// MainTabView.swift
// The four-tab navigation skeleton that holds the whole app together.
// Shown immediately after onboarding completes. The Cards tab hosts
// the existing SwipeView; the other three are placeholders for now.
//
// IMPORTANT — the `matchedCard` state and the match `fullScreenCover`
// live here on the TabView (not inside SwipeView) so that:
//   1. The celebration cover overlays the entire app, including the
//      tab bar, regardless of which tab the user is on when the cover
//      gets presented.
//   2. SwipeView stays a leaf view that just reports up via a binding.

import SwiftUI
import FirebaseFirestore

struct MainTabView: View {

    // The shared mission list. Injected at the app root.
    @Environment(MissionStore.self) private var missionStore

    // Memory list + paywall gate, both injected at the app root. MainTabView is
    // where the couple's match count lives (the `celebrated` set), so it's the
    // natural place to feed the gate its match/memory counts as they change.
    @Environment(MemoryStore.self) private var memoryStore
    @Environment(PaywallGate.self) private var paywallGate

    // Couple link + matching, both injected at the app root. MainTabView is the
    // right home for the matches listener: it outlives any single tab, so a match
    // celebration can overlay the whole app no matter where the user is — and the
    // partner who didn't complete the match still gets it here.
    @Environment(CoupleService.self) private var coupleService
    @Environment(MatchService.self) private var matchService

    // Mirrors local mission edits to Firestore and feeds the missions listener
    // below. Injected at the app root, same as the services above.
    @Environment(MissionService.self) private var missionService

    // Memory Vault sync — feeds the memories listener below and is the upload
    // path behind MemoryStore.remoteUpsert. Injected at the app root.
    @Environment(MemoryService.self) private var memoryService

    // Shared date wishlist — store + its Firestore sync. MainTabView hosts the
    // wishlist listener alongside the mission/memory ones so a partner's add,
    // tick-off, or delete lands live.
    @Environment(BucketListStore.self) private var bucketListStore
    @Environment(BucketListService.self) private var bucketListService

    // RevenueCat entitlement. MainTabView is where premium is reconciled onto the
    // couple doc (subscribed-before-pairing) and where the effective premium
    // (mine OR the shared flag) is pushed into the paywall gate.
    @Environment(SubscriptionService.self) private var subscriptionService

    // Cards is the headline feature so it's the default landing tab.
    @State private var selectedTab: AppTab = .cards

    // The current couple's id now lives on the shared CoupleService (observable),
    // so it updates the instant pairing completes — including for the partner who
    // redeemed an invite mid-session. The swipe views fall back to placeholder
    // matching while it's nil, and the listener only starts once we have it.
    private var coupleId: String? { coupleService.coupleId }

    // The live matches listener, plus the coupleId it's attached for. We re-key
    // the listener whenever coupleId changes (nil -> paired), which is exactly the
    // transition the redeemer hits after redeeming. nil = not currently listening.
    @State private var matchListener: ListenerRegistration?
    @State private var listeningCoupleId: String?

    // The live missions listener, paired to the same couple as the match listener
    // above. Delivers remote mission creates/edits (e.g. the partner setting a
    // date/time) into the shared MissionStore.
    @State private var missionListener: ListenerRegistration?

    // The live memories listener (Memory Vault sync) and the couple-doc listener.
    // The latter republishes the couple on every change, so a partner's new name
    // or a changed couple photo lands live without a relaunch.
    @State private var memoryListener: ListenerRegistration?
    @State private var coupleListener: ListenerRegistration?

    // The live wishlist listener, paired to the same couple as the others.
    @State private var bucketListener: ListenerRegistration?

    // cardIds we've already celebrated on THIS device, persisted so old matches
    // don't replay their celebration on every launch. Keyed per couple. The
    // listener fires `.added` for every existing match on attach, so this guard
    // is what turns "deliver all matches" into "celebrate only the new ones".
    @State private var celebrated: Set<String> = []

