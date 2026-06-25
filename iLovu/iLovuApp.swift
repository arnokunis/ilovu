//
//  iLovuApp.swift
//  iLovu
//
//  Created by Arnoldas on 20/05/2026.
//

import SwiftUI
import FirebaseCore
import RevenueCat

@main
struct iLovuApp: App {

    // One MissionStore + one MemoryStore owned at the app root.
    // @State preserves them across SwiftUI re-renders of the App body.
    // Both injected into the environment so every view in the app
    // reads and writes the same shared lists.
    @State private var missionStore = MissionStore()
    @State private var memoryStore  = MemoryStore()

    // Local profile photo (name lives in @AppStorage and syncs via the couple
    // doc). Owned here so the Us tab and any avatar share one instance.
    @State private var profileStore = ProfileStore()

    // Firestore-backed invite/couple system. Constructing it touches no Firebase
    // (its Firestore handle is resolved lazily per call), so a plain default is
    // safe here even though it runs before configure() in init.
    @State private var coupleService = CoupleService()

    // Firestore-backed two-player matching. Like CoupleService, constructing it
    // touches no Firebase (its handle is resolved lazily), so a plain default is
    // safe at the app root. Injected so the swipe views can record likes and
    // MainTabView can host the app-level matches listener.
    @State private var matchService = MatchService()

    // Firestore-backed mission sync. Mirrors local MissionStore mutations to
    // couples/{id}/missions and feeds MainTabView's missions listener, so a
    // date/time edit on one phone reaches the partner. Same lazy-Firebase,
    // safe-to-default-construct shape as the services above.
    @State private var missionService = MissionService()

    // Firestore + Storage sync for the Memory Vault. Uploads proof-photo bytes
    // to couples/{id}/memories/{memId}.jpg and mirrors metadata to Firestore, so
    // both partners share one durable vault. Same lazy-Firebase, safe-to-default
    // shape as the services above.
    @State private var memoryService = MemoryService()

    // Decides WHEN the soft paywall appears (not the purchase). Couple-level,
    // UserDefaults-backed, no Firebase — safe to default-construct here. Read by
    // HomeView at the calm mission-start entry point; fed match/memory counts by
    // MainTabView + MissionDetailView.
    @State private var paywallGate = PaywallGate()

    // RevenueCat: this user's entitlement + the purchase/restore + offering loads.
    // Constructing it touches no RevenueCat (start()/loadOfferings run later in
    // .task, after Purchases.configure), so a plain default is safe at the root.
    @State private var subscriptionService = SubscriptionService()

    // Decides when to show the optional, dismissible "set up your story" card
    // after pairing. Per-couple, UserDefaults-backed, no Firebase — safe to
    // default-construct. Read by the Us tab.
    @State private var coupleSetupPrompt = CoupleSetupPrompt()

    // Firestore-backed sync for the shared Daily Question. Writes each partner's
    // answer to couples/{id}/dailyAnswers/{date} and feeds DailyQuestionCard's
    // today-doc listener (the "answer to unlock" reveal). Same lazy-Firebase,
    // safe-to-default shape as the services above.
    @State private var dailyQuestionService = DailyQuestionService()

    // Tracks Firebase auth state so ContentView can route signed-in vs
    // signed-out. Built in init() — see below for why it isn't a default.
    @State private var authState: AuthState

    // Connect to Firebase at launch (reads GoogleService-Info.plist), then
    // create AuthState. Order matters: AuthState observes Auth.auth(), which
    // requires FirebaseApp.configure() to have already run.
    init() {
        FirebaseApp.configure()

        // RevenueCat, configured at launch alongside Firebase. The public SDK
        // key lives in Secrets.swift (gitignored) — paste it there. .debug log
        // level for now so configuration + entitlement fetches are visible in
        // the console while integrating; dial this back before launch.
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)

        _authState = State(initialValue: AuthState())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(missionStore)
                .environment(memoryStore)
                .environment(profileStore)
                .environment(authState)
                .environment(coupleService)
                .environment(matchService)
                .environment(missionService)
                .environment(memoryService)
                .environment(paywallGate)
                .environment(subscriptionService)
                .environment(coupleSetupPrompt)
                .environment(dailyQuestionService)
                // Wire MissionStore's write-through sink once. Every local
                // add/update then mirrors to Firestore for the current couple;
                // when unpaired (coupleId nil) it's a no-op and missions stay
                // local. Reads coupleId live, so it starts syncing the moment
                // pairing completes — no relaunch needed.
                .task {
                    // RevenueCat: keep this user's entitlement live and mirror it
                    // onto the SHARED couple doc whenever it flips (the payer-only
                    // write that unlocks BOTH partners). Wired once at the root, so
                    // it works regardless of which screen is showing.
                    subscriptionService.onEntitlementChange = { [coupleService] active in
                        Task { await coupleService.syncPremiumEntitlement(active) }
                    }
                    subscriptionService.start()
                    Task { await subscriptionService.loadOfferings() }

                    missionStore.remoteUpsert = { [coupleService, missionService] mission in
                        guard let coupleId = coupleService.coupleId else { return }
                        Task { await missionService.saveMission(coupleId: coupleId, mission: mission) }
                    }
                    // Memory sync sink: upload bytes + metadata, then mark the
                    // local memory synced (records storagePath, drops inline
                    // bytes). No-op when unpaired — memories stay local until
                    // pairing, then resyncUnsynced() migrates them.
                    memoryStore.remoteUpsert = { [coupleService, memoryService, memoryStore] memory in
                        guard let coupleId = coupleService.coupleId else { return }
                        Task { @MainActor in
                            if let path = await memoryService.saveMemory(coupleId: coupleId, memory: memory) {
                                memoryStore.markSynced(id: memory.id, storagePath: path)
                            }
                        }
                    }
                }
        }
    }
}
