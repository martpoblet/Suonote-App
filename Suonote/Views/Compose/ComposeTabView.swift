import SwiftUI
import SwiftData

// MARK: - Compose Tab
/// The heart of songwriting: an editorial lead sheet.
///
/// Top: song facts (key · tempo · meter) and the arrangement strip.
/// Body: one page block per section, each a grid of measures where chords
/// are set in Erode. Every edit goes through `ComposeEditor` (undo/redo).
struct ComposeTabView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var editor = ComposeEditor()
    /// nil = every section on the page; otherwise only this arrangement item.
    @State private var focusedItemId: UUID?
    @State private var paletteSlot: ChordSlot?
    @State private var activeSheet: ComposeSheet?
    @State private var recordingTarget: ComposeRecordingTarget?
    @State private var pendingDeletion: ArrangementItem?
    @State private var playhead: ComposePlayhead?
    /// Held without observing: the recorder publishes meter levels many times a
    /// second, which must not re-render the whole lead sheet. Views that need
    /// live state (linked takes) observe it themselves.
    @State private var services = ComposeServices()

    private var audioManager: AudioRecordingManager { services.audio }
    private var chordPreview: ChordPreviewPlayer { services.preview }

    var body: some View {
        let items = ComposeChordOps.orderedItems(project)
        let recordings = recordingsBySection()

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    ComposeSongHeader(
                        project: project,
                        items: items,
                        onKey: { activeSheet = .key },
                        onTempo: { activeSheet = .tempo },
                        onExport: { activeSheet = .export }
                    )

                    if items.isEmpty {
                        ComposeEmptyState(
                            onAddSection: { activeSheet = .newSection(afterItemId: nil) },
                            onQuickStart: quickStart
                        )
                    } else {
                        ComposeArrangementStrip(
                            project: project,
                            items: items,
                            focusedItemId: $focusedItemId,
                            playingItemId: playhead?.itemId,
                            onAddSection: { activeSheet = .newSection(afterItemId: items.last?.id) },
                            onSelect: { item in select(item, proxy: proxy) }
                        )

                        sections(items: items, recordings: recordings)

                        addSectionFooter(after: items.last)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xxxl)
            }
            .scrollIndicators(.hidden)
        }
        .paperBackground()
        .overlay(alignment: .bottom) {
            ComposeToastView(editor: editor)
                .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .background(ComposePlayheadObserver(project: project, playhead: $playhead))
        .environment(editor)
        .onAppear {
            editor.attach(project: project, context: modelContext)
            audioManager.setup(project: project)
        }
        .onDisappear {
            // Undo is scoped to this editing session; other tabs may change the song.
            // (Recording a take covers the page but stays in the session.)
            if recordingTarget == nil { editor.history.clear() }
            chordPreview.stopAllNotes()
        }
        .onChange(of: project.arrangementItems.count) { _, _ in
            if let focusedItemId, !project.arrangementItems.contains(where: { $0.id == focusedItemId }) {
                self.focusedItemId = nil
            }
        }
        #if DEBUG
        .task {
            // App Store screenshots: `-ScreenshotOpen palette` opens the chord palette on the chorus.
            guard UserDefaults.standard.string(forKey: "ScreenshotOpen") == "palette" else { return }
            try? await Task.sleep(for: .seconds(1.2))
            let sections = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }.compactMap(\.sectionTemplate)
            if let chorus = sections.first(where: { StudioArranger.Role.from(name: $0.name) == .chorus }) ?? sections.first {
                paletteSlot = ChordSlot(barIndex: 1, beatOffset: 0, sectionId: chorus.id)
            }
        }
        #endif
        .sheet(item: $paletteSlot) { slot in
            if let section = section(for: slot.sectionId) {
                ChordPaletteSheet(section: section, slot: slot, project: project, preview: chordPreview)
                    .environment(editor)
                    .presentationDetents([.large])
                    .studioModalStyle()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
                .environment(editor)
                .studioModalStyle()
        }
        .fullScreenCover(item: $recordingTarget) { target in
            ActiveRecordingView(
                project: project,
                audioManager: audioManager,
                recordingType: .sketch,
                initialLinkedSectionId: target.id
            )
        }
        .confirmationDialog(
            "Delete \(pendingDeletion?.sectionTemplate?.name ?? String(localized: "section"))?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { item in
            Button("Delete section", role: .destructive) { delete(item) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It leaves the arrangement. You can undo this.")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func sections(items: [ArrangementItem], recordings: [UUID: [Recording]]) -> some View {
        let visible = focusedItemId.map { id in items.filter { $0.id == id } } ?? items
        LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            ForEach(visible, id: \.id) { item in
                if let section = item.sectionTemplate {
                    ComposeSectionBlock(
                        project: project,
                        item: item,
                        section: section,
                        position: (items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1,
                        sectionCount: items.count,
                        recordings: recordings[section.id] ?? [],
                        playingBar: playhead?.itemId == item.id ? playhead?.bar : nil,
                        audioManager: audioManager,
                        actions: sectionActions(for: item, section: section)
                    )
                    .id(item.id)
                }
            }
        }
    }

    private func sectionActions(for item: ArrangementItem, section: SectionTemplate) -> ComposeSectionActions {
        ComposeSectionActions(
            onSlot: { slot in
                haptic(.selection)
                paletteSlot = slot
            },
            onAudition: { value in
                guard !value.isRest else { return }
                chordPreview.playChord(root: value.root, quality: value.quality)
            },
            onRecord: {
                haptic(.medium)
                recordingTarget = ComposeRecordingTarget(id: section.id)
            },
            onEdit: { activeSheet = .editSection(section) },
            onDuplicate: {
                haptic(.medium)
                editor.perform(String(localized: "Duplicate section"), toast: String(localized: "Section duplicated")) {
                    ComposeChordOps.duplicate(item, in: project)
                }
            },
            onMove: { delta in
                editor.perform(String(localized: "Move section")) {
                    ComposeChordOps.moveItem(item, by: delta, in: project)
                }
            },
            onDelete: { pendingDeletion = item },
            onToggleFocus: {
                withAnimation(DesignSystem.Animations.smoothSpring) {
                    focusedItemId = focusedItemId == item.id ? nil : item.id
                }
            },
            isFocused: focusedItemId == item.id
        )
    }

    private func addSectionFooter(after item: ArrangementItem?) -> some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                haptic(.medium)
                activeSheet = .newSection(afterItemId: focusedItemId ?? item?.id)
            } label: {
                Label("Add section", systemImage: "plus")
            }
            .buttonStyle(OutlineButtonStyle())
            Spacer(minLength: 0)
        }
        .padding(.top, DesignSystem.Spacing.xs)
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ComposeSheet) -> some View {
        switch sheet {
        case .key:
            KeyPickerSheet(project: project, preview: chordPreview)
                .presentationDetents([.large])
        case .tempo:
            ComposeTempoMeterSheet(project: project)
                .presentationDetents([.medium, .large])
        case .export:
            ExportView(project: project)
        case .newSection(let afterItemId):
            SectionCreatorView(
                project: project,
                insertAfter: afterItemId.flatMap { id in project.arrangementItems.first { $0.id == id } },
                onSectionCreated: { section in
                    if focusedItemId != nil,
                       let item = project.arrangementItems.first(where: { $0.sectionTemplate?.id == section.id }) {
                        focusedItemId = item.id
                    }
                }
            )
            .presentationDetents([.large])
        case .editSection(let section):
            SectionEditorSheet(section: section)
                .presentationDetents([.large])
        }
    }

    // MARK: Actions

    private func select(_ item: ArrangementItem, proxy: ScrollViewProxy) {
        haptic(.selection)
        withAnimation(DesignSystem.Animations.smoothSpring) {
            if focusedItemId == nil {
                proxy.scrollTo(item.id, anchor: .top)
            } else {
                focusedItemId = item.id
            }
        }
    }

    private func delete(_ item: ArrangementItem) {
        haptic(.warning)
        let name = item.sectionTemplate?.name ?? String(localized: "Section")
        if focusedItemId == item.id { focusedItemId = nil }
        editor.perform(String(localized: "Delete section"), toast: String(localized: "\(name) removed")) {
            ComposeChordOps.remove(item, from: project, context: modelContext)
        }
    }

    private func quickStart() {
        haptic(.success)
        editor.perform(String(localized: "Quick start")) {
            ComposeChordOps.createSection(in: project, name: String(localized: "Verse 1", comment: "Song section name"), bars: 8, colorHex: SectionPreset.verse.colorHex)
            ComposeChordOps.createSection(in: project, name: String(localized: "Chorus", comment: "Song section name"), bars: 8, colorHex: SectionPreset.chorus.colorHex)
        }
    }

    private func section(for id: UUID) -> SectionTemplate? {
        project.sectionTemplates.first { $0.id == id }
    }

    private func recordingsBySection() -> [UUID: [Recording]] {
        var map: [UUID: [Recording]] = [:]
        for recording in project.recordings {
            if let id = recording.linkedSectionId {
                map[id, default: []].append(recording)
            }
        }
        return map
    }
}

