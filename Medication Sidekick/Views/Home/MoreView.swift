//
//  MoreView.swift
//  Medication Sidekick
//
//  Replaces the old sliding sidebar: times of day, settings, help, about.
//

import SwiftUI

struct MoreView: View {

    @Environment(ThemeManager.self) var themeManager
    @State private var showAbout = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.mealTimeSettings) {
                    Label("Times of Day", systemImage: "sun.max")
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
