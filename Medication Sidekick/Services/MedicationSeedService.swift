//
//  MedicationSeedService.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import Foundation
import SwiftData

actor MedicationSeedService {

    // MARK: - Public API
    func seedIfNeeded(container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            let existing = try context.fetch(FetchDescriptor<Medication>())

            if !existing.isEmpty {
                print("✅ Medications already exist — skipping seed")
                return
            }

            print("🌱 Seeding default medications...")

            let meds = buildDefaultMedications()

            for med in meds {
                context.insert(med)
            }

            try context.save()

            print("✅ Medication seed complete")

        } catch {
            print("❌ Failed to seed medications: \(error)")
        }
    }
}

// MARK: - Builders
private extension MedicationSeedService {

    func buildDefaultMedications() -> [Medication] {

        return [

            Medication(
                name: "Valsartan",
                dosage: "40 mg",
                meals: [.breakfast],
                medicationType: .tablet,
                currentStock: 45,
                stockUnit: .tablets
            ),

            Medication(
                name: "Aspirin (Low Dose)",
                dosage: "81 mg",
                meals: [.breakfast],
                medicationType: .tablet,
                currentStock: 90,
                stockUnit: .tablets
            ),

            Medication(
                name: "Atorvastatin",
                dosage: "20 mg",
                meals: [.breakfast],
                medicationType: .tablet,
                currentStock: 12,
                stockUnit: .tablets
            ),

            Medication(
                name: "Rivaroxaban",
                dosage: "2.5 mg",
                meals: [.breakfast],
                medicationType: .tablet,
                currentStock: 5,
                stockUnit: .tablets
            ),

            Medication(
                name: "Colchicine",
                dosage: "0.5 mg",
                meals: [.breakfast],
                medicationType: .tablet,
                currentStock: 28,
                stockUnit: .tablets
            ),

            Medication(
                name: "Citalopram",
                dosage: "20 mg",
                meals: [.supper],
                medicationType: .tablet,
                currentStock: 60,
                stockUnit: .tablets
            ),

            Medication(
                name: "Vitamin / Supplement",
                dosage: "500 mg",
                meals: [.breakfast, .supper],
                medicationType: .supplement,
                currentStock: 20,
                doseQuantity: 1,
                stockUnit: .tablets
            )
        ]
    }
}
