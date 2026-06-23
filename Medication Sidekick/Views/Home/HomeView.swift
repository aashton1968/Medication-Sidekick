//
//  HomeView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2024-10-31.
//

import SwiftUI
import SwiftData
import os.log

struct HomeView: View {
    
    @EnvironmentObject var navigationRouter: NavigationRouter
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    
    @State private var showAbout = false
    @State private var sidebarOpen = false
    @State private var showingInitialSubscriptionPrompt = false
    @AppStorage(AppStorageKeys.hasShownInitialSubscriptionPrompt.rawValue)
    private var hasShownInitialSubscriptionPrompt: Bool = false
    private let notificationService = MedicationNotificationService()
    
    let customConfig = SidebarConfiguration(
        width:  270,
        animationDuration: 0.4,
        minimumSwipeDistance: 80,
        velocityThreshold: 500
    )
    
    
    var body: some View {
        
        ZStack {
            NavigationStack(path: $navigationRouter.path) {
                SlidingSidebar(isOpen: $sidebarOpen, configuration: customConfig) {
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Today")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                Text("Your next doses and progress")
                                    .font(.subheadline)
                                    .foregroundStyle(themeManager.selectedTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                            TodaySnapshotSection(openTodayButtonTitle: "Open Today")
                                .padding(.horizontal)

                            /*
                            Text("This Week")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 4)
                             */
                            
                            WeeklyCompletionChartView()
                                .padding(.horizontal)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity)
                    }
                } sidebar: {
                    SidebarContentView()
                        .environmentObject(navigationRouter)
                }
                .navigationDestination(for: Route.self) { route in
                    destinationView(for: route)
                }
                
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
                
               
                
                // Menu Button
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            sidebarOpen.toggle()
                        }) {
                            Label {
                                Text("Menu")
                            } icon: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 20, weight: .bold))
                                    .accessibilityLabel("Menu")
                            }
                        }
                    }
                }
                // Context menu
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Section("Actions") {
                                Button {
                                    showAbout = true
                                } label: {
                                    Label("About", systemImage: "info.circle")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20, weight: .bold))
                                .accessibilityLabel("More")
                        }
                            
                    }
                }
            }
        }
        .sheet(isPresented: $showAbout, content: {
            AboutView()
                .environment(themeManager)
        })
        .sheet(isPresented: $showingInitialSubscriptionPrompt) {
            SubscriptionSheetView()
        }
        
        .task {
            await AppStartupSequence.runPhase1IfNeeded(
                subscriptionService: subscriptionService,
                container: modelContext.container,
                mainContext: modelContext
            )
            await generateDosesForActiveMedications()
            await notificationService.requestAuthorizationIfNeeded()
            await syncMedicationNotifications()
            
            if AppNotificationDelegate.consumePendingMedicationReminderOpen() {
                sidebarOpen = false
                navigationRouter.navigate(.todayView)
            }
            /*
            if navigationRouter.path.isEmpty {
                navigationRouter.navigate(.todayView)
            }
             */
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationDidChange)) { _ in
            Task {
                await syncMedicationNotifications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationReminderOpened)) { _ in
            sidebarOpen = false
            navigationRouter.navigate(.todayView)
        }
        .onChange(of: subscriptionService.hasLoadedCustomerInfo) { _, loaded in
            guard loaded else { return }
            presentInitialSubscriptionPromptIfNeeded()
        }
        .onChange(of: subscriptionService.isPro) { _, isPro in
            guard !isPro else { return }
            presentInitialSubscriptionPromptIfNeeded()
        }
        .toast()
           
    }

    // MARK: - Navigation Destination Builder
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {

        case .home:
            EmptyView()

        case .todayView:
            TodayView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medications:
            MedicationListView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medicationSchedule:
            MedicationSchedulesView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medicationNew:
            MedicationAddView()
                .environmentObject(navigationRouter)
                .environment(themeManager)

        case .mealTimeSettings:
            MealTimeListView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .settings:
            SettingsView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .help:
            HelpView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medication(let id):
            medicationDestination(id: id)
        }
    }

    // MARK: - Detail Fetch Helpers
    @ViewBuilder
    private func medicationDestination(id: UUID) -> some View {
        let descriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.id == id }
        )

        if let medication = try? modelContext.fetch(descriptor).first {
            MedicationDetailView(medicationID: medication.id)
                .environmentObject(navigationRouter)
                .environment(themeManager)
        } else {
            Text("Medication not found")
        }
    }
    
    @MainActor
    private func generateDosesForActiveMedications() async {
        do {
            let descriptor = FetchDescriptor<Medication>()
            let allMedications = try modelContext.fetch(descriptor)
            let active = allMedications.filter { $0.isActive && !$0.mealsRaw.isEmpty }
            for medication in active {
                try? MedicationDoseGenerator.generateUpcomingDoses(
                    for: medication,
                    modelContext: modelContext
                )
            }
            try modelContext.save()
        } catch {
            os_log(.error, "Failed to generate doses: %{public}@", error.localizedDescription)
        }
    }

    @MainActor
    private func syncMedicationNotifications() async {
        await notificationService.syncScheduledDoseNotifications(modelContext: modelContext)
    }

    @MainActor
    private func presentInitialSubscriptionPromptIfNeeded() {
        guard subscriptionService.hasLoadedCustomerInfo else { return }
        guard !subscriptionService.isPro else { return }
        guard !hasShownInitialSubscriptionPrompt else { return }
        hasShownInitialSubscriptionPrompt = true
        showingInitialSubscriptionPrompt = true
    }
}

#if DEBUG
#Preview {
    let themeManager = ThemeManager()
    return NavPreview {
        HomeView()
    }
    .modelContainer(PreviewData.container)
    .environmentObject(NavigationRouter())
    .environmentObject(SubscriptionService())
    .environment(themeManager)
}
#endif
