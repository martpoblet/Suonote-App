import XCTest
import SwiftData
import AVFoundation
import SwiftUI
@testable import Suonote

/// Guards the sound-quality fixes: preset routing, loudness matching,
/// register defaults, groove shape and pedalling.
final class StudioSoundTests: XCTestCase {

    // MARK: - Catalog

    func testSilentPresetsAreRoutedToWorkingOnes() {
        // 0/89 "Warm Pad" and 0/38 "Synth Bass 1" render silence under AUSampler.
        XCTAssertNotEqual(StudioSoundCatalog.preset(for: .padWarm), StudioSoundCatalog.Preset(bankVariation: 0, program: 89, isPercussion: false))
        XCTAssertNotEqual(StudioSoundCatalog.preset(for: .synthBass), StudioSoundCatalog.Preset(bankVariation: 0, program: 38, isPercussion: false))
    }

    func testEverySupportedVariantHasALoudnessTrim() {
        for instrument in StudioInstrument.allCases where !instrument.isAudio {
            for variant in SoundFontManager.supportedVariants(for: instrument) {
                XCTAssertNotNil(StudioSoundCatalog.measuredTrims[variant], "\(variant.rawValue) has no measured trim")
                let trim = StudioSoundCatalog.loudnessTrimDB(for: variant, instrument: instrument)
                XCTAssertTrue((-16...24).contains(trim), "\(variant.rawValue) trim \(trim) out of range")
            }
        }
    }

    func testStyleDefaultsAreSupportedVariants() {
        for style in StudioStyle.allCases {
            for instrument in StudioInstrument.allCases where !instrument.isAudio {
                guard let variant = SoundFontManager.defaultVariant(for: instrument, style: style) else {
                    XCTFail("No default for \(instrument.rawValue) in \(style.rawValue)")
                    continue
                }
                XCTAssertTrue(SoundFontManager.supportedVariants(for: instrument).contains(variant))
            }
        }
        XCTAssertEqual(SoundFontManager.defaultVariant(for: .guitar, style: .rock), .overdriveGuitar)
        XCTAssertEqual(SoundFontManager.defaultVariant(for: .piano, style: .lofi), .vintageElectricPiano)
        XCTAssertEqual(SoundFontManager.defaultVariant(for: .drums, style: .jazz), .brushDrumKit)
    }

    func testBankVariationVariantsUseBankEight() {
        XCTAssertEqual(InstrumentVariant.mellowGrandPiano.bankVariation, 8)
        XCTAssertEqual(InstrumentVariant.vintageElectricPiano.bankVariation, 8)
        XCTAssertEqual(InstrumentVariant.acousticPiano.bankVariation, 0)
    }

    func testFaderUnityAndSilence() {
        XCTAssertEqual(StudioMixGraph.faderGain(0.75), 1, accuracy: 0.001)
        XCTAssertEqual(StudioMixGraph.faderGain(0), 0)
        XCTAssertGreaterThan(StudioMixGraph.faderGain(1), 1)
    }

    // MARK: - Registers

    func testNewTracksStartInTheirNaturalRegister() {
        for instrument in StudioInstrument.allCases where !instrument.isAudio && instrument != .drums && instrument != .piano {
            for variant in SoundFontManager.supportedVariants(for: instrument) {
                XCTAssertEqual(
                    StudioGenerator.initialOctaveShift(for: instrument, variant: variant),
                    StudioGenerator.defaultOctaveShift(for: instrument, variant: variant),
                    "\(variant.rawValue) should start at its natural register"
                )
            }
        }
    }

    @MainActor
    func testPopBassIsAudible() throws {
        let project = try makeProject(style: .pop)
        let variant = SoundFontManager.defaultVariant(for: .bass, style: .pop)
        let notes = StudioGenerator.generateNotes(
            for: .bass, project: project, style: .pop, variant: variant,
            octaveShift: StudioGenerator.initialOctaveShift(for: .bass, variant: variant)
        )
        XCTAssertFalse(notes.isEmpty)
        // E1 (28) and up — never the sub-audible C0 region old defaults produced.
        XCTAssertGreaterThanOrEqual(notes.map(\.pitch).min() ?? 0, 28)
    }

    // MARK: - Groove

    @MainActor
    func testRockGuitarDrivesTheWholeBar() throws {
        let project = try makeProject(style: .rock)
        let notes = StudioGenerator.generateNotes(
            for: .guitar, project: project, style: .rock, variant: .overdriveGuitar,
            octaveShift: 2, compingPattern: .block
        )
        let beatsPerBar = Double(project.timeTop)
        let positions = Set(notes.filter { $0.startBeat < beatsPerBar }.map { Int(($0.startBeat * 2).rounded()) })
        // Hits in both halves of the bar, not just beats 1–2.
        XCTAssertTrue(positions.contains { $0 < 4 })
        XCTAssertTrue(positions.contains { $0 >= 4 })
        XCTAssertGreaterThanOrEqual(positions.count, 6)
    }

