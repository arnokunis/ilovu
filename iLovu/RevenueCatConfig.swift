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

    /// App Store Connect product identifiers behind the offering's packages.
    /// The PURCHASE flow resolves packages via Offering.annual / .monthly (by
    /// package type), so it needs no ids — but the settings STATUS row labels
    /// which plan the subscriber bought, read off
    /// customerInfo.entitlements[...].productIdentifier, which IS a raw id. These
    /// must match the dashboard / ASC products byte-for-byte.
    static let annualProductID  = "com.ilovu.app.annual"   // $49.99/yr ($rc_annual)
    static let monthlyProductID = "com.ilovu.app.monthly"  // $6.99/mo  ($rc_monthly)
}
