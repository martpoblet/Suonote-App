import Foundation

/// Writes pop and rock bass lines the way a session bassist plays them,
/// instead of looping one figure per chord:
/// - **Locks to the kick.** Reads the drum track's kicks (or the style's
///   groove when there is no drum part yet) and plays on them.
/// - **Follows the song.** Held roots in light verses, the kick pocket in
///   fuller verses, driving eighths through pre-choruses, a bouncier line with
///   octave pops in choruses.
/// - **Connects the chords.** Diatonic approach notes, a walk-up into big
///   sections and a small fill closing every four-bar phrase.
/// - **Articulates.** Notes stop just before the next one, pick-ups are short,
///   and the odd muted ghost note gives the groove a bounce.
@MainActor
enum StudioBassComposer {

    /// Song-wide facts the bass line reacts to.
    struct SongContext {
        let map: StudioArranger.SongMap
        /// Kick offsets per bar (quantized to 16ths) played by the drum track.
        let kicksByBar: [Int: [Double]]
        /// One bar of the drum groove's kicks, for bars the drum track doesn't cover.
        let kickTemplate: [Double]
        let keyPitchClass: Int
        let scale: [Int]

        init(project: Project, style: StudioStyle) {
            map = StudioArranger.songMap(for: project)
            keyPitchClass = ChordPreviewPlayer.pitchClass(of: project.keyRoot) ?? 0
            scale = project.keyMode.intervals
            let beatsPerBar = Double(max(1, project.timeTop))
            let drums = project.studioTracks.first { $0.instrument == .drums }

            var byBar: [Int: Set<Double>] = [:]
            for note in drums?.notes ?? [] where note.pitch == 35 || note.pitch == 36 {
                let beat = (note.startBeat * 4).rounded() / 4
                let bar = Int((beat / beatsPerBar + 0.0001).rounded(.down))
                byBar[bar, default: []].insert(beat - Double(bar) * beatsPerBar)
            }
            kicksByBar = byBar.mapValues { $0.sorted() }

            let preset = drums?.drumPreset ?? DrumPreset.defaultPreset(
                for: style, beatsPerBar: project.timeTop, timeBottom: project.timeBottom
            )
            let groove = StudioGenerator.generateDrumNotes(
                totalBars: 1, beatsPerBar: project.timeTop, timeBottom: project.timeBottom,
                style: style, preset: preset, variant: drums?.variant
            )
            kickTemplate = Array(Set(groove
                .filter { $0.pitch == 35 || $0.pitch == 36 }
                .map { ($0.startBeat * 4).rounded() / 4 }
                .filter { $0 < beatsPerBar }))
                .sorted()
        }
    }

    struct Line {
        let chords: [StudioGenerator.ChordSpan]
        let pattern: BassPattern
        let style: StudioStyle
        let beatsPerBar: Int
        let range: ClosedRange<Int>
        let velocity: Int
        let song: SongContext?
    }

    /// The patterns (and meters) this composer writes; the rest keep the
    /// per-chord figures in `StudioGenerator`.
    static func composes(_ pattern: BassPattern, beatsPerBar: Int, timeBottom: Int) -> Bool {
        timeBottom == 4 && beatsPerBar == 4 && (pattern == .pocket || pattern == .drive)
    }

    // MARK: - Composition

    private struct Harmony {
        let start: Double
        let end: Double
        /// Bass pitch class (the slash note for inversions).
        let root: Int
        /// Pitch class of the chord's own fifth (A for D/F#, not C#).
        let fifth: Int
    }

    private enum Kind: Equatable {
        case root, fifth, octave, approach, ghost
        /// Scale steps away from the next root (negative = below).
        case walk(Int)
    }

    private enum Articulation {
        case hold, short, ghost, walk
    }

    private struct Hit {
        let beat: Double
        let kind: Kind
        let articulation: Articulation
        let accent: Int
        /// Fills and approaches win over the groove when two land together.
        let priority: Int
    }

