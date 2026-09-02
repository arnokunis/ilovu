// HomeView.swift
// The home dashboard — the first screen users see each time they open
// the app. iLovu's positioning is the anti-pressure couples app:
// research shows one or two intentional dates per month is the sweet
// spot for relationship satisfaction; daily nagging causes stress and
// kills the benefit. So this dashboard is deliberately calm: monthly
// goals, micro-moments count, no streaks-or-shame language.

import SwiftUI

// Safety-net date suggestion used by HomeView only if SampleCards.all is
// ever empty. Defined at file scope (not as a static on HomeView) because
// referencing a struct-level static from a @State default expression can
// confuse SourceKit and cascade "type not found" errors across the file.
private let homeFallbackCard = DateCard(
    title: "Take five together",
    description: "Sit for five minutes with no phones — share one good thing about today each.",
    emoji: "💕",
    difficulty: .micro,
    estimatedCost: .free,
    category: .cosy,
    whyItWorks: "Even tiny moments of focused attention count as a date.",
    tips: [
        "Set a five-minute timer.",
        "Phones face-down on the table.",
        "Take turns sharing — no interrupting."
    ]
)

struct HomeView: View {

    // Binding to MainTabView's selected tab. HomeView doesn't own the
    // selection — it borrows it via @Binding so the "Find an idea →"
    // button can flip the app over to the Cards tab.
    @Binding var selectedTab: AppTab

    // Shared stores (injected at the app root). HomeView observes both
    // so the missions list and the stats row stay live as missions are
    // completed and memories are saved elsewhere in the app.
    @Environment(MissionStore.self) private var missionStore
    @Environment(MemoryStore.self)  private var memoryStore

    // Set during onboarding.
    @AppStorage("userName") private var userName: String = ""

    // The couple link — the partner's name now rides on the shared couple doc
    // (each member writes their own via CoupleService.setDisplayName), so we read
    // it from here instead of a never-populated local placeholder. Resolves on
    // launch / next currentCouple() fetch.
    @Environment(CoupleService.self) private var coupleService

    // Decides whether the soft paywall should appear at this calm mission-start
    // entry point. Fed match/memory counts elsewhere (MainTabView /
    // MissionDetailView); here we only read its decision.
    @Environment(PaywallGate.self) private var paywallGate

    // RevenueCat: real prices for the wall + the purchase / restore flows.
    @Environment(SubscriptionService.self) private var subscriptionService

    // 0...5. Drives how many of the five flame emojis are lit.
    // Conceptually: one completed Mission = a big spark boost; a quick
    // micro-moment = a small boost. The UI doesn't differentiate them
    // — both feed into the same score.
    @AppStorage("sparkScore") private var sparkScore: Int = 2

    /// Dismissal latch for the add-the-widget hint. Once off, stays off.
    @AppStorage("widgetPromptDismissed") private var widgetPromptDismissed: Bool = false

    // Day streak stays as an @AppStorage placeholder until we wire it
    // to real activity data. The other two stats are now derived from
    // the live stores below — single source of truth, no duplication.

    // Real counts read from the stores. Recomputed cheaply on every
    // render; SwiftUI re-renders this view whenever the @Observable
    // stores publish a change, so these are always fresh.
    private var missionsCompletedCount: Int {
        missionStore.missions.filter { $0.status == .completed }.count
    }
    private var memoriesSavedCount: Int {
        memoryStore.memories.count
    }

    // True while a nudge call is in flight, so the button disables and shows a
    // sending state. The per-couple COOLDOWN itself is read live from the shared
    // couple doc (coupleService.canSendManualNudge) — the Cloud Function is the
    // authority and both phones see the same window, so there's no local store.
    @State private var isSendingNudge: Bool = false

    // Picked once per HomeView instance (~once per app launch) so the
    // suggestion stays stable while the user looks at the dashboard.
    // Falls back to `homeFallbackCard` (file scope, above) if SampleCards.all
    // is ever empty — in practice it never is, but `??` keeps the init
    // non-crashing.
    @State private var tonightsCard: DateCard = SampleCards.all.randomElement() ?? homeFallbackCard

    // Message for the brief toast at the top of the screen (nil = hidden). Holds
    // the outcome copy — sent / cooldown / partner-unreachable / error.
    @State private var nudgeToast: String? = nil

    // When set, MissionDetailView is presented as a sheet so the user
    // can edit / mark complete the tapped mission.
    @State private var missionToOpen: Mission?

