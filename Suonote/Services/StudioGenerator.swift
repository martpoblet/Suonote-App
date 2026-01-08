import Foundation
import SwiftData

struct StudioGenerator {
    struct ChordSpan {
        let chord: ChordEvent
        let startBeat: Double
        let duration: Double
    }

    static func generateTracks(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext
    ) -> [StudioTrack] {
        let timeline = buildTimeline(for: project)
        let diatonicMap = diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)
        let instruments: [StudioInstrument] = [.piano, .synth, .guitar, .bass, .drums]
        var tracks: [StudioTrack] = []
        let defaultDrumPreset = DrumPreset.defaultPreset(
            for: style,
            beatsPerBar: project.timeTop,
            timeBottom: project.timeBottom
        )

        for (index, instrument) in instruments.enumerated() {
            let track = StudioTrack(
                name: instrument.title,
                instrument: instrument,
                orderIndex: index
            )
            track.project = project
            modelContext.insert(track)
            if instrument == .drums {
                track.drumPreset = defaultDrumPreset
            }

            let notes = notesForInstrument(
                instrument,
                chords: timeline.chords,
                totalBars: timeline.totalBars,
                beatsPerBar: project.timeTop,
                timeBottom: project.timeBottom,
                style: style,
                drumPreset: instrument == .drums ? track.drumPreset : nil,
                octaveShift: track.octaveShift,
                keyRoot: project.keyRoot,
                diatonicMap: diatonicMap
            )
            for note in notes {
                note.track = track
                track.notes.append(note)
                modelContext.insert(note)
            }

            tracks.append(track)
        }

