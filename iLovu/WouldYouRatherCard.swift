// WouldYouRatherCard.swift
// The "Would You Rather" couple game — a light daily dilemma, shown on the Home
// dashboard beside the Daily Question. Same "answer to unlock" reveal: you pick
// A or B, and once your partner picks too, the card reveals whether you matched
// (the fun, shareable payoff). Fully self-contained (owns its own listener),
// mirroring DailyQuestionCard.
//
// States:
//   1. Choosing — two tappable options
//   2. Chosen, partner hasn't (paired) — your pick locked + "waiting" panel
//   3. Both chosen — both picks shown + a "in sync / opposites attract" verdict
// UNPAIRED: pick is stored locally; a warm "connect to compare" panel replaces
// the reveal (nothing regresses before pairing).

import SwiftUI
import FirebaseFirestore

struct WouldYouRatherCard: View {

    let coupleId: String?
    var isOrphaned: Bool = false

    @Environment(WouldYouRatherService.self) private var gameService

    // Unpaired local-only fallback: my pick + the date it was made (to tell
    // "chose TODAY" from a stale previous day).
    @AppStorage("wyrChoice")        private var savedChoice: String = ""
    @AppStorage("wyrChoiceDateKey") private var savedChoiceDateKey: String = ""

    @State private var mineChoice: String?
    @State private var partnerChoice: String?
    @State private var listener: ListenerRegistration?

    private let prompt = WouldYouRather.today

    private var isPaired: Bool { coupleId != nil }

    private var myChoice: String? {
        if isPaired { return mineChoice }
        return (!savedChoice.isEmpty && savedChoiceDateKey == WouldYouRather.todayDateKey)
            ? savedChoice : nil
    }
    private var hasChosen: Bool { myChoice != nil }
    private var bothChosen: Bool { isPaired && mineChoice != nil && partnerChoice != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Would You Rather 🎲")

            option("A", text: prompt.optionA)
            option("B", text: prompt.optionB)

            if hasChosen { verdict }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
        .onAppear { attachListener() }
        .onDisappear { detachListener() }
        .onChange(of: coupleId) { _, _ in attachListener() }
    }

    // MARK: - Option button

    @ViewBuilder
    private func option(_ key: String, text: String) -> some View {
        let isMine = myChoice == key
        let isPartner = bothChosen && partnerChoice == key

        Button { choose(key) } label: {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isMine ? .white : Color.deepRose)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                if isMine { pickBadge("You", onColor: true) }
                if isPartner { pickBadge("Them", onColor: isMine) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background {
                if isMine {
                    LouvGradient.coral
                } else if isPartner {
                    Color.louvCoral.opacity(0.12)
                } else {
                    Color.blushCream
                }
            }
            .overlay {
                if isPartner && !isMine {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.louvCoral, lineWidth: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(hasChosen && !isMine && !isPartner ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(hasChosen)   // one pick per day, like the Daily Question
    }

    private func pickBadge(_ text: String, onColor: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(onColor ? .white : Color.louvCoral)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(onColor ? Color.white.opacity(0.25) : Color.louvCoral.opacity(0.15),
                        in: Capsule())
    }

    // MARK: - Verdict / waiting / connect

    @ViewBuilder
    private var verdict: some View {
        if isPaired {
            if bothChosen {
                let matched = mineChoice == partnerChoice
                panel(
                    icon: matched ? "sparkles" : "arrow.left.arrow.right",
                    title: matched ? "You're in sync! 💕" : "Opposites attract 😄",
                    subtitle: matched ? "You both picked the same one."
                                      : "You each went your own way — that's the fun of it."
                )
            } else {
                panel(icon: "lock.fill",
                      title: "Waiting for your partner…",
                      subtitle: "You'll see their pick once they choose too 💕")
            }
        } else if isOrphaned {
            panel(icon: "heart.fill",
                  title: "Just a bit of fun 💕",
                  subtitle: "Your picks stay here for you.")
        } else {
            panel(icon: "heart.fill",
                  title: "Compare with your partner",
                  subtitle: "Connect to see if you two match 💕")
        }
    }

    private func panel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.louvCoral)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.deepRose)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.blushCream.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity)
    }

    // MARK: - Actions

    private func choose(_ key: String) {
        guard !hasChosen else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AppAnalytics.log("would_you_rather_answered")

        if let coupleId {
            withAnimation(LouvAnimation.spring) { mineChoice = key }
            Task {
                await gameService.saveChoice(
                    coupleId: coupleId,
                    dateKey: WouldYouRather.todayDateKey,
                    promptIndex: WouldYouRather.todayIndex,
                    choice: key
                )
            }
        } else {
            withAnimation(LouvAnimation.spring) {
                savedChoice = key
                savedChoiceDateKey = WouldYouRather.todayDateKey
            }
        }
    }

    // MARK: - Listener lifecycle

    private func attachListener() {
        detachListener()
        mineChoice = nil
        partnerChoice = nil
        guard let coupleId else { return }
        listener = gameService.observeToday(
            coupleId: coupleId,
            dateKey: WouldYouRather.todayDateKey
        ) { mine, partner in
            withAnimation(LouvAnimation.spring) {
                mineChoice = mine
                partnerChoice = partner
            }
        }
    }

    private func detachListener() {
        listener?.remove()
        listener = nil
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

#Preview {
    WouldYouRatherCard(coupleId: nil)
        .environment(WouldYouRatherService())
        .padding(20)
        .background(Color.blushCream)
}
