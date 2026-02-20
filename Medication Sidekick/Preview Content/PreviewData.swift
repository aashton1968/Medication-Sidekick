//
//  PreviewData.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

import Foundation
import SwiftData

@MainActor
struct PreviewData {

    /// Fresh in-memory container every time it is accessed
    static var container: ModelContainer {
        do {
            let schema = Schema([
                Medication.self,
                MedicationDose.self,
                MealTimeSetting.self
            ])

            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])

            seed(into: container.mainContext)

            return container
        } catch {
            fatalError("❌ Failed to create preview container: \(error)")
        }
    }

    // MARK: - Seed Data

    static func seed(into context: ModelContext) {

        // Seed meal time settings first
        let mealTimeDefaults: [(name: String, key: String, hour: Int, minute: Int, sortOrder: Int, symbol: String)] = [
            ("Pre-Breakfast", "preBreakfast", 6,  30, 0, "clock"),
            ("Breakfast",     "breakfast",    7,  0,  1, "sunrise"),
            ("Lunch",         "lunch",        12, 0,  2, "sun.max"),
            ("Dinner",        "dinner",       18, 30, 3, "sun.haze"),
            ("Supper",        "supper",       20, 0,  4, "moon.haze"),
            ("Bed Time",      "bedTime",      22, 30, 5, "moon.zzz"),
        ]

        var settingsByKey: [String: MealTimeSetting] = [:]
        for d in mealTimeDefaults {
            let setting = MealTimeSetting(
                name: d.name,
                key: d.key,
                hour: d.hour,
                minute: d.minute,
                sortOrder: d.sortOrder,
                symbolName: d.symbol
            )
            context.insert(setting)
            settingsByKey[d.key] = setting
        }

        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)

        let meds: [Medication] = [
            Medication(
                name: "Metformin",
                dosage: "500 mg",
                instructions: "Take with meals to reduce stomach upset",
                meals: [.breakfast, .dinner],
                startDate: startOfDay,
                medicationType: .tablet,
                currentStock: 56,
                stockUnit: .tablets
            ),
            Medication(
                name: "Vitamin D",
                dosage: "1,000 IU",
                instructions: "Once daily in the morning",
                meals: [.breakfast],
                startDate: startOfDay,
                medicationType: .supplement,
                currentStock: 90,
                stockUnit: .capsules
            ),
            Medication(
                name: "Atorvastatin",
                dosage: "20 mg",
                instructions: "Take at night",
                meals: [.breakfast],
                startDate: startOfDay,
                medicationType: .tablet,
                currentStock: 8,
                stockUnit: .tablets
            ),
            Medication(
                name: "Insulin (Basal)",
                dosage: "18 units",
                instructions: "Once daily before bed",
                meals: [.supper],
                startDate: startOfDay,
                medicationType: .injection,
                currentStock: 3,
                stockUnit: .units
            ),
            Medication(
                name: "Aspirin",
                dosage: "81 mg",
                instructions: "Low-dose cardiovascular protection",
                isActive: false,
                medicationType: .tablet,
                currentStock: 0,
                stockUnit: .tablets
            ),
            Medication(
                name: "Insulin (Bolus)",
                dosage: "26 units",
                instructions: "Once daily before bed",
                isActive: false,
                medicationType: .injection,
                currentStock: 0,
                stockUnit: .units
            )
        ]

        meds.forEach { context.insert($0) }

        // MARK: - Create Doses (Today)

        for medication in meds {
            guard medication.isActive else { continue }

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

                let dose = MedicationDose(
                    medication: medication,
                    mealKey: mealKey,
                    scheduledDate: scheduledDate
                )

                context.insert(dose)
            }
        }

        try? context.save()
    }
}
