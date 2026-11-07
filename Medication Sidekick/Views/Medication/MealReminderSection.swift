//
//  MealReminderSection.swift
//  Medication Sidekick
//
//  Shared "Meals & Reminders" form section used by the Add, Edit and Edit Schedule screens.
//  Each ticked meal gets a reminder time that defaults to the meal's own time and can be
//  changed for this medication only.
//

import SwiftUI
import SwiftData

struct MealReminderSection: View {

    @Environment(ThemeManager.self) private var themeManager

    let mealTimeSettings: [MealTimeSetting]
    @Binding var selectedMealKeys: Set<String>
    /// Reminder times the user has changed, keyed by meal key. A meal missing from here follows its meal time.
    @Binding var timeOverrides: [String: DateComponents]

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    var body: some View {
        Section {
            ForEach(mealTimeSettings) { setting in
                mealRow(setting)

                if selectedMealKeys.contains(setting.key) {
                    reminderRow(setting)
                }
            }
        } header: {
            Text("Meal Type & Reminder")
        } footer: {
            Text("Each reminder follows its meal's time from Meal Times. Change a time to set your own for this medication.")
        }
    }

    // MARK: - Rows

    private func mealRow(_ setting: MealTimeSetting) -> some View {
        let isSelected = selectedMealKeys.contains(setting.key)

        return Button {
            toggle(setting.key)
        } label: {
            HStack {
                Image(systemName: setting.symbolName)
                    .frame(width: 24)
                    .foregroundStyle(.tint)

                Text(setting.name)
                    .foregroundStyle(.primary)

                Spacer()

                // Selected meals show their editable reminder row underneath instead.
                if !isSelected {
                    Text(setting.displayTime)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(theme.textSecondary))
            }
        }
    }

    private func reminderRow(_ setting: MealTimeSetting) -> some View {
        let isCustom = timeOverrides[setting.key] != nil

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminder")
                    .font(.subheadline)
                Text(isCustom ? "Custom time" : "Follows \(setting.name)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            if isCustom {
                Button("Reset") {
                    timeOverrides[setting.key] = nil
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }

            DatePicker(
                "Reminder time",
                selection: timeBinding(for: setting),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
        .padding(.leading, 36) // lines up under the meal name
    }

    // MARK: - Helpers

    private func toggle(_ key: String) {
        if selectedMealKeys.contains(key) {
            selectedMealKeys.remove(key)
            timeOverrides[key] = nil
        } else {
            selectedMealKeys.insert(key)
        }
    }

    /// Shows the override if there is one, otherwise the meal's time. Setting the picker back
    /// to exactly the meal's time clears the override, so it goes back to following the meal.
    private func timeBinding(for setting: MealTimeSetting) -> Binding<Date> {
        Binding(
            get: {
                let time = timeOverrides[setting.key] ?? setting.defaultDateComponents
                return Calendar.current.date(from: time) ?? Date()
            },
            set: { newValue in
                let time = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                if time.hour == setting.hour && time.minute == setting.minute {
                    timeOverrides[setting.key] = nil
                } else {
                    timeOverrides[setting.key] = DateComponents(hour: time.hour, minute: time.minute)
                }
            }
        )
    }
}

#if DEBUG
private struct MealReminderSectionPreview: View {
    @Query(sort: \MealTimeSetting.sortOrder) private var settings: [MealTimeSetting]
    @State private var selected: Set<String> = ["breakfast", "dinner"]
    @State private var overrides: [String: DateComponents] = ["dinner": DateComponents(hour: 19, minute: 15)]

    var body: some View {
        Form {
            MealReminderSection(
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
    return MealReminderSectionPreview()
        .modelContainer(container)
        .environment(ThemeManager())
}
#endif
