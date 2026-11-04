import Foundation
import SwiftData
import os

/// Collaboration support — project sharing via codable format (F-05)
/// The portable `.suonote` file: JSON describing the song (sections, chords,
/// arrangement, lyrics). Recordings and Studio parts are not included.
///
/// Versions:
/// - 1: sections + chords (sections in storage order, no arrangement)
/// - 2: adds the arrangement order, chord extensions and project status
///
/// Files written by older versions still open (missing keys fall back to
/// defaults); files from a newer version are refused with a clear error.

struct SuonoteProjectExchange: Codable {
    static let currentVersion = 2

    // Limits for imported files (a real song is a few KB).
    static let maxFileBytes = 5 * 1024 * 1024
    static let maxBars = 256
    static let maxSections = 200
    static let maxChordsPerSection = 2_000
    static let maxArrangementItems = 1_000
    static let maxTags = 50

    var version: Int = SuonoteProjectExchange.currentVersion
    let exportDate: Date
    let project: ProjectData

    enum CodingKeys: String, CodingKey {
        case version, exportDate, project
    }

    struct ProjectData: Codable {
        let title: String
        let keyRoot: String
        let keyMode: String
        let bpm: Int
        let timeTop: Int
        let timeBottom: Int
        let tags: [String]
        let sections: [SectionData]
        /// v2: `ProjectStatus` raw value.
        var status: String? = nil
        /// v2: the arrangement in order; each entry points at `sections`.
        var arrangement: [ArrangementData]? = nil

        enum CodingKeys: String, CodingKey {
            case title, keyRoot, keyMode, bpm, timeTop, timeBottom, tags, sections, status, arrangement
        }
    }

    struct SectionData: Codable {
        let name: String
        let bars: Int
        let colorHex: String?
        let lyrics: String
        let notes: String
        let keyOverride: String?
        let modeOverride: String?
        let bpmOverride: Int?
        let chords: [ChordData]

        enum CodingKeys: String, CodingKey {
            case name, bars, colorHex, lyrics, notes, keyOverride, modeOverride, bpmOverride, chords
        }
    }

    struct ChordData: Codable {
        let root: String
        let quality: String
        let barIndex: Int
        let beatOffset: Double
        let duration: Double
        let isRest: Bool
        let slashRoot: String?
        /// v2: chord extensions such as "add9".
        var extensions: [String]? = nil

        enum CodingKeys: String, CodingKey {
            case root, quality, barIndex, beatOffset, duration, isRest, slashRoot, extensions
        }
    }

    /// v2: one slot of the song order.
    struct ArrangementData: Codable {
        /// Index into `ProjectData.sections`.
        let sectionIndex: Int
        let labelOverride: String?

