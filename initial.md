# Suonote — Initial Product Spec (v0.1)

## 1) Vision

Suonote is an iOS app for capturing **song ideas fast** and helping musicians **develop those ideas into finished songs**.

A Project is a song idea. The user can quickly add:

- Chords / harmony
- Lyrics
- Tempo & time signature
- Audio takes (quick recordings)

And Suonote gradually assists the user through development features like structure, repeatable sections, playback, and export to a DAW.

**Core promise:** “Capture the idea in seconds. Develop it with clarity.”

---

## 2) High-level UX Principles

- **Speed first:** creation must be frictionless.
- **Context always visible:** user always knows the current section, bar, and tempo.
- **Song-first mental model:** structure (Arrangement) + reusable Section content.
- **Low-tap editing:** tap to set, long-press for actions, chips for fast choices.
- **Audio as a first-class citizen:** takes are part of the idea, not an afterthought.
- **MVP is local-first:** no login required initially.

---

## 3) App Information Architecture

### Main navigation

- **Projects** (library)
- Project detail:
  - **Compose** tab
  - **Lyrics** tab
  - **Recordings** tab

---

## 4) Projects (Library) Screen

### Purpose

Let a musician:

- create a new idea instantly
- find and filter existing ideas
- organize ideas with status + tags

### Layout

- Top bar: App title “Projects” + Search
- Quick filters (chips): Status, Tags (and optionally Key/BPM in advanced filters)
- List/grid of Project cards
- Primary CTA: “+ New Idea”

### Project card content

- Title
- Status pill
- Tag chips (limited to 2–3 visible)
- Key + BPM (if set)
- Updated date (“Edited 2h ago”)
- Audio badge (e.g., “2 takes”) if recordings exist

### Create Project (New Idea) flow (fast modal)

Fields:

- Title (default: “New Idea”)
- Status (default: Idea)
- Tags (optional)
- Optional: tempo preset (or keep default)

### Status values (recommended)

Keep it simple and meaningful:

1. **Idea** (raw capture)
2. **In Progress** (structure or sections exist)
3. **Polished** (lyrics/harmony mostly defined)
4. **Finished** (ready to export / rehearse)
5. **Archived** (optional)

### Tags

- Free-form tags + recent suggestions
- Tag quick-add UI (chips)
- Search should match title + tags

### Projects sorting

- Default: most recently edited
- Optional: A–Z, status, key, BPM

---

## 5) Project Detail — Overview

A Project is a song idea with these global settings:

- Key (root + mode)
- BPM
- Time Signature

Project has 3 main areas:

- **Compose**: arrangement + chord editor + playback + export
- **Lyrics**: lyrics per section
- **Recordings**: audio takes captured with click + visual pulse

### Global header (Compose tab)

Persistent controls:

- Key picker + mode
- BPM control
- Time signature control
- Play/Stop
- Metronome / Click toggle
- Export

---

## 6) Compose Tab — Song-first Composition

### Concept

Suonote uses an **Arrangement-first** approach:

- **Arrangement** is the ordered structure of the song (Intro → Verse → Chorus → …)
- **Section Template** is reusable content (chords + pattern + lyrics + notes)
- **Arrangement Item** is an instance in the arrangement referencing a Section Template

**Critical rule:** repeating a Chorus 3x should NOT duplicate the chorus content. It reuses the same Section Template.

### Compose layout

#### A) Arrangement Block (top)

- List or timeline of arrangement items
- Drag & drop reordering
- Tap selects an item (selects a section instance)

Actions:

- Add new section template + append instance
- Add existing section template as another instance
- Duplicate instance
- Create variation (duplicate the template and point a new instance to the new template)

Visuals:

- Show section name
- Show repeat badge “xN” when the same template appears multiple times

#### B) Section Editor Block (bottom)

Edits the selected Section Template:

- Section name
- Bars count (Stepper)
- Pattern preset (segmented)
- Chord grid (fast editing)

### Chord grid (MVP)

- `barsCount` bars
- 2 chord slots per bar:
  - beatOffset = 0
  - beatOffset = 2
- Slot UI: pill / rounded rectangle
  - filled: show chord display
  - empty: show “—”

Interactions:

- Tap slot → open Chord Palette sheet (bar + beat context)
- Long-press filled slot → context actions:
  - Replace (opens palette)
  - Clear
  - Toggle 7th

### Chord Palette (MVP)

A bottom sheet to set/replace chords quickly.

Must include:

- Header with “Bar X • Beat Y”
- Tabs/segments:
  - **In Key** (diatonic suggestions from project key)
  - **Other Key** (diatonic suggestions from a user-selected key)
  - **Custom** (chord builder)
- “Add 7th” toggle (applies extension 7)
- Recents chips (from all chords used across the project)

Diatonic triads mapping (MVP):

- Major: I maj, ii min, iii min, IV maj, V maj, vi min, vii dim
- Natural minor: i min, ii dim, III maj, iv min, v min, VI maj, VII maj

Apply behavior:

- Selecting a chip sets/replaces the chord for the active slot.
- Default: auto-close after applying (optionally add “Keep open”).

### Playback (Phase 1)

