import Foundation

/// Turns generated parts into an *arrangement*: instruments enter, drop out,
/// thin and build with the song's structure instead of playing the same
/// loop from intro to outro (the single biggest reason generated songs
/// sounded "MIDI"). Also writes drum fills into section changes and a crash
/// on big downbeats.
///
/// Pure function over notes: it never touches hand-edited tracks unless the
/// track is regenerated, and each track can opt out (`followsArrangement`).
@MainActor
enum StudioArranger {

    // MARK: - Song map

    enum Role: Equatable {
        case intro, verse, preChorus, chorus, postChorus, bridge, breakdown, solo, outro, other

        static func from(name: String) -> Role {
            let n = name.lowercased()
                .folding(options: .diacriticInsensitive, locale: nil)
            func has(_ keys: String...) -> Bool { keys.contains { n.contains($0) } }
            if has("pre-chorus", "prechorus", "pre chorus", "pre-coro", "precoro", "pre coro", "pre-estribillo", "build") { return .preChorus }
            if has("post-chorus", "postchorus", "post coro") { return .postChorus }
            if has("chorus", "coro", "estribillo", "hook", "refrain", "drop") { return .chorus }
            if has("verse", "estrofa", "verso") { return .verse }
            if has("bridge", "puente", "middle 8") { return .bridge }
            if has("intro") { return .intro }
            if has("outro", "final", "coda", "ending", "cierre") { return .outro }
            if has("breakdown", "break", "interlude", "interludio") { return .breakdown }
            if has("solo", "instrumental") { return .solo }
            if n.hasPrefix("pre") { return .preChorus }
            return .other
        }
    }

    struct Span {
        let startBeat: Double
        let endBeat: Double
        let bars: Int
        let role: Role
        /// 0 for the first verse, 1 for the second…
        let occurrence: Int
        /// 1 (whisper) … 5 (everything).
        let energy: Int
        let nextRole: Role?
        let isLastOfRole: Bool
    }

    struct SongMap {
        let spans: [Span]
        let beatsPerBar: Int

        func span(at beat: Double) -> Span? {
            spans.first { beat >= $0.startBeat - 0.001 && beat < $0.endBeat - 0.001 }
        }

        /// The map is only meaningful when the song has some structure.
        var isStructured: Bool {
            Set(spans.map(\.role)).count >= 2
        }
    }

    static func songMap(for project: Project) -> SongMap {
        let beatsPerBar = project.timeTop
        let items = project.arrangementItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { item -> (String, Int)? in
                guard let section = item.sectionTemplate else { return nil }
                return (item.labelOverride?.isEmpty == false ? item.labelOverride! : section.name, max(1, section.bars))
            }
        let roles = items.map { Role.from(name: $0.0) }
        var counts: [Role: Int] = [:]
        let totals = roles.reduce(into: [Role: Int]()) { $0[$1, default: 0] += 1 }
        var spans: [Span] = []
        var bar = 0
        for (index, item) in items.enumerated() {
            let role = roles[index]
            let occurrence = counts[role, default: 0]
            counts[role] = occurrence + 1
            let isLast = occurrence + 1 == totals[role, default: 1]
            spans.append(Span(
                startBeat: Double(bar * beatsPerBar),
                endBeat: Double((bar + item.1) * beatsPerBar),
                bars: item.1,
                role: role,
                occurrence: occurrence,
                energy: energy(for: role, occurrence: occurrence, isLast: isLast),
                nextRole: index + 1 < roles.count ? roles[index + 1] : nil,
                isLastOfRole: isLast
            ))
            bar += item.1
        }
        return SongMap(spans: spans, beatsPerBar: beatsPerBar)
    }

    private static func energy(for role: Role, occurrence: Int, isLast: Bool) -> Int {
        switch role {
        case .intro: return 1
        case .verse: return occurrence == 0 ? 2 : 3
        case .preChorus: return 4
        case .chorus: return 5
        case .postChorus: return 4
        case .bridge: return 2
        case .breakdown: return 1
        case .solo: return 4
        case .outro: return 1
        case .other: return 3
        }
    }

