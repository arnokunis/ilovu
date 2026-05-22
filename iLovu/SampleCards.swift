// SampleCards.swift
// The hand-curated deck of date ideas we ship with the app.
// No backend yet — these live in code so the app works fully offline.
// Later we'll swap this array out for cards fetched from a server.
//
// The first 40 cards round-robin across the five categories
// (cosy → foodie → adventure → creative → intimate, repeat) so
// the swipe feed feels varied. The remaining 100 are a themed
// content pack — grouped by vibe rather than interleaved.

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
        ),

        // MARK: - Content Pack (100 additions)

        // Cosy Night In
        DateCard(
            title: "Blanket Fort Cinema",
            description: "Build a fort with every cushion you own and watch the film one of you has been \"meaning to show\" the other for years.",
            emoji: "🛋️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Two-Person Bake-Off",
            description: "Same recipe, separate bowls, no helping. Judge each other's results with brutal honesty and a kiss.",
            emoji: "🧁",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Candlelit Floor Picnic",
            description: "Move dinner to a blanket on the living room floor, lights off, candles only.",
            emoji: "🪔",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "The Reverse Day",
            description: "Breakfast for dinner, pyjamas all evening, dessert first. Do the whole night backwards.",
            emoji: "🌙",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "Handwritten Letter Swap",
            description: "Write each other a letter by hand, seal it, swap, read in silence.",
            emoji: "💌",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Old Photos, New Wine",
            description: "Open a bottle and scroll back through every photo of you two from the very beginning.",
            emoji: "🍷",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate
        ),
        DateCard(
            title: "Living Room Camp-Out",
            description: "Sleeping bags, fairy lights, phone torches as \"stars,\" ghost stories optional.",
            emoji: "⛺",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Cook Without a Recipe",
            description: "Open the fridge, pick five things, invent a dish together. No looking anything up.",
            emoji: "🥘",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "The Massage Trade",
            description: "Ten minutes each, no talking, just hands and quiet music.",
            emoji: "🤲",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Playlist Confessions",
            description: "Each build a 5-song playlist of \"songs that remind me of you,\" then explain every choice.",
            emoji: "🎶",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),

        // Foodie
        DateCard(
            title: "Order in a Language You Don't Speak",
            description: "Find a restaurant whose menu you can't read and order purely by pointing and hoping.",
            emoji: "🍜",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .foodie
        ),
        DateCard(
            title: "The Tenner Dinner Challenge",
            description: "Each given a tenner, separate shops, meet back home and combine whatever you bought into one meal.",
            emoji: "💷",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Dessert Crawl",
            description: "Skip dinner entirely. Visit three places and order only the pudding at each.",
            emoji: "🍰",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie
        ),
        DateCard(
            title: "Recreate Your First-Date Meal",
            description: "Find or cook exactly what you ate the first time you went out.",
            emoji: "💝",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Five-Way Blind Taste Test",
            description: "Buy five versions of one thing (chocolate, cheese, crisps). Blindfold, rank, argue.",
            emoji: "🫐",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Cook Your Grandmother's Recipe",
            description: "One of you teaches the other a dish from your family. Phone home if you have to.",
            emoji: "👵",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Street Food Hunt",
            description: "Pick a market and share one thing from every stall that catches your eye.",
            emoji: "🌭",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie
        ),
        DateCard(
            title: "The Spice Dare",
            description: "Cook one dish, add increasing heat, see who taps out first.",
            emoji: "🌶️",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "Breakfast in a New Town",
            description: "Drive somewhere you've never had breakfast and find the busiest café.",
            emoji: "🥐",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie
        ),
        DateCard(
            title: "Make Pasta From Scratch",
            description: "Flour, eggs, a rolling pin, low expectations, high laughter.",
            emoji: "🍝",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie
        ),

        // Adventure & Outdoors
        DateCard(
            title: "Coin-Flip Road Trip",
            description: "At every junction, flip a coin: heads left, tails right. Drive for an hour. See where you land.",
            emoji: "🛣️",
            difficulty: .adventure,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "Sunrise You'll Regret Setting an Alarm For",
            description: "Pick a high spot, set a 5am alarm, bring coffee in a flask.",
            emoji: "🌄",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "The Unplanned Train",
            description: "Go to the station, take the next train leaving, get off when somewhere looks interesting.",
            emoji: "🚆",
            difficulty: .adventure,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "Wild Swim",
            description: "Find a lake, river, or sea spot and get in. Scream together about the cold.",
            emoji: "🏊",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "Map Pin Dart",
            description: "Drop a pin somewhere within an hour's drive without looking, then go there.",
            emoji: "🎯",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "Golden Hour Walk",
            description: "Plan a walk that ends at the best view exactly as the sun goes down.",
            emoji: "🌇",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "Forage and Cook",
            description: "Pick blackberries, wild garlic, or whatever's in season, then cook with it.",
            emoji: "🍄",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "Stargazing Drive",
            description: "Get away from city lights with a blanket and an app that names what you're looking at.",
            emoji: "🔭",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "The Tourist in Your Own City",
            description: "Do the most obvious tourist thing in your town that you've never bothered to do.",
            emoji: "🗺️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "Cycle to Nowhere",
            description: "Two bikes, no destination, turn back when one of you gets hungry.",
            emoji: "🚴",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure
        ),

        // Creative & Playful
        DateCard(
            title: "Ten-Minute Portraits",
            description: "Cheap paints, two canvases, ten-minute portraits of each other. Frame the worst one.",
            emoji: "🖌️",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Write a Song About Today",
            description: "Doesn't matter if it's terrible. Three verses about your day, performed seriously.",
            emoji: "🎤",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "The Pottery Disaster",
            description: "Air-dry clay on the kitchen table. Make each other a \"gift.\" Keep it forever.",
            emoji: "🏺",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Build Something Flat-Pack",
            description: "Get the cheapest flat-pack furniture, no arguing allowed, time yourselves.",
            emoji: "🪛",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Two-Person Photoshoot",
            description: "One photographs, one poses, then swap. Find your most ridiculous and your most beautiful shot.",
            emoji: "📸",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Invent a Cocktail",
            description: "Name it after your relationship. Write the recipe down. Make it your \"house drink.\"",
            emoji: "🍹",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "The Jigsaw Race",
            description: "Two small jigsaws, start at the same time, loser does the washing up.",
            emoji: "🧩",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Draw Your Future House",
            description: "Each sketch the home you'd build together, then merge the two into one.",
            emoji: "🏡",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Make a Zine About Us",
            description: "Fold paper into a tiny booklet, fill it with drawings and inside jokes.",
            emoji: "📓",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Lip-Sync Battle",
            description: "One song each, full commitment, phone on a tripod, no mercy.",
            emoji: "🎙️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),

        // Intimate & Connection
        DateCard(
            title: "Eye Contact for Four Minutes",
            description: "Set a timer, sit knee to knee, just look. It gets weird, then it gets real.",
            emoji: "👀",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The Gratitude Round",
            description: "Take turns naming one thing you're grateful for about the other, until you run out.",
            emoji: "🙏",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Slow Dance, No Occasion",
            description: "One song, kitchen floor, no reason. Just because.",
            emoji: "🩰",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Read to Each Other in Bed",
            description: "One chapter of a book, out loud, lights low.",
            emoji: "📚",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The \"Remember When\" Game",
            description: "Trade your favourite memories of each other until one of you cries (happy tears).",
            emoji: "🎞️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Phone-Free Dinner",
            description: "Both phones in a drawer in another room. Just talk. See how long it really lasts.",
            emoji: "🤫",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Trace and Tell",
            description: "Draw a slow line down your partner's arm with a fingertip and tell them one thing you love about them.",
            emoji: "🤍",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The Closeness Questions",
            description: "Work through a few of the famous get-closer questions over tea.",
            emoji: "💞",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Bath and Talk",
            description: "Run a bath, no agenda, just float and chat.",
            emoji: "🛁",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Make a Wish List for Us",
            description: "Each write five things you want to do together this year, then read them aloud.",
            emoji: "📝",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),

        // Rainy Day / Low Energy
        DateCard(
            title: "The Duvet Day",
            description: "Cancel everything, stay in bed, order food, watch a whole series.",
            emoji: "🛏️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "Puzzle and Podcast",
            description: "A big jigsaw and a podcast you both like. Quiet, easy, together.",
            emoji: "🎧",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "Build the Ultimate Hot Drink",
            description: "Hot chocolate with everything: cream, marshmallows, a sneaky shot.",
            emoji: "☕",
            difficulty: .micro,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "Window-Watch the Storm",
            description: "Two chairs at the window, a blanket, watch the rain do its thing.",
            emoji: "🌧️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Learn One Card Trick Each",
            description: "Ten minutes of online tutorials, then perform for each other.",
            emoji: "🃏",
            difficulty: .micro,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "The Nap Date",
            description: "Yes, a nap counts. Curl up, set no alarm, that's the whole date.",
            emoji: "😴",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Reorganise One Drawer Together",
            description: "Oddly satisfying, weirdly bonding, find something you forgot you owned.",
            emoji: "🗄️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy
        ),
        DateCard(
            title: "Indoor Picnic Under the Table",
            description: "Recreate childhood. Crackers, cheese, juice in wine glasses.",
            emoji: "🧺",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy
        ),
        DateCard(
            title: "Two-Player Game Night",
            description: "Co-op a video or board game. Blame each other loudly when you lose.",
            emoji: "🎲",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Face Mask and Trash TV",
            description: "Skincare neither of you understands and the worst reality show you can find.",
            emoji: "📺",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy
        ),

        // Special Occasion / Milestone
        DateCard(
            title: "The Anniversary Map",
            description: "Pin every place that mattered in your relationship and revisit one.",
            emoji: "📌",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .intimate
        ),
        DateCard(
            title: "Recreate the First Date",
            description: "Same place, same order, same outfits if you can remember them.",
            emoji: "💕",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .intimate
        ),
        DateCard(
            title: "Open the Time Capsule",
            description: "Write letters to each other, seal them, plan to open them in exactly one year.",
            emoji: "📦",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The Year in Review Night",
            description: "Look back at everything you did this year together and pick your top three moments.",
            emoji: "📅",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Renew Your Tiny Vows",
            description: "Not married? Make up your own vows for the next year and say them anyway.",
            emoji: "💍",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The Birthday Surprise Swap",
            description: "Each plan a 2-hour surprise for the other on the same day.",
            emoji: "🎁",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .intimate
        ),
        DateCard(
            title: "Revisit Where You Said \"I Love You\"",
            description: "Go back to the exact spot. Say it again.",
            emoji: "💖",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate
        ),
        DateCard(
            title: "The Future Letter",
            description: "Write to your relationship five years from now. Hide it somewhere you'll find it.",
            emoji: "🕰️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Celebrate a Half-Anniversary",
            description: "Why wait for the full year? Mark six months with something small and silly.",
            emoji: "🥂",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate
        ),
        DateCard(
            title: "The Milestone Feast",
            description: "Cook the most ambitious meal you've ever attempted to mark something big.",
            emoji: "🍽️",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie
        ),

        // Out & About
        DateCard(
            title: "Gallery Whisper Game",
            description: "At a museum, make up the real story behind each painting in whispers.",
            emoji: "🏛️",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "The Charity Shop Challenge",
            description: "A fiver each, find the other the most \"them\" item in the shop.",
            emoji: "🛍️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "Bookshop Blind Date",
            description: "Each pick a book for the other based on the cover alone. Buy it. Read it.",
            emoji: "📖",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Farmers Market Breakfast",
            description: "Build breakfast entirely from market stalls, eat it on a bench.",
            emoji: "🥕",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie
        ),
        DateCard(
            title: "The Free Things Tour",
            description: "A whole day out spending nothing: parks, libraries, free museums, window shopping.",
            emoji: "🆓",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "Botanical Garden Slow Walk",
            description: "No phones, no rush, find the weirdest plant and name it after each other.",
            emoji: "🌿",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "Live Music, Any Genre",
            description: "Find the smallest gig in town and go, even if it's a genre neither of you knows.",
            emoji: "🎷",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "The Viewpoint Picnic",
            description: "Find the highest accessible point near you and eat lunch looking down on everything.",
            emoji: "⛰️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        ),
        DateCard(
            title: "Vintage Cinema Trip",
            description: "Find somewhere showing an old film and treat it like an event.",
            emoji: "🎬",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .creative
        ),
        DateCard(
            title: "Harbour or River Walk at Dusk",
            description: "Walk by water as the lights come on, talk about nothing important.",
            emoji: "🌆",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure
        ),

        // Flirty & Tender
        DateCard(
            title: "The Compliment Volley",
            description: "No repeats, back and forth, until one of you blushes too hard to continue.",
            emoji: "🥰",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Slow Dance With the Lights Off",
            description: "One song, no phone, no talking.",
            emoji: "🕺",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The \"What I First Noticed\" Reveal",
            description: "Tell each other the very first thing you noticed about them.",
            emoji: "✨",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Kiss for Every Green Light",
            description: "On a drive or walk, every green light earns a kiss.",
            emoji: "💚",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The Truth-or-Truth Game",
            description: "No dares, only truths, increasingly bold.",
            emoji: "🎴",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Write Three Things You Find Irresistible",
            description: "Swap the notes. No reading aloud. Just keep them.",
            emoji: "📜",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The Long Goodnight",
            description: "No phones in bed for one full night. Just each other.",
            emoji: "🌜",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "Recreate Your First Kiss",
            description: "Same energy, same nervousness, do it again like it's new.",
            emoji: "💋",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),
        DateCard(
            title: "The Slow Morning",
            description: "Set no alarm. Whoever wakes first makes the coffee. Stay in bed regardless.",
            emoji: "🛌",
            difficulty: .micro,
            estimatedCost: .low,
            category: .intimate
        ),
        DateCard(
            title: "Two-Minute Heartbeat",
            description: "Lie still, hand on each other's chest, feel the rhythm slow down together.",
            emoji: "💓",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate
        ),

        // Try Something New
        DateCard(
            title: "Beginner's Class, Anything",
            description: "Pottery, dance, climbing, whatever has a \"first timers\" session this week.",
            emoji: "🎓",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .creative
        ),
        DateCard(
            title: "Be a Beginner at Their Hobby",
            description: "Spend an hour being a total beginner at the thing your partner loves.",
            emoji: "🪡",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "The New Cuisine Rule",
            description: "Eat food from a country neither of you has tried. Order the thing you can't pronounce.",
            emoji: "🍱",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie
        ),
        DateCard(
            title: "Plant Something Together",
            description: "A herb pot, a tree, a window box. Watch it grow as long as you're together.",
            emoji: "🌱",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "The Skill Swap",
            description: "Each teach the other something you can do that they can't, in 30 minutes.",
            emoji: "🔁",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Volunteer for an Afternoon",
            description: "Do something good for someone else, together, for a few hours.",
            emoji: "🤝",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure
        ),
        DateCard(
            title: "The Language Hour",
            description: "Both learn ten words of a new language and only use those words for an hour.",
            emoji: "🗣️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative
        ),
        DateCard(
            title: "Build a Bucket List Board",
            description: "A physical board of everything you want to do together. Hang it where you'll see it.",
            emoji: "📋",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative
        ),
        DateCard(
            title: "Try the Thing You're Both Scared Of",
            description: "Heights, deep water, public dancing. Hold hands. Do it anyway.",
            emoji: "😱",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure
        ),
        DateCard(
            title: "The Reverse Bucket List",
            description: "Instead of new things, redo your favourite thing you've ever done together.",
            emoji: "♻️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure
        )
    ]
}
