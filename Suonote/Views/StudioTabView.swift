import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers

struct StudioTabView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var showingStylePicker = false
    @State private var showingRecordingPicker = false
    @State private var showingRegenerateDialog = false
    @State private var showingInstrumentPicker = false
    @State private var showingAddTrackMenu = false
    @State private var pendingAddTrackAfterStyle = false
    @State private var selectedTrackId: UUID?
    @State private var editingTrack: StudioTrack?
    @State private var needsRebuild = true
    @State private var lastProjectSignature = ""
    @State private var lastChordIds: Set<UUID> = []
    @State private var lastTotalBars = 0
    @StateObject private var playback = StudioPlaybackEngine()
    @State private var showingNoSectionsAlert = false

    private var sortedTracks: [StudioTrack] {
        project.studioTracks.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var selectedTrack: StudioTrack? {
        guard let selectedTrackId else { return nil }
        return project.studioTracks.first { $0.id == selectedTrackId }
    }

    private var hasGeneratedTracks: Bool {
        project.studioTracks.contains { !$0.instrument.isAudio }
    }

    private var existingInstrumentSet: Set<StudioInstrument> {
        Set(project.studioTracks.filter { !$0.instrument.isAudio }.map(\.instrument))
    }

    private var existingRecordingIds: Set<UUID> {
        Set(project.studioTracks.compactMap { $0.audioRecordingId })
    }

    private var availableRecordings: [Recording] {
        project.recordings.filter { !existingRecordingIds.contains($0.id) }
    }

    private var availableInstruments: [StudioInstrument] {
        StudioInstrument.allCases.filter { !$0.isAudio }
    }

    private var hasSections: Bool {
        project.arrangementItems.contains { $0.sectionTemplate != nil }
    }

    private var totalBars: Int {
        let bars = project.arrangementItems
            .compactMap { $0.sectionTemplate?.bars }
            .reduce(0, +)
        return max(1, bars)
    }

    private var timelineSegments: [StudioTimelineSegment] {
        let orderedItems = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        var segments: [StudioTimelineSegment] = []
        var startBar = 0

        for item in orderedItems {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            let label = item.labelOverride?.isEmpty == false ? item.labelOverride! : section.name
            segments.append(
                StudioTimelineSegment(
                    label: label,
                    color: section.color,
                    startBar: startBar,
                    bars: bars
                )
            )
            startBar += bars
        }

        if segments.isEmpty {
            segments.append(
                StudioTimelineSegment(
                    label: "Song",
                    color: SectionColor.purple.color,
                    startBar: 0,
                    bars: totalBars
                )
            )
        }

        return segments
    }

    var body: some View {
        VStack(spacing: 0) {
            studioHeader
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.sm)

            Divider().overlay(DesignSystem.Colors.border)

            if sortedTracks.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    
                StudioEmptyState(
                    project: project,
                    accentColor: project.studioStyle?.accentColor ?? SectionColor.purple.color,
                    onPickStyle: { showingStylePicker = true },
                    onAddTrack: promptAddTrack
                )
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.xs) {
                        StudioTrackList(
                            tracks: sortedTracks,
                            selectedTrackId: $selectedTrackId,
                            onTrackStructureChange: { needsRebuild = true },
                            onMixChange: applyMixState,
                            onEffectsChange: applyEffects,
                            onDelete: deleteTrack,
                            onOpenEditor: { track in
                                selectedTrackId = track.id
                                editingTrack = track
                            },
                            onReorder: reorderTracks
                        )
                        StudioTrackEditorHint(
                            accentColor: selectedTrack?.instrument.color
                                ?? project.studioStyle?.accentColor
                                ?? SectionColor.purple.color
                        )
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Layout.projectTabBarClearance)
                }
                
                if hasSections {
                    // Fixed timeline at bottom
                    VStack(spacing: 0) {                        
                        StudioTimelineView(
                            segments: timelineSegments,
                            beatsPerBar: project.timeTop,
                            totalBars: totalBars,
                            currentBeat: playback.currentBeat,
                            isPlaying: playback.isPlaying,
                            accentColor: project.studioStyle?.accentColor ?? SectionColor.purple.color,
                            isMetronomeEnabled: $playback.isMetronomeEnabled,
                            onPlay: handlePlay,
                            onPause: playback.pause,
                            onStop: handleStop,
                            onSeek: { beat in
                                playback.seek(to: beat)
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                    .padding(.bottom, DesignSystem.Layout.projectTabBarClearance + 5)
                }
            }
        }
        .alert("Add sections first", isPresented: $showingNoSectionsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Create at least one section in Compose to add instruments and play the Studio.")
        }
        .onAppear {
            if project.studioStyle == nil {
                showingStylePicker = true
            }
            if selectedTrackId == nil {
                selectedTrackId = sortedTracks.first?.id
            }
            playback.prepare(project: project)
            playback.updateProject(project)
            // Restart playhead timer if still playing (e.g. returning from another tab)
            if playback.isPlaying {
                playback.ensurePlayheadTimer()
            }
            lastProjectSignature = projectStudioSignature
            let timeline = StudioGenerator.timeline(for: project)
            lastChordIds = Set(timeline.chords.map { $0.chord.id })
            lastTotalBars = timeline.totalBars
            syncStudioIfNeeded()
        }
        .onChange(of: projectStudioSignature) { _, newSignature in
            handleProjectChange(newSignature: newSignature)
        }
        .onChange(of: project.arrangementItems.count) { _, newValue in
            if newValue == 0 {
                playback.stop(resetPosition: true)
            }
        }
        .onChange(of: showingStylePicker) { _, isShowing in
            guard !isShowing else { return }
            if pendingAddTrackAfterStyle, project.studioStyle != nil {
                pendingAddTrackAfterStyle = false
                showingInstrumentPicker = true
            } else if project.studioStyle == nil {
                pendingAddTrackAfterStyle = false
            }
        }
        .onChange(of: playback.isMetronomeEnabled) { _, _ in
            needsRebuild = true
        }
        .sheet(isPresented: $showingStylePicker) {
            StudioStylePickerView(
                selectedStyle: project.studioStyle,
                onConfirm: { style in
                    let previousStyle = project.studioStyle
                    project.studioStyle = style
                    project.updatedAt = Date()
                    if previousStyle != style, hasGeneratedTracks {
                        StudioGenerator.regenerateNotes(
                            for: project,
                            style: style,
                            modelContext: modelContext,
                            resetDrumPreset: true
                        )
                        updateStudioSyncState(signature: projectStudioSignature, timeline: StudioGenerator.timeline(for: project))
                        needsRebuild = true
                        try? modelContext.save()
                    } else {
                        try? modelContext.save()
                    }
                }
            )
        }
        .sheet(isPresented: $showingRecordingPicker) {
            StudioRecordingPicker(
                recordings: availableRecordings,
                onPick: { recording in
                    addAudioTrack(from: recording)
                }
            )
        }
        .sheet(isPresented: $showingInstrumentPicker) {
            StudioInstrumentPickerView(
                availableInstruments: availableInstruments,
                existingInstruments: existingInstrumentSet,
                onPick: { instrument in
                    addInstrumentTrack(instrument)
                }
            )
        }
        .sheet(isPresented: $showingAddTrackMenu) {
            AddTrackMenuView(
                hasRecordings: !availableRecordings.isEmpty,
                onAddInstrument: {
                    showingAddTrackMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingInstrumentPicker = true
                    }
                },
                onAddRecording: {
                    showingAddTrackMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingRecordingPicker = true
                    }
                }
            )
        }
        .confirmationDialog(
            "Regenerate tracks?",
            isPresented: $showingRegenerateDialog,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                regenerateNotes()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will rebuild notes for the current generated tracks.")
        }
        .fullScreenCover(item: $editingTrack, onDismiss: {
            editingTrack = nil
            applyMixState()
        }) { track in
            StudioTrackEditorView(
                project: project,
                track: track,
                totalBars: totalBars,
                beatsPerBar: project.timeTop,
                timeBottom: project.timeBottom,
                style: project.studioStyle,
                playback: playback,
                onNotesChanged: { needsRebuild = true },
                onPlay: handlePlay,
                onPause: playback.pause,
                onStop: handleStop
            )
        }
    }

    private var studioHeader: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Style Picker Button
            Button {
                showingStylePicker = true
            } label: {
                AppChip(
                    text: project.studioStyle?.title ?? "Pick Style",
                    icon: project.studioStyle?.icon ?? "sparkles",
                    tint: project.studioStyle?.accentColor ?? DesignSystem.Colors.primary,
                    font: DesignSystem.Typography.callout
                )
            }
            .animatedPress()

            Spacer()

            // Add Track Button
            Button {
                promptAddTrack()
            } label: {
                AppChip(
                    text: "Add Track",
                    icon: DesignSystem.Icons.add,
                    tint: project.studioStyle?.accentColor ?? DesignSystem.Colors.primary,
                    font: DesignSystem.Typography.callout
                )
            }
            .animatedPress()
            .disabled(!hasSections)
        }
    }

    private func regenerateNotes() {
        guard let style = project.studioStyle else { return }
        StudioGenerator.regenerateNotes(for: project, style: style, modelContext: modelContext)
        updateStudioSyncState(signature: projectStudioSignature, timeline: StudioGenerator.timeline(for: project))
        project.updatedAt = Date()
        try? modelContext.save()
        needsRebuild = true
        playback.stop(resetPosition: true)
    }

    private func promptAddTrack() {
        guard hasSections else {
            showingNoSectionsAlert = true
            return
        }
        guard project.studioStyle != nil else {
            pendingAddTrackAfterStyle = true
            showingStylePicker = true
            return
        }
        showingAddTrackMenu = true
    }

    private func addInstrumentTrack(_ instrument: StudioInstrument) {
        guard hasSections else { return }
        guard let style = project.studioStyle else { return }
        guard !existingInstrumentSet.contains(instrument) else { return }

        let orderIndex = (project.studioTracks.map(\.orderIndex).max() ?? -1) + 1
        let track = StudioTrack(
            name: instrument.title,
            instrument: instrument,
            orderIndex: orderIndex
        )
        track.project = project
        project.studioTracks.append(track)
        modelContext.insert(track)

        let drumPreset = instrument == .drums
            ? DrumPreset.defaultPreset(for: style, beatsPerBar: project.timeTop, timeBottom: project.timeBottom)
            : nil
        track.drumPreset = drumPreset
        let notes = StudioGenerator.generateNotes(
            for: instrument,
            project: project,
            style: style,
            drumPreset: drumPreset,
            variant: track.variant,
            octaveShift: track.octaveShift,
            intensity: track.regenerateIntensity,
            complexity: track.regenerateComplexity,
            naturalness: track.regenerateNaturalness,
            arpeggioEnabled: track.regenerateArpeggioEnabled,
            arpeggioRate: track.regenerateArpeggioRate,
            arpeggioPattern: track.regenerateArpeggioPattern
        )
        for note in notes {
            note.track = track
            track.notes.append(note)
            modelContext.insert(note)
        }

        selectedTrackId = track.id
        updateStudioSyncState(signature: projectStudioSignature, timeline: StudioGenerator.timeline(for: project))
        project.updatedAt = Date()
        try? modelContext.save()
        needsRebuild = true
    }

    private func deleteTrack(_ track: StudioTrack) {
        for note in track.notes {
            modelContext.delete(note)
        }
        if let index = project.studioTracks.firstIndex(where: { $0.id == track.id }) {
            project.studioTracks.remove(at: index)
        }
        modelContext.delete(track)

        if editingTrack?.id == track.id {
            editingTrack = nil
        }

        if selectedTrackId == track.id {
            selectedTrackId = project.studioTracks.sorted { $0.orderIndex < $1.orderIndex }.first?.id
        }

        if playback.isPlaying {
            playback.stop(resetPosition: false)
        }
        project.updatedAt = Date()
        try? modelContext.save()
        needsRebuild = true
    }

    private func reorderTracks(_ source: IndexSet, _ destination: Int) {
        var ordered = sortedTracks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, track) in ordered.enumerated() {
            track.orderIndex = index
        }
        project.updatedAt = Date()
        try? modelContext.save()
        needsRebuild = true
    }

    private func addAudioTrack(from recording: Recording) {
        let orderIndex = (project.studioTracks.map(\.orderIndex).max() ?? -1) + 1
        let track = StudioTrack(
            name: recording.name,
            instrument: .audio,
            orderIndex: orderIndex,
            audioRecordingId: recording.id,
            audioStartBeat: 0
        )
        track.project = project
        project.studioTracks.append(track)
        modelContext.insert(track)
        selectedTrackId = track.id
        project.updatedAt = Date()
        try? modelContext.save()
        needsRebuild = true
    }

    private func handlePlay() {
        guard hasSections else {
            showingNoSectionsAlert = true
            return
        }
        if needsRebuild {
            playback.rebuildSequence(project: project)
            needsRebuild = false
        } else {
            playback.updateProject(project)
        }
        playback.play()
    }

    private func handleStop() {
        playback.stop(resetPosition: true)
    }

    private func handleProjectChange(newSignature: String) {
        guard newSignature != lastProjectSignature else { return }
        lastProjectSignature = newSignature

        syncStudioIfNeeded()

        if playback.isPlaying {
            playback.stop(resetPosition: false)
        }
        needsRebuild = true
        playback.prepare(project: project)
        playback.updateProject(project)
    }

    private func applyMixState() {
        playback.applyMixState(project: project)
    }

    private func applyEffects() {
        for track in project.studioTracks {
            playback.updateTrackEffects(
                trackId: track.id,
                reverbEnabled: track.reverbEnabled,
                reverbMix: track.reverbMix,
                delayEnabled: track.delayEnabled,
                delayTime: track.delayTime,
                delayMix: track.delayMix
            )
        }
    }

    private func syncStudioIfNeeded() {
        guard let style = project.studioStyle, !project.studioTracks.isEmpty else { return }

        let signature = projectStudioSignature
        guard project.studioSyncSignature != signature else { return }

        let timeline = StudioGenerator.timeline(for: project)
        let currentChordIds = Set(timeline.chords.map { $0.chord.id })
        let previousChordIds: Set<UUID> = {
            guard let raw = project.studioLastChordIds, !raw.isEmpty else { return [] }
            let ids = raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
            return Set(ids)
        }()
        let previousTotalBars = project.studioLastTotalBars

        let currentSignatureMap = chordSignatureMap(from: timeline)
        let previousSignatureMap = parseChordSignatureMap(project.studioLastChordSignature)

        let newChordIds = currentChordIds.subtracting(previousChordIds)
        let removedChordIds = previousChordIds.subtracting(currentChordIds)
        let barsChanged = timeline.totalBars != previousTotalBars
        let meterChanged = project.studioLastTimeTop != project.timeTop
            || project.studioLastTimeBottom != project.timeBottom
        let keyChanged = project.studioLastKeyRoot != project.keyRoot
            || project.studioLastKeyModeRaw != project.keyMode.rawValue
        let tempoChanged = project.studioLastBpm != project.bpm
        let headerChanged = meterChanged || keyChanged || tempoChanged
        let changedChordIds: Set<UUID> = Set(currentSignatureMap.compactMap { entry in
            let (id, signature) = entry
            guard let previous = previousSignatureMap[id] else { return nil }
            return previous == signature ? nil : id
        })

        let canAppend = !headerChanged
            && removedChordIds.isEmpty
            && !newChordIds.isEmpty
            && timeline.totalBars >= previousTotalBars
            && !barsChanged

        let shouldRegenerateDrums = meterChanged || barsChanged

        if headerChanged || barsChanged || !removedChordIds.isEmpty {
            StudioGenerator.regenerateNotes(
                for: project,
                style: style,
                modelContext: modelContext,
                includeDrums: shouldRegenerateDrums
            )
            project.updatedAt = Date()
        } else if !changedChordIds.isEmpty {
            let affectedSections = sectionIds(containing: changedChordIds)
            let updated = StudioGenerator.replaceNotesForSections(
                for: project,
                style: style,
                modelContext: modelContext,
                sectionIds: affectedSections
            )
            if updated {
                project.updatedAt = Date()
            }
        } else if canAppend {
            let appended = StudioGenerator.appendNotesForNewContent(
                for: project,
                style: style,
                modelContext: modelContext,
                newChordIds: newChordIds,
                previousTotalBars: previousTotalBars
            )
            if appended {
                project.updatedAt = Date()
            }
        } else {
            StudioGenerator.regenerateNotes(
                for: project,
                style: style,
                modelContext: modelContext
            )
            project.updatedAt = Date()
        }

        updateStudioSyncState(signature: signature, timeline: timeline)
        try? modelContext.save()
        needsRebuild = true
    }

    private func updateStudioSyncState(signature: String, timeline: (chords: [StudioGenerator.ChordSpan], totalBars: Int)) {
        project.studioSyncSignature = signature
        project.studioLastChordIds = timeline.chords.map { $0.chord.id.uuidString }.joined(separator: ",")
        project.studioLastTotalBars = timeline.totalBars
        project.studioLastChordSignature = encodeChordSignatureMap(chordSignatureMap(from: timeline))
        project.studioLastBpm = project.bpm
        project.studioLastTimeTop = project.timeTop
        project.studioLastTimeBottom = project.timeBottom
        project.studioLastKeyRoot = project.keyRoot
        project.studioLastKeyModeRaw = project.keyMode.rawValue
    }

    private func chordSignatureMap(from timeline: (chords: [StudioGenerator.ChordSpan], totalBars: Int)) -> [UUID: String] {
        var map: [UUID: String] = [:]
        for span in timeline.chords {
            map[span.chord.id] = chordSignature(span.chord)
        }
        return map
    }

    private func chordSignature(_ chord: ChordEvent) -> String {
        let ext = chord.extensions.joined(separator: ",")
        let beat = String(format: "%.3f", chord.beatOffset)
        let duration = String(format: "%.3f", chord.duration)
        let restFlag = chord.isRest ? "rest" : "chord"
        return "\(chord.barIndex)|\(beat)|\(duration)|\(restFlag)|\(chord.root)|\(chord.quality.rawValue)|\(ext)|\(chord.slashRoot ?? "")"
    }

    private func encodeChordSignatureMap(_ map: [UUID: String]) -> String {
        map.map { "\($0.key.uuidString)=\($0.value)" }.sorted().joined(separator: "||")
    }

    private func parseChordSignatureMap(_ raw: String?) -> [UUID: String] {
        guard let raw, !raw.isEmpty else { return [:] }
        var map: [UUID: String] = [:]
        let entries = raw.components(separatedBy: "||").filter { !$0.isEmpty }
        for entry in entries {
            let parts = entry.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let id = UUID(uuidString: String(parts[0])) else { continue }
            map[id] = String(parts[1])
        }
        return map
    }

    private func sectionIds(containing chordIds: Set<UUID>) -> Set<UUID> {
        guard !chordIds.isEmpty else { return [] }
        let sections = project.arrangementItems.compactMap { $0.sectionTemplate }
        var ids = Set<UUID>()
        for section in sections {
            if section.chordEvents.contains(where: { chordIds.contains($0.id) }) {
                ids.insert(section.id)
            }
        }
        return ids
    }

    private var projectStudioSignature: String {
        let header = "bpm:\(project.bpm)|time:\(project.timeTop)/\(project.timeBottom)|key:\(project.keyRoot)\(project.keyMode.rawValue)"
        let arrangement = project.arrangementItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { item in
                let sectionId = item.sectionTemplate?.id.uuidString ?? "none"
                let label = item.labelOverride ?? ""
                return "\(item.id.uuidString):\(item.orderIndex):\(sectionId):\(label)"
            }
            .joined(separator: "|")
        let arrangementSections = project.arrangementItems.compactMap { $0.sectionTemplate }
        var seenSectionIds = Set<UUID>()
        let sections = arrangementSections
            .filter { seenSectionIds.insert($0.id).inserted }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { section in
                let chords = section.chordEvents
                    .sorted { lhs, rhs in
                        if lhs.barIndex != rhs.barIndex { return lhs.barIndex < rhs.barIndex }
                        if lhs.beatOffset != rhs.beatOffset { return lhs.beatOffset < rhs.beatOffset }
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    .map { chord in
                        let ext = chord.extensions.joined(separator: ",")
                        let beat = String(format: "%.3f", chord.beatOffset)
                        let duration = String(format: "%.3f", chord.duration)
                        let restFlag = chord.isRest ? "rest" : "chord"
                        return "\(chord.barIndex):\(beat):\(duration):\(restFlag):\(chord.root):\(chord.quality.rawValue):\(ext):\(chord.slashRoot ?? "")"
                    }
                    .joined(separator: ";")
                return "\(section.id.uuidString):\(section.bars):\(chords)"
            }
            .joined(separator: "|")
        return [header, arrangement, sections].joined(separator: "#")
    }
}

