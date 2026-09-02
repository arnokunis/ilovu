// LocationBucket.swift
// The ~11km (city-scale) location grid the whole app shares — the SINGLE source of truth for
// the "%.1f,%.1f" bucket string. Both the event cache and the place-deck cache
// key on it, and the couple doc stores ONE bucket both partners anchor to, so
// the format MUST be identical everywhere: if events and places bucketed
// differently, the shared couple bucket would line up for one source but not the
// other. Centralising it here makes that impossible to get wrong.
//
// 1 decimal ≈ a ~11km cell — roughly a city.
//
// WAS 2 decimals (~1.1km) until 2026-09-02, and that was a real cost bug: the
// SEARCH RADIUS is 10-30km, so the cache was bucketing ten times finer than the
// thing it cached. Every neighbourhood produced a fresh full curated fetch that
// no one else could ever reuse — 282 users generated 143 buckets, all unique,
// none shared, which is most of a ~€45/month Places bill on €0 revenue.
// "Scales with venues, not users" only holds if users CLUSTER; at 1km they never
// do. At ~11km a city becomes one bucket and the cache finally amortises.
//
// Old 2-decimal buckets still PARSE (center(of:) reads any Double), so stored
// couple anchors keep resolving; they simply stop being hit and age out. Expect
// one re-anchor per active user as their coordinate maps to the coarser cell.

import Foundation

enum LocationBucket {

    /// The bucket a coordinate falls in, e.g. (54.687, 25.279) -> "54.7,25.3".
    static func of(latitude: Double, longitude: Double) -> String {
        String(format: "%.1f,%.1f", latitude, longitude)
    }

    /// Parse a bucket string back to its centre. The search radius around the
    /// centre comfortably absorbs the 1-decimal rounding. nil if malformed.
    static func center(of bucket: String) -> (lat: Double, lng: Double)? {
        let parts = bucket.split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) else { return nil }
        return (lat, lng)
    }
}
