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
    @EnvironmentObject var navigationRouter: NavigationRouter
    
    // MARK: - Form State
    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var instructions: String = ""

    @State private var times: [Date] = [
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    ]

    // MARK: - Validation
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dosage.trimmingCharacters(in: .whitespaces).isEmpty &&
        !times.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Medication Info
                Section("Medication") {
                    TextField("Name", text: $name)
                    TextField("Dosage (e.g. 500 mg)", text: $dosage)
                    TextField("Instructions", text: $instructions)
                }

                // MARK: - Times
                Section("Times") {

                    ForEach(times.indices, id: \.self) { index in
                        DatePicker(
                            "Time \(index + 1)",
                            selection: $times[index],
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Button {
                        addTime()
                    } label: {
                        Label("Add Time", systemImage: "plus")
                    }

                    if times.count > 1 {
                        Button(role: .destructive) {
                            removeLastTime()
                        } label: {
                            Label("Remove Time", systemImage: "minus")
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
        }
    }
    // MARK: - Save
    private func save() {

        let medication = Medication(
            name: name,
            dosage: dosage,
            instructions: instructions.isEmpty ? nil : instructions
        )

        modelContext.insert(medication)

        let components = times.map {
            Calendar.current.dateComponents([.hour, .minute], from: $0)
        }

        let schedule = MedicationSchedule(
            frequency: .daily,
            times: components,
            startDate: Date()
        )

        schedule.medication = medication

        modelContext.insert(schedule)

        try? modelContext.save()

        dismiss()
    }

    // MARK: - Helpers
    private func addTime() {
        times.append(Date())
    }

    private func removeLastTime() {
        guard times.count > 1 else { return }
        times.removeLast()
    }
}

#Preview("Medication Add (Sheet)") {
    MedicationAddView()
        .modelContainer(PreviewData.container)
}
