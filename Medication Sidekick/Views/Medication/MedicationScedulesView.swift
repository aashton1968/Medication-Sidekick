//
//  MedicationSchedulesView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-03.
//

import SwiftUI
import SwiftData

struct MedicationSchedulesView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    
    @Query(sort: \Medication.name)
    private var medications: [Medication]

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    private var activeMedications: [Medication] {
        medications.filter { $0.isActive && !$0.mealsRaw.isEmpty }
    }

    private var groupedByMeal: [(setting: MealTimeSetting, medications: [Medication])] {
        mealTimeSettings.compactMap { setting in
            let meds = activeMedications.filter { $0.mealsRaw.contains(setting.key) }
            guard !meds.isEmpty else { return nil }
            return (setting: setting, medications: meds)
        }
    }

    var body: some View {
        
        List {
            if groupedByMeal.isEmpty {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.plus",
                    description: Text("You haven't created any medication schedules yet.")
                )
            } else {
                ForEach(groupedByMeal, id: \.setting.id) { group in
                    Section(header: Text("\(group.setting.name) — \(group.setting.displayTime)")) {
                        ForEach(group.medications) { medication in
                            ScheduleRowView(medication: medication, mealTimeSettings: mealTimeSettings)
                        }
                    }
                }
            }
        }
        
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.selectedTheme.toolbarButtonAccentColor)
                        .accessibilityLabel("More")
                }
            }
        }
    
        .toolbarBackground(Color(themeManager.selectedTheme.toolbarBackgroundColor), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct ScheduleRowView: View {

    let medication: Medication
    let mealTimeSettings: [MealTimeSetting]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(medication.name)
                .font(.headline)

            Text(medication.frequency.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(timesSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let endDate = medication.endDate {
                Text("Ended \(endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }

    private var timesSummary: String {
        let names = medication.mealDisplayNames(settings: mealTimeSettings)
        return names.isEmpty ? "No meals set" : names.joined(separator: ", ")
    }
}


#Preview("Schedules View") {
    
    let themeManager = ThemeManager()
    let container = PreviewData.container
    
    return NavPreview {
        MedicationSchedulesView()
    }
    .modelContainer(container)
    .environment(themeManager)
    .environmentObject(NavigationRouter())
}
