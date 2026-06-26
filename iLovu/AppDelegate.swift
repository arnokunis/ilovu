// AppDelegate.swift
// The UIKit application delegate, bridged into our SwiftUI lifecycle via
// @UIApplicationDelegateAdaptor (see iLovuApp). SwiftUI's App protocol has no
// hook for the remote-notification callbacks APNs/FCM need, so we keep a thin
// delegate purely for push plumbing — everything else stays in SwiftUI.
//
// Stage 3 of the push roadmap ("FCM + device tokens"): register with APNs, hand
// the APNs token to Firebase Messaging, and surface the resulting FCM
// registration token. That token is what a push is addressed to:
//   • Stage 4 sends a test push to it (copy it from the Xcode console).
//   • Stage 5 (nudge logic) persists it to couples/{coupleId}.fcmTokens.{uid}
//     so a Cloud Function can reach the partner's device. Deferred until then —
//     persisting needs a couple to exist + a firestore.rules change, so we log
//     for now and wire storage when we build the nudge.
//
// ORDERING: FirebaseApp.configure() runs in iLovuApp.init(), which completes
// before this delegate's didFinishLaunchingWithOptions, so Firebase is already
// configured by the time we touch Messaging here. (The app already relies on
// that same init-first ordering: AuthState observes Auth.auth() from init().)

import UIKit
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // FCM hands us registration tokens; UNUserNotificationCenter hands us
        // foreground-presentation + tap callbacks. Wire both to this delegate.
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // We NO LONGER ask for permission at cold launch. iOS only ever offers the
        // permission prompt ONCE, so cold-asking a brand-new user (who has no idea
        // what the app is for yet) risks a permanent "no" — losing the channel. The
        // ask now fires at a warm, partner-framed moment: the user's first mutual
        // match (see MainTabView). But if they ALREADY granted on a past launch,
        // re-register with APNs so FCM keeps a fresh token across launches.
        Task { @MainActor in
            if await PushAuthorization.status() == .authorized {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        return true
    }

    // APNs issued a device token. Hand it to FCM so it can mint / refresh the
    // FCM registration token (delivered via the MessagingDelegate below).
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Common on Simulator (no APNs) — expected there; real devices should
        // succeed once the APNs key + capability are in place (Stage 2).
        print("⚠️ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - Firebase Messaging

extension AppDelegate: MessagingDelegate {

    // Fired whenever FCM issues or rotates the registration token. THIS string
    // is the push address. Logged for debugging; Stage 5 also hands it to
    // CoupleService (via PushTokenBridge below) so it lands on the couple doc and
    // the nudge Cloud Function can reach the partner's device.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("📲 FCM registration token:\n\(fcmToken)")
        // Hop to the main actor (this delegate callback isn't isolated) and
        // publish onto the bridge. iLovuApp forwards it to CoupleService.
        Task { @MainActor in PushTokenBridge.publish(fcmToken) }
    }
}

// MARK: - Push token bridge
//
// The UIKit AppDelegate can't read the SwiftUI environment where CoupleService
// lives, so the FCM token (delivered above) is published here; iLovuApp wires
// `onToken` at launch to forward each token to CoupleService, which writes it to
// couples/{id}.fcmTokens[uid]. `latest` covers the ordering where a token
// arrives BEFORE that forwarding closure is wired (we replay it on wire-up).
@MainActor
enum PushTokenBridge {
    private(set) static var latest: String?
    static var onToken: ((String) -> Void)?

    static func publish(_ token: String) {
        latest = token
        onToken?(token)
    }
}

// MARK: - Push authorization
//
// Centralizes the OS-level notification permission so the request lives in ONE
// place — the warm first-match moment (MainTabView) calls request(); cold launch
// only ever calls status(). Keeping it here (not in AppDelegate's instance) means
// any view can ask without reaching the delegate.
@MainActor
enum PushAuthorization {

    /// The current OS notification authorization status. `.notDetermined` means we
    /// still hold the one-shot prompt; `.authorized`/`.denied`/`.provisional` mean
    /// it's already been decided and re-asking shows no UI.
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Fires the ONE-SHOT iOS permission prompt and, on grant, registers with APNs
    /// so FCM can mint a token (delivered to AppDelegate → PushTokenBridge). No-ops
    /// into the current status if permission was already decided. Returns granted.
    @discardableResult
    static func request() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("ℹ️ Notification permission denied — no pushes will be delivered.")
            }
            return granted
        } catch {
            print("⚠️ Notification authorization error: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - User Notifications

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Show the notification even when the app is in the foreground — otherwise a
    // push that arrives while the user is in-app is silently dropped, which
    // would make Stage 4 testing look like a failure.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
