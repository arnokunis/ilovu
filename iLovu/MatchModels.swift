// MatchModels.swift
// The Firestore-side shapes for real two-player matching. Both live UNDER the
// couple doc, so they inherit couple-membership scoping in the rules:
//
//   couples/{coupleId}/swipes/{cardId}  -> CardSwipe  (shared like record)
//   couples/{coupleId}/matches/{cardId} -> CardMatch  (created when both like)
//
// Only RIGHT-swipes (likes) are persisted in v1 — a left-swipe writes nothing.
// A card is a match the moment both members' uids appear in `likedBy`. The match
// doc carries only cardId + deck (no card content): each client rebuilds the
// full DateCard / LocalEvent from its local sample array via SampleCards.byId /
// SampleEvents.byId. Doc id == cardId in both collections, so a both-liked-at-once
// race collapses to a single doc.
//
// Convention matches CachedVenue / Couple: @DocumentID for the doc id (left nil
// on write, populated on read), @ServerTimestamp for server-stamped times.

import Foundation
import FirebaseFirestore

// Which sample deck a swipe/match belongs to. Stored as its rawValue string so
// the listener knows whether to resolve the cardId against SampleCards (date
// ideas) or SampleEvents (local events).
enum Deck: String, Codable {
    case dates
    case events
    // Near You can be fed by either source; the deck a swipe belongs to decides
    // how the partner's app rebuilds the matched card (events -> EventCache by
    // eventId; places -> VenueCache by placeId). A venue and an event resolve
    // through different caches, so they need distinct deck values — reusing
    // `events` for a placeId would make the partner's reconstruction miss.
    case places
}

// MARK: - couples/{coupleId}/swipes/{cardId}

struct CardSwipe: Codable, Identifiable {

    /// == the doc id (the stable cardId). Populated on read, nil on write.
    @DocumentID var id: String?

    /// Same value as the doc id, as a plain queryable field (survives encoding).
    var cardId: String

    /// "dates" or "events" — see Deck.
    var deck: String

    /// uids who right-swiped this card. BOTH members present => it's a match.
    /// Written via arrayUnion(myUid); the rules let a member add only their own.
    var likedBy: [String]

    @ServerTimestamp var updatedAt: Timestamp?
}

// MARK: - couples/{coupleId}/matches/{cardId}

struct CardMatch: Codable, Identifiable {

    /// == the doc id (the stable cardId). Populated on read, nil on write.
    @DocumentID var id: String?

    var cardId: String
    var deck: String

    @ServerTimestamp var createdAt: Timestamp?
}
