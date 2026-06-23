//
//  Structs.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-10-24.
//
import SwiftUI
import Foundation
import SwiftData

struct MenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void
}





struct NavigationRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .padding(.trailing, 6)
            }
    }
}

extension View {
    func navigationRow() -> some View {
        self.modifier(NavigationRowModifier())
    }
}



