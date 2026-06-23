//
//  SidebarConfiguration.swift
//  SidebarMenuExample
//
//  Created by Alan Ashton on 2025-11-24.
//

import SwiftUI

// NEW: Configuration struct for sidebar appearance and behavior
struct SidebarConfiguration {
    let width: CGFloat
    let animationDuration: Double
    let minimumSwipeDistance: CGFloat
    let velocityThreshold: CGFloat
    
    static let `default` = SidebarConfiguration(
        width: 280,
        animationDuration: 0.3,
        minimumSwipeDistance: 50,
        velocityThreshold: 300
    )
}

