// PaywallGate.swift
// Decides WHEN the soft paywall (PaywallView) should appear — never the
// purchase itself. Two trigger conditions, whichever comes first:
//
//   A) the couple has reached its 2nd match AND saved its 1st memory, or
//   B) 14 days have elapsed since pairing/first use (a calm backstop).
//
// Brand rule baked into the mechanism: the wall NEVER interrupts a celebration.
// When a condition becomes true it only *arms* the gate (latched, persisted);
// the wall is then presented at the next CALM entry point — opening a mission
// from the Home dashboard — by HomeView checking shouldPresentAtMissionStart().
//
// All state is per-couple (one subscription unlocks both partners), persisted
// in UserDefaults with the same lightweight approach as MissionStore /
// MemoryStore / the celebrated-match set. The gate engages only once a couple
// exists; unpaired/solo use never arms it.
//
// ENTITLEMENT PLACEHOLDER: `isSubscribed` is hardcoded false. RevenueCat's
// couple-level entitlement (read from couples/{id}.entitlement) plugs in here
// in a later step — once it's true the wall stops presenting.

import Foundation

@Observable
final class PaywallGate {

    // MARK: - Trigger thresholds
    private let matchThreshold = 2      // condition A: 2nd match reached
    private let memoryThreshold = 1     // condition A: 1st memory saved
    private let backstopDays = 14       // condition B: 14-day backstop

    // MARK: - Entitlement (PLACEHOLDER)
    /// Whether either partner is subscribed. While false the wall can arm and
    /// show. TODO: wire to RevenueCat couple-level entitlement (couples/{id}
    /// .entitlement); set true once subscribed so the wall stops presenting.
    var isSubscribed: Bool = false

    // MARK: - Hard mode (single reversible flag)
    /// When true, the soft show-once wall becomes a persistent HARD wall:
    /// once armed (and not subscribed) it presents on EVERY gated action,
    /// ignoring the show-once latch, and the gated action is BLOCKED unless the
    /// couple subscribes (HomeView refuses to open the mission on dismiss).
    /// Flip to `false` to restore the original soft / dismiss-through /
    /// show-once behavior — that single change reverts everything.
    /// Arming (matchCount≥2 + memory, OR 14-day backstop) is unaffected either way.
    var hardMode: Bool = true

    private let defaults = UserDefaults.standard

    // MARK: - Per-couple keys
    private func armedKey(_ c: String)       -> String { "paywallArmed.\(c)" }
    private func shownKey(_ c: String)       -> String { "paywallShown.\(c)" }
    private func pairingDateKey(_ c: String) -> String { "pairingDate.\(c)" }
    private func matchCountKey(_ c: String)  -> String { "paywallMatchCount.\(c)" }
    private func memoryCountKey(_ c: String) -> String { "paywallMemoryCount.\(c)" }

    // MARK: - Inputs (call as state changes; each re-evaluates the gate)

    /// Stamps the pairing date used by the 14-day backstop. Prefers the
    /// authoritative server `createdAt` when it's resolved (it's nil locally
    /// right after redeem — see CoupleService); otherwise falls back to the
    /// first moment this device saw the couple, set once.
    func noteCoupleActive(coupleId: String, createdAt: Date? = nil) {
        let key = pairingDateKey(coupleId)
        if let createdAt {
            defaults.set(createdAt.timeIntervalSince1970, forKey: key)
        } else if defaults.object(forKey: key) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: key)
        }
        evaluate(coupleId: coupleId)
    }

    /// The couple's match count (date + event). Source is MainTabView's
    /// per-couple `celebrated` set, which converges to the full match count.
    func recordMatchCount(_ count: Int, coupleId: String) {
        defaults.set(count, forKey: matchCountKey(coupleId))
        evaluate(coupleId: coupleId)
    }

    /// The couple's saved-memory count (MemoryStore.memories.count today).
    func recordMemoryCount(_ count: Int, coupleId: String) {
        defaults.set(count, forKey: memoryCountKey(coupleId))
        evaluate(coupleId: coupleId)
    }

    // MARK: - Presentation decision

    /// True when the wall should present at the calm mission-start entry point.
    /// Subscribed → never. Otherwise the couple must be armed; in hard mode it
    /// then presents EVERY time (show-once latch ignored), in soft mode only
    /// until it has been shown once.
    func shouldPresentAtMissionStart(coupleId: String) -> Bool {
        guard !isSubscribed else { return false }
        guard defaults.bool(forKey: armedKey(coupleId)) else { return false }
        if hardMode { return true }                          // persistent
        return !defaults.bool(forKey: shownKey(coupleId))    // soft: show once
    }

    /// Records that the wall has been presented — show-once, no nagging.
    func markShown(coupleId: String) {
        defaults.set(true, forKey: shownKey(coupleId))
    }

    // MARK: - Evaluation (latches `armed` true; never un-arms)

    private func evaluate(coupleId: String) {
        guard !defaults.bool(forKey: armedKey(coupleId)) else { return }

        let matches  = defaults.integer(forKey: matchCountKey(coupleId))
        let memories = defaults.integer(forKey: memoryCountKey(coupleId))
        let conditionA = matches >= matchThreshold && memories >= memoryThreshold
        let conditionB = backstopElapsed(coupleId: coupleId)

        if conditionA || conditionB {
            defaults.set(true, forKey: armedKey(coupleId))
        }
    }

    private func backstopElapsed(coupleId: String) -> Bool {
        let raw = defaults.double(forKey: pairingDateKey(coupleId))
        guard raw > 0 else { return false }
        let paired = Date(timeIntervalSince1970: raw)
        let days = Calendar.current.dateComponents([.day], from: paired, to: Date()).day ?? 0
        return days >= backstopDays
    }
}
