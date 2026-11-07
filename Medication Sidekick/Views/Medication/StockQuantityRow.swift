//
//  StockQuantityRow.swift
//  Medication Sidekick
//
//  Shared "Current Stock" row for the Add, Edit and Edit Stock screens.
//
//  - Tapping anywhere on the row (label included) starts editing.
//  - The cursor starts at the right-hand end of the existing number.
//  - A "+" menu adds common refill sizes in two taps, or clears the count.
//

import SwiftUI
import UIKit

struct StockQuantityRow: View {

    @Binding var stock: Int

    @FocusState private var isFocused: Bool

    private static let quickAddAmounts = [10, 30, 60, 90, 100]
    private static let maximumStock = 100_000

    var body: some View {
        HStack(spacing: 12) {
            Text("Current Stock")
            Spacer()
            TextField("0", value: $stock, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .frame(minWidth: 60, maxWidth: 90)
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                    guard isFocused, let field = note.object as? UITextField else { return }
                    // Defer so UIKit has placed its own cursor first, then move it to the end.
                    DispatchQueue.main.async {
                        let end = field.endOfDocument
                        field.selectedTextRange = field.textRange(from: end, to: end)
                    }
                }
            Menu {
                ForEach(Self.quickAddAmounts, id: \.self) { amount in
                    Button("Add \(amount)") { stock = min(stock + amount, Self.maximumStock) }
                }
                Divider()
                Button("Clear", role: .destructive) { stock = 0 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel("Quick add stock")
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFocused {
                    Spacer()
                    Button("Done") { isFocused = false }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var stock = 42
    Form {
        StockQuantityRow(stock: $stock)
    }
}
