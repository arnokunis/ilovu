// SampleCards.swift
// The hand-curated deck of 40 date ideas we ship with the app.
// No backend yet — these live in code so the app works fully offline.
// Later we'll swap this array out for cards fetched from a server.
//
// Order is round-robin across the five categories (cosy → foodie →
// adventure → creative → intimate, repeat) so the swipe feed feels
// varied — not eight cosy nights in a row.

import Foundation

// MARK: - SampleCards
// An enum used as a namespace (no cases, never instantiated) just to
// group sample data under a clear name: `SampleCards.all`.
enum SampleCards {

    static let all: [DateCard] = [

        // Round 1
        DateCard(
            title: "Recreate Your First Date",
            description: "Cook the same meal, play the same music, dress up like you did the night it all started.",
            emoji: "🌹",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Blind Taste Test",
            description: "Blindfold each other and guess mystery foods. Loser does the dishes.",
            emoji: "🍫",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Sunrise Somewhere New",
            description: "Set an early alarm. Watch the sun come up from a spot you've never been.",
            emoji: "🌅",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "Paint Each Other",
            description: "Cheap canvases and paints. Paint portraits. Keep them forever.",
            emoji: "🎨",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Phone-Free Evening",
            description: "Both phones in a drawer from dinner until bed.",
            emoji: "📵",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),

        // Round 2
        DateCard(
            title: "Blanket Fort Movie Marathon",
            description: "Build a fort with every cushion you own. Pick a film series. No phones inside.",
            emoji: "🏰",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Cook Each Other's Childhood Meal",
            description: "Make the dish that reminds you of growing up. Share the story.",
            emoji: "🍲",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "The Coin Flip Day",
            description: "At every junction flip a coin for left or right. Go where chance takes you.",
            emoji: "🪙",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "Co-op Video Game Night",
            description: "Pick a game you have to beat together.",
            emoji: "🎮",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "The Appreciation Exchange",
            description: "Take turns saying three things you appreciate. No interrupting.",
            emoji: "💛",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),

        // Round 3
        DateCard(
            title: "Candlelit Dinner at Home",
            description: "No takeaway. Cook together, dim the lights, phones in another room.",
            emoji: "🕯️",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "The New Restaurant Rule",
            description: "Go somewhere neither of you has been. No reviews beforehand.",
            emoji: "🍽️",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .foodie
        ),
        DateCard(
            title: "Tourist in Your Own Town",
            description: "Visit the spots locals never go. Take cheesy tourist photos.",
            emoji: "📸",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "Write Your Story",
            description: "Each write one paragraph, then swap. Build a ridiculous tale.",
            emoji: "✍️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Dream Planning Session",
            description: "Plan the trip you'd take if money was no object.",
            emoji: "🗺️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),

        // Round 4
        DateCard(
            title: "The 36 Questions",
            description: "Work through the psychology questions designed to make two people fall in love.",
            emoji: "💭",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Build Your Own Pizza Night",
            description: "Buy bases and toppings. Make the weirdest pizza you can.",
            emoji: "🍕",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Sunset Walk No Destination",
            description: "Walk until the sun sets. Talk about anything except work.",
            emoji: "🚶",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "Build a Playlist for Us",
            description: "Each add 10 songs that remind you of the other.",
            emoji: "🎵",
            difficulty: .micro,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Slow Dance in the Kitchen",
            description: "One song. No reason. Just dance together tonight.",
            emoji: "💃",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),

        // Round 5
        DateCard(
            title: "Breakfast in Bed Swap",
            description: "Each secretly makes the other breakfast in bed tomorrow morning.",
            emoji: "🥞",
            difficulty: .micro,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "Cocktail Lab",
            description: "Invent two original cocktails. Name them after each other.",
            emoji: "🍸",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Try a Class Together",
            description: "Pottery, dance, climbing — book something neither has done.",
            emoji: "🎯",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "The Memory Jar",
            description: "Decorate a jar. Each week add a happy moment note. Open next year.",
            emoji: "🫙",
            difficulty: .micro,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "The Time Capsule Letter",
            description: "Each write a letter to open on your next anniversary.",
            emoji: "✉️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),

        // Round 6
        DateCard(
            title: "Living Room Camping",
            description: "Sleeping bags, fairy lights, snacks, ghost stories. Camp without leaving home.",
            emoji: "⛺",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Bake Something That Scares You",
            description: "Pick the most ambitious recipe you'd never try. Bake it together.",
            emoji: "🎂",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "The Stargazing Mission",
            description: "Drive somewhere dark. Bring blankets. Find three constellations.",
            emoji: "⭐",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "Learn Each Other's Hobby",
            description: "Spend an evening teaching each other something you love.",
            emoji: "🎸",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Massage Exchange",
            description: "Take turns. 15 minutes each. No phones, soft music.",
            emoji: "💆",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate
        ),

        // Round 7
        DateCard(
            title: "Read to Each Other",
            description: "Pick a book. Take turns reading a chapter aloud before bed.",
            emoji: "📖",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Street Food Tour",
            description: "Three food spots in one evening — starter, main, dessert, each somewhere new.",
            emoji: "🌮",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie
        ),
        DateCard(
            title: "Pick a Pin on the Map",
            description: "Drop a pin within an hour's travel, go explore whatever's there.",
            emoji: "📍",
            difficulty: .adventure,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "Photo Scavenger Hunt",
            description: "List 10 things to photograph together. First to all 10 wins.",
            emoji: "📷",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Look Through Old Photos",
            description: "Go through photos from when you first met.",
            emoji: "🖼️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),

        // Round 8
        DateCard(
            title: "Spa Night",
            description: "Face masks, foot rubs, calming playlist. Pamper each other.",
            emoji: "🧖",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "Breakfast for Dinner",
            description: "Pancakes, eggs, the works — at 8pm in your pyjamas.",
            emoji: "🍳",
            difficulty: .micro,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Bike Ride to Nowhere",
            description: "Ride somewhere you've never explored. Stop for snacks.",
            emoji: "🚲",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "DIY Something for Home",
            description: "Build, paint or make one thing for your space together.",
            emoji: "🔨",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "The Big Questions Night",
            description: "Talk about dreams, fears, where you see us in 5 years.",
            emoji: "🌌",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        )
    ]
}
