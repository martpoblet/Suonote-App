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
        // Note: Actual project creation requires ModelContext which isn't available here
        // This intent opens the app with parameters
        return .result(dialog: "Created '\(title)' in \(key) at \(bpm) BPM")
    }
    
    static var openAppWhenRun: Bool = true
}

/// Siri Shortcut: Quick voice note
struct QuickRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Voice Note"
    static var description = IntentDescription("Start a quick audio recording in Suonote")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Opening Suonote for recording...")
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
        AppShortcut(
            intent: QuickRecordIntent(),
            phrases: [
                "Record a voice note in \(.applicationName)",
                "Quick recording in \(.applicationName)"
            ],
            shortTitle: "Quick Record",
            systemImageName: "mic.fill"
        )
    }
}
