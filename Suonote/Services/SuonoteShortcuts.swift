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
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Use the app's own container: a second CloudKit-backed container on
        // the same store would compete with it.
        let context = AppContainer.shared.mainContext

        // Same limits the Project initializer applies (20...300 BPM, a real key).
        let clampedBpm = max(20, min(300, bpm))
        let keyText = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = keyText.prefix(1).uppercased() + String(keyText.dropFirst())
        let keyRoot = MusicTheory.noteIndex(candidate) == nil ? "C" : MusicTheory.normalize(candidate)

        let project = Project(title: title, keyRoot: keyRoot, bpm: clampedBpm)
        context.insert(project)
        try context.save()
        
        return .result(dialog: "Created '\(project.title)' in \(project.keyRoot) at \(project.bpm) BPM")
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
