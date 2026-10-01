import SwiftUI

// MARK: - Lyrics typography

enum LyricsType {
    /// The lyric itself — it's the content, so it reads like a printed page.
    static let lyric = Font.erode(19, weight: .regular, relativeTo: .body)
    static let lyricUIFont = UIFont.erode(19, weight: .regular)
    /// Extra leading between lyric lines.
    static let lineSpacing: CGFloat = 9
}

// MARK: - Text analysis

/// Lightweight, language-agnostic helpers for songwriting hints:
/// syllable estimates, word/line counts, rhyme keys and rhyme scheme letters.
enum LyricsAnalysis {
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]

    /// Letters only, lowercased, accents folded ("Corazón" → "corazon").
    static func normalized(_ word: String) -> String {
        word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .filter { $0.isLetter }
    }

    static func words(in text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { $0.contains(where: \.isLetter) }
    }

    static func wordCount(_ text: String) -> Int { words(in: text).count }

    /// Non-empty lines.
    static func lines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Estimated syllables in one word (vowel groups, with a silent-e rule).
    static func syllables(inWord raw: String) -> Int {
        let word = normalized(raw)
        guard !word.isEmpty else { return 0 }
        var count = 0
        var previousWasVowel = false
        for char in word {
            let isVowel = vowels.contains(char)
            if isVowel && !previousWasVowel { count += 1 }
            previousWasVowel = isVowel
        }
        // English silent final "e" ("love", "fire"), but not "-le" ("little").
        let chars = Array(word)
        if count > 1, chars.count > 2, chars.last == "e",
           !vowels.contains(chars[chars.count - 2]),
           !(chars[chars.count - 2] == "l" && !vowels.contains(chars[max(0, chars.count - 3)])) {
            count -= 1
        }
        return max(1, count)
    }

    static func syllables(inLine line: String) -> Int {
        words(in: line).reduce(0) { $0 + syllables(inWord: $1) }
    }

    /// The sound a line ends on: last vowel (+ silent e handling) and what follows.
    /// "night" → "ight", "heart"/"start" → "art", "fire"/"desire" → "ire".
    static func rhymeKey(forLine line: String) -> String? {
        guard let last = words(in: line).last else { return nil }
        let word = Array(normalized(last))
        guard !word.isEmpty else { return nil }

        var end = word.count
        // Skip a silent trailing e to find the stressed vowel before it.
        if word.count > 2, word.last == "e", !vowels.contains(word[word.count - 2]) {
            end = word.count - 1
        }
        var index = end - 1
        while index >= 0 && !vowels.contains(word[index]) { index -= 1 }
        guard index >= 0 else { return String(word) }
        return String(word[index...])
    }

    /// One letter per non-empty line (A, B, A, B…). Lines whose ending sound
    /// appears only once are marked `isRhyme == false`.
    static func rhymeScheme(_ text: String) -> [(line: String, letter: String, isRhyme: Bool)] {
        let lines = lines(text)
        let keys = lines.map { rhymeKey(forLine: $0) ?? UUID().uuidString }
        var counts: [String: Int] = [:]
        keys.forEach { counts[$0, default: 0] += 1 }
        var letters: [String: String] = [:]
        var next = 0
        return zip(lines, keys).map { line, key in
            if letters[key] == nil {
                let scalar = UnicodeScalar(UInt8(65 + next % 26))
                letters[key] = String(Character(scalar))
                next += 1
            }
            return (line, letters[key] ?? "?", (counts[key] ?? 0) > 1)
        }
    }
}

// MARK: - Chords of a section

extension SectionTemplate {
    /// Chord symbols bar by bar ("C G", "Am F", …); nil when the section has no chords.
    var lyricsChordBars: [String]? {
        let events = chordEvents.filter { !$0.isRest }
        guard !events.isEmpty else { return nil }
        let lastBar = events.map(\.barIndex).max() ?? 0
        let barCount = max(bars, lastBar + 1)
        let grouped = Dictionary(grouping: events, by: \.barIndex)
        let result = (0..<barCount).map { bar -> String in
            let symbols = (grouped[bar] ?? [])
                .sorted { $0.beatOffset < $1.beatOffset }
                .map { $0.display.isEmpty ? $0.root : $0.localizedDisplay }
            return symbols.isEmpty ? "–" : symbols.joined(separator: " ")
        }
        return result
    }
}

/// A section's chords as a quiet reference line: "C G │ Am F │ …".
struct LyricsChordLine: View {
    let bars: [String]
    var lineLimit: Int? = 2

    var body: some View {
        bars.enumerated().reduce(Text(verbatim: "")) { partial, item in
            let separator = item.offset == 0
                ? Text(verbatim: "")
                : Text(verbatim: "  │  ").foregroundStyle(DesignSystem.Colors.borderActive)
            return Text("\(partial)\(separator)\(Text(verbatim: item.element))")
        }
        .font(DesignSystem.Typography.chordSmall)
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .lineLimit(lineLimit)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Chords: \(bars.filter { $0 != "–" }.joined(separator: ", "))")
    }
}
