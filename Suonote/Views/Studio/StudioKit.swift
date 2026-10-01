import SwiftUI
import SwiftData

// MARK: - Studio Kit
/// Shared vocabulary for the Studio ("production room"): music helpers,
/// arrangement geometry, and the small controls reused by the track list,
/// the editors and the transport. Everything here is Studio-scoped.

// MARK: - Music helpers

enum StudioMusic {
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func noteName(_ midi: Int) -> String {
        let name = noteNames[(midi % 12 + 12) % 12]
        let octave = (midi / 12) - 1
        return "\(name)\(octave)"
    }

    static func isBlackKey(_ midi: Int) -> Bool {
        [1, 3, 6, 8, 10].contains((midi % 12 + 12) % 12)
    }

    static func panLabel(_ pan: Float) -> String {
        if pan < -0.05 { return "L\(Int((abs(pan) * 100).rounded()))" }
        if pan > 0.05 { return "R\(Int((pan * 100).rounded()))" }
        return "C"
    }

    static func chordText(_ chord: ChordEvent) -> String {
        if !chord.display.isEmpty { return chord.display }
        if chord.isRest { return String(localized: "Rest") }
        var text = chord.root + chord.quality.symbol
        if !chord.extensions.isEmpty { text += chord.extensions.joined() }
        if let slash = chord.slashRoot, !slash.isEmpty { text += "/\(slash)" }
        return text
    }

    static func fit(_ pitch: Int, into range: ClosedRange<Int>) -> Int {
        var adjusted = pitch
        while adjusted < range.lowerBound { adjusted += 12 }
        while adjusted > range.upperBound { adjusted -= 12 }
        return min(max(adjusted, range.lowerBound), range.upperBound)
    }

    /// "Bar.beat" timecode (1-based), e.g. `12.3`.
    static func timecode(beat: Double, beatsPerBar: Int) -> String {
        let perBar = Double(max(1, beatsPerBar))
        let clamped = max(0, beat)
        let bar = Int(clamped / perBar) + 1
        let beatInBar = Int(clamped.truncatingRemainder(dividingBy: perBar)) + 1
        return "\(bar).\(beatInBar)"
    }

    static func keyLabel(root: String, mode: KeyMode) -> String {
        mode == .minor ? "\(root)m" : root
    }
}

// MARK: - Arrangement geometry

/// One bar of the song with its section + chord context (used by the editors' rulers).
struct StudioBarSectionInfo: Identifiable {
    let barIndex: Int
    let sectionLabel: String
    let sectionColor: Color
    let chordLabel: String?

    var id: Int { barIndex }
}

/// One arranged section placed on the song timeline.
struct StudioSectionSpan: Identifiable {
    let id: UUID
    let name: String
    let color: Color
    let startBar: Int
    let bars: Int

    var endBar: Int { startBar + bars }
}

extension Project {
    /// Arranged sections in play order with their bar positions.
    var studioSectionSpans: [StudioSectionSpan] {
        var spans: [StudioSectionSpan] = []
        var bar = 0
        for item in arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            let label = (item.labelOverride?.isEmpty == false) ? item.labelOverride! : section.name
            spans.append(StudioSectionSpan(id: item.id, name: label, color: section.color, startBar: bar, bars: bars))
            bar += bars
        }
        return spans
    }

    var studioTotalBars: Int {
        max(1, arrangementItems.compactMap { $0.sectionTemplate?.bars }.reduce(0, +))
    }

    var studioHasSections: Bool {
        arrangementItems.contains { $0.sectionTemplate != nil }
    }

    func studioBarSectionInfos(fallbackColor: Color) -> [StudioBarSectionInfo] {
        var infos: [StudioBarSectionInfo] = []
        var globalBar = 0
        for item in arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            let label = (item.labelOverride?.isEmpty == false) ? item.labelOverride! : section.name
            let chordsByBar = Dictionary(grouping: section.chordEvents, by: \.barIndex)
            for localBar in 0..<bars {
                let chords = (chordsByBar[localBar] ?? []).sorted { lhs, rhs in
                    if lhs.beatOffset != rhs.beatOffset { return lhs.beatOffset < rhs.beatOffset }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                let symbols = chords.map(StudioMusic.chordText)
                let chordLabel: String? = symbols.isEmpty
                    ? nil
                    : symbols.prefix(2).joined(separator: " ") + (symbols.count > 2 ? " +" : "")
                infos.append(StudioBarSectionInfo(
                    barIndex: globalBar + localBar,
                    sectionLabel: label,
                    sectionColor: section.color,
                    chordLabel: chordLabel
                ))
            }
            globalBar += bars
        }
        if infos.isEmpty {
            infos = (0..<studioTotalBars).map {
                StudioBarSectionInfo(barIndex: $0, sectionLabel: String(localized: "Song"), sectionColor: fallbackColor, chordLabel: nil)
            }
        }
        return infos
    }

    /// Section at a given (0-based) bar.
    func studioSection(atBar bar: Int) -> StudioSectionSpan? {
        studioSectionSpans.first { bar >= $0.startBar && bar < $0.endBar }
    }
}

