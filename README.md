# Suonote

Suonote is a native iOS songwriting workspace designed to capture and develop musical ideas from the first spark to a shareable draft.

Instead of splitting your process across Notes, Voice Memos, and multiple temporary tools, Suonote keeps composition, lyrics, recordings, arrangement, and quick production in one project-centered workflow.

## Product Vision

Song ideas are usually fragmented:
- a lyric line in a notes app,
- a melody memo in a recorder,
- chords remembered mentally,
- arrangement decisions postponed,
- production experimentation delayed until a DAW session.

Suonote solves this by turning each idea into a structured project where you can:
- define key, mode, tempo, and time signature,
- build song sections and chord timelines,
- write lyrics per section,
- record takes and link them to structure,
- generate and edit studio-style instrument tracks,
- export your work into standard formats.

## Core Experience

A Suonote project is the central unit. Each project includes:
- creative metadata (title, tags, status),
- musical context (key root, key mode, BPM, time signature),
- arrangement structure (ordered section instances),
- harmonic content (chord events across bars/beats),
- lyrical content (section lyrics and notes),
- recorded audio takes,
- optional Studio-generated and manual tracks.

This allows users to move from idea capture to compositional development without context-switching.

## Main Features

## 1. Project Library and Idea Management
- Project list sorted by most recently updated.
- Search across:
  - project title,
  - tags,
  - lyrics content.
- Filters by:
  - project status,
  - tags.
- Project statuses:
  - `Idea`,
  - `In Progress`,
  - `Polished`,
  - `Finished`,
  - `Archived`.
- Swipe actions on project cards:
  - delete,
  - archive/unarchive,
  - clone.
- Quick creation flow for new ideas with:
  - title,
  - status,
  - tags,
  - BPM presets and tempo preview.
- Deep linking support:
  - open a project with `suonote://project/<uuid>[/compose|studio|lyrics|record]`,
  - `suonote://new` creates a song, `suonote://record` records on the latest song.

## 2. Composition Workspace (Compose Tab)
- Section-based songwriting model (verse, chorus, bridge, custom sections).
- Arrangement timeline with ordered section cards.
- Drag-and-drop section reorder in timeline.
- View modes:
  - all sections expanded,
  - focus on a single section.
- Per-section editing features:
  - section name,
  - color,
  - number of bars,
  - duplicate section,
  - delete section from arrangement.
- Per-section musical overrides:
  - key root override,
  - key mode override,
  - BPM override.
- Chord grid editor by bars and beats.
- Chord events support:
  - bar index,
  - beat offset,
  - duration in beats,
  - rests,
  - root,
  - quality,
  - optional slash bass,
  - optional extensions.
- Chord drag-and-drop and slot-level operations.
- Bar-level operations and bar reordering in section grids.
- Chord preview playback while selecting harmonies.

## 3. Harmonic Intelligence and Music Theory Tools
- Diatonic chord generation for current key/mode.
- Context-aware next-chord suggestions based on progression history.
- Borrowed/modal/secondary suggestions in contextual engine.
- Popular progression templates (major/minor families).
- Progression analysis with:
  - diatonic vs non-diatonic count,
  - roman numeral sequence,
  - diatonic percentage.
- Chord quality system includes triads, sevenths, extensions, suspensions, altered colors.
- Voice-leading helper utilities for smoother voicings in generation logic.
- Circle of Fifths view.
- Chord diagram view (instrument-oriented visualization).

### Supported Key Modes
- Major
- Minor
- Dorian
- Phrygian
- Lydian
- Mixolydian
- Aeolian
- Locrian
- Harmonic Minor
- Melodic Minor
- Pentatonic Major
- Pentatonic Minor
- Blues

## 4. Lyrics Workspace (Lyrics Tab)
- Lyrics are organized per unique section.
- Section cards display:
  - section name,
  - usage count in arrangement,
  - lyrics preview.
- Full-screen immersive lyrics editor with:
  - focused writing environment,
  - automatic section context,
  - character count.
- Fast navigation between section lyric blocks.

## 5. Recording Workspace (Record Tab)
- Built-in audio capture using AVFoundation.
- Recording setup includes:
  - count-in bars,
  - metronome click,
  - recording type classification.
- Live input level metering during recording.
- Recording types include categories such as:
  - voice,
  - guitar,
  - piano,
  - melody idea,
  - beat,
  - sketch,
  - other.
- Take management:
  - playback,
  - detail editing,
  - delete,
  - favorites,
  - naming.
