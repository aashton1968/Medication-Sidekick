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
        var id: Date { date }
    }

    /// One entry per dose today, in time order. Drives the segmented ring.
    enum Segment {
        case taken
        case skipped
        case missed
        case due
        case later
    }

    let total: Int
    let taken: Int
    let dueNow: Int
    let laterToday: Int
    let missed: Int
    /// Distinct medication names needing action (due now or missed), earliest first.
    let attentionNames: [String]
    let days: [Day]
    let segments: [Segment]
    /// Taken ÷ scheduled for the week so far. `nil` when nothing has been scheduled yet.
    let weekPercent: Int?

    init(total: Int, taken: Int, dueNow: Int, laterToday: Int, missed: Int,
         attentionNames: [String], days: [Day], weekPercent: Int?, segments: [Segment] = []) {
        self.total = total
        self.taken = taken
        self.dueNow = dueNow
        self.laterToday = laterToday
        self.missed = missed
        self.attentionNames = attentionNames
        self.days = days
        self.weekPercent = weekPercent
        self.segments = segments
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
            .sorted {
                // Time order; doses at the same time list taken first so the ring fills clockwise.
                if $0.scheduledDate != $1.scheduledDate { return $0.scheduledDate < $1.scheduledDate }
                return $0.status.sortPriority > $1.status.sortPriority
            }

        var taken = 0, dueNow = 0, later = 0, missed = 0
        var names: [String] = []
        var segments: [Segment] = []
        for dose in today {
            if dose.status == .taken { taken += 1; segments.append(.taken); continue }
            if dose.status == .skipped { segments.append(.skipped); continue }
            if isMissed(dose) {
                missed += 1
                segments.append(.missed)
            } else if dose.scheduledDate <= now {
                dueNow += 1
                segments.append(.due)
            } else {
                later += 1
                segments.append(.later)
                continue
            }
            if let name = dose.medication?.name, !name.isEmpty, !names.contains(name) {
                names.append(name)
            }
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
            return Day(date: day, state: state)
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
            attentionNames: names,
            days: days,
            weekPercent: percent,
            segments: segments
        )
    }

    // MARK: - Display helpers

    var progress: Double {
        total > 0 ? Double(taken) / Double(total) : 0
    }

    /// Medication names that need action, bolded by the card.
    var attentionNamesText: String? {
        switch attentionNames.count {
        case 0: nil
        case 1: attentionNames[0]
        case 2: "\(attentionNames[0]) and \(attentionNames[1])"
        default: "\(attentionNames[0]), \(attentionNames[1]) and \(attentionNames.count - 2) more"
        }
    }

    var attentionSuffix: String {
        let verb = attentionNames.count == 1 ? "is" : "are"
        return dueNow == 0 ? " \(verb) overdue." : " \(verb) due."
    }

    var idleMessage: String {
        if total == 0 { return "No medications scheduled today." }
        if laterToday > 0 { return "All caught up for now." }
        return "All done for today."
    }

    static var preview: HomeSummary {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let states: [Day.State] = [.complete, .complete, .missed, .complete, .complete, .pending, .upcoming]
        let days = states.enumerated().compactMap { index, state in
            calendar.date(byAdding: .day, value: index, to: weekStart).map { Day(date: $0, state: state) }
        }
        return HomeSummary(
            total: 4, taken: 1, dueNow: 2, laterToday: 1, missed: 0,
            attentionNames: ["Trurapi", "Atorvastatin"],
            days: days, weekPercent: 82,
            segments: [.taken, .taken, .missed, .due, .due, .later, .later, .later]
        )
    }
}
