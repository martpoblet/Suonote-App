import AVFoundation

/// Offline audio bounce/render (P-01)
/// Renders the studio arrangement to a WAV/M4A file
class AudioBounceEngine {
    
    enum BounceFormat {
        case wav
        case m4a
        
        var settings: [String: Any] {
            switch self {
            case .wav:
                return [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            case .m4a:
                return [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                    AVEncoderBitRateKey: 256000
                ]
            }
        }
        
        var fileExtension: String {
            switch self {
            case .wav: return "wav"
            case .m4a: return "m4a"
            }
        }
    }
    
    /// Bounce the current engine output to a file
    /// Uses AVAudioEngine's offline rendering mode
    static func bounce(
        engine: AVAudioEngine,
        sequencer: AVAudioSequencer,
        duration: TimeInterval,
        format: BounceFormat = .wav,
        fileName: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName).\(format.fileExtension)")
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        let sampleRate = 44100.0
        let channelCount: AVAudioChannelCount = 2
        guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount) else {
            throw BounceError.invalidFormat
        }
        
        // Enable manual rendering
        try engine.enableManualRenderingMode(.offline, format: outputFormat, maximumFrameCount: 4096)
        try engine.start()
        
        sequencer.currentPositionInBeats = 0
        try sequencer.start()
        
        let totalFrames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 4096)!
        
        guard let outputFile = try? AVAudioFile(forWriting: outputURL, settings: format.settings) else {
            throw BounceError.cannotCreateFile
        }
        
        var framesRendered: AVAudioFrameCount = 0
        
        while framesRendered < totalFrames {
            let framesToRender = min(4096, totalFrames - framesRendered)
            let status = try engine.renderOffline(framesToRender, to: buffer)
            
            switch status {
            case .success:
                try outputFile.write(from: buffer)
                framesRendered += framesToRender
                progress?(Double(framesRendered) / Double(totalFrames))
            case .insufficientDataFromInputNode:
                continue
            case .cannotDoInCurrentContext:
                try await Task.sleep(nanoseconds: 10_000_000)
            case .error:
                throw BounceError.renderError
            @unknown default:
                throw BounceError.renderError
            }
        }
        
        engine.stop()
        engine.disableManualRenderingMode()
        
        return outputURL
    }
    
    enum BounceError: LocalizedError {
        case invalidFormat
        case cannotCreateFile
        case renderError
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Invalid audio format"
            case .cannotCreateFile: return "Cannot create output file"
            case .renderError: return "Audio rendering failed"
            }
        }
    }
}

// MARK: - Per-Track Effect Presets (P-02)

/// Effect presets that can be applied per-track
struct TrackEffectPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var reverbAmount: Float   // 0.0 - 1.0
    var delayAmount: Float    // 0.0 - 1.0
    var delayTime: Float      // seconds
    var eqLow: Float          // -12 to +12 dB
    var eqMid: Float          // -12 to +12 dB
    var eqHigh: Float         // -12 to +12 dB
    var compressorThreshold: Float  // dB
    var compressorRatio: Float      // 1:1 to 20:1
    
    static let clean = TrackEffectPreset(
        id: UUID(), name: "Clean", reverbAmount: 0.1, delayAmount: 0,
        delayTime: 0, eqLow: 0, eqMid: 0, eqHigh: 0,
        compressorThreshold: -20, compressorRatio: 2
    )
    
    static let ambient = TrackEffectPreset(
        id: UUID(), name: "Ambient", reverbAmount: 0.6, delayAmount: 0.3,
        delayTime: 0.4, eqLow: -3, eqMid: 0, eqHigh: 2,
        compressorThreshold: -15, compressorRatio: 3
    )
    
    static let bright = TrackEffectPreset(
        id: UUID(), name: "Bright", reverbAmount: 0.2, delayAmount: 0.1,
        delayTime: 0.15, eqLow: -2, eqMid: 1, eqHigh: 4,
        compressorThreshold: -18, compressorRatio: 4
    )
    
    static let warm = TrackEffectPreset(
        id: UUID(), name: "Warm", reverbAmount: 0.3, delayAmount: 0,
        delayTime: 0, eqLow: 3, eqMid: 1, eqHigh: -2,
        compressorThreshold: -22, compressorRatio: 3
    )
    
    static let presets: [TrackEffectPreset] = [.clean, .ambient, .bright, .warm]
}

// MARK: - Overdub Support (P-05)

/// Manages recording while playing back existing tracks
class OverdubManager {
    private var playbackEngine: StudioPlaybackEngine?
    private var recorder: AVAudioRecorder?
    private(set) var isOverdubbing = false
    
    /// Start overdub: play existing tracks while recording new audio
    func startOverdub(
        playbackEngine: StudioPlaybackEngine,
        project: Project,
        outputURL: URL
    ) throws {
        self.playbackEngine = playbackEngine
        
        AudioSessionManager.shared.configureForOverdub()
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder?.prepareToRecord()
        recorder?.record()
        
        playbackEngine.play()
        isOverdubbing = true
    }
    
    func stopOverdub() -> URL? {
        let url = recorder?.url
        recorder?.stop()
        playbackEngine?.stop(resetPosition: false)
        isOverdubbing = false
        
        AudioSessionManager.shared.configureForPlayback()
        return url
    }
}

// MARK: - Punch-In/Out Support (P-08)

/// Defines a region for punch-in recording
struct PunchRegion {
    var startBeat: Double
    var endBeat: Double
    var isActive: Bool = false
    
    var duration: Double { endBeat - startBeat }
}

// MARK: - MIDI Import (P-04)

