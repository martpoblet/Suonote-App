import Foundation
import SwiftUI

// MARK: - Progression Library (A2 + A3)
// Famous chord progressions database + DNA genre analysis

// MARK: - Famous Progression Entry

struct FamousProgression: Identifiable {
    let id = UUID()
    let name: String                        // e.g. "I–V–vi–IV"
    let degrees: [String]                   // Roman numeral degrees
    let genre: [String]                     // genres it appears in
    let mood: [String]                      // emotional descriptors
    let songs: [String]                     // famous songs using it
    let tensionProfile: Double              // 0.0 low tension, 1.0 high
    let complexity: Int                     // 1–5 stars
    let description: String
}

struct ProgressionLibrary {

    // MARK: - Database

    static let progressions: [FamousProgression] = [

        // MARK: POP STAPLES
        FamousProgression(
            name: "I–V–vi–IV",
            degrees: ["I", "V", "vi", "IV"],
            genre: ["Pop", "Rock", "Country"],
            mood: ["Uplifting", "Anthemic", "Happy"],
            songs: ["Let It Be", "Someone Like You", "No Woman No Cry", "Let Her Go"],
            tensionProfile: 0.25,
            complexity: 1,
            description: "The most popular progression in Western pop. Feels complete and satisfying."
        ),
        FamousProgression(
            name: "I–IV–V",
            degrees: ["I", "IV", "V"],
            genre: ["Rock", "Blues", "Country", "Folk"],
            mood: ["Classic", "Energetic", "Simple"],
            songs: ["Johnny B. Goode", "Twist & Shout", "La Bamba"],
            tensionProfile: 0.2,
            complexity: 1,
            description: "The bedrock of rock and blues. Three-chord magic."
        ),
        FamousProgression(
            name: "I–vi–IV–V",
            degrees: ["I", "vi", "IV", "V"],
            genre: ["Pop", "Doo-Wop", "Oldies"],
            mood: ["Nostalgic", "Sweet", "Classic"],
            songs: ["Stand By Me", "Unchained Melody", "Blue Moon"],
            tensionProfile: 0.3,
            complexity: 1,
            description: "The '50s doo-wop classic. Nostalgic and timeless."
        ),
        FamousProgression(
            name: "I–V–vi–iii–IV",
            degrees: ["I", "V", "vi", "iii", "IV"],
            genre: ["Pop", "Rock", "Film"],
            mood: ["Epic", "Cinematic", "Triumphant"],
            songs: ["Pachelbel's Canon", "Axis of Awesome", "Don't Stop Believin'"],
            tensionProfile: 0.3,
            complexity: 2,
            description: "The Canon progression. Used in hundreds of pop songs."
        ),
        FamousProgression(
            name: "ii–V–I",
            degrees: ["ii", "V", "I"],
            genre: ["Jazz", "Bossa Nova", "R&B"],
            mood: ["Sophisticated", "Smooth", "Resolved"],
            songs: ["Autumn Leaves", "Fly Me to the Moon", "All The Things You Are"],
            tensionProfile: 0.45,
            complexity: 2,
            description: "The cornerstone of jazz harmony. The strongest resolution sequence."
        ),
        FamousProgression(
            name: "i–VII–VI–VII",
            degrees: ["i", "VII", "VI", "VII"],
            genre: ["Rock", "Metal", "Pop"],
            mood: ["Dark", "Powerful", "Driving"],
            songs: ["Stairway to Heaven", "Smoke on the Water", "All Along the Watchtower"],
            tensionProfile: 0.55,
            complexity: 2,
            description: "Aeolian rock riff. Dark, powerful, and instantly recognizable."
        ),
        FamousProgression(
            name: "i–VI–III–VII",
            degrees: ["i", "VI", "III", "VII"],
            genre: ["Pop", "R&B", "Ballad"],
            mood: ["Emotional", "Bittersweet", "Longing"],
            songs: ["The Scientist", "Creep", "Numb", "Boulevard of Broken Dreams"],
            tensionProfile: 0.4,
            complexity: 2,
            description: "The modern minor ballad standard. Emotional depth guaranteed."
        ),
        FamousProgression(
            name: "I–IV–I–V",
            degrees: ["I", "IV", "I", "V"],
            genre: ["Gospel", "Blues", "Soul"],
            mood: ["Soulful", "Uplifting", "Warm"],
            songs: ["Oh Happy Day", "Amazing Grace", "Lean On Me"],
            tensionProfile: 0.25,
            complexity: 1,
            description: "Gospel staple. Warm, communal, and spiritually uplifting."
        ),

        // MARK: JAZZ
        FamousProgression(
            name: "I–VI–ii–V",
            degrees: ["I", "VI", "ii", "V"],
            genre: ["Jazz", "Swing", "Standard"],
            mood: ["Sophisticated", "Swinging", "Classic"],
            songs: ["I Got Rhythm", "Blue Moon", "Body and Soul"],
            tensionProfile: 0.5,
            complexity: 3,
            description: "The 'rhythm changes' turnaround. Essential jazz vocabulary."
        ),
        FamousProgression(
            name: "I–♭VII–IV",
            degrees: ["I", "♭VII", "IV"],
            genre: ["Rock", "Mixolydian", "Country"],
            mood: ["Cool", "Modal", "Floating"],
            songs: ["Sweet Home Alabama", "La Grange", "What I Got"],
            tensionProfile: 0.3,
            complexity: 2,
            description: "Mixolydian borrowing. Has that southern rock floating quality."
        ),

        // MARK: SOUL / R&B
        FamousProgression(
            name: "I–♭III–IV–♭VII",
            degrees: ["I", "♭III", "IV", "♭VII"],
            genre: ["Soul", "Funk", "R&B"],
            mood: ["Funky", "Groove", "Soulful"],
            songs: ["Superstition", "Get Lucky", "Use Me"],
            tensionProfile: 0.35,
            complexity: 2,
            description: "Blues-inflected soul groove with borrowed flat chords."
        ),
        FamousProgression(
            name: "i–iv–i–V7",
            degrees: ["i", "iv", "i", "V7"],
            genre: ["Blues", "Jazz", "Soul"],
            mood: ["Blues", "Longing", "Deep"],
            songs: ["12-Bar Blues variations", "Thrill Is Gone", "Red House"],
            tensionProfile: 0.5,
            complexity: 2,
            description: "The essence of blues. The V7 creates that classic blues tension."
        ),

        // MARK: MINOR MOODS
        FamousProgression(
            name: "i–VII–♭VI–V",
            degrees: ["i", "VII", "♭VI", "V"],
            genre: ["Pop", "Rock", "Flamenco"],
            mood: ["Dramatic", "Intense", "Passionate"],
            songs: ["Hit The Road Jack", "Smooth Criminal", "La Macarena"],
            tensionProfile: 0.6,
            complexity: 2,
            description: "Andalusian cadence. Flamenco-inspired descending bass line."
        ),
        FamousProgression(
            name: "i–♭VI–♭III–♭VII",
            degrees: ["i", "♭VI", "♭III", "♭VII"],
            genre: ["Rock", "Alternative", "Pop"],
            mood: ["Dark", "Anthemic", "Emotional"],
            songs: ["Zombie", "All Along the Watchtower", "Mad World"],
            tensionProfile: 0.45,
            complexity: 2,
            description: "Dark minor cycle. Found in many emotional rock anthems."
        ),

        // MARK: COMPLEX / JAZZ MODAL
        FamousProgression(
            name: "ii7–V7–Imaj7",
            degrees: ["ii7", "V7", "Imaj7"],
            genre: ["Jazz", "Neo-Soul", "Bossa Nova"],
            mood: ["Sophisticated", "Lush", "Complex"],
            songs: ["Girl From Ipanema", "Fly Me to the Moon", "Misty"],
            tensionProfile: 0.5,
            complexity: 3,
            description: "Jazzy ii-V-I with 7th chords. Rich harmonic color."
        ),
        FamousProgression(
            name: "I–II–IV–I",
            degrees: ["I", "II", "IV", "I"],
            genre: ["Pop", "Gospel", "Soul"],
            mood: ["Bright", "Surprising", "Open"],
            songs: ["Here Comes the Sun", "You Are the Sunshine", "Lovely Day"],
            tensionProfile: 0.3,
            complexity: 2,
            description: "Using the major II (borrowed) gives a bright, surprising lift."
        ),
        FamousProgression(
            name: "I–♭VI–♭VII–I",
            degrees: ["I", "♭VI", "♭VII", "I"],
            genre: ["Rock", "Pop", "Electronic"],
            mood: ["Epic", "Modern", "Powerful"],
            songs: ["Where the Streets Have No Name", "With or Without You"],
            tensionProfile: 0.35,
            complexity: 2,
            description: "Modal mixture with borrowed ♭VI and ♭VII. Epic, stadium-sized."
        ),

        // MARK: CHILL / LO-FI
        FamousProgression(
            name: "Imaj7–vi7–ii7–V7",
            degrees: ["Imaj7", "vi7", "ii7", "V7"],
            genre: ["Lo-Fi", "Jazz", "Chill"],
            mood: ["Relaxed", "Dreamy", "Sophisticated"],
            songs: ["Various lo-fi jazz standards"],
            tensionProfile: 0.3,
            complexity: 3,
            description: "Lush 7th chord cycle. The definition of lo-fi jazz aesthetic."
        ),
    ]

