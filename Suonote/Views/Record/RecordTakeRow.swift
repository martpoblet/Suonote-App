import SwiftUI

/// One take in the list: play, name, type, duration, favorite, waveform
/// (scrubbable once loaded), linked section and active effects.
struct RecordTakeRow: View {
    let recording: Recording
    let linkedSection: SectionTemplate?
    @ObservedObject var player: RecordTakePlayer
    let onOpen: () -> Void
    let onToggleFavorite: () -> Void
    let onLinkSection: () -> Void

    private var isPlaying: Bool { player.isPlaying(recording) }
    private var isLoaded: Bool { player.isLoaded(recording) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                playButton

                VStack(alignment: .leading, spacing: 3) {
                    Text(recording.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Image(systemName: recording.recordingType.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(recording.recordingType.color)
                        Text(recording.recordingType.recordDisplayName)
                        Text("·")
                        Text(recording.createdAt.formatted(.relative(presentation: .named)))
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .lineLimit(1)
                }

                Spacer(minLength: DesignSystem.Spacing.xs)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeLabel)
                        .font(DesignSystem.Typography.timecode)
                        .foregroundStyle(isLoaded ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textSecondary)
                        .contentTransition(.numericText())
                    favoriteButton
                }
            }

            RecordWaveformView(
                fileName: recording.fileName,
                samples: 56,
                progress: player.progress(for: recording),
                isActive: isLoaded,
                onSeek: isLoaded ? { fraction in player.seek(recording, to: fraction) } : nil
            )
            .frame(height: 34)
            .allowsHitTesting(isLoaded)

            if linkedSection != nil || !recording.recordActiveEffectNames.isEmpty {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    sectionChip
                    Spacer(minLength: 0)
                    if !recording.recordActiveEffectNames.isEmpty {
                        effectsLabel
                    }
                }
            } else {
                sectionChip
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(color: isLoaded ? DesignSystem.Colors.primary.opacity(0.45) : nil)
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open take", onOpen)
    }

    private var timeLabel: String {
        if isLoaded, player.currentTime > 0 {
            return RecordFormat.duration(player.currentTime)
        }
        return RecordFormat.duration(recording.duration)
    }

    private var playButton: some View {
        Button {
            HapticFeedback.light.trigger()
            player.toggle(recording)
        } label: {
            ZStack {
                Circle()
                    .fill(isPlaying ? DesignSystem.Colors.primary : DesignSystem.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isPlaying ? DesignSystem.Colors.onPrimary : DesignSystem.Colors.background)
                    .offset(x: isPlaying ? 0 : 1.5)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause \(recording.name)" : "Play \(recording.name)")
    }

    private var favoriteButton: some View {
        Button {
            HapticFeedback.selection.trigger()
            onToggleFavorite()
        } label: {
            Image(systemName: recording.isFavorite ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(recording.isFavorite ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                .frame(width: 28, height: 24, alignment: .trailing)
                .contentShape(Rectangle())
                .symbolEffect(.bounce, value: recording.isFavorite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recording.isFavorite ? "Remove from favorites" : "Add to favorites")
    }

    @ViewBuilder
    private var sectionChip: some View {
        if let section = linkedSection {
            Button(action: onLinkSection) {
                HStack(spacing: 6) {
                    SectionColorDot(section.color, size: 7)
                    Text(section.name)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(section.color.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Linked to \(section.name). Change link")
        } else {
            Button(action: onLinkSection) {
                HStack(spacing: 5) {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Link section")
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(DesignSystem.Colors.border, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Link to a section")
        }
    }

    private var effectsLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "dial.medium")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryDark)
            Text(recording.recordActiveEffectNames.joined(separator: " · "))
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Effects: \(recording.recordActiveEffectNames.joined(separator: ", "))")
    }
}
