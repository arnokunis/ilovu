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

    /// Raw Google photo "resource names" (Place.Photo.name) — kept so we can
    /// rebuild URLs later (e.g. at a different size) without another API call.
    var photoNames: [String]
    /// Pre-built fetchable photo URLs (via PlacesService.photoURL). Decision:
    /// cache the URL *strings* only for v1 — image bytes are NOT mirrored to
    /// Storage. AsyncImage still fetches the bytes from Google per render.
    var photoURLs: [String]

    /// Human-readable weekday hours lines (Place.OpeningHours.weekdayDescriptions).
    /// NOTE: Place.OpeningHours.openNow is intentionally NOT cached — it's
    /// time-of-day volatile and would be wrong the moment it's 7 days stale.
    /// Recompute "open now" live if ever needed.
    var openingHoursWeekday: [String]?

    var reviews: [CachedReview]

    var websiteUri: String?
    var googleMapsUri: String?

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

    static let currentSchemaVersion = 1
}

// MARK: - Place -> CachedVenue

extension CachedVenue {

    /// Builds a cache doc from a freshly-fetched Place. `service` is needed only
    /// to turn photo resource names into URL strings (photoURL embeds the API
    /// key). `id` is left nil and `fetchedAt` is left nil on purpose — the doc
    /// ref supplies identity and the server stamps the time on write.
    static func from(_ place: Place, using service: PlacesService) -> CachedVenue {
        let names = place.photos?.map(\.name) ?? []
        let urls  = names.compactMap { service.photoURL(name: $0)?.absoluteString }

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
            photoURLs: urls,
            openingHoursWeekday: place.regularOpeningHours?.weekdayDescriptions,
            reviews: reviews,
            websiteUri: place.websiteUri,
            googleMapsUri: place.googleMapsUri,
            fetchedAt: nil,
            schemaVersion: CachedVenue.currentSchemaVersion
        )
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
