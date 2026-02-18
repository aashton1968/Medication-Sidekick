//
//  MedicationDoseGenerator.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-01.
//

import Foundation
import SwiftData

@MainActor
struct MedicationDoseGenerator {

    /// Generates scheduled doses for the next N days (default: 7)
    static func generateUpcomingDoses(
        for schedule: MedicationSchedule,
        daysAhead: Int = 7,
        modelContext: ModelContext
    ) throws {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let sortedTimes = schedule.sortedTimes()

        guard !sortedTimes.isEmpty else { return }

        let allDoses = try modelContext.fetch(FetchDescriptor<MedicationDose>())

        for dayOffset in 0..<daysAhead {

            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: today
            ) else { continue }

            // Respect start / end date
            guard schedule.isActive(on: day) else { continue }

            for time in sortedTimes {

                var components = calendar.dateComponents(
                    [.year, .month, .day],
                    from: day
                )

                components.hour = time.hour
                components.minute = time.minute
                components.second = 0

                guard let scheduledDate = calendar.date(from: components) else {
                    continue
                }

                // Prevent duplicates
                let startOfMinute = scheduledDate
                guard let endOfMinute = calendar.date(
                    byAdding: .minute,
                    value: 1,
                    to: startOfMinute
                ) else { continue }

                // Check for duplicates in memory
                let alreadyExists = allDoses.contains {
                    $0.schedule == schedule &&
                    $0.scheduledDate >= startOfMinute &&
                    $0.scheduledDate < endOfMinute
                }

                guard !alreadyExists else { continue }

                let dose = MedicationDose(
                    schedule: schedule,
                    scheduledDate: scheduledDate
                )

                modelContext.insert(dose)
            }
        }

        try modelContext.save()
    }
}
