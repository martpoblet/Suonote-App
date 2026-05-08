import Foundation
import AudioToolbox

/// Describes one SoundFont file the app can load.
/// Packs are tried in priority order (most specific first); the first one whose
/// file is present in the app bundle is used. GeneralUser GS is the broad
/// fallback so the engine never has zero candidates.
struct SoundFontPack: Equatable {
    /// Folder relative to `SoundFonts/` (e.g. "Piano", "Drums", "Arachno").
    let subdirectory: String
    /// File name without extension (e.g. "GeneralUser-GS").
    let fileName: String
    /// User-visible label, used in attribution.
    let displayName: String
    /// License tag (e.g. "CC0", "CC-BY 3.0", "MIT").
    let licenseTag: String

    /// Build a search list of bundle subdirectories to look in. Allows files
    /// to live either at `SoundFonts/<sub>/<file>.sf2` or `SoundFonts/<file>.sf2`.
    var searchSubdirectories: [String?] {
        let base = SoundFontManager.folderName
        if subdirectory.isEmpty { return ["\(base)", nil] }
        return ["\(base)/\(subdirectory)", base, nil]
    }
}

enum SoundFontManager {
    static let folderName = "SoundFonts"

    /// The primary, broadly-compatible SoundFont. CC-BY 3.0, ~30 MB, full GM map
    /// (128 melodic instruments + percussion bank with multiple kits). Drop the
    /// file at `Suonote/SoundFonts/Arachno/GeneralUser-GS.sf2` and Xcode bundles
    /// it automatically thanks to the folder reference.
    static let generalUserGS = SoundFontPack(
        subdirectory: "Arachno",
        fileName: "GeneralUser-GS",
        displayName: "GeneralUser GS",
        licenseTag: "CC-BY 3.0 (S. Christian Collins)"
    )

    // MARK: - Optional dedicated packs (multi-SoundFont registry)
    //
    // Per-family packs are tried before the broad pack. If a dedicated file
    // isn't bundled the engine falls back to GeneralUser GS — no crashes, no
    // breakage when a family-specific upgrade hasn't been added yet.
    //
    // To upgrade an instrument family, drop a CC-licensed `.sf2` at:
    //     Suonote/SoundFonts/<Subdirectory>/<FileName>.sf2
    // Xcode includes the SoundFonts folder by reference so no project edit
    // is required. Update `Resources/THIRD_PARTY_NOTICES.md` with the
    // attribution.

    static let pianoPack = SoundFontPack(
        subdirectory: "Piano",
        fileName: "Suonote_Piano",
        displayName: "Suonote Piano",
        licenseTag: ""
    )

    static let drumsPack = SoundFontPack(
        subdirectory: "Drums",
        fileName: "Suonote_Drums",
        displayName: "Suonote Drums",
        licenseTag: ""
    )

    static let bassPack = SoundFontPack(
        subdirectory: "Bass",
        fileName: "Suonote_Bass",
        displayName: "Suonote Bass",
        licenseTag: ""
    )

    static let stringsPack = SoundFontPack(
        subdirectory: "Strings",
        fileName: "Suonote_Strings",
        displayName: "Suonote Strings",
        licenseTag: ""
    )

    static let brassPack = SoundFontPack(
        subdirectory: "Brass",
        fileName: "Suonote_Brass",
        displayName: "Suonote Brass",
        licenseTag: ""
    )

    static let guitarPack = SoundFontPack(
        subdirectory: "Guitar",
        fileName: "Suonote_Guitar",
        displayName: "Suonote Guitar",
        licenseTag: ""
    )

    /// Ordered list of candidate packs to try for a given instrument. The engine
    /// loads the first one whose file is actually present in the bundle.
    static func candidatePacks(
        for instrument: StudioInstrument,
        variant _: InstrumentVariant?
    ) -> [SoundFontPack] {
        let dedicated: [SoundFontPack]
        switch instrument {
        case .piano:
            dedicated = [pianoPack]
        case .drums:
            dedicated = [drumsPack]
        case .bass:
            dedicated = [bassPack]
        case .strings:
            dedicated = [stringsPack]
        case .brass:
            dedicated = [brassPack]
        case .guitar:
            dedicated = [guitarPack]
        case .synth, .woodwinds, .organ, .mallets, .audio:
            dedicated = []
        }
        return dedicated + [generalUserGS]
    }

    /// Resolve a pack to a bundle URL. Returns nil if no matching file is bundled.
    static func bundleURL(for pack: SoundFontPack) -> URL? {
        for sub in pack.searchSubdirectories {
            if let url = Bundle.main.url(forResource: pack.fileName, withExtension: "sf2", subdirectory: sub) {
                return url
            }
        }
        return nil
    }

    static func supportedVariants(for instrument: StudioInstrument) -> [InstrumentVariant] {
        switch instrument {
        case .piano:
            // GeneralUser GS exposes the full GM piano family — surface them all
            // so users can A/B between Steinway-flavoured grand, EP1, EP2, etc.
            return [.acousticPiano, .brightPiano, .electricPiano, .electricPiano2,
                    .honkyTonkPiano, .harpsichord, .clavinet, .harp]
        case .drums:
            return [.standardDrumKit, .roomDrumKit, .powerDrumKit,
                    .electronicDrumKit, .tr808DrumKit, .jazzDrumKit, .brushDrumKit]
        case .synth:
            return [.leadSquare, .leadSaw, .leadCalliope, .leadVoice,
                    .leadBass, .padNewAge, .padWarm, .padPolysynth,
                    .padChoir, .padBowed, .padHalo, .padSweep]
        case .guitar:
            return [.acousticNylonGuitar, .acousticSteelGuitar, .jazzGuitar,
                    .cleanGuitar, .mutedGuitar, .overdriveGuitar, .distortionGuitar,
                    .harmonicsGuitar]
        case .bass:
            return [.acousticBass, .fingerBass, .pickBass, .fretlessBass,
                    .slapBass1, .synthBass, .synthBass2]
        case .strings:
            return [.stringEnsemble, .slowStrings, .tremoloStrings,
                    .pizzicatoStrings, .synthStrings1, .synthStrings2,
                    .choirAahs, .voiceOohs]
        case .brass:
            return [.trumpet, .trombone, .tuba, .mutedTrumpet, .frenchHorn,
                    .brassSection, .synthBrass1, .synthBrass2]
        case .woodwinds:
            return [.sopranoSax, .altoSax, .tenorSax, .baritoneSax,
                    .oboe, .englishHorn, .clarinet, .flute, .piccolo,
                    .panFlute, .recorder, .ocarina]
        case .organ:
            return [.drawbarOrgan, .percussiveOrgan, .rockOrgan, .churchOrgan,
                    .reedOrgan, .accordion, .harmonica]
        case .mallets:
            return [.celesta, .glockenspiel, .musicBox, .vibraphone,
                    .marimba, .xylophone, .tubularBells, .dulcimer, .kalimba]
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

    /// Legacy single-URL accessor. Prefer `candidatePacks(for:variant:)` + `bundleURL(for:)`
    /// in new code so the engine can probe multiple SoundFonts. Kept for callers
    /// (chord preview, metronome) that just need any working SF2 URL.
    static func soundFontURL(for instrument: StudioInstrument, variant: InstrumentVariant?) -> URL? {
        guard resolvedVariant(for: instrument, variant: variant) != nil else {
            return nil
        }
        for pack in candidatePacks(for: instrument, variant: variant) {
            if let url = bundleURL(for: pack) {
                return url
            }
        }
        return nil
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
