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
    @ServerTimestamp var createdAt: Timestamp?

    /// The *other* member's uid, from the current user's point of view.
    /// nil if this somehow isn't a two-person couple.
    func partner(of uid: String) -> String? {
        members.first { $0 != uid }
    }
}
