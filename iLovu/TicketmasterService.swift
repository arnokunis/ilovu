// TicketmasterService.swift
// Talks to the Ticketmaster Discovery API (v2). The events analogue of
// PlacesService: one struct, key-gated, that turns a location + date window
// into raw event results. Everything above it (EventCache, EventCuration)
// treats this as the single billed/rate-limited edge — fetch once, cache, and
// both partners + the card and detail screens read from the cache.
//
//   • searchEvents(near:) — find upcoming events around a point
//
// Like PlacesService this reads like a first networking class on purpose:
// URLSession + async + Codable, no extra packages. The API key is sent as the
// `apikey` QUERY parameter (Ticketmaster's scheme — NOT a header like Places),
// and the location is sent as a `geoPoint` geohash + `radius`, the Discovery
// API's recommended geo search (the older `latlong` param is deprecated).

import Foundation

struct TicketmasterService {

    // MARK: - Configuration

    /// True only when Secrets.swift has a real Ticketmaster key. Callers
    /// (EventCache) check this before any fetch — when false the Near You deck
    /// silently keeps using SampleEvents, same contract as PlacesService.
    var hasAPIKey: Bool { !Secrets.ticketmasterAPIKey.isEmpty }

    private var apiKey: String { Secrets.ticketmasterAPIKey }

    // MARK: - Search

    /// Upcoming, date-appropriate-ish events around (`latitude`,`longitude`).
    /// Returns the RAW Ticketmaster events (sorted soonest-first); curation /
    /// hard exclusions happen one layer up in EventCuration so this stays a thin
    /// transport. `now` is injected so the date window is testable and so the
    /// caller controls the clock.
    ///
    /// API-side curation: we request only the romance-leaning segments (Music,
    /// Arts & Theatre, Film, Miscellaneous) — which EXCLUDES the Sports segment
    /// at the source, so we never pay bandwidth for a stadium fixture. The finer
    /// "jazz club not monster truck" ranking is EventCuration's job.
    func searchEvents(
        near latitude: Double,
        longitude: Double,
        now: Date = Date()
    ) async throws -> [TicketmasterEvent] {

        guard hasAPIKey else { throw EventsError.missingAPIKey }

        guard var components = URLComponents(string: TicketmasterConfig.eventsSearchURL) else {
            throw EventsError.invalidResponse
        }

        let window = now.addingTimeInterval(Double(TicketmasterConfig.searchWindowDays) * 24 * 60 * 60)
        let geohash = Geohash.encode(
            latitude: latitude,
            longitude: longitude,
            precision: TicketmasterConfig.geohashPrecision
        )

        var items: [URLQueryItem] = [
            URLQueryItem(name: "apikey",        value: apiKey),
            URLQueryItem(name: "geoPoint",      value: geohash),
            URLQueryItem(name: "radius",        value: "\(TicketmasterConfig.searchRadiusKm)"),
            URLQueryItem(name: "unit",          value: "km"),
            URLQueryItem(name: "size",          value: "\(TicketmasterConfig.maxSearchResults)"),
            URLQueryItem(name: "sort",          value: "date,asc"),
            // Real start times only — we need a concrete date for the date-TTL.
            URLQueryItem(name: "includeTBA",    value: "no"),
            URLQueryItem(name: "includeTBD",    value: "no"),
            URLQueryItem(name: "startDateTime", value: Self.iso8601UTC(now)),
            URLQueryItem(name: "endDateTime",   value: Self.iso8601UTC(window))
        ]
        // Include filters: one item per wanted segment. Requesting these by name
        // omits the Sports segment entirely (no exclude operator exists in the
        // Discovery API, so we enumerate the includes).
        for segment in ["Music", "Arts & Theatre", "Film", "Miscellaneous"] {
            items.append(URLQueryItem(name: "segmentName", value: segment))
        }
        components.queryItems = items

        guard let url = components.url else { throw EventsError.invalidResponse }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else { throw EventsError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw EventsError.httpError(http.statusCode) }

        do {
            let decoded = try JSONDecoder().decode(EventsResponse.self, from: data)
            // `_embedded` is absent when there are zero results — that's a valid
            // empty answer, not an error.
            return decoded.embedded?.events ?? []
        } catch {
            throw EventsError.decodingError(error)
        }
    }

