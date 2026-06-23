//
//  MedicationAddView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import SwiftUI
import SwiftData

struct MedicationAddView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    // MARK: - Form State
    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var instructions: String = ""
    @State private var selectedMealKeys: Set<String> = []
    @State private var medicationType: MedicationType = .tablet
    @State private var frequency: MedicationFrequency = .daily
    @State private var estimatedDailyDoses: Int = 1
    @State private var currentStock: Int = 0
    @State private var doseQuantity: Int = 1
    @State private var stockUnit: StockUnit = .tablets

    // MARK: - Validation
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dosage.trimmingCharacters(in: .whitespaces).isEmpty &&
        (frequency == .asNeeded || !selectedMealKeys.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Medication") {
                    TextField("Name", text: $name)
                    TextField("Dosage (e.g. 500 mg)", text: $dosage)
                    TextField("Instructions", text: $instructions)
                }

                Section("Type") {
                    Picker("Medication Type", selection: $medicationType) {
                        ForEach(MedicationType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.symbolName).tag(type)
                        }
                    }
                }

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
                        Text("Select meals to take with")
                            .font(.footnote)
                            .foregroundStyle(themeManager.selectedTheme.textSecondary)

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

                Section("Stock") {
                    HStack {
                        Text("Current Stock")
                        Spacer()
                        TextField("0", value: $currentStock, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Stepper("Per dose: \(doseQuantity)", value: $doseQuantity, in: 1...10)

                    Picker("Unit", selection: $stockUnit) {
                        ForEach(StockUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            }
            .navigationTitle("New Medication")
            .toolbar {

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: medicationType) { _, newType in
                stockUnit = newType.defaultStockUnit
            }
        }
    }

    // MARK: - Save
    private func save() {

        let orderedKeys = mealTimeSettings
            .filter { selectedMealKeys.contains($0.key) }
            .map(\.key)

        let medication = Medication(
            name: name,
            dosage: dosage,
            instructions: instructions.isEmpty ? nil : instructions,
            frequency: frequency,
            startDate: Date(),
            medicationType: medicationType,
            currentStock: currentStock,
            doseQuantity: doseQuantity,
            stockUnit: stockUnit,
            estimatedDailyDoses: estimatedDailyDoses
        )
        medication.mealsRaw = orderedKeys

        modelContext.insert(medication)

        do {
            try MedicationDoseGenerator.generateUpcomingDoses(for: medication, modelContext: modelContext)
        } catch {
            ToastManager.shared.showError("Medication saved, but doses could not be generated. Pull to refresh Today.")
        }

        do {
            try modelContext.save()
        } catch {
            ToastManager.shared.showError("Could not save medication. Please try again.")
            return
        }
        NotificationCenter.default.post(name: .medicationDidChange, object: nil)
        dismiss()
    }

    // MARK: - Helpers
    private func toggleMeal(_ key: String) {
        if selectedMealKeys.contains(key) {
            selectedMealKeys.remove(key)
        } else {
            selectedMealKeys.insert(key)
        }
    }
}

#Preview("Medication Add (Sheet)") {
    MedicationAddView()
        .modelContainer(PreviewData.container)
}
