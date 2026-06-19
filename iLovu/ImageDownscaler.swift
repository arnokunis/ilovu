// ImageDownscaler.swift
// One place to shrink a picked image to an upload-friendly JPEG, so every
// photo we send to Storage (couple photo now, Memory Vault next) uses the same
// budget. Generalizes the inline resize that already lived in EditProfileView
// (avatars, 512px/0.8) and CompleteMissionSheet (proof photos, 1024px/0.6).
//
// Couple + memory photos target 1024px max edge at JPEG 0.7 — decent fidelity
// for a photo shown large, ~150–350 KB on the wire (see the cost plan).

import UIKit

enum ImageDownscaler {

    /// Resizes `image` so its longest edge is at most `maxEdge` (never upscales)
    /// and re-encodes as JPEG at `quality`. Returns nil only if encoding fails.
    static func downscaledJPEG(_ image: UIImage,
                               maxEdge: CGFloat = 1024,
                               quality: CGFloat = 0.7) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: image.size.width * scale,
                            height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1   // target is already in pixels; don't multiply by screen scale
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Convenience for raw picked bytes (e.g. PhotosPickerItem data).
    static func downscaledJPEG(from data: Data,
                               maxEdge: CGFloat = 1024,
                               quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return downscaledJPEG(image, maxEdge: maxEdge, quality: quality)
    }
}