/// Basic MIDI file parser for importing chord progressions
class MIDIImporter {
    
    struct ImportedChord {
        let root: String
        let quality: ChordQuality
        let startBeat: Double
        let duration: Double
    }
    
    /// Parse a MIDI file and extract chord events
    static func importMIDI(from url: URL) -> [ImportedChord]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard data.count > 14 else { return nil }
        
        // Verify MIDI header
        let header = String(data: data[0..<4], encoding: .ascii)
        guard header == "MThd" else { return nil }
        
        // Read ticks per quarter note
        let ticksPerQuarter = Int(data[12]) << 8 | Int(data[13])
        guard ticksPerQuarter > 0 else { return nil }
        
        // Simple: find all Note On events and group simultaneous ones as chords
        var noteEvents: [(tick: Int, note: UInt8, velocity: UInt8, isOn: Bool)] = []
        var pos = 14  // After header
        
        while pos < data.count - 4 {
            // Find track headers
            if data[pos] == 0x4D && data[pos+1] == 0x54 &&
               data[pos+2] == 0x72 && data[pos+3] == 0x6B {
                let trackLen = Int(data[pos+4]) << 24 | Int(data[pos+5]) << 16 |
                               Int(data[pos+6]) << 8 | Int(data[pos+7])
                pos += 8
                let trackEnd = min(pos + trackLen, data.count)
                var currentTick = 0
                var runningStatus: UInt8 = 0
                
                while pos < trackEnd {
                    // Read delta time
                    var delta = 0
                    while pos < trackEnd {
                        let byte = data[pos]
                        pos += 1
                        delta = (delta << 7) | Int(byte & 0x7F)
                        if byte & 0x80 == 0 { break }
                    }
                    currentTick += delta
                    
                    guard pos < trackEnd else { break }
                    var status = data[pos]
                    
                    if status & 0x80 != 0 {
                        runningStatus = status
                        pos += 1
                    } else {
                        status = runningStatus
                    }
                    
                    guard pos < trackEnd else { break }
                    
                    let type = status & 0xF0
                    switch type {
                    case 0x90: // Note On
                        let note = data[pos]; pos += 1
                        guard pos < trackEnd else { break }
                        let vel = data[pos]; pos += 1
                        noteEvents.append((currentTick, note, vel, vel > 0))
                    case 0x80: // Note Off
                        let note = data[pos]; pos += 1
                        guard pos < trackEnd else { break }
                        pos += 1 // velocity
                        noteEvents.append((currentTick, note, 0, false))
                    case 0xFF: // Meta event
                        guard pos < trackEnd else { break }
                        pos += 1 // meta type
                        guard pos < trackEnd else { break }
                        let len = Int(data[pos]); pos += 1
                        pos += len
                    case 0xC0, 0xD0: // Program change, channel pressure (1 byte)
                        pos += 1
                    default: // Other 2-byte events
                        pos += 2
                    }
                }
            } else {
                pos += 1
            }
        }
        
        // Group note-ons by tick into chords
        return groupNotesIntoChords(noteEvents, ticksPerQuarter: ticksPerQuarter)
    }
    
    private static func groupNotesIntoChords(_ events: [(tick: Int, note: UInt8, velocity: UInt8, isOn: Bool)],
                                              ticksPerQuarter: Int) -> [ImportedChord] {
        let noteOns = events.filter { $0.isOn && $0.velocity > 0 }
        guard !noteOns.isEmpty else { return [] }
        
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // Group by tick (within small window)
        var groups: [[UInt8]] = []
        var groupTicks: [Int] = []
        var currentGroup: [UInt8] = []
        var lastTick = -1000
        
        for event in noteOns.sorted(by: { $0.tick < $1.tick }) {
            if event.tick - lastTick > ticksPerQuarter / 8 {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    groupTicks.append(lastTick)
                }
                currentGroup = [event.note]
            } else {
                currentGroup.append(event.note)
            }
            lastTick = event.tick
        }
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
            groupTicks.append(lastTick)
        }
        
        // Identify chords from note groups
        var chords: [ImportedChord] = []
        for (i, group) in groups.enumerated() {
            let pitchClasses = Set(group.map { Int($0) % 12 }).sorted()
            guard let root = pitchClasses.first else { continue }
            let rootName = noteNames[root]
            
            // Simple chord identification by intervals
            let intervals = pitchClasses.map { ($0 - root + 12) % 12 }
            let quality: ChordQuality
            if intervals.contains(4) && intervals.contains(7) { quality = .major }
            else if intervals.contains(3) && intervals.contains(7) { quality = .minor }
            else if intervals.contains(3) && intervals.contains(6) { quality = .diminished }
            else if intervals.contains(4) && intervals.contains(8) { quality = .augmented }
            else { quality = .major }
            
            let startBeat = Double(groupTicks[i]) / Double(ticksPerQuarter)
            let duration: Double = if i + 1 < groupTicks.count {
                Double(groupTicks[i + 1] - groupTicks[i]) / Double(ticksPerQuarter)
            } else {
                1.0
            }
            
            chords.append(ImportedChord(root: rootName, quality: quality,
                                        startBeat: startBeat, duration: max(0.25, duration)))
        }
        
        return chords
    }
}

// MARK: - Stereo Recording (P-07)

extension AudioRecordingManager {
    /// Configure for stereo recording if available
    static func stereoRecordingSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
    }
    
    /// Check if stereo input is available
    static var isStereoInputAvailable: Bool {
        let session = AVAudioSession.sharedInstance()
        return session.inputNumberOfChannels >= 2
    }
}
