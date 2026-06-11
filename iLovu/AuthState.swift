// AuthState.swift
// The single source of truth for "is someone signed in?" across the app.
//
// It wraps Firebase Auth's state-change listener in an @Observable object so
// SwiftUI can route on it directly. The listener fires once shortly after
// launch with the *restored* session (Firebase persists sign-in across app
// launches), and again on every sign-in / sign-out — so routing stays correct
// without us polling anything.
//
// Owned once at the app root (iLovuApp) and injected into the environment.

import Foundation
import FirebaseCore
import FirebaseAuth

@MainActor
@Observable
final class AuthState {

    // The three states the UI routes on. `loading` is the brief window between
    // launch and Firebase reporting the restored session — we show a splash
    // then, so a returning user never flashes past the sign-in screen.
    enum Status: Equatable {
        case loading
        case signedOut
        case signedIn(uid: String)
    }

    private(set) var status: Status = .loading

    // The full Firebase user, kept alongside `status` for screens that need
    // more than the uid (email, display name, etc.).
    private(set) var user: User?

    // @ObservationIgnored: this is plumbing, not observable UI state.
    // nonisolated(unsafe): lets deinit (a nonisolated context) read it to
    // remove the listener. Safe — written once in init, read once in deinit.
    @ObservationIgnored
    nonisolated(unsafe) private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Guard against Firebase not being configured — e.g. SwiftUI previews,
        // which never call FirebaseApp.configure(). Without this, Auth.auth()
        // would crash the preview canvas.
        guard FirebaseApp.app() != nil else {
            status = .signedOut
            return
        }

        // Fires immediately with the restored session, then on every change.
        // Firebase calls this on the main thread, matching our @MainActor.
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.status = user.map { .signedIn(uid: $0.uid) } ?? .signedOut
        }
    }

    deinit {
        if let listenerHandle {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
    }

    /// Signs the current user out. The state listener flips `status` to
    /// `.signedOut`, which re-routes the app back to SignInView.
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("⚠️ Sign out failed: \(error.localizedDescription)")
        }
    }
}
