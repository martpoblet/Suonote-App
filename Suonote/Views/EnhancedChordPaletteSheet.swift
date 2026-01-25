import SwiftUI

struct EnhancedChordPaletteSheet: View {
    let project: Project
    let section: SectionTemplate
    @Binding var isPresented: Bool
    
    let onChordSelected: (String, ChordQuality) -> Void
    
    @State private var selectedTab: PaletteTab = .smart
    @State private var selectedCategory: ChordCategory = .triad
    @State private var selectedRoot: String = "C"
    
    enum PaletteTab: String, CaseIterable {
        case smart = "Smart"
        case all = "All Chords"
        case analysis = "Analysis"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Tabs
            tabSelector
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Divider()
                .background(DesignSystem.Colors.border)
                .padding(.vertical, DesignSystem.Spacing.sm)
            
            // Content
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    switch selectedTab {
                    case .smart:
                        smartSuggestionsSection
                    case .all:
                        allChordsSection
                    case .analysis:
                        analysisSection
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
        }
        .background(DesignSystem.Colors.backgroundSecondary)
        
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Chord Palette")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: DesignSystem.Icons.key)
                        .font(DesignSystem.Typography.caption)
                    Text("\(project.keyRoot) \(project.keyMode == .major ? "Major" : "Minor")")
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundTertiary)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(PaletteTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(DesignSystem.Spacing.xxs)
        .glassStyle(cornerRadius: DesignSystem.CornerRadius.lg)
    }
    
    private func tabButton(_ tab: PaletteTab) -> some View {
        Button {
            withAnimation(DesignSystem.Animations.smoothSpring) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(selectedTab == tab ? DesignSystem.Colors.backgroundSecondary : DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    selectedTab == tab ?
                        AnyView(Capsule().fill(DesignSystem.Colors.primary)) :
                        AnyView(Color.clear)
                )
        }
    }
    
    // MARK: - Smart Suggestions
    
    private var smartSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Contextual suggestions
            contextualSuggestionsCard
            
            // Popular progressions
            popularProgressionsCard
            
