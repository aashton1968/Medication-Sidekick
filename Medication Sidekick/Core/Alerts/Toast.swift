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

    var color: Color {
        switch self {
        case .error:
            return Color(red: 1.0, green: 0.42, blue: 0.42) // Soft red #FF6B6B
        case .success:
            return Color(red: 0.32, green: 0.81, blue: 0.4) // Soft green #51CF66
        case .general:
            return Color(red: 0.29, green: 0.33, blue: 0.41) // Dark gray #4A5568
        }
    }

    var uiColor: UIColor {
        switch self {
        case .error:
            return UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0)
        case .success:
            return UIColor(red: 0.32, green: 0.81, blue: 0.4, alpha: 1.0)
        case .general:
            return UIColor(red: 0.29, green: 0.33, blue: 0.41, alpha: 1.0)
        }
    }

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

    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    /// Main method to show toast
    func show(message: String, type: ToastType, duration: TimeInterval = 3.0, showIcon: Bool = true) {
        let config = ToastConfig(message: message, type: type, duration: duration, showIcon: showIcon)

        showSwiftUIToast(config: config)
    }

    /// SwiftUI toast presentation
    private func showSwiftUIToast(config: ToastConfig) {
        // Cancel any existing dismiss work
        dismissWorkItem?.cancel()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.currentToast = config
            self.isShowingToast = true

            // Create new dismiss work item
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.isShowingToast = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.currentToast = nil
                }
            }

            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + config.duration, execute: workItem)
        }
    }

    /// Get key window (iOS 13+ compatible)
    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else if #available(iOS 13.0, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }

    /// Dismiss current toast immediately
    func dismiss() {
        dismissWorkItem?.cancel()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                self.isShowingToast = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.currentToast = nil
            }
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
                    SwiftUIToastView(config: toast)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                        .zIndex(999)
                        .onTapGesture {
                            ToastManager.shared.dismiss()
                        }
                }
                Spacer()
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: manager.isShowingToast)
        }
    }
}

// MARK: - SwiftUI Toast View

struct Oct30View: View {
    var body: some View {
        VStack(spacing: 20) {
            Button("Show Error Toast") {
                ToastManager.shared.showError("Something went wrong!")
            }

            Button("Show Success Toast") {
                ToastManager.shared.showSuccess("Operation completed!")
            }

            Button("Show General Toast") {
                ToastManager.shared.showGeneral("This is a notification")
            }

            Button("Custom Toast") {
                ToastManager.shared.show(
                    message: "Custom message here",
                    type: .success,
                    duration: 5.0,
                    showIcon: false
                )
            }
        }
        //.toast() // Add this modifier to enable toast
    }
}

#Preview("SwiftUI Toast") {
    Oct30View()
}

