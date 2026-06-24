// BundledRemoteImage.swift
// Loads a remote image URL via URLSession into a UIImage, sending the app's
// bundle id in the X-Ios-Bundle-Identifier header — which AsyncImage can't do
// (it attaches no custom headers).
//
// Why it exists: Google Places venue photos are served from media URLs that
// carry the API key as a query param. When that key is restricted to "iOS apps
// + our bundle id" (the correct, locked-down setting), Google enforces the
// restriction by reading the X-Ios-Bundle-Identifier request header. The Places
// SDK sends it automatically; a raw AsyncImage GET does not, so an
// iOS-bundle-restricted key blocks the photo with a 403 — exactly the symptom we
// hit. Sending the header here makes photos load WITHOUT loosening the key.
//
// The header is harmless to non-Google hosts (e.g. Ticketmaster's CDN ignore it),
// so this is safe for any image URL. Mirrors CachedStorageImage's shape: a
// @State UIImage, a caller-supplied placeholder, and three render states
// (loading / loaded / failed) matching AsyncImage's semantics.

import SwiftUI

struct BundledRemoteImage<Placeholder: View>: View {

    let urlString: String?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var didFail = false
    @State private var loadedKey = ""

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if didFail {
                // Failed (or non-http) — just the caller's placeholder, no spinner.
                placeholder()
            } else {
                // Loading — placeholder with a spinner, same as AsyncImage's .empty.
                placeholder()
                    .overlay(ProgressView().tint(.white))
            }
        }
        // Keyed on the URL so a reused tile reloads when its URL changes.
        .task(id: urlString ?? "") { await load() }
    }

    private func load() async {
        guard let urlString else { return }
        // New URL on a reused view — clear stale state before reloading.
        if loadedKey != urlString {
            image = nil
            didFail = false
        }
        guard urlString.hasPrefix("http"), let url = URL(string: urlString) else {
            didFail = true
            return
        }

        let fetched = await Self.fetch(url)

        // The view may have been reused for a different URL mid-flight; only
        // commit if we're still meant to show this one.
        guard urlString == self.urlString else { return }
        loadedKey = urlString
        if let fetched {
            image = fetched
            didFail = false
        } else {
            didFail = true
        }
    }

    /// GET the image with the bundle-id header so an iOS-restricted Google key
    /// passes. nil on any non-2xx / network / decode failure (caller shows the
    /// placeholder). Relies on URLSession's shared URLCache for HTTP-level reuse.
    private static func fetch(_ url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            let image = UIImage(data: data)
        else { return nil }
        return image
    }
}
