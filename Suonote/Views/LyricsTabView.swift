import SwiftUI
import SwiftData

struct LyricsTabView: View {
    @Bindable var project: Project
    @State private var selectedSection: SectionTemplate?
    
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
                                usageCount: usageCount(for: section)
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
