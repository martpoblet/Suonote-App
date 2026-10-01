import os
import Foundation

enum SoundFontManager {
    static let folderName = "SoundFonts"
    /// MS Basic (MuseScore General) — MIT-licensed full-GM bank, so every
    /// variant below maps to a real preset.
    private static let bankFilePath = "MuseScore/MS_Basic"

    static func supportedVariants(for instrument: StudioInstrument) -> [InstrumentVariant] {
        // First entry is the default for new tracks when no style is known
        // (and the fallback for persisted tracks whose stored variant is no
        // longer supported). Ordered best-sounding first.
        switch instrument {
        case .piano:
            return [.acousticPiano, .mellowGrandPiano, .brightPiano, .electricPiano,
                    .vintageElectricPiano, .electricPiano2, .electricGrandPiano,
                    .honkyTonkPiano, .clavinet, .harpsichord, .harp]
        case .drums:
            return [.standardDrumKit, .roomDrumKit, .powerDrumKit, .electronicDrumKit,
                    .tr808DrumKit, .jazzDrumKit, .brushDrumKit, .orchestraDrumKit]
        case .synth:
            return [.synthAnalogPad, .synthGlassPad, .synthSupersaw, .synthPluck,
                    .padWarm, .padPolysynth, .padHalo, .padSweep, .padSoundtrack,
                    .padAtmosphere, .padNewAge, .padChoir, .padBowed, .padMetallic,
                    .leadSaw, .leadSquare, .leadFifths, .leadCharang, .leadChiff,
                    .leadCalliope, .leadVoice, .leadBass]
        case .guitar:
            return [.acousticSteelGuitar, .acousticNylonGuitar, .cleanGuitar, .funkGuitar,
                    .jazzGuitar, .twelveStringGuitar, .mutedGuitar, .overdriveGuitar,
                    .distortionGuitar, .ukulele, .harmonicsGuitar]
        case .bass:
            return [.fingerBass, .pickBass, .acousticBass, .fretlessBass, .synthAnalogBass,
                    .synthSubBass, .synthBass, .analogBass, .synthBass2, .slapBass1, .slapBass2]
        case .strings:
            return [.stringEnsemble, .slowStrings, .padOrchestral, .tremoloStrings,
                    .pizzicatoStrings, .synthStrings1, .synthStrings2, .synthStrings3,
                    .choirAahs, .voiceOohs]
        case .brass:
            return [.brassSection, .trumpet, .trombone, .frenchHorn, .mutedTrumpet,
                    .tuba, .synthBrass1, .synthBrass2]
        case .woodwinds:
            return [.flute, .clarinet, .altoSax, .tenorSax, .sopranoSax,
                    .baritoneSax, .oboe, .englishHorn, .bassoon, .piccolo,
                    .recorder, .panFlute, .ocarina]
        case .organ:
            return [.drawbarOrgan, .percussiveOrgan, .rockOrgan, .churchOrgan,
                    .reedOrgan, .accordion, .harmonica, .tangoAccordion]
        case .mallets:
            return [.vibraphone, .marimba, .celesta, .glockenspiel, .musicBox,
                    .xylophone, .kalimba, .tubularBells, .dulcimer]
        case .audio:
            return []
        }
    }

    static func defaultVariant(for instrument: StudioInstrument) -> InstrumentVariant? {
        supportedVariants(for: instrument).first
    }

