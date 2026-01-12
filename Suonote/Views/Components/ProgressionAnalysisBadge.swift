import SwiftUI

// MARK: - Progression Analysis Badge Component

struct ProgressionAnalysisBadge: View {
    let section: SectionTemplate
    let project: Project
    
    private var analysis: ProgressionAnalysis {
        ChordSuggestionEngine.analyzeProgression(
            section.chordEvents,
            inKey: project.keyRoot,
            mode: project.keyMode
        )
    }
    
    private var statusColor: Color {
        if analysis.totalChords == 0 { return .gray }
        if analysis.diatonicPercentage > 80 { return DesignSystem.Colors.success }
        if analysis.diatonicPercentage > 50 { return DesignSystem.Colors.warning }
        return DesignSystem.Colors.error
    }
    
    private var statusIcon: String {
        if analysis.totalChords == 0 { return "music.note" }
        if analysis.diatonicPercentage > 80 { return "checkmark.circle.fill" }
        if analysis.diatonicPercentage > 50 { return "exclamationmark.triangle.fill" }
        return "xmark.circle.fill"
    }
    
    var body: some View {
        if analysis.totalChords > 0 {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: statusIcon)
                    .font(.system(size: 8))
                Text("\(Int(analysis.diatonicPercentage))%")
                    .font(DesignSystem.Typography.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Spacing.xxxs)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.3))
                    .overlay(
                        Capsule().stroke(statusColor, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Chord Count Badge

struct ChordCountBadge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxxs) {
            Image(systemName: "music.note")
                .font(.system(size: 8))
            Text("\(count)")
                .font(DesignSystem.Typography.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xxxs)
        .background(
            Capsule()
                .fill(color.opacity(0.3))
                .overlay(
                    Capsule().stroke(color, lineWidth: 1)
                )
        )
    }
}

// MARK: - Recording Count Badge

struct RecordingCountBadge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxxs) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 8))
            Text("\(count)")
                .font(DesignSystem.Typography.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xxxs)
        .background(
            Capsule()
                .fill(color.opacity(0.3))
                .overlay(
                    Capsule().stroke(color, lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignSystem.Spacing.md) {
        ProgressionAnalysisBadge(
            section: SectionTemplate(name: "Test"),
            project: Project(title: "Test", keyRoot: "C", keyMode: .major, bpm: 120)
        )
        
        ChordCountBadge(count: 8, color: .purple)
    }
    .padding()
    .preferredColorScheme(.dark)
}
