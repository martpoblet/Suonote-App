import Foundation
import SwiftUI

// MARK: - Lyric Assistant (L1 + L2 + L4)
// Provides: syllable counting, rhyme detection, rhyme suggestions, and lyric structure templates.

struct LyricAssistant {

    // MARK: - L1: Syllable Counting

    /// Count syllables in a single word using vowel-group heuristics
    static func syllableCount(in word: String) -> Int {
        let letters = word.lowercased().filter { $0.isLetter }
        guard !letters.isEmpty else { return 0 }

        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        var count = 0
        var prevWasVowel = false

        for char in letters {
            let isVowel = vowels.contains(char)
            if isVowel && !prevWasVowel { count += 1 }
            prevWasVowel = isVowel
        }

        // Silent 'e' at end (e.g., "make", "love")
        if letters.hasSuffix("e") && count > 1 {
            count -= 1
        }

        // -le suffix with preceding consonant (e.g., "sim-ple", "gen-tle")
        if letters.count > 3 && letters.hasSuffix("le") {
            let charBeforeLe = letters[letters.index(letters.endIndex, offsetBy: -3)]
            if !vowels.contains(charBeforeLe) { count += 1 }
        }

        // Common multi-vowel patterns that form one syllable
        let singleVowelPatterns = ["tion", "sion", "ious", "eous", "uous"]
        for pattern in singleVowelPatterns where letters.hasSuffix(pattern) {
            count = max(count, 1)
        }

        return max(1, count)
    }

    /// Count syllables in a full line of text
    static func syllableCount(inLine line: String) -> Int {
        line.split(separator: " ")
            .map { syllableCount(in: String($0)) }
            .reduce(0, +)
    }

    /// Returns (line, syllable count) pairs for a full lyrics text
    static func syllablesPerLine(_ text: String) -> [(line: String, count: Int)] {
        text.components(separatedBy: "\n").map {
            (line: $0, count: syllableCount(inLine: $0))
        }
    }

    /// Pattern description for a syllable array (iambic, trochaic, free)
    static func meterDescription(for syllableCounts: [Int]) -> String {
        let nonEmpty = syllableCounts.filter { $0 > 0 }
        guard !nonEmpty.isEmpty else { return "No text" }
        let avg = Double(nonEmpty.reduce(0, +)) / Double(nonEmpty.count)
        if abs(avg - 10) < 2 { return "Iambic pentameter (~10 syl/line)" }
        if abs(avg - 8) < 1.5 { return "Common meter (~8 syl/line)" }
        if abs(avg - 6) < 1.5 { return "Short meter (~6 syl/line)" }
        if abs(avg - 12) < 2 { return "Alexandrine (~12 syl/line)" }
        return "Free verse"
    }

    // MARK: - L2: Rhyme Detection

    /// Extract the rhyming ending of a word (last stressed vowel + consonants)
    static func rhymingEnding(of word: String) -> String {
        let cleaned = word.lowercased().filter { $0.isLetter }
        guard !cleaned.isEmpty else { return "" }
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]

