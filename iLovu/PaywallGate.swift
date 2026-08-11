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
// All state is keyed by a SCOPE id, persisted in UserDefaults with the same
// lightweight approach as MissionStore / MemoryStore / the celebrated-match set.
// The scope is the coupleId when paired (one subscription unlocks both partners)
// and "solo.<uid>" when not — see CoupleService.paywallScopeId.
//
// WHY SOLO SCOPING EXISTS (added 1.0.8, 2026-08-11): the gate used to engage only
// once a couple existed, so an unpaired user could NEVER see the wall at any
// duration. With ~96% of users unpaired, `paywall_shown` had fired ZERO times in
// the app's lifetime and monetization was structurally unreachable rather than
// underperforming. Condition C below is what makes it reachable.
//
// `isSubscribed` is pushed in from MainTabView (RevenueCat entitlement OR the
// shared couple-doc flag); once true the wall stops presenting.

import Foundation

@Observable
final class PaywallGate {

    // MARK: - Trigger thresholds
    private let matchThreshold = 2      // condition A: 2nd match reached
    private let memoryThreshold = 1     // condition A: 1st memory saved
    private let backstopDays = 14       // condition B: 14-day backstop
    private let missionThreshold = 2    // condition C: 2nd mission planned (works solo)

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

    // MARK: - Swipe cap (second trigger)

    /// Daily swipe allowance before the wall presents. **Remotely tunable** — see
    /// MainTabView.loadPaywallConfig, which overwrites this from
    /// `config/paywall.soloSwipeCap` at launch.
    ///
    /// WHY REMOTE: the right number is genuinely unknown. Solo swipes were never
    /// instrumented before 1.0.8, and the "25 and 21 in one session" figure in
    /// CLAUDE.md came from a single PAIRED couple — not the ~96% who are solo.
    /// Near You is also the ONLY surface solo users reach, so a cap set too low
    /// walls the single activation surface mid-first-session. Shipping it tunable
    /// means tightening 20 → 15 → 10 in minutes instead of an App Store release.
    /// `<= 0` disables the cap entirely (a remote kill switch).
    var swipeCap: Int = 20

    private func swipeCountKey(_ c: String) -> String { "paywallSwipeCount.\(c)" }
    private func swipeDayKey(_ c: String)   -> String { "paywallSwipeDay.\(c)" }

    /// Records one swipe for this scope and reports whether the wall should
    /// present *at this swipe*. Resets at local midnight. Call BEFORE consuming
    /// the card so hitting the wall never costs the user a venue.
    func registerSwipeAndShouldPresent(scopeId: String) -> Bool {
        guard !isSubscribed, swipeCap > 0 else { return false }

        let today = Self.dayStamp()
        if defaults.string(forKey: swipeDayKey(scopeId)) != today {
            defaults.set(today, forKey: swipeDayKey(scopeId))
            defaults.set(0, forKey: swipeCountKey(scopeId))
        }

        let used = defaults.integer(forKey: swipeCountKey(scopeId))
        guard used < swipeCap else { return true }   // already spent — wall, don't count
        defaults.set(used + 1, forKey: swipeCountKey(scopeId))
        return false
    }

    /// Local-day stamp; the cap is a per-day allowance, not a lifetime one.
    private static func dayStamp(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    // MARK: - Per-scope keys
    // The key STRINGS are deliberately unchanged from the per-couple era so
    // existing couples keep their armed latch and backstop stamp across upgrade.
    private func armedKey(_ c: String)        -> String { "paywallArmed.\(c)" }
    private func shownKey(_ c: String)        -> String { "paywallShown.\(c)" }
    private func firstSeenKey(_ c: String)    -> String { "pairingDate.\(c)" }
    private func matchCountKey(_ c: String)   -> String { "paywallMatchCount.\(c)" }
    private func memoryCountKey(_ c: String)  -> String { "paywallMemoryCount.\(c)" }
    private func missionCountKey(_ c: String) -> String { "paywallMissionCount.\(c)" }

    // MARK: - Inputs (call as state changes; each re-evaluates the gate)

    /// Stamps the pairing date used by the 14-day backstop. Prefers the
    /// authoritative server `createdAt` when it's resolved (it's nil locally
    /// right after redeem — see CoupleService); otherwise falls back to the
    /// first moment this device saw the couple, set once.
    func noteScopeActive(scopeId: String, createdAt: Date? = nil) {
        let key = firstSeenKey(scopeId)
        if let createdAt {
            defaults.set(createdAt.timeIntervalSince1970, forKey: key)
        } else if defaults.object(forKey: key) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: key)
        }
        evaluate(scopeId: scopeId)
    }

    /// The couple's match count (date + event). Source is MainTabView's
    /// per-couple `celebrated` set, which converges to the full match count.
    /// Paired-only by nature — a solo user never reaches a mutual match.
    func recordMatchCount(_ count: Int, scopeId: String) {
        defaults.set(count, forKey: matchCountKey(scopeId))
        evaluate(scopeId: scopeId)
    }

    /// The couple's saved-memory count (MemoryStore.memories.count today).
    func recordMemoryCount(_ count: Int, scopeId: String) {
        defaults.set(count, forKey: memoryCountKey(scopeId))
        evaluate(scopeId: scopeId)
    }

    /// Missions planned in this scope (MissionStore.missions.count). This is the
    /// SOLO-reachable input: MissionStore persists locally and `remoteUpsert` is
    /// nil when unpaired, so an unpaired user genuinely plans dates — that is the
    /// value they have received, and condition C arms on it.
    func recordMissionCount(_ count: Int, scopeId: String) {
        defaults.set(count, forKey: missionCountKey(scopeId))
        evaluate(scopeId: scopeId)
    }

    // MARK: - Presentation decision

    /// True when the wall should present at the calm mission-start entry point.
    /// Subscribed → never. Otherwise the couple must be armed; in hard mode it
    /// then presents EVERY time (show-once latch ignored), in soft mode only
    /// until it has been shown once.
    func shouldPresentAtMissionStart(scopeId: String) -> Bool {
        guard !isSubscribed else { return false }
        guard defaults.bool(forKey: armedKey(scopeId)) else { return false }
        if hardMode { return true }                          // persistent
        return !defaults.bool(forKey: shownKey(scopeId))     // soft: show once
    }

    /// Records that the wall has been presented — show-once, no nagging.
    func markShown(scopeId: String) {
        defaults.set(true, forKey: shownKey(scopeId))
    }

    // MARK: - Evaluation (latches `armed` true; never un-arms)

    private func evaluate(scopeId: String) {
        guard !defaults.bool(forKey: armedKey(scopeId)) else { return }

        let matches  = defaults.integer(forKey: matchCountKey(scopeId))
        let memories = defaults.integer(forKey: memoryCountKey(scopeId))
        let missions = defaults.integer(forKey: missionCountKey(scopeId))
        let conditionA = matches >= matchThreshold && memories >= memoryThreshold
        let conditionB = backstopElapsed(scopeId: scopeId)
        let conditionC = missions >= missionThreshold

        if conditionA || conditionB || conditionC {
            defaults.set(true, forKey: armedKey(scopeId))
        }
    }

    private func backstopElapsed(scopeId: String) -> Bool {
        let raw = defaults.double(forKey: firstSeenKey(scopeId))
        guard raw > 0 else { return false }
        let firstSeen = Date(timeIntervalSince1970: raw)
        let days = Calendar.current.dateComponents([.day], from: firstSeen, to: Date()).day ?? 0
        return days >= backstopDays
    }
}
