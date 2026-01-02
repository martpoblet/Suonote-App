import SwiftUI
import SwiftData

struct LyricsTabView: View {
    @Bindable var project: Project
    @State private var selectedSection: SectionTemplate?
    
    var uniqueSections: [SectionTemplate] {
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
            if uniqueSections.isEmpty {
                Text("No sections yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(uniqueSections) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.name)
                                    .font(.headline)
                                
                                let usageCount = project.arrangementItems.filter { $0.sectionTemplate?.id == section.id }.count
                                if usageCount > 1 {
                                    Text("Used \(usageCount) times")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if !section.lyricsText.isEmpty {
                                    Text(section.lyricsText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedSection) { section in
            LyricsEditorView(section: section)
        }
    }
}

struct LyricsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var section: SectionTemplate
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $section.lyricsText)
                    .font(.body)
                    .padding()
            }
            .navigationTitle(section.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Test Project")
    container.mainContext.insert(project)
    
    return LyricsTabView(project: project)
        .modelContainer(container)
}
