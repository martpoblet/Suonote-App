import Foundation
import AVFoundation
import AudioToolbox
import Combine
import os

/// Auditions a Studio sound before you pick it: a short, idiomatic phrase
/// (a groove for kits, a line for basses, a voiced chord for keys and pads,
/// a melodic figure for leads) through the same loudness-matched preset the
/// mix uses. Independent of the Studio engine so it never disturbs playback.
@MainActor
final class StudioSoundPreviewer: ObservableObject {
    static let shared = StudioSoundPreviewer()

    /// The variant currently sounding (for "playing" indicators in pickers).
    @Published private(set) var previewingVariant: InstrumentVariant?

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private lazy var synth: AVAudioUnitMIDIInstrument = {
        SuonoteSynthAudioUnit.register()
        return AVAudioUnitMIDIInstrument(audioComponentDescription: SuonoteSynthAudioUnit.componentDescription)
    }()
    private let inputMix = AVAudioMixerNode()
    /// The instrument currently auditioning (sampler or synth).
    private var current: AVAudioUnitMIDIInstrument?
    private let tone = AVAudioUnitEQ(numberOfBands: 1)
    private let room = AVAudioUnitReverb()
    private var isSetup = false
    private var loadedKey: String?
    private var workItems: [DispatchWorkItem] = []
    private var sounding: Set<UInt8> = []
    private var channel: UInt8 = 0

    private init() {}

    private func setupIfNeeded() -> Bool {
        if isSetup {
            if !engine.isRunning { try? engine.start() }
            return engine.isRunning
        }
        [sampler, synth, inputMix, tone, room].forEach { engine.attach($0) }
        // Configure units before connecting (parameter-tree rebuild race).
        tone.bands[0].filterType = .highPass
        tone.bands[0].frequency = 35
        tone.bands[0].bypass = false
        room.loadFactoryPreset(.mediumRoom)
        room.wetDryMix = 14
        engine.connect(sampler, to: inputMix, format: nil)
        engine.connect(synth, to: inputMix, format: nil)
        engine.connect(inputMix, to: tone, format: nil)
        engine.connect(tone, to: room, format: nil)
        engine.connect(room, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.8
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isSetup = true
        } catch {
            AppLog.audio.error("Sound preview engine failed: \(String(describing: error))")
        }
        return isSetup
    }

    /// Plays a short phrase for `variant` in `keyRoot` (defaults to C).
    func preview(instrument: StudioInstrument, variant: InstrumentVariant?, keyRoot: String = "C") {
        stop()
        guard !instrument.isAudio, setupIfNeeded(),
              let resolved = SoundFontManager.resolvedVariant(for: instrument, variant: variant),
              load(resolved, instrument: instrument) else { return }

        previewingVariant = resolved
        let root = ChordPreviewPlayer.pitchClass(of: keyRoot) ?? 0
        let role = StudioSoundCatalog.role(for: instrument, variant: resolved)
        channel = resolved.isDrumKit ? 9 : 0

        switch role {
        case .drums:
            playGroove()
        case .bass:
            let base = 36 + root   // C2 region
            playLine([base, base + 7, base + 12, base + 7, base], step: 0.3, length: 0.28, velocity: 96)
        case .lead, .winds, .mallets:
            let base = (role == .mallets ? 72 : 67) + root % 12 - (root > 5 ? 12 : 0)
            playLine([base, base + 4, base + 7, base + 12, base + 7], step: 0.22, length: 0.24, velocity: 92, lastLength: 0.9)
        case .guitar:
            let base = 52 + root % 12 - (root > 7 ? 12 : 0)
            playChord([base, base + 7, base + 12, base + 16, base + 19], roll: 0.022, velocity: 90, hold: 1.4)
        case .keys, .pad, .strings, .organ, .brass:
            let bass = 48 + root
            let upper = [bass + 12 + 4, bass + 12 + 7, bass + 12 + 11, bass + 24 + 2]
            let hold = role == .pad || role == .strings ? 1.8 : 1.3
            playChord([bass] + upper, roll: role == .keys ? 0.012 : 0, velocity: 84, hold: hold)
        }
    }

