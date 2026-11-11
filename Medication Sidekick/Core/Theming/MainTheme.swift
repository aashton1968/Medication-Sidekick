//
//  MainTheme.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2025-10-23.
//

import SwiftUI
import UIKit

struct Main: ThemeProtocol {
   
   
   // Fonts
    var navigationTitleFont: Font = .custom("MartelSans-ExtraBold", size: 26.0).bold()
    
    
    // Semantic foundation tokens
    var bgBase: Color { Color("mnBgBase") }
    var bgSubtle: Color { Color("mnBgSubtle") }
    var surfaceBase: Color { Color("mnSurfaceBase") }
    var surfaceElevated: Color { Color("mnSurfaceElevated") }
    var borderSubtle: Color { Color("mnBorderSubtle") }
    var borderDefault: Color { Color("mnBorderDefault") }

    // Semantic text tokens
    var textPrimary: Color { Color("mnTextPrimary") }
    var textSecondary: Color { Color("mnTextSecondary") }
    var textMuted: Color { Color("mnTextMuted") }
    var textOnAccent: Color { .white }

    // Semantic accent tokens
    var accentPrimary: Color { Color("mnPrimaryAccentColor") }
    var accentSecondary: Color { Color("mnButtonBackgroundColorEnd") }
    var accentTint: Color { Color("mnAccentTint") }

    // Semantic status tokens
    var statusSuccess: Color { Color(hex: "#009999") }
    /// Dark red in light mode; a lighter red in dark mode so text and dots stay legible on dark surfaces.
    var statusError: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.42, blue: 0.40, alpha: 1)   // #FF6B66
                : UIColor(red: 0.70, green: 0.0, blue: 0.0, alpha: 1)    // #B30000
        })
    }
    var statusInfo: Color { textSecondary }

    // Semantic shadow tokens
    var shadowTint: Color { accentPrimary }
    var shadowLevel1: Color { accentPrimary.opacity(0.08) }
    var shadowLevel2: Color { accentPrimary.opacity(0.06) }
    
}
