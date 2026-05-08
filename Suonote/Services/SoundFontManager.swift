import Foundation
import AudioToolbox

/// Describes one SoundFont file the app can load.
/// Packs are tried in priority order (most specific first); the first one whose
/// file is present in the app bundle is used. The Arachno Lite pack is always
/// available as a fallback so the engine never has zero candidates.
struct SoundFontPack: Equatable {
    /// Folder relative to `SoundFonts/` (e.g. "Piano", "Drums", "Arachno").
    let subdirectory: String
    /// File name without extension (e.g. "Salamander_Grand_V3").
    let fileName: String
    /// User-visible label, used in attribution.
    let displayName: String
    /// License tag (e.g. "CC0", "CC-BY 3.0", "MIT"). Empty for bundled-by-author packs.
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

    /// The always-bundled fallback. Ships with every build and covers every GM program.
    static let arachnoLite = SoundFontPack(
        subdirectory: "Arachno",
        fileName: "Arachno_Lite",
        displayName: "Arachno Lite",
        licenseTag: "Used with permission (Arachnosoft)"
    )

    // MARK: - Optional dedicated packs (multi-SoundFont registry)
    //
    // These describe the file names the engine will look for FIRST when loading a
    // given instrument family. If the file isn't bundled the engine falls back to
    // Arachno Lite, so the registry is safe to populate before the asset exists.
    //
    // To upgrade an instrument family, drop a CC-licensed `.sf2` at:
    //     Suonote/SoundFonts/<Subdirectory>/<FileName>.sf2
    // Xcode includes the SoundFonts folder by reference so no project edit is required.
    // Update `Resources/THIRD_PARTY_NOTICES.md` with the attribution.

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
        return dedicated + [arachnoLite]
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
            return [.flute, .clarinet, .tenorSax]
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
