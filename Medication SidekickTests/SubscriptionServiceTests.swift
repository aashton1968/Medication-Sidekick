import Testing
import StoreKit
import StoreKitTest
@testable import Medication_Sidekick

extension Tag {
    @Tag static var storeKitIntegration: Self
}

// MARK: - SubscriptionService

@Suite(.serialized)
@MainActor
struct SubscriptionServiceTests {

    // MARK: Initial state

    @Test func `isPro starts false`() {
        let sut = SubscriptionService()
        #expect(sut.isPro == false)
    }

    @Test func `hasLoadedStatus starts false`() {
        let sut = SubscriptionService()
        #expect(sut.hasLoadedStatus == false)
    }

    @Test func `proProduct starts nil`() {
        let sut = SubscriptionService()
        #expect(sut.proProduct == nil)
    }

    @Test func `subscriptionPriceDisclosure starts nil`() {
        let sut = SubscriptionService()
        #expect(sut.subscriptionPriceDisclosure == nil)
    }

    @Test func `proTransactionID starts nil`() {
        let sut = SubscriptionService()
        #expect(sut.proTransactionID == nil)
    }

    // MARK: Constants

    @Test func `freeMedicationLimit is 5`() {
        #expect(SubscriptionService.freeMedicationLimit == 5)
    }

    @Test func `proProductID matches expected value`() {
        #expect(SubscriptionService.proProductID == "alanashton.com.medicationsidekick.pro.access.annual")
    }

    // MARK: canAddMedication — free tier boundary tests

    @Test(arguments: [0, 1, 2, 3, 4])
    func `canAddMedication returns true below the free limit`(count: Int) {
        let sut = SubscriptionService()
        #expect(
            sut.canAddMedication(currentCount: count),
            "Expected true for count \(count) (below limit of \(SubscriptionService.freeMedicationLimit))"
        )
    }

    @Test(arguments: [5, 6, 10, 100])
    func `canAddMedication returns false at or above the free limit`(count: Int) {
        let sut = SubscriptionService()
        #expect(
            sut.canAddMedication(currentCount: count) == false,
            "Expected false for count \(count) (at or above limit of \(SubscriptionService.freeMedicationLimit))"
        )
    }

    // MARK: purchase() — no product loaded

    @Test func `purchase returns cancelled when proProduct is nil`() async throws {
        let sut = SubscriptionService()
        let outcome = try await sut.purchase()
        #expect(outcome == .cancelled)
    }

    // MARK: StoreKit integration — start()

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `start sets hasLoadedStatus to true`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()

        #expect(sut.hasLoadedStatus, "hasLoadedStatus should be true after start() completes")
    }

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `start loads proProduct`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()

        #expect(sut.proProduct != nil, "proProduct should be set after start()")
    }

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `start populates subscriptionPriceDisclosure`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()

        let disclosure = try #require(sut.subscriptionPriceDisclosure)
        #expect(disclosure.isEmpty == false, "Disclosure should be non-empty")
        #expect(disclosure.contains("year"), "Disclosure should mention the billing period")
        #expect(disclosure.contains("auto-renewing"), "Disclosure should mention auto-renewal")
    }

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `start is idempotent — second call is a no-op`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        let firstProductID = sut.proProduct?.id

        await sut.start()
        #expect(sut.proProduct?.id == firstProductID, "Product ID should not change on a second start() call")
    }

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `refreshPaywallDisclosure reloads product and disclosure`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        let originalProductID = try #require(sut.proProduct?.id, "Product must be set after start()")

        await sut.refreshPaywallDisclosure()

        #expect(sut.proProduct?.id == originalProductID, "Product ID should remain the same after refreshPaywallDisclosure()")
        #expect(sut.subscriptionPriceDisclosure != nil, "Disclosure should still be populated after refresh")
    }

    // MARK: StoreKit integration — purchase status

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `isPro becomes true when an active subscription exists`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        try await session.buyProduct(identifier: SubscriptionService.proProductID)
        try await AppStore.sync()
        await sut.refreshSubscriptionStatus(allowAutomaticRestore: false)

        #expect(sut.isPro, "isPro should be true when an active subscription exists")
        #expect(sut.proTransactionID != nil, "proTransactionID should be populated with an active subscription")
    }

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `isPro reverts to false after subscription is revoked`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        try await session.buyProduct(identifier: SubscriptionService.proProductID)
        try await AppStore.sync()
        await sut.refreshSubscriptionStatus(allowAutomaticRestore: false)
        #expect(sut.isPro, "Precondition: isPro must be true before revocation")

        session.clearTransactions()
        try await Task.sleep(for: .milliseconds(100))
        await sut.refreshSubscriptionStatus(allowAutomaticRestore: false)

        #expect(sut.isPro == false, "isPro should revert to false after the subscription is revoked")
        #expect(sut.proTransactionID == nil, "proTransactionID should be nil after revocation")
    }

    // MARK: StoreKit integration — canAddMedication when pro

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)), arguments: [0, 5, 6, 100])
    func `canAddMedication is always true when isPro`(count: Int) async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        try await session.buyProduct(identifier: SubscriptionService.proProductID)
        try await AppStore.sync()
        await sut.refreshSubscriptionStatus(allowAutomaticRestore: false)
        try #require(sut.isPro, "Precondition: must be pro for this test")

        #expect(
            sut.canAddMedication(currentCount: count),
            "Pro users should bypass the free limit (tested count: \(count))"
        )
    }

    // MARK: StoreKit integration — restorePurchases

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `restorePurchases sets isPro when an active subscription exists`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        try await session.buyProduct(identifier: SubscriptionService.proProductID)
        try await Task.sleep(for: .milliseconds(300))
        try await sut.restorePurchases()

        #expect(sut.isPro, "isPro should be true after restoring an active subscription")
    }

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `restorePurchases leaves isPro false when no subscription exists`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.clearTransactions()

        let sut = SubscriptionService()
        try await sut.restorePurchases()

        #expect(sut.isPro == false, "isPro should remain false when there is nothing to restore")
    }

    // MARK: StoreKit integration — purchase() outcomes

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `purchase returns purchased on successful transaction`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        try #require(sut.proProduct != nil, "Product must load before purchase can complete")

        let outcome = try await sut.purchase()

        #expect(outcome == .purchased, "A successful transaction should return .purchased")
        #expect(sut.isPro, "isPro should be true after a successful purchase")
    }

    @Test(.tags(.storeKitIntegration), .timeLimit(.minutes(1)))
    func `purchase returns pending when Ask to Buy is enabled`() async throws {
        let session = try SKTestSession(configurationFileNamed: "TestProducts")
        session.disableDialogs = true
        session.askToBuyEnabled = true
        session.clearTransactions()

        let sut = SubscriptionService()
        await sut.start()
        try #require(sut.proProduct != nil, "Product must load before purchase")

        let outcome = try await sut.purchase()

        #expect(outcome == .pending, "Ask to Buy should produce a .pending outcome")
        #expect(sut.isPro == false, "isPro should remain false while purchase is pending approval")
    }
}
