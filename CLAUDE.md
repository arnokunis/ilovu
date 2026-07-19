# CLAUDE.md — iLovu

Project context for Claude Code sessions. Read this first.

---

## CURRENT STATUS (updated 2026-07-19)

**iLovu is LIVE on the App Store** as of ~July 11 2026: https://apps.apple.com/app/id6781237573 — **post-launch phase, NOT pre-launch.** Any "pre-launch" framing below is historical (the hardening sprint etc. happened before launch); read it as done-before-launch, not still-pending-for-launch.

- **Real users:** ~13 downloads. **Apple Search Ads running** (~€2.23 CPI).
- **Known live problem — 0 completed pairs:** invites are generated but never redeemed. Suspected cause: the invite share message carried only the `ilovu://` custom-scheme link (stripped/dead in messaging apps for a partner without the app) and **no App Store link**, so recipients had no install path. Interim fix shipped in 1.0.1 (in review): store link + typed code in the message. The proper fix — **Universal Links via `ilovu.io` — is BUILT + COMMITTED (`ed3928f`, 2026-07-19)**: web half (AASA + `invite.html` landing page) is **LIVE on ilovu.io**; the app half (applinks entitlement, dual-form parsing, one-link share message) **ships as 1.0.2** once 1.0.1 clears review. Same day: **pairing push deployed** — `redeemInvite` notifies the inviter "You're connected 💕" when the partner joins. See the Invite link decision.
- **North-star metric:** completed dates (memories) per couple per month. Immediate diagnostic to watch: `invite_created → invite_redeemed` conversion.

---

## What iLovu is

A couples date-planning iOS app (SwiftUI). Core loop:

> Both partners swipe date-idea cards + real local events → a mutual match becomes a **Mission** → the Mission is completed by capturing a **Proof Photo** → the photo lands in a shared **Memory Vault**.

**Positioning is firmly anti-pressure**: "one real date a month, science-backed." Tagline: *"Show it. Don't just say it. 💕"* The completion/proof loop (match → Mission → Proof Photo → Memory Vault) is the competitive wedge — no competitor does "proof you went." Do **not** drift toward "relationship repair/reignite" framing; that's off-brand.

**Brand voice pattern (locked):** "Clear keyword line + soul kicker." e.g. "Date ideas for couples who actually go." / "Show it. Don't just say it. 💕"

---

## Commands

Scheme is `iLovu`; test targets are `iLovuTests` (unit, Swift Testing / `@Test`) and `iLovuUITests` (XCUITest). All Swift sources are flat in `iLovu/`; the two `*Service.swift` + `*Store.swift` pairs are the Firestore sync layer.

**Build & test (iOS app)** — run from repo root:
```bash
# Build for the simulator
xcodebuild -scheme iLovu -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run all unit tests
xcodebuild test -scheme iLovu -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:iLovuTests

# Run a single test (Type/method from the Swift Testing struct)
xcodebuild test -scheme iLovu -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:iLovuTests/InviteDeepLinkTests/parsesTokenFromValidLink
```
Note: `SWIFT_USE_INTEGRATED_DRIVER = NO` is set in the project (Xcode 26.6 driver-crash workaround — see Environment notes); don't remove it. Day-to-day dev is normally driven from Xcode, not the CLI. `Secrets.swift` + `GoogleService-Info.plist` are gitignored and must exist on disk for a build to succeed.

**Cloud Functions** (`functions/`, Node 22) — run from `functions/`:
```bash
npm install                    # deps
npm run deploy                 # firebase deploy --only functions (europe-west1)
npm run logs                   # firebase functions:log
npm run serve                  # emulator (functions only)
```
Deploy rules from repo root: `firebase deploy --only firestore:rules` / `firebase deploy --only storage`. **Deploy order when tightening a rule: Cloud Function FIRST, then rules** (no window where a locked rule has no CF path). Firebase project: `ilovu-b5d87` (`.firebaserc` default). Deleting a deployed function: `firebase functions:delete <name> --region europe-west1`. No linter is configured (ESLint was declined at `init`).

---

## Tech stack

