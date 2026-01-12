import Foundation
import AVFoundation
import AudioToolbox
import SwiftData
import Combine

@MainActor
final class StudioPlaybackEngine: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentBeat: Double = 0
    @Published private(set) var totalBeats: Double = 0

    private var engine = AVAudioEngine()
    private var sequencer: AVAudioSequencer?
    private var samplerNodes: [UUID: AVAudioUnitSampler] = [:]
    private var audioNodes: [UUID: AVAudioPlayerNode] = [:]
    private var mixerNodes: [UUID: AVAudioMixerNode] = [:]
    private var audioTrackInfo: [UUID: (url: URL, startBeat: Double)] = [:]
    private var bpm: Double = 120
    private var beatScale: Double = 1.0
    private var gridBeatInterval: Double = 0.5
    private var playheadTimer: Timer?
    private var customBankStatus: CustomBankStatus = .unknown

    private enum CustomBankStatus {
        case unknown
        case available(URL)
        case unavailable
    }

    func prepare(project: Project) {
        bpm = project.quarterNoteBpm()
        beatScale = 4.0 / Double(project.timeBottom)
        gridBeatInterval = project.gridBeatInterval()
        totalBeats = timelineBeats(for: project)
        if sequencer == nil {
            rebuildSequence(project: project)
        }
    }

    func rebuildSequence(project: Project) {
        stop(resetPosition: false)
        sequencer = nil
        teardownEngine()

        bpm = project.quarterNoteBpm()
        beatScale = 4.0 / Double(project.timeBottom)
        gridBeatInterval = project.gridBeatInterval()
        totalBeats = timelineBeats(for: project)
        currentBeat = min(currentBeat, totalBeats)

        configureAudioSession()
        engine = AVAudioEngine()
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        guard outputFormat.sampleRate > 0, outputFormat.channelCount > 0 else {
            print("Studio playback output unavailable.")
            return
        }

        let activeTracks = resolvedTracks(from: project)
        attachSamplers(for: activeTracks)
        attachAudioNodes(for: activeTracks, project: project)
        connectOutputIfNeeded(outputFormat: outputFormat)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            print("Studio playback engine failed to start: \(error)")
            return
        }

        sequencer = AVAudioSequencer(audioEngine: engine)
        buildSequence(for: activeTracks)
    }

    func play() {
        guard let sequencer else { return }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Studio playback engine failed to start: \(error)")
            }
        }

        scheduleAudioTracks(startBeat: currentBeat)
        sequencer.currentPositionInBeats = currentBeat * beatScale

        do {
            try sequencer.start()
            isPlaying = true
            startPlayheadTimer()
        } catch {
            print("Failed to start sequencer: \(error)")
        }
    }

    func pause() {
        stop(resetPosition: false)
    }

    func stop(resetPosition: Bool = false) {
        sequencer?.stop()
        for node in audioNodes.values {
            node.stop()
        }
        isPlaying = false
        stopPlayheadTimer()

        let position = sequencer?.currentPositionInBeats ?? (currentBeat * beatScale)
        currentBeat = resetPosition ? 0 : (position / beatScale)
        if resetPosition {
            sequencer?.currentPositionInBeats = 0
        }
    }

    func seek(to beat: Double) {
        let clamped = max(0, min(beat, totalBeats))
        currentBeat = clamped
        sequencer?.currentPositionInBeats = clamped * beatScale

        if isPlaying {
            stop(resetPosition: false)
            play()
        }
    }
    
    func updateTrackMix(trackId: UUID, volume: Float, pan: Float) {
        guard let mixer = mixerNodes[trackId] else { return }
        mixer.outputVolume = volume
        mixer.pan = pan
    }

    private func resolvedTracks(from project: Project) -> [StudioTrack] {
        let solos = project.studioTracks.filter { $0.isSolo }
        let active = solos.isEmpty ? project.studioTracks.filter { !$0.isMuted } : solos
        return active.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    private func teardownEngine() {
        engine.stop()
        engine.reset()
        samplerNodes.values.forEach { engine.detach($0) }
        audioNodes.values.forEach { engine.detach($0) }
        mixerNodes.values.forEach { engine.detach($0) }
        samplerNodes.removeAll()
        audioNodes.removeAll()
        mixerNodes.removeAll()
        audioTrackInfo.removeAll()
        stopPlayheadTimer()
    }

    private func connectOutputIfNeeded(outputFormat: AVAudioFormat) {
        let connections = engine.outputConnectionPoints(for: engine.mainMixerNode, outputBus: 0)
        guard connections.isEmpty else { return }
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
    }

    private func attachSamplers(for tracks: [StudioTrack]) {
        for track in tracks where !track.instrument.isAudio {
            let sampler = AVAudioUnitSampler()
            let mixer = AVAudioMixerNode()
            
            engine.attach(sampler)
            engine.attach(mixer)
            
            // Connect: sampler -> mixer -> main
            engine.connect(sampler, to: mixer, format: nil)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
            
            // Apply volume and pan
            mixer.outputVolume = track.volume
            mixer.pan = track.pan
            
            samplerNodes[track.id] = sampler
            mixerNodes[track.id] = mixer
            loadInstrument(for: track, sampler: sampler)
        }
    }

    private func attachAudioNodes(for tracks: [StudioTrack], project: Project) {
        for track in tracks where track.instrument.isAudio {
            let node = AVAudioPlayerNode()
            let mixer = AVAudioMixerNode()
            
            engine.attach(node)
            engine.attach(mixer)
            
            // Connect: player -> mixer -> main
            var inputFormat: AVAudioFormat?
            
            // Apply volume and pan
            mixer.outputVolume = track.volume
            mixer.pan = track.pan
            
            audioNodes[track.id] = node
            mixerNodes[track.id] = mixer

            if let recordingId = track.audioRecordingId,
               let recording = project.recordings.first(where: { $0.id == recordingId }) {
                if let url = FileManagerUtils.existingRecordingURL(for: recording.fileName) {
                    audioTrackInfo[track.id] = (url, track.audioStartBeat)
                    if let file = try? AVAudioFile(forReading: url) {
                        inputFormat = file.processingFormat
                    }
                } else {
                    print("Recording file not found for: \(recording.fileName)")
                }
            }

            engine.connect(node, to: mixer, format: inputFormat)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        }
    }

    private func buildSequence(for tracks: [StudioTrack]) {
        guard let sequencer else { return }

        for track in tracks where !track.instrument.isAudio {
            guard let sampler = samplerNodes[track.id] else { continue }
            let musicTrack = sequencer.createAndAppendTrack()

            musicTrack.destinationAudioUnit = sampler
            addNotes(track.notes, to: musicTrack, channel: midiChannel(for: track.instrument))
        }

        if bpm > 0 {
            sequencer.rate = Float(bpm / 120.0)
        }
        sequencer.prepareToPlay()
    }

    private func addNotes(_ notes: [StudioNote], to track: AVMusicTrack, channel: UInt8) {
        let ordered = notes.sorted { $0.startBeat < $1.startBeat }
        for note in ordered {
            let key = UInt32(max(0, min(note.pitch, 127)))
            let velocity = UInt32(max(0, min(note.velocity, 127)))
            let message = AVMIDINoteEvent(
                channel: UInt32(channel),
                key: key,
                velocity: velocity,
                duration: note.duration * beatScale
            )
            track.addEvent(message, at: note.startBeat * beatScale)
        }
    }

    private func scheduleAudioTracks(startBeat: Double) {
        let beatDuration = gridBeatInterval

        for (trackId, node) in audioNodes {
            guard let info = audioTrackInfo[trackId] else { continue }
            let url = info.url

            do {
                let file = try AVAudioFile(forReading: url)
                let offsetSeconds = (startBeat - info.startBeat) * beatDuration
                let sampleRate = file.processingFormat.sampleRate
                node.stop()
                if offsetSeconds >= 0 {
                    let startFrame = AVAudioFramePosition(offsetSeconds * sampleRate)
                    let remainingFrames = max(0, file.length - startFrame)
                    if remainingFrames > 0 {
                        node.scheduleSegment(
                            file,
                            startingFrame: startFrame,
                            frameCount: AVAudioFrameCount(remainingFrames),
                            at: nil
                        )
                        node.play()
                    }
                } else {
                    let delay = abs(offsetSeconds)
                    node.scheduleFile(file, at: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        node.play()
                    }
                }
            } catch {
                print("Failed to load audio file: \(error)")
            }
        }
    }

    private func startPlayheadTimer() {
        stopPlayheadTimer()
        playheadTimer = Timer.scheduledTimer(
            timeInterval: 0.05,
            target: self,
            selector: #selector(handlePlayheadTick),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopPlayheadTimer() {
        playheadTimer?.invalidate()
        playheadTimer = nil
    }

    @objc private func handlePlayheadTick() {
        guard let sequencer else { return }
        let position = sequencer.currentPositionInBeats / beatScale
        currentBeat = position
        if totalBeats > 0, position >= totalBeats {
            stop(resetPosition: true)
        }
    }

    private func loadInstrument(for track: StudioTrack, sampler: AVAudioUnitSampler) {
        // Use variant's MIDI program if available, otherwise default
        let fallbackProgram = track.variant?.midiProgram ?? programNumber(for: track.instrument)
        let customURL = resolvedCustomBankURL()
        let program = resolvedProgram(
            for: track,
            customBankURL: customURL,
            fallbackProgram: fallbackProgram
        )

        if let url = customURL {
            let logFailure: Bool
            if case .unknown = customBankStatus {
                logFailure = true
            } else {
                logFailure = false
            }
            if attemptLoad(
                sampler,
                url: url,
                program: program,
                bankMSB: appleBankMSB(for: track.instrument),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB),
                logFailure: logFailure
            ) {
                customBankStatus = .available(url)
                return
            }
            customBankStatus = .unavailable
        }

        if let systemURL = systemSoundBankURL() {
            _ = attemptLoad(
                sampler,
                url: systemURL,
                program: fallbackProgram,
                bankMSB: appleBankMSB(for: track.instrument),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB),
                logFailure: false
            )
        }
    }

    private func midiChannel(for instrument: StudioInstrument) -> UInt8 {
        instrument == .drums ? 9 : 0
    }

    private func programNumber(for instrument: StudioInstrument) -> UInt8 {
        switch instrument {
        case .piano:
            return 0  // Acoustic Grand Piano
        case .synth:
            return 89 // Warm Pad
        case .guitar:
            return 26 // Electric Guitar (jazz) for cleaner tuning
        case .bass:
            return 32 // Acoustic Bass
        case .drums, .audio:
            return 0
        }
    }

    private func generalSoundFontURL() -> URL? {
        let candidates = [
            "Arachno",
            "Arachno SoundFont - Version 1.0"
        ]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "sf2") {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: "sf2", subdirectory: "SoundFonts") {
                return url
            }
        }
        return nil
    }

    private func resolvedProgram(
        for track: StudioTrack,
        customBankURL: URL?,
        fallbackProgram: UInt8
    ) -> UInt8 {
        guard track.instrument == .guitar,
              let variant = track.variant,
              let customBankURL,
              isArachnoSoundFont(customBankURL) else {
            return fallbackProgram
        }

        // Arachno's nylon/jazz guitars are reported as detuned; use alternate programs.
        switch variant {
        case .acousticGuitar:
            return 25 // Acoustic Guitar (steel)
        case .cleanGuitar:
            return 28 // Electric Guitar (muted)
        case .electricGuitar:
            return fallbackProgram
        default:
            return fallbackProgram
        }
    }

    private func isArachnoSoundFont(_ url: URL) -> Bool {
        url.lastPathComponent.localizedCaseInsensitiveContains("arachno")
    }

    private func resolvedCustomBankURL() -> URL? {
        switch customBankStatus {
        case .available(let url):
            return url
        case .unavailable:
            return nil
        case .unknown:
            if let url = generalSoundFontURL() {
                return url
            }
            customBankStatus = .unavailable
            return nil
        }
    }

    private func attemptLoad(
        _ sampler: AVAudioUnitSampler,
        url: URL,
        program: UInt8,
        bankMSB: UInt8,
        bankLSB: UInt8,
        logFailure: Bool
    ) -> Bool {
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: bankMSB,
                bankLSB: bankLSB
            )
            return true
        } catch {
            if logFailure {
                print("Failed to load sound bank \(url.lastPathComponent): \(error)")
            }
            return false
        }
    }

    private func appleBankMSB(for instrument: StudioInstrument) -> UInt8 {
        instrument == .drums ? UInt8(kAUSampler_DefaultPercussionBankMSB) : UInt8(kAUSampler_DefaultMelodicBankMSB)
    }

    private func systemSoundBankURL() -> URL? {
        let possiblePaths = [
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
            "/System/Library/Audio/Units/gs_instruments.dls"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func timelineBeats(for project: Project) -> Double {
        let bars = project.arrangementItems
            .compactMap { $0.sectionTemplate?.bars }
            .reduce(0, +)
        return Double(max(1, bars * project.timeTop))
    }
}
