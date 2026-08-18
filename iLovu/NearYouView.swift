// NearYouView.swift
// The real Near You tab — a swipe deck for local events, modelled
// to feel identical to the date-card SwipeView. Same drag physics,
// same threshold, same LIKE/NOPE stamps, same haptics, same coin-
// flip match. The only differences are the data type (LocalEvent
// instead of DateCard), the filter (Category instead of Difficulty),
// and the card content (event meta + optional rating row).
//
// Events here are sample data from SampleEvents. Later this list
// becomes results from Google Places + Eventbrite — the swipe deck
// itself doesn't change.

import SwiftUI
import CoreLocation

struct NearYouView: View {

    // MARK: - State

    // Starts EMPTY and loads on .task — real Ticketmaster events through
    // EventCache when a key is configured, SampleEvents as the silent fallback
    // (no key / no results / offline). Loading once before interaction avoids
    // swapping the deck out from under a mid-swipe finger.
    @State private var deck: [LocalEvent] = []
    @State private var isLoading = true

    // How many cards the user has swiped this session. A late reload (permission
    // granted, or pairing completed) only re-fetches the deck if it's still
    // untouched, so we never reset cards out from under an active session.
    @State private var swipedCount = 0

    @State private var dragOffset: CGSize = .zero

    // Owned here like EventDetailView owns its own — the deck biases its event
    // search to roughly where the user is, falling back to London until a fix.
    @State private var locationManager = LocationManager()

    // Set on a right-swipe match. Parent (MainTabView) watches and
    // presents EventMatchView via .fullScreenCover. Same pattern as
    // the date card matchedCard binding.
    @Binding var matchedEvent: LocalEvent?

    // Tapping a card (without swiping) sets this. MainTabView owns
    // the actual sheet so that both the tap-to-detail path and the
    // View-Details-from-match path can present the same screen.
    @Binding var eventToShow: LocalEvent?

    // Current couple's id from MainTabView. Present => real likes via MatchService
    // (celebration driven by MainTabView's listener); nil => placeholder coin-flip.
    let coupleId: String?

    @Environment(MatchService.self) private var matchService

    // Read for the SHARED event-location bucket (so both partners load one deck)
    // and written when this device claims/re-anchors it. nil-couple => solo deck.
    @Environment(CoupleService.self) private var coupleService
    // Needed so a SOLO right-swipe can save the venue as a Mission directly.
    // MissionStore persists locally and its remoteUpsert is nil when unpaired,
    // so this works with no couple and no Firestore write.
    @Environment(MissionStore.self) private var missionStore

    /// Venue just saved by a solo right-swipe — drives the brief confirmation
    /// toast. Nil hides it.
    @State private var savedVenueName: String? = nil

    // Swipe-cap paywall. Near You reaches ~67% of onboarded users vs ~33% for
    // mission-open, so this is the trigger that actually gets the wall in front
    // of people — hence its own presentation here rather than routing through
    // HomeView.
    @Environment(PaywallGate.self) private var paywallGate
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showPaywall = false

    @State private var selectedCategory: LocalEvent.Category? = nil

    /// Food & Drink sub-filter. Only reachable while Food & Drink is the selected
    /// category, and cleared whenever the category changes or the deck reloads —
    /// so it can never silently narrow a deck whose pill row isn't even showing.
    @State private var selectedCuisine: PlaceCuration.Cuisine? = nil

    /// The filter pills for THIS deck, snapshotted when it loads.
    ///
    /// Deliberately NOT derived from `deck` on every render: completeSwipe REMOVES
    /// each swiped card from `deck`, so a live-derived list made pills disappear
    /// mid-session. Swipe the last steakhouse and the "Steak & Seafood" pill
    /// vanished from under the user's finger, reflowing the row — and when the last
    /// cuisine went, the whole second row collapsed and shifted the card stack up
    /// into the tap, which is how tapping a pill could end up opening a card.
    /// Small buckets (steak, burgers) hit this first, which is exactly where it was
    /// reported.
    ///
    /// Snapshotting keeps the row stable for the session. A pill whose cards have
    /// all been swiped simply shows the existing "that's everything" empty state —
    /// the honest outcome, and one the user can tap straight back out of.
    @State private var deckCategories: [LocalEvent.Category] = []
    @State private var deckCuisines: [PlaceCuration.Cuisine] = []

