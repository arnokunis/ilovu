// MemoryStore.swift
// The shared "list of memories" — same pattern as MissionStore.
// @Observable + JSON-into-UserDefaults persistence. Injected at the
// app root so UsView, HomeView, and the completion flow all see the
// same one instance.

import Foundation
import Observation

@Observable
final class MemoryStore {

    var memories: [Memory] = []

    // Versioned key — a future schema change can bump to v2 and ignore
    // any old data instead of corrupting it via a half-broken decode.
    private let storageKey = "memories.v1"

    init() {
        load()
    }

    // MARK: - Mutations

    func add(_ memory: Memory) {
        memories.append(memory)
        save()
    }

    // MARK: - Queries

    // Newest first — the way humans naturally read a journal.
    var sortedByDate: [Memory] {
        memories.sorted { $0.dateCompleted > $1.dateCompleted }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(memories) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Memory].self, from: data)
        else { return }
        memories = decoded
    }
}
