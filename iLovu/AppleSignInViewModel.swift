// AppleSignInViewModel.swift
// Drives the "Sign in with Apple" → Firebase Auth handshake.
//
// The flow, end to end:
//   1. Before Apple shows its sheet, we generate a one-time random `nonce`
//      and hand Apple the SHA256 *hash* of it (prepareRequest).
//   2. Apple signs the user in and returns an identity token that embeds
//      the hashed nonce.
//   3. We hand Firebase the identity token *plus the original raw nonce*
//      (handleCompletion → exchangeAndSignIn). Firebase re-hashes the raw
//      nonce and checks it matches the one baked into the token — that's
//      what stops a stolen token from being replayed.
//
// This view model only signs the user in and confirms the Firebase user.
// It deliberately does NOT decide what the app shows next — that's owned by
// ContentView, which routes off AuthState the moment sign-in flips it.

import Foundation
import CryptoKit
import AuthenticationServices
import FirebaseAuth

@MainActor
@Observable
final class AppleSignInViewModel {

    // A friendly, non-technical message shown under the button when something
    // goes wrong. nil means "no error to show". User cancellation leaves this
    // nil on purpose — backing out isn't a failure worth nagging about.
    var errorMessage: String?

    // True while Firebase is exchanging the credential, so the UI can show a
    // spinner and disable interaction.
    var isSigningIn = false

    // The raw nonce for the in-flight request. We send Apple its SHA256 hash,
    // but Firebase needs this original value to verify the returned token, so
    // we hold onto it between prepareRequest and the completion callback.
    private var currentNonce: String?

    // MARK: - Step 1: configure the Apple request

    /// Called from `SignInWithAppleButton`'s `onRequest`. Generates a fresh
    /// nonce, stores the raw value, and gives Apple the hashed value + the
    /// scopes we want back.
    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    // MARK: - Step 2: handle Apple's answer

    /// Called from `SignInWithAppleButton`'s `onCompletion`.
    func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            handle(error)

        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                show("We couldn't read your Apple credentials. Please try again.")
                return
            }
            Task { await exchangeAndSignIn(appleIDCredential) }
        }
    }

    // MARK: - Step 3: exchange for a Firebase credential and sign in

    private func exchangeAndSignIn(_ appleIDCredential: ASAuthorizationAppleIDCredential) async {
        guard let nonce = currentNonce else {
            // Should never happen — prepareRequest always runs first — but we
            // refuse to proceed without the raw nonce rather than crash.
            show("Something went wrong starting sign-in. Please try again.")
            return
        }
        guard let tokenData = appleIDCredential.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8) else {
            show("We couldn't read your Apple ID token. Please try again.")
            return
        }

        // Build the Firebase credential from Apple's token + our raw nonce.
        // fullName is only non-nil on the very first sign-in for this Apple ID;
        // passing it lets Firebase populate the user's display name.
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            let user = result.user
            errorMessage = nil
            // AuthState's listener fires on this same sign-in and routes the app
            // out of SignInView; this view model just completes the credential
            // exchange. Console line kept as a build-testing breadcrumb.
            print("✅ Firebase sign-in success — uid: \(user.uid), email: \(user.email ?? "none"), name: \(user.displayName ?? "none")")
            AppAnalytics.log("sign_in", ["method": "apple"])
        } catch {
            print("⚠️ Firebase sign-in error: \(error.localizedDescription)")
            show("We couldn't sign you in. Please try again.")
        }
    }

    // MARK: - Reviewer/demo login (email + password)

    /// App Review can't use Sign in with Apple, so a demo account signs in with a
    /// plain Firebase email+password. It flows through the SAME path as Apple —
    /// AuthState's listener fires, ContentView routes, MainTabView resolves the
    /// couple — so a demo account that's already paired lands straight in the
    /// two-partner experience. Credentials are handed to App Review out-of-band
    /// (App Review notes); they are NEVER hardcoded here, and the app has no
    /// sign-up path (never calls createUser), so only accounts created
    /// server-side (i.e. the single demo account) can ever sign in this way.
    /// Reached only via the hidden long-press reveal in SignInView.
    func signIn(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            show("Enter an email and password.")
            return
        }

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil
            // Skip first-run onboarding so the reviewer lands directly in
            // MainTabView, where currentCouple() resolves the pre-paired demo
            // couple. Matches the @AppStorage key ContentView routes on.
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            print("✅ Firebase email sign-in success — uid: \(result.user.uid)")
        } catch {
            print("⚠️ Firebase email sign-in error: \(error.localizedDescription)")
            show("We couldn't sign you in. Check the email and password and try again.")
        }
    }

    // MARK: - Error handling

    private func handle(_ error: Error) {
        // ASAuthorizationError.canceled means the user dismissed Apple's sheet.
        // That's a normal choice, not an error — stay quiet.
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            errorMessage = nil
            return
        }
        print("⚠️ Apple authorization error: \(error.localizedDescription)")
        show("Sign in with Apple didn't work. Please try again.")
    }

    private func show(_ message: String) {
        errorMessage = message
    }

    // MARK: - Nonce helpers

    /// A cryptographically-random string used once per sign-in attempt.
    /// SecRandomCopyBytes is the source of randomness; on the (effectively
    /// impossible) chance it fails, we fall back to UUIDs rather than crash.
    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randomByte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)
            guard status == errSecSuccess else {
                // Fallback: still random enough to be safe, and never crashes.
                return UUID().uuidString + UUID().uuidString
            }
            if randomByte < charset.count {
                result.append(charset[Int(randomByte)])
                remaining -= 1
            }
        }
        return result
    }

    /// SHA256 hash of the nonce, hex-encoded — the exact form Apple expects in
    /// `request.nonce` and that Firebase requires for Apple sign-in.
    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
