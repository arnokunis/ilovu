//
//  ContentView.swift
//  iLovu
//
//  Created by Arnoldas on 20/05/2026.
//

import SwiftUI

struct ContentView: View {
    // The first-launch onboarding flow flips this to true when finished.
    // Once true, it stays true across app launches (until the app is reinstalled
    // or AppStorage is cleared), so returning users go straight to SwipeView.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var matchedCard: DateCard?

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                SwipeView(matchedCard: $matchedCard)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        // Drives the cross-fade when the onboarding flag flips.
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .fullScreenCover(item: $matchedCard) { card in
            MatchView(card: card)
        }
    }
}

#Preview {
    ContentView()
}
