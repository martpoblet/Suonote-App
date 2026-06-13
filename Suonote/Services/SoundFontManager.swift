import os
import Foundation

enum SoundFontManager {
    static let folderName = "SoundFonts"
    /// MS Basic (MuseScore General) — MIT-licensed full-GM bank, so every
    /// variant below maps to a real preset.
    private static let bankFilePath = "MuseScore/MS_Basic"

    static func supportedVariants(for instrument: StudioInstrument) -> [InstrumentVariant] {
        // First entry is the default for new tracks (and the fallback for
        // persisted tracks whose stored variant is no longer supported).
        switch instrument {
        case .piano:
            return [.acousticPiano, .brightPiano, .electricPiano, .electricPiano2,
                    .honkyTonkPiano, .harpsichord, .clavinet, .harp]
        case .drums:
            return [.standardDrumKit, .roomDrumKit, .powerDrumKit, .electronicDrumKit,
                    .tr808DrumKit, .jazzDrumKit, .brushDrumKit, .orchestraDrumKit]
        case .synth:
            return [.leadBass, .padWarm, .leadSquare, .leadSaw, .leadCalliope,
                    .leadChiff, .leadCharang, .leadVoice, .leadFifths,
                    .padNewAge, .padPolysynth, .padChoir, .padBowed,
                    .padMetallic, .padHalo, .padSweep]
        case .guitar:
            return [.acousticNylonGuitar, .acousticSteelGuitar, .cleanGuitar,
                    .jazzGuitar, .mutedGuitar, .overdriveGuitar, .distortionGuitar,
                    .harmonicsGuitar]
        case .bass:
            return [.fingerBass, .synthBass, .acousticBass, .pickBass,
                    .fretlessBass, .slapBass1, .slapBass2, .synthBass2]
        case .strings:
            return [.stringEnsemble, .slowStrings, .tremoloStrings, .pizzicatoStrings,
                    .synthStrings1, .synthStrings2, .choirAahs, .voiceOohs]
        case .brass:
            return [.brassSection, .trumpet, .trombone, .tuba, .mutedTrumpet,
                    .frenchHorn, .synthBrass1, .synthBrass2]
        case .woodwinds:
            return [.flute, .clarinet, .tenorSax, .sopranoSax, .altoSax,
                    .baritoneSax, .oboe, .englishHorn, .bassoon, .piccolo,
                    .recorder, .panFlute, .ocarina]
        case .organ:
            return [.drawbarOrgan, .percussiveOrgan, .rockOrgan, .churchOrgan,
                    .reedOrgan, .accordion, .harmonica, .tangoAccordion]
        case .mallets:
            return [.xylophone, .marimba, .vibraphone, .glockenspiel, .celesta,
                    .musicBox, .tubularBells, .dulcimer, .kalimba]
        case .audio:
            return []
        }
    }

    static func defaultVariant(for instrument: StudioInstrument) -> InstrumentVariant? {
        supportedVariants(for: instrument).first
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