    // MARK: - DNA Analysis (A2)

    struct ProgressionDNA {
        let genreAffinities: [(genre: String, percentage: Double)]
        let closestProgressions: [FamousProgression]
        let primaryMood: String
        let complexityScore: Int
        let uniquenessScore: Double   // 0.0 = very common, 1.0 = very unique
    }

    /// Analyze a set of chord progressions and return genre/mood DNA
    static func analyzeDNA(chords: [(root: String, quality: ChordQuality)],
                            keyRoot: String, mode: KeyMode) -> ProgressionDNA {
        guard !chords.isEmpty else {
            return ProgressionDNA(genreAffinities: [], closestProgressions: [],
                                   primaryMood: "N/A", complexityScore: 1, uniquenessScore: 0.5)
        }

        // Build Roman numeral sequence
        let romanNumerals = chords.map {
            TempoUtils.romanNumeral(root: $0.root, quality: $0.quality, keyRoot: keyRoot, mode: mode)
        }

        // Count genre votes from matching progressions
        var genreVotes: [String: Double] = [:]
        var closestMatches: [(prog: FamousProgression, similarity: Double)] = []

        for prog in progressions {
            let similarity = sequenceSimilarity(romanNumerals, prog.degrees)
            if similarity > 0.2 {
                closestMatches.append((prog, similarity))
                for genre in prog.genre {
                    genreVotes[genre, default: 0] += similarity
                }
            }
        }

        // Normalize genre votes
        let totalVotes = genreVotes.values.reduce(0, +)
        let genreAffinities = genreVotes
            .map { (genre: $0.key, percentage: totalVotes > 0 ? $0.value / totalVotes : 0) }
            .sorted { $0.percentage > $1.percentage }
            .prefix(5)
            .map { $0 }

        // Closest progressions
        let top = closestMatches.sorted { $0.similarity > $1.similarity }.prefix(3).map { $0.prog }

        // Complexity from chord quality variety
        let uniqueQualities = Set(chords.map { $0.quality })
        let complexityScore = min(5, max(1, uniqueQualities.count))

        // Uniqueness: inverse of max similarity
        let maxSimilarity = closestMatches.map { $0.similarity }.max() ?? 0.0
        let uniqueness = 1.0 - maxSimilarity

        // Primary mood from top match
        let primaryMood = top.first.flatMap { $0.mood.first } ?? "Original"

        return ProgressionDNA(
            genreAffinities: genreAffinities,
            closestProgressions: Array(top),
            primaryMood: primaryMood,
            complexityScore: complexityScore,
            uniquenessScore: uniqueness
        )
    }