    // Owned here so the full-screen cover can sit on the TabView itself.
    @State private var matchedCard: DateCard?

    // Same pattern for the Near You event swipe deck — a separate
    // binding because event matches present a different celebration
    // (EventMatchView with Book Now + Add to Calendar) than date
    // card matches (MatchView with Plan This Date).
    @State private var matchedEvent: LocalEvent?

    // When set, MissionDetailView is presented as a sheet over the
    // tab bar. Set by the "Plan This Date" flow after the match
    // celebration has dismissed.
    @State private var missionToPlan: Mission?

    // The EventDetailView sheet is owned here so two flows can
    // present it: tapping an event card on NearYouView, or tapping
    // View Details on the event match celebration.
    @State private var eventToShow: LocalEvent?

    // Tapped-but-not-swiped date card. Lives here for symmetry with
    // eventToShow — the detail sheet sits above the tab bar.
    @State private var cardToShow: DateCard?

    // Stage 5 push — the warm notification-permission ask. A mutual match is the
    // moment we ask (iOS only offers the one-shot prompt once ever, so we never
    // cold-ask). `pushAskPending` is armed in handleMatch when the OS status is
    // still .notDetermined; `showPushAsk` drives the partner-framed alert, which we
    // present only once the celebration cover is gone and nothing else is up.
    @State private var pushAskPending = false
    @State private var showPushAsk = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            SwipeView(matchedCard: $matchedCard, cardToShow: $cardToShow, coupleId: coupleId)
                .tabItem { Label("Cards", systemImage: "square.stack") }
                .tag(AppTab.cards)

            NearYouView(matchedEvent: $matchedEvent, eventToShow: $eventToShow, coupleId: coupleId)
                .tabItem { Label("Near You", systemImage: "mappin.and.ellipse") }
                .tag(AppTab.nearYou)

