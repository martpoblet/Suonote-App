import Foundation
import SwiftData

// Deduplicate and sort small Int arrays (drum steps)
@inline(__always)
private func uniqueSorted(_ arr: [Int]) -> [Int] {
    guard arr.count > 1 else { return arr }
    var seen = Set<Int>(minimumCapacity: arr.count)
    var result = [Int]()
    result.reserveCapacity(arr.count)
    for v in arr where seen.insert(v).inserted { result.append(v) }
    return result.sorted()
}

@inline(__always)
private func uniqueSorted(_ arr: [Double]) -> [Double] {
    guard arr.count > 1 else { return arr }
    var seen = Set<Double>(minimumCapacity: arr.count)
    var result = [Double]()
    result.reserveCapacity(arr.count)
    for v in arr where seen.insert(v).inserted { result.append(v) }
    return result.sorted()
}

struct StudioGenerator {
    struct ChordSpan {
        let chord: ChordEvent
        let startBeat: Double
        let duration: Double
    }

    struct SectionDynamic {
        let startBeat: Double
        let endBeat: Double
        let velocityScale: Float  // 0.6 (pp) to 1.2 (ff)
        let densityScale: Float   // 0.7 to 1.3
    }

    /// Map section names to dynamics levels (pp → ff)
    private static func sectionDynamics(for project: Project) -> [SectionDynamic] {
        let orderedItems = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        var dynamics: [SectionDynamic] = []
        var bar = 0
        let bpb = project.timeTop

        for item in orderedItems {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            let startBeat = Double(bar * bpb)
            let endBeat = Double((bar + bars) * bpb)
            let name = section.name.lowercased()

            let (velScale, densScale): (Float, Float)
            if name.contains("intro") {
                (velScale, densScale) = (0.7, 0.7)
            } else if name.contains("verse") {
                (velScale, densScale) = (0.85, 0.85)
            } else if name.contains("pre") {  // pre-chorus
                (velScale, densScale) = (0.95, 1.0)
            } else if name.contains("chorus") {
                (velScale, densScale) = (1.1, 1.2)
            } else if name.contains("bridge") {
                (velScale, densScale) = (0.8, 0.8)
            } else if name.contains("solo") {
                (velScale, densScale) = (1.0, 0.9)
            } else if name.contains("outro") {
                (velScale, densScale) = (0.75, 0.75)
            } else if name.contains("drop") {
                (velScale, densScale) = (1.2, 1.3)
            } else if name.contains("build") {
                (velScale, densScale) = (1.05, 1.1)
            } else {
                (velScale, densScale) = (1.0, 1.0)
            }
            dynamics.append(SectionDynamic(startBeat: startBeat, endBeat: endBeat, velocityScale: velScale, densityScale: densScale))
            bar += bars
        }
        return dynamics
    }

    /// Get dynamics scaling for a given beat position
    private static func dynamicScale(at beat: Double, dynamics: [SectionDynamic]) -> (velocity: Float, density: Float) {
        for d in dynamics where beat >= d.startBeat && beat < d.endBeat {
            return (d.velocityScale, d.densityScale)
        }
        return (1.0, 1.0)
    }

    /// Apply section-based dynamics to generated notes (velocity scaling)
    private static func applySectionDynamics(_ notes: [StudioNote], dynamics: [SectionDynamic]) {
        guard !dynamics.isEmpty else { return }
        for note in notes {
            let scale = dynamicScale(at: note.startBeat, dynamics: dynamics)
            note.velocity = min(127, max(1, Int(Float(note.velocity) * scale.velocity)))
        }
    }

    static func generateTracks(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext
    ) -> [StudioTrack] {
        let timeline = buildTimeline(for: project)
        let diatonicMap = diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)
        let sectionBounds = sectionStartBars(for: project)
        let dynamics = sectionDynamics(for: project)
        let instruments: [StudioInstrument] = [
            .piano,
            .synth,
            .guitar,
            .bass,
            .strings,
            .brass,
            .woodwinds,
            .organ,
            .mallets,
            .drums
        ]
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
            track.octaveShift = defaultOctaveShift(for: instrument, variant: track.variant)
            // Set per-instrument humanization defaults so freshly generated tracks
            // feel played rather than quantized. The applyNaturalness pass already
            // knows to apply less timing jitter to drums than melodic instruments.
            track.regenerateNaturalness = defaultNaturalness(for: instrument)