- Link recordings to a specific section for arrangement context.
- Recording filters and sort options:
  - by type,
  - linked only,
  - date,
  - name,
  - duration.
- Recording-level effect settings:
  - reverb,
  - delay,
  - EQ,
  - compression.

## 6. Studio Workspace (Studio Tab)
- Project-integrated production layer for fast arrangement prototyping.
- Style-driven generation options:
  - Pop,
  - Rock,
  - Lo-Fi,
  - EDM,
  - Jazz,
  - Hip-Hop,
  - Funk,
  - Ambient.
- Track types:
  - instrument MIDI tracks,
  - drum tracks,
  - imported project audio tracks.
- Instrument families available in Studio:
  - Piano,
  - Synth,
  - Guitar,
  - Bass,
  - Strings,
  - Brass,
  - Woodwinds,
  - Organ,
  - Mallets,
  - Drums,
  - Audio.
- Instrument variant support via SoundFont mappings.
- Track operations:
  - add,
  - delete,
  - reorder,
  - open full editor.
- Piano-roll note editor features:
  - tap to add,
  - delete notes,
  - duration editing,
  - velocity controls,
  - octave shift.
- Drum editor features:
  - step sequencing,
  - lane-based editing,
  - velocity patterns.
- Transport and playback:
  - play/pause/stop,
  - timeline seek,
  - metronome toggle,
  - optional loop/cycle controls.
- Mix controls per track:
  - volume,
  - pan,
  - mute,
  - solo.
- FX controls per track:
  - reverb presets and wet mix,
  - synced/free delay,
  - EQ bands,
  - compressor toggle.
- Regeneration controls for generated material:
  - intensity,
  - complexity,
  - naturalness,
  - arpeggiation options.
- Sync-aware regeneration when harmony/structure changes.

## 7. Export and Sharing
- MIDI export with multi-track structure including:
  - metadata/tempo/signature,
  - chord track,
  - bass track,
  - drum track.
- Text export options:
  - chord chart,
  - full project report.
- PDF export:
  - printable chord chart by section.
- Native iOS share sheet integration for exported assets.
- Portable project document support:
  - `.suonote` file type,
  - JSON-backed exchange format,
  - ready for cross-device/project handoff.

## 8. Sync and Apple Ecosystem Integration
- Local-first persistence with SwiftData.
- Cloud-backed sync with CloudKit private database (`iCloud.Suonote`).
  - Song structure, chords, lyrics and recording *metadata* sync across devices.
  - Recorded audio files are **not** synced: they stay in the Documents folder of the device where they were recorded, and other devices show "Audio not available on this device" for those takes.
- Migration fallback logic for schema/store changes.
- App Group support (`group.MartinCode.Suonote.shared`) for widget data sharing.
- Home Screen widget (`SuonoteWidget`) with deep links into a song's tabs.
- App Intents / Shortcuts integration:
  - create a new project from Siri/Shortcuts.

## 9. Onboarding and UX Layer
- First-launch onboarding flow that introduces:
  - project structuring,
  - chord intelligence,
  - record + studio workflow.
- The last onboarding page offers "Listen to an example song", which adds the demo song to the library.
- Splash transition to main project list.
- Design system with consistent typography, spacing, and component styles.
- Haptic feedback integration in key interactions.
- Light, dark and system appearance, plus an in-app language override (English / Spanish).
- Accessibility work in progress: VoiceOver labels and custom actions on the editors, Reduce Motion support, and AA-contrast text colors.

## Domain Model (Data Architecture)

Primary entities:
- `Project`
  - global musical context,
  - arrangement collection,
  - recordings,
  - studio state snapshots.
- `SectionTemplate`
  - reusable section content,
  - lyrics,
  - chord events,
  - per-section musical overrides.
- `ArrangementItem`
  - ordered references to section templates,
  - optional label overrides.
- `ChordEvent`
  - time-positioned harmonic event (or rest).
- `Recording`
  - audio take metadata + linked section + effect settings.
- `StudioTrack`
  - generated or audio-backed production track configuration.

Supporting enums/models cover:
- key modes,
- chord qualities/categories,
- recording types,
- studio styles,
- instruments and variants,
- drum presets,
- time signature presets.

