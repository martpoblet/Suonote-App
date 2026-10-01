import Foundation
import SwiftData

/// Keeps generated Studio parts in sync with the song written in Compose.
/// Shared by the Studio tab and the project-wide transport, so pressing play
/// from any tab always plays the current chords.
@MainActor
enum StudioSync {

    /// Brings Studio parts in line with Compose (new/changed/removed chords,
    /// key/tempo/meter changes). Returns true when notes changed.
    @discardableResult
    static func syncIfNeeded(project: Project, modelContext: ModelContext) -> Bool {
        guard let style = project.studioStyle, !project.studioTracks.isEmpty else { return false }

        let currentSignature = Self.signature(for: project)
        guard project.studioSyncSignature != currentSignature else { return false }

        let timeline = StudioGenerator.timeline(for: project)
        let currentChordIds = Set(timeline.chords.map { $0.chord.id })
        let previousChordIds: Set<UUID> = {
            guard let raw = project.studioLastChordIds, !raw.isEmpty else { return [] }
            let ids = raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
            return Set(ids)
        }()
        let previousTotalBars = project.studioLastTotalBars

        let currentSignatureMap = chordSignatureMap(from: timeline)
        let previousSignatureMap = parseChordSignatureMap(project.studioLastChordSignature)

        let newChordIds = currentChordIds.subtracting(previousChordIds)
        let removedChordIds = previousChordIds.subtracting(currentChordIds)
        let barsChanged = timeline.totalBars != previousTotalBars
        let meterChanged = project.studioLastTimeTop != project.timeTop
            || project.studioLastTimeBottom != project.timeBottom
        let keyChanged = project.studioLastKeyRoot != project.keyRoot
            || project.studioLastKeyModeRaw != project.keyMode.rawValue
        let tempoChanged = project.studioLastBpm != project.bpm
        let headerChanged = meterChanged || keyChanged || tempoChanged
        let changedChordIds: Set<UUID> = Set(currentSignatureMap.compactMap { entry in
            let (id, signature) = entry
            guard let previous = previousSignatureMap[id] else { return nil }
            return previous == signature ? nil : id
        })

        let canAppend = !headerChanged
            && removedChordIds.isEmpty
            && !newChordIds.isEmpty
            && timeline.totalBars >= previousTotalBars
            && !barsChanged

        let shouldRegenerateDrums = meterChanged || barsChanged

        if headerChanged || barsChanged || !removedChordIds.isEmpty {
            StudioGenerator.regenerateNotes(
                for: project,
                style: style,
                modelContext: modelContext,
                includeDrums: shouldRegenerateDrums
            )
            project.updatedAt = Date()
        } else if !changedChordIds.isEmpty {
            let affectedSections = sectionIds(containing: changedChordIds, in: project)
            let updated = StudioGenerator.replaceNotesForSections(
                for: project,
                style: style,
                modelContext: modelContext,
                sectionIds: affectedSections
            )
            if updated {
                project.updatedAt = Date()
            }
        } else if canAppend {
            let appended = StudioGenerator.appendNotesForNewContent(
                for: project,
                style: style,
                modelContext: modelContext,
                newChordIds: newChordIds,
                previousTotalBars: previousTotalBars
            )
            if appended {
                project.updatedAt = Date()
            }
        } else {
            StudioGenerator.regenerateNotes(
                for: project,
                style: style,
                modelContext: modelContext
            )
            project.updatedAt = Date()
        }

        updateSyncState(project: project, signature: currentSignature, timeline: timeline)
        try? modelContext.save()
        return true
    }

    static func updateSyncState(project: Project, signature: String, timeline: (chords: [StudioGenerator.ChordSpan], totalBars: Int)) {
        project.studioSyncSignature = signature
        project.studioLastChordIds = timeline.chords.map { $0.chord.id.uuidString }.joined(separator: ",")
        project.studioLastTotalBars = timeline.totalBars
        project.studioLastChordSignature = encodeChordSignatureMap(chordSignatureMap(from: timeline))
        project.studioLastBpm = project.bpm
        project.studioLastTimeTop = project.timeTop
        project.studioLastTimeBottom = project.timeBottom
        project.studioLastKeyRoot = project.keyRoot
        project.studioLastKeyModeRaw = project.keyMode.rawValue
    }

