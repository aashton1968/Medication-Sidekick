//
//  Constants.swift
//  Magic Weather
//
//  Created by Cody Kerns on 12/14/20.
//

import Foundation
import SwiftUI

/*
 Configuration file for your app's RevenueCat settings.
 */

struct Constants {
    // Keys are injected at build time from Config/Secrets.xcconfig → Info.plist.
    // Literals no longer live in source; see Config/Secrets.xcconfig.template for setup.
    static var revenueCatProductionKey: String {
        Bundle.main.infoDictionary?["RevenueCatProductionKey"] as? String ?? ""
    }
    static var revenueCatTestKey: String {
        Bundle.main.infoDictionary?["RevenueCatTestKey"] as? String ?? ""
    }

    static let medicationMissedGracePeriod: TimeInterval = 2 * 60 * 60

    static var revenueCatKey: String {
        #if targetEnvironment(simulator)
        #if DEBUG
        return revenueCatTestKey
        #else
        return revenueCatProductionKey
        #endif
        #else
        return revenueCatProductionKey
        #endif
    }

    /// Use this value only for `Purchases.configure`.
    ///
    /// RevenueCat’s SDK calls `fatalError` if a `test_` key is passed in Release builds.
    /// This guard ensures the production key is always used when building for non-debug.
    static var revenueCatKeyForPurchasesConfigure: String {
        let key = revenueCatKey
        #if DEBUG
        return revenueCatProductionKey
        #else
        if key.hasPrefix("test_") {
            return revenueCatProductionKey
        }
        return key
        #endif
    }

    static let proEntitlementID = "Medication Sidekick Pro"
}

@MainActor let feedback = UINotificationFeedbackGenerator()

extension Notification.Name {
    static let medicationDidChange = Notification.Name("medicationDidChange")
    static let medicationReminderOpened = Notification.Name("medicationReminderOpened")
}

enum AppStorageKeys: String {
    case medicationNotificationsEnabled = "medicationNotificationsEnabled"
    case medicationReminderLeadTimeMinutes = "medicationReminderLeadTimeMinutes"
    case notificationPrivacyEnabled = "notificationPrivacyEnabled"
    case revenueCatAppUserID = "revenueCatAppUserID"
    case hasShownInitialSubscriptionPrompt = "hasShownInitialSubscriptionPrompt"
}

@MainActor
enum InteractionGuard {
    private static let reconcileCooldown: TimeInterval = 10
    private static var lastDoseInteractionAt: Date = .distantPast

    static func markDoseInteraction() {
        lastDoseInteractionAt = Date()
    }

    static func shouldDeferBackgroundReconcile() -> Bool {
        Date().timeIntervalSince(lastDoseInteractionAt) < reconcileCooldown
    }
}

