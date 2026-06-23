//
//  MealTimeSettingSeedService.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-18.
//

import Foundation
import os.log
import SwiftData

final class MealTimeSettingSeedService {
    static let shared = MealTimeSettingSeedService()
    nonisolated(unsafe) private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick", category: "MealTimeSeed")
    private init() {}

    nonisolated func seedIfNeeded(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            var existing = try context.fetch(FetchDescriptor<MealTimeSetting>())
            var hasChanges = false

            // Remove accidental duplicates for the same stable key.
            let groupedByKey = Dictionary(grouping: existing, by: \.key)
            for group in groupedByKey.values where group.count > 1 {
                let sorted = group.sorted {
                    if $0.sortOrder == $1.sortOrder {
                        return $0.id.uuidString < $1.id.uuidString
                    }
                    return $0.sortOrder < $1.sortOrder
                }
                for duplicate in sorted.dropFirst() {
                    context.delete(duplicate)
                    hasChanges = true
                }
            }

            if hasChanges {
                try context.save()
                existing = try context.fetch(FetchDescriptor<MealTimeSetting>())
            }

            let existingKeys = Set(existing.map(\.key))
            for d in defaults where !existingKeys.contains(d.key) {
                let setting = MealTimeSetting(
                    name: d.name,
                    key: d.key,
                    hour: d.hour,
                    minute: d.minute,
                    sortOrder: d.sortOrder,
                    symbolName: d.symbol
                )
                context.insert(setting)
                hasChanges = true
            }

            if hasChanges {
                try context.save()
            }

        } catch {
            Self.logger.error("Failed to seed meal time settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated var defaults: [(name: String, key: String, hour: Int, minute: Int, sortOrder: Int, symbol: String)] {
        [
            ("Pre-Breakfast", "preBreakfast", 6,  30, 0, "clock"),
            ("Breakfast",     "breakfast",    7,  0,  1, "sunrise"),
            ("Lunch",         "lunch",        12, 0,  2, "sun.max"),
            ("Dinner",        "dinner",       18, 30, 3, "sun.haze"),
            ("Supper",        "supper",       20, 0,  4, "moon.haze"),
            ("Bed Time",      "bedTime",      22, 30, 5, "moon.zzz"),
        ]
    }
}
