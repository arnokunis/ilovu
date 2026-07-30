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

    // Public email sign-up / sign-in sheet — the low-friction alternative to Apple.
    @State private var showEmailAuth = false

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

                    Text("Sign in to save your dates and pick up right where you left off.")
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

                    // Reassurance: signing in is free. A real tester (the founder's
                    // partner) hesitated to tap Sign in with Apple, fearing it would
                    // charge — the likely cause of the big drop at this screen.
                    Text("Free to start — signing in never charges you 💛")
                        .font(.system(size: 13))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)

                    Text("or")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.7))
                        .padding(.vertical, 2)

                    // Email is the low-friction alternative for anyone wary of Apple
                    // sign-in (a real, observed hesitation). Opens a sign-up / sign-in
                    // sheet; both flow through the same AuthState routing as Apple.
                    Button {
                        viewModel.errorMessage = nil
                        viewModel.noticeMessage = nil
                        showEmailAuth = true
                    } label: {
                        Text("Continue with Email")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.deepRose)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.white, in: Capsule())
                            .louvShadow()
                    }
                    .buttonStyle(.plain)
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
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Email sign-up / sign-in sheet
//
// Presented from "Continue with Email". Segmented toggle between creating an
// account and signing in; a forgot-password link in sign-in mode. On success,
// AuthState flips and ContentView routes the whole app away — this sheet unmounts
// with SignInView, so there's no explicit success dismissal to manage.
private struct EmailAuthSheet: View {
    let viewModel: AppleSignInViewModel
    @Environment(\.dismiss) private var dismiss

    // Default to "Create account" — sign-up is the point of this screen.
    @State private var isCreating = true
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blushCream.ignoresSafeArea()

                VStack(spacing: 18) {
                    Picker("", selection: $isCreating) {
                        Text("Create account").tag(true)
                        Text("Sign in").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isCreating) { _, _ in
                        viewModel.errorMessage = nil
                        viewModel.noticeMessage = nil
                    }

                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .modifier(EmailFieldStyle())
                        SecureField("Password", text: $password)
                            .textContentType(isCreating ? .newPassword : .password)
                            .modifier(EmailFieldStyle())
                    }

                    Button {
                        Task {
                            if isCreating {
                                await viewModel.createAccount(email: email, password: password)
                            } else {
                                await viewModel.signInEmail(email: email, password: password)
                            }
                        }
                    } label: {
                        Text(isCreating ? "Create account" : "Sign in")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.louvCoral, in: Capsule())
                            .opacity(viewModel.isSigningIn ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSigningIn || email.isEmpty || password.isEmpty)

                    if !isCreating {
                        Button("Forgot password?") {
                            Task { await viewModel.sendPasswordReset(email: email) }
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(Color.deepRose)
                    }

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.passRed)
                            .multilineTextAlignment(.center)
                    } else if let notice = viewModel.noticeMessage {
                        Text(notice)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.deepRose)
                            .multilineTextAlignment(.center)
                    }

                    Text("Free to start — you'll never be charged for an account 💛")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Spacer()
                }
                .padding(24)

                if viewModel.isSigningIn {
                    Color.black.opacity(0.05).ignoresSafeArea()
                    ProgressView().controlSize(.large).tint(Color.louvCoral)
                }
            }
            .navigationTitle(isCreating ? "Create account" : "Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.louvCoral)
                }
            }
        }
    }
}

// Explicit field styling: white background + dark text, so the fields are
// readable regardless of light/dark mode. The default label colour goes white
// (invisible) on our always-light blushCream sheet in dark mode — the same fix
// PairingView's redeem field uses.
private struct EmailFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(Color.deepRose)
            .tint(Color.louvCoral)
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    SignInView()
}
