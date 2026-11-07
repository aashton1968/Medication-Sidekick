//
//  HomeWeekCard.swift
//  Medication Sidekick
//
//  Floating card under the hero: a short status line, the doses that need action
//  right now, and the week as mini bars (which also pick the day shown below).
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

    private let maxListedDoses = 3
    private let barHeight: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusLine

            if !summary.attention.isEmpty {
                attentionList
            }

            Divider()

            weekSection
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceBase, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .premiumCardShadow(theme: theme)
    }

    // MARK: - Status line

    private var toneColor: Color {
        switch summary.tone {
        case .overdue: theme.statusError
        case .due:     theme.accentTint
        case .ok:      theme.statusSuccess
        }
    }

    private var toneSymbol: String {
        switch summary.tone {
        case .overdue: "exclamationmark.circle.fill"
        case .due:     "clock.fill"
        case .ok:      "checkmark.circle.fill"
        }
    }

    private var statusLine: some View {
        HStack(spacing: 10) {
            Image(systemName: toneSymbol)
                .font(.title3)
                .foregroundStyle(toneColor)
                .accessibilityHidden(true)
            Text(summary.headline)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Doses needing action

    private var attentionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(summary.attention.prefix(maxListedDoses)) { item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(item.isOverdue ? theme.statusError : theme.accentTint)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if !item.amount.isEmpty {
                        Text(item.amount)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(item.time, style: .time)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(item.isOverdue ? theme.statusError : theme.textSecondary)
                }
            }

            let extra = summary.attention.count - maxListedDoses
            if extra > 0 {
                Text("+\(extra) more")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.leading, 18)
            }
        }
    }

    // MARK: - Week

    private var weekSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if let percent = summary.weekPercent {
                    Text("\(percent)% taken")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            HStack(spacing: 4) {
                ForEach(summary.days) { day in
                    dayColumn(day)
                }
            }
        }
    }

    private func dayColumn(_ day: HomeSummary.Day) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isFuture = day.date > calendar.startOfDay(for: Date())

        return Button {
            onSelect(day.date)
        } label: {
            VStack(spacing: 6) {
                Text(day.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? theme.textPrimary : theme.textSecondary)

                bar(for: day)

                Text(day.date, format: .dateTime.day())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accentTint.opacity(0.14))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A vertical bar filled bottom-up by the share of that day's doses taken.
    /// A missed day gets a red-tinted track so it stands out even when partly filled.
    private func bar(for day: HomeSummary.Day) -> some View {
        let trackColor = day.state == .missed
            ? theme.statusError.opacity(0.18)
            : theme.borderSubtle.opacity(0.7)
        let fillColor = day.state == .complete ? theme.statusSuccess : theme.accentTint

        return ZStack(alignment: .bottom) {
            Capsule().fill(trackColor)
            if day.fraction > 0 {
                Capsule()
                    .fill(fillColor)
                    .frame(height: max(10, barHeight * day.fraction))
            }
        }
        .frame(width: 24, height: barHeight)
        .clipShape(Capsule())
    }

    private func accessibilityLabel(for day: HomeSummary.Day) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day())
        switch day.state {
        case .noDoses:  return "\(date), no doses scheduled"
        case .upcoming: return "\(date), upcoming"
        case .complete: return "\(date), all \(day.total) doses taken"
        case .missed:   return "\(date), \(day.taken) of \(day.total) taken, some missed"
        case .pending:  return "\(date), \(day.taken) of \(day.total) taken, doses remaining"
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
