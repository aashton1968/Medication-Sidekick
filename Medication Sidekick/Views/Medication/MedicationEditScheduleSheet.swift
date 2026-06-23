//
//  MedicationEditScheduleSheet.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-19.
//

import SwiftUI
import SwiftData

struct MedicationEditScheduleSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    let medication: Medication

    // MARK: - Form State
    @State private var frequency: MedicationFrequency = .daily
    @State private var selectedMealKeys: Set<String> = []
    @State private var selectedWeekdays: Set<Int> = []
    @State private var isActive: Bool = true
    @State private var estimatedDailyDoses: Int = 1

    private static let weekdayNames: [(Int, String)] = [
        (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"),
        (5, "Thursday"), (6, "Friday"), (7, "Saturday"), (1, "Sunday")
    ]

    private var isValid: Bool {
        if frequency == .asNeeded { return true }
        if frequency == .specificDays && selectedWeekdays.isEmpty { return false }
        return !selectedMealKeys.isEmpty
    }

    private var hasChanges: Bool {
        frequency != medication.frequency ||
        selectedMealKeys != Set(medication.mealsRaw) ||
        selectedWeekdays != medication.scheduledWeekdays ||
        isActive != medication.isActive ||
        estimatedDailyDoses != medication.estimatedDailyDoses
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(MedicationFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)

                    if frequency == .asNeeded {
                        Stepper("Est. daily doses: \(estimatedDailyDoses)", value: $estimatedDailyDoses, in: 1...10)
                    }
                }

                if frequency == .specificDays {
                    Section("Days of the Week") {
                        ForEach(Self.weekdayNames, id: \.0) { weekday, name in
                            Button {
                                if selectedWeekdays.contains(weekday) {
                                    selectedWeekdays.remove(weekday)
                                } else {
                                    selectedWeekdays.insert(weekday)
                                }
                            } label: {
                                HStack {
                                    Text(name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedWeekdays.contains(weekday) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if frequency != .asNeeded {
                    Section("When to Take") {
                        ForEach(mealTimeSettings) { setting in
                            Button {
                                toggleMeal(setting.key)
                            } label: {
                                HStack {
                                    Image(systemName: setting.symbolName)
                                        .frame(width: 24)
                                        .foregroundStyle(.tint)

                                    Text(setting.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Text(setting.displayTime)
                                        .font(.caption)
                                        .foregroundStyle(themeManager.selectedTheme.textSecondary)

                                    if selectedMealKeys.contains(setting.key) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(themeManager.selectedTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Active", isOn: $isActive)
                }
            }
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || !hasChanges)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            frequency = medication.frequency
            selectedMealKeys = Set(medication.mealsRaw)
            selectedWeekdays = medication.scheduledWeekdays
            isActive = medication.isActive
            estimatedDailyDoses = medication.estimatedDailyDoses
        }
    }

    private func save() {
        medication.mealsRaw = mealTimeSettings
            .filter { selectedMealKeys.contains($0.key) }
            .map(\.key)
        medication.frequency = frequency
        medication.scheduledWeekdays = frequency == .specificDays ? selectedWeekdays : []
        medication.isActive = isActive
        medication.estimatedDailyDoses = estimatedDailyDoses
        medication.updatedAt = Date()

        do {
            try MedicationDoseGenerator.refreshDoses(for: medication, modelContext: modelContext)
        } catch {
            ToastManager.shared.showError("Schedule saved, but doses could not refresh. Pull to refresh Today.")
        }

        do {
            try modelContext.save()
        } catch {
            ToastManager.shared.showError("Could not save schedule. Please try again.")
            return
        }
        NotificationCenter.default.post(name: .medicationDidChange, object: nil)
        dismiss()
    }

    private func toggleMeal(_ key: String) {
        if selectedMealKeys.contains(key) {
            selectedMealKeys.remove(key)
        } else {
            selectedMealKeys.insert(key)
        }
    }
}

#if DEBUG
#Preview("Edit Schedule") {
    let container = PreviewData.container
    let context = container.mainContext
    let medication = (try? context.fetch(FetchDescriptor<Medication>()))?.first ?? {
        fatalError("No preview medications")
    }()

    return MedicationEditScheduleSheet(medication: medication)
        .modelContainer(container)
}
#endif
