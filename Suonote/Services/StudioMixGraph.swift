import Foundation
import AVFoundation
import AudioToolbox
import os

/// Builds and drives the Studio's audio graph. Shared by realtime playback
/// (`StudioPlaybackEngine`) and offline mixdown (`StudioOfflineRenderer`) so
/// what you hear is exactly what you export.
///
/// Per track:
///   source (sampler | player) → tone EQ → [comp] → reverb → delay → channel
///   channel ──┬──▶ main mixer          (fader + pan)
///             └──▶ ambience bus send   (shared room, post-fader)
///
///   tone EQ = loudness trim + role balance (global gain), role high-pass,
///             user low/mid/high, style low-pass.
///
/// Master: main mixer → bus EQ → glue compressor → peak limiter → output.
final class StudioMixGraph {

    struct TrackChain {
        /// The MIDI instrument: a SoundFont sampler or Suonote's synth.
        let sampler: AVAudioUnitMIDIInstrument?
        let player: AVAudioPlayerNode?
        /// Up-mixes mono/odd-rate recordings to the graph format, or sums an
        /// instrument with its layer.
        let inputMixer: AVAudioMixerNode?
        /// Optional sub-bass layer that doubles a sampled bass for weight.
        let layer: AVAudioUnitMIDIInstrument?
        let tone: AVAudioUnitEQ
        let compressor: AVAudioUnitEffect
        let reverb: AVAudioUnitReverb
        let delay: AVAudioUnitDelay
        let channel: AVAudioMixerNode
        let ambienceBus: AVAudioNodeBus
        let profile: StudioSoundCatalog.MixProfile
        /// Fixed gain from loudness matching + role balance.
        let baseGainDB: Float
        /// Drum kits normally sit on the percussion bank (channel 10);
        /// if only the melodic fallback loaded, notes go on channel 1.
        var drumsOnMelodicBank: Bool = false
    }

    struct MixState {
        var volume: Float
        var pan: Float
        var isMuted: Bool
        var isSolo: Bool
    }

    let engine: AVAudioEngine
    private(set) var chains: [UUID: TrackChain] = [:]
    private(set) var style: StudioStyle?

    private let ambienceInput = AVAudioMixerNode()
    private let ambienceReverb = AVAudioUnitReverb()
    private let ambienceTone = AVAudioUnitEQ(numberOfBands: 2)
    private let busEQ = AVAudioUnitEQ(numberOfBands: 3)
    private let glue: AVAudioUnitEffect
    private let limiter: AVAudioUnitEffect
    /// Output trim after the limiter: keeps true peaks under -1 dBFS.
    private let ceiling = AVAudioMixerNode()
    private var nextAmbienceBus: AVAudioNodeBus = 0
    private var mixState: [UUID: MixState] = [:]

    /// User-facing fader (0…1, default 0.75) to linear gain. 0.75 ≈ unity,
    /// full travel adds ~+4 dB so users can push a part forward.
    static func faderGain(_ value: Float) -> Float {
        let clamped = max(0, min(1, value))
        guard clamped > 0.001 else { return 0 }
        let db = (clamped - 0.75) * 18   // 0.75 → 0 dB, 1.0 → +4.5 dB, 0.25 → -9 dB
        let curve = clamped < 0.25 ? clamped / 0.25 : 1   // fade to silence at the bottom
        return powf(10, db / 20) * curve
    }

