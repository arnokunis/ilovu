// MissionService.swift
// All Firestore reads/writes for shared missions live here, so the rest of the
// app mutates missions through MissionStore and this service quietly mirrors them
// to Firestore. Owned at the app root (iLovuApp) and injected via the environment,
// same as MatchService / CoupleService.
//
//   couples/{coupleId}/missions/{cardId}  -> the shared, syncable mission state
//
// The doc id IS the cardId (one mission per matched card), so both partners' apps
// converge on the same document — that's what makes a date/time edit on one phone
// reach the other. Missions were UserDefaults-only before this; MissionStore stays
// the in-memory source of truth and local cache, while this service is the network.
//
// Two halves, mirroring MatchService:
//   saveMission(...)     -> push the local mission to Firestore (create or update).
//   observeMissions(...) -> a snapshot listener that delivers remote missions
//                           (added + modified) and removals back to the caller,
//                           which merges them into MissionStore.
//
// Writes go out as explicit dictionaries (not a Codable encode) so we control
// nulls precisely — clearing scheduledDate/budget must write an explicit null so
// the partner sees the field cleared, not a stale value. Reads decode through the
// Firestore Codable RemoteMission below (so @DocumentID / @ServerTimestamp work).
//
// Failures are SILENT to callers (same fallback spirit as MatchService) but
// printed under #if DEBUG while build-testing.

import Foundation
import FirebaseAuth
import FirebaseFirestore

// The Firestore-side shape of a mission. Pure data (no DateCard) so the listener
// closure stays off the main actor; MainTabView rebuilds the full Mission from
// the local SampleCards array via cardId, exactly like CardMatch -> DateCard.
struct RemoteMission: Codable, Identifiable {

    /// == the doc id (the stable cardId). Populated on read, nil on write.
    @DocumentID var id: String?

    var cardId: String
    var deck: String
    var status: String
    var scheduledDate: Timestamp?
    var budget: String?
    var checklist: [RemoteChecklistItem]
    @ServerTimestamp var updatedAt: Timestamp?

    struct RemoteChecklistItem: Codable {
        var id: String
        var title: String
        var done: Bool
    }
}

@MainActor
@Observable
final class MissionService {

    // Computed so constructing MissionService touches no Firebase — it can be
    // default-initialized at the app root and in previews. firestore() returns the
    // cached default instance, so this is cheap per request.
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Write (mirror a local mission to Firestore)

    /// Pushes `mission` to couples/{coupleId}/missions/{cardId}. Create and update
    /// are the same call (merge:true keyed on cardId). Optional fields that are
    /// unset are written as explicit nulls so clearing a date/budget propagates.
    func saveMission(coupleId: String, mission: Mission) async {
        guard Auth.auth().currentUser != nil else {
            log("saveMission skipped — not signed in")
            return
        }

        let ref = db.collection("couples").document(coupleId)
            .collection("missions").document(mission.cardId)

        // Deck-aware so the partner rebuilds the right card: a date-card mission
        // resolves in the static SampleCards deck (.dates); a Near You venue
        // mission does not (.places -> the partner rebuilds from VenueCache by
        // placeId, mirroring the .places MATCH rebuild). cardId == placeId for venues.
        let deck: Deck = SampleCards.byId(mission.cardId) != nil ? .dates : .places

        var data: [String: Any] = [
            "cardId":    mission.cardId,
            "deck":      deck.rawValue,
            "status":    mission.status.rawValue,
            "checklist": mission.checklist.map { [
                "id":    $0.id.uuidString,
                "title": $0.title,
                "done":  $0.done
            ] },
            "updatedAt": FieldValue.serverTimestamp()
        ]
        // Explicit null when unset, so a cleared field reaches the partner.
        data["scheduledDate"] = mission.scheduledDate.map { Timestamp(date: $0) } ?? NSNull()
        let trimmedBudget = mission.budget?.trimmingCharacters(in: .whitespacesAndNewlines)
        data["budget"] = (trimmedBudget?.isEmpty == false) ? trimmedBudget! : NSNull()

        do {
            try await ref.setData(data, merge: true)
            log("saved mission \(mission.cardId) [status=\(mission.status.rawValue)]")
        } catch {
            log("ERROR saveMission \(mission.cardId): \(error.localizedDescription)")
        }
    }

    // MARK: - Observe (deliver remote missions to the caller)

    /// Attaches a snapshot listener on the couple's missions subcollection. Calls
    /// `onUpsert` for each added/modified mission and `onRemove(cardId)` for a
    /// deletion. On first attach this fires for every existing mission (initial
    /// hydration). The caller owns the returned registration and must `.remove()`.
    func observeMissions(
        coupleId: String,
        onUpsert: @escaping (RemoteMission) -> Void,
        onRemove: @escaping (String) -> Void
    ) -> ListenerRegistration {
        let ref = db.collection("couples").document(coupleId).collection("missions")

        return ref.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                self?.log("missions listener error: \(error.localizedDescription)")
                return
            }
            guard let snapshot else { return }

            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified:
                    guard let remote = try? change.document.data(as: RemoteMission.self) else { continue }
                    self?.log("mission delivered \(remote.cardId) [status=\(remote.status)]")
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
        print("📋 MissionService: \(message)")
        #endif
    }
}