    /// Simple sequence similarity score (Jaccard-like over degree overlap)
    private static func sequenceSimilarity(_ a: [String], _ b: [String]) -> Double {
        let setA = Set(a.map { normalizeRoman($0) })
        let setB = Set(b.map { normalizeRoman($0) })
        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count
        guard union > 0 else { return 0 }
        let jaccard = Double(intersection) / Double(union)

        // Bonus for matching order
        var orderBonus = 0.0
        let minLen = min(a.count, b.count)
        for i in 0..<minLen {
            if normalizeRoman(a[i]) == normalizeRoman(b[i]) { orderBonus += 1 }
        }
        let orderScore = minLen > 0 ? orderBonus / Double(minLen) : 0

        return (jaccard * 0.6 + orderScore * 0.4)
    }

    private static func normalizeRoman(_ s: String) -> String {
        // Strip quality suffixes to compare root degree only
        var result = s
        for suffix in ["maj7", "m7", "7", "Δ", "+", "°", "ø", "sus2", "sus4"] {
            result = result.replacingOccurrences(of: suffix, with: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Progression Library View (A3)

struct ProgressionLibraryView: View {
    var onSelectProgression: ((FamousProgression) -> Void)? = nil
    @State private var searchText = ""
    @State private var selectedGenre: String? = nil
    @State private var selectedMood: String? = nil
    @Environment(\.dismiss) private var dismiss

    private var allGenres: [String] {
        Array(Set(ProgressionLibrary.progressions.flatMap { $0.genre })).sorted()
    }

    private var filtered: [FamousProgression] {
        var list = ProgressionLibrary.progressions
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.songs.joined().localizedCaseInsensitiveContains(searchText) ||
                $0.genre.joined().localizedCaseInsensitiveContains(searchText)
            }
        }
        if let genre = selectedGenre {
            list = list.filter { $0.genre.contains(genre) }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Genre filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        GenreChip(label: "All", isSelected: selectedGenre == nil) {
                            selectedGenre = nil
                        }
                        ForEach(allGenres, id: \.self) { genre in
                            GenreChip(label: genre, isSelected: selectedGenre == genre) {
                                selectedGenre = selectedGenre == genre ? nil : genre
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }

                Divider().overlay(DesignSystem.Colors.border)

                // Progressions list
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(filtered) { prog in
                            progressionCard(prog)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .searchable(text: $searchText, prompt: "Search progressions, songs...")
            .navigationTitle("Progression Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func progressionCard(_ prog: FamousProgression) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                // Name + degrees
                VStack(alignment: .leading, spacing: 3) {
                    Text(prog.name)
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    HStack(spacing: 4) {
                        ForEach(prog.degrees, id: \.self) { deg in
                            Text(deg)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.primaryDark)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(
                                    Capsule().fill(DesignSystem.Colors.primary.opacity(0.12))
                                )
                        }
                    }
                }

                Spacer()

                // Complexity stars
                HStack(spacing: 2) {
                    ForEach(0..<prog.complexity, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(DesignSystem.Colors.warning)
                    }
                    ForEach(prog.complexity..<5, id: \.self) { _ in
                        Image(systemName: "star")
                            .font(.system(size: 9))
                            .foregroundStyle(DesignSystem.Colors.border)
                    }
                }
            }

            Text(prog.description)
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(2)

            // Genres
            HStack(spacing: 4) {
                ForEach(prog.genre.prefix(3), id: \.self) { g in
                    Text(g)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            Capsule().fill(DesignSystem.Colors.surfaceSecondary)
                        )
                }
            }

            // Songs
            Text("♪ " + prog.songs.prefix(2).joined(separator: " · "))
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .lineLimit(1)

            // Select button
            if let onSelect = onSelectProgression {
                Button {
                    onSelect(prog)
                    dismiss()
                } label: {
                    Text("Use this progression")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
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
}

// MARK: - Progression DNA View (A2)

struct ProgressionDNAView: View {
    let project: Project

    private var allChords: [(root: String, quality: ChordQuality)] {
        project.sectionTemplates.flatMap { section in
            section.chordEvents.filter { !$0.isRest }.map { ($0.root, $0.quality) }
        }
    }

    private var dna: ProgressionLibrary.ProgressionDNA {
        ProgressionLibrary.analyzeDNA(
            chords: allChords,
            keyRoot: project.keyRoot,
            mode: project.keyMode
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if allChords.isEmpty {
                Text("Add chords to see your progression DNA.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            } else {
                // Genre affinities
                Text("Genre Affinities")
                    .font(DesignSystem.Typography.calloutBold)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                ForEach(dna.genreAffinities.prefix(4), id: \.genre) { aff in
                    HStack {
                        Text(aff.genre)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 80, alignment: .leading)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.border)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(genreColor(aff.genre))
                                .frame(width: max(CGFloat(aff.percentage) * 180, 4), height: 8)
                        }
                        .frame(width: 180)

                        Text("\(Int(aff.percentage * 100))%")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                Divider().overlay(DesignSystem.Colors.border)

                // Closest matching progressions
                if !dna.closestProgressions.isEmpty {
                    Text("Similar Progressions")
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    ForEach(dna.closestProgressions) { prog in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prog.name)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text(prog.songs.first ?? "")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(prog.genre.first ?? "")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Spacing.xs)
                    }
                }

                // Stats
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complexity")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        HStack(spacing: 2) {
                            ForEach(0..<dna.complexityScore, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DesignSystem.Colors.warning)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uniqueness")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Text("\(Int(dna.uniquenessScore * 100))%")
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mood")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Text(dna.primaryMood)
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
    }

    private func genreColor(_ genre: String) -> Color {
        let colors: [String: Color] = [
            "Pop": DesignSystem.Colors.primary,
            "Rock": DesignSystem.Colors.error,
            "Jazz": DesignSystem.Colors.accent,
            "Blues": DesignSystem.Colors.info,
            "Soul": DesignSystem.Colors.warning,
            "Folk": DesignSystem.Colors.success,
            "R&B": DesignSystem.Colors.sectionBerry,
            "Lo-Fi": DesignSystem.Colors.sectionLavender,
            "Metal": DesignSystem.Colors.textSecondary,
            "Country": DesignSystem.Colors.sectionSand,
        ]
        return colors[genre] ?? DesignSystem.Colors.primary
    }
}

// MARK: - Helper: Genre Chip

private struct GenreChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                )
                .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
