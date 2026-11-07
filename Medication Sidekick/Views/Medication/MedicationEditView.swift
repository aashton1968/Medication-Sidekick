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
    @State private var currentStock: Int = 0
    @State private var doseQuantity: Int = 1
    @State private var stockUnit: StockUnit = .tablets
    @State private var estimatedDailyDoses: Int = 1
    @State private var followsDeviceTimeZone: Bool = true

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
        currentStock != medication.currentStock ||
        doseQuantity != medication.doseQuantity ||
        stockUnit != medication.stockUnit ||
        estimatedDailyDoses != medication.estimatedDailyDoses ||
        followsDeviceTimeZone != medication.followsDeviceTimeZone
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
                    MealReminderSection(
                        mealTimeSettings: mealTimeSettings,
                        selectedMealKeys: $selectedMealKeys,
                        timeOverrides: $timeOverrides
                    )
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

                Section {
                    Toggle("Active", isOn: $isActive)
                }

                Section {
                    Toggle("Adjust for Travel", isOn: $followsDeviceTimeZone)
                } footer: {
                    Text(followsDeviceTimeZone
                        ? "Dose times follow your device's current timezone, so this medication stays on the same local mealtime wherever you are."
                        : "Dose times stay fixed to \(medication.homeTimeZoneIdentifier ?? TimeZone.current.identifier) and won't shift when you travel — use this for medications where the interval between doses matters more than the local clock hour.")
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
            currentStock = medication.currentStock
            doseQuantity = medication.doseQuantity
            stockUnit = medication.stockUnit
            estimatedDailyDoses = medication.estimatedDailyDoses
            followsDeviceTimeZone = medication.followsDeviceTimeZone
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
        medication.currentStock = currentStock
        medication.doseQuantity = doseQuantity
        medication.stockUnit = stockUnit
        medication.estimatedDailyDoses = estimatedDailyDoses

        let travelModeChanged = followsDeviceTimeZone != medication.followsDeviceTimeZone
        if followsDeviceTimeZone == false && medication.followsDeviceTimeZone == true {
            medication.homeTimeZoneIdentifier = TimeZone.current.identifier
        }
        medication.followsDeviceTimeZone = followsDeviceTimeZone
        medication.updatedAt = Date()

        do {
            try MedicationDoseGenerator.refreshDoses(for: medication, modelContext: modelContext)
            if travelModeChanged || timesChanged {
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
