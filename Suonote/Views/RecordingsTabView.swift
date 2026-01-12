import SwiftUI
import SwiftData
import AVFoundation

struct RecordingsTabView: View {
    @Bindable var project: Project
    @StateObject private var audioManager = AudioRecordingManager()
    @StateObject private var effectsProcessor = AudioEffectsProcessor()
    @State private var showingRecordingScreen = false
    @State private var showingTypePicker = false
    @State private var selectedRecordingType: RecordingType = .voice
    @State private var filterType: RecordingType?
    @State private var showLinkedOnly = false
    @State private var sortOrder: RecordingSortOrder = .dateDescending
    @State private var selectedRecording: Recording?
    @State private var selectedRecordingForLink: Recording?
    @State private var showingEffects = false
    @State private var selectedRecordingForDetail: Recording?
    @State private var recordingToDelete: Recording?
    @State private var showDeleteConfirmation = false
    @State private var playingRecordingId: UUID?
    
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
    
    private var sectionsById: [UUID: SectionTemplate] {
        var map: [UUID: SectionTemplate] = [:]
        for section in uniqueSections {
            map[section.id] = section
        }
        return map
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con botón de grabar
            recordingHeader
            
            Divider()
                .overlay(DesignSystem.Colors.border)
            
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
        .sheet(isPresented: $showingEffects) {
            AudioEffectsSheet(
                settings: $effectsProcessor.settings,
                onApply: {
                    effectsProcessor.applyEffects()
                }
            )
        }
        .sheet(item: $selectedRecordingForDetail) { recording in
            RecordingDetailView(
                recording: recording,
                sections: uniqueSections,
                onUpdate: {
                    // Recording updated
                }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            audioManager.setup(project: project)
        }
        .onReceive(audioManager.$currentlyPlayingRecording) { current in
            if let current {
                playingRecordingId = current.id
            } else if !effectsProcessor.isPlaying {
                playingRecordingId = nil
            }
        }
        .alert("Delete Recording?", isPresented: $showDeleteConfirmation, presenting: recordingToDelete) { recording in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteRecording(recording)
            }
        } message: { recording in
            Text("Are you sure you want to delete '\(recording.name)'? This action cannot be undone.")
        }
    }
    
    private var recordingHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Record button
            Button {
                showingRecordingScreen = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.error.opacity(0.2))
                            .frame(width: 48, height: 48)
                        
