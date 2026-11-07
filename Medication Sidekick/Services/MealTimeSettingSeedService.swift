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
    nonisolated private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick", category: "MealTimeSeed")
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

            // Rename the original defaults in place (keys stay the same, so medications, doses and
            // history are untouched). Only names still at their old default are renamed, so a name
            // the user chose is left alone.
            for setting in existing {
                if let legacyName = legacyNames[setting.key],
                   setting.name == legacyName,
                   let newName = defaults.first(where: { $0.key == setting.key })?.name {
                    setting.name = newName
                    hasChanges = true
                }
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

    /// What a fresh install gets. The keys of the first four are the original meal keys
    /// ("breakfast" etc.) so older data keeps working; only the names changed.
    /// Existing installs keep any Pre-Breakfast / Supper they already have.
    private nonisolated var defaults: [(name: String, key: String, hour: Int, minute: Int, sortOrder: Int, symbol: String)] {
        [
            ("Morning",   "breakfast", 7,  0,  1, "sunrise"),
            ("Noon",      "lunch",     12, 0,  2, "sun.max"),
            ("Evening",   "dinner",    18, 30, 3, "sun.haze"),
            ("Night",     "bedTime",   22, 30, 5, "moon.zzz"),
            ("As Needed", "asNeeded",  12, 0,  6, "pills"),
        ]
    }

    /// The previous default names, by key, used to decide whether a name is safe to rename.
    private nonisolated var legacyNames: [String: String] {
        ["breakfast": "Breakfast", "lunch": "Lunch", "dinner": "Dinner", "bedTime": "Bed Time"]
    }
}
