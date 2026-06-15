import XCTest
import SwiftData
import AVFoundation
import AudioToolbox
@testable import Suonote

/// Unit tests for StudioGenerator and SoundFont mappings (T-01)
final class StudioGeneratorTests: XCTestCase {

    // MARK: - Drum generation

    func testGenerateDrumNotesProducesValidNotesForEveryStyle() {
        for style in StudioStyle.allCases {
            let notes = StudioGenerator.generateDrumNotes(
                totalBars: 4,
                beatsPerBar: 4,
                timeBottom: 4,
                style: style,
                preset: nil
            )
            XCTAssertFalse(notes.isEmpty, "Style \(style.rawValue) generated no drum notes")

            let maxBeat = Double(4 * 4)
            for note in notes {
                XCTAssertTrue((0...127).contains(note.pitch), "Pitch out of MIDI range for \(style.rawValue)")
                XCTAssertTrue((1...127).contains(note.velocity), "Velocity out of range for \(style.rawValue)")
                XCTAssertGreaterThanOrEqual(note.startBeat, 0)
                XCTAssertLessThan(note.startBeat, maxBeat, "Note starts after timeline end for \(style.rawValue)")
                XCTAssertGreaterThan(note.duration, 0)
            }
        }
    }

    func testGenerateDrumNotesRespectsOddMeter() {
        let notes = StudioGenerator.generateDrumNotes(
            totalBars: 2,
            beatsPerBar: 3,
            timeBottom: 4,
            style: .pop,
            preset: nil
        )
        let maxBeat = Double(2 * 3)
        for note in notes {
            XCTAssertLessThan(note.startBeat, maxBeat)
        }
    }

    // MARK: - Instrument ranges

    func testInstrumentRangeOctaveShiftMovesByTwelveSemitones() {
        for instrument in StudioInstrument.allCases where !instrument.isAudio && instrument != .drums {
            let neutral = StudioGenerator.instrumentRange(for: instrument, octaveShift: 2)
            let up = StudioGenerator.instrumentRange(for: instrument, octaveShift: 3)
            XCTAssertEqual(up.lowerBound - neutral.lowerBound, 12, "Octave up should shift \(instrument.rawValue) range by 12")
            XCTAssertEqual(up.upperBound - neutral.upperBound, 12)
        }
    }

    func testDefaultOctaveShiftIsWithinAllowedRange() {
        for instrument in StudioInstrument.allCases where !instrument.isAudio {
            let variants = SoundFontManager.supportedVariants(for: instrument)
            for variant in variants {
                let defaultShift = StudioGenerator.defaultOctaveShift(for: instrument, variant: variant)
                let allowed = StudioGenerator.allowedOctaveShiftRange(for: instrument, variant: variant)
                XCTAssertTrue(
                    allowed.contains(defaultShift),
                    "Default octave shift \(defaultShift) outside allowed \(allowed) for \(instrument.rawValue)/\(variant.rawValue)"
                )
            }
        }
    }

    // MARK: - Generation from a project

    @MainActor
    func testGenerateNotesStayWithinInstrumentRange() throws {
        let project = try makeProject()

        for instrument in [StudioInstrument.piano, .bass, .strings] {
            let variant = SoundFontManager.defaultVariant(for: instrument)
            let octaveShift = StudioGenerator.defaultOctaveShift(for: instrument, variant: variant)
            let notes = StudioGenerator.generateNotes(
                for: instrument,
                project: project,
                style: .pop,
                variant: variant,
                octaveShift: octaveShift
            )
            XCTAssertFalse(notes.isEmpty, "\(instrument.rawValue) generated no notes")

            let range = StudioGenerator.instrumentRange(
                for: instrument,
                variant: variant,
                style: .pop,
                octaveShift: octaveShift
            )
            for note in notes {
                XCTAssertTrue((0...127).contains(note.pitch))
                XCTAssertTrue(
                    range.contains(note.pitch),
                    "\(instrument.rawValue) pitch \(note.pitch) outside range \(range)"
                )
            }
        }
    }

    @MainActor
    func testGenerateNotesFitTimeline() throws {
        let project = try makeProject()
        let totalBeats = Double(4 * project.timeTop)

        let notes = StudioGenerator.generateNotes(for: .piano, project: project, style: .rock)
        for note in notes {
            XCTAssertGreaterThanOrEqual(note.startBeat, 0)
            XCTAssertLessThan(note.startBeat, totalBeats)
        }
    }

