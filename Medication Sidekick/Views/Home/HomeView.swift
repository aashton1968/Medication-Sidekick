//
//  HomeView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2024-10-31.
//

import SwiftUI
import SwiftData

/// Content of the Today tab. Lives inside the tab's NavigationStack (see MainTabView).
struct HomeView: View {

    @Environment(ThemeManager.self) var themeManager

    /// All doses scheduled this week (Monday start, matching the rest of the app).
    @Query private var weekDoses: [MedicationDose]

    init() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        _weekDoses = Query(filter: #Predicate<MedicationDose> {
            $0.scheduledDate >= start && $0.scheduledDate < end
        })
    }

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    var body: some View {
        // Re-evaluate every minute so "due now" / "missed" stay current.
        TimelineView(.everyMinute) { context in
            let summary = HomeSummary(doses: weekDoses, now: context.date)

            ScrollView {
                VStack(spacing: 24) {
                    HomeHeroView(summary: summary, date: context.date)
                        .padding(.horizontal, 20)

                    HomeWeekCard(summary: summary)
                        .padding(.horizontal, 16)

                    // Existing dose cards (with Taken buttons) stay until the floating pill
                    // and the folded-in dose list replace them.
                    TodaySnapshotSection(openTodayButtonTitle: nil, showsDailyStatus: false)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                theme.bgBase
                LinearGradient(
                    colors: [theme.accentPrimary, theme.accentPrimary.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 460)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        // Let the hero gradient run up behind the bar instead of a separate tinted band.
        .toolbarBackground(.hidden, for: .navigationBar)
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
