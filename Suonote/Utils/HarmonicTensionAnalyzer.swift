import Foundation
import SwiftUI

// MARK: - Harmonic Tension Analyzer (H1 + H2 + H3 + H4)
// Provides:
//  - H1: Tension graph data across the song
//  - H2: Voice leading analysis between consecutive chords
//  - H3: Chord substitution suggestions
//  - H4: Cadence detection and suggestions

// MARK: - Tension Data

struct ChordTensionPoint: Identifiable {
    let id = UUID()
    let sectionName: String
    let chordDisplay: String
    let beatPosition: Double   // Global beat index across whole song
    let tension: Double        // 0.0 (resolved) – 1.0 (maximum tension)
    let isDiatonic: Bool
}

struct TensionArc {
    let points: [ChordTensionPoint]
    var averageTension: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.tension).reduce(0, +) / Double(points.count)
    }
    var peakTension: Double { points.map(\.tension).max() ?? 0 }
    var tensionVariety: Double {
        guard points.count > 1 else { return 0 }
        let mean = averageTension
        let variance = points.map { pow($0.tension - mean, 2) }.reduce(0, +) / Double(points.count)
        return sqrt(variance)
    }
}

// MARK: - Voice Leading

struct VoiceMovement {
    let fromNote: String
    let toNote: String
    let interval: Int           // semitones moved (can be negative)
    let voiceName: String       // "Bass", "Tenor", "Alto", "Soprano"
}

struct VoiceLeadingResult {
    let from: (root: String, quality: ChordQuality)
    let to: (root: String, quality: ChordQuality)
    let movements: [VoiceMovement]
    let smoothnessScore: Double   // 0.0 = awkward, 1.0 = perfectly smooth
    let commonTones: [String]
    let summary: String
}

// MARK: - Chord Substitution

struct ChordSubstitution: Identifiable {
    let id = UUID()
    let root: String
    let quality: ChordQuality
    let name: String            // e.g., "Tritone Substitution", "Relative Minor"
    let explanation: String
    let type: SubstitutionType
    let strength: Double        // 0.0–1.0 how strong the substitution is

    var display: String { root + quality.symbol }
}

enum SubstitutionType: String, CaseIterable {
    case tritone = "Tritone"
    case relativeChange = "Relative"
    case modalInterchange = "Modal Interchange"
    case secondaryDominant = "Secondary Dominant"
    case neapolitan = "Neapolitan"
    case parallelMode = "Parallel Mode"
    case diminishedPassing = "Diminished Passing"
}

// MARK: - Cadence

enum CadenceType: String, CaseIterable {
    case authentic = "Authentic (V→I)"
    case perfectAuthentic = "Perfect Authentic (V7→I)"
    case plagal = "Plagal (IV→I)"
    case halfCadence = "Half (→V)"
    case deceptive = "Deceptive (V→vi)"
    case phrygian = "Phrygian (♭VII→i)"
    case none = "None detected"

    var description: String {
        switch self {
        case .authentic: return "Strong resolution. Use at the end of a section."
        case .perfectAuthentic: return "Strongest resolution. Classic song ending."
        case .plagal: return "Soft resolution (\"Amen\" cadence). Great for choruses."
        case .halfCadence: return "Unresolved ending — creates suspense, perfect for pre-chorus."
        case .deceptive: return "Surprise move to vi instead of I. Emotional twist."
        case .phrygian: return "Dark resolution. Works in minor/modal context."
        case .none: return "No standard cadence pattern detected."
        }
    }

    var icon: String {
        switch self {
        case .authentic, .perfectAuthentic: return "checkmark.circle.fill"
        case .plagal: return "leaf.fill"
        case .halfCadence: return "questionmark.circle"
        case .deceptive: return "exclamationmark.triangle"
        case .phrygian: return "moon.fill"
        case .none: return "minus.circle"
        }
    }
}

struct CadenceSuggestion: Identifiable {
    let id = UUID()
    let type: CadenceType
    let chords: [(root: String, quality: ChordQuality)]
    let description: String
}

// MARK: - Analyzer Engine

struct HarmonicTensionAnalyzer {

    // MARK: - H1: Tension Arc

