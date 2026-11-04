import os
import AVFoundation
import UIKit

/// Shared audio session and engine management (A-04)
/// Coordinates audio sessions across MetronomeClickPlayer, ChordPreviewPlayer,
/// AudioEffectsProcessor, and StudioPlaybackEngine to prevent conflicts.
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private(set) var isSessionActive = false
    private var interruptionObserver: Any?
    
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
            AppLog.audio.error("Failed to activate session: \(String(describing: error))")
        }
    }
    
    /// Deactivate when no engines need the session
    func deactivateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
        } catch {
            AppLog.audio.error("Failed to deactivate session: \(String(describing: error))")
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
            AppLog.audio.error("Failed to configure recording: \(String(describing: error))")
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
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        interruptionObserver = NotificationCenter.default.addObserver(
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

/// Keeps the screen awake while audio work is in progress (a take being
/// recorded, Studio playback). Holders are tracked by identity, so recording
/// and playback can overlap and each `release` is safe to call more than once
/// (every exit path, including `deinit`, may call it).
nonisolated enum ScreenAwake {
    private static let holders = OSAllocatedUnfairLock<Set<ObjectIdentifier>>(initialState: [])

    static func hold(_ owner: AnyObject) {
        let id = ObjectIdentifier(owner)
        holders.withLock { _ = $0.insert(id) }
        apply()
    }

    static func release(_ owner: AnyObject) {
        let id = ObjectIdentifier(owner)
        holders.withLock { _ = $0.remove(id) }
        apply()
    }

    private static func apply() {
        // Re-reads the holders on the main actor, so out-of-order hops still
        // end on the right value.
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = !holders.withLock { $0.isEmpty }
        }
    }
}
