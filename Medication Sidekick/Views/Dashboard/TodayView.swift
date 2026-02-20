//
//  TodayView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

import SwiftUI
import SwiftData

// MARK: - Slot Grouping

struct TimeSlotGroup: Identifiable {
    let key: String
    let name: String
    let time: String
    let symbol: String
    let sortOrder: Int
    let doses: [MedicationDose]

    var id: String { key }

    var isComplete: Bool {
        doses.allSatisfy { $0.status != .scheduled }
    }
}

// MARK: - Today View

struct TodayView: View {

    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    
    @Query private var doses: [MedicationDose]
    @Query(sort: \MealTimeSetting.sortOrder) private var mealTimeSettings: [MealTimeSetting]

    private var todayDoses: [MedicationDose] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        return doses
            .filter {
                $0.scheduledDate >= start &&
                $0.scheduledDate < end
            }
            .sorted {
                $0.scheduledDate < $1.scheduledDate
            }
    }

    private var slotGroups: [TimeSlotGroup] {
        let grouped = Dictionary(grouping: todayDoses) { $0.mealTimeRaw }

        return grouped.map { key, slotDoses in
            let setting = mealTimeSettings.first { $0.key == key }
            return TimeSlotGroup(
                key: key,
                name: setting?.name ?? (MealTime(rawValue: key)?.displayName ?? key),
                time: setting?.displayTime ?? "",
                symbol: setting?.symbolName ?? "fork.knife",
                sortOrder: setting?.sortOrder ?? 999,
                doses: slotDoses.sorted { $0.scheduledDate < $1.scheduledDate }
            )
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var nextSlot: TimeSlotGroup? {
        slotGroups.first { !$0.isComplete }
    }

   var body: some View {
       VStack {
           List {

               if let nextSlot {
                   Section {
                       NextDoseCard(
                           doses: nextSlot.doses,
                           slotName: nextSlot.name,
                           slotTime: nextSlot.time,
                           slotSymbol: nextSlot.symbol
                       )
                   }
                   .listRowInsets(EdgeInsets())
                   .listRowBackground(Color.clear)
                   .listRowSeparator(.hidden)
               } else if !todayDoses.isEmpty {
                   Section {
                       HStack(spacing: 12) {
                           Image(systemName: "checkmark.seal.fill")
                               .foregroundStyle(.green)
                               .font(.title2)
                           Text("All done for today!")
                               .font(.headline)
                       }
                       .frame(maxWidth: .infinity)
                       .padding(.vertical, 8)
                   }
                   .listRowBackground(Color.clear)
               }

               if todayDoses.isEmpty {
                   Text("No medications scheduled today")
                       .foregroundStyle(.secondary)
               }

               ForEach(slotGroups) { group in
                   Section(header: Text(group.name)) {
                       ForEach(group.doses) { dose in
                           DoseRow(dose: dose)
                       }
                   }
               }
           }
           
           .navigationTitle("Today")
           .navigationBarTitleDisplayMode(.inline)
           
           .toolbar {
               ToolbarItem(placement: .navigationBarTrailing) {
                   Menu {
                   } label: {
                       Image(systemName: "ellipsis.circle")
                           .font(.system(size: 20, weight: .bold))
                           .foregroundColor(themeManager.selectedTheme.toolbarButtonAccentColor)
                           .accessibilityLabel("More")
                   }
               }
           }
       
           .toolbarBackground(Color(themeManager.selectedTheme.toolbarBackgroundColor), for: .navigationBar)
           .toolbarBackground(.visible, for: .navigationBar)
       }
   }
}


#Preview("Today View") {
    
    let themeManager = ThemeManager()
    let container = PreviewData.container
    
    return NavPreview {
        TodayView()
    }
    .modelContainer(container)
    .environment(themeManager)
    .environmentObject(NavigationRouter())
}


// MARK: - Dose Row

struct DoseRow: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    let dose: MedicationDose

    private var iconName: String {
        switch dose.status {
        case .taken: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .scheduled: return "circle"
        }
    }

    private var iconColor: Color {
        switch dose.status {
        case .taken:
            return .green
        case .missed:
            return .red
        case .skipped:
            return .orange
        case .scheduled:
            return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading) {

                Text(dose.medication?.name ?? "Medication")
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(dose.medication?.dosage ?? "")
                    Text("·")
                    Text(dose.mealDisplayName(settings: mealTimeSettings))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(dose.scheduledDate, style: .time)
                .font(.subheadline)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle()
        }
        
        .opacity(dose.status == .taken ? 0.5 : 1.0)
        .animation(.easeInOut, value: dose.status)
    }

    private func toggle() {
        if dose.status == .taken {
            dose.undoTaken()
        } else {
            dose.markAsTaken()
        }
    }
}
