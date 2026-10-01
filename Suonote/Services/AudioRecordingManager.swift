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
    /// Seconds captured so far (from the recorder itself, not a UI timer).
    @Published private(set) var elapsedTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var clickPlayer: AVAudioPlayer?
    private var metronomeTimer: Timer?

    private var project: Project?
    private var recordingStartTime: Date?
    private var countInBars = 1
    private var clickEnabled = true
    private var currentRecordingType: RecordingType = .voice
    private var currentLinkedSectionId: UUID?
    private var meterTimer: Timer?

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

        self.countInBars = max(0, countIn)
        self.clickEnabled = clickEnabled
        self.currentRecordingType = recordingType
        self.currentLinkedSectionId = linkedSectionId

        let fileName = "\(UUID().uuidString).m4a"
        let url = FileManagerUtils.recordingURL(for: fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        } catch {
            AppLog.audio.error("Failed to start recording: \(String(describing: error))")
            audioRecorder = nil
            return
        }

        recordedBeats = 0
        elapsedTime = 0
        let totalCountInBeats = countInBars * project.tempoBeatsPerBar
        countInBeatsRemaining = totalCountInBeats
        isCountingIn = totalCountInBeats > 0

        if totalCountInBeats == 0 {
            beginCapture()
        }
        // The metronome clock drives the count-in (always audible, so the
        // player can hear where "one" is) and, if requested, the click while
        // recording. Recording starts exactly on the downbeat after the
        // count-in — previously the view counted a bar and then the manager
        // waited another bar, and dismissing during count-in left a recorder
        // running in the background.
        startMetronome(countInBeats: totalCountInBeats)
    }

    /// Stops and keeps the take. Returns the new `Recording` (nil if nothing was captured).
    @discardableResult
    func stopRecording() -> Recording? {
        guard let recorder = audioRecorder, let project = project else { return nil }

        // Stopped while still counting in: nothing was captured.
        guard isRecording else {
            cancelRecording()
            return nil
        }

        let capturedTime = recorder.currentTime
        recorder.stop()
        isRecording = false
        isCountingIn = false
        stopMetronome()
        stopMeterTimer()

        let fallback = Date().timeIntervalSince(recordingStartTime ?? Date())
        let duration = capturedTime > 0 ? capturedTime : fallback

        let recording = Recording(
            name: String(localized: "Take \(project.recordings.count + 1)"),
            fileName: recorder.url.lastPathComponent,
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
        audioRecorder = nil
        return recording
    }

    /// Stops without saving and deletes the partial file.
    func cancelRecording() {
        stopMetronome()
        stopMeterTimer()
        if let recorder = audioRecorder {
            if recorder.isRecording { recorder.stop() }
            recorder.deleteRecording()
        }
        audioRecorder = nil
        isRecording = false
        isCountingIn = false
        countInBeatsRemaining = 0
        recordedBeats = 0
        elapsedTime = 0
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

    // MARK: - Capture

    private func beginCapture() {
        guard let recorder = audioRecorder else { return }
        recorder.record()
        isCountingIn = false
        countInBeatsRemaining = 0
        isRecording = true
        recordingStartTime = Date()
        startMeterTimer()
    }

    // MARK: - Metronome

    private func startMetronome(countInBeats: Int) {
        stopMetronome()
        let interval = project?.tempoBeatInterval() ?? 0.5
        let beatsPerBar = max(1, project?.tempoBeatsPerBar ?? (project?.timeTop ?? 4))
        var beatCount = 0

        let tick: () -> Void = { [weak self] in
            guard let self else { return }
            let isAccent = beatCount % beatsPerBar == 0

            if beatCount < countInBeats {
                // Count-in: always click so "one" is unmistakable.
                self.playClickSound(isAccent: isAccent)
                self.countInBeatsRemaining = countInBeats - beatCount
            } else {
                if beatCount == countInBeats, !self.isRecording {
                    self.beginCapture()
                }
                if self.clickEnabled {
                    self.playClickSound(isAccent: isAccent)
                }
                self.recordedBeats = beatCount - countInBeats
                // Haptic pulse only alongside the click (taps can bleed into the mic).
                if self.isRecording && self.clickEnabled {
                    UIImpactFeedbackGenerator(style: isAccent ? .medium : .light).impactOccurred(intensity: isAccent ? 0.8 : 0.4)
                }
            }
            beatCount += 1
        }

        // First beat sounds immediately; the rest follow on the grid.
        tick()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        metronomeTimer = timer
    }

    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }

    private func playClickSound(isAccent: Bool) {
        MetronomeClickPlayer.shared.play(accent: isAccent)
    }

    private func startMeterTimer() {
        meterTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMeters() }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func updateMeters() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()
        // Convert dB (-160...0) to normalized 0...1
        let minDb: Float = -60
        let average = max(0, (recorder.averagePower(forChannel: 0) - minDb) / (-minDb))
        let peak = max(0, (recorder.peakPower(forChannel: 0) - minDb) / (-minDb))
        currentMeterLevel = min(1, average)
        currentPeakLevel = min(1, peak)
        elapsedTime = recorder.currentTime
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
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

extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            AppLog.audio.error("Recording failed")
        }
    }
}

extension AudioRecordingManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentlyPlayingRecording = nil
    }
}