        enum CodingKeys: String, CodingKey {
            case sectionIndex, labelOverride
        }
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case unreadable
        case fileTooLarge
        case newerVersion(Int)
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return String(localized: "This file isn't a valid Suonote song.")
            case .fileTooLarge:
                return String(localized: "This file is too large to be a Suonote song.")
            case .newerVersion:
                return String(localized: "This song was saved by a newer version of Suonote. Update the app to open it.")
            case .invalid(let reason):
                return String(localized: "This song file can't be opened: \(reason)")
            }
        }
    }

    // MARK: - Export

    static func export(project: Project) -> Data? {
        let sectionList = project.sectionTemplates
        let sections = sectionList.map { section in
            SectionData(
                name: section.name,
                bars: section.bars,
                colorHex: section.colorHex,
                lyrics: section.lyricsText,
                notes: section.notesText,
                keyOverride: section.sectionKeyRoot,
                modeOverride: section.sectionKeyModeRaw,
                bpmOverride: section.sectionBpm,
                chords: section.chordEvents
                    .sorted(by: { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) })
                    .map { chord in
                        ChordData(
                            root: chord.root,
                            quality: chord.quality.rawValue,
                            barIndex: chord.barIndex,
                            beatOffset: chord.beatOffset,
                            duration: chord.duration,
                            isRest: chord.isRest,
                            slashRoot: chord.slashRoot,
                            extensions: chord.extensions.isEmpty ? nil : chord.extensions
                        )
                    }
            )
        }

        var indexById: [UUID: Int] = [:]
        for (index, section) in sectionList.enumerated() {
            indexById[section.id] = index
        }
        let arrangement: [ArrangementData] = project.arrangementItems
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .compactMap { item in
                guard let id = item.sectionTemplateId, let index = indexById[id] else { return nil }
                return ArrangementData(sectionIndex: index, labelOverride: item.labelOverride)
            }

        let exchange = SuonoteProjectExchange(
            exportDate: Date(),
            project: ProjectData(
                title: project.title,
                keyRoot: project.keyRoot,
                keyMode: project.keyMode.rawValue,
                bpm: project.bpm,
                timeTop: project.timeTop,
                timeBottom: project.timeBottom,
                tags: project.tags,
                sections: sections,
                status: project.status.rawValue,
                arrangement: arrangement
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(exchange)
        } catch {
            AppLog.general.error("Song export failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Import

    /// Reads and validates a `.suonote` file (handles security-scoped URLs
    /// from the document picker or from another app).
    static func importProject(from url: URL) throws -> SuonoteProjectExchange {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > maxFileBytes {
            throw ImportError.fileTooLarge
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            AppLog.general.error("Couldn't read song file: \(error.localizedDescription)")
            throw ImportError.unreadable
        }
        return try importProject(from: data)
    }

    /// Decodes and validates song data. Throws a typed, localized error
    /// instead of returning nil so the UI can say what went wrong.
    static func importProject(from data: Data) throws -> SuonoteProjectExchange {
        guard !data.isEmpty else { throw ImportError.unreadable }
        guard data.count <= maxFileBytes else { throw ImportError.fileTooLarge }

        // Check the version first: a newer file may not decode with this shape.
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw ImportError.unreadable
        }
        if let fileVersion = dictionary["version"] as? Int {
            if fileVersion > currentVersion { throw ImportError.newerVersion(fileVersion) }
            if fileVersion < 1 { throw ImportError.unreadable }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exchange: SuonoteProjectExchange
        do {
            exchange = try decoder.decode(SuonoteProjectExchange.self, from: data)
        } catch {
            AppLog.general.error("Song file decode failed: \(error.localizedDescription)")
            throw ImportError.unreadable
        }
        try exchange.validate()
        return exchange
    }

    /// Structural checks that are not worth repairing silently.
    private func validate() throws {
        let data = project
        guard (1...12).contains(data.timeTop), [2, 4, 8, 16].contains(data.timeBottom) else {
            throw ImportError.invalid(String(localized: "unsupported time signature"))
        }
        guard data.sections.count <= SuonoteProjectExchange.maxSections,
              data.tags.count <= SuonoteProjectExchange.maxTags,
              (data.arrangement?.count ?? 0) <= SuonoteProjectExchange.maxArrangementItems,
              !data.sections.contains(where: { $0.chords.count > SuonoteProjectExchange.maxChordsPerSection }) else {
            throw ImportError.invalid(String(localized: "the song is too large"))
        }
    }

    /// Apply imported data to create a new Project.
    /// Values that are out of range are clamped; chords that don't fit their
    /// section (or aren't real chords) are skipped.
    static func createProject(from exchange: SuonoteProjectExchange, modelContext: SwiftData.ModelContext) -> Project {
        let data = exchange.project

        let trimmedTitle = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyRoot = MusicTheory.noteIndex(data.keyRoot) == nil ? "C" : data.keyRoot
        let project = Project(
            title: String(trimmedTitle.prefix(120)),
            status: data.status.flatMap { ProjectStatus(rawValue: $0) } ?? .idea,
            keyRoot: keyRoot,
            keyMode: KeyMode(rawValue: data.keyMode) ?? .major,
            bpm: data.bpm,                 // Project.init clamps to 20...300
            timeTop: data.timeTop,
            timeBottom: data.timeBottom
        )
        project.tags = Array(
            data.tags
                .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)) }
                .filter { !$0.isEmpty }
                .prefix(maxTags)
        )
        modelContext.insert(project)

        let beatsPerBar = project.timeTop
        var createdSections: [SectionTemplate?] = []

        for sectionData in data.sections.prefix(maxSections) {
            let bars = max(1, min(maxBars, sectionData.bars))
            let section = SectionTemplate()
            let name = sectionData.name.trimmingCharacters(in: .whitespacesAndNewlines)
            section.name = name.isEmpty ? String(localized: "Section") : String(name.prefix(80))
            section.bars = bars
            section.colorHex = sanitizedHex(sectionData.colorHex)
            section.lyricsText = sectionData.lyrics
            section.notesText = sectionData.notes
            section.sectionKeyRoot = validNote(sectionData.keyOverride)
            section.sectionKeyModeRaw = sectionData.modeOverride.flatMap { KeyMode(rawValue: $0)?.rawValue }
            section.sectionBpm = sectionData.bpmOverride.map { max(20, min(300, $0)) }

            for chordData in sectionData.chords.prefix(maxChordsPerSection) {
                guard chordData.barIndex >= 0, chordData.barIndex < bars,
                      chordData.beatOffset.isFinite, chordData.beatOffset >= 0,
                      chordData.beatOffset < Double(beatsPerBar),
                      chordData.duration.isFinite, chordData.duration > 0 else { continue }
                if !chordData.isRest, MusicTheory.noteIndex(chordData.root) == nil { continue }

                let slash = validNote(chordData.slashRoot)
                let extensions = (chordData.extensions ?? []).prefix(8).map { String($0.prefix(12)) }
                let chord = ChordEvent(
                    barIndex: chordData.barIndex,
                    beatOffset: chordData.beatOffset,
                    duration: min(chordData.duration, Double(bars * beatsPerBar)),
                    isRest: chordData.isRest,
                    root: chordData.isRest ? "C" : chordData.root,
                    quality: ChordQuality(rawValue: chordData.quality) ?? .major,
                    extensions: chordData.isRest ? [] : extensions,
                    slashRoot: chordData.isRest ? nil : slash
                )
                section.chordEvents.append(chord)
            }

            project.sectionTemplates.append(section)
            createdSections.append(section)
        }

        // Arrangement: v2 files carry the song order (repeats included);
        // v1 files have none, so play every section once, in file order.
        var order: [(section: SectionTemplate, label: String?)] = []
        for entry in (data.arrangement ?? []).prefix(maxArrangementItems) {
            guard entry.sectionIndex >= 0, entry.sectionIndex < createdSections.count,
                  let section = createdSections[entry.sectionIndex] else { continue }
            order.append((section: section, label: entry.labelOverride.map { String($0.prefix(80)) }))
        }
        if order.isEmpty {
            order = createdSections.compactMap { $0 }.map { (section: $0, label: nil as String?) }
        }
        for (index, entry) in order.enumerated() {
            let item = ArrangementItem(orderIndex: index, labelOverride: entry.label)
            item.sectionTemplate = entry.section
            item.project = project
            project.arrangementItems.append(item)
        }

        project.updatedAt = Date()
        return project
    }

    /// The note name if it is a real one ("C", "F#", "Bb"), otherwise nil.
    private static func validNote(_ note: String?) -> String? {
        guard let note, MusicTheory.noteIndex(note) != nil else { return nil }
        return note
    }

    /// "#RRGGBB" or nil; the UI falls back to the default section color.
    private static func sanitizedHex(_ hex: String?) -> String? {
        guard let hex else { return nil }
        let digits = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, digits.allSatisfy({ $0.isHexDigit }) else { return nil }
        return "#" + digits.uppercased()
    }
}

