import SwiftUI

/// Interactive circle of fifths: majors on the outer ring, relative minors
/// inside. Selected key in ink; neighbours (closely related keys) get a hint.
struct CircleOfFifthsView: View {
    let currentKey: String
    let currentMode: KeyMode
    let onKeySelected: (String, KeyMode) -> Void

    private let majorKeys = ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]
    private let minorKeys = ["A", "E", "B", "F#", "C#", "G#", "Eb", "Bb", "F", "C", "G", "D"]

    private var selectedIndex: Int? {
        let keys = currentMode.isMinor ? minorKeys : majorKeys
        return keys.firstIndex { MusicTheory.normalize($0) == MusicTheory.normalize(currentKey) }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = size * 0.41
            let innerRadius = size * 0.26

            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(center)
                Circle()
                    .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .position(center)

                ForEach(0..<12, id: \.self) { index in
                    let key = majorKeys[index]
                    keyButton(
                        label: key.replacingOccurrences(of: "b", with: "♭").replacingOccurrences(of: "#", with: "♯"),
                        position: point(center: center, radius: outerRadius, index: index),
                        isSelected: !currentMode.isMinor && selectedIndex == index,
                        isRelated: isRelated(index),
                        isMajor: true
                    ) {
                        onKeySelected(MusicTheory.normalize(key), .major)
                    }
                    .accessibilityLabel("\(key) major")
                }

                ForEach(0..<12, id: \.self) { index in
                    let key = minorKeys[index]
                    keyButton(
                        label: key.replacingOccurrences(of: "b", with: "♭").replacingOccurrences(of: "#", with: "♯") + "m",
                        position: point(center: center, radius: innerRadius, index: index),
                        isSelected: currentMode.isMinor && selectedIndex == index,
                        isRelated: isRelated(index),
                        isMajor: false
                    ) {
                        onKeySelected(MusicTheory.normalize(key), .minor)
                    }
                    .accessibilityLabel("\(key) minor")
                }

                Text("5ths")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .position(center)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func isRelated(_ index: Int) -> Bool {
        guard let selectedIndex else { return false }
        let distance = abs(index - selectedIndex)
        return min(distance, 12 - distance) == 1 || index == selectedIndex
    }

    private func keyButton(
        label: String,
        position: CGPoint,
        isSelected: Bool,
        isRelated: Bool,
        isMajor: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            haptic(.selection)
            action()
        } label: {
            Text(label)
                .font(isMajor ? DesignSystem.Typography.chordSmall : DesignSystem.Typography.caption)
                .foregroundStyle(isSelected ? DesignSystem.Colors.background : (isMajor ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: isMajor ? 42 : 36, height: isMajor ? 42 : 36)
                .background(
                    Circle().fill(
                        isSelected ? DesignSystem.Colors.textPrimary
                            : (isRelated ? DesignSystem.Colors.primaryLight : DesignSystem.Colors.surface)
                    )
                )
                .overlay(Circle().stroke(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1))
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.92))
        .position(position)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func point(center: CGPoint, radius: CGFloat, index: Int) -> CGPoint {
        let radians = (Double(index) * 30.0 - 90.0) * .pi / 180.0
        return CGPoint(x: center.x + radius * CGFloat(cos(radians)), y: center.y + radius * CGFloat(sin(radians)))
    }
}
