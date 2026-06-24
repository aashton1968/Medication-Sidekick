//
//  MedicationSeedService.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import Foundation
import SwiftData
import os.log

// This class has no stored instance state. Every method is `nonisolated` so
// the heavy SwiftData fetch-and-mutate work runs on the cooperative thread
// pool instead of the main actor, despite SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
final class MedicationSeedService {
    static let shared = MedicationSeedService()
    nonisolated(unsafe) private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick", category: "SeedService")
    private init() {}

    // MARK: - Public API
    nonisolated func reconcileSeedDuplicates(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            let existing = try context.fetch(FetchDescriptor<Medication>())
            let duplicates = duplicateSeedDefaults(in: existing)
            guard !duplicates.isEmpty else { return }

            for duplicate in duplicates {
                context.delete(duplicate)
            }
            try context.save()
            Self.logger.notice("Removed \(duplicates.count, privacy: .public) duplicate seeded medications")
        } catch {
            Self.logger.error("Failed to reconcile duplicate medications: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated func reconcileCloudMedicationDuplicates(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            let medications = try context.fetch(FetchDescriptor<Medication>())
            var hasChanges = false

            var grouped = Dictionary(grouping: medications, by: { logicalIdentitySignature(for: $0) })
            for group in grouped.values where group.count > 1 {
                let doses: [MedicationDose]
                do {
                    doses = try context.fetch(FetchDescriptor<MedicationDose>())
                } catch {
                    Self.logger.error("Failed to refetch doses during medication reconcile: \(error.localizedDescription, privacy: .public)")
                    continue
                }
                guard let keeper = selectKeeper(from: group, doses: doses) else { continue }
                let duplicates = group.filter { $0.id != keeper.id }

                var keeperDoses = doses.filter { $0.medication?.id == keeper.id }
                var keeperDoseByKey: [String: MedicationDose] = [:]
                for dose in keeperDoses {
                    let key = doseKey(for: dose)
                    if let existing = keeperDoseByKey[key] {
                        mergeDose(existing, with: dose)
                        context.delete(dose)
                        hasChanges = true
                    } else {
                        keeperDoseByKey[key] = dose
                    }
                }

                for duplicate in duplicates {
                    let duplicateDoses = doses.filter { $0.medication?.id == duplicate.id }

                    for dose in duplicateDoses {
                        let key = doseKey(for: dose)
                        if let existingKeeperDose = keeperDoseByKey[key] {
                            mergeDose(existingKeeperDose, with: dose)
                            context.delete(dose)
                        } else {
                            dose.medication = keeper
                            keeperDoses.append(dose)
                            keeperDoseByKey[key] = dose
                        }
                        hasChanges = true
                    }

                    mergeMedication(keeper, with: duplicate)
                    context.delete(duplicate)
                    hasChanges = true
                }
            }

            if hasChanges {
                try context.save()
            }

            let medicationsAfterFirstPass = try context.fetch(FetchDescriptor<Medication>())
            let dosesAfterFirstPass = try context.fetch(FetchDescriptor<MedicationDose>())
            grouped = Dictionary(grouping: medicationsAfterFirstPass, by: { relaxedIdentitySignature(for: $0) })
            for group in grouped.values where group.count > 1 {
                guard let keeper = selectKeeper(from: group, doses: dosesAfterFirstPass) else { continue }
                let duplicates = group.filter { $0.id != keeper.id }
                for duplicate in duplicates {
                    mergeMedication(keeper, with: duplicate)
                    let duplicateDoses = dosesAfterFirstPass.filter { $0.medication?.id == duplicate.id }
                    for dose in duplicateDoses {
                        dose.medication = keeper
                    }
                    context.delete(duplicate)
                    hasChanges = true
                }
            }

            if hasChanges {
                try context.save()
                Self.logger.notice("Reconciled CloudKit medication duplicates")
            }
        } catch {
            Self.logger.error("Failed to reconcile CloudKit medication duplicates: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated func reconcileCloudDoseDuplicates(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            let doses = try context.fetch(FetchDescriptor<MedicationDose>())
            var hasChanges = false
            var removedCount = 0

            let grouped = Dictionary(grouping: doses, by: { doseStorageKey(for: $0) })
            for group in grouped.values where group.count > 1 {
                guard let keeper = selectDoseKeeper(from: group) else { continue }
                for duplicate in group where ObjectIdentifier(duplicate) != ObjectIdentifier(keeper) {
                    mergeDose(keeper, with: duplicate)
                    context.delete(duplicate)
                    removedCount += 1
                    hasChanges = true
                }
            }

            if hasChanges {
                try context.save()
                Self.logger.notice("Reconciled duplicate dose rows (removed: \(removedCount, privacy: .public))")
            }
        } catch {
            Self.logger.error("Failed to reconcile duplicate dose rows: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated func seedIfNeeded(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            var existing = try context.fetch(FetchDescriptor<Medication>())
            var hasChanges = false

            let duplicateSeedMeds = duplicateSeedDefaults(in: existing)
            if !duplicateSeedMeds.isEmpty {
                for duplicate in duplicateSeedMeds {
                    context.delete(duplicate)
                    hasChanges = true
                }
                try context.save()
                existing = try context.fetch(FetchDescriptor<Medication>())
            }

            // Use relaxed identity (name+dosage+type) so that user-edited medications
            // are not re-seeded when they change their schedule, stock, or dose quantity.
            // The full signature includes mealsRaw/currentStock, so any user edit would
            // cause a false "missing seed" detection and insert a duplicate with the
            // original schedule — which then wins the merge because its updatedAt is newer.
            let existingRelaxedIDs = Set(existing.map { relaxedIdentitySignature(for: $0) })
            let meds = buildDefaultMedications()
            var inserted = 0

            for med in meds where !existingRelaxedIDs.contains(relaxedIdentitySignature(for: med)) {
                context.insert(med)
                inserted += 1
                hasChanges = true
            }

            if hasChanges {
                try context.save()
            }
            Self.logger.notice("Medication seed complete (inserted: \(inserted, privacy: .public), removed duplicates: \(duplicateSeedMeds.count, privacy: .public))")

        } catch {
            Self.logger.error("Failed to seed medications: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Builders
private extension MedicationSeedService {
    nonisolated func signature(for medication: Medication) -> String {
        let meals = medication.mealsRaw.sorted().joined(separator: ",")
        return [
            medication.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            medication.frequencyRaw,
            medication.medicationTypeRaw,
            medication.stockUnitRaw,
            String(medication.currentStock),
            String(medication.doseQuantity),
            meals
        ].joined(separator: "|")
    }

    nonisolated func duplicateSeedDefaults(in existing: [Medication]) -> [Medication] {
        let seedSignatures = Set(buildDefaultMedications().map { signature(for: $0) })
        let seedMeds = existing.filter { seedSignatures.contains(signature(for: $0)) }
        let grouped = Dictionary(grouping: seedMeds, by: { signature(for: $0) })

        var duplicates: [Medication] = []
        for group in grouped.values where group.count > 1 {
            let sorted = group.sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
            duplicates.append(contentsOf: sorted.dropFirst())
        }
        return duplicates
    }

    nonisolated func logicalIdentitySignature(for medication: Medication) -> String {
        let meals = medication.mealsRaw.sorted().joined(separator: ",")
        return [
            normalizedText(medication.name),
            normalizedDosage(medication.dosage),
            medication.frequencyRaw,
            medication.medicationTypeRaw,
            meals
        ].joined(separator: "|")
    }

    nonisolated func relaxedIdentitySignature(for medication: Medication) -> String {
        [
            normalizedText(medication.name),
            normalizedDosage(medication.dosage),
            medication.medicationTypeRaw
        ].joined(separator: "|")
    }

    nonisolated func selectKeeper(from medications: [Medication], doses: [MedicationDose]) -> Medication? {
        guard !medications.isEmpty else {
            Self.logger.notice("selectKeeper: empty medication group (skipped)")
            return nil
        }
        var doseCountByMedicationID: [UUID: Int] = [:]
        for dose in doses {
            guard let medicationID = dose.medication?.id else { continue }
            doseCountByMedicationID[medicationID, default: 0] += 1
        }

        let sorted = medications.sorted { lhs, rhs in
            let lhsDoseCount = doseCountByMedicationID[lhs.id] ?? 0
            let rhsDoseCount = doseCountByMedicationID[rhs.id] ?? 0
            if lhsDoseCount != rhsDoseCount {
                return lhsDoseCount > rhsDoseCount
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return sorted[0]
    }

    nonisolated func mergeMedication(_ keeper: Medication, with duplicate: Medication) {
        if (keeper.instructions ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let duplicateInstructions = duplicate.instructions,
           !duplicateInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keeper.instructions = duplicateInstructions
        }

        if keeper.updatedAt < duplicate.updatedAt {
            keeper.mealsRaw = duplicate.mealsRaw
            keeper.frequencyRaw = duplicate.frequencyRaw
        }

        keeper.currentStock = min(keeper.currentStock, duplicate.currentStock)
        keeper.isActive = keeper.isActive || duplicate.isActive
        keeper.updatedAt = max(keeper.updatedAt, duplicate.updatedAt)
    }

    nonisolated func mergeDose(_ keeperDose: MedicationDose, with duplicateDose: MedicationDose) {
        let preferredStatus = preferredDoseStatus(keeperDose.status, duplicateDose.status)
        keeperDose.status = preferredStatus

        if keeperDose.takenTime == nil, let duplicateTakenTime = duplicateDose.takenTime {
            keeperDose.takenTime = duplicateTakenTime
        }
        keeperDose.updatedAt = max(keeperDose.updatedAt, duplicateDose.updatedAt)
    }

    nonisolated func preferredDoseStatus(_ lhs: DoseStatus, _ rhs: DoseStatus) -> DoseStatus {
        lhs.sortPriority >= rhs.sortPriority ? lhs : rhs
    }

    nonisolated func selectDoseKeeper(from doses: [MedicationDose]) -> MedicationDose? {
        guard !doses.isEmpty else {
            Self.logger.notice("selectDoseKeeper: empty dose group (skipped)")
            return nil
        }
        return doses.sorted(by: doseShouldSortBefore)[0]
    }

    nonisolated func doseShouldSortBefore(_ lhs: MedicationDose, _ rhs: MedicationDose) -> Bool {
        DoseRankingPolicy.sortsBefore(lhs, rhs)
    }

    nonisolated func doseKey(for dose: MedicationDose) -> String {
        "\(dose.mealTimeRaw)|\(dose.scheduledDate.timeIntervalSince1970.safeInt)"
    }

    nonisolated func doseStorageKey(for dose: MedicationDose) -> String {
        let medicationID = dose.medication?.id.uuidString ?? "none"
        return "\(medicationID)|\(doseKey(for: dose))"
    }

    nonisolated func normalizedText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    nonisolated func normalizedDosage(_ value: String) -> String {
        normalizedText(value).replacingOccurrences(of: " ", with: "")
    }

    nonisolated func buildDefaultMedications() -> [Medication] {
        return [
            Medication(
                name: "Aspirin (Low Dose)",
                dosage: "81 mg",
                meals: [.breakfast],
                medicationType: .tablet,
                currentStock: 90,
                stockUnit: .tablets
            ),
            Medication(
                name: "Vitamin / Supplement",
                dosage: "500 mg",
                meals: [.breakfast, .dinner],
                medicationType: .supplement,
                currentStock: 20,
                doseQuantity: 1,
                stockUnit: .tablets
            )
        ]
    }
}
