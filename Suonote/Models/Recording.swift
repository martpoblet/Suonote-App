import Foundation
import SwiftData
import SwiftUI

@Model
final class Recording {
    var id: UUID
    var name: String
    var fileName: String
    var duration: TimeInterval
    var bpm: Int
    var timeTop: Int
    var timeBottom: Int
    var countIn: Int
    var createdAt: Date
    var isFavorite: Bool
    var linkedSectionId: UUID?
    private var _recordingType: String?
    
    // Audio Effects Settings
    var reverbEnabled: Bool = false
    var reverbMix: Float = 0.5
    var reverbSize: Float = 0.5
    
    var delayEnabled: Bool = false
    var delayTime: Float = 0.3
    var delayFeedback: Float = 0.3
    var delayMix: Float = 0.3
    
    var eqEnabled: Bool = false
    var lowGain: Float = 0
    var midGain: Float = 0
    var highGain: Float = 0
    
    var compressionEnabled: Bool = false
    var compressionThreshold: Float = -20
    var compressionRatio: Float = 4.0
    
    var project: Project?
    
    var recordingType: RecordingType {
        get {
            if let typeString = _recordingType,
               let type = RecordingType(rawValue: typeString) {
                return type
            }
            return .voice
        }
        set {
            _recordingType = newValue.rawValue
        }
    }
    
    init(
        name: String = "Take",
        fileName: String,
        duration: TimeInterval = 0,
        bpm: Int = 120,
        timeTop: Int = 4,
        timeBottom: Int = 4,
        countIn: Int = 1,
        recordingType: RecordingType? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.fileName = fileName
        self.duration = duration
        self.bpm = bpm
        self.timeTop = timeTop
        self.timeBottom = timeBottom
        self.countIn = countIn
        self.createdAt = Date()
        self.isFavorite = false
        self._recordingType = (recordingType ?? .voice).rawValue
    }
}

enum RecordingType: String, Codable, CaseIterable {
    case sketch = "Sketch"
    case voice = "Voice"
    case guitar = "Guitar"
    case piano = "Piano"
    case melody = "Melody Idea"
    case beat = "Beat"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .voice: return "mic.fill"
        case .guitar: return "guitars.fill"
        case .piano: return "pianokeys"
        case .melody: return "music.note"
        case .sketch: return "pencil.and.scribble"
        case .beat: return "waveform"
        case .other: return "waveform.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .voice: return SectionColor.ocean.color
        case .guitar: return SectionColor.coral.color
        case .piano: return SectionColor.lavender.color
        case .melody: return SectionColor.sky.color
        case .sketch: return SectionColor.sand.color
        case .beat: return SectionColor.moss.color
        case .other: return SectionColor.sage.color
        }
    }
}
