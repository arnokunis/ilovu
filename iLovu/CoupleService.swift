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
import FirebaseFunctions
import FirebaseStorage

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
    // just on next launc1h. This is the keystone the redeemer was missing: before,
    // redeem() wrote to Firestore but updated nothing local, so MainTabView's
    // coupleId stayed nil for the rest of the session. Now redeem() / currentCouple()
    // publish here and every observer (MainTabView, the swipe decks) follows.
    // nil = unknown or not paired.
    private(set) var couple: Couple?

    /// The current couple's document id, or nil if unpaired. The swipe decks and
    /// the matches listener key off this.
    var coupleId: String? { couple?.id }

    /// Scope key for per-user LOCAL gate state (PaywallGate). Prefers the couple —
    /// one subscription unlocks both partners, so paired state must stay shared —
    /// and falls back to a per-uid solo scope so an UNPAIRED user still has a
    /// durable identity to arm the paywall against. Before 1.0.8 there was no
    /// fallback, so a solo user could never see the wall at any duration.
    /// nil only when signed out, in which case no gate should evaluate at all.
    var paywallScopeId: String? {
        if let id = couple?.id { return id }
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return "solo.\(uid)"
    }

    /// Scope key used by the DEVICE fallback below. Deliberately not a uid: it
    /// exists precisely for the moments when there isn't one.
    static let deviceScopeId = "device"

    /// The scope every paywall check should use — never nil.
    ///
    /// WHY THIS EXISTS (found 2026-08-16, from BigQuery): all three gate call
    /// sites used to `guard let paywallScopeId else { …skip… }`, so a nil scope
    /// meant the gate silently did not run — no wall, no log, no error. Two of
    /// the six heaviest users in the app's history escaped the paywall entirely
    /// that way: 42 swipes in a day from Munich and 30 from Accra, both with
    /// `paywall_shown` = 0, against a cap of 20. A monetization gate must fail
    /// CLOSED; failing open is unbounded and, worse, invisible.
    ///
    /// The trade is deliberate: after signing in, the scope moves from "device"
    /// to "solo.<uid>" and that day's allowance restarts, so a user can get up to
    /// one extra day of swipes across that boundary. Being over-generous by a day
    /// beats today's behaviour of being over-generous forever.
    ///
    /// `context` labels WHERE the fallback happened, because the root cause is
    /// still open: either Near You is reachable before Auth restores on a cold
    /// launch, or those users were genuinely signed out. One day of this event
    /// answers it.
    func paywallScope(_ context: String) -> String {
        if let id = paywallScopeId { return id }
        AppAnalytics.log("paywall_scope_missing", ["context": context])
        return Self.deviceScopeId
    }

    /// The partner's display name from the shared couple doc, or nil if unpaired
    /// or they haven't set one yet. Reads the signed-in uid here so views (HomeView)
    /// don't have to touch Auth/Firebase themselves.
    var partnerDisplayName: String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return couple?.partnerName(currentUid: uid)
    }

    /// True when the partner has deleted their account, leaving this user the sole
    /// surviving member of the couple doc. The whole app branches on this to show a
    /// gentle "your partner left" state and to suppress partner-facing affordances
    /// (nudge, daily-question reveal) instead of hanging on a partner who's gone.
    var isOrphaned: Bool { couple?.isOrphaned ?? false }

    /// Storage path of the shared couple photo, or nil if none set / unpaired.
    /// Views pass this to CachedStorageImage.
    var couplePhotoPath: String? { couple?.couplePhotoPath }

    /// Cache-bust token for the couple photo — changes whenever the photo does,
    /// so CachedStorageImage re-downloads. Empty string when no photo is set.
    var couplePhotoVersion: String {
        guard let ts = couple?.couplePhotoUpdatedAt else { return "" }
        return String(Int(ts.dateValue().timeIntervalSince1970))
    }

    /// A relationship milestone's date (dating / engaged / wedding), or nil.
    /// Falls back to the locally parked dating date when unpaired, so the Couple
    /// Story editor pre-fills and the counter reads correctly before pairing.
    func milestoneDate(_ milestone: CoupleMilestone) -> Date? {
        if let onCouple = couple?.milestoneDate(milestone) { return onCouple }
        return milestone == .dating ? soloDatingDate : nil
    }

    /// The "started dating" date — the source of the Days Together counter.
    var datingDate: Date? { couple?.milestoneDate(.dating) }

    /// Days together (start day = day 1), or nil until the dating date is set.
    var daysTogether: Int? { couple?.daysTogether() }

    /// The couple's relationship stage, or nil if unset. Falls back to the locally
    /// parked pick when unpaired (the Couple Story editor keys its visible
    /// milestones off this, so without the fallback the date field vanishes).
    var relationshipStatus: String? { couple?.relationshipStatus ?? soloRelationshipStatus }

    // MARK: - Solo (unpaired) relationship details
    //
    // Milestones live on the couple doc, so before 1.0.8 an unpaired user could
    // open the Couple Story editor, pick a status, enter their dating date — and
    // silently lose it, because setMilestone/setRelationshipStatus write to a
    // couple that does not exist. The Days Together widget therefore rendered
    // BLANK for the ~96% who are unpaired, even though "love counter" is the #1
    // converting Apple Search Ads keyword: people pay to install FOR the counter
    // and hit nothing. Park both locally and flush at pairing — the same shape as
    // the parked display name and FCM token.

    private static let soloDatingKey = "solo.datingDate"
    private static let soloStatusKey = "solo.relationshipStatus"

    private(set) var soloDatingDate: Date? =
        UserDefaults.standard.object(forKey: CoupleService.soloDatingKey) as? Date
    private(set) var soloRelationshipStatus: String? =
        UserDefaults.standard.string(forKey: CoupleService.soloStatusKey)

    // Solo Near You location, parked locally for exactly the reason the dating
    // date is: it lives on the couple doc, so before 2026-09-02 an unpaired user
    // had nowhere to put it — and the whole "search a city / plan a trip" bar was
    // therefore hidden from them. After the places pivot that is ~98% of users,
    // and searching another city is a headline feature, so it parks here instead.
    private static let soloBucketKey = "solo.eventLocationBucket"
    private static let soloManualKey = "solo.eventLocationManual"
    private static let soloLabelKey  = "solo.eventLocationLabel"

    private(set) var soloEventBucket: String? =
        UserDefaults.standard.string(forKey: CoupleService.soloBucketKey)
    private(set) var soloEventManual: Bool =
        UserDefaults.standard.bool(forKey: CoupleService.soloManualKey)
    private(set) var soloEventLabel: String? =
        UserDefaults.standard.string(forKey: CoupleService.soloLabelKey)

    /// Dating date to DISPLAY: the couple's when paired, the locally parked one
    /// when not. Use this for widgets and UI; `datingDate` stays couple-only.
    var effectiveDatingDate: Date? { couple?.milestoneDate(.dating) ?? soloDatingDate }

    /// Days together from `effectiveDatingDate`, so the counter works solo.
    /// Start day counts as day 1, matching Couple.daysTogether().
    var effectiveDaysTogether: Int? {
        if let paired = couple?.daysTogether() { return paired }
        guard let start = soloDatingDate else { return nil }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())
        ).day
        return days.map { $0 + 1 }
    }

    /// Pushes anything parked while solo up to the couple doc, once one exists.
    /// Idempotent and non-destructive: it never overwrites a value the couple
    /// already carries, so a partner who set the date first always wins.
    func flushSoloRelationshipDetails() async {
        guard couple?.id != nil else { return }
        if let parked = soloDatingDate, couple?.milestoneDate(.dating) == nil {
            await setMilestone(.dating, date: parked)
        }
        if let parked = soloRelationshipStatus, couple?.relationshipStatus == nil {
            await setRelationshipStatus(parked)
        }
    }

    /// The couple's SHARED Near You location bucket ("%.1f,%.1f"), or nil until a
    /// partner has claimed one. NearYouView reads this to fetch the shared deck.
    var eventLocationBucket: String? { couple?.eventLocationBucket ?? soloEventBucket }

    /// When the shared event-location bucket was last set, or nil if never. Used
    /// by NearYouView's re-anchor debounce (only override an older stored bucket).
    var eventLocationUpdatedAt: Date? { couple?.eventLocationUpdatedAt?.dateValue() }
    var eventLocationManual: Bool { couple?.eventLocationManual ?? soloEventManual }
    var eventLocationLabel: String? { couple?.eventLocationLabel ?? soloEventLabel }

    /// The signed-in user's birthday, or nil if unset / unpaired.
    var myBirthday: Date? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return couple?.birthday(of: uid)
    }

    /// The partner's birthday, or nil if unset / unpaired.
    var partnerBirthday: Date? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return couple?.partnerBirthday(currentUid: uid)
    }

    enum InviteError: LocalizedError {
        case notSignedIn
        case inviteNotFound
        case alreadyConsumed
        case cannotRedeemOwnInvite
        case inviteExpired
        case tooManyAttempts
        case notPaired

        var errorDescription: String? {
            switch self {
            case .notSignedIn:           "You need to be signed in."
            case .inviteNotFound:        "This invite link isn't valid."
            case .alreadyConsumed:       "This invite has already been used."
            case .cannotRedeemOwnInvite: "You can't redeem your own invite."
            case .inviteExpired:         "This invite has expired — ask for a fresh code."
            case .tooManyAttempts:       "Too many attempts — please try again in an hour."
            case .notPaired:             "Connect with your partner first."
            }
        }
    }

    // Uploads couple-photo bytes to Cloud Storage. Stateless wrapper; cheap to
    // hold here so setCouplePhoto can move bytes without the views touching the
    // Storage SDK directly.
    private let storage = StorageService()

    // MARK: - Create

    /// Mints a new invite owned by the signed-in user and returns its token (the
    /// document ID) to share. The token IS the secret — the rules let any signed-in
    /// user read an invite *if they know its id* — so never log it or expose it
    /// anywhere public; hand it straight to a share sheet / deep link.
    /// `source` splits the funnel by WHERE the invite was created — the pairing
    /// screen versus a planned mission. The two asks are very different ("install
    /// my app" vs "come to this on Saturday"), and `invite_redeemed` has been
    /// stuck at 3 all-time, so which one converts is the question worth answering.
    @discardableResult
    func createInvite(source: String = "pairing_screen") async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw InviteError.notSignedIn }

        let token = Self.makeToken()
        var data: [String: Any] = [
            "creatorId": uid,
            "status": InviteStatus.pending.rawValue,
            "consumedBy": NSNull(),                       // explicit null — create rule checks == null
            "createdAt": FieldValue.serverTimestamp()
        ]
        // If push permission is already granted (a parked token exists), ride it
        // along so redeemInvite can ping this creator the moment the partner
        // connects. Creator-only invite reads keep the token private.
        if let fcm = pendingFCMToken { data["creatorFcmToken"] = fcm }
        try await db.collection("invites").document(token).setData(data)
        activeInviteToken = token
        AppAnalytics.log("invite_created", ["source": source])
        return token
    }

    // MARK: - Redeem

    /// Redeems an invite by token: consumes it, then creates the couple doc
    /// linking creator + redeemer. Returns the new couple's id.
    @discardableResult
    func redeem(token: String) async throws -> String {
        guard Auth.auth().currentUser != nil else { throw InviteError.notSignedIn }

        // Atomic redemption is a Cloud Function now: it consumes the invite AND
        // creates the couple doc in ONE Firestore transaction (Admin SDK), so the
        // two writes can't half-complete or be raced. firestore.rules forbids
        // client couple-creation and client invite-consumption outright — this
        // callable is the only path. Only NEW pairings run this; already-paired
        // couples never call redeem, so they're untouched.
        let coupleId: String
        let members: [String]
        do {
            let result = try await functions.httpsCallable("redeemInvite").call(["token": token])
            guard let data = result.data as? [String: Any],
                  let id = data["coupleId"] as? String,
                  let mems = data["members"] as? [String] else {
                throw InviteError.inviteNotFound
            }
            coupleId = id
            members = mems
        } catch let error as InviteError {
            Self.logRedeemFailure(error)
            throw error
        } catch {
            let mapped = Self.mapRedeemError(error)
            Self.logRedeemFailure(mapped)
            throw mapped
        }

        // Publish the new couple locally right away — this lets the redeemer's app
        // flip from "unpaired" to "paired" mid-session (before, nothing on-device
        // knew the couple existed, so swipes hit the solo coin-flip fallback).
        // createdAt stays nil until a read resolves the server timestamp.
        couple = Couple(id: coupleId, members: members, createdAt: nil)
        // A name / FCM token parked while unpaired now has somewhere to go.
        await flushPendingDisplayName()
        await flushPendingFCMToken()
        // Seed the onboarding name (which never goes through setDisplayName).
        await seedDisplayNameFromLocalIfNeeded()
        // Pull the freshly-set coupleId claim into this device's token (Storage
        // membership enforcement reads it).
        await refreshAuthClaims()
        AppAnalytics.log("invite_redeemed")
        return coupleId
    }

    /// Maps a `redeemInvite` callable failure back to the InviteError the redeem
    /// UI already knows. The machine-readable `reason` in the error details is what
    /// distinguishes "already used" from "your own invite" (the HttpsError code
    /// alone can't). Unknown / transport errors are returned unchanged so a network
    /// blip doesn't masquerade as "invalid invite".
    /// Records WHY a redemption failed.
    ///
    /// Until now `invite_redeemed` fired only on success and nothing fired on any
    /// failure path — so "the partner never tried" and "the partner tried and it
    /// broke" looked identical in GA4: a created invite with no redemption. Those
    /// have opposite fixes (persuasion vs mechanics), and with `invite_redeemed`
    /// stuck at 3 all-time we could only guess which we had.
    private static func logRedeemFailure(_ error: Error) {
        let reason: String
        switch error {
        case InviteError.inviteExpired:         reason = "expired"
        case InviteError.alreadyConsumed:       reason = "already_consumed"
        case InviteError.inviteNotFound:        reason = "not_found"
        case InviteError.cannotRedeemOwnInvite: reason = "own_invite"
        case InviteError.tooManyAttempts:       reason = "rate_limited"
        case InviteError.notSignedIn:           reason = "not_signed_in"
        default:                                reason = "other"
        }
        AppAnalytics.log("invite_redeem_failed", ["reason": reason])
    }

    private static func mapRedeemError(_ error: Error) -> Error {
        let ns = error as NSError
        guard ns.domain == FunctionsErrorDomain else { return error }
        let details = ns.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
        switch details?["reason"] as? String {
        case "not_found":        return InviteError.inviteNotFound
        case "already_consumed": return InviteError.alreadyConsumed
        case "own_invite":       return InviteError.cannotRedeemOwnInvite
        case "expired":          return InviteError.inviteExpired
        case "rate_limited":     return InviteError.tooManyAttempts
        default:
            if let code = FunctionsErrorCode(rawValue: ns.code), code == .unauthenticated {
                return InviteError.notSignedIn
            }
            return error
        }
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
            // Likewise for a token that arrived before the couple resolved.
            await flushPendingFCMToken()
            // Seed the onboarding name on first couple load (e.g. inviter's
            // cold launch / when the partner joins) if it's not already set.
            await seedDisplayNameFromLocalIfNeeded()
            // Ensure this device's token carries the coupleId claim (covers the
            // creator discovering the couple, and every paired launch).
            await refreshAuthClaims()
        }
        return resolved
    }

    // MARK: - Live couple doc

    /// Attaches a snapshot listener on the couple doc and republishes it into
    /// `couple` on every change. This is what makes cross-phone updates land
    /// live: the partner's new display name AND a changed couple photo both ride
    /// on this doc, so both refresh without a relaunch. Returns nil if unpaired;
    /// the caller (MainTabView) owns the registration and must `.remove()`.
    func observeCouple() -> ListenerRegistration? {
        guard let coupleId = couple?.id else { return nil }
        return db.collection("couples").document(coupleId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.log("couple listener error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot, snapshot.exists,
                      let updated = try? snapshot.data(as: Couple.self) else { return }
                self.couple = updated
            }
    }

    // MARK: - Auth claims (couple membership)

    /// Force-refreshes the signed-in user's ID token so the `coupleId` custom claim
    /// (stamped on both members by the redeemInvite CF / backfill) lands in the
    /// token THIS device uses. storage.rules enforces couples/{coupleId}/** via
    /// `request.auth.token.coupleId` — Storage rules can't read Firestore — so the
    /// token must carry it. Called after redeem (redeemer) and on couple resolve
    /// (currentCouple → covers the creator + every launch). Never throws; a failed
    /// refresh just retries at the next resolve, and nothing enforces the claim
    /// until the Storage rule flip, so a miss is harmless in the meantime.
    @discardableResult
    func refreshAuthClaims() async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: true)
            let claim = result.claims["coupleId"] as? String
            log("auth claims refreshed — coupleId=\(claim ?? "nil")")
            return claim
        } catch {
            log("auth claims refresh failed: \(error.localizedDescription)")
            return nil
        }
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

    // The @AppStorage key the onboarding / profile screens store the user's name
    // under. Read directly here because CoupleService isn't a View.
    private let localNameKey = "userName"

    /// Seeds the couple doc with the name the user typed during onboarding
    /// (@AppStorage "userName"), which never flows through setDisplayName on its
    /// own — so without this a newly-paired user's name never reaches the shared
    /// doc until they manually re-save in the Us tab. Only writes when a name
    /// exists locally AND this uid has no entry yet, so it never clobbers a name
    /// already set (decoded from Firestore or edited this session). Reuses
    /// setDisplayName for the race-proof / parked-retry write path. Called after
    /// the couple is created (redeem) or first loads (currentCouple).
    func seedDisplayNameFromLocalIfNeeded() async {
        guard let uid = Auth.auth().currentUser?.uid, couple?.id != nil else { return }
        // Don't clobber an entry that's already set.
        let existing = couple?.displayNames?[uid]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard existing?.isEmpty != false else { return }
        let local = (UserDefaults.standard.string(forKey: localNameKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !local.isEmpty else { return }
        log("seeding display name from local userName '\(local)'")
        await setDisplayName(local)
    }

    // MARK: - Push token (FCM)
    //
    // Each member's FCM registration token is written to couples/{id}.fcmTokens[uid]
    // so the Stage 5 match-nudge Cloud Function can address the PARTNER's device.
    // The client never READS tokens (only the function does), so they're not on the
    // Couple model — just written via a dot-path update, which the existing couples
    // update rule already permits (it only freezes `members`).
    //
    // Same parking shape as setDisplayName: an FCM token can arrive before sign-in
    // OR before pairing, so we stash it and flush once a couple is available.
    private var pendingFCMToken: String?

    // The invite this user has open (creator side), so a token that arrives
    // AFTER invite creation (permission granted at the pairing moment) can be
    // attached to it — that's what powers the "your partner connected 💕" push.
    private var activeInviteToken: String?

    /// Writes the signed-in user's FCM token to the shared couple doc. Stashes it
    /// first so it survives the common races (token before sign-in / before
    /// pairing); flushPendingFCMToken() retries it at the next couple load. A
    /// rotated token simply overwrites this uid's entry. Silent on failure — the
    /// token stays parked and a later call (rotation or couple-load) re-attempts.
    func persistFCMToken(_ token: String) async {
        pendingFCMToken = token
        guard let uid = Auth.auth().currentUser?.uid else {
            log("persistFCMToken — not signed in yet, parked")
            return
        }
        // Resolve the couple if in-memory state hasn't caught up (same race guard
        // as setDisplayName), then we genuinely need a couple to write to.
        if couple?.id == nil { _ = try? await currentCouple() }
        guard let coupleId = couple?.id else {
            log("persistFCMToken — no couple yet, parked")
            // Unpaired but inviting: attach the token to the open invite so the
            // redeem CF can notify this creator at connection. Best-effort — the
            // rules allow the creator to update ONLY this field; token stays
            // parked either way and flushes to the couple doc after pairing.
            if let inviteToken = activeInviteToken {
                try? await db.collection("invites").document(inviteToken)
                    .updateData(["creatorFcmToken": token])
                log("persistFCMToken — attached to open invite for pairing push")
            }
            return
        }
        do {
            try await db.collection("couples").document(coupleId)
                .updateData(["fcmTokens.\(uid)": token])
            pendingFCMToken = nil
            log("persistFCMToken — wrote token for \(uid) to couple \(coupleId)")
        } catch {
            log("persistFCMToken — write FAILED (\(error.localizedDescription)); kept parked")
        }
    }

    /// Writes any token parked before a couple existed. Called after the couple is
    /// created (redeem) or first loads (currentCouple). No-op if nothing's parked.
    func flushPendingFCMToken() async {
        guard let token = pendingFCMToken else { return }
        log("flushing parked FCM token")
        await persistFCMToken(token)
    }

    // MARK: - Manual partner nudge ("come swipe with me")
    //
    // The Home dashboard's Nudge button calls nudgePartner(), which invokes the
    // `nudgePartner` CALLABLE Cloud Function (authenticated; resolves the couple
    // server-side and rate-limits per couple). The cooldown is mirrored here only
    // to drive button state — the function is the authority that enforces it.

    // Functions handle for the EU region the functions are deployed in. Computed
    // (cheap, cached) so constructing CoupleService still touches no Firebase.
    private var functions: Functions { Functions.functions(region: "europe-west1") }

    /// Per-couple manual-nudge cooldown, mirroring the server's NUDGE_COOLDOWN_MS.
    static let manualNudgeCooldown: TimeInterval = 2 * 60 * 60   // 2 hours

    /// When the manual nudge becomes available again, or nil if it never fired /
    /// unpaired. Rides observeCouple, so BOTH phones reflect the shared cooldown.
    var manualNudgeAvailableAt: Date? {
        guard let ts = couple?.lastManualNudgeAt else { return nil }
        return ts.dateValue().addingTimeInterval(Self.manualNudgeCooldown)
    }

    /// Whether the manual nudge can be sent right now (no active cooldown). Used
    /// for button state only; the server re-checks and is authoritative.
    var canSendManualNudge: Bool {
        guard let until = manualNudgeAvailableAt else { return true }
        return Date() >= until
    }

    /// Outcome of a manual nudge, for the caller's UI feedback.
    enum NudgeOutcome: Equatable {
        case sent
        case partnerUnreachable            // partner has no token / notifications off
        case cooldown(retryAfterSec: Int)
        case notPaired
        case failed
    }

    /// Sends the manual "come swipe with me" nudge via the `nudgePartner` callable.
    /// The function authenticates the caller, resolves the couple, rate-limits per
    /// couple, and pushes the partner a warm invite. Returns a NudgeOutcome for UI
    /// feedback; never throws.
    func nudgePartner() async -> NudgeOutcome {
        guard Auth.auth().currentUser != nil else { return .notPaired }
        do {
            let result = try await functions.httpsCallable("nudgePartner").call()
            let data = result.data as? [String: Any]
            // Absent `delivered` (shouldn't happen) is treated as sent.
            let delivered = (data?["delivered"] as? Bool) ?? true
            log("nudgePartner — delivered=\(delivered)")
            return delivered ? .sent : .partnerUnreachable
        } catch {
            let ns = error as NSError
            if ns.domain == FunctionsErrorDomain,
               let code = FunctionsErrorCode(rawValue: ns.code) {
                switch code {
                case .resourceExhausted:
                    let details = ns.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
                    let retry = (details?["retryAfterSec"] as? Int)
                        ?? Int(Self.manualNudgeCooldown)
                    log("nudgePartner — cooldown, retry in \(retry)s")
                    return .cooldown(retryAfterSec: retry)
                case .failedPrecondition, .unauthenticated:
                    return .notPaired
                default:
                    log("nudgePartner — failed (\(code.rawValue)): \(ns.localizedDescription)")
                    return .failed
                }
            }
            log("nudgePartner — failed: \(ns.localizedDescription)")
            return .failed
        }
    }

    // MARK: - Account deletion (App Store 5.1.1(v))
    //
    // In-app account deletion runs entirely through the `deleteAccount` callable
    // Cloud Function (Admin SDK): the client can't delete the couple doc / its
    // subcollections (all `allow delete: if false`) or the Auth user (that needs a
    // fresh Sign-in-with-Apple reauth). The function orphans the couple when a
    // partner survives (they keep the shared Vault) or tears it fully down when
    // nobody's left, then deletes the Auth user. See functions/index.js.

    /// Deletes the signed-in user's account via the `deleteAccount` callable. On
    /// success the Auth user is gone server-side; the caller must then wipe local
    /// state and sign out (the local session is now invalid). Clears the in-memory
    /// couple + any parked local writes so nothing lingers. Throws on failure so the
    /// UI can keep the user signed in and show a retry.
    func deleteAccount() async throws {
        guard Auth.auth().currentUser != nil else { throw InviteError.notSignedIn }
        _ = try await functions.httpsCallable("deleteAccount").call()
        // Server side is done — drop everything we hold about this couple so no
        // observer keeps rendering a doc that no longer belongs to us.
        couple = nil
        pendingFCMToken = nil
        UserDefaults.standard.removeObject(forKey: pendingDisplayNameKey)
    }

    /// Drops all in-memory state this service holds about the current couple, so a
    /// DIFFERENT account signing in on the same device never sees the previous
    /// user's couple (name, photo, days-together). Used by the account-switch reset
    /// at the app root — the persisted UserDefaults side is wiped there.
    func clearLocalState() {
        couple = nil
        pendingFCMToken = nil
        UserDefaults.standard.removeObject(forKey: pendingDisplayNameKey)
    }

    // MARK: - Couple photo
    //
    // PRE-LAUNCH HARDENING: this is a client-authed write to Cloud Storage,
    // gated only by storage.rules' interim "signed-in" check — Storage rules
    // can't read Firestore to verify couple membership, so a signed-in user who
    // knows a coupleId could write here. Move to a Cloud Function + custom
    // `coupleId` claim + App Check before launch, same as the deferred invite-
    // redemption and venue-cache hardening. See storage.rules and redeem().

    /// Uploads `jpegData` as the shared couple photo (one image both partners
    /// see) and records its Storage PATH + an updated timestamp on the couple
    /// doc. Overwrites any existing photo. We store the path, never a download
    /// URL, so nothing sensitive is baked into Firestore.
    ///
    /// Throws if not signed in / not paired / the upload or doc write fails, so
    /// the caller can offer a retry. Unlike setDisplayName we don't park the
    /// (large) bytes on failure — the user simply re-picks.
    func setCouplePhoto(jpegData: Data) async throws {
        guard Auth.auth().currentUser != nil else { throw InviteError.notSignedIn }

        // Resolve the couple if in-memory state hasn't caught up (same race
        // guard as setDisplayName) — then we genuinely need a couple to write to.
        if couple?.id == nil {
            _ = try? await currentCouple()
        }
        guard let coupleId = couple?.id else { throw InviteError.notPaired }

        let path = "couples/\(coupleId)/profile.jpg"
        try await storage.uploadJPEG(jpegData, to: path)
        try await db.collection("couples").document(coupleId).updateData([
            "couplePhotoPath": path,
            "couplePhotoUpdatedAt": FieldValue.serverTimestamp()
        ])

        // Mirror locally so this device updates instantly; the server timestamp
        // reconciles on the next read. A local Date() is a fine cache-bust token.
        couple?.couplePhotoPath = path
        couple?.couplePhotoUpdatedAt = Timestamp(date: Date())
        log("setCouplePhoto — wrote \(path) for couple \(coupleId)")
    }

    // MARK: - Couple story (anniversary / birthdays / relationship status)
    //
    // Same write shape as setDisplayName / setCouplePhoto: a dot-path update so
    // only the touched field changes, mirrored locally so the UI refreshes
    // instantly and observeCouple syncs the partner. These are only ever set
    // post-pairing (the Couple Story editor), so unlike setDisplayName there's no
    // pre-pairing parking — the couple is loaded by the time we get here.

    /// Sets one of the couple's relationship milestones (dating / engaged /
    /// wedding). Dot-path write so the others are untouched; hidden milestones are
    /// never deleted by a status change.
    func setMilestone(_ milestone: CoupleMilestone, date: Date) async {
        // Unpaired: park a dating date locally instead of losing the write, so
        // Days Together works solo (see the solo section above). Engagement and
        // wedding dates are inherently couple-scoped — nothing to park.
        guard couple?.id != nil else {
            guard milestone == .dating else { return }
            soloDatingDate = date
            UserDefaults.standard.set(date, forKey: Self.soloDatingKey)
            return
        }
        await updateCoupleField(["milestones.\(milestone.rawValue)": Timestamp(date: date)]) {
            var map = $0.milestones ?? [:]
            map[milestone.rawValue] = Timestamp(date: date)
            $0.milestones = map
        }
    }

    /// Sets the signed-in user's own birthday (their entry in the per-uid map).
    func setBirthday(_ date: Date) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        await updateCoupleField(["birthdays.\(uid)": Timestamp(date: date)]) {
            var map = $0.birthdays ?? [:]
            map[uid] = Timestamp(date: date)
            $0.birthdays = map
        }
    }

    /// Publishes this device's timezone to the couple doc, so scheduled pushes land
    /// at a sane LOCAL hour instead of Vilnius 09:00. Cheap and idempotent: it only
    /// writes when the value actually changed, so it is safe to call on every
    /// couple attach. Last device to open the app wins — for a couple in two
    /// timezones there is no single right answer, and either partner's local
    /// morning beats a third country's small hours.
    func syncTimeZone() async {
        let current = TimeZone.current.identifier
        guard couple?.id != nil, couple?.timeZone != current else { return }
        await updateCoupleField(["timeZone": current]) { $0.timeZone = current }
    }

    /// Sets the couple's shared relationship stage.
    func setRelationshipStatus(_ status: String) async {
        // Unpaired: park it, or the Couple Story editor silently forgets the pick
        // and the dating-date field never reappears (visibleMilestones keys off it).
        guard couple?.id != nil else {
            soloRelationshipStatus = status
            UserDefaults.standard.set(status, forKey: Self.soloStatusKey)
            return
        }
        await updateCoupleField(["relationshipStatus": status]) {
            $0.relationshipStatus = status
        }
    }

    /// Claims / updates the couple's SHARED Near You location bucket so both
    /// partners fetch ONE event deck (and their swipe cardIds line up for
    /// matching). NearYouView decides WHEN to call this — bootstrap when unset,
    /// re-anchor on travel — this just writes it. Same dot-path-update + local
    /// mirror shape as the setters above; rides observeCouple to the partner live,
    /// and the existing couples update rule already permits it (members frozen).
    func setEventLocation(bucket: String, manual: Bool = false, label: String? = nil) async {
        // Unpaired: park it locally. updateCoupleField below no-ops without a
        // couple, so without this branch a solo city search silently did nothing.
        guard couple != nil else {
            soloEventBucket = bucket
            soloEventManual = manual
            soloEventLabel = label
            UserDefaults.standard.set(bucket, forKey: Self.soloBucketKey)
            UserDefaults.standard.set(manual, forKey: Self.soloManualKey)
            if let label {
                UserDefaults.standard.set(label, forKey: Self.soloLabelKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.soloLabelKey)
            }
            return
        }

        // In auto mode the label is cleared (FieldValue.delete removes the field).
        let labelValue: Any = label ?? FieldValue.delete()
        await updateCoupleField([
            "eventLocationBucket": bucket,
            "eventLocationUpdatedAt": FieldValue.serverTimestamp(),
            "eventLocationManual": manual,
            "eventLocationLabel": labelValue
        ]) {
            $0.eventLocationBucket = bucket
            $0.eventLocationUpdatedAt = Timestamp(date: Date())
            $0.eventLocationManual = manual
            $0.eventLocationLabel = label
        }
    }

    // MARK: - Premium (couple-shared subscription)
    //
    // "One subscription unlocks BOTH partners." SubscriptionService owns the
    // RevenueCat truth (this user's entitlement); this is the mirror onto the
    // SHARED couple doc so the partner reads premium without buying their own.
    // Only the PAYER writes here — see the client-mirror / revocation note in
    // SubscriptionService for the v1 trade-off and the webhook end-state.

    /// Reflects this user's RevenueCat entitlement onto the shared couple doc.
    /// `active == true`  → the payer stamps isPremium + subscriptionOwner = self.
    /// `active == false` → ONLY the recorded payer takes the flag back down (the
    ///                     partner isn't the owner, so they never clear it).
    /// Resolves the couple first; a no-op when unpaired (subscribed-before-pairing
    /// is reconciled later, at the couple-load seam in MainTabView).
    func syncPremiumEntitlement(_ active: Bool) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if couple?.id == nil { _ = try? await currentCouple() }
        guard couple?.id != nil else {
            log("syncPremiumEntitlement — no couple yet, deferring (active=\(active))")
            return
        }

        if active {
            // Already reflecting me as the premium owner → nothing to write.
            guard !(couple?.isPremium == true && couple?.subscriptionOwner == uid) else { return }
            await updateCoupleField([
                "isPremium": true,
                "subscriptionOwner": uid,
                "subscriptionUpdatedAt": FieldValue.serverTimestamp()
            ]) {
                $0.isPremium = true
                $0.subscriptionOwner = uid
                $0.subscriptionUpdatedAt = Timestamp(date: Date())
            }
        } else {
            // Client-mirror v1: only the recorded payer revokes, and only when
            // their own entitlement lapsed. A payer who never reopens leaves it
            // set (generous-fail) — the known gap the webhook closes later.
            guard couple?.isPremium == true, couple?.subscriptionOwner == uid else { return }
            await updateCoupleField([
                "isPremium": false,
                "subscriptionUpdatedAt": FieldValue.serverTimestamp()
            ]) {
                $0.isPremium = false
                $0.subscriptionUpdatedAt = Timestamp(date: Date())
            }
        }
    }

    /// Shared write path for couple-story fields: resolve the couple if the
    /// in-memory state hasn't caught up, apply a dot-path update, then mirror
    /// locally. Silent on failure — the value stays editable in the Us tab, so
    /// there's no enter-once-or-lose (the name-entry bug lesson).
    private func updateCoupleField(_ data: [String: Any],
                                   mirror: (inout Couple) -> Void) async {
        if couple?.id == nil { _ = try? await currentCouple() }
        guard let coupleId = couple?.id else {
            log("updateCoupleField — no couple yet, skipping \(data.keys)")
            return
        }
        do {
            try await db.collection("couples").document(coupleId).updateData(data)
            if var c = couple { mirror(&c); couple = c }
            log("updateCoupleField — wrote \(data.keys) for couple \(coupleId)")
        } catch {
            log("updateCoupleField — FAILED \(data.keys): \(error.localizedDescription)")
        }
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

    /// Universal Link host (2026-07-19). https://ilovu.io/invite/<token> is the
    /// ONE link we share: iOS routes it into the app when installed (AASA on
    /// Netlify + applinks entitlement), and Safari shows the invite landing
    /// page (site/invite.html — code + App Store button) when not.
    nonisolated static let universalLinkHost = "ilovu.io"

    /// The live App Store page (single source — reused anywhere we link the
    /// store: invite shares, future review/marketing surfaces).
    nonisolated static let appStoreURL = URL(string: "https://apps.apple.com/app/id6781237573")!

    /// Builds the custom-scheme deep link for an invite token (installed-only).
    /// `nonisolated`: pure string work, safe to call off the main actor.
    nonisolated static func inviteURL(token: String) -> URL {
        URL(string: "\(inviteURLScheme)://\(inviteURLHost)/\(token)")!
    }

    /// Builds the Universal Link for an invite token — the one link that works
    /// for everyone (opens the app if installed, the landing page if not).
    nonisolated static func inviteWebURL(token: String) -> URL {
        URL(string: "https://\(universalLinkHost)/\(inviteURLHost)/\(token)")!
    }

    /// The same invite link, carrying the PLAN so the landing page can show the
    /// date someone actually made rather than a generic "You're invited".
    ///
    /// The plan travels in the URL because `invite.html` is a static page and
    /// cannot read Firestore without auth. Params are deliberately optional and
    /// ignored by the app's own link parser (`inviteToken(from:)` reads only the
    /// path), so an older build and the plain link both keep working.
    ///
    /// Kept short — `p` plan, `w` when (ISO day), `n` sender's first name, `e`
    /// emoji — because the whole thing appears inside a text message. Nothing
    /// sensitive should ever be added here: links get forwarded, logged and
    /// previewed by messaging apps.
    nonisolated static func missionInviteWebURL(token: String,
                                                planTitle: String,
                                                emoji: String?,
                                                when: Date?,
                                                senderName: String?) -> URL {
        var components = URLComponents(url: inviteWebURL(token: token),
                                       resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "p", value: planTitle)]
        if let emoji, !emoji.isEmpty { items.append(URLQueryItem(name: "e", value: emoji)) }
        if let when {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "yyyy-MM-dd"
            items.append(URLQueryItem(name: "w", value: fmt.string(from: when)))
        }
        if let senderName, !senderName.isEmpty {
            items.append(URLQueryItem(name: "n", value: senderName))
        }
        components.queryItems = items
        return components.url ?? inviteWebURL(token: token)
    }

    /// Invite text sent FROM a planned mission. The generic invite is "install my
    /// app" — abstract, no urgency, and plausibly why so few onboarded users ever
    /// send one. This one is "I want to take you to this on Saturday": the
    /// recipient reads a real plan in their messages before tapping anything.
    nonisolated static func missionInviteShareMessage(token: String,
                                                      planTitle: String,
                                                      emoji: String?,
                                                      when: Date?,
                                                      senderName: String?) -> String {
        let url = missionInviteWebURL(token: token,
                                      planTitle: planTitle,
                                      emoji: emoji,
                                      when: when,
                                      senderName: senderName)
        let opener: String
        if let when {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE"          // "Saturday"
            opener = "I've planned \(planTitle) for \(fmt.string(from: when)) 💕"
        } else {
            opener = "I've planned \(planTitle) for us 💕"
        }
        return """
        \(opener)
        Open your invitation: \(url.absoluteString)
        Your code: \(formatInviteCode(token))
        """
    }

    /// Extracts the token from an incoming invite link, or nil if `url` isn't
    /// one. Accepts BOTH forms — the custom scheme (ilovu://invite/<token>)
    /// and the Universal Link (https://ilovu.io/invite/<token>, www too);
    /// SwiftUI delivers both through the same onOpenURL.
    /// `nonisolated`: pure parsing, no actor state touched.
    nonisolated static func inviteToken(from url: URL) -> String? {
        if url.scheme == inviteURLScheme, url.host == inviteURLHost {
            // ilovu://invite/<token> -> pathComponents ["/", "<token>"]
            guard let token = url.pathComponents.first(where: { $0 != "/" }), !token.isEmpty else {
                return nil
            }
            return token
        }
        if url.scheme == "https",
           let host = url.host,
           host == universalLinkHost || host == "www.\(universalLinkHost)" {
            // https://ilovu.io/invite/<token> -> pathComponents ["/", "invite", "<token>"]
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 2, parts[0] == inviteURLHost, !parts[1].isEmpty else {
                return nil
            }
            return parts[1]
        }
        return nil
    }

    // MARK: - Token

    // Crockford base32: digits + letters minus i, l, o, u (avoids look-alike
    // ambiguity). 32 divides 256, so `byte % 32` is perfectly unbiased.
    nonisolated static let tokenAlphabet = Array("0123456789abcdefghjkmnpqrstvwxyz")

    /// Invite-code length in characters. 5 chars over a 32-symbol alphabet =
    /// 25 bits (32^5 ≈ 33.5M) — deliberately short enough to read aloud or type
    /// in seconds at the pairing moment. That's NOT unguessable by brute force
    /// on its own, so the security premise moved server-side (2026-07-18):
    ///   * firestore.rules: invite reads are creator-only (redemption is
    ///     CF-only, so nobody else needs to read them),
    ///   * `redeemInvite` rate-limits failed attempts per account (the only
    ///     guessing surface left) and expires invites after 7 days.
    /// At ~10 guesses/hour against 33.5M combos, a brute force needs centuries.
    /// Easy to bump if the threat model ever changes. Old 10-char pending
    /// invites still redeem fine (the CF never checks length).
    private static let tokenLength = 5

    /// `tokenLength` cryptographically-random Crockford-base32 chars. Unguessable
    /// by design — that's the entire security premise of the invite rules, since
    /// any signed-in user may read an invite by its id.
    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: tokenLength)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            // SecRandomCopyBytes essentially never fails; a fallback keeps us safe.
            return String((0..<tokenLength).map { _ in tokenAlphabet.randomElement()! })
        }
        // 256 % 32 == 0, so the modulo is bias-free over the 32-char alphabet.
        return String(bytes.map { tokenAlphabet[Int($0) % tokenAlphabet.count] })
    }

    // MARK: - Invite-code display / input

    /// Formats a token for legible DISPLAY: uppercased and grouped in 5s with a
    /// hyphen (e.g. "K2MN8-P4QRS"). Display only — the stored token / clipboard
    /// copy stays the raw lowercase form, and input is normalized back via
    /// normalizeInviteCode, so the hyphen/case never reach Firestore.
    nonisolated static func formatInviteCode(_ token: String) -> String {
        let clean = token.uppercased()
        let chars = Array(clean)
        return stride(from: 0, to: chars.count, by: 5)
            .map { String(chars[$0..<min($0 + 5, chars.count)]) }
            .joined(separator: "-")
    }

    /// The warm, on-brand text shared from the invite share sheet. ONE smart
    /// link (the Universal Link): opens the app directly when installed, and
    /// the invite landing page (code + App Store button) when not. The
    /// human-readable code rides along as PLAIN TEXT so even a mangled link
    /// leaves the partner with something typeable ("Have a code?" field).
    nonisolated static func inviteShareMessage(token: String) -> String {
        """
        Join me on iLovu 💕
        Tap to connect: \(inviteWebURL(token: token).absoluteString)
        Your code: \(formatInviteCode(token))
        """
    }

    /// Normalizes a hand-typed or pasted code back to a raw token: lowercases,
    /// strips formatting (spaces/hyphens), and maps Crockford look-alikes
    /// (o→0, i/l→1) so a slightly mistyped code still resolves. The token
    /// alphabet excludes i/l/o/u, so these maps only ever fix typos.
    nonisolated static func normalizeInviteCode(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // A pasted LINK is at least as likely as a typed code — the invite page's
        // primary action is now "Copy my code", and plenty of people copy the whole
        // URL instead. Without this the character filter below turns
        // "https://ilovu.io/invite/mtv7w" into "httpsilovuioinvitemtv7w", which can
        // never resolve: a guaranteed dead end, silently. Pull the token out first.
        if let url = URL(string: text), let token = inviteToken(from: url) {
            text = token
        } else if let range = text.range(of: "invite/", options: .caseInsensitive) {
            // Not a URL the parser accepts (a bare "ilovu.io/invite/x", a trailing
            // "?p=..." the pasteboard mangled), but the shape is unmistakable.
            text = String(text[range.upperBound...])
            text = text.components(separatedBy: CharacterSet(charactersIn: "?#/")).first ?? text
        }

        let mapped = text.lowercased()
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "i", with: "1")
            .replacingOccurrences(of: "l", with: "1")
        return String(mapped.filter { $0.isLetter || $0.isNumber })
    }
}
