import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var allProjects: [Project]
    
    @State private var searchText = ""
    @State private var selectedStatus: ProjectStatus?
    @State private var selectedTag: String?
    @State private var showingCreateSheet = false
    
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
        NavigationStack {
            VStack(spacing: 0) {
                filterChipsView
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectCardView(project: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Projects")
            .searchable(text: $searchText, prompt: "Search projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("New Idea", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateProjectView()
            }
        }
    }
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Filter:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    FilterChip(
                        title: status.rawValue,
                        isSelected: selectedStatus == status
                    ) {
                        selectedStatus = selectedStatus == status ? nil : status
                    }
                }
                
                if !allTags.isEmpty {
                    Divider()
                        .frame(height: 20)
                    
                    ForEach(allTags, id: \.self) { tag in
                        FilterChip(
                            title: tag,
                            isSelected: selectedTag == tag
                        ) {
                            selectedTag = selectedTag == tag ? nil : tag
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemBackground))
    }
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
