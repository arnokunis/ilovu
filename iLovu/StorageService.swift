// StorageService.swift
// A thin wrapper over Firebase Cloud Storage that the rest of the app uses to
// move photo BYTES by path. Two operations, both authenticated by the signed-in
// user's token and gated by storage.rules — see the PRE-LAUNCH HARDENING note
// there about the interim client-authed model.
//
// We deliberately deal in Storage PATHS (e.g. "couples/{id}/profile.jpg"), never
// getDownloadURL() tokens. The path lives in Firestore; the SDK fetches the
// bytes with the user's auth. Nothing sensitive (no token, no API key) is ever
// persisted — the lesson from the Places key that got baked into cached venue
// photo URLs.

import Foundation
import FirebaseStorage

final class StorageService {

    // Storage.storage() returns the cached default instance, so constructing
    // this is cheap and touches no network until a call is made.
    private var storage: Storage { Storage.storage() }

    enum StorageServiceError: Error { case emptyPath }

    /// Uploads JPEG bytes to `path`, overwriting any existing object there.
    /// contentType is tagged image/jpeg so storage.rules' image check passes and
    /// downloads serve with the right type.
    func uploadJPEG(_ data: Data, to path: String) async throws {
        guard !path.isEmpty else { throw StorageServiceError.emptyPath }
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await storage.reference(withPath: path).putDataAsync(data, metadata: metadata)
    }

    /// Downloads the bytes at `path`. `maxSize` caps the in-memory download as a
    /// safety valve (our uploads are < 5 MB; 8 MB leaves headroom).
    func downloadData(at path: String, maxSize: Int64 = 8 * 1024 * 1024) async throws -> Data {
        guard !path.isEmpty else { throw StorageServiceError.emptyPath }
        return try await storage.reference(withPath: path).data(maxSize: maxSize)
    }
}
