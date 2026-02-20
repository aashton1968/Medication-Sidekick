//
//  MedicationBootstrap.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import SwiftData
import Foundation

struct MedicationBootstrap {

    @MainActor
    static func generateTodayEvents(context: ModelContext) throws {

        let medications = try context.fetch(FetchDescriptor<Medication>())
        let existingDoses = try context.fetch(FetchDescriptor<MedicationDose>())
        let settings = try context.fetch(FetchDescriptor<MealTimeSetting>())
        let settingsByKey = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0) })

        let calendar = Calendar.current
        let today = Date()

        for medication in medications {

            guard medication.isActive, medication.isScheduleActive(on: today) else { continue }

            for mealKey in medication.mealsRaw {

                let components: DateComponents
                if let setting = settingsByKey[mealKey] {
                    components = setting.defaultDateComponents
                } else if let enumCase = MealTime(rawValue: mealKey) {
                    components = enumCase.defaultDateComponents
                } else {
                    continue
                }

                guard let scheduledDate = calendar.date(
                    bySettingHour: components.hour ?? 0,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: today
                ) else { continue }

                let alreadyExists = existingDoses.contains {
                    $0.mealTimeRaw == mealKey &&
                    $0.medication == medication &&
                    Calendar.current.isDate($0.scheduledDate, inSameDayAs: scheduledDate)
                }

                if alreadyExists { continue }

                let dose = MedicationDose(
                    medication: medication,
                    mealKey: mealKey,
                    scheduledDate: scheduledDate
                )

                context.insert(dose)
            }
        }

        try context.save()
    }
}
