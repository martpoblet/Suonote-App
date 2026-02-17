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
  - open a project with `suonote://project/<uuid>`.

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
- Migration fallback logic for schema/store changes.
- App Group support (`group.MartinCode.Suonote.shared`) for widget data sharing.
- App Intents / Shortcuts integration:
  - create a new project from Siri/Shortcuts.

## 9. Onboarding and UX Layer
- First-launch onboarding flow that introduces:
  - project structuring,
  - chord intelligence,
  - record + studio workflow.
- Splash transition to main project list.
- Design system with consistent typography, spacing, and component styles.
- Haptic feedback integration in key interactions.
- Accessibility-oriented utility layer (helpers and adaptive layout support).

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
- SoundFont-based playback using `Arachno_Lite.sf2`.

## Repository Structure

```text
/Users/martinpoblet/Documents/Xcode/Suonote/
├── README.md
├── ARCHITECTURE.md
├── ADVANCED_FEATURES.md
├── CHANGELOG.md
├── Suonote.xcodeproj
├── Suonote/
│   ├── SuonoteApp.swift
│   ├── Models/
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   ├── Utils/
│   ├── Resources/
│   └── SoundFonts/
├── SuonoteTests/
└── SuonoteWidget/
```

## Build and Run

1. Open `/Users/martinpoblet/Documents/Xcode/Suonote/Suonote.xcodeproj` in Xcode 15+.
2. Select the `Suonote` target.
3. Run on iOS 17+ simulator or device.
4. For real iCloud sync testing, ensure iCloud + CloudKit capabilities are enabled in Signing & Capabilities.

## Configuration Notes

- iCloud/CloudKit setup guide:
  - `/Users/martinpoblet/Documents/Xcode/Suonote/Suonote/ICLOUD_SETUP_GUIDE.md`
- SoundFont setup and licensing guidance:
  - `/Users/martinpoblet/Documents/Xcode/Suonote/Suonote/SOUNDFONTS_FREEPATS_SETUP.md`
- Third-party notices:
  - `/Users/martinpoblet/Documents/Xcode/Suonote/Suonote/Resources/THIRD_PARTY_NOTICES.md`

## Why Suonote

Suonote is built around one practical promise:
- capture the idea immediately,
- keep all musical context attached,
- iterate harmonically and structurally,
- preserve audio references,
- and leave each session with a clearer, more producible song draft.

It is a single-place songwriting system for creators who want speed at idea time and structure at composition time.