// MARK: - Lenient decoding (older files, hand-edited files)

extension SuonoteProjectExchange {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportDate = try container.decodeIfPresent(Date.self, forKey: .exportDate) ?? Date()
        project = try container.decode(ProjectData.self, forKey: .project)
    }
}

extension SuonoteProjectExchange.ProjectData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        keyRoot = try c.decodeIfPresent(String.self, forKey: .keyRoot) ?? "C"
        keyMode = try c.decodeIfPresent(String.self, forKey: .keyMode) ?? KeyMode.major.rawValue
        bpm = try c.decodeIfPresent(Int.self, forKey: .bpm) ?? 120
        timeTop = try c.decodeIfPresent(Int.self, forKey: .timeTop) ?? 4
        timeBottom = try c.decodeIfPresent(Int.self, forKey: .timeBottom) ?? 4
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        sections = try c.decodeIfPresent([SuonoteProjectExchange.SectionData].self, forKey: .sections) ?? []
        status = try c.decodeIfPresent(String.self, forKey: .status)
        arrangement = try c.decodeIfPresent([SuonoteProjectExchange.ArrangementData].self, forKey: .arrangement)
    }
}

extension SuonoteProjectExchange.SectionData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        bars = try c.decodeIfPresent(Int.self, forKey: .bars) ?? 4
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        lyrics = try c.decodeIfPresent(String.self, forKey: .lyrics) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        keyOverride = try c.decodeIfPresent(String.self, forKey: .keyOverride)
        modeOverride = try c.decodeIfPresent(String.self, forKey: .modeOverride)
        bpmOverride = try c.decodeIfPresent(Int.self, forKey: .bpmOverride)
        chords = try c.decodeIfPresent([SuonoteProjectExchange.ChordData].self, forKey: .chords) ?? []
    }
}

extension SuonoteProjectExchange.ChordData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        root = try c.decodeIfPresent(String.self, forKey: .root) ?? "C"
        quality = try c.decodeIfPresent(String.self, forKey: .quality) ?? ""
        barIndex = try c.decodeIfPresent(Int.self, forKey: .barIndex) ?? 0
        beatOffset = try c.decodeIfPresent(Double.self, forKey: .beatOffset) ?? 0
        duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? 1
        isRest = try c.decodeIfPresent(Bool.self, forKey: .isRest) ?? false
        slashRoot = try c.decodeIfPresent(String.self, forKey: .slashRoot)
        extensions = try c.decodeIfPresent([String].self, forKey: .extensions)
    }
}
