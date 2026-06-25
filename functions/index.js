/**
 * iLovu Cloud Functions.
 *
 * Stage 1: scaffolding + a smoke-test function. No nudge / push logic yet.
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

setGlobalOptions({ maxInstances: 10, region: "europe-west1" });

/**
 * Smoke test: confirms the write -> deploy -> live pipeline works end to end.
 * An HTTP function so you can hit its URL in a browser. Inherits maxInstances +
 * region from setGlobalOptions above. Safe to delete once the pipeline's proven.
 */
exports.helloWorld = onRequest((req, res) => {
  res.send("Hello from iLovu! 💕");
});