    /// Compute tension points for all sections in a project
    static func tensionArc(for project: Project) -> TensionArc {
        var points: [ChordTensionPoint] = []
        var globalBeat: Double = 0

        let sortedItems = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        let beatsPerBar = Double(project.timeTop)

        for item in sortedItems {
            guard let section = item.sectionTemplate else { continue }
            let keyRoot = section.effectiveKeyRoot
            let mode = section.effectiveKeyMode
            let scaleIntervals = Set(mode.intervals)

            let sectionChords = section.chordEvents
                .filter { !$0.isRest }
                .sorted { $0.barIndex * 100 + Int($0.beatOffset * 10) <
                          $1.barIndex * 100 + Int($1.beatOffset * 10) }

            for chord in sectionChords {
                let chordBeat = Double(chord.barIndex) * beatsPerBar + chord.beatOffset
                let tension = chordTension(root: chord.root, quality: chord.quality,
                                           keyRoot: keyRoot, mode: mode, scaleIntervals: scaleIntervals)
                let isDiatonic = isChordDiatonic(root: chord.root, quality: chord.quality,
                                                  keyRoot: keyRoot, mode: mode)
                points.append(ChordTensionPoint(
                    sectionName: section.name,
                    chordDisplay: chord.display,
                    beatPosition: globalBeat + chordBeat,
                    tension: tension,
                    isDiatonic: isDiatonic
                ))
            }

            globalBeat += Double(section.bars) * beatsPerBar
        }

        return TensionArc(points: points)
    }

    /// Tension score for a single chord (0.0 resolved – 1.0 max tension)
    static func chordTension(root: String, quality: ChordQuality,
                              keyRoot: String, mode: KeyMode,
                              scaleIntervals: Set<Int>? = nil) -> Double {
        var score = 0.0
        let intervals = scaleIntervals ?? Set(mode.intervals)
        guard let rootIdx = MusicTheory.noteIndex(root),
              let keyIdx = MusicTheory.noteIndex(keyRoot) else { return 0.5 }

        let intervalFromKey = (rootIdx - keyIdx + 12) % 12

        // Base tension from root position relative to key
        let rootTensions: [Int: Double] = [
            0: 0.0,  // I - tonic
            7: 0.1,  // V - dominant
            5: 0.2,  // IV - subdominant
            9: 0.3,  // VI - relative
            2: 0.4,  // II - supertonic
            4: 0.5,  // III
            10: 0.6, // ♭VII
            3: 0.6,  // ♭III
            8: 0.7,  // ♭VI
            1: 0.8,  // ♭II (Neapolitan)
            6: 0.9,  // Tritone
            11: 0.7  // VII
        ]
        score = rootTensions[intervalFromKey] ?? 0.5

        // Tension from quality
        switch quality {
        case .major, .major7: score += 0.0
        case .minor, .minor7: score += 0.05
        case .dominant7: score += 0.15
        case .diminished, .halfDiminished7: score += 0.25
        case .diminished7: score += 0.3
        case .augmented: score += 0.2
        case .dominant7sharp9, .dominant7flat9, .altered: score += 0.3
        case .sus2, .sus4: score += 0.1
        default: score += 0.08
        }

        // Non-diatonic chord = more tension
        if !intervals.contains(intervalFromKey) {
            score += 0.2
        }

        return min(1.0, score)
    }

    /// Whether a chord's root is in the current scale
    static func isChordDiatonic(root: String, quality: ChordQuality, keyRoot: String, mode: KeyMode) -> Bool {
        guard let rootIdx = MusicTheory.noteIndex(root),
              let keyIdx = MusicTheory.noteIndex(keyRoot) else { return false }
        let interval = (rootIdx - keyIdx + 12) % 12
        return mode.intervals.contains(interval)
    }

    // MARK: - H2: Voice Leading