struct StudioEmptyState: View {
    let project: Project
    let accentColor: Color
    let onPickStyle: () -> Void
    let onAddTrack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(DesignSystem.Typography.md)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                Text("Build Your Studio")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Pick a style and add instruments from your chord progression.")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                if project.studioStyle == nil {
                    Button {
                        onPickStyle()
                    } label: {
                        Text("Pick Style")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(accentColor.opacity(0.3))
                            )
                    }
                }

                if project.studioStyle != nil {
                    Button {
                        onAddTrack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Track")
                        }
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textWhite)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(accentColor)
                        )
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct StudioTimelineSegment: Identifiable {
    let id: String
    let label: String
    let color: Color
    let startBar: Int
    let bars: Int
    
    init(label: String, color: Color, startBar: Int, bars: Int) {
        self.id = "\(startBar)_\(bars)_\(label)"
        self.label = label
        self.color = color
        self.startBar = startBar
        self.bars = bars
    }
}

struct StudioBarSectionInfo: Identifiable {
    let barIndex: Int
    let sectionLabel: String
    let sectionColor: Color
    let chordLabel: String?

    var id: Int { barIndex }
}

struct StudioTimelineView: View {
    let segments: [StudioTimelineSegment]
    let beatsPerBar: Int
    let totalBars: Int
    let currentBeat: Double
    let isPlaying: Bool
    let accentColor: Color
    @Binding var isMetronomeEnabled: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    let onSeek: (Double) -> Void
    @State private var isScrubbing = false
    @State private var scrubBeat: Double = 0

