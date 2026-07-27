/**
 * iLovu Cloud Functions.
 *
 * onMatchCreated — Stage 5 partner nudge: pushes the partner who didn't complete
 *                  a match. (sendTestPush, the Stage 4 manual push rehearsal, was
 *                  removed once onMatchCreated was verified on two phones.)
 * onDailyAnswer — pushes the partner when one member answers the Daily Question:
 *                  a "your partner answered — answer to see theirs" nudge, or the
 *                  "they answered too, tap to see" reveal when the pair completes.
 * nudgePartner — manual "come swipe with me" nudge (callable, rate-limited).
 * sendDateReminders — SCHEDULED daily special-date reminders (anniversary,
 *                  engagement, wedding, birthdays).
 *
 * GLOBAL GUARDRAILS — applied to EVERY function in this codebase:
 *   • maxInstances: a hard ceiling on concurrent instances, so a bug or a
 *     traffic spike can never fan out to hundreds of billed instances ("cache
 *     everything for margins" applies to the backend too). 10 is plenty at this
 *     stage — raise it deliberately, never by accident.
 *   • region: europe-west1, to sit next to our EU Firestore (lower latency, data
 *     stays in-region). Easily changed here if we ever want elsewhere.
 */

const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

// Shared secret guarding the RevenueCat webhook. Set the SAME random string as the
// webhook's Authorization header in the RevenueCat dashboard and here via:
//   firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
const REVENUECAT_WEBHOOK_SECRET = defineSecret("REVENUECAT_WEBHOOK_SECRET");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10, region: "europe-west1" });

// ---------------------------------------------------------------------------
// cacheWrite — the ONLY writer for the shared, world-readable cache collections.
//
// venues / venueQueries / placeDeckQueries / eventQueries are readable by anyone
// but writable by NO client (firestore.rules: `allow write: if false`). The app
// still fetches from Google Places on-device (bundle-restricted key) and hands
// the resolved doc here to persist — so a signed-in client can no longer write
// arbitrary docs straight into these collections (the cache-poisoning / cost-abuse
// hole flagged in the PRE-LAUNCH HARDENING notes). The Admin SDK bypasses rules.
//
// THIN GATE (deliberate, pre-launch): this trusts the client-fetched payload and
// only controls WHERE it may land + how big it may be. Moving the Places fetch
// itself server-side (data becomes authoritative AND the API key leaves the
// device) is the post-launch fast-follow. `events/{eventId}` is intentionally NOT
// gated here yet — that path is dormant and its doc carries a concrete `expireAt`
// Timestamp that doesn't fit this JSON-only relay; gate it when events reactivates.
//
// @ServerTimestamp fields (fetchedAt / resolvedAt) encode to a FieldValue sentinel
// that can't cross the callable JSON boundary, so the client strips them and names
// them in serverTimestampFields; we re-stamp them with server time here —
// producing exactly the same doc the old client setData(from:) wrote.
const CACHE_WRITE_COLLECTIONS = new Set([
  "venues",
  "venueQueries",
  "placeDeckQueries",
  "eventQueries",
]);

// Bound the relayed payload so a bad/hostile client can't write huge docs (cost).
// A real venue doc (reviews + hours + photo names) is a few KB; 200 KB is generous.
const MAX_CACHE_DOC_BYTES = 200 * 1024;

exports.cacheWrite = onCall((request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to write the cache.");
  }

  const { collection, docId, data, serverTimestampFields } = request.data || {};

  if (!CACHE_WRITE_COLLECTIONS.has(collection)) {
    throw new HttpsError("invalid-argument", `Collection not cache-writable: ${collection}`);
  }
  if (
    typeof docId !== "string" ||
    docId.length === 0 ||
    docId.length > 1500 ||
    docId.includes("/")
  ) {
    throw new HttpsError("invalid-argument", "Invalid docId.");
  }
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "data must be an object.");
  }
  if (Buffer.byteLength(JSON.stringify(data), "utf8") > MAX_CACHE_DOC_BYTES) {
    throw new HttpsError("invalid-argument", "Cache doc too large.");
  }
  const tsFields = Array.isArray(serverTimestampFields) ? serverTimestampFields : [];
  if (!tsFields.every((f) => typeof f === "string")) {
    throw new HttpsError("invalid-argument", "serverTimestampFields must be strings.");
  }

  // Full overwrite (matches the client's old setData(from:)), server-stamping the
  // freshness fields the client stripped.
  const doc = { ...data };
  for (const field of tsFields) {
    doc[field] = admin.firestore.FieldValue.serverTimestamp();
  }

  return admin
    .firestore()
    .collection(collection)
    .doc(docId)
    .set(doc)
    .then(() => ({ ok: true }));
});

