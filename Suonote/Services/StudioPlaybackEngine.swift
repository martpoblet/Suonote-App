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
    
    // Loop/Cycle playback (P-06)
    @Published var isLooping: Bool = false
    @Published var loopStartBeat: Double = 0
    @Published var loopEndBeat: Double? = nil  // nil = loop entire arrangement

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
    private var reverbNodes: [UUID: AVAudioUnitReverb] = [:]
    private var delayNodes: [UUID: AVAudioUnitDelay] = [:]
    private var eqNodes: [UUID: AVAudioUnitEQ] = [:]
    private var compressorNodes: [UUID: AVAudioUnitEffect] = [:]
    private var masterLimiter: AVAudioUnitEffect?
    private var metronomePlayer: AVAudioPlayerNode?
    private var metronomeBuffer: AVAudioPCMBuffer?
    @Published var isMetronomeEnabled: Bool = false
    @Published var metronomeVolume: Float = 0.5
    @Published var countInBars: Int = 0  // 0 = no count-in, 1 or 2
    private var audioTrackInfo: [UUID: AudioTrackInfo] = [:]
    private var trackMixState: [UUID: TrackMixState] = [:]
    private var bpm: Double = 120
    private var beatScale: Double = 1.0
    private var currentBeatsPerBar: Int = 4
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
    
    /// Incremental rebuild: only update MIDI sequence data without tearing down engine (A-06)
    /// Falls back to full rebuild if engine topology changed
    func rebuildSequenceIncremental(project: Project) {
        let allTracks = resolvedTracks(from: project)
        let currentSamplerIds = Set(samplerNodes.keys)
        let currentAudioIds = Set(audioNodes.keys)
        let newMidiIds = Set(allTracks.filter { $0.audioRecordingId == nil }.map { $0.id })
        let newAudioIds = Set(allTracks.filter { $0.audioRecordingId != nil }.map { $0.id })
        
        // If track topology changed, do full rebuild
        guard currentSamplerIds == newMidiIds && currentAudioIds == newAudioIds else {
            rebuildSequence(project: project)
            return
        }
        
        // Just rebuild the MIDI sequence in-place
        let wasPlaying = isPlaying
        let savedBeat = currentBeat
        
        stop(resetPosition: false)
        updateBeatClock(for: project)
        totalBeats = timelineBeats(for: project)
        
        sequencer = AVAudioSequencer(audioEngine: engine)
        buildSequence(for: allTracks)
        applyMixState(project: project)
        
        currentBeat = min(savedBeat, totalBeats)
        sequencer?.currentPositionInBeats = beatClock.uiBeatToSequencerBeat(currentBeat)
        
        if wasPlaying { play() }
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
        stopPlayheadTimer()
        isPlaying = false
        
        if resetPosition {
            currentBeat = 0
        }
        
        sequencer?.stop()
        for node in audioNodes.values {
            node.stop()
        }
        
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
        if var mixState = trackMixState[trackId] {
            mixState.volume = volume
            mixState.pan = pan
            trackMixState[trackId] = mixState
        } else {
            // Engine not yet built — seed the state so the next rebuild picks it up
            trackMixState[trackId] = TrackMixState(volume: volume, pan: pan, isMuted: false, isSolo: false)
        }
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
            applyEffects(for: track)
        }
        applyMixStateFromCache()
    }

    func updateTrackEffects(track: StudioTrack) {
        applyEffects(for: track)
    }

    private func applyEffects(for track: StudioTrack) {
        let trackId = track.id
        if let reverb = reverbNodes[trackId] {
            if let preset = AVAudioUnitReverbPreset(rawValue: track.reverbPreset.avPreset) {
                reverb.loadFactoryPreset(preset)
            }
            reverb.wetDryMix = track.reverbEnabled ? track.reverbMix * 100 : 0
        }
        if let delay = delayNodes[trackId] {
            delay.wetDryMix = track.delayEnabled ? track.delayMix * 100 : 0
            if track.delaySyncMode == .free {
                delay.delayTime = TimeInterval(track.delayTime)
            } else {
                delay.delayTime = track.delaySyncMode.delayTime(bpm: bpm)
            }
        }
        if let eq = eqNodes[trackId] {
            configureEQ(eq, track: track)
        }
    }

    // Legacy compatibility
    func updateTrackEffects(trackId: UUID, reverbEnabled: Bool, reverbMix: Float, delayEnabled: Bool, delayTime: Float, delayMix: Float) {
        if let reverb = reverbNodes[trackId] {
            reverb.wetDryMix = reverbEnabled ? reverbMix * 100 : 0
        }
        if let delay = delayNodes[trackId] {
            delay.wetDryMix = delayEnabled ? delayMix * 100 : 0
            delay.delayTime = TimeInterval(delayTime)
        }
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
        reverbNodes.values.forEach { engine.detach($0) }
        delayNodes.values.forEach { engine.detach($0) }
        eqNodes.values.forEach { engine.detach($0) }
        compressorNodes.values.forEach { engine.detach($0) }
        mixerNodes.values.forEach { engine.detach($0) }
        if let limiter = masterLimiter { engine.detach(limiter); masterLimiter = nil }
        if let metro = metronomePlayer { engine.detach(metro); metronomePlayer = nil }
        engine.reset()
        samplerNodes.removeAll()
        audioNodes.removeAll()
        reverbNodes.removeAll()
        delayNodes.removeAll()
        eqNodes.removeAll()
        compressorNodes.removeAll()
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
            let reverb = AVAudioUnitReverb()
            let delay = AVAudioUnitDelay()
            let eq = AVAudioUnitEQ(numberOfBands: 3)
            
            engine.attach(sampler)
            engine.attach(eq)
            engine.attach(reverb)
            engine.attach(delay)
            engine.attach(mixer)
            
            // Chain: sampler -> EQ -> reverb -> delay -> mixer -> main
            engine.connect(sampler, to: eq, format: nil)
            engine.connect(eq, to: reverb, format: nil)
            engine.connect(reverb, to: delay, format: nil)
            engine.connect(delay, to: mixer, format: nil)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
            
            // Configure reverb
            if let preset = AVAudioUnitReverbPreset(rawValue: track.reverbPreset.avPreset) {
                reverb.loadFactoryPreset(preset)
            }
            reverb.wetDryMix = track.reverbEnabled ? track.reverbMix * 100 : 0
            
            // Configure delay
            let effectiveDelayTime: TimeInterval
            if track.delaySyncMode == .free {
                effectiveDelayTime = TimeInterval(track.delayTime)
            } else {
                effectiveDelayTime = track.delaySyncMode.delayTime(bpm: bpm)
            }
            delay.wetDryMix = track.delayEnabled ? track.delayMix * 100 : 0
            delay.delayTime = effectiveDelayTime
            delay.feedback = 30
            
            // Configure 3-band EQ (low 250Hz, mid 1kHz, high 4kHz)
            configureEQ(eq, track: track)
            
            // Apply volume and pan
            mixer.outputVolume = track.volume
            mixer.pan = track.pan
            
            samplerNodes[track.id] = sampler
            mixerNodes[track.id] = mixer
            reverbNodes[track.id] = reverb
            delayNodes[track.id] = delay
            eqNodes[track.id] = eq
            trackMixState[track.id] = TrackMixState(
                volume: track.volume,
                pan: track.pan,
                isMuted: track.isMuted,
                isSolo: track.isSolo
            )
            loadInstrument(for: track, sampler: sampler)
        }
        // Attach master limiter
        setupMasterLimiter()
    }

    private func configureEQ(_ eq: AVAudioUnitEQ, track: StudioTrack) {
        let bands = eq.bands
        guard bands.count >= 3 else { return }
        bands[0].filterType = .lowShelf
        bands[0].frequency = 250
        bands[0].gain = track.eqEnabled ? track.eqLowGain : 0
        bands[0].bypass = false
        bands[1].filterType = .parametric
        bands[1].frequency = 1000
        bands[1].bandwidth = 1.0
        bands[1].gain = track.eqEnabled ? track.eqMidGain : 0
        bands[1].bypass = false
        bands[2].filterType = .highShelf
        bands[2].frequency = 4000
        bands[2].gain = track.eqEnabled ? track.eqHighGain : 0
        bands[2].bypass = false
    }

    private func setupMasterLimiter() {
        guard masterLimiter == nil else { return }
        // Use AudioComponentDescription for a dynamics processor configured as limiter
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let limiter = AVAudioUnitEffect(audioComponentDescription: desc)
        engine.attach(limiter)
        // Insert between mainMixer and output
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.disconnectNodeOutput(engine.mainMixerNode)
        engine.connect(engine.mainMixerNode, to: limiter, format: format)
        engine.connect(limiter, to: engine.outputNode, format: format)
        masterLimiter = limiter
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

        // Add metronome track if enabled
        if isMetronomeEnabled {
            addMetronomeTrack(to: sequencer)
        }

        configureTempoTrack(for: sequencer)
        sequencer.prepareToPlay()
    }

    private func addMetronomeTrack(to sequencer: AVAudioSequencer) {
        let metroSampler = AVAudioUnitSampler()
        engine.attach(metroSampler)
        let metroMixer = AVAudioMixerNode()
        engine.attach(metroMixer)
        engine.connect(metroSampler, to: metroMixer, format: nil)
        engine.connect(metroMixer, to: engine.mainMixerNode, format: nil)
        metroMixer.outputVolume = metronomeVolume

        // Load using the app's SoundFont (percussion bank for click sounds)
        let loaded: Bool
        if let sfURL = SoundFontManager.soundFontURL(for: .drums, variant: nil) {
            loaded = attemptLoad(
                metroSampler, url: sfURL, program: 0,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB), logFailure: false
            ) || attemptLoad(
                metroSampler, url: sfURL, program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB), logFailure: false
            )
        } else if let sysURL = systemSoundBankURL() {
            loaded = attemptLoad(
                metroSampler, url: sysURL, program: 0,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB), logFailure: false
            )
        } else {
            loaded = false
        }
        guard loaded else {
            engine.detach(metroMixer)
            engine.detach(metroSampler)
            return
        }

        let musicTrack = sequencer.createAndAppendTrack()
        musicTrack.destinationAudioUnit = metroSampler

        // GM percussion: 76 = Hi Wood Block (accent), 77 = Lo Wood Block (normal)
        let accentNote: UInt32 = 76
        let normalNote: UInt32 = 77
        let totalSeqBeats = totalBeats * beatScale
        let seqBeatStep = beatScale
        var pos = 0.0
        var beatIndex = 0
        let beatsPerBar = max(1, currentBeatsPerBar)
        while pos < totalSeqBeats {
            let isDownbeat = beatIndex % beatsPerBar == 0
            let note = isDownbeat ? accentNote : normalNote
            let vel: UInt32 = isDownbeat ? 110 : 80
            let event = AVMIDINoteEvent(channel: 9, key: note, velocity: vel, duration: 0.1)
            musicTrack.addEvent(event, at: pos)
            pos += seqBeatStep
            beatIndex += 1
        }
    }

    private func addNotes(_ notes: [StudioNote], to track: AVMusicTrack, channel: UInt8) {
        for note in notes {
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

    /// Re-attach playhead timer if playing but timer was lost (e.g. view reappeared)
    func ensurePlayheadTimer() {
        guard isPlaying, playheadTimer == nil else { return }
        startPlayheadTimer()
    }

    private func startPlayheadTimer() {
        stopPlayheadTimer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.handlePlayheadTick()
            }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        playheadTimer = timer
    }

    private func stopPlayheadTimer() {
        playheadTimer?.invalidate()
        playheadTimer = nil
    }

    private func handlePlayheadTick() {
        guard let sequencer, isPlaying else { return }
        
        let position: Double
        do {
            let raw = sequencer.currentPositionInBeats
            position = beatClock.sequencerBeatToUiBeat(raw)
        }
        currentBeat = position
        
        // Loop/Cycle support (P-06)
        if isLooping {
            let end = loopEndBeat ?? totalBeats
            if end > 0, position >= end {
                seek(to: loopStartBeat)
                return
            }
        }
        
        if totalBeats > 0, position >= totalBeats {
            DispatchQueue.main.async { [weak self] in
                self?.stop(resetPosition: true)
            }
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
        currentBeatsPerBar = project.timeTop
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

    // MARK: - MIDI Export

    func exportMIDI(project: Project) -> URL? {
        let tracks = project.studioTracks
            .filter { !$0.instrument.isAudio }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard !tracks.isEmpty else { return nil }

        var musicSequence: MusicSequence?
        guard NewMusicSequence(&musicSequence) == noErr, let seq = musicSequence else { return nil }

        // Tempo track
        var tempoTrack: MusicTrack?
        MusicSequenceGetTempoTrack(seq, &tempoTrack)
        if let tempoTrack {
            MusicTrackNewExtendedTempoEvent(tempoTrack, 0, Float64(bpm))
        }

        for track in tracks {
            var mTrack: MusicTrack?
            MusicSequenceNewTrack(seq, &mTrack)
            guard let mTrack else { continue }

            let channel: UInt8 = track.instrument == .drums ? 9 : UInt8(track.orderIndex % 16)
            for note in track.notes {
                var msg = MIDINoteMessage(
                    channel: channel,
                    note: UInt8(max(0, min(127, note.pitch))),
                    velocity: UInt8(max(0, min(127, note.velocity))),
                    releaseVelocity: 0,
                    duration: Float32(note.duration * beatScale)
                )
                MusicTrackNewMIDINoteEvent(mTrack, note.startBeat * beatScale, &msg)
            }
        }

        let fileName = "\(project.title.replacingOccurrences(of: " ", with: "_"))_studio.mid"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)

        guard MusicSequenceFileCreate(seq, url as CFURL, .midiType, .eraseFile, 0) == noErr else {
            DisposeMusicSequence(seq)
            return nil
        }
        DisposeMusicSequence(seq)
        return url
    }
}
