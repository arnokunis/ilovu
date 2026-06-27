// MemoryImage.swift
// Renders a Memory's proof photo, wherever the bytes happen to live:
//   • just-captured / not-yet-synced  -> inline memory.photoData (instant)
//   • synced from the partner / migrated -> downloaded from storagePath via the
//     download-once ImageCache
//
// AsyncImage-style: the caller supplies how to style the resolved Image (the
// vault card crops to a 4:3 fill; the detail view fits the whole photo), plus a
// placeholder shown while a remote photo loads or if there's nothing to show.

import SwiftUI

struct MemoryImage<Content: View, Placeholder: View>: View {

    let memory: Memory
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var downloaded: UIImage?

    var body: some View {
        Group {
            if let image = resolvedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        // Re-resolve if the row is reused for a different memory OR the photo was
        // replaced (photoVersion bump) — the latter re-downloads the new bytes.
        .task(id: "\(memory.id)#\(memory.photoVersion)") { await loadRemoteIfNeeded() }
    }

    // Local bytes win (instant, no flicker); otherwise the downloaded copy.
    private var resolvedImage: UIImage? {
        if let data = memory.photoData, let image = UIImage(data: data) { return image }
        return downloaded
    }

    private func loadRemoteIfNeeded() async {
        // Only fetch when there are no local bytes but we do have a Storage path.
        guard memory.photoData == nil, let path = memory.storagePath else { return }
        // photoVersion busts the cache when the photo is replaced (the path is
        // overwritten in place, so the path alone wouldn't change).
        downloaded = await ImageCache.shared.image(forPath: path, version: String(memory.photoVersion))
    }
}
