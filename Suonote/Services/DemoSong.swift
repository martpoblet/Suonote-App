import Foundation
import SwiftData

/// A complete, finished-sounding demo song ("Golden Hour") so the Studio can be
/// heard with a real arrangement: intro, verses, pre-choruses, choruses,
/// bridge and outro, with lyrics and a six-piece band.
@MainActor
enum DemoSong {
    static let title = "Golden Hour"

    private typealias Chord = (root: String, quality: ChordQuality, slash: String?, beat: Double, length: Double)

    private static func bar(_ root: String, _ quality: ChordQuality = .major, over slash: String? = nil) -> [Chord] {
        [(root, quality, slash, 0, 4)]
    }

    private static func split(_ a: (String, ChordQuality), _ b: (String, ChordQuality)) -> [Chord] {
        [(a.0, a.1, nil, 0, 2), (b.0, b.1, nil, 2, 2)]
    }

    /// Removes any previous copy of the demo (so it always reflects the
    /// current sound engine), then creates a fresh one.
    @discardableResult
    static func replace(in context: ModelContext, style: StudioStyle = .pop) -> Project {
        let existing = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        for project in existing where project.title == title && project.tags.contains("demo") {
            context.delete(project)
        }
        return make(in: context, style: style)
    }

    @discardableResult
    static func make(in context: ModelContext, style: StudioStyle = .pop) -> Project {
        let project = Project(
            title: title,
            status: .inProgress,
            tags: ["demo"],
            keyRoot: "G",
            keyMode: .major,
            bpm: 96
        )
        context.insert(project)

        let intro = section("Intro", .sky, project: project, context: context, bars: [
            bar("G", .major7), bar("C", .major7), bar("E", .minor7), bar("D", .sus4)
        ])
        let verse = section("Verse", .ocean, project: project, context: context, bars: [
            bar("G"), bar("D", over: "F#"), bar("E", .minor7), bar("C", .major7),
            bar("G"), bar("D", over: "F#"), bar("A", .minor7), bar("C", .major7)
        ], lyrics: """
        Streetlights hum a quiet tune
        Your shadow leaning into mine
        We never planned to stay this late
        But nothing here is keeping time
        """)
        let pre = section("Pre-Chorus", .sand, project: project, context: context, bars: [
            bar("A", .minor7), bar("B", .minor7), bar("C", .major7), split(("D", .sus4), ("D", .major))
        ], lyrics: """
        And if the night is running out
        Let it run
        """)
        let chorus = section("Chorus", .coral, project: project, context: context, bars: [
            bar("C"), bar("G", over: "B"), bar("E", .minor7), bar("D"),
            bar("C"), bar("G"), bar("A", .minor7), split(("D", .sus4), ("D", .major))
        ], lyrics: """
        Stay in the golden hour with me
        Where every light is soft and slow
        Hold on, the sky is burning gently
        Don't let it go, don't let it go
        """)
        let bridge = section("Bridge", .berry, project: project, context: context, bars: [
            bar("E", .minor), bar("C"), bar("G"), bar("D")
        ], lyrics: """
        Maybe tomorrow forgets our names
        Tonight it knows them all
        """)
        let outro = section("Outro", .sage, project: project, context: context, bars: [
            bar("C", .major7), bar("G", over: "B"), bar("A", .minor7), bar("G", .major7)
        ])

        let order = [intro, verse, pre, chorus, verse, pre, chorus, bridge, chorus, outro]
        for (index, template) in order.enumerated() {
            let item = ArrangementItem(orderIndex: index)
            context.insert(item)
            item.project = project
            project.arrangementItems.append(item)
            item.sectionTemplate = template
        }

        project.studioStyle = style
        let band: [StudioInstrument] = [.drums, .bass, .piano, .guitar, .strings, .synth]
        for instrument in band {
            let track = StudioTrack(
                name: instrument.title,
                instrument: instrument,
                orderIndex: project.studioTracks.count,
                style: style
            )
            track.project = project
            project.studioTracks.append(track)
            context.insert(track)
            track.compingPattern = StudioGenerator.recommendedComping(for: instrument, variant: track.variant, style: style)
            track.bassPattern = StudioGenerator.recommendedBass(for: style)
            track.octaveShift = StudioGenerator.initialOctaveShift(for: instrument, variant: track.variant)
            track.regenerateNaturalness = StudioGenerator.defaultNaturalness(for: instrument)
            if instrument == .drums {
                track.drumPreset = DrumPreset.defaultPreset(for: style, beatsPerBar: project.timeTop, timeBottom: project.timeBottom)
            }
            applyDemoMix(to: track)
        }
        StudioGenerator.regenerateNotes(for: project, style: style, modelContext: context)
        // Mark the Studio as in sync with Compose so it doesn't rewrite the parts on open.
        StudioSync.updateSyncState(
            project: project,
            signature: StudioSync.signature(for: project),
            timeline: StudioGenerator.timeline(for: project)
        )
        project.updatedAt = Date()
        try? context.save()
        return project
    }

    /// A produced starting mix that shows off the per-track effects: room on
    /// the piano, a hall on the strings, a dotted-eighth echo on the guitar,
    /// and EQ that carves space for each part.
    private static func applyDemoMix(to track: StudioTrack) {
        func eq(_ low: Float, _ mid: Float, _ high: Float) {
            track.eqEnabled = true
            track.eqLowGain = low; track.eqMidGain = mid; track.eqHighGain = high
        }
        switch track.instrument {
        case .drums:
            eq(2.5, -2, 3)
            track.volume = 0.78
        case .bass:
            eq(1.5, -3, 1.5)
            track.volume = 0.62
        case .piano:
            eq(-2, -1, 2)
            track.reverbEnabled = true; track.reverbPreset = .medium; track.reverbMix = 0.16
            track.pan = 0.15
        case .guitar:
            eq(-4, 1, 2.5)
            track.delayEnabled = true; track.delaySyncMode = .dottedEighth; track.delayMix = 0.14
            track.pan = -0.35
            track.volume = 0.7
        case .strings:
            eq(-3, -1.5, 1.5)
            track.reverbEnabled = true; track.reverbPreset = .large; track.reverbMix = 0.24
            track.pan = 0.25
            track.volume = 0.68
        case .synth:
            eq(-4, -1, 1)
            track.reverbEnabled = true; track.reverbPreset = .plate; track.reverbMix = 0.2
            track.delayEnabled = true; track.delaySyncMode = .quarter; track.delayMix = 0.12
            track.volume = 0.66
        default:
            break
        }
    }

    private static func section(
        _ name: String,
        _ color: SectionColor,
        project: Project,
        context: ModelContext,
        bars: [[Chord]],
        lyrics: String = ""
    ) -> SectionTemplate {
        let section = SectionTemplate(name: name, bars: bars.count, lyricsText: lyrics, colorHex: color.hex)
        context.insert(section)
        section.project = project
        project.sectionTemplates.append(section)
        for (barIndex, chords) in bars.enumerated() {
            for chord in chords {
                let event = ChordEvent(
                    barIndex: barIndex,
                    beatOffset: chord.beat,
                    duration: chord.length,
                    root: chord.root,
                    quality: chord.quality,
                    slashRoot: chord.slash
                )
                context.insert(event)
                event.sectionTemplate = section
                section.chordEvents.append(event)
            }
        }
        return section
    }
}