- **SwiftUI**, iOS-only (iPhone, `TARGETED_DEVICE_FAMILY = 1`)
- **Firebase**: Auth (Sign in with Apple) + Firestore (Standard, EU region) + Cloud Storage + **App Check** (App Attest, MONITORING mode — enforcement pending #4b, see Pre-launch hardening sprint)
- **Google Places API (New)** — venue data, read-through cached to Firestore; now also powers **Near You** (curated restaurants/wine bars/cafés). Bundle-restricted keys need the `X-Ios-Bundle-Identifier` header — see the Near You decision below.
- **RevenueCat** — **INTEGRATED**: `Purchases.configure` at launch with the real `appl_` SDK key (`Secrets.revenueCatAPIKey`); `SubscriptionService` owns the live `premium` entitlement + `default` offering + real purchase/restore. See the RevenueCat decision below. (The dashboard offering + App Store Connect products are external config, NOT verifiable from code.)
- **Ticketmaster** — events code built but **DORMANT** (no date-appropriate Vilnius events; kept for event-rich markets like London/US). **Eventbrite: DEAD** — it removed its public Event Search API; do not pursue.
- **Cloud Functions** (Node 22, `firebase-functions` v6, `europe-west1`) — deployed: `onMatchCreated` (match nudge), `onDailyAnswer` (Daily-Question partner nudge, 2026-07-19), `nudgePartner` (manual nudge), `sendDateReminders` (scheduled), `deleteAccount` (in-app account deletion), plus `cacheWrite` + `redeemInvite` from the hardening sprint. See Push notifications + Pre-launch hardening sprint below.
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
couples/{coupleId}/dailyAnswers/{dayKey} // DailyQuestionService — Daily Question sync (committed c28201b; rules deployed)
  answers: { uid: text }, questionId, updatedAt  // each writes ONLY own uid key; answer-to-unlock reveal, passive listener

invites/{token}                          // Invite.swift — doc ID IS the token (5-char code, single-use)
  creatorId, status ("pending"|"consumed"), consumedBy (null until redeemed), createdAt
  // 2026-07-18: token shrank 10 → 5 chars (typeable at the pairing moment). Guessing is
  // closed server-side instead of by entropy: invite reads are CREATOR-ONLY in rules
  // (redeem is CF-only, nobody else needs to read), redeemInvite rate-limits failed
  // attempts (10/hr/uid, bookkept in server-only redeemAttempts/{uid}) and enforces a
  // 7-DAY EXPIRY off createdAt (no expiresAt field; old 10-char invites still redeem)
  // redemption is ATOMIC via the redeemInvite CF ✓ (consume + couple-create in one
  // transaction); firestore.rules: invites-update + couples-create are CF-only (write:false)

// cache collections below are world-READABLE, but writes are Cloud-Function-only ✓
// (firestore.rules write:false; the app writes via the `cacheWrite` callable — hardening #2).
// events/{eventId} is the one exception (still signed-in write; dormant, has a concrete Timestamp).
venues/{placeId}                         // world-readable cache
venueQueries/{queryKey}                  // read-through cache, stale-while-revalidate (>7 days)
eventQueries/{queryKey}                  // Ticketmaster events cache (DORMANT — see Tech stack)
placeDeckQueries/{queryKey}              // Near You curated-Places deck cache (per-open re-bill fixed)
```

**Cloud Storage (EU bucket) — couple photos.** Image BYTES live here, not in Firestore; docs store the Storage PATH only (never a download URL / embedded secret — the Places-key lesson). `StorageService` uploads/downloads by path; `ImageCache` (FileManager) caches download-once so egress scales with content, not usage. Compression is centralized in `ImageDownscaler` (1024px / JPEG 0.7).
```
couples/{coupleId}/profile.jpg               // shared couple photo (overwritten on change)
couples/{coupleId}/memories/{memoryId}.jpg   // proof photos (Memory Vault)
```
`storage.rules` enforces couple membership via the `coupleId` auth claim ✓ (hardening #3): Storage rules can't read Firestore, so membership rides the token — `couples/{coupleId}/**` requires `request.auth.token.coupleId == coupleId` (+ image/size checks on write). See the Pre-launch hardening sprint decision below.

### Real matching — client-side intersection, no Cloud Functions
Lives in `MatchService`: `recordLike(coupleId:cardId:deck:)` + `observeMatches(coupleId:onMatch:)`. On a right-swipe each partner `arrayUnion`s their own uid into `couples/{coupleId}/swipes/{cardId}.likedBy`; a strongly-consistent read-after-write detects when both UIDs are present and creates the match doc. The match doc uses the card ID as its doc ID, so a both-liked-at-once race collapses to one idempotent doc. The partner who didn't complete the match is notified via an app-level `matches` snapshot listener (dedupe against a *persisted* set of celebrated cardIds, or every past match replays on launch). **Unpaired → falls back to `Bool.random()` solo celebration** (`SwipeView.swift:214`). Both phones must complete pairing before real matching works.

### Invite link — custom scheme now, Universal Links later
`ilovu://invite/<token>` via Info.plist + `onOpenURL`, parsed by `CoupleService.inviteToken(from:)` / built by `inviteURL(token:)`. The invite lifecycle is `CoupleService.createInvite()` → `redeem(token:)` → `currentCouple()`. **Firebase Dynamic Links is dead (shut down Aug 25 2025)** — do not use it. Custom scheme only resolves if the app is already installed; manual "Have a code?" field is the backup. Universal Links via `ilovu.io` (AASA on Netlify) + deferred deep-linking is the future upgrade.
- **LIVE BUG + fix (2026-07-18):** in production this produced **0 completed pairs** — the share message had NO App Store link, so a partner without the app hit a dead `ilovu://` link and a code for an app they couldn't find. `inviteShareMessage` now leads with the App Store link (`CoupleService.appStoreURL`, id6781237573) then the typed code, with the scheme link last as the installed-fast-path. Universal Links is the proper fix and is now the top growth priority.
- **Universal Links ✓ BUILT + COMMITTED (`ed3928f`, 2026-07-19); web half LIVE, app half ships as 1.0.2.** `https://ilovu.io/invite/<token>` is the ONE shared link: opens the app when installed, else Safari shows the invite landing page.
  - **App side (`CoupleService.swift`):** `universalLinkHost = "ilovu.io"`; `inviteWebURL(token:)` builds the https link; `inviteToken(from:)` parses BOTH the custom scheme AND `https://ilovu.io|www.ilovu.io/invite/<token>` (SwiftUI delivers both via the same `onOpenURL`); `inviteShareMessage` is ONE smart link + plain-text code. 7 parser tests in `iLovuTests.swift` (18 total, green).
  - **Entitlement:** `com.apple.developer.associated-domains` = `applinks:ilovu.io` ONLY — `www` was deliberately dropped: `www.ilovu.io` 301s to the apex and Apple's AASA fetcher won't follow redirects (the parser still accepts www URLs).
  - **Web side (`site/`, LIVE + verified):** AASA lives as the VISIBLE `site/aasa.json`, rewritten to `/.well-known/apple-app-site-association` via `_redirects` (200 rewrite) — because **Netlify drag-and-drop silently skips hidden folders** (learned live: the `.well-known/` copy 404'd on first deploy). `site/_headers` forces `Content-Type: application/json`. `/invite/*` → `invite.html` (landing page: big copyable code, App Store button, open-app button). Verified: AASA 200 + JSON, landing 200.
  - **Pairing push ✓ (same day, CF + rules DEPLOYED):** the creator is asked for notification permission at invite creation (warm ask in `PairingView`, mirrors the first-match pattern); their FCM token rides `invites/{token}.creatorFcmToken` (attached at create or late via `persistFCMToken` + `activeInviteToken`; a narrow rules carve-out lets the creator update ONLY that field on their own pending invite); `redeemInvite` pushes "You're connected 💕" and strips the token from the client response.
  - **Still to do at 1.0.2 time:** confirm Associated Domains appears in Xcode Signing & Capabilities (automatic signing registers the App ID capability on first build), then two-phone verify: installed partner taps link → app opens + auto-redeems; fresh-install partner sees the landing page. AASA is CDN-cached by Apple — first activation on a device can lag or need a reinstall.

### Cost architecture (critical — 95% margin target)
Naive per-user live Places fetching is catastrophic (~$16k/mo at 300 users). **Cache everything**: fetch each venue once to Firestore, serve both card and detail from cache. Scales with venues, not users. Set a Billing budget alert the moment paid billing is attached.

### Subscriptions — RevenueCat (INTEGRATED; real purchase flow live in code)
`SubscriptionService` is the single source of truth: `Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)` runs at launch (real `appl_` public SDK key, gitignored in `Secrets.swift`). It reads the **`premium`** entitlement off `customerInfoStream` (live: purchase/renewal/expiry), loads the **`default`** offering's `$rc_annual` / `$rc_monthly` packages (products `com.ilovu.app.annual` $49.99/yr, `com.ilovu.app.monthly` $6.99/mo), and runs **real** `Purchases.shared.purchase(package:)` / `restorePurchases()`. Dashboard ids are centralized in `RevenueCatConfig.swift`.
- **Paywall is real, not stubbed:** presented from `HomeView` (`showPaywall`), its buy/restore buttons call `subscriptionService.purchaseAnnual()/purchaseMonthly()/restore()`. The only stub is `PaywallView`'s `#Preview`. `PaywallGate` decides only WHEN the wall appears (soft show-once OR hard persistent — see Hard mode below); the purchase itself is separate.
- **Hard mode ✓ (commit `24e0446`) — `PaywallGate.hardMode` (default `true`):** the soft show-once wall is now a persistent HARD wall behind ONE reversible flag. Armed + not subscribed + hardMode → the wall presents on EVERY mission-open from Home (ignoring the show-once latch) and the tapped mission does NOT open on dismiss, UNLESS the couple subscribed on the wall just then (smooth post-purchase proceed). Only gate point is `HomeView.openMission`; pairing / swiping / matching / "Plan This Date" / the Vault are NEVER gated. Arming is unchanged. Flip `hardMode = false` → reverts to soft / dismiss-through / show-once in one line (resting for an A/B call). Verified end-to-end on two phones.
- **POST-LAUNCH — Revisit paywall gating consistency (DEFERRED; measure, don't guess):** "Plan This Date" is currently **ungated** while the Home **mission-tab IS gated** (and dismissible per mode); decide whether to add "Plan This Date" as a SECOND trigger — **(A)** one wall per session then through, or **(B)** block every time — and **measure via a RevenueCat experiment** rather than picking on intuition. Build shape when we do it: add the post-match plan flow (`MainTabView` MatchView/EventMatchView completions) as a SECOND gate that **reuses `PaywallGate.shouldPresentAtMissionStart`** — arming is UNCHANGED (2nd match + 1st memory, or the 14-day backstop; early users still never see it), it only fires when already armed + not subscribed. Build shape: keep the arm/subscribed decision single-sourced in `PaywallGate` (no duplicated check); `MainTabView` mirrors `HomeView`'s paywall sheet to gate the two Plan-This-Date completions; add an in-memory `presentedThisSession` cap + a shared `markPresented(coupleId:)` so the two triggers never wall an armed non-subscribed user twice in one session (soft mode already dedupes via the persisted `shownKey`; hard mode has no shared session state today). **UNRESOLVED A/B — decide via a RevenueCat experiment, NOT intuition:** hard mode's 2nd gated action in a session — **(A)** cap-then-let-through (one hard wall per session, then missions open) vs **(B)** strict block every time (re-present at each gated action). Brand caveat: this gates "plan the date you just matched" for armed users — a shift from the locked "Plan This Date is never gated" stance, hence measuring first. **v1 ships the CURRENT single trigger only (Home mission-row); "Plan This Date" stays ungated.**
- **Gate arming fix ✓ (commit `f534326`):** the gate's `memoryCount` now also updates when a memory arrives via REMOTE sync (`applyRemoteMemory` → `recordMemoryCount`), not only on local completion + couple-attach — so the partner who RECEIVES a synced memory arms Condition A without a relaunch (previously the Vault could show N memories while the gate still read 0).
- **Couple sharing ("one sub unlocks both"):** `premiumActive(couple:) = myEntitlementActive OR couple.isPremium`. On an entitlement flip, `onEntitlementChange` → `CoupleService.syncPremiumEntitlement` mirrors `isPremium` onto the shared couple doc (PAYER only), so the non-paying partner unlocks off the doc.
- **Subscription status + management UI ✓ (commit `0d09ff2`):** the "Us" tab (`UsView`) shows the couple's state derived from the SAME source as the gate (`premiumActive`), so it can't diverge — "Premium — Annual/Monthly" (payer; plan read from `customerInfo.entitlements["premium"].productIdentifier` via new `RevenueCatConfig` product-id constants), "Premium — covered by [partner]" (mirrored partner), or "Free". A **"Manage Subscription"** button (never a fake "Cancel" — Apple forbids self-cancel) deep-links to StoreKit 2's native `AppStore.showManageSubscriptions(in:)`, falling back to `apps.apple.com/account/subscriptions` (no scene / throws). Shown ONLY when `myEntitlementActive` (this Apple ID owns the sub); the partner sees "Managed by [partner]", no button. **Satisfies App Store 3.1.2** (subscription apps must provide a way to manage/cancel).
- **NOT verifiable from code (external):** whether the RevenueCat dashboard `default` offering + the two App Store Connect products are actually configured/purchasable. If missing, `loadOfferings()` leaves packages nil and a buy returns the friendly "Plans are still loading — try again," not a crash. The app passed App Review with subscriptions and is live, so ASC products exist; still confirm a real production purchase completes end-to-end.
- **HARDENING (v1 gap):** entitlement **revocation is client-mirror only** — if the payer's sub lapses and they never reopen the app, the couple-doc `isPremium` lingers (premium too long; never wrongly drops). Clean end-state: a **RevenueCat webhook → Cloud Function** writing the couple doc authoritatively (grant AND revoke), which also closes the "a member could set `isPremium=true` without paying" hole. Tracked with the other `// PRE-LAUNCH HARDENING` items.

### Near You — curated Google Places, not events (pivoted, committed 778a857, works on device)
Near You ships as live **curated Google Places** (restaurants, wine bars, cafés by name) via `PlaceCuration.swift` + `NearYouConfig.source = .places` — pivoted away from events because Ticketmaster had no date-appropriate Vilnius events and **Eventbrite removed its public Event Search API** (dead end). The Ticketmaster events path is kept **dormant-but-intact** for event-rich markets (London/US) later.
- **Places 403 fix (locked):** iOS-bundle-restricted Google keys require the `X-Ios-Bundle-Identifier` header on raw `URLSession` Places calls (search), plus a custom `BundledRemoteImage` loader for photos (`AsyncImage` can't send headers). **Do NOT loosen the key restriction to fix a 403** — send the header.
- **Cache cost fixes:** deployed `placeDeckQueries` `firestore.rules` (stops per-open re-billing); fixed `@ServerTimestamp` returning `nil` right after a write (false-stale → re-billing) by reading with `.estimate` `ServerTimestampBehavior` across placeDeck + EventCache + venueQuery. Confirmed on device: **deck HIT (fresh), 0 Places calls** on open.
- **Venues are plannable — full parity with date cards ✓ (two-phone verified):** a Near You venue match → **"Plan This Date"** creates a **Mission** (date/time + checklist), completes into a shared **Memory**, and **syncs to the partner** — the same Match→Mission→Memory loop as cards. A venue is adapted into a `DateCard` via `DateCard(fromVenue:)` (lossy by design — keeps title/emoji/description; defaults difficulty/cost/category), so the Mission/sync/completion chain is **unchanged**. The mission's `deck` is `.places`; the partner rebuilds the card from `VenueCache.venue(forId: placeId)` (mirrors the `.places` MATCH rebuild). All read-only by placeId, **0-bill, NO Firestore schema/sync change**.
- **Rich venue info on a planned venue mission ✓ (Route A, two-phone verified):** the mission shows rating + address inline (`MissionDetailView` looks the venue up read-only by placeId), plus a **"View place details"** sheet that presents `EventDetailView` with **photos, full weekly hours, and 4★+-filtered reviews**, and a **Book Now** that opens the exact place in Google Maps (placeId `googleMapsUri` via `EventLinkBuilder`). The calendar button is hidden here (`showCalendarAction: false` — the mission owns its own schedule). **Photos MUST use `BundledRemoteImage`** (the bundle-key 403 rule above — never `AsyncImage`). All read-only from `VenueCache.venue(forId:)`; no sync/schema touch.

### Daily Questions — couple-synced ✓ (COMMITTED + rules deployed; only a two-phone smoke test outstanding)
~130 `ConnectionQuestions` with day-rotation + reveal UI already existed as a stub, but answers saved only to local `@AppStorage` and "waiting for partner" was hardcoded fake. Now real-synced via `DailyQuestionService` + `DailyAnswerDoc`: subcollection-per-day, **answer-to-unlock** reveal (you see your partner's answer only after you answer too), passive Firestore listener (no push). `dailyAnswers` `firestore.rules` are couple-scoped, write-your-own-uid-key only. **Committed `c28201b` ("Wire real couple sync for the Daily Question") + rules deployed; wired end-to-end** — `DailyQuestionService` injected at the app root (`iLovuApp`), `DailyQuestionCard` presented in `UsView` (passes `nil`/`isOrphaned` for unpaired & orphaned couples → local `@AppStorage` fallback). Only the on-device **two-phone reveal smoke test** is still unchecked (needs two Apple IDs; not a code gap).
- **Partner-answered push ✓ (DEPLOYED + committed `fe140b9`, 2026-07-19):** new `onDailyAnswer` Cloud Function (`onDocumentWritten` on `couples/{id}/dailyAnswers/{dateKey}`) pushes the partner of whoever just answered — a **nudge-to-unlock** on the first answer ("[Name] answered today's question 💬 / Answer to see theirs 💕") and a **reveal** ping to the first answerer when the pair completes ("[Name] answered too 💬 / Tap to see what they said 💕"). Fires only on a genuinely NEW answer key (diffs before/after → edits & updatedAt-only writes don't re-nudge), skips orphaned/no-token/half-paired couples, reuses the `onMatchCreated` send path + stale-token cleanup, needs NO new IAM role (Firestore read/write, `datastore.user` already granted) and **NO client change** (reuses existing `fcmTokens` + match-time permission). **BRAND softening (noted deliberately):** the card's original "anti-pressure, NO notifications" stance banned *guilt/nagging* pings — this is the warm, partner-framed kind (same tone as the match nudge), which the user green-lit. **Live in europe-west1; only a two-phone reveal test remains.**

### Add to Calendar — working as designed (not a bug)
"Add to Calendar" creates the event on the **device** calendar (`sourceType = 2`, CalDAV); it just doesn't surface in the Google Calendar app, which is where it looked missing. DECISION: keep the manual button as-is for launch (on-brand); auto-add-on-schedule deferred.

### Push notifications + Cloud Functions — ALL 5 STAGES DONE ✅ (match nudge live on two phones)
Goal: partner-nudge feature ("Inesa is swiping — join her?"). Stages: **1 = Cloud Functions foundation [DONE]** → **2 = APNs + push capability [DONE]** → **3 = FCM + device tokens [DONE]** → **4 = test push arrives [DONE]** → **5 = nudge logic [DONE]**. The first real nudge — the MATCH nudge — is verified end-to-end on two physical phones.
- Node + npm + Firebase CLI installed; `firebase login` + `firebase init functions` done (JavaScript, ESLint No). `functions/` holds `index.js` (`maxInstances: 10` cost cap, `region: europe-west1`), `package.json` (Node 22), `firebase.json` functions block (firestore/storage rules intact); `npm install` done.
- `helloWorld` smoke-test HTTP function proved the deploy pipeline (Stage 1), then **REMOVED ✅ (2026-06-30, commit `343a7d1`)** once the real functions shipped. Project on **Blaze** (€257 free-trial credit, 55 days, €20/mo budget alert).
- `firebase-functions` is on **v6** (6.6.0); v7 exists with breaking changes — deliberately NOT upgraded yet (nothing to migrate at this stage).
- **Stage 5 (match nudge) shape:** FCM tokens persist to `couples/{id}.fcmTokens[uid]` (per-uid map, written via `CoupleService.persistFCMToken`, parked-until-paired like display names; AppDelegate → `PushTokenBridge` → CoupleService). Permission prompt moved from cold launch to the **first mutual match** (warm, partner-framed; `PushAuthorization` + `MainTabView`). `onMatchCreated` (Firestore `onDocumentCreated` on `matches/{cardId}`) pushes the partner who ISN'T `createdBy`; match doc records `createdBy` and `firestore.rules` enforces `createdBy == uid()` so the nudge target is forge-proof. **Brand rule for all nudge copy: warm + partner-framed, NEVER time/guilt-based.**
- **`sendTestPush` REMOVED** (the Stage-4 manual push rehearsal) once the real nudge worked; deleted from source + project.
- **Manual nudge button LIVE** (2nd nudge type): the Home dashboard's "💕 Nudge [partner] to swipe" button (long a UI-only stub) now calls `nudgePartner` — a **CALLABLE** (`onCall`, authenticated) function that resolves the couple by membership, pushes the partner "[Name] wants to plan a date with you 💛 / Open iLovu to swipe together →", and rate-limits **one nudge per couple per 2h** (server-authoritative, stamped on `couples/{id}.lastManualNudgeAt`, mirrored to button state via observeCouple). Required linking the **FirebaseFunctions** SDK product into the Xcode target (mirrored FirebaseStorage in `project.pbxproj`). Verified on two phones.
- **GOTCHA (learned the hard way):** the default compute service account (`<projnum>-compute@developer.gserviceaccount.com`) needs the **`roles/datastore.user`** IAM role for any function that READS/WRITES Firestore via the Admin SDK — without it `onMatchCreated`'s `coupleRef.get()` throws `7 PERMISSION_DENIED` (Admin SDK bypasses Firestore *rules* but NOT GCP *IAM*). FCM-only functions (sendTestPush) didn't expose this; the first Firestore-reading function did. Grant once via Cloud Console IAM or `gcloud projects add-iam-policy-binding`. **Sibling GOTCHA (hardening sprint):** setting custom claims needs a FURTHER role — `roles/firebaseauth.admin` on the same SA — because `admin.auth().setCustomUserClaims()` touches Auth, not just Firestore. `datastore.user` alone gives `auth/insufficient-permission`. Granted for `redeemInvite`.
- **Special-date reminders LIVE** (3rd nudge type): `sendDateReminders` — our first **SCHEDULED** (cron) function (`onSchedule`, `firebase-functions/v2/scheduler`), runs daily `0 9 * * *`. Once a day it scans every couple and pushes warm reminders for recurring annual dates that are TODAY or 3 days out (`REMINDER_LEAD_DAYS`): anniversary (`milestones.dating`, legacy `anniversaryDate` fallback) always; engagement (`milestones.engaged`) only if status Engaged/Married; wedding (`milestones.wedding`) only if Married; both `birthdays[uid]`. Matches on **month+day only** (year ignored — recurring). Each date fires twice/yr: a heads-up + on the day. **Recipients:** shared dates → BOTH partners; a birthday → the OTHER partner only (surprise-preserving, "It's [Name]'s birthday…"). **Double-send guard:** stamps `couples/{id}.remindersSent[key]="YYYY-MM-DD"`; a same-day re-run skips (server-only field, ignored by Swift decode). Skips gracefully on no token / no date / missing partner. Reuses the `onMatchCreated` send path + stale-token cleanup; inherits `maxInstances:10`. Deploy auto-enabled the Cloud Scheduler + Pub/Sub APIs. **Verified end-to-end on a physical phone** (anniversary banner landed). **Brand copy: warm, no Memory-Vault tie-in.**
  - **TIMEZONE = single-zone (FOR LATER):** all couples are evaluated in `Europe/Vilnius` and pushed at Vilnius 09:00 (no per-couple tz — `eventLocationBucket` is a coarse lat/lng with no tz, and we have no tz lib). Fine for the launch market; **must add real per-couple timezone before international expansion** (else someone abroad gets a 3am-local ping). Constants to change: `REMINDER_TZ` / `REMINDER_HOUR` in `functions/index.js`.
  - **`runDateRemindersNow` test trigger — REMOVED ✅ (2026-06-30, commit `697a6d8`).** The deployed HTTP function was deleted (`firebase functions:delete runDateRemindersNow --region europe-west1`) and its block + `TEST_TRIGGER_SECRET` stripped from `functions/index.js` (no dangling refs; `onRequest` import kept for `helloWorld`). It was a secret-guarded (`?key=`) on-demand scan returning a JSON `sent`/`skipped` summary (`?force=1` bypassed the dedup). `sendTestPush` was already gone. **`helloWorld` (Stage-1 HTTP smoke test) also REMOVED ✅ (commit `343a7d1`)** — deleted from source (+ now-unused `onRequest` import) and via `firebase functions:delete helloWorld --region europe-west1`. Remaining deployed functions are all real: `onMatchCreated`, `nudgePartner`, `sendDateReminders`, `cacheWrite`, `redeemInvite` (the last two from the hardening sprint; the one-off `backfillCoupleClaims` was run then removed ✅, commit `9fcd458`).
- **Daily-question nudge (4th type) ✓ DEPLOYED + committed `fe140b9` (2026-07-19):** `onDailyAnswer` pushes the partner when one member answers the Daily Question (nudge-to-unlock, then a reveal ping on completion). Warm + partner-framed like the others. Details in the Daily Questions decision above. **Only a two-phone reveal test remains.**
- **FUTURE nudge types beyond these are ON HOLD** pending real-use tone testing (user's call) — beyond match / manual / special-date / daily-answer, no more for now.
- Cloud Functions unlocked the **PRE-LAUNCH HARDENING** sprint — atomic invite redemption, cache-write gating, and Storage couple-membership are now DONE (see next). Still deferred: the RevenueCat grant/revoke webhook and App Check enforcement (#4b).

### Pre-launch hardening sprint ✓ (4 of 5 done; committed + pushed to origin/main 2026-07-01)

Locked down the client-authed surfaces flagged in the old `// PRE-LAUNCH HARDENING` notes. Four items shipped and verified on two phones; only App Check enforcement remains. Deploy order each step: Cloud Function first, then rules (so there's no window where a tightened rule has no CF path); existing paired couples stayed working throughout.

- **#4a App Check — SDK integrated, MONITORING mode ✓ (`537bb3c`):** `FirebaseAppCheck` linked into the target; `ILovuAppCheckProviderFactory` uses App Attest on device / `AppCheckDebugProvider` under `#if DEBUG`, registered BEFORE `FirebaseApp.configure()` in `iLovuApp.swift`. Enforcement is OFF server-side — nothing is rejected yet, requests are only recorded verified/unverified. **Enforcement is #4b (still pending).**
- **#2 Cache writes → Cloud-Function-only ✓ (`590abb5`):** `venues` / `venueQueries` / `placeDeckQueries` / `eventQueries` are now `allow write: if false`; the app persists cache docs through the new **`cacheWrite`** callable (auth + collection-whitelist + docId/200 KB validation, re-stamps the stripped `@ServerTimestamp` field). `CacheWriteService.swift` encodes the model, strips the server-timestamp sentinel (can't cross the callable JSON boundary), calls the CF, which re-stamps server-side → identical stored doc. **THIN gate:** the client still runs the Places fetch on-device (bundle-restricted key stays here) — moving the fetch + key server-side is the post-launch fast-follow. `events/{eventId}` is the one cache collection still signed-in-writable (dormant + a concrete `expireAt` Timestamp that doesn't fit the JSON-only relay).
- **#1 Atomic invite redemption ✓ (`e994b7b`):** consume-invite + create-couple now run in ONE Firestore transaction inside the **`redeemInvite`** callable (Admin SDK). `firestore.rules` couples-**create** and invites-**update** are now `if false` (CF-only). `CoupleService.redeem` calls the CF then publishes the couple locally exactly as before; `mapRedeemError` maps the CF's `reason` detail back to the same `InviteError` cases (UI messaging unchanged). Blast radius is new-pairing only — already-paired couples never call redeem.
- **#3 Storage couple-membership via `coupleId` claim ✓ (`f52b560` / `1c97284` / `9fcd458`):** the real hole was Storage (any signed-in user reaching any couple's photos, since Storage rules can't read Firestore). Fixed with a custom **`coupleId` auth claim**: `redeemInvite` stamps it on both members (a one-off secret-guarded `backfillCoupleClaims` did existing couples, then was removed); `CoupleService.refreshAuthClaims` force-refreshes the ID token (after redeem + on `currentCouple`) so the token carries it. `storage.rules` `couples/{coupleId}/**` now requires `request.auth.token.coupleId == coupleId`. **Firestore couple-scoped rules were left as-is** — `isCoupleMember()` already enforces membership via a couple-doc read, so migrating them to the claim would be perf/consistency only (deferred, not a fix).
- **Remaining — #4b flip App Check enforcement:** enable enforcement (console) for Firestore + Storage + Functions. **Blocked on a parked dev-build App Check debug-token 403** (harmless in monitoring; a hard block under enforcement) — resolve it and confirm a clean verified exchange on both phones FIRST. Widest blast radius (every Firebase call at once); do it in a dedicated session. Also still open: the RevenueCat webhook (grant/revoke), gating `events/{eventId}`, and the full server-side Places fetch.

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
- **Analytics go through `AppAnalytics` (`AnalyticsService.swift`) — the single Firebase Analytics choke point.** Named `AppAnalytics` (not `Analytics`) to avoid clashing with FirebaseAnalytics' own type. Log ONLY the canonical funnel names — don't invent variants: `sign_in → onboarding_complete → invite_created → invite_redeemed → card_liked → match_created → mission_created → memory_completed → paywall_shown → paywall_dismissed → purchase_success / restore_success`. North-star event: `memory_completed`; live pairing diagnostic: `invite_created → invite_redeemed`. Names are ≤40 chars, snake_case (Firebase rule).
- **Website source lives in `site/`** (ilovu.io — landing, privacy, terms, support; imported from the live Netlify deploy 2026-07-18). Deploys via Netlify drag-and-drop of the `site/` folder — edit here, redeploy there. Also holds the Universal Links web side (committed + LIVE 2026-07-19): `invite.html` landing page, `aasa.json` (+ hidden-folder `.well-known/` copy), `_headers`, `_redirects` — see the Invite link decision. **Drag-and-drop skips hidden folders** — that's why the AASA is served from visible `aasa.json` via a `_redirects` 200 rewrite.
- **Two-phone re-test reset:** deleting `couples` + `invites` in Firestore (and `couples/` photos in Storage) is NOT enough — local `@AppStorage` keeps a zombie half-paired state. You MUST **delete + reinstall the app on BOTH phones**. Keep the shared caches (`venues`, `venueQueries`, `eventQueries`, `placeDeckQueries`); only couple data needs clearing.
- Security is day-one, not retrofitted: Firestore rules, single-use invite tokens (7-day server-side expiry + rate-limited redemption since 2026-07-18), photo/Vault access control all built in. Proof photos now live in Cloud Storage (not UserDefaults). **Pre-launch hardening sprint (2026-07-01) ✓** landed cache-write gating, atomic invite redemption, and Storage couple-membership via a `coupleId` auth claim (see the decision section). Remaining: App Check enforcement (#4b, blocked on a parked debug-token 403) + the RevenueCat grant/revoke webhook.

---

## Pricing (locked)

$6.99/mo or $49.99/yr. **One subscription unlocks both partners — never split payment.** Founding offer: $39.99/yr for first 500 users. Push annual. On breakup: subscription follows the payer; both keep their own copy of shared memories.

---

## Current phase

**LAUNCHED — post-launch growth + hardening.** The app is live on the App Store (see CURRENT STATUS at top); the build-out below is the shipped feature inventory, and "Remaining" items are now the post-launch backlog. Top post-launch priorities, in order: **(1)** ship 1.0.2 (Universal Links app half + pairing push client — built + committed; archive once 1.0.1 clears review), **(2)** watch the funnel in Firebase Analytics (`invite_created → invite_redeemed`, `memory_completed`), **(3)** RevenueCat webhook + App Check #4b, **(4)** retention surfaces (memory share-card; widgets are code-staged — see below).

Shipped feature inventory: Auth ✓, invite/couple pairing ✓, real matching ✓, deep link ✓, name sync ✓, **Memory Vault sync ✓** (shared couple photo + proof photos via Firebase Storage; couple doc live-syncs name + photo via a snapshot listener), **paywall ✓** (`PaywallGate` — arms at 2nd match + 1st memory, or a 14-day backstop, never mid-celebration; **hard mode default ON** behind a reversible `hardMode` flag — presents at every calm mission-start + blocks until subscribed; soft show-once restored by flipping the flag — see decision above), **RevenueCat purchase/entitlement ✓** (real `Purchases.shared.purchase`/`restore` + live `premium` entitlement → couple-doc `isPremium` mirror — see decision above), **subscription status + Manage UI ✓** (status + StoreKit `showManageSubscriptions` deep-link in the Us tab; App Store 3.1.2 — see decision above), **Near You ✓** (curated Google Places, deck-cached; **venues now plannable as Missions** — date/time + checklist + partner-sync, with rich venue info (photos/hours/4★+ reviews/maps) on the mission — see decision above), **Push notifications ✓** (all 5 stages; match nudge + manual nudge + scheduled special-date reminders all live, verified on phone — see Push section). **Daily Question sync ✓** (committed `c28201b`, rules deployed, wired in `UsView`; only the on-device two-phone reveal test is outstanding — see decision above). Remaining: verify the RevenueCat **dashboard offering + App Store Connect products** are configured (external, not code — required for a real purchase to complete); the **RevenueCat webhook → Cloud Function** for authoritative grant/revoke (the v1 client-mirror revocation gap); further nudge types (on hold for tone testing); (test functions `runDateRemindersNow` + `helloWorld` both removed ✅); **Cloud Functions hardening sprint ✓** (App Check SDK/monitoring, cache-write gating, atomic invite redemption, Storage couple-membership via `coupleId` claim — all committed + pushed 2026-07-01), leaving **App Check enforcement (#4b)** as the one remaining hardening item (blocked on a parked debug-token 403).

**Events:** **DEPRIORITIZED / pivoted.** Eventbrite is dead (public API removed); Ticketmaster code is built but dormant until we target event-rich markets (London/US). No Facebook Events, no SerpApi. Near You ships on curated Places instead.
**Widgets (CODE STAGED, target pending):** three static widgets (days-together, next-Mission, latest-Memory photo) live in `iLovuWidget/` with the app feeding an App Group snapshot via `WidgetDataWriter` (digest-driven `.task(id:)` in `iLovuApp`; no-ops until the App Group exists, so safe to ship). The **manual Xcode/portal steps** (create `group.com.ilovu.app` App Group + the Widget Extension target) are documented in `iLovuWidget/SETUP.md`. Keep copy WARM, not guilt-tripping.

**Onboarding (SHIPPED, lite):** `OnboardingView.swift` — welcome + concept + name/vibe collection (`@AppStorage`), gated by `hasCompletedOnboarding`. Relationship status is NOT collected there (set later via `CoupleService.setRelationshipStage`); progressive collection of dates after first match/memory stays the design. No spark rating (off-brand).
