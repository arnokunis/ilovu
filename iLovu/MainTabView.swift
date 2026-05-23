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

struct MainTabView: View {

    // The shared mission list. Injected at the app root.
    @Environment(MissionStore.self) private var missionStore

    // Cards is the headline feature so it's the default landing tab.
    @State private var selectedTab: AppTab = .cards

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

            SwipeView(matchedCard: $matchedCard, cardToShow: $cardToShow)
                .tabItem { Label("Cards", systemImage: "square.stack") }
                .tag(AppTab.cards)

            NearYouView(matchedEvent: $matchedEvent, eventToShow: $eventToShow)
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
}
