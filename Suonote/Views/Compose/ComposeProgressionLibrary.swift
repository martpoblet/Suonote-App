import SwiftUI

// MARK: - Named progressions
/// A progression a musician would recognise, built in the current key.
struct ComposeProgression: Identifiable {
    let id: String
    /// "I–V–vi–IV"
    let numerals: String
    /// "The Axis"
    let nickname: String
    let blurb: String
    let chords: [ComposeChordValue]
}

enum ComposeProgressionLibrary {
    private struct Pattern {
        let degrees: [Int]
        var overrides: [Int: ChordQuality] = [:]
        let numerals: String
        let nickname: String
        let blurb: String
    }

    private static let majorPatterns: [Pattern] = [
        Pattern(degrees: [0, 4, 5, 3], numerals: "I–V–vi–IV", nickname: String(localized: "The Axis"),
                blurb: String(localized: "The backbone of modern pop — bright, singable, endlessly reusable.")),
        Pattern(degrees: [5, 3, 0, 4], numerals: "vi–IV–I–V", nickname: String(localized: "The sensitive one"),
                blurb: String(localized: "Axis chords starting on the minor — wistful and searching.")),
        Pattern(degrees: [0, 5, 3, 4], numerals: "I–vi–IV–V", nickname: String(localized: "’50s doo-wop"),
                blurb: String(localized: "Sweet and nostalgic, made for slow dances and big harmonies.")),
        Pattern(degrees: [0, 3, 4], numerals: "I–IV–V", nickname: String(localized: "Three-chord classic"),
                blurb: String(localized: "Folk, blues and rock ’n’ roll in their simplest, strongest form.")),
        Pattern(degrees: [1, 4, 0], numerals: "ii–V–I", nickname: String(localized: "Jazz turnaround"),
                blurb: String(localized: "The most common cadence in jazz — tension that lands home.")),
        Pattern(degrees: [0, 3, 5, 4], numerals: "I–IV–vi–V", nickname: String(localized: "Ascending lift"),
                blurb: String(localized: "Rising energy — a natural pre-chorus.")),
        Pattern(degrees: [5, 1, 4, 0], numerals: "vi–ii–V–I", nickname: String(localized: "Circle of fifths"),
                blurb: String(localized: "Each chord pulls to the next — an inevitable walk home.")),
        Pattern(degrees: [0, 6, 3], overrides: [6: .major], numerals: "I–♭VII–IV", nickname: String(localized: "Mixolydian rock"),
                blurb: String(localized: "A borrowed ♭VII gives that open, anthemic rock swagger."))
    ]

    private static let minorPatterns: [Pattern] = [
        Pattern(degrees: [0, 5, 2, 6], numerals: "i–VI–III–VII", nickname: String(localized: "The minor Axis"),
                blurb: String(localized: "The Axis’ darker twin — brooding, anthemic, cinematic.")),
        Pattern(degrees: [0, 6, 5, 4], overrides: [4: .major], numerals: "i–VII–VI–V", nickname: String(localized: "Andalusian cadence"),
                blurb: String(localized: "A stepwise descent with Spanish fire — flamenco to film scores.")),
        Pattern(degrees: [0, 3, 4], numerals: "i–iv–v", nickname: String(localized: "Natural minor"),
                blurb: String(localized: "Plain and somber, with a folk-song honesty.")),
        Pattern(degrees: [0, 5, 6], numerals: "i–VI–VII", nickname: String(localized: "Epic rise"),
                blurb: String(localized: "Climbs back to the tonic — big, heroic, trailer-ready.")),
        Pattern(degrees: [0, 5, 3, 4], overrides: [4: .major], numerals: "i–VI–iv–V", nickname: String(localized: "Dramatic minor"),
                blurb: String(localized: "The major V brings real tension before falling home.")),
        Pattern(degrees: [0, 3, 6, 2], numerals: "i–iv–VII–III", nickname: String(localized: "Minor circle"),
                blurb: String(localized: "Moves by fourths — smooth, soulful and inevitable."))
    ]

