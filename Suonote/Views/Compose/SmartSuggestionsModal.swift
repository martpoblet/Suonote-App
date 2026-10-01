import SwiftUI

// MARK: - Smart suggestions
/// "Ideas" for the current beat: next-chord suggestions with a reason,
/// named progressions in the key (audition or write them in), and a
/// plain-language read of the section's harmony.
struct SmartSuggestionsModal: View {
    let section: SectionTemplate
    let keyRoot: String
    let keyMode: KeyMode
    let barIndex: Int
    let beatsPerBar: Int
    let previousChords: [ChordEvent]
    let nextChords: [ChordEvent]
    let preview: ChordPreviewPlayer
    let onSelect: (ComposeChordValue) -> Void
    let onApplyProgression: ([ComposeChordValue]) -> Void

    @State private var tab: Tab = .next
    @State private var suggestions: [ChordSuggestion] = []
    @State private var progressions: [ComposeProgression] = []
    @State private var insights: [ComposeInsight] = []
    @State private var numerals: [String] = []
    @State private var auditionTask: Task<Void, Never>?
    @State private var playingProgressionId: String?

    enum Tab: String, CaseIterable, Identifiable {
        case next = "Next chord"
        case progressions = "Progressions"
        case analysis = "Analysis"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .next: return String(localized: "Next chord")
            case .progressions: return String(localized: "Progressions")
            case .analysis: return String(localized: "Analysis")
            }
        }
    }

    var body: some View {
        SheetScaffold(
            title: String(localized: "Ideas"),
            subtitle: String(localized: "In \(ComposeFormat.keyName(root: keyRoot, mode: keyMode)) · \(section.name), bar \(barIndex + 1)")
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(Tab.allCases) { item in
                        SelectableChip(title: item.title, isSelected: tab == item) {
                            haptic(.selection)
                            withAnimation(DesignSystem.Animations.quickSpring) { tab = item }
                        }
                    }
                }

                switch tab {
                case .next: nextChordContent
                case .progressions: progressionsContent
                case .analysis: analysisContent
                }
            }
        }
        .onAppear(perform: load)
        .onDisappear {
            auditionTask?.cancel()
            preview.stopAllNotes()
        }
    }

    private func load() {
        suggestions = Array(ChordSuggestionEngine.suggestContextualChords(
            previousChords: previousChords,
            nextChords: nextChords,
            inKey: keyRoot,
            mode: keyMode
        ).prefix(8))
        progressions = ComposeProgressionLibrary.progressions(keyRoot: keyRoot, mode: keyMode)
        insights = ComposeInsightEngine.insights(for: section, beatsPerBar: beatsPerBar)
        let ordered = section.chordEvents.sorted { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) }
        numerals = ComposeInsightEngine.numerals(for: ordered, keyRoot: keyRoot, mode: keyMode)
    }

    // MARK: Next chord

    private var nextChordContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            contextLine

            if suggestions.isEmpty {
                Text("Add a chord or two and ideas will follow.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        if index > 0 { Hairline().padding(.leading, DesignSystem.Spacing.md) }
                        suggestionRow(suggestion)
                    }
                }
                .cardStyle()
            }
        }
    }

    private var contextLine: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(previousChords.suffix(3)) { chord in
                ComposeChordSymbol(value: ComposeChordValue(chord), size: .small)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
            Text("?")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.primaryDark)
                .frame(width: 30, height: 30)
                .background(Circle().fill(DesignSystem.Colors.primaryLight))
            if let next = nextChords.first {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                ComposeChordSymbol(value: ComposeChordValue(next), size: .small)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previousChords.isEmpty ? "Start of the section" : "After \(previousChords.last?.display ?? "")")
    }

    private func suggestionRow(_ suggestion: ChordSuggestion) -> some View {
        let value = ComposeChordValue(suggestion)
        return HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                haptic(.success)
                preview.playChord(root: value.root, quality: value.quality)
                onSelect(value)
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        ComposeChordSymbol(value: value, size: .large)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(suggestion.romanNumeral ?? MusicTheoryUtils.romanNumeral(root: value.root, quality: value.quality, keyRoot: keyRoot, mode: keyMode))
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.primaryDark)
                    }
                    .frame(width: 84, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(fitLabel(suggestion.confidence))
                            .eyebrow(color: fitColor(suggestion.confidence))
                        Text(suggestion.reason)
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(ComposeChordSpeech.spoken(value)). \(fitLabel(suggestion.confidence)). \(suggestion.reason)")
            .accessibilityHint("Double-tap to use this chord")

            Button {
                haptic(.light)
                preview.playChord(root: value.root, quality: value.quality)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(DesignSystem.Colors.surfaceSecondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(value.display)")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private func fitLabel(_ confidence: Double) -> String {
        confidence >= 0.8 ? String(localized: "Strong fit") : confidence >= 0.5 ? String(localized: "Good fit") : String(localized: "Adventurous")
    }

    private func fitColor(_ confidence: Double) -> Color {
        confidence >= 0.8 ? DesignSystem.Colors.primaryDark : confidence >= 0.5 ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent
    }

    // MARK: Progressions

    private var progressionsContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if progressions.isEmpty {
                Text("Named progressions need a major or minor key.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            ForEach(progressions) { progression in
                progressionCard(progression)
            }
        }
    }

    private func progressionCard(_ progression: ComposeProgression) -> some View {
        let isPlaying = playingProgressionId == progression.id
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progression.numerals)
                        .eyebrow(color: DesignSystem.Colors.primaryDark)
                    Text(progression.nickname)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                Spacer(minLength: 0)
                Button {
                    audition(progression)
                } label: {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isPlaying ? DesignSystem.Colors.onPrimary : DesignSystem.Colors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(isPlaying ? DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Stop" : "Play \(progression.nickname)")
            }

            Text(progression.blurb)
                .font(DesignSystem.Typography.italicSmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(progression.chords.enumerated()), id: \.offset) { _, value in
                    Button {
                        haptic(.success)
                        preview.playChord(root: value.root, quality: value.quality)
                        onSelect(value)
                    } label: {
                        ComposeChordSymbol(value: value, size: .small)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                                    .fill(DesignSystem.Colors.surfaceSecondary)
                            )
                    }
                    .buttonStyle(AnimatedPressButtonStyle(scale: 0.95))
                    .accessibilityHint("Double-tap to use this chord")
                }
            }

            Button {
                haptic(.success)
                onApplyProgression(progression.chords)
            } label: {
                Label("Write from bar \(barIndex + 1)", systemImage: "text.badge.plus")
            }
            .buttonStyle(OutlineButtonStyle(compact: true))
            .accessibilityHint("Writes one chord per bar, replacing what’s there. You can undo.")
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func audition(_ progression: ComposeProgression) {
        auditionTask?.cancel()
        if playingProgressionId == progression.id {
            playingProgressionId = nil
            preview.stopAllNotes()
            return
        }
        haptic(.light)
        playingProgressionId = progression.id
        auditionTask = Task { @MainActor in
            for value in progression.chords {
                guard !Task.isCancelled else { return }
                preview.playChord(root: value.root, quality: value.quality, duration: 0.85)
                try? await Task.sleep(for: .milliseconds(900))
            }
            if !Task.isCancelled { playingProgressionId = nil }
        }
    }

    // MARK: Analysis

    private var analysisContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if numerals.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Nothing to read yet")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Write a few chords in \(section.name) and this page will tell you what they’re doing.")
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Roman numerals")
                        .eyebrow()
                    ComposeFlowLayout(spacing: 10, lineSpacing: 6) {
                        ForEach(Array(numerals.enumerated()), id: \.offset) { _, numeral in
                            Text(numeral)
                                .font(DesignSystem.Typography.title3)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .accessibilityElement(children: .combine)

                VStack(spacing: 0) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        if index > 0 { Hairline().padding(.leading, 52) }
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: insight.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.primaryDark)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(DesignSystem.Colors.primaryLight))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title)
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text(insight.detail)
                                    .font(DesignSystem.Typography.callout)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .accessibilityElement(children: .combine)
                    }
                }
                .cardStyle()
            }
        }
    }
}
