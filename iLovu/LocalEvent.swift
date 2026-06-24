// LocalEvent.swift
// The data model for a single local event the couple can swipe on
// together. Modelled to match what a real Google Places / Eventbrite
// response would give us — title/venue/date/price plus optional
// rating + review count — so when we wire those APIs later, only the
// fetch layer changes and this struct stays the same.
//
// Why an explicit init?
// Swift's auto-synthesized memberwise init does NOT include `let`
// properties with default values as parameters — they're treated as
// already-initialized and skipped. That made it impossible for
// SampleEvents to pass the new detail fields (address, photos, etc.)
// to the synthesized init. The explicit init below declares every
// property with sensible defaults for the optional ones, so basic
// events can omit the detail fields and rich events can include them.

import Foundation

struct LocalEvent: Identifiable, Equatable {

    // Core fields — every event has these.
    let id: UUID
    let cardId: String      // STABLE cross-device matching key (slug of title by
                            // default, overridable). Two-player matching keys on
                            // this, never on the per-instance `id`.
    let title: String
    let venue: String
    let date: String        // Short label e.g. "Fri 8pm". String for now;
                            // we'll swap to a real Date when we add a
                            // backend with proper time zones + parsing.
    let price: String       // "Free", "£15", etc.
    let category: Category
    let emoji: String
    let description: String

    // Optional review summary — nil if the event hasn't been rated.
    let rating: Double?
    let reviewCount: Int?

    // Detail-screen fields — defaulted via the init below to nil / [].
    // The UI hides any section whose data is missing.
    let address: String?
    let openingHours: String?
    let photos: [String]                // future image URLs / asset names
    let highlights: [String]            // e.g. "🍝 Truffle Pasta"
    let reviewSnippets: [ReviewSnippet]
    let bookingURL: String?

    // Real-event fields — set only for live Ticketmaster events (sample events
    // leave them nil). Defaulted in the init, so every existing call site is
    // unaffected.
    //
    //   startDate     — the event's real start instant; powers the calendar add
    //                   (real datetime instead of a "tomorrow 7pm" guess).
    //   ticketURLBase — the KEY-FREE Ticketmaster ticket page. EventLinkBuilder
    //                   wraps it with the Impact affiliate id at display time;
    //                   distinguishes an affiliate-eligible link from bookingURL
    //                   (which may be a non-Ticketmaster fallback, never wrapped).
    let startDate: Date?
    let ticketURLBase: String?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        cardId: String? = nil,
        title: String,
        venue: String,
        date: String,
        price: String,
        category: Category,
        emoji: String,
        description: String,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        address: String? = nil,
        openingHours: String? = nil,
        photos: [String] = [],
        highlights: [String] = [],
        reviewSnippets: [ReviewSnippet] = [],
        bookingURL: String? = nil,
        startDate: Date? = nil,
        ticketURLBase: String? = nil
    ) {
        self.id              = id
        self.cardId          = cardId ?? Self.slug(title)
        self.title           = title
        self.venue           = venue
        self.date            = date
        self.price           = price
        self.category        = category
        self.emoji           = emoji
        self.description     = description
        self.rating          = rating
        self.reviewCount     = reviewCount
        self.address         = address
        self.openingHours    = openingHours
        self.photos          = photos
        self.highlights      = highlights
        self.reviewSnippets  = reviewSnippets
        self.bookingURL      = bookingURL
        self.startDate       = startDate
        self.ticketURLBase   = ticketURLBase
    }

    /// Deterministic lowercase, hyphenated slug of a title — identical on both
    /// partners' devices, which is what makes it a valid shared match key.
    static func slug(_ title: String) -> String {
        title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    // MARK: - Nested types

    enum Category: String, CaseIterable, Identifiable {
        case music     = "Music"
        case foodDrink = "Food & Drink"
        case arts      = "Arts"
        case outdoors  = "Outdoors"
        case nightlife = "Nightlife"

        var id: String { rawValue }
    }

    // One short review excerpt to render in the detail screen. Will
    // be replaced by Google Places review objects later — same shape.
    // Explicit init for the same reason as LocalEvent: defaulted `let`
    // properties don't show up in the memberwise init.
    struct ReviewSnippet: Identifiable, Equatable {
        let id: UUID
        let author: String
        let rating: Int     // 1...5
        let text: String

        init(id: UUID = UUID(), author: String, rating: Int, text: String) {
            self.id     = id
            self.author = author
            self.rating = rating
            self.text   = text
        }
    }
}