    // Manual location search ("Search here" / plan a trip by typing a city).
    @State private var townQuery = ""
    @State private var isGeocoding = false
    @State private var searchError: String? = nil
    // City search runs in a native alert text field, NOT an inline one — an inline
    // field's keyboard shoved the whole deck layout up and hid the search box.
    @State private var showCitySearch = false

    /// A travel move only overrides an OLDER stored bucket than this, so two
    /// co-located partners straddling a ~1km bucket boundary don't ping-pong the
    /// shared deck back and forth on every open.
    private let reanchorDebounce: TimeInterval = 12 * 60 * 60

    /// A move farther than this from the stored bucket is real travel, not
    /// boundary jitter, so it re-anchors the shared deck IMMEDIATELY (ignoring the
    /// 12h debounce) — the fix for "drove 60km, still seeing the old town".
    private let travelReanchorKm: Double = 20

    // Same threshold as SwipeView — keeps the muscle memory identical.
    private let swipeThreshold: CGFloat = 120

    private var visibleDeck: [LocalEvent] {
        var result = deck
        if let selectedCategory {
            result = result.filter { $0.category == selectedCategory }
        }
        if let selectedCuisine {
            result = result.filter { PlaceCuration.cuisine(forPrimaryType: $0.primaryType) == selectedCuisine }
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                    .padding(.top, 16)

                // Trip planning + "search here" — a paired-only surface (a solo
                // deck already follows live GPS, so there's nothing to override).
                if coupleId != nil {
                    locationBar
                }

                filterPills

                Spacer()

                ZStack {
                    if isLoading && deck.isEmpty {
                        loadingState
                    } else if visibleDeck.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(visibleDeck.prefix(2).enumerated()), id: \.element.id) { index, event in
                            cardView(for: event)
                                .zIndex(Double(1 - index))
                        }
                    }
                }
                .frame(maxWidth: 340, maxHeight: 480)
                // Hard-clip the card stack's HIT AREA to its own box (2026-08-16).
                // Reported: tapping a category pill sometimes opened a venue photo
                // instead — i.e. the card's tap handler fired for a touch up in the
                // pill row. contentShape + clipped means a touch outside these
                // bounds can never reach a card, whatever the column height does.
                // Belt and braces with the maxHeight change on the card itself:
                // that stops the overflow, this stops it mattering.
                .clipped()
                .contentShape(Rectangle())
                .padding(.horizontal, 24)

                Spacer()

