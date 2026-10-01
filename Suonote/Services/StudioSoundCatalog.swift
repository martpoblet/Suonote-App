import Foundation

/// The Studio's sound design table: which SoundFont preset each instrument
/// variant really plays, how loud that preset is, and how it should sit in a
/// mix (balance, stereo position, ambience, filtering, pedal).
///
/// Why this exists: GM presets in MuseScore General HQ differ by up to ~40 dB
/// in level (a muted guitar is near-silent next to slow strings) and a few
/// presets render silence under AUSampler. Without loudness matching and a
/// sensible default mix, every arrangement sounded muddy and lopsided.
enum StudioSoundCatalog {

    // MARK: - Presets

    struct Preset: Equatable {
        /// Melodic bank variation (LSB under the melodic MSB). Ignored for kits.
        let bankVariation: UInt8
        let program: UInt8
        let isPercussion: Bool
    }

    /// Variants whose original preset is silent under AUSampler (their SF2
    /// programming relies on filter modulators AUSampler doesn't implement)
    /// are routed to the closest-sounding working preset.
    static func preset(for variant: InstrumentVariant) -> Preset {
        if variant.isDrumKit {
            return Preset(bankVariation: 0, program: variant.midiProgram, isPercussion: true)
        }
        switch variant {
        case .padWarm:
            // "Warm Pad" (0/89) is silent → Halo pad has the same soft, warm body.
            return Preset(bankVariation: 0, program: 94, isPercussion: false)
        case .synthBass:
            // "Synth Bass 1" (0/38) is silent → bank-8 "Synth Bass 4" (analog, round).
            return Preset(bankVariation: 8, program: 39, isPercussion: false)
        default:
            return Preset(bankVariation: variant.bankVariation, program: variant.midiProgram, isPercussion: false)
        }
    }

    /// Parallel "amp" saturation for sampled electric basses (nil = none).
    /// GM bass samples are dull and almost inaudible on phone speakers; the
    /// mid harmonics give them growl and presence without touching the low end.
    static func bassAmpDrive(for variant: InstrumentVariant?) -> Double? {
        switch variant {
        case .fingerBass, .pickBass: return 1.0
        case .fretlessBass, .slapBass1, .slapBass2: return 0.6
        default: return nil
        }
    }

    /// Variants played by Suonote's own synth engine instead of the SoundFont.
    static func synthPreset(for variant: InstrumentVariant?) -> SynthPreset? {
        switch variant {
        case .synthAnalogPad: return .analogPad
        case .synthGlassPad: return .glassPad
        case .synthSupersaw: return .supersaw
        case .synthPluck: return .softPluck
        case .synthAnalogBass: return .analogBass
        case .synthSubBass: return .subBass
        default: return nil
        }
    }

    // MARK: - Mix roles

    enum Role {
        case drums, bass, keys, guitar, pad, strings, organ, brass, winds, lead, mallets
    }

    static func role(for instrument: StudioInstrument, variant: InstrumentVariant?) -> Role {
        switch instrument {
        case .drums: return .drums
        case .bass: return .bass
        case .piano: return .keys
        case .guitar: return .guitar
        case .strings: return .strings
        case .organ: return .organ
        case .brass: return .brass
        case .woodwinds: return .winds
        case .mallets: return .mallets
        case .synth:
            switch variant {
            case .leadSquare, .leadSaw, .leadCalliope, .leadChiff, .leadCharang,
                 .leadVoice, .leadFifths, .leadBass:
                return .lead
            default:
                return .pad
            }
        case .audio: return .keys
        }
    }

    struct MixProfile {
        /// Balance relative to a loudness-matched drum kit, in dB.
        let levelDB: Float
        /// Default stereo position (-1…1) — only used while the user's pan is centered.
        let pan: Float
        /// Send to the shared ambience reverb (0…1).
        let ambience: Float
        /// High-pass corner to keep the low end for bass & kick (Hz, 0 = off).
        let highPassHz: Float
        /// Gentle top-end roll-off for warmth (Hz, 0 = off).
        let lowPassHz: Float
        /// Sustain pedal follows chord changes (pianos, EPs).
        let sustainPedal: Bool
    }

