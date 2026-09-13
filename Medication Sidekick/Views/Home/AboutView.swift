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
                    Text("Medication Sidekick")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top)
                    
                    Text(appVersion)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Divider()
                    
                    Text("Welcome to Medication Sidekick")
                        .padding(.horizontal)
                    
                    featureRow("Track medications and daily doses with ease")
                    featureRow("Smart reminders for morning, evening, and bedtime")
                    featureRow("Flexible schedules: with food, before, or after meals")
                    featureRow("Clear daily timeline of all medications")
                    featureRow("Quick add and manage your medications")
                    featureRow("Stay consistent and never miss a dose")
                    
                    featureRow("Pro subscription: add more than 5 medications")
                    featureRow("Pro subscription: List of medications and dosages")
                    
                    Spacer(minLength: 30)
                    
                    Text("© 2024 Ashton IT Consulting")
                        .font(.footnote)
                        .foregroundStyle(themeManager.selectedTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    
                }
                .padding(.horizontal)
                
                .navigationTitle("About")
                .navigationBarTitleDisplayMode(.inline)
                
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .background(themeManager.selectedTheme.bgBase)
            
        }
    }

    private func featureRow(_ text: String, isHelp: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
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
