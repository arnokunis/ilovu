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

    // Hidden reviewer/demo login (email + password), revealed by a long-press on
    // the wordmark. Kept out of the normal flow on purpose — production sign-in
    // is Sign in with Apple only; this exists so App Review can reach a pre-paired
    // demo couple (see AppleSignInViewModel.signIn(email:password:)).
    @State private var showDemoLogin = false
    @State private var demoEmail = ""
    @State private var demoPassword = ""

    var body: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 16) {
                    Text("iLovu")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.louvCoral)
                        // Hidden reviewer/demo login reveal — normal users never
                        // discover it; App Review is told the gesture in the notes.
                        .onLongPressGesture(minimumDuration: 1.5) {
                            withAnimation(LouvAnimation.spring) { showDemoLogin = true }
                        }

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

                    // Reviewer/demo login — revealed only by the wordmark long-press.
                    if showDemoLogin {
                        VStack(spacing: 12) {
                            TextField("Email", text: $demoEmail)
                                .textContentType(.username)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            SecureField("Password", text: $demoPassword)
                                .textContentType(.password)

                            Button {
                                Task { await viewModel.signIn(email: demoEmail, password: demoPassword) }
                            } label: {
                                Text("Sign in")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(Color.louvCoral, in: Capsule())
                            }
                            .disabled(viewModel.isSigningIn || demoEmail.isEmpty || demoPassword.isEmpty)
                        }
                        .textFieldStyle(.roundedBorder)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
