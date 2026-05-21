// Mission.swift
// The data model for a planned date — what happens AFTER a swipe-right
// turns into a match. A Mission wraps the matched DateCard with the
// extra planning state: status, optional date, optional budget, and a
// short checklist. Persisted as JSON in UserDefaults by MissionStore.
//
// This is the centerpiece of iLovu's "Match → Mission → Memory" loop.
// A match without a Mission is just a fleeting tap; a Mission turns
// it into a real plan the couple can act on.

import Foundation

struct Mission: Identifiable, Codable, Equatable {

    let id: UUID
    let card: DateCard
    var status: Status
    var scheduledDate: Date?
    var budget: String?
    var checklist: [ChecklistItem]

    // Two-state lifecycle for now. We'll likely add `.cancelled` or
    // `.archived` later, but `upcoming` / `completed` is enough today
    // to power the dashboard count and the "Mark Complete" flow.
    enum Status: String, Codable {
        case upcoming
        case completed
    }

    // One row in the planning checklist. `done` is a `var` so the
    // detail view can toggle it; everything else is set at creation.
    struct ChecklistItem: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var done: Bool

        init(id: UUID = UUID(), title: String, done: Bool = false) {
            self.id = id
            self.title = title
            self.done = done
        }
    }

    // Convenience initializer used when a swipe-right becomes a match.
    // Seeds the default 3-item checklist that every Mission starts with.
    init(from card: DateCard) {
        self.id = UUID()
        self.card = card
        self.status = .upcoming
        self.scheduledDate = nil
        self.budget = nil
        self.checklist = [
            ChecklistItem(title: "Pick a date"),
            ChecklistItem(title: "Set a reminder"),
            ChecklistItem(title: "Make it happen")
        ]
    }
}