// ---------------------------------------------------------------------------
// redeemInvite — atomic invite redemption (pre-launch hardening #1).
//
// The client used to consume the invite and create the couple doc in TWO
// separate writes, which could half-complete or be raced. This callable does
// both in ONE Firestore transaction (Admin SDK), so redemption is all-or-nothing
// and tamper-proof. firestore.rules now forbids client couple-creation and client
// invite-consumption outright (allow create / update: if false) — this function
// is the ONLY path. Only NEW pairings run this; already-paired couples are
// untouched. Returns { coupleId, members } so the client can publish the couple
// locally and flip to "paired" mid-session, exactly as the old client path did.
exports.redeemInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You need to be signed in.");
  }
  const uid = request.auth.uid;
  const token = request.data && request.data.token;
  if (typeof token !== "string" || token.length === 0) {
    throw new HttpsError("invalid-argument", "Missing invite token.");
  }

  const db = admin.firestore();
  const inviteRef = db.collection("invites").doc(token);

  // Rate limit + expiry (2026-07-18): invite codes shrank to 5 chars
  // (32^5 ≈ 33.5M combos) so they're typeable at the pairing moment. That's
  // only safe because guessing is throttled HERE — this callable is the sole
  // redemption path, and firestore.rules makes invite reads creator-only, so
  // there is no other surface to enumerate tokens against. At 10 failed
  // tries/hour, brute-forcing 33.5M combos takes centuries per account.
  const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
  const RATE_LIMIT_MAX_FAILED = 10;
  const INVITE_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

  // redeemAttempts/{uid} — server-only bookkeeping (no rules grant client
  // access): { count, windowStart }. Best-effort, not transactional — a racing
  // pair of guesses may slip one extra attempt through, which doesn't matter
  // at this scale.
  const attemptsRef = db.collection("redeemAttempts").doc(uid);
  const attemptsSnap = await attemptsRef.get();
  const attempts = attemptsSnap.exists ? attemptsSnap.data() : null;
  const windowActive = !!(attempts && attempts.windowStart &&
    Date.now() - attempts.windowStart.toMillis() < RATE_LIMIT_WINDOW_MS);
  if (windowActive && attempts.count >= RATE_LIMIT_MAX_FAILED) {
    throw new HttpsError("resource-exhausted",
        "Too many attempts — please try again in an hour.",
        { reason: "rate_limited" });
  }

  // The transaction re-reads the invite and commits both writes atomically, so a
  // race between two redeemers resolves to exactly one winner (the loser's
  // pending-check fails inside the transaction and retries → already-used).
  let result;
  try {
    result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(inviteRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "This invite link isn't valid.", { reason: "not_found" });
      }
      const invite = snap.data();
      if (invite.status !== "pending") {
        throw new HttpsError("failed-precondition", "This invite has already been used.", { reason: "already_consumed" });
      }
      if (invite.creatorId === uid) {
        throw new HttpsError("failed-precondition", "You can't redeem your own invite.", { reason: "own_invite" });
      }
      // Expiry: createdAt is always server-stamped on create; a missing one
      // (shouldn't happen) is treated as still-valid rather than bricking.
      if (invite.createdAt &&
          Date.now() - invite.createdAt.toMillis() > INVITE_EXPIRY_MS) {
        throw new HttpsError("failed-precondition",
            "This invite has expired — ask for a fresh code.",
            { reason: "expired" });
      }

      const members = [invite.creatorId, uid];
      const coupleRef = db.collection("couples").doc();
      tx.update(inviteRef, { status: "consumed", consumedBy: uid });
      tx.set(coupleRef, {
        members,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      // creatorFcmToken rides along (internal only — stripped before returning
      // to the client) so the creator gets the "you're connected" push below.
      return { coupleId: coupleRef.id, members, creatorFcmToken: invite.creatorFcmToken || null };
    });
  } catch (e) {
    // Count only guess-shaped failures (wrong/used/expired code) against the
    // rate limit — own_invite and infrastructure errors aren't guessing.
    const guessReasons = ["not_found", "already_consumed", "expired"];
    if (e instanceof HttpsError && e.details && guessReasons.includes(e.details.reason)) {
      await attemptsRef.set({
        count: windowActive ? admin.firestore.FieldValue.increment(1) : 1,
        windowStart: windowActive ?
          attempts.windowStart :
          admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    throw e;
  }

  // Bind couple membership to BOTH members' auth tokens via a custom `coupleId`
  // claim. storage.rules enforces couples/{coupleId}/** with
  // request.auth.token.coupleId (Storage rules can't read Firestore), so the
  // token must carry it; the client force-refreshes to pick it up. Done AFTER the
  // transaction commits (Auth writes aren't part of a Firestore tx). Best-effort:
  // the couple doc is already the source of truth, so a failed claim set never
  // fails redemption — backfillCoupleClaims / the next launch can re-apply it.
  try {
    await Promise.all(
      result.members.map((memberUid) =>
        admin.auth().setCustomUserClaims(memberUid, { coupleId: result.coupleId })
      )
    );
  } catch (e) {
    console.error("redeemInvite: setCustomUserClaims failed (couple still created)", e);
  }

  // Pairing push (2026-07-19): the creator granted notifications at the
  // pairing moment and their token rode in on the invite doc — tell them the
  // wait is over. Best-effort: a dead/absent token never fails redemption, and
  // there's no stale-token cleanup to do (the invite is consumed regardless).
  // Brand rule: warm + partner-framed, never time/guilt-based.
  if (result.creatorFcmToken) {
    try {
      await admin.messaging().send({
        token: result.creatorFcmToken,
        notification: {
          title: "You're connected 💕",
          body: "Your person just joined you on iLovu — go swipe together!",
        },
      });
      console.log(`redeemInvite ${result.coupleId}: pairing push sent to creator`);
    } catch (err) {
      console.log("redeemInvite: pairing push failed (non-fatal):", err.code || err.message);
    }
  }

  // Strip the internal token before answering the redeemer's client.
  return { coupleId: result.coupleId, members: result.members };
});

// ---------------------------------------------------------------------------
// deleteAccount — in-app account deletion (App Store Guideline 5.1.1(v)).
//
// CALLABLE (onCall): the Firebase SDK attaches the caller's auth, so
// request.auth.uid is a VERIFIED signed-in user — we only ever delete the CALLER,
// never a client-supplied id. The client can't do any of this itself: couples +
// every subcollection are `allow delete: if false`, and Auth.user.delete() needs
// a fresh Sign-in-with-Apple reauth. The Admin SDK bypasses rules and reauth.
//
// THE COUPLE CASE (locked design — "1-lite"): a couple is a SHARED doc both
// partners point to, with shared memories/photos beneath it. When ONE member
// deletes and the other is still around, we do NOT delete the shared data — the
// surviving partner keeps the Vault (matches the locked breakup policy: "both keep
// their own copy of shared memories", and the Privacy Policy's "your data deleted
// within 30 days"). We ORPHAN the couple instead: flag the leaver in
// `deletedMembers` and scrub their personal identifiers (name / birthday / push
// token). `members` is left intact so the surviving partner's read rule + partner
// resolution keep working structurally; the app branches on `deletedMembers` to
// show a gentle "your partner left — your memories are safe" state.
//
// Only when NO living partner remains (a solo member, or the partner already
// deleted earlier) is there nobody left to keep the shared data — then we tear the
// whole couple down (subcollections + Storage + doc).
//
// IAM: admin.auth().deleteUser touches Auth (not just Firestore), so the compute
// SA needs roles/firebaseauth.admin — the SAME role already granted for
// redeemInvite's setCustomUserClaims. datastore.user covers the Firestore work.
//
// COST: inherits maxInstances:10 + region from setGlobalOptions. A rare, deliberate
// user action — never fans out.
exports.deleteAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to delete your account.");
  }
  const uid = request.auth.uid;
  const db = admin.firestore();

  // Resolve the caller's couple by membership — never trust a client-passed id.
  const snap = await db.collection("couples")
    .where("members", "array-contains", uid).limit(1).get();

  if (!snap.empty) {
    const coupleRef = snap.docs[0].ref;
    const couple = snap.docs[0].data() || {};
    const members = couple.members || [];
    const alreadyDeleted = couple.deletedMembers || [];
    const partnerUid = members.find((m) => m !== uid);
    const partnerLiving = Boolean(partnerUid) && !alreadyDeleted.includes(partnerUid);

    if (partnerLiving) {
      // ORPHAN: partner keeps the shared couple doc + memories. Flag the leaver and
      // scrub their personal identifiers (dot-path deletes touch only their keys).
      await coupleRef.update({
        deletedMembers: admin.firestore.FieldValue.arrayUnion(uid),
        [`displayNames.${uid}`]: admin.firestore.FieldValue.delete(),
        [`birthdays.${uid}`]: admin.firestore.FieldValue.delete(),
        [`fcmTokens.${uid}`]: admin.firestore.FieldValue.delete(),
      });
    } else {
      // No living partner remains — nobody is left to keep the shared data, so tear
      // the whole couple down. recursiveDelete removes the doc + every subcollection
      // (swipes / matches / missions / memories / dailyAnswers); Storage is purged
      // separately. Best-effort Storage so a bucket hiccup can't block the delete.
      await purgeCoupleStorage(coupleRef.id);
      await db.recursiveDelete(coupleRef);
    }
  }

  // Remove any invites this user minted (pending or spent) — leftover data of theirs.
  const invites = await db.collection("invites").where("creatorId", "==", uid).get();
  await Promise.all(invites.docs.map((d) => d.ref.delete()));

  // Finally, delete the Auth user itself. Do this LAST: the steps above run under
  // the caller's still-valid token, and deleting the user invalidates it.
  await admin.auth().deleteUser(uid);

  console.log(`deleteAccount: deleted ${uid}`);
  return { ok: true };
});

