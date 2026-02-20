//
//  MedicationEditStockSheet.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-19.
//

import SwiftUI
import SwiftData

struct MedicationEditStockSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let medication: Medication

    // MARK: - Form State
    @State private var currentStock: Int = 0
    @State private var doseQuantity: Int = 1
    @State private var stockUnit: StockUnit = .tablets

    private var hasChanges: Bool {
        currentStock != medication.currentStock ||
        doseQuantity != medication.doseQuantity ||
        stockUnit != medication.stockUnit
    }

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Edit Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!hasChanges)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            currentStock = medication.currentStock
            doseQuantity = medication.doseQuantity
            stockUnit = medication.stockUnit
        }
    }

    private func save() {
        medication.currentStock = currentStock
        medication.doseQuantity = doseQuantity
        medication.stockUnit = stockUnit
        medication.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

#if DEBUG
#Preview("Edit Stock") {
    let container = PreviewData.container
    let context = container.mainContext
    let medication = (try? context.fetch(FetchDescriptor<Medication>()))?.first ?? {
        fatalError("No preview medications")
    }()

    return MedicationEditStockSheet(medication: medication)
        .modelContainer(container)
}
#endif
