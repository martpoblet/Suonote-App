import os
import AVFoundation
import Combine

class AudioEffectsProcessor: ObservableObject {
    
    // MARK: - Effect Parameters
    
    struct EffectSettings {
        // Reverb
        var reverbEnabled: Bool = false
        var reverbMix: Float = 0.5 // 0.0 to 1.0
        var reverbSize: Float = 0.5 // 0.0 to 1.0
        
        // Delay
        var delayEnabled: Bool = false
        var delayTime: Float = 0.3 // seconds
        var delayFeedback: Float = 0.3 // 0.0 to 1.0
        var delayMix: Float = 0.3 // 0.0 to 1.0
        
        // EQ
        var eqEnabled: Bool = false
        var lowGain: Float = 0 // -24 to +24 dB
        var midGain: Float = 0 // -24 to +24 dB
        var highGain: Float = 0 // -24 to +24 dB
        
        // Compression
        var compressionEnabled: Bool = false
        var compressionThreshold: Float = -20 // dB
        var compressionRatio: Float = 4.0 // ratio
    }
    
    // MARK: - Audio Engine
    
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    
    // Effect nodes
    private var reverbNode: AVAudioUnitReverb
    private var delayNode: AVAudioUnitDelay
    private var eqNode: AVAudioUnitEQ
    private var compressorNode: AVAudioUnitEffect
    
    @Published var settings = EffectSettings()

    private var loadedReverbPreset: AVAudioUnitReverbPreset?
    private var chainFormat: AVAudioFormat?
    private var currentFile: AVAudioFile?
    /// Frame the current segment started at (for position + seeking).
    private var segmentStartFrame: AVAudioFramePosition = 0
    /// Bumped on every stop/seek so stale completion handlers are ignored
    /// (AVAudioPlayerNode fires the completion when it is stopped, too).
    private var playbackGeneration = 0
    private var completionHandler: (() -> Void)?
    
    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        // Initialize effects
        reverbNode = AVAudioUnitReverb()
        delayNode = AVAudioUnitDelay()
        eqNode = AVAudioUnitEQ(numberOfBands: 3)
        
        // Compression (using Dynamics Processor)
        let compressorDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        compressorNode = AVAudioUnitEffect(audioComponentDescription: compressorDesc)
        
