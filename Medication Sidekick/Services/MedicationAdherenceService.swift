//
//  MedicationAdherenceService.swift
//  Medication Sidekick
//
//  Created by Cursor on 2026-02-23.
//

import Foundation
import SwiftData
import UserNotifications

struct AdherenceConfiguration {
    var missedGracePeriod: TimeInterval
    var skippedCountsAgainstAdherence: Bool

    nonisolated init(
        missedGracePeriod: TimeInterval = 2 * 60 * 60,
        skippedCountsAgainstAdherence: Bool = true
    ) {
        self.missedGracePeriod = missedGracePeriod
        self.skippedCountsAgainstAdherence = skippedCountsAgainstAdherence
    }
}

struct AdherenceSummary {
    let rangeStart: Date
    let rangeEnd: Date
    let dueCount: Int
    let takenCount: Int
    let missedCount: Int
    let skippedCount: Int
    let pendingCount: Int

    var remainingCount: Int {
        pendingCount + missedCount
    }

    var adherencePercent: Int {
        guard dueCount > 0 else { return 0 }
        let ratio = Double(takenCount) / Double(dueCount)
        let percent = round(ratio * 100)
        return percent.safeInt
    }
}

struct MedicationAdherenceSummary: Identifiable {
    let medicationID: UUID
    let medicationName: String
    let summary: AdherenceSummary

    var id: UUID { medicationID }
}

@MainActor
struct MedicationAdherenceService {

    let configuration: AdherenceConfiguration
    let calendar: Calendar

    nonisolated init(
        configuration: AdherenceConfiguration = AdherenceConfiguration(),
        calendar: Calendar = .current
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    func dailySummary(
        on day: Date = Date(),
        now: Date = Date(),
        modelContext: ModelContext
    ) throws -> AdherenceSummary {
        let range = dayRange(for: day)
        let doses = try doses(in: range, modelContext: modelContext)
        return summarize(doses: doses, in: range, now: now)
    }

    func rollingSummary(
        days: Int,
        endingAt now: Date = Date(),
        modelContext: ModelContext
    ) throws -> AdherenceSummary {
        let end = now
        let startOfEndDay = calendar.startOfDay(for: end)
        guard days > 0 else {
            return AdherenceSummary(
                rangeStart: startOfEndDay,
                rangeEnd: startOfEndDay,
                dueCount: 0,
                takenCount: 0,
                missedCount: 0,
                skippedCount: 0,
                pendingCount: 0
            )
        }
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfEndDay) else {
            return AdherenceSummary(
                rangeStart: end,
                rangeEnd: end,
                dueCount: 0,
                takenCount: 0,
                missedCount: 0,
                skippedCount: 0,
                pendingCount: 0
            )
        }

        let range = DateInterval(start: start, end: end)
        let doses = try doses(in: range, modelContext: modelContext)
        return summarize(doses: doses, in: range, now: now)
    }

    func perMedicationDailySummary(
        on day: Date = Date(),
        now: Date = Date(),
        modelContext: ModelContext
    ) throws -> [MedicationAdherenceSummary] {
        let range = dayRange(for: day)
        let doses = try doses(in: range, modelContext: modelContext)
        let grouped = Dictionary(grouping: doses) { $0.medication?.id }

        return grouped.compactMap { medicationID, medicationDoses in
            guard let medicationID,
                  let medicationName = medicationDoses.first?.medication?.name else {
                return nil
            }
            return MedicationAdherenceSummary(
                medicationID: medicationID,
                medicationName: medicationName,
                summary: summarize(doses: medicationDoses, in: range, now: now)
            )
        }
        .sorted { $0.medicationName.localizedCaseInsensitiveCompare($1.medicationName) == .orderedAscending }
    }

    /// Promotes stale scheduled doses to missed using the configured grace period.
    /// Returns number of doses updated.
    @discardableResult
    func syncMissedStatuses(
        now: Date = Date(),
        modelContext: ModelContext
    ) throws -> Int {
        let cutoff = now.addingTimeInterval(-configuration.missedGracePeriod)
        let scheduledRaw = "scheduled"
        let descriptor = FetchDescriptor<MedicationDose>(
            predicate: #Predicate { dose in
                dose.statusRaw == scheduledRaw && dose.scheduledDate <= cutoff
            }
        )
        let staleDoses = try modelContext.fetch(descriptor)

        for dose in staleDoses {
            dose.status = .missed
            dose.updatedAt = now
        }

        if !staleDoses.isEmpty {
            try modelContext.save()
        }

        return staleDoses.count
    }

    func summarize(
        doses: [MedicationDose],
        in range: DateInterval,
        now: Date = Date()
    ) -> AdherenceSummary {
        let dueCutoff = min(now, range.end)
        let inRange = doses.filter { range.contains($0.scheduledDate) }
        let dueDoses = inRange.filter { $0.scheduledDate <= dueCutoff }
        let pending = dueDoses.filter { effectiveStatus(for: $0, now: now) == .scheduled }.count
        let taken = dueDoses.filter { effectiveStatus(for: $0, now: now) == .taken }.count
        let missed = dueDoses.filter { effectiveStatus(for: $0, now: now) == .missed }.count
        let skipped = dueDoses.filter { effectiveStatus(for: $0, now: now) == .skipped }.count
        let due = taken + missed + (configuration.skippedCountsAgainstAdherence ? skipped : 0)

        return AdherenceSummary(
            rangeStart: range.start,
            rangeEnd: range.end,
            dueCount: due,
            takenCount: taken,
            missedCount: missed,
            skippedCount: skipped,
            pendingCount: pending
        )
    }

    private func dayRange(for day: Date) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func doses(in range: DateInterval, modelContext: ModelContext) throws -> [MedicationDose] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<MedicationDose>(
            predicate: #Predicate { dose in
                dose.scheduledDate >= start && dose.scheduledDate < end
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func effectiveStatus(for dose: MedicationDose, now: Date) -> DoseStatus {
        if dose.status != .scheduled {
            return dose.status
        }

        let overdueCutoff = dose.scheduledDate.addingTimeInterval(configuration.missedGracePeriod)
        if now >= overdueCutoff {
            return .missed
        }

        return .scheduled
    }
}

@MainActor
struct MedicationNotificationService {

    private static let requestPrefix = "meddose."
    private static let testRequestPrefix = "meddose.test."
    private static let supportedLeadTimes = [0, 5, 10, 15, 30, 60]
    private let center = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard

    struct Preferences {
        let isEnabled: Bool
        let leadTimeMinutes: Int
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
        return Preferences(isEnabled: isEnabled, leadTimeMinutes: leadTime)
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
        let limitedGroups = Array(groups.prefix(64))

        await removeAllMedicationNotifications()

        for group in limitedGroups {
            let request = buildRequest(
                for: group,
                leadTimeMinutes: prefs.leadTimeMinutes
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
        leadTimeMinutes: Int
    ) -> UNNotificationRequest {
        let title = "Medication Reminder"
        let medicationList = formattedMedicationList(group.medicationTexts)

        let content = UNMutableNotificationContent()
        content.title = title
        if leadTimeMinutes > 0 {
            content.body = "Upcoming in \(leadTimeMinutes) min for \(group.mealLabel): \(medicationList)."
        } else {
            content.body = "Time for \(group.mealLabel): \(medicationList)."
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func requestAuthorization(options: UNAuthorizationOptions) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            center.requestAuthorization(options: options) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { (continuation: CheckedContinuation<UNNotificationSettings, Never>) in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[UNNotificationRequest], Never>) in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[UNNotification], Never>) in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }
}