        // Find last vowel
        var lastVowelIdx: String.Index? = nil
        for idx in cleaned.indices.reversed() {
            if vowels.contains(cleaned[idx]) {
                lastVowelIdx = idx
                break
            }
        }
        guard let idx = lastVowelIdx else { return String(cleaned.suffix(2)) }
        return String(cleaned[idx...])
    }

    /// Extract last meaningful word from a line
    static func lastWord(of line: String) -> String {
        let words = line.components(separatedBy: .whitespaces)
            .map { $0.filter { $0.isLetter || $0 == "'" } }
            .filter { !$0.isEmpty }
        return words.last?.lowercased() ?? ""
    }

    /// Detect rhyme scheme for an array of lines (returns e.g. "ABAB")
    static func rhymeScheme(lines: [String]) -> String {
        var scheme: [String] = []
        var groupToLetter: [String: String] = [:]
        var nextCharCode: UInt32 = 65 // 'A'

        for line in lines {
            let word = lastWord(of: line)
            guard !word.isEmpty else { scheme.append("-"); continue }
            let ending = rhymingEnding(of: word)

            if let existing = groupToLetter[ending] {
                scheme.append(existing)
            } else {
                let letter = String(UnicodeScalar(nextCharCode)!)
                groupToLetter[ending] = letter
                scheme.append(letter)
                nextCharCode += 1
            }
        }
        return scheme.joined()
    }

    /// Suggest rhyming words for a given word
    static func rhymeSuggestions(for word: String, maxCount: Int = 8) -> [String] {
        let ending = rhymingEnding(of: word)
        let target = word.lowercased()
        guard !ending.isEmpty else { return [] }

        // Comprehensive rhyme pool
        let rhymePool: [String: [String]] = [
            "ay": ["day", "say", "way", "play", "stay", "ray", "may", "bay", "gray", "pray", "sway", "clay"],
            "ight": ["night", "light", "right", "might", "fight", "sight", "bright", "flight", "delight", "tonight"],
            "ove": ["love", "above", "dove", "shove", "of"],
            "ive": ["live", "give", "forgive", "thrive", "alive", "drive", "strive"],
            "ine": ["mine", "fine", "line", "shine", "divine", "wine", "pine", "nine", "combine", "define"],
            "ame": ["flame", "name", "game", "frame", "same", "came", "blame", "shame", "claim", "tame"],
            "ound": ["sound", "found", "ground", "around", "bound", "wound", "profound", "surround"],
            "old": ["bold", "cold", "gold", "hold", "told", "fold", "sold", "unfold", "behold"],
            "ong": ["song", "long", "strong", "belong", "along", "wrong", "among"],
            "art": ["heart", "start", "part", "apart", "dark", "spark", "art", "smart"],
            "ow": ["know", "show", "flow", "glow", "grow", "below", "slow", "though", "go", "so"],
            "ee": ["free", "see", "be", "me", "tree", "feel", "real", "dream", "believe"],
            "ore": ["more", "before", "door", "shore", "floor", "core", "ignore", "explore", "adore"],
            "ake": ["take", "make", "break", "shake", "wake", "lake", "ache", "mistake", "forsake"],
            "ell": ["tell", "well", "fell", "shell", "spell", "bell", "dwell", "farewell"],
            "ead": ["head", "dead", "bread", "instead", "spread", "thread", "lead", "ahead"],
            "est": ["best", "rest", "chest", "blessed", "quest", "test", "nest", "crest"],
            "ind": ["mind", "find", "kind", "blind", "behind", "wind", "signed", "remind", "unwind"],
            "ire": ["fire", "desire", "inspire", "higher", "entire", "admire", "empire"],
            "ule": ["rule", "fool", "cool", "school", "pool", "tool", "fuel"],
            "ide": ["side", "ride", "guide", "hide", "inside", "decide", "pride", "wide"],
            "ame": ["came", "name", "blame", "fame", "flame", "game", "same", "tame"],
            "ost": ["lost", "cost", "most", "ghost", "host", "close", "trust"],
            "eed": ["need", "feel", "heal", "real", "deal", "seal", "reveal", "appeal"],
            "ack": ["back", "black", "track", "lack", "crack", "pack", "attack", "stack"],
            "own": ["down", "town", "crown", "brown", "around", "frown", "gown"],
            "all": ["call", "fall", "wall", "tall", "hall", "recall", "small", "stall"],
            "ive": ["live", "give", "alive", "thrive", "drive", "survive", "arrive"],
            "un": ["run", "sun", "gun", "done", "one", "fun", "begun", "won"],
            "ove": ["love", "above", "dove", "shove", "of", "enough"],
            "ight": ["night", "light", "right", "bright", "sight", "fight", "might"],
        ]

        var results: [String] = []
        for (key, words) in rhymePool {
            if ending.hasSuffix(key) || key.hasSuffix(ending) || ending == key {
                results += words.filter { $0 != target }
            }
        }

        // Also match by common ending characters
        let suffixLen = min(3, ending.count)
        let endSuffix = String(ending.suffix(suffixLen))
        for (_, words) in rhymePool {
            for w in words where !results.contains(w) && w != target {
                let wEnding = rhymingEnding(of: w)
                if wEnding.hasSuffix(endSuffix) || endSuffix.hasSuffix(wEnding) {
                    results.append(w)
                }
            }
        }

        return Array(Set(results)).prefix(maxCount).sorted()
    }

    // MARK: - L4: Lyric Templates

    struct LyricTemplate: Identifiable {
        let id = UUID()
        let name: String
        let scheme: String           // e.g. "ABAB"
        let category: String         // "Verse", "Chorus", "Bridge"
        let description: String
        let lineCount: Int
        let example: [String]        // example lines
        let icon: String
    }

    static let templates: [LyricTemplate] = [
        // Verse templates
        LyricTemplate(
            name: "AABB — Couplets",
            scheme: "AABB",
            category: "Verse",
            description: "Pairs of rhyming lines. Simple, catchy, and easy to sing.",
            lineCount: 4,
            example: [
                "I walked into the night",
                "The stars were shining bright",
                "I heard a distant sound",
                "My heart was tightly wound"
            ],
            icon: "1.circle"
        ),
        LyricTemplate(
            name: "ABAB — Alternating",
            scheme: "ABAB",
            category: "Verse",
            description: "Alternating rhyme scheme. Great for storytelling verses.",
            lineCount: 4,
            example: [
                "I found you in the rain",
                "Beneath the fading light",
                "You whispered through my pain",
                "And everything felt right"
            ],
            icon: "2.circle"
        ),
        LyricTemplate(
            name: "ABCB — Ballad",
            scheme: "ABCB",
            category: "Verse",
            description: "Only lines 2 & 4 rhyme. Natural speech rhythm.",
            lineCount: 4,
            example: [
                "There's a place I used to go",
                "Deep in the woods alone",
                "Where the river meets the hill",
                "And makes a singing tone"
            ],
            icon: "3.circle"
        ),
        LyricTemplate(
            name: "ABBA — Envelope",
            scheme: "ABBA",
            category: "Verse",
            description: "Outer lines frame the inner rhyming pair. Creates depth.",
            lineCount: 4,
            example: [
                "Standing in the cold",
                "The silence speaks to me",
                "I'm searching for the key",
                "To a story untold"
            ],
            icon: "4.circle"
        ),
        // Chorus templates
        LyricTemplate(
            name: "AABB — Power Chorus",
            scheme: "AABB",
            category: "Chorus",
            description: "Direct rhyming pairs. Maximum impact for chorus.",
            lineCount: 4,
            example: [
                "We are the fire burning bright",
                "We're standing tall with all our might",
                "Together we will never fall",
                "One voice, one heart, one single call"
            ],
            icon: "star"
        ),
        LyricTemplate(
            name: "AAAA — Monorhyme",
            scheme: "AAAA",
            category: "Chorus",
            description: "All lines rhyme. Bold, anthemic feel.",
            lineCount: 4,
            example: [
                "Everything fades away",
                "Words I forgot to say",
                "Heading into the gray",
                "Gone at the end of day"
            ],
            icon: "star.fill"
        ),
        LyricTemplate(
            name: "AABA — Hook",
            scheme: "AABA",
            category: "Chorus",
            description: "Classic pop hook structure. Highly memorable.",
            lineCount: 4,
            example: [
                "Someday I'll find my way",
                "Through all this disarray",
                "But for now I just wait",
                "For a brand new day"
            ],
            icon: "music.note"
        ),
        // Bridge templates
        LyricTemplate(
            name: "Free Verse — Break",
            scheme: "ABCD",
            category: "Bridge",
            description: "No rhyme required. Focus on emotion and imagery.",
            lineCount: 4,
            example: [
                "The morning comes slow",
                "Like honey dripping from a spoon",
                "I remember your voice",
                "And the way you said nothing"
            ],
            icon: "waveform"
        ),
        LyricTemplate(
            name: "ABAB — Contrast Bridge",
            scheme: "ABAB",
            category: "Bridge",
            description: "Alternating rhyme that shifts the emotional perspective.",
            lineCount: 4,
            example: [
                "Maybe I was wrong",
                "To think that you would stay",
                "All this time I've held on",
                "To what has slipped away"
            ],
            icon: "arrow.left.arrow.right"
        ),
        LyricTemplate(
            name: "Verse + Couplet",
            scheme: "ABABCC",
            category: "Verse",
            description: "4 alternating lines + closing rhyming couplet (Shakespearean).",
            lineCount: 6,
            example: [
                "The city lights at night",
                "Reflect on glass and steel",
                "Something doesn't feel right",
                "A numbness I can feel",
                "But still I hold on tight",
                "And let the rhythm heal"
            ],
            icon: "6.circle"
        )
    ]

    /// Returns grouped templates by category
    static var templatesByCategory: [(category: String, templates: [LyricTemplate])] {
        let categories = ["Verse", "Chorus", "Bridge"]
        return categories.compactMap { cat in
            let group = templates.filter { $0.category == cat }
            return group.isEmpty ? nil : (category: cat, templates: group)
        }
    }

    /// Analyze a text and return a detailed lyric report
    static func analyze(_ text: String) -> LyricAnalysis {
        let lines = text.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let syllableCounts = nonEmpty.map { syllableCount(inLine: $0) }
        let scheme = nonEmpty.count >= 2 ? rhymeScheme(lines: nonEmpty) : ""
        let meter = meterDescription(for: syllableCounts)
        let totalSyllables = syllableCounts.reduce(0, +)
        let wordCount = text.split { !$0.isLetter && $0 != "'" }.count

        return LyricAnalysis(
            lineCount: nonEmpty.count,
            wordCount: wordCount,
            totalSyllables: totalSyllables,
            syllablesPerLine: zip(nonEmpty, syllableCounts).map { ($0, $1) },
            rhymeScheme: scheme,
            meter: meter
        )
    }
}

