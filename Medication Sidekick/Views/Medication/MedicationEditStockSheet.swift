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
    @Environment(ThemeManager.self) private var themeManager

    let medication: Medication

    // MARK: - Form State
    @State private var tracksStock: Bool = true
    @State private var currentStock: Int = 0
    @State private var doseQuantity: Int = 1
    @State private var stockUnit: StockUnit = .tablets

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    private var hasChanges: Bool {
        tracksStock != medication.tracksStock ||
        currentStock != medication.currentStock ||
        doseQuantity != medication.doseQuantity ||
        stockUnit != medication.stockUnit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(medication.name)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                        Text(medication.dosage)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.surfaceBase)
                        .premiumCardShadow(theme: theme)
                )

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
            tracksStock = medication.tracksStock
            currentStock = medication.currentStock
            doseQuantity = medication.doseQuantity
            stockUnit = medication.stockUnit
        }
    }

    private func save() {
        medication.tracksStock = tracksStock
        medication.currentStock = currentStock
        medication.doseQuantity = doseQuantity
        medication.stockUnit = stockUnit
        medication.updatedAt = Date()
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

#if DEBUG
#Preview("Edit Stock") {
    let container = PreviewData.container
    let context = container.mainContext
    let medication = (try? context.fetch(FetchDescriptor<Medication>()))?.first ?? {
        fatalError("No preview medications")
    }()

    return MedicationEditStockSheet(medication: medication)
        .modelContainer(container)
        .environment(ThemeManager())
}
#endif
