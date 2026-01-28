import Foundation

enum SoundFontManager {
    static let folderName = "SoundFonts"

    private static let variantFileMap: [InstrumentVariant: String] = [
        // Piano
        .acousticPiano: "Piano/Upright_Piano_KW_Small",
        .electricPiano: "Piano/FM_Synth_Piano_1",
        .electricPiano2: "Piano/FM_Synth_Piano_2",

        // Drums
        .standardDrumKit: "Drums/AcousticKitM.B.2",
        .electronicDrumKit: "Drums/Synth_Percussion",
        .roomDrumKit: "Drums/AcousticKitM.B.2",

        // Synth
        .leadBass: "Synth/Synth_Bass_Lead",

        // Guitar
        .acousticNylonGuitar: "Guitar/Spanish_Classical",
        .cleanGuitar: "Guitar/Clean_Electric_Guitar_1",

        // Bass
        .fingerBass: "Bass/Electric_Bass_Finger",

        // Strings
        .synthStrings1: "Strings/Synth_Strings_1",
        .synthStrings2: "Strings/Synth_Strings_2",

        // Brass
        .synthBrass1: "Brass/Synth_Brass_1",
        .synthBrass2: "Brass/Synth_Brass_2",

        // Woodwinds
        .clarinet: "Woodwinds/Clarinet",
        .tenorSax: "Woodwinds/Tenor_Sax",
        .ocarina: "Woodwinds/Ocarina",

        // Organ
        .churchOrgan: "Organ/Pipe_Organ",

        // Mallets
        .xylophone: "Mallets/Xylophone",
        .tubularBells: "Mallets/Tubular_Bells",
        .kalimba: "Mallets/Kalimba"
    ]

    static func supportedVariants(for instrument: StudioInstrument) -> [InstrumentVariant] {
        switch instrument {
        case .piano:
            return [.acousticPiano, .electricPiano, .electricPiano2]
        case .drums:
            return [.standardDrumKit, .electronicDrumKit, .roomDrumKit]
        case .synth:
            return [.leadBass]
        case .guitar:
            return [.acousticNylonGuitar, .cleanGuitar]
        case .bass:
            return [.fingerBass]
        case .strings:
            return [.synthStrings1, .synthStrings2]
        case .brass:
            return [.synthBrass1, .synthBrass2]
        case .woodwinds:
            return [.clarinet, .tenorSax, .ocarina]
        case .organ:
            return [.churchOrgan]
        case .mallets:
            return [.xylophone, .tubularBells, .kalimba]
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
        guard let resolved = resolvedVariant(for: instrument, variant: variant),
              let filePath = variantFileMap[resolved] else {
            return nil
        }
        let components = filePath.split(separator: "/").map(String.init)
        let fileName = components.last ?? filePath
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
                path == nil ? "\(fileName).sf2" : "\(path)/\(fileName).sf2"
            }.joined(separator: " | ")
            print("❌ Missing SoundFont in bundle. Tried: \(attempts)")
        }
#endif
        return url
    }

    static func usesPercussionBank(for variant: InstrumentVariant?) -> Bool {
        switch variant {
        case .standardDrumKit, .roomDrumKit:
            return true
        default:
            return false
        }
    }

    struct DrumPitchMap {
        let kick: Int
        let snare: Int
        let hatClosed: Int
        let hatOpen: Int
        let clap: Int
    }

    static func drumPitchMap(for variant: InstrumentVariant?) -> DrumPitchMap {
        if usesPercussionBank(for: variant) {
            return DrumPitchMap(kick: 36, snare: 38, hatClosed: 42, hatOpen: 46, clap: 39)
        }
        if variant == .standardDrumKit || variant == .roomDrumKit {
            return DrumPitchMap(kick: 36, snare: 38, hatClosed: 42, hatOpen: 46, clap: 39)
        }
        switch variant {
        case .roomDrumKit:
            return DrumPitchMap(kick: 60, snare: 62, hatClosed: 65, hatOpen: 67, clap: 69)
        case .electronicDrumKit:
            return DrumPitchMap(kick: 60, snare: 62, hatClosed: 64, hatOpen: 67, clap: 69)
        default:
            return DrumPitchMap(kick: 60, snare: 62, hatClosed: 64, hatOpen: 67, clap: 69)
        }
    }
}
