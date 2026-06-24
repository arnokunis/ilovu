// EventCacheModels.swift
// The Firestore-side shapes for the EVENT cache. Two collections, mirroring the
// venue cache exactly (see VenueCacheModels):
//
//   events/{eventId}        -> CachedEvent  (truth: one doc per Ticketmaster event)
//   eventQueries/{queryKey} -> EventQuery   (pointer cache: location bucket + date
//                                            window -> an ORDERED list of eventIds)
//
// The one shape difference from venues: an EventQuery points at a LIST of
// eventIds (a curated, ranked deck), not a single id — a "near you" search
// returns many events, and the cached order is what makes BOTH partners swipe
// the SAME deck (so their cardIds line up for matching).
//
// CachedEvent is a flattened mirror of TicketmasterEvent that feeds straight
// into LocalEvent via asLocalEvent(), so the swipe deck + detail screen never
// know the data came from cache. Convention matches CachedVenue / Couple:
// @DocumentID for the id, @ServerTimestamp for server times, read via .data(as:).
//
// KEY-FREE (the Places lesson): we store imageURLs (plain Ticketmaster CDN URLs,
// no key) and the key-free `ticketURLBase`. The affiliate wrapper is applied at
// DISPLAY time by EventLinkBuilder, never baked into a stored doc — so flipping
// the affiliate on needs no re-cache.

import Foundation
import FirebaseFirestore

// MARK: - events/{eventId}

struct CachedEvent: Codable, Identifiable {

    /// Ticketmaster event id, mirrored from the doc id. Populated on read, nil on
    /// write (the doc ref carries identity; `eventId` below holds it as a real
    /// field). Same rule as CachedVenue.id.
    @DocumentID var id: String?

    /// Same value as the doc id, as a plain queryable field (survives encoding).
    /// THIS is the stable cross-device match key — LocalEvent.cardId is set from it.
    var eventId: String

    var name: String
    var info: String?

    var venueName: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?

    /// The event's real start instant. This drives the date-TTL: an event is
    /// served only while `startDate` (+ grace) is still in the future. Unlike
    /// venues' single 7-day age, the TTL here is per-event — its own date.
    var startDate: Timestamp

    var priceMin: Double?
    var priceMax: Double?
    var currency: String?

    /// Raw Ticketmaster classification, kept for debugging / future re-curation.
    var segment: String?
    var genre: String?

    /// The deck category EventCuration mapped this onto (LocalEvent.Category
    /// rawValue) and its date-appropriateness score (higher = floats up the deck).
    var category: String
    var dateScore: Int

    /// Ticketmaster CDN image URLs — key-free, safe to store and render directly.
    var imageURLs: [String]

    /// Public Ticketmaster event-page URL — KEY-FREE base. EventLinkBuilder wraps
    /// it with the Impact affiliate id at display time; never stored wrapped.
    var ticketURLBase: String?

    /// = startDate (+ grace). Powers a Firestore native TTL policy on this field
    /// (enable it in the console on events.expireAt) so past events auto-delete
    /// with zero maintenance. Read-time filtering in EventCache is the immediate
    /// guarantee; this is the housekeeping purge.
    var expireAt: Timestamp

    /// Server time this doc was last written. With queryMaxAge it drives the
    /// pointer-list staleness check (stale-while-revalidate).
    @ServerTimestamp var fetchedAt: Timestamp?

    /// Bumped when this struct's shape changes — an older doc is treated as a miss
    /// so it transparently re-fetches instead of decoding stale data.
    var schemaVersion: Int

    static let currentSchemaVersion = 1
}

// MARK: - TicketmasterEvent -> CachedEvent

extension CachedEvent {

    /// Builds a cache doc from a raw Ticketmaster event plus its already-parsed
    /// start date and curation verdict (so we don't re-derive the mapping). `id`
    /// and `fetchedAt` are left nil on purpose — the doc ref supplies identity,
    /// the server stamps the time. Only key-free image / ticket URLs are stored.
    static func from(
        _ event: TicketmasterEvent,
        start: Date,
        verdict: EventCuration.Verdict
    ) -> CachedEvent {

        let venue = event.embedded?.venues?.first
        let price = event.priceRanges?.first

        return CachedEvent(
            id: nil,
            eventId: event.id,
            name: event.name,
            info: event.info ?? event.pleaseNote,
            venueName: venue?.name,
            address: venue?.address?.line1 ?? venue?.city?.name,
            latitude: venue?.location?.latitude.flatMap(Double.init),
            longitude: venue?.location?.longitude.flatMap(Double.init),
            startDate: Timestamp(date: start),
            priceMin: price?.min,
            priceMax: price?.max,
            currency: price?.currency,
            segment: event.classifications?.first?.segment?.name,
            genre: event.classifications?.first?.genre?.name,
            category: verdict.category.rawValue,
            dateScore: verdict.score,
            imageURLs: Self.bestImageURLs(event.images),
            ticketURLBase: event.url,
            expireAt: Timestamp(date: start.addingTimeInterval(TicketmasterConfig.expiryGrace)),
            fetchedAt: nil,
            schemaVersion: CachedEvent.currentSchemaVersion
        )
    }