            // Extensions
            extensionsCard
        }
    }
    
    private var contextualSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text("Smart Suggestions")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            
            let suggestions = ChordSuggestionEngine.suggestNextChord(
                after: section.chordEvents.last,
                inKey: project.keyRoot,
                mode: project.keyMode
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.sm) {
                ForEach(suggestions.prefix(6)) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: DesignSystem.Colors.accent)
    }
    
    private func suggestionCard(_ suggestion: ChordSuggestion) -> some View {
        Button {
            onChordSelected(suggestion.root, suggestion.quality)
            isPresented = false
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(suggestion.display)
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    if let roman = suggestion.romanNumeral {
                        Badge(roman, color: DesignSystem.Colors.accent)
                    }
                }
                
                // Notes in chord
                let notes = ChordUtils.getChordNotes(
                    root: suggestion.root,
                    quality: suggestion.quality
                )
                
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    ForEach(notes.prefix(4), id: \.self) { note in
                        Text(note)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, DesignSystem.Spacing.xxxs)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.surface)
                            )
                    }
                }
                
                Text(suggestion.reason)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
                
                // Confidence stars
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: "star.fill")
                            .font(DesignSystem.Typography.nano)
                            .foregroundStyle(
                                Double(index) < suggestion.confidence * 5 ?
                                    DesignSystem.Colors.accent :
                                    DesignSystem.Colors.surface
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.sm)
            .glassStyle(cornerRadius: DesignSystem.CornerRadius.md)
        }
        .animatedPress()
    }
    
    private var popularProgressionsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundStyle(DesignSystem.Colors.primary)
                Text("Popular Progressions")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            
            let progressions = ChordSuggestionEngine.popularProgressions(
                forKey: project.keyRoot,
                mode: project.keyMode
            )
            
            ForEach(progressions.prefix(4), id: \.name) { progression in
                progressionRow(progression)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: DesignSystem.Colors.primary)
    }
    
    private func progressionRow(_ progression: (name: String, progression: [ChordSuggestion])) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(progression.name)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(progression.progression.prefix(4)) { chord in
                    Text(chord.display)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.surface)
                        )
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStyle(cornerRadius: DesignSystem.CornerRadius.sm)
    }
    
    private var extensionsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(DesignSystem.Colors.secondary)
                Text("Add Color")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            
            let extensions = ChordSuggestionEngine.commonExtensions(
                forKey: project.keyRoot,
                mode: project.keyMode
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.xs) {
                ForEach(extensions.prefix(9)) { chord in
                    simpleChordButton(chord)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: DesignSystem.Colors.secondary)
    }
    
    // MARK: - All Chords Section
    
    private var allChordsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Category selector
            categorySelector
            
            // Chords grid by category
            chordsGridByCategory
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach([ChordCategory.triad, .suspended, .seventh, .extended], id: \.self) { category in
                    Button {
                        withAnimation(DesignSystem.Animations.smoothSpring) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(selectedCategory == category ? DesignSystem.Colors.backgroundSecondary : DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                selectedCategory == category ?
                                    AnyView(Capsule().fill(DesignSystem.Colors.primary)) :
                                    AnyView(Capsule().stroke(DesignSystem.Colors.border, lineWidth: 1))
                            )
                    }
                }
            }
        }
    }
    
    private var chordsGridByCategory: some View {
        let qualities = ChordQuality.allCases.filter { $0.category == selectedCategory }
        
        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignSystem.Spacing.sm) {
            ForEach(qualities, id: \.self) { quality in
                chordQualityButton(quality)
            }
        }
    }
    
    private func chordQualityButton(_ quality: ChordQuality) -> some View {
        Button {
            onChordSelected(selectedRoot, quality)
            isPresented = false
        } label: {
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text(selectedRoot + quality.symbol)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(quality.displayName)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .glassStyle(cornerRadius: DesignSystem.CornerRadius.md)
        }
        .animatedPress()
    }
    
    // MARK: - Analysis Section
    
    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Progression analysis
            progressionAnalysisCard
            
            // Scale match
            scaleMatchCard
        }
    }
    
    private var progressionAnalysisCard: some View {
        let analysis = ChordSuggestionEngine.analyzeProgression(
            section.chordEvents,
            inKey: project.keyRoot,
            mode: project.keyMode
        )
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(DesignSystem.Colors.info)
                Text("Progression Analysis")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            
            // Stats
            HStack(spacing: DesignSystem.Spacing.lg) {
                statCard(
                    title: "Total Chords",
                    value: "\(analysis.totalChords)",
                    color: DesignSystem.Colors.primary
                )
                
                statCard(
                    title: "In Key",
                    value: "\(Int(analysis.diatonicPercentage))%",
                    color: analysis.diatonicPercentage > 80 ?
                           DesignSystem.Colors.success :
                           DesignSystem.Colors.warning
                )
            }
            
            // Roman numerals
            if !analysis.romanNumerals.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Progression")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(analysis.romanNumerals, id: \.self) { numeral in
                                Text(numeral)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, DesignSystem.Spacing.xxs)
                                    .glassStyle(cornerRadius: DesignSystem.CornerRadius.sm)
                            }
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: DesignSystem.Colors.info)
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(value)
                .font(DesignSystem.Typography.md)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .glassStyle(cornerRadius: DesignSystem.CornerRadius.md)
    }
    
    private var scaleMatchCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "music.quarternote.3")
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text("Scale Suggestions")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            
            Text("Notes in \(project.keyRoot) \(project.keyMode == .major ? "Major" : "Minor")")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            let scaleNotes = NoteUtils.scaleNotes(
                root: project.keyRoot,
                scaleType: project.keyMode == .major ? .major : .naturalMinor
            )
            
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(scaleNotes, id: \.self) { note in
                    Text(note)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                            .fill(DesignSystem.Colors.accent.opacity(0.2))
                                .overlay(
                                    Circle().stroke(DesignSystem.Colors.accent, lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: DesignSystem.Colors.accent)
    }
    
    // MARK: - Helper Views
    
    private func simpleChordButton(_ suggestion: ChordSuggestion) -> some View {
        Button {
            onChordSelected(suggestion.root, suggestion.quality)
            isPresented = false
        } label: {
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text(suggestion.display)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(suggestion.quality.displayName)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .glassStyle(cornerRadius: DesignSystem.CornerRadius.sm)
        }
        .animatedPress()
    }
}

// MARK: - Preview

#Preview {
    EnhancedChordPaletteSheet(
        project: Project(title: "Test", keyRoot: "C", keyMode: .major, bpm: 120),
        section: SectionTemplate(),
        isPresented: .constant(true)
    ) { _, _ in }
}