// MARK: - Instrument presentation

extension StudioInstrument {
    /// A more distinctive SF Symbol per instrument for Studio surfaces.
    var studioSymbol: String {
        switch self {
        case .piano: return "pianokeys"
        case .synth: return "waveform.path"
        case .guitar: return "guitars"
        case .bass: return "guitars.fill"
        case .strings: return "music.quarternote.3"
        case .brass: return "horn"
        case .woodwinds: return "wind"
        case .organ: return "pianokeys.inverse"
        case .mallets: return "circle.grid.3x3"
        case .drums: return "circle.grid.cross"
        case .audio: return "waveform"
        }
    }

    /// One editorial line describing the instrument's role.
    var studioTagline: String {
        switch self {
        case .piano: return String(localized: "Chords and colour from the keys.")
        case .synth: return String(localized: "Pads and leads with a modern glow.")
        case .guitar: return String(localized: "Strums, picks and chops.")
        case .bass: return String(localized: "The floor everything stands on.")
        case .strings: return String(localized: "Long, warm lines that lift a chorus.")
        case .brass: return String(localized: "Bright stabs and bold swells.")
        case .woodwinds: return String(localized: "A singing melodic voice.")
        case .organ: return String(localized: "Sustained, churchy warmth.")
        case .mallets: return String(localized: "Glassy, bell-like sparkle.")
        case .drums: return String(localized: "The groove — kick, snare and hats.")
        case .audio: return String(localized: "Your recorded take, in time.")
        }
    }

    /// The sound a new track of this instrument starts on for a style.
    func studioRecommendedVariant(for style: StudioStyle?) -> InstrumentVariant? {
        SoundFontManager.defaultVariant(for: self, style: style)
    }
}

extension StudioTrack {
    /// Display name of the sound actually playing on this track.
    var studioSoundName: String {
        if instrument.isAudio { return String(localized: "Recording") }
        let resolved = SoundFontManager.resolvedVariant(for: instrument, variant: variant)
        return resolved?.displayName ?? variant?.displayName ?? instrument.title
    }
}

// MARK: - Track actions

enum StudioTrackActions {
    /// Switches a track's sound, keeping its register and clamping notes into range.
    static func applyVariant(
        _ newVariant: InstrumentVariant,
        to track: StudioTrack,
        style: StudioStyle?,
        onChange: () -> Void
    ) {
        let previousVariant = track.variant
        guard previousVariant != newVariant else { return }

        let remappedShift = StudioGenerator.remapOctaveShiftPreservingDisplayOffset(
            track.octaveShift,
            for: track.instrument,
            oldVariant: previousVariant,
            newVariant: newVariant
        )
        track.variant = newVariant
        track.octaveShift = remappedShift

        let targetRange = StudioGenerator.instrumentRange(
            for: track.instrument,
            variant: newVariant,
            style: style,
            octaveShift: remappedShift
        )
        for note in track.notes {
            note.pitch = StudioMusic.fit(note.pitch, into: targetRange)
        }
        onChange()
    }

