// SubscriptionService.swift
// The single source of truth for RevenueCat: this user's "premium" entitlement,
// the "default" offering's packages, and the purchase / restore flows. Owned once
// at the app root (iLovuApp) and injected via the environment, same as
// CoupleService / MissionService / the other services.
//
// COUPLE SHARING (brand rule: "one subscription unlocks BOTH partners"):
// `myEntitlementActive` is only THIS user's RevenueCat truth. The shared access
// rule lives in `premiumActive(couple:)` — premium = my own entitlement OR the
// couple doc's `isPremium` flag. When my entitlement flips, `onEntitlementChange`
// fires; iLovuApp wires that to CoupleService.syncPremiumEntitlement, which (for
// the PAYER only) mirrors the flag onto the shared couple doc so the partner
// reads premium straight off the couple doc — no purchase of their own.
//
// PRE-LAUNCH HARDENING: revocation is client-mirror only for v1 — if the payer's
// entitlement lapses while they never reopen the app, the couple-doc flag stays
// set (a couple keeps premium slightly too long; it never wrongly drops). The
// clean end-state is a RevenueCat webhook -> Cloud Function writing the couple
// doc authoritatively (grant AND revoke), which also closes the "a member could
// set isPremium=true without paying" hole. Same trajectory as the invite-
// redemption / venue-cache hardening notes.

import Foundation
import RevenueCat

/// The result of a purchase / restore attempt, surfaced to PaywallView so it can
/// show the right state without knowing anything about RevenueCat.
enum PurchaseOutcome {
    case success
    case cancelled          // user backed out of the system sheet — show nothing
    case failed(String)     // friendly, user-presentable message
}

/// Display strings for one plan, derived from a RevenueCat package's localized
/// price (so currency/locale are correct), fed into PaywallView's existing UI.
struct PlanDisplay {
    let priceText: String       // e.g. "$49.99/yr" (localized)
    let perMonthText: String?   // e.g. "just $4.17/mo" (localized), nil if uncomputable
}

@MainActor
@Observable
final class SubscriptionService {

    // Dashboard identifiers (entitlement / offering) live in RevenueCatConfig.

    // MARK: - Entitlement (this user only)

    /// Whether THIS user's own RevenueCat "premium" entitlement is active. The
    /// shared/couple rule is layered on in `premiumActive(couple:)` — don't gate
    /// UI on this alone or the non-paying partner loses access.
    private(set) var myEntitlementActive = false

    /// The product id of THIS user's active "premium" entitlement (e.g.
    /// `com.ilovu.app.annual`), or nil when they have no own active entitlement.
    /// Lets the settings status row label the plan (Annual/Monthly). Kept live off
    /// the same `apply(_:)` as the entitlement flag. Only the payer's own device
    /// can know this — the partner reads premium off the couple doc (no plan type).
    private(set) var myPlanProductID: String?

    /// Human-readable plan name for THIS user's active entitlement ("Annual" /
    /// "Monthly"), or nil if they have no own entitlement or it's an unrecognized
    /// product.
    var myPlanLabel: String? {
        switch myPlanProductID {
        case RevenueCatConfig.annualProductID:  return "Annual"
        case RevenueCatConfig.monthlyProductID: return "Monthly"
        default: return nil
        }
    }

    /// Fired when `myEntitlementActive` changes (purchase, renewal, expiry).
    /// iLovuApp wires this to CoupleService so the payer mirrors premium onto the
    /// shared couple doc. Set once at the app root.
    var onEntitlementChange: ((Bool) -> Void)?

    // MARK: - Offering / packages

    private(set) var annualPackage: Package?
    private(set) var monthlyPackage: Package?
    private(set) var isLoadingOfferings = false

    /// Effective premium for the whole couple: my own entitlement OR the shared
    /// couple-doc flag. This is the value the paywall gate reads.
    func premiumActive(couple: Couple?) -> Bool {
        myEntitlementActive || couple?.isPremium == true
    }

    // MARK: - Lifecycle

    /// Pulls the current entitlement once, then keeps `myEntitlementActive` live
    /// off RevenueCat's customerInfo stream (renewals/expirations included).
    /// Call once at the app root after Purchases.configure() has run.
    func start() {
        Task { [weak self] in
            guard let self else { return }
            if let info = try? await Purchases.shared.customerInfo() {
                self.apply(info)
            }
            for await info in Purchases.shared.customerInfoStream {
                self.apply(info)
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[RevenueCatConfig.entitlementID]
        let active = entitlement?.isActive == true
        // Track WHICH plan is active independently of the change-guard below, so a
        // same-state renewal or a plan switch (monthly→annual) still refreshes it.
        myPlanProductID = active ? entitlement?.productIdentifier : nil
        guard active != myEntitlementActive else { return }
        myEntitlementActive = active
        onEntitlementChange?(active)
    }

    // MARK: - Offerings

    /// Loads the "default" offering's annual + monthly packages so PaywallView can
    /// show real localized prices. Best-effort: on failure the packages stay nil
    /// and PaywallView falls back to its static price copy, so the wall never
    /// looks broken offline.
    func loadOfferings() async {
        guard !isLoadingOfferings else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.current ?? offerings.all[RevenueCatConfig.offeringID]
            guard let offering else { return }
            // Prefer the convenience accessors ($rc_annual / $rc_monthly); fall
            // back to scanning by package type in case the rc_ aliases aren't set.
            annualPackage  = offering.annual  ?? offering.availablePackages.first { $0.packageType == .annual }
            monthlyPackage = offering.monthly ?? offering.availablePackages.first { $0.packageType == .monthly }
        } catch {
            log("loadOfferings failed: \(error.localizedDescription)")
        }
    }

    var annualDisplay: PlanDisplay?  { display(annualPackage) }
    var monthlyDisplay: PlanDisplay? { display(monthlyPackage) }

    private func display(_ package: Package?) -> PlanDisplay? {
        guard let package else { return nil }
        let product = package.storeProduct
        var perMonth: String? = nil
        if let pm = product.pricePerMonth, let fmt = product.priceFormatter,
           let s = fmt.string(from: pm) {
            perMonth = "just \(s)/mo"
        }
        return PlanDisplay(priceText: product.localizedPriceString, perMonthText: perMonth)
    }

    // MARK: - Purchase / restore

    func purchaseAnnual() async -> PurchaseOutcome  { await purchase(annualPackage) }
    func purchaseMonthly() async -> PurchaseOutcome { await purchase(monthlyPackage) }

    private func purchase(_ package: Package?) async -> PurchaseOutcome {
        guard let package else {
            return .failed("Plans are still loading — try again in a moment.")
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)   // flips entitlement -> triggers couple-doc mirror
            return .success
        } catch {
            log("purchase failed: \(error.localizedDescription)")
            return .failed(friendlyMessage(for: error))
        }
    }

    /// Restores prior purchases (e.g. reinstall, or the partner who paid on
    /// another device but is signed in here). Success only if it actually yields
    /// an active entitlement.
    func restore() async -> PurchaseOutcome {
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return myEntitlementActive
                ? .success
                : .failed("No active subscription found to restore.")
        } catch {
            log("restore failed: \(error.localizedDescription)")
            return .failed(friendlyMessage(for: error))
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = (error as NSError).localizedDescription
        return message.isEmpty ? "Something went wrong. Please try again." : message
    }

    // MARK: - Debug logging

    private func log(_ message: String) {
        #if DEBUG
        print("💳 SubscriptionService: \(message)")
        #endif
    }
}
