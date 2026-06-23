//
//  ErrorHandler.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2024-08-12.
//

import SwiftUI
import Combine

@MainActor
class ErrorManager: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    func handleError(_ error: Error) {
        // Customize your error handling
        errorMessage = error.localizedDescription
        showError = true
    }
}

