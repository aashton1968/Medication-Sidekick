//
//  TodayView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

import SwiftUI
import SwiftData
import os.log

private func preferredDose(_ lhs: MedicationDose, _ rhs: MedicationDose) -> MedicationDose {
    let lhsPriority = lhs.status.sortPriority
    let rhsPriority = rhs.status.sortPriority
    if lhsPriority != rhsPriority {
        return lhsPriority > rhsPriority ? lhs : rhs
    }
    if lhs.updatedAt != rhs.updatedAt {
        return lhs.updatedAt > rhs.updatedAt ? lhs : rhs
    }
    if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt <= rhs.createdAt ? lhs : rhs
    }
    // Avoid touching SwiftData internal IDs here; stale futures from sync can crash
    // when resolved. Keep deterministic ordering using stable domain fields instead.
    let lhsMedicationID = lhs.medication?.id.uuidString ?? ""
    let rhsMedicationID = rhs.medication?.id.uuidString ?? ""
    if lhsMedicationID != rhsMedicationID {
        return lhsMedicationID < rhsMedicationID ? lhs : rhs
    }
    if lhs.mealTimeRaw != rhs.mealTimeRaw {
        return lhs.mealTimeRaw < rhs.mealTimeRaw ? lhs : rhs
    }
    return lhs
}

private func normalizedMedicationToken(_ value: String?) -> String {
    (value ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

private func canonicalDoseKey(for dose: MedicationDose) -> String {
    let medicationName = normalizedMedicationToken(dose.medication?.name)
    let dosage = normalizedMedicationToken(dose.medication?.dosage)
        .replacingOccurrences(of: " ", with: "")
    let mealKey = normalizedMedicationToken(dose.mealTimeRaw)
    let scheduled = dose.scheduledDate.timeIntervalSince1970.safeInt
    return "\(medicationName)|\(dosage)|\(mealKey)|\(scheduled)"
}

private func deduplicatedDoses(_ doses: [MedicationDose]) -> [MedicationDose] {
    var winnersByKey: [String: MedicationDose] = [:]
    for dose in doses {
        let key = canonicalDoseKey(for: dose)
        if let existing = winnersByKey[key] {
            winnersByKey[key] = preferredDose(existing, dose)
        } else {
            winnersByKey[key] = dose
        }
    }
    return Array(winnersByKey.values).sorted(by: medicationDoseSortsBefore)
}

private func medicationDoseSortsBefore(_ lhs: MedicationDose, _ rhs: MedicationDose) -> Bool {
    let lhsName = lhs.medication?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let rhsName = rhs.medication?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let byName = lhsName.localizedCaseInsensitiveCompare(rhsName)
    if byName != .orderedSame {
        return byName == .orderedAscending
    }
    if lhs.scheduledDate != rhs.scheduledDate {
        return lhs.scheduledDate < rhs.scheduledDate
    }
    let lhsID = lhs.medication?.id.uuidString ?? ""
    let rhsID = rhs.medication?.id.uuidString ?? ""
    if lhsID != rhsID {
        return lhsID < rhsID
    }
    if lhs.mealTimeRaw != rhs.mealTimeRaw {
        return lhs.mealTimeRaw < rhs.mealTimeRaw
    }
    if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt < rhs.createdAt
    }
    if lhs.updatedAt != rhs.updatedAt {
        return lhs.updatedAt < rhs.updatedAt
    }
    return false
}

// MARK: - Slot Grouping

private func makeSlotGroups(from doses: [MedicationDose], settings: [MealTimeSetting]) -> [TimeSlotGroup] {
    let grouped = Dictionary(grouping: doses) { $0.mealTimeRaw }
    return grouped.map { key, slotDoses in
        let setting = settings.first { $0.key == key }
        return TimeSlotGroup(
            key: key,
            name: setting?.name ?? (MealTime(rawValue: key)?.displayName ?? key),
            time: setting?.displayTime ?? "",
            symbol: setting?.symbolName ?? "fork.knife",
            sortOrder: setting?.sortOrder ?? 999,
            doses: slotDoses.sorted(by: medicationDoseSortsBefore)
        )
    }
    .sorted { $0.sortOrder < $1.sortOrder }
}

struct TimeSlotGroup: Identifiable {
    let key: String
    let name: String
    let time: String
    let symbol: String
    let sortOrder: Int
    let doses: [MedicationDose]

    var id: String { key }

    var isComplete: Bool {
        doses.allSatisfy { $0.status != .scheduled }
    }
}

// MARK: - Daily Status

private struct DailyStatusSnapshot {
    let total: Int
    let taken: Int
    let scheduled: Int
    let missed: Int
    let skipped: Int

    var completionPercent: Int {
        guard total > 0 else { return 0 }
        let ratio = Double(taken) / Double(total)
        let percent = round(ratio * 100)
        return percent.safeInt
    }

    var remaining: Int {
        scheduled + missed
    }

    var subtitle: String {
        if total == 0 { return "No medications scheduled today" }
        if remaining == 0 { return "All done for today!" }
        return "\(remaining) dose\(remaining == 1 ? "" : "s") remaining today"
    }
}

private struct DailyStatusCardView: View {

    @Environment(ThemeManager.self) var themeManager

    let snapshot: DailyStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Status")
                    .font(.headline)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(themeManager.selectedTheme.textMuted)
                Text(Date(), format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.caption2)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)

                Spacer()

                Text("\(snapshot.completionPercent)%")
                    .font(.headline.weight(.bold))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(snapshot.taken)")
                    .font(.title3.weight(.bold))
                Text("of \(snapshot.total) taken")
                    .font(.caption)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)
            }

            ProgressView(
                value: snapshot.total > 0
                    ? Double(snapshot.taken) / Double(snapshot.total)
                    : 0
            )
            .tint(themeManager.selectedTheme.accentPrimary)

            HStack(spacing: 8) {
                statPill(title: "Taken", count: snapshot.taken, color: .green)
                statPill(title: "Scheduled", count: snapshot.scheduled, color: themeManager.selectedTheme.textMuted)
                statPill(title: "Missed", count: snapshot.missed, color: .red)
                statPill(title: "Skipped", count: snapshot.skipped, color: .orange)
            }

            Text(snapshot.subtitle)
                .font(.caption)
                .foregroundStyle(themeManager.selectedTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.selectedTheme.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .premiumCardShadow(theme: themeManager.selectedTheme)
    }

    private func statPill(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(title) \(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(themeManager.selectedTheme.textSecondary)
        }
    }
}

