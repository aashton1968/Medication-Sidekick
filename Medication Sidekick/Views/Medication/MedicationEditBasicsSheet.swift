//
//  MedicationEditBasicsSheet.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-19.
//

import SwiftUI
import SwiftData

struct MedicationEditBasicsSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let medication: Medication

    // MARK: - Form State
    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var instructions: String = ""
    @State private var medicationType: MedicationType = .tablet

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dosage.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        name != medication.name ||
        dosage != medication.dosage ||
        instructions != (medication.instructions ?? "") ||
        medicationType != medication.medicationType
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
            }
            .navigationTitle("Edit Basics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || !hasChanges)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            name = medication.name
            dosage = medication.dosage
            instructions = medication.instructions ?? ""
            medicationType = medication.medicationType
        }
    }

    private func save() {
        medication.name = name
        medication.dosage = dosage
        medication.instructions = instructions.isEmpty ? nil : instructions
        medication.medicationType = medicationType
        medication.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

#if DEBUG
#Preview("Edit Basics") {
    let container = PreviewData.container
    let context = container.mainContext
    let medication = (try? context.fetch(FetchDescriptor<Medication>()))?.first ?? {
        fatalError("No preview medications")
    }()

    return MedicationEditBasicsSheet(medication: medication)
        .modelContainer(container)
}
#endif
