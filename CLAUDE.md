# CLAUDE.md — iLovu

Project context for Claude Code sessions. Read this first.

---

## What iLovu is

A couples date-planning iOS app (SwiftUI). Core loop:

> Both partners swipe date-idea cards + real local events → a mutual match becomes a **Mission** → the Mission is completed by capturing a **Proof Photo** → the photo lands in a shared **Memory Vault**.

**Positioning is firmly anti-pressure**: "one real date a month, science-backed." Tagline: *"Show it. Don't just say it. 💕"* The completion/proof loop (match → Mission → Proof Photo → Memory Vault) is the competitive wedge — no competitor does "proof you went." Do **not** drift toward "relationship repair/reignite" framing; that's off-brand.

**Brand voice pattern (locked):** "Clear keyword line + soul kicker." e.g. "Date ideas for couples who actually go." / "Show it. Don't just say it. 💕"

---

## Tech stack

- **SwiftUI**, iOS-only (iPhone, `TARGETED_DEVICE_FAMILY = 1`)
- **Firebase**: Auth (Sign in with Apple) + Firestore (Standard, EU region)
- **Google Places API (New)** — venue data, read-through cached to Firestore; now also powers **Near You** (curated restaurants/wine bars/cafés). Bundle-restricted keys need the `X-Ios-Bundle-Identifier` header — see the Near You decision below.
- **RevenueCat** — **INTEGRATED**: `Purchases.configure` at launch with the real `appl_` SDK key (`Secrets.revenueCatAPIKey`); `SubscriptionService` owns the live `premium` entitlement + `default` offering + real purchase/restore. See the RevenueCat decision below. (The dashboard offering + App Store Connect products are external config, NOT verifiable from code.)
- **Ticketmaster** — events code built but **DORMANT** (no date-appropriate Vilnius events; kept for event-rich markets like London/US). **Eventbrite: DEAD** — it removed its public Event Search API; do not pursue.
- **Cloud Functions** (Node 22, `firebase-functions` v6, `europe-west1`) — `helloWorld` + `onMatchCreated` (match nudge) live; see Push notifications below.
- Firebase project: `ilovu-b5d87` · Bundle ID: `com.ilovu.app.iLovu` · Team: KUNIS, MB (Apple Org ID 7AU9U5Q6LT)

---

## Architecture decisions (locked)

### Auth
Sign in with Apple, upfront, for both partners. Durable accounts from the start (matters for a memories app). No anonymous-bootstrap.

### Data model — shared `couples` document is the keystone
A couple is its own Firestore document that both users point to. The design target is one shared doc holding the subscription entitlement (one sub unlocks both), matches, missions, memories, and the breakup policy. Below, `// PLANNED` marks the locked design intent that the code hasn't implemented yet — verify against the Swift models before relying on a field.

