import SwiftUI
import SwiftData

// MARK: - Piano roll
/// Full-range note editor. Tools: Draw (tap to write), Select (tap to pick,
/// drag to move) and Erase (tap to remove). Notes drag in time and pitch and
/// stretch from their right edge; a velocity lane sits under the grid. The
/// keyboard column, ruler and velocity lane stay pinned while the grid
/// scrolls; only the visible part of the grid is drawn.

enum StudioEditTool: String, CaseIterable, Identifiable {
    case draw, select, erase
    var id: String { rawValue }

    var title: String {
        switch self {
        case .draw: return String(localized: "Draw")
        case .select: return String(localized: "Select")
        case .erase: return String(localized: "Erase")
        }
    }

    var icon: String {
        switch self {
        case .draw: return "pencil.tip"
        case .select: return "hand.point.up.left"
        case .erase: return "eraser"
        }
    }
}

struct PitchRow: Identifiable {
    let pitch: Int
    let label: String
    var id: Int { pitch }

    var isBlackKey: Bool { StudioMusic.isBlackKey(pitch) }
    var isC: Bool { (pitch % 12 + 12) % 12 == 0 }

    static func rows(
        for instrument: StudioInstrument,
        variant: InstrumentVariant? = nil,
        style: StudioStyle?,
        octaveShift: Int,
        fullRange: Bool = false
    ) -> [PitchRow] {
        switch instrument {
        case .drums, .audio:
            return []
        case .bass, .guitar, .synth, .piano, .strings, .brass, .woodwinds, .organ, .mallets:
            let range = fullRange
                ? StudioGenerator.fullInstrumentRange(for: instrument, variant: variant)
                : StudioGenerator.instrumentRange(for: instrument, variant: variant, style: style, octaveShift: octaveShift)
            return Array(range).reversed().map { PitchRow(pitch: $0, label: StudioMusic.noteName($0)) }
        }
    }
}

struct StudioNoteEditor: View {
    @Bindable var track: StudioTrack
    let beatsPerBar: Int
    let timeBottom: Int
    let totalBars: Int
    let barSectionInfos: [StudioBarSectionInfo]
    let style: StudioStyle?
    let onNotesChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playback: StudioPlaybackEngine

    @State private var tool: StudioEditTool = .draw
    @State private var snap: Double = 0.25
    @State private var noteLength: Double = 1
    @State private var cellWidth: CGFloat = 22
    @State private var pinchBaseWidth: CGFloat?
    @State private var selectedNoteId: UUID?

    @State private var hScroll = ScrollPosition()
    @State private var vScroll = ScrollPosition()
    @State private var hVisible: CGRect = .zero
    @State private var vVisible: CGRect = .zero
    @State private var didInitialScroll = false

    private let stepsPerBeat = 4
    private let rowHeight: CGFloat = 20
    private let keyWidth: CGFloat = 46
    private let rulerHeight: CGFloat = 40
    private let laneHeight: CGFloat = 64

    // MARK: Geometry

    private var stepLength: Double { 1.0 / Double(stepsPerBeat) }
    private var totalBeats: Double { Double(max(1, totalBars * beatsPerBar)) }
    private var beatWidth: CGFloat { cellWidth * CGFloat(stepsPerBeat) }
    private var barWidth: CGFloat { beatWidth * CGFloat(beatsPerBar) }
    private var gridWidth: CGFloat { CGFloat(totalBeats) * beatWidth }
    private var contentWidth: CGFloat { keyWidth + gridWidth + 24 }

    private var pitchRows: [PitchRow] {
        PitchRow.rows(for: track.instrument, variant: track.variant, style: style, octaveShift: track.octaveShift, fullRange: true)
    }

    private var rowIndexByPitch: [Int: Int] {
        Dictionary(uniqueKeysWithValues: pitchRows.enumerated().map { ($0.element.pitch, $0.offset) })
    }

    private var gridHeight: CGFloat { CGFloat(pitchRows.count) * rowHeight }

