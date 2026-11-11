//
//  MoreView.swift
//  Medication Sidekick
//
//  Replaces the old sliding sidebar: times of day, settings, help, about.
//

import SwiftUI

struct MoreView: View {

    @Environment(ThemeManager.self) var themeManager
    @Environment(NavigationRouter.self) var router
    @State private var showAbout = false

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    var body: some View {
        List {
            Section {
                row(title: "Help", systemImage: "questionmark.circle.fill") {
                    router.navigate(.help)
                }
                row(title: "Schedule Times", systemImage: "sun.max") {
                    router.navigate(.mealTimeSettings)
                }
                row(title: "Settings", systemImage: "gearshape.fill") {
                    router.navigate(.settings)
                }
                row(title: "About", systemImage: "info.circle") {
                    showAbout = true
                }
            }
        }
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .background(theme.bgBase)
        .navigationTitle("More")
        .sheet(isPresented: $showAbout) {
            AboutView()
                .environment(themeManager)
        }
    }

    /// One tappable card row: icon tile, title, and our own trailing chevron —
    /// a plain `Button`, not a `NavigationLink`, so there's no system disclosure arrow.
    private func row(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.textSecondary.opacity(0.12))
                    )

                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.surfaceBase)
                .premiumCardShadow(theme: theme)
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MoreView()
    }
    .environment(NavigationRouter())
    .environment(ThemeManager())
}
#endif
