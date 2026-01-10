import SwiftUI
import SwiftData
import Foundation

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
    @State private var needsRebuild = true
    @State private var lastProjectSignature = ""
    @StateObject private var playback = StudioPlaybackEngine()

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

    private var availableInstruments: [StudioInstrument] {
        StudioInstrument.allCases.filter { !$0.isAudio }
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
                        accentColor: project.studioStyle?.accentColor ?? SectionColor.purple.color,
                        onPickStyle: { showingStylePicker = true },
                        onAddTrack: promptAddTrack
                    )
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        StudioTrackList(
                            tracks: sortedTracks,
                            selectedTrackId: $selectedTrackId,
                            onTrackChange: { needsRebuild = true },
                            onDelete: deleteTrack,
                            playback: playback
                        )

                        if let selectedTrack {
                            if selectedTrack.instrument == .drums {
                                StudioDrumEditor(
                                    track: selectedTrack,
                                    beatsPerBar: project.timeTop,
                                    timeBottom: project.timeBottom,
                                    totalBars: totalBars,
                                    style: project.studioStyle,
                                    onNotesChanged: { needsRebuild = true }
                                )
                            } else {
                                StudioNoteEditor(
                                    track: selectedTrack,
                                    beatsPerBar: project.timeTop,
                                    totalBars: totalBars,
                                    style: project.studioStyle,
                                    onNotesChanged: { needsRebuild = true }
                                )
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .padding(.bottom, 120)
                }
                
                // Fixed timeline at bottom
                VStack(spacing: 0) {
                    Divider().overlay(DesignSystem.Colors.border)
                    
                    StudioTimelineView(
                        segments: timelineSegments,
                        beatsPerBar: project.timeTop,
                        totalBars: totalBars,
                        currentBeat: playback.currentBeat,
                        isPlaying: playback.isPlaying,
                        accentColor: project.studioStyle?.accentColor ?? SectionColor.purple.color,
                        onPlay: handlePlay,
                        onPause: playback.pause,
                        onStop: handleStop,
                        onSeek: { beat in
                            playback.seek(to: beat)
                        }
                    )
                    .padding(DesignSystem.Spacing.md)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.95),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            if project.studioStyle == nil {
                showingStylePicker = true
            }
            if selectedTrackId == nil {
                selectedTrackId = sortedTracks.first?.id
            }
            playback.prepare(project: project)
            lastProjectSignature = projectStudioSignature
        }
        .onChange(of: projectStudioSignature) { _, newSignature in
            handleProjectChange(newSignature: newSignature)
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
                recordings: project.recordings,
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
                hasRecordings: !project.recordings.isEmpty,
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
    }

    private var studioHeader: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Style Picker Button
            Button {
                showingStylePicker = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: project.studioStyle?.icon ?? "sparkles")
                    Text(project.studioStyle?.title ?? "Pick Style")
                        .font(DesignSystem.Typography.callout)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(
                    Capsule()
                        .fill((project.studioStyle?.accentColor ?? DesignSystem.Colors.primary).opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(project.studioStyle?.accentColor ?? DesignSystem.Colors.primary, lineWidth: 1)
                        )
                )
            }
            .animatedPress()

            Spacer()

            // Add Track Button
            Button {
                promptAddTrack()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: DesignSystem.Icons.add)
                    Text("Add Track")
                }
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(
                    Capsule()
                        .fill(project.studioStyle?.accentColor ?? DesignSystem.Colors.primary)
                )
            }
            .animatedPress()
        }
    }

    private func regenerateNotes() {
        guard let style = project.studioStyle else { return }
        StudioGenerator.regenerateNotes(for: project, style: style, modelContext: modelContext)
        project.updatedAt = Date()
        try? modelContext.save()
        needsRebuild = true
        playback.stop(resetPosition: true)
    }

    private func promptAddTrack() {
        guard project.studioStyle != nil else {
            pendingAddTrackAfterStyle = true
            showingStylePicker = true
            return
        }
        showingAddTrackMenu = true
    }

    private func addInstrumentTrack(_ instrument: StudioInstrument) {
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
            octaveShift: track.octaveShift
        )
        for note in notes {
            note.track = track
            track.notes.append(note)
            modelContext.insert(note)
        }

        selectedTrackId = track.id
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
        if needsRebuild {
            playback.rebuildSequence(project: project)
            needsRebuild = false
        }
        playback.play()
    }

    private func handleStop() {
        playback.stop(resetPosition: true)
    }

    private func handleProjectChange(newSignature: String) {
        guard newSignature != lastProjectSignature else { return }
        lastProjectSignature = newSignature

        guard let style = project.studioStyle else {
            needsRebuild = true
            playback.prepare(project: project)
            return
        }

        if !project.studioTracks.isEmpty {
            StudioGenerator.regenerateNotes(for: project, style: style, modelContext: modelContext)
            try? modelContext.save()
        }

        if playback.isPlaying {
            playback.stop(resetPosition: false)
        }
        needsRebuild = true
        playback.prepare(project: project)
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
                        return "\(chord.barIndex):\(beat):\(duration):\(chord.root):\(chord.quality.rawValue):\(ext):\(chord.slashRoot ?? "")"
                    }
                    .joined(separator: ";")
                return "\(section.id.uuidString):\(section.bars):\(chords)"
            }
            .joined(separator: "|")
        return [header, arrangement, sections].joined(separator: "#")
    }
}

