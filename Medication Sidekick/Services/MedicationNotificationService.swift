//
//  MedicationNotificationService.swift
//  Medication Sidekick
//

import Foundation
import SwiftData
import UserNotifications
import os.log

@MainActor
struct MedicationNotificationService {

    private static let requestPrefix = "meddose."
    private static let testRequestPrefix = "meddose.test."
    private static let supportedLeadTimes = [0, 5, 10, 15, 30, 60]
    private let center = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard

    private static let maximumScheduledNotifications = 64

    struct Preferences {
        let isEnabled: Bool
        let leadTimeMinutes: Int
        let privacyModeEnabled: Bool
    }

    private struct MealNotificationGroup {
        let mealKey: String
        let mealLabel: String
        let scheduledDate: Date
        let medicationTexts: [String]
    }

    enum TestNotificationError: LocalizedError {
        case disabledInApp
        case deniedBySystem
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .disabledInApp:
                return "Medication reminders are off. Enable them first to send a test notification."
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
        if userDefaults.object(forKey: AppStorageKeys.medicationNotificationsEnabled.rawValue) == nil {
            isEnabled = true
        } else {
            isEnabled = userDefaults.bool(forKey: AppStorageKeys.medicationNotificationsEnabled.rawValue)
        }

        let rawLeadTime = userDefaults.integer(forKey: AppStorageKeys.medicationReminderLeadTimeMinutes.rawValue)
        let leadTime = Self.supportedLeadTimes.contains(rawLeadTime) ? rawLeadTime : 0
        let privacy = userDefaults.bool(forKey: AppStorageKeys.notificationPrivacyEnabled.rawValue)
        return Preferences(isEnabled: isEnabled, leadTimeMinutes: leadTime, privacyModeEnabled: privacy)
    }