        setupAudioEngine()
        configureEQ()
    }
    
    private func setupAudioEngine() {
        // Attach nodes
        audioEngine.attach(playerNode)
        audioEngine.attach(reverbNode)
        audioEngine.attach(delayNode)
        audioEngine.attach(eqNode)
        audioEngine.attach(compressorNode)
        
        connectChain(format: audioEngine.outputNode.inputFormat(forBus: 0))
        
        // Initial configuration
        reverbNode.loadFactoryPreset(.mediumHall)
        loadedReverbPreset = .mediumHall
        reverbNode.wetDryMix = 0
        
        delayNode.delayTime = 0.3
        delayNode.feedback = 30
        delayNode.wetDryMix = 0
    }
    
    /// Player -> EQ -> Compressor -> Delay -> Reverb -> Mixer, all in one
    /// format. Matching the file's sample rate avoids a resample inside the
    /// player; the main mixer converts to the hardware format.
    private func connectChain(format: AVAudioFormat?) {
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: compressorNode, format: format)
        audioEngine.connect(compressorNode, to: delayNode, format: format)
        audioEngine.connect(delayNode, to: reverbNode, format: format)
        audioEngine.connect(reverbNode, to: mainMixer, format: format)
        chainFormat = format
    }

    private func configureEQ() {
        // Low band (80 Hz)
        eqNode.bands[0].frequency = 80
        eqNode.bands[0].bandwidth = 1.0
        eqNode.bands[0].bypass = false
        eqNode.bands[0].filterType = .parametric
        
        // Mid band (1000 Hz)
        eqNode.bands[1].frequency = 1000
        eqNode.bands[1].bandwidth = 1.0
        eqNode.bands[1].bypass = false
        eqNode.bands[1].filterType = .parametric
        
        // High band (10000 Hz)
        eqNode.bands[2].frequency = 10000
        eqNode.bands[2].bandwidth = 1.0
        eqNode.bands[2].bypass = false
        eqNode.bands[2].filterType = .parametric
    }
    
    // MARK: - Apply Effects
    
    func applyEffects() {
        // Reverb — load the preset first: loading a factory preset resets
        // wetDryMix, so the mix must be applied afterwards.
        if settings.reverbEnabled {
            let preset: AVAudioUnitReverbPreset
            if settings.reverbSize < 0.3 {
                preset = .smallRoom
            } else if settings.reverbSize < 0.7 {
                preset = .mediumHall
            } else {
                preset = .cathedral
            }
            if preset != loadedReverbPreset {
                reverbNode.loadFactoryPreset(preset)
                loadedReverbPreset = preset
            }
            reverbNode.wetDryMix = settings.reverbMix * 100 // 0-100
        } else {
            reverbNode.wetDryMix = 0
        }
        
        // Delay
        if settings.delayEnabled {
            delayNode.delayTime = TimeInterval(settings.delayTime)
            delayNode.feedback = settings.delayFeedback * 100 // 0-100
            delayNode.wetDryMix = settings.delayMix * 100 // 0-100
        } else {
            delayNode.wetDryMix = 0
        }
        
        // EQ
        if settings.eqEnabled {
            eqNode.bands[0].gain = settings.lowGain
            eqNode.bands[1].gain = settings.midGain
            eqNode.bands[2].gain = settings.highGain
            eqNode.bypass = false
        } else {
            eqNode.bypass = true
        }
        
        // Compression - would need AudioUnit parameter manipulation
        // This is more complex and requires direct AudioUnit access
        if settings.compressionEnabled {
            compressorNode.bypass = false
            // Configure compression parameters through AudioUnit
            configureCompression()
        } else {
            compressorNode.bypass = true
        }
    }
    
    private func configureCompression() {
        compressorNode.bypass = !settings.compressionEnabled
        let unit = compressorNode.audioUnit
        // Dynamics Processor threshold range is -40...20 dB.
        let threshold = min(20, max(-40, settings.compressionThreshold))
        // No direct "ratio" parameter: approximate it with headroom
        // (smaller headroom above threshold = harder compression).
        let ratio = max(1, settings.compressionRatio)
        let headRoom = min(40, max(0.1, 20 / ratio))
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, threshold, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, headRoom, 0)
    }
    
    // MARK: - Playback
    
    func playAudio(url: URL, completion: @escaping () -> Void) throws {
        try playAudio(url: url, from: 0, completion: completion)
    }

    /// Plays `url` through the effects chain starting at `startTime` seconds.
    func playAudio(url: URL, from startTime: TimeInterval, completion: @escaping () -> Void) throws {
        configureAudioSessionForPlayback()
        let audioFile = try AVAudioFile(forReading: url)
        
        // Stop if already playing (and invalidate its completion)
        stop()

        // Run the chain at the file's sample rate (stereo, so reverb/delay
        // keep their width); the player node maps the mono take onto it.
        let fileRate = audioFile.processingFormat.sampleRate
        if chainFormat?.sampleRate != fileRate,
           let stereo = AVAudioFormat(standardFormatWithSampleRate: fileRate, channels: 2) {
            connectChain(format: stereo)
        }
        
        // Apply current effects
        applyEffects()
        
        // Prepare engine
        audioEngine.prepare()
        try audioEngine.start()

        currentFile = audioFile
        completionHandler = completion
        scheduleSegment(from: startTime)
    }

    /// Jumps to `time` (seconds) in the file that is currently loaded.
    func seek(to time: TimeInterval) {
        guard currentFile != nil else { return }
        let wasPlaying = playerNode.isPlaying
        playbackGeneration += 1
        playerNode.stop()
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        scheduleSegment(from: time, play: wasPlaying || audioEngine.isRunning)
    }

    private func scheduleSegment(from time: TimeInterval, play: Bool = true) {
        guard let file = currentFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = min(max(0, AVAudioFramePosition(time * sampleRate)), max(0, file.length - 1))
        let frames = AVAudioFrameCount(max(0, file.length - startFrame))
        segmentStartFrame = startFrame
        playbackGeneration += 1
        let generation = playbackGeneration
        guard frames > 0 else { return }

        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil) { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.playbackGeneration == generation else { return }
                self.completionHandler?()
            }
        }
        if play {
            playerNode.play()
        }
    }
    
    func stop() {
        playbackGeneration += 1
        playerNode.stop()
        audioEngine.stop()
    }
    
    var isPlaying: Bool {
        return audioEngine.isRunning && playerNode.isPlaying
    }

    /// Length of the loaded file in seconds.
    var duration: TimeInterval {
        guard let file = currentFile else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// Current playback position in seconds.
    var currentTime: TimeInterval {
        guard let file = currentFile else { return 0 }
        let sampleRate = file.processingFormat.sampleRate
        var frame = segmentStartFrame
        if playerNode.isPlaying,
           let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            frame += max(0, playerTime.sampleTime)
        }
        return min(Double(frame) / sampleRate, duration)
    }

    private func configureAudioSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            AppLog.audio.error("Failed to configure audio session: \(String(describing: error))")
        }
    }
}
