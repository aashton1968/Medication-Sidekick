//
//  Enums.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//
import Foundation

// Global enumerations used throughout the app
enum MedicationFrequency: String, Codable, CaseIterable {
    case daily
    case everyOtherDay
    case specificDays
    case asNeeded
}

extension MedicationFrequency {
    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .everyOtherDay:
            return "Every Other Day"
        case .specificDays:
            return "Specific Days"
        case .asNeeded:
            return "As Needed"
        }
    }
}

// Medication dose status
enum DoseStatus: String, Codable, CaseIterable {
    case scheduled
    case taken
    case skipped
    case missed
}


enum MedicationTimeOfDay {
    case morning
    case evening

    var dateComponents: DateComponents {
        switch self {
        case .morning:
            return DateComponents(hour: 8, minute: 0)

        case .evening:
            return DateComponents(hour: 20, minute: 0)
        }
    }
}
