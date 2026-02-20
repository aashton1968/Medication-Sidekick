//
//  MealTimeListView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-18.
//

import SwiftUI
import SwiftData

struct MealTimeListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimes: [MealTimeSetting]

    @State private var showingAdd = false
    @State private var selectedMealTime: MealTimeSetting?

    var body: some View {
        List {

            if mealTimes.isEmpty {
                ContentUnavailableView(
                    "No Meal Times",
                    systemImage: "fork.knife",
                    description: Text("Tap + to add a meal time")
                )
            }

            ForEach(mealTimes) { mealTime in
                MealTimeRow(mealTime: mealTime)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMealTime = mealTime
                    }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Meal Times")
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.selectedTheme.toolbarButtonAccentColor)
                        .accessibilityLabel("Add Meal Time")
                }
            }
        }

        .toolbarBackground(Color(themeManager.selectedTheme.toolbarBackgroundColor), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)

        .sheet(isPresented: $showingAdd) {
            MealTimeEditView(
                mode: .add,
                nextSortOrder: (mealTimes.last?.sortOrder ?? -1) + 1
            )
        }
        .sheet(item: $selectedMealTime) { mealTime in
            MealTimeEditView(mode: .edit(mealTime))
        }
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let mealTime = mealTimes[index]
            removeMealReferences(key: mealTime.key)
            modelContext.delete(mealTime)
        }
        try? modelContext.save()
    }

    /// Cleans up medication references when a meal time is deleted
    private func removeMealReferences(key: String) {
        guard let medications = try? modelContext.fetch(FetchDescriptor<Medication>()) else { return }
        for med in medications where med.mealsRaw.contains(key) {
            med.mealsRaw.removeAll { $0 == key }
        }
    }
}

// MARK: - Row

struct MealTimeRow: View {

    let mealTime: MealTimeSetting

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: mealTime.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(mealTime.name)
                    .font(.headline)

                Text(mealTime.displayTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    let themeManager = ThemeManager()
    return NavigationStack {
        MealTimeListView()
    }
    .modelContainer(PreviewData.container)
    .environment(themeManager)
}
#endif
