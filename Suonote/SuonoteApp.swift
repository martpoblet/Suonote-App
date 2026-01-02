import SwiftUI
import SwiftData

@main
struct SuonoteApp: App {
    var body: some Scene {
        WindowGroup {
            ProjectsListView()
        }
        .modelContainer(for: [Project.self, SectionTemplate.self, ArrangementItem.self, ChordEvent.self, Recording.self])
    }
}
