import Foundation

// MARK: - Music Theory Constants

enum MusicTheory {
    static let chromaticScale = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    /// Maps flat note names to their sharp equivalents for lookup
    static let flatToSharp: [String: String] = [
        "Db": "C#", "Eb": "D#", "Fb": "E", "Gb": "F#",
        "Ab": "G#", "Bb": "A#", "Cb": "B"
    ]
    
    /// Maps sharp note names to their preferred flat equivalents for display
    static let sharpToFlat: [String: String] = [
        "C#": "Db", "D#": "Eb", "F#": "Gb", "G#": "Ab", "A#": "Bb"
    ]
    
    /// Keys that conventionally use flats
    static let flatKeys: Set<String> = ["F", "Bb", "Eb", "Ab", "Db", "Gb",
                                         "Dm", "Gm", "Cm", "Fm", "Bbm", "Ebm"]
    
    /// Normalize any note name (flat or sharp) to its chromatic scale index
    static func noteIndex(_ note: String) -> Int? {
        if let idx = chromaticScale.firstIndex(of: note) { return idx }
        if let sharp = flatToSharp[note] { return chromaticScale.firstIndex(of: sharp) }
        return nil
    }
    
    /// Normalize a note name to its sharp equivalent for internal use
    static func normalize(_ note: String) -> String {
        flatToSharp[note] ?? note
    }
    
    /// Get the display name for a note in a given key context (sharp or flat)
    static func displayName(for note: String, inKey root: String, mode: KeyMode? = nil) -> String {
        let keyId = root + (mode == .minor ? "m" : "")
        if flatKeys.contains(keyId) || flatKeys.contains(root) {
            let normalized = normalize(note)
            return sharpToFlat[normalized] ?? normalized
        }
        return normalize(note)
    }
    
    // Intervals in semitones
    enum Interval: Int {
        case unison = 0
        case minorSecond = 1
        case majorSecond = 2
        case minorThird = 3
        case majorThird = 4
        case perfectFourth = 5
        case tritone = 6
        case perfectFifth = 7
        case minorSixth = 8
        case majorSixth = 9
        case minorSeventh = 10
        case majorSeventh = 11
        case octave = 12
    }
    
    // Scale formulas (intervals from root)
    enum ScaleFormula {
        static let major = [0, 2, 4, 5, 7, 9, 11]
        static let naturalMinor = [0, 2, 3, 5, 7, 8, 10]
        static let harmonicMinor = [0, 2, 3, 5, 7, 8, 11]
        static let melodicMinor = [0, 2, 3, 5, 7, 9, 11]
        static let dorian = [0, 2, 3, 5, 7, 9, 10]
        static let mixolydian = [0, 2, 4, 5, 7, 9, 10]
    }
}

struct ChordSuggestion: Identifiable {
    let id = UUID()
    let root: String
    let quality: ChordQuality
    let extensions: [String]
    let reason: String
    let confidence: Double
    let romanNumeral: String?
    
    var display: String {
        root + quality.symbol + extensions.joined()
    }
    
    init(root: String, quality: ChordQuality, extensions: [String] = [], reason: String, confidence: Double, romanNumeral: String? = nil) {
        self.root = root
        self.quality = quality
        self.extensions = extensions
        self.reason = reason
        self.confidence = confidence
        self.romanNumeral = romanNumeral
    }
}

class ChordSuggestionEngine {
    
    // MARK: - Scale Degrees
    
    private static func scaleDegreesForKey(root: String, mode: KeyMode) -> [String] {
        guard let rootIndex = MusicTheory.noteIndex(root) else { return [] }
        return mode.intervals.map { offset in
            MusicTheory.chromaticScale[(rootIndex + offset) % 12]
        }
    }
    
    // MARK: - Note Utilities
    
    static func transpose(note: String, semitones: Int) -> String {
        guard let index = MusicTheory.noteIndex(note) else { return note }
        let newIndex = (index + semitones + 12) % 12
        return MusicTheory.chromaticScale[newIndex]
    }
    
    static func intervalBetween(from: String, to: String) -> Int {
        guard let fromIndex = MusicTheory.noteIndex(from),
              let toIndex = MusicTheory.noteIndex(to) else { return 0 }
        return (toIndex - fromIndex + 12) % 12
    }
    
    // MARK: - Diatonic Chords
    
