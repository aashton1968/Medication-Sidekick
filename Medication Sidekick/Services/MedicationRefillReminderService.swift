//
//  MedicationRefillReminderService.swift
//  Medication Sidekick
//

import Foundation
import SwiftData
import UserNotifications

/// Watches each active medication's stock level and fires a local notification when it
/// crosses into Running Low / Very Low / Out of Stock, so refills happen before doses are
/// missed. Unlike dose reminders (future calendar triggers), this is a state-based alert —
/// it tracks the last-notified severity per medication in UserDefaults so an unchanged
/// stock level doesn't re-notify on every sync pass. Restocking clears that state so a
/// future drop notifies again.
@MainActor
struct MedicationRefillReminderService {

    private static let requestPrefix = "medrefill."
    private static let testRequestPrefix = "medrefill.test."
    private static let notifiedLevelsKey = "medicationRefillNotifiedLevels"
    private let center = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard

    struct Preferences {
        let isEnabled: Bool
        let privacyModeEnabled: Bool
    }

    enum TestNotificationError: LocalizedError {
        case disabledInApp
        case deniedBySystem
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .disabledInApp:
                return "Refill reminders are off. Enable them first to send a test notification."
            case .deniedBySystem:
                return "Notifications are denied by iOS. Enable them in Settings."
            case .notAuthorized:
                return "Notification permission is not active yet."
            }
        }
    }

    func requestAuthorizationIfNeeded() async {
        guard preferences().isEnabled else { return }
        let settings = await notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = await requestAuthorization(options: [.alert, .badge, .sound])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        (await notificationSettings()).authorizationStatus
    }

    func preferences() -> Preferences {
        let isEnabled: Bool
        if userDefaults.object(forKey: AppStorageKeys.refillRemindersEnabled.rawValue) == nil {
            isEnabled = true
        } else {
            isEnabled = userDefaults.bool(forKey: AppStorageKeys.refillRemindersEnabled.rawValue)
        }
        let privacy = userDefaults.bool(forKey: AppStorageKeys.notificationPrivacyEnabled.rawValue)
        return Preferences(isEnabled: isEnabled, privacyModeEnabled: privacy)
    }

    /// Recomputes stock levels for every active medication and fires a reminder for any
    /// whose severity has newly increased since it was last notified.
    func syncRefillReminders(modelContext: ModelContext) async {
        let prefs = preferences()
        guard prefs.isEnabled else {
            await removeAllRefillNotifications()
            clearNotifiedLevels()
            return
        }

        let settings = await notificationSettings()
        guard isSchedulingAllowed(settings.authorizationStatus) else { return }

        let allMedications = (try? modelContext.fetch(FetchDescriptor<Medication>())) ?? []
        let plan = Self.medicationsNeedingReminder(
            medications: allMedications,
            previouslyNotifiedSeverities: loadNotifiedLevels()
        )

        let validIdentifiers = Set(
            allMedications.filter(\.isActive).map { notificationIdentifier(for: $0.id) }
        )
        await removeStaleRefillNotifications(keeping: validIdentifiers)

        for medication in plan.toNotify {
            let request = buildRequest(for: medication, privacyMode: prefs.privacyModeEnabled)
            try? await add(request)
        }

        saveNotifiedLevels(plan.updatedSeverities)
    }

    /// Pure decision of which medications currently need a (re-)fired refill reminder, given
    /// each medication's last-known severity. `updatedSeverities` always tracks the *current*
    /// severity (not just the severity that triggered a notification) — otherwise a partial
    /// improvement that doesn't fully restock (e.g. critical → warning) would permanently
    /// wedge the stored value at the old, higher severity and swallow a later re-escalation
    /// back to critical. Inactive medications and those back at a safe stock level are dropped
    /// from the returned state so a later reactivation or a future stock drop notifies fresh.
    /// Kept `nonisolated` and free of any UNUserNotificationCenter/UserDefaults access so it
    /// can be unit tested directly.
    static nonisolated func medicationsNeedingReminder(
        medications: [Medication],
        previouslyNotifiedSeverities: [String: Int]
    ) -> (toNotify: [Medication], updatedSeverities: [String: Int]) {
        let activeMedications = medications.filter(\.isActive)
        let activeKeys = Set(activeMedications.map { $0.id.uuidString.lowercased() })
        var updatedSeverities = previouslyNotifiedSeverities.filter { activeKeys.contains($0.key) }
        var toNotify: [Medication] = []

        for medication in activeMedications {
            let key = medication.id.uuidString.lowercased()
            let level = medication.stockLevel

            guard level.severity > 0 else {
                // Restocked (or never was low) — clear so a future drop notifies again.
                updatedSeverities.removeValue(forKey: key)
                continue
            }

            let previousSeverity = updatedSeverities[key] ?? 0
            if level.severity > previousSeverity {
                toNotify.append(medication)
            }
            updatedSeverities[key] = level.severity
        }

        return (toNotify, updatedSeverities)
    }

    /// The notification body for a medication currently needing a refill reminder. Pure and
    /// `nonisolated` so wording can be unit tested without a UNNotificationRequest.
    static nonisolated func reminderBody(for medication: Medication, privacyMode: Bool) -> String {
        let level = medication.stockLevel
        let subject = privacyMode ? "A medication" : doseText(for: medication)
        guard level != .empty else {
            return "\(subject) is out of stock. Time to refill."
        }
        return "\(subject) is \(level.displayName.lowercased()) — ~\(medication.daysOfSupply) days supply."
    }

    func sendTestNotification() async throws {
        guard preferences().isEnabled else {
            throw TestNotificationError.disabledInApp
        }

        var status = await authorizationStatus()
        if status == .notDetermined {
            _ = await requestAuthorization(options: [.alert, .badge, .sound])
            status = await authorizationStatus()
        }

        if status == .denied {
            throw TestNotificationError.deniedBySystem
        }

        guard isSchedulingAllowed(status) else {
            throw TestNotificationError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = "Refill Reminder"
        content.body = "This is a test refill reminder. Your notification settings are working."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Self.testRequestPrefix)\(UUID().uuidString.lowercased())",
            content: content,
            trigger: trigger
        )

        try await add(request)
    }

    func removeAllRefillNotifications() async {
        let pending = await pendingNotificationRequests()
        let pendingIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        let delivered = await deliveredNotifications()
        let deliveredIDs = delivered
            .map(\.request.identifier)
            .filter { $0.hasPrefix(Self.requestPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }

    /// Removes refill notifications left over from medications that were deleted, made
    /// inactive, or have since restocked — keeping test pings untouched so they aren't
    /// cancelled mid-flight by an unrelated sync pass.
    private func removeStaleRefillNotifications(keeping validIdentifiers: Set<String>) async {
        let pending = await pendingNotificationRequests()
        let stalePendingIDs = pending
            .map(\.identifier)
            .filter {
                $0.hasPrefix(Self.requestPrefix) &&
                !$0.hasPrefix(Self.testRequestPrefix) &&
                !validIdentifiers.contains($0)
            }
        center.removePendingNotificationRequests(withIdentifiers: stalePendingIDs)

        let delivered = await deliveredNotifications()
        let staleDeliveredIDs = delivered
            .map(\.request.identifier)
            .filter {
                $0.hasPrefix(Self.requestPrefix) &&
                !$0.hasPrefix(Self.testRequestPrefix) &&
                !validIdentifiers.contains($0)
            }
        center.removeDeliveredNotifications(withIdentifiers: staleDeliveredIDs)
    }

    private func isSchedulingAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func buildRequest(
        for medication: Medication,
        privacyMode: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Refill Reminder"
        content.body = Self.reminderBody(for: medication, privacyMode: privacyMode)
        content.sound = .default

        // `trigger: nil` delivers as soon as possible — this is a "your stock is low right
        // now" state alert, not tied to a future scheduled time like dose reminders are.
        return UNNotificationRequest(
            identifier: notificationIdentifier(for: medication.id),
            content: content,
            trigger: nil
        )
    }

    private static nonisolated func doseText(for medication: Medication) -> String {
        medication.dosage.isEmpty ? medication.name : "\(medication.name) (\(medication.dosage))"
    }

    private func notificationIdentifier(for medicationID: UUID) -> String {
        "\(Self.requestPrefix)\(medicationID.uuidString.lowercased())"
    }

    private func loadNotifiedLevels() -> [String: Int] {
        (userDefaults.dictionary(forKey: Self.notifiedLevelsKey) as? [String: Int]) ?? [:]
    }

    private func saveNotifiedLevels(_ levels: [String: Int]) {
        userDefaults.set(levels, forKey: Self.notifiedLevelsKey)
    }

    private func clearNotifiedLevels() {
        userDefaults.removeObject(forKey: Self.notifiedLevelsKey)
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    private func requestAuthorization(options: UNAuthorizationOptions) async -> Bool {
        (try? await center.requestAuthorization(options: options)) ?? false
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await center.notificationSettings()
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await center.deliveredNotifications()
    }
}
