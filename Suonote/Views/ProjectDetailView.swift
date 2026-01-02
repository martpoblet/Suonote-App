import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @State private var selectedTab = 0
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Background
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
                // Custom Tab Bar
                customTabBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                
                // Content
                TabView(selection: $selectedTab) {
                    ComposeTabView(project: project)
                        .tag(0)
                    
                    LyricsTabView(project: project)
                        .tag(1)
                    
                    RecordingsTabView(project: project)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(project.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Label("\(project.keyRoot) \(project.keyMode.rawValue)", systemImage: "music.note")
                        Text("•")
                        Label("\(project.bpm) BPM", systemImage: "metronome")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title3.weight(selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                        
                        Text(tab.title)
                            .font(.caption.weight(selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                        
                        if selectedTab == index {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var tabs: [(title: String, icon: String)] {
        [
            ("Compose", "music.note.list"),
            ("Lyrics", "text.quote"),
            ("Record", "waveform.circle.fill")
        ]
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
