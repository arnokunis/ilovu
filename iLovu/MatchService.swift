// MatchService.swift
// All Firestore reads/writes for real two-player matching live here, so swipe
// views call intent-named methods and never touch Firestore directly. Owned at
// the app root (iLovuApp) and injected via the environment, same as CoupleService.
//
// Two halves (see project design):
//   recordLike(...)   -> write MY like, then read-after-write to detect whether
//                        BOTH partners now like the card; if so, create the match
//                        doc and return true so the caller can celebrate now.
//   observeMatches(...) -> an app-level snapshot listener that delivers match docs
//                          (including ones created while this user was away) so the
//                          partner who didn't complete the match still sees it.
//
// Only RIGHT-swipes are written (a left-swipe calls nothing). Both subcollections
// key on cardId, so a both-liked-at-once race collapses to one doc.
//
// Writes go through the swipes/matches security rules: a member may only add
// their own uid to likedBy, and isCoupleMember scopes everything to the couple.
//
// Failures are SILENT to callers (recordLike returns false, same fallback spirit
// as the rest of the app) but printed under #if DEBUG so likes vs matches are
// visible in the console while build-testing.

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class MatchService {

    // Computed so constructing MatchService touches no Firebase — it can be
    // default-initialized at the app root and in previews. firestore() returns
    // the cached default instance, so this is cheap per request.
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Record a like (the completing path)

    /// Records the signed-in user's right-swipe on `cardId` and reports whether
    /// that completes a match (both partners have now liked it). On a match it
    /// also creates the match doc — that's what the app-level listener delivers
    /// to the *other* partner. Returns false on any miss/error (caller falls back
    /// to "no match", i.e. just advances to the next card).
    func recordLike(coupleId: String, cardId: String, deck: Deck) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            log("recordLike skipped — not signed in")
            return false
        }

        let swipeRef = db.collection("couples").document(coupleId)
            .collection("swipes").document(cardId)

        do {
            // Record my like. setData(merge:) + arrayUnion handles BOTH the
            // first-liker create (likedBy becomes [me]) and the second-liker
            // update (likedBy becomes [partner, me]) in one call — and both
            // shapes satisfy the swipes rules.
            try await swipeRef.setData([
                "cardId":    cardId,
                "deck":      deck.rawValue,
                "likedBy":   FieldValue.arrayUnion([uid]),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            // Read-after-write: who likes this card now? Server read is strongly
            // consistent, so the second liker always sees both uids here.
            let snap  = try await swipeRef.getDocument()
            let swipe = try? snap.data(as: CardSwipe.self)
            let likedBy = Set(swipe?.likedBy ?? [])

            // The rules guarantee every entry in likedBy is a distinct member who
            // added only themselves, so two distinct uids == both partners liked.
            AppAnalytics.log("card_liked", ["deck": deck.rawValue])

            guard likedBy.count >= 2 else {
                log("LIKE \(cardId) [\(deck.rawValue)] recorded — waiting on partner")
                return false
            }

            // Both liked → create the match doc. id == cardId makes a both-at-once
            // race idempotent (same doc, same content). merge:true so a duplicate
            // create from the other client is harmless.
            try await db.collection("couples").document(coupleId)
                .collection("matches").document(cardId)
                .setData([
                    "cardId":    cardId,
                    "deck":      deck.rawValue,
                    // The completer (this user, the second liker). The Stage 5
                    // nudge function reads this to push the OTHER partner — the one
                    // who liked it earlier and isn't here to see the celebration.
                    "createdBy": uid,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)

            log("MATCH \(cardId) [\(deck.rawValue)] — both liked 🎉")
            AppAnalytics.log("match_created", ["deck": deck.rawValue])
            return true
        } catch {
            log("ERROR recordLike \(cardId): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Observe matches (the delivery path)

    /// Attaches a snapshot listener on the couple's matches subcollection and
    /// calls `onMatch` for each match document as it's ADDED. The caller owns the
    /// returned registration and must call `.remove()` when done.
    ///
    /// IMPORTANT for the caller (piece 3): on first attach this fires `.added`
    /// for EVERY existing match doc — including old ones from previous sessions.
    /// That's intentional (a match made while the app was closed must still be
    /// delivered), but it means the host MUST dedupe against a PERSISTED set of
    /// already-celebrated cardIds, or every past match replays on each launch.
    func observeMatches(
        coupleId: String,
        onMatch: @escaping (CardMatch) -> Void
    ) -> ListenerRegistration {
        let matchesRef = db.collection("couples").document(coupleId).collection("matches")

        return matchesRef.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                self?.log("matches listener error: \(error.localizedDescription)")
                return
            }
            guard let snapshot else { return }

            // documentChanges gives us only what changed; .added covers both the
            // initial existing docs and live arrivals.
            for change in snapshot.documentChanges where change.type == .added {
                guard let match = try? change.document.data(as: CardMatch.self) else { continue }
                self?.log("match delivered \(match.cardId) [\(match.deck)]")
                onMatch(match)
            }
        }
    }

    // MARK: - Debug logging

    private func log(_ message: String) {
        #if DEBUG
        print("💞 MatchService: \(message)")
        #endif
    }
}
