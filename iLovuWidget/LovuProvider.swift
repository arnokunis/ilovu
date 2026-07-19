// LovuProvider.swift  (iLovuWidget extension target)
// The timeline provider shared by all three iLovu widgets. It reads the snapshot
// the app wrote into the App Group container (WidgetSnapshot.load()) and the
// optional latest-memory JPEG — no Firebase, no network. The app pushes
// WidgetCenter reloads on every data change; this provider ALSO re-renders at the
// next local midnight so the Days Together count rolls over on its own.
//
// TARGET MEMBERSHIP: this file + all the *Widget.swift files + iLovuWidgetBundle
// belong to the iLovuWidget target ONLY. WidgetShared.swift is the one file
// shared with BOTH the app and this extension.

import WidgetKit
import SwiftUI

struct LovuEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let memoryImage: Image?
}

struct LovuProvider: TimelineProvider {

    func placeholder(in context: Context) -> LovuEntry {
        LovuEntry(date: Date(), snapshot: .preview, memoryImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LovuEntry) -> Void) {
        // The gallery preview uses friendly sample content; a real install shows
        // its own data.
        let entry = context.isPreview ? LovuEntry(date: Date(), snapshot: .preview, memoryImage: nil)
                                      : currentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LovuEntry>) -> Void) {
        let entry = currentEntry()
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> LovuEntry {
        let snapshot = WidgetSnapshot.load()
        var image: Image?
        if snapshot.hasMemoryImage,
           let url = WidgetShared.memoryImageURL,
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) {
            image = Image(uiImage: ui)
        }
        return LovuEntry(date: Date(), snapshot: snapshot, memoryImage: image)
    }
}

// MARK: - Brand style (local so the widget target needs no DesignSystem import)

enum LovuWidgetStyle {
    static let coral     = Color(red: 1.00, green: 0.42, blue: 0.42)
    static let coralDeep = Color(red: 0.96, green: 0.28, blue: 0.45)
    static var coralGradient: LinearGradient {
        LinearGradient(colors: [coral, coralDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Snapshot display helpers

extension WidgetSnapshot {

    /// Days together for display: recomputed from `datingDate` when present (stays
    /// correct across a midnight boundary), else the value the app precomputed.
    var displayDaysTogether: Int? {
        if let start = datingDate { return WidgetShared.daysTogether(since: start) }
        return daysTogether
    }

    /// Friendly sample content for the widget gallery + placeholder.
    static let preview: WidgetSnapshot = {
        var s = WidgetSnapshot()
        s.daysTogether      = 428
        s.partnerName       = "Inesa"
        s.nextMissionTitle  = "Sunset picnic"
        s.nextMissionEmoji  = "🧺"
        s.nextMissionDate   = Date().addingTimeInterval(2 * 24 * 60 * 60)
        s.latestMemoryTitle = "Wine bar night"
        s.latestMemoryEmoji = "🍷"
        return s
    }()
}
