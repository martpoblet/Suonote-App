import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Project Detail View
/// The song shell: Compose, Studio, Lyrics and Record tabs, one shared
/// transport (tab bar accessory) and the song's title + status in the
/// navigation bar.
struct ProjectDetailView: View {
    // MARK: - Properties
    @Bindable var project: Project
    @State private var selectedTab: ProjectDetailTab
    @State private var showingEditSheet = false
    @State private var showingStatusPicker = false
    @StateObject private var playback = StudioPlaybackEngine()

    init(project: Project, initialTab: ProjectDetailTab = .compose) {
        self.project = project
        _selectedTab = State(initialValue: initialTab)
    }

    // MARK: - Body
    var body: some View {
        projectTabView
            // Single transport for the whole project: the Studio-styled mini
            // player shows on every tab (always-applied accessory means the
            // TabView is never rebuilt → no stutter when switching tabs).
            .tabViewBottomAccessory {
                MiniTransportView(project: project)
            }
            .environmentObject(playback)
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleView
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    .accessibilityLabel("Song details")
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditProjectSheet(project: project)
                    .studioModalStyle()
            }
            .sheet(isPresented: $showingStatusPicker) {
                StatusPickerSheet(project: project)
                    .studioModalStyle()
            }
            .onAppear {
                updateWidgetData()
            }
            .onChange(of: project.updatedAt) { _, _ in
                updateWidgetData()
            }
            .onChange(of: selectedTab) { _, _ in
                HapticFeedback.selection.trigger()
            }
    }

    /// Erode title over a quiet, tappable status line.
    private var titleView: some View {
        VStack(spacing: 1) {
            Text(project.title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 220)

            HStack(spacing: 6) {
                Button {
                    showingStatusPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(project.status.swiftUIColor)
                            .frame(width: 6, height: 6)
                        Text(project.status.libraryDisplayName)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Status: \(project.status.libraryDisplayName)")
                .accessibilityHint("Changes the song's status")

                SyncStatusIndicator(style: .minimal)
            }
        }
    }

    private var projectTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(ProjectDetailTab.compose.title, systemImage: ProjectDetailTab.compose.icon, value: .compose) {
                ProjectTabContainer { ComposeTabView(project: project) }
            }
            Tab(ProjectDetailTab.studio.title, systemImage: ProjectDetailTab.studio.icon, value: .studio) {
                ProjectTabContainer { StudioTabView(project: project) }
            }
            Tab(ProjectDetailTab.lyrics.title, systemImage: ProjectDetailTab.lyrics.icon, value: .lyrics) {
                ProjectTabContainer { LyricsTabView(project: project) }
            }
            Tab(ProjectDetailTab.record.title, systemImage: ProjectDetailTab.record.icon, value: .record) {
                ProjectTabContainer { RecordingsTabView(project: project) }
            }
        }
        // One brand accent across every tab.
        .tint(DesignSystem.Colors.primaryDark)
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: - Helper Methods

    private func updateWidgetData() {
        WidgetSongSnapshot.publish(project)
    }
}

struct ProjectBackgroundView: View {
    static let gradient = DesignSystem.Colors.background

    var body: some View {
        Self.gradient
            .ignoresSafeArea()
    }
}

struct ProjectTabContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            ProjectBackgroundView()
            content
        }
    }
}

// MARK: - Flow Layout
/// Wrapping layout for chips and tags (used across the app).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Summer Vibes", status: .inProgress, tags: ["Pop"], bpm: 128)
    container.mainContext.insert(project)
    
    return NavigationStack {
        ProjectDetailView(project: project)
    }
    .modelContainer(container)
}