    /// Up to 4 distinct, reasonably-large Ticketmaster image URLs (widest first).
    /// Ticketmaster returns many crops; we keep the biggest few for the gallery.
    private static func bestImageURLs(_ images: [TicketmasterEvent.EventImage]?) -> [String] {
        guard let images else { return [] }
        var seen = Set<String>()
        return images
            .filter { ($0.width ?? 0) >= 600 }
            .sorted { ($0.width ?? 0) > ($1.width ?? 0) }
            .map(\.url)
            .filter { seen.insert($0).inserted }
            .prefix(4)
            .map { $0 }
    }
}

// MARK: - CachedEvent -> LocalEvent

extension CachedEvent {

    /// Projects a cached event onto the existing LocalEvent shape the swipe deck
    /// and detail screen already render — the only seam the rest of the UI sees.
    /// `cardId` is set from `eventId` (the stable match key); `id` is a fresh
    /// per-instance UUID, exactly as LocalEvent intends.
    func asLocalEvent() -> LocalEvent {
        let cat = LocalEvent.Category(rawValue: category) ?? .music
        return LocalEvent(
            cardId:        eventId,
            title:         name,
            venue:         venueName ?? "",
            date:          Self.displayDate(startDate.dateValue()),
            price:         priceLabel,
            category:      cat,
            emoji:         Self.emoji(for: cat),
            description:   info ?? "",
            address:       address,
            photos:        imageURLs,
            startDate:     startDate.dateValue(),
            ticketURLBase: ticketURLBase
        )
    }

    /// A short human label like "Fri 8pm" / "Sat 14:00" from the real start date,
    /// in the device's locale/timezone. Matches the existing card's `date` style.
    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mma"   // e.g. "Fri 8:00PM"
        return formatter.string(from: date)
            .replacingOccurrences(of: ":00", with: "")   // "Fri 8PM"
            .replacingOccurrences(of: "AM", with: "am")
            .replacingOccurrences(of: "PM", with: "pm")
    }

    /// Price pill text from the Ticketmaster price range. Neutral "See tickets"
    /// when Ticketmaster published no price (common) — never invents a number.
    var priceLabel: String {
        guard let min = priceMin else { return "See tickets" }
        let symbol = Self.currencySymbol(currency)
        if let max = priceMax, max > min {
            return "\(symbol)\(Int(min))–\(symbol)\(Int(max))"
        }
        return min == 0 ? "Free" : "\(symbol)\(Int(min))"
    }

    private static func currencySymbol(_ code: String?) -> String {
        switch code?.uppercased() {
        case "GBP": return "£"
        case "USD": return "$"
        case "EUR": return "€"
        case .some(let c): return "\(c) "
        case .none: return ""
        }
    }

    /// A category-appropriate emoji (Ticketmaster has none). Mirrors the visual
    /// vocabulary of the sample events so real and sample cards read alike.
    private static func emoji(for category: LocalEvent.Category) -> String {
        switch category {
        case .music:     return "🎶"
        case .foodDrink: return "🍷"
        case .arts:      return "🎭"
        case .outdoors:  return "🎪"
        case .nightlife: return "🎤"
        }
    }
}

// MARK: - eventQueries/{queryKey}

struct EventQuery: Codable, Identifiable {

    /// The query key (location bucket + date window), mirrored from the doc id.
    /// See EventCache for how it's built. nil on write, populated on read.
    @DocumentID var id: String?

    /// The resolved deck — an ORDERED list of eventIds (curated + ranked). Look
    /// each up in events/{eventId}. Ordered so both partners get the same deck
    /// sequence, which keeps their swipe cardIds aligned for matching.
    var eventIds: [String]

    /// Server time this query last resolved — drives the SWR refresh window.
    @ServerTimestamp var resolvedAt: Timestamp?
}
