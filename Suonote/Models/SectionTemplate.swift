import Foundation
import SwiftData

@Model
final class SectionTemplate {
    var id: UUID
    var name: String
    var barsCount: Int
    var patternPreset: PatternPreset
    var lyricsText: String
    var notesText: String
    
    @Relationship(deleteRule: .cascade)
    var chordEvents: [ChordEvent]
    
    var project: Project?
    
    init(
        name: String = "New Section",
        barsCount: Int = 4,
        patternPreset: PatternPreset = .simple,
        lyricsText: String = "",
        notesText: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.barsCount = barsCount
        self.patternPreset = patternPreset
        self.lyricsText = lyricsText
        self.notesText = notesText
        self.chordEvents = []
    }
}

enum PatternPreset: String, Codable, CaseIterable {
    case simple = "Simple"
    case downbeat = "Downbeat"
    case halfTime = "Half Time"
    case custom = "Custom"
}