struct LyricAnalysis {
    let lineCount: Int
    let wordCount: Int
    let totalSyllables: Int
    let syllablesPerLine: [(line: String, count: Int)]
    let rhymeScheme: String
    let meter: String

    var avgSyllablesPerLine: Double {
        guard lineCount > 0 else { return 0 }
        return Double(totalSyllables) / Double(lineCount)
    }
}

// MARK: - Syllable Counter View (L1)

struct SyllableCounterView: View {
    let text: String

    private var analysis: [(line: String, count: Int)] {
        LyricAssistant.syllablesPerLine(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(analysis.enumerated()), id: \.offset) { _, pair in
                if !pair.line.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(pair.line)
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(pair.count)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(syllableColor(pair.count))
                            .frame(minWidth: 24)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(
                                Capsule().fill(syllableColor(pair.count).opacity(0.15))
                            )
                    }
                }
            }
        }
    }

    private func syllableColor(_ count: Int) -> Color {
        if count <= 6 { return DesignSystem.Colors.success }
        if count <= 10 { return DesignSystem.Colors.primary }
        if count <= 14 { return DesignSystem.Colors.warning }
        return DesignSystem.Colors.error
    }
}

// MARK: - Rhyme Finder View (L2)

struct RhymeFinderView: View {
    let text: String
    @State private var selectedWord: String = ""
    @State private var rhymes: [String] = []
    @State private var customWord: String = ""

