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
import RevenueCatUI

@main
struct Medication_SidekickApp: App {
    
    // RevenueCat Customer Info Manager
    @StateObject private var customerInfoManager = CustomerInfoManager()
    @StateObject private var navigationRouter = NavigationRouter()
    
    @State private var offering: Offering?
    @State private var gateState: LaunchGateState = .unknown
    @State var themeManager = ThemeManager()
    
    
    // Gate the UI so the main app never renders until subscription status is known.
    private enum LaunchGateState: Equatable {
        case unknown
        case inactive
        case active
    }

    
    
    
    // Storage object for various data items
    //@AppStorage(AppStorageKeys.hasSetupData.rawValue) var revenueCatUserId: String = ""
    
    init() {
        
        /* Enable debug logs before calling `configure`. */
        Purchases.logLevel = .debug
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: Constants.revenueCatKey)
                .with(storeKitVersion: .storeKit2)
                .build()
        )
    }
    
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Medication.self,
            MedicationDoseEvent.self,
            MedicationSchedule.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        
        
        
        WindowGroup {
            HomeView()
                .environmentObject(navigationRouter)
                .environment(themeManager)
            
                .task {
                    
                    // Xlinker for Cursor
                    #if DEBUG
                    Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
                    //for tvOS:
                    Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection.bundle")?.load()
                    //Or for macOS:
                    Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
                    #endif
                    
                    // Seed default medications (runs once)
                    let seedService = MedicationSeedService()
                    await seedService.seedIfNeeded(container: sharedModelContainer)

                    // Generate today's events
                    try? MedicationBootstrap.generateTodayEvents(context: sharedModelContainer.mainContext)
                }
    
        }
        .modelContainer(sharedModelContainer)
    }
    
    
}
