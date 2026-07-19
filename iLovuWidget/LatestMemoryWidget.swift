// LatestMemoryWidget.swift  (iLovuWidget target)
// The most recent proof photo on the home screen — the single strongest reason
// couples don't uninstall: a swipe deck is replaceable, a shared memory is not.
// Full-bleed photo with a soft scrim + title; graceful text card before any
// memory exists or while the photo is still downloading.

import WidgetKit
import SwiftUI

struct LatestMemoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LatestMemoryWidget", provider: LovuProvider()) { entry in
            LatestMemoryView(entry: entry)
                .containerBackground(for: .widget) {
                    if let image = entry.memoryImage {
                        image.resizable().scaledToFill()
                    } else {
                        LovuWidgetStyle.coralGradient
                    }
                }
        }
        .configurationDisplayName("Latest Memory")
        .description("Your most recent shared memory.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LatestMemoryView: View {
    let entry: LovuEntry

    var body: some View {
        let hasPhoto = entry.memoryImage != nil
        let title = entry.snapshot.latestMemoryTitle

        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            if let title {
                HStack(spacing: 5) {
                    Text(entry.snapshot.latestMemoryEmoji ?? "📸").font(.system(size: 16))
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text("Your latest memory 💕")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            } else {
                Text("📸").font(.system(size: 30))
                Text("Your memories\nwill appear here")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
        }
        .padding(hasPhoto ? 4 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // A bottom scrim so overlaid text stays legible on any photo.
        .background(alignment: .bottom) {
            if hasPhoto {
                LinearGradient(
                    colors: [.black.opacity(0.55), .clear],
                    startPoint: .bottom, endPoint: .center
                )
            }
        }
    }
}
