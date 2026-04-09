import Foundation
import SwiftUI

// MARK: - Melody Sketch Engine (M1 + M3)
// Provides scale-aware melodic note editing, motif storage, and degree labeling.

struct MelodyNote: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var pitchIndex: Int          // 0 = root, 1 = 2nd degree, etc. (scale degree index)
    var beatPosition: Double     // position within the section (in beats)
    var duration: Double         // duration in beats (0.25, 0.5, 1.0, 2.0)
    var velocity: Int            // 0–127 MIDI velocity
    var octave: Int              // octave offset from middle (0 = middle, -1 = lower, +1 = higher)
}

struct Motif: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var notes: [MelodyNote]
    var sourceKeyRoot: String    // key it was created in
    var sourceKeyMode: String    // mode it was created in
    var createdAt: Date = Date()

    /// Duration of the full motif in beats
    var totalBeats: Double {
        guard !notes.isEmpty else { return 0 }
        let last = notes.max(by: { $0.beatPosition < $1.beatPosition })!
        return last.beatPosition + last.duration
    }
}

struct MelodySketchEngine {

    // MARK: - Scale notes for a key/mode

    /// Returns the note names for all scale degrees in a key/mode (1 octave)
    static func scaleNotes(keyRoot: String, mode: KeyMode) -> [String] {
        guard let rootIdx = MusicTheory.noteIndex(keyRoot) else { return [] }
        return mode.intervals.map { interval in
            MusicTheory.chromaticScale[(rootIdx + interval) % 12]
        }
    }

    /// Returns degree labels for scale positions ("1", "2", "3" etc.)
    static func degreeLabels(for mode: KeyMode) -> [String] {
        switch mode {
        case .major, .lydian, .mixolydian:
            return ["1", "2", "3", "4", "5", "6", "7"]
        case .minor, .aeolian, .dorian, .phrygian, .locrian,
             .harmonicMinor, .melodicMinor:
            return ["1", "2", "♭3", "4", "5", "♭6", "7"]
        case .pentatonicMajor:
            return ["1", "2", "3", "5", "6"]
        case .pentatonicMinor:
            return ["1", "♭3", "4", "5", "♭7"]
        case .blues:
            return ["1", "♭3", "4", "♯4", "5", "♭7"]
        }
    }

    /// Returns the interval role label for a scale degree (e.g., "Root", "Major 3rd")
    static func intervalRole(degreeIndex: Int, mode: KeyMode) -> String {
        let intervals = mode.intervals
        guard degreeIndex < intervals.count else { return "" }
        let semitones = intervals[degreeIndex]
        let names = [
            0: "Root", 1: "♭2nd", 2: "Major 2nd", 3: "Minor 3rd",
            4: "Major 3rd", 5: "Perfect 4th", 6: "Tritone",
            7: "Perfect 5th", 8: "Minor 6th", 9: "Major 6th",
            10: "Minor 7th", 11: "Major 7th"
        ]
        return names[semitones] ?? ""
    }

    // MARK: - Tension scoring for individual notes

    /// Returns a tension score 0.0–1.0 for a scale degree index
    static func tensionScore(for degreeIndex: Int, mode: KeyMode) -> Double {
        let intervals = mode.intervals
        guard degreeIndex < intervals.count else { return 0.5 }
        let semitones = intervals[degreeIndex]
        // Tension by interval: root/5th = 0, 3rd = 0.2, 2nd/6th = 0.4, 4th = 0.5, 7th = 0.7, tritone = 1.0
        switch semitones {
        case 0: return 0.0   // Root – stable
        case 7: return 0.05  // Perfect 5th – very stable
        case 4, 3: return 0.2  // Major/minor 3rd – consonant
        case 9, 8: return 0.35 // 6th – mild
        case 2: return 0.5   // Major 2nd – tension
        case 5: return 0.55  // Perfect 4th – mild tension
        case 10, 11: return 0.7  // Minor/Major 7th – needs resolution
        case 1: return 0.85  // Minor 2nd – strong tension
        case 6: return 1.0   // Tritone – maximum tension
        default: return 0.5
        }
    }

    // MARK: - Transpose motif to a new key

