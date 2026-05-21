// PlacesService.swift
// Talks to the Google Places API (New). Used by EventDetailView to
// fetch real photos, ratings, reviews, hours, and address for the
// place that matches a sample event's title + venue. The whole
// service is one struct with two public methods:
//
//   • searchText(query:)    — find places matching free text
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
        "places.googleMapsUri"
    ].joined(separator: ",")

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
            throw PlacesError.httpError(http.statusCode)
        }

        // Decode the JSON into our SearchTextResponse → [Place].
        do {
            let decoded = try JSONDecoder().decode(SearchTextResponse.self, from: data)
            return decoded.places ?? []
        } catch {
            throw PlacesError.decodingError(error)
        }
    }

    // MARK: - Photo URLs
    // Google Places photos come as opaque "resource names" like
    // "places/{place_id}/photos/{photo_id}". We turn them into
    // fetchable image URLs by appending /media plus our API key.
    // SwiftUI's AsyncImage can load these directly.

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
        case httpError(Int)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:        return "Google Places API key isn't configured."
            case .invalidResponse:      return "Couldn't read the Places response."
            case .httpError(let code):  return "Places API returned HTTP \(code)."
            case .decodingError(let e): return "Failed to decode Places response: \(e.localizedDescription)"
            }
        }
    }
}

// MARK: - Response shapes
// These mirror the JSON the Places API (New) returns. Optional
// everywhere because Google omits fields when there's no data, and
// we'd rather have `nil` than crashes.

private struct SearchTextResponse: Codable {
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

    struct LocalizedText: Codable {
        let text: String
        let languageCode: String?
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
