//
//  MedicationDetailView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import SwiftUI
import SwiftData

struct MedicationDetailView: View {
    
    // MARK: - Dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) var navigationRouter
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    // MARK: - Input
    let medicationID: UUID
    
    @Query private var medications: [Medication]
    
    // MARK: - State
    @State private var showEditBasics = false
    @State private var showEditSchedule = false
    @State private var showEditStock = false
    @State private var showEditAll = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    
    init(medicationID: UUID) {
        self.medicationID = medicationID
        _medications = Query(filter: #Predicate<Medication> { $0.id == medicationID })
    }
    
    var body: some View {
        Group {
            if let medication = medications.first {
                content(for: medication)
            } else {
                ContentUnavailableView(
                    "Medication Not Found",
                    systemImage: "pills",
                    description: Text("This medication may have been removed or merged.")
                )
            }
        }
    }
    
    @ViewBuilder
    private func content(for medication: Medication) -> some View {
        VStack(spacing: 16) {
            
            // MARK: - Header Card
            Button {
                showEditBasics = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: medication.medicationType.symbolName)
                        .font(.title2)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(medication.name)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text(medication.dosage)
                            .font(.subheadline)
                            .foregroundStyle(themeManager.selectedTheme.textSecondary)

                        if let instructions = medication.instructions, !instructions.isEmpty {
                            Text(instructions)
                                .font(.caption)
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(themeManager.selectedTheme.surfaceBase))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            
            // MARK: - Schedule Section
            Button {
                showEditSchedule = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schedule")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if medication.mealsRaw.isEmpty {
                            Text("No meals set")
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        } else {
                            Text(medication.mealDisplayNames(settings: mealTimeSettings).joined(separator: ", "))
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        }

                        Text(medication.frequency.displayName)
                            .font(.subheadline)
                            .foregroundStyle(themeManager.selectedTheme.textSecondary)

                        if !medication.isActive {
                            Text("Inactive")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(themeManager.selectedTheme.surfaceBase))
            .clipShape(RoundedRectangle(cornerRadius: 12))


            // MARK: - Stock Section
            Button {
                showEditStock = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stock")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: medication.stockLevel.symbolName)
                                .foregroundStyle(stockLevelColor(medication.stockLevel))

                            Text(medication.stockLevel.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(stockLevelColor(medication.stockLevel))
                        }

                        HStack(spacing: 6) {
                            Image(systemName: medication.medicationType.symbolName)
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                                .font(.subheadline)

                            Text("\(medication.currentStock) \(medication.stockUnit.displayName)")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        }

                        if medication.currentStock > 0 {
                            Text("~\(medication.daysOfSupply) days supply")
                                .font(.caption)
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        }

                        if medication.doseQuantity > 1 {
                            Text("\(medication.doseQuantity) \(medication.stockUnit.displayName.lowercased()) per dose")
                                .font(.caption)
                                .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(themeManager.selectedTheme.surfaceBase))
            .clipShape(RoundedRectangle(cornerRadius: 12))


            Spacer()
            
        }
        .padding()
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
        
        // MARK: - Toolbar
        .toolbar {
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {

                    Button {
                        showEditAll = true
                    } label: {
                        Label("Edit All", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .bold))
                        .accessibilityLabel("More")
                }
            }
        }
        
        
        // MARK: - Edit Sheets
        .sheet(isPresented: $showEditBasics) {
            MedicationEditBasicsSheet(medication: medication)
        }
        .sheet(isPresented: $showEditSchedule) {
            MedicationEditScheduleSheet(medication: medication)
        }
        .sheet(isPresented: $showEditStock) {
            MedicationEditStockSheet(medication: medication)
        }
        .sheet(isPresented: $showEditAll) {
            MedicationEditView(medication: medication)
        }
        
        // MARK: - Delete Confirmation
        .alert("Delete Medication", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteMedication(medication)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this medication?")
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            if let deleteError {
                Text(deleteError)
            }
        }
    }

    // MARK: - Helpers
    private func stockLevelColor(_ level: StockLevel) -> Color {
        switch level {
        case .good:              return .green
        case .warning:           return .orange
        case .critical, .empty:  return .red
        }
    }

    // MARK: - Actions
    @MainActor
    private func deleteMedication(_ medication: Medication) {
        modelContext.delete(medication)
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .medicationDidChange, object: nil)
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}


#if DEBUG
#Preview("Medication Detail") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Medication.self, configurations: config)
        let context = container.mainContext

        PreviewData.seed(into: context)

        let descriptor = FetchDescriptor<Medication>()
        let medications = try context.fetch(descriptor)
        let medication = medications.first!

        return NavigationStack {
            MedicationDetailView(medicationID: medication.id)
                .environment(NavigationRouter())
                .environment(ThemeManager())
        }
        .modelContainer(container)
    } catch {
        fatalError("Failed to create model container: \(error)")
    }
}
#endif
