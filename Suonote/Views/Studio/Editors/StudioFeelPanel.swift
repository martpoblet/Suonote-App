import SwiftUI
import SwiftData

// MARK: - Feel panel
/// How the part is *written*: its playing pattern plus three musical dials —
/// Energy, Busy-ness and Human touch — then one clear "Rewrite part" action.
struct StudioFeelPanel: View {
    @Bindable var project: Project
    @Bindable var track: StudioTrack
    let style: StudioStyle?
    let onNotesChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playback: StudioPlaybackEngine
    @State private var showingRewriteConfirm = false
    @State private var hasPendingChanges = false
    @State private var justRewrote = false

    private var family: StudioPlayingFamily { StudioPlayingFamily(instrument: track.instrument, style: style) }
    private var resolvedStyle: StudioStyle { style ?? .pop }

    private var compingOptions: [CompingPattern] {
        let options = StudioGenerator.compingOptions(for: track.instrument, variant: track.variant, style: resolvedStyle)
        return options.contains(track.compingPattern) ? options : [track.compingPattern] + options
    }

    private var bassOptions: [BassPattern] {
        let options = StudioGenerator.bassOptions(for: resolvedStyle)
        return options.contains(track.bassPattern) ? options : [track.bassPattern] + options
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                Text("Shape how this part is written, then rewrite it. Your sound and mix stay as they are.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if style == nil {
                    Label("Choose a Studio style to write parts.", systemImage: "sparkles")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                } else {
                    patternSection
                    dialsSection
                    arrangementSection
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if style != nil {
                rewriteBar
                    .padding(.horizontal, DesignSystem.Spacing.gutter)
                    .padding(.bottom, DesignSystem.Spacing.xs)
            }
        }
        .confirmationDialog("Rewrite \(track.name)?", isPresented: $showingRewriteConfirm, titleVisibility: .visible) {
            Button("Rewrite part", role: .destructive, action: rewrite)
        } message: {
            Text("Notes you edited by hand on this track will be replaced.")
        }
    }

    // MARK: Pattern

    @ViewBuilder
    private var patternSection: some View {
        switch family {
        case .drums:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                SectionHeader(title: String(localized: "Groove"), detail: track.drumPreset?.title)
                Text("Pick a groove in the Groove tab — the dials below shape how it's played.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        case .bass:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                SectionHeader(title: family.title, detail: track.bassPattern.displayName)
                StudioOptionGrid(
                    options: bassOptions,
                    selected: track.bassPattern,
                    recommended: StudioGenerator.recommendedBass(for: resolvedStyle),
                    label: \.displayName,
                    icon: \.icon
                ) { track.bassPattern = $0; markChanged() }
            }
        case .lead:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                SectionHeader(title: family.title, detail: StudioLeadFeel(closestTo: track.regenerateComplexity).displayName)
                StudioOptionGrid(
                    options: StudioLeadFeel.named,
                    selected: StudioLeadFeel(closestTo: track.regenerateComplexity),
                    recommended: .flowing,
                    label: \.displayName,
                    icon: \.icon
                ) { feel in
                    if let complexity = feel.complexity {
                        withAnimation(DesignSystem.Animations.smoothSpring) { track.regenerateComplexity = complexity }
                    }
                    markChanged()
                }
            }
        case .comping:
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                SectionHeader(title: family.title, detail: track.compingPattern.displayName)
                StudioOptionGrid(
                    options: compingOptions,
                    selected: track.compingPattern,
                    recommended: StudioGenerator.recommendedComping(for: track.instrument, variant: track.variant, style: resolvedStyle),
                    label: \.displayName,
                    icon: \.icon
                ) { track.compingPattern = $0; markChanged() }

                if track.compingPattern.usesRate {
                    HStack(spacing: 6) {
                        Text("Note rate").eyebrow()
                            .padding(.trailing, 4)
                        ForEach(["1/4", "1/8", "1/16"], id: \.self) { rate in
                            SelectableChip(title: rate, isSelected: track.regenerateArpeggioRate == rate) {
                                track.regenerateArpeggioRate = rate
                                markChanged()
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    // MARK: Dials

    private var dialsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: String(localized: "Feel"))
            VStack(spacing: DesignSystem.Spacing.lg) {
                StudioFeelSlider(
                    title: "Energy",
                    lowLabel: "Gentle",
                    highLabel: "Driving",
                    value: dial(\.regenerateIntensity)
                )
                Hairline()
                StudioFeelSlider(
                    title: "Busy-ness",
                    lowLabel: "Spacious",
                    highLabel: "Busy",
                    value: dial(\.regenerateComplexity)
                )
                Hairline()
                StudioFeelSlider(
                    title: "Human touch",
                    lowLabel: "On the grid",
                    highLabel: "Loose, played",
                    value: dial(\.regenerateNaturalness)
                )
            }
            .padding(DesignSystem.Spacing.md)
            .cardStyle()
        }
    }

    // MARK: Arrangement

    private var arrangementSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: String(localized: "Arrangement"))
            Toggle(isOn: Binding(
                get: { track.followsArrangement },
                set: { newValue in
                    track.followsArrangement = newValue
                    markChanged()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Follow the song's structure")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(track.followsArrangement
                         ? "Enters, rests and builds with intro, verses and choruses."
                         : "Plays the same way through the whole song.")
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(DesignSystem.Colors.primary)
            .padding(DesignSystem.Spacing.md)
            .cardStyle()
        }
    }

    private func dial(_ keyPath: ReferenceWritableKeyPath<StudioTrack, Double>) -> Binding<Double> {
        Binding(
            get: { track[keyPath: keyPath] },
            set: { newValue in
                track[keyPath: keyPath] = newValue
                markChanged()
            }
        )
    }

    private func markChanged() {
        hasPendingChanges = true
        justRewrote = false
        project.updatedAt = Date()
    }

    // MARK: Rewrite

    private var rewriteBar: some View {
        VStack(spacing: 6) {
            if justRewrote {
                Label("Part rewritten", systemImage: "checkmark")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                    .transition(.opacity)
            } else if hasPendingChanges {
                Text("Settings changed — rewrite to hear them.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .transition(.opacity)
            }
            PrimaryButton(hasPendingChanges ? String(localized: "Rewrite part") : String(localized: "Rewrite part again"), icon: "wand.and.stars") {
                showingRewriteConfirm = true
            }
        }
        .animation(DesignSystem.Animations.quickEase, value: hasPendingChanges)
        .animation(DesignSystem.Animations.quickEase, value: justRewrote)
    }

    private func rewrite() {
        guard let style else { return }
        if playback.isPlaying {
            playback.stop(resetPosition: false)
        }
        StudioTrackActions.regenerate(track, project: project, style: style, modelContext: modelContext)
        try? modelContext.save()
        onNotesChanged()
        hasPendingChanges = false
        justRewrote = true
        haptic(.success)
    }
}
