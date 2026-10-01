import SwiftUI

// MARK: - Progression Analysis Badge
/// Quiet chip summarising a section's harmony: the progression's nickname
/// when it's a known one ("The Axis"), otherwise how much sits in the key.
struct ProgressionAnalysisBadge: View {
    let section: SectionTemplate
    let project: Project

    var body: some View {
        if let text = ComposeInsightEngine.badge(for: section) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                Text(text)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(DesignSystem.Colors.primaryLight.opacity(0.7)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Harmony: \(text)")
        }
    }
}

// MARK: - Chord Count Badge

struct ChordCountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        AppChip(
            text: "\(count)",
            icon: "music.note",
            tint: color,
            textColor: DesignSystem.Colors.textSecondary,
            font: DesignSystem.Typography.caption2
        )
        .accessibilityLabel("\(count) chords")
    }
}

// MARK: - Recording Count Badge

struct RecordingCountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        AppChip(
            text: "\(count)",
            icon: "waveform",
            tint: color,
            textColor: DesignSystem.Colors.textSecondary,
            font: DesignSystem.Typography.caption2
        )
        .accessibilityLabel("\(count) recordings")
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.md) {
        ProgressionAnalysisBadge(
            section: SectionTemplate(name: "Test"),
            project: Project(title: "Test", keyRoot: "C", keyMode: .major, bpm: 120)
        )
        ChordCountBadge(count: 8, color: DesignSystem.Colors.primary)
        RecordingCountBadge(count: 2, color: DesignSystem.Colors.accent)
    }
    .padding()
    .paperBackground()
}
