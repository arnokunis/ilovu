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

    // Opens the paywall's Terms / Privacy links in Safari (external browser).
    @Environment(\.openURL) private var openURL

    // 0...5. Drives how many of the five flame emojis are lit.
    // Conceptually: one completed Mission = a big spark boost; a quick
    // micro-moment = a small boost. The UI doesn't differentiate them
    // — both feed into the same score.
    @AppStorage("sparkScore") private var sparkScore: Int = 2

    // Day streak stays as an @AppStorage placeholder until we wire it
    // to real activity data. The other two stats are now derived from
    // the live stores below — single source of truth, no duplication.
    @AppStorage("dayStreak") private var dayStreak: Int = 1

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

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            // ScrollView so the dashboard still works on smaller phones
            // where the sections might exceed screen height.
            ScrollView {
                VStack(spacing: 24) {
                    greetingSection
                    sparkScoreCard
                    gentleReminder
                    thisWeeksSuggestionCard
                    missionsSection
                    nudgeButton
                    quickStatsRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

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
        // Paywall presented in place of opening the mission when the gate is
        // armed. In SOFT mode (paywallGate.hardMode == false) dismissing the
        // wall continues to the tapped mission, so it never blocks the date. In
        // HARD mode the dismiss-through is withheld unless the couple actually
        // subscribed on the wall just now — the mission stays closed otherwise.
        .sheet(isPresented: $showPaywall, onDismiss: {
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
                annualPriceText:    subscriptionService.annualDisplay?.priceText,
                annualPerMonthText: subscriptionService.annualDisplay?.perMonthText,
                monthlyPriceText:   subscriptionService.monthlyDisplay?.priceText,
                onPurchase: { plan in
                    switch plan {
                    case .annual:  await subscriptionService.purchaseAnnual()
                    case .monthly: await subscriptionService.purchaseMonthly()
                    }
                },
                onRestore: { await subscriptionService.restore() },
                // Live URLs (ilovu.io pages ship separately — fine if they 404 today).
                onTerms:   { openURL(URL(string: "https://ilovu.io/terms")!) },
                onPrivacy: { openURL(URL(string: "https://ilovu.io/privacy")!) }
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
        if let coupleId = coupleService.coupleId,
           paywallGate.shouldPresentAtMissionStart(coupleId: coupleId) {
            // Soft mode is show-once; latch it. Hard mode presents every time,
            // so it deliberately never latches.
            if !paywallGate.hardMode {
                paywallGate.markShown(coupleId: coupleId)
            }
            missionAfterPaywall = mission
            showPaywall = true
        } else {
            missionToOpen = mission
        }
    }

    // MARK: - Greeting

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
        return userName.isEmpty
            ? "Good \(part) 💕"
            : "Good \(part), \(userName) 💕"
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
            sectionLabel("Your Missions")

            let upcoming = missionStore.upcoming
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
        Text("No missions yet — swipe to match on a date idea 💕")
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
                    if let date = mission.scheduledDate {
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

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            statCard(number: missionsCompletedCount, label: "Missions")
            // Real "Days Together" once an anniversary is set; falls back to the
            // placeholder Day Streak until then.
            if let days = coupleService.daysTogether {
                statCard(number: days, label: "Days Together")
            } else {
                statCard(number: dayStreak, label: "Day Streak")
            }
            statCard(number: memoriesSavedCount,     label: "Memories")
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
