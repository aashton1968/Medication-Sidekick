//
//  MoreView.swift
//  Medication Sidekick
//
//  Replaces the old sliding sidebar: schedules, meal times, settings, help, about.
//

import SwiftUI

struct MoreView: View {

    @Environment(ThemeManager.self) var themeManager
    @State private var showAbout = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.medicationSchedule) {
                    Label("Medication Schedule", systemImage: "calendar.circle.fill")
                }
                NavigationLink(value: Route.mealTimeSettings) {
                    Label("Meal Times", systemImage: "fork.knife")
                }
            }

            Section {
                NavigationLink(value: Route.settings) {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }

            Section {
                NavigationLink(value: Route.help) {
                    Label("Help", systemImage: "questionmark.circle.fill")
                }
                Button {
                    showAbout = true
                } label: {
                    Label("About", systemImage: "info.circle")
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("More")
        .sheet(isPresented: $showAbout) {
            AboutView()
                .environment(themeManager)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MoreView()
    }
    .environment(NavigationRouter())
    .environment(ThemeManager())
}
#endif
