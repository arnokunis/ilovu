// ThirtySixQuestions.swift
// The actual content behind the "36 Questions" (and "Closeness Questions") date
// cards — Arthur Aron's classic set, popularized as "the 36 questions that lead
// to love." The cards used to describe the exercise without ever containing it;
// this file + ThirtySixQuestionsView fix that broken promise.
//
// Structure matters: the three sets escalate in intimacy on purpose. You work
// through them IN ORDER, taking turns, never skipping ahead — that gradual
// self-disclosure is the mechanism, not the questions themselves.

import SwiftUI

enum ThirtySixQuestions {

    /// The date-card cardIds that should surface this exercise (both cards are the
    /// same underlying Aron set). Matched in DateCardDetailView.
    static let cardIds: Set<String> = ["the-36-questions", "the-closeness-questions"]

    struct QuestionSet: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let questions: [String]
    }

    static let sets: [QuestionSet] = [
        QuestionSet(
            title: "Set I",
            subtitle: "Warming up",
            questions: [
                "Given the choice of anyone in the world, whom would you want as a dinner guest?",
                "Would you like to be famous? In what way?",
                "Before making a phone call, do you ever rehearse what you're going to say? Why?",
                "What would constitute a \u{201C}perfect\u{201D} day for you?",
                "When did you last sing to yourself? To someone else?",
                "If you could live to 90 and keep either the mind or body of a 30-year-old for the last 60 years, which would you want?",
                "Do you have a secret hunch about how you will die?",
                "Name three things you and your partner appear to have in common.",
                "For what in your life do you feel most grateful?",
                "If you could change anything about the way you were raised, what would it be?",
                "Take four minutes and tell your partner your life story in as much detail as possible.",
                "If you could wake up tomorrow having gained any one quality or ability, what would it be?"
            ]
        ),
        QuestionSet(
            title: "Set II",
            subtitle: "Getting real",
            questions: [
                "If a crystal ball could tell you the truth about yourself, your life, the future, or anything else, what would you want to know?",
                "Is there something you've dreamed of doing for a long time? Why haven't you done it?",
                "What is the greatest accomplishment of your life?",
                "What do you value most in a friendship?",
                "What is your most treasured memory?",
                "What is your most terrible memory?",
                "If you knew that in one year you would die suddenly, would you change anything about how you're living now? Why?",
                "What does friendship mean to you?",
                "What roles do love and affection play in your life?",
                "Take turns sharing something you consider a positive characteristic of your partner — five things in total.",
                "How close and warm is your family? Do you feel your childhood was happier than most people's?",
                "How do you feel about your relationship with your mother?"
            ]
        ),
        QuestionSet(
            title: "Set III",
            subtitle: "Going deep",
            questions: [
                "Make three true \u{201C}we\u{201D} statements each. For instance, \u{201C}We are both in this room feeling…\u{201D}",
                "Complete this sentence: \u{201C}I wish I had someone with whom I could share…\u{201D}",
                "If you were going to become close friends with your partner, what would be important for them to know?",
                "Tell your partner what you like about them — be honest, saying things you might not say to someone you'd just met.",
                "Share with your partner an embarrassing moment in your life.",
                "When did you last cry in front of another person? By yourself?",
                "Tell your partner something you like about them already.",
                "What, if anything, is too serious to be joked about?",
                "If you were to die this evening with no chance to communicate with anyone, what would you most regret not telling someone? Why haven't you told them yet?",
                "Your house, with everything you own, catches fire. After saving loved ones and pets, you can save one last item. What would it be? Why?",
                "Of all the people in your family, whose death would you find most disturbing? Why?",
                "Share a personal problem and ask your partner's advice on how they might handle it. Then ask them to reflect back how you seem to be feeling about it."
            ]
        )
    ]
}

// MARK: - Viewer

struct ThirtySixQuestionsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro

                    ForEach(ThirtySixQuestions.sets) { set in
                        setBlock(set)
                    }
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .background(Color.blushCream.ignoresSafeArea())
            .navigationTitle("The 36 Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.louvCoral)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Take turns answering, in order. Don't skip ahead — the sets get more personal on purpose. Set aside about an hour.")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .lineSpacing(3)
        }
    }

    private func setBlock(_ set: ThirtySixQuestions.QuestionSet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(set.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                Text(set.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.louvCoral)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(set.questions.enumerated()), id: \.offset) { index, question in
                    questionRow(number: baseNumber(for: set) + index + 1, text: question)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
        }
    }

    private func questionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.louvCoral, in: Circle())
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.deepRose)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// Continuous 1–36 numbering across the three sets.
    private func baseNumber(for set: ThirtySixQuestions.QuestionSet) -> Int {
        var base = 0
        for s in ThirtySixQuestions.sets {
            if s.id == set.id { return base }
            base += s.questions.count
        }
        return base
    }
}

#Preview {
    ThirtySixQuestionsView()
}
