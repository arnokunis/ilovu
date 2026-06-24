// EventLinkBuilder.swift
// The ONE place a ticket link is built — so turning on affiliate tracking is a
// one-line change in TicketmasterConfig (paste the Impact id) with no rebuild
// elsewhere and, crucially, NO cache invalidation: cached events store only the
// key-free base URL (ticketURLBase), and the affiliate wrapper is applied HERE,
// at display time. Same lesson as the Places key — never bake an
// identifier/secret into a stored doc; inject it when the URL is built.
//
// Today (pre-approval) impactAffiliateId is empty, so this returns the plain
// Ticketmaster URL — links work, just unattributed. Post-approval the wrapper
// switches on automatically for every event, everywhere, instantly.

import Foundation

enum EventLinkBuilder {

    /// The booking URL to open for `event`. Resolution order:
    ///   1. real Ticketmaster ticket page (event.ticketURLBase) — affiliate-
    ///      wrapped when an Impact id is configured, plain otherwise;
    ///   2. any other bookingURL the event carries (e.g. a sample event's link) —
    ///      returned as-is, NEVER affiliate-wrapped (it isn't a Ticketmaster link);
    ///   3. a Google search for "title venue" as a last resort.
    ///
    /// `affiliateId` defaults to the configured id so callers don't pass anything;
    /// it's a parameter purely so the wrapping is testable and so the flip-on is
    /// genuinely one line in config.
    static func ticketURL(
        for event: LocalEvent,
        affiliateId: String = TicketmasterConfig.impactAffiliateId
    ) -> URL? {
        // 1. Real Ticketmaster link — the only affiliate-eligible case.
        if let base = event.ticketURLBase, let baseURL = URL(string: base) {
            return wrap(baseURL, affiliateId: affiliateId)
        }
        // 2. Non-Ticketmaster booking link (sample data) — pass through untouched.
        if let raw = event.bookingURL, let url = URL(string: raw) {
            return url
        }
        // 3. Fallback search.
        return googleSearch(for: event)
    }

    // MARK: - Affiliate wrapping

    /// Wraps a Ticketmaster URL in the Impact tracking redirect when an affiliate
    /// id is set; returns the URL untouched when it isn't (pre-approval today).
    /// The exact Impact format is confirmed at approval time — the structure is
    /// "tracking host / id, with the destination as an encoded param" — but the
    /// SHAPE (one function, destination preserved) is locked now so flipping it on
    /// is a config edit, not a code change.
    private static func wrap(_ destination: URL, affiliateId: String) -> URL {
        guard !affiliateId.isEmpty else { return destination }

        var components = URLComponents()
        components.scheme = "https"
        components.host   = TicketmasterConfig.impactTrackingHost
        // Impact deep-link shape: /<publisherId> with the destination carried as
        // the `u` (url) query item, percent-encoded by URLComponents.
        components.path   = "/\(affiliateId)"
        components.queryItems = [URLQueryItem(name: "u", value: destination.absoluteString)]
        return components.url ?? destination   // never fail a booking over wrapping
    }

    // MARK: - Fallback

    private static func googleSearch(for event: LocalEvent) -> URL? {
        let query = "\(event.title) \(event.venue)"
        guard
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://www.google.com/search?q=\(encoded)")
        else { return nil }
        return url
    }
}
