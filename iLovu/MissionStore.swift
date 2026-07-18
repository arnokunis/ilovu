// MissionStore.swift
// The shared "list of missions" that every screen in the app reads
// from and writes to. Lives in memory while the app is running,
// persists itself to UserDefaults as JSON every time it changes.
//
// Why a shared store and not @AppStorage?
// @AppStorage is great for single Bool / Int / String / Double values
// but doesn't natively handle arrays of custom Codable types. A small
// @Observable store gives us:
//   • one source of truth that survives app launches,
//   • automatic SwiftUI re-renders in any view observing it,
//   • cleaner mutation APIs (add / update / upcoming).
//
// It's wired into the SwiftUI environment at the iLovuApp root so
// HomeView, MainTabView, and MissionDetailView all see the same one.

import Foundation
import Observation

@Observable
final class MissionStore {

    var missions: [Mission] = []

    // Versioned key so a future model change can ship a new "v2" key
    // and skip a broken decode of old data without losing the user's
    // missions through silent corruption.
    private let storageKey = "missions.v1"

    // Sink for pushing a locally-mutated mission to Firestore. Injected once at
    // the app root (iLovuApp) so MissionStore itself stays Firebase-free and
    // previewable — when nil (previews, unpaired/offline) mutations are simply
    // local. Set by the app to call MissionService.saveMission for the current
    // couple. Remote-origin merges (mergeFromRemote) deliberately DON'T fire this,
    // so an incoming update never echoes back out as a write.
    var remoteUpsert: ((Mission) -> Void)?

    init() {
        load()
    }

    // MARK: - Mutations
    // Every mutation goes through these helpers so save() is never
    // forgotten. Direct manipulation of `missions` would skip persistence.

    func add(_ mission: Mission) {
        missions.append(mission)
        save()
        remoteUpsert?(mission)
        // Local creations only — remote-synced missions arrive via
        // mergeFromRemote, so the partner's device doesn't double-count.
        AppAnalytics.log("mission_created")
    }

    func update(_ mission: Mission) {
        guard let index = missions.firstIndex(where: { $0.id == mission.id })
        else { return }
        missions[index] = mission
        save()
        remoteUpsert?(mission)
    }

    // MARK: - Remote sync
    // Merges keyed on cardId, NOT the local UUID id: the two phones generate
    // independent UUIDs for the same matched card, so cardId is the only stable
    // cross-device identity. These are called by MainTabView's missions listener.

    /// Applies a mission that arrived from Firestore. Replaces the existing local
    /// mission for the same card (preserving its local `id` so SwiftUI list
    /// identity stays stable), or appends it if we hadn't seen this card yet.
    /// Does NOT push back out — this is the inbound half of the sync.
    func mergeFromRemote(_ mission: Mission) {
        if let index = missions.firstIndex(where: { $0.cardId == mission.cardId }) {
            let preservedId = missions[index].id
            missions[index] = Mission(
                id: preservedId,
                card: mission.card,
                status: mission.status,
                scheduledDate: mission.scheduledDate,
                budget: mission.budget,
                checklist: mission.checklist
            )
        } else {
            missions.append(mission)
        }
        save()
    }

    /// Drops the local mission for `cardId` after a remote deletion. (We don't
    /// delete missions from the client today, but this keeps the listener honest.)
    func removeFromRemote(cardId: String) {
        let before = missions.count
        missions.removeAll { $0.cardId == cardId }
        if missions.count != before { save() }
    }

    // MARK: - Queries

    var upcoming: [Mission] {
        missions.filter { $0.status == .upcoming }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(missions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Mission].self, from: data)
        else { return }
        missions = decoded
    }
}
