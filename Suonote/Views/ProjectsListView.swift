import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var allProjects: [Project]
    
    @State private var searchText = ""
    @State private var selectedStatus: ProjectStatus?
    @State private var selectedTag: String?
    @State private var showingCreateSheet = false
    @State private var scrollOffset: CGFloat = 0
    @State private var projectToDelete: Project?
    @State private var showDeleteConfirmation = false
    
    var filteredProjects: [Project] {
        var projects = allProjects
        
        // Always exclude archived unless explicitly filtering for archived
        if selectedStatus != .archived {
            projects = projects.filter { $0.status != .archived }
        }
        
        if !searchText.isEmpty {
            projects = projects.filter { project in
                project.title.localizedCaseInsensitiveContains(searchText) ||
                project.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        if let status = selectedStatus {
            projects = projects.filter { $0.status == status }
        }
        
        if let tag = selectedTag {
            projects = projects.filter { $0.tags.contains(tag) }
        }
        
        return projects
    }
    
    var allTags: [String] {
        Array(Set(allProjects.flatMap { $0.tags })).sorted()
    }
    
    var body: some View {
        ZStack {
            // Background usando Design System
            ProjectBackgroundView()
            
            VStack(spacing: 0) {
                // Custom header - always at top
                customHeader
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.xs)
                
                // Filter chips
                if !allProjects.isEmpty {
                    filterChipsView
                        .padding(.top, DesignSystem.Spacing.md)
                }
                
                // Projects grid
                if filteredProjects.isEmpty {
                    VStack(spacing: 0) {
                        Spacer()
                        emptyStateView
                            .padding(.horizontal, DesignSystem.Spacing.xxl)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ModernProjectCard(project: project)
                            }
                            .listRowInsets(EdgeInsets(
                                top: DesignSystem.Spacing.xs,
                                leading: DesignSystem.Spacing.xl,
                                bottom: DesignSystem.Spacing.xs,
                                trailing: DesignSystem.Spacing.xl
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    projectToDelete = project
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: DesignSystem.Icons.delete)
                                }
                                
                                Button {
                                    archiveProject(project)
                                } label: {
                                    Label(project.status == .archived ? "Unarchive" : "Archive", 
                                          systemImage: project.status == .archived ? "tray.and.arrow.up.fill" : "archivebox.fill")
                                }
                                .tint(DesignSystem.Colors.warning)
                                
                                Button {
                                    cloneProject(project)
                                } label: {
                                    Label("Clone", systemImage: "doc.on.doc.fill")
                                }
                                .tint(DesignSystem.Colors.info)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 16, for: .scrollContent)
                }
            }
            
            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton {
                        showingCreateSheet = true
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProjectView()
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirmation, presenting: projectToDelete) { project in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteProject(project)
            }
        } message: { project in
            Text("Are you sure you want to delete '\(project.title)'? This action cannot be undone.")
        }
            }
    
    private var customHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            AppLogoView(height: 24)
                .padding(.bottom, 2)

            Text("Your Ideas")
                .font(DesignSystem.Typography.xxl)
                .fontWeight(.bold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            if !allProjects.isEmpty {
                Text("\(allProjects.count) project\(allProjects.count == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            // Search bar con glassmorphism
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                TextField("Search ideas...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                if !searchText.isEmpty {
                    Button {
                        withAnimation(DesignSystem.Animations.quickSpring) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .glassStyle(cornerRadius: DesignSystem.CornerRadius.lg)
            .padding(.top, DesignSystem.Spacing.xs)
        }
    }
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    ModernFilterChip(
                        title: status.rawValue,
                        icon: statusIcon(for: status),
                        isSelected: selectedStatus == status,
                        color: statusColor(for: status)
                    ) {
                        withAnimation(DesignSystem.Animations.smoothSpring) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                    }
                }
                
                if !allTags.isEmpty {
                    Divider()
                        .frame(height: 30)
                        .overlay(DesignSystem.Colors.border.opacity(0.5))
                    
                    ForEach(allTags, id: \.self) { tag in
                        ModernFilterChip(
                            title: tag,
                            icon: "tag.fill",
                            isSelected: selectedTag == tag,
                            color: DesignSystem.Colors.info
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var emptyStateView: some View {
        // Usar el componente EmptyStateView del Design System
        EmptyStateView(
            icon: "music.note.list",
            title: allProjects.isEmpty ? "No Ideas Yet" : "No Results",
            message: allProjects.isEmpty ? 
                "Tap the + button to capture your first idea" : 
                "Try adjusting your filters",
            actionTitle: allProjects.isEmpty ? "Create Project" : nil
        ) {
            showingCreateSheet = true
        }
    }
    
    private func statusIcon(for status: ProjectStatus) -> String {
        switch status {
        case .idea: return "lightbulb.fill"
        case .inProgress: return "hammer.fill"
        case .polished: return "sparkles"
        case .finished: return "checkmark.seal.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .idea: return DesignSystem.Colors.info
        case .inProgress: return DesignSystem.Colors.warning
        case .polished: return DesignSystem.Colors.primary
        case .finished: return DesignSystem.Colors.success
        case .archived: return DesignSystem.Colors.secondary
        }
    }
    
    private func deleteProject(_ project: Project) {
        // The confirmation alert is handled by swipeActions' role: .destructive
        modelContext.delete(project)
        try? modelContext.save()
    }
    
    private func archiveProject(_ project: Project) {
        project.status = project.status == .archived ? .idea : .archived
        project.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func cloneProject(_ project: Project) {
        // Create clone in background to avoid animation conflicts
        DispatchQueue.main.async {
            let clonedProject = Project(
                title: "\(project.title) (Copy)",
                status: project.status,
                tags: project.tags,
                keyRoot: project.keyRoot,
                keyMode: project.keyMode,
                bpm: project.bpm,
                timeTop: project.timeTop,
                timeBottom: project.timeBottom
            )
            clonedProject.studioStyleRaw = project.studioStyleRaw
            
            // Clone arrangement items and sections
            for item in project.arrangementItems {
                if let originalSection = item.sectionTemplate {
                    let clonedSection = SectionTemplate(
                        name: originalSection.name,
                        bars: originalSection.bars,
                        patternPreset: originalSection.patternPreset,
                        lyricsText: originalSection.lyricsText,
                        notesText: originalSection.notesText,
                        colorHex: originalSection.colorHex ?? SectionColor.sage.hex
                    )
                    
                    // Clone chord events
                    for chordEvent in originalSection.chordEvents {
                        let clonedChord = ChordEvent(
                            barIndex: chordEvent.barIndex,
                            beatOffset: chordEvent.beatOffset,
                            duration: chordEvent.duration,
                            isRest: chordEvent.isRest,
                            root: chordEvent.root,
                            quality: chordEvent.quality,
                            extensions: chordEvent.extensions,
                            slashRoot: chordEvent.slashRoot
                        )
                        clonedSection.chordEvents.append(clonedChord)
                    }
                    
                    let clonedArrangementItem = ArrangementItem(
                        orderIndex: item.orderIndex,
                        labelOverride: item.labelOverride
                    )
                    clonedArrangementItem.sectionTemplate = clonedSection
                    clonedProject.arrangementItems.append(clonedArrangementItem)
                }
            }

            for track in project.studioTracks {
                let clonedTrack = StudioTrack(
                    name: track.name,
                    instrument: track.instrument,
                    orderIndex: track.orderIndex,
                    isMuted: track.isMuted,
                    isSolo: track.isSolo,
                    audioRecordingId: track.audioRecordingId,
                    audioStartBeat: track.audioStartBeat
                )
                clonedTrack.octaveShift = track.octaveShift
                clonedTrack.volume = track.volume
                clonedTrack.pan = track.pan
                clonedTrack.variant = track.variant
                clonedTrack.drumPreset = track.drumPreset

                for note in track.notes {
                    let clonedNote = StudioNote(
                        startBeat: note.startBeat,
                        duration: note.duration,
                        pitch: note.pitch,
                        velocity: note.velocity
                    )
                    clonedTrack.notes.append(clonedNote)
                }

                clonedProject.studioTracks.append(clonedTrack)
            }
            
            self.modelContext.insert(clonedProject)
            try? self.modelContext.save()
        }
    }
}

// MARK: - Modern Components

struct ModernFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)

                Text(title)
                    .font(DesignSystem.Typography.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(color.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(color.opacity(0.6), lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(DesignSystem.Colors.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                            )
                    }
                }
            )
            .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

struct ModernProjectCard: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(statusColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(project.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                // Metadata
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                        Text("\(project.keyRoot)\(project.keyMode == .minor ? "m" : "")")
                    }
                    .font(DesignSystem.Typography.caption)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "metronome")
                        Text("\(project.bpm)")
                    }
                    .font(DesignSystem.Typography.caption)
                    
                    if project.recordingsCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                            Text("\(project.recordingsCount)")
                        }
                        .font(DesignSystem.Typography.caption)
                    }
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                // Tags
                if !project.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(project.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(DesignSystem.Typography.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(DesignSystem.Colors.info.opacity(0.15))
                                .foregroundStyle(DesignSystem.Colors.info)
                                .clipShape(Capsule())
                        }
                        if project.tags.count > 2 {
                            Text("+\(project.tags.count - 2)")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
    }
    
    private var statusColor: Color {
        switch project.status {
        case .idea: return DesignSystem.Colors.info
        case .inProgress: return DesignSystem.Colors.warning
        case .polished: return DesignSystem.Colors.primary
        case .finished: return DesignSystem.Colors.success
        case .archived: return DesignSystem.Colors.secondary
        }
    }
}

struct StatusBadge: View {
    let status: ProjectStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.micro)
                .fontWeight(.bold)
            Text(status.rawValue)
                .font(DesignSystem.Typography.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DesignSystem.Colors.surfaceSecondary)
        .foregroundStyle(DesignSystem.Colors.textPrimary)
        .clipShape(Capsule())
    }
    
    private var icon: String {
        switch status {
        case .idea: return "lightbulb.fill"
        case .inProgress: return "hammer.fill"
        case .polished: return "sparkles"
        case .finished: return "checkmark.seal.fill"
        case .archived: return "archivebox.fill"
        }
    }
}

