import SwiftUI

// MARK: - Pedalboard
/// The effect chain as a row of pedals: each has a bypass switch with an
/// LED, and knobs that show their value. Used inline in the take detail and
/// in `AudioEffectsSheet`.

struct RecordPedalboard: View {
    @Binding var settings: AudioEffectsProcessor.EffectSettings
    /// Called after any change (to re-apply effects live).
    var onChange: () -> Void = {}

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            RecordPedal(
                title: String(localized: "Reverb"),
                subtitle: String(localized: "Space around the sound"),
                icon: "dot.radiowaves.left.and.right",
                isOn: binding(\.reverbEnabled)
            ) {
                RecordKnob(label: String(localized: "Mix"), value: binding(\.reverbMix), range: 0...1, defaultValue: 0.5,
                           isOn: settings.reverbEnabled, format: Self.percent)
                RecordKnob(label: String(localized: "Room"), value: binding(\.reverbSize), range: 0...1, defaultValue: 0.5,
                           isOn: settings.reverbEnabled, format: Self.roomName)
            }

            RecordPedal(
                title: String(localized: "Delay"),
                subtitle: String(localized: "Echoes that repeat"),
                icon: "repeat",
                isOn: binding(\.delayEnabled)
            ) {
                RecordKnob(label: String(localized: "Time"), value: binding(\.delayTime), range: 0.1...2.0, defaultValue: 0.3,
                           isOn: settings.delayEnabled, format: { String(format: "%.2f s", $0) })
                RecordKnob(label: String(localized: "Feedback"), value: binding(\.delayFeedback), range: 0...0.9, defaultValue: 0.3,
                           isOn: settings.delayEnabled, format: Self.percent)
                RecordKnob(label: String(localized: "Mix"), value: binding(\.delayMix), range: 0...1, defaultValue: 0.3,
                           isOn: settings.delayEnabled, format: Self.percent)
            }

            RecordPedal(
                title: String(localized: "Equalizer"),
                subtitle: String(localized: "Low 80 Hz · Mid 1 kHz · High 10 kHz"),
                icon: "slider.vertical.3",
                isOn: binding(\.eqEnabled)
            ) {
                RecordKnob(label: String(localized: "Low"), value: binding(\.lowGain), range: -24...24, defaultValue: 0,
                           isOn: settings.eqEnabled, bipolar: true, format: Self.decibels)
                RecordKnob(label: String(localized: "Mid"), value: binding(\.midGain), range: -24...24, defaultValue: 0,
                           isOn: settings.eqEnabled, bipolar: true, format: Self.decibels)
                RecordKnob(label: String(localized: "High"), value: binding(\.highGain), range: -24...24, defaultValue: 0,
                           isOn: settings.eqEnabled, bipolar: true, format: Self.decibels)
            }

            RecordPedal(
                title: String(localized: "Compressor"),
                subtitle: String(localized: "Evens out the loud and the quiet"),
                icon: "waveform.badge.minus",
                isOn: binding(\.compressionEnabled)
            ) {
                RecordKnob(label: String(localized: "Threshold"), value: binding(\.compressionThreshold), range: -40...0, defaultValue: -20,
                           isOn: settings.compressionEnabled, format: { String(format: "%.0f dB", $0) })
                RecordKnob(label: String(localized: "Ratio"), value: binding(\.compressionRatio), range: 1...20, defaultValue: 4,
                           isOn: settings.compressionEnabled, format: { String(format: "%.1f:1", $0) })
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AudioEffectsProcessor.EffectSettings, T>) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                onChange()
            }
        )
    }

    nonisolated static func percent(_ value: Float) -> String { "\(Int((value * 100).rounded()))%" }

    nonisolated static func decibels(_ value: Float) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded) dB" : "\(rounded) dB"
    }

    nonisolated static func roomName(_ value: Float) -> String {
        value < 0.3 ? String(localized: "Room") : (value < 0.7 ? String(localized: "Hall") : String(localized: "Cathedral"))
    }
}

