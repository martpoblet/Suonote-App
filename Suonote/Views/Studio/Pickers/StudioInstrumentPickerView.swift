import SwiftUI

extension TrackStyleChoice {
    /// The idiomatic playing style for an instrument in a style — what a new
    /// track gets when added with a single tap.
    static func recommended(
        for instrument: StudioInstrument,
        style: StudioStyle?,
        beatsPerBar: Int,
        timeBottom: Int
    ) -> TrackStyleChoice {
        let resolvedStyle = style ?? .pop
        var choice = TrackStyleChoice()
        switch StudioPlayingFamily(instrument: instrument, style: style) {
        case .bass:
            choice.bass = StudioGenerator.recommendedBass(for: resolvedStyle)
        case .drums:
            choice.drumPreset = DrumPreset.presets(for: resolvedStyle, beatsPerBar: beatsPerBar, timeBottom: timeBottom).first
        case .lead:
            choice.leadComplexity = StudioLeadFeel.flowing.complexity
        case .comping:
            choice.comping = StudioGenerator.recommendedComping(for: instrument, variant: nil, style: resolvedStyle)
        }
        return choice
    }
}

// MARK: - Add instrument sheet

/// Tap an instrument, choose how it plays (the style's suggestion is already
/// picked) and add it. Recordings can be placed on the timeline from the
/// same sheet.
struct StudioInstrumentPickerView: View {
    let availableInstruments: [StudioInstrument]
    let instrumentCounts: [StudioInstrument: Int]
    let style: StudioStyle?
    let beatsPerBar: Int
    let timeBottom: Int
    var recordings: [Recording] = []
    let onPick: (StudioInstrument, TrackStyleChoice) -> Void
    var onPickRecording: ((Recording) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var customizing: StudioInstrument?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var subtitle: String {
        if let style {
            return String(localized: "Pick an instrument, then choose how it plays in this \(style.title) song.")
        }
        return String(localized: "Pick an instrument, then choose how it plays.")
    }

    var body: some View {
        NavigationStack {
            SheetScaffold(title: String(localized: "Add a track"), subtitle: subtitle) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(availableInstruments) { instrument in
                            instrumentCard(instrument)
                        }
                    }

                    if !recordings.isEmpty, onPickRecording != nil {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            SectionHeader(title: String(localized: "From your recordings"), detail: "\(recordings.count)")
                            StudioRecordingPicker(recordings: recordings) { recording in
                                onPickRecording?(recording)
                                haptic(.success)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            #if DEBUG
            .task {
                // Screenshots: `-ScreenshotOpen add:strings` opens that instrument's style step.
                guard let name = UserDefaults.standard.string(forKey: "ScreenshotOpen"), name.hasPrefix("add:"),
                      let instrument = StudioInstrument(rawValue: String(name.dropFirst(4))) else { return }
                try? await Task.sleep(for: .seconds(0.8))
                customizing = instrument
            }
            #endif
            .navigationDestination(item: $customizing) { instrument in
                TrackStyleStepView(
                    instrument: instrument,
                    style: style,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom,
                    confirmTitle: String(localized: "Add \(instrument.title)"),
                    onConfirm: { choice in
                        onPick(instrument, choice)
                        haptic(.success)
                        dismiss()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func instrumentCard(_ instrument: StudioInstrument) -> some View {
        let count = instrumentCounts[instrument, default: 0]
        let isFull = count >= instrument.maxStudioTracks
        let soundName = instrument.studioRecommendedVariant(for: style)?.displayName

        ZStack(alignment: .topTrailing) {
            Button {
                guard !isFull else { return }
                haptic(.selection)
                customizing = instrument
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    StudioInstrumentBadge(instrument: instrument, size: 38, isDimmed: isFull)
                        .padding(.bottom, 4)
                    Text(instrument.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(instrument.studioTagline)
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    statusLine(instrument: instrument, count: count, isFull: isFull, soundName: soundName)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
                .cardStyle()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isFull ? 0.55 : 1)
            .disabled(isFull)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(instrument, count: count, isFull: isFull, soundName: soundName))
            .accessibilityHint(isFull ? "" : "Choose how it plays, then add it")

            if !isFull {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(14)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func statusLine(instrument: StudioInstrument, count: Int, isFull: Bool, soundName: String?) -> some View {
        if isFull {
            Label(instrument.maxStudioTracks > 1 ? "All \(instrument.maxStudioTracks) layers added" : "In the song", systemImage: "checkmark")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 9, weight: .semibold))
                Text(soundName ?? instrument.title)
                    .lineLimit(1)
                if instrument.maxStudioTracks > 1, count > 0 {
                    Text("· layer \(count + 1)")
                }
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.primaryDark)
        }
    }

    private func accessibilityLabel(_ instrument: StudioInstrument, count: Int, isFull: Bool, soundName: String?) -> String {
        var parts = [instrument.title, instrument.studioTagline]
        if isFull {
            parts.append(String(localized: "Already in the song"))
        } else if let soundName {
            parts.append(String(localized: "Sound: \(soundName)"))
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Recordings list

/// Recordings that can be dropped onto the Studio timeline as audio tracks.
struct StudioRecordingPicker: View {
    let recordings: [Recording]
    let onPick: (Recording) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(recordings.enumerated()), id: \.element.id) { index, recording in
                Button {
                    onPick(recording)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ZStack {
                            Circle().fill(recording.recordingType.color.opacity(0.18))
                            Image(systemName: recording.recordingType.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                        .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recording.name)
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                            Text(recording.recordingType.recordDisplayName)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Text(durationText(recording.duration))
                            .font(DesignSystem.Typography.caption.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignSystem.Colors.primaryDark)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(recording.name), \(durationText(recording.duration))")

                if index < recordings.count - 1 {
                    Hairline().padding(.leading, 64)
                }
            }
        }
        .cardStyle()
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Customize before adding

/// Optional step of "add instrument": choose the sound and how it plays.
/// The options depend on the instrument family (accompaniment for chords,
/// line for bass, groove for drums, phrasing for leads).
struct TrackStyleStepView: View {
    let instrument: StudioInstrument
    let style: StudioStyle?
    let beatsPerBar: Int
    let timeBottom: Int
    /// Pre-selected style when editing an existing track; nil pre-selects the
    /// recommended style (used when adding a new instrument).
    var initialChoice: TrackStyleChoice? = nil
    var confirmTitle: String = String(localized: "Add to song")
    let onConfirm: (TrackStyleChoice) -> Void

    @State private var comping: CompingPattern = .auto
    @State private var bass: BassPattern = .auto
    @State private var drumPreset: DrumPreset = .basic
    @State private var leadFeel: StudioLeadFeel = .auto
    @State private var variant: InstrumentVariant?

    private var family: StudioPlayingFamily { StudioPlayingFamily(instrument: instrument, style: style) }
    private var resolvedStyle: StudioStyle { style ?? .pop }

    private var drumPresets: [DrumPreset] {
        DrumPreset.presets(for: resolvedStyle, beatsPerBar: beatsPerBar, timeBottom: timeBottom)
    }
    private var compingOptions: [CompingPattern] {
        let options = StudioGenerator.compingOptions(for: instrument, variant: nil, style: resolvedStyle)
        return options.contains(comping) ? options : [comping] + options
    }
    private var bassOptions: [BassPattern] {
        let options = StudioGenerator.bassOptions(for: resolvedStyle)
        return options.contains(bass) ? options : [bass] + options
    }
    private var recommendedComping: CompingPattern {
        StudioGenerator.recommendedComping(for: instrument, variant: nil, style: resolvedStyle)
    }
    private var recommendedBass: BassPattern {
        StudioGenerator.recommendedBass(for: resolvedStyle)
    }
    private var recommendedVariant: InstrumentVariant? {
        instrument.studioRecommendedVariant(for: style)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    StudioInstrumentBadge(instrument: instrument, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instrument.title)
                            .font(DesignSystem.Typography.title)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(style.map { String(localized: "How should it play in this \($0.title) song?") }
                             ?? String(localized: "How should it sound and play?"))
                            .font(DesignSystem.Typography.italicSmall)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    SectionHeader(title: family.title)
                    switch family {
                    case .bass:
                        StudioOptionGrid(options: bassOptions, selected: bass, recommended: recommendedBass, label: \.displayName, icon: \.icon) { bass = $0 }
                    case .drums:
                        StudioOptionGrid(options: drumPresets, selected: drumPreset, recommended: drumPresets.first, label: \.title, icon: { _ in "metronome" }) { drumPreset = $0 }
                    case .lead:
                        StudioOptionGrid(options: StudioLeadFeel.allCases, selected: leadFeel, recommended: .flowing, label: \.displayName, icon: \.icon) { leadFeel = $0 }
                    case .comping:
                        StudioOptionGrid(options: compingOptions, selected: comping, recommended: recommendedComping, label: \.displayName, icon: \.icon) { comping = $0 }
                    }
                }

                if !instrument.variants.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        SectionHeader(title: String(localized: "Sound"), detail: String(localized: "\(instrument.variants.count) to choose from"))
                        StudioSoundList(
                            instrument: instrument,
                            selected: variant,
                            recommended: recommendedVariant
                        ) { variant = $0 }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(confirmTitle, icon: "plus") {
                onConfirm(buildChoice())
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .onAppear(perform: preselect)
    }

    private func preselect() {
        if let initialChoice {
            comping = initialChoice.comping
            bass = initialChoice.bass
            if let preset = initialChoice.drumPreset {
                drumPreset = preset
            } else if family == .drums {
                drumPreset = drumPresets.first ?? .basic
            }
            leadFeel = StudioLeadFeel(closestTo: initialChoice.leadComplexity)
            variant = initialChoice.variant ?? recommendedVariant
        } else {
            comping = recommendedComping
            bass = recommendedBass
            leadFeel = .flowing
            if family == .drums { drumPreset = drumPresets.first ?? .basic }
            variant = recommendedVariant
        }
    }

    private func buildChoice() -> TrackStyleChoice {
        var choice = TrackStyleChoice()
        switch family {
        case .bass: choice.bass = bass
        case .drums: choice.drumPreset = drumPreset
        case .lead: choice.leadComplexity = leadFeel.complexity
        case .comping: choice.comping = comping
        }
        choice.variant = variant
        return choice
    }
}
