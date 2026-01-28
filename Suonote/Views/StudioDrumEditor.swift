import SwiftUI
import SwiftData

struct StudioDrumEditor: View {
    @Bindable var track: StudioTrack
    let beatsPerBar: Int
    let timeBottom: Int
    let totalBars: Int
    let style: StudioStyle?
    let onNotesChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var copiedBarIndex: Int?

    private let baseCellWidth: CGFloat = 26
    private let cellHeight: CGFloat = 26
    private let cellSpacing: CGFloat = 6
    private let laneSpacing: CGFloat = 10
    private let barRulerHeight: CGFloat = 18
    private let labelColumnWidth: CGFloat = 110

    private var stepsPerBeat: Int {
        timeBottom == 8 ? 2 : 4
    }

    private var stepsPerBar: Int {
        beatsPerBar * stepsPerBeat
    }

    private var totalSteps: Int {
        max(1, totalBars * stepsPerBar)
    }

    private var stepLength: Double {
        1.0 / Double(stepsPerBeat)
    }

    private var gridHeight: CGFloat {
        CGFloat(drumLanes.count) * cellHeight + CGFloat(max(drumLanes.count - 1, 0)) * laneSpacing
    }

    private var notesByPitch: [Int: [Int: StudioNote]] {
        var map: [Int: [Int: StudioNote]] = [:]
        for note in track.notes {
            let step = stepIndex(for: note)
            guard step >= 0 && step < totalSteps else { continue }
            map[note.pitch, default: [:]][step] = note
        }
        return map
    }

    private var drumLanes: [DrumLane] {
        let pitchMap = SoundFontManager.drumPitchMap(for: track.variant)
        return [
            DrumLane(
                name: "Kick",
                pitch: pitchMap.kick,
                color: SectionColor.red.color,
                velocity: DrumVelocityProfile(ghost: 62, normal: 108, accent: 120)
            ),
            DrumLane(
                name: "Snare",
                pitch: pitchMap.snare,
                color: SectionColor.orange.color,
                velocity: DrumVelocityProfile(ghost: 58, normal: 98, accent: 112)
            ),
            DrumLane(
                name: "Rim",
                pitch: pitchMap.rim,
                color: SectionColor.yellow.color,
                velocity: DrumVelocityProfile(ghost: 52, normal: 86, accent: 102)
            ),
            DrumLane(
                name: "Clap",
                pitch: pitchMap.clap,
                color: SectionColor.purple.color,
                velocity: DrumVelocityProfile(ghost: 56, normal: 92, accent: 108)
            ),
            DrumLane(
                name: "Hat Closed",
                pitch: pitchMap.hatClosed,
                color: SectionColor.cyan.color,
                velocity: DrumVelocityProfile(ghost: 48, normal: 72, accent: 88)
            ),
            DrumLane(
                name: "Hat Open",
                pitch: pitchMap.hatOpen,
                color: SectionColor.blue.color,
                velocity: DrumVelocityProfile(ghost: 54, normal: 78, accent: 94)
            ),
            DrumLane(
                name: "Ride",
                pitch: pitchMap.ride,
                color: SectionColor.green.color,
                velocity: DrumVelocityProfile(ghost: 50, normal: 76, accent: 92)
            ),
            DrumLane(
                name: "Crash",
                pitch: pitchMap.crash,
                color: SectionColor.pink.color,
                velocity: DrumVelocityProfile(ghost: 64, normal: 96, accent: 112)
            ),
            DrumLane(
                name: "Tom Low",
                pitch: pitchMap.tomLow,
                color: SectionColor.orange.color,
                velocity: DrumVelocityProfile(ghost: 58, normal: 92, accent: 108)
            ),
            DrumLane(
                name: "Tom Mid",
                pitch: pitchMap.tomMid,
                color: SectionColor.blue.color,
                velocity: DrumVelocityProfile(ghost: 60, normal: 94, accent: 110)
            ),
            DrumLane(
                name: "Tom High",
                pitch: pitchMap.tomHigh,
                color: SectionColor.cyan.color,
                velocity: DrumVelocityProfile(ghost: 62, normal: 96, accent: 112)
            ),
            DrumLane(
                name: "Perc",
                pitch: pitchMap.perc,
                color: SectionColor.green.color,
                velocity: DrumVelocityProfile(ghost: 52, normal: 86, accent: 100)
            )
        ]
    }