    private var normalizedBarInfos: [StudioBarSectionInfo] {
        let byIndex = Dictionary(uniqueKeysWithValues: barSectionInfos.map { ($0.barIndex, $0) })
        return (0..<max(1, totalBars)).map { bar in
            byIndex[bar] ?? StudioBarSectionInfo(barIndex: bar, sectionLabel: String(localized: "Song"), sectionColor: track.instrument.color, chordLabel: nil)
        }
    }

    private var selectedNote: StudioNote? {
        guard let selectedNoteId else { return nil }
        return track.notes.first { $0.id == selectedNoteId }
    }

    private func x(forBeat beat: Double) -> CGFloat {
        keyWidth + CGFloat(beat) * beatWidth
    }

    private func snapped(_ beat: Double) -> Double {
        (beat / snap).rounded(.down) * snap
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            contextBar
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .frame(minHeight: 58)

            Hairline()

            grid
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            toolPalette
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xs)
        }
        .onChange(of: playback.currentBeat) { _, beat in
            followPlayhead(beat: beat)
        }
    }

    // MARK: Context bar (hint or inspector)

    @ViewBuilder
    private var contextBar: some View {
        if let note = selectedNote {
            NoteInspector(
                note: note,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                step: snap,
                maxDuration: max(stepLength, totalBeats - note.startBeat),
                onDelete: { deleteNote(note) },
                onNoteUpdated: onNotesChanged,
                onDeselect: { selectedNoteId = nil }
            )
        } else {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: tool.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                Text(hint)
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\(track.notes.count) notes")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hint: String {
        switch tool {
        case .draw: return String(localized: "Tap the grid to write a note. Drag notes to move, pull an edge to stretch.")
        case .select: return String(localized: "Tap a note to shape it. Drag to move it in time or pitch.")
        case .erase: return String(localized: "Tap notes to remove them.")
        }
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                StudioEditorRuler(
                    barInfos: normalizedBarInfos,
                    barWidth: barWidth,
                    leadingInset: keyWidth,
                    height: rulerHeight,
                    beatsPerBar: beatsPerBar,
                    onSeek: { playback.seek(to: $0) }
                )
                .overlay(alignment: .leading) {
                    pinnedCorner(height: rulerHeight) {
                        Text(StudioGridValue.label(beats: snap, timeBottom: timeBottom))
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }

                Hairline()

                ScrollView(.vertical) {
                    noteCanvas
                }
                .scrollPosition($vScroll)
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGRect.self, of: { $0.visibleRect }) { _, rect in
                    vVisible = rect
                    scrollToNotesIfNeeded(viewportHeight: rect.height)
                }

                Hairline()

                StudioVelocityLane(
                    notes: track.notes,
                    selectedNoteId: selectedNoteId,
                    color: track.instrument.color,
                    stepLength: stepLength,
                    cellWidth: cellWidth,
                    leadingInset: keyWidth,
                    height: laneHeight,
                    onChanged: { },
                    onEnded: onNotesChanged
                )
                .frame(width: contentWidth, height: laneHeight)
                .overlay(alignment: .leading) {
                    pinnedCorner(height: laneHeight) {
                        Text("Vel")
                            .eyebrow()
                    }
                }
            }
            .frame(width: contentWidth, alignment: .leading)
            .overlay(alignment: .topLeading) {
                StudioEditorPlayhead(
                    height: rulerHeight + max(0, vVisible.height) + laneHeight + 2,
                    xForBeat: x(forBeat:)
                )
            }
        }
        .scrollPosition($hScroll)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGRect.self, of: { $0.visibleRect }) { _, rect in
            hVisible = rect
        }
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let base = pinchBaseWidth ?? cellWidth
                    if pinchBaseWidth == nil { pinchBaseWidth = cellWidth }
                    cellWidth = min(44, max(10, base * value.magnification))
                }
                .onEnded { _ in pinchBaseWidth = nil }
        )
        .background(DesignSystem.Colors.surface)
    }

    /// Fixed area at the left edge that stays put while the grid scrolls.
    private func pinnedCorner<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: keyWidth, height: height)
            .background(DesignSystem.Colors.surfaceSecondary)
            .overlay(alignment: .trailing) {
                Rectangle().fill(DesignSystem.Colors.border).frame(width: 1)
            }
            .offset(x: max(0, hVisible.minX))
    }

    private var noteCanvas: some View {
        let rows = pitchRows
        let indexByPitch = rowIndexByPitch
        let viewport = CGRect(
            x: max(0, hVisible.minX),
            y: max(0, vVisible.minY),
            width: max(1, hVisible.width),
            height: max(1, vVisible.height)
        )

        return ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: contentWidth, height: gridHeight)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    handleGridTap(location, rows: rows)
                }

            StudioPianoRollGrid(
                rows: rows,
                rowHeight: rowHeight,
                keyWidth: keyWidth,
                stepWidth: cellWidth,
                stepsPerBeat: stepsPerBeat,
                beatsPerBar: beatsPerBar,
                totalBeats: totalBeats,
                barInfos: normalizedBarInfos,
                viewport: viewport
            )
            .frame(width: viewport.width, height: viewport.height)
            .offset(x: viewport.minX, y: viewport.minY)
            .allowsHitTesting(false)

            ForEach(track.notes, id: \.id) { note in
                if let row = indexByPitch[note.pitch] {
                    StudioNoteBlock(
                        note: note,
                        rowIndex: row,
                        rows: rows,
                        rowHeight: rowHeight,
                        beatWidth: beatWidth,
                        originX: keyWidth,
                        snap: snap,
                        minDuration: stepLength,
                        totalBeats: totalBeats,
                        color: track.instrument.color,
                        isSelected: selectedNoteId == note.id,
                        tool: tool,
                        onTap: { handleNoteTap(note) },
                        onEditEnded: {
                            selectedNoteId = note.id
                            onNotesChanged()
                        }
                    )
                }
            }

            StudioKeyColumn(rows: rows, rowHeight: rowHeight, width: keyWidth) { pitch in
                audition(pitch)
            }
            .offset(x: max(0, hVisible.minX))
        }
        .frame(width: contentWidth, height: gridHeight, alignment: .topLeading)
    }

    // MARK: Tool palette (floating glass)

    private var toolPalette: some View {
        HStack(spacing: 4) {
            ForEach(StudioEditTool.allCases) { option in
                Button {
                    tool = option
                    if option == .erase { selectedNoteId = nil }
                    haptic(.selection)
                } label: {
                    Image(systemName: option.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tool == option ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                        .frame(width: 38, height: 34)
                        .background(
                            Capsule().fill(tool == option ? DesignSystem.Colors.textPrimary : Color.clear)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(tool == option ? .isSelected : [])
            }

            Divider().frame(height: 22).padding(.horizontal, 4)

            Menu {
                Picker("Snap", selection: $snap) {
                    ForEach(StudioGridValue.snaps, id: \.self) { value in
                        Text(StudioGridValue.label(beats: value, timeBottom: timeBottom)).tag(value)
                    }
                }
            } label: {
                paletteLabel(icon: "square.grid.3x1.below.line.grid.1x2", text: StudioGridValue.label(beats: snap, timeBottom: timeBottom))
            }
            .accessibilityLabel("Snap: \(StudioGridValue.label(beats: snap, timeBottom: timeBottom))")

            Menu {
                Picker("Note length", selection: $noteLength) {
                    ForEach(StudioGridValue.lengths, id: \.self) { value in
                        Text(StudioGridValue.label(beats: value, timeBottom: timeBottom)).tag(value)
                    }
                }
            } label: {
                paletteLabel(icon: "music.note", text: StudioGridValue.label(beats: noteLength, timeBottom: timeBottom))
            }
            .accessibilityLabel("New note length: \(StudioGridValue.label(beats: noteLength, timeBottom: timeBottom))")

            Spacer(minLength: 0)

            Button {
                withAnimation(DesignSystem.Animations.quickSpring) { cellWidth = max(10, cellWidth - 6) }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .accessibilityLabel("Zoom out")

            Button {
                withAnimation(DesignSystem.Animations.quickSpring) { cellWidth = min(44, cellWidth + 6) }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .accessibilityLabel("Zoom in")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
    }

    private func paletteLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(DesignSystem.Typography.buttonSmall)
                .monospacedDigit()
        }
        .foregroundStyle(DesignSystem.Colors.textPrimary)
        .padding(.horizontal, 8)
        .frame(height: 34)
        .contentShape(Capsule())
    }

    // MARK: Editing

    private func handleGridTap(_ location: CGPoint, rows: [PitchRow]) {
        let gridX = location.x - keyWidth
        guard gridX >= 0, location.y >= 0 else { return }
        let rowIndex = Int(location.y / rowHeight)
        guard rows.indices.contains(rowIndex) else { return }

        switch tool {
        case .draw:
            let start = snapped(Double(gridX / beatWidth))
            guard start < totalBeats else { return }
            addNote(startBeat: start, pitch: rows[rowIndex].pitch)
        case .select, .erase:
            selectedNoteId = nil
        }
    }

    private func handleNoteTap(_ note: StudioNote) {
        switch tool {
        case .erase:
            deleteNote(note)
            haptic(.light)
        case .draw, .select:
            selectedNoteId = selectedNoteId == note.id && tool == .select ? nil : note.id
            haptic(.selection)
        }
    }

    private func addNote(startBeat: Double, pitch: Int) {
        let duration = min(noteLength, max(stepLength, totalBeats - startBeat))
        removeOverlappingNotes(pitch: pitch, startBeat: startBeat, duration: duration)

        let newNote = StudioNote(startBeat: startBeat, duration: duration, pitch: pitch, velocity: 92)
        newNote.track = track
        track.notes.append(newNote)
        modelContext.insert(newNote)
        selectedNoteId = newNote.id
        haptic(.light)
        audition(pitch)
        onNotesChanged()
    }

    /// Hear a pitch on this track's sound (keyboard taps, new notes).
    private func audition(_ pitch: Int) {
        StudioSoundPreviewer.shared.playNote(
            instrument: track.instrument,
            variant: track.variant,
            pitch: pitch,
            velocity: 96
        )
    }

    private func removeOverlappingNotes(pitch: Int, startBeat: Double, duration: Double) {
        let endBeat = startBeat + duration
        let overlapping = track.notes.filter { note in
            guard note.pitch == pitch else { return false }
            return max(note.startBeat, startBeat) < min(note.startBeat + note.duration, endBeat)
        }
        for note in overlapping {
            deleteNote(note, notify: false)
        }
    }

    private func deleteNote(_ note: StudioNote, notify: Bool = true) {
        if let index = track.notes.firstIndex(where: { $0.id == note.id }) {
            track.notes.remove(at: index)
        }
        if selectedNoteId == note.id { selectedNoteId = nil }
        modelContext.delete(note)
        if notify { onNotesChanged() }
    }

    // MARK: Scrolling

    private func scrollToNotesIfNeeded(viewportHeight: CGFloat) {
        guard !didInitialScroll, viewportHeight > 0 else { return }
        didInitialScroll = true
        let rows = pitchRows
        let pitches = track.notes.map(\.pitch).sorted()
        let centerPitch: Int
        if pitches.isEmpty {
            centerPitch = rows.isEmpty ? 60 : rows[rows.count / 2].pitch
        } else {
            centerPitch = pitches[pitches.count / 2]
        }
        guard let index = rowIndexByPitch[centerPitch] else { return }
        let target = CGFloat(index) * rowHeight - viewportHeight / 2
        vScroll.scrollTo(y: max(0, min(target, gridHeight - viewportHeight)))
    }

    private func followPlayhead(beat: Double) {
        guard playback.isPlaying, hVisible.width > 0 else { return }
        let playX = x(forBeat: beat)
        let visibleStart = hVisible.minX + keyWidth
        let visibleEnd = hVisible.maxX - 24
        if playX < visibleStart || playX > visibleEnd {
            let target = max(0, min(playX - keyWidth - hVisible.width * 0.15, contentWidth - hVisible.width))
            withAnimation(DesignSystem.Animations.smoothEase) {
                hScroll.scrollTo(x: target)
            }
        }
    }
}

// MARK: - Grid drawing (viewport only)

struct StudioPianoRollGrid: View {
    let rows: [PitchRow]
    let rowHeight: CGFloat
    let keyWidth: CGFloat
    let stepWidth: CGFloat
    let stepsPerBeat: Int
    let beatsPerBar: Int
    let totalBeats: Double
    let barInfos: [StudioBarSectionInfo]
    /// Visible rect in content coordinates.
    let viewport: CGRect

    var body: some View {
        Canvas { context, size in
            let originX = viewport.minX
            let originY = viewport.minY
            let gridEndX = keyWidth + CGFloat(totalBeats) * CGFloat(stepsPerBeat) * stepWidth

            // Row shading: black keys recessed, C rows ruled.
            let firstRow = max(0, Int(originY / rowHeight))
            let lastRow = min(rows.count - 1, Int((originY + size.height) / rowHeight))
            if firstRow <= lastRow {
                for index in firstRow...lastRow {
                    let y = CGFloat(index) * rowHeight - originY
                    let row = rows[index]
                    if row.isBlackKey {
                        context.fill(
                            Path(CGRect(x: 0, y: y, width: size.width, height: rowHeight)),
                            with: .color(DesignSystem.Colors.surfaceSecondary)
                        )
                    }
                    let line = Path(CGRect(x: 0, y: y + rowHeight - 0.5, width: size.width, height: 0.5))
                    context.fill(line, with: .color(row.pitch % 12 == 0 ? DesignSystem.Colors.borderActive : DesignSystem.Colors.border.opacity(0.7)))
                }
            }

            // Section tint per bar.
            let beatWidth = stepWidth * CGFloat(stepsPerBeat)
            let barWidth = beatWidth * CGFloat(beatsPerBar)
            let firstBar = max(0, Int((originX - keyWidth) / barWidth))
            let lastBar = min(barInfos.count - 1, Int((originX + size.width - keyWidth) / barWidth))
            if firstBar <= lastBar {
                for bar in firstBar...lastBar {
                    let x = keyWidth + CGFloat(bar) * barWidth - originX
                    context.fill(
                        Path(CGRect(x: x, y: 0, width: barWidth, height: size.height)),
                        with: .color(barInfos[bar].sectionColor.opacity(0.05))
                    )
                }
            }

            // Vertical lines: steps (faint), beats, bars (strong).
            let firstStep = max(0, Int((originX - keyWidth) / stepWidth))
            let lastStep = Int((min(gridEndX, originX + size.width) - keyWidth) / stepWidth)
            if firstStep <= lastStep {
                let stepsPerBar = stepsPerBeat * beatsPerBar
                for step in firstStep...lastStep {
                    let x = keyWidth + CGFloat(step) * stepWidth - originX
                    let isBar = step % stepsPerBar == 0
                    let isBeat = step % stepsPerBeat == 0
                    if !isBar && !isBeat && stepWidth < 14 { continue }
                    let width: CGFloat = isBar ? 1 : 0.5
                    let color: Color = isBar
                        ? DesignSystem.Colors.borderActive
                        : (isBeat ? DesignSystem.Colors.border : DesignSystem.Colors.borderSubtle)
                    context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(color))
                }
            }
        }
    }
}

// MARK: - Keyboard column

/// Pinned keyboard on the left of the piano roll: black keys shaded, C labeled.
struct StudioKeyColumn: View {
    let rows: [PitchRow]
    let rowHeight: CGFloat
    let width: CGFloat
    /// Called with the MIDI pitch of a tapped key.
    var onPlay: ((Int) -> Void)? = nil
    @State private var pressedPitch: Int?

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(DesignSystem.Colors.surface))
            for (index, row) in rows.enumerated() {
                let y = CGFloat(index) * rowHeight
                if row.pitch == pressedPitch {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: rowHeight)),
                        with: .color(DesignSystem.Colors.primary.opacity(0.55))
                    )
                } else if row.isBlackKey {
                    context.fill(
                        Path(roundedRect: CGRect(x: 0, y: y + 1, width: size.width * 0.62, height: rowHeight - 2), cornerRadius: 2),
                        with: .color(DesignSystem.Colors.textPrimary.opacity(0.78))
                    )
                }
                if row.isC {
                    context.fill(Path(CGRect(x: 0, y: y + rowHeight - 1, width: size.width, height: 1)), with: .color(DesignSystem.Colors.borderActive))
                    let text = Text(row.label)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    context.draw(text, at: CGPoint(x: size.width - 5, y: y + rowHeight / 2), anchor: .trailing)
                }
            }
            context.fill(Path(CGRect(x: size.width - 1, y: 0, width: 1, height: size.height)), with: .color(DesignSystem.Colors.border))
        }
        .frame(width: width, height: CGFloat(rows.count) * rowHeight)
        .contentShape(Rectangle())
        .gesture(
            // Press a key to hear it; slide to glissando across keys.
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let index = Int(value.location.y / rowHeight)
                    guard rows.indices.contains(index) else { return }
                    let pitch = rows[index].pitch
                    guard pitch != pressedPitch else { return }
                    pressedPitch = pitch
                    onPlay?(pitch)
                    haptic(.selection)
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.25)) { pressedPitch = nil }
                },
            including: onPlay == nil ? .none : .all
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Note block

