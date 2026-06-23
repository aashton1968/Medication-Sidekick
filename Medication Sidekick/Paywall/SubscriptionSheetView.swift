import SwiftUI
import RevenueCatUI

struct SubscriptionSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            PaywallView(displayCloseButton: true)

            Button {
                dismiss()
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
}
