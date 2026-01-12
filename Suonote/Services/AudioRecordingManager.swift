import Foundation
import AVFoundation
import SwiftData
import Combine
import UIKit

class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var currentlyPlayingRecording: Recording?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var clickPlayer: AVAudioPlayer?
    private var metronomeTimer: Timer?
    
    private var project: Project?
    private var recordingStartTime: Date?
    private var countInBars = 1
    private var clickEnabled = true
    private var currentRecordingType: RecordingType = .voice
    
    func setup(project: Project) {
        self.project = project
    }
    
    func startRecording(countIn: Int, clickEnabled: Bool, recordingType: RecordingType = .voice) {
        guard let project = project else { return }

        configureAudioSession(category: .playAndRecord, options: [.defaultToSpeaker])
        
        self.countInBars = countIn
        self.clickEnabled = clickEnabled
        self.currentRecordingType = recordingType
        
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
            audioRecorder?.prepareToRecord()
            
            if clickEnabled {
                startMetronome(bpm: project.bpm, countInBars: countIn)
            }
            
            let beatsPerBar = project.tempoBeatsPerBar
            let interval = project.tempoBeatInterval()
            let beatsPerSecond = interval > 0 ? (1.0 / interval) : 0
            let countInDuration = Double(countInBars * beatsPerBar) / max(0.0001, beatsPerSecond)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + countInDuration) {
                self.audioRecorder?.record()
                self.isRecording = true
                self.recordingStartTime = Date()
            }
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard let recorder = audioRecorder, let project = project else { return }
        
        recorder.stop()
        isRecording = false
        stopMetronome()
        
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        
        let recording = Recording(
            name: "Take \(project.recordings.count + 1)",
            fileName: recorder.url.lastPathComponent,
            duration: duration,
            bpm: project.bpm,
            timeTop: project.timeTop,
            timeBottom: project.timeBottom,
            countIn: countInBars,
            recordingType: currentRecordingType
        )
        
        recording.project = project
        project.recordings.append(recording)
        project.updatedAt = Date()
    }
    
    func playRecording(_ recording: Recording) {
        configureAudioSession(category: .playback, options: [.mixWithOthers])

        guard let url = FileManagerUtils.existingRecordingURL(for: recording.fileName) else {
            print("Recording file not found for: \(recording.fileName)")
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
            print("Failed to play recording: \(error)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        currentlyPlayingRecording = nil
    }
    
    private func startMetronome(bpm: Int, countInBars: Int) {
        guard clickEnabled else { return }
        
        let interval = project?.tempoBeatInterval() ?? (60.0 / Double(max(1, bpm)))
        
        var beatCount = 0
        let beatsPerBar = project?.tempoBeatsPerBar ?? (project?.timeTop ?? 4)
        let totalCountInBeats = countInBars * beatsPerBar
        
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return
            }
            
            // Play click sound for both count-in and recording
            let isAccent = beatCount % beatsPerBar == 0
            self.playClickSound(isAccent: isAccent)
            
            // Trigger haptic feedback if recording has started
            if beatCount >= totalCountInBeats && self.isRecording {
                if isAccent {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            
            beatCount += 1
        }
    }
    
    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }
    
    private func playClickSound(isAccent: Bool) {
        MetronomeClickPlayer.shared.play(accent: isAccent)
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
            print("Failed to configure audio session: \(error)")
        }
    }
}

extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}

extension AudioRecordingManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentlyPlayingRecording = nil
    }
}