    // MARK: - Parts

    private enum Part {
        case drums, bass, primaryHarmony, secondaryHarmony, pad, strings, organ, brass, lead, mallets
    }

    private static func part(
        for instrument: StudioInstrument,
        variant: InstrumentVariant?,
        band: Set<StudioInstrument>
    ) -> Part {
        switch instrument {
        case .drums: return .drums
        case .bass: return .bass
        case .piano: return .primaryHarmony
        case .guitar: return band.contains(.piano) ? .secondaryHarmony : .primaryHarmony
        case .synth:
            if StudioSoundCatalog.role(for: .synth, variant: variant) == .lead { return .lead }
            return band.contains(.piano) || band.contains(.guitar) ? .pad : .primaryHarmony
        case .organ:
            return band.contains(.piano) || band.contains(.guitar) ? .organ : .primaryHarmony
        case .strings:
            return band.contains(.piano) || band.contains(.guitar) || band.contains(.synth) ? .strings : .primaryHarmony
        case .brass: return .brass
        case .woodwinds: return .lead
        case .mallets: return .mallets
        case .audio: return .pad
        }
    }

    /// Does this part play in this section at all?
    private static func plays(_ part: Part, in span: Span, style: StudioStyle) -> Bool {
        switch part {
        case .primaryHarmony:
            return true
        case .drums:
            // Pop intros and outros breathe without drums; groove styles keep the beat.
            if [.edm, .hiphop, .funk, .lofi].contains(style) { return span.role != .outro || span.bars > 4 }
            return span.energy >= 2 || span.role == .outro
        case .bass:
            return span.energy >= 2 || span.role == .outro
        case .secondaryHarmony:
            // Plays from the first verse on (lightly there), rests in
            // intros/breakdowns and gives the bridge some air.
            return span.energy >= 2 && span.role != .bridge
        case .pad:
            return true
        case .strings:
            return span.energy >= 4 || span.role == .bridge || span.role == .outro
        case .organ:
            return span.energy >= 3
        case .brass:
            return span.energy >= 5
        case .lead:
            return [.intro, .bridge, .solo, .outro].contains(span.role) || (span.role == .chorus && span.isLastOfRole)
        case .mallets:
            return [.intro, .chorus, .postChorus, .outro].contains(span.role)
        }
    }

    // MARK: - Arrange

    /// Arranges a freshly generated part. `limit` restricts edits/insertions
    /// to a beat range (partial regeneration).
    static func arrange(
        _ notes: [StudioNote],
        instrument: StudioInstrument,
        variant: InstrumentVariant?,
        project: Project,
        style: StudioStyle,
        limit: ClosedRange<Double>? = nil
    ) -> [StudioNote] {
        guard instrument != .audio, !notes.isEmpty else { return notes }
        let map = songMap(for: project)
        guard map.isStructured else { return notes }

        let band = Set(project.studioTracks.filter { !$0.instrument.isAudio }.map(\.instrument)).union([instrument])
        // With a tiny band, keep everyone playing — only add fills/crashes.
        let thinBand = band.count < 3
        let part = part(for: instrument, variant: variant, band: band)
        let beatsPerBar = Double(map.beatsPerBar)

        var result: [StudioNote] = []
        result.reserveCapacity(notes.count)
        for note in notes {
            if let limit, !limit.contains(note.startBeat) {
                result.append(note)
                continue
            }
            guard let span = map.span(at: note.startBeat) else {
                result.append(note)
                continue
            }
            if !thinBand, !plays(part, in: span, style: style) { continue }
            if let shaped = shape(note, part: part, span: span, instrument: instrument, style: style, beatsPerBar: beatsPerBar, thinBand: thinBand) {
                result.append(shaped)
            }
        }

        if instrument == .drums {
            result = addDrumTransitions(to: result, map: map, style: style, variant: variant, limit: limit, thinBand: thinBand)
            result = removeDoubledHits(result)
        }
        return result.sorted { $0.startBeat < $1.startBeat }
    }

