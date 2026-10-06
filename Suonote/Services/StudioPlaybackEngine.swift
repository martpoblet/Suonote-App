import os
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

    /// Set when the project's musical content changes so the MIDI sequence is
    /// stale. Lets transports defer the (expensive) rebuild until the user
    /// actually presses play, while sharing that state across views (the
    /// Studio tab and the bottom-accessory transport).
    @Published var needsSequenceRebuild: Bool = true
    
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
        var startBeat: Double
        let file: AVAudioFile
        let format: AVAudioFormat
        let sampleRate: Double
        let length: AVAudioFramePosition
    }


    private var engine = AVAudioEngine()
    private var sequencer: AVAudioSequencer?
    private var graph: StudioMixGraph?
    private var graphSignature = ""
    /// Toggling is live: the click track always exists in the sequence and
    /// is simply muted/unmuted, so playback never restarts.
    @Published var isMetronomeEnabled: Bool = false {
        didSet { applyMetronomeLevel() }
    }
    @Published var metronomeVolume: Float = 0.5 {
        didSet { applyMetronomeLevel() }
    }
    private var metronomeSampler: AVAudioUnitSampler?
    private var metronomeMixer: AVAudioMixerNode?

    private func applyMetronomeLevel() {
        metronomeMixer?.outputVolume = isMetronomeEnabled ? metronomeVolume : 0
    }
    @Published var countInBars: Int = 0  // 0 = no count-in, 1 or 2
    private var audioTrackInfo: [UUID: AudioTrackInfo] = [:]
    private var bpm: Double = 120
    private var beatScale: Double = 1.0
    private var currentBeatsPerBar: Int = 4
    private var beatClock = BeatClock(bpm: 120, timeBottom: 4)
    private var playheadTimer: Timer?


    nonisolated private static let audioSessionQueue = DispatchQueue(
        label: "com.suonote.studioPlayback.audioSession"
    )

    private var sessionObservers: [Any] = []
    private var wasPlayingBeforeInterruption = false

    // MARK: - Track level metering
    /// Smoothed RMS level per track (0...1), published on the playhead tick.
    @Published private(set) var trackLevels: [UUID: Float] = [:]
    private let levelStore = TrackLevelStore()

    /// Thread-safe store written from the audio render tap.
    private final class TrackLevelStore: @unchecked Sendable {
        private var levels: [UUID: Float] = [:]
        private let lock = NSLock()

        func set(_ level: Float, for id: UUID) {
            lock.lock()
            levels[id] = level
            lock.unlock()
        }

        func snapshot() -> [UUID: Float] {
            lock.lock()
            defer { lock.unlock() }
            return levels
        }

        func clear() {
            lock.lock()
            levels = [:]
            lock.unlock()
        }
    }

    private func installMeterTaps() {
        guard let graph else { return }
        for (id, chain) in graph.chains {
            let mixer = chain.channel
            let format = mixer.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else { continue }
            mixer.removeTap(onBus: 0)
            mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [levelStore] buffer, _ in
                guard let data = buffer.floatChannelData else { return }
                let frames = Int(buffer.frameLength)
                guard frames > 0 else { return }
                let samples = data[0]
                var sum: Float = 0
                var count = 0
                for index in stride(from: 0, to: frames, by: 8) {
                    sum += samples[index] * samples[index]
                    count += 1
                }
                let rms = sqrt(sum / Float(max(1, count)))
                levelStore.set(min(1, rms * 2.5), for: id)
            }
        }
    }

    private func removeMeterTaps() {
        for chain in graph?.chains.values.map({ $0 }) ?? [] {
            chain.channel.removeTap(onBus: 0)
        }
        levelStore.clear()
        trackLevels = [:]
    }

    init() {
        observeAudioSessionNotifications()
    }

    deinit {
        for observer in sessionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Audio session interruptions / route changes (A-02)

    private func observeAudioSessionNotifications() {
        let center = NotificationCenter.default
        let interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract Sendable values before hopping to the main actor.
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            let owner = self
            Task { @MainActor in
                owner?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
        sessionObservers.append(interruptionObserver)

        let routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let owner = self
            Task { @MainActor in
                owner?.handleRouteChange(reasonValue: reasonValue)
            }
        }
        sessionObservers.append(routeChangeObserver)
    }

    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            Self.playbackSessionActive = false
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume), wasPlayingBeforeInterruption {
                configureAudioSession()
                play()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonValue: UInt?) {
        guard let reasonValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        // Pause when the output device disappears (e.g. headphones unplugged)
        // so playback doesn't blast from the speaker mid-session.
        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
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

        updateBeatClock(for: project)
        totalBeats = timelineBeats(for: project)
        currentBeat = min(currentBeat, totalBeats)

        configureAudioSession()
        engine = AVAudioEngine()
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        guard outputFormat.sampleRate > 0, outputFormat.channelCount > 0 else {
            AppLog.studio.error("Studio playback output unavailable.")
            return
        }

        let allTracks = resolvedTracks(from: project)
        let graph = StudioMixGraph(engine: engine)
        graph.build(tracks: allTracks, project: project, outputFormat: outputFormat)
        self.graph = graph
        graphSignature = Self.graphSignature(for: allTracks, style: project.studioStyle)
        loadAudioTrackInfo(for: allTracks, project: project)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            AppLog.studio.error("Studio playback engine failed to start: \(String(describing: error))")
            return
        }

        sequencer = AVAudioSequencer(audioEngine: engine)
        buildSequence(for: allTracks)
        applyMixState(project: project)
        if !isPlaying { scheduleIdlePause() }
    }

    /// Anything that changes which nodes/presets exist forces a full rebuild;
    /// note, mix and effect edits never do.
    private static func graphSignature(for tracks: [StudioTrack], style: StudioStyle?) -> String {
        tracks.map { "\($0.id.uuidString):\($0.instrument.rawValue):\($0.variant?.rawValue ?? "-"):\($0.audioRecordingId?.uuidString ?? "")" }
            .joined(separator: "|") + "#\(style?.rawValue ?? "-")"
    }
    
    func rebuildSequenceIncremental(project: Project) {
        let allTracks = resolvedTracks(from: project)

        // If the graph topology or any preset changed, do a full rebuild.
        guard graph != nil,
              Self.graphSignature(for: allTracks, style: project.studioStyle) == graphSignature else {
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
        guard sequencer != nil else { return }
        cancelIdlePause()

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                AppLog.studio.error("Studio playback engine failed to start: \(String(describing: error))")
            }
        }

        if countInBars > 0, !isCountingIn {
            startCountIn { [weak self] in
                self?.beginPlayback()
            }
        } else {
            beginPlayback()
        }
    }

    private func beginPlayback() {
        guard let sequencer else { return }

        let sequencerStartBeat = beatClock.uiBeatToSequencerBeat(currentBeat)
        sequencer.currentPositionInBeats = sequencerStartBeat

        do {
            playbackGeneration += 1
            bandClock = nil
            let startPosition = sequencer.currentPositionInSeconds
            // Listen before starting: the first click renders right away.
            if !audioTrackInfo.isEmpty {
                listenForFirstClick(startBeat: currentBeat, requestedAt: mach_absolute_time(), generation: playbackGeneration)
            }
            try sequencer.start()
            isPlaying = true
            installMeterTaps()
            startPlayheadTimer()
            if !audioTrackInfo.isEmpty {
                alignRecordings(to: sequencer, from: startPosition, startBeat: currentBeat, generation: playbackGeneration)
            }
        } catch {
            AppLog.studio.error("Failed to start sequencer: \(String(describing: error))")
        }
    }

    /// Bumped on every start, so a late alignment never touches a newer run.
    private var playbackGeneration = 0

    /// Starts recordings on the band's real clock. The sequencer begins a
    /// moment after `start()` returns, so takes started "now" ran ahead of
    /// the band. Its position is watched until it moves; the take is then
    /// started from the matching point in its file. (`hostTime(forBeats:)`
    /// can't be used: right after `start()` it raises -10852.)
    private func alignRecordings(to sequencer: AVAudioSequencer, from startPosition: TimeInterval, startBeat: Double, generation: Int) {
        let requested = mach_absolute_time()
        Task { @MainActor [weak self] in
            var anchor: UInt64?
            for _ in 0..<150 {
                guard let self, self.isPlaying, self.playbackGeneration == generation else { return }
                let elapsed = sequencer.currentPositionInSeconds - startPosition
                if elapsed > 0.000_5 {
                    // The band's start beat sounded `elapsed` seconds ago.
                    anchor = mach_absolute_time() - AVAudioTime.hostTime(forSeconds: elapsed)
                    break
                }
                try? await Task.sleep(for: .milliseconds(2))
            }
            // The click already gave the real clock: nothing to guess.
            guard let self, self.isPlaying, self.playbackGeneration == generation, self.bandClock == nil else { return }
            if anchor == nil {
                AppLog.studio.error("Sequencer clock didn't move; starting recordings unaligned")
            }
            let estimate = BandClock(hostTime: anchor ?? requested, uiBeat: startBeat, isMeasured: false)
            self.bandClock = estimate
            self.scheduleAudioTracks(startBeat: startBeat, anchorHostTime: estimate.hostTime)
        }
    }

    // MARK: - Band clock

    /// Ties a beat of the band to the host time it renders at.
    private struct BandClock {
        let hostTime: UInt64
        let uiBeat: Double
        /// True once taken from the click actually rendering, not estimated.
        let isMeasured: Bool
    }

    /// The running band's clock, used to start and move recordings.
    private var bandClock: BandClock?

    /// Watches the click track (always sequenced, even when muted) for the
    /// first beat after a start. Its render time is the band's real clock,
    /// whatever delay the sequencer adds when it starts; recordings are then
    /// (re)started to match it.
    private func listenForFirstClick(startBeat: Double, requestedAt: UInt64, generation: Int) {
        guard let sampler = metronomeSampler else { return }
        let format = sampler.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }
        let sampleRate = format.sampleRate
        let once = FirstClickLatch()
        sampler.removeTap(onBus: 0)
        sampler.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, when in
            guard when.isHostTimeValid, let channel = buffer.floatChannelData?[0] else { return }
            guard let onset = once.onset(in: channel, frames: Int(buffer.frameLength)) else { return }
            let hostTime = when.hostTime + AVAudioTime.hostTime(forSeconds: Double(onset) / sampleRate)
            let owner = self
            Task { @MainActor in
                owner?.firstClickHeard(atHostTime: hostTime, startBeat: startBeat, requestedAt: requestedAt, generation: generation)
            }
        }
    }

    private func firstClickHeard(atHostTime hostTime: UInt64, startBeat: Double, requestedAt: UInt64, generation: Int) {
        metronomeSampler?.removeTap(onBus: 0)
        guard isPlaying, playbackGeneration == generation else { return }
        // Clicks fall on whole beats. The start delay is far less than half a
        // beat, so the beat due at that moment, rounded, is the one heard.
        let sinceRequest = AVAudioTime.seconds(forHostTime: hostTime) - AVAudioTime.seconds(forHostTime: requestedAt)
        let due = (startBeat + sinceRequest / beatClock.uiBeatSeconds).rounded()
        let clickBeat = max(due, (startBeat - 0.001).rounded(.up))
        let measured = BandClock(hostTime: hostTime, uiBeat: clickBeat, isMeasured: true)
        let previous = bandClock
        bandClock = measured
        // Restart takes only if the estimate they started on was off.
        if let previous {
            let drift = abs(Self.seconds(from: previous, to: measured, beatSeconds: beatClock.uiBeatSeconds))
            guard drift > 0.002 else { return }
            AppLog.studio.info("Recordings re-aligned to the band by \(Int(drift * 1000)) ms")
        }
        scheduleAudioTracks(startBeat: measured.uiBeat, anchorHostTime: measured.hostTime)
    }

    /// How far `b`'s clock is from `a`'s, in seconds (positive: `b` later).
    private static func seconds(from a: BandClock, to b: BandClock, beatSeconds: Double) -> Double {
        let aSeconds = AVAudioTime.seconds(forHostTime: a.hostTime) - a.uiBeat * beatSeconds
        let bSeconds = AVAudioTime.seconds(forHostTime: b.hostTime) - b.uiBeat * beatSeconds
        return bSeconds - aSeconds
    }

    /// A recording's start bar or nudge changed: move just that take. The
    /// band keeps playing (rebuilding the sequence used to silence it).
    func audioClipMoved(_ track: StudioTrack) {
        guard var info = audioTrackInfo[track.id] else {
            needsSequenceRebuild = true
            return
        }
        info.startBeat = track.audioStartBeat
        audioTrackInfo[track.id] = info
        guard isPlaying, let bandClock else { return }
        scheduleAudioTracks(startBeat: bandClock.uiBeat, anchorHostTime: bandClock.hostTime, only: track.id)
    }

    // MARK: - Count-in (A-04)

    @Published private(set) var isCountingIn = false
    private var countInWorkItems: [DispatchWorkItem] = []
    private var countInSampler: AVAudioUnitSampler?

    private func ensureCountInSampler() -> AVAudioUnitSampler? {
        if let countInSampler { return countInSampler }
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        var loaded = false
        if let sfURL = SoundFontManager.soundFontURL(for: .drums, variant: nil) {
            loaded = attemptLoad(
                sampler, url: sfURL, program: 0,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB), logFailure: false
            )
        }
        if !loaded, let sysURL = systemSoundBankURL() {
            loaded = attemptLoad(
                sampler, url: sysURL, program: 0,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB), logFailure: false
            )
        }
        guard loaded else {
            engine.detach(sampler)
            return nil
        }
        countInSampler = sampler
        return sampler
    }

    private func startCountIn(completion: @escaping () -> Void) {
        guard let sampler = ensureCountInSampler() else {
            completion()
            return
        }

        isCountingIn = true
        let beatSeconds = beatClock.uiBeatSeconds
        let beatsPerBar = max(1, currentBeatsPerBar)
        let totalClicks = countInBars * beatsPerBar

        // GM percussion: 76 = Hi Wood Block (accent), 77 = Lo Wood Block
        for index in 0..<totalClicks {
            let isDownbeat = index % beatsPerBar == 0
            let item = DispatchWorkItem {
                let note: UInt8 = isDownbeat ? 76 : 77
                let velocity: UInt8 = isDownbeat ? 110 : 80
                sampler.startNote(note, withVelocity: velocity, onChannel: 9)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    sampler.stopNote(note, onChannel: 9)
                }
            }
            countInWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * beatSeconds, execute: item)
        }

        let finish = DispatchWorkItem { [weak self] in
            self?.isCountingIn = false
            self?.countInWorkItems.removeAll()
            completion()
        }
        countInWorkItems.append(finish)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(totalClicks) * beatSeconds,
            execute: finish
        )
    }

    private func cancelCountIn() {
        for item in countInWorkItems {
            item.cancel()
        }
        countInWorkItems.removeAll()
        isCountingIn = false
    }

    /// Rebuild the sequence first if it's marked stale, then start playback.
    /// Centralizes the deferred-rebuild logic so any transport (Studio tab or
    /// bottom accessory) can start playback correctly.
    func playRebuildingIfNeeded(project: Project) {
        if needsSequenceRebuild {
            rebuildSequence(project: project)
            needsSequenceRebuild = false
        } else {
            updateProject(project)
        }
        play()
    }

    func pause() {
        stop(resetPosition: false)
    }

    func stop(resetPosition: Bool = false) {
        cancelCountIn()
        stopPlayheadTimer()
        removeMeterTaps()
        metronomeSampler?.removeTap(onBus: 0)
        bandClock = nil
        isPlaying = false
        
        if resetPosition {
            currentBeat = 0
        }
        
        sequencer?.stop()
        for chain in graph?.chains.values.map({ $0 }) ?? [] {
            chain.player?.stop()
        }

        if resetPosition {
            sequencer?.currentPositionInBeats = 0
        }
        scheduleIdlePause()
    }

    // MARK: - Idle power

    private var idlePauseWork: DispatchWorkItem?

    /// A running AVAudioEngine processes every effect in the graph even in
    /// silence (~20% CPU with a full band). Pause it shortly after playback
    /// stops (letting reverb tails ring out); `play()` restarts it.
    private func scheduleIdlePause() {
        idlePauseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isPlaying, !self.isCountingIn, self.engine.isRunning else { return }
            self.engine.pause()
        }
        idlePauseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func cancelIdlePause() {
        idlePauseWork?.cancel()
        idlePauseWork = nil
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
    
    /// Call after editing a track's notes. Rewrites just that part in the
    /// running sequence so the change is heard immediately (even mid-loop);
    /// falls back to a deferred rebuild when the track isn't in the graph.
    func notesChanged(for track: StudioTrack, project: Project) {
        // A sound/instrument change needs new nodes: rebuild now if playing
        // (brief restart), otherwise on the next play.
        let signature = Self.graphSignature(for: resolvedTracks(from: project), style: project.studioStyle)
        if track.instrument.isAudio, signature == graphSignature {
            updateBeatClock(for: project)
            audioClipMoved(track)
            return
        }
        guard signature == graphSignature, !track.instrument.isAudio else {
            if isPlaying {
                rebuildSequenceIncremental(project: project)
                needsSequenceRebuild = false
            } else {
                needsSequenceRebuild = true
            }
            return
        }
        updateBeatClock(for: project)
        if let graph, graph.rewriteEvents(for: track, beatScale: beatScale, beatsPerBar: currentBeatsPerBar) {
            return
        }
        needsSequenceRebuild = true
    }

    func updateTrackMix(trackId: UUID, volume: Float, pan: Float) {
        graph?.setMix(trackId: trackId, volume: volume, pan: pan)
    }

    func applyMixState(project: Project) {
        graph?.applyMix(project: project)
        for track in project.studioTracks {
            graph?.updateEffects(for: track, bpm: bpm)
        }
    }

    func updateTrackEffects(track: StudioTrack) {
        graph?.updateEffects(for: track, bpm: bpm)
    }

    // Legacy compatibility
    func updateProject(_ project: Project) {
        updateBeatClock(for: project)
        totalBeats = timelineBeats(for: project)
        applyMixState(project: project)
    }

    private func resolvedTracks(from project: Project) -> [StudioTrack] {
        project.studioTracks.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Whether this engine already set up and activated the playback session.
    private static var playbackSessionActive = false

    private func configureAudioSession() {
        // Setting the category or activating blocks the main thread for a
        // moment, so only do it when something (a recording) changed it.
        let current = AVAudioSession.sharedInstance()
        if Self.playbackSessionActive, current.category == .playback,
           current.mode == .default, current.categoryOptions == [.mixWithOthers] {
            return
        }
        Self.audioSessionQueue.sync {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                Self.playbackSessionActive = true
            } catch {
                AppLog.audio.error("Failed to configure audio session: \(String(describing: error))")
            }
        }
    }

    private func teardownEngine() {
        sequencer?.stop()
        removeMeterTaps()
        engine.stop()
        graph?.teardown()
        graph = nil
        graphSignature = ""
        if let metro = metronomeSampler { engine.detach(metro); metronomeSampler = nil }
        if let metroMixer = metronomeMixer { engine.detach(metroMixer); metronomeMixer = nil }
        if let countIn = countInSampler { engine.detach(countIn); countInSampler = nil }
        cancelCountIn()
        engine.reset()
        audioTrackInfo.removeAll()
        stopPlayheadTimer()
    }

    private func loadAudioTrackInfo(for tracks: [StudioTrack], project: Project) {
        for track in tracks where track.instrument.isAudio {
            guard let recordingId = track.audioRecordingId,
                  let recording = project.recordings.first(where: { $0.id == recordingId }) else { continue }
            guard let url = FileManagerUtils.existingRecordingURL(for: recording.fileName),
                  let file = try? AVAudioFile(forReading: url) else {
                AppLog.studio.error("Recording file not found for: \(recording.fileName)")
                continue
            }
            audioTrackInfo[track.id] = AudioTrackInfo(
                url: url,
                startBeat: track.audioStartBeat,
                file: file,
                format: file.processingFormat,
                sampleRate: file.processingFormat.sampleRate,
                length: file.length
            )
        }
    }

    private func buildSequence(for tracks: [StudioTrack]) {
        guard let sequencer else { return }

        graph?.buildSequence(sequencer, tracks: tracks, beatScale: beatScale, beatsPerBar: currentBeatsPerBar)

        // Click track is always sequenced; its level follows the toggle.
        addMetronomeTrack(to: sequencer)

        configureTempoTrack(for: sequencer)
        sequencer.prepareToPlay()
    }

    private func ensureMetronome() -> AVAudioUnitSampler? {
        if let metronomeSampler { return metronomeSampler }
        let metroSampler = AVAudioUnitSampler()
        let metroMixer = AVAudioMixerNode()
        engine.attach(metroSampler)
        engine.attach(metroMixer)
        engine.connect(metroSampler, to: metroMixer, format: nil)
        engine.connect(metroMixer, to: engine.mainMixerNode, format: nil)

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
            return nil
        }
        metronomeSampler = metroSampler
        metronomeMixer = metroMixer
        applyMetronomeLevel()
        return metroSampler
    }

    private func addMetronomeTrack(to sequencer: AVAudioSequencer) {
        guard let metroSampler = ensureMetronome() else { return }

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

    private func scheduleAudioTracks(startBeat: Double, anchorHostTime: UInt64?, only trackId: UUID? = nil) {
        // UI beats are timeBottom-based; convert to seconds using the project's BPM + meter.
        let uiBeatSeconds = beatClock.uiBeatSeconds
        let anchor = anchorHostTime ?? engine.outputNode.lastRenderTime?.hostTime ?? mach_absolute_time()
        // Never schedule in the past: a late start skips into the file instead,
        // so the take stays on the beat it belongs to.
        let earliest = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.005)

        for (id, info) in audioTrackInfo where trackId == nil || id == trackId {
            guard let node = graph?.chains[id]?.player else { continue }
            node.stop()

            // Seconds into the file at the anchor (negative: the clip starts later).
            var fileSeconds = (startBeat - info.startBeat) * uiBeatSeconds
            var startHost = anchor
            if fileSeconds < 0 {
                startHost += AVAudioTime.hostTime(forSeconds: -fileSeconds)
                fileSeconds = 0
            }
            if startHost < earliest {
                fileSeconds += AVAudioTime.seconds(forHostTime: earliest) - AVAudioTime.seconds(forHostTime: startHost)
                startHost = earliest
            }

            let startFrame = AVAudioFramePosition(fileSeconds * info.sampleRate)
            let remainingFrames = info.length - startFrame
            guard remainingFrames > 0 else { continue }
            node.scheduleSegment(
                info.file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(remainingFrames),
                at: nil
            )
            node.play(at: AVAudioTime(hostTime: startHost))
        }
    }

    /// Live sequencer position in UI beats, for frame-rate playhead rendering
    /// (the published `currentBeat` only updates on the coarse logic timer).
    func livePositionBeats() -> Double {
        guard isPlaying, let sequencer else { return currentBeat }
        let beats = beatClock.sequencerBeatToUiBeat(sequencer.currentPositionInBeats)
        return max(0, min(beats, totalBeats))
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
        trackLevels = levelStore.snapshot()
        
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
                AppLog.audio.error("Failed to load sound bank \(url.lastPathComponent): \(String(describing: error))")
            }
            return false
        }
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


    // MARK: - MIDI Export

    func exportMIDI(project: Project) -> URL? {
        let tracks = project.studioTracks
            .filter { !$0.instrument.isAudio }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard !tracks.isEmpty else { return nil }

        var musicSequence: MusicSequence?
        guard NewMusicSequence(&musicSequence) == noErr, let seq = musicSequence else { return nil }

        // Tempo track: tempo + time signature meta event (A-05)
        var tempoTrack: MusicTrack?
        MusicSequenceGetTempoTrack(seq, &tempoTrack)
        if let tempoTrack {
            MusicTrackNewExtendedTempoEvent(tempoTrack, 0, Float64(bpm))
            addTimeSignatureMeta(to: tempoTrack, beatsPerBar: currentBeatsPerBar, timeBottom: beatClock.timeBottom)
        }

        // Channel assignment: drums on the GM percussion channel (9),
        // melodic tracks on sequential channels skipping 9.
        var nextMelodicChannel: UInt8 = 0
        for track in tracks {
            var mTrack: MusicTrack?
            MusicSequenceNewTrack(seq, &mTrack)
            guard let mTrack else { continue }

            let channel: UInt8
            if track.instrument == .drums {
                channel = 9
            } else {
                if nextMelodicChannel == 9 { nextMelodicChannel += 1 }
                channel = nextMelodicChannel % 16
                nextMelodicChannel += 1
            }

            // Program change so DAWs load the right GM instrument (A-05).
            if track.instrument != .drums {
                let resolved = SoundFontManager.resolvedVariant(for: track.instrument, variant: track.variant)
                let preset = resolved.map(StudioSoundCatalog.preset(for:))
                let program = preset?.program ?? programNumber(for: track.instrument)
                if let variation = preset?.bankVariation, variation > 0 {
                    // GM2/GS bank select: CC0 = 121 (melodic), CC32 = variation.
                    var msb = MIDIChannelMessage(status: 0xB0 | channel, data1: 0, data2: 121, reserved: 0)
                    var lsb = MIDIChannelMessage(status: 0xB0 | channel, data1: 32, data2: variation, reserved: 0)
                    MusicTrackNewMIDIChannelEvent(mTrack, 0, &msb)
                    MusicTrackNewMIDIChannelEvent(mTrack, 0, &lsb)
                }
                var programMessage = MIDIChannelMessage(
                    status: 0xC0 | channel,
                    data1: program,
                    data2: 0,
                    reserved: 0
                )
                MusicTrackNewMIDIChannelEvent(mTrack, 0, &programMessage)
            }

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

    /// Writes a standard MIDI time-signature meta event (FF 58).
    private func addTimeSignatureMeta(to track: MusicTrack, beatsPerBar: Int, timeBottom: Int) {
        let denominatorPower = UInt8(max(0, Int(log2(Double(max(1, timeBottom))).rounded())))
        let payload: [UInt8] = [
            UInt8(max(1, min(255, beatsPerBar))),
            denominatorPower,
            24, // MIDI clocks per metronome click
            8   // 32nd notes per quarter note
        ]

        let size = MemoryLayout<MIDIMetaEvent>.size + payload.count - 1
        let memory = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<MIDIMetaEvent>.alignment)
        defer { memory.deallocate() }

        let event = memory.bindMemory(to: MIDIMetaEvent.self, capacity: 1)
        event.pointee.metaEventType = 0x58
        event.pointee.dataLength = UInt32(payload.count)
        withUnsafeMutablePointer(to: &event.pointee.data) { dataPointer in
            dataPointer.withMemoryRebound(to: UInt8.self, capacity: payload.count) { bytes in
                for (index, byte) in payload.enumerated() {
                    bytes[index] = byte
                }
            }
        }
        MusicTrackNewMetaEvent(track, 0, event)
    }
}

/// Finds the first click after a start, once, from the audio thread. A
/// click only counts after a stretch of silence, so the tail of a click from
/// before a restart isn't mistaken for the new downbeat.
nonisolated final class FirstClickLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var found = false
    private var isFirstBuffer = true
    /// Starts "quiet": playback starts from silence unless a tail is ringing.
    private var quietFrames = FirstClickLatch.quietNeeded

    private static let threshold: Float = 0.002
    private static let quietNeeded = 256

    func onset(in channel: UnsafePointer<Float>, frames: Int) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        guard !found else { return nil }
        if isFirstBuffer {
            isFirstBuffer = false
            // Sound already playing when listening began is an old tail.
            if frames > 0, abs(channel[0]) > Self.threshold { quietFrames = 0 }
        }
        for index in 0..<frames {
            if abs(channel[index]) > Self.threshold {
                if quietFrames >= Self.quietNeeded {
                    found = true
                    return index
                }
                quietFrames = 0
            } else {
                quietFrames += 1
            }
        }
        return nil
    }
}
