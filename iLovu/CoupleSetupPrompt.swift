// CoupleSetupPrompt.swift
// Decides WHEN to show the optional "set up your story" card after a couple
// connects — never a gate, always dismissible. Mirrors PaywallGate's per-couple
// UserDefaults approach.
//
// Lifecycle (gentle, exactly ONE re-surface, then quiet):
//   • first time paired with no anniversary -> show
//   • "Maybe later" -> hide, arm a single re-surface
//   • re-surface once, on the first memory saved since dismissal OR a ~7-day
//     backstop, whichever comes first
//   • dismissed again -> suppressed for good
//   • anniversary ever set -> never shows again (the card's whole reason is gone)

import Foundation

@Observable
final class CoupleSetupPrompt {

    private let defaults = UserDefaults.standard
    private let backstopDays = 7

    private func dismissCountKey(_ c: String)   -> String { "coupleSetupDismissCount.\(c)" }
    private func dismissedAtKey(_ c: String)    -> String { "coupleSetupDismissedAt.\(c)" }
    private func memoryAtDismissKey(_ c: String) -> String { "coupleSetupMemoryAtDismiss.\(c)" }
    private func suppressedKey(_ c: String)     -> String { "coupleSetupSuppressed.\(c)" }

    /// Whether to show the card now. Gated on: paired (caller passes a coupleId),
    /// no start ("dating") date yet, not suppressed, and either never dismissed or
    /// eligible for the single gentle re-surface.
    func shouldShow(coupleId: String, hasStartDate: Bool, memoryCount: Int) -> Bool {
        guard !hasStartDate else { return false }
        guard !defaults.bool(forKey: suppressedKey(coupleId)) else { return false }

        let count = defaults.integer(forKey: dismissCountKey(coupleId))
        if count == 0 { return true }   // never dismissed → first invitation

        // Dismissed once → re-surface on first memory since dismissal, or backstop.
        if memoryCount > defaults.integer(forKey: memoryAtDismissKey(coupleId)) { return true }
        let dismissedAt = defaults.double(forKey: dismissedAtKey(coupleId))
        if dismissedAt > 0 {
            let days = Calendar.current.dateComponents(
                [.day], from: Date(timeIntervalSince1970: dismissedAt), to: Date()
            ).day ?? 0
            if days >= backstopDays { return true }
        }
        return false
    }

    /// Records a "Maybe later". First dismiss arms the single re-surface; a second
    /// dismiss (after re-surfacing) suppresses the card for good.
    func dismiss(coupleId: String, memoryCount: Int) {
        let count = defaults.integer(forKey: dismissCountKey(coupleId))
        if count == 0 {
            defaults.set(1, forKey: dismissCountKey(coupleId))
            defaults.set(Date().timeIntervalSince1970, forKey: dismissedAtKey(coupleId))
            defaults.set(memoryCount, forKey: memoryAtDismissKey(coupleId))
        } else {
            defaults.set(true, forKey: suppressedKey(coupleId))
        }
    }
}
