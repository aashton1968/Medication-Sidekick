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
                // Main content area
                content
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .contentShape(Rectangle())
                    .offset(x: isOpen ? configuration.width + dragOffset : dragOffset)
                    .animation(animationCurve, value: isOpen)
                    .onTapGesture {
                        if isOpen {
                            withAnimation(animationCurve) {
                                isOpen = false
                            }
                        }
                    }
                
                // Sidebar
                sidebar
                    .frame(width: configuration.width)
                    .offset(x: isOpen ? dragOffset : -configuration.width + dragOffset)
                    .animation(animationCurve, value: isOpen)
            }
            .gesture(
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
                        let translationWidth = value.translation.width
                        let velocityWidth = value.velocity.width
                        
                        let shouldToggle = shouldCompleteGesture(
                            translation: translationWidth,
                            velocity: velocityWidth
                        )
                        
                        withAnimation(animationCurve) {
                            dragOffset = 0
                            if shouldToggle {
                                isOpen.toggle()
                            }
                        }
                    }
            )
        }
    }
    
    // UPDATED: Uses configuration values instead of hardcoded constants
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
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
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
        .onTapGesture {
            // Handle menu item tap
            print("Tapped \(target.title)")
            navigationRouter.navigate(target.route)
        }
        
        
    }
}


struct CurrentUserSettingsToken: Hashable, Codable {
    static let shared = CurrentUserSettingsToken()
}

extension SidebarMenuTargets {
    static func from(route: Route?) -> SidebarMenuTargets? {
        guard let route else { return nil }

        switch route {
        case .home:
            return .home
        case .todayView:
            return .todayView
        case .medications:
            return .medications
        case .medicationSchedule:
            return .medicationSchedule
        case .mealTimeSettings:
            return .mealTimeSettings
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
        case .home: return .home
        case .todayView: return .todayView
        case .medicationSchedule: return .medicationSchedule
        case .medications: return .medications
        case .mealTimeSettings: return .mealTimeSettings
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
