//
//  MedicationDose.swift
//  Medication Sidekick
//

import Foundation
import SwiftData

@Model
final class MedicationDose {

    // MARK: - Identity
    @Relationship
    var schedule: MedicationSchedule

    // MARK: - Timing
    var scheduledDate: Date

    // MARK: - Metadata
    var createdAt: Date = Date()

    init(
        schedule: MedicationSchedule,
        scheduledDate: Date
    ) {
        self.schedule = schedule
        self.scheduledDate = scheduledDate
        self.createdAt = Date()
    }
}
