//
//  MedicationEditView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-18.
//

import SwiftUI
import SwiftData

struct MedicationEditView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    let medication: Medication

    // MARK: - Form State
    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var instructions: String = ""
    @State private var selectedMealKeys: Set<String> = []
    @State private var timeOverrides: [String: DateComponents] = [:]
    @State private var frequency: MedicationFrequency = .daily
    @State private var isActive: Bool = true
    @State private var medicationType: MedicationType = .tablet
    @State private var tracksStock: Bool = true
    @State private var currentStock: Int = 0
    @State private var doseQuantity: Int = 1
    @State private var stockUnit: StockUnit = .tablets
    @State private var estimatedDailyDoses: Int = 1

    // MARK: - Validation
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dosage.trimmingCharacters(in: .whitespaces).isEmpty &&
        (frequency == .asNeeded || !selectedMealKeys.isEmpty)
    }

    private var hasChanges: Bool {
        name != medication.name ||
        dosage != medication.dosage ||
        instructions != (medication.instructions ?? "") ||
        selectedMealKeys != Set(medication.mealsRaw) ||
        timeOverrides != medication.timeOverrides ||
        frequency != medication.frequency ||
        isActive != medication.isActive ||
        medicationType != medication.medicationType ||
        tracksStock != medication.tracksStock ||
        currentStock != medication.currentStock ||
        doseQuantity != medication.doseQuantity ||
        stockUnit != medication.stockUnit ||
        estimatedDailyDoses != medication.estimatedDailyDoses
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

                Section {
                    Toggle("Active", isOn: $isActive)
                }
            }
            .navigationTitle("Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid || !hasChanges)
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
        .onAppear {
            name = medication.name
            dosage = medication.dosage
            instructions = medication.instructions ?? ""
            selectedMealKeys = Set(medication.mealsRaw)
            timeOverrides = medication.timeOverrides
            frequency = medication.frequency
            isActive = medication.isActive
            medicationType = medication.medicationType
            tracksStock = medication.tracksStock
            currentStock = medication.currentStock
            doseQuantity = medication.doseQuantity
            stockUnit = medication.stockUnit
            estimatedDailyDoses = medication.estimatedDailyDoses
        }
    }

    // MARK: - Save
    private func save() {
        medication.name = name
        medication.dosage = dosage
        medication.instructions = instructions.isEmpty ? nil : instructions
        let timesChanged = timeOverrides != medication.timeOverrides
        medication.mealsRaw = mealTimeSettings
            .filter { selectedMealKeys.contains($0.key) }
            .map(\.key)
        medication.timeOverrides = timeOverrides.filter { selectedMealKeys.contains($0.key) }
        medication.frequency = frequency
        medication.isActive = isActive
        medication.medicationType = medicationType
        medication.tracksStock = tracksStock
        medication.currentStock = currentStock
        medication.doseQuantity = doseQuantity
        medication.stockUnit = stockUnit
        medication.estimatedDailyDoses = estimatedDailyDoses

        medication.updatedAt = Date()

        do {
            try MedicationDoseGenerator.refreshDoses(for: medication, modelContext: modelContext)
            if timesChanged {
                try MedicationDoseGenerator.retimeStaleDoses(modelContext: modelContext)
            }
        } catch {
            ToastManager.shared.showError("Schedule saved, but doses could not refresh. Pull to refresh Today.")
        }

        do {
            try modelContext.save()
        } catch {
            ToastManager.shared.showError("Could not save changes. Please try again.")
            return
        }
        NotificationCenter.default.post(name: .medicationDidChange, object: nil)
        dismiss()
    }
}

#Preview("Edit Medication") {
    let container = PreviewData.container
    let context = container.mainContext
    let medication = (try? context.fetch(FetchDescriptor<Medication>()))?.first ?? {
        fatalError("No preview medications")
    }()

    return MedicationEditView(medication: medication)
        .modelContainer(container)
}
