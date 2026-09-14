//
//  ViewExt.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-10-18.
//
import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func isHidden(_ hidden: Bool, remove: Bool = false) -> some View {
        if hidden {
            if remove {
                EmptyView()
            } else {
                self.hidden()
            }
        } else {
            self
        }
    }
}

extension View {
    func toast() -> some View {
        self.modifier(ToastModifier())
    }

    /// Applies Liquid Glass. iOS 26 is the deployment floor, so no fallback branch is needed.
    func liquidGlass(in shape: some Shape = .rect) -> some View {
        self.glassEffect(in: shape)
    }
}


