import SwiftUI
import SwiftData

// MARK: - Chord grid
/// A section's measures laid out like a lead sheet: systems of 2–4 bars,
/// bar lines between measures, chord symbols in Erode sitting on their beats,
/// faint slots for empty beats. Tap to write, hold to edit/move.
struct ChordGridView: View {
    @Bindable var section: SectionTemplate
    @Bindable var project: Project
    let playingBar: Int?
    let onSlot: (ChordSlot) -> Void
    let onAudition: (ComposeChordValue) -> Void

    @Environment(ComposeEditor.self) private var editor
    @State private var width: CGFloat = 0

    private var beatsPerBar: Int { max(1, project.timeTop) }

    private var measuresPerRow: Int {
        guard width > 0 else { return 2 }
        let minimum = max(130, CGFloat(beatsPerBar) * 34)
        return min(4, max(1, Int(width / minimum)))
    }

    var body: some View {
        let byBar = ComposeChordOps.chordsByBar(section)
        let perRow = measuresPerRow
        let rowCount = Int(ceil(Double(section.bars) / Double(perRow)))
        let measureWidth = width > 0 ? (width - 6) / CGFloat(perRow) : 0

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if measureWidth > 0 {
                ForEach(0..<rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(row * perRow ..< min(section.bars, (row + 1) * perRow), id: \.self) { bar in
                            ComposeMeasureView(
                                section: section,
                                bar: bar,
                                chords: byBar[bar] ?? [],
                                beatsPerBar: beatsPerBar,
                                width: measureWidth,
                                isPlaying: playingBar == bar,
                                onSlot: onSlot,
                                onAudition: onAudition,
                                onDrop: handleDrop
                            )
                        }
                        let isLastRow = row == rowCount - 1
                        ComposeBarline(isFinal: isLastRow)
                        if isLastRow { Spacer(minLength: 0) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
            if abs(newWidth - width) > 0.5 { width = newWidth }
        }
    }

    // MARK: Drops

    /// Routes any drop inside this section: bars reorder, chords move/swap.
    private func handleDrop(_ payloadString: String, _ target: ComposeDropTarget) -> Bool {
        guard let payload = ComposeDragPayload(string: payloadString) else { return false }
        switch payload {
        case .bar(let sectionId, let sourceBar):
            guard sectionId == section.id, sourceBar != target.bar else { return false }
            editor.perform(String(localized: "Move bar")) {
                ComposeChordOps.moveBar(in: section, from: sourceBar, to: target.bar)
            }
            haptic(.success)
            return true

        case .chord(let sectionId, let chordId):
            guard let source = project.sectionTemplates.first(where: { $0.id == sectionId }),
                  let chord = source.chordEvents.first(where: { $0.id == chordId }) else { return false }
            var moved = false
            switch target {
            case .chord(let other):
                guard other.id != chord.id else { return false }
                editor.perform(String(localized: "Swap chords")) { ComposeChordOps.swap(chord, other) }
                moved = true
            case .beat(let bar, let beat):
                editor.perform(String(localized: "Move chord")) {
                    moved = ComposeChordOps.move(chord, from: source, to: section, bar: bar, beat: beat, beatsPerBar: beatsPerBar)
                }
            case .bar(let bar):
                guard let beat = ComposeChordOps.slots(
                    barIndex: bar,
                    chords: (ComposeChordOps.chordsByBar(section)[bar] ?? []).filter { $0.id != chord.id },
                    beatsPerBar: beatsPerBar
                ).first(where: { $0.chord == nil })?.beatOffset else { return false }
                editor.perform(String(localized: "Move chord")) {
                    moved = ComposeChordOps.move(chord, from: source, to: section, bar: bar, beat: beat, beatsPerBar: beatsPerBar)
                }
            }
            haptic(moved ? .success : .error)
            return moved
        }
    }
}

enum ComposeDropTarget {
    case chord(ChordEvent)
    case beat(bar: Int, beat: Double)
    case bar(Int)

    var bar: Int {
        switch self {
        case .chord(let chord): return chord.barIndex
        case .beat(let bar, _): return bar
        case .bar(let bar): return bar
        }
    }
}

// MARK: - Bar line

struct ComposeBarline: View {
    var isFinal = false

    var body: some View {
        HStack(spacing: 2) {
            Rectangle()
                .fill(DesignSystem.Colors.borderActive)
                .frame(width: 1)
            if isFinal {
                Rectangle()
                    .fill(DesignSystem.Colors.textSecondary)
                    .frame(width: 2.5)
            }
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Measure

struct ComposeMeasureView: View {
    let section: SectionTemplate
    let bar: Int
    let chords: [ChordEvent]
    let beatsPerBar: Int
    let width: CGFloat
    let isPlaying: Bool
    let onSlot: (ChordSlot) -> Void
    let onAudition: (ComposeChordValue) -> Void
    let onDrop: (String, ComposeDropTarget) -> Bool

    @Environment(ComposeEditor.self) private var editor
    @State private var isTargeted = false

    private let leadingInset: CGFloat = 7
    private let trailingInset: CGFloat = 4

    var body: some View {
        let slots = ComposeChordOps.slots(barIndex: bar, chords: chords, beatsPerBar: beatsPerBar)
        let beatWidth = max(0, width - 1 - leadingInset - trailingInset) / CGFloat(beatsPerBar)

        HStack(spacing: 0) {
            Rectangle()
                .fill(bar == 0 ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.borderActive)
                .frame(width: 1)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 4) {
                barNumber

                HStack(spacing: 0) {
                    ForEach(slots) { slot in
                        slotView(slot)
                            .frame(width: beatWidth * CGFloat(slot.duration), alignment: .leading)
                    }
                }
                .frame(height: 38)

                beatTicks(beatWidth: beatWidth)
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.vertical, 6)
        }
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                .fill(backgroundFill)
                .padding(.leading, 1)
        )
        .contextMenu { measureMenu }
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first else { return false }
            return onDrop(first, .bar(bar))
        } isTargeted: { isTargeted = $0 }
        .animation(DesignSystem.Animations.quickEase, value: isPlaying)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bar \(bar + 1)")
    }

    private var backgroundFill: Color {
        if isTargeted { return DesignSystem.Colors.surfaceHover }
        if isPlaying { return DesignSystem.Colors.primaryLight }
        return .clear
    }

    // MARK: Pieces

    private var barNumber: some View {
        Text("\(bar + 1)")
            .font(DesignSystem.Typography.caption2)
            .foregroundStyle(isPlaying ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textTertiary)
            .monospacedDigit()
            .padding(.trailing, 10)
            .contentShape(Rectangle())
            .draggable(ComposeDragPayload.bar(sectionId: section.id, barIndex: bar).string) {
                Text("Bar \(bar + 1)")
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(DesignSystem.Colors.surface))
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func slotView(_ slot: ComposeBeatSlot) -> some View {
        if let chord = slot.chord {
            ComposeChordToken(
                chord: chord,
                color: section.color,
                payload: ComposeDragPayload.chord(sectionId: section.id, chordId: chord.id).string,
                onTap: { onSlot(ChordSlot(barIndex: bar, beatOffset: chord.beatOffset, isHalf: chord.duration < 1, sectionId: section.id)) },
                onDrop: { onDrop($0, .chord(chord)) }
            )
            .contextMenu { chordMenu(chord) }
        } else {
            ComposeEmptyBeat(
                isDownbeat: abs(slot.beatOffset.rounded() - slot.beatOffset) < 0.01,
                label: String(localized: "Bar \(bar + 1), beat \(ComposeFormat.beatPosition(slot.beatOffset)), empty"),
                onTap: { onSlot(ChordSlot(barIndex: bar, beatOffset: slot.beatOffset, isHalf: slot.duration < 1, sectionId: section.id)) },
                onDrop: { onDrop($0, .beat(bar: bar, beat: slot.beatOffset)) }
            )
        }
    }

    private func beatTicks(beatWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<beatsPerBar, id: \.self) { beat in
                Rectangle()
                    .fill(beat == 0 ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textMuted)
                    .frame(width: 1, height: beat == 0 ? 6 : 4)
                    .frame(width: beatWidth, alignment: .leading)
            }
        }
        .frame(height: 6, alignment: .bottom)
        .opacity(0.8)
        .accessibilityHidden(true)
    }

    // MARK: Menus

    @ViewBuilder
    private var measureMenu: some View {
        Section("Bar \(bar + 1)") {
            Menu {
                ForEach(1...3, id: \.self) { times in
                    Button {
                        perform(String(localized: "Repeat bars"), toast: String(localized: "Bar \(bar + 1) repeated")) {
                            ComposeChordOps.repeatBars(in: section, range: bar..<(bar + 1), times: times)
                        }
                    } label: {
                        Text(times == 1 ? String(localized: "Once more") : String(localized: "\(times) more times"))
                    }
                    .disabled(!ComposeChordOps.canAdd(times, to: section))
                }
            } label: {
                Label("Repeat bar", systemImage: "repeat.1")
            }
            if bar > 0 {
                Button {
                    perform(String(localized: "Repeat bars"), toast: String(localized: "Bars 1–\(bar + 1) repeated")) {
                        ComposeChordOps.repeatBars(in: section, range: 0..<(bar + 1), times: 1)
                    }
                } label: {
                    Label("Repeat bars 1–\(bar + 1)", systemImage: "repeat")
                }
                .disabled(!ComposeChordOps.canAdd(bar + 1, to: section))
            }
            Button { perform(String(localized: "Insert bar")) { ComposeChordOps.insertBar(in: section, at: bar) } } label: {
                Label("Insert bar before", systemImage: "arrow.left.to.line")
            }
            Button { perform(String(localized: "Insert bar")) { ComposeChordOps.insertBar(in: section, at: bar + 1) } } label: {
                Label("Insert bar after", systemImage: "arrow.right.to.line")
            }
        }
        Section {
            if bar > 0 {
                Button { perform(String(localized: "Move bar")) { ComposeChordOps.moveBar(in: section, from: bar, to: bar - 1) } } label: {
                    Label("Move earlier", systemImage: "arrow.left")
                }
            }
            if bar < section.bars - 1 {
                Button { perform(String(localized: "Move bar")) { ComposeChordOps.moveBar(in: section, from: bar, to: bar + 1) } } label: {
                    Label("Move later", systemImage: "arrow.right")
                }
            }
        }
        if !chords.isEmpty {
            Button {
                perform(String(localized: "Clear bar"), toast: String(localized: "Bar cleared")) {
                    ComposeChordOps.clearBar(in: section, bar: bar, context: editor.modelContext)
                }
            } label: {
                Label("Clear bar", systemImage: "eraser")
            }
        }
        if section.bars > 1 {
            Button(role: .destructive) {
                perform(String(localized: "Delete bar"), toast: String(localized: "Bar \(bar + 1) deleted")) {
                    ComposeChordOps.deleteBar(in: section, bar: bar, context: editor.modelContext)
                }
            } label: {
                Label("Delete bar", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func chordMenu(_ chord: ChordEvent) -> some View {
        Section(chord.isRest ? String(localized: "Rest") : chord.display) {
            Button {
                onSlot(ChordSlot(barIndex: bar, beatOffset: chord.beatOffset, isHalf: chord.duration < 1, sectionId: section.id))
            } label: {
                Label("Edit…", systemImage: "pencil")
            }
            if !chord.isRest {
                Button { onAudition(ComposeChordValue(chord)) } label: {
                    Label("Play", systemImage: "speaker.wave.2")
                }
            }
            if ComposeChordOps.duplicateTargetBeat(for: chord, in: section, beatsPerBar: beatsPerBar) != nil {
                Button {
                    perform(String(localized: "Duplicate chord")) { ComposeChordOps.duplicate(chord, in: section, beatsPerBar: beatsPerBar) }
                } label: {
                    Label("Repeat on next beat", systemImage: "plus.square.on.square")
                }
            }
        }
        Button(role: .destructive) {
            perform(String(localized: "Delete chord"), toast: chord.isRest ? String(localized: "Rest removed") : String(localized: "\(chord.display) removed")) {
                ComposeChordOps.delete(chord, from: section, context: editor.modelContext)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func perform(_ label: String, toast: String? = nil, _ change: () -> Void) {
        haptic(.light)
        editor.perform(label, toast: toast, change)
    }
}

// MARK: - Chord token

/// A chord sitting on its beat: Erode symbol with a duration rule beneath.
struct ComposeChordToken: View {
    let chord: ChordEvent
    let color: Color
    let payload: String
    let onTap: () -> Void
    let onDrop: (String) -> Bool

    @State private var isTargeted = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                if chord.isRest {
                    Text("rest")
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                } else {
                    ComposeChordSymbol(value: ComposeChordValue(chord), size: .regular)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                Capsule()
                    .fill(chord.isRest ? DesignSystem.Colors.border : color)
                    .frame(height: 3)
                    .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.trailing, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isTargeted ? color.opacity(0.18) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.95))
        .draggable(payload) {
            ComposeChordSymbol(value: ComposeChordValue(chord), size: .regular)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(DesignSystem.Colors.surface))
                .overlay(Capsule().stroke(color, lineWidth: 1.5))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first else { return false }
            return onDrop(first)
        } isTargeted: { isTargeted = $0 }
        .accessibilityLabel(chord.isRest ? String(localized: "Rest") : ComposeChordSpeech.spoken(ComposeChordValue(chord)))
        .accessibilityValue("\(ComposeFormat.beatsUnit(chord.duration)) from beat \(ComposeFormat.beatPosition(chord.beatOffset))")
        .accessibilityHint("Double-tap to edit. Hold for more options.")
    }
}

// MARK: - Empty beat

struct ComposeEmptyBeat: View {
    let isDownbeat: Bool
    let label: String
    let onTap: () -> Void
    let onDrop: (String) -> Bool

    @State private var isTargeted = false

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isTargeted ? DesignSystem.Colors.primaryLight : DesignSystem.Colors.surfaceSecondary.opacity(0.7))
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isTargeted ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textMuted)
                        .opacity(isDownbeat || isTargeted ? 1 : 0.6)
                }
                .padding(.vertical, 6)
                .padding(.trailing, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.92))
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first else { return false }
            return onDrop(first)
        } isTargeted: { isTargeted = $0 }
        .accessibilityLabel(label)
        .accessibilityHint("Double-tap to add a chord")
    }
}

