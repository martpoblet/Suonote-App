import SwiftUI

/// Accessibility helpers and modifiers (U-01)

// MARK: - Dynamic Type Support

extension View {
    /// Apply accessibility-friendly scaling to fixed-size elements
    @ViewBuilder
    func accessibleFrame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                         minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil) -> some View {
        self.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth,
                   minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight)
    }
    
    /// Standard accessibility label for chord chips
    func chordAccessibility(root: String, quality: ChordQuality) -> some View {
        self
            .accessibilityLabel("\(root) \(quality.displayName) chord")
            .accessibilityHint("Double-tap to select this chord")
    }
    
    /// Standard accessibility for section headers
    func sectionAccessibility(name: String, bars: Int, chordCount: Int) -> some View {
        self
            .accessibilityLabel("\(name) section, \(bars) bars, \(chordCount) chords")
    }
    
    /// Standard accessibility for playback controls
    func playbackAccessibility(isPlaying: Bool) -> some View {
        self
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityHint(isPlaying ? "Double-tap to pause playback" : "Double-tap to start playback")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Color Blind Friendly Indicators

struct ColorBlindIndicator: View {
    let status: ProjectStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.rawValue)
                .font(.caption2)
        }
        .foregroundStyle(status.swiftUIColor)
        .accessibilityLabel("\(status.rawValue) status")
    }
}

// MARK: - Accessible Beat Indicator (U-09)

struct BeatIndicatorView: View {
    let currentBeat: Double
    let beatsPerBar: Int
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<beatsPerBar, id: \.self) { beat in
                Circle()
                    .fill(isCurrentBeat(beat) ? Color.accentColor : Color(.systemGray4))
                    .frame(width: isCurrentBeat(beat) ? 12 : 8,
                           height: isCurrentBeat(beat) ? 12 : 8)
                    .scaleEffect(isCurrentBeat(beat) ? 1.2 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: currentBeat)
            }
        }
        .accessibilityLabel("Beat \(currentBeatIndex + 1) of \(beatsPerBar)")
    }
    
    private var currentBeatIndex: Int {
        Int(currentBeat.truncatingRemainder(dividingBy: Double(beatsPerBar)))
    }
    
    private func isCurrentBeat(_ beat: Int) -> Bool {
        guard isPlaying else { return beat == 0 }
        return beat == currentBeatIndex
    }
}

// MARK: - Accessible Chord Chip

struct AccessibleChordChip: View {
    let root: String
    let quality: ChordQuality
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(root)\(quality.rawValue)")
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .chordAccessibility(root: root, quality: quality)
    }
}
