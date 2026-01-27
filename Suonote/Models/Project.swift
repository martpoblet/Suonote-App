import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var title: String = "New Idea"
    var status: ProjectStatus = ProjectStatus.idea
    var tags: [String] = []
    var keyRoot: String = "C"
    var keyMode: KeyMode = KeyMode.major
    var bpm: Int = 120
    var timeTop: Int = 4
    var timeBottom: Int = 4
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    var sectionTemplatesStore: [SectionTemplate]? = []
    
    var arrangementItemsStore: [ArrangementItem]? = []
    
    var recordingsStore: [Recording]? = []

    var studioStyleRaw: String? = nil
    var studioSyncSignature: String? = nil
    var studioLastChordIds: String? = nil
    var studioLastTotalBars: Int = 0
    var studioLastChordSignature: String? = nil
    var studioLastBpm: Int = 120
    var studioLastTimeTop: Int = 4
    var studioLastTimeBottom: Int = 4
    var studioLastKeyRoot: String? = "C"
    var studioLastKeyModeRaw: String? = KeyMode.major.rawValue
    
    var studioTracksStore: [StudioTrack]? = []
    
    init(
        title: String = "New Idea",
        status: ProjectStatus = ProjectStatus.idea,
        tags: [String] = [],
        keyRoot: String = "C",
        keyMode: KeyMode = KeyMode.major,
        bpm: Int = 120,
        timeTop: Int = 4,
        timeBottom: Int = 4
    ) {
        self.title = title
        self.status = status
        self.tags = tags
        self.keyRoot = keyRoot
        self.keyMode = keyMode
        self.bpm = bpm
        self.timeTop = timeTop
        self.timeBottom = timeBottom
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sectionTemplatesStore = []
        self.arrangementItemsStore = []
        self.recordingsStore = []
        self.studioStyleRaw = nil
        self.studioSyncSignature = nil
        self.studioLastChordIds = nil
        self.studioLastTotalBars = 0
        self.studioLastChordSignature = nil
        self.studioLastBpm = bpm
        self.studioLastTimeTop = timeTop
        self.studioLastTimeBottom = timeBottom
        self.studioLastKeyRoot = keyRoot
        self.studioLastKeyModeRaw = keyMode.rawValue
        self.studioTracksStore = []
    }

    var sectionTemplates: [SectionTemplate] {
        get { sectionTemplatesStore ?? [] }
        set {
            sectionTemplatesStore = newValue
            for section in newValue {
                section.projectStore = self
            }
        }
    }

    var arrangementItems: [ArrangementItem] {
        get { arrangementItemsStore ?? [] }
        set {
            arrangementItemsStore = newValue
            for item in newValue {
                item.projectStore = self
            }
        }
    }

    var recordings: [Recording] {
        get { recordingsStore ?? [] }
        set {
            recordingsStore = newValue
            for recording in newValue {
                recording.projectStore = self
            }
        }
    }

    var studioTracks: [StudioTrack] {
        get { studioTracksStore ?? [] }
        set {
            studioTracksStore = newValue
            for track in newValue {
                track.project = self
            }
        }
    }
    
    var recordingsCount: Int {
        recordings.count
    }

    var studioStyle: StudioStyle? {
        get {
            guard let studioStyleRaw else { return nil }
            return StudioStyle(rawValue: studioStyleRaw)
        }
        set {
            studioStyleRaw = newValue?.rawValue
        }
    }
}

extension Project {
    var timeSignaturePreset: TimeSignaturePreset {
        TimeSignaturePreset.from(top: timeTop, bottom: timeBottom)
    }

    var tempoBeatsPerBar: Int {
        timeSignaturePreset.tempoBeatsPerBar
    }

    func tempoBeatInterval() -> Double {
        timeSignaturePreset.secondsPerTempoBeat(bpm: bpm)
    }

    func gridBeatInterval() -> Double {
        timeSignaturePreset.secondsPerGridBeat(bpm: bpm)
    }

    func quarterNoteBpm() -> Double {
        timeSignaturePreset.quarterNoteBpm(from: bpm)
    }