    // MARK: - Date formatting
    // Ticketmaster wants ISO8601 in UTC with a trailing Z and no fractional
    // seconds, e.g. 2026-06-24T00:00:00Z.

    private static func iso8601UTC(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    // MARK: - Errors

    enum EventsError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:        return "Ticketmaster API key isn't configured."
            case .invalidResponse:      return "Couldn't read the Ticketmaster response."
            case .httpError(let code):  return "Ticketmaster API returned HTTP \(code)."
            case .decodingError(let e): return "Failed to decode Ticketmaster response: \(e.localizedDescription)"
            }
        }
    }
}

// MARK: - Response shapes
// Mirror the slice of the Discovery API JSON we actually use. Optional almost
// everywhere — Ticketmaster omits fields freely and we'd rather get nil than
// crash. Names map JSON keys via CodingKeys where they differ (`_embedded`).

private struct EventsResponse: Codable {
    let embedded: Embedded?
    enum CodingKeys: String, CodingKey { case embedded = "_embedded" }

    struct Embedded: Codable {
        let events: [TicketmasterEvent]?
    }
}

/// One raw Discovery API event. Flattened into CachedEvent by EventCacheModels;
/// nothing else in the app sees this shape.
struct TicketmasterEvent: Codable, Identifiable {
    let id: String
    let name: String
    /// Public event page — KEY-FREE. This is the base URL EventLinkBuilder wraps
    /// for affiliate tracking at display time (never stored with a wrapper).
    let url: String?
    let info: String?
    let pleaseNote: String?
    let images: [EventImage]?
    let dates: Dates?
    let classifications: [Classification]?
    let priceRanges: [PriceRange]?
    let embedded: Embedded?

    enum CodingKeys: String, CodingKey {
        case id, name, url, info, pleaseNote, images, dates, classifications, priceRanges
        case embedded = "_embedded"
    }

    struct EventImage: Codable {
        let url: String
        let width: Int?
        let height: Int?
        let ratio: String?
    }

    struct Dates: Codable {
        let start: Start?
        struct Start: Codable {
            /// Full UTC instant when present (preferred for the date-TTL).
            let dateTime: String?
            /// Fallbacks when only a calendar day/time is published.
            let localDate: String?
            let localTime: String?
        }
    }

    struct Classification: Codable {
        let segment: Named?
        let genre: Named?
        let subGenre: Named?
        struct Named: Codable { let name: String? }
    }

    struct PriceRange: Codable {
        let currency: String?
        let min: Double?
        let max: Double?
    }

    struct Embedded: Codable {
        let venues: [Venue]?
        enum CodingKeys: String, CodingKey { case venues }

        struct Venue: Codable {
            let name: String?
            let address: Address?
            let city: City?
            let location: Location?
            struct Address: Codable { let line1: String? }
            struct City: Codable { let name: String? }
            struct Location: Codable {
                // Ticketmaster sends these as strings.
                let latitude: String?
                let longitude: String?
            }
        }
    }
}

// MARK: - Geohash
// Minimal geohash encoder for the Discovery API `geoPoint` parameter. Standard
// algorithm (interleave lat/lng bit-bisections, base32). Self-contained so the
// service needs no extra dependency. Deterministic — the same coordinate always
// yields the same hash, which matters: it keeps a bucket's search stable.

enum Geohash {

    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int) -> String {
        var latInterval = (-90.0, 90.0)
        var lonInterval = (-180.0, 180.0)
        var hash = ""
        var isEven = true
        var bit = 0
        var ch = 0

        while hash.count < precision {
            if isEven {
                let mid = (lonInterval.0 + lonInterval.1) / 2
                if longitude >= mid { ch |= (1 << (4 - bit)); lonInterval.0 = mid }
                else { lonInterval.1 = mid }
            } else {
                let mid = (latInterval.0 + latInterval.1) / 2
                if latitude >= mid { ch |= (1 << (4 - bit)); latInterval.0 = mid }
                else { latInterval.1 = mid }
            }
            isEven.toggle()
            if bit < 4 {
                bit += 1
            } else {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        return hash
    }
}
