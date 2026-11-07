//
//  DosePillView.swift
//  Medication Sidekick
//
//  Floating "next dose" pill shown as the tab bar's bottom accessory.
//

import SwiftUI
import SwiftData
import os.log

struct DosePillView: View {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick",
        category: "DosePill"
    )

    @Environment(\.modelContext) private var modelContext
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(ThemeManager.self) private var themeManager

    let state: DosePillState

    private var theme: ThemeProtocol { themeManager.selectedTheme }
    private var isInline: Bool { placement == .inline }

    private var accent: Color {
        switch state.kind {
        case .overdue:  theme.statusError
        case .due:      theme.accentPrimary
        case .upcoming: theme.textMuted
        }
    }

    private var medicationName: String {
        state.dose.medication?.name ?? "Medication"
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(medicationName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                if !isInline {
                    Text(state.statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Drawn explicitly: the accessory restyles system button styles into plain text.
            Button(action: markTaken) {
                Text("Taken")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.bgBase)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(theme.textPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(medicationName) as taken")
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }

    private func markTaken() {
        let dose = state.dose
        InteractionGuard.markDoseInteraction()
        dose.markAsTaken()
        do {
            try modelContext.save()
            ToastManager.shared.showGeneral(
                CongratsMessages.forSingleDose(medicationName: dose.medication?.name),
                duration: 5.0
            )
            NotificationCenter.default.post(name: .medicationDidChange, object: nil)
        } catch {
            Self.logger.error("Failed to mark dose taken from pill: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#if DEBUG
#Preview {
    let container = PreviewData.container
    PreviewData.seed(into: container.mainContext)
    let doses = (try? container.mainContext.fetch(FetchDescriptor<MedicationDose>())) ?? []
    let state = DosePillState(doses: doses, now: .distantFuture)
        ?? doses.first.map { DosePillState(doses: [$0], now: $0.scheduledDate.addingTimeInterval(60)) } ?? nil

    return Group {
        if let state {
            DosePillView(state: state)
                .frame(height: 56)
                .glassEffect(.regular, in: .capsule)
                .padding()
        } else {
            Text("No preview doses")
        }
    }
    .modelContainer(container)
    .environment(ThemeManager())
}
#endif