            UsView()
                .tabItem { Label("Us", systemImage: "heart.circle") }
                .tag(AppTab.us)
        }
        // Selected tab takes our brand coral. Unselected items use
        // iOS's default grey, which already matches the "soft grey"
        // we want — no UIKit appearance hack needed.
        .tint(Color.louvCoral)
        // Match cover lives on the TabView so it can fully overlay
        // the tab bar during the celebration.
        .fullScreenCover(item: $matchedCard) { card in
            MatchView(card: card) { mission in
                // Save to the store immediately so it's already
                // listed on the Home dashboard.
                missionStore.add(mission)
                // SwiftUI can't present a new modal while the cover
                // above is still mid-dismiss. Tiny delay lets the
                // cover finish, then we open the planning sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    missionToPlan = mission
                }
            }
        }
        // Planning sheet — opened from the match flow above and from
        // tapping a mission on the Home dashboard.
        .sheet(item: $missionToPlan) { mission in
            MissionDetailView(mission: mission)
        }
        // Event match celebration — independent of the date card
        // match cover above. Only one of these is ever visible at
        // a time because matchedCard and matchedEvent are bound to
        // separate decks.
        .fullScreenCover(item: $matchedEvent) { event in
            EventMatchView(event: event) { mission in
                // Plan This Date — identical to the card match flow: add the
                // mission so it's already on the Home dashboard, then open the
                // planning sheet once the cover finishes dismissing.
                missionStore.add(mission)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    missionToPlan = mission
                }
            } onViewDetails: {
                // View Details tapped — same delayed-present trick as
                // the mission flow, so the cover can finish dismissing
                // before the sheet starts coming up.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    eventToShow = event
                }
            }
        }
        // Event detail sheet. Two flows feed it: a tap on the Near You
        // deck, and the View Details button on EventMatchView.
        .sheet(item: $eventToShow) { event in
            EventDetailView(event: event)
        }
        // Date card detail sheet. Driven by tapping a card on the
        // Cards deck — swipes still like/nope through SwipeView's
        // drag gesture, only true taps land here.
        .sheet(item: $cardToShow) { card in
            DateCardDetailView(card: card)
        }
        // On appear, resolve the couple from Firestore (covers a cold launch when
        // already paired). This publishes into coupleService.couple, which flips
        // coupleId and trips the onChange below.
        .task {
            _ = try? await coupleService.currentCouple()
            syncCoupleListeners()
        }
        // React the moment coupleId changes — most importantly nil -> paired right
        // after the redeemer redeems an invite, without waiting for a relaunch.
        .onChange(of: coupleId) { _, _ in syncCoupleListeners() }
        // Keep the gate's "subscribed" decision live: it flips when MY entitlement
        // changes (purchase/restore/expiry) OR when the partner's purchase lands on
        // the shared couple doc (couple listener republishes isPremium).
        .onChange(of: subscriptionService.myEntitlementActive) { _, _ in updatePremiumGate() }
        .onChange(of: coupleService.couple?.isPremium) { _, _ in updatePremiumGate() }
        // Pull the remotely tunable paywall config once per launch.
        .task { await loadPaywallConfig() }
        // Stamp "first seen" for the CURRENT paywall scope — including a solo one.
        // This is what arms the 14-day backstop for users who never plan 2 Missions
        // and never hit the daily swipe cap; without it they had no path to the
        // wall at all. Keyed on the scope so it re-runs at sign-in and at pairing.
        //
        // Safe against the couple path: noteScopeActive only writes when the stamp
        // is ABSENT unless given an explicit date, and syncCoupleListeners passes
        // the authoritative server createdAt, which always wins regardless of order.
        // The `guard let … else { return }` this replaces meant a nil scope never
        // stamped "first seen", so the 14-day backstop clock never STARTED for
        // those users — the third of the three fail-open gate paths.
        .task(id: coupleService.paywallScopeId) {
            paywallGate.noteScopeActive(scopeId: coupleService.paywallScope("launch"))
        }
        // When a match celebration cover dismisses, see if a warm push ask is
        // queued. Watched on both decks because either celebration can be the
        // first match. maybePresentPushAsk re-checks we're truly idle first.
        .onChange(of: matchedCard) { _, newValue in if newValue == nil { maybePresentPushAsk() } }
        .onChange(of: matchedEvent) { _, newValue in if newValue == nil { maybePresentPushAsk() } }
        // The warm, partner-framed permission ask. Anti-pressure brand: no time/
        // guilt framing, and "Not now" simply defers — we never lose the iOS
        // one-shot prompt because the SYSTEM prompt only fires on "Sounds good".
        .alert("Stay in the loop 💛", isPresented: $showPushAsk) {
            Button("Sounds good") { Task { await PushAuthorization.request() } }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Want a heads-up when \(pushAskPartnerName) is ready to plan a date together?")
        }
        // Detach the listeners if this view ever goes away (hygiene — they
        // normally live for the whole signed-in session).
        .onDisappear { detachCoupleListeners() }
    }

    /// The partner's first name for the push ask copy, or a warm fallback.
    private var pushAskPartnerName: String {
        coupleService.partnerDisplayName ?? "your partner"
    }

    /// Presents the warm push ask IF one is queued and we're genuinely idle — no
    /// celebration cover, no mission/detail sheet. Called when a match cover
    /// dismisses; the short delay lets the "Plan This Date" flow win the race (it
    /// opens the mission sheet ~0.45s after the cover), in which case we hold the
    /// ask for the next match rather than stacking a system prompt under a sheet.
    private func maybePresentPushAsk() {
        guard pushAskPending else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard pushAskPending,
                  matchedCard == nil, matchedEvent == nil,
                  missionToPlan == nil, eventToShow == nil, cardToShow == nil else { return }
            pushAskPending = false
            showPushAsk = true
        }
    }

    // MARK: - Couple listeners (matches + missions)

    /// Attaches the app-level matches and missions listeners for the current
    /// couple, re-keying if the couple changed and tearing down if we became
    /// unpaired. Idempotent — safe to call from both the initial .task and every
    /// coupleId change.
    private func syncCoupleListeners() {
        guard let id = coupleId else { return }     // not paired yet — nothing to attach
        guard id != listeningCoupleId else { return } // already listening for this couple

        detachCoupleListeners()
        listeningCoupleId = id
        celebrated = loadCelebrated(for: id)

        // Feed the paywall gate the current couple state on attach (also covers
        // the 14-day backstop on a cold launch with no new match/memory). The
        // server createdAt is preferred when resolved; nil falls back to a
        // first-seen stamp inside the gate.
        paywallGate.noteScopeActive(scopeId: id, createdAt: coupleService.couple?.createdAt?.dateValue())
        paywallGate.recordMatchCount(celebrated.count, scopeId: id)
        paywallGate.recordMemoryCount(memoryStore.memories.count, scopeId: id)

        // Premium reconcile: if this user is already subscribed (including
        // subscribed-BEFORE-pairing, which the entitlement callback couldn't
        // mirror because no couple existed yet), stamp the shared flag now that
        // the couple is present. Then push effective premium into the gate.
        Task { await coupleService.syncPremiumEntitlement(subscriptionService.myEntitlementActive) }
        // Push up anything set before pairing (dating date, relationship status).
        // Non-destructive: a value the partner already set always wins.
        Task { await coupleService.flushSoloRelationshipDetails() }
        // Keep the couple's timezone current so scheduled pushes land at a sane
        // LOCAL hour. No-ops unless it actually changed (travel, or first write).
        Task { await coupleService.syncTimeZone() }
        updatePremiumGate()

        matchListener = matchService.observeMatches(coupleId: id) { match in
            handleMatch(match)
        }
        missionListener = missionService.observeMissions(
            coupleId: id,
            onUpsert: { remote in applyRemoteMission(remote) },
            onRemove: { cardId in missionStore.removeFromRemote(cardId: cardId) }
        )
        memoryListener = memoryService.observeMemories(
            coupleId: id,
            onUpsert: { remote in applyRemoteMemory(remote) },
            onRemove: { memoryId in memoryStore.removeFromRemote(id: memoryId) }
        )
        // Live couple-doc updates (partner name + couple photo freshness).
        coupleListener = coupleService.observeCouple()
        // Shared wishlist: deliver the partner's items (add/tick/remove) into the
        // local store, converting the Firestore shape back to BucketListItem.
        bucketListener = bucketListService.observeItems(
            coupleId: id,
            onUpsert: { remote in if let item = remote.asItem() { bucketListStore.mergeFromRemote(item) } },
            onRemove: { itemId in bucketListStore.removeFromRemote(id: itemId) }
        )
        // Migrate any local-only memories (pre-Storage, or saved while unpaired)
        // up to Storage now that we have a couple. Idempotent.
        memoryStore.resyncUnsynced()
        // Same migration for wishlist items added while unpaired.
        bucketListStore.resyncAll()
    }

    /// Pushes the effective couple-shared premium (my own entitlement OR the
    /// shared couple-doc flag) into the paywall gate, which stops presenting the
    /// wall once true. Cheap; called on attach and whenever either input changes.
    private func updatePremiumGate() {
        paywallGate.isSubscribed = subscriptionService.premiumActive(couple: coupleService.couple)
    }

    /// Reads the remotely tunable paywall config from `config/paywall`, once per
    /// launch. Deliberately Firestore rather than Firebase Remote Config: Remote
    /// Config is NOT linked in this project and Firestore already is, so this adds
    /// no dependency for one integer.
    ///
    /// Why it must be remote: the swipe cap number is a genuine guess until
    /// `swipe_made` data lands, and Near You is the only surface most (unpaired)
    /// users reach — a cap set too low suppresses the single activation surface.
    /// This lets it be retuned, or switched off with `soloSwipeCap: 0`, in minutes
    /// instead of an App Store release. Any failure (offline, rules, missing doc)
    /// silently keeps the built-in default, which is the safe direction.
    private func loadPaywallConfig() async {
        guard let snap = try? await Firestore.firestore()
            .collection("config").document("paywall").getDocument(),
              let cap = snap.data()?["soloSwipeCap"] as? Int
        else { return }
        paywallGate.swipeCap = cap
    }

    private func detachCoupleListeners() {
        matchListener?.remove()
        matchListener = nil
        missionListener?.remove()
        missionListener = nil
        memoryListener?.remove()
        memoryListener = nil
        coupleListener?.remove()
        coupleListener = nil
        bucketListener?.remove()
        bucketListener = nil
        listeningCoupleId = nil
    }

    /// Rebuilds a full Mission from a synced RemoteMission and merges it into the
    /// store. A date-card mission's card lives in the static SampleCards deck; a
    /// Near You VENUE mission's card doesn't, so for `.places` we rebuild it from
    /// the SHARED venue cache by placeId (cardId == placeId) — exactly like the
    /// `.places` MATCH rebuild. Runs on the main actor (SampleCards stays
    /// main-isolated). Skips a card this build can't resolve.
    private func applyRemoteMission(_ remote: RemoteMission) {
        if let card = SampleCards.byId(remote.cardId) {
            mergeRemoteMission(remote, into: card)
        } else if remote.deck == Deck.places.rawValue {
            // A planned Near You venue. Async — merge once the cache read lands.
            // If the venue isn't cached yet, skip; the planner already cached it at
            // match time, and a later listener fire resolves any cold-cache gap.
            Task { @MainActor in
                guard let venue = await VenueCache().venue(forId: remote.cardId)?.asLocalEvent()
                else { return }
                mergeRemoteMission(remote, into: DateCard(fromVenue: venue))
            }
        }
        // Otherwise an unknown date card this build doesn't ship — skip (unchanged).
    }

    /// Shared merge: builds the Mission from a resolved DateCard + the remote
    /// planning state and hands it to the store. Used by both the SampleCards and
    /// the venue-cache rebuild paths above.
    private func mergeRemoteMission(_ remote: RemoteMission, into card: DateCard) {
        let checklist = remote.checklist.map { item in
            Mission.ChecklistItem(
                id: UUID(uuidString: item.id) ?? UUID(),
                title: item.title,
                done: item.done
            )
        }

        let mission = Mission(
            card: card,
            status: Mission.Status(rawValue: remote.status) ?? .upcoming,
            scheduledDate: remote.scheduledDate?.dateValue(),
            budget: remote.budget,
            // A remote doc should always carry the 3 seed items; fall back to a
            // fresh seed if it somehow arrived empty so the checklist UI isn't blank.
            checklist: checklist.isEmpty ? Mission(from: card).checklist : checklist
        )
        missionStore.mergeFromRemote(mission)
    }

    /// Rebuilds a Memory from a synced RemoteMemory and merges it into the store.
    /// Photo bytes aren't carried in the doc — photoData stays nil and the vault
    /// downloads from `storagePath` via the cache. Skips a doc with a malformed id.
    private func applyRemoteMemory(_ remote: RemoteMemory) {
        guard let idString = remote.id, let uuid = UUID(uuidString: idString) else { return }
        let memory = Memory(
            id: uuid,
            dateCompleted: remote.dateCompleted.dateValue(),
            cardTitle: remote.cardTitle,
            cardEmoji: remote.cardEmoji,
            photoData: nil,
            rating: remote.rating,
            note: remote.note,
            storagePath: remote.storagePath,
            createdBy: remote.createdBy,
            photoVersion: remote.photoVersion ?? 1,
            latitude: remote.latitude,
            longitude: remote.longitude
        )
        memoryStore.mergeFromRemote(memory)

        // Remote-synced memory → update the gate's memory count too, so the
        // partner who RECEIVES a memory arms Condition A without a relaunch.
        // Mirrors local completion (MissionDetailView) + attach: same source the
        // gate reads (memoryStore.memories.count). Read-side gate counting only.
        if let id = coupleId {
            paywallGate.recordMemoryCount(memoryStore.memories.count, scopeId: id)
        }
    }

    /// Called for every match the listener delivers (existing + live). Presents
    /// the right celebration the first time we see each cardId, then remembers it
    /// so it never replays. The match doc is id-only, so we rebuild the full card
    /// from local sample data via SampleCards/SampleEvents.byId.
    private func handleMatch(_ match: CardMatch) {
        // Record the match for the Missions list BEFORE the celebrated guard —
        // that guard returns early for matches already celebrated in a previous
        // session, so anything after it would never see them and the badge would
        // vanish on relaunch.
        missionStore.matchedCardIds.insert(match.cardId)

        guard !celebrated.contains(match.cardId) else { return }
        celebrated.insert(match.cardId)
        persistCelebrated()

        // New match → update the gate's match count. This only ARMS the gate;
        // it never presents here (mid-celebration). The wall waits for the next
        // calm mission-start in HomeView.
        if let id = coupleId {
            paywallGate.recordMatchCount(celebrated.count, scopeId: id)
        }

        // Stage 5 push: a real match is the warm, partner-relevant moment to ask
        // for notification permission. Only arm if iOS still holds the one-shot
        // prompt (.notDetermined); maybePresentPushAsk shows it once the
        // celebration is gone. Granted/denied users never see it again.
        Task { @MainActor in
            if await PushAuthorization.status() == .notDetermined {
                pushAskPending = true
            }
        }

        switch Deck(rawValue: match.deck) {
        case .dates:
            if let card = SampleCards.byId(match.cardId) { matchedCard = card }
        case .events:
            // The match doc is id-only, so rebuild the full event from its cardId.
            // Sample/offline events resolve synchronously from the local array;
            // a REAL Ticketmaster event (cardId == the TM event id) is rebuilt from
            // the SHARED event cache, since the partner who didn't swipe may never
            // have held it in a local array. Async — present once it lands.
            if let event = SampleEvents.byId(match.cardId) {
                matchedEvent = event
            } else {
                Task { @MainActor in
                    if let event = await EventCache().event(forId: match.cardId) {
                        matchedEvent = event
                    }
                }
            }
        case .places:
            // A real Google Places venue (cardId == placeId): rebuild from the
            // SHARED venue cache so the partner who didn't swipe can celebrate it.
            // Async — present once the cache read lands.
            Task { @MainActor in
                if let event = await VenueCache().venue(forId: match.cardId)?.asLocalEvent() {
                    matchedEvent = event
                }
            }
        case .none:
            break
        }
    }

    // MARK: - Celebrated-set persistence
    // UserDefaults-backed, keyed per couple so re-pairing starts clean. Same
    // lightweight local-persistence approach as MissionStore / MemoryStore.

    private func celebratedKey(_ coupleId: String) -> String {
        "celebratedMatches.\(coupleId)"
    }

    private func loadCelebrated(for coupleId: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: celebratedKey(coupleId)) ?? [])
    }

    private func persistCelebrated() {
        guard let coupleId else { return }
        UserDefaults.standard.set(Array(celebrated), forKey: celebratedKey(coupleId))
    }
}

// The four top-level tabs. Named `AppTab` (not `Tab`) to avoid
// colliding with SwiftUI's iOS 18 `Tab` type.
//
// No longer `private` — HomeView needs to reference this type so it
// can accept a Binding<AppTab> and switch the user over to the Cards
// tab when "Swipe Tonight →" is tapped.
enum AppTab: Hashable {
    case home, cards, nearYou, us
}

#Preview {
    MainTabView()
        .environment(MissionStore())
        .environment(MemoryStore())
        .environment(CoupleService())
        .environment(MatchService())
        .environment(MissionService())
        .environment(MemoryService())
        .environment(PaywallGate())
        .environment(SubscriptionService())
        .environment(DailyQuestionService())
}
