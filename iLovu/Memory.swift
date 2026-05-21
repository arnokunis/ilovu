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

    // Photo stored inline as JPEG Data. CompleteMissionSheet compresses
    // before saving (max 1024px, quality 0.6), so a typical entry is
    // ~100-300 KB — fine in UserDefaults for the foreseeable future.
    // If we ever ship to thousands of memories per couple, we'd move
    // these out to FileManager and keep only filenames here.
    let photoData: Data

    // Optional metadata — neither blocks saving a memory.
    let rating: Int?
    let note: String?
}
