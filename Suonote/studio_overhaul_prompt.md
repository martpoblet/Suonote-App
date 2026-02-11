# ✅ Studio Overhaul Prompt (SwiftUI + AVAudioEngine/Sequencer)

Act as a senior iOS audio + SwiftUI engineer. You will **refactor + fix + improve** the entire **Studio** side of the app using the provided files:

- `StudioPlaybackEngine.swift`
- `StudioDrumEditor.swift`
- `StudioTabView.swift` (includes `StudioTrackEditorView`, `StudioTimelineView`, `StudioNoteEditor`, etc.)

## Non-negotiables
- **Do not change the visual design language** (keep `DesignSystem.*`, spacing, typography, existing style intent).
- You may improve layout behavior/responsiveness and interactions, but **no “redesign”**.
- Prioritize: **timing correctness**, **audio sync**, **performance**, **clean architecture**, **testability**.

---

# 1) Core problems to solve (must fix)

## 1.1 Audio tracks drift / wrong offset math
`StudioPlaybackEngine.scheduleAudioTracks()` uses:
- `beatDuration = gridBeatInterval` ❌ (this is not seconds-per-beat)
- `offsetSeconds = (startBeat - info.startBeat) * beatDuration` ❌

### Fix requirement
Define **seconds per UI beat** properly from project tempo + meter conversion:

- Sequencer uses **quarter-note beats**.
- UI timeline uses “beats” in `timeTop/timeBottom` where beat unit is `timeBottom`.
- You already use: `beatScale = 4.0 / Double(project.timeBottom)` so:
  - `sequencerBeat = uiBeat * beatScale`
  - Therefore `uiBeatDurationSeconds = quarterDurationSeconds * beatScale`
  - `quarterDurationSeconds = 60 / bpm`

✅ Replace offset math with:
- `let uiBeatSeconds = (60.0 / bpm) * beatScale`
- `offsetSeconds = (startBeat - info.startBeat) * uiBeatSeconds`

This alone should fix lots of wrong alignment for 6/8, 3/8, etc.

---

## 1.2 Audio scheduling is not sample-accurate (uses asyncAfter)
Current negative offset branch does:
- `node.scheduleFile(file, at: nil)`
- `DispatchQueue.main.asyncAfter { node.play() }` ❌

### Fix requirement
Schedule playback using **AVAudioTime hostTime**, aligned to engine time:

- Use `engine.outputNode.lastRenderTime` and `engine.outputNode.playerTime(forNodeTime:)` (or `engine.mainMixerNode.lastRenderTime`) to derive a stable reference.
- Compute a target host time for “start in X seconds”.
- Use:
  - `node.play(at: AVAudioTime(hostTime: targetHostTime))`
  - or schedule the segment “at” that time.

No more `DispatchQueue.main.asyncAfter` for audio start.

---

## 1.3 Sequencer tempo handling is fragile (`sequencer.rate`)
Currently:
```swift
sequencer.rate = Float(bpm / 120.0)
```
This is a hack and can cause confusion when bpm changes.

### Fix requirement
Drive tempo properly:
- Prefer setting the sequencer’s tempo track (add tempo events).
- If you keep `rate`, at least ensure:
  - `sequencer.rate = 1` by default
  - tempo changes rebuild tempo track
  - UI beat <-> sequencer beat conversions remain consistent

Goal: When BPM changes, playback remains stable and seek/play stays aligned with audio tracks.

---

## 1.4 Mute/Solo should apply immediately without rebuild
Right now, mute/solo changes mark `needsRebuild = true` and only apply on next play.

### Fix requirement
Implement live mixing changes:
- For muted tracks: set their track mixer volume to `0` (store previous volume if needed).
- For solo:
  - If any solo track exists, non-solo tracks become effectively muted.
  - If no solo tracks, restore normal volumes.
- Apply to both:
  - sampler tracks (`sampler -> mixer`)
  - audio tracks (`player -> mixer`)

Add something like:
- `func applyMixState(project: Project)` or `updateSoloMute(tracks:)`
and call it from UI on toggle, even while playing.

---

# 2) StudioPlaybackEngine.swift — required refactor

## 2.1 Split responsibilities (keep same public API)
Refactor into small private helpers without changing how `StudioTabView` calls it:
- `prepare(project:)`
- `rebuildSequence(project:)`
- `play/pause/stop/seek`
- `updateTrackMix(trackId:volume:pan:)`

### New internal structure (recommended)
- `BeatClock` helper:
  - conversions: `uiBeat <-> sequencerBeat`
  - `uiBeatSeconds`
- `AudioTrackScheduler` helper:
  - schedule audio nodes using hostTime
  - calculate startFrame safely
- `SamplerLoader` helper:
  - load soundfonts with correct MSB/LSB + channel logic

Keep `@MainActor` on the engine, but move heavy file IO off main where safe.

---

## 2.2 Fix engine teardown order
Current teardown:
- `engine.stop()`
- `engine.reset()`
- `engine.detach(...)`

Prefer:
1) stop sequencer & nodes
2) stop engine
3) detach nodes
4) reset engine
5) clear caches

Make sure timers are invalidated reliably.

---

## 2.3 Audio node connection formats
For audio tracks:
- determine file format once (cache it per trackId if possible)
- connect player -> mixer using that format
- ensure mixer -> main uses nil format

Also guard against missing files and avoid repeated open/read on every play.

---

## 2.4 End-of-play handling
Current:
- timer reads `sequencer.currentPositionInBeats`
- stops when `position >= totalBeats`

