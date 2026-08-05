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
    private let cacheWriter = CacheWriteService()
    private var db: Firestore { Firestore.firestore() }

    /// Cached venues older than this are served stale, then refreshed in the
    /// background (stale-while-revalidate). ~7 days.
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// The places DECK pointer is served stale-while-revalidate after this long.
    /// Unlike events there's no date-TTL — venues don't expire by date; a deck
    /// just goes mildly stale as places open/close, so ~7 days is plenty.
    private static let placeDeckMaxAge: TimeInterval = 7 * 24 * 60 * 60

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

            var venue = CachedVenue.from(top)   // id nil, fetchedAt nil
            try await writeVenue(venue, placeId: top.id)             // venues/{placeId}
            try await writeQuery(key: key, placeId: top.id, rawQuery: query)  // venueQueries/{key}
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
            // .estimate so a just-written pointer's @ServerTimestamp resolvedAt
            // reads as ~now instead of nil in the pending-write window (else the
            // staleness check re-bills a Text Search on the next immediate open).
            return try snap.data(as: VenueQuery.self, with: .estimate)
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

    // MARK: - Firestore writes (via the cacheWrite Cloud Function)
    // Cache writes are Cloud-Function-only now (firestore.rules: write:false) — see
    // CacheWriteService. @DocumentID id stays nil so it isn't encoded (the doc ref
    // carries identity); the @ServerTimestamp freshness field is stripped client-
    // side and re-stamped server-side, so the stored doc is identical to the old
    // setData(from:) write and the `.estimate` staleness reads are unaffected.

    private func writeVenue(_ venue: CachedVenue, placeId: String) async throws {
        try await cacheWriter.write(venue, to: "venues", docId: placeId,
                                    serverTimestampFields: ["fetchedAt"])
    }

    private func writeQuery(key: String, placeId: String, rawQuery: String) async throws {
        let pointer = VenueQuery(id: nil, placeId: placeId, rawQuery: rawQuery, resolvedAt: nil)
        try await cacheWriter.write(pointer, to: "venueQueries", docId: key,
                                    serverTimestampFields: ["resolvedAt"])
    }

    // MARK: - Staleness

    private func isStale(_ venue: CachedVenue) -> Bool {
        guard let stamped = venue.fetchedAt?.dateValue() else { return true }
        return Date().timeIntervalSince(stamped) > Self.maxAge
    }

    // MARK: - Places deck (Near You "places" mode)
    // The venue twin of EventCache.deck: a read-through cache that turns a
    // location bucket into a curated, ranked list of date-appropriate venues.
    // REUSES the venues/{placeId} truth layer wholesale (loadVenue/writeVenue) —
    // a venue resolved for the deck is then free for detail enrichment, and vice
    // versa. The only new collection is the pointer: placeDeckQueries/{bucket} ->
    // ordered [placeId]. No date-TTL (venues don't expire by date); just SWR.

    /// The curated venue deck near `bucket` (the SHARED couple bucket when paired,
    /// so both partners get the same deck and their cardIds line up for matching).
    /// [] when nothing's near / cache + search both miss / no API key (caller
    /// falls back to SampleEvents).
    func deck(bucket: String) async -> [LocalEvent] {
        guard let center = LocationBucket.center(of: bucket) else { return [] }

        let pointer = await loadPlaceDeck(bucket)
        // A deck written by an OLDER curation version is stale by definition (its
        // categories/scoring predate a curation change) — treat it as a miss and
        // re-resolve synchronously, so e.g. the new Hikes & Trails venues show on
        // the FIRST open rather than after a background SWR pass.
        let versionCurrent = (pointer?.curationVersion ?? 0) == PlaceCuration.curationVersion

        if let pointer, versionCurrent {
            let venues = await loadVenuesInOrder(pointer.placeIds)
            let stale = isDeckStale(pointer)
            if !venues.isEmpty {
                if stale {
                    log("DECK HIT (stale) \(bucket) — revalidating in background")
                    revalidateDeck(bucket: bucket, center: center)
                } else {
                    log("DECK HIT (fresh) \(bucket) — 0 Places calls")
                }
                return venues.map { $0.asLocalEvent(firstPhotoURL: $0.photoURLStrings(using: places, limit: 1).first) }
            }
            // A FRESH but empty pointer is a recorded "nothing curated near here" —
            // respect it instead of re-searching every open. Only a STALE empty
            // pointer earns a fresh search.
            guard stale else { log("DECK EMPTY (fresh) \(bucket) — falling back"); return [] }
            log("DECK EMPTY (stale) \(bucket) — re-resolving")
        } else if pointer != nil {
            log("DECK curation v\(pointer?.curationVersion ?? 0)→v\(PlaceCuration.curationVersion) \(bucket) — re-resolving")
        } else {
            log("DECK MISS \(bucket) — no pointer")
        }

        let resolved = await resolveDeckAndCache(bucket: bucket, center: center)
        return resolved.map { $0.asLocalEvent(firstPhotoURL: $0.photoURLStrings(using: places, limit: 1).first) }
    }

    /// Fan out grouped Nearby searches (for category variety), curate + rank,
    /// write each venues/{placeId} + the ordered placeDeckQueries/{bucket} pointer,
    /// and return the cached deck. [] on no curated results / error.
    @discardableResult
    private func resolveDeckAndCache(bucket: String, center: (lat: Double, lng: Double)) async -> [CachedVenue] {
        var raw: [Place] = []
        for group in PlaceCuration.searchGroups {
            do {
                log("BILLED Nearby search \(bucket) \(group.types) r=\(Int(group.radiusMeters))m")
                let found = try await places.searchNearby(latitude: center.lat, longitude: center.lng,
                                                          includedTypes: group.types, radiusMeters: group.radiusMeters)
                raw.append(contentsOf: found)
            } catch {
                // One group failing (e.g. an unknown type) shouldn't sink the deck.
                log("DECK group error \(group.types): \(error.localizedDescription)")
            }
        }

        let ranked = PlaceCuration.rank(raw)
        guard !ranked.isEmpty else {
            log("DECK no curated venues for \(bucket)")
            try? await writePlaceDeck(key: bucket, placeIds: [])   // record empty so we don't re-search every open
            return []
        }

        var ordered: [CachedVenue] = []
        for item in ranked {
            let venue = CachedVenue.from(item.place, category: item.verdict.category)
            do {
                try await writeVenue(venue, placeId: item.place.id)   // reuse the venues/{placeId} truth layer
                ordered.append(venue)
            } catch {
                log("DECK write venue \(item.place.id): \(error.localizedDescription)")
            }
        }
        do { try await writePlaceDeck(key: bucket, placeIds: ordered.map(\.placeId)) }
        catch { log("DECK write pointer \(bucket): \(error.localizedDescription)") }
        log("DECK WROTE \(bucket) — \(ordered.count) venues")
        return ordered
    }

    private func revalidateDeck(bucket: String, center: (lat: Double, lng: Double)) {
        Task { _ = await resolveDeckAndCache(bucket: bucket, center: center) }
    }

    /// Load the pointer's venues IN ORDER, dropping any missing or old-schema doc
    /// (loadVenue already treats an out-of-date schema as a miss — those re-resolve
    /// on the next deck refresh).
    private func loadVenuesInOrder(_ placeIds: [String]) async -> [CachedVenue] {
        var result: [CachedVenue] = []
        for id in placeIds {
            if let venue = await loadVenue(id) { result.append(venue) }
        }
        return result
    }

    private func loadPlaceDeck(_ key: String) async -> PlaceDeckQuery? {
        do {
            let snap = try await db.collection("placeDeckQueries").document(key).getDocument()
            guard snap.exists else { return nil }
            // .estimate so a just-written pointer's @ServerTimestamp resolvedAt
            // reads as ~now (local estimate) instead of nil during the brief
            // pending-write window — otherwise isDeckStale treats nil as stale and
            // re-bills 4 Nearby searches on the very next open.
            return try snap.data(as: PlaceDeckQuery.self, with: .estimate)
        } catch {
            log("ERROR reading deck pointer \(key): \(error.localizedDescription)")
            return nil
        }
    }

    private func writePlaceDeck(key: String, placeIds: [String]) async throws {
        let pointer = PlaceDeckQuery(id: nil, placeIds: placeIds,
                                     curationVersion: PlaceCuration.curationVersion,
                                     resolvedAt: nil)
        try await cacheWriter.write(pointer, to: "placeDeckQueries", docId: key,
                                    serverTimestampFields: ["resolvedAt"])
    }

    private func isDeckStale(_ pointer: PlaceDeckQuery) -> Bool {
        guard let stamped = pointer.resolvedAt?.dateValue() else { return true }
        return Date().timeIntervalSince(stamped) > Self.placeDeckMaxAge
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