// MARK: - Reusable Today Snapshot

struct TodaySnapshotSection: View {

    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    @Query(sort: \MealTimeSetting.sortOrder) private var mealTimeSettings: [MealTimeSetting]

    @State private var todayDoses: [MedicationDose] = []
    @State private var dailyStatusSnapshot = DailyStatusSnapshot(
        total: 0,
        taken: 0,
        scheduled: 0,
        missed: 0,
        skipped: 0
    )

    @State private var adherenceService = MedicationAdherenceService()

    let openTodayButtonTitle: String?

    private var slotGroups: [TimeSlotGroup] {
        makeSlotGroups(from: todayDoses, settings: mealTimeSettings)
    }

    private var nextSlot: TimeSlotGroup? {
        slotGroups.first { !$0.isComplete }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DailyStatusCardView(snapshot: dailyStatusSnapshot)

            if let nextSlot {
                NextMedsCard(
                    doses: nextSlot.doses,
                    slotName: nextSlot.name,
                    slotTime: nextSlot.time,
                    slotSymbol: nextSlot.symbol
                )
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.98))))
            }

            if let openTodayButtonTitle {
                
                Button {
                    navigationRouter.navigate(.todayView)
                } label: {
                    Label(openTodayButtonTitle, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .buttonStyle(.plain)
                .background(
                    LinearGradient(
                        colors: [
                            themeManager.selectedTheme.accentPrimary,
                            themeManager.selectedTheme.accentSecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
            }
        }
        .task {
            await refreshDoses()
        }
        .animation(.easeOut(duration: 0.28), value: nextSlot?.id)
        .onReceive(NotificationCenter.default.publisher(for: .medicationDidChange)) { _ in
            fetchTodayDoses()
            refreshDailyStatusSnapshot()
        }
    }

    @MainActor
    private func refreshDoses() async {
        do {
            try MedicationDoseGenerator.refreshAllDoses(modelContext: modelContext)
            _ = try adherenceService.syncMissedStatuses(modelContext: modelContext)
        } catch {
            os_log(.error, "Failed to refresh doses: %{public}@", error.localizedDescription)
        }
        fetchTodayDoses()
        refreshDailyStatusSnapshot()
    }

    private func fetchTodayDoses() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)

        do {
            let descriptor = FetchDescriptor<MedicationDose>(
                predicate: #Predicate { $0.scheduledDate >= start && $0.scheduledDate < end }
            )
            let fetched = try modelContext.fetch(descriptor)
            todayDoses = deduplicatedDoses(fetched.filter { $0.medication?.isActive == true })
        } catch {
            todayDoses = []
        }
    }

    private func refreshDailyStatusSnapshot(now: Date = Date()) {
        let overdueThreshold: TimeInterval = Constants.medicationMissedGracePeriod

        var taken = 0
        var missed = 0
        var skipped = 0
        var scheduled = 0

        for dose in todayDoses {
            switch dose.status {
            case .taken:
                taken += 1
            case .skipped:
                skipped += 1
            case .missed:
                missed += 1
            case .scheduled:
                if now > dose.scheduledDate.addingTimeInterval(overdueThreshold) {
                    missed += 1
                } else {
                    scheduled += 1
                }
            }
        }

        dailyStatusSnapshot = DailyStatusSnapshot(
            total: todayDoses.count,
            taken: taken,
            scheduled: scheduled,
            missed: missed,
            skipped: skipped
        )
    }
}

