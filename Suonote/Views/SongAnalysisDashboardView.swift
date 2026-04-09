import SwiftUI
import SwiftData

// MARK: - Song Analysis Dashboard (A1 + A2 + A3)
// Comprehensive analysis panel: Song Score, Progression DNA, and Famous Progressions Library.

struct SongAnalysisDashboardView: View {
    let project: Project
    @State private var selectedTab: AnalysisTab = .score
    @State private var showProgressionLibrary = false

    enum AnalysisTab: String, CaseIterable {
        case score = "Score"
        case dna = "DNA"
        case library = "Library"

        var icon: String {
            switch self {
            case .score: return "chart.bar.fill"
            case .dna: return "waveform.path.ecg"
            case .library: return "books.vertical.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            HStack(spacing: 0) {
                ForEach(AnalysisTab.allCases, id: \.rawValue) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.rawValue)
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundStyle(selectedTab == tab ?
                                         DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 0) {
                    ForEach(AnalysisTab.allCases, id: \.rawValue) { tab in
                        Rectangle()
                            .fill(selectedTab == tab ? DesignSystem.Colors.primary : Color.clear)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider().overlay(DesignSystem.Colors.border)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .score: songScoreView
                    case .dna: dnaView
                    case .library: progressionLibraryButton
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
        .sheet(isPresented: $showProgressionLibrary) {
            ProgressionLibraryView()
        }
    }

    // MARK: - A1: Song Score

    private var songScore: SongScore { SongScore(project: project) }

    private var songScoreView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {

            // Overall Score ring
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(DesignSystem.Colors.border, lineWidth: 10)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: CGFloat(songScore.overall) / 100)
                        .stroke(
                            AngularGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.accent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(songScore.overall))")
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("/ 100")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                Spacer()
            }

            // Score breakdown
            VStack(spacing: DesignSystem.Spacing.sm) {
                scoreRow(label: "Harmonic Richness", value: songScore.harmonicRichness,
                         icon: "music.note", color: DesignSystem.Colors.primary)
                scoreRow(label: "Structural Variety", value: songScore.structuralVariety,
                         icon: "square.grid.3x3", color: DesignSystem.Colors.accent)
                scoreRow(label: "Tension Arc", value: songScore.tensionArc,
                         icon: "waveform", color: DesignSystem.Colors.info)
                scoreRow(label: "Lyric Density", value: songScore.lyricDensity,
                         icon: "text.quote", color: DesignSystem.Colors.success)
                scoreRow(label: "Section Balance", value: songScore.sectionBalance,
                         icon: "arrow.left.arrow.right", color: DesignSystem.Colors.warning)
            }

            Divider().overlay(DesignSystem.Colors.border)

            // Recommendations
            if !songScore.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Suggestions")
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    ForEach(songScore.recommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "lightbulb.fill")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.warning)
                            Text(rec)
                                .font(DesignSystem.Typography.callout)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                    }
                }
            }

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                statCell(label: "Total Chords", value: "\(songScore.totalChords)")
                statCell(label: "Unique Chords", value: "\(songScore.uniqueChords)")
                statCell(label: "Sections", value: "\(songScore.sectionCount)")
                statCell(label: "Diatonic %", value: "\(Int(songScore.diatonicPercent))%")
                statCell(label: "Total Bars", value: "\(songScore.totalBars)")
                statCell(label: "Has Lyrics", value: songScore.hasLyrics ? "Yes" : "No")
            }
        }
    }

    private func scoreRow(label: String, value: Double, icon: String, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 140, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.border)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(CGFloat(value / 100) * 100, 2), height: 8)
            }
            .frame(width: 100)

            Text("\(Int(value))")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.primary)
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
    }

    // MARK: - A2: Progression DNA

    private var dnaView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your Progression DNA")
                .font(DesignSystem.Typography.bodyBold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.bottom, DesignSystem.Spacing.sm)

            ProgressionDNAView(project: project)
        }
    }

    // MARK: - A3: Progression Library

    private var progressionLibraryButton: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 40))
                .foregroundStyle(DesignSystem.Colors.primary)
                .padding(.top, DesignSystem.Spacing.xl)

            Text("Progression Library")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Browse \(ProgressionLibrary.progressions.count) famous progressions across Pop, Jazz, Blues, Rock and more.")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showProgressionLibrary = true
            } label: {
                Text("Open Library")
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .fill(DesignSystem.Colors.primary)
                    )
            }
            .buttonStyle(.plain)
            .animatedPress()
            .padding(.top, DesignSystem.Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }
}

