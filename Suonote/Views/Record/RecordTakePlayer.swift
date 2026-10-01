import SwiftUI
import os
import Combine

/// Plays takes through each take's own effect chain, with position,
/// pause/resume and seeking — shared by the takes list and the take detail
/// so playback carries over between them.
final class RecordTakePlayer: ObservableObject {
    /// Take currently loaded (playing or paused at `currentTime`).
    @Published private(set) var loadedId: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private let processor = AudioEffectsProcessor()
    private var ticker: Timer?

    var progress: Double {
        duration > 0 ? min(1, max(0, currentTime / duration)) : 0
    }

    func isPlaying(_ recording: Recording) -> Bool {
        isPlaying && loadedId == recording.id
    }

    func isLoaded(_ recording: Recording) -> Bool {
        loadedId == recording.id
    }

    /// Progress for a given take (0 when another take is loaded).
    func progress(for recording: Recording) -> Double? {
        isLoaded(recording) ? progress : nil
    }

    // MARK: Transport

    func toggle(_ recording: Recording) {
        if isPlaying(recording) {
            pause()
        } else if isLoaded(recording), currentTime < duration - 0.05 {
            play(recording, from: currentTime)
        } else {
            play(recording, from: 0)
        }
    }

    func play(_ recording: Recording, from time: TimeInterval = 0) {
        guard let url = recording.recordFileURL else {
            AppLog.audio.error("Recording file not found for: \(recording.fileName)")
            HapticFeedback.error.trigger()
            return
        }
        processor.settings = recording.recordEffectSettings
        let id = recording.id
        do {
            try processor.playAudio(url: url, from: time) { [weak self] in
                self?.finished(id: id)
            }
            loadedId = id
            duration = processor.duration > 0 ? processor.duration : recording.duration
            currentTime = time
            isPlaying = true
            startTicker()
        } catch {
            AppLog.audio.error("Failed to play take: \(String(describing: error))")
            stop()
        }
    }

    func pause() {
        guard isPlaying else { return }
        currentTime = processor.currentTime
        processor.stop()
        isPlaying = false
        stopTicker()
    }

    func stop() {
        processor.stop()
        stopTicker()
        isPlaying = false
        loadedId = nil
        currentTime = 0
        duration = 0
    }

    /// Jumps to a fraction of the take; starts playing it if it wasn't.
    func seek(_ recording: Recording, to fraction: Double) {
        let total = isLoaded(recording) && duration > 0 ? duration : recording.duration
        let time = max(0, min(1, fraction)) * total
        if isPlaying(recording) {
            processor.seek(to: time)
            currentTime = time
        } else {
            play(recording, from: time)
        }
    }

    /// Nudges the playhead by `delta` seconds.
    func skip(_ recording: Recording, by delta: TimeInterval) {
        let total = isLoaded(recording) && duration > 0 ? duration : recording.duration
        guard total > 0 else { return }
        let base = isLoaded(recording) ? currentTime : 0
        seek(recording, to: (base + delta) / total)
    }

    /// Re-applies the take's effects live (while tweaking the pedalboard).
    func refreshEffects(for recording: Recording) {
        guard isLoaded(recording) else { return }
        processor.settings = recording.recordEffectSettings
        processor.applyEffects()
    }

    // MARK: Private

    private func finished(id: UUID) {
        guard loadedId == id else { return }
        stopTicker()
        isPlaying = false
        currentTime = 0
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return }
                self.currentTime = self.processor.currentTime
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
