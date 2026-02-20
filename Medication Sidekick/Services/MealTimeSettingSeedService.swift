//
//  MealTimeSettingSeedService.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-18.
//

import Foundation
import SwiftData

actor MealTimeSettingSeedService {

    func seedIfNeeded(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            let existing = try context.fetch(FetchDescriptor<MealTimeSetting>())

            if !existing.isEmpty {
                return
            }

            let defaults: [(name: String, key: String, hour: Int, minute: Int, sortOrder: Int, symbol: String)] = [
                ("Pre-Breakfast", "preBreakfast", 6,  30, 0, "clock"),
                ("Breakfast",     "breakfast",    7,  0,  1, "sunrise"),
                ("Lunch",         "lunch",        12, 0,  2, "sun.max"),
                ("Dinner",        "dinner",       18, 30, 3, "sun.haze"),
                ("Supper",        "supper",       20, 0,  4, "moon.haze"),
                ("Bed Time",      "bedTime",      22, 30, 5, "moon.zzz"),
            ]

            for d in defaults {
                let setting = MealTimeSetting(
                    name: d.name,
                    key: d.key,
                    hour: d.hour,
                    minute: d.minute,
                    sortOrder: d.sortOrder,
                    symbolName: d.symbol
                )
                context.insert(setting)
            }

            try context.save()

        } catch {
            print("Failed to seed meal time settings: \(error)")
        }
    }
}
