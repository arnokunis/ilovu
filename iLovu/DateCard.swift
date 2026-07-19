// DateCard.swift
// The data model for a single date idea — the thing the user swipes on.
// This file defines WHAT a date card IS, not how it looks.
// (The visual card lives in SwipeView.swift; this is just the data shape.)

import Foundation

// MARK: - DateCard
// A struct because cards are simple value types — copying one is fine,
// they don't need shared identity or reference semantics.
//
// `Identifiable` lets SwiftUI's ForEach loop over cards automatically
// using the `id` property. `Equatable` lets us compare two cards
// (handy for "did the user just match on this exact card?").
// Added Codable so a DateCard embedded inside a Mission can be persisted
// (Mission → JSON → UserDefaults via MissionStore).
struct DateCard: Identifiable, Equatable, Codable {
    let id: UUID = UUID()           // Per-instance fingerprint for SwiftUI/ForEach.
                                    // NOT stable across launches or devices — never
                                    // match on this; it differs for each partner.
    let cardId: String               // STABLE, cross-device matching key. Defaults to a
                                    // slug of the title (identical on both partners'
                                    // devices) but is overridable per card. Two-player
                                    // matching keys swipes on this. See init below.
    let title: String                // Short headline, e.g. "Slow Dance in the Kitchen"
    let description: String          // 1-2 warm sentences explaining the date idea.
    let emoji: String                // The big visual hook at the top of the card.
    let difficulty: Difficulty       // How much time/effort this date needs.
    let estimatedCost: Cost          // Rough money commitment.
    let category: Category           // The vibe — cosy, foodie, adventure, etc.
    let whyItWorks: String           // Bespoke per-card line shown on the detail sheet.
    let tips: [String]               // Bespoke per-card practical tips on the detail sheet.

    // MARK: - Init
    // Explicit (replacing the synthesized memberwise init) so cardId can default
    // to a slug of the title while staying overridable per card. `id` keeps its
    // property-level UUID() default and is NOT a parameter — exactly as before,
    // sample data never passed it. Existing DateCard(...) call sites are
    // unchanged: they simply omit cardId and get the slug.
    init(
        title: String,
        description: String,
        emoji: String,
        difficulty: Difficulty,
        estimatedCost: Cost,
        category: Category,
        whyItWorks: String,
        tips: [String],
        cardId: String? = nil
    ) {
        self.cardId        = cardId ?? Self.slug(title)
        self.title         = title
        self.description   = description
        self.emoji         = emoji
        self.difficulty    = difficulty
        self.estimatedCost = estimatedCost
        self.category      = category
        self.whyItWorks    = whyItWorks
        self.tips          = tips
    }

    /// Deterministic lowercase, hyphenated slug of a title — identical on both
    /// partners' devices, which is exactly what makes it a valid shared match key.
    static func slug(_ title: String) -> String {
        title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    // MARK: - Difficulty
    // An enum because difficulty has a fixed set of options.
    // The raw String value is what we show in the UI — no extra mapping needed.
    enum Difficulty: String, CaseIterable, Codable {
        case micro      = "Micro · 5 min"
        case quick      = "Quick · 30 min"
        case halfDay    = "Half Day"
        case adventure  = "Full Day Adventure"
    }

    // MARK: - Cost
    // Three buckets — keeps things simple. No exact prices, just a feel.
    enum Cost: String, CaseIterable, Codable {
        case free   = "Free"
        case low    = "Low"
        case medium = "Medium"
    }

    // MARK: - Category
    // The emotional flavor of the date. Used later to filter or theme cards.
    enum Category: String, CaseIterable, Codable {
        case cosy
        case foodie
        case adventure
        case creative
        case intimate
    }
}

// MARK: - Decode tolerance
// DateCards are embedded in Missions (Mission → JSON → UserDefaults via
// MissionStore). Missions saved BEFORE cardId existed have no cardId key, so the
// synthesized decoder would throw and those missions would silently disappear.
// This custom decoder fills a missing cardId from the title slug instead. `id`
// is intentionally not decoded — it keeps its UUID() default (a fresh per-load
// fingerprint is fine; matching keys on cardId, never id). encode(to:) and
// CodingKeys are still synthesized, so new saves persist cardId going forward.
extension DateCard {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.title         = try c.decode(String.self, forKey: .title)
        self.description   = try c.decode(String.self, forKey: .description)
        self.emoji         = try c.decode(String.self, forKey: .emoji)
        self.difficulty    = try c.decode(Difficulty.self, forKey: .difficulty)
        self.estimatedCost = try c.decode(Cost.self, forKey: .estimatedCost)
        self.category      = try c.decode(Category.self, forKey: .category)
        self.whyItWorks    = try c.decode(String.self, forKey: .whyItWorks)
        self.tips          = try c.decode([String].self, forKey: .tips)
        // Decode-tolerant: old missions predate cardId.
        self.cardId        = try c.decodeIfPresent(String.self, forKey: .cardId) ?? Self.slug(title)
    }
}

// MARK: - Adapt a Near You venue (LocalEvent) into a DateCard
// Lets a curated Google Places venue be PLANNED as a Mission exactly like a
// swiped date card. The Mission / sync / planning / completion chain only ever
// sees a DateCard, so nothing downstream changes. cardId == placeId (the stable
// cross-device key) — also what the `.places` mission-rebuild path keys on.
// The venue-less fields (difficulty/cost/whyItWorks/tips) map to sensible
// defaults; MissionDetailView only renders emoji/title/description/difficulty.
extension DateCard {
    init(fromVenue e: LocalEvent) {
        self.init(
            title:         e.title,
            description:   e.description,
            emoji:         e.emoji,
            difficulty:    .halfDay,                       // a venue is an outing, not a 5-min gesture
            estimatedCost: Self.venueCost(e.price),
            category:      Self.venueCategory(e.category),
            whyItWorks:    "",                             // not rendered by MissionDetailView
            tips:          [],                             // not rendered by MissionDetailView
            cardId:        e.cardId                        // == placeId
        )
    }

    // LocalEvent.Category -> DateCard.Category (approved mapping). `.cosy` is
    // intentionally unreachable: it's the at-home vibe, and every venue is an outing.
    private static func venueCategory(_ c: LocalEvent.Category) -> Category {
        switch c {
        case .foodDrink: return .foodie
        case .outdoors:  return .adventure
        case .trails:    return .adventure
        case .nightlife: return .intimate
        case .arts:      return .creative
        case .music:     return .creative
        }
    }

    // Venue price label (from asLocalEvent: "Free" / "€"…"€€€€" / "") -> Cost.
    // Expensive tiers collapse to .medium (the enum ceiling); unknown -> .medium
    // so we never undersell a pricey spot as cheap.
    private static func venueCost(_ price: String) -> Cost {
        switch price {
        case "Free": return .free
        case "€":    return .low
        default:     return .medium      // €€ / €€€ / €€€€ and "" (unknown)
        }
    }
}
