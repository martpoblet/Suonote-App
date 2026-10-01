import SwiftUI
import SwiftData

// MARK: - Drum editor
/// Step sequencer: one lane per drum voice in its own color, pads shaded by
/// velocity. "Hits" mode toggles pads; "Accent" mode cycles a pad through
/// ghost → normal → accent. Grooves for the song's style sit on top as presets.
struct StudioDrumEditor: View {
    @Bindable var track: StudioTrack
    let beatsPerBar: Int
    let timeBottom: Int
    let totalBars: Int
    let barSectionInfos: [StudioBarSectionInfo]
    let style: StudioStyle?
    let onNotesChanged: () -> Void

    enum Mode: String, CaseIterable, Identifiable {
        case hits, accent
        var id: String { rawValue }
        var title: String { self == .hits ? String(localized: "Hits") : String(localized: "Accent") }
        var icon: String { self == .hits ? "square.grid.3x3.fill" : "dial.high" }
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playback: StudioPlaybackEngine

    @State private var mode: Mode = .hits
    @State private var copiedBarIndex: Int?
    @State private var cachedNotesByPitch: [Int: [Int: StudioNote]] = [:]
    @State private var cachedNotesSignature: Int = 0
    @State private var cellWidth: CGFloat = 26
    @State private var hScroll = ScrollPosition()
    @State private var hVisible: CGRect = .zero
    @State private var showingClearConfirm = false

    private let laneHeight: CGFloat = 36
    private let rulerHeight: CGFloat = 40
    private let labelWidth: CGFloat = 92

    private var stepsPerBeat: Int { timeBottom == 8 ? 2 : 4 }
    private var stepsPerBar: Int { beatsPerBar * stepsPerBeat }
    private var totalSteps: Int { max(1, totalBars * stepsPerBar) }
    private var stepLength: Double { 1.0 / Double(stepsPerBeat) }
    private var totalBeats: Double { Double(max(1, totalBars * beatsPerBar)) }
    private var barWidth: CGFloat { CGFloat(stepsPerBar) * cellWidth }
    private var gridWidth: CGFloat { CGFloat(totalSteps) * cellWidth + 16 }
    private var gridHeight: CGFloat { CGFloat(drumLanes.count) * laneHeight }

    private var normalizedBarInfos: [StudioBarSectionInfo] {
        let byIndex = Dictionary(uniqueKeysWithValues: barSectionInfos.map { ($0.barIndex, $0) })
        return (0..<max(1, totalBars)).map { bar in
            byIndex[bar] ?? StudioBarSectionInfo(barIndex: bar, sectionLabel: String(localized: "Song"), sectionColor: track.instrument.color, chordLabel: nil)
        }
    }

    private var presets: [DrumPreset] {
        DrumPreset.presets(for: style ?? .pop, beatsPerBar: beatsPerBar, timeBottom: timeBottom)
    }

    private var currentPreset: DrumPreset? {
        track.drumPreset ?? style.map { DrumPreset.defaultPreset(for: $0, beatsPerBar: beatsPerBar, timeBottom: timeBottom) }
    }

