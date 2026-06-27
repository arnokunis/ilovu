/**
 * iLovu Cloud Functions.
 *
 * helloWorld   — pipeline smoke test (HTTP).
 * onMatchCreated — Stage 5 partner nudge: pushes the partner who didn't complete
 *                  a match. (sendTestPush, the Stage 4 manual push rehearsal, was
 *                  removed once onMatchCreated was verified on two phones.)
 * nudgePartner — manual "come swipe with me" nudge (callable, rate-limited).
 * sendDateReminders — SCHEDULED daily special-date reminders (anniversary,
 *                  engagement, wedding, birthdays). runDateRemindersNow is its
 *                  TEST-ONLY manual trigger (remove before launch).
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
const { onSchedule } = require("firebase-functions/v2/scheduler");
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

// TEST-ONLY manual trigger — REMOVE BEFORE LAUNCH.
// Lets you fire the reminder scan on demand (no waiting for 09:00 / a real date)
// and see a JSON summary of exactly what it did. `?force=1` bypasses the per-day
// dedup AND writes no stamp, so you can re-run freely and reset cleanly.
// Guarded by a shared secret so the public URL can't be drive-by triggered.
const TEST_TRIGGER_SECRET = "ilovu-reminders-test-7AU9U5Q6LT";
exports.runDateRemindersNow = onRequest(async (req, res) => {
  if (req.query.key !== TEST_TRIGGER_SECRET) {
    res.status(403).send("forbidden");
    return;
  }
  try {
    const summary = await runDateReminders({ force: req.query.force === "1" });
    res.json(summary);
  } catch (err) {
    console.error("runDateRemindersNow failed:", err);
    res.status(500).json({ error: err.message });
  }
});