    static func compose(_ line: Line) -> [StudioNote] {
        let harmonies = line.chords.compactMap { span -> Harmony? in
            let slash = span.chord.slashRoot.flatMap { $0.isEmpty ? nil : $0 }
            guard let chordRoot = ChordPreviewPlayer.pitchClass(of: span.chord.root),
                  let root = ChordPreviewPlayer.pitchClass(of: slash ?? span.chord.root),
                  span.duration > 0.01 else { return nil }
            let tones = StudioGenerator.harmonicTones(for: span.chord.quality)
            return Harmony(start: span.startBeat, end: span.startBeat + span.duration,
                           root: root, fifth: (chordRoot + tones.fifth) % 12)
        }.sorted { $0.start < $1.start }
        guard let first = harmonies.first, let last = harmonies.last else { return [] }

        let bpb = Double(line.beatsPerBar)
        let firstBar = Int((first.start / bpb + 0.0001).rounded(.down))
        let lastBar = Int(((last.end - 0.001) / bpb).rounded(.down))

        var hits: [Hit] = []
        for bar in firstBar...lastBar {
            hits += barHits(bar: bar, line: line, harmonies: harmonies, songEnd: last.end)
        }
        // One hit per position; fills/approaches replace the groove note.
        var byBeat: [Double: Hit] = [:]
        for hit in hits {
            let key = (hit.beat * 4).rounded() / 4
            if let existing = byBeat[key], existing.priority >= hit.priority { continue }
            byBeat[key] = hit
        }
        let ordered = byBeat.values
            .filter { beat in harmonies.contains { beat.beat >= $0.start - 0.001 && beat.beat < $0.end - 0.001 } }
            .sorted { $0.beat < $1.beat }

        return render(ordered, harmonies: harmonies, line: line, songEnd: last.end)
    }

    /// The rhythm (and role of each note) for one bar.
    private static func barHits(bar: Int, line: Line, harmonies: [Harmony], songEnd: Double) -> [Hit] {
        let bpb = Double(line.beatsPerBar)
        let barStart = Double(bar) * bpb
        let map = line.song?.map
        let span = map?.isStructured == true ? map?.span(at: barStart + 0.01) : nil
        let energy = span?.energy ?? 3
        let barInSection = span.map { Int(((barStart - $0.startBeat) / bpb).rounded()) } ?? bar
        let sectionBars = span?.bars ?? Int.max
        let isSectionEnd = span != nil && barInSection == sectionBars - 1
        let isPhraseEnd = isSectionEnd || barInSection % 4 == 3
        let isSongEnd = barStart + bpb >= songEnd - 0.01
        let style = line.style

        // Kicks on the eighth-note grid (sixteenth kicks are drum detail, not bass rhythm).
        let kicks = (line.song?.kicksByBar[bar] ?? line.song?.kickTemplate ?? [0, 2])
            .filter { $0 < bpb - 0.01 && abs(($0 * 2).rounded() - $0 * 2) < 0.01 }

        func harmony(at beat: Double) -> Harmony? {
            harmonies.first { beat >= $0.start - 0.001 && beat < $0.end - 0.001 }
        }
        func sameChordThroughBar() -> Bool {
            guard let h = harmony(at: barStart) else { return false }
            return h.end >= barStart + bpb - 0.01
        }
        // Chord changes inside the bar always get a root.
        let changes = harmonies.map(\.start).filter { $0 > barStart + 0.01 && $0 < barStart + bpb - 0.01 }

        var result: [Hit] = []
        func add(_ offset: Double, _ kind: Kind, _ articulation: Articulation, accent: Int = 0, priority: Int = 0) {
            result.append(Hit(beat: barStart + offset, kind: kind, articulation: articulation, accent: accent, priority: priority))
        }

        // Last bar of the song: one ringing root.
        if isSongEnd {
            add(0, .root, .hold, accent: 6)
            for change in changes { add(change - barStart, .root, .hold, accent: 2) }
            return result
        }

        switch (line.pattern, energy) {
        case (_, ...1):
            add(0, .root, .hold, accent: 4)
        case (.drive, 2):
            for beat in 0..<line.beatsPerBar { add(Double(beat), .root, .short, accent: beat == 0 ? 8 : 0) }
        case (_, 2):
            // Light verse: hold the roots on 1 and 3, the fifth now and then.
            add(0, .root, .hold, accent: 6)
            add(2, bar % 2 == 1 && sameChordThroughBar() ? .fifth : .root, .hold, accent: 0)
        case (.drive, _):
            for step in 0..<(line.beatsPerBar * 2) {
                let offset = Double(step) * 0.5
                let onBeat = step % 2 == 0
                var kind: Kind = .root
                if energy >= 5, sameChordThroughBar() {
                    if offset == 2.5, barInSection % 2 == 1 { kind = .octave }
                    if offset == 2.0, barInSection % 4 == 2 { kind = .fifth }
                }
                let accent = offset == 0 ? 10 : (kicks.contains(offset) ? 4 : (onBeat ? 1 : -8))
                add(offset, kind, .short, accent: accent)
            }
        case (_, 4):
            // Pre-chorus: steady eighths on the root, building.
            for step in 0..<(line.beatsPerBar * 2) {
                let offset = Double(step) * 0.5
                let onKick = offset == 0 || kicks.contains(offset)
                add(offset, .root, onKick ? .hold : .short, accent: onKick ? 5 : (step % 2 == 0 ? -1 : -9))
            }
        case (_, 3):
            // The pocket: play with the kick, bounce on the "and" of 2.
            add(0, .root, .hold, accent: 8)
            for kick in kicks where kick > 0 {
                let onThree = abs(kick - 2) < 0.01
                let isFifth = onThree && bar % 2 == 1 && sameChordThroughBar()
                add(kick, isFifth ? .fifth : .root, .hold, accent: 3, priority: isFifth ? 1 : 0)
            }
            if !kicks.contains(where: { $0.truncatingRemainder(dividingBy: 1) > 0.25 }), bar % 2 == 1 {
                add(1.5, .root, .short, accent: -7)
            }
            if [.pop, .funk, .hiphop].contains(style), bar % 4 == 2, kicks.contains(2) {
                add(1.75, .ghost, .ghost)
            }
        default:
            // Chorus: kick-locked roots, short pushes, an octave pop every other bar.
            add(0, .root, .hold, accent: 10)
            for kick in kicks where kick > 0 { add(kick, .root, .hold, accent: 4) }
            for push in [1.5, 3.5] where !kicks.contains(push) { add(push, .root, .short, accent: -6) }
            if sameChordThroughBar() {
                if barInSection % 2 == 1 { add(2.5, .octave, .short, accent: -2) }
                if barInSection % 4 == 2 { add(2, .fifth, .hold, accent: 2, priority: 1) }
            }
            if [.pop, .funk].contains(style), barInSection % 4 == 0, !kicks.contains(1.5) { add(1.25, .ghost, .ghost) }
        }

        for change in changes { add(change - barStart, .root, .hold, accent: 4, priority: 1) }

        // Approach the next chord on the last eighth before it changes.
        let nextChange = harmonies.first { $0.start > barStart + 0.01 && $0.start <= barStart + bpb + 0.01 }
        if energy >= 2, let next = nextChange, let current = harmony(at: next.start - 0.25), current.root != next.root {
            let approachBeat = next.start - 0.5 - barStart
            let wantsApproach = energy >= 3 ? (isPhraseEnd || bar % 2 == 1 || line.pattern == .drive) : isSectionEnd
            if approachBeat >= 1, wantsApproach {
                add(approachBeat, .approach, .short, accent: -3, priority: 2)
            }
        }

        // Fills that close a section or a four-bar phrase.
        let nextRole = isSectionEnd ? span?.nextRole : nil
        let bigEntrance = nextRole.map { [.chorus, .preChorus, .postChorus, .solo].contains($0) } ?? false
        if isSectionEnd, bigEntrance, energy >= 2, sameChordThroughBar() {
            result.removeAll { $0.beat >= barStart + 2 - 0.01 }
            for (i, steps) in [-4, -3, -2, -1].enumerated() {
                add(2 + Double(i) * 0.5, .walk(steps), .walk, accent: -4 + i * 3, priority: 3)
            }
        } else if isPhraseEnd, energy >= 3, sameChordThroughBar() {
            let phrase = barInSection / 4
            result.removeAll { $0.beat >= barStart + 3 - 0.01 }
            if phrase % 2 == 0 {
                add(3, .octave, .short, accent: 0, priority: 3)
                add(3.5, .approach, .short, accent: -2, priority: 3)
            } else {
                add(3, .root, .short, accent: 0, priority: 3)
                add(3.5, .walk(2), .short, accent: -4, priority: 3)
                add(3.75, .walk(1), .short, accent: -2, priority: 3)
            }
        }
        return result
    }

