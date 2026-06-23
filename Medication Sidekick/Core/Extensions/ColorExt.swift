//
//  ExtColor.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2024-12-30.
//
import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)

        // Remove the '#' if present
        if hex.hasPrefix("#") {
            scanner.currentIndex = hex.index(after: hex.startIndex)
        }

        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

import SwiftUI

extension Color {

    static let criticalLow    = Color(hex: "#D34A4A")
    static let lowBG          = Color(hex: "#9A6AC0")
    static let inRangeBG      = Color(hex: "#38D925")
    static let slightlyHighBG = Color(hex: "#2AEBBD")
    static let highBG         = Color(hex: "#E3A14F")
    static let veryHighBG     = Color(hex: "#4B88B3")
    static let criticalHigh  = Color(hex: "#B74343")
    
    
}
