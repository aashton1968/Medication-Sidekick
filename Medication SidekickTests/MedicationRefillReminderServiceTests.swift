//
//  MedicationRefillReminderServiceTests.swift
//  Medication Sidekick Tests
//
//  Covers the pure decision logic in MedicationRefillReminderService —
//  medicationsNeedingReminder() and reminderBody() — which are kept free of
//  UNUserNotificationCenter/UserDefaults specifically so they can be tested directly.
//

import Testing
import Foundation
@testable import Medication_Sidekick

@MainActor
struct MedicationRefillReminderServiceTests {

    // MARK: Fixtures

    /// One meal, daily, dose quantity 1 → dailyConsumptionRate == 1, so currentStock maps
    /// 1:1 onto daysOfSupply, which makes the stock-level brackets easy to target:
    /// 0 → empty, 1–6 → critical, 7–13 → warning, 14+ → good.
    private func medication(
        name: String = "Amoxicillin",
        dosage: String = "500mg",
        currentStock: Int,
        isActive: Bool = true
    ) -> Medication {
        Medication(
            name: name,
            dosage: dosage,
            isActive: isActive,
            frequency: .daily,
            meals: [.breakfast],
            currentStock: currentStock,
            doseQuantity: 1
        )
    }

    // MARK: - medicationsNeedingReminder

    @Test func `a newly low medication with no prior state is notified`() {
        let med = medication(currentStock: 10) // warning
        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [med],
            previouslyNotifiedSeverities: [:]
        )

        #expect(result.toNotify.map(\.id) == [med.id])
        #expect(result.updatedSeverities[med.id.uuidString.lowercased()] == StockLevel.warning.severity)
    }

    @Test func `an unchanged severity is not re-notified`() {
        let med = medication(currentStock: 10) // warning
        let previous = [med.id.uuidString.lowercased(): StockLevel.warning.severity]

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [med],
            previouslyNotifiedSeverities: previous
        )

        #expect(result.toNotify.isEmpty)
        #expect(result.updatedSeverities == previous)
    }

    @Test func `an escalation from warning to critical re-notifies`() {
        let med = medication(currentStock: 3) // critical
        let previous = [med.id.uuidString.lowercased(): StockLevel.warning.severity]

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [med],
            previouslyNotifiedSeverities: previous
        )

        #expect(result.toNotify.map(\.id) == [med.id])
        #expect(result.updatedSeverities[med.id.uuidString.lowercased()] == StockLevel.critical.severity)
    }

    @Test func `a partial improvement that stays low does not notify but still updates the stored severity`() {
        // Regression test: the stored severity must track the *current* level, not just
        // the level that last triggered a notification — otherwise a partial improvement
        // (critical -> warning, without fully restocking to "good") would wedge the stored
        // value at the old, higher severity and swallow a later re-escalation back to critical.
        let med = medication(currentStock: 10) // warning (improved from critical)
        let previous = [med.id.uuidString.lowercased(): StockLevel.critical.severity]

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [med],
            previouslyNotifiedSeverities: previous
        )

        #expect(result.toNotify.isEmpty)
        #expect(result.updatedSeverities[med.id.uuidString.lowercased()] == StockLevel.warning.severity)
    }

    @Test func `re-escalating after a partial improvement notifies again`() {
        let med = medication(currentStock: 3) // critical again
        // Simulates the state left behind by the previous test: it had dropped to warning
        // after being critical, and the stored severity was correctly updated to warning.
        let previous = [med.id.uuidString.lowercased(): StockLevel.warning.severity]

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [med],
            previouslyNotifiedSeverities: previous
        )

        #expect(result.toNotify.map(\.id) == [med.id])
        #expect(result.updatedSeverities[med.id.uuidString.lowercased()] == StockLevel.critical.severity)
    }

    @Test func `fully restocking to a safe level clears the stored severity and does not notify`() {
        let med = medication(currentStock: 30) // good
        let previous = [med.id.uuidString.lowercased(): StockLevel.critical.severity]

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [med],
            previouslyNotifiedSeverities: previous
        )

        #expect(result.toNotify.isEmpty)
        #expect(result.updatedSeverities.isEmpty)
    }

    @Test func `an inactive medication is never notified even when critically low`() {
        let med = medication(currentStock: 0, isActive: false) // empty, but inactive

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [med],
            previouslyNotifiedSeverities: [:]
        )

        #expect(result.toNotify.isEmpty)
        #expect(result.updatedSeverities.isEmpty)
    }

    @Test func `stored state for a medication no longer present is dropped`() {
        // Simulates a deleted medication, or one that was made inactive, whose stale
        // severity would otherwise linger in UserDefaults forever.
        let staleKey = UUID().uuidString.lowercased()
        let survivor = medication(currentStock: 10) // warning
        let previous = [
            staleKey: StockLevel.critical.severity,
            survivor.id.uuidString.lowercased(): StockLevel.warning.severity
        ]

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [survivor],
            previouslyNotifiedSeverities: previous
        )

        #expect(result.updatedSeverities.keys.contains(staleKey) == false)
        #expect(result.toNotify.isEmpty) // survivor's severity was unchanged
    }

    @Test func `only low medications are notified out of a mixed set`() {
        let low = medication(name: "Low Med", currentStock: 3) // critical
        let ok = medication(name: "OK Med", currentStock: 30) // good

        let result = MedicationRefillReminderService.medicationsNeedingReminder(
            medications: [low, ok],
            previouslyNotifiedSeverities: [:]
        )

        #expect(result.toNotify.map(\.id) == [low.id])
        #expect(result.updatedSeverities.count == 1)
        #expect(result.updatedSeverities[low.id.uuidString.lowercased()] == StockLevel.critical.severity)
    }

    // MARK: - reminderBody

    @Test func `reminderBody names the medication and dosage when privacy mode is off`() {
        let med = medication(name: "Ibuprofen", dosage: "200mg", currentStock: 10) // warning
        let body = MedicationRefillReminderService.reminderBody(for: med, privacyMode: false)

        #expect(body.contains("Ibuprofen (200mg)"))
        #expect(body.contains("running low"))
        #expect(body.contains("~10 days supply"))
    }

    @Test func `reminderBody omits empty parentheses when there is no dosage`() {
        let med = medication(name: "Ibuprofen", dosage: "", currentStock: 10)
        let body = MedicationRefillReminderService.reminderBody(for: med, privacyMode: false)

        #expect(body.contains("Ibuprofen is running low"))
        #expect(body.contains("(") == false)
    }

    @Test func `reminderBody uses very low wording at critical severity`() {
        let med = medication(currentStock: 3) // critical
        let body = MedicationRefillReminderService.reminderBody(for: med, privacyMode: false)

        #expect(body.contains("very low"))
        #expect(body.contains("~3 days supply"))
    }

    @Test func `reminderBody uses the out-of-stock message at zero stock`() {
        let med = medication(currentStock: 0)
        let body = MedicationRefillReminderService.reminderBody(for: med, privacyMode: false)

        #expect(body.contains("out of stock"))
        #expect(body.contains("days supply") == false)
    }

    @Test func `reminderBody redacts the medication name in privacy mode`() {
        let med = medication(name: "Ibuprofen", currentStock: 0)
        let body = MedicationRefillReminderService.reminderBody(for: med, privacyMode: true)

        #expect(body.hasPrefix("A medication"))
        #expect(body.contains("Ibuprofen") == false)
    }
}
