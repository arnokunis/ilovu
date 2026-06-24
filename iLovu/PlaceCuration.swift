// PlaceCuration.swift
// The brand filter for the Near You PLACES deck — the venue twin of
// EventCuration. iLovu is anti-pressure couples dating, so the deck should feel
// like an intimate restaurant, a wine bar, a cosy café, a gallery to wander —
// NEVER fast food, a chain, a supermarket, or a petrol station.
//
// Three gates, in order: hard-exclude -> category-map -> quality + score.
// Google Places types are the primary signal (mirroring how EventCuration uses
// Ticketmaster segments). Everything is a plain, tunable table so adjusting the
// brand feel is editing a dictionary, not rewriting logic (and an easy lift to
// remote config later). A score of 0 or less means "drop it".
//
// Also owns the brand-SAFE review-snippet selection used for a card's
// description: only short, clearly-positive snippets ever show — a date card
// must never surface a negative or weird review. No suitable snippet => the
// caller uses a curated per-category tagline.

import Foundation

enum PlaceCuration {

    /// The outcome of curating one venue: its mapped deck category + a
    /// date-appropriateness score. `score <= 0` => exclude.
    struct Verdict {
        let category: LocalEvent.Category
        let score: Int
    }

    // MARK: - API include-types (grouped for variety)
    // searchNearby returns at most ~20 per call, and a single mixed call is
    // dominated by prominent restaurants — so we fan out a few grouped calls to
    // guarantee arts / outdoors / nightlife get representation, then merge +
    // curate. All cached, so it's a handful of billed calls per bucket per
    // refresh, not per user.
    //
    // NOTE: every string here MUST be a valid Places API (New) "Table A" type —
    // an unknown type 400s the whole call. This is a conservative, known-valid
    // set; widen it (wine_bar, tea_house, performing_arts_theater…) only after
    // confirming each against the current Table A.
    static let searchGroups: [[String]] = [
        ["restaurant", "cafe", "coffee_shop", "bakery", "ice_cream_shop"],   // food & drink
        ["bar", "night_club"],                                               // nightlife
        ["art_gallery", "museum", "movie_theater", "book_store"],            // arts
        ["tourist_attraction", "park"]                                       // outdoors / experiences
    ]

    // MARK: - Curate one venue

    /// Curate a single Place. Returns nil to EXCLUDE (off-brand, closed, or too
    /// little signal), or a Verdict with its mapped category + score.
    static func curate(_ place: Place) -> Verdict? {
        // primaryType first (most specific), then the rest — all lowercased.
        let allTypes: [String] = ([place.primaryType].compactMap { $0 } + (place.types ?? []))
            .map { $0.lowercased() }
        let name = place.displayName?.text.lowercased() ?? ""

        // 1. Hard exclusions — any off-brand type, or a known chain by name.
        if allTypes.contains(where: excludeTypes.contains) { return nil }
        if chainDenylist.contains(where: name.contains) { return nil }

        // 2. Quality gate — open for business, with enough rating signal to trust.
        if let status = place.businessStatus, status != "OPERATIONAL" { return nil }
        guard let rating = place.rating, rating >= minRating,
              let count = place.userRatingCount, count >= minRatingCount else { return nil }

        // 3. Map to a deck category (first mapped type wins). Unmappable => drop.
        var mapped: (LocalEvent.Category, Int)?
        for type in allTypes {
            if let hit = typeScores[type] { mapped = hit; break }
        }
        guard let (category, base) = mapped else { return nil }

        // Score = type base + a rating boost + a "wine" nudge (catches wine bars
        // that Google returns under the generic `bar` type).
        var score = base + ratingBoost(rating)
        if name.contains("wine") || allTypes.contains(where: { $0.contains("wine") }) { score += 2 }

        return score > 0 ? Verdict(category: category, score: score) : nil
    }

    /// Curate + rank a batch: drop excluded venues, dedupe by placeId keeping the
    /// best score, then order by score desc (most date-appropriate first) then
    /// rating desc. Returns each surviving place with its verdict.
    static func rank(_ places: [Place]) -> [(place: Place, verdict: Verdict)] {
        var bestByID: [String: (place: Place, verdict: Verdict)] = [:]
        for place in places {
            guard let verdict = curate(place) else { continue }
            if let existing = bestByID[place.id], existing.verdict.score >= verdict.score { continue }
            bestByID[place.id] = (place, verdict)
        }
        return bestByID.values.sorted { lhs, rhs in
            if lhs.verdict.score != rhs.verdict.score { return lhs.verdict.score > rhs.verdict.score }
            return (lhs.place.rating ?? 0) > (rhs.place.rating ?? 0)
        }
    }

