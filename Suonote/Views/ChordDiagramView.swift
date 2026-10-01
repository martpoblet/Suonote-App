import SwiftUI

// MARK: - Chord Diagram
/// Piano (two octaves, root-position voicing) or guitar (a playable shape found
/// on the neck) for a chord, plus its note names.
struct ChordDiagramView: View {
    let root: String
    let quality: ChordQuality
    let extensions: [String]
    let accentColor: Color
    var bassNote: String? = nil

    @AppStorage("compose.diagramInstrument") private var instrumentRaw: String = ChordInstrument.piano.rawValue

    enum ChordInstrument: String, CaseIterable {
        case piano = "Piano"
        case guitar = "Guitar"

        var icon: String { self == .piano ? "pianokeys" : "guitars" }

        /// Display name (rawValue is persisted in AppStorage).
        var title: String {
            switch self {
            case .piano: return String(localized: "Piano")
            case .guitar: return String(localized: "Guitar")
            }
        }
    }

    private var instrument: ChordInstrument {
        ChordInstrument(rawValue: instrumentRaw) ?? .piano
    }

    var body: some View {
        let intervals = ChordNoteCalculator.intervals(quality: quality, extensions: extensions)
        let rootIndex = MusicTheory.noteIndex(root) ?? 0
        let bassIndex = bassNote.flatMap { MusicTheory.noteIndex($0) }
        let noteNames = ChordNoteCalculator.names(rootIndex: rootIndex, intervals: intervals, bassIndex: bassIndex)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(ChordInstrument.allCases, id: \.self) { option in
                    SelectableChip(title: option.title, icon: option.icon, isSelected: instrument == option) {
                        haptic(.selection)
                        withAnimation(DesignSystem.Animations.quickSpring) { instrumentRaw = option.rawValue }
                    }
                }
                Spacer(minLength: 0)
            }

            Group {
                switch instrument {
                case .piano:
                    PianoChordDiagram(rootIndex: rootIndex, intervals: intervals, bassIndex: bassIndex, accentColor: accentColor)
                        .frame(height: 104)
                case .guitar:
                    GuitarChordDiagram(
                        voicing: GuitarVoicing.find(
                            pitchClasses: Set(intervals.map { (rootIndex + $0) % 12 }),
                            rootIndex: rootIndex,
                            bassIndex: bassIndex ?? rootIndex
                        ),
                        accentColor: accentColor
                    )
                    .frame(height: 170)
                }
            }
            .frame(maxWidth: .infinity)

            ComposeFlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Array(noteNames.enumerated()), id: \.offset) { index, note in
                    Text(note)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(index == 0 ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(index == 0 ? accentColor.opacity(0.22) : DesignSystem.Colors.surfaceSecondary))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Notes: \(noteNames.joined(separator: ", "))")
        }
    }
}

// MARK: - Piano

private struct PianoChordDiagram: View {
    let rootIndex: Int
    let intervals: [Int]
    let bassIndex: Int?
    let accentColor: Color

    private static let whiteSemitones = [0, 2, 4, 5, 7, 9, 11]
    private static let blackSemitones = [1, 3, 6, 8, 10]

    /// Absolute key positions (0..<24 from C) of the voicing.
    private var positions: (chord: Set<Int>, bass: Int?) {
        var chord = Set<Int>()
        let start = bassIndex == nil ? rootIndex : rootIndex + (rootIndex <= (bassIndex ?? 0) ? 12 : 0)
        for interval in intervals {
            var position = start + interval
            while position >= 24 { position -= 12 }
            chord.insert(position)
        }
        return (chord, bassIndex)
    }

