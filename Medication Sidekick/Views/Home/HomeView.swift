//
//  HomeView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2024-10-31.
//

import SwiftUI
import SwiftData
import os.log

struct HomeView: View {
    
    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) var themeManager
    
    @State private var showAbout = false
    @State private var sidebarOpen = false
    @State private var schedules: [MedicationSchedule] = []
    
    let customConfig = SidebarConfiguration(
        width:  270,
        animationDuration: 0.4,
        minimumSwipeDistance: 80,
        velocityThreshold: 500
    )
    
    
    var body: some View {
        
        ZStack {
            NavigationStack(path: $navigationRouter.path) {
                SlidingSidebar(isOpen: $sidebarOpen, configuration: customConfig) {
                    Spacer()
                } sidebar: {
                    SidebarContentView()
                        .environmentObject(navigationRouter)
                        .navigationDestination(for: Route.self) { route in
                            destinationView(for: route)
                        }
                        // Menu Button
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                
                                Button(action: {
                                    sidebarOpen.toggle()
                                }) {
                                    Label {
                                        Text("Menu")
                                        
                                    } icon: {
                                        Image(systemName: "line.3.horizontal")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(themeManager.selectedTheme.toolbarForegroundColor)
                                            .accessibilityLabel("Menu")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(themeManager.selectedTheme.toolbarButtonAccentColor)
                            }
                            
                        }
                    
                        // Context menu
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    Button {
                                        showAbout = true
                                    } label: {
                                        Label("About", systemImage: "info.circle")
                                    }
                                    
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(themeManager.selectedTheme.toolbarButtonAccentColor)
                                        .accessibilityLabel("More")
                                }
                            }
                        }
                    
                        .toolbarBackground(Color(themeManager.selectedTheme.toolbarBackgroundColor), for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                    
                }
            }
        }
        .sheet(isPresented: $showAbout, content: {
            AboutView()
                .environment(themeManager)
        })
        
        .task {
            loadSchedules()
            generateSchedulesIfNeeded()
            
            if navigationRouter.path.isEmpty {
                navigationRouter.navigate(.todayView)
            }
        }
           
    }

    // MARK: - Navigation Destination Builder
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {

        case .home:
            EmptyView()

        case .todayView:
            TodayView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medications:
            MedicationListView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medicationSchedule:
            MedicationSchedulesView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medicationNew:
            MedicationAddView()
                .environmentObject(navigationRouter)
                .environment(themeManager)

        case .help:
            HelpView()
                .environment(themeManager)
                .environmentObject(navigationRouter)

        case .medication(let id):
            medicationDestination(id: id)
        }
    }

    // MARK: - Detail Fetch Helpers
    @ViewBuilder
    private func medicationDestination(id: UUID) -> some View {
        let descriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.id == id }
        )

        if let medication = try? modelContext.fetch(descriptor).first {
            MedicationDetailView(medication: medication)
                .environmentObject(navigationRouter)
                .environment(themeManager)
        } else {
            Text("Medication not found")
        }
    }
    
    @MainActor
    private func loadSchedules() {
        let now = Date()

        let descriptor = FetchDescriptor<MedicationSchedule>()

        do {
            let allSchedules = try modelContext.fetch(descriptor)

            schedules = allSchedules.filter { schedule in
                schedule.endDate == nil || schedule.endDate! >= now
            }
        } catch {
            os_log(.error, "Failed to load schedules: %{public}@", error.localizedDescription)
        }
    }
    
    @MainActor
    private func generateSchedulesIfNeeded() {
        for schedule in schedules {
            do {
                try MedicationDoseGenerator.generateUpcomingDoses(
                    for: schedule,
                    modelContext: modelContext
                )
            } catch {
                os_log(.error, "Dose generation failed: %{public}@", error.localizedDescription)
            }
        }
    }
}

#if DEBUG
#Preview {
    let themeManager = ThemeManager()
    return NavPreview {
        HomeView()
    }
    .modelContainer(PreviewData.container)
    .environmentObject(NavigationRouter())
    .environment(themeManager)
}
#endif
