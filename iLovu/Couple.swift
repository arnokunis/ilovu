// Couple.swift
// The Firestore model linking exactly two users, created at redemption time.
//   couples/{coupleId} -> members (two uids), createdAt
//
// Both members can read it (firestore.rules); the membership list is frozen on
// update so neither side can add, drop, or swap who's in the relationship.

import Foundation
import FirebaseFirestore

struct Couple: Codable, Identifiable {

    @DocumentID var id: String?
    var members: [String]

    /// uid -> chosen display name. Each member writes their OWN name here (via
    /// CoupleService.setDisplayName) so the partner can read it off the shared
    /// doc. Optional/defaulted so older couple docs (and the redeem-time create,
    /// which doesn't set it) decode cleanly. The couples update rule already
    /// permits this — it only freezes `members`.
    var displayNames: [String: String]? = nil

    @ServerTimestamp var createdAt: Timestamp?

    /// The *other* member's uid, from the current user's point of view.
    /// nil if this somehow isn't a two-person couple.
    func partner(of uid: String) -> String? {
        members.first { $0 != uid }
    }

    /// The partner's chosen display name, if they've set one yet.
    func partnerName(currentUid uid: String) -> String? {
        guard let partner = partner(of: uid) else { return nil }
        let name = displayNames?[partner]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false) ? name : nil
    }
}
