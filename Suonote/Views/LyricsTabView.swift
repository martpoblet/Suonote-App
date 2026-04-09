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
            ImmersiveLyricsEditor(section: section, project: project) {
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

    private var analysis: LyricAnalysis {
        LyricAssistant.analyze(section.lyricsText)
    }

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

                    // Lyric stats badges
                    if !section.lyricsText.isEmpty {
                        HStack(spacing: 6) {
                            if !analysis.rhymeScheme.isEmpty {
                                Text(analysis.rhymeScheme.prefix(4))
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.primary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(DesignSystem.Colors.primary.opacity(0.12)))
                            }
                            Text("\(analysis.totalSyllables)syl")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

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

// MARK: - Immersive Lyrics Editor (enhanced with L1, L2, L3, L4)

struct ImmersiveLyricsEditor: View {
    @Bindable var section: SectionTemplate
    let project: Project
    var onDismiss: () -> Void
    @FocusState private var isTextEditorFocused: Bool

    // Tool panels
    @State private var activePanel: LyricsPanel? = nil
    @State private var showTemplatePicker = false

    enum LyricsPanel: String, Identifiable {
        case syllables = "Syllables"
        case rhymes = "Rhymes"
        case chordSync = "Chord Sync"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .syllables: return "number.circle"
            case .rhymes: return "text.word.spacing"
            case .chordSync: return "guitars"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider().overlay(DesignSystem.Colors.border)

            // Tool panel (collapsed/expanded)
            if let panel = activePanel {
                lyricsPanelView(panel)
                    .transition(.move(edge: .top).combined(with: .opacity))
                Divider().overlay(DesignSystem.Colors.border)
            }

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

            Divider().overlay(DesignSystem.Colors.border)

            // Bottom toolbar
            bottomToolbar
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: activePanel)
        .sheet(isPresented: $showTemplatePicker) {
            LyricTemplatePicker { template in
                applyTemplate(template)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        ZStack {
            HStack(spacing: DesignSystem.Spacing.xs) {
                SectionColorDot(section.color, size: 10)
                Text(section.name)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
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
                // Template button
                Button {
                    isTextEditorFocused = false
                    showTemplatePicker = true
                } label: {
                    Image(systemName: "text.insert")
                        .font(.system(size: 17))
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Tool Panels

    @ViewBuilder
    private func lyricsPanelView(_ panel: LyricsPanel) -> some View {
        ScrollView {
            switch panel {
            case .syllables:
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    let analysis = LyricAssistant.analyze(section.lyricsText)
                    HStack {
                        Text(analysis.meter)
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.primary)
                        Spacer()
                        Text("\(analysis.totalSyllables) total · \(analysis.wordCount) words")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)

                    SyllableCounterView(text: section.lyricsText)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                }
                .padding(.vertical, DesignSystem.Spacing.sm)

            case .rhymes:
                RhymeFinderView(text: section.lyricsText)

            case .chordSync:
                LyricChordSyncView(section: section, project: project)
                    .padding(DesignSystem.Spacing.md)
            }
        }
        .frame(maxHeight: 220)
        .background(DesignSystem.Colors.backgroundSecondary)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Text("\(section.lyricsText.count) characters")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            // Tool panel toggles
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach([LyricsPanel.syllables, .rhymes, .chordSync]) { panel in
                    Button {
                        withAnimation {
                            if activePanel == panel { activePanel = nil }
                            else { activePanel = panel; isTextEditorFocused = false }
                        }
                    } label: {
                        Image(systemName: panel.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(activePanel == panel ?
                                             DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                    }
                }
            }

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

    // MARK: - Template Application

    private func applyTemplate(_ template: LyricAssistant.LyricTemplate) {
        if section.lyricsText.isEmpty {
            section.lyricsText = template.example.joined(separator: "\n")
        } else {
            section.lyricsText += "\n\n" + template.example.joined(separator: "\n")
        }
    }
}

// MARK: - L3: Lyric + Chord Sync View

struct LyricChordSyncView: View {
    let section: SectionTemplate
    let project: Project

    private var chords: [ChordEvent] {
        section.chordEvents
            .filter { !$0.isRest }
            .sorted { $0.barIndex * 100 + Int($0.beatOffset * 10) <
                      $1.barIndex * 100 + Int($1.beatOffset * 10) }
    }

    private var lyricLines: [String] {
        section.lyricsText.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var keyRoot: String { section.effectiveKeyRoot }
    private var mode: KeyMode { section.effectiveKeyMode }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if chords.isEmpty && lyricLines.isEmpty {
                Text("Add chords and lyrics to see the sync view.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            } else {
                // Chord row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(chords) { chord in
                            VStack(spacing: 2) {
                                Text(chord.display)
                                    .font(DesignSystem.Typography.calloutBold)
                                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(DesignSystem.Colors.primary.opacity(0.12))
                                    )
                                Text("Bar \(chord.barIndex + 1)")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                }

                Divider().overlay(DesignSystem.Colors.border)

                // Lyrics with chord alignment
                VStack(alignment: .leading, spacing: 4) {
                    let chordPerLine = chords.count > 0 && lyricLines.count > 0
                        ? chords.count / max(1, lyricLines.count) : 0

                    ForEach(Array(lyricLines.enumerated()), id: \.offset) { i, line in
                        VStack(alignment: .leading, spacing: 2) {
                            // Chord aligned to this lyric line
                            if chordPerLine > 0 {
                                let startChord = i * chordPerLine
                                let endChord = min(startChord + chordPerLine, chords.count)
                                if startChord < chords.count {
                                    HStack(spacing: 6) {
                                        ForEach(chords[startChord..<endChord]) { chord in
                                            Text(chord.display)
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(DesignSystem.Colors.primary)
                                        }
                                    }
                                }
                            }
                            Text(line)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

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
