//
//  ThemeProtocol.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-10-23.
//

import SwiftUI

protocol ThemeProtocol {
    
    
    var navigationTitleFont: Font { get }
   
    
     // Colors

    // Semantic foundation tokens
    var bgBase: Color { get }
    var bgSubtle: Color { get }
    var surfaceBase: Color { get }
    var surfaceElevated: Color { get }
    var borderSubtle: Color { get }
    var borderDefault: Color { get }

    // Semantic text tokens
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textMuted: Color { get }
    var textOnAccent: Color { get }

    // Semantic accent tokens
    var accentPrimary: Color { get }
    var accentSecondary: Color { get }

    // Semantic status tokens
    var statusSuccess: Color { get }
    var statusError: Color { get }
    var statusInfo: Color { get }

    // Semantic shadow tokens
    var shadowTint: Color { get }
    var shadowLevel1: Color { get }
    var shadowLevel2: Color { get }

}
