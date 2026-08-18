// PlacesService.swift
// Talks to the Google Places API (New). Used by EventDetailView to
// fetch real photos, ratings, reviews, hours, and address for a venue,
// and by VenueCache.deck to pull date-appropriate venues NEAR the user
// for the Near You deck. The whole service is one struct:
//
//   • searchText(query:)    — find places matching free text
//   • searchNearby(...)     — find places of given types near a point
//   • photoURL(name:)       — build a fetchable URL for a place photo
//
// Why does this read like a beginner's first networking class?
// Because that's exactly what it is on purpose. URLSession + async
// + Codable is Apple's recommended path for app-side HTTP today, and
// it doesn't need any extra packages.

import Foundation

struct PlacesService {

    // MARK: - Configuration

    /// True only when Secrets.swift has been filled in with a real
    /// API key. EventDetailView checks this before attempting any
    /// fetch — when false, the app silently keeps using sample data.
    var hasAPIKey: Bool {
        !Secrets.googlePlacesAPIKey.isEmpty
    }

    private var apiKey: String { Secrets.googlePlacesAPIKey }

    private let baseURL = URL(string: "https://places.googleapis.com/v1")!

    // The Places API (New) requires a FieldMask listing which fields
    // we want returned. This both controls cost (we only pay for
    // fields we ask for) and forces us to think about exactly what
    // we need. Fields for the SearchText endpoint are prefixed with
    // `places.` because the response is a `places` array.
    private static let searchFieldMask: String = [
        "places.id",
        "places.displayName",
        "places.formattedAddress",
        "places.rating",
        "places.userRatingCount",
        "places.priceLevel",
        "places.photos",
        "places.regularOpeningHours",
        "places.reviews",
        "places.websiteUri",
        "places.googleMapsUri",
        // Phone number (added 2026-08-12) powers the mission's Call button — the
        // missing step between planning a place and actually going. `reviews`
        // above already puts this request in the top Places SKU, so this field
        // does not move the billing tier; verify against the pricing table if
        // that ever changes.
        "places.nationalPhoneNumber"
    ].joined(separator: ",")

    // Nearby Search needs everything searchText returns PLUS the signals
    // PlaceCuration ranks on: the type (to map a venue to a deck category and
    // score date-appropriateness), the coordinate, and the open/closed status
    // (so we never surface a permanently-closed spot). reviews + photos ride
    // along so a deck-resolved venue lands in the cache already rich enough for
    // the detail screen to read for free (no second billed call).
    private static let nearbyFieldMask: String = (searchFieldMask + "," + [
        "places.primaryType",
        "places.types",
        "places.location",
        "places.businessStatus"
    ].joined(separator: ","))

    // MARK: - Text search
    // The most flexible Places endpoint: any free-text query plus an
    // optional location bias. We use it because we have human-readable
    // venue names ("The Blue Note") rather than Place IDs.

    func searchText(
        query: String,
        locationBias: (latitude: Double, longitude: Double)? = nil,
        maxResults: Int = 5
    ) async throws -> [Place] {

        guard hasAPIKey else { throw PlacesError.missingAPIKey }

        // Build the URL: POST .../places:searchText
        let url = baseURL.appendingPathComponent("places:searchText")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,                    forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(Self.searchFieldMask,      forHTTPHeaderField: "X-Goog-FieldMask")

        // iOS-app API-key restrictions are enforced by THIS header on REST calls.
        // The Google Places SDK sets it automatically; raw URLSession must send it
        // itself. Without it, a key restricted to our bundle id is rejected with
        // "requests from this ios client application <empty> are blocked" — exactly
        // the 403 an iOS-restricted key produces here.
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }

        // Body is JSON. Built with a dictionary because the shape is
        // tiny — a custom Encodable struct would be overkill here.
        var body: [String: Any] = [
            "textQuery":       query,
            "maxResultCount":  maxResults
        ]
        if let bias = locationBias {
            // 5km circle around the bias point. Bias is a soft hint —
            // results outside the circle can still appear when relevant.
            body["locationBias"] = [
                "circle": [
                    "center": ["latitude": bias.latitude, "longitude": bias.longitude],
                    "radius": 5000.0
                ]
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Fire the request. URLSession.shared.data(for:) is the
        // async/await way to make a network call. It returns the
        // raw bytes + the HTTP response object.
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PlacesError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            // Surface Google's JSON error body VERBATIM — it names the exact
            // cause (API_KEY_INVALID, "Places API (New) … is disabled", "requests
            // from this ios client application … are blocked", billing). Without
            // it a 403 is unactionable guesswork. Flows up through the thrown
            // error's localizedDescription into VenueCache's DEBUG error log.
            let body = String(data: data, encoding: .utf8) ?? "<no response body>"
            throw PlacesError.httpError(http.statusCode, body: body)
        }

        // Decode the JSON into our PlacesSearchResponse → [Place].
        do {
            let decoded = try JSONDecoder().decode(PlacesSearchResponse.self, from: data)
            return decoded.places ?? []
        } catch {
            throw PlacesError.decodingError(error)
        }
    }