struct StudioNoteBlock: View {
    @Bindable var note: StudioNote
    let rowIndex: Int
    let rows: [PitchRow]
    let rowHeight: CGFloat
    let beatWidth: CGFloat
    let originX: CGFloat
    let snap: Double
    let minDuration: Double
    let totalBeats: Double
    let color: Color
    let isSelected: Bool
    let tool: StudioEditTool
    let onTap: () -> Void
    let onEditEnded: () -> Void

    @State private var dragStart: (beat: Double, row: Int)?
    @State private var resizeStart: Double?

    private var width: CGFloat { max(6, CGFloat(note.duration) * beatWidth - 1) }
    private var velocityOpacity: Double { 0.35 + 0.65 * Double(min(127, max(1, note.velocity))) / 127 }

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color.opacity(velocityOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary.opacity(0.25), lineWidth: isSelected ? 2 : 0.75)
            )
            .overlay(alignment: .trailing) {
                if tool != .erase {
                    resizeHandle
                }
            }
            .frame(width: width, height: rowHeight - 3)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .gesture(moveGesture, isEnabled: tool != .erase)
            .offset(x: originX + CGFloat(note.startBeat) * beatWidth, y: CGFloat(rowIndex) * rowHeight + 1.5)
            .accessibilityElement()
            .accessibilityLabel("\(StudioMusic.noteName(note.pitch)) note")
            .accessibilityValue("Starts beat \(String(format: "%.2g", note.startBeat + 1)), velocity \(note.velocity)")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var resizeHandle: some View {
        Capsule()
            .fill(DesignSystem.Colors.textPrimary.opacity(isSelected ? 0.55 : 0.25))
            .frame(width: 3, height: max(4, rowHeight - 10))
            .padding(.trailing, 2)
            .frame(width: 14, height: rowHeight)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if resizeStart == nil { resizeStart = note.duration }
                        let proposed = (resizeStart ?? note.duration) + Double(value.translation.width / beatWidth)
                        let quantized = max(minDuration, (proposed / snap).rounded() * snap)
                        note.duration = min(quantized, max(minDuration, totalBeats - note.startBeat))
                    }
                    .onEnded { _ in
                        resizeStart = nil
                        onEditEnded()
                    }
            )
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = (note.startBeat, rowIndex)
                    haptic(.selection)
                }
                guard let start = dragStart else { return }
                let deltaBeats = Double(value.translation.width / beatWidth)
                let proposed = ((start.beat + deltaBeats) / snap).rounded() * snap
                note.startBeat = min(max(0, proposed), max(0, totalBeats - note.duration))
                let newRow = min(max(0, start.row + Int((value.translation.height / rowHeight).rounded())), rows.count - 1)
                let newPitch = rows[newRow].pitch
                if newPitch != note.pitch {
                    note.pitch = newPitch
                }
            }
            .onEnded { _ in
                dragStart = nil
                onEditEnded()
            }
    }
}

