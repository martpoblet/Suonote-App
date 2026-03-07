import SwiftUI
import SwiftData

struct LyricsTabView: View {
    @Bindable var project: Project
    @State private var selectedSection: SectionTemplate?
    @State private var composerSection: SectionTemplate?

    var uniqueSections: [SectionTemplate] {
        var seen = Set<UUID>()
        return project.arrangementItems.compactMap { item in
            guard let section = item.sectionTemplate,
                  !seen.contains(section.id) else { return nil }
            seen.insert(section.id)
            return section
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if uniqueSections.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(uniqueSections) { section in
                            LyricsSectionCard(
                                section: section,
                                usageCount: usageCount(for: section),
                                onCompose: { composerSection = section }
                            ) {
                                selectedSection = section
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
        }
        .fullScreenCover(item: $selectedSection) { section in
            ImmersiveLyricsEditor(section: section) {
                selectedSection = nil
            }
        }
        .fullScreenCover(item: $composerSection) { section in
            ComposerView(section: section, project: project) {
                composerSection = nil
            }
        }
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "text.quote",
            title: "No sections yet",
            message: "Add sections in the Compose tab first"
        )
    }
    
    private func usageCount(for section: SectionTemplate) -> Int {
        project.arrangementItems.filter { $0.sectionTemplate?.id == section.id }.count
    }
}

// MARK: - Lyrics Section Card

struct LyricsSectionCard: View {
    let section: SectionTemplate
    let usageCount: Int
    let onCompose: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header
                HStack {
                    SectionColorDot(section.color, size: 10)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(section.name)
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        if usageCount > 1 {
                            Text("Used \(usageCount) times")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()

                    // Composer mode: chords + lyrics together
                    Button(action: onCompose) {
                        Image(systemName: "music.note.list")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(section.color)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                // Lyrics preview
                if !section.lyricsText.isEmpty {
                    Text(section.lyricsText)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(3)
                        .padding(DesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(DesignSystem.Colors.surface.opacity(0.6))
                        )
                } else {
                    HStack {
                        Image(systemName: "text.cursor")
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        Text("No lyrics yet")
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animatedPress()
    }
}

// MARK: - Syllable counting (heuristic, English-optimized)

private func syllableCount(_ text: String) -> Int {
    let words = text.lowercased()
        .components(separatedBy: .whitespacesAndNewlines)
        .map { $0.filter(\.isLetter) }
        .filter { !$0.isEmpty }
    return words.reduce(0) { total, word in
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var prevWasVowel = false
        for ch in word {
            let isVowel = vowels.contains(ch)
            if isVowel && !prevWasVowel { count += 1 }
            prevWasVowel = isVowel
        }
        // Silent trailing 'e' (e.g., "time", "love") — subtract if word has multiple syllables
        if word.last == "e" && count > 1 { count -= 1 }
        return total + max(1, count)
    }
}

// MARK: - Immersive Lyrics Editor

struct ImmersiveLyricsEditor: View {
    @Bindable var section: SectionTemplate
    var onDismiss: () -> Void
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                // Center: dot + section name
                HStack(spacing: DesignSystem.Spacing.xs) {
                    SectionColorDot(section.color, size: 10)
                    Text(section.name)
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                
                // Leading: back chevron
                HStack {
                    Button {
                        isTextEditorFocused = false
                        onDismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryDark)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            
            // Text Editor
            ZStack(alignment: .topLeading) {
                if section.lyricsText.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "text.quote")
                            .font(DesignSystem.Typography.jumbo)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        Text("Start writing your lyrics..")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                TextEditor(text: $section.lyricsText)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isTextEditorFocused)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .frame(maxHeight: .infinity)
            
            // Bottom toolbar — syllables, words, chars
            HStack {
                let text = section.lyricsText
                let wordCount = text.split(whereSeparator: \.isWhitespace).count
                let syllables = syllableCount(text)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Label("\(syllables) syl", systemImage: "music.note")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.primary)

                    Text("·")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("\(wordCount) words")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("·")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("\(text.count) chars")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()
                if isTextEditorFocused {
                    Button {
                        isTextEditorFocused = false
                    } label: {
                        Text("Done")
                            .font(DesignSystem.Typography.bodyBold)
                            .foregroundStyle(DesignSystem.Colors.primaryDark)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
    }
}

// MARK: - Composer View (chords + lyrics side by side)

/// Full-screen songwriter workspace: chord reference strip on top, lyrics editor below.
/// The chord strip gives a quick visual reference of what harmonic content is in each bar
/// without requiring the user to switch back to the Compose tab.
struct ComposerView: View {
    @Bindable var section: SectionTemplate
    let project: Project
    var onDismiss: () -> Void

    @FocusState private var isTextEditorFocused: Bool

    // Chord area height — user can drag the divider to resize.
    @State private var chordAreaHeight: CGFloat = 180
    @GestureState private var dividerDrag: CGFloat = 0

    private var effectiveChordHeight: CGFloat {
        max(80, min(340, chordAreaHeight + dividerDrag))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DesignSystem.Colors.border)

            // ── Chord Reference Strip ──────────────────────────────────────
            chordReferenceStrip
                .frame(height: effectiveChordHeight)
                .background(DesignSystem.Colors.surfaceSecondary)

            // Resizable divider handle
            resizeDivider

            // ── Lyrics Editor ──────────────────────────────────────────────
            ZStack(alignment: .topLeading) {
                if section.lyricsText.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "text.quote")
                            .font(DesignSystem.Typography.jumbo)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text("Start writing your lyrics..")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                TextEditor(text: $section.lyricsText)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isTextEditorFocused)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .frame(maxHeight: .infinity)

            // ── Bottom toolbar: syllable / word / char count ───────────────
            HStack {
                let text = section.lyricsText
                let wordCount = text.split(whereSeparator: \.isWhitespace).count
                let syllables = syllableCount(text)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Label("\(syllables) syl", systemImage: "music.note")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.primary)

                    Text("·").font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("\(wordCount) words")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("·").font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("\(text.count) chars")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                if isTextEditorFocused {
                    Button {
                        isTextEditorFocused = false
                    } label: {
                        Text("Done")
                            .font(DesignSystem.Typography.bodyBold)
                            .foregroundStyle(DesignSystem.Colors.primaryDark)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isTextEditorFocused = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            HStack(spacing: DesignSystem.Spacing.xs) {
                SectionColorDot(section.color, size: 10)
                Text(section.name)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("·").font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                // Key + BPM context
                Text("\(project.keyRoot)\(project.keyMode == .minor ? "m" : "") · \(project.bpm) BPM")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            HStack {
                Button {
                    isTextEditorFocused = false
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryDark)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Chord Reference Strip

    /// Read-only horizontal chord strip — one cell per bar, showing chords in that bar.
    private var chordReferenceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                let chordsByBar = Dictionary(
                    grouping: section.chordEvents.filter { !$0.isRest },
                    by: { $0.barIndex }
                )

                ForEach(0..<max(1, section.bars), id: \.self) { bar in
                    VStack(spacing: 4) {
                        Text("Bar \(bar + 1)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        let chordsInBar = (chordsByBar[bar] ?? [])
                            .sorted { $0.beatOffset < $1.beatOffset }

                        if chordsInBar.isEmpty {
                            Text("–")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(DesignSystem.Colors.surfaceSecondary)
                                )
                        } else {
                            ForEach(chordsInBar) { chord in
                                Text(chord.display)
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(section.color.opacity(0.22))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(section.color.opacity(0.4), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                    .padding(8)
                    .frame(minWidth: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DesignSystem.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Resizable Divider

    private var resizeDivider: some View {
        ZStack {
            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(height: 1)

            // Drag handle pill
            Capsule()
                .fill(DesignSystem.Colors.textTertiary)
                .frame(width: 36, height: 4)
        }
        .frame(height: 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dividerDrag) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    chordAreaHeight = max(80, min(340, chordAreaHeight + value.translation.height))
                }
        )
        .background(DesignSystem.Colors.surfaceSecondary)
    }
}

// MARK: - LyricsTabView Preview

private struct LyricsTabViewPreview: View {
    let container: ModelContainer
    let project: Project

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Project.self, configurations: config)
        let project = Project(title: "Test")
        container.mainContext.insert(project)

        let section = SectionTemplate(
            name: "Verse 1",
            lyricsText: "This is a sample lyric\nWith multiple lines\nTo show the preview"
        )
        section.project = project
        project.sectionTemplates.append(section)

        let item = ArrangementItem(orderIndex: 0)
        item.sectionTemplate = section
        item.project = project
        project.arrangementItems.append(item)

        self.container = container
        self.project = project
    }

    var body: some View {
        LyricsTabView(project: project)
            .modelContainer(container)
    }
}

#Preview {
    LyricsTabViewPreview()
}