    func syncScheduledDoseNotifications(
        modelContext: ModelContext,
        now: Date = Date()
    ) async {
        let prefs = preferences()
        guard prefs.isEnabled else {
            await removeAllMedicationNotifications()
            return
        }

        let settings = await notificationSettings()
        guard isSchedulingAllowed(settings.authorizationStatus) else {
            await removeAllMedicationNotifications()
            return
        }

        let doses = fetchNotifiableDoses(
            modelContext: modelContext,
            now: now,
            leadTimeMinutes: prefs.leadTimeMinutes
        )
        let settingsByKey = fetchMealSettingsByKey(modelContext: modelContext)
        let groups = buildNotificationGroups(
            doses: doses,
            mealSettingsByKey: settingsByKey
        )
        // Sort near-term reminders first so early-week doses are kept if the
        // 64-slot system cap is hit, rather than arbitrarily dropping later-day ones.
        let limitedGroups = Array(groups.sorted { $0.scheduledDate < $1.scheduledDate }.prefix(Self.maximumScheduledNotifications))

        await removeAllMedicationNotifications()

        for group in limitedGroups {
            let request = buildRequest(
                for: group,
                leadTimeMinutes: prefs.leadTimeMinutes,
                privacyMode: prefs.privacyModeEnabled
            )
            try? await add(request)
        }
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
        content.title = "Medication Sidekick"
        content.body = "This is a test reminder. Your notification settings are working."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Self.testRequestPrefix)\(UUID().uuidString.lowercased())",
            content: content,
            trigger: trigger
        )

        try await add(request)
    }

    func removeNotifications(for medicationID: UUID) async {
        let medicationKey = medicationID.uuidString.lowercased()
        let pending = await pendingNotificationRequests()
        let matchingPendingIDs = pending
            .map(\.identifier)
            .filter { $0.contains(medicationKey) }
        center.removePendingNotificationRequests(withIdentifiers: matchingPendingIDs)

        let delivered = await deliveredNotifications()
        let matchingDeliveredIDs = delivered
            .map(\.request.identifier)
            .filter { $0.contains(medicationKey) }
        center.removeDeliveredNotifications(withIdentifiers: matchingDeliveredIDs)
    }

    func removeAllMedicationNotifications() async {
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

    private func isSchedulingAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func fetchNotifiableDoses(
        modelContext: ModelContext,
        now: Date,
        leadTimeMinutes: Int
    ) -> [MedicationDose] {
        let leadSeconds = TimeInterval(max(0, leadTimeMinutes) * 60)
        let allDoses = (try? modelContext.fetch(FetchDescriptor<MedicationDose>())) ?? []
        return allDoses
            .filter {
                $0.status == .scheduled &&
                $0.scheduledDate.addingTimeInterval(-leadSeconds) > now &&
                $0.medication?.isActive == true
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private func fetchMealSettingsByKey(modelContext: ModelContext) -> [String: MealTimeSetting] {
        let settings = (try? modelContext.fetch(FetchDescriptor<MealTimeSetting>())) ?? []
        return Dictionary(settings.map { ($0.key, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private func buildNotificationGroups(
        doses: [MedicationDose],
        mealSettingsByKey: [String: MealTimeSetting]
    ) -> [MealNotificationGroup] {
        let grouped = Dictionary(grouping: doses) { dose in
            GroupKey(mealTimeRaw: dose.mealTimeRaw, scheduledDate: dose.scheduledDate)
        }

        return grouped
            .compactMap { key, groupedDoses in
                let meds = groupedDoses
                    .compactMap { doseText(for: $0.medication) }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                guard meds.isEmpty == false else { return nil }

                let mealLabel = mealSettingsByKey[key.mealTimeRaw]?.name
                    ?? MealTime(rawValue: key.mealTimeRaw)?.displayName
                    ?? key.mealTimeRaw

                return MealNotificationGroup(
                    mealKey: key.mealTimeRaw,
                    mealLabel: mealLabel,
                    scheduledDate: key.scheduledDate,
                    medicationTexts: meds
                )
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private func doseText(for medication: Medication?) -> String? {
        guard let medication else { return nil }
        return medication.dosage.isEmpty ? medication.name : "\(medication.name) (\(medication.dosage))"
    }

    private struct GroupKey: Hashable {
        let mealTimeRaw: String
        let scheduledDate: Date
    }

    private func buildRequest(
        for group: MealNotificationGroup,
        leadTimeMinutes: Int,
        privacyMode: Bool = false
    ) -> UNNotificationRequest {
        let title = "Medication Reminder"
        let content = UNMutableNotificationContent()
        content.title = title
        if privacyMode {
            let count = group.medicationTexts.count
            let noun = count == 1 ? "medication" : "medications"
            if leadTimeMinutes > 0 {
                content.body = "Upcoming in \(leadTimeMinutes) min for \(group.mealLabel): \(count) \(noun)."
            } else {
                content.body = "Time for \(group.mealLabel): \(count) \(noun)."
            }
        } else {
            let medicationList = formattedMedicationList(group.medicationTexts)
            if leadTimeMinutes > 0 {
                content.body = "Upcoming in \(leadTimeMinutes) min for \(group.mealLabel): \(medicationList)."
            } else {
                content.body = "Time for \(group.mealLabel): \(medicationList)."
            }
        }
        content.sound = .default

        let fireDate = group.scheduledDate.addingTimeInterval(TimeInterval(-leadTimeMinutes * 60))

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: notificationIdentifier(for: group),
            content: content,
            trigger: trigger
        )
    }

    private func formattedMedicationList(_ meds: [String], maxVisible: Int = 4) -> String {
        guard meds.count > maxVisible else {
            return meds.joined(separator: ", ")
        }

        let visible = meds.prefix(maxVisible).joined(separator: ", ")
        let remaining = meds.count - maxVisible
        return "\(visible), +\(remaining) more"
    }

    private func notificationIdentifier(for group: MealNotificationGroup) -> String {
        let mealKey = group.mealKey.lowercased()
        let timestamp = group.scheduledDate.timeIntervalSince1970.safeInt
        return "\(Self.requestPrefix)\(mealKey).\(timestamp)"
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
