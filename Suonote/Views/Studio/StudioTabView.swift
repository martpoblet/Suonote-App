import SwiftUI
import SwiftData
import Foundation

// MARK: - Studio
/// The production room: song facts and style up top, the arrangement as a
/// section timeline with a live playhead, and the band as a quiet list of
/// tracks. Playback is driven by the project-wide transport (the tab bar
/// accessory, `MiniTransportView`); full-screen track editors carry the
/// matching floating transport. Components live in `Views/Studio/`.
struct StudioTabView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var showingStylePicker = false
    @State private var showingRegenerateDialog = false
    @State private var showingInstrumentPicker = false
    @State private var pendingAddTrackAfterStyle = false
    @State private var selectedTrackId: UUID?
    @State private var editingTrack: StudioTrack?
    @State private var lastProjectSignature = ""
    @State private var lastChordIds: Set<UUID> = []
    @State private var lastTotalBars = 0
    @State private var showMixer = false
    @State private var shareItem: StudioShareItem?
    @State private var exportFailed = false
    @State private var mixProgress: Double?
    @EnvironmentObject private var playback: StudioPlaybackEngine
    @State private var showingNoSectionsAlert = false

    private var sortedTracks: [StudioTrack] {
        project.studioTracks.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var hasGeneratedTracks: Bool {
        project.studioTracks.contains { !$0.instrument.isAudio }
    }

    /// How many generated tracks exist per instrument, used to gate adding more
    /// (most instruments allow one; piano allows up to three).
    private var instrumentCounts: [StudioInstrument: Int] {
        project.studioTracks
            .filter { !$0.instrument.isAudio }
            .reduce(into: [:]) { counts, track in counts[track.instrument, default: 0] += 1 }
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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                header

                if !hasSections {
                    noSectionsState
                } else if project.studioStyle == nil && sortedTracks.isEmpty {
                    chooseStyleState
                } else {
                    factsCard
                    arrangementSection
                    if sortedTracks.isEmpty {
                        firstTrackState
                    } else {
                        tracksSection
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, 112)
            .animation(DesignSystem.Animations.smoothSpring, value: sortedTracks.map(\.id))
            .animation(DesignSystem.Animations.smoothSpring, value: showMixer)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) {
            if let mixProgress {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView(value: mixProgress)
                        .tint(DesignSystem.Colors.primary)
                        .frame(width: 90)
                    Text("Bouncing mix · \(Int(mixProgress * 100))%")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .monospacedDigit()
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .glassEffect(.regular, in: .capsule)
                .padding(.top, DesignSystem.Spacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(DesignSystem.Animations.smoothSpring, value: mixProgress == nil)
        .alert("Couldn't export", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert("Add sections first", isPresented: $showingNoSectionsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Create at least one section in Compose to add instruments and play the Studio.")
        }
        .onAppear {
            if selectedTrackId == nil {
                selectedTrackId = sortedTracks.first?.id
            }
            normalizeLegacyPianoOctavesIfNeeded()
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
        .sheet(isPresented: $showingStylePicker) {
            StudioStylePickerView(
                selectedStyle: project.studioStyle,
                willRewriteTracks: hasGeneratedTracks,
                onConfirm: applyStyle
            )
            .presentationDetents([.large])
            .studioModalStyle()
        }
        .sheet(isPresented: $showingInstrumentPicker) {
            StudioInstrumentPickerView(
                availableInstruments: availableInstruments,
                instrumentCounts: instrumentCounts,
                style: project.studioStyle,
                beatsPerBar: project.timeTop,
                timeBottom: project.timeBottom,
                recordings: availableRecordings,
                onPick: { instrument, choice in
                    addInstrumentTrack(instrument, choice: choice)
                },
                onPickRecording: { recording in
                    addAudioTrack(from: recording)
                }
            )
            .presentationDetents([.large])
            .studioModalStyle()
        }
        .sheet(item: $shareItem) { item in
            StudioShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Rewrite every part?",
            isPresented: $showingRegenerateDialog,
            titleVisibility: .visible
        ) {
            Button("Rewrite all parts", role: .destructive) {
                regenerateNotes()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every generated track gets fresh notes in the \(project.studioStyle?.title ?? String(localized: "current")) style. Hand edits are replaced.")
        }
        #if DEBUG
        .task {
            // App Store screenshots: `-ScreenshotOpen piano` opens that track's editor.
            guard let name = UserDefaults.standard.string(forKey: "ScreenshotOpen"),
                  let instrument = StudioInstrument(rawValue: name) else { return }
            try? await Task.sleep(for: .seconds(1.2))
            editingTrack = project.studioTracks.first { $0.instrument == instrument }
        }
        #endif
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
                onNotesChanged: {
                    project.updatedAt = Date()
                    // Heard immediately, even mid-playback.
                    playback.notesChanged(for: track, project: project)
                },
                onDelete: deleteTrack
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        ScreenHeader(
            eyebrow: String(localized: "Studio"),
            title: project.studioStyle.map { String(localized: "\($0.title) session") } ?? String(localized: "Studio"),
            subtitle: project.studioStyle?.description ?? String(localized: "Turn your chords into a band.")
        ) {
            if hasSections {
                studioMenu
            }
        }
    }

    private var studioMenu: some View {
        Menu {
            Button {
                showingStylePicker = true
            } label: {
                Label(project.studioStyle == nil ? "Choose style" : "Change style", systemImage: "sparkles")
            }
            if hasGeneratedTracks, project.studioStyle != nil {
                Button {
                    showingRegenerateDialog = true
                } label: {
                    Label("Rewrite all parts", systemImage: "wand.and.stars")
                }
            }
            if hasGeneratedTracks {
                Divider()
                Button {
                    exportMix()
                } label: {
                    Label("Export audio mix", systemImage: "hifispeaker.2")
                }
                .disabled(mixProgress != nil)
                Button {
                    exportMIDI()
                } label: {
                    Label("Export MIDI", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Studio options")
    }

    // MARK: - Facts

    private var factsCard: some View {
        HStack(spacing: 0) {
            StatTile(label: String(localized: "Key"), value: StudioMusic.keyLabel(root: project.keyRoot, mode: project.keyMode))
            factDivider
            StatTile(label: String(localized: "Tempo"), value: "\(project.bpm)")
            factDivider
            StatTile(label: String(localized: "Meter"), value: "\(project.timeTop)/\(project.timeBottom)")
            factDivider
            StatTile(label: String(localized: "Bars"), value: "\(totalBars)")
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private var factDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.border)
            .frame(width: 1, height: 36)
            .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    // MARK: - Arrangement

    private var arrangementSection: some View {
        let spans = project.studioSectionSpans
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(
                title: String(localized: "Arrangement"),
                detail: String(localized: "\(spans.count) sections"),
                actionTitle: playback.isLooping ? String(localized: "Stop loop") : nil,
                action: { StudioTransportActions.toggleLoop(playback: playback) }
            )
            StudioTimelineRuler(project: project)
                .padding(DesignSystem.Spacing.sm)
                .cardStyle()
            Text("Tap to jump · hold a section to loop it")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    // MARK: - Tracks

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(
                title: String(localized: "Tracks"),
                detail: "\(sortedTracks.count)",
                actionTitle: showMixer ? String(localized: "Hide mixer") : String(localized: "Mixer"),
                action: {
                    withAnimation(DesignSystem.Animations.smoothSpring) { showMixer.toggle() }
                    haptic(.selection)
                }
            )
            StudioTrackList(
                tracks: sortedTracks,
                style: project.studioStyle,
                showMixer: showMixer,
                canDuplicate: canDuplicate,
                onTrackStructureChange: {
                    project.updatedAt = Date()
                    playback.needsSequenceRebuild = true
                },
                onMixChange: applyMixState,
                onDelete: deleteTrack,
                onDuplicate: duplicateTrack,
                onOpenEditor: { track in
                    selectedTrackId = track.id
                    editingTrack = track
                    haptic(.light)
                },
                onReorder: reorderTracks
            )
            addTrackRow
            Text("Tap a track to write its part · hold to reorder or for more")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    /// Inline "add" row at the end of the band — never floats over a track.
    private var addTrackRow: some View {
        Button(action: promptAddTrack) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryLight)
                        .frame(width: 40, height: 40)
                    Image(systemName: DesignSystem.Icons.add)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add an instrument")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Keys, guitar, strings, a recorded take…")
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.borderActive, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add track")
    }

    // MARK: - Empty states

    private var noSectionsState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            BrandWavesMark(size: 40, animated: true)
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Nothing to play yet")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Write a few sections with chords in Compose — the Studio turns them into a band.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxxl)
    }

    private var chooseStyleState: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose the room")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("A style sets the groove, voicings and sounds. You can change it any time.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            StudioStyleGrid(selected: project.studioStyle) { style in
                withAnimation(DesignSystem.Animations.smoothSpring) {
                    applyStyle(style)
                }
                haptic(.success)
            }
        }
    }

    private var firstTrackState: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(title: String(localized: "Tracks"))
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: -8) {
                    ForEach([StudioInstrument.drums, .bass, .piano]) { instrument in
                        StudioInstrumentBadge(instrument: instrument, size: 44)
                            .background(Circle().fill(DesignSystem.Colors.surface))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start with a band")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Drums, bass and keys written from your chords — or pick instruments one by one.")
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        addStarterBand()
                    } label: {
                        Label("Add starter band", systemImage: "sparkles")
                    }
                    .buttonStyle(InkButtonStyle())

                    Button(action: promptAddTrack) {
                        Text("Choose…")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    // MARK: - Actions

    private func applyStyle(_ style: StudioStyle) {
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
            playback.needsSequenceRebuild = true
            try? modelContext.save()
        } else {
            try? modelContext.save()
        }
    }

    private func regenerateNotes() {
        guard let style = project.studioStyle else { return }
        StudioGenerator.regenerateNotes(for: project, style: style, modelContext: modelContext)
        updateStudioSyncState(signature: projectStudioSignature, timeline: StudioGenerator.timeline(for: project))
        project.updatedAt = Date()
        try? modelContext.save()
        playback.needsSequenceRebuild = true
        playback.stop(resetPosition: true)
        haptic(.success)
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
        showingInstrumentPicker = true
    }

    /// Creates and configures (but does not write notes for) a new instrument track.
    @discardableResult
    private func makeInstrumentTrack(_ instrument: StudioInstrument, choice: TrackStyleChoice) -> StudioTrack? {
        guard let style = project.studioStyle else { return nil }
        let existingCount = instrumentCounts[instrument, default: 0]
        guard existingCount < instrument.maxStudioTracks else { return nil }

        let orderIndex = (project.studioTracks.map(\.orderIndex).max() ?? -1) + 1
        // When more than one of an instrument is allowed (e.g. piano), number the
        // extra tracks so they're distinguishable in the list.
        let trackName = existingCount == 0 ? instrument.title : "\(instrument.title) \(existingCount + 1)"
        let track = StudioTrack(
            name: trackName,
            instrument: instrument,
            orderIndex: orderIndex,
            style: style
        )
        if let variant = choice.variant {
            track.variant = variant
        }
        track.project = project
        project.studioTracks.append(track)
        modelContext.insert(track)

        // Apply the playing style chosen when adding the instrument.
        track.compingPattern = choice.comping
        track.bassPattern = choice.bass
        if let density = choice.leadComplexity {
            track.regenerateComplexity = density
        }

        // Set the musically correct default octave for this instrument before generating.
        // The generator owns per-instrument defaults so playing-style regeneration stays aligned.
        track.octaveShift = StudioGenerator.initialOctaveShift(for: instrument, variant: track.variant)
        // Tracks added individually should get the same default humanization
        // as style-generated ones (otherwise they play perfectly quantized).
        track.regenerateNaturalness = StudioGenerator.defaultNaturalness(for: instrument)

        track.drumPreset = instrument == .drums
            ? (choice.drumPreset ?? DrumPreset.defaultPreset(for: style, beatsPerBar: project.timeTop, timeBottom: project.timeBottom))
            : nil
        return track
    }

    private func addInstrumentTrack(_ instrument: StudioInstrument, choice: TrackStyleChoice = TrackStyleChoice()) {
        guard hasSections, let style = project.studioStyle else { return }
        guard let track = makeInstrumentTrack(instrument, choice: choice) else { return }

        StudioTrackActions.regenerate(track, project: project, style: style, modelContext: modelContext)

        selectedTrackId = track.id
        updateStudioSyncState(signature: projectStudioSignature, timeline: StudioGenerator.timeline(for: project))
        project.updatedAt = Date()
        try? modelContext.save()
        playback.needsSequenceRebuild = true
    }

    /// One tap: drums, bass and piano, written together so they share an
    /// arrangement context (bass owns the low end, keys sit above it).
    private func addStarterBand() {
        guard hasSections, let style = project.studioStyle else { return }
        for instrument in [StudioInstrument.drums, .bass, .piano] {
            makeInstrumentTrack(
                instrument,
                choice: .recommended(for: instrument, style: style, beatsPerBar: project.timeTop, timeBottom: project.timeBottom)
            )
        }
        StudioGenerator.regenerateNotes(for: project, style: style, modelContext: modelContext)
        selectedTrackId = sortedTracks.first?.id
        updateStudioSyncState(signature: projectStudioSignature, timeline: StudioGenerator.timeline(for: project))
        project.updatedAt = Date()
        try? modelContext.save()
        playback.needsSequenceRebuild = true
        haptic(.success)
    }

    private func canDuplicate(_ track: StudioTrack) -> Bool {
        guard !track.instrument.isAudio else { return false }
        return instrumentCounts[track.instrument, default: 0] < track.instrument.maxStudioTracks
    }

    /// Copies a track (sound, part, mix and effects) right below the original.
    private func duplicateTrack(_ source: StudioTrack) {
        guard canDuplicate(source) else { return }
        let count = instrumentCounts[source.instrument, default: 0]
        let insertIndex = source.orderIndex + 1
        for track in project.studioTracks where track.orderIndex >= insertIndex {
            track.orderIndex += 1
        }

        let copy = StudioTrack(
            name: "\(source.instrument.title) \(count + 1)",
            instrument: source.instrument,
            orderIndex: insertIndex
        )
        copy.variant = source.variant
        copy.octaveShift = source.octaveShift
        copy.drumPreset = source.drumPreset
        copy.compingPattern = source.compingPattern
        copy.bassPattern = source.bassPattern
        copy.regenerateIntensity = source.regenerateIntensity
        copy.regenerateComplexity = source.regenerateComplexity
        copy.regenerateNaturalness = source.regenerateNaturalness
        copy.regenerateArpeggioEnabled = source.regenerateArpeggioEnabled
        copy.regenerateArpeggioRate = source.regenerateArpeggioRate
        copy.regenerateArpeggioPattern = source.regenerateArpeggioPattern
        copy.volume = source.volume
        copy.pan = source.pan
        copy.reverbEnabled = source.reverbEnabled
        copy.reverbMix = source.reverbMix
        copy.reverbPreset = source.reverbPreset
        copy.delayEnabled = source.delayEnabled
        copy.delayTime = source.delayTime
        copy.delayMix = source.delayMix
        copy.delaySyncMode = source.delaySyncMode
        copy.eqEnabled = source.eqEnabled
        copy.eqLowGain = source.eqLowGain
        copy.eqMidGain = source.eqMidGain
        copy.eqHighGain = source.eqHighGain
        copy.project = project
        project.studioTracks.append(copy)
        modelContext.insert(copy)

        for note in source.notes {
            let newNote = StudioNote(startBeat: note.startBeat, duration: note.duration, pitch: note.pitch, velocity: note.velocity)
            newNote.track = copy
            copy.notes.append(newNote)
            modelContext.insert(newNote)
        }

        selectedTrackId = copy.id
        project.updatedAt = Date()
        try? modelContext.save()
        playback.needsSequenceRebuild = true
        haptic(.success)
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
        playback.needsSequenceRebuild = true
        haptic(.light)
    }

    private func reorderTracks(_ source: IndexSet, _ destination: Int) {
        var ordered = sortedTracks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, track) in ordered.enumerated() {
            track.orderIndex = index
        }
        project.updatedAt = Date()
        try? modelContext.save()
        playback.needsSequenceRebuild = true
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
        playback.needsSequenceRebuild = true
    }

    /// Bounces the arrangement to an M4A through the same mix as playback.
    private func exportMix() {
        mixProgress = 0
        Task { @MainActor in
            defer { mixProgress = nil }
            do {
                let url = try await StudioOfflineRenderer.render(project: project, format: .m4a) { value in
                    mixProgress = value
                }
                HapticFeedback.success.trigger()
                shareItem = StudioShareItem(url: url)
            } catch {
                exportFailed = true
            }
        }
    }

    private func exportMIDI() {
        if let url = playback.exportMIDI(project: project) {
            shareItem = StudioShareItem(url: url)
        } else {
            exportFailed = true
        }
    }

    private func handleProjectChange(newSignature: String) {
        guard newSignature != lastProjectSignature else { return }
        lastProjectSignature = newSignature

        syncStudioIfNeeded()

        if playback.isPlaying {
            playback.stop(resetPosition: false)
        }
        playback.needsSequenceRebuild = true
        playback.prepare(project: project)
        playback.updateProject(project)
    }

    private func applyMixState() {
        playback.applyMixState(project: project)
    }

    private func syncStudioIfNeeded() {
        if StudioSync.syncIfNeeded(project: project, modelContext: modelContext) {
            playback.needsSequenceRebuild = true
        }
    }

    private func updateStudioSyncState(signature: String, timeline: (chords: [StudioGenerator.ChordSpan], totalBars: Int)) {
        StudioSync.updateSyncState(project: project, signature: signature, timeline: timeline)
    }

    private var projectStudioSignature: String {
        StudioSync.signature(for: project)
    }

    private func normalizeLegacyPianoOctavesIfNeeded() {
        guard let style = project.studioStyle else { return }

        // One-time fix for tracks created with the old SoundFont's octave
        // compensation (basses at C0, pads in octave 1…).
        let migrated = StudioGenerator.migrateOctaveSemanticsIfNeeded(project: project)

        let pianoTracks = project.studioTracks.filter {
            $0.instrument == .piano && $0.octaveShift < 0
        }
        guard migrated || !pianoTracks.isEmpty else { return }

        for track in pianoTracks {
            track.octaveShift = StudioGenerator.initialOctaveShift(for: .piano, variant: track.variant)
        }

        StudioGenerator.regenerateNotes(
            for: project,
            style: style,
            modelContext: modelContext
        )
        project.updatedAt = Date()
        try? modelContext.save()
        playback.needsSequenceRebuild = true
    }













}
