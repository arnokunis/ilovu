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
const { onRequest } = require("firebase-functions/v2/https");
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