    static func mixProfile(for role: Role, style: StudioStyle?) -> MixProfile {
        let base: MixProfile
        switch role {
        case .drums:   base = MixProfile(levelDB: 0,   pan: 0,     ambience: 0.10, highPassHz: 0,   lowPassHz: 0, sustainPedal: false)
        case .bass:    base = MixProfile(levelDB: 1,   pan: 0,     ambience: 0.0,  highPassHz: 0,   lowPassHz: 0, sustainPedal: false)
        case .keys:    base = MixProfile(levelDB: -1,  pan: 0.12,  ambience: 0.22, highPassHz: 70,  lowPassHz: 0, sustainPedal: true)
        case .guitar:  base = MixProfile(levelDB: 0,   pan: -0.32, ambience: 0.18, highPassHz: 90,  lowPassHz: 0, sustainPedal: false)
        case .pad:     base = MixProfile(levelDB: -4,  pan: 0,     ambience: 0.35, highPassHz: 140, lowPassHz: 0, sustainPedal: false)
        case .strings: base = MixProfile(levelDB: -4,  pan: 0.22,  ambience: 0.38, highPassHz: 110, lowPassHz: 0, sustainPedal: false)
        case .organ:   base = MixProfile(levelDB: -5,  pan: -0.18, ambience: 0.2,  highPassHz: 100, lowPassHz: 0, sustainPedal: false)
        case .brass:   base = MixProfile(levelDB: -4,  pan: 0.28,  ambience: 0.26, highPassHz: 110, lowPassHz: 0, sustainPedal: false)
        case .winds:   base = MixProfile(levelDB: -3,  pan: -0.25, ambience: 0.28, highPassHz: 140, lowPassHz: 0, sustainPedal: false)
        case .lead:    base = MixProfile(levelDB: -4,  pan: 0.08,  ambience: 0.24, highPassHz: 160, lowPassHz: 0, sustainPedal: false)
        case .mallets: base = MixProfile(levelDB: -3,  pan: 0.35,  ambience: 0.3,  highPassHz: 180, lowPassHz: 0, sustainPedal: false)
        }
        guard let style else { return base }
        // Style colour: lo-fi is darker and roomier, EDM/hip-hop drier and
        // brighter, ambient drenched.
        var ambience = base.ambience
        var lowPass = base.lowPassHz
        var level = base.levelDB
        switch style {
        case .lofi:
            ambience *= 1.15
            lowPass = role == .bass || role == .drums ? 9_000 : 6_500
            if role == .keys { level += 3 }
            if role == .pad { level += 5 }
            if role == .drums { level -= 1 }
        case .ambient:
            ambience = min(0.6, ambience * 1.6 + 0.05)
        case .edm, .hiphop:
            ambience *= role == .drums || role == .bass ? 0.4 : 0.85
            if role == .drums { level += 1 }
        case .jazz:
            ambience *= 1.1
            if role == .drums { level -= 2 }
        case .rock:
            if role == .guitar { level += 8 }
            if role == .bass { level -= 6 }
            if role == .drums { level -= 2 }
        case .pop, .funk:
            if role == .drums { level += 1.5 }
        }
        return MixProfile(
            levelDB: level,
            pan: base.pan,
            ambience: ambience,
            highPassHz: base.highPassHz,
            lowPassHz: lowPass,
            sustainPedal: base.sustainPedal
        )
    }

    /// Corrective EQ a mix engineer would start from, per role (used while the
    /// user hasn't set their own EQ). Values: low shelf @ lowHz, bell @ midHz,
    /// high shelf @ highHz, in dB.
    struct AutoEQ {
        let lowHz: Float, low: Float
        let midHz: Float, mid: Float, midWidth: Float
        let highHz: Float, high: Float
    }

    static func autoEQ(for role: Role) -> AutoEQ? {
        switch role {
        case .bass:    return AutoEQ(lowHz: 90, low: 2.5, midHz: 420, mid: -3.5, midWidth: 1.2, highHz: 2_600, high: 2)
        case .drums:   return AutoEQ(lowHz: 70, low: 2, midHz: 420, mid: -2.5, midWidth: 1.4, highHz: 8_000, high: 2.5)
        case .keys:    return AutoEQ(lowHz: 180, low: -1.5, midHz: 350, mid: -2, midWidth: 1.2, highHz: 6_000, high: 1.5)
        case .guitar:  return AutoEQ(lowHz: 200, low: -2.5, midHz: 900, mid: -1, midWidth: 1.5, highHz: 5_000, high: 2)
        case .strings: return AutoEQ(lowHz: 220, low: -1.5, midHz: 450, mid: -2, midWidth: 1.3, highHz: 8_000, high: 1.5)
        case .pad:     return AutoEQ(lowHz: 250, low: -2, midHz: 500, mid: -1.5, midWidth: 1.5, highHz: 7_000, high: 1)
        case .organ:   return AutoEQ(lowHz: 200, low: -1.5, midHz: 400, mid: -2, midWidth: 1.3, highHz: 5_000, high: 1)
        case .brass:   return AutoEQ(lowHz: 200, low: -1, midHz: 600, mid: -1.5, midWidth: 1.4, highHz: 4_000, high: 1)
        case .winds, .lead, .mallets: return nil
        }
    }

    /// Shared ambience reverb per style.
    static func ambienceReverbPreset(for style: StudioStyle?) -> Int {
        switch style {
        case .ambient: return 6   // large hall
        case .jazz: return 4      // medium hall
        case .lofi: return 1      // medium room
        case .edm, .hiphop: return 10 // plate
        case .rock: return 2      // large room
        default: return 5         // medium chamber
        }
    }

