//
//  DoseTimesSection.swift
//  Medication Sidekick
//
//  Shared "Dose Times" form section used by the Add, Edit and Edit Schedule screens.
//  A medication has a list of dose times. Each one has a selectable meal type and an editable
//  time. The time defaults to the chosen meal's time (and keeps following it) until you change it.
//
//  Storage is unchanged: `selectedMealKeys` is the set of meal types in use and `timeOverrides`
//  holds only the times that differ from their meal's time. That means one dose per meal type.
//

import SwiftUI
import SwiftData

struct DoseTimesSection: View {

    @Environment(ThemeManager.self) private var themeManager

    let mealTimeSettings: [MealTimeSetting]
    @Binding var selectedMealKeys: Set<String>
    /// Times the user has changed, keyed by meal key. A meal missing from here follows its meal time.
    @Binding var timeOverrides: [String: DateComponents]

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    /// One dose time: a meal type and the time it is due.
    private struct Entry: Identifiable {
        let setting: MealTimeSetting
        let time: DateComponents
        var id: String { setting.key }
        var minutes: Int { (time.hour ?? 0) * 60 + (time.minute ?? 0) }
    }

    /// Entries in time order.
    private var entries: [Entry] {
        mealTimeSettings
            .filter { selectedMealKeys.contains($0.key) }
            .map { Entry(setting: $0, time: timeOverrides[$0.key] ?? $0.defaultDateComponents) }
            .sorted { $0.minutes < $1.minutes }
    }

    private var hasUnusedMeal: Bool {
        mealTimeSettings.contains { !selectedMealKeys.contains($0.key) }
    }

    var body: some View {
        Section {
            ForEach(entries) { entry in
                row(for: entry)
            }

            if entries.isEmpty {
                Text("Add at least one dose time.")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }

            Button {
                addEntry()
            } label: {
                Label("Add Dose Time", systemImage: "plus.circle.fill")
            }
            .disabled(!hasUnusedMeal)
        } header: {
            Text("Dose Times")
        } footer: {
            Text("Pick a time of day for each dose. The time follows that time of day's setting in Times of Day until you change it here.")
        }
    }

    // MARK: - Row

    private func row(for entry: Entry) -> some View {
        let isCustom = timeOverrides[entry.setting.key] != nil

        return HStack(spacing: 10) {
            Button {
                remove(entry)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(entry.setting.name) dose")

            VStack(alignment: .leading, spacing: 2) {
                Picker("Time of day", selection: mealBinding(for: entry)) {
                    ForEach(availableMeals(for: entry)) { setting in
                        Label(setting.name, systemImage: setting.symbolName).tag(setting.key)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()

                HStack(spacing: 8) {
                    Text(isCustom ? "Custom time" : "Follows \(entry.setting.name)")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    if isCustom {
                        Button("Reset") {
                            timeOverrides[entry.setting.key] = nil
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }

            Spacer(minLength: 4)

            DatePicker(
                "\(entry.setting.name) time",
                selection: timeBinding(for: entry),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    // MARK: - Actions

    private func addEntry() {
        guard let next = mealTimeSettings.first(where: { !selectedMealKeys.contains($0.key) }) else { return }
        selectedMealKeys.insert(next.key)
    }

    private func remove(_ entry: Entry) {
        selectedMealKeys.remove(entry.setting.key)
        timeOverrides[entry.setting.key] = nil
    }

    /// Meals this row can switch to: its own, plus any not already used by another dose.
    private func availableMeals(for entry: Entry) -> [MealTimeSetting] {
        mealTimeSettings.filter { $0.key == entry.setting.key || !selectedMealKeys.contains($0.key) }
    }

    /// Changing the meal type keeps a custom time you set, but a time that was just following
    /// the old meal switches to following the new one.
    private func mealBinding(for entry: Entry) -> Binding<String> {
        Binding(
            get: { entry.setting.key },
            set: { newKey in
                guard newKey != entry.setting.key,
                      let newSetting = mealTimeSettings.first(where: { $0.key == newKey }) else { return }

                let customTime = timeOverrides[entry.setting.key]
                selectedMealKeys.remove(entry.setting.key)
                timeOverrides[entry.setting.key] = nil
                selectedMealKeys.insert(newKey)

                if let customTime,
                   !(customTime.hour == newSetting.hour && customTime.minute == newSetting.minute) {
                    timeOverrides[newKey] = customTime
                }
            }
        )
    }

    /// Setting the time back to exactly the meal's time clears the override, so the dose
    /// goes back to following the meal.
    private func timeBinding(for entry: Entry) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: entry.time) ?? Date() },
            set: { newValue in
                let time = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                if time.hour == entry.setting.hour && time.minute == entry.setting.minute {
                    timeOverrides[entry.setting.key] = nil
                } else {
                    timeOverrides[entry.setting.key] = DateComponents(hour: time.hour, minute: time.minute)
                }
            }
        )
    }
}

#if DEBUG
private struct DoseTimesSectionPreview: View {
    @Query(sort: \MealTimeSetting.sortOrder) private var settings: [MealTimeSetting]
    @State private var selected: Set<String> = ["breakfast", "dinner"]
    @State private var overrides: [String: DateComponents] = ["dinner": DateComponents(hour: 19, minute: 15)]

    var body: some View {
        Form {
            DoseTimesSection(
                mealTimeSettings: settings,
                selectedMealKeys: $selected,
                timeOverrides: $overrides
            )
        }
    }
}

#Preview {
    let container = PreviewData.container
    if ((try? container.mainContext.fetch(FetchDescriptor<MealTimeSetting>())) ?? []).isEmpty {
        PreviewData.seed(into: container.mainContext)
    }
    return DoseTimesSectionPreview()
        .modelContainer(container)
        .environment(ThemeManager())
}
#endif
