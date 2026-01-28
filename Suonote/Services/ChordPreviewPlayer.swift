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
        // Try custom SoundFont first
        if let customURL = SoundFontManager.soundFontURL(for: .piano, variant: .acousticPiano) {
            attemptLoad(url: customURL, program: 0) // Piano = 0
            return
        }
        
        // Fallback to system SoundFont
        if let systemURL = systemSoundBankURL() {
            attemptLoad(url: systemURL, program: 0)
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
    
    /// Play a chord preview
    func playChord(root: String, quality: ChordQuality, duration: TimeInterval = 0.8) {
        let notes = ChordUtils.getChordNotes(root: root, quality: quality)
        let midiNotes = notes.compactMap { noteNameToMIDI($0) }
        
        guard !midiNotes.isEmpty else { return }
        
        // Play all notes simultaneously
        let velocity: UInt8 = 80 // Medium velocity
        for midiNote in midiNotes {
            sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
        }
        
        // Stop notes after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            for midiNote in midiNotes {
                self?.sampler.stopNote(midiNote, onChannel: 0)
            }
        }
        
        print("🎹 Playing chord: \(root) \(quality.displayName) - Notes: \(notes.joined(separator: ", "))")
    }
    
    /// Convert note name (e.g., "C", "C#", "Db") to MIDI number
    private func noteNameToMIDI(_ noteName: String) -> UInt8? {
        let octave: Int = 4 // Middle octave
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
        return UInt8(midiNote)
    }
}
