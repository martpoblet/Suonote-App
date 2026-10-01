import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Slots & values

/// A beat position inside a section — the target of the chord palette.
struct ChordSlot: Identifiable, Equatable {
    let id = UUID()
    let barIndex: Int
    /// Beat offset inside the bar (0-based, half-beat resolution).
    let beatOffset: Double
    let isHalf: Bool
    let sectionId: UUID

    init(barIndex: Int, beatOffset: Double, isHalf: Bool = false, sectionId: UUID) {
        self.barIndex = barIndex
        self.beatOffset = beatOffset
        self.isHalf = isHalf
        self.sectionId = sectionId
    }
}

/// One cell inside a measure: either a chord or an empty stretch of beats.
struct ComposeBeatSlot: Identifiable {
    let id: String
    let beatOffset: Double
    let duration: Double
    let chord: ChordEvent?
}

/// Value copy of a chord's harmonic content (what the palette edits).
struct ComposeChordValue: Hashable {
    var root: String
    var quality: ChordQuality
    var extensions: [String] = []
    var slashRoot: String? = nil
    var isRest: Bool = false

    init(root: String, quality: ChordQuality, extensions: [String] = [], slashRoot: String? = nil, isRest: Bool = false) {
        self.root = root
        self.quality = quality
        self.extensions = extensions
        self.slashRoot = slashRoot
        self.isRest = isRest
    }

    init(_ chord: ChordEvent) {
        self.init(
            root: chord.root,
            quality: chord.quality,
            extensions: chord.extensions,
            slashRoot: chord.slashRoot,
            isRest: chord.isRest
        )
    }

    init(_ suggestion: ChordSuggestion) {
        self.init(root: suggestion.root, quality: suggestion.quality, extensions: suggestion.extensions)
    }

    var display: String {
        guard !isRest else { return String(localized: "Rest") }
        var text = root + quality.symbol + extensions.joined()
        if let slashRoot, !slashRoot.isEmpty { text += "/" + slashRoot }
        return text
    }
}

// MARK: - Drag payloads

/// String payloads used for drag & drop inside Compose.
enum ComposeDragPayload {
    case chord(sectionId: UUID, chordId: UUID)
    case bar(sectionId: UUID, barIndex: Int)

    var string: String {
        switch self {
        case .chord(let sectionId, let chordId):
            return "suonote.chord|\(sectionId.uuidString)|\(chordId.uuidString)"
        case .bar(let sectionId, let barIndex):
            return "suonote.bar|\(sectionId.uuidString)|\(barIndex)"
        }
    }

    init?(string: String) {
        let parts = string.split(separator: "|").map(String.init)
        guard parts.count == 3, let sectionId = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "suonote.chord":
            guard let chordId = UUID(uuidString: parts[2]) else { return nil }
            self = .chord(sectionId: sectionId, chordId: chordId)
        case "suonote.bar":
            guard let bar = Int(parts[2]) else { return nil }
            self = .bar(sectionId: sectionId, barIndex: bar)
        default:
            return nil
        }
    }
}

/// Reorders arrangement sections live while a segment is dragged over another.
struct ArrangementDropDelegate: DropDelegate {
    let targetItem: ArrangementItem
    let onItemHovered: (ArrangementItem) -> Void
    let onDrop: (ArrangementItem, [NSItemProvider]) -> Bool
    let onExit: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        onItemHovered(targetItem)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onExit()
    }

    func performDrop(info: DropInfo) -> Bool {
        onDrop(targetItem, info.itemProviders(for: [UTType.text]))
    }
}

// MARK: - Formatting

enum ComposeFormat {
    /// "½", "1", "1½", "2" …
    static func beats(_ value: Double) -> String {
        let whole = Int(value.rounded(.down))
        let hasHalf = value - Double(whole) >= 0.25
        if whole == 0 { return hasHalf ? "½" : "0" }
        return hasHalf ? "\(whole)½" : "\(whole)"
    }

    /// 1-based beat label for a 0-based offset ("1", "2½").
    static func beatPosition(_ offset: Double) -> String {
        beats(offset + 1)
    }

    static func beatsUnit(_ value: Double) -> String {
        value > 1 ? String(localized: "\(beats(value)) beats") : String(localized: "\(beats(value)) beat")
    }