// Best-effort delete of a couple's Storage prefix (couple photo + proof photos).
// Wrapped so a Storage error never blocks the Firestore/Auth teardown; the doc is
// already the source of truth, and orphaned bytes are harmless (and cheap).
async function purgeCoupleStorage(coupleId) {
  try {
    await admin.storage().bucket().deleteFiles({ prefix: `couples/${coupleId}/` });
  } catch (e) {
    console.error(`purgeCoupleStorage ${coupleId} failed (non-fatal):`, e.message);
  }
}

// ---------------------------------------------------------------------------
// STAGE 5 — match nudge (the first real nudge).
//
// Fires when a match doc is created under couples/{coupleId}/matches/{cardId}.
// A match means BOTH partners liked the same card; the completer (the second
// liker) is already looking at the in-app celebration, so we push the OTHER
// partner — the one who liked it earlier and isn't here to see it land — a warm,
// partner-framed nudge to come open it together.
//
// COST: inherits maxInstances:10 + region from setGlobalOptions. A match is a
// rare event (two deliberate right-swipes on the same card), so this trigger
// fires seldom and never fans out.
//
// IDEMPOTENT: the match doc id is the cardId, so a both-liked-at-once race
// collapses to ONE create — onDocumentCreated fires exactly once per match, so
// the partner is nudged once, never on replays or the merge that may follow.
//
// BRAND (hard rule): copy is warm + partner-framed, NEVER time- or guilt-based.
// No "you haven't…", no "it's been N days". Just "you two liked the same thing".
// ---------------------------------------------------------------------------
// revenueCatWebhook — authoritative subscription grant/revoke.
//
// RevenueCat POSTs a subscription lifecycle event here (server-to-server), so the
// couple's shared `isPremium` flag stays correct even when the payer never reopens
// the app — closing the client-mirror revocation gap (a lapsed sub used to linger
// as premium until the payer next launched). Resolves the couple by `app_user_id`,
// which equals the Firebase uid (see syncRevenueCatIdentity in iLovuApp).
//
// GRANT on purchase/renewal/uncancellation; REVOKE on expiration/pause. CANCELLATION
// (auto-renew off but still entitled until period end) and BILLING_ISSUE (grace) are
// deliberately NO-OPs — the sub is still active. Revoke only fires for the recorded
// payer, so a stray event for the non-paying partner can't drop an active couple.
//
// SECURITY: guarded by a shared secret in the Authorization header (set the SAME
// value in the RC dashboard webhook + as REVENUECAT_WEBHOOK_SECRET). Always 200s on
// a handled event (even a no-op) so RevenueCat doesn't retry; only bad auth 401s.
//
// NOTE (deliberate, incremental): the client mirror (CoupleService.syncPremiumEntitlement)
// and the OPEN isPremium rule are intentionally LEFT IN PLACE for now, so a webhook
// misconfig can never regress purchase-unlock. Both writers agree on grant; the
// webhook's unique job is the revoke. Locking `isPremium` to CF-only in firestore.rules
// (which also closes the "a member forges isPremium=true" hole) is the follow-up once
// this is verified live.
const RC_GRANT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
]);
const RC_REVOKE_TYPES = new Set([
  "EXPIRATION",
  "SUBSCRIPTION_PAUSED",
]);

