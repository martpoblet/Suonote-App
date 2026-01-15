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
    case strings
    case brass
    case woodwinds
    case organ
    case mallets
    case drums
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .piano: return "Piano"
        case .synth: return "Synth"
        case .guitar: return "Guitar"
        case .bass: return "Bass"
        case .strings: return "Strings"
        case .brass: return "Brass"
        case .woodwinds: return "Woodwinds"
        case .organ: return "Organ"
        case .mallets: return "Mallets"
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
        case .strings: return "music.quarternote.3"
        case .brass: return "music.note.list"
        case .woodwinds: return "music.note"
        case .organ: return "pianokeys"
        case .mallets: return "music.note"
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
        case .strings: return SectionColor.pink.color
        case .brass: return SectionColor.yellow.color
        case .woodwinds: return SectionColor.green.color
        case .organ: return SectionColor.cyan.color
        case .mallets: return SectionColor.purple.color
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
            return [
                .acousticPiano,
                .brightPiano,
                .electricPiano,
                .electricPiano2,
                .honkyTonkPiano,
                .harpsichord,
                .clavinet
            ]
        case .synth:
            return [
                .leadSquare,
                .leadSaw,
                .leadCalliope,
                .leadChiff,
                .leadCharang,
                .leadVoice,
                .leadFifths,
                .leadBass,
                .padNewAge,
                .padWarm,
                .padPolysynth,
                .padChoir,
                .padBowed,
                .padMetallic,
                .padHalo,
                .padSweep
            ]
        case .guitar:
            return [
                .cleanGuitar,
                .acousticNylonGuitar,
                .acousticSteelGuitar,
                .jazzGuitar,
                .electricGuitar,
                .mutedGuitar,
                .overdriveGuitar,
                .distortionGuitar,
                .harmonicsGuitar
            ]
        case .bass:
            return [
                .acousticBass,
                .fingerBass,
                .pickBass,
                .fretlessBass,
                .slapBass1,
                .slapBass2,
                .synthBass,
                .synthBass2
            ]
        case .strings:
            return [
                .tremoloStrings,
                .pizzicatoStrings,
                .stringEnsemble,
                .slowStrings,
                .synthStrings1,
                .synthStrings2,
                .choirAahs,
                .voiceOohs
            ]
        case .brass:
            return [
                .trumpet,
                .trombone,
                .tuba,
                .mutedTrumpet,
                .frenchHorn,
                .brassSection,
                .synthBrass1,
                .synthBrass2
            ]
        case .woodwinds:
            return [
                .sopranoSax,
                .altoSax,
                .tenorSax,
                .baritoneSax,
                .oboe,
                .englishHorn,
                .bassoon,
                .clarinet,
                .piccolo,
                .flute,
                .recorder,
                .panFlute
            ]
        case .organ:
            return [
                .drawbarOrgan,
                .percussiveOrgan,
                .rockOrgan,
                .churchOrgan,
                .reedOrgan,
                .accordion,
                .harmonica,
                .tangoAccordion
            ]
        case .mallets:
            return [
                .celesta,
                .glockenspiel,
                .musicBox,
                .vibraphone,
                .marimba,
                .xylophone,
                .tubularBells,
                .dulcimer
            ]
        case .drums:
            return [
                .standardDrumKit,
                .roomDrumKit,
                .powerDrumKit,
                .electronicDrumKit,
                .tr808DrumKit,
                .jazzDrumKit,
                .brushDrumKit,
                .orchestraDrumKit,
                .sfxDrumKit
            ]
        case .audio:
            return []
        }
    }
}

enum InstrumentVariant: String, Codable, CaseIterable {
    // Piano variants
    case acousticPiano = "Acoustic Piano"
    case electricPiano = "Electric Piano"
    case brightPiano = "Bright Piano"
    case electricPiano2 = "Electric Piano 2"
    case honkyTonkPiano = "Honky-Tonk Piano"
    case harpsichord = "Harpsichord"
    case clavinet = "Clavinet"
    