    static func keyName(root: String, mode: KeyMode) -> String {
        let note = MusicTheory.displayName(for: root, inKey: root, mode: mode)
        switch mode {
        case .major: return String(localized: "\(note) major")
        case .minor: return String(localized: "\(note) minor")
        case .dorian: return String(localized: "\(note) dorian")
        case .phrygian: return String(localized: "\(note) phrygian")
        case .lydian: return String(localized: "\(note) lydian")
        case .mixolydian: return String(localized: "\(note) mixolydian")
        case .aeolian: return String(localized: "\(note) aeolian")
        case .locrian: return String(localized: "\(note) locrian")
        case .harmonicMinor: return String(localized: "\(note) harmonic minor")
        case .melodicMinor: return String(localized: "\(note) melodic minor")
        case .pentatonicMajor: return String(localized: "\(note) pentatonic major")
        case .pentatonicMinor: return String(localized: "\(note) pentatonic minor")
        case .blues: return String(localized: "\(note) blues")
        }
    }

    /// Localized mode name for display ("Major", "Dorian"…). `KeyMode.rawValue`
    /// is persisted, so it is never shown directly.
    static func modeName(_ mode: KeyMode) -> String {
        switch mode {
        case .major: return String(localized: "Major")
        case .minor: return String(localized: "Minor")
        case .dorian: return String(localized: "Dorian")
        case .phrygian: return String(localized: "Phrygian")
        case .lydian: return String(localized: "Lydian")
        case .mixolydian: return String(localized: "Mixolydian")
        case .aeolian: return String(localized: "Aeolian")
        case .locrian: return String(localized: "Locrian")
        case .harmonicMinor: return String(localized: "Harmonic Minor")
        case .melodicMinor: return String(localized: "Melodic Minor")
        case .pentatonicMajor: return String(localized: "Pentatonic Major")
        case .pentatonicMinor: return String(localized: "Pentatonic Minor")
        case .blues: return String(localized: "Blues")
        }
    }

    /// Compact key symbol for figures: "C", "Am", "D dor".
    static func keyShort(root: String, mode: KeyMode) -> String {
        let note = MusicTheory.displayName(for: root, inKey: root, mode: mode)
        switch mode {
        case .major: return note
        case .minor, .aeolian: return note + "m"
        case .dorian: return note + " dor"
        case .phrygian: return note + " phr"
        case .lydian: return note + " lyd"
        case .mixolydian: return note + " mix"
        case .locrian: return note + " loc"
        case .harmonicMinor: return note + "m harm"
        case .melodicMinor: return note + "m mel"
        case .pentatonicMajor: return note + " pent"
        case .pentatonicMinor: return note + "m pent"
        case .blues: return note + " blues"
        }
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static let chromatic = MusicTheory.chromaticScale
}

// MARK: - Chord & bar operations

/// Pure model mutations used by Compose. Callers wrap them in
/// `ComposeEditor.perform` so every change is saved and undoable.
@MainActor
enum ComposeChordOps {
    static let epsilon = 0.0001

    // MARK: Reading

    /// Chords grouped by bar, each bar sorted by beat.
    static func chordsByBar(_ section: SectionTemplate) -> [Int: [ChordEvent]] {
        var map = Dictionary(grouping: section.chordEvents, by: { $0.barIndex })
        for (key, value) in map {
            map[key] = value.sorted { $0.beatOffset < $1.beatOffset }
        }
        return map
    }

    /// Lays a bar out as chords + empty beat cells.
    static func slots(barIndex: Int, chords: [ChordEvent], beatsPerBar: Int) -> [ComposeBeatSlot] {
        let total = Double(max(1, beatsPerBar))
        var result: [ComposeBeatSlot] = []
        var position = 0.0

        func appendEmpty(to end: Double) {
            var p = position
            while end - p > epsilon {
                let next = min(end, (p + epsilon).rounded(.down) + 1)
                result.append(ComposeBeatSlot(
                    id: "empty-\(barIndex)-\(p)",
                    beatOffset: p,
                    duration: next - p,
                    chord: nil
                ))
                p = next
            }
            position = max(position, end)
        }

        for chord in chords where chord.beatOffset < total - epsilon {
            appendEmpty(to: min(chord.beatOffset, total))
            let begin = max(position, chord.beatOffset)
            let end = min(total, chord.beatOffset + max(chord.duration, 0.25))
            if end - begin > epsilon {
                result.append(ComposeBeatSlot(
                    id: chord.id.uuidString,
                    beatOffset: begin,
                    duration: end - begin,
                    chord: chord
                ))
            }
            position = max(position, end)
        }
        appendEmpty(to: total)
        return result
    }

