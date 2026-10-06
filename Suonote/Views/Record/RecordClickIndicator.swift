import SwiftUI

/// Where the visual click is in the bar: which beat is lit and how much of
/// its flash is left. Read from the take's beat clock every frame, so the
/// light lands with the sound rather than with a UI timer.
private struct RecordBeatState {
    /// Beat within the bar, or nil before the first click.
    let beat: Int?
    /// 1 right on the click, fading to 0 over the first third of the beat.
    let flash: Double

    init(clock: RecordBeatClock?, beatsPerBar: Int) {
        guard let clock else {
            beat = nil
            flash = 0
            return
        }
        let position = clock.heardBeats()
        guard position >= 0 else {
            beat = nil
            flash = 0
            return
        }
        let whole = position.rounded(.down)
        beat = Int(whole) % max(1, beatsPerBar)
        flash = max(0, 1 - (position - whole) / 0.33)
    }
}

/// One light per beat of the bar. The current beat flashes on the click and
/// "one" is drawn bigger and in the accent color, so the pulse is readable
/// at a glance even with the click off.
struct RecordBeatLights: View {
    let clock: RecordBeatClock?
    let beatsPerBar: Int
    let tint: Color
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: clock == nil)) { _ in
            let state = RecordBeatState(clock: clock, beatsPerBar: beatsPerBar)
            HStack(spacing: 8) {
                ForEach(0..<max(1, beatsPerBar), id: \.self) { beat in
                    light(beat: beat, state: state)
                }
            }
        }
        .frame(maxWidth: 340)
        .accessibilityHidden(true)
    }

    private func light(beat: Int, state: RecordBeatState) -> some View {
        let isCurrent = state.beat == beat
        let hasPassed = (state.beat ?? -1) > beat
        let color = beat == 0 ? accent : tint
        let flash = isCurrent ? state.flash : 0

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isCurrent ? color : (hasPassed ? color.opacity(0.22) : DesignSystem.Colors.surfaceSecondary))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isCurrent ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
            )
            .overlay(
                Text("\(beat + 1)")
                    .font(DesignSystem.Typography.calloutBold)
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? DesignSystem.Colors.background : DesignSystem.Colors.textTertiary)
            )
            .frame(height: beat == 0 ? 48 : 40)
            .frame(maxWidth: .infinity)
            .opacity(isCurrent ? 0.6 + 0.4 * flash : 1)
            .scaleEffect(isCurrent && !reduceMotion ? 1 + 0.12 * flash : 1)
            .shadow(color: isCurrent ? color.opacity(0.45 * flash) : .clear, radius: 12)
    }
}

/// A ring that blooms out from the count-in number on every click — bigger
/// and in the accent color on "one".
struct RecordClickPulse: View {
    let clock: RecordBeatClock?
    let beatsPerBar: Int
    let tint: Color
    let accent: Color
    var size: CGFloat = 220

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: clock == nil)) { _ in
            let state = RecordBeatState(clock: clock, beatsPerBar: beatsPerBar)
            let isOne = state.beat == 0
            let color = isOne ? accent : tint
            let bloom = reduceMotion ? 0 : 1 - state.flash

            ZStack {
                Circle()
                    .fill(color.opacity(0.14 * state.flash))
                Circle()
                    .strokeBorder(color.opacity(0.85 * state.flash), lineWidth: isOne ? 4 : 2.5)
                    .scaleEffect(0.86 + 0.2 * bloom)
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}