    static func chordSignatureMap(from timeline: (chords: [StudioGenerator.ChordSpan], totalBars: Int)) -> [UUID: String] {
        var map: [UUID: String] = [:]
        for span in timeline.chords {
            map[span.chord.id] = chordSignature(span.chord)
        }
        return map
    }

    static func chordSignature(_ chord: ChordEvent) -> String {
        let ext = chord.extensions.joined(separator: ",")
        let beat = String(format: "%.3f", chord.beatOffset)
        let duration = String(format: "%.3f", chord.duration)
        let restFlag = chord.isRest ? "rest" : "chord"
        return "\(chord.barIndex)|\(beat)|\(duration)|\(restFlag)|\(chord.root)|\(chord.quality.rawValue)|\(ext)|\(chord.slashRoot ?? "")"
    }

    static func encodeChordSignatureMap(_ map: [UUID: String]) -> String {
        map.map { "\($0.key.uuidString)=\($0.value)" }.sorted().joined(separator: "||")
    }

    static func parseChordSignatureMap(_ raw: String?) -> [UUID: String] {
        guard let raw, !raw.isEmpty else { return [:] }
        var map: [UUID: String] = [:]
        let entries = raw.components(separatedBy: "||").filter { !$0.isEmpty }
        for entry in entries {
            let parts = entry.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let id = UUID(uuidString: String(parts[0])) else { continue }
            map[id] = String(parts[1])
        }
        return map
    }

    static func sectionIds(containing chordIds: Set<UUID>, in project: Project) -> Set<UUID> {
        guard !chordIds.isEmpty else { return [] }
        let sections = project.arrangementItems.compactMap { $0.sectionTemplate }
        var ids = Set<UUID>()
        for section in sections {
            if section.chordEvents.contains(where: { chordIds.contains($0.id) }) {
                ids.insert(section.id)
            }
        }
        return ids
    }

    static func signature(for project: Project) -> String {
        let header = "bpm:\(project.bpm)|time:\(project.timeTop)/\(project.timeBottom)|key:\(project.keyRoot)\(project.keyMode.rawValue)"
        let arrangement = project.arrangementItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { item in
                let sectionId = item.sectionTemplate?.id.uuidString ?? "none"
                let label = item.labelOverride ?? ""
                return "\(item.id.uuidString):\(item.orderIndex):\(sectionId):\(label)"
            }
            .joined(separator: "|")
        let arrangementSections = project.arrangementItems.compactMap { $0.sectionTemplate }
        var seenSectionIds = Set<UUID>()
        let sections = arrangementSections
            .filter { seenSectionIds.insert($0.id).inserted }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { section in
                let chords = section.chordEvents
                    .sorted { lhs, rhs in
                        if lhs.barIndex != rhs.barIndex { return lhs.barIndex < rhs.barIndex }
                        if lhs.beatOffset != rhs.beatOffset { return lhs.beatOffset < rhs.beatOffset }
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    .map { chord in
                        let ext = chord.extensions.joined(separator: ",")
                        let beat = String(format: "%.3f", chord.beatOffset)
                        let duration = String(format: "%.3f", chord.duration)
                        let restFlag = chord.isRest ? "rest" : "chord"
                        return "\(chord.barIndex):\(beat):\(duration):\(restFlag):\(chord.root):\(chord.quality.rawValue):\(ext):\(chord.slashRoot ?? "")"
                    }
                    .joined(separator: ";")
                return "\(section.id.uuidString):\(section.bars):\(chords)"
            }
            .joined(separator: "|")
        return [header, arrangement, sections].joined(separator: "#")
    }
}
