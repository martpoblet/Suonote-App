import SwiftUI
import SwiftData

@main
struct SuonoteApp: App {

    @State private var showMigrationAlert = false
    @StateObject private var cloudSyncMonitor = CloudSyncMonitor()
    @State private var settings = AppSettings.shared

    init() {
        // Verificar fuentes al inicio
        #if DEBUG
        AppFonts.checkFonts()
        #endif

        // Brand font on segmented controls; everything else uses the
        // system Liquid Glass appearance (nav bars, tab bars, toolbars).
        let segmentedAppearance = UISegmentedControl.appearance()
        segmentedAppearance.setTitleTextAttributes([.font: UIFont.manrope(11)], for: .normal)
        segmentedAppearance.setTitleTextAttributes([.font: UIFont.manrope(11)], for: .selected)

        // Soften unselected tab items from pure black/white to the app's ink.
        // Transparent background keeps the system Liquid Glass tab bar intact;
        // selected items still follow the SwiftUI `.tint`.
        let unselected = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hexString: "A4A9B6")   // textSecondary (dark)
                : UIColor(hexString: "6E7480")   // textSecondary (light)
        }
        let itemAppearance = UITabBarItemAppearance()
        for state in [itemAppearance.normal, itemAppearance.disabled] {
            state.iconColor = unselected
            state.titleTextAttributes = [.foregroundColor: unselected]
        }
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.stackedLayoutAppearance = itemAppearance
        tabAppearance.inlineLayoutAppearance = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Project.self])
        let cloudKitContainerId = "iCloud.Suonote"
        let modelConfiguration = ModelConfiguration(
            "Cloud",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .private(cloudKitContainerId)
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ Cloud store unavailable: \(error.localizedDescription)")
            UserDefaults.standard.set(true, forKey: "didOpenLocalRecoveryStore")

            let localConfiguration = ModelConfiguration(
                "LocalRecovery",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [localConfiguration])
                print("✅ Local recovery database opened successfully")
                return container
            } catch {
                fatalError("Could not create ModelContainer after CloudKit failure: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            SplashContainerView()
                .font(DesignSystem.Typography.body)
                .tint(DesignSystem.Colors.primaryDark)
                .preferredColorScheme(settings.theme.colorScheme)
                .environmentObject(cloudSyncMonitor)
                .alert("Using Local Storage", isPresented: $showMigrationAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("iCloud sync could not be opened, so Suonote started with a local recovery store. Your existing Cloud data was not deleted.")
                }
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "didOpenLocalRecoveryStore") {
                        showMigrationAlert = true
                        UserDefaults.standard.set(false, forKey: "didOpenLocalRecoveryStore")
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