    /// Analyze voice leading between two consecutive chords
    static func voiceLeading(from fromChord: ChordEvent, to toChord: ChordEvent) -> VoiceLeadingResult {
        let fromNotes = ChordUtils.getChordNotes(root: fromChord.root, quality: fromChord.quality)
        let toNotes = ChordUtils.getChordNotes(root: toChord.root, quality: toChord.quality)

        let voiceNames = ["Bass", "Tenor", "Alto", "Soprano"]
        var movements: [VoiceMovement] = []

        let voiceCount = min(4, max(fromNotes.count, toNotes.count))
        for i in 0..<voiceCount {
            let fromNote = i < fromNotes.count ? fromNotes[i] : fromNotes.last ?? "C"
            let toNote = i < toNotes.count ? toNotes[i] : toNotes.last ?? "C"
            let interval = NoteUtils.intervalBetween(from: fromNote, to: toNote)
            let voiceName = i < voiceNames.count ? voiceNames[i] : "Voice \(i+1)"
            movements.append(VoiceMovement(
                fromNote: fromNote, toNote: toNote,
                interval: interval, voiceName: voiceName
            ))
        }

        let commonTones = ChordUtils.commonNotes(
            chord1Root: fromChord.root, chord1Quality: fromChord.quality,
            chord2Root: toChord.root, chord2Quality: toChord.quality
        )

        // Smoothness: prefer small movements and common tones
        let totalMovement = movements.map { abs($0.interval) }.reduce(0, +)
        let maxPossible = Double(voiceCount) * 12
        let smoothness = 1.0 - min(1.0, Double(totalMovement) / maxPossible) * 0.7 +
                         Double(commonTones.count) / Double(max(1, voiceCount)) * 0.3

        let summary = buildVoiceLeadingSummary(movements: movements, commonTones: commonTones, smoothness: smoothness)

        return VoiceLeadingResult(
            from: (fromChord.root, fromChord.quality),
            to: (toChord.root, toChord.quality),
            movements: movements,
            smoothnessScore: min(1.0, smoothness),
            commonTones: commonTones,
            summary: summary
        )
    }

    private static func buildVoiceLeadingSummary(movements: [VoiceMovement],
                                                   commonTones: [String],
                                                   smoothness: Double) -> String {
        var parts: [String] = []
        if !commonTones.isEmpty {
            parts.append("\(commonTones.joined(separator: ", ")) shared")
        }
        let maxMove = movements.map { abs($0.interval) }.max() ?? 0
        if maxMove > 7 { parts.append("large leap in \(movements.first(where: { abs($0.interval) == maxMove })?.voiceName ?? "")") }
        if smoothness > 0.8 { return "Very smooth \(parts.isEmpty ? "" : "· " + parts.joined(separator: " · "))" }
        if smoothness > 0.6 { return "Smooth \(parts.isEmpty ? "" : "· " + parts.joined(separator: " · "))" }
        if smoothness > 0.4 { return "Moderate \(parts.isEmpty ? "" : "· " + parts.joined(separator: " · "))" }
        return "Rough voice leading \(parts.isEmpty ? "" : "· " + parts.joined(separator: " · "))"
    }

    // MARK: - H3: Chord Substitutions

    /// Generate chord substitutions for a given chord in context
    static func substitutions(for chord: ChordEvent, keyRoot: String, mode: KeyMode) -> [ChordSubstitution] {
        var subs: [ChordSubstitution] = []
        guard let rootIdx = MusicTheory.noteIndex(chord.root) else { return [] }

        // 1. Tritone substitution (for dominant chords)
        if chord.quality == .dominant7 || chord.quality == .dominant9 {
            let tritoneRoot = MusicTheory.chromaticScale[(rootIdx + 6) % 12]
            subs.append(ChordSubstitution(
                root: tritoneRoot, quality: .dominant7,
                name: "Tritone Sub",
                explanation: "Replaces \(chord.root)7 with \(tritoneRoot)7 — shares the tritone interval.",
                type: .tritone, strength: 0.9
            ))
        }

        // 2. Relative major/minor swap
        let relativeInterval = mode.isMinor ? 3 : 9
        let relativeRoot = MusicTheory.chromaticScale[(rootIdx + relativeInterval) % 12]
        let relativeQuality: ChordQuality = mode.isMinor ? .major : .minor
        subs.append(ChordSubstitution(
            root: relativeRoot, quality: relativeQuality,
            name: "Relative \(mode.isMinor ? "Major" : "Minor")",
            explanation: "Shares the same notes as \(chord.root)\(chord.quality.symbol) but with a different root.",
            type: .relativeChange, strength: 0.75
        ))

        // 3. Modal interchange (parallel mode borrowing)
        let parallelMode: KeyMode = mode.isMinor ? .major : .minor
        let parallelIntervals = Set(parallelMode.intervals)
        if let keyIdx = MusicTheory.noteIndex(keyRoot) {
            let chordInterval = (rootIdx - keyIdx + 12) % 12
            if !parallelIntervals.contains(chordInterval) {
                subs.append(ChordSubstitution(
                    root: chord.root,
                    quality: mode.isMinor ? .major : .minor,
                    name: "Modal Interchange",
                    explanation: "Borrowed from the parallel \(parallelMode.rawValue) — creates emotional contrast.",
                    type: .modalInterchange, strength: 0.7
                ))
            }
        }

        // 4. Secondary dominant (V7 of this chord's root)
        let secDomRoot = MusicTheory.chromaticScale[(rootIdx + 7) % 12]
        subs.append(ChordSubstitution(
            root: secDomRoot, quality: .dominant7,
            name: "Secondary Dominant",
            explanation: "\(secDomRoot)7 pulls strongly into \(chord.root) — use the bar before.",
            type: .secondaryDominant, strength: 0.8
        ))

        // 5. Neapolitan chord (for V or ii chords)
        let neapolitanRoot = MusicTheory.chromaticScale[(rootIdx + 1) % 12]
        subs.append(ChordSubstitution(
            root: neapolitanRoot, quality: .major,
            name: "Neapolitan",
            explanation: "♭II major — dramatic, film-music feel. Great before a cadence.",
            type: .neapolitan, strength: 0.6
        ))

        // 6. Diminished passing chord
        let dimRoot = MusicTheory.chromaticScale[(rootIdx + 11) % 12]
        subs.append(ChordSubstitution(
            root: dimRoot, quality: .diminished7,
            name: "Diminished Passing",
            explanation: "Use as a chromatic stepping stone into \(chord.root).",
            type: .diminishedPassing, strength: 0.65
        ))

        return subs.sorted { $0.strength > $1.strength }
    }

