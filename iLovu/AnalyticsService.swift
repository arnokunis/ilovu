//
//  AnalyticsService.swift
//  iLovu
//
//  Thin wrapper over Firebase Analytics for the core funnel events. One
//  choke point so event names stay consistent and a future SDK swap (or a
//  kill switch) is a one-file change. Named AppAnalytics to avoid clashing
//  with FirebaseAnalytics' own `Analytics` class.
//
//  Canonical funnel (log these names, don't invent variants):
//    sign_in → onboarding_complete → reached_pairing_screen → invite_created
//    → invite_redeemed → card_liked → match_created → mission_created
//    → memory_completed → paywall_shown → paywall_dismissed
//    → purchase_success / restore_success
//
//  reached_pairing_screen: an unpaired user reached the invite/redeem UI
//  (PairingView). Splits the big "installed but never paired" leak into two
//  measurable steps — reached pairing vs. created an invite once there.
//
//  Growth loop (viral acquisition): memory_shared — logged when the user opens
//  the share sheet for a Memory's proof-photo card (MemoryDetailView). Measures
//  how often couples share, the top of the organic-growth funnel.
//
//  North-star: memory_completed (a real date happened). The live diagnostic
//  for the pairing funnel is invite_created → invite_redeemed conversion.
//

import FirebaseAnalytics

enum AppAnalytics {

    /// Logs a funnel event. Safe from any thread/actor — Firebase queues
    /// internally. Event names: ≤40 chars, snake_case (Firebase rules).
    static func log(_ event: String, _ parameters: [String: Any]? = nil) {
        Analytics.logEvent(event, parameters: parameters)
    }
}
