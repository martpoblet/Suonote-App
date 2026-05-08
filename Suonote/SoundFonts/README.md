# SoundFonts

The Studio engine probes a list of candidate SoundFonts per instrument family
and uses the first one whose `.sf2` file is bundled. If no dedicated pack is
present the engine falls back to **GeneralUser GS**, which is the primary
SoundFont and ships with every build.

## Primary pack

| Pack            | Path                                                  | License            |
|-----------------|-------------------------------------------------------|--------------------|
| GeneralUser GS  | `SoundFonts/Arachno/GeneralUser-GS.sf2`               | CC-BY 3.0          |

GeneralUser GS covers the full GM map (128 melodic instruments + percussion
bank with multiple kits) at ~30 MB. It is the broad fallback used whenever a
dedicated per-family pack is missing.

## How to upgrade an instrument family

1. Drop a CC-licensed `.sf2` file at the expected path (see table below).
2. The `SoundFonts` directory is included in Xcode as a folder reference, so
   new files are bundled automatically — no project edit required.
3. Add an attribution line to `Suonote/Resources/THIRD_PARTY_NOTICES.md`.
4. Rebuild. The Studio engine picks the new pack on next playback.

## Expected file paths

The registry in `SoundFontManager.swift` looks for these paths first:

| Family   | Expected path                                  |
|----------|------------------------------------------------|
| Piano    | `SoundFonts/Piano/Suonote_Piano.sf2`           |
| Drums    | `SoundFonts/Drums/Suonote_Drums.sf2`           |
| Bass     | `SoundFonts/Bass/Suonote_Bass.sf2`             |
| Strings  | `SoundFonts/Strings/Suonote_Strings.sf2`       |
| Brass    | `SoundFonts/Brass/Suonote_Brass.sf2`           |
| Guitar   | `SoundFonts/Guitar/Suonote_Guitar.sf2`         |
| (any)    | `SoundFonts/Arachno/GeneralUser-GS.sf2`        |

The Suonote_* names are placeholders so the registry stays decoupled from any
particular third-party file. Rename the SoundFont you choose to the expected
file name, or update the `fileName` field in `SoundFontManager.swift`.

## Notes

- The bank/program numbers used per variant come from the General MIDI map in
  `StudioTrack.swift`. Custom packs should map their presets to GM programs so
  the registry can find them with `program = variant.midiProgram`.
- Drum kits should live on the GM percussion bank (MSB = 0x78). The engine
  also probes the melodic bank as a fallback.
- The historical `Arachno_Lite.sf2` may still be present alongside
  `GeneralUser-GS.sf2`. It is no longer referenced by the engine; you can
  remove it to save bundle size or keep it as a backup.
