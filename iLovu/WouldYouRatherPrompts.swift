// WouldYouRatherPrompts.swift
// The content bank for the "Would You Rather" couple game — light, warm, date-y
// dilemmas (never heavy/relationship-audit territory; that's off-brand). Rotated
// by day-of-year so BOTH partners independently land on the same prompt, exactly
// like ConnectionQuestions.today for the Daily Question. The reveal (did we
// match?) is the fun payoff and the shareable moment.

import Foundation

struct WYRPrompt: Equatable {
    let optionA: String
    let optionB: String
}

enum WouldYouRather {

    static let prompts: [WYRPrompt] = [
        WYRPrompt(optionA: "Beach day 🏖️",          optionB: "Mountain hike 🏔️"),
        WYRPrompt(optionA: "Fancy dinner 🍽️",        optionB: "Street food crawl 🌮"),
        WYRPrompt(optionA: "Movie night in 🍿",       optionB: "Dancing out 💃"),
        WYRPrompt(optionA: "Watch the sunrise 🌅",    optionB: "Watch the sunset 🌇"),
        WYRPrompt(optionA: "Cook together 🍳",        optionB: "Order in 🥡"),
        WYRPrompt(optionA: "Road trip 🚗",            optionB: "Fly somewhere ✈️"),
        WYRPrompt(optionA: "Plan every detail 📋",    optionB: "Totally spontaneous 🎲"),
        WYRPrompt(optionA: "Coffee date ☕️",          optionB: "Cocktail date 🍸"),
        WYRPrompt(optionA: "Board games 🎲",          optionB: "Video games 🎮"),
        WYRPrompt(optionA: "Camp under the stars ⛺️", optionB: "Cozy cabin 🛖"),
        WYRPrompt(optionA: "Museum wander 🖼️",        optionB: "Live music 🎶"),
        WYRPrompt(optionA: "Picnic in the park 🧺",   optionB: "Rooftop drinks 🍷"),
        WYRPrompt(optionA: "Early morning walk 🌄",   optionB: "Late night drive 🌙"),
        WYRPrompt(optionA: "Sweet breakfast 🥞",      optionB: "Savory breakfast 🥓"),
        WYRPrompt(optionA: "City break 🏙️",           optionB: "Countryside escape 🌾"),
        WYRPrompt(optionA: "Slow dance at home 🎵",   optionB: "Concert front row 🎤"),
        WYRPrompt(optionA: "Bake a cake 🎂",          optionB: "Make a pizza 🍕"),
        WYRPrompt(optionA: "Stargazing 🔭",           optionB: "Bonfire on the beach 🔥"),
        WYRPrompt(optionA: "Bookshop afternoon 📚",   optionB: "Art gallery afternoon 🎨"),
        WYRPrompt(optionA: "Spa day 💆",              optionB: "Adventure park 🎢"),
        WYRPrompt(optionA: "Winter cuddles ❄️",       optionB: "Summer adventures ☀️"),
        WYRPrompt(optionA: "Tea person 🍵",           optionB: "Coffee person ☕️"),
        WYRPrompt(optionA: "Sunset picnic 🌅",        optionB: "Midnight snack run 🌭"),
        WYRPrompt(optionA: "Dogs 🐶",                 optionB: "Cats 🐱"),
        WYRPrompt(optionA: "Live in the city 🌆",     optionB: "Live by the sea 🌊"),
        WYRPrompt(optionA: "Karaoke night 🎤",        optionB: "Trivia night 🧠"),
        WYRPrompt(optionA: "Breakfast in bed 🛏️",     optionB: "Brunch out 🥐"),
        WYRPrompt(optionA: "Handwritten letter ✍️",   optionB: "Surprise voice note 🎙️"),
        WYRPrompt(optionA: "Wine 🍷",                 optionB: "Cocktails 🍹"),
        WYRPrompt(optionA: "Comedy show 😂",          optionB: "Theatre play 🎭"),
        WYRPrompt(optionA: "Cook a new recipe 👩‍🍳",    optionB: "Revisit our favorite 🍝"),
        WYRPrompt(optionA: "Aquarium 🐠",             optionB: "Botanical garden 🌷"),
        WYRPrompt(optionA: "Ski trip ⛷️",             optionB: "Tropical getaway 🌴"),
        WYRPrompt(optionA: "Matching outfits 👕",     optionB: "Never in a million years 🙅"),
        WYRPrompt(optionA: "Sing in the car 🎶",      optionB: "Deep chats in the car 💬"),
        WYRPrompt(optionA: "Farmers market 🥕",       optionB: "Vintage flea market 🕰️"),
        WYRPrompt(optionA: "Sunrise coffee ☕️",       optionB: "Sunset wine 🍷"),
        WYRPrompt(optionA: "Netflix marathon 📺",     optionB: "Cinema outing 🎬"),
        WYRPrompt(optionA: "Long hike 🥾",            optionB: "Lazy beach nap 😴"),
        WYRPrompt(optionA: "Cook breakfast 🍳",       optionB: "Cook dinner 🕯️")
    ]

    /// Today's prompt, rotated by day-of-year so both partners see the same one.
    static var today: WYRPrompt { prompts[todayIndex] }

    /// Index of today's prompt (persisted on the game doc so a reveal shows the
    /// right dilemma even if the bank is later edited).
    static var todayIndex: Int {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return (day - 1) % prompts.count
    }

    /// The shared game-doc id for today ("YYYY-MM-DD"), computed identically on
    /// both devices so they converge on the same round.
    static var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Resolve a stored index back to its prompt (bounds-safe).
    static func prompt(at index: Int) -> WYRPrompt {
        prompts[((index % prompts.count) + prompts.count) % prompts.count]
    }
}
