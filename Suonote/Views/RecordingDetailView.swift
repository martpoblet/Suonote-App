import SwiftUI
import AVFoundation

/// A single take: scrub and play it, rename it, change its type, link it to
/// a section, shape it on the pedalboard (heard live), share or delete it.
struct RecordingDetailView: View {
    @Bindable var recording: Recording
    let sections: [SectionTemplate]
    @ObservedObject var player: RecordTakePlayer
    let onUpdate: () -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showingTypePicker = false
    @FocusState private var nameFocused: Bool

    private var isPlaying: Bool { player.isPlaying(recording) }
    private var isLoaded: Bool { player.isLoaded(recording) }

    private var effectsBinding: Binding<AudioEffectsProcessor.EffectSettings> {
        Binding(
            get: { recording.recordEffectSettings },
            set: { recording.recordEffectSettings = $0 }
        )
    }

    private var linkedSection: SectionTemplate? {
        guard let id = recording.linkedSectionId else { return nil }
        return sections.first { $0.id == id }
    }

    var body: some View {
        SheetScaffold(title: recording.name.isEmpty ? String(localized: "Untitled take") : recording.name, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                playerCard
                detailsSection
                effectsSection
                actionsSection
            }
        }
        .presentationDetents([.large])
        .studioModalStyle()
        .sheet(isPresented: $showingTypePicker) {
            RecordingTypePickerSheet(selectedType: Binding(
                get: { recording.recordingType },
                set: { recording.recordingType = $0; onUpdate() }
            ))
        }
        .onDisappear {
            onUpdate()
        }
    }

    private var subtitle: String {
        "\(recording.recordingType.recordDisplayName) · \(recording.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }

    // MARK: Player

    private var playerCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            RecordWaveformView(
                fileName: recording.fileName,
                samples: 72,
                progress: player.progress(for: recording) ?? 0,
                isActive: isLoaded,
                barSpacing: 2.5,
                onSeek: { fraction in
                    HapticFeedback.light.trigger()
                    player.seek(recording, to: fraction)
                }
            )
            .frame(height: 88)

            HStack {
                Text(RecordFormat.duration(isLoaded ? player.currentTime : 0))
                Spacer()
                Text(RecordFormat.duration(isLoaded && player.duration > 0 ? player.duration : recording.duration))
            }
            .font(DesignSystem.Typography.timecode)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Position \(RecordFormat.spoken(isLoaded ? player.currentTime : 0)) of \(RecordFormat.spoken(recording.duration))")

            HStack(spacing: DesignSystem.Spacing.xl) {
                transportButton(icon: "gobackward.5", label: "Back 5 seconds") {
                    player.skip(recording, by: -5)
                }

                Button {
                    HapticFeedback.medium.trigger()
                    player.toggle(recording)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? DesignSystem.Colors.primary : DesignSystem.Colors.textPrimary)
                            .frame(width: 64, height: 64)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(isPlaying ? DesignSystem.Colors.onPrimary : DesignSystem.Colors.background)
                            .offset(x: isPlaying ? 0 : 2)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(AnimatedPressButtonStyle(scale: 0.94))
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                transportButton(icon: "goforward.5", label: "Forward 5 seconds") {
                    player.skip(recording, by: 5)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: isLoaded ? DesignSystem.Colors.primary.opacity(0.45) : nil)
    }

    private func transportButton(icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.light.trigger()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: String(localized: "Details"))

            VStack(spacing: 0) {
                // Name
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Name")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    TextField("Take name", text: $recording.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { onUpdate() }
                }
                .padding(DesignSystem.Spacing.md)

                Hairline()

                // Type
                Button {
                    showingTypePicker = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Type")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: recording.recordingType.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(recording.recordingType.color)
                        Text(recording.recordingType.recordDisplayName)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Type, \(recording.recordingType.recordDisplayName)")
                .accessibilityHint("Opens the type picker")

                Hairline()

                // Favorite
                Toggle(isOn: Binding(
                    get: { recording.isFavorite },
                    set: { recording.isFavorite = $0; HapticFeedback.selection.trigger(); onUpdate() }
                )) {
                    Text("Favorite")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .tint(DesignSystem.Colors.accent)
                .padding(DesignSystem.Spacing.md)

                Hairline()

                // Section link
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Linked section")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    if sections.isEmpty {
                        Text("Add sections in Compose to link this take.")
                            .font(DesignSystem.Typography.italicSmall)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                SelectableChip(title: String(localized: "None"), isSelected: recording.linkedSectionId == nil) {
                                    link(nil)
                                }
                                ForEach(sections) { section in
                                    SelectableChip(
                                        title: section.name,
                                        dot: section.color,
                                        isSelected: recording.linkedSectionId == section.id
                                    ) {
                                        link(section.id)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, 1)
                        }
                        .scrollIndicators(.hidden)
                        .padding(.horizontal, -DesignSystem.Spacing.md)
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .cardStyle()

            Text("Recorded at \(recording.bpm) BPM in \(recording.timeTop)/\(recording.timeBottom)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, DesignSystem.Spacing.xxs)
        }
    }

    // MARK: Effects

    private var effectsSection: some View {
        let active = recording.recordEffectSettings.recordActiveCount
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(
                title: String(localized: "Effects"),
                detail: active == 0 ? String(localized: "Dry") : String(localized: "\(active) on"),
                actionTitle: active > 0 ? String(localized: "Bypass all") : nil,
                action: active > 0 ? { bypassAll() } : nil
            )
            Text(isPlaying ? "Changes are heard as you play." : "Press play to hear changes live.")
                .font(DesignSystem.Typography.italicSmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            RecordPedalboard(settings: effectsBinding) {
                player.refreshEffects(for: recording)
            }
        }
    }

    // MARK: Actions

    private var actionsSection: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let url = recording.recordFileURL {
                ShareLink(item: url, preview: SharePreview(recording.name)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle())
            }
            if let onDelete {
                Button(role: .destructive) {
                    if isLoaded { player.stop() }
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle(tint: DesignSystem.Colors.error))
            }
        }
        .padding(.top, DesignSystem.Spacing.xs)
    }

    // MARK: Helpers

    private func link(_ id: UUID?) {
        HapticFeedback.selection.trigger()
        recording.linkedSectionId = id
        onUpdate()
    }

    private func bypassAll() {
        HapticFeedback.light.trigger()
        var settings = recording.recordEffectSettings
        settings.reverbEnabled = false
        settings.delayEnabled = false
        settings.eqEnabled = false
        settings.compressionEnabled = false
        withAnimation(DesignSystem.Animations.quickSpring) {
            recording.recordEffectSettings = settings
        }
        player.refreshEffects(for: recording)
    }
}
