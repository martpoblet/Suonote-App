import os
import AVFoundation

/// Where the recording's beats are, in the same clock the audio runs on.
/// Shared with the UI so the visual click lands on the audible one.
nonisolated struct RecordBeatClock: Equatable, Sendable {
    /// Host time at which the first click is rendered.
    let startHostTime: UInt64
    let beatSeconds: Double
    let beatsPerBar: Int
    let countInBeats: Int
    /// Time from render to the speaker or headphones.
    let outputLatency: Double

    /// Beats since the first click, as heard (negative before it sounds).
    func heardBeats(atHostTime hostTime: UInt64 = mach_absolute_time()) -> Double {
        let seconds = AVAudioTime.seconds(forHostTime: hostTime) - AVAudioTime.seconds(forHostTime: startHostTime)
        return (seconds - outputLatency) / beatSeconds
    }
}

/// Records a take on a sample-accurate clock.
///
/// The click and the microphone run on one `AVAudioEngine`, so the click's
/// render time and the captured audio share a timeline. The input is held in
/// memory until shortly after the downbeat; by then the count-in clicks have
/// usually bled into the microphone, which gives the real round-trip latency
/// (speaker → air → mic → converter). The file is then written from the exact
/// sample where a note played on "one" lands, so bar 1 of the take is bar 1
/// of the song. With headphones there is no bleed and the latencies the audio
/// session reports are used instead.
nonisolated final class TakeCapture: @unchecked Sendable {
    enum CaptureError: Error {
        case noInput
    }

    struct Levels: Sendable {
        var rms: Float = 0
        var peak: Float = 0
    }

    let url: URL

    private let engine = AVAudioEngine()
    private let clickNode = AVAudioPlayerNode()
    private var clickRate: Double = 48_000
    private var accentClick: AVAudioPCMBuffer?
    private var regularClick: AVAudioPCMBuffer?
    private var nextClickBeat = 0

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Suonote", category: "audio")

    // Fixed once `start` returns.
    private var inputRate: Double = 48_000
    private var beatSeconds: Double = 0.5
    private var beatsPerBar = 4
    private var countInBeats = 0
    private var clickWhileRecording = false
    private var fallbackLatency: Double = 0

    // Shared with the input tap; guarded by `lock`.
    private let lock = OSAllocatedUnfairLock()
    /// Host time of the first click; input that arrives before it is set is dropped.
    private var startHostTime: UInt64?
    private var file: AVAudioFile?
    private var preroll: [Float] = []
    private var prerollStartSeconds: Double?
    private var isAligned = false
    private var framesWritten: Int64 = 0
    private var levels = Levels()
    private var appliedLatency: Double = 0
    private var latencyWasMeasured = false

    /// How long after the downbeat the input is held before alignment runs.
    private static let alignmentWindow: Double = 0.45

    init(url: URL) {
        self.url = url
    }

    // MARK: Lifecycle

    /// Starts the engine, the click and the capture. The audio session must
    /// already be set to play-and-record.
    func start(
        beatSeconds: Double,
        beatsPerBar: Int,
        countInBeats: Int,
        clickWhileRecording: Bool
    ) throws -> RecordBeatClock {
        self.beatSeconds = max(0.05, beatSeconds)
        self.beatsPerBar = max(1, beatsPerBar)
        self.countInBeats = max(0, countInBeats)
        self.clickWhileRecording = clickWhileRecording

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw CaptureError.noInput }
        inputRate = inputFormat.sampleRate

        file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: inputRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        let outputRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        clickRate = outputRate > 0 ? outputRate : 48_000
        guard let clickFormat = AVAudioFormat(standardFormatWithSampleRate: clickRate, channels: 1) else {
            throw CaptureError.noInput
        }
        accentClick = Self.makeClick(format: clickFormat, frequency: 1_500, duration: 0.035, amplitude: 0.45)
        regularClick = Self.makeClick(format: clickFormat, frequency: 1_000, duration: 0.03, amplitude: 0.35)
        engine.attach(clickNode)
        engine.connect(clickNode, to: engine.mainMixerNode, format: clickFormat)

        input.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, time in
            self?.receive(buffer, at: time)
        }

        engine.prepare()
        try engine.start()

        let session = AVAudioSession.sharedInstance()
        fallbackLatency = session.inputLatency + session.outputLatency

        // A short lead so the first click is never clipped by engine start-up.
        let firstClickHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.25)
        lock.withLockUnchecked { startHostTime = firstClickHostTime }
        scheduleClicks(throughSeconds: Double(self.countInBeats) * self.beatSeconds + 2)
        clickNode.play(at: AVAudioTime(hostTime: firstClickHostTime))

        return RecordBeatClock(
            startHostTime: firstClickHostTime,
            beatSeconds: self.beatSeconds,
            beatsPerBar: self.beatsPerBar,
            countInBeats: self.countInBeats,
            outputLatency: session.outputLatency
        )
    }

    /// Keeps a few seconds of clicks queued ahead. Call regularly while rolling.
    func scheduleClicks(throughSeconds limit: Double) {
        guard let accentClick, let regularClick else { return }
        while Double(nextClickBeat) * beatSeconds <= limit {
            let beat = nextClickBeat
            guard beat < countInBeats || clickWhileRecording else { return }
            let frame = AVAudioFramePosition((Double(beat) * beatSeconds * clickRate).rounded())
            let buffer = beat % beatsPerBar == 0 ? accentClick : regularClick
            clickNode.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: frame, atRate: clickRate))
            nextClickBeat += 1
        }
    }

    /// Stops and finishes the file. Returns the seconds of audio kept.
    func stop() -> Double {
        shutDownEngine()
        return lock.withLockUnchecked {
            if !isAligned { alignAndFlush() }
            file = nil
            preroll = []
            return Double(framesWritten) / inputRate
        }
    }

    /// Stops and deletes whatever was captured.
    func cancel() {
        shutDownEngine()
        lock.withLockUnchecked {
            file = nil
            preroll = []
        }
        try? FileManager.default.removeItem(at: url)
    }

    var currentLevels: Levels {
        lock.withLockUnchecked { levels }
    }

    /// The round-trip latency the take was aligned with, and whether it was
    /// measured from the click bleeding into the mic (vs. reported by iOS).
    var alignment: (latency: Double, measured: Bool)? {
        lock.withLockUnchecked { isAligned ? (appliedLatency, latencyWasMeasured) : nil }
    }

    private func shutDownEngine() {
        engine.inputNode.removeTap(onBus: 0)
        clickNode.stop()
        engine.stop()
    }

    // MARK: Input

    private func receive(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        let count = Int(buffer.frameLength)
        guard count > 0, let channels = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)

        var mono = [Float](repeating: 0, count: count)
        let scale = 1 / Float(channelCount)
        for channel in 0..<channelCount {
            let data = channels[channel]
            for frame in 0..<count { mono[frame] += data[frame] * scale }
        }

        var sumSquares: Float = 0
        var peak: Float = 0
        for sample in mono {
            sumSquares += sample * sample
            peak = max(peak, abs(sample))
        }
        let rms = (sumSquares / Float(count)).squareRoot()

        lock.withLockUnchecked {
            levels = Levels(rms: Self.normalized(rms), peak: Self.normalized(peak))
            guard let startHostTime else { return }
            if isAligned {
                write(mono[...])
                return
            }
            if prerollStartSeconds == nil {
                prerollStartSeconds = time.isHostTimeValid
                    ? AVAudioTime.seconds(forHostTime: time.hostTime) - AVAudioTime.seconds(forHostTime: startHostTime)
                    : -Double(count) / inputRate
            }
            preroll.append(contentsOf: mono)
            let coveredUntil = (prerollStartSeconds ?? 0) + Double(preroll.count) / inputRate
            if coveredUntil >= Double(countInBeats) * beatSeconds + Self.alignmentWindow {
                alignAndFlush()
            }
        }
    }

    /// Finds where "one" lands in the held input and writes from there on.
    /// Call with `lock` held.
    private func alignAndFlush() {
        let downbeat = Double(countInBeats) * beatSeconds
        // Every click that has sounded by the downbeat is a reference.
        let referenceBeats = countInBeats + (clickWhileRecording ? 1 : 0)
        let clickTimes = (0..<referenceBeats).map { Double($0) * beatSeconds }
        let start = prerollStartSeconds ?? 0

        let measured = TakeAligner.measureLatency(
            samples: preroll,
            sampleRate: inputRate,
            startSeconds: start,
            clickTimes: clickTimes,
            beatSeconds: beatSeconds
        )
        appliedLatency = measured ?? fallbackLatency
        latencyWasMeasured = measured != nil
        isAligned = true

        let firstIndex = Int(((downbeat + appliedLatency - start) * inputRate).rounded())
        if firstIndex < preroll.count {
            write(preroll[max(0, firstIndex)...])
        }
        preroll = []
        Self.log.info("Take aligned with \(Int(self.appliedLatency * 1000)) ms latency (\(measured != nil ? "measured" : "reported"))")
    }

    /// Call with `lock` held.
    private func write(_ samples: ArraySlice<Float>) {
        guard let file, !samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: inputRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let target = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            target.update(from: base, count: samples.count)
        }
        do {
            try file.write(from: buffer)
            framesWritten += Int64(samples.count)
        } catch {
            Self.log.error("Failed to write take audio: \(String(describing: error))")
        }
    }

    // MARK: Helpers

    /// dBFS mapped to 0...1 over a 60 dB range.
    private static func normalized(_ amplitude: Float) -> Float {
        guard amplitude > 0 else { return 0 }
        let db = 20 * log10(amplitude)
        return min(1, max(0, (db + 60) / 60))
    }

    private static func makeClick(format: AVAudioFormat, frequency: Double, duration: Double, amplitude: Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            let envelope = max(0, 1 - t / duration)
            channel[frame] = Float(sin(2 * Double.pi * frequency * t) * envelope) * amplitude
        }
        return buffer
    }
}

