// DailyQuestionCard.swift
// One thoughtful question per day, shown at the top of the Us tab.
// Anti-pressure by design: no notifications, no streaks, no shame.
// It just sits there warmly until you feel like answering.
//
// Three visual states (the real "answer to unlock" mechanic):
//   1. Answering — text field + Save button + "no rush" reassurance
//   2. Answered, partner hasn't  — your answer + "waiting for your partner" lock
//   3. Both answered             — your answer + your partner's, revealed
//
// PAIRED: answers sync through DailyQuestionService to
// couples/{id}/dailyAnswers/{dateKey}. You only ever see your partner's answer
// AFTER you've answered (state 2 -> 3 when they answer too) — the gate is the
// same "both present" check matching uses on likedBy. The partner's answer
// arrives passively via the doc's snapshot listener (live on the Us tab, fresh
// on open) — no push.
//
// UNPAIRED: falls back to the original local-only @AppStorage journaling (no
// partner to sync with), so nothing regresses before pairing.
//
// The question itself needs no syncing — ConnectionQuestions.today is picked by
// day-of-year, so both partners independently see the same prompt.

import SwiftUI
import FirebaseFirestore

struct DailyQuestionCard: View {

    /// The current couple's id, or nil when unpaired (local-only fallback).
    let coupleId: String?

    @Environment(DailyQuestionService.self) private var dailyService

    // Unpaired local-only fallback — the original behavior. We store the answer
    // text AND the date it was saved, to tell "answered TODAY" from stale.
    @AppStorage("dailyAnswerText")    private var savedAnswer: String        = ""
    @AppStorage("dailyAnswerDateKey") private var savedAnswerDateKey: String = ""

    // The in-progress text the user is typing. Kept separate so we can validate
    // (disable Save on empty) without writing on every keystroke.
    @State private var draftAnswer: String = ""

    // Paired state, delivered by the dailyAnswers listener: my answer and my
    // partner's (nil until each is written). Partner is gated behind mine in the UI.
    @State private var mineAnswer: String?
    @State private var partnerAnswer: String?
    @State private var listener: ListenerRegistration?

    private var isPaired: Bool { coupleId != nil }

    /// My answer for today, from the synced doc when paired or @AppStorage when
    /// not. nil => I haven't answered today => show the answering view.
    private var myAnswerText: String? {
        if isPaired { return mineAnswer }
        return (!savedAnswer.isEmpty && savedAnswerDateKey == ConnectionQuestions.todayDateKey)
            ? savedAnswer : nil
    }

    private var hasAnsweredToday: Bool { myAnswerText != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Today's Question 💬")

            Text(ConnectionQuestions.today)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.leading)
                // fixedSize so long questions wrap rather than truncate.
                .fixedSize(horizontal: false, vertical: true)

            if hasAnsweredToday {
                answeredView
            } else {
                answeringView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .louvShadow()
        // Listen to today's shared doc while the card is on screen; re-key if the
        // couple link changes mid-session (e.g. pairing completes on the Us tab).
        .onAppear { attachListener() }
        .onDisappear { detachListener() }
        .onChange(of: coupleId) { _, _ in attachListener() }
    }

    // MARK: - Answering state

    private var answeringView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // axis: .vertical lets the field grow as the user types, up to 5 lines.
            TextField("Type your answer...", text: $draftAnswer, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(size: 15))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.blushCream)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Answer anytime — no rush 💕")
                .font(.system(size: 12))
                .italic()
                .foregroundStyle(.gray)

            Button(action: saveAnswer) {
                Text("Save my answer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LouvGradient.coral)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isDraftEmpty)
            .opacity(isDraftEmpty ? 0.5 : 1)
        }
        .transition(.opacity)
    }

    private var isDraftEmpty: Bool {
        draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Answered state (my answer + reveal / waiting / connect)

    private var answeredView: some View {
        VStack(alignment: .leading, spacing: 12) {
            answerBlock(label: "Your answer", text: myAnswerText ?? "", tint: Color.deepRose)

            if isPaired {
                if let partnerAnswer {
                    // Both answered — the reveal.
                    answerBlock(label: "Their answer", text: partnerAnswer, tint: Color.louvCoral)
                } else {
                    // I've answered; they haven't yet.
                    lockedPanel(
                        icon: "lock.fill",
                        title: "Waiting for your partner...",
                        subtitle: "They'll see your answer once they answer too 💕"
                    )
                }
            } else {
                // No partner to sync with yet.
                lockedPanel(
                    icon: "heart.fill",
                    title: "Just between you two, soon",
                    subtitle: "Connect with your partner to swap answers 💕"
                )
            }
        }
        .transition(.opacity)
    }

    private func answerBlock(label: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.blushCream)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func lockedPanel(icon: String, title: String, subtitle: String) -> some View {
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
    }

    // MARK: - Actions

    private func saveAnswer() {
        let trimmed = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if let coupleId {
            // Optimistic: show my answer immediately; the listener confirms it and
            // brings the partner's in when they answer.
            withAnimation(LouvAnimation.spring) {
                mineAnswer  = trimmed
                draftAnswer = ""
            }
            Task {
                await dailyService.saveAnswer(
                    coupleId: coupleId,
                    dateKey:  ConnectionQuestions.todayDateKey,
                    question: ConnectionQuestions.today,
                    answer:   trimmed
                )
            }
        } else {
            // Unpaired: local-only journaling (unchanged original behavior).
            withAnimation(LouvAnimation.spring) {
                savedAnswer        = trimmed
                savedAnswerDateKey = ConnectionQuestions.todayDateKey
                draftAnswer        = ""
            }
        }
    }

    // MARK: - Listener lifecycle

    private func attachListener() {
        detachListener()
        mineAnswer = nil
        partnerAnswer = nil
        guard let coupleId else { return }
        listener = dailyService.observeToday(
            coupleId: coupleId,
            dateKey:  ConnectionQuestions.todayDateKey
        ) { mine, partner in
            withAnimation(LouvAnimation.spring) {
                mineAnswer    = mine
                partnerAnswer = partner
            }
        }
    }

    private func detachListener() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Shared

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

#Preview {
    DailyQuestionCard(coupleId: nil)
        .environment(DailyQuestionService())
        .padding(20)
        .background(Color.blushCream)
}
