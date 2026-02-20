//
//  NavigationRouter.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2025-11-16.
//

import SwiftUI
import Combine

@MainActor
final class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var currentRoute: Route? = .home

    func navigate(_ route: Route) {
        // optional: clear the path for "root" routes
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
