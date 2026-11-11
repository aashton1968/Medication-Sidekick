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
    @State private var timeOverrides: [String: DateComponents] = [:]
    @State private var medicationType: MedicationType = .tablet
    @State private var frequency: MedicationFrequency = .daily
    @State private var estimatedDailyDoses: Int = 1
    @State private var tracksStock: Bool = true
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
                    DoseTimesSection(
                        mealTimeSettings: mealTimeSettings,
                        selectedMealKeys: $selectedMealKeys,
                        timeOverrides: $timeOverrides
                    )
                }

                Section {
                    Toggle("Track Stock", isOn: $tracksStock)

                    if tracksStock {
                        StockQuantityRow(stock: $currentStock)

                        Stepper("Per dose: \(doseQuantity)", value: $doseQuantity, in: 1...10)

                        Picker("Unit", selection: $stockUnit) {
                            ForEach(StockUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                    }
                } header: {
                    Text("Stock")
                } footer: {
                    if !tracksStock {
                        Text("Use this for medications like insulin where the dose varies each time and isn't a fixed quantity to subtract from a running stock count.")
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
            tracksStock: tracksStock,
            currentStock: currentStock,
            doseQuantity: doseQuantity,
            stockUnit: stockUnit,
            estimatedDailyDoses: estimatedDailyDoses
        )
        medication.mealsRaw = orderedKeys
        medication.timeOverrides = timeOverrides.filter { orderedKeys.contains($0.key) }

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
}

#Preview("Medication Add (Sheet)") {
    MedicationAddView()
        .modelContainer(PreviewData.container)
}
