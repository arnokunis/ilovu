//
//  iLovuApp.swift
//  iLovu
//
//  Created by Arnoldas on 20/05/2026.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import RevenueCat

// App Check provider factory. Attests that Firebase traffic comes from a genuine,
// unmodified build of THIS app (device-level, via Apple's App Attest) — the
// device-attestation half of the pre-launch hardening. On real devices we use
// AppAttestProvider; DEBUG builds (simulator / Xcode) can't App-Attest, so they
// use the debug provider, which prints a debug token to the console on first run
// that must be registered in the Firebase console (App Check → Manage debug tokens).
//
// IMPORTANT: registering the factory does NOT block anything on its own. App Check
// starts in MONITORING mode — the console records verified vs unverified traffic
// but nothing is rejected. Enforcement is flipped ON in the console only after all
// client call sites are stable (the #4b step of the hardening sprint).
final class ILovuAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}

@main
struct iLovuApp: App {

    // UIKit application delegate, bridged in purely for push-notification
    // plumbing (APNs registration + FCM token) that SwiftUI's App protocol
    // can't express. See AppDelegate.swift. Its didFinishLaunching runs AFTER
    // this struct's init() below, so FirebaseApp.configure() has already run by
    // the time the delegate touches Messaging.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // One MissionStore + one MemoryStore owned at the app root.
    // @State preserves them across SwiftUI re-renders of the App body.
    // Both injected into the environment so every view in the app
    // reads and writes the same shared lists.
    @State private var missionStore = MissionStore()
    @State private var memoryStore  = MemoryStore()

    // Shared date wishlist (custom date ideas). Same local-mirror + remote-sink
    // shape as the stores above; synced to the partner via BucketListService.
    @State private var bucketListStore = BucketListStore()

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

    // Firestore sync for the shared date wishlist (couples/{id}/bucketList).
    // Same lazy-Firebase, safe-to-default shape as the services above.
    @State private var bucketListService = BucketListService()

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

    // "Would You Rather" game sync (couples/{id}/games). Self-contained card owns
    // its own listener, same as DailyQuestionCard — this just needs to exist in the
    // environment. Same lazy-Firebase, safe-to-default shape as the services above.
    @State private var wouldYouRatherService = WouldYouRatherService()

    // Tracks Firebase auth state so ContentView can route signed-in vs
    // signed-out. Built in init() — see below for why it isn't a default.
    @State private var authState: AuthState

    // Connect to Firebase at launch (reads GoogleService-Info.plist), then
    // create AuthState. Order matters: AuthState observes Auth.auth(), which
    // requires FirebaseApp.configure() to have already run.
    init() {
        // App Check MUST be registered before FirebaseApp.configure() so the
        // very first Firebase requests carry an attestation token. Monitoring
        // mode only (see ILovuAppCheckProviderFactory) — this changes no runtime
        // behavior until enforcement is enabled server-side.
        AppCheck.setAppCheckProviderFactory(ILovuAppCheckProviderFactory())

        FirebaseApp.configure()

        // RevenueCat, configured at launch alongside Firebase. The public SDK
        // key lives in Secrets.swift (gitignored) — paste it there. .debug log
        // level for now so configuration + entitlement fetches are visible in
        // the console while integrating; dial this back before launch.
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)