```
users/{uid}                             // PLANNED — no users doc is written yet (onboarding unbuilt)
  displayName, vibe, relationshipStatus, coupleId, createdAt

couples/{coupleId}                       // Couple.swift — created at invite redemption (no "pending" state today)
  members: [uidA, uidB]                  // exactly two uids; frozen on update by firestore.rules
  createdAt
  displayNames: { uid: name }            // each member writes their own (Couple.swift / setDisplayName)
  couplePhotoPath, couplePhotoUpdatedAt  // DONE — shared couple photo: Storage PATH (not a URL) + cache-bust ts
  isPremium, subscriptionOwner, subscriptionUpdatedAt  // DONE — shared premium flag, written ONLY by the payer (their RevenueCat entitlement mirrors here so the partner unlocks without paying); subscriptionOwner = payer uid (sub follows on breakup). Couple.swift
  // PLANNED: status (active / broken-up)

couples/{coupleId}/swipes/{cardId}       // a right-swipe; this is where likes live (CardSwipe model)
  cardId, deck, likedBy: [uid…], updatedAt   // each user arrayUnions ONLY their own uid into likedBy
couples/{coupleId}/matches/{cardId}      // deterministic doc ID = idempotent, no race dupes
  cardId, deck, createdAt

couples/{coupleId}/missions/{cardId}     // DONE — synced via MissionService; doc id = cardId; MissionStore mirrors up + listens
  cardId, deck (dates|places), status, scheduledDate, budget, checklist, updatedAt
  // deck-aware: a date-card mission resolves in SampleCards (.dates); a Near You
  // VENUE mission (cardId == placeId) rebuilds from VenueCache (.places)
couples/{coupleId}/memories/{memoryId}   // DONE — synced via MemoryService; MemoryStore mirrors up + listens
  dateCompleted, cardTitle, cardEmoji, storagePath, rating, note, createdBy, schemaVersion, createdAt
  // photo BYTES live in Cloud Storage (couples/{coupleId}/memories/{memoryId}.jpg), NEVER in the doc
couples/{coupleId}/dailyAnswers/{dayKey} // DailyQuestionService — Daily Question sync (CODE NOT COMMITTED; rules deployed)
  answers: { uid: text }, questionId, updatedAt  // each writes ONLY own uid key; answer-to-unlock reveal, passive listener

invites/{token}                          // Invite.swift — doc ID IS the token (unguessable, single-use)
  creatorId, status ("pending"|"consumed"), consumedBy (null until redeemed), createdAt
  // no expiresAt yet; single-use is enforced via status + firestore.rules

venues/{placeId}                         // world-readable cache
venueQueries/{queryKey}                  // read-through cache, stale-while-revalidate (>7 days)
eventQueries/{queryKey}                  // Ticketmaster events cache (DORMANT — see Tech stack)
placeDeckQueries/{queryKey}              // Near You curated-Places deck cache; firestore.rules deployed (per-open re-bill fixed)
```

**Cloud Storage (EU bucket) — couple photos.** Image BYTES live here, not in Firestore; docs store the Storage PATH only (never a download URL / embedded secret — the Places-key lesson). `StorageService` uploads/downloads by path; `ImageCache` (FileManager) caches download-once so egress scales with content, not usage. Compression is centralized in `ImageDownscaler` (1024px / JPEG 0.7).
```
couples/{coupleId}/profile.jpg               // shared couple photo (overwritten on change)
couples/{coupleId}/memories/{memoryId}.jpg   // proof photos (Memory Vault)
```
`storage.rules` is couple-scoped but INTERIM: Storage rules can't read Firestore, so they enforce signed-in + image + size only, NOT membership. See the `// PRE-LAUNCH HARDENING` note below.

### Real matching — client-side intersection, no Cloud Functions
Lives in `MatchService`: `recordLike(coupleId:cardId:deck:)` + `observeMatches(coupleId:onMatch:)`. On a right-swipe each partner `arrayUnion`s their own uid into `couples/{coupleId}/swipes/{cardId}.likedBy`; a strongly-consistent read-after-write detects when both UIDs are present and creates the match doc. The match doc uses the card ID as its doc ID, so a both-liked-at-once race collapses to one idempotent doc. The partner who didn't complete the match is notified via an app-level `matches` snapshot listener (dedupe against a *persisted* set of celebrated cardIds, or every past match replays on launch). **Unpaired → falls back to `Bool.random()` solo celebration** (`SwipeView.swift:214`). Both phones must complete pairing before real matching works.

### Invite link — custom scheme now, Universal Links later
`ilovu://invite/<token>` via Info.plist + `onOpenURL`, parsed by `CoupleService.inviteToken(from:)` / built by `inviteURL(token:)`. The invite lifecycle is `CoupleService.createInvite()` → `redeem(token:)` → `currentCouple()`. **Firebase Dynamic Links is dead (shut down Aug 25 2025)** — do not use it. Custom scheme only resolves if the app is already installed; manual "Have a code?" field is the backup. Universal Links via `ilovu.io` (AASA on Netlify) + deferred deep-linking is the future upgrade.

### Cost architecture (critical — 95% margin target)
Naive per-user live Places fetching is catastrophic (~$16k/mo at 300 users). **Cache everything**: fetch each venue once to Firestore, serve both card and detail from cache. Scales with venues, not users. Set a Billing budget alert the moment paid billing is attached.

