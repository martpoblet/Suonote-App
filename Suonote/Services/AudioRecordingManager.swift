import Foundation
import AVFoundation
import SwiftData
import Combine

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
    
    func setup(project: Project) {
        self.project = project
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func startRecording(countIn: Int, clickEnabled: Bool) {
        guard let project = project else { return }
        
        self.countInBars = countIn
        self.clickEnabled = clickEnabled
        
        let fileName = "\(UUID().uuidString).m4a"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            
            if clickEnabled {
                startMetronome(bpm: project.bpm, countInBars: countIn)
            }
            
            let beatsPerBar = project.timeTop
            let beatsPerSecond = Double(project.bpm) / 60.0
            let countInDuration = Double(countInBars * beatsPerBar) / beatsPerSecond
            
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
            countIn: countInBars
        )
        
        recording.project = project
        project.recordings.append(recording)
        project.updatedAt = Date()
    }
    
    func playRecording(_ recording: Recording) {
        let url = getDocumentsDirectory().appendingPathComponent(recording.fileName)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            currentlyPlayingRecording = recording
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
        
        let beatsPerSecond = Double(bpm) / 60.0
        let interval = 1.0 / beatsPerSecond
        
        var beatCount = 0
        let totalBeats = countInBars * (project?.timeTop ?? 4)
        
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            if beatCount >= totalBeats && self.isRecording {
                timer.invalidate()
                return
            }
            
            self.playClickSound(isAccent: beatCount % (self.project?.timeTop ?? 4) == 0)
            beatCount += 1
        }
    }
    
    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }
    
    private func playClickSound(isAccent: Bool) {
        AudioServicesPlaySystemSound(isAccent ? 1054 : 1053)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
