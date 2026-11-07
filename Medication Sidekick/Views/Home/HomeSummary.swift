//
//  HomeSummary.swift
//  Medication Sidekick
//
//  Pure value type that turns a week of doses into everything the Home
//  hero and week card display. No SwiftData fetching here, so it is trivial to preview.
//

import Foundation

struct HomeSummary {

    struct Day: Identifiable {
        enum State {
            case noDoses     // nothing scheduled
            case upcoming    // future day
            case pending     // today, doses still to take
            case complete    // nothing left to do, nothing missed
            case missed      // at least one missed dose
        }

        let date: Date
        let state: State
        var taken: Int = 0
        var total: Int = 0
        var id: Date { date }

        /// Share of the day's doses taken, 0...1.
        var fraction: Double { total > 0 ? Double(taken) / Double(total) : 0 }
    }

    /// A dose that needs action right now (due or overdue).
    struct Attention: Identifiable {
        let id: UUID
        let name: String
        let amount: String
        let time: Date
        let isOverdue: Bool
    }

    enum Tone {
        case overdue
        case due
        case ok
    }

    let total: Int
    let taken: Int
    let dueNow: Int
    let laterToday: Int
    let missed: Int
    /// Doses needing action (due now or missed), earliest first.
    let attention: [Attention]
    let days: [Day]
    /// Taken ÷ scheduled for the week so far. `nil` when nothing has been scheduled yet.
    let weekPercent: Int?

    init(total: Int, taken: Int, dueNow: Int, laterToday: Int, missed: Int,
         attention: [Attention], days: [Day], weekPercent: Int?) {
        self.total = total
        self.taken = taken
        self.dueNow = dueNow
        self.laterToday = laterToday
        self.missed = missed
        self.attention = attention
        self.days = days
        self.weekPercent = weekPercent
    }

    init(doses: [MedicationDose], now: Date = Date()) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday, matching the rest of the app

        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let grace = Constants.medicationMissedGracePeriod

        // CloudKit can sync duplicate dose rows; collapse them so counts stay honest.
        let active = deduplicatedDoses(doses.filter { $0.medication?.isActive == true })

        func isMissed(_ dose: MedicationDose) -> Bool {
            switch dose.status {
            case .missed: true
            case .scheduled: now > dose.scheduledDate.addingTimeInterval(grace)
            case .taken, .skipped: false
            }
        }

        // Today
        let today = active
            .filter { $0.scheduledDate >= startOfToday && $0.scheduledDate < startOfTomorrow }
            .sorted { $0.scheduledDate < $1.scheduledDate }

        var taken = 0, dueNow = 0, later = 0, missed = 0
        var items: [Attention] = []
        for dose in today {
            if dose.status == .taken { taken += 1; continue }
            if dose.status == .skipped { continue }
            if isMissed(dose) {
                missed += 1
            } else if dose.scheduledDate <= now {
                dueNow += 1
            } else {
                later += 1
                continue
            }
            items.append(Attention(
                id: UUID(),
                name: dose.medication?.name ?? "Medication",
                amount: dose.medication?.dosage ?? "",
                time: dose.scheduledDate,
                isOverdue: isMissed(dose)
            ))
        }

        // Week strip
        let days: [Day] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }

            let dayDoses = active.filter { $0.scheduledDate >= day && $0.scheduledDate < next }
            let state: Day.State
            if dayDoses.isEmpty {
                state = .noDoses
            } else if day > startOfToday {
                state = .upcoming
            } else if dayDoses.contains(where: isMissed) {
                state = .missed
            } else if dayDoses.contains(where: { $0.status == .scheduled }) {
                state = .pending
            } else {
                state = .complete
            }
            return Day(
                date: day,
                state: state,
                taken: dayDoses.filter { $0.status == .taken }.count,
                total: dayDoses.count
            )
        }

        // Week-to-date adherence
        let weekToDate = active.filter { $0.scheduledDate >= weekStart && $0.scheduledDate < startOfTomorrow }
        let percent: Int? = weekToDate.isEmpty
            ? nil
            : Int((Double(weekToDate.filter { $0.status == .taken }.count) / Double(weekToDate.count) * 100).rounded())

        self.init(
            total: today.count,
            taken: taken,
            dueNow: dueNow,
            laterToday: later,
            missed: missed,
            attention: items,
            days: days,
            weekPercent: percent
        )
    }

    // MARK: - Display helpers

    var progress: Double {
        total > 0 ? Double(taken) / Double(total) : 0
    }

    var tone: Tone {
        if attention.contains(where: { !$0.isOverdue }) { return .due }
        if !attention.isEmpty { return .overdue }
        return .ok
    }

    /// Short summary line for the card.
    var headline: String {
        let count = attention.count
        switch tone {
        case .due:
            return count == 1 ? "1 dose due now" : "\(count) doses need attention"
        case .overdue:
            return count == 1 ? "1 dose overdue" : "\(count) doses overdue"
        case .ok:
            if total == 0 { return "No medications scheduled today" }
            return laterToday > 0 ? "All caught up for now" : "All done for today"
        }
    }

    static var preview: HomeSummary {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday-first, like the real summary
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let states: [Day.State] = [.complete, .complete, .missed, .complete, .complete, .pending, .upcoming]
        let totals = [4, 4, 4, 4, 4, 4, 0]
        let takens = [4, 4, 2, 4, 4, 1, 0]
        let days = states.enumerated().compactMap { index, state in
            calendar.date(byAdding: .day, value: index, to: weekStart).map {
                Day(date: $0, state: state, taken: takens[index], total: totals[index])
            }
        }
        return HomeSummary(
            total: 4, taken: 1, dueNow: 2, laterToday: 1, missed: 0,
            attention: [
                Attention(id: UUID(), name: "Trurapi", amount: "26 units", time: Date().addingTimeInterval(-3600), isOverdue: true),
                Attention(id: UUID(), name: "Atorvastatin", amount: "20 mg", time: Date().addingTimeInterval(-600), isOverdue: false)
            ],
            days: days, weekPercent: 82
        )
    }
}