// MARK: - Chord symbol

/// Lead-sheet chord typesetting: root in Erode, quality set smaller and raised.
struct ComposeChordSymbol: View {
    enum Size { case small, regular, large, hero }

    let value: ComposeChordValue
    var size: Size = .regular

    var body: some View {
        let suffix = value.quality.symbol + value.extensions.joined()
        let slash = value.slashRoot.map { "/" + $0 } ?? ""
        Text("\(Text(value.root).font(rootFont))\(Text(suffix).font(suffixFont).baselineOffset(raise))\(Text(slash).font(suffixFont))")
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel(ComposeChordSpeech.spoken(value))
    }

    private var rootFont: Font {
        switch size {
        case .small: return DesignSystem.Typography.chordSmall
        case .regular: return DesignSystem.Typography.chord
        case .large: return DesignSystem.Typography.title
        case .hero: return DesignSystem.Typography.jumbo
        }
    }

    private var suffixFont: Font {
        switch size {
        case .small: return Font.erode(15, weight: .semibold, relativeTo: .callout)
        case .regular: return DesignSystem.Typography.chordSmall
        case .large: return DesignSystem.Typography.title3
        case .hero: return DesignSystem.Typography.lg
        }
    }

    private var raise: CGFloat {
        switch size {
        case .small: return 2
        case .regular: return 4
        case .large: return 6
        case .hero: return 14
        }
    }
}

/// VoiceOver-friendly chord names ("A minor seventh over E").
enum ComposeChordSpeech {
    static func spoken(_ value: ComposeChordValue) -> String {
        guard !value.isRest else { return String(localized: "Rest") }
        let root = note(value.root)
        let quality = value.quality.displayName.lowercased()
        var text = "\(root) \(quality)"
        if !value.extensions.isEmpty {
            let added = value.extensions.joined(separator: " ")
            text = String(localized: "\(text) add \(added)", comment: "Spoken chord with added tones")
        }
        if let slash = value.slashRoot {
            let bass = note(slash)
            text = String(localized: "\(text) over \(bass)", comment: "Spoken slash chord: chord over bass note")
        }
        return text
    }

    /// Spoken note name ("C sharp", "B flat").
    static func note(_ n: String) -> String {
        guard n.count > 1 else { return n }
        let letter = String(n.prefix(1))
        if n.hasSuffix("#") { return String(localized: "\(letter) sharp") }
        if n.hasSuffix("b") { return String(localized: "\(letter) flat") }
        return n
    }
}