// MARK: - Today View

struct TodayView: View {

    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    
    @Query(sort: \MealTimeSetting.sortOrder) private var mealTimeSettings: [MealTimeSetting]

    @State private var todayDoses: [MedicationDose] = []
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var weekStartBoundary: Date {
        calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? startOfToday
    }

    private var canMoveBackward: Bool {
        selectedDate > weekStartBoundary
    }

    private var canMoveForward: Bool {
        selectedDate < startOfToday
    }

    private var selectedDateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }
        if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var selectedDateSubtitle: String {
        selectedDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private var slotGroups: [TimeSlotGroup] {
        makeSlotGroups(from: todayDoses, settings: mealTimeSettings)
    }

    private var nextSlot: TimeSlotGroup? {
        slotGroups.first { !$0.isComplete }
    }

    private var dailyStatusSnapshot: DailyStatusSnapshot {
        let overdueThreshold: TimeInterval = Constants.medicationMissedGracePeriod
        let referenceNow: Date
        if calendar.isDateInToday(selectedDate) {
            referenceNow = Date()
        } else {
            referenceNow = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }

        var taken = 0
        var missed = 0
        var skipped = 0
        var scheduled = 0

        for dose in todayDoses {
            switch dose.status {
            case .taken:
                taken += 1
            case .skipped:
                skipped += 1
            case .missed:
                missed += 1
            case .scheduled:
                if referenceNow > dose.scheduledDate.addingTimeInterval(overdueThreshold) {
                    missed += 1
                } else {
                    scheduled += 1
                }
            }
        }

        return DailyStatusSnapshot(
            total: todayDoses.count,
            taken: taken,
            scheduled: scheduled,
            missed: missed,
            skipped: skipped
        )
    }

   var body: some View {
       List {
           Section {
               VStack(alignment: .leading, spacing: 12) {
                   HStack(spacing: 12) {
                       Button {
                           moveDay(by: -1)
                       } label: {
                           Image(systemName: "chevron.left")
                               .font(.headline.weight(.semibold))
                               .frame(width: 34, height: 34)
                               .background(themeManager.selectedTheme.surfaceBase)
                               .clipShape(Circle())
                       }
                       .buttonStyle(.plain)
                       .disabled(!canMoveBackward)
                       .opacity(canMoveBackward ? 1 : 0.35)

                       VStack(alignment: .leading, spacing: 2) {
                           Text(selectedDateTitle)
                               .font(.headline)
                           Text(selectedDateSubtitle)
                               .font(.caption)
                               .foregroundStyle(themeManager.selectedTheme.textSecondary)
                       }

                       Spacer()

                       if canMoveForward {
                           Button("Today") {
                               selectedDate = startOfToday
                           }
                           .font(.caption.weight(.semibold))
                           .padding(.horizontal, 10)
                           .padding(.vertical, 6)
                           .background(themeManager.selectedTheme.surfaceBase)
                           .clipShape(Capsule())
                       }

                       Button {
                           moveDay(by: 1)
                       } label: {
                           Image(systemName: "chevron.right")
                               .font(.headline.weight(.semibold))
                               .frame(width: 34, height: 34)
                               .background(themeManager.selectedTheme.surfaceBase)
                               .clipShape(Circle())
                       }
                       .buttonStyle(.plain)
                       .disabled(!canMoveForward)
                       .opacity(canMoveForward ? 1 : 0.35)
                   }

                   DailyStatusCardView(snapshot: dailyStatusSnapshot)

                   if dailyStatusSnapshot.total == 0 {
                       Text("No medications scheduled for this day")
                           .font(.subheadline)
                           .foregroundStyle(themeManager.selectedTheme.textSecondary)
                           .padding(.horizontal, 6)
                   } else if dailyStatusSnapshot.remaining == 0 {
                       HStack(spacing: 12) {
                           Image(systemName: "checkmark.seal.fill")
                               .foregroundStyle(.green)
                               .font(.title2)
                           Text("All done for this day!")
                               .font(.headline)
                       }
                       .frame(maxWidth: .infinity, alignment: .leading)
                       .padding(.vertical, 12)
                       .padding(.horizontal, 12)
                       .background(themeManager.selectedTheme.surfaceBase)
                       .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                   } else if let nextSlot {
                       NextMedsCard(
                           doses: nextSlot.doses,
                           slotName: nextSlot.name,
                           slotTime: nextSlot.time,
                           slotSymbol: nextSlot.symbol
                       )
                       .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.98))))
                   }
               }
           }
           .listRowInsets(EdgeInsets())
           .listRowBackground(Color.clear)
           .listRowSeparator(.hidden)

           ForEach(slotGroups) { group in
               Section(header: Text(group.name)) {
                   ForEach(group.doses) { dose in
                       DoseRow(dose: dose, mealTimeSettings: mealTimeSettings)
                   }
               }
           }
       }
       .onAppear {
           Task { await refreshDoses() }
       }
       .animation(.easeOut(duration: 0.28), value: nextSlot?.id)
       .onReceive(NotificationCenter.default.publisher(for: .medicationDidChange)) { _ in
           fetchDoses(for: selectedDate)
       }
       .onChange(of: selectedDate) { _, newDate in
           fetchDoses(for: newDate)
       }
       .refreshable {
           await refreshDoses()
       }
       
       .navigationBarTitleDisplayMode(.inline)
       .toolbar {
           ToolbarItem(placement: .principal) {
               Text("Today")
                   .font(.headline).bold()
                   .foregroundStyle(themeManager.selectedTheme.textPrimary)
           }
       }
   }

    @MainActor
    private func refreshDoses() async {
        do {
            try MedicationDoseGenerator.refreshAllDoses(modelContext: modelContext)
        } catch {
            os_log(.error, "Failed to refresh doses: %{public}@", error.localizedDescription)
        }
        fetchDoses(for: selectedDate)
    }

    private func fetchDoses(for date: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)

        do {
            let descriptor = FetchDescriptor<MedicationDose>(
                predicate: #Predicate { $0.scheduledDate >= start && $0.scheduledDate < end }
            )
            let fetched = try modelContext.fetch(descriptor)
            todayDoses = deduplicatedDoses(fetched.filter { $0.medication?.isActive == true })
        } catch {
            todayDoses = []
        }
    }

    private func moveDay(by days: Int) {
        guard let moved = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = min(max(moved, weekStartBoundary), startOfToday)
    }
}


