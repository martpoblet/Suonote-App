import SwiftUI
import SwiftData

// MARK: - Navigation

/// The four rooms of a song. Shared by the library (quick-entry) and
/// `ProjectDetailView` (tab selection).
enum ProjectDetailTab: Int, CaseIterable, Hashable {
    case compose
    case studio
    case lyrics
    case record

    var title: String {
        switch self {
        case .compose: return String(localized: "Compose")
        case .studio: return String(localized: "Studio")
        case .lyrics: return String(localized: "Lyrics")
        case .record: return String(localized: "Record")
        }
    }

    var icon: String {
        switch self {
        case .compose: return "music.note.list"
        case .studio: return "square.grid.2x2"
        case .lyrics: return "text.quote"
        case .record: return "waveform.circle.fill"
        }
    }
}

/// A push into a song, optionally straight into one of its tabs.
struct LibraryRoute: Hashable, Identifiable {
    let project: Project
    var tab: ProjectDetailTab = .compose

    var id: String { "\(project.id.uuidString)-\(tab.rawValue)" }
}

// MARK: - Sorting

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent = "Recently edited"
    case created = "Recently created"
    case title = "Title"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recent: return "clock"
        case .created: return "sparkles"
        case .title: return "textformat"
        }
    }

    /// Localized display name (rawValue is persisted in AppStorage).
    var displayName: String {
        switch self {
        case .recent: return String(localized: "Recently edited")
        case .created: return String(localized: "Recently created")
        case .title: return String(localized: "Title")
        }
    }
}

// MARK: - Project presentation helpers

extension Project {
    /// "A minor", "C major", "D dorian".
    var libraryKeyLabel: String {
        "\(keyRoot) \(keyMode.libraryDisplayName.lowercased())"
    }

    /// Compact key, e.g. "Am", "C", "D dor".
    var libraryKeyShort: String {
        switch keyMode {
        case .major: return keyRoot
        case .minor, .aeolian: return "\(keyRoot)m"
        default: return "\(keyRoot) \(String(keyMode.libraryDisplayName.prefix(3)).lowercased())"
        }
    }

    var libraryMeterLabel: String { "\(timeTop)/\(timeBottom)" }

    /// Ordered sections of the arrangement (repeats included).
    var libraryArrangement: [SectionTemplate] {
        arrangementItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { $0.sectionTemplate }
    }

    var libraryTotalBars: Int {
        libraryArrangement.reduce(0) { $0 + max(1, $1.bars) }
    }

    /// Searchable text: title, tags, section names and lyrics.
    func libraryMatches(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || tags.contains { $0.localizedCaseInsensitiveContains(query) }
            || sectionTemplates.contains {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.lyricsText.localizedCaseInsensitiveContains(query)
            }
    }
}

extension ProjectStatus {
    /// Localized display name (rawValue is persisted).
    var libraryDisplayName: String {
        switch self {
        case .idea: return String(localized: "Idea")
        case .inProgress: return String(localized: "In Progress")
        case .polished: return String(localized: "Polished")
        case .finished: return String(localized: "Finished")
        case .archived: return String(localized: "Archived")
        }
    }

    /// One line describing where a song is at.
    var libraryBlurb: String {
        switch self {
        case .idea: return String(localized: "A spark — a title, a feel, a few chords.")
        case .inProgress: return String(localized: "Taking shape. Sections and words are landing.")
        case .polished: return String(localized: "Nearly there. Refining the details.")
        case .finished: return String(localized: "Done. Ready to play for people.")
        case .archived: return String(localized: "Set aside. Out of the main library.")
        }
    }
}

extension KeyMode {
    /// Localized display name (rawValue is persisted).
    var libraryDisplayName: String {
        switch self {
        case .major: return String(localized: "Major")
        case .minor: return String(localized: "Minor")
        case .dorian: return String(localized: "Dorian")
        case .phrygian: return String(localized: "Phrygian")
        case .lydian: return String(localized: "Lydian")
        case .mixolydian: return String(localized: "Mixolydian")
        case .aeolian: return String(localized: "Aeolian")
        case .locrian: return String(localized: "Locrian")
        case .harmonicMinor: return String(localized: "Harmonic Minor")
        case .melodicMinor: return String(localized: "Melodic Minor")
        case .pentatonicMajor: return String(localized: "Pentatonic Major")
        case .pentatonicMinor: return String(localized: "Pentatonic Minor")
        case .blues: return String(localized: "Blues")
        }
    }
}

