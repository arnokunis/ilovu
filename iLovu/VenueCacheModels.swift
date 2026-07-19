// VenueCacheModels.swift
// The Firestore-side shapes for the venue cache. Two collections:
//
//   venues/{placeId}        -> CachedVenue   (the source of truth: one doc per
//                                              resolved Google venue)
//   venueQueries/{queryKey} -> VenueQuery    (a pointer cache: free-text query +
//                                              location bucket -> placeId)
//
// CachedVenue is a *flattened* mirror of the Place struct PlacesService returns
// (Place's nested LocalizedText / Photo / OpeningHours / Review collapse into
// flat fields), so it stores cleanly in Firestore and feeds straight into
// LocalEvent.enriching(...) without the caller knowing it came from cache.
//
// Convention matches the rest of the app (see Couple.swift): @DocumentID for the
// doc id, @ServerTimestamp for server-stamped times, read via `.data(as:)`.
// Writing detail lives in VenueCache (piece 2).

import Foundation
import FirebaseFirestore

// MARK: - venues/{placeId}

struct CachedVenue: Codable, Identifiable {

    /// The Google `place.id`, mirrored from the Firestore document id
    /// (`venues/{placeId}`). Populated automatically on read; left nil on write
    /// (a non-nil @DocumentID can't be encoded — the doc ref carries identity,
    /// and `placeId` below holds the value as a real, queryable field).
    @DocumentID var id: String?

    /// Same value as the doc id, stored as a plain field so it survives encoding
    /// and can be queried / referenced (e.g. future NearYou lists of placeIds).
    var placeId: String

    var displayName: String
    var formattedAddress: String?
    var rating: Double?
    var userRatingCount: Int?
    var priceLevel: String?

    /// Raw Google photo "resource names" (Place.Photo.name), e.g.
    /// "places/{id}/photos/{id}" — the ONLY photo data persisted. Fetchable URLs
    /// are rebuilt on demand via `photoURLStrings(using:)`, so the API key is
    /// NEVER baked into a stored doc (it lives only in Secrets, injected at
    /// display time — survives key rotation with no cache invalidation).
    ///
    /// (Older cached docs may still carry a now-ignored `photoURLs` field with an
    /// embedded key; it's never read and is dropped the next time the doc is
    /// rewritten on revalidation. Decode ignores it, so no schema bump is needed.)
    var photoNames: [String]

    /// Human-readable weekday hours lines (Place.OpeningHours.weekdayDescriptions).
    /// NOTE: Place.OpeningHours.openNow is intentionally NOT cached — it's
    /// time-of-day volatile and would be wrong the moment it's 7 days stale.
    /// Recompute "open now" live if ever needed.
    var openingHoursWeekday: [String]?

    var reviews: [CachedReview]

    var websiteUri: String?
    var googleMapsUri: String?

    /// Deck category (LocalEvent.Category rawValue) + the raw Google primary type,
    /// set ONLY when this venue was resolved for the Near You places deck (via
    /// PlaceCuration). nil for venues resolved by detail-screen text search, which
    /// don't need them. Optional/defaulted so older docs decode cleanly.
    var category: String? = nil
    var primaryType: String? = nil

    /// Server time this doc was last written. Drives the ~7-day staleness check
    /// in VenueCache (stale-while-revalidate). @ServerTimestamp is filled by the
    /// server on write and read back as a Timestamp.
    @ServerTimestamp var fetchedAt: Timestamp?

    /// Bumped whenever this struct's shape changes. VenueCache treats any doc
    /// with an older version as a miss, so a schema change transparently
    /// re-fetches instead of decoding stale/incompatible data.
    var schemaVersion: Int

    /// Flattened Place.Review — author attribution and localized text collapsed
    /// to plain values.
    struct CachedReview: Codable {
        var rating: Double?
        var text: String?
        var authorName: String?
    }

    // v2 added category + primaryType (places deck). Older docs decode fine (both
    // optional), but bumping makes the deck always re-resolve a v1 doc so a deck
    // venue is guaranteed to carry its category.
    static let currentSchemaVersion = 2
}

// MARK: - Place -> CachedVenue

extension CachedVenue {

    /// Builds a cache doc from a freshly-fetched Place. `id` is left nil and
    /// `fetchedAt` is left nil on purpose — the doc ref supplies identity and the
    /// server stamps the time on write. Only key-free photo resource names are
    /// stored; fetchable URLs are rebuilt at display time (see photoURLStrings).
    static func from(_ place: Place, category: LocalEvent.Category? = nil) -> CachedVenue {
        let names = place.photos?.map(\.name) ?? []

        let reviews = (place.reviews ?? []).map { review in
            CachedReview(
                rating: review.rating,
                text: review.text?.text,
                authorName: review.authorAttribution?.displayName
            )
        }

        return CachedVenue(
            id: nil,
            placeId: place.id,
            displayName: place.displayName?.text ?? "",
            formattedAddress: place.formattedAddress,
            rating: place.rating,
            userRatingCount: place.userRatingCount,
            priceLevel: place.priceLevel,
            photoNames: names,
            openingHoursWeekday: place.regularOpeningHours?.weekdayDescriptions,
            reviews: reviews,
            websiteUri: place.websiteUri,
            googleMapsUri: place.googleMapsUri,
            category: category?.rawValue,
            primaryType: place.primaryType,
            fetchedAt: nil,
            schemaVersion: CachedVenue.currentSchemaVersion
        )
    }