    // Synth variants
    case leadSquare = "Lead (Square)"
    case leadSaw = "Lead (Saw)"
    case leadCalliope = "Lead (Calliope)"
    case leadChiff = "Lead (Chiff)"
    case leadCharang = "Lead (Charang)"
    case leadVoice = "Lead (Voice)"
    case leadFifths = "Lead (Fifths)"
    case leadBass = "Lead (Bass + Lead)"
    case padNewAge = "Pad (New Age)"
    case padWarm = "Pad (Warm)"
    case padPolysynth = "Pad (Polysynth)"
    case padChoir = "Pad (Choir)"
    case padBowed = "Pad (Bowed)"
    case padMetallic = "Pad (Metallic)"
    case padHalo = "Pad (Halo)"
    case padSweep = "Pad (Sweep)"
    
    // Guitar variants
    case acousticNylonGuitar = "Acoustic Guitar (Nylon)"
    case acousticSteelGuitar = "Acoustic Guitar (Steel)"
    case electricGuitar = "Electric Guitar"
    case cleanGuitar = "Clean Guitar"
    case jazzGuitar = "Jazz Guitar"
    case mutedGuitar = "Muted Guitar"
    case overdriveGuitar = "Overdrive Guitar"
    case distortionGuitar = "Distortion Guitar"
    case harmonicsGuitar = "Guitar Harmonics"
    
    // Bass variants
    case acousticBass = "Acoustic Bass"
    case fingerBass = "Electric Bass (Finger)"
    case pickBass = "Electric Bass (Pick)"
    case fretlessBass = "Fretless Bass"
    case slapBass1 = "Slap Bass 1"
    case slapBass2 = "Slap Bass 2"
    case synthBass = "Synth Bass"
    case synthBass2 = "Synth Bass 2"

    // Strings variants
    case tremoloStrings = "Tremolo Strings"
    case pizzicatoStrings = "Pizzicato Strings"
    case stringEnsemble = "String Ensemble"
    case slowStrings = "Slow Strings"
    case synthStrings1 = "Synth Strings 1"
    case synthStrings2 = "Synth Strings 2"
    case choirAahs = "Choir Aahs"
    case voiceOohs = "Voice Oohs"

    // Brass variants
    case trumpet = "Trumpet"
    case trombone = "Trombone"
    case tuba = "Tuba"
    case mutedTrumpet = "Muted Trumpet"
    case frenchHorn = "French Horn"
    case brassSection = "Brass Section"
    case synthBrass1 = "Synth Brass 1"
    case synthBrass2 = "Synth Brass 2"

    // Woodwinds variants
    case sopranoSax = "Soprano Sax"
    case altoSax = "Alto Sax"
    case tenorSax = "Tenor Sax"
    case baritoneSax = "Baritone Sax"
    case oboe = "Oboe"
    case englishHorn = "English Horn"
    case bassoon = "Bassoon"
    case clarinet = "Clarinet"
    case piccolo = "Piccolo"
    case flute = "Flute"
    case recorder = "Recorder"
    case panFlute = "Pan Flute"

    // Organ variants
    case drawbarOrgan = "Drawbar Organ"
    case percussiveOrgan = "Percussive Organ"
    case rockOrgan = "Rock Organ"
    case churchOrgan = "Church Organ"
    case reedOrgan = "Reed Organ"
    case accordion = "Accordion"
    case harmonica = "Harmonica"
    case tangoAccordion = "Tango Accordion"

    // Mallet variants
    case celesta = "Celesta"
    case glockenspiel = "Glockenspiel"
    case musicBox = "Music Box"
    case vibraphone = "Vibraphone"
    case marimba = "Marimba"
    case xylophone = "Xylophone"
    case tubularBells = "Tubular Bells"
    case dulcimer = "Dulcimer"

