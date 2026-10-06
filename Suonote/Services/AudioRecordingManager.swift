import os
import Foundation
import AVFoundation
import SwiftData
import Combine
import UIKit

class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var currentlyPlayingRecording: Recording?
    @Published var currentMeterLevel: Float = 0
    /// Peak (not average) input level, normalized 0...1 — drives clip indicators.
    @Published private(set) var currentPeakLevel: Float = 0
    /// True between `startRecording(countIn:>0 …)` and the first recorded beat.
    @Published private(set) var isCountingIn = false
    /// Beats left in the count-in (counts down to 0, then recording starts).
    @Published private(set) var countInBeatsRemaining = 0
    /// Beats elapsed since recording actually began (0 = downbeat of bar 1).
    @Published private(set) var recordedBeats = 0
    /// Seconds since the downbeat, on the take's own beat clock.
    @Published private(set) var elapsedTime: TimeInterval = 0

    /// The beat clock of the take in progress (nil when idle). Views use it
    /// to draw the visual click in step with the audible one.
    @Published private(set) var beatClock: RecordBeatClock?

    private var capture: TakeCapture?
    private var audioPlayer: AVAudioPlayer?
    private var pollTimer: Timer?
    private var lastBeatIndex = Int.min
    private var pollTicks = 0

    private var project: Project?
    private var countInBars = 1
    private var clickEnabled = true
    private var currentRecordingType: RecordingType = .voice
    private var currentLinkedSectionId: UUID?

    func setup(project: Project) {
        self.project = project
    }

    /// Whether a take is armed (counting in) or rolling.
    var isBusy: Bool { isRecording || isCountingIn }

    func startRecording(
        countIn: Int,
        clickEnabled: Bool,
        recordingType: RecordingType = .voice,
        linkedSectionId: UUID? = nil
    ) {
        guard let project = project, !isBusy else { return }

        configureAudioSession(category: .playAndRecord, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        // Small I/O buffers keep the click tight and the latency low.
        try? AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)

        self.countInBars = max(0, countIn)
        self.clickEnabled = clickEnabled
        self.currentRecordingType = recordingType
        self.currentLinkedSectionId = linkedSectionId

        let beatsPerBar = max(1, project.tempoBeatsPerBar)
        let totalCountInBeats = countInBars * beatsPerBar
        let capture = TakeCapture(url: FileManagerUtils.recordingURL(for: "\(UUID().uuidString).m4a"))
        do {
            // The click and the microphone share one sample clock, so the take
            // starts exactly on the downbeat after the count-in (see TakeCapture).
            beatClock = try capture.start(
                beatSeconds: project.tempoBeatInterval(),
                beatsPerBar: beatsPerBar,
                countInBeats: totalCountInBeats,
                clickWhileRecording: clickEnabled
            )
        } catch {
            AppLog.audio.error("Failed to start recording: \(String(describing: error))")
            capture.cancel()
            beatClock = nil
            return
        }
        self.capture = capture

        recordedBeats = 0
        elapsedTime = 0
        lastBeatIndex = Int.min
        countInBeatsRemaining = totalCountInBeats
        isCountingIn = totalCountInBeats > 0
        isRecording = totalCountInBeats == 0
        startPolling()
    }

    /// Stops and keeps the take. Returns the new `Recording` (nil if nothing was captured).
    @discardableResult
    func stopRecording() -> Recording? {
        guard let capture, let project = project else { return nil }

        // Stopped while still counting in: nothing was captured.
        guard isRecording else {
            cancelRecording()
            return nil
        }

        stopPolling()
        let duration = capture.stop()
        isRecording = false
        isCountingIn = false
        resetLevels()
        self.capture = nil
        beatClock = nil

        guard duration > 0 else {
            try? FileManager.default.removeItem(at: capture.url)
            currentLinkedSectionId = nil
            return nil
        }

        let recording = Recording(
            name: String(localized: "Take \(project.recordings.count + 1)"),
            fileName: capture.url.lastPathComponent,
            duration: duration,
            bpm: project.bpm,
            timeTop: project.timeTop,
            timeBottom: project.timeBottom,
            countIn: countInBars,
            recordingType: currentRecordingType
        )
        recording.linkedSectionId = currentLinkedSectionId

        recording.project = project
        project.recordings.append(recording)
        project.updatedAt = Date()
        try? project.modelContext?.save()
        currentLinkedSectionId = nil
        return recording
    }

    /// Stops without saving and deletes the partial file.
    func cancelRecording() {
        stopPolling()
        capture?.cancel()
        capture = nil
        beatClock = nil
        isRecording = false
        isCountingIn = false
        countInBeatsRemaining = 0
        recordedBeats = 0
        elapsedTime = 0
        resetLevels()
        currentLinkedSectionId = nil
    }

    func playRecording(_ recording: Recording) {
        configureAudioSession(category: .playback, options: [.mixWithOthers])

        guard let url = FileManagerUtils.existingRecordingURL(for: recording.fileName) else {
            AppLog.audio.error("Recording file not found for: \(recording.fileName)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            if audioPlayer?.play() == true {
                currentlyPlayingRecording = recording
            } else {
                currentlyPlayingRecording = nil
            }
        } catch {
            AppLog.audio.error("Failed to play recording: \(String(describing: error))")
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        currentlyPlayingRecording = nil
    }

    // MARK: - Beat clock

    /// Follows the beat clock: count-in, the downbeat, beats while rolling,
    /// input levels, and keeps the click queue topped up.
    private func startPolling() {
        stopPolling()
        pollTicks = 0
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        poll()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        guard let capture, let clock = beatClock else { return }
        let heard = clock.heardBeats()
        capture.scheduleClicks(throughSeconds: max(0, heard) * clock.beatSeconds + 3)

        let beatIndex = Int(heard.rounded(.down))
        if beatIndex >= 0, beatIndex != lastBeatIndex {
            lastBeatIndex = beatIndex
            if beatIndex < clock.countInBeats {
                countInBeatsRemaining = clock.countInBeats - beatIndex
            } else {
                if !isRecording {
                    isCountingIn = false
                    countInBeatsRemaining = 0
                    isRecording = true
                }
                recordedBeats = beatIndex - clock.countInBeats
                // Haptic pulse only alongside the click (taps can bleed into the mic).
                if clickEnabled {
                    let isAccent = recordedBeats % clock.beatsPerBar == 0
                    UIImpactFeedbackGenerator(style: isAccent ? .medium : .light).impactOccurred(intensity: isAccent ? 0.8 : 0.4)
                }
            }
        }

        // Levels and the clock readout at 20 Hz, like the old meter timer.
        pollTicks += 1
        guard pollTicks % 3 == 0 else { return }
        if isRecording {
            let levels = capture.currentLevels
            currentMeterLevel = levels.rms
            currentPeakLevel = levels.peak
            elapsedTime = max(0, heard - Double(clock.countInBeats)) * clock.beatSeconds
        }
    }

    private func resetLevels() {
        currentMeterLevel = 0
        currentPeakLevel = 0
    }

    private func configureAudioSession(
        category: AVAudioSession.Category,
        options: AVAudioSession.CategoryOptions
    ) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category, mode: .default, options: options)
            try session.setActive(true)
        } catch {
            AppLog.audio.error("Failed to configure audio session: \(String(describing: error))")
        }
    }
}

extension AudioRecordingManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentlyPlayingRecording = nil
    }
}
