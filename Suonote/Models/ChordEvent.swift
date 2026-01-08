import Foundation
import SwiftData

@Model
final class ChordEvent {
    var id: UUID
    var barIndex: Int
    var beatOffset: Double  // Changed to Double to support fractional beats
    var duration: Double    // Duration in beats (0.5 = half beat, 1 = full beat, 2 = two beats)
    var root: String
    var quality: ChordQuality
    var extensions: [String]
    var slashRoot: String?
    var display: String
    
    var sectionTemplate: SectionTemplate?
    
    init(
        barIndex: Int,
        beatOffset: Double,
        duration: Double = 1.0,
        root: String,
        quality: ChordQuality = .major,
        extensions: [String] = [],
        slashRoot: String? = nil
    ) {
        self.id = UUID()
        self.barIndex = barIndex
        self.beatOffset = beatOffset
        self.duration = duration
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

// MARK: - Enhanced Chord Quality

enum ChordQuality: String, Codable, CaseIterable {
    // Triads
    case major = ""
    case minor = "m"
    case diminished = "dim"
    case augmented = "aug"
    
    // Suspended
    case sus2 = "sus2"
    case sus4 = "sus4"
    
    // Seventh Chords
    case dominant7 = "7"
    case major7 = "maj7"
    case minor7 = "m7"
    case minorMajor7 = "m(maj7)"
    case diminished7 = "dim7"
    case halfDiminished7 = "ø7"
    case augmented7 = "aug7"
    
    // Extended Chords (for future use)
    case dominant9 = "9"
    case major9 = "maj9"
    case minor9 = "m9"
    
    var symbol: String {
        rawValue
    }
    
    var displayName: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .diminished: return "Diminished"
        case .augmented: return "Augmented"
        case .sus2: return "Suspended 2"
        case .sus4: return "Suspended 4"
        case .dominant7: return "Dominant 7th"
        case .major7: return "Major 7th"
        case .minor7: return "Minor 7th"
        case .minorMajor7: return "Minor-Major 7th"
        case .diminished7: return "Diminished 7th"
        case .halfDiminished7: return "Half Diminished"
        case .augmented7: return "Augmented 7th"
        case .dominant9: return "Dominant 9th"
        case .major9: return "Major 9th"
        case .minor9: return "Minor 9th"
        }
    }
    
    var category: ChordCategory {
        switch self {
        case .major, .minor, .diminished, .augmented:
            return .triad
        case .sus2, .sus4:
            return .suspended
        case .dominant7, .major7, .minor7, .minorMajor7, .diminished7, .halfDiminished7, .augmented7:
            return .seventh
        case .dominant9, .major9, .minor9:
            return .extended
        }
    }
    
    /// Returns the intervals (in semitones from root) that make up this chord
    var intervals: [Int] {
        switch self {
        // Triads
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        
        // Suspended
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        
        // Seventh Chords
        case .dominant7: return [0, 4, 7, 10]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .minorMajor7: return [0, 3, 7, 11]
        case .diminished7: return [0, 3, 6, 9]
        case .halfDiminished7: return [0, 3, 6, 10]
        case .augmented7: return [0, 4, 8, 10]
        
        // Extended
        case .dominant9: return [0, 4, 7, 10, 14]
        case .major9: return [0, 4, 7, 11, 14]
        case .minor9: return [0, 3, 7, 10, 14]
        }
    }
}

enum ChordCategory: String {
    case triad = "Triads"
    case suspended = "Suspended"
    case seventh = "7th Chords"
    case extended = "Extended"
}
