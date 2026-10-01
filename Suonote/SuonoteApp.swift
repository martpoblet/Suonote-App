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

        Self.configureSystemChrome()
    }

    /// Makes UIKit-backed chrome speak the brand: Erode for navigation
    /// titles, Manrope for controls, one teal accent for tab selection.
    /// Backgrounds are left alone so iOS 26 Liquid Glass bars stay intact.
    private static func configureSystemChrome() {
        // DesignSystem colors wrap dynamic UIColors, so these stay light/dark aware.
        let ink = UIColor(DesignSystem.Colors.textPrimary)
        let inkSecondary = UIColor(DesignSystem.Colors.textSecondary)
        let teal = UIColor(DesignSystem.Colors.primaryDark)

        // Navigation bar titles — Erode semibold, ink.
        let navigationBar = UINavigationBar.appearance()
        navigationBar.titleTextAttributes = [
            .font: UIFont.erode(17, weight: .semibold),
            .foregroundColor: ink
        ]
        navigationBar.largeTitleTextAttributes = [
            .font: UIFont.erode(34, weight: .semibold),
            .foregroundColor: ink
        ]

        // Bar button titles (Cancel, Done, Back) — Manrope.
        let barButton = UIBarButtonItem.appearance()
        for state: UIControl.State in [.normal, .highlighted] {
            barButton.setTitleTextAttributes([.font: UIFont.manrope(17, weight: .semibold)], for: state)
        }
        barButton.setTitleTextAttributes([.font: UIFont.manrope(17, weight: .medium)], for: .disabled)

        // Segmented controls — Manrope semibold.
        let segmented = UISegmentedControl.appearance()
        segmented.setTitleTextAttributes([.font: UIFont.manrope(13, weight: .semibold), .foregroundColor: inkSecondary], for: .normal)
        segmented.setTitleTextAttributes([.font: UIFont.manrope(13, weight: .semibold), .foregroundColor: ink], for: .selected)

        // Tab bar items — Manrope labels, ink when idle, teal when selected.
        // Transparent background keeps the system Liquid Glass tab bar.
        let itemAppearance = UITabBarItemAppearance()
        let tabFont = UIFont.manrope(10, weight: .semibold)
        for state in [itemAppearance.normal, itemAppearance.disabled] {
            state.iconColor = inkSecondary
            state.titleTextAttributes = [.foregroundColor: inkSecondary, .font: tabFont]
        }
        itemAppearance.selected.iconColor = teal
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: teal, .font: tabFont]

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
                .environment(\.locale, settings.appLanguage.locale ?? .autoupdatingCurrent)
                .environmentObject(cloudSyncMonitor)
                .alert("Using Local Storage", isPresented: $showMigrationAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("iCloud sync could not be opened, so Suonote started with a local recovery store. Your existing Cloud data was not deleted.")
                }
                #if DEBUG
                .task { await ScreenshotSeeder.seedIfRequested(sharedModelContainer.mainContext) }
                #endif
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
