import Foundation
import SwiftData

@Model
final class ChordEvent {
    var id: UUID = UUID()
    var barIndex: Int = 0
    var beatOffset: Double = 0  // Changed to Double to support fractional beats
    var duration: Double = 1.0  // Duration in beats (0.5 = half beat, 1 = full beat, 2 = two beats)
    var isRest: Bool = false
    var root: String = "C"
    var quality: ChordQuality = ChordQuality.major
    var extensions: [String] = []
    var slashRoot: String? = nil
    var display: String = ""
    
    var sectionTemplateStore: SectionTemplate?
    
    /// Recomputes the display string from current chord properties
    func updateDisplay() {
        if isRest {
            display = "Rest"
        } else {
            var displayStr = root + quality.symbol
            if !extensions.isEmpty {
                displayStr += extensions.joined()
            }
            if let slash = slashRoot {
                displayStr += "/" + slash
            }
            display = displayStr
        }
    }
    
    init(
        barIndex: Int,
        beatOffset: Double,
        duration: Double = 1.0,
        isRest: Bool = false,
        root: String,
        quality: ChordQuality = ChordQuality.major,
        extensions: [String] = [],
        slashRoot: String? = nil
    ) {
        self.barIndex = barIndex
        self.beatOffset = beatOffset
        self.duration = duration
        self.isRest = isRest
        self.root = root
        self.quality = quality
        self.extensions = extensions
        self.slashRoot = slashRoot
        
        if isRest {
            self.display = "Rest"
        } else {
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

    var sectionTemplate: SectionTemplate? {
        get { sectionTemplateStore }
        set { sectionTemplateStore = newValue }
    }
}

// MARK: - Enhanced Chord Quality

enum ChordQuality: String, Codable, CaseIterable {
    // Triads
    case major = ""
    case minor = "m"
    case diminished = "dim"
    case augmented = "aug"
    case power = "5"
    
    // Suspended
    case sus2 = "sus2"
    case sus4 = "sus4"
    
    // Sixth Chords
    case sixth = "6"
    case minorSixth = "m6"
    
    // Seventh Chords
    case dominant7 = "7"
    case major7 = "maj7"
    case minor7 = "m7"
    case minorMajor7 = "m(maj7)"
    case diminished7 = "dim7"
    case halfDiminished7 = "ø7"
    case augmented7 = "aug7"
    case dominant7sus4 = "7sus4"
    
    // Extended Chords
    case dominant9 = "9"
    case major9 = "maj9"
    case minor9 = "m9"
    case dominant11 = "11"
    case minor11 = "m11"
    case major11 = "maj11"
    case dominant13 = "13"
    case minor13 = "m13"
    case major13 = "maj13"
    
    // Add Chords
    case add9 = "add9"
    case add11 = "add11"
    
    // Altered
    case dominant7sharp9 = "7#9"
    case dominant7flat9 = "7b9"
    case dominant7sharp11 = "7#11"
    case altered = "7alt"
    
    var symbol: String {
        rawValue
    }
    
    var displayName: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .diminished: return "Diminished"
        case .augmented: return "Augmented"
        case .power: return "Power"
        case .sus2: return "Suspended 2"
        case .sus4: return "Suspended 4"
        case .sixth: return "6th"
        case .minorSixth: return "Minor 6th"
        case .dominant7: return "Dominant 7th"
        case .major7: return "Major 7th"
        case .minor7: return "Minor 7th"
        case .minorMajor7: return "Minor-Major 7th"
        case .diminished7: return "Diminished 7th"
        case .halfDiminished7: return "Half Diminished"
        case .augmented7: return "Augmented 7th"
        case .dominant7sus4: return "7sus4"
        case .dominant9: return "Dominant 9th"
        case .major9: return "Major 9th"
        case .minor9: return "Minor 9th"
        case .dominant11: return "Dominant 11th"
        case .minor11: return "Minor 11th"
        case .major11: return "Major 11th"
        case .dominant13: return "Dominant 13th"
        case .minor13: return "Minor 13th"
        case .major13: return "Major 13th"
        case .add9: return "Add 9"
        case .add11: return "Add 11"
        case .dominant7sharp9: return "7#9 (Hendrix)"
        case .dominant7flat9: return "7♭9"
        case .dominant7sharp11: return "7#11"
        case .altered: return "Altered"
        }
    }
    
    var category: ChordCategory {
        switch self {
        case .major, .minor, .diminished, .augmented, .power:
            return .triad
        case .sus2, .sus4:
            return .suspended
        case .sixth, .minorSixth:
            return .sixth
        case .dominant7, .major7, .minor7, .minorMajor7, .diminished7, .halfDiminished7, .augmented7, .dominant7sus4:
            return .seventh
        case .dominant9, .major9, .minor9, .dominant11, .minor11, .major11,
             .dominant13, .minor13, .major13, .add9, .add11,
             .dominant7sharp9, .dominant7flat9, .dominant7sharp11, .altered:
            return .extended
        }
    }
    
    /// Whether this quality is minor-sounding
    var isMinor: Bool {
        switch self {
        case .minor, .minor7, .minorMajor7, .minor9, .minor11, .minor13, .minorSixth,
             .diminished, .diminished7, .halfDiminished7:
            return true
        default:
            return false
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
        case .power: return [0, 7]
        
        // Suspended
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        
        // Sixth
        case .sixth: return [0, 4, 7, 9]
        case .minorSixth: return [0, 3, 7, 9]
        
        // Seventh Chords
        case .dominant7: return [0, 4, 7, 10]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .minorMajor7: return [0, 3, 7, 11]
        case .diminished7: return [0, 3, 6, 9]
        case .halfDiminished7: return [0, 3, 6, 10]
        case .augmented7: return [0, 4, 8, 10]
        case .dominant7sus4: return [0, 5, 7, 10]
        
        // Extended
        case .dominant9: return [0, 4, 7, 10, 14]
        case .major9: return [0, 4, 7, 11, 14]
        case .minor9: return [0, 3, 7, 10, 14]
        case .dominant11: return [0, 4, 7, 10, 14, 17]
        case .minor11: return [0, 3, 7, 10, 14, 17]
        case .major11: return [0, 4, 7, 11, 14, 17]
        case .dominant13: return [0, 4, 7, 10, 14, 21]
        case .minor13: return [0, 3, 7, 10, 14, 21]
        case .major13: return [0, 4, 7, 11, 14, 21]
        
        // Add
        case .add9: return [0, 4, 7, 14]
        case .add11: return [0, 4, 7, 17]
        
        // Altered
        case .dominant7sharp9: return [0, 4, 7, 10, 15]
        case .dominant7flat9: return [0, 4, 7, 10, 13]
        case .dominant7sharp11: return [0, 4, 7, 10, 18]
        case .altered: return [0, 4, 6, 10, 13]
        }
    }
}

enum ChordCategory: String {
    case triad = "Triads"
    case suspended = "Suspended"
    case sixth = "6th Chords"
    case seventh = "7th Chords"
    case extended = "Extended"
}