    /// The sound a producer would reach for first in each style — new tracks
    /// start here instead of a generic GM default (nylon guitar in a rock song,
    /// a lead synth for lo-fi pads…).
    static func defaultVariant(for instrument: StudioInstrument, style: StudioStyle?) -> InstrumentVariant? {
        guard let style else { return defaultVariant(for: instrument) }
        let pick: InstrumentVariant?
        switch (instrument, style) {
        // Keys
        case (.piano, .lofi): pick = .vintageElectricPiano
        case (.piano, .jazz): pick = .acousticPiano
        case (.piano, .funk): pick = .electricPiano
        case (.piano, .ambient): pick = .mellowGrandPiano
        case (.piano, .hiphop): pick = .electricPiano
        case (.piano, .edm): pick = .brightPiano
        case (.piano, .rock): pick = .brightPiano
        // Guitar
        case (.guitar, .rock): pick = .overdriveGuitar
        case (.guitar, .funk): pick = .funkGuitar
        case (.guitar, .jazz): pick = .jazzGuitar
        case (.guitar, .lofi): pick = .cleanGuitar
        case (.guitar, .edm), (.guitar, .hiphop): pick = .cleanGuitar
        case (.guitar, .ambient): pick = .cleanGuitar
        // Bass
        case (.bass, .rock): pick = .pickBass
        case (.bass, .jazz): pick = .acousticBass
        case (.bass, .funk): pick = .slapBass1
        case (.bass, .edm): pick = .synthAnalogBass
        case (.bass, .hiphop): pick = .synthSubBass
        case (.bass, .lofi): pick = .fretlessBass
        case (.bass, .ambient): pick = .fretlessBass
        // Drums
        case (.drums, .rock): pick = .powerDrumKit
        case (.drums, .jazz): pick = .brushDrumKit
        case (.drums, .lofi): pick = .roomDrumKit
        case (.drums, .edm): pick = .electronicDrumKit
        case (.drums, .hiphop): pick = .tr808DrumKit
        case (.drums, .ambient): pick = .roomDrumKit
        // Synth
        case (.synth, .edm): pick = .synthSupersaw
        case (.synth, .ambient): pick = .synthGlassPad
        case (.synth, .lofi): pick = .synthAnalogPad
        case (.synth, .hiphop): pick = .synthAnalogPad
        case (.synth, .pop): pick = .synthGlassPad
        // Strings
        case (.strings, .ambient), (.strings, .lofi): pick = .slowStrings
        case (.strings, .edm): pick = .synthStrings1
        // Organ / brass / mallets
        case (.organ, .rock): pick = .rockOrgan
        case (.organ, .jazz), (.organ, .funk): pick = .percussiveOrgan
        case (.brass, .funk): pick = .brassSection
        case (.brass, .edm): pick = .synthBrass1
        case (.mallets, .lofi): pick = .vibraphone
        case (.mallets, .ambient): pick = .celesta
        case (.woodwinds, .jazz): pick = .tenorSax
        case (.woodwinds, .funk): pick = .altoSax
        default: pick = nil
        }
        if let pick, supportedVariants(for: instrument).contains(pick) {
            return pick
        }
        return defaultVariant(for: instrument)
    }

    static func resolvedVariant(for instrument: StudioInstrument, variant: InstrumentVariant?) -> InstrumentVariant? {
        let supported = supportedVariants(for: instrument)
        if let variant, supported.contains(variant) {
            return variant
        }
        return supported.first
    }

    static func soundFontURL(for instrument: StudioInstrument, variant: InstrumentVariant?) -> URL? {
        guard resolvedVariant(for: instrument, variant: variant) != nil else {
            return nil
        }
        let components = bankFilePath.split(separator: "/").map(String.init)
        let fileName = components.last ?? bankFilePath
        let subfolder = components.dropLast().joined(separator: "/")
        let subdirectory = subfolder.isEmpty ? folderName : "\(folderName)/\(subfolder)"
        let searchPaths = [
            subdirectory,
            folderName,
            nil
        ]
        let url = searchPaths.compactMap { path in
            Bundle.main.url(forResource: fileName, withExtension: "sf2", subdirectory: path)
        }.first
#if DEBUG
        if url == nil {
            let attempts = searchPaths.compactMap { path in
                if let path {
                    return "\(path)/\(fileName).sf2"
                }
                return "\(fileName).sf2"
            }.joined(separator: " | ")
            AppLog.audio.error("Missing SoundFont in bundle. Tried: \(attempts)")
        }
#endif
        return url
    }

    static func usesPercussionBank(for variant: InstrumentVariant?) -> Bool {
        (variant ?? .standardDrumKit).isDrumKit
    }

    struct DrumPitchMap {
        let kick: Int
        let snare: Int
        let hatClosed: Int
        let hatOpen: Int
        let clap: Int
        let rim: Int
        let tomLow: Int
        let tomMid: Int
        let tomHigh: Int
        let ride: Int
        let crash: Int
        let perc: Int
    }

    static func drumPitchMap(for _: InstrumentVariant?) -> DrumPitchMap {
        return DrumPitchMap(
            kick: 36,
            snare: 38,
            hatClosed: 42,
            hatOpen: 46,
            clap: 39,
            rim: 37,
            tomLow: 45,
            tomMid: 47,
            tomHigh: 50,
            ride: 51,
            crash: 49,
            perc: 56
        )
    }
}
