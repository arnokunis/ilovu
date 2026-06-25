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

        // Ask for permission, then register with APNs on success. Requesting at
        // launch is the SIMPLE path to get a token + Stage 4 working. PRE-LAUNCH
        // the prompt should move to a warm, contextual moment (anti-pressure
        // brand) — e.g. right after a first match — NOT blasted at cold launch.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error {
                print("⚠️ Notification authorization error: \(error.localizedDescription)")
                return
            }
            guard granted else {
                print("ℹ️ Notification permission denied — no pushes will be delivered.")
                return
            }
            // registerForRemoteNotifications must be called on the main thread.
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
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
    // is the push address. Logged prominently so Stage 4 can copy it; Stage 5
    // will persist it to the couple doc instead of just printing.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("📲 FCM registration token:\n\(fcmToken)")
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
