//
//  Medication_SidekickApp.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-25.
//

import os.log
import SwiftData
import SwiftUI
import RevenueCat
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()
    private static let medicationRequestPrefix = "meddose."
    @MainActor private(set) static var hasPendingMedicationReminderOpen = false

    private override init() {}
    
    @MainActor
    static func consumePendingMedicationReminderOpen() -> Bool {
        let hadPendingOpen = hasPendingMedicationReminderOpen
        hasPendingMedicationReminderOpen = false
        return hadPendingOpen
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        
        guard response.notification.request.identifier.hasPrefix(Self.medicationRequestPrefix) else {
            return
        }
        
        Task { @MainActor in
            Self.hasPendingMedicationReminderOpen = true
            NotificationCenter.default.post(name: .medicationReminderOpened, object: nil)
        }
    }
}

private struct DatabaseUnavailableView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("Unable to Load App Data")
                .font(.title2.weight(.bold))
            Text("Medication Sidekick could not initialise its database. Try freeing storage space and relaunching the app.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

@main
struct Medication_SidekickApp: App {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick", category: "AppInit")

    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var navigationRouter = NavigationRouter()
    @Environment(\.scenePhase) private var scenePhase

    @State var themeManager = ThemeManager()

    
    
    
    // Storage object for various data items
    //@AppStorage(AppStorageKeys.hasSetupData.rawValue) var revenueCatUserId: String = ""
    
    init() {
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
        let chromeTheme = Main()
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(chromeTheme.accentPrimary)
        let headerColor = UIColor(chromeTheme.textOnAccent)
        appearance.titleTextAttributes = [.foregroundColor: headerColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: headerColor]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(chromeTheme.textOnAccent)
        
        
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        let appUserID = AppUserIdentityService.shared.getOrCreateAppUserID()
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: Constants.revenueCatKeyForPurchasesConfigure)
                .with(appUserID: appUserID)
                .with(storeKitVersion: .storeKit2)
                .build()
        )
    }
    
    
    private static let modelSchema = Schema([Medication.self, MedicationDose.self, MealTimeSetting.self])

    private let sharedModelContainer: ModelContainer? = {
        do {
            return try Self.makeModelContainer(schema: Self.modelSchema)
        } catch {
            Self.logger.fault("All ModelContainer creation attempts failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                HomeView()
                    .environmentObject(navigationRouter)
                    .environmentObject(subscriptionService)
                    .environment(themeManager)
                    .toolbarBackground(
                        LinearGradient(
                            colors: [
                                themeManager.selectedTheme.accentPrimary,
                                themeManager.selectedTheme.accentSecondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        for: .navigationBar
                    )
                    .toolbarBackground(.visible, for: .navigationBar)
                    .modelContainer(container)
            } else {
                DatabaseUnavailableView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await subscriptionService.refreshSubscriptionStatus(allowAutomaticRestore: true)
            }
        }
    }
    
    
    private static func makeModelContainer(schema: Schema) throws -> ModelContainer {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let storeURL = appSupportURL.appendingPathComponent("MedicationSidekick.store")
        let config = ModelConfiguration(
            "MedicationSidekick",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            logger.error("Primary ModelContainer init failed: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try resetStoreFiles(at: storeURL, fileManager: fileManager)
            logger.notice("Reset local SwiftData store and retrying container init")
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            logger.fault("ModelContainer recovery failed: \(error.localizedDescription, privacy: .public)")
            let memoryConfig = ModelConfiguration(
                "MedicationSidekickInMemory",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            do {
                logger.notice("Falling back to in-memory ModelContainer")
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                logger.fault("In-memory ModelContainer also failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
    }

    private static func resetStoreFiles(at storeURL: URL, fileManager: FileManager) throws {
        let parentDirectory = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)

        let sidecars = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]

        for url in sidecars where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
