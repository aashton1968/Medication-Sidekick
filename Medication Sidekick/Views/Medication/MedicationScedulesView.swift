//
//  MedicationSchedulesView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-03.
//

import SwiftUI
import SwiftData

struct MedicationSchedulesView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MedicationSchedule.startDate)
    private var schedules: [MedicationSchedule]

    var body: some View {
        List {
            if schedules.isEmpty {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.plus",
                    description: Text("You haven’t created any medication schedules yet.")
                )
            } else {
                ForEach(schedules) { schedule in
                    ScheduleRowView(schedule: schedule)
                }
            }
        }
        .navigationTitle("Schedules")
    }
}

private struct ScheduleRowView: View {

    let schedule: MedicationSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Medication name (or fallback)
            Text(schedule.medication?.name ?? "Unknown Medication")
                .font(.headline)

            // Frequency
            Text(schedule.frequency.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Times
            Text(timesSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Active / ended
            if let endDate = schedule.endDate {
                Text("Ended \(endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }

    private var timesSummary: String {
        let times = schedule.times
            .sorted { ($0.hour ?? 0) < ($1.hour ?? 0) }
            .compactMap { components -> String? in
                guard let hour = components.hour,
                      let minute = components.minute else { return nil }

                return String(format: "%02d:%02d", hour, minute)
            }

        return times.isEmpty
            ? "No times set"
            : times.joined(separator: ", ")
    }
}


#Preview("Schedules View") {
    
    // Initialise the background Store
    let themeManager = ThemeManager()
    let container = PreviewData.container
    
    // 4️⃣ Return the view with modelContainer attached
    return NavPreview {
        MedicationSchedulesView()
    }
    .modelContainer(container)
    .environment(themeManager)
    .environmentObject(NavigationRouter())
}
