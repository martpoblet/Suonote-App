import os
import AVFoundation
import AudioToolbox
import Combine

/// Chord audition for Compose: a mellow grand in a small room, voiced like a
/// pianist would (bass + open upper structure) and voice-led from the previous
/// chord so tapping through a progression sounds connected, not like blocks.
///
/// Engine starts lazily on first preview; pending note-offs are cancelled when
/// a new chord starts so rapid previews never leave hanging notes (A-06).
final class ChordPreviewPlayer: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let tone = AVAudioUnitEQ(numberOfBands: 2)
    private let room = AVAudioUnitReverb()
    private var isSetup = false
    private var activeNotes: Set<UInt8> = []
    private var pendingWorkItems: [DispatchWorkItem] = []
    private var interruptionObserver: Any?
    private var lastUpperVoicing: [Int] = []

    init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopAllNotes()
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    private func setupIfNeeded() {
        guard !isSetup else {
            if !audioEngine.isRunning {
                try? audioEngine.start()
            }
            return
        }

        [sampler, tone, room].forEach { audioEngine.attach($0) }

        // Configure units before connecting (parameter-tree rebuild race).
        let bands = tone.bands
        bands[0].filterType = .highPass
        bands[0].frequency = 60
        bands[0].bypass = false
        bands[1].filterType = .parametric
        bands[1].frequency = 300
        bands[1].bandwidth = 1.2
        bands[1].gain = -2
        bands[1].bypass = false
        room.loadFactoryPreset(.mediumRoom)
        room.wetDryMix = 16
        audioEngine.connect(sampler, to: tone, format: nil)
        audioEngine.connect(tone, to: room, format: nil)
        audioEngine.connect(room, to: audioEngine.mainMixerNode, format: nil)

        loadPiano()

        do {
            try audioEngine.start()
            isSetup = true
        } catch {
            AppLog.audio.error("Failed to start chord preview engine: \(String(describing: error))")
        }
    }

    private func loadPiano() {
        let variant = InstrumentVariant.mellowGrandPiano
        tone.globalGain = StudioSoundCatalog.loudnessTrimDB(for: variant, instrument: .piano) + 2
        if let url = SoundFontManager.soundFontURL(for: .piano, variant: variant) {
            let preset = StudioSoundCatalog.preset(for: variant)
            if attemptLoad(url: url, program: preset.program, bankLSB: preset.bankVariation)
                || attemptLoad(url: url, program: 0, bankLSB: 0) {
                return
            }
        }
        if let systemURL = systemSoundBankURL() {
            _ = attemptLoad(url: systemURL, program: 0, bankLSB: 0)
        }
    }

    private func systemSoundBankURL() -> URL? {
        let possiblePaths = [
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
            "/System/Library/Frameworks/AudioToolbox.framework/Versions/A/Resources/gs_instruments.dls"
        ]
        return possiblePaths
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func attemptLoad(url: URL, program: UInt8, bankLSB: UInt8) -> Bool {
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: bankLSB
            )
            return true
        } catch {
            AppLog.audio.error("Failed to load preview SoundFont: \(String(describing: error))")
            return false
        }
    }

    /// Cancels pending note events and silences anything still sounding.
    func stopAllNotes() {
        for item in pendingWorkItems {
            item.cancel()
        }
        pendingWorkItems.removeAll()
        sampler.sendController(64, withValue: 0, onChannel: 0)
        for note in activeNotes {
            sampler.stopNote(note, onChannel: 0)
        }
        activeNotes.removeAll()
    }

    private func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        pendingWorkItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Play a chord preview: bass root + voice-led upper structure.
    func playChord(root: String, quality: ChordQuality, duration: TimeInterval = 0.9) {
        guard let rootPC = Self.pitchClass(of: root) else { return }
        let pitchClasses = quality.intervals.map { (rootPC + $0) % 12 }
        guard !pitchClasses.isEmpty else { return }
        play(bassPitchClass: rootPC, upperPitchClasses: pitchClasses, duration: duration)
    }

    /// Audition arbitrary MIDI pitches (e.g. a slash chord or a voicing).
    func playPitches(_ pitches: [Int], duration: TimeInterval = 0.9) {
        setupIfNeeded()
        stopAllNotes()
        let notes = pitches.map { UInt8(max(0, min(127, $0))) }
        strike(notes, velocities: notes.map { _ in 76 }, duration: duration)
    }

    private func play(bassPitchClass: Int, upperPitchClasses: [Int], duration: TimeInterval) {
        setupIfNeeded()
        stopAllNotes()

        // Bass: root nearest to D3, kept between E2 and D#3.
        var bass = 48 + bassPitchClass
        if bass > 51 { bass -= 12 }
        if bass < 40 { bass += 12 }

        // Upper structure: drop the root when the chord is rich enough, keep
        // it to 4 voices, and voice-lead from the previous chord.
        var tones = upperPitchClasses
        if tones.count >= 4, let rootIndex = tones.firstIndex(of: bassPitchClass) {
            tones.remove(at: rootIndex)
        }
        if tones.count > 4 {
            // Prefer 3rd/7th/colour tones: keep the last four (extensions are
            // appended after the core triad in ChordQuality.intervals).
            tones = Array(tones.suffix(4))
        }
        let upper = Self.voiceLead(pitchClasses: tones, from: lastUpperVoicing, above: bass)
        lastUpperVoicing = upper

        let notes = ([bass] + upper).map { UInt8($0) }
        let velocities: [UInt8] = notes.indices.map { index in
            if index == 0 { return 84 }                 // bass anchor
            if index == notes.count - 1 { return 78 }   // melody voice on top
            return 66                                   // inner voices sit back
        }
        strike(notes, velocities: velocities, duration: duration)
    }

    private func strike(_ notes: [UInt8], velocities: [UInt8], duration: TimeInterval) {
        // Pedal down so the chord blooms into the room.
        sampler.sendController(64, withValue: 127, onChannel: 0)
        // Gentle roll (≈12 ms per voice) — a pianist's hand, not a machine.
        for (index, note) in notes.enumerated() {
            let velocity = velocities[min(index, velocities.count - 1)]
            schedule(after: Double(index) * 0.012) { [weak self] in
                self?.activeNotes.insert(note)
                self?.sampler.startNote(note, withVelocity: velocity, onChannel: 0)
            }
        }
        schedule(after: duration) { [weak self] in
            guard let self else { return }
            for note in notes {
                self.sampler.stopNote(note, onChannel: 0)
                self.activeNotes.remove(note)
            }
        }
        // Lift the pedal a little later for a natural tail.
        schedule(after: duration + 0.35) { [weak self] in
            self?.sampler.sendController(64, withValue: 0, onChannel: 0)
        }
        // Idle engines still burn CPU: pause once the tail has rung out.
        schedule(after: duration + 2.5) { [weak self] in
            guard let self, self.activeNotes.isEmpty else { return }
            self.audioEngine.pause()
        }
    }

    // MARK: - Voicing

    /// Places each pitch class in F3…A5, choosing the arrangement closest to
    /// the previous voicing (or centred around E4 when there is none).
    static func voiceLead(pitchClasses: [Int], from previous: [Int], above bass: Int) -> [Int] {
        let low = max(bass + 5, 53)   // at least a fourth above the bass, ≥ F3
        let high = 81                 // A5
        let target = previous.isEmpty ? 64.0 : Double(previous.reduce(0, +)) / Double(previous.count)

        var voiced: [Int] = []
        for pc in pitchClasses {
            var candidates: [Int] = []
            var pitch = low + ((pc - low % 12) + 12) % 12
            while pitch <= high {
                candidates.append(pitch)
                pitch += 12
            }
            guard !candidates.isEmpty else { continue }
            let best = candidates.min { abs(Double($0) - target) < abs(Double($1) - target) } ?? candidates[0]
            voiced.append(best)
        }
        voiced = Array(Set(voiced)).sorted()
        // Avoid a cluster: if the voicing spans less than a fifth with 4 voices,
        // open it by lifting the second voice an octave (drop-2 in reverse).
        if voiced.count >= 4, let first = voiced.first, let last = voiced.last, last - first < 9,
           voiced[1] + 12 <= high {
            voiced[1] += 12
            voiced.sort()
        }
        return voiced
    }

    static func pitchClass(of noteName: String) -> Int? {
        let map: [String: Int] = [
            "C": 0, "B#": 0, "C#": 1, "Db": 1,
            "D": 2, "D#": 3, "Eb": 3,
            "E": 4, "Fb": 4, "E#": 5,
            "F": 5, "F#": 6, "Gb": 6,
            "G": 7, "G#": 8, "Ab": 8,
            "A": 9, "A#": 10, "Bb": 10,
            "B": 11, "Cb": 11
        ]
        return map[noteName.trimmingCharacters(in: .whitespaces)]
    }
}
