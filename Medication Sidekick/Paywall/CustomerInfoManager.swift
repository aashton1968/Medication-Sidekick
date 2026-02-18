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
class CustomerInfoManager: NSObject, ObservableObject, PurchasesDelegate {
    
    @Published var customerInfo: CustomerInfo?
    @Published var isPro: Bool = false
    
    override init() {
        super.init()
        
        Task {
            await refreshCustomerInfo()
        }
        
        // RevenueCat delegate must be NSObject-based
        Purchases.shared.delegate = self
    }
    
    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            await updateState(with: info)
        } catch {
            print("❌ Error fetching customer info: \(error)")
        }
    }
    
    private func updateState(with info: CustomerInfo) {
        self.customerInfo = info
        self.isPro = info.entitlements[Constants.proEntitlementID]?.isActive == true
    }
    
    // MARK: - PurchasesDelegate
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.updateState(with: customerInfo)
        }
    }
}

