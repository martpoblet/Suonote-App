# Suonote

A fast iOS app for capturing and developing song ideas.

## Features

### Milestone 1: Projects Library ✅
- Browse and search projects
- Filter by status and tags
- Create new song ideas quickly
- Project cards with metadata display

### Milestone 2: Project Detail Tabs ✅
- **Compose Tab**: Arrangement editor with chord grid
- **Lyrics Tab**: Section-based lyrics editing
- **Recordings Tab**: Audio recording with click track and visual pulse

### Milestone 3: Chord Editor ✅
- Interactive chord grid (2 slots per bar)
- Chord palette with In Key, Other, and Custom tabs
- Visual chord editing

## Technical Stack

- SwiftUI for UI
- SwiftData for local-first persistence
- AVFoundation for audio recording and playback
- 100% native iOS (Swift)

## Project Structure

```
Suonote/
├── Models/
│   ├── Project.swift
│   ├── SectionTemplate.swift
│   ├── ArrangementItem.swift
│   ├── ChordEvent.swift
│   └── Recording.swift
├── Views/
│   ├── ProjectsListView.swift
│   ├── CreateProjectView.swift
│   ├── ProjectDetailView.swift
│   ├── ComposeTabView.swift
│   ├── ChordPaletteView.swift
│   ├── LyricsTabView.swift
│   ├── RecordingsTabView.swift
│   ├── KeyPickerView.swift
│   └── ExportView.swift
├── Services/
│   └── AudioRecordingManager.swift
├── Utils/
│   └── DateExtensions.swift
└── SuonoteApp.swift
```

## Getting Started

1. Open the project in Xcode 15+
2. Select a simulator or device running iOS 17+
3. Build and run

## Core Concepts

- **Project**: A song idea with key, BPM, time signature
- **Section Template**: Reusable content (chords, lyrics, pattern)
- **Arrangement**: Ordered list of section instances
- **Recording**: Audio takes with metadata and click track

## Future Roadmap

- Phase 2: Tap-to-mark chords during playback
- Phase 3: Automatic chord suggestions
- MIDI export functionality
- Cloud sync (optional)