        return tracks
    }

    static func regenerateNotes(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext,
        resetDrumPreset: Bool = false
    ) {
        let timeline = buildTimeline(for: project)
        let diatonicMap = diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)
        let defaultDrumPreset = DrumPreset.defaultPreset(
            for: style,
            beatsPerBar: project.timeTop,
            timeBottom: project.timeBottom
        )

        for track in project.studioTracks where !track.instrument.isAudio {
            for note in track.notes {
                modelContext.delete(note)
            }
            track.notes.removeAll()

            let activeDrumPreset: DrumPreset?
            if track.instrument == .drums {
                let preset = resetDrumPreset ? defaultDrumPreset : (track.drumPreset ?? defaultDrumPreset)
                track.drumPreset = preset
                activeDrumPreset = preset
            } else {
                activeDrumPreset = nil
            }

            let notes = notesForInstrument(
                track.instrument,
                chords: timeline.chords,
                totalBars: timeline.totalBars,
                beatsPerBar: project.timeTop,
                timeBottom: project.timeBottom,
                style: style,
                drumPreset: activeDrumPreset,
                octaveShift: track.octaveShift,
                keyRoot: project.keyRoot,
                diatonicMap: diatonicMap
            )
            for note in notes {
                note.track = track
                track.notes.append(note)
                modelContext.insert(note)
            }
        }
    }

    static func generateNotes(
        for instrument: StudioInstrument,
        project: Project,
        style: StudioStyle,
        drumPreset: DrumPreset? = nil,
        octaveShift: Int = 0
    ) -> [StudioNote] {
        let timeline = buildTimeline(for: project)
        let diatonicMap = diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)
        let resolvedPreset: DrumPreset?
        if instrument == .drums {
            resolvedPreset = drumPreset ?? DrumPreset.defaultPreset(
                for: style,
                beatsPerBar: project.timeTop,
                timeBottom: project.timeBottom
            )
        } else {
            resolvedPreset = nil
        }
        return notesForInstrument(
            instrument,
            chords: timeline.chords,
            totalBars: timeline.totalBars,
            beatsPerBar: project.timeTop,
            timeBottom: project.timeBottom,
            style: style,
            drumPreset: resolvedPreset,
            octaveShift: octaveShift,
            keyRoot: project.keyRoot,
            diatonicMap: diatonicMap
        )
    }

    static func generateDrumNotes(
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        preset: DrumPreset?
    ) -> [StudioNote] {
        let resolvedPreset = preset ?? DrumPreset.defaultPreset(
            for: style,
            beatsPerBar: beatsPerBar,
            timeBottom: timeBottom
        )
        return drumNotes(
            totalBars: totalBars,
            beatsPerBar: beatsPerBar,
            timeBottom: timeBottom,
            style,
            preset: resolvedPreset
        )
    }

    private static func buildTimeline(for project: Project) -> (chords: [ChordSpan], totalBars: Int) {
        let orderedItems = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        var sectionStartBar = 0
        var chordSpans: [ChordSpan] = []

        for item in orderedItems {
            guard let section = item.sectionTemplate else { continue }
            let sectionBars = max(1, section.bars)
            for chord in section.chordEvents {
                let globalBar = sectionStartBar + chord.barIndex
                let startBeat = Double(globalBar * project.timeTop) + chord.beatOffset
                chordSpans.append(
                    ChordSpan(
                        chord: chord,
                        startBeat: startBeat,
                        duration: chord.duration
                    )
                )
            }
            sectionStartBar += sectionBars
        }

        let totalBars = max(1, sectionStartBar)
        let timelineBeats = Double(totalBars * project.timeTop)
        let sorted = chordSpans.sorted { $0.startBeat < $1.startBeat }
        let adjusted = sorted.enumerated().map { index, span -> ChordSpan in
            let nextStart = (index + 1) < sorted.count ? sorted[index + 1].startBeat : timelineBeats
            let maxDuration = max(0.25, nextStart - span.startBeat)
            let base = max(0.25, span.duration)
            let duration = min(base, maxDuration)
            return ChordSpan(
                chord: span.chord,
                startBeat: span.startBeat,
                duration: duration
            )
        }
        return (chords: adjusted, totalBars: totalBars)
    }

    private static func notesForInstrument(
        _ instrument: StudioInstrument,
        chords: [ChordSpan],
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        drumPreset: DrumPreset?,
        octaveShift: Int,
        keyRoot: String,
        diatonicMap: [String: ChordQuality]
    ) -> [StudioNote] {
        switch instrument {
        case .drums:
            return drumNotes(
                totalBars: totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style,
                preset: drumPreset ?? DrumPreset.defaultPreset(
                    for: style,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom
                )
            )
        case .bass:
            return bassNotes(
                chords: chords,
                instrument: instrument,
                totalBars: totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style: style,
                octaveShift: octaveShift,
                keyRoot: keyRoot
            )
        case .guitar, .synth, .piano:
            return chordPadNotes(
                chords: chords,
                instrument: instrument,
                totalBars: totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style: style,
                octaveShift: octaveShift,
                keyRoot: keyRoot,
                diatonicMap: diatonicMap
            )
        case .audio:
            return []
        }
    }

    private static func chordPadNotes(
        chords: [ChordSpan],
        instrument: StudioInstrument,
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        octaveShift: Int,
        keyRoot: String,
        diatonicMap: [String: ChordQuality]
    ) -> [StudioNote] {
        let range = chordRange(for: instrument, style: style, octaveShift: octaveShift)
        let tonicTarget = anchorPitch(for: keyRoot, in: range)
        var lastCenter = tonicTarget
        var notes: [StudioNote] = []

        for span in chords {
            let rootClass = noteSemitone(for: span.chord.root)
            let rootPitch = nearestPitch(for: rootClass, in: range, near: lastCenter)
            let baseDuration = max(0.25, span.duration)
            let resolvedQuality = resolveQuality(
                for: span.chord,
                diatonicMap: diatonicMap
            )
            var pitches = chordPitches(rootPitch: rootPitch, quality: resolvedQuality)
            pitches = fitPitches(pitches, in: range)
            let center = pitches.reduce(0, +) / max(1, pitches.count)
            lastCenter = center
            let velocity = chordVelocity(for: instrument, style: style)
            let hitOffsets = chordHitOffsets(
                instrument: instrument,
                style: style,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                chordDuration: baseDuration
            )

            for offset in hitOffsets {
                guard offset < baseDuration else { continue }
                let hitDuration = chordHitDuration(
                    instrument: instrument,
                    style: style,
                    timeBottom: timeBottom,
                    baseDuration: baseDuration,
                    offset: offset
                )
                let duration = min(hitDuration, max(0.25, baseDuration - offset))
                let startBeat = span.startBeat + offset
                for pitch in pitches {
                    notes.append(
                        StudioNote(
                            startBeat: startBeat,
                            duration: duration,
                            pitch: pitch,
                            velocity: velocity
                        )
                    )
                }
            }
        }

        return notes
    }

    private static func bassNotes(
        chords: [ChordSpan],
        instrument: StudioInstrument,
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        octaveShift: Int,
        keyRoot: String
    ) -> [StudioNote] {
        let range = bassRange(style: style, octaveShift: octaveShift)
        var lastPitch = anchorPitch(for: keyRoot, in: range)
        var notes: [StudioNote] = []

        for span in chords {
            let rootName = span.chord.slashRoot ?? span.chord.root
            let rootClass = noteSemitone(for: rootName)
            let rootPitch = nearestPitch(for: rootClass, in: range, near: lastPitch)
            lastPitch = rootPitch
            let baseDuration = max(0.25, span.duration)
            let fifth = fitPitch(rootPitch + 7, in: range)
            let octave = fitPitch(rootPitch + 12, in: range)
            let midBeat = Double(max(1, beatsPerBar / 2))
            var hits: [(offset: Double, pitch: Int)] = [(0, rootPitch)]

            switch style {
            case .pop:
                if baseDuration >= midBeat + 0.25 {
                    hits.append((midBeat, octave))
                }
            case .rock:
                if baseDuration >= midBeat + 0.25 {
                    hits.append((midBeat, fifth))
                }
            case .lofi:
                hits = [(0, rootPitch)]
            case .edm:
                let strideBeat = timeBottom == 8 ? midBeat : 1.0
                let offsets = stride(from: 0.0, to: baseDuration, by: strideBeat).map { $0 }
                hits = offsets.map { ($0, rootPitch) }
            }

            let durationHint = bassHitDuration(style: style)
            let velocity = bassVelocity(for: style)
            var seenOffsets = Set<Double>()
            let orderedHits = hits
                .filter { seenOffsets.insert($0.offset).inserted }
                .sorted { $0.offset < $1.offset }

            for hit in orderedHits {
                guard hit.offset < baseDuration else { continue }
                let duration = min(durationHint, max(0.25, baseDuration - hit.offset))
                notes.append(
                    StudioNote(
                        startBeat: span.startBeat + hit.offset,
                        duration: duration,
                        pitch: hit.pitch,
                        velocity: velocity
                    )
                )
            }
        }

        return notes
    }

    private static func drumNotes(
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        _: StudioStyle,
        preset: DrumPreset
    ) -> [StudioNote] {
        let stepsPerBeat = timeBottom == 8 ? 2 : 4
        let stepLength = 1.0 / Double(stepsPerBeat)
        let stepsPerBar = beatsPerBar * stepsPerBeat
        let meter = meterPattern(beatsPerBar: beatsPerBar, timeBottom: timeBottom)
        let pattern = drumPattern(
            for: preset,
            meter: meter,
            stepsPerBeat: stepsPerBeat,
            stepsPerBar: stepsPerBar
        )
        let accentSteps = hatAccentSteps(
            pulseOffsets: meter.pulseOffsets,
            stepsPerBeat: stepsPerBeat
        )
        var notes: [StudioNote] = []

        for bar in 0..<totalBars {
            let barStart = Double(bar * beatsPerBar)
            for step in pattern.kick {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: 36,
                        velocity: step == 0 ? 118 : 110
                    )
                )
            }
            for step in pattern.snare {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: 38,
                        velocity: 102
                    )
                )
            }
            for step in pattern.hat {
                let velocity = accentSteps.contains(step) ? 82 : 68
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: 42,
                        velocity: velocity
                    )
                )
            }
            for step in pattern.clap {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: 39,
                        velocity: 90
                    )
                )
            }
        }

        return notes
    }

    private static func chordPitches(rootPitch: Int, quality: ChordQuality) -> [Int] {
        let intervals = simpleIntervals(for: quality)
        return intervals.map { rootPitch + $0 }
    }

    private static func diatonicQualityMap(forKey root: String, mode: KeyMode) -> [String: ChordQuality] {
        let chords = ChordSuggestionEngine.diatonicChords(forKey: root, mode: mode)
        return Dictionary(uniqueKeysWithValues: chords.map { ($0.root, $0.quality) })
    }

    private static func resolveQuality(
        for chord: ChordEvent,
        diatonicMap: [String: ChordQuality]
    ) -> ChordQuality {
        guard chord.extensions.isEmpty else { return chord.quality }
        guard chord.quality == .major else { return chord.quality }

        if let diatonic = diatonicMap[chord.root], diatonic != .major {
            return diatonic
        }
        return chord.quality
    }
    private static func noteSemitone(for note: String) -> Int {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let first = trimmed.prefix(1).uppercased()
        let rest = trimmed.dropFirst()
        let normalized = first + rest

        let map: [String: Int] = [
            "C": 0, "B#": 0,
            "C#": 1, "Db": 1,
            "D": 2,
            "D#": 3, "Eb": 3,
            "E": 4, "Fb": 4,
            "F": 5, "E#": 5,
            "F#": 6, "Gb": 6,
            "G": 7,
            "G#": 8, "Ab": 8,
            "A": 9,
            "A#": 10, "Bb": 10,
            "B": 11, "Cb": 11
        ]

        let keys = map.keys.sorted { $0.count > $1.count }
        for key in keys {
            if normalized.hasPrefix(key) {
                return map[key] ?? 0
            }
        }
        return 0
    }

    static func instrumentRange(
        for instrument: StudioInstrument,
        style: StudioStyle? = nil,
        octaveShift: Int = 0
    ) -> ClosedRange<Int> {
        let base = baseInstrumentRange(for: instrument)
        let styleShift = styleRegisterShift(for: instrument, style: style)
        let semitoneShift = styleShift + (octaveShift * 12)
        return shiftRange(base, by: semitoneShift)
    }

    private static func baseInstrumentRange(for instrument: StudioInstrument) -> ClosedRange<Int> {
        switch instrument {
        case .piano:
            return 36...72
        case .synth:
            return 40...76
        case .guitar:
            return 40...70
        case .bass:
            return 28...52
        case .drums, .audio:
            return 36...72
        }
    }

    private static func styleRegisterShift(
        for instrument: StudioInstrument,
        style: StudioStyle?
    ) -> Int {
        guard let style else { return 0 }
        switch style {
        case .pop:
            return 0
        case .rock:
            return instrument == .guitar ? -12 : 0
        case .lofi:
            if instrument == .piano || instrument == .synth {
                return -12
            }
            return instrument == .guitar ? -12 : 0
        case .edm:
            return instrument == .synth ? 12 : 0
        }
    }

    private static func shiftRange(_ range: ClosedRange<Int>, by semitones: Int) -> ClosedRange<Int> {
        var lower = range.lowerBound + semitones
        var upper = range.upperBound + semitones

        if lower < 0 {
            let shift = -lower
            lower += shift
            upper += shift
        }

        if upper > 127 {
            let shift = upper - 127
            lower -= shift
            upper -= shift
        }

        lower = max(0, lower)
        upper = min(127, upper)

        if lower >= upper {
            let clampedLower = max(0, min(127, range.lowerBound))
            let clampedUpper = max(clampedLower, min(127, range.upperBound))
            return clampedLower...clampedUpper
        }

        return lower...upper
    }

    private static func chordRange(
        for instrument: StudioInstrument,
        style: StudioStyle,
        octaveShift: Int
    ) -> ClosedRange<Int> {
        instrumentRange(for: instrument, style: style, octaveShift: octaveShift)
    }

    private static func bassRange(style: StudioStyle, octaveShift: Int) -> ClosedRange<Int> {
        instrumentRange(for: .bass, style: style, octaveShift: octaveShift)
    }

    private static func anchorPitch(for keyRoot: String, in range: ClosedRange<Int>) -> Int {
        let pitchClass = noteSemitone(for: keyRoot)
        let center = (range.lowerBound + range.upperBound) / 2
        return nearestPitch(for: pitchClass, in: range, near: center)
    }

    private static func nearestPitch(for pitchClass: Int, in range: ClosedRange<Int>, near target: Int) -> Int {
        var best = range.lowerBound
        var bestDistance = Int.max
        var pitch = pitchClass
        while pitch < range.lowerBound { pitch += 12 }

        while pitch <= range.upperBound {
            let distance = abs(pitch - target)
            if distance < bestDistance {
                bestDistance = distance
                best = pitch
            }
            pitch += 12
        }
        return best
    }

    private static func fitPitches(_ pitches: [Int], in range: ClosedRange<Int>) -> [Int] {
        guard var minPitch = pitches.min(), var maxPitch = pitches.max() else { return pitches }
        var adjusted = pitches
        while maxPitch > range.upperBound {
            adjusted = adjusted.map { $0 - 12 }
            minPitch -= 12
            maxPitch -= 12
        }
        while minPitch < range.lowerBound {
            adjusted = adjusted.map { $0 + 12 }
            minPitch += 12
            maxPitch += 12
        }
        return adjusted
    }

    private static func chordIntervals(for chord: ChordEvent) -> [Int] {
        simpleIntervals(for: chord.quality)
    }

    private static func chordVelocity(for instrument: StudioInstrument, style: StudioStyle) -> Int {
        let base: Int
        switch instrument {
        case .synth:
            base = 70
        case .guitar:
            base = 78
        case .piano:
            base = 88
        default:
            base = 86
        }

        let styleBoost: Int
        switch style {
        case .pop:
            styleBoost = 0
        case .rock:
            styleBoost = 8
        case .lofi:
            styleBoost = -12
        case .edm:
            styleBoost = 4
        }

        return min(127, max(40, base + styleBoost))
    }

    private static func chordHitOffsets(
        instrument: StudioInstrument,
        style: StudioStyle,
        beatsPerBar: Int,
        timeBottom: Int,
        chordDuration: Double
    ) -> [Double] {
        let midBeat = Double(max(1, beatsPerBar / 2))
        let beatStride = timeBottom == 8 ? midBeat : 1.0
        let offbeat = timeBottom == 8 ? midBeat : 0.5
        let quantStep = timeBottom == 8 ? 1.0 : 0.5

        var offsets: [Double] = []
        switch style {
        case .lofi:
            offsets = [0]
        case .pop:
            if instrument == .synth {
                offsets = [0]
            } else {
                offsets = [0]
                if chordDuration >= midBeat + 0.25 {
                    offsets.append(midBeat)
                }
            }
        case .rock:
            if instrument == .guitar {
                offsets = stride(from: 0, to: chordDuration, by: beatStride).map { $0 }
            } else {
                offsets = [0]
            }
        case .edm:
            if instrument == .synth {
                offsets = stride(from: offbeat, to: chordDuration, by: beatStride).map { $0 }
                if offsets.isEmpty {
                    offsets = [0]
                }
            } else {
                offsets = [0]
            }
        }

        let clamped = offsets
            .filter { $0 >= 0 && $0 < chordDuration }
            .map { quantize($0, step: quantStep) }
        return Array(Set(clamped)).sorted()
    }

    private static func chordHitDuration(
        instrument: StudioInstrument,
        style: StudioStyle,
        timeBottom: Int,
        baseDuration: Double,
        offset: Double
    ) -> Double {
        let remaining = max(0.25, baseDuration - offset)
        let shortHit = timeBottom == 8 ? 1.0 : 0.5

        switch style {
        case .lofi:
            return remaining
        case .pop:
            if instrument == .synth {
                return remaining
            }
            return min(remaining, 1.5)
        case .rock:
            if instrument == .guitar {
                return min(remaining, 0.75)
            }
            return min(remaining, 1.25)
        case .edm:
            if instrument == .synth {
                return min(remaining, shortHit)
            }
            return min(remaining, 1.0)
        }
    }

    private static func bassHitDuration(style: StudioStyle) -> Double {
        switch style {
        case .lofi:
            return 4.0
        case .pop:
            return 2.0
        case .rock:
            return 1.0
        case .edm:
            return 0.5
        }
    }

    private static func bassVelocity(for style: StudioStyle) -> Int {
        switch style {
        case .pop:
            return 86
        case .rock:
            return 96
        case .lofi:
            return 72
        case .edm:
            return 90
        }
    }

    private static func fitPitch(_ pitch: Int, in range: ClosedRange<Int>) -> Int {
        fitPitches([pitch], in: range).first ?? pitch
    }

    private static func quantize(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private static func simpleIntervals(for quality: ChordQuality) -> [Int] {
        switch quality {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .dominant7: return [0, 4, 7]
        case .major7: return [0, 4, 7]
        case .minor7: return [0, 3, 7]
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        }
    }

    private static func extensionInterval(for ext: String) -> Int? {
        switch ext {
        case "7": return 10
        case "9": return 14
        case "11": return 17
        case "13": return 21
        case "sus2": return 2
        case "sus4": return 5
        case "add9": return 14
        default: return nil
        }
    }

    private struct DrumPattern {
        let kick: [Int]
        let snare: [Int]
        let hat: [Int]
        let clap: [Int]
    }

    private struct MeterPattern {
        let beatOffsets: [Double]
        let offbeatOffsets: [Double]
        let pulseOffsets: [Double]
        let backbeatOffsets: [Double]
        let beatsPerBar: Int
        let timeBottom: Int
    }

    private static func meterPattern(
        beatsPerBar: Int,
        timeBottom: Int
    ) -> MeterPattern {
        let beatOffsets = (0..<beatsPerBar).map { Double($0) }
        let offbeatOffsets: [Double]

        let pulseOffsets: [Double]
        let backbeatOffsets: [Double]

        if timeBottom == 4 {
            offbeatOffsets = beatOffsets.map { $0 + 0.5 }.filter { $0 < Double(beatsPerBar) }
            pulseOffsets = beatOffsets
            switch beatsPerBar {
            case 4:
                backbeatOffsets = [1, 3]
            case 3:
                backbeatOffsets = [1]
            case 5:
                backbeatOffsets = [2, 4]
            default:
                backbeatOffsets = [Double(max(1, beatsPerBar / 2))]
            }
        } else {
            switch beatsPerBar {
            case 6:
                pulseOffsets = [0, 3]
                backbeatOffsets = [3]
                offbeatOffsets = [1.5, 4.5]
            case 12:
                pulseOffsets = [0, 3, 6, 9]
                backbeatOffsets = [3, 9]
                offbeatOffsets = [1.5, 4.5, 7.5, 10.5]
            case 7:
                pulseOffsets = [0, 2, 4]
                backbeatOffsets = [4]
                offbeatOffsets = [1, 3, 5.5]
            default:
                pulseOffsets = beatOffsets
                backbeatOffsets = [Double(max(1, beatsPerBar / 2))]
                offbeatOffsets = beatOffsets.map { $0 + 0.5 }.filter { $0 < Double(beatsPerBar) }
            }
        }

        return MeterPattern(
            beatOffsets: beatOffsets,
            offbeatOffsets: offbeatOffsets,
            pulseOffsets: pulseOffsets,
            backbeatOffsets: backbeatOffsets,
            beatsPerBar: beatsPerBar,
            timeBottom: timeBottom
        )
    }

    private static func drumPattern(
        for preset: DrumPreset,
        meter: MeterPattern,
        stepsPerBeat: Int,
        stepsPerBar: Int
    ) -> DrumPattern {
        let beatOffsets = meter.beatOffsets
        let offbeatOffsets = meter.offbeatOffsets
        let pulseOffsets = meter.pulseOffsets
        let backbeatOffsets = meter.backbeatOffsets

        let kickOffsets: [Double]
        let snareOffsets: [Double]
        let hatSteps: [Int]
        let clapOffsets: [Double]

        switch preset {
        case .basic:
            kickOffsets = basicKickOffsets(meter: meter)
            snareOffsets = backbeatOffsets.isEmpty ? [Double(max(1, meter.beatsPerBar - 1))] : backbeatOffsets
            hatSteps = stepsFromOffsets(
                meter.timeBottom == 4 ? beatOffsets + offbeatOffsets : beatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = meter.timeBottom == 4 ? snareOffsets : []
        case .drive:
            let extraKick = backbeatOffsets.compactMap { $0 - 0.5 >= 0 ? $0 - 0.5 : nil }
            kickOffsets = (pulseOffsets + extraKick).sorted()
            snareOffsets = backbeatOffsets
            hatSteps = Array(0..<stepsPerBar)
            clapOffsets = snareOffsets
        case .halfTime:
            let snareHit = halfTimeSnareOffset(meter: meter)
            kickOffsets = [pulseOffsets.first ?? 0]
            snareOffsets = [snareHit]
            hatSteps = stepsFromOffsets(
                meter.timeBottom == 4 ? beatOffsets : pulseOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = snareOffsets
        case .sparse:
            kickOffsets = [pulseOffsets.first ?? 0]
            snareOffsets = backbeatOffsets.isEmpty ? [Double(max(1, meter.beatsPerBar - 1))] : [backbeatOffsets.first!]
            hatSteps = stepsFromOffsets(
                meter.timeBottom == 4 ? beatOffsets : pulseOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = []
        case .fourOnFloor:
            kickOffsets = meter.timeBottom == 4 ? beatOffsets : pulseOffsets
            snareOffsets = backbeatOffsets
            hatSteps = stepsFromOffsets(
                offbeatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = snareOffsets
        case .offbeat:
            kickOffsets = pulseOffsets
            snareOffsets = backbeatOffsets
            hatSteps = stepsFromOffsets(
                offbeatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = []
        }

        let kickSteps = stepsFromOffsets(kickOffsets, stepsPerBeat: stepsPerBeat, stepsPerBar: stepsPerBar)
        let snareSteps = stepsFromOffsets(snareOffsets, stepsPerBeat: stepsPerBeat, stepsPerBar: stepsPerBar)
        let clapSteps = stepsFromOffsets(clapOffsets, stepsPerBeat: stepsPerBeat, stepsPerBar: stepsPerBar)

        return DrumPattern(
            kick: Array(Set(kickSteps)).sorted(),
            snare: Array(Set(snareSteps)).sorted(),
            hat: Array(Set(hatSteps)).sorted(),
            clap: Array(Set(clapSteps)).sorted()
        )
    }

    private static func stepsFromOffsets(
        _ offsets: [Double],
        stepsPerBeat: Int,
        stepsPerBar: Int
    ) -> [Int] {
        offsets
            .map { Int(round($0 * Double(stepsPerBeat))) }
            .filter { $0 >= 0 && $0 < stepsPerBar }
    }

    private static func hatAccentSteps(
        pulseOffsets: [Double],
        stepsPerBeat: Int
    ) -> Set<Int> {
        let steps = pulseOffsets.map { Int(round($0 * Double(stepsPerBeat))) }
        if steps.isEmpty {
            return [0]
        }
        return Set(steps)
    }

    private static func halfTimeSnareOffset(meter: MeterPattern) -> Double {
        if meter.timeBottom == 8 {
            if meter.beatsPerBar == 6 {
                return 3
            }
            if meter.beatsPerBar == 12 {
                return 6
            }
        }
        if meter.beatsPerBar >= 4 {
            return 2
        }
        return Double(max(1, meter.beatsPerBar - 1))
    }

    private static func basicKickOffsets(meter: MeterPattern) -> [Double] {
        if meter.timeBottom == 4 {
            switch meter.beatsPerBar {
            case 4:
                return [0, 2]
            case 3:
                return [0]
            case 5:
                return [0, 2, 4]
            default:
                return [0, Double(max(1, meter.beatsPerBar / 2))]
            }
        }
        if meter.beatsPerBar == 7 {
            return [0, 4]
        }
        return meter.pulseOffsets
    }
}
