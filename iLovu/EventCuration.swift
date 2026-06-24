// EventCuration.swift
// The brand filter. iLovu is anti-pressure couples dating — the Near You deck
// should feel like a jazz club, a comedy cellar, a wine tasting; NEVER a
// stadium fixture or a monster-truck rally. Ticketmaster's API-side segment
// filter already drops the Sports segment, so this layer does the FINER work:
//
//   1. map a raw Ticketmaster segment/genre onto one of our five swipe
//      categories (music / foodDrink / arts / outdoors / nightlife), and
//   2. score it for date-appropriateness so the deck ranks intimate/romantic
//      over big-room/impersonal, and HARD-EXCLUDES anything off-brand that
//      slipped through the segment net (kids' shows, motorsports, expos).
//
// Data-driven on purpose: the mappings are plain tables keyed by lowercased
// genre/segment text, so tuning the brand feel is editing a dictionary, not
// rewriting logic (and an easy lift to remote config later). A score of 0 or
// less means "drop it entirely" — curation, not just ordering.

import Foundation

enum EventCuration {

    /// The outcome of curating one raw event: which deck category it belongs to
    /// and how date-appropriate it is. `score <= 0` => exclude.
    struct Verdict {
        let category: LocalEvent.Category
        let score: Int
    }

    // MARK: - Public

    /// Curate one raw Ticketmaster event. Returns nil to EXCLUDE (off-brand or
    /// unclassifiable), or a Verdict carrying its mapped category + score.
    static func curate(_ event: TicketmasterEvent) -> Verdict? {
        let segment = event.classifications?.first?.segment?.name?.lowercased() ?? ""
        let genre   = event.classifications?.first?.genre?.name?.lowercased() ?? ""
        let sub     = event.classifications?.first?.subGenre?.name?.lowercased() ?? ""
        let haystack = "\(segment) \(genre) \(sub)"

        // Hard exclusions first — anything matching is off-brand regardless of
        // segment (e.g. a "Family" show under Arts & Theatre, a motorsport under
        // Miscellaneous). These are the monster-truck-rally guards.
        if excludeKeywords.contains(where: haystack.contains) { return nil }

        // Map to a deck category. Unmappable => we don't trust it on-brand, drop.
        guard let category = category(segment: segment, genre: genre) else { return nil }

        // Base score by segment, nudged by romance-positive genre signals. Higher
        // = more date-appropriate, so it floats up the deck.
        var score = baseScore(forSegment: segment)
        if romanticKeywords.contains(where: haystack.contains) { score += 3 }

        return score > 0 ? Verdict(category: category, score: score) : nil
    }

    /// Curate + rank a batch: drops excluded events, keeps the cardId stable, and
    /// orders by score (most date-appropriate first), then soonest date. The
    /// returned tuples carry the verdict so the cache can persist the mapped
    /// category + score without re-deriving them.
    static func rank(
        _ events: [(event: TicketmasterEvent, start: Date)]
    ) -> [(event: TicketmasterEvent, start: Date, verdict: Verdict)] {
        events
            .compactMap { pair -> (TicketmasterEvent, Date, Verdict)? in
                guard let verdict = curate(pair.event) else { return nil }
                return (pair.event, pair.start, verdict)
            }
            .sorted { lhs, rhs in
                if lhs.2.score != rhs.2.score { return lhs.2.score > rhs.2.score }
                return lhs.1 < rhs.1
            }
            .map { (event: $0.0, start: $0.1, verdict: $0.2) }
    }

    // MARK: - Category mapping

    /// Map a Ticketmaster segment/genre onto one of our five deck categories, or
    /// nil if it doesn't map to anything on-brand. Genre wins over segment where
    /// it's more specific (a "Jazz" music genre at a late club reads nightlife,
    /// but we keep it simple and category-by-segment with a few genre overrides).
    private static func category(segment: String, genre: String) -> LocalEvent.Category? {
        // Genre overrides first — the most specific signal.
        if genre.contains("comedy")                              { return .nightlife }
        if genre.contains("food") || genre.contains("wine")
            || genre.contains("beer") || genre.contains("culinary") { return .foodDrink }

        switch segment {
        case "music":            return .music
        case "arts & theatre":   return .arts
        case "film":             return .arts
        case "miscellaneous":
            // Only the romance-leaning slices of the grab-bag survive; the rest
            // returns nil (dropped). Food/wine handled by the genre override above.
            if genre.contains("fair") || genre.contains("festival") { return .outdoors }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Scoring tables

    /// Per-segment starting score. Theatre/film/music are inherently more
    /// date-shaped (sit together, talk between) than a sprawling festival.
    private static func baseScore(forSegment segment: String) -> Int {
        switch segment {
        case "arts & theatre": return 8
        case "music":          return 7
        case "film":           return 6
        case "miscellaneous":  return 4
        default:               return 0
        }
    }

    /// Genre/sub-genre signals that read intimate & romantic — they float an
    /// event up the deck.
    private static let romanticKeywords: [String] = [
        "jazz", "acoustic", "classical", "blues", "soul", "folk",
        "theatre", "theater", "comedy", "cabaret", "wine", "dance"
    ]

    /// Genre/sub-genre signals that are off-brand for a couples date deck — any
    /// match drops the event regardless of its segment. The monster-truck-rally
    /// list.
    private static let excludeKeywords: [String] = [
        "motorsport", "motor sport", "racing", "wrestling", "rodeo",
        "monster truck", "family", "children", "kids", "expo", "convention",
        "trade show", "esports", "fighting", "boxing", "mma"
    ]
}
