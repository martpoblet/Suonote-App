import SwiftUI
import SwiftData

@main
struct SuonoteApp: App {

    init() {
        // Verificar fuentes al inicio
        #if DEBUG
        AppFonts.checkFonts()
        #endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Project.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Migration failed - delete old store and try again
            print("⚠️ Migration failed, deleting old database...")
            
            // Delete the old store
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)
            
            // Try creating container again
            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ New database created successfully")
                return container
            } catch {
                fatalError("Could not create ModelContainer even after deleting old store: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ProjectsListView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
