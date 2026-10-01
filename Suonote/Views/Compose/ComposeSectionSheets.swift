import SwiftUI
import SwiftData

// MARK: - Presets

enum SectionPreset: String, CaseIterable, Identifiable {
    case intro = "Intro"
    case verse = "Verse"
    case preChorus = "Pre-Chorus"
    case chorus = "Chorus"
    case bridge = "Bridge"
    case solo = "Solo"
    case outro = "Outro"

    var id: String { rawValue }
    /// Default section name written into the song (kept in English: section
    /// names are matched elsewhere, e.g. SectionNameLabel abbreviations).
    var name: String { rawValue }

    /// Localized kind name for display only.
    var displayName: String {
        switch self {
        case .intro: return String(localized: "Intro")
        case .verse: return String(localized: "Verse")
        case .preChorus: return String(localized: "Pre-Chorus")
        case .chorus: return String(localized: "Chorus")
        case .bridge: return String(localized: "Bridge")
        case .solo: return String(localized: "Solo")
        case .outro: return String(localized: "Outro")
        }
    }

    var defaultBars: Int {
        switch self {
        case .intro, .preChorus, .bridge, .outro: return 4
        case .verse, .chorus, .solo: return 8
        }
    }

    var icon: String {
        switch self {
        case .intro: return "arrow.right.to.line"
        case .verse: return "text.alignleft"
        case .preChorus: return "arrow.up.right"
        case .chorus: return "music.note.list"
        case .bridge: return "arrow.triangle.branch"
        case .solo: return "guitars"
        case .outro: return "arrow.left.to.line"
        }
    }

    var sectionColor: SectionColor {
        switch self {
        case .intro: return .moss
        case .verse: return .sky
        case .preChorus: return .sand
        case .chorus: return .berry
        case .bridge: return .coral
        case .solo: return .lavender
        case .outro: return .ocean
        }
    }

    var color: Color { sectionColor.color }
    var colorHex: String { sectionColor.hex }

    var blurb: String {
        switch self {
        case .intro: return String(localized: "Sets the mood")
        case .verse: return String(localized: "Tells the story")
        case .preChorus: return String(localized: "Builds the lift")
        case .chorus: return String(localized: "The big idea")
        case .bridge: return String(localized: "Somewhere new")
        case .solo: return String(localized: "Let it sing")
        case .outro: return String(localized: "Says goodbye")
        }
    }
}

struct PresetCard: View {
    let preset: SectionPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(preset.color).frame(width: 8, height: 8)
                    Spacer(minLength: 0)
                    Image(systemName: preset.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.background.opacity(0.8) : DesignSystem.Colors.textTertiary)
                }
                Text(preset.displayName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(preset.blurb)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.background.opacity(0.75) : DesignSystem.Colors.textTertiary)
                    .lineLimit(1)
            }
            .padding(DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.97))
        .accessibilityLabel("\(preset.displayName), \(preset.blurb)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Shared form pieces

/// Text field set on a recessed well.
struct ComposeTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(DesignSystem.Typography.title3)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .wellStyle()
    }
}

/// Erode figure with − / + glass buttons.
struct ComposeStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String? = nil
    var step: Int = 1

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(label)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer(minLength: 0)
            button("minus", delta: -step)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                if let unit {
                    Text(unit)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .frame(minWidth: 58)
            button("plus", delta: step)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit ?? "")")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(step)
            case .decrement: change(-step)
            @unknown default: break
            }
        }
    }

    private func button(_ icon: String, delta: Int) -> some View {
        Button {
            change(delta)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .disabled(delta < 0 ? value <= range.lowerBound : value >= range.upperBound)
    }

    private func change(_ delta: Int) {
        let next = min(max(value + delta, range.lowerBound), range.upperBound)
        guard next != value else { return }
        haptic(.selection)
        withAnimation(DesignSystem.Animations.quickSpring) { value = next }
    }
}

/// Row of the eight section colours.
struct ComposeColorPicker: View {
    @Binding var selection: SectionColor

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SectionColor.allCases) { color in
                Button {
                    haptic(.selection)
                    selection = color
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.Colors.textPrimary, lineWidth: selection == color ? 2 : 0)
                                .padding(-4)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.localizedName)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
    }
}

// MARK: - New section

struct SectionCreatorView: View {
    @Bindable var project: Project
    var insertAfter: ArrangementItem? = nil
    let onSectionCreated: (SectionTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ComposeEditor.self) private var editor

    @State private var preset: SectionPreset = .verse
    @State private var name = ""
    @State private var bars = 8
    @State private var color: SectionColor = .sky
    @State private var nameEdited = false

