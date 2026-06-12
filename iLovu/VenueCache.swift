// VenueCache.swift
// A read-through cache for Google Places data, sitting BETWEEN the app and
// PlacesService. Callers ask for a venue by free-text query (or by placeId) and
// get back a CachedVenue — without knowing or caring whether it came from
// Firestore (free) or a freshly-billed Places Text Search.
//
// Two collections back it (see VenueCacheModels):
//   venueQueries/{queryKey} -> placeId   (pointer cache: skip the billed search)
//   venues/{placeId}        -> CachedVenue (the source of truth)
//
// Flow for venue(forQuery:):
//   1. Build queryKey = normalized text + location bucket.
//   2. Look up the pointer. If it points at a venue doc we have:
//        - fresh (<7d)  -> return it. ZERO Places calls.
//        - stale (>=7d) -> return it NOW, refresh in the background (SWR).
//   3. Miss (no pointer, or orphan pointer) -> one billed Text Search, write
//      both docs, return fresh.
//
// venue(forId:) is a plain truth-layer read with no refresh: PlacesService has
// no "get place by id" (Place Details) endpoint, so a venue can only be
// refreshed via its original query. Future NearYou (Nearby Search) uses this to
// read venues it already resolved.
//
// Failures stay SILENT to callers (return nil, same as PlacesService today) but
// are printed under #if DEBUG so cache hits vs billed calls are visible in the
// console while build-testing.

import Foundation
import FirebaseFirestore

struct VenueCache {

    private let places = PlacesService()
    private var db: Firestore { Firestore.firestore() }

    /// Cached venues older than this are served stale, then refreshed in the
    /// background (stale-while-revalidate). ~7 days.
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Public: lookup by query

    /// The cached venue best matching `query`, biased to `locationBias`. Returns
    /// nil if nothing matches or the lookup fails (caller falls back to sample
    /// data, exactly as before). A first-ever query pays one billed Text Search;
    /// repeats — same query in the same ~1km area — are free Firestore reads.
    func venue(
        forQuery query: String,
        locationBias: (latitude: Double, longitude: Double)? = nil
    ) async -> CachedVenue? {

        let key = Self.queryKey(query: query, locationBias: locationBias)

        // 1. Pointer cache: query -> placeId.
        if let pointer = await loadVenueQuery(key) {
            // 2. Truth layer: placeId -> venue.
            if let cached = await loadVenue(pointer.placeId) {
                if isStale(cached) {
                    log("HIT (stale) \"\(query)\" -> \(pointer.placeId) — revalidating in background")
                    revalidate(query: query, key: key, locationBias: locationBias)
                } else {
                    log("HIT (fresh) \"\(query)\" -> \(pointer.placeId) — 0 Places calls")
                }
                return cached
            }
            // Orphan pointer (venue doc gone / unreadable / old schema) -> re-resolve.
            log("ORPHAN pointer \"\(query)\" -> \(pointer.placeId) — re-resolving")
        } else {
            log("MISS \"\(query)\" — no pointer")
        }

        // 3. Miss -> billed Text Search + write-through.
        return await resolveAndCache(query: query, key: key, locationBias: locationBias)
    }

    // MARK: - Public: lookup by id

    /// The cached venue for a known placeId, or nil if it isn't cached. Pure
    /// truth-layer read — no billing, and no refresh (there's no Place Details
    /// endpoint to refresh from; refresh happens via venue(forQuery:)).
    func venue(forId placeId: String) async -> CachedVenue? {
        if let cached = await loadVenue(placeId) {
            log("HIT (byId\(isStale(cached) ? ", stale" : "")) \(placeId) — 0 Places calls")
            return cached
        }
        log("MISS (byId) \(placeId) — not cached")
        return nil
    }

    // MARK: - Resolve + write-through (the billed path)

