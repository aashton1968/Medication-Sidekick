//
//  MainTabView.swift
//  Medication Sidekick
//
//  Root tab bar. Owns app startup work, notification deep-links and the
//  initial paywall prompt (previously in HomeView).
//

import SwiftUI
import SwiftData
import UIKit
import os.log

struct MainTabView: View {

    @State private var now = Date()

    var body: some View {
        MainTabContent(now: now)
            .task {
                // Keeps "due now" / overdue state and the pill's today-range query fresh.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    now = Date()
                }
            }
    }
}

/// Split from `MainTabView` so the dose query is rebuilt (new "today" range) whenever the clock ticks.
private struct MainTabContent: View {

    @Environment(NavigationRouter.self) var navigationRouter
    @Environment(SubscriptionService.self) var subscriptionService
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager

    let now: Date

    /// Today's doses, for the floating pill.
    @Query private var todayDoses: [MedicationDose]

    init(now: Date) {
        self.now = now
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        _todayDoses = Query(filter: #Predicate<MedicationDose> {
            $0.scheduledDate >= start && $0.scheduledDate < end
        })
    }

    private var pillState: DosePillState? {
        DosePillState(doses: todayDoses, now: now)
    }

    /// On iPad the tab bar floats at the top, over Home's dark teal hero band, where the
    /// system's default (dark) label color is low-contrast — force light labels there only.
    /// On iPhone the bar sits at the bottom over lighter content, so leave it adaptive.
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @State private var showingInitialSubscriptionPrompt = false
    @AppStorage(AppStorageKeys.hasShownInitialSubscriptionPrompt.rawValue)
    private var hasShownInitialSubscriptionPrompt: Bool = false
    private let notificationService = MedicationNotificationService()
    private let refillReminderService = MedicationRefillReminderService()
    @State private var notificationSyncTask: Task<Void, Never>?

    var body: some View {
        @Bindable var router = navigationRouter
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView()
                        .routeDestinations()
                }
            }

            Tab("Medications", systemImage: "pills.fill", value: AppTab.medicines) {
                NavigationStack(path: $router.medicinesPath) {
                    MedicationListView()
                        .routeDestinations()
                }
            }

            Tab("More", systemImage: "ellipsis.circle.fill", value: AppTab.more) {
                NavigationStack(path: $router.morePath) {
                    MoreView()
                        .routeDestinations()
                }
            }
        }
        .tint(themeManager.selectedTheme.accentTint)
        .toolbarColorScheme(isPad ? .dark : nil, for: .tabBar)
        // Without this, the tab bar (and the accessory beside it) never minimizes, so
        // `tabViewBottomAccessoryPlacement` stays `.expanded` no matter how content scrolls.
        .tabBarMinimizeBehavior(.onScrollDown)
        .dosePillAccessory(pillState)
        .sheet(isPresented: $showingInitialSubscriptionPrompt) {
            PaywallView()
        }
        .task {
            await AppStartupSequence.runPhase1IfNeeded(
                subscriptionService: subscriptionService,
                container: modelContext.container,
                mainContext: modelContext
            )
            await generateDosesForActiveMedications()
            await notificationService.requestAuthorizationIfNeeded()
            await refillReminderService.requestAuthorizationIfNeeded()
            await syncMedicationNotifications()

            if AppNotificationDelegate.consumePendingMedicationReminderOpen() {
                navigationRouter.navigate(.home)
            }
            if AppNotificationDelegate.consumePendingRefillReminderOpen() {
                navigationRouter.navigate(.medications)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationDidChange)) { _ in
            notificationSyncTask?.cancel()
            notificationSyncTask = Task {
                await syncMedicationNotifications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationReminderOpened)) { _ in
            navigationRouter.navigate(.home)
        }
        .onReceive(NotificationCenter.default.publisher(for: .medicationRefillReminderOpened)) { _ in
            navigationRouter.navigate(.medications)
        }
        .onChange(of: subscriptionService.hasLoadedStatus) { _, loaded in
            guard loaded else { return }
            presentInitialSubscriptionPromptIfNeeded()
        }
        .onChange(of: subscriptionService.isPro) { _, isPro in
            guard !isPro else { return }
            presentInitialSubscriptionPromptIfNeeded()
        }
        .toast()
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
        await refillReminderService.syncRefillReminders(modelContext: modelContext)
    }

    @MainActor
    private func presentInitialSubscriptionPromptIfNeeded() {
        guard subscriptionService.hasLoadedStatus else { return }
        guard !subscriptionService.isPro else { return }
        guard !hasShownInitialSubscriptionPrompt else { return }
        hasShownInitialSubscriptionPrompt = true
        showingInitialSubscriptionPrompt = true
    }
}

// MARK: - Bottom accessory

private extension View {
    /// Shows the dose pill above the tab bar while there is something left to take.
    /// `isEnabled` needs iOS 26.1; on 26.0 the accessory is only attached while a dose is pending.
    @ViewBuilder
    func dosePillAccessory(_ state: DosePillState?) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: state != nil) {
                if let state {
                    DosePillView(state: state)
                }
            }
        } else if let state {
            tabViewBottomAccessory {
                DosePillView(state: state)
            }
        } else {
            self
        }
    }
}

#if DEBUG
#Preview {
    MainTabView()
        .modelContainer(PreviewData.container)
        .environment(NavigationRouter())
        .environment(SubscriptionService())
        .environment(ThemeManager())
}
#endif
