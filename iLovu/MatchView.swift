// MatchView.swift
// The celebration screen that pops up when a swipe-right turns into a match.
// Full-screen coral gradient, springy heart, falling confetti, success haptic.
// Designed to feel like a tiny moment of joy — not just a modal alert.

import SwiftUI

struct MatchView: View {

    // The card that triggered the match — we show its title so the
    // user knows exactly which date idea they just matched on.
    let card: DateCard

    // SwiftUI's built-in dismiss action. Works because we're presented
    // via .fullScreenCover from the parent. Calling it slides us away.
    @Environment(\.dismiss) private var dismiss

    // Drives the heart's "pop" animation. We change it in stages from
    // .onAppear: 0.3 → 1.2 → 1.0. SwiftUI animates the transitions.
    @State private var heartScale: CGFloat = 0.3

    var body: some View {
        ZStack {
            // Signature gradient covering the whole screen.
            LouvGradient.coral.ignoresSafeArea()

            // The falling confetti layer sits behind the text so it doesn't
            // obscure it. Each piece is its own animated subview.
            ConfettiLayer()

            VStack(spacing: 24) {
                Spacer()

                // The hero heart. starts tiny, overshoots, settles.
                Text("💖")
                    .font(.system(size: 120))
                    .scaleEffect(heartScale)

                // Headline.
                Text("It's a Match! 🎉")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                // Which card matched, so the moment feels specific.
                Text(card.title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Action buttons.
                VStack(spacing: 16) {
                    // Primary CTA — white pill, coral text. Stands out
                    // strongly against the gradient.
                    Button {
                        // No planning flow yet — just dismiss for now.
                        dismiss()
                    } label: {
                        Text("Plan This Date")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.louvCoral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }

                    // Secondary — outline only, lower visual weight.
                    Button {
                        dismiss()
                    } label: {
                        Text("Keep Swiping")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                Capsule().stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            // Celebratory tap — the "good news" haptic.
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Stage 1: pop up past the final size (overshoot at 1.2).
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                heartScale = 1.2
            }
            // Stage 2: settle back to the natural 1.0 size.
            // 0.4s delay lets the overshoot complete first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(LouvAnimation.spring) {
                    heartScale = 1.0
                }
            }
        }
    }
}

// MARK: - ConfettiLayer
// 40 little circles drifting from above the screen to below it,
// each with its own random color, size, x position, delay, and duration.
// The randomness is what makes it feel alive rather than mechanical.
private struct ConfettiLayer: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<40, id: \.self) { _ in
                    ConfettiPiece(screenSize: geo.size)
                }
            }
        }
        .ignoresSafeArea()
        // Confetti is decoration — don't let it eat taps meant for the buttons.
        .allowsHitTesting(false)
    }
}

// MARK: - ConfettiPiece
// One little falling circle. It picks all its random properties ONCE
// when it's created (stored in @State), then animates itself from
// above the screen to below it on appear.
private struct ConfettiPiece: View {
    let screenSize: CGSize

    // A small palette of warm + festive colors. Picked once per piece.
    private static let palette: [Color] = [
        .white, .yellow, .louvCoral, .louvOrange, .deepRose
    ]

    // All randomness is captured at creation time so the piece is stable
    // (it doesn't pick new random values on every redraw).
    @State private var color: Color = ConfettiPiece.palette.randomElement()!
    @State private var size: CGFloat = .random(in: 6...12)
    @State private var xPosition: CGFloat = .random(in: 0...1)
    @State private var delay: Double = .random(in: 0...1.5)
    @State private var duration: Double = .random(in: 2.0...3.5)

    // The piece's current vertical position, as a fraction of screen height.
    // Starts above the screen (-0.1), animates to below it (1.2).
    @State private var yProgress: CGFloat = -0.1

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(
                x: xPosition * screenSize.width,
                y: yProgress * screenSize.height
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration).delay(delay)
                ) {
                    yProgress = 1.2
                }
            }
    }
}

#Preview {
    MatchView(card: SampleCards.all[0])
}
