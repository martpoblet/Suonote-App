import Foundation

// MARK: - Music Theory Utilities

struct NoteUtils {
    
    /// All 12 chromatic notes in Western music
    static let chromaticScale = MusicTheory.chromaticScale
    
    /// Transpose a note by a given number of semitones
    static func transpose(note: String, semitones: Int) -> String {
        ChordSuggestionEngine.transpose(note: note, semitones: semitones)
    }
    
    /// Calculate the interval (in semitones) between two notes
    static func intervalBetween(from: String, to: String) -> Int {
        ChordSuggestionEngine.intervalBetween(from: from, to: to)
    }
    
    /// Get all notes in a specific scale
    static func scaleNotes(root: String, scaleType: ScaleType) -> [String] {
        guard let rootIndex = chromaticScale.firstIndex(of: root) else { return [] }
        
        return scaleType.intervals.map { interval in
            chromaticScale[(rootIndex + interval) % 12]
        }
    }
    
    /// Check if a note is in a specific scale
    static func isInScale(note: String, root: String, scaleType: ScaleType) -> Bool {
        let scaleNotes = scaleNotes(root: root, scaleType: scaleType)
        return scaleNotes.contains(note)
    }
    
    /// Get the enharmonic equivalent of a note (e.g., C# = Db)
    static func enharmonic(of note: String) -> String? {
        let enharmonics: [String: String] = [
            "C#": "Db", "Db": "C#",
            "D#": "Eb", "Eb": "D#",
            "F#": "Gb", "Gb": "F#",
            "G#": "Ab", "Ab": "G#",
            "A#": "Bb", "Bb": "A#"
        ]
        return enharmonics[note]
    }
}

// MARK: - Scale Types

enum ScaleType {
    case major
    case naturalMinor
    case harmonicMinor
    case melodicMinor
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case aeolian
    case locrian
    case pentatonicMajor
    case pentatonicMinor
    case blues
    
    var intervals: [Int] {
        switch self {
        case .major:
            return MusicTheory.ScaleFormula.major
        case .naturalMinor, .aeolian:
            return MusicTheory.ScaleFormula.naturalMinor
        case .harmonicMinor:
            return MusicTheory.ScaleFormula.harmonicMinor
        case .melodicMinor:
            return MusicTheory.ScaleFormula.melodicMinor
        case .dorian:
            return MusicTheory.ScaleFormula.dorian
        case .phrygian:
            return [0, 1, 3, 5, 7, 8, 10]
        case .lydian:
            return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian:
            return MusicTheory.ScaleFormula.mixolydian
        case .locrian:
            return [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor:
            return [0, 2, 4, 7, 9]
        case .pentatonicMinor:
            return [0, 3, 5, 7, 10]
        case .blues:
            return [0, 3, 5, 6, 7, 10]
        }
    }
    
    var displayName: String {
        switch self {
        case .major: return "Major"
        case .naturalMinor: return "Natural Minor"
        case .harmonicMinor: return "Harmonic Minor"
        case .melodicMinor: return "Melodic Minor"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .aeolian: return "Aeolian"
        case .locrian: return "Locrian"
        case .pentatonicMajor: return "Pentatonic Major"
        case .pentatonicMinor: return "Pentatonic Minor"
        case .blues: return "Blues"
        }
    }
}

// MARK: - Rhythm Utilities

struct RhythmUtils {
    
    /// Convert beats to musical notation
    static func beatsToNotation(beats: Double) -> String {
        switch beats {
        case 0.25: return "16th note"
        case 0.5: return "8th note"
        case 1.0: return "Quarter note"
        case 1.5: return "Dotted quarter"
        case 2.0: return "Half note"
        case 3.0: return "Dotted half"
        case 4.0: return "Whole note"
        default: return "\(beats) beats"
        }
    }
    
    /// Calculate the duration in seconds for a given number of beats
    static func beatsToSeconds(beats: Double, bpm: Int) -> Double {
        let secondsPerBeat = 60.0 / Double(bpm)
        return beats * secondsPerBeat
    }
    
    /// Calculate how many beats fit in a given time duration
    static func secondsToBeats(seconds: Double, bpm: Int) -> Double {
        let secondsPerBeat = 60.0 / Double(bpm)
        return seconds / secondsPerBeat
    }
    
    /// Quantize beats to the nearest subdivision
    static func quantize(beats: Double, subdivision: Double = 0.25) -> Double {
        return (beats / subdivision).rounded() * subdivision
    }
}

// MARK: - Chord Utilities

struct ChordUtils {
    
    /// Get the notes that make up a chord
    static func getChordNotes(root: String, quality: ChordQuality) -> [String] {
        guard let rootIndex = NoteUtils.chromaticScale.firstIndex(of: root) else { return [] }
        
        return quality.intervals.map { interval in
            NoteUtils.chromaticScale[(rootIndex + interval) % 12]
        }
    }
    
    /// Check if a chord contains a specific note
    static func chordContains(root: String, quality: ChordQuality, note: String) -> Bool {
        let chordNotes = getChordNotes(root: root, quality: quality)
        return chordNotes.contains(note)
    }
    
    /// Find common notes between two chords
    static func commonNotes(chord1Root: String, chord1Quality: ChordQuality,
                           chord2Root: String, chord2Quality: ChordQuality) -> [String] {
        let notes1 = Set(getChordNotes(root: chord1Root, quality: chord1Quality))
        let notes2 = Set(getChordNotes(root: chord2Root, quality: chord2Quality))
        return Array(notes1.intersection(notes2))
    }
    
    /// Calculate voice leading distance between two chords
    static func voiceLeadingDistance(from chord1: (root: String, quality: ChordQuality),
                                    to chord2: (root: String, quality: ChordQuality)) -> Int {
        let commonCount = commonNotes(chord1Root: chord1.root, chord1Quality: chord1.quality,
                                     chord2Root: chord2.root, chord2Quality: chord2.quality).count
        
        let totalNotes = max(chord1.quality.intervals.count, chord2.quality.intervals.count)
        return totalNotes - commonCount
    }
}

// MARK: - BPM & Tempo Utilities

struct TempoUtils {
    
    /// Common tempo markings
    enum TempoMarking: String, CaseIterable {
        case largo = "Largo (40-60)"
        case adagio = "Adagio (66-76)"
        case andante = "Andante (76-108)"
        case moderato = "Moderato (108-120)"
        case allegro = "Allegro (120-168)"
        case presto = "Presto (168-200)"
        
        var bpmRange: ClosedRange<Int> {
            switch self {
            case .largo: return 40...60
            case .adagio: return 66...76
            case .andante: return 76...108
            case .moderato: return 108...120
            case .allegro: return 120...168
            case .presto: return 168...200
            }
        }
        
        static func marking(for bpm: Int) -> TempoMarking? {
            allCases.first { $0.bpmRange.contains(bpm) }
        }
    }
    
    /// Get a descriptive tempo name for a BPM value
    static func tempoDescription(for bpm: Int) -> String {
        if let marking = TempoMarking.marking(for: bpm) {
            return marking.rawValue
        } else if bpm < 40 {
            return "Very Slow"
        } else {
            return "Very Fast"
        }
    }
    
    /// Calculate the duration of one bar in seconds
    static func barDuration(bpm: Int, timeSignatureTop: Int) -> Double {
        let secondsPerBeat = 60.0 / Double(bpm)
        return secondsPerBeat * Double(timeSignatureTop)
    }
}
