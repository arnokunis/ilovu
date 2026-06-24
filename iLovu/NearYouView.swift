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

    @State private var selectedCategory: LocalEvent.Category? = nil

    /// A travel move only overrides an OLDER stored bucket than this, so two
    /// co-located partners straddling a ~1km bucket boundary don't ping-pong the
    /// shared deck back and forth on every open.
    private let reanchorDebounce: TimeInterval = 12 * 60 * 60

    // Same threshold as SwipeView — keeps the muscle memory identical.
    private let swipeThreshold: CGFloat = 120

    private var visibleDeck: [LocalEvent] {
        guard let selectedCategory else { return deck }
        return deck.filter { $0.category == selectedCategory }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                    .padding(.top, 8)

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
                .padding(.horizontal, 24)

                Spacer()

                actionButtons
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Load the deck once on appear (real events via EventCache, or the
        // SampleEvents fallback). .task is cancelled automatically on disappear.
        .task { await loadDeck() }
        // If location permission is granted AFTER the first load, or the couple
        // link completes mid-session, re-fetch — but only while the deck is still
        // untouched, so an active swipe session is never reset.
        .onChange(of: locationManager.hasPermission) { _, _ in reloadIfUntouched() }
        .onChange(of: coupleId) { _, _ in reloadIfUntouched() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("iLovu")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.louvCoral)
            Text("Near You 📍")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.deepRose)
            Text("Events near you this week")
                .font(.system(size: 13))
                .foregroundStyle(.gray)
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
            .frame(width: 340, height: 480)
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
            .gesture(dragGesture)
            // Tap (with no significant drag) opens the event detail.
            // DragGesture's default minimumDistance (10pt) means a real
            // tap doesn't accidentally trigger the drag, and vice versa.
            .onTapGesture {
                eventToShow = event
            }
            .allowsHitTesting(isTop)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
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

    private func completeSwipe(direction: SwipeDirection) {
        let topEvent = visibleDeck.first

        // Mark the session as touched so a late location/pairing reload won't
        // yank the deck out from under the user.
        swipedCount += 1

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
            // don't set matchedEvent here). Without a couple, fall back to the
            // placeholder coin-flip so the deck still celebrates in solo/preview.
            if direction == .right, let event = topEvent {
                if let coupleId {
                    Task { await matchService.recordLike(coupleId: coupleId, cardId: event.cardId, deck: .events) }
                } else if Bool.random() {
                    matchedEvent = event
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(label: "All",          value: nil)
                filterPill(label: "Music",        value: .music)
                filterPill(label: "Food & Drink", value: .foodDrink)
                filterPill(label: "Arts",         value: .arts)
                filterPill(label: "Outdoors",     value: .outdoors)
                filterPill(label: "Nightlife",    value: .nightlife)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func filterPill(label: String, value: LocalEvent.Category?) -> some View {
        let isSelected = selectedCategory == value

        Button {
            withAnimation(LouvAnimation.spring) {
                selectedCategory = value
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

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.louvCoral)
                .scaleEffect(1.3)
            Text("Finding events near you…")
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

    /// Real events for the resolved (shared, when paired) location bucket, or []
    /// to signal "fall back to samples" (no API key, offline, or nothing near).
    private func fetchEvents() async -> [LocalEvent] {
        guard TicketmasterService().hasAPIKey else { return [] }
        let bucket = await resolveBucket()
        return await EventCache().deck(bucket: bucket)
    }

    /// The location bucket to fetch the deck for. When paired this is the SHARED
    /// bucket on the couple doc, so both partners get ONE deck (and their swipe
    /// cardIds line up for matching). This device claims it on bootstrap and
    /// re-anchors it on travel — but only ever PERSISTS a real GPS fix (never the
    /// London fallback), and only overrides an OLDER stored bucket (debounced), so
    /// co-located partners don't ping-pong the shared deck.
    private func resolveBucket() async -> String {
        let coord = locationManager.coordinate
        let deviceBucket = EventCache.locationBucket(latitude: coord.latitude, longitude: coord.longitude)

        guard coupleId != nil else { return deviceBucket }   // solo — no doc to share through

        let stored = coupleService.eventLocationBucket

        if locationManager.hasPermission {
            if stored == nil {
                await coupleService.setEventLocation(bucket: deviceBucket)   // bootstrap claim
                return deviceBucket
            }
            if deviceBucket != stored,
               let updated = coupleService.eventLocationUpdatedAt,
               Date().timeIntervalSince(updated) > reanchorDebounce {
                await coupleService.setEventLocation(bucket: deviceBucket)   // travel re-anchor
                return deviceBucket
            }
        }
        // No real fix yet, or nothing to change: prefer the shared bucket, else
        // the device (possibly London) bucket just for this load.
        return stored ?? deviceBucket
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("That's everything in this category 📍")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)
            Text("Try a different filter, or check back next week.")
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
        VStack(spacing: 14) {
            Spacer()

            Text(event.emoji)
                .font(.system(size: 64))

            VStack(spacing: 4) {
                Text(event.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text("\(event.venue) · \(event.date)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Rating row — only shown when we have review data.
            // String(format:) gives "4.7" not "4.70" or "4.7000...".
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
                .padding(.horizontal, 24)
                .lineLimit(3)

            Spacer()

            HStack(spacing: 8) {
                pill(text: event.category.rawValue, background: .louvCoral)
                pill(text: event.price,             background: .louvOrange)
            }
            .padding(.bottom, 20)
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
