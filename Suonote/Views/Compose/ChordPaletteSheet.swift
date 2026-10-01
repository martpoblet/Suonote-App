import SwiftUI
import SwiftData

// MARK: - Chord palette
/// Fast chord entry for one beat of a section.
///
/// Order of the page follows how songwriters think: the chords of the key
/// (with Roman numerals), what usually comes next, chords already in the
/// song, then a builder (root · quality · bass · colour) and the length.
/// Every tap auditions. "Add & next" keeps the sheet open and moves on.
struct ChordPaletteSheet: View {
    let section: SectionTemplate
    @Bindable var project: Project
    let preview: ChordPreviewPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(ComposeEditor.self) private var editor

    @State private var slot: ChordSlot
    @State private var value: ComposeChordValue
    @State private var duration: Double
    @State private var isEditing: Bool
    @State private var context: PaletteContext
    @State private var showAllQualities = false
    @State private var showColor = false
    @State private var showDiagram = false
    @State private var showingIdeas = false

    private static let commonQualities: [ChordQuality] = [
        .major, .minor, .dominant7, .major7, .minor7, .sus2,
        .sus4, .add9, .sixth, .diminished, .augmented, .halfDiminished7
    ]
    private static let colorExtensions = ["7", "9", "11", "13", "sus2", "sus4", "add9"]

    init(section: SectionTemplate, slot: ChordSlot, project: Project, preview: ChordPreviewPlayer) {
        self.section = section
        self.project = project
        self.preview = preview
        let context = PaletteContext(section: section, project: project, slot: slot)
        let existing = ComposeChordOps.chord(at: slot, in: section)
        _slot = State(initialValue: slot)
        _context = State(initialValue: context)
        _isEditing = State(initialValue: existing != nil)
        _value = State(initialValue: existing.map { ComposeChordValue($0) }
            ?? context.smart.first.map { ComposeChordValue($0) }
            ?? ComposeChordValue(root: section.effectiveKeyRoot, quality: section.effectiveKeyMode.isMinor ? .minor : .major))
        let initialDuration = existing?.duration ?? min(Double(project.timeTop), context.maxDuration)
        _duration = State(initialValue: max(0.5, min(initialDuration, context.maxDuration)))
    }

    private var beatsPerBar: Int { max(1, project.timeTop) }