    /// Transposes a motif's notes from one key to another (preserves scale degree relationships)
    static func transpose(motif: Motif, toKeyRoot: String, toMode: KeyMode) -> Motif {
        // Since notes are stored as scale degree indices, no pitch recalculation needed —
        // just update the source key metadata. The view renders notes using the new key's scale.
        var transposed = motif
        transposed.id = UUID()
        transposed.name = motif.name + " (transposed)"
        transposed.sourceKeyRoot = toKeyRoot
        transposed.sourceKeyMode = toMode.rawValue
        return transposed
    }

    // MARK: - Beat grid helpers

    /// Available note durations (in beats)
    static let availableDurations: [(label: String, beats: Double)] = [
        ("1/16", 0.25), ("1/8", 0.5), ("1/4", 1.0),
        ("1/2", 2.0), ("Whole", 4.0)
    ]

    /// Snaps a beat position to the nearest subdivision
    static func snap(_ beat: Double, to subdivision: Double = 0.25) -> Double {
        (beat / subdivision).rounded() * subdivision
    }

    // MARK: - MIDI pitch for a melody note

    /// Converts a melody note to a MIDI pitch number
    static func midiPitch(for note: MelodyNote, keyRoot: String, mode: KeyMode, baseOctave: Int = 4) -> Int {
        let scale = scaleNotes(keyRoot: keyRoot, mode: mode)
        guard note.pitchIndex < scale.count else { return 60 }
        let noteName = scale[note.pitchIndex]
        guard let noteIdx = MusicTheory.noteIndex(noteName) else { return 60 }
        let octave = baseOctave + note.octave
        return (octave + 1) * 12 + noteIdx
    }
}

// MARK: - Melody Sketch View (M1)

struct MelodySketchView: View {
    @Bindable var section: SectionTemplate
    @State private var notes: [MelodyNote] = []
    @State private var selectedDuration: Double = 1.0
    @State private var currentOctave: Int = 0
    @State private var showMotifSaver = false
    @State private var motifName = ""
    @State private var savedMotifs: [Motif] = []
    @State private var showMotifLibrary = false
    @State private var playingNote: Int? = nil

    private var keyRoot: String { section.effectiveKeyRoot }
    private var mode: KeyMode { section.effectiveKeyMode }

    private var scaleNotes: [String] { MelodySketchEngine.scaleNotes(keyRoot: keyRoot, mode: mode) }
    private var degreeLabels: [String] { MelodySketchEngine.degreeLabels(for: mode) }

    private let rowHeight: CGFloat = 44
    private let beatWidth: CGFloat = 72
    private var totalBars: Int { max(section.bars, 1) }
    private var beatsPerBar: Int { section.project?.timeTop ?? 4 }
    private var totalBeats: Double { Double(totalBars * beatsPerBar) }

