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
        // North-star event: a real date happened. Local completions only —
        // the partner's synced copy lands via mergeFromRemote (not counted).
        AppAnalytics.log("memory_completed")
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
            storagePath: storagePath, createdBy: m.createdBy,
            photoVersion: m.photoVersion
        )
        save()
    }

    /// Replaces a memory's proof photo. Bumps photoVersion (busts the image
    /// cache on both devices), stashes the new bytes locally so they show
    /// instantly, then re-runs the sync sink to overwrite the Storage object +
    /// mirror the new version to the partner. No-op if the id is unknown.
    func replacePhoto(id: UUID, data: Data) {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { return }
        let m = memories[index]
        let updated = Memory(
            id: m.id, dateCompleted: m.dateCompleted,
            cardTitle: m.cardTitle, cardEmoji: m.cardEmoji,
            photoData: data, rating: m.rating, note: m.note,
            storagePath: m.storagePath, createdBy: m.createdBy,
            photoVersion: m.photoVersion + 1
        )
        memories[index] = updated
        save()
        remoteUpsert?(updated)   // upload bytes → markSynced clears photoData, keeps version
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
            // A newer remote photoVersion means the partner replaced the photo —
            // take it AND drop our now-stale local bytes so the fresh Storage copy
            // is fetched. Otherwise keep our instant bytes (unchanged photo).
            let remoteIsNewer = memory.photoVersion > existing.photoVersion
            memories[index] = Memory(
                id: memory.id, dateCompleted: memory.dateCompleted,
                cardTitle: memory.cardTitle, cardEmoji: memory.cardEmoji,
                photoData: remoteIsNewer ? nil : existing.photoData,  // keep instant bytes unless superseded
                rating: memory.rating, note: memory.note,
                storagePath: memory.storagePath ?? existing.storagePath,
                createdBy: memory.createdBy ?? existing.createdBy,
                photoVersion: max(memory.photoVersion, existing.photoVersion)
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
