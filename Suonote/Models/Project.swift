import Foundation
import SwiftData
import SwiftUI

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
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Idea" : title
        self.status = status
        self.tags = Array(Set(tags)) // Deduplicate
        self.keyRoot = MusicTheory.normalize(keyRoot)
        self.keyMode = keyMode
        self.bpm = max(20, min(300, bpm))
        self.timeTop = max(1, min(12, timeTop))
        self.timeBottom = [2, 4, 8, 16].contains(timeBottom) ? timeBottom : 4
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
    
    // MARK: - Studio Snapshot (A-05)
    
    /// Encapsulates all studioLast* fields for cleaner access
    struct StudioSnapshot: Equatable {
        var chordIds: String?
        var totalBars: Int
        var chordSignature: String?
        var bpm: Int
        var timeTop: Int
        var timeBottom: Int
        var keyRoot: String?
        var keyModeRaw: String?
    }
    
    var studioSnapshot: StudioSnapshot {
        get {
            StudioSnapshot(
                chordIds: studioLastChordIds,
                totalBars: studioLastTotalBars,
                chordSignature: studioLastChordSignature,
                bpm: studioLastBpm,
                timeTop: studioLastTimeTop,
                timeBottom: studioLastTimeBottom,
                keyRoot: studioLastKeyRoot,
                keyModeRaw: studioLastKeyModeRaw
            )
        }
        set {
            studioLastChordIds = newValue.chordIds
            studioLastTotalBars = newValue.totalBars
            studioLastChordSignature = newValue.chordSignature
            studioLastBpm = newValue.bpm
            studioLastTimeTop = newValue.timeTop
            studioLastTimeBottom = newValue.timeBottom
            studioLastKeyRoot = newValue.keyRoot
            studioLastKeyModeRaw = newValue.keyModeRaw
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
    
    var swiftUIColor: Color {
        switch self {
        case .idea: return DesignSystem.Colors.info
        case .inProgress: return DesignSystem.Colors.warning
        case .polished: return DesignSystem.Colors.primary
        case .finished: return DesignSystem.Colors.success
        case .archived: return DesignSystem.Colors.secondary
        }
    }
    
    var icon: String {
        switch self {
        case .idea: return "lightbulb.fill"
        case .inProgress: return "hammer.fill"
        case .polished: return "sparkles"
        case .finished: return "checkmark.seal.fill"
        case .archived: return "archivebox.fill"
        }
    }
}

enum KeyMode: String, Codable, CaseIterable {
    case major = "Major"
    case minor = "Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case aeolian = "Aeolian"
    case locrian = "Locrian"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    
    var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor, .aeolian: return [0, 2, 3, 5, 7, 8, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        }
    }
    
    /// Whether this mode is fundamentally minor-sounding
    var isMinor: Bool {
        switch self {
        case .minor, .aeolian, .dorian, .phrygian, .locrian,
             .harmonicMinor, .melodicMinor, .pentatonicMinor, .blues:
            return true
        default:
            return false
        }
    }
    
    /// The common/basic modes for the mode picker
    static var commonModes: [KeyMode] {
        [.major, .minor, .dorian, .mixolydian, .pentatonicMajor, .pentatonicMinor, .blues]
    }
    
    /// All 7-note modes (excludes pentatonic/blues)
    static var heptatonicModes: [KeyMode] {
        [.major, .minor, .dorian, .phrygian, .lydian, .mixolydian, .aeolian, .locrian,
         .harmonicMinor, .melodicMinor]
    }
}