                actionButtons
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // City search lives in a native alert so its keyboard can never push the
        // deck layout around (the inline-field bug). Search geocodes + pins the
        // shared anchor; Cancel clears the draft.
        .alert("Search a city", isPresented: $showCitySearch) {
            TextField("City (e.g. Palanga)", text: $townQuery)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button("Search", action: searchTown)
            Button("Cancel", role: .cancel) { townQuery = "" }
        } message: {
            Text("See date spots there and plan a trip together.")
        }
        // Load the deck once on appear (real events via EventCache, or the
        // SampleEvents fallback). .task is cancelled automatically on disappear.
        .task {
            logNearYouVisit()
            await loadDeck()
        }
        // Swipe-cap wall. Mirrors HomeView's sheet so the purchase path is
        // identical wherever the wall fires.
        .sheet(isPresented: $showPaywall, onDismiss: {
            AppAnalytics.log("paywall_dismissed", ["trigger": "swipe_limit"])
        }) {
            PaywallView(
                isPaired:           coupleId != nil,
                annualPriceText:    subscriptionService.annualDisplay?.priceText,
                annualPerMonthText: subscriptionService.annualDisplay?.perMonthText,
                monthlyPriceText:   subscriptionService.monthlyDisplay?.priceText,
                onPurchase: { plan in
                    switch plan {
                    case .annual:  await subscriptionService.purchaseAnnual()
                    case .monthly: await subscriptionService.purchaseMonthly()
                    }
                },
                onRestore: { await subscriptionService.restore() }
            )
            .task { await subscriptionService.loadOfferings() }
        }
        // Solo save confirmation. Deliberately a light toast, NOT a full-screen
        // cover: a right-swipe is a cheap, repeated action and interrupting every
        // one of them would suppress exactly the swipe volume we now want. Copy is
        // honest — nothing "matched", the venue was saved.
        .overlay(alignment: .bottom) {
            if let savedVenueName {
                Text("Saved to your plans 💛 · \(savedVenueName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.louvCoral, in: Capsule())
                    .shadow(radius: 8, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: savedVenueName) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(LouvAnimation.spring) { self.savedVenueName = nil }
                    }
            }
        }
        // If location permission is granted AFTER the first load, or the couple
        // link completes mid-session, re-fetch — but only while the deck is still
        // untouched, so an active swipe session is never reset.
        .onChange(of: locationManager.hasPermission) { _, _ in reloadIfUntouched() }
        // When the first real GPS fix lands after launch, re-fetch so we anchor to
        // the true location (not the London fallback) instead of waiting a session.
        .onChange(of: locationManager.hasFix) { _, _ in reloadIfUntouched() }
        .onChange(of: coupleId) { _, _ in reloadIfUntouched() }
    }

    // MARK: - Location search bar

    /// Trip-planning row: a city search that pins BOTH partners' shared deck to a
    /// destination, plus a chip that reflects/clears the current pin.
    @ViewBuilder
    private var locationBar: some View {
        VStack(spacing: 8) {
            // Tapping opens a native alert text field (see the .alert in body) —
            // deliberately NOT an inline TextField, whose keyboard pushed the deck
            // layout up and hid this row.
            Button {
                townQuery = ""
                searchError = nil
                showCitySearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.gray)
                    Text("Plan a trip — search a city")
                        .font(.system(size: 15))
                        .foregroundStyle(.gray)
                    Spacer()
                    if isGeocoding { ProgressView().scaleEffect(0.7) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                if coupleService.eventLocationManual,
                   let label = coupleService.eventLocationLabel {
                    Label(label, systemImage: "mappin.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.deepRose)
                    Button(action: searchHere) {
                        Label("Use my location", systemImage: "location.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                } else {
                    Button(action: searchHere) {
                        Label("Search here", systemImage: "location.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                }
                if let searchError {
                    Text(searchError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            // The screen title IS the header — no redundant "iLovu" wordmark
            // (it's already the app name in the tab bar). See HomeView for the
            // matching cleanup.
            Text("Near You 📍")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.deepRose)
            Text(headerSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.gray)
        }
    }

    /// Subtitle reflects the active deck source (venues at launch, not events).
    private var headerSubtitle: String {
        switch NearYouConfig.source {
        case .places: return "Cosy spots near you, picked for two"
        case .events: return "Events near you this week"
        case .both:   return "Date spots & events near you"
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func cardView(for event: LocalEvent) -> some View {
        let isTop = event.id == visibleDeck.first?.id

        // Identical stamp opacity math to SwipeView — both decks share
        // the same SwipeStamp view so the rendering is literally the
        // same code, only the opacity-drive math is duplicated locally.
        let likeOpacity = isTop ? min(max(dragOffset.width / swipeThreshold, 0), 1) : 0
        let nopeOpacity = isTop ? min(max(-dragOffset.width / swipeThreshold, 0), 1) : 0

        EventCardContent(event: event)
            // maxWidth/maxHeight, NOT a fixed frame (2026-08-16). A fixed
            // .frame(height: 480) does not shrink when the column is short, so the
            // card OVERFLOWED its maxHeight-480 container and slid up under the
            // filter pills — while still receiving touches. Because the gesture
            // below uses minimumDistance 0, it then claimed horizontal drags meant
            // for the pills' ScrollView and the category row stopped scrolling.
            // Worst under Food & Drink, the one category that adds a cuisine
            // sub-row (~40pt), and on paired accounts, which also show locationBar.
            .frame(maxWidth: 340, maxHeight: 480)
            .background(Color.white)
            .overlay(alignment: .topLeading) {
                SwipeStamp(text: "LIKE", color: .matchGreen, rotation: -18)
                    .opacity(likeOpacity)
            }
            .overlay(alignment: .topTrailing) {
                SwipeStamp(text: "NOPE", color: .passRed, rotation: 18)
                    .opacity(nopeOpacity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.deepRose.opacity(0.12), lineWidth: 1)
            )
            .louvShadow()
            .scaleEffect(isTop ? 1.0 : 0.95)
            .rotationEffect(isTop ? .degrees(Double(dragOffset.width / 20)) : .degrees(-3))
            .offset(isTop ? dragOffset : .zero)
            // ONE gesture decides tap-vs-swipe, rather than a DragGesture and an
            // .onTapGesture racing. As two independent recognizers they could both
            // claim the same touch, so a quick flick sometimes swiped the card AND
            // opened its detail sheet ("I swipe left and the image opens"). Deciding
            // once in onEnded makes the two outcomes mutually exclusive.
            .gesture(dragGesture(for: event))
            .allowsHitTesting(isTop)
    }

    // MARK: - Drag Gesture

    /// Movement below this reads as a TAP (open the detail) rather than a drag.
    /// Same 10pt as DragGesture's default minimumDistance, which is what used to
    /// separate the two recognizers before they were merged into one.
    private let tapSlop: CGFloat = 10

    private func dragGesture(for event: LocalEvent) -> some Gesture {
        // minimumDistance 0 so this gesture sees the whole touch — including one
        // that turns out to be a tap. The card still doesn't MOVE until the touch
        // passes tapSlop, so a tap looks exactly like a tap.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard max(abs(value.translation.width), abs(value.translation.height)) > tapSlop else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard max(abs(value.translation.width), abs(value.translation.height)) > tapSlop else {
                    // Never moved: a tap. Open the detail and swipe nothing.
                    dragOffset = .zero
                    eventToShow = event
                    return
                }
                if value.translation.width > swipeThreshold {
                    completeSwipe(direction: .right)
                } else if value.translation.width < -swipeThreshold {
                    completeSwipe(direction: .left)
                } else {
                    withAnimation(LouvAnimation.spring) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Swipe Completion

    private enum SwipeDirection { case left, right }

    /// Logs `near_you_opened` at most once per ~session.
    ///
    /// It used to fire directly in `.task`, which SwiftUI runs on EVERY view
    /// appearance — so it counted TAB SWITCHES, not visits. One founder testing
    /// session logged 33 "opens" from a single user in a day, inflating every
    /// engagement read built on it by an unknown multiple. 30 minutes matches
    /// GA4's own session timeout, so one event now means one visit.
    @MainActor private static var lastOpenLoggedAt: Date?

    private func logNearYouVisit() {
        let now = Date()
        if let last = Self.lastOpenLoggedAt, now.timeIntervalSince(last) < 30 * 60 { return }
        Self.lastOpenLoggedAt = now
        AppAnalytics.log("near_you_opened")
    }

    private func completeSwipe(direction: SwipeDirection) {
        let topEvent = visibleDeck.first

        // Swipe cap — evaluated BEFORE the card is consumed, so hitting the wall
        // never costs the user a venue. The card snaps back instead of flying off,
        // and the swipe is neither counted nor logged: it didn't happen.
        // paywallScope, not paywallScopeId: an `if let` here let a nil scope skip
        // the cap silently, and 42- and 30-swipe days went unwalled because of it.
        if paywallGate.registerSwipeAndShouldPresent(
            scopeId: coupleService.paywallScope("swipe")) {
            withAnimation(LouvAnimation.spring) { dragOffset = .zero }
            showPaywall = true
            AppAnalytics.log("paywall_shown", [
                "trigger": "swipe_limit",
                "scope": coupleId == nil ? "solo" : "couple"
            ])
            return
        }

        // Mark the session as touched so a late location/pairing reload won't
        // yank the deck out from under the user.
        swipedCount += 1

        // Solo swipes were entirely uninstrumented before 1.0.8 — card_liked only
        // fires inside MatchService.recordLike, which requires a coupleId — so
        // there was no data to size a swipe cap against. Log every swipe.
        AppAnalytics.log("swipe_made", [
            "direction": direction == .right ? "right" : "left",
            "scope": coupleId == nil ? "solo" : "couple"
        ])

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(LouvAnimation.spring) {
            dragOffset.width = direction == .right ? 600 : -600
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(LouvAnimation.spring) {
                if let topEvent {
                    deck.removeAll { $0.id == topEvent.id }
                }
                dragOffset = .zero
            }

            // Right-swipe = a like. With a couple, record it for real — the
            // match is detected and celebrated via MainTabView's listener (we
            // don't set matchedEvent here). SOLO saves the venue straight to
            // Missions; see below.
            if direction == .right, let event = topEvent {
                // SAVE FIRST, ALWAYS — paired or not (2026-08-12, founder hit this
                // in Madrid). Before today a PAIRED right-swipe only recorded a
                // like and waited for the partner to like the same card, so
                // someone swiping alone in a city they don't know saved literally
                // NOTHING. Swiping now builds YOUR shortlist; a mutual match is a
                // bonus on top rather than the toll gate in front. add() is
                // idempotent on cardId, so the match flow's "Plan This Date"
                // cannot double-add the same venue.
                if missionStore.add(Mission(from: DateCard(fromVenue: event))) {
                    withAnimation(LouvAnimation.spring) { savedVenueName = event.venue }
                }
                // Paired: also record the like, so a card you BOTH swiped still
                // lights up as a match. Recorded under the card's OWN deck
                // (.places / .events) so the partner rebuilds it from the right
                // cache; samples (nil) stay .events.
                //
                // (This branch previously held a `Bool.random()` placeholder for
                // the solo case that faked "It's a Match! 🎉" half the time and
                // silently dropped the rest — removed 2026-08-11.)
                if let coupleId {
                    let deck = event.sourceDeck ?? .events
                    Task { await matchService.recordLike(coupleId: coupleId, cardId: event.cardId, deck: deck) }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 40) {
            Button {
                guard !visibleDeck.isEmpty else { return }
                completeSwipe(direction: .left)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.gray)
                    .frame(width: 64, height: 64)
                    .background(Color.white)
                    .clipShape(Circle())
                    .louvShadow()
            }
            .buttonStyle(.plain)

            Button {
                guard !visibleDeck.isEmpty else { return }
                completeSwipe(direction: .right)
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(LouvGradient.coral)
                    .clipShape(Circle())
                    .louvShadow()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterPill(label: "All", value: nil)
                    ForEach(deckCategories, id: \.self) { category in
                        filterPill(label: category.rawValue, value: category)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Cuisine sub-row — only under Food & Drink, which is the one category
            // big enough (ten split searches) that a single pill isn't enough to
            // navigate it. Other categories stay a single, uncluttered row.
            if selectedCategory == .foodDrink, !deckCuisines.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        cuisinePill(label: "Any food", value: nil)
                        ForEach(deckCuisines, id: \.self) { cuisine in
                            cuisinePill(label: cuisine.rawValue, value: cuisine)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Only the categories actually present in a freshly-loaded deck, in a stable
    /// display order — so a filter that can't have results never shows a dead pill.
    /// The Places deck never produces `.music` (that's an events-only category, and
    /// events are dormant), so Music simply doesn't appear; ditto any category with
    /// nothing nearby in the current bucket.
    ///
    /// Called ONCE per load, not per render — see deckCategories for why.
    private static func categories(in deck: [LocalEvent]) -> [LocalEvent.Category] {
        let present = Set(deck.map(\.category))
        let order: [LocalEvent.Category] = [.music, .foodDrink, .arts, .outdoors, .trails, .nightlife]
        return order.filter(present.contains)
    }

    /// Only the cuisines actually present among a freshly-loaded deck's Food & Drink
    /// cards — same "never show a dead pill" rule as categories(in:). Venues with a
    /// generic or unmapped primaryType contribute no bucket (see PlaceCuration.Cuisine).
    ///
    /// Called ONCE per load, not per render — see deckCuisines for why.
    private static func cuisines(in deck: [LocalEvent]) -> [PlaceCuration.Cuisine] {
        let present = Set(
            deck.lazy
                .filter { $0.category == .foodDrink }
                .compactMap { PlaceCuration.cuisine(forPrimaryType: $0.primaryType) }
        )
        return PlaceCuration.cuisineDisplayOrder.filter(present.contains)
    }

    @ViewBuilder
    private func filterPill(label: String, value: LocalEvent.Category?) -> some View {
        let isSelected = selectedCategory == value

        Button {
            withAnimation(LouvAnimation.spring) {
                selectedCategory = value
                // Leaving Food & Drink hides the cuisine row, so drop any cuisine
                // with it — otherwise an invisible filter keeps narrowing the deck.
                if value != .foodDrink { selectedCuisine = nil }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        LouvGradient.coral
                    } else {
                        Color(white: 0.92)
                    }
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// The cuisine pill is deliberately a size down from the category pill (13pt,
    /// tighter padding, flat coral instead of the gradient) so the two rows read as
    /// filter → sub-filter rather than as two competing choices.
    @ViewBuilder
    private func cuisinePill(label: String, value: PlaceCuration.Cuisine?) -> some View {
        let isSelected = selectedCuisine == value

        Button {
            withAnimation(LouvAnimation.spring) {
                selectedCuisine = value
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .gray)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Color.louvCoral
                    } else {
                        Color(white: 0.95)
                    }
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.louvCoral)
                .scaleEffect(1.3)
            Text(NearYouConfig.source == .events ? "Finding events near you…" : "Finding date spots near you…")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Data loading
    // The deck loads through EventCache (a read-through Firestore cache over the
    // Ticketmaster Discovery API). The first lookup of a given bucket+week pays
    // one rate-limited search and writes it to Firestore; repeats — same area,
    // same week, EITHER partner — are free cache reads. Any miss / no-key /
    // offline path silently falls back to SampleEvents, the same contract the
    // venue cache and the rest of the app use.

    private func loadDeck() async {
        locationManager.requestPermissionIfNeeded()

        let events = await fetchEvents()
        await MainActor.run {
            // Adopt the load only while the session is untouched. The .task load
            // always is; a late reload is already guarded by reloadIfUntouched().
            if swipedCount == 0 {
                deck = events.isEmpty ? SampleEvents.all : events
                // Snapshot the pills for this deck. From here they stay put for the
                // session even as swiping empties `deck` — see deckCategories.
                deckCategories = Self.categories(in: deck)
                deckCuisines = Self.cuisines(in: deck)
                // Drop a filter the new deck can't satisfy (its pill is now hidden),
                // so the user never lands on an empty, un-deselectable category.
                if let selectedCategory, !deckCategories.contains(selectedCategory) {
                    self.selectedCategory = nil
                    self.selectedCuisine = nil
                }
                // Same rule one level down: a new deck (new city) may have no
                // Italian at all, and its pill is now gone — don't strand the user
                // on an empty, un-deselectable cuisine.
                if let selectedCuisine, !deckCuisines.contains(selectedCuisine) {
                    self.selectedCuisine = nil
                }
            }
            isLoading = false
        }
    }

    /// Re-runs the load after permission is granted or pairing completes — but
    /// only if the user hasn't started swiping, so an active session is never reset.
    private func reloadIfUntouched() {
        guard swipedCount == 0 else { return }
        isLoading = true
        Task { await loadDeck() }
    }

    /// The real deck for the resolved (shared, when paired) location bucket, from
    /// the configured source (NearYouConfig.source). [] signals "fall back to
    /// samples" (no API key, offline, or nothing near). Each card it returns
    /// already carries its sourceDeck, so a swipe records the right Deck.
    private func fetchEvents() async -> [LocalEvent] {
        let bucket = await resolveBucket()
        switch NearYouConfig.source {
        case .places:
            return await placesDeck(bucket: bucket)
        case .events:
            return await eventsDeck(bucket: bucket)
        case .both:
            // Both pipelines run concurrently; cards carry their own deck, so the
            // interleaved result swipes/matches correctly per card.
            async let places = placesDeck(bucket: bucket)
            async let events = eventsDeck(bucket: bucket)
            return interleave(await places, await events)
        }
    }

    /// Google Places venues near the bucket, or [] if no key. The Vilnius-launch
    /// source.
    private func placesDeck(bucket: String) async -> [LocalEvent] {
        guard PlacesService().hasAPIKey else { return [] }
        return await VenueCache().deck(bucket: bucket)
    }

    /// Ticketmaster events near the bucket, or [] if no key. Dormant at launch,
    /// re-enabled via NearYouConfig.source — the whole events pipeline is intact.
    private func eventsDeck(bucket: String) async -> [LocalEvent] {
        guard TicketmasterService().hasAPIKey else { return [] }
        return await EventCache().deck(bucket: bucket)
    }

    /// Alternate two decks A,B,A,B… keeping each source visible near the top.
    private func interleave(_ a: [LocalEvent], _ b: [LocalEvent]) -> [LocalEvent] {
        var result: [LocalEvent] = []
        for i in 0..<max(a.count, b.count) {
            if i < a.count { result.append(a[i]) }
            if i < b.count { result.append(b[i]) }
        }
        return result
    }

    /// The location bucket to fetch the deck for. When paired this is the SHARED
    /// bucket on the couple doc, so both partners get ONE deck (and their swipe
    /// cardIds line up for matching). This device claims it on bootstrap and
    /// re-anchors it on travel — but only ever PERSISTS a real GPS fix (never the
    /// London fallback), and only overrides an OLDER stored bucket (debounced), so
    /// co-located partners don't ping-pong the shared deck.
    private func resolveBucket() async -> String {
        let coord = locationManager.coordinate
        let deviceBucket = LocationBucket.of(latitude: coord.latitude, longitude: coord.longitude)

        guard coupleId != nil else { return deviceBucket }   // solo — no doc to share through

        let stored = coupleService.eventLocationBucket

        // A deliberately-set location (a "Search here" tap or a planned town) stays
        // put until the user clears it — auto-GPS never yanks it away.
        if coupleService.eventLocationManual, let stored { return stored }

        // Only ever persist a REAL fix, so the couple never anchors to the London
        // fallback coordinate.
        if locationManager.hasPermission, locationManager.hasFix {
            guard let stored else {
                await coupleService.setEventLocation(bucket: deviceBucket)   // bootstrap claim
                return deviceBucket
            }
            if deviceBucket != stored {
                let movedFar = LocationBucket.center(of: stored)
                    .map { kmBetween(coord, lat: $0.lat, lng: $0.lng) > travelReanchorKm } ?? true
                let debounced = coupleService.eventLocationUpdatedAt
                    .map { Date().timeIntervalSince($0) > reanchorDebounce } ?? true
                // Real travel re-anchors NOW; a small boundary hop waits out the
                // 12h debounce so two co-located partners don't ping-pong it.
                if movedFar || debounced {
                    await coupleService.setEventLocation(bucket: deviceBucket)   // re-anchor
                    return deviceBucket
                }
            }
        }
        // No real fix yet, or nothing to change: prefer the shared bucket, else
        // the device (possibly London) bucket just for this load.
        return stored ?? deviceBucket
    }

    /// Kilometres between a live coordinate and a stored bucket's centre.
    private func kmBetween(_ coord: CLLocationCoordinate2D, lat: Double, lng: Double) -> Double {
        CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            .distance(from: CLLocation(latitude: lat, longitude: lng)) / 1000
    }

    // MARK: - Location search actions

    /// Force the shared anchor to the current GPS fix now, returning to auto-follow
    /// (clears any manual pin). Powers both "Search here" and "Use my location".
    private func searchHere() {
        searchError = nil
        guard locationManager.hasFix else {
            locationManager.requestPermissionIfNeeded()
            return
        }
        let coord = locationManager.coordinate
        let bucket = LocationBucket.of(latitude: coord.latitude, longitude: coord.longitude)
        Task {
            await coupleService.setEventLocation(bucket: bucket, manual: false)
            await reloadDeckForced()
        }
    }

    /// Geocode a typed city (free, on-device via CLGeocoder) and pin the couple's
    /// shared deck there so BOTH partners plan — and match — for a trip.
    private func searchTown() {
        let query = townQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchError = nil
        isGeocoding = true
        Task {
            do {
                let marks = try await CLGeocoder().geocodeAddressString(query)
                guard let place = marks.first, let loc = place.location else {
                    await MainActor.run { searchError = "Couldn't find that place"; isGeocoding = false }
                    return
                }
                let bucket = LocationBucket.of(latitude: loc.coordinate.latitude,
                                               longitude: loc.coordinate.longitude)
                let label = place.locality ?? place.name ?? query
                await coupleService.setEventLocation(bucket: bucket, manual: true, label: label)
                await MainActor.run { townQuery = ""; isGeocoding = false }
                await reloadDeckForced()
            } catch {
                await MainActor.run { searchError = "Couldn't find that place"; isGeocoding = false }
            }
        }
    }

    /// A location change swaps the whole deck, so reset the swipe session and
    /// reload unconditionally (unlike reloadIfUntouched, which preserves an active
    /// session — here the user explicitly asked for a new place).
    @MainActor
    private func reloadDeckForced() {
        swipedCount = 0
        deck = []
        deckCategories = []
        deckCuisines = []
        selectedCategory = nil
        selectedCuisine = nil
        isLoading = true
        Task { await loadDeck() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("That's everything in this category 📍")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)
            Text("Try a different filter, or check back soon.")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - EventCardContent
// The contents of a single event card. Mirrors CardContent's shape
// from SwipeView (emoji top, title + secondary line, optional row,
// description, pills at the bottom) so both decks read the same way.
private struct EventCardContent: View {
    let event: LocalEvent

    var body: some View {
        VStack(spacing: 0) {
            // Hero: the venue's real first photo when we have one — rendered via
            // BundledRemoteImage (the bundle-key loader; NEVER AsyncImage, per the
            // Places 403 rule). Falls back to the big category emoji while loading
            // or when the venue has no photo (and for date-idea cards, which have none).
            Group {
                if let photo = event.photos.first {
                    BundledRemoteImage(urlString: photo) {
                        ZStack {
                            Color.blushCream
                            Text(event.emoji).font(.system(size: 56))
                        }
                    }
                } else {
                    ZStack {
                        Color.blushCream
                        Text(event.emoji).font(.system(size: 72))
                    }
                }
            }
            .frame(height: 230)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(spacing: 8) {
                Text(event.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Join non-empty parts: events show "Venue · Fri 8pm"; venues have
                // no date, so they show just the type label (e.g. "Wine Bar").
                Text([event.venue, event.date].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)

                // Rating row — only shown when we have review data.
                if let rating = event.rating, let reviewCount = event.reviewCount {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 14, weight: .semibold))
                        Text("·")
                            .foregroundStyle(.gray)
                        Text("\(reviewCount.formatted()) reviews")
                            .font(.system(size: 13))
                            .foregroundStyle(.gray)
                    }
                    .foregroundStyle(Color.louvCoral)
                }

                Text(event.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    pill(text: event.category.rawValue, background: .louvCoral)
                    // Venues without a published price level omit the price pill.
                    if !event.price.isEmpty {
                        pill(text: event.price, background: .louvOrange)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func pill(text: String, background: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(Capsule())
    }
}

#Preview {
    NearYouView(matchedEvent: .constant(nil), eventToShow: .constant(nil), coupleId: nil)
        .environment(MatchService())
        .environment(CoupleService())
}