exports.revenueCatWebhook = onRequest(
  { secrets: [REVENUECAT_WEBHOOK_SECRET] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const expected = REVENUECAT_WEBHOOK_SECRET.value();
    if (!expected || req.get("authorization") !== expected) {
      console.warn("revenueCatWebhook: bad or missing authorization");
      res.status(401).send("Unauthorized");
      return;
    }

    const event = (req.body && req.body.event) || {};
    const type = event.type;
    const grant = RC_GRANT_TYPES.has(type);
    const revoke = RC_REVOKE_TYPES.has(type);
    if (!grant && !revoke) {
      // TEST / CANCELLATION / BILLING_ISSUE / TRANSFER / etc. — nothing to write.
      console.log(`revenueCatWebhook: ignoring type ${type}`);
      res.status(200).send("ignored");
      return;
    }

    // The payer's uid. After logIn, app_user_id IS the Firebase uid; also scan
    // aliases / original id in case RevenueCat sends an alternate id on the event.
    const candidates = [event.app_user_id, event.original_app_user_id]
      .concat(Array.isArray(event.aliases) ? event.aliases : [])
      .filter((v) => typeof v === "string" && v.length > 0);
    if (candidates.length === 0) {
      console.warn("revenueCatWebhook: event has no app_user_id");
      res.status(200).send("no user");
      return;
    }

    // Find the couple this user belongs to (members array-contains the uid).
    const db = admin.firestore();
    let coupleSnap = null;
    let uid = null;
    for (const candidate of candidates) {
      const q = await db.collection("couples")
        .where("members", "array-contains", candidate)
        .limit(1).get();
      if (!q.empty) { coupleSnap = q.docs[0]; uid = candidate; break; }
    }
    if (!coupleSnap) {
      // Bought before pairing (no couple yet). The client mirror will set the flag
      // when they pair; nothing authoritative to do here. 200 so RC doesn't retry.
      console.log(`revenueCatWebhook: no couple for ${candidates.join(",")} (type ${type})`);
      res.status(200).send("no couple");
      return;
    }

    const couple = coupleSnap.data() || {};
    const coupleRef = coupleSnap.ref;

    if (grant) {
      await coupleRef.update({
        isPremium: true,
        subscriptionOwner: uid,
        subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`revenueCatWebhook: GRANT ${coupleSnap.id} (owner ${uid}, type ${type})`);
      res.status(200).send("granted");
      return;
    }

    // Revoke — only the recorded payer can drop the couple's premium, so an
    // expiration event for the non-paying partner never revokes an active sub.
    const owner = couple.subscriptionOwner;
    if (owner && owner !== uid) {
      console.log(`revenueCatWebhook: ${coupleSnap.id} expire for non-owner ${uid}, ignoring`);
      res.status(200).send("not owner");
      return;
    }
    await coupleRef.update({
      isPremium: false,
      subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`revenueCatWebhook: REVOKE ${coupleSnap.id} (was owner ${uid}, type ${type})`);
    res.status(200).send("revoked");
  },
);

exports.onMatchCreated = onDocumentCreated(
  "couples/{coupleId}/matches/{cardId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return; // defensive: no snapshot on the event

    const match = snap.data() || {};
    const coupleId = event.params.coupleId;

    // Who completed the match? Without this we can't tell the two partners apart,
    // so we skip rather than risk nudging the wrong person. (Old match docs
    // predating Stage 5 have no createdBy — they're silently ignored, which is
    // correct: they're not new and were already seen in-app.)
    const createdBy = match.createdBy;
    if (!createdBy) {
      console.log(`onMatchCreated ${coupleId}/${snap.id}: no createdBy, skipping`);
      return;
    }

    // Load the couple to resolve members, tokens, and names.
    const coupleRef = admin.firestore().doc(`couples/${coupleId}`);
    const coupleSnap = await coupleRef.get();
    if (!coupleSnap.exists) return;
    const couple = coupleSnap.data() || {};

    const members = couple.members || [];
    // The partner to notify = the member who ISN'T the completer.
    const recipient = members.find((m) => m !== createdBy);
    if (!recipient) {
      console.log(`onMatchCreated ${coupleId}: no partner distinct from completer`);
      return;
    }

    // Only send if the partner has a registered token. In our flow a token is
    // only ever minted AFTER the user grants notification permission (Piece 2),
    // so "has a token" is also our proxy for "has granted" — no token means we
    // skip gracefully (permission not granted, or no device registered yet).
    const tokens = couple.fcmTokens || {};
    const token = tokens[recipient];
    if (!token) {
      console.log(`onMatchCreated ${coupleId}: partner ${recipient} has no token, skipping`);
      return;
    }

    // Warm, partner-framed copy from displayNames. Falls back to a generic-but-
    // still-warm line if the completer never set a name.
    const names = couple.displayNames || {};
    const actorName = (names[createdBy] || "").trim();
    const title = actorName
      ? `You and ${actorName} both liked something 💛`
      : "You both liked something 💛";
    const body = "Open it together →";

    try {
      const messageId = await admin.messaging().send({
        token,
        notification: { title, body },
      });
      console.log(`onMatchCreated ${coupleId}: nudged ${recipient} (msg ${messageId})`);
    } catch (err) {
      console.error("onMatchCreated send failed:", err.code, err.message);
      // Stale token (app deleted / permission revoked / token rotated): drop it so
      // we don't keep trying to push a dead address. The next launch re-registers
      // a fresh one (Piece 1) if the partner still has the app + permission.
      if (err.code === "messaging/registration-token-not-registered") {
        await coupleRef.update({
          [`fcmTokens.${recipient}`]: admin.firestore.FieldValue.delete(),
        });
        console.log(`onMatchCreated ${coupleId}: removed stale token for ${recipient}`);
      }
    }
  },
);

// ---------------------------------------------------------------------------
// DAILY-QUESTION NUDGE — pushes the partner when one member answers today's
// shared Daily Question (couples/{id}/dailyAnswers/{dateKey}).
//
// The card is "answer to unlock": you see your partner's answer only once you've
// answered too. This function turns that mechanic into a warm partner signal:
//   • FIRST answer of the day  -> nudge the OTHER partner ("Inesa answered today's
//     question — answer to see theirs"). This is what pulls them in to unlock the
//     reveal, the whole point of the feature.
//   • SECOND answer (pair now complete) -> tell the partner who answered FIRST that
//     the reveal just landed ("Inesa answered too — tap to see"). The second
//     answerer is already in the app watching it unlock, so they're never pushed.
// Either way we notify the member who did NOT just answer.
//
// BRAND — reconciling with "anti-pressure, no notifications" (DailyQuestionCard's
// header + CLAUDE.md): that rule bans GUILT/nagging pings ("you haven't answered
// today", streaks, shame). This is the opposite kind — warm + PARTNER-framed, the
// same social-invite tone as onMatchCreated ("Inesa is swiping — join her"). No
// time/guilt copy, ever. (A deliberate softening of the original "no notifications"
// stance; noted in CLAUDE.md's Daily Questions decision.)
//
// TRIGGER SHAPE — onDocumentWritten (not ...Created): we diff before/after to find
// the answer key that is NEW on this write. That makes us fire ONLY on a genuinely
// new answer — an EDIT to an existing answer (key already present) and a pure
// updatedAt/serverTimestamp resolution both leave newAnswerers empty, so neither
// re-nudges the partner. A rare simultaneous both-answered write (>1 new key) is
// skipped too: nobody is waiting, both see the reveal in-app.
//
// COST: inherits maxInstances:10 + region. One answer/day/couple → fires seldom;
// reuses the onMatchCreated send path, fcmTokens, and stale-token cleanup.
exports.onDailyAnswer = onDocumentWritten(
  "couples/{coupleId}/dailyAnswers/{dateKey}",
  async (event) => {
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after) return; // deletion — nothing to notify on
    const before = event.data.before.exists ? event.data.before.data() : null;

    const beforeAnswers = (before && before.answers) || {};
    const afterAnswers = after.answers || {};

    // The answer key(s) present now but absent before = who just answered on THIS
    // write. Exactly one is the normal case (each member writes only their own key).
    // Empty = an edit or an updatedAt-only write → nothing to notify. More than one
    // = a rare simultaneous double → skip (nobody's waiting on a reveal).
    const newAnswerers = Object.keys(afterAnswers).filter((u) => !(u in beforeAnswers));
    if (newAnswerers.length !== 1) return;
    const answerer = newAnswerers[0];

    const coupleId = event.params.coupleId;
    const coupleRef = admin.firestore().doc(`couples/${coupleId}`);
    const coupleSnap = await coupleRef.get();
    if (!coupleSnap.exists) return;
    const couple = coupleSnap.data() || {};

    // Orphaned couple (a member deleted) — no living partner to notify, and the
    // "waiting for your partner" reveal never completes. Skip, like sendDateReminders.
    if ((couple.deletedMembers || []).length > 0) return;

    const members = couple.members || [];
    const recipient = members.find((m) => m !== answerer);
    if (!recipient) return; // half-paired / self — nothing to send

    // Token == granted permission (minted only after the match-time prompt), same
    // proxy as onMatchCreated. No token → skip gracefully.
    const token = (couple.fcmTokens || {})[recipient];
    if (!token) {
      console.log(`onDailyAnswer ${coupleId}: partner ${recipient} has no token, skipping`);
      return;
    }

    // bothAnswered === this write COMPLETED the pair → the recipient (who answered
    // first) can now see the reveal; otherwise they still need to answer to unlock it.
    const bothAnswered = Object.keys(afterAnswers).length >= 2;
    const names = couple.displayNames || {};
    const who = (names[answerer] || "").trim();
    const title = bothAnswered
      ? (who ? `${who} answered too 💬` : "Your partner answered too 💬")
      : (who ? `${who} answered today's question 💬` : "Your partner answered today's question 💬");
    const body = bothAnswered ? "Tap to see what they said 💕" : "Answer to see theirs 💕";

    try {
      const messageId = await admin.messaging().send({ token, notification: { title, body } });
      console.log(`onDailyAnswer ${coupleId}: notified ${recipient} (both=${bothAnswered}, msg ${messageId})`);
    } catch (err) {
      console.error("onDailyAnswer send failed:", err.code, err.message);
      // Stale token (app deleted / permission revoked / rotated) — drop it, exactly
      // as onMatchCreated does; the next launch re-registers a fresh one.
      if (err.code === "messaging/registration-token-not-registered") {
        await coupleRef.update({
          [`fcmTokens.${recipient}`]: admin.firestore.FieldValue.delete(),
        });
        console.log(`onDailyAnswer ${coupleId}: removed stale token for ${recipient}`);
      }
    }
  },
);

