//
//  SlidingSidebar.swift
//  SidebarMenuExample
//
//  Created by Alan Ashton on 2025-11-24.
//

import SwiftUI
import Foundation

struct SlidingSidebar<Content: View, Sidebar: View>: View {
    // NEW: External binding support for parent view control
    @Binding var isOpen: Bool
    @State private var dragOffset: CGFloat = 0
    
    let content: Content
    let sidebar: Sidebar
    let configuration: SidebarConfiguration
    
    // NEW: Configurable initialization with multiple convenience initializers
    init(
        isOpen: Binding<Bool>,
        configuration: SidebarConfiguration = .default,
        @ViewBuilder content: () -> Content,
        @ViewBuilder sidebar: () -> Sidebar
    ) {
        self._isOpen = isOpen
        self.configuration = configuration
        self.content = content()
        self.sidebar = sidebar()
    }
    
    // NEW: Simple initializer for basic use cases
    init(
        isOpen: Binding<Bool>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder sidebar: () -> Sidebar
    ) {
        self.init(isOpen: isOpen, configuration: .default, content: content, sidebar: sidebar)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Main content stays in place so glass can render over it
                content
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Tap-to-close overlay (only active when sidebar is open)
                if isOpen {
                    Button {
                        withAnimation(animationCurve) {
                            isOpen = false
                        }
                    } label: {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                }

                // Sidebar panel with Liquid Glass on iOS 26+
                ZStack {
                    if #available(iOS 26.0, *) {
                        Rectangle()
                            .glassEffect(.regular, in: .rect)
                            .ignoresSafeArea()
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                    }
                    sidebar
                }
                .frame(width: configuration.width)
                .offset(x: isOpen ? dragOffset : -configuration.width + dragOffset)
                .animation(animationCurve, value: isOpen)
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        if isOpen {
                            dragOffset = max(-configuration.width, min(0, translation))
                        } else {
                            dragOffset = max(0, min(configuration.width, translation))
                        }
                    }
                    .onEnded { value in
                        let shouldToggle = shouldCompleteGesture(
                            translation: value.translation.width,
                            velocity: value.velocity.width
                        )
                        withAnimation(animationCurve) {
                            dragOffset = 0
                            if shouldToggle { isOpen.toggle() }
                        }
                    }
            )
        }
    }

    private var animationCurve: Animation {
        .easeInOut(duration: configuration.animationDuration)
    }
    
    private func shouldCompleteGesture(translation: CGFloat, velocity: CGFloat) -> Bool {
        if isOpen {
            let fastSwipeLeft = velocity < -configuration.velocityThreshold
            let draggedFarLeft = translation < -configuration.minimumSwipeDistance
            return fastSwipeLeft || draggedFarLeft
        } else {
            let fastSwipeRight = velocity > configuration.velocityThreshold
            let draggedFarRight = translation > configuration.minimumSwipeDistance
            return fastSwipeRight || draggedFarRight
        }
    }
}

// Custom Menu Item Component
struct SidebarMenuItemView: View {
    
    @EnvironmentObject var navigationRouter: NavigationRouter
    
    let icon: String
    //let title: String
    let target: SidebarMenuTargets
   
    private var currentTarget: SidebarMenuTargets? {
        SidebarMenuTargets.from(route: navigationRouter.currentRoute)
    }
    
    var body: some View {
        Button {
            navigationRouter.navigate(target.route)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)

                Text(target.title)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .background(
                currentTarget == target ? Color.blue.opacity(0.1) : Color.clear
            )
        }
        .buttonStyle(.plain)
    }
}


struct CurrentUserSettingsToken: Hashable, Codable {
    static let shared = CurrentUserSettingsToken()
}

extension SidebarMenuTargets {
    static func from(route: Route?) -> SidebarMenuTargets? {
        guard let route else { return nil }

        switch route {
        case .todayView:
            return .todayView
        case .medications:
            return .medications
        case .medicationSchedule:
            return .medicationSchedule
        case .mealTimeSettings:
            return .mealTimeSettings
        case .settings:
            return .settings
        case .help:
            return .help
        default:
            return nil
        }
    }
}

private extension SidebarMenuTargets {
    var route: Route {
        switch self {
        case .todayView: return .todayView
        case .medicationSchedule: return .medicationSchedule
        case .medications: return .medications
        case .mealTimeSettings: return .mealTimeSettings
        case .settings: return .settings
        case .help: return .help
        }
    }
}


#Preview {
    SlidingSidebar(isOpen: .constant(false)) {
        Color.white
            .overlay(
                Text("Main Content Area")
                    .font(.title)
            )
    } sidebar: {
        VStack {
            Text("Sidebar Menu")
                .font(.headline)
                .padding()
            Spacer()
        }
        .background(Color.gray.opacity(0.2))
        .padding()
    }
}
