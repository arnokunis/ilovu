# CLAUDE.md — iLovu

Project context for Claude Code sessions. Read this first.

---

## CURRENT STATUS (updated 2026-07-30)

**iLovu is LIVE on the App Store** as of ~July 11 2026: https://apps.apple.com/app/id6781237573 — **post-launch phase, NOT pre-launch.** Any "pre-launch" framing below is historical (the hardening sprint etc. happened before launch); read it as done-before-launch, not still-pending-for-launch.

- **⬅ BEFORE THE NEXT SHIP: read "Solo-first funnel fix (PROPOSED)" near the bottom.** A structural alternative to patching the sign-in and pairing leaks one at a time — it attacks the reason both leaks exist (a signed-in user has nowhere to store anything until pairing). Not locked; decide deliberately.
- **⬅ START HERE BEFORE ANYTHING: read "ASA WORLDWIDE + 1.1.0 PLAN (2026-08-11)" near the bottom.** ASA went worldwide 2026-08-08 and blended CPI is now ~€0.50 (the ~€2.6 figure below is OBSOLETE). It carries the worldwide-cohort funnel (sign-in leak 45% → 15%), **four measurement bugs that make current numbers partly fog**, the **`Bool.random()` fake match shipping to production**, proof that **solo users already plan Missions**, the €0.50 unit economics (break-even = 1.3% install→paid, blocked ONLY by the per-couple paywall), and the build plan. **1.0.8 (branch `solo-paywall-1.0.8`) is BUILT**: the paywall is now
reachable solo via two triggers (2nd Mission, and a remotely tunable 20/day swipe cap),
and the `Bool.random()` fake match is deleted. The payments stack was audited end-to-end
and is GREEN — €0 was never a payments bug. It supersedes the sequencing plan below.
- **⬅ ASA ACTION, found 2026-08-11: iLovu is rated 18+, and since 2026-02-24 Apple BLOCKS 18+ downloads in Brazil, Australia and Singapore for un-verified adults** — an install leak that happens BEFORE `first_open`, so it is invisible in GA4 while we buy those storefronts worldwide. See "iLovu IS RATED 18+" under the ASA plan.
- **⬅ DECIDED 2026-08-11: the solo DATING layer is gated, not scheduled** — competitor scan, the guideline 1.2 moderation bill, and four explicit entry gates are in "PARKED — a dating layer for solo users" near the bottom. Two pieces of it (interest tags, fresh-couple question track) were split out as build-now items that need no dating.
- **⬅ ALSO BEFORE THE NEXT BUILD: read "Retention playbook — Flame audit (2026-08-08)" near the bottom.** The daily-question TRIGGER (carrot/stick push) is now a decided build item, plus three iLovu-native retention mechanics and a fresh paired-couple count (3: AU/LT/UK).
- **1.0.6 SUBMITTED (build 11, 2026-07-30) — LATEST; a funnel-fix batch driven by an all-time GA4 read (see ALL-TIME FUNNEL ANALYSIS below).** Attacks the two biggest leaks the data exposed. **Sign-in leak (~45% of installs never sign in):** a "Free to start — signing in never charges you" reassurance line (a real tester feared Apple sign-in would CHARGE her) + a public **Email sign-up/sign-in** alongside Apple (`AppleSignInViewModel.createAccount` / `signInEmail` / `sendPasswordReset`; stable numeric FIRAuthErrorCode mapping; the email sheet forces `.preferredColorScheme(.light)` so placeholders + the segmented toggle aren't white-on-white in dark mode). **Pairing leak (~70% never invite):** a prominent **unpaired-only "invite your partner" card on the Home dashboard** (was buried in the Us tab) — opens the same `PairingView`, vanishes once paired. **Notifications:** the invite REDEEMER is now asked for permission at redeem (only the creator was → redeemers had NO FCM token → zero pushes + the "nudge didn't send" bug); a **Notifications enable/status row in the Us tab** (request / re-register token / open Settings + a confirmation alert); copy now names the special-date reminders and says ONE grant activates ALL push types. **Data-isolation fix:** signing in as a DIFFERENT account (now possible via email) had account B inheriting A's name/missions/memories/couple, because sign-out never cleared the device-local stores — `handleAuthChange` at the app root now resets the in-memory stores + `removePersistentDomain` on a uid change (sign-out itself doesn't wipe, so signing back in as yourself keeps your data). **Fix 1 (explore-before-sign-in) DEFERRED until 1.0.6 stats land** — the structural 45%-leak fix; touches the locked auth-upfront decision, so decide with data, not blind.
- **1.0.5 SHIPPED (build 10, submitted 2026-07-28) — prior release.** The post-1.0.4 Near You polish batch (all found via on-device testing of 1.0.4's new search): **city-search keyboard fix** (the inline `TextField` keyboard shoved the deck layout up and hid the search box → moved to a native `.alert` text field), **popularity ranking** (`curationVersion 3→4` — busier/more-reviewed venues rank higher via a log-scaled capped `popularityBoost`), **all cached venue photos** shown (was 4 of ~10), and **dynamic filter pills** (the always-empty Music pill is gone — pills now derive from categories actually in the deck). App Store "What's New" framed as Near You improvements. Details in the "Near You polish batch" decision. **1.0.4 is live**, so this shipped as a new version (not a build-9 replacement).
- **1.0.4 RELEASED (build 9, 2026-07-28) — prior live version.** Contents: **Near You travel fix** (distance-gated re-anchor >20km, ignores the 12h debounce — fixes "drove 60km, still loading the old town"; `hasFix`-gated so it never anchors to the London fallback), **"Search here" + plan-a-trip city search** (free on-device `CLGeocoder` → shared couple anchor `eventLocationManual`/`eventLocationLabel`, so both partners plan+match a trip destination), **delete a mission** (drops the planned date off both dashboards; `missions` delete opened to couple members in rules — memories stay delete-locked), the **`reached_pairing_screen` analytics event** (splits the download→invite_created leak into "reached pairing" vs "created invite once there"), and the **RevenueCat identity fix** (`Purchases.logIn(uid)` so the `revenueCatWebhook` — deployed 2026-07-27 — can resolve the couple for authoritative grant/revoke). App Store description updated (added the plan-a-trip/city-search lines). **Two-phone test of the Near You search + a sandbox buy/revoke webhook test are the outstanding on-device checks.** Details in the Near You / RevenueCat / Analytics decisions below.
- **1.0.3 RELEASED (build 8, approved 2026-07-22) — prior live version.** The retention/growth batch: memory share-cards, the Would You Rather game (120 prompts), a shared date wishlist, Memory Map + Year-in-Review, Daily Question moved to Home, the deck grown 140→165 + the real 36 Questions content, and **per-category Near You radius (10km going-out / 30km outdoors+trails — fixes the "few hikes" 4km limitation of 1.0.2)**. `curationVersion 2→3` auto-refreshes each couple's deck to the 30km trails search on first open. App Store description updated to match. Details in the "Retention & growth batch" decision below. **Watch `memory_shared` (new viral-loop event) alongside the pairing funnel.**
- **1.0.2 (build 7, 2026-07-20):** shipped Universal Links (pairing fix), home-screen Widgets, and the Hikes & Trails category — but trails searched a flat **4km** radius (few hikes in-city); 1.0.3's 30km radius is the fix. Superseded by 1.0.3.
- **Real users (latest — App Store Connect Acquisition, as of 2026-07-27):** **41 first-time downloads** + **6 redownloads**, **0.8% daily-avg conversion** (impression→download). Up from ~13 at 1.0.1 / ~23 on 2026-07-23. **IMPORTANT attribution:** **~30 of the 41 are Apple Search Ads (PAID)** — so the recent spike is ad-driven, and true ORGANIC installs are only ~11. **Apple Search Ads running on a small budget** (~**€2.6 CPI**, up from ~€2.23). Implication: growth today ≈ ad spend, organic is still a trickle — so **distribution/organic (Product Hunt, backlinks, socials, ASO) is the real bottleneck**, not paid volume. Still small-n for funnel decisions (need ~100+ per step); Product Hunt + ads are the volume plan.
- **Pairing funnel — fix now SHIPPED, watch the data:** the "0 completed pairs" problem (invites generated but never redeemed) was caused by the share message carrying only a dead `ilovu://` link + no install path. 1.0.1 added a store link + typed code; **1.0.2 ships the real fix — Universal Links via `ilovu.io`** (web half AASA + `invite.html` LIVE; app half — applinks entitlement, dual-form parsing, one-link share message — now live in 1.0.2). Pairing push also live (`redeemInvite` → "You're connected 💕"). **DON'T assume it's fixed — verify `invite_created → invite_redeemed` climbs in the funnel over the coming days.**
- **Analytics now VISIBLE:** Firebase Analytics → GA4 (funnel exploration built: `sign_in → invite_created → invite_redeemed → match_created → mission_created → memory_completed`) + **BigQuery export linked** (2026-07-19, daily, going forward only — exact/unsampled numbers once data lands). Was "flying blind"; no longer.
- **North-star metric:** completed dates (memories) per couple per month. Immediate diagnostic to watch: `invite_created → invite_redeemed` conversion.
- **EARLY FUNNEL READ (2026-07-23, n TOO SMALL to decide — directional only):** first stitched funnel (App Store Connect + GA4 + Firestore): ~23 downloads → **7 `invite_created`** → **2 actual pairs** (Firestore `couples` truth). Surprise: the `invite_created → pair` step is ~29% (okay), but **`download → invite_created` is only ~30% — i.e. ~70% of installers never even TRY to pair.** So the biggest leak is likely UPSTREAM of redemption, not the redeem step everyone was watching. **DO NOT act on these rates yet** — at n=23 every % is noise (±~19pp); need ~100 at a step to see shape, ~400 to trust a rate. Plan: let the Product Hunt launch + ads inject volume, THEN read. Low-regret prep meanwhile: add a **"reached pairing screen" analytics event** (not yet built) so the download→invite leak becomes visible; make cheap solo-value / earlier-permission-ask changes blind. Strategic direction if redeems stay low: **solo-first value + no-install web partner participation + unpaired-user push/email nudge** (all attack the same leak; brainstormed, not committed).
- **GA4 GOTCHA (learned 2026-07-23):** GA4 **demographic reports** (Country/City, anything with Google-signals) apply **data thresholding** — low-count events are HIDDEN (e.g. `invite_redeemed` showed 1 in the demographic view when Firestore had 2 real pairs). For any low-volume/critical metric, trust the **Firestore `couples` count or the BigQuery export**, NOT the GA4 demographic exploration. Also: the Country report **mixes the web (ilovu.io) + iOS (app) streams** — filter by **Stream name** to read either cleanly.
- **ENGAGEMENT READ (GA4 Country×Platform, Jul 1–29 2026, n small — directional):** 115 active users, 65% engagement, $0 revenue. The story is a huge **engagement gulf by cohort**: **Lithuania iOS = 8 users at 14m 46s avg (33% of ALL events)** — the founder + close testers; when someone genuinely tries iLovu it's VERY sticky. **US iOS = 29 users (the Apple Search Ads cohort) at just 33s** — paid installs open for half a minute and bounce, almost certainly at/before pairing (33s isn't enough to pair). **That 14m-vs-33s gap IS the €2.6-CPI leak made visible** — paid installs don't reach the "aha." Website rows (US web 33 @ 8s, India/Poland/Germany/Estonia web @ 0–14s) are scattered, low-intent, **0 App Store-click key events** — the site isn't a conversion channel yet (authority-blocked). **Implication: the product is sticky when reached; the whole job is getting new/paid installs to that same aha instead of bouncing — i.e. FIX THE FUNNEL/pairing leak, don't scale spend.** `reached_pairing_screen` (1.0.4) will show if the 33s cohort even reaches pairing.
- **ALL-TIME FUNNEL ANALYSIS (GA4 Data API via analytics MCP, all-time, 2026-07-30 — RAW events, NOT the thresholded explorations):** unique-user funnel = **49 installs → 27 signed in (–45%) → 27 onboarded (0% loss) → 9 created an invite (–67%) → 2 paired.** Three **compounding** leaks: **(1) ~45% never sign in** — biggest + earliest, the locked auth-upfront wall; a real tester feared it would CHARGE her (→ 1.0.6 reassurance + Email login). **(2) ~67% of onboarded never invite** — pairing was buried in the Us tab (→ 1.0.6 Home connect card). **(3) the core swipe→match loop is essentially DEAD** — only **3 users EVER swiped a card, 1 match EVER** (mutual matching needs two partners active at once, which almost never coincides); missions/memories instead happen via **Near You + direct planning**, suggesting the real product is plan-a-date, not card-matching (Fix 4 = a parked strategic question). **Revenue $0, paywall seen by 2 users ever** — and the paywall ONLY ever reaches PAIRED couples (`PaywallGate` is entirely per-couple; its 14-day backstop counts from PAIRING, so **solo users NEVER hit it** — monetization is structurally unvalidated, and can't be validated until pairing works). **Engagement gulf:** 8 Lithuania iOS users = ~75% of all app-engagement time (~16 min avg) vs the US-ad iOS cohort (30 users @ 32s, bounce). **STRATEGY (locked): FIX THE FUNNEL, don't scale spend** — €2.6 CPI is fine, but ~4–8% install→pair + the dead loop make paid deeply unprofitable (~€30/paired couple before any sub). 1.0.6 attacks leaks 1+2 *cheaply/low-regret*; **decide Fix 1 (explore-before-sign-in) and anything rate-based ONLY after volume (~100+/step)**. n still small → treat as hypothesis + big-structural-signal, never precise rates.

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
  answers: { uid: text }, question, dateKey, updatedAt  // each writes ONLY own uid key; answer-to-unlock reveal, passive listener
  // NOTE: `question` is the QUESTION TEXT snapshotted as asked that day (DailyQuestionService.swift:38)
  // — there is NO questionId/index field (this line used to claim one; corrected 2026-08-08).
  // Consequence: the question bank can be grown/reordered/re-themed with ZERO migration.

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
- **HARDENING — RevenueCat webhook ✓ DEPLOYED + LIVE (committed `524d429`, deployed 2026-07-27; only the sandbox buy/revoke test + the rules-lock follow-up remain):** the client-mirror revocation gap (a lapsed sub lingering as `isPremium` until the payer next opened the app) is now backed by an authoritative server path. **`revenueCatWebhook`** (`onRequest` in `functions/index.js`, secret-guarded via the `REVENUECAT_WEBHOOK_SECRET` secret — set + Secret Manager API enabled + compute-SA `secretAccessor` granted at deploy) writes the couple doc on RevenueCat's real events — GRANT on `INITIAL_PURCHASE`/`RENEWAL`/`PRODUCT_CHANGE`/`UNCANCELLATION`/`NON_RENEWING_PURCHASE`, REVOKE on `EXPIRATION`/`SUBSCRIPTION_PAUSED`; `CANCELLATION` (still entitled until period end) + `BILLING_ISSUE` (grace) are deliberate NO-OPs. Revoke only for the recorded `subscriptionOwner`, so a stray event for the non-paying partner can't drop an active couple. Resolves the couple by `app_user_id == Firebase uid` — wired by **`syncRevenueCatIdentity`** (`Purchases.logIn`/`logOut` on auth changes) in `iLovuApp` (previously `Purchases.configure` ran with NO appUserID → anonymous, which is why the webhook couldn't map to a couple before). URL `https://europe-west1-ilovu-b5d87.cloudfunctions.net/revenueCatWebhook`; **RC dashboard webhook is configured** (Both Production+Sandbox, All events, that secret as the `Authorization` header). **Verified live via curl:** no/wrong auth → 401; correct secret + `TEST` → 200 `ignored`; correct secret + `EXPIRATION` for an unknown uid → 200 `no couple`. **DELIBERATELY INCREMENTAL:** the client mirror (`syncPremiumEntitlement`) + the OPEN `isPremium` rule are kept as a belt so a webhook misconfig can't regress purchase-unlock (both agree on grant; the webhook's unique job is the revoke). **REMAINING: (1)** the identity fix ships in the NEXT app build (1.0.4) — a real sandbox `buy → cancel → expire (don't reopen) → couple drops to free` test needs a device build that includes `524d429`; **(2)** AFTER that passes, lock `isPremium` to CF-only in `firestore.rules` (also closes the "a member forges `isPremium=true`" hole).

### Near You — curated Google Places, not events (pivoted, committed 778a857, works on device)
Near You ships as live **curated Google Places** (restaurants, wine bars, cafés by name) via `PlaceCuration.swift` + `NearYouConfig.source = .places` — pivoted away from events because Ticketmaster had no date-appropriate Vilnius events and **Eventbrite removed its public Event Search API** (dead end). The Ticketmaster events path is kept **dormant-but-intact** for event-rich markets (London/US) later.
- **Places 403 fix (locked):** iOS-bundle-restricted Google keys require the `X-Ios-Bundle-Identifier` header on raw `URLSession` Places calls (search), plus a custom `BundledRemoteImage` loader for photos (`AsyncImage` can't send headers). **Do NOT loosen the key restriction to fix a 403** — send the header.
- **Cache cost fixes:** deployed `placeDeckQueries` `firestore.rules` (stops per-open re-billing); fixed `@ServerTimestamp` returning `nil` right after a write (false-stale → re-billing) by reading with `.estimate` `ServerTimestampBehavior` across placeDeck + EventCache + venueQuery. Confirmed on device: **deck HIT (fresh), 0 Places calls** on open.
- **Hikes & Trails category ✓ (`f1e5e44` + curation-version bust, works on device, verified against live Vilnius data):** a first-class `LocalEvent.Category.trails` ("Hikes & Trails" 🥾) with its own Near You filter pill. A dedicated nature search group (`hiking_area, national_park, state_park, park, botanical_garden, garden, wildlife_park, campground` — ALL confirmed valid Table A types; a bad type 400s the whole group) + `typeScores` maps parks/gardens/scenic spots (incl. the primaryTypes Google actually returns — `city_park`, `observation_deck`) to `.trails`. `curate()` was restructured to **map BEFORE the quality gate** so the rating-count floor is per-category (`minRatingCount(for:)`: **10 for `.trails`** vs 30 for eateries — nature spots draw far fewer reviews). **0 schema/cost change**; plannable-as-Mission unchanged (`.trails` → `.adventure` vibe in `DateCard`). Adding a category is a pure dictionary edit; a NEW enum case never orphans cached venues (old rawValues still decode).
- **Curation-version cache bust (locked pattern):** `PlaceCuration.curationVersion` (now **2**) is stamped onto each `placeDeckQueries` doc; `VenueCache.deck()` treats a version mismatch as a MISS and re-resolves synchronously (trails show on the FIRST open, not after a 7-day SWR wait). **Bump this constant whenever curation logic changes** (search groups / mapping / scoring / gates) instead of manually deleting Firestore deck docs — old decks (nil version → 0) auto-refresh once, then carry the version. Field is optional/defaulted so old docs decode.
- **Venues are plannable — full parity with date cards ✓ (two-phone verified):** a Near You venue match → **"Plan This Date"** creates a **Mission** (date/time + checklist), completes into a shared **Memory**, and **syncs to the partner** — the same Match→Mission→Memory loop as cards. A venue is adapted into a `DateCard` via `DateCard(fromVenue:)` (lossy by design — keeps title/emoji/description; defaults difficulty/cost/category), so the Mission/sync/completion chain is **unchanged**. The mission's `deck` is `.places`; the partner rebuilds the card from `VenueCache.venue(forId: placeId)` (mirrors the `.places` MATCH rebuild). All read-only by placeId, **0-bill, NO Firestore schema/sync change**.
- **Rich venue info on a planned venue mission ✓ (Route A, two-phone verified):** the mission shows rating + address inline (`MissionDetailView` looks the venue up read-only by placeId), plus a **"View place details"** sheet that presents `EventDetailView` with **photos, full weekly hours, and 4★+-filtered reviews**, and a **Book Now** that opens the exact place in Google Maps (placeId `googleMapsUri` via `EventLinkBuilder`). The calendar button is hidden here (`showCalendarAction: false` — the mission owns its own schedule). **Photos MUST use `BundledRemoteImage`** (the bundle-key 403 rule above — never `AsyncImage`). All read-only from `VenueCache.venue(forId:)`; no sync/schema touch.
- **Travel fix + "Search here" + plan-a-trip city search ✓ (`f74f69e`, 2026-07-27; BUILT — two-phone test outstanding):** fixes the live-observed "drove 60km, deck still loading the old town" bug and adds trip planning. Root cause: paired couples anchor to ONE shared `eventLocationBucket` (so both fetch the same deck + swipes line up for matching), and a **12h re-anchor debounce** (`reanchorDebounce`) meant genuine travel didn't update Near You for 12h.
  - **Distance-gated re-anchor:** `resolveBucket()` in `NearYouView` now re-anchors IMMEDIATELY when the device is **> `travelReanchorKm` (20 km)** from the stored bucket (`kmBetween` via `CLLocation.distance`), ignoring the debounce; the 12h debounce is kept ONLY for sub-threshold jitter so co-located partners don't ping-pong. Re-anchor now also requires a real fix (`locationManager.hasFix`) so the couple never anchors to the `.london` fallback, and a new `.onChange(of: hasFix)` reload bootstraps the true location on the first fix instead of waiting a session.
  - **Two new couple-doc fields (`Couple.swift`, optional/backward-compatible, NO rules change — couples-update already permits them):** `eventLocationManual: Bool?` + `eventLocationLabel: String?`. `CoupleService.setEventLocation(bucket:manual:label:)` writes them (`FieldValue.delete()` clears the label in auto mode); accessors `eventLocationManual` / `eventLocationLabel`.
  - **"Search here"** force-anchors both partners to the current GPS spot and returns to auto-follow (`manual:false`). **City search** (paired-only `locationBar`) geocodes a typed city via **free on-device `CLGeocoder`** → `LocationBucket` → sets it as the SHARED anchor with `manual:true` + a human label (e.g. "Palanga"), so BOTH partners' decks move there and swipes match for the trip. A manual pin is NEVER auto-overridden by GPS; a **"📍 {label} · Use my location"** chip clears it. `reloadDeckForced()` resets the swipe session on any location change (unlike `reloadIfUntouched`). Bar is hidden solo (a solo deck already follows live GPS).
- **Near You polish batch ✓ (SHIPPED in 1.0.5, build 10, 2026-07-28):** four on-device-found refinements. **(1) City search → native alert** (`f9f15f5`): the inline `TextField`'s keyboard shoved the whole deck VStack up and hid the search box even with `.ignoresSafeArea(.keyboard)` (the TabView/NavigationStack re-applied the inset); the "Plan a trip — search a city" pill now opens a system `.alert` text field, whose keyboard can't move the underlying layout. **(2) Popularity ranking** (`753eaf6`, `curationVersion 3→4`): review count was only a quality GATE (`minRatingCount`), never a ranking signal, so a 4k-review buzzy spot didn't outrank a 40-review one; added a log-scaled, capped `popularityBoost(count)` to the score (30→1, 100→2, 1k→3, 10k+→4 — the closest proxy Google gives for "what's hot / TikTok-famous"), capped so volume can't bury a quiet high-rated gem (a 4.0/20k place only TIES a 4.8/60 gem; rating breaks the tie). **(3) All venue photos** (`542cbc8`→`d6f491e`): the detail carousel was capped at 4 of the ~10 photos Google returns + we cache; now shows all (`photoURLStrings(limit: .max)`) — each rendered photo is one cached-after Photo request. **(4) Dynamic filter pills** (`d6f491e`): the hardcoded **Music** pill was always empty (Places curation never maps `.music` — that's an events-only category, and events are dormant); pills are now derived from the categories actually present in the loaded deck (`availableCategories`), killing Music + any empty-category filter, with a guard that resets a selected filter the new deck can't satisfy (e.g. after a city search).
- **Events / concerts API research (2026-07-28, for market expansion — NOT a now-build):** getting concerts into the **Music** filter needs a location-based events source, and there's **no cheap universal one that covers the Vilnius launch market**. Ranked for iLovu: **Ticketmaster Discovery** (already integrated, FREE, one-line `NearYouConfig.source` flip — but ~zero Lithuania coverage; lights up Music in London/US/Western-EU); **Bandsintown** (best global *touring-artist* concert coverage incl. Lithuania, BUT its free API is ARTIST-centric — no open "near me" endpoint; location discovery is partner-gated + needs scale we don't have, and it'd be a from-scratch integration); **PredictHQ** (truly global aggregator, but PAID/enterprise). DEAD ends: Eventbrite (search API removed), Facebook Events (API killed), Songkick (public API discontinued), Google Events (no API). CTS Eventim has EU/Eastern-EU inventory but no open API. **Decision: venue-first (Places) everywhere now; flip Ticketmaster to `.both` when expanding to a covered market; revisit Bandsintown only if concerts become a priority AND we qualify for partner access.**

### Daily Questions — couple-synced ✓ (COMMITTED + rules deployed; only a two-phone smoke test outstanding)
~130 `ConnectionQuestions` with day-rotation + reveal UI already existed as a stub, but answers saved only to local `@AppStorage` and "waiting for partner" was hardcoded fake. Now real-synced via `DailyQuestionService` + `DailyAnswerDoc`: subcollection-per-day, **answer-to-unlock** reveal (you see your partner's answer only after you answer too), passive Firestore listener (no push). `dailyAnswers` `firestore.rules` are couple-scoped, write-your-own-uid-key only. **Committed `c28201b` ("Wire real couple sync for the Daily Question") + rules deployed; wired end-to-end** — `DailyQuestionService` injected at the app root (`iLovuApp`), `DailyQuestionCard` presented in `UsView` (passes `nil`/`isOrphaned` for unpaired & orphaned couples → local `@AppStorage` fallback). Only the on-device **two-phone reveal smoke test** is still unchecked (needs two Apple IDs; not a code gap).
- **Partner-answered push ✓ (DEPLOYED + committed `fe140b9`, 2026-07-19):** new `onDailyAnswer` Cloud Function (`onDocumentWritten` on `couples/{id}/dailyAnswers/{dateKey}`) pushes the partner of whoever just answered — a **nudge-to-unlock** on the first answer ("[Name] answered today's question 💬 / Answer to see theirs 💕") and a **reveal** ping to the first answerer when the pair completes ("[Name] answered too 💬 / Tap to see what they said 💕"). Fires only on a genuinely NEW answer key (diffs before/after → edits & updatedAt-only writes don't re-nudge), skips orphaned/no-token/half-paired couples, reuses the `onMatchCreated` send path + stale-token cleanup, needs NO new IAM role (Firestore read/write, `datastore.user` already granted) and **NO client change** (reuses existing `fcmTokens` + match-time permission). **BRAND softening (noted deliberately):** the card's original "anti-pressure, NO notifications" stance banned *guilt/nagging* pings — this is the warm, partner-framed kind (same tone as the match nudge), which the user green-lit. **Live in europe-west1; only a two-phone reveal test remains.**

### Retention & growth batch (SHIPPED in 1.0.3, build 8 — LIVE on the App Store)

The engagement/content layer added after 1.0.2 — **now LIVE as part of 1.0.3** (build 8, current App Store version). All on `origin/main`. The reusable `ShareSheet` (UIViewControllerRepresentable) lives in `MemoryShareCard.swift` and is shared by both share features.

- **Memory share-cards ✓ (`3bb921a`, on-device VERIFIED):** "Share this memory" in `MemoryDetailView` renders a 9:16 branded card (`MemoryShareCard` via `ImageRenderer` → PNG → native `ShareSheet`) from a completed Memory — proof photo + "Our Nth date" + days-together + iLovu wordmark. Reads the Vault only, no backend. New **canonical `memory_shared`** analytics event (top of the viral loop; registered in `AnalyticsService`). Coral-gradient fallback when the photo isn't local yet.
- **Would You Rather game ✓ (`f22ecc9`; 120 prompts `1087e98`):** daily A/B couple game on the Home dashboard. **Reuses the Daily Question reveal mechanic 1:1** — `WouldYouRatherService` syncs `couples/{id}/games/{dateKey}` (uid-keyed `choices` map; own-key-only rule mirroring dailyAnswers, **rules DEPLOYED**); the self-contained `WouldYouRatherCard` owns its own listener (NO MainTabView wiring, like DailyQuestionCard); 120 prompts in `WouldYouRatherPrompts` rotated by day-of-year. Reveal = "in sync 💕 / opposites attract 😄". Follow-ons (weekly quizzes, "Guess My Answer") can reuse this exact engine.
- **Shared date wishlist (bucket list) ✓ (`5e3032f`):** couples add / tick-off / DELETE custom date ideas (kills "swiped everything" churn). `BucketListItem` + `BucketListService` + `BucketListStore` mirror the Mission/Memory Service+Store pattern (local @Observable + UserDefaults, remote sinks at the app root, listener in MainTabView, `resyncAll()` on pair). `couples/{id}/bucketList` rule is couple-scoped **with delete allowed** (unlike missions/memories; **DEPLOYED**). "Date Wishlist" row → `BucketListView` sheet in the Us tab.
- **Memory Map + Year-in-Review ✓ (`d533391`):** `Memory` gained optional `latitude`/`longitude` — threaded through ALL 3 `MemoryStore` reconstructions (markSynced/replacePhoto/mergeFromRemote — else location drops on sync), `RemoteMemory` + `saveMemory`, and `MainTabView.applyRemoteMemory` (backward-compatible; old memories decode nil = no pin). **Capture gotcha:** `LocationManager.coordinate` falls back to London, so a new `LocationManager.hasFix` flag gates it — `CompleteMissionSheet` stamps the real device coordinate at completion ONLY when `hasFix` (never the fallback; no new prompt — reuses Near You's already-granted permission). `MemoryMapView` = MapKit pins (`Map(initialPosition: .automatic)`) → tap opens the memory. `YearInReview` = shareable 9:16 recap (dates this year, days together, the year's emoji) reusing the share-card render path. Both from new Us-tab rows (shown once ≥1 memory exists). **No rules change** (memories rule already covers new fields).
- **Daily Question moved to Home (`0179236`, `f22ecc9`):** was buried in the Us tab; now on the Home dashboard, ordered greeting → spark-this-month → Daily Question → Would You Rather. Clean split: **Home = daily-action dashboard, Us = relationship hub** (story, wishlist, map, year-in-review, memories, subscription, settings). Don't move it back without reason.
- **Deck 140 → 165 + real 36 Questions (`c2692a5`, `2dec312`):** +25 curated, psychology-grounded cards (awe/novelty/vulnerability/prosocial — Aron self-expansion + arousal, Keltner awe), deliberately NON-overlapping the existing 140 (bulk-padding near-duplicates was rejected — quality over volume). Fixed the dead-promise "36 Questions" / "Closeness Questions" cards, which described Aron's exercise but never contained it: `ThirtySixQuestions` (full 3-set list) + a viewer sheet, surfaced via a "See the 36 questions →" button in `DateCardDetailView` (shown only for cardIds in `ThirtySixQuestions.cardIds`).
- **Per-category Near You radius (`5b19934`, curationVersion 2→3):** `PlaceCuration.searchGroups` are now `SearchGroup(types:radiusMeters:)` — 10 km for going-out (food/nightlife/arts), 30 km for outdoors + Hikes & Trails (day-trip intent; trails sit beyond the urban core). Cost-neutral (cached per bucket); existing decks auto-refresh via the curation-version bump. See the Near You decision.

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
- **Remaining — #4b flip App Check enforcement:** enable enforcement (console) for Firestore + Storage + Functions. **Blocked on a parked dev-build App Check debug-token 403** (harmless in monitoring; a hard block under enforcement) — resolve it and confirm a clean verified exchange on both phones FIRST. Widest blast radius (every Firebase call at once); do it in a dedicated session. Also still open: the RevenueCat webhook (grant/revoke) is now DEPLOYED + LIVE (auth-verified) — only the on-device sandbox buy/revoke test (needs a 1.0.4 build with the identity fix) + the `isPremium` rules-lock follow-up remain (see the RevenueCat decision); gating `events/{eventId}`; and the full server-side Places fetch.

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
- **Analytics go through `AppAnalytics` (`AnalyticsService.swift`) — the single Firebase Analytics choke point.** Named `AppAnalytics` (not `Analytics`) to avoid clashing with FirebaseAnalytics' own type. Log ONLY the canonical funnel names — don't invent variants: `sign_in → onboarding_complete → reached_pairing_screen → invite_created → invite_redeemed → card_liked → match_created → mission_created → memory_completed → paywall_shown → paywall_dismissed → purchase_success / restore_success`, plus `memory_shared` (viral loop). North-star event: `memory_completed`; live pairing diagnostic: `invite_created → invite_redeemed`. **Engagement events (added 2026-07-31 — measure what couples DO inside, beyond the acquisition funnel; the funnel alone couldn't answer "what do couples do most" because screens aren't tracked + features fired nothing):** `near_you_opened` (the plan-a-date surface — directly tests the matching-vs-planning strategic question), `daily_question_answered`, `would_you_rather_answered`, `bucket_list_added`, `memory_viewed`. On `main`, NOT in the submitted 1.0.6 build 11 — ship in the next build. `reached_pairing_screen` (added 2026-07-28, `PairingView`, fired once when an UNPAIRED user lands on the invite/redeem UI) decomposes the biggest funnel leak — `download → invite_created` (~70% never try to pair) — into `onboarding_complete → reached_pairing_screen` (never navigate to pairing) vs `reached_pairing_screen → invite_created` (there, but create no invite). Names are ≤40 chars, snake_case (Firebase rule).
- **Website source lives in `site/`** (ilovu.io — landing, privacy, terms, support; imported from the live Netlify deploy 2026-07-18). **Deploys via Netlify GIT continuous deploy (2026-07-23): push to `main` → auto-deploy of `site/` in ~60s.** `netlify.toml` at repo root sets `publish = "site"` (no build step). The old drag-and-drop flow is retired — **edit `site/`, commit, push, done.** Because Git deploy INCLUDES hidden folders (unlike drag-and-drop), `site/.well-known/apple-app-site-association` now serves natively too — the `aasa.json` + `_redirects` rewrite still coexists as a second path (belt-and-suspenders; both verified 200 live). Also holds the Universal Links web side (committed + LIVE 2026-07-19): `invite.html` landing page, `aasa.json` (+ `.well-known/` copy), `_headers`, `_redirects` — see the Invite link decision. See the **SEO/GEO content cluster** decision below for the 25 content pages.
- **Web analytics — GA4 LIVE on all site pages (2026-07-23):** GA4 web stream `G-BY93CRYSZK` (property = the SAME Firebase-linked GA4 property the iOS app reports to; it's a second data stream, NOT a new property). The gtag snippet sits right after `<head>` on every site page AND is baked into `scripts/gen_pages.py` (braces doubled for the f-string) so regenerated cluster pages keep it — any NEW hand-authored page must add the snippet manually (as `love-counter` does). Enhanced Measurement auto-captures **outbound App Store CTA clicks** (`click` event) — the key web conversion to mark as a key event + later import into Google Ads. **GDPR note:** no consent banner yet (low risk at current traffic; revisit with a banner or Consent Mode v2 before scaling EU paid). When building a web-only report, filter to **Stream name = ilovu.io** so app events don't muddy it.

### SEO / GEO content cluster (`site/`, deploy = `git push` (Netlify Git CD); keyword-data-driven since 2026-07-23)
Web growth channel: rank for "date ideas" (+ long-tail) and get cited by AI answer engines (Generative Engine Optimization). **30 content pages** live in `site/` forming one topic cluster around `/date-ideas` (the pillar/hub, which links to every child). Base 24: `date-night`, `romantic`, `date-ideas-at-home`, `cheap-date-ideas`, `outdoor`, `first-date`, `fun`, `cute`, `unique`, `adventurous`, `foodie`, `creative`, `rainy-day`, `winter`, `summer`, `autumn`, `weekend`, `anniversary`, `date-ideas-for-married-couples`, `double-date`, `long-distance`, `36-questions`, `would-you-rather-couples`, `questions-to-ask-your-partner`.
- **Keyword-Planner re-audit (2026-07-23) → 5 new product-aligned pages added.** A real Google Keyword Planner export (couples/date niche) reprioritized the roadmap toward keywords that map to features iLovu ALREADY has (higher install intent than generic listicles). Added: `couple-games` (the `couple games`/`games for couples`/`questions for a couple game` cluster ~50k/mo → maps to Would You Rather + 36 Questions + Daily Question), `picnic-date-ideas` (`picnic date ideas` **18,100/mo, competition index 11** — near-free win), `coffee-date-ideas` (5,400/mo), `second-date-ideas` (5,400/mo), and **`love-counter`** — an INTERACTIVE tool page (enter start date → live days/weeks/months/years + next milestone) targeting `love counter` 6,600/mo + `relationship counter/tracker`, CTAing to the app's **Days Together widget**; carries a `WebApplication` JSON-LD on top of Article+FAQ. **Strategic shift (locked):** weight new SEO toward product-aligned terms (games, love-counter, app-feature) over generic "date ideas" where the domain competes with everyone. Deprioritize low-volume base pages (`weekend`, `adventurous`, `creative`) — keep, don't invest. Full audit + volumes are in this session's history.
- **GENERATED (most), some hand-written:** `scripts/gen_pages.py` (NOT deployed — only `site/` ships) holds the f-string template + a `PAGES` data table (curated ideas per theme, drawn from the 165-card deck) and writes the cluster `.html` files incl. the 4 new listicle pages. Edit the data + re-run `python3 scripts/gen_pages.py` to regenerate. The pillar, `36-questions`, `date-ideas-at-home/cheap/outdoor/first-date`, `would-you-rather`, and **`love-counter`** (has interactive JS) are hand-authored standalone HTML (not in the generator); all share `site/assets/site.css` (CSS vars `--coral/--rose/--ink/--gradient`).
- **Every page:** unique title/meta/canonical + H1, a direct-answer lead, and **Article + FAQPage + ItemList JSON-LD** (love-counter swaps ItemList for `WebApplication`) — the FAQ schema is the GEO win (what ChatGPT/Perplexity/Google AI Overviews extract to cite). Plus internal cross-links + App Store CTA. `robots.txt` + `sitemap.xml` (33 URLs) present; homepage has `MobileApplication` + `WebSite` JSON-LD. **GA4 `G-BY93CRYSZK` on every page** (see Web analytics bullet).
- **Clean URLs:** files are `slug.html`; Netlify serves them at `/slug` (canonical uses the clean form).
- **Search Console + Bing verified** (domain property, DNS TXT via Netlify), sitemap submitted. After adding pages: resubmit sitemap + Request-Indexing the highest-intent new URLs (`/couple-games`, `/love-counter`). **Honest status (unchanged): content is a compounding long-game — it won't rank at zero domain authority without backlinks** (Product Hunt launch + "best couples apps" listicles + Reddit are the highest-ROI moves). Better keyword targeting raises the ceiling; it does NOT remove the authority requirement. Watch GSC impressions before scaling to per-card pages (phase 2, in batches — do NOT bulk-dump; new-domain crawl/spam risk).
- **Two-phone re-test reset:** deleting `couples` + `invites` in Firestore (and `couples/` photos in Storage) is NOT enough — local `@AppStorage` keeps a zombie half-paired state. You MUST **delete + reinstall the app on BOTH phones**. Keep the shared caches (`venues`, `venueQueries`, `eventQueries`, `placeDeckQueries`); only couple data needs clearing.
- Security is day-one, not retrofitted: Firestore rules, single-use invite tokens (7-day server-side expiry + rate-limited redemption since 2026-07-18), photo/Vault access control all built in. Proof photos now live in Cloud Storage (not UserDefaults). **Pre-launch hardening sprint (2026-07-01) ✓** landed cache-write gating, atomic invite redemption, and Storage couple-membership via a `coupleId` auth claim (see the decision section). Remaining: App Check enforcement (#4b, blocked on a parked debug-token 403) + the RevenueCat grant/revoke webhook.

---

## Solo-first funnel fix (PROPOSED — NOT locked; decide before the next ship)

Raised 2026-08-03. **Nothing here is implemented.** This is a structural alternative to
patching the sign-in and pairing leaks individually — it attacks the reason both exist.

### The root cause

**The couple doc is born at redemption.** `functions/index.js:191` — `db.collection("couples").doc()` inside the `redeemInvite` transaction. Every subcollection lives under `couples/{id}/`: swipes, matches, missions, memories, bucketList. **So before pairing, a signed-in user has nowhere to put anything.** That is not a UX gap; the data model has no concept of one person.

Three consequences, all visible in the all-time funnel:
- **27 users onboarded into an app with no storage for them.** The 67% invite leak is partly this — there is nothing to do first, so the invite is a cold ask with no motivation behind it.
- **The swipe→match loop requires coincidence.** Mutual `likedBy` means both partners must be active on the same card. 3 users have ever swiped, 1 match ever. It is not a UI problem — it is a synchronisation requirement.
- **Monetization is structurally unreachable.** `PaywallGate` is entirely per-couple and its 14-day backstop counts from PAIRING, so a solo user never sees it at any duration. 2 users have seen the paywall, ever. **Revenue is not underperforming, it is unmeasured.**

Also worth noting: **"love counter" is the #1 converting Apple Search Ads keyword, and Days Together needs no partner at all.** The best-converting promise is currently gated behind a step 96% never complete.

### The proposal — a couple of one

**Create the couple doc at sign-in with `members: [uid]`.** Pairing stops creating and starts appending.

**This is cheaper than it sounds because `isCoupleMember(coupleId)` is just `uid() in members` (`firestore.rules:21`) — a one-member couple already satisfies every existing rule.** Missions, memories, bucketList, Daily Question all work unchanged. `firestore.rules` needs no rewrite for the happy path.

Three real changes:
1. **Create-on-sign-in** instead of create-on-redeem. Note the couple doc is currently Cloud-Function-only by rule (`allow create: if false` for clients) — so this stays server-side, called at first sign-in.
2. **A like becomes a mission directly** when `members.count == 1`, instead of waiting for mutual `likedBy`.
3. **`redeemInvite` merges instead of creates.**

**The merge is the only genuinely hard part.** Two users who both explored solo have two couple docs — pick a survivor (inviter's) and copy the redeemer's subcollections inside the transaction. In practice most redeemers install FROM the invite and have nothing to merge; the collision is the rare case, not the common one. Do not ship this without deciding the merge rule explicitly — silently dropping a redeemer's missions is the kind of bug that surfaces as a 1-star review.

### The swipe survives — it stops being a gate

Keep the mechanic, change its job: **swiping builds YOUR shortlist.** When a partner joins, cards both liked light up as matches. The match moment — which the SpyTok briefing ranks as the #1 marketing angle — survives as a bonus on top of something already working, rather than the toll gate in front of it.

This also resolves the parked Fix 4 question ("is the real product plan-a-date, not card-matching?") without having to answer it: both work, and the data says which one people use.

### Invite from the mission, carrying the plan

**Send the invite from the mission window, not from a generic pairing screen.** Today the invite is "install my app" — abstract, no urgency, which is plausibly why 67% of onboarded users never send one. From a mission it is "I want to take you to this on Saturday." Specific, warm, and the recipient sees a date plan rather than a product pitch.

**Then make `site/invite.html` render the actual mission.** It currently shows a generic "You're invited" headline and an App Store button. If it showed the real plan — venue, date, who planned it — the partner sees something concrete before installing.

**This also attacks a separate problem: GA4 records ZERO App Store click key events from ilovu.io, ever.** `invite.html` is the one page on the site with genuine intent behind it. Making it the conversion page is likely worth more than the whole SEO cluster in the short run.

Sequence after this change: plan alone → partner opens a link and sees a date someone made for them → installs → the plan is already there. **The app has delivered before the second person did anything.**

### Paywall — sequence matters more than the setting

**Do NOT ship solo access and a hard 14-day wall in the same release.** At ~50 lifetime installs there is no resolution to untangle which one moved the number, and this file already says repeatedly that n<100/step is noise. Make the paywall REACHABLE first — that alone takes it from 2 users ever to everyone — read the rate, then decide hard vs soft.

**And reconsider what it gates.** A hard wall at day 14 from sign-in lands on the ~96% who never paired — people who have not seen what they would be paying for. The engagement gulf says the paid US cohort is gone in 33s and the people who DO reach value stay ~16 min, so the wall mostly blocks the engaged minority, which is exactly who you least want to block. **Gate depth, not access** — N active missions, or Near You past the free radius. Keep the hard 14-day wall for PAIRED couples, where the current backstop already applies and value has been reached.

### Honest limits

- **Solo value buys time and a better invite; it does not remove the need to pair.** A user planning dates for a partner who never joins has a to-do list, and retention dies there regardless.
- **This does not fix revenue this quarter.** See `~/ilovu-content/NINETY-DAYS.md` — it makes revenue *measurable*, which is the actual blocker.
- **Not decided here:** the merge rule, whether solo users get Near You at full radius, and whether "invite several people so one redeems" is worth building (cheap, sensible) versus multi-person plans (a couples app becoming a group app — `members` is a pair and the paywall is per-couple; much bigger, separate question).

---

### Fix 1 build plan — explore-before-sign-in + solo-first (READY to execute IF 1.0.6 leaves install→sign_in still ~45%)

Concrete execution plan for the 45%-leak fix (drafted 2026-08-06). **Reverses the locked "auth upfront / durable accounts from the start" decision — deliberate, decide with 1.0.6 data.** Two halves: PHASE A (explore before auth — the leak fix) + PHASE B (solo-first storage — so there's somewhere to save). Ships as **1.0.7**. Effort ~2–3 weeks.

**PHASE A — explore before sign-in (the leak fix):**
1. **Routing (`ContentView`):** signed-out no longer forces `SignInView`. Route signed-out → a GUEST swipe deck (`SampleCards` — static/local, no backend, no auth). `SignInView` becomes a gated full-screen cover, not the front door.
2. **Local pre-auth swipes:** guest likes/shortlist store LOCALLY only (UserDefaults) — no `MatchService`/Firestore (those need auth). Reuse the existing unpaired-local pattern (`MissionStore`/`MemoryStore` already persist locally when unpaired).
3. **Sign-in prompt at first VALUE-CAPTURE, not upfront:** present `SignInView` when the guest taps "Save these / Plan this date / Invite your partner." Value-framed copy ("Sign in to save + plan together — free, never charges you" — the fiancée-fear fix, now at a motivated moment).
4. **Migrate on sign-in:** guest's local likes → missions on the couple-of-one doc (Phase B). Reuse the resync-on-pair migration pattern.
5. **Analytics:** add the pre-auth funnel — `guest_swipe` + `signin_prompt_shown` → existing `sign_in`, so guest→sign_in becomes the new measurable top. Also add an **`is_paired` user property** so solo-vs-paired engagement is finally segmentable.

**PHASE B — solo-first storage (couple-of-one):**
6. **Create `couples/{id}` with `members:[uid]` at first sign-in** (server-side — couple-create is CF-only by rule). `isCoupleMember` already = `uid in members`, so a one-member couple satisfies EVERY existing rule — missions/memories/bucketList/dailyAnswers work unchanged.
7. **Like→mission direct when `members.count == 1`** (skip the mutual-match requirement). Swipe mechanic stays; it just stops being a two-person gate.
8. **`redeemInvite` MERGES two solo docs** instead of creating (survivor = inviter's; copy the redeemer's subcollections in the transaction). **THE HARD PART — decide the merge rule explicitly** (never silently drop the redeemer's missions). Most redeemers install FROM the invite and have nothing to merge; collision is the rare case, not the common one.
9. **Invite FROM the mission carrying the plan;** make `site/invite.html` render the actual mission (venue/date/who planned) — the partner sees a real date before installing.

**STAYS gated (sign-in required):** Near You "Plan This Date", memories/Vault, pairing, subscription.

**GOTCHAS:** (a) App Store review is fine with delayed auth (a memories app that lets you try first is common). (b) The MERGE is the only genuinely hard bit — ship an explicit rule + test the collision case. (c) **Do NOT add a hard paywall in this release** — make it reachable, read the rate, gate on usage in 1.0.8 (see below). (d) One lever per release — don't ship this WITH the usage-cap paywall.

**EVIDENCE it's worth building (2026-08-06 GA4):** ~28 of 34 signed-in users are solo; `mission_created` (9 users) >> `match_created` (3 users) means ~6 users planned a date solo/independently — solo users DO engage with planning before solo-first even exists. Encouraging, not conclusive (GA4 can't cleanly segment solo vs paired yet — hence the `is_paired` property above).

### Paywall trigger — tie it to usage, not to pairing (PROPOSED, 2026-08-03)

The core of it: **stop gating the paywall behind a milestone and gate it behind use.** Whatever lever is chosen, that is the change that makes monetization reachable at all.

**A swipe cap, Tinder-style, is the obvious candidate — and it has a hard prerequisite.** Swipes live at `couples/{coupleId}/swipes/{cardId}` and the rules scope them with `isCoupleMember`. **A solo user cannot swipe at all today**, so a swipe cap would apply to paired couples only, of which there are two. **This cannot ship before the couple-of-one change above.** The order is forced, not a preference.

**If it does ship, the cap number is the whole design.** Set it above casual use and below engaged use; the funnel gives both bounds:

- median user: **0 swipes**
- the Peterborough/Bradwell pair, 2026-07-31: **25 and 21** in one session, 46 together

So **30-40/day** is never seen by a casual user and would have caught that couple on night one — asking exactly the people who have experienced the product, while adding no friction to a funnel already losing 45% at sign-in and 67% at invite. **A cap of 10 hits everyone and makes a nearly-dead loop deader.** Tinder's cap works because swiping IS the product with infinite supply; here swiping is a means to a plan, so capping it caps value delivery rather than a vanity metric.

**The alternative — cap active missions instead — is probably the better long-run lever.** For a date planner the plan is the value, not the swipe. "Two active missions free" maps to what someone actually received, converts later but warmer, and composes naturally with solo-first. The tradeoff is speed: swipes produce paywall exposure in a week, missions in a month. Given that **2 users have seen the paywall ever**, speed is worth a lot right now.

**Do both eventually; swipes first, because the data gap is the binding constraint.**

### Sequencing — the thing most likely to go wrong

Three changes are now on the table: solo-first, the 14-day trial, and a usage cap. **Shipping any two together at ~50 installs means learning nothing about either.** This file already says n<100/step is noise; that applies to our own releases, not just to the funnel.

    1.0.7   solo-first — makes the paywall REACHABLE (2 users have seen it, ever)
    1.0.8   usage cap  — makes it FIRE on engagement
    1.0.9   hard/soft, trial length — tune, once there is a rate to tune

**Whether to wait for 1.0.6 numbers before starting depends on a fact we do not have yet: is Apple Search Ads still spending?** Installs fell from ~7/day (Jul 28-29) to ~1.75/day (Jul 31-Aug 3), and 1.0.6 has **4 users total, 3 of them new installs**. If spend resumed, ~50-60 installs by early September makes the sign-in leak readable and it is worth waiting. If spend stopped, waiting buys nothing and the wait is pure delay.

**Either way, start building now** — solo-first is 3-4 weeks of careful work (server-side couple creation, like→mission, and a `redeemInvite` that merges rather than creates). The ASA answer changes when it ships, not whether to begin.

---

## Retention — the Flame parallel (RAISED 2026-08-08, decide before the next release)

**Flame's first product was a date-planning app for couples. It got 0.8% day-30 retention
and they abandoned the model to survive.** Their founder's diagnosis, in his words: it was
"a tool similar to Airbnb — you book an event, but you don't come back unless you need the
next one." Same category, same mechanic, same market as iLovu.

What rescued them was **not better date planning**. It was making a **daily question** the
mainstay of the product: 0.8% -> 4.2% -> 30% -> 50% day-30 retention, above TikTok's ~40%
and Instagram's ~35%. It took eight months of iterating on that one feature.

**iLovu already has a Daily Question.** It is a card on Home, not the reason to open the
app. The reason to open the app is currently planning a date — which is the thing that
returned 0.8% for them.

**The mechanics that did the work, and they are specific:**
- Every retention event tied to a **trigger** (BJ Fogg's habit-formation work).
- A **carrot and a stick** notification each day — but the stick was NOT "you will lose
  your streak". It was **"your partner will be sad."** The obligation is to a person, not
  to a number. That is the part they credit for beating TikTok, and it is only available
  to a two-sided product.
- A **missing-out lock**: you cannot see your partner's answer until you answer your own.
  Each answer pulls the other person back, which compounds.
- **Widgets** as a re-engagement surface — big, dynamic, unavoidable on the home screen.
  iLovu already ships three (Days Together, Next Date, Latest Memory) and deliberately
  leaves them un-gated, which matches what Flame found.

**Why this matters more than the funnel fixes already queued.** The solo-first change
above makes the paywall REACHABLE; it does not give anyone a reason to open the app
tomorrow. Retention and monetization are separate problems and this file currently has a
plan for only one of them. A 50%-D30 product with 49 installs is a business; a 4%-D30
product with 10,000 installs is a leaking bucket.

**Correction to the list above — the missing-out lock is ALREADY BUILT.** `DailyQuestionService`
has shipped answer-to-unlock since `c28201b` (you see your partner's answer only after you
answer). Don't re-scope it as new work. Of Flame's four mechanics iLovu has three; the one
genuinely missing is the trigger.

### DECIDED 2026-08-08 (founder call) — BUILD the daily-question trigger

**Reverses the "skip the carrot/stick, it's Flame's mechanic not ours" recommendation
made earlier the same day.** The founder and his partner use the Daily Question *every
day* — it is the only feature with directly observed daily pull, and it is the plausible
explanation for the Lithuania cohort's ~16-min sessions vs the US ad cohort's 33s. That
outweighs the strategic worry, which was never that the feature is wrong but that
*leading* with it drifts iLovu into the crowded prompt-app lane (Paired, Couple Joy).
Resolution: build it, and keep it **feeding the proof loop rather than standing alone**
(answers surface as date suggestions / seed the wishlist), so the daily habit routes into
`memory_completed` instead of replacing it. Daily question = the *trigger*; the completed
date stays the *value*. Positioning stays "one real date a month," unchanged.

**THE ACTUAL CODE GAP — there is no trigger at all today.** The only daily-question push
is `onDailyAnswer` (`functions/index.js:592`), which fires **only when the partner has
already answered**. If neither person opens the app, nobody is ever notified — the loop
can only be started by someone who was already coming back on their own, which is the
exact inverse of a retention trigger. Fogg's formula is motivation x ability x TRIGGER;
iLovu has the first two and a hard zero on the third.

**Build shape (cheap — copy an existing function, no new architecture):** a
`sendDailyQuestionNudge` scheduled function modelled on `sendDateReminders`
(`functions/index.js:970`) — already a working `onSchedule` cron with FCM send path,
`remindersSent` dedupe stamps and stale-token cleanup. Morning carrot ("today's question
is live"), evening stick for the unanswered — **partner-framed, never self-framed**
("Inesa answered. She's waiting on you 💛" is on-brand; "don't break your streak" is not).
**Blocker to respect: `REMINDER_TZ` is single-zone `Europe/Vilnius`** — shipping this
before per-couple timezone pings the US/AU cohort at ~3am local. Fix the tz first.

**Sequencing caveat:** the Daily Question is per-couple (unpaired falls back to local
`@AppStorage`, and `onDailyAnswer` skips half-paired couples), so a perfect trigger today
reaches **3 couples**. Either ship it with/after solo-first, or make the solo daily
question real — answer alone, revealed to the partner when they join, which doubles as a
reason to invite. Build solo-first so `fcmTokens[uid]` and a real `dailyAnswers` path
exist on a couple-of-one, or this becomes a data migration instead of a cron job.

### iLovu-native retention mechanics (ranked; the parts Flame structurally cannot copy)

Flame's core value event is daily (answer a prompt). iLovu's north star is monthly
(`memory_completed`). Importing a *daily* streak wholesale would optimise daily opens
while the valuable thing stays monthly. The uncopyable asset is **proof + an accumulating
shared history** — no competitor has a Vault filled by verified proof photos.

1. **Days Together / love-counter available SOLO** — ships with solo-first, addresses the
   ~96%, needs no partner, ticks up with zero user effort (the most anti-pressure
   retention mechanic there is), and is already **the #1 converting ASA keyword**. People
   are paying to download for the counter and hitting a wall before they can see it.
2. **"A year ago today" from the Vault** — resurface a proof photo on its anniversary.
   Memories already carry `latitude`/`longitude` and `MemoryMapView` exists, so it is
   near-free. Pure carrot, zero guilt, and it gets **better the longer someone stays** —
   the inverse of a streak, which gets more stressful over time.
3. **Countdown in the Next Date widget** — a Mission has a `scheduledDate` and the
   multi-day anticipation window between planning and going is currently *completely
   unexploited* (no countdown, no checklist nudge). Retention flowing from the product's
   real value rather than bolted on.
4. **Monthly date-streak** ("3 months in a row you actually went out") — streaks the
   north-star event, forgiving by construction, and uncopyable without a proof loop. This
   is the honest replacement for the fake card below.

**FIX THE FAKE STREAK CARD (`HomeView.swift:628`).** `@AppStorage("dayStreak")` is
initialised to `1` and **never written anywhere in the repo**, so any user without an
anniversary sees "1 Day Streak" permanently — a stat that never moves reads as a broken
app. Two structural problems beyond the placeholder: (a) it sits in the `else` branch of
`quickStatsRow`, mutually exclusive with Days Together, so it **vanishes for users who set
an anniversary** — backwards, it disappears for the more-invested user; (b) it contradicts
locked brand comments in the same files (`HomeView.swift:7`, `DailyQuestionCard.swift:3`,
both "no streaks, no shame"). Resolution per Flame: a **self**-directed streak is
off-brand, a **couple**-framed one is not ("You two — 6 days in a row 💛"). Wire it to real
`dailyAnswers` day-count, give it a permanent slot, update the two comments.

### Paired-couple count (GA4, Jul 1 – Aug 8 2026)

**3 paired couples — Australia 1, Lithuania 1, United Kingdom 1** (`invite_redeemed`, 3
events / 3 users; country = the REDEEMER's). Up from 2 in the 2026-07-30 all-time read.
The country split sums exactly to the un-dimensioned total, so **thresholding hid nothing
this time** — but keep re-checking against the un-dimensioned total, per the GA4 GOTCHA
above. Same window, unique users: `sign_in` 35, `invite_created` 10, `invite_redeemed` 3,
`mission_created` 10, `match_created` 3, `memory_completed` 4, `paywall_shown` 2.

**Two signals in that table:**
- **`memory_completed` = 4 users but only 3 paired couples exist**, and the country rows
  put completed memories in the **US and Canada, neither of which has a redeem**. Those
  are **solo users completing real dates**, stored local-only and thrown away. Direct
  evidence for solo-first: people reach the north-star event without a partner today.
- **`match_created` = 20 events across only 3 users** — the UK pair alone is 18 of them.
  The swipe loop is not broadly dead so much as one engaged couple and nobody else.

**TOOLING BLOCKER (worth fixing before the next data read):** Firestore `couples` is the
documented source of truth, but the Admin SDK is unreachable from this machine — ADC at
`~/.config/gcloud/application_default_credentials.json` is authenticated as the ads
account (`quota_project_id: kunwebs-ads-mcp`), not the iLovu Firebase owner
(`ilovuapp27@gmail.com`, which only `firebase-tools` holds). **Do NOT run
`gcloud auth application-default login` to fix this** — it overwrites the shared credential
and breaks google-ads-mcp + analytics-mcp. The clean fix is a **service-account key for
`ilovu-b5d87`** kept beside the project, which sidesteps the collision entirely.

### BOTH non-founder pairs CHURNED within 24h of pairing (GA4, 2026-08-08)

Per-day trace of the two pairs above, iOS stream only (`streamName = iLovu`; the country
rows mix in `Ilovu.io` web traffic and must be filtered or they mislead).

**🇦🇺 AU — paired Jul 27, last seen Jul 27, silent 12 days.** Jul 22 `sign_in` +
`onboarding_complete` + `invite_created` (16 ev / 4m48s) · Jul 24 opened, no funnel events
(5 ev / 47s) · Jul 25 sign_in + onboarding AGAIN (8 ev / 52s) · Jul 26 sign_in + onboarding
AGAIN (6 ev / 20s) · **Jul 27 `invite_created` → `invite_redeemed`, 2 users (26 ev /
5m53s)** · Jul 28–Aug 8 **nothing**. **Zero `card_liked`, zero `mission_created`, zero
`memory_completed`, zero `paywall_shown` — they paired and never used the product.**

**🇬🇧 UK — paired Jul 31, last seen Jul 31, silent 8 days.** Jul 24 sign_in + onboarding
(8 ev / 35s) · Jul 28 2 users sign in + `invite_created` (34 ev / 5m24s) · **Jul 31
`invite_redeemed` + 46 `card_liked` → 18 `match_created` (106 ev / 9m24s)** · Aug 1–Aug 8
**nothing**.

**D1 retention = 0 for both pairs. Neither reached D7.** D30 not yet measurable (AU hits it
2026-08-26). n=2 — a signal about SHAPE, never a rate.

**Three findings, in order of importance:**

1. **The pairing session IS the peak, then a cliff.** Both pairs spent their largest
   session on the day they paired and never opened the app again. Pairing is being
   experienced as the destination, and **nothing is scheduled to pull them back the next
   day** — which is the DECIDED daily-question trigger above, now with direct evidence
   behind it rather than a Flame analogy.
2. **The UK pair completed the entire "aha" and churned anyway: 46 swipes → 18 matches →
   `mission_created` 0, `memory_completed` 0.** This is sharper than "the swipe loop is
   dead" (the loop worked perfectly); the dead end is **match → mission**. Eighteen mutual
   matches produced not one planned date. "Plan This Date" is UNGATED, so the paywall is
   not the cause. **This deserves its own investigation before the next build** — it is a
   SECOND retention hole, downstream of pairing and independent of the funnel work.
3. **AU fired `onboarding_complete` on FOUR separate days** (Jul 22/25/26/27). Onboarding
   is gated by `hasCompletedOnboarding` in `@AppStorage` and should fire once per install.
   Repeated firing = repeated reinstalls or local state being wiped — and it happened
   during exactly the window they were struggling to pair. **Possible bug, not just a
   metric; check before assuming it's noise.**

**Consequence for strategy — state it plainly:** solo-first makes the paywall REACHABLE,
but it does not fix this. Both couples who *did* pair churned inside a day. Getting users
through the funnel is necessary and NOT sufficient; there is a distinct
post-pairing retention hole, and match→mission is where it leaks.

### Daily Question bank — expansion plan (PROPOSED 2026-08-08)

Current content banks, counted from source: **`ConnectionQuestions.all` = 130** (Daily
Question) · **`WouldYouRather.prompts` = 120** · **`ThirtySixQuestions` = 36** · 286 total
(separate from the 165-card date deck). Goal: **~1,000 Daily Questions** (~2.7 years),
science-grounded, so partners keep learning about each other.

**⚠️ BLOCKER — THE BANK CANNOT EXCEED 366 TODAY. FIX ROTATION BEFORE WRITING CONTENT.**
`ConnectionQuestions.today` (`ConnectionQuestions.swift:172-176`) is
`(ordinality(of:.day, in:.year) - 1) % all.count`. `ordinality` returns **1–366**, so the
index never exceeds 365 no matter how large the bank is — **questions 367+ are unreachable
dead code.** Writing 870 questions against today's rotation would ship ~236 of them.

**Migration risk: NONE (verified).** `DailyAnswerDoc.question` snapshots the question TEXT
as asked (`DailyQuestionService.swift:38`), not an index or ID — so the bank can be grown,
reordered and re-themed freely and past answers keep their original prompt. See the
corrected `dailyAnswers` note in the data model above.

**Rotation fix — continuous counter + per-couple offset:** replace day-of-year with days
since a fixed epoch, plus an offset derived from `coupleId`. Buys three things: (a) unlocks
banks >366, (b) kills the **Jan 1 sequence reset** (a couple in year two currently re-runs
the same order), (c) different couples get different questions on the same day while BOTH
partners still compute the identical prompt locally with no server call (same `coupleId` →
same offset), preserving the existing design. **GOTCHA: `hashValue` is per-process seeded
in Swift and is NOT stable across launches — using it would hand each partner a DIFFERENT
question.** Use a deterministic hash (FNV-1a / UTF8 byte sum).

**Structure — `[String]` → a struct with theme + depth.** Escalating reciprocal
self-disclosure is the actual mechanism behind Aron's 36 Questions; a flat random bank
discards the effect the research demonstrates. Early days lean `.light`, depth unlocks as
answered-days accumulate. Themes, each anchored to a real construct: **Love Maps**
(Gottman — the canonical "knowing your partner's inner world" construct, the core of this
goal) · **Dreams & self-expansion** (Aron) · **Gratitude & capitalization** (Gable,
active-constructive responding) · **Savoring & memories** (Bryant — ties into the Memory
Vault) · **Growth & affirmation** (Drigotas & Rusbult, Michelangelo phenomenon) · **Awe &
novelty** (Keltner; Aron arousal — already the rationale behind the 165-card deck) ·
**Playful** (Fredrickson) · **Closeness** (Reis & Shaver intimacy process model).

**HARD BRAND GUARD on generation:** anti-pressure positioning is locked and
"relationship repair/reignite" framing is explicitly off-brand; `WouldYouRatherPrompts.swift:2-3`
bans "heavy/relationship-audit territory." No conflict diagnostics, no "what do you
resent," no therapy-speak. Warm and curious, always.

**Build order (volume LAST — the precedent is quality over volume; bulk-padding
near-duplicates was already rejected once when growing the deck 140→165):**
1. Rotation fix + `ConnectionQuestion` struct (small; unblocks everything else)
2. Re-theme the existing 130 into the taxonomy (tagging, no new writing)
3. Batches of ~110 to 1,000, **deduped per batch**, never one dump

**Honest caveat:** at today's retention nobody has come close to exhausting 130 — both
paired couples churned inside a day. This is content for a retention problem not yet
solved. Worth doing anyway (the rotation bug means even the current 130 partly doesn't
work, and content compounds), but **after** the trigger work, not instead of it.

### What SOLO users actually do (GA4, 2026-08-08) — Near You, never the card deck

**MEASUREMENT GAP FIRST:** `near_you_opened` / `daily_question_answered` /
`would_you_rather_answered` / `memory_viewed` fire in **Lithuania ONLY** — i.e. dev builds.
They are on `main` but **NOT in submitted 1.0.6 build 11**, so no shipped build reports
them. **"What do users do inside the app" is unanswerable for real users until that build
ships — make it the next build's first priority.** (GA4 also cannot segment solo vs paired;
the `is_paired` user property is still only PROPOSED. Below is by exclusion, knowing
exactly what the 3 paired couples did.)

**Almost nobody arrives.** US (the whole paid cohort): 38 `first_open` → 16 `sign_in` → 15
onboarded → **3 `reached_pairing_screen`** → 2 `invite_created` → **0 redeemed. Zero US
pairs, ever.**

**Those who DO engage plan dates and never swipe** (users, iOS stream):

| Country | `card_liked` | `mission_created` | `memory_completed` |
|---|---|---|---|
| United States | **0** | 4 | 1 |
| Canada | 0 | 1 | 1 |
| Bulgaria | 3 | 1 | 0 |
| UK (the pair) | 46 | **0** | 0 |
| Lithuania (founder/testers) | 21 | 4 | 2 |

**16 US users signed in and NOT ONE swiped a card, yet 4 created missions.** The only route
to a mission without a swipe is **Near You → "Plan This Date"** (ungated). **This answers
the parked Fix 4 strategic question: outside founder testing the card deck is essentially
unused and Near You IS the product.** Note the inverse for the UK pair — 46 swipes, 0
missions. Swiping and planning are being done by *different people*, and only planning
reaches the north star.

**Two solo users completed the full north-star loop alone** (US 1, CA 1): swiped nothing,
planned from Near You, went, captured a proof photo. The Canadian tried to pair first
(`reached_pairing_screen` → `invite_created` → never redeemed), gave up, and used it solo
anyway. All of it stored **local-only and discarded** — the strongest single argument for
solo-first storage.

**DATA-INTEGRITY CATCH — `match_created` is contaminated.** Bulgaria logs `match_created`
with no pairing: unpaired swipes fall back to a `Bool.random()` solo celebration
(`SwipeView.swift:214`) which appears to fire the analytics event. So "3 users ever
matched" is really ~2 real + a coin flip. **Either stop logging `match_created` on the
solo fallback or give it a distinct name** before any decision leans on that number.

Prior evidence: `~/ilovu-content/ILOVU-PLAN.md` and the Flame interview notes there.

### PARKED — future Near You categories + a "Trending" cross-cutting filter (raised 2026-08-08/10, NOT scheduled)

Deliberately parked by the founder: worth building, not now. Near You is where real solo
users actually go (see the solo section above), so investment here is better-aimed than
most — but it fixes none of the retention holes.

**Beaches — a dictionary edit, the `.trails` pattern exactly.** New `LocalEvent.Category`
case + `SearchGroup` (30 km, day-trip intent) + `typeScores` + `minRatingCount` (LOW, ~10
like trails — beaches draw few reviews) + `curationVersion` bump. **Put it in its OWN
SearchGroup and verify the type against Table A first** — "a bad type 400s the whole
group", so appending an unverified beach type to the trails group would take hiking
coverage down with it. Empty in Vilnius (Palanga/Nida are ~300 km out, past any radius) —
**already handled**: 1.0.5's dynamic pills only render categories present in the loaded
deck, so a Beaches pill won't appear in Vilnius and WILL appear via the plan-a-trip city
search. "Top" beaches needs nothing new — `popularityBoost` already ranks.

**Rooftops — structurally harder: Google has NO rooftop place type.** Rooftop is an
ATTRIBUTE, not a type, so `searchNearby`/`includedTypes` cannot find them at all. Options:
**(A)** `PlacesService.searchText` already exists (`PlacesService.swift:70`) — but its
`searchFieldMask` lacks `primaryType`, `types`, `location`, `businessStatus`, i.e. exactly
the four fields `curate()` needs to map a category and drop closed venues; it would have to
use `nearbyFieldMask` (`PlacesService.swift:58`), slightly pricier per call. **(B)** name/
review matching over already-cached `bar`/`wine_bar` venues — zero extra API calls, zero
cost, low recall. **(C) RECOMMENDED: one text search per location bucket, cached to
`placeDeckQueries`** — respects the locked "scale with venues, not users" cost rule.
Seasonal (Vilnius rooftops are summer-only); dynamic pills handle the empty state.

**"Trending" filter (the TikTok idea, REFINED 2026-08-10) — a CROSS-CUTTING TOGGLE, not a
category.** Categories are mutually exclusive; "viral" is an attribute a restaurant, a
rooftop bar and a viewpoint can all carry at once, so making it a category would force a
false choice. Shape: an OPTIONAL `viralScore`/`isViral` on the cached venue (optional =>
old cached docs decode nil, no orphaning — same property that made `.trails` safe); the
filter row becomes category pills **+ one independent toggle** that composes with them;
same empty-state guard as the dynamic pills (hide when the deck has zero viral venues —
the Music-pill lesson); `curationVersion` bump. **This shape makes manual curation almost
trivial: a list of placeIds per city + a flag.** No taxonomy work, no caption parsing — the
venue already carries its category, rating, photos, hours. Ship the filter with hand-picked
data, swap the source later without touching the UI.

**⚠️ NAMING: do NOT ship "TikTok" as the user-facing label.** Third-party trademark in the
UI and App Store listing, and if the data ever comes from scraping the name advertises it.
Use **"Trending" / "Viral" / "Hyped right now"** — stays accurate if the source later
becomes Foursquare or our own data.

**Data sources, ranked (2026-08-10):** **(1) Manual curation per city — RECOMMENDED at
current scale.** ~20–30 spots per market, zero cost, zero ToS risk, and HIGHER quality than
fuzzy-matched scrape output. The 165-card deck and `searchGroups` are already hand-curated;
this is the same muscle. **(2) Foursquare Places API** — the legitimate version of the
Apify idea (real popularity/trending signals, free tier); **check Lithuania coverage
first** — thin launch-market coverage is what killed Ticketmaster AND Eventbrite, and it
would kill this too. **(3) Our own `bucketList` aggregate** — anonymised wishlist adds =
"trending with couples on iLovu"; proprietary, legally clean, compounds with scale. Cold
start is fatal today (3 couples) but the schema is worth designing now. **(4) Review
recency** — `places.reviews` is ALREADY in the field mask, fetched, billed and cached, but
`PlacesService.Review` (`PlacesService.swift:293`) decodes only rating/text/author and
**drops `publishTime`**; adding it is a 2-line Codable change at ZERO extra API cost.
Weak though: Places returns ~5 reviews chosen by RELEVANCE, not recency — a biased sample
of five, cheap to try, not reliable to rank on alone.

**On Apify/TikTok specifically:** **there is NO legitimate TikTok API for this** (Research
API = academic-gated, Display API = the user's own content only, Commercial Content API =
ads transparency), so scraping is the only TikTok path — real ToS risk, weigh it
deliberately. If ever done: frame TikTok as a **ranking SIGNAL on venues already cached**,
never as a source of venues (entity resolution from captions is where these projects die);
run it **server-side, per city bucket, weekly** (never per user — that repeats the ~$16k/mo
Places mistake); and **extract venue names ONLY** — no usernames, comments or video
content — which keeps it clear of the messiest GDPR exposure. Cache writes are already
CF-only since the hardening sprint, so it has to be server-side regardless.

### TOOLING BACKLOG (2026-08-10)

- **Firestore service-account key for `ilovu-b5d87`** — so `couples` (the documented source
  of truth) is directly readable. See the ADC collision note above; never fix it with
  `gcloud auth application-default login`.
- **Apple Ads (Search Ads) API — IN PROGRESS.** Removes the documented "read CPI/spend from
  the dashboard by hand" step. **P-256 keypair generated 2026-08-10 at `~/.apple-ads/`**
  (`private-key.pem` 600, dir 700; public key uploaded in Apple Ads → Account Settings →
  API → Client Credentials). Still needed: **`clientId` / `teamId` / `keyId`** (returned on
  upload) plus **`orgId`** (NOT on that screen — Account Settings or the `/me` endpoint).
  Flow: ES256 client-secret JWT (iss=teamId, sub=clientId, aud=`https://appleid.apple.com`,
  kid=keyId) → `appleid.apple.com/auth/oauth2/token` (`grant_type=client_credentials`,
  `scope=searchadsorg`) → **1-hour** access token → `api.searchads.apple.com/api/v5/...`
  with `Authorization: Bearer` + `X-AP-Context: orgId=<orgId>`.
  **⚠️ The client-secret JWT expires in ≤180 DAYS and will fail silently months later** —
  diarise it (same failure mode as the 7-day `-personal` ADC).
  **MCP choice:** all options are third-party and unvetted, holding WRITE access to real ad
  spend. **Prefer a LOCAL stdio server over a hosted one** (hosted = credentials on someone
  else's infrastructure) and read the source before installing — "74 typed tools / full v5
  coverage" means full mutate access by default. Candidates: `AppVisionOS/apple-search-ads-mcp`,
  `Happygallo/apple-ads-mcp`, `gregtuc/asa-mcp` (local) vs `ppcprophet/apple-ads-mcp`
  (hosted — avoid). **Alternative with zero third-party trust: a ~50-line read-only script**
  doing JWT → token → report, which covers the actual need (CPI, spend, installs).

---

## ASA WORLDWIDE + 1.1.0 PLAN (2026-08-11) — read this before the next build

**Apple Search Ads went WORLDWIDE on 2026-08-08** (was US/UK/AU/NZ at ~€2.6 CPI).
**Blended CPI is now ~€0.50.** The €2.6 benchmark everywhere above is OBSOLETE, and the new
number is dangerous: it fell because spend moved to cheap storefronts (Algeria, Mongolia,
Uzbekistan, Nepal, Peru, Venezuela), where a $49.99/yr sub is a very heavy ask. **Read CPI
and revenue-per-install PER STOREFRONT, never blended.** This makes the half-built Apple Ads
API (TOOLING BACKLOG above) the highest-value tooling item — 25 storefronts is not a
by-hand job.

### The worldwide cohort — GA4, iLovu stream, 2026-08-08 to 08-10

Volume jumped from 0–2 new users/day (Aug 5–7) to **8 / 15 / 11**. Unique-user funnel:

    34 first_open → 29 sign_in (85%) → 26 onboarded → 18 near_you → 11 reached_pairing
                                     → 5 invite_created → 0 invite_redeemed
    mission_created 8 · card_liked 1

vs the 2026-07-30 all-time baseline (49 → 27 → 27 → 9 → 2). **The sign-in leak went from
45% to 15%** — the biggest single funnel result to date. **CAVEAT: cannot be attributed.**
It could be 1.0.6/1.0.7 working OR a higher-intent cohort mix, and *we do not know which
build these users ran* — CLAUDE.md never recorded whether 1.0.6 or 1.0.7 was approved.
Confirm in App Store Connect before banking it.

**Per country (Aug 8–10):** Italy is the standout — 6 installs, 6 sign-ins, 4 Near You,
2 pairing, 1 invite, 1 mission. Then Algeria 3/3/2/1/–/1 · Mongolia 2/2/2/1/–/1 ·
Mexico 2/2/1/1/–/1 · Türkiye 2/2/1/2/–/– · Chile, Peru, Uzbekistan each reached an invite
from 2 installs. **The US collapsed to 1 install and 0 sign-ins** — worldwide did not ADD
to the US cohort, it REPLACED it. The long tail is NOT behaving like junk traffic; several
of those geos convert deeper than the US ever did at €2.6.
**Spanish cluster (MX/CL/PE/VE/HN): 8 installs → 7 sign-ins → 3 pairing → 2 invites.**

### ⚠️ iLovu IS RATED 18+ — and 18+ is now AGE-GATED in 3 storefronts (found 2026-08-11)

**The App Store listing shows a 18+ age rating** (verified on the live product page; a
consequence of the 2025 age-rating overhaul that replaced 12+/17+ with 13+/16+/18+ and
forced every app through a new questionnaire by 2026-01-31). Nothing in this file had ever
recorded it.

**Since 2026-02-24 Apple BLOCKS downloads of 18+ apps in Brazil, Australia and Singapore**
unless the Apple Account has been confirmed as an adult; the App Store does the check itself,
before the install. Utah (2026-05-06) and Louisiana (2026-07-01) additionally share age
categories with apps via the Declared Age Range API for new accounts.

**Why this matters right now:** ASA went worldwide on 2026-08-08 into ~25 storefronts, and
**AU is one of only 3 paired couples all-time**. If AU/BR/SG are in the campaign, a share of
that spend is buying impressions against a download gate — an install leak that is INVISIBLE
in the GA4 funnel, because it happens before `first_open`. **→ Check the ASA per-storefront
install rate for AU/BR/SG against comparable geos, and exclude them if the tap-to-install
rate is depressed.** Independent argument for concentrating ASA on 1–2 storefronts.

**Also worth a deliberate decision: is 18+ even correct?** It restricts the whole app in
those markets and narrows ASA reach everywhere. If the rating came from an over-cautious
questionnaire answer rather than a real content requirement, a re-rate is free reach. But
**do NOT re-rate below 18+ if the dating layer is ever built** (see PARKED below) — and note
the questionnaire is the honest-answer obligation of guideline 2.3.6.

### Couples: still 3, and ~1 alive

`invite_redeemed` all-time = **3** (AU 1 / LT 1 / UK 1), the country split summing exactly
to the un-dimensioned total (thresholding hid nothing). **Unchanged since 2026-08-08 — the
worldwide cohort has produced ZERO pairs from 5 invites.** In the last 7 days
`match_created` and `memory_completed` are both **0**; the only couple-shaped signal is 2
users answering daily questions (the founder pair). Note `daily_question_answered` /
`would_you_rather_answered` are NEW events (`70b58ef`) — their earlier zeros are
instrumentation, not churn.

### FOUR MEASUREMENT BUGS — the numbers above are partly fog

1. **`is_paired` is NOT registered as a GA4 custom dimension** (only
   `firebase_last_notification` exists). The code sends it (`ba7c649`) but **GA4 silently
   discards unregistered user properties and registration is NOT retroactive.** Solo vs
   paired cannot be segmented, and every day of delay is permanently lost. Register it FIRST.
2. **Solo swipes log NOTHING.** `card_liked` fires only inside `MatchService.recordLike`,
   which requires a `coupleId`. `completeSwipe` logs nothing on the solo branch. **We have
   zero observations of solo swipe volume** — which is why the swipe-cap number below
   cannot be chosen from data we hold.
3. **`near_you_opened` is a TAB-OPEN counter, not a visit** — logged in `.task`
   (`NearYouView.swift:171`), so it re-fires on every view appearance. Aug 6 shows **33
   events from 1 user** (founder testing the parallel-load build). Any engagement read
   built on it is inflated by an unknown multiple.
4. **`paywall_shown` = 0 across 37 new users in 7 days.** Also 0: `paywall_dismissed`,
   `purchase_success`, `restore_success`, `memory_shared`. The money path has never once
   executed end-to-end, and the RevenueCat sandbox buy/revoke test is still outstanding.

### THE FAKE MATCH — solo users get a coin flip (`NearYouView.swift:373-383`)

    if let coupleId { Task { await matchService.recordLike(...) } }
    else if Bool.random() { matchedEvent = event }      // ← unpaired: 50/50

An unpaired right-swipe has a **50% chance** of showing the full celebration —
`EventMatchView.swift:55` literally reads **"It's a Match! 🎉"** — with a "Plan This Date →"
CTA that calls `missionStore.add`. The other 50% does nothing at all. The comment calls it
a "placeholder coin-flip … for solo/preview"; **it is shipping to production in ~25
countries.** Consequences: it is a lie to the user, half of all solo intent is silently
discarded, and **`mission_created` is ~50% noise** so real solo intent is higher than
measured. Not an A/B question — delete it.

### SOLO USERS ALREADY PLAN DATES — the strongest solo-first evidence yet

`MissionStore.add` (`MissionStore.swift:53-60`) writes to **UserDefaults first**;
`remoteUpsert` is nil when unpaired (comment at :34-36), so **mission planning already
works solo, device-local.** `Mission(from:)` sets `.upcoming` (`Mission.swift:74`), so it
does render on Home. Last 7 days: **9 users created 14 missions with `match_created` = 0
and only 3 couples in existence.** Missions (9 users) OUTNUMBER invites (5) — people plan
before they invite. Those missions are fragile (reinstall or a uid change wipes them) and
**none of those 9 can ever pay us** — `PaywallGate` is per-couple.

### What solo users do, ranked (7d, % of the 27 who onboarded)

    Near You 18 (67%) · pairing screen 11 (41%) · Mission 9 (33%) · invite 5 (19%)
    Would You Rather 3 (11%, 3.7 plays each) · Daily Question 2 (7%, 4.5 each)
    card deck 1 (4%) · bucket list 1 · memory viewed 1

The card deck is DEAD — **Fix 4 is settled**, stop treating it as open. The games have the
highest DEPTH of anything in the app from the few who find them: a discovery problem, not
an interest problem.

### NEAR YOU DOES NOT RETAIN — reach 67%, next-day return <10%

Aug 8–10: **18 distinct Near You users, 20 daily-user-days → 2 return-days. 16 of 18
opened it on exactly one day.** Structural, not polish: **the deck is exhaustible** — swipe
your city and there is nothing new tomorrow. This is exactly Flame's Airbnb diagnosis in
the retention section above. **Near You is an ACTIVATION surface, not a retention surface.**
More categories (Beaches, Rooftops) improve the FIRST session only; **"Trending" is the one
parked Near You idea that would retain**, because novelty-over-time is the mechanism.

### SOLO USERS CANNOT BE REACHED AT ALL — the retention blocker

`CoupleService.persistFCMToken` (`:425-443`) writes to `couples/{id}.fcmTokens[uid]`. With
no couple the token is **parked in memory and never persisted** (sole exception: attached to
`invites/{token}.creatorFcmToken` when an open invite exists, purely for the pairing push).
**A solo user has no server-side push token — we cannot send them a single notification.**
Every push mechanic, including the DECIDED daily-question trigger, is unavailable to ~96%
of users. So solo retention has only two possible surfaces: **a home-screen surface that
changes without us, and a commitment the user made themselves.**

- **Days Together solo — the best build in the app.** The widget exists and is ungated, but
  `WidgetDataWriter.swift:31` reads `couple?.milestoneDate(.dating)` → **nil when unpaired,
  so it renders blank.** It is the **#1 converting ASA keyword**: people pay to install FOR
  this and hit a wall. Move `datingDate` to user-scoped storage.
- **Next Date countdown — already works solo** (reads the local mission store). The
  plan→date anticipation window is completely unexploited; the post-date "how did it go?"
  prompt is the path to `memory_completed`, currently **0**.
- **FLAME'S BEST MECHANIC DOES NOT PORT.** Their stick was "your partner will be sad" —
  obligation to a person. A solo user has nobody to disappoint. **Only carrots exist solo.**
  The retention section above was derived from an inherently two-sided mechanic; it
  quietly assumes a partner.

### UNIT ECONOMICS AT €0.50 CPI — the gate is the whole problem

Annual $49.99 → ~$42.49 net (Apple Small Business 15%) ≈ **€39** → break-even at
**78 installs per annual sub = 1.3% install→paid**. Founding $39.99 ≈ €31 → 62 installs =
1.6%. **1.3% is a completely normal target — €0.50 CPI is profitable-capable.**

Decompose it: `1.3% = onboard 76% × reach-paywall X × buy Y`

    X = 2%  (today, pairing-gated)  →  Y = 85%   IMPOSSIBLE
    X = 33% (usage-triggered)       →  Y = 5.2%  normal
    X = 50%                         →  Y = 3.4%  comfortable

And today X is not even 2% — `paywall_shown` is **0**. **Traffic prices are already
profitable; the product is unmonetizable.** Exactly one change fixes it: make the paywall
reachable without a partner.

### SUPERSEDED SAME DAY — 1.0.8 monetization slice ships FIRST (2026-08-11)

**The one-big-ship call below was made before the founder stated the priority as
"generate revenue ASAP and get some numbers."** Those conflict: 1.1.0 is 2–3 weeks
and most of it (solo-first Firestore storage, Days Together, retention) earns
nothing. So the monetization slice was split out and built the same day.

**THE KEY DISCOVERY THAT MADE IT DAYS INSTEAD OF WEEKS: `PaywallGate` never
touched Firestore.** It is entirely `UserDefaults`, and `coupleId` was only ever a
string used to namespace local keys. **Solo-first storage is NOT required to charge
money** — it is required for sync, push and durability. Pass a uid-derived scope and
the whole gate works alone.

**PAYMENTS AUDIT (2026-08-11) — the money path is GREEN.** Verified before building,
because a broken purchase path would make everything else theatre:
`premium` entitlement exists with BOTH real App Store products attached to the real
iLovu app ✓ · offering `default` is Current with `$rc_annual`/`$rc_monthly` mapping to
`com.ilovu.app.annual`/`.monthly`, matching `RevenueCatConfig` byte-for-byte ✓ · SDK
key valid ✓ · `revenueCatWebhook` deployed (europe-west1), endpoint live, auth guard
correct (GET→405, bad auth→401) ✓ · `REVENUECAT_WEBHOOK_SECRET` set ✓ · webhook
registered in RevenueCat for **Both Production and Sandbox** ✓ · **Paid Applications
Agreement ACTIVE, all countries, through 2027-06-03** ✓ · `purchase_success` correctly
logged at `SubscriptionService.swift:170` ✓.
**Conclusion: €0 is NOT a payments bug — it is `paywall_shown` = 0.**
Two leftovers: the webhook has never received a single event (no purchase has ever
happened, so nothing to send — its Authorization header therefore remains UNTESTED,
and a mismatch would silently 401 and break revocation only); and an old `iLovu Pro`
entitlement holds Test Store products (`monthly`/`yearly`/`lifetime`) — harmless
prototype junk from 2026-06-17, ignore it.
**⚠️ DIARISE: the Paid Apps Agreement expires 2027-06-03. A lapsed agreement silently
blocks ALL purchases** — same failure mode as the Apple Ads JWT.

**⚠️ THE FOUNDING OFFER DOES NOT EXIST IN THE PRODUCT CONFIG.** Pricing below locks
"$39.99/yr for the first 500 users", but RevenueCat serves only
`com.ilovu.app.annual` ($49.99) and `com.ilovu.app.monthly`. There is no founding SKU,
so any revenue test runs at the HIGHEST price point we will ever charge, on an app with
3 couples. Decide before spending on ads.

### SHIPPED in 1.0.8 (built 2026-08-11, branch `solo-paywall-1.0.8`; build + tests pass)

**Two paywall triggers, both reachable without a partner:**

    mission-open   armed at the 2nd Mission planned, presents when one is opened   ~33% reach
    swipe cap      20 swipes/day in Near You                                       ~67% reach

- **`PaywallGate` is now SCOPE-keyed, not couple-keyed.** Scope = `coupleId` when
  paired, `"solo.<uid>"` when not (`CoupleService.paywallScopeId`). New arming
  **condition C: 2 Missions planned** — the solo-reachable input, since `MissionStore`
  persists locally and `remoteUpsert` is nil when unpaired.
  **The UserDefaults key STRINGS were left byte-identical** (`pairingDate.*` etc.) so
  the 3 existing couples keep their armed latch and backstop stamp across upgrade.
- **THE `Bool.random()` FAKE MATCH IS DELETED.** A solo right-swipe now ALWAYS saves
  the venue as a Mission, with an honest toast ("Saved to your plans 💛 · <venue>") —
  deliberately a toast and not a full-screen cover, because interrupting every
  right-swipe would suppress exactly the swipe volume the cap needs.
- **The swipe cap is REMOTELY TUNABLE** — `MainTabView.loadPaywallConfig` reads
  `config/paywall.soloSwipeCap` from Firestore once per launch. Firestore, NOT Firebase
  Remote Config, which is not linked in this project; no new dependency for one integer.
  Tighten 20 → 15 → 10, or kill it with `0`, **without an App Store release.** Any
  failure (offline / rules / missing doc) keeps the built-in default — the safe
  direction. New read-only `config/{key}` rule added.
  **The cap is checked BEFORE the card is consumed**, so hitting the wall never costs a
  venue, and that swipe is neither counted nor logged.
- **New measurement:** `swipe_made` (`direction`, `scope`) — solo swipes were entirely
  invisible before, which is why the cap number is still a guess — and `paywall_shown`
  now carries (`trigger`, `scope`).
- **`hardMode` left `true`** (the locked default): an armed, unsubscribed solo user is
  BLOCKED from opening their own planned date. Fastest revenue signal, highest churn
  risk. One line to soften — revisit as soon as drop-off is visible.

**NOT done in 1.0.8, still open:** deploy `firestore:rules` + create the
`config/paywall` doc (the dial is inert until both) · one sandbox purchase end-to-end ·
register `is_paired` in GA4 · price/founding-SKU decision · concentrate ASA on ~2
storefronts · version bump · the Layer-1 leftovers (`near_you_opened` visit fix, fake
`dayStreak` card, per-couple `REMINDER_TZ`) · all of Layer 2 (solo-first storage).

**Learning-budget arithmetic:** ~100 paywall views gives a rough conversion rate; at
~67% reach that is ~150 installs; at €0.50 CPI ≈ **€75**. Call it €150 over ~10 days
(~300 installs). At 3–5% conversion that is 3–5 subs ≈ €117–195 net — the learning
spend plausibly pays for itself. **Concentrate it on 2 storefronts, not 25: data
density matters as much as user density.**

### DECIDED 2026-08-11 (founder call) — 1.1.0, ONE BIG SHIP (SUPERSEDED — see above)

**Reverses the 1.0.7/1.0.8/1.0.9 split proposed in "Sequencing" above** (and its warning
that "shipping any two together at ~50 installs means learning nothing about either").
**Version is 1.1.0 — 1.0.7 was already spent on the Near You batch (`aaa218f`).**

**Mitigation that recovers clean attribution: ship the usage cap behind a REMOTE FLAG, OFF.**
Confirm solo-first alone for a week, then flip the cap remotely. One ship, clean reads.

    LAYER 1 — instrumentation + bugs (prerequisites; nothing is readable without these)
      · delete the Bool.random() fake match + honest copy ("Saved to your plans", not "It's a Match!")
      · add swipe_made; add a `reason` param to paywall_shown (swipe_limit | mission_start)
      · near_you_opened → count visits, not view appearances
      · register is_paired in GA4 (do TODAY — not retroactive)
      · fix the fake dayStreak card (HomeView.swift:628, @AppStorage init 1, never written)
      · per-couple REMINDER_TZ — now a LIVE bug, not a future blocker (Vilnius 09:00 is
        ~2am in Mexico City); blocks the daily-question trigger
    LAYER 2 — solo-first storage
      · couple-of-one at sign-in, server-side creation
      · redeemInvite MERGES rather than creates  ← the only piece that can corrupt live data
      · gives fcmTokens[uid] and dailyAnswers a real home; makes missions durable
    LAYER 3 — monetization + retention on top
      · PaywallGate arms on USAGE, not pairing
      · swipe cap behind the remote flag
      · Days Together solo · Next Date countdown · solo Daily Question

### Swipe cap — design (extends the 2026-08-03 proposal above)

Prerequisite is FORCED: swipes live at `couples/{coupleId}/swipes/{cardId}` scoped by
`isCoupleMember`, so a solo user cannot write one today. **Couple-of-one makes the cap free
— no rules change.** Count via `swipeCount` + `swipeCountDay` **on the couple doc** (not
`@AppStorage` — a reinstall would reset the paywall; not a collection count — reads cost
money per swipe). Gate inside **`PaywallGate`** as `shouldPresentAtSwipeLimit(coupleId:)`
so arming stays single-sourced, reusing `hardMode` + a `presentedThisSession` cap. Fires in
`completeSwipe` **before the card is consumed** — otherwise the user pays a venue to be walled.

**THE CAP NUMBER CANNOT BE CHOSEN FROM DATA WE HAVE.** The 2026-08-03 figures (25 and 21 in
one session) came from ONE PAIRED COUPLE's Firestore swipe docs; solo is now 96% of users
and solo swipes are uninstrumented (bug #2 above). Downside is asymmetric — Near You is the
ONLY thing solo users do and 16 of 18 use it once, so a low cap walls the single activation
surface mid-first-session.
**→ Read the cap from a Firestore config doc at launch, cached.** No new dependency
(**Firebase Remote Config is NOT linked** in the project; Firestore is already there). Ship
at 40 or off, measure the real distribution for a week, tighten 40 → 25 → 15 **without App
Review.**

### ON-DEVICE 2026-08-12 — first revenue events ever, and two real bugs

**THE MONEY PATH WORKS.** A sandbox purchase completed end to end on a real phone. GA4
realtime, same session: `paywall_shown` **1** and `purchase_success` **1** — the **first of
each in the app's lifetime** — plus `swipe_made` **20** (the cap fired on the 21st, exactly
as designed) and `near_you_opened` **1** (visit dedupe works; it previously logged one per
tab switch). Four changes verified in one sitting.
**Still unverified:** the RevenueCat webhook received NOTHING, and not an auth failure
either — RC never sent it. Not a ship blocker (the client mirrors the entitlement, which is
what worked); it only means revoke lags. The auth header remains untested.

**BUG 1 — THE COIN FLIP WAS ONLY HALF-FIXED.** `SwipeView` carried the identical
`Bool.random()` fake match. The 1.0.8 fix landed on the venue deck only, so the DATE-CARD
deck kept telling solo users "It's a Match!" half the time with no partner in existence.
Now saves a plan and logs `swipe_made`, matching Near You. **Lesson: that mechanic existed
in two decks — grep for the pattern, not the file.**

**BUG 2 — THE INVITE PAGE'S "OPEN APP" BUTTON IS DEAD IN MESSENGER. Strongest candidate yet
for why `invite_redeemed` sat at 3 all-time.**
It navigates to `ilovu://invite/<token>`. **Messenger / Instagram / WhatsApp open links in
their own WKWebView, which silently cancels custom-scheme navigation** — it spins, then
nothing, no error. Most invites arrive through exactly those apps.
**Universal Links CANNOT rescue it:** iOS deliberately refuses to hand a URL to the app when
you are already viewing that URL in a browser (the designed escape hatch to the web
version), and in-app webviews often ignore Universal Links anyway. **No href works there.**
Shipped: detect the in-app browser and repurpose the button to **"Copy my code"** — the one
action that always succeeds — plus an Open-in-Safari hint. "Get iLovu" now also copies the
code on the way to the App Store: the poor-man's deferred deep link, since install wipes all
web context. Also deleted the step-2 line *"or just tap this link again — it opens the
app"*, which was **actively false** in the browser most recipients use.

**⚠️ OPERATIONAL: NETLIFY DEPLOYS `main` ONLY.** Every site change sat on the feature branch
for two days while on-device testing kept reproducing the "fixed" bug — the live page was
still the old one. `netlify.toml` publishes `site/`, but CD is branch-scoped. **Site changes
must land on `main` to go live; pushing a feature branch does nothing.** Cost two test
cycles. The invite page is now cherried onto `main` and verified live; app work stays on
`solo-paywall-1.0.8` until the device pass is done.

**EMAIL DELIVERABILITY — password resets were going to SPAM (found on device).** Firebase
sends from `noreply@<project>.firebaseapp.com`: a domain shared with every Firebase project,
unrelated to ilovu.io, with a default template structurally identical to phishing. **This
broke account recovery for exactly the cohort email sign-in was added to rescue in 1.0.6** —
the cautious users — and no GA4 event would ever have surfaced it.
Fixed 2026-08-12: Firebase custom email domain verified on ilovu.io. DNS is on **Netlify
(NS1 nameservers)**. **⚠️ THE TRAP: Firebase instructs you to add a SECOND SPF record. Two
SPF records on one domain violates RFC 7208 → PermError → SPF fails for ALL mail, including
the Google Workspace inbox.** It must be MERGED. Live record is now exactly one:
`v=spf1 include:_spf.google.com include:_spf.firebasemail.com ~all`, plus the
`firebase=ilovu-b5d87` TXT and both `firebase{1,2}._domainkey` DKIM CNAMEs, verified
resolving against the authoritative NS.
**Still open:** no `_dmarc` record; sender name + template rewrite; and the action link still
points at `firebaseapp.com` while the sender is now ilovu.io — a remaining domain mismatch
that needs a self-hosted auth action handler (real work, deliberately deferred).

**KNOWN DEAD END, NOT YET FIXED:** pasting the full invite URL into "Have a code?" always
fails — `normalizeInviteCode` strips non-alphanumerics, so `https://ilovu.io/invite/mtv7w`
becomes `httpsilovuioinvitemtv7w`. Five-line fix (take the last path component when the text
contains `invite/`). **Higher-value than before, because "Copy my code" just made the
clipboard the primary path.**

### PARKED — a dating layer for solo users (raised 2026-08-11; researched + gated 2026-08-11)

Prompted by BPM (French sports dating app, €140k MRR in 6 months). Idea: let solo users
swipe on PARTNERS by shared interest, then scroll ACTIVITIES together once matched.
**Founder's expanded version (2026-08-11):** relationship status in onboarding → single
route collects INTEREST TAGS (running, gym, triathlon, football, cinema, theatre, AI,
business, marketing…) → filter who you swipe by those tags + radius, tabs styled like the
Near You cuisine filter → on match, the fresh pair enters the EXISTING loop (swipe venues
together, plan, maybe chat) → a DIFFERENT Daily Question bank tuned for a brand-new couple.

**COMPETITOR SCAN (2026-08-11, done properly — the earlier "matching half is taken" line
was right but understated):**
- **Interest/sport-tag matching is fully occupied and funded.** **Surf** became the
  *official dating app partner of HYROX Americas* (Jan 2026) — a HYROX filter, race-venue
  activations, and interest filters deliberately kept **free, not paywalled**. **GRASS**
  (outdoor) has 50k+ downloads clustered in Denver/Portland/LA/Seattle. **DateFit** filters
  by activity type, workout frequency and goals. **Leg Day** (Apr 2026) only works while you
  are physically inside your gym. Plus BPM (FR), Fitafy, and Hinge/Bumble interest badges +
  exercise filters at unreachable scale.
- **"Plan the activity instead of chatting" is the FASTEST-GROWING category in dating, not a
  gap.** GRASS's own positioning is literally *"replaces swiping and chatting with planning
  and doing"* — activity-first ("what do I want to do, who wants to join") vs people-first.
  **Tinder Events** lets singles browse local activities and see who is going. **Hinge Date
  Ideas** suggests first dates. **222** runs questionnaire → real reservation → post-event
  "see them again?". Activity-based platforms are growing while Match Group and Bumble
  stall, which is exactly why all of them are shipping into it. **This half is closing.**
- **The couples-side co-swipe is crowded too** (our own category): Cobble, WeDo, DateMatch,
  Connected, Cupla all do partner-matched date ideas.
- **GENUINELY UNCLAIMED: converting a fresh MATCH into a completed, proof-photographed,
  jointly-vaulted date.** Nothing found does it. **But understand WHY it is empty — it is
  not hard to build, it is that a dating app which works LOSES TWO USERS.** Hinge has no
  incentive to build the thing that graduates people off Hinge. That is the one durable
  strategic story here: **iLovu is the retention half that dating apps structurally cannot
  want.** It also argues the funnel runs the OTHER way — the couples product is the LTV
  tail of dating, not dating a feature of the couples product.
- **Cautionary precedent: HowAboutWe** — a date-idea-first dating product ("How about
  we… go hiking") that launched **You&Me**, a couples app, in 2014, was absorbed into IAC
  and disappeared. The exact concept, tried at the top of the market, and the couples half
  is where it ended up.

**WOULD APPLE APPROVE IT? Yes, with one real ongoing cost — and one pleasant surprise.**
- **4.3(b) names dating explicitly** as saturated: *"we will not accept new submissions
  unless they offer a meaningfully different or improved experience."* That targets **new
  submissions**; an update to an already-approved app is a softer path. Real risk, NOT the
  binding constraint.
- **1.2 (User-Generated Content) IS the binding constraint** — four mandatory requirements
  we satisfy ZERO of today, because iLovu has no profiles, no chat and no stranger photos:
  (1) filter objectionable material *before* it posts, (2) a report mechanism with timely
  response, (3) block abusive users, (4) published contact info. In practice: image
  moderation on every profile photo, a report queue a HUMAN works, block lists propagating
  through `firestore.rules`, a staffed support address. **Ongoing opex, not a one-time
  build** — and BPM had 10–20 fake profiles within TWO DAYS, pre-marketing.
- **1.1.4 bans "hookup" apps.** The long-term-relationship framing is on the right side of
  this; keep it there explicitly in metadata and screenshots.
- **AGE RATING COSTS NOTHING: iLovu is ALREADY 18+** (see the ASA section above). The
  assumed "a dating layer forces an 18+ re-rate" blocker does not exist. Corollary: do NOT
  re-rate below 18+ while this idea is live.

**WHY NOT NOW (unchanged, and the interest-filter idea makes one reason WORSE):**
1. **Density IS the product, and FILTERS DIVIDE AN EMPTY POOL.** ~37 installs/week across
   ~25 countries ≈ 2–3 users per city. "Women into AI + business + marketing + football +
   triathlon within 20km" returns ZERO in Vilnius and zero everywhere else. Interest filters
   are a feature that only works ABOVE a density threshold we are orders of magnitude below;
   they make the cold-start worse, not better. Every winner bought density first — BPM held
   ONE country for 7 months, Surf bought HYROX, GRASS lives in five US metros.
2. **Buying BOTH sides of a marketplace cold is the most expensive thing in consumer apps**,
   and paid ads are our only channel. BPM had a run club, a 3k waitlist and 500
   first-weekend installs BEFORE the app.
3. **Moderation opex** (1.2 above) with no team.
4. **It abandons our one working acquisition signal** — "love counter" is the #1 converting
   ASA keyword and it is *already-in-a-relationship* intent.
5. **It dodges the cheapest unknown on the table.** 1.0.8 exists specifically to answer
   "will a solo user pay?" and is still unshipped. ~€150 and ~10 days buys that answer;
   spending 2–3 months on a two-sided marketplace to avoid learning it is the wrong trade.

**WOULD WE BUILD IT LATER, AND IN WHICH PHASE? — Not a phase of iLovu. Phase 1 of a
DIFFERENT product, entered only on a specific negative result.** Explicit gates:

    GATE A (now)  ship 1.0.8 · deploy rules + config/paywall doc · concentrate ASA on ≤2
                  storefronts · reach ~100 paywall_shown  →  install→paid rate is KNOWN
    GATE B        install→paid ≥ 1.3% (break-even at €0.50 CPI)
                  →  DO NOT BUILD DATING. Scale the couples app. Dating never happens.
    GATE C        install→paid < 1.3% AND solo D7 retention still <10% AFTER the retention
                  batch has shipped and been measured
                  →  the couples thesis is failing; dating becomes the PIVOT CANDIDATE —
                     never a bolt-on, never while the couples thesis is still untested
    GATE D        before writing any dating code, all three must exist:
                  (1) ONE city, chosen for a reason, not 25 storefronts
                  (2) a real-world distribution hook that exists BEFORE the app (BPM's run
                      club / Surf's HYROX) — paid ads alone cannot cold-start two sides
                  (3) a budgeted, staffed answer to guideline 1.2 moderation

**WHICH CITY (founder raised NZ / Madrid, 2026-08-11) — the city is the LAST decision:**
- **NZ is NOT a cheap-ads market — it is one of our expensive ones.** ASA ran US/UK/AU/NZ at
  **~€2.6 CPI**; today's blended €0.50 came *from moving spend AWAY from those four*. English
  and cheap do not co-occur. (NZ's one edge over AU: **AU is in the 18+ download-block list,
  NZ is not.**)
- **CPI is the wrong metric for a marketplace. Use cost to reach N users inside ONE 20km
  radius.** Cheap CPI in a thin geography buys a dead deck. Auckland ~1.7M · Madrid metro
  ~6.7M · CDMX ~22M.
- **If Spanish, the data says MEXICO CITY, not Madrid.** The promising Spanish signal is
  **LatAm, not Spain** — MX/CL/PE/VE/HN was 8 installs → 7 sign-ins → 3 pairing → 2 invites,
  our best deep-funnel cohort; **Spain was not in it at all**. CDMX pairs the cheapest CPI
  with the highest density. Catch: $49.99/yr is a very heavy ask there → a **MX price tier
  becomes mandatory** (liquidity is the first question, monetization the second).
- **Budget honestly:** a deck needs ~500–1,000 CONCURRENTLY ACTIVE singles in one city;
  after gender split + interest filters that is several thousand installs. At €1 CPI this is
  a **€3–10k experiment**, not a €150 one. Different order of spend from Gate A.
- **→ The one city where the Gate D hook is FREE is the one the founder lives in.** Vilnius
  is small, but run clubs / gyms / universities are reachable on foot, in-language, at €0
  CPI. Every comparable bought density with a real-world hook BEFORE ads, because ads deliver
  strangers one at a time into an empty room and the first 200 leave before the next 200
  arrive. **If the mechanic cannot be made to work where we have feet on the ground, a
  foreign city with paid traffic will not rescue it.**
- **THE €0 VERSION, DO THIS FIRST: a landing page + waitlist for ONE city.** <300 sign-ups in
  a single metro → no amount of ASA creates liquidity. ≥300 → that IS the launch-day density
  that made BPM's first weekend work. Validates the hook BEFORE the localization bill (451
  content pieces + per-couple language field + language-blind deck cache) and before any
  dating code.

**If it is ever built: a NEW app, one city, reusing the venue/deck code as a library.** And
**do not compete on activity-first matching** — GRASS/BPM/Surf/Tinder Events already own it.
Compete on what happens AFTER the match works, which is the only part nobody wants to build.
**The transferable BPM lesson is not "build dating"** — it is *niche + one geography +
density + every €1 returns €1*. Applied here that means CONCENTRATING ASA on one or two
storefronts instead of 25, which is free to do and the opposite of what we did on 2026-08-08.

### SPLIT OUT of the dating idea — two pieces worth building WITHOUT it (2026-08-11)

The founder's dating proposal contains two components that pay for themselves inside the
CURRENT couples product, need no profiles/chat/moderation, and carry ZERO App Review risk.
**Build these; park the dating layer.** They are also exactly the prerequisites the dating
layer would need, so building them here is free optionality rather than sunk cost.

1. **Interest tags in onboarding** (running, gym, cinema, theatre, food, culture…), picked
   with the same multi-select pill UI as the shipped Near You cuisine filter. Inside the
   couples app they personalise **the Near You deck and the 165-card deck for the SOLO
   majority** — solo users are ~96% of the base and Near You is the only surface they touch.
   Same data model the dating layer would need, validated in a context where it earns its
   keep first. **No moderation surface, no UGC, no rating change.**
2. **A "fresh couple" Daily Question track** — a get-to-know-you arc served to a NEWLY
   paired couple instead of the general rotation. This attacks a problem already MEASURED,
   not a hypothetical: **both non-founder pairs churned within 24h of pairing** (see that
   section above). Slots directly into the Daily Question bank expansion plan; the bank
   snapshots question TEXT (`DailyQuestionService.swift:38`), so adding a track needs **no
   migration**. Cost is content, not architecture.

### PARKED — localization / Spanish (raised 2026-08-11)

**There is ZERO localization infrastructure today:** no `.lproj`, no `.xcstrings`, no
`NSLocalizedString`/`LocalizedStringKey` anywhere; `developmentRegion = en`,
`knownRegions = (en, Base)`. Every string is a hardcoded English literal.
**There is no LANGUAGE gap in the market** — Cupla ships Spanish, Amora claims 30+ locales,
Paired is multi-locale. A language gap is also the easiest kind to close, so it is not
defensible; the positional gap (proof loop + venue discovery) is.
Three iLovu-specific blockers if we ever do it:
1. **The content banks are the real cost** — 130 Daily Questions + 120 WYR + 36 Questions +
   the 165-card deck ≈ **451 pieces of content** needing warm on-brand translation. Machine
   translation will flatten the locked anti-pressure voice.
2. **`dailyAnswers` snapshots the question TEXT** (`DailyQuestionService.swift:38`), so two
   partners on different device languages would write different-language prompts into the
   same shared doc and the reveal would mismatch. **Language must be a PER-COUPLE setting on
   the couple doc, not per-device.** (The same design is what makes the bank expansion
   migration-free — it cuts the other way here.)
3. **The Near You deck cache is language-blind** — the only `languageCode` in
   `PlacesService.swift:272` is a decoded RESPONSE field; nothing sets it on a request.
   Language would have to join the cache key, multiplying cached decks per city — a direct
   hit to the locked "scale with venues, not users" cost rule.
**Recommendation: localize the App Store LISTING for es-MX/es-ES first** (cheap, reversible,
no binary change, tests demand). Localize the app only once the funnel holds.

---

## Pricing (locked)

$6.99/mo or $49.99/yr. **One subscription unlocks both partners — never split payment.** Founding offer: $39.99/yr for first 500 users. Push annual. On breakup: subscription follows the payer; both keep their own copy of shared memories.

---

## Current phase

**LAUNCHED — post-launch growth + hardening.** The app is live on the App Store (see CURRENT STATUS at top); the build-out below is the shipped feature inventory, and "Remaining" items are now the post-launch backlog. Top post-launch priorities, in order: **(1)** ✅ 1.0.2 RELEASED (Universal Links + Widgets + Hikes & Trails, 2026-07-20) — now **watch the funnel** (GA4 + BigQuery both live) to confirm `invite_created → invite_redeemed` actually recovers, **(2)** ✅ retention/growth batch SHIPPED in **1.0.3 (build 8) — LIVE** (share-cards, Would You Rather, wishlist, Memory Map + Year-in-Review, deck 140→165); on-device tests still worth doing, **(3)** RevenueCat webhook + App Check #4b, **(4)** ARPU expansion (the real $1M-MRR lever — date-booking/affiliate on the existing Places+Book-Now surface, physical memory books). See the growth analysis note below.

Shipped feature inventory: Auth ✓, invite/couple pairing ✓, real matching ✓, deep link ✓, name sync ✓, **Memory Vault sync ✓** (shared couple photo + proof photos via Firebase Storage; couple doc live-syncs name + photo via a snapshot listener), **paywall ✓** (`PaywallGate` — arms at 2nd match + 1st memory, or a 14-day backstop, never mid-celebration; **hard mode default ON** behind a reversible `hardMode` flag — presents at every calm mission-start + blocks until subscribed; soft show-once restored by flipping the flag — see decision above), **RevenueCat purchase/entitlement ✓** (real `Purchases.shared.purchase`/`restore` + live `premium` entitlement → couple-doc `isPremium` mirror — see decision above), **subscription status + Manage UI ✓** (status + StoreKit `showManageSubscriptions` deep-link in the Us tab; App Store 3.1.2 — see decision above), **Near You ✓** (curated Google Places, deck-cached; **venues now plannable as Missions** — date/time + checklist + partner-sync, with rich venue info (photos/hours/4★+ reviews/maps) on the mission — see decision above), **Push notifications ✓** (all 5 stages; match nudge + manual nudge + scheduled special-date reminders all live, verified on phone — see Push section). **Daily Question sync ✓** (committed `c28201b`, rules deployed, wired in `UsView`; only the on-device two-phone reveal test is outstanding — see decision above). Remaining: verify the RevenueCat **dashboard offering + App Store Connect products** are configured (external, not code — required for a real purchase to complete); the **RevenueCat webhook → Cloud Function** for authoritative grant/revoke (the v1 client-mirror revocation gap); further nudge types (on hold for tone testing); (test functions `runDateRemindersNow` + `helloWorld` both removed ✅); **Cloud Functions hardening sprint ✓** (App Check SDK/monitoring, cache-write gating, atomic invite redemption, Storage couple-membership via `coupleId` claim — all committed + pushed 2026-07-01), leaving **App Check enforcement (#4b)** as the one remaining hardening item (blocked on a parked debug-token 403).

**Events:** **DEPRIORITIZED / pivoted.** Eventbrite is dead (public API removed); Ticketmaster code is built but dormant until we target event-rich markets (London/US). No Facebook Events, no SerpApi. Near You ships on curated Places instead.
**Widgets ✓ (WIRED + BUILDING, on-device verified):** three static home-screen widgets — **Days Together**, **Next Date** (soonest upcoming Mission), **Latest Memory** (most recent proof photo). Architecture: the `iLovuWidgetExtension` target reads an **App Group** (`group.com.ilovu.app`) snapshot + a downscaled JPEG that the APP writes via `WidgetDataWriter` (digest-driven `.task(id: widgetDigest)` in `iLovuApp` → rewrites on couple/mission/memory change, then `WidgetCenter.reloadAllTimelines()`). Widget renders OFFLINE (no Firebase/network). **`WidgetShared.swift` is the ONE file in BOTH targets** (app + extension); `WidgetDataWriter.swift` stays app-only (UIKit/ImageCache). The extension uses a **synchronized folder group**, so every `.swift` in `iLovuWidget/` is auto-member — only `WidgetShared.swift` needs the manual cross-membership tick. App Group capability + entitlement on BOTH targets (confirmed in `iLovu.entitlements` + `iLovuWidgetExtension.entitlements`). `WidgetShared.containerURL == nil` → everything no-ops (pre-setup safe). Days-together recomputes from a stored `datingDate` at midnight (correct across day boundary without an app open). Setup steps: `WIDGETS_SETUP.md`. **NOT gated by premium — deliberate: widgets are a re-engagement surface, free = more app opens = more paywall exposure.** Copy is WARM, never guilt/streak-based.

**Onboarding (SHIPPED, lite):** `OnboardingView.swift` — welcome + concept + name/vibe collection (`@AppStorage`), gated by `hasCompletedOnboarding`. Relationship status is NOT collected there (set later via `CoupleService.setRelationshipStage`); progressive collection of dates after first match/memory stays the design. No spark rating (off-brand). **Flow is auth-FIRST** (ContentView routes signed-out → `SignInView`, then signed-in + not-onboarded → `OnboardingView`), so the welcome screen's old "Already have an account? Sign in" line was **dead/vestigial** (non-tappable Text; user is already signed in by then) and was **removed** — leaving just the working "Get Started →" CTA. Don't re-add a sign-in affordance to onboarding unless the funnel is deliberately flipped to marketing-first.
