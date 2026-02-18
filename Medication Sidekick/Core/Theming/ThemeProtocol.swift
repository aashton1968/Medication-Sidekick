//
//  ThemeProtocol.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-10-23.
//

import SwiftUI

protocol ThemeProtocol {
    
    
    var navigationTitleFont: Font { get }
    /*
    // Fonts Not in use
    var largeTitleFont: Font { get }
    var textTitleFont: Font { get }
    var bodyTextFont: Font { get }
    var captionTxtFont: Font { get }
    var subHeadlineFont: Font { get }
    var compactRowFont: Font { get }
    var normalBtnTitleFont: Font { get }
    var largeBtnTitleFont: Font { get }
    var gridRowFont: Font { get }
    var largeGridRowFont: Font { get }
     */
    
     // Colors

    var buttonColor: Color { get }
    var altButtonColor: Color { get }
    var toolbarBackgroundColor: Color { get }
    var toolbarForegroundColor : Color { get }
    var buttonBackgroundColor: Color { get }
    var headerBackgroundColor: Color { get }
    var headerForegroundColor: Color { get }
    var toolbarButtonAccentColor : Color { get }
    var destructiveButtonColor: Color { get }
    var bodyTextColorPrimary: Color { get }
    var primaryThemeBackgroundColor: Color { get }
    var primaryThemeAccentColor: Color { get }
    // Not in Use
    /*
     
     var buttonColor: Color { get }
     var altButtonColor: Color { get }
     var destructiveButtonColor: Color { get }
    var primaryThemeBackgroundColor: Color { get }
    var primaryThemeColor: Color { get }
    
    var gridTextColor: Color { get }
    
    
    
    var affirmBtnTitleColor: Color { get }
    var negativeBtnTitleColor: Color { get }
    var primaryButtonBackgroundColor: Color { get }
    var altButtonBackgroundColor: Color { get }
    var navigationTitleFont: Font { get }
     */
}
