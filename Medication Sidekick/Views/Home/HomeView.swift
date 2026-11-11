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
    /// Scroll position, read only by the background so scrolling doesn't re-render the whole screen.
    @State private var scrollTracker = ScrollTracker()

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
        .background { HomeBackground(tracker: scrollTracker) }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        // Transparent bar over the teal band drawn by HomeBackground. (A solid toolbarBackground
        // resolves the accent colour in the bar's own appearance and comes out a different blue.)
        // White text is forced so it doesn't flip to black over light content.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await refreshDoses() }
        .refreshable { await refreshDoses() }
    }

    // MARK: - Content

    private func content(now: Date) -> some View {
        let summary = HomeSummary(doses: weekDoses, now: now)
        let calendar = Self.calendar
        let today = calendar.startOfDay(for: now)
        let selectedDate = selectedDay.map { calendar.startOfDay(for: $0) } ?? today
        let doses = sortedDoses(for: selectedDate)
        // Taken doses sink below the rest, each half keeping the same time/alpha order.
        let notTakenDoses = doses.filter { $0.status != .taken }
        let takenDoses = doses.filter { $0.status == .taken }

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

                if doses.isEmpty {
                    Text("No medications scheduled for this day")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            // Two groups of cards, each ordered by due time (alpha tiebreak): doses still
            // needing action, then taken ones sunk below. DoseRow is a direct list row so
            // swipe actions work.
            if !notTakenDoses.isEmpty {
                Section {
                    ForEach(notTakenDoses) { dose in
                        DoseRow(dose: dose, mealTimeSettings: mealTimeSettings, now: now)
                    }
                } header: {
                    sectionHeader("Not Taken")
                }
            }

            if !takenDoses.isEmpty {
                Section {
                    ForEach(takenDoses) { dose in
                        DoseRow(dose: dose, mealTimeSettings: mealTimeSettings, now: now)
                    }
                } header: {
                    sectionHeader("Taken")
                }
            }
        }
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .listSectionSpacing(.compact)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollTracker.offset = offset
        }
        }
    }

    // MARK: - Helpers

    /// A section header matching the day title's look (used by `content(now:)`).
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(theme.textSecondary)
    }

    /// The day's doses ordered by when they're due, alphabetically where times tie.
    /// Taken vs. not-taken is split out separately by `content(now:)`, so this keeps a
    /// single consistent order for both groups rather than re-sorting taken doses by
    /// when they were taken.
    private func sortedDoses(for day: Date) -> [MedicationDose] {
        let calendar = Self.calendar
        return deduplicatedDoses(
            weekDoses.filter {
                $0.medication?.isActive == true && calendar.isDate($0.scheduledDate, inSameDayAs: day)
            }
        )
        .sorted { lhs, rhs in
            if lhs.scheduledDate != rhs.scheduledDate { return lhs.scheduledDate < rhs.scheduledDate }
            return medicationDoseSortsBefore(lhs, rhs)
        }
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

@Observable
private final class ScrollTracker {
    var offset: CGFloat = 0
}

/// Teal hero gradient that scrolls away with the content, plus a fixed teal band behind the
/// status bar and title so their white text stays readable once the gradient has scrolled off.
private struct HomeBackground: View {

    @Environment(ThemeManager.self) private var themeManager
    let tracker: ScrollTracker

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    var body: some View {
        GeometryReader { geometry in
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
                .offset(y: -max(tracker.offset, 0))

                theme.accentPrimary
                    .frame(height: geometry.safeAreaInsets.top)
            }
            .ignoresSafeArea()
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
