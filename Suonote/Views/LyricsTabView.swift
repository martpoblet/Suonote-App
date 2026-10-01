import SwiftUI
import SwiftData

/// The lyrics as a writer's page: every section in song order, named in
/// Erode with its color rule, chords above as a quiet reference, and the
/// words set like a printed lyric sheet. Tap any section to write.
struct LyricsTabView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    @AppStorage("lyrics.showSyllables") private var showSyllables = true
    @State private var editorStart: LyricsEditorStart?

    /// Identifies which section the full-screen editor opens on.
    private struct LyricsEditorStart: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private var uniqueSections: [SectionTemplate] { project.recordUniqueSections }

    private var allLyrics: String {
        uniqueSections.map(\.lyricsText).joined(separator: "\n")
    }

    var body: some View {
        let sections = uniqueSections
        Group {
            if sections.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(sections: sections)
                        emptyStateView
                            .padding(.top, DesignSystem.Spacing.xxl)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.gutter)
                    .padding(.top, DesignSystem.Spacing.md)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(sections: sections)
                            .padding(.bottom, DesignSystem.Spacing.sm)

                        ForEach(Array(sections.enumerated()), id: \.element.id) { offset, section in
                            if offset > 0 { Hairline() }
                            LyricsSectionBlock(
                                section: section,
                                usageCount: usageCount(for: section),
                                showSyllables: showSyllables
                            ) {
                                HapticFeedback.light.trigger()
                                editorStart = LyricsEditorStart(index: offset)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.gutter)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xxxl)
                }
                .scrollIndicators(.hidden)
            }
        }
        .fullScreenCover(item: $editorStart) { start in
            ImmersiveLyricsEditor(sections: uniqueSections, startIndex: start.index) {
                editorStart = nil
                project.updatedAt = Date()
            }
        }
    }

    // MARK: Header

    private func header(sections: [SectionTemplate]) -> some View {
        ScreenHeader(eyebrow: String(localized: "Lyrics"), title: project.title, subtitle: subtitle(sections: sections)) {
            if !sections.isEmpty {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Menu {
                        Toggle(isOn: $showSyllables) {
                            Label("Syllable counts", systemImage: "number")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Lyrics options")

                    Button {
                        HapticFeedback.light.trigger()
                        editorStart = LyricsEditorStart(index: firstSectionToWrite(in: sections))
                    } label: {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Open writing page")
                }
            }
        }
    }

    private func subtitle(sections: [SectionTemplate]) -> String {
        guard !sections.isEmpty else { return String(localized: "Every song starts as a sketch.") }
        let words = LyricsAnalysis.wordCount(allLyrics)
        let written = sections.filter { !$0.lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        if words == 0 { return String(localized: "A blank page, \(sections.count) sections waiting.") }
        return String(localized: "\(words) words · \(written) of \(sections.count) sections written")
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "text.quote",
            title: String(localized: "No sections yet"),
            message: String(localized: "Start with the words — Suonote will make the first verse for you."),
            actionTitle: String(localized: "Start writing")
        ) {
            startLyricsSection()
        }
    }

    // MARK: Helpers

    /// Opens on the first section without lyrics, or the first one.
    private func firstSectionToWrite(in sections: [SectionTemplate]) -> Int {
        sections.firstIndex { $0.lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? 0
    }

    private func usageCount(for section: SectionTemplate) -> Int {
        project.arrangementItems.filter { $0.sectionTemplate?.id == section.id }.count
    }

    private func startLyricsSection() {
        let section = SectionTemplate(
            name: "Verse 1",
            bars: 8,
            colorHex: SectionColor.sky.hex
        )
        section.project = project
        project.sectionTemplates.append(section)

        let item = ArrangementItem(orderIndex: project.arrangementItems.count)
        item.sectionTemplate = section
        item.project = project
        project.arrangementItems.append(item)
        project.updatedAt = Date()

        try? modelContext.save()
        HapticFeedback.success.trigger()
        editorStart = LyricsEditorStart(index: max(0, uniqueSections.firstIndex { $0.id == section.id } ?? 0))
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