    /// Progressions for the key. Uses major/minor harmony so names stay accurate.
    static func progressions(keyRoot: String, mode: KeyMode) -> [ComposeProgression] {
        let isMinor = mode.isMinor
        let diatonic = ChordSuggestionEngine.diatonicChords(forKey: keyRoot, mode: isMinor ? .minor : .major)
        guard diatonic.count >= 7 else { return [] }
        return (isMinor ? minorPatterns : majorPatterns).map { pattern in
            ComposeProgression(
                id: pattern.numerals,
                numerals: pattern.numerals,
                nickname: pattern.nickname,
                blurb: pattern.blurb,
                chords: pattern.degrees.map { degree in
                    var root = diatonic[degree].root
                    if pattern.overrides[degree] == .major, degree == 6, !isMinor {
                        // ♭VII in major is a whole step below the tonic.
                        root = ChordSuggestionEngine.transpose(note: keyRoot, semitones: 10)
                    }
                    return ComposeChordValue(root: root, quality: pattern.overrides[degree] ?? diatonic[degree].quality)
                }
            )
        }
    }

    /// Finds a named progression inside the section (exact or rotated).
    static func recognize(_ chords: [ChordEvent], keyRoot: String, mode: KeyMode) -> (progression: ComposeProgression, rotated: Bool)? {
        let sequence = collapse(chords.filter { !$0.isRest }.map { signature(root: $0.root, quality: $0.quality, keyRoot: keyRoot) })
        guard sequence.count >= 3 else { return nil }
        let candidates = progressions(keyRoot: keyRoot, mode: mode)

        for progression in candidates {
            let pattern = progression.chords.map { signature(root: $0.root, quality: $0.quality, keyRoot: keyRoot) }
            if contains(sequence, pattern) { return (progression, false) }
        }
        for progression in candidates where progression.chords.count >= 4 {
            let pattern = progression.chords.map { signature(root: $0.root, quality: $0.quality, keyRoot: keyRoot) }
            for shift in 1..<pattern.count {
                let rotated = Array(pattern[shift...] + pattern[..<shift])
                if contains(sequence, rotated) { return (progression, true) }
            }
        }
        return nil
    }

    private struct Signature: Equatable {
        let interval: Int
        let isMinor: Bool
    }

    private static func signature(root: String, quality: ChordQuality, keyRoot: String) -> Signature {
        Signature(interval: ChordSuggestionEngine.intervalBetween(from: keyRoot, to: root), isMinor: quality.isMinor)
    }

    private static func collapse(_ values: [Signature]) -> [Signature] {
        values.reduce(into: []) { result, value in
            if result.last != value { result.append(value) }
        }
    }

    private static func contains(_ sequence: [Signature], _ pattern: [Signature]) -> Bool {
        guard pattern.count <= sequence.count else { return false }
        for start in 0...(sequence.count - pattern.count) where Array(sequence[start..<(start + pattern.count)]) == pattern {
            return true
        }
        return false
    }
}

// MARK: - Insights
/// Musician-friendly observations about a section's harmony.
struct ComposeInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

enum ComposeInsightEngine {
    static func numerals(for chords: [ChordEvent], keyRoot: String, mode: KeyMode) -> [String] {
        chords.filter { !$0.isRest }.map {
            MusicTheoryUtils.romanNumeral(root: $0.root, quality: $0.quality, keyRoot: keyRoot, mode: mode)
        }
    }

    static func insights(for section: SectionTemplate, beatsPerBar: Int) -> [ComposeInsight] {
        let keyRoot = section.effectiveKeyRoot
        let mode = section.effectiveKeyMode
        let ordered = section.chordEvents
            .filter { !$0.isRest }
            .sorted { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) }
        guard !ordered.isEmpty else { return [] }

        var cards: [ComposeInsight] = []
        let keyName = ComposeFormat.keyName(root: keyRoot, mode: mode)
        let diatonic = ChordSuggestionEngine.diatonicChords(forKey: keyRoot, mode: mode)
        let outside = ordered.filter { chord in
            !diatonic.contains { $0.root == chord.root && $0.quality.isMinor == chord.quality.isMinor }
        }
        let inside = ordered.count - outside.count

        // Key fit
        if outside.isEmpty {
            cards.append(ComposeInsight(icon: "checkmark.seal", title: String(localized: "Fully in \(keyName)"),
                                        detail: String(localized: "Every chord belongs to the key — focused and easy to sing over.")))
        } else {
            let names = uniqueDisplays(outside).prefix(3).joined(separator: ", ")
            cards.append(ComposeInsight(icon: "paintpalette", title: String(localized: "\(inside) of \(ordered.count) chords in \(keyName)"),
                                        detail: String(localized: "Color from outside the key: \(names). Borrowed chords add surprise and lift.")))
        }

