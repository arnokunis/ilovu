// HomeView.swift
// The home dashboard — the first screen users see each time they open
// the app. iLovu's positioning is the anti-pressure couples app:
// research shows one or two intentional dates per month is the sweet
// spot for relationship satisfaction; daily nagging causes stress and
// kills the benefit. So this dashboard is deliberately calm: monthly
// goals, micro-moments count, no streaks-or-shame language.

import SwiftUI

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

    // Not collected anywhere yet — placeholder for when partner sync is
    // added. Falls back to "your partner" if empty.
    @AppStorage("partnerName") private var partnerName: String = ""

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

    // Timestamp of the last partner nudge. Stored as a Double (seconds
    // since 1970) because @AppStorage handles Double natively. We use
    // Calendar.isDateInToday rather than a raw date string so timezones
    // and DST never trip us up.
    @AppStorage("lastNudgeTimestamp") private var lastNudgeTimestamp: Double = 0

    // Picked once per HomeView instance (~once per app launch) so the
    // suggestion stays stable while the user looks at the dashboard.
    @State private var tonightsCard: DateCard = SampleCards.all.randomElement()!

    // Drives the brief "Nudge sent! 💕" toast at the top of the screen.
    @State private var showNudgeConfirmation: Bool = false

    // When set, MissionDetailView is presented as a sheet so the user
    // can edit / mark complete the tapped mission.
    @State private var missionToOpen: Mission?

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
            if showNudgeConfirmation {
                VStack {
                    nudgeConfirmationToast
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
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("iLovu")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.louvCoral)

            Text(greetingText)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepRose)
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
            missionToOpen = mission
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
    // A soft secondary button. The whole spam-prevention story is in
    // `hasNudgedToday` — once true, the button changes copy, fades,
    // and becomes disabled until midnight (Calendar.isDateInToday
    // does the day-boundary check).

    // True when there's a recorded nudge whose timestamp is in the
    // current calendar day. Cheap to compute on every redraw.
    private var hasNudgedToday: Bool {
        guard lastNudgeTimestamp > 0 else { return false }
        return Calendar.current.isDateInToday(
            Date(timeIntervalSince1970: lastNudgeTimestamp)
        )
    }

    // Use the partner's name if we have one; otherwise warm fallback.
    private var nudgeTarget: String {
        partnerName.isEmpty ? "your partner" : partnerName
    }

    private var nudgeButton: some View {
        Button(action: sendNudge) {
            Text(hasNudgedToday
                 ? "Nudge sent today 💕"
                 : "💕 Nudge \(nudgeTarget) to swipe")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(hasNudgedToday ? Color.gray : Color.louvCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        hasNudgedToday
                            ? Color.gray.opacity(0.25)
                            : Color.louvCoral.opacity(0.45),
                        lineWidth: 1.5
                    )
                )
                .louvShadow()
        }
        .buttonStyle(.plain)
        .disabled(hasNudgedToday)
    }

    // The toast that drops in from the top after a successful nudge.
    private var nudgeConfirmationToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.matchGreen)
            Text("Nudge sent! 💕")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.deepRose)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(Capsule())
        .louvShadow()
    }

    // Records the nudge, vibrates, shows the toast, and schedules its
    // own dismissal. No network call yet — that'll come when partner
    // sync is wired through Firebase.
    private func sendNudge() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        lastNudgeTimestamp = Date().timeIntervalSince1970

        withAnimation(LouvAnimation.spring) {
            showNudgeConfirmation = true
        }

        // Auto-dismiss after ~2s. Long enough to read, short enough to
        // get out of the way before the user moves on.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showNudgeConfirmation = false
            }
        }
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            statCard(number: missionsCompletedCount, label: "Missions")
            statCard(number: dayStreak,              label: "Day Streak")
            statCard(number: memoriesSavedCount,     label: "Memories")
        }
    }

    private func statCard(number: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(number)")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepRose)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
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
}
