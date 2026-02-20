//
//  MedicationDose.swift
//  Medication Sidekick
//

import Foundation
import SwiftData

@Model
final class MedicationDose {

    // MARK: - Relationships
    @Relationship
    var medication: Medication?

    // MARK: - Timing
    var mealTimeRaw: String = MealTime.breakfast.rawValue
    var scheduledDate: Date

    // MARK: - Outcome
    var statusRaw: String = DoseStatus.scheduled.rawValue
    var takenTime: Date? = nil

    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Computed
    var mealTime: MealTime {
        get { MealTime(rawValue: mealTimeRaw) ?? .breakfast }
        set { mealTimeRaw = newValue.rawValue }
    }

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    init(
        medication: Medication,
        mealTime: MealTime,
        scheduledDate: Date,
        status: DoseStatus = .scheduled
    ) {
        self.medication = medication
        self.mealTimeRaw = mealTime.rawValue
        self.scheduledDate = scheduledDate
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(
        medication: Medication,
        mealKey: String,
        scheduledDate: Date,
        status: DoseStatus = .scheduled
    ) {
        self.medication = medication
        self.mealTimeRaw = mealKey
        self.scheduledDate = scheduledDate
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Resolves the display name for this dose's meal time from MealTimeSettings, falling back to the enum displayName
    func mealDisplayName(settings: [MealTimeSetting]) -> String {
        if let setting = settings.first(where: { $0.key == mealTimeRaw }) {
            return setting.name
        }
        return mealTime.displayName
    }

    // MARK: - Stock-Aware Status Transitions

    /// Marks the dose as taken and decrements the parent medication's stock.
    func markAsTaken(at time: Date = Date()) {
        guard status != .taken else { return }
        status = .taken
        takenTime = time
        updatedAt = Date()
        if let medication {
            medication.currentStock = max(0, medication.currentStock - medication.doseQuantity)
            medication.updatedAt = Date()
        }
    }

    /// Reverts a taken dose back to scheduled and restores the parent medication's stock.
    func undoTaken() {
        guard status == .taken else { return }
        let restoreQty = medication?.doseQuantity ?? 1
        status = .scheduled
        takenTime = nil
        updatedAt = Date()
        if let medication {
            medication.currentStock += restoreQty
            medication.updatedAt = Date()
        }
    }
}