    // MARK: - H4: Cadence Detection

    /// Detect the cadence formed by the last 2 chords of a section
    static func detectCadence(in section: SectionTemplate, keyRoot: String, mode: KeyMode) -> CadenceType {
        let chords = section.chordEvents
            .filter { !$0.isRest }
            .sorted { $0.barIndex * 100 + Int($0.beatOffset * 10) <
                      $1.barIndex * 100 + Int($1.beatOffset * 10) }

        guard chords.count >= 2 else { return .none }
        let penultimate = chords[chords.count - 2]
        let last = chords[chords.count - 1]

        guard let keyIdx = MusicTheory.noteIndex(keyRoot),
              let penIdx = MusicTheory.noteIndex(penultimate.root),
              let lastIdx = MusicTheory.noteIndex(last.root) else { return .none }

        let penInterval = (penIdx - keyIdx + 12) % 12
        let lastInterval = (lastIdx - keyIdx + 12) % 12

        // V or V7 → I (authentic)
        if penInterval == 7 && lastInterval == 0 {
            if penultimate.quality == .dominant7 || penultimate.quality == .major7 {
                return .perfectAuthentic
            }
            return .authentic
        }
        // IV → I (plagal)
        if penInterval == 5 && lastInterval == 0 { return .plagal }
        // → V (half cadence)
        if lastInterval == 7 { return .halfCadence }
        // V → vi (deceptive)
        if penInterval == 7 && lastInterval == 9 { return .deceptive }
        // ♭VII → i (Phrygian)
        if penInterval == 10 && lastInterval == 0 && mode.isMinor { return .phrygian }

        return .none
    }

    /// Generate cadence options for the end of a section
    static func cadenceSuggestions(for keyRoot: String, mode: KeyMode) -> [CadenceSuggestion] {
        guard let keyIdx = MusicTheory.noteIndex(keyRoot) else { return [] }
        let scale = mode.intervals.map { MusicTheory.chromaticScale[(keyIdx + $0) % 12] }
        guard scale.count >= 5 else { return [] }

        let tonicQuality: ChordQuality = mode.isMinor ? .minor : .major
        let dominantRoot = scale.count > 4 ? scale[4] : "G"
        let subdominantRoot = scale.count > 3 ? scale[3] : "F"
        let submediantRoot = scale.count > 5 ? scale[5] : "A"

        return [
            CadenceSuggestion(
                type: .perfectAuthentic,
                chords: [(dominantRoot, .dominant7), (keyRoot, tonicQuality)],
                description: "Strongest resolution. Finishes a section definitively."
            ),
            CadenceSuggestion(
                type: .plagal,
                chords: [(subdominantRoot, .major), (keyRoot, tonicQuality)],
                description: "Soft, warm resolution. Great for outro or chorus end."
            ),
            CadenceSuggestion(
                type: .halfCadence,
                chords: [(subdominantRoot, .major), (dominantRoot, .major)],
                description: "Leaves the listener wanting more. Perfect for verse end."
            ),
            CadenceSuggestion(
                type: .deceptive,
                chords: [(dominantRoot, .dominant7), (submediantRoot, mode.isMinor ? .major : .minor)],
                description: "Surprise ending. Creates emotional depth and unexpectedness."
            )
        ]
    }
}