    var body: some View {
        let notesByPitch = notesByPitch

        VStack(alignment: .leading, spacing: 12) {
            headerView

            if let style {
                DrumPresetPicker(
                    presets: DrumPreset.presets(
                        for: style,
                        beatsPerBar: beatsPerBar,
                        timeBottom: timeBottom
                    ),
                    selectedPreset: track.drumPreset ?? DrumPreset.defaultPreset(
                        for: style,
                        beatsPerBar: beatsPerBar,
                        timeBottom: timeBottom
                    ),
                    accentColor: style.accentColor,
                    onSelect: { preset in
                        applyPreset(preset, style: style)
                    }
                )
            }

            GeometryReader { geo in
                let availableWidth = max(0, geo.size.width - labelColumnWidth - 12)
                let cellWidth = resolvedCellWidth(availableWidth: availableWidth)
                let gridWidth = gridWidth(for: cellWidth)
                let contentWidth = max(gridWidth, availableWidth)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .trailing, spacing: 8) {
                        Color.clear
                            .frame(height: barRulerHeight)
                        DrumLabelColumn(
                            lanes: drumLanes,
                            rowHeight: cellHeight,
                            rowSpacing: laneSpacing,
                            columnWidth: labelColumnWidth
                        )
                    }
                    .frame(width: labelColumnWidth, alignment: .trailing)

                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            DrumBarRuler(
                                totalBars: totalBars,
                                stepsPerBar: stepsPerBar,
                                cellWidth: cellWidth,
                                cellSpacing: cellSpacing
                            )
                            .frame(width: contentWidth, height: barRulerHeight, alignment: .leading)

                            ZStack(alignment: .topLeading) {
                                DrumGridBackground(
                                    lanes: drumLanes.count,
                                    totalSteps: totalSteps,
                                    stepsPerBeat: stepsPerBeat,
                                    stepsPerBar: stepsPerBar,
                                    cellWidth: cellWidth,
                                    cellHeight: cellHeight,
                                    cellSpacing: cellSpacing,
                                    laneSpacing: laneSpacing
                                )

                                VStack(alignment: .leading, spacing: laneSpacing) {
                                    ForEach(drumLanes) { lane in
                                        DrumLaneRow(
                                            lane: lane,
                                            totalSteps: totalSteps,
                                            stepsPerBeat: stepsPerBeat,
                                            stepsPerBar: stepsPerBar,
                                            cellWidth: cellWidth,
                                            cellHeight: cellHeight,
                                            cellSpacing: cellSpacing,
                                            notesByStep: notesByPitch[lane.pitch] ?? [:],
                                            onToggle: { step in
                                                toggleStep(lane: lane, step: step)
                                            },
                                            onAccent: { step in
                                                cycleVelocity(lane: lane, step: step)
                                            }
                                        )
                                    }
                                }
                            }
                            .frame(width: contentWidth, height: gridHeight, alignment: .topLeading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                }
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(height: gridHeight + barRulerHeight + 8)

            DrumVelocityLegend(color: track.instrument.color)
        }
        .onChange(of: totalBars) { _, newValue in
            if let copiedBarIndex, copiedBarIndex >= newValue {
                self.copiedBarIndex = nil
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
    }

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Drum Groove")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Tap to toggle · Long press for ghost/normal/accent")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(beatsPerBar)/\(timeBottom) · \(stepsPerBeat)x grid")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                HStack(spacing: 8) {
                    Menu {
                        Section("Copy Bar") {
                            ForEach(0..<totalBars, id: \.self) { bar in
                                Button("Copy Bar \(bar + 1)") {
                                    copiedBarIndex = bar
                                }
                            }
                        }

                        Section("Paste To") {
                            ForEach(0..<totalBars, id: \.self) { bar in
                                Button("Paste to Bar \(bar + 1)") {
                                    guard let source = copiedBarIndex else { return }
                                    duplicateBar(from: source, to: bar)
                                }
                                .disabled(copiedBarIndex == nil || copiedBarIndex == bar)
                            }
                        }

                        Section("Paste Everywhere") {
                            Button("Paste to All Bars") {
                                guard let source = copiedBarIndex else { return }
                                duplicateBarToAllBars(from: source)
                            }
                            .disabled(copiedBarIndex == nil || totalBars <= 1)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                            Text(copyLabel)
                        }
                        .font(DesignSystem.Typography.caption)
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

                    Button(role: .destructive) {
                        clearPattern()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("Clear")
                        }
                        .font(DesignSystem.Typography.caption)
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
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stepIndex(for note: StudioNote) -> Int {
        Int((note.startBeat / stepLength).rounded())
    }

    private func gridWidth(for cellWidth: CGFloat) -> CGFloat {
        CGFloat(totalSteps) * cellWidth + CGFloat(max(totalSteps - 1, 0)) * cellSpacing
    }

    private func resolvedCellWidth(availableWidth: CGFloat) -> CGFloat {
        let baseWidth = gridWidth(for: baseCellWidth)
        guard availableWidth > 0, baseWidth < availableWidth else { return baseCellWidth }
        let spacingWidth = CGFloat(max(totalSteps - 1, 0)) * cellSpacing
        let stretched = (availableWidth - spacingWidth) / CGFloat(max(totalSteps, 1))
        return max(baseCellWidth, stretched)
    }

    private func toggleStep(lane: DrumLane, step: Int) {
        let existingNotes = notesAt(pitch: lane.pitch, step: step)
        if !existingNotes.isEmpty {
            for note in existingNotes {
                delete(note)
            }
            return
        }

        addNote(
            pitch: lane.pitch,
            step: step,
            velocity: lane.velocity.normal
        )
    }

    private func cycleVelocity(lane: DrumLane, step: Int) {
        if let note = noteAt(pitch: lane.pitch, step: step) {
            note.velocity = nextVelocity(for: note.velocity, profile: lane.velocity)
            onNotesChanged()
        } else {
            addNote(
                pitch: lane.pitch,
                step: step,
                velocity: lane.velocity.accent
            )
        }
    }

    private func addNote(pitch: Int, step: Int, velocity: Int) {
        let timelineBeats = Double(totalBars * beatsPerBar)
        let startBeat = Double(step) * stepLength
        guard startBeat < timelineBeats else { return }

        removeOverlappingNotes(pitch: pitch, step: step)

        let newNote = StudioNote(
            startBeat: startBeat,
            duration: stepLength,
            pitch: pitch,
            velocity: velocity
        )
        newNote.track = track
        track.notes.append(newNote)
        modelContext.insert(newNote)
        onNotesChanged()
    }

    private func removeOverlappingNotes(pitch: Int, step: Int) {
        let existingNotes = notesAt(pitch: pitch, step: step)
        for note in existingNotes {
            delete(note)
        }
    }

    private func notesAt(pitch: Int, step: Int) -> [StudioNote] {
        track.notes.filter { $0.pitch == pitch && stepIndex(for: $0) == step }
    }

    private func noteAt(pitch: Int, step: Int) -> StudioNote? {
        track.notes.first { $0.pitch == pitch && stepIndex(for: $0) == step }
    }

    private func delete(_ note: StudioNote) {
        if let index = track.notes.firstIndex(where: { $0.id == note.id }) {
            track.notes.remove(at: index)
        }
        modelContext.delete(note)
        onNotesChanged()
    }

    private func clearPattern() {
        replaceNotes(with: [])
    }

    private func applyPreset(_ preset: DrumPreset, style: StudioStyle) {
        track.drumPreset = preset
        let notes = StudioGenerator.generateDrumNotes(
            totalBars: totalBars,
            beatsPerBar: beatsPerBar,
            timeBottom: timeBottom,
            style: style,
            preset: preset,
            variant: track.variant
        )
        replaceNotes(with: notes)
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
        onNotesChanged()
    }

    private func nextVelocity(for current: Int, profile: DrumVelocityProfile) -> Int {
        if current >= profile.accent - 2 {
            return profile.ghost
        }
        if current <= profile.ghost + 4 {
            return profile.normal
        }
        return profile.accent
    }

    private var copyLabel: String {
        if let copiedBarIndex {
            return "Bar \(copiedBarIndex + 1)"
        }
        return "Duplicate"
    }

    private func duplicateBar(from sourceBar: Int, to targetBar: Int, notify: Bool = true) {
        guard sourceBar != targetBar else { return }
        let barLength = Double(beatsPerBar)
        let sourceStart = Double(sourceBar) * barLength
        let sourceEnd = sourceStart + barLength
        let targetStart = Double(targetBar) * barLength
        let targetEnd = targetStart + barLength

        removeNotes(in: targetStart..<targetEnd)

        let sourceNotes = track.notes.filter { note in
            note.startBeat >= sourceStart && note.startBeat < sourceEnd
        }

        for note in sourceNotes {
            let offset = note.startBeat - sourceStart
            let newStart = targetStart + offset
            guard newStart < targetEnd else { continue }
            let duration = min(note.duration, max(0.25, targetEnd - newStart))
            let newNote = StudioNote(
                startBeat: newStart,
                duration: duration,
                pitch: note.pitch,
                velocity: note.velocity
            )
            newNote.track = track
            track.notes.append(newNote)
            modelContext.insert(newNote)
        }

        if notify {
            onNotesChanged()
        }
    }

    private func duplicateBarToAllBars(from sourceBar: Int) {
        guard totalBars > 1 else { return }
        for bar in 0..<totalBars where bar != sourceBar {
            duplicateBar(from: sourceBar, to: bar, notify: false)
        }
        onNotesChanged()
    }

    private func removeNotes(in range: Range<Double>) {
        let toRemove = track.notes.filter { note in
            note.startBeat >= range.lowerBound && note.startBeat < range.upperBound
        }
        guard !toRemove.isEmpty else { return }
        let ids = Set(toRemove.map(\.id))
        for note in toRemove {
            modelContext.delete(note)
        }
        track.notes.removeAll { ids.contains($0.id) }
    }
}

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
        self.id = name
        self.name = name
        self.pitch = pitch
        self.color = color
        self.velocity = velocity
    }
}

