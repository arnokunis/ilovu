// NearYouConfig.swift
// Picks what fills the Near You deck per market, in one discoverable place. The
// Ticketmaster events pipeline (EventCache / EventCuration / TicketmasterService
// …) stays fully built and intact — this switch just decides whether it's the
// active source. Vilnius launches on .places (Google Places has rich
// date-venue coverage there; Ticketmaster has almost none). Markets with good
// event coverage flip to .events or .both later — a one-line change, no rebuild.

enum NearYouSource {
    case places   // Google Places venues (restaurants, wine bars, cafés, galleries…)
    case events   // Ticketmaster events — dormant at launch, kept ready
    case both     // interleave both (future — needs per-card deck tagging; see NearYouView)
}

enum NearYouConfig {

    /// The active deck source. .places for the Vilnius launch; flip to .events or
    /// .both in coverage-rich markets. The events code path is preserved and
    /// re-enabled solely by changing this value.
    static let source: NearYouSource = .places
}
