//
//  Toast.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2026-01-08.
//

import SwiftUI

// MARK: - SwiftUI Toast View

struct SwiftUIToastView: View {
    let config: ToastConfig
    @Environment(ThemeManager.self) private var themeManager
    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    
    private var toastBackgroundColor: Color {
        switch config.type {
        case .error:
            return themeManager.selectedTheme.statusError
        case .success:
            return themeManager.selectedTheme.statusSuccess
        case .general:
            return themeManager.selectedTheme.statusInfo
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if config.showIcon {
                Text(config.type.icon)
                    .font(.system(size: 20))
            }

            Text(config.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.selectedTheme.textOnAccent)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(toastBackgroundColor)
        .cornerRadius(12)
        .premiumFloatingShadow(theme: themeManager.selectedTheme, cornerRadius: 12)
        .padding(.horizontal, 16)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
                opacity = 1
            }
        }
    }
}


