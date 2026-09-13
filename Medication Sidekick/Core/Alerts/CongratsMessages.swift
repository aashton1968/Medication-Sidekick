//
//  CongratsMessages.swift
//  Medication Sidekick
//

import Foundation

enum CongratsMessages {
    private static let genericSingleDoseMessages = [
        "Great job staying on track!",
        "Nice work - dose logged!",
        "Awesome consistency!"
    ]

    private static let namedSingleDoseTemplates = [
        "Great job taking %@!",
        "Nice work - %@ logged!",
        "Awesome - %@ taken."
    ]

    static func forSingleDose(medicationName: String?) -> String {
        let cleanedName = medicationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanedName.isEmpty, let template = namedSingleDoseTemplates.randomElement() {
            return String(format: template, cleanedName)
        }
        return genericSingleDoseMessages.randomElement() ?? "Great job!"
    }

}
