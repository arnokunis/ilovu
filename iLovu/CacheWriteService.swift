// CacheWriteService.swift
// Routes cache write-through to the `cacheWrite` Cloud Function, so the shared,
// world-readable cache collections — venues / venueQueries / placeDeckQueries /
// eventQueries — are writable ONLY via a Cloud Function (Admin SDK), never by a
// client directly. firestore.rules for these is `allow write: if false`; reads
// stay open. This closes the "any signed-in user can poison the cache / write
// huge docs" hole (see the PRE-LAUNCH HARDENING notes + functions/index.js).
//
// THIN GATE: the client still runs the Google Places fetch on-device (the
// bundle-restricted key stays here for now) and hands the resolved doc to the CF
// to persist. Moving the fetch + key server-side is the post-launch fast-follow.
//
// @ServerTimestamp fields (fetchedAt / resolvedAt) encode to a FieldValue sentinel
// that can't cross the callable JSON boundary, so we strip them and name them in
// `serverTimestampFields`; the CF re-stamps them with server time — producing the
// exact doc the old `setData(from:)` write produced (so the `.estimate` freshness
// reads in VenueCache / EventCache are unaffected).

import Foundation
import FirebaseFirestore
import FirebaseFunctions

struct CacheWriteService {

    private var functions: Functions { Functions.functions(region: "europe-west1") }

    /// Encode a Codable cache model and persist it via the `cacheWrite` CF.
    /// `serverTimestampFields` are the model's @ServerTimestamp keys (stripped
    /// here, re-stamped server-side). Throws on failure so callers' existing
    /// try/catch logging (and SWR retry-on-next-open) behave exactly as before.
    func write<T: Encodable>(
        _ model: T,
        to collection: String,
        docId: String,
        serverTimestampFields: [String]
    ) async throws {
        var data = try Firestore.Encoder().encode(model)
        for field in serverTimestampFields {
            data.removeValue(forKey: field)   // FieldValue sentinel — CF re-stamps it
        }
        _ = try await functions.httpsCallable("cacheWrite").call([
            "collection": collection,
            "docId": docId,
            "data": data,
            "serverTimestampFields": serverTimestampFields,
        ])
    }
}
