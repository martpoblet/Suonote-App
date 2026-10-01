import SwiftUI

// MARK: - Effects rack
/// A track's effects: quick "looks" plus Reverb, Delay, EQ and Compressor.
/// Used in the track editor's Sound panel and in the standalone Effects sheet.
struct StudioEffectsRack: View {
    @Bindable var track: StudioTrack
    @EnvironmentObject private var playback: StudioPlaybackEngine
    @State private var effectsDebounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            looksRow
            rack
        }
    }

    private var rack: some View {
        VStack(spacing: 0) {
            effectRow(
                title: "Reverb",
                subtitle: track.reverbEnabled ? "\(track.reverbPreset.title) · \(Int(track.reverbMix * 100))%" : String(localized: "A sense of space"),
                icon: "dot.radiowaves.left.and.right",
                isOn: $track.reverbEnabled
            ) {
                chipRow(ReverbPreset.allCases, selected: track.reverbPreset, title: \.shortTitle) { track.reverbPreset = $0 }
                StudioSliderRow(title: "Amount", value: $track.reverbMix, range: 0...1,
                                valueText: "\(Int(track.reverbMix * 100))%", onChange: debouncedEffects)
            }

            Hairline().padding(.leading, 52)

            effectRow(
                title: "Delay",
                subtitle: track.delayEnabled ? "\(track.delaySyncMode.title) · \(Int(track.delayMix * 100))%" : String(localized: "Echoes in time"),
                icon: "repeat",
                isOn: $track.delayEnabled
            ) {
                chipRow(DelaySyncMode.allCases, selected: track.delaySyncMode, title: \.shortTitle) { track.delaySyncMode = $0 }
                if track.delaySyncMode == .free {
                    StudioSliderRow(title: "Time", value: $track.delayTime, range: 0.05...1,
                                    valueText: String(format: "%.2fs", track.delayTime), onChange: debouncedEffects)
                }
                StudioSliderRow(title: "Amount", value: $track.delayMix, range: 0...1,
                                valueText: "\(Int(track.delayMix * 100))%", onChange: debouncedEffects)
            }

            Hairline().padding(.leading, 52)

            effectRow(
                title: "EQ",
                subtitle: track.eqEnabled ? eqSummary : String(localized: "Shape lows, mids and highs"),
                icon: "slider.vertical.3",
                isOn: $track.eqEnabled
            ) {
                StudioSliderRow(title: "Low", value: $track.eqLowGain, range: -12...12,
                                valueText: gainText(track.eqLowGain), onChange: debouncedEffects)
                StudioSliderRow(title: "Mid", value: $track.eqMidGain, range: -12...12,
                                valueText: gainText(track.eqMidGain), onChange: debouncedEffects)
                StudioSliderRow(title: "High", value: $track.eqHighGain, range: -12...12,
                                valueText: gainText(track.eqHighGain), onChange: debouncedEffects)
            }

            Hairline().padding(.leading, 52)

            effectRow(
                title: "Compressor",
                subtitle: track.compressorEnabled
                    ? "\(Int(track.compressorThreshold)) dB · \(String(format: "%.1f", track.compressorRatio)):1"
                    : String(localized: "Evens out the dynamics"),
                icon: "rectangle.compress.vertical",
                isOn: $track.compressorEnabled
            ) {
                StudioSliderRow(title: "Threshold", value: $track.compressorThreshold, range: -40...0,
                                valueText: "\(Int(track.compressorThreshold)) dB", onChange: debouncedEffects)
                StudioSliderRow(title: "Ratio", value: $track.compressorRatio, range: 1.5...10,
                                valueText: String(format: "%.1f:1", track.compressorRatio), onChange: debouncedEffects)
            }
        }
        .cardStyle()
    }

    // MARK: Looks — one-tap effect chains

    private enum Look: String, CaseIterable, Identifiable {
        case dry = "Dry", room = "Room", hall = "Big hall", echo = "Echo", dreamy = "Dreamy"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .dry: return String(localized: "Dry")
            case .room: return String(localized: "Room")
            case .hall: return String(localized: "Big hall")
            case .echo: return String(localized: "Echo")
            case .dreamy: return String(localized: "Dreamy")
            }
        }
        var icon: String {
            switch self {
            case .dry: return "circle.slash"
            case .room: return "square.split.bottomrightquarter"
            case .hall: return "building.columns"
            case .echo: return "repeat"
            case .dreamy: return "sparkles"
            }
        }
    }

    private var looksRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Look.allCases) { look in
                    SelectableChip(title: look.title, icon: look.icon, isSelected: false) {
                        apply(look)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func apply(_ look: Look) {
        withAnimation(DesignSystem.Animations.smoothSpring) {
            switch look {
            case .dry:
                track.reverbEnabled = false
                track.delayEnabled = false
            case .room:
                track.reverbEnabled = true; track.reverbPreset = .small; track.reverbMix = 0.18
                track.delayEnabled = false
            case .hall:
                track.reverbEnabled = true; track.reverbPreset = .large; track.reverbMix = 0.3
                track.delayEnabled = false
            case .echo:
                track.reverbEnabled = true; track.reverbPreset = .medium; track.reverbMix = 0.12
                track.delayEnabled = true; track.delaySyncMode = .dottedEighth; track.delayMix = 0.2
            case .dreamy:
                track.reverbEnabled = true; track.reverbPreset = .plate; track.reverbMix = 0.38
                track.delayEnabled = true; track.delaySyncMode = .quarter; track.delayMix = 0.22
            }
        }
        playback.updateTrackEffects(track: track)
        haptic(.selection)
    }

    private var eqSummary: String {
        "\(gainText(track.eqLowGain)) · \(gainText(track.eqMidGain)) · \(gainText(track.eqHighGain))"
    }

    private func gainText(_ value: Float) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded) dB" : "\(rounded) dB"
    }

    private func effectRow<Content: View>(
        title: LocalizedStringKey,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn.wrappedValue ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textTertiary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Toggle(title, isOn: Binding(
                    get: { isOn.wrappedValue },
                    set: { newValue in
                        withAnimation(DesignSystem.Animations.smoothSpring) { isOn.wrappedValue = newValue }
                        playback.updateTrackEffects(track: track)
                        haptic(.selection)
                    }
                ))
                .labelsHidden()
                .tint(DesignSystem.Colors.primary)
            }
            if isOn.wrappedValue {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    content()
                }
                .padding(.leading, 36)
                .transition(.opacity)
            }
        }
        .padding(DesignSystem.Spacing.md)
    }

    private func chipRow<Option: Hashable>(
        _ options: [Option],
        selected: Option,
        title: KeyPath<Option, String>,
        onSelect: @escaping (Option) -> Void
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    SelectableChip(title: option[keyPath: title], isSelected: option == selected) {
                        onSelect(option)
                        playback.updateTrackEffects(track: track)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func debouncedEffects() {
        effectsDebounceTask?.cancel()
        effectsDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            playback.updateTrackEffects(track: track)
        }
    }
}

/// Effects for one track, reachable straight from the track's ⋯ menu.
struct StudioEffectsSheet: View {
    @Bindable var track: StudioTrack

    var body: some View {
        SheetScaffold(title: String(localized: "Effects"), subtitle: "\(track.name) · \(track.studioSoundName)") {
            StudioEffectsRack(track: track)
        }
        .presentationDetents([.medium, .large])
        .studioModalStyle()
    }
}
