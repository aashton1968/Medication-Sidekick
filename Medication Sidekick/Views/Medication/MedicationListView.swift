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
    @EnvironmentObject var navigationRouter: NavigationRouter
    
    @Query(sort: \Medication.name)
    private var medications: [Medication]

    @State private var showingAdd = false

    var body: some View {
        VStack {
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

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MedicationAddView()
            }
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

    let medication: Medication

    private var schedule: MedicationSchedule? {
        medication.schedule
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(medication.name)
                .font(.headline)

            Text(medication.dosage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let schedule {
                Text(timeString(from: schedule))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func timeString(from schedule: MedicationSchedule) -> String {
        schedule.times
            .compactMap { comp in
                if let hour = comp.hour, let minute = comp.minute {
                    let date = Calendar.current.date(
                        bySettingHour: hour,
                        minute: minute,
                        second: 0,
                        of: Date()
                    )
                    return date?.formatted(date: .omitted, time: .shortened)
                }
                return nil
            }
            .joined(separator: ", ")
    }
}
