import SwiftUI
import SwiftData

struct CreateProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = "New Idea"
    @State private var status: ProjectStatus = .idea
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var bpm = 120
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    
                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                
                Section("Tags") {
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .onSubmit {
                                addTag()
                            }
                        
                        Button("Add") {
                            addTag()
                        }
                        .disabled(tagInput.isEmpty)
                    }
                    
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                
                Section("Settings") {
                    Stepper("BPM: \(bpm)", value: $bpm, in: 40...240)
                }
            }
            .navigationTitle("New Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            tagInput = ""
        }
    }
    
    private func createProject() {
        let project = Project(
            title: title,
            status: status,
            tags: tags,
            bpm: bpm
        )
        modelContext.insert(project)
        dismiss()
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: [Project.self])
}
