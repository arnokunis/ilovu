// Invite.swift
// The Firestore model for an invite. The document ID *is* the invite token —
// an unguessable, securely-random string — so the doc carries no separate
// token field. One user creates an invite; another redeems it to form a couple.
//
// Mirrors the field contract enforced by firestore.rules:
//   invites/{token} -> creatorId, status, consumedBy, createdAt
//
// This model is used for *reads* (decoding). Writes go through CoupleService as
// explicit dictionaries, so the document shape matches the rules exactly —
// notably `consumedBy` written as an explicit null on create.

import Foundation
import FirebaseFirestore

struct Invite: Codable, Identifiable {

    // The doc ID = the token. Populated on decode; omitted on encode.
    @DocumentID var token: String?

    var creatorId: String
    var status: InviteStatus
    var consumedBy: String?

    // Server-stamped on create; read-only here.
    @ServerTimestamp var createdAt: Timestamp?

    var id: String? { token }
}

enum InviteStatus: String, Codable {
    case pending
    case consumed
}
