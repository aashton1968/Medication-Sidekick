//
//  TodayView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

// TodayView.swift

import SwiftUI
import SwiftData

struct TodayView: View {

    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    
    @Query private var events: [MedicationDoseEvent]

    private var nextEvent: MedicationDoseEvent? {
        todayEvents.first { $0.status == .scheduled }
    }
    private var todayEvents: [MedicationDoseEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        return events
            .filter {
                $0.dose.scheduledDate >= start &&
                $0.dose.scheduledDate < end
            }
            .sorted {
                $0.dose.scheduledDate < $1.dose.scheduledDate
            }
    }

    private func section(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<15:
            return "Morning"
        default:
            return "Evening"
        }
    }

    private var groupedEvents: [String: [MedicationDoseEvent]] {
        Dictionary(grouping: todayEvents) { event in
            section(for: event.dose.scheduledDate)
        }
    }

    private var sortedSectionKeys: [String] {
        ["Morning", "Evening"].filter { groupedEvents[$0] != nil }
    }

   var body: some View {
       VStack {
           List {

               if let nextEvent {
                   NextDoseCard(event: nextEvent)
                       .listRowInsets(EdgeInsets())
                       .listRowBackground(Color.clear)
               }

               if todayEvents.isEmpty {
                   Text("No medications scheduled today")
                       .foregroundStyle(.secondary)
               }

               ForEach(sortedSectionKeys, id: \.self) { key in
                   Section(header: Text(key)) {
                       ForEach(groupedEvents[key] ?? []) { event in
                           DoseRow(event: event)
                       }
                   }
               }
           }
           
           .navigationTitle("Today")
           .navigationBarTitleDisplayMode(.inline)
           
           // Context menu
           .toolbar {
               ToolbarItem(placement: .navigationBarTrailing) {
                   Menu {
                       /*
                       Button {
                           showAbout = true
                       } label: {
                           Label("About", systemImage: "info.circle")
                       }
                        */
                       
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
    
    // Initialise the background Store
    let themeManager = ThemeManager()
    let container = PreviewData.container
    
    // 4️⃣ Return the view with modelContainer attached
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
    let event: MedicationDoseEvent

    private var medication: Medication? {
        event.dose.schedule.medication
    }

    private var iconName: String {
        switch event.status {
        case .taken: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .scheduled: return "circle"
        }
    }

    private var iconColor: Color {
        switch event.status {
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

                Text(medication?.name ?? "Medication")
                    .font(.headline)

                Text(medication?.dosage ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(event.dose.scheduledDate, style: .time)
                .font(.subheadline)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle()
        }
        
        .opacity(event.status == .taken ? 0.5 : 1.0)
        .animation(.easeInOut, value: event.status)
    }

    private func toggle() {
        if event.status == .taken {
            event.status = .scheduled
            event.takenTime = nil
        } else {
            event.status = .taken
            event.takenTime = Date()
        }

        event.updatedAt = Date()
    }
}
