//
//  SidebarContentView.swift
//  SidebarMenuExample
//
//  Created by Alan Ashton on 2025-11-24.
//
import SwiftUI

struct SidebarContentView: View {
    
    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(ThemeManager.self) var themeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Menu Items
            VStack(spacing: 0) {
                
                
                SidebarMenuItemView(icon: "text.rectangle.page", target: .todayView)
                SidebarMenuItemView(icon: "pill.circle", target: .medications)
                SidebarMenuItemView(icon: "calendar.circle.fill", target: .medicationSchedule)
                SidebarMenuItemView(icon: "fork.knife", target: .mealTimeSettings)
                SidebarMenuItemView(icon: "gearshape.fill", target: .settings)
                
            }
            .environmentObject(navigationRouter)
           
            
            Spacer()
            
            // Bottom Section
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 20)
                
                SidebarMenuItemView(icon: "questionmark.circle.fill", target: .help)
                   
            }
        }
        .background(
            LinearGradient(
                colors: [
                    themeManager.selectedTheme.bgSubtle.opacity(0.25),
                    themeManager.selectedTheme.bgSubtle.opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

enum SidebarMenuTargets {
    case todayView
    case medicationSchedule
    case medications
    case mealTimeSettings
    case settings
    case help

    var title: String {
        switch self {
        case .todayView:          "Today View"
        case .medications:        "Medications"
        case .medicationSchedule: "Medication Schedule"
        case .mealTimeSettings:   "Meal Times"
        case .settings:           "Settings"
        case .help:               "Help"
        }
    }
}

#Preview {
    
    let navigationRouter = NavigationRouter()
    let themeManager = ThemeManager()
    
    SidebarContentView()
        .environmentObject(navigationRouter)
        .environment(themeManager)
}