    static func chord(at slot: ChordSlot, in section: SectionTemplate) -> ChordEvent? {
        section.chordEvents.first {
            $0.barIndex == slot.barIndex && abs($0.beatOffset - slot.beatOffset) < epsilon
        }
    }

    /// Space (in beats) from `beat` to the next chord or the bar line.
    static func maxDuration(
        in section: SectionTemplate,
        bar: Int,
        from beat: Double,
        beatsPerBar: Int,
        excluding excludedId: UUID? = nil
    ) -> Double {
        let barEnd = Double(beatsPerBar)
        let nextStart = section.chordEvents
            .filter { $0.barIndex == bar && $0.id != excludedId && $0.beatOffset > beat + epsilon }
            .map(\.beatOffset)
            .min() ?? barEnd
        return max(0, min(barEnd, nextStart) - beat)
    }

    /// Whether `beat` falls inside (not at the start of) another chord.
    static func isCovered(
        in section: SectionTemplate,
        bar: Int,
        beat: Double,
        excluding excludedId: UUID? = nil
    ) -> Bool {
        section.chordEvents.contains {
            $0.barIndex == bar && $0.id != excludedId &&
            $0.beatOffset < beat - epsilon && $0.beatOffset + $0.duration > beat + epsilon
        }
    }

    /// First empty beat at or after (bar, beat) in this section.
    static func nextEmptySlot(
        in section: SectionTemplate,
        afterBar: Int,
        beat: Double,
        beatsPerBar: Int
    ) -> (bar: Int, beat: Double)? {
        let byBar = chordsByBar(section)
        guard afterBar < section.bars else { return nil }
        for bar in afterBar..<section.bars {
            let slots = slots(barIndex: bar, chords: byBar[bar] ?? [], beatsPerBar: beatsPerBar)
            if let empty = slots.first(where: { $0.chord == nil && (bar > afterBar || $0.beatOffset >= beat - epsilon) }) {
                return (bar, empty.beatOffset)
            }
        }
        return nil
    }

    static func usedBeats(_ section: SectionTemplate, beatsPerBar: Int) -> Double {
        section.chordEvents.reduce(0) { total, chord in
            guard chord.barIndex < section.bars else { return total }
            return total + min(chord.duration, max(0, Double(beatsPerBar) - chord.beatOffset))
        }
    }

    // MARK: Chords

    static func apply(_ value: ComposeChordValue, to chord: ChordEvent) {
        chord.isRest = value.isRest
        chord.root = value.root
        chord.quality = value.quality
        chord.extensions = value.isRest ? [] : value.extensions
        chord.slashRoot = value.isRest ? nil : value.slashRoot
        chord.updateDisplay()
    }

    @discardableResult
    static func place(
        _ value: ComposeChordValue,
        in section: SectionTemplate,
        bar: Int,
        beat: Double,
        duration: Double
    ) -> ChordEvent {
        if let existing = section.chordEvents.first(where: { $0.barIndex == bar && abs($0.beatOffset - beat) < epsilon }) {
            apply(value, to: existing)
            existing.duration = duration
            return existing
        }
        let chord = ChordEvent(
            barIndex: bar,
            beatOffset: beat,
            duration: duration,
            isRest: value.isRest,
            root: value.root,
            quality: value.quality,
            extensions: value.isRest ? [] : value.extensions,
            slashRoot: value.isRest ? nil : value.slashRoot
        )
        section.chordEvents.append(chord)
        return chord
    }

    static func delete(_ chord: ChordEvent, from section: SectionTemplate, context: ModelContext?) {
        section.chordEvents.removeAll { $0.id == chord.id }
        context?.delete(chord)
    }

    static func duplicateTargetBeat(for chord: ChordEvent, in section: SectionTemplate, beatsPerBar: Int) -> Double? {
        var beat = ((chord.beatOffset + chord.duration) * 2).rounded(.up) / 2
        while beat + chord.duration <= Double(beatsPerBar) + epsilon {
            if !isCovered(in: section, bar: chord.barIndex, beat: beat),
               !section.chordEvents.contains(where: { $0.barIndex == chord.barIndex && abs($0.beatOffset - beat) < epsilon }),
               maxDuration(in: section, bar: chord.barIndex, from: beat, beatsPerBar: beatsPerBar) >= chord.duration - epsilon {
                return beat
            }
            beat += 0.5
        }
        return nil
    }

