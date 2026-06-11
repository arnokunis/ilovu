//
//  ContentView.swift
//  iLovu
//
//  Created by Arnoldas on 20/05/2026.
//

import SwiftUI

struct ContentView: View {
    // Firebase auth state, owned at the app root. Drives the top-level
    // signed-in vs signed-out routing below.
    @Environment(AuthState.self) private var authState

    // The first-launch onboarding flow flips this to true when finished.
    // Only consulted once the user is signed in.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        ZStack {
            switch authState.status {
            case .loading:
                // Brief splash while Firebase restores any persisted session,
                // so a returning user never flashes past the sign-in screen.
                launchScreen

            case .signedOut:
                SignInView()
                    .transition(.opacity)

            case .signedIn:
                signedInFlow
                    .transition(.opacity)
            }
        }
        // Cross-fades between sign-in, onboarding, and the tab app as auth
        // state changes.
        .animation(.easeInOut(duration: 0.35), value: authState.status)
    }

    // Signed-in users still go through onboarding once before reaching the
    // main tabs; afterwards they land straight on MainTabView.
    @ViewBuilder
    private var signedInFlow: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }

    private var launchScreen: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("iLovu")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.louvCoral)
                ProgressView()
                    .tint(Color.louvCoral)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthState())
}
