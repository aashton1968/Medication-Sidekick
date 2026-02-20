//
//  MedicationListView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import SwiftUI
import SwiftData

struct MedicationListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    @EnvironmentObject var navigationRouter: NavigationRouter
    
    @Query(sort: \Medication.name)
    private var medications: [Medication]

    @State private var showingAdd = false

    var body: some View {
        List {

            if medications.isEmpty {
                ContentUnavailableView(
                    "No Medications",
                    systemImage: "pills",
                    description: Text("Tap + to add your first medication")
                )
            }

            ForEach(medications) { medication in
                MedicationRow(medication: medication)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        navigationRouter.navigate(.medication(id: medication.id))
                    }
                    .contextMenu {
                        Button {
                            navigationRouter.navigate(.medication(id: medication.id))
                        } label: {
                            Label("View Details", systemImage: "eye")
                        }
                        Divider()

                        Button(role: .destructive) {
                            deleteMedication(medication)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete(perform: delete)
        }
        
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.selectedTheme.toolbarButtonAccentColor)
                        .accessibilityLabel("Add Medication")
                }
            }
        }
        
        .toolbarBackground(Color(themeManager.selectedTheme.toolbarBackgroundColor), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        
        .sheet(isPresented: $showingAdd) {
            MedicationAddView()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let medication = medications[index]
            modelContext.delete(medication)
        }

        try? modelContext.save()
    }

    private func deleteMedication(_ medication: Medication) {
        modelContext.delete(medication)
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewData.container
    let context = container.mainContext

    let existing = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
    if existing.isEmpty {
        try? PreviewData.seed(into: context)
    }

    return MedicationListView()
        .modelContainer(container)
        .environmentObject(NavigationRouter())
        .environment(ThemeManager())
}

struct MedicationRow: View {

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    let medication: Medication

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: medication.medicationType.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(medication.name)
                    .font(.headline)

                Text(medication.dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !medication.mealsRaw.isEmpty {
                    Text(medication.mealDisplayNames(settings: mealTimeSettings).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: medication.stockLevel.symbolName)
                .foregroundStyle(stockLevelColor(medication.stockLevel))
                .font(.system(size: 14))
        }
        .padding(.vertical, 4)
    }

    private func stockLevelColor(_ level: StockLevel) -> Color {
        switch level {
        case .good:              return .green
        case .warning:           return .orange
        case .critical, .empty:  return .red
        }
    }
}