    /// Per-note adjustments: lighter verses, bigger choruses.
    private static func shape(
        _ note: StudioNote,
        part: Part,
        span: Span,
        instrument: StudioInstrument,
        style: StudioStyle,
        beatsPerBar: Double,
        thinBand: Bool
    ) -> StudioNote? {
        let positionInBar = (note.startBeat - span.startBeat).truncatingRemainder(dividingBy: beatsPerBar)
        let onStrongBeat = abs(positionInBar.rounded() - positionInBar) < 0.04
            && Int(positionInBar.rounded()) % 2 == 0
        var pitch = note.pitch
        var velocity = note.velocity
        var duration = note.duration

        switch part {
        case .drums:
            let map = SoundFontManager.drumPitchMap(for: nil)
            if span.energy <= 2 {
                // Light groove: cross-stick instead of snare, no ghost/open hats.
                if note.pitch == map.snare {
                    if note.velocity < 45 { return nil }
                    if ![.rock, .edm, .hiphop].contains(style) { pitch = map.rim }
                }
                if note.pitch == map.hatOpen || note.pitch == map.crash { pitch = map.hatClosed }
                if note.pitch == map.clap { return nil }
                velocity = Int(Double(velocity) * 0.82)
            } else if span.energy >= 5 {
                // Final chorus: move to the ride for one last lift.
                if span.role == .chorus, span.isLastOfRole, span.occurrence >= 2,
                   note.pitch == map.hatClosed || note.pitch == map.hatOpen {
                    pitch = map.ride
                    velocity = Int(Double(velocity) * 1.05)
                }
                // Chorus lift: hats open up on the "&" of 2 and 4.
                else if note.pitch == map.hatClosed, ![.jazz, .lofi].contains(style) {
                    let offbeat = positionInBar.truncatingRemainder(dividingBy: 2)
                    if abs(offbeat - 1.5) < 0.05 { pitch = map.hatOpen; duration = 0.45 }
                }
            }
        case .bass:
            if span.energy <= 2, !thinBand {
                // Verses: hold the roots, leave space.
                guard onStrongBeat else { return nil }
                duration = max(duration, 1.5)
                velocity = Int(Double(velocity) * 0.9)
            }
            if span.role == .outro, span.startBeat + Double(span.bars - 1) * beatsPerBar <= note.startBeat {
                duration = max(duration, beatsPerBar)
            }
        case .secondaryHarmony, .organ:
            if span.energy <= 2, !thinBand {
                // Light verse part: only strong beats, softer.
                guard onStrongBeat else { return nil }
                velocity = Int(Double(velocity) * 0.82)
            } else if span.energy == 3 {
                velocity = Int(Double(velocity) * 0.88)
            }
        case .pad:
            // Pads sit lower in busy sections, bloom in the gaps.
            if span.energy >= 5 { velocity = Int(Double(velocity) * 0.85) }
            if span.energy <= 2 { velocity = Int(Double(velocity) * 1.08) }
        case .strings:
            if span.role == .bridge || span.role == .outro { velocity = Int(Double(velocity) * 0.9) }
        case .primaryHarmony:
            if span.energy <= 1, instrument == .piano || instrument == .guitar {
                // Intros/outros: let chords ring instead of busy comping.
                if !onStrongBeat, note.duration < 1 { velocity = Int(Double(velocity) * 0.85) }
            }
        case .brass, .lead, .mallets:
            break
        }

        return StudioNote(
            startBeat: note.startBeat,
            duration: duration,
            pitch: pitch,
            velocity: max(1, min(127, velocity))
        )
    }

