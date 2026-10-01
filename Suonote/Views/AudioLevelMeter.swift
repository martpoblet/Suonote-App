import SwiftUI

/// Input level meter with a peak-hold tick and clipping indicator (P-09).
/// Brand teal while healthy, warm as it gets hot, record red when clipping.
struct AudioLevelMeter: View {
    let level: Float  // 0.0 to 1.0
    let peakLevel: Float
    var orientation: Orientation = .vertical
    var showClipping: Bool = true
    var thickness: CGFloat = 8

    enum Orientation {
        case vertical, horizontal
    }

    private var clipping: Bool {
        peakLevel >= 0.95
    }

    private var clampedLevel: CGFloat { CGFloat(max(0, min(1, level))) }
    private var clampedPeak: CGFloat { CGFloat(max(0, min(1, peakLevel))) }

    var body: some View {
        GeometryReader { geo in
            let length = orientation == .horizontal ? geo.size.width : geo.size.height
            ZStack(alignment: orientation == .vertical ? .bottom : .leading) {
                Capsule()
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .overlay(Capsule().stroke(DesignSystem.Colors.border, lineWidth: 0.5))

                Capsule()
                    .fill(levelGradient)
                    .mask(alignment: orientation == .vertical ? .bottom : .leading) {
                        Rectangle().frame(
                            width: orientation == .horizontal ? length * clampedLevel : nil,
                            height: orientation == .vertical ? length * clampedLevel : nil
                        )
                    }
                    .animation(.linear(duration: 0.06), value: level)

                // Peak-hold tick
                if clampedPeak > 0.02 {
                    Capsule()
                        .fill(clipping && showClipping ? DesignSystem.Colors.record : DesignSystem.Colors.textPrimary.opacity(0.55))
                        .frame(
                            width: orientation == .horizontal ? 2 : nil,
                            height: orientation == .vertical ? 2 : nil
                        )
                        .offset(
                            x: orientation == .horizontal ? max(0, length * clampedPeak - 2) : 0,
                            y: orientation == .vertical ? -max(0, length * clampedPeak - 2) : 0
                        )
                }
            }
            .overlay(alignment: orientation == .vertical ? .top : .trailing) {
                if showClipping && clipping {
                    Circle()
                        .fill(DesignSystem.Colors.record)
                        .frame(width: thickness, height: thickness)
                        .offset(
                            x: orientation == .horizontal ? thickness + 4 : 0,
                            y: orientation == .vertical ? -(thickness + 4) : 0
                        )
                }
            }
        }
        .frame(
            width: orientation == .vertical ? thickness : nil,
            height: orientation == .horizontal ? thickness : nil
        )
        .accessibilityElement()
        .accessibilityLabel("Input level")
        .accessibilityValue(clipping ? "Clipping" : "\(Int(clampedLevel * 100)) percent")
    }

    private var levelGradient: LinearGradient {
        let colors: [Color] = [
            DesignSystem.Colors.brand,
            DesignSystem.Colors.brand,
            DesignSystem.Colors.warning,
            DesignSystem.Colors.record
        ]
        let startPoint: UnitPoint = orientation == .vertical ? .bottom : .leading
        let endPoint: UnitPoint = orientation == .vertical ? .top : .trailing
        return LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
}

/// Stereo meter pair
struct StereoMeterView: View {
    let leftLevel: Float
    let rightLevel: Float
    let leftPeak: Float
    let rightPeak: Float

    var body: some View {
        HStack(spacing: 2) {
            AudioLevelMeter(level: leftLevel, peakLevel: leftPeak)
            AudioLevelMeter(level: rightLevel, peakLevel: rightPeak)
        }
        .frame(width: 20)
    }
}