    var body: some View {
        SheetScaffold(
            title: isEditing ? String(localized: "Edit chord") : String(localized: "Add chord"),
            subtitle: String(localized: "\(section.name) · bar \(slot.barIndex + 1), beat \(ComposeFormat.beatPosition(slot.beatOffset))")
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                hero
                if !value.isRest {
                    diatonicSection
                    suggestionsSection
                    if !context.songChords.isEmpty { songChordsSection }
                    builderSection
                }
                lengthSection
                if isEditing { removeButton }
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .sheet(isPresented: $showingIdeas) {
            SmartSuggestionsModal(
                section: section,
                keyRoot: context.keyRoot,
                keyMode: context.keyMode,
                barIndex: slot.barIndex,
                beatsPerBar: beatsPerBar,
                previousChords: context.previous,
                nextChords: context.next,
                preview: preview,
                onSelect: { picked in
                    select(picked, audition: false)
                    showingIdeas = false
                },
                onApplyProgression: applyProgression
            )
            .presentationDetents([.large])
            .studioModalStyle()
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    if value.isRest {
                        Text("Rest")
                            .font(DesignSystem.Typography.display)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Text("Silence for \(ComposeFormat.beatsUnit(duration)) — no harmony is generated.")
                            .font(DesignSystem.Typography.italicSmall)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    } else {
                        ComposeChordSymbol(value: value, size: .hero)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .contentTransition(.opacity)
                        Text(functionLine)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.primaryDark)
                        Text(notesLine)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                if !value.isRest {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        ComposeIconButton(systemImage: "speaker.wave.2.fill", label: String(localized: "Play \(value.display)"), tint: DesignSystem.Colors.primaryDark) {
                            audition()
                        }
                        ComposeIconButton(
                            systemImage: showDiagram ? "pianokeys.inverse" : "pianokeys",
                            label: showDiagram ? String(localized: "Hide diagram") : String(localized: "Show piano and guitar diagram")
                        ) {
                            haptic(.selection)
                            withAnimation(DesignSystem.Animations.smoothSpring) { showDiagram.toggle() }
                        }
                    }
                }
            }

            if showDiagram && !value.isRest {
                ChordDiagramView(
                    root: value.root,
                    quality: value.quality,
                    extensions: value.extensions,
                    accentColor: section.color,
                    bassNote: value.slashRoot
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                SelectableChip(title: String(localized: "Chord"), icon: "music.note", isSelected: !value.isRest) {
                    haptic(.selection)
                    withAnimation(DesignSystem.Animations.quickSpring) { value.isRest = false }
                }
                SelectableChip(title: String(localized: "Rest"), icon: "pause", isSelected: value.isRest) {
                    haptic(.selection)
                    withAnimation(DesignSystem.Animations.quickSpring) {
                        value.isRest = true
                        showDiagram = false
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var functionLine: String {
        let numeral = MusicTheoryUtils.romanNumeral(root: value.root, quality: value.quality, keyRoot: context.keyRoot, mode: context.keyMode)
        if let match = context.diatonic.first(where: { $0.root == value.root && $0.quality == value.quality }),
           let function = match.reason.components(separatedBy: " - ").last {
            return String(localized: "\(numeral) · \(function) in \(ComposeFormat.keyName(root: context.keyRoot, mode: context.keyMode))")
        }
        return String(localized: "\(numeral) · outside the key")
    }

    private var notesLine: String {
        var notes = ChordUtils.getChordNotes(root: value.root, quality: value.quality)
        if let bass = value.slashRoot, !notes.contains(bass) { notes.insert(bass, at: 0) }
        return notes.joined(separator: " · ")
    }

    // MARK: Diatonic

    private var diatonicSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: String(localized: "In \(ComposeFormat.keyName(root: context.keyRoot, mode: context.keyMode))"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: DesignSystem.Spacing.xs)], spacing: DesignSystem.Spacing.xs) {
                ForEach(context.diatonic) { suggestion in
                    chordTile(
                        ComposeChordValue(suggestion),
                        caption: suggestion.romanNumeral ?? ""
                    )
                }
            }
        }
    }

    private func chordTile(_ tile: ComposeChordValue, caption: String) -> some View {
        let selected = !value.isRest && tile.root == value.root && tile.quality == value.quality && value.extensions == tile.extensions
        return Button {
            select(tile)
        } label: {
            VStack(spacing: 2) {
                ComposeChordSymbol(value: tile, size: .small)
                    .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                Text(caption)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(selected ? DesignSystem.Colors.background.opacity(0.75) : DesignSystem.Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(selected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.95))
        .accessibilityLabel("\(ComposeChordSpeech.spoken(tile)), \(caption)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(
                title: String(localized: "Next up"),
                detail: context.previous.last.map { String(localized: "after \($0.display)") } ?? String(localized: "to open the section"),
                actionTitle: String(localized: "More ideas"),
                action: {
                    haptic(.light)
                    showingIdeas = true
                }
            )
            ScrollView(.horizontal) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(context.smart) { suggestion in
                        suggestionTile(suggestion)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func suggestionTile(_ suggestion: ChordSuggestion) -> some View {
        let tile = ComposeChordValue(suggestion)
        let selected = !value.isRest && tile == ComposeChordValue(root: value.root, quality: value.quality, extensions: value.extensions)
        return Button {
            select(tile)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                ComposeChordSymbol(value: tile, size: .regular)
                    .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                Text(shortReason(suggestion))
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(selected ? DesignSystem.Colors.background.opacity(0.75) : DesignSystem.Colors.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 104, alignment: .leading)
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(selected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.95))
        .accessibilityLabel("\(ComposeChordSpeech.spoken(tile)). \(suggestion.reason)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shortReason(_ suggestion: ChordSuggestion) -> String {
        if let numeral = suggestion.romanNumeral, !suggestion.reason.hasPrefix(numeral) {
            return "\(numeral) · \(suggestion.reason)"
        }
        return suggestion.reason
    }

    // MARK: Song chords

    private var songChordsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: String(localized: "In this song"))
            ComposeFlowLayout(spacing: DesignSystem.Spacing.xs, lineSpacing: DesignSystem.Spacing.xs) {
                ForEach(context.songChords, id: \.self) { chord in
                    let selected = chord == value
                    Button {
                        select(chord)
                    } label: {
                        ComposeChordSymbol(value: chord, size: .small)
                            .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface))
                            .overlay(Capsule().stroke(selected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1))
                    }
                    .buttonStyle(AnimatedPressButtonStyle(scale: 0.95))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Builder

    private var builderSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            SectionHeader(title: String(localized: "Build your own"))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Root").font(DesignSystem.Typography.caption).foregroundStyle(DesignSystem.Colors.textSecondary)
                noteGrid(selected: value.root) { note in
                    value.root = note
                    audition()
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text("Quality").font(DesignSystem.Typography.caption).foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                    Button(showAllQualities ? "Fewer" : "All qualities") {
                        haptic(.selection)
                        withAnimation(DesignSystem.Animations.smoothSpring) { showAllQualities.toggle() }
                    }
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.xs), count: 4), spacing: DesignSystem.Spacing.xs) {
                    ForEach(showAllQualities ? ChordQuality.allCases : Self.commonQualities, id: \.self) { quality in
                        qualityTile(quality)
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Bass note").font(DesignSystem.Typography.caption).foregroundStyle(DesignSystem.Colors.textSecondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        SelectableChip(title: String(localized: "Root"), isSelected: value.slashRoot == nil) {
                            haptic(.selection)
                            value.slashRoot = nil
                        }
                        ForEach(ComposeFormat.chromatic.filter { $0 != value.root }, id: \.self) { note in
                            SelectableChip(title: "/" + displayNote(note), isSelected: value.slashRoot == note) {
                                haptic(.selection)
                                value.slashRoot = note
                                audition()
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Button {
                    haptic(.selection)
                    withAnimation(DesignSystem.Animations.smoothSpring) { showColor.toggle() }
                } label: {
                    HStack {
                        Text("Add colour")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        if !value.extensions.isEmpty {
                            Text(value.extensions.joined(separator: " "))
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.primaryDark)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .rotationEffect(.degrees(showColor ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showColor {
                    ComposeFlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(Self.colorExtensions, id: \.self) { ext in
                            let isOn = value.extensions.contains(ext)
                            SelectableChip(title: ext, isSelected: isOn) {
                                haptic(.selection)
                                if isOn {
                                    value.extensions.removeAll { $0 == ext }
                                } else if value.extensions.count < 2 {
                                    value.extensions.append(ext)
                                }
                            }
                            .opacity(!isOn && value.extensions.count >= 2 ? 0.4 : 1)
                            .disabled(!isOn && value.extensions.count >= 2)
                        }
                    }
                    Text("Up to two extra tones, written after the quality.")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func noteGrid(selected: String, onPick: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(ComposeFormat.chromatic, id: \.self) { note in
                let isSelected = note == selected
                let inKey = context.scaleNotes.contains(note)
                Button {
                    haptic(.selection)
                    onPick(note)
                } label: {
                    Text(displayNote(note))
                        .font(DesignSystem.Typography.chordSmall)
                        .foregroundStyle(isSelected ? DesignSystem.Colors.background : (inKey ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                                .fill(isSelected ? DesignSystem.Colors.textPrimary : (inKey ? DesignSystem.Colors.surfaceSecondary : Color.clear))
                        )
                        .overlay(alignment: .bottom) {
                            if inKey && !isSelected {
                                Circle().fill(DesignSystem.Colors.primary).frame(width: 4, height: 4).padding(.bottom, 4)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ComposeChordSpeech.note(note))
                .accessibilityValue(inKey ? "In key" : "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func qualityTile(_ quality: ChordQuality) -> some View {
        let isSelected = value.quality == quality
        let inKey = context.diatonic.contains { $0.root == value.root && $0.quality == quality }
        let tile = ComposeChordValue(root: value.root, quality: quality)
        return Button {
            haptic(.selection)
            value.quality = quality
            audition()
        } label: {
            VStack(spacing: 1) {
                ComposeChordSymbol(value: tile, size: .small)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                Text(quality.displayName)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.background.opacity(0.75) : DesignSystem.Colors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surfaceSecondary)
            )
            .overlay(alignment: .topTrailing) {
                if inKey && !isSelected {
                    Circle().fill(DesignSystem.Colors.primary).frame(width: 5, height: 5).padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(quality.displayName)
        .accessibilityValue(inKey ? "In key" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func displayNote(_ note: String) -> String {
        MusicTheory.displayName(for: note, inKey: context.keyRoot, mode: context.keyMode)
    }

    // MARK: Length

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: String(localized: "Length"), detail: String(localized: "up to \(ComposeFormat.beatsUnit(context.maxDuration)) here"))
            ScrollView(.horizontal) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(durationOptions, id: \.self) { option in
                        let isSelected = abs(option - duration) < 0.01
                        Button {
                            haptic(.selection)
                            withAnimation(DesignSystem.Animations.quickSpring) { duration = option }
                        } label: {
                            VStack(spacing: 0) {
                                Text(ComposeFormat.beats(option))
                                    .font(DesignSystem.Typography.title3)
                                    .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                                Text(lengthCaption(option))
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(isSelected ? DesignSystem.Colors.background.opacity(0.75) : DesignSystem.Colors.textTertiary)
                            }
                            .frame(minWidth: 52)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                    .fill(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                    .stroke(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ComposeFormat.beatsUnit(option))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            ComposeBeatRuler(
                beatsPerBar: beatsPerBar,
                start: slot.beatOffset,
                duration: duration,
                color: section.color
            )
        }
    }

    private var durationOptions: [Double] {
        let maxDuration = context.maxDuration
        var options: [Double] = maxDuration >= 0.5 ? [0.5] : []
        var beat = 1.0
        while beat <= maxDuration + 0.001 {
            options.append(beat)
            beat += 1
        }
        if let last = options.last, maxDuration - last > 0.25 { options.append(maxDuration) }
        if abs(duration.truncatingRemainder(dividingBy: 1) - 0.5) < 0.01, !options.contains(where: { abs($0 - duration) < 0.01 }) {
            options.append(duration)
            options.sort()
        }
        return options
    }

    private func lengthCaption(_ beats: Double) -> String {
        if abs(beats - Double(beatsPerBar)) < 0.01 && slot.beatOffset == 0 { return String(localized: "full bar") }
        return beats <= 1 ? String(localized: "beat") : String(localized: "beats")
    }

    // MARK: Remove

    private var removeButton: some View {
        Button(role: .destructive) {
            guard let chord = ComposeChordOps.chord(at: slot, in: section) else { return }
            haptic(.warning)
            editor.perform(String(localized: "Delete chord"), toast: chord.isRest ? String(localized: "Rest removed") : String(localized: "\(chord.display) removed")) {
                ComposeChordOps.delete(chord, from: section, context: editor.modelContext)
            }
            dismiss()
        } label: {
            Label(value.isRest ? "Remove rest" : "Remove chord", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(OutlineButtonStyle(tint: DesignSystem.Colors.error))
    }

    // MARK: Action bar

    private var nextSlotAfterCommit: (bar: Int, beat: Double)? {
        let end = slot.beatOffset + duration
        if end < Double(beatsPerBar) - 0.001 {
            return ComposeChordOps.nextEmptySlot(in: section, afterBar: slot.barIndex, beat: end, beatsPerBar: beatsPerBar)
        }
        guard slot.barIndex + 1 < section.bars else { return nil }
        return ComposeChordOps.nextEmptySlot(in: section, afterBar: slot.barIndex + 1, beat: 0, beatsPerBar: beatsPerBar)
    }

    private var actionBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if nextSlotAfterCommit != nil {
                Button {
                    commit(advance: true)
                } label: {
                    Label(isEditing ? "Save & next" : "Add & next", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(OutlineButtonStyle())
                .accessibilityHint("Saves and moves to the next empty beat")
            }
            PrimaryButton(primaryTitle, icon: isEditing ? "checkmark" : "plus") {
                commit(advance: false)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.gutter)
        .padding(.top, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.xs)
        .background(
            DesignSystem.Colors.background
                .opacity(0.94)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var primaryTitle: String {
        if value.isRest {
            return isEditing ? String(localized: "Save rest") : String(localized: "Add rest")
        }
        return isEditing ? String(localized: "Save \(value.display)") : String(localized: "Add \(value.display)")
    }

    // MARK: Actions

    private func select(_ picked: ComposeChordValue, audition shouldPlay: Bool = true) {
        haptic(.selection)
        withAnimation(DesignSystem.Animations.quickSpring) {
            value = ComposeChordValue(root: picked.root, quality: picked.quality, extensions: picked.extensions, slashRoot: picked.slashRoot)
        }
        if shouldPlay { audition() }
    }

    private func audition() {
        guard !value.isRest else { return }
        preview.playChord(root: value.root, quality: value.quality)
    }

    private func commit(advance: Bool) {
        let committed = value
        let length = max(0.5, min(duration, context.maxDuration))
        let target = slot
        duration = length
        editor.perform(isEditing ? String(localized: "Edit chord") : String(localized: "Add chord")) {
            ComposeChordOps.place(committed, in: section, bar: target.barIndex, beat: target.beatOffset, duration: length)
        }
        haptic(.success)
        // Look for the next gap only after placing, so half-beat gaps are found too.
        let next = advance ? nextSlotAfterCommit : nil

        guard let next else {
            dismiss()
            return
        }
        let nextSlot = ChordSlot(barIndex: next.bar, beatOffset: next.beat, sectionId: section.id)
        let nextContext = PaletteContext(section: section, project: project, slot: nextSlot)
        withAnimation(DesignSystem.Animations.smoothSpring) {
            slot = nextSlot
            context = nextContext
            isEditing = ComposeChordOps.chord(at: nextSlot, in: section) != nil
            duration = max(0.5, min(length, nextContext.maxDuration))
            if let suggestion = nextContext.smart.first {
                value = ComposeChordValue(suggestion)
            }
        }
    }

    private func applyProgression(_ chords: [ComposeChordValue]) {
        let start = slot.barIndex
        editor.perform(String(localized: "Write progression"), toast: String(localized: "Progression written")) {
            ComposeChordOps.applyProgression(chords, to: section, startBar: start, beatsPerBar: beatsPerBar, context: editor.modelContext)
        }
        showingIdeas = false
        dismiss()
    }
}

// MARK: - Palette context

/// Everything the palette derives from the song, computed once per slot.
struct PaletteContext {
    let keyRoot: String
    let keyMode: KeyMode
    let diatonic: [ChordSuggestion]
    let smart: [ChordSuggestion]
    let previous: [ChordEvent]
    let next: [ChordEvent]
    let songChords: [ComposeChordValue]
    let scaleNotes: Set<String>
    let maxDuration: Double

    @MainActor
    init(section: SectionTemplate, project: Project, slot: ChordSlot) {
        let root = section.effectiveKeyRoot
        let mode = section.effectiveKeyMode
        keyRoot = root
        keyMode = mode
        diatonic = ChordSuggestionEngine.diatonicChords(forKey: root, mode: mode)
        scaleNotes = Set(mode.intervals.map { ChordSuggestionEngine.transpose(note: root, semitones: $0) })

        let ordered = section.chordEvents
            .filter { !$0.isRest }
            .sorted { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) }
        let previousChords = ordered.filter { ($0.barIndex, $0.beatOffset) < (slot.barIndex, slot.beatOffset) }
        let nextChords = ordered.filter { ($0.barIndex, $0.beatOffset) > (slot.barIndex, slot.beatOffset) }
        previous = previousChords
        next = nextChords

        smart = Array(ChordSuggestionEngine.suggestContextualChords(
            previousChords: previousChords,
            nextChords: nextChords,
            inKey: root,
            mode: mode
        ).prefix(8))

        var counts: [ComposeChordValue: Int] = [:]
        var firstSeen: [ComposeChordValue: Int] = [:]
        var index = 0
        for item in ComposeChordOps.orderedItems(project) {
            for chord in item.sectionTemplate?.chordEvents ?? [] where !chord.isRest {
                let value = ComposeChordValue(chord)
                counts[value, default: 0] += 1
                if firstSeen[value] == nil { firstSeen[value] = index }
                index += 1
            }
        }
        songChords = counts.keys
            .sorted { (counts[$0]!, -firstSeen[$0]!) > (counts[$1]!, -firstSeen[$1]!) }
            .prefix(10)
            .map { $0 }

        maxDuration = max(0.5, ComposeChordOps.maxDuration(
            in: section,
            bar: slot.barIndex,
            from: slot.beatOffset,
            beatsPerBar: max(1, project.timeTop)
        ))
    }
}

// MARK: - Beat ruler

/// Shows where the chord sits in its bar: beats as cells, the chord's span filled.
struct ComposeBeatRuler: View {
    let beatsPerBar: Int
    let start: Double
    let duration: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let beatWidth = proxy.size.width / CGFloat(max(1, beatsPerBar))
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(0..<beatsPerBar, id: \.self) { beat in
                        Rectangle()
                            .fill(DesignSystem.Colors.surfaceSecondary)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(DesignSystem.Colors.border).frame(width: beat == 0 ? 0 : 1)
                            }
                    }
                }
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.85))
                    .frame(width: max(4, beatWidth * CGFloat(duration) - 2))
                    .offset(x: beatWidth * CGFloat(start) + 1)
                    .animation(DesignSystem.Animations.quickSpring, value: duration)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(height: 14)
        .accessibilityElement()
        .accessibilityLabel("Starts on beat \(ComposeFormat.beatPosition(start)), lasts \(ComposeFormat.beatsUnit(duration))")
    }
}
