import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio

/// Suonote's own virtual-analog synthesizer, as an in-process Audio Unit so
/// `AVAudioSequencer` can play it exactly like a sampler.
///
/// Why: General MIDI synth pads/basses are the most "dated" sounds in any
/// SoundFont. Two detuned band-limited saws + a sub oscillator through a
/// resonant filter with its own envelope gives modern, warm pads and basses
/// at zero bundle size.
///
/// Realtime notes: all DSP state lives in preallocated unsafe buffers owned
/// by `SynthKernel`; the render block captures only that kernel and never
/// allocates, locks or touches Swift collections.
nonisolated final class SuonoteSynthAudioUnit: AUAudioUnit {

    static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_MusicDevice,
        componentSubType: 0x736E5379,          // 'snSy'
        componentManufacturer: 0x53756F6E,     // 'Suon'
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private static let registration: Void = {
        AUAudioUnit.registerSubclass(
            SuonoteSynthAudioUnit.self,
            as: componentDescription,
            name: "Suonote: Synth",
            version: 1
        )
    }()

    /// Call once before instantiating (idempotent).
    static func register() { _ = registration }

    private let kernel = SynthKernel()
    private var outputBus: AUAudioUnitBus!
    private var outputBusArray: AUAudioUnitBusArray!

    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = 2
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        maximumFramesToRender = 4_096
    }

    override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    override var channelCapabilities: [NSNumber]? { [0, 2] }

    /// Which sound to play. Safe to set before rendering starts.
    var preset: SynthPreset {
        get { kernel.preset }
        set { kernel.setPreset(newValue) }
    }

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        kernel.prepare(sampleRate: outputBus.format.sampleRate)
    }

    override func deallocateRenderResources() {
        kernel.reset()
        super.deallocateRenderResources()
    }

    override var internalRenderBlock: AUInternalRenderBlock {
        let kernel = self.kernel
        return { _, timestamp, frameCount, _, outputData, realtimeEventListHead, _ in
            kernel.render(
                frameCount: frameCount,
                startSample: AUEventSampleTime(timestamp.pointee.mSampleTime),
                output: outputData,
                events: realtimeEventListHead
            )
            return noErr
        }
    }
}

// MARK: - Presets

struct SynthPreset: Equatable, Sendable {
    var saw2Detune: Double      // cents
    var sawMix: Double          // saw level (each)
    var subLevel: Double        // sine level
    var subRatio: Double = 0.5  // sine frequency vs. the note (0.5 = octave down)
    var cutoff: Double          // Hz
    var envAmount: Double       // Hz added at filter envelope peak
    var keyTrack: Double        // 0…1 cutoff follows pitch
    var resonance: Double       // 0…0.9
    var velocityToCutoff: Double
    var ampAttack: Double, ampDecay: Double, ampSustain: Double, ampRelease: Double
    var filterAttack: Double, filterDecay: Double, filterSustain: Double, filterRelease: Double
    var stereoSpread: Double    // 0…1
    var gain: Double

    static let analogPad = SynthPreset(
        saw2Detune: 11, sawMix: 0.5, subLevel: 0.25, cutoff: 900, envAmount: 1_400, keyTrack: 0.35,
        resonance: 0.18, velocityToCutoff: 0.4,
        ampAttack: 0.55, ampDecay: 1.2, ampSustain: 0.85, ampRelease: 1.3,
        filterAttack: 0.9, filterDecay: 1.6, filterSustain: 0.45, filterRelease: 1.2,
        stereoSpread: 0.7, gain: 0.55)

    static let glassPad = SynthPreset(
        saw2Detune: 7, sawMix: 0.45, subLevel: 0.0, cutoff: 2_400, envAmount: 2_200, keyTrack: 0.5,
        resonance: 0.32, velocityToCutoff: 0.5,
        ampAttack: 0.25, ampDecay: 0.9, ampSustain: 0.75, ampRelease: 1.6,
        filterAttack: 0.05, filterDecay: 1.4, filterSustain: 0.3, filterRelease: 1.4,
        stereoSpread: 0.85, gain: 0.45)

    static let supersaw = SynthPreset(
        saw2Detune: 22, sawMix: 0.55, subLevel: 0.15, cutoff: 3_800, envAmount: 2_500, keyTrack: 0.4,
        resonance: 0.12, velocityToCutoff: 0.5,
        ampAttack: 0.02, ampDecay: 0.6, ampSustain: 0.8, ampRelease: 0.45,
        filterAttack: 0.01, filterDecay: 0.7, filterSustain: 0.5, filterRelease: 0.4,
        stereoSpread: 1.0, gain: 0.42)

