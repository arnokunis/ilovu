// SampleEvents.swift
// 15 hand-curated local events shipping with the app. No backend yet
// — these live in code so the Near You tab works fully offline.
// Later this list will be replaced by results from Google Places +
// Eventbrite, but the LocalEvent shape stays the same.
//
// Five top events get rich detail data (address, hours, highlights,
// review snippets, booking URL) so the detail screen feels real and
// premium. The other ten use just the base fields — the detail
// screen handles missing data by hiding the relevant sections.

import Foundation

enum SampleEvents {

    static let all: [LocalEvent] = [

        // MARK: - Music
        LocalEvent(
            title: "Live Jazz at The Blue Note",
            venue: "The Blue Note",
            date: "Fri 8pm",
            price: "£15",
            category: .music,
            emoji: "🎷",
            description: "An intimate live trio in a candlelit basement bar. Perfect for conversation between songs.",
            rating: 4.7,
            reviewCount: 890,
            address: "47 Beale Street, Old Town",
            openingHours: "Open until 1am",
            photos: ["jazz-stage", "interior", "drinks", "trio"],
            highlights: ["🎷 Live Trio Sets", "🍸 Craft Cocktails", "🕯️ Candlelit Tables"],
            reviewSnippets: [
                .init(author: "Sarah", rating: 5, text: "Perfect date spot, cosy and romantic. The music was incredible."),
                .init(author: "Mark",  rating: 5, text: "Best jazz in the city. Came on a Tuesday and it was packed."),
                .init(author: "Lena",  rating: 4, text: "Lovely vibe, the saxophonist was outstanding. A bit pricey but worth it.")
            ],
            bookingURL: "https://www.google.com/search?q=The+Blue+Note+jazz+booking"
        ),
        LocalEvent(
            title: "Acoustic Open Mic Night",
            venue: "The Whistle",
            date: "Wed 8pm",
            price: "Free",
            category: .music,
            emoji: "🎸",
            description: "Local musicians try out new material. Low-key, surprise-filled, great drinks.",
            rating: 4.4,
            reviewCount: 230
        ),
        LocalEvent(
            title: "Sunday Vinyl Brunch",
            venue: "Echo Cafe",
            date: "Sun 11am",
            price: "£12",
            category: .music,
            emoji: "🎶",
            description: "Records spinning, eggs benedict, slow morning energy.",
            rating: 4.6,
            reviewCount: 410
        ),

        // MARK: - Food & Drink
        LocalEvent(
            title: "Street Food Night Market",
            venue: "Riverside Plaza",
            date: "Sat 6pm",
            price: "Free",
            category: .foodDrink,
            emoji: "🌮",
            description: "Twenty stalls of global flavours, fairy lights everywhere, communal long tables.",
            rating: 4.5,
            reviewCount: 2100,
            address: "Riverside Plaza, Harbour Front",
            openingHours: "Sat 5pm — midnight",
            photos: ["lanterns", "stalls", "food", "crowd"],
            highlights: ["🌮 20+ Stalls", "🎶 Live DJ", "🪔 Fairy Lights"],
            reviewSnippets: [
                .init(author: "Emma",  rating: 5, text: "We tried five different cuisines in one night. So fun."),
                .init(author: "James", rating: 4, text: "Crowded but in a good way. The Korean tacos were unreal."),
                .init(author: "Priya", rating: 5, text: "Our new Saturday tradition. Always something new to try.")
            ],
            bookingURL: "https://www.google.com/search?q=Riverside+Plaza+night+market"
        ),
        LocalEvent(
            title: "Wine Tasting Evening",
            venue: "Cellar 47",
            date: "Thu 7pm",
            price: "£25",
            category: .foodDrink,
            emoji: "🍷",
            description: "Six glasses from a region you haven't tried, sommelier-guided, cheese pairings included.",
            rating: 4.8,
            reviewCount: 540,
            address: "22 Vine Street, Cellar District",
            openingHours: "Tasting 7pm — 9pm",
            photos: ["wine", "cellar", "cheese", "glasses"],
            highlights: ["🍷 6 Wines", "🧀 Cheese Board", "📚 Sommelier Notes"],
            reviewSnippets: [
                .init(author: "Charlie", rating: 5, text: "Learned more in two hours than I have in years. And got tipsy."),
                .init(author: "Nadia",   rating: 5, text: "Cellar 47 itself is gorgeous. Felt like a hidden gem."),
                .init(author: "Ben",     rating: 4, text: "Great selection. Would love more food included.")
            ],
            bookingURL: "https://www.google.com/search?q=Cellar+47+wine+tasting"
        ),
        LocalEvent(
            title: "Cocktail Bar Crawl",
            venue: "Three bars, starts at Atlas",
            date: "Sat 8pm",
            price: "£30",
            category: .foodDrink,
            emoji: "🍸",
            description: "Three signature bars in one night. One drink at each, walk between, host guides the route.",
            rating: nil,
            reviewCount: nil
        ),
        LocalEvent(
            title: "Sushi Making Class",
            venue: "Mori Kitchen",
            date: "Sun 6pm",
            price: "£55",
            category: .foodDrink,
            emoji: "🍣",
            description: "Hands-on rolls with a chef. You make dinner together and eat what you make.",
            rating: 4.9,
            reviewCount: 280,
            address: "12 Cherry Lane, East Side",
            openingHours: "Class runs 6pm — 8:30pm",
            photos: ["sushi", "kitchen", "chef", "rolls"],
            highlights: ["🍣 Hands-on Rolls", "👨‍🍳 Pro Chef", "🥢 All Tools Provided"],
            reviewSnippets: [
                .init(author: "Tina",   rating: 5, text: "Chef Mori was so patient and funny. We made AND ate eight rolls."),
                .init(author: "Daniel", rating: 5, text: "We did this for our anniversary. Best date in years."),
                .init(author: "Sam",    rating: 5, text: "Bring your appetite — you make a LOT of food.")
            ],
            bookingURL: "https://www.google.com/search?q=Mori+Kitchen+sushi+class"
        ),

        // MARK: - Arts
        LocalEvent(
            title: "Pottery Class for Two",
            venue: "Mud + Wheel Studio",
            date: "Sun 2pm",
            price: "£40",
            category: .arts,
            emoji: "🏺",
            description: "Two wheels side by side, all materials included. Take home what you make.",
            rating: 4.9,
            reviewCount: 320,
            address: "8 Workshop Lane, Arts Quarter",
            openingHours: "Class runs 2pm — 4:30pm",
            photos: ["pottery", "wheel", "studio", "finished"],
            highlights: ["🏺 Two Wheels", "🎨 All Materials", "📦 Take Home"],
            reviewSnippets: [
                .init(author: "Olivia", rating: 5, text: "We laughed so much. My boyfriend's bowl looks like a sad pancake but we love it."),
                .init(author: "Ravi",   rating: 5, text: "Surprisingly meditative. The instructor was warm and encouraging."),
                .init(author: "Maya",   rating: 5, text: "Booked again the next weekend. Just a really nice afternoon.")
            ],
            bookingURL: "https://www.google.com/search?q=Mud+Wheel+Studio+pottery"
        ),
        LocalEvent(
            title: "Watercolor & Wine Night",
            venue: "Studio Bloom",
            date: "Fri 7pm",
            price: "£35",
            category: .arts,
            emoji: "🎨",
            description: "Guided painting, no skill needed, second glass on the house.",
            rating: 4.7,
            reviewCount: 610
        ),
        LocalEvent(
            title: "Photography Walking Tour",
            venue: "Meet at Old Town Square",
            date: "Sat 10am",
            price: "£20",
            category: .arts,
            emoji: "📸",
            description: "A photographer leads you through hidden corners of the old town. Bring any camera.",
            rating: nil,
            reviewCount: nil
        ),

        // MARK: - Outdoors
        LocalEvent(
            title: "Sunset Rooftop Cinema",
            venue: "Skyline Rooftop",
            date: "Fri 7pm",
            price: "£20",
            category: .outdoors,
            emoji: "🎬",
            description: "A classic film on a 30ft screen, blankets and popcorn included, drinks at the bar.",
            rating: nil,
            reviewCount: nil
        ),
        LocalEvent(
            title: "Sunrise Hike & Picnic",
            venue: "Eagle Point Trail",
            date: "Sat 6am",
            price: "Free",
            category: .outdoors,
            emoji: "🌅",
            description: "An easy 4km trail to a viewpoint. Coffee and pastries waiting at the top.",
            rating: 4.6,
            reviewCount: 145
        ),
        LocalEvent(
            title: "Botanical Garden After Dark",
            venue: "City Botanical Gardens",
            date: "Thu 8pm",
            price: "£18",
            category: .outdoors,
            emoji: "🌿",
            description: "Illuminated garden walk with a live string quartet drifting between the paths.",
            rating: 4.5,
            reviewCount: 380
        ),

        // MARK: - Nightlife
        LocalEvent(
            title: "Comedy Club Date Night",
            venue: "The Laughing Cellar",
            date: "Sat 9pm",
            price: "£22",
            category: .nightlife,
            emoji: "🎤",
            description: "Three comedians, two-drink minimum, great storytelling all evening.",
            rating: 4.6,
            reviewCount: 720
        ),
        LocalEvent(
            title: "Speakeasy Jazz Lounge",
            venue: "Hidden behind The Phone Booth",
            date: "Fri 10pm",
            price: "£15",
            category: .nightlife,
            emoji: "🥃",
            description: "Vintage cocktails, late-night sets, dim lighting. You'll need the password at the door.",
            rating: nil,
            reviewCount: nil
        )
    ]

    /// Rebuilds an event from its stable cardId — used when an app-level match
    /// listener gets a match doc (which stores only cardId + deck) and needs the
    /// full event to present the celebration. Linear scan is fine for a one-shot
    /// lookup on match delivery.
    static func byId(_ cardId: String) -> LocalEvent? {
        all.first { $0.cardId == cardId }
    }
}