Fix: account for beatScale correctly + audio tracks tail.
- If you stop at exact end, audio nodes might still be playing.
- Decide behavior:
  - Option A: stop everything at end of timeline
  - Option B: allow audio tail, but stop transport + keep audio until done
Pick one and implement consistently.

---

## 2.5 Drums channel logic
You have:
- `drumMelodicChannels` and `midiChannel(for:)` returning 0 or 9 based on bank load.

Make this deterministic:
- If soundfont uses percussion bank, use channel 9
- If melodic bank drums, channel 0
Ensure it matches the bank you actually loaded (primary/fallback).

Add explicit debug logs only in debug builds.

---

# 3) StudioDrumEditor.swift — UX + performance upgrades (no redesign)

## 3.1 Gesture conflict (tap + long press)
Right now each cell uses:
- `.onTapGesture { toggle }`
- `.onLongPressGesture { accent }`

This often triggers tap before long press or feels inconsistent.

### Fix requirement
Use a single composed gesture:
- Long press should **not** toggle.
- Tap should toggle.
Implementation options:
- `highPriorityGesture(LongPressGesture...)`
- or `simultaneousGesture` + state flag
- or custom `Gesture` with minimumDuration and press tracking

Also add subtle haptic:
- toggle: light
- velocity cycle: medium

---

## 3.2 Avoid re-building large maps every render
`notesByPitch` is recomputed each body run. On big timelines, this is costly.

### Fix requirement
Cache derived note maps:
- Keep a `@State` cached dictionary and recompute only when `track.notes` changes.
- Use `.onChange(of: track.notes.count)` and also track a cheap signature:
  - e.g. lastModified timestamp, or sum of ids, or incremental update.
If you can’t detect per-note edits reliably, use:
- recompute on `onNotesChanged()` callback.

---

## 3.3 Quantization correctness
`stepIndex(for:)` uses rounded():
```swift
Int((note.startBeat / stepLength).rounded())
```
This can jump notes to neighbor cells.

### Fix requirement
Use deterministic quantization:
- `Int(floor(note.startBeat / stepLength + 1e-6))`
or store the step index explicitly when creating notes.

Also ensure duplication uses exact step alignment.

---

## 3.4 Lane definitions
You use `SectionColor.*.color` for lane colors. Keep it.
But ensure lane identity is stable:
- lane `id` is currently `name` which is ok, but ensure uniqueness if names change.

---

# 4) StudioTabView.swift / Track Editor — behavior + performance

## 4.1 Rebuild strategy: stop doing heavy rebuilds unnecessarily
Currently `needsRebuild` flips often.

### Fix requirement
Create a more precise rebuild trigger:
- Rebuild only when:
  - notes changed (structure)
  - tempo/meter changed
  - track added/removed
  - instrument variant changed (sampler reload)
  - audio recording source changed
- Do NOT rebuild when only:
  - volume/pan changes (use mixer update live)
  - mute/solo changes (applyMixState live)
  - selection changes

Implement:
- `StudioPlaybackEngine.updateProject(_:)` or `syncIfNeeded(project:)` called from view changes.

---

## 4.2 Selected track behavior
Ensure:
- selecting a track doesn’t automatically open editor unless user intends it
Right now `.onTapGesture` triggers `onOpenEditor()` always.

### Fix requirement
Make tap select, and add an explicit affordance to open editor OR keep current behavior but prevent accidental opens:
- Option A (preferred): tap selects, secondary button opens editor
- Option B: keep tap to open editor but add a “hit slop” or delay to avoid accidental scroll taps

Choose the minimal change consistent with current UX.

---

## 4.3 Timeline scrub should not spam seeks
Current drag gesture calls `onSeek` continuously.
This can cause:
- repeated stop/play cycles when `isPlaying`
- audible glitches

### Fix requirement
Implement scrub throttling:
- While dragging: update UI playhead only (no engine seek)
- On end: commit seek once
OR
- throttle seeks (e.g. every 40–80ms) and avoid full restart until end

Make it smooth.

---

# 5) Acceptance criteria (must pass)

## Playback correctness
- 4/4 @ 120: audio tracks align with MIDI notes across start/seek.
- 6/8 @ 90: alignment remains correct (no drift).
- Seeking during playback does not create doubling/overlapping audio.
- Audio start offsets respect `track.audioStartBeat` precisely.

## UX correctness
- Drum cell long press cycles velocity without toggling.
- Tap toggles reliably.
- Copy/paste bar keeps notes exactly in the expected steps.

## Performance
- Drum editor remains responsive at large `totalBars` (e.g. 32–64 bars).
- Avoid rebuilding note maps in every frame unnecessarily.
- No repeated file open/format parsing on every play.

## Code quality
- Smaller functions, clearer naming, documented beat conversions.
- Remove dead code (`generalSoundFontURL/resolvedProgram/resolvedCustomBankURL` if truly unused) or implement them properly.
- No main-thread heavy work that can be moved safely.

---

# 6) Deliverables

1) Provide updated Swift code for:
- `StudioPlaybackEngine.swift`
- `StudioDrumEditor.swift`
- Any minimal supporting helpers you introduce (inside same files unless necessary)

2) Explain changes briefly in comments:
- Beat conversion logic
- HostTime scheduling logic
- Mute/solo live mixing behavior

3) Keep public interfaces stable unless absolutely required.

---

# Implementation notes you must follow
- Use `uiBeatSeconds = (60 / bpm) * beatScale`
- Use hostTime scheduling for delayed audio start
- Cache note maps in Drum Editor
- Fix quantization rounding bugs
- Implement live mute/solo and keep volume/pan smooth

GO.
