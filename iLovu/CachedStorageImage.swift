// CachedStorageImage.swift
// SwiftUI view that renders a Storage-backed photo from its PATH, going through
// ImageCache so the bytes are fetched at most once. While loading (or when
// there's no photo yet, or a download fails) it shows the caller's placeholder.
//
// Pass `version` so a changed photo re-downloads: for the couple photo that's
// couplePhotoUpdatedAt. The .task is keyed on (path, version), so SwiftUI
// re-runs the load whenever either changes.

import SwiftUI

struct CachedStorageImage<Placeholder: View>: View {

    let path: String?
    let version: String
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadedKey: String = ""

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: "\(path ?? "")#\(version)") {
            await load()
        }
    }

    private func load() async {
        let key = "\(path ?? "")#\(version)"
        // Avoid clobbering a good image with a flash of placeholder when the
        // task re-fires for an unchanged key.
        guard key != loadedKey else { return }
        let fetched = await ImageCache.shared.image(forPath: path, version: version)
        // Only commit if this is still the key we're meant to show (the view
        // may have been reused for a different path mid-flight).
        if "\(path ?? "")#\(version)" == key {
            image = fetched
            loadedKey = key
        }
    }
}
