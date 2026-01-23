import SwiftUI
import SwiftData

@main
struct SuonoteApp: App {

    init() {
        // Verificar fuentes al inicio
        #if DEBUG
        AppFonts.checkFonts()
        #endif
        
        // Configure navigation bar appearance for light mode
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DesignSystem.Colors.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(DesignSystem.Colors.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(DesignSystem.Colors.textPrimary)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(DesignSystem.Colors.tabBarBackground)
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
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
