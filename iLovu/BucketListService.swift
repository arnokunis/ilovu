// BucketListService.swift
// All Firestore reads/writes for the shared date wishlist live here:
//   couples/{coupleId}/bucketList/{itemId}   (doc id == item UUID)
// The app mutates through BucketListStore; this service quietly mirrors changes
// to Firestore, and a snapshot listener delivers the partner's edits back. Mirrors
// MissionService. Failures are SILENT to callers (printed under #if DEBUG).

import Foundation
import FirebaseAuth
import FirebaseFirestore

// The Firestore-side shape of a wishlist item. Pure data so the listener closure
// stays simple; MainTabView converts it back to a BucketListItem via asItem().
struct RemoteBucketItem: Codable, Identifiable {

    @DocumentID var id: String?     // == item.id.uuidString
    var title: String
    var emoji: String
    var done: Bool
    var addedBy: String?
    var createdAt: Timestamp?       // client stamp (stable across done-toggles)

    /// Rebuild the local model, or nil if the doc id isn't a valid UUID.
    func asItem() -> BucketListItem? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        return BucketListItem(
            id: uuid, title: title, emoji: emoji, done: done,
            addedBy: addedBy, createdAt: createdAt?.dateValue() ?? Date()
        )
    }
}

@MainActor
@Observable
final class BucketListService {

    private var db: Firestore { Firestore.firestore() }

    // MARK: - Write

    /// Pushes `item` to couples/{coupleId}/bucketList/{itemId}. Create and update
    /// are the same call (merge:true keyed on the item UUID). createdAt is written
    /// as the item's own stamp so it stays stable when `done` is toggled.
    func saveItem(coupleId: String, item: BucketListItem) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            log("saveItem skipped — not signed in")
            return
        }
        let ref = db.collection("couples").document(coupleId)
            .collection("bucketList").document(item.id.uuidString)

        let data: [String: Any] = [
            "title":     item.title,
            "emoji":     item.emoji,
            "done":      item.done,
            "addedBy":   item.addedBy ?? uid,
            "createdAt": Timestamp(date: item.createdAt)
        ]
        do {
            try await ref.setData(data, merge: true)
            log("saved \(item.id.uuidString) [done=\(item.done)]")
        } catch {
            log("ERROR saveItem \(item.id.uuidString): \(error.localizedDescription)")
        }
    }

    /// Deletes the item doc — wishlist items are meant to be removed (unlike
    /// missions/memories), which the couple-scoped rule allows.
    func deleteItem(coupleId: String, itemId: String) async {
        do {
            try await db.collection("couples").document(coupleId)
                .collection("bucketList").document(itemId).delete()
            log("deleted \(itemId)")
        } catch {
            log("ERROR deleteItem \(itemId): \(error.localizedDescription)")
        }
    }

    // MARK: - Observe

    /// Snapshot listener on the couple's wishlist. Fires `onUpsert` for each
    /// added/modified item and `onRemove(itemId)` for a deletion. On first attach
    /// this hydrates every existing item. The caller owns the returned registration.
    func observeItems(
        coupleId: String,
        onUpsert: @escaping (RemoteBucketItem) -> Void,
        onRemove: @escaping (String) -> Void
    ) -> ListenerRegistration {
        let ref = db.collection("couples").document(coupleId).collection("bucketList")
        return ref.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                self?.log("listener error: \(error.localizedDescription)")
                return
            }
            guard let snapshot else { return }
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified:
                    guard let remote = try? change.document.data(as: RemoteBucketItem.self) else { continue }
                    onUpsert(remote)
                case .removed:
                    onRemove(change.document.documentID)
                }
            }
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("🪣 BucketListService: \(message)")
        #endif
    }
}
