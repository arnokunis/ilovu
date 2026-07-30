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

    // A positive, non-error notice (e.g. "password reset email sent"), shown in a
    // friendly colour distinct from errorMessage. nil means nothing to show.
    var noticeMessage: String?

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

    // MARK: - Public email sign-up / sign-in
    //
    // Apple is offered first (privacy-forward + Guideline 4.8-friendly), but a real
    // tester feared "Sign in with Apple" would charge her — a likely driver of the
    // big drop at the sign-in screen. Email is the low-friction alternative. Both
    // flow through the SAME AuthState listener → ContentView routing as Apple, so
    // nothing downstream changes. Firebase's Email/Password provider must be enabled
    // in the console (it already is — the reviewer login below uses it).

    /// Creates a brand-new email/password account. A NEW user then routes into
    /// onboarding normally (we don't force-skip it, unlike the reviewer path).
    func createAccount(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validate(email: email, password: password, requireStrong: true) else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            errorMessage = nil; noticeMessage = nil
            print("✅ Email account created — uid: \(result.user.uid)")
            AppAnalytics.log("sign_in", ["method": "email"])
        } catch {
            show(friendlyAuthMessage(error))
        }
    }

    /// Signs in to an existing email/password account (public flow — does NOT
    /// force-skip onboarding, unlike the reviewer `signIn` below).
    func signInEmail(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validate(email: email, password: password, requireStrong: false) else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil; noticeMessage = nil
            print("✅ Email sign-in — uid: \(result.user.uid)")
            AppAnalytics.log("sign_in", ["method": "email"])
        } catch {
            show(friendlyAuthMessage(error))
        }
    }

    /// Sends a Firebase password-reset email. Surfaces success via noticeMessage.
    func sendPasswordReset(email: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { show("Enter your email first."); return }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = nil
            noticeMessage = "Password reset email sent — check your inbox."
        } catch {
            show(friendlyAuthMessage(error))
        }
    }

    private func validate(email: String, password: String, requireStrong: Bool) -> Bool {
        guard !email.isEmpty else { show("Enter your email."); return false }
        guard email.contains("@"), email.contains(".") else { show("That doesn't look like a valid email."); return false }
        guard !password.isEmpty else { show("Enter a password."); return false }
        if requireStrong, password.count < 6 { show("Password must be at least 6 characters."); return false }
        return true
    }

    /// Maps Firebase Auth errors to friendly copy. Uses the STABLE public numeric
    /// error codes (FIRAuthErrorCode) so it's independent of the typed-enum API,
    /// which has changed shape across Firebase major versions.
    private func friendlyAuthMessage(_ error: Error) -> String {
        let ns = error as NSError
        switch ns.code {
        case 17007: return "That email already has an account — try signing in instead."
        case 17008: return "That doesn't look like a valid email."
        case 17026: return "Password must be at least 6 characters."
        case 17009, 17004: return "Wrong email or password. Try again."
        case 17011: return "No account with that email — create one above."
        case 17020: return "No connection. Please try again."
        case 17999: return "Something went wrong. Please try again."
        default:    return "Something went wrong. Please try again."
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