struct FloatingActionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 64, height: 64)
                
                Image(systemName: "plus")
                    .font(DesignSystem.Typography.sm)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.Colors.textWhite)
            }
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: UUID())
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    
    let project1 = Project(title: "Summer Vibes", status: .idea, tags: ["Pop", "Upbeat"], bpm: 128)
    let project2 = Project(title: "Midnight Jazz", status: .inProgress, tags: ["Jazz", "Chill"], keyRoot: "Dm", keyMode: .minor, bpm: 85)
    
    container.mainContext.insert(project1)
    container.mainContext.insert(project2)
    
    return NavigationStack {
        ProjectsListView()
    }
    .modelContainer(container)
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? DesignSystem.Colors.primary.opacity(0.3) : DesignSystem.Colors.surface)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? DesignSystem.Colors.primary.opacity(0.6) : DesignSystem.Colors.border, lineWidth: 1)
                )
        }
    }
}

struct ProjectCardView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                StatusPill(status: project.status)
            }
            
            HStack(spacing: 12) {
                if !project.keyRoot.isEmpty {
                    Label("\(project.keyRoot) \(project.keyMode.rawValue)", systemImage: "music.note")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                Label("\(project.bpm) BPM", systemImage: "metronome")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                if project.recordingsCount > 0 {
                    Label("\(project.recordingsCount) takes", systemImage: "waveform")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            
            if !project.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(project.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(DesignSystem.Typography.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.info.opacity(0.2))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .clipShape(Capsule())
                    }
                    if project.tags.count > 3 {
                        Text("+\(project.tags.count - 3)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            Text("Edited \(project.updatedAt.timeAgo())")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding()
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusPill: View {
    let status: ProjectStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .idea: return DesignSystem.Colors.info
        case .inProgress: return DesignSystem.Colors.warning
        case .polished: return DesignSystem.Colors.primary
        case .finished: return DesignSystem.Colors.success
        case .archived: return DesignSystem.Colors.secondary
        }
    }
}

#Preview {
    ProjectsListView()
        .modelContainer(for: [Project.self])
}
