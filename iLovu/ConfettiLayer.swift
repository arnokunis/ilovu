// ConfettiLayer.swift
// 40 little circles drifting from above the screen to below it,
// each with its own random color, size, x position, delay, and
// duration. The randomness is what makes it feel alive rather
// than mechanical.
//
// Used by MatchView (date card match) and EventMatchView (event
// match) so both celebrations look identical.

import SwiftUI

struct ConfettiLayer: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<40, id: \.self) { _ in
                    ConfettiPiece(screenSize: geo.size)
                }
            }
        }
        .ignoresSafeArea()
        // Confetti is decoration — don't let it eat taps meant for the
        // buttons underneath.
        .allowsHitTesting(false)
    }
}

// MARK: - ConfettiPiece
// One falling circle. It picks all its random properties ONCE when
// it's created (stored in @State), then animates itself from above
// the screen to below it on appear. Picking once means a redraw
// doesn't shuffle every piece — they stay on their own paths.
private struct ConfettiPiece: View {
    let screenSize: CGSize

    // A small palette of warm + festive colors. Picked once per piece.
    private static let palette: [Color] = [
        .white, .yellow, .louvCoral, .louvOrange, .deepRose
    ]

    @State private var color: Color = ConfettiPiece.palette.randomElement()!
    @State private var size: CGFloat = .random(in: 6...12)
    @State private var xPosition: CGFloat = .random(in: 0...1)
    @State private var delay: Double = .random(in: 0...1.5)
    @State private var duration: Double = .random(in: 2.0...3.5)

    // The piece's current vertical position, as a fraction of screen
    // height. Starts above the screen (-0.1), animates to below it (1.2).
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
