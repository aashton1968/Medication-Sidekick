//
//  MedicationDoseEvent.swift
//  Medication Sidekick
//

import Foundation
import SwiftData

@Model
final class MedicationDoseEvent {

    // MARK: - Relationships
    @Relationship
    var dose: MedicationDose

    // MARK: - Timing
    /// When the user actually took the dose (nil if not taken)
    var takenTime: Date? = nil

    // MARK: - Outcome
    var status: DoseStatus = DoseStatus.scheduled

    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Init
    init(
        dose: MedicationDose,
        takenTime: Date? = nil,
        status: DoseStatus = .scheduled
    ) {
        self.dose = dose
        self.takenTime = takenTime
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