    var body: some View {
        SheetScaffold(
            title: String(localized: "New section"),
            subtitle: insertAfter?.sectionTemplate.map { String(localized: "Goes after \($0.name)") } ?? String(localized: "Added to the end of the song"),
            primaryTitle: trimmedName.isEmpty ? String(localized: "Add section") : String(localized: "Add \(trimmedName)"),
            primaryIcon: "plus",
            primaryDisabled: trimmedName.isEmpty,
            primaryAction: create
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    SectionHeader(title: String(localized: "Kind"))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: DesignSystem.Spacing.xs)], spacing: DesignSystem.Spacing.xs) {
                        ForEach(SectionPreset.allCases) { option in
                            PresetCard(preset: option, isSelected: preset == option) {
                                haptic(.selection)
                                apply(option)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    SectionHeader(title: String(localized: "Details"))
                    ComposeTextField(placeholder: "Section name", text: Binding(
                        get: { name },
                        set: { name = $0; nameEdited = true }
                    ))
                    ComposeStepper(label: String(localized: "Length"), value: $bars, range: 1...64, unit: String(localized: "bars"))
                    Hairline()
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Colour")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        ComposeColorPicker(selection: $color)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .cardStyle()
            }
        }
        .onAppear { apply(preset) }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func apply(_ option: SectionPreset) {
        withAnimation(DesignSystem.Animations.quickSpring) {
            preset = option
            bars = option.defaultBars
            color = option.sectionColor
            if !nameEdited || trimmedName.isEmpty {
                name = ComposeChordOps.uniqueName(option.name, in: project)
                nameEdited = false
            }
        }
    }

    private func create() {
        let finalName = trimmedName
        var created: SectionTemplate?
        editor.perform(String(localized: "Add section")) {
            created = ComposeChordOps.createSection(
                in: project,
                name: finalName,
                bars: bars,
                colorHex: color.hex,
                after: insertAfter
            )
        }
        haptic(.success)
        if let created { onSectionCreated(created) }
        dismiss()
    }
}

// MARK: - Edit section

struct SectionEditorSheet: View {
    @Bindable var section: SectionTemplate

    @Environment(\.dismiss) private var dismiss
    @Environment(ComposeEditor.self) private var editor

    @State private var name = ""
    @State private var bars = 4
    @State private var color: SectionColor = .sage
    @State private var ownKey = false
    @State private var keyRoot = "C"
    @State private var keyMode: KeyMode = .major
    @State private var ownTempo = false
    @State private var bpm = 120
    @State private var loaded = false

    var body: some View {
        SheetScaffold(
            title: String(localized: "Edit section"),
            subtitle: section.name,
            primaryTitle: String(localized: "Save changes"),
            primaryDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            primaryAction: save
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    SectionHeader(title: String(localized: "Details"))
                    ComposeTextField(placeholder: "Section name", text: $name)
                    ComposeStepper(label: String(localized: "Length"), value: $bars, range: 1...64, unit: String(localized: "bars"))
                    if let lost = lostBarsWarning {
                        Label(lost, systemImage: "exclamationmark.triangle")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.warning)
                    }
                    Hairline()
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Colour")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        ComposeColorPicker(selection: $color)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .cardStyle()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    SectionHeader(title: String(localized: "Overrides"), detail: String(localized: "Only for this section"))
                    Toggle(isOn: $ownKey.animation(DesignSystem.Animations.smoothSpring)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Own key")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Text(ownKey ? ComposeFormat.keyName(root: keyRoot, mode: keyMode) : String(localized: "Follows the song (\(songKeyName))"))
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .tint(DesignSystem.Colors.primary)

                    if ownKey {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                            ForEach(ComposeFormat.chromatic, id: \.self) { note in
                                let selected = keyRoot == note
                                Button {
                                    haptic(.selection)
                                    keyRoot = note
                                } label: {
                                    Text(note)
                                        .font(DesignSystem.Typography.chordSmall)
                                        .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                                                .fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surfaceSecondary)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                        ComposeFlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(KeyMode.commonModes, id: \.self) { mode in
                                SelectableChip(title: ComposeFormat.modeName(mode), isSelected: keyMode == mode) {
                                    haptic(.selection)
                                    keyMode = mode
                                }
                            }
                        }
                    }

                    Hairline()

                    Toggle(isOn: $ownTempo.animation(DesignSystem.Animations.smoothSpring)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Own tempo")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Text(ownTempo ? "\(bpm) bpm" : String(localized: "Follows the song (\(section.project?.bpm ?? 120) bpm)"))
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .tint(DesignSystem.Colors.primary)

                    if ownTempo {
                        ComposeStepper(label: String(localized: "Tempo"), value: $bpm, range: 20...300, unit: "bpm")
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .cardStyle()
            }
        }
        .onAppear(perform: load)
    }

    private var songKeyName: String {
        ComposeFormat.keyName(root: section.project?.keyRoot ?? "C", mode: section.project?.keyMode ?? .major)
    }

    private var lostBarsWarning: String? {
        guard bars < section.bars else { return nil }
        let lost = section.chordEvents.filter { $0.barIndex >= bars }.count
        guard lost > 0 else { return nil }
        return String(localized: "\(lost) chords after bar \(bars) will be removed.")
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        name = section.name
        bars = section.bars
        color = SectionColor.allCases.first { $0.hex.caseInsensitiveCompare(section.colorHex ?? "") == .orderedSame } ?? .sage
        ownKey = section.hasKeyChange
        keyRoot = section.effectiveKeyRoot
        keyMode = section.effectiveKeyMode
        ownTempo = section.hasTempoChange
        bpm = section.effectiveBpm
    }

    private func save() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        editor.perform(String(localized: "Edit section")) {
            section.name = finalName
            section.colorHex = color.hex
            ComposeChordOps.setBars(bars, in: section, context: editor.modelContext)
            section.sectionKeyRoot = ownKey ? keyRoot : nil
            section.sectionKeyModeRaw = ownKey ? keyMode.rawValue : nil
            section.sectionBpm = ownTempo ? bpm : nil
        }
        haptic(.success)
        dismiss()
    }
}
