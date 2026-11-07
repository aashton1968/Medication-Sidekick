//
//  DoseRow.swift
//  Medication Sidekick
//
//  A single dose in the Home list, drawn as a card: tap to take, swipe to take / skip.
//  Must live inside a List for the swipe actions to appear.
//

import SwiftUI
import SwiftData
import os.log

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
    /// Used for the "Late" text. Passed in so the Home list can keep it current by the minute.
    var now: Date = Date()
    @State private var isToggling = false

    private var theme: ThemeProtocol { themeManager.selectedTheme }

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

    private var isHandled: Bool {
        dose.status == .taken || dose.status == .skipped
    }

    /// "Late 2:05" (hours:minutes since it was due) for today's unlogged doses,
    /// "Missed" for unlogged doses on earlier days, nothing otherwise.
    private var lateText: String? {
        guard dose.status == .scheduled || dose.status == .missed else { return nil }
        let calendar = Calendar.current
        guard calendar.isDateInToday(dose.scheduledDate) else {
            return dose.scheduledDate < calendar.startOfDay(for: now) ? "Missed" : nil
        }
        let seconds = now.timeIntervalSince(dose.scheduledDate)
        guard seconds >= 60 else { return nil }
        let minutes = Int(seconds / 60)
        return String(format: "Late %d:%02d", minutes / 60, minutes % 60)
    }

    /// "500 mg · Take with food": dosage first, then instructions when there are any.
    private var detailText: String? {
        let dosage = dose.medication?.dosage.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let instructions = dose.medication?.instructions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = [dosage, instructions].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The medication's type icon in a tinted tile, with a status badge on its corner once handled.
    private var medicationIcon: some View {
        Image(systemName: dose.medication?.medicationType.symbolName ?? "pill.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(theme.accentTint)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.accentTint.opacity(0.12))
            )
            .overlay(alignment: .bottomTrailing) {
                if dose.status != .scheduled {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(iconColor)
                        .background(Circle().fill(theme.surfaceBase).padding(1))
                        .offset(x: 6, y: 6)
                }
            }
            .accessibilityHidden(true)
    }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {

                medicationIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(dose.medication?.name ?? "Medication")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    if let detail = detailText {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Text(dose.mealDisplayName(settings: mealTimeSettings))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(theme.accentTint)
                }

                Spacer(minLength: 8)

                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .allowsHitTesting(!isToggling)
            .opacity(isHandled ? 0.55 : 1.0)
            .animation(.easeInOut, value: dose.status)
        }
        .buttonStyle(.plain)
        // Each row is its own card, with the list's row spacing as the gap between them.
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.surfaceBase)
                .premiumCardShadow(theme: theme)
        )
        .contextMenu {
            if dose.status == .scheduled || dose.status == .skipped {
                Button {
                    skip()
                } label: {
                    Label(dose.status == .skipped ? "Undo Skip" : "Skip Dose", systemImage: dose.status == .skipped ? "arrow.uturn.backward" : "minus.circle")
                }
            }
        }
        // Swipe right to mark taken (or undo, if already taken) — the standard iOS
        // check-in gesture, on top of the same toggle() the row's tap already uses.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggle()
            } label: {
                if dose.status == .taken {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Mark Taken", systemImage: "checkmark")
                }
            }
            .tint(dose.status == .taken ? .gray : .green)
        }
        // Swipe left to skip (or undo a skip). Mirrors the context menu above: skipping
        // is only offered from .scheduled/.skipped, matching markAsSkipped()'s own guard.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if dose.status == .scheduled || dose.status == .skipped {
                Button {
                    skip()
                } label: {
                    Label(dose.status == .skipped ? "Undo Skip" : "Skip", systemImage: dose.status == .skipped ? "arrow.uturn.backward" : "minus.circle")
                }
                .tint(.gray)
            }
        }
    }

    /// Right-hand side: the due time (or the time it was taken) and a small status line.
    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 3) {
            switch dose.status {
            case .taken:
                Text(dose.takenTime ?? dose.scheduledDate, style: .time)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                Text("Taken")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.statusSuccess)
            case .skipped:
                Text(dose.scheduledDate, style: .time)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                Text("Skipped")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            case .scheduled, .missed:
                Text(dose.scheduledDate, style: .time)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                if let lateText {
                    Text(lateText)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.statusError)
                }
            }
        }
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

    private func skip() {
        InteractionGuard.markDoseInteraction()
        if dose.status == .skipped {
            dose.undoSkipped()
        } else {
            dose.markAsSkipped()
        }
        do {
            try context.save()
            NotificationCenter.default.post(name: .medicationDidChange, object: nil)
        } catch {
            Self.logger.error("Failed toggling skip: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview("Dose Row") {
    let themeManager = ThemeManager()
    let container = PreviewData.container
    let context = container.mainContext

    let medication = Medication(
        name: "Metformin",
        dosage: "500 mg",
        meals: [.breakfast, .lunch, .dinner, .supper],
        currentStock: 40,
        stockUnit: .tablets
    )
    context.insert(medication)

    // One row per status, so all four swipe/tap states are visible at a glance —
    // including "scheduled but overdue," which drives the Late text.
    let scheduledDose = MedicationDose(medication: medication, mealTime: .breakfast, scheduledDate: Date().addingTimeInterval(3600))
    let takenDose = MedicationDose(medication: medication, mealTime: .lunch, scheduledDate: Date(), status: .taken)
    takenDose.takenTime = Date()
    let skippedDose = MedicationDose(medication: medication, mealTime: .dinner, scheduledDate: Date(), status: .skipped)
    let lateDose = MedicationDose(
        medication: medication,
        mealTime: .supper,
        scheduledDate: Date().addingTimeInterval(-2 * 3600 - 300),
        status: .scheduled
    )

    [scheduledDose, takenDose, skippedDose, lateDose].forEach { context.insert($0) }
    try? context.save()

    return List {
        DoseRow(dose: scheduledDose, mealTimeSettings: [])
        DoseRow(dose: takenDose, mealTimeSettings: [])
        DoseRow(dose: skippedDose, mealTimeSettings: [])
        DoseRow(dose: lateDose, mealTimeSettings: [])
    }
    .listRowSpacing(10)
    .scrollContentBackground(.hidden)
    .modelContainer(container)
    .environment(themeManager)
}
