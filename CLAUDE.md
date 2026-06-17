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
- **Google Places API (New)** — venue data, read-through cached to Firestore
- **RevenueCat** (planned, not yet integrated) — paywall/trial/A-B testing
- **Ticketmaster + Eventbrite** (Phase 3, not yet built) — events
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
  // PLANNED: status, subscriptionOwner (entitlement follows on breakup), entitlement

couples/{coupleId}/swipes/{cardId}       // a right-swipe; this is where likes live (CardSwipe model)
  cardId, deck, likedBy: [uid…], updatedAt   // each user arrayUnions ONLY their own uid into likedBy
couples/{coupleId}/matches/{cardId}      // deterministic doc ID = idempotent, no race dupes
  cardId, deck, createdAt

couples/{coupleId}/missions/{missionId}  // PLANNED — missions persist to UserDefaults today (MissionStore)
couples/{coupleId}/memories/{memoryId}   // PLANNED — memories persist to UserDefaults today (MemoryStore)

invites/{token}                          // Invite.swift — doc ID IS the token (unguessable, single-use)
  creatorId, status ("pending"|"consumed"), consumedBy (null until redeemed), createdAt
  // no expiresAt yet; single-use is enforced via status + firestore.rules

venues/{placeId}                         // world-readable cache
venueQueries/{queryKey}                  // read-through cache, stale-while-revalidate (>7 days)
```

### Real matching — client-side intersection, no Cloud Functions
Lives in `MatchService`: `recordLike(coupleId:cardId:deck:)` + `observeMatches(coupleId:onMatch:)`. On a right-swipe each partner `arrayUnion`s their own uid into `couples/{coupleId}/swipes/{cardId}.likedBy`; a strongly-consistent read-after-write detects when both UIDs are present and creates the match doc. The match doc uses the card ID as its doc ID, so a both-liked-at-once race collapses to one idempotent doc. The partner who didn't complete the match is notified via an app-level `matches` snapshot listener (dedupe against a *persisted* set of celebrated cardIds, or every past match replays on launch). **Unpaired → falls back to `Bool.random()` solo celebration** (`SwipeView.swift:214`). Both phones must complete pairing before real matching works.

### Invite link — custom scheme now, Universal Links later
`ilovu://invite/<token>` via Info.plist + `onOpenURL`, parsed by `CoupleService.inviteToken(from:)` / built by `inviteURL(token:)`. The invite lifecycle is `CoupleService.createInvite()` → `redeem(token:)` → `currentCouple()`. **Firebase Dynamic Links is dead (shut down Aug 25 2025)** — do not use it. Custom scheme only resolves if the app is already installed; manual "Have a code?" field is the backup. Universal Links via `ilovu.io` (AASA on Netlify) + deferred deep-linking is the future upgrade.

### Cost architecture (critical — 95% margin target)
Naive per-user live Places fetching is catastrophic (~$16k/mo at 300 users). **Cache everything**: fetch each venue once to Firestore, serve both card and detail from cache. Scales with venues, not users. Set a Billing budget alert the moment paid billing is attached.

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
- Security is day-one, not retrofitted: Firestore rules, single-use invite tokens, photo/Vault access control all built in (token *expiry* is a planned addition, not yet implemented). Pre-launch: move cache writes + invite redemption to Cloud Functions (currently client-authed); move `Memory.photoData` from UserDefaults to FileManager.

---

## Pricing (locked)

$6.99/mo or $49.99/yr. **One subscription unlocks both partners — never split payment.** Founding offer: $39.99/yr for first 500 users. Push annual. On breakup: subscription follows the payer; both keep their own copy of shared memories.

---

## Current phase

**Phase 2 (Firebase) — in progress.** Auth ✓, invite/couple pairing ✓, real matching ✓, deep link ✓ (per last verification). Remaining: RevenueCat paywall (soft wall — let users finish celebrating, wall at next mission), Cloud Functions for atomic redeem + cache writes, FileManager photo storage, NearYou→venue cache wiring.

**Phase 3:** Events (Ticketmaster, then Eventbrite — one at a time. No Facebook Events, no SerpApi).
**Phase 4:** Polish + launch. Post-launch priority: iOS shared widgets (next-Mission, Memory-photo, days-together) — keep WARM, not guilt-tripping.

**Onboarding (to build):** SHORT — name, vibe, relationship status only. Progressive collection of dates after first match/memory, fully skippable. No spark rating (off-brand).
