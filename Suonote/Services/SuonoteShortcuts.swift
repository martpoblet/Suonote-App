import AppIntents
import SwiftData

/// Siri Shortcut: Create a new songwriting project (F-07)
struct CreateProjectIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Suonote Project"
    static var description = IntentDescription("Create a new songwriting project in Suonote")
    
    @Parameter(title: "Title")
    var title: String
    
    @Parameter(title: "Key", default: "C")
    var key: String
    
    @Parameter(title: "BPM", default: 120)
    var bpm: Int
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let schema = Schema([Project.self])
        let config = ModelConfiguration(
            "Cloud",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .private("iCloud.Suonote")
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let project = Project(title: title)
        project.keyRoot = key
        project.bpm = bpm
        context.insert(project)
        try context.save()
        
        return .result(dialog: "Created '\(title)' in \(key) at \(bpm) BPM")
    }
    
    static var openAppWhenRun: Bool = true
}

/// App Shortcuts provider
struct SuonoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateProjectIntent(),
            phrases: [
                "Create a new song in \(.applicationName)",
                "New project in \(.applicationName)",
                "Start songwriting in \(.applicationName)"
            ],
            shortTitle: "New Song",
            systemImageName: "music.note"
        )
    }
}