    static let softPluck = SynthPreset(
        saw2Detune: 6, sawMix: 0.5, subLevel: 0.1, cutoff: 700, envAmount: 4_200, keyTrack: 0.6,
        resonance: 0.25, velocityToCutoff: 0.8,
        ampAttack: 0.003, ampDecay: 0.65, ampSustain: 0.0, ampRelease: 0.35,
        filterAttack: 0.001, filterDecay: 0.22, filterSustain: 0.0, filterRelease: 0.2,
        stereoSpread: 0.5, gain: 0.6)

    static let analogBass = SynthPreset(
        saw2Detune: 4, sawMix: 0.5, subLevel: 0.6, cutoff: 260, envAmount: 1_500, keyTrack: 0.3,
        resonance: 0.35, velocityToCutoff: 0.7,
        ampAttack: 0.003, ampDecay: 0.4, ampSustain: 0.8, ampRelease: 0.09,
        filterAttack: 0.001, filterDecay: 0.18, filterSustain: 0.15, filterRelease: 0.08,
        stereoSpread: 0.0, gain: 0.7)

    /// Pure, soft sine sub to sit under a sampled bass (layer, not a solo sound).
    static let subLayer = SynthPreset(
        saw2Detune: 0, sawMix: 0.0, subLevel: 1.0, subRatio: 1.0, cutoff: 140, envAmount: 0, keyTrack: 0,
        resonance: 0, velocityToCutoff: 0,
        ampAttack: 0.008, ampDecay: 0.25, ampSustain: 0.9, ampRelease: 0.07,
        filterAttack: 0.001, filterDecay: 0.1, filterSustain: 1, filterRelease: 0.1,
        stereoSpread: 0.0, gain: 0.7)

    static let subBass = SynthPreset(
        saw2Detune: 0, sawMix: 0.12, subLevel: 1.0, subRatio: 1.0, cutoff: 180, envAmount: 300, keyTrack: 0.2,
        resonance: 0.05, velocityToCutoff: 0.3,
        ampAttack: 0.005, ampDecay: 0.3, ampSustain: 0.95, ampRelease: 0.12,
        filterAttack: 0.001, filterDecay: 0.1, filterSustain: 0.5, filterRelease: 0.1,
        stereoSpread: 0.0, gain: 0.85)
}

// MARK: - DSP kernel

