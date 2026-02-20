//
//  MainTheme.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-10-23.
//

import SwiftUI

struct Main: ThemeProtocol {
   
   
   // Fonts
    var navigationTitleFont: Font = .custom("MartelSans-ExtraBold", size: 26.0).bold()
    
    
    // Colors
    var buttonColor: Color { return Color("mnButtonColor") }
    var altButtonColor: Color { return Color("mnAltButtonColor") }

    var primaryThemeColor: Color { return Color("mnPrimaryThemeColor") }
    var primaryThemeBackgroundColor: Color { return Color("mnPrimaryThemeBackgroundColor") }
    var primaryThemeAccentColor: Color { return Color("mnPrimaryAccentColor") }
    
    var buttonBackgroundColor: Color { return Color("mnButtonBackgroundColor") }
    var destructiveButtonColor: Color { return Color("mnDestructiveButtonColor") }
    var cardBackgroundColor: Color { return Color("mnCardBackgroundColor") }
    var headerForegroundColor: Color { return Color("mnHeaderForegroundColor") }
    
    var toolbarForegroundColor: Color { return Color("mnToolbarForegroundColor") }
    var toolbarBackgroundColor: Color { return Color("mnToolbarBackgroundColor") }
    var toolbarButtonAccentColor: Color { return Color("mnToolbarButtonAccentColor") }
    
    var bodyTextColorPrimary: Color { return Color("mnBodyTextColorPrimary") }
    
}
