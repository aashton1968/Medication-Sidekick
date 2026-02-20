//
//  NextDoseCard.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//

import SwiftUI
import SwiftData

// MARK: - Local Display Helpers

extension DoseStatus {
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .taken:     return "Taken"
        case .missed:    return "Missed"
        case .skipped:   return "Skipped"
        }
    }
}

// MARK: - Next Dose Card (Time-Slot)

struct NextDoseCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager

    let doses: [MedicationDose]
    let slotName: String
    let slotTime: String
    let slotSymbol: String

    private var handledCount: Int {
        doses.filter { $0.status == .taken || $0.status == .skipped }.count
    }

    private var hasScheduled: Bool {
        doses.contains { $0.status == .scheduled }
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
                }

                Spacer()

                Text("\(handledCount)/\(doses.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        themeManager.selectedTheme.primaryThemeAccentColor,
                        themeManager.selectedTheme.toolbarButtonAccentColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // ── Medication rows ──

            VStack(spacing: 0) {
                ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
                    SlotDoseRow(dose: dose)
                    if index < doses.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 4)

            // ── Bulk actions ──

            if hasScheduled {
                Divider()
                HStack(spacing: 12) {
                    Button {
                        markAllTaken()
                    } label: {
                        Label("Take All", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.selectedTheme.primaryThemeAccentColor)

                    Button {
                        skipAll()
                    } label: {
                        Label("Skip All", systemImage: "forward.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(themeManager.selectedTheme.cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Bulk Actions

    private func markAllTaken() {
        withAnimation {
            for dose in doses where dose.status == .scheduled {
                dose.markAsTaken()
            }
        }
    }

    private func skipAll() {
        withAnimation {
            for dose in doses where dose.status == .scheduled {
                dose.status = .skipped
                dose.updatedAt = Date()
            }
        }
    }
}

// MARK: - Slot Dose Row

private struct SlotDoseRow: View {

    let dose: MedicationDose

    private var effectiveStatus: DoseStatus {
        if dose.status != .scheduled { return dose.status }
        if Date() > dose.scheduledDate.addingTimeInterval(60 * 60) {
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
                    .foregroundStyle(.secondary)
            }

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
        .opacity(dose.status == .taken || dose.status == .skipped ? 0.5 : 1.0)
        .animation(.easeInOut, value: dose.status)
    }

    private func toggle() {
        withAnimation {
            if dose.status == .taken {
                dose.undoTaken()
            } else {
                dose.markAsTaken()
            }
        }
    }
}

// MARK: - Preview

#Preview("Next Dose Card") {

    let themeManager = ThemeManager()
    let container = PreviewData.container
    let context = container.mainContext

    try? PreviewData.seed(into: context)

    let descriptor = FetchDescriptor<MedicationDose>()
    let allDoses = (try? context.fetch(descriptor)) ?? []
    let sampleDoses = Array(allDoses.prefix(3))

    return ScrollView {
        VStack(spacing: 16) {
            NextDoseCard(
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
