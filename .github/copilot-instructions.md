# Suonote - GitHub Copilot Instructions

## Build & Run

This is an iOS app built with Xcode.

- **Open**: `Suonote.xcodeproj` in Xcode 15+
- **Build**: `⌘B` or Product → Build
- **Run**: `⌘R` on iOS 17+ simulator or device
- **Build scheme**: `Suonote` (single target)

No tests are currently implemented.

## Architecture Overview

### Data Flow
- **SwiftData** for persistence with CloudKit sync enabled
- **@Model** classes for data models (Project, SectionTemplate, ChordEvent, Recording, StudioTrack)
- **@Observable** for service classes (AudioRecordingManager, StudioPlaybackEngine)
- Models use store properties (e.g., `sectionTemplatesStore`) with computed accessors for relationships

### Tab-Based Navigation
The app has a 3-tab structure in `ProjectDetailView`:
1. **Compose Tab** (`ComposeTabView.swift`) - Arrangement editor with chord grid
2. **Lyrics Tab** (`LyricsTabView.swift`) - Section-based lyrics editing  
3. **Studio Tab** (`StudioTabView.swift`) - Multi-track production with MIDI playback

### Key Architectural Patterns

**SwiftData Relationships**:
- Models use `@Relationship` with store properties (e.g., `sectionTemplatesStore`) and computed properties for access
- Bidirectional relationships set inverse references in setters
- Example: `project.sectionTemplates` setter also sets `section.projectStore = self`

**Arrangement System**:
- Songs are structured as reusable `SectionTemplate` instances (Verse, Chorus, etc.)
- `ArrangementItem` array defines playback order (e.g., [Intro, Verse, Chorus, Verse, Chorus])
- Each section has `bars` (measures) containing `chordEvents` positioned by `barIndex` and `beatOffset`

**Chord System**:
- `ChordEvent` stores position (`barIndex`, `beatOffset`), duration, and chord data (root, quality, extensions)
- Beat positions are decimal: 0.0 = beat 1, 0.5 = half beat, 3.5 = end of measure
- Durations: 0.5, 1.0, 2.0, 4.0 beats
- Smart suggestions via `ChordSuggestionEngine` based on key and context

**Studio/Playback**:
- `StudioGenerator` converts chord arrangements into MIDI tracks
- `StudioPlaybackEngine` manages multi-track playback with AVAudioEngine
- SoundFont-based synthesis (FreePats SoundFonts in Resources/)
- Tracks have instrument assignment, volume, pan, effects

**Audio Recording**:
- `AudioRecordingManager` handles AVAudioRecorder/Player
- Metronome click track during recording via `MetronomeClickPlayer`
- Recordings stored in Documents directory, linked to sections via `linkedSectionId`

## Key Conventions

### File Organization
- Large view files use `// MARK:` sections for organization
- Supporting views defined in same file below main view (e.g., `SwipeActionRow` at bottom of `ComposeTabView.swift`)
- Reusable components in `Views/Components/`

### Design System
- All colors, typography, spacing via `DesignSystem` utility
- Color palette: teal primary (`#00CCBE`), warm peach accent (`#E3A894`), soft charcoal text (`#2F2E35`)
- Typography uses custom fonts: Erode (headings/emphasis) and Manrope (body)
- Section colors: 8 pastel colors (Sage, Ocean, Sky, Moss, Sand, Coral, Berry, Lavender)
- **SwipeAction icons must use `.foregroundStyle(.white)` for visibility on colored backgrounds**

### State Management
- Use `@Bindable` for `@Model` objects passed to views
- Use `@State` for view-local state
- Use `@Environment(\.modelContext)` for SwiftData operations
- Service classes use `@Observable` (not `ObservableObject`)

### Music Theory
- `MusicTheory` enum provides chromatic scale, intervals, chord qualities
- `ChordSuggestionEngine` for diatonic chords and smart progressions
- `NoteUtils` for transposition and scale calculations
- All music constants centralized in `MusicTheoryUtils.swift`

### UI Patterns
- Custom tab bar in `ProjectDetailView` (not native TabView) for consistency
- Swipe actions via custom `SwipeActionRow` component (not native `.swipeActions`)
- Sheet presentations use `.sheet(isPresented:)` with `@State` boolean flags
- Animations via `.animation(.spring(response: 0.3))` for smooth transitions

### Persistence
- SwiftData auto-saves on `modelContext` changes
- Update `project.updatedAt = Date()` when modifying projects
- iCloud sync configured via `ModelConfiguration` with `cloudKitDatabase: .private`
- No explicit save calls needed - SwiftData handles persistence

## Current Features

- ✅ Project library with filters, search, and tags
- ✅ Chord grid editor with smart suggestions
- ✅ Section-based arrangement system
- ✅ Lyrics editor synchronized with sections
- ✅ Audio recording with click track
- ✅ Multi-track studio with MIDI playback
- ✅ Drum pattern editor
- ✅ Audio effects (reverb, delay, EQ)
- ✅ iCloud sync via CloudKit

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
// SwiftData auto-saves via modelContext

// Add a section
let section = SectionTemplate(...)
project.sectionTemplates.append(section)
```

### Adding Swipe Actions
```swift
SwipeActionRow(actions: [
    SwipeActionItem(
        systemImage: "trash.fill",
        tint: DesignSystem.Colors.error,
        role: .destructive
    ) {
        // Delete action
    }
]) {
    // Row content
}
```

## Important Notes

- App forces light mode via `UIView.appearance().overrideUserInterfaceStyle = .light`
- Navigation/tab bar appearance customized in `SuonoteApp.swift` init
- Font registration happens in `FontExtensions.swift` - check `AppFonts.checkFonts()` in debug
- SoundFonts must be in Resources/SoundFonts/ directory
- CloudKit container ID: `iCloud.Suonote`
