//
//  Medication.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

// Medication.swift

import Foundation
import SwiftData

@Model
final class Medication {

    // MARK: - Identifiers
    var id: UUID = UUID()

    // MARK: - Core Fields
    var name: String = ""
    var dosage: String = ""                 // Display-only (e.g. "500 mg")
    var instructions: String? = nil          // Optional notes

    var isActive: Bool = true

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade)
    var schedule: MedicationSchedule? = nil

    // MARK: - Init
    init(
        name: String,
        dosage: String,
        instructions: String? = nil,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.instructions = instructions
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