    private var maxBeats: Double {
        Double(max(1, totalBars * beatsPerBar))
    }

    private var displayedBeat: Double {
        isScrubbing ? scrubBeat : currentBeat
    }

    private var currentBarIndex: Int {
        Int(displayedBeat / Double(beatsPerBar))
    }

    private var currentSection: StudioTimelineSegment? {
        segments.last { segment in
            let endBar = segment.startBar + segment.bars
            return currentBarIndex >= segment.startBar && currentBarIndex < endBar
        }
    }

    private var timeLabel: String {
        let bar = max(1, currentBarIndex + 1)
        let beat = max(1, Int(displayedBeat.truncatingRemainder(dividingBy: Double(beatsPerBar))) + 1)
        return "Bar \(bar) · Beat \(beat)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentSection?.label ?? "Timeline")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(timeLabel.uppercased())
                        .font(DesignSystem.Typography.nano)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .tracking(0.6)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        isMetronomeEnabled.toggle()
                    } label: {
                        Image(systemName: "metronome.fill")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(isMetronomeEnabled ? .white : DesignSystem.Colors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isMetronomeEnabled ? accentColor : DesignSystem.Colors.surfaceSecondary)
                                    .overlay(
                                        Circle()
                                            .stroke(isMetronomeEnabled ? accentColor : DesignSystem.Colors.border, lineWidth: 1)
                                    )
                            )
                    }

                    Button {
                        onStop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.surfaceSecondary)
                                    .overlay(
                                        Circle()
                                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                    )
                            )
                    }

                    Button {
                        isPlaying ? onPause() : onPlay()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textWhite)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(accentColor)
                            )
                            .shadow(color: accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                }
            }

            GeometryReader { geo in
                let barWidth = geo.size.width / CGFloat(max(1, totalBars))
                let progressX = CGFloat(displayedBeat / Double(beatsPerBar)) * barWidth

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.Colors.backgroundTertiary)
                        .frame(height: 18)
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 1)
                        )

                    ForEach(segments) { segment in
                        let width = CGFloat(segment.bars) * barWidth
                        let x = CGFloat(segment.startBar) * barWidth
                        Capsule()
                            .fill(segment.color.opacity(0.25))
                            .frame(width: width, height: 18)
                            .overlay(
                                Capsule()
                                    .stroke(segment.color.opacity(0.5), lineWidth: 1)
                            )
                            .offset(x: x)
                    }

                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(2, progressX), height: 18)

                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.backgroundSecondary)
                            .frame(width: 18, height: 18)
                            .shadow(color: accentColor.opacity(0.25), radius: 4, x: 0, y: 2)
                        Circle()
                            .stroke(accentColor, lineWidth: 2)
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(accentColor)
                            .frame(width: 4, height: 4)
                    }
                    .offset(x: max(0, min(progressX - 9, geo.size.width - 18)))
                }
                .contentShape(Rectangle().inset(by: -12))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clampedX = max(0, min(value.location.x, geo.size.width))
                            let beat = Double(clampedX / barWidth) * Double(beatsPerBar)
                            scrubBeat = min(beat, maxBeats)
                            isScrubbing = true
                        }
                        .onEnded { _ in
                            if isScrubbing {
                                onSeek(scrubBeat)
                            }
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 20)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

struct StudioEditorTransportView: View {
    let title: String
    let barBeatLabel: String
    let isPlaying: Bool
    let accentColor: Color
    @Binding var isMetronomeEnabled: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? "Project" : title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                Text(barBeatLabel.uppercased())
                    .font(DesignSystem.Typography.nano)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .tracking(0.5)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    isMetronomeEnabled.toggle()
                } label: {
                    Image(systemName: "metronome.fill")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(isMetronomeEnabled ? Color.white : DesignSystem.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(isMetronomeEnabled ? accentColor : DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    Circle()
                                        .stroke(isMetronomeEnabled ? accentColor : DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    Circle()
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    isPlaying ? onPause() : onPlay()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textWhite)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(accentColor)
                        )
                        .shadow(color: accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

struct StudioEditorPlayhead: View {
    let x: CGFloat
    let height: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(0.85))
                .frame(width: 2, height: max(0, height))
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .offset(x: -3, y: -3)
                .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 1)
        }
        .offset(x: x, y: 0)
        .allowsHitTesting(false)
    }
}