// MARK: - Sheet routing

enum ComposeSheet: Identifiable {
    case key
    case tempo
    case export
    case newSection(afterItemId: UUID?)
    case editSection(SectionTemplate)

    var id: String {
        switch self {
        case .key: return "key"
        case .tempo: return "tempo"
        case .export: return "export"
        case .newSection(let id): return "new-\(id?.uuidString ?? "end")"
        case .editSection(let section): return "edit-\(section.id.uuidString)"
        }
    }
}

// MARK: - Playhead

/// Where the shared transport is, mapped to an arrangement item + bar.
struct ComposePlayhead: Equatable {
    let itemId: UUID
    let bar: Int
}

/// Listens to the shared transport without re-rendering the whole page:
/// it only writes when the playing bar actually changes.
private struct ComposePlayheadObserver: View {
    @EnvironmentObject private var playback: StudioPlaybackEngine
    let project: Project
    @Binding var playhead: ComposePlayhead?
    @State private var lastGlobalBar: Int = -1

    var body: some View {
        Color.clear
            .onReceive(playback.$currentBeat) { beat in
                update(beat: beat, isPlaying: playback.isPlaying)
            }
            .onReceive(playback.$isPlaying) { isPlaying in
                update(beat: playback.currentBeat, isPlaying: isPlaying)
            }
            .accessibilityHidden(true)
    }

