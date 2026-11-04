# Suonote - GitHub Copilot Instructions

## Build & Run

This is an iOS app built with Xcode (SwiftUI + SwiftData, Swift 5 language mode, default actor isolation = `MainActor`).

- **Open**: `Suonote.xcodeproj` in a recent Xcode that supports the iOS 26 SDK
- **Build**: `Cmd+B` or Product → Build
- **Run**: `Cmd+R` on an iOS 26 simulator or device (deployment target: iOS 26.0)
- **Scheme**: `Suonote` (app); the widget extension is `SuonoteWidgetExtension` and the unit-test bundle is `SuonoteTests`
- **SoundFont**: `Suonote/SoundFonts/MuseScore/MS_Basic.sf2` is git-ignored (too large for GitHub). Download it as described in `Suonote/SoundFonts/MuseScore/README.md`; without it Studio sounds are missing (the debug log reports "Missing SoundFont in bundle").

### Tests

Unit tests live in `SuonoteTests/` (XCTest, `@testable import Suonote`): music theory and chord suggestions, MIDI export, Studio generator and sound, recording and structure, lyrics syllable counting.

- In Xcode: `Cmd+U` with the `Suonote` scheme.
- CLI: `xcodebuild test -project Suonote.xcodeproj -scheme Suonote -destination 'platform=iOS Simulator,name=<an installed iPhone simulator>'`
- Because of default `MainActor` isolation, test classes/methods that touch app types usually need `@MainActor`.

## Architecture Overview

### Data Flow
- **SwiftData** for persistence with CloudKit sync (private database, container `iCloud.Suonote`); the container is built in `SuonoteApp.swift` with local-store fallbacks
- **@Model** classes for data models (`Project`, `SectionTemplate`, `ArrangementItem`, `ChordEvent`, `Recording`, `StudioTrack`, `StudioNote`)
- Relationship properties are stored as optional arrays/references named `...Store` (CloudKit requires optional or defaulted attributes) with computed non-optional accessors. The models do not use the `@Relationship` macro; SwiftData infers the relationships, and the setters keep the inverse reference in sync.
- Observation is mixed: `AppSettings` and `ComposeEditor` use `@Observable`; the audio/Studio services (`StudioPlaybackEngine`, `AudioRecordingManager`, `CloudSyncMonitor`, `RecordTakePlayer`) are `ObservableObject` injected with `@EnvironmentObject` / `@ObservedObject`.
- Sync scope: song structure, chords, lyrics and recording *metadata* sync via iCloud. Recorded audio files stay in the Documents directory of the device that recorded them, so views must handle a `Recording` whose file is missing (`FileManagerUtils.audioFileExists(fileName:)`, `AudioUnavailableLabel`).

### Tab-Based Navigation
`ProjectDetailView` uses a native `TabView` (iOS 26 `Tab` API) with four tabs:
1. **Compose** (`Views/Compose/ComposeTabView.swift`) - arrangement editor with chord grid
2. **Studio** (`Views/Studio/StudioTabView.swift`) - multi-track production with MIDI playback
3. **Lyrics** (`Views/LyricsTabView.swift`) - section-based lyrics editing
4. **Record** (`Views/RecordingsTabView.swift`) - takes, recording, effects

Playback transport floats above the tab bar (`Views/Components/MiniTransportView.swift`); full-screen editors carry a matching `StudioFloatingTransport`.

### Key Architectural Patterns

**Arrangement System**:
- Songs are structured as reusable `SectionTemplate` instances (Verse, Chorus, etc.)
- `ArrangementItem` array defines playback order (e.g., [Intro, Verse, Chorus, Verse, Chorus])
- Each section has `bars` (measures) containing `chordEvents` positioned by `barIndex` and `beatOffset`

**Chord System**:
- `ChordEvent` stores position (`barIndex`, `beatOffset`), duration, and chord data (root, quality, extensions, slash bass)
- Beat positions are decimal: 0.0 = beat 1, 0.5 = half beat, 3.5 = end of measure
- Durations: 0.5, 1.0, 2.0, 4.0 beats
- Smart suggestions via `ChordSuggestionEngine` based on key and context
- Compose edits go through `ComposeEditor.perform(_:toast:_:)`, which saves, records undo/redo history and shows the toast

**Studio/Playback**:
- `StudioGenerator` (with `StudioArranger`, `StudioBassComposer`) converts chord arrangements into MIDI tracks
- `StudioSync` detects when harmony/structure changed and keeps generated parts in sync
- `StudioPlaybackEngine` / `StudioMixGraph` manage multi-track playback with AVAudioEngine; `StudioOfflineRenderer` bounces the mix
- Sound comes from the MuseScore `MS_Basic.sf2` SoundFont plus custom AudioUnits (`SuonoteSynthUnit`, `SuonoteBassAmpUnit`); see `docs/SOUND_ENGINE.md`
- Tracks have instrument assignment, volume, pan, effects

**Audio Recording**:
- `AudioRecordingManager` (+ `TakeCapture`, `AudioSessionManager`, `MetronomeClickPlayer`) handles capture and the click/count-in
- Takes play through `RecordTakePlayer`; effects through `AudioEffectsProcessor`
- Recordings are stored in the Documents directory and linked to sections via `linkedSectionId`

**Export & exchange**: chord chart PDF/text, lyric sheet, MIDI, Studio mix, takes, and the `.suonote` JSON project file (`SuonoteDocument`, `CollaborationExchange`). Widget data is shared through the App Group `group.MartinCode.Suonote.shared`.

