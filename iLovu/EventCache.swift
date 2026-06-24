// EventCache.swift
// A read-through cache for Ticketmaster events, sitting BETWEEN the app and
// TicketmasterService — the events twin of VenueCache. Callers ask for the deck
// near a location bucket (or one event by id) and get back LocalEvents, without
// knowing or caring whether the data came from Firestore (free) or a freshly
// rate-limited Discovery search.
//
// Two collections back it (see EventCacheModels):
//   eventQueries/{queryKey} -> [eventId]    (pointer cache: skip the billed search)
//   events/{eventId}        -> CachedEvent  (the source of truth)
//
// Flow for deck(bucket:):
//   1. queryKey = location bucket + ISO-week window.
//   2. Look up the pointer; load its events, DROPPING any past one (date-TTL).
//        - fresh (<24h)  -> return them. ZERO Ticketmaster calls.
//        - stale (>=24h) -> return them NOW, refresh in background (SWR).
//   3. Miss / empty after expiry -> one rate-limited search, curate + rank,
//      write the event docs + the ordered pointer, return.
//
// THE DATE-TTL (the difference from venues): events don't go stale at a fixed
// age — they EXPIRE at their own date. Three layers enforce it:
//   • read-time filter (authoritative): never return an event past its expireAt;
//   • SWR (~24h): the pointer LIST refreshes daily, re-curating + dropping passed
//     events from the deck order;
//   • expireAt + a Firestore native TTL policy on events.expireAt: auto-purge of
//     past docs, zero maintenance (enable the policy once in the console).
//
// Deck order is cached so BOTH partners swipe the same sequence — that shared
// cardId space is what makes two-player event matching work. Failures stay
// SILENT to callers (return []/nil, caller falls back to SampleEvents) but print
// under #if DEBUG so cache hits vs billed calls are visible while build-testing.

import Foundation
import FirebaseFirestore

struct EventCache {

    private let service = TicketmasterService()
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Public: the deck for a location bucket

    /// The curated event deck near `bucket` (a "%.2f,%.2f" location bucket — the
    /// SHARED one stored on the couple doc, so both partners get the same deck).
    /// Empty when nothing's near, the cache + search both miss, or there's no API
    /// key (caller falls back to SampleEvents). `now` is injected for testability.
    func deck(bucket: String, now: Date = Date()) async -> [LocalEvent] {
        guard let center = Self.center(fromBucket: bucket) else { return [] }
        let key = Self.queryKey(bucket: bucket, now: now)

        if let pointer = await loadQuery(key) {
            let events = await loadEvents(pointer.eventIds, now: now)   // ordered, unexpired
            let stale = isStale(pointer, now: now)

            if !events.isEmpty {
                if stale {
                    log("HIT (stale) deck \(key) — revalidating in background")
                    revalidate(key: key, center: center)
                } else {
                    log("HIT (fresh) deck \(key) — 0 Ticketmaster calls")
                }
                return events.map { $0.asLocalEvent() }
            }

            // Pointer exists but yields nothing right now. If it's still FRESH,
            // that's a recorded "nothing date-appropriate near here this week" —
            // respect it (fall back to samples) instead of re-searching on every
            // open. Only a STALE empty pointer earns a fresh search.
            guard stale else {
                log("EMPTY (fresh) deck \(key) — 0 Ticketmaster calls, falling back")
                return []
            }
            log("EMPTY (stale) deck \(key) — re-resolving")
        } else {
            log("MISS deck \(key) — no pointer")
        }

        let resolved = await resolveAndCache(key: key, center: center, now: now)
        return resolved.map { $0.asLocalEvent() }
    }

    // MARK: - Public: one event by id (match reconstruction)

    /// The cached event for a known Ticketmaster eventId, or nil if it isn't
    /// cached. Pure truth-layer read — no billing, no refresh, and deliberately
    /// NOT date-filtered: this is how MainTabView rebuilds a matched event for the
    /// partner who didn't swipe, and a just-passed match must still reconstruct.
    func event(forId eventId: String) async -> LocalEvent? {
        guard let cached = await loadEvent(eventId) else {
            log("MISS (byId) \(eventId) — not cached")
            return nil
        }
        log("HIT (byId) \(eventId) — 0 Ticketmaster calls")
        return cached.asLocalEvent()
    }

    // MARK: - Resolve + write-through (the billed path)

    /// Runs one rate-limited Discovery search, curates + ranks the results,
    /// writes each events/{eventId} and the ordered eventQueries/{key} pointer,
    /// and returns the cached deck. [] on no results or error (printed in DEBUG,
    /// silent to caller).
    @discardableResult
    private func resolveAndCache(key: String, center: (lat: Double, lng: Double), now: Date) async -> [CachedEvent] {
        do {
            log("BILLED Ticketmaster search for \(key)")
            let raw = try await service.searchEvents(near: center.lat, longitude: center.lng, now: now)

            // Parse each event's start date; drop anything undated or already past
            // BEFORE curation, so the pointer only ever holds upcoming events.
            let upcoming: [(event: TicketmasterEvent, start: Date)] = raw.compactMap { event in
                guard let start = Self.parseStart(event), start.addingTimeInterval(TicketmasterConfig.expiryGrace) > now
                else { return nil }
                return (event, start)
            }

            let ranked = EventCuration.rank(upcoming)
            guard !ranked.isEmpty else {
                log("NO date-appropriate events for \(key)")
                // Still write an empty pointer so we don't re-search every open
                // within the window; SWR will retry it after queryMaxAge.
                try writeQuery(key: key, eventIds: [])
                return []
            }

            // Write each truth doc, collecting ids in ranked order for the pointer.
            var ordered: [CachedEvent] = []
            for item in ranked {
                let cached = CachedEvent.from(item.event, start: item.start, verdict: item.verdict)
                try writeEvent(cached)
                ordered.append(cached)
            }
            try writeQuery(key: key, eventIds: ordered.map(\.eventId))
            log("WROTE deck \(key) — \(ordered.count) events")
            return ordered
        } catch {
            log("ERROR resolving \(key): \(error.localizedDescription)")
            return []
        }
    }