nonisolated final class SynthKernel: @unchecked Sendable {
    private static let voiceCount = 16

    private struct Voice {
        var active = false
        var releasing = false
        var held = false            // released while sustain pedal down
        var note: UInt8 = 0
        var velocity: Double = 0
        var phase1 = 0.0, phase2 = 0.0, phaseSub = 0.0
        var inc1 = 0.0, inc2 = 0.0, incSub = 0.0
        var amp = 0.0, ampStage = 0      // 0 attack 1 decay 2 sustain 3 release
        var fenv = 0.0, fenvStage = 0
        var lowL = 0.0, bandL = 0.0, lowR = 0.0, bandR = 0.0
        var pan = 0.5
        var age: UInt64 = 0
        // Filter coefficients, refreshed every `controlRate` samples.
        var a1 = 1.0, a2 = 0.0, a3 = 0.0
        var controlCounter = 0
    }

    /// Envelope → filter updates happen at this sub-rate (inaudible, ~16x cheaper).
    private static let controlRate = 16

    private let voices = UnsafeMutablePointer<Voice>.allocate(capacity: voiceCount)
    private var sampleRate = 44_100.0
    private var clock: UInt64 = 0
    private var sustain = false
    private var expression = 1.0
    private(set) var preset = SynthPreset.analogPad

    init() {
        voices.initialize(repeating: Voice(), count: Self.voiceCount)
    }

    deinit {
        voices.deinitialize(count: Self.voiceCount)
        voices.deallocate()
    }

    func setPreset(_ preset: SynthPreset) { self.preset = preset }

    func prepare(sampleRate: Double) {
        self.sampleRate = sampleRate > 0 ? sampleRate : 44_100
        reset()
    }

    func reset() {
        for i in 0..<Self.voiceCount { voices[i] = Voice() }
        sustain = false
        expression = 1
    }

    // MARK: Events

    private func handleMIDI(_ status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        let type = status & 0xF0
        switch type {
        case 0x90 where data2 > 0:
            noteOn(data1, velocity: data2)
        case 0x80, 0x90:
            noteOff(data1)
        case 0xB0:
            switch data1 {
            case 64:
                sustain = data2 >= 64
                if !sustain {
                    for i in 0..<Self.voiceCount where voices[i].held {
                        voices[i].held = false
                        voices[i].releasing = true
                        voices[i].ampStage = 3
                        voices[i].fenvStage = 3
                    }
                }
            case 11: expression = Double(data2) / 127
            case 120, 123:
                for i in 0..<Self.voiceCount { voices[i].releasing = true; voices[i].ampStage = 3; voices[i].fenvStage = 3 }
            default: break
            }
        default: break
        }
    }

    private func noteOn(_ note: UInt8, velocity: UInt8) {
        clock &+= 1
        // Reuse the same note if it's still sounding, else a free voice, else steal the oldest.
        var index = -1
        var oldest: UInt64 = .max
        for i in 0..<Self.voiceCount {
            if voices[i].active && voices[i].note == note { index = i; break }
        }
        if index < 0 {
            for i in 0..<Self.voiceCount where !voices[i].active { index = i; break }
        }
        if index < 0 {
            for i in 0..<Self.voiceCount where voices[i].age < oldest { oldest = voices[i].age; index = i }
        }
        let freq = 440 * pow(2, (Double(note) - 69) / 12)
        let detune = pow(2, preset.saw2Detune / 1200)
        var v = voices[index]
        let wasActive = v.active
        v.active = true
        v.releasing = false
        v.held = false
        v.note = note
        v.velocity = Double(velocity) / 127
        v.inc1 = freq / sampleRate
        v.inc2 = freq * detune / sampleRate
        v.incSub = freq * preset.subRatio / sampleRate
        if !wasActive {
            // Random-ish start phases so stacked voices don't phase-cancel.
            v.phase1 = Double((clock &* 2654435761) % 1000) / 1000
            v.phase2 = Double((clock &* 40503) % 1000) / 1000
            v.phaseSub = 0
            v.amp = 0
            v.lowL = 0; v.bandL = 0; v.lowR = 0; v.bandR = 0
        }
        v.ampStage = 0
        v.fenvStage = 0
        v.controlCounter = 0
        // Spread voices across the stereo field by pitch.
        v.pan = 0.5 + (Double(Int(note % 12) - 6) / 12) * preset.stereoSpread * 0.8
        v.age = clock
        voices[index] = v
    }

    private func noteOff(_ note: UInt8) {
        for i in 0..<Self.voiceCount where voices[i].active && voices[i].note == note && !voices[i].releasing {
            if sustain {
                voices[i].held = true
            } else {
                voices[i].releasing = true
                voices[i].ampStage = 3
                voices[i].fenvStage = 3
            }
        }
    }

    // MARK: Render

    @_optimize(speed) @inline(__always)
    private func polyBLEP(_ t: Double, _ dt: Double) -> Double {
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        } else if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    @_optimize(speed) @inline(__always)
    private func envelopeStep(_ level: inout Double, _ stage: inout Int, attack: Double, decay: Double, sustain: Double, release: Double) {
        switch stage {
        case 0:
            level += 1 / max(1, attack * sampleRate)
            if level >= 1 { level = 1; stage = 1 }
        case 1:
            level += (sustain - level) * (1 - exp(-4 / max(1, decay * sampleRate)))
            if abs(level - sustain) < 0.001 { stage = 2 }
        case 2:
            level = sustain
        default:
            level *= exp(-4.6 / max(1, release * sampleRate))
        }
    }

    @_optimize(speed)
    func render(frameCount: AUAudioFrameCount, startSample: AUEventSampleTime, output: UnsafeMutablePointer<AudioBufferList>, events: UnsafePointer<AURenderEvent>?) {
        let buffers = UnsafeMutableAudioBufferListPointer(output)
        guard buffers.count >= 1 else { return }
        let left = buffers[0].mData?.assumingMemoryBound(to: Float.self)
        let right = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : left
        guard let left, let right else { return }

        var event = events
        let frames = Int(frameCount)
        let p = preset
        let twoPi = 2 * Double.pi
        for frame in 0..<frames {
            // Apply events due at this frame (sample accurate).
            while let current = event {
                let header = current.pointee.head
                // Render-event times are absolute; make them buffer-relative.
                let eventFrame = Int(header.eventSampleTime - startSample)
                if header.eventType == .MIDI || header.eventType == .midiSysEx {
                    if eventFrame > frame && eventFrame < frames { break }
                    let midi = current.pointee.MIDI
                    if midi.length >= 1 {
                        handleMIDI(midi.data.0, midi.length > 1 ? midi.data.1 : 0, midi.length > 2 ? midi.data.2 : 0)
                    }
                }
                event = UnsafePointer(header.next)
            }

            var outL = 0.0, outR = 0.0
            for i in 0..<Self.voiceCount where voices[i].active {
                var v = voices[i]
                envelopeStep(&v.amp, &v.ampStage, attack: p.ampAttack, decay: p.ampDecay, sustain: p.ampSustain, release: p.ampRelease)
                envelopeStep(&v.fenv, &v.fenvStage, attack: p.filterAttack, decay: p.filterDecay, sustain: p.filterSustain, release: p.filterRelease)
                if v.releasing && v.amp < 0.0005 {
                    v.active = false
                    voices[i] = v
                    continue
                }

                // Oscillators: two band-limited saws + sine sub.
                var s1 = 2 * v.phase1 - 1
                s1 -= polyBLEP(v.phase1, v.inc1)
                var s2 = 2 * v.phase2 - 1
                s2 -= polyBLEP(v.phase2, v.inc2)
                let sub = sin(twoPi * v.phaseSub)
                v.phase1 += v.inc1; if v.phase1 >= 1 { v.phase1 -= 1 }
                v.phase2 += v.inc2; if v.phase2 >= 1 { v.phase2 -= 1 }
                v.phaseSub += v.incSub; if v.phaseSub >= 1 { v.phaseSub -= 1 }
                let oscL = s1 * p.sawMix + s2 * p.sawMix * 0.6 + sub * p.subLevel
                let oscR = s1 * p.sawMix * 0.6 + s2 * p.sawMix + sub * p.subLevel

                // State-variable low-pass with envelope, key-tracking and velocity.
                if v.controlCounter == 0 {
                    let noteFreq = v.inc1 * sampleRate
                    var cutoff = p.cutoff * (1 + p.keyTrack * (noteFreq / 261.6 - 1))
                    cutoff += p.envAmount * v.fenv * (1 - p.velocityToCutoff + p.velocityToCutoff * v.velocity)
                    cutoff = min(max(cutoff, 30), sampleRate * 0.45)
                    // Zero-delay-feedback (TPT) state-variable low-pass: stable at
                    // every cutoff, unlike the classic Chamberlin form.
                    let g = tan(Double.pi * cutoff / sampleRate)
                    let k = 2 - 1.8 * p.resonance
                    v.a1 = 1 / (1 + g * (g + k))
                    v.a2 = g * v.a1
                    v.a3 = g * v.a2
                }
                v.controlCounter = (v.controlCounter + 1) % Self.controlRate
                let a1 = v.a1, a2 = v.a2, a3 = v.a3
                // Left (lowL = ic2eq, bandL = ic1eq)
                let v3L = oscL - v.lowL
                let v1L = a1 * v.bandL + a2 * v3L
                let v2L = v.lowL + a2 * v.bandL + a3 * v3L
                v.bandL = 2 * v1L - v.bandL
                v.lowL = 2 * v2L - v.lowL
                // Right
                let v3R = oscR - v.lowR
                let v1R = a1 * v.bandR + a2 * v3R
                let v2R = v.lowR + a2 * v.bandR + a3 * v3R
                v.bandR = 2 * v1R - v.bandR
                v.lowR = 2 * v2R - v.lowR
                if !v2L.isFinite || !v2R.isFinite {
                    v.lowL = 0; v.bandL = 0; v.lowR = 0; v.bandR = 0
                    voices[i] = v
                    continue
                }

                let level = v.amp * (0.35 + 0.65 * v.velocity)
                outL += v2L * level * (1 - v.pan) * 2
                outR += v2R * level * v.pan * 2
                voices[i] = v
            }
            let gain = p.gain * expression * 0.3
            // Gentle soft clip so stacked voices never crackle.
            let l = tanh(outL * gain), r = tanh(outR * gain)
            left[frame] = l.isFinite ? Float(l) : 0
            right[frame] = r.isFinite ? Float(r) : 0
        }
    }
}
