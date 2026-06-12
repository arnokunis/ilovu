//
//  iLovuApp.swift
//  iLovu
//
//  Created by Arnoldas on 20/05/2026.
//

import SwiftUI
import FirebaseCore

@main
struct iLovuApp: App {

    // One MissionStore + one MemoryStore owned at the app root.
    // @State preserves them across SwiftUI re-renders of the App body.
    // Both injected into the environment so every view in the app
    // reads and writes the same shared lists.
    @State private var missionStore = MissionStore()
    @State private var memoryStore  = MemoryStore()

    // Firestore-backed invite/couple system. Constructing it touches no Firebase
    // (its Firestore handle is resolved lazily per call), so a plain default is
    // safe here even though it runs before configure() in init.
    @State private var coupleService = CoupleService()

    // Firestore-backed two-player matching. Like CoupleService, constructing it
    // touches no Firebase (its handle is resolved lazily), so a plain default is
    // safe at the app root. Injected so the swipe views can record likes and
    // MainTabView can host the app-level matches listener.
    @State private var matchService = MatchService()

    // Tracks Firebase auth state so ContentView can route signed-in vs
    // signed-out. Built in init() — see below for why it isn't a default.
    @State private var authState: AuthState

    // Connect to Firebase at launch (reads GoogleService-Info.plist), then
    // create AuthState. Order matters: AuthState observes Auth.auth(), which
    // requires FirebaseApp.configure() to have already run.
    init() {
        FirebaseApp.configure()
        _authState = State(initialValue: AuthState())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(missionStore)
                .environment(memoryStore)
                .environment(authState)
                .environment(coupleService)
                .environment(matchService)
        }
    }
}