// MARK: - Harmonic Tension Graph View (H1)

struct HarmonicTensionGraphView: View {
    let project: Project

    private var arc: TensionArc {
        HarmonicTensionAnalyzer.tensionArc(for: project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Stats row
            HStack(spacing: DesignSystem.Spacing.lg) {
                statBadge(
                    label: "Avg Tension",
                    value: String(format: "%.0f%%", arc.averageTension * 100),
                    color: tensionColor(arc.averageTension)
                )
                statBadge(
                    label: "Peak",
                    value: String(format: "%.0f%%", arc.peakTension * 100),
                    color: tensionColor(arc.peakTension)
                )
                statBadge(
                    label: "Variety",
                    value: String(format: "%.0f%%", arc.tensionVariety * 100),
                    color: DesignSystem.Colors.primary
                )
                Spacer()
            }

            if arc.points.isEmpty {
                Text("Add chords to see the tension arc")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                // Line chart
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let points = arc.points

                    Canvas { ctx, size in
                        guard points.count > 1 else { return }

                        let maxBeat = points.map(\.beatPosition).max() ?? 1
                        func xPos(_ p: ChordTensionPoint) -> CGFloat {
                            CGFloat(p.beatPosition / maxBeat) * w
                        }
                        func yPos(_ p: ChordTensionPoint) -> CGFloat {
                            h - CGFloat(p.tension) * h
                        }

                        // Fill area under curve
                        var fillPath = Path()
                        fillPath.move(to: CGPoint(x: xPos(points[0]), y: h))
                        for point in points {
                            fillPath.addLine(to: CGPoint(x: xPos(point), y: yPos(point)))
                        }
                        fillPath.addLine(to: CGPoint(x: xPos(points.last!), y: h))
                        fillPath.closeSubpath()
                        ctx.fill(fillPath, with: .linearGradient(
                            Gradient(colors: [DesignSystem.Colors.primary.opacity(0.3), .clear]),
                            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)
                        ))

                        // Draw line
                        var linePath = Path()
                        linePath.move(to: CGPoint(x: xPos(points[0]), y: yPos(points[0])))
                        for point in points.dropFirst() {
                            linePath.addLine(to: CGPoint(x: xPos(point), y: yPos(point)))
                        }
                        ctx.stroke(linePath, with: .color(DesignSystem.Colors.primary), lineWidth: 2.5)

                        // Dots for non-diatonic chords
                        for point in points where !point.isDiatonic {
                            let dotRect = CGRect(
                                x: xPos(point) - 4, y: yPos(point) - 4,
                                width: 8, height: 8
                            )
                            ctx.fill(Path(ellipseIn: dotRect), with: .color(DesignSystem.Colors.accent))
                        }
                    }
                }
                .frame(height: 90)
                .padding(.top, 4)

                // Legend
                HStack(spacing: DesignSystem.Spacing.md) {
                    HStack(spacing: 4) {
                        Circle().fill(DesignSystem.Colors.primary).frame(width: 8, height: 8)
                        Text("Diatonic").font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(DesignSystem.Colors.accent).frame(width: 8, height: 8)
                        Text("Non-diatonic").font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
    }

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundStyle(color)
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    private func tensionColor(_ t: Double) -> Color {
        if t < 0.3 { return DesignSystem.Colors.success }
        if t < 0.6 { return DesignSystem.Colors.warning }
        return DesignSystem.Colors.error
    }
}

// MARK: - Voice Leading View (H2)

struct VoiceLeadingView: View {
    let section: SectionTemplate

    private var pairs: [VoiceLeadingResult] {
        let chords = section.chordEvents
            .filter { !$0.isRest }
            .sorted { $0.barIndex * 100 + Int($0.beatOffset * 10) <
                      $1.barIndex * 100 + Int($1.beatOffset * 10) }
        guard chords.count >= 2 else { return [] }
        return zip(chords, chords.dropFirst()).map {
            HarmonicTensionAnalyzer.voiceLeading(from: $0, to: $1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if pairs.isEmpty {
                Text("Need at least 2 chords to analyze voice leading.")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        ForEach(Array(pairs.enumerated()), id: \.offset) { _, result in
                            voiceLeadingCard(result)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
    }

    private func voiceLeadingCard(_ result: VoiceLeadingResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Chord pair
            HStack(spacing: 4) {
                Text(result.from.root + result.from.quality.symbol)
                    .font(DesignSystem.Typography.calloutBold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text(result.to.root + result.to.quality.symbol)
                    .font(DesignSystem.Typography.calloutBold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }

            // Smoothness bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(DesignSystem.Colors.border)
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(smoothnessColor(result.smoothnessScore))
                    .frame(width: 90 * CGFloat(result.smoothnessScore), height: 5)
            }
            .frame(width: 90)

            Text(result.summary)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 110, alignment: .leading)
                .lineLimit(2)

            // Common tones
            if !result.commonTones.isEmpty {
                Text("Common: \(result.commonTones.prefix(3).joined(separator: ", "))")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
        .frame(width: 130)
    }

    private func smoothnessColor(_ s: Double) -> Color {
        if s > 0.7 { return DesignSystem.Colors.success }
        if s > 0.4 { return DesignSystem.Colors.warning }
        return DesignSystem.Colors.error
    }
}

// MARK: - Chord Substitutions View (H3)

struct ChordSubstitutionsView: View {
    let chord: ChordEvent
    let keyRoot: String
    let mode: KeyMode
    var onSelect: (ChordSubstitution) -> Void

    private var substitutions: [ChordSubstitution] {
        HarmonicTensionAnalyzer.substitutions(for: chord, keyRoot: keyRoot, mode: mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Substitutions for \(chord.display)")
                .font(DesignSystem.Typography.bodyBold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            ForEach(substitutions) { sub in
                Button { onSelect(sub) } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Chord name
                        Text(sub.display)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.primary)
                            .frame(width: 60, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.name)
                                .font(DesignSystem.Typography.calloutBold)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Text(sub.explanation)
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        // Strength indicator
                        Circle()
                            .fill(strengthColor(sub.strength))
                            .frame(width: 8, height: 8)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(DesignSystem.Colors.surfaceSecondary)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.md)
    }

    private func strengthColor(_ s: Double) -> Color {
        if s > 0.8 { return DesignSystem.Colors.success }
        if s > 0.6 { return DesignSystem.Colors.warning }
        return DesignSystem.Colors.textTertiary
    }
}

// MARK: - Cadence View (H4)

struct CadenceAnalysisView: View {
    let section: SectionTemplate

    private var keyRoot: String { section.effectiveKeyRoot }
    private var mode: KeyMode { section.effectiveKeyMode }

    private var detected: CadenceType {
        HarmonicTensionAnalyzer.detectCadence(in: section, keyRoot: keyRoot, mode: mode)
    }

    private var suggestions: [CadenceSuggestion] {
        HarmonicTensionAnalyzer.cadenceSuggestions(for: keyRoot, mode: mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Detected cadence
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: detected.icon)
                    .foregroundStyle(detectedColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(detected.rawValue)
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(detected.description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(detectedColor.opacity(0.1))
            )

            // Suggestions
            Text("Cadence Options")
                .font(DesignSystem.Typography.calloutBold)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.top, 4)

            ForEach(suggestions) { sug in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(sug.type.rawValue)
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                        // Chord labels
                        HStack(spacing: 4) {
                            ForEach(Array(sug.chords.enumerated()), id: \.offset) { i, chord in
                                if i > 0 {
                                    Text("→").font(DesignSystem.Typography.caption2)
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                }
                                Text(chord.root + chord.quality.symbol)
                                    .font(DesignSystem.Typography.caption)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(DesignSystem.Colors.primary.opacity(0.15))
                                    )
                                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                            }
                        }
                    }
                    Text(sug.description)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
    }

    private var detectedColor: Color {
        switch detected {
        case .perfectAuthentic, .authentic: return DesignSystem.Colors.success
        case .plagal: return DesignSystem.Colors.primary
        case .halfCadence: return DesignSystem.Colors.warning
        case .deceptive: return DesignSystem.Colors.accent
        case .phrygian: return DesignSystem.Colors.info
        case .none: return DesignSystem.Colors.textTertiary
        }
    }
}
