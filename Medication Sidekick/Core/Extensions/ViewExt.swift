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

    /// Applies Liquid Glass on iOS 26+; falls back to a solid colour background on earlier OS versions.
    @ViewBuilder
    func liquidGlass(in shape: some Shape = .rect, fallback: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(fallback)
        }
    }
}


