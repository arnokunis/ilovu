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

    init() {
        load()
    }

    // MARK: - Mutations
    // Every mutation goes through these helpers so save() is never
    // forgotten. Direct manipulation of `missions` would skip persistence.

    func add(_ mission: Mission) {
        missions.append(mission)
        save()
    }

    func update(_ mission: Mission) {
        guard let index = missions.firstIndex(where: { $0.id == mission.id })
        else { return }
        missions[index] = mission
        save()
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
