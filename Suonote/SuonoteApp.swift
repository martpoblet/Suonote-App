import SwiftUI
import SwiftData

@main
struct SuonoteApp: App {

    @State private var showMigrationAlert = false
    @StateObject private var cloudSyncMonitor = CloudSyncMonitor()

    init() {
        UIView.appearance().overrideUserInterfaceStyle = .light
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
        UINavigationBar.appearance().tintColor = UIColor(DesignSystem.Colors.primaryDark)
        UIBarButtonItem.appearance().tintColor = UIColor(DesignSystem.Colors.primaryDark)

        // Segmented controls (Picker segmented style) should always use app font.
        let segmentedAppearance = UISegmentedControl.appearance()
        segmentedAppearance.setTitleTextAttributes(
            [
                .font: UIFont.manrope(11),
                .foregroundColor: UIColor(DesignSystem.Colors.textSecondary)
            ],
            for: .normal
        )
        segmentedAppearance.setTitleTextAttributes(
            [
                .font: UIFont.manrope(11),
                .foregroundColor: UIColor(DesignSystem.Colors.textPrimary)
            ],
            for: .selected
        )
        segmentedAppearance.backgroundColor = UIColor(DesignSystem.Colors.surfaceSecondary)
        segmentedAppearance.selectedSegmentTintColor = UIColor(DesignSystem.Colors.backgroundSecondary)
        
        // Configure tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = UIColor.clear
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        let selectedTabColor = UIColor(DesignSystem.Colors.tabBarActive)
        let normalTabColor = UIColor(DesignSystem.Colors.tabBarInactive)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = selectedTabColor
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedTabColor
        ]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = normalTabColor
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalTabColor
        ]
        tabAppearance.inlineLayoutAppearance.selected.iconColor = selectedTabColor
        tabAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedTabColor
        ]
        tabAppearance.inlineLayoutAppearance.normal.iconColor = normalTabColor
        tabAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalTabColor
        ]
        tabAppearance.compactInlineLayoutAppearance.selected.iconColor = selectedTabColor
        tabAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedTabColor
        ]
        tabAppearance.compactInlineLayoutAppearance.normal.iconColor = normalTabColor
        tabAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalTabColor
        ]
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(DesignSystem.Colors.tabBarActive)
        UITabBar.appearance().unselectedItemTintColor = UIColor(DesignSystem.Colors.tabBarInactive)
        UITabBar.appearance().backgroundColor = UIColor.clear
        UITabBar.appearance().isTranslucent = true
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