    private var lastWords: [String] {
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Array(Set(lines.map { LyricAssistant.lastWord(of: $0) })).filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Scheme display
            let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if lines.count >= 2 {
                let scheme = LyricAssistant.rhymeScheme(lines: lines)
                HStack {
                    Text("Rhyme Scheme:")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text(scheme)
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }

            Divider().overlay(DesignSystem.Colors.border)

            // Word selector
            Text("Find rhymes for:")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            // Custom word input
            HStack {
                TextField("Type a word...", text: $customWord)
                    .font(DesignSystem.Typography.body)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if !customWord.isEmpty {
                            selectedWord = customWord
                            rhymes = LyricAssistant.rhymeSuggestions(for: customWord)
                        }
                    }
                if !customWord.isEmpty {
                    Button { customWord = ""; rhymes = [] } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(DesignSystem.Colors.surfaceSecondary)
            )

            // Quick-pick from line endings
            if !lastWords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(lastWords, id: \.self) { word in
                            Button(word) {
                                selectedWord = word
                                customWord = word
                                rhymes = LyricAssistant.rhymeSuggestions(for: word)
                            }
                            .font(DesignSystem.Typography.caption)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selectedWord == word ?
                                          DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                            )
                            .foregroundStyle(selectedWord == word ? .white : DesignSystem.Colors.textPrimary)
                        }
                    }
                }
            }

            // Rhyme results
            if !rhymes.isEmpty {
                Text("Rhymes with \"\(selectedWord)\"")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 6) {
                    ForEach(rhymes, id: \.self) { rhyme in
                        Text(rhyme)
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DesignSystem.Colors.primary.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
            } else if !selectedWord.isEmpty {
                Text("No common rhymes found. Try a different word.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
    }
}

// MARK: - Lyric Template Picker (L4)

struct LyricTemplatePicker: View {
    let onSelect: (LyricAssistant.LyricTemplate) -> Void
    @State private var selectedCategory: String = "Verse"
    @Environment(\.dismiss) private var dismiss

    private let categories = ["Verse", "Chorus", "Bridge"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .padding(DesignSystem.Spacing.md)

                // Templates list
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        let filtered = LyricAssistant.templates.filter { $0.category == selectedCategory }
                        ForEach(filtered) { template in
                            templateCard(template)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Lyric Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func templateCard(_ template: LyricAssistant.LyricTemplate) -> some View {
        Button {
            onSelect(template)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: template.icon)
                        .foregroundStyle(DesignSystem.Colors.primary)
                    Text(template.name)
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text(template.scheme)
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            Capsule().fill(DesignSystem.Colors.primary.opacity(0.15))
                        )
                }

                Text(template.description)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                // Example lines (first 2)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(template.example.prefix(2), id: \.self) { line in
                        Text("   " + line)
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .italic()
                    }
                    if template.example.count > 2 {
                        Text("   ···")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                )
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animatedPress()
    }
}
