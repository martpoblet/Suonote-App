import SwiftUI

/// A section on the lyrics page: colored rule, name in Erode, the chords as a
/// quiet reference, then the words set like a printed lyric sheet with a
/// syllable count in the margin.
struct LyricsSectionBlock: View {
    let section: SectionTemplate
    let usageCount: Int
    var showSyllables: Bool = true
    let onEdit: () -> Void

    private var lines: [String] {
        section.lyricsText.components(separatedBy: .newlines)
    }

    private var nonEmptyLineCount: Int {
        LyricsAnalysis.lines(section.lyricsText).count
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(section.color)
                    .frame(width: 3)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    header

                    if let bars = section.lyricsChordBars {
                        LyricsChordLine(bars: bars)
                    }

                    if section.lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Tap to write this section…")
                            .font(DesignSystem.Typography.italic)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.top, 2)
                    } else {
                        lyricLines
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.99))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens the writing page")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
            Text(section.name)
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
            if usageCount > 1 {
                Text("×\(usageCount)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            Spacer(minLength: DesignSystem.Spacing.xs)
            Text(metaLine)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .lineLimit(1)
            Image(systemName: "pencil.line")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    private var metaLine: String {
        let count = nonEmptyLineCount
        if count == 0 { return String(localized: "\(section.bars) bars") }
        return String(localized: "\(count) lines")
    }

    private var lyricLines: some View {
        VStack(alignment: .leading, spacing: LyricsType.lineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    // Stanza break
                    Color.clear.frame(height: 6)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                        Text(trimmed)
                            .font(LyricsType.lyric)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if showSyllables {
                            Text("\(LyricsAnalysis.syllables(inLine: trimmed))")
                                .font(DesignSystem.Typography.caption2.monospacedDigit())
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .frame(minWidth: 18, alignment: .trailing)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
    }

    private var accessibilitySummary: String {
        let lyric = section.lyricsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if lyric.isEmpty { return String(localized: "\(section.name), no lyrics yet") }
        return String(localized: "\(section.name), \(nonEmptyLineCount) lines. \(lyric)")
    }
}
