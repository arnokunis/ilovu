// SwipeView.swift
// The main screen: a stack of date cards the user swipes right (like) or left (pass).
// All the swipe physics, haptics, and "is it a match?" coin-flip happen here.
//
// This view does NOT own the match screen — it just sets a binding when a
// match happens, and the parent (ContentView) decides how to present it.

import SwiftUI

struct SwipeView: View {

    // MARK: - State

    // The current deck of cards. We mutate this by removing the top card
    // each time the user swipes. @State means SwiftUI re-renders when it changes.
    @State private var deck: [DateCard] = SampleCards.all

    // How far the user has currently dragged the top card.
    // Resets to .zero after every swipe completes.
    @State private var dragOffset: CGSize = .zero

    // A binding owned by the parent. When we set this to a card,
    // ContentView's .fullScreenCover sees it and shows MatchView.
    @Binding var matchedCard: DateCard?

    // Tapping a card (without swiping) sets this. MainTabView owns
    // the actual sheet — same pattern as NearYouView's eventToShow.
    @Binding var cardToShow: DateCard?

    // The current couple's id, passed down from MainTabView. When present, a
    // right-swipe records a real like through MatchService and the celebration is
    // driven by MainTabView's matches listener. When nil (not paired / preview),
    // we keep the placeholder coin-flip so the deck still feels alive.
    let coupleId: String?

    // Records likes + creates match docs. Celebration itself is presented by
    // MainTabView's listener, not here — see completeSwipe.
    @Environment(MatchService.self) private var matchService

    // Currently selected difficulty filter. nil = "All" (show every card).
    // Changing this immediately changes the deck the user sees.
    @State private var selectedDifficulty: DateCard.Difficulty? = nil

    // How far the user must drag before we count it as a real swipe.
    // Smaller = more sensitive; bigger = harder to trigger accidentally.
    private let swipeThreshold: CGFloat = 120

