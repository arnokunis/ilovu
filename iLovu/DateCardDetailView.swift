// DateCardDetailView.swift
// The detail sheet shown when the user TAPS a date card on the Cards
// swipe deck (instead of swiping it). Mirrors EventDetailView's visual
// rhythm — same blush cream background, same pill styling, same close
// button — so the two detail screens feel like siblings.
//
// Unlike EventDetailView there's no Places fetch and no booking flow:
// a date card is editorial content, not a venue. The screen exists to
// give a swiped-on idea a little more room to breathe and to coach the
// couple on how to actually pull it off.

import SwiftUI

struct DateCardDetailView: View {

    let card: DateCard

    @Environment(\.dismiss) private var dismiss

    // The 36-Questions / Closeness-Questions cards carry an actual guided exercise
    // (Aron's set) — surfaced via a button + sheet so the card isn't a dead promise.
    @State private var showQuestions = false
    private var hasGuidedQuestions: Bool { ThirtySixQuestions.cardIds.contains(card.cardId) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    emojiBlock
                    titleBlock
                    descriptionBlock
                    if hasGuidedQuestions { guidedQuestionsButton }
                    whyThisWorksSection
                    tipsSection
                }
                .padding(.bottom, 32)
            }

            closeButton
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
        .background(Color.blushCream.ignoresSafeArea())
        .sheet(isPresented: $showQuestions) {
            ThirtySixQuestionsView()
        }
    }

    // MARK: - Guided questions entry

    private var guidedQuestionsButton: some View {
        Button { showQuestions = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.system(size: 15, weight: .semibold))
                Text("See the 36 questions")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(LouvGradient.coral)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .louvShadow()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Emoji

    private var emojiBlock: some View {
        Text(card.emoji)
            .font(.system(size: 96))
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    // MARK: - Title + pills

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepRose)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Three pills (category, difficulty, cost) instead of the
            // two on the card itself — the extra room here lets us
            // surface the category too. ScrollView keeps them on one
            // visual row even when "Full Day Adventure" runs long.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pill(text: card.category.rawValue.capitalized, background: .deepRose)
                    pill(text: card.difficulty.rawValue,           background: .louvCoral)
                    pill(text: card.estimatedCost.rawValue,        background: .louvOrange)
                }
            }
        }
        .padding(.horizontal, 20)
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

    // MARK: - Description

    private var descriptionBlock: some View {
        Text(card.description)
            .font(.system(size: 15))
            .foregroundStyle(.gray)
            .lineSpacing(3)
            .padding(.horizontal, 20)
    }

    // MARK: - Why this works

    private var whyThisWorksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Why this works")

            Text(card.whyItWorks)
                .font(.system(size: 15))
                .foregroundStyle(Color.deepRose)
                .lineSpacing(3)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .louvShadow()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("How to pull it off")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(card.tips, id: \.self) { tip in
                    tipRow(tip)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .louvShadow()
        }
        .padding(.horizontal, 20)
    }

    private func tipRow(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.louvCoral)
                .padding(.top, 5)
            Text(tip)
                .font(.system(size: 14))
                .foregroundStyle(Color.deepRose)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.4))
        }
    }

    // MARK: - Shared

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 4)
    }
}

#Preview {
    DateCardDetailView(card: SampleCards.all[0])
}