    var body: some View {
        VStack(spacing: 0) {
            // Header controls
            headerControls
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)

            Divider().overlay(DesignSystem.Colors.border)

            // Piano-roll style grid
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Grid background
                    gridBackground
                    // Notes layer
                    notesLayer
                }
                .frame(
                    width: CGFloat(totalBeats) * beatWidth + 60,
                    height: CGFloat(scaleNotes.count) * rowHeight + 32
                )
            }
            .background(DesignSystem.Colors.backgroundSecondary)

            Divider().overlay(DesignSystem.Colors.border)

            // Bottom toolbar
            bottomToolbar
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .onAppear { loadNotes() }
        .sheet(isPresented: $showMotifSaver) { motifSaverSheet }
        .sheet(isPresented: $showMotifLibrary) { motifLibrarySheet }
    }

    // MARK: - Header Controls

    private var headerControls: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Key info
            Label("\(keyRoot) \(mode.rawValue)", systemImage: "music.note")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.primary)

            Spacer()

            // Duration picker
            HStack(spacing: 4) {
                ForEach(MelodySketchEngine.availableDurations, id: \.beats) { dur in
                    Button(dur.label) {
                        selectedDuration = dur.beats
                    }
                    .font(DesignSystem.Typography.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedDuration == dur.beats ?
                                  DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                    )
                    .foregroundStyle(selectedDuration == dur.beats ?
                                     .white : DesignSystem.Colors.textPrimary)
                }
            }

            // Octave controls
            HStack(spacing: 2) {
                Button { currentOctave = max(-2, currentOctave - 1) } label: {
                    Image(systemName: "chevron.down")
                        .font(DesignSystem.Typography.caption2)
                }
                Text("Oct \(currentOctave >= 0 ? "+" : "")\(currentOctave)")
                    .font(DesignSystem.Typography.caption2)
                Button { currentOctave = min(2, currentOctave + 1) } label: {
                    Image(systemName: "chevron.up")
                        .font(DesignSystem.Typography.caption2)
                }
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Grid Background

    private var gridBackground: some View {
        Canvas { ctx, size in
            let rowH = rowHeight
            let beatW = beatWidth
            let noteCount = scaleNotes.count
            let offsetX: CGFloat = 60

            // Row backgrounds alternating
            for row in 0..<noteCount {
                let rect = CGRect(x: offsetX, y: CGFloat(row) * rowH + 32,
                                  width: size.width - offsetX, height: rowH)
                let tension = MelodySketchEngine.tensionScore(
                    for: noteCount - 1 - row, mode: mode)
                let fillColor = Color.white.opacity(0.95 - tension * 0.15)
                ctx.fill(Path(rect), with: .color(fillColor))
            }

            // Row label area
            for row in 0..<noteCount {
                let y = CGFloat(row) * rowH + 32
                let rect = CGRect(x: 0, y: y, width: offsetX, height: rowH)
                ctx.fill(Path(rect), with: .color(DesignSystem.Colors.backgroundTertiary))

                // Divider line
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(DesignSystem.Colors.border.opacity(0.6)), lineWidth: 0.5)
            }

            // Beat lines
            var beat = 0.0
            var barCount = 0
            while beat <= totalBeats {
                let x = offsetX + CGFloat(beat) * beatW
                var vLine = Path()
                vLine.move(to: CGPoint(x: x, y: 32))
                vLine.addLine(to: CGPoint(x: x, y: size.height))
                let isBarLine = beat == Double(barCount * beatsPerBar)
                ctx.stroke(vLine, with: .color(isBarLine ?
                    DesignSystem.Colors.border : DesignSystem.Colors.borderSubtle),
                           lineWidth: isBarLine ? 1.0 : 0.5)
                if beat == Double(barCount * beatsPerBar) { barCount += 1 }
                beat += 1
            }

            // Header bar numbers
            for bar in 0..<totalBars {
                let x = offsetX + CGFloat(bar * beatsPerBar) * beatW + 4
                // Can't draw text easily in Canvas without resolved text, but we'll add an overlay
            }
        }
        .overlay(alignment: .topLeading) {
            // Row labels overlay
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Color.clear.frame(width: 60, height: 32)
                    ForEach(0..<totalBars, id: \.self) { bar in
                        Text("Bar \(bar + 1)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .frame(width: CGFloat(beatsPerBar) * beatWidth, height: 32)
                    }
                }

                ForEach(Array(scaleNotes.enumerated().reversed()), id: \.offset) { idx, noteName in
                    HStack(spacing: 0) {
                        // Note label
                        VStack(spacing: 1) {
                            Text(noteName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                            if idx < degreeLabels.count {
                                Text(degreeLabels[idx])
                                    .font(.system(size: 9))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 60, height: rowHeight)
                        .background(DesignSystem.Colors.backgroundTertiary)

                        // Tap area for this row
                        Color.clear
                            .frame(width: CGFloat(totalBeats) * beatWidth, height: rowHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let beat = MelodySketchEngine.snap(
                                    Double(location.x) / Double(beatWidth), to: selectedDuration)
                                addNote(pitchIndex: idx, beat: beat)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Notes Layer

    private var notesLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(notes) { note in
                let row = scaleNotes.count - 1 - note.pitchIndex
                let x = 60 + CGFloat(note.beatPosition) * beatWidth
                let y = 32 + CGFloat(row) * rowHeight + 4
                let w = CGFloat(note.duration) * beatWidth - 3
                let h = rowHeight - 8

                RoundedRectangle(cornerRadius: 5)
                    .fill(noteColor(for: note))
                    .frame(width: max(w, 8), height: h)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .offset(x: x, y: y)
                    .onTapGesture { removeNote(id: note.id) }
            }
        }
    }

    private func noteColor(for note: MelodyNote) -> Color {
        let tension = MelodySketchEngine.tensionScore(for: note.pitchIndex, mode: mode)
        let hue = 0.5 - tension * 0.3   // teal → purple as tension increases
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Button {
                notes.removeAll()
                saveNotes()
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.error)
            }

            Spacer()

            Text("\(notes.count) note\(notes.count == 1 ? "" : "s")")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            Button {
                motifName = section.name + " Motif"
                showMotifSaver = true
            } label: {
                Label("Save Motif", systemImage: "bookmark")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
            .disabled(notes.isEmpty)

            Button {
                showMotifLibrary = true
            } label: {
                Image(systemName: "music.note.list")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
        }
    }

    // MARK: - Motif Saver Sheet

    private var motifSaverSheet: some View {
        NavigationStack {
            Form {
                Section("Motif Name") {
                    TextField("Name", text: $motifName)
                }
                Section("Preview") {
                    Text("\(notes.count) notes in \(keyRoot) \(mode.rawValue)")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .navigationTitle("Save Motif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showMotifSaver = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let motif = Motif(
                            name: motifName.isEmpty ? "Motif" : motifName,
                            notes: notes,
                            sourceKeyRoot: keyRoot,
                            sourceKeyMode: mode.rawValue
                        )
                        savedMotifs.append(motif)
                        saveMotifs()
                        showMotifSaver = false
                    }
                }
            }
        }
    }

    // MARK: - Motif Library Sheet

    private var motifLibrarySheet: some View {
        NavigationStack {
            Group {
                if savedMotifs.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "music.note.list")
                            .font(DesignSystem.Typography.display)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text("No saved motifs yet")
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(savedMotifs) { motif in
                            Button {
                                loadMotif(motif)
                                showMotifLibrary = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(motif.name)
                                        .font(DesignSystem.Typography.bodyBold)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Text("\(motif.notes.count) notes · \(motif.sourceKeyRoot) \(motif.sourceKeyMode)")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            savedMotifs.remove(atOffsets: indexSet)
                            saveMotifs()
                        }
                    }
                }
            }
            .navigationTitle("Motif Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showMotifLibrary = false }
                }
            }
        }
    }

    // MARK: - Data helpers

    private func addNote(pitchIndex: Int, beat: Double) {
        guard beat < totalBeats else { return }
        // Avoid overlap on same pitch
        let overlapping = notes.filter {
            $0.pitchIndex == pitchIndex &&
            $0.beatPosition < beat + selectedDuration &&
            $0.beatPosition + $0.duration > beat
        }
        if !overlapping.isEmpty { return }
        let note = MelodyNote(
            pitchIndex: pitchIndex,
            beatPosition: beat,
            duration: selectedDuration,
            velocity: 80,
            octave: currentOctave
        )
        notes.append(note)
        saveNotes()
        HapticFeedback.selection()
    }

    private func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
        saveNotes()
        HapticFeedback.selection()
    }

    private func loadMotif(_ motif: Motif) {
        let transposed = MelodySketchEngine.transpose(motif: motif, toKeyRoot: keyRoot, toMode: mode)
        notes = transposed.notes
        saveNotes()
    }

    // MARK: - Persistence (UserDefaults keyed by section id)

    private var notesKey: String { "melody_notes_\(section.id)" }
    private var motifsKey: String { "melody_motifs" }

    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([MelodyNote].self, from: data) {
            notes = decoded
        }
        if let data = UserDefaults.standard.data(forKey: motifsKey),
           let decoded = try? JSONDecoder().decode([Motif].self, from: data) {
            savedMotifs = decoded
        }
    }

    private func saveMotifs() {
        if let data = try? JSONEncoder().encode(savedMotifs) {
            UserDefaults.standard.set(data, forKey: motifsKey)
        }
    }
}
