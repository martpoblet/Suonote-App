import Foundation
import SwiftData
import SwiftUI

enum ReverbPreset: String, Codable, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case plate = "plate"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return String(localized: "Small Room")
        case .medium: return String(localized: "Medium Hall")
        case .large: return String(localized: "Large Hall")
        case .plate: return String(localized: "Plate")
        }
    }
    var avPreset: Int {
        switch self {
        case .small: return 2   // AVAudioUnitReverbPreset.smallRoom
        case .medium: return 4  // AVAudioUnitReverbPreset.mediumHall
        case .large: return 6   // AVAudioUnitReverbPreset.largeHall
        case .plate: return 10  // AVAudioUnitReverbPreset.plate
        }
    }
    var shortTitle: String {
        switch self {
        case .small: return String(localized: "Small")
        case .medium: return String(localized: "Medium")
        case .large: return String(localized: "Large")
        case .plate: return String(localized: "Plate")
        }
    }
}

enum DelaySyncMode: String, Codable, CaseIterable, Identifiable {
    case free = "free"
    case quarter = "1/4"
    case eighth = "1/8"
    case dottedEighth = "dotted 1/8"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .free: return String(localized: "Free")
        case .quarter: return String(localized: "1/4 Note")
        case .eighth: return String(localized: "1/8 Note")
        case .dottedEighth: return String(localized: "Dotted 1/8")
        }
    }
    func delayTime(bpm: Double) -> Double {
        let beatDuration = 60.0 / bpm
        switch self {
        case .free: return 0.25
        case .quarter: return beatDuration
        case .eighth: return beatDuration / 2.0
        case .dottedEighth: return beatDuration * 0.75
        }
    }
    var shortTitle: String {
        switch self {
        case .free: return String(localized: "Free")
        case .quarter: return "1/4"
        case .eighth: return "1/8"
        case .dottedEighth: return String(localized: "D 1/8")
        }
    }
}

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
        case .pop: return String(localized: "Pop")
        case .rock: return String(localized: "Rock")
        case .lofi: return String(localized: "Lo-Fi")
        case .edm: return String(localized: "EDM")
        case .jazz: return String(localized: "Jazz")
        case .hiphop: return String(localized: "Hip-Hop")
        case .funk: return String(localized: "Funk")
        case .ambient: return String(localized: "Ambient")
        }
    }

    var description: String {
        switch self {
        case .pop: return String(localized: "Clean, tight groove with bright chords.")
        case .rock: return String(localized: "Punchy drums with driving guitars.")
        case .lofi: return String(localized: "Soft drums, warm keys, mellow bass.")
        case .edm: return String(localized: "Four‑on‑the‑floor with big synths.")
        case .jazz: return String(localized: "Swung rhythms with complex harmonies.")
        case .hiphop: return String(localized: "Hard-hitting drums with deep bass.")
        case .funk: return String(localized: "Groovy bass with syncopated rhythms.")
        case .ambient: return String(localized: "Atmospheric pads with sparse drums.")
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
        case .piano: return String(localized: "Piano")
        case .synth: return String(localized: "Synth")
        case .guitar: return String(localized: "Guitar")
        case .bass: return String(localized: "Bass")
        case .strings: return String(localized: "Strings")
        case .brass: return String(localized: "Brass")
        case .woodwinds: return String(localized: "Woodwinds")
        case .organ: return String(localized: "Organ")
        case .mallets: return String(localized: "Mallets")
        case .drums: return String(localized: "Drums")
        case .audio: return String(localized: "Audio")
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
        case .audio: return DesignSystem.Colors.secondary
        }
    }

    var isAudio: Bool {
        self == .audio
    }

    /// How many generated tracks of this instrument a project may contain.
    /// Most instruments are unique; piano can be layered up to three times.
    var maxStudioTracks: Int {
        switch self {
        case .piano: return 3
        default: return 1
        }
    }

    var variants: [InstrumentVariant] {
        SoundFontManager.supportedVariants(for: self)
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
    case harp = "Harp"
    case mellowGrandPiano = "Mellow Grand Piano"
    case vintageElectricPiano = "Vintage EP"
    case electricGrandPiano = "Electric Grand"

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
    case padOrchestral = "Pad (Orchestral)"
    case padSoundtrack = "Pad (Soundtrack)"
    case padAtmosphere = "Pad (Atmosphere)"
    case synthStrings3 = "Synth Strings 3"
    // Suonote synth engine (not SoundFont)
    case synthAnalogPad = "Analog Pad"
    case synthGlassPad = "Glass Pad"
    case synthSupersaw = "Supersaw"
    case synthPluck = "Soft Pluck"
    
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
    case funkGuitar = "Funk Guitar"
    case twelveStringGuitar = "12-String Guitar"
    case ukulele = "Ukulele"
    
    // Bass variants
    case acousticBass = "Acoustic Bass"
    case fingerBass = "Electric Bass (Finger)"
    case pickBass = "Electric Bass (Pick)"
    case fretlessBass = "Fretless Bass"
    case slapBass1 = "Slap Bass 1"
    case slapBass2 = "Slap Bass 2"
    case synthBass = "Synth Bass"
    case synthBass2 = "Synth Bass 2"
    case analogBass = "Analog Bass"
    case synthAnalogBass = "Analog Synth Bass"
    case synthSubBass = "Sub Bass"

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
    case ocarina = "Ocarina"

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
    case kalimba = "Kalimba"

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
        case .harp: return 46
        case .mellowGrandPiano: return 0
        case .vintageElectricPiano: return 4
        case .electricGrandPiano: return 2
        
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
        case .padOrchestral: return 48
        case .padSoundtrack: return 97
        case .padAtmosphere: return 99
        case .synthStrings3: return 50
        case .synthAnalogPad: return 89
        case .synthGlassPad: return 92
        case .synthSupersaw: return 81
        case .synthPluck: return 84
        
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
        case .funkGuitar: return 28
        case .twelveStringGuitar: return 25
        case .ukulele: return 24
        
        // Bass
        case .acousticBass: return 32
        case .fingerBass: return 33
        case .pickBass: return 34
        case .fretlessBass: return 35
        case .slapBass1: return 36
        case .slapBass2: return 37
        case .synthBass: return 38
        case .synthBass2: return 39
        case .analogBass: return 39
        case .synthAnalogBass: return 38
        case .synthSubBass: return 38

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
        case .ocarina: return 79

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
        case .kalimba: return 108

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

    /// SoundFont bank variation (bank LSB under the melodic MSB). MuseScore
    /// General HQ keeps its alternate tones (mellow grand, vintage EP, funk
    /// guitar…) in bank 8.
    var bankVariation: UInt8 {
        switch self {
        case .mellowGrandPiano, .vintageElectricPiano, .padOrchestral, .synthStrings3,
             .funkGuitar, .twelveStringGuitar, .ukulele, .analogBass:
            return 8
        default:
            return 0
        }
    }

    /// The sound's name in the user's language (raw values stay English: they are persisted).
    var displayName: String {
        switch self {
        case .acousticPiano: return String(localized: "Acoustic Piano", comment: "Instrument sound name")
        case .electricPiano: return String(localized: "Electric Piano", comment: "Instrument sound name")
        case .brightPiano: return String(localized: "Bright Piano", comment: "Instrument sound name")
        case .electricPiano2: return String(localized: "Electric Piano 2", comment: "Instrument sound name")
        case .honkyTonkPiano: return String(localized: "Honky-Tonk Piano", comment: "Instrument sound name")
        case .harpsichord: return String(localized: "Harpsichord", comment: "Instrument sound name")
        case .clavinet: return String(localized: "Clavinet", comment: "Instrument sound name")
        case .harp: return String(localized: "Concert Harp", comment: "Instrument sound name")
        case .mellowGrandPiano: return String(localized: "Mellow Grand Piano", comment: "Instrument sound name")
        case .vintageElectricPiano: return String(localized: "Vintage EP", comment: "Instrument sound name")
        case .electricGrandPiano: return String(localized: "Electric Grand", comment: "Instrument sound name")
        case .leadSquare: return String(localized: "Lead (Square)", comment: "Instrument sound name")
        case .leadSaw: return String(localized: "Lead (Saw)", comment: "Instrument sound name")
        case .leadCalliope: return String(localized: "Lead (Calliope)", comment: "Instrument sound name")
        case .leadChiff: return String(localized: "Lead (Chiff)", comment: "Instrument sound name")
        case .leadCharang: return String(localized: "Lead (Charang)", comment: "Instrument sound name")
        case .leadVoice: return String(localized: "Lead (Voice)", comment: "Instrument sound name")
        case .leadFifths: return String(localized: "Lead (Fifths)", comment: "Instrument sound name")
        case .leadBass: return String(localized: "Lead (Bass + Lead)", comment: "Instrument sound name")
        case .padNewAge: return String(localized: "Pad (New Age)", comment: "Instrument sound name")
        case .padWarm: return String(localized: "Pad (Warm)", comment: "Instrument sound name")
        case .padPolysynth: return String(localized: "Pad (Polysynth)", comment: "Instrument sound name")
        case .padChoir: return String(localized: "Pad (Choir)", comment: "Instrument sound name")
        case .padBowed: return String(localized: "Pad (Bowed)", comment: "Instrument sound name")
        case .padMetallic: return String(localized: "Pad (Metallic)", comment: "Instrument sound name")
        case .padHalo: return String(localized: "Pad (Halo)", comment: "Instrument sound name")
        case .padSweep: return String(localized: "Pad (Sweep)", comment: "Instrument sound name")
        case .padOrchestral: return String(localized: "Pad (Orchestral)", comment: "Instrument sound name")
        case .padSoundtrack: return String(localized: "Pad (Soundtrack)", comment: "Instrument sound name")
        case .padAtmosphere: return String(localized: "Pad (Atmosphere)", comment: "Instrument sound name")
        case .synthStrings3: return String(localized: "Synth Strings 3", comment: "Instrument sound name")
        case .synthAnalogPad: return String(localized: "Analog Pad", comment: "Instrument sound name")
        case .synthGlassPad: return String(localized: "Glass Pad", comment: "Instrument sound name")
        case .synthSupersaw: return String(localized: "Supersaw", comment: "Instrument sound name")
        case .synthPluck: return String(localized: "Soft Pluck", comment: "Instrument sound name")
        case .acousticNylonGuitar: return String(localized: "Acoustic Guitar (Nylon)", comment: "Instrument sound name")
        case .acousticSteelGuitar: return String(localized: "Acoustic Guitar (Steel)", comment: "Instrument sound name")
        case .electricGuitar: return String(localized: "Electric Guitar", comment: "Instrument sound name")
        case .cleanGuitar: return String(localized: "Clean Guitar", comment: "Instrument sound name")
        case .jazzGuitar: return String(localized: "Jazz Guitar", comment: "Instrument sound name")
        case .mutedGuitar: return String(localized: "Muted Guitar", comment: "Instrument sound name")
        case .overdriveGuitar: return String(localized: "Overdrive Guitar", comment: "Instrument sound name")
        case .distortionGuitar: return String(localized: "Distortion Guitar", comment: "Instrument sound name")
        case .harmonicsGuitar: return String(localized: "Guitar Harmonics", comment: "Instrument sound name")
        case .funkGuitar: return String(localized: "Funk Guitar", comment: "Instrument sound name")
        case .twelveStringGuitar: return String(localized: "12-String Guitar", comment: "Instrument sound name")
        case .ukulele: return String(localized: "Ukulele", comment: "Instrument sound name")
        case .acousticBass: return String(localized: "Acoustic Bass", comment: "Instrument sound name")
        case .fingerBass: return String(localized: "Electric Bass (Finger)", comment: "Instrument sound name")
        case .pickBass: return String(localized: "Electric Bass (Pick)", comment: "Instrument sound name")
        case .fretlessBass: return String(localized: "Fretless Bass", comment: "Instrument sound name")
        case .slapBass1: return String(localized: "Slap Bass 1", comment: "Instrument sound name")
        case .slapBass2: return String(localized: "Slap Bass 2", comment: "Instrument sound name")
        case .synthBass: return String(localized: "Synth Bass", comment: "Instrument sound name")
        case .synthBass2: return String(localized: "Synth Bass 2", comment: "Instrument sound name")
        case .analogBass: return String(localized: "Analog Bass", comment: "Instrument sound name")
        case .synthAnalogBass: return String(localized: "Analog Synth Bass", comment: "Instrument sound name")
        case .synthSubBass: return String(localized: "Sub Bass", comment: "Instrument sound name")
        case .tremoloStrings: return String(localized: "Tremolo Strings", comment: "Instrument sound name")
        case .pizzicatoStrings: return String(localized: "Pizzicato Strings", comment: "Instrument sound name")
        case .stringEnsemble: return String(localized: "String Ensemble", comment: "Instrument sound name")
        case .slowStrings: return String(localized: "Slow Strings", comment: "Instrument sound name")
        case .synthStrings1: return String(localized: "Synth Strings 1", comment: "Instrument sound name")
        case .synthStrings2: return String(localized: "Synth Strings 2", comment: "Instrument sound name")
        case .choirAahs: return String(localized: "Choir Aahs", comment: "Instrument sound name")
        case .voiceOohs: return String(localized: "Voice Oohs", comment: "Instrument sound name")
        case .trumpet: return String(localized: "Trumpet", comment: "Instrument sound name")
        case .trombone: return String(localized: "Trombone", comment: "Instrument sound name")
        case .tuba: return String(localized: "Tuba", comment: "Instrument sound name")
        case .mutedTrumpet: return String(localized: "Muted Trumpet", comment: "Instrument sound name")
        case .frenchHorn: return String(localized: "French Horn", comment: "Instrument sound name")
        case .brassSection: return String(localized: "Brass Section", comment: "Instrument sound name")
        case .synthBrass1: return String(localized: "Synth Brass 1", comment: "Instrument sound name")
        case .synthBrass2: return String(localized: "Synth Brass 2", comment: "Instrument sound name")
        case .sopranoSax: return String(localized: "Soprano Sax", comment: "Instrument sound name")
        case .altoSax: return String(localized: "Alto Sax", comment: "Instrument sound name")
        case .tenorSax: return String(localized: "Tenor Sax", comment: "Instrument sound name")
        case .baritoneSax: return String(localized: "Baritone Sax", comment: "Instrument sound name")
        case .oboe: return String(localized: "Oboe", comment: "Instrument sound name")
        case .englishHorn: return String(localized: "English Horn", comment: "Instrument sound name")
        case .bassoon: return String(localized: "Bassoon", comment: "Instrument sound name")
        case .clarinet: return String(localized: "Clarinet", comment: "Instrument sound name")
        case .piccolo: return String(localized: "Piccolo", comment: "Instrument sound name")
        case .flute: return String(localized: "Flute", comment: "Instrument sound name")
        case .recorder: return String(localized: "Recorder", comment: "Instrument sound name")
        case .panFlute: return String(localized: "Pan Flute", comment: "Instrument sound name")
        case .ocarina: return String(localized: "Ocarina", comment: "Instrument sound name")
        case .drawbarOrgan: return String(localized: "Drawbar Organ", comment: "Instrument sound name")
        case .percussiveOrgan: return String(localized: "Percussive Organ", comment: "Instrument sound name")
        case .rockOrgan: return String(localized: "Rock Organ", comment: "Instrument sound name")
        case .churchOrgan: return String(localized: "Church Organ", comment: "Instrument sound name")
        case .reedOrgan: return String(localized: "Reed Organ", comment: "Instrument sound name")
        case .accordion: return String(localized: "Accordion", comment: "Instrument sound name")
        case .harmonica: return String(localized: "Harmonica", comment: "Instrument sound name")
        case .tangoAccordion: return String(localized: "Tango Accordion", comment: "Instrument sound name")
        case .celesta: return String(localized: "Celesta", comment: "Instrument sound name")
        case .glockenspiel: return String(localized: "Glockenspiel", comment: "Instrument sound name")
        case .musicBox: return String(localized: "Music Box", comment: "Instrument sound name")
        case .vibraphone: return String(localized: "Vibraphone", comment: "Instrument sound name")
        case .marimba: return String(localized: "Marimba", comment: "Instrument sound name")
        case .xylophone: return String(localized: "Xylophone", comment: "Instrument sound name")
        case .tubularBells: return String(localized: "Tubular Bells", comment: "Instrument sound name")
        case .dulcimer: return String(localized: "Dulcimer", comment: "Instrument sound name")
        case .kalimba: return String(localized: "Kalimba", comment: "Instrument sound name")
        case .standardDrumKit: return String(localized: "Standard Kit", comment: "Instrument sound name")
        case .roomDrumKit: return String(localized: "Room Kit", comment: "Instrument sound name")
        case .powerDrumKit: return String(localized: "Power Kit", comment: "Instrument sound name")
        case .electronicDrumKit: return String(localized: "Electronic Kit", comment: "Instrument sound name")
        case .tr808DrumKit: return String(localized: "TR-808 Kit", comment: "Instrument sound name")
        case .jazzDrumKit: return String(localized: "Jazz Kit", comment: "Instrument sound name")
        case .brushDrumKit: return String(localized: "Brush Kit", comment: "Instrument sound name")
        case .orchestraDrumKit: return String(localized: "Orchestra Kit", comment: "Instrument sound name")
        case .sfxDrumKit: return String(localized: "SFX Kit", comment: "Instrument sound name")
        }
    }

    var isDrumKit: Bool {
        switch self {
        case .standardDrumKit,
             .roomDrumKit,
             .powerDrumKit,
             .electronicDrumKit,
             .tr808DrumKit,
             .jazzDrumKit,
             .brushDrumKit,
             .orchestraDrumKit,
             .sfxDrumKit:
            return true
        default:
            return false
        }
    }
}

