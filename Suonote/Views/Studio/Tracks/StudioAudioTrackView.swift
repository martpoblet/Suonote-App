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

    /// The clip sits on a bar plus an optional nudge (a fraction of a beat
    /// either way), so a take can be lined up by ear without a new field.
    private var startBar: Int { max(1, Int((track.audioStartBeat / Double(beatsPerBar)).rounded()) + 1) }

    private var nudgeBeats: Double { track.audioStartBeat - Double((startBar - 1) * beatsPerBar) }

    private var beatSeconds: Double {
        60.0 / max(1, project.quarterNoteBpm()) * 4.0 / Double(max(1, project.timeBottom))
    }

    private var nudgeMilliseconds: Int { Int((nudgeBeats * beatSeconds * 1000).rounded()) }

    private static let nudgeStep = 10
    private static let nudgeLimit = 300

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
                            track.audioStartBeat = Double(max(0, newBar - 1) * beatsPerBar) + nudgeBeats
                            onChange()
                        }
                    ), in: 1...max(1, project.studioTotalBars))
                    .labelsHidden()
                }

                Hairline()

                timingRow
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

    /// Moves the take a few milliseconds earlier or later against the band.
    private var timingRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Timing").eyebrow()
                Text(nudgeLabel)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Sounds early or late? Nudge it.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            Spacer(minLength: 0)
            if nudgeMilliseconds != 0 {
                Button {
                    setNudge(milliseconds: 0)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset")
                .transition(.opacity)
            }
            Stepper("Timing", value: Binding(
                get: { nudgeMilliseconds },
                set: { setNudge(milliseconds: $0) }
            ), in: -Self.nudgeLimit...Self.nudgeLimit, step: Self.nudgeStep)
            .labelsHidden()
        }
        .accessibilityElement(children: .combine)
    }

    private var nudgeLabel: String {
        switch nudgeMilliseconds {
        case 0: return String(localized: "On the grid")
        case ..<0: return String(localized: "\(abs(nudgeMilliseconds)) ms earlier")
        default: return String(localized: "\(nudgeMilliseconds) ms later")
        }
    }

    private func setNudge(milliseconds: Int) {
        let clamped = min(Self.nudgeLimit, max(-Self.nudgeLimit, milliseconds))
        let barStart = Double((startBar - 1) * beatsPerBar)
        withAnimation(DesignSystem.Animations.quickSpring) {
            track.audioStartBeat = barStart + Double(clamped) / 1000 / beatSeconds
        }
        haptic(.selection)
        onChange()
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