        _authState = State(initialValue: AuthState())
    }

    // A cheap signature of everything the widgets render. When it changes, the
    // .task(id:) below rewrites the shared snapshot. Kept scalar (no image bytes)
    // so recomputing it on every render is free; the newest-memory id+version
    // catches a photo replace, and the earliest scheduled date catches replanning.
    private var widgetDigest: String {
        let daysValue: Int? = coupleService.couple?.daysTogether()
        let days: String = daysValue.map { String($0) } ?? "-"

        let upcoming: [Mission] = missionStore.missions.filter { $0.status == .upcoming }
        let earliest: TimeInterval? = upcoming
            .compactMap { $0.scheduledDate?.timeIntervalSince1970 }
            .min()
        let mission: String = earliest.map { String($0) } ?? "u\(missionStore.missions.count)"

        let newest: Memory? = memoryStore.memories.max { $0.dateCompleted < $1.dateCompleted }
        let memory: String = newest.map { "\($0.id)-\($0.photoVersion)" } ?? "none"

        let partner: String = coupleService.partnerDisplayName ?? ""
        return "\(days)|\(mission)|\(memory)|\(partner)"
    }

    /// Tie RevenueCat's identity to the Firebase uid, so the subscription webhook
    /// (revenueCatWebhook Cloud Function) receives our uid as `app_user_id` and can
    /// resolve the couple to grant/revoke premium authoritatively — even when the
    /// payer never reopens the app. logIn aliases any anonymous pre-sign-in purchase
    /// onto the uid; logOut resets to anonymous on sign-out.
    private func syncRevenueCatIdentity(_ status: AuthState.Status) {
        switch status {
        case .signedIn(let uid):
            Task { _ = try? await Purchases.shared.logIn(uid) }
        case .signedOut:
            Task { _ = try? await Purchases.shared.logOut() }
        case .loading:
            break
        }
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
                .environment(wouldYouRatherService)
                .environment(bucketListStore)
                .environment(bucketListService)
                // Keep the home-screen widgets fed. A cheap digest of the couple
                // days / next mission / latest memory drives this: .task(id:) reruns
                // the write whenever that digest changes (and once on first appear).
                // No-ops until the App Group + widget extension exist (see
                // WidgetDataWriter / WidgetShared), so it's safe to ship now.
                .task(id: widgetDigest) {
                    await WidgetDataWriter().refresh(
                        couple: coupleService.couple,
                        partnerName: coupleService.partnerDisplayName,
                        missions: missionStore.missions,
                        memories: memoryStore.memories
                    )
                }
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
                    // Set the RevenueCat identity for whoever's already signed in at
                    // launch; the .onChange below keeps it in step on later sign-in/out.
                    syncRevenueCatIdentity(authState.status)
                    Task { await subscriptionService.loadOfferings() }

                    // Stage 5 push: AppDelegate publishes each FCM token onto
                    // PushTokenBridge; forward it to CoupleService, which writes it
                    // to the shared couple doc so the nudge function can reach the
                    // partner. Replay any token that arrived before this wiring ran.
                    PushTokenBridge.onToken = { [coupleService] token in
                        Task { await coupleService.persistFCMToken(token) }
                    }
                    if let token = PushTokenBridge.latest {
                        Task { await coupleService.persistFCMToken(token) }
                    }

                    missionStore.remoteUpsert = { [coupleService, missionService] mission in
                        guard let coupleId = coupleService.coupleId else { return }
                        Task { await missionService.saveMission(coupleId: coupleId, mission: mission) }
                    }
                    missionStore.remoteDelete = { [coupleService, missionService] cardId in
                        guard let coupleId = coupleService.coupleId else { return }
                        Task { await missionService.deleteMission(coupleId: coupleId, cardId: cardId) }
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
                    // Bucket-list sync sinks: mirror an add/toggle up, and a delete.
                    // No-op when unpaired (coupleId nil); items stay local until
                    // pairing, then resyncAll() (in MainTabView) migrates them.
                    bucketListStore.remoteUpsert = { [coupleService, bucketListService] item in
                        guard let coupleId = coupleService.coupleId else { return }
                        Task { await bucketListService.saveItem(coupleId: coupleId, item: item) }
                    }
                    bucketListStore.remoteDelete = { [coupleService, bucketListService] id in
                        guard let coupleId = coupleService.coupleId else { return }
                        Task { await bucketListService.deleteItem(coupleId: coupleId, itemId: id.uuidString) }
                    }
                }
                // Keep RevenueCat's app_user_id == Firebase uid across sign-in/out.
                .onChange(of: authState.status) { _, status in
                    syncRevenueCatIdentity(status)
                }
        }
    }
}
