// WidgetShared.swift
// The tiny data contract shared between the iLovu app (the WRITER) and the
// iLovu widget extension (the READER). It lives in the App Group container so
// the widget renders OFFLINE — no Firebase, no network, instant, and free.
//
// IMPORTANT: once the widget extension target exists, this ONE file must be a
// member of BOTH targets (app + widget extension). It's pure Foundation so it
// compiles cleanly into either. Keep it dependency-free for that reason.
//
// The app writes a WidgetSnapshot (JSON) plus an optional latest-memory JPEG
// whenever the couple / missions / memories change; the widget's timeline
// provider reads them back. If the App Group isn't configured yet (capability
// not added, or running before setup), every accessor no-ops gracefully
// (containerURL == nil) so nothing crashes and the app behaves exactly as
// before.

import Foundation

enum WidgetShared {

    /// App Group identifier. MUST match the capability added to BOTH targets in
    /// Xcode and the group registered in the Apple Developer portal. Change it
    /// here and both sides stay in sync.
    static let appGroupId = "group.com.ilovu.app"

    static let snapshotFilename    = "widget-snapshot.json"
    static let memoryImageFilename = "widget-latest-memory.jpg"

    /// The shared container URL, or nil if the App Group isn't set up yet — the
    /// single graceful-degradation gate both writer and reader check.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }

    static var snapshotURL: URL?    { containerURL?.appendingPathComponent(snapshotFilename) }
    static var memoryImageURL: URL? { containerURL?.appendingPathComponent(memoryImageFilename) }

    /// Days together from the dating date, counting the start day itself as DAY 1
    /// (so it never reads "0 days"); clamps to ≥1. MIRRORS Couple.daysTogether so
    /// the widget can recompute across a midnight boundary — from the stored
    /// datingDate — without waiting for the app to reopen and rewrite the snapshot.
    static func daysTogether(since start: Date, asOf now: Date = Date()) -> Int {
        let cal = Calendar.current
        let elapsed = cal.dateComponents([.day],
                                         from: cal.startOfDay(for: start),
                                         to: cal.startOfDay(for: now)).day ?? 0
        return max(1, elapsed + 1)
    }
}

/// Everything the three widgets need, in one small JSON payload. Every field is
/// optional so a brand-new or unpaired user still produces a VALID snapshot —
/// the widgets show a gentle empty state instead of stale or missing data.
struct WidgetSnapshot: Codable {

    // Days Together widget. `datingDate` lets the widget recompute the count at a
    // day boundary on its own; `daysTogether` is the precomputed value at write
    // time (a stable fallback when the dating date was never set).
    var daysTogether: Int?
    var datingDate: Date?
    var partnerName: String?

    // Next Mission widget.
    var nextMissionTitle: String?
    var nextMissionEmoji: String?
    var nextMissionDate: Date?

    // Latest Memory widget. The image itself rides alongside as a separate JPEG
    // (WidgetShared.memoryImageURL); this flag says whether it was written.
    var latestMemoryTitle: String?
    var latestMemoryEmoji: String?
    var hasMemoryImage: Bool = false

    var updatedAt: Date = Date()

    /// The empty snapshot — an unpaired or brand-new install.
    static let empty = WidgetSnapshot()

    /// Load the current snapshot from the shared container, or `.empty` when it's
    /// missing/unreadable (widget side; also safe from the app).
    static func load() -> WidgetSnapshot {
        guard let url = WidgetShared.snapshotURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.widget.decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return decoded
    }
}

// Shared date strategy so the writer and reader always agree on the wire format.
extension JSONEncoder {
    static var widget: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var widget: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
