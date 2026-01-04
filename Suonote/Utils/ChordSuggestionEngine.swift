import Foundation

struct ChordSuggestion: Identifiable {
    let id = UUID()
    let root: String
    let quality: ChordQuality
    let extensions: [String]
    let reason: String
    let confidence: Double
    
    var display: String {
        root + quality.symbol + extensions.joined()
    }
}

class ChordSuggestionEngine {
    
    // MARK: - Scale Degrees
    
    private static func scaleDegreesForKey(root: String, mode: KeyMode) -> [String] {
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        guard let rootIndex = notes.firstIndex(of: root) else { return [] }
        
        let intervals: [Int]
        switch mode {
        case .major:
            intervals = [0, 2, 4, 5, 7, 9, 11] // Major scale
        case .minor:
            intervals = [0, 2, 3, 5, 7, 8, 10] // Natural minor scale
        }
        
        return intervals.map { offset in
            notes[(rootIndex + offset) % 12]
        }
    }
    
    // MARK: - Diatonic Chords
    
    static func diatonicChords(forKey root: String, mode: KeyMode) -> [ChordSuggestion] {
        let scaleDegrees = scaleDegreesForKey(root: root, mode: mode)
        var chords: [ChordSuggestion] = []
        
        if mode == .major {
            // Major key: I, ii, iii, IV, V, vi, vii°
            let qualities: [ChordQuality] = [.major, .minor, .minor, .major, .major, .minor, .diminished]
            let romanNumerals = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
            
            for (index, degree) in scaleDegrees.enumerated() {
                chords.append(ChordSuggestion(
                    root: degree,
                    quality: qualities[index],
                    extensions: [],
                    reason: "Diatonic chord \(romanNumerals[index])",
                    confidence: index == 0 || index == 3 || index == 4 ? 1.0 : 0.8
                ))
            }
        } else {
            // Minor key: i, ii°, III, iv, v, VI, VII
            let qualities: [ChordQuality] = [.minor, .diminished, .major, .minor, .minor, .major, .major]
            let romanNumerals = ["i", "ii°", "III", "iv", "v", "VI", "VII"]
            
            for (index, degree) in scaleDegrees.enumerated() {
                chords.append(ChordSuggestion(
                    root: degree,
                    quality: qualities[index],
                    extensions: [],
                    reason: "Diatonic chord \(romanNumerals[index])",
                    confidence: index == 0 || index == 3 || index == 4 ? 1.0 : 0.8
                ))
            }
        }
        
        return chords
    }
    
    // MARK: - Common Extensions
    
    static func commonExtensions(forKey root: String, mode: KeyMode) -> [ChordSuggestion] {
        let diatonic = diatonicChords(forKey: root, mode: mode)
        var extended: [ChordSuggestion] = []
        
        // Add 7th chords
        for chord in diatonic.prefix(5) {
            extended.append(ChordSuggestion(
                root: chord.root,
                quality: chord.quality,
                extensions: ["7"],
                reason: "Common 7th chord",
                confidence: 0.7
            ))
        }
        
        // Add suspended chords on I, IV, V
        let suspendedDegrees = [diatonic[0], diatonic[3], diatonic[4]]
        for chord in suspendedDegrees {
            extended.append(ChordSuggestion(
                root: chord.root,
                quality: .major,
                extensions: ["sus4"],
                reason: "Suspended chord",
                confidence: 0.6
            ))
        }
        
        return extended
    }
    
    // MARK: - Smart Suggestions
    
    static func suggestNextChord(
        after lastChord: ChordEvent?,
        inKey keyRoot: String,
        mode: KeyMode
    ) -> [ChordSuggestion] {
        let diatonic = diatonicChords(forKey: keyRoot, mode: mode)
        
        guard let last = lastChord else {
            // No previous chord - suggest tonic and dominant
            return [
                diatonic[0], // I or i
                diatonic[4], // V
                diatonic[3]  // IV or iv
            ]
        }
        
        var suggestions: [ChordSuggestion] = []
        
        // Find the last chord in the scale
        if let lastIndex = diatonic.firstIndex(where: { $0.root == last.root }) {
            switch lastIndex {
            case 0: // I/i - can go anywhere, but commonly to IV, V, vi
                suggestions = [diatonic[3], diatonic[4], diatonic[5]]
            case 1: // ii - commonly to V
                suggestions = [diatonic[4], diatonic[0]]
            case 2: // iii - to vi or IV
                suggestions = [diatonic[5], diatonic[3]]
            case 3: // IV - to I, V, or ii
                suggestions = [diatonic[0], diatonic[4], diatonic[1]]
            case 4: // V - strong pull to I
                suggestions = [diatonic[0], diatonic[5]]
            case 5: // vi - to IV, ii, or V
                suggestions = [diatonic[3], diatonic[1], diatonic[4]]
            case 6: // vii° - to I
                suggestions = [diatonic[0]]
            default:
                suggestions = [diatonic[0]]
            }
        } else {
            // Last chord not in key, suggest tonic
            suggestions = [diatonic[0], diatonic[4]]
        }
        
        return suggestions
    }
    
    // MARK: - Popular Progressions
    
    static func popularProgressions(forKey root: String, mode: KeyMode) -> [(name: String, progression: [ChordSuggestion])] {
        let chords = diatonicChords(forKey: root, mode: mode)
        
        if mode == .major {
            return [
                ("I-V-vi-IV", [chords[0], chords[4], chords[5], chords[3]]),
                ("I-IV-V", [chords[0], chords[3], chords[4]]),
                ("vi-IV-I-V", [chords[5], chords[3], chords[0], chords[4]]),
                ("I-vi-IV-V", [chords[0], chords[5], chords[3], chords[4]]),
                ("ii-V-I", [chords[1], chords[4], chords[0]])
            ]
        } else {
            return [
                ("i-VI-III-VII", [chords[0], chords[5], chords[2], chords[6]]),
                ("i-iv-v", [chords[0], chords[3], chords[4]]),
                ("i-VI-VII", [chords[0], chords[5], chords[6]]),
                ("i-III-VII-iv", [chords[0], chords[2], chords[6], chords[3]])
            ]
        }
    }
}
