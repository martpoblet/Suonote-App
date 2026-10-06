import SwiftUI

// MARK: - Immersive Lyrics Editor
/// Distraction-free writing page. One section at a time, chords as a quiet
/// reference, counts at the bottom, an optional rhyme-scheme margin, and
/// quick navigation between sections. Text binds straight to
/// `section.lyricsText` (saved by SwiftData like everywhere else).

struct ImmersiveLyricsEditor: View {
    let sections: [SectionTemplate]
    var onDismiss: () -> Void

    @State private var index: Int
    @State private var showRhymes = false
    @FocusState private var isTextEditorFocused: Bool

    init(sections: [SectionTemplate], startIndex: Int = 0, onDismiss: @escaping () -> Void) {
        self.sections = sections
        self.onDismiss = onDismiss
        self._index = State(initialValue: min(max(0, startIndex), max(0, sections.count - 1)))
    }

    /// Single-section convenience.
    init(section: SectionTemplate, onDismiss: @escaping () -> Void) {
        self.init(sections: [section], startIndex: 0, onDismiss: onDismiss)
    }

    private var section: SectionTemplate? {
        sections.indices.contains(index) ? sections[index] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)

            if let section {
                LyricsWritingPage(
                    section: section,
                    position: index + 1,
                    total: sections.count,
                    showRhymes: showRhymes,
                    focus: $isTextEditorFocused
                )
                .id(section.id)
                .transition(.opacity)

                bottomBar(for: section)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
            } else {
                Spacer()
            }
        }
        .background(background.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                isTextEditorFocused = true
            }
        }
    }

    private var background: some View {
        ZStack {
            DesignSystem.Colors.background
            LinearGradient(
                colors: [(section?.color ?? .clear).opacity(0.10), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.35)
            )
        }
        .animation(DesignSystem.Animations.gentleEase, value: index)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                isTextEditorFocused = false
                HapticFeedback.light.trigger()
                onDismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close writing page")

            Spacer(minLength: 0)

            if sections.count > 1 {
                Menu {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { offset, item in
                        Button {
                            go(to: offset)
                        } label: {
                            if offset == index {
                                Label(item.name, systemImage: "checkmark")
                            } else {
                                Text(item.name)
                            }
                        }
                    }
                } label: {
                    sectionPill
                }
                .accessibilityLabel("Jump to section, current \(section?.name ?? "")")
            } else {
                sectionPill
            }

            Spacer(minLength: 0)

            rhymeButton
        }
    }

    @ViewBuilder
    private var rhymeButton: some View {
        let toggle = {
            HapticFeedback.selection.trigger()
            withAnimation(DesignSystem.Animations.smoothSpring) { showRhymes.toggle() }
        }
        let icon = Image(systemName: "textformat.abc")
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 36, height: 36)
        Group {
            if showRhymes {
                Button(action: toggle) { icon.foregroundStyle(DesignSystem.Colors.onPrimary) }
                    .buttonStyle(.glassProminent)
                    .tint(DesignSystem.Colors.primary)
            } else {
                Button(action: toggle) { icon.foregroundStyle(DesignSystem.Colors.textPrimary) }
                    .buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.circle)
        .accessibilityLabel("Rhyme scheme")
        .accessibilityValue(showRhymes ? "Shown" : "Hidden")
    }

    private var sectionPill: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            SectionColorDot(section?.color ?? DesignSystem.Colors.border, size: 8)
            Text(section?.name ?? "")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
            if sections.count > 1 {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Bottom bar

    private func bottomBar(for section: SectionTemplate) -> some View {
        let lines = LyricsAnalysis.lines(section.lyricsText)
        let words = LyricsAnalysis.wordCount(section.lyricsText)
        let syllables = lines.map { LyricsAnalysis.syllables(inLine: $0) }
        let average = syllables.isEmpty ? 0 : Int((Double(syllables.reduce(0, +)) / Double(syllables.count)).rounded())

        return HStack(spacing: DesignSystem.Spacing.sm) {
            navButton(icon: "chevron.left", label: "Previous section", enabled: index > 0) {
                go(to: index - 1)
            }

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("\(lines.count) line\(lines.count == 1 ? "" : "s") · \(words) word\(words == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.calloutBold)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(lines.isEmpty ? "Section \(index + 1) of \(sections.count)" : "≈ \(average) syllables a line")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if isTextEditorFocused {
                Button("Done") {
                    isTextEditorFocused = false
                }
                .font(DesignSystem.Typography.buttonSmall)
                .buttonStyle(.glassProminent)
                .tint(DesignSystem.Colors.textPrimary)
                .accessibilityLabel("Hide keyboard")
            } else {
                navButton(icon: "chevron.right", label: "Next section", enabled: index < sections.count - 1) {
                    go(to: index + 1)
                }
            }
        }
        .animation(DesignSystem.Animations.quickSpring, value: isTextEditorFocused)
    }

    private func navButton(icon: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textMuted)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func go(to newIndex: Int) {
        guard sections.indices.contains(newIndex), newIndex != index else { return }
        HapticFeedback.selection.trigger()
        withAnimation(DesignSystem.Animations.smoothEase) { index = newIndex }
    }
}

