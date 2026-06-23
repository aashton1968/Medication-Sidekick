//
//  MedicationListView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

import SwiftUI
import SwiftData
import RevenueCat
import RevenueCatUI

struct MedicationListView: View {
    private enum PremiumAction {
        case addMedication
        case shareMedications
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    @Environment(NavigationRouter.self) var navigationRouter
    @EnvironmentObject var subscriptionService: SubscriptionService
    
    @Query
    private var medications: [Medication]

    @State private var showingAdd = false
    @State private var showingPaywall = false
    @State private var showingPaywallMessage = false
    @State private var paywallMessageTitle = "Subscription"
    @State private var paywallMessageBody = ""
    @State private var pendingPremiumAction: PremiumAction?
    
    private var sortedMedications: [Medication] {
        medications.sorted { lhs, rhs in
            let lhsName = lhs.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let rhsName = rhs.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let byName = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if byName != .orderedSame {
                return byName == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var body: some View {
        List {

            if sortedMedications.isEmpty {
                ContentUnavailableView(
                    "No Medications",
                    systemImage: "pills",
                    description: Text("Tap + to add your first medication")
                )
            }

            ForEach(sortedMedications) { medication in
                Button {
                    navigationRouter.navigate(.medication(id: medication.id))
                } label: {
                    MedicationRow(medication: medication)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                        Button {
                            navigationRouter.navigate(.medication(id: medication.id))
                        } label: {
                            Label("View Details", systemImage: "eye")
                        }
                        Divider()

                        Button(role: .destructive) {
                            deleteMedication(medication)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete(perform: delete)
        }
        
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !sortedMedications.isEmpty {
                        Button {
                            if subscriptionService.isPro {
                                presentShareSheet()
                            } else {
                                pendingPremiumAction = .shareMedications
                                showingPaywall = true
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .accessibilityLabel("Share Medications")
                        }
                    }

                    Button {
                        if subscriptionService.canAddMedication(currentCount: sortedMedications.count) {
                            pendingPremiumAction = nil
                            showingAdd = true
                        } else {
                            pendingPremiumAction = .addMedication
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .accessibilityLabel("Add Medication")
                    }
                }
            }
        }
        
        .sheet(isPresented: $showingAdd) {
            MedicationAddView()
        }
        .sheet(isPresented: $showingPaywall) {
            VStack(spacing: 12) {
                PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        handlePaywallSuccess(with: customerInfo, source: "Purchase")
                    }
                    .onPurchaseFailure { error in
                        paywallMessageTitle = "Purchase Failed"
                        paywallMessageBody = error.localizedDescription
                        showingPaywallMessage = true
                    }
                    .onRestoreCompleted { customerInfo in
                        handlePaywallSuccess(with: customerInfo, source: "Restore")
                    }
                    .onRestoreFailure { error in
                        paywallMessageTitle = "Restore Failed"
                        paywallMessageBody = error.localizedDescription
                        showingPaywallMessage = true
                    }

                Button {
                    showingPaywall = false
                } label: {
                    Text("Dismiss for now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#C10007"))
                .padding(.horizontal)
                .padding(.bottom, 12)
                .accessibilityLabel("Dismiss subscription for now")
            }
        }
        .alert(paywallMessageTitle, isPresented: $showingPaywallMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(paywallMessageBody)
        }
    }

    @MainActor
    private func handlePaywallSuccess(with customerInfo: CustomerInfo, source: String) {
        let hasEntitlement = customerInfo.entitlements[subscriptionService.requiredEntitlementID]?.isActive == true
        guard hasEntitlement else {
            paywallMessageTitle = "\(source) Complete"
            paywallMessageBody = "No active \(subscriptionService.requiredEntitlementID) subscription was found for this Apple ID."
            showingPaywallMessage = true
            pendingPremiumAction = nil
            return
        }

        let nextAction = pendingPremiumAction
        pendingPremiumAction = nil
        showingPaywall = false

        // Presenting another sheet or UIActivityViewController in the same turn as dismissing
        // the paywall sheet often crashes; defer until after the dismiss transaction completes.
        Task { @MainActor in
            switch nextAction {
            case .shareMedications:
                presentShareSheet()
            case .addMedication:
                showingAdd = true
            case .none:
                showingAdd = true
            }
        }
    }

    private var shareMedicationsText: String {
        var lines: [String] = []
        lines.append("My Medications")
        lines.append(String(repeating: "─", count: 40))

        for med in sortedMedications {
            let unit = med.stockUnit.displayName.lowercased()
            let qty = "\(med.doseQuantity) \(unit)/dose"
            lines.append("\(med.name)\t\(med.dosage)\t\(qty)\t\(med.frequency.displayName)")
        }

        lines.append(String(repeating: "─", count: 40))
        lines.append("Shared from Medication Sidekick")
        return lines.joined(separator: "\n")
    }

    private func presentShareSheet() {
        let renderer = ImageRenderer(content: MedicationShareView(medications: sortedMedications))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image, shareMedicationsText],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(activityVC, animated: true)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let medication = sortedMedications[index]
            modelContext.delete(medication)
        }

        do {
            try modelContext.save()
        } catch {
            ToastManager.shared.showError("Could not delete medication. Please try again.")
            return
        }
        NotificationCenter.default.post(name: .medicationDidChange, object: nil)
    }

    private func deleteMedication(_ medication: Medication) {
        modelContext.delete(medication)
        do {
            try modelContext.save()
        } catch {
            ToastManager.shared.showError("Could not delete medication. Please try again.")
            return
        }
        NotificationCenter.default.post(name: .medicationDidChange, object: nil)
    }
}

#Preview {
    let container = PreviewData.container
    let context = container.mainContext

    let existing = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
    if existing.isEmpty {
        PreviewData.seed(into: context)
    }

    return MedicationListView()
        .modelContainer(container)
        .environment(NavigationRouter())
        .environmentObject(SubscriptionService())
        .environment(ThemeManager())
}

struct MedicationRow: View {
    @Environment(ThemeManager.self) private var themeManager

