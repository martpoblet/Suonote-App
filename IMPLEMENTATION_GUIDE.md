IMPLEMENTATION_GUIDE.md

# Suonote - Implementation Guide

## What Has Been Created

A complete iOS app structure for Suonote following the specifications in `initial.md`.

### Files Created (17 total)

#### App Entry Point
- `SuonoteApp.swift` - Main app with SwiftData model container

#### Models (6 files)
- `Project.swift` - Core project model with status, tags, key, BPM, time signature
- `SectionTemplate.swift` - Reusable section content with chords and lyrics
- `ArrangementItem.swift` - References to sections in arrangement order
- `ChordEvent.swift` - Chord data (root, quality, extensions, position)
- `Recording.swift` - Audio take metadata

#### Views (9 files)
- `ProjectsListView.swift` - Library screen with search, filters, project cards
- `CreateProjectView.swift` - Fast modal for creating new projects
- `ProjectDetailView.swift` - Tab container for Compose/Lyrics/Recordings
- `ComposeTabView.swift` - Arrangement editor + section editor + chord grid
- `ChordPaletteView.swift` - Chord selection with In Key/Other/Custom tabs
- `LyricsTabView.swift` - Section-based lyrics editing
- `RecordingsTabView.swift` - Recording UI with click track and takes list
- `KeyPickerView.swift` - Key and mode selection
- `ExportView.swift` - Export placeholder (MIDI/Text)

#### Services
- `AudioRecordingManager.swift` - AVFoundation-based recording with metronome

#### Utils
- `DateExtensions.swift` - Time ago formatting

## Features Implemented

### ✅ Milestone 1: Projects Library
- Search by title and tags
- Filter by status (Idea, In Progress, Polished, Finished, Archived)
- Filter by tags
- Project cards showing:
  - Title, status pill, tags
  - Key, BPM, recordings count
  - Last edited timestamp
- Fast project creation modal
- Sorting by most recently edited

### ✅ Milestone 2: Project Detail Tabs
- **Compose Tab**:
  - Global header with key/mode/BPM/time signature controls
  - Arrangement block (list of sections)
  - Section editor (name, bars, pattern preset)
  - Interactive chord grid (2 slots per bar)
  
- **Lyrics Tab**:
  - List of unique sections
  - Usage count for repeated sections
  - Text editor for lyrics per section

- **Recordings Tab**:
  - Record/Stop button with visual design
  - Count-in selector (1-2 bars)
  - Click/metronome toggle
  - Visual pulse toggle
  - Takes list with playback
  - Rename, delete, favorite actions
  - Metadata display (BPM, time sig, duration)

### ✅ Milestone 3: Chord Editor
- Chord grid with 2 slots per bar
- Tap to open chord palette
- Palette tabs: In Key, Other Key, Custom
- In Key chords calculated from project key/mode
- Clear chord option
- Chord display updates in real-time

## How to Open in Xcode

Since this is a SwiftUI/SwiftData project, you'll need to create a proper Xcode project:

### Option 1: Use Xcode to Create Project
1. Open Xcode
2. File → New → Project
3. Choose "iOS App"
4. Name: "Suonote"
5. Interface: SwiftUI
6. Storage: SwiftData
7. Create the project
8. Delete the template files
9. Copy all the files from the created structure into the Xcode project

### Option 2: Import Files into New Project
1. Create new Xcode project with SwiftUI + SwiftData
2. Drag and drop all files from each folder:
   - Models → Xcode Models group
   - Views → Xcode Views group
   - Services → Xcode Services group
   - Utils → Xcode Utils group
3. Add `Info.plist` to project
4. Build and run

## Key Technical Decisions

1. **SwiftData** for local-first persistence (no backend required)
2. **@Bindable** and **@Query** property wrappers for reactive UI
3. **AVAudioSession** + **AVAudioRecorder** for audio recording
4. **System sounds** for metronome clicks (1054 for accent, 1053 for normal)
5. **Relationships** with cascade delete for data integrity
6. **UUID** identifiers for all models

## Architecture Highlights

### Data Flow
- SwiftData models are @Observable by default
- Views use @Query for automatic updates
- @Bindable enables two-way binding to model properties
- Relationships maintain data integrity

### Recording Flow
1. User configures count-in and click settings
2. Metronome plays during count-in
3. Recording starts after count-in
4. Visual pulse syncs with BPM
5. Recording saved with metadata
6. File stored in Documents directory

### Chord Grid Logic
- 2 fixed slots per bar (beat 0 and beat 2)
- ChordEvents stored with barIndex + beatOffset
- Palette shows chords filtered by key
- Display updates immediately after selection

## What's Still Placeholder

- Play/Stop functionality (metronome icon in Compose header)
- Actual MIDI export implementation
- Text export implementation
- Tap-to-mark chords during playback (Phase 2)
- Automatic chord suggestions (Phase 3)

## Next Steps

1. Create proper Xcode project and import files
2. Test on iOS simulator or device (iOS 17+)
3. Implement Play/Stop with AVAudioEngine
4. Add MIDI export using MIDIKit or similar
5. Test recording permissions and audio session
6. Add unit tests for models
7. Consider iPad support (already supports orientation)

## Notes

- All code is brand-neutral as requested
- No external dependencies required
- Fully local-first (no auth/cloud)
- Follows SwiftUI best practices
- Uses iOS 17+ features (SwiftData, @Observable)
