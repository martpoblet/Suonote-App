import Foundation
import SwiftData
import SwiftUI

enum StudioStyle: String, Codable, CaseIterable, Identifiable {
    case pop
    case rock
    case lofi
    case edm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pop: return "Pop"
        case .rock: return "Rock"
        case .lofi: return "Lo-Fi"
        case .edm: return "EDM"
        }
    }

    var description: String {
        switch self {
        case .pop: return "Clean, tight groove with bright chords."
        case .rock: return "Punchy drums with driving guitars."
        case .lofi: return "Soft drums, warm keys, mellow bass."
        case .edm: return "Four‑on‑the‑floor with big synths."
        }
    }

    var icon: String {
        switch self {
        case .pop: return "sparkles"
        case .rock: return "guitars"
        case .lofi: return "leaf.fill"
        case .edm: return "bolt.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .pop: return SectionColor.purple.color
        case .rock: return SectionColor.orange.color
        case .lofi: return SectionColor.green.color
        case .edm: return SectionColor.cyan.color
        }
    }
}

enum StudioInstrument: String, Codable, CaseIterable, Identifiable {
    case piano
    case synth
    case guitar
    case bass
    case drums
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .piano: return "Piano"
        case .synth: return "Synth"
        case .guitar: return "Guitar"
        case .bass: return "Bass"
        case .drums: return "Drums"
        case .audio: return "Audio"
        }
    }

    var icon: String {
        switch self {
        case .piano: return "pianokeys"
        case .synth: return "waveform.path.ecg"
        case .guitar: return "guitars"
        case .bass: return "music.note"
        case .drums: return "circle.grid.cross"
        case .audio: return "waveform"
        }
    }

    var color: Color {
        switch self {
        case .piano: return SectionColor.purple.color
        case .synth: return SectionColor.cyan.color
        case .guitar: return SectionColor.orange.color
        case .bass: return SectionColor.blue.color
        case .drums: return SectionColor.red.color
        case .audio: return .gray
        }
    }

    var isAudio: Bool {
        self == .audio
    }
}

@Model
final class StudioTrack {
    var id: UUID
    var name: String
    var orderIndex: Int
    private var _instrument: String
    private var _drumPreset: String
    var octaveShift: Int
    var isMuted: Bool
    var isSolo: Bool
    var createdAt: Date
    var audioRecordingId: UUID?
    var audioStartBeat: Double

    @Relationship(deleteRule: .cascade)
    var notes: [StudioNote]
    var project: Project?

    var instrument: StudioInstrument {
        get { StudioInstrument(rawValue: _instrument) ?? .piano }
        set { _instrument = newValue.rawValue }
    }

    var drumPreset: DrumPreset? {
        get {
            let trimmed = _drumPreset.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return DrumPreset(rawValue: trimmed)
        }
        set {
            _drumPreset = newValue?.rawValue ?? ""
        }
    }

    init(
        name: String,
        instrument: StudioInstrument,
        orderIndex: Int,
        isMuted: Bool = false,
        isSolo: Bool = false,
        audioRecordingId: UUID? = nil,
        audioStartBeat: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.orderIndex = orderIndex
        self._instrument = instrument.rawValue
        self._drumPreset = ""
        self.octaveShift = 0
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.createdAt = Date()
        self.audioRecordingId = audioRecordingId
        self.audioStartBeat = audioStartBeat
        self.notes = []
    }
}

@Model
final class StudioNote {
    var id: UUID
    var startBeat: Double
    var duration: Double
    var pitch: Int
    var velocity: Int
    var track: StudioTrack?

    init(
        startBeat: Double,
        duration: Double,
        pitch: Int,
        velocity: Int = 90
    ) {
        self.id = UUID()
        self.startBeat = startBeat
        self.duration = duration
        self.pitch = pitch
        self.velocity = velocity
    }
}
