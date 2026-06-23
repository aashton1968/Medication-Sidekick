//
//  MainTheme.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2025-10-23.
//

import SwiftUI

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

    // Semantic status tokens
    var statusSuccess: Color { Color(hex: "#009999") }
    var statusError: Color { Color(hex: "#b30000")  }
    var statusInfo: Color { textSecondary }

    // Semantic shadow tokens
    var shadowTint: Color { accentPrimary }
    var shadowLevel1: Color { accentPrimary.opacity(0.08) }
    var shadowLevel2: Color { accentPrimary.opacity(0.06) }
    
}