// MARK: - Writing page

private struct LyricsWritingPage: View {
    @Bindable var section: SectionTemplate
    let position: Int
    let total: Int
    let showRhymes: Bool
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(total > 1 ? "Section \(position) of \(total)" : "Lyrics").eyebrow()
                Text(section.name)
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                if let bars = section.lyricsChordBars {
                    LyricsChordLine(bars: bars, lineLimit: 3)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter + 4)
            .padding(.top, DesignSystem.Spacing.md)

            Hairline()
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.top, DesignSystem.Spacing.md)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $section.lyricsText)
                    .font(LyricsType.lyric)
                    .lineSpacing(LyricsType.lineSpacing)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .tint(DesignSystem.Colors.primaryDark)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .focused(focus)
                    .padding(.horizontal, DesignSystem.Spacing.gutter - 1)
                    .padding(.top, DesignSystem.Spacing.xs)
                    .accessibilityLabel("\(section.name) lyrics")

                if section.lyricsText.isEmpty {
                    Text("Start with a line you can't forget…")
                        .font(DesignSystem.Typography.italicLarge)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.gutter + 4)
                        .padding(.top, DesignSystem.Spacing.xs + 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxHeight: .infinity)

            if showRhymes {
                LyricsRhymePanel(text: section.lyricsText)
                    .padding(.horizontal, DesignSystem.Spacing.gutter)
                    .padding(.bottom, DesignSystem.Spacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Rhyme panel

/// Line endings with their rhyme letter (A B A B…), so patterns are easy to see.
private struct LyricsRhymePanel: View {
    let text: String

    private static let palette: [Color] = [
        DesignSystem.Colors.sectionOcean, DesignSystem.Colors.sectionCoral,
        DesignSystem.Colors.sectionMoss, DesignSystem.Colors.sectionLavender,
        DesignSystem.Colors.sectionSand, DesignSystem.Colors.sectionBerry,
        DesignSystem.Colors.sectionSky, DesignSystem.Colors.sectionSage
    ]

    var body: some View {
        let scheme = LyricsAnalysis.rhymeScheme(text)
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rhyme scheme").eyebrow()
                Spacer(minLength: 0)
                if !scheme.isEmpty {
                    Text(scheme.map(\.letter).joined(separator: " "))
                        .font(DesignSystem.Typography.chordSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            if scheme.isEmpty {
                Text("Write a few lines to see which ones rhyme.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(scheme.enumerated()), id: \.offset) { _, entry in
                            row(entry)
                        }
                    }
                }
                .frame(maxHeight: 132)
                .scrollIndicators(.hidden)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func row(_ entry: (line: String, letter: String, isRhyme: Bool)) -> some View {
        let letterIndex = Int(entry.letter.unicodeScalars.first?.value ?? 65) - 65
        let color = Self.palette[max(0, letterIndex) % Self.palette.count]
        let lastWord = LyricsAnalysis.words(in: entry.line).last ?? ""
        return HStack(spacing: DesignSystem.Spacing.sm) {
            Text(entry.letter)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(entry.isRhyme ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(entry.isRhyme ? color.opacity(0.35) : Color.clear))
                .overlay(Circle().stroke(entry.isRhyme ? Color.clear : DesignSystem.Colors.border, lineWidth: 1))
            Text(lastWord)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(entry.isRhyme ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(LyricsAnalysis.syllables(inLine: entry.line)) syl")
                .font(DesignSystem.Typography.caption.monospacedDigit())
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