struct StudioTrackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    @Bindable var track: StudioTrack
    let totalBars: Int
    let beatsPerBar: Int
    let timeBottom: Int
    let style: StudioStyle?
    @ObservedObject var playback: StudioPlaybackEngine
    let onNotesChanged: () -> Void
    let onPlay: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    @State private var showingRegenerateOptions = false
    @State private var regenerateIntensity: Double = 0.5
    @State private var regenerateComplexity: Double = 0.5
    @State private var regenerateNaturalness: Double = 0.0
    @State private var regenerateArpeggioEnabled = false
    @State private var regenerateArpeggioRate = "1/8"
    @State private var regenerateArpeggioPattern = "Up"
    @State private var effectsDebounceTask: Task<Void, Never>?

    private var accentColor: Color {
        track.instrument.color
    }

    private var trackSubtitle: String {
        if let variant = track.variant?.displayName, !variant.isEmpty {
            return "\(track.instrument.title) - \(variant)"
        }
        return track.instrument.title
    }

    private var keyLabel: String {
        let mode = project.keyMode == .minor ? "Minor" : "Major"
        return "\(project.keyRoot) \(mode)"
    }

    private var infoItems: [StudioInfoChipData] {
        let items: [StudioInfoChipData] = [
            StudioInfoChipData(icon: DesignSystem.Icons.key, text: keyLabel),
            StudioInfoChipData(icon: DesignSystem.Icons.tempo, text: "\(project.bpm) BPM"),
            StudioInfoChipData(icon: DesignSystem.Icons.timeSignature, text: "\(project.timeTop)/\(project.timeBottom)")
        ]
        return items
    }

    private var canRegenerate: Bool {
        !track.instrument.isAudio && style != nil
    }

    private var panLabel: String {
        if track.pan < -0.05 {
            return "L\(Int(abs(track.pan) * 100))"
        } else if track.pan > 0.05 {
            return "R\(Int(track.pan * 100))"
        } else {
            return "C"
        }
    }

    private var timelineBeats: Double {
        Double(max(1, totalBars * beatsPerBar))
    }

    private var transportBarBeatLabel: String {
        let beat = min(max(playback.currentBeat, 0), timelineBeats)
        let barNumber = max(1, Int(beat / Double(beatsPerBar)) + 1)
        let beatNumber = max(1, Int(beat.truncatingRemainder(dividingBy: Double(beatsPerBar))) + 1)
        return "Bar \(barNumber) · Beat \(beatNumber)"
    }

    private var barSectionInfos: [StudioBarSectionInfo] {
        let orderedItems = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        var infos: [StudioBarSectionInfo] = []
        var globalBar = 0

        for item in orderedItems {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            let sectionLabel = item.labelOverride?.isEmpty == false ? item.labelOverride! : section.name
            let chordsByBar = Dictionary(grouping: section.chordEvents, by: \.barIndex)

            for localBar in 0..<bars {
                let chords = (chordsByBar[localBar] ?? []).sorted { lhs, rhs in
                    if lhs.beatOffset != rhs.beatOffset { return lhs.beatOffset < rhs.beatOffset }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                infos.append(
                    StudioBarSectionInfo(
                        barIndex: globalBar + localBar,
                        sectionLabel: sectionLabel,
                        sectionColor: section.color,
                        chordLabel: chordSummary(for: chords)
                    )
                )
            }

            globalBar += bars
        }

        if infos.isEmpty {
            infos = (0..<max(1, totalBars)).map { index in
                StudioBarSectionInfo(
                    barIndex: index,
                    sectionLabel: "Song",
                    sectionColor: accentColor,
                    chordLabel: nil
                )
            }
        }

        return infos
    }

    private func chordSummary(for chords: [ChordEvent]) -> String? {
        let symbols = chords.map(chordDisplayText(for:))
        guard !symbols.isEmpty else { return nil }
        let preview = Array(symbols.prefix(2)).joined(separator: " · ")
        if symbols.count > 2 {
            return "\(preview) +"
        }
        return preview
    }

    private func chordDisplayText(for chord: ChordEvent) -> String {
        if !chord.display.isEmpty {
            return chord.display
        }
        if chord.isRest {
            return "Rest"
        }
        var text = chord.root + chord.quality.symbol
        if !chord.extensions.isEmpty {
            text += chord.extensions.joined()
        }
        if let slash = chord.slashRoot, !slash.isEmpty {
            text += "/\(slash)"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(DesignSystem.Colors.border)

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    trackControls
                    editorContent
                }
                .padding(DesignSystem.Spacing.lg)
                .padding(.bottom, 80)
            }

            if !project.arrangementItems.isEmpty {
                playbackHud
            }
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showingRegenerateOptions) {
            RegenerateOptionsView(
                trackName: track.name,
                instrument: track.instrument,
                variant: track.variant,
                style: style,
                intensity: $regenerateIntensity,
                complexity: $regenerateComplexity,
                naturalness: $regenerateNaturalness,
                arpeggioEnabled: $regenerateArpeggioEnabled,
                arpeggioRate: $regenerateArpeggioRate,
                arpeggioPattern: $regenerateArpeggioPattern,
                onRegenerate: executeRegenerate,
                onCancel: {
                    showingRegenerateOptions = false
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    Circle()
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(trackSubtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(0.6), lineWidth: 1)
                        )
                    Image(systemName: track.instrument.icon)
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(accentColor)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(infoItems) { item in
                        StudioInfoChip(
                            icon: item.icon,
                            text: item.text,
                            color: accentColor
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            DesignSystem.Colors.surfaceSecondary
        )
    }

    private var trackControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Track Controls")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                if !track.instrument.isAudio {
                    Button {
                        openRegenerateOptions()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(DesignSystem.Typography.caption)
                            Text("Regenerate")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(accentColor.opacity(canRegenerate ? 0.3 : 0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(accentColor.opacity(canRegenerate ? 0.7 : 0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRegenerate)
                }
            }

            if !track.instrument.variants.isEmpty {
                trackVariantPicker
            }

            // Compact mix controls so the editor has more vertical space.
            HStack(spacing: 12) {
                trackSliderCompact(
                    icon: "speaker.wave.2.fill",
                    title: "Volume",
                    valueText: "\(Int(track.volume * 100))%",
                    value: $track.volume,
                    range: 0...1
                )

                trackSliderCompact(
                    icon: "l.joystick.fill",
                    title: "Pan",
                    valueText: panLabel,
                    value: $track.pan,
                    range: -1...1
                )
            }

            // Effects section (non-audio instruments only)
            if !track.instrument.isAudio {
                trackEffectsSection
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var trackVariantPicker: some View {
        HStack {
            Text("Variant")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            Menu {
                ForEach(track.instrument.variants, id: \.self) { variant in
                    Button {
                        track.variant = variant
                        onNotesChanged()
                    } label: {
                        HStack {
                                    Text(variant.displayName)
                                    if track.variant == variant {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                let resolvedVariant = SoundFontManager.resolvedVariant(for: track.instrument, variant: track.variant)
                HStack(spacing: 6) {
                    Text(resolvedVariant?.displayName ?? track.instrument.variants.first?.displayName ?? track.instrument.title)
                        .font(DesignSystem.Typography.caption)
                    Image(systemName: "chevron.down")
                        .font(DesignSystem.Typography.caption2)
                }
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(accentColor.opacity(0.5), lineWidth: 1)
                        )
                )
            }
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        if track.instrument == .drums {
            StudioDrumEditor(
                track: track,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                totalBars: totalBars,
                barSectionInfos: barSectionInfos,
                currentBeat: playback.currentBeat,
                isPlaying: playback.isPlaying,
                style: style,
                onNotesChanged: onNotesChanged
            )
        } else if track.instrument == .audio {
            StudioAudioTrackView(track: track, project: project)
        } else {
            StudioNoteEditor(
                track: track,
                beatsPerBar: beatsPerBar,
                totalBars: totalBars,
                barSectionInfos: barSectionInfos,
                currentBeat: playback.currentBeat,
                isPlaying: playback.isPlaying,
                style: style,
                onNotesChanged: onNotesChanged
            )
        }
    }

    private func trackSliderCompact(
        icon: String,
        title: String,
        valueText: String,
        value: Binding<Float>,
        range: ClosedRange<Float>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text(title)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
                Text(valueText)
                    .font(DesignSystem.Typography.caption2.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }

            Slider(value: value, in: range)
                .tint(accentColor)
                .onChange(of: value.wrappedValue) { _, _ in
                    updateTrackMix()
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func updateTrackMix() {
        playback.updateTrackMix(trackId: track.id, volume: track.volume, pan: track.pan)
    }

    private func updateTrackEffects() {
        playback.updateTrackEffects(track: track)
    }

    private func debouncedEffectsUpdate() {
        effectsDebounceTask?.cancel()
        effectsDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            updateTrackEffects()
        }
    }

    private var trackEffectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with icon
            HStack(spacing: 6) {
                Image(systemName: "waveform.badge.plus")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(accentColor)
                Text("Effects")
                    .font(DesignSystem.Typography.caption.bold())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .padding(.bottom, 2)

            // Effect cards in a clean grid
            VStack(spacing: 10) {
                reverbEffectCard
                delayEffectCard
                eqEffectCard
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DesignSystem.Colors.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var reverbEffectCard: some View {
        effectCard(
            icon: "waveform.path.ecg",
            title: "Reverb",
            isEnabled: $track.reverbEnabled,
            onToggle: updateTrackEffects
        ) {
            VStack(spacing: 6) {
                Picker("Preset", selection: $track.reverbPreset) {
                    ForEach(ReverbPreset.allCases) { preset in
                        Text(preset.shortTitle)
                            .font(DesignSystem.Typography.caption2)
                            .tag(preset)
                    }
                }
                .font(DesignSystem.Typography.caption2)
                .pickerStyle(.segmented)
                .scaleEffect(x: 1, y: 0.85)
                .frame(height: 26)
                .onChange(of: track.reverbPreset) { _, _ in updateTrackEffects() }

                fxSlider(label: "Mix", value: $track.reverbMix, range: 0...1,
                         display: "\(Int(track.reverbMix * 100))%")
            }
        }
    }

    private var delayEffectCard: some View {
        effectCard(
            icon: "arrow.triangle.2.circlepath",
            title: "Delay",
            isEnabled: $track.delayEnabled,
            onToggle: updateTrackEffects
        ) {
            VStack(spacing: 6) {
                Picker("Sync", selection: $track.delaySyncMode) {
                    ForEach(DelaySyncMode.allCases) { mode in
                        Text(mode.shortTitle)
                            .font(DesignSystem.Typography.caption2)
                            .tag(mode)
                    }
                }
                .font(DesignSystem.Typography.caption2)
                .pickerStyle(.segmented)
                .scaleEffect(x: 1, y: 0.85)
                .frame(height: 26)
                .onChange(of: track.delaySyncMode) { _, _ in updateTrackEffects() }

                if track.delaySyncMode == .free {
                    fxSlider(label: "Time", value: $track.delayTime, range: 0.05...1.0,
                             display: "\(String(format: "%.2f", track.delayTime))s")
                }
                fxSlider(label: "Mix", value: $track.delayMix, range: 0...1,
                         display: "\(Int(track.delayMix * 100))%")
            }
        }
    }

    private var eqEffectCard: some View {
        effectCard(
            icon: "slider.horizontal.3",
            title: "EQ",
            isEnabled: $track.eqEnabled,
            onToggle: updateTrackEffects
        ) {
            VStack(spacing: 4) {
                fxSlider(label: "Low", value: $track.eqLowGain, range: -12...12,
                         display: "\(String(format: "%.0f", track.eqLowGain))dB")
                fxSlider(label: "Mid", value: $track.eqMidGain, range: -12...12,
                         display: "\(String(format: "%.0f", track.eqMidGain))dB")
                fxSlider(label: "High", value: $track.eqHighGain, range: -12...12,
                         display: "\(String(format: "%.0f", track.eqHighGain))dB")
            }
        }
    }

    private func effectCard<Content: View>(
        icon: String,
        title: String,
        isEnabled: Binding<Bool>,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header row: icon + title + toggle
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isEnabled.wrappedValue ? accentColor : DesignSystem.Colors.textSecondary)
                    .frame(width: 16)
                Text(title)
                    .font(DesignSystem.Typography.caption2.weight(.semibold))
                    .foregroundStyle(isEnabled.wrappedValue ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: accentColor))
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .onChange(of: isEnabled.wrappedValue) { _, _ in onToggle() }
            }

            // Expandable detail when enabled
            if isEnabled.wrappedValue {
                content()
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEnabled.wrappedValue ? accentColor.opacity(0.06) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isEnabled.wrappedValue ? accentColor.opacity(0.2) : DesignSystem.Colors.border.opacity(0.3), lineWidth: 1)
                )
        )
        .animation(.none, value: isEnabled.wrappedValue)
    }

    private func fxSlider(label: String, value: Binding<Float>, range: ClosedRange<Float>, display: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 30, alignment: .leading)
            Slider(value: value, in: range)
                .tint(accentColor)
                .onChange(of: value.wrappedValue) { _, _ in debouncedEffectsUpdate() }
            Text(display)
                .font(DesignSystem.Typography.caption2.monospacedDigit())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private func openRegenerateOptions() {
        guard canRegenerate else { return }
        regenerateIntensity = track.regenerateIntensity
        regenerateComplexity = track.regenerateComplexity
        regenerateNaturalness = track.regenerateNaturalness
        regenerateArpeggioEnabled = track.regenerateArpeggioEnabled
        regenerateArpeggioRate = track.regenerateArpeggioRate
        regenerateArpeggioPattern = normalizedArpeggioPattern(track.regenerateArpeggioPattern)
        showingRegenerateOptions = true
    }

    private func executeRegenerate() {
        guard let style else { return }

        for note in track.notes {
            modelContext.delete(note)
        }
        track.notes.removeAll()

        let newNotes = StudioGenerator.generateNotes(
            for: track.instrument,
            project: project,
            style: style,
            drumPreset: track.drumPreset,
            variant: track.variant,
            octaveShift: track.octaveShift,
            intensity: regenerateIntensity,
            complexity: regenerateComplexity,
            naturalness: regenerateNaturalness,
            arpeggioEnabled: regenerateArpeggioEnabled,
            arpeggioRate: regenerateArpeggioRate,
            arpeggioPattern: regenerateArpeggioPattern
        )

        for note in newNotes {
            note.track = track
            track.notes.append(note)
            modelContext.insert(note)
        }

        track.regenerateIntensity = regenerateIntensity
        track.regenerateComplexity = regenerateComplexity
        track.regenerateNaturalness = regenerateNaturalness
        track.regenerateArpeggioEnabled = regenerateArpeggioEnabled
        track.regenerateArpeggioRate = regenerateArpeggioRate
        track.regenerateArpeggioPattern = normalizedArpeggioPattern(regenerateArpeggioPattern)
        project.updatedAt = Date()
        try? modelContext.save()
        onNotesChanged()
        onStop()
        showingRegenerateOptions = false
    }

    private func normalizedArpeggioPattern(_ raw: String) -> String {
        switch raw.lowercased() {
        case "down":
            return "Down"
        case "updown":
            return "UpDown"
        default:
            return "Up"
        }
    }

    private var playbackHud: some View {
        VStack(spacing: 0) {
            StudioEditorTransportView(
                title: project.title,
                barBeatLabel: transportBarBeatLabel,
                isPlaying: playback.isPlaying,
                accentColor: accentColor,
                isMetronomeEnabled: $playback.isMetronomeEnabled,
                onPlay: onPlay,
                onPause: onPause,
                onStop: onStop
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
    }
}

struct StudioTrackEditorHint: View {
    let accentColor: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(accentColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(accentColor.opacity(0.2))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Select a track, then tap Edit")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Open the full-screen editor to write notes and grooves.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

private struct StudioInfoChipData: Identifiable {
    let icon: String
    let text: String
    var id: String { "\(icon)-\(text)" }
}

private struct StudioInfoChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.caption2)
            Text(text)
                .font(DesignSystem.Typography.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(DesignSystem.Colors.textPrimary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

struct StudioTrackList: View {
    let tracks: [StudioTrack]
    @Binding var selectedTrackId: UUID?
    let onTrackStructureChange: () -> Void
    let onMixChange: () -> Void
    let onEffectsChange: () -> Void
    let onDelete: (StudioTrack) -> Void
    let onOpenEditor: (StudioTrack) -> Void
    let onReorder: (IndexSet, Int) -> Void

    @State private var draggingId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tracks")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                if tracks.count > 1 {
                    Text("Hold & drag to reorder")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            VStack(spacing: 8) {
                ForEach(tracks) { track in
                    SwipeActionRow(actions: [
                        SwipeActionItem(systemImage: "trash.fill", tint: DesignSystem.Colors.error, role: .destructive) {
                            onDelete(track)
                        }
                    ]) {
                        StudioTrackRow(
                            track: track,
                            isSelected: selectedTrackId == track.id,
                            onSelect: { selectedTrackId = track.id },
                            onTrackStructureChange: onTrackStructureChange,
                            onMixChange: onMixChange,
                            onEffectsChange: onEffectsChange,
                            onDelete: { onDelete(track) },
                            onOpenEditor: { onOpenEditor(track) }
                        )
                    }
                    .opacity(draggingId == track.id ? 0.5 : 1.0)
                    .onDrag {
                        draggingId = track.id
                        return NSItemProvider(object: track.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TrackReorderDelegate(
                        targetTrack: track,
                        tracks: tracks,
                        draggingId: $draggingId,
                        onReorder: onReorder
                    ))
                }
            }
        }
    }
}

private struct TrackReorderDelegate: DropDelegate {
    let targetTrack: StudioTrack
    let tracks: [StudioTrack]
    @Binding var draggingId: UUID?
    let onReorder: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingId,
              draggingId != targetTrack.id,
              let fromIndex = tracks.firstIndex(where: { $0.id == draggingId }),
              let toIndex = tracks.firstIndex(where: { $0.id == targetTrack.id })
        else { return }
        let dest = toIndex > fromIndex ? toIndex + 1 : toIndex
        withAnimation(.easeInOut(duration: 0.2)) {
            onReorder(IndexSet(integer: fromIndex), dest)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropExited(info: DropInfo) {}

    func validateDrop(info: DropInfo) -> Bool { true }
}

struct StudioTrackRow: View {
    @Bindable var track: StudioTrack
    let isSelected: Bool
    let onSelect: () -> Void
    let onTrackStructureChange: () -> Void
    let onMixChange: () -> Void
    let onEffectsChange: () -> Void
    let onDelete: () -> Void
    let onOpenEditor: () -> Void
    @State private var isExpanded: Bool = false
    @State private var mixDebounceTask: Task<Void, Never>?

    private var panLabel: String {
        if track.pan < -0.05 {
            return "L\(Int(abs(track.pan) * 100))"
        } else if track.pan > 0.05 {
            return "R\(Int(track.pan * 100))"
        } else {
            return "C"
        }
    }

    private func debouncedMixChange() {
        mixDebounceTask?.cancel()
        mixDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            onMixChange()
        }
    }

    private var effectTogglesView: some View {
        let color = track.instrument.color
        return HStack(spacing: 12) {
            Button {
                track.reverbEnabled.toggle()
                onEffectsChange()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg").font(DesignSystem.Typography.caption2)
                    Text("Reverb").font(DesignSystem.Typography.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(track.reverbEnabled ? color.opacity(0.3) : DesignSystem.Colors.surface))
                .overlay(Capsule().strokeBorder(track.reverbEnabled ? color : DesignSystem.Colors.border, lineWidth: 1))
            }
            .foregroundStyle(track.reverbEnabled ? color : DesignSystem.Colors.textSecondary)

            Button {
                track.delayEnabled.toggle()
                onEffectsChange()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(DesignSystem.Typography.caption2)
                    Text("Delay").font(DesignSystem.Typography.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(track.delayEnabled ? color.opacity(0.3) : DesignSystem.Colors.surface))
                .overlay(Capsule().strokeBorder(track.delayEnabled ? color : DesignSystem.Colors.border, lineWidth: 1))
            }
            .foregroundStyle(track.delayEnabled ? color : DesignSystem.Colors.textSecondary)

            Spacer()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: track.instrument.icon)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(track.instrument.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    // Variant selector inline
                    if !track.instrument.variants.isEmpty {
                        Menu {
                            ForEach(track.instrument.variants, id: \.self) { variant in
                                Button {
                                    track.variant = variant
                                    onTrackStructureChange()
                                } label: {
                                    HStack {
                                        Text(variant.displayName)
                                        if track.variant == variant {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(track.variant?.displayName ?? track.instrument.variants.first?.displayName ?? track.instrument.title)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(DesignSystem.Typography.nano)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    } else {
                        Text(track.instrument.title)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                Button {
                    track.isMuted.toggle()
                    onMixChange()
                } label: {
                    Text("M")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(track.isMuted ? DesignSystem.Colors.backgroundSecondary : DesignSystem.Colors.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(track.isMuted ? track.instrument.color : DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    Circle()
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    track.isSolo.toggle()
                    onMixChange()
                } label: {
                    Text("S")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(track.isSolo ? DesignSystem.Colors.backgroundSecondary : DesignSystem.Colors.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(track.isSolo ? track.instrument.color : DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    Circle()
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onOpenEditor()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    Circle()
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            // Expandable volume & pan controls
            if isExpanded {
                VStack(spacing: 8) {
                    Divider().overlay(DesignSystem.Colors.border)

                    // Volume
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: 16)
                        Slider(value: $track.volume, in: 0...1)
                            .tint(track.instrument.color)
                            .onChange(of: track.volume) { _, _ in
                                debouncedMixChange()
                            }
                        Text("\(Int(track.volume * 100))%")
                            .font(DesignSystem.Typography.caption2.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 36, alignment: .trailing)
                    }

                    // Pan
                    HStack(spacing: 8) {
                        Image(systemName: "l.joystick.fill")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: 16)
                        Slider(value: $track.pan, in: -1...1)
                            .tint(track.instrument.color)
                            .onChange(of: track.pan) { _, _ in
                                debouncedMixChange()
                            }
                        Text(panLabel)
                            .font(DesignSystem.Typography.caption2.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 36, alignment: .trailing)
                    }

                    // Quick effect toggles
                    if !track.instrument.isAudio {
                        effectTogglesView
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isSelected ? track.instrument.color : DesignSystem.Colors.border, lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
            isExpanded.toggle()
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Track", systemImage: "trash.fill")
            }
        }
    }
    
}

struct StudioAudioTrackView: View {
    @Bindable var track: StudioTrack
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Track")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            if let recording = project.recordings.first(where: { $0.id == track.audioRecordingId }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.name)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Starts at beat \(String(format: "%.1f", track.audioStartBeat))")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                )
            } else {
                Text("Recording not found.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Text("Audio editing and playback will appear here.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(track.instrument.color.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct StudioNoteEditor: View {
    @Bindable var track: StudioTrack
    let beatsPerBar: Int
    let totalBars: Int
    let barSectionInfos: [StudioBarSectionInfo]
    let currentBeat: Double
    let isPlaying: Bool
    let style: StudioStyle?
    let onNotesChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selectedNoteId: UUID?
    @State private var defaultDuration: Double = 1.0

    private let stepsPerBeat = 4
    private let barRulerHeight: CGFloat = 34
    private let pitchColumnWidth: CGFloat = 52
    private let cellWidth: CGFloat = 28
    private let cellHeight: CGFloat = 26
    private let durationOptions: [Double] = [0.25, 0.5, 1, 2, 4]
    private let octaveRange = -4...4

    private var totalSteps: Int {
        max(1, totalBars * beatsPerBar * stepsPerBeat)
    }

    private var stepLength: Double {
        1.0 / Double(stepsPerBeat)
    }

    private var pitchRows: [PitchRow] {
        PitchRow.rows(
            for: track.instrument,
            style: style,
            octaveShift: track.octaveShift
        )
    }

    // Cache row indexes by pitch to avoid repeated scans while rendering notes.
    private var pitchRowIndexByPitch: [Int: Int] {
        Dictionary(uniqueKeysWithValues: pitchRows.enumerated().map { ($0.element.pitch, $0.offset) })
    }

    private var gridHeight: CGFloat {
        let contentHeight = CGFloat(pitchRows.count) * cellHeight
        return min(contentHeight, 420)
    }

    private var selectedNote: StudioNote? {
        guard let selectedNoteId else { return nil }
        return track.notes.first { $0.id == selectedNoteId }
    }

    private var stepsPerBar: Int {
        beatsPerBar * stepsPerBeat
    }

    private var barInfoByIndex: [Int: StudioBarSectionInfo] {
        Dictionary(uniqueKeysWithValues: barSectionInfos.map { ($0.barIndex, $0) })
    }

    private var normalizedBarInfos: [StudioBarSectionInfo] {
        (0..<max(1, totalBars)).map { bar in
            if let info = barInfoByIndex[bar] {
                return info
            }
            return StudioBarSectionInfo(
                barIndex: bar,
                sectionLabel: "Song",
                sectionColor: track.instrument.color,
                chordLabel: nil
            )
        }
    }

    private var selectedNoteSummary: String? {
        guard let selectedNote else { return nil }
        let bar = Int(selectedNote.startBeat / Double(beatsPerBar)) + 1
        return "\(midiNoteName(for: selectedNote.pitch)) · Bar \(bar)"
    }

    private var timelineBeats: Double {
        Double(max(1, totalBars * beatsPerBar))
    }

    private var shouldShowPlayhead: Bool {
        isPlaying || currentBeat > 0.0001
    }

    private var playheadX: CGFloat {
        let width = CGFloat(totalSteps) * cellWidth
        guard width > 0 else { return 0 }
        let clampedBeat = min(max(currentBeat, 0), timelineBeats)
        let x = CGFloat(clampedBeat / timelineBeats) * width
        return min(max(0, x), max(0, width - 2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Note Editor")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Tap to add · Double tap to delete · Hold note for velocity")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Menu {
                    ForEach(durationOptions, id: \.self) { option in
                        Button {
                            defaultDuration = option
                        } label: {
                            Text("\(option, specifier: "%.2g") beats")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(DesignSystem.Typography.caption2)
                        Text("\(defaultDuration, specifier: "%.2g")")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Image(systemName: "chevron.down")
                            .font(DesignSystem.Typography.caption2)
                    }
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(track.instrument.color.opacity(0.18))
                    )
                }

                octaveControl
            }

            if let summary = selectedNoteSummary, let selectedNote {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(DesignSystem.Typography.caption2)
                    Text(summary)
                        .font(DesignSystem.Typography.caption2)
                    Spacer()
                    Text("Vel \(selectedNote.velocity)")
                        .font(DesignSystem.Typography.caption2.monospacedDigit())
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(track.instrument.color.opacity(0.12))
                )
            }

            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Color.clear
                            .frame(height: barRulerHeight)
                        PitchLabelColumn(
                            rows: pitchRows,
                            rowHeight: cellHeight,
                            columnWidth: pitchColumnWidth
                        )
                    }
                    .frame(width: pitchColumnWidth, alignment: .trailing)

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            StudioNoteBarRuler(
                                barInfos: normalizedBarInfos,
                                stepsPerBar: stepsPerBar,
                                cellWidth: cellWidth,
                                height: barRulerHeight
                            )
                            .frame(
                                width: CGFloat(totalSteps) * cellWidth,
                                height: barRulerHeight,
                                alignment: .leading
                            )

                            ZStack(alignment: .topLeading) {
                                GridBackground(
                                    rows: pitchRows.count,
                                    columns: totalSteps,
                                    beatsPerBar: beatsPerBar,
                                    stepsPerBeat: stepsPerBeat,
                                    cellWidth: cellWidth,
                                    cellHeight: cellHeight,
                                    barInfos: normalizedBarInfos
                                )

                                ForEach(track.notes, id: \.id) { note in
                                    if let rowIndex = pitchRowIndexByPitch[note.pitch] {
                                        StudioNoteBlock(
                                            note: note,
                                            rowIndex: rowIndex,
                                            stepLength: stepLength,
                                            cellWidth: cellWidth,
                                            cellHeight: cellHeight,
                                            maxBeats: Double(totalBars * beatsPerBar),
                                            color: track.instrument.color,
                                            isSelected: selectedNoteId == note.id,
                                            onSelect: { selectedNoteId = note.id },
                                            onDelete: { deleteNote(note) },
                                            onCycleVelocity: { cycleVelocity(for: note) },
                                            onNotesChanged: onNotesChanged
                                        )
                                    }
                                }

                                if shouldShowPlayhead {
                                    StudioEditorPlayhead(
                                        x: playheadX,
                                        height: CGFloat(pitchRows.count) * cellHeight,
                                        color: track.instrument.color
                                    )
                                }
                            }
                            .frame(
                                width: CGFloat(totalSteps) * cellWidth,
                                height: CGFloat(pitchRows.count) * cellHeight
                            )
                            .contentShape(Rectangle())
                            .onTapGesture(count: 1, coordinateSpace: .local) { location in
                                handleGridTap(location: location)
                            }
                        }
                    }
                }
            }
            .frame(height: gridHeight + barRulerHeight + 8)

            NoteVelocityLegend(color: track.instrument.color)

            if let note = selectedNote {
                NoteInspector(
                    note: note,
                    maxDuration: maxDuration(for: note),
                    stepLength: stepLength,
                    onDelete: { deleteNote(note) },
                    onNoteUpdated: onNotesChanged
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(track.instrument.color.opacity(0.4), lineWidth: 1)
                )
        )
        .onChange(of: track.octaveShift) { oldValue, newValue in
            guard oldValue != newValue else { return }
            applyOctaveShift(from: oldValue, to: newValue)
        }
    }

    private var octaveControl: some View {
        HStack(spacing: 6) {
            octaveButton(
                systemName: "minus",
                isEnabled: track.octaveShift > octaveRange.lowerBound
            ) {
                adjustOctave(-1)
            }

            Text("Oct \(track.octaveShift >= 0 ? "+\(track.octaveShift)" : "\(track.octaveShift)")")
                .font(DesignSystem.Typography.caption2)

            octaveButton(
                systemName: "plus",
                isEnabled: track.octaveShift < octaveRange.upperBound
            ) {
                adjustOctave(1)
            }
        }
        .foregroundStyle(DesignSystem.Colors.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(track.instrument.color.opacity(0.12))
        )
        .buttonStyle(.plain)
    }

    private func octaveButton(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(DesignSystem.Typography.caption2)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(track.instrument.color.opacity(0.2))
                )
        }
        .disabled(!isEnabled)
        .contentShape(Circle())
    }

    private func handleGridTap(location: CGPoint) {
        guard location.x >= 0,
              location.y >= 0,
              location.x < CGFloat(totalSteps) * cellWidth,
              location.y < CGFloat(pitchRows.count) * cellHeight else {
            return
        }

        if let note = noteAt(location: location) {
            selectedNoteId = note.id
            return
        }

        let column = Int(location.x / cellWidth)
        let row = Int(location.y / cellHeight)
        let pitch = pitchRows[row].pitch
        let startBeat = Double(column) * stepLength
        addNote(startBeat: startBeat, pitch: pitch)
    }

    private func noteAt(location: CGPoint) -> StudioNote? {
        for note in track.notes {
            guard let rowIndex = pitchRowIndexByPitch[note.pitch] else { continue }
            let x = CGFloat(note.startBeat / stepLength) * cellWidth
            let width = CGFloat(note.duration / stepLength) * cellWidth
            let y = CGFloat(rowIndex) * cellHeight
            let rect = CGRect(x: x, y: y, width: width, height: cellHeight)
            if rect.contains(location) {
                return note
            }
        }
        return nil
    }

    private func addNote(startBeat: Double, pitch: Int) {
        let timelineBeats = Double(totalBars * beatsPerBar)
        guard startBeat < timelineBeats else { return }

        let maxDuration = max(stepLength, timelineBeats - startBeat)
        let duration = min(defaultDuration, maxDuration)
        let noteDuration = track.instrument == .drums ? stepLength : duration

        removeOverlappingNotes(pitch: pitch, startBeat: startBeat, duration: noteDuration)

        let newNote = StudioNote(
            startBeat: startBeat,
            duration: noteDuration,
            pitch: pitch,
            velocity: 90
        )
        newNote.track = track
        track.notes.append(newNote)
        modelContext.insert(newNote)
        selectedNoteId = newNote.id
        onNotesChanged()
    }

    private func removeOverlappingNotes(pitch: Int, startBeat: Double, duration: Double) {
        let endBeat = startBeat + duration
        let toRemove = track.notes.filter { note in
            guard note.pitch == pitch else { return false }
            let noteEnd = note.startBeat + note.duration
            return max(note.startBeat, startBeat) < min(noteEnd, endBeat)
        }
        for note in toRemove {
            deleteNote(note)
        }
    }

    private func deleteNote(_ note: StudioNote) {
        if let index = track.notes.firstIndex(where: { $0.id == note.id }) {
            track.notes.remove(at: index)
        }
        modelContext.delete(note)
        if selectedNoteId == note.id {
            selectedNoteId = nil
        }
        onNotesChanged()
    }

    private func cycleVelocity(for note: StudioNote) {
        note.velocity = nextVelocity(for: note.velocity)
        selectedNoteId = note.id
        onNotesChanged()
    }

    private func nextVelocity(for current: Int) -> Int {
        if current >= 108 { return 56 }   // ghost
        if current <= 64 { return 92 }    // normal
        return 120                        // accent
    }

    private func midiNoteName(for midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let name = names[(midi % 12 + 12) % 12]
        let octave = (midi / 12) - 1
        return "\(name)\(octave)"
    }

    private func maxDuration(for note: StudioNote) -> Double {
        let timelineBeats = Double(totalBars * beatsPerBar)
        return max(stepLength, timelineBeats - note.startBeat)
    }

    private func adjustOctave(_ delta: Int) {
        let proposed = track.octaveShift + delta
        let clamped = min(octaveRange.upperBound, max(octaveRange.lowerBound, proposed))
        guard clamped != track.octaveShift else { return }
        track.octaveShift = clamped
    }

    private func applyOctaveShift(from oldValue: Int, to newValue: Int) {
        let delta = newValue - oldValue
        guard delta != 0 else { return }
        let semitones = delta * 12
        let targetRange = StudioGenerator.instrumentRange(
            for: track.instrument,
            style: style,
            octaveShift: newValue
        )

        for note in track.notes {
            note.pitch = fitPitch(note.pitch + semitones, into: targetRange)
        }
        onNotesChanged()
    }

    private func fitPitch(_ pitch: Int, into range: ClosedRange<Int>) -> Int {
        var adjusted = pitch
        while adjusted < range.lowerBound {
            adjusted += 12
        }
        while adjusted > range.upperBound {
            adjusted -= 12
        }
        return min(max(adjusted, range.lowerBound), range.upperBound)
    }
}

struct PitchRow: Identifiable {
    let id = UUID()
    let pitch: Int
    let label: String

    static func rows(
        for instrument: StudioInstrument,
        style: StudioStyle?,
        octaveShift: Int
    ) -> [PitchRow] {
        switch instrument {
        case .drums:
            return [
                PitchRow(pitch: 36, label: "Kick"),
                PitchRow(pitch: 38, label: "Snare"),
                PitchRow(pitch: 42, label: "Hat"),
                PitchRow(pitch: 39, label: "Clap")
            ]
        case .bass, .guitar, .synth, .piano, .strings, .brass, .woodwinds, .organ, .mallets:
            let range = StudioGenerator.instrumentRange(
                for: instrument,
                style: style,
                octaveShift: octaveShift
            )
            return noteRows(range: range)
        case .audio:
            return []
        }
    }

    private static func noteRows(range: ClosedRange<Int>) -> [PitchRow] {
        let pitches = Array(range).reversed()
        return pitches.map { pitch in
            PitchRow(pitch: pitch, label: noteName(for: pitch))
        }
    }

    private static func noteName(for midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let name = names[midi % 12]
        let octave = (midi / 12) - 1
        return "\(name)\(octave)"
    }
}

struct PitchLabelColumn: View {
    let rows: [PitchRow]
    let rowHeight: CGFloat
    var columnWidth: CGFloat = 42

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(rows) { row in
                Text(row.label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(height: rowHeight)
                    .frame(width: columnWidth, alignment: .trailing)
            }
        }
    }
}

struct StudioNoteBlock: View {
    @Bindable var note: StudioNote
    let rowIndex: Int
    let stepLength: Double
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let maxBeats: Double
    let color: Color
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onCycleVelocity: () -> Void
    let onNotesChanged: () -> Void

    @State private var resizeStartDuration: Double = 0
    @State private var isResizing = false

    private var x: CGFloat {
        CGFloat(note.startBeat / stepLength) * cellWidth
    }

    private var width: CGFloat {
        CGFloat(note.duration / stepLength) * cellWidth
    }

    private var y: CGFloat {
        CGFloat(rowIndex) * cellHeight
    }

    private var intensity: Double {
        if note.velocity >= 108 { return 0.95 }
        if note.velocity <= 64 { return 0.38 }
        return 0.72
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(intensity))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? DesignSystem.Colors.backgroundSecondary : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .leading) {
                    if width > cellWidth * 1.4 {
                        Text("\(note.velocity)")
                            .font(DesignSystem.Typography.nano.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.backgroundSecondary.opacity(0.92))
                            .padding(.leading, 4)
                    }
                }
                .overlay(alignment: .center) {
                    if note.velocity <= 64 {
                        Circle()
                            .fill(DesignSystem.Colors.backgroundSecondary)
                            .frame(width: 4, height: 4)
                    }
                }

            Rectangle()
                .fill(DesignSystem.Colors.textPrimary.opacity(0.45))
                .frame(width: 5)
                .padding(.trailing, 3)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isResizing {
                                resizeStartDuration = note.duration
                                isResizing = true
                            }

                            let deltaBeats = Double(value.translation.width / cellWidth) * stepLength
                            let proposed = resizeStartDuration + deltaBeats
                            let clamped = clampDuration(proposed)
                            note.duration = clamped
                        }
                        .onEnded { _ in
                            isResizing = false
                            onNotesChanged()
                        }
                )
        }
        .frame(width: max(width, cellWidth * 0.9), height: cellHeight - 4)
        .offset(x: x, y: y + 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onDelete)
        .onLongPressGesture(minimumDuration: 0.25, perform: onCycleVelocity)
        .contextMenu {
            Button {
                onCycleVelocity()
            } label: {
                Label("Cycle Velocity", systemImage: "waveform.path.ecg")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Note", systemImage: "trash.fill")
            }
        }
        .onChange(of: note.duration) { _, _ in
            onNotesChanged()
        }
        .onChange(of: note.velocity) { _, _ in
            onNotesChanged()
        }
    }

    private func clampDuration(_ duration: Double) -> Double {
        let quantized = (duration / stepLength).rounded() * stepLength
        let maxDuration = max(stepLength, maxBeats - note.startBeat)
        return min(max(stepLength, quantized), maxDuration)
    }
}

struct GridBackground: View {
    let rows: Int
    let columns: Int
    let beatsPerBar: Int
    let stepsPerBeat: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let barInfos: [StudioBarSectionInfo]

    var body: some View {
        let stepsPerBar = max(1, beatsPerBar * stepsPerBeat)
        let totalBars = max(1, columns / stepsPerBar)
        let infoByBar = Dictionary(uniqueKeysWithValues: barInfos.map { ($0.barIndex, $0) })

        Canvas { context, size in
            // Section tint blocks across bars.
            for bar in 0..<totalBars {
                let x = CGFloat(bar * stepsPerBar) * cellWidth
                let width = CGFloat(stepsPerBar) * cellWidth
                let info = infoByBar[bar]
                let fillColor = (info?.sectionColor ?? SectionColor.purple.color).opacity(bar.isMultiple(of: 2) ? 0.08 : 0.04)
                context.fill(
                    Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                    with: .color(fillColor)
                )
            }

            var gridPath = Path()
            for column in 0...columns {
                let x = CGFloat(column) * cellWidth
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 0...rows {
                let y = CGFloat(row) * cellHeight
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(gridPath, with: .color(DesignSystem.Colors.border.opacity(0.6)), lineWidth: 0.5)

            var barPath = Path()
            for bar in 0...max(0, columns / stepsPerBar) {
                let x = CGFloat(bar * stepsPerBar) * cellWidth
                barPath.move(to: CGPoint(x: x, y: 0))
                barPath.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(barPath, with: .color(DesignSystem.Colors.borderActive), lineWidth: 1.25)
        }
        .frame(
            width: CGFloat(columns) * cellWidth,
            height: CGFloat(rows) * cellHeight
        )
    }
}

struct StudioNoteBarRuler: View {
    let barInfos: [StudioBarSectionInfo]
    let stepsPerBar: Int
    let cellWidth: CGFloat
    let height: CGFloat

    var body: some View {
        let barWidth = CGFloat(max(1, stepsPerBar)) * cellWidth

        HStack(spacing: 0) {
            ForEach(barInfos) { info in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bar \(info.barIndex + 1)")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text(info.chordLabel ?? info.sectionLabel)
                        .font(DesignSystem.Typography.nano)
                        .foregroundStyle(info.sectionColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(width: barWidth, height: height, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(info.sectionColor.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(info.sectionColor.opacity(0.35), lineWidth: 1)
                        )
                )
            }
        }
    }
}

struct NoteVelocityLegend: View {
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            legendItem(title: "Ghost", opacity: 0.38)
            legendItem(title: "Normal", opacity: 0.72)
            legendItem(title: "Accent", opacity: 0.95)
            Spacer()
            Text("Long press note to cycle")
        }
        .font(DesignSystem.Typography.caption2)
        .foregroundStyle(DesignSystem.Colors.textSecondary)
    }

    private func legendItem(title: String, opacity: Double) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(opacity))
                .frame(width: 16, height: 12)
            Text(title)
        }
    }
}

struct NoteInspector: View {
    @Bindable var note: StudioNote
    let maxDuration: Double
    let stepLength: Double
    let onDelete: () -> Void
    let onNoteUpdated: () -> Void

    private var durationText: String {
        "\(String(format: "%.2g", note.duration)) beats"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Note Settings")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.error)
                        )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Length")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                    Text(durationText)
                        .font(DesignSystem.Typography.caption2.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Stepper("", value: $note.duration, in: stepLength...maxDuration, step: stepLength)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Velocity")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                    Text("\(note.velocity)")
                        .font(DesignSystem.Typography.caption2.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                Slider(
                    value: Binding(
                        get: { Double(note.velocity) },
                        set: { note.velocity = Int($0) }
                    ),
                    in: 20...127,
                    step: 1
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
        .onChange(of: note.duration) { _, _ in
            onNoteUpdated()
        }
        .onChange(of: note.velocity) { _, _ in
            onNoteUpdated()
        }
    }
}

struct StudioStylePickerView: View {
    let selectedStyle: StudioStyle?
    let onConfirm: (StudioStyle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentSelection: StudioStyle?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose a Style")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(StudioStyle.allCases) { style in
                        Button {
                            currentSelection = style
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: style.icon)
                                        .font(DesignSystem.Typography.title3)
                                        .foregroundStyle(style.accentColor)
                                    Spacer()
                                    if currentSelection == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(DesignSystem.Typography.title3)
                                            .foregroundStyle(style.accentColor)
                                    }
                                }

                                Text(style.title)
                                    .font(DesignSystem.Typography.headline)
                                Text(style.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(style.accentColor.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(style.accentColor.opacity(0.7), lineWidth: currentSelection == style ? 2 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                AppButton(
                    title: "Continue",
                    kind: .primary((currentSelection ?? selectedStyle)?.accentColor ?? DesignSystem.Colors.primary)
                ) {
                    if let style = currentSelection {
                        onConfirm(style)
                        dismiss()
                    }
                }
                .disabled(currentSelection == nil)
            }
            .padding(24)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Studio Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
            }
        }
        .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .presentationBackground(DesignSystem.Colors.backgroundSecondary)
        .onAppear {
            currentSelection = selectedStyle
        }
    }
}

struct StudioInstrumentPickerView: View {
    let availableInstruments: [StudioInstrument]
    let existingInstruments: Set<StudioInstrument>
    let onPick: (StudioInstrument) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add Track")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if availableInstruments.isEmpty {
                    Text("No instruments available.")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(availableInstruments) { instrument in
                            let isAdded = existingInstruments.contains(instrument)
                            Button {
                                guard !isAdded else { return }
                                onPick(instrument)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: instrument.icon)
                                            .font(DesignSystem.Typography.title3)
                                            .foregroundStyle(instrument.color)
                                        Spacer()
                                        if isAdded {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(DesignSystem.Typography.title3)
                                        }
                                    }

                                    Text(instrument.title)
                                        .font(DesignSystem.Typography.headline)

                                    Text(isAdded ? "Already added" : "Tap to add")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(instrument.color.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(instrument.color.opacity(isAdded ? 0.5 : 0.8), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isAdded)
                            .opacity(isAdded ? 0.6 : 1.0)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Instruments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
            }
}

struct StudioRecordingPicker: View {
    let recordings: [Recording]
    let onPick: (Recording) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if recordings.isEmpty {
                    Text("No recordings available.")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                } else {
                    ForEach(recordings) { recording in
                        Button {
                            onPick(recording)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: recording.recordingType.icon)
                                    .foregroundStyle(recording.recordingType.color)
                                VStack(alignment: .leading) {
                                    Text(recording.name)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Text(recording.recordingType.rawValue)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                                Spacer()
                                Text("\(recording.duration, specifier: "%.1f")s")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                        .listRowBackground(DesignSystem.Colors.surfaceSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
            }
}

struct AddTrackMenuView: View {
    let hasRecordings: Bool
    let onAddInstrument: () -> Void
    let onAddRecording: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose Track Type")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.top, 24)
                
                VStack(spacing: 16) {
                    Button {
                        onAddInstrument()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "music.note")
                                .font(DesignSystem.Typography.title2)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(SectionColor.purple.color.opacity(0.3))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Instrument")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                
                                Text("Piano, Guitar, Drums, Bass, Synth")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(SectionColor.purple.color.opacity(0.4), lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onAddRecording()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "waveform")
                                .font(DesignSystem.Typography.title2)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(DesignSystem.Colors.accent.opacity(0.3))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Recording")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                
                                Text(hasRecordings ? "Import audio from your recordings" : "No recordings available")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DesignSystem.Colors.surfaceSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(DesignSystem.Colors.accent.opacity(hasRecordings ? 0.4 : 0.2), lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasRecordings)
                    .opacity(hasRecordings ? 1.0 : 0.5)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(
                DesignSystem.Colors.background
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
                .presentationDetents([.height(350)])
    }
}

struct RegenerateOptionsView: View {
    let trackName: String
    let instrument: StudioInstrument
    let variant: InstrumentVariant?
    let style: StudioStyle?
    @Binding var intensity: Double
    @Binding var complexity: Double
    @Binding var naturalness: Double
    @Binding var arpeggioEnabled: Bool
    @Binding var arpeggioRate: String
    @Binding var arpeggioPattern: String
    let onRegenerate: () -> Void
    let onCancel: () -> Void
    
    private let arpeggioRates = ["1/4", "1/8", "1/16"]
    private let arpeggioPatterns = ["Up", "Down", "UpDown"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Regenerating: \(trackName)")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    
                    // Intensity Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundStyle(DesignSystem.Colors.primary)
                            Text("Intensity")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                            Text("\(Int(intensity * 100))%")
                                .font(DesignSystem.Typography.caption.monospacedDigit())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Slider(value: $intensity, in: 0...1)
                            .tint(DesignSystem.Colors.primary)
                        
                        HStack {
                            Text("Minimal")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Maximum")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Text("Controls hit frequency and velocity")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    
                    // Complexity Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundStyle(DesignSystem.Colors.info)
                            Text("Complexity")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                            Text("\(Int(complexity * 100))%")
                                .font(DesignSystem.Typography.caption.monospacedDigit())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Slider(value: $complexity, in: 0...1)
                            .tint(DesignSystem.Colors.accent)
                        
                        HStack {
                            Text("Simple")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Complex")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Text("Controls note variations and rhythmic patterns")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    // Naturalness Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tuningfork")
                                .foregroundStyle(DesignSystem.Colors.warning)
                            Text("Naturalness")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Spacer()
                            Text("\(Int(naturalness * 100))%")
                                .font(DesignSystem.Typography.caption.monospacedDigit())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Slider(value: $naturalness, in: 0...1)
                            .tint(DesignSystem.Colors.warning)
                        
                        HStack {
                            Text("Tight")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("Loose")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Text("Adds subtle timing and velocity variation")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    // Arpeggio Options
                    if supportsArpeggio {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $arpeggioEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.right.and.arrow.down.left")
                                        .foregroundStyle(DesignSystem.Colors.info)
                                    Text("Arpeggiate")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                }
                            }
                            .tint(DesignSystem.Colors.info)
                            
                            if arpeggioEnabled {
                                HStack(spacing: 12) {
                                    Menu {
                                        ForEach(arpeggioRates, id: \.self) { rate in
                                            Button(rate) {
                                                arpeggioRate = rate
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text("Rate \(arpeggioRate)")
                                                .font(DesignSystem.Typography.caption)
                                            Image(systemName: "chevron.down")
                                                .font(DesignSystem.Typography.caption2)
                                        }
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(DesignSystem.Colors.surfaceSecondary)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                                )
                                        )
                                    }
                                    
                                    Menu {
                                        ForEach(arpeggioPatterns, id: \.self) { pattern in
                                            Button(pattern) {
                                                arpeggioPattern = pattern
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(arpeggioPattern)
                                                .font(DesignSystem.Typography.caption)
                                            Image(systemName: "chevron.down")
                                                .font(DesignSystem.Typography.caption2)
                                        }
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(DesignSystem.Colors.surfaceSecondary)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                                
                                Text("Spreads chord notes in time")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                )
                
                Spacer(minLength: 12)
                
                // Buttons
                HStack(spacing: 12) {
                    AppButton(title: "Cancel", kind: .secondary) {
                        onCancel()
                    }
                    
                    AppButton(title: "Regenerate", icon: "sparkles", kind: .primary(DesignSystem.Colors.primary)) {
                        onRegenerate()
                    }
                }
            }
            .padding(24)
            .background(
                DesignSystem.Colors.background
            )
            .navigationTitle("Regenerate Options")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(680)])
    }

    private var supportsArpeggio: Bool {
        StudioGenerator.supportsArpeggio(
            instrument: instrument,
            variant: variant,
            style: style
        )
    }
}
