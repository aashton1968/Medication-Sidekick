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