extension Date {
    /// Short relative time: "now", "5m", "3h", "2d", "Sep 12".
    var libraryShortAgo: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return String(localized: "now", comment: "Very short relative time") }
        if seconds < 3600 { return String(localized: "\(Int(seconds / 60))m", comment: "Minutes ago, compact") }
        if seconds < 86_400 { return String(localized: "\(Int(seconds / 3600))h", comment: "Hours ago, compact") }
        if seconds < 86_400 * 7 { return String(localized: "\(Int(seconds / 86_400))d", comment: "Days ago, compact") }
        return formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Starter structures

/// Song-form starting points offered when creating a song.
/// Repeated sections share one section template (like the Compose tab).
struct LibraryStarter: Identifiable, Equatable {
    struct Part: Equatable {
        let name: String
        let bars: Int
        let color: SectionColor
    }

    let id: String
    let name: String
    let detail: String
    /// Arrangement order; parts with the same name reuse the same section.
    let parts: [Part]

    var totalBars: Int { parts.reduce(0) { $0 + $1.bars } }
    var uniqueSectionCount: Int { Set(parts.map(\.name)).count }

    static let blank = LibraryStarter(id: "blank", name: String(localized: "Blank page"), detail: String(localized: "Nothing but a title"), parts: [])

    static let all: [LibraryStarter] = [
        .blank,
        LibraryStarter(
            id: "verse-chorus",
            name: String(localized: "Verse–Chorus"),
            detail: String(localized: "The classic shape"),
            parts: [
                .init(name: "Verse", bars: 8, color: .sage),
                .init(name: "Chorus", bars: 8, color: .coral),
                .init(name: "Verse", bars: 8, color: .sage),
                .init(name: "Chorus", bars: 8, color: .coral),
            ]
        ),
        LibraryStarter(
            id: "pop",
            name: String(localized: "Verse–Chorus–Bridge"),
            detail: String(localized: "Intro to outro, with a turn"),
            parts: [
                .init(name: "Intro", bars: 4, color: .sky),
                .init(name: "Verse", bars: 8, color: .sage),
                .init(name: "Pre-Chorus", bars: 4, color: .sand),
                .init(name: "Chorus", bars: 8, color: .coral),
                .init(name: "Verse", bars: 8, color: .sage),
                .init(name: "Pre-Chorus", bars: 4, color: .sand),
                .init(name: "Chorus", bars: 8, color: .coral),
                .init(name: "Bridge", bars: 8, color: .lavender),
                .init(name: "Chorus", bars: 8, color: .coral),
                .init(name: "Outro", bars: 4, color: .sky),
            ]
        ),
        LibraryStarter(
            id: "aaba",
            name: "AABA",
            detail: String(localized: "32-bar standard"),
            parts: [
                .init(name: "A", bars: 8, color: .ocean),
                .init(name: "A", bars: 8, color: .ocean),
                .init(name: "B", bars: 8, color: .berry),
                .init(name: "A", bars: 8, color: .ocean),
            ]
        ),
        LibraryStarter(
            id: "blues",
            name: String(localized: "12-bar blues"),
            detail: String(localized: "Three lines, one feeling"),
            parts: [
                .init(name: "Blues", bars: 12, color: .ocean),
            ]
        ),
        LibraryStarter(
            id: "loop",
            name: String(localized: "Loop"),
            detail: String(localized: "One idea, on repeat"),
            parts: [
                .init(name: "Loop", bars: 4, color: .moss),
            ]
        ),
    ]

    /// Inserts this structure's sections + arrangement into `project`.
    func apply(to project: Project) {
        var byName: [String: SectionTemplate] = [:]
        for part in parts {
            let section: SectionTemplate
            if let existing = byName[part.name] {
                section = existing
            } else {
                section = SectionTemplate(name: part.name, bars: part.bars, colorHex: part.color.hex)
                section.project = project
                project.sectionTemplates.append(section)
                byName[part.name] = section
            }
            let item = ArrangementItem(orderIndex: project.arrangementItems.count)
            item.sectionTemplate = section
            item.project = project
            project.arrangementItems.append(item)
        }
    }
}