@Model
final class StudioTrack {
    var id: UUID = UUID()
    var name: String = ""
    var orderIndex: Int = 0
    private var _instrument: String = StudioInstrument.piano.rawValue
    private var _drumPreset: String = ""
    private var _variant: String? = nil
    var octaveShift: Int = 2
    var isMuted: Bool = false
    var isSolo: Bool = false
    var volume: Float = 0.75
    var pan: Float = 0.0
    var regenerateIntensity: Double = 0.5
    var regenerateComplexity: Double = 0.5
    var regenerateNaturalness: Double = 0.0
    var regenerateArpeggioEnabled: Bool = false
    private var _regenerateArpeggioRate: String = "1/8"
    private var _regenerateArpeggioPattern: String = "Up"
    /// User-selected accompaniment pattern for chord instruments.
    private var _compingPattern: String = "auto"
    /// User-selected bass line style.
    private var _bassPattern: String = "auto"
    var createdAt: Date = Date()
    var audioRecordingId: UUID? = nil
    var audioStartBeat: Double = 0

    // Per-track effects
    var reverbEnabled: Bool = false
    var reverbMix: Float = 0.3
    private var _reverbPreset: String = "medium"
    var delayEnabled: Bool = false
    var delayTime: Float = 0.25
    var delayMix: Float = 0.2
    private var _delaySyncMode: String = "free"
    var eqEnabled: Bool = false
    var eqLowGain: Float = 0.0
    var eqMidGain: Float = 0.0
    var eqHighGain: Float = 0.0
    /// When true, the generator arranges this part by section (enters,
    /// drops out, thins or builds with the song's structure).
    var followsArrangement: Bool = true
    var compressorEnabled: Bool = false
    var compressorThreshold: Float = -20.0
    var compressorRatio: Float = 4.0

