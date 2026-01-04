import Foundation
import SwiftData

@Model
final class SectionTemplate {
    var id: UUID
    var name: String
    var bars: Int  // Keep for backward compatibility, but will be calculated dynamically
    var patternPreset: PatternPreset
    var lyricsText: String
    var notesText: String
    var colorHex: String?  // Color personalizado para la sección (opcional para migración)
    
    @Relationship(deleteRule: .cascade)
    var chordEvents: [ChordEvent]
    
    var project: Project?
    
    // Computed property: Color from hex string
    var color: Color {
        Color(hex: colorHex ?? "#A855F7") ?? SectionColor.purple.color
    }
    
    // Computed property: total beats in the section
    var totalBeats: Double {
        guard !chordEvents.isEmpty else { return Double(bars * (project?.timeTop ?? 4)) }
        
        // Calculate based on the furthest chord position + its duration
        let maxPosition = chordEvents.map { 
            Double($0.barIndex * (project?.timeTop ?? 4)) + $0.beatOffset + $0.duration 
        }.max() ?? 0
        
        return maxPosition
    }
    
    // Computed property: actual number of bars needed
    var calculatedBars: Int {
        let beatsPerBar = Double(project?.timeTop ?? 4)
        return Int(ceil(totalBeats / beatsPerBar))
    }
    
    init(
        name: String = "New Section",
        bars: Int = 4,
        patternPreset: PatternPreset = .simple,
        lyricsText: String = "",
        notesText: String = "",
        colorHex: String = "#A855F7"  // Default purple
    ) {
        self.id = UUID()
        self.name = name
        self.bars = bars
        self.patternPreset = patternPreset
        self.lyricsText = lyricsText
        self.notesText = notesText
        self.colorHex = colorHex
        self.chordEvents = []
    }
}

enum PatternPreset: String, Codable, CaseIterable {
    case simple = "Simple"
    case downbeat = "Downbeat"
    case halfTime = "Half Time"
    case custom = "Custom"
}

// MARK: - Section Colors
enum SectionColor: String, CaseIterable, Identifiable {
    case purple = "Purple"
    case blue = "Blue"
    case cyan = "Cyan"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case red = "Red"
    case pink = "Pink"
    
    var id: String { rawValue }
    
    var hex: String {
        switch self {
        case .purple: return "#A855F7"
        case .blue: return "#3B82F6"
        case .cyan: return "#06B6D4"
        case .green: return "#10B981"
        case .yellow: return "#F59E0B"
        case .orange: return "#F97316"
        case .red: return "#EF4444"
        case .pink: return "#EC4899"
        }
    }
    
    var color: Color {
        Color(hex: hex) ?? .purple
    }
}

// MARK: - Color Extension
import SwiftUI

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
