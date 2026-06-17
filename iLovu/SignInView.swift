// SignInView.swift
// The sign-in screen: brand wordmark, a short line of reassurance, and the
// official "Sign in with Apple" button wired to AppleSignInViewModel.
//
// Styled to match the rest of iLovu — blush-cream background, coral wordmark,
// pill-shaped button with our soft coral shadow. The button itself uses
// Apple's required SignInWithAppleButton (we only control height, shape, and
// shadow; Apple owns the logo, label, and interaction per their guidelines).
//
// This screen only collects the sign-in. Routing is owned at the root by
// ContentView, which observes AuthState: a successful sign-in flips auth state
// and cross-fades the app to onboarding (first run) or the main tabs, so there
// is no on-screen success state to show here.

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var viewModel = AppleSignInViewModel()

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 16) {
                    Text("iLovu")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.louvCoral)

                    Text("Sign in to save your sparks and pick up right where you left off.")
                        .font(.system(size: 16))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        viewModel.prepareRequest(request)
                    } onCompletion: { result in
                        viewModel.handleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(Capsule())
                    .louvShadow()
                    .disabled(viewModel.isSigningIn)

                    // Friendly inline error — only present when something failed.
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.passRed)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .animation(LouvAnimation.spring, value: viewModel.errorMessage)
            }

            // Subtle full-screen overlay while Firebase does its exchange.
            if viewModel.isSigningIn {
                Color.black.opacity(0.05).ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.louvCoral)
            }
        }
    }
}

#Preview {
    SignInView()
}