    /// The same drum struck twice within a few milliseconds (e.g. the
    /// generator's section crash plus ours) sounds flammy and too loud.
    private static func removeDoubledHits(_ notes: [StudioNote]) -> [StudioNote] {
        var kept: [StudioNote] = []
        var lastByPitch: [Int: Int] = [:]   // pitch → index in kept
        for note in notes.sorted(by: { $0.startBeat < $1.startBeat }) {
            if let index = lastByPitch[note.pitch], note.startBeat - kept[index].startBeat < 0.04 {
                if note.velocity > kept[index].velocity { kept[index] = note }
                continue
            }
            lastByPitch[note.pitch] = kept.count
            kept.append(note)
        }
        return kept
    }

    // MARK: - Drum transitions

    private static func addDrumTransitions(
        to notes: [StudioNote],
        map: SongMap,
        style: StudioStyle,
        variant: InstrumentVariant?,
        limit: ClosedRange<Double>?,
        thinBand: Bool
    ) -> [StudioNote] {
        let kit = SoundFontManager.drumPitchMap(for: variant)
        var result = notes
        let beatsPerBar = Double(map.beatsPerBar)

        for (index, span) in map.spans.enumerated() {
            let next = index + 1 < map.spans.count ? map.spans[index + 1] : nil
            let drumsHere = thinBand || plays(.drums, in: span, style: style)
            let drumsNext = next.map { thinBand || plays(.drums, in: $0, style: style) } ?? false

            // Fill into the next section (bigger into a chorus).
            if let next, drumsNext {
                let fillBeats: Double = next.energy >= 5 || (!drumsHere) ? 2 : (next.energy > span.energy ? 1 : 0)
                if fillBeats > 0 {
                    let fillEnd = next.startBeat
                    let fillStart = fillEnd - min(fillBeats, beatsPerBar)
                    if limit == nil || limit!.contains(fillStart) {
                        result.removeAll { $0.startBeat >= fillStart - 0.01 && $0.startBeat < fillEnd - 0.01 && $0.pitch != kit.kick }
                        result.append(contentsOf: fill(from: fillStart, to: fillEnd, kit: kit, style: style, intensity: next.energy))
                    }
                }
            }

            // Crash + kick on every section downbeat the drums play — the
            // "cortes" that tell the listener a new part has begun.
            if drumsHere {
                let crashVelocity = [84, 84, 94, 102, 114][max(0, min(4, span.energy - 1))]
                func crash(at beat: Double, velocity: Int) {
                    guard limit == nil || limit!.contains(beat) else { return }
                    if !result.contains(where: { abs($0.startBeat - beat) < 0.05 && $0.pitch == kit.crash }) {
                        result.append(StudioNote(startBeat: beat, duration: 1.5, pitch: kit.crash, velocity: velocity))
                    }
                    if !result.contains(where: { abs($0.startBeat - beat) < 0.05 && $0.pitch == kit.kick }) {
                        result.append(StudioNote(startBeat: beat, duration: 0.25, pitch: kit.kick, velocity: min(118, velocity)))
                    }
                }
                crash(at: span.startBeat, velocity: crashVelocity)

                // Long sections breathe in 4-bar phrases: a short pickup fill
                // at the end of each phrase, and in big sections a crash to
                // mark the next one.
                if span.bars >= 8, span.energy >= 3, ![.lofi, .ambient].contains(style) {
                    var phraseBar = 4
                    while phraseBar < span.bars {
                        let phraseStart = span.startBeat + Double(phraseBar) * beatsPerBar
                        let fillStart = phraseStart - 1
                        if limit == nil || limit!.contains(fillStart) {
                            result.removeAll { $0.startBeat >= fillStart - 0.01 && $0.startBeat < phraseStart - 0.01 && $0.pitch != kit.kick && $0.pitch != kit.hatClosed }
                            result.append(contentsOf: fill(from: fillStart, to: phraseStart, kit: kit, style: style, intensity: span.energy - 1))
                        }
                        if span.energy >= 5 { crash(at: phraseStart, velocity: 98) }
                        phraseBar += 4
                    }
                }
            }

            // Final hit at the very end.
            if next == nil, drumsHere {
                let last = span.endBeat - beatsPerBar
                if limit == nil || limit!.contains(last) {
                    result.removeAll { $0.startBeat >= last + 0.01 && $0.startBeat < span.endBeat }
                    result.append(StudioNote(startBeat: last, duration: 3, pitch: kit.crash, velocity: 100))
                    result.append(StudioNote(startBeat: last, duration: 0.25, pitch: kit.kick, velocity: 108))
                }
            }
        }
        return result
    }

