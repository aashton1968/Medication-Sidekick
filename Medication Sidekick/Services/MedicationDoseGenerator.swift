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

    /// Generates scheduled doses for the next N days (default: 7)
    static func generateUpcomingDoses(
        for medication: Medication,
        daysAhead: Int = 7,
        modelContext: ModelContext
    ) throws {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard !medication.mealsRaw.isEmpty else { return }

        let allDoses = try modelContext.fetch(FetchDescriptor<MedicationDose>())
        let settings = try modelContext.fetch(FetchDescriptor<MealTimeSetting>())
        let settingsByKey = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0) })

        for dayOffset in 0..<daysAhead {

            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: today
            ) else { continue }

            guard medication.isScheduleActive(on: day) else { continue }

            for mealKey in medication.mealsRaw {

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
            }
        }

        try modelContext.save()
    }
}