    private func update(beat: Double, isPlaying: Bool) {
        guard isPlaying else {
            lastGlobalBar = -1
            if playhead != nil { playhead = nil }
            return
        }
        let globalBar = Int(beat / Double(max(1, project.timeTop)))
        guard globalBar != lastGlobalBar else { return }
        lastGlobalBar = globalBar
        var start = 0
        for item in ComposeChordOps.orderedItems(project) {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            if globalBar >= start && globalBar < start + bars {
                playhead = ComposePlayhead(itemId: item.id, bar: globalBar - start)
                return
            }
            start += bars
        }
        playhead = nil
    }
}

// MARK: - Toast

private struct ComposeToastView: View {
    let editor: ComposeEditor

    var body: some View {
        if let toast = editor.toast {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(toast.message)
                    .font(DesignSystem.Typography.calloutBold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                if toast.offersUndo, editor.history.canUndo {
                    Button("Undo") {
                        editor.dismissToast()
                        editor.undo()
                    }
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .glassEffect(.regular, in: .capsule)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
        }
    }
}

// MARK: - Empty state

private struct ComposeEmptyState: View {
    let onAddSection: () -> Void
    let onQuickStart: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            BrandWavesMark(size: 40, animated: true)
                .padding(.top, DesignSystem.Spacing.xxl)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("A blank lead sheet")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Sketch the first section — the chords come next.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: onAddSection) {
                    Label("Add section", systemImage: "plus")
                }
                .buttonStyle(InkButtonStyle())

                Button(action: onQuickStart) {
                    Text("Start with Verse + Chorus")
                }
                .buttonStyle(OutlineButtonStyle(compact: true))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, DesignSystem.Spacing.xxl)
    }
}

// MARK: - Services

/// Long-lived audio helpers for the Compose page.
@MainActor
final class ComposeServices {
    let audio = AudioRecordingManager()
    let preview = ChordPreviewPlayer()
}

/// The section a new take will be linked to.
struct ComposeRecordingTarget: Identifiable {
    let id: UUID
}
