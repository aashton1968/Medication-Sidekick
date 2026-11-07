//
//  HomeHeroView.swift
//  Medication Sidekick
//
//  Top of the Today tab: date, progress ring and three headline stats.
//  Sits on the accent gradient drawn by HomeView.
//

import SwiftUI

struct HomeHeroView: View {

    @Environment(ThemeManager.self) private var themeManager
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 168

    let summary: HomeSummary
    var date: Date = Date()

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .textCase(.uppercase)
                .font(.footnote.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(theme.textOnAccent.opacity(0.85))

            HStack(spacing: 24) {
                ring
                VStack(alignment: .leading, spacing: 14) {
                    stat(summary.dueNow, "due now")
                    stat(summary.laterToday, "later today")
                    stat(summary.missed, "missed")
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(theme.textOnAccent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.taken) of \(summary.total) doses taken. \(summary.dueNow) due now, \(summary.laterToday) later today, \(summary.missed) missed."
        )
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(theme.textOnAccent.opacity(0.22), lineWidth: 16)
            Circle()
                .trim(from: 0, to: summary.progress)
                .stroke(theme.textOnAccent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: summary.progress)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(summary.taken)")
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                    Text("/\(summary.total)")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .opacity(0.8)
                }
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                Text("TAKEN")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
            Text(label)
                .font(.subheadline.weight(.medium))
                .opacity(0.9)
        }
    }
}

#if DEBUG
#Preview {
    let theme = ThemeManager()
    HomeHeroView(summary: .preview)
        .padding()
        .background(theme.selectedTheme.accentPrimary)
        .environment(theme)
}
#endif
