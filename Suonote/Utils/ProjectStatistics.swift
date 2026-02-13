import Foundation

/// Project statistics and insights (F-10)
struct ProjectStatistics {
    let totalSections: Int
    let totalChords: Int
    let totalBars: Int
    let uniqueChords: Int
    let mostUsedChord: String
    let diatonicPercentage: Double
    let estimatedDuration: String
    let lyricsWordCount: Int
    let hasRecordings: Bool
    let recordingCount: Int
    
    static func compute(for project: Project) -> ProjectStatistics {
        let sections = project.sectionTemplates
        let allChords = sections.flatMap { $0.chordEvents }
        let totalBars = sections.reduce(0) { $0 + $1.calculatedBars }
        
        // Most used chord
        var chordCounts: [String: Int] = [:]
        for chord in allChords {
            chordCounts[chord.display, default: 0] += 1
        }
        let mostUsed = chordCounts.max(by: { $0.value < $1.value })?.key ?? "—"
        
        // Unique chords
        let uniqueChords = Set(allChords.map { $0.display }).count
        
        // Diatonic percentage
        let scaleDegrees = ChordSuggestionEngine.diatonicChords(
            forKey: project.keyRoot,
            mode: project.keyMode
        )
        let diatonicRoots = Set(scaleDegrees.map { $0.root })
        let diatonicCount = allChords.filter { diatonicRoots.contains($0.root) }.count
        let diatonicPct = allChords.isEmpty ? 0 : Double(diatonicCount) / Double(allChords.count) * 100
        
        // Duration estimate
        let beatsPerBar = Double(project.timeTop)
        let totalBeats = Double(totalBars) * beatsPerBar
        let seconds = totalBeats * 60.0 / Double(project.bpm)
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let duration = String(format: "%d:%02d", mins, secs)
        
        // Lyrics
        let wordCount = sections.reduce(0) { total, section in
            total + section.lyricsText.split(separator: " ").count
        }
        
        // Recordings
        let recordings = project.recordings
        
        return ProjectStatistics(
            totalSections: sections.count,
            totalChords: allChords.count,
            totalBars: totalBars,
            uniqueChords: uniqueChords,
            mostUsedChord: mostUsed,
            diatonicPercentage: diatonicPct,
            estimatedDuration: duration,
            lyricsWordCount: wordCount,
            hasRecordings: !recordings.isEmpty,
            recordingCount: recordings.count
        )
    }
}