    // MARK: - Musicality

    @MainActor
    func testGuitarVoicingsAvoidMuddyLowIntervals() throws {
        let project = try makeProject()
        let notes = StudioGenerator.generateNotes(
            for: .guitar,
            project: project,
            style: .rock,
            octaveShift: StudioGenerator.defaultOctaveShift(for: .guitar, variant: .cleanGuitar)
        )
        XCTAssertFalse(notes.isEmpty)

        // Group notes per bar (one chord per bar in the fixture) and check
        // that no two voices sit closer than a fourth in the low register.
        let beatsPerBar = Double(project.timeTop)
        let grouped = Dictionary(grouping: notes) { Int($0.startBeat / beatsPerBar) }
        for (bar, barNotes) in grouped {
            let pitches = Set(barNotes.map(\.pitch)).sorted()
            for index in 1..<pitches.count {
                let lower = pitches[index - 1]
                let gap = pitches[index] - lower
                if lower < 55 {
                    XCTAssertGreaterThanOrEqual(
                        gap, 5,
                        "Muddy low interval (\(lower), \(pitches[index])) in bar \(bar)"
                    )
                }
            }
        }
    }

    @MainActor
    func testGuitarChordsAreStrummed() throws {
        let project = try makeProject()
        let notes = StudioGenerator.generateNotes(for: .guitar, project: project, style: .pop)

        // Notes of the first chord hit should have staggered note-ons.
        let firstHit = notes.filter { $0.startBeat < 0.2 }
        let distinctStarts = Set(firstHit.map { ($0.startBeat * 1000).rounded() })
        XCTAssertGreaterThan(
            distinctStarts.count, 1,
            "Guitar chord tones should be strummed, not simultaneous"
        )
    }

    @MainActor
    func testVelocitiesAreNotFlat() throws {
        let project = try makeProject()
        let notes = StudioGenerator.generateNotes(for: .piano, project: project, style: .pop)
        let velocities = Set(notes.map(\.velocity))
        XCTAssertGreaterThan(
            velocities.count, 1,
            "Chord velocities should vary (accents + per-voice shaping)"
        )
    }

    @MainActor
    func testStyleVelocityIdentityIsPreserved() throws {
        let project = try makeProject()
        func averageVelocity(_ style: StudioStyle) -> Double {
            let notes = StudioGenerator.generateNotes(for: .guitar, project: project, style: style)
            guard !notes.isEmpty else { return 0 }
            return Double(notes.map(\.velocity).reduce(0, +)) / Double(notes.count)
        }
        let lofi = averageVelocity(.lofi)
        let rock = averageVelocity(.rock)
        XCTAssertGreaterThan(
            rock - lofi, 10,
            "Rock should be clearly louder than Lo-Fi (lofi: \(lofi), rock: \(rock))"
        )
    }

    // MARK: - Arrangement coordination

    @MainActor
    func testPianoUsesBothHands() throws {
        let project = try makeProject()
        // Solo piano (no bass) should anchor the low end with a left hand.
        let notes = StudioGenerator.generateNotes(for: .piano, project: project, style: .pop)
        XCTAssertFalse(notes.isEmpty)

        let belowMiddleC = notes.contains { $0.pitch < 60 }
        let atOrAboveMiddleC = notes.contains { $0.pitch >= 60 }
        XCTAssertTrue(belowMiddleC, "Piano left hand should place notes below middle C")
        XCTAssertTrue(atOrAboveMiddleC, "Piano right hand should place notes at/above middle C")
    }

    @MainActor
    func testBassFloorKeepsLowEndClear() throws {
        let project = try makeProject()
        let withBass = StudioGenerator.ArrangementContext(instruments: [.piano, .bass, .drums])
        let notes = StudioGenerator.generateNotes(
            for: .piano,
            project: project,
            style: .pop,
            arrangement: withBass
        )
        XCTAssertFalse(notes.isEmpty)
        for note in notes {
            XCTAssertGreaterThanOrEqual(
                note.pitch, 48,
                "With a dedicated bass, piano should stay out of the bass register (>= C3)"
            )
        }
    }

    @MainActor
    func testSustainedStringsRingThroughChords() throws {
        let project = try makeProject()
        let notes = StudioGenerator.generateNotes(for: .strings, project: project, style: .pop)
        XCTAssertFalse(notes.isEmpty)
        // Each chord lasts 4 beats in the fixture; sustained strings should hold
        // most of that rather than firing short stabs.
        let longNotes = notes.filter { $0.duration >= 3.0 }
        XCTAssertFalse(longNotes.isEmpty, "Strings should sustain across the chord")
    }

