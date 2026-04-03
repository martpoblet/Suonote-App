import AVFoundation
import AudioToolbox
import Combine

/// Simple chord preview player using MIDI sampler
final class ChordPreviewPlayer: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var isSetup = false
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        guard !isSetup else { return }
        
        // Attach sampler to engine
        audioEngine.attach(sampler)
        
        // Connect to output
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        
        // Load piano soundfont
        loadPianoSoundFont()
        
        // Start engine
        do {
            try audioEngine.start()
            isSetup = true
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    private func loadPianoSoundFont() {
        // Use Electric Piano from Arachno (warm, cleaner preview than acoustic)
        if let customURL = SoundFontManager.soundFontURL(for: .piano, variant: .electricPiano) {
            attemptLoad(url: customURL, program: 4) // Electric Piano = GM program 4
            return
        }

        // Fallback to system SoundFont
        if let systemURL = systemSoundBankURL() {
            attemptLoad(url: systemURL, program: 4)
        }
    }
    
    private func systemSoundBankURL() -> URL? {
        let possiblePaths = [
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
            "/System/Library/Frameworks/AudioToolbox.framework/Versions/A/Resources/gs_instruments.dls"
        ]
        
        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        
        return nil
    }
    
    private func attemptLoad(url: URL, program: UInt8) {
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            print("✅ Loaded SoundFont for chord preview")
        } catch {
            print("❌ Failed to load SoundFont: \(error)")
        }
    }
    
    /// Play a chord preview with voice spread, per-voice velocity, and bass octave doubling.
    func playChord(root: String, quality: ChordQuality, duration: TimeInterval = 0.8) {
        let notes = ChordUtils.getChordNotes(root: root, quality: quality)
        guard !notes.isEmpty else { return }

        // Build voiced notes: bass (octave 3) + chord voicing (octave 4), low→high
        var midiNotes: [UInt8] = []
        if let rootMidi = noteNameToMIDI(notes[0], octave: 3) {
            midiNotes.append(rootMidi)  // bass note, one octave lower
        }
        for name in notes {
            if let m = noteNameToMIDI(name, octave: 4) {
                midiNotes.append(m)
            }
        }
        guard !midiNotes.isEmpty else { return }

        // Velocity per voice: bass loudest, inner voices softer, soprano medium.
        let lastIndex = midiNotes.count - 1
        let velocities: [UInt8] = midiNotes.indices.map { index in
            if index == 0               { return 92 }  // bass — punchy anchor
            if index == lastIndex       { return 78 }  // soprano — slightly above inner
            if index == 1               { return 70 }  // lowest chord tone
            return 65                                   // inner voices — sit back
        }

        // Staggered note-on: 14ms per voice — like a real piano arpeggiation
        for (i, midiNote) in midiNotes.enumerated() {
            let delay = Double(i) * 0.014
            let vel = velocities[i]
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.sampler.startNote(midiNote, withVelocity: vel, onChannel: 0)
            }
        }

        // Staggered note-off: bass lingers, upper voices release earlier — natural decay
        let bassRelease = duration + 0.15
        let upperRelease = duration - 0.05

        for (i, midiNote) in midiNotes.enumerated() {
            let releaseTime = i == 0 ? bassRelease : upperRelease
            DispatchQueue.main.asyncAfter(deadline: .now() + releaseTime) { [weak self] in
                self?.sampler.stopNote(midiNote, onChannel: 0)
            }
        }

        print("🎹 Playing chord: \(root) \(quality.displayName) — \(midiNotes.count) voices")
    }
    
    /// Convert note name (e.g., "C", "C#", "Db") to MIDI number at the given octave.
    private func noteNameToMIDI(_ noteName: String, octave: Int = 4) -> UInt8? {
        let noteMap: [String: Int] = [
            "C": 0, "C#": 1, "Db": 1,
            "D": 2, "D#": 3, "Eb": 3,
            "E": 4,
            "F": 5, "F#": 6, "Gb": 6,
            "G": 7, "G#": 8, "Ab": 8,
            "A": 9, "A#": 10, "Bb": 10,
            "B": 11
        ]
        guard let semitone = noteMap[noteName] else { return nil }
        let midiNote = (octave + 1) * 12 + semitone
        guard midiNote >= 0, midiNote <= 127 else { return nil }
        return UInt8(midiNote)
    }
}
