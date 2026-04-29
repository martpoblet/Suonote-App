import Foundation
import SwiftData

/// Extracted business logic from Project model (A-02)
/// Provides operations that modify project data without cluttering the model
struct ProjectService {
    
    // MARK: - Section Management (F-03)
    
    /// Duplicate a section, optionally transposing chords
    static func duplicateSection(
        _ section: SectionTemplate,
        in project: Project,
        transpose semitones: Int = 0,
        nameSuffix: String = " (copy)"
    ) -> SectionTemplate {
        let copy = SectionTemplate()
        copy.name = section.name + nameSuffix
        copy.bars = section.bars
        copy.patternPreset = section.patternPreset
        copy.lyricsText = section.lyricsText
        copy.notesText = section.notesText
        copy.colorHex = section.colorHex
        copy.sectionKeyRoot = section.sectionKeyRoot
        copy.sectionKeyModeRaw = section.sectionKeyModeRaw
        copy.sectionBpm = section.sectionBpm
        
        // Deep-copy chord events
        var newChords: [ChordEvent] = []
        for chord in section.chordEvents {
            let newChord = ChordEvent(
                barIndex: chord.barIndex,
                beatOffset: chord.beatOffset,
                duration: chord.duration,
                isRest: chord.isRest,
                root: semitones == 0 ? chord.root : NoteUtils.transpose(note: chord.root, semitones: semitones),
                quality: chord.quality
            )
            newChord.isRest = chord.isRest
            newChord.slashRoot = chord.slashRoot
            newChord.display = chord.display
            if semitones != 0 { newChord.updateDisplay() }
            newChords.append(newChord)
        }
        copy.chordEventsStore = newChords
        
        project.sectionTemplates.append(copy)
        return copy
    }
    
    /// Create a variation of a section (change mode, or shift by interval)
    static func createVariation(
        of section: SectionTemplate,
        in project: Project,
        variationType: VariationType
    ) -> SectionTemplate {
        switch variationType {
        case .copy:
            return duplicateSection(section, in: project)
        case .transposeUp:
            return duplicateSection(section, in: project, transpose: 2, nameSuffix: " (+2)")
        case .transposeDown:
            return duplicateSection(section, in: project, transpose: -2, nameSuffix: " (-2)")
        case .relativeMinor:
            return duplicateSection(section, in: project, transpose: -3, nameSuffix: " (rel. min)")
        case .relativeMajor:
            return duplicateSection(section, in: project, transpose: 3, nameSuffix: " (rel. maj)")
        }
    }
    
    enum VariationType: String, CaseIterable {
        case copy = "Exact Copy"
        case transposeUp = "Transpose Up (whole step)"
        case transposeDown = "Transpose Down (whole step)"
        case relativeMinor = "Relative Minor"
        case relativeMajor = "Relative Major"
    }
    
    // MARK: - Project Creation from Template (F-02)
    
    static func createProject(from template: ProjectTemplate, modelContext: ModelContext) -> Project {
        let project = Project(
            title: template.name,
            keyRoot: template.keyRoot,
            keyMode: template.keyMode,
            bpm: template.bpm,
            timeTop: template.timeTop,
            timeBottom: template.timeBottom
        )
        project.tags = template.tags
        modelContext.insert(project)
        
        for sectionDef in template.sections {
            let section = SectionTemplate()
            section.name = sectionDef.name
            section.bars = sectionDef.bars
            section.colorHex = sectionDef.colorHex
            project.sectionTemplates.append(section)

            let arrangementItem = ArrangementItem(orderIndex: project.arrangementItems.count)
            arrangementItem.sectionTemplate = section
            arrangementItem.project = project
            project.arrangementItems.append(arrangementItem)
        }

        project.updatedAt = Date()
        
        return project
    }
    
    // MARK: - Version Snapshot (F-04)
    
    /// Creates a lightweight text snapshot of the current project state for comparison
    static func createSnapshot(of project: Project) -> ProjectSnapshot {
        var sectionSnapshots: [ProjectSnapshot.SectionSnap] = []
        
        for section in project.sectionTemplates {
            let chordStr = section.chordEvents
                .sorted(by: { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) })
                .map { $0.display }
                .joined(separator: " | ")
            
            sectionSnapshots.append(ProjectSnapshot.SectionSnap(
                name: section.name,
                bars: section.bars,
                chords: chordStr,
                lyrics: section.lyricsText
            ))
        }
        
        return ProjectSnapshot(
            date: Date(),
            title: project.title,
            keyRoot: project.keyRoot,
            keyMode: project.keyMode.rawValue,
            bpm: project.bpm,
            sections: sectionSnapshots
        )
    }
    
    /// Compare two snapshots and return differences
    static func diff(_ a: ProjectSnapshot, _ b: ProjectSnapshot) -> [String] {
        var diffs: [String] = []
        
        if a.title != b.title { diffs.append("Title: \"\(a.title)\" → \"\(b.title)\"") }
        if a.bpm != b.bpm { diffs.append("BPM: \(a.bpm) → \(b.bpm)") }
        if a.keyRoot != b.keyRoot || a.keyMode != b.keyMode {
            diffs.append("Key: \(a.keyRoot) \(a.keyMode) → \(b.keyRoot) \(b.keyMode)")
        }
        
        let maxSections = max(a.sections.count, b.sections.count)
        for i in 0..<maxSections {
            if i >= a.sections.count {
                diffs.append("+ Added section: \(b.sections[i].name)")
            } else if i >= b.sections.count {
                diffs.append("- Removed section: \(a.sections[i].name)")
            } else {
                let sa = a.sections[i], sb = b.sections[i]
                if sa.name != sb.name { diffs.append("Section \(i+1) name: \"\(sa.name)\" → \"\(sb.name)\"") }
                if sa.chords != sb.chords { diffs.append("Section \"\(sb.name)\" chords changed") }
                if sa.lyrics != sb.lyrics { diffs.append("Section \"\(sb.name)\" lyrics changed") }
                if sa.bars != sb.bars { diffs.append("Section \"\(sb.name)\" bars: \(sa.bars) → \(sb.bars)") }
            }
        }
        
        return diffs
    }
}

/// Lightweight project snapshot for version comparison (F-04)
struct ProjectSnapshot: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let title: String
    let keyRoot: String
    let keyMode: String
    let bpm: Int
    let sections: [SectionSnap]
    
    struct SectionSnap: Codable {
        let name: String
        let bars: Int
        let chords: String
        let lyrics: String
    }
    
    var summary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(formatter.string(from: date)) — \(title) (\(sections.count) sections)"
    }
}