// ---------------------------------------------------------------------------
// Manual "come swipe with me" nudge — one partner taps a button to invite the
// other into the app right now.
//
// CALLABLE (onCall), NOT HTTP: the Firebase SDK attaches the caller's Firebase
// auth, so request.auth.uid is a VERIFIED signed-in user. We resolve the couple
// by membership (never trusting a client-supplied id), so only a real member can
// trigger a nudge, and only ever to their own partner. Reuses the same send path,
// fcmTokens, and roles/datastore.user permission as onMatchCreated.
//
// COST: inherits maxInstances:10 + region from setGlobalOptions.
//
// ANTI-SPAM: one nudge per COUPLE per NUDGE_COOLDOWN_MS, authoritative on the
// server. The stamp lives on the couple doc (shared across both partners and
// surviving reinstall — a client-only/per-device guard wouldn't). 2h is a
// deliberate anti-pressure default: it kills rapid-fire spam but still allows a
// genuine re-invite later in the day. Tune via the one constant below.
//
// BRAND (hard rule): warm INVITE tone, never nagging / "you haven't…".
//
// PRE-LAUNCH HARDENING: the cooldown stamp (lastManualNudgeAt) is writable by a
// client under the current couples update rule (members can write non-`members`
// fields). For our two-trusted-partner model that only lets someone loosen their
// OWN couple's cooldown, so it's a UX guard, not a security boundary — consistent
// with the matches/missions trust posture. Lock it (rules denying client writes
// to this field, or a function-only doc) alongside the other hardening later.
const NUDGE_COOLDOWN_MS = 2 * 60 * 60 * 1000; // 2 hours, per couple

