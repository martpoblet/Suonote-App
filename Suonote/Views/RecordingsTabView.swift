import SwiftUI
import SwiftData
import AVFoundation

struct RecordingsTabView: View {
    @Bindable var project: Project
    @StateObject private var audioManager = AudioRecordingManager()
    @State private var currentBeat = 0
    @State private var currentBar = 0
    @State private var audioLevels: [Float] = Array(repeating: 0, count: 50)
    @State private var micPermissionGranted = false
    @State private var showingPermissionAlert = false
    @State private var metronomeTimer: Timer?
    @State private var showingSectionPicker = false
    @State private var selectedRecordingForLink: Recording?
    
    private var uniqueSections: [SectionTemplate] {
        var seen = Set<UUID>()
        return project.arrangementItems.compactMap { item in
            guard let section = item.sectionTemplate,
                  !seen.contains(section.id) else { return nil }
            seen.insert(section.id)
            return section
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if audioManager.isRecording {
                recordingInterfaceView
            } else {
                readyToRecordView
            }
            
            Divider()
                .overlay(Color.white.opacity(0.1))
                .padding(.vertical, 20)
            
            takesListView
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .onAppear {
            audioManager.setup(project: project)
            requestMicrophonePermission()
        }
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings", role: .cancel) {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .destructive) {}
        } message: {
            Text("Suonote needs microphone access to record audio. Please enable it in Settings.")
        }
        .sheet(isPresented: $showingSectionPicker) {
            if let recording = selectedRecordingForLink {
                SectionLinkSheet(
                    recording: recording,
                    sections: uniqueSections,
                    onLink: { sectionId in
                        recording.linkedSectionId = sectionId
                    }
                )
            }
        }
    }
    
    private var readyToRecordView: some View {
        VStack(spacing: 32) {
            Button {
                if micPermissionGranted {
                    audioManager.startRecording(countIn: 1, clickEnabled: true)
                    startMetronome()
                } else {
                    showingPermissionAlert = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.red.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text("Ready to Record")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Text("Take \(project.recordings.count + 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(project.bpm)")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                    .overlay(Color.white.opacity(0.2))
                
                VStack(spacing: 4) {
                    Text("\(project.timeTop)/\(project.timeBottom)")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        }
        .frame(maxHeight: .infinity)
    }
    
    private var recordingInterfaceView: some View {
        VStack(spacing: 24) {
            WaveformView(levels: audioLevels)
                .frame(height: 100)
            
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("BAR")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("\(currentBar + 1)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                
                VStack(spacing: 8) {
                    Text("BEAT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<project.timeTop, id: \.self) { beat in
                            Circle()
                                .fill(beat == currentBeat ? Color.red : Color.white.opacity(0.3))
                                .frame(width: beat == currentBeat ? 16 : 12, height: beat == currentBeat ? 16 : 12)
                                .shadow(color: beat == currentBeat ? Color.red.opacity(0.6) : .clear, radius: 8)
                                .animation(.spring(response: 0.2), value: currentBeat)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
            
            Button {
                audioManager.stopRecording()
                stopMetronome()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text("Stop Recording")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.8))
                        .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 5)
                )
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var takesListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Takes (\(project.recordings.count))")
                .font(.headline)
                .foregroundStyle(.white)
            
            if project.recordings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No recordings yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(project.recordings.sorted(by: { $0.createdAt > $1.createdAt })) { recording in
                            ModernTakeCard(
                                recording: recording,
                                linkedSection: uniqueSections.first(where: { $0.id == recording.linkedSectionId }),
                                isPlaying: audioManager.currentlyPlayingRecording?.id == recording.id,
                                onPlay: {
                                    if audioManager.currentlyPlayingRecording?.id == recording.id {
                                        audioManager.stopPlayback()
                                    } else {
                                        audioManager.playRecording(recording)
                                    }
                                },
                                onLinkSection: {
                                    selectedRecordingForLink = recording
                                    showingSectionPicker = true
                                },
                                onDelete: {
                                    deleteRecording(recording)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
                if !granted {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func startMetronome() {
        let interval = 60.0 / Double(project.bpm)
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation {
                currentBeat = (currentBeat + 1) % project.timeTop
                if currentBeat == 0 {
                    currentBar += 1
                }
            }
            
            audioLevels.removeFirst()
            audioLevels.append(Float.random(in: 0...1))
        }
    }
    
    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        currentBeat = 0
        currentBar = 0
        audioLevels = Array(repeating: 0, count: 50)
    }
    
    private func deleteRecording(_ recording: Recording) {
        if let index = project.recordings.firstIndex(where: { $0.id == recording.id }) {
            project.recordings.remove(at: index)
        }
    }
}

struct WaveformView: View {
    let levels: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            let barWidth = (geometry.size.width / CGFloat(levels.count)) - 2
            
            HStack(spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    let barHeight = max(4, CGFloat(level) * geometry.size.height)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.6)],
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
}

struct ModernTakeCard: View {
    let recording: Recording
    let linkedSection: SectionTemplate?
    let isPlaying: Bool
    let onPlay: () -> Void
    let onLinkSection: () -> Void
    let onDelete: () -> Void
    
    private var playButtonGradient: LinearGradient {
        LinearGradient(
            colors: isPlaying ? [Color.green, Color.cyan] : [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderColor: Color {
        isPlaying ? Color.green.opacity(0.5) : Color.white.opacity(0.1)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(playButtonGradient)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    if let section = linkedSection {
                        Text(section.name)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.purple.opacity(0.2))
                            )
                    }
                    
                    Text(recording.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(formatDuration(recording.duration))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Mini waveform preview
            MiniWaveformView()
                .frame(width: 40, height: 24)
            
            // Link section button
            Button(action: onLinkSection) {
                Image(systemName: linkedSection == nil ? "link.badge.plus" : "link")
                    .font(.caption)
                    .foregroundStyle(linkedSection == nil ? .blue.opacity(0.8) : .purple.opacity(0.8))
                    .padding(8)
                    .background(Circle().fill((linkedSection == nil ? Color.blue : Color.purple).opacity(0.15)))
            }
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(8)
                    .background(Circle().fill(Color.red.opacity(0.15)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MiniWaveformView: View {
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<20, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: CGFloat.random(in: 4...20))
            }
        }
    }
}

// MARK: - Section Link Sheet

struct SectionLinkSheet: View {
    @Bindable var recording: Recording
    let sections: [SectionTemplate]
    let onLink: (UUID?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if sections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        
                        Text("No sections available")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Create sections in the Compose tab first")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Unlink option
                            if recording.linkedSectionId != nil {
                                Button {
                                    onLink(nil)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "link.badge.minus")
                                            .font(.title3)
                                            .foregroundStyle(.red)
                                        
                                        Text("Remove Link")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.red.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .padding(.bottom, 8)
                            }
                            
                            ForEach(sections) { section in
                                SectionLinkButton(
                                    section: section,
                                    isLinked: recording.linkedSectionId == section.id,
                                    onSelect: {
                                        onLink(section.id)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(24)
                    }
                }
            }
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
            .navigationTitle("Link to Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SectionLinkButton: View {
    let section: SectionTemplate
    let isLinked: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isLinked ? .purple : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("\(section.bars) bars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(linkBackground)
        }
    }
    
    private var linkBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isLinked ? Color.purple.opacity(0.15) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isLinked ? Color.purple : Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Test", bpm: 120)
    container.mainContext.insert(project)
    
    return RecordingsTabView(project: project)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
