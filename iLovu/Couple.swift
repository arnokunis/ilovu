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

    /// Storage path (NOT a download URL) of the shared couple photo — one image
    /// both partners see, set/changed by either via CoupleService.setCouplePhoto.
    /// We persist the path ref and fetch bytes through the Storage SDK + rules,
    /// so nothing sensitive (no token, no API key) is ever baked into the doc.
    /// nil until a photo is set. Optional/defaulted so older docs decode cleanly.
    var couplePhotoPath: String? = nil

    /// When the couple photo last changed. Doubles as the cache-bust token: the
    /// image cache keys on this, so a change on one phone invalidates the other's
    /// cached copy and re-downloads. nil until a photo is set.
    var couplePhotoUpdatedAt: Timestamp? = nil

    /// COUPLE-LEVEL "together since" date — one shared truth, set by either
    /// partner, powering the days-together counter. Distinct from `createdAt`
    /// (the *pairing* date). nil until set; optional/defaulted so older docs
    /// decode cleanly. (All special-dates fields are optional + editable later —
    /// never enter-once-or-lose.)
    var anniversaryDate: Timestamp? = nil

    /// uid -> birthday. PER-PARTNER, same shape as `displayNames`: each member
    /// writes their OWN entry; the partner reads it off the shared doc.
    var birthdays: [String: Timestamp]? = nil

    /// COUPLE-LEVEL relationship stage ("Dating" | "Engaged" | "Married"), set by
    /// either partner. nil until set.
    var relationshipStatus: String? = nil

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

    /// The signed-in member's own birthday, if set.
    func birthday(of uid: String) -> Date? {
        birthdays?[uid]?.dateValue()
    }

    /// The partner's birthday, if they've set one.
    func partnerBirthday(currentUid uid: String) -> Date? {
        guard let partner = partner(of: uid) else { return nil }
        return birthdays?[partner]?.dateValue()
    }

    /// Days together, counting the anniversary itself as DAY 1 (so it never reads
    /// "0 days" — warmer for a love app). nil until an anniversary is set; clamps
    /// to at least 1 if the date is today or somehow in the future.
    func daysTogether(asOf now: Date = Date()) -> Int? {
        guard let start = anniversaryDate?.dateValue() else { return nil }
        let cal = Calendar.current
        let elapsed = cal.dateComponents([.day],
                                         from: cal.startOfDay(for: start),
                                         to: cal.startOfDay(for: now)).day ?? 0
        return max(1, elapsed + 1)
    }
}
