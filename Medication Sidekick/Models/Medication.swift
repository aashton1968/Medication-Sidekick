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
    /// Comma-separated Calendar weekday integers (1=Sun … 7=Sat) for `.specificDays` frequency.
    /// Empty string means all days (used as a fallback if no days have been configured yet).
    var scheduledWeekdaysRaw: String = ""

    // MARK: - Stock / Inventory
    var currentStock: Int = 0
    var doseQuantity: Int = 1
    var stockUnitRaw: String = StockUnit.tablets.rawValue
    var estimatedDailyDoses: Int = 1

    // MARK: - Timezone Behavior
    /// When true (default), this medication's dose times follow the device's current
    /// timezone, so e.g. "8am breakfast" always means 8am local wherever the user is.
    /// When false, dose times stay anchored to `homeTimeZoneIdentifier` regardless of
    /// travel — for medications where the interval between doses matters more than the
    /// local clock hour (e.g. antibiotics dosed every 8 hours).
    var followsDeviceTimeZone: Bool = true
    /// IANA identifier captured the moment `followsDeviceTimeZone` is turned off.
    /// Used to anchor this medication's dose times to a fixed timezone instead of
    /// whichever timezone the device currently reports.
    var homeTimeZoneIdentifier: String? = nil

    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \MedicationDose.medication)
    var doses: [MedicationDose]? = []

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

    var scheduledWeekdays: Set<Int> {
        get {
            Set(scheduledWeekdaysRaw.split(separator: ",").compactMap { Int($0) })
        }
        set {
            scheduledWeekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// The calendar used to resolve this medication's meal times into absolute dose dates.
    /// Follows the device's live timezone for `followsDeviceTimeZone` medications so their
    /// scheduled times track local mealtimes when traveling; otherwise pins to
    /// `homeTimeZoneIdentifier` so the medication's clock time never moves with the device.
    var schedulingCalendar: Calendar {
        var calendar = Calendar.current
        guard !followsDeviceTimeZone,
              let identifier = homeTimeZoneIdentifier,
              let zone = TimeZone(identifier: identifier) else {
            return calendar
        }
        calendar.timeZone = zone
        return calendar
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
        let quotient = Double(currentStock) / dailyConsumptionRate
        let days = quotient.safeInt
        return max(days, 0)
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
        estimatedDailyDoses: Int = 1,
        followsDeviceTimeZone: Bool = true,
        homeTimeZoneIdentifier: String? = nil
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
        self.followsDeviceTimeZone = followsDeviceTimeZone
        self.homeTimeZoneIdentifier = homeTimeZoneIdentifier
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Helpers

    func isScheduleActive(on date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: startDate)
        if day < startDay { return false }
        if let endDate {
            let endDay = calendar.startOfDay(for: endDate)
            if day > endDay { return false }
        }
        return true
    }

    func sortedTimes() -> [DateComponents] {
        meals.map { $0.defaultDateComponents }.sorted {
            ($0.hour ?? 0, $0.minute ?? 0) < ($1.hour ?? 0, $1.minute ?? 0)
        }
    }

    /// Resolves meal display names from MealTimeSettings, falling back to the MealTime enum
    func mealDisplayNames(settings: [MealTimeSetting]) -> [String] {
        let settingsByKey = Dictionary(settings.map { ($0.key, $0) }, uniquingKeysWith: { _, latest in latest })
        return mealsRaw.compactMap { key in
            if let setting = settingsByKey[key] {
                return setting.name
            }
            return MealTime(rawValue: key)?.displayName
        }
    }
}
