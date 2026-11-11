//
//  DosePillState.swift
//  Medication Sidekick
//
//  Decides which single dose the floating pill above the tab bar should show.
//

import Foundation

struct DosePillState {

    enum Kind {
        case overdue
        case due
        case upcoming
        case allDone
    }

    /// `nil` only for `.allDone`, when there's no single dose left to point at.
    let dose: MedicationDose?
    let kind: Kind
    /// Other doses that are also due or overdue right now.
    let moreCount: Int

    /// Returns `nil` only when nothing at all is scheduled for today — the pill is
    /// otherwise always shown, falling back to the next upcoming dose, then to
    /// `.allDone` once every dose for the day has been taken or skipped.
    init?(doses: [MedicationDose], now: Date = Date()) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return nil }
        let grace = Constants.medicationMissedGracePeriod

        let today = deduplicatedDoses(doses)
            .filter { dose in
                dose.medication?.isActive == true
                    && dose.scheduledDate >= startOfToday
                    && dose.scheduledDate < startOfTomorrow
            }
        guard !today.isEmpty else { return nil }

        let remaining = today
            .filter { $0.status == .scheduled || $0.status == .missed }
            .sorted { $0.scheduledDate < $1.scheduledDate }

        let needingAction = remaining.filter { $0.scheduledDate <= now }

        if let first = needingAction.first {
            let isOverdue = first.status == .missed
                || now > first.scheduledDate.addingTimeInterval(grace)
            self.dose = first
            self.kind = isOverdue ? .overdue : .due
            self.moreCount = needingAction.count - 1
        } else if let next = remaining.first {
            self.dose = next
            self.kind = .upcoming
            self.moreCount = 0
        } else {
            self.dose = nil
            self.kind = .allDone
            self.moreCount = 0
        }
    }

    var timeText: String {
        dose?.scheduledDate.formatted(date: .omitted, time: .shortened) ?? ""
    }

    var statusText: String {
        var text: String
        switch kind {
        case .overdue:  text = "Overdue · \(timeText)"
        case .due:      text = "Due · \(timeText)"
        case .upcoming: text = "Next · \(timeText)"
        case .allDone:  text = "All doses taken today"
        }
        if moreCount > 0 { text += " · +\(moreCount) more" }
        return text
    }
}
