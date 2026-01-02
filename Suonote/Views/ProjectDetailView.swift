import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                Text("Compose").tag(0)
                Text("Lyrics").tag(1)
                Text("Recordings").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
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
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