    @MainActor
    func testManyInstrumentsThinTheirVoicings() throws {
        let project = try makeProject()
        let fullBand = StudioGenerator.ArrangementContext(
            instruments: [.piano, .guitar, .strings, .organ, .brass, .bass, .drums]
        )
        let notes = StudioGenerator.generateNotes(
            for: .guitar,
            project: project,
            style: .pop,
            complexity: 1.0,
            arrangement: fullBand
        )
        // With 5+ harmonic instruments, each chord hit caps at 2 voices.
        let beatsPerBar = Double(project.timeTop)
        let grouped = Dictionary(grouping: notes) {
            ($0.startBeat / beatsPerBar * 4).rounded()
        }
        for (_, simultaneous) in grouped {
            let distinctPitches = Set(simultaneous.map(\.pitch))
            XCTAssertLessThanOrEqual(
                distinctPitches.count, 2,
                "Crowded arrangements should thin each instrument's voicing"
            )
        }
    }

    // MARK: - Melodic lines & patterns

    @MainActor
    func testLeadInstrumentPlaysAMelodicLine() throws {
        let project = try makeProject()   // C F G C, C major
        let notes = StudioGenerator.generateNotes(for: .woodwinds, project: project, style: .pop, complexity: 0.8)
        XCTAssertFalse(notes.isEmpty)
        // A moving line, not one held note per chord.
        XCTAssertGreaterThan(notes.count, 6, "Lead should play a melodic line, not one note per chord")
        XCTAssertGreaterThan(Set(notes.map(\.pitch)).count, 3, "Melody should move between pitches")
        // Every melodic note is diatonic to C major.
        let cMajor: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
        for note in notes {
            XCTAssertTrue(cMajor.contains(((note.pitch % 12) + 12) % 12), "Non-diatonic melody note \(note.pitch % 12)")
        }
    }

    @MainActor
    func testLeadLandsOnChordToneAtChordStart() throws {
        let project = try makeProject(progression: [
            (0, "C", .major), (1, "A", .minor), (2, "F", .major), (3, "G", .major)
        ])
        let notes = StudioGenerator.generateNotes(for: .woodwinds, project: project, style: .pop, complexity: 0.6)
        let bpb = project.timeTop
        let chordTones: [Int: Set<Int>] = [0: [0, 4, 7], 1: [9, 0, 4], 2: [5, 9, 0], 3: [7, 11, 2]]
        for (bar, tones) in chordTones {
            let start = Double(bar * bpb)
            let downbeat = notes
                .filter { $0.startBeat >= start - 0.01 && $0.startBeat < start + 1 }
                .min(by: { $0.startBeat < $1.startBeat })
            if let downbeat {
                XCTAssertTrue(
                    tones.contains(((downbeat.pitch % 12) + 12) % 12),
                    "Bar \(bar) downbeat \(downbeat.pitch % 12) is not a chord tone"
                )
            }
        }
    }

    @MainActor
    func testPianoArpeggiatesInLofi() throws {
        let project = try makeProject()
        let notes = StudioGenerator.generateNotes(for: .piano, project: project, style: .lofi, complexity: 0.6)
        XCTAssertFalse(notes.isEmpty)
        // A broken-chord figure produces many short sequential notes, not 4 blocks.
        XCTAssertGreaterThan(notes.count, 8, "Lo-fi piano should arpeggiate, not play block chords")
        let onsets = Set(notes.map { ($0.startBeat * 100).rounded() })
        XCTAssertGreaterThan(onsets.count, notes.count / 2, "Pattern should be broken (distinct onsets)")
    }

    @MainActor
    func testExplicitCompingPatternIsHonored() throws {
        let project = try makeProject()   // C F G C

        func onsetBuckets(_ notes: [StudioNote]) -> [Double: [StudioNote]] {
            Dictionary(grouping: notes) { ($0.startBeat * 10).rounded() }
        }

        // Same instrument + style; only the chosen pattern differs.
        let arp = StudioGenerator.generateNotes(
            for: .guitar, project: project, style: .pop, compingPattern: .arpeggioUp
        )
        let block = StudioGenerator.generateNotes(
            for: .guitar, project: project, style: .pop, compingPattern: .block
        )
        XCTAssertFalse(arp.isEmpty)
        XCTAssertFalse(block.isEmpty)

        // Arpeggio spreads chord tones across distinct onsets; block strikes
        // them together, so block has more multi-note onset clusters.
        let arpClusters = onsetBuckets(arp).values.filter { $0.count >= 2 }.count
        let blockClusters = onsetBuckets(block).values.filter { $0.count >= 2 }.count
        XCTAssertGreaterThan(blockClusters, arpClusters, "Block should strike chords together; arpeggio should spread them")
        // The arpeggio is a steadier stream of notes.
        XCTAssertGreaterThan(arp.count, 8, "Arpeggio should produce a continuous figure")
    }

