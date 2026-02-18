//
//  MedicationSchedule.swift
//  Medication Sidekick
//

import Foundation
import SwiftData

@Model
final class MedicationSchedule {

    // MARK: - Relationships
    @Relationship(inverse: \Medication.schedule)
    var medication: Medication?

    // MARK: - Core Scheduling
    var frequency: MedicationFrequency = MedicationFrequency.daily

    /// Times of day the medication should be taken (e.g. 08:00, 20:00)
    /// Stored as DateComponents to avoid timezone and DST issues
    var times: [DateComponents] = []

    // MARK: - Schedule Range
    var startDate: Date = Date()
    var endDate: Date? = nil

    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init
    init(
        frequency: MedicationFrequency,
        times: [DateComponents],
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.frequency = frequency
        self.times = times
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    // MARK: - Helpers

    /// Returns true if the schedule is active on the given date
    func isActive(on date: Date) -> Bool {
        if date < startDate { return false }
        if let endDate, date > endDate { return false }
        return true
    }

    /// Returns the scheduled times sorted by hour/minute
    func sortedTimes() -> [DateComponents] {
        times.sorted {
            ($0.hour ?? 0, $0.minute ?? 0) < ($1.hour ?? 0, $1.minute ?? 0)
        }
    }
}