    func testLofiDefaultGrooveHasBothBackbeats() {
        XCTAssertEqual(DrumPreset.defaultPreset(for: .lofi, beatsPerBar: 4, timeBottom: 4), .boomBap)
        let notes = StudioGenerator.generateDrumNotes(totalBars: 1, beatsPerBar: 4, timeBottom: 4, style: .lofi, preset: .boomBap)
        let map = SoundFontManager.drumPitchMap(for: nil)
        let snareBeats = Set(notes.filter { $0.pitch == map.snare && $0.velocity > 60 }.map { Int($0.startBeat.rounded()) })
        XCTAssertTrue(snareBeats.contains(1))
        XCTAssertTrue(snareBeats.contains(3))
    }

    // MARK: - Pedalling & preview voicing

    func testPedalEventsAlternateAndEndReleased() {
        let notes = [
            StudioNote(startBeat: 0, duration: 1, pitch: 60), StudioNote(startBeat: 0, duration: 1, pitch: 64),
            StudioNote(startBeat: 4, duration: 1, pitch: 65), StudioNote(startBeat: 4, duration: 1, pitch: 69)
        ]
        let events = StudioMixGraph.pedalEvents(for: notes, beatsPerBar: 4)
        XCTAssertEqual(events.first?.1, true)
        XCTAssertEqual(events.last?.1, false)
        XCTAssertEqual(events.filter { $0.1 }.count, 2, "Re-pedal once per harmony change")
    }

    func testPreviewVoicingStaysInMidRegister() {
        let voicing = ChordPreviewPlayer.voiceLead(pitchClasses: [0, 4, 7, 11], from: [], above: 48)
        XCTAssertFalse(voicing.isEmpty)
        XCTAssertTrue(voicing.allSatisfy { (53...81).contains($0) })
        XCTAssertEqual(ChordPreviewPlayer.pitchClass(of: "Bb"), 10)
        XCTAssertEqual(ChordPreviewPlayer.pitchClass(of: "Eb"), 3)
    }

    // MARK: - Arranger

    @MainActor
    func testSectionRolesUnderstandEnglishAndSpanish() {
        XCTAssertEqual(StudioArranger.Role.from(name: "Pre-Chorus"), .preChorus)
        XCTAssertEqual(StudioArranger.Role.from(name: "Estribillo"), .chorus)
        XCTAssertEqual(StudioArranger.Role.from(name: "Estrofa 2"), .verse)
        XCTAssertEqual(StudioArranger.Role.from(name: "Puente"), .bridge)
        XCTAssertEqual(StudioArranger.Role.from(name: "Intro"), .intro)
        XCTAssertEqual(StudioArranger.Role.from(name: "Ending"), .outro)
    }

