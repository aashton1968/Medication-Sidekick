//
//  NavigationRouter.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2025-11-16.
//

import SwiftUI

/// Top-level tabs shown in the tab bar.
enum AppTab: Hashable {
    case today
    case medicines
    case more
}

/// Owns tab selection plus one `NavigationPath` per tab, so pushing a detail
/// screen never replaces the tab bar. `navigate(_:)` picks the right tab for a route.
@Observable
final class NavigationRouter {
    var selectedTab: AppTab = .today
    var todayPath = NavigationPath()
    var medicinesPath = NavigationPath()
    var morePath = NavigationPath()
    var currentRoute: Route? = .home

    func navigate(_ route: Route) {
        switch route {
        case .home, .todayView:
            // Today has been rolled into Home.
            selectedTab = .today
            todayPath = NavigationPath()
        case .medications:
            selectedTab = .medicines
            medicinesPath = NavigationPath()
        case .medication, .medicationNew:
            selectedTab = .medicines
            medicinesPath.append(route)
        case .medicationSchedule, .mealTimeSettings, .settings, .help:
            selectedTab = .more
            morePath.append(route)
        }
        currentRoute = route
    }

    func reset() {
        todayPath = NavigationPath()
        medicinesPath = NavigationPath()
        morePath = NavigationPath()
        selectedTab = .today
        currentRoute = .home
    }
}


// Navigation Route
enum Route: Hashable {
    case home
    case todayView
    case medicationSchedule
    case medications
    case medication(id: UUID)
    case medicationNew
    case mealTimeSettings
    case settings
    case help
}

struct NavPreview<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        NavigationStack { content }
    }
}
