import AVFoundation

final class MetronomeClickPlayer {
    static let shared = MetronomeClickPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let regularBuffer: AVAudioPCMBuffer
    private let accentBuffer: AVAudioPCMBuffer
    private var isReady = false

    private init() {
        let sampleRate: Double = 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            fatalError("Metronome click format unavailable.")
        }
        self.format = format
        self.regularBuffer = Self.makeClickBuffer(
            format: format,
            frequency: 1_000,
            duration: 0.03,
            amplitude: 0.35
        )
        self.accentBuffer = Self.makeClickBuffer(
            format: format,
            frequency: 1_500,
            duration: 0.035,
            amplitude: 0.45
        )

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        startEngineIfNeeded()
    }

    func play(accent: Bool) {
        startEngineIfNeeded()
        let buffer = accent ? accentBuffer : regularBuffer
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    private func startEngineIfNeeded() {
        if isReady && engine.isRunning {
            return
        }
        do {
            try engine.start()
            isReady = true
        } catch {
            print("Metronome engine failed to start: \(error)")
        }
    }

    private static func makeClickBuffer(
        format: AVAudioFormat,
        frequency: Double,
        duration: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = max(0, 1.0 - (t / duration))
            let sample = sin(2.0 * Double.pi * frequency * t) * envelope
            channel[frame] = Float(sample) * amplitude
        }
        return buffer
    }
}