exports.nudgePartner = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to nudge your partner.");
  }

  const db = admin.firestore();
  // Resolve the caller's couple by membership — never trust a client-passed id.
  const snap = await db.collection("couples")
    .where("members", "array-contains", uid).limit(1).get();
  if (snap.empty) {
    throw new HttpsError("failed-precondition", "You're not paired yet.");
  }
  const coupleRef = snap.docs[0].ref;
  const couple = snap.docs[0].data();

  const partnerUid = (couple.members || []).find((m) => m !== uid);
  if (!partnerUid) {
    throw new HttpsError("failed-precondition", "No partner on this couple.");
  }

  // Rate limit (per couple). Reading the stamp at call time keeps it authoritative
  // even though two phones share it.
  const lastMs = (couple.lastManualNudgeAt && couple.lastManualNudgeAt.toMillis)
    ? couple.lastManualNudgeAt.toMillis() : 0;
  const elapsed = Date.now() - lastMs;
  if (lastMs && elapsed < NUDGE_COOLDOWN_MS) {
    const retryAfterSec = Math.ceil((NUDGE_COOLDOWN_MS - elapsed) / 1000);
    throw new HttpsError(
      "resource-exhausted",
      "You nudged recently — give it a little while.",
      { retryAfterSec },
    );
  }

  const token = (couple.fcmTokens || {})[partnerUid];
  if (!token) {
    // Partner hasn't enabled notifications / no device registered. Not an error —
    // report it so the client can show an honest, gentle message (and we don't
    // burn the cooldown on a nudge that couldn't be delivered).
    return { delivered: false, reason: "partner-no-token" };
  }

  const names = couple.displayNames || {};
  const callerName = (names[uid] || "").trim() || "Your partner";
  const title = `${callerName} wants to plan a date with you 💛`;
  const body = "Open iLovu to swipe together →";

  try {
    await admin.messaging().send({ token, notification: { title, body } });
  } catch (err) {
    console.error("nudgePartner send failed:", err.code, err.message);
    if (err.code === "messaging/registration-token-not-registered") {
      await coupleRef.update({
        [`fcmTokens.${partnerUid}`]: admin.firestore.FieldValue.delete(),
      });
      return { delivered: false, reason: "partner-no-token" };
    }
    throw new HttpsError("unavailable", "Couldn't reach your partner just now.");
  }

  // Stamp the cooldown ONLY after a successful send, so a failed/undelivered
  // nudge never locks the user out.
  await coupleRef.update({
    lastManualNudgeAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`nudgePartner: ${uid} nudged ${partnerUid}`);
  return { delivered: true };
});

