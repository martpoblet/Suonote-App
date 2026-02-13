import Foundation
import SwiftData

/// Collaboration support — project sharing via codable format (F-05)
/// Enables future real-time collaboration by defining a portable project format

struct SuonoteProjectExchange: Codable {
    var version: Int = 1
    let exportDate: Date
    let project: ProjectData
    
    struct ProjectData: Codable {
        let title: String
        let keyRoot: String
        let keyMode: String
        let bpm: Int
        let timeTop: Int
        let timeBottom: Int
        let tags: [String]
        let sections: [SectionData]
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
    }
    
    struct ChordData: Codable {
        let root: String
        let quality: String
        let barIndex: Int
        let beatOffset: Double
        let duration: Double
        let isRest: Bool
        let slashRoot: String?
    }
    
    // MARK: - Export
    
    static func export(project: Project) -> Data? {
        let sections = project.sectionTemplates.map { section in
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
                            slashRoot: chord.slashRoot
                        )
                    }
            )
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
                sections: sections
            )
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(exchange)
    }
    
    // MARK: - Import
    
    static func importProject(from data: Data) -> SuonoteProjectExchange? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SuonoteProjectExchange.self, from: data)
    }
    
    /// Apply imported data to create a new Project
    static func createProject(from exchange: SuonoteProjectExchange, modelContext: SwiftData.ModelContext) -> Project {
        let data = exchange.project
        let project = Project(
            title: data.title,
            keyRoot: data.keyRoot,
            keyMode: KeyMode(rawValue: data.keyMode) ?? .major,
            bpm: data.bpm,
            timeTop: data.timeTop,
            timeBottom: data.timeBottom
        )
        project.tags = data.tags
        modelContext.insert(project)
        
        for sectionData in data.sections {
            let section = SectionTemplate()
            section.name = sectionData.name
            section.bars = sectionData.bars
            section.colorHex = sectionData.colorHex
            section.lyricsText = sectionData.lyrics
            section.notesText = sectionData.notes
            section.sectionKeyRoot = sectionData.keyOverride
            section.sectionKeyModeRaw = sectionData.modeOverride
            section.sectionBpm = sectionData.bpmOverride
            
            for chordData in sectionData.chords {
                let chord = ChordEvent(
                    barIndex: chordData.barIndex,
                    beatOffset: chordData.beatOffset,
                    duration: chordData.duration,
                    isRest: chordData.isRest,
                    root: chordData.root,
                    quality: ChordQuality(rawValue: chordData.quality) ?? .major
                )
                chord.slashRoot = chordData.slashRoot
                section.chordEvents.append(chord)
            }
            
            project.sectionTemplates.append(section)
        }
        
        return project
    }
}
