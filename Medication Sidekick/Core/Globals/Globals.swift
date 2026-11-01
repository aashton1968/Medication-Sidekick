//
//  Constants.swift
//  Magic Weather
//
//  Created by Cody Kerns on 12/14/20.
//

import Foundation
import SwiftUI
import UIKit

struct Constants {
    static let medicationMissedGracePeriod: TimeInterval = 2 * 60 * 60
}

@MainActor let feedback = UINotificationFeedbackGenerator()

extension Notification.Name {
    static let medicationDidChange = Notification.Name("medicationDidChange")
    static let medicationReminderOpened = Notification.Name("medicationReminderOpened")
    static let medicationRefillReminderOpened = Notification.Name("medicationRefillReminderOpened")
}

enum AppStorageKeys: String {
    case medicationNotificationsEnabled = "medicationNotificationsEnabled"
    case medicationReminderLeadTimeMinutes = "medicationReminderLeadTimeMinutes"
    case notificationPrivacyEnabled = "notificationPrivacyEnabled"
    case hasShownInitialSubscriptionPrompt = "hasShownInitialSubscriptionPrompt"
    case refillRemindersEnabled = "refillRemindersEnabled"
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

