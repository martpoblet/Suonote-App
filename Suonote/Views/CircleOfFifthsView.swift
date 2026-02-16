import SwiftUI

/// Interactive Circle of Fifths for key/chord exploration (M-08)
struct CircleOfFifthsView: View {
    let currentKey: String
    let currentMode: KeyMode
    let onKeySelected: (String, KeyMode) -> Void
    
    private let majorKeys = ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]
    private let minorKeys = ["A", "E", "B", "F#", "C#", "G#", "Eb", "Bb", "F", "C", "G", "D"]
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = size * 0.42
            let innerRadius = size * 0.28
            
            ZStack {
                // Outer ring: Major keys
                ForEach(0..<12, id: \.self) { index in
                    let angle = angleFor(index: index)
                    let pos = pointOn(center: center, radius: outerRadius, angle: angle)
                    let key = majorKeys[index]
                    let isSelected = key == currentKey && !currentMode.isMinor
                    
                    keyButton(label: key, position: pos, isSelected: isSelected, isMajor: true) {
                        onKeySelected(key, .major)
                    }
                }
                
                // Inner ring: Minor keys
                ForEach(0..<12, id: \.self) { index in
                    let angle = angleFor(index: index)
                    let pos = pointOn(center: center, radius: innerRadius, angle: angle)
                    let key = minorKeys[index]
                    let isSelected = key == currentKey && currentMode.isMinor
                    
                    keyButton(label: "\(key)m", position: pos, isSelected: isSelected, isMajor: false) {
                        onKeySelected(key, .minor)
                    }
                }
                
                // Center label
                Text("5ths")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .position(center)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func keyButton(label: String, position: CGPoint, isSelected: Bool, isMajor: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(isMajor ? .system(size: 14, weight: .semibold) : .system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .white : (isMajor ? .primary : .secondary))
                .frame(width: isMajor ? 36 : 30, height: isMajor ? 36 : 30)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
        .position(position)
    }
    
    private func angleFor(index: Int) -> Double {
        // Start at top (-90°), go clockwise, 30° per step
        return Double(index) * 30.0 - 90.0
    }
    
    private func pointOn(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let rad = angle * .pi / 180.0
        return CGPoint(
            x: center.x + radius * CGFloat(cos(rad)),
            y: center.y + radius * CGFloat(sin(rad))
        )
    }
}
