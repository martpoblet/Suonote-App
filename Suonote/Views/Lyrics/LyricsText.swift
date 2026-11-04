import SwiftUI
import NaturalLanguage

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

    /// Estimated syllables in one word. English counts vowel groups with a
    /// silent-e rule; Spanish uses `spanishSyllables(inWord:)`. `language` nil
    /// means "the app's current language" (a lone word is too short to detect).
    static func syllables(inWord raw: String, language: NLLanguage? = nil) -> Int {
        if (language ?? fallbackLanguage) == .spanish {
            return spanishSyllables(inWord: raw)
        }
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

    /// `language` nil detects English vs Spanish from the line itself (falling
    /// back to the app language when the line is too short to tell).
    static func syllables(inLine line: String, language: NLLanguage? = nil) -> Int {
        let resolved = language ?? detectedLanguage(of: line)
        return words(in: line).reduce(0) { $0 + syllables(inWord: $1, language: resolved) }
    }

    // MARK: Language

    /// The app's current language (English unless the app resolves to Spanish).
    private static var fallbackLanguage: NLLanguage {
        Bundle.main.preferredLocalizations.first?.hasPrefix("es") == true ? .spanish : .english
    }

    /// English or Spanish for a piece of lyrics; the app language when unsure.
    static func detectedLanguage(of text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.english, .spanish]
        recognizer.processString(text)
        if let dominant = recognizer.dominantLanguage,
           (recognizer.languageHypotheses(withMaximum: 2)[dominant] ?? 0) >= 0.6 {
            return dominant
        }
        return fallbackLanguage
    }

    // MARK: Spanish syllables

    private enum SpanishLetter { case consonant, strong, weak, stressedWeak }

    /// Syllables in a Spanish word from its vowel nuclei. a/e/o (and accented
    /// á/é/ó) are strong; i/u/ü are weak and fuse with a neighbouring vowel
    /// into a diphthong; accented í/ú break it (hiatus), as do two strong
    /// vowels. "u" is silent in qu- and in gu- before e/i (but not in gü-);
    /// a final "y" acts as a vowel; there is no silent-final-e rule.
    static func spanishSyllables(inWord raw: String) -> Int {
        let chars = Array(raw.lowercased().filter { $0.isLetter })
        guard !chars.isEmpty else { return 0 }

        var letters: [SpanishLetter] = []
        for (index, char) in chars.enumerated() {
            let previous: Character? = index > 0 ? chars[index - 1] : nil
            let next: Character? = index + 1 < chars.count ? chars[index + 1] : nil
            switch char {
            case "a", "e", "o", "á", "é", "ó":
                letters.append(.strong)
            case "í", "ú":
                letters.append(.stressedWeak)
            case "i", "ü":
                letters.append(.weak)
            case "u":
                if previous == "q" {
                    letters.append(.consonant)
                } else if previous == "g", let next, ["e", "i", "é", "í"].contains(next) {
                    letters.append(.consonant)
                } else {
                    letters.append(.weak)
                }
            case "y":
                letters.append(index == chars.count - 1 ? .weak : .consonant)
            default:
                letters.append(.consonant)
            }
        }

        var count = 0
        for index in letters.indices where letters[index] != .consonant {
            guard index > 0, letters[index - 1] != .consonant else {
                count += 1
                continue
            }
            let before = letters[index - 1]
            let current = letters[index]
            let isHiatus = (before == .strong && current == .strong)
                || before == .stressedWeak
                || current == .stressedWeak
            if isHiatus { count += 1 }
        }
        return max(1, count)
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