// ---------------------------------------------------------------------------
// SPECIAL-DATE REMINDERS — a SCHEDULED (cron) function, our first of this kind.
//
// Once a day it scans every couple and pushes a warm reminder when one of their
// recurring annual dates is TODAY or LEAD-days away:
//   • anniversary  (milestones.dating, legacy anniversaryDate fallback) — always
//   • engagement   (milestones.engaged)  — only if status Engaged/Married
//   • wedding      (milestones.wedding)  — only if status Married
//   • birthdays    (birthdays[uid])      — always, BOTH partners' birthdays
//
// Each date therefore fires TWICE a year: a heads-up LEAD days before, and one
// on the day. Matching is on MONTH+DAY only (year ignored — it recurs annually).
//
// RECIPIENTS:
//   • Shared dates (anniversary/engagement/wedding) -> BOTH partners.
//   • A birthday -> the OTHER partner only ("It's [Name]'s birthday…"), never
//     the birthday person. >>> FLAGGED for confirmation: flip to both easily by
//     changing the recipients line in buildReminders().
//
// TIMEZONE (flagged): per-couple local time is hard — eventLocationBucket is a
// coarse lat/lng string with no tz attached, and we have no tz library. So we
// run ONCE daily at REMINDER_HOUR in REMINDER_TZ (Europe/Vilnius, our launch
// market) and treat every couple's dates in that same zone. Nobody is pinged at
// 3am locally for a Vilnius-area user base; revisit (real per-couple tz) when we
// expand markets.
//
// DOUBLE-SEND GUARD: each reminder we send stamps couples/{id}.remindersSent[key]
// with today's date string. A second run the same day (retry / manual test) sees
// the stamp and skips — so a date never double-fires in a day. (Server-only
// field; not in the Swift model, harmlessly ignored on decode.)
//
// COST: inherits maxInstances:10 + region. One Firestore read of the couples
// collection per day + a handful of pushes; trivial. Full-collection scan is
// fine at our scale — revisit (sharding / date index) only at large N.
const REMINDER_LEAD_DAYS = 3;          // heads-up: this many days before the date
const REMINDER_TZ = "Europe/Vilnius";  // single-zone approximation (see note above)
const REMINDER_HOUR = 9;               // 09:00 local — a sane, non-3am hour

// MM-DD for a date, evaluated in REMINDER_TZ (so a date picked at local midnight
// reads as the day the user meant, not UTC-shifted).
function monthDayInTz(date, tz) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, month: "2-digit", day: "2-digit",
  }).formatToParts(date);
  const m = parts.find((p) => p.type === "month").value;
  const d = parts.find((p) => p.type === "day").value;
  return `${m}-${d}`;
}

// YYYY-MM-DD for a date in REMINDER_TZ — the per-day dedup key for remindersSent.
function dateKeyInTz(date, tz) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(date);
  const y = parts.find((p) => p.type === "year").value;
  const m = parts.find((p) => p.type === "month").value;
  const d = parts.find((p) => p.type === "day").value;
  return `${y}-${m}-${d}`;
}