// MARK: - Velocity lane

/// Velocity sticks under the grid. Drag up/down over a note to set how hard
/// it's played (the selected note only, or every note starting at that spot).
struct StudioVelocityLane: View {
    let notes: [StudioNote]
    let selectedNoteId: UUID?
    let color: Color
    let stepLength: Double
    let cellWidth: CGFloat
    let leadingInset: CGFloat
    let height: CGFloat
    let onChanged: () -> Void
    let onEnded: () -> Void

    var body: some View {
        Canvas { context, size in
            let usable = size.height - 8
            for note in notes {
                let x = leadingInset + CGFloat(note.startBeat / stepLength) * cellWidth
                let h = max(2, usable * CGFloat(note.velocity) / 127)
                let isSelected = note.id == selectedNoteId
                let stick = Path(roundedRect: CGRect(x: x, y: size.height - h - 4, width: 3, height: h), cornerRadius: 1.5)
                context.fill(stick, with: .color(isSelected ? DesignSystem.Colors.primaryDark : color.opacity(0.9)))
                let cap = Path(ellipseIn: CGRect(x: x - 2.5, y: size.height - h - 7, width: 8, height: 8))
                context.fill(cap, with: .color(isSelected ? DesignSystem.Colors.primaryDark : color))
            }
        }
        .background(DesignSystem.Colors.surfaceSecondary.opacity(0.6))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    apply(at: value.location)
                    onChanged()
                }
                .onEnded { _ in
                    onEnded()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Velocity lane")
        .accessibilityHint("Drag over a note to change how hard it is played")
    }