    @MainActor
    func testBassPatternRootsPlaysOneNotePerChord() throws {
        let project = try makeProject()   // 4 chords, 4 bars
        let notes = StudioGenerator.generateNotes(
            for: .bass, project: project, style: .jazz, bassPattern: .roots
        )
        // One root per chord → ~4 notes, all on chord downbeats.
        XCTAssertEqual(notes.count, 4, "Roots pattern should play one note per chord")
        let beatsPerBar = Double(project.timeTop)
        for note in notes {
            XCTAssertEqual(note.startBeat.truncatingRemainder(dividingBy: beatsPerBar), 0, accuracy: 0.01)
        }
    }

    @MainActor
    func testBassPatternWalkingIsFourToTheBar() throws {
        let project = try makeProject()
        let walking = StudioGenerator.generateNotes(
            for: .bass, project: project, style: .pop, bassPattern: .walking
        )
        let roots = StudioGenerator.generateNotes(
            for: .bass, project: project, style: .pop, bassPattern: .roots
        )
        // A walking line is much busier than roots in the same style.
        XCTAssertGreaterThan(walking.count, roots.count + 4, "Walking bass should be 4-to-the-bar")
    }

    func testFullInstrumentRangeSpansMoreOctavesThanPlayRange() {
        for instrument in [StudioInstrument.piano, .guitar, .bass, .strings] {
            let play = StudioGenerator.instrumentRange(for: instrument)
            let full = StudioGenerator.fullInstrumentRange(for: instrument)
            XCTAssertLessThanOrEqual(full.lowerBound, play.lowerBound)
            XCTAssertGreaterThanOrEqual(full.upperBound, play.upperBound)
            XCTAssertGreaterThanOrEqual(full.upperBound - full.lowerBound, 24, "Customize range should span at least 2 octaves")
        }
    }

    // MARK: - Per-instrument recommended patterns

