import SwiftUI
import SwiftData

/// Full-screen mixer console — every studio track on one screen with volume,
/// pan, mute, solo, lock and (when applicable) reverb send. Designed to be
/// opened from the studio header so users can balance the mix without flipping
/// between expandable rows.
struct StudioMixerView: View {
    @Bindable var project: Project
    let onMixChange: () -> Void
    let onEffectsChange: () -> Void
    let onTrackStructureChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var mixDebounceTask: Task<Void, Never>?

    private var sortedTracks: [StudioTrack] {
        project.studioTracks.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var accentColor: Color {
        project.studioStyle?.accentColor ?? SectionColor.purple.color
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                if sortedTracks.isEmpty {
                    EmptyStateView(
                        icon: "slider.horizontal.3",
                        title: "Nothing to mix yet",
                        message: "Add a track in Studio first, then come back to dial in volume, pan and reverb."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            HStack {
                                Text("\(sortedTracks.count) track\(sortedTracks.count == 1 ? "" : "s")")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                Spacer()
                                if sortedTracks.contains(where: { $0.isSolo }) {
                                    Button("Clear solo") {
                                        for track in sortedTracks where track.isSolo {
                                            track.isSolo = false
                                        }
                                        scheduleMixUpdate()
                                    }
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.warning)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)

                            ForEach(sortedTracks) { track in
                                MixerTrackRow(
                                    track: track,
                                    accentColor: accentColor,
                                    onMixChange: scheduleMixUpdate,
                                    onEffectsChange: onEffectsChange,
                                    onLockChange: { onTrackStructureChange() }
                                )
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
            .navigationTitle("Mixer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            }
        }
    }

    /// Debounce mix updates while sliders move so we don't thrash the engine.
    private func scheduleMixUpdate() {
        mixDebounceTask?.cancel()
        mixDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            try? modelContext.save()
            onMixChange()
        }
    }
}

private struct MixerTrackRow: View {
    @Bindable var track: StudioTrack
    let accentColor: Color
    let onMixChange: () -> Void
    let onEffectsChange: () -> Void
    let onLockChange: () -> Void

    private var instrumentColor: Color { track.instrument.color }

    private var panLabel: String {
        if track.pan < -0.05 { return "L\(Int(abs(track.pan) * 100))" }
        if track.pan > 0.05  { return "R\(Int(track.pan * 100))" }
        return "C"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: track.instrument.icon)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(instrumentColor)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(track.variant?.displayName ?? track.instrument.title)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                MixerCapsule(symbol: "M", isOn: track.isMuted, tint: instrumentColor) {
                    track.isMuted.toggle()
                    onMixChange()
                }
                MixerCapsule(symbol: "S", isOn: track.isSolo, tint: instrumentColor) {
                    track.isSolo.toggle()
                    onMixChange()
                }
                if !track.instrument.isAudio {
                    MixerCapsule(systemImage: track.isLocked ? "lock.fill" : "lock.open",
                                 isOn: track.isLocked,
                                 tint: instrumentColor) {
                        track.isLocked.toggle()
                        onLockChange()
                    }
                }
            }

            // Volume row
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 18)
                Slider(value: $track.volume, in: 0...1)
                    .tint(instrumentColor)
                    .onChange(of: track.volume) { _, _ in onMixChange() }
                Text("\(Int(track.volume * 100))%")
                    .font(DesignSystem.Typography.caption2.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 38, alignment: .trailing)
            }

            // Pan row
            HStack(spacing: 8) {
                Image(systemName: "l.joystick.fill")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 18)
                Slider(value: $track.pan, in: -1...1)
                    .tint(instrumentColor)
                    .onChange(of: track.pan) { _, _ in onMixChange() }
                Text(panLabel)
                    .font(DesignSystem.Typography.caption2.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 38, alignment: .trailing)
            }

            // Reverb send (engine treats this as a wet send into the shared bus)
            if !track.instrument.isAudio {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(track.reverbEnabled ? instrumentColor : DesignSystem.Colors.textSecondary)
                        .frame(width: 18)
                    Slider(value: $track.reverbMix, in: 0...1)
                        .tint(instrumentColor.opacity(track.reverbEnabled ? 1 : 0.4))
                        .disabled(!track.reverbEnabled)
                        .onChange(of: track.reverbMix) { _, _ in onEffectsChange() }
                    Toggle("", isOn: $track.reverbEnabled)
                        .labelsHidden()
                        .tint(instrumentColor)
                        .onChange(of: track.reverbEnabled) { _, _ in onEffectsChange() }
                        .frame(width: 50)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(track.isLocked ? instrumentColor.opacity(0.5) : DesignSystem.Colors.border,
                                lineWidth: track.isLocked ? 1.5 : 1)
                )
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

private struct MixerCapsule: View {
    var symbol: String? = nil
    var systemImage: String? = nil
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Text(symbol).font(DesignSystem.Typography.caption)
                } else if let systemImage {
                    Image(systemName: systemImage).font(DesignSystem.Typography.caption2)
                }
            }
            .foregroundStyle(isOn ? DesignSystem.Colors.backgroundSecondary : DesignSystem.Colors.textSecondary)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(isOn ? tint : DesignSystem.Colors.surface)
                    .overlay(Circle().stroke(DesignSystem.Colors.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
