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

    private struct BeatClock {
        var bpm: Double
        var timeBottom: Int

        // Sequencer uses quarter-note beats; UI uses timeBottom as the beat unit.
        var beatScale: Double { 4.0 / Double(timeBottom) }
        var uiBeatSeconds: Double { (60.0 / bpm) * beatScale }

        func uiBeatToSequencerBeat(_ uiBeat: Double) -> Double { uiBeat * beatScale }
        func sequencerBeatToUiBeat(_ beat: Double) -> Double { beat / beatScale }
    }

    private struct AudioTrackInfo {
        let url: URL
        let startBeat: Double
        let file: AVAudioFile
        let format: AVAudioFormat
        let sampleRate: Double
        let length: AVAudioFramePosition
    }

    private struct TrackMixState {
        var volume: Float
        var pan: Float
        var isMuted: Bool
        var isSolo: Bool
    }

    private var engine = AVAudioEngine()
    private var sequencer: AVAudioSequencer?
    private var samplerNodes: [UUID: AVAudioUnitSampler] = [:]
    private var audioNodes: [UUID: AVAudioPlayerNode] = [:]
    private var mixerNodes: [UUID: AVAudioMixerNode] = [:]
    private var audioTrackInfo: [UUID: AudioTrackInfo] = [:]
    private var trackMixState: [UUID: TrackMixState] = [:]
    private var bpm: Double = 120
    private var beatScale: Double = 1.0
    private var beatClock = BeatClock(bpm: 120, timeBottom: 4)
    private var playheadTimer: Timer?
    private var customBankStatus: CustomBankStatus = .unknown
    private var drumBankMode: [UUID: Bool] = [:] // true = melodic bank, false = percussion bank

    private enum CustomBankStatus {
        case unknown
        case available(URL)
        case unavailable
    }

    func prepare(project: Project) {
        updateBeatClock(for: project)
        totalBeats = timelineBeats(for: project)
        if sequencer == nil {
            rebuildSequence(project: project)
        }
    }

    func rebuildSequence(project: Project) {
        stop(resetPosition: false)
        sequencer = nil
        teardownEngine()
        drumBankMode.removeAll()

        updateBeatClock(for: project)
        totalBeats = timelineBeats(for: project)
        currentBeat = min(currentBeat, totalBeats)

        configureAudioSession()
        engine = AVAudioEngine()
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        guard outputFormat.sampleRate > 0, outputFormat.channelCount > 0 else {
            print("Studio playback output unavailable.")
            return
        }

        let allTracks = resolvedTracks(from: project)
        attachSamplers(for: allTracks)
        attachAudioNodes(for: allTracks, project: project)
        connectOutputIfNeeded(outputFormat: outputFormat)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            print("Studio playback engine failed to start: \(error)")
            return
        }

        sequencer = AVAudioSequencer(audioEngine: engine)
        buildSequence(for: allTracks)
        applyMixState(project: project)
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
        sequencer.currentPositionInBeats = beatClock.uiBeatToSequencerBeat(currentBeat)

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

        let position = sequencer?.currentPositionInBeats ?? beatClock.uiBeatToSequencerBeat(currentBeat)
        currentBeat = resetPosition ? 0 : beatClock.sequencerBeatToUiBeat(position)
        if resetPosition {
            sequencer?.currentPositionInBeats = 0
        }
    }

    func seek(to beat: Double) {
        let clamped = max(0, min(beat, totalBeats))
        currentBeat = clamped
        sequencer?.currentPositionInBeats = beatClock.uiBeatToSequencerBeat(clamped)

        if isPlaying {
            stop(resetPosition: false)
            play()
        }
    }
    
    func updateTrackMix(trackId: UUID, volume: Float, pan: Float) {
        guard var mixState = trackMixState[trackId] else { return }
        mixState.volume = volume
        mixState.pan = pan
        trackMixState[trackId] = mixState
        applyMixStateFromCache()
    }

    func applyMixState(project: Project) {
        for track in project.studioTracks {
            let state = TrackMixState(
                volume: track.volume,
                pan: track.pan,
                isMuted: track.isMuted,
                isSolo: track.isSolo
            )
            trackMixState[track.id] = state
        }
        applyMixStateFromCache()
    }

    func updateProject(_ project: Project) {
        updateBeatClock(for: project)
        totalBeats = timelineBeats(for: project)
        applyMixState(project: project)
    }

    private func resolvedTracks(from project: Project) -> [StudioTrack] {
        project.studioTracks.sorted { $0.orderIndex < $1.orderIndex }
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
        sequencer?.stop()
        for node in audioNodes.values {
            node.stop()
        }
        engine.stop()
        samplerNodes.values.forEach { engine.detach($0) }
        audioNodes.values.forEach { engine.detach($0) }
        mixerNodes.values.forEach { engine.detach($0) }
        engine.reset()
        samplerNodes.removeAll()
        audioNodes.removeAll()
        mixerNodes.removeAll()
        audioTrackInfo.removeAll()
        trackMixState.removeAll()
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
            trackMixState[track.id] = TrackMixState(
                volume: track.volume,
                pan: track.pan,
                isMuted: track.isMuted,
                isSolo: track.isSolo
            )
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
            trackMixState[track.id] = TrackMixState(
                volume: track.volume,
                pan: track.pan,
                isMuted: track.isMuted,
                isSolo: track.isSolo
            )

            if let recordingId = track.audioRecordingId,
               let recording = project.recordings.first(where: { $0.id == recordingId }) {
                if let url = FileManagerUtils.existingRecordingURL(for: recording.fileName) {
                    if let file = try? AVAudioFile(forReading: url) {
                        inputFormat = file.processingFormat
                        audioTrackInfo[track.id] = AudioTrackInfo(
                            url: url,
                            startBeat: track.audioStartBeat,
                            file: file,
                            format: file.processingFormat,
                            sampleRate: file.processingFormat.sampleRate,
                            length: file.length
                        )
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
            addNotes(track.notes, to: musicTrack, channel: midiChannel(for: track))
        }

        configureTempoTrack(for: sequencer)
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
        // UI beats are timeBottom-based; convert to seconds using the project's BPM + meter.
        let uiBeatSeconds = beatClock.uiBeatSeconds

        for (trackId, node) in audioNodes {
            guard let info = audioTrackInfo[trackId] else { continue }
            let offsetSeconds = (startBeat - info.startBeat) * uiBeatSeconds
            let sampleRate = info.sampleRate
            node.stop()

            if offsetSeconds >= 0 {
                let startFrame = AVAudioFramePosition(offsetSeconds * sampleRate)
                let remainingFrames = max(0, info.length - startFrame)
                guard remainingFrames > 0 else { continue }
                let startTime = hostTime(after: 0)
                node.scheduleSegment(
                    info.file,
                    startingFrame: startFrame,
                    frameCount: AVAudioFrameCount(remainingFrames),
                    at: startTime
                )
                play(node, at: startTime)
            } else {
                let delay = abs(offsetSeconds)
                let startTime = hostTime(after: delay)
                node.scheduleSegment(
                    info.file,
                    startingFrame: 0,
                    frameCount: AVAudioFrameCount(info.length),
                    at: startTime
                )
                play(node, at: startTime)
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
        let position = beatClock.sequencerBeatToUiBeat(sequencer.currentPositionInBeats)
        currentBeat = position
        if totalBeats > 0, position >= totalBeats {
            stop(resetPosition: true)
        }
    }

    private func loadInstrument(for track: StudioTrack, sampler: AVAudioUnitSampler) {
        let fallbackProgram = track.variant?.midiProgram ?? programNumber(for: track.instrument)
        if let url = SoundFontManager.soundFontURL(for: track.instrument, variant: track.variant) {
            let logFailure: Bool
            if case .unknown = customBankStatus {
                logFailure = true
            } else {
                logFailure = false
            }
            var primaryBankMSB: UInt8 = UInt8(kAUSampler_DefaultMelodicBankMSB)
            if track.instrument == .drums {
                primaryBankMSB = SoundFontManager.usesPercussionBank(for: track.variant)
                    ? UInt8(kAUSampler_DefaultPercussionBankMSB)
                    : UInt8(kAUSampler_DefaultMelodicBankMSB)
            }
            if attemptLoad(
                sampler,
                url: url,
                program: fallbackProgram,
                bankMSB: primaryBankMSB,
                bankLSB: UInt8(kAUSampler_DefaultBankLSB),
                logFailure: logFailure
            ) {
                if track.instrument == .drums {
                    if primaryBankMSB == UInt8(kAUSampler_DefaultMelodicBankMSB) {
                        drumBankMode[track.id] = true
                    } else {
                        drumBankMode[track.id] = false
                    }
                }
                customBankStatus = .available(url)
                return
            }
            if track.instrument == .drums {
                let fallbackBankMSB = primaryBankMSB == UInt8(kAUSampler_DefaultPercussionBankMSB)
                    ? UInt8(kAUSampler_DefaultMelodicBankMSB)
                    : UInt8(kAUSampler_DefaultPercussionBankMSB)
                if attemptLoad(
                    sampler,
                    url: url,
                    program: fallbackProgram,
                    bankMSB: fallbackBankMSB,
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB),
                    logFailure: logFailure
                ) {
                    if fallbackBankMSB == UInt8(kAUSampler_DefaultMelodicBankMSB) {
                        drumBankMode[track.id] = true
                    } else {
                        drumBankMode[track.id] = false
                    }
                    customBankStatus = .available(url)
                    return
                }
            }
            if track.instrument == .drums {
                #if DEBUG
                print("❌ Drum soundfont failed to load: \(url.lastPathComponent)")
                #endif
            }
            if case .unknown = customBankStatus {
                customBankStatus = .unavailable
            }
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

    private func midiChannel(for track: StudioTrack) -> UInt8 {
        guard track.instrument == .drums else { return 0 }
        let usesMelodicBank = drumBankMode[track.id] ?? false
        return usesMelodicBank ? 0 : 9
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
        case .strings:
            return 48 // String Ensemble
        case .brass:
            return 61 // Brass Section
        case .woodwinds:
            return 73 // Flute
        case .organ:
            return 16 // Drawbar Organ
        case .mallets:
            return 12 // Marimba
        case .drums, .audio:
            return 0
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

    private func updateBeatClock(for project: Project) {
        bpm = project.quarterNoteBpm()
        beatClock = BeatClock(bpm: bpm, timeBottom: project.timeBottom)
        beatScale = beatClock.beatScale
    }

    private func configureTempoTrack(for sequencer: AVAudioSequencer) {
        guard bpm > 0 else { return }
        let tempoTrack = sequencer.tempoTrack
        if tempoTrack.lengthInBeats > 0 {
            tempoTrack.clearEvents(in: AVMakeBeatRange(0, AVMusicTimeStampEndOfTrack))
        }
        let tempoEvent = AVExtendedTempoEvent(tempo: bpm)
        tempoTrack.addEvent(tempoEvent, at: 0)
        sequencer.rate = 1
    }

    private func applyMixStateFromCache() {
        let soloed = trackMixState.values.contains { $0.isSolo }
        for (trackId, mixState) in trackMixState {
            guard let mixer = mixerNodes[trackId] else { continue }
            let effectiveMuted = mixState.isMuted || (soloed && !mixState.isSolo)
            // Apply mute/solo live without rebuilding.
            mixer.outputVolume = effectiveMuted ? 0 : mixState.volume
            mixer.pan = mixState.pan
        }
    }

    private func hostTime(after delaySeconds: Double) -> AVAudioTime? {
        guard let nodeTime = engine.outputNode.lastRenderTime else { return nil }
        let hostTime = nodeTime.hostTime + AVAudioTime.hostTime(forSeconds: delaySeconds)
        // Host-time scheduling keeps audio start sample-accurate.
        return AVAudioTime(hostTime: hostTime)
    }

    private func play(_ node: AVAudioPlayerNode, at time: AVAudioTime?) {
        if let time {
            node.play(at: time)
        } else {
            node.play()
        }
    }
}