    private func apply(at location: CGPoint) {
        let gridX = location.x - leadingInset
        guard gridX >= 0 else { return }
        let beat = Double(gridX / cellWidth) * stepLength
        let tolerance = stepLength * 0.75
        let velocity = Int((1 - min(1, max(0, (location.y - 4) / max(1, height - 8)))) * 126) + 1

        if let selectedNoteId,
           let selected = notes.first(where: { $0.id == selectedNoteId }),
           abs(selected.startBeat - beat) <= tolerance {
            selected.velocity = velocity
            return
        }
        for note in notes where abs(note.startBeat - beat) <= tolerance {
            note.velocity = velocity
        }
    }
}

// MARK: - Note inspector

/// Shapes the selected note: pitch, length, velocity, delete.
struct NoteInspector: View {
    @Bindable var note: StudioNote
    let beatsPerBar: Int
    let timeBottom: Int
    let step: Double
    let maxDuration: Double
    let onDelete: () -> Void
    let onNoteUpdated: () -> Void
    var onDeselect: () -> Void = {}

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 0) {
                Text(StudioMusic.noteName(note.pitch))
                    .font(DesignSystem.Typography.chord)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Bar \(StudioMusic.timecode(beat: note.startBeat, beatsPerBar: beatsPerBar))")
                    .font(DesignSystem.Typography.caption2.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(minWidth: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("Length").eyebrow()
                HStack(spacing: 2) {
                    stepButton("minus", label: "Shorter") {
                        note.duration = max(step, note.duration - step)
                        onNoteUpdated()
                    }
                    Text(StudioGridValue.label(beats: note.duration, timeBottom: timeBottom))
                        .font(DesignSystem.Typography.caption.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(minWidth: 40)
                    stepButton("plus", label: "Longer") {
                        note.duration = min(maxDuration, note.duration + step)
                        onNoteUpdated()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Velocity \(note.velocity)").eyebrow()
                Slider(
                    value: Binding(get: { Double(note.velocity) }, set: { note.velocity = Int($0) }),
                    in: 1...127,
                    step: 1,
                    onEditingChanged: { editing in if !editing { onNoteUpdated() } }
                )
                .tint(DesignSystem.Colors.primary)
                .accessibilityLabel("Velocity")
                .accessibilityValue("\(note.velocity)")
            }

            Button(role: .destructive) {
                onDelete()
                haptic(.light)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.error)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(DesignSystem.Colors.error.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete note")
        }
    }

    private func stepButton(_ icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(DesignSystem.Colors.surfaceSecondary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
