import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio

/// A bass "amp" for sampled electric basses: the clean signal keeps the low
/// end, and a parallel path saturates only the mids (band-limited, like a
/// DI + amp blend). The added harmonics are what make a bass audible and
/// growly on phone and laptop speakers, which can't reproduce its fundamental.
///
/// Realtime notes: the kernel preallocates its buffers; the render block
/// never allocates, locks or touches Swift collections.
nonisolated final class SuonoteBassAmpUnit: AUAudioUnit {

    static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: 0x736E4241,          // 'snBA'
        componentManufacturer: 0x53756F6E,     // 'Suon'
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private static let registration: Void = {
        AUAudioUnit.registerSubclass(
            SuonoteBassAmpUnit.self,
            as: componentDescription,
            name: "Suonote: Bass Amp",
            version: 1
        )
    }()

    /// Call once before instantiating (idempotent).
    static func register() { _ = registration }

    private let kernel = BassAmpKernel()
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!

    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        inputBus = try AUAudioUnitBus(format: format)
        inputBus.maximumChannelCount = 2
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = 2
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        maximumFramesToRender = 4_096
    }

    override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    override var outputBusses: AUAudioUnitBusArray { outputBusArray }
    override var channelCapabilities: [NSNumber]? { [2, 2] }

    /// 0 = clean … 1 = the default growl. Set before rendering starts.
    var drive: Double {
        get { kernel.drive }
        set { kernel.drive = max(0, min(1.5, newValue)) }
    }

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        kernel.prepare(sampleRate: outputBus.format.sampleRate, maxFrames: Int(maximumFramesToRender))
    }

    override func deallocateRenderResources() {
        kernel.release()
        super.deallocateRenderResources()
    }

    override var internalRenderBlock: AUInternalRenderBlock {
        let kernel = self.kernel
        return { _, timestamp, frameCount, _, outputData, _, pullInputBlock in
            guard let pullInputBlock else { return kAudioUnitErr_NoConnection }
            guard let input = kernel.inputList(frameCount: frameCount) else { return kAudioUnitErr_TooManyFramesToProcess }
            var flags = AudioUnitRenderActionFlags()
            let status = pullInputBlock(&flags, timestamp, frameCount, 0, input)
            guard status == noErr else { return status }
            kernel.process(frameCount: Int(frameCount), input: input, output: outputData)
            return noErr
        }
    }
}

/// DSP state for `SuonoteBassAmpUnit`.
nonisolated final class BassAmpKernel: @unchecked Sendable {
    var drive: Double = 1

    private var sampleRate: Double = 44_100
    private var maxFrames = 0
    private var left: UnsafeMutablePointer<Float>?
    private var right: UnsafeMutablePointer<Float>?
    private let list = AudioBufferList.allocate(maximumBuffers: 2)

    // Per channel: high-pass into the saturator, low-pass after it (TPT one-poles).
    private var hpState: (Float, Float) = (0, 0)
    private var lpState: (Float, Float) = (0, 0)
    private var lp2State: (Float, Float) = (0, 0)
    private var hpG: Float = 0
    private var lpG: Float = 0

    func prepare(sampleRate: Double, maxFrames: Int) {
        release()
        self.sampleRate = sampleRate
        self.maxFrames = maxFrames
        left = .allocate(capacity: maxFrames)
        right = .allocate(capacity: maxFrames)
        left?.initialize(repeating: 0, count: maxFrames)
        right?.initialize(repeating: 0, count: maxFrames)
        hpG = Self.onePoleG(cutoff: 220, sampleRate: sampleRate)
        lpG = Self.onePoleG(cutoff: 2_800, sampleRate: sampleRate)
        hpState = (0, 0); lpState = (0, 0); lp2State = (0, 0)
    }

    func release() {
        left?.deallocate(); left = nil
        right?.deallocate(); right = nil
        maxFrames = 0
    }

    private static func onePoleG(cutoff: Double, sampleRate: Double) -> Float {
        let g = tan(Double.pi * min(cutoff, sampleRate * 0.45) / sampleRate)
        return Float(g / (1 + g))
    }

    /// Points the pull buffer list at our scratch buffers.
    func inputList(frameCount: AUAudioFrameCount) -> UnsafeMutablePointer<AudioBufferList>? {
        guard let left, let right, Int(frameCount) <= maxFrames else { return nil }
        let bytes = UInt32(Int(frameCount) * MemoryLayout<Float>.size)
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(left))
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(right))
        return list.unsafeMutablePointer
    }

    @_optimize(speed)
    func process(frameCount: Int, input: UnsafeMutablePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        let inputs = UnsafeMutableAudioBufferListPointer(input)
        let outputs = UnsafeMutableAudioBufferListPointer(output)
        // Saturation amount, blend, and a makeup that keeps the overall level steady.
        let amount = Float(drive)
        let preGain: Float = 1 + 4.5 * amount
        let mix: Float = 0.6 * min(1, amount)
        let bias: Float = 0.18
        let biasOffset = tanhf(bias)
        let outGain: Float = 1 / (1 + 0.45 * mix)

        for channel in 0..<min(2, outputs.count) {
            guard channel < inputs.count, let src = inputs[channel].mData?.assumingMemoryBound(to: Float.self) else { continue }
            if outputs[channel].mData == nil { outputs[channel].mData = inputs[channel].mData }
            guard let dst = outputs[channel].mData?.assumingMemoryBound(to: Float.self) else { continue }
            outputs[channel].mDataByteSize = UInt32(frameCount * MemoryLayout<Float>.size)

            var hp = channel == 0 ? hpState.0 : hpState.1
            var lp = channel == 0 ? lpState.0 : lpState.1
            var lp2 = channel == 0 ? lp2State.0 : lp2State.1
            for i in 0..<frameCount {
                let x = src[i]
                // One-pole high-pass: keep the fundamental out of the saturator.
                let v = (x - hp) * hpG
                let low = v + hp
                hp = low + v
                let mids = x - low
                // Asymmetric soft clip → even + odd harmonics, like a driven amp.
                let shaped = tanhf(mids * preGain + bias) - biasOffset
                // Two one-pole low-passes: speaker-cabinet roll-off, no fizz.
                let v1 = (shaped - lp) * lpG
                let y1 = v1 + lp
                lp = y1 + v1
                let v2 = (y1 - lp2) * lpG
                let y2 = v2 + lp2
                lp2 = y2 + v2
                var out = (x + mix * y2) * outGain
                if !out.isFinite { out = 0; hp = 0; lp = 0; lp2 = 0 }
                dst[i] = out
            }
            if channel == 0 { hpState.0 = hp; lpState.0 = lp; lp2State.0 = lp2 }
            else { hpState.1 = hp; lpState.1 = lp; lp2State.1 = lp2 }
        }
    }
}