    static func diatonicChords(forKey root: String, mode: KeyMode) -> [ChordSuggestion] {
        let scaleDegrees = scaleDegreesForKey(root: root, mode: mode)
        var chords: [ChordSuggestion] = []
        
        // Diatonic triad qualities by mode (for 7-note scales)
        let qualitiesForMode: [ChordQuality]
        let romanForMode: [String]
        let functionsForMode: [String]
        
        switch mode {
        case .major:
            qualitiesForMode = [.major, .minor, .minor, .major, .major, .minor, .diminished]
            romanForMode = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Leading Tone"]
        case .minor, .aeolian:
            qualitiesForMode = [.minor, .diminished, .major, .minor, .minor, .major, .major]
            romanForMode = ["i", "ii°", "III", "iv", "v", "VI", "VII"]
            functionsForMode = ["Tonic", "Supertonic", "Relative Major", "Subdominant", "Dominant", "Submediant", "Subtonic"]
        case .dorian:
            qualitiesForMode = [.minor, .minor, .major, .major, .minor, .diminished, .major]
            romanForMode = ["i", "ii", "III", "IV", "v", "vi°", "VII"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Subtonic"]
        case .phrygian:
            qualitiesForMode = [.minor, .major, .major, .minor, .diminished, .major, .minor]
            romanForMode = ["i", "II", "III", "iv", "v°", "VI", "vii"]
            functionsForMode = ["Tonic", "Neapolitan", "Mediant", "Subdominant", "Dominant", "Submediant", "Subtonic"]
        case .lydian:
            qualitiesForMode = [.major, .major, .minor, .diminished, .major, .minor, .minor]
            romanForMode = ["I", "II", "iii", "iv°", "V", "vi", "vii"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Subtonic"]
        case .mixolydian:
            qualitiesForMode = [.major, .minor, .diminished, .major, .minor, .minor, .major]
            romanForMode = ["I", "ii", "iii°", "IV", "v", "vi", "VII"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Subtonic"]
        case .locrian:
            qualitiesForMode = [.diminished, .major, .minor, .minor, .major, .major, .minor]
            romanForMode = ["i°", "II", "iii", "iv", "V", "VI", "vii"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Subtonic"]
        case .harmonicMinor:
            qualitiesForMode = [.minor, .diminished, .augmented, .minor, .major, .major, .diminished]
            romanForMode = ["i", "ii°", "III+", "iv", "V", "VI", "vii°"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Leading Tone"]
        case .melodicMinor:
            qualitiesForMode = [.minor, .minor, .augmented, .major, .major, .diminished, .diminished]
            romanForMode = ["i", "ii", "III+", "IV", "V", "vi°", "vii°"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Leading Tone"]
        case .pentatonicMajor:
            qualitiesForMode = [.major, .minor, .minor, .major, .minor]
            romanForMode = ["I", "ii", "iii", "V", "vi"]
            functionsForMode = ["Tonic", "Supertonic", "Mediant", "Dominant", "Submediant"]
        case .pentatonicMinor:
            qualitiesForMode = [.minor, .major, .minor, .minor, .major]
            romanForMode = ["i", "III", "iv", "v", "VII"]
            functionsForMode = ["Tonic", "Mediant", "Subdominant", "Dominant", "Subtonic"]
        case .blues:
            qualitiesForMode = [.minor, .major, .minor, .minor, .minor, .major]
            romanForMode = ["i", "III", "iv", "♯iv/♭v", "v", "VII"]
            functionsForMode = ["Tonic", "Mediant", "Subdominant", "Blue Note", "Dominant", "Subtonic"]
        }
        
        for (index, degree) in scaleDegrees.enumerated() {
            guard index < qualitiesForMode.count else { break }
            let confidence: Double = {
                switch index {
                case 0: return 1.0
                case 3, 4: return mode == .major ? 1.0 : 0.9
                case 5: return 0.9
                case 1: return 0.8
                default: return 0.7
                }
            }()
            
            chords.append(ChordSuggestion(
                root: degree,
                quality: qualitiesForMode[index],
                extensions: [],
                reason: "\(romanForMode[index]) - \(functionsForMode[index])",
                confidence: confidence,
                romanNumeral: romanForMode[index]
            ))
        }
        
        return chords
    }
    
    // MARK: - Common Extensions
    
    static func commonExtensions(forKey root: String, mode: KeyMode) -> [ChordSuggestion] {
        let diatonic = diatonicChords(forKey: root, mode: mode)
        var extended: [ChordSuggestion] = []
        
        // Add 7th chords (dominant, major7, minor7)
        for (index, chord) in diatonic.enumerated() {
            let seventh: ChordQuality
            let reason: String
            
            switch chord.quality {
            case .major:
                // V (index 4) always gets dom7; ♭VII (index 6) keeps dom7 for modal color.
                // All other major positions (I, II, III, IV, VI) get maj7.
                if index == 4 || index == 6 {
                    seventh = .dominant7
                    reason = "Dominant 7th"
                } else {
                    seventh = .major7
                    reason = "Major 7th chord"
                }
            case .minor:
                seventh = .minor7
                reason = "Minor 7th chord"
            case .diminished:
                seventh = .halfDiminished7
                reason = "Half-diminished 7th"
            case .augmented:
                seventh = .augmented7
                reason = "Augmented 7th"
            default:
                seventh = .dominant7
                reason = "7th chord"
            }
            
            if index < 6 {  // Skip vii° for 7th extensions
                extended.append(ChordSuggestion(
                    root: chord.root,
                    quality: seventh,
                    extensions: [],
                    reason: reason,
                    confidence: 0.75
                ))
            }
        }
        
        // Add suspended chords on I, IV, V (very common)
        let suspendedIndices = [0, 3, 4]
        for index in suspendedIndices where index < diatonic.count {
            let chord = diatonic[index]
            
            extended.append(ChordSuggestion(
                root: chord.root,
                quality: .sus4,
                extensions: [],
                reason: "Sus4 - creates tension",
                confidence: 0.65
            ))
            
            extended.append(ChordSuggestion(
                root: chord.root,
                quality: .sus2,
                extensions: [],
                reason: "Sus2 - open sound",
                confidence: 0.6
            ))
        }
        
        // Add 9th extensions to I, ii, V
        let ninthIndices = [0, 1, 4]
        for index in ninthIndices where index < diatonic.count {
            let chord = diatonic[index]
            extended.append(ChordSuggestion(
                root: chord.root,
                quality: chord.quality,
                extensions: ["9"],
                reason: "Add9 - richer harmony",
                confidence: 0.7
            ))
        }
        
        return extended
    }
    
    // MARK: - Smart Suggestions (Context-Aware)
    
    static func suggestNextChord(
        after lastChord: ChordEvent?,
        inKey keyRoot: String,
        mode: KeyMode
    ) -> [ChordSuggestion] {
        let diatonic = diatonicChords(forKey: keyRoot, mode: mode)
        
        guard let last = lastChord else {
            // No previous chord - suggest strong opening chords
            return [
                diatonic[0],  // I or i (tonic)
                diatonic[4],  // V (dominant - strong opener)
                diatonic[3],  // IV or iv (subdominant)
                diatonic[5]   // vi or VI (alternative)
            ].compactMap { $0 }
        }
        
        var suggestions: [ChordSuggestion] = []
        
        // Find the last chord in the scale
        if let lastIndex = diatonic.firstIndex(where: { $0.root == last.root && $0.quality == last.quality }) {
            // Use music theory progressions based on functional harmony
            switch lastIndex {
            case 0: // I/i (Tonic) - can go anywhere, common: IV, V, vi/VI, iii
                suggestions = [
                    ChordSuggestion(root: diatonic[3].root, quality: diatonic[3].quality, reason: "IV - Subdominant movement", confidence: 0.95),
                    ChordSuggestion(root: diatonic[4].root, quality: diatonic[4].quality, reason: "V - Dominant movement", confidence: 0.95),
                    ChordSuggestion(root: diatonic[5].root, quality: diatonic[5].quality, reason: "vi/VI - Relative minor color", confidence: 0.85),
                    ChordSuggestion(root: diatonic[1].root, quality: diatonic[1].quality, reason: "ii - Pre-dominant", confidence: 0.75),
                    ChordSuggestion(root: diatonic[2].root, quality: diatonic[2].quality, reason: "iii/III - Mediant color", confidence: 0.65)
                ]
                
            case 1: // ii/ii° (Supertonic) - commonly to V or back to I
                suggestions = [
                    ChordSuggestion(root: diatonic[4].root, quality: diatonic[4].quality, reason: "V - Strong cadence", confidence: 1.0),
                    ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Direct resolution", confidence: 0.7),
                    ChordSuggestion(root: diatonic[3].root, quality: diatonic[3].quality, reason: "IV - Plagal motion", confidence: 0.65)
                ]
                
            case 2: // iii/III (Mediant) - to vi, IV, or bridge
                suggestions = [
                    ChordSuggestion(root: diatonic[5].root, quality: diatonic[5].quality, reason: "vi/VI - Parallel minor", confidence: 0.9),
                    ChordSuggestion(root: diatonic[3].root, quality: diatonic[3].quality, reason: "IV - Descending", confidence: 0.85),
                    ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Resolution", confidence: 0.75)
                ]
                
            case 3: // IV/iv (Subdominant) - to I, V, or ii
                suggestions = [
                    ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Plagal cadence", confidence: 0.95),
                    ChordSuggestion(root: diatonic[4].root, quality: diatonic[4].quality, reason: "V - Authentic cadence prep", confidence: 0.95),
                    ChordSuggestion(root: diatonic[1].root, quality: diatonic[1].quality, reason: "ii - Pre-dominant chain", confidence: 0.75),
                    ChordSuggestion(root: diatonic[5].root, quality: diatonic[5].quality, reason: "vi - Deceptive", confidence: 0.7)
                ]
                
            case 4: // V/v (Dominant) - strong pull to I
                var v4: [ChordSuggestion] = [
                    ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Perfect cadence", confidence: 1.0),
                    ChordSuggestion(root: diatonic[5].root, quality: diatonic[5].quality, reason: "vi/VI - Deceptive cadence", confidence: 0.85),
                    ChordSuggestion(root: diatonic[3].root, quality: diatonic[3].quality, reason: "IV - Extended resolution", confidence: 0.65)
                ]
                // In minor, v is minor by default; surface V major (harmonic minor) for strong resolution
                if mode != .major, diatonic[4].quality == .minor {
                    v4.insert(
                        ChordSuggestion(root: diatonic[4].root, quality: .major, reason: "V major – harmonic minor cadence", confidence: 0.92, romanNumeral: "V"),
                        at: 1
                    )
                }
                suggestions = v4
                
            case 5: // vi/VI (Submediant) - to IV, ii, or V
                suggestions = [
                    ChordSuggestion(root: diatonic[3].root, quality: diatonic[3].quality, reason: "IV - Descending bass", confidence: 0.9),
                    ChordSuggestion(root: diatonic[1].root, quality: diatonic[1].quality, reason: "ii - Circle progression", confidence: 0.85),
                    ChordSuggestion(root: diatonic[4].root, quality: diatonic[4].quality, reason: "V - Direct to dominant", confidence: 0.8),
                    ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Back to tonic", confidence: 0.75)
                ]
                
            case 6: // vii°/VII (Leading Tone / Subtonic) - to I
                suggestions = [
                    ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Leading tone resolution", confidence: 1.0),
                    ChordSuggestion(root: diatonic[5].root, quality: diatonic[5].quality, reason: "vi/VI - Alternative", confidence: 0.6)
                ]
                
            default:
                suggestions = [diatonic[0], diatonic[4]].compactMap { $0 }
            }
        } else {
            // Last chord not in key - suggest tonic and dominant
            suggestions = [
                ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Return to key", confidence: 0.95),
                ChordSuggestion(root: diatonic[4].root, quality: diatonic[4].quality, reason: "V - Establish tonality", confidence: 0.85)
            ]
        }
        
        return suggestions
    }

    // MARK: - Contextual Smart Suggestions

    static func suggestContextualChords(
        previousChords: [ChordEvent],
        nextChords: [ChordEvent],
        inKey keyRoot: String,
        mode: KeyMode
    ) -> [ChordSuggestion] {
        let diatonic = diatonicChords(forKey: keyRoot, mode: mode)
        let lastChord = previousChords.last
        let nextChord = nextChords.first

        var suggestions = suggestNextChord(
            after: lastChord,
            inKey: keyRoot,
            mode: mode
        )

        var suggestionMap = [String: ChordSuggestion]()
        for suggestion in suggestions {
            suggestionMap[uniqueKey(for: suggestion)] = suggestion
        }

        func addSuggestion(_ suggestion: ChordSuggestion) {
            suggestionMap[uniqueKey(for: suggestion)] = suggestion
        }

        if previousChords.count >= 2 {
            let lastTwo = Array(previousChords.suffix(2))
            if let firstIndex = diatonicIndex(for: lastTwo[0], in: diatonic),
               let secondIndex = diatonicIndex(for: lastTwo[1], in: diatonic) {
                if firstIndex == 1 && secondIndex == 4 {
                    addSuggestion(
                        ChordSuggestion(
                            root: diatonic[0].root,
                            quality: diatonic[0].quality,
                            reason: "ii–V resolution",
                            confidence: 0.95,
                            romanNumeral: diatonic[0].romanNumeral
                        )
                    )
                } else if firstIndex == 3 && secondIndex == 4 {
                    addSuggestion(
                        ChordSuggestion(
                            root: diatonic[0].root,
                            quality: diatonic[0].quality,
                            reason: "IV–V to tonic",
                            confidence: 0.9,
                            romanNumeral: diatonic[0].romanNumeral
                        )
                    )
                }
            }
        }

        if let nextChord {
            let targetRoot = nextChord.root
            let secondaryDominant = transpose(note: targetRoot, semitones: 7)
            addSuggestion(
                ChordSuggestion(
                    root: secondaryDominant,
                    quality: .dominant7,
                    reason: "V/\(targetRoot) leading into the next chord",
                    confidence: 0.85
                )
            )
            let secondarySupertonic = transpose(note: targetRoot, semitones: 2)
            addSuggestion(
                ChordSuggestion(
                    root: secondarySupertonic,
                    quality: .minor7,
                    reason: "ii of \(targetRoot) – sets up V–I into next chord",
                    confidence: 0.75
                )
            )
            let tritoneSub = transpose(note: secondaryDominant, semitones: 6)
            addSuggestion(
                ChordSuggestion(
                    root: tritoneSub,
                    quality: .dominant7,
                    reason: "Tritone sub into \(targetRoot)",
                    confidence: 0.6
                )
            )
        }

        if mode == .major {
            let flatSeven = transpose(note: keyRoot, semitones: -2)
            addSuggestion(
                ChordSuggestion(
                    root: flatSeven,
                    quality: .major,
                    reason: "♭VII borrowed from Mixolydian",
                    confidence: 0.6
                )
            )
            let flatSix = transpose(note: keyRoot, semitones: -4)
            addSuggestion(
                ChordSuggestion(
                    root: flatSix,
                    quality: .major,
                    reason: "♭VI borrowed from Aeolian",
                    confidence: 0.55
                )
            )
            if diatonic.indices.contains(3) {
                addSuggestion(
                    ChordSuggestion(
                        root: diatonic[3].root,
                        quality: .minor,
                        reason: "iv minor for emotional color",
                        confidence: 0.6
                    )
                )
            }
        } else {
            if diatonic.indices.contains(4) {
                addSuggestion(
                    ChordSuggestion(
                        root: diatonic[4].root,
                        quality: .major,
                        reason: "V major from harmonic minor",
                        confidence: 0.8
                    )
                )
                addSuggestion(
                    ChordSuggestion(
                        root: diatonic[4].root,
                        quality: .dominant7,
                        reason: "V7 for strong resolution",
                        confidence: 0.85
                    )
                )
            }
            let flatTwo = transpose(note: keyRoot, semitones: 1)
            addSuggestion(
                ChordSuggestion(
                    root: flatTwo,
                    quality: .major,
                    reason: "♭II (Neapolitan)",
                    confidence: 0.55
                )
            )
            addSuggestion(
                ChordSuggestion(
                    root: keyRoot,
                    quality: .major,
                    reason: "Picardy third (major tonic)",
                    confidence: 0.5
                )
            )
        }

        if let lastChord {
            let upMediant = transpose(note: lastChord.root, semitones: 4)
            addSuggestion(
                ChordSuggestion(
                    root: upMediant,
                    quality: lastChord.quality == .minor ? .major : .minor,
                    reason: "Chromatic mediant color",
                    confidence: 0.5
                )
            )
            let downMediant = transpose(note: lastChord.root, semitones: -4)
            addSuggestion(
                ChordSuggestion(
                    root: downMediant,
                    quality: lastChord.quality == .minor ? .major : .minor,
                    reason: "Chromatic mediant contrast",
                    confidence: 0.5
                )
            )

            let circleRoot = transpose(note: lastChord.root, semitones: -7)
            let diatonicMatch = diatonic.first { $0.root == circleRoot }
            addSuggestion(
                ChordSuggestion(
                    root: circleRoot,
                    quality: diatonicMatch?.quality ?? .major,
                    reason: "Circle of fifths motion",
                    confidence: 0.65,
                    romanNumeral: diatonicMatch?.romanNumeral
                )
            )
        }

        let refined = suggestionMap.values.map { suggestion in
            adjustConfidence(suggestion, lastChord: lastChord, nextChord: nextChord)
        }
        suggestions = refined.sorted { $0.confidence > $1.confidence }
        return Array(suggestions.prefix(12))
    }
    
    // MARK: - Popular Progressions
    
    static func popularProgressions(forKey root: String, mode: KeyMode) -> [(name: String, progression: [ChordSuggestion])] {
        let chords = diatonicChords(forKey: root, mode: mode)
        
        if mode == .major {
            return [
                ("I-V-vi-IV (Pop)", [chords[0], chords[4], chords[5], chords[3]]),
                ("I-IV-V (Classic)", [chords[0], chords[3], chords[4]]),
                ("vi-IV-I-V (Sensitive)", [chords[5], chords[3], chords[0], chords[4]]),
                ("I-vi-IV-V (50s Doo-Wop)", [chords[0], chords[5], chords[3], chords[4]]),
                ("ii-V-I (Jazz)", [chords[1], chords[4], chords[0]]),
                ("I-IV-vi-V (Ascending)", [chords[0], chords[3], chords[5], chords[4]]),
                ("vi-ii-V-I (Circle)", [chords[5], chords[1], chords[4], chords[0]])
            ]
        } else {
            return [
                ("i-VI-III-VII (Andalusian)", [chords[0], chords[5], chords[2], chords[6]]),
                ("i-iv-v (Natural Minor)", [chords[0], chords[3], chords[4]]),
                ("i-VI-VII (Modal)", [chords[0], chords[5], chords[6]]),
                ("i-III-VII-iv (Dorian Feel)", [chords[0], chords[2], chords[6], chords[3]]),
                ("i-VII-VI-VII (Epic)", [chords[0], chords[6], chords[5], chords[6]]),
                ("i-VI-iv-V (Dramatic)", [chords[0], chords[5], chords[3], chords[4]])
            ]
        }
    }
    
    // MARK: - Chord Analysis
    
    /// Analyzes a chord progression and provides insights
    static func analyzeProgression(_ chords: [ChordEvent], inKey root: String, mode: KeyMode) -> ProgressionAnalysis {
        let diatonic = diatonicChords(forKey: root, mode: mode)
        var analysis = ProgressionAnalysis()
        
        for chord in chords {
            if let match = diatonic.first(where: { $0.root == chord.root }) {
                let isDiatonicQuality = baseQuality(for: chord.quality) == match.quality
                if isDiatonicQuality {
                    analysis.diatonicChords += 1
                } else {
                    analysis.nonDiatonicChords += 1
                }

                if let romanNumeral = match.romanNumeral {
                    analysis.romanNumerals.append(isDiatonicQuality ? romanNumeral : "\(romanNumeral)*")
                }
            } else {
                analysis.nonDiatonicChords += 1
                analysis.romanNumerals.append("?")
            }
        }
        
        analysis.totalChords = chords.count
        return analysis
    }
}

private extension ChordSuggestionEngine {
    static func baseQuality(for quality: ChordQuality) -> ChordQuality {
        switch quality {
        case .major, .major7, .major9, .major11, .major13, .dominant7, .dominant9,
             .dominant11, .dominant13, .dominant7sus4, .dominant7sharp9, .dominant7flat9,
             .dominant7sharp11, .altered, .sus2, .sus4, .augmented, .augmented7,
             .sixth, .add9, .add11, .power:
            return .major
        case .minor, .minor7, .minor9, .minor11, .minor13, .minorMajor7, .minorSixth:
            return .minor
        case .diminished, .diminished7, .halfDiminished7:
            return .diminished
        }
    }

    static func adjustConfidence(_ suggestion: ChordSuggestion, lastChord: ChordEvent?, nextChord: ChordEvent?) -> ChordSuggestion {
        var adjusted = suggestion.confidence

        if let lastChord {
            let interval = intervalBetween(from: lastChord.root, to: suggestion.root)
            switch interval {
            case 2, 10:
                adjusted += 0.05 // stepwise motion
            case 3, 9:
                adjusted += 0.04 // minor/major third (common in minor keys: i→III, i→VI)
            case 5, 7:
                adjusted += 0.08 // fourth/fifth motion (strongest functional moves)
            case 1, 11:
                adjusted += 0.03 // semitone chromatic color
            case 6:
                if !suggestion.reason.lowercased().contains("tritone") {
                    adjusted -= 0.05
                }
            default:
                break
            }
        }

        if let nextChord {
            let interval = intervalBetween(from: suggestion.root, to: nextChord.root)
            switch interval {
            case 2, 10:
                adjusted += 0.04
            case 3, 9:
                adjusted += 0.03
            case 5, 7:
                adjusted += 0.06
            case 1, 11:
                adjusted += 0.02
            default:
                break
            }
        }

        let clamped = min(max(adjusted, 0.4), 1.0)
        return ChordSuggestion(
            root: suggestion.root,
            quality: suggestion.quality,
            extensions: suggestion.extensions,
            reason: suggestion.reason,
            confidence: clamped,
            romanNumeral: suggestion.romanNumeral
        )
    }

    static func diatonicIndex(for chord: ChordEvent, in diatonic: [ChordSuggestion]) -> Int? {
        if let exactIndex = diatonic.firstIndex(where: { $0.root == chord.root && $0.quality == chord.quality }) {
            return exactIndex
        }
        return diatonic.firstIndex(where: { $0.root == chord.root })
    }

    static func uniqueKey(for suggestion: ChordSuggestion) -> String {
        let extensionKey = suggestion.extensions.joined(separator: "-")
        return "\(suggestion.root)|\(suggestion.quality.rawValue)|\(extensionKey)"
    }
    
    // MARK: - Voice Leading (M-10)
    
    /// Calculate optimal voicing of a chord to minimize movement from previous voicing
    /// Returns MIDI note numbers for smooth voice leading
    static func optimalVoicing(
        root: String,
        quality: ChordQuality,
        previousVoicing: [Int]?,
        baseOctave: Int = 4
    ) -> [Int] {
        guard let rootIdx = MusicTheory.noteIndex(root) else { return [] }
        let baseMidi = 12 * (baseOctave + 1) + rootIdx
        
        // Default voicing: root in given octave
        let voicing = quality.intervals.map { baseMidi + $0 }
        
        guard let prev = previousVoicing, !prev.isEmpty else {
            return voicing
        }
        
        // Try inversions to minimize total voice movement
        let noteCount = voicing.count
        var bestVoicing = voicing
        var bestCost = voiceLeadingCost(from: prev, to: voicing)
        
        // Try each inversion (shift notes up by octave)
        for inversion in 1..<noteCount {
            var candidate = voicing
            for i in 0..<inversion {
                candidate[i] += 12
            }
            candidate.sort()
            
            let cost = voiceLeadingCost(from: prev, to: candidate)
            if cost < bestCost {
                bestCost = cost
                bestVoicing = candidate
            }
        }
        
        // Also try dropping root an octave
        var dropped = bestVoicing
        if let minNote = dropped.first {
            dropped[0] = minNote - 12
            let dropCost = voiceLeadingCost(from: prev, to: dropped)
            if dropCost < bestCost {
                bestVoicing = dropped
            }
        }
        
        return bestVoicing
    }
    
    /// Calculate the total semitone movement between two voicings
    private static func voiceLeadingCost(from: [Int], to: [Int]) -> Int {
        let minCount = min(from.count, to.count)
        guard minCount > 0 else { return 100 }
        
        var cost = 0
        for i in 0..<minCount {
            cost += abs(from[i] - to[i])
        }
        // Penalty for differing voice count
        cost += abs(from.count - to.count) * 6
        return cost
    }
}

// MARK: - Supporting Types

struct ProgressionAnalysis {
    var totalChords: Int = 0
    var diatonicChords: Int = 0
    var nonDiatonicChords: Int = 0
    var romanNumerals: [String] = []
    
    var diatonicPercentage: Double {
        guard totalChords > 0 else { return 0 }
        return Double(diatonicChords) / Double(totalChords) * 100
    }
    
    var romanNumeralString: String {
        romanNumerals.joined(separator: " - ")
    }
}

// MARK: - Genre-Based Suggestions (M-09)

enum MusicGenre: String, CaseIterable {
    case pop = "Pop"
    case rock = "Rock"
    case jazz = "Jazz"
    case blues = "Blues"
    case folk = "Folk"
    case rnb = "R&B/Soul"
    case latin = "Latin"
    case gospel = "Gospel"
    case edm = "EDM"
    case country = "Country"
    
    /// Common chord progressions for this genre (as scale degree intervals from root)
    var typicalProgressions: [[(interval: Int, quality: ChordQuality)]] {
        switch self {
        case .pop:
            return [
                [(0, .major), (7, .major), (9, .minor), (5, .major)],           // I-V-vi-IV
                [(0, .major), (5, .major), (7, .major), (5, .major)],           // I-IV-V-IV
                [(9, .minor), (5, .major), (0, .major), (7, .major)],           // vi-IV-I-V
            ]
        case .rock:
            return [
                [(0, .major), (5, .major), (7, .major), (5, .major)],           // I-IV-V-IV
                [(0, .major), (10, .major), (5, .major), (0, .major)],          // I-bVII-IV-I
                [(0, .power), (5, .power), (7, .power), (5, .power)],           // Power chords
            ]
        case .jazz:
            return [
                [(0, .major7), (9, .minor7), (2, .minor7), (7, .dominant7)],    // Imaj7-vi7-ii7-V7
                [(2, .minor7), (7, .dominant7), (0, .major7), (0, .major7)],    // ii-V-I
                [(0, .major7), (5, .major7), (2, .minor7), (7, .dominant7)],    // I-IV-ii-V
            ]
        case .blues:
            return [
                [(0, .dominant7), (5, .dominant7), (0, .dominant7), (7, .dominant7)], // 12-bar blues
                [(0, .dominant7), (0, .dominant7), (5, .dominant7), (0, .dominant7)],
            ]
        case .folk:
            return [
                [(0, .major), (7, .major), (0, .major), (5, .major)],           // I-V-I-IV
                [(0, .major), (2, .minor), (5, .major), (0, .major)],           // I-ii-IV-I
            ]
        case .rnb:
            return [
                [(0, .major7), (2, .minor7), (7, .dominant7), (0, .major7)],    // Imaj7-ii7-V7-I
                [(9, .minor7), (2, .minor7), (7, .dominant7), (0, .major7)],    // vi7-ii7-V7-I
            ]
        case .latin:
            return [
                [(0, .major), (5, .major), (7, .major), (0, .major)],           // I-IV-V-I
                [(0, .minor), (5, .minor), (7, .dominant7), (0, .minor)],       // i-iv-V7-i
            ]
        case .gospel:
            return [
                [(0, .major7), (5, .major7), (7, .dominant7), (0, .major7)],    // I-IV-V-I with 7ths
                [(0, .major), (2, .minor7), (7, .dominant7), (0, .major)],      // I-ii7-V7-I
            ]
        case .edm:
            return [
                [(0, .minor), (5, .minor), (10, .major), (7, .major)],          // i-iv-bVII-V
                [(9, .minor), (5, .major), (0, .major), (7, .major)],           // vi-IV-I-V
            ]
        case .country:
            return [
                [(0, .major), (5, .major), (7, .major), (0, .major)],           // I-IV-V-I
                [(0, .major), (7, .major), (5, .major), (0, .major)],           // I-V-IV-I
            ]
        }
    }
    
    /// Generate chord suggestions for a given key using this genre's patterns
    func suggestions(keyRoot: String) -> [ChordSuggestion] {
        guard let rootIdx = MusicTheory.noteIndex(keyRoot) else { return [] }
        var result: [ChordSuggestion] = []
        
        for (progIdx, progression) in typicalProgressions.enumerated() {
            for (chordIdx, chord) in progression.enumerated() {
                let noteIdx = (rootIdx + chord.interval) % 12
                let note = MusicTheory.chromaticScale[noteIdx]
                result.append(ChordSuggestion(
                    root: note,
                    quality: chord.quality,
                    extensions: [],
                    reason: "\(rawValue) pattern \(progIdx + 1), beat \(chordIdx + 1)",
                    confidence: progIdx == 0 ? 0.9 : 0.7,
                    romanNumeral: ""
                ))
            }
        }
        
        // Deduplicate by root+quality
        var seen = Set<String>()
        return result.filter { s in
            let key = "\(s.root)\(s.quality.rawValue)"
            return seen.insert(key).inserted
        }
    }
}