struct StudioEmptyState: View {
    let accentColor: Color
    let onPickStyle: () -> Void
    let onAddTrack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text("Build Your Studio")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Pick a style and add instruments from your chord progression.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    onPickStyle()
                } label: {
                    Text("Pick Style")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(accentColor.opacity(0.3))
                        )
                }

                Button {
                    onAddTrack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Track")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(accentColor)
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct StudioTimelineSegment: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
    let startBar: Int
    let bars: Int
}

struct StudioTimelineView: View {
    let segments: [StudioTimelineSegment]
    let beatsPerBar: Int
    let totalBars: Int
    let currentBeat: Double
    let isPlaying: Bool
    let accentColor: Color
    let onPlay: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    let onSeek: (Double) -> Void

    private var maxBeats: Double {
        Double(max(1, totalBars * beatsPerBar))
    }

    private var currentBarIndex: Int {
        Int(currentBeat / Double(beatsPerBar))
    }

    private var currentSection: StudioTimelineSegment? {
        segments.last { segment in
            let endBar = segment.startBar + segment.bars
            return currentBarIndex >= segment.startBar && currentBarIndex < endBar
        }
    }

    private var timeLabel: String {
        let bar = max(1, currentBarIndex + 1)
        let beat = max(1, Int(currentBeat.truncatingRemainder(dividingBy: Double(beatsPerBar))) + 1)
        return "Bar \(bar) · Beat \(beat)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentSection?.label ?? "Timeline")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        onPlay()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(accentColor))
                    }
                    .disabled(isPlaying)

                    Button {
                        onPause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .disabled(!isPlaying)

                    Button {
                        onStop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
            }

            GeometryReader { geo in
                let barWidth = geo.size.width / CGFloat(max(1, totalBars))
                let playheadX = CGFloat(currentBeat / Double(beatsPerBar)) * barWidth

                ZStack(alignment: .topLeading) {
                    ForEach(segments) { segment in
                        let width = CGFloat(segment.bars) * barWidth
                        let x = CGFloat(segment.startBar) * barWidth
                        RoundedRectangle(cornerRadius: 6)
                            .fill(segment.color.opacity(0.5))
                            .frame(width: width, height: 40)
                            .overlay(
                                Text(segment.label)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(width > 48 ? 0.95 : 0))
                                    .lineLimit(1)
                                    .padding(.horizontal, 6),
                                alignment: .center
                            )
                            .offset(x: x)
                    }

                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 2, height: 44)
                        .offset(x: max(0, min(playheadX, geo.size.width - 2)))

                    Circle()
                        .fill(accentColor)
                        .frame(width: 10, height: 10)
                        .offset(
                            x: max(0, min(playheadX - 4, geo.size.width - 10)),
                            y: -5
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clampedX = max(0, min(value.location.x, geo.size.width))
                            let beat = Double(clampedX / barWidth) * Double(beatsPerBar)
                            onSeek(min(beat, maxBeats))
                        }
                )
            }
            .frame(height: 44)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct StudioTrackList: View {
    let tracks: [StudioTrack]
    @Binding var selectedTrackId: UUID?
    let onTrackChange: () -> Void
    let onDelete: (StudioTrack) -> Void
    let playback: StudioPlaybackEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracks")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(tracks, id: \.id) { track in
                    SwipeActionRow(actions: [
                        SwipeActionItem(systemImage: "trash.fill", tint: .red, role: .destructive) {
                            onDelete(track)
                        }
                    ]) {
                        StudioTrackRow(
                            track: track,
                            isSelected: selectedTrackId == track.id,
                            onSelect: {
                                selectedTrackId = track.id
                            },
                            onTrackChange: onTrackChange,
                            onDelete: {
                                onDelete(track)
                            },
                            playback: playback
                        )
                    }
                }
            }
        }
    }
}

