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

    // MARK: - Init

    init(
        id: UUID = UUID(),
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
        bookingURL: String? = nil
    ) {
        self.id              = id
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
