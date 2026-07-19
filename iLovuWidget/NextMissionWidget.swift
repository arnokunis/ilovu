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
                Text("Swipe together to match one")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