struct StudioTrackRow: View {
    @Bindable var track: StudioTrack
    let isSelected: Bool
    let onSelect: () -> Void
    let onTrackChange: () -> Void
    let onDelete: () -> Void
    let playback: StudioPlaybackEngine
    @State private var showingControls = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: track.instrument.icon)
                    .font(.title3)
                    .foregroundStyle(track.instrument.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    // Variant selector inline
                    if !track.instrument.variants.isEmpty {
                        Menu {
                            ForEach(track.instrument.variants, id: \.self) { variant in
                                Button {
                                    track.variant = variant
                                    onTrackChange()
                                } label: {
                                    HStack {
                                        Text(variant.rawValue)
                                        if track.variant == variant {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(track.variant?.rawValue ?? track.instrument.variants.first?.rawValue ?? track.instrument.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(track.instrument.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showingControls.toggle()
                    }
                } label: {
                    Image(systemName: showingControls ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)

                Button {
                    track.isMuted.toggle()
                    onTrackChange()
                } label: {
                    Text("M")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(track.isMuted ? .black : .white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(track.isMuted ? track.instrument.color : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    track.isSolo.toggle()
                    onTrackChange()
                } label: {
                    Text("S")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(track.isSolo ? .black : .white)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(track.isSolo ? track.instrument.color : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            
            if showingControls {
                VStack(spacing: 12) {
                    // Volume Control
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Volume")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(track.volume * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        
                        Slider(value: $track.volume, in: 0...1)
                            .tint(track.instrument.color)
                            .onChange(of: track.volume) { _, newValue in
                                playback.updateTrackMix(trackId: track.id, volume: newValue, pan: track.pan)
                                onTrackChange()
                            }
                    }
                    
                    // Pan Control
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "l.joystick.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Pan")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(panLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        
                        Slider(value: $track.pan, in: -1...1)
                            .tint(track.instrument.color)
                            .onChange(of: track.pan) { _, newValue in
                                playback.updateTrackMix(trackId: track.id, volume: track.volume, pan: newValue)
                                onTrackChange()
                            }
                    }
                    
                    // Regenerate button (only for generated tracks)
                    if !track.instrument.isAudio && !track.notes.isEmpty {
                        Button {
                            // TODO: Implement individual track regeneration with options
                            onTrackChange()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                Text("Regenerate Notes")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                            }
                            .foregroundStyle(track.instrument.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(track.instrument.color.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(track.instrument.color.opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? track.instrument.color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Track", systemImage: "trash.fill")
            }
        }
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
}

struct StudioAudioTrackView: View {
    @Bindable var track: StudioTrack
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Track")
                .font(.headline)
                .foregroundStyle(.white)

            if let recording = project.recordings.first(where: { $0.id == track.audioRecordingId }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Starts at beat \(String(format: "%.1f", track.audioStartBeat))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            } else {
                Text("Recording not found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Audio editing and playback will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
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
    let style: StudioStyle?
    let onNotesChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selectedNoteId: UUID?
    @State private var defaultDuration: Double = 1.0

    private let stepsPerBeat = 4
    private let cellWidth: CGFloat = 28
    private let cellHeight: CGFloat = 26
    private let durationOptions: [Double] = [0.25, 0.5, 1, 2, 4]
    private let octaveRange = -2...2

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

    private var gridHeight: CGFloat {
        let contentHeight = CGFloat(pitchRows.count) * cellHeight
        return min(contentHeight, 260)
    }

    private var selectedNote: StudioNote? {
        guard let selectedNoteId else { return nil }
        return track.notes.first { $0.id == selectedNoteId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Note Editor")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 10) {
                    octaveControl

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
                            Text("Length")
                                .font(.caption.weight(.semibold))
                            Text("\(defaultDuration, specifier: "%.2g")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(track.instrument.color.opacity(0.2))
                        )
                    }
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top, spacing: 8) {
                    PitchLabelColumn(rows: pitchRows, rowHeight: cellHeight)

                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            GridBackground(
                                rows: pitchRows.count,
                                columns: totalSteps,
                                beatsPerBar: beatsPerBar,
                                stepsPerBeat: stepsPerBeat,
                                cellWidth: cellWidth,
                                cellHeight: cellHeight
                            )

                            ForEach(track.notes, id: \.id) { note in
                                if let rowIndex = pitchRows.firstIndex(where: { $0.pitch == note.pitch }) {
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
                                        onNotesChanged: onNotesChanged
                                    )
                                }
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
            .frame(height: gridHeight)

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
                .fill(Color.white.opacity(0.04))
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
            Button {
                adjustOctave(-1)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .frame(width: 20, height: 20)
            }
            .disabled(track.octaveShift <= octaveRange.lowerBound)

            Text("Oct \(track.octaveShift >= 0 ? "+\(track.octaveShift)" : "\(track.octaveShift)")")
                .font(.caption.weight(.semibold))

            Button {
                adjustOctave(1)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 20, height: 20)
            }
            .disabled(track.octaveShift >= octaveRange.upperBound)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(track.instrument.color.opacity(0.2))
        )
        .buttonStyle(.plain)
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
            guard let rowIndex = pitchRows.firstIndex(where: { $0.pitch == note.pitch }) else { continue }
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
        case .bass, .guitar, .synth, .piano:
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

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(rows) { row in
                Text(row.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: rowHeight)
                    .frame(width: 42, alignment: .trailing)
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

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )

            Rectangle()
                .fill(Color.white.opacity(0.7))
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
        .onChange(of: note.duration) { _, _ in
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

    var body: some View {
        Canvas { context, size in
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
            context.stroke(gridPath, with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)

            var barPath = Path()
            let stepsPerBar = beatsPerBar * stepsPerBeat
            for bar in 0...max(0, columns / stepsPerBar) {
                let x = CGFloat(bar * stepsPerBar) * cellWidth
                barPath.move(to: CGPoint(x: x, y: 0))
                barPath.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(barPath, with: .color(Color.white.opacity(0.25)), lineWidth: 1)
        }
        .frame(
            width: CGFloat(columns) * cellWidth,
            height: CGFloat(rows) * cellHeight
        )
    }
}

struct NoteInspector: View {
    @Bindable var note: StudioNote
    let maxDuration: Double
    let stepLength: Double
    let onDelete: () -> Void
    let onNoteUpdated: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note Settings")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Length")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Stepper(value: $note.duration, in: stepLength...maxDuration, step: stepLength) {
                        Text("\(note.duration, specifier: "%.2g") beats")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Velocity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(note.velocity) },
                            set: { note.velocity = Int($0) }
                        ),
                        in: 20...127,
                        step: 1
                    )
                }

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(Color.red))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
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
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(StudioStyle.allCases) { style in
                        Button {
                            currentSelection = style
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: style.icon)
                                        .font(.title3)
                                    Spacer()
                                    if currentSelection == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                    }
                                }

                                Text(style.title)
                                    .font(.headline)
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .foregroundStyle(.white)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(style.accentColor.opacity(currentSelection == style ? 0.35 : 0.15))
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

                Button {
                    if let style = currentSelection {
                        onConfirm(style)
                        dismiss()
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill((currentSelection ?? selectedStyle)?.accentColor ?? SectionColor.purple.color)
                        )
                }
                .disabled(currentSelection == nil)
            }
            .padding(24)
            .navigationTitle("Studio Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
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
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                if availableInstruments.isEmpty {
                    Text("No instruments available.")
                        .foregroundStyle(.secondary)
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
                                            .font(.title3)
                                        Spacer()
                                        if isAdded {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                        }
                                    }

                                    Text(instrument.title)
                                        .font(.headline)

                                    Text(isAdded ? "Already added" : "Tap to add")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.white)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(instrument.color.opacity(isAdded ? 0.2 : 0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(instrument.color.opacity(isAdded ? 0.5 : 0.8), lineWidth: isAdded ? 1 : 2)
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
                }
            }
        }
        .preferredColorScheme(.dark)
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
                        .foregroundStyle(.secondary)
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
                                        .foregroundStyle(.white)
                                    Text(recording.recordingType.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(recording.duration, specifier: "%.1f")s")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.2))
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
        .preferredColorScheme(.dark)
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
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 24)
                
                VStack(spacing: 16) {
                    Button {
                        onAddInstrument()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(SectionColor.purple.color.opacity(0.3))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Instrument")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Text("Piano, Guitar, Drums, Bass, Synth")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
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
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(SectionColor.cyan.color.opacity(0.3))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Recording")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Text(hasRecordings ? "Import audio from your recordings" : "No recordings available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(SectionColor.cyan.color.opacity(hasRecordings ? 0.4 : 0.2), lineWidth: 1.5)
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
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.height(350)])
    }
}