    func applyTimeSignatureChange(
        oldTimeTop: Int,
        oldTimeBottom: Int,
        newTimeTop: Int,
        newTimeBottom: Int
    ) {
        guard oldTimeTop > 0, newTimeTop > 0 else { return }
        guard oldTimeTop != newTimeTop || oldTimeBottom != newTimeBottom else { return }

        let oldBeatsPerBar = Double(oldTimeTop)
        let newBeatsPerBar = Double(newTimeTop)
        let oldBeatUnit = 1.0 / Double(max(1, oldTimeBottom))
        let newBeatUnit = 1.0 / Double(max(1, newTimeBottom))
        let minDuration = min(0.25, newBeatsPerBar)
        let epsilon = 0.0001

        let arrangementSections = arrangementItems.compactMap { $0.sectionTemplate }
        for section in arrangementSections where !sectionTemplates.contains(where: { $0.id == section.id }) {
            sectionTemplates.append(section)
        }
        var seenSectionIds = Set<UUID>()
        let allSections = (sectionTemplates + arrangementSections).filter { section in
            seenSectionIds.insert(section.id).inserted
        }

        for section in allSections {
            let oldSectionBeats = Double(max(1, section.bars)) * oldBeatsPerBar
            let oldSectionDuration = oldSectionBeats * oldBeatUnit
            var maxChordBeat = 0.0

            for chord in section.chordEvents {
                let originalBar = chord.barIndex
                let originalOffset = chord.beatOffset
                let originalDuration = chord.duration
                let absoluteStart = (Double(originalBar) * oldBeatsPerBar + originalOffset) * oldBeatUnit
                let absoluteEnd = absoluteStart + (originalDuration * oldBeatUnit)
                maxChordBeat = max(maxChordBeat, absoluteEnd)

                let newBeatPosition = absoluteStart / newBeatUnit
                let newBarIndex = max(0, Int(floor(newBeatPosition / newBeatsPerBar)))
                let remainder = newBeatPosition - Double(newBarIndex) * newBeatsPerBar
                let maxOffset = max(0, newBeatsPerBar - epsilon)
                let newBeatOffset = max(0, min(remainder, maxOffset))
                let newDuration = (originalDuration * oldBeatUnit) / newBeatUnit

                chord.barIndex = newBarIndex
                chord.beatOffset = newBeatOffset

                let available = max(0, newBeatsPerBar - newBeatOffset)
                chord.duration = min(newDuration, available)
                if chord.duration < minDuration, available >= minDuration {
                    chord.duration = minDuration
                }
            }

            let totalDuration = max(oldSectionDuration, maxChordBeat)
            let newTotalBeats = totalDuration / newBeatUnit
            let newBars = max(1, Int(ceil(newTotalBeats / newBeatsPerBar)))
            section.bars = newBars
        }

        for recording in recordings {
            recording.timeTop = newTimeTop
            recording.timeBottom = newTimeBottom
        }
    }

    func applyKeyChange(oldRoot: String, newRoot: String) {
        let semitones = NoteUtils.intervalBetween(from: oldRoot, to: newRoot)
        guard semitones != 0 else { return }

        let arrangementSections = arrangementItems.compactMap { $0.sectionTemplate }
        for section in arrangementSections where !sectionTemplates.contains(where: { $0.id == section.id }) {
            sectionTemplates.append(section)
        }
        var seenSectionIds = Set<UUID>()
        let allSections = (sectionTemplates + arrangementSections).filter { section in
            seenSectionIds.insert(section.id).inserted
        }

        for section in allSections {
            for chord in section.chordEvents {
                guard !chord.isRest else { continue }
                chord.root = NoteUtils.transpose(note: chord.root, semitones: semitones)
                if let slash = chord.slashRoot, !slash.isEmpty {
                    chord.slashRoot = NoteUtils.transpose(note: slash, semitones: semitones)
                }
            }
        }
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case idea = "Idea"
    case inProgress = "In Progress"
    case polished = "Polished"
    case finished = "Finished"
    case archived = "Archived"
    
    var color: String {
        switch self {
        case .idea: return "blue"
        case .inProgress: return "orange"
        case .polished: return "purple"
        case .finished: return "green"
        case .archived: return "gray"
        }
    }
}

enum KeyMode: String, Codable, CaseIterable {
    case major = "Major"
    case minor = "Minor"
}
