//
//  NextMedsCard.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

import SwiftUI
import SwiftData
import os.log

// MARK: - Next Dose Card (Time-Slot)

struct NextMedsCard: View {

    @Environment(ThemeManager.self) var themeManager

    let doses: [MedicationDose]
    let slotName: String
    let slotTime: String
    let slotSymbol: String

    private var handledCount: Int {
        doses.filter { $0.status == .taken || $0.status == .skipped }.count
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Gradient header ──

            HStack {
                Image(systemName: slotSymbol)
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(slotName)
                        .font(.headline)
                    Text(slotTime)
                        .font(.subheadline.weight(.medium))
                        .opacity(0.85)
                    Text("Tap each medication as you take it")
                        .font(.caption2)
                        .opacity(0.85)
                }

                Spacer()

                Text("\(handledCount)/\(doses.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .foregroundStyle(themeManager.selectedTheme.textOnAccent)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
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

            // ── Medication rows ──

            let pendingScheduledCount = doses.filter { $0.status == .scheduled }.count
            VStack(spacing: 0) {
                ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
                    SlotDoseRow(
                        dose: dose,
                        isFinalPendingDoseInSlot: pendingScheduledCount == 1 && dose.status == .scheduled
                    )
                    if index < doses.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(themeManager.selectedTheme.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .premiumCardShadow(theme: themeManager.selectedTheme)
        
    }

}

// MARK: - Slot Dose Row

private struct SlotDoseRow: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick",
        category: "DoseTap"
    )
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    let dose: MedicationDose
    let isFinalPendingDoseInSlot: Bool
    @State private var isToggling = false

    private var effectiveStatus: DoseStatus {
        if dose.status != .scheduled { return dose.status }
        if Date() > dose.scheduledDate.addingTimeInterval(Constants.medicationMissedGracePeriod) {
            return .missed
        }
        return .scheduled
    }

    private var iconName: String {
        switch effectiveStatus {
        case .taken:     return "checkmark.circle.fill"
        case .missed:    return "exclamationmark.circle.fill"
        case .skipped:   return "minus.circle.fill"
        case .scheduled: return "circle"
        }
    }

    private var iconColor: Color {
        switch effectiveStatus {
        case .taken:     return .green
        case .missed:    return .red
        case .skipped:   return .orange
        case .scheduled: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medication?.name ?? "Medication")
                    .font(.subheadline.weight(.medium))

                Text(dose.medication?.dosage ?? "")
                    .font(.caption)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)
            }
            .foregroundColor(themeManager.selectedTheme.textPrimary)
            
            
            Spacer()

            if effectiveStatus == .missed {
                Text("Overdue")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .allowsHitTesting(!isToggling)
        .opacity(dose.status == .taken || dose.status == .skipped ? 0.5 : 1.0)
        .animation(.easeInOut, value: dose.status)
    }

    private func toggle() {
        guard !isToggling else { return }
        isToggling = true
        defer { isToggling = false }

        InteractionGuard.markDoseInteraction()
        if dose.status == .taken {
            dose.undoTaken()
            do {
                try modelContext.save()
                Self.logger.debug("Dose toggled to scheduled from NextDoseCard")
                NotificationCenter.default.post(name: .medicationDidChange, object: nil)
            } catch {
                Self.logger.error("Failed toggling dose to scheduled: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            dose.markAsTaken()
            do {
                try modelContext.save()
                Self.logger.debug("Dose toggled to taken from NextDoseCard")
                ToastManager.shared.showGeneral(
                    CongratsMessages.forSingleDose(medicationName: dose.medication?.name),
                    duration: 5.0
                )
                // Give the final-row interaction a short grace period so the card
                // does not disappear immediately under the user's finger.
                if isFinalPendingDoseInSlot {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        NotificationCenter.default.post(name: .medicationDidChange, object: nil)
                    }
                } else {
                    NotificationCenter.default.post(name: .medicationDidChange, object: nil)
                }
            } catch {
                Self.logger.error("Failed toggling dose to taken: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - Preview

#Preview("Next Meds Card") {

    let themeManager = ThemeManager()
    let container = PreviewData.container
    let context = container.mainContext

    PreviewData.seed(into: context)

    let descriptor = FetchDescriptor<MedicationDose>()
    let allDoses = (try? context.fetch(descriptor)) ?? []
    let sampleDoses = Array(allDoses.prefix(3))

    return ScrollView {
        VStack(spacing: 16) {
            NextMedsCard(
                doses: sampleDoses,
                slotName: "Breakfast",
                slotTime: "7:00 AM",
                slotSymbol: "fork.knife"
            )
        }
        .padding()
    }
    .modelContainer(container)
    .environment(themeManager)
    .environmentObject(NavigationRouter())
}
