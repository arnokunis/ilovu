// MemoryService.swift
// All Firestore + Storage I/O for the shared Memory Vault. MemoryStore stays the
// in-memory source of truth + local cache; this service is the network half,
// mirroring MissionService.
//
//   couples/{coupleId}/memories/{memoryId}        -> metadata (this file, Firestore)
//   couples/{coupleId}/memories/{memoryId}.jpg     -> the proof photo bytes (Storage)
//
// The doc id IS the memory's UUID, so the creator's local memory and the doc the
// partner receives converge on the same identity (idempotent, migration-safe).
// We store the Storage PATH on the doc, never a download URL — the bytes are
// fetched through the SDK + rules, so nothing sensitive is baked into Firestore.
//
// Two halves, like MissionService:
//   saveMemory(...)     -> upload bytes, then write the metadata doc; returns the path.
//   observeMemories(...) -> snapshot listener delivering remote memories + removals.

import Foundation
import FirebaseAuth
import FirebaseFirestore

// The Firestore-side shape of a memory. Pure data; the photo bytes live in
// Storage at `storagePath`, not here.
struct RemoteMemory: Codable, Identifiable {

    /// == the doc id (the memory's UUID string). Populated on read, nil on write.
    @DocumentID var id: String?

    var dateCompleted: Timestamp
    var cardTitle: String
    var cardEmoji: String
    var storagePath: String
    var rating: Int?
    var note: String?
    var createdBy: String?
    var schemaVersion: Int
    @ServerTimestamp var createdAt: Timestamp?

    /// Bumped when the proof photo is replaced; mirrors Memory.photoVersion so the
    /// partner's image cache busts. Optional — docs predating the field decode as
    /// nil and are treated as version 1.
    var photoVersion: Int?
}

@MainActor
@Observable
final class MemoryService {

    static let currentSchemaVersion = 1

    private var db: Firestore { Firestore.firestore() }
    private let storage = StorageService()

    /// Where a memory's photo lives in Storage.
    func storagePath(coupleId: String, memoryId: String) -> String {
        "couples/\(coupleId)/memories/\(memoryId).jpg"
    }

    // MARK: - Write (upload bytes + mirror metadata)

    /// Uploads the memory's photo to Storage, then writes its metadata doc.
    /// Returns the Storage path on success (nil on any failure / nothing to
    /// upload), so the caller can mark the local memory synced.
    @discardableResult
    func saveMemory(coupleId: String, memory: Memory) async -> String? {
        guard let uid = Auth.auth().currentUser?.uid else {
            log("saveMemory skipped — not signed in")
            return nil
        }
        guard let photoData = memory.photoData else {
            log("saveMemory skipped \(memory.id) — no local bytes")
            return nil
        }

        let memoryId = memory.id.uuidString
        let path = storagePath(coupleId: coupleId, memoryId: memoryId)

        do {
            // Bytes first: if this fails we never write a doc pointing at a
            // missing object.
            try await storage.uploadJPEG(photoData, to: path)

            var data: [String: Any] = [
                "dateCompleted": Timestamp(date: memory.dateCompleted),
                "cardTitle":     memory.cardTitle,
                "cardEmoji":     memory.cardEmoji,
                "storagePath":   path,
                "createdBy":     uid,
                "schemaVersion": Self.currentSchemaVersion,
                "photoVersion":  memory.photoVersion,
                "createdAt":     FieldValue.serverTimestamp()
            ]
            data["rating"] = memory.rating ?? NSNull()
            let trimmedNote = memory.note?.trimmingCharacters(in: .whitespacesAndNewlines)
            data["note"] = (trimmedNote?.isEmpty == false) ? trimmedNote! : NSNull()

            try await db.collection("couples").document(coupleId)
                .collection("memories").document(memoryId)
                .setData(data, merge: true)

            log("saved memory \(memoryId)")
            return path
        } catch {
            log("ERROR saveMemory \(memoryId): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Observe (deliver remote memories to the caller)

    /// Snapshot listener on the couple's memories subcollection. Calls `onUpsert`
    /// for each added/modified memory and `onRemove(memoryId)` for a deletion.
    /// Fires for every existing memory on first attach (initial hydration). The
    /// caller owns the returned registration and must `.remove()`.
    func observeMemories(
        coupleId: String,
        onUpsert: @escaping (RemoteMemory) -> Void,
        onRemove: @escaping (String) -> Void
    ) -> ListenerRegistration {
        let ref = db.collection("couples").document(coupleId).collection("memories")

        return ref.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                self?.log("memories listener error: \(error.localizedDescription)")
                return
            }
            guard let snapshot else { return }

            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified:
                    guard let remote = try? change.document.data(as: RemoteMemory.self) else { continue }
                    self?.log("memory delivered \(remote.id ?? "?")")
                    onUpsert(remote)
                case .removed:
                    onRemove(change.document.documentID)
                }
            }
        }
    }

    // MARK: - Debug logging

    private func log(_ message: String) {
        #if DEBUG
        print("📸 MemoryService: \(message)")
        #endif
    }
}
