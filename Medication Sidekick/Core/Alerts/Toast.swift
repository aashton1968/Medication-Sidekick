//
//  Toast.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-12-30.
//

import Foundation
import SwiftUI

enum ToastType {
    case error
    case success
    case general

    var icon: String {
        switch self {
        case .error: return "⚠️"
        case .success: return "✓"
        case .general: return "ℹ️"
        }
    }
}


struct ToastConfig {
    let message: String
    let type: ToastType
    let duration: TimeInterval
    let showIcon: Bool

    init(message: String, type: ToastType, duration: TimeInterval = 3.0, showIcon: Bool = true) {
        self.message = message
        self.type = type
        self.duration = duration
        self.showIcon = showIcon
    }
}

@MainActor
@Observable
class ToastManager {
    static let shared = ToastManager()

    var currentToast: ToastConfig?
    var isShowingToast = false

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(message: String, type: ToastType, duration: TimeInterval = 5.0, showIcon: Bool = true) {
        let config = ToastConfig(message: message, type: type, duration: duration, showIcon: showIcon)
        dismissTask?.cancel()

        currentToast = config
        isShowingToast = true

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(config.duration))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isShowingToast = false
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            currentToast = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isShowingToast = false
        }
        dismissTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            currentToast = nil
        }
    }
}

// MARK: - Convenience Methods

extension ToastManager {
    func showError(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .error, duration: duration)
    }

    func showSuccess(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .success, duration: duration)
    }

    func showGeneral(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .general, duration: duration)
    }
}


struct ToastModifier: ViewModifier {
    var manager = ToastManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                if manager.isShowingToast, let toast = manager.currentToast {
                    Button {
                            ToastManager.shared.dismiss()
                        } label: {
                            SwiftUIToastView(config: toast)
                        }
                        .buttonStyle(.plain)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                        .zIndex(999)
                }
                Spacer()
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: manager.isShowingToast)
        }
    }
}

