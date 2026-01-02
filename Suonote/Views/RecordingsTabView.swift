import SwiftUI
import SwiftData
import AVFoundation

struct RecordingsTabView: View {
    @Bindable var project: Project
    @StateObject private var audioManager = AudioRecordingManager()
    
    @State private var countIn = 1
    @State private var clickEnabled = true
    @State private var visualPulseEnabled = true
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 20) {
            recordingControlsView
            
            Divider()
            
            takesListView
        }
        .padding()
        .onAppear {
            audioManager.setup(project: project)
        }
        .onChange(of: audioManager.isRecording) { _, isRecording in
            if isRecording && visualPulseEnabled {
                startVisualPulse()
            } else {
                stopVisualPulse()
            }
        }
    }
    
    private var recordingControlsView: some View {
        VStack(spacing: 16) {
            if audioManager.isRecording {
                ZStack {
                    if isPulsing {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                    }
                    
                    Button {
                        audioManager.stopRecording()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.red)
                    }
                }
                .frame(height: 100)
            } else {
                Button {
                    audioManager.startRecording(
                        countIn: countIn,
                        clickEnabled: clickEnabled
                    )
                } label: {
                    Image(systemName: "record.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red)
                }
            }
            
            if !audioManager.isRecording {
                VStack(spacing: 12) {
                    Stepper("Count-in: \(countIn) bar\(countIn > 1 ? "s" : "")", value: $countIn, in: 1...2)
                    
                    Toggle("Click/Metronome", isOn: $clickEnabled)
                    
                    Toggle("Visual Pulse", isOn: $visualPulseEnabled)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var takesListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Takes (\(project.recordings.count))")
                .font(.headline)
            
            if project.recordings.isEmpty {
                Text("No recordings yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(project.recordings.sorted(by: { $0.createdAt > $1.createdAt })) { recording in
                            RecordingCard(recording: recording, audioManager: audioManager)
                        }
                    }
                }
            }
        }
    }
    
    private func startVisualPulse() {
        let beatsPerSecond = Double(project.bpm) / 60.0
        let interval = 1.0 / beatsPerSecond
        
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if !audioManager.isRecording {
                timer.invalidate()
                return
            }
            
            withAnimation(.easeInOut(duration: interval * 0.3)) {
                isPulsing = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * 0.3) {
                withAnimation(.easeInOut(duration: interval * 0.7)) {
                    isPulsing = false
                }
            }
        }
    }
    
    private func stopVisualPulse() {
        isPulsing = false
    }
}

struct RecordingCard: View {
    @Bindable var recording: Recording
    @ObservedObject var audioManager: AudioRecordingManager
    @State private var showingRenameAlert = false
    @State private var newName = ""
    
    var isPlaying: Bool {
        audioManager.currentlyPlayingRecording?.id == recording.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    if isPlaying {
                        audioManager.stopPlayback()
                    } else {
                        audioManager.playRecording(recording)
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(formatDuration(recording.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    recording.isFavorite.toggle()
                } label: {
                    Image(systemName: recording.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(recording.isFavorite ? .yellow : .secondary)
                }
                
                Menu {
                    Button {
                        newName = recording.name
                        showingRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        deleteRecording()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            HStack(spacing: 12) {
                Text("\(recording.bpm) BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(recording.timeTop)/\(recording.timeBottom)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(recording.createdAt.timeAgo())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .alert("Rename Take", isPresented: $showingRenameAlert) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                recording.name = newName
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func deleteRecording() {
        if let project = recording.project {
            project.recordings.removeAll { $0.id == recording.id }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Test Project")
    container.mainContext.insert(project)
    
    return RecordingsTabView(project: project)
        .modelContainer(container)
}