    /// Runs the one billed Text Search, writes venues/{placeId} and the
    /// venueQueries/{key} pointer, and returns the fresh venue. nil on no result
    /// or error (printed in DEBUG, silent to caller).
    @discardableResult
    private func resolveAndCache(
        query: String,
        key: String,
        locationBias: (latitude: Double, longitude: Double)?
    ) async -> CachedVenue? {
        do {
            log("BILLED Text Search for \"\(query)\"")
            let results = try await places.searchText(query: query, locationBias: locationBias)
            guard let top = results.first else {
                log("NO RESULT for \"\(query)\" — not cached")
                return nil
            }

            var venue = CachedVenue.from(top, using: places)   // id nil, fetchedAt nil
            try writeVenue(venue, placeId: top.id)             // venues/{placeId}
            try writeQuery(key: key, placeId: top.id, rawQuery: query)  // venueQueries/{key}
            log("WROTE cache \(top.id) for \"\(query)\"")

            venue.id = top.id   // for the returned copy only; never re-encoded
            return venue
        } catch {
            log("ERROR resolving \"\(query)\": \(error.localizedDescription)")
            return nil
        }
    }

    /// Fire-and-forget background refresh for a stale entry (SWR). The caller has
    /// already been handed the stale copy; this just overwrites the docs when the
    /// fresh data lands. Self is a value type, so the captured copy is safe.
    private func revalidate(
        query: String,
        key: String,
        locationBias: (latitude: Double, longitude: Double)?
    ) {
        Task {
            _ = await resolveAndCache(query: query, key: key, locationBias: locationBias)
        }
    }

    // MARK: - Firestore reads

    private func loadVenueQuery(_ key: String) async -> VenueQuery? {
        do {
            let snap = try await db.collection("venueQueries").document(key).getDocument()
            guard snap.exists else { return nil }
            return try snap.data(as: VenueQuery.self)
        } catch {
            log("ERROR reading pointer \(key): \(error.localizedDescription)")
            return nil
        }
    }

    private func loadVenue(_ placeId: String) async -> CachedVenue? {
        do {
            let snap = try await db.collection("venues").document(placeId).getDocument()
            guard snap.exists else { return nil }
            let venue = try snap.data(as: CachedVenue.self)
            // Treat an out-of-date schema as absent so it re-resolves cleanly.
            guard venue.schemaVersion >= CachedVenue.currentSchemaVersion else {
                log("STALE SCHEMA \(placeId) (v\(venue.schemaVersion)) — treating as miss")
                return nil
            }
            return venue
        } catch {
            log("ERROR reading venue \(placeId): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Firestore writes
    // Codable write-through. @DocumentID id stays nil so it isn't encoded (the
    // doc ref carries identity); @ServerTimestamp fetchedAt/resolvedAt encode to
    // a server-timestamp sentinel, so the server stamps the freshness time.

    private func writeVenue(_ venue: CachedVenue, placeId: String) throws {
        try db.collection("venues").document(placeId).setData(from: venue)
    }

    private func writeQuery(key: String, placeId: String, rawQuery: String) throws {
        let pointer = VenueQuery(id: nil, placeId: placeId, rawQuery: rawQuery, resolvedAt: nil)
        try db.collection("venueQueries").document(key).setData(from: pointer)
    }

    // MARK: - Staleness

    private func isStale(_ venue: CachedVenue) -> Bool {
        guard let stamped = venue.fetchedAt?.dateValue() else { return true }
        return Date().timeIntervalSince(stamped) > Self.maxAge
    }

    // MARK: - Query key
    // queryKey = slug(normalized text) + "@" + location bucket. The bucket is
    // lat/lng rounded to 2 decimals (~1km grid), so the SAME query in the SAME
    // ~1km area reuses the cache, but the same query in another city correctly
    // re-resolves (Text Search is location-biased). All chars produced here are
    // valid Firestore document-id characters.

    static func queryKey(
        query: String,
        locationBias: (latitude: Double, longitude: Double)?
    ) -> String {
        let slug = query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        let bucket: String
        if let bias = locationBias {
            bucket = String(format: "%.2f,%.2f", bias.latitude, bias.longitude)
        } else {
            bucket = "none"
        }
        return "\(slug)@\(bucket)"
    }

    // MARK: - Debug logging

    private func log(_ message: String) {
        #if DEBUG
        print("🗂️ VenueCache: \(message)")
        #endif
    }
}
