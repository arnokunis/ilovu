// Memory.swift
// A snapshot of a completed mission — the photographic proof + a
// little context. Memories are the third beat of iLovu's
// "Match → Mission → Memory" loop, and the reason couples don't
// uninstall: a swipe deck is replaceable; a year of shared memories
// is not.
//
// Why store the title + emoji rather than the whole DateCard?
// A Memory should be frozen in time. If we later edit the underlying
// card's copy or remove a card entirely, the memory should keep
// looking the same. Embedding just the snapshot fields we need
// keeps Memory independent of the live deck.

import Foundation

struct Memory: Identifiable, Codable, Equatable {

    let id: UUID
    let dateCompleted: Date
    let cardTitle: String
    let cardEmoji: String

    // Photo bytes, present when the memory was just captured on THIS device or
    // hasn't synced yet. Once uploaded to Storage we clear it (markSynced) and
    // serve from `storagePath` via the download-once ImageCache — so memories
    // synced from the partner arrive with photoData == nil and storagePath set.
    // Optional (was non-optional) so remote-origin memories decode; old local
    // entries still carry their bytes until migrated.
    let photoData: Data?

    // Optional metadata — neither blocks saving a memory.
    let rating: Int?
    let note: String?

    // Cloud Storage PATH of the proof photo (couples/{id}/memories/{memId}.jpg),
    // NOT a download URL — the bytes are fetched through the SDK + rules. nil
    // until the memory has been uploaded. Set on sync; the keystone of sharing
    // a memory with the partner.
    var storagePath: String? = nil

    // uid that saved the memory. Informational; nil for legacy local entries.
    var createdBy: String? = nil
}
