import Foundation
import SwiftData
import SwiftUI

enum StudioStyle: String, Codable, CaseIterable, Identifiable {
    case pop
    case rock
    case lofi
    case edm
    case jazz
    case hiphop
    case funk
    case ambient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pop: return "Pop"
        case .rock: return "Rock"
        case .lofi: return "Lo-Fi"
        case .edm: return "EDM"
        case .jazz: return "Jazz"
        case .hiphop: return "Hip-Hop"
        case .funk: return "Funk"
        case .ambient: return "Ambient"
        }
    }

    var description: String {
        switch self {
        case .pop: return "Clean, tight groove with bright chords."
        case .rock: return "Punchy drums with driving guitars."
        case .lofi: return "Soft drums, warm keys, mellow bass."
        case .edm: return "Four‑on‑the‑floor with big synths."
        case .jazz: return "Swung rhythms with complex harmonies."
        case .hiphop: return "Hard-hitting drums with deep bass."
        case .funk: return "Groovy bass with syncopated rhythms."
        case .ambient: return "Atmospheric pads with sparse drums."
        }
    }

    var icon: String {
        switch self {
        case .pop: return "sparkles"
        case .rock: return "guitars"
        case .lofi: return "leaf.fill"
        case .edm: return "bolt.fill"
        case .jazz: return "music.quarternote.3"
        case .hiphop: return "waveform"
        case .funk: return "figure.dance"
        case .ambient: return "cloud.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .pop: return SectionColor.purple.color
        case .rock: return SectionColor.orange.color
        case .lofi: return SectionColor.green.color
        case .edm: return SectionColor.cyan.color
        case .jazz: return SectionColor.blue.color
        case .hiphop: return SectionColor.red.color
        case .funk: return SectionColor.yellow.color
        case .ambient: return SectionColor.pink.color
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
    
    var variants: [InstrumentVariant] {
        switch self {
        case .piano:
            return [.acousticPiano, .electricPiano, .brightPiano]
        case .synth:
            return [.padSynth, .leadSynth, .brassSynth]
        case .guitar:
            return [.acousticGuitar, .electricGuitar, .cleanGuitar]
        case .bass:
            return [.acousticBass, .electricBass, .synthBass]
        case .drums, .audio:
            return []
        }
    }
}

enum InstrumentVariant: String, Codable, CaseIterable {
    // Piano variants
    case acousticPiano = "Acoustic Piano"
    case electricPiano = "Electric Piano"
    case brightPiano = "Bright Piano"
    
    // Synth variants
    case padSynth = "Pad Synth"
    case leadSynth = "Lead Synth"
    case brassSynth = "Brass Synth"
    
    // Guitar variants
    case acousticGuitar = "Acoustic Guitar"
    case electricGuitar = "Electric Guitar"
    case cleanGuitar = "Clean Guitar"
    
    // Bass variants
    case acousticBass = "Acoustic Bass"
    case electricBass = "Electric Bass"
    case synthBass = "Synth Bass"
    
    var midiProgram: UInt8 {
        switch self {
        // Piano
        case .acousticPiano: return 0
        case .electricPiano: return 4
        case .brightPiano: return 1
        
        // Synth
        case .padSynth: return 88
        case .leadSynth: return 80
        case .brassSynth: return 61
        
        // Guitar
        case .acousticGuitar: return 24
        case .electricGuitar: return 27
        case .cleanGuitar: return 26
        
        // Bass
        case .acousticBass: return 32
        case .electricBass: return 33
        case .synthBass: return 38
        }
    }
}

@Model
final class StudioTrack {
    var id: UUID
    var name: String
    var orderIndex: Int
    private var _instrument: String
    private var _drumPreset: String
    private var _variant: String?
    var octaveShift: Int
    var isMuted: Bool
    var isSolo: Bool
    var volume: Float
    var pan: Float
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
    
    var variant: InstrumentVariant? {
        get {
            guard let variantString = _variant else { return nil }
            return InstrumentVariant(rawValue: variantString)
        }
        set {
            _variant = newValue?.rawValue
        }
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
        self._variant = instrument.variants.first?.rawValue
        self.octaveShift = 0
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.volume = 0.75
        self.pan = 0.0
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