/// Measures input latency from clicks heard by the microphone.
nonisolated enum TakeAligner {
    /// Looks for each click's onset in `samples` and returns the typical delay
    /// from its render time, or nil when the clicks can't be heard reliably
    /// (headphones, a noisy room, or someone counting out loud).
    ///
    /// - Parameters:
    ///   - startSeconds: time of `samples[0]` on the click clock.
    ///   - clickTimes: render times of the clicks on the same clock.
    static func measureLatency(
        samples: [Float],
        sampleRate: Double,
        startSeconds: Double,
        clickTimes: [Double],
        beatSeconds: Double,
        maxLatency: Double = 0.4
    ) -> Double? {
        guard !clickTimes.isEmpty, sampleRate > 0 else { return nil }
        let searchAhead = min(maxLatency, beatSeconds * 0.9)
        let searchBehind = 0.02
        let noiseSpan = Int(0.04 * sampleRate)

        var delays: [Double] = []
        for click in clickTimes {
            let center = (click - startSeconds) * sampleRate
            let lower = Int((center - searchBehind * sampleRate).rounded())
            let upper = Int((center + searchAhead * sampleRate).rounded())
            guard lower - noiseSpan >= 0, upper <= samples.count else { continue }

            var noise: Float = 0
            for index in (lower - noiseSpan)..<lower { noise += samples[index] * samples[index] }
            noise = (noise / Float(noiseSpan)).squareRoot()

            var peak: Float = 0
            for index in lower..<upper { peak = max(peak, abs(samples[index])) }
            guard peak >= 0.01, peak >= 8 * max(noise, 0.000_5) else { continue }

            let threshold = peak * 0.3
            guard let onset = (lower..<upper).first(where: { abs(samples[$0]) >= threshold }) else { continue }
            delays.append((Double(onset) - center) / sampleRate)
        }

        let needed = min(2, clickTimes.count)
        guard delays.count >= needed else { return nil }
        let sorted = delays.sorted()
        let median = sorted[sorted.count / 2]
        let agreeing = sorted.filter { abs($0 - median) <= 0.004 }
        // Most clicks must agree, or the "clicks" were really someone playing.
        guard agreeing.count >= needed, agreeing.count * 2 > delays.count else { return nil }
        return agreeing.reduce(0, +) / Double(agreeing.count)
    }
}
