import SwiftUI
import SwiftData
import Observation

// MARK: - Compose Editor
/// Single entry point for every Compose mutation.
///
/// `perform` snapshots the song before and after a change, saves, and
/// registers the pair with `EditHistoryManager`, so every edit — chords, bars,
/// sections, key, tempo — can be undone and redone. Restores are diff-based:
/// only entities the action created or touched are affected, so edits made in
/// other tabs are never clobbered.
@MainActor
@Observable
final class ComposeEditor {
    let history = EditHistoryManager()

    /// Short-lived confirmation shown as a toast ("Bar deleted").
    private(set) var toast: Toast?

    @ObservationIgnored private weak var project: Project?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var trackingBefore: ComposeSnapshot?

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let message: String
        let offersUndo: Bool
    }

    func attach(project: Project, context: ModelContext) {
        if self.project !== project { history.clear() }
        self.project = project
        self.context = context
    }

    var modelContext: ModelContext? { context }

    /// Runs `change`, saves, and records it for undo.
    func perform(
        _ label: String,
        toast message: String? = nil,
        animated: Bool = true,
        _ change: () -> Void
    ) {
        guard let project else {
            change()
            return
        }
        let before = ComposeSnapshot(project: project)
        if animated {
            withAnimation(DesignSystem.Animations.smoothSpring) { change() }
        } else {
            change()
        }
        let after = ComposeSnapshot(project: project)
        guard before != after else { return }
        commit()
        history.register(
            label: label,
            undo: { [weak self] in self?.restore(before, from: after) },
            redo: { [weak self] in self?.restore(after, from: before) }
        )
        if let message { show(message, offersUndo: true) }
    }

    /// Starts a multi-step gesture (e.g. live drag reordering) that should
    /// land in history as a single step once `commitTracking` is called.
    func beginTracking() {
        guard let project else { return }
        trackingBefore = ComposeSnapshot(project: project)
    }

    func commitTracking(_ label: String) {
        guard let project, let before = trackingBefore else { return }
        trackingBefore = nil
        let after = ComposeSnapshot(project: project)
        guard before != after else { return }
        commit()
        history.register(
            label: label,
            undo: { [weak self] in self?.restore(before, from: after) },
            redo: { [weak self] in self?.restore(after, from: before) }
        )
    }

    func undo() {
        guard history.canUndo else { return }
        let label = history.undoLabel
        history.undo()
        haptic(.light)
        show(String(localized: "Undid \(label.lowercased())"), offersUndo: false)
    }

    func redo() {
        guard history.canRedo else { return }
        let label = history.redoLabel
        history.redo()
        haptic(.light)
        show(String(localized: "Redid \(label.lowercased())"), offersUndo: false)
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(DesignSystem.Animations.quickSpring) { toast = nil }
    }

    private func show(_ message: String, offersUndo: Bool) {
        toastTask?.cancel()
        withAnimation(DesignSystem.Animations.quickSpring) {
            toast = Toast(message: message, offersUndo: offersUndo)
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(offersUndo ? 3.2 : 1.6))
            guard !Task.isCancelled else { return }
            self?.dismissToast()
        }
    }

    private func commit() {
        project?.updatedAt = Date()
        try? context?.save()
    }

    private func restore(_ target: ComposeSnapshot, from current: ComposeSnapshot) {
        guard let project else { return }
        withAnimation(DesignSystem.Animations.smoothSpring) {
            target.restore(into: project, discarding: current, context: context)
        }
        commit()
    }
}

// MARK: - Snapshot

/// Value copy of everything Compose can edit.
struct ComposeSnapshot: Equatable {
    struct Chord: Equatable {
        let id: UUID
        let barIndex: Int
        let beatOffset: Double
        let duration: Double
        let isRest: Bool
        let root: String
        let quality: ChordQuality
        let extensions: [String]
        let slashRoot: String?
    }

    struct Section: Equatable {
        let id: UUID
        let name: String
        let bars: Int
        let colorHex: String?
        let lyricsText: String
        let notesText: String
        let patternPreset: PatternPreset
        let keyRoot: String?
        let keyModeRaw: String?
        let bpm: Int?
        let chords: [Chord]
    }

    struct Item: Equatable {
        let id: UUID
        let orderIndex: Int
        let sectionId: UUID?
        let labelOverride: String?
    }

    let keyRoot: String
    let keyMode: KeyMode
    let bpm: Int
    let timeTop: Int
    let timeBottom: Int
    let sections: [Section]
    let items: [Item]

