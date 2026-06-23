//
//  MedicationAdherenceService.swift
//  Medication Sidekick
//
//  Created by Cursor on 2026-02-23.
//

import Foundation
import SwiftData
import UserNotifications

struct AdherenceConfiguration {
    var missedGracePeriod: TimeInterval
    var skippedCountsAgainstAdherence: Bool

    nonisolated init(
        missedGracePeriod: TimeInterval = 2 * 60 * 60,
        skippedCountsAgainstAdherence: Bool = true
    ) {
        self.missedGracePeriod = missedGracePeriod
        self.skippedCountsAgainstAdherence = skippedCountsAgainstAdherence
    }
}

struct AdherenceSummary {
    let rangeStart: Date
    let rangeEnd: Date
    let dueCount: Int
    let takenCount: Int
    let missedCount: Int
    let skippedCount: Int
    let pendingCount: Int

    var remainingCount: Int {
        pendingCount + missedCount
    }

    var adherencePercent: Int {
        guard dueCount > 0 else { return 0 }
        let ratio = Double(takenCount) / Double(dueCount)
        let percent = round(ratio * 100)
        return percent.safeInt
    }
}

struct MedicationAdherenceSummary: Identifiable {
    let medicationID: UUID
    let medicationName: String
    let summary: AdherenceSummary

    var id: UUID { medicationID }
}

@MainActor
struct MedicationAdherenceService {

    let configuration: AdherenceConfiguration
    let calendar: Calendar

    nonisolated init(
        configuration: AdherenceConfiguration = AdherenceConfiguration(),
        calendar: Calendar = .current
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    func dailySummary(
        on day: Date = Date(),
        now: Date = Date(),
        modelContext: ModelContext
    ) throws -> AdherenceSummary {
        let range = dayRange(for: day)
        let doses = try doses(in: range, modelContext: modelContext)
        return summarize(doses: doses, in: range, now: now)
    }

    func rollingSummary(
        days: Int,
        endingAt now: Date = Date(),
        modelContext: ModelContext
    ) throws -> AdherenceSummary {
        let end = now
        let startOfEndDay = calendar.startOfDay(for: end)
        guard days > 0 else {
            return AdherenceSummary(
                rangeStart: startOfEndDay,
                rangeEnd: startOfEndDay,
                dueCount: 0,
                takenCount: 0,
                missedCount: 0,
                skippedCount: 0,
                pendingCount: 0
            )
        }
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfEndDay) else {
            return AdherenceSummary(
                rangeStart: end,
                rangeEnd: end,
                dueCount: 0,
                takenCount: 0,
                missedCount: 0,
                skippedCount: 0,
                pendingCount: 0
            )
        }

        let range = DateInterval(start: start, end: end)
        let doses = try doses(in: range, modelContext: modelContext)
        return summarize(doses: doses, in: range, now: now)
    }

    func perMedicationDailySummary(
        on day: Date = Date(),
        now: Date = Date(),
        modelContext: ModelContext
    ) throws -> [MedicationAdherenceSummary] {
        let range = dayRange(for: day)
        let doses = try doses(in: range, modelContext: modelContext)
        let grouped = Dictionary(grouping: doses) { $0.medication?.id }

        return grouped.compactMap { medicationID, medicationDoses in
            guard let medicationID,
                  let medicationName = medicationDoses.first?.medication?.name else {
                return nil
            }
            return MedicationAdherenceSummary(
                medicationID: medicationID,
                medicationName: medicationName,
                summary: summarize(doses: medicationDoses, in: range, now: now)
            )
        }
        .sorted { $0.medicationName.localizedCaseInsensitiveCompare($1.medicationName) == .orderedAscending }
    }

    /// Promotes stale scheduled doses to missed using the configured grace period.
    /// Returns number of doses updated.
    @discardableResult
    func syncMissedStatuses(
        now: Date = Date(),
        modelContext: ModelContext
    ) throws -> Int {
        let cutoff = now.addingTimeInterval(-configuration.missedGracePeriod)
        let scheduledRaw = "scheduled"
        let descriptor = FetchDescriptor<MedicationDose>(
            predicate: #Predicate { dose in
                dose.statusRaw == scheduledRaw && dose.scheduledDate <= cutoff
            }
        )
        let staleDoses = try modelContext.fetch(descriptor)

        for dose in staleDoses {
            dose.status = .missed
            dose.updatedAt = now
        }

        if !staleDoses.isEmpty {
            try modelContext.save()
        }

        return staleDoses.count
    }

    func summarize(
        doses: [MedicationDose],
        in range: DateInterval,
        now: Date = Date()
    ) -> AdherenceSummary {
        let dueCutoff = min(now, range.end)
        let inRange = doses.filter { range.contains($0.scheduledDate) }
        let dueDoses = inRange.filter { $0.scheduledDate <= dueCutoff }
        let pending = dueDoses.filter { effectiveStatus(for: $0, now: now) == .scheduled }.count
        let taken = dueDoses.filter { effectiveStatus(for: $0, now: now) == .taken }.count
        let missed = dueDoses.filter { effectiveStatus(for: $0, now: now) == .missed }.count
        let skipped = dueDoses.filter { effectiveStatus(for: $0, now: now) == .skipped }.count
        let due = taken + missed + (configuration.skippedCountsAgainstAdherence ? skipped : 0)

        return AdherenceSummary(
            rangeStart: range.start,
            rangeEnd: range.end,
            dueCount: due,
            takenCount: taken,
            missedCount: missed,
            skippedCount: skipped,
            pendingCount: pending
        )
    }

    private func dayRange(for day: Date) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func doses(in range: DateInterval, modelContext: ModelContext) throws -> [MedicationDose] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<MedicationDose>(
            predicate: #Predicate { dose in
                dose.scheduledDate >= start && dose.scheduledDate < end
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func effectiveStatus(for dose: MedicationDose, now: Date) -> DoseStatus {
        if dose.status != .scheduled {
            return dose.status
        }

        let overdueCutoff = dose.scheduledDate.addingTimeInterval(configuration.missedGracePeriod)
        if now >= overdueCutoff {
            return .missed
        }

        return .scheduled
    }
}
