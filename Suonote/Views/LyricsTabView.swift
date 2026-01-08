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
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
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
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
        }
        .fullScreenCover(item: $selectedSection) { section in
            ImmersiveLyricsEditor(section: section)
        }
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "text.quote",
            title: "No sections yet",
            message: "Add sections in the Compose tab first"
        )
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
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(section.name)
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(.white)
                        
                        if usageCount > 1 {
                            Text("Used \(usageCount) times")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Lyrics preview
                if !section.lyricsText.isEmpty {
                    Text(section.lyricsText)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                        .padding(DesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(DesignSystem.Colors.surface.opacity(0.6))
                        )
                } else {
                    HStack {
                        Image(systemName: "text.cursor")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        Text("No lyrics yet")
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animatedPress()
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
                        HStack(spacing: DesignSystem.Spacing.xxs) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.white)
                    }
                    .animatedPress()
                    
                    Spacer()
                    
                    Text(section.name)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .opacity(0)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.md)
                
                // Text Editor
                ZStack(alignment: .topLeading) {
                    if section.lyricsText.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.1))
                            
                            Text("Start writing your lyrics...")
                                .font(DesignSystem.Typography.title3)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    TextEditor(text: $section.lyricsText)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .focused($isTextEditorFocused)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                }
                .frame(maxHeight: .infinity)
                
                // Toolbar
                HStack(spacing: DesignSystem.Spacing.lg) {
                    Text("\(section.lyricsText.count) characters")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        isTextEditorFocused = false
                    } label: {
                        Text("Done")
                            .font(DesignSystem.Typography.bodyBold)
                            .foregroundStyle(DesignSystem.Colors.primaryGradient)
                    }
                    .animatedPress()
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.md)
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
