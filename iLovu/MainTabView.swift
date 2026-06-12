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

    // Couple link + matching, both injected at the app root. MainTabView is the
    // right home for the matches listener: it outlives any single tab, so a match
    // celebration can overlay the whole app no matter where the user is — and the
    // partner who didn't complete the match still gets it here.
    @Environment(CoupleService.self) private var coupleService
    @Environment(MatchService.self) private var matchService

    // Cards is the headline feature so it's the default landing tab.
    @State private var selectedTab: AppTab = .cards

    // The current couple's id, resolved once on appear. nil until resolved (or if
    // the user isn't paired yet) — the swipe views fall back to placeholder
    // matching while it's nil, and the listener only starts once we have it.
    @State private var coupleId: String?

    // The live matches listener. Held so we can detach it on disappear.
    @State private var matchListener: ListenerRegistration?

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
            EventMatchView(event: event) {
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
        // Resolve the couple + start the matches listener once the tabs appear.
        .task { await startMatching() }
        // Detach the listener if this view ever goes away (hygiene — it normally
        // lives for the whole signed-in session).
        .onDisappear {
            matchListener?.remove()
            matchListener = nil
        }
    }

    // MARK: - Matching

    /// Resolves the current couple and attaches the app-level matches listener.
    /// No-op if already started or if the user isn't paired (matching needs a
    /// partner; until then the swipe views use the placeholder coin-flip).
    private func startMatching() async {
        guard coupleId == nil else { return }   // already resolved
        do {
            guard let couple = try await coupleService.currentCouple(),
                  let id = couple.id else { return }
            coupleId  = id
            celebrated = loadCelebrated(for: id)
            matchListener = matchService.observeMatches(coupleId: id) { match in
                handleMatch(match)
            }
        } catch {
            // Silent — without a resolvable couple there's simply no matching.
        }
    }

    /// Called for every match the listener delivers (existing + live). Presents
    /// the right celebration the first time we see each cardId, then remembers it
    /// so it never replays. The match doc is id-only, so we rebuild the full card
    /// from local sample data via SampleCards/SampleEvents.byId.
    private func handleMatch(_ match: CardMatch) {
        guard !celebrated.contains(match.cardId) else { return }
        celebrated.insert(match.cardId)
        persistCelebrated()

        switch Deck(rawValue: match.deck) {
        case .dates:
            if let card = SampleCards.byId(match.cardId) { matchedCard = card }
        case .events:
            if let event = SampleEvents.byId(match.cardId) { matchedEvent = event }
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
        .environment(CoupleService())
        .environment(MatchService())
}
