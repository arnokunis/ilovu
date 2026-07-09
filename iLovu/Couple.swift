// Couple.swift
// The Firestore model linking exactly two users, created at redemption time.
//   couples/{coupleId} -> members (two uids), createdAt
//
// Both members can read it (firestore.rules); the membership list is frozen on
// update so neither side can add, drop, or swap who's in the relationship.

import Foundation
import FirebaseFirestore

// The couple's relationship milestones. Stored as a map on the couple doc
// (milestones[rawValue] -> Timestamp), so adding a new milestone later (moved in
// together, first trip…) needs no migration. Which ones are RELEVANT depends on
// relationship status — see CoupleStoryView — but `dating` always exists as the
// source of the Days Together counter.
enum CoupleMilestone: String, CaseIterable {
    case dating      // when they first met / started dating — drives "Days Together"
    case engaged     // engagement day
    case wedding     // wedding day
}

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

    /// Relationship milestones, keyed by CoupleMilestone.rawValue (dating /
    /// engaged / wedding). COUPLE-LEVEL — either partner sets them; which are
    /// shown depends on relationshipStatus. All optional + editable later. Hidden
    /// (status-irrelevant) milestones are never deleted, only not shown.
    var milestones: [String: Timestamp]? = nil

    /// LEGACY: the original single "together since" field. No longer written —
    /// kept only as a non-destructive read fallback for the `dating` milestone so
    /// couples who set it before the milestones rework keep their counter.
    var anniversaryDate: Timestamp? = nil

    /// uid -> birthday. PER-PARTNER, same shape as `displayNames`: each member
    /// writes their OWN entry; the partner reads it off the shared doc.
    var birthdays: [String: Timestamp]? = nil

    /// COUPLE-LEVEL relationship stage ("Dating" | "Engaged" | "Married"), set by
    /// either partner. nil until set.
    var relationshipStatus: String? = nil

    /// COUPLE-LEVEL subscription flag — "one subscription unlocks BOTH partners".
    /// Written ONLY by the payer (the partner whose RevenueCat entitlement is
    /// active) via CoupleService.syncPremiumEntitlement; both partners then read
    /// premium access off this. Optional/defaulted so older docs decode cleanly.
    /// See SubscriptionService for the full sharing + revocation model.
    var isPremium: Bool? = nil

    /// The uid of the PAYER whose entitlement set `isPremium`. Locked design intent
    /// (CLAUDE.md): on breakup the subscription follows this user. Also lets the
    /// client-mirror revoke path ensure only the payer ever clears the flag.
    var subscriptionOwner: String? = nil

    /// When the subscription flag last changed. Audit/cache-bust only.
    var subscriptionUpdatedAt: Timestamp? = nil

    /// SHARED ~1km location bucket ("%.2f,%.2f") for the Near You event deck. Both
    /// partners build their event-cache query key from THIS, so they fetch the
    /// SAME curated deck and their swipe cardIds line up for matching — instead of
    /// each phone's GPS producing two disjoint decks (which would silently kill
    /// event matches when partners are even slightly apart). Claimed/refreshed by
    /// whoever opens Near You with a fresh GPS fix; see CoupleService.setEventLocation
    /// and NearYouView. nil until first claimed. Optional/defaulted so older docs
    /// decode cleanly.
    var eventLocationBucket: String? = nil

    /// When `eventLocationBucket` was last set — debounces re-anchoring (a travel
    /// move only overrides an OLDER stored bucket, so two co-located partners
    /// straddling a bucket boundary don't ping-pong it). nil until first claimed.
    var eventLocationUpdatedAt: Timestamp? = nil

    /// When either partner last fired the manual "come swipe with me" nudge.
    /// Written ONLY by the `nudgePartner` Cloud Function (server timestamp); the
    /// client just reads it to reflect the shared per-couple cooldown on the Nudge
    /// button. nil until the first nudge. Optional/defaulted so older docs decode.
    var lastManualNudgeAt: Timestamp? = nil

    /// uids of members who DELETED their account (App Store 5.1.1(v) account
    /// deletion). Written ONLY by the `deleteAccount` Cloud Function, which ALSO
    /// scrubs that uid's personal identifiers (displayNames / birthdays / fcmTokens)
    /// — so a departed partner leaves no ghost name or birthday behind, and the
    /// surviving partner keeps the shared couple doc + Memory Vault. `members` is
    /// left intact so read rules + partner resolution stay structurally valid; the
    /// app branches on `isOrphaned` to show a gentle "your partner left" state.
    /// Only the surviving partner can ever read this (the leaver's account is gone).
    /// nil/absent on a healthy couple. Optional/defaulted so older docs decode.
    var deletedMembers: [String]? = nil

    /// True once a member has deleted their account — from the reader's point of
    /// view that always means "my partner left" (the leaver can't read this doc).
    var isOrphaned: Bool { !(deletedMembers ?? []).isEmpty }

    /// The *other* member's uid, from the current user's point of view. nil if this
    /// somehow isn't a two-person couple, OR if the resolved partner has deleted
    /// their account — so every partner-identity site (name, birthday, nudge target)
    /// degrades to "no partner" instead of surfacing a departed ghost.
    func partner(of uid: String) -> String? {
        let gone = deletedMembers ?? []
        return members.first { $0 != uid && !gone.contains($0) }
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

    /// A milestone's date, or nil if unset. `dating` falls back to the legacy
    /// `anniversaryDate` so pre-rework data still resolves.
    func milestoneDate(_ milestone: CoupleMilestone) -> Date? {
        if let ts = milestones?[milestone.rawValue] { return ts.dateValue() }
        if milestone == .dating { return anniversaryDate?.dateValue() }   // legacy fallback
        return nil
    }

    /// Days together, ALWAYS from the `dating` date (the true together-count,
    /// regardless of later engagement/marriage), counting the start day itself as
    /// DAY 1 (so it never reads "0 days"). nil until the dating date is set;
    /// clamps to at least 1 if the date is today or somehow in the future.
    func daysTogether(asOf now: Date = Date()) -> Int? {
        guard let start = milestoneDate(.dating) else { return nil }
        let cal = Calendar.current
        let elapsed = cal.dateComponents([.day],
                                         from: cal.startOfDay(for: start),
                                         to: cal.startOfDay(for: now)).day ?? 0
        return max(1, elapsed + 1)
    }
}
