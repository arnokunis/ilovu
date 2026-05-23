// DateCard.swift
// The data model for a single date idea — the thing the user swipes on.
// This file defines WHAT a date card IS, not how it looks.
// (The visual card lives in SwipeView.swift; this is just the data shape.)

import Foundation

// MARK: - DateCard
// A struct because cards are simple value types — copying one is fine,
// they don't need shared identity or reference semantics.
//
// `Identifiable` lets SwiftUI's ForEach loop over cards automatically
// using the `id` property. `Equatable` lets us compare two cards
// (handy for "did the user just match on this exact card?").
// Added Codable so a DateCard embedded inside a Mission can be persisted
// (Mission → JSON → UserDefaults via MissionStore).
struct DateCard: Identifiable, Equatable, Codable {
    let id: UUID = UUID()           // Unique fingerprint, auto-generated for each card.
    let title: String                // Short headline, e.g. "Slow Dance in the Kitchen"
    let description: String          // 1-2 warm sentences explaining the date idea.
    let emoji: String                // The big visual hook at the top of the card.
    let difficulty: Difficulty       // How much time/effort this date needs.
    let estimatedCost: Cost          // Rough money commitment.
    let category: Category           // The vibe — cosy, foodie, adventure, etc.
    let whyItWorks: String           // Bespoke per-card line shown on the detail sheet.
    let tips: [String]               // Bespoke per-card practical tips on the detail sheet.

    // MARK: - Difficulty
    // An enum because difficulty has a fixed set of options.
    // The raw String value is what we show in the UI — no extra mapping needed.
    enum Difficulty: String, CaseIterable, Codable {
        case micro      = "Micro · 5 min"
        case quick      = "Quick · 30 min"
        case halfDay    = "Half Day"
        case adventure  = "Full Day Adventure"
    }

    // MARK: - Cost
    // Three buckets — keeps things simple. No exact prices, just a feel.
    enum Cost: String, CaseIterable, Codable {
        case free   = "Free"
        case low    = "Low"
        case medium = "Medium"
    }

    // MARK: - Category
    // The emotional flavor of the date. Used later to filter or theme cards.
    enum Category: String, CaseIterable, Codable {
        case cosy
        case foodie
        case adventure
        case creative
        case intimate
    }
}
