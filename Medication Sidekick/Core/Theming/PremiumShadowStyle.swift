//
//  PremiumShadowStyle.swift
//  Medication Sidekick
//
//  Created by Cursor on 2026-03-30.
//

import SwiftUI

struct PremiumCardShadowModifier: ViewModifier {
    let theme: ThemeProtocol

    func body(content: Content) -> some View {
        content
            .shadow(color: theme.shadowLevel1, radius: 3, x: 0, y: 1)
            .shadow(color: theme.shadowLevel2, radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.shadowTint.opacity(0.06), lineWidth: 1)
            )
    }
}

struct PremiumFloatingShadowModifier: ViewModifier {
    let theme: ThemeProtocol
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: theme.shadowLevel1, radius: 4, x: 0, y: 1)
            .shadow(color: theme.shadowLevel2, radius: 14, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.shadowTint.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func premiumCardShadow(theme: ThemeProtocol) -> some View {
        modifier(PremiumCardShadowModifier(theme: theme))
    }

    func premiumFloatingShadow(theme: ThemeProtocol, cornerRadius: CGFloat) -> some View {
        modifier(PremiumFloatingShadowModifier(theme: theme, cornerRadius: cornerRadius))
    }
}
