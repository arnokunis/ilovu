// MemoryStore.swift
// The shared "list of memories" — same pattern as MissionStore.
// @Observable + JSON-into-UserDefaults persistence. Injected at the
// app root so UsView, HomeView, and the completion flow all see the
// same one instance.

import Foundation
import Observation

@Observable
final class MemoryStore {

    var memories: [Memory] = []

    // Versioned key — a future schema change can bump to v2 and ignore
    // any old data instead of corrupting it via a half-broken decode. Kept at
    // v1 across the Storage-sync change: Memory's new fields are additive/
    // optional, so old entries (which still carry photoData) decode cleanly and
    // get migrated up to Storage by resyncUnsynced().
    private let storageKey = "memories.v1"

    // Sink for syncing a new local memory to Storage + Firestore. Injected once
    // at the app root (iLovuApp) so MemoryStore stays Firebase-free/previewable;
    // nil in previews / when unpaired, in which case memories stay local. Set to
    // call MemoryService.saveMemory then markSynced. Remote-origin merges
    // (mergeFromRemote) deliberately DON'T fire this — no echo back out.
    var remoteUpsert: ((Memory) -> Void)?

    init() {
        load()
    }

    // MARK: - Mutations

    func add(_ memory: Memory) {
        memories.append(memory)
        save()
        remoteUpsert?(memory)
    }

    /// Marks a memory as uploaded: records its Storage path and drops the inline
    /// photoData so the bytes live in Storage (served via the download-once
    /// ImageCache), not duplicated in UserDefaults. Called after a successful
    /// saveMemory.
    func markSynced(id: UUID, storagePath: String) {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { return }
        let m = memories[index]
        memories[index] = Memory(
            id: m.id, dateCompleted: m.dateCompleted,
            cardTitle: m.cardTitle, cardEmoji: m.cardEmoji,
            photoData: nil, rating: m.rating, note: m.note,
            storagePath: storagePath, createdBy: m.createdBy
        )
        save()
    }

    // MARK: - Remote sync
    // Keyed on the memory's UUID, which IS the Firestore doc id — so the
    // creator's local entry and the doc the partner receives are one identity.

    /// Applies a memory that arrived from Firestore. Updates the existing local
    /// entry for the same id (preserving any local photoData we already have, so
    /// the creator's instant display isn't lost), or appends it for the partner
    /// who's seeing it for the first time. Does NOT push back out.
    func mergeFromRemote(_ memory: Memory) {
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            let existing = memories[index]
            memories[index] = Memory(
                id: memory.id, dateCompleted: memory.dateCompleted,
                cardTitle: memory.cardTitle, cardEmoji: memory.cardEmoji,
                photoData: existing.photoData,                       // keep instant bytes if present
                rating: memory.rating, note: memory.note,
                storagePath: memory.storagePath ?? existing.storagePath,
                createdBy: memory.createdBy ?? existing.createdBy
            )
        } else {
            memories.append(memory)
        }
        save()
    }

    /// Drops the local memory for `memoryId` (UUID string) after a remote
    /// deletion. We don't delete from the client today, but this keeps the
    /// listener honest.
    func removeFromRemote(id memoryId: String) {
        let before = memories.count
        memories.removeAll { $0.id.uuidString == memoryId }
        if memories.count != before { save() }
    }

    /// Re-runs the sync sink for every memory that has local bytes but no
    /// Storage path yet — the migration of pre-Storage local memories, plus a
    /// retry for any earlier upload that failed. Safe to call repeatedly
    /// (idempotent: deterministic ids/paths; synced entries are skipped).
    func resyncUnsynced() {
        for memory in memories where memory.storagePath == nil && memory.photoData != nil {
            remoteUpsert?(memory)
        }
    }

    // MARK: - Queries

    // Newest first — the way humans naturally read a journal.
    var sortedByDate: [Memory] {
        memories.sorted { $0.dateCompleted > $1.dateCompleted }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(memories) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Memory].self, from: data)
        else { return }
        memories = decoded
    }
}
