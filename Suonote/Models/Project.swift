import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var title: String
    var status: ProjectStatus
    var tags: [String]
    var keyRoot: String
    var keyMode: KeyMode
    var bpm: Int
    var timeTop: Int
    var timeBottom: Int
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade)
    var sectionTemplates: [SectionTemplate]
    
    @Relationship(deleteRule: .cascade)
    var arrangementItems: [ArrangementItem]
    
    @Relationship(deleteRule: .cascade)
    var recordings: [Recording]

    var studioStyleRaw: String?
    
    @Relationship(deleteRule: .cascade)
    var studioTracks: [StudioTrack]
    
    init(
        title: String = "New Idea",
        status: ProjectStatus = .idea,
        tags: [String] = [],
        keyRoot: String = "C",
        keyMode: KeyMode = .major,
        bpm: Int = 120,
        timeTop: Int = 4,
        timeBottom: Int = 4
    ) {
        self.id = UUID()
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
        self.sectionTemplates = []
        self.arrangementItems = []
        self.recordings = []
        self.studioStyleRaw = nil
        self.studioTracks = []
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
