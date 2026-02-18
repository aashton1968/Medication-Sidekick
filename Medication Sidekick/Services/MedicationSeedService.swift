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

            // ✅ Prevent duplicates
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

            buildMedication(
                name: "Valsartan",
                dosage: "40 mg",
                times: [DateComponents(hour: 7, minute: 0)]
            ),

            buildMedication(
                name: "Aspirin (Low Dose)",
                dosage: "81 mg",
                times: [DateComponents(hour: 7, minute: 0)]
            ),

            buildMedication(
                name: "Atorvastatin",
                dosage: "20 mg",
                times: [DateComponents(hour: 7, minute: 0)]
            ),

            buildMedication(
                name: "Rivaroxaban",
                dosage: "2.5 mg",
                times: [DateComponents(hour: 7, minute: 0)]
            ),

            buildMedication(
                name: "Colchicine",
                dosage: "0.5 mg",
                times: [DateComponents(hour: 7, minute: 0)]
            ),

            buildMedication(
                name: "Citalopram",
                dosage: "20 mg",
                times: [DateComponents(hour: 20, minute: 0)]
            ),

            buildMedication(
                name: "Vitamin / Supplement",
                dosage: "500 mg",
                times: [
                    DateComponents(hour: 8, minute: 0),
                    DateComponents(hour: 20, minute: 0)
                ]
            )
        ]
    }

    func buildMedication(
        name: String,
        dosage: String,
        times: [DateComponents]
    ) -> Medication {

        let medication = Medication(
            name: name,
            dosage: dosage
        )

        let schedule = MedicationSchedule(
            frequency: .daily,
            times: times,
            startDate: Calendar.current.startOfDay(for: Date())
        )

        medication.schedule = schedule

        return medication
    }
}
