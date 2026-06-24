//
//  SettingsView.swift
//  Medication Sidekick
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscriptionService
    @AppStorage(AppStorageKeys.medicationNotificationsEnabled.rawValue) private var notificationsEnabled: Bool = true
    @AppStorage(AppStorageKeys.medicationReminderLeadTimeMinutes.rawValue) private var reminderLeadTimeMinutes: Int = 0
    @AppStorage(AppStorageKeys.notificationPrivacyEnabled.rawValue) private var notificationPrivacyEnabled: Bool = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var testNotificationMessage: String?
    @State private var testNotificationIsError = false
    @State private var restoreMessage: String?
    @State private var restoreIsError = false
    @State private var isRestoringPurchases = false
    @State private var cleanupMessage: String?
    @State private var cleanupIsError = false
    @State private var isRunningCloudCleanup = false

    private let notificationService = MedicationNotificationService()
    private let leadTimeOptions = [0, 5, 10, 15, 30, 60]

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Medication reminders", isOn: $notificationsEnabled)

                Toggle("Hide medication names in notifications", isOn: $notificationPrivacyEnabled)
                    .disabled(!notificationsEnabled)
                    .onChange(of: notificationPrivacyEnabled) { _, _ in
                        NotificationCenter.default.post(name: .medicationDidChange, object: nil)
                    }

                Picker("Reminder lead time", selection: $reminderLeadTimeMinutes) {
                    ForEach(leadTimeOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? "At scheduled time" : "\(minutes) minutes before")
                            .tag(minutes)
                    }
                }
                .disabled(!notificationsEnabled)

                Text(notificationStatusMessage)
                    .font(.caption)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)

                if isSettingsActionRequired {
                    Button("Open Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    Task {
                        await scheduleTestNotification()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.blue)
                        Text("Send Test Notification")
                        Spacer()
                        Text("Test")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }
                .disabled(!notificationsEnabled)

                if let testNotificationMessage {
                    Text(testNotificationMessage)
                        .font(.caption)
                        .foregroundStyle(testNotificationIsError ? .red : themeManager.selectedTheme.textSecondary)
                }
            }

            Section("Subscription") {
                HStack(spacing: 10) {
                    Image(systemName: subscriptionStatusIconName)
                        .foregroundStyle(subscriptionStatusIconColor)
                    Text(subscriptionStatusText)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    HStack {
                        Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
                        Spacer()
                        if isRestoringPurchases {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isRestoringPurchases)

                
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.caption)
                        .foregroundStyle(restoreIsError ? .red : themeManager.selectedTheme.textSecondary)
                }
                Text(subscriptionService.isPro ? "Pro Access is active." : "Free plan active (up to 5 medications).")
                    .font(.caption)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Auto-Renewable Subscription")
                        .font(.caption.weight(.semibold))
                    Text(subscriptionService.subscriptionPriceDisclosure ?? "Medication Sidekick Pro subscription details are shown on the purchase page.")
                        .font(.caption2)
                        .foregroundStyle(themeManager.selectedTheme.textSecondary)
                }
            }

            Section("Data Cleanup") {
                Button {
                    Task {
                        await runCloudCleanup()
                    }
                } label: {
                    HStack {
                        Label("Run Cloud Data Cleanup", systemImage: "arrow.triangle.2.circlepath.circle")
                        Spacer()
                        if isRunningCloudCleanup {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isRunningCloudCleanup)

                Text("Use this after signing into iCloud if medications or dose events appear duplicated.")
                    .font(.caption)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)

                if let cleanupMessage {
                    Text(cleanupMessage)
                        .font(.caption)
                        .foregroundStyle(cleanupIsError ? .red : themeManager.selectedTheme.textSecondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshNotificationStatus()
            await subscriptionService.refreshPaywallDisclosure()
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            Task {
                if isEnabled {
                    await notificationService.requestAuthorizationIfNeeded()
                    await refreshNotificationStatus()
                }
                NotificationCenter.default.post(name: .medicationDidChange, object: nil)
            }
        }
        .onChange(of: reminderLeadTimeMinutes) { _, newValue in
            let safeValue = leadTimeOptions.contains(newValue) ? newValue : 0
            if safeValue != newValue {
                reminderLeadTimeMinutes = safeValue
            }
            NotificationCenter.default.post(name: .medicationDidChange, object: nil)
        }
        .background(themeManager.selectedTheme.bgBase)

    }

    private var notificationStatusMessage: String {
        switch notificationStatus {
        case .authorized:
            return "Notifications are authorized."
        case .provisional:
            return "Notifications are provisionally authorized."
        case .ephemeral:
            return "Notifications are temporarily authorized."
        case .denied:
            return "Notifications are denied. Enable them in Settings to receive reminders."
        case .notDetermined:
            return "Notification permission has not been requested yet."
        @unknown default:
            return "Notification permission status is unknown."
        }
    }

    private var isSettingsActionRequired: Bool {
        notificationStatus == .denied
    }

    private var subscriptionStatusIconName: String {
        subscriptionService.isPro ? "crown.fill" : "person.crop.circle.badge.xmark"
    }

    private var subscriptionStatusIconColor: Color {
        subscriptionService.isPro ? .yellow : themeManager.selectedTheme.textMuted
    }

    private var subscriptionStatusText: String {
        subscriptionService.isPro ? "Pro Access" : "Free Access"
    }

    @MainActor
    private func refreshNotificationStatus() async {
        notificationStatus = await notificationService.authorizationStatus()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func scheduleTestNotification() async {
        do {
            try await notificationService.sendTestNotification()
            await refreshNotificationStatus()
            testNotificationIsError = false
            testNotificationMessage = "Test notification scheduled. You should receive it in about 5 seconds."
        } catch {
            await refreshNotificationStatus()
            testNotificationIsError = true
            testNotificationMessage = error.localizedDescription
        }
    }

    @MainActor
    private func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await subscriptionService.restorePurchases()
            restoreIsError = false
            restoreMessage = subscriptionService.isPro
                ? "Purchases restored successfully. Pro Access is now active."
                : "Restore completed. No active Pro Access subscription was found for this Apple ID."
        } catch {
            restoreIsError = true
            restoreMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func runCloudCleanup() async {
        isRunningCloudCleanup = true
        defer { isRunningCloudCleanup = false }

        // Run multiple passes because iCloud sync can deliver records in waves.
        let offsets: [Double] = [0, 4, 10]
        var previousOffset: Double = 0
        for offset in offsets {
            let stepDelay = max(0, offset - previousOffset)
            previousOffset = offset
            if stepDelay > 0 {
                try? await Task.sleep(for: .seconds(stepDelay))
            }

            await MedicationSeedService.shared.reconcileSeedDuplicates(container: modelContext.container)
            await MedicationSeedService.shared.reconcileCloudMedicationDuplicates(container: modelContext.container)
            await MedicationSeedService.shared.reconcileCloudDoseDuplicates(container: modelContext.container)
        }
        NotificationCenter.default.post(name: .medicationDidChange, object: nil)

        cleanupIsError = false
        cleanupMessage = "Cleanup complete for medication and dose duplicates. If iCloud is still syncing, run again after sync settles."
    }
}

#Preview {
    let theme = ThemeManager()
    NavPreview {
        SettingsView()
    }
    .environment(theme)
    .environment(SubscriptionService())
}
