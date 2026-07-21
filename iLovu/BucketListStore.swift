// BucketListStore.swift
// The shared "date wishlist" — @Observable + JSON-into-UserDefaults, injected at
// the app root so the Us tab + the wishlist screen see one instance. Mirrors
// MissionStore/MemoryStore: local mutations fire a remote sink (wired once at the
// app root) that syncs to Firestore; mergeFromRemote applies the partner's edits
// without echoing back out.

import Foundation
import Observation

@Observable
final class BucketListStore {

    var items: [BucketListItem] = []

    private let storageKey = "bucketList.v1"

    // Sinks set once at the app root (iLovuApp). nil in previews / when unpaired,
    // in which case items stay local. Remote-origin merges never fire these.
    var remoteUpsert: ((BucketListItem) -> Void)?
    var remoteDelete: ((UUID) -> Void)?

    init() { load() }

    /// Active (not-done) items first, newest within each group.
    var sorted: [BucketListItem] {
        items.sorted { lhs, rhs in
            if lhs.done != rhs.done { return !lhs.done }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var activeCount: Int { items.filter { !$0.done }.count }

    // MARK: - Mutations

    func add(title: String, emoji: String, addedBy: String?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = BucketListItem(title: trimmed, emoji: emoji, addedBy: addedBy)
        items.append(item)
        save()
        remoteUpsert?(item)
    }

    func toggle(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].done.toggle()
        save()
        remoteUpsert?(items[index])
    }

    func remove(id: UUID) {
        guard items.contains(where: { $0.id == id }) else { return }
        items.removeAll { $0.id == id }
        save()
        remoteDelete?(id)
    }

    // MARK: - Remote sync (never pushes back out)

    func mergeFromRemote(_ item: BucketListItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        save()
    }

    func removeFromRemote(id itemId: String) {
        let before = items.count
        items.removeAll { $0.id.uuidString == itemId }
        if items.count != before { save() }
    }

    /// Re-push every local item after pairing so items added while unpaired reach
    /// Firestore (mirrors MemoryStore.resyncUnsynced). Idempotent — setData merges.
    func resyncAll() {
        for item in items { remoteUpsert?(item) }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BucketListItem].self, from: data) else { return }
        items = decoded
    }
}