## Technical Stack
- `SwiftUI` for the entire app interface.
- `SwiftData` for model persistence and CloudKit-backed storage.
- `AVFoundation` for recording/playback/audio engine composition.
- `AudioToolbox` integrations for metronome and low-level audio utilities.
- `CloudKit` for sync.
- `WidgetKit` and `App Intents` for the widget and Shortcuts.
- SoundFont-based playback using `MS_Basic.sf2` (MuseScore General, MIT license).
- Swift 5 language mode with default `MainActor` isolation; iOS 26 (Liquid Glass) deployment target.

## Repository Structure

```text
Suonote-App/
├── README.md
├── Info.plist
├── Suonote.xcodeproj
├── Suonote/                      # App target
│   ├── SuonoteApp.swift          # Entry point, ModelContainer + CloudKit setup
│   ├── Models/                   # SwiftData models (Project, SectionTemplate, ChordEvent, Recording, StudioTrack…)
│   ├── Views/                    # SwiftUI screens: Compose/, Lyrics/, Record/, Studio/, Library/, Components/
│   ├── ViewModels/
│   ├── Services/                 # Audio recording, Studio generation/playback, sync, export, shortcuts
│   ├── Utils/                    # DesignSystem, music theory, settings, haptics, helpers
│   ├── Resources/                # Fonts (Erode, Manrope), logo, THIRD_PARTY_NOTICES.md
│   ├── SoundFonts/MuseScore/     # MS_Basic.sf2 goes here (git-ignored, see below)
│   ├── Assets.xcassets
│   └── *.xcstrings               # Localizable, InfoPlist, AppShortcuts string catalogs
├── SuonoteTests/                 # XCTest unit tests
├── SuonoteWidget/                # Widget extension
├── SuonoteWidgetExtension.entitlements
└── docs/                         # Design notes, audits and App Store assets
```

### Documentation (`docs/`)
- `DESIGN_LANGUAGE.md` — visual language: paper surfaces, ink, teal accent, typography.
- `LIQUID_GLASS_REDESIGN.md` — how Liquid Glass (iOS 26) is used for the floating control layer.
- `SOUND_ENGINE.md` — Studio sound engine architecture.
- `SOUND_UPGRADE_RESEARCH.md` — research behind the SoundFont/sound upgrade.
- `AUDIT_2026-06.md` — June 2026 technical audit (historical; see `AUDIT_2026-11.md` for the current state).
- `app-store/` — App Store screenshots and `RELEASE_2.1.0.md` (release notes, store copy, App Review notes, pre-archive checklist).

## Build and Run

Requirements: a recent Xcode that supports the iOS 26 SDK (the project's deployment target is **iOS 26.0**).

1. Add the SoundFont (see below). The app builds without it, but Studio and chord-preview instrument sounds will be missing (a debug log reports the missing bank).
2. Open `Suonote.xcodeproj` in Xcode.
3. Select the `Suonote` scheme and an iOS 26 simulator or device.
4. Run (`Cmd+R`).
5. For real iCloud sync testing, use a device or simulator signed in to iCloud and make sure the iCloud (CloudKit, container `iCloud.Suonote`) and App Group (`group.MartinCode.Suonote.shared`) capabilities are enabled for your team in Signing & Capabilities.

### SoundFont (`MS_Basic.sf2`)

`MS_Basic.sf2` (MS Basic / MuseScore General, MIT license) is too large for GitHub, so it is git-ignored (`Suonote/SoundFonts/**/*.sf2`) and not in the repository. To build a working app, download it from the MuseScore General upstream
(`https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/`) and save it as
`Suonote/SoundFonts/MuseScore/MS_Basic.sf2`. See `Suonote/SoundFonts/MuseScore/README.md` for details.

## Tests

Unit tests live in `SuonoteTests/` (music theory, chord suggestions, MIDI export, Studio generator and sound, recording and structure, lyrics syllable counting).

- In Xcode: select the `Suonote` scheme and press `Cmd+U`.
- From the command line (adjust the simulator name to one you have installed):

```bash
xcodebuild test -project Suonote.xcodeproj -scheme Suonote \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Configuration Notes

- Third-party notices (fonts, SoundFont license):
  - `Suonote/Resources/THIRD_PARTY_NOTICES.md`
- SoundFont credits:
  - `Suonote/SoundFonts/MuseScore/README.md`

## Why Suonote

Suonote is built around one practical promise:
- capture the idea immediately,
- keep all musical context attached,
- iterate harmonically and structurally,
- preserve audio references,
- and leave each session with a clearer, more producible song draft.

It is a single-place songwriting system for creators who want speed at idea time and structure at composition time.