## Key Conventions

### File Organization
- Large view files use `// MARK:` sections for organization
- Supporting views are often defined in the same file below the main view
- Reusable components in `Views/Components/`, feature folders under `Views/` (Compose, Lyrics, Record, Studio, Library)

### Design System
- All colors, typography, spacing via `DesignSystem` (`Utils/DesignSystem.swift`); see `docs/DESIGN_LANGUAGE.md`
- "Ink on paper, with a teal pulse": warm paper surfaces, near-black ink, hairline rules. Brand teal `#00CCBE` (`Colors.brand`) is for marks/decoration; fills use `Colors.primary` (a deeper teal in light mode so `onPrimary` text passes AA); the second voice is terracotta (`Colors.accent`)
- Text tokens (`textPrimary/Secondary/Tertiary/Muted`) are tuned to >= 4.5:1 contrast on paper in both modes - keep that when changing them
- Typography: Erode (serif, anything that carries meaning) and Manrope (working UI), registered in `FontExtensions.swift` (`AppFonts.checkFonts()` helps in debug)
- Section colors: 8 pastel colors (Sage, Ocean, Sky, Moss, Sand, Coral, Berry, Lavender); the hex values are persisted, keep them stable
- Liquid Glass (`.glassEffect`, `.glass` button styles; helpers in `Utils/GlassComponents.swift`) is reserved for the floating control layer; content surfaces stay solid
- Appearance is System/Light/Dark (`AppSettings.theme`, applied with `preferredColorScheme`); the app does **not** force light mode

### Accessibility
- Interactive controls should have a >= 44 x 44 pt hit area (`.frame(minWidth: 44, minHeight: 44)` + `.contentShape(...)`)
- Gesture-only editors (piano roll, drum grid) expose VoiceOver actions that call the same model mutations as the gestures
- Honor `accessibilityReduceMotion`; give every icon-only button an `.accessibilityLabel`

### Localization
- User-facing strings use `String(localized:)` / `LocalizedStringKey`; translations (English source, Spanish) live in `Suonote/Localizable.xcstrings` (plus `InfoPlist.xcstrings`, `AppShortcuts.xcstrings`)
- Persisted values (raw enum values, section colors) must never be localized; use a separate display-name property

### State Management
- Use `@Bindable` for `@Model` objects passed to views
- Use `@State` for view-local state
- Use `@Environment(\.modelContext)` for SwiftData operations
- Prefer `@Observable` for new model-like classes; the existing audio services are `ObservableObject`

### Music Theory
- `MusicTheory` enum (in `ChordSuggestionEngine.swift`) provides chromatic scale, intervals, chord qualities
- `ChordSuggestionEngine` for diatonic chords and smart progressions
- `MusicTheoryUtils.swift` centralizes music constants and helpers (roman numerals, transposition, scales)

### UI Patterns
- Native `TabView` / `NavigationStack`; native `.swipeActions` in lists (`Compose/SwipeActionRow.swift` is a legacy custom component, currently unused)
- Sheet presentations use `.sheet(isPresented:)` with `@State` boolean flags; shared scaffolding in `Views/StudioModalStyle.swift` and `Library/LibraryComponents.swift`
- Animations via the `DesignSystem.Animations` springs/eases

### Persistence
- SwiftData autosaves, but flows that must not lose data call `try? modelContext.save()` or `modelContext.saveLogged(_:)` (`Utils/SaveHelper.swift`) explicitly
- Update `project.updatedAt = Date()` when modifying projects
- iCloud sync is configured via `ModelConfiguration` with `cloudKitDatabase: .private(...)`; any schema change must stay CloudKit-compatible (optional or defaulted properties, no unique constraints)

## Current Features

- Project library with filters, search, tags, status and a demo song ("Listen to an example song" on the last onboarding page / Settings)
- Chord grid editor with smart suggestions, progression library and undo/redo
- Section-based arrangement system
- Lyrics editor synchronized with sections (syllable counts for English and Spanish, rhyme scheme)
- Audio recording with click track and count-in, takes with effects (reverb, delay, EQ, compression)
- Multi-track studio with generated parts, piano-roll and drum step editors, mixer and FX
- Export: PDF/text chord charts, lyric sheet, MIDI, mix bounce, takes, `.suonote` file
- iCloud sync via CloudKit (audio files excluded), home-screen widget, App Shortcuts, English/Spanish localization

## Common Patterns

### Adding a New View
```swift
struct MyNewView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // Use DesignSystem for styling
        Text("Hello")
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }
}
```

### Modifying SwiftData Models
```swift
// Update a project
project.title = "New Title"
project.updatedAt = Date()
modelContext.saveLogged("rename project")

// Add a section
let section = SectionTemplate(...)
project.sectionTemplates.append(section)
```

## Important Notes

- Navigation/tab bar appearance is customized in `SuonoteApp.swift`
- Font registration happens in `FontExtensions.swift`
- `MS_Basic.sf2` must be at `Suonote/SoundFonts/MuseScore/MS_Basic.sf2` (git-ignored); license notice in `Suonote/Resources/THIRD_PARTY_NOTICES.md`
- CloudKit container ID: `iCloud.Suonote`; App Group: `group.MartinCode.Suonote.shared`
- Do not edit `*.xcstrings` by hand without keeping both English and Spanish entries in sync