    @MainActor
    init(project: Project) {
        keyRoot = project.keyRoot
        keyMode = project.keyMode
        bpm = project.bpm
        timeTop = project.timeTop
        timeBottom = project.timeBottom
        sections = project.sectionTemplates.map { section in
            Section(
                id: section.id,
                name: section.name,
                bars: section.bars,
                colorHex: section.colorHex,
                lyricsText: section.lyricsText,
                notesText: section.notesText,
                patternPreset: section.patternPreset,
                keyRoot: section.sectionKeyRoot,
                keyModeRaw: section.sectionKeyModeRaw,
                bpm: section.sectionBpm,
                chords: section.chordEvents
                    .map {
                        Chord(
                            id: $0.id, barIndex: $0.barIndex, beatOffset: $0.beatOffset,
                            duration: $0.duration, isRest: $0.isRest, root: $0.root,
                            quality: $0.quality, extensions: $0.extensions, slashRoot: $0.slashRoot
                        )
                    }
                    .sorted { ($0.barIndex, $0.beatOffset, $0.id.uuidString) < ($1.barIndex, $1.beatOffset, $1.id.uuidString) }
            )
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }
        items = project.arrangementItems
            .map { Item(id: $0.id, orderIndex: $0.orderIndex, sectionId: $0.sectionTemplateId, labelOverride: $0.labelOverride) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Brings `project` back to this snapshot. Entities that exist only in
    /// `other` (created by the undone action) are removed; anything unknown to
    /// both snapshots is left untouched.
    @MainActor
    func restore(into project: Project, discarding other: ComposeSnapshot, context: ModelContext?) {
        project.keyRoot = keyRoot
        project.keyMode = keyMode
        project.bpm = bpm
        project.timeTop = timeTop
        project.timeBottom = timeBottom

        // Sections
        let targetSectionIds = Set(sections.map(\.id))
        let createdSectionIds = Set(other.sections.map(\.id)).subtracting(targetSectionIds)
        let otherChordIds: [UUID: Set<UUID>] = Dictionary(
            uniqueKeysWithValues: other.sections.map { ($0.id, Set($0.chords.map(\.id))) }
        )

        var templates = project.sectionTemplates
        for created in templates where createdSectionIds.contains(created.id) {
            for chord in created.chordEvents { context?.delete(chord) }
            created.chordEvents = []
            context?.delete(created)
        }
        templates.removeAll { createdSectionIds.contains($0.id) }

        for state in sections {
            let section: SectionTemplate
            if let existing = templates.first(where: { $0.id == state.id }) {
                section = existing
            } else {
                section = SectionTemplate(name: state.name, bars: state.bars)
                section.id = state.id
                section.project = project
                templates.append(section)
            }
            section.name = state.name
            section.bars = state.bars
            section.colorHex = state.colorHex
            section.lyricsText = state.lyricsText
            section.notesText = state.notesText
            section.patternPreset = state.patternPreset
            section.sectionKeyRoot = state.keyRoot
            section.sectionKeyModeRaw = state.keyModeRaw
            section.sectionBpm = state.bpm
            restoreChords(state.chords, in: section, otherIds: otherChordIds[state.id] ?? [], context: context)
        }
        project.sectionTemplates = templates

        // Arrangement
        let targetItemIds = Set(items.map(\.id))
        let createdItemIds = Set(other.items.map(\.id)).subtracting(targetItemIds)
        var arrangement = project.arrangementItems
        for created in arrangement where createdItemIds.contains(created.id) {
            context?.delete(created)
        }
        arrangement.removeAll { createdItemIds.contains($0.id) }
        for state in items {
            let item: ArrangementItem
            if let existing = arrangement.first(where: { $0.id == state.id }) {
                item = existing
            } else {
                item = ArrangementItem(orderIndex: state.orderIndex, labelOverride: state.labelOverride)
                item.id = state.id
                item.project = project
                arrangement.append(item)
            }
            item.orderIndex = state.orderIndex
            item.sectionTemplateId = state.sectionId
            item.labelOverride = state.labelOverride
        }
        arrangement.sort { $0.orderIndex < $1.orderIndex }
        for (index, item) in arrangement.enumerated() { item.orderIndex = index }
        project.arrangementItems = arrangement
    }

    @MainActor
    private func restoreChords(_ states: [Chord], in section: SectionTemplate, otherIds: Set<UUID>, context: ModelContext?) {
        let targetIds = Set(states.map(\.id))
        var chords = section.chordEvents
        // Chords that only exist in the state we're leaving were created by the action.
        let createdIds = otherIds.subtracting(targetIds)
        for chord in chords where createdIds.contains(chord.id) {
            context?.delete(chord)
        }
        chords.removeAll { createdIds.contains($0.id) }

        for state in states {
            let chord: ChordEvent
            if let existing = chords.first(where: { $0.id == state.id }) {
                chord = existing
            } else {
                chord = ChordEvent(barIndex: state.barIndex, beatOffset: state.beatOffset, root: state.root)
                chord.id = state.id
                chords.append(chord)
            }
            chord.barIndex = state.barIndex
            chord.beatOffset = state.beatOffset
            chord.duration = state.duration
            chord.isRest = state.isRest
            chord.root = state.root
            chord.quality = state.quality
            chord.extensions = state.extensions
            chord.slashRoot = state.slashRoot
            chord.updateDisplay()
        }
        section.chordEvents = chords
    }
}
