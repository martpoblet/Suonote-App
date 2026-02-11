import Foundation

enum SoundFontManager {
    static let folderName = "SoundFonts"
    private static let arachnoLiteFilePath = "Arachno/Arachno_Lite"

    static func supportedVariants(for instrument: StudioInstrument) -> [InstrumentVariant] {
        switch instrument {
        case .piano:
            return [.acousticPiano, .brightPiano, .electricPiano]
        case .drums:
            return [.standardDrumKit, .electronicDrumKit, .tr808DrumKit]
        case .synth:
            return [.leadBass, .padWarm]
        case .guitar:
            return [.acousticNylonGuitar, .acousticSteelGuitar, .cleanGuitar, .overdriveGuitar]
        case .bass:
            return [.fingerBass, .synthBass]
        case .strings:
            return [.stringEnsemble, .synthStrings1, .synthStrings2]
        case .brass:
            return [.synthBrass1, .synthBrass2]
        case .woodwinds:
            return [.clarinet, .tenorSax, .flute]
        case .organ:
            return [.drawbarOrgan, .churchOrgan]
        case .mallets:
            return [.xylophone, .tubularBells]
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
        let components = arachnoLiteFilePath.split(separator: "/").map(String.init)
        let fileName = components.last ?? arachnoLiteFilePath
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
            print("❌ Missing SoundFont in bundle. Tried: \(attempts)")
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
