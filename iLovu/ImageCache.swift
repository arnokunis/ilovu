// ImageCache.swift
// Download-once image cache for Storage-backed photos, so we never re-fetch the
// same bytes on every scroll/launch. This is the bandwidth cost control for the
// whole photo-sync feature — same philosophy as the venue cache: pay once, then
// serve locally. Without it, egress scales with usage instead of with content.
//
// Two layers: an in-memory NSCache (fast, auto-evicts under pressure) over a
// FileManager directory in Caches/ (survives launches, the OS can reclaim it).
//
// Cache KEY = path + "#" + version. For the couple photo, version is
// couplePhotoUpdatedAt, so a change on one phone busts the other's cached copy.
// (Memory Vault photos in slice 2 are immutable, so they'll pass a fixed version.)

import UIKit

@MainActor
final class ImageCache {

    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let storageService = StorageService()
    private let directory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("iLovuImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Returns the image for a Storage path, fetching+caching on a miss. Returns
    /// nil if the path is nil/empty or the download fails (callers show a
    /// placeholder). `version` busts the cache when the underlying photo changes.
    func image(forPath path: String?, version: String) async -> UIImage? {
        guard let path, !path.isEmpty else { return nil }
        let key = cacheKey(path: path, version: version)

        // 1. In-memory.
        if let hit = memory.object(forKey: key as NSString) { return hit }

        // 2. On-disk.
        let fileURL = directory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }

        // 3. Miss → download via Storage, then populate both layers.
        guard let data = try? await storageService.downloadData(at: path),
              let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        try? data.write(to: fileURL, options: .atomic)
        return image
    }

    // Turn path+version into a DETERMINISTIC filesystem-safe filename. Swift's
    // String.hashValue is seeded per process, so it can't be used here — the
    // disk cache must survive relaunches. Mapping non-alphanumerics to "_" is
    // stable across launches and collision-free for our structured keys.
    private func cacheKey(path: String, version: String) -> String {
        let raw = "\(path)#\(version)"
        return String(raw.map { $0.isLetter || $0.isNumber ? $0 : "_" })
    }
}