    var body: some View {
        let active = positions
        GeometryReader { proxy in
            let whiteWidth = proxy.size.width / 14
            let height = proxy.size.height
            let blackWidth = whiteWidth * 0.6

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0..<14, id: \.self) { index in
                        let position = (index / 7) * 12 + Self.whiteSemitones[index % 7]
                        let isChord = active.chord.contains(position)
                        let isBass = active.bass == position
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isBass ? DesignSystem.Colors.accent.opacity(0.35) : (isChord ? accentColor.opacity(0.35) : DesignSystem.Colors.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(DesignSystem.Colors.borderActive, lineWidth: 1)
                            )
                            .overlay(alignment: .bottom) {
                                if isChord || isBass {
                                    Circle()
                                        .fill(isBass ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)
                                        .frame(width: 8, height: 8)
                                        .padding(.bottom, 8)
                                }
                            }
                            .frame(width: whiteWidth)
                    }
                }

                ForEach(0..<2, id: \.self) { octave in
                    ForEach(Self.blackSemitones, id: \.self) { semitone in
                        let position = octave * 12 + semitone
                        let whiteBefore = octave * 7 + (Self.whiteSemitones.lastIndex(where: { $0 < semitone }) ?? 0)
                        let isChord = active.chord.contains(position)
                        let isBass = active.bass == position
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(isBass ? DesignSystem.Colors.accent : (isChord ? accentColor : DesignSystem.Colors.textPrimary))
                            .frame(width: blackWidth, height: height * 0.6)
                            .overlay(alignment: .bottom) {
                                if isChord || isBass {
                                    Circle()
                                        .fill(DesignSystem.Colors.surface)
                                        .frame(width: 6, height: 6)
                                        .padding(.bottom, 6)
                                }
                            }
                            .offset(x: CGFloat(whiteBefore + 1) * whiteWidth - blackWidth / 2)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Guitar

struct GuitarVoicing {
    /// Fret per string, low E → high E. nil = muted.
    let frets: [Int?]
    let baseFret: Int

    private static let tuning = [4, 9, 2, 7, 11, 4]

    static func find(pitchClasses: Set<Int>, rootIndex: Int, bassIndex: Int) -> GuitarVoicing {
        let essential: Set<Int> = {
            guard pitchClasses.count > 4 else { return pitchClasses }
            // Big chords: the fifth is optional.
            return pitchClasses.subtracting([(rootIndex + 7) % 12])
        }()
        var best: (score: Int, voicing: GuitarVoicing)?

        for start in 0...9 {
            let window = start == 0 ? Array(0...3) : Array(start...(start + 3))
            var frets: [Int?] = tuning.map { open in
                window.first { pitchClasses.contains((open + $0) % 12) }
            }
            guard let bassString = frets.indices.first(where: { index in
                guard let fret = frets[index] else { return false }
                return (tuning[index] + fret) % 12 == bassIndex
            }) else { continue }
            for index in 0..<bassString { frets[index] = nil }

            let played = frets.indices.compactMap { index in frets[index].map { (tuning[index] + $0) % 12 } }
            let missing = essential.subtracting(played).count
            let muted = frets.filter { $0 == nil }.count
            let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
            let span = (fretted.max() ?? 0) - (fretted.min() ?? 0)
            let score = missing * 12 + muted * 3 + start * 2 + (span > 3 ? 50 : 0) + (bassString > 1 ? 6 : 0)

            let base = (fretted.max() ?? 0) <= 4 ? 1 : (fretted.min() ?? 1)
            let voicing = GuitarVoicing(frets: frets, baseFret: base)
            if best == nil || score < best!.score { best = (score, voicing) }
        }
        return best?.voicing ?? GuitarVoicing(frets: Array(repeating: nil, count: 6), baseFret: 1)
    }
}

private struct GuitarChordDiagram: View {
    let voicing: GuitarVoicing
    let accentColor: Color

    private let fretCount = 4

    var body: some View {
        GeometryReader { proxy in
            let markerHeight: CGFloat = 18
            let width = min(proxy.size.width, 200)
            let gridHeight = proxy.size.height - markerHeight - 6
            let stringSpacing = (width - 36) / 5
            let fretSpacing = gridHeight / CGFloat(fretCount)
            let originX = (proxy.size.width - width) / 2 + 18

            ZStack(alignment: .topLeading) {
                // Open / muted markers
                ForEach(0..<6, id: \.self) { string in
                    let fret = voicing.frets[string]
                    Text(fret == nil ? "×" : (fret == 0 ? "○" : ""))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(fret == nil ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                        .frame(width: 16)
                        .position(x: originX + CGFloat(string) * stringSpacing, y: markerHeight / 2)
                }

                // Frets
                ForEach(0...fretCount, id: \.self) { fret in
                    Rectangle()
                        .fill(fret == 0 && voicing.baseFret == 1 ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.borderActive)
                        .frame(width: stringSpacing * 5, height: fret == 0 && voicing.baseFret == 1 ? 4 : 1)
                        .position(x: originX + stringSpacing * 2.5, y: markerHeight + 6 + CGFloat(fret) * fretSpacing)
                }

                // Strings
                ForEach(0..<6, id: \.self) { string in
                    Rectangle()
                        .fill(DesignSystem.Colors.textSecondary.opacity(0.6))
                        .frame(width: 1, height: gridHeight)
                        .position(x: originX + CGFloat(string) * stringSpacing, y: markerHeight + 6 + gridHeight / 2)
                }

                if voicing.baseFret > 1 {
                    Text("\(voicing.baseFret)fr")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .position(x: originX - 16, y: markerHeight + 6 + fretSpacing / 2)
                }

                // Dots
                ForEach(0..<6, id: \.self) { string in
                    if let fret = voicing.frets[string], fret > 0 {
                        let row = fret - voicing.baseFret
                        Circle()
                            .fill(string == voicing.frets.firstIndex(where: { $0 != nil }) ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)
                            .frame(width: min(18, stringSpacing * 0.7), height: min(18, stringSpacing * 0.7))
                            .position(
                                x: originX + CGFloat(string) * stringSpacing,
                                y: markerHeight + 6 + (CGFloat(row) + 0.5) * fretSpacing
                            )
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let names = [String(localized: "low E"), "A", "D", "G", "B", String(localized: "high E")]
        let parts = voicing.frets.enumerated().map { index, fret -> String in
            let name = names[index]
            guard let fret else { return String(localized: "\(name) muted") }
            return fret == 0 ? String(localized: "\(name) open") : String(localized: "\(name) fret \(fret)")
        }
        let shape = parts.joined(separator: ", ")
        return String(localized: "Guitar shape: \(shape)")
    }
}

// MARK: - Notes

enum ChordNoteCalculator {
    static func intervals(quality: ChordQuality, extensions: [String]) -> [Int] {
        var intervals = Set(quality.intervals)
        if extensions.contains("sus2") {
            intervals.subtract([3, 4]); intervals.insert(2)
        }
        if extensions.contains("sus4") {
            intervals.subtract([3, 4]); intervals.insert(5)
        }
        for ext in extensions {
            switch ext {
            case "7": intervals.insert(10)
            case "9", "add9": intervals.insert(14)
            case "11": intervals.insert(17)
            case "13": intervals.insert(21)
            default: break
            }
        }
        return intervals.sorted()
    }

    static func names(rootIndex: Int, intervals: [Int], bassIndex: Int?) -> [String] {
        var seen = Set<Int>()
        var names: [String] = []
        if let bassIndex {
            seen.insert(bassIndex)
            names.append(MusicTheory.chromaticScale[bassIndex])
        }
        for interval in intervals {
            let pc = (rootIndex + interval) % 12
            if seen.insert(pc).inserted { names.append(MusicTheory.chromaticScale[pc]) }
        }
        return names
    }
}

#Preview {
    ChordDiagramView(root: "C", quality: .major7, extensions: [], accentColor: DesignSystem.Colors.sectionSky, bassNote: "E")
        .padding()
        .paperBackground()
}
