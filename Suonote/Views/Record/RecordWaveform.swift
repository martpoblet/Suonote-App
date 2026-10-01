import SwiftUI

// MARK: - Waveform cache

/// Peak envelopes are expensive (they decode the whole file), so they are
/// computed off the main thread once per file/size and kept in memory.
enum RecordWaveformCache {
    private static var store: [String: [CGFloat]] = [:]

    static func cached(_ fileName: String, samples: Int) -> [CGFloat]? {
        store["\(fileName)#\(samples)"]
    }

    static func load(_ fileName: String, samples: Int) async -> [CGFloat] {
        if let hit = cached(fileName, samples: samples) { return hit }
        let values = await Task.detached(priority: .utility) {
            FileManagerUtils.extractWaveform(from: fileName, samples: samples)
        }.value
        store["\(fileName)#\(samples)"] = values
        return values
    }
}

// MARK: - Take waveform

/// A take's peak waveform. Played portion in brand teal, the rest in soft ink.
/// Tap to jump; drag to scrub (when `onSeek` is provided).
struct RecordWaveformView: View {
    let fileName: String
    var samples: Int = 48
    /// 0...1 playhead, nil when this take isn't loaded.
    var progress: Double?
    var isActive: Bool = false
    var barSpacing: CGFloat = 2
    var onSeek: ((Double) -> Void)? = nil

    @State private var levels: [CGFloat] = []
    @State private var scrubFraction: Double?

    var body: some View {
        GeometryReader { geo in
            let shown = scrubFraction ?? progress
            Canvas { context, size in
                draw(in: &context, size: size, progress: shown)
            }
            .overlay(alignment: .leading) {
                if let shown, isActive || scrubFraction != nil {
                    Capsule()
                        .fill(DesignSystem.Colors.primaryDark)
                        .frame(width: 2)
                        .offset(x: max(0, min(geo.size.width - 2, geo.size.width * shown - 1)))
                }
            }
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: geo.size.width), including: onSeek == nil ? .none : .all)
        }
        .task(id: "\(fileName)#\(samples)") {
            if let hit = RecordWaveformCache.cached(fileName, samples: samples) {
                levels = hit
            } else {
                let loaded = await RecordWaveformCache.load(fileName, samples: samples)
                withAnimation(DesignSystem.Animations.smoothEase) { levels = loaded }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Waveform")
        .accessibilityValue(progress.map { String(localized: "\(Int($0 * 100)) percent played") } ?? "")
        .accessibilityAdjustableAction { direction in
            guard let onSeek else { return }
            let base = progress ?? 0
            switch direction {
            case .increment: onSeek(min(1, base + 0.1))
            case .decrement: onSeek(max(0, base - 0.1))
            @unknown default: break
            }
        }
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard width > 0 else { return }
                scrubFraction = max(0, min(1, value.location.x / width))
            }
            .onEnded { value in
                guard width > 0 else { return }
                let fraction = max(0, min(1, value.location.x / width))
                scrubFraction = nil
                HapticFeedback.selection.trigger()
                onSeek?(fraction)
            }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, progress: Double?) {
        let count = max(1, levels.isEmpty ? samples : levels.count)
        let barWidth = max(1.5, (size.width - CGFloat(count - 1) * barSpacing) / CGFloat(count))
        let played = DesignSystem.Colors.brand
        let idle = isActive ? DesignSystem.Colors.textTertiary.opacity(0.55) : DesignSystem.Colors.textTertiary.opacity(0.45)
        for index in 0..<count {
            let level = levels.isEmpty ? 0.08 : max(0.08, min(1, levels[index]))
            let height = max(2, size.height * level)
            let x = CGFloat(index) * (barWidth + barSpacing)
            let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)
            let isPlayed = progress.map { (Double(index) + 0.5) / Double(count) <= $0 } ?? false
            context.fill(
                Path(roundedRect: rect, cornerRadius: barWidth / 2),
                with: .color(isPlayed ? played : idle)
            )
        }
    }
}

// MARK: - Live input waveform

/// Scrolling input envelope while recording — newest sample on the right.
struct RecordLiveWaveform: View {
    let levels: [Float]
    var tint: Color = DesignSystem.Colors.brand

    var body: some View {
        Canvas { context, size in
            let count = max(1, levels.count)
            let spacing: CGFloat = 3
            let barWidth = max(1.5, (size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            let mid = size.height / 2
            context.fill(
                Path(CGRect(x: 0, y: mid - 0.5, width: size.width, height: 1)),
                with: .color(DesignSystem.Colors.border)
            )
            for (index, level) in levels.enumerated() {
                let shaped = pow(CGFloat(max(0, min(1, level))), 1.6)
                let height = max(3, size.height * 0.92 * shaped)
                let x = CGFloat(index) * (barWidth + spacing)
                let rect = CGRect(x: x, y: mid - height / 2, width: barWidth, height: height)
                let age = Double(index) / Double(count)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(tint.opacity(0.35 + 0.65 * age))
                )
            }
        }
        .accessibilityHidden(true)
    }
}
