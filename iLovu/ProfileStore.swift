// ProfileStore.swift
// The local profile photo. Kept tiny and on-device only for now — the partner
// doesn't see it yet (that needs Firebase Storage, deferred). Same lightweight
// @Observable + UserDefaults persistence as MissionStore / MemoryStore, and the
// same posture as Memory.photoData (image bytes in UserDefaults today; a future
// pass moves both to FileManager).
//
// The display NAME, by contrast, lives in @AppStorage("userName") and syncs to
// the partner via the couple doc (CoupleService.setDisplayName) — only the photo
// is local-only, which is why it gets its own little store here.

import Foundation
import Observation

@Observable
final class ProfileStore {

    // JPEG bytes of the user's profile photo, or nil if they haven't set one.
    private(set) var photoData: Data?

    // Versioned key so a future migration (e.g. to FileManager) can move off it
    // cleanly, same convention as missions.v1 / the memory store.
    private let storageKey = "profilePhoto.v1"

    init() {
        photoData = UserDefaults.standard.data(forKey: storageKey)
    }

    /// Replaces (or clears) the profile photo and persists it. Pass already-
    /// downscaled JPEG data — callers shrink before saving so UserDefaults never
    /// holds a multi-MB original.
    func setPhoto(_ data: Data?) {
        photoData = data
        if let data {
            UserDefaults.standard.set(data, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