    // Soft-paywall presentation. When the gate is armed, tapping a mission shows
    // the wall first; the tapped mission is held here and opened on dismiss, so
    // the wall is dismissible and never actually blocks the date.
    @State private var showPaywall: Bool = false
    @State private var missionAfterPaywall: Mission?

    // Presents the pairing sheet from the unpaired-only connect card.
    @State private var showPairing: Bool = false

    /// True only for a real, live couple. Drives the pivot's split: solo users get
    /// a saved-places list, paired users keep the full dashboard unchanged.
    private var isPaired: Bool {
        coupleService.coupleId != nil && !coupleService.isOrphaned
    }

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            // ScrollView so the dashboard still works on smaller phones
            // where the sections might exceed screen height.
            ScrollView {
                VStack(spacing: 24) {
                    greetingSection

                    // PIVOT 2026-09-02 — this tab is "Saved" for the ~98% who never
                    // pair: their saved places and nothing else. Every couples ritual
                    // below is gated behind `isPaired` rather than deleted, so the
                    // three existing couples keep the dashboard they have today and
                    // the code survives for the matching phase.
                    // The invite card is gone for solo users on purpose: pushing an
                    // unpaired person to recruit a partner was the old thesis, and
                    // 38 invites produced 6 pairs.
                    if isPaired {
                        sparkScoreCard
                    }

                    // Daily couple rituals, on the dashboard where daily attention
                    // lands. Orphaned → pass nil so answering falls back to local
                    // journaling instead of a perpetual "waiting for partner" lock.
                    if isPaired {
                        DailyQuestionCard(
                            coupleId: coupleService.isOrphaned ? nil : coupleService.coupleId,
                            isOrphaned: coupleService.isOrphaned
                        )
                    }

                    if isPaired {
                        WouldYouRatherCard(
                            coupleId: coupleService.isOrphaned ? nil : coupleService.coupleId,
                            isOrphaned: coupleService.isOrphaned
                        )
                    }

                    if isPaired {
                        gentleReminder
                        thisWeeksSuggestionCard
                    }
                    missionsSection
                    // Hidden once the partner has deleted their account — there's
                    // no one to nudge (the call would ghost / error out).
                    if isPaired && !coupleService.isOrphaned {
                        nudgeButton
                    }
                    quickStatsRow
                    addWidgetCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            // Dismiss the keyboard when the dashboard is scrolled — so tapping the
            // Daily Question field and then scrolling away (without typing) closes
            // it, instead of leaving the keyboard stuck up.
            .scrollDismissesKeyboard(.immediately)

            // Toast overlay — sits on top of the ScrollView, drops in
            // from the top edge, fades out on its own. allowsHitTesting
            // is off so it never blocks taps on the content underneath.
            if let nudgeToast {
                VStack {
                    nudgeToastView(nudgeToast)
                        .padding(.top, 12)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        // Tapping any mission row sets missionToOpen, which presents
        // the planning sheet. SwiftUI auto-clears the binding when
        // the sheet dismisses.
        .sheet(item: $missionToOpen) { mission in
            MissionDetailView(mission: mission)
        }
        // Pairing sheet opened from the connect card — reuses the same PairingView
        // as the Us tab, so there's no duplicate pairing logic.
        .sheet(isPresented: $showPairing) {
            PairingView()
        }
        // Paywall presented in place of opening the mission when the gate is
        // armed. In SOFT mode (paywallGate.hardMode == false) dismissing the
        // wall continues to the tapped mission, so it never blocks the date. In
        // HARD mode the dismiss-through is withheld unless the couple actually
        // subscribed on the wall just now — the mission stays closed otherwise.
        .sheet(isPresented: $showPaywall, onDismiss: {
            AppAnalytics.log("paywall_dismissed")
            guard let pending = missionAfterPaywall else { return }
            missionAfterPaywall = nil
            // Hard mode blocks: only proceed to the mission in soft mode, or if
            // the user subscribed while the wall was up (smooth post-purchase).
            guard !paywallGate.hardMode || paywallGate.isSubscribed else { return }
            // Small hop so the just-dismissed sheet fully clears before the
            // mission sheet presents (SwiftUI dislikes back-to-back modals).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                missionToOpen = pending
            }
        }) {
            PaywallView(
                isPaired:           coupleService.coupleId != nil,
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
                // Terms of Use / Privacy Policy links live inside PaywallView now
                // (real live ilovu.io pages) so they're always present for
                // App Store 3.1.2(c) — no call-site wiring needed.
            )
            // Load the real offering as the wall appears; PaywallView shows its
            // static fallback copy until the prices land.
            .task { await subscriptionService.loadOfferings() }
        }
    }

    // MARK: - Mission open + paywall gate

    // The calm "next mission start" entry point. If the paywall gate is armed
    // (and the couple isn't subscribed), present the wall instead of opening
    // straight away; otherwise open the mission normally. Choosing this calm
    // path — not the post-match "Plan This Date" flow — is what guarantees the
    // wall never appears mid-celebration. Hard vs. soft (block vs. dismiss-
    // through) is decided in the .sheet onDismiss above via paywallGate.hardMode.
    private func openMission(_ mission: Mission) {
        // Was: "signed out — never gate", which opened the mission ungated whenever
        // the scope was nil. Same fail-open hole as the swipe cap; a device scope
        // keeps the gate honest until a uid exists.
        let scopeId = coupleService.paywallScope("mission_open")
        // Feed the gate the current mission count BEFORE asking. This is the
        // SOLO-reachable arming input (PaywallGate condition C); recording it at
        // the open point needs no extra listener — by the time someone opens a
        // mission the count is already correct, and arming here still lands on
        // the calm entry point rather than mid-celebration.
        paywallGate.recordMissionCount(missionStore.missions.count, scopeId: scopeId)

        if paywallGate.shouldPresentAtMissionStart(scopeId: scopeId) {
            // Soft mode is show-once; latch it. Hard mode presents every time,
            // so it deliberately never latches.
            if !paywallGate.hardMode {
                paywallGate.markShown(scopeId: scopeId)
            }
            missionAfterPaywall = mission
            showPaywall = true
            AppAnalytics.log("paywall_shown", [
                "trigger": "mission_start",
                // Splits the funnel by whether the wall is reaching the ~96% of
                // users who are unpaired — the whole point of the 1.0.8 change.
                "scope": coupleService.coupleId == nil ? "solo" : "couple"
            ])
        } else {
            missionToOpen = mission
        }
    }

    // MARK: - Greeting

    // Prominent, unpaired-only invite CTA on the dashboard — the coral gradient
    // makes it the clear primary action. Opens the same PairingView the Us tab
    // uses; vanishes once the couple pairs (coupleId != nil).
    private var connectPartnerCard: some View {
        Button {
            showPairing = true
        } label: {
            HStack(spacing: 14) {
                Text("💕").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Better with your partner")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Invite them to swipe date ideas and plan together")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(LouvGradient.coral, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
        }
        .buttonStyle(.plain)
    }

    private var greetingSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // The greeting IS the header — no redundant "iLovu" wordmark (it's
                // already the app name in the tab bar). Matches NearYouView.
                Text(greetingText)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.deepRose)

                // The PARTNER's name (the member that isn't you), read off the
                // couple's displayNames via CoupleService. Only shown once they've
                // set one — otherwise we'd just print a placeholder.
                if let partner = coupleService.partnerDisplayName {
                    Text("With \(partner) 💞")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.gray)
                }

                // The payoff for setting an anniversary — only shown once it's set.
                if let days = coupleService.daysTogether {
                    Text("\(days.formatted()) days together 💕")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.louvCoral)
                }
            }

            Spacer(minLength: 0)

            // Shared couple photo as a small avatar — display only here (setting
            // it lives in the Us tab). Shown only once a photo exists, so the
            // calm Home header isn't cluttered with a prompt.
            if let path = coupleService.couplePhotoPath, !path.isEmpty {
                CachedStorageImage(path: path,
                                   version: coupleService.couplePhotoVersion) {
                    Circle().fill(Color.blushCream)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.louvCoral.opacity(0.3), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Reads the current hour and picks morning / afternoon / evening.
    // Falls back gracefully if the user skipped the name field in
    // onboarding.
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part: String
        switch hour {
        case 5..<12:  part = "morning"
        case 12..<18: part = "afternoon"
        default:      part = "evening"
        }
        // 💕 only for couples — for everyone else this is a places app.
        let emoji = isPaired ? "💕" : "📍"
        return userName.isEmpty
            ? "Good \(part) \(emoji)"
            : "Good \(part), \(userName) \(emoji)"
    }

    // MARK: - Spark Score

    private var sparkScoreCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Your Spark This Month")

            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { index in
                    Text("🔥")
                        .font(.system(size: 30))
                        // Filled flames stay vivid; unfilled go grey
                        // and faded. .grayscale strips the color and
                        // .opacity dims them so they read as clearly
                        // "off".
                        .grayscale(index < sparkScore ? 0 : 1)
                        .opacity(index < sparkScore ? 1 : 0.3)
                }
            }

            Text("Couples who share one real date a month stay happiest 💕")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    // The whisper line under the spark card — italicized, small,
    // centered. Reinforces the no-pressure positioning.
    private var gentleReminder: some View {
        Text("No pressure — even a 5-minute moment counts.")
            .font(.system(size: 13))
            .italic()
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - This Week's Suggestion

    private var thisWeeksSuggestionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("This week's idea")

            HStack(spacing: 16) {
                Text(tonightsCard.emoji)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 6) {
                    Text(tonightsCard.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.deepRose)
                        .multilineTextAlignment(.leading)

                    Text(tonightsCard.difficulty.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.louvCoral)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            Button {
                // The whole cross-view wiring is right here: flip the
                // shared binding and SwiftUI does the rest. MainTabView
                // sees its @State change and the TabView animates over
                // to the Cards tab automatically.
                withAnimation(LouvAnimation.spring) {
                    selectedTab = .cards
                }
            } label: {
                Text("Find an idea →")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LouvGradient.coral)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    // MARK: - Missions
    // The bridge between matching and doing. Upcoming missions show
    // as small tappable rows; tap to open MissionDetailView. If the
    // list is empty we show a warm prompt that points back to the
    // Cards tab — the only way new missions get created today.

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(isPaired ? "Your Missions" : "Your Places")

            // Matches float to the top. Since a right-swipe now saves a plan on
            // its own, this list mixes "I saved this" with "we both want this" —
            // the higher-intent one should not be buried under a shortlist.
            let upcoming = missionStore.matchesFirst(missionStore.upcoming)
            if upcoming.isEmpty {
                missionsEmptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(upcoming) { mission in
                        missionRow(mission)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
    }

    private var missionsEmptyState: some View {
        Text(isPaired ? "No missions yet — swipe to match on a date idea 💕"
                          : "Nothing saved yet — swipe a place you like in Near You 📍")
            .font(.system(size: 14))
            .foregroundStyle(.gray)
            .multilineTextAlignment(.leading)
    }

    private func missionRow(_ mission: Mission) -> some View {
        Button {
            openMission(mission)
        } label: {
            HStack(spacing: 12) {
                Text(mission.card.emoji)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(Color.blushCream)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.card.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.deepRose)
                        .multilineTextAlignment(.leading)
                    // Tells the two kinds of row apart. Before a right-swipe saved
                    // anything on its own, every mission WAS a match and no label
                    // was needed; now the list is mixed and this is the signal.
                    if missionStore.matchedCardIds.contains(mission.cardId) {
                        Text("💕 You both liked this")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.louvCoral)
                    } else if let date = mission.scheduledDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Long-press for a quick delete without opening the mission (the full
        // delete + confirm also lives in MissionDetailView).
        .contextMenu {
            Button(role: .destructive) {
                missionStore.delete(mission)
            } label: {
                Label("Delete mission", systemImage: "trash")
            }
        }
    }

    // MARK: - Nudge Partner
    // A soft secondary button that sends a real "come swipe with me" push to the
    // partner via the `nudgePartner` callable Cloud Function. Spam-prevention is
    // now SERVER-authoritative (one nudge per couple per cooldown); the button
    // disables while a call is in flight or while the shared cooldown is active
    // (coupleService.canSendManualNudge, read live off the couple doc).

    // True when the per-couple cooldown is active — button shows a calm resting
    // state instead of the invite, and taps are blocked.
    private var nudgeOnCooldown: Bool { !coupleService.canSendManualNudge }

    // Button is inert while sending OR cooling down.
    private var nudgeDisabled: Bool { isSendingNudge || nudgeOnCooldown }

    // Use the partner's name if we have one; otherwise warm fallback.
    private var nudgeTarget: String {
        coupleService.partnerDisplayName ?? "your partner"
    }

    private var nudgeButtonLabel: String {
        if isSendingNudge { return "Sending…" }
        if nudgeOnCooldown { return "Nudge sent — check back soon 💕" }
        return "💕 Nudge \(nudgeTarget) to swipe"
    }

    private var nudgeButton: some View {
        Button(action: sendNudge) {
            Text(nudgeButtonLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(nudgeDisabled ? Color.gray : Color.louvCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        nudgeDisabled
                            ? Color.gray.opacity(0.25)
                            : Color.louvCoral.opacity(0.45),
                        lineWidth: 1.5
                    )
                )
                .louvShadow()
        }
        .buttonStyle(.plain)
        .disabled(nudgeDisabled)
    }

    // The toast that drops in from the top after a nudge attempt. Message varies
    // by outcome (sent / cooldown / partner-unreachable / error).
    private func nudgeToastView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.matchGreen)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.deepRose)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(Capsule())
        .louvShadow()
    }

    // Fires the real nudge: haptic, call the callable, then show outcome copy.
    // The server enforces the per-couple cooldown, so even a stale-enabled button
    // can't actually spam — a cooldown reply just shows the resting message.
    private func sendNudge() {
        guard !isSendingNudge else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isSendingNudge = true
        Task {
            let outcome = await coupleService.nudgePartner()
            isSendingNudge = false
            switch outcome {
            case .sent:
                showNudgeToast("Nudge sent! 💕")
            case .partnerUnreachable:
                // Partner hasn't turned on notifications — be honest, stay warm.
                showNudgeToast("\(nudgeTarget) hasn't turned on nudges yet")
            case .cooldown:
                showNudgeToast("Already nudged — check back soon 💕")
            case .notPaired:
                showNudgeToast("Connect with your partner first")
            case .failed:
                showNudgeToast("Couldn't send just now — try again")
            }
        }
    }

    // Shows a toast and auto-dismisses it after ~2.5s, but only clears it if the
    // same message is still showing (so a newer toast isn't cut short).
    private func showNudgeToast(_ message: String) {
        withAnimation(LouvAnimation.spring) { nudgeToast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if nudgeToast == message {
                withAnimation(.easeOut(duration: 0.3)) { nudgeToast = nil }
            }
        }
    }

    // MARK: - Quick Stats

    /// One-time prompt to put Days Together on the home screen.
    ///
    /// "love counter" is the #1 converting Apple Search Ads keyword — people pay
    /// to install FOR this — but iOS offers NO way to add a widget
    /// programmatically, and almost nobody discovers the long-press flow on their
    /// own. So the surface they came for never reaches the place it matters. That
    /// is what this card fixes; the widget itself has shipped since 1.0.2.
    ///
    /// Shown only once there is a date to count from (otherwise the widget would
    /// render empty), and dismissible for good — this is a hint, not a nag, and
    /// there is no API to detect whether they already added it.
    @ViewBuilder
    private var addWidgetCard: some View {
        if !widgetPromptDismissed, coupleService.effectiveDaysTogether != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Keep it on your home screen 💛")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.deepRose)
                    Spacer()
                    Button {
                        withAnimation(LouvAnimation.spring) { widgetPromptDismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
                Text("Touch and hold your home screen → tap ➕ → search iLovu → add **Days Together**.")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .louvShadow()
        }
    }

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            statCard(number: missionsCompletedCount, label: isPaired ? "Missions" : "Visited")
            // "Days Together" whenever a dating date exists — effectiveDaysTogether
            // so it also works for an unpaired user who set one.
            //
            // The old `else` branch showed a "Day Streak" card backed by
            // @AppStorage("dayStreak"), which was initialised to 1 and NEVER
            // written anywhere in the repo: anyone without a date saw "1 Day
            // Streak" permanently, a stat that can never move. It also contradicted
            // the locked "no streaks, no shame" rule stated at the top of this file
            // and in DailyQuestionCard, and it was mutually exclusive with Days
            // Together — so it vanished for the MORE invested user. Removed rather
            // than wired: a self-directed streak is off-brand by decision.
            if let days = coupleService.effectiveDaysTogether {
                statCard(number: days, label: "Days Together")
            }
            if isPaired {
                statCard(number: memoriesSavedCount, label: "Memories")
            } else {
                statCard(number: missionStore.missions.count, label: "Saved")
            }
        }
    }

    private func statCard(number: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(number.formatted())
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .louvShadow()
    }

    // MARK: - Shared helpers

    // The small uppercase grey headers above each card's content.
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

#Preview {
    // .constant gives the preview a fake binding so HomeView renders
    // standalone without needing a real parent to own the state.
    HomeView(selectedTab: .constant(.home))
        .environment(MissionStore())
        .environment(MemoryStore())
        .environment(CoupleService())
        .environment(PaywallGate())
        .environment(SubscriptionService())
}
