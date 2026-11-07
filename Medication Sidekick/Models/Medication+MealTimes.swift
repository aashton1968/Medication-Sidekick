//
//  Medication+MealTimes.swift
//  Medication Sidekick
//
//  Per-medication reminder times for each linked meal.
//
//  A meal with no override follows the meal's own time (Meal Times settings), so changing
//  "Dinner" to 7pm moves every medication linked to it. An override pins that one
//  medication's dose for that meal to its own clock time instead.
//

import Foundation

extension Medication {

    /// Overrides keyed by meal key. Stored in `mealTimeOverridesRaw` as `"breakfast=08:30"`
    /// strings, because SwiftData/CloudKit stores plain `[String]` happily and a new
    /// defaulted field is an additive schema change.
    var timeOverrides: [String: DateComponents] {
        get {
            var result: [String: DateComponents] = [:]
            for entry in mealTimeOverridesRaw {
                let pair = entry.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { continue }
                let parts = pair[1].split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { continue }
                result[pair[0]] = DateComponents(hour: parts[0], minute: parts[1])
            }
            return result
        }
        set {
            mealTimeOverridesRaw = newValue
                .sorted { $0.key < $1.key }
                .compactMap { key, time in
                    guard let hour = time.hour, let minute = time.minute else { return nil }
                    return String(format: "%@=%02d:%02d", key, hour, minute)
                }
        }
    }

    func timeOverride(for mealKey: String) -> DateComponents? {
        timeOverrides[mealKey]
    }

    /// The clock time this medication's dose for `mealKey` is due:
    /// its own override if it has one, otherwise the meal's setting, otherwise the built-in default.
    func resolvedTime(for mealKey: String, settingsByKey: [String: MealTimeSetting]) -> DateComponents? {
        if let override = timeOverride(for: mealKey) { return override }
        if let setting = settingsByKey[mealKey] { return setting.defaultDateComponents }
        return MealTime(rawValue: mealKey)?.defaultDateComponents
    }

    /// "Breakfast 8:30 AM" style entries in time order, for the detail screen.
    func reminderSummary(settings: [MealTimeSetting]) -> [String] {
        let settingsByKey = Dictionary(settings.map { ($0.key, $0) }, uniquingKeysWith: { _, latest in latest })
        let calendar = Calendar.current

        return mealsRaw.compactMap { key -> (minutes: Int, text: String)? in
            guard let time = resolvedTime(for: key, settingsByKey: settingsByKey) else { return nil }
            let name = settingsByKey[key]?.name ?? MealTime(rawValue: key)?.displayName ?? key
            let timeText = calendar.date(from: time)?.formatted(date: .omitted, time: .shortened) ?? ""
            return ((time.hour ?? 0) * 60 + (time.minute ?? 0), "\(name) \(timeText)")
        }
        .sorted { $0.minutes < $1.minutes }
        .map(\.text)
    }
}