    /// Rebuilds fetchable photo URL strings from the stored key-free `photoNames`,
    /// injecting the CURRENT API key via the service. Built fresh per display so a
    /// rotated key takes effect immediately with no cache invalidation. Returns at
    /// most `limit` URLs; empty when there are no photos or no API key.
    func photoURLStrings(using service: PlacesService, limit: Int = 4) -> [String] {
        photoNames.prefix(limit).compactMap { service.photoURL(name: $0)?.absoluteString }
    }
}

// MARK: - venueQueries/{queryKey}

struct VenueQuery: Codable, Identifiable {

    /// The query key (normalized free text + location bucket), mirrored from the
    /// document id (`venueQueries/{queryKey}`). See VenueCache for how the key is
    /// built. Left nil on write, populated on read — same rule as CachedVenue.id.
    @DocumentID var id: String?

    /// The resolved venue this query points at — look it up in `venues/{placeId}`.
    var placeId: String

    /// The original "title + venue" text, kept for debugging / inspection only.
    var rawQuery: String

    /// Server time this query last resolved.
    @ServerTimestamp var resolvedAt: Timestamp?
}

// MARK: - CachedVenue -> LocalEvent (places deck)

extension CachedVenue {

    /// Projects a deck venue onto the existing LocalEvent shape the Near You deck
    /// and detail screen already render — the only seam the rest of the UI sees,
    /// exactly like CachedEvent.asLocalEvent(). `cardId == placeId` (the stable
    /// cross-device match key). The description is a brand-SAFE positive review
    /// snippet, or a curated category tagline when none qualifies (PlaceCuration).
    func asLocalEvent() -> LocalEvent {
        let cat = LocalEvent.Category(rawValue: category ?? "") ?? .foodDrink
        let blurb = PlaceCuration.brandSafeSnippet(from: reviews) ?? PlaceCuration.tagline(for: cat)
        return LocalEvent(
            cardId:        placeId,
            title:         displayName,
            venue:         Self.typeLabel(primaryType: primaryType, category: cat),
            date:          "",                       // venues have no date; the card joins non-empty parts
            price:         Self.priceLabel(priceLevel),
            category:      cat,
            emoji:         Self.emoji(for: cat),
            description:   blurb,
            rating:        rating,
            reviewCount:   userRatingCount,
            address:       formattedAddress,
            openingHours:  openingHoursWeekday?.first,
            bookingURL:    googleMapsUri ?? websiteUri,   // "Book Now" -> Maps/site (never Ticketmaster-wrapped)
            sourceDeck:    .places
        )
    }

    /// A human secondary-line label from the raw Google primary type ("coffee_shop"
    /// -> "Coffee Shop"), falling back to the deck category name.
    private static func typeLabel(primaryType: String?, category: LocalEvent.Category) -> String {
        guard let raw = primaryType, !raw.isEmpty else { return category.rawValue }
        return raw
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Map the Places (New) priceLevel enum to a compact symbol. "" when absent —
    /// the card hides an empty price pill rather than showing a blank one.
    private static func priceLabel(_ level: String?) -> String {
        switch level {
        case "PRICE_LEVEL_FREE":           return "Free"
        case "PRICE_LEVEL_INEXPENSIVE":    return "€"
        case "PRICE_LEVEL_MODERATE":       return "€€"
        case "PRICE_LEVEL_EXPENSIVE":      return "€€€"
        case "PRICE_LEVEL_VERY_EXPENSIVE": return "€€€€"
        default:                           return ""
        }
    }

    private static func emoji(for category: LocalEvent.Category) -> String {
        switch category {
        case .foodDrink: return "🍽️"
        case .nightlife: return "🍸"
        case .arts:      return "🎨"
        case .outdoors:  return "🌳"
        case .trails:    return "🥾"
        case .music:     return "🎶"
        }
    }
}

// MARK: - placeDeckQueries/{queryKey}

struct PlaceDeckQuery: Codable, Identifiable {

    /// The query key (= the location bucket). nil on write, populated on read.
    @DocumentID var id: String?

    /// The resolved deck — an ORDERED, curated list of placeIds (look each up in
    /// venues/{placeId}). Ordered so both partners swipe the same sequence, which
    /// keeps their cardIds aligned for matching — same role as EventQuery.eventIds.
    var placeIds: [String]

    /// The curation-logic version that produced this deck (PlaceCuration.curationVersion).
    /// A mismatch means the deck predates a curation change, so VenueCache treats it
    /// as a miss and re-resolves. Optional/nil for decks written before this field
    /// existed — they re-resolve once, then carry the current version.
    var curationVersion: Int? = nil

    /// Server time this deck last resolved — drives the SWR refresh window.
    @ServerTimestamp var resolvedAt: Timestamp?
}
