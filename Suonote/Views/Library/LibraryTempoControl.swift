import SwiftUI

// MARK: - BPM Selector
/// Tempo control shared by the create and edit sheets:
/// big Erode figure, tempo marking, ±1 steppers, slider, tap tempo,
/// metronome preview and quick presets.
/// API kept stable: `BPMSelector(bpm:timeTop:timeBottom:)`.
struct BPMSelector: View {
    @Binding var bpm: Int
    let timeTop: Int
    let timeBottom: Int
    @StateObject private var tempoPreviewer = TempoPreviewer()
    @State private var tapTempo = TapTempo()
    @State private var tapPulse = false

    private let presets = [70, 90, 110, 120, 140]
    private let bpmRange = 40...240

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            display
            slider
            Hairline()
            HStack(spacing: DesignSystem.Spacing.sm) {
                tapButton
                Spacer(minLength: 0)
                TempoPreviewButton(
                    previewer: tempoPreviewer,
                    bpm: bpm,
                    timeTop: timeTop,
                    timeBottom: timeBottom,
                    tint: DesignSystem.Colors.primary,
                    label: "Listen"
                )
            }
            presetRow
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    // MARK: Pieces

    private var display: some View {
        HStack(alignment: .center) {
            stepButton("minus", label: "Slower", enabled: bpm > bpmRange.lowerBound) { adjust(-1) }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(bpm)")
                        .font(DesignSystem.Typography.displayLarge)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(bpm)))
                        .scaleEffect(tapPulse ? 1.04 : 1)
                    Text("BPM")
                        .eyebrow()
                }
                Text(Self.marking(for: bpm))
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .contentTransition(.opacity)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue(String(localized: "\(bpm) beats per minute, \(Self.marking(for: bpm))"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjust(1)
                case .decrement: adjust(-1)
                @unknown default: break
                }
            }
            Spacer(minLength: 0)
            stepButton("plus", label: "Faster", enabled: bpm < bpmRange.upperBound) { adjust(1) }
        }
        .animation(DesignSystem.Animations.quickSpring, value: bpm)
    }

    private var slider: some View {
        Slider(
            value: Binding(
                get: { Double(bpm) },
                set: { bpm = Int($0.rounded()) }
            ),
            in: Double(bpmRange.lowerBound)...Double(bpmRange.upperBound),
            step: 1
        )
        .tint(DesignSystem.Colors.primary)
        .accessibilityHidden(true)
    }

    private var tapButton: some View {
        Button {
            tapTempo.tap()
            HapticFeedback.light.trigger()
            if tapTempo.tapCount >= 2 {
                bpm = min(max(tapTempo.currentBPM, bpmRange.lowerBound), bpmRange.upperBound)
            }
            withAnimation(DesignSystem.Animations.quickSpring) { tapPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(DesignSystem.Animations.quickSpring) { tapPulse = false }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 13, weight: .semibold))
                Text("Tap tempo")
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < min(tapTempo.tapCount, 4)
                                  ? DesignSystem.Colors.primary
                                  : DesignSystem.Colors.border)
                            .frame(width: 5, height: 5)
                    }
                }
                .animation(DesignSystem.Animations.quickSpring, value: tapTempo.tapCount)
            }
        }
        .buttonStyle(OutlineButtonStyle(compact: true))
        .accessibilityHint("Tap repeatedly in time to set the tempo")
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.self) { preset in
                Button {
                    HapticFeedback.selection.trigger()
                    tapTempo.reset()
                    bpm = preset
                } label: {
                    Text("\(preset)")
                        .font(DesignSystem.Typography.buttonSmall)
                        .monospacedDigit()
                        .foregroundStyle(bpm == preset ? DesignSystem.Colors.background : DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(bpm == preset ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surfaceSecondary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset) BPM")
            }
        }
    }

    private func stepButton(_ icon: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textMuted)
                .frame(width: 44, height: 44)
                .background(Circle().fill(DesignSystem.Colors.surfaceSecondary))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func adjust(_ delta: Int) {
        bpm = min(max(bpm + delta, bpmRange.lowerBound), bpmRange.upperBound)
        HapticFeedback.selection.trigger()
    }

    /// Classical tempo marking, used as an italic caption.
    static func marking(for bpm: Int) -> String {
        switch bpm {
        case ..<60: return String(localized: "Largo", comment: "Tempo marking")
        case 60..<76: return String(localized: "Adagio", comment: "Tempo marking")
        case 76..<108: return String(localized: "Andante", comment: "Tempo marking")
        case 108..<120: return String(localized: "Moderato", comment: "Tempo marking")
        case 120..<156: return String(localized: "Allegro", comment: "Tempo marking")
        case 156..<176: return String(localized: "Vivace", comment: "Tempo marking")
        default: return String(localized: "Presto", comment: "Tempo marking")
        }
    }
}
