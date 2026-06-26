/**
 * iLovu Cloud Functions.
 *
 * helloWorld   — pipeline smoke test (HTTP).
 * onMatchCreated — Stage 5 partner nudge: pushes the partner who didn't complete
 *                  a match. (sendTestPush, the Stage 4 manual push rehearsal, was
 *                  removed once onMatchCreated was verified on two phones.)
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
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10, region: "europe-west1" });

/**
 * Smoke test: confirms the write -> deploy -> live pipeline works end to end.
 * An HTTP function so you can hit its URL in a browser. Inherits maxInstances +
 * region from setGlobalOptions above. Safe to delete once the pipeline's proven.
 */
exports.helloWorld = onRequest((req, res) => {
  res.send("Hello from iLovu! 💕");
});

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
