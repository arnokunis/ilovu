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

    /// Bumped whenever the curation logic changes (search groups, type→category
    /// mapping, scoring, or quality gates) in a way that should INVALIDATE already-
    /// cached decks. VenueCache stamps this onto each placeDeckQueries doc and
    /// treats a mismatch as a miss, so a curation change re-resolves the deck on
    /// the next Near You open instead of waiting out the 7-day SWR window.
    /// v2 (2026-07-19): added the Hikes & Trails category.
    /// v3 (2026-07-21): per-category search radius (10 km going-out / 30 km outdoors + trails).
    /// v4 (2026-07-28): popularity boost — busier (more-reviewed) venues rank higher.
    /// v5 (2026-07-31): 10 split cuisine food searches (was 1) + review floor 30→15 — many more cards.
    /// v6 (2026-08-06): split nightlife/arts/trails too (each was 1 search capped at 20) — more cards per category.
    static let curationVersion = 6

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
    // RADIUS is PER-GROUP because intent differs: a dinner/drinks/arts date is
    // "near us tonight" (~10 km — rich in dense cities, covers suburban sprawl,
    // and POPULARITY ranking + curation keep nearby spots on top), while a hike or
    // park is "somewhere we'll drive to this weekend" (~30 km — trails sit well
    // beyond the urban core, so a tight radius leaves that deck thin). Wider radius
    // costs nothing extra: billed per bucket refresh, not per user.
    //
    // NOTE: every string here MUST be a valid Places API (New) "Table A" type —
    // an unknown type 400s the whole call. This is a conservative, known-valid
    // set; widen it (wine_bar, tea_house, performing_arts_theater…) only after
    // confirming each against the current Table A.
    struct SearchGroup {
        let types: [String]
        let radiusMeters: Double
    }

    static let searchGroups: [SearchGroup] = [
        // FOOD & DRINK — split into many NARROW searches so each returns its own
        // ~20 (one broad search caps at Google's 20-result max). This multiplies
        // the deck AND sets up per-cuisine filtering. Overlap across groups is
        // deduped by placeId in rank(). Every type below is a confirmed Table A
        // includedType — a bad type 400s only its own group.
        SearchGroup(types: ["restaurant"], radiusMeters: 10_000),
        SearchGroup(types: ["cafe", "coffee_shop", "bakery", "ice_cream_shop"], radiusMeters: 10_000),
        SearchGroup(types: ["pizza_restaurant", "italian_restaurant"], radiusMeters: 10_000),
        SearchGroup(types: ["sushi_restaurant", "japanese_restaurant", "ramen_restaurant"], radiusMeters: 10_000),
        SearchGroup(types: ["steak_house", "seafood_restaurant", "barbecue_restaurant"], radiusMeters: 10_000),
        SearchGroup(types: ["thai_restaurant", "indian_restaurant", "chinese_restaurant", "korean_restaurant", "vietnamese_restaurant", "indonesian_restaurant"], radiusMeters: 10_000),
        SearchGroup(types: ["turkish_restaurant", "middle_eastern_restaurant", "mediterranean_restaurant", "greek_restaurant", "lebanese_restaurant"], radiusMeters: 10_000),
        SearchGroup(types: ["french_restaurant", "spanish_restaurant", "brazilian_restaurant"], radiusMeters: 10_000),
        SearchGroup(types: ["mexican_restaurant", "hamburger_restaurant", "american_restaurant", "sandwich_shop"], radiusMeters: 10_000),
        SearchGroup(types: ["vegan_restaurant", "vegetarian_restaurant", "brunch_restaurant", "breakfast_restaurant"], radiusMeters: 10_000),
        // NIGHTLIFE — split so each returns its own ~20 (bars are plentiful).
        SearchGroup(types: ["bar"], radiusMeters: 10_000),
        SearchGroup(types: ["wine_bar", "night_club"], radiusMeters: 10_000),
        // ARTS — split into two searches.
        SearchGroup(types: ["art_gallery", "museum"], radiusMeters: 10_000),
        SearchGroup(types: ["movie_theater", "book_store"], radiusMeters: 10_000),
        // OUTDOORS — open-air leisure
        SearchGroup(types: ["tourist_attraction", "plaza", "marina", "dog_park"], radiusMeters: 30_000),
        // HIKES & TRAILS — split: true wilderness vs parks/gardens, so each
        // returns its own ~20 (nature is thinner, but this doubles the ceiling).
        SearchGroup(types: ["hiking_area", "national_park", "state_park", "campground", "wildlife_park"], radiusMeters: 30_000),
        SearchGroup(types: ["park", "botanical_garden", "garden"], radiusMeters: 30_000)
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

        // 2. Open for business.
        if let status = place.businessStatus, status != "OPERATIONAL" { return nil }

        // 3. Map to a deck category (first mapped type wins). Unmappable => drop.
        // Done BEFORE the quality gate so the rating-count floor can be
        // category-aware (nature spots draw far fewer reviews than restaurants).
        var mapped: (LocalEvent.Category, Int)?
        for type in allTypes {
            if let hit = typeScores[type] { mapped = hit; break }
        }
        guard let (category, base) = mapped else { return nil }

        // 4. Quality gate — enough rating signal to trust, floor per category.
        guard let rating = place.rating, rating >= minRating,
              let count = place.userRatingCount, count >= minRatingCount(for: category) else { return nil }

        // Score = type base + a rating boost + a POPULARITY boost (review volume,
        // our proxy for "what everyone's raving about") + a "wine" nudge (catches
        // wine bars that Google returns under the generic `bar` type).
        var score = base + ratingBoost(rating) + popularityBoost(count)
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
        // Cuisine-specific restaurant types (from the split food searches). Most
        // also carry the generic `restaurant` type, but mapping them explicitly
        // guarantees a match + a sensible score for date-appropriateness.
        "pizza_restaurant":         (.foodDrink, 7),
        "italian_restaurant":       (.foodDrink, 8),
        "sushi_restaurant":         (.foodDrink, 8),
        "japanese_restaurant":      (.foodDrink, 8),
        "ramen_restaurant":         (.foodDrink, 6),
        "steak_house":              (.foodDrink, 8),
        "seafood_restaurant":       (.foodDrink, 8),
        "barbecue_restaurant":      (.foodDrink, 6),
        "thai_restaurant":          (.foodDrink, 7),
        "indian_restaurant":        (.foodDrink, 7),
        "chinese_restaurant":       (.foodDrink, 6),
        "korean_restaurant":        (.foodDrink, 7),
        "vietnamese_restaurant":    (.foodDrink, 6),
        "indonesian_restaurant":    (.foodDrink, 6),
        "turkish_restaurant":       (.foodDrink, 7),
        "middle_eastern_restaurant":(.foodDrink, 6),
        "mediterranean_restaurant": (.foodDrink, 8),
        "greek_restaurant":         (.foodDrink, 7),
        "lebanese_restaurant":      (.foodDrink, 6),
        "french_restaurant":        (.foodDrink, 8),
        "spanish_restaurant":       (.foodDrink, 7),
        "brazilian_restaurant":     (.foodDrink, 6),
        "mexican_restaurant":       (.foodDrink, 7),
        "hamburger_restaurant":     (.foodDrink, 5),
        "american_restaurant":      (.foodDrink, 6),
        "sandwich_shop":            (.foodDrink, 4),
        "vegan_restaurant":         (.foodDrink, 6),
        "vegetarian_restaurant":    (.foodDrink, 6),
        "brunch_restaurant":        (.foodDrink, 7),
        "breakfast_restaurant":     (.foodDrink, 6),
        "bar":                (.nightlife, 7),
        "wine_bar":           (.nightlife, 8),
        "night_club":         (.nightlife, 5),
        "art_gallery":        (.arts, 7),
        "museum":             (.arts, 6),
        "movie_theater":      (.arts, 6),
        "book_store":         (.arts, 5),
        // Outdoors — open-air leisure & sightseeing (kept distinct from Trails).
        "tourist_attraction": (.outdoors, 6),
        "marina":             (.outdoors, 5),
        "plaza":              (.outdoors, 4),
        "dog_park":           (.outdoors, 3),
        // Hikes & Trails — nature you move through. Broad on purpose: in launch
        // markets true hiking_area/national_park are thin, so parks/gardens/scenic
        // spots fill the deck (they carry the ratings — see minRatingCount). Maps
        // the primaryTypes Google actually returns (city_park, observation_deck)
        // too, not just the searchable includedTypes.
        "hiking_area":        (.trails, 8),
        "national_park":      (.trails, 8),
        "state_park":         (.trails, 7),
        "park":               (.trails, 6),
        "city_park":          (.trails, 6),
        "botanical_garden":   (.trails, 6),
        "wildlife_park":      (.trails, 6),
        "observation_deck":   (.trails, 6),
        "garden":             (.trails, 5),
        "campground":         (.trails, 5)
    ]

    private static func ratingBoost(_ rating: Double) -> Int {
        switch rating {
        case 4.7...: return 3
        case 4.5...: return 2
        case 4.2...: return 1
        default:     return 0
        }
    }

    /// A modest, log-scaled boost for how BUSY a venue is (review volume) — the
    /// closest proxy Google gives us for "what everyone's raving about right now"
    /// (the buzzy / TikTok-famous feel your users chase). Log-scaled + capped so a
    /// genuinely popular spot rises, but sheer tourist-trap volume can't bury a
    /// quiet high-rated gem: e.g. a 4.0/20k place only TIES a 4.8/60 gem on score,
    /// and rating breaks the tie (see rank()). Roughly: 30→1, 100→2, 1k→3, 10k+→4.
    private static func popularityBoost(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(4, Int(log10(Double(count))))
    }

    /// Quality gates — keep junk and unproven spots out of a romantic deck.
    /// Tunable; raised/lowered if Vilnius (or a future market) comes up thin.
    private static let minRating = 4.0

    /// Minimum rating count to trust a venue, per category. Restaurants/bars are
    /// review-dense, so 30 keeps unproven spots out; parks, trails and gardens
    /// draw a fraction of the reviews an eatery does, so a lower floor keeps real
    /// nature spots in the Hikes & Trails deck without loosening the food/nightlife
    /// bar. Highly-rated is still required (minRating) either way.
    private static func minRatingCount(for category: LocalEvent.Category) -> Int {
        switch category {
        case .trails: return 10
        default:      return 15   // lowered from 30 to surface MORE cards (rating floor 4.0 still applies)
        }
    }

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
        case .trails:    return "Lace up and wander somewhere green together."
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