struct DrumLabelColumn: View {
    let lanes: [DrumLane]
    let rowHeight: CGFloat
    let rowSpacing: CGFloat
    let columnWidth: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: rowSpacing) {
            ForEach(lanes) { lane in
                HStack(spacing: 8) {
                    Circle()
                        .fill(lane.color)
                        .frame(width: 8, height: 8)
                    Text(lane.name)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                .frame(height: rowHeight)
                .frame(width: columnWidth, alignment: .trailing)
            }
        }
    }
}

struct DrumPresetPicker: View {
    let presets: [DrumPreset]
    let selectedPreset: DrumPreset
    let accentColor: Color
    let onSelect: (DrumPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        Text(preset.title)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(selectedPreset == preset ? DesignSystem.Colors.backgroundSecondary : DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedPreset == preset ? accentColor.opacity(0.85) : DesignSystem.Colors.surfaceSecondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedPreset == preset ? accentColor : DesignSystem.Colors.border,
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DrumBarRuler: View {
    let totalBars: Int
    let stepsPerBar: Int
    let cellWidth: CGFloat
    let cellSpacing: CGFloat

    var body: some View {
        let barWidth = CGFloat(stepsPerBar) * cellWidth + CGFloat(max(stepsPerBar - 1, 0)) * cellSpacing
        HStack(spacing: cellSpacing) {
            ForEach(0..<totalBars, id: \.self) { bar in
                HStack(spacing: 6) {
                    Text("Bar \(bar + 1)")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                }
                .frame(width: barWidth, alignment: .leading)
            }
        }
    }
}

struct DrumGridBackground: View {
    let lanes: Int
    let totalSteps: Int
    let stepsPerBeat: Int
    let stepsPerBar: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let cellSpacing: CGFloat
    let laneSpacing: CGFloat

    var body: some View {
        let width = CGFloat(totalSteps) * cellWidth + CGFloat(max(totalSteps - 1, 0)) * cellSpacing
        let height = CGFloat(lanes) * cellHeight + CGFloat(max(lanes - 1, 0)) * laneSpacing
        let stepStride = cellWidth + cellSpacing
        let beatStride = CGFloat(stepsPerBeat) * stepStride
        let barStride = CGFloat(stepsPerBar) * stepStride

        Canvas { context, size in
            var rowPath = Path()
            for row in 0...lanes {
                let y = CGFloat(row) * (cellHeight + laneSpacing) - (row == lanes ? laneSpacing : 0)
                rowPath.move(to: CGPoint(x: 0, y: y))
                rowPath.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(rowPath, with: .color(DesignSystem.Colors.border.opacity(0.6)), lineWidth: 0.6)

            var beatPath = Path()
            let totalBeats = max(1, totalSteps / max(1, stepsPerBeat))
            for beat in 0...totalBeats {
                let x = CGFloat(beat) * beatStride - (beat == totalBeats ? cellSpacing : 0)
                beatPath.move(to: CGPoint(x: x, y: 0))
                beatPath.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(beatPath, with: .color(DesignSystem.Colors.border.opacity(0.8)), lineWidth: 1)

            var barPath = Path()
            let totalBars = max(1, totalSteps / max(1, stepsPerBar))
            for bar in 0...totalBars {
                var x = CGFloat(bar) * barStride
                if bar == totalBars {
                    x = max(0, x - cellSpacing)
                }
                barPath.move(to: CGPoint(x: x, y: 0))
                barPath.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(barPath, with: .color(DesignSystem.Colors.borderActive), lineWidth: 1.4)
        }
        .frame(width: width, height: height)
    }
}

struct DrumLaneRow: View {
    let lane: DrumLane
    let totalSteps: Int
    let stepsPerBeat: Int
    let stepsPerBar: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let cellSpacing: CGFloat
    let notesByStep: [Int: StudioNote]
    let onToggle: (Int) -> Void
    let onAccent: (Int) -> Void

    var body: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<totalSteps, id: \.self) { step in
                let note = notesByStep[step]
                DrumStepCell(
                    isActive: note != nil,
                    velocity: note?.velocity ?? 0,
                    color: lane.color,
                    isBeatStart: step % stepsPerBeat == 0,
                    isBarStart: step % stepsPerBar == 0
                )
                .frame(width: cellWidth, height: cellHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggle(step)
                }
                .onLongPressGesture(minimumDuration: 0.3) {
                    onAccent(step)
                }
            }
        }
    }
}

struct DrumStepCell: View {
    let isActive: Bool
    let velocity: Int
    let color: Color
    let isBeatStart: Bool
    let isBarStart: Bool

    private var intensity: Double {
        if velocity >= 108 { return 0.95 }
        if velocity <= 64 { return 0.35 }
        return 0.7
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isActive ? color.opacity(intensity) : DesignSystem.Colors.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isActive ? color.opacity(0.85) : DesignSystem.Colors.border.opacity(isBarStart ? 1 : (isBeatStart ? 0.8 : 0.5)),
                        lineWidth: isBarStart ? 1.2 : 0.6
                    )
            )
            .overlay(alignment: .center) {
                if isActive && velocity <= 64 {
                    Circle()
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .frame(width: 4, height: 4)
                }
            }
    }
}

struct DrumVelocityLegend: View {
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            legendItem(title: "Ghost", opacity: 0.35)
            legendItem(title: "Normal", opacity: 0.7)
            legendItem(title: "Accent", opacity: 0.95)
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
