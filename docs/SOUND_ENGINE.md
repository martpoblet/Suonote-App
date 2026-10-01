# Suonote — Studio sound engine (v2)

Why the Studio "didn't sound good", what changed, and how to keep it good.

## Root causes found (measured offline against MS_Basic.sf2)
1. **Silent presets.** `Warm Pad` (0/89) and `Synth Bass 1` (0/38) render *silence* under
   AUSampler (their SF2 programming relies on filter modulators AUSampler doesn't implement).
2. **~40 dB loudness spread between presets.** Slow strings ≈ -7 dBFS vs muted guitar ≈ -41,
   xylophone ≈ -57 for the same chord at velocity 90. Strings/pads buried everything; plucked
   and mallet sounds were inaudible.
3. **Wrong registers.** Octave defaults still compensated for the old Arachno bank; with the
   concert-pitched MuseScore bank the pop bass played at C0 and pads in octave 1.
4. **Lopsided rhythms.** The `complexity` control kept the *first half* of a bar's hits
   (rock guitar: two stabs, then silence); guitar off-beats were filtered out in every style;
   the Lo-Fi default groove had a single snare per bar.
5. **No mix.** Everything dry, centered, at the same fader, summed into a limiter.
6. **Generic sounds.** Every style got the same first-in-list variant (nylon guitar for rock,
   a "bass & lead" synth for Lo-Fi pads).

## Architecture
- `StudioSoundCatalog` — variant → real preset (bank/program, silent-preset substitutes),
  measured loudness trims, mix role, per-style mix profile (balance, default pan, ambience
  send, high-pass/low-pass, sustain pedal), shared ambience reverb per style.
- `StudioMixGraph` — builds the graph, shared by playback and export:
  `sampler → tone EQ (trim + role filters + user EQ) → comp → reverb → delay → channel`
  `channel → main mixer` + post-fader send to a shared, filtered ambience reverb.
  Master: bus EQ → glue compressor → peak limiter → -1 dB ceiling.
  Writes MIDI incl. legato piano pedalling (CC64 re-pressed on harmony changes), and can
  rewrite a single part in place (`rewriteEvents`) for live note edits.
- `StudioPlaybackEngine` — realtime transport on top of the graph; live metronome toggle
  (click track always sequenced, muted/unmuted); `notesChanged(for:project:)` hot-swaps edits.
- `StudioOfflineRenderer` — bounces the arrangement to M4A/WAV faster than realtime through
  the same graph (Export ▸ Studio mix, Studio ▸ ⋯ ▸ Export audio mix).
- `StudioSoundPreviewer` — auditions a variant (groove / bass line / chord / melody) in pickers.
- `ChordPreviewPlayer` — Compose audition: mellow grand, room, pedal, voice-led voicings,
  flat roots (Bb, Eb…) now sound.
- `SoundFontManager.defaultVariant(for:style:)` — style-appropriate starting sounds.

## Re-calibrating (if the SoundFont changes)
Loudness trims in `StudioSoundCatalog.measuredTrims` were produced by an offline harness that
renders each supported variant (chord/note/groove at velocity 90) and measures max momentary
RMS (400 ms windows), targeting -20 dBFS. Re-measure whenever the bank changes; the unit test
`testEverySupportedVariantHasALoudnessTrim` fails if a new variant has no trim.

## v3 — "less MIDI" (arrangement, performance, synth)
- **`StudioArranger`** — reads section names (EN/ES: intro/estrofa/pre-coro/coro/puente/final…),
  assigns an energy level per section and decides per part what plays: pop intros without
  drums/bass, lighter first verses (cross-stick, roots-only bass), second harmony instrument
  and strings entering for pre-choruses/choruses, brass only in choruses, leads in
  intro/bridge/outro. Writes drum fills into section changes, a crash on big downbeats and a
  final hit; dedupes doubled drum hits. Per-track opt-out: `StudioTrack.followsArrangement`
  ("Follow the song's structure" in the Feel panel).
- **Expression** — `StudioArranger.expressionCurve` drives CC11 on strings/pads/organ/brass:
  soft verses, crescendo through pre-choruses, full choruses, fading outros.
- **Performance feel** — `applyNaturalness` now moves *gestures* (notes struck together)
  with small gaussian timing, rolls piano chords low→high, lays backbeats back per style,
  sits the bass behind the kick and drifts dynamics by phrase (was: independent ±34 ms
  per-note jitter that smeared chords).
- **Bus compression** — drums and bass get built-in glue compression unless the user enables
  their own compressor.
- **`SuonoteSynthAudioUnit`** — in-process AUv3 virtual-analog synth (2 polyBLEP saws + sub,
  ZDF state-variable low-pass with envelope, per-voice stereo). Presets: Analog Pad, Glass Pad,
  Supersaw, Soft Pluck, Analog Synth Bass, Sub Bass. Driven by `AVAudioSequencer` like a sampler.
- **AVFAudio race** — configure effect parameters *before* connecting nodes; connecting at a
  new sample rate makes Apple units rebuild their parameter tree on a background queue and
  setting parameters concurrently crashes (seen at 48 kHz).
