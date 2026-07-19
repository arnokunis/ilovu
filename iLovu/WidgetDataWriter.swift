// WidgetDataWriter.swift
// App-side writer for the home-screen widgets. Serializes the current couple
// state into the shared App Group container (see WidgetShared) and asks
// WidgetKit to reload its timelines — so the Days Together / Next Mission /
// Latest Memory widgets stay fresh WITHOUT the extension ever touching Firebase.
//
// Driven from the app root (iLovuApp) by a cheap digest: whenever the couple,
// missions, or memories change, refresh() runs. It no-ops harmlessly until the
// App Group + widget extension are added in Xcode (WidgetShared.containerURL
// is nil until then), so it's safe to ship ahead of the extension.

import UIKit
import WidgetKit

@MainActor
struct WidgetDataWriter {

    /// Rebuild + persist the widget snapshot, then reload timelines. Cheap enough
    /// to call on every relevant change: a small JSON write plus, at most, one
    /// downscaled image encode for the newest memory.
    func refresh(couple: Couple?,
                 partnerName: String?,
                 missions: [Mission],
                 memories: [Memory]) async {

        // No shared container => App Group not set up yet. Do nothing.
        guard WidgetShared.containerURL != nil else { return }

        var snapshot = WidgetSnapshot()
        snapshot.daysTogether = couple?.daysTogether()
        snapshot.datingDate   = couple?.milestoneDate(.dating)
        snapshot.partnerName  = partnerName

        // Next mission = the soonest UPCOMING mission. Dated missions sort by
        // their scheduled date (earliest first); undated upcoming ones fall in
        // after, so the widget still has something to show before a date is set.
        let upcoming = missions.filter { $0.status == .upcoming }
        let next = upcoming.min { lhs, rhs in
            switch (lhs.scheduledDate, rhs.scheduledDate) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true    // a dated mission precedes an undated one
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
        if let next {
            snapshot.nextMissionTitle = next.card.title
            snapshot.nextMissionEmoji = next.card.emoji
            snapshot.nextMissionDate  = next.scheduledDate
        }

        // Latest memory = newest by completion date.
        if let latest = memories.max(by: { $0.dateCompleted < $1.dateCompleted }) {
            snapshot.latestMemoryTitle = latest.cardTitle
            snapshot.latestMemoryEmoji = latest.cardEmoji
            snapshot.hasMemoryImage    = await writeMemoryImage(for: latest)
        } else {
            removeMemoryImage()
        }

        snapshot.updatedAt = Date()
        write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Snapshot JSON

    private func write(_ snapshot: WidgetSnapshot) {
        guard let url = WidgetShared.snapshotURL,
              let data = try? JSONEncoder.widget.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Latest-memory image

    /// Writes a small JPEG of the memory's proof photo into the shared container.
    /// Returns true on success. Uses local bytes when present, otherwise the
    /// download-once ImageCache (so a cache hit costs zero egress). Returns false
    /// silently when the image isn't available locally yet (e.g. a partner-synced
    /// memory not downloaded) — the widget then shows its text-only fallback.
    private func writeMemoryImage(for memory: Memory) async -> Bool {
        guard let url = WidgetShared.memoryImageURL else { return false }

        var image: UIImage?
        if let data = memory.photoData { image = UIImage(data: data) }
        if image == nil {
            image = await ImageCache.shared.image(
                forPath: memory.storagePath,
                version: String(memory.photoVersion)
            )
        }
        guard let image,
              let jpeg = ImageDownscaler.downscaledJPEG(image, maxEdge: 600, quality: 0.7)
        else { return false }

        do {
            try jpeg.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func removeMemoryImage() {
        guard let url = WidgetShared.memoryImageURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
