import SwiftUI

// MARK: - Audio clip
/// A recording placed on the Studio timeline: name, waveform and where it
/// starts in the song.
struct StudioAudioTrackView: View {
    @Bindable var track: StudioTrack
    let project: Project
    var onChange: () -> Void = {}
    @State private var waveformSamples: [CGFloat] = []

    private var recording: Recording? {
        project.recordings.first(where: { $0.id == track.audioRecordingId })
    }

    private var beatsPerBar: Int { max(1, project.timeTop) }

    private var startBar: Int { Int(track.audioStartBeat / Double(beatsPerBar)) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if let recording {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clip").eyebrow()
                    Text(recording.name)
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(durationText(recording.duration))
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Group {
                    if waveformSamples.isEmpty {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.surfaceSecondary)
                            .overlay(LoadingView(String(localized: "Reading the take…")).scaleEffect(0.8))
                    } else {
                        StudioWaveformView(samples: waveformSamples, color: DesignSystem.Colors.brand)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .wellStyle()
                    }
                }
                .frame(height: 96)

                Hairline()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Starts at").eyebrow()
                        Text("Bar \(startBar)")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Stepper("Start bar", value: Binding(
                        get: { startBar },
                        set: { newBar in
                            track.audioStartBeat = Double(max(0, newBar - 1) * beatsPerBar)
                            onChange()
                        }
                    ), in: 1...max(1, project.studioTotalBars))
                    .labelsHidden()
                }
            } else {
                EmptyStateView(
                    icon: "waveform.slash",
                    title: String(localized: "Recording not found"),
                    message: String(localized: "The take this track points to was deleted.")
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .task(id: track.audioRecordingId) {
            guard let recording else { return }
            let fileName = recording.fileName
            let samples = await Task.detached(priority: .utility) {
                FileManagerUtils.extractWaveform(from: fileName, samples: 90)
            }.value
            waveformSamples = samples
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: String(localized: "%d:%02d long"), total / 60, total % 60)
    }
}

/// Static waveform rendering for audio tracks, built from cached peak samples.
struct StudioWaveformView: View {
    let samples: [CGFloat]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let count = max(1, samples.count)
            let barWidth = size.width / CGFloat(count)
            for (index, sample) in samples.enumerated() {
                let height = max(2, sample * size.height)
                let rect = CGRect(
                    x: CGFloat(index) * barWidth + barWidth * 0.15,
                    y: (size.height - height) / 2,
                    width: barWidth * 0.7,
                    height: height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth * 0.35), with: .color(color.opacity(0.85)))
            }
        }
        .accessibilityHidden(true)
    }
}
