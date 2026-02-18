//
//  PreviewData.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//


// In a shared file, e.g., PreviewData.swif
import Foundation
import SwiftData

// Preview-only SwiftData container + sample seed data
@MainActor
struct PreviewData {

        
    /// Fresh in-memory container every time it is accessed (more reliable for Xcode Previews than a static-let singleton).
    static var container: ModelContainer {
        do {
            let schema = Schema([
                Medication.self,
                MedicationDose.self,
                MedicationDoseEvent.self,
                MedicationSchedule.self
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
        // Build once per preview render; if you ever re-call seed on the same context, you can guard by checking existing data.

        // Example schedules are optional; if MedicationSchedule isn’t ready yet, you can remove these and keep meds only.
        let metforminSchedule = MedicationSchedule.previewDaily(times: ["08:00", "18:00"])
        let basalSchedule = MedicationSchedule.previewDaily(times: ["18:00"])
        let statinSchedule = MedicationSchedule.previewDaily(times: ["08:00"])
        
        let meds: [Medication] = [
            Medication(
                name: "Metformin",
                dosage: "500 mg",
                instructions: "Take with meals to reduce stomach upset",
                isActive: true
            ),
            Medication(
                name: "Vitamin D",
                dosage: "1,000 IU",
                instructions: "Once daily in the morning",
                isActive: true
            ),
            Medication(
                name: "Atorvastatin",
                dosage: "20 mg",
                instructions: "Take at night",
                isActive: true
            ),
            Medication(
                name: "Insulin (Basal)",
                dosage: "18 units",
                instructions: "Once daily before bed",
                isActive: true
            ),
            Medication(
                name: "Aspirin",
                dosage: "81 mg",
                instructions: "Low-dose cardiovascular protection",
                isActive: false
            ),
            Medication(
                name: "Insulin (Bolus)",
                dosage: "26 units",
                instructions: "Once daily before bed",
                isActive: false
            )
        ]

        // Attach schedules to a couple of meds (safe even if your UI doesn’t show schedules yet)
        meds.first(where: { $0.name == "Metformin" })?.schedule = metforminSchedule
        meds.first(where: { $0.name == "Insulin (Basal)" })?.schedule = basalSchedule
        meds.first(where: { $0.name == "Atorvastatin" })?.schedule = statinSchedule

        context.insert(metforminSchedule)
        context.insert(basalSchedule)
        context.insert(statinSchedule)

        meds.forEach { context.insert($0) }

        // MARK: - Create Doses + Events (Today)

        let calendar = Calendar.current
        let today = Date()

        for medication in meds {
            guard let schedule = medication.schedule else { continue }

            for time in schedule.times {
                guard let scheduledDate = calendar.date(
                    bySettingHour: time.hour ?? 0,
                    minute: time.minute ?? 0,
                    second: 0,
                    of: today
                ) else { continue }

                let dose = MedicationDose(
                    schedule: schedule,
                    scheduledDate: scheduledDate
                )

                context.insert(dose)

                let event = MedicationDoseEvent(dose: dose)
                context.insert(event)
            }
        }

        try? context.save()
    }
}

// MARK: - MedicationSchedule Preview Helpers

@MainActor
fileprivate extension MedicationSchedule {
    /// Helper to convert "HH:mm" strings to DateComponents (hour, minute)
    /// and create a realistic daily schedule for previews.
    static func previewDaily(times: [String]) -> MedicationSchedule {
        let dateComponents: [DateComponents] = times.compactMap { timeString in
            let parts = timeString.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else {
                return nil
            }
            return DateComponents(hour: hour, minute: minute)
        }

        return MedicationSchedule(
            frequency: .daily,
            times: dateComponents,
            startDate: Calendar.current.startOfDay(for: Date()),
            endDate: nil
        )
    }
}
