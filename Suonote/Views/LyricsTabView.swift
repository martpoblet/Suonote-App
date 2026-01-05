import SwiftUI
import SwiftData

struct LyricsTabView: View {
    @Bindable var project: Project
    @State private var selectedSection: SectionTemplate?
    @State private var showingEditor = false
    
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
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(uniqueSections) { section in
                            LyricsSectionCard(
                                section: section,
                                usageCount: usageCount(for: section)
                            ) {
                                selectedSection = section
                                showingEditor = true
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)  // Extra top padding to prevent overlap
                    .padding(.bottom, 20)
                }
            }
        }
        .fullScreenCover(item: $selectedSection) { section in
            ImmersiveLyricsEditor(section: section)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                
                Image(systemName: "text.quote")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No sections yet")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Add sections in the Compose tab first")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func usageCount(for section: SectionTemplate) -> Int {
        project.arrangementItems.filter { $0.sectionTemplate?.id == section.id }.count
    }
}

// MARK: - Lyrics Section Card

struct LyricsSectionCard: View {
    let section: SectionTemplate
    let usageCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        
                        if usageCount > 1 {
                            Text("Used \(usageCount) times")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Lyrics preview
                if !section.lyricsText.isEmpty {
                    Text(section.lyricsText)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.03))
                        )
                } else {
                    HStack {
                        Image(systemName: "text.cursor")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        Text("No lyrics yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Immersive Lyrics Editor

struct ImmersiveLyricsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var section: SectionTemplate
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Text(section.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                // Text Editor
                ZStack(alignment: .topLeading) {
                    if section.lyricsText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.1))
                            
                            Text("Start writing your lyrics...")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    TextEditor(text: $section.lyricsText)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .focused($isTextEditorFocused)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
                .frame(maxHeight: .infinity)
                
                // Toolbar
                HStack(spacing: 20) {
                    Text("\(section.lyricsText.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        isTextEditorFocused = false
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .blur(radius: 20)
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Test")
    container.mainContext.insert(project)
    
    let section = SectionTemplate(name: "Verse 1", lyricsText: "This is a sample lyric\nWith multiple lines\nTo show the preview")
    section.project = project
    project.sectionTemplates.append(section)
    
    let item = ArrangementItem(orderIndex: 0)
    item.sectionTemplate = section
    item.project = project
    project.arrangementItems.append(item)
    
    return LyricsTabView(project: project)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
