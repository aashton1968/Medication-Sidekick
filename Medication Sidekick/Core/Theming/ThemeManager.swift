//
//  ThemeManager.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2025-10-23.
//

import SwiftUI


@MainActor
@Observable
class ThemeManager {
    var selectedTheme: ThemeProtocol = Main()
    
    func setTheme(_ theme: ThemeProtocol) {
        selectedTheme = theme
    }
}
