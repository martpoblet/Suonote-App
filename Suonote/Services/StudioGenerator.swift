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

    /// Describes the full set of instruments in an arrangement so each
    /// instrument can place its notes in a coordinated register and thin its
    /// voicing — instead of every instrument independently piling chords into
    /// the same mid register (the cause of "no harmony between instruments").
    struct ArrangementContext {
        let instruments: Set<StudioInstrument>

        /// No coordination context — the instrument fills its full natural
        /// role (e.g. a lone piano covers both hands and the low end).
        static let solo = ArrangementContext(instruments: [])

        var hasBass: Bool { instruments.contains(.bass) }

        /// Chord-playing instruments competing for the harmonic mid register.
        var harmonicCount: Int {
            instruments.filter { ![.bass, .drums, .audio].contains($0) }.count
        }

        /// MIDI floor for non-bass instruments when a dedicated bass is present,
        /// keeping the low end clear for the bass.
        var lowEndFloor: Int? { hasBass ? 48 : nil } // C3

        var hasPiano: Bool { instruments.contains(.piano) }
        var hasGuitar: Bool { instruments.contains(.guitar) }
        var hasStrings: Bool { instruments.contains(.strings) }
        var hasSynth: Bool { instruments.contains(.synth) }
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
            // Same section vocabulary as the arranger (English + Spanish names).
            // The arranger already thins/builds the band, so velocity only
            // shapes the contour gently.
            let role = StudioArranger.Role.from(name: item.labelOverride?.isEmpty == false ? item.labelOverride! : section.name)
            let (velScale, densScale): (Float, Float)
            switch role {
            case .intro: (velScale, densScale) = (0.86, 0.8)
            case .verse: (velScale, densScale) = (0.9, 0.9)
            case .preChorus: (velScale, densScale) = (0.97, 1.0)
            case .chorus: (velScale, densScale) = (1.08, 1.15)
            case .postChorus: (velScale, densScale) = (1.02, 1.05)
            case .bridge: (velScale, densScale) = (0.86, 0.85)
            case .breakdown: (velScale, densScale) = (0.8, 0.75)
            case .solo: (velScale, densScale) = (1.0, 0.95)
            case .outro: (velScale, densScale) = (0.84, 0.8)
            case .other: (velScale, densScale) = (1.0, 1.0)
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
        let arrangement = ArrangementContext(instruments: Set(instruments))

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
            track.octaveShift = initialOctaveShift(for: instrument, variant: track.variant)
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
                keyMode: project.keyMode,
                diatonicMap: diatonicMap,
                intensity: track.regenerateIntensity,
                complexity: track.regenerateComplexity,
                naturalness: track.regenerateNaturalness,
                arpeggioEnabled: track.regenerateArpeggioEnabled,
                arpeggioRate: track.regenerateArpeggioRate,
                arpeggioPattern: track.regenerateArpeggioPattern,
                compingPattern: track.compingPattern,
                bassPattern: track.bassPattern,
                sectionBoundaryBars: sectionBounds,
                arrangement: arrangement
            )
            let arranged = StudioArranger.arrange(notes, instrument: instrument, variant: track.variant, project: project, style: style)
            applySectionDynamics(arranged, dynamics: dynamics)
            for note in arranged {
                note.track = track
                track.notes.append(note)
                modelContext.insert(note)
            }

            tracks.append(track)
        }

        return tracks
    }

    /// Everything regeneration needs that depends on the whole song, computed once.
    private struct RegenerationContext {
        let timeline: (chords: [ChordSpan], totalBars: Int)
        let diatonicMap: [String: ChordQuality]
        let sectionBounds: Set<Int>
        let dynamics: [SectionDynamic]
        let defaultDrumPreset: DrumPreset
        let arrangement: ArrangementContext

        init(project: Project, style: StudioStyle) {
            timeline = StudioGenerator.buildTimeline(for: project)
            diatonicMap = StudioGenerator.diatonicQualityMap(forKey: project.keyRoot, mode: project.keyMode)
            sectionBounds = StudioGenerator.sectionStartBars(for: project)
            dynamics = StudioGenerator.sectionDynamics(for: project)
            defaultDrumPreset = DrumPreset.defaultPreset(
                for: style,
                beatsPerBar: project.timeTop,
                timeBottom: project.timeBottom
            )
            arrangement = ArrangementContext(
                instruments: Set(project.studioTracks.filter { !$0.instrument.isAudio }.map(\.instrument))
            )
        }
    }

    static func regenerateNotes(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext,
        resetDrumPreset: Bool = false,
        includeDrums: Bool = true
    ) {
        let context = RegenerationContext(project: project, style: style)
        for track in project.studioTracks where !track.instrument.isAudio {
            if track.instrument == .drums, !includeDrums {
                continue
            }
            regenerate(track, project: project, style: style, context: context,
                       modelContext: modelContext, resetDrumPreset: resetDrumPreset)
        }
    }

    /// Rewrites a single track's part with the same song-aware rules as a
    /// full regeneration (section dynamics, section boundaries, and awareness
    /// of the other instruments in the arrangement).
    static func regenerateTrack(
        _ track: StudioTrack,
        project: Project,
        style: StudioStyle,
        modelContext: ModelContext,
        resetDrumPreset: Bool = false
    ) {
        guard !track.instrument.isAudio else { return }
        let context = RegenerationContext(project: project, style: style)
        regenerate(track, project: project, style: style, context: context,
                   modelContext: modelContext, resetDrumPreset: resetDrumPreset)
    }

    private static func regenerate(
        _ track: StudioTrack,
        project: Project,
        style: StudioStyle,
        context: RegenerationContext,
        modelContext: ModelContext,
        resetDrumPreset: Bool
    ) {
        for note in track.notes {
            modelContext.delete(note)
        }
        track.notes.removeAll()

        let activeDrumPreset: DrumPreset?
        if track.instrument == .drums {
            let preset = resetDrumPreset ? context.defaultDrumPreset : (track.drumPreset ?? context.defaultDrumPreset)
            track.drumPreset = preset
            activeDrumPreset = preset
        } else {
            activeDrumPreset = nil
        }

        let notes = notesForInstrument(
            track.instrument,
            chords: context.timeline.chords,
            totalBars: context.timeline.totalBars,
            beatsPerBar: project.timeTop,
            timeBottom: project.timeBottom,
            style: style,
            drumPreset: activeDrumPreset,
            variant: track.variant,
            octaveShift: track.octaveShift,
            keyRoot: project.keyRoot,
            keyMode: project.keyMode,
            diatonicMap: context.diatonicMap,
            intensity: track.regenerateIntensity,
            complexity: track.regenerateComplexity,
            naturalness: track.regenerateNaturalness,
            arpeggioEnabled: track.regenerateArpeggioEnabled,
            arpeggioRate: track.regenerateArpeggioRate,
            arpeggioPattern: track.regenerateArpeggioPattern,
            compingPattern: track.compingPattern,
            bassPattern: track.bassPattern,
            sectionBoundaryBars: context.sectionBounds,
            arrangement: context.arrangement
        )
        let arranged = track.followsArrangement
            ? StudioArranger.arrange(notes, instrument: track.instrument, variant: track.variant, project: project, style: style)
            : notes
        applySectionDynamics(arranged, dynamics: context.dynamics)
        for note in arranged {
            note.track = track
            track.notes.append(note)
            modelContext.insert(note)
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
                    naturalness: track.regenerateNaturalness,
                    style: style
                )
                var newNotes = naturalDrums.filter { $0.startBeat >= previousTotalBeats }
                if track.followsArrangement {
                    newNotes = StudioArranger.arrange(
                        newNotes, instrument: .drums, variant: track.variant, project: project, style: style,
                        limit: previousTotalBeats...Double.greatestFiniteMagnitude
                    )
                }
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
                keyMode: project.keyMode,
                diatonicMap: diatonicMap,
                intensity: track.regenerateIntensity,
                complexity: track.regenerateComplexity,
                naturalness: track.regenerateNaturalness,
                arpeggioEnabled: track.regenerateArpeggioEnabled,
                arpeggioRate: track.regenerateArpeggioRate,
                arpeggioPattern: track.regenerateArpeggioPattern,
                compingPattern: track.compingPattern,
                bassPattern: track.bassPattern
            )
            var newNotes = notes.filter { note in
                let beat = note.startBeat
                // Binary search: find first range where end > beat
                var lo = 0, hi = newChordRanges.count
                while lo < hi {
                    let mid = (lo + hi) / 2
                    if newChordRanges[mid].end <= beat { lo = mid + 1 } else { hi = mid }
                }
                return lo < newChordRanges.count && beat >= newChordRanges[lo].start && beat < newChordRanges[lo].end
            }
            if track.followsArrangement {
                newNotes = StudioArranger.arrange(newNotes, instrument: track.instrument, variant: track.variant, project: project, style: style)
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
                keyMode: project.keyMode,
                diatonicMap: diatonicMap,
                intensity: track.regenerateIntensity,
                complexity: track.regenerateComplexity,
                naturalness: track.regenerateNaturalness,
                arpeggioEnabled: track.regenerateArpeggioEnabled,
                arpeggioRate: track.regenerateArpeggioRate,
                arpeggioPattern: track.regenerateArpeggioPattern,
                compingPattern: track.compingPattern,
                bassPattern: track.bassPattern
            )
            let arranged = track.followsArrangement
                ? StudioArranger.arrange(notes, instrument: track.instrument, variant: track.variant, project: project, style: style)
                : notes
            didChange = appendNotes(arranged, to: track, modelContext: modelContext) || didChange
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
        arpeggioPattern: String = "up",
        compingPattern: CompingPattern = .auto,
        bassPattern: BassPattern = .auto,
        arrangement: ArrangementContext = .solo,
        followsArrangement: Bool = true
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
        let notes = notesForInstrument(
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
            keyMode: project.keyMode,
            diatonicMap: diatonicMap,
            intensity: intensity,
            complexity: complexity,
            naturalness: naturalness,
            arpeggioEnabled: arpeggioEnabled,
            arpeggioRate: arpeggioRate,
            arpeggioPattern: arpeggioPattern,
            compingPattern: compingPattern,
            bassPattern: bassPattern,
            arrangement: arrangement
        )
        guard followsArrangement else { return notes }
        let arranged = StudioArranger.arrange(notes, instrument: instrument, variant: variant, project: project, style: style)
        applySectionDynamics(arranged, dynamics: sectionDynamics(for: project))
        return arranged
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
        keyMode: KeyMode = .major,
        diatonicMap: [String: ChordQuality],
        intensity: Double = 0.5,
        complexity: Double = 0.5,
        naturalness: Double = 0.0,
        arpeggioEnabled: Bool = false,
        arpeggioRate: String = "1/8",
        arpeggioPattern: String = "up",
        compingPattern: CompingPattern = .auto,
        bassPattern: BassPattern = .auto,
        sectionBoundaryBars: Set<Int> = [],
        arrangement: ArrangementContext = .solo
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
                complexity: complexity,
                bassPattern: bassPattern
            )
        case .piano:
            // Piano plays as two hands: a low-register left-hand foundation
            // plus a mid/upper-register right-hand voicing.
            generated = pianoNotes(
                chords: chords,
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
                arpeggioPattern: arpeggioPattern,
                compingPattern: compingPattern,
                arrangement: arrangement
            )
        case .guitar, .synth, .strings, .brass, .woodwinds, .organ, .mallets:
            let profile = chordVoicingProfile(for: instrument, variant: variant, style: style)
            if profile.monophonic {
                // Lead instruments (woodwinds, synth leads) play a real melodic
                // line over the changes rather than one held chord tone.
                generated = melodyNotes(
                    chords: chords,
                    instrument: instrument,
                    variant: variant,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom,
                    style: style,
                    octaveShift: octaveShift,
                    keyRoot: keyRoot,
                    keyMode: keyMode,
                    diatonicMap: diatonicMap,
                    intensity: intensity,
                    complexity: complexity
                )
            } else {
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
                    arpeggioPattern: arpeggioPattern,
                    compingPattern: compingPattern,
                    arrangement: arrangement
                )
            }
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
            naturalness: naturalness,
            style: style
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
        arpeggioPattern: String = "up",
        compingPattern: CompingPattern = .auto,
        arrangement: ArrangementContext = .solo,
        rangeOverride: ClosedRange<Int>? = nil,
        noteCap: Int? = nil
    ) -> [StudioNote] {
        let voicingProfile = chordVoicingProfile(
            for: instrument,
            variant: variant,
            style: style
        )
        let effectiveComplexity = max(0.0, min(1.0, complexity + voicingProfile.extensionBias))

        // Resolve `.auto` to the instrument's recommended pattern, then derive
        // the concrete behaviour: a sustained pad, a broken-chord figure, or a
        // rhythmic block comp.
        let effectiveComping: CompingPattern = compingPattern == .auto
            ? recommendedComping(for: instrument, variant: variant, style: style)
            : compingPattern
        let isSustained = effectiveComping == .sustained
        let figure: AccompanimentPattern? = arpeggioEnabled ? nil : accompanimentFigure(for: effectiveComping)

        var range = rangeOverride ?? chordRange(for: instrument, variant: variant, style: style, octaveShift: octaveShift)
        // Keep the low end clear for a dedicated bass: lift harmonic instruments
        // out of the bass register so they don't muddy the foundation.
        if let floor = arrangement.lowEndFloor, instrument != .mallets {
            let lifted = max(range.lowerBound, floor)
            if lifted < range.upperBound {
                range = lifted...range.upperBound
            }
        }
        range = arrangementRoleRange(
            for: instrument,
            variant: variant,
            style: style,
            baseRange: range,
            arrangement: arrangement
        )
        // Thin voicings when many instruments share the harmony — fewer notes
        // per instrument keeps the combined texture clear instead of a wash.
        let densityCap: Int? = {
            switch arrangement.harmonicCount {
            case 0...3: return noteCap
            case 4: return min(noteCap ?? .max, 3)
            default: return min(noteCap ?? .max, 2)
            }
        }()
        let tonicTarget = anchorPitch(for: keyRoot, in: range)
        var lastCenter = tonicTarget
        var lastVoicing: [Int] = []
        var notes: [StudioNote] = []

        for span in chords {
            let rootClass = noteSemitone(for: span.chord.root)
            let rootPitch = nearestPitch(for: rootClass, in: range, near: lastCenter)
            let baseDuration = max(0.25, span.duration)
            let resolvedQuality = resolveQuality(
                for: span.chord,
                diatonicMap: diatonicMap
            )
            // Accurate chord tones from the real quality + the event's
            // extensions — this is what guarantees a m7 sounds like a m7,
            // a maj7 keeps its natural 7, a sus has no third, etc.
            let tones = harmonicTones(for: resolvedQuality, extensions: span.chord.extensions)
            var intervals: [Int]
            if voicingProfile.omitThird {
                // Power / fifth voicings — root + fifth only.
                intervals = [0, tones.fifth]
            } else {
                intervals = tones.essential + selectedTensions(
                    from: tones,
                    instrument: instrument,
                    variant: variant,
                    style: style,
                    complexity: effectiveComplexity
                )
            }
            var pitches = uniqueSorted(intervals).map { rootPitch + $0 }
            if intensity > 0.7, voicingProfile.allowOctaveDoubling, instrument != .guitar {
                pitches.append(rootPitch + 12)
            }
            pitches = uniqueSorted(pitches)
            pitches = fitPitches(pitches, in: range)

            // Jazz keyboards comp rootless — the bass / left hand owns the root,
            // freeing the 3rd, 7th and tensions to define the color.
            if style == .jazz, instrument == .piano || instrument == .organ, pitches.count >= 3 {
                pitches = fitPitches(rootlessVoicing(pitches, rootPitch: rootPitch), in: range)
            }

            // Monophonic instruments: pick the chord tone nearest the previous
            // note for a smooth melodic line instead of always the top note.
            if instrument == .woodwinds || voicingProfile.monophonic {
                if let pitch = pitches.min(by: { abs($0 - lastCenter) < abs($1 - lastCenter) }) {
                    pitches = [pitch]
                }
            }

            // Simplify guitar voicings - complexity scales note count up to 6
            if instrument == .guitar {
                let maxNotes = complexity > 0.8 ? 6 : (complexity > 0.6 ? 5 : (complexity > 0.4 ? 4 : (complexity > 0.2 ? 3 : 2)))
                let cappedNotes = min(maxNotes, voicingProfile.maxNotes ?? maxNotes)
                pitches = trimVoicesHarmonic(pitches, rootPitch: rootPitch, keep: cappedNotes)
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

            // Octave-displacing voicings can overshoot the range — fold every
            // voice back in (never drop a chord tone).
            pitches = foldIntoRange(pitches, range)

            let effectiveMaxNotes = [voicingProfile.maxNotes, densityCap].compactMap { $0 }.min()
            if let effectiveMaxNotes {
                pitches = trimVoicesHarmonic(pitches, rootPitch: rootPitch, keep: effectiveMaxNotes)
            }

            // Smooth voice leading: pick the inversion closest to the
            // previous voicing, then clear muddy low intervals.
            pitches = voiceLead(pitches, previous: lastVoicing, range: range)
            pitches = avoidLowIntervalMud(pitches, range: range)
            pitches = shapeVoicingForMix(
                pitches,
                instrument: instrument,
                variant: variant,
                style: style,
                range: range
            )
            lastVoicing = pitches

            let center = pitches.reduce(0, +) / max(1, pitches.count)
            lastCenter = center
            
            // Apply intensity to velocity with instrument-specific curve
            let baseVelocity = chordVelocity(for: instrument, style: style)
                + chordVelocityAdjustment(for: instrument, variant: variant, style: style)
            let velocity = velocityCurve(base: baseVelocity, intensity: intensity, instrument: instrument)

            // Broken-chord patterns (arpeggio / Alberti). The user's explicit
            // choice wins; `.auto` resolves to the instrument's recommended
            // figure. The legacy arpeggio toggle routes through its own branch.
            if pitches.count >= 2, let figure {
                // Explicit arpeggio/Alberti choices follow the rate control;
                // the auto default uses a musical per-style grid.
                let grid = compingPattern == .auto
                    ? patternGrid(style: style, timeBottom: timeBottom)
                    : arpeggioRateBeats(arpeggioRate, timeBottom: timeBottom)
                notes += patternFigure(
                    pitches: pitches,
                    startBeat: span.startBeat,
                    duration: baseDuration,
                    pattern: figure,
                    grid: grid,
                    velocity: velocity
                )
                continue
            }

            // Sustained pads (strings, organ, synth pads, or an explicit
            // "Sustained" choice) hold one voicing across the whole chord — the
            // glue under the rhythmic instruments. Everything else comps with
            // the per-style rhythm.
            let hitOffsets: [Double]
            if isSustained {
                hitOffsets = [0]
            } else if let patternOffsets = explicitCompingOffsets(
                for: effectiveComping,
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                chordDuration: baseDuration
            ) {
                hitOffsets = patternOffsets
            } else {
                hitOffsets = chordHitOffsets(
                    instrument: instrument,
                    style: style,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom,
                    chordDuration: baseDuration,
                    intensity: intensity,
                    complexity: effectiveComplexity
                )
            }

            for offset in hitOffsets {
                guard offset < baseDuration else { continue }
                let duration: Double
                if isSustained {
                    // Ring through the chord and a touch into the next for legato.
                    duration = max(0.25, baseDuration - offset) + 0.2
                } else {
                    let hitDuration = chordHitDuration(
                        instrument: instrument,
                        variant: variant,
                        style: style,
                        timeBottom: timeBottom,
                        baseDuration: baseDuration,
                        offset: offset,
                        durationScale: voicingProfile.durationScale
                    )
                    duration = min(
                        hitDuration * compingDurationScale(for: effectiveComping),
                        max(0.25, baseDuration - offset)
                    )
                }
                let startBeat = span.startBeat + offset
                let positionInBar = (span.startBeat + offset)
                    .truncatingRemainder(dividingBy: Double(beatsPerBar))
                let accent = metricAccent(positionInBar: positionInBar, beatsPerBar: beatsPerBar)

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
                            // Alternating emphasis keeps arpeggios from sounding sequenced.
                            let arpVelocity = velocity + accent
                                - (index % 2 == 0 ? 0 : 5)
                                + Int.random(in: -2...2)
                            notes.append(
                                StudioNote(
                                    startBeat: arpStart,
                                    duration: arpDuration,
                                    pitch: pitch,
                                    velocity: clampVelocity(arpVelocity)
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
                                    velocity: clampVelocity(velocity + accent)
                                )
                            )
                        }
                    }
                } else {
                    // Guitar and harp roll their chords audibly; offbeat hits
                    // become up-strokes (high→low, slightly softer), like a
                    // real strumming hand.
                    let isStrummed = pitches.count > 1
                        && (instrument == .guitar || variant == .harp)
                    let isUpstroke = isStrummed && accent < 0
                    let strumStep = isStrummed ? (variant == .harp ? 0.05 : 0.03) : 0.0
                    let ordered = isUpstroke ? pitches.sorted(by: >) : pitches.sorted()
                    let lastIndex = ordered.count - 1

                    for (idx, pitch) in ordered.enumerated() {
                        var noteVelocity = velocity + accent
                        // Outer voices define the chord; inner voices sit back.
                        if ordered.count > 2, idx != 0, idx != lastIndex {
                            noteVelocity -= 5
                        }
                        if isUpstroke {
                            noteVelocity -= 6
                        }
                        noteVelocity += Int.random(in: -2...2)

                        let strumOffset = strumStep * Double(idx)
                        notes.append(
                            StudioNote(
                                startBeat: startBeat + strumOffset,
                                duration: max(0.1, duration - strumOffset),
                                pitch: pitch,
                                velocity: clampVelocity(noteVelocity)
                            )
                        )
                    }
                }
            }
        }

        // Avoid overlapping note-ons for the same pitch when density/intensity increases.
        return dedupeAndClampNotes(notes)
    }

    // MARK: - Piano (two hands)

    /// Generates a pianistic part split into a low-register left-hand
    /// foundation and a mid/upper-register right-hand voicing. The right hand
    /// reuses the chord-comping engine; the left hand anchors the harmony
    /// (and the low end when no dedicated bass is present).
    private static func pianoNotes(
        chords: [ChordSpan],
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        variant: InstrumentVariant?,
        octaveShift: Int,
        keyRoot: String,
        diatonicMap: [String: ChordQuality],
        intensity: Double,
        complexity: Double,
        arpeggioEnabled: Bool,
        arpeggioRate: String,
        arpeggioPattern: String,
        compingPattern: CompingPattern,
        arrangement: ArrangementContext
    ) -> [StudioNote] {
        let fullRange = chordRange(for: .piano, variant: variant, style: style, octaveShift: octaveShift)
        // Split the keyboard around middle C. The right hand comps above it;
        // the left hand lives below.
        let splitPoint = max(fullRange.lowerBound + 7, min(60, fullRange.upperBound - 7))
        let rightRange = splitPoint...fullRange.upperBound
        // With a dedicated bass, keep even the left hand above the bass register.
        let stablePianoFloor = 36 // C2: avoids unstable lowest soundfont samples.
        let leftLower = max(fullRange.lowerBound, arrangement.lowEndFloor ?? stablePianoFloor, stablePianoFloor)
        let leftRange = min(leftLower, splitPoint - 1)...(splitPoint - 1)

        var notes: [StudioNote] = []

        // Right hand: comp the chord voicing in the upper register, 3 voices.
        notes += chordPadNotes(
            chords: chords,
            instrument: .piano,
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
            arpeggioPattern: arpeggioPattern,
            compingPattern: compingPattern,
            arrangement: arrangement,
            rangeOverride: rightRange,
            noteCap: 3
        )

        // Left hand foundation. With no dedicated bass, keep it even when the
        // right hand plays a broken pattern; the right hand is constrained to
        // the upper range, so it cannot anchor the song by itself. With bass,
        // skip it for broken/arpeggiated parts to avoid low-end clutter.
        let effectiveComping = compingPattern == .auto
            ? recommendedComping(for: .piano, variant: variant, style: style)
            : compingPattern
        let busyRightHand = arpeggioEnabled
            || accompanimentFigure(for: effectiveComping) != nil
        let shouldPlayLeftHand = !arrangement.hasBass || !busyRightHand
        if shouldPlayLeftHand {
            notes += pianoLeftHand(
                chords: chords,
                range: leftRange,
                style: style,
                keyRoot: keyRoot,
                intensity: intensity,
                beatsPerBar: beatsPerBar,
                hasBass: arrangement.hasBass
            )
        }

        return dedupeAndClampNotes(notes)
    }

    /// Left-hand foundation. With a dedicated bass present it plays a soft
    /// sustained root+fifth shell up near the hand split (staying out of the
    /// bass's way); otherwise it anchors the low end like a real left hand —
    /// root on the downbeat, fifth mid-bar, sustained.
    private static func pianoLeftHand(
        chords: [ChordSpan],
        range: ClosedRange<Int>,
        style: StudioStyle,
        keyRoot: String,
        intensity: Double,
        beatsPerBar: Int,
        hasBass: Bool
    ) -> [StudioNote] {
        guard range.lowerBound < range.upperBound else { return [] }

        // Sit the shell in the upper third of the LH range when a bass owns the
        // low end, otherwise anchor near the bottom.
        let anchorTarget = hasBass
            ? range.lowerBound + (range.upperBound - range.lowerBound) * 2 / 3
            : range.lowerBound + 4
        var lastRoot = nearestPitch(for: noteSemitone(for: keyRoot), in: range, near: anchorTarget)
        var notes: [StudioNote] = []

        let baseVelocity = max(40, bassVelocity(for: style) - (hasBass ? 22 : 10))
        let midBeat = Double(max(1, beatsPerBar / 2))
        let staccato = !hasBass && (style == .funk || style == .edm)

        for span in chords {
            let rootClass = noteSemitone(for: span.chord.slashRoot ?? span.chord.root)
            let rootPitch = nearestPitch(for: rootClass, in: range, near: lastRoot)
            lastRoot = rootPitch
            let baseDuration = max(0.25, span.duration)
            let fifth = fitPitch(rootPitch + 7, in: range)
            let velocity = clampVelocity(velocityCurve(base: baseVelocity, intensity: intensity, instrument: .bass))

            // Note-on offsets and which pitch sounds.
            var hits: [(offset: Double, pitch: Int)] = [(0, rootPitch)]
            if !staccato, baseDuration >= midBeat + 0.25 {
                // Add the fifth (or a higher root) mid-bar to keep the hand moving.
                hits.append((midBeat, hasBass ? fitPitch(rootPitch + 12, in: range) : fifth))
            }

            for hit in hits {
                guard hit.offset < baseDuration else { continue }
                let ring = staccato ? min(0.4, baseDuration - hit.offset)
                                    : (baseDuration - hit.offset) + 0.15  // legato
                notes.append(
                    StudioNote(
                        startBeat: span.startBeat + hit.offset,
                        duration: max(0.2, ring),
                        pitch: hit.pitch,
                        velocity: velocity
                    )
                )
            }
        }

        return dedupeAndClampNotes(notes)
    }

    // MARK: - Melodic line (lead instruments)

    private struct MelodyCell {
        let offset: Double
        let duration: Double
        let isRest: Bool
        let strong: Bool
    }

    /// Builds a real melodic line over the changes for monophonic lead
    /// instruments: stepwise scale motion that lands on chord tones on strong
    /// beats, with rests for phrasing and a register that arcs rather than
    /// holding a single note per chord.
    private static func melodyNotes(
        chords: [ChordSpan],
        instrument: StudioInstrument,
        variant: InstrumentVariant?,
        beatsPerBar: Int,
        timeBottom: Int,
        style: StudioStyle,
        octaveShift: Int,
        keyRoot: String,
        keyMode: KeyMode,
        diatonicMap: [String: ChordQuality],
        intensity: Double,
        complexity: Double
    ) -> [StudioNote] {
        let range = chordRange(for: instrument, variant: variant, style: style, octaveShift: octaveShift)
        guard range.upperBound > range.lowerBound else { return [] }
        let keyPC = noteSemitone(for: keyRoot)
        let scalePCs = Set(keyMode.intervals.map { (keyPC + $0) % 12 })

        // Leads sing in the upper-middle of their range; keep the line within
        // roughly an octave of that center so it stays singable.
        let center = range.lowerBound + (range.upperBound - range.lowerBound) * 6 / 10
        let windowRadius = 10
        var lastPitch = nearest(in: pitches(in: range, pcs: scalePCs), to: center) ?? center
        var direction = 1
        let baseVelocity = chordVelocity(for: instrument, style: style)
        var notes: [StudioNote] = []

        for (index, span) in chords.enumerated() {
            let quality = resolveQuality(for: span.chord, diatonicMap: diatonicMap)
            let tones = harmonicTones(for: quality)
            let chordRootPC = noteSemitone(for: span.chord.root)
            let chordTonePCs = Set(tones.essential.map { (chordRootPC + $0) % 12 })
            // Diatonic steps plus the chord's own tones (covers chromatic chords).
            let stepPCs = scalePCs.union(chordTonePCs)
            let stepPitches = pitches(in: range, pcs: stepPCs)
            let chordTonePitches = pitches(in: range, pcs: chordTonePCs)
            guard !stepPitches.isEmpty, !chordTonePitches.isEmpty else { continue }

            let isLast = index == chords.count - 1
            let cells = melodicRhythm(
                style: style,
                chordDuration: max(0.25, span.duration),
                beatsPerBar: beatsPerBar,
                timeBottom: timeBottom,
                complexity: complexity,
                intensity: intensity,
                isLastChord: isLast
            )

            for cell in cells where !cell.isRest {
                // Reflect direction at the edges of the melodic window.
                if lastPitch > center + windowRadius { direction = -1 }
                else if lastPitch < center - windowRadius { direction = 1 }
                else if Int.random(in: 0..<5) == 0 { direction = -direction }

                let target: Int
                if cell.strong {
                    // Land on a chord tone, biased a small step in the current
                    // direction so the line keeps moving.
                    let aim = lastPitch + direction * 2
                    target = nearest(in: chordTonePitches, to: aim) ?? lastPitch
                } else {
                    // Passing / neighbor tone: nearest scale step in direction.
                    target = nearestStep(from: lastPitch, in: stepPitches, direction: direction)
                }

                let velocity = clampVelocity(
                    velocityCurve(base: baseVelocity, intensity: intensity, instrument: instrument)
                        + (cell.strong ? 6 : -3)
                        + Int.random(in: -3...3)
                )
                notes.append(
                    StudioNote(
                        startBeat: span.startBeat + cell.offset,
                        duration: cell.duration,
                        pitch: target,
                        velocity: velocity
                    )
                )
                lastPitch = target
            }
        }
        return dedupeAndClampNotes(notes)
    }

    /// All pitches in `range` whose pitch class is in `pcs`, ascending.
    private static func pitches(in range: ClosedRange<Int>, pcs: Set<Int>) -> [Int] {
        range.filter { pcs.contains((($0 % 12) + 12) % 12) }
    }

    private static func nearest(in pitches: [Int], to target: Int) -> Int? {
        pitches.min(by: { abs($0 - target) < abs($1 - target) })
    }

    /// The next scale pitch one step from `from` in `direction`; reflects at
    /// the ends so the line never runs off the instrument range.
    private static func nearestStep(from pitch: Int, in scalePitches: [Int], direction: Int) -> Int {
        let sorted = scalePitches
        guard !sorted.isEmpty else { return pitch }
        let idx = sorted.indices.min(by: { abs(sorted[$0] - pitch) < abs(sorted[$1] - pitch) }) ?? 0
        let nextIdx = idx + direction
        if nextIdx < 0 { return sorted[min(1, sorted.count - 1)] }
        if nextIdx >= sorted.count { return sorted[max(0, sorted.count - 2)] }
        return sorted[nextIdx]
    }

    /// A per-style rhythmic grid of melodic cells (notes and rests) covering
    /// one chord, with chord-tone "strong" landings on the main beats.
    private static func melodicRhythm(
        style: StudioStyle,
        chordDuration: Double,
        beatsPerBar: Int,
        timeBottom: Int,
        complexity: Double,
        intensity: Double,
        isLastChord: Bool
    ) -> [MelodyCell] {
        let grid: Double
        switch style {
        case .lofi, .ambient:   grid = 1.0
        default:                grid = 0.5
        }
        let density = max(0.0, min(1.0, 0.35 + complexity * 0.4 + intensity * 0.15))

        var cells: [MelodyCell] = []
        var offset = 0.0
        var first = true
        while offset < chordDuration - 0.001 {
            let onBeat = abs(offset.rounded() - offset) < 0.001
            let beatIndex = Int(offset.rounded())
            let strong = onBeat && (beatIndex % 2 == 0)

            let restChance: Double = first ? 0.0 : (strong ? 0.12 : (1.0 - density))
            let isRest = !first && Double.random(in: 0...1) < restChance

            var duration = grid
            if !isRest, Double.random(in: 0...1) < 0.3, offset + grid * 2 <= chordDuration {
                duration = grid * 2
            }
            duration = min(duration, chordDuration - offset)

            cells.append(MelodyCell(offset: offset, duration: max(0.1, duration), isRest: isRest, strong: strong))
            offset += duration
            first = false
        }

        if isLastChord, let last = cells.last, last.isRest, cells.count > 1 {
            cells.removeLast()
        }
        return cells
    }

    // MARK: - Idiomatic accompaniment patterns

    private enum AccompanimentPattern {
        case arpeggioUp
        case arpeggioDown
        case arpeggioUpDown
        case alberti       // low–high–mid–high (broken-chord keyboard figure)
        case ostinato      // short repeating harmonic cell
    }

    /// Resolves an explicit chord pattern to its broken-chord figure (nil means
    /// block or sustained — handled outside the pattern path). `.auto` is
    /// resolved to the per-instrument recommendation before this is called.
    private static func accompanimentFigure(for comping: CompingPattern) -> AccompanimentPattern? {
        switch comping {
        case .arpeggioUp:     return .arpeggioUp
        case .arpeggioDown:   return .arpeggioDown
        case .arpeggioUpDown: return .arpeggioUpDown
        case .alberti:        return .alberti
        case .ostinato:       return .ostinato
        case .auto, .block, .sustained, .offbeat, .pulse, .stabs, .anticipation, .waltz, .tremolo:
            return nil
        }
    }

    private static func guitarIsAcoustic(_ variant: InstrumentVariant?) -> Bool {
        guard let variant else { return true }
        return [.acousticNylonGuitar, .acousticSteelGuitar, .cleanGuitar, .jazzGuitar, .twelveStringGuitar, .ukulele].contains(variant)
    }

    /// The idiomatic default articulation for a chord instrument in a given
    /// style — what "Auto" resolves to, and what the add-instrument flow
    /// pre-selects. This is the heart of "a specific pattern per instrument".
    static func recommendedComping(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle
    ) -> CompingPattern {
        switch instrument {
        // Sustained beds (a pluck synth arpeggiates instead).
        case .synth where variant == .synthPluck:
            return .arpeggioUpDown
        case .strings, .organ, .synth:
            return .sustained

        case .piano:
            switch style {
            case .lofi, .ambient, .hiphop: return .alberti   // broken comp
            case .pop: return .anticipation                  // chords on 1 + pushed "and of 4"
            case .jazz, .rock, .edm, .funk:      return .block      // rootless / stabs
            }

        case .guitar:
            let acoustic = guitarIsAcoustic(variant)
            switch style {
            case .lofi, .ambient:        return .arpeggioUp                 // fingerpick
            case .pop:                   return acoustic ? .pulse : .block   // strummed quarters
            case .jazz:                  return acoustic ? .arpeggioUp : .block
            case .rock, .edm, .funk, .hiphop: return .block                 // strum / stabs / power
            }

        case .mallets:
            switch style {
            case .rock, .edm:                  return .block
            case .lofi, .ambient, .jazz, .hiphop: return .arpeggioUpDown
            case .pop, .funk:                  return .arpeggioUp
            }

        case .brass:
            return .block   // section stabs

        // Woodwinds play melodic lines, bass/drums have their own engines.
        case .woodwinds, .bass, .drums, .audio:
            return .auto
        }
    }

    /// The idiomatic default bass feel for a style (pre-selected in the
    /// add-instrument flow).
    static func recommendedBass(for style: StudioStyle) -> BassPattern {
        switch style {
        case .pop:     return .pocket
        case .rock:    return .drive
        case .jazz:    return .walking
        case .funk:    return .syncopated
        case .edm:     return .offbeat
        case .hiphop:  return .roots
        case .lofi:    return .roots
        case .ambient: return .roots
        }
    }

    static func compingOptions(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle
    ) -> [CompingPattern] {
        switch instrument {
        case .piano:
            return [.auto, .alberti, .block, .pulse, .offbeat, .anticipation, .waltz, .arpeggioUpDown, .sustained]
        case .guitar:
            return [.auto, .block, .offbeat, .stabs, .pulse, .arpeggioUp, .arpeggioUpDown, .anticipation, .sustained]
        case .strings:
            return [.auto, .sustained, .tremolo, .pulse, .anticipation, .arpeggioUpDown]
        case .synth:
            return [.auto, .sustained, .pulse, .offbeat, .stabs, .tremolo, .arpeggioUp, .arpeggioUpDown]
        case .organ:
            return [.auto, .sustained, .block, .offbeat, .pulse, .stabs, .anticipation]
        case .mallets:
            return [.auto, .ostinato, .arpeggioUp, .arpeggioUpDown, .pulse, .block, .sustained]
        case .brass:
            return [.auto, .stabs, .block, .offbeat, .anticipation, .pulse]
        case .woodwinds, .bass, .drums, .audio:
            return [.auto]
        }
    }

    static func bassOptions(for style: StudioStyle) -> [BassPattern] {
        switch style {
        case .jazz:
            return [.auto, .walking, .rootFifth, .anticipated, .sparse, .roots, .pedal]
        case .funk:
            return [.auto, .syncopated, .offbeat, .octaves, .rootFifth, .anticipated, .sparse]
        case .edm:
            return [.auto, .offbeat, .octaves, .pedal, .drive, .roots, .anticipated, .sparse]
        case .rock:
            return [.auto, .drive, .octaves, .rootFifth, .pedal, .anticipated, .roots, .sparse]
        case .hiphop:
            return [.auto, .roots, .pocket, .sparse, .offbeat, .pedal, .anticipated, .octaves]
        case .lofi, .ambient:
            return [.auto, .roots, .sparse, .pedal, .rootFifth, .anticipated]
        case .pop:
            return [.auto, .pocket, .drive, .rootFifth, .octaves, .offbeat, .anticipated, .roots, .sparse]
        }
    }

    private static func patternGrid(style: StudioStyle, timeBottom: Int) -> Double {
        let beat = timeBottom == 8 ? 1.0 : 0.5   // an eighth note in UI beats
        return style == .ambient ? beat * 2 : beat
    }

    /// Emits a repeating broken-chord figure across the chord's duration.
    private static func patternFigure(
        pitches: [Int],
        startBeat: Double,
        duration: Double,
        pattern: AccompanimentPattern,
        grid: Double,
        velocity: Int
    ) -> [StudioNote] {
        let sorted = uniqueSorted(pitches)
        guard sorted.count >= 2, grid > 0 else {
            return sorted.map { StudioNote(startBeat: startBeat, duration: duration, pitch: $0, velocity: clampVelocity(velocity)) }
        }

        let top = sorted.count - 1
        let sequence: [Int]
        switch pattern {
        case .arpeggioUp:
            sequence = Array(0..<sorted.count)
        case .arpeggioDown:
            sequence = Array((0..<sorted.count).reversed())
        case .arpeggioUpDown:
            sequence = sorted.count <= 2
                ? Array(0..<sorted.count)
                : Array(0..<sorted.count) + Array((1..<top).reversed())
        case .alberti:
            sequence = sorted.count >= 3 ? [0, top, 1, top] : [0, 1]
        case .ostinato:
            sequence = sorted.count >= 3 ? [0, 2, 1, 2] : [0, 1, 0, 1]
        }

        var result: [StudioNote] = []
        var step = 0
        var offset = 0.0
        while offset < duration - 0.001 {
            let pitch = sorted[sequence[step % sequence.count]]
            let isCycleStart = step % sequence.count == 0
            let dur = min(grid * 0.95, duration - offset)
            result.append(
                StudioNote(
                    startBeat: startBeat + offset,
                    duration: max(0.1, dur),
                    pitch: pitch,
                    // Emphasise the bass note that begins each cycle.
                    velocity: clampVelocity(velocity + (isCycleStart ? 4 : -5) + Int.random(in: -2...2))
                )
            )
            offset += grid
            step += 1
        }
        return result
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
        complexity: Double = 0.5,
        bassPattern requested: BassPattern = .auto
    ) -> [StudioNote] {
        // "Auto" plays the style's recommended feel (same as the starter band).
        let bassPattern = requested == .auto ? recommendedBass(for: style) : requested
        let fullRange = bassRange(variant: variant, style: style, octaveShift: octaveShift)
        // Keep the line out of the sub-audible bottom (below A1 ≈ 55 Hz):
        // there GM bass samples get flabby and phone speakers lose the note.
        // Sub basses and the user's octave choices below neutral keep their floor.
        let floor = variant == .synthSubBass || octaveShift < 2 ? fullRange.lowerBound : max(fullRange.lowerBound, 33)
        let range = floor + 12 <= fullRange.upperBound ? floor...fullRange.upperBound : fullRange
        let bassProfile = bassVoicingProfile(variant: variant, style: style)
        var lastPitch = anchorPitch(for: keyRoot, in: range)
        var notes: [StudioNote] = []

        for (index, span) in chords.enumerated() {
            let rootName = span.chord.slashRoot ?? span.chord.root
            let rootClass = noteSemitone(for: rootName)
            let rootPitch = nearestPitch(for: rootClass, in: range, near: lastPitch)
            lastPitch = rootPitch
            let baseDuration = max(0.25, span.duration)
            let tones = harmonicTones(for: span.chord.quality)
            let fifth = fitPitch(rootPitch + tones.fifth, in: range)
            let third = fitPitch(rootPitch + (tones.third ?? tones.suspension ?? 7), in: range)
            let octave = fitPitch(rootPitch + 12, in: range)
            let midBeat = Double(max(1, beatsPerBar / 2))

            // Where the NEXT chord's root lands, for leading-tone / approach notes.
            let nextRootClass: Int? = index + 1 < chords.count
                ? noteSemitone(for: chords[index + 1].chord.slashRoot ?? chords[index + 1].chord.root)
                : nil
            // A half-step (or whole-step) approach note just below/above the
            // next root — the hallmark of a walking / connected bass line.
            func approachToNext() -> Int {
                guard let nextRootClass else { return fifth }
                let target = nearestPitch(for: nextRootClass, in: range, near: rootPitch)
                let fromBelow = fitPitch(target - 1, in: range)
                let fromAbove = fitPitch(target + 1, in: range)
                // Prefer the chromatic approach that's closest to where we are.
                return abs(fromBelow - rootPitch) <= abs(fromAbove - rootPitch) ? fromBelow : fromAbove
            }

            var hits: [(offset: Double, pitch: Int)] = [(0, rootPitch)]

            // Explicit user-chosen bass feel overrides the per-style default.
            if bassPattern != .auto {
                switch bassPattern {
                case .roots:
                    hits = [(0, rootPitch)]
                case .rootFifth:
                    hits = [(0, rootPitch)]
                    if baseDuration >= midBeat + 0.25 { hits.append((midBeat, fifth)) }
                case .octaves:
                    hits = stride(from: 0.0, to: baseDuration, by: 1.0).enumerated()
                        .map { i, off in (off, i % 2 == 0 ? rootPitch : octave) }
                case .walking:
                    let line = [rootPitch, third, fifth, approachToNext()]
                    hits = stride(from: 0.0, to: baseDuration, by: 1.0).enumerated()
                        .map { i, off in (off, line[i % line.count]) }
                case .syncopated:
                    hits = stride(from: 0.0, to: baseDuration, by: 0.5).enumerated()
                        .map { i, off in (off, i % 2 == 0 ? rootPitch : (i % 4 == 1 ? octave : fifth)) }
                case .pedal:
                    hits = stride(from: 0.0, to: baseDuration, by: 1.0).map { ($0, rootPitch) }
                case .offbeat:
                    let step = timeBottom == 8 ? midBeat : 1.0
                    let firstUpbeat = step / 2.0
                    hits = [(0, rootPitch)]
                    hits.append(
                        contentsOf: stride(from: firstUpbeat, to: baseDuration, by: step)
                            .map { ($0, octave) }
                    )
                case .anticipated:
                    hits = [(0, rootPitch)]
                    if baseDuration >= midBeat + 0.25 {
                        hits.append((midBeat, fifth))
                    }
                    let push = max(0.5, baseDuration - 0.5)
                    if push < baseDuration {
                        hits.append((push, approachToNext()))
                    }
                case .sparse:
                    hits = [(0, rootPitch)]
                    if baseDuration >= midBeat * 2.0 {
                        hits.append((midBeat * 2.0, rootPitch))
                    }
                case .pocket:
                    // How a pop bassist actually plays: a long root on 1, a
                    // pick-up on the "and" of 2, the root again on 3, and the
                    // "and" of 4 walks into the next chord. Locks with a pop kick.
                    if baseDuration >= 4 - 0.01 {
                        hits = [(0, rootPitch), (1.5, rootPitch), (2.0, index % 2 == 0 ? rootPitch : fifth)]
                        hits.append((3.5, nextRootClass != nil ? approachToNext() : octave))
                    } else if baseDuration >= 2 - 0.01 {
                        hits = [(0, rootPitch)]
                        if nextRootClass != nil { hits.append((baseDuration - 0.5, approachToNext())) }
                    } else {
                        hits = [(0, rootPitch)]
                    }
                case .drive:
                    // Played like a real pick/finger player: steady eighths on
                    // the root, an octave lift on the "and" of 3 now and then,
                    // and the last eighth walks into the next chord.
                    let step = timeBottom == 8 ? midBeat / 2 : 0.5
                    var driveHits: [(Double, Int)] = []
                    var offset = 0.0
                    var i = 0
                    while offset < baseDuration - 0.01 {
                        let isLast = offset + step >= baseDuration - 0.01
                        let pitch: Int
                        if isLast, nextRootClass != nil, baseDuration >= 2 {
                            pitch = approachToNext()
                        } else if i == 5, baseDuration >= 4, index % 2 == 1 {
                            pitch = octave
                        } else {
                            pitch = rootPitch
                        }
                        driveHits.append((offset, pitch))
                        offset += step
                        i += 1
                    }
                    hits = driveHits
                case .auto:
                    break
                }
                // Skip the per-style switch and density auto-edits below.
                let velocity = scaledVelocity(
                    base: bassVelocity(for: style) + bassProfile.velocityOffset,
                    intensity: intensity,
                    range: 36
                )
                let durationHint = bassHitDuration(style: style) * bassProfile.durationScale
                let adjustedDuration = max(0.25, durationHint * (1.1 - 0.4 * intensity))
                var seen = Set<Double>()
                for hit in hits.filter({ seen.insert($0.offset).inserted }).sorted(by: { $0.offset < $1.offset }) {
                    guard hit.offset < baseDuration else { continue }
                    var duration = min(adjustedDuration, max(0.25, baseDuration - hit.offset))
                    var hitVelocity = velocity
                    if bassPattern == .pocket {
                        // Long notes ring (legato to the next hit), pick-ups are short.
                        let next = hits.filter { $0.offset > hit.offset + 0.01 }.map(\.offset).min() ?? baseDuration
                        let gap = next - hit.offset
                        duration = gap >= 1 ? gap * 0.92 : min(0.42, gap * 0.85)
                        let isDownbeat = hit.offset < 0.01
                        hitVelocity += isDownbeat ? 8 : (abs(hit.offset.rounded() - hit.offset) < 0.01 ? 2 : -7)
                    } else if bassPattern == .drive {
                        // Short, punchy eighths with a natural accent shape:
                        // downbeat strongest, beats medium, off-beats lighter.
                        duration = min(0.42, max(0.2, baseDuration - hit.offset))
                        let isDownbeat = abs(hit.offset.truncatingRemainder(dividingBy: Double(beatsPerBar))) < 0.01
                        let onBeat = abs(hit.offset.rounded() - hit.offset) < 0.01
                        hitVelocity += isDownbeat ? 10 : (onBeat ? 3 : -9)
                    }
                    notes.append(StudioNote(startBeat: span.startBeat + hit.offset, duration: duration, pitch: hit.pitch, velocity: clampVelocity(hitVelocity)))
                }
                continue
            }

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
                // Walking bass: root → 3rd → 5th → chromatic approach to the
                // real next root (1-3-5-approach over four beats).
                if baseDuration >= 2.0 {
                    hits = [(0, rootPitch), (1.0, third)]
                    if baseDuration >= 3.0 {
                        hits.append((2.0, fifth))
                    }
                    if baseDuration >= 4.0 {
                        hits.append((3.0, approachToNext()))
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
                if density > 0.85, baseDuration >= 1.5, nextRootClass != nil {
                    // Lead into the next chord with a real approach note.
                    let approachOffset = max(0.5, baseDuration - 0.5)
                    if approachOffset < baseDuration {
                        hits.append((approachOffset, approachToNext()))
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
            // Only snap sustained notes whose gap is small but positive. Short,
            // articulated notes (eighth-note bass, stabs) keep their punch.
            guard note.duration >= 1.0, gap > 1e-6 && gap <= snapThreshold else { return note }
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
    static func defaultNaturalness(for instrument: StudioInstrument) -> Double {
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

    /// Human feel. Unlike a per-note random jitter (which made chords smear
    /// and sounded like a broken sequence), this treats notes that start
    /// together as one gesture:
    /// - a shared, normally distributed timing offset per gesture (small),
    /// - piano chords rolled gently low → high, top voice slightly accented,
    /// - style "pocket": laid-back backbeats and a bass that sits on the kick,
    /// - correlated velocity drift so phrases breathe instead of flickering.
    private static func applyNaturalness(
        to notes: [StudioNote],
        totalBars: Int,
        beatsPerBar: Int,
        timeBottom: Int,
        instrument: StudioInstrument,
        naturalness: Double,
        style: StudioStyle? = nil
    ) -> [StudioNote] {
        let amount = max(0.0, min(1.0, naturalness))
        guard amount > 0, !notes.isEmpty else { return notes }
        let timelineBeats = Double(totalBars * beatsPerBar)
        let beatUnit = 4.0 / Double(max(1, timeBottom))

        func gaussian(_ sigma: Double) -> Double {
            let u1 = Double.random(in: 0.0001...1), u2 = Double.random(in: 0...1)
            return sigma * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
        }

        // Timing spread (in beats): ~6 ms at 100 bpm for melodic parts at
        // default naturalness, tighter for drums.
        let sigma = (instrument == .drums ? 0.012 : 0.022) * amount * beatUnit
        let kit = SoundFontManager.drumPitchMap(for: nil)
        let backbeatLag: Double = {
            switch style {
            case .lofi, .hiphop: return 0.022
            case .pop, .funk: return 0.008
            case .jazz: return 0.012
            default: return 0
            }
        }() * beatUnit
        let bassLag: Double = (style == .lofi || style == .hiphop ? 0.012 : 0.006) * beatUnit

        // Group simultaneous onsets into gestures.
        let sorted = notes.sorted { ($0.startBeat, $0.pitch) < ($1.startBeat, $1.pitch) }
        var gestures: [[StudioNote]] = []
        for note in sorted {
            if let last = gestures.last?.first, abs(note.startBeat - last.startBeat) < 0.03 * beatUnit {
                gestures[gestures.count - 1].append(note)
            } else {
                gestures.append([note])
            }
        }

        var drift = 0.0  // slow random walk for phrase-level dynamics
        var adjusted: [StudioNote] = []
        adjusted.reserveCapacity(notes.count)
        for gesture in gestures {
            drift = max(-1, min(1, drift * 0.85 + gaussian(0.35)))
            let shared = gaussian(sigma)
            let gestureVelocity = drift * 5 * amount
            let rollStep = instrument == .piano && gesture.count >= 3 ? 0.006 * beatUnit * (0.5 + amount) : 0
            let topPitch = gesture.map(\.pitch).max() ?? 0

            for (index, note) in gesture.enumerated() {
                var offset = shared + Double(index) * rollStep
                var velocity = Double(note.velocity) + gestureVelocity + gaussian(1.5 * amount)

                switch instrument {
                case .drums:
                    let isBackbeat = [kit.snare, kit.clap, kit.rim].contains(note.pitch) && note.velocity > 60
                    if isBackbeat { offset += backbeatLag }
                    // Hats breathe a touch more than the kick/snare.
                    if [kit.hatClosed, kit.hatOpen, kit.ride].contains(note.pitch) {
                        offset += gaussian(sigma * 0.5)
                        velocity += gaussian(4 * amount)
                    }
                case .bass:
                    offset += bassLag
                default:
                    if gesture.count >= 3, note.pitch == topPitch { velocity += 4 * amount }
                }

                let newStart = min(max(0, note.startBeat + offset), max(0, timelineBeats - 0.05))
                let newDuration = min(note.duration, max(0.05, timelineBeats - newStart))
                adjusted.append(StudioNote(
                    startBeat: newStart,
                    duration: newDuration,
                    pitch: note.pitch,
                    velocity: min(127, max(1, Int(velocity.rounded())))
                ))
            }
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

    // MARK: - Accurate harmonic core

    /// The chord tones derived from the *actual* chord quality (so a m7 always
    /// carries its ♭7, a maj7 its natural 7, a sus has no third, etc.), split
    /// into essential tones (must sound for the chord to be correct) and
    /// optional upper tensions (9/11/13 colors).
    struct HarmonicTones {
        var third: Int?       // 3 (minor) or 4 (major); nil for power/sus
        var suspension: Int?  // 2 or 5 (sus chords)
        var fifth: Int        // 6 (dim), 7 (perfect), 8 (aug)
        var sixth: Int?       // 9 (6 / m6 chords)
        var seventh: Int?     // 9 (dim7 bb7), 10 (♭7), 11 (maj7)
        var tensions: [Int]   // 13(♭9) 14(9) 15(♯9) 17(11) 18(♯11) 20(♭13) 21(13)

        /// Notes that must be present for the quality to be heard.
        var essential: [Int] {
            var result = [0]
            if let suspension { result.append(suspension) }
            if let third { result.append(third) }
            result.append(fifth)
            if let sixth { result.append(sixth) }
            if let seventh { result.append(seventh) }
            return result.sorted()
        }
    }

    static func harmonicTones(for quality: ChordQuality, extensions: [String] = []) -> HarmonicTones {
        let intervals = Set(quality.intervals)
        var tones = HarmonicTones(third: nil, suspension: nil, fifth: 7, sixth: nil, seventh: nil, tensions: [])

        // Fifth: diminished / augmented / perfect.
        if intervals.contains(6) { tones.fifth = 6 }
        else if intervals.contains(8) { tones.fifth = 8 }
        else { tones.fifth = 7 }

        // Third or (for sus/power) the replacing tone.
        if intervals.contains(4) { tones.third = 4 }
        else if intervals.contains(3) { tones.third = 3 }
        else if intervals.contains(2) { tones.suspension = 2 }
        else if intervals.contains(5) { tones.suspension = 5 }

        // Seventh / sixth. A 9-semitone interval is the ♭♭7 in dim7 but the
        // 6th in 6/m6 chords.
        if quality == .diminished7 {
            tones.seventh = 9
        } else if intervals.contains(11) {
            tones.seventh = 11
        } else if intervals.contains(10) {
            tones.seventh = 10
        } else if intervals.contains(9), quality.category == .sixth {
            tones.sixth = 9
        }

        // Upper tensions baked into the quality.
        var tensions = Set(quality.intervals.filter { $0 >= 13 })

        // Explicit extensions chosen on the event.
        for ext in extensions {
            guard let iv = extensionInterval(for: ext) else { continue }
            switch iv {
            case 2, 5:
                if tones.third == nil { tones.suspension = iv }
            case 10:
                if tones.seventh == nil { tones.seventh = 10 }
            default:
                if iv >= 13 { tensions.insert(iv) }
            }
        }
        tones.tensions = tensions.sorted()
        return tones
    }

    /// Chooses which upper tensions to actually voice, given the instrument,
    /// style and complexity. Essential tones are always kept by the caller;
    /// this only adds color.
    private static func selectedTensions(
        from tones: HarmonicTones,
        instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle,
        complexity: Double
    ) -> [Int] {
        guard !tones.tensions.isEmpty else { return [] }

        // How freely this context adds extensions (0 = none, 1 = all available).
        var openness: Double
        switch style {
        case .jazz:   openness = 0.85
        case .lofi:   openness = 0.65
        case .ambient: openness = 0.6
        case .hiphop: openness = 0.5
        case .funk:   openness = 0.5
        case .pop:    openness = 0.3
        case .edm:    openness = 0.3
        case .rock:   openness = 0.15
        }
        switch instrument {
        case .guitar, .mallets: openness -= 0.2   // fewer stacked tensions
        case .strings, .synth, .organ: openness += 0.1
        case .brass, .woodwinds: openness -= 0.1
        default: break
        }
        openness += (complexity - 0.5) * 0.6
        openness = max(0, min(1, openness))

        // Keep tensions in priority order: 9th, 13th, then 11th/altered last.
        let priority: [Int] = [14, 21, 13, 15, 18, 17, 20]
        let available = priority.filter { tones.tensions.contains($0) }
        // Avoid the natural 11 (17) clashing with a major 3rd unless the chord
        // is explicitly an 11 chord (which the model already encodes).
        let maxCount = Int((openness * 3).rounded())   // 0...3 tensions
        return Array(available.prefix(max(0, maxCount)))
    }

    /// Rootless jazz keyboard voicing — drops the root (bass/left hand covers
    /// it) so the 3rd and 7th define the chord. The signature jazz-comp sound.
    private static func rootlessVoicing(_ pitches: [Int], rootPitch: Int) -> [Int] {
        let withoutRoot = pitches.filter { ($0 - rootPitch) % 12 != 0 }
        return withoutRoot.count >= 2 ? withoutRoot : pitches
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
            case .brightPiano, .electricPiano, .electricPiano2, .vintageElectricPiano, .electricGrandPiano, .padWarm, .padHalo, .padSweep:
                if complexity > 0.5 {
                    intervals.append(14)
                }
            case .padChoir, .padBowed, .padPolysynth, .padNewAge, .padMetallic, .padSoundtrack, .padAtmosphere,
                 .synthAnalogPad, .synthGlassPad, .synthSupersaw:
                if complexity > 0.4 {
                    intervals.append(14)
                }
                if complexity > 0.75 {
                    intervals.append(17)
                }
            case .harpsichord, .honkyTonkPiano, .clavinet, .mutedGuitar, .overdriveGuitar, .distortionGuitar:
                intervals.removeAll()
            case .tremoloStrings, .stringEnsemble, .slowStrings, .synthStrings1, .synthStrings2, .synthStrings3, .padOrchestral:
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

    /// The complete playable range for manual editing — the instrument's
    /// natural range extended an octave each way, clamped to a musical span
    /// (C1–C7) so every available octave is editable.
    static func fullInstrumentRange(
        for instrument: StudioInstrument,
        variant: InstrumentVariant? = nil
    ) -> ClosedRange<Int> {
        let base = baseInstrumentRange(for: instrument, variant: variant)
        let lower = max(24, base.lowerBound - 12)   // C1 floor
        let upper = min(96, base.upperBound + 12)   // C7 ceiling
        return lower...max(lower + 12, upper)
    }

    /// The octave setting that plays an instrument in its natural register.
    /// MS Basic presets are all concert-pitched and the base ranges already
    /// encode each instrument's register, so neutral is always 2 (no shift).
    static func defaultOctaveShift(
        for instrument: StudioInstrument,
        variant: InstrumentVariant? = nil
    ) -> Int {
        2
    }

    /// Where a freshly added track starts. Piano begins an octave down so its
    /// left hand gives the arrangement weight; everything else starts in its
    /// natural register.
    static func initialOctaveShift(
        for instrument: StudioInstrument,
        variant: InstrumentVariant? = nil
    ) -> Int {
        let neutral = defaultOctaveShift(for: instrument, variant: variant)
        let allowed = allowedOctaveShiftRange(for: instrument, variant: variant)
        let start = instrument == .piano ? neutral - 1 : neutral
        return min(allowed.upperBound, max(allowed.lowerBound, start))
    }

    /// Octave semantics changed when the old SoundFont (whose presets needed
    /// per-variant octave compensation) was replaced. Tracks created before
    /// that sit one or two octaves too low (e.g. a bass at C0). Resets them
    /// once per project; returns true when notes need regenerating.
    @discardableResult
    static func migrateOctaveSemanticsIfNeeded(project: Project) -> Bool {
        let key = "studio.octaveSemanticsV2.\(project.id.uuidString)"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        var changed = false
        for track in project.studioTracks where !track.instrument.isAudio && track.instrument != .drums {
            let allowed = allowedOctaveShiftRange(for: track.instrument, variant: track.variant)
            let initial = initialOctaveShift(for: track.instrument, variant: track.variant)
            if !allowed.contains(track.octaveShift) || (track.instrument != .piano && track.octaveShift < initial) {
                track.octaveShift = initial
                changed = true
            }
        }
        return changed
    }

    /// ±1 octave around the natural register (piano ±2), clamped where the
    /// instrument or its samples run out.
    static func allowedOctaveShiftRange(
        for instrument: StudioInstrument,
        variant: InstrumentVariant? = nil
    ) -> ClosedRange<Int> {
        switch instrument {
        case .drums, .audio:
            return 2...2   // Fixed – no octave shift for drums or audio tracks
        case .piano:
            return 0...4
        case .mallets:
            if variant == .glockenspiel { return 1...2 }   // already very high
            return 1...3
        default:
            return 1...3
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
            // Only push synth lower; piano already starts in a lower default register.
            // Strings at -12 drops below cello (C1 = MIDI 24).
            if instrument == .synth {
                return -12
            }
            return 0
        case .edm:
            return instrument == .synth ? 12 : 0
        case .jazz:
            // Brass +12 pushes trumpet to Bb6+ (above physical limit)
            return 0
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
            return 0
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

    private static func intersectRange(
        _ range: ClosedRange<Int>,
        with preferred: ClosedRange<Int>,
        minimumSpan: Int = 7
    ) -> ClosedRange<Int> {
        let lower = max(range.lowerBound, preferred.lowerBound)
        let upper = min(range.upperBound, preferred.upperBound)
        guard lower <= upper, upper - lower >= minimumSpan else { return range }
        return lower...upper
    }

    /// Assigns each harmonic instrument to a musical register lane in a band
    /// arrangement. Physical ranges say what an instrument can play; these
    /// lanes say where it should sit so Studio does not stack every voicing in
    /// the same muddy midrange.
    private static func arrangementRoleRange(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle,
        baseRange: ClosedRange<Int>,
        arrangement: ArrangementContext
    ) -> ClosedRange<Int> {
        guard arrangement.harmonicCount >= 2 || arrangement.hasBass else { return baseRange }

        let preferred: ClosedRange<Int>
        switch instrument {
        case .piano:
            preferred = arrangement.hasBass ? 55...76 : 48...76

        case .guitar:
            if let variant, [.mutedGuitar, .overdriveGuitar, .distortionGuitar].contains(variant) {
                preferred = arrangement.hasBass ? 45...64 : 40...67
            } else {
                preferred = (arrangement.hasBass || arrangement.hasPiano) ? 52...76 : 45...76
            }

        case .strings:
            // Warm middle register (G3–G5) under a band; wider when alone.
            preferred = (arrangement.hasPiano || arrangement.hasGuitar || arrangement.hasSynth)
                ? 55...79
                : 48...81

        case .synth:
            // Pads sit just above the keys, not in the whistle register.
            if style == .ambient {
                preferred = 57...84
            } else {
                preferred = arrangement.hasStrings ? 60...79 : 55...77
            }

        case .organ:
            preferred = arrangement.hasBass ? 52...76 : 45...76

        case .brass:
            preferred = 55...78

        case .mallets:
            preferred = 60...88

        case .woodwinds:
            preferred = 60...84

        case .bass, .drums, .audio:
            return baseRange
        }

        return intersectRange(baseRange, with: preferred)
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

    private static func maxVoicingSpan(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle
    ) -> Int {
        if instrument == .strings { return style == .ambient ? 36 : 31 }
        if instrument == .synth { return style == .ambient ? 31 : 24 }
        if instrument == .organ { return 24 }
        if instrument == .piano { return 21 }
        if instrument == .guitar {
            if let variant, [.mutedGuitar, .overdriveGuitar, .distortionGuitar].contains(variant) {
                return 14
            }
            return 19
        }
        if instrument == .brass { return 16 }
        if instrument == .mallets { return 16 }
        return 24
    }

    /// Final voicing polish after inversion selection: keep voices inside the
    /// instrument's register lane, avoid enormous chord spans for comping
    /// instruments, and re-check low intervals after any octave movement.
    private static func shapeVoicingForMix(
        _ pitches: [Int],
        instrument: StudioInstrument,
        variant: InstrumentVariant?,
        style: StudioStyle,
        range: ClosedRange<Int>
    ) -> [Int] {
        var shaped = foldIntoRange(pitches, range)
        let originalCount = shaped.count
        let maxSpan = maxVoicingSpan(for: instrument, variant: variant, style: style)
        var safety = 0

        while let low = shaped.first,
              let high = shaped.last,
              high - low > maxSpan,
              safety < 32 {
            safety += 1

            let raisedLow = low + 12
            if raisedLow <= range.upperBound, !shaped.contains(raisedLow) {
                shaped.removeFirst()
                shaped.append(raisedLow)
                shaped = uniqueSorted(shaped)
                if shaped.count == originalCount { continue }
            }

            let loweredHigh = high - 12
            if loweredHigh >= range.lowerBound, !shaped.contains(loweredHigh) {
                shaped.removeLast()
                shaped.append(loweredHigh)
                shaped = uniqueSorted(shaped)
                if shaped.count == originalCount { continue }
            }

            break
        }

        return avoidLowIntervalMud(shaped, range: range)
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
        /// Holds a single voicing across the whole chord (legato pad) instead
        /// of re-articulating with the rhythm.
        var sustains: Bool = false
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
            profile.sustains = true
        case .brass:
            profile.maxNotes = 3
        case .woodwinds:
            profile.maxNotes = 1
        case .organ:
            profile.maxNotes = 4
            profile.preferOpenVoicing = true
            profile.sustains = true
        case .mallets:
            profile.maxNotes = 2
            profile.durationScale = 0.7
        case .bass, .drums, .audio:
            break
        }

        // Ambient is a wash: everything sustains.
        if style == .ambient, instrument != .mallets {
            profile.sustains = true
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
            case .padNewAge, .padWarm, .padPolysynth, .padChoir, .padBowed, .padMetallic, .padHalo, .padSweep, .padSoundtrack, .padAtmosphere,
                 .synthAnalogPad, .synthGlassPad, .synthSupersaw:
                profile.maxNotes = 4
                profile.preferOpenVoicing = true
                profile.extensionBias = 0.2
                profile.durationScale = 1.1
                profile.sustains = true
            case .acousticNylonGuitar, .acousticSteelGuitar, .twelveStringGuitar, .ukulele:
                profile.maxNotes = 3
                profile.preferOpenVoicing = true
            case .funkGuitar:
                profile.maxNotes = 3
                profile.durationScale = 0.6
                profile.allowOctaveDoubling = false
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
                profile.sustains = false   // plucked, re-articulates
            case .stringEnsemble, .slowStrings, .synthStrings1, .synthStrings2, .synthStrings3, .padOrchestral:
                profile.maxNotes = 4
                profile.preferOpenVoicing = true
                profile.extensionBias = 0.1
                profile.sustains = true
            case .choirAahs, .voiceOohs:
                profile.maxNotes = 3
                profile.preferOpenVoicing = true
                profile.extensionBias = 0.15
                profile.sustains = true
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
                profile.sustains = false   // staccato organ, re-articulates
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
            case .synthBass, .synthBass2, .analogBass, .synthAnalogBass, .synthSubBass:
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
        case .electricPiano, .electricPiano2, .vintageElectricPiano, .electricGrandPiano:
            return 2
        case .honkyTonkPiano, .harpsichord, .clavinet:
            return 4
        case .mutedGuitar:
            return -6
        case .overdriveGuitar, .distortionGuitar:
            return 8
        case .brassSection, .synthBrass1, .synthBrass2:
            return style == .rock ? 4 : -4
        case .tremoloStrings, .stringEnsemble, .slowStrings, .padOrchestral:
            return -8
        case .synthStrings1, .synthStrings2, .synthStrings3:
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

    private static func clampVelocity(_ velocity: Int) -> Int {
        min(127, max(25, velocity))
    }

    /// Metric accent in velocity units: downbeats push forward, offbeat
    /// ("and") hits sit back. Position is in beats within the bar.
    private static func metricAccent(positionInBar: Double, beatsPerBar: Int) -> Int {
        let nearestBeat = positionInBar.rounded()
        let isOnBeat = abs(positionInBar - nearestBeat) < 0.01
        guard isOnBeat else { return -5 }
        let beat = Int(nearestBeat) % max(1, beatsPerBar)
        if beat == 0 { return 6 }
        if beatsPerBar % 2 == 0, beat == beatsPerBar / 2 { return 2 }
        return 0
    }

    /// Keeps the bass note plus the top voices when a chord has too many
    /// notes. Dropping inner voices keeps the harmony clear; keeping the
    /// lowest notes (old behavior) clustered everything in the mud register.
    private static func trimVoices(_ pitches: [Int], keep: Int) -> [Int] {
        let sorted = uniqueSorted(pitches)
        guard sorted.count > keep, keep >= 1 else { return sorted }
        guard keep > 1 else { return [sorted[0]] }
        return [sorted[0]] + Array(sorted.suffix(keep - 1))
    }

    /// Harmonic importance of a voice for trimming decisions — the 3rd and 7th
    /// (guide tones) define the chord quality and must outrank the easily
    /// dropped perfect 5th.
    private static func voiceImportance(_ pitch: Int, rootPitch: Int) -> Int {
        let iv = ((pitch - rootPitch) % 12 + 12) % 12
        switch iv {
        case 3, 4:        return 6   // third
        case 10, 11:      return 6   // seventh
        case 6, 8:        return 5   // altered 5th — defines dim/aug
        case 9:           return 4   // 6th / dim7 / 13th color
        case 2, 5:        return 3   // sus / 9 / 11 color
        case 0:           return 3   // root
        case 7:           return 1   // perfect 5th — first to go
        default:          return 2
        }
    }

    /// Trims to `keep` voices while preserving the guide tones: always keeps the
    /// bass and the top, then fills the middle by harmonic importance (so the
    /// 3rd/7th survive and the 5th is dropped first).
    private static func trimVoicesHarmonic(_ pitches: [Int], rootPitch: Int, keep: Int) -> [Int] {
        let sorted = uniqueSorted(pitches)
        guard sorted.count > keep, keep >= 1 else { return sorted }
        guard keep > 1 else { return [sorted[0]] }

        var kept: Set<Int> = [sorted.first!, sorted.last!]
        let middle = sorted.dropFirst().dropLast()
            .sorted { voiceImportance($0, rootPitch: rootPitch) > voiceImportance($1, rootPitch: rootPitch) }
        for pitch in middle where kept.count < keep {
            kept.insert(pitch)
        }
        return kept.sorted()
    }

    /// Picks the chord inversion that moves least from the previous voicing,
    /// weighting top-voice continuity — smooth comping instead of parallel
    /// root-position jumps.
    private static func voiceLead(_ pitches: [Int], previous: [Int], range: ClosedRange<Int>) -> [Int] {
        guard !previous.isEmpty, pitches.count > 1 else { return uniqueSorted(pitches) }

        let voiceCount = uniqueSorted(pitches).count

        func cost(_ candidate: [Int]) -> Int {
            var total = 0
            for pitch in candidate {
                total += previous.map { abs(pitch - $0) }.min() ?? 0
            }
            if let top = candidate.max(), let previousTop = previous.max() {
                total += abs(top - previousTop) * 2
            }
            return total
        }

        var best = uniqueSorted(pitches)
        var bestCost = cost(best)

        var rising = best
        for _ in 0..<max(0, best.count - 1) {
            guard let lowest = rising.min() else { break }
            rising = uniqueSorted(rising.filter { $0 != lowest } + [lowest + 12])
            guard rising.allSatisfy({ range.contains($0) }) else { break }
            // Never accept an inversion that lost a voice to an octave collision —
            // that would silently drop a chord tone.
            guard rising.count == voiceCount else { continue }
            let candidateCost = cost(rising)
            if candidateCost < bestCost {
                best = rising
                bestCost = candidateCost
            }
        }

        var falling = uniqueSorted(pitches)
        for _ in 0..<max(0, falling.count - 1) {
            guard let highest = falling.max() else { break }
            falling = uniqueSorted(falling.filter { $0 != highest } + [highest - 12])
            guard falling.allSatisfy({ range.contains($0) }) else { break }
            guard falling.count == voiceCount else { continue }
            let candidateCost = cost(falling)
            if candidateCost < bestCost {
                best = falling
                bestCost = candidateCost
            }
        }

        return best
    }

    /// Opens up voices packed tighter than a fourth below G3 — close low
    /// intervals turn to mud with realistic samples. It only ever moves a voice
    /// up by an octave (preserving the chord tone); if it can't, it leaves the
    /// voice in place rather than dropping a chord tone.
    private static func avoidLowIntervalMud(_ pitches: [Int], range: ClosedRange<Int>) -> [Int] {
        var sorted = uniqueSorted(pitches)
        guard sorted.count > 2 else { return sorted }   // keep small voicings intact
        var index = 1
        var safety = 0
        while index < sorted.count, safety < 64 {
            safety += 1
            let lower = sorted[index - 1]
            let upper = sorted[index]
            if lower < 55, upper - lower < 5 {
                let raised = upper + 12
                if raised <= range.upperBound, !sorted.contains(raised) {
                    sorted[index] = raised
                    sorted = uniqueSorted(sorted)
                    index = 1
                    continue
                }
                // Can't cleanly raise — leave it rather than drop a chord tone.
            }
            index += 1
        }
        return sorted
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

    /// Octave-folds any out-of-range voices back inside the instrument range,
    /// preserving their pitch class. Voicing transforms (open / drop-2 / divisi)
    /// displace notes by octaves and can overshoot the range — folding keeps
    /// every chord tone instead of dropping it.
    private static func foldIntoRange(_ pitches: [Int], _ range: ClosedRange<Int>) -> [Int] {
        let folded = pitches.map { pitch -> Int in
            var value = pitch
            while value > range.upperBound { value -= 12 }
            while value < range.lowerBound { value += 12 }
            return max(range.lowerBound, min(range.upperBound, value))
        }
        return uniqueSorted(folded)
    }

    /// Divisi spacing for strings — opens the chord across the cello/viola/
    /// violin registers. Critically it only moves voices by **octaves**, so the
    /// chord tones (and thus the quality) are preserved; it never rewrites a
    /// 3rd into a 5th.
    private static func divisiSpacing(_ pitches: [Int], range: ClosedRange<Int>) -> [Int] {
        var sorted = uniqueSorted(pitches)
        // Drop the lowest voice an octave for a cello-like foundation.
        if let first = sorted.first, first > 55, range.contains(first - 12) {
            sorted[0] = first - 12
        }
        // Lift the top voice an octave for violin sheen when the chord is cramped.
        if sorted.count >= 3, let last = sorted.last, last < 67, range.contains(last + 12) {
            sorted[sorted.count - 1] = last + 12
        }
        return foldIntoRange(sorted, range)
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
            if let v = variant, [.padNewAge, .padWarm, .padPolysynth, .padChoir, .padBowed, .padMetallic, .padHalo, .padSweep, .padSoundtrack, .padAtmosphere, .synthAnalogPad, .synthGlassPad, .synthSupersaw].contains(v) {
                return 0.95
            }
            return 0.70
        case .bass:      return 0.70
        default:         return 0.80
        }
    }

    /// Style-aware velocity curve — non-linear intensity response centered on
    /// the style/instrument base velocity, so Lo-Fi stays soft and Rock stays
    /// loud regardless of the intensity slider position.
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
        // intensity 0.5 lands near `base`; full range swings ±25 around it.
        let velocity = Double(base) + (curved - 0.5) * 50.0
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
                // Driving eighths — the engine of a rock arrangement.
                offsets = stride(from: 0, to: chordDuration, by: offbeat).map { $0 }
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

        // Strummed acoustic styles stay on the beat; rock/funk/EDM guitars
        // keep their off-beat drive.
        if instrument == .guitar, [.pop, .jazz, .lofi, .ambient, .hiphop].contains(style) {
            offsets = offsets.filter { abs($0.rounded() - $0) < 0.001 }
            if offsets.isEmpty {
                offsets = [0]
            }
        }

        let clamped = offsets
            .filter { $0 >= 0 && $0 < chordDuration }
            .map { quantize($0, step: timeBottom == 8 ? quantStep : min(quantStep, 0.25)) }

        let sorted = uniqueSorted(clamped)

        // Complexity thins the pattern *by metric importance* (downbeat, then
        // mid-bar, then beats, then off-beats) — never by chopping the end of
        // the bar off. At the default (0.5) and above the style pattern plays
        // in full.
        let keepFraction = min(1.0, 0.35 + 1.3 * max(0, min(1, complexity)))
        let numHitsToKeep = max(1, Int((Double(sorted.count) * keepFraction).rounded()))
        guard numHitsToKeep < sorted.count else { return sorted }
        func weight(_ offset: Double) -> Int {
            if offset < 0.001 { return 4 }
            if abs(offset - midBeat) < 0.001 { return 3 }
            if abs(offset.rounded() - offset) < 0.001 { return 2 }
            return 1
        }
        let kept = sorted
            .enumerated()
            .sorted { lhs, rhs in
                weight(lhs.element) != weight(rhs.element)
                    ? weight(lhs.element) > weight(rhs.element)
                    : lhs.offset < rhs.offset
            }
            .prefix(numHitsToKeep)
            .map(\.element)
        return uniqueSorted(kept)
    }

    private static func explicitCompingOffsets(
        for comping: CompingPattern,
        beatsPerBar: Int,
        timeBottom: Int,
        chordDuration: Double
    ) -> [Double]? {
        let beat = timeBottom == 8 ? Double(max(1, beatsPerBar / 2)) : 1.0
        let halfBeat = beat / 2.0

        func clipped(_ offsets: [Double]) -> [Double] {
            let valid = uniqueSorted(offsets.filter { $0 >= 0 && $0 < chordDuration })
            return valid.isEmpty ? [0.0] : valid
        }

        switch comping {
        case .offbeat:
            return clipped(Array(stride(from: halfBeat, to: chordDuration, by: beat)))
        case .pulse:
            return clipped(Array(stride(from: 0.0, to: chordDuration, by: beat)))
        case .stabs:
            var offsets = [0.0]
            if chordDuration >= beat + halfBeat {
                offsets.append(beat + halfBeat)
            }
            if chordDuration >= beat * 3.0 {
                offsets.append(beat * 2.5)
            }
            return clipped(offsets)
        case .anticipation:
            let push = max(halfBeat, chordDuration - halfBeat)
            return clipped([0.0, push])
        case .waltz:
            return clipped([0.0, beat, beat * 2.0])
        case .tremolo:
            let tremoloStep = max(0.25, halfBeat)
            return clipped(Array(stride(from: 0.0, to: chordDuration, by: tremoloStep)))
        case .auto, .block, .sustained, .arpeggioUp, .arpeggioDown, .arpeggioUpDown, .alberti, .ostinato:
            return nil
        }
    }

    private static func compingDurationScale(for comping: CompingPattern) -> Double {
        switch comping {
        case .stabs:
            return 0.35
        case .offbeat, .anticipation:
            return 0.55
        case .pulse, .waltz:
            return 0.75
        case .tremolo:
            return 0.3
        case .auto, .block, .sustained, .arpeggioUp, .arpeggioDown, .arpeggioUpDown, .alberti, .ostinato:
            return 1.0
        }
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
            } else {
                baseDurationValue = min(remaining, 1.5)
            }

        case .rock:
            if instrument == .guitar {
                baseDurationValue = min(remaining, 0.64) // Driving eighths, slightly detached
            } else if instrument == .piano {
                baseDurationValue = min(remaining, 1.0)
            } else {
                baseDurationValue = min(remaining, 1.25)
            }

        case .edm:
            if instrument == .synth {
                baseDurationValue = min(remaining, shortHit) // Stabs
            } else if instrument == .piano {
                baseDurationValue = min(remaining, 0.75)
            } else {
                baseDurationValue = min(remaining, 1.0)
            }

        case .jazz:
            // Medium-short for comp feel
            if instrument == .piano {
                baseDurationValue = min(remaining, 0.5)
            } else if instrument == .guitar {
                baseDurationValue = min(remaining, 0.75)
            } else {
                baseDurationValue = min(remaining, 0.75)
            }

        case .hiphop:
            // Long, sustained
            baseDurationValue = remaining

        case .funk:
            if instrument == .guitar {
                baseDurationValue = min(remaining, 0.5) // Short, percussive
            } else if instrument == .piano {
                baseDurationValue = min(remaining, 0.25) // Very short stabs
            } else {
                baseDurationValue = min(remaining, 1.0)
            }

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
            // Half-time space: kick on one, snare on the middle of the bar.
            kickOffsets = [pulseOffsets.first ?? 0]
            snareOffsets = [halfTimeSnareOffset(meter: meter)]
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
        case .boomBap:
            // Head-nod groove: kick on 1, the "and" of 2 and on 3½-ish,
            // snare on the backbeats, steady eighth hats (swing comes from
            // the style's feel pass).
            if meter.timeBottom == 4 && meter.beatsPerBar == 4 {
                kickOffsets = [0.0, 1.5, 2.75]
            } else {
                kickOffsets = basicKickOffsets(meter: meter)
            }
            snareOffsets = backbeatOffsets.isEmpty ? [Double(max(1, meter.beatsPerBar - 1))] : backbeatOffsets
            hatSteps = stepsFromOffsets(
                meter.timeBottom == 4 ? beatOffsets + offbeatOffsets : beatOffsets,
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
