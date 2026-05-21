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
    // or AppStorage is cleared), so returning users go straight to MainTabView.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        // Drives the cross-fade when the onboarding flag flips.
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
}