    // MARK: - Pitches, lengths, dynamics

    private static func render(_ hits: [Hit], harmonies: [Harmony], line: Line, songEnd: Double) -> [StudioNote] {
        let range = line.range
        // Roots live in the bottom octave of the range (A1–A2 by default).
        let home = range.lowerBound...min(range.upperBound, range.lowerBound + 12)
        let keyPC = line.song?.keyPitchClass ?? harmonies.first?.root ?? 0
        let scalePCs = Set((line.song?.scale ?? KeyMode.major.intervals).map { (keyPC + $0) % 12 })
        let bpb = Double(line.beatsPerBar)
        let map = line.song?.map

        func pitches(_ pc: Int, in r: ClosedRange<Int>) -> [Int] {
            var p = r.lowerBound + ((pc - r.lowerBound % 12) + 12) % 12
            var out: [Int] = []
            while p <= r.upperBound { out.append(p); p += 12 }
            return out
        }
        func voiceLead(_ pc: Int, from previous: Int) -> Int {
            let candidates = pitches(pc, in: home)
            return candidates.min { abs($0 - previous) < abs($1 - previous) } ?? previous
        }
        func scaleStep(from target: Int, steps: Int) -> Int {
            var pitch = target
            var remaining = abs(steps)
            let direction = steps < 0 ? -1 : 1
            while remaining > 0 {
                pitch += direction
                if scalePCs.contains(((pitch % 12) + 12) % 12) { remaining -= 1 }
            }
            return pitch
        }

        var rootPitch: [Int: Int] = [:]   // harmony index → voiced root
        var previous = voiceLead(keyPC, from: (home.lowerBound + home.upperBound) / 2)
        for (index, h) in harmonies.enumerated() {
            previous = voiceLead(h.root, from: previous)
            rootPitch[index] = previous
        }
        func harmonyIndex(at beat: Double) -> Int? {
            harmonies.firstIndex { beat >= $0.start - 0.001 && beat < $0.end - 0.001 }
        }
        func nextRoot(after index: Int) -> Int? {
            index + 1 < harmonies.count ? rootPitch[index + 1] : nil
        }

        var notes: [StudioNote] = []
        for (i, hit) in hits.enumerated() {
            guard let hIndex = harmonyIndex(at: hit.beat), let root = rootPitch[hIndex] else { continue }
            let h = harmonies[hIndex]
            // The chord's fifth above the bass note — or the one below when the
            // root already sits high, so the line stays in the bass register.
            let fifthUp = root + ((h.fifth - root % 12) + 12) % 12
            let fifthDown = fifthUp - 12
            let fifth = (fifthUp > home.upperBound || fifthUp > range.upperBound) && fifthDown >= range.lowerBound
                ? fifthDown
                : min(fifthUp, range.upperBound)
            let target = nextRoot(after: hIndex) ?? root

            var pitch: Int
            switch hit.kind {
            case .root, .ghost:
                pitch = root
            case .fifth:
                pitch = fifth
            case .octave:
                // Octave pop up, or an octave drop when there's no room above.
                pitch = root + 12 <= range.upperBound ? root + 12 : (root - 12 >= range.lowerBound ? root - 12 : fifth)
            case .approach:
                if target == root {
                    pitch = fifth
                } else if abs(target - root) <= 2 {
                    // Moving by step: restrike the root, the step is the approach.
                    pitch = root
                } else if line.style == .jazz {
                    pitch = target > root ? target - 1 : target + 1
                } else {
                    let neighbour = scaleStep(from: target, steps: target > root ? -1 : 1)
                    let chromatic = target > root ? target - 1 : target + 1
                    pitch = neighbour == root ? (chromatic == root ? fifth : chromatic) : neighbour
                }
            case .walk(let steps):
                // Pick one direction for the whole fill: up from below when
                // there's room under the target, otherwise down from above.
                let roomBelow = scaleStep(from: target, steps: -4) >= range.lowerBound
                let roomAbove = scaleStep(from: target, steps: 4) <= range.upperBound
                let fromBelow = steps < 0 ? roomBelow || !roomAbove : !(roomAbove || !roomBelow)
                pitch = scaleStep(from: target, steps: fromBelow ? -abs(steps) : abs(steps))
            }
            pitch = min(range.upperBound, max(range.lowerBound, pitch))

            // Length: stop just before the next note, like a player muting the string.
            let nextBeat = i + 1 < hits.count ? hits[i + 1].beat : songEnd + bpb
            let gap = max(0.1, nextBeat - hit.beat)
            let span = map?.isStructured == true ? map?.span(at: hit.beat) : nil
            let energy = span?.energy ?? 3
            var duration: Double
            switch hit.articulation {
            case .hold:
                let release = line.pattern == .drive ? 0.12 : 0.1
                let cap = energy <= 2 ? bpb : 1.75
                duration = min(cap, gap - release)
            case .short:
                duration = min(gap - 0.06, hit.beat.truncatingRemainder(dividingBy: 1) < 0.01 ? 0.4 : 0.3)
            case .ghost:
                duration = 0.09
            case .walk:
                duration = min(0.44, gap - 0.04)
            }
            // The last note before the bass rests (or the song ends) rings out.
            if i + 1 == hits.count || nextBeat - hit.beat > bpb {
                let barEnd = (hit.beat / bpb + 0.0001).rounded(.down) * bpb + bpb
                duration = max(duration, min(songEnd, barEnd) - hit.beat - 0.05)
            }
            duration = max(0.08, duration)

            var velocity = line.velocity + hit.accent
            if hit.kind == .ghost { velocity = max(30, line.velocity / 2 - 4) }
            if let span, span.energy == 4, span.bars > 1 {
                // Pre-chorus builds bar by bar.
                let progress = (hit.beat - span.startBeat) / (Double(span.bars) * bpb)
                velocity += Int((progress * 9).rounded()) - 3
            }
            notes.append(StudioNote(startBeat: hit.beat, duration: duration, pitch: pitch,
                                    velocity: max(30, min(127, velocity))))
        }
        return notes
    }
}
