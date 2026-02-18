//
//  HelpListView.swift
//  Diabetic Sidekick
//
//  Created by Alan Ashton on 2026-01-03.
//

import SwiftUI

struct HelpListView: View {
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) var dismiss
    
    var onSelect: (HelpDocumentation.HelpPage) -> Void
    
    var body: some View {
        
        List(HelpDocumentation.helpPages) { page in
            Button {
                onSelect(page)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.selectedTheme.bodyTextColorPrimary)

                    Text(page.title)
                        .font(.headline)
                        .foregroundColor(themeManager.selectedTheme.bodyTextColorPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(themeManager.selectedTheme.toolbarBackgroundColor, for: .navigationBar)
    
        .task {
            print("HelpListView appeared: Loaded \(HelpDocumentation.helpPages[0].markdownURL) help pages.")
        }
        
        // Header Toolbar
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Help Topics")
                    .font(.headline)
                    .foregroundColor(themeManager.selectedTheme.toolbarForegroundColor)
            }
        }
        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
       
    }
}

#if DEBUG
#Preview {
    let themeManager = ThemeManager()
    
    return NavPreview {
        HelpListView { (_: HelpDocumentation.HelpPage) in }
    }
    .environment(themeManager)
}
#endif
