//
//  RouteDestinations.swift
//  Medication Sidekick
//
//  Shared `Route` -> view mapping applied to every tab's NavigationStack.
//

import SwiftUI
import SwiftData

private struct RouteDestinationsModifier: ViewModifier {
    @Environment(NavigationRouter.self) private var navigationRouter
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            destination(for: route)
                .environment(themeManager)
                .environment(navigationRouter)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .home, .todayView:
            EmptyView()
        case .medications:
            MedicationListView()
        case .medicationSchedule:
            MedicationSchedulesView()
        case .medicationNew:
            MedicationAddView()
        case .mealTimeSettings:
            MealTimeListView()
        case .settings:
            SettingsView()
        case .help:
            HelpView()
        case .medication(let id):
            medicationDestination(id: id)
        }
    }

    @ViewBuilder
    private func medicationDestination(id: UUID) -> some View {
        let descriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.id == id }
        )
        if let medication = try? modelContext.fetch(descriptor).first {
            MedicationDetailView(medicationID: medication.id)
        } else {
            Text("Medication not found")
        }
    }
}

extension View {
    func routeDestinations() -> some View {
        modifier(RouteDestinationsModifier())
    }
}
