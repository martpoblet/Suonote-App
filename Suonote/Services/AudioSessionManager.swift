import AVFoundation

/// Shared audio session and engine management (A-04)
/// Coordinates audio sessions across MetronomeClickPlayer, ChordPreviewPlayer,
/// AudioEffectsProcessor, and StudioPlaybackEngine to prevent conflicts.
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private(set) var isSessionActive = false
    
    private init() {}
    
    /// Configure and activate the shared audio session
    func activateSession(category: AVAudioSession.Category = .playAndRecord,
                         options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothA2DP]) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category, options: options)
            try session.setActive(true)
            isSessionActive = true
        } catch {
            print("[AudioSessionManager] Failed to activate session: \(error)")
        }
    }
    
    /// Deactivate when no engines need the session
    func deactivateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
        } catch {
            print("[AudioSessionManager] Failed to deactivate session: \(error)")
        }
    }
    
    /// Configure session for recording
    func configureForRecording() {
        activateSession(
            category: .playAndRecord,
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.005)
        } catch {
            print("[AudioSessionManager] Failed to configure recording: \(error)")
        }
    }
    
    /// Configure session for playback only
    func configureForPlayback() {
        activateSession(
            category: .playback,
            options: [.mixWithOthers]
        )
    }
    
    /// Configure for simultaneous playback and recording (overdub — P-05)
    func configureForOverdub() {
        activateSession(
            category: .playAndRecord,
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
    }
    
    /// Handle audio interruptions (phone calls, etc.)
    func setupInterruptionHandling(onInterruption: @escaping (Bool) -> Void) {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            switch type {
            case .began:
                onInterruption(true)
            case .ended:
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        onInterruption(false)
                    }
                }
            @unknown default:
                break
            }
        }
    }
}