#Preview("Today View") {
    
    let themeManager = ThemeManager()
    let container = PreviewData.container
    
    return NavPreview {
        TodayView()
    }
    .modelContainer(container)
    .environment(themeManager)
    .environmentObject(NavigationRouter())
}

#Preview("Daily Status Card") {
    let themeManager = ThemeManager()
    let snapshot = DailyStatusSnapshot(
        total: 8,
        taken: 5,
        scheduled: 2,
        missed: 1,
        skipped: 0
    )

    return DailyStatusCardView(snapshot: snapshot)
        .padding()
        .environment(themeManager)
}


// MARK: - Dose Row

struct DoseRow: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick",
        category: "DoseTap"
    )
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager

    let dose: MedicationDose
    let mealTimeSettings: [MealTimeSetting]
    @State private var isToggling = false

    private var iconName: String {
        switch dose.status {
        case .taken: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .scheduled: return "circle"
        }
    }

    private var iconColor: Color {
        switch dose.status {
        case .taken:
            return .green
        case .missed:
            return .red
        case .skipped:
            return .orange
        case .scheduled:
            return .secondary
        }
    }
    
    var body: some View {
        Button(action: toggle) {
        HStack(spacing: 12) {

            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading) {

                Text(dose.medication?.name ?? "Medication")
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(dose.medication?.dosage ?? "")
                    Text("·")
                    Text(dose.mealDisplayName(settings: mealTimeSettings))
                }
                .font(.subheadline)
                .foregroundStyle(themeManager.selectedTheme.textSecondary)
            }

            Spacer()

            Text(dose.scheduledDate, style: .time)
                .font(.subheadline)
        }
        .contentShape(Rectangle())
        .allowsHitTesting(!isToggling)
        .opacity(dose.status == .taken ? 0.5 : 1.0)
        .animation(.easeInOut, value: dose.status)
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        guard !isToggling else { return }
        isToggling = true
        defer { isToggling = false }
        InteractionGuard.markDoseInteraction()
        if dose.status == .taken {
            dose.undoTaken()
            do {
                try context.save()
                NotificationCenter.default.post(name: .medicationDidChange, object: nil)
            } catch {
                Self.logger.error("Failed toggling dose to scheduled: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            dose.markAsTaken()
            do {
                try context.save()
                ToastManager.shared.showGeneral(
                    CongratsMessages.forSingleDose(medicationName: dose.medication?.name),
                    duration: 5.0
                )
                NotificationCenter.default.post(name: .medicationDidChange, object: nil)
            } catch {
                Self.logger.error("Failed toggling dose to taken: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
