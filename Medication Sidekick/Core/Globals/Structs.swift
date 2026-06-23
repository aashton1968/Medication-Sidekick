//
//  Structs.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-10-24.
//
import SwiftUI
import Foundation
import SwiftData

struct MenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void
}





struct NavigationRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 6)
            }
    }
}

extension View {
    func navigationRow() -> some View {
        self.modifier(NavigationRowModifier())
    }
}

// MARK: - Dose Ranking Policy

/// Single source of truth for which MedicationDose "wins" when two records
/// represent the same logical dose. Used by UI deduplication (TodayView) and
/// CloudKit reconciliation (MedicationSeedService) so they always pick the same keeper.
enum DoseRankingPolicy {

    nonisolated static func preferred(_ lhs: MedicationDose, _ rhs: MedicationDose) -> MedicationDose {
        if lhs.status.sortPriority != rhs.status.sortPriority {
            return lhs.status.sortPriority > rhs.status.sortPriority ? lhs : rhs
        }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt ? lhs : rhs }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt <= rhs.createdAt ? lhs : rhs }
        let lhsID = lhs.medication?.id.uuidString ?? ""
        let rhsID = rhs.medication?.id.uuidString ?? ""
        if lhsID != rhsID { return lhsID < rhsID ? lhs : rhs }
        if lhs.mealTimeRaw != rhs.mealTimeRaw { return lhs.mealTimeRaw < rhs.mealTimeRaw ? lhs : rhs }
        return lhs
    }

    nonisolated static func sortsBefore(_ lhs: MedicationDose, _ rhs: MedicationDose) -> Bool {
        if lhs.status.sortPriority != rhs.status.sortPriority { return lhs.status.sortPriority > rhs.status.sortPriority }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        let lhsID = lhs.medication?.id.uuidString ?? ""
        let rhsID = rhs.medication?.id.uuidString ?? ""
        if lhsID != rhsID { return lhsID < rhsID }
        if lhs.mealTimeRaw != rhs.mealTimeRaw { return lhs.mealTimeRaw < rhs.mealTimeRaw }
        return false
    }
}