    @Query(sort: \MealTimeSetting.sortOrder)
    private var mealTimeSettings: [MealTimeSetting]

    let medication: Medication

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: medication.medicationType.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(medication.name)
                    .font(.headline)

                Text(medication.dosage)
                    .font(.subheadline)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)

                if !medication.mealsRaw.isEmpty {
                    Text(medication.mealDisplayNames(settings: mealTimeSettings).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(themeManager.selectedTheme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: medication.stockLevel.symbolName)
                .foregroundStyle(stockLevelColor(medication.stockLevel))
                .font(.system(size: 14))
        }
        .padding(.vertical, 4)
    }

    private func stockLevelColor(_ level: StockLevel) -> Color {
        switch level {
        case .good:              return .green
        case .warning:           return .orange
        case .critical, .empty:  return .red
        }
    }
}

// MARK: - Share Image View

struct MedicationShareView: View {
    @Environment(ThemeManager.self) private var themeManager

    let medications: [Medication]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Medications")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Medication").fontWeight(.semibold)
                    Text("Dose").fontWeight(.semibold)
                    Text("Qty / Dose").fontWeight(.semibold)
                    Text("Frequency").fontWeight(.semibold)
                }
                .font(.subheadline)

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                ForEach(medications) { med in
                    GridRow {
                        Text(med.name)
                        Text(med.dosage)
                        Text("\(med.doseQuantity) \(med.stockUnit.displayName.lowercased())")
                        Text(med.frequency.displayName)
                    }
                    .font(.subheadline)
                }
            }

            Divider()

            Text("Shared from Medication Sidekick")
                .font(.caption)
                .foregroundStyle(themeManager.selectedTheme.textSecondary)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .environment(\.colorScheme, .light)
    }
}