        // Named progression
        if let match = ComposeProgressionLibrary.recognize(ordered, keyRoot: keyRoot, mode: mode) {
            cards.append(ComposeInsight(
                icon: "sparkles",
                title: match.rotated ? String(localized: "A turn on \(match.progression.nickname)") : "\(match.progression.nickname) · \(match.progression.numerals)",
                detail: match.rotated
                    ? String(localized: "The \(match.progression.numerals) chords, starting elsewhere in the loop. \(match.progression.blurb)")
                    : match.progression.blurb
            ))
        }

        // Ending
        if let last = ordered.last {
            let interval = ChordSuggestionEngine.intervalBetween(from: keyRoot, to: last.root)
            let ending: (String, String)
            switch interval {
            case 0: ending = (String(localized: "Lands home"), String(localized: "Ends on the tonic — settled, like a full stop."))
            case 7: ending = (String(localized: "Leans forward"), String(localized: "Ends on the dominant — unresolved, perfect right before a chorus."))
            case 5: ending = (String(localized: "Soft landing"), String(localized: "Ends on the IV — open and gentle, the ‘amen’ feeling."))
            case 9 where !mode.isMinor: ending = (String(localized: "Bittersweet ending"), String(localized: "Ends on the relative minor — wistful, asks for more."))
            default: ending = (String(localized: "Keeps the tension"), String(localized: "Ends away from home, so the next section feels like an answer."))
            }
            cards.append(ComposeInsight(icon: "flag.checkered", title: ending.0, detail: ending.1))
        }

        // Harmonic rhythm
        let barsUsed = Set(ordered.map(\.barIndex)).count
        if barsUsed > 0 {
            let perBar = Double(ordered.count) / Double(barsUsed)
            let rhythm: (String, String) = perBar <= 1.05
                ? (String(localized: "One chord per bar"), String(localized: "A relaxed harmonic rhythm — room for the melody to breathe."))
                : perBar < 2.5
                    ? (String(localized: "Two chords per bar"), String(localized: "A busier harmonic rhythm that keeps things moving."))
                    : (String(localized: "Fast changes"), String(localized: "Several chords per bar — driving, jazzy, restless."))
            cards.append(ComposeInsight(icon: "metronome", title: rhythm.0, detail: rhythm.1))
        }

        // Detected key
        if ordered.count >= 4,
           let detected = MusicTheoryUtils.detectKey(chords: ordered.map { ($0.root, $0.quality) }),
           detected.confidence >= 0.7,
           (MusicTheory.normalize(detected.root) != MusicTheory.normalize(keyRoot) || detected.mode.isMinor != mode.isMinor) {
            cards.append(ComposeInsight(
                icon: "tuningfork",
                title: String(localized: "Sounds like \(ComposeFormat.keyName(root: detected.root, mode: detected.mode))"),
                detail: String(localized: "These chords centre on \(detected.root). Setting that key sharpens the suggestions.")
            ))
        }
        return cards
    }

    /// Short summary for badges: nickname, or "% in key".
    static func badge(for section: SectionTemplate) -> String? {
        let keyRoot = section.effectiveKeyRoot
        let mode = section.effectiveKeyMode
        let chords = section.chordEvents.filter { !$0.isRest }
        guard chords.count >= 2 else { return nil }
        let ordered = chords.sorted { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) }
        if let match = ComposeProgressionLibrary.recognize(ordered, keyRoot: keyRoot, mode: mode), !match.rotated {
            return match.progression.nickname
        }
        let diatonic = ChordSuggestionEngine.diatonicChords(forKey: keyRoot, mode: mode)
        let inKey = chords.filter { chord in
            diatonic.contains { $0.root == chord.root && $0.quality.isMinor == chord.quality.isMinor }
        }.count
        let percent = Int((Double(inKey) / Double(chords.count) * 100).rounded())
        return percent == 100 ? String(localized: "All in key") : String(localized: "\(percent)% in key")
    }

    private static func uniqueDisplays(_ chords: [ChordEvent]) -> [String] {
        var seen = Set<String>()
        return chords.compactMap { seen.insert($0.display).inserted ? $0.display : nil }
    }
}
