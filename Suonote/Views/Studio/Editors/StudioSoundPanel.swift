import SwiftUI

// MARK: - Sound panel
/// Everything about how a track *sounds*: which instrument sound, its
/// register, its place in the mix, and its effects.
struct StudioSoundPanel: View {
    @Bindable var project: Project
    @Bindable var track: StudioTrack
    let style: StudioStyle?
    let onNotesChanged: () -> Void

    @EnvironmentObject private var playback: StudioPlaybackEngine
    @State private var mixDebounceTask: Task<Void, Never>?

    private var hasRegister: Bool {
        track.instrument != .drums && !track.instrument.isAudio
    }

    private var octaveRange: ClosedRange<Int> {
        StudioGenerator.allowedOctaveShiftRange(for: track.instrument, variant: track.variant)
    }

    /// 0 = the instrument's natural register for its sound.
    private var displayOctave: Int {
        track.octaveShift - StudioGenerator.defaultOctaveShift(for: track.instrument, variant: track.variant)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                if !track.instrument.isAudio, !track.instrument.variants.isEmpty {
                    section(String(localized: "Sound"), detail: track.studioSoundName) {
                        StudioSoundList(
                            instrument: track.instrument,
                            selected: SoundFontManager.resolvedVariant(for: track.instrument, variant: track.variant),
                            recommended: track.instrument.studioRecommendedVariant(for: style),
                            keyRoot: project.keyRoot
                        ) { variant in
                            StudioTrackActions.applyVariant(variant, to: track, style: style, onChange: onNotesChanged)
                            project.updatedAt = Date()
                        }
                    }
                }

                if hasRegister {
                    section(String(localized: "Register")) { registerCard }
                }

                section(String(localized: "Mix")) { mixCard }

                if !track.instrument.isAudio {
                    section(String(localized: "Effects")) { effectsCard }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private func section<Content: View>(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: title, detail: detail)
            content()
        }
    }

    // MARK: Register

    private var registerCard: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayOctave == 0 ? String(localized: "Natural") : (displayOctave > 0 ? String(localized: "+\(displayOctave) oct") : String(localized: "\(displayOctave) oct")))
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .contentTransition(.numericText())
                Text(displayOctave == 0 ? "Where this sound sits best." : (displayOctave > 0 ? "Brighter, higher voicing." : "Darker, lower voicing."))
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Spacer()
            HStack(spacing: DesignSystem.Spacing.xs) {
                octaveButton("minus", label: "Octave down", enabled: track.octaveShift > octaveRange.lowerBound) { shiftOctave(-1) }
                octaveButton("plus", label: "Octave up", enabled: track.octaveShift < octaveRange.upperBound) { shiftOctave(1) }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func octaveButton(_ icon: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(OutlineButtonStyle(compact: true))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }

    private func shiftOctave(_ delta: Int) {
        let newValue = min(octaveRange.upperBound, max(octaveRange.lowerBound, track.octaveShift + delta))
        guard newValue != track.octaveShift else { return }
        track.octaveShift = newValue
        let targetRange = StudioGenerator.instrumentRange(
            for: track.instrument,
            variant: track.variant,
            style: style,
            octaveShift: newValue
        )
        for note in track.notes {
            note.pitch = StudioMusic.fit(note.pitch + delta * 12, into: targetRange)
        }
        project.updatedAt = Date()
        haptic(.selection)
        onNotesChanged()
    }

    // MARK: Mix

    private var mixCard: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            StudioSliderRow(
                title: "Volume",
                value: $track.volume,
                range: 0...1,
                valueText: "\(Int((track.volume * 100).rounded()))",
                onChange: debouncedMix
            )
            StudioSliderRow(
                title: "Pan",
                value: $track.pan,
                range: -1...1,
                valueText: StudioMusic.panLabel(track.pan),
                onChange: debouncedMix
            )
            Hairline()
            HStack(spacing: DesignSystem.Spacing.sm) {
                StudioMixToggle(kind: .mute, isOn: track.isMuted) {
                    track.isMuted.toggle()
                    playback.applyMixState(project: project)
                }
                Text(track.isMuted ? "Muted" : "Mute")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
                Text(track.isSolo ? "Soloed" : "Solo")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                StudioMixToggle(kind: .solo, isOn: track.isSolo) {
                    track.isSolo.toggle()
                    playback.applyMixState(project: project)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func debouncedMix() {
        mixDebounceTask?.cancel()
        mixDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            playback.updateTrackMix(trackId: track.id, volume: track.volume, pan: track.pan)
        }
    }

    // MARK: Effects

    private var effectsCard: some View {
        StudioEffectsRack(track: track)
    }
}