    init(engine: AVAudioEngine) {
        self.engine = engine
        glue = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0
        ))
        limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0
        ))
    }

    // MARK: - Build

    /// Attaches the master section and every track chain, and loads instruments.
    func build(tracks: [StudioTrack], project: Project, outputFormat: AVAudioFormat) {
        style = project.studioStyle
        let format = AVAudioFormat(standardFormatWithSampleRate: outputFormat.sampleRate, channels: 2) ?? outputFormat

        // Master section.
        [ambienceInput, ambienceReverb, ambienceTone, busEQ, glue, limiter, ceiling].forEach { engine.attach($0) }
        configureMaster()   // before connecting (see makeChain)
        engine.connect(ambienceInput, to: ambienceTone, format: format)
        engine.connect(ambienceTone, to: ambienceReverb, format: format)
        engine.connect(ambienceReverb, to: engine.mainMixerNode, format: format)
        engine.disconnectNodeOutput(engine.mainMixerNode)
        engine.connect(engine.mainMixerNode, to: busEQ, format: format)
        engine.connect(busEQ, to: glue, format: format)
        engine.connect(glue, to: limiter, format: format)
        engine.connect(limiter, to: ceiling, format: format)
        engine.connect(ceiling, to: engine.outputNode, format: outputFormat)

        for track in tracks {
            if track.instrument.isAudio {
                attachAudioChain(for: track, project: project, format: format)
            } else {
                attachInstrumentChain(for: track, format: format)
            }
        }
        applyMix(project: project)
    }

    func teardown() {
        for chain in chains.values {
            chain.player?.stop()
            [chain.sampler, chain.layer, chain.player, chain.inputMixer, chain.tone, chain.compressor, chain.reverb, chain.delay, chain.channel]
                .compactMap { $0 as AVAudioNode? }
                .forEach { engine.detach($0) }
        }
        chains.removeAll()
        mixState.removeAll()
        musicTracks.removeAll()
        layerTracks.removeAll()
        for node in [ambienceInput, ambienceReverb, ambienceTone, busEQ, glue, limiter, ceiling] where node.engine != nil {
            engine.detach(node)
        }
        nextAmbienceBus = 0
    }

    private func attachInstrumentChain(for track: StudioTrack, format: AVAudioFormat) {
        let resolved = SoundFontManager.resolvedVariant(for: track.instrument, variant: track.variant)
        if let preset = StudioSoundCatalog.synthPreset(for: resolved) {
            SuonoteSynthAudioUnit.register()
            let synth = AVAudioUnitMIDIInstrument(audioComponentDescription: SuonoteSynthAudioUnit.componentDescription)
            (synth.auAudioUnit as? SuonoteSynthAudioUnit)?.preset = preset
            chains[track.id] = makeChain(for: track, source: synth, player: nil, sourceFormat: nil, format: format)
            return
        }
        let sampler = AVAudioUnitSampler()
        // (A synth sub layer under sampled basses was tried and removed: it
        // made a real bass sound synthetic. Weight comes from the role EQ.)
        let chain = makeChain(for: track, source: sampler, player: nil, sourceFormat: nil, format: format)
        chains[track.id] = chain
        loadInstrument(for: track, into: sampler)
    }

    private func attachAudioChain(for track: StudioTrack, project: Project, format: AVAudioFormat) {
        let player = AVAudioPlayerNode()
        var fileFormat: AVAudioFormat?
        if let recordingId = track.audioRecordingId,
           let recording = project.recordings.first(where: { $0.id == recordingId }),
           let url = FileManagerUtils.existingRecordingURL(for: recording.fileName),
           let file = try? AVAudioFile(forReading: url) {
            fileFormat = file.processingFormat
        }
        chains[track.id] = makeChain(for: track, source: player, player: player, sourceFormat: fileFormat, format: format)
    }

    private func makeChain(
        for track: StudioTrack,
        source: AVAudioNode,
        player: AVAudioPlayerNode?,
        sourceFormat: AVAudioFormat?,
        format: AVAudioFormat,
        layer: AVAudioUnitMIDIInstrument? = nil
    ) -> TrackChain {
        let tone = AVAudioUnitEQ(numberOfBands: 5)
        let compressor = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0
        ))
        let reverb = AVAudioUnitReverb()
        let delay = AVAudioUnitDelay()
        let channel = AVAudioMixerNode()
        [source, tone, compressor, reverb, delay, channel].forEach { engine.attach($0) }
        var inputMixer: AVAudioMixerNode?
        if player != nil || layer != nil {
            let upmix = AVAudioMixerNode()
            engine.attach(upmix)
            inputMixer = upmix
        }
        if let layer { engine.attach(layer) }

        let role = StudioSoundCatalog.role(for: track.instrument, variant: track.variant)
        var profile = StudioSoundCatalog.mixProfile(for: role, style: style)
        if track.instrument.isAudio {
            profile = StudioSoundCatalog.MixProfile(levelDB: 0, pan: 0, ambience: 0.12, highPassHz: 60, lowPassHz: 0, sustainPedal: false)
        }
        let resolvedVariant = SoundFontManager.resolvedVariant(for: track.instrument, variant: track.variant)
        let trim = track.instrument.isAudio ? 0 : StudioSoundCatalog.loudnessTrimDB(for: resolvedVariant, instrument: track.instrument)
        let ambienceBus = nextAmbienceBus
        nextAmbienceBus += 1
        let chain = TrackChain(
            sampler: source as? AVAudioUnitMIDIInstrument,
            player: player,
            inputMixer: inputMixer,
            layer: layer,
            tone: tone,
            compressor: compressor,
            reverb: reverb,
            delay: delay,
            channel: channel,
            ambienceBus: ambienceBus,
            profile: profile,
            baseGainDB: trim + profile.levelDB
        )
        // Configure parameters BEFORE connecting: connecting at a new sample
        // rate makes Apple's effect units rebuild their parameter trees on a
        // background queue, and setting parameters during that rebuild
        // crashes inside AVFAudio (seen on 48 kHz devices).
        configureTone(chain, track: track)
        configureEffects(chain, track: track, bpm: 120)

        if let inputMixer {
            engine.connect(source, to: inputMixer, format: sourceFormat ?? (player == nil ? format : nil))
            if let layer {
                engine.connect(layer, to: inputMixer, format: format)
                layer.volume = 0.28
            }
            engine.connect(inputMixer, to: tone, format: format)
        } else {
            engine.connect(source, to: tone, format: format)
        }
        engine.connect(tone, to: compressor, format: format)
        engine.connect(compressor, to: reverb, format: format)
        engine.connect(reverb, to: delay, format: format)
        engine.connect(delay, to: channel, format: format)

        let mainBus = engine.mainMixerNode.nextAvailableInputBus
        engine.connect(
            channel,
            to: [
                AVAudioConnectionPoint(node: engine.mainMixerNode, bus: mainBus),
                AVAudioConnectionPoint(node: ambienceInput, bus: ambienceBus)
            ],
            fromBus: 0,
            format: format
        )
        return chain
    }

    // MARK: - Instruments

    private func loadInstrument(for track: StudioTrack, into sampler: AVAudioUnitSampler) {
        guard let variant = SoundFontManager.resolvedVariant(for: track.instrument, variant: track.variant),
              let url = SoundFontManager.soundFontURL(for: track.instrument, variant: variant) else {
            loadSystemFallback(for: track, into: sampler)
            return
        }
        let preset = StudioSoundCatalog.preset(for: variant)
        let melodicMSB = UInt8(kAUSampler_DefaultMelodicBankMSB)
        let percussionMSB = UInt8(kAUSampler_DefaultPercussionBankMSB)

        if preset.isPercussion {
            if load(sampler, url: url, program: preset.program, msb: percussionMSB, lsb: 0)
                || load(sampler, url: url, program: 0, msb: percussionMSB, lsb: 0) {
                return
            }
            if load(sampler, url: url, program: preset.program, msb: melodicMSB, lsb: 0) {
                chains[track.id]?.drumsOnMelodicBank = true
                return
            }
        } else if load(sampler, url: url, program: preset.program, msb: melodicMSB, lsb: preset.bankVariation)
                    || load(sampler, url: url, program: preset.program, msb: melodicMSB, lsb: 0) {
            return
        }
        AppLog.audio.error("Preset load failed for \(variant.rawValue); using system bank")
        loadSystemFallback(for: track, into: sampler)
    }

    private func loadSystemFallback(for track: StudioTrack, into sampler: AVAudioUnitSampler) {
        let paths = [
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
            "/System/Library/Audio/Units/gs_instruments.dls"
        ]
        guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        let isDrums = track.instrument == .drums
        _ = load(
            sampler,
            url: URL(fileURLWithPath: path),
            program: isDrums ? 0 : (track.variant?.midiProgram ?? 0),
            msb: UInt8(isDrums ? kAUSampler_DefaultPercussionBankMSB : kAUSampler_DefaultMelodicBankMSB),
            lsb: 0
        )
    }

    private func load(_ sampler: AVAudioUnitSampler, url: URL, program: UInt8, msb: UInt8, lsb: UInt8) -> Bool {
        do {
            try sampler.loadSoundBankInstrument(at: url, program: program, bankMSB: msb, bankLSB: lsb)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Master

    private func configureMaster() {
        // Ambience: darkened, de-mudded room shared by every track.
        ambienceReverb.loadFactoryPreset(AVAudioUnitReverbPreset(rawValue: StudioSoundCatalog.ambienceReverbPreset(for: style)) ?? .mediumChamber)
        ambienceReverb.wetDryMix = 100
        let ambienceBands = ambienceTone.bands
        ambienceBands[0].filterType = .highPass
        ambienceBands[0].frequency = 220
        ambienceBands[0].bypass = false
        ambienceBands[1].filterType = .lowPass
        ambienceBands[1].frequency = style == .lofi ? 4_500 : 8_000
        ambienceBands[1].bypass = false
        ambienceInput.outputVolume = 1

        // Bus EQ: clean sub rumble, a touch of air (less for lo-fi).
        let bands = busEQ.bands
        bands[0].filterType = .highPass
        bands[0].frequency = 28
        bands[0].bypass = false
        bands[1].filterType = .parametric
        bands[1].frequency = 320
        bands[1].bandwidth = 1.2
        bands[1].gain = -1.2   // de-box the low mids where GM samples pile up
        bands[1].bypass = false
        bands[2].filterType = .highShelf
        bands[2].frequency = 9_000
        bands[2].gain = style == .lofi ? -2.5 : 1.5
        bands[2].bypass = false

        // Glue: gentle 2:1-ish bus compression so parts sit together.
        setParameter(glue, kDynamicsProcessorParam_Threshold, -16)
        setParameter(glue, kDynamicsProcessorParam_HeadRoom, 8)
        setParameter(glue, kDynamicsProcessorParam_AttackTime, 0.012)
        setParameter(glue, kDynamicsProcessorParam_ReleaseTime, 0.18)
        setParameter(glue, kDynamicsProcessorParam_OverallGain, 3.5)

        // Limiter: catch peaks, add a little loudness.
        setParameter(limiter, kLimiterParam_AttackTime, 0.004)
        setParameter(limiter, kLimiterParam_DecayTime, 0.04)
        setParameter(limiter, kLimiterParam_PreGain, 3.5)

        engine.mainMixerNode.outputVolume = 1
        ceiling.outputVolume = 0.88   // ≈ -1.1 dB
    }

    private func setParameter(_ unit: AVAudioUnitEffect, _ id: AudioUnitParameterID, _ value: Float) {
        AudioUnitSetParameter(unit.audioUnit, id, kAudioUnitScope_Global, 0, value, 0)
    }

    // MARK: - Tone & effects

    private func configureTone(_ chain: TrackChain, track: StudioTrack) {
        let bands = chain.tone.bands
        guard bands.count >= 5 else { return }
        chain.tone.globalGain = max(-96, min(24, chain.baseGainDB))

        bands[0].filterType = .highPass
        bands[0].frequency = max(20, chain.profile.highPassHz)
        bands[0].bypass = chain.profile.highPassHz <= 0

        // User EQ when set; otherwise the role's corrective "engineer" EQ.
        let role = StudioSoundCatalog.role(for: track.instrument, variant: track.variant)
        let auto = track.eqEnabled || track.instrument.isAudio ? nil : StudioSoundCatalog.autoEQ(for: role)

        bands[1].filterType = .lowShelf
        bands[1].frequency = auto?.lowHz ?? 200
        bands[1].gain = track.eqEnabled ? track.eqLowGain : (auto?.low ?? 0)
        bands[1].bypass = !track.eqEnabled && auto == nil

        bands[2].filterType = .parametric
        bands[2].frequency = auto?.midHz ?? 1_000
        bands[2].bandwidth = auto?.midWidth ?? 1.0
        bands[2].gain = track.eqEnabled ? track.eqMidGain : (auto?.mid ?? 0)
        bands[2].bypass = !track.eqEnabled && auto == nil

        bands[3].filterType = .highShelf
        bands[3].frequency = auto?.highHz ?? 5_000
        bands[3].gain = track.eqEnabled ? track.eqHighGain : (auto?.high ?? 0)
        bands[3].bypass = !track.eqEnabled && auto == nil

        bands[4].filterType = .lowPass
        bands[4].frequency = chain.profile.lowPassHz > 0 ? chain.profile.lowPassHz : 18_000
        bands[4].bypass = chain.profile.lowPassHz <= 0
    }

    private func configureEffects(_ chain: TrackChain, track: StudioTrack, bpm: Double) {
        if let preset = AVAudioUnitReverbPreset(rawValue: track.reverbPreset.avPreset) {
            chain.reverb.loadFactoryPreset(preset)
        }
        chain.reverb.wetDryMix = track.reverbEnabled ? track.reverbMix * 100 : 0
        chain.reverb.bypass = !track.reverbEnabled

        chain.delay.delayTime = track.delaySyncMode == .free
            ? TimeInterval(track.delayTime)
            : track.delaySyncMode.delayTime(bpm: bpm)
        chain.delay.feedback = 28
        chain.delay.lowPassCutoff = 6_000
        chain.delay.wetDryMix = track.delayEnabled ? track.delayMix * 100 : 0
        chain.delay.bypass = !track.delayEnabled

        let role = StudioSoundCatalog.role(for: track.instrument, variant: track.variant)
        if !track.compressorEnabled, role == .drums || role == .bass {
            // Built-in bus compression: punchier drums, a steadier bass.
            chain.compressor.bypass = false
            let drums = role == .drums
            setParameter(chain.compressor, kDynamicsProcessorParam_Threshold, drums ? -20 : -22)
            setParameter(chain.compressor, kDynamicsProcessorParam_HeadRoom, drums ? 7 : 9)
            setParameter(chain.compressor, kDynamicsProcessorParam_AttackTime, drums ? 0.012 : 0.006)
            setParameter(chain.compressor, kDynamicsProcessorParam_ReleaseTime, drums ? 0.09 : 0.14)
            setParameter(chain.compressor, kDynamicsProcessorParam_OverallGain, drums ? 3 : 2.5)
            return
        }
        chain.compressor.bypass = !track.compressorEnabled
        if track.compressorEnabled {
            let ratio = max(1.1, track.compressorRatio)
            // DynamicsProcessor has no ratio knob: approximate with headroom.
            setParameter(chain.compressor, kDynamicsProcessorParam_Threshold, track.compressorThreshold)
            setParameter(chain.compressor, kDynamicsProcessorParam_HeadRoom, max(0.5, 24 / ratio))
            setParameter(chain.compressor, kDynamicsProcessorParam_AttackTime, 0.008)
            setParameter(chain.compressor, kDynamicsProcessorParam_ReleaseTime, 0.12)
            setParameter(chain.compressor, kDynamicsProcessorParam_OverallGain, min(12, abs(track.compressorThreshold) / ratio * 0.5))
        }
    }

    /// Re-applies a track's user EQ / reverb / delay / compressor settings live.
    func updateEffects(for track: StudioTrack, bpm: Double) {
        guard let chain = chains[track.id] else { return }
        configureTone(chain, track: track)
        configureEffects(chain, track: track, bpm: bpm)
    }

    // MARK: - Mix

    func applyMix(project: Project) {
        for track in project.studioTracks {
            mixState[track.id] = MixState(volume: track.volume, pan: track.pan, isMuted: track.isMuted, isSolo: track.isSolo)
        }
        refreshMix()
    }

    func setMix(trackId: UUID, volume: Float? = nil, pan: Float? = nil, isMuted: Bool? = nil, isSolo: Bool? = nil) {
        var state = mixState[trackId] ?? MixState(volume: 0.75, pan: 0, isMuted: false, isSolo: false)
        if let volume { state.volume = volume }
        if let pan { state.pan = pan }
        if let isMuted { state.isMuted = isMuted }
        if let isSolo { state.isSolo = isSolo }
        mixState[trackId] = state
        refreshMix()
    }

    private func refreshMix() {
        let anySolo = mixState.values.contains { $0.isSolo }
        for (id, state) in mixState {
            guard let chain = chains[id] else { continue }
            let silenced = state.isMuted || (anySolo && !state.isSolo)
            chain.channel.outputVolume = silenced ? 0 : Self.faderGain(state.volume)
            // Centered tracks get the arranger's default stereo seat.
            let pan = abs(state.pan) < 0.01 ? chain.profile.pan : state.pan
            chain.channel.pan = max(-1, min(1, pan))
            if let send = chain.channel.destination(forMixer: ambienceInput, bus: chain.ambienceBus) {
                send.volume = chain.profile.ambience
                send.pan = chain.channel.pan
            }
            if let main = chain.channel.destination(forMixer: engine.mainMixerNode, bus: mainBus(for: chain)) {
                main.pan = chain.channel.pan
            }
        }
    }

    private func mainBus(for chain: TrackChain) -> AVAudioNodeBus {
        engine.outputConnectionPoints(for: chain.channel, outputBus: 0)
            .first { $0.node === engine.mainMixerNode }?.bus ?? 0
    }

    // MARK: - Sequencing

    /// MIDI tracks of the current sequence, so a single part can be rewritten
    /// in place (note edits while playing) without rebuilding the graph.
    private(set) var musicTracks: [UUID: AVMusicTrack] = [:]
    private var layerTracks: [UUID: AVMusicTrack] = [:]

    /// Writes every instrument track's notes (and piano pedalling) into the sequencer.
    func buildSequence(_ sequencer: AVAudioSequencer, tracks: [StudioTrack], beatScale: Double, beatsPerBar: Int) {
        musicTracks.removeAll()
        layerTracks.removeAll()
        for track in tracks where !track.instrument.isAudio {
            guard let chain = chains[track.id], let sampler = chain.sampler else { continue }
            let musicTrack = sequencer.createAndAppendTrack()
            musicTrack.destinationAudioUnit = sampler
            musicTracks[track.id] = musicTrack
            writeEvents(for: track, into: musicTrack, beatScale: beatScale, beatsPerBar: beatsPerBar)
            if let layer = chain.layer {
                let layerTrack = sequencer.createAndAppendTrack()
                layerTrack.destinationAudioUnit = layer
                layerTracks[track.id] = layerTrack
                writeLayerEvents(for: track, into: layerTrack, beatScale: beatScale)
            }
        }
    }

    private func writeLayerEvents(for track: StudioTrack, into musicTrack: AVMusicTrack, beatScale: Double) {
        for note in track.notes {
            musicTrack.addEvent(
                AVMIDINoteEvent(
                    channel: 0,
                    key: UInt32(max(0, min(note.pitch, 127))),
                    velocity: UInt32(max(1, min(note.velocity, 127))),
                    duration: max(0.02, note.duration * beatScale)
                ),
                at: max(0, note.startBeat * beatScale)
            )
        }
    }

    /// Replaces one part's events in the running sequence. Returns false when
    /// the track isn't part of the current graph (caller should rebuild).
    @discardableResult
    func rewriteEvents(for track: StudioTrack, beatScale: Double, beatsPerBar: Int) -> Bool {
        guard let musicTrack = musicTracks[track.id], let chain = chains[track.id], let sampler = chain.sampler else {
            return false
        }
        let channel = midiChannel(for: track, chain: chain)
        musicTrack.clearEvents(in: AVMakeBeatRange(0, AVMusicTimeStampEndOfTrack))
        // Silence anything left hanging by the removed note-offs.
        sampler.sendController(64, withValue: 0, onChannel: UInt8(channel))
        sampler.sendController(123, withValue: 0, onChannel: UInt8(channel))
        writeEvents(for: track, into: musicTrack, beatScale: beatScale, beatsPerBar: beatsPerBar)
        if let layerTrack = layerTracks[track.id], let layer = chain.layer {
            layerTrack.clearEvents(in: AVMakeBeatRange(0, AVMusicTimeStampEndOfTrack))
            layer.sendController(123, withValue: 0, onChannel: 0)
            writeLayerEvents(for: track, into: layerTrack, beatScale: beatScale)
        }
        return true
    }

    private func midiChannel(for track: StudioTrack, chain: TrackChain) -> UInt32 {
        track.instrument == .drums && !chain.drumsOnMelodicBank ? 9 : 0
    }

    private func writeEvents(for track: StudioTrack, into musicTrack: AVMusicTrack, beatScale: Double, beatsPerBar: Int) {
        guard let chain = chains[track.id] else { return }
        let channel = midiChannel(for: track, chain: chain)

        // Reset controllers so a reused sampler starts clean.
        musicTrack.addEvent(AVMIDIControlChangeEvent(channel: channel, messageType: .sustain, value: 0), at: 0)
        musicTrack.addEvent(AVMIDIControlChangeEvent(channel: channel, messageType: .expression, value: 127), at: 0)

        for note in track.notes {
            let event = AVMIDINoteEvent(
                channel: channel,
                key: UInt32(max(0, min(note.pitch, 127))),
                velocity: UInt32(max(1, min(note.velocity, 127))),
                duration: max(0.02, note.duration * beatScale)
            )
            musicTrack.addEvent(event, at: max(0, note.startBeat * beatScale))
        }

        // Expression swells for sustained parts: soft verses, crescendo
        // through pre-choruses, full choruses, fading outros.
        if track.followsArrangement, let project = track.project,
           [.strings, .pad, .organ, .brass].contains(StudioSoundCatalog.role(for: track.instrument, variant: track.variant)) {
            var lastValue = -1
            for point in StudioArranger.expressionCurve(for: project) where point.value != lastValue {
                musicTrack.addEvent(
                    AVMIDIControlChangeEvent(channel: channel, messageType: .expression, value: UInt32(point.value)),
                    at: max(0, point.beat * beatScale)
                )
                lastValue = point.value
            }
        }

        if shouldPedal(track: track, profile: chain.profile) {
            for (beat, down) in Self.pedalEvents(for: track.notes, beatsPerBar: Double(beatsPerBar)) {
                musicTrack.addEvent(
                    AVMIDIControlChangeEvent(channel: channel, messageType: .sustain, value: down ? 127 : 0),
                    at: max(0, beat * beatScale)
                )
            }
        }
    }

    private func shouldPedal(track: StudioTrack, profile: StudioSoundCatalog.MixProfile) -> Bool {
        guard profile.sustainPedal, track.instrument == .piano else { return false }
        switch track.variant {
        case .harpsichord, .clavinet, .harp: return false
        default: break
        }
        switch track.compingPattern {
        case .stabs, .offbeat, .pulse, .tremolo: return false
        case .auto:
            switch style {
            case .funk, .edm, .hiphop: return false
            default: return true
            }
        default: return true
        }
    }

    /// Legato pedalling: lift just before each harmony change, press again just
    /// after the new chord sounds, so chords ring into each other without blur.
    static func pedalEvents(for notes: [StudioNote], beatsPerBar: Double) -> [(Double, Bool)] {
        guard !notes.isEmpty else { return [] }
        let sorted = notes.sorted { $0.startBeat < $1.startBeat }
        var groups: [(start: Double, pitchClasses: Set<Int>)] = []
        for note in sorted {
            if let last = groups.last, note.startBeat - last.start < 0.06 {
                groups[groups.count - 1].pitchClasses.insert(note.pitch % 12)
            } else {
                groups.append((note.startBeat, [note.pitch % 12]))
            }
        }

        var changes: [Double] = []
        var current: Set<Int> = []
        var lastChange = -Double.infinity
        for group in groups {
            let crossesBar = floor(group.start / beatsPerBar) != floor(lastChange / beatsPerBar)
            let isChord = group.pitchClasses.count >= 2
            // A new harmony: a chord whose pitches aren't a subset of what's
            // ringing, or the first event of a new bar (arpeggios).
            let newHarmony = isChord ? !group.pitchClasses.isSubset(of: current) : !current.contains(group.pitchClasses.first ?? -1) && crossesBar
            if changes.isEmpty || (newHarmony && group.start - lastChange >= 0.5) {
                changes.append(group.start)
                lastChange = group.start
                current = group.pitchClasses
            } else {
                current.formUnion(group.pitchClasses)
            }
        }

        var events: [(Double, Bool)] = []
        for (index, start) in changes.enumerated() {
            if index > 0 {
                events.append((max(0, start - 0.02), false))
            }
            events.append((start + 0.06, true))
        }
        let end = (sorted.map { $0.startBeat + $0.duration }.max() ?? 0)
        events.append((end + 0.25, false))
        return events
    }
}
