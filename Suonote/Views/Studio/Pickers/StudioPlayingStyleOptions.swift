import SwiftUI

// MARK: - Playing style vocabulary
/// Shared by the add-instrument flow (`TrackStyleStepView`) and the editor's
/// Feel panel, so "how it plays" reads the same everywhere.

/// The playing style chosen for a freshly added instrument.
struct TrackStyleChoice {
    var comping: CompingPattern = .auto
    var bass: BassPattern = .auto
    var drumPreset: DrumPreset? = nil
    var leadComplexity: Double? = nil
    /// Sound to start on; nil keeps the style's recommended sound.
    var variant: InstrumentVariant? = nil
}

/// Which playing-style vocabulary an instrument uses.
enum StudioPlayingFamily {
    case bass, drums, lead, comping

    init(instrument: StudioInstrument, style: StudioStyle?) {
        if instrument == .bass {
            self = .bass
        } else if instrument == .drums {
            self = .drums
        } else if !StudioGenerator.supportsArpeggio(instrument: instrument, variant: nil, style: style) {
            self = .lead
        } else {
            self = .comping
        }
    }

    var title: String {
        switch self {
        case .bass: return String(localized: "Bass line")
        case .drums: return String(localized: "Groove")
        case .lead: return String(localized: "Phrasing")
        case .comping: return String(localized: "Accompaniment")
        }
    }
}

/// Named phrasing presets for melodic (lead) instruments, mapped onto the
/// track's complexity ("busy-ness") value.
enum StudioLeadFeel: String, CaseIterable, Identifiable {
    case auto, minimal, sparse, lyrical, flowing, riff, busy, solo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .minimal: return String(localized: "Minimal")
        case .sparse: return String(localized: "Sparse")
        case .lyrical: return String(localized: "Lyrical")
        case .flowing: return String(localized: "Flowing")
        case .riff: return String(localized: "Riff")
        case .busy: return String(localized: "Busy")
        case .solo: return String(localized: "Solo")
        }
    }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .minimal: return "circle"
        case .sparse: return "moon.stars"
        case .lyrical: return "music.note"
        case .flowing: return "wind"
        case .riff: return "waveform"
        case .busy: return "bolt.fill"
        case .solo: return "sparkles"
        }
    }

    var complexity: Double? {
        switch self {
        case .auto: return nil
        case .minimal: return 0.15
        case .sparse: return 0.3
        case .lyrical: return 0.45
        case .flowing: return 0.6
        case .riff: return 0.72
        case .busy: return 0.85
        case .solo: return 0.95
        }
    }

    /// Maps a stored complexity value back to the closest named feel so the
    /// editor can pre-select the track's current style.
    init(closestTo complexity: Double?) {
        guard let complexity else { self = .flowing; return }
        let options: [StudioLeadFeel] = [.minimal, .sparse, .lyrical, .flowing, .riff, .busy, .solo]
        self = options.min(by: {
            abs(($0.complexity ?? 0) - complexity) < abs(($1.complexity ?? 0) - complexity)
        }) ?? .flowing
    }

    static var named: [StudioLeadFeel] { allCases.filter { $0 != .auto } }
}

/// Two-column grid of selectable playing-style options.
struct StudioOptionGrid<Option: Identifiable & Equatable>: View {
    let options: [Option]
    let selected: Option?
    let recommended: Option?
    let label: (Option) -> String
    let icon: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(options) { option in
                let isSelected = option == selected
                Button {
                    onSelect(option)
                    haptic(.selection)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon(option))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textSecondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(label(option))
                                .font(DesignSystem.Typography.calloutBold)
                                .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if option == recommended {
                                Text("Suggested")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(isSelected ? DesignSystem.Colors.background.opacity(0.75) : DesignSystem.Colors.primaryDark)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                            .fill(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                            .strokeBorder(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .animation(DesignSystem.Animations.quickSpring, value: isSelected)
            }
        }
    }
}

/// Vertical list of sounds (variants) with the chosen one marked in teal.
struct StudioSoundList: View {
    let instrument: StudioInstrument
    let selected: InstrumentVariant?
    var recommended: InstrumentVariant? = nil
    /// Key used for auditions so previews sound "in the song".
    var keyRoot: String = "C"
    let onSelect: (InstrumentVariant) -> Void

    @ObservedObject private var previewer = StudioSoundPreviewer.shared

    var body: some View {
        VStack(spacing: 0) {
            let variants = instrument.variants
            ForEach(Array(variants.enumerated()), id: \.element) { index, variant in
                let isSelected = variant == selected
                let isPreviewing = previewer.previewingVariant == variant
                HStack(spacing: 0) {
                    // Audition without choosing.
                    Button {
                        if isPreviewing {
                            previewer.stop()
                        } else {
                            previewer.preview(instrument: instrument, variant: variant, keyRoot: keyRoot)
                        }
                        haptic(.light)
                    } label: {
                        Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22, weight: .regular))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isPreviewing || isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textTertiary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 50, height: 46)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPreviewing ? "Stop preview" : "Preview \(variant.displayName)")

                    Button {
                        onSelect(variant)
                        previewer.preview(instrument: instrument, variant: variant, keyRoot: keyRoot)
                        haptic(.selection)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(variant.displayName)
                                .font(isSelected ? DesignSystem.Typography.headline : DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                            if variant == recommended {
                                Badge(String(localized: "Suggested"), color: DesignSystem.Colors.primaryDark)
                            }
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                            }
                        }
                        .padding(.trailing, DesignSystem.Spacing.md)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                .background(isSelected ? DesignSystem.Colors.primaryLight.opacity(0.6) : Color.clear)

                if index < variants.count - 1 {
                    Hairline().padding(.leading, 50)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        .cardStyle()
        .onDisappear { previewer.stop() }
    }
}
