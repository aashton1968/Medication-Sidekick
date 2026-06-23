//
//  CustomerInfoManager.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-01-27.
//


import Foundation
import RevenueCat
import Combine

@MainActor
final class SubscriptionService: NSObject, ObservableObject, PurchasesDelegate {
    static let freeMedicationLimit = 5
    private static let automaticRestoreRetryInterval: TimeInterval = 12 * 60 * 60

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isPro = false
    @Published private(set) var hasLoadedCustomerInfo = false
    @Published private(set) var subscriptionPriceDisclosure: String?

    private var hasStarted = false
    private var lastAutomaticRestoreAttempt: Date?

    override init() {
        super.init()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        Purchases.shared.delegate = self
        await refreshSubscriptionStatus(allowAutomaticRestore: true)
        await refreshPaywallDisclosure()
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateState(with: info)
        } catch {
            print("❌ Error fetching customer info: \(error)")
            hasLoadedCustomerInfo = true
        }
    }

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        updateState(with: info)
    }

    func syncPurchases() async {
        do {
            let info = try await Purchases.shared.syncPurchases()
            updateState(with: info)
        } catch {
            print("❌ Error syncing purchases: \(error)")
        }
    }

    func refreshSubscriptionStatus(allowAutomaticRestore: Bool) async {
        await refreshCustomerInfo()
        guard !isPro else { return }

        await syncPurchases()
        guard !isPro, allowAutomaticRestore else { return }

        await attemptAutomaticRestoreIfNeeded()
    }

    func refreshPaywallDisclosure() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages.first else {
                subscriptionPriceDisclosure = nil
                return
            }
            let title = package.storeProduct.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = package.storeProduct.localizedPriceString
            let period = package.storeProduct.subscriptionPeriod?.periodTitle ?? "subscription period"
            subscriptionPriceDisclosure = "\(title): \(price) / \(period), auto-renewing."
        } catch {
            subscriptionPriceDisclosure = nil
        }
    }

    func canAddMedication(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeMedicationLimit
    }

    var requiredEntitlementID: String {
        Constants.proEntitlementID
    }

    private func updateState(with info: CustomerInfo) {
        customerInfo = info
        isPro = info.entitlements[Constants.proEntitlementID]?.isActive == true
        hasLoadedCustomerInfo = true
    }

    private func attemptAutomaticRestoreIfNeeded() async {
        let now = Date()
        if let lastAutomaticRestoreAttempt,
           now.timeIntervalSince(lastAutomaticRestoreAttempt) < Self.automaticRestoreRetryInterval {
            return
        }
        lastAutomaticRestoreAttempt = now

        do {
            let info = try await Purchases.shared.restorePurchases()
            updateState(with: info)
        } catch {
            print("❌ Automatic restore attempt failed: \(error)")
        }
    }

    // MARK: - PurchasesDelegate
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.updateState(with: customerInfo)
        }
    }
}

typealias CustomerInfoManager = SubscriptionService

private extension SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return "period"
        }
    }
}

