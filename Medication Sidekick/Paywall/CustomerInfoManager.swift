//
//  CustomerInfoManager.swift
//  Medication Sidekick
//

import Foundation
import Observation
import StoreKit
import os.log

@Observable
@MainActor
final class SubscriptionService {
    static let freeMedicationLimit = 5
    static let proProductID = "alanashton.com.medicationsidekick.pro.access.annual"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MedicationSidekick",
        category: "SubscriptionService"
    )

    private(set) var isPro = false
    private(set) var hasLoadedStatus = false
    private(set) var subscriptionPriceDisclosure: String?
    private(set) var proTransactionID: Transaction.ID?

    private(set) var proProduct: Product?
    private var updatesTask: Task<Void, Never>?
    private var hasStarted = false

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshPurchaseStatus()
                }
            }
        }

        await refreshPurchaseStatus()
        await loadProduct()
    }

    func refreshSubscriptionStatus(allowAutomaticRestore: Bool) async {
        await refreshPurchaseStatus()
    }

    func refreshPaywallDisclosure() async {
        await loadProduct()
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshPurchaseStatus()
    }

    func purchase() async throws -> PurchaseOutcome {
        guard let product = proProduct else { return .cancelled }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshPurchaseStatus()
                return .purchased
            }
            return .cancelled
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    func canAddMedication(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeMedicationLimit
    }

    // MARK: - Private

    private func refreshPurchaseStatus() async {
        var hasActiveSub = false
        var foundTransactionID: Transaction.ID?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                hasActiveSub = true
                foundTransactionID = transaction.id
                break
            }
        }
        isPro = hasActiveSub
        proTransactionID = foundTransactionID
        hasLoadedStatus = true
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
            if let product = proProduct {
                let period = product.subscription?.subscriptionPeriod.periodTitle ?? "year"
                subscriptionPriceDisclosure = "\(product.displayName): \(product.displayPrice) / \(period), auto-renewing."
            }
        } catch {
            Self.logger.error("Failed to load StoreKit products: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum PurchaseOutcome: Equatable {
    case purchased
    case cancelled
    case pending
}


private extension Product.SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .day:   return value == 1 ? "day" : "\(value) days"
        case .week:  return value == 1 ? "week" : "\(value) weeks"
        case .month: return value == 1 ? "month" : "\(value) months"
        case .year:  return value == 1 ? "year" : "\(value) years"
        @unknown default: return "period"
        }
    }
}