// MARK: - Pedal

struct RecordPedal<Knobs: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    @ViewBuilder let knobs: Knobs

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .fill(isOn ? DesignSystem.Colors.primaryLight : DesignSystem.Colors.surfaceSecondary)
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textTertiary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Circle()
                            .fill(isOn ? DesignSystem.Colors.brand : DesignSystem.Colors.borderActive)
                            .frame(width: 7, height: 7)
                            .shadow(color: isOn ? DesignSystem.Colors.brand.opacity(0.7) : .clear, radius: 4)
                            .accessibilityHidden(true)
                    }
                    Text(isOn ? subtitle : String(localized: "Bypassed"))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                Toggle(isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        HapticFeedback.light.trigger()
                        withAnimation(DesignSystem.Animations.quickSpring) { isOn = newValue }
                    }
                )) {
                    Text(title)
                }
                .labelsHidden()
                .tint(DesignSystem.Colors.primary)
                .accessibilityLabel("\(title) pedal")
                .accessibilityValue(isOn ? "On" : "Bypassed")
            }

            HStack(alignment: .top, spacing: 0) {
                knobs
            }
            .frame(maxWidth: .infinity)
            .opacity(isOn ? 1 : 0.45)
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: isOn ? DesignSystem.Colors.primary.opacity(0.35) : nil)
    }
}

// MARK: - Knob

/// Rotary control: drag up/down (or swipe with VoiceOver) to change,
/// double-tap to reset. Shows its value under the dial.
struct RecordKnob: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var defaultValue: Float
    var isOn: Bool = true
    var bipolar: Bool = false
    var format: (Float) -> String

    @State private var dragStart: Float?
    private let size: CGFloat = 54
    private let sweep: Double = 270

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return Double((min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / span)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .eyebrow()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.surfaceSecondary)
                Circle()
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)

                arc(from: 0, to: 1)
                    .stroke(DesignSystem.Colors.border, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(-6)

                valueArc
                    .stroke(isOn ? DesignSystem.Colors.primary : DesignSystem.Colors.textTertiary,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(-6)

                // Pointer
                Capsule()
                    .fill(DesignSystem.Colors.textPrimary)
                    .frame(width: 2.5, height: size * 0.28)
                    .offset(y: -size * 0.22)
                    .rotationEffect(.degrees(-sweep / 2 + sweep * fraction))
            }
            .frame(width: size, height: size)
            .padding(6)
            .contentShape(Circle())
            .gesture(dragGesture)
            .onTapGesture(count: 2) {
                HapticFeedback.light.trigger()
                withAnimation(DesignSystem.Animations.quickSpring) { value = defaultValue }
            }

            Text(format(value))
                .font(DesignSystem.Typography.caption.monospacedDigit())
                .foregroundStyle(isOn ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityHint("Swipe up or down to adjust. Double tap the dial to reset.")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { drag in
                let start = dragStart ?? value
                if dragStart == nil {
                    dragStart = value
                    HapticFeedback.selection.trigger()
                }
                let span = range.upperBound - range.lowerBound
                // 160 pt of vertical travel covers the full range.
                let delta = Float(-drag.translation.height / 160) * span
                value = min(range.upperBound, max(range.lowerBound, start + delta))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var valueArc: some Shape {
        if bipolar {
            let center = 0.5
            return arc(from: min(center, fraction), to: max(center, fraction))
        }
        return arc(from: 0, to: fraction)
    }

    /// Arc over the knob's sweep, `from`/`to` in 0...1 of the sweep.
    private func arc(from start: Double, to end: Double) -> RecordArc {
        RecordArc(start: start, end: end, sweep: sweep)
    }
}

struct RecordArc: Shape {
    var start: Double
    var end: Double
    var sweep: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let begin = 90 + (360 - sweep) / 2 // 135° = bottom-left
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(begin + sweep * start),
            endAngle: .degrees(begin + sweep * max(start, end)),
            clockwise: false
        )
        return path
    }
}