    func testRecommendedCompingIsInstrumentSpecific() {
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .piano, variant: nil, style: .lofi), .alberti)
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .piano, variant: nil, style: .rock), .block)
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .strings, variant: nil, style: .pop), .sustained)
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .organ, variant: nil, style: .jazz), .sustained)
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .mallets, variant: nil, style: .jazz), .arpeggioUpDown)
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .guitar, variant: .acousticNylonGuitar, style: .lofi), .arpeggioUp)
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .guitar, variant: .distortionGuitar, style: .rock), .block)
        XCTAssertEqual(StudioGenerator.recommendedComping(for: .brass, variant: nil, style: .funk), .block)
    }

    func testRecommendedBassPerStyle() {
        XCTAssertEqual(StudioGenerator.recommendedBass(for: .jazz), .walking)
        XCTAssertEqual(StudioGenerator.recommendedBass(for: .funk), .syncopated)
        XCTAssertEqual(StudioGenerator.recommendedBass(for: .pop), .rootFifth)
        XCTAssertEqual(StudioGenerator.recommendedBass(for: .rock), .octaves)
    }

    @MainActor
    func testSustainedCompingHoldsTheChord() throws {
        let project = try makeProject()   // 4-beat chords
        let notes = StudioGenerator.generateNotes(
            for: .piano, project: project, style: .pop, compingPattern: .sustained
        )
        XCTAssertFalse(notes.isEmpty)
        let longNotes = notes.filter { $0.duration >= 3.0 }
        XCTAssertFalse(longNotes.isEmpty, "Sustained pattern should hold the chord across the bar")
    }

    @MainActor
    func testAutoUsesRecommendedPattern() throws {
        let project = try makeProject()
        // Piano in lofi recommends Alberti → broken figure (many distinct onsets).
        let auto = StudioGenerator.generateNotes(for: .piano, project: project, style: .lofi)
        let onsets = Set(auto.map { ($0.startBeat * 100).rounded() })
        XCTAssertGreaterThan(onsets.count, 6, "Auto piano in lo-fi should play the recommended broken pattern")
    }

    // MARK: - Harmonic accuracy

    func testHarmonicTonesCarryTheCorrectSeventh() {
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .minor7).seventh, 10, "m7 needs a ♭7")
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .major7).seventh, 11, "maj7 needs a natural 7")
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .dominant7).seventh, 10, "dom7 needs a ♭7")
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .minorMajor7).seventh, 11)
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .diminished7).seventh, 9, "dim7 has a ♭♭7")
    }

    func testHarmonicTonesThirdsAndFifths() {
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .minor7).third, 3)
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .major).third, 4)
        // Half-diminished: minor 3rd, flat 5th, minor 7th.
        let halfDim = StudioGenerator.harmonicTones(for: .halfDiminished7)
        XCTAssertEqual(halfDim.third, 3)
        XCTAssertEqual(halfDim.fifth, 6)
        XCTAssertEqual(halfDim.seventh, 10)
        // Augmented: raised 5th.
        XCTAssertEqual(StudioGenerator.harmonicTones(for: .augmented).fifth, 8)
    }

    func testSuspendedChordsHaveNoThird() {
        let sus4 = StudioGenerator.harmonicTones(for: .sus4)
        XCTAssertNil(sus4.third, "sus4 must not contain a 3rd")
        XCTAssertEqual(sus4.suspension, 5)
        let sus2 = StudioGenerator.harmonicTones(for: .sus2)
        XCTAssertNil(sus2.third)
        XCTAssertEqual(sus2.suspension, 2)
    }

    func testSixthChordIsNotASeventh() {
        let sixth = StudioGenerator.harmonicTones(for: .sixth)
        XCTAssertEqual(sixth.sixth, 9)
        XCTAssertNil(sixth.seventh, "a 6 chord must not voice a 7th")
    }

    @MainActor
    func testGeneratedSeventhChordsContainGuideTones() throws {
        // A jazzy ii–V–I in C with explicit 7th qualities.
        let project = try makeProject(progression: [
            (0, "D", .minor7),
            (1, "G", .dominant7),
            (2, "C", .major7),
            (3, "C", .major7)
        ])
        // Strings preserve all four chord tones (no rootless, no aggressive trim).
        let notes = StudioGenerator.generateNotes(for: .strings, project: project, style: .jazz)
        XCTAssertFalse(notes.isEmpty)

        let beatsPerBar = project.timeTop
        func pitchClasses(inBar bar: Int) -> Set<Int> {
            let start = Double(bar * beatsPerBar)
            let end = Double((bar + 1) * beatsPerBar)
            return Set(notes.filter { $0.startBeat >= start - 0.5 && $0.startBeat < end }
                .map { (($0.pitch % 12) + 12) % 12 })
        }
        // Dm7 → must contain F (m3 = 5) and C (♭7 = 0)
        XCTAssertTrue(pitchClasses(inBar: 0).isSuperset(of: [5, 0]), "Dm7 missing its 3rd/7th: \(pitchClasses(inBar: 0))")
        // G7 → must contain B (3 = 11) and F (♭7 = 5)
        XCTAssertTrue(pitchClasses(inBar: 1).isSuperset(of: [11, 5]), "G7 missing its 3rd/7th: \(pitchClasses(inBar: 1))")
        // Cmaj7 → must contain E (3 = 4) and B (maj7 = 11)
        XCTAssertTrue(pitchClasses(inBar: 2).isSuperset(of: [4, 11]), "Cmaj7 missing its 3rd/7th: \(pitchClasses(inBar: 2))")
    }

    @MainActor
    func testGuitarKeepsGuideTonesOverFifthWhenTrimmed() throws {
        let project = try makeProject(progression: [(0, "C", .major7), (1, "C", .major7)])
        // Low complexity caps the guitar at a small voicing; the maj7 (B) and
        // 3rd (E) should survive over the droppable 5th (G).
        let notes = StudioGenerator.generateNotes(
            for: .guitar, project: project, style: .pop, complexity: 0.5
        )
        let classes = Set(notes.map { (($0.pitch % 12) + 12) % 12 })
        XCTAssertTrue(classes.contains(11), "Trimmed Cmaj7 dropped its maj7 guide tone")
        XCTAssertTrue(classes.contains(4), "Trimmed Cmaj7 dropped its 3rd")
    }

    // MARK: - SoundFont mappings

    func testEveryInstrumentVariantHasValidMidiProgram() {
        for variant in InstrumentVariant.allCases {
            XCTAssertLessThanOrEqual(variant.midiProgram, 127, "\(variant.rawValue) has invalid GM program")
        }
    }

    func testSupportedVariantsResolveConsistently() {
        for instrument in StudioInstrument.allCases {
            let supported = SoundFontManager.supportedVariants(for: instrument)

            if instrument.isAudio {
                XCTAssertTrue(supported.isEmpty)
                continue
            }

            XCTAssertFalse(supported.isEmpty, "\(instrument.rawValue) has no variants")
            XCTAssertEqual(SoundFontManager.defaultVariant(for: instrument), supported.first)

            // A supported variant resolves to itself
            if let first = supported.first {
                XCTAssertEqual(SoundFontManager.resolvedVariant(for: instrument, variant: first), first)
            }
            // An unsupported variant falls back to the default
            XCTAssertEqual(
                SoundFontManager.resolvedVariant(for: instrument, variant: .tubularBells)
                    ?? SoundFontManager.defaultVariant(for: instrument),
                supported.contains(.tubularBells) ? .tubularBells : supported.first
            )
        }
    }

    func testDrumPitchMapUsesGeneralMidiPercussionRange() {
        let map = SoundFontManager.drumPitchMap(for: nil)
        let pitches = [
            map.kick, map.snare, map.hatClosed, map.hatOpen, map.clap, map.rim,
            map.tomLow, map.tomMid, map.tomHigh, map.ride, map.crash, map.perc
        ]
        for pitch in pitches {
            XCTAssertTrue((35...81).contains(pitch), "Drum pitch \(pitch) outside GM percussion range")
        }
        XCTAssertEqual(map.kick, 36)
        XCTAssertEqual(map.snare, 38)
    }

    func testBundledSoundFontExistsForEveryInstrument() {
        for instrument in StudioInstrument.allCases where !instrument.isAudio {
            let url = SoundFontManager.soundFontURL(for: instrument, variant: nil)
            XCTAssertNotNil(url, "Missing bundled SoundFont for \(instrument.rawValue)")
            if let url {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            }
        }
    }

    /// Loads every supported variant's GM program from the bundled bank into
    /// a real sampler, so a missing preset fails CI instead of falling back
    /// silently at runtime (T-01 / sound upgrade validation).
    func testEverySupportedVariantLoadsFromBundledBank() throws {
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        for instrument in StudioInstrument.allCases where !instrument.isAudio {
            guard let url = SoundFontManager.soundFontURL(for: instrument, variant: nil) else {
                XCTFail("Missing bank for \(instrument.rawValue)")
                continue
            }
            for variant in SoundFontManager.supportedVariants(for: instrument) {
                let bankMSB = variant.isDrumKit
                    ? UInt8(kAUSampler_DefaultPercussionBankMSB)
                    : UInt8(kAUSampler_DefaultMelodicBankMSB)
                XCTAssertNoThrow(
                    try sampler.loadSoundBankInstrument(
                        at: url,
                        program: variant.midiProgram,
                        bankMSB: bankMSB,
                        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                    ),
                    "Preset missing in bank: \(instrument.rawValue) / \(variant.rawValue) (program \(variant.midiProgram))"
                )
            }
        }
        engine.stop()
    }

    // MARK: - Helpers

    @MainActor
    private func makeProject(
        progression: [(Int, String, ChordQuality)] = [
            (0, "C", .major),
            (1, "F", .major),
            (2, "G", .major),
            (3, "C", .major)
        ]
    ) throws -> Project {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, configurations: config)
        let context = container.mainContext

        let project = Project(title: "Test Song")
        context.insert(project)

        let section = SectionTemplate(name: "Verse", bars: max(4, progression.count))
        section.project = project
        project.sectionTemplates.append(section)

        for (bar, root, quality) in progression {
            let chord = ChordEvent(barIndex: bar, beatOffset: 0, duration: 4, root: root, quality: quality)
            chord.sectionTemplate = section
            section.chordEvents.append(chord)
            context.insert(chord)
        }

        let item = ArrangementItem(orderIndex: 0)
        item.sectionTemplate = section
        item.project = project
        project.arrangementItems.append(item)

        // Keep the container alive for the duration of the test
        objc_setAssociatedObject(self, &Self.containerKey, container, .OBJC_ASSOCIATION_RETAIN)
        return project
    }

    private static var containerKey: UInt8 = 0
}
