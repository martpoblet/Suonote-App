import SwiftUI
import SwiftData
import os

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

    /// One container for the whole process (the Siri intent uses it too).
    private var sharedModelContainer: ModelContainer { AppContainer.shared }
    
    var body: some Scene {
        WindowGroup {
            SplashContainerView()
                .font(DesignSystem.Typography.body)
                .tint(DesignSystem.Colors.primaryDark)
                .preferredColorScheme(settings.theme.colorScheme)
                .environment(\.locale, settings.appLanguage.locale ?? .autoupdatingCurrent)
                .environmentObject(cloudSyncMonitor)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if AppContainer.storageMode != .cloud {
                        Button {
                            showMigrationAlert = true
                        } label: {
                            Label("Not syncing with iCloud", systemImage: "exclamationmark.icloud")
                                .font(DesignSystem.Typography.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(DesignSystem.Colors.warning.opacity(0.2))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                }
                .alert("Using Local Storage", isPresented: $showMigrationAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    switch AppContainer.storageMode {
                    case .cloud:
                        EmptyView()
                    case .localRecovery(let backupSaved):
                        if backupSaved {
                            Text("iCloud sync could not be opened, so Suonote started with an empty local store. A backup copy of your previous data was saved on this device.")
                        } else {
                            Text("iCloud sync could not be opened, so Suonote started with an empty local store. Your songs may not show up until iCloud sync works again.")
                        }
                    case .memoryOnly:
                        Text("Suonote could not open its storage. Songs you create now will be lost when you close the app.")
                    }
                }
                #if DEBUG
                .task { await ScreenshotSeeder.seedIfRequested(sharedModelContainer.mainContext) }
                #endif
                .onAppear {
                    // The warning stays until the iCloud store opens again.
                    if AppContainer.storageMode != .cloud {
                        showMigrationAlert = true
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Model container

/// Opens the SwiftData store once per launch.
///
/// Order of attempts: the iCloud-backed store, then (after saving a copy of the
/// existing store files) an empty local-recovery store, then an in-memory store
/// so the app can still launch and explain what happened.
enum AppContainer {
    enum StorageMode: Equatable {
        case cloud
        /// iCloud store failed; `backupSaved` is whether the old store files were copied aside.
        case localRecovery(backupSaved: Bool)
        /// Nothing could be opened on disk: nothing will be kept.
        case memoryOnly
    }

    private static let recoveryKey = "didOpenLocalRecoveryStore"
    private static let backupKey = "localRecoveryBackupSaved"

    private static let opened: (container: ModelContainer, mode: StorageMode) = open()

    static var shared: ModelContainer { opened.container }
    static var storageMode: StorageMode { opened.mode }

    private static func open() -> (container: ModelContainer, mode: StorageMode) {
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
        let defaults = UserDefaults.standard

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // iCloud works again: the recovery warning can go away.
            defaults.set(false, forKey: recoveryKey)
            defaults.set(false, forKey: backupKey)
            return (container, .cloud)
        } catch {
            AppLog.general.error("Cloud store unavailable: \(error.localizedDescription)")
        }

        // Keep a copy of what is on disk before starting from an empty store.
        // Only the first time: later launches in recovery mode reuse that backup.
        let alreadyRecovering = defaults.bool(forKey: recoveryKey)
        let backupSaved = alreadyRecovering ? defaults.bool(forKey: backupKey) : backupExistingStores()
        defaults.set(true, forKey: recoveryKey)
        defaults.set(backupSaved, forKey: backupKey)

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
            AppLog.general.info("Local recovery database opened successfully")
            return (container, .localRecovery(backupSaved: backupSaved))
        } catch {
            AppLog.general.error("Local recovery store unavailable: \(error.localizedDescription)")
        }

        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return (try ModelContainer(for: schema, configurations: [memoryConfiguration]), .memoryOnly)
        } catch {
            fatalError("Could not create even an in-memory ModelContainer: \(error)")
        }
    }

    /// Copies the existing store files (and their -wal/-shm companions) to
    /// Application Support/Backups/<timestamp>/. Best effort.
    private static func backupExistingStores() -> Bool {
        let fileManager = FileManager.default
        do {
            let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let storeFiles = try fileManager.contentsOfDirectory(atPath: support.path).filter {
                $0.hasPrefix("Cloud.store") || $0.hasPrefix("default.store")
            }
            guard !storeFiles.isEmpty else { return false }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let folder = support
                .appendingPathComponent("Backups", isDirectory: true)
                .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

            var copied = 0
            for name in storeFiles {
                let source = support.appendingPathComponent(name)
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
                try fileManager.copyItem(at: source, to: folder.appendingPathComponent(name))
                copied += 1
            }
            return copied > 0
        } catch {
            AppLog.general.error("Store backup failed: \(error.localizedDescription)")
            return false
        }
    }
}
