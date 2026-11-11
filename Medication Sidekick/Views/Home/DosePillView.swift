//
//  DosePillView.swift
//  Medication Sidekick
//
//  Floating "next dose" pill shown as the tab bar's bottom accessory.
//

import SwiftUI
import SwiftData

struct DosePillView: View {

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(ThemeManager.self) private var themeManager

    let state: DosePillState

    private var theme: ThemeProtocol { themeManager.selectedTheme }
    private var isInline: Bool { placement == .inline }

    private var accent: Color {
        switch state.kind {
        case .overdue:  theme.statusError
        case .due:      theme.accentTint
        case .upcoming: theme.textMuted
        case .allDone:  theme.statusSuccess
        }
    }

    private var primaryText: String {
        state.kind == .allDone ? "All doses taken today" : (state.dose?.medication?.name ?? "Medication")
    }

    /// `.inline` is the system's own collapsed form — shown automatically while the tab's
    /// content is scrolling, in place beside the tab bar items — so the content here just
    /// needs to shrink to fit that narrower space rather than drive the collapse itself.
    var body: some View {
        HStack(spacing: isInline ? 8 : 12) {
            leadingIndicator

            if isInline {
                Text(primaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(primaryText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    if state.kind != .allDone {
                        Text(state.statusText)
                            .font(.caption.weight(state.kind == .overdue ? .heavy : .medium))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
            }
        }
        .padding(.horizontal, isInline ? 10 : 16)
        .accessibilityElement(children: .combine)
    }

    private var leadingIndicator: some View {
        Group {
            if state.kind == .allDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: isInline ? 14 : 16, weight: .semibold))
                    .foregroundStyle(theme.statusSuccess)
            } else {
                Circle()
                    .fill(accent)
                    .frame(width: isInline ? 8 : 10, height: isInline ? 8 : 10)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    let container = PreviewData.container
    PreviewData.seed(into: container.mainContext)
    let doses = (try? container.mainContext.fetch(FetchDescriptor<MedicationDose>())) ?? []
    let state = DosePillState(doses: doses, now: .distantFuture)
        ?? doses.first.map { DosePillState(doses: [$0], now: $0.scheduledDate.addingTimeInterval(60)) } ?? nil

    return Group {
        if let state {
            DosePillView(state: state)
                .frame(height: 56)
                .glassEffect(.regular, in: .capsule)
                .padding()
        } else {
            Text("No preview doses")
        }
    }
    .modelContainer(container)
    .environment(ThemeManager())
}
#endif