                        Circle()
                            .fill(DesignSystem.Colors.error)
                            .frame(width: 20, height: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxs) {
                        Text("Start Recording")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(.white)
                        
                        Text("Take \(project.recordings.count + 1) • \(selectedRecordingType.rawValue)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(DesignSystem.Colors.error.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .animatedPress()
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
    
    private var takesListView: some View {
        let recordings = filteredAndSortedRecordings
        let sectionMap = sectionsById
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Takes")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(.white)
                
                Badge("\(recordings.count)", color: DesignSystem.Colors.surface)
                
                Spacer()
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Filter menu
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
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 20))
                        Text("Filter")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(DesignSystem.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1.5)
                            )
                    )
                }
                .animatedPress()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.top, DesignSystem.Spacing.xxs)
            
            // Active Filters Display
            if filterType != nil || showLinkedOnly {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
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
                                color: DesignSystem.Colors.primary,
                                onRemove: { showLinkedOnly = false }
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                }
            }
            
            if recordings.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    
                    EmptyStateView(
                        icon: "waveform.circle",
                        title: project.recordings.isEmpty ? "No recordings yet" : "No recordings match filters",
                        message: project.recordings.isEmpty ? "Tap 'Start Recording' to begin" : "Try adjusting your filters",
                        actionTitle: project.recordings.isEmpty ? nil : "Clear Filters"
                    ) {
                        if !project.recordings.isEmpty {
                            filterType = nil
                            showLinkedOnly = false
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
            } else {
                List {
                    ForEach(recordings) { recording in
                        Button(action: {
                            selectedRecordingForDetail = recording
                        }) {
                            ModernTakeCard(
                                recording: recording,
                                linkedSection: recording.linkedSectionId.flatMap { sectionMap[$0] },
                                isPlaying: playingRecordingId == recording.id,
                                onPlay: {
                                    togglePlayback(for: recording)
                                },
                                onTap: {
                                    selectedRecordingForDetail = recording
                                },
                                onLinkSection: {
                                    selectedRecordingForLink = recording
                                },
                                onDelete: {
                                    deleteRecording(recording)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.xxs,
                            leading: DesignSystem.Spacing.xl,
                            bottom: DesignSystem.Spacing.xxs,
                            trailing: DesignSystem.Spacing.xl
                        ))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                recordingToDelete = recording
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash.fill")
                            }
                            
                            if recording.linkedSectionId != nil {
                                Button {
                                    recording.linkedSectionId = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .tint(.orange)
                            }
                            
                            Button {
                                selectedRecordingForLink = recording
                            } label: {
                                Image(systemName: recording.linkedSectionId == nil ? "link.circle.fill" : "link.circle")
                            }
                            .tint(.purple)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private func deleteRecording(_ recording: Recording) {
        if let index = project.recordings.firstIndex(where: { $0.id == recording.id }) {
            project.recordings.remove(at: index)
        }
    }
    
    private func togglePlayback(for recording: Recording) {
        if playingRecordingId == recording.id {
            stopPlayback()
        } else {
            playRecordingWithEffects(recording)
        }
    }
    
    private func stopPlayback() {
        audioManager.stopPlayback()
        effectsProcessor.stop()
        playingRecordingId = nil
    }
    
    private func playRecordingWithEffects(_ recording: Recording) {
        stopPlayback()
        guard let url = FileManagerUtils.existingRecordingURL(for: recording.fileName) else {
            print("Recording file not found for: \(recording.fileName)")
            return
        }
        
        // Check if recording has individual effects
        let hasEffects = recording.reverbEnabled || recording.delayEnabled || 
                        recording.eqEnabled || recording.compressionEnabled
        
        if hasEffects {
            // Apply recording's individual effects
            effectsProcessor.settings.reverbEnabled = recording.reverbEnabled
            effectsProcessor.settings.reverbMix = recording.reverbMix
            effectsProcessor.settings.reverbSize = recording.reverbSize
            
            effectsProcessor.settings.delayEnabled = recording.delayEnabled
            effectsProcessor.settings.delayTime = recording.delayTime
            effectsProcessor.settings.delayFeedback = recording.delayFeedback
            effectsProcessor.settings.delayMix = recording.delayMix
            
            effectsProcessor.settings.eqEnabled = recording.eqEnabled
            effectsProcessor.settings.lowGain = recording.lowGain
            effectsProcessor.settings.midGain = recording.midGain
            effectsProcessor.settings.highGain = recording.highGain
            
            effectsProcessor.settings.compressionEnabled = recording.compressionEnabled
            effectsProcessor.settings.compressionThreshold = recording.compressionThreshold
            effectsProcessor.settings.compressionRatio = recording.compressionRatio
            
            effectsProcessor.applyEffects()
            
            playingRecordingId = recording.id
            do {
                try effectsProcessor.playAudio(url: url) {
                    playingRecordingId = nil
                }
            } catch {
                print("Failed to play recording with effects: \(error)")
                playingRecordingId = nil
            }
        } else {
            audioManager.playRecording(recording)
            playingRecordingId = recording.id
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
    let onTap: () -> Void
    let onLinkSection: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Play button with type indicator
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
            .onTapGesture {
                onPlay()
            }
        
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
                                Image(systemName: "link.circle.fill")
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
                
                if !activeEffects.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(activeEffects) { effect in
                            Image(systemName: effect.icon)
                                .font(.caption2)
                                .foregroundStyle(effect.color)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(effect.color.opacity(0.15))
                                )
                        }
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
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    linkedSection != nil ?
                        recording.recordingType.color.opacity(0.05) :
                        (isPlaying ? Color.green.opacity(0.05) : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        )
    }
    
    private var borderColor: Color {
        if linkedSection != nil {
            return recording.recordingType.color.opacity(0.6)
        } else if isPlaying {
            return .green.opacity(0.5)
        } else {
            return Color.white.opacity(0.1)
        }
    }
    
    private var borderWidth: CGFloat {
        isPlaying || linkedSection != nil ? 1.5 : 1
    }
    
    private struct EffectBadge: Identifiable {
        let id: String
        let icon: String
        let color: Color
    }
    
    private var activeEffects: [EffectBadge] {
        var effects: [EffectBadge] = []
        
        if recording.reverbEnabled {
            effects.append(EffectBadge(id: "reverb", icon: "waveform.path.ecg", color: .purple))
        }
        if recording.delayEnabled {
            effects.append(EffectBadge(id: "delay", icon: "arrow.triangle.2.circlepath", color: .blue))
        }
        if recording.eqEnabled {
            effects.append(EffectBadge(id: "eq", icon: "slider.horizontal.3", color: .green))
        }
        
        return effects
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
