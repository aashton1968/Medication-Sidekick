//
//  AboutView.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2025-12-29.
//

import SwiftUI

struct AboutView: View {
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (Build \(build))"
    }

    
    var body: some View {
       
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header
                    Text("Diabetic Sidekick")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top)
                    
                    Text(appVersion)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Divider()
                    
                    Text("Welcome to Medication Sidekick")
                        .padding(.horizontal)
                    
                    featureRow("Monitor your blood sugar levels")
                    featureRow("Interactive chart: Glucose and Insulin Entries.")
                    featureRow("Dexcom integration: Live glucose & trends.")
                    featureRow("Insulin on-board safety calculations")
                    featureRow("Manage and select meals")
                    featureRow("User settings management")
                    
                    
                    Spacer(minLength: 30)
                    
                    Text("© 2024 Ashton IT Consulting")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    
                }
                .padding(.horizontal)
                
                .navigationTitle("About")
                .navigationBarTitleDisplayMode(.inline)
                
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .toolbarBackground(Color(themeManager.selectedTheme.toolbarBackgroundColor), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .background(themeManager.selectedTheme.toolbarBackgroundColor)
        }
    }

    private func featureRow(_ text: String, isHelp: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.red)
                .padding(.top, 6)

                Text("**\(text)**")
            
        }
    }
}

#Preview {
    
    let theme = ThemeManager()
    return NavPreview {
        AboutView()
    }
    .environment(theme)
}