// MARK: - Duplicate

enum LibraryProjectCloner {
    /// Deep copy of a song: sections (shared between repeats), chords,
    /// arrangement and Studio tracks. Recordings stay with the original.
    @discardableResult
    static func duplicate(_ project: Project, in context: ModelContext) -> Project {
        let clone = Project(
            title: String(localized: "\(project.title) (copy)"),
            status: project.status == .archived ? .idea : project.status,
            tags: project.tags,
            keyRoot: project.keyRoot,
            keyMode: project.keyMode,
            bpm: project.bpm,
            timeTop: project.timeTop,
            timeBottom: project.timeBottom
        )
        clone.studioStyleRaw = project.studioStyleRaw
        context.insert(clone)

        var sectionMap: [UUID: SectionTemplate] = [:]
        for original in project.sectionTemplates {
            let section = SectionTemplate(
                name: original.name,
                bars: original.bars,
                patternPreset: original.patternPreset,
                lyricsText: original.lyricsText,
                notesText: original.notesText,
                colorHex: original.colorHex ?? SectionColor.sage.hex
            )
            section.sectionKeyRoot = original.sectionKeyRoot
            section.sectionKeyModeRaw = original.sectionKeyModeRaw
            section.sectionBpm = original.sectionBpm
            section.project = clone
            clone.sectionTemplates.append(section)

            for chord in original.chordEvents {
                let copy = ChordEvent(
                    barIndex: chord.barIndex,
                    beatOffset: chord.beatOffset,
                    duration: chord.duration,
                    isRest: chord.isRest,
                    root: chord.root,
                    quality: chord.quality,
                    extensions: chord.extensions,
                    slashRoot: chord.slashRoot
                )
                copy.sectionTemplate = section
                section.chordEvents.append(copy)
            }
            sectionMap[original.id] = section
        }

        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let original = item.sectionTemplate, let section = sectionMap[original.id] else { continue }
            let copy = ArrangementItem(orderIndex: item.orderIndex, labelOverride: item.labelOverride)
            copy.sectionTemplate = section
            copy.project = clone
            clone.arrangementItems.append(copy)
        }

        for track in project.studioTracks {
            let copy = StudioTrack(
                name: track.name,
                instrument: track.instrument,
                orderIndex: track.orderIndex,
                isMuted: track.isMuted,
                isSolo: track.isSolo,
                audioRecordingId: track.audioRecordingId,
                audioStartBeat: track.audioStartBeat
            )
            copy.octaveShift = track.octaveShift
            copy.volume = track.volume
            copy.pan = track.pan
            copy.variant = track.variant
            copy.drumPreset = track.drumPreset
            copy.regenerateIntensity = track.regenerateIntensity
            copy.regenerateComplexity = track.regenerateComplexity
            copy.regenerateNaturalness = track.regenerateNaturalness
            copy.regenerateArpeggioEnabled = track.regenerateArpeggioEnabled
            copy.reverbEnabled = track.reverbEnabled
            copy.reverbMix = track.reverbMix
            copy.reverbPreset = track.reverbPreset
            copy.delayEnabled = track.delayEnabled
            copy.delayTime = track.delayTime
            copy.delayMix = track.delayMix
            copy.delaySyncMode = track.delaySyncMode
            copy.eqEnabled = track.eqEnabled
            copy.eqLowGain = track.eqLowGain
            copy.eqMidGain = track.eqMidGain
            copy.eqHighGain = track.eqHighGain
            copy.compressorEnabled = track.compressorEnabled
            copy.compressorThreshold = track.compressorThreshold
            copy.compressorRatio = track.compressorRatio
            for note in track.notes {
                copy.notes.append(StudioNote(
                    startBeat: note.startBeat,
                    duration: note.duration,
                    pitch: note.pitch,
                    velocity: note.velocity
                ))
            }
            clone.studioTracks.append(copy)
        }

        clone.updatedAt = Date()
        try? context.save()
        return clone
    }
}
