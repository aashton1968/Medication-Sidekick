//
//  HomeTimeZoneSection.swift
//  Medication Sidekick
//
//  Shared "Advanced > Keep home time zone" control for the Add, Edit and Edit Schedule screens.
//
//  This is the same setting as `Medication.followsDeviceTimeZone`, shown the other way round:
//  "Keep home time zone" ON  == followsDeviceTimeZone false
//  "Keep home time zone" OFF == followsDeviceTimeZone true (the default)
//

import SwiftUI

struct HomeTimeZoneSection: View {

    @Environment(ThemeManager.self) private var themeManager

    /// The medication's `followsDeviceTimeZone` value (true = dose times move with the phone's time zone).
    @Binding var followsDeviceTimeZone: Bool
    /// The time zone the schedule is pinned to when "keep home time zone" is on.
    let homeTimeZoneIdentifier: String

    @State private var isExpanded = false

    private var keepsHomeTimeZone: Binding<Bool> {
        Binding(
            get: { !followsDeviceTimeZone },
            set: { followsDeviceTimeZone = !$0 }
        )
    }

    private var homeZoneName: String {
        TimeZone(identifier: homeTimeZoneIdentifier)?
            .localizedName(for: .generic, locale: .current) ?? homeTimeZoneIdentifier
    }

    var body: some View {
        Section {
            DisclosureGroup("Advanced", isExpanded: $isExpanded) {
                Toggle("Keep home time zone", isOn: keepsHomeTimeZone)

                Text(followsDeviceTimeZone
                    ? "Dose times follow your phone's time zone, so a dose at 8:00 AM stays at 8:00 AM wherever you travel."
                    : "Dose times stay on \(homeZoneName) time and won't shift when you travel. Use this when the gap between doses matters more than the time on the clock, such as an antibiotic every 8 hours.")
                    .font(.footnote)
                    .foregroundStyle(themeManager.selectedTheme.textSecondary)
            }
        }
        // Open by itself when the setting is already on, including when the Edit screens load it a moment late.
        .onChange(of: followsDeviceTimeZone, initial: true) { _, follows in
            if !follows { isExpanded = true }
        }
    }
}

#if DEBUG
private struct HomeTimeZoneSectionPreview: View {
    @State private var follows = true
    var body: some View {
        Form {
            HomeTimeZoneSection(followsDeviceTimeZone: $follows, homeTimeZoneIdentifier: "America/Toronto")
        }
    }
}

#Preview {
    HomeTimeZoneSectionPreview()
        .environment(ThemeManager())
}
#endif
