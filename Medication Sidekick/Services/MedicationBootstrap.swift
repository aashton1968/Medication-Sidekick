//
//  MedicationBootstrap.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import SwiftData
import Foundation

struct MedicationBootstrap {

    static func generateTodayEvents(context: ModelContext) throws {

        let schedules = try context.fetch(FetchDescriptor<MedicationSchedule>())

        let calendar = Calendar.current
        let today = Date()

        for schedule in schedules {

            guard schedule.isActive(on: today) else { continue }

            for time in schedule.times {

                guard let scheduledDate = calendar.date(
                    bySettingHour: time.hour ?? 0,
                    minute: time.minute ?? 0,
                    second: 0,
                    of: today
                ) else { continue }

                // Check if already exists
                let existing = try context.fetch(FetchDescriptor<MedicationDoseEvent>())

                let alreadyExists = existing.contains {
                    $0.dose.scheduledDate == scheduledDate &&
                    $0.dose.schedule == schedule
                }

                if alreadyExists { continue }

                let dose = MedicationDose(
                    schedule: schedule,
                    scheduledDate: scheduledDate
                )

                let event = MedicationDoseEvent(dose: dose)

                context.insert(dose)
                context.insert(event)
            }
        }

        try context.save()
    }
}
