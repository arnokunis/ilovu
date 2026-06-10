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

    // Connect to Firebase at launch (reads GoogleService-Info.plist).
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(missionStore)
                .environment(memoryStore)
        }
    }
}
