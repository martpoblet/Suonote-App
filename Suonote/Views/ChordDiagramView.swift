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
                GuitarChordDiagram(root: root, quality: quality, accentColor: accentColor)
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
                .foregroundStyle(.secondary)
            
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
                                .fill(isActive ? accentColor.opacity(0.3) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.black, lineWidth: 1)
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
                                    .fill(isActive ? accentColor : Color.black)
                                    .frame(width: keyWidth * 0.6, height: keyHeight * 0.6)
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            if isActive {
                                                Circle()
                                                    .fill(Color.white)
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
    let root: String
    let quality: ChordQuality
    let accentColor: Color
    
    private var fingerPositions: [Int?] {
        getGuitarFingeringPosition(root: root, quality: quality)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Guitar")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
            
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
                                .foregroundStyle(.red)
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
                                .fill(Color.white.opacity(0.3))
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
                                .fill(Color.white.opacity(0.5))
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
                                                .stroke(Color.white, lineWidth: 2)
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
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
        }
    }
    
    private func getGuitarFingeringPosition(root: String, quality: ChordQuality) -> [Int?] {
        // Simple guitar chord shapes (strings from low E to high E)
        // nil = don't play, 0 = open, 1-4 = fret number
        
        let chordShapes: [String: [String: [Int?]]] = [
            "C": [
                "major": [nil, 3, 2, 0, 1, 0],
                "minor": [nil, 3, 1, 0, 1, 3]
            ],
            "D": [
                "major": [nil, nil, 0, 2, 3, 2],
                "minor": [nil, nil, 0, 2, 3, 1]
            ],
            "E": [
                "major": [0, 2, 2, 1, 0, 0],
                "minor": [0, 2, 2, 0, 0, 0]
            ],
            "F": [
                "major": [1, 3, 3, 2, 1, 1],
                "minor": [1, 3, 3, 1, 1, 1]
            ],
            "G": [
                "major": [3, 2, 0, 0, 0, 3],
                "minor": [3, 5, 5, 3, 3, 3]
            ],
            "A": [
                "major": [nil, 0, 2, 2, 2, 0],
                "minor": [nil, 0, 2, 2, 1, 0]
            ],
            "B": [
                "major": [nil, 2, 4, 4, 4, 2],
                "minor": [nil, 2, 4, 4, 3, 2]
            ]
        ]
        
        let qualityKey: String
        switch quality {
        case .major:
            qualityKey = "major"
        case .minor:
            qualityKey = "minor"
        case .diminished, .augmented, .dominant7, .major7, .minor7, .sus2, .sus4, 
             .minorMajor7, .diminished7, .halfDiminished7, .augmented7, 
             .dominant9, .major9, .minor9:
            // For other qualities, default to major shape
            qualityKey = "major"
        }
        
        if let shapes = chordShapes[root], let shape = shapes[qualityKey] {
            return shape
        }
        
        // Default shape if not found
        return [nil, nil, nil, nil, nil, nil]
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
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.8), accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            
            ForEach(notes, id: \.self) { note in
                Text(note)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.white)
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
    ChordDiagramView(root: "C", quality: .major, extensions: [], accentColor: .purple)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
