import SwiftUI
import AVFoundation

// MARK: - Waveform View (S1)
// Renders an audio waveform visualization from a recording file URL.
// Uses AVAssetReader to sample amplitude data and renders with Canvas.

@MainActor
class WaveformLoader: ObservableObject {
    @Published var samples: [Float] = []
    @Published var isLoading: Bool = false

    func load(url: URL, sampleCount: Int = 100) {
        guard !isLoading else { return }
        isLoading = true
        samples = []

        Task.detached(priority: .userInitiated) { [weak self] in
            let result = await WaveformLoader.extractSamples(from: url, count: sampleCount)
            await MainActor.run {
                self?.samples = result
                self?.isLoading = false
            }
        }
    }

    private static func extractSamples(from url: URL, count: Int) async -> [Float] {
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return WaveformLoader.syntheticSamples(count: count)
        }

        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return WaveformLoader.syntheticSamples(count: count)
        }

        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            return WaveformLoader.syntheticSamples(count: count)
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        assetReader.add(output)

        guard assetReader.startReading() else {
            return WaveformLoader.syntheticSamples(count: count)
        }

        var rawSamples: [Float] = []
        while assetReader.status == .reading {
            guard let buffer = output.copyNextSampleBuffer(),
                  let block = CMSampleBufferGetDataBuffer(buffer) else { break }
            let length = CMBlockBufferGetDataLength(block)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { ptr in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
            }
            let int16Samples = data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
            rawSamples += int16Samples.map { abs(Float($0)) / Float(Int16.max) }
        }

        guard !rawSamples.isEmpty else { return WaveformLoader.syntheticSamples(count: count) }

        // Downsample to `count` samples
        let chunkSize = max(1, rawSamples.count / count)
        var result: [Float] = []
        for i in 0..<count {
            let start = i * chunkSize
            let end = min(start + chunkSize, rawSamples.count)
            guard start < rawSamples.count else { result.append(0); continue }
            let chunk = rawSamples[start..<end]
            let rms = sqrt(chunk.map { $0 * $0 }.reduce(0, +) / Float(chunk.count))
            result.append(rms)
        }

        // Normalize
        if let maxVal = result.max(), maxVal > 0 {
            result = result.map { $0 / maxVal }
        }
        return result
    }

    /// Generates a plausible synthetic waveform for files that can't be read
    static func syntheticSamples(count: Int) -> [Float] {
        (0..<count).map { i in
            let t = Double(i) / Double(count)
            let base = Float(sin(t * .pi * 8) * 0.4 + 0.4)
            let noise = Float.random(in: -0.1...0.1)
            return max(0, min(1, base + noise))
        }
    }
}

struct WaveformView: View {
    let url: URL?
    var height: CGFloat = 60
    var foregroundColor: Color = DesignSystem.Colors.primary
    var backgroundColor: Color = Color.clear
    var showTimeline: Bool = false
    var duration: Double = 0

    @StateObject private var loader = WaveformLoader()

    var body: some View {
        ZStack {
            backgroundColor

            if loader.isLoading {
                // Loading shimmer
                shimmerView
            } else if loader.samples.isEmpty {
                emptyWaveform
            } else {
                Canvas { ctx, size in
                    drawWaveform(ctx: ctx, size: size, samples: loader.samples)
                }
                .frame(height: height)
            }
        }
        .frame(height: height)
        .onChange(of: url) { _, newURL in
            if let url = newURL { loader.load(url: url) }
        }
        .onAppear {
            if let url { loader.load(url: url) }
        }
    }

    // MARK: - Drawing

    private func drawWaveform(ctx: GraphicsContext, size: CGSize, samples: [Float]) {
        let barWidth = size.width / CGFloat(samples.count)
        let midY = size.height / 2

        for (i, sample) in samples.enumerated() {
            let x = CGFloat(i) * barWidth + barWidth / 2
            let amplitude = CGFloat(sample) * midY * 0.95

            var path = Path()
            path.move(to: CGPoint(x: x, y: midY - amplitude))
            path.addLine(to: CGPoint(x: x, y: midY + amplitude))

            ctx.stroke(path, with: .color(foregroundColor.opacity(0.7 + Double(sample) * 0.3)),
                       lineWidth: max(1.5, barWidth - 1))
        }
    }

    // MARK: - Shimmer

    private var shimmerView: some View {
        HStack(spacing: 2) {
            ForEach(0..<50, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DesignSystem.Colors.border)
                    .frame(width: 2, height: CGFloat.random(in: 8...height * 0.9))
            }
        }
    }

    // MARK: - Empty

    private var emptyWaveform: some View {
        HStack(spacing: 2) {
            ForEach(WaveformLoader.syntheticSamples(count: 60).indices, id: \.self) { i in
                let sample = WaveformLoader.syntheticSamples(count: 60)[i]
                RoundedRectangle(cornerRadius: 1)
                    .fill(DesignSystem.Colors.border)
                    .frame(width: 2, height: CGFloat(sample) * height * 0.8)
            }
        }
    }
}

// MARK: - Compact Waveform Row (for RecordingsTab)

struct WaveformRowView: View {
    let recording: Recording
    var isPlaying: Bool = false

    private var audioURL: URL? {
        let filename = recording.fileName
        guard !filename.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(filename)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Play indicator
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 12))
                .foregroundStyle(isPlaying ? DesignSystem.Colors.error : DesignSystem.Colors.primary)
                .frame(width: 20)

            // Waveform
            WaveformView(
                url: audioURL,
                height: 40,
                foregroundColor: isPlaying ? DesignSystem.Colors.accent : DesignSystem.Colors.primary
            )

            // Duration
            Text(durationString)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var durationString: String {
        let d = recording.duration
        let mins = Int(d) / 60
        let secs = Int(d) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