### Subscriptions — RevenueCat (INTEGRATED; real purchase flow live in code)
`SubscriptionService` is the single source of truth: `Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)` runs at launch (real `appl_` public SDK key, gitignored in `Secrets.swift`). It reads the **`premium`** entitlement off `customerInfoStream` (live: purchase/renewal/expiry), loads the **`default`** offering's `$rc_annual` / `$rc_monthly` packages (products `com.ilovu.app.annual` $49.99/yr, `com.ilovu.app.monthly` $6.99/mo), and runs **real** `Purchases.shared.purchase(package:)` / `restorePurchases()`. Dashboard ids are centralized in `RevenueCatConfig.swift`.
- **Paywall is real, not stubbed:** presented from `HomeView` (`showPaywall`), its buy/restore buttons call `subscriptionService.purchaseAnnual()/purchaseMonthly()/restore()`. The only stub is `PaywallView`'s `#Preview`. `PaywallGate` decides only WHEN the soft-wall appears; the purchase itself is separate.
- **Couple sharing ("one sub unlocks both"):** `premiumActive(couple:) = myEntitlementActive OR couple.isPremium`. On an entitlement flip, `onEntitlementChange` → `CoupleService.syncPremiumEntitlement` mirrors `isPremium` onto the shared couple doc (PAYER only), so the non-paying partner unlocks off the doc.
- **NOT verifiable from code (external):** whether the RevenueCat dashboard `default` offering + the two App Store Connect products are actually configured/purchasable. If missing, `loadOfferings()` leaves packages nil and a buy returns the friendly "Plans are still loading — try again," not a crash. **Confirm dashboard + ASC before a TestFlight purchase test.**
- **HARDENING (v1 gap):** entitlement **revocation is client-mirror only** — if the payer's sub lapses and they never reopen the app, the couple-doc `isPremium` lingers (premium too long; never wrongly drops). Clean end-state: a **RevenueCat webhook → Cloud Function** writing the couple doc authoritatively (grant AND revoke), which also closes the "a member could set `isPremium=true` without paying" hole. Tracked with the other `// PRE-LAUNCH HARDENING` items.

