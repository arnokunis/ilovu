// SignInView.swift
// The sign-in screen: brand wordmark, a short line of reassurance, and the
// official "Sign in with Apple" button wired to AppleSignInViewModel.
//
// Styled to match the rest of iLovu — blush-cream background, coral wordmark,
// pill-shaped button with our soft coral shadow. The button itself uses
// Apple's required SignInWithAppleButton (we only control height, shape, and
// shadow; Apple owns the logo, label, and interaction per their guidelines).
//
// This screen is intentionally standalone for now: it confirms a successful
// Firebase sign-in on-screen and in the console, but doesn't yet route the
// app into a signed-in state. That comes next.

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

                    // Temporary success confirmation for build-testing, before
                    // we add real signed-in routing.
                    if let uid = viewModel.signedInUID {
                        Text("Signed in ✓  \(uid.prefix(8))…")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.matchGreen)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .animation(LouvAnimation.spring, value: viewModel.errorMessage)
                .animation(LouvAnimation.spring, value: viewModel.signedInUID)
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
