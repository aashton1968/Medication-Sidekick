//
//  NextDoseCard.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

// NextDoseCard.swift

import SwiftUI

import SwiftData

// MARK: - Local display helpers
extension DoseStatus {
    var displayName: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .taken:
            return "Taken"
        case .missed:
            return "Missed"
        case .skipped:
            return "Skipped"
        @unknown default:
            return "Unknown"
        }
    }
}

struct NextDoseCard: View {

    @Environment(\.modelContext) private var modelContext

    let event: MedicationDoseEvent
    private var medication: Medication? {
        event.dose.schedule.medication
    }

    private var effectiveStatus: DoseStatus {
        if event.status == .taken { return .taken }

        let scheduled = event.dose.scheduledDate

        if Date() > scheduled.addingTimeInterval(60 * 60) {
            return .missed
        }

        return event.status
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Next dose")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(medication?.name ?? "Unknown Medication")
                    .font(.headline)

                Text(medication?.dosage ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(event.dose.scheduledDate, style: .timer)
                .font(.title2.weight(.bold))
                .foregroundStyle(
                    effectiveStatus == .missed
                    ? .red
                    : (effectiveStatus == .scheduled ? .primary : .secondary)
                )
            
            Text(effectiveStatus.displayName)
                .font(.caption)
                .foregroundStyle(effectiveStatus == .missed ? .red : .secondary)

            HStack(spacing: 12) {
                Button("Taken") {
                    markTaken()
                }
                .buttonStyle(.borderedProminent)
                .disabled(event.status == .taken)

                Button("Skip") {
                    markSkipped()
                }
                .buttonStyle(.bordered)
                .disabled(event.status == .taken)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func markTaken() {
        withAnimation {
            event.status = .taken
            event.takenTime = Date()
            event.updatedAt = Date()
        }
    }

    private func markSkipped() {
        withAnimation {
            event.status = .skipped
            event.updatedAt = Date()
        }
    }
}

#Preview("Next Dose Card") {

    
    // Initialise the background Store
    let themeManager = ThemeManager()
    let container = PreviewData.container
    let context = container.mainContext

    // Seed data into this container
    try? PreviewData.seed(into: context)

    // Fetch one event safely
    let descriptor = FetchDescriptor<MedicationDoseEvent>()
    let event = (try? context.fetch(descriptor))?.first ?? {
        fatalError("No preview events available")
    }()
    
    // 4️⃣ Return the view with modelContainer attached
    return ScrollView {
        VStack(spacing: 16) {
            NextDoseCard(event: event)
        }
        .padding()
    }
    .modelContainer(container)
    .environment(themeManager)
    .environmentObject(NavigationRouter())
}
    


