// BucketListItem.swift
// One entry on the couple's shared date wishlist — a custom date idea they added
// themselves, beyond the swipe deck. Solves the long-term "we've swiped
// everything" churn. Synced across both partners via BucketListService, mirrored
// locally by BucketListStore (same Service + Store pattern as Mission/Memory).

import Foundation

struct BucketListItem: Identifiable, Codable, Equatable {

    let id: UUID
    var title: String
    var emoji: String
    var done: Bool
    var addedBy: String?    // uid that added it (informational; filled on write)
    let createdAt: Date

    init(id: UUID = UUID(),
         title: String,
         emoji: String = "💡",
         done: Bool = false,
         addedBy: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.done = done
        self.addedBy = addedBy
        self.createdAt = createdAt
    }
}
