//
//  NavigationRouter.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2025-11-16.
//

import SwiftUI

@Observable
final class NavigationRouter {
    var path = NavigationPath()
    var currentRoute: Route? = .home

    func navigate(_ route: Route) {
        if route == .home {
            path = NavigationPath()
        } else {
            path.append(route)
        }
        currentRoute = route
    }

    func reset() {
        path = NavigationPath()
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
