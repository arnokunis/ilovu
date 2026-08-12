// NextMissionWidget.swift  (iLovuWidget target)
// The couple's next planned date at a glance — a warm nudge toward the plan
// they already made, not a to-do guilt trip.

import WidgetKit
import SwiftUI

struct NextMissionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextMissionWidget", provider: LovuProvider()) { entry in
            NextMissionView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Date")
        .description("Your next planned mission, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextMissionView: View {
    let entry: LovuEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text("🎯").font(.system(size: 15))
                Text("Next date")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Spacer(minLength: 2)

            if let title = entry.snapshot.nextMissionTitle {
                Text(entry.snapshot.nextMissionEmoji ?? "💘")
                    .font(.system(size: 30))
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let date = entry.snapshot.nextMissionDate {
                    Text(date, format: .dateTime.weekday(.wide).month().day())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LovuWidgetStyle.coralDeep)
                    // The multi-day gap between planning a date and going on it was
                    // completely unexploited — no countdown anywhere in the app.
                    // This is anticipation, not pressure: it only ever counts DOWN
                    // to something good, and disappears once the day passes.
                    if let countdown = Self.countdownText(to: date, from: entry.date) {
                        Text(countdown)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Pick a day together")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("💘").font(.system(size: 30))
                Text("No date planned yet")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                // Was "Swipe together to match one" — but since 1.0.8 a solo
                // right-swipe saves a plan on its own, so the old copy told most
                // users to do something they cannot do yet.
                Text("Swipe in Near You to plan one")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Warm, day-granular countdown. Compares START OF DAY on both sides so
    /// "Tomorrow" means the next calendar day rather than 24 hours away. Returns
    /// nil once the day has arrived-and-gone, so a stale mission never nags.
    static func countdownText(to date: Date, from now: Date) -> String? {
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: now),
                                      to: cal.startOfDay(for: date)).day
        guard let days else { return nil }
        switch days {
        case ..<0:  return nil
        case 0:     return "Today 💛"
        case 1:     return "Tomorrow"
        default:    return "in \(days) days"
        }
    }
}