    var reverbPreset: ReverbPreset {
        get { ReverbPreset(rawValue: _reverbPreset) ?? .medium }
        set { _reverbPreset = newValue.rawValue }
    }

    var delaySyncMode: DelaySyncMode {
        get { DelaySyncMode(rawValue: _delaySyncMode) ?? .free }
        set { _delaySyncMode = newValue.rawValue }
    }

    var notesStore: [StudioNote]? = []
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
        audioStartBeat: Double = 0,
        style: StudioStyle? = nil
    ) {
        self.name = name
        self.orderIndex = orderIndex
        self._instrument = instrument.rawValue
        self._drumPreset = ""
        self._variant = SoundFontManager.defaultVariant(for: instrument, style: style)?.rawValue
        self.octaveShift = 2
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.volume = 0.75
        self.pan = 0.0
        self.regenerateIntensity = 0.5
        self.regenerateComplexity = 0.5
        self.regenerateNaturalness = 0.0
        self.regenerateArpeggioEnabled = false
        self._regenerateArpeggioRate = "1/8"
        self._regenerateArpeggioPattern = "Up"
        self._compingPattern = "auto"
        self._bassPattern = "auto"
        self.createdAt = Date()
        self.audioRecordingId = audioRecordingId
        self.audioStartBeat = audioStartBeat
        self.notesStore = []
    }

    var notes: [StudioNote] {
        get { notesStore ?? [] }
        set {
            notesStore = newValue
            for note in newValue {
                note.track = self
            }
        }
    }

    var regenerateArpeggioRate: String {
        get { _regenerateArpeggioRate }
        set { _regenerateArpeggioRate = newValue }
    }

    var regenerateArpeggioPattern: String {
        get { _regenerateArpeggioPattern }
        set { _regenerateArpeggioPattern = newValue }
    }

    var compingPattern: CompingPattern {
        get { CompingPattern(rawValue: _compingPattern) ?? .auto }
        set { _compingPattern = newValue.rawValue }
    }

    var bassPattern: BassPattern {
        get { BassPattern(rawValue: _bassPattern) ?? .auto }
        set { _bassPattern = newValue.rawValue }
    }
}

