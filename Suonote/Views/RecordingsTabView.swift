import SwiftUI
import SwiftData
import AVFoundation

struct RecordingsTabView: View {
    @Bindable var project: Project
    @StateObject private var audioManager = AudioRecordingManager()
    @State private var showingRecordingScreen = false
    @State private var showingTypePicker = false
    @State private var selectedRecordingType: RecordingType = .voice
    @State private var filterType: RecordingType?
    @State private var showLinkedOnly = false
    @State private var sortOrder: RecordingSortOrder = .dateDescending
    @State private var selectedRecording: Recording?
    @State private var selectedRecordingForLink: Recording?
    
    enum RecordingSortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case nameAscending = "Name A-Z"
        case durationDescending = "Longest First"
    }
    
    private var filteredAndSortedRecordings: [Recording] {
        var recordings = project.recordings
        
        // Filter by type
        if let type = filterType {
            recordings = recordings.filter { $0.recordingType == type }
        }
        
        // Filter by linked status
        if showLinkedOnly {
            recordings = recordings.filter { $0.linkedSectionId != nil }
        }
        
        // Sort
        switch sortOrder {
        case .dateDescending:
            recordings.sort { $0.createdAt > $1.createdAt }
        case .dateAscending:
            recordings.sort { $0.createdAt < $1.createdAt }
        case .nameAscending:
            recordings.sort { $0.name < $1.name }
        case .durationDescending:
            recordings.sort { $0.duration > $1.duration }
        }
        
        return recordings
    }
    
    private var uniqueSections: [SectionTemplate] {
        // Get unique sections from arrangement items
        var seen = Set<UUID>()
        var sections: [SectionTemplate] = []
        
        for item in project.arrangementItems {
            if let section = item.sectionTemplate,
               !seen.contains(section.id) {
                seen.insert(section.id)
                sections.append(section)
            }
        }
        
        return sections
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con botón de grabar
            recordingHeader
            
            Divider()
                .overlay(Color.white.opacity(0.1))
            
            // Lista de takes
            takesListView
        }
        .fullScreenCover(isPresented: $showingRecordingScreen) {
            ActiveRecordingView(
                project: project,
                audioManager: audioManager,
                recordingType: selectedRecordingType
            )
        }
        .sheet(isPresented: $showingTypePicker) {
            RecordingTypePickerSheet(selectedType: $selectedRecordingType)
        }
        .sheet(item: $selectedRecordingForLink) { recording in
            SectionLinkSheet(
                recording: recording,
                sections: uniqueSections,
                onLink: { sectionId in
                    recording.linkedSectionId = sectionId
                }
            )
        }
        .onAppear {
            audioManager.setup(project: project)
        }
    }
    
    private var recordingHeader: some View {
        VStack(spacing: 16) {
            // Record button
            Button {
                showingRecordingScreen = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 48, height: 48)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Recording")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Take \(project.recordings.count + 1) • \(selectedRecordingType.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var takesListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Takes")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Text("\(filteredAndSortedRecordings.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
                
                Spacer()
                
                Menu {
                    // Type Filter
                    Menu("Filter by Type") {
                        Button {
                            filterType = nil
                        } label: {
                            HStack {
                                Text("All Types")
                                if filterType == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        ForEach(RecordingType.allCases, id: \.self) { type in
                            Button {
                                filterType = type
                            } label: {
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                    if filterType == type {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    // Linked Filter
                    Button {
                        showLinkedOnly.toggle()
                    } label: {
                        HStack {
                            Image(systemName: showLinkedOnly ? "checkmark.square" : "square")
                            Text("Linked Only")
                        }
                    }
                    
                    Divider()
                    
                    // Sort Options
                    Menu("Sort By") {
                        ForEach(RecordingSortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Active Filters Display
            if filterType != nil || showLinkedOnly {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let type = filterType {
                            FilterChipView(
                                icon: type.icon,
                                text: type.rawValue,
                                color: type.color,
                                onRemove: { filterType = nil }
                            )
                        }
                        
                        if showLinkedOnly {
                            FilterChipView(
                                icon: "link",
                                text: "Linked",
                                color: .purple,
                                onRemove: { showLinkedOnly = false }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            
            if filteredAndSortedRecordings.isEmpty {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse)
                    
                    VStack(spacing: 6) {
                        Text(project.recordings.isEmpty ? "No recordings yet" : "No recordings match filters")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(project.recordings.isEmpty ? "Tap 'Start Recording' to begin" : "Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if !project.recordings.isEmpty {
                        Button("Clear Filters") {
                            filterType = nil
                            showLinkedOnly = false
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredAndSortedRecordings) { recording in
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
                                },
                                onDelete: {
                                    deleteRecording(recording)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
            }
        }
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
    
    var body: some View {
        HStack(spacing: 16) {
            // Play button with type indicator
            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(
                            isPlaying ? 
                                LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [recording.recordingType.color.opacity(0.3), recording.recordingType.color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: isPlaying ? Color.green.opacity(0.3) : recording.recordingType.color.opacity(0.2), radius: 8)
                    
                    if isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Info section
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(recording.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Image(systemName: recording.recordingType.icon)
                        .font(.caption)
                        .foregroundStyle(recording.recordingType.color)
                }
                
                HStack(spacing: 6) {
                    if let section = linkedSection {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(section.name)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.2))
                                .overlay(Capsule().stroke(Color.purple.opacity(0.5), lineWidth: 1))
                        )
                    } else {
                        Button(action: onLinkSection) {
                            HStack(spacing: 4) {
                                Image(systemName: "link.badge.plus")
                                    .font(.caption2)
                                Text("Link Section")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatDuration(recording.duration))
                            .font(.caption)
                    }
                    
                    Text("•")
                        .font(.caption2)
                    
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions menu
            Menu {
                Button {
                    onPlay()
                } label: {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                
                Divider()
                
                Button {
                    onLinkSection()
                } label: {
                    Label(linkedSection == nil ? "Link to Section" : "Change Section", systemImage: "link")
                }
                
                if linkedSection != nil {
                    Button {
                        recording.linkedSectionId = nil
                    } label: {
                        Label("Unlink Section", systemImage: "link.circle.fill")
                    }
                }
                
                Divider()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isPlaying ?
                        Color.green.opacity(0.05) :
                        Color.white.opacity(0.03)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        )
    }
    
    private var borderColor: Color {
        if isPlaying {
            return .green.opacity(0.5)
        } else if linkedSection != nil {
            return .purple.opacity(0.4)
        } else {
            return Color.white.opacity(0.1)
        }
    }
    
    private var borderWidth: CGFloat {
        isPlaying || linkedSection != nil ? 1.5 : 1
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
            VStack(spacing: 16) {
                // Recording info
                VStack(spacing: 8) {
                    Text(recording.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Image(systemName: recording.recordingType.icon)
                            .font(.caption)
                        Text(recording.recordingType.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(recording.recordingType.color)
                }
                .padding(.top, 8)
                
                if sections.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No sections available")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("Create sections in Compose first")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Sections grid
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(sections) { section in
                                Button {
                                    onLink(section.id)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        Text(section.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        
                                        Text("\(section.bars) bars")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(recording.linkedSectionId == section.id ? Color.purple.opacity(0.2) : Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(recording.linkedSectionId == section.id ? Color.purple : Color.white.opacity(0.1), lineWidth: recording.linkedSectionId == section.id ? 2 : 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Unlink button
                        if recording.linkedSectionId != nil {
                            Button {
                                onLink(nil)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red)
                                    
                                    Text("Remove Link")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.red.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }
                    }
                }
                
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
            .navigationTitle("Link to Section")
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

// MARK: - Filter Chip View

struct FilterChipView: View {
    let icon: String
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(Capsule().stroke(color, lineWidth: 1))
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Test", bpm: 120)
    container.mainContext.insert(project)
    
    return RecordingsTabView(project: project)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