    @MainActor
    func testDemoSongIsArrangedBySection() throws {
        let container = try ModelContainer(for: Project.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let project = DemoSong.make(in: ModelContext(container))
        let map = StudioArranger.songMap(for: project)
        XCTAssertEqual(map.spans.first?.role, .intro)
        guard let intro = map.spans.first,
              let chorus = map.spans.first(where: { $0.role == .chorus }),
              let firstVerse = map.spans.first(where: { $0.role == .verse }) else {
            return XCTFail("Demo song should have intro, verse and chorus")
        }
        func notes(_ instrument: StudioInstrument, in span: StudioArranger.Span) -> [StudioNote] {
            project.studioTracks.first { $0.instrument == instrument }?.notes
                // Ignore the humanized edges (±0.1 beat) of each section.
                .filter { $0.startBeat >= span.startBeat + 0.1 && $0.startBeat < span.endBeat - 0.1 } ?? []
        }
        // Bass waits for the verse; guitar (second harmony) waits for more energy.
        XCTAssertTrue(notes(.bass, in: intro).isEmpty)
        // Guitar (second harmony) plays lightly in the first verse, fully in the chorus.
        let versePerBar = Double(notes(.guitar, in: firstVerse).count) / Double(firstVerse.bars)
        let chorusPerBar = Double(notes(.guitar, in: chorus).count) / Double(chorus.bars)
        XCTAssertGreaterThan(chorusPerBar, versePerBar * 1.5)
        // Piano (primary harmony) always plays.
        XCTAssertFalse(notes(.piano, in: intro).isEmpty)
        // A crash marks the chorus downbeat.
        let kit = SoundFontManager.drumPitchMap(for: nil)
        let drums = project.studioTracks.first { $0.instrument == .drums }?.notes ?? []
        let crashes = drums.filter { $0.pitch == kit.crash && abs($0.startBeat - chorus.startBeat) < 0.1 }
        XCTAssertEqual(crashes.count, 1, "Exactly one crash on the chorus downbeat (humanized timing allowed)")
    }

    @MainActor
    func testExpressionSwellsIntoChorus() throws {
        let container = try ModelContainer(for: Project.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let project = DemoSong.make(in: ModelContext(container))
        let curve = StudioArranger.expressionCurve(for: project)
        XCTAssertFalse(curve.isEmpty)
        XCTAssertTrue(curve.allSatisfy { (30...127).contains($0.value) })
        XCTAssertEqual(curve.map(\.value).max(), 127)
    }

    // MARK: - Synth engine

    func testSynthVariantsHavePresetsAndTrims() {
        for variant in [InstrumentVariant.synthAnalogPad, .synthGlassPad, .synthSupersaw, .synthPluck, .synthAnalogBass, .synthSubBass] {
            XCTAssertNotNil(StudioSoundCatalog.synthPreset(for: variant), "\(variant.rawValue) has no synth preset")
            XCTAssertNotNil(StudioSoundCatalog.measuredTrims[variant], "\(variant.rawValue) has no trim")
        }
        XCTAssertNil(StudioSoundCatalog.synthPreset(for: .acousticPiano))
    }

    @MainActor
    func testSynthRendersStableAudio() throws {
        SuonoteSynthAudioUnit.register()
        for preset in [SynthPreset.supersaw, .analogBass, .glassPad] {
            let engine = AVAudioEngine()
            let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 2_048)
            let synth = AVAudioUnitMIDIInstrument(audioComponentDescription: SuonoteSynthAudioUnit.componentDescription)
            (synth.auAudioUnit as? SuonoteSynthAudioUnit)?.preset = preset
            engine.attach(synth)
            engine.connect(synth, to: engine.mainMixerNode, format: format)
            try engine.start()
            for note: UInt8 in [36, 60, 64, 67, 96] { synth.startNote(note, withVelocity: 127, onChannel: 0) }
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2_048)!
            var peak: Float = 0
            for _ in 0..<40 {
                _ = try engine.renderOffline(2_048, to: buffer)
                for channel in 0..<2 {
                    for i in 0..<Int(buffer.frameLength) {
                        let value = buffer.floatChannelData![channel][i]
                        XCTAssertTrue(value.isFinite)
                        peak = max(peak, abs(value))
                    }
                }
            }
            engine.stop()
            XCTAssertGreaterThan(peak, 0.01, "Synth preset produced silence")
            XCTAssertLessThanOrEqual(peak, 1.0)
        }
    }

    // MARK: - Brand

    func testLogoGeometryMatchesBrandArtwork() {
        XCTAssertEqual(SuonoteLogoGeometry.waveCount, 3)
        XCTAssertEqual(SuonoteLogoGeometry.letterCount, 7)
        let rect = CGRect(x: 0, y: 0, width: 739.45, height: 104)
        for index in 0..<3 {
            let bounds = SuonoteLogoGeometry.wave(index, in: rect).boundingRect
            XCTAssertLessThan(bounds.maxX, SuonoteLogoGeometry.markWidth + 1)
        }
    }

    // MARK: - Bass drive

    @MainActor
    func testDriveBassPlaysShortAccentedEighths() throws {
        let project = try makeProject(style: .pop)
        let notes = StudioGenerator.generateNotes(
            for: .bass, project: project, style: .pop, variant: .fingerBass,
            octaveShift: 2, naturalness: 0, bassPattern: .drive, followsArrangement: false
        )
        let firstBar = notes.filter { $0.startBeat < 4 }
        XCTAssertEqual(firstBar.count, 8, "Eighth notes through the bar")
        XCTAssertTrue(firstBar.allSatisfy { $0.duration <= 0.45 }, "Short, punchy notes")
        let downbeat = firstBar.min { $0.startBeat < $1.startBeat }!
        XCTAssertGreaterThan(downbeat.velocity, firstBar.filter { $0.startBeat > 0.4 && $0.startBeat < 0.6 }.first?.velocity ?? 0)
    }

    // MARK: - Helpers

    @MainActor
    private func makeProject(style: StudioStyle) throws -> Project {
        let container = try ModelContainer(for: Project.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let project = Project(title: "Test", keyRoot: "C", keyMode: .major, bpm: 100)
        context.insert(project)
        let section = SectionTemplate(name: "Verse", bars: 4)
        context.insert(section)
        section.project = project
        project.sectionTemplates.append(section)
        for (bar, root) in ["C", "A", "F", "G"].enumerated() {
            let chord = ChordEvent(barIndex: bar, beatOffset: 0, duration: 4, root: root, quality: bar == 1 ? .minor : .major)
            context.insert(chord)
            chord.sectionTemplate = section
            section.chordEvents.append(chord)
        }
        let item = ArrangementItem(orderIndex: 0)
        context.insert(item)
        item.project = project
        project.arrangementItems.append(item)
        item.sectionTemplate = section
        project.studioStyle = style
        return project
    }
}