    // The deck the user actually sees, after applying the difficulty filter.
    // `deck` stays the master list (so swipes permanently remove a card);
    // `visibleDeck` is a computed view on top of it.
    private var visibleDeck: [DateCard] {
        guard let selectedDifficulty else { return deck }
        return deck.filter { $0.difficulty == selectedDifficulty }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // The warm cream background — never pure white, per our design system.
            Color.blushCream.ignoresSafeArea()

            VStack(spacing: 24) {
                filterPills
                    .padding(.top, 8)

                Spacer()

                // The card stack lives inside a fixed-size ZStack so the
                // cards don't push the buttons around as they move.
                ZStack {
                    if visibleDeck.isEmpty {
                        emptyState
                    } else {
                        // Top two cards only — explicit zIndex keeps the top
                        // card above the peek card without relying on iteration order.
                        ForEach(Array(visibleDeck.prefix(2).enumerated()), id: \.element.id) { index, card in
                            cardView(for: card)
                                .zIndex(Double(1 - index))
                        }
                    }
                }
                // maxWidth/maxHeight (not fixed width/height) so the card
                // shrinks on narrow phones and doesn't look lost on iPad.
                .frame(maxWidth: 340, maxHeight: 480)
                .padding(.horizontal, 24)

                Spacer()

                actionButtons
                    .padding(.bottom, 32)
            }
            // Pin the VStack to the full ZStack — guards against the layout
            // collapsing to its intrinsic content height on iPad / Catalyst.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Card View

    // Returns one rendered card. The top card gets the drag gesture and
    // tracks the user's finger; the card behind sits slightly scaled-down
    // and tilted to give the stack a sense of depth.
    @ViewBuilder
    private func cardView(for card: DateCard) -> some View {
        let isTop = card.id == visibleDeck.first?.id

        // Stamps fade in proportionally to drag progress toward the threshold,
        // and only ever show on the top card. Clamped 0...1.
        let likeOpacity = isTop ? min(max(dragOffset.width / swipeThreshold, 0), 1) : 0
        let nopeOpacity = isTop ? min(max(-dragOffset.width / swipeThreshold, 0), 1) : 0

        CardContent(card: card)
            .frame(width: 340, height: 480)
            .background(Color.white)
            // Stamps go BEFORE clipShape so the rounded corners mask them
            // if they happen to overflow. Border overlay stays AFTER clipShape
            // so the stroke renders on top of everything.
            // SwipeStamp lives in its own file — NearYouView uses the same
            // view for its event swipe deck so the two decks feel identical.
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
            // The back card is smaller and slightly rotated for depth.
            .scaleEffect(isTop ? 1.0 : 0.95)
            .rotationEffect(isTop ? .degrees(Double(dragOffset.width / 20)) : .degrees(-3))
            // Only the top card follows the finger.
            .offset(isTop ? dragOffset : .zero)
            .gesture(dragGesture)
            // Tap (with no significant drag) opens the card detail.
            // DragGesture's default minimumDistance (10pt) means a real
            // tap doesn't accidentally trigger the drag, and vice versa.
            .onTapGesture {
                cardToShow = card
            }
            // Only the top card should accept touches — back cards are decorative.
            .allowsHitTesting(isTop)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Follow the finger directly — no easing while dragging.
                dragOffset = value.translation
            }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    completeSwipe(direction: .right)
                } else if value.translation.width < -swipeThreshold {
                    completeSwipe(direction: .left)
                } else {
                    // Didn't drag far enough — spring back to center.
                    withAnimation(LouvAnimation.spring) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Swipe Completion

    private enum SwipeDirection { case left, right }

    // Called both by the drag gesture and by the action buttons.
    // Flies the card off screen, then pops it off the deck and
    // (for a right-swipe) flips a coin to decide if it's a match.
    private func completeSwipe(direction: SwipeDirection) {
        // Capture the card BEFORE we remove it from the deck.
        // We pull from `visibleDeck` (what the user sees) but remove from
        // the master `deck` — otherwise the filtered card wouldn't actually
        // get marked as swiped.
        let topCard = visibleDeck.first

        // Subtle vibration so the swipe feels physical, not just visual.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Fling the card off to the appropriate edge.
        withAnimation(LouvAnimation.spring) {
            dragOffset.width = direction == .right ? 600 : -600
        }

        // After the fly-off animation, remove the swiped card from the master
        // deck so the next visible one becomes the new top. Wrapped in
        // withAnimation so the back card smoothly scales up from 0.95 → 1.0.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(LouvAnimation.spring) {
                if let topCard {
                    deck.removeAll { $0.id == topCard.id }
                }
                dragOffset = .zero
            }

            // Right-swipe = a like. With a couple, record it for real: the
            // match (if the partner already liked it too) is detected and
            // celebrated via MainTabView's matches listener — we do NOT set
            // matchedCard here. Without a couple, fall back to the placeholder
            // coin-flip so the deck still celebrates in solo/preview.
            if direction == .right, let card = topCard {
                if let coupleId {
                    Task { await matchService.recordLike(coupleId: coupleId, cardId: card.cardId, deck: .dates) }
                } else if Bool.random() {
                    matchedCard = card
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 40) {
            // Pass — grey circle with an ✗
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

            // Like — coral gradient circle with a ♥
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
    // A horizontal row of difficulty filters at the top of the screen.
    // "All" (nil) shows everything; each other pill narrows the deck to
    // one difficulty. Selected = coral gradient, unselected = light grey.

    private var filterPills: some View {
        // ScrollView so the row doesn't get clipped on narrow iPhones —
        // five labels plus padding can easily overflow ~390pt of width.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(label: "All", value: nil)
                filterPill(label: "Micro", value: .micro)
                filterPill(label: "Quick", value: .quick)
                filterPill(label: "Half Day", value: .halfDay)
                filterPill(label: "Adventure", value: .adventure)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func filterPill(label: String, value: DateCard.Difficulty?) -> some View {
        let isSelected = selectedDifficulty == value

        Button {
            // Animate so the deck change feels smooth rather than a jump-cut.
            withAnimation(LouvAnimation.spring) {
                selectedDifficulty = value
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

    // MARK: - Empty State

    // Shown once the user has swiped through every card.
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("That's everyone for today 💝")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)
            Text("Come back tomorrow for fresh ideas.")
                .font(.system(size: 15))
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - CardContent
// The actual contents of a single card. Pulled into its own private view
// so the parent SwipeView stays focused on stack/gesture/state logic.
private struct CardContent: View {
    let card: DateCard

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Big visual hook.
            Text(card.emoji)
                .font(.system(size: 72))

            // Title.
            Text(card.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Description.
            Text(card.description)
                .font(.system(size: 15))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            // Tag pills at the bottom: difficulty (coral) + cost (orange).
            HStack(spacing: 8) {
                pill(text: card.difficulty.rawValue, background: .louvCoral)
                pill(text: card.estimatedCost.rawValue, background: .louvOrange)
            }
            .padding(.bottom, 24)
        }
    }

    // A tiny helper so the two pills stay visually identical.
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

// MARK: - Preview
// .constant(nil) gives us a fake binding for previewing without a real parent.
// coupleId: nil keeps the preview on the placeholder coin-flip (no Firestore).
#Preview {
    SwipeView(matchedCard: .constant(nil), cardToShow: .constant(nil), coupleId: nil)
        .environment(MatchService())
}
