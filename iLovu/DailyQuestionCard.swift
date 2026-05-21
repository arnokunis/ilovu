// DailyQuestionCard.swift
// One thoughtful question per day, shown at the top of the Us tab.
// Anti-pressure by design: no notifications, no streaks, no shame.
// It just sits there warmly until you feel like answering.
//
// Two visual states:
//   1. Answering — text field + Save button + "no rush" reassurance
//   2. Answered  — user's saved answer + a soft "waiting for your
//                  partner" lock (real partner sync arrives with
//                  Firebase later; for now this is local-only)
//
// Persistence is keyed by the calendar day. Saving on a new day
// silently overwrites the previous day's answer in storage — and
// reading on a new day reveals the fresh question with an empty
// field, because the saved date key no longer matches today.

import SwiftUI

struct DailyQuestionCard: View {

    // Persisted across launches. We store the answer text AND the
    // date it was saved, so we can tell "did the user answer TODAY"
    // (vs answered yesterday and is now looking at a stale state).
    @AppStorage("dailyAnswerText")    private var savedAnswer: String        = ""
    @AppStorage("dailyAnswerDateKey") private var savedAnswerDateKey: String = ""

    // The in-progress text the user is typing. Kept separate from
    // savedAnswer so we can validate (e.g. disable Save on empty)
    // without writing to @AppStorage on every keystroke.
    @State private var draftAnswer: String = ""

    // True only when there is a saved answer AND it was saved today.
    // Drives which of the two views is shown.
    private var hasAnsweredToday: Bool {
        !savedAnswer.isEmpty && savedAnswerDateKey == ConnectionQuestions.todayDateKey
    }

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
    }

    // MARK: - Answering state

    private var answeringView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // axis: .vertical lets the field grow as the user types,
            // up to 5 lines. lineLimit gives min + max bounds.
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

    // MARK: - Answered state

    private var answeredView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The user's own answer, replayed back to them.
            VStack(alignment: .leading, spacing: 6) {
                Text("Your answer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(savedAnswer)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.deepRose)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.blushCream)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Soft locked panel for the partner's side. Stub for now —
            // real partner sync will replace this with the partner's
            // answer once both have answered.
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.louvCoral)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Waiting for your partner...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.deepRose)
                    Text("They'll see your answer once they answer too 💕")
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
        .transition(.opacity)
    }

    // MARK: - Actions

    private func saveAnswer() {
        let trimmed = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(LouvAnimation.spring) {
            savedAnswer        = trimmed
            savedAnswerDateKey = ConnectionQuestions.todayDateKey
            draftAnswer        = ""
        }
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
    DailyQuestionCard()
        .padding(20)
        .background(Color.blushCream)
}
