import SwiftUI

struct ChordDiagramView: View {
    let root: String
    let quality: ChordQuality
    let extensions: [String]
    let accentColor: Color
    @State private var selectedInstrument: ChordInstrument = .piano
    
    enum ChordInstrument: String, CaseIterable {
        case piano = "Piano"
        case guitar = "Guitar"
    }
    
    var body: some View {
        let chordNotes = ChordNoteCalculator.notes(
            root: root,
            quality: quality,
            extensions: extensions
        )
        let display = root + quality.symbol + extensions.joined()
        
        VStack(spacing: 20) {
            // Instrument selector
            Picker("Instrument", selection: $selectedInstrument) {
                ForEach(ChordInstrument.allCases, id: \.self) { instrument in
                    Text(instrument.rawValue).tag(instrument)
                }
            }
            .pickerStyle(.segmented)
            .tint(accentColor)
            .padding(.horizontal, 24)
            
            // Diagram
            switch selectedInstrument {
            case .piano:
                PianoChordDiagram(notes: chordNotes, accentColor: accentColor)
            case .guitar:
                GuitarChordDiagram(notes: chordNotes, accentColor: accentColor)
            }
            
            ChordNoteChips(display: display, notes: chordNotes, accentColor: accentColor)
        }
    }
}

// MARK: - Piano Diagram

private struct PianoChordDiagram: View {
    let notes: [String]
    let accentColor: Color
    
    private let whiteKeys = ["C", "D", "E", "F", "G", "A", "B"]
    private let blackKeyPositions = [1, 2, 4, 5, 6] // Positions after C, D, F, G, A
    
    private func isNoteInChord(_ note: String) -> Bool {
        notes.contains(note)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Piano")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            GeometryReader { geometry in
                let keyWidth = geometry.size.width / 7
                let keyHeight = geometry.size.height
                
                ZStack(alignment: .top) {
                    // White keys
                    HStack(spacing: 0) {
                        ForEach(0..<7) { index in
                            let note = whiteKeys[index]
                            let isActive = isNoteInChord(note)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isActive ? accentColor.opacity(0.3) : DesignSystem.Colors.backgroundSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(DesignSystem.Colors.textPrimary.opacity(0.65), lineWidth: 1)
                                )
                                .overlay(
                                    VStack {
                                        Spacer()
                                        if isActive {
                                            Circle()
                                                .fill(accentColor)
                                                .frame(width: 12, height: 12)
                                                .padding(.bottom, 8)
                                        }
                                    }
                                )
                                .frame(width: keyWidth)
                        }
                    }
                    
                    // Black keys
                    HStack(spacing: 0) {
                        ForEach(0..<7) { index in
                            if blackKeyPositions.contains(index + 1) {
                                let blackNote = whiteKeys[index] + "#"
                                let isActive = isNoteInChord(blackNote)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isActive ? accentColor : DesignSystem.Colors.textPrimary)
                                    .frame(width: keyWidth * 0.6, height: keyHeight * 0.6)
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            if isActive {
                                                Circle()
                                                    .fill(DesignSystem.Colors.backgroundSecondary)
                                                    .frame(width: 8, height: 8)
                                                    .padding(.bottom, 6)
                                            }
                                        }
                                    )
                                    .offset(x: keyWidth * 0.7)
                            } else {
                                Spacer()
                                    .frame(width: keyWidth)
                            }
                        }
                    }
                }
            }
            .frame(height: 140)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Guitar Diagram

private struct GuitarChordDiagram: View {
    let notes: [String]
    let accentColor: Color
    
