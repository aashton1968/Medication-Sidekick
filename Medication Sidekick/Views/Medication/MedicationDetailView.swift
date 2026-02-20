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
    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    // MARK: - Input
    let medication: Medication
    
    // MARK: - State
    @State private var showEditBasics = false
    @State private var showEditSchedule = false
    @State private var showEditStock = false
    @State private var showEditAll = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    
    var body: some View {
        
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
                            .foregroundStyle(.secondary)

                        if let instructions = medication.instructions, !instructions.isEmpty {
                            Text(instructions)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            .background(Color(themeManager.selectedTheme.cardBackgroundColor))
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
                                .foregroundStyle(.secondary)
                        } else {
                            Text(medication.mealDisplayNames(settings: mealTimeSettings).joined(separator: ", "))
                                .foregroundStyle(.secondary)
                        }

                        Text(medication.frequency.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

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
            .background(Color(themeManager.selectedTheme.cardBackgroundColor))
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
                                .foregroundStyle(.secondary)
                                .font(.subheadline)

                            Text("\(medication.currentStock) \(medication.stockUnit.displayName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if medication.currentStock > 0 {
                            Text("~\(medication.daysOfSupply) days supply")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if medication.doseQuantity > 1 {
                            Text("\(medication.doseQuantity) \(medication.stockUnit.displayName.lowercased()) per dose")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            .background(Color(themeManager.selectedTheme.cardBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))


            Spacer()
            
        }
        .padding()
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
        
        // MARK: - Toolbar
        .toolbar {
            
            ToolbarItem(placement: .navigationBarTrailing) {
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
                        .foregroundColor(themeManager.selectedTheme.cardBackgroundColor)
                        .accessibilityLabel("More")
                }
            }
        }
        
        .toolbarBackground(Color(themeManager.selectedTheme.toolbarBackgroundColor), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        
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
                deleteMedication()
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
    private func deleteMedication() {
        modelContext.delete(medication)
        do {
            try modelContext.save()
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

        try? PreviewData.seed(into: context)

        let descriptor = FetchDescriptor<Medication>()
        let medications = try context.fetch(descriptor)
        let medication = medications.first!

        return NavigationStack {
            MedicationDetailView(medication: medication)
                .environmentObject(NavigationRouter())
                .environment(ThemeManager())
        }
        .modelContainer(container)
    } catch {
        fatalError("Failed to create model container: \(error)")
    }
}
#endif