// MARK: - Song Score Calculator (A1)

struct SongScore {
    let project: Project

    var harmonicRichness: Double {
        let chords = allChords
        guard !chords.isEmpty else { return 0 }
        let uniqueQualities = Set(chords.map { $0.quality }).count
        let uniqueRoots = Set(chords.map { $0.root }).count
        let score = Double(uniqueQualities) / 8.0 * 50 + Double(uniqueRoots) / 12.0 * 50
        return min(100, score)
    }

    var structuralVariety: Double {
        let sectionCount = project.sectionTemplates.count
        let arrangementCount = project.arrangementItems.count
        if sectionCount == 0 { return 0 }
        let uniqueNames = Set(project.sectionTemplates.map { $0.name }).count
        let score = Double(uniqueNames) / 5.0 * 50 + Double(min(arrangementCount, 8)) / 8.0 * 50
        return min(100, score)
    }

    var tensionArc: Double {
        let arc = HarmonicTensionAnalyzer.tensionArc(for: project)
        guard arc.points.count >= 3 else { return 0 }
        // Good arc = variety in tension (not flat)
        return min(100, arc.tensionVariety * 200)
    }

    var lyricDensity: Double {
        let sections = project.sectionTemplates
        guard !sections.isEmpty else { return 0 }
        let withLyrics = sections.filter { !$0.lyricsText.isEmpty }.count
        let avgLen = sections.filter { !$0.lyricsText.isEmpty }
            .map { Double($0.lyricsText.count) }.reduce(0, +) / Double(max(1, withLyrics))
        let coverage = Double(withLyrics) / Double(sections.count) * 60
        let density = min(40, avgLen / 200 * 40)
        return min(100, coverage + density)
    }

    var sectionBalance: Double {
        let items = project.arrangementItems
        guard !items.isEmpty else { return 0 }
        let sectionCounts = Dictionary(grouping: items) { $0.sectionTemplate?.id }
            .values.map { Double($0.count) }
        guard !sectionCounts.isEmpty else { return 0 }
        let avg = sectionCounts.reduce(0, +) / Double(sectionCounts.count)
        let variance = sectionCounts.map { pow($0 - avg, 2) }.reduce(0, +) / Double(sectionCounts.count)
        return max(0, 100 - variance * 10)
    }

    var overall: Double {
        (harmonicRichness + structuralVariety + tensionArc + lyricDensity + sectionBalance) / 5.0
    }

    var recommendations: [String] {
        var recs: [String] = []
        if harmonicRichness < 30 { recs.append("Try adding more chord variety — 7th chords and borrowed chords add richness.") }
        if structuralVariety < 40 { recs.append("Add distinct section types (Verse, Chorus, Bridge) to create contrast.") }
        if tensionArc < 30 { recs.append("Vary the tension — build up to the chorus, then resolve at the end.") }
        if lyricDensity < 30 { recs.append("Add lyrics to your sections to give the song more emotional shape.") }
        if sectionBalance < 50 { recs.append("Balance section repetition — chorus can repeat more, bridge should appear once.") }
        return Array(recs.prefix(3))
    }

    // Stats
    var totalChords: Int { allChords.count }
    var uniqueChords: Int { Set(allChords.map { $0.root + $0.quality.symbol }).count }
    var sectionCount: Int { project.sectionTemplates.count }
    var totalBars: Int { project.sectionTemplates.map { $0.bars }.reduce(0, +) }
    var hasLyrics: Bool { project.sectionTemplates.contains { !$0.lyricsText.isEmpty } }
    var diatonicPercent: Double {
        let chords = allChords
        guard !chords.isEmpty else { return 0 }
        let diatonic = chords.filter {
            HarmonicTensionAnalyzer.isChordDiatonic(
                root: $0.root, quality: $0.quality,
                keyRoot: project.keyRoot, mode: project.keyMode)
        }.count
        return Double(diatonic) / Double(chords.count) * 100
    }

    private var allChords: [(root: String, quality: ChordQuality)] {
        project.sectionTemplates.flatMap { s in
            s.chordEvents.filter { !$0.isRest }.map { ($0.root, $0.quality) }
        }
    }
}

