import SwiftUI

// MARK: - Arrangement strip

/// A thin, proportional ribbon of section colors — the song's shape at a glance.
struct LibraryArrangementStrip: View {
    struct Segment: Identifiable {
        let id: Int
        let color: Color
        let bars: Int
    }

    let segments: [Segment]
    var height: CGFloat = 5

    init(project: Project, height: CGFloat = 5) {
        self.segments = project.libraryArrangement.enumerated().map {
            Segment(id: $0.offset, color: $0.element.color, bars: max(1, $0.element.bars))
        }
        self.height = height
    }

    init(starter: LibraryStarter, height: CGFloat = 5) {
        self.segments = starter.parts.enumerated().map {
            Segment(id: $0.offset, color: $0.element.color.color, bars: $0.element.bars)
        }
        self.height = height
    }

    var body: some View {
        GeometryReader { proxy in
            let total = CGFloat(max(1, segments.reduce(0) { $0 + $1.bars }))
            let gap: CGFloat = segments.count > 1 ? 2 : 0
            let usable = max(0, proxy.size.width - gap * CGFloat(max(0, segments.count - 1)))
            if segments.isEmpty {
                Capsule()
                    .stroke(DesignSystem.Colors.border, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            } else {
                HStack(spacing: gap) {
                    ForEach(segments) { segment in
                        Capsule()
                            .fill(segment.color)
                            .frame(width: max(2, usable * CGFloat(segment.bars) / total))
                    }
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Status

/// Quiet status label: colored dot + Manrope caption.
struct LibraryStatusLabel: View {
    let status: ProjectStatus
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.swiftUIColor)
                .frame(width: 6, height: 6)
            Text(status.libraryDisplayName)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(DesignSystem.Colors.surfaceSecondary))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.libraryDisplayName)")
    }
}

/// Status choice as a row of selectable chips.
struct LibraryStatusChips: View {
    @Binding var status: ProjectStatus
    var includeArchived: Bool = true

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ProjectStatus.allCases.filter { includeArchived || $0 != .archived }, id: \.self) { option in
                SelectableChip(title: option.libraryDisplayName, dot: option.swiftUIColor, isSelected: status == option) {
                    HapticFeedback.selection.trigger()
                    status = option
                }
            }
        }
    }
}

// MARK: - Form grouping

/// Eyebrow label + content block used in every sheet of the library area.
struct LibraryFormGroup<Content: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: title, detail: detail)
            content
        }
    }
}

// MARK: - Key

/// Root grid (Erode note names) + mode chips.
struct LibraryKeyPicker: View {
    @Binding var root: String
    @Binding var mode: KeyMode

    static let roots = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let modes: [KeyMode] = [.major, .minor, .dorian, .mixolydian, .lydian, .phrygian,
                                   .harmonicMinor, .melodicMinor, .pentatonicMajor, .pentatonicMinor,
                                   .blues, .locrian]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(Self.roots, id: \.self) { note in
                    let selected = root == note
                    Button {
                        HapticFeedback.selection.trigger()
                        root = note
                    } label: {
                        Text(note)
                            .font(DesignSystem.Typography.chordSmall)
                            .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                    .fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                    .stroke(selected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(note.hasSuffix("#") ? String(localized: "\(String(note.dropLast())) sharp") : note)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.modes, id: \.self) { option in
                        SelectableChip(title: option.libraryDisplayName, isSelected: mode == option || (option == .minor && mode == .aeolian)) {
                            HapticFeedback.selection.trigger()
                            mode = option
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Meter

struct LibraryMeterPicker: View {
    @Binding var top: Int
    @Binding var bottom: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeSignaturePreset.allCases) { preset in
                    let selected = preset.top == top && preset.bottom == bottom
                    Button {
                        HapticFeedback.selection.trigger()
                        top = preset.top
                        bottom = preset.bottom
                    } label: {
                        Text(preset.rawValue)
                            .font(DesignSystem.Typography.chordSmall)
                            .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface))
                            .overlay(Capsule().stroke(selected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.top) \(preset.bottom)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Tags

struct LibraryTagEditor: View {
    @Binding var tags: [String]
    var suggestions: [String] = []
    @State private var input = ""
    @FocusState private var focused: Bool

    private var openSuggestions: [String] {
        suggestions.filter { !tags.contains($0) }.prefix(8).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "number")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                TextField("Add a tag — mood, genre, who it's for", text: $input)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit(add)
                if !input.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: add)
                        .buttonStyle(InkButtonStyle(compact: true))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 10)
            .wellStyle()

            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            withAnimation(DesignSystem.Animations.quickSpring) {
                                tags.removeAll { $0 == tag }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(DesignSystem.Typography.buttonSmall)
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(DesignSystem.Colors.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(DesignSystem.Colors.textPrimary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove tag \(tag)")
                    }
                }
            }

            if !openSuggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(openSuggestions, id: \.self) { tag in
                        SelectableChip(title: tag, icon: "plus", isSelected: false) {
                            withAnimation(DesignSystem.Animations.quickSpring) { tags.append(tag) }
                        }
                    }
                }
            }
        }
    }

    private func add() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            withAnimation(DesignSystem.Animations.quickSpring) { tags.append(trimmed) }
        }
        input = ""
        focused = true
    }
}

// MARK: - Musical facts row

/// Key · Tempo · Meter as Erode stat tiles separated by hairline rules.
struct LibraryFactsRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            StatTile(label: String(localized: "Key"), value: project.libraryKeyShort)
            rule
            StatTile(label: String(localized: "Tempo"), value: "\(project.bpm)")
            rule
            StatTile(label: String(localized: "Meter"), value: project.libraryMeterLabel)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key \(project.libraryKeyLabel), \(project.bpm) BPM, \(project.timeTop) \(project.timeBottom) time")
    }

    private var rule: some View {
        Rectangle()
            .fill(DesignSystem.Colors.border)
            .frame(width: 1, height: 34)
    }
}
