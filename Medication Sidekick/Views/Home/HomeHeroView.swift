//
//  HomeHeroView.swift
//  Medication Sidekick
//
//  Top of the Home tab: date, a segmented "dose ring" (one arc per dose today,
//  coloured by status) and a legend of glass chips. Sits on the accent gradient drawn by HomeView.
//

import SwiftUI

struct HomeHeroView: View {

    @Environment(ThemeManager.self) private var themeManager
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 164

    let summary: HomeSummary
    var date: Date = Date()

    private var theme: ThemeProtocol { themeManager.selectedTheme }

    // Segment / chip colours. Missed is derived from the theme's error token, lightened so it
    // reads on the accent gradient; due uses a warm amber, which the theme has no token for.
    private var takenColor: Color { theme.textOnAccent }
    private var skippedColor: Color { theme.textOnAccent.opacity(0.5) }
    private var missedColor: Color { theme.statusError.mix(with: .white, by: 0.45) }
    private var dueColor: Color { .yellow }
    private var laterColor: Color { theme.textOnAccent.opacity(0.28) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(theme.textOnAccent.opacity(0.85))

            HStack(spacing: 20) {
                ring

                GlassEffectContainer(spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        chip(symbol: "clock.fill", color: dueColor, value: summary.dueNow, label: "due now")
                        chip(symbol: "hourglass", color: laterColor.opacity(3), value: summary.laterToday, label: "later")
                        chip(symbol: "exclamationmark.circle.fill", color: missedColor, value: summary.missed, label: "missed")
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(theme.textOnAccent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.taken) of \(summary.total) doses taken. \(summary.dueNow) due now, \(summary.laterToday) later today, \(summary.missed) missed."
        )
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            SegmentedRing(
                segments: summary.segments,
                lineWidth: 14,
                color: color(for:),
                emptyColor: laterColor
            )
            .padding(7) // keep the stroke inside the frame so list rows don't clip it

            VStack(spacing: 2) {
                if summary.total == 0 {
                    Text("No doses")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                } else {
                    Text("\(summary.taken)")
                        .font(.system(size: 58, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("of \(summary.total) taken")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .opacity(0.9)
                }
            }
            .padding(.horizontal, 28)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        }
        .frame(width: ringSize, height: ringSize)
        .animation(.easeOut(duration: 0.4), value: summary.segments)
    }

    private func color(for segment: HomeSummary.Segment) -> Color {
        switch segment {
        case .taken:   takenColor
        case .skipped: skippedColor
        case .missed:  missedColor
        case .due:     dueColor
        case .later:   laterColor
        }
    }

    // MARK: - Chips

    private func chip(symbol: String, color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text("\(value)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .opacity(0.9)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Segmented ring

/// A ring split into one arc per dose, in time order starting at 12 o'clock.
private struct SegmentedRing: View {

    let segments: [HomeSummary.Segment]
    let lineWidth: CGFloat
    let color: (HomeSummary.Segment) -> Color
    let emptyColor: Color

    /// Gap between arcs, as a fraction of the full circle (~4°).
    private let gap = 0.011

    var body: some View {
        ZStack {
            if segments.isEmpty {
                Circle().stroke(emptyColor, lineWidth: lineWidth)
            } else {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    let span = 1.0 / Double(segments.count)
                    let inset = segments.count == 1 ? 0 : gap / 2
                    Circle()
                        .trim(from: Double(index) * span + inset,
                              to: Double(index + 1) * span - inset)
                        .stroke(color(segment), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let theme = ThemeManager()
    HomeHeroView(summary: .preview)
        .padding()
        .background(theme.selectedTheme.accentPrimary)
        .environment(theme)
}
#endif