    private var fingerPositions: [Int?] {
        getGuitarFingeringPosition(notes: notes)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Guitar")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: 0) {
                // String markers (X or O)
                HStack(spacing: 0) {
                    ForEach(0..<6) { string in
                        if let pos = fingerPositions[string] {
                            if pos == 0 {
                                Text("O")
                                    .font(.caption)
                                    .foregroundStyle(accentColor)
                            } else {
                                Text("")
                            }
                        } else {
                            Text("X")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.error)
                        }
                        if string < 5 {
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
                
                // Fretboard
                ZStack {
                    // Frets (horizontal lines)
                    VStack(spacing: 0) {
                        ForEach(0..<5) { fret in
                            Rectangle()
                                .fill(DesignSystem.Colors.border)
                                .frame(height: 2)
                            if fret < 4 {
                                Spacer()
                                    .frame(height: 35)
                            }
                        }
                    }
                    
                    // Strings (vertical lines)
                    HStack(spacing: 0) {
                        ForEach(0..<6) { string in
                            Rectangle()
                                .fill(DesignSystem.Colors.borderActive)
                                .frame(width: 1.5)
                            if string < 5 {
                                Spacer()
                            }
                        }
                    }
                    
                    // Finger positions
                    HStack(spacing: 0) {
                        ForEach(0..<6) { string in
                            VStack(spacing: 0) {
                                if let position = fingerPositions[string], position > 0 {
                                    Spacer()
                                        .frame(height: CGFloat(position - 1) * 37.5 + 10)
                                    
                                    Circle()
                                        .fill(accentColor)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(DesignSystem.Colors.backgroundSecondary, lineWidth: 2)
                                        )
                                    
                                    Spacer()
                                } else {
                                    Spacer()
                                }
                            }
                            if string < 5 {
                                Spacer()
                            }
                        }
                    }
                }
                .frame(height: 150)
                .padding(.horizontal, 40)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
        }
    }
    
    private func getGuitarFingeringPosition(notes: [String]) -> [Int?] {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let tuning = ["E", "A", "D", "G", "B", "E"] // Low E to high E
        let noteSet = Set(notes)
        let maxFret = 4

        func noteIndex(_ name: String) -> Int? {
            noteNames.firstIndex(of: name)
        }

        return tuning.compactMap { openNote in
            guard let openIndex = noteIndex(openNote) else { return nil }
            for fret in 0...maxFret {
                let note = noteNames[(openIndex + fret) % 12]
                if noteSet.contains(note) {
                    return fret
                }
            }
            return nil
        }
    }
}

private struct ChordNoteChips: View {
    let display: String
    let notes: [String]
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(display)
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.25))
                        .overlay(
                            Capsule()
                                .stroke(accentColor.opacity(0.5), lineWidth: 1)
                        )
                )
            
            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.25))
                            .overlay(Capsule().stroke(accentColor, lineWidth: 1))
                    )
            }
        }
    }
}

private enum ChordNoteCalculator {
    static func notes(root: String, quality: ChordQuality, extensions: [String]) -> [String] {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        guard let rootIndex = noteNames.firstIndex(of: root) else { return [] }
        
        var intervals = Set(baseIntervals(for: quality))
        
        if extensions.contains("sus2") {
            intervals.remove(3)
            intervals.remove(4)
            intervals.insert(2)
        }
        
        if extensions.contains("sus4") {
            intervals.remove(3)
            intervals.remove(4)
            intervals.insert(5)
        }
        
        for ext in extensions {
            switch ext {
            case "7":
                intervals.insert(10)
            case "9":
                intervals.insert(14)
            case "11":
                intervals.insert(17)
            case "13":
                intervals.insert(21)
            case "add9":
                intervals.insert(14)
            default:
                break
            }
        }
        
        return intervals
            .sorted()
            .map { noteNames[(rootIndex + $0) % 12] }
    }
    
    private static func baseIntervals(for quality: ChordQuality) -> [Int] {
        // Use the intervals property from ChordQuality
        return quality.intervals
    }
}

#Preview {
    ChordDiagramView(root: "C", quality: .major, extensions: [], accentColor: DesignSystem.Colors.primary)
        
    .background(DesignSystem.Colors.background)
}
