# SoundFonts

The Studio engine probes a list of candidate SoundFonts per instrument family
and uses the first one whose `.sf2` file is bundled. If no dedicated pack is
present the engine falls back to `Arachno/Arachno_Lite.sf2`, which ships with
every build.

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
| (any)    | `SoundFonts/Arachno/Arachno_Lite.sf2`          |

The Suonote_* names are placeholders so the registry stays decoupled from any
particular third-party file. Rename the SoundFont you choose to the expected
file name, or update the `fileName` field in `SoundFontManager.swift`.

## Recommended free SoundFonts (as of 2026)

These are not bundled; they are starting points if you want better samples.
**Always confirm the license** before bundling.

- **Piano** — Salamander Grand V3 (CC-BY 3.0). Drop as `SoundFonts/Piano/Suonote_Piano.sf2`.
- **Drums** — *99 Sounds* drum SoundFonts (CC-BY) or MS Drumkit (CC0).
- **Strings/Brass** — VSCO 2 Lite SoundFont (CC0).
- **Bass** — HD.F. Bass (free, check author).

## Notes

- The bank/program numbers used per variant come from the General MIDI map in
  `StudioTrack.swift`. Custom packs should map their presets to GM programs so
  the registry can find them with `program = variant.midiProgram`.
- Drum kits should live on the GM percussion bank (MSB = 0x78). The engine
  also probes the melodic bank as a fallback.
