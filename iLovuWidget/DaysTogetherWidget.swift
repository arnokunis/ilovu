// DaysTogetherWidget.swift  (iLovuWidget target)
// The warm, ambient "days together" counter — the retention heart of the widget
// set. Anti-pressure by design: it celebrates time shared, never nags.

import WidgetKit
import SwiftUI

struct DaysTogetherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DaysTogetherWidget", provider: LovuProvider()) { entry in
            DaysTogetherView(entry: entry)
                .containerBackground(LovuWidgetStyle.coralGradient, for: .widget)
        }
        .configurationDisplayName("Days Together")
        .description("A gentle count of your time together.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DaysTogetherView: View {
    let entry: LovuEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("💞").font(.system(size: 26))
            Spacer(minLength: 4)

            if let days = entry.snapshot.displayDaysTogether {
                Text("\(days)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(caption(days: days, partner: entry.snapshot.partnerName))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            } else {
                Text("Set your start date")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("in the Us tab to start counting 💕")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func caption(days: Int, partner: String?) -> String {
        let unit = days == 1 ? "day" : "days"
        if let partner, !partner.isEmpty { return "\(unit) with \(partner)" }
        return "\(unit) together"
    }
}
