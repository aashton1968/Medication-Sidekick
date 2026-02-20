//
//  Enums.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//
import Foundation

// MARK: - Medication Frequency

enum MedicationFrequency: String, Codable, CaseIterable {
    case daily
    case everyOtherDay
    case specificDays
    case asNeeded

    var displayName: String {
        switch self {
        case .daily:          return "Daily"
        case .everyOtherDay:  return "Every Other Day"
        case .specificDays:   return "Specific Days"
        case .asNeeded:       return "As Needed"
        }
    }
}

// MARK: - Dose Status

enum DoseStatus: String, Codable, CaseIterable {
    case scheduled
    case taken
    case skipped
    case missed
}

// MARK: - Meal Time

enum MealTime: String, Codable, CaseIterable {
    case preBreakfast
    case breakfast
    case lunch
    case dinner
    case supper
    case bedTime

    var displayName: String {
        switch self {
        case .preBreakfast: return "Pre-Breakfast"
        case .breakfast:    return "Breakfast"
        case .lunch:        return "Lunch"
        case .dinner:       return "Dinner"
        case .supper:       return "Supper"
        case .bedTime:      return "BedTime"
        }
    }

    var defaultDateComponents: DateComponents {
        switch self {
        case .preBreakfast: return DateComponents(hour: 6, minute: 30)
        case .breakfast:    return DateComponents(hour: 7, minute: 0)
        case .lunch:        return DateComponents(hour: 12, minute: 0)
        case .dinner:       return DateComponents(hour: 18, minute: 30)
        case .supper:       return DateComponents(hour: 20, minute: 0)
        case .bedTime:      return DateComponents(hour: 10, minute: 30)
        }
    }
}

// MARK: - Medication Type

enum MedicationType: String, Codable, CaseIterable {
    case tablet
    case capsule
    case liquid
    case injection
    case inhaler
    case topical
    case patch
    case drops
    case supplement

    var displayName: String {
        switch self {
        case .tablet:     return "Tablet"
        case .capsule:    return "Capsule"
        case .liquid:     return "Liquid"
        case .injection:  return "Injection"
        case .inhaler:    return "Inhaler"
        case .topical:    return "Topical"
        case .patch:      return "Patch"
        case .drops:      return "Drops"
        case .supplement: return "Supplement"
        }
    }

    var symbolName: String {
        switch self {
        case .tablet:     return "pill.fill"
        case .capsule:    return "pills.fill"
        case .liquid:     return "drop.fill"
        case .injection:  return "syringe.fill"
        case .inhaler:    return "lungs.fill"
        case .topical:    return "bandage.fill"
        case .patch:      return "cross.vial.fill"
        case .drops:      return "eye.dropper.fill"
        case .supplement: return "leaf.fill"
        }
    }

    var defaultStockUnit: StockUnit {
        switch self {
        case .tablet:     return .tablets
        case .capsule:    return .capsules
        case .liquid:     return .ml
        case .injection:  return .units
        case .inhaler:    return .puffs
        case .topical:    return .doses
        case .patch:      return .patches
        case .drops:      return .drops
        case .supplement: return .tablets
        }
    }
}

// MARK: - Stock Unit

enum StockUnit: String, Codable, CaseIterable {
    case tablets
    case capsules
    case pills
    case ml
    case doses
    case puffs
    case patches
    case sachets
    case units
    case drops

    var displayName: String {
        switch self {
        case .tablets:  return "Tablets"
        case .capsules: return "Capsules"
        case .pills:    return "Pills"
        case .ml:       return "mL"
        case .doses:    return "Doses"
        case .puffs:    return "Puffs"
        case .patches:  return "Patches"
        case .sachets:  return "Sachets"
        case .units:    return "Units"
        case .drops:    return "Drops"
        }
    }
}

// MARK: - Stock Level

enum StockLevel {
    case good       // >= 14 days supply
    case warning    // 7–13 days supply
    case critical   // 1–6 days supply
    case empty      // 0 stock

    var displayName: String {
        switch self {
        case .good:     return "Well Stocked"
        case .warning:  return "Running Low"
        case .critical: return "Very Low"
        case .empty:    return "Out of Stock"
        }
    }

    var symbolName: String {
        switch self {
        case .good:     return "circle.fill"
        case .warning:  return "circle.fill"
        case .critical: return "exclamationmark.circle.fill"
        case .empty:    return "xmark.circle.fill"
        }
    }
}