    /// Fire-and-forget background refresh for a stale deck (SWR). The caller
    /// already got the stale list; this overwrites the docs + pointer when fresh
    /// data lands. Self is a value type, so the captured copy is safe.
    private func revalidate(key: String, center: (lat: Double, lng: Double)) {
        Task { _ = await resolveAndCache(key: key, center: center, now: Date()) }
    }

    // MARK: - Firestore reads

    private func loadQuery(_ key: String) async -> EventQuery? {
        do {
            let snap = try await db.collection("eventQueries").document(key).getDocument()
            guard snap.exists else { return nil }
            return try snap.data(as: EventQuery.self)
        } catch {
            log("ERROR reading pointer \(key): \(error.localizedDescription)")
            return nil
        }
    }

    /// Loads the pointer's events IN ORDER, dropping any that are missing, an old
    /// schema, or PAST (the read-time date-TTL — the authoritative expiry guard).
    private func loadEvents(_ eventIds: [String], now: Date) async -> [CachedEvent] {
        var result: [CachedEvent] = []
        for id in eventIds {
            guard let cached = await loadEvent(id) else { continue }
            if cached.expireAt.dateValue() < now { continue }   // past its date — never serve
            result.append(cached)
        }
        return result
    }

    private func loadEvent(_ eventId: String) async -> CachedEvent? {
        do {
            let snap = try await db.collection("events").document(eventId).getDocument()
            guard snap.exists else { return nil }
            let event = try snap.data(as: CachedEvent.self)
            guard event.schemaVersion >= CachedEvent.currentSchemaVersion else {
                log("STALE SCHEMA \(eventId) (v\(event.schemaVersion)) — treating as miss")
                return nil
            }
            return event
        } catch {
            log("ERROR reading event \(eventId): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Firestore writes
    // Codable write-through, same rules as VenueCache: @DocumentID id stays nil
    // (the doc ref carries identity); @ServerTimestamp fetchedAt/resolvedAt encode
    // to a server sentinel so the server stamps freshness.

    private func writeEvent(_ event: CachedEvent) throws {
        try db.collection("events").document(event.eventId).setData(from: event)
    }

    private func writeQuery(key: String, eventIds: [String]) throws {
        let pointer = EventQuery(id: nil, eventIds: eventIds, resolvedAt: nil)
        try db.collection("eventQueries").document(key).setData(from: pointer)
    }

    // MARK: - Staleness (pointer LIST, not individual events)

    private func isStale(_ query: EventQuery, now: Date) -> Bool {
        guard let stamped = query.resolvedAt?.dateValue() else { return true }
        return now.timeIntervalSince(stamped) > TicketmasterConfig.queryMaxAge
    }

    // MARK: - Start-date parsing
    // dateTime is a full UTC instant (preferred). Fall back to localDate(+
    // localTime); a date with no time is treated as that day at 19:00 local — a
    // sensible "evening event" default that still gives the TTL a concrete time.

    static func parseStart(_ event: TicketmasterEvent) -> Date? {
        guard let start = event.dates?.start else { return nil }

        if let dt = start.dateTime {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: dt) { return date }
        }

        guard let day = start.localDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let time = start.localTime {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let date = formatter.date(from: "\(day) \(time)") { return date }
        }
        formatter.dateFormat = "yyyy-MM-dd"
        guard let midnight = formatter.date(from: day) else { return nil }
        return Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: midnight) ?? midnight
    }

    // MARK: - Query key + location bucket
    // queryKey = "{bucket}@{ISO-week}". The bucket is lat/lng to 2 decimals (~1km
    // grid) — the SAME bucket stored on the couple doc, so both partners build the
    // SAME key and share one deck. ISO-week makes the key stable within a calendar
    // week and roll forward weekly. All chars are valid Firestore doc-id chars.

    static func queryKey(bucket: String, now: Date = Date()) -> String {
        "\(bucket)@\(isoWeek(now))"
    }

    /// The ~1km location bucket for a coordinate. Delegates to the shared
    /// LocationBucket so events + places + the couple doc all grid identically.
    static func locationBucket(latitude: Double, longitude: Double) -> String {
        LocationBucket.of(latitude: latitude, longitude: longitude)
    }

    /// Parse a "%.2f,%.2f" bucket back to its centre for the Ticketmaster search.
    /// The search radius (25km) comfortably absorbs the 2-decimal rounding.
    static func center(fromBucket bucket: String) -> (lat: Double, lng: Double)? {
        LocationBucket.center(of: bucket)
    }

    private static func isoWeek(_ date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    // MARK: - Debug logging

    private func log(_ message: String) {
        #if DEBUG
        print("🎟️ EventCache: \(message)")
        #endif
    }
}