// Decide which reminders this couple has TODAY. Returns a list of
// { key, recipients:[uid…], title, body }. `key` is stable per occurrence so the
// dedup stamp works (heads-up and day-of are distinct, and live on different
// calendar days anyway).
function buildReminders(couple, todayMD, headsMD) {
  const out = [];
  const members = couple.members || [];
  const names = couple.displayNames || {};
  const status = couple.relationshipStatus; // "Dating" | "Engaged" | "Married"
  const lead = REMINDER_LEAD_DAYS;

  // Match a stored Timestamp's month+day against today / heads-up day.
  // Returns "day" | "heads" | null.
  const occasion = (ts) => {
    if (!ts || !ts.toDate) return null;
    const md = monthDayInTz(ts.toDate(), REMINDER_TZ);
    if (md === todayMD) return "day";
    if (md === headsMD) return "heads";
    return null;
  };

  const milestones = couple.milestones || {};

  // --- Anniversary (dating). Always relevant; legacy anniversaryDate fallback. ---
  const datingTs = milestones.dating || couple.anniversaryDate;
  const datingWhen = occasion(datingTs);
  if (datingWhen === "day") {
    out.push({ key: "anniv:day", recipients: members,
      title: "Happy anniversary 💛", body: "Make today count together" });
  } else if (datingWhen === "heads") {
    out.push({ key: "anniv:heads", recipients: members,
      title: `Your anniversary is in ${lead} days 💛`, body: "Plan something together" });
  }

  // --- Engagement. Only once Engaged or Married. ---
  if (status === "Engaged" || status === "Married") {
    const w = occasion(milestones.engaged);
    if (w === "day") {
      out.push({ key: "engaged:day", recipients: members,
        title: "Happy engagement anniversary 💛", body: "Celebrate it today" });
    } else if (w === "heads") {
      out.push({ key: "engaged:heads", recipients: members,
        title: `Your engagement anniversary is in ${lead} days 💛`, body: "Plan something together" });
    }
  }

  // --- Wedding. Only once Married. ---
  if (status === "Married") {
    const w = occasion(milestones.wedding);
    if (w === "day") {
      out.push({ key: "wedding:day", recipients: members,
        title: "Happy wedding anniversary 💛", body: "Make today count together" });
    } else if (w === "heads") {
      out.push({ key: "wedding:heads", recipients: members,
        title: `Your wedding anniversary is in ${lead} days 💛`, body: "Plan something together" });
    }
  }

  // --- Birthdays. Each partner's birthday -> the OTHER partner only. ---
  const birthdays = couple.birthdays || {};
  for (const bdayUid of Object.keys(birthdays)) {
    const w = occasion(birthdays[bdayUid]);
    if (!w) continue;
    const partnerUid = members.find((m) => m !== bdayUid);
    if (!partnerUid) continue; // missing/half-paired couple — skip gracefully
    const who = (names[bdayUid] || "").trim() || "Your partner";
    // >>> To ping BOTH partners instead, change `[partnerUid]` to `members`.
    if (w === "day") {
      out.push({ key: `bday:${bdayUid}:day`, recipients: [partnerUid],
        title: `It's ${who}'s birthday today 💛`, body: "Make it special" });
    } else {
      out.push({ key: `bday:${bdayUid}:heads`, recipients: [partnerUid],
        title: `${who}'s birthday is in ${lead} days 💛`, body: "Plan a surprise" });
    }
  }

  return out;
}

// Send one reminder to its recipients. Skips recipients with no token, cleans up
// stale tokens (same policy as onMatchCreated). Returns true if ≥1 push landed.
async function sendReminder(coupleRef, couple, reminder) {
  const tokens = couple.fcmTokens || {};
  let anySent = false;
  for (const uid of reminder.recipients) {
    const token = tokens[uid];
    if (!token) continue; // no permission / no device — skip gracefully
    try {
      await admin.messaging().send({
        token,
        notification: { title: reminder.title, body: reminder.body },
      });
      anySent = true;
    } catch (err) {
      console.error(`sendReminder ${reminder.key} -> ${uid} failed:`, err.code, err.message);
      if (err.code === "messaging/registration-token-not-registered") {
        await coupleRef.update({
          [`fcmTokens.${uid}`]: admin.firestore.FieldValue.delete(),
        });
      }
    }
  }
  return anySent;
}

// Core run, shared by the scheduled job and the test trigger. `force` bypasses
// (and does NOT write) the per-day dedup stamp, so a test can re-run repeatedly
// and leaves no remindersSent residue to clean up afterwards.
async function runDateReminders({ now = new Date(), force = false } = {}) {
  const todayMD = monthDayInTz(now, REMINDER_TZ);
  const heads = new Date(now.getTime() + REMINDER_LEAD_DAYS * 24 * 60 * 60 * 1000);
  const headsMD = monthDayInTz(heads, REMINDER_TZ);
  const todayKey = dateKeyInTz(now, REMINDER_TZ);

  const db = admin.firestore();
  const couplesSnap = await db.collection("couples").get();

  const summary = { date: todayKey, force, couples: couplesSnap.size, sent: [], skipped: [] };

  for (const doc of couplesSnap.docs) {
    const couple = doc.data() || {};
    // Skip orphaned couples (a member deleted their account) — never ping the
    // surviving partner about the anniversary/birthday of a relationship that
    // ended. The leaver's identifiers are already scrubbed, but the shared dates
    // (milestones) linger on the doc, so guard here.
    if ((couple.deletedMembers || []).length > 0) continue;
    const reminders = buildReminders(couple, todayMD, headsMD);
    if (reminders.length === 0) continue;

    const sentMap = couple.remindersSent || {};
    for (const reminder of reminders) {
      // Dedup: already handled today (unless we're force-testing).
      if (!force && sentMap[reminder.key] === todayKey) {
        summary.skipped.push({ couple: doc.id, key: reminder.key, why: "already-sent-today" });
        continue;
      }
      const delivered = await sendReminder(doc.ref, couple, reminder);
      if (delivered && !force) {
        await doc.ref.update({ [`remindersSent.${reminder.key}`]: todayKey });
      }
      (delivered ? summary.sent : summary.skipped).push({
        couple: doc.id, key: reminder.key, ...(delivered ? {} : { why: "no-recipient-token" }),
      });
    }
  }

  console.log(`runDateReminders ${todayKey}: ${summary.sent.length} sent, ${summary.skipped.length} skipped, ${summary.couples} couples`);
  return summary;
}

// The scheduled entry point. Runs daily at REMINDER_HOUR REMINDER_TZ. onSchedule
// provisions a Cloud Scheduler job + Pub/Sub topic on deploy (needs the Cloud
// Scheduler + Pub/Sub APIs enabled — `firebase deploy` enables them on Blaze).
exports.sendDateReminders = onSchedule(
  { schedule: `0 ${REMINDER_HOUR} * * *`, timeZone: REMINDER_TZ },
  async () => { await runDateReminders(); },
);