    var drumLanes: [DrumLane] {
        let map = SoundFontManager.drumPitchMap(for: track.variant)
        return [
            DrumLane(name: String(localized: "Kick"), pitch: map.kick, color: DesignSystem.Colors.sectionCoral, velocity: .init(ghost: 62, normal: 108, accent: 120)),
            DrumLane(name: String(localized: "Snare"), pitch: map.snare, color: DesignSystem.Colors.sectionSand, velocity: .init(ghost: 58, normal: 98, accent: 112)),
            DrumLane(name: String(localized: "Rim"), pitch: map.rim, color: DesignSystem.Colors.sectionSand, velocity: .init(ghost: 52, normal: 86, accent: 102)),
            DrumLane(name: String(localized: "Clap"), pitch: map.clap, color: DesignSystem.Colors.sectionBerry, velocity: .init(ghost: 56, normal: 92, accent: 108)),
            DrumLane(name: String(localized: "Closed hat"), pitch: map.hatClosed, color: DesignSystem.Colors.sectionSky, velocity: .init(ghost: 48, normal: 72, accent: 88)),
            DrumLane(name: String(localized: "Open hat"), pitch: map.hatOpen, color: DesignSystem.Colors.sectionSky, velocity: .init(ghost: 54, normal: 78, accent: 94)),
            DrumLane(name: String(localized: "Ride"), pitch: map.ride, color: DesignSystem.Colors.sectionOcean, velocity: .init(ghost: 50, normal: 76, accent: 92)),
            DrumLane(name: String(localized: "Crash"), pitch: map.crash, color: DesignSystem.Colors.sectionLavender, velocity: .init(ghost: 64, normal: 96, accent: 112)),
            DrumLane(name: String(localized: "Low tom"), pitch: map.tomLow, color: DesignSystem.Colors.sectionMoss, velocity: .init(ghost: 58, normal: 92, accent: 108)),
            DrumLane(name: String(localized: "Mid tom"), pitch: map.tomMid, color: DesignSystem.Colors.sectionMoss, velocity: .init(ghost: 60, normal: 94, accent: 110)),
            DrumLane(name: String(localized: "High tom"), pitch: map.tomHigh, color: DesignSystem.Colors.sectionSage, velocity: .init(ghost: 62, normal: 96, accent: 112)),
            DrumLane(name: String(localized: "Perc"), pitch: map.perc, color: DesignSystem.Colors.sectionSage, velocity: .init(ghost: 52, normal: 86, accent: 100))
        ]
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            presetStrip
                .padding(.vertical, DesignSystem.Spacing.xs)

            Hairline()

            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    laneLabels
                    padGrid
                }
            }
            .scrollIndicators(.hidden)
            .background(DesignSystem.Colors.surface)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            toolPalette
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xs)
        }
        .onChange(of: totalBars) { _, newValue in
            if let copiedBarIndex, copiedBarIndex >= newValue { self.copiedBarIndex = nil }
            refreshNotesCacheIfNeeded()
        }
        .onChange(of: track.notes.count) { _, _ in refreshNotesCacheIfNeeded() }
        .onChange(of: playback.currentBeat) { _, beat in followPlayhead(beat: beat) }
        .onAppear { refreshNotesCacheIfNeeded() }
        .confirmationDialog("Clear the whole groove?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("Clear all hits", role: .destructive) { replaceNotes(with: []) }
        }
    }

    // MARK: Presets

    private var presetStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("Groove").eyebrow()
                    .padding(.trailing, 4)
                ForEach(presets) { preset in
                    SelectableChip(title: preset.title, isSelected: currentPreset == preset) {
                        applyPreset(preset)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Lanes

    private var laneLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: rulerHeight + 1)
            ForEach(drumLanes) { lane in
                HStack(spacing: 8) {
                    Circle()
                        .fill(lane.color)
                        .frame(width: 8, height: 8)
                    Text(lane.name)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .frame(width: labelWidth, height: laneHeight, alignment: .leading)
            }
        }
        .background(DesignSystem.Colors.surfaceSecondary)
        .overlay(alignment: .trailing) {
            Rectangle().fill(DesignSystem.Colors.border).frame(width: 1)
        }
    }

    private var padGrid: some View {
        let lanes = drumLanes
        let notesByPitch = cachedNotesByPitch
        let viewport = CGRect(x: max(0, hVisible.minX), y: 0, width: max(1, hVisible.width), height: gridHeight)

        return ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                StudioEditorRuler(
                    barInfos: normalizedBarInfos,
                    barWidth: barWidth,
                    height: rulerHeight,
                    beatsPerBar: beatsPerBar,
                    onSeek: { playback.seek(to: $0) }
                )
                Hairline()
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .frame(width: gridWidth, height: gridHeight)
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { location in
                            handleTap(location, lanes: lanes)
                        }
                    StudioDrumPadCanvas(
                        lanes: lanes,
                        notesByPitch: notesByPitch,
                        totalSteps: totalSteps,
                        stepsPerBeat: stepsPerBeat,
                        stepsPerBar: stepsPerBar,
                        cellWidth: cellWidth,
                        laneHeight: laneHeight,
                        viewport: viewport
                    )
                    .frame(width: viewport.width, height: viewport.height)
                    .offset(x: viewport.minX)
                    .allowsHitTesting(false)
                }
                .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
            }
            .overlay(alignment: .topLeading) {
                StudioEditorPlayhead(height: rulerHeight + gridHeight + 1) { beat in
                    CGFloat(beat) * CGFloat(stepsPerBeat) * cellWidth
                }
            }
        }
        .scrollPosition($hScroll)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGRect.self, of: { $0.visibleRect }) { _, rect in
            hVisible = rect
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drum pattern, \(totalBars) bars")
    }

    // MARK: Tool palette

    private var toolPalette: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases) { option in
                Button {
                    mode = option
                    haptic(.selection)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(option.title)
                            .font(DesignSystem.Typography.buttonSmall)
                    }
                    .foregroundStyle(mode == option ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Capsule().fill(mode == option ? DesignSystem.Colors.textPrimary : Color.clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == option ? .isSelected : [])
            }

            Divider().frame(height: 22).padding(.horizontal, 4)

            Menu {
                Section("Copy") {
                    ForEach(0..<totalBars, id: \.self) { bar in
                        Button("Copy bar \(bar + 1)") { copiedBarIndex = bar; haptic(.selection) }
                    }
                }
                if let source = copiedBarIndex {
                    Section("Paste bar \(source + 1)") {
                        Button("Paste to every bar") { duplicateBarToAllBars(from: source) }
                            .disabled(totalBars <= 1)
                        ForEach(0..<totalBars, id: \.self) { bar in
                            Button("Paste to bar \(bar + 1)") { duplicateBar(from: source, to: bar) }
                                .disabled(bar == source)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copiedBarIndex == nil ? "doc.on.doc" : "doc.on.clipboard")
                        .font(.system(size: 12, weight: .semibold))
                    Text(copiedBarIndex.map { String(localized: "Bar \($0 + 1)") } ?? String(localized: "Copy"))
                        .font(DesignSystem.Typography.buttonSmall)
                }
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, 8)
                .frame(height: 34)
                .contentShape(Capsule())
            }
            .accessibilityLabel(copiedBarIndex.map { String(localized: "Paste bar \($0 + 1)") } ?? String(localized: "Copy a bar"))

            Spacer(minLength: 0)

            Button {
                showingClearConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .accessibilityLabel("Clear pattern")

            Button {
                withAnimation(DesignSystem.Animations.quickSpring) { cellWidth = cellWidth > 30 ? 22 : 36 }
            } label: {
                Image(systemName: cellWidth > 30 ? "minus.magnifyingglass" : "plus.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .accessibilityLabel(cellWidth > 30 ? "Zoom out" : "Zoom in")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Editing

    private func handleTap(_ location: CGPoint, lanes: [DrumLane]) {
        let laneIndex = Int(location.y / laneHeight)
        let step = Int(location.x / cellWidth)
        guard lanes.indices.contains(laneIndex), step >= 0, step < totalSteps else { return }
        let lane = lanes[laneIndex]
        switch mode {
        case .hits:
            toggleStep(lane: lane, step: step)
            haptic(.light)
        case .accent:
            cycleVelocity(lane: lane, step: step)
            haptic(.medium)
        }
    }

    private func stepIndex(for note: StudioNote) -> Int {
        Int(floor(note.startBeat / stepLength + 1e-6))
    }

    private func notesAt(pitch: Int, step: Int) -> [StudioNote] {
        track.notes.filter { $0.pitch == pitch && stepIndex(for: $0) == step }
    }

    private func toggleStep(lane: DrumLane, step: Int) {
        let existing = notesAt(pitch: lane.pitch, step: step)
        if !existing.isEmpty {
            existing.forEach(delete)
            notesDidChange()
            return
        }
        addNote(pitch: lane.pitch, step: step, velocity: lane.velocity.normal)
    }

    private func cycleVelocity(lane: DrumLane, step: Int) {
        if let note = notesAt(pitch: lane.pitch, step: step).first {
            note.velocity = nextVelocity(for: note.velocity, profile: lane.velocity)
            notesDidChange()
        } else {
            addNote(pitch: lane.pitch, step: step, velocity: lane.velocity.accent)
        }
    }

    private func nextVelocity(for current: Int, profile: DrumVelocityProfile) -> Int {
        if current >= profile.accent - 2 { return profile.ghost }
        if current <= profile.ghost + 4 { return profile.normal }
        return profile.accent
    }

    private func addNote(pitch: Int, step: Int, velocity: Int) {
        let startBeat = Double(step) * stepLength
        guard startBeat < totalBeats else { return }
        notesAt(pitch: pitch, step: step).forEach(delete)
        let note = StudioNote(startBeat: startBeat, duration: stepLength, pitch: pitch, velocity: velocity)
        note.track = track
        track.notes.append(note)
        modelContext.insert(note)
        notesDidChange()
    }

    private func delete(_ note: StudioNote) {
        if let index = track.notes.firstIndex(where: { $0.id == note.id }) {
            track.notes.remove(at: index)
        }
        modelContext.delete(note)
    }

    private func applyPreset(_ preset: DrumPreset) {
        guard let style else { return }
        track.drumPreset = preset
        let notes = StudioGenerator.generateDrumNotes(
            totalBars: totalBars,
            beatsPerBar: beatsPerBar,
            timeBottom: timeBottom,
            style: style,
            preset: preset,
            variant: track.variant,
            intensity: track.regenerateIntensity,
            complexity: track.regenerateComplexity
        )
        replaceNotes(with: notes)
        haptic(.success)
    }

    private func replaceNotes(with notes: [StudioNote]) {
        for note in track.notes {
            modelContext.delete(note)
        }
        track.notes.removeAll()
        for note in notes {
            note.track = track
            track.notes.append(note)
            modelContext.insert(note)
        }
        notesDidChange()
    }

    private func duplicateBar(from sourceBar: Int, to targetBar: Int, notify: Bool = true) {
        guard sourceBar != targetBar else { return }
        let barLength = Double(beatsPerBar)
        let sourceStart = Double(sourceBar) * barLength
        let targetStart = Double(targetBar) * barLength
        let targetEnd = targetStart + barLength

        let toRemove = track.notes.filter { $0.startBeat >= targetStart && $0.startBeat < targetEnd }
        toRemove.forEach(delete)

        let sourceNotes = track.notes.filter { $0.startBeat >= sourceStart && $0.startBeat < sourceStart + barLength }
        for note in sourceNotes {
            let newStart = targetStart + (note.startBeat - sourceStart)
            guard newStart < targetEnd else { continue }
            let copy = StudioNote(
                startBeat: newStart,
                duration: min(note.duration, max(0.25, targetEnd - newStart)),
                pitch: note.pitch,
                velocity: note.velocity
            )
            copy.track = track
            track.notes.append(copy)
            modelContext.insert(copy)
        }
        if notify {
            notesDidChange()
            haptic(.success)
        }
    }

    private func duplicateBarToAllBars(from sourceBar: Int) {
        guard totalBars > 1 else { return }
        for bar in 0..<totalBars where bar != sourceBar {
            duplicateBar(from: sourceBar, to: bar, notify: false)
        }
        notesDidChange()
        haptic(.success)
    }

    private func notesDidChange() {
        refreshNotesCacheIfNeeded()
        onNotesChanged()
    }

    private func refreshNotesCacheIfNeeded() {
        var hasher = Hasher()
        for note in track.notes {
            hasher.combine(note.id)
            hasher.combine(note.startBeat)
            hasher.combine(note.pitch)
            hasher.combine(note.velocity)
        }
        let signature = hasher.finalize()
        guard signature != cachedNotesSignature else { return }
        cachedNotesSignature = signature
        var map: [Int: [Int: StudioNote]] = [:]
        for note in track.notes {
            let step = stepIndex(for: note)
            guard step >= 0, step < totalSteps else { continue }
            map[note.pitch, default: [:]][step] = note
        }
        cachedNotesByPitch = map
    }

    private func followPlayhead(beat: Double) {
        guard playback.isPlaying, hVisible.width > 0 else { return }
        let playX = CGFloat(beat) * CGFloat(stepsPerBeat) * cellWidth
        if playX < hVisible.minX || playX > hVisible.maxX - 24 {
            let target = max(0, min(playX - hVisible.width * 0.15, gridWidth - hVisible.width))
            withAnimation(DesignSystem.Animations.smoothEase) {
                hScroll.scrollTo(x: target)
            }
        }
    }
}

// MARK: - Pads (viewport drawing)

struct StudioDrumPadCanvas: View {
    let lanes: [DrumLane]
    let notesByPitch: [Int: [Int: StudioNote]]
    let totalSteps: Int
    let stepsPerBeat: Int
    let stepsPerBar: Int
    let cellWidth: CGFloat
    let laneHeight: CGFloat
    let viewport: CGRect

    var body: some View {
        Canvas { context, size in
            let originX = viewport.minX
            let firstStep = max(0, Int(originX / cellWidth))
            let lastStep = min(totalSteps - 1, Int((originX + size.width) / cellWidth))
            guard firstStep <= lastStep else { return }

            for (laneIndex, lane) in lanes.enumerated() {
                let y = CGFloat(laneIndex) * laneHeight
                let hits = notesByPitch[lane.pitch] ?? [:]
                for step in firstStep...lastStep {
                    let x = CGFloat(step) * cellWidth - originX
                    let rect = CGRect(x: x + 2, y: y + 3, width: cellWidth - 4, height: laneHeight - 6)
                    let pad = Path(roundedRect: rect, cornerRadius: 5, style: .continuous)
                    if let note = hits[step] {
                        let strength = 0.3 + 0.7 * Double(min(127, max(1, note.velocity))) / 127
                        context.fill(pad, with: .color(lane.color.opacity(strength)))
                        context.stroke(pad, with: .color(DesignSystem.Colors.textPrimary.opacity(0.22)), lineWidth: 0.75)
                        if note.velocity <= 64 {
                            let dot = Path(ellipseIn: CGRect(x: rect.midX - 2, y: rect.midY - 2, width: 4, height: 4))
                            context.fill(dot, with: .color(DesignSystem.Colors.textPrimary.opacity(0.5)))
                        }
                    } else {
                        let isBeat = step % stepsPerBeat == 0
                        context.fill(pad, with: .color(isBeat ? DesignSystem.Colors.surfaceHover : DesignSystem.Colors.surfaceSecondary))
                    }
                }
            }

            // Bar rules.
            for step in firstStep...lastStep where step % stepsPerBar == 0 {
                let x = CGFloat(step) * cellWidth - originX
                context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(DesignSystem.Colors.borderActive))
            }
        }
    }
}

// MARK: - Lane model

struct DrumVelocityProfile {
    let ghost: Int
    let normal: Int
    let accent: Int
}

struct DrumLane: Identifiable {
    let id: String
    let name: String
    let pitch: Int
    let color: Color
    let velocity: DrumVelocityProfile

    init(name: String, pitch: Int, color: Color, velocity: DrumVelocityProfile) {
        self.id = "\(name)-\(pitch)"
        self.name = name
        self.pitch = pitch
        self.color = color
        self.velocity = velocity
    }
}
