//
//  MealTimeEditView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-18.
//

import SwiftUI
import SwiftData

struct MealTimeEditView: View {

    enum Mode: Identifiable {
        case add
        case edit(MealTimeSetting)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let s): return s.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var nextSortOrder: Int = 0

    // MARK: - Form State
    @State private var name: String = ""
    @State private var selectedTime: Date = Calendar.current.date(
        from: DateComponents(hour: 8, minute: 0)
    ) ?? Date()
    @State private var symbolName: String = "fork.knife"

    private let symbols = [
        "fork.knife", "sunrise", "sun.max", "sun.haze",
        "moon.haze", "moon.zzz", "cup.and.saucer", "mug"
    ]

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Details") {
                    TextField("Name (e.g. Morning Snack)", text: $name)

                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Icon") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: 16
                    ) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button {
                                symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        symbolName == symbol
                                            ? Color.accentColor.opacity(0.15)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Edit Meal Time" : "New Meal Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { loadExisting() }
    }

    // MARK: - Load

    private func loadExisting() {
        guard case .edit(let setting) = mode else { return }
        name = setting.name
        symbolName = setting.symbolName
        selectedTime = Calendar.current.date(
            from: DateComponents(hour: setting.hour, minute: setting.minute)
        ) ?? Date()
    }

    // MARK: - Save

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0

        switch mode {
        case .add:
            let setting = MealTimeSetting(
                name: name.trimmingCharacters(in: .whitespaces),
                hour: hour,
                minute: minute,
                sortOrder: nextSortOrder,
                symbolName: symbolName
            )
            modelContext.insert(setting)

        case .edit(let setting):
            setting.name = name.trimmingCharacters(in: .whitespaces)
            setting.hour = hour
            setting.minute = minute
            setting.symbolName = symbolName
        }

        try? modelContext.save()
        dismiss()
    }
}

#if DEBUG
#Preview("Add Meal Time") {
    MealTimeEditView(mode: .add, nextSortOrder: 5)
        .modelContainer(PreviewData.container)
}
#endif
