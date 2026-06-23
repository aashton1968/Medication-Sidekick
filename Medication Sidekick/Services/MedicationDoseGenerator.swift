//
//  MedicationDoseGenerator.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-01.
//

import Foundation
import SwiftData

@MainActor
struct MedicationDoseGenerator {

    /// Removes future scheduled doses whose meal key is no longer in the
    /// medication's schedule, then fills in any missing doses.
    /// Only makes changes when the data doesn't match the current schedule,
    /// so repeated calls with unchanged data produce no writes.
    /// Does NOT save — the caller is responsible for saving.
    static func refreshDoses(
        for medication: Medication,
        modelContext: ModelContext
    ) throws {

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let currentMealKeys = Set(medication.mealsRaw)

        let allDoses = try modelContext.fetch(FetchDescriptor<MedicationDose>())

        let dosesFromToday = allDoses.filter { dose in
            dose.medication == medication &&
            dose.scheduledDate >= startOfToday
        }

        var deletedIDs = Set<ObjectIdentifier>()

        for dose in dosesFromToday {
            let shouldRemove = !medication.isActive || !currentMealKeys.contains(dose.mealTimeRaw)
            // Keep taken doses as historical records, but reconcile all other statuses
            // so today's schedule reflects meal-slot edits immediately.
            if shouldRemove && dose.status != .taken {
                modelContext.delete(dose)
                deletedIDs.insert(ObjectIdentifier(dose))
            }
        }

        let remainingDoses = allDoses.filter { !deletedIDs.contains(ObjectIdentifier($0)) }

        if medication.isActive && !medication.mealsRaw.isEmpty {
            try generateUpcomingDoses(
                for: medication,
                existingDoses: remainingDoses,
                modelContext: modelContext
            )
        }
    }

    /// Refreshes doses for all medications, saving only if changes were made.
    static func refreshAllDoses(modelContext: ModelContext) throws {
        let medications = try modelContext.fetch(FetchDescriptor<Medication>())
        for medication in medications {
            try refreshDoses(for: medication, modelContext: modelContext)
        }
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    /// Returns true if a dose should be generated for `day` based on the medication's frequency.
    private static func isDoseScheduled(
        for medication: Medication,
        on day: Date,
        calendar: Calendar
    ) -> Bool {
        switch medication.frequency {
        case .daily, .asNeeded:
            return true
        case .everyOtherDay:
            let startDay = calendar.startOfDay(for: medication.startDate)
            let daysDiff = calendar.dateComponents([.day], from: startDay, to: day).day ?? 0
            return daysDiff % 2 == 0
        case .specificDays:
            let weekdays = medication.scheduledWeekdays
            guard !weekdays.isEmpty else { return true }
            let weekday = calendar.component(.weekday, from: day)
            return weekdays.contains(weekday)
        }
    }

    /// Generates scheduled doses for the next N days (default: 7).
    /// Does NOT save — the caller is responsible for saving.
    ///
    /// - Parameter existingDoses: Pre-filtered dose list to check for duplicates.
    ///   When called from `refreshDoses`, this excludes the just-deleted stale doses
    ///   so the duplicate check works correctly without an intermediate save.
    ///   When nil, doses are fetched fresh from the context.
    static func generateUpcomingDoses(
        for medication: Medication,
        existingDoses: [MedicationDose]? = nil,
        daysAhead: Int = 7,
        modelContext: ModelContext
    ) throws {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard !medication.mealsRaw.isEmpty else { return }

        var allDoses = try existingDoses ?? modelContext.fetch(FetchDescriptor<MedicationDose>())
        let settings = try modelContext.fetch(FetchDescriptor<MealTimeSetting>())
        let settingsByKey = Dictionary(settings.map { ($0.key, $0) }, uniquingKeysWith: { _, latest in latest })
        let uniqueMealKeys = Array(Set(medication.mealsRaw))

        for dayOffset in 0..<daysAhead {

            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: today
            ) else { continue }

            guard medication.isScheduleActive(on: day) else { continue }
            guard isDoseScheduled(for: medication, on: day, calendar: calendar) else { continue }

            for mealKey in uniqueMealKeys {

                let time: DateComponents
                if let setting = settingsByKey[mealKey] {
                    time = setting.defaultDateComponents
                } else if let enumCase = MealTime(rawValue: mealKey) {
                    time = enumCase.defaultDateComponents
                } else {
                    continue
                }

                var components = calendar.dateComponents(
                    [.year, .month, .day],
                    from: day
                )

                components.hour = time.hour
                components.minute = time.minute
                components.second = 0

                guard let scheduledDate = calendar.date(from: components) else {
                    continue
                }

                let alreadyExists = allDoses.contains {
                    $0.medication == medication &&
                    $0.mealTimeRaw == mealKey &&
                    calendar.isDate($0.scheduledDate, inSameDayAs: scheduledDate)
                }

                guard !alreadyExists else { continue }

                let dose = MedicationDose(
                    medication: medication,
                    mealKey: mealKey,
                    scheduledDate: scheduledDate
                )

                modelContext.insert(dose)
                allDoses.append(dose)
            }
        }
    }
}
