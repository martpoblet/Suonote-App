import Foundation
import SwiftData

@Model
final class ChordEvent {
    var id: UUID
    var barIndex: Int
    var beatOffset: Int
    var root: String
    var quality: ChordQuality
    var extensions: [String]
    var slashRoot: String?
    var display: String
    
    var sectionTemplate: SectionTemplate?
    
    init(
        barIndex: Int,
        beatOffset: Int,
        root: String,
        quality: ChordQuality = .major,
        extensions: [String] = [],
        slashRoot: String? = nil
    ) {
        self.id = UUID()
        self.barIndex = barIndex
        self.beatOffset = beatOffset
        self.root = root
        self.quality = quality
        self.extensions = extensions
        self.slashRoot = slashRoot
        
        var displayStr = root + quality.symbol
        if !extensions.isEmpty {
            displayStr += extensions.joined()
        }
        if let slash = slashRoot {
            displayStr += "/" + slash
        }
        self.display = displayStr
    }
}

enum ChordQuality: String, Codable, CaseIterable {
    case major = ""
    case minor = "m"
    case diminished = "dim"
    case augmented = "aug"
    case dominant7 = "7"
    case major7 = "maj7"
    case minor7 = "m7"
    case sus2 = "sus2"
    case sus4 = "sus4"
    
    var symbol: String {
        rawValue
    }
}