/// How a bass line is built. `auto` keeps the smart per-style line; the rest
/// let the user pick a feel explicitly.
enum BassPattern: String, CaseIterable, Identifiable {
    case auto
    case roots          // one root per chord
    case rootFifth      // root + fifth
    case octaves        // root/octave bounce
    case walking        // 4-to-the-bar walking line
    case syncopated     // funky offbeats
    case pedal          // repeated tonic pedal
    case offbeat        // upbeat bounce
    case anticipated    // pushes into the next chord
    case sparse         // roomy roots
    case drive          // modern pop/rock eighth-note drive
    case pocket         // pop pocket: locked to the kick, approach into changes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .roots: return String(localized: "Roots")
        case .rootFifth: return String(localized: "Root + Fifth")
        case .octaves: return String(localized: "Octaves")
        case .walking: return String(localized: "Walking")
        case .syncopated: return String(localized: "Syncopated")
        case .pedal: return String(localized: "Pedal Tone")
        case .offbeat: return String(localized: "Offbeat Bounce")
        case .anticipated: return String(localized: "Anticipated")
        case .sparse: return String(localized: "Sparse")
        case .drive: return String(localized: "Eighth-Note Drive")
        case .pocket: return String(localized: "Pocket Groove")
        }
    }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .roots: return "circle.fill"
        case .rootFifth: return "circle.grid.2x1.fill"
        case .octaves: return "arrow.up.arrow.down"
        case .walking: return "figure.walk"
        case .syncopated: return "bolt.fill"
        case .pedal: return "repeat"
        case .offbeat: return "forward.frame.fill"
        case .anticipated: return "arrowshape.turn.up.right.fill"
        case .sparse: return "circle.dotted"
        case .drive: return "waveform.path"
        case .pocket: return "music.note.house"
        }
    }
}