    /// A short fill: snare/tom 16ths that rise in volume and fall in pitch.
    /// Lo-fi / hip-hop / jazz get a softer snare-only pickup.
    private static func fill(from start: Double, to end: Double, kit: SoundFontManager.DrumPitchMap, style: StudioStyle, intensity: Int) -> [StudioNote] {
        let step = 0.25
        let count = Int(((end - start) / step).rounded())
        guard count > 0 else { return [] }
        let tomRun = [kit.snare, kit.snare, kit.tomHigh, kit.tomHigh, kit.tomMid, kit.tomMid, kit.tomLow, kit.tomLow]
        var notes: [StudioNote] = []
        for i in 0..<count {
            let t = Double(i) / Double(max(1, count - 1))
            let beat = start + Double(i) * step
            let pitch: Int
            let velocity: Int
            if [.lofi, .hiphop, .jazz, .ambient].contains(style) {
                // Pickup: a few snare hits, not a tom roll.
                guard i % 2 == 0 || i == count - 1 else { continue }
                pitch = kit.snare
                velocity = Int(52 + 38 * t)
            } else {
                pitch = tomRun[min(tomRun.count - 1, Int(t * Double(tomRun.count - 1) + 0.5))]
                velocity = Int(68 + Double(intensity) * 6 + 30 * t)
            }
            notes.append(StudioNote(startBeat: beat, duration: 0.2, pitch: pitch, velocity: min(124, velocity)))
        }
        // Anchor the fill with a kick on its first beat.
        notes.append(StudioNote(startBeat: start, duration: 0.25, pitch: kit.kick, velocity: 96))
        return notes
    }

    // MARK: - Expression (used by the mix graph)

    /// CC11 expression curve for sustained parts: soft verses, swells through
    /// pre-choruses, full choruses, fading outros. Returns (beat, value) pairs.
    static func expressionCurve(for project: Project) -> [(beat: Double, value: Int)] {
        let map = songMap(for: project)
        guard map.isStructured else { return [] }
        let beatsPerBar = Double(map.beatsPerBar)
        var points: [(Double, Int)] = []
        for span in map.spans {
            let base: Int
            switch span.energy {
            case 1: base = 88
            case 2: base = 96
            case 3: base = 108
            case 4: base = 104
            default: base = 127
            }
            switch span.role {
            case .preChorus:
                // Swell across the section into the chorus.
                let steps = max(4, span.bars * 2)
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    points.append((span.startBeat + t * (span.endBeat - span.startBeat - 0.1), Int(Double(base) + (127 - Double(base)) * t * t)))
                }
            case .outro:
                let steps = max(4, span.bars * 2)
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    points.append((span.startBeat + t * (span.endBeat - span.startBeat), Int(Double(base) - 40 * t)))
                }
            default:
                points.append((span.startBeat, base))
                // Small lift into whatever comes next.
                if let next = span.nextRole, next == .chorus, span.role != .preChorus {
                    points.append((span.endBeat - beatsPerBar, base))
                    points.append((span.endBeat - 0.1, min(127, base + 14)))
                }
            }
        }
        return points.map { (beat: $0.0, value: max(30, min(127, $0.1))) }
    }
}
