//
//  HomeView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2024-10-31.
//

import SwiftUI
import SwiftData
import os.log

/// Content of the Home tab: hero, week card (also the day picker) and the selected day's doses.
/// Lives inside the tab's NavigationStack (see MainTabView).
struct HomeView: View {

    @Environment(ThemeManager.self) var themeManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MealTimeSetting.sortOrder) private var mealTimeSettings: [MealTimeSetting]

    /// All doses scheduled this week (Monday start, matching the rest of the app).
    @Query private var weekDoses: [MedicationDose]

    /// `nil` means "today", so the selection follows midnight rollover on its own.
    @State private var selectedDay: Date?
    @State private var adherenceService = MedicationAdherenceService()

    init() {
        let calendar = Self.calendar
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        _weekDoses = Query(filter: #Predicate<MedicationDose> {
            $0.scheduledDate >= start && $0.scheduledDate < end
        })
    }

    private static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private static let dosesAnchor = "dosesTitle"

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    var body: some View {
        // Re-evaluate every minute so "due now" / "missed" stay current.
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                theme.bgBase
                // Solid behind the whole hero so its white text stays readable, then fades under the card.
                LinearGradient(
                    stops: [
                        .init(color: theme.accentPrimary, location: 0),
                        .init(color: theme.accentPrimary, location: 0.68),
                        .init(color: theme.accentPrimary.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 520)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        // Let the hero gradient run up behind the bar instead of a separate tinted band.
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await refreshDoses() }
        .refreshable { await refreshDoses() }
    }

    // MARK: - Content

    private func content(now: Date) -> some View {
        let summary = HomeSummary(doses: weekDoses, now: now)
        let calendar = Self.calendar
        let today = calendar.startOfDay(for: now)
        let selectedDate = selectedDay.map { calendar.startOfDay(for: $0) } ?? today
        let groups = slotGroups(for: selectedDate)

        return ScrollViewReader { proxy in
        List {
            Section {
                HomeHeroView(summary: summary, date: now)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                HomeWeekCard(summary: summary, selectedDate: selectedDate) { day in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDay = calendar.isDate(day, inSameDayAs: today) ? nil : day
                    }
                    // Jump to the day's doses so the change is visible, not hidden below the card.
                    Task { @MainActor in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(Self.dosesAnchor, anchor: .top)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Day title (and empty state). A plain row, not a header, so it scrolls with the list.
            Section {
                Text(dayTitle(for: selectedDate, today: today))
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(theme.textSecondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
                    .id(Self.dosesAnchor)

                if groups.isEmpty {
                    Text("No medications scheduled for this day")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            // One section per meal, with DoseRow as a direct list row so swipe actions work.
            ForEach(groups) { group in
                Section {
                    ForEach(group.doses) { dose in
                        DoseRow(dose: dose, mealTimeSettings: mealTimeSettings)
                    }
                } header: {
                    Text(group.time.isEmpty ? group.name : "\(group.name) · \(group.time)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .listSectionSpacing(.compact)
        }
    }

    // MARK: - Helpers

    private func slotGroups(for day: Date) -> [TimeSlotGroup] {
        let calendar = Self.calendar
        let dayDoses = deduplicatedDoses(
            weekDoses.filter {
                $0.medication?.isActive == true && calendar.isDate($0.scheduledDate, inSameDayAs: day)
            }
        )
        return makeSlotGroups(from: dayDoses, settings: mealTimeSettings)
    }

    private func dayTitle(for day: Date, today: Date) -> String {
        let calendar = Self.calendar
        if calendar.isDate(day, inSameDayAs: today) { return "Today's doses" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday's doses"
        }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    @MainActor
    private func refreshDoses() async {
        do {
            try MedicationDoseGenerator.refreshAllDoses(modelContext: modelContext)
            _ = try adherenceService.syncMissedStatuses(modelContext: modelContext)
        } catch {
            os_log(.error, "Failed to refresh doses: %{public}@", error.localizedDescription)
        }
    }
}

#if DEBUG
#Preview {
    NavPreview {
        HomeView()
    }
    .modelContainer(PreviewData.container)
    .environment(NavigationRouter())
    .environment(SubscriptionService())
    .environment(ThemeManager())
}
#endif
