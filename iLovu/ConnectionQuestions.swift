// ConnectionQuestions.swift
// The bank of warm, specific connection questions cycled one per
// day on the Us tab. Designed to feel like a thoughtful friend
// nudging — not a therapy worksheet. Every question is short,
// concrete, and easy to answer in 2-3 sentences.
//
// Rotation rule: pick by day-of-year, mod question count. With 30
// questions that means a 30-day cycle — each question reappears
// roughly 12 times a year, far enough apart that they feel fresh.

import Foundation

enum ConnectionQuestions {

    static let all: [String] = [
        "What's one small thing I did this week that you noticed?",
        "If we could wake up anywhere tomorrow, where would it be?",
        "What's a memory of us that always makes you smile?",
        "What's something you've wanted to try together but haven't yet?",
        "When did you feel most loved by me recently?",
        "What's the best meal we've ever had together?",
        "What song always reminds you of us?",
        "What's something I do that makes you laugh?",
        "If we had a free Saturday with no plans, what would feel perfect?",
        "What's one thing you'd like to learn together?",
        "What's a place we've been that you'd go back to in a heartbeat?",
        "What's something kind you've noticed me doing for someone else?",
        "What does a really good day with me look like to you?",
        "What's a small ritual of ours you'd hate to lose?",
        "What's something about me that's grown on you since we first met?",
        "If we were meeting for the first time tomorrow, what would you want me to know about you?",
        "What's a tradition you'd like us to start?",
        "What's something we did this month that you're glad we did?",
        "When have you felt the most 'us' lately?",
        "What's one thing you'd want us to slow down and enjoy more?",
        "What's something you appreciate about me that you don't say out loud?",
        "What's a side of me that you really love?",
        "What's something simple that always cheers you up?",
        "What would your perfect lazy morning look like?",
        "What's the kindest thing someone's done for you this month?",
        "What's something small that always makes your day better?",
        "What's something you've been thinking about a lot lately?",
        "What's a moment from this past year you'd freeze in time?",
        "Where do you feel most at peace?",
        "What's something you'd love us to do before the year ends?"
    ]

    // Today's question. Picked by day-of-year so both partners on the
    // same calendar day see the same prompt, no syncing required.
    static var today: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (day - 1) % all.count
        return all[index]
    }

    // Stable per-day key used by @AppStorage to remember whether the
    // user has answered TODAY specifically. Format: "2026-05-21".
    // Using Calendar.dateComponents respects the user's local time
    // zone — they shouldn't see "today" flip at UTC midnight.
    static var todayDateKey: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d",
                      comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