### Near You — curated Google Places, not events (pivoted, committed 778a857, works on device)
Near You ships as live **curated Google Places** (restaurants, wine bars, cafés by name) via `PlaceCuration.swift` + `NearYouConfig.source = .places` — pivoted away from events because Ticketmaster had no date-appropriate Vilnius events and **Eventbrite removed its public Event Search API** (dead end). The Ticketmaster events path is kept **dormant-but-intact** for event-rich markets (London/US) later.
- **Places 403 fix (locked):** iOS-bundle-restricted Google keys require the `X-Ios-Bundle-Identifier` header on raw `URLSession` Places calls (search), plus a custom `BundledRemoteImage` loader for photos (`AsyncImage` can't send headers). **Do NOT loosen the key restriction to fix a 403** — send the header.
- **Cache cost fixes:** deployed `placeDeckQueries` `firestore.rules` (stops per-open re-billing); fixed `@ServerTimestamp` returning `nil` right after a write (false-stale → re-billing) by reading with `.estimate` `ServerTimestampBehavior` across placeDeck + EventCache + venueQuery. Confirmed on device: **deck HIT (fresh), 0 Places calls** on open.
- **Venues are plannable — full parity with date cards ✓ (two-phone verified):** a Near You venue match → **"Plan This Date"** creates a **Mission** (date/time + checklist), completes into a shared **Memory**, and **syncs to the partner** — the same Match→Mission→Memory loop as cards. A venue is adapted into a `DateCard` via `DateCard(fromVenue:)` (lossy by design — keeps title/emoji/description; defaults difficulty/cost/category), so the Mission/sync/completion chain is **unchanged**. The mission's `deck` is `.places`; the partner rebuilds the card from `VenueCache.venue(forId: placeId)` (mirrors the `.places` MATCH rebuild). All read-only by placeId, **0-bill, NO Firestore schema/sync change**.
- **Rich venue info on a planned venue mission ✓ (Route A, two-phone verified):** the mission shows rating + address inline (`MissionDetailView` looks the venue up read-only by placeId), plus a **"View place details"** sheet that presents `EventDetailView` with **photos, full weekly hours, and 4★+-filtered reviews**, and a **Book Now** that opens the exact place in Google Maps (placeId `googleMapsUri` via `EventLinkBuilder`). The calendar button is hidden here (`showCalendarAction: false` — the mission owns its own schedule). **Photos MUST use `BundledRemoteImage`** (the bundle-key 403 rule above — never `AsyncImage`). All read-only from `VenueCache.venue(forId:)`; no sync/schema touch.

### Daily Questions — couple-synced (built, NOT committed, PENDING two-phone test)
~130 `ConnectionQuestions` with day-rotation + reveal UI already existed as a stub, but answers saved only to local `@AppStorage` and "waiting for partner" was hardcoded fake. Now real-synced via `DailyQuestionService` + `DailyAnswerDoc`: subcollection-per-day, **answer-to-unlock** reveal (you see your partner's answer only after you answer too), passive Firestore listener (no push). `dailyAnswers` `firestore.rules` are couple-scoped, write-your-own-uid-key only. **Rules DEPLOYED; code NOT committed.** PENDING: two-phone test, then commit.

### Add to Calendar — working as designed (not a bug)
"Add to Calendar" creates the event on the **device** calendar (`sourceType = 2`, CalDAV); it just doesn't surface in the Google Calendar app, which is where it looked missing. DECISION: keep the manual button as-is for launch (on-brand); auto-add-on-schedule deferred.

### Push notifications + Cloud Functions — ALL 5 STAGES DONE ✅ (match nudge live on two phones)
Goal: partner-nudge feature ("Inesa is swiping — join her?"). Stages: **1 = Cloud Functions foundation [DONE]** → **2 = APNs + push capability [DONE]** → **3 = FCM + device tokens [DONE]** → **4 = test push arrives [DONE]** → **5 = nudge logic [DONE]**. The first real nudge — the MATCH nudge — is verified end-to-end on two physical phones.
- Node + npm + Firebase CLI installed; `firebase login` + `firebase init functions` done (JavaScript, ESLint No). `functions/` holds `index.js` (`maxInstances: 10` cost cap, `region: europe-west1`), `package.json` (Node 22), `firebase.json` functions block (firestore/storage rules intact); `npm install` done.
- `helloWorld` HTTP function DEPLOYED + confirmed live. Project on **Blaze** (€257 free-trial credit, 55 days, €20/mo budget alert).
- `firebase-functions` is on **v6** (6.6.0); v7 exists with breaking changes — deliberately NOT upgraded yet (nothing to migrate at this stage).
- **Stage 5 (match nudge) shape:** FCM tokens persist to `couples/{id}.fcmTokens[uid]` (per-uid map, written via `CoupleService.persistFCMToken`, parked-until-paired like display names; AppDelegate → `PushTokenBridge` → CoupleService). Permission prompt moved from cold launch to the **first mutual match** (warm, partner-framed; `PushAuthorization` + `MainTabView`). `onMatchCreated` (Firestore `onDocumentCreated` on `matches/{cardId}`) pushes the partner who ISN'T `createdBy`; match doc records `createdBy` and `firestore.rules` enforces `createdBy == uid()` so the nudge target is forge-proof. **Brand rule for all nudge copy: warm + partner-framed, NEVER time/guilt-based.**
- **`sendTestPush` REMOVED** (the Stage-4 manual push rehearsal) once the real nudge worked; deleted from source + project.
- **Manual nudge button LIVE** (2nd nudge type): the Home dashboard's "💕 Nudge [partner] to swipe" button (long a UI-only stub) now calls `nudgePartner` — a **CALLABLE** (`onCall`, authenticated) function that resolves the couple by membership, pushes the partner "[Name] wants to plan a date with you 💛 / Open iLovu to swipe together →", and rate-limits **one nudge per couple per 2h** (server-authoritative, stamped on `couples/{id}.lastManualNudgeAt`, mirrored to button state via observeCouple). Required linking the **FirebaseFunctions** SDK product into the Xcode target (mirrored FirebaseStorage in `project.pbxproj`). Verified on two phones.
- **GOTCHA (learned the hard way):** the default compute service account (`<projnum>-compute@developer.gserviceaccount.com`) needs the **`roles/datastore.user`** IAM role for any function that READS/WRITES Firestore via the Admin SDK — without it `onMatchCreated`'s `coupleRef.get()` throws `7 PERMISSION_DENIED` (Admin SDK bypasses Firestore *rules* but NOT GCP *IAM*). FCM-only functions (sendTestPush) didn't expose this; the first Firestore-reading function did. Grant once via Cloud Console IAM or `gcloud projects add-iam-policy-binding`.
- **Special-date reminders LIVE** (3rd nudge type): `sendDateReminders` — our first **SCHEDULED** (cron) function (`onSchedule`, `firebase-functions/v2/scheduler`), runs daily `0 9 * * *`. Once a day it scans every couple and pushes warm reminders for recurring annual dates that are TODAY or 3 days out (`REMINDER_LEAD_DAYS`): anniversary (`milestones.dating`, legacy `anniversaryDate` fallback) always; engagement (`milestones.engaged`) only if status Engaged/Married; wedding (`milestones.wedding`) only if Married; both `birthdays[uid]`. Matches on **month+day only** (year ignored — recurring). Each date fires twice/yr: a heads-up + on the day. **Recipients:** shared dates → BOTH partners; a birthday → the OTHER partner only (surprise-preserving, "It's [Name]'s birthday…"). **Double-send guard:** stamps `couples/{id}.remindersSent[key]="YYYY-MM-DD"`; a same-day re-run skips (server-only field, ignored by Swift decode). Skips gracefully on no token / no date / missing partner. Reuses the `onMatchCreated` send path + stale-token cleanup; inherits `maxInstances:10`. Deploy auto-enabled the Cloud Scheduler + Pub/Sub APIs. **Verified end-to-end on a physical phone** (anniversary banner landed). **Brand copy: warm, no Memory-Vault tie-in.**
  - **TIMEZONE = single-zone (FOR LATER):** all couples are evaluated in `Europe/Vilnius` and pushed at Vilnius 09:00 (no per-couple tz — `eventLocationBucket` is a coarse lat/lng with no tz, and we have no tz lib). Fine for the launch market; **must add real per-couple timezone before international expansion** (else someone abroad gets a 3am-local ping). Constants to change: `REMINDER_TZ` / `REMINDER_HOUR` in `functions/index.js`.
  - **`runDateRemindersNow` = TEMPORARY public test trigger — DELETE BEFORE LAUNCH.** HTTP function (secret-guarded via `?key=`) that runs the scan on demand and returns a JSON `sent`/`skipped` summary; `?force=1` bypasses the dedup and writes no stamp (repeatable, clean). It's a public URL — remove it: delete the block + `TEST_TRIGGER_SECRET` from `functions/index.js`, then `firebase functions:delete runDateRemindersNow --region europe-west1` (a redeploy alone won't prune it).
- **FUTURE nudge types are ON HOLD** pending real-use tone testing (user's call) — beyond match / manual / special-date, no more for now.
- Cloud Functions also unlocks the deferred **PRE-LAUNCH HARDENING** (RevenueCat webhook, atomic invite redemption, App Check, real Storage couple-membership enforcement).

---

## Environment notes (this machine — MacBook Air M5, macOS Tahoe, Xcode 26.6)

- **`SWIFT_USE_INTEGRATED_DRIVER = NO`** is set in both Debug and Release app configs. This is a workaround for an Xcode 26.6 integrated-driver `SWBBuildService` SIGTRAP crash. Remove it once a future Xcode fixes the driver. **Do not remove it casually** — builds will crash.
- `Secrets.swift` and `GoogleService-Info.plist` are **gitignored** and must stay that way. They live on disk only. `Secrets.swift` holds `enum Secrets { static let googlePlacesAPIKey = "..." }`.
- Xcode lives in `/Applications` (not Downloads). Toolchain via `xcode-select` points there.
- Build setting ≠ binary lesson: Xcode silently drops `INFOPLIST_KEY_` suffixes — verify the built binary, not just build settings.

---

## Conventions

- **Claude Code** (this tool): multi-file coordinated edits, builds, repo-wide changes.
- **Claude chat** (the project): architecture, strategy, planning.
- Real-device testing requires cable install (deep link won't bootstrap an install). Two-phone tests need two **different Apple IDs**.
- **Two-phone re-test reset:** deleting `couples` + `invites` in Firestore (and `couples/` photos in Storage) is NOT enough — local `@AppStorage` keeps a zombie half-paired state. You MUST **delete + reinstall the app on BOTH phones**. Keep the shared caches (`venues`, `venueQueries`, `eventQueries`, `placeDeckQueries`); only couple data needs clearing.
- Security is day-one, not retrofitted: Firestore rules, single-use invite tokens, photo/Vault access control all built in (token *expiry* is a planned addition, not yet implemented). Proof photos now live in Cloud Storage (not UserDefaults). Pre-launch hardening (all client-authed today, tracked together in `// PRE-LAUNCH HARDENING` comments): move cache writes + invite redemption to Cloud Functions; bind couple membership to the auth token via a custom `coupleId` claim set by a Cloud Function at pairing, so `storage.rules` (and the Firestore subcollection writes) can enforce real membership instead of just signed-in; enable App Check.

---

## Pricing (locked)

$6.99/mo or $49.99/yr. **One subscription unlocks both partners — never split payment.** Founding offer: $39.99/yr for first 500 users. Push annual. On breakup: subscription follows the payer; both keep their own copy of shared memories.

---

## Current phase

**Phase 2 (Firebase) — in progress.** Auth ✓, invite/couple pairing ✓, real matching ✓, deep link ✓, name sync ✓, **Memory Vault sync ✓** (shared couple photo + proof photos via Firebase Storage; couple doc live-syncs name + photo via a snapshot listener), **paywall trigger ✓** (`PaywallGate` — the soft-wall *WHEN* logic: arms at 2nd match + 1st memory, or a 14-day backstop; presents at the next calm mission-start, never mid-celebration), **RevenueCat purchase/entitlement ✓** (real `Purchases.shared.purchase`/`restore` + live `premium` entitlement → couple-doc `isPremium` mirror — see decision above), **Near You ✓** (curated Google Places, deck-cached; **venues now plannable as Missions** — date/time + checklist + partner-sync, with rich venue info (photos/hours/4★+ reviews/maps) on the mission — see decision above), **Push notifications ✓** (all 5 stages; match nudge + manual nudge + scheduled special-date reminders all live, verified on phone — see Push section). **Daily Question sync** built (rules deployed) but PENDING two-phone test + commit. Remaining: verify the RevenueCat **dashboard offering + App Store Connect products** are configured (external, not code — required for a real purchase to complete); the **RevenueCat webhook → Cloud Function** for authoritative grant/revoke (the v1 client-mirror revocation gap); further nudge types (on hold for tone testing); delete the `runDateRemindersNow` test trigger before launch; Cloud Functions hardening (atomic redeem + cache writes + Storage/Firestore couple-membership + App Check).

**Phase 3:** Events — **DEPRIORITIZED / pivoted.** Eventbrite is dead (public API removed); Ticketmaster code is built but dormant until we target event-rich markets (London/US). No Facebook Events, no SerpApi. Near You ships on curated Places instead.
**Phase 4:** Polish + launch. Post-launch priority: iOS shared widgets (next-Mission, Memory-photo, days-together) — keep WARM, not guilt-tripping.

**Onboarding (to build):** SHORT — name, vibe, relationship status only. Progressive collection of dates after first match/memory, fully skippable. No spark rating (off-brand).
