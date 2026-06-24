// TicketmasterConfig.swift
// The Ticketmaster Discovery API tunables + the affiliate switch, in one
// discoverable place — same role RevenueCatConfig plays for RevenueCat. The
// API KEY itself lives in Secrets.swift (gitignored); only non-secret tuning
// constants and the affiliate id live here.
//
// THE AFFILIATE SWITCH (impactAffiliateId): empty today because the Impact
// affiliate program isn't approved yet. Post-approval, paste the publisher id
// here — ONE line — and every "Book Now" / ticket link starts earning, with no
// rebuild and (critically) no cache invalidation: cached event docs store only
// the key-free base ticket URL, and the affiliate wrapper is applied at DISPLAY
// time by EventLinkBuilder. Same lesson as the Places key — never bake a
// secret/identifier into a stored doc; inject it when the URL is built.

import Foundation

enum TicketmasterConfig {

    // MARK: - Affiliate (the one-line flip)

    /// Impact publisher / affiliate id used to wrap ticket links so purchases are
    /// attributed to iLovu. EMPTY = not approved yet → EventLinkBuilder returns
    /// the plain Ticketmaster URL, so links still work, just unattributed. Set
    /// this once Impact approves the program and every ticket link starts
    /// tracking immediately (no rebuild, no re-cache). See EventLinkBuilder.
    static let impactAffiliateId = ""

    /// The Impact tracking host that wraps the destination URL. Only consulted
    /// when impactAffiliateId is non-empty. Kept here (not hard-coded in the
    /// builder) so the exact program endpoint can be set at approval time
    /// alongside the id. Placeholder until approval confirms the real value.
    static let impactTrackingHost = "ilovu.pxf.io"

    // MARK: - Discovery API endpoint

    /// Base URL for the Discovery API v2 events search. The consumer key is sent
    /// as the `apikey` query param (Ticketmaster's scheme), added by the service.
    static let eventsSearchURL = "https://app.ticketmaster.com/discovery/v2/events.json"

    // MARK: - Search shape

    /// Radius of the events search around the location bucket centre. ~1km
    /// bucketing already collapses nearby couples onto one shared deck; this is
    /// how far OUT from that centre we pull events. 25km comfortably covers a
    /// city's worth of date options without spilling into the next town.
    static let searchRadiusKm = 25

    /// How far ahead we look for events, in days. The Near You copy is "events
    /// near you this week"; two weeks keeps the deck full while staying genuinely
    /// near-term (a date you can actually plan now, on-brand anti-pressure).
    static let searchWindowDays = 14

    /// Max events pulled per billed search before curation trims/ranks them.
    /// Ticketmaster pages at up to 200; 60 is plenty for a swipe deck and keeps
    /// the cached pointer list (and each partner's deck) a sane size.
    static let maxSearchResults = 60

    /// Geohash precision for the `geoPoint` search param. 7 chars ≈ 150m cells —
    /// finer than our ~1km bucket, so the radius (above) does the real
    /// neighbourhood-sizing while the point just anchors the search.
    static let geohashPrecision = 7

    // MARK: - Cache freshness

    /// The event-query POINTER (eventQueries/{key}) is served stale-while-
    /// revalidate after this long. Much shorter than venues' 7 days: an events
    /// LIST goes stale fast (new shows added, others sell out / pass), so we
    /// refresh the curated list roughly daily in the background. Individual past
    /// events are dropped at read time regardless (see EventCache date-TTL).
    static let queryMaxAge: TimeInterval = 24 * 60 * 60

    /// Grace kept after an event's start time before it's treated as expired, so
    /// a show "tonight" stays swipeable all day instead of vanishing at its door
    /// time. Read-time filtering and the expireAt TTL both apply this.
    static let expiryGrace: TimeInterval = 6 * 60 * 60
}
