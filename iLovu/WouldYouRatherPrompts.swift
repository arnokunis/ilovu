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
        WYRPrompt(optionA: "Cook breakfast 🍳",       optionB: "Cook dinner 🕯️"),

        // Food & drink
        WYRPrompt(optionA: "Pancakes 🥞", optionB: "Waffles 🧇"),
        WYRPrompt(optionA: "Sushi 🍣", optionB: "Tacos 🌮"),
        WYRPrompt(optionA: "Ice cream 🍦", optionB: "Chocolate 🍫"),
        WYRPrompt(optionA: "Pasta night 🍝", optionB: "Ramen night 🍜"),
        WYRPrompt(optionA: "Spicy food 🌶️", optionB: "Sweet treats 🍬"),
        WYRPrompt(optionA: "Cheese board 🧀", optionB: "Dessert board 🍮"),
        WYRPrompt(optionA: "Breakfast for dinner 🍳", optionB: "Dinner for breakfast 🍲"),
        WYRPrompt(optionA: "Bake cookies 🍪", optionB: "Make smoothies 🥤"),
        WYRPrompt(optionA: "Popcorn 🍿", optionB: "Nachos 🧀"),
        WYRPrompt(optionA: "Wine tasting 🍇", optionB: "Coffee crawl ☕️"),
        WYRPrompt(optionA: "Lazy brunch 🥐", optionB: "Big Sunday roast 🍗"),

        // Activities
        WYRPrompt(optionA: "Mini golf ⛳️", optionB: "Bowling 🎳"),
        WYRPrompt(optionA: "Escape room 🔐", optionB: "Puzzle night 🧩"),
        WYRPrompt(optionA: "Roller skating 🛼", optionB: "Ice skating ⛸️"),
        WYRPrompt(optionA: "Pottery class 🏺", optionB: "Cooking class 🍳"),
        WYRPrompt(optionA: "Dance class 💃", optionB: "Painting class 🎨"),
        WYRPrompt(optionA: "Bike ride 🚲", optionB: "Kayak paddle 🛶"),
        WYRPrompt(optionA: "Surfing 🏄", optionB: "Snorkeling 🤿"),
        WYRPrompt(optionA: "Rock climbing 🧗", optionB: "Zip-lining 🪢"),
        WYRPrompt(optionA: "Yoga together 🧘", optionB: "Run together 🏃"),
        WYRPrompt(optionA: "Fishing 🎣", optionB: "Birdwatching 🐦"),
        WYRPrompt(optionA: "Go-karting 🏎️", optionB: "Arcade night 🕹️"),
        WYRPrompt(optionA: "Horse riding 🐴", optionB: "Hot air balloon 🎈"),
        WYRPrompt(optionA: "Beach volleyball 🏐", optionB: "Frisbee in the park 🥏"),
        WYRPrompt(optionA: "Photography walk 📷", optionB: "Sketching in the park ✏️"),
        WYRPrompt(optionA: "Axe throwing 🪓", optionB: "Darts night 🎯"),
        WYRPrompt(optionA: "Flower arranging 💐", optionB: "Candle making 🕯️"),

        // Travel & adventure
        WYRPrompt(optionA: "Backpacking 🎒", optionB: "Luxury resort 🏨"),
        WYRPrompt(optionA: "Cruise ship 🚢", optionB: "Train journey 🚂"),
        WYRPrompt(optionA: "Desert adventure 🏜️", optionB: "Rainforest trek 🌴"),
        WYRPrompt(optionA: "Northern lights 🌌", optionB: "Tropical beach 🏝️"),
        WYRPrompt(optionA: "New city every trip 🗺️", optionB: "Same favorite spot 📍"),
        WYRPrompt(optionA: "Tent 🏕️", optionB: "Campervan 🚐"),
        WYRPrompt(optionA: "Island hopping 🛥️", optionB: "Mountain village ⛰️"),
        WYRPrompt(optionA: "Safari 🦁", optionB: "Scuba diving 🐠"),
        WYRPrompt(optionA: "Window seat ✈️", optionB: "Aisle seat 🚶"),
        WYRPrompt(optionA: "Pack light 🎒", optionB: "Pack everything 🧳"),

        // Cozy & home
        WYRPrompt(optionA: "Blanket fort 🏰", optionB: "Backyard camping ⛺️"),
        WYRPrompt(optionA: "Candles and a bath 🛁", optionB: "Fireplace and cocoa 🔥"),
        WYRPrompt(optionA: "Big cozy sweater 🧶", optionB: "Fluffy socks 🧦"),
        WYRPrompt(optionA: "Rainy day inside ☔️", optionB: "Sunny day outside ☀️"),
        WYRPrompt(optionA: "Redecorate a room 🛋️", optionB: "Plant a garden 🪴"),
        WYRPrompt(optionA: "Slow morning ☕️", optionB: "Adventurous morning 🥾"),
        WYRPrompt(optionA: "Home spa night 💆", optionB: "Home cocktail night 🍸"),
        WYRPrompt(optionA: "Read side by side 📖", optionB: "Watch the rain 🌧️"),
        WYRPrompt(optionA: "Morning cuddles 🌅", optionB: "Late-night talks 🌙"),
        WYRPrompt(optionA: "Fairy lights ✨", optionB: "Scented candles 🕯️"),
        WYRPrompt(optionA: "Nap together 😴", optionB: "Stay up late 🌙"),
        WYRPrompt(optionA: "Grow herbs 🌿", optionB: "Grow flowers 🌷"),

        // Playful & silly
        WYRPrompt(optionA: "Prank each other 😜", optionB: "Compliment battle 🥰"),
        WYRPrompt(optionA: "Sing loudly 🎤", optionB: "Dance badly 🕺"),
        WYRPrompt(optionA: "Scary stories 👻", optionB: "Funny stories 😂"),
        WYRPrompt(optionA: "Build furniture together 🔧", optionB: "Never again 🙅"),
        WYRPrompt(optionA: "Water balloon fight 💦", optionB: "Pillow fight 🛏️"),
        WYRPrompt(optionA: "Truth 🤔", optionB: "Dare 😈"),
        WYRPrompt(optionA: "Couple's playlist 🎶", optionB: "Couple's scrapbook 📸"),
        WYRPrompt(optionA: "Win the argument 🏆", optionB: "Get the last bite 🍪"),
        WYRPrompt(optionA: "Couples costume 🎭", optionB: "Solo costume 🦸"),
        WYRPrompt(optionA: "Tickle fight 🤣", optionB: "Staring contest 👀"),
        WYRPrompt(optionA: "Make each other laugh 😄", optionB: "Make each other blush 😊"),
        WYRPrompt(optionA: "Roast each other lovingly 🔥", optionB: "Hype each other up 📣"),

        // Seasonal
        WYRPrompt(optionA: "Autumn leaves 🍂", optionB: "Spring blossoms 🌸"),
        WYRPrompt(optionA: "Snowball fight ❄️", optionB: "Sandcastles 🏖️"),
        WYRPrompt(optionA: "Christmas market 🎄", optionB: "Summer festival 🎪"),
        WYRPrompt(optionA: "Pumpkin patch 🎃", optionB: "Berry picking 🫐"),
        WYRPrompt(optionA: "First snow ❄️", optionB: "First warm day 🌤️"),
        WYRPrompt(optionA: "Spooky Halloween 👻", optionB: "Cozy Christmas 🎄"),
        WYRPrompt(optionA: "Hot cocoa season ☕️", optionB: "Iced coffee season 🧊"),
        WYRPrompt(optionA: "Rake the leaves 🍁", optionB: "Build a snowman ⛄️"),

        // Little preferences
        WYRPrompt(optionA: "Early bird 🌅", optionB: "Night owl 🦉"),
        WYRPrompt(optionA: "Save dessert for last 🍰", optionB: "Eat it first 😋"),
        WYRPrompt(optionA: "Playlist DJ 🎧", optionB: "Podcast picker 🎙️"),
        WYRPrompt(optionA: "Map reader 🗺️", optionB: "Free explorer 🧭"),
        WYRPrompt(optionA: "Big group hangout 👯", optionB: "Just us two 💑"),
        WYRPrompt(optionA: "Same meal every time 🍔", optionB: "Try something new 🆕"),
        WYRPrompt(optionA: "Give gifts 🎁", optionB: "Give experiences 🎟️"),
        WYRPrompt(optionA: "Textbook romantic 🌹", optionB: "Goofy romantic 🤪"),
        WYRPrompt(optionA: "Beach sunset 🌇", optionB: "City lights 🌃"),
        WYRPrompt(optionA: "Text all day 📱", optionB: "Save it for tonight 🌙"),
        WYRPrompt(optionA: "Slow dance in the kitchen 💃", optionB: "Sing into the spatula 🎤")
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
