//
//  HomeWeekCard.swift
//  Medication Sidekick
//
//  Floating card under the hero: what needs doing now, plus the week strip.
//

import SwiftUI

struct HomeWeekCard: View {

    @Environment(ThemeManager.self) private var themeManager

    let summary: HomeSummary
    /// The day whose doses are listed below the card.
    let selectedDate: Date
    let onSelect: (Date) -> Void

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headline

            VStack(spacing: 12) {
                HStack {
                    Text("THIS WEEK")
                        .font(.footnote.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    if let percent = summary.weekPercent {
                        Text("\(percent)%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                HStack(spacing: 0) {
                    ForEach(summary.days) { day in
                        dayCell(day)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceBase, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .premiumCardShadow(theme: theme)
    }

    // MARK: - Headline

    @ViewBuilder
    private var headline: some View {
        Group {
            if let names = summary.attentionNamesText {
                Text(names).fontWeight(.bold) + Text(summary.attentionSuffix)
            } else {
                Text(summary.idleMessage)
            }
        }
        .font(.system(.title2, design: .rounded, weight: .regular))
        .foregroundStyle(theme.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Week strip

    private func dayCell(_ day: HomeSummary.Day) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isFuture = day.date > calendar.startOfDay(for: Date())

        return Button {
            onSelect(day.date)
        } label: {
            dayCellContent(day, isToday: isToday, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dayCellContent(_ day: HomeSummary.Day, isToday: Bool, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? theme.textPrimary : theme.textSecondary)

            Text(day.date, format: .dateTime.day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(ringColor(for: day.state), lineWidth: 3))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                Capsule().fill(theme.accentPrimary.opacity(0.14))
            }
        }
        .contentShape(Rectangle())
    }

    private func ringColor(for state: HomeSummary.Day.State) -> Color {
        switch state {
        case .complete: theme.statusSuccess
        case .missed:   theme.statusError
        case .pending:  theme.accentPrimary
        case .noDoses, .upcoming: theme.borderDefault
        }
    }

    private func accessibilityLabel(for day: HomeSummary.Day) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day())
        switch day.state {
        case .complete: return "\(date), all doses taken"
        case .missed:   return "\(date), missed doses"
        case .pending:  return "\(date), doses remaining"
        case .upcoming: return "\(date), upcoming"
        case .noDoses:  return "\(date), no doses scheduled"
        }
    }
}

#if DEBUG
#Preview {
    HomeWeekCard(summary: .preview, selectedDate: Date(), onSelect: { _ in })
        .padding()
        .environment(ThemeManager())
}
#endif