Composition playback (not live instrument performance):

- Simple audio preview using sampler + scheduler
- Patterns:
  - Block
  - Arp
  - Basic (optional bass + simple drums)
- Loop current selected section when Loop is ON

### Export (Phase 1)

- Export Standard MIDI File (SMF)
  - Track 1: chords
  - Track 2: bass (optional)
  - Track 3: drums (optional)
- Include tempo + time signature
- Add section markers (nice-to-have)

---

## 7) Lyrics Tab — Section-based Lyrics

### Purpose

Keep lyrics organized by sections and aligned with the arrangement.

Layout:

- Show unique Section Templates in arrangement order (no duplicates)
- Tap a section → edit lyrics
- If a section appears multiple times in arrangement, show “Used X times”

Editor:

- TextEditor bound to `section.lyricsText`
- Optional: markers (Hook / Pre / Adlibs) in later phases

---

## 8) Recordings Tab — Audio Takes + Click + Visual Pulse

### Purpose

Enable “capture the idea now” with timing reference.

MVP recording experience:

- Large Record / Stop button
- Count-in selector (1–2 bars)
- Click ON/OFF
- Visual pulse ON/OFF (screen pulses on beat)

Important:

- The click should be played as monitoring reference during recording, but not baked into the recorded audio.
- Save each take with metadata: BPM, time signature, count-in settings, created time.

### Takes list / timeline

- List of takes under the record controls
- Each take card:
  - Name (editable)
  - Duration
  - Created/updated date
  - BPM / time signature at time of recording
  - Favorite/star

Actions:

- Play/pause
- Rename
- Delete
- Mark as favorite

### Linking takes to composition (Phase 2)

- Allow attaching a take to:
  - the full Project, or
  - a specific Section Template
- When a section is selected in Compose, show an attached take mini-player

---

## 9) “Magic” Development Features Roadmap

### Phase 2 — Assisted mapping (realistic, high impact)

1. **Tap-to-mark chords while playing a take**

- During playback, user taps chords in the palette.
- Save chord markers aligned to bar/beat based on project tempo.
- This builds a progression without automatic detection.

2. **Set Downbeat / Align Take**

- Let the user define where bar 1 beat 1 starts within the take.
- Improves alignment of timeline and chord grid.

### Phase 3 — Automatic suggestions

- Semi-automatic suggestions for likely chords based on audio segments.
- Full chord detection is a later/optional research-level feature.

---

## 10) MVP Tech Decisions

- SwiftUI UI
- SwiftData persistence (local-first)
- No auth/login in MVP
- Audio: AVAudioEngine + AVAudioRecorder (or modern AVAudioSession approach)
- Export: MIDI file generation + Share Sheet

---

# AI IMPLEMENTATION PROMPT (COPY/PASTE)

You are a Senior iOS Engineer and Product UX designer.
Implement the Suonote MVP screens and data models described above using SwiftUI + SwiftData.

CRITICAL RULE:

- Do NOT mention any external apps or references in code or comments.
- Keep code and comments brand-neutral.

ASSUMED EXISTING MODELS (SwiftData)

- Project: title, keyRoot, keyMode, bpm, timeTop/timeBottom, sectionTemplates[], arrangementItems[]
- SectionTemplate: name, barsCount, patternPreset, lyricsText, notesText, chordEvents[]
- ArrangementItem: orderIndex, labelOverride, sectionTemplate
- ChordEvent: barIndex, beatOffset, root, quality, extensions[], slashRoot?, display

MILESTONE 1 — Projects Library (complete)
Implement:

1. Projects screen

- Search
- Filter by status and tags
- Project cards with status pill + tags + audio badge
- Create new project modal (fast)
- Delete project
- Sorting (most recently edited)

2. Data additions

- Add `status` to Project (enum)
- Add `tags` to Project (array of strings)
- Add minimal `recordingsCount`/relationship placeholder (can be stubbed)

MILESTONE 2 — Project Detail Tabs (complete)
Implement a Project detail with 3 tabs:

- Compose
- Lyrics
- Recordings

Compose:

- Header with key/mode/bpm/time signature + play/export placeholders
- Arrangement list + Section editor placeholder

Lyrics:

- Section list in arrangement order + editor for lyricsText

Recordings:

- Record/stop UI
- Count-in (1–2 bars)
- Click toggle
- Visual pulse toggle
- Takes list UI (with rename/delete/favorite)
- Playback for takes (basic)

MILESTONE 3 — Compose Chord Editor (next)
Implement interactive chord grid + chord palette sheet:

- 2 chord slots per bar
- Tap opens palette
- Palette tabs: In Key / Other Key / Custom
- Recents chips
- Long-press context actions

RECORDING DETAILS (MVP)

- Use AVAudioSession correctly for recording/playback.
- While recording, provide a click sound (monitoring) and a UI pulse synced to BPM.
- Click should not be recorded into the audio file.
- Store takes locally with metadata (bpm, time signature, createdAt, duration, name, favorite).

OUTPUT FORMAT

1. List the files to create/modify.
2. Provide a step-by-step plan.
3. Provide code per file with headings “// File: …”
4. Ensure code compiles.

END.
