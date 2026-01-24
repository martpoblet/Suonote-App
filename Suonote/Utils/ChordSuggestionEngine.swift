import Foundation

// MARK: - Music Theory Constants

enum MusicTheory {
    static let chromaticScale = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
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
        guard let rootIndex = MusicTheory.chromaticScale.firstIndex(of: root) else { return [] }
        
        let intervals: [Int]
        switch mode {
        case .major:
            intervals = MusicTheory.ScaleFormula.major
        case .minor:
            intervals = MusicTheory.ScaleFormula.naturalMinor
        }
        
        return intervals.map { offset in
            MusicTheory.chromaticScale[(rootIndex + offset) % 12]
        }
    }
    
    // MARK: - Note Utilities
    
    static func transpose(note: String, semitones: Int) -> String {
        guard let index = MusicTheory.chromaticScale.firstIndex(of: note) else { return note }
        let newIndex = (index + semitones + 12) % 12
        return MusicTheory.chromaticScale[newIndex]
    }
    
    static func intervalBetween(from: String, to: String) -> Int {
        guard let fromIndex = MusicTheory.chromaticScale.firstIndex(of: from),
              let toIndex = MusicTheory.chromaticScale.firstIndex(of: to) else { return 0 }
        return (toIndex - fromIndex + 12) % 12
    }
    
    // MARK: - Diatonic Chords
    
    static func diatonicChords(forKey root: String, mode: KeyMode) -> [ChordSuggestion] {
        let scaleDegrees = scaleDegreesForKey(root: root, mode: mode)
        var chords: [ChordSuggestion] = []
        
        if mode == .major {
            // Major key: I, ii, iii, IV, V, vi, vii°
            let qualities: [ChordQuality] = [.major, .minor, .minor, .major, .major, .minor, .diminished]
            let romanNumerals = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
            let functionNames = ["Tonic", "Supertonic", "Mediant", "Subdominant", "Dominant", "Submediant", "Leading Tone"]
            
            for (index, degree) in scaleDegrees.enumerated() {
                let confidence: Double = {
                    switch index {
                    case 0, 3, 4: return 1.0  // I, IV, V - primary chords
                    case 5: return 0.9        // vi - very common
                    case 1: return 0.8        // ii - common pre-dominant
                    default: return 0.7
                    }
                }()
                
                chords.append(ChordSuggestion(
                    root: degree,
                    quality: qualities[index],
                    extensions: [],
                    reason: "\(romanNumerals[index]) - \(functionNames[index])",
                    confidence: confidence,
                    romanNumeral: romanNumerals[index]
                ))
            }
        } else {
            // Minor key: i, ii°, III, iv, v, VI, VII
            let qualities: [ChordQuality] = [.minor, .diminished, .major, .minor, .minor, .major, .major]
            let romanNumerals = ["i", "ii°", "III", "iv", "v", "VI", "VII"]
            let functionNames = ["Tonic", "Supertonic", "Relative Major", "Subdominant", "Dominant", "Submediant", "Subtonic"]
            
            for (index, degree) in scaleDegrees.enumerated() {
                let confidence: Double = {
                    switch index {
                    case 0, 3, 4: return 1.0  // i, iv, v
                    case 5, 6: return 0.9     // VI, VII - common in minor
                    default: return 0.7
                    }
                }()
                
                chords.append(ChordSuggestion(
                    root: degree,
                    quality: qualities[index],
                    extensions: [],
                    reason: "\(romanNumerals[index]) - \(functionNames[index])",
                    confidence: confidence,
                    romanNumeral: romanNumerals[index]
                ))
            }
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
            
            switch (mode, index) {
            case (.major, 0), (.major, 3):  // I and IV in major
                seventh = .major7
                reason = "Major 7th chord"
            case (.major, 4):  // V in major
                seventh = .dominant7
                reason = "Dominant 7th"
            case (_, _) where chord.quality == .minor:  // Any minor chord
                seventh = .minor7
                reason = "Minor 7th chord"
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
            case 0: // I/i (Tonic) - can go anywhere, common: IV, V, vi/VI
                suggestions = [
                    ChordSuggestion(root: diatonic[3].root, quality: diatonic[3].quality, reason: "IV - Subdominant movement", confidence: 0.95),
                    ChordSuggestion(root: diatonic[4].root, quality: diatonic[4].quality, reason: "V - Dominant movement", confidence: 0.95),
                    ChordSuggestion(root: diatonic[5].root, quality: diatonic[5].quality, reason: "vi/VI - Deceptive resolution", confidence: 0.85),
                    ChordSuggestion(root: diatonic[1].root, quality: diatonic[1].quality, reason: "ii - Pre-dominant", confidence: 0.75)
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
                suggestions = [
                    ChordSuggestion(root: diatonic[0].root, quality: diatonic[0].quality, reason: "I - Perfect cadence", confidence: 1.0),
                    ChordSuggestion(root: diatonic[5].root, quality: diatonic[5].quality, reason: "vi/VI - Deceptive cadence", confidence: 0.85),
                    ChordSuggestion(root: diatonic[3].root, quality: diatonic[3].quality, reason: "IV - Extended resolution", confidence: 0.65)
                ]
                
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
                    reason: "ii/V approach toward \(targetRoot)",
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
        case .major, .major7, .major9, .dominant7, .dominant9, .sus2, .sus4, .augmented, .augmented7:
            return .major
        case .minor, .minor7, .minor9, .minorMajor7:
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
                adjusted += 0.05 // stepwise
            case 5, 7:
                adjusted += 0.08 // fourth/fifth
            case 1, 11:
                adjusted += 0.03 // semitone color
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
