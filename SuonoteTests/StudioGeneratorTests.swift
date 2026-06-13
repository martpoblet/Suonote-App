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
    private func makeProject() throws -> Project {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, configurations: config)
        let context = container.mainContext

        let project = Project(title: "Test Song")
        context.insert(project)

        let section = SectionTemplate(name: "Verse", bars: 4)
        section.project = project
        project.sectionTemplates.append(section)

        let progression: [(Int, String, ChordQuality)] = [
            (0, "C", .major),
            (1, "F", .major),
            (2, "G", .major),
            (3, "C", .major)
        ]
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