/// How a chord instrument articulates its harmony. `auto` keeps the smart
/// per-style behavior; the rest let the user pick explicitly.
enum CompingPattern: String, CaseIterable, Identifiable {
    case auto
    case block
    case sustained
    case arpeggioUp
    case arpeggioDown
    case arpeggioUpDown
    case alberti
    case offbeat
    case pulse
    case stabs
    case anticipation
    case waltz
    case ostinato
    case tremolo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .block: return String(localized: "Block / Comp")
        case .sustained: return String(localized: "Sustained Pad")
        case .arpeggioUp: return String(localized: "Arpeggio ↑")
        case .arpeggioDown: return String(localized: "Arpeggio ↓")
        case .arpeggioUpDown: return String(localized: "Arpeggio ↑↓")
        case .alberti: return String(localized: "Alberti / Broken")
        case .offbeat: return String(localized: "Offbeat Chops")
        case .pulse: return String(localized: "Pulse")
        case .stabs: return String(localized: "Short Stabs")
        case .anticipation: return String(localized: "Pushes")
        case .waltz: return String(localized: "Waltz Comp")
        case .ostinato: return String(localized: "Ostinato")
        case .tremolo: return String(localized: "Tremolo Pad")
        }
    }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .block: return "rectangle.grid.1x2"
        case .sustained: return "rectangle.fill"
        case .arpeggioUp: return "arrow.up.right"
        case .arpeggioDown: return "arrow.down.right"
        case .arpeggioUpDown: return "arrow.up.arrow.down"
        case .alberti: return "water.waves"
        case .offbeat: return "forward.frame.fill"
        case .pulse: return "metronome"
        case .stabs: return "bolt.fill"
        case .anticipation: return "arrowshape.turn.up.right.fill"
        case .waltz: return "music.note.list"
        case .ostinato: return "repeat"
        case .tremolo: return "waveform.path.ecg"
        }
    }

    /// Whether choosing this pattern exposes the arpeggio rate control.
    var usesRate: Bool {
        switch self {
        case .arpeggioUp, .arpeggioDown, .arpeggioUpDown, .alberti, .ostinato: return true
        case .auto, .block, .sustained, .offbeat, .pulse, .stabs, .anticipation, .waltz, .tremolo: return false
        }
    }
}

@Model
final class StudioNote {
    var id: UUID = UUID()
    var startBeat: Double = 0
    var duration: Double = 1
    var pitch: Int = 60
    var velocity: Int = 90
    var track: StudioTrack?

    init(
        startBeat: Double,
        duration: Double,
        pitch: Int,
        velocity: Int = 90
    ) {
        self.startBeat = startBeat
        self.duration = duration
        self.pitch = pitch
        self.velocity = velocity
    }
}
