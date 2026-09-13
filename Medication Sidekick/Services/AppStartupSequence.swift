//
//  AppStartupSequence.swift
//  Medication Sidekick
//
//  Runs seeding and today's dose generation on the main `ModelContext` before other
//  startup work, and schedules delayed duplicate reconciliation so it does not race
//  initial UI-driven saves.
//

import Foundation
import os.log
import SwiftData

enum AppStartupSequence {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick", category: "AppInit")
    @MainActor private static var didCompletePhase1 = false
    @MainActor private static var reconcileTask: Task<Void, Never>?

    /// Seeds the store, generates today’s dose rows on `mainContext`, then schedules delayed reconcile passes.
    /// Call once from `HomeView`’s `.task` before generating doses or syncing notifications that touch the store.
    @MainActor
    static func runPhase1IfNeeded(
        subscriptionService: SubscriptionService,
        container: ModelContainer,
        mainContext: ModelContext
    ) async {
        guard !didCompletePhase1 else { return }
        didCompletePhase1 = true

        await subscriptionService.start()

        #if DEBUG
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection.bundle")?.load()
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
        #endif

        await MealTimeSettingSeedService.shared.seedIfNeeded(container: container)
        await MedicationSeedService.shared.seedIfNeeded(container: container)
        do {
            try MedicationDoseGenerator.refreshAllDoses(modelContext: mainContext)
        } catch {
            logger.error("Initial dose generation failed: \(error.localizedDescription, privacy: .public)")
        }

        await retimeDosesForTimeZoneChangeIfNeeded(modelContext: mainContext)

        scheduleDelayedReconcile(container: container)
    }

    /// Corrects any scheduled doses whose stored clock time no longer matches their meal
    /// setting — the situation that arises after the device's timezone changes (e.g. arriving
    /// in a new country) while doses for the next few days were already generated in the old
    /// timezone. Safe to call repeatedly; it's a no-op when nothing is stale.
    @MainActor
    static func retimeDosesForTimeZoneChangeIfNeeded(modelContext: ModelContext) async {
        do {
            let didChange = try MedicationDoseGenerator.retimeStaleDoses(modelContext: modelContext)
            guard didChange else { return }
            try modelContext.save()
            NotificationCenter.default.post(name: .medicationDidChange, object: nil)
            ToastManager.shared.showGeneral("Medication times updated for \(TimeZone.current.identifier)")
        } catch {
            logger.error("Failed to retime doses for timezone change: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func scheduleDelayedReconcile(container: ModelContainer) {
        reconcileTask = Task { @MainActor in
            let reconcileOffsets: [Double] = [8, 20, 45]
            var previousOffset: Double = 0
            for offset in reconcileOffsets {
                let stepDelay = max(0, offset - previousOffset)
                previousOffset = offset
                do { try await Task.sleep(for: .seconds(stepDelay)) } catch { return }
                if InteractionGuard.shouldDeferBackgroundReconcile() {
                    logger.notice("Skipping reconcile pass due to recent dose interaction")
                    continue
                }
                await MedicationSeedService.shared.reconcileSeedDuplicates(container: container)
                await MedicationSeedService.shared.reconcileCloudMedicationDuplicates(container: container)
                await MedicationSeedService.shared.reconcileCloudDoseDuplicates(container: container)
            }
        }
    }
}