    // MARK: - Loudness matching

    /// Gain (dB) that brings each preset to a common reference loudness
    /// (≈ -20 dBFS max-momentary RMS for a velocity-90 chord / note / groove).
    /// Measured offline from MS_Basic.sf2 with the Suonote render harness.
    static func loudnessTrimDB(for variant: InstrumentVariant?, instrument: StudioInstrument) -> Float {
        guard let variant else { return 0 }
        let trim = measuredTrims[variant] ?? 0
        return max(-16, min(24, trim))
    }

    static let measuredTrims: [InstrumentVariant: Float] = [
        .acousticPiano: 0.2,
        .mellowGrandPiano: 0.7,
        .brightPiano: 1.5,
        .electricPiano: -1.8,
        .vintageElectricPiano: -3.5,
        .electricPiano2: -9.3,
        .electricGrandPiano: 3.5,
        .honkyTonkPiano: -1.5,
        .clavinet: 6.6,
        .harpsichord: 3.4,
        .harp: 0.3,
        .padWarm: -1.5,
        .padPolysynth: -2.7,
        .padHalo: -1.5,
        .padSweep: -4.6,
        .padSoundtrack: -5.2,
        .padAtmosphere: -2.1,
        .padNewAge: -8.8,
        .padChoir: -1.4,
        .padBowed: 3.6,
        .padMetallic: -0.9,
        .leadSaw: -8.2,
        .leadSquare: 0.0,
        .leadFifths: -0.5,
        .leadCharang: -1.6,
        .leadChiff: 3.5,
        .leadCalliope: 9.0,
        .leadVoice: 2.7,
        .leadBass: -5.8,
        .acousticSteelGuitar: 5.7,
        .acousticNylonGuitar: 2.1,
        .cleanGuitar: -0.7,
        .funkGuitar: -1.3,
        .jazzGuitar: 4.2,
        .twelveStringGuitar: 3.7,
        .mutedGuitar: 13.6,
        .overdriveGuitar: -0.7,
        .distortionGuitar: 0.9,
        .ukulele: 1.0,
        .harmonicsGuitar: -0.9,
        .fingerBass: 3.4,         // includes the bass amp (bassAmpDrive)
        .pickBass: 5.0,
        .acousticBass: 6.5,
        .fretlessBass: 2.6,
        .synthBass: 5.5,
        .analogBass: 5.5,
        .synthBass2: 6.8,
        .slapBass1: 8.8,
        .slapBass2: 14.6,
        .stringEnsemble: -13.2,
        .slowStrings: -13.4,
        .padOrchestral: -10.0,
        .tremoloStrings: -12.7,
        .pizzicatoStrings: -10.6,
        .synthStrings1: -3.3,
        .synthStrings2: -3.3,
        .synthStrings3: -2.7,
        .choirAahs: -0.2,
        .voiceOohs: 2.8,
        .brassSection: 4.2,
        .trumpet: 5.4,
        .trombone: -3.1,
        .frenchHorn: 1.5,
        .mutedTrumpet: 3.0,
        .tuba: -3.2,
        .synthBrass1: -6.6,
        .synthBrass2: -0.2,
        .flute: 3.9,
        .clarinet: 5.9,
        .altoSax: 5.1,
        .tenorSax: 11.2,
        .sopranoSax: 7.0,
        .baritoneSax: 10.1,
        .oboe: 5.1,
        .englishHorn: 11.0,
        .bassoon: 5.3,
        .piccolo: 2.2,
        .recorder: 4.3,
        .panFlute: 5.4,
        .ocarina: 1.3,
        .drawbarOrgan: 6.4,
        .percussiveOrgan: -1.3,
        .rockOrgan: -0.2,
        .churchOrgan: 0.9,
        .reedOrgan: -1.3,
        .accordion: 1.7,
        .harmonica: 0.8,
        .tangoAccordion: -1.6,
        .vibraphone: 8.6,
        .marimba: 9.4,
        .celesta: 7.3,
        .glockenspiel: 15.2,
        .musicBox: 5.2,
        .xylophone: 29.6,
        .kalimba: 18.4,
        .tubularBells: 10.0,
        .dulcimer: 13.1,
        .standardDrumKit: 5.1,
        .roomDrumKit: 5.7,
        .powerDrumKit: 2.5,
        .electronicDrumKit: 4.6,
        .tr808DrumKit: 1.4,
        .jazzDrumKit: 3.5,
        .brushDrumKit: 3.7,
        .orchestraDrumKit: -0.6,
        // Suonote synth engine
        .synthAnalogPad: 0.0,
        .synthGlassPad: 4.0,
        .synthSupersaw: 2.1,
        .synthPluck: 6.2,
        .synthAnalogBass: 1.6,
        .synthSubBass: -3.0,
    ]
}
