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
    
    // MARK: - Roman Numeral Analysis (M-04)
    
    /// Returns the Roman numeral for a chord in a given key/mode
    static func romanNumeral(root: String, quality: ChordQuality, keyRoot: String, mode: KeyMode) -> String {
        let interval = ChordSuggestionEngine.intervalBetween(from: keyRoot, to: root)
        let scaleIntervals = mode.intervals
        
        guard let degreeIndex = scaleIntervals.firstIndex(of: interval) else {
            // Chromatic / non-diatonic chord
            let semitoneToRoman = ["I", "♭II", "II", "♭III", "III", "IV", "♯IV/♭V", "V", "♭VI", "VI", "♭VII", "VII"]
            let base = semitoneToRoman[interval % 12]
            return quality.isMinor ? base.lowercased() : base
        }
        
        let romanNumerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        let base = romanNumerals[degreeIndex]
        let numeral = quality.isMinor ? base.lowercased() : base
        
        switch quality {
        case .diminished, .diminished7: return numeral + "°"
        case .halfDiminished7: return numeral + "ø"
        case .augmented, .augmented7: return numeral + "+"
        case .dominant7: return numeral + "7"
        case .major7: return numeral + "Δ7"
        case .minor7: return numeral + "7"
        case .sus2: return numeral + "sus2"
        case .sus4: return numeral + "sus4"
        default: return numeral
        }
    }
    
    // MARK: - Nashville Number System (M-06)
    
    /// Returns the Nashville number for a chord in a given key
    static func nashvilleNumber(root: String, quality: ChordQuality, keyRoot: String) -> String {
        let interval = ChordSuggestionEngine.intervalBetween(from: keyRoot, to: root)
        let majorIntervals = [0, 2, 4, 5, 7, 9, 11]
        
        guard let degreeIndex = majorIntervals.firstIndex(of: interval) else {
            let flatDegrees = [1: "♭2", 3: "♭3", 6: "♭5", 8: "♭6", 10: "♭7"]
            let num = flatDegrees[interval] ?? "\(interval)"
            return quality.isMinor ? "-\(num)" : num
        }
        
        let number = "\(degreeIndex + 1)"
        var suffix = ""
        if quality.isMinor { suffix = "-" }
        if quality == .diminished || quality == .diminished7 { suffix = "°" }
        if quality == .augmented { suffix = "+" }
        if quality == .dominant7 { suffix += "7" }
        if quality == .major7 { suffix += "Δ" }
        
        return suffix.isEmpty ? number : "\(number)\(suffix)"
    }
    
    // MARK: - Auto Key Detection (M-05)
    
    /// Detect the most likely key/mode from a list of chord roots and qualities
    static func detectKey(chords: [(root: String, quality: ChordQuality)]) -> (root: String, mode: KeyMode, confidence: Double)? {
        guard !chords.isEmpty else { return nil }
        
        let roots = MusicTheory.chromaticScale
        let modes: [KeyMode] = [.major, .minor, .dorian, .mixolydian]
        
        var bestMatch: (root: String, mode: KeyMode, score: Double) = ("C", .major, 0)
        
        for root in roots {
            let rootIdx = MusicTheory.noteIndex(root)
            guard let ri = rootIdx else { continue }
            
            for mode in modes {
                let scaleNotes = Set(mode.intervals.map { (ri + $0) % 12 })
                var score = 0.0
                
                for chord in chords {
                    guard let chordIdx = MusicTheory.noteIndex(chord.root) else { continue }
                    if scaleNotes.contains(chordIdx) {
                        score += 1.0
                        // Bonus for tonic chord
                        if chordIdx == ri { score += 0.5 }
                        // Bonus for V chord
                        if (chordIdx - ri + 12) % 12 == 7 { score += 0.3 }
                    }
                }
                
                if score > bestMatch.score {
                    bestMatch = (root, mode, score)
                }
            }
        }
        
        let maxScore = Double(chords.count) * 1.8
        let confidence = min(bestMatch.score / maxScore, 1.0)
        return (bestMatch.root, bestMatch.mode, confidence)
    }
}
