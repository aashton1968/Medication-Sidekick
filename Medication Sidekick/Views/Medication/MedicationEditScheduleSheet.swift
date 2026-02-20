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

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    let medication: Medication

    // MARK: - Form State
    @State private var frequency: MedicationFrequency = .daily
    @State private var selectedMealKeys: Set<String> = []
    @State private var isActive: Bool = true
    @State private var estimatedDailyDoses: Int = 1

    private var isValid: Bool {
        frequency == .asNeeded || !selectedMealKeys.isEmpty
    }

    private var hasChanges: Bool {
        frequency != medication.frequency ||
        selectedMealKeys != Set(medication.mealsRaw) ||
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
                                        .foregroundStyle(.secondary)

                                    if selectedMealKeys.contains(setting.key) {
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
            isActive = medication.isActive
            estimatedDailyDoses = medication.estimatedDailyDoses
        }
    }

    private func save() {
        medication.mealsRaw = mealTimeSettings
            .filter { selectedMealKeys.contains($0.key) }
            .map(\.key)
        medication.frequency = frequency
        medication.isActive = isActive
        medication.estimatedDailyDoses = estimatedDailyDoses
        medication.updatedAt = Date()
        try? modelContext.save()
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
