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
    
    var filteredProjects: [Project] {
        var projects = allProjects
        
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
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                customHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                
                // Filter chips
                if !allProjects.isEmpty {
                    filterChipsView
                        .padding(.top, 16)
                }
                
                // Projects grid
                if filteredProjects.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredProjects) { project in
                                NavigationLink(destination: ProjectDetailView(project: project)) {
                                    ModernProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
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
        .preferredColorScheme(.dark)
    }
    
    private var customHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Ideas")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(white: 0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            if !allProjects.isEmpty {
                Text("\(allProjects.count) project\(allProjects.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search ideas...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.top, 8)
        }
    }
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    ModernFilterChip(
                        title: status.rawValue,
                        icon: statusIcon(for: status),
                        isSelected: selectedStatus == status,
                        color: statusColor(for: status)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                    }
                }
                
                if !allTags.isEmpty {
                    Divider()
                        .frame(height: 30)
                        .overlay(Color.white.opacity(0.2))
                    
                    ForEach(allTags, id: \.self) { tag in
                        ModernFilterChip(
                            title: tag,
                            icon: "tag.fill",
                            isSelected: selectedTag == tag,
                            color: .cyan
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
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text(allProjects.isEmpty ? "No ideas yet" : "No results")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text(allProjects.isEmpty ? "Tap the + button to capture your first idea" : "Try adjusting your filters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
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
        case .idea: return .yellow
        case .inProgress: return .orange
        case .polished: return .purple
        case .finished: return .green
        case .archived: return .gray
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
                    .font(.system(size: 12, weight: .semibold))
                
                Text(title)
                    .font(.subheadline.weight(.medium))
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
                                    .stroke(color, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            )
            .foregroundStyle(isSelected ? color : .white.opacity(0.7))
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
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                // Metadata
                HStack(spacing: 12) {
                    Label("\(project.keyRoot)\(project.keyMode == .minor ? "m" : "")", systemImage: "music.note")
                        .font(.caption)
                    
                    Label("\(project.bpm)", systemImage: "metronome")
                        .font(.caption)
                    
                    if project.recordingsCount > 0 {
                        Label("\(project.recordingsCount)", systemImage: "waveform")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
                
                // Tags
                if !project.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(project.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.cyan.opacity(0.15))
                                    .foregroundStyle(.cyan)
                                    .clipShape(Capsule())
                            }
                            if project.tags.count > 2 {
                                Text("+\(project.tags.count - 2)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var statusColor: Color {
        switch project.status {
        case .idea: return .yellow
        case .inProgress: return .orange
        case .polished: return .purple
        case .finished: return .green
        case .archived: return .gray
        }
    }
}

struct StatusBadge: View {
    let status: ProjectStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(status.rawValue)
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.25))
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
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.purple.opacity(0.5), radius: 20, x: 0, y: 10)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
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
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct ProjectCardView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                StatusPill(status: project.status)
            }
            
            HStack(spacing: 12) {
                if !project.keyRoot.isEmpty {
                    Label("\(project.keyRoot) \(project.keyMode.rawValue)", systemImage: "music.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Label("\(project.bpm) BPM", systemImage: "metronome")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if project.recordingsCount > 0 {
                    Label("\(project.recordingsCount) takes", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !project.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(project.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    if project.tags.count > 3 {
                        Text("+\(project.tags.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Text("Edited \(project.updatedAt.timeAgo())")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusPill: View {
    let status: ProjectStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .idea: return .blue
        case .inProgress: return .orange
        case .polished: return .purple
        case .finished: return .green
        case .archived: return .gray
        }
    }
}

#Preview {
    ProjectsListView()
        .modelContainer(for: [Project.self])
}
