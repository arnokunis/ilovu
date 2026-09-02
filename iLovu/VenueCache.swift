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

    /// How many document ids fit in one `whereField(FieldPath.documentID(), in:)`
    /// query — Firestore's hard limit for an `in` filter. Raising it past 30 makes
    /// the query throw, so chunk to it rather than tuning it.
    private static let idQueryChunkSize = 30

    /// Ceiling on simultaneous cacheWrite Cloud Function calls when caching a
    /// freshly-resolved deck. The functions run with `maxInstances: 10`, so pushing
    /// much beyond this just queues server-side while burning client sockets.
    private static let maxConcurrentWrites = 8

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

    /// writeVenue with the deck's error policy folded in: returns the placeId on
    /// success, nil on failure (logged). Lets the bounded write group collect
    /// successes without a throwing task, keeping "one bad venue doesn't sink the
    /// deck" exactly as it behaved when the writes ran in a serial loop.
    private func tryWriteVenue(_ venue: CachedVenue, placeId: String) async -> String? {
        do {
            try await writeVenue(venue, placeId: placeId)   // reuse the venues/{placeId} truth layer
            return placeId
        } catch {
            log("DECK write venue \(placeId): \(error.localizedDescription)")
            return nil
        }
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

        // Cards come back as soon as the SEARCHES finish. Persisting them is a
        // separate, unawaited phase — see persistDeck for why that's safe.
        let resolved = await searchAndRank(bucket: bucket, center: center)
        persistInBackground(bucket: bucket, venues: resolved)
        return resolved.map { $0.asLocalEvent(firstPhotoURL: $0.photoURLStrings(using: places, limit: 1).first) }
    }

    /// Fan out grouped Nearby searches (for category variety), then curate + rank
    /// into the deck order. Pure network + in-memory work: NOTHING here touches
    /// Firestore, so it's everything the UI needs to draw a card and nothing it
    /// doesn't. [] on no curated results / error.
    private func searchAndRank(bucket: String, center: (lat: Double, lng: Double)) async -> [CachedVenue] {
        // CONCURRENT, not one search after another. There are now seventeen search
        // groups (food alone is split ten ways), so running them in sequence cost
        // seventeen stacked network round trips on a cold bucket. Fanning them out
        // makes the whole search phase cost about as long as its slowest single
        // group. Billing is unchanged — same seventeen calls, just not queued.
        //
        // Order of arrival doesn't matter: rank() dedupes by placeId and sorts, and
        // the resulting order is written ONCE to placeDeckQueries and then read by
        // BOTH partners, so the shared deck sequence comes from the stored pointer
        // rather than from whichever search happened to return first.
        var raw: [Place] = []
        await withTaskGroup(of: [Place].self) { taskGroup in
            for group in PlaceCuration.searchGroups {
                taskGroup.addTask {
                    do {
                        self.log("BILLED Nearby search \(bucket) \(group.types) r=\(Int(group.radiusMeters))m")
                        return try await self.places.searchNearby(latitude: center.lat, longitude: center.lng,
                                                                  includedTypes: group.types, radiusMeters: group.radiusMeters)
                    } catch {
                        // One group failing (e.g. an unknown type) shouldn't sink the deck.
                        self.log("DECK group error \(group.types): \(error.localizedDescription)")
                        return []
                    }
                }
            }
            for await found in taskGroup { raw.append(contentsOf: found) }
        }

        let ranked = PlaceCuration.rank(raw)
        log("DECK resolved \(bucket) — \(ranked.count) curated venues")
        return ranked.map { CachedVenue.from($0.place, category: $0.verdict.category) }
    }

    /// Cache a freshly-resolved deck WITHOUT making anyone wait for it: each venue
    /// doc, then the ordered pointer.
    ///
    /// Unawaited on the read path on purpose. By the time this is called the cards
    /// are already in memory and on screen — these writes exist only to make the
    /// NEXT open (and the partner's first open) a cache hit. Blocking the deck on
    /// them meant staring at a spinner through a hundred-plus Cloud Function round
    /// trips for zero visible benefit.
    ///
    /// The pointer is written LAST, and that ordering is what makes an interrupted
    /// run safe: no pointer means the next open is a clean MISS and re-resolves. If
    /// the pointer were written first, an interruption would leave it referencing
    /// venue docs that were never written, and loadVenuesInOrder would then serve a
    /// silently truncated deck as a HIT.
    private func persistDeck(bucket: String, venues: [CachedVenue]) async {
        guard !venues.isEmpty else {
            log("DECK no curated venues for \(bucket)")
            try? await writePlaceDeck(key: bucket, placeIds: [])   // record empty so we don't re-search every open
            return
        }

        // Write the venues concurrently but BOUNDED. Each write is a cacheWrite
        // Cloud Function round trip (cache writes are CF-only), and a curated deck
        // is now well over a hundred venues. Bounded rather than unbounded so a big
        // deck doesn't fire a hundred simultaneous CF invocations, which would
        // fight `maxInstances: 10` and just queue anyway.
        let pending = venues.map { (venue: $0, id: $0.placeId) }
        var writtenIds = Set<String>()

        await withTaskGroup(of: String?.self) { group in
            var next = 0
            while next < min(Self.maxConcurrentWrites, pending.count) {
                let item = pending[next]
                group.addTask { await self.tryWriteVenue(item.venue, placeId: item.id) }
                next += 1
            }
            // Keep the window full: each completion starts the next write.
            while let finished = await group.next() {
                if let id = finished { writtenIds.insert(id) }
                if next < pending.count {
                    let item = pending[next]
                    group.addTask { await self.tryWriteVenue(item.venue, placeId: item.id) }
                    next += 1
                }
            }
        }

        // Rebuild in RANKED order — writes finish out of order, and this ordering is
        // what both partners then swipe (see loadVenuesInOrder).
        let orderedIds = pending.filter { writtenIds.contains($0.id) }.map(\.id)
        do { try await writePlaceDeck(key: bucket, placeIds: orderedIds) }
        catch { log("DECK write pointer \(bucket): \(error.localizedDescription)") }
        log("DECK WROTE \(bucket) — \(orderedIds.count) venues")
    }

    /// Kick off persistence without joining it to the caller's lifetime. Deliberately
    /// an unstructured Task: the caller is a view load that finishes the moment the
    /// cards are handed over, and cancelling the cache write along with it would
    /// leave the bucket uncached and re-search on every single open.
    private func persistInBackground(bucket: String, venues: [CachedVenue]) {
        Task { await persistDeck(bucket: bucket, venues: venues) }
    }

    private func revalidateDeck(bucket: String, center: (lat: Double, lng: Double)) {
        Task {
            let venues = await searchAndRank(bucket: bucket, center: center)
            await persistDeck(bucket: bucket, venues: venues)
        }
    }

    /// Load the pointer's venues IN ORDER, dropping any missing or old-schema doc
    /// (loadVenue already treats an out-of-date schema as a miss — those re-resolve
    /// on the next deck refresh).
    ///
    /// BATCHED, not one id at a time. This is the WARM path — it runs on every
    /// Near You open that hits a cached deck — and a deck is now well past a
    /// hundred placeIds (ten split food searches). One getDocument() per id meant
    /// that many SEQUENTIAL round trips before the first card could render, which
    /// is what made a cached open take ~30s. Firestore takes 30 ids per
    /// documentID() `in` query and the chunks run concurrently, so the same load
    /// costs roughly ONE round trip. Identical billing (Firestore charges per
    /// document read either way) — this is pure latency.
    private func loadVenuesInOrder(_ placeIds: [String]) async -> [CachedVenue] {
        guard !placeIds.isEmpty else { return [] }

        let chunks = stride(from: 0, to: placeIds.count, by: Self.idQueryChunkSize).map {
            Array(placeIds[$0 ..< min($0 + Self.idQueryChunkSize, placeIds.count)])
        }

        var byId: [String: CachedVenue] = [:]
        await withTaskGroup(of: [(String, CachedVenue)].self) { group in
            for chunk in chunks {
                group.addTask { await self.loadVenues(ids: chunk) }
            }
            for await pairs in group {
                for (id, venue) in pairs { byId[id] = venue }
            }
        }

        // Reorder to the pointer's sequence. An `in` query returns documents in
        // arbitrary order, and deck ORDER is precisely what keeps both partners
        // swiping the same cards in the same places so their cardIds line up for
        // matching — so this reorder is load-bearing, not cosmetic.
        return placeIds.compactMap { byId[$0] }
    }

    /// One chunk of up to `idQueryChunkSize` ids in a single query, returned keyed
    /// by document id. Same per-document semantics as loadVenue: a missing doc, an
    /// undecodable doc, or one on an out-of-date schema is simply absent from the
    /// result (and so re-resolves on the next deck refresh).
    private func loadVenues(ids: [String]) async -> [(String, CachedVenue)] {
        do {
            let snap = try await db.collection("venues")
                .whereField(FieldPath.documentID(), in: ids)
                .getDocuments()
            return snap.documents.compactMap { doc in
                guard let venue = try? doc.data(as: CachedVenue.self) else { return nil }
                guard venue.schemaVersion >= CachedVenue.currentSchemaVersion else {
                    log("STALE SCHEMA \(doc.documentID) (v\(venue.schemaVersion)) — treating as miss")
                    return nil
                }
                return (doc.documentID, venue)
            }
        } catch {
            log("ERROR batch-reading \(ids.count) venues: \(error.localizedDescription)")
            return []
        }
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

        // Route through LocationBucket rather than formatting here. This line used
        // its own "%.2f,%.2f" until 2026-09-02 — a second, divergent definition of
        // the grid, which is precisely what LocationBucket exists to prevent. When
        // the shared grid was coarsened to ~11km this would have silently kept
        // keying venue queries at ~1km, so the two caches would have disagreed.
        let bucket: String
        if let bias = locationBias {
            bucket = LocationBucket.of(latitude: bias.latitude, longitude: bias.longitude)
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
