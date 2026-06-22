// RevenueCatConfig.swift
// The RevenueCat dashboard identifiers the app reads, in one discoverable place.
// These MUST match the RevenueCat project settings (and the linked App Store
// Connect products) byte-for-byte — a typo here fails silently: no offering
// loads, or the entitlement never reads active. Change them here, nowhere else.

enum RevenueCatConfig {

    /// Entitlement that unlocks premium (RevenueCat dashboard → Entitlements).
    /// Read from customerInfo.entitlements[...] to decide premium access.
    static let entitlementID = "premium"

    /// Offering the paywall reads its packages from (RevenueCat → Offerings).
    /// `current` is preferred at runtime; this is the explicit fallback id when
    /// no current offering is configured.
    static let offeringID = "default"

    // For reference — configured in the dashboard, NOT matched by string in code:
    //   package $rc_annual  → product com.ilovu.app.annual  ($49.99/yr)
    //   package $rc_monthly → product com.ilovu.app.monthly ($6.99/mo)
    // The app resolves these via Offering.annual / .monthly (by package type),
    // so they need no string constants here.
}
