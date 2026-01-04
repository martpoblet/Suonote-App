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
        
        // Connect nodes
        let mainMixer = audioEngine.mainMixerNode
        let format = audioEngine.outputNode.inputFormat(forBus: 0)
        
        // Player -> EQ -> Compressor -> Delay -> Reverb -> Output
        audioEngine.connect(playerNode, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: compressorNode, format: format)
        audioEngine.connect(compressorNode, to: delayNode, format: format)
        audioEngine.connect(delayNode, to: reverbNode, format: format)
        audioEngine.connect(reverbNode, to: mainMixer, format: format)
        
        // Initial configuration
        reverbNode.loadFactoryPreset(.mediumHall)
        reverbNode.wetDryMix = 0
        
        delayNode.delayTime = 0.3
        delayNode.feedback = 30
        delayNode.wetDryMix = 0
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
        // Reverb
        if settings.reverbEnabled {
            reverbNode.wetDryMix = settings.reverbMix * 100 // 0-100
            // Adjust reverb size by changing preset or parameters
            if settings.reverbSize < 0.3 {
                reverbNode.loadFactoryPreset(.smallRoom)
            } else if settings.reverbSize < 0.7 {
                reverbNode.loadFactoryPreset(.mediumHall)
            } else {
                reverbNode.loadFactoryPreset(.cathedral)
            }
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
        // Note: Direct AudioUnit parameter manipulation requires more complex setup
        // For now, we'll use the bypass to enable/disable compression
        // Full implementation would require accessing the underlying AudioUnit directly
        compressorNode.bypass = !settings.compressionEnabled
    }
    
    // MARK: - Playback
    
    func playAudio(url: URL, completion: @escaping () -> Void) throws {
        let audioFile = try AVAudioFile(forReading: url)
        
        // Stop if already playing
        if audioEngine.isRunning {
            playerNode.stop()
            audioEngine.stop()
        }
        
        // Apply current effects
        applyEffects()
        
        // Prepare engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Schedule file
        playerNode.scheduleFile(audioFile, at: nil) {
            DispatchQueue.main.async {
                completion()
            }
        }
        
        playerNode.play()
    }
    
    func stop() {
        playerNode.stop()
        audioEngine.stop()
    }
    
    var isPlaying: Bool {
        return audioEngine.isRunning && playerNode.isPlaying
    }
}