    static func duplicate(_ chord: ChordEvent, in section: SectionTemplate, beatsPerBar: Int) {
        guard let beat = duplicateTargetBeat(for: chord, in: section, beatsPerBar: beatsPerBar) else { return }
        place(ComposeChordValue(chord), in: section, bar: chord.barIndex, beat: beat, duration: chord.duration)
    }

    /// Moves a chord onto an empty beat; its length is trimmed to fit.
    @discardableResult
    static func move(
        _ chord: ChordEvent,
        from source: SectionTemplate,
        to target: SectionTemplate,
        bar: Int,
        beat: Double,
        beatsPerBar: Int
    ) -> Bool {
        guard !isCovered(in: target, bar: bar, beat: beat, excluding: chord.id) else { return false }
        if target.chordEvents.contains(where: { $0.id != chord.id && $0.barIndex == bar && abs($0.beatOffset - beat) < epsilon }) {
            return false
        }
        let available = maxDuration(in: target, bar: bar, from: beat, beatsPerBar: beatsPerBar, excluding: chord.id)
        guard available >= 0.5 - epsilon else { return false }

        if source.id != target.id {
            source.chordEvents.removeAll { $0.id == chord.id }
            target.chordEvents.append(chord)
        }
        chord.barIndex = bar
        chord.beatOffset = beat
        chord.duration = min(chord.duration, available)
        return true
    }

    /// Swaps the harmony of two chords, keeping their rhythm in place.
    static func swap(_ a: ChordEvent, _ b: ChordEvent) {
        guard a.id != b.id else { return }
        let valueA = ComposeChordValue(a)
        apply(ComposeChordValue(b), to: a)
        apply(valueA, to: b)
    }

    // MARK: Bars

    static func insertBar(in section: SectionTemplate, at index: Int) {
        let clamped = min(max(0, index), section.bars)
        for chord in section.chordEvents where chord.barIndex >= clamped {
            chord.barIndex += 1
        }
        section.bars += 1
    }

    static func duplicateBar(in section: SectionTemplate, bar: Int) {
        let source = section.chordEvents.filter { $0.barIndex == bar }
        insertBar(in: section, at: bar + 1)
        for chord in source {
            place(ComposeChordValue(chord), in: section, bar: bar + 1, beat: chord.beatOffset, duration: chord.duration)
        }
    }

    static func clearBar(in section: SectionTemplate, bar: Int, context: ModelContext?) {
        for chord in section.chordEvents where chord.barIndex == bar {
            delete(chord, from: section, context: context)
        }
    }

    static func deleteBar(in section: SectionTemplate, bar: Int, context: ModelContext?) {
        guard section.bars > 1 else { return }
        clearBar(in: section, bar: bar, context: context)
        for chord in section.chordEvents where chord.barIndex > bar {
            chord.barIndex -= 1
        }
        section.bars -= 1
    }

    static func moveBar(in section: SectionTemplate, from source: Int, to target: Int) {
        let target = min(max(0, target), section.bars - 1)
        guard source != target, source >= 0, source < section.bars else { return }
        for chord in section.chordEvents {
            if chord.barIndex == source {
                chord.barIndex = target
            } else if source < target, chord.barIndex > source, chord.barIndex <= target {
                chord.barIndex -= 1
            } else if source > target, chord.barIndex >= target, chord.barIndex < source {
                chord.barIndex += 1
            }
        }
    }

    static func setBars(_ count: Int, in section: SectionTemplate, context: ModelContext?) {
        let count = max(1, count)
        if count < section.bars {
            for chord in section.chordEvents where chord.barIndex >= count {
                delete(chord, from: section, context: context)
            }
        }
        section.bars = count
    }

    /// Writes a progression one chord per bar starting at `startBar`.
    static func applyProgression(
        _ chords: [ComposeChordValue],
        to section: SectionTemplate,
        startBar: Int,
        beatsPerBar: Int,
        context: ModelContext?
    ) {
        for (offset, value) in chords.enumerated() {
            let bar = startBar + offset
            if bar >= section.bars { section.bars = bar + 1 }
            clearBar(in: section, bar: bar, context: context)
            place(value, in: section, bar: bar, beat: 0, duration: Double(beatsPerBar))
        }
    }

