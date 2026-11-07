//
//  DoseGrouping.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

import SwiftUI
import SwiftData
import os.log

func preferredDose(_ lhs: MedicationDose, _ rhs: MedicationDose) -> MedicationDose {
    DoseRankingPolicy.preferred(lhs, rhs)
}

func normalizedMedicationToken(_ value: String?) -> String {
    (value ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

func canonicalDoseKey(for dose: MedicationDose) -> String {
    let medicationName = normalizedMedicationToken(dose.medication?.name)
    let dosage = normalizedMedicationToken(dose.medication?.dosage)
        .replacingOccurrences(of: " ", with: "")
    let mealKey = normalizedMedicationToken(dose.mealTimeRaw)
    let scheduled = dose.scheduledDate.timeIntervalSince1970.safeInt
    return "\(medicationName)|\(dosage)|\(mealKey)|\(scheduled)"
}

func deduplicatedDoses(_ doses: [MedicationDose]) -> [MedicationDose] {
    var winnersByKey: [String: MedicationDose] = [:]
    for dose in doses {
        let key = canonicalDoseKey(for: dose)
        if let existing = winnersByKey[key] {
            winnersByKey[key] = preferredDose(existing, dose)
        } else {
            winnersByKey[key] = dose
        }
    }
    return Array(winnersByKey.values).sorted(by: medicationDoseSortsBefore)
}

func medicationDoseSortsBefore(_ lhs: MedicationDose, _ rhs: MedicationDose) -> Bool {
    let lhsName = lhs.medication?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let rhsName = rhs.medication?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let byName = lhsName.localizedCaseInsensitiveCompare(rhsName)
    if byName != .orderedSame {
        return byName == .orderedAscending
    }
    if lhs.scheduledDate != rhs.scheduledDate {
        return lhs.scheduledDate < rhs.scheduledDate
    }
    let lhsID = lhs.medication?.id.uuidString ?? ""
    let rhsID = rhs.medication?.id.uuidString ?? ""
    if lhsID != rhsID {
        return lhsID < rhsID
    }
    if lhs.mealTimeRaw != rhs.mealTimeRaw {
        return lhs.mealTimeRaw < rhs.mealTimeRaw
    }
    if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt < rhs.createdAt
    }
    if lhs.updatedAt != rhs.updatedAt {
        return lhs.updatedAt < rhs.updatedAt
    }
    return false
}

// MARK: - Slot Grouping

/// Fetches, deduplicates, and filters active-medication doses for a single calendar day.
func fetchDayDoses(for date: Date, calendar: Calendar, context: ModelContext) -> [MedicationDose] {
    let start = calendar.startOfDay(for: date)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
    do {
        let descriptor = FetchDescriptor<MedicationDose>(
            predicate: #Predicate { $0.scheduledDate >= start && $0.scheduledDate < end }
        )
        let fetched = try context.fetch(descriptor)
        return deduplicatedDoses(fetched.filter { $0.medication?.isActive == true })
    } catch {
        return []
    }
}

func makeSlotGroups(from doses: [MedicationDose], settings: [MealTimeSetting]) -> [TimeSlotGroup] {
    let grouped = Dictionary(grouping: doses) { $0.mealTimeRaw }
    return grouped.map { key, slotDoses in
        let setting = settings.first { $0.key == key }
        return TimeSlotGroup(
            key: key,
            name: setting?.name ?? (MealTime(rawValue: key)?.displayName ?? key),
            time: setting?.displayTime ?? "",
            symbol: setting?.symbolName ?? "fork.knife",
            sortOrder: setting?.sortOrder ?? 999,
            doses: slotDoses.sorted(by: medicationDoseSortsBefore)
        )
    }
    .sorted { $0.sortOrder < $1.sortOrder }
}

struct TimeSlotGroup: Identifiable {
    let key: String
    let name: String
    let time: String
    let symbol: String
    let sortOrder: Int
    let doses: [MedicationDose]

    var id: String { key }

    var isComplete: Bool {
        doses.allSatisfy { $0.status != .scheduled }
    }
}

