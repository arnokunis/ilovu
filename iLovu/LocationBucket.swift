// LocationBucket.swift
// The ~1km location grid the whole app shares — the SINGLE source of truth for
// the "%.2f,%.2f" bucket string. Both the event cache and the place-deck cache
// key on it, and the couple doc stores ONE bucket both partners anchor to, so
// the format MUST be identical everywhere: if events and places bucketed
// differently, the shared couple bucket would line up for one source but not the
// other. Centralising it here makes that impossible to get wrong.
//
// 2 decimals ≈ a ~1km cell, same grain as the venue query cache.

import Foundation

enum LocationBucket {

    /// The bucket a coordinate falls in, e.g. (54.687, 25.279) -> "54.69,25.28".
    static func of(latitude: Double, longitude: Double) -> String {
        String(format: "%.2f,%.2f", latitude, longitude)
    }

    /// Parse a bucket string back to its centre. The search radius around the
    /// centre comfortably absorbs the 2-decimal rounding. nil if malformed.
    static func center(of bucket: String) -> (lat: Double, lng: Double)? {
        let parts = bucket.split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) else { return nil }
        return (lat, lng)
    }
}
