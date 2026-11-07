//
//  DoseRow.swift
//  Medication Sidekick
//
//  A single dose in the Home list: tap to take, swipe to take / skip.
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
        .opacity(dose.status == .taken || dose.status == .skipped ? 0.5 : 1.0)
        .animation(.easeInOut, value: dose.status)
        }
        .buttonStyle(.plain)
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
    // including "scheduled but overdue," which drives the .missed icon/color.
    let scheduledDose = MedicationDose(medication: medication, mealTime: .breakfast, scheduledDate: Date())
    let takenDose = MedicationDose(medication: medication, mealTime: .lunch, scheduledDate: Date(), status: .taken)
    let skippedDose = MedicationDose(medication: medication, mealTime: .dinner, scheduledDate: Date(), status: .skipped)
    let missedDose = MedicationDose(
        medication: medication,
        mealTime: .supper,
        scheduledDate: Date().addingTimeInterval(-6 * 3600),
        status: .missed
    )

    [scheduledDose, takenDose, skippedDose, missedDose].forEach { context.insert($0) }
    try? context.save()

    return List {
        DoseRow(dose: scheduledDose, mealTimeSettings: [])
        DoseRow(dose: takenDose, mealTimeSettings: [])
        DoseRow(dose: skippedDose, mealTimeSettings: [])
        DoseRow(dose: missedDose, mealTimeSettings: [])
    }
    .modelContainer(container)
    .environment(themeManager)
}
