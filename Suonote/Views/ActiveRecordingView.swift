import SwiftUI
import AVFoundation
import UIKit

struct ActiveRecordingView: View {
    @Bindable var project: Project
    @ObservedObject var audioManager: AudioRecordingManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRecordingType: RecordingType
    @State private var audioLevels: [Float] = Array(repeating: 0, count: 50)
    @State private var currentBeat = 0
    @State private var currentBar = 0
    @State private var beatTimer: Timer?
    @State private var timeTimer: Timer?
    @State private var elapsedTime: TimeInterval = 0
    @State private var isInCountIn = false
    @State private var countInBeats = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var metronomeEnabled = false
    @State private var hapticEnabled = true
    @State private var showingMetronomeSettings = false
    @State private var isReadyToRecord = true
    @State private var showingTypePicker = false
    
    init(project: Project, audioManager: AudioRecordingManager, recordingType: RecordingType) {
        self.project = project
        self.audioManager = audioManager
        self._selectedRecordingType = State(initialValue: recordingType)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.15),
                    Color.black,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Pulse border overlay
            if !isInCountIn && audioManager.isRecording {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(currentBeat == 0 ? Color.red : Color.orange, lineWidth: 8)
                    .scaleEffect(pulseScale)
                    .opacity(0.6)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.1), value: pulseScale)
            }
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Spacer()
                
                // Main recording interface
                if isReadyToRecord {
                    readyToRecordView
                } else if isInCountIn {
                    countInView
                } else {
                    recordingInterfaceView
                }
                
                Spacer()
                
                // Controls
                if !isReadyToRecord {
                    controlsView
                }
            }
            .padding(.vertical, 40)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingMetronomeSettings) {
            metronomeSettingsSheet
        }
        .sheet(isPresented: $showingTypePicker) {
            RecordingTypePickerSheet(selectedType: $selectedRecordingType)
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    if audioManager.isRecording {
                        audioManager.stopRecording()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Take \(project.recordings.count + 1)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Image(systemName: selectedRecordingType.icon)
                            .font(.caption2)
                        Text(selectedRecordingType.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(selectedRecordingType.color)
                }
                
                Spacer()
                
                // Metronome settings button
                Button {
                    showingMetronomeSettings = true
                } label: {
                    Image(systemName: metronomeEnabled ? "metronome.fill" : "metronome")
                        .font(.title3)
                        .foregroundStyle(metronomeEnabled ? .orange : .white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var countInView: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Get Ready")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("\(4 - countInBeats)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            
            HStack(spacing: 20) {
                ForEach(0..<project.timeTop, id: \.self) { beat in
                    Circle()
                        .fill(beat < countInBeats % project.timeTop ? Color.orange : Color.white.opacity(0.2))
                        .frame(width: 16, height: 16)
                        .shadow(color: beat < countInBeats % project.timeTop ? Color.orange.opacity(0.6) : .clear, radius: 8)
                }
            }
        }
    }
    
    private var readyToRecordView: some View {
        VStack(spacing: 40) {
            // Project info
            VStack(spacing: 12) {
                Text("Ready to Record")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("Take \(project.recordings.count + 1)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Recording type badge
            Button {
                showingTypePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedRecordingType.icon)
                        .font(.title2)
                    Text("Recording Type: \(selectedRecordingType.rawValue)")
                        .font(.title3.weight(.semibold))
                }
                .foregroundStyle(selectedRecordingType.color)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selectedRecordingType.color.opacity(0.15))
                        .overlay(Capsule().stroke(selectedRecordingType.color, lineWidth: 2))
                )
            }
            
            // Project settings
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("\(project.bpm)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("BPM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 8) {
                    Text("\(project.timeTop)/\(project.timeBottom)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Record button
            Button {
                isReadyToRecord = false
                isInCountIn = true
                startCountIn()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.red.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }
            
            Text("Tap to start recording")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    private var recordingInterfaceView: some View {
        VStack(spacing: 32) {
            // Recording indicator
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 16, height: 16)
                    .opacity(audioManager.isRecording ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioManager.isRecording)
                
                Text("RECORDING")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                    .tracking(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.red.opacity(0.15))
                    .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
            )
            
            // Time display
            Text(formatTime(elapsedTime))
                .font(.system(size: 56, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            
            // Waveform
            RealTimeWaveformView(levels: audioLevels)
                .frame(height: 120)
                .padding(.horizontal, 24)
            
            // Bar and beat counter
            VStack(spacing: 16) {
                HStack(spacing: 50) {
                    VStack(spacing: 8) {
                        Text("BAR")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        Text("\(currentBar + 1)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    
                    VStack(spacing: 8) {
                        Text("BEAT")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 10) {
                            ForEach(0..<project.timeTop, id: \.self) { beat in
                                Circle()
                                    .fill(beat == currentBeat ? Color.red : Color.white.opacity(0.3))
                                    .frame(width: beat == currentBeat ? 18 : 14, height: beat == currentBeat ? 18 : 14)
                                    .shadow(color: beat == currentBeat ? Color.red.opacity(0.6) : .clear, radius: 10)
                                    .animation(.spring(response: 0.2), value: currentBeat)
                            }
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 20) {
            // BPM and Time signature info
            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Image(systemName: "metronome")
                        .font(.caption)
                    Text("\(project.bpm) BPM")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4, height: 4)
                
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.caption)
                    Text("\(project.timeTop)/\(project.timeBottom)")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            
            // Stop button
            Button {
                audioManager.stopRecording()
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text("Stop & Save")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.red.opacity(0.4), radius: 15, x: 0, y: 8)
                )
            }
            .padding(.horizontal, 24)
            .disabled(!audioManager.isRecording)
        }
    }
    
    private func startCountIn() {
        let interval = 60.0 / Double(project.bpm)
        let totalCountInBeats = project.timeTop * 1 // 1 bar count-in
        
        // Start immediately
        countInBeats = 0
        
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            countInBeats += 1
            
            if countInBeats >= totalCountInBeats {
                timer.invalidate()
                withAnimation {
                    isInCountIn = false
                }
                // Start recording immediately without delay
                DispatchQueue.main.async {
                    self.startRecording()
                }
            }
        }
    }
    
    private func startRecording() {
        audioManager.startRecording(countIn: 0, clickEnabled: false, recordingType: selectedRecordingType)
        startTimers()
    }
    
    private func startTimers() {
        // Beat timer
        let beatInterval = 60.0 / Double(project.bpm)
        beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { _ in
            withAnimation(.spring(response: 0.2)) {
                currentBeat = (currentBeat + 1) % project.timeTop
                if currentBeat == 0 {
                    currentBar += 1
                }
            }
            
            // Visual pulse
            pulseScale = 1.05
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pulseScale = 1.0
            }
            
            // Haptic feedback
            if hapticEnabled {
                if currentBeat == 0 {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            
            // Audio click
            if metronomeEnabled {
                AudioServicesPlaySystemSound(currentBeat == 0 ? 1054 : 1053)
            }
            
            // Simulate audio levels
            audioLevels.removeFirst()
            audioLevels.append(Float.random(in: 0.2...1.0))
        }
        
        // Elapsed time timer
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if audioManager.isRecording {
                elapsedTime += 0.1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private var metronomeSettingsSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Metronome & Feedback")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    // Haptic feedback toggle
                    Toggle(isOn: $hapticEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.tap.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vibration")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                
                                Text("Feel the beat while recording")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.blue)
                    
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                    
                    // Audio metronome toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $metronomeEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Audio Click")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    
                                    Text("Hear the metronome")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.orange)
                        
                        if metronomeEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                
                                Text("Warning: Click will be recorded. Use headphones!")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                
                Spacer()
                
                Button {
                    showingMetronomeSettings = false
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Recording Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }
    
    private func cleanup() {
        beatTimer?.invalidate()
        beatTimer = nil
        timeTimer?.invalidate()
        timeTimer = nil
        
        if audioManager.isRecording {
            audioManager.stopRecording()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}

// MARK: - Recording Type Picker Sheet

struct RecordingTypePickerSheet: View {
    @Binding var selectedType: RecordingType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("What are you recording?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(RecordingType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                            dismiss()
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.title)
                                    .foregroundStyle(type.color)
                                
                                Text(type.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedType == type ? type.color.opacity(0.2) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedType == type ? type.color : Color.white.opacity(0.1), lineWidth: selectedType == type ? 2 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Recording Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.height(600)])
    }
}

struct RealTimeWaveformView: View {
    let levels: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            let barWidth = (geometry.size.width / CGFloat(levels.count)) - 1
            
            HStack(spacing: 1) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    let barHeight = max(4, CGFloat(level) * geometry.size.height)
                    let isRecent = index > levels.count - 10
                    
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(
                            LinearGradient(
                                colors: isRecent ? 
                                    [Color.red, Color.orange] : 
                                    [Color.red.opacity(0.6), Color.orange.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: barHeight)
                        .frame(height: geometry.size.height, alignment: .center)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
