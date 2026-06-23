//
//  WeeklyCompletionChartView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-21.
//

import SwiftUI
import SwiftData
import Charts
import os.log

// MARK: - Chart Data

struct DoseStatusSlice: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let color: Color
}

private struct PieSliceStyle {
    let angularInset: CGFloat
    let cornerRadius: CGFloat
}

private enum WeeklyChartMode: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case daily = "Daily"

    var id: String { rawValue }
}

private struct DailyChartSnapshot: Identifiable {
    let date: Date
    let summary: ChartStatusSummary

    var id: Date { date }
}

private struct ChartStatusSummary {
    let taken: Int
    let missed: Int
    let skipped: Int
    let pending: Int

    var total: Int {
        taken + missed + skipped + pending
    }

    var completionPercent: Int {
        guard total > 0 else { return 0 }
        let ratio = Double(taken) / Double(total)
        let percent = round(ratio * 100)
        return percent.safeInt
    }
}

// MARK: - Weekly Completion Chart

struct WeeklyCompletionChartView: View {

    @Query private var doses: [MedicationDose]
    @Environment(ThemeManager.self) private var themeManager
    @State private var chartMode: WeeklyChartMode = .summary
    private static let chartSafetyLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick",
        category: "ChartSafety"
    )

    @State private var weekStart: Date = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? cal.startOfDay(for: Date())
    }()

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    private var weekDoses: [MedicationDose] {
        let start = weekStart
        let end = weekEnd
        return doses.filter {
            $0.scheduledDate >= start &&
            $0.scheduledDate < end &&
            $0.medication?.isActive == true
        }
    }

    private var weeklySummary: ChartStatusSummary {
        let range = DateInterval(start: weekStart, end: weekEnd)
        return summarizeFullRange(doses: weekDoses, in: range, now: Date())
    }

    private var slices: [DoseStatusSlice] {
        slices(for: weeklySummary)
    }

    private var completionPercentage: Int {
        weeklySummary.completionPercent
    }

    private static let weekRangeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var weekRangeLabel: String {
        let start = Self.weekRangeDateFormatter.string(from: weekStart)
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let end = Self.weekRangeDateFormatter.string(from: endOfWeek)
        return "\(start) – \(end)"
    }

    private var dailySnapshots: [DailyChartSnapshot] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let dayRange = DateInterval(start: day, end: nextDay)
            let dayDoses = weekDoses.filter { dayRange.contains($0.scheduledDate) }
            let daySummary = summarizeFullRange(doses: dayDoses, in: dayRange, now: now)
            return DailyChartSnapshot(date: day, summary: daySummary)
        }
    }

    private var showingDailyCharts: Bool {
        chartMode == .daily
    }

    private var flipRotation: Double {
        showingDailyCharts ? 180 : 0
    }

    var body: some View {
        if weekDoses.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No doses scheduled this week yet")
                .font(.subheadline)
                .foregroundStyle(themeManager.selectedTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Chart

    private var chartContent: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                Text(weekRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)

                Spacer()

                Picker("Chart Mode", selection: $chartMode) {
                    ForEach(WeeklyChartMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            ZStack {
                summaryChart
                    .opacity(showingDailyCharts ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(flipRotation),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.6
                    )

                dailyCharts
                    .opacity(showingDailyCharts ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(flipRotation + 180),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.6
                    )
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.85), value: chartMode)
            legend
        }
    }

    private var summaryChart: some View {
        let summarySliceStyle = pieSliceStyle(for: slices, defaultInset: 1.5, defaultCornerRadius: 4)
        return Chart(slices) { slice in
            SectorMark(
                angle: .value("Count", slice.count),
                innerRadius: .ratio(0.62),
                angularInset: summarySliceStyle.angularInset
            )
            .foregroundStyle(slice.color)
            .clipShape(.rect(cornerRadius: summarySliceStyle.cornerRadius))
        }
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text("\(completionPercentage)%")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("complete")
                    .font(.caption)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)
            }
        }
        .frame(height: 280)
    }

    private var dailyCharts: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 104), spacing: 12)],
            spacing: 12
        ) {
            ForEach(dailySnapshots) { snapshot in
                dayChartCard(snapshot: snapshot)
            }
        }
    }

    @ViewBuilder
    private func dayChartCard(snapshot: DailyChartSnapshot) -> some View {
        let daySlices = slices(for: snapshot.summary)
        let daySliceStyle = pieSliceStyle(for: daySlices, defaultInset: 1.2, defaultCornerRadius: 3)
        VStack(spacing: 8) {
            Text(snapshot.date, format: .dateTime.weekday(.abbreviated))
                .font(.caption.weight(.semibold))
            Text(snapshot.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(themeManager.selectedTheme.textSecondary)

            if daySlices.isEmpty {
                Image(systemName: "minus.circle")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                    .frame(height: 72)
            } else {
                Chart(daySlices) { slice in
                    SectorMark(
                        angle: .value("Count", slice.count),
                        innerRadius: .ratio(0.62),
                        angularInset: daySliceStyle.angularInset
                    )
                    .foregroundStyle(slice.color)
                    .clipShape(.rect(cornerRadius: daySliceStyle.cornerRadius))
                }
                .chartBackground { _ in
                    Text("\(snapshot.summary.completionPercent)%")
                        .font(.caption.weight(.bold))
                }
                .frame(height: 72)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(slices) { slice in
                HStack(spacing: 5) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 8, height: 8)
                    Text("\(slice.label) (\(slice.count))")
                        .font(.caption)
                        .foregroundStyle(themeManager.selectedTheme.textSecondary)
                }
            }
        }
    }

    private func slices(for summary: ChartStatusSummary) -> [DoseStatusSlice] {
        [
            DoseStatusSlice(label: "Taken", count: summary.taken, color: .green),
            DoseStatusSlice(label: "Missed", count: summary.missed, color: .red),
            DoseStatusSlice(label: "Skipped", count: summary.skipped, color: .orange),
            DoseStatusSlice(label: "Pending", count: summary.pending, color: Color(.systemGray4))
        ]
        .filter { $0.count > 0 }
    }

    private func pieSliceStyle(
        for slices: [DoseStatusSlice],
        defaultInset: CGFloat,
        defaultCornerRadius: CGFloat
    ) -> PieSliceStyle {
        guard slices.count > 1 else {
            logChartSafetyFallback(
                reason: "single_slice",
                slices: slices,
                smallestFraction: 1
            )
            return PieSliceStyle(angularInset: 0, cornerRadius: 0)
        }

        let total = slices.reduce(0) { $0 + max(0, $1.count) }
        guard total > 0 else {
            logChartSafetyFallback(
                reason: "non_positive_total",
                slices: slices,
                smallestFraction: 0
            )
            return PieSliceStyle(angularInset: 0, cornerRadius: 0)
        }

        // Guard against tiny sectors where rounded corners + insets can produce
        // invalid path geometry in Charts and trigger rendering traps.
        let smallestFraction = slices
            .map { Double($0.count) / Double(total) }
            .min() ?? 1

        let hasTinySlice = smallestFraction < 0.03
        if hasTinySlice {
            logChartSafetyFallback(
                reason: "tiny_slice",
                slices: slices,
                smallestFraction: smallestFraction
            )
            return PieSliceStyle(angularInset: 0, cornerRadius: 0)
        }

        return PieSliceStyle(
            angularInset: defaultInset,
            cornerRadius: defaultCornerRadius
        )
    }

    private func logChartSafetyFallback(
        reason: StaticString,
        slices: [DoseStatusSlice],
        smallestFraction: Double
    ) {
        let payload = slices
            .map { "\($0.label):\($0.count)" }
            .joined(separator: ",")
        Self.chartSafetyLogger.notice(
            "chart_style_fallback reason=\(reason, privacy: .public) slices=\(slices.count, privacy: .public) min_fraction=\(smallestFraction, format: .fixed(precision: 4), privacy: .public) payload=\(payload, privacy: .public)"
        )
    }

    private func summarizeFullRange(
        doses: [MedicationDose],
        in range: DateInterval,
        now: Date
    ) -> ChartStatusSummary {
        let adherenceSummary = MedicationAdherenceService().summarize(doses: doses, in: range, now: now)
        return ChartStatusSummary(
            taken: adherenceSummary.takenCount,
            missed: adherenceSummary.missedCount,
            skipped: adherenceSummary.skippedCount,
            pending: adherenceSummary.pendingCount
        )
    }
}

#Preview {
    WeeklyCompletionChartView()
        .modelContainer(PreviewData.container)
        .padding()
}