    // Drum variants
    case standardDrumKit = "Standard Kit"
    case roomDrumKit = "Room Kit"
    case powerDrumKit = "Power Kit"
    case electronicDrumKit = "Electronic Kit"
    case tr808DrumKit = "TR-808 Kit"
    case jazzDrumKit = "Jazz Kit"
    case brushDrumKit = "Brush Kit"
    case orchestraDrumKit = "Orchestra Kit"
    case sfxDrumKit = "SFX Kit"
    
    var midiProgram: UInt8 {
        switch self {
        // Piano
        case .acousticPiano: return 0
        case .brightPiano: return 1
        case .electricPiano: return 4
        case .electricPiano2: return 5
        case .honkyTonkPiano: return 3
        case .harpsichord: return 6
        case .clavinet: return 7
        
        // Synth
        case .leadSquare: return 80
        case .leadSaw: return 81
        case .leadCalliope: return 82
        case .leadChiff: return 83
        case .leadCharang: return 84
        case .leadVoice: return 85
        case .leadFifths: return 86
        case .leadBass: return 87
        case .padNewAge: return 88
        case .padWarm: return 89
        case .padPolysynth: return 90
        case .padChoir: return 91
        case .padBowed: return 92
        case .padMetallic: return 93
        case .padHalo: return 94
        case .padSweep: return 95
        
        // Guitar
        case .acousticNylonGuitar: return 24
        case .acousticSteelGuitar: return 25
        case .jazzGuitar: return 26
        case .cleanGuitar: return 27
        case .electricGuitar: return 27
        case .mutedGuitar: return 28
        case .overdriveGuitar: return 29
        case .distortionGuitar: return 30
        case .harmonicsGuitar: return 31
        
        // Bass
        case .acousticBass: return 32
        case .fingerBass: return 33
        case .pickBass: return 34
        case .fretlessBass: return 35
        case .slapBass1: return 36
        case .slapBass2: return 37
        case .synthBass: return 38
        case .synthBass2: return 39

        // Strings
        case .tremoloStrings: return 44
        case .pizzicatoStrings: return 45
        case .stringEnsemble: return 48
        case .slowStrings: return 49
        case .synthStrings1: return 50
        case .synthStrings2: return 51
        case .choirAahs: return 52
        case .voiceOohs: return 53

        // Brass
        case .trumpet: return 56
        case .trombone: return 57
        case .tuba: return 58
        case .mutedTrumpet: return 59
        case .frenchHorn: return 60
        case .brassSection: return 61
        case .synthBrass1: return 62
        case .synthBrass2: return 63

        // Woodwinds
        case .sopranoSax: return 64
        case .altoSax: return 65
        case .tenorSax: return 66
        case .baritoneSax: return 67
        case .oboe: return 68
        case .englishHorn: return 69
        case .bassoon: return 70
        case .clarinet: return 71
        case .piccolo: return 72
        case .flute: return 73
        case .recorder: return 74
        case .panFlute: return 75

        // Organ
        case .drawbarOrgan: return 16
        case .percussiveOrgan: return 17
        case .rockOrgan: return 18
        case .churchOrgan: return 19
        case .reedOrgan: return 20
        case .accordion: return 21
        case .harmonica: return 22
        case .tangoAccordion: return 23

        // Mallets
        case .celesta: return 8
        case .glockenspiel: return 9
        case .musicBox: return 10
        case .vibraphone: return 11
        case .marimba: return 12
        case .xylophone: return 13
        case .tubularBells: return 14
        case .dulcimer: return 15

        // Drums (GM kits on channel 10)
        case .standardDrumKit: return 0
        case .roomDrumKit: return 8
        case .powerDrumKit: return 16
        case .electronicDrumKit: return 24
        case .tr808DrumKit: return 25
        case .jazzDrumKit: return 32
        case .brushDrumKit: return 40
        case .orchestraDrumKit: return 48
        case .sfxDrumKit: return 56
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
        if instrument == .guitar {
            self._variant = InstrumentVariant.cleanGuitar.rawValue
        } else {
            self._variant = instrument.variants.first?.rawValue
        }
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
