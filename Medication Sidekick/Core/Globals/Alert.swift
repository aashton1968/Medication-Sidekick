//
//  Alert.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-12-30.
//
import Foundation
import SwiftUI
import SwiftUI

public struct YAlertView {
    
    public enum AlertState {
        case withCancel
        case withOutCancel
    }
    
    public enum AlertStyle {
        case alert
        case actionSheet
    }
    
    public static func showAlert(
        state: AlertState,
        title: String,
        description: String,
        okButtonTitle: String = "Ok",
        cancelButtonTitle: String = "Cancel",
        preferredStyle: AlertStyle = .alert,
        okAction: ((UIAlertAction) -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            let alertController: UIAlertController
            switch preferredStyle {
            case .alert:
                alertController = UIAlertController(title: title, message: description, preferredStyle: .alert)
            case .actionSheet:
                alertController = UIAlertController(title: title, message: description, preferredStyle: .actionSheet)
            }
            
            alertController.addAction(UIAlertAction(title: okButtonTitle, style: .default, handler: okAction))
            
            if state == .withCancel {
                alertController.addAction(UIAlertAction(title: cancelButtonTitle, style: .cancel, handler: nil))
            }
            
            if var topController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                topController.present(alertController, animated: true, completion: nil)
            }
        }
    }
}
#Preview {
    VStack(spacing: 25) {
        Text("Alert View Preview")
        
        // Show Alert with cancel button
        Button("Show Alert with Cancel") {
            YAlertView.showAlert(
                state: .withCancel,
                title: "Alert Title",
                description: "This is an alert with a cancel button.",
                okAction: { _ in print("Ok Action") }
            )
        }
        
        // Show Alert without cancel button
        Button("Show Alert without Cancel") {
            YAlertView.showAlert(
                state: .withOutCancel,
                title: "Alert Title",
                description: "This is an alert without a cancel button.",
                okAction: { _ in print("Ok Action") }
            )
        }
        
        // Show Action Sheet with cancel button
        Button("Show Action Sheet with Cancel") {
            YAlertView.showAlert(
                state: .withCancel,
                title: "Action Sheet Title",
                description: "This is an action sheet with a cancel button.",
                okButtonTitle: "Logout",
                preferredStyle: .actionSheet,
                okAction: { _ in print("Ok Action") }
            )
        }
        
        // Show Action Sheet without cancel button
        Button("Show Action Sheet without Cancel") {
            YAlertView.showAlert(
                state: .withOutCancel,
                title: "Action Sheet Title",
                description: "This is an action sheet without a cancel button.",
                okButtonTitle: "Logout",
                preferredStyle: .actionSheet,
                okAction: { _ in print("Ok Action") }
            )
        }
    }
    .padding()
}