    /// Plays a single note on a track's sound (piano-roll keyboard, new notes).
    /// Unlike `preview`, it doesn't stop other sounding notes, so you can play
    /// several keys in a row.
    func playNote(instrument: StudioInstrument, variant: InstrumentVariant?, pitch: Int, velocity: UInt8 = 96) {
        guard !instrument.isAudio, setupIfNeeded(),
              let resolved = SoundFontManager.resolvedVariant(for: instrument, variant: variant) else { return }
        if previewingVariant != nil { stop() }
        guard load(resolved, instrument: instrument) else { return }
        channel = resolved.isDrumKit ? 9 : 0
        let role = StudioSoundCatalog.role(for: instrument, variant: resolved)
        let length: Double = role == .drums ? 0.3 : (role == .pad || role == .strings ? 1.2 : 0.7)
        noteOn(pitch, velocity: velocity, at: 0, length: length)
        after(length + 2) { [weak self] in
            guard let self, self.sounding.isEmpty else { return }
            self.engine.pause()
        }
    }

    func stop() {
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
        for note in sounding {
            current?.stopNote(note, onChannel: channel)
        }
        sounding.removeAll()
        current?.sendController(64, withValue: 0, onChannel: channel)
        previewingVariant = nil
    }

    // MARK: - Loading

    private func load(_ variant: InstrumentVariant, instrument: StudioInstrument) -> Bool {
        let key = variant.rawValue
        tone.globalGain = StudioSoundCatalog.loudnessTrimDB(for: variant, instrument: instrument)
        if let preset = StudioSoundCatalog.synthPreset(for: variant) {
            (synth.auAudioUnit as? SuonoteSynthAudioUnit)?.preset = preset
            current = synth
            return true
        }
        current = sampler
        if loadedKey == key { return true }
        guard let url = SoundFontManager.soundFontURL(for: instrument, variant: variant) else { return false }
        let preset = StudioSoundCatalog.preset(for: variant)
        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: preset.program,
                bankMSB: UInt8(preset.isPercussion ? kAUSampler_DefaultPercussionBankMSB : kAUSampler_DefaultMelodicBankMSB),
                bankLSB: preset.isPercussion ? 0 : preset.bankVariation
            )
            loadedKey = key
            return true
        } catch {
            AppLog.audio.error("Preview load failed for \(variant.rawValue)")
            return false
        }
    }

    // MARK: - Phrases

    private func after(_ seconds: Double, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        workItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func noteOn(_ pitch: Int, velocity: UInt8, at time: Double, length: Double) {
        let note = UInt8(max(0, min(127, pitch)))
        after(time) { [weak self] in
            guard let self else { return }
            self.sounding.insert(note)
            self.current?.startNote(note, withVelocity: velocity, onChannel: self.channel)
        }
        after(time + length) { [weak self] in
            guard let self else { return }
            self.current?.stopNote(note, onChannel: self.channel)
            self.sounding.remove(note)
        }
    }

    private func finish(at time: Double) {
        after(time) { [weak self] in self?.previewingVariant = nil }
        after(time + 2) { [weak self] in
            guard let self, self.sounding.isEmpty else { return }
            self.engine.pause()   // idle engines still burn CPU
        }
    }

    private func playLine(_ pitches: [Int], step: Double, length: Double, velocity: UInt8, lastLength: Double? = nil) {
        for (index, pitch) in pitches.enumerated() {
            let isLast = index == pitches.count - 1
            let accent: UInt8 = index == 0 ? 8 : 0
            noteOn(pitch, velocity: min(127, velocity + accent), at: Double(index) * step,
                   length: isLast ? (lastLength ?? length) : length)
        }
        finish(at: Double(pitches.count - 1) * step + (lastLength ?? length) + 0.3)
    }

    private func playChord(_ pitches: [Int], roll: Double, velocity: UInt8, hold: Double) {
        current?.sendController(64, withValue: 127, onChannel: channel)
        for (index, pitch) in pitches.enumerated() {
            let voiceVelocity = index == 0 ? velocity : max(50, velocity - 12)
            noteOn(pitch, velocity: voiceVelocity, at: Double(index) * roll, length: hold)
        }
        after(hold + 0.25) { [weak self] in
            guard let self else { return }
            self.current?.sendController(64, withValue: 0, onChannel: self.channel)
        }
        finish(at: hold + 0.5)
    }

    private func playGroove() {
        let step = 0.16   // 16ths at ~94 bpm
        let kick = [0, 6, 8], snare = [4, 12], hats = Array(stride(from: 0, to: 16, by: 2))
        for i in kick { noteOn(36, velocity: 110, at: Double(i) * step, length: 0.1) }
        for i in snare { noteOn(38, velocity: 104, at: Double(i) * step, length: 0.1) }
        for i in hats { noteOn(42, velocity: i % 4 == 0 ? 88 : 64, at: Double(i) * step, length: 0.08) }
        noteOn(49, velocity: 90, at: 16 * step, length: 0.4)
        noteOn(36, velocity: 112, at: 16 * step, length: 0.1)
        finish(at: 16 * step + 0.8)
    }
}
