// CoupleService.swift
// All Firestore reads/writes for the invite + couple system live here, so the
// rest of the app calls intent-named async methods and never touches Firestore
// directly. Owned once at the app root (iLovuApp) and injected via the
// environment, the same way MissionStore / MemoryStore are.
//
// Two flows:
//   createInvite()  -> a creator mints an invite, returns its share token
//   redeem(token:)  -> a redeemer consumes a pending invite, and a couple doc
//                      is created linking both users
//
// Writes are sent as explicit dictionaries (not Codable encodes) so the document
// shape matches firestore.rules byte-for-byte — notably `consumedBy: NSNull()`
// on create, which the create rule checks (`== null`), and a redeem update that
// touches ONLY status + consumedBy, which the update rule requires.
//
// PRE-LAUNCH HARDENING: redeem() does two writes — consume the invite, then
// create the couple — which are NOT atomic. The rules block the abusive cases
// (double-redeem, spoofing consumedBy, forging membership), but binding the two
// writes into one tamper-proof transaction is deferred to a Cloud Function.

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class CoupleService {

    // Computed (not stored) so constructing CoupleService touches no Firebase —
    // it can be default-initialized at the app root and in previews without
    // requiring FirebaseApp.configure() to have run. firestore() returns the
    // cached default instance, so this is cheap to call per request.
    private var db: Firestore { Firestore.firestore() }

    // The signed-in user's couple, once resolved. Observable (this class is
    // @Observable) so the whole app reacts the MOMENT pairing completes — not
    // just on next launch. This is the keystone the redeemer was missing: before,
    // redeem() wrote to Firestore but updated nothing local, so MainTabView's
    // coupleId stayed nil for the rest of the session. Now redeem() / currentCouple()
    // publish here and every observer (MainTabView, the swipe decks) follows.
    // nil = unknown or not paired.
    private(set) var couple: Couple?

    /// The current couple's document id, or nil if unpaired. The swipe decks and
    /// the matches listener key off this.
    var coupleId: String? { couple?.id }

    /// The partner's display name from the shared couple doc, or nil if unpaired
    /// or they haven't set one yet. Reads the signed-in uid here so views (HomeView)
    /// don't have to touch Auth/Firebase themselves.
    var partnerDisplayName: String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return couple?.partnerName(currentUid: uid)
    }

    enum InviteError: LocalizedError {
        case notSignedIn
        case inviteNotFound
        case alreadyConsumed
        case cannotRedeemOwnInvite

        var errorDescription: String? {
            switch self {
            case .notSignedIn:           "You need to be signed in."
            case .inviteNotFound:        "This invite link isn't valid."
            case .alreadyConsumed:       "This invite has already been used."
            case .cannotRedeemOwnInvite: "You can't redeem your own invite."
            }
        }
    }

    // MARK: - Create

    /// Mints a new invite owned by the signed-in user and returns its token (the
    /// document ID) to share. The token IS the secret — the rules let any signed-in
    /// user read an invite *if they know its id* — so never log it or expose it
    /// anywhere public; hand it straight to a share sheet / deep link.
    @discardableResult
    func createInvite() async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw InviteError.notSignedIn }

        let token = Self.makeToken()
        try await db.collection("invites").document(token).setData([
            "creatorId": uid,
            "status": InviteStatus.pending.rawValue,
            "consumedBy": NSNull(),                       // explicit null — create rule checks == null
            "createdAt": FieldValue.serverTimestamp()
        ])
        return token
    }

    // MARK: - Redeem

    /// Redeems an invite by token: consumes it, then creates the couple doc
    /// linking creator + redeemer. Returns the new couple's id.
    @discardableResult
    func redeem(token: String) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw InviteError.notSignedIn }

        let inviteRef = db.collection("invites").document(token)

        // Read first, for precise error messages. The rules re-check every one
        // of these conditions on the write itself, so a redeemer who races past
        // this read still can't slip an invalid redemption through.
        let snapshot = try await inviteRef.getDocument()
        guard snapshot.exists, let invite = try? snapshot.data(as: Invite.self) else {
            throw InviteError.inviteNotFound
        }
        guard invite.status == .pending else { throw InviteError.alreadyConsumed }
        guard invite.creatorId != uid else { throw InviteError.cannotRedeemOwnInvite }

        // Consume the invite — touches ONLY status + consumedBy (redeem rule).
        // If someone redeemed it between our read and here, the rule denies this
        // write and it throws — which is the correct outcome (one-shot invite).
        try await inviteRef.updateData([
            "status": InviteStatus.consumed.rawValue,
            "consumedBy": uid
        ])

        // Link the two users. members must be exactly two and include us (create rule).
        let coupleRef = db.collection("couples").document()
        try await coupleRef.setData([
            "members": [invite.creatorId, uid],
            "createdAt": FieldValue.serverTimestamp()
        ])

        // Publish the new couple locally right away. This is what lets the
        // redeemer's app flip from "unpaired" to "paired" mid-session — without
        // it, the couple existed in Firestore but nothing on this device knew,
        // so swipes kept hitting the solo coin-flip fallback. createdAt stays nil
        // until a read resolves the server timestamp; we don't need it locally.
        couple = Couple(id: coupleRef.documentID, members: [invite.creatorId, uid], createdAt: nil)
        // If a name was set while still unpaired, write it now that there's a couple.
        await flushPendingDisplayName()
        return coupleRef.documentID
    }

    // MARK: - Lookup

    /// The current user's couple, if they're in one. The couples read rule
    /// (uid must be in members) guarantees this only ever returns your own.
    /// Caches the result into `couple` so observers (MainTabView) pick it up on a
    /// cold launch the same way they pick up a fresh redeem.
    @discardableResult
    func currentCouple() async throws -> Couple? {
        guard let uid = Auth.auth().currentUser?.uid else { throw InviteError.notSignedIn }
        let query = try await db.collection("couples")
            .whereField("members", arrayContains: uid)
            .limit(to: 1)
            .getDocuments()
        let resolved = try query.documents.first?.data(as: Couple.self)
        // Don't clobber an already-published couple with a nil from a racing read
        // (e.g. redeem() just set it but this query hasn't seen the write yet).
        if let resolved {
            couple = resolved
            // A name set before the couple loaded now has somewhere to go.
            await flushPendingDisplayName()
        }
        return resolved
    }

    // MARK: - Display name

    // Where a name set before the couple is loaded (or while a write fails) is
    // parked, so it isn't silently lost. Flushed by flushPendingDisplayName()
    // once a couple is available — see currentCouple() / redeem().
    private let pendingDisplayNameKey = "pendingDisplayName"

    /// Publishes the signed-in user's display name onto the shared couple doc so
    /// the partner can read it (couples/{id}.displayNames[myUid]). Uses a dot-path
    /// update so only this user's entry changes; the couples update rule allows it
    /// because `members` stays frozen. Mirrors into the published couple so local
    /// observers refresh without a re-read.
    ///
    /// Robust against the timing race that dropped writes before: if `couple`
    /// isn't loaded yet it resolves it first, and if it still can't (genuinely
    /// unpaired) or the write fails, it parks the name to retry at the next
    /// pairing / couple load instead of no-opping silently.
    func setDisplayName(_ name: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            log("setDisplayName skipped — not signed in")
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // (#2) Resolve the couple if the in-memory state hasn't caught up yet —
        // this is the race that silently dropped the redeemer's name.
        if couple?.id == nil {
            log("setDisplayName — couple not loaded, resolving…")
            _ = try? await currentCouple()
        }

        guard let coupleId = couple?.id else {
            // (#3) Genuinely unpaired — park it and bail without losing it.
            UserDefaults.standard.set(trimmed, forKey: pendingDisplayNameKey)
            log("setDisplayName — no couple yet, parked pending name '\(trimmed)'")
            return
        }

        do {
            try await db.collection("couples").document(coupleId)
                .updateData(["displayNames.\(uid)": trimmed])
            // Success — supersede any parked value and mirror locally.
            UserDefaults.standard.removeObject(forKey: pendingDisplayNameKey)
            var names = couple?.displayNames ?? [:]
            names[uid] = trimmed
            couple?.displayNames = names
            log("setDisplayName — wrote '\(trimmed)' for \(uid) to couple \(coupleId)")
        } catch {
            // (#3) Park for retry — the name still lives locally in @AppStorage.
            UserDefaults.standard.set(trimmed, forKey: pendingDisplayNameKey)
            log("setDisplayName — write FAILED (\(error.localizedDescription)); parked pending name")
        }
    }

    /// Writes any name parked by setDisplayName once a couple is available. Called
    /// after the couple loads (currentCouple) or is created (redeem). No-op if
    /// nothing's parked or we're still unpaired. setDisplayName clears the parked
    /// value on a successful write, so this converges.
    func flushPendingDisplayName() async {
        guard couple?.id != nil else { return }
        guard let pending = UserDefaults.standard.string(forKey: pendingDisplayNameKey),
              !pending.isEmpty else { return }
        log("flushing parked pending name '\(pending)'")
        await setDisplayName(pending)
    }

    // MARK: - Debug logging

    private func log(_ message: String) {
        #if DEBUG
        print("👥 CoupleService: \(message)")
        #endif
    }

    // MARK: - Deep links
    // Invite links use a custom URL scheme: ilovu://invite/<token>. A custom
    // scheme keeps this server-free (no domain / apple-app-site-association);
    // the tradeoff is the link only resolves if the app is installed.

    // nonisolated: immutable Sendable constants that have nothing to do with the
    // main actor — they only inherited its isolation from the @MainActor class.
    // Marking them nonisolated lets the nonisolated parsing helpers below read
    // them without crossing an isolation boundary. There's no mutable state and
    // no race here; the @MainActor isolation was noise, not protection.
    nonisolated static let inviteURLScheme = "ilovu"
    nonisolated static let inviteURLHost   = "invite"

    /// Builds the shareable deep link for an invite token.
    /// `nonisolated`: pure string work, safe to call off the main actor.
    nonisolated static func inviteURL(token: String) -> URL {
        URL(string: "\(inviteURLScheme)://\(inviteURLHost)/\(token)")!
    }

    /// Extracts the token from an incoming invite link, or nil if `url` isn't one.
    /// `nonisolated`: pure parsing, no actor state touched.
    nonisolated static func inviteToken(from url: URL) -> String? {
        guard url.scheme == inviteURLScheme, url.host == inviteURLHost else { return nil }
        // ilovu://invite/<token> -> pathComponents ["/", "<token>"]
        guard let token = url.pathComponents.first(where: { $0 != "/" }), !token.isEmpty else {
            return nil
        }
        return token
    }

    // MARK: - Token

    /// 16 cryptographically-random bytes → Crockford base32 (~26 chars, 128 bits
    /// of entropy). Unguessable by design — that's the entire security premise of
    /// the invite rules, since any signed-in user may read an invite by its id.
    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            // SecRandomCopyBytes essentially never fails; UUID is a safe fallback.
            return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }

        // Crockford base32: digits + letters minus i, l, o, u (avoids ambiguity).
        let alphabet = Array("0123456789abcdefghjkmnpqrstvwxyz")
        var out = ""
        var buffer = 0
        var bits = 0
        for byte in bytes {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                out.append(alphabet[(buffer >> bits) & 0x1f])
            }
        }
        if bits > 0 {
            out.append(alphabet[(buffer << (5 - bits)) & 0x1f])
        }
        return out
    }
}