            let notes = notesForInstrument(
                instrument,
                chords: timeline.chords,
                totalBars: timeline.totalBars,
                beatsPerBar: project.timeTop,
                timeBottom: project.timeBottom,
                style: style,
                drumPreset: instrument == .drums ? track.drumPreset : nil,
                variant: track.variant,
                octaveShift: track.octaveShift,
                keyRoot: project.keyRoot,
                diatonicMap: diatonicMap,
                intensity: track.regenerateIntensity,
                complexity: track.regenerateComplexity,
                naturalness: track.regenerateNaturalness,
                arpeggioEnabled: track.regenerateArpeggioEnabled,
                arpeggioRate: track.regenerateArpeggioRate,
                arpeggioPattern: track.regenerateArpeggioPattern,
                sectionBoundaryBars: sectionBounds
            )
            applySectionDynamics(notes, dynamics: dynamics)
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
        resetDrumPreset: Bool = false,
        includeDrums: Bool = true
    ) {
        let timeline = buildTimeline(for: project)
        let diatonicMap = diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)
        let sectionBounds = sectionStartBars(for: project)
        let dynamics = sectionDynamics(for: project)
        let defaultDrumPreset = DrumPreset.defaultPreset(
            for: style,
            beatsPerBar: project.timeTop,
            timeBottom: project.timeBottom
        )

        for track in project.studioTracks where !track.instrument.isAudio {
            if track.instrument == .drums, !includeDrums {
                continue
            }
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
                variant: track.variant,
                octaveShift: track.octaveShift,
                keyRoot: project.keyRoot,
                diatonicMap: diatonicMap,
                intensity: track.regenerateIntensity,
                complexity: track.regenerateComplexity,
                naturalness: track.regenerateNaturalness,
                arpeggioEnabled: track.regenerateArpeggioEnabled,
                arpeggioRate: track.regenerateArpeggioRate,
                arpeggioPattern: track.regenerateArpeggioPattern,
                sectionBoundaryBars: sectionBounds
            )
            applySectionDynamics(notes, dynamics: dynamics)
            for note in notes {
                note.track = track
                track.notes.append(note)
                modelContext.insert(note)
            }
        }
    }

    static func appendNotesForNewContent(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext,
        newChordIds: Set<UUID>,
        previousTotalBars: Int
    ) -> Bool {
        let timeline = buildTimeline(for: project)
        let beatsPerBar = project.timeTop
        let timeBottom = project.timeBottom
        let diatonicMap = diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)
        let defaultDrumPreset = DrumPreset.defaultPreset(
            for: style,
            beatsPerBar: beatsPerBar,
            timeBottom: timeBottom
        )
        let previousTotalBeats = Double(previousTotalBars * beatsPerBar)
        let newChordSpans = timeline.chords.filter { newChordIds.contains($0.chord.id) }
        let newChordRanges = newChordSpans.map { span in
            (start: span.startBeat, end: span.startBeat + max(0.25, span.duration))
        }.sorted { $0.start < $1.start }
        var didAppend = false

        for track in project.studioTracks where !track.instrument.isAudio {
            if track.instrument == .drums {
                guard timeline.totalBars > previousTotalBars else { continue }
                let preset = track.drumPreset ?? defaultDrumPreset
                track.drumPreset = preset
                let drumNotes = generateDrumNotes(
                    totalBars: timeline.totalBars,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom,
                    style: style,
                    preset: preset,
                    variant: track.variant,
                    intensity: track.regenerateIntensity,
                    complexity: track.regenerateComplexity
                )
                let naturalDrums = applyNaturalness(
                    to: drumNotes,
                    totalBars: timeline.totalBars,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom,
                    instrument: .drums,
                    naturalness: track.regenerateNaturalness
                )
                let newNotes = naturalDrums.filter { $0.startBeat >= previousTotalBeats }
                didAppend = appendNotes(newNotes, to: track, modelContext: modelContext) || didAppend
                continue
            }

            guard !newChordRanges.isEmpty else { continue }
            let notes = notesForInstrument(
                track.instrument,
                chords: timeline.chords,
                totalBars: timeline.totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style: style,
                drumPreset: nil,
                variant: track.variant,
                octaveShift: track.octaveShift,
                keyRoot: project.keyRoot,
                diatonicMap: diatonicMap,
                intensity: track.regenerateIntensity,
                complexity: track.regenerateComplexity,
                naturalness: track.regenerateNaturalness,
                arpeggioEnabled: track.regenerateArpeggioEnabled,
                arpeggioRate: track.regenerateArpeggioRate,
                arpeggioPattern: track.regenerateArpeggioPattern
            )
            let newNotes = notes.filter { note in
                let beat = note.startBeat
                // Binary search: find first range where end > beat
                var lo = 0, hi = newChordRanges.count
                while lo < hi {
                    let mid = (lo + hi) / 2
                    if newChordRanges[mid].end <= beat { lo = mid + 1 } else { hi = mid }
                }
                return lo < newChordRanges.count && beat >= newChordRanges[lo].start && beat < newChordRanges[lo].end
            }
            didAppend = appendNotes(newNotes, to: track, modelContext: modelContext) || didAppend
        }

        return didAppend
    }

    static func replaceNotesForSections(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext,
        sectionIds: Set<UUID>
    ) -> Bool {
        guard !sectionIds.isEmpty else { return false }
        let timeline = buildTimeline(for: project)
        let beatsPerBar = project.timeTop
        let timeBottom = project.timeBottom
        let diatonicMap = diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)

        let ranges = sectionRanges(for: project).filter { sectionIds.contains($0.sectionId) }
        guard !ranges.isEmpty else { return false }
        let sortedRanges = ranges.sorted { $0.startBeat < $1.startBeat }

        let chordsInRanges = timeline.chords.filter { span in
            let beat = span.startBeat
            var lo = 0, hi = sortedRanges.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if sortedRanges[mid].endBeat <= beat { lo = mid + 1 } else { hi = mid }
            }
            return lo < sortedRanges.count && beat >= sortedRanges[lo].startBeat && beat < sortedRanges[lo].endBeat
        }
        guard !chordsInRanges.isEmpty else { return false }

        var didChange = false

        for track in project.studioTracks where !track.instrument.isAudio && track.instrument != .drums {
            let removed = removeNotes(in: ranges, from: track, modelContext: modelContext)
            didChange = removed || didChange

            let notes = notesForInstrument(
                track.instrument,
                chords: chordsInRanges,
                totalBars: timeline.totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style: style,
                drumPreset: nil,
                variant: track.variant,
                octaveShift: track.octaveShift,
                keyRoot: project.keyRoot,
                diatonicMap: diatonicMap,
                intensity: track.regenerateIntensity,
                complexity: track.regenerateComplexity,
                naturalness: track.regenerateNaturalness,
                arpeggioEnabled: track.regenerateArpeggioEnabled,
                arpeggioRate: track.regenerateArpeggioRate,
                arpeggioPattern: track.regenerateArpeggioPattern
            )
            didChange = appendNotes(notes, to: track, modelContext: modelContext) || didChange
        }

        return didChange
    }

    static func timeline(for project: Project) -> (chords: [ChordSpan], totalBars: Int) {
        buildTimeline(for: project)
    }

    static func generateNotes(
        for instrument: StudioInstrument,
        project: Project,
        style: StudioStyle,
        drumPreset: DrumPreset? = nil,
        variant: InstrumentVariant? = nil,
        octaveShift: Int = 2, // 2 = neutral (formula: (octaveShift − 2) × 12 = 0)
        intensity: Double = 0.5,
        complexity: Double = 0.5,
        naturalness: Double = 0.0,
        arpeggioEnabled: Bool = false,
        arpeggioRate: String = "1/8",
        arpeggioPattern: String = "up"
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
            variant: variant,
            octaveShift: octaveShift,
            keyRoot: project.keyRoot,
            diatonicMap: diatonicMap,
            intensity: intensity,
            complexity: complexity,
            naturalness: naturalness,
            arpeggioEnabled: arpeggioEnabled,
            arpeggioRate: arpeggioRate,
            arpeggioPattern: arpeggioPattern
        )
    }

    static func generateDrumNotes(
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        preset: DrumPreset?,
        variant: InstrumentVariant? = nil,
        intensity: Double = 0.5,
        complexity: Double = 0.5
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
            style: style,
            preset: resolvedPreset,
            variant: variant,
            intensity: intensity,
            complexity: complexity
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
                guard !chord.isRest else { continue }
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

    private struct SectionRange {
        let sectionId: UUID
        let startBeat: Double
        let endBeat: Double
    }

    private static func sectionRanges(for project: Project) -> [SectionRange] {
        let orderedItems = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        var ranges: [SectionRange] = []
        var sectionStartBar = 0
        let beatsPerBar = project.timeTop

        for item in orderedItems {
            guard let section = item.sectionTemplate else { continue }
            let sectionBars = max(1, section.bars)
            let startBeat = Double(sectionStartBar * beatsPerBar)
            let endBeat = Double((sectionStartBar + sectionBars) * beatsPerBar)
            ranges.append(SectionRange(sectionId: section.id, startBeat: startBeat, endBeat: endBeat))
            sectionStartBar += sectionBars
        }
        return ranges
    }

    private static func removeNotes(
        in ranges: [SectionRange],
        from track: StudioTrack,
        modelContext: ModelContext
    ) -> Bool {
        guard !ranges.isEmpty else { return false }
        var removed = false
        let toRemove = track.notes.filter { note in
            ranges.contains { note.startBeat >= $0.startBeat && note.startBeat < $0.endBeat }
        }
        guard !toRemove.isEmpty else { return false }
        for note in toRemove {
            modelContext.delete(note)
        }
        track.notes.removeAll { note in
            toRemove.contains { $0.id == note.id }
        }
        removed = true
        return removed
    }

    private static func appendNotes(
        _ notes: [StudioNote],
        to track: StudioTrack,
        modelContext: ModelContext
    ) -> Bool {
        guard !notes.isEmpty else { return false }
        var appended = false
        for note in notes {
            guard !track.notes.contains(where: { existing in
                existing.pitch == note.pitch
                    && abs(existing.startBeat - note.startBeat) < 0.0001
                    && abs(existing.duration - note.duration) < 0.0001
            }) else {
                continue
            }
            note.track = track
            track.notes.append(note)
            modelContext.insert(note)
            appended = true
        }
        return appended
    }

    /// Compute bar indices where a new section starts (for drum fills/crashes).
    private static func sectionStartBars(for project: Project) -> Set<Int> {
        let items = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        var bars: Set<Int> = []
        var currentBar = 0
        for item in items {
            guard let section = item.sectionTemplate else { continue }
            if currentBar > 0 { bars.insert(currentBar) }
            currentBar += max(1, section.bars)
        }
        return bars
    }

    private static func notesForInstrument(
        _ instrument: StudioInstrument,
        chords: [ChordSpan],
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        drumPreset: DrumPreset?,
        variant: InstrumentVariant?,
        octaveShift: Int,
        keyRoot: String,
        diatonicMap: [String: ChordQuality],
        intensity: Double = 0.5,
        complexity: Double = 0.5,
        naturalness: Double = 0.0,
        arpeggioEnabled: Bool = false,
        arpeggioRate: String = "1/8",
        arpeggioPattern: String = "up",
        sectionBoundaryBars: Set<Int> = []
    ) -> [StudioNote] {
        let generated: [StudioNote]
        switch instrument {
        case .drums:
            generated = drumNotes(
                totalBars: totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style: style,
                preset: drumPreset ?? DrumPreset.defaultPreset(
                    for: style,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom
                ),
                variant: variant,
                intensity: intensity,
                complexity: complexity,
                sectionBoundaryBars: sectionBoundaryBars
            )
        case .bass:
            generated = bassNotes(
                chords: chords,
                instrument: instrument,
                totalBars: totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style: style,
                variant: variant,
                octaveShift: octaveShift,
                keyRoot: keyRoot,
                intensity: intensity,
                complexity: complexity
            )
        case .guitar, .synth, .piano, .strings, .brass, .woodwinds, .organ, .mallets:
            generated = chordPadNotes(
                chords: chords,
                instrument: instrument,
                totalBars: totalBars,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                style: style,
                variant: variant,
                octaveShift: octaveShift,
                keyRoot: keyRoot,
                diatonicMap: diatonicMap,
                intensity: intensity,
                complexity: complexity,
                arpeggioEnabled: arpeggioEnabled,
                arpeggioRate: arpeggioRate,
                arpeggioPattern: arpeggioPattern
            )
        case .audio:
            generated = []
        }

        // Apply swing/groove feel before humanization so jitter sits on top of groove.
        let swung = applySwingFeel(
            to: generated,
            style: style,
            instrument: instrument,
            totalBars: totalBars,
            beatsPerBar: beatsPerBar
        )
        let humanized = applyNaturalness(
            to: swung,
            totalBars: totalBars,
            beatsPerBar: beatsPerBar,
            timeBottom: timeBottom,
            instrument: instrument,
            naturalness: naturalness
        )
        if instrument != .drums && instrument != .audio {
            let deduped = dedupeAndClampNotes(humanized)
            // Snap notes that almost fill a bar to cover it completely.
            return snapNotesToBarBoundaries(deduped, beatsPerBar: beatsPerBar)
        }
        return humanized
    }

    private static func chordPadNotes(
        chords: [ChordSpan],
        instrument: StudioInstrument,
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        variant: InstrumentVariant?,
        octaveShift: Int,
        keyRoot: String,
        diatonicMap: [String: ChordQuality],
        intensity: Double = 0.5,
        complexity: Double = 0.5,
        arpeggioEnabled: Bool = false,
        arpeggioRate: String = "1/8",
        arpeggioPattern: String = "up"
    ) -> [StudioNote] {
        let voicingProfile = chordVoicingProfile(
            for: instrument,
            variant: variant,
            style: style
        )
        let effectiveComplexity = max(0.0, min(1.0, complexity + voicingProfile.extensionBias))
        let range = chordRange(for: instrument, variant: variant, style: style, octaveShift: octaveShift)
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
            var pitches = chordPitches(
                rootPitch: rootPitch,
                quality: resolvedQuality,
                omitThird: voicingProfile.omitThird
            )
            let extensions = chordExtensionIntervals(
                for: resolvedQuality,
                style: style,
                instrument: instrument,
                variant: variant,
                complexity: effectiveComplexity
            )
            for interval in extensions {
                pitches.append(rootPitch + interval)
            }
            if intensity > 0.7, instrument != .guitar || voicingProfile.allowOctaveDoubling {
                pitches.append(rootPitch + 12)
            }
            pitches = uniqueSorted(pitches)
            pitches = fitPitches(pitches, in: range)
            
            // Monophonic instruments or variants: pick a single melodic pitch
            if (instrument == .woodwinds || voicingProfile.monophonic), let pitch = pitches.last {
                pitches = [pitch]
            }

            // Simplify guitar voicings - complexity scales note count up to 6
            if instrument == .guitar {
                let maxNotes = complexity > 0.8 ? 6 : (complexity > 0.6 ? 5 : (complexity > 0.4 ? 4 : (complexity > 0.2 ? 3 : 2)))
                let cappedNotes = min(maxNotes, voicingProfile.maxNotes ?? maxNotes)
                if pitches.count > cappedNotes {
                    pitches = Array(pitches.prefix(cappedNotes))
                }
            }
            
            if voicingProfile.preferOpenVoicing {
                pitches = openVoicing(pitches)
            }

            // Orchestral divisi spacing for strings — spread across cello/viola/violin registers
            if instrument == .strings, pitches.count >= 3 {
                pitches = divisiSpacing(pitches, range: range)
            }

            // Drop-2 voicing for brass — move 2nd-highest note down an octave
            if instrument == .brass, pitches.count >= 3 {
                pitches = drop2Voicing(pitches, range: range)
            }

            if let maxNotes = voicingProfile.maxNotes, pitches.count > maxNotes {
                pitches = Array(pitches.prefix(maxNotes))
            }
            
            let center = pitches.reduce(0, +) / max(1, pitches.count)
            lastCenter = center
            
            // Apply intensity to velocity with instrument-specific curve
            let baseVelocity = chordVelocity(for: instrument, style: style)
                + chordVelocityAdjustment(for: instrument, variant: variant, style: style)
            let velocity = velocityCurve(base: baseVelocity, intensity: intensity, instrument: instrument)
            
            let hitOffsets = chordHitOffsets(
                instrument: instrument,
                style: style,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                chordDuration: baseDuration,
                intensity: intensity,
                complexity: effectiveComplexity
            )

            for offset in hitOffsets {
                guard offset < baseDuration else { continue }
                let hitDuration = chordHitDuration(
                    instrument: instrument,
                    variant: variant,
                    style: style,
                    timeBottom: timeBottom,
                    baseDuration: baseDuration,
                    offset: offset,
                    durationScale: voicingProfile.durationScale
                )
                let duration = min(hitDuration, max(0.25, baseDuration - offset))
                let startBeat = span.startBeat + offset
                if arpeggioEnabled, pitches.count > 1 {
                    let orderedPitches = arpeggioOrder(
                        pitches: pitches,
                        pattern: arpeggioPattern
                    )
                    let step = arpeggioRateBeats(
                        arpeggioRate,
                        timeBottom: timeBottom
                    )
                    let spread = step * Double(max(0, orderedPitches.count - 1))
                    if spread <= max(0.0, baseDuration - offset - 0.05) {
                        for (index, pitch) in orderedPitches.enumerated() {
                            let arpOffset = step * Double(index)
                            let arpStart = startBeat + arpOffset
                            let arpDuration = min(duration, max(0.05, baseDuration - offset - arpOffset))
                            notes.append(
                                StudioNote(
                                    startBeat: arpStart,
                                    duration: arpDuration,
                                    pitch: pitch,
                                    velocity: velocity
                                )
                            )
                        }
                    } else {
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
                } else {
                    // Guitar strumming simulation — micro-delay between chord tones
                    let strumDelay = (instrument == .guitar && pitches.count > 1) ? 0.012 : 0.0
                    for (idx, pitch) in pitches.enumerated() {
                        let strumOffset = strumDelay * Double(idx)
                        notes.append(
                            StudioNote(
                                startBeat: startBeat + strumOffset,
                                duration: max(0.1, duration - strumOffset),
                                pitch: pitch,
                                velocity: velocity
                            )
                        )
                    }
                }
            }
        }

        // Avoid overlapping note-ons for the same pitch when density/intensity increases.
        return dedupeAndClampNotes(notes)
    }

    private static func bassNotes(
        chords: [ChordSpan],
        instrument: StudioInstrument,
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        variant: InstrumentVariant?,
        octaveShift: Int,
        keyRoot: String,
        intensity: Double = 0.5,
        complexity: Double = 0.5
    ) -> [StudioNote] {
        let range = bassRange(variant: variant, style: style, octaveShift: octaveShift)
        let bassProfile = bassVoicingProfile(variant: variant, style: style)
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
                // Root-5th-octave pattern
                if baseDuration >= midBeat + 0.25 {
                    hits.append((midBeat, fifth))
                }
                if baseDuration >= midBeat * 2 + 0.25 {
                    hits.append((midBeat * 2, octave))
                }
            case .rock:
                // Driving root-5th with syncopation
                if baseDuration >= 1.0 {
                    hits.append((1.0, fifth))
                }
                if baseDuration >= midBeat + 0.25 {
                    hits.append((midBeat, rootPitch))
                }
            case .lofi:
                hits = [(0, rootPitch)]
            case .edm:
                let strideBeat = timeBottom == 8 ? midBeat : 1.0
                let offsets = stride(from: 0.0, to: baseDuration, by: strideBeat).map { $0 }
                hits = offsets.map { ($0, rootPitch) }
            case .jazz:
                // Walking bass: root → 3rd → 5th → chromatic approach to next root
                if baseDuration >= 2.0 {
                    let third = fitPitch(rootPitch + (span.chord.quality.isMinor ? 3 : 4), in: range)
                    hits = [(0, rootPitch), (1.0, third)]
                    if baseDuration >= 3.0 {
                        hits.append((2.0, fifth))
                    }
                    // Chromatic approach to next chord root
                    if baseDuration >= 4.0 {
                        let nextRootClass = rootClass  // Will be overridden by approach
                        let approach = fitPitch(rootPitch + (nextRootClass % 2 == 0 ? 11 : 1), in: range)
                        hits.append((3.0, approach))
                    }
                } else if baseDuration >= 1.0 {
                    hits.append((0.75, fifth))
                }
            case .hiphop:
                hits = [(0, rootPitch)]
                if baseDuration >= 2.0 {
                    hits.append((1.5, rootPitch))
                }
            case .funk:
                // Syncopated: root + offbeat hits with octave jumps
                let offsets = stride(from: 0.0, to: baseDuration, by: 0.5).map { $0 }
                hits = offsets.enumerated().map { idx, offset in
                    (offset, idx % 2 == 0 ? rootPitch : (idx % 4 == 1 ? octave : fifth))
                }
            case .ambient:
                hits = [(0, rootPitch)]
            }

            let density = max(0.0, min(1.0, complexity))
            if density < 0.35 {
                hits = hits.first.map { [$0] } ?? []
            } else {
                if style == .jazz, density > 0.6 {
                    hits = stride(from: 0.0, to: baseDuration, by: 1.0).map { ($0, rootPitch) }
                }
                if density > 0.6 {
                    let extraOffset = min(midBeat, baseDuration - 0.25)
                    if extraOffset > 0 {
                        let extraPitch: Int
                        switch style {
                        case .edm:
                            extraPitch = octave
                        case .hiphop:
                            extraPitch = rootPitch
                        default:
                            extraPitch = fifth
                        }
                        hits.append((extraOffset, extraPitch))
                    }
                }
                if density > 0.85, baseDuration >= 1.5 {
                    let approachOffset = max(0.5, baseDuration - 0.5)
                    if approachOffset < baseDuration {
                        hits.append((approachOffset, fitPitch(rootPitch + 2, in: range)))
                    }
                }
            }

            if bassProfile.syncopationBoost, baseDuration >= 1.0 {
                hits.append((min(0.5, baseDuration - 0.25), fifth))
            }
            if bassProfile.useOctaveJump, baseDuration >= 1.5 {
                hits.append((min(1.0, baseDuration - 0.25), octave))
            }

            let durationHint = bassHitDuration(style: style) * bassProfile.durationScale
            let adjustedDuration = max(0.25, durationHint * (1.1 - 0.4 * intensity))
            let velocity = scaledVelocity(
                base: bassVelocity(for: style) + bassProfile.velocityOffset,
                intensity: intensity,
                range: 36
            )
            var seenOffsets = Set<Double>()
            let orderedHits = hits
                .filter { seenOffsets.insert($0.offset).inserted }
                .sorted { $0.offset < $1.offset }

            for hit in orderedHits {
                guard hit.offset < baseDuration else { continue }
                let duration = min(adjustedDuration, max(0.25, baseDuration - hit.offset))
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

        // Prevent overlapping bass notes on the same pitch.
        return dedupeAndClampNotes(notes)
    }

    private static func dedupeAndClampNotes(
        _ notes: [StudioNote],
        minimumDuration: Double = 0.05
    ) -> [StudioNote] {
        let epsilon = 0.0001
        var byPitch: [Int: [StudioNote]] = [:]
        for note in notes {
            byPitch[note.pitch, default: []].append(note)
        }

        var result: [StudioNote] = []
        for (_, pitchNotes) in byPitch {
            let ordered = pitchNotes.sorted { lhs, rhs in
                if abs(lhs.startBeat - rhs.startBeat) > epsilon {
                    return lhs.startBeat < rhs.startBeat
                }
                if lhs.duration != rhs.duration {
                    return lhs.duration > rhs.duration
                }
                return lhs.velocity > rhs.velocity
            }

            var lastStart: Double? = nil
            for index in ordered.indices {
                let note = ordered[index]
                if let lastStart, abs(note.startBeat - lastStart) < epsilon {
                    continue
                }

                var duration = max(minimumDuration, note.duration)
                if index + 1 < ordered.count {
                    let nextStart = ordered[index + 1].startBeat
                    if nextStart > note.startBeat + epsilon {
                        duration = min(duration, max(minimumDuration, nextStart - note.startBeat))
                    }
                }

                let clamped = StudioNote(
                    startBeat: note.startBeat,
                    duration: duration,
                    pitch: note.pitch,
                    velocity: note.velocity
                )
                result.append(clamped)
                lastStart = note.startBeat
            }
        }

        return result.sorted { $0.startBeat < $1.startBeat }
    }

    /// Snaps notes whose end falls just before a bar boundary, extending them to fill the bar.
    /// e.g., a note lasting 3.75 beats in a 4/4 bar becomes 4.0 beats (full bar).
    /// Threshold: notes within `snapThreshold` beats of a bar boundary are snapped.
    private static func snapNotesToBarBoundaries(
        _ notes: [StudioNote],
        beatsPerBar: Int,
        snapThreshold: Double = 0.5
    ) -> [StudioNote] {
        let bpb = Double(beatsPerBar)
        return notes.map { note in
            let noteEnd = note.startBeat + note.duration
            // Find the next bar boundary at or above noteEnd
            let barBoundary = ceil(noteEnd / bpb) * bpb
            let gap = barBoundary - noteEnd
            // Only snap if the gap is small but positive (avoids snapping already-full bars)
            guard gap > 1e-6 && gap <= snapThreshold else { return note }
            return StudioNote(
                startBeat: note.startBeat,
                duration: note.duration + gap,
                pitch: note.pitch,
                velocity: note.velocity
            )
        }
    }

    // MARK: - Swing / Groove feel

    /// Returns the swing shift amount (beats) and grain size for styles that require groove.
    /// - shift: how many beats to push an upbeat note later (0 = no swing)
    /// - grain: subdivision size being swung (1.0 = 8th-note swing, 0.5 = 16th-note shuffle)
    /// Per-instrument humanization level applied when tracks are first generated.
    /// Keeps drums tighter to the grid while letting melodic instruments breathe.
    private static func defaultNaturalness(for instrument: StudioInstrument) -> Double {
        switch instrument {
        case .drums:      return 0.30   // Tight but not robotic — slight velocity scatter
        case .bass:       return 0.40   // Slightly laid-back feel
        case .guitar:     return 0.42   // Strummy, imprecise timing is musical
        case .piano:      return 0.45   // Most expressive — widest timing/velocity range
        case .synth:      return 0.28   // Synths can be tighter
        case .strings:    return 0.20   // Pads / long notes — timing variation less audible
        case .brass:      return 0.25
        case .woodwinds:  return 0.28
        case .organ:      return 0.18   // Organ is typically tight / locked to grid
        case .mallets:    return 0.32
        case .audio:      return 0.0
        }
    }

    private static func swingConfig(
        for style: StudioStyle,
        instrument: StudioInstrument
    ) -> (shift: Double, grain: Double)? {
        switch style {
        case .jazz:
            // Standard jazz triplet swing: upbeats land at ~62% of beat instead of 50%.
            // Drums get a slightly smaller shift for natural feel.
            return (instrument == .drums ? 0.10 : 0.12, 1.0)
        case .hiphop:
            // Laid-back 8th-note swing, subtle (56% feel).
            return (0.06, 1.0)
        case .funk:
            // 16th-note shuffle: "e" and "ah" subdivisions pushed slightly later.
            return (0.04, 0.5)
        default:
            return nil
        }
    }

    /// Push notes landing on upbeat subdivisions later to create swing/groove feel.
    /// Called before `applyNaturalness` so random jitter rides on top of the groove.
    private static func applySwingFeel(
        to notes: [StudioNote],
        style: StudioStyle,
        instrument: StudioInstrument,
        totalBars: Int,
        beatsPerBar: Int
    ) -> [StudioNote] {
        guard let (shift, grain) = swingConfig(for: style, instrument: instrument),
              !notes.isEmpty else { return notes }

        let upbeat = grain / 2
        // Tolerance: 6% of grain (accounts for small floating-point offsets in generated hits)
        let tolerance = grain * 0.06
        let timelineBeats = Double(totalBars * beatsPerBar)

        return notes.map { note in
            let phase = note.startBeat.truncatingRemainder(dividingBy: grain)
            guard abs(phase - upbeat) < tolerance else { return note }
            let newStart = min(note.startBeat + shift, timelineBeats - 0.05)
            // Upbeats are played slightly softer — standard jazz/funk articulation.
            let newVelocity = max(1, note.velocity - 5)
            return StudioNote(
                startBeat: newStart,
                duration: note.duration,
                pitch: note.pitch,
                velocity: newVelocity
            )
        }
    }

    private static func applyNaturalness(
        to notes: [StudioNote],
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        instrument: StudioInstrument,
        naturalness: Double
    ) -> [StudioNote] {
        let clamped = max(0.0, min(1.0, naturalness))
        guard clamped > 0, !notes.isEmpty else { return notes }
        let timelineBeats = Double(totalBars * beatsPerBar)
        let baseOffset = 0.12 * (4.0 / Double(timeBottom))
        let timingMax = (instrument == .drums ? baseOffset * 0.4 : baseOffset) * clamped
        let velocityMax = Int(round(12.0 * clamped))

        var adjusted: [StudioNote] = []
        adjusted.reserveCapacity(notes.count)
        for note in notes {
            let timingDelta = Double.random(in: -timingMax...timingMax)
            let newStart = min(max(0, note.startBeat + timingDelta), max(0.0, timelineBeats - 0.05))
            let maxDuration = max(0.05, timelineBeats - newStart)
            let newDuration = min(note.duration, maxDuration)
            let velocityDelta = Int.random(in: -velocityMax...velocityMax)
            let newVelocity = min(127, max(1, note.velocity + velocityDelta))
            adjusted.append(
                StudioNote(
                    startBeat: newStart,
                    duration: newDuration,
                    pitch: note.pitch,
                    velocity: newVelocity
                )
            )
        }
        return adjusted
    }

    private static func arpeggioRateBeats(_ rate: String, timeBottom: Int) -> Double {
        let trimmed = rate.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/")
        guard parts.count == 2, let denom = Double(parts[1]) else { return 0.5 }
        return Double(timeBottom) / denom
    }

    private static func arpeggioOrder(pitches: [Int], pattern: String) -> [Int] {
        let ordered = pitches.sorted()
        switch pattern.lowercased() {
        case "down":
            return Array(ordered.reversed())
        case "updown":
            guard ordered.count > 2 else { return ordered }
            let down = ordered.dropFirst().dropLast().reversed()
            return ordered + Array(down)
        default:
            return ordered
        }
    }

    private static func drumNotes(
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        preset: DrumPreset,
        variant: InstrumentVariant?,
        intensity: Double = 0.5,
        complexity: Double = 0.5,
        sectionBoundaryBars: Set<Int> = []
    ) -> [StudioNote] {
        let stepsPerBeat = timeBottom == 8 ? 2 : 4
        let stepLength = 1.0 / Double(stepsPerBeat)
        let stepsPerBar = beatsPerBar * stepsPerBeat
        let meter = meterPattern(beatsPerBar: beatsPerBar, timeBottom: timeBottom)
        var pattern = drumPattern(
            for: preset,
            meter: meter,
            stepsPerBeat: stepsPerBeat,
            stepsPerBar: stepsPerBar
        )
        let resolvedVariant = SoundFontManager.resolvedVariant(for: .drums, variant: variant) ?? .standardDrumKit

        let density = max(0.0, min(1.0, complexity))
        if density < 0.35 {
            pattern = DrumPattern(
                kick: pattern.kick.filter { $0 % stepsPerBeat == 0 },
                snare: Array(pattern.snare.prefix(1)),
                hatClosed: pattern.hatClosed.filter { $0 % stepsPerBeat == 0 },
                hatOpen: [],
                clap: [],
                rim: [],
                tomLow: [],
                tomMid: [],
                tomHigh: [],
                ride: [],
                crash: [],
                perc: []
            )
        } else if density > 0.75 {
            let offbeatSteps = stepsFromOffsets(
                meter.offbeatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            let extraHat = pattern.hatClosed + offbeatSteps
            let extraSnare = density > 0.9 ? (pattern.snare + offbeatSteps) : pattern.snare
            pattern = DrumPattern(
                kick: pattern.kick,
                snare: uniqueSorted(extraSnare),
                hatClosed: uniqueSorted(extraHat),
                hatOpen: pattern.hatOpen,
                clap: pattern.clap,
                rim: pattern.rim,
                tomLow: pattern.tomLow,
                tomMid: pattern.tomMid,
                tomHigh: pattern.tomHigh,
                ride: pattern.ride,
                crash: pattern.crash,
                perc: pattern.perc
            )
        }

        let accentSteps = hatAccentSteps(
            pulseOffsets: meter.pulseOffsets,
            stepsPerBeat: stepsPerBeat
        )
        let beatSteps = stepsFromOffsets(
            meter.beatOffsets,
            stepsPerBeat: stepsPerBeat,
            stepsPerBar: stepsPerBar
        )
        let offbeatSteps = stepsFromOffsets(
            meter.offbeatOffsets,
            stepsPerBeat: stepsPerBeat,
            stepsPerBar: stepsPerBar
        )
        let backbeatSteps = stepsFromOffsets(
            meter.backbeatOffsets,
            stepsPerBeat: stepsPerBeat,
            stepsPerBar: stepsPerBar
        )
        var kickSteps = pattern.kick
        var snareSteps = pattern.snare
        var hatClosedSteps = pattern.hatClosed
        var clapSteps = pattern.clap

        switch resolvedVariant {
        case .powerDrumKit:
            kickSteps = uniqueSorted(kickSteps + backbeatSteps)
            if density > 0.6 {
                snareSteps = uniqueSorted(snareSteps + offbeatSteps)
            }
        case .roomDrumKit:
            if density < 0.5 {
                hatClosedSteps = hatClosedSteps.filter { $0 % stepsPerBeat == 0 }
            }
        case .electronicDrumKit, .tr808DrumKit:
            let electronicHats = density > 0.6 ? Array(0..<stepsPerBar) : offbeatSteps
            hatClosedSteps = uniqueSorted(hatClosedSteps + electronicHats)
            if density > 0.5 {
                kickSteps = uniqueSorted(kickSteps + offbeatSteps)
            }
        case .jazzDrumKit:
            kickSteps = Array(beatSteps.prefix(2))
            snareSteps = density > 0.6 ? backbeatSteps : Array(snareSteps.prefix(1))
            hatClosedSteps = beatSteps
        case .brushDrumKit:
            kickSteps = [0]
            snareSteps = density > 0.7 ? backbeatSteps : []
            hatClosedSteps = []
            clapSteps = []
        case .orchestraDrumKit:
            kickSteps = [0]
            snareSteps = density > 0.7 ? backbeatSteps : []
            hatClosedSteps = []
            clapSteps = []
        case .sfxDrumKit:
            kickSteps = density > 0.6 ? beatSteps : [0]
            snareSteps = []
            hatClosedSteps = []
            clapSteps = []
        default:
            break
        }
        kickSteps = uniqueSorted(kickSteps)
        snareSteps = uniqueSorted(snareSteps)
        hatClosedSteps = uniqueSorted(hatClosedSteps)
        clapSteps = uniqueSorted(clapSteps)
        let isLatinPreset = preset == .latin || preset == .bossa
        var notes: [StudioNote] = []
        var kickVelocityBase = style == .rock ? 118 : 112
        var snareVelocityBase = style == .rock ? 108 : 102
        var hatVelocityBase = style == .ambient ? 62 : 72
        let clapVelocityBase = style == .edm ? 98 : 90
        let rimVelocityBase = style == .hiphop ? 92 : 84
        let tomVelocityBase = style == .rock ? 108 : 96
        var rideVelocityBase = style == .jazz ? 76 : 72
        var crashVelocityBase = style == .rock ? 114 : 106
        var percVelocityBase = isLatinPreset ? 96 : 88
        switch resolvedVariant {
        case .standardDrumKit:
            crashVelocityBase -= 6
        case .powerDrumKit:
            kickVelocityBase += 6
            snareVelocityBase += 6
            crashVelocityBase += 4
        case .roomDrumKit:
            hatVelocityBase -= 4
        case .electronicDrumKit, .tr808DrumKit:
            kickVelocityBase += 2
            snareVelocityBase -= 2
            hatVelocityBase -= 4
            crashVelocityBase -= 6
        case .jazzDrumKit:
            kickVelocityBase -= 8
            snareVelocityBase -= 10
            hatVelocityBase -= 8
            rideVelocityBase -= 4
            crashVelocityBase -= 10
        case .brushDrumKit:
            kickVelocityBase -= 16
            snareVelocityBase -= 18
            hatVelocityBase -= 14
            rideVelocityBase -= 10
            crashVelocityBase -= 16
        case .orchestraDrumKit:
            kickVelocityBase -= 8
            snareVelocityBase -= 8
            hatVelocityBase -= 12
            crashVelocityBase -= 12
            percVelocityBase -= 6
        case .sfxDrumKit:
            kickVelocityBase -= 4
            snareVelocityBase -= 6
            hatVelocityBase -= 12
            crashVelocityBase -= 14
            percVelocityBase += 4
        default:
            break
        }
        let pitchMap = SoundFontManager.drumPitchMap(for: variant)
        var openHatSteps = pattern.hatOpen
        if intensity > 0.55 {
            openHatSteps.append(contentsOf: offbeatSteps)
        }
        if density > 0.8 {
            openHatSteps.append(contentsOf: backbeatSteps)
        }
        if resolvedVariant == .electronicDrumKit || resolvedVariant == .tr808DrumKit {
            openHatSteps.append(contentsOf: offbeatSteps)
        }
        if resolvedVariant == .brushDrumKit || resolvedVariant == .orchestraDrumKit || resolvedVariant == .sfxDrumKit {
            openHatSteps = []
        }
        openHatSteps = uniqueSorted(openHatSteps)

        var rideSteps: [Int] = []
        switch style {
        case .jazz:
            if density > 0.45 {
                rideSteps = uniqueSorted(beatSteps + offbeatSteps)
            }
        case .rock, .funk:
            if density > 0.6 {
                rideSteps = beatSteps
            }
        case .edm, .pop:
            if density > 0.7 {
                rideSteps = offbeatSteps
            }
        case .lofi, .hiphop, .ambient:
            rideSteps = []
        }
        switch resolvedVariant {
        case .jazzDrumKit:
            rideSteps = density > 0.4 ? uniqueSorted(beatSteps + offbeatSteps) : beatSteps
        case .brushDrumKit:
            rideSteps = beatSteps
        case .electronicDrumKit, .tr808DrumKit, .orchestraDrumKit, .sfxDrumKit:
            rideSteps = []
        default:
            break
        }
        if isLatinPreset, density > 0.55, rideSteps.isEmpty {
            rideSteps = beatSteps
        }

        var crashBars: Set<Int> = []
        if intensity > 0.45 || style == .rock || style == .edm {
            let interval: Int?
            switch resolvedVariant {
            case .standardDrumKit:
                interval = intensity > 0.6 ? 2 : 4
            case .powerDrumKit:
                interval = intensity > 0.6 ? 1 : 2
            case .roomDrumKit:
                interval = 2
            case .electronicDrumKit, .tr808DrumKit, .jazzDrumKit, .brushDrumKit, .orchestraDrumKit, .sfxDrumKit:
                interval = intensity > 0.85 ? 4 : nil
            default:
                interval = 2
            }
            if let interval {
                crashBars = Set(stride(from: 0, to: totalBars, by: interval))
            }
        }

        var rimSteps: [Int] = []
        if style == .hiphop || style == .lofi {
            rimSteps = density < 0.6 ? offbeatSteps : backbeatSteps
        }

        var percSteps: [Int] = []
        if isLatinPreset {
            percSteps = offbeatSteps
        } else if style == .funk && density > 0.5 {
            percSteps = offbeatSteps
        } else if style == .edm && density > 0.8 {
            percSteps = beatSteps
        }
        if resolvedVariant == .orchestraDrumKit || resolvedVariant == .sfxDrumKit {
            percSteps = beatSteps
        }

        var tomLowSteps: [Int] = []
        var tomMidSteps: [Int] = []
        var tomHighSteps: [Int] = []
        if density > 0.7 || intensity > 0.7 {
            let fillStart = max(stepsPerBar - stepsPerBeat, 0)
            let fillSteps = (0..<min(stepsPerBeat, 3)).map { fillStart + $0 }.filter { $0 < stepsPerBar }
            if let first = fillSteps.first {
                tomLowSteps.append(first)
            }
            if fillSteps.count > 1 {
                tomMidSteps.append(fillSteps[1])
            }
            if fillSteps.count > 2 {
                tomHighSteps.append(fillSteps[2])
            }
        }
        if style == .rock && density > 0.6 {
            tomMidSteps.append(contentsOf: backbeatSteps.filter { $0 % stepsPerBeat == 0 })
        }
        if resolvedVariant == .powerDrumKit, density > 0.6 {
            tomLowSteps.append(contentsOf: backbeatSteps.filter { $0 % stepsPerBeat == 0 })
        }
        if resolvedVariant == .brushDrumKit || resolvedVariant == .orchestraDrumKit || resolvedVariant == .sfxDrumKit {
            tomLowSteps = []
            tomMidSteps = []
            tomHighSteps = []
        }
        tomLowSteps = uniqueSorted(tomLowSteps)
        tomMidSteps = uniqueSorted(tomMidSteps)
        tomHighSteps = uniqueSorted(tomHighSteps)

        for bar in 0..<totalBars {
            let barStart = Double(bar * beatsPerBar)
            let isBeforeSectionChange = sectionBoundaryBars.contains(bar + 1)
            let isSectionStart = sectionBoundaryBars.contains(bar)

            // Crash cymbal on first beat of new sections
            if isSectionStart && bar > 0 {
                notes.append(StudioNote(
                    startBeat: barStart,
                    duration: stepLength * 2,
                    pitch: pitchMap.crash,
                    velocity: scaledVelocity(base: crashVelocityBase + 8, intensity: intensity, range: 16)
                ))
            }

            // Auto-fill on last bar before section transition
            if isBeforeSectionChange && intensity > 0.3 {
                let fillBase = max(0, stepsPerBar - stepsPerBeat * 2)
                for i in 0..<min(stepsPerBeat * 2, stepsPerBar) {
                    let fillStep = fillBase + i
                    guard fillStep < stepsPerBar else { continue }
                    let fillBeat = barStart + Double(fillStep) * stepLength
                    let tom: Int
                    if i < stepsPerBeat / 2 { tom = pitchMap.tomHigh }
                    else if i < stepsPerBeat { tom = pitchMap.tomMid }
                    else { tom = pitchMap.tomLow }
                    notes.append(StudioNote(
                        startBeat: fillBeat,
                        duration: stepLength,
                        pitch: tom,
                        velocity: scaledVelocity(base: tomVelocityBase + 4, intensity: intensity, range: 20)
                    ))
                }
            }

            for step in kickSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.kick,
                        velocity: scaledVelocity(
                            base: step == 0 ? kickVelocityBase : kickVelocityBase - 8,
                            intensity: intensity,
                            range: 24
                        )
                    )
                )
            }
            for step in snareSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.snare,
                        velocity: scaledVelocity(
                            base: snareVelocityBase,
                            intensity: intensity,
                            range: 22
                        )
                    )
                )
            }
            // Ghost notes on snare — low velocity hits on off-beat 16ths
            if density > 0.45 && !isBeforeSectionChange {
                let snareSet = Set(snareSteps)
                for step in offbeatSteps where !snareSet.contains(step) {
                    let ghostStep = step + (stepsPerBeat > 2 ? 1 : 0)
                    guard ghostStep < stepsPerBar, !snareSet.contains(ghostStep) else { continue }
                    notes.append(StudioNote(
                        startBeat: barStart + Double(ghostStep) * stepLength,
                        duration: stepLength * 0.5,
                        pitch: pitchMap.snare,
                        velocity: Int.random(in: 22...35)
                    ))
                }
            }
            for step in pattern.rim + rimSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.rim,
                        velocity: scaledVelocity(
                            base: rimVelocityBase,
                            intensity: intensity,
                            range: 16
                        )
                    )
                )
            }
            var effectiveOpenHatSteps = openHatSteps
            // Hi-hat variation: open on off-beats for rock, 16th-note hats for funk
            if style == .rock && density > 0.5 {
                let rockOpenSteps = offbeatSteps.filter { !Set(openHatSteps).contains($0) }
                effectiveOpenHatSteps = uniqueSorted(openHatSteps + Array(rockOpenSteps.prefix(2)))
            }
            if style == .funk && density > 0.6 {
                // Add 16th-note subdivision hats
                let sixteenthSteps = (0..<stepsPerBar).filter { $0 % max(1, stepsPerBeat / 2) == 0 }
                let extraHats = sixteenthSteps.filter { !Set(hatClosedSteps).contains($0) && !Set(effectiveOpenHatSteps).contains($0) }
                for step in extraHats {
                    notes.append(StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength * 0.5,
                        pitch: pitchMap.hatClosed,
                        velocity: scaledVelocity(base: hatVelocityBase - 10, intensity: intensity, range: 12)
                    ))
                }
            }
            let closedHatSteps = hatClosedSteps.filter { !effectiveOpenHatSteps.contains($0) }
            for step in closedHatSteps {
                let velocity = accentSteps.contains(step)
                    ? scaledVelocity(base: hatVelocityBase + 8, intensity: intensity, range: 18)
                    : scaledVelocity(base: hatVelocityBase, intensity: intensity, range: 16)
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.hatClosed,
                        velocity: velocity
                    )
                )
            }
            for step in effectiveOpenHatSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.hatOpen,
                        velocity: scaledVelocity(
                            base: hatVelocityBase + 10,
                            intensity: intensity,
                            range: 16
                        )
                    )
                )
            }
            for step in rideSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.ride,
                        velocity: scaledVelocity(
                            base: rideVelocityBase,
                            intensity: intensity,
                            range: 14
                        )
                    )
                )
            }
            if crashBars.contains(bar) {
                let crashSteps = density > 0.85 ? uniqueSorted([0] + backbeatSteps) : [0]
                for step in crashSteps {
                    notes.append(
                        StudioNote(
                            startBeat: barStart + Double(step) * stepLength,
                            duration: stepLength,
                            pitch: pitchMap.crash,
                            velocity: scaledVelocity(
                                base: crashVelocityBase,
                                intensity: intensity,
                                range: 20
                            )
                        )
                    )
                }
            }
            for step in tomLowSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.tomLow,
                        velocity: scaledVelocity(
                            base: tomVelocityBase - 6,
                            intensity: intensity,
                            range: 18
                        )
                    )
                )
            }
            for step in tomMidSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.tomMid,
                        velocity: scaledVelocity(
                            base: tomVelocityBase,
                            intensity: intensity,
                            range: 18
                        )
                    )
                )
            }
            for step in tomHighSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.tomHigh,
                        velocity: scaledVelocity(
                            base: tomVelocityBase + 4,
                            intensity: intensity,
                            range: 18
                        )
                    )
                )
            }
            for step in clapSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.clap,
                        velocity: scaledVelocity(
                            base: clapVelocityBase,
                            intensity: intensity,
                            range: 18
                        )
                    )
                )
            }
            for step in percSteps {
                notes.append(
                    StudioNote(
                        startBeat: barStart + Double(step) * stepLength,
                        duration: stepLength,
                        pitch: pitchMap.perc,
                        velocity: scaledVelocity(
                            base: percVelocityBase,
                            intensity: intensity,
                            range: 14
                        )
                    )
                )
            }
        }

        return notes
    }

    private static func chordPitches(
        rootPitch: Int,
        quality: ChordQuality,
        omitThird: Bool
    ) -> [Int] {
        let intervals = simpleIntervals(for: quality, omitThird: omitThird)
        return intervals.map { rootPitch + $0 }
    }

    private static func chordExtensionIntervals(
        for quality: ChordQuality,
        style: StudioStyle,
        instrument: StudioInstrument,
        variant: InstrumentVariant?,
        complexity: Double
    ) -> [Int] {
        guard complexity > 0.35 else { return [] }

        let seventhInterval: Int = {
            switch quality {
            case .major, .major7, .minorMajor7:
                return 11
            case .diminished7:
                return 9
            default:
                return 10
            }
        }()

        var intervals: [Int] = []

        switch style {
        case .jazz:
            intervals.append(seventhInterval)
            if complexity > 0.5 {
                intervals.append(14) // 9th
            }
            if complexity > 0.8 {
                intervals.append(21) // 13th
            }
        case .lofi:
            if complexity > 0.4 {
                intervals.append(seventhInterval)
            }
            if complexity > 0.7 {
                intervals.append(14) // 9th for dreamy quality
            }
        case .ambient:
            if instrument != .guitar {
                intervals.append(14) // add9
            }
            if complexity > 0.6 {
                intervals.append(17) // 11th for suspended feel
            }
        case .pop:
            if complexity > 0.5, quality == .major || quality == .minor {
                intervals.append(14) // add9 / sus4 color
            }
            if complexity > 0.8 {
                intervals.append(seventhInterval)
            }
        case .funk:
            intervals.append(10) // dom7 always in funk
            if complexity > 0.7, instrument == .piano || instrument == .guitar {
                intervals.append(14) // 9th
            }
        case .edm:
            if instrument == .synth, complexity > 0.5 {
                intervals.append(14) // add9
            }
        case .rock:
            if instrument == .guitar, complexity > 0.3 {
                // Power chords: remove 3rd (keep root+5th only) handled by voicing
                intervals.removeAll() // rock guitar = power chords
            } else if instrument == .piano, complexity > 0.6 {
                intervals.append(seventhInterval)
            }
        case .hiphop:
            if instrument == .piano || instrument == .synth {
                intervals.append(seventhInterval)
                if complexity > 0.7 {
                    intervals.append(14) // 9th
                }
            }
        }

        if let variant {
            switch variant {
            case .brightPiano, .electricPiano, .electricPiano2, .padWarm, .padHalo, .padSweep:
                if complexity > 0.5 {
                    intervals.append(14)
                }
            case .padChoir, .padBowed, .padPolysynth, .padNewAge, .padMetallic:
                if complexity > 0.4 {
                    intervals.append(14)
                }
                if complexity > 0.75 {
                    intervals.append(17)
                }
            case .harpsichord, .honkyTonkPiano, .clavinet, .mutedGuitar, .overdriveGuitar, .distortionGuitar:
                intervals.removeAll()
            case .tremoloStrings, .stringEnsemble, .slowStrings, .synthStrings1, .synthStrings2:
                if complexity > 0.55 {
                    intervals.append(14)
                }
            case .brassSection, .synthBrass1, .synthBrass2:
                if complexity > 0.6 {
                    intervals.append(seventhInterval)
                }
            case .vibraphone, .marimba:
                if complexity > 0.6 {
                    intervals.append(14)
                }
            default:
                break
            }
        }

        return intervals
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
        variant: InstrumentVariant? = nil,
        style: StudioStyle? = nil,
        octaveShift: Int = 2 // 2 = neutral (formula: (octaveShift − 2) × 12 = 0)
    ) -> ClosedRange<Int> {
        let base = baseInstrumentRange(for: instrument, variant: variant)
        let styleShift = styleRegisterShift(for: instrument, style: style)
        let semitoneShift = styleShift + ((octaveShift - 2) * 12)
        return shiftRange(base, by: semitoneShift)
    }

    /// Returns the default internal `octaveShift` for a new track.
    /// The UI uses this as the reference where the octave control displays `Oct 0`.
    /// Internal formula: semitoneShift = (octaveShift − 2) × 12
    static func defaultOctaveShift(
        for instrument: StudioInstrument,
        variant: InstrumentVariant? = nil
    ) -> Int {
        switch instrument {

        case .synth:
            return 0

        case .guitar:
            switch variant {
            case .acousticNylonGuitar:
                return 4
            case .acousticSteelGuitar:
                return 1
            default:
                return 2
            }

        case .bass:
            switch variant {
            case .fingerBass:
                return 0
            case .synthBass:
                return 1
            default:
                return 2
            }

        case .strings:
            switch variant {
            case .stringEnsemble, .synthStrings1, .synthStrings2:
                return 1
            default:
                return 2
            }

        case .woodwinds:
            switch variant {
            case .clarinet:
                return 1
            default:
                return 2
            }

        default:
            // The base ranges already encode the instrument's natural concert register.
            return 2
        }
    }

    /// Returns the allowed range of `octaveShift` values for a given instrument/variant.
    /// Display octave = octaveShift − defaultOctaveShift(for:variant:)
    /// Internal formula: semitoneShift = (octaveShift − 2) × 12
    static func allowedOctaveShiftRange(
        for instrument: StudioInstrument,
        variant: InstrumentVariant? = nil
    ) -> ClosedRange<Int> {
        switch instrument {
        case .drums, .audio:
            return 2...2   // Fixed – no octave shift for drums or audio tracks

        case .guitar:
            switch variant {
            case .acousticNylonGuitar:
                return 3...5
            case .acousticSteelGuitar:
                return 0...2
            default:
                return 1...3
            }

        case .piano:
            return 0...4

        case .bass:
            switch variant {
            case .fingerBass:
                return -1...1
            case .synthBass:
                return 0...2
            default:
                return 2...3
            }

        case .synth:
            return -1...2

        case .organ:
            return 0...4

        case .strings:
            switch variant {
            case .stringEnsemble, .synthStrings1, .synthStrings2:
                return 0...3
            default:
                return 1...4
            }

        case .brass:
            return 1...3   // −1 to +1 octave (physical instrument limits)

        case .woodwinds:
            switch variant {
            case .clarinet:
                return 0...2
            default:
                return 1...3
            }

        case .mallets:
            if let variant {
                switch variant {
                case .glockenspiel:
                    return 1...2   // Already very high; only Oct 0/+1 above neutral
                case .xylophone, .marimba, .vibraphone, .tubularBells,
                     .dulcimer, .kalimba, .musicBox:
                    return 1...3
                default:
                    break
                }
            }
            return 1...4
        }
    }

    /// Recomputes the internal octave shift when the variant changes while preserving the
    /// user-facing octave offset shown in the UI (`Oct -1`, `Oct 0`, `Oct +1`, etc.).
    static func remapOctaveShiftPreservingDisplayOffset(
        _ currentShift: Int,
        for instrument: StudioInstrument,
        oldVariant: InstrumentVariant?,
        newVariant: InstrumentVariant?
    ) -> Int {
        let oldDefault = defaultOctaveShift(for: instrument, variant: oldVariant)
        let newDefault = defaultOctaveShift(for: instrument, variant: newVariant)
        let displayOffset = currentShift - oldDefault
        let target = newDefault + displayOffset
        let allowed = allowedOctaveShiftRange(for: instrument, variant: newVariant)
        return min(allowed.upperBound, max(allowed.lowerBound, target))
    }

    static func supportsArpeggio(
        instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle?
    ) -> Bool {
        guard instrument != .drums && instrument != .audio && instrument != .bass else { return false }
        guard let style else { return true }
        let profile = chordVoicingProfile(for: instrument, variant: variant, style: style)
        if profile.monophonic { return false }
        if let maxNotes = profile.maxNotes, maxNotes <= 1 { return false }
        return true
    }

    private static func baseInstrumentRange(for instrument: StudioInstrument, variant: InstrumentVariant? = nil) -> ClosedRange<Int> {
        // Variant-specific overrides
        if let variant {
            switch variant {
            // Piano/Keyboard — variant-specific ranges
            case .clavinet:      return 41...64  // F2 to E4 (Clavinet D6 real range)
            case .harpsichord:   return 29...89  // F1 to A6 (standard harpsichord)
            case .harp:          return 24...103 // C1 to G7 (concert harp full range)
            // Woodwinds — realistic per-instrument ranges
            case .sopranoSax:    return 56...76
            case .altoSax:       return 49...69
            case .tenorSax:      return 44...64
            case .flute:         return 60...84
            case .clarinet:      return 50...82
            case .oboe:          return 58...81
            case .bassoon:       return 34...63
            // Brass — realistic per-instrument ranges
            case .trumpet:       return 55...82
            case .trombone:      return 40...67
            case .frenchHorn:    return 34...72
            case .tuba:          return 29...55
            case .brassSection:  return 42...72
            case .synthBrass1, .synthBrass2: return 48...67
            case .mutedTrumpet:  return 55...79
            // Mallets — realistic per-instrument ranges
            case .marimba:      return 35...84  // B1 to C6 (bass marimba register)
            case .vibraphone:   return 53...89  // F3 to F6 (full jazz vibraphone)
            case .xylophone:    return 65...96  // F4 to C7 (bright upper register)
            case .glockenspiel: return 79...108 // G5 to high register (orchestral sparkle)
            case .tubularBells: return 60...79  // C4 to G5 (concert tubular bells)
            case .musicBox:     return 60...84  // C4 to C6 (delicate mid-high range)
            case .dulcimer:     return 36...72  // C2 to C5 (mountain dulcimer)
            case .kalimba:      return 52...81  // E3 to A5 (17-key kalimba)
            // Guitar — realistic per-instrument ranges
            case .acousticNylonGuitar:              return 52...76  // E3 to E5 (classical guitar practical chord range – avoids low-sample artifacts)
            case .acousticSteelGuitar:              return 40...76  // E2 to E5 (acoustic guitar)
            case .electricGuitar, .cleanGuitar, .jazzGuitar: return 40...79  // E2 to G5
            case .mutedGuitar:                      return 40...71  // E2 to B4 (rhythm range)
            case .overdriveGuitar, .distortionGuitar: return 40...84  // E2 to C6
            case .harmonicsGuitar:                  return 52...88  // E3 to E6 (artificial harmonics)
            default: break
            }
        }
        switch instrument {
        case .piano:
            return 36...84  // C2 to C6 (full range)
        case .synth:
            return 52...88  // E3 to E6
        case .guitar:
            return 40...76  // E2 to E5 (low E string to high E)
        case .bass:
            return 28...52  // E1 to E3
        case .strings:
            return 36...84  // C2 to C6 (divisi range: cello to violin)
        case .brass:
            return 48...76  // C3 to E5
        case .woodwinds:
            return 52...84  // E3 to C6
        case .organ:
            return 40...84  // E2 to C6
        case .mallets:
            return 60...96  // C4 to C7
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
            return 0
        case .lofi:
            // Only push piano/synth lower; strings at -12 drops below cello (C1 = MIDI 24)
            if instrument == .piano || instrument == .synth {
                return -12
            }
            return 0
        case .edm:
            return instrument == .synth ? 12 : 0
        case .jazz:
            // Only piano shifts up; brass +12 pushes trumpet to Bb6+ (above physical limit)
            return instrument == .piano ? 12 : 0
        case .hiphop:
            // Bass is already at E1 (MIDI 28); -12 drops to E0 (MIDI 16), out of soundfont range
            return instrument == .synth ? -12 : 0
        case .funk:
            // Bass sits naturally at E1-E3 for funk; no downward shift needed
            return 0
        case .ambient:
            if instrument == .synth || instrument == .strings || instrument == .organ {
                return 12
            }
            return instrument == .piano ? 12 : 0
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
        variant: InstrumentVariant? = nil,
        style: StudioStyle,
        octaveShift: Int
    ) -> ClosedRange<Int> {
        instrumentRange(for: instrument, variant: variant, style: style, octaveShift: octaveShift)
    }

    private static func bassRange(variant: InstrumentVariant? = nil, style: StudioStyle, octaveShift: Int) -> ClosedRange<Int> {
        instrumentRange(for: .bass, variant: variant, style: style, octaveShift: octaveShift)
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
        guard let minP = pitches.min(), let maxP = pitches.max() else { return pitches }
        var shift = 0
        var currentMax = maxP
        var currentMin = minP
        while currentMax > range.upperBound {
            shift -= 12
            currentMax -= 12
            currentMin -= 12
        }
        while currentMin < range.lowerBound {
            shift += 12
            currentMin += 12
            currentMax += 12
        }
        if shift == 0 { return pitches }
        return pitches.map { $0 + shift }
    }

    private static func chordIntervals(for chord: ChordEvent) -> [Int] {
        simpleIntervals(for: chord.quality)
    }

    private static func chordVelocity(for instrument: StudioInstrument, style: StudioStyle) -> Int {
        // More nuanced velocities based on instrument AND style
        switch (style, instrument) {
        // Pop - balanced, clean
        case (.pop, .piano): return 90
        case (.pop, .guitar): return 82
        case (.pop, .synth): return 75
            
        // Rock - aggressive, loud
        case (.rock, .guitar): return 95
        case (.rock, .piano): return 92
        case (.rock, .synth): return 85
            
        // Lo-Fi - soft, mellow
        case (.lofi, .piano): return 70
        case (.lofi, .guitar): return 65
        case (.lofi, .synth): return 60
            
        // EDM - punchy, energetic
        case (.edm, .synth): return 100
        case (.edm, .piano): return 90
        case (.edm, .guitar): return 85
            
        // Jazz - subtle, dynamic
        case (.jazz, .piano): return 75
        case (.jazz, .guitar): return 70
        case (.jazz, .synth): return 65
            
        // Hip-Hop - moderate, groovy
        case (.hiphop, .piano): return 85
        case (.hiphop, .synth): return 80
        case (.hiphop, .guitar): return 75
            
        // Funk - percussive, rhythmic
        case (.funk, .guitar): return 95
        case (.funk, .piano): return 92
        case (.funk, .synth): return 85
            
        // Ambient - very soft, atmospheric
        case (.ambient, .synth): return 55
        case (.ambient, .piano): return 60
        case (.ambient, .guitar): return 58
            
        default: return 80
        }
    }

    private struct ChordVoicingProfile {
        var maxNotes: Int?
        var omitThird: Bool
        var preferOpenVoicing: Bool
        var extensionBias: Double
        var durationScale: Double
        var monophonic: Bool
        var allowOctaveDoubling: Bool
    }

    private struct BassVoicingProfile {
        var durationScale: Double
        var velocityOffset: Int
        var syncopationBoost: Bool
        var useOctaveJump: Bool
    }

    private static func chordVoicingProfile(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle
    ) -> ChordVoicingProfile {
        var profile = ChordVoicingProfile(
            maxNotes: nil,
            omitThird: false,
            preferOpenVoicing: instrument == .strings || instrument == .organ,
            extensionBias: 0,
            durationScale: 1,
            monophonic: instrument == .woodwinds,
            allowOctaveDoubling: true
        )

        switch instrument {
        case .piano:
            profile.maxNotes = 4
        case .synth:
            profile.maxNotes = 4
            profile.preferOpenVoicing = true
        case .guitar:
            profile.maxNotes = 6
            profile.preferOpenVoicing = true
        case .strings:
            profile.maxNotes = 4
            profile.preferOpenVoicing = true
        case .brass:
            profile.maxNotes = 3
        case .woodwinds:
            profile.maxNotes = 1
        case .organ:
            profile.maxNotes = 4
            profile.preferOpenVoicing = true
        case .mallets:
            profile.maxNotes = 2
            profile.durationScale = 0.7
        case .bass, .drums, .audio:
            break
        }

        if let variant {
            switch variant {
            case .brightPiano:
                profile.extensionBias = 0.1
            case .electricPiano, .electricPiano2:
                profile.extensionBias = 0.15
                profile.preferOpenVoicing = true
            case .honkyTonkPiano, .harpsichord, .clavinet:
                profile.maxNotes = 2
                profile.durationScale = 0.6
                profile.extensionBias = -0.2
            case .harp:
                profile.maxNotes = 3
                profile.preferOpenVoicing = true
                profile.allowOctaveDoubling = true
            case .leadSquare, .leadSaw, .leadCalliope, .leadChiff, .leadCharang, .leadVoice:
                profile.maxNotes = 1
                profile.monophonic = true
                profile.extensionBias = -0.2
            case .leadFifths:
                profile.maxNotes = 1
                profile.monophonic = true
                profile.omitThird = true
                profile.extensionBias = -0.2
            case .leadBass:
                profile.maxNotes = 2
                profile.omitThird = true
                profile.extensionBias = -0.2
            case .padNewAge, .padWarm, .padPolysynth, .padChoir, .padBowed, .padMetallic, .padHalo, .padSweep:
                profile.maxNotes = 4
                profile.preferOpenVoicing = true
                profile.extensionBias = 0.2
                profile.durationScale = 1.1
            case .acousticNylonGuitar, .acousticSteelGuitar:
                profile.maxNotes = 3
                profile.preferOpenVoicing = true
            case .electricGuitar, .cleanGuitar, .jazzGuitar:
                profile.maxNotes = 3
            case .mutedGuitar, .overdriveGuitar, .distortionGuitar:
                profile.maxNotes = 2
                profile.omitThird = true
                profile.durationScale = 0.7
                profile.allowOctaveDoubling = false
            case .harmonicsGuitar:
                profile.maxNotes = 2
                profile.durationScale = 0.5
                profile.allowOctaveDoubling = true
            case .tremoloStrings:
                profile.durationScale = 0.7
            case .pizzicatoStrings:
                profile.durationScale = 0.4
                profile.maxNotes = 2
            case .stringEnsemble, .slowStrings, .synthStrings1, .synthStrings2:
                profile.maxNotes = 4
                profile.preferOpenVoicing = true
                profile.extensionBias = 0.1
            case .choirAahs, .voiceOohs:
                profile.maxNotes = 3
                profile.preferOpenVoicing = true
                profile.extensionBias = 0.15
            case .trumpet, .trombone, .tuba, .mutedTrumpet, .frenchHorn:
                profile.maxNotes = 2
                profile.extensionBias = -0.1
            case .brassSection, .synthBrass1, .synthBrass2:
                profile.maxNotes = 4
                profile.extensionBias = 0.1
            case .drawbarOrgan, .rockOrgan, .churchOrgan, .reedOrgan:
                profile.maxNotes = 4
                profile.preferOpenVoicing = true
                profile.durationScale = 1.1
            case .percussiveOrgan:
                profile.maxNotes = 3
                profile.durationScale = 0.7
            case .accordion, .harmonica, .tangoAccordion:
                profile.maxNotes = 2
                profile.durationScale = 0.8
            case .celesta, .glockenspiel, .musicBox, .xylophone, .tubularBells:
                profile.maxNotes = 2
                profile.durationScale = 0.5
            case .vibraphone:
                profile.maxNotes = 4  // 2 mallets per hand → up to 4-note chords
                profile.durationScale = 0.75
                profile.preferOpenVoicing = true
                profile.extensionBias = 0.1  // Jazz vibraphone loves extensions
            case .marimba:
                profile.maxNotes = 4  // 2 mallets per hand → 4-note chords common
                profile.durationScale = 0.65
                profile.preferOpenVoicing = true
            case .dulcimer:
                profile.maxNotes = 2
                profile.durationScale = 0.6
                profile.preferOpenVoicing = false
            case .kalimba:
                profile.maxNotes = 2
                profile.durationScale = 0.55  // Short attack, fast decay
            default:
                break
            }
        }

        if style == .ambient, (instrument == .synth || instrument == .strings) {
            profile.durationScale = max(profile.durationScale, 1.2)
            profile.extensionBias += 0.1
        }

        return profile
    }

    private static func bassVoicingProfile(
        variant: InstrumentVariant?,
        style: StudioStyle
    ) -> BassVoicingProfile {
        var profile = BassVoicingProfile(
            durationScale: 1,
            velocityOffset: 0,
            syncopationBoost: style == .funk,
            useOctaveJump: style == .edm
        )

        if let variant {
            switch variant {
            case .slapBass1, .slapBass2:
                profile.velocityOffset = 8
                profile.durationScale = 0.7
                profile.syncopationBoost = true
                profile.useOctaveJump = true
            case .pickBass:
                profile.velocityOffset = 6
                profile.durationScale = 0.85
            case .fretlessBass:
                profile.velocityOffset = -4
                profile.durationScale = 1.2
            case .synthBass, .synthBass2:
                profile.velocityOffset = 4
                profile.durationScale = 0.75
                profile.syncopationBoost = style == .edm || style == .hiphop
            case .acousticBass, .fingerBass:
                profile.durationScale = 1.0
            default:
                break
            }
        }

        return profile
    }

    private static func chordVelocityAdjustment(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle
    ) -> Int {
        guard let variant else { return 0 }
        switch variant {
        case .brightPiano:
            return 6
        case .electricPiano, .electricPiano2:
            return 2
        case .honkyTonkPiano, .harpsichord, .clavinet:
            return 4
        case .mutedGuitar:
            return -6
        case .overdriveGuitar, .distortionGuitar:
            return 8
        case .brassSection, .synthBrass1, .synthBrass2:
            return style == .rock ? 4 : -4
        case .tremoloStrings, .stringEnsemble, .slowStrings:
            return -8
        case .synthStrings1, .synthStrings2:
            return -4
        case .clarinet:
            return -6
        case .flute, .piccolo:
            return -4
        case .vibraphone, .marimba:
            return -4
        default:
            return 0
        }
    }

    private static func openVoicing(_ pitches: [Int]) -> [Int] {
        guard pitches.count >= 3 else { return pitches }
        let sorted = pitches.sorted()
        let root = sorted[0]
        let third = sorted[1]
        let fifth = sorted[2]
        let rest = sorted.dropFirst(3).map { $0 + 12 }
        let voicing = [root, fifth, third + 12] + rest
        return voicing.sorted()
    }

    /// Divisi spacing for strings: cello (36-60), viola (55-72), violin (60-84)
    /// Ensures minimum P5 (7 semitones) spacing below C4 (60).
    private static func divisiSpacing(_ pitches: [Int], range: ClosedRange<Int>) -> [Int] {
        var sorted = pitches.sorted()
        // Place lowest note in cello register
        if sorted[0] > 55 { sorted[0] = sorted[0] - 12 }
        // Ensure at least P5 spacing between lower voices
        for i in 1..<sorted.count {
            if sorted[i] < 60, sorted[i] - sorted[i-1] < 7 {
                sorted[i] = sorted[i-1] + 7
            }
        }
        // Keep highest voice in violin register
        if let last = sorted.last, last < 60, sorted.count >= 3 {
            sorted[sorted.count - 1] = last + 12
        }
        return sorted.filter { range.contains($0) }
    }

    /// Drop-2 voicing for brass: move the 2nd-highest note down an octave.
    private static func drop2Voicing(_ pitches: [Int], range: ClosedRange<Int>) -> [Int] {
        var sorted = pitches.sorted()
        let dropIndex = sorted.count - 2
        let dropped = sorted[dropIndex] - 12
        if dropped >= range.lowerBound {
            sorted[dropIndex] = dropped
        }
        return sorted.sorted()
    }

    /// Instrument-family articulation: how much of the beat the note should fill.
    /// 1.0 = full legato, 0.5 = short staccato.
    private static func articulationScale(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle
    ) -> Double {
        // Variant overrides
        if let variant {
            switch variant {
            case .pizzicatoStrings:  return 0.35
            case .tremoloStrings:    return 0.90
            case .mutedTrumpet:      return 0.55
            case .mutedGuitar:       return 0.50
            case .distortionGuitar, .overdriveGuitar: return 0.65
            case .accordion, .harmonica, .tangoAccordion: return 0.90
            default: break
            }
        }
        switch instrument {
        case .strings:   return 0.95  // Legato
        case .brass:     return style == .jazz ? 0.55 : 0.60  // Marcato
        case .guitar:    return style == .funk ? 0.50 : 0.75  // Natural decay
        case .organ:     return 1.0   // Sustained
        case .mallets:   return 0.60  // Percussive decay
        case .woodwinds: return 0.85  // Breath phrase
        case .piano:     return style == .jazz ? 0.55 : 0.85
        case .synth:
            // Pads legato, leads shorter
            if let v = variant, [.padNewAge, .padWarm, .padPolysynth, .padChoir, .padBowed, .padMetallic, .padHalo, .padSweep].contains(v) {
                return 0.95
            }
            return 0.70
        case .bass:      return 0.70
        default:         return 0.80
        }
    }

    /// Style-aware velocity curve — applies non-linear scaling per instrument.
    private static func velocityCurve(base: Int, intensity: Double, instrument: StudioInstrument) -> Int {
        let t = max(0.0, min(1.0, intensity))
        let curved: Double
        switch instrument {
        case .brass:
            curved = pow(t, 1.5)  // Exponential — quiet until pushed
        case .piano:
            curved = pow(t, 0.7)  // Logarithmic — responsive at low levels
        case .strings:
            curved = t * 0.8 + 0.1  // Compressed — always moderate
        case .woodwinds:
            curved = pow(t, 0.8)  // Slightly logarithmic
        default:
            curved = t  // Linear
        }
        let velocity = 40.0 + curved * 87.0
        return Int(max(30, min(127, velocity)))
    }

    private static func scaledVelocity(base: Int, intensity: Double, range: Int) -> Int {
        let clamped = max(0.0, min(1.0, intensity))
        let offset = (clamped - 0.5) * Double(range)
        let adjusted = Double(base) + offset
        return Int(max(30, min(127, adjusted)))
    }

    private static func chordHitOffsets(
        instrument: StudioInstrument,
        style: StudioStyle,
        beatsPerBar: Int,
        timeBottom: Int,
        chordDuration: Double,
        intensity: Double = 0.5,
        complexity: Double = 0.5
    ) -> [Double] {
        let midBeat = Double(max(1, beatsPerBar / 2))
        let beatStride = timeBottom == 8 ? midBeat : 1.0
        let offbeat = timeBottom == 8 ? midBeat : 0.5
        let quantStep = timeBottom == 8 ? 1.0 : 0.5

        var offsets: [Double] = []
        switch style {
        case .lofi:
            // All instruments: sustained, minimal hits
            offsets = [0]
            
        case .pop:
            // Piano/Guitar: on-beat with half-beat accents
            // Synth: sustained pads
            if instrument == .synth {
                offsets = [0]
            } else {
                offsets = [0]
                if chordDuration >= midBeat + 0.25 {
                    offsets.append(midBeat)
                }
            }
            
        case .rock:
            // Guitar: driving rhythm, frequent hits
            // Piano: solid quarter notes
            // Synth: sustained
            if instrument == .guitar {
                offsets = stride(from: 0, to: chordDuration, by: beatStride).map { $0 }
            } else if instrument == .piano {
                offsets = [0]
                if chordDuration >= 1.0 {
                    offsets.append(1.0)
                }
            } else {
                offsets = [0]
            }
            
        case .edm:
            // Synth: offbeat stabs
            // Piano: quarter notes
            // Guitar: sustained
            if instrument == .synth {
                offsets = stride(from: offbeat, to: chordDuration, by: beatStride).map { $0 }
                if offsets.isEmpty {
                    offsets = [0]
                }
            } else if instrument == .piano {
                offsets = stride(from: 0, to: chordDuration, by: 1.0).map { $0 }
            } else {
                offsets = [0]
            }
            
        case .jazz:
            // All instruments: swing feel
            // Piano: walking comp pattern
            // Guitar: light swing
            if instrument == .piano {
                offsets = [0]
                if chordDuration >= 2.0 {
                    offsets.append(0.75)
                    offsets.append(2.0)
                } else if chordDuration >= 1.0 {
                    offsets.append(0.75)
                }
            } else if instrument == .guitar {
                offsets = [0]
                if chordDuration >= 1.5 {
                    offsets.append(0.75)
                }
            } else {
                offsets = [0]
            }
            
        case .hiphop:
            // Piano/Synth: sparse, on downbeats
            // Guitar: minimal
            if instrument == .piano || instrument == .synth {
                offsets = [0]
                if chordDuration >= 2.0 {
                    offsets.append(2.0)
                }
            } else {
                offsets = [0]
            }
            
        case .funk:
            // Guitar: syncopated 16th note rhythms
            // Piano: percussive stabs
            // Synth: sustained
            if instrument == .guitar {
                offsets = stride(from: 0, to: chordDuration, by: 0.5).map { $0 }
            } else if instrument == .piano {
                offsets = [0]
                if chordDuration >= 1.0 {
                    offsets.append(0.5)
                    if chordDuration >= 2.0 {
                        offsets.append(1.5)
                    }
                }
            } else {
                offsets = [0]
            }
            
        case .ambient:
            // All instruments: sustained, minimal movement
            offsets = [0]
        }

        let intensityClamped = max(0.0, min(1.0, intensity))
        if intensityClamped < 0.3 {
            offsets = [0]
        } else if intensityClamped > 0.7 {
            let microStep = timeBottom == 8 ? 0.5 : 0.25
            let syncopated = timeBottom == 8 ? 1.0 : 0.5
            switch style {
            case .funk:
                if instrument == .guitar {
                    offsets.append(contentsOf: stride(from: microStep, to: chordDuration, by: 0.5))
                }
            case .rock:
                if instrument == .guitar {
                    offsets.append(contentsOf: stride(from: 0, to: chordDuration, by: beatStride))
                }
            case .pop:
                if instrument == .piano || instrument == .guitar {
                    offsets.append(syncopated)
                }
            case .edm:
                if instrument == .synth {
                    offsets.append(syncopated)
                }
            default:
                if instrument == .piano {
                    offsets.append(syncopated)
                }
            }
        }

        if instrument == .guitar {
            offsets = offsets.filter { abs($0.rounded() - $0) < 0.001 }
            if offsets.isEmpty {
                offsets = [0]
            }
        }

        let clamped = offsets
            .filter { $0 >= 0 && $0 < chordDuration }
            .map { quantize($0, step: quantStep) }
        
        let sorted = uniqueSorted(clamped)
        
        // Apply complexity: lower complexity = fewer hits
        // Complexity 0.0 = only first hit
        // Complexity 0.5 = half the hits
        // Complexity 1.0 = all hits
        let numHitsToKeep = max(1, Int(Double(sorted.count) * complexity))
        return Array(sorted.prefix(numHitsToKeep))
    }

    private static func chordHitDuration(
        instrument: StudioInstrument,
        variant: InstrumentVariant? = nil,
        style: StudioStyle,
        timeBottom: Int,
        baseDuration: Double,
        offset: Double,
        durationScale: Double
    ) -> Double {
        let remaining = max(0.25, baseDuration - offset)
        let shortHit = timeBottom == 8 ? 1.0 : 0.5

        var baseDurationValue = remaining
        switch style {
        case .lofi:
            // All sustained
            baseDurationValue = remaining
            
        case .pop:
            if instrument == .synth {
                baseDurationValue = remaining
            } else if instrument == .piano {
                baseDurationValue = min(remaining, 1.5)
            } else if instrument == .guitar {
                baseDurationValue = min(remaining, 1.0)
            }
            baseDurationValue = min(remaining, 1.5)
            
        case .rock:
            if instrument == .guitar {
                baseDurationValue = min(remaining, 0.75) // Short, punchy
            } else if instrument == .piano {
                baseDurationValue = min(remaining, 1.0)
            }
            baseDurationValue = min(remaining, 1.25)
            
        case .edm:
            if instrument == .synth {
                baseDurationValue = min(remaining, shortHit) // Stabs
            } else if instrument == .piano {
                baseDurationValue = min(remaining, 0.75)
            }
            baseDurationValue = min(remaining, 1.0)
            
        case .jazz:
            // Medium-short for comp feel
            if instrument == .piano {
                baseDurationValue = min(remaining, 0.5)
            } else if instrument == .guitar {
                baseDurationValue = min(remaining, 0.75)
            }
            baseDurationValue = min(remaining, 0.75)
            
        case .hiphop:
            // Long, sustained
            if instrument == .piano || instrument == .synth {
                baseDurationValue = remaining
            }
            baseDurationValue = remaining
            
        case .funk:
            if instrument == .guitar {
                baseDurationValue = min(remaining, 0.5) // Short, percussive
            } else if instrument == .piano {
                baseDurationValue = min(remaining, 0.25) // Very short stabs
            }
            baseDurationValue = min(remaining, 1.0)
            
        case .ambient:
            // Everything sustained
            baseDurationValue = remaining
        }

        let scaled = baseDurationValue * durationScale
        let articulation = articulationScale(for: instrument, variant: variant, style: style)
        return min(remaining, max(0.25, scaled * articulation))
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
        case .jazz:
            return 0.75
        case .hiphop:
            return 1.5
        case .funk:
            return 0.5
        case .ambient:
            return 4.0
        }
    }

    private static func bassVelocity(for style: StudioStyle) -> Int {
        switch style {
        case .lofi:
            return 65
        case .pop:
            return 80
        case .rock:
            return 95
        case .edm:
            return 100
        case .jazz:
            return 70
        case .hiphop:
            return 105
        case .funk:
            return 90
        case .ambient:
            return 60
        }
    }

    private static func fitPitch(_ pitch: Int, in range: ClosedRange<Int>) -> Int {
        fitPitches([pitch], in: range).first ?? pitch
    }

    private static func quantize(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private static func simpleIntervals(
        for quality: ChordQuality,
        omitThird: Bool = false
    ) -> [Int] {
        // Use the intervals property from ChordQuality directly
        // But for backward compatibility with the pattern generation, only use triads
        let intervals: [Int]
        switch quality {
        case .major, .sixth: intervals = [0, 4, 7]
        case .minor, .minorSixth: intervals = [0, 3, 7]
        case .diminished: intervals = [0, 3, 6]
        case .augmented: intervals = [0, 4, 8]
        case .power: intervals = [0, 7]
        case .dominant7, .dominant7sus4, .dominant7sharp9, .dominant7flat9, .dominant7sharp11, .altered:
            intervals = [0, 4, 7]
        case .major7: intervals = [0, 4, 7]
        case .minor7: intervals = [0, 3, 7]
        case .minorMajor7: intervals = [0, 3, 7]
        case .diminished7: intervals = [0, 3, 6]
        case .halfDiminished7: intervals = [0, 3, 6]
        case .augmented7: intervals = [0, 4, 8]
        case .sus2: intervals = [0, 2, 7]
        case .sus4: intervals = [0, 5, 7]
        case .dominant9, .major9, .add9: intervals = [0, 4, 7]
        case .minor9: intervals = [0, 3, 7]
        case .dominant11, .major11, .add11: intervals = [0, 4, 7]
        case .minor11: intervals = [0, 3, 7]
        case .dominant13, .major13: intervals = [0, 4, 7]
        case .minor13: intervals = [0, 3, 7]
        }
        if omitThird {
            return intervals.filter { $0 != 3 && $0 != 4 && $0 != 5 }
        }
        return intervals
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
        let hatClosed: [Int]
        let hatOpen: [Int]
        let clap: [Int]
        let rim: [Int]
        let tomLow: [Int]
        let tomMid: [Int]
        let tomHigh: [Int]
        let ride: [Int]
        let crash: [Int]
        let perc: [Int]
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
        case .shuffle:
            let shuffleKicks = basicKickOffsets(meter: meter) + offbeatOffsets.filter { $0 < Double(meter.beatsPerBar) }
            kickOffsets = uniqueSorted(shuffleKicks)
            snareOffsets = backbeatOffsets.isEmpty ? [Double(max(1, meter.beatsPerBar - 1))] : backbeatOffsets
            hatSteps = stepsFromOffsets(
                beatOffsets + offbeatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = meter.timeBottom == 4 ? snareOffsets : []
        case .swing:
            kickOffsets = pulseOffsets
            snareOffsets = backbeatOffsets
            hatSteps = stepsFromOffsets(
                beatOffsets + offbeatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = []
        case .trap:
            let trapKicks = [0.0, 1.5, 2.5].filter { $0 < Double(meter.beatsPerBar) }
            kickOffsets = meter.timeBottom == 4 ? trapKicks : pulseOffsets
            snareOffsets = [Double(max(1, meter.beatsPerBar / 2))]
            hatSteps = Array(0..<stepsPerBar)
            clapOffsets = snareOffsets
        case .breakbeat:
            let breakKicks = [0.0, 1.5, 2.5].filter { $0 < Double(meter.beatsPerBar) }
            kickOffsets = meter.timeBottom == 4 ? breakKicks : pulseOffsets
            snareOffsets = backbeatOffsets.isEmpty ? [Double(max(1, meter.beatsPerBar - 1))] : backbeatOffsets
            hatSteps = stepsFromOffsets(
                beatOffsets + offbeatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = snareOffsets
        case .bossa:
            let bossaKick = [0.0, 2.0].filter { $0 < Double(meter.beatsPerBar) }
            kickOffsets = meter.timeBottom == 4 ? bossaKick : pulseOffsets
            snareOffsets = offbeatOffsets
            hatSteps = stepsFromOffsets(
                beatOffsets,
                stepsPerBeat: stepsPerBeat,
                stepsPerBar: stepsPerBar
            )
            clapOffsets = []
        case .latin:
            let latinKick = [0.0, 1.5, 2.0, 3.5].filter { $0 < Double(meter.beatsPerBar) }
            kickOffsets = meter.timeBottom == 4 ? latinKick : pulseOffsets
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
            kick: uniqueSorted(kickSteps),
            snare: uniqueSorted(snareSteps),
            hatClosed: uniqueSorted(hatSteps),
            hatOpen: [],
            clap: uniqueSorted(clapSteps),
            rim: [],
            tomLow: [],
            tomMid: [],
            tomHigh: [],
            ride: [],
            crash: [],
            perc: []
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
