import XCTest
import SwiftData
import AVFoundation
@testable import Suonote

/// Take alignment (clicks heard by the mic) and repeating bars in Compose.
final class RecordingAndStructureTests: XCTestCase {

    // MARK: - Take alignment

    private let rate = 48_000.0

    /// Input as the mic hears it: room noise plus each click arriving
    /// `latency` seconds after it was rendered. `startSeconds` is the click
    /// clock time of sample 0.
    private func micInput(
        clickTimes: [Double],
        latency: Double,
        startSeconds: Double = -0.25,
        seconds: Double,
        noise: Float = 0.002,
        clickLevel: Float = 0.2
    ) -> [Float] {
        var generator = SystemRandomNumberGenerator()
        var samples = (0..<Int(seconds * rate)).map { _ in Float.random(in: -noise...noise, using: &generator) }
        for click in clickTimes {
            let start = Int(((click + latency - startSeconds) * rate).rounded())
            for offset in 0..<Int(0.03 * rate) where start + offset < samples.count {
                let t = Double(offset) / rate
                let envelope = Float(max(0, 1 - t / 0.03))
                samples[start + offset] += Float(sin(2 * .pi * 1_000 * t)) * envelope * clickLevel
            }
        }
        return samples
    }

    func testMeasuresSpeakerLatencyFromCountInClicks() throws {
        let beat = 0.5
        let clicks = (0..<4).map { Double($0) * beat }
        let input = micInput(clickTimes: clicks, latency: 0.037, seconds: 3)
        let latency = try XCTUnwrap(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
        XCTAssertEqual(latency, 0.037, accuracy: 0.001)
    }

    func testFastTempoStillFindsEachClick() throws {
        let beat = 60.0 / 200
        let clicks = (0..<8).map { Double($0) * beat }
        let input = micInput(clickTimes: clicks, latency: 0.012, seconds: 3.5)
        let latency = try XCTUnwrap(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
        XCTAssertEqual(latency, 0.012, accuracy: 0.001)
    }

    func testHeadphonesFallBackToReportedLatency() {
        // No bleed: the mic hears only the room.
        let beat = 0.5
        let clicks = (0..<4).map { Double($0) * beat }
        let input = micInput(clickTimes: [], latency: 0, seconds: 3)
        XCTAssertNil(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
    }

    func testInconsistentOnsetsAreRejected() {
        // Someone counting out loud at random times, not clicks.
        let beat = 0.5
        let clicks = (0..<4).map { Double($0) * beat }
        let hits = [0.05, 0.62, 1.21, 1.68]
        let input = micInput(clickTimes: hits, latency: 0, seconds: 3)
        XCTAssertNil(TakeAligner.measureLatency(
            samples: input, sampleRate: rate, startSeconds: -0.25, clickTimes: clicks, beatSeconds: beat
        ))
    }

    func testBeatClockCountsHeardBeats() {
        let start = mach_absolute_time()
        let clock = RecordBeatClock(startHostTime: start, beatSeconds: 0.5, beatsPerBar: 4, countInBeats: 4, outputLatency: 0.01)
        let later = start + AVAudioTimeHelper.hostTicks(seconds: 1.26)
        XCTAssertEqual(clock.heardBeats(atHostTime: later), 2.5, accuracy: 0.001)
        XCTAssertLessThan(clock.heardBeats(atHostTime: start), 0)
    }

    // MARK: - Repeating bars

    @MainActor
    private func makeSection(bars: Int, chords: [(bar: Int, root: String)]) throws -> (SectionTemplate, ModelContainer) {
        let container = try ModelContainer(for: Project.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let section = SectionTemplate(name: "Verse", bars: bars)
        ModelContext(container).insert(section)
        for chord in chords {
            section.chordEvents.append(ChordEvent(barIndex: chord.bar, beatOffset: 0, duration: 4, root: chord.root))
        }
        return (section, container)
    }

    @MainActor
    private func roots(_ section: SectionTemplate) -> [String] {
        (0..<section.bars).map { bar in
            section.chordEvents.first { $0.barIndex == bar }?.root ?? "-"
        }
    }

    @MainActor
    func testRepeatLastTwoBarsAppendsCopies() throws {
        let (section, container) = try makeSection(bars: 4, chords: [(0, "C"), (1, "G"), (2, "A"), (3, "F")])
        _ = container
        ComposeChordOps.repeatBars(in: section, range: 2..<4, times: 1)
        XCTAssertEqual(section.bars, 6)
        XCTAssertEqual(roots(section), ["C", "G", "A", "F", "A", "F"])
    }

    @MainActor
    func testRepeatBarSeveralTimesShiftsLaterBars() throws {
        let (section, container) = try makeSection(bars: 3, chords: [(0, "C"), (1, "G"), (2, "F")])
        _ = container
        ComposeChordOps.repeatBars(in: section, range: 0..<1, times: 2)
        XCTAssertEqual(roots(section), ["C", "C", "C", "G", "F"])
    }

    @MainActor
    func testRepeatKeepsBeatsAndDurationsAndEmptyBars() throws {
        let (section, container) = try makeSection(bars: 2, chords: [(0, "C")])
        _ = container
        section.chordEvents.append(ChordEvent(barIndex: 0, beatOffset: 2, duration: 2, root: "E", quality: .minor))
        ComposeChordOps.repeatBars(in: section, range: 0..<2, times: 1)
        XCTAssertEqual(section.bars, 4)
        let copied = section.chordEvents.filter { $0.barIndex == 2 }.sorted { $0.beatOffset < $1.beatOffset }
        XCTAssertEqual(copied.map(\.root), ["C", "E"])
        XCTAssertEqual(copied.last?.beatOffset, 2)
        XCTAssertEqual(copied.last?.duration, 2)
        XCTAssertEqual(copied.last?.quality, .minor)
        XCTAssertTrue(section.chordEvents.filter { $0.barIndex == 3 }.isEmpty)
    }

    @MainActor
    func testRepeatNeverGrowsPastTheLimit() throws {
        let (section, container) = try makeSection(bars: 40, chords: [])
        _ = container
        ComposeChordOps.repeatBars(in: section, range: 0..<40, times: 1)
        XCTAssertEqual(section.bars, 40)
        XCTAssertFalse(ComposeChordOps.canAdd(40, to: section))
        XCTAssertTrue(ComposeChordOps.canAdd(24, to: section))
    }

    @MainActor
    func testRepeatOptionsFitTheSection() throws {
        let (eight, container) = try makeSection(bars: 8, chords: [])
        _ = container
        XCTAssertEqual(ComposeRepeatOption.endings(of: eight).map(\.range), [7..<8, 6..<8, 4..<8, 0..<8])
        let (two, other) = try makeSection(bars: 2, chords: [])
        _ = other
        XCTAssertEqual(ComposeRepeatOption.endings(of: two).map(\.range), [1..<2, 0..<2])
    }
}

// MARK: - Take → Studio timing, end to end (offline, silent)

final class TakeTimingPipelineTests: XCTestCase {
    private let takeRate = 48_000.0

    /// A take as TakeCapture writes it: mono AAC at the mic's rate, with a
    /// short click at each of `clickSeconds`.
    private func writeTake(clicks clickSeconds: [Double], seconds: Double, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: takeRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let frames = Int(seconds * takeRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: takeRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let data = buffer.floatChannelData![0]
        for i in 0..<frames { data[i] = 0 }
        for click in clickSeconds {
            let start = Int(click * takeRate)
            for i in 0..<Int(0.02 * takeRate) where start + i < frames {
                let t = Double(i) / takeRate
                data[start + i] = Float(sin(2 * .pi * 1_000 * t) * max(0, 1 - t / 0.02)) * 0.8
            }
        }
        // Write in tap-sized chunks, like the live capture does.
        var offset = 0
        while offset < frames {
            let count = min(4_800, frames - offset)
            let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
            chunk.frameLength = AVAudioFrameCount(count)
            chunk.floatChannelData![0].update(from: data + offset, count: count)
            try file.write(from: chunk)
            offset += count
        }
    }

    /// Onset times (seconds) of transients in a file: first sample over 30%
    /// of the file's peak after at least 80 ms of quiet.
    private func onsets(in url: URL) throws -> [Double] {
        let file = try AVAudioFile(forReading: url)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
        let rate = file.processingFormat.sampleRate
        let peak = samples.map(abs).max() ?? 0
        guard peak > 0 else { return [] }
        var result: [Double] = []
        var lastLoud = -Int.max / 2
        for (i, sample) in samples.enumerated() where abs(sample) >= peak * 0.3 {
            if i - lastLoud > Int(0.08 * rate) { result.append(Double(i) / rate) }
            lastLoud = i
        }
        return result
    }

    func testAACRoundTripKeepsClicksInPlace() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("roundtrip.m4a")
        let clicks = [0.0, 0.5, 1.0, 1.5]
        try writeTake(clicks: clicks, seconds: 2.5, to: url)
        let found = try onsets(in: url)
        XCTAssertEqual(found.count, clicks.count, "found \(found)")
        for (expected, actual) in zip(clicks, found) {
            XCTAssertEqual(actual, expected, accuracy: 0.002, "AAC shifted a click: \(found)")
        }
    }

    @MainActor
    func testTakeLinesUpWithTheBandInTheMix() async throws {
        let container = try ModelContainer(for: Project.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        func project(withTake: Bool) throws -> Project {
            let project = Project(title: "Timing", status: .idea, tags: [], keyRoot: "C", keyMode: .major, bpm: 120, timeTop: 4, timeBottom: 4)
            context.insert(project)
            project.studioStyle = .pop
            // No sections: the render is one 4/4 bar (2 s at 120 bpm).
            if withTake {
                let fileName = "timing-\(UUID().uuidString).m4a"
                try writeTake(clicks: (0..<4).map { Double($0) * 0.5 }, seconds: 2.5, to: FileManagerUtils.recordingURL(for: fileName))
                let recording = Recording(name: "Take", fileName: fileName, duration: 2.5, bpm: 120, recordingType: .voice)
                recording.project = project
                project.recordings.append(recording)
                let track = StudioTrack(name: "Take", instrument: .audio, orderIndex: 0, audioRecordingId: recording.id, audioStartBeat: 0)
                track.project = project
                project.studioTracks.append(track)
            } else {
                let track = StudioTrack(name: "Drums", instrument: .drums, orderIndex: 0, style: .pop)
                track.notes = (0..<4).map { StudioNote(startBeat: Double($0), duration: 0.25, pitch: 36, velocity: 120) }
                track.project = project
                project.studioTracks.append(track)
            }
            return project
        }

        let band = try onsets(in: try await StudioOfflineRenderer.render(project: try project(withTake: false), format: .wav, tail: 0.5))
        let take = try onsets(in: try await StudioOfflineRenderer.render(project: try project(withTake: true), format: .wav, tail: 0.5))
        print("TIMING band onsets: \(band.map { Int(($0 * 1000).rounded()) }) ms")
        print("TIMING take onsets: \(take.map { Int(($0 * 1000).rounded()) }) ms")
        XCTAssertGreaterThanOrEqual(band.count, 4)
        XCTAssertGreaterThanOrEqual(take.count, 4)
        for (kick, click) in zip(band, take) {
            XCTAssertEqual(click, kick, accuracy: 0.012, "take vs band: \(Int((click - kick) * 1000)) ms")
        }
    }
}

private enum AVAudioTimeHelper {
    static func hostTicks(seconds: Double) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return UInt64(seconds * 1_000_000_000 * Double(info.denom) / Double(info.numer))
    }
}