    // MARK: - Nearby search
    // Finds places of the given types within a radius of a point — the deck
    // source for Near You's "places" mode. Unlike searchText this takes a
    // locationRestriction (a hard circle, required by the endpoint) rather than a
    // soft bias, and an includedTypes whitelist so we only pull date-appropriate
    // categories (PlaceCuration owns that list + the finer ranking).

    func searchNearby(
        latitude: Double,
        longitude: Double,
        includedTypes: [String],
        radiusMeters: Double = 4000,
        maxResults: Int = 20
    ) async throws -> [Place] {

        guard hasAPIKey else { throw PlacesError.missingAPIKey }

        let url = baseURL.appendingPathComponent("places:searchNearby")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",   forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,               forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(Self.nearbyFieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        // Same iOS-bundle-restriction header as searchText (see note there).
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }

        let body: [String: Any] = [
            "includedTypes":   includedTypes,
            "maxResultCount":  maxResults,
            "rankPreference":  "POPULARITY",   // prominence-first — surfaces the spots people actually go to
            "locationRestriction": [
                "circle": [
                    "center": ["latitude": latitude, "longitude": longitude],
                    "radius": radiusMeters
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw PlacesError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no response body>"
            throw PlacesError.httpError(http.statusCode, body: body)
        }

        do {
            let decoded = try JSONDecoder().decode(PlacesSearchResponse.self, from: data)
            return decoded.places ?? []
        } catch {
            throw PlacesError.decodingError(error)
        }
    }

    // MARK: - Photo URLs
    // Google Places photos come as opaque "resource names" like
    // "places/{place_id}/photos/{photo_id}". We turn them into
    // fetchable image URLs by appending /media plus our API key.
    // Load these with BundledRemoteImage, NOT AsyncImage: the key is
    // iOS-bundle-restricted, so the GET must carry the
    // X-Ios-Bundle-Identifier header (AsyncImage can't) or Google 403s.

    func photoURL(name: String, maxWidthPx: Int = 800) -> URL? {
        guard hasAPIKey else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host   = "places.googleapis.com"
        components.path   = "/v1/\(name)/media"
        components.queryItems = [
            URLQueryItem(name: "maxWidthPx", value: "\(maxWidthPx)"),
            URLQueryItem(name: "key",        value: apiKey)
        ]
        return components.url
    }

    // MARK: - Errors

    enum PlacesError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int, body: String)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:        return "Google Places API key isn't configured."
            case .invalidResponse:      return "Couldn't read the Places response."
            case .httpError(let code, let body):
                return "Places API returned HTTP \(code): \(body)"
            case .decodingError(let e): return "Failed to decode Places response: \(e.localizedDescription)"
            }
        }
    }
}

// MARK: - Response shapes
// These mirror the JSON the Places API (New) returns. Optional
// everywhere because Google omits fields when there's no data, and
// we'd rather have `nil` than crashes.

private struct PlacesSearchResponse: Codable {
    let places: [Place]?
}

struct Place: Codable, Identifiable {
    let id: String
    let displayName: LocalizedText?
    let formattedAddress: String?
    let rating: Double?
    let userRatingCount: Int?
    let priceLevel: String?
    let photos: [Photo]?
    let regularOpeningHours: OpeningHours?
    let reviews: [Review]?
    let websiteUri: String?
    let googleMapsUri: String?
    let nationalPhoneNumber: String?

    // Nearby-search extras (nil on a searchText result — that mask omits them).
    // Drive PlaceCuration's category mapping, ranking, and open/closed gate.
    let primaryType: String?
    let types: [String]?
    let location: LatLng?
    let businessStatus: String?

    struct LocalizedText: Codable {
        let text: String
        let languageCode: String?
    }

    struct LatLng: Codable {
        let latitude: Double?
        let longitude: Double?
    }

    struct Photo: Codable {
        // The "resource name" — feed this back to PlacesService.photoURL
        // to get a URL you can render with AsyncImage.
        let name: String
        let widthPx: Int?
        let heightPx: Int?
    }

    struct OpeningHours: Codable {
        let openNow: Bool?
        let weekdayDescriptions: [String]?
    }

    struct Review: Codable {
        let rating: Double?
        let text: LocalizedText?
        let authorAttribution: AuthorAttribution?
    }

    struct AuthorAttribution: Codable {
        let displayName: String?
    }
}