    /// Rebuilds one track's notes from its current playing-style settings.
    static func regenerate(
        _ track: StudioTrack,
        project: Project,
        style: StudioStyle,
        modelContext: ModelContext
    ) {
        // Song-aware: applies section dynamics, section boundaries and the
        // rest of the arrangement, same as a full regeneration.
        StudioGenerator.regenerateTrack(track, project: project, style: style, modelContext: modelContext)
        project.updatedAt = Date()
    }
}

// MARK: - Small controls

/// Round instrument mark: soft instrument tint, ink glyph.
struct StudioInstrumentBadge: View {
    let instrument: StudioInstrument
    var size: CGFloat = 40
    var isDimmed: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(instrument.color.opacity(isDimmed ? 0.08 : 0.2))
            Circle()
                .strokeBorder(instrument.color.opacity(0.45), lineWidth: 1)
            Image(systemName: instrument.studioSymbol)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(isDimmed ? 0.45 : 0.9))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Live level meter in brand teal. Square-root curve so quiet parts still read.
struct StudioLevelMeter: View {
    let level: Float
    var isActive: Bool = true
    var height: CGFloat = 3

    private var normalized: CGFloat {
        CGFloat(min(1, max(0, sqrt(level))))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignSystem.Colors.border)
                Capsule()
                    .fill(DesignSystem.Colors.brand)
                    .frame(width: isActive ? max(height, geo.size.width * normalized) : 0)
                    .opacity(isActive ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.linear(duration: 0.1), value: normalized)
        .accessibilityHidden(true)
    }
}

/// Mute / Solo pill. Mute on = ink; Solo on = teal.
struct StudioMixToggle: View {
    enum Kind { case mute, solo }
    let kind: Kind
    let isOn: Bool
    let action: () -> Void

    private var letter: String { kind == .mute ? "M" : "S" }
    private var onFill: Color {
        kind == .mute ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.primary
    }
    private var onText: Color {
        kind == .mute ? DesignSystem.Colors.background : DesignSystem.Colors.onPrimary
    }

    var body: some View {
        Button {
            action()
            haptic(.selection)
        } label: {
            Text(letter)
                .font(DesignSystem.Typography.buttonSmall)
                .foregroundStyle(isOn ? onText : DesignSystem.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isOn ? onFill : DesignSystem.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isOn ? Color.clear : DesignSystem.Colors.borderActive, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .mute ? "Mute" : "Solo")
        .accessibilityValue(isOn ? "On" : "Off")
        .animation(DesignSystem.Animations.quickSpring, value: isOn)
    }
}

/// Labeled slider row used by the mixer and Sound panel.
struct StudioSliderRow: View {
    let title: LocalizedStringKey
    let value: Binding<Float>
    let range: ClosedRange<Float>
    let valueText: String
    var tint: Color = DesignSystem.Colors.primary
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(minWidth: 52, alignment: .leading)
            Slider(value: value, in: range, onEditingChanged: onEditingChanged)
                .tint(tint)
                .onChange(of: value.wrappedValue) { _, _ in onChange() }
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
            Text(valueText)
                .font(DesignSystem.Typography.caption.monospacedDigit())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(minWidth: 44, alignment: .trailing)
        }
    }
}

/// Musical slider with words at either end instead of numbers ("Soft … Driving").
struct StudioFeelSlider: View {
    let title: LocalizedStringKey
    let lowLabel: LocalizedStringKey
    let highLabel: LocalizedStringKey
    @Binding var value: Double
    var tint: Color = DesignSystem.Colors.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(Int((value * 100).rounded()))")
                    .font(DesignSystem.Typography.caption.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            Slider(value: $value, in: 0...1)
                .tint(tint)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value * 100).rounded())) percent")
            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(DesignSystem.Typography.italicSmall)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}

/// Glass icon button for floating toolbars.
struct StudioGlassIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isOn: Bool = false
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(isOn ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(
            Circle().fill(isOn ? DesignSystem.Colors.primaryLight : Color.clear)
        )
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Share sheet

/// Minimal activity sheet (Studio-scoped to avoid collisions).
struct StudioShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct StudioShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
