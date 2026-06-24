import SwiftUI
import StoreKit

// TODO: Replace privacyPolicyURL with your actual privacy policy URL before shipping.
private let privacyPolicyURL = URL(string: "https://example.com/privacy")!
private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

struct SubscriptionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private let accentRed = Color(hex: "#C10007")

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    pricingCard
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                    featureList
                        .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            bottomBar
        }
        .task {
            if subscriptionService.proProduct == nil {
                await subscriptionService.refreshPaywallDisclosure()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geo in
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.65))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(accentRed)
            }

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text("Medication SideKick")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Pro Access")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground).opacity(0.9))
                        .frame(width: 30, height: 30)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentRed)
                }
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityLabel("Close")
        }
        .frame(height: 200)
    }

    // MARK: - Pricing Card

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("yearly")
                .font(.subheadline)
                .foregroundStyle(Color(.systemGray3))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(subscriptionService.proProduct?.displayPrice ?? "—")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                Text("/yr")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(.systemGray3))
            }

            if let monthly = monthlyPriceString() {
                Text("\(monthly) per month, billed annually")
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 20) {
            featureItem(
                heading: "Unlock Medications",
                body: "Unlock unlimited Medications"
            )
            featureItem(
                heading: "Share Medications",
                body: "Share your medication list with others."
            )
        }
    }

    private func featureItem(heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentRed)
            Text(body)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task { await purchase() }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue")
                                .font(.headline.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentRed)
                .disabled(isPurchasing || isRestoring || subscriptionService.proProduct == nil)
                .padding(.horizontal, 20)
                .accessibilityLabel("Subscribe to Medication SideKick Pro")

                if let product = subscriptionService.proProduct {
                    Text("Auto-renews for \(product.displayPrice)/year until cancelled")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 24) {
                    Button {
                        Task { await restore() }
                    } label: {
                        if isRestoring {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Restore Purchases")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .disabled(isPurchasing || isRestoring)

                    Link("Terms", destination: termsURL)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)

                    Link("Privacy", destination: privacyPolicyURL)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 8)
            }
            .padding(.top, 12)
            .background(Color(.secondarySystemBackground))
        }
    }

    // MARK: - Helpers

    private func monthlyPriceString() -> String? {
        guard let product = subscriptionService.proProduct,
              product.subscription?.subscriptionPeriod.unit == .year,
              product.subscription?.subscriptionPeriod.value == 1 else { return nil }
        let monthly = product.price / 12
        return monthly.formatted(product.priceFormatStyle)
    }

    private func purchase() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let success = try await subscriptionService.purchase()
            if success { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isPro { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SubscriptionSheetView()
        .environment(SubscriptionService())
}
