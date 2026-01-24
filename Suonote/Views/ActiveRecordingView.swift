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
            DesignSystem.Colors.background
            .ignoresSafeArea()
            
            // Pulse border overlay with blur
            if !isInCountIn && audioManager.isRecording {
                RoundedRectangle(cornerRadius: 50)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                currentBeat == 0 ? DesignSystem.Colors.error : DesignSystem.Colors.warning,
                                (currentBeat == 0 ? DesignSystem.Colors.error : DesignSystem.Colors.warning).opacity(0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 12
                    )
                    .scaleEffect(pulseScale)
                    .blur(radius: 8)
                    .opacity(0.8)
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
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(DesignSystem.Colors.border))
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Take \(project.recordings.count + 1)")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: selectedRecordingType.icon)
                            .font(DesignSystem.Typography.caption2)
                        Text(selectedRecordingType.rawValue)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(selectedRecordingType.color)
                }
                
                Spacer()
                
                // Spacer for symmetry
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var countInView: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Get Ready")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Text("\(max(0, tempoBeatsPerBar - countInBeats))")
                    .font(DesignSystem.Typography.hero)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            
            HStack(spacing: 20) {
                ForEach(0..<tempoBeatsPerBar, id: \.self) { beat in
                    Circle()
                        .fill(beat < countInBeats % tempoBeatsPerBar ? DesignSystem.Colors.warning : DesignSystem.Colors.border.opacity(0.5))
                        .frame(width: 16, height: 16)
                        .shadow(color: beat < countInBeats % tempoBeatsPerBar ? DesignSystem.Colors.warning.opacity(0.6) : .clear, radius: 8)
                }
            }
        }
    }
    
    private var readyToRecordView: some View {
        VStack(spacing: 40) {
            // Project info
            VStack(spacing: 12) {
                Text("Ready to Record")
                    .font(DesignSystem.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Take \(project.recordings.count + 1)")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            // Recording type badge
            Button {
                showingTypePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedRecordingType.icon)
                        .font(DesignSystem.Typography.title2)
                    Text("Recording Type: \(selectedRecordingType.rawValue)")
                        .font(DesignSystem.Typography.title3)
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
                        .font(DesignSystem.Typography.huge)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("BPM")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                VStack(spacing: 8) {
                    Text("\(project.timeTop)/\(project.timeBottom)")
                        .font(DesignSystem.Typography.huge)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Time")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
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
                                colors: [DesignSystem.Colors.error.opacity(0.8), DesignSystem.Colors.error],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: DesignSystem.Colors.error.opacity(0.35), radius: 20, x: 0, y: 10)
                    
                    Circle()
                        .stroke(DesignSystem.Colors.textMuted, lineWidth: 3)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "circle.fill")
                        .font(DesignSystem.Typography.xl)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            }
            
            Text("Tap to start recording")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    private var recordingInterfaceView: some View {
        VStack(spacing: 32) {
            // Recording indicator
            HStack(spacing: 12) {
                Circle()
                    .fill(DesignSystem.Colors.error)
                    .frame(width: 16, height: 16)
                    .opacity(audioManager.isRecording ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioManager.isRecording)
                
                Text("RECORDING")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.error)
                    .tracking(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.error.opacity(0.2))
                    .overlay(Capsule().stroke(DesignSystem.Colors.error.opacity(0.4), lineWidth: 1))
            )
            
            // Time display
            Text(formatTime(elapsedTime))
                .font(DesignSystem.Typography.giant)
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
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
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        Text("\(currentBar + 1)")
                            .font(DesignSystem.Typography.xl)
                            .fontWeight(.bold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .monospacedDigit()
                    }
                    
                    VStack(spacing: 8) {
                        Text("BEAT")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 10) {
                            ForEach(0..<tempoBeatsPerBar, id: \.self) { beat in
                                Circle()
                                    .fill(beat == currentBeat ? DesignSystem.Colors.error : DesignSystem.Colors.textMuted)
                                    .frame(width: beat == currentBeat ? 18 : 14, height: beat == currentBeat ? 18 : 14)
                                    .shadow(color: beat == currentBeat ? DesignSystem.Colors.error.opacity(0.6) : .clear, radius: 10)
                                    .animation(.spring(response: 0.2), value: currentBeat)
                            }
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
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
                        .font(DesignSystem.Typography.caption)
                    Text("\(project.bpm) BPM")
                        .font(DesignSystem.Typography.subheadline)
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Circle()
                    .fill(DesignSystem.Colors.textMuted)
                    .frame(width: 4, height: 4)
                
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(DesignSystem.Typography.caption)
                    Text("\(project.timeTop)/\(project.timeBottom)")
                        .font(DesignSystem.Typography.subheadline)
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            // Stop button
            Button {
                audioManager.stopRecording()
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "stop.fill")
                        .font(DesignSystem.Typography.title2)
                    Text("Stop & Save")
                        .font(DesignSystem.Typography.headline)
                }
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.error.opacity(0.8), DesignSystem.Colors.error],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: DesignSystem.Colors.error.opacity(0.35), radius: 15, x: 0, y: 8)
                )
            }
            .padding(.horizontal, 24)
            .disabled(!audioManager.isRecording)
        }
    }
    
    private func startCountIn() {
        let interval = project.tempoBeatInterval()
        let totalCountInBeats = tempoBeatsPerBar * 1 // 1 bar count-in
        
        // Visual pulse for count-in
        countInBeats = 0
        isInCountIn = true
        
        // Timer for each count-in beat
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            self.countInBeats += 1
            
            if self.countInBeats >= totalCountInBeats {
                timer.invalidate()
                withAnimation {
                    self.isInCountIn = false
                }
                // Start recording immediately
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
        let beatInterval = project.tempoBeatInterval()
        beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { _ in
            withAnimation(.spring(response: 0.2)) {
                self.currentBeat = (self.currentBeat + 1) % self.tempoBeatsPerBar
                if self.currentBeat == 0 {
                    self.currentBar += 1
                }
            }
            
            // Visual pulse
            self.pulseScale = 1.08
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.pulseScale = 1.0
            }
        }
        
        // Time timer
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.elapsedTime += 0.1
            // Simulate audio levels
            if self.audioLevels.count > 0 {
                self.audioLevels.removeFirst()
                self.audioLevels.append(Float.random(in: 0.2...1.0))
            }
        }
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

    private var tempoBeatsPerBar: Int {
        project.tempoBeatsPerBar
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
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.top, 8)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(RecordingType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                            dismiss()
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(DesignSystem.Typography.title)
                                    .foregroundStyle(type.color)
                                
                                Text(type.rawValue)
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedType == type ? type.color.opacity(0.2) : DesignSystem.Colors.surfaceSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedType == type ? type.color : DesignSystem.Colors.border, lineWidth: selectedType == type ? 2 : 1)
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
                DesignSystem.Colors.background
            )
            .navigationTitle("Recording Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
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
                                    [DesignSystem.Colors.error, DesignSystem.Colors.warning] :
                                    [DesignSystem.Colors.error.opacity(0.6), DesignSystem.Colors.warning.opacity(0.6)],
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
                .fill(DesignSystem.Colors.surfaceSecondary.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.Colors.error.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
