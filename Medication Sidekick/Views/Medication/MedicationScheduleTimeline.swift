//
//  MedicationScheduleTimeline.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-03.
//
//  The "Schedule" mode of the Medicines tab: every active medication laid out
//  through the day, ordered by clock time, with the linked meal as the label.
//

import SwiftUI
import SwiftData

struct MedicationScheduleTimeline: View {

    @Environment(ThemeManager.self) private var themeManager
    @Environment(NavigationRouter.self) private var navigationRouter

    @Query(sort: \Medication.name)
    private var medications: [Medication]

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    /// One time-of-day slot (a meal) and the medications taken in it.
    private struct Slot: Identifiable {
        let key: String
        let name: String
        let time: DateComponents
        let medications: [Medication]

        var id: String { key }

        var minutesIntoDay: Int { (time.hour ?? 0) * 60 + (time.minute ?? 0) }

        var timeText: String {
            Calendar.current.date(from: time)?.formatted(date: .omitted, time: .shortened) ?? ""
        }
    }

    private var slots: [Slot] {
        let active = medications.filter { $0.isActive && !$0.mealsRaw.isEmpty }
        let settingsByKey = Dictionary(mealTimeSettings.map { ($0.key, $0) }, uniquingKeysWith: { _, latest in latest })

        // Every meal key in use, including keys with no MealTimeSetting (falls back to the
        // MealTime defaults), so a medication can never silently drop off this screen.
        let keys = Set(active.flatMap(\.mealsRaw))

        return keys.compactMap { key -> Slot? in
            let name: String
            let time: DateComponents
            if let setting = settingsByKey[key] {
                name = setting.name
                time = setting.defaultDateComponents
            } else if let meal = MealTime(rawValue: key) {
                name = meal.displayName
                time = meal.defaultDateComponents
            } else {
                return nil
            }
            let meds = active.filter { $0.mealsRaw.contains(key) }
            return Slot(key: key, name: name, time: time, medications: meds)
        }
        .sorted { $0.minutesIntoDay < $1.minutesIntoDay }
    }

    var body: some View {
        List {
            if slots.isEmpty {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.plus",
                    description: Text("You haven't created any medication schedules yet.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(slots) { slot in
                    Section {
                        ForEach(slot.medications) { medication in
                            Button {
                                navigationRouter.navigate(.medication(id: medication.id))
                            } label: {
                                ScheduleRowView(medication: medication)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("\(slot.timeText) · \(slot.name)")
                    }
                }
            }
        }
    }
}

private struct ScheduleRowView: View {

    @Environment(ThemeManager.self) private var themeManager

    let medication: Medication

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: medication.medicationType.symbolName)
                .font(.title3)
                .foregroundStyle(theme.accentPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(medication.name)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                Text(amountText)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)

                Text(daysText)
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)

                if let endDate = medication.endDate {
                    Text("Ends \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(theme.statusError)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    /// "500 mg" or "500 mg · 2 tablets" when more than one unit is taken per dose.
    private var amountText: String {
        var parts: [String] = []
        if !medication.dosage.isEmpty { parts.append(medication.dosage) }
        if medication.doseQuantity > 1 {
            parts.append("\(medication.doseQuantity) \(medication.stockUnit.displayName.lowercased())")
        }
        return parts.isEmpty ? "Dose not set" : parts.joined(separator: " · ")
    }

    private var daysText: String {
        switch medication.frequency {
        case .daily:
            return "Every day"
        case .asNeeded:
            return "As needed"
        case .everyOtherDay:
            let start = medication.startDate.formatted(.dateTime.month(.abbreviated).day())
            return "Every other day · from \(start)"
        case .specificDays:
            let weekdays = medication.scheduledWeekdays
            guard !weekdays.isEmpty else { return "Every day" }
            let symbols = Calendar.current.shortWeekdaySymbols
            // Monday-first, matching the rest of the app.
            return [2, 3, 4, 5, 6, 7, 1]
                .filter { weekdays.contains($0) }
                .map { symbols[$0 - 1] }
                .joined(separator: ", ")
        }
    }
}

#Preview("Schedule Timeline") {
    let container = PreviewData.container
    let context = container.mainContext
    if ((try? context.fetch(FetchDescriptor<Medication>())) ?? []).isEmpty {
        PreviewData.seed(into: context)
    }

    return NavPreview {
        MedicationScheduleTimeline()
    }
    .modelContainer(container)
    .environment(ThemeManager())
    .environment(NavigationRouter())
}
