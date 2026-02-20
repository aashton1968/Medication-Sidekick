//
//  Medication.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

import Foundation
import SwiftData

@Model
final class Medication {

    // MARK: - Identifiers
    var id: UUID = UUID()

    // MARK: - Core Fields
    var name: String = ""
    var dosage: String = ""
    var instructions: String? = nil
    var isActive: Bool = true

    // MARK: - Medication Type
    var medicationTypeRaw: String = MedicationType.tablet.rawValue

    // MARK: - Scheduling
    var frequencyRaw: String = MedicationFrequency.daily.rawValue
    var mealsRaw: [String] = []
    var startDate: Date = Date()
    var endDate: Date? = nil

    // MARK: - Stock / Inventory
    var currentStock: Int = 0
    var doseQuantity: Int = 1
    var stockUnitRaw: String = StockUnit.tablets.rawValue
    var estimatedDailyDoses: Int = 1

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \MedicationDose.medication)
    var doses: [MedicationDose] = []

    // MARK: - Computed
    var frequency: MedicationFrequency {
        get { MedicationFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var meals: [MealTime] {
        get { mealsRaw.compactMap { MealTime(rawValue: $0) } }
        set { mealsRaw = newValue.map(\.rawValue) }
    }

    var medicationType: MedicationType {
        get { MedicationType(rawValue: medicationTypeRaw) ?? .tablet }
        set { medicationTypeRaw = newValue.rawValue }
    }

    var stockUnit: StockUnit {
        get { StockUnit(rawValue: stockUnitRaw) ?? .tablets }
        set { stockUnitRaw = newValue.rawValue }
    }

    var dailyConsumptionRate: Double {
        let qty = Double(doseQuantity)
        switch frequency {
        case .daily:
            return Double(max(mealsRaw.count, 1)) * qty
        case .everyOtherDay:
            return (Double(max(mealsRaw.count, 1)) * qty) / 2.0
        case .specificDays:
            return (Double(max(mealsRaw.count, 1)) * qty) / 2.0
        case .asNeeded:
            return Double(max(estimatedDailyDoses, 1)) * qty
        }
    }

    var daysOfSupply: Int {
        guard dailyConsumptionRate > 0 else { return Int.max }
        return Int(Double(currentStock) / dailyConsumptionRate)
    }

    var stockLevel: StockLevel {
        if currentStock <= 0 { return .empty }
        let days = daysOfSupply
        if days >= 14 { return .good }
        if days >= 7 { return .warning }
        return .critical
    }

    // MARK: - Init
    init(
        name: String,
        dosage: String,
        instructions: String? = nil,
        isActive: Bool = true,
        frequency: MedicationFrequency = .daily,
        meals: [MealTime] = [],
        startDate: Date = Date(),
        endDate: Date? = nil,
        medicationType: MedicationType = .tablet,
        currentStock: Int = 0,
        doseQuantity: Int = 1,
        stockUnit: StockUnit = .tablets,
        estimatedDailyDoses: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.instructions = instructions
        self.isActive = isActive
        self.frequencyRaw = frequency.rawValue
        self.mealsRaw = meals.map(\.rawValue)
        self.startDate = startDate
        self.endDate = endDate
        self.medicationTypeRaw = medicationType.rawValue
        self.currentStock = currentStock
        self.doseQuantity = doseQuantity
        self.stockUnitRaw = stockUnit.rawValue
        self.estimatedDailyDoses = estimatedDailyDoses
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Helpers

    func isScheduleActive(on date: Date) -> Bool {
        if date < startDate { return false }
        if let endDate, date > endDate { return false }
        return true
    }

    func sortedTimes() -> [DateComponents] {
        meals.map { $0.defaultDateComponents }.sorted {
            ($0.hour ?? 0, $0.minute ?? 0) < ($1.hour ?? 0, $1.minute ?? 0)
        }
    }

    /// Resolves meal display names from MealTimeSettings, falling back to the MealTime enum
    func mealDisplayNames(settings: [MealTimeSetting]) -> [String] {
        let settingsByKey = Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0) })
        return mealsRaw.compactMap { key in
            if let setting = settingsByKey[key] {
                return setting.name
            }
            return MealTime(rawValue: key)?.displayName
        }
    }
}