    // MARK: - Category + scoring tables

    /// type -> (deck category, base score). Higher base = more inherently
    /// date-shaped (linger over dinner > grab an ice cream). A venue maps via the
    /// first of its types found here. `bar` reads nightlife; wine bars get nudged
    /// up by the "wine" boost in curate().
    private static let typeScores: [String: (LocalEvent.Category, Int)] = [
        "restaurant":         (.foodDrink, 7),
        "cafe":               (.foodDrink, 6),
        "coffee_shop":        (.foodDrink, 6),
        "bakery":             (.foodDrink, 5),
        "ice_cream_shop":     (.foodDrink, 4),
        "bar":                (.nightlife, 7),
        "night_club":         (.nightlife, 5),
        "art_gallery":        (.arts, 7),
        "museum":             (.arts, 6),
        "movie_theater":      (.arts, 6),
        "book_store":         (.arts, 5),
        "tourist_attraction": (.outdoors, 6),
        "park":               (.outdoors, 5)
    ]

    private static func ratingBoost(_ rating: Double) -> Int {
        switch rating {
        case 4.7...: return 3
        case 4.5...: return 2
        case 4.2...: return 1
        default:     return 0
        }
    }

    /// Quality gates — keep junk and unproven spots out of a romantic deck.
    /// Tunable; raised/lowered if Vilnius (or a future market) comes up thin.
    private static let minRating = 4.0
    private static let minRatingCount = 30

    /// Off-brand types — any match drops the venue regardless of score. The
    /// "not a date" list.
    private static let excludeTypes: Set<String> = [
        "fast_food_restaurant", "meal_takeaway", "meal_delivery",
        "convenience_store", "supermarket", "grocery_store", "grocery_or_supermarket",
        "gas_station", "lodging", "department_store", "shopping_mall"
    ]

    /// Known chains to drop by name (case-insensitive contains). Includes the big
    /// Lithuanian fast-food / retail names since Vilnius is the launch market —
    /// extend per market. Imperfect by nature, but cheap brand insurance.
    private static let chainDenylist: [String] = [
        "mcdonald", "kfc", "subway", "burger king", "starbucks", "domino",
        "pizza hut", "taco bell", "wendy", "dunkin", "costa coffee",
        "hesburger", "maxima", "iki", "rimi", "lidl", "norfa", "circle k"
    ]

    // MARK: - Brand-safe review snippet (card description)

    /// The best SHORT, clearly-POSITIVE review snippet to show as a card's
    /// description, or nil if none qualify (caller falls back to a tagline). A
    /// date card must never show a negative/weird review, so this is strict:
    /// 4★+, concise, single-line, and free of any red-flag word.
    static func brandSafeSnippet(from reviews: [CachedVenue.CachedReview]) -> String? {
        for review in reviews {
            guard let rating = review.rating, rating >= 4,
                  let raw = review.text else { continue }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = text.lowercased()

            // Short + single-thought only (long reviews ramble into caveats).
            guard (20...140).contains(text.count), !text.contains("\n") else { continue }
            // No negativity or tonal red flags, even on a 4★ review (they often
            // carry a "but…").
            if snippetRedFlags.contains(where: lower.contains) { continue }

            return text
        }
        return nil
    }

    /// Warm, on-brand, anti-pressure fallback line per category — used when no
    /// review snippet is brand-safe.
    static func tagline(for category: LocalEvent.Category) -> String {
        switch category {
        case .foodDrink: return "A cosy spot to linger over a meal together."
        case .nightlife: return "Low-lit and easy — made for an evening out."
        case .arts:      return "Wander and see something new, side by side."
        case .outdoors:  return "Fresh air and unhurried conversation."
        case .music:     return "Somewhere to share a song or two."
        }
    }

    /// Words that disqualify a snippet — negativity, complaints, or tonal misfires
    /// for a romantic date app.
    private static let snippetRedFlags: [String] = [
        "bad", "rude", "slow", "dirty", "overpriced", "worst", "avoid",
        "disappoint", "mediocre", "terrible", "awful", "cold", "wait",
        "closed", "expensive", "meh", "not worth", "never again", "horrible",
        "unfriendly", "bland", "stale", "noisy", "crowded", "tourist trap"
    ]
}