    // MARK: Sections

    static func orderedItems(_ project: Project) -> [ArrangementItem] {
        project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// "Verse" → "Verse 2" when a Verse already exists; "Verse 1" → "Verse 2".
    static func uniqueName(_ base: String, in project: Project) -> String {
        let existing = Set(orderedItems(project).compactMap { $0.sectionTemplate?.name.lowercased() })
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        guard existing.contains(trimmed.lowercased()) else { return trimmed }
        var stem = trimmed
        var number = 2
        if let last = trimmed.split(separator: " ").last, let value = Int(last) {
            stem = trimmed.split(separator: " ").dropLast().joined(separator: " ")
            number = value + 1
        }
        while existing.contains("\(stem) \(number)".lowercased()) { number += 1 }
        return "\(stem) \(number)"
    }

    @discardableResult
    static func createSection(
        in project: Project,
        name: String,
        bars: Int,
        colorHex: String,
        after item: ArrangementItem? = nil
    ) -> SectionTemplate {
        let section = SectionTemplate(name: name, bars: bars, colorHex: colorHex)
        section.project = project
        project.sectionTemplates.append(section)
        insertItem(for: section, in: project, after: item)
        return section
    }

    @discardableResult
    static func duplicate(_ item: ArrangementItem, in project: Project) -> SectionTemplate? {
        guard let section = item.sectionTemplate else { return nil }
        let copy = SectionTemplate(
            name: uniqueName(section.name, in: project),
            bars: section.bars,
            patternPreset: section.patternPreset,
            lyricsText: section.lyricsText,
            notesText: section.notesText,
            colorHex: section.colorHex ?? SectionColor.sage.hex
        )
        copy.sectionKeyRoot = section.sectionKeyRoot
        copy.sectionKeyModeRaw = section.sectionKeyModeRaw
        copy.sectionBpm = section.sectionBpm
        copy.project = project
        project.sectionTemplates.append(copy)
        for chord in section.chordEvents {
            place(ComposeChordValue(chord), in: copy, bar: chord.barIndex, beat: chord.beatOffset, duration: chord.duration)
        }
        insertItem(for: copy, in: project, after: item)
        return copy
    }

    private static func insertItem(for section: SectionTemplate, in project: Project, after anchor: ArrangementItem?) {
        var ordered = orderedItems(project)
        let newItem = ArrangementItem(orderIndex: ordered.count)
        newItem.sectionTemplate = section
        newItem.project = project
        if let anchor, let index = ordered.firstIndex(where: { $0.id == anchor.id }) {
            ordered.insert(newItem, at: index + 1)
        } else {
            ordered.append(newItem)
        }
        for (index, item) in ordered.enumerated() { item.orderIndex = index }
        project.arrangementItems = ordered
    }

    static func remove(_ item: ArrangementItem, from project: Project, context: ModelContext?) {
        var ordered = orderedItems(project)
        ordered.removeAll { $0.id == item.id }
        for (index, remaining) in ordered.enumerated() { remaining.orderIndex = index }
        project.arrangementItems = ordered
        context?.delete(item)
    }

    static func moveItem(sourceId: UUID, targetId: UUID, in project: Project) {
        guard sourceId != targetId else { return }
        var ordered = orderedItems(project)
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = ordered.firstIndex(where: { $0.id == targetId }) else { return }
        let moved = ordered.remove(at: sourceIndex)
        ordered.insert(moved, at: min(targetIndex, ordered.count))
        for (index, item) in ordered.enumerated() { item.orderIndex = index }
        project.arrangementItems = ordered
    }

    static func moveItem(_ item: ArrangementItem, by delta: Int, in project: Project) {
        var ordered = orderedItems(project)
        guard let index = ordered.firstIndex(where: { $0.id == item.id }) else { return }
        let target = min(max(0, index + delta), ordered.count - 1)
        guard target != index else { return }
        let moved = ordered.remove(at: index)
        ordered.insert(moved, at: target)
        for (i, item) in ordered.enumerated() { item.orderIndex = i }
        project.arrangementItems = ordered
    }
}

// MARK: - Flow layout

/// Wrapping row layout for chips (Compose-local to avoid cross-file coupling).
struct ComposeFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
