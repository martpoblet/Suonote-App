import SwiftUI

// MARK: - Editor ruler
/// Bar ruler shared by the piano roll and the drum editor: a thin section
/// color band, the section name where it begins, bar numbers and chords
/// (chords in Erode). Tap or drag to move the playhead.
struct StudioEditorRuler: View {
    let barInfos: [StudioBarSectionInfo]
    let barWidth: CGFloat
    /// Space before bar 1 (e.g. the pinned label column).
    var leadingInset: CGFloat = 0
    var height: CGFloat = 40
    let beatsPerBar: Int
    let onSeek: (Double) -> Void

    @State private var scrubBeat: Double?

    private var totalBeats: Double { Double(max(1, barInfos.count * beatsPerBar)) }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: leadingInset)
            ForEach(barInfos) { info in
                barCell(info)
            }
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    scrubBeat = beat(forX: value.location.x)
                }
                .onEnded { value in
                    onSeek(beat(forX: value.location.x))
                    scrubBeat = nil
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Bar ruler")
        .accessibilityHint("Drag to move the playhead")
    }

    private func barCell(_ info: StudioBarSectionInfo) -> some View {
        let startsSection = info.barIndex == 0
            || barInfos.first(where: { $0.barIndex == info.barIndex - 1 })?.sectionLabel != info.sectionLabel
        return VStack(alignment: .leading, spacing: 2) {
            Rectangle()
                .fill(info.sectionColor.opacity(0.85))
                .frame(height: 3)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(info.barIndex + 1)")
                    .font(DesignSystem.Typography.caption2.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                if let chord = info.chordLabel {
                    Text(chord)
                        .font(DesignSystem.Typography.chordSmall)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                } else if startsSection {
                    Text(info.sectionLabel)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 5)
            Spacer(minLength: 0)
        }
        .frame(width: barWidth, height: height, alignment: .topLeading)
        .background(info.sectionColor.opacity(info.barIndex.isMultiple(of: 2) ? 0.07 : 0.04))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(startsSection ? DesignSystem.Colors.borderActive : DesignSystem.Colors.border)
                .frame(width: 1)
        }
    }

    private func beat(forX x: CGFloat) -> Double {
        let gridX = max(0, x - leadingInset)
        let raw = Double(gridX / max(barWidth, 1)) * Double(beatsPerBar)
        return min(max(0, raw), totalBeats)
    }
}

/// Smooth playhead line for editors (teal, reads the live sequencer position).
struct StudioEditorPlayhead: View {
    let height: CGFloat
    /// Converts a beat to an x position in the editor's content coordinates.
    let xForBeat: (Double) -> CGFloat
    @EnvironmentObject private var playback: StudioPlaybackEngine

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !playback.isPlaying)) { _ in
            let beat = playback.isPlaying ? playback.livePositionBeats() : playback.currentBeat
            let visible = playback.isPlaying || playback.currentBeat > 0
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 2, height: max(0, height))
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 10, height: 10)
                    .offset(y: -4)
            }
            .offset(x: xForBeat(beat) - 1)
            .opacity(visible ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Snap / length grid values expressed in beats with musical labels.
enum StudioGridValue {
    static let snaps: [Double] = [0.25, 0.5, 1, 2]
    static let lengths: [Double] = [0.25, 0.5, 1, 2, 4]

    /// "1/16", "1/8", "1/4"… relative to the meter's beat unit.
    static func label(beats: Double, timeBottom: Int) -> String {
        let denominator = Double(max(1, timeBottom)) / beats
        if denominator >= 1, denominator.rounded() == denominator {
            let value = Int(denominator)
            return "1/\(value)"
        }
        return beats == 1 ? String(localized: "1 beat") : String(localized: "\(beats.formatted()) beats")
    }
}
