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
            category: .cosy,
            whyItWorks: "Nostalgia is a shortcut to feeling new again — same room, lit by old memory.",
            tips: [
                "Dig up the playlist before the day, not on it.",
                "Wear the same fit if you still own it. Bonus for the haircut.",
                "Tell each other one thing you remember the other forgot."
            ]
        ),
        DateCard(
            title: "Blind Taste Test",
            description: "Blindfold each other and guess mystery foods. Loser does the dishes.",
            emoji: "🍫",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Take sight away and the smallest flavours suddenly get loud — and the laughing comes easy.",
            tips: [
                "Five items each. Mix obvious with weird.",
                "Use a real blindfold, not a tea towel.",
                "Keep score. Loser owes more than dishes."
            ]
        ),
        DateCard(
            title: "Sunrise Somewhere New",
            description: "Set an early alarm. Watch the sun come up from a spot you've never been.",
            emoji: "🌅",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "There's an unspoken intimacy in being awake for something the rest of the world is sleeping through.",
            tips: [
                "Drive there in the dark. The arrival hits harder.",
                "Bring a flask. Coffee, tea — anything warm and shared.",
                "Stay until the light fully wins. Don't rush back."
            ]
        ),
        DateCard(
            title: "Paint Each Other",
            description: "Cheap canvases and paints. Paint portraits. Keep them forever.",
            emoji: "🎨",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Looking at someone long enough to paint them is its own quiet declaration.",
            tips: [
                "Twenty minutes max — perfection isn't the point.",
                "Use bold colours. Realism makes it harder, not better.",
                "Sign and date both canvases. They get better with time."
            ]
        ),
        DateCard(
            title: "Phone-Free Evening",
            description: "Both phones in a drawer from dinner until bed.",
            emoji: "📵",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "An evening with no notifications is an evening neither of you can leave halfway through.",
            tips: [
                "Pick the drawer before dinner. Friction matters.",
                "Tell anyone urgent you'll reply tomorrow.",
                "Notice the moment you reach for your pocket. That's the point."
            ]
        ),

        // Round 2
        DateCard(
            title: "Blanket Fort Movie Marathon",
            description: "Build a fort with every cushion you own. Pick a film series. No phones inside.",
            emoji: "🏰",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Building something silly together drops every defence before the film even starts.",
            tips: [
                "Strip every cushion off every sofa. Commit.",
                "String fairy lights inside if you have them.",
                "Pick the series, not just one film. Stay in."
            ]
        ),
        DateCard(
            title: "Cook Each Other's Childhood Meal",
            description: "Make the dish that reminds you of growing up. Share the story.",
            emoji: "🍲",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Childhood food is shorthand for who someone was before you knew them.",
            tips: [
                "Phone a parent for the real recipe, not Google.",
                "Cook it the way it was made for you, not how you'd improve it.",
                "Eat at the table. Tell the story between bites."
            ]
        ),
        DateCard(
            title: "The Coin Flip Day",
            description: "At every junction flip a coin for left or right. Go where chance takes you.",
            emoji: "🪙",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "Surrender the plan and the day stops being errands you ran together.",
            tips: [
                "Decide the rules before you start. Three flips minimum.",
                "Bring cash — some places that catch you won't take card.",
                "When it lands somewhere boring, flip again. The day is yours."
            ]
        ),
        DateCard(
            title: "Co-op Video Game Night",
            description: "Pick a game you have to beat together.",
            emoji: "🎮",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Failing at the same boss for an hour is a low-stakes test of how you fight together.",
            tips: [
                "Pick co-op proper — not split-screen competitive.",
                "One controller, one navigator if you're new to it.",
                "Quit while you're still laughing. Don't grind it out."
            ]
        ),
        DateCard(
            title: "The Appreciation Exchange",
            description: "Take turns saying three things you appreciate. No interrupting.",
            emoji: "💛",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Saying it out loud lands differently than thinking it — for both of you.",
            tips: [
                "Three things each. Specific beats sweeping.",
                "No interrupting. Just listen.",
                "End with one thing you want more of from them."
            ]
        ),

        // Round 3
        DateCard(
            title: "Candlelit Dinner at Home",
            description: "No takeaway. Cook together, dim the lights, phones in another room.",
            emoji: "🕯️",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Lower the lights and you both look softer — to each other and to yourselves.",
            tips: [
                "Light the candles before you start cooking, not at serving.",
                "One course you've both made before. Stress-free is the point.",
                "Save the dishes for tomorrow."
            ]
        ),
        DateCard(
            title: "The New Restaurant Rule",
            description: "Go somewhere neither of you has been. No reviews beforehand.",
            emoji: "🍽️",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "No reviews means no expectations — just the place, the food, and your reactions to it.",
            tips: [
                "Book somewhere with a chef's choice or set menu.",
                "Order whatever the table next to you ordered.",
                "Save the review for the walk home."
            ]
        ),
        DateCard(
            title: "Tourist in Your Own Town",
            description: "Visit the spots locals never go. Take cheesy tourist photos.",
            emoji: "📸",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "The places locals dismiss often turn out to be exactly the things you fell for, once.",
            tips: [
                "Make a list of three corny spots before you leave.",
                "Take the photo. The one you'd roll your eyes at.",
                "Eat where the coach parties eat. Once."
            ]
        ),
        DateCard(
            title: "Write Your Story",
            description: "Each write one paragraph, then swap. Build a ridiculous tale.",
            emoji: "✍️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Co-writing forces you to take whatever the other gives you — same as the relationship.",
            tips: [
                "Set a 60-second timer per paragraph.",
                "Never delete what the other wrote. Build, don't fix.",
                "End with a cliffhanger. Pick it up next week."
            ]
        ),
        DateCard(
            title: "Dream Planning Session",
            description: "Plan the trip you'd take if money was no object.",
            emoji: "🗺️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Planning a trip you can't yet afford is a quiet way of saying you see a future.",
            tips: [
                "Open a real map. Pin the places aloud.",
                "Pick the meal you'd eat there before the hotel.",
                "Save the plan in one note. Some of it will happen."
            ]
        ),

        // Round 4
        DateCard(
            title: "The 36 Questions",
            description: "Work through the psychology questions designed to make two people fall in love.",
            emoji: "💭",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "The questions are designed to escalate slowly — let them. Don't skip ahead.",
            tips: [
                "Brew something hot. This needs an hour, minimum.",
                "Answer in turn. No shortcuts.",
                "If a question lands hard, sit with it before moving on."
            ]
        ),
        DateCard(
            title: "Build Your Own Pizza Night",
            description: "Buy bases and toppings. Make the weirdest pizza you can.",
            emoji: "🍕",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Making your own dinner together is the smallest possible domestic adventure.",
            tips: [
                "Shop-bought bases are fine. Save your energy for toppings.",
                "Each design one weird pizza for the other to eat.",
                "Eat them straight off the tray, standing up."
            ]
        ),
        DateCard(
            title: "Sunset Walk No Destination",
            description: "Walk until the sun sets. Talk about anything except work.",
            emoji: "🚶",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Walking lowers the bar for conversation — there's no stare, just stride.",
            tips: [
                "Leave 45 minutes before sunset. Don't time it tight.",
                "Take the road you usually don't.",
                "If it goes quiet, let it. Walking quiet is different to sitting quiet."
            ]
        ),
        DateCard(
            title: "Build a Playlist for Us",
            description: "Each add 10 songs that remind you of the other.",
            emoji: "🎵",
            difficulty: .micro,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Curating songs about each other is one of the few times sentimentality is welcome.",
            tips: [
                "Don't overthink it — first ten that come to mind.",
                "Include the song that played at a moment, even if it's bad.",
                "Save it. Play it back in a year."
            ]
        ),
        DateCard(
            title: "Slow Dance in the Kitchen",
            description: "One song. No reason. Just dance together tonight.",
            emoji: "💃",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "A kitchen dance with nothing to celebrate is the kind of moment that becomes the memory.",
            tips: [
                "One song. Just one.",
                "Lean in. Don't perform.",
                "Don't bring out your phone for a video. Be there."
            ]
        ),

        // Round 5
        DateCard(
            title: "Breakfast in Bed Swap",
            description: "Each secretly makes the other breakfast in bed tomorrow morning.",
            emoji: "🥞",
            difficulty: .micro,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Being woken up by someone making effort for you is the simplest possible love language.",
            tips: [
                "Set quiet alarms an hour apart.",
                "Keep it small — toast and tea beat a feast nobody asked for.",
                "Bring a tiny extra: a flower, a note, a song."
            ]
        ),
        DateCard(
            title: "Cocktail Lab",
            description: "Invent two original cocktails. Name them after each other.",
            emoji: "🍸",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Naming a drink after each other gives you something silly and permanent to argue about.",
            tips: [
                "Three ingredients max. Anything more becomes a chore.",
                "Taste, adjust, name. Don't write the recipe first.",
                "Make a second round. The first one is always wrong."
            ]
        ),
        DateCard(
            title: "Try a Class Together",
            description: "Pottery, dance, climbing — book something neither has done.",
            emoji: "🎯",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "Being beginners side by side resets the dynamic — neither of you gets to be the expert.",
            tips: [
                "Book it tonight. The hesitation is what kills it.",
                "Pick something neither of you would normally do.",
                "Plan a drink after — you'll have things to debrief."
            ]
        ),
        DateCard(
            title: "The Memory Jar",
            description: "Decorate a jar. Each week add a happy moment note. Open next year.",
            emoji: "🫙",
            difficulty: .micro,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Tiny weekly notes turn into a real archive of the year you forgot you were having.",
            tips: [
                "Keep the jar somewhere you both pass daily.",
                "One sentence per note. No essays.",
                "Set a date next year to open it together."
            ]
        ),
        DateCard(
            title: "The Time Capsule Letter",
            description: "Each write a letter to open on your next anniversary.",
            emoji: "✉️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Writing to your future self is one of the only ways to notice how much you've changed.",
            tips: [
                "Hand-write it. Typing makes it forgettable.",
                "Include one prediction, one fear, one wish.",
                "Seal it. Don't peek. Set a calendar reminder."
            ]
        ),

        // Round 6
        DateCard(
            title: "Living Room Camping",
            description: "Sleeping bags, fairy lights, snacks, ghost stories. Camp without leaving home.",
            emoji: "⛺",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Recreating childhood makes you both younger for an evening, which is no small thing.",
            tips: [
                "Fairy lights count as stars. Use them.",
                "Snack like nine-year-olds: crisps, biscuits, juice.",
                "Tell one real ghost story. Not invented — remembered."
            ]
        ),
        DateCard(
            title: "Bake Something That Scares You",
            description: "Pick the most ambitious recipe you'd never try. Bake it together.",
            emoji: "🎂",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Choosing the recipe you've been intimidated by makes the win shared, not solo.",
            tips: [
                "Read the recipe twice, all the way through, before starting.",
                "Set out every ingredient first. Mise en place saves the marriage.",
                "If it flops, photograph it anyway. Disaster bakes get the most likes."
            ]
        ),
        DateCard(
            title: "The Stargazing Mission",
            description: "Drive somewhere dark. Bring blankets. Find three constellations.",
            emoji: "⭐",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Looking up at the same sky reminds you both how small the rest of the noise is.",
            tips: [
                "Drive at least 30 minutes from any city lights.",
                "Let your eyes adjust for 10 minutes before you start naming things.",
                "Bring one blanket to lie on, one to share."
            ]
        ),
        DateCard(
            title: "Learn Each Other's Hobby",
            description: "Spend an evening teaching each other something you love.",
            emoji: "🎸",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Showing someone the thing you love lets them see a version of you they don't usually meet.",
            tips: [
                "Teach the way you wish you'd been taught.",
                "Start with the easiest version, not the show-off one.",
                "Trade in the same evening — go both ways."
            ]
        ),
        DateCard(
            title: "Massage Exchange",
            description: "Take turns. 15 minutes each. No phones, soft music.",
            emoji: "💆",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate,
            whyItWorks: "Slow, attentive touch in silence is harder than it sounds and worth more than it costs.",
            tips: [
                "Warm the oil in your hands first. Cold ruins it.",
                "Fifteen minutes each. Set a timer.",
                "No talking. Just hands and breath."
            ]
        ),

        // Round 7
        DateCard(
            title: "Read to Each Other",
            description: "Pick a book. Take turns reading a chapter aloud before bed.",
            emoji: "📖",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Being read to is a kind of care most people last received as children.",
            tips: [
                "Pick something with momentum — short chapters, real plot.",
                "Swap halfway through. Don't hog the voice.",
                "Stop on a cliffhanger. That's how you stay hooked."
            ]
        ),
        DateCard(
            title: "Street Food Tour",
            description: "Three food spots in one evening — starter, main, dessert, each somewhere new.",
            emoji: "🌮",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "Three small stops beat one big meal — more places, more conversation, less commitment.",
            tips: [
                "Walk between stops. The hunger has to come back.",
                "One starter, one main, one pud. Different streets if you can.",
                "Pay for the dessert without warning."
            ]
        ),
        DateCard(
            title: "Pick a Pin on the Map",
            description: "Drop a pin within an hour's travel, go explore whatever's there.",
            emoji: "📍",
            difficulty: .adventure,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "Letting the map choose forces you to find the interesting thing instead of expecting it.",
            tips: [
                "Close your eyes when you drop the pin. No cheating.",
                "Hour cap on travel. The point is the spot, not the drive.",
                "Don't Google it first. Arrive blind."
            ]
        ),
        DateCard(
            title: "Photo Scavenger Hunt",
            description: "List 10 things to photograph together. First to all 10 wins.",
            emoji: "📷",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Looking for something specific makes you notice the city you usually walk through.",
            tips: [
                "Pick weird categories — a yellow door, a stranger's dog, the word 'wait'.",
                "Set a 90-minute clock. Pressure makes it a game.",
                "Print the best one when you get home."
            ]
        ),
        DateCard(
            title: "Look Through Old Photos",
            description: "Go through photos from when you first met.",
            emoji: "🖼️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Seeing yourselves from before you were 'you two' is its own kind of love letter.",
            tips: [
                "Start with the oldest folder. Work forward.",
                "Pause on the one you barely remember being taken.",
                "Pick a favourite each. Set them as your home screens."
            ]
        ),

        // Round 8
        DateCard(
            title: "Spa Night",
            description: "Face masks, foot rubs, calming playlist. Pamper each other.",
            emoji: "🧖",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Looking after each other with no agenda is the kind of evening you both forget to plan.",
            tips: [
                "Phones in another room. The whole point is no buzzing.",
                "Music low. Lights lower.",
                "Trade — face mask one, foot rub the other, then swap."
            ]
        ),
        DateCard(
            title: "Breakfast for Dinner",
            description: "Pancakes, eggs, the works — at 8pm in your pyjamas.",
            emoji: "🍳",
            difficulty: .micro,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Eating pancakes at 8pm in your pyjamas is a small rebellion against the day.",
            tips: [
                "Cook one each. Don't share a pan.",
                "Stack everything. Height is half the appeal.",
                "Maple syrup is non-negotiable."
            ]
        ),
        DateCard(
            title: "Bike Ride to Nowhere",
            description: "Ride somewhere you've never explored. Stop for snacks.",
            emoji: "🚲",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "Bikes give you a wider radius than walking but slow enough to actually talk.",
            tips: [
                "Pick a direction, not a destination.",
                "Carry one snack each. You'll need it sooner than you think.",
                "Stop the moment something interesting appears."
            ]
        ),
        DateCard(
            title: "DIY Something for Home",
            description: "Build, paint or make one thing for your space together.",
            emoji: "🔨",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Making one shared object together quietly turns 'your place' into 'ours'.",
            tips: [
                "Keep the scope tiny — a shelf, a frame, a planter.",
                "Decide colours together before you buy paint.",
                "Hang it somewhere you'll both see daily."
            ]
        ),
        DateCard(
            title: "The Big Questions Night",
            description: "Talk about dreams, fears, where you see us in 5 years.",
            emoji: "🌌",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Couples drift apart less from fighting and more from never asking the big things again.",
            tips: [
                "Pour something to share. This needs an evening, not an hour.",
                "One question at a time. Both answer fully.",
                "End with: 'What would I never know to ask you?'"
            ]
        ),

        // MARK: - Content Pack (100 additions)

        // Cosy Night In
        DateCard(
            title: "Blanket Fort Cinema",
            description: "Build a fort with every cushion you own and watch the film one of you has been \"meaning to show\" the other for years.",
            emoji: "🛋️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Watching the film one of you has been pushing for years is a small gift you keep delaying.",
            tips: [
                "Cushions off every chair. Don't half-build it.",
                "Snack the way you would in a real cinema.",
                "No checking your phone — even at the slow bits."
            ]
        ),
        DateCard(
            title: "Two-Person Bake-Off",
            description: "Same recipe, separate bowls, no helping. Judge each other's results with brutal honesty and a kiss.",
            emoji: "🧁",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Same brief, different bowls — you'll be surprised what each of you reaches for.",
            tips: [
                "Pick a recipe with room for interpretation — cookies over bread.",
                "No tasting each other's mid-bake.",
                "Judge with kissed feedback only."
            ]
        ),
        DateCard(
            title: "Candlelit Floor Picnic",
            description: "Move dinner to a blanket on the living room floor, lights off, candles only.",
            emoji: "🪔",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Eating on the floor by candlelight strips away the small formalities of the dinner table.",
            tips: [
                "Real candles, not LED. The flicker matters.",
                "Finger food only. Cutlery breaks the spell.",
                "Stay there after the food — that's where the talk happens."
            ]
        ),
        DateCard(
            title: "The Reverse Day",
            description: "Breakfast for dinner, pyjamas all evening, dessert first. Do the whole night backwards.",
            emoji: "🌙",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Inverting the routine for one night reminds you the routine was a choice.",
            tips: [
                "Commit fully. Dessert first means dessert first.",
                "Pyjamas before sunset. No changing back.",
                "Skip the part you usually do last and replace it with kissing."
            ]
        ),
        DateCard(
            title: "Handwritten Letter Swap",
            description: "Write each other a letter by hand, seal it, swap, read in silence.",
            emoji: "💌",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Handwriting forces a slower thought — what you write down is what you actually mean.",
            tips: [
                "Use proper paper. The cheap stuff cheapens it.",
                "Don't read each other's drafts. Seal first.",
                "Read in the same room, in silence."
            ]
        ),
        DateCard(
            title: "Old Photos, New Wine",
            description: "Open a bottle and scroll back through every photo of you two from the very beginning.",
            emoji: "🍷",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate,
            whyItWorks: "A bottle and a camera roll is a cheaper, better therapy session than most.",
            tips: [
                "Start at the very beginning of you two.",
                "Pause on the photos where you both look different.",
                "Pick the one to print before you finish the bottle."
            ]
        ),
        DateCard(
            title: "Living Room Camp-Out",
            description: "Sleeping bags, fairy lights, phone torches as \"stars,\" ghost stories optional.",
            emoji: "⛺",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Camp gear indoors hits the comfort sweet spot — adventure-shaped, but you sleep in your own bed.",
            tips: [
                "Sleeping bags on the floor, not the sofa.",
                "Phone torches for stars. The illusion is the joy.",
                "One real story each, before you sleep."
            ]
        ),
        DateCard(
            title: "Cook Without a Recipe",
            description: "Open the fridge, pick five things, invent a dish together. No looking anything up.",
            emoji: "🥘",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Improvising a meal together is a stress test in the most low-stakes possible form.",
            tips: [
                "Open the fridge first. Cook with what's there.",
                "No looking anything up. Use what you remember.",
                "Plate it like a restaurant, even if it's chaos."
            ]
        ),
        DateCard(
            title: "The Massage Trade",
            description: "Ten minutes each, no talking, just hands and quiet music.",
            emoji: "🤲",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Touch with no talk forces the slow attention that words usually rush past.",
            tips: [
                "Warm hands first. Run them under water if you have to.",
                "Ten minutes a side. Timer on, talking off.",
                "End with a long hug, not a thank-you."
            ]
        ),
        DateCard(
            title: "Playlist Confessions",
            description: "Each build a 5-song playlist of \"songs that remind me of you,\" then explain every choice.",
            emoji: "🎶",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Songs say things about how you feel that you'd be too embarrassed to say plainly.",
            tips: [
                "Five songs each. Don't go over.",
                "Explain the choice before pressing play.",
                "Save the playlist. It outlasts the evening."
            ]
        ),

        // Foodie
        DateCard(
            title: "Order in a Language You Don't Speak",
            description: "Find a restaurant whose menu you can't read and order purely by pointing and hoping.",
            emoji: "🍜",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "Pointing at the menu is how you discover the dish you would never have ordered.",
            tips: [
                "Pick somewhere with no English on the menu.",
                "Order three things, not one. Spread the risk.",
                "Ask the waiter what their favourite is, even if neither of you speaks the language."
            ]
        ),
        DateCard(
            title: "The Tenner Dinner Challenge",
            description: "Each given a tenner, separate shops, meet back home and combine whatever you bought into one meal.",
            emoji: "💷",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Constraint is the mother of resourcefulness — also of laughter at the till.",
            tips: [
                "Different shops. No texting strategy.",
                "Buy something you didn't plan on the way back.",
                "Cook together. You're a team again at the chopping board."
            ]
        ),
        DateCard(
            title: "Dessert Crawl",
            description: "Skip dinner entirely. Visit three places and order only the pudding at each.",
            emoji: "🍰",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "Skipping dinner for three puddings is the kind of unserious decision long relationships need more of.",
            tips: [
                "Three different places. No repeats.",
                "Share one fork. Bites taste better that way.",
                "Rank them on the walk home."
            ]
        ),
        DateCard(
            title: "Recreate Your First-Date Meal",
            description: "Find or cook exactly what you ate the first time you went out.",
            emoji: "💝",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Eating exactly what you ate that night is the closest thing to time travel you'll cheaply get.",
            tips: [
                "Order the same drink too. The drink anchors the memory.",
                "Sit on the same side of the table you sat on then.",
                "Tell each other one thing you got wrong about the other that first night."
            ]
        ),
        DateCard(
            title: "Five-Way Blind Taste Test",
            description: "Buy five versions of one thing (chocolate, cheese, crisps). Blindfold, rank, argue.",
            emoji: "🫐",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Blind tasting is the quickest way to find out you actually love the cheap version.",
            tips: [
                "Choose one category. Don't mix chocolate with crisps.",
                "Properly blindfolded. No squinting.",
                "Score on a card, then reveal. The arguing is the fun."
            ]
        ),
        DateCard(
            title: "Cook Your Grandmother's Recipe",
            description: "One of you teaches the other a dish from your family. Phone home if you have to.",
            emoji: "👵",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Recipes from family kitchens carry more than ingredients — they carry the people.",
            tips: [
                "Call home before you start. Get the version that isn't written down.",
                "Cook it the way she'd cook it, not the way you'd modernise it.",
                "Say her name out loud at the table."
            ]
        ),
        DateCard(
            title: "Street Food Hunt",
            description: "Pick a market and share one thing from every stall that catches your eye.",
            emoji: "🌭",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "Shared bites at every stall make the market feel less like a meal and more like a tour.",
            tips: [
                "Cash. Markets hate cards.",
                "One item per stall, split it.",
                "Don't fill up at the first one. Pace."
            ]
        ),
        DateCard(
            title: "The Spice Dare",
            description: "Cook one dish, add increasing heat, see who taps out first.",
            emoji: "🌶️",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Suffering together is one of the older relationship bonds — also one of the funniest.",
            tips: [
                "Cook one dish, three heat levels.",
                "Glass of milk visible at the table.",
                "Whoever taps out cleans the kitchen."
            ]
        ),
        DateCard(
            title: "Breakfast in a New Town",
            description: "Drive somewhere you've never had breakfast and find the busiest café.",
            emoji: "🥐",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "Breakfast in an unfamiliar place is the cheapest possible mini-break.",
            tips: [
                "Drive 45 minutes minimum. The point is somewhere new.",
                "Find the busiest café. The locals know.",
                "Skip the obvious tourist café. Take the next door down."
            ]
        ),
        DateCard(
            title: "Make Pasta From Scratch",
            description: "Flour, eggs, a rolling pin, low expectations, high laughter.",
            emoji: "🍝",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Flour, eggs, and an hour together is one of the rare meals where the doing beats the eating.",
            tips: [
                "Eggs at room temperature. Cold eggs split the dough.",
                "Don't measure perfectly. Pasta forgives.",
                "Cook a small portion first to test. Adjust the rest."
            ]
        ),

        // Adventure & Outdoors
        DateCard(
            title: "Coin-Flip Road Trip",
            description: "At every junction, flip a coin: heads left, tails right. Drive for an hour. See where you land.",
            emoji: "🛣️",
            difficulty: .adventure,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "Coin flips strip the day of agenda and put both of you in the same passenger seat.",
            tips: [
                "Flip out loud — neither of you cheats.",
                "Stop the moment something looks worth stopping for.",
                "Eat where the coin sends you, even if it's a petrol station meal deal."
            ]
        ),
        DateCard(
            title: "Sunrise You'll Regret Setting an Alarm For",
            description: "Pick a high spot, set a 5am alarm, bring coffee in a flask.",
            emoji: "🌄",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "The cost of the early alarm is exactly what makes the sunrise feel earned.",
            tips: [
                "Pack the flask and coats the night before.",
                "Scout the spot beforehand if you can — no headtorching at 4am.",
                "Stay until the sky settles into proper morning."
            ]
        ),
        DateCard(
            title: "The Unplanned Train",
            description: "Go to the station, take the next train leaving, get off when somewhere looks interesting.",
            emoji: "🚆",
            difficulty: .adventure,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "Taking the next train out is the lowest-effort version of a real adventure.",
            tips: [
                "No checking the route beforehand.",
                "Get off when the platform looks interesting.",
                "Plan only one thing: how you'll get back."
            ]
        ),
        DateCard(
            title: "Wild Swim",
            description: "Find a lake, river, or sea spot and get in. Scream together about the cold.",
            emoji: "🏊",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Cold water rewires your brain for a few minutes — and you remember it for years.",
            tips: [
                "Check tides or river flow. Boring but necessary.",
                "Towel and dry clothes in the car. Future-you will thank you.",
                "Get in fully. Wading doesn't count."
            ]
        ),
        DateCard(
            title: "Map Pin Dart",
            description: "Drop a pin somewhere within an hour's drive without looking, then go there.",
            emoji: "🎯",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "Drop a pin without looking and the day arranges itself around the chance you took.",
            tips: [
                "Eyes shut. Index finger. No retries.",
                "Hour's drive cap. Discipline matters.",
                "Don't read about it on the way. Arrive cold."
            ]
        ),
        DateCard(
            title: "Golden Hour Walk",
            description: "Plan a walk that ends at the best view exactly as the sun goes down.",
            emoji: "🌇",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Timing a walk to the light makes you both notice things you usually march past.",
            tips: [
                "Leave an hour before sunset. Don't time it perfectly — overshoot a touch.",
                "Walk west, generally.",
                "Take one photo, not twenty."
            ]
        ),
        DateCard(
            title: "Forage and Cook",
            description: "Pick blackberries, wild garlic, or whatever's in season, then cook with it.",
            emoji: "🍄",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Picking your own ingredients ties the meal to the afternoon in a way shopping never does.",
            tips: [
                "Only pick what you can 100% identify.",
                "Bring a paper bag — plastic crushes everything.",
                "Cook simply. Foraged ingredients want plain partners."
            ]
        ),
        DateCard(
            title: "Stargazing Drive",
            description: "Get away from city lights with a blanket and an app that names what you're looking at.",
            emoji: "🔭",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "Lying back under a real sky is the kind of thing your phone can't replicate.",
            tips: [
                "Get an hour from city lights, minimum.",
                "Let your eyes adjust. Don't open your phone.",
                "Bring layers — you'll be still for longer than you expect."
            ]
        ),
        DateCard(
            title: "The Tourist in Your Own City",
            description: "Do the most obvious tourist thing in your town that you've never bothered to do.",
            emoji: "🗺️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "The corny thing you've always avoided turns out to be why people visit in the first place.",
            tips: [
                "Book in advance if it has a queue. The queue ruins the magic.",
                "Take the photo. Embrace the corn.",
                "End at a pub locals use, not tourists."
            ]
        ),
        DateCard(
            title: "Cycle to Nowhere",
            description: "Two bikes, no destination, turn back when one of you gets hungry.",
            emoji: "🚴",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Two bikes and no plan is the right speed for a day with no agenda.",
            tips: [
                "Tyres checked the night before.",
                "Snack and water packed.",
                "Turn back when one of you wants to. No martyrdom."
            ]
        ),

        // Creative & Playful
        DateCard(
            title: "Ten-Minute Portraits",
            description: "Cheap paints, two canvases, ten-minute portraits of each other. Frame the worst one.",
            emoji: "🖌️",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Painting each other badly is the surest way to keep something real on the wall.",
            tips: [
                "Set a 10-minute timer. Don't overshoot.",
                "Use one paintbrush and three colours, max.",
                "Frame the worst one. Genuinely."
            ]
        ),
        DateCard(
            title: "Write a Song About Today",
            description: "Doesn't matter if it's terrible. Three verses about your day, performed seriously.",
            emoji: "🎤",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Writing about a day forces you to notice what was actually in it.",
            tips: [
                "Three verses, one chorus. Don't aim for a hit.",
                "One writes verses, one writes chorus, then swap.",
                "Perform it standing. Sit-down songs don't land."
            ]
        ),
        DateCard(
            title: "The Pottery Disaster",
            description: "Air-dry clay on the kitchen table. Make each other a \"gift.\" Keep it forever.",
            emoji: "🏺",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Air-dry clay on the kitchen table is the right amount of mess for one good evening.",
            tips: [
                "Cover the table. Clay gets everywhere.",
                "Make something for the other, not for yourself.",
                "Keep it terrible. Don't redo."
            ]
        ),
        DateCard(
            title: "Build Something Flat-Pack",
            description: "Get the cheapest flat-pack furniture, no arguing allowed, time yourselves.",
            emoji: "🪛",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "The flat-pack test is whether you can stay light when the instructions don't make sense.",
            tips: [
                "One reads the instructions, one builds. Then swap.",
                "No phones for distraction. Stay in the project.",
                "Time yourselves. It's funnier if you fail the time."
            ]
        ),
        DateCard(
            title: "Two-Person Photoshoot",
            description: "One photographs, one poses, then swap. Find your most ridiculous and your most beautiful shot.",
            emoji: "📸",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Taking each other seriously behind the camera is a small, kind act of attention.",
            tips: [
                "Outside. Natural light is forgiving.",
                "Take one ridiculous, one beautiful.",
                "Show each other the photo of them you like best."
            ]
        ),
        DateCard(
            title: "Invent a Cocktail",
            description: "Name it after your relationship. Write the recipe down. Make it your \"house drink.\"",
            emoji: "🍹",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Inventing a 'house drink' is one of the rare things that quietly belongs only to the two of you.",
            tips: [
                "Three ingredients max.",
                "Name it before you fully like it. Pressure helps.",
                "Write the recipe on a card. Stick it in the kitchen."
            ]
        ),
        DateCard(
            title: "The Jigsaw Race",
            description: "Two small jigsaws, start at the same time, loser does the washing up.",
            emoji: "🧩",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "A small puzzle each makes a quiet evening feel like a contest, in the good way.",
            tips: [
                "Same size puzzles. No handicaps.",
                "Start on three. Mean it.",
                "Loser does the washing up — same night, no postponing."
            ]
        ),
        DateCard(
            title: "Draw Your Future House",
            description: "Each sketch the home you'd build together, then merge the two into one.",
            emoji: "🏡",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Drawing the house you'd build is a sneaky way of admitting what you want from the rest of your life.",
            tips: [
                "No looking at each other's sketch until both are done.",
                "Include the room you'd disagree on.",
                "Try to merge them into one drawing. That's where the conversation happens."
            ]
        ),
        DateCard(
            title: "Make a Zine About Us",
            description: "Fold paper into a tiny booklet, fill it with drawings and inside jokes.",
            emoji: "📓",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "A tiny handmade booklet is the kind of artefact that survives moves and matters more than expected.",
            tips: [
                "Fold one A4 sheet into eight pages. Don't overscope.",
                "Inside jokes are the whole point. Don't worry about coherence.",
                "Keep it somewhere obvious, not in a drawer."
            ]
        ),
        DateCard(
            title: "Lip-Sync Battle",
            description: "One song each, full commitment, phone on a tripod, no mercy.",
            emoji: "🎙️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Performing badly on purpose dissolves the small armour of taking yourself seriously.",
            tips: [
                "One song each. Choose for each other, not yourself.",
                "Phone on a tripod or a stack of books.",
                "Full commitment. Half-arsed is the only way to lose."
            ]
        ),

        // Intimate & Connection
        DateCard(
            title: "Eye Contact for Four Minutes",
            description: "Set a timer, sit knee to knee, just look. It gets weird, then it gets real.",
            emoji: "👀",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Four uninterrupted minutes of looking is longer than you've spent doing it in months.",
            tips: [
                "Sit knee-to-knee. Closer than feels normal.",
                "No phones in the room. Not even face-down.",
                "If it gets awkward, stay. The point is past the awkward."
            ]
        ),
        DateCard(
            title: "The Gratitude Round",
            description: "Take turns naming one thing you're grateful for about the other, until you run out.",
            emoji: "🙏",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Couples drift not from lack of love but from forgetting to say it. This is the antidote.",
            tips: [
                "Take turns. Don't pile up.",
                "Specific. 'You always know when I need quiet' beats 'you're kind'.",
                "Go until you genuinely run out. That's longer than you think."
            ]
        ),
        DateCard(
            title: "Slow Dance, No Occasion",
            description: "One song, kitchen floor, no reason. Just because.",
            emoji: "🩰",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Dancing without a wedding or a New Year's Eve is the kind of small ceremony a relationship runs on.",
            tips: [
                "One song, no more.",
                "Kitchen, hallway, anywhere with floor.",
                "Hold tight. Don't sway like you're being watched."
            ]
        ),
        DateCard(
            title: "Read to Each Other in Bed",
            description: "One chapter of a book, out loud, lights low.",
            emoji: "📚",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Being read to in bed is a kind of care that doesn't ask anything in return.",
            tips: [
                "One chapter, not a whole book.",
                "Lights dim. Voice lower than usual.",
                "Pause at the good sentence. Re-read it."
            ]
        ),
        DateCard(
            title: "The \"Remember When\" Game",
            description: "Trade your favourite memories of each other until one of you cries (happy tears).",
            emoji: "🎞️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Trading memories back and forth is how a relationship audits how much it's lived through.",
            tips: [
                "Start light. Get serious gradually.",
                "Don't compete on memory — fill in each other's gaps.",
                "End on the one that makes one of you cry. Happy tears."
            ]
        ),
        DateCard(
            title: "Phone-Free Dinner",
            description: "Both phones in a drawer in another room. Just talk. See how long it really lasts.",
            emoji: "🤫",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Removing the phone removes the side-exit from the conversation.",
            tips: [
                "Both phones in a drawer in another room.",
                "Tell anyone urgent you'll reply tomorrow.",
                "Notice when you reach for your pocket. That's the moment that matters."
            ]
        ),
        DateCard(
            title: "Trace and Tell",
            description: "Draw a slow line down your partner's arm with a fingertip and tell them one thing you love about them.",
            emoji: "🤍",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "A slow fingertip and one honest sentence at a time slows the night down to relationship pace.",
            tips: [
                "Lights low. Music optional but quiet.",
                "Take turns — three each.",
                "Specific. 'I love how you laugh when you're tired' beats 'I love you'."
            ]
        ),
        DateCard(
            title: "The Closeness Questions",
            description: "Work through a few of the famous get-closer questions over tea.",
            emoji: "💞",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "These questions work because they make you ask things you'd otherwise wait years to bring up.",
            tips: [
                "Cup of tea each. Settle in.",
                "Take the question seriously. No deflecting with jokes.",
                "If a question hits, sit with it before moving on."
            ]
        ),
        DateCard(
            title: "Bath and Talk",
            description: "Run a bath, no agenda, just float and chat.",
            emoji: "🛁",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "A shared bath with no agenda is one of the more honest places to have a conversation.",
            tips: [
                "Bath bombs or oil. Make it nice.",
                "Phones not in the room. Obvious but easy to forget.",
                "Talk about whatever surfaces. Don't bring a topic."
            ]
        ),
        DateCard(
            title: "Make a Wish List for Us",
            description: "Each write five things you want to do together this year, then read them aloud.",
            emoji: "📝",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Putting your shared wants on paper makes them real — and accountable.",
            tips: [
                "Five things each. Small to big.",
                "Read aloud. Don't pass the paper.",
                "Pick the first one to do this month."
            ]
        ),

        // Rainy Day / Low Energy
        DateCard(
            title: "The Duvet Day",
            description: "Cancel everything, stay in bed, order food, watch a whole series.",
            emoji: "🛏️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Choosing to do nothing together is its own act of intimacy — you're not avoiding each other.",
            tips: [
                "Decide on the series before you cancel everything.",
                "Order food before you're starving.",
                "Get up only when one of you genuinely wants to."
            ]
        ),
        DateCard(
            title: "Puzzle and Podcast",
            description: "A big jigsaw and a podcast you both like. Quiet, easy, together.",
            emoji: "🎧",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "A puzzle and a podcast is the right shape of evening when neither of you can be entertained at.",
            tips: [
                "Bigger puzzle than you think. Small ones finish too fast.",
                "Pick a podcast you've both started, not new.",
                "Don't talk. The shared quiet is the point."
            ]
        ),
        DateCard(
            title: "Build the Ultimate Hot Drink",
            description: "Hot chocolate with everything: cream, marshmallows, a sneaky shot.",
            emoji: "☕",
            difficulty: .micro,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Hot drinks built to excess are a small luxury that costs nothing and lasts an evening.",
            tips: [
                "Cream, marshmallows, a chocolate bar broken into it.",
                "Sneaky shot if you're up for it.",
                "Drink it on the sofa. Don't take it to the desk."
            ]
        ),
        DateCard(
            title: "Window-Watch the Storm",
            description: "Two chairs at the window, a blanket, watch the rain do its thing.",
            emoji: "🌧️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Storms watched together feel less like weather and more like an event you both attended.",
            tips: [
                "Two chairs at the window, side by side.",
                "Blanket over both of you.",
                "No commentary. Just watch."
            ]
        ),
        DateCard(
            title: "Learn One Card Trick Each",
            description: "Ten minutes of online tutorials, then perform for each other.",
            emoji: "🃏",
            difficulty: .micro,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Ten minutes of YouTube and a deck of cards is the cheapest performance you'll do all year.",
            tips: [
                "Easy ones — 'the four aces', 'pick a card'.",
                "Practise once in private, then perform.",
                "Loser does next week's washing up."
            ]
        ),
        DateCard(
            title: "The Nap Date",
            description: "Yes, a nap counts. Curl up, set no alarm, that's the whole date.",
            emoji: "😴",
            difficulty: .micro,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Choosing a nap as a date acknowledges that being tired together is sometimes the best you've got.",
            tips: [
                "Curtains closed, phones on Do Not Disturb.",
                "Don't set an alarm.",
                "Cuddle, don't sprawl. The point is closeness."
            ]
        ),
        DateCard(
            title: "Reorganise One Drawer Together",
            description: "Oddly satisfying, weirdly bonding, find something you forgot you owned.",
            emoji: "🗄️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .cosy,
            whyItWorks: "Tackling a drawer together is the kind of micro-project that's quietly bonding.",
            tips: [
                "One drawer. Not a whole cupboard.",
                "Bin three things you haven't touched in a year.",
                "Find something forgotten — that's the bonus."
            ]
        ),
        DateCard(
            title: "Indoor Picnic Under the Table",
            description: "Recreate childhood. Crackers, cheese, juice in wine glasses.",
            emoji: "🧺",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Eating under the table puts you both back inside a slightly silly version of yourselves.",
            tips: [
                "Tablecloth over the table, blanket underneath.",
                "Finger food only. No plates.",
                "Juice in wine glasses. Always."
            ]
        ),
        DateCard(
            title: "Two-Player Game Night",
            description: "Co-op a video or board game. Blame each other loudly when you lose.",
            emoji: "🎲",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Co-op gaming is one of the few places where your reflexes for working together get tested in real time.",
            tips: [
                "Co-op only. Competitive games are a different evening.",
                "Snacks within reach.",
                "Quit while it's still fun. Don't grind into resentment."
            ]
        ),
        DateCard(
            title: "Face Mask and Trash TV",
            description: "Skincare neither of you understands and the worst reality show you can find.",
            emoji: "📺",
            difficulty: .quick,
            estimatedCost: .low,
            category: .cosy,
            whyItWorks: "Bad TV with skincare you don't understand is a kind of restorative idleness you can't schedule into a calendar.",
            tips: [
                "Pick the worst show on the menu. The worse the better.",
                "Set a 20-minute timer on the mask. Don't wing it.",
                "Comment freely. The show invites it."
            ]
        ),

        // Special Occasion / Milestone
        DateCard(
            title: "The Anniversary Map",
            description: "Pin every place that mattered in your relationship and revisit one.",
            emoji: "📌",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .intimate,
            whyItWorks: "A map of the places that mattered is a record of who you've already been together.",
            tips: [
                "Pin the silly places too — the petrol station, the bench.",
                "Pick one you haven't been back to. Revisit.",
                "Take a photo at the spot, then compare to the original."
            ]
        ),
        DateCard(
            title: "Recreate the First Date",
            description: "Same place, same order, same outfits if you can remember them.",
            emoji: "💕",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .intimate,
            whyItWorks: "Going back to where you started — with everything you now know — recasts that night in a new light.",
            tips: [
                "Same place if it's still open. If not, the closest version.",
                "Order what you ordered, dress how you dressed.",
                "Talk about what you remember being nervous about."
            ]
        ),
        DateCard(
            title: "Open the Time Capsule",
            description: "Write letters to each other, seal them, plan to open them in exactly one year.",
            emoji: "📦",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Opening last year's letter shows you how much the small worries shrink in hindsight.",
            tips: [
                "Schedule the open date the moment you seal it.",
                "Read alone first, then aloud.",
                "Write a new one straight after. Keep the loop going."
            ]
        ),
        DateCard(
            title: "The Year in Review Night",
            description: "Look back at everything you did this year together and pick your top three moments.",
            emoji: "📅",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Couples remember the bad year more clearly than the good — this fixes that.",
            tips: [
                "Scroll back through your camera roll together.",
                "Each pick a top three.",
                "Pick one thing you want to do more of next year."
            ]
        ),
        DateCard(
            title: "Renew Your Tiny Vows",
            description: "Not married? Make up your own vows for the next year and say them anyway.",
            emoji: "💍",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Writing your own vows once a year quietly resets the contract you live by.",
            tips: [
                "Hand-write them. Typing makes them lifeless.",
                "Promise three things, not ten.",
                "Read them out loud, at home, candle on the table."
            ]
        ),
        DateCard(
            title: "The Birthday Surprise Swap",
            description: "Each plan a 2-hour surprise for the other on the same day.",
            emoji: "🎁",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .intimate,
            whyItWorks: "Planning a surprise for someone who's planning one for you is a strange, lovely tension.",
            tips: [
                "Same day, two-hour blocks, no overlapping.",
                "No checking what the other is up to. Trust.",
                "Debrief over dinner. Both at the same restaurant, neither booked."
            ]
        ),
        DateCard(
            title: "Revisit Where You Said \"I Love You\"",
            description: "Go back to the exact spot. Say it again.",
            emoji: "💖",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate,
            whyItWorks: "Going back to the exact spot makes the words land all over again.",
            tips: [
                "Same time of day if you can.",
                "Don't rehearse. Just be there.",
                "Say it again. Out loud. Even if it feels theatrical."
            ]
        ),
        DateCard(
            title: "The Future Letter",
            description: "Write to your relationship five years from now. Hide it somewhere you'll find it.",
            emoji: "🕰️",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Writing to your relationship five years from now is a promise hidden as a letter.",
            tips: [
                "Hand-write. Seal. Date the envelope.",
                "Hide it somewhere you'll find it accidentally.",
                "Don't talk about what's inside."
            ]
        ),
        DateCard(
            title: "Celebrate a Half-Anniversary",
            description: "Why wait for the full year? Mark six months with something small and silly.",
            emoji: "🥂",
            difficulty: .quick,
            estimatedCost: .low,
            category: .intimate,
            whyItWorks: "Celebrating six months without occasion is exactly the kind of small ritual that adds up over years.",
            tips: [
                "Mark it with one small thing — a meal, a walk, a card.",
                "Don't overscope. The point is the gesture.",
                "Schedule it now so you don't forget next year either."
            ]
        ),
        DateCard(
            title: "The Milestone Feast",
            description: "Cook the most ambitious meal you've ever attempted to mark something big.",
            emoji: "🍽️",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "Cooking something beyond your usual range together is the kind of project that becomes the memory.",
            tips: [
                "Pick the recipe a week in advance. Shop properly.",
                "Cook side by side. Don't divide the kitchen.",
                "Sit down to eat at the table, not the counter."
            ]
        ),

        // Out & About
        DateCard(
            title: "Gallery Whisper Game",
            description: "At a museum, make up the real story behind each painting in whispers.",
            emoji: "🏛️",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "Making up the story behind each painting is a low-effort excuse to be in a quiet beautiful room together.",
            tips: [
                "Whisper. Don't actually disturb anyone.",
                "Read the placard after you've made up the story.",
                "Pick a favourite painting each. Tell each other why."
            ]
        ),
        DateCard(
            title: "The Charity Shop Challenge",
            description: "A fiver each, find the other the most \"them\" item in the shop.",
            emoji: "🛍️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "Hunting for the most 'them' item in a charity shop is half-shopping, half love letter.",
            tips: [
                "Fiver each, hard cap.",
                "Different shops or different aisles.",
                "Wear or use what they bought you, at least once."
            ]
        ),
        DateCard(
            title: "Bookshop Blind Date",
            description: "Each pick a book for the other based on the cover alone. Buy it. Read it.",
            emoji: "📖",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Picking books by the cover is the most honest way to discover what someone wants you to read.",
            tips: [
                "One book each. Cover only — no reading the back.",
                "Buy them. Borrowing reduces commitment.",
                "Set a deadline to finish."
            ]
        ),
        DateCard(
            title: "Farmers Market Breakfast",
            description: "Build breakfast entirely from market stalls, eat it on a bench.",
            emoji: "🥕",
            difficulty: .quick,
            estimatedCost: .low,
            category: .foodie,
            whyItWorks: "Building breakfast from a market is the closest you'll get to cooking without cooking.",
            tips: [
                "Go early. The best stalls sell out.",
                "Pick the bread first. Build around it.",
                "Eat on a bench, not on the move."
            ]
        ),
        DateCard(
            title: "The Free Things Tour",
            description: "A whole day out spending nothing: parks, libraries, free museums, window shopping.",
            emoji: "🆓",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "A day where you spend nothing is also a day where you can't shortcut your way out of being together.",
            tips: [
                "Plan three free stops in advance.",
                "Bring water and a snack. The cost trap is the café.",
                "End at a free view — a park, a hilltop, a river bend."
            ]
        ),
        DateCard(
            title: "Botanical Garden Slow Walk",
            description: "No phones, no rush, find the weirdest plant and name it after each other.",
            emoji: "🌿",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "Walking very slowly through a garden is a small protest against the rest of the week.",
            tips: [
                "No phones. Not even for photos.",
                "Name the weirdest plant you see after each other.",
                "Sit for ten minutes somewhere quiet. Don't talk."
            ]
        ),
        DateCard(
            title: "Live Music, Any Genre",
            description: "Find the smallest gig in town and go, even if it's a genre neither of you knows.",
            emoji: "🎷",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "The smallest gig in town will always beat the big one — closer, weirder, more memorable.",
            tips: [
                "Pick by venue, not band. Tiny rooms are the point.",
                "Get there for the support act.",
                "Buy the merch if you liked it. Future-you will be glad."
            ]
        ),
        DateCard(
            title: "The Viewpoint Picnic",
            description: "Find the highest accessible point near you and eat lunch looking down on everything.",
            emoji: "⛰️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "Eating somewhere high reframes the city you live in as a place worth being in.",
            tips: [
                "Walk up. The earned view is the better view.",
                "Pack the picnic the night before.",
                "Stay long enough for the light to change."
            ]
        ),
        DateCard(
            title: "Vintage Cinema Trip",
            description: "Find somewhere showing an old film and treat it like an event.",
            emoji: "🎬",
            difficulty: .quick,
            estimatedCost: .medium,
            category: .creative,
            whyItWorks: "Watching an old film on a big screen is the kind of evening cinema was actually invented for.",
            tips: [
                "Pick a film one of you has never seen.",
                "Dress for it. Even slightly.",
                "Walk home after. Don't break the spell with a tube."
            ]
        ),
        DateCard(
            title: "Harbour or River Walk at Dusk",
            description: "Walk by water as the lights come on, talk about nothing important.",
            emoji: "🌆",
            difficulty: .quick,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Walking by water as the lights come on is a small, free gift of an evening.",
            tips: [
                "Time it for sunset, not after.",
                "No agenda for the conversation.",
                "Stop somewhere for a drink as the lights win."
            ]
        ),

        // Flirty & Tender
        DateCard(
            title: "The Compliment Volley",
            description: "No repeats, back and forth, until one of you blushes too hard to continue.",
            emoji: "🥰",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "No-repeat compliments force you past the easy ones into the things you actually notice.",
            tips: [
                "No repeats. The constraint is the magic.",
                "Eye contact for each one.",
                "Stop when one of you blushes too hard to continue."
            ]
        ),
        DateCard(
            title: "Slow Dance With the Lights Off",
            description: "One song, no phone, no talking.",
            emoji: "🕺",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Dancing in the dark removes the small self-consciousness that ruins the moment in the light.",
            tips: [
                "Curtains drawn, all lights off.",
                "One song. No more.",
                "No talking. Just stay close."
            ]
        ),
        DateCard(
            title: "The \"What I First Noticed\" Reveal",
            description: "Tell each other the very first thing you noticed about them.",
            emoji: "✨",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "The thing you first noticed is usually still true — and usually a surprise to the other person.",
            tips: [
                "No fishing. Just say it.",
                "One thing only. Don't list.",
                "Ask theirs after you've said yours."
            ]
        ),
        DateCard(
            title: "Kiss for Every Green Light",
            description: "On a drive or walk, every green light earns a kiss.",
            emoji: "💚",
            difficulty: .quick,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Tying affection to a small public ritual makes the day feel like a private game.",
            tips: [
                "Driver doesn't count if it's unsafe. Passenger kisses driver, not the other way.",
                "Walking version: every pedestrian green.",
                "Count them. Tell each other at the end."
            ]
        ),
        DateCard(
            title: "The Truth-or-Truth Game",
            description: "No dares, only truths, increasingly bold.",
            emoji: "🎴",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Removing the 'dare' option forces the conversation toward what you've both been quietly thinking.",
            tips: [
                "Start light. Increase the stakes slowly.",
                "No passing on a question. That's the rule.",
                "End with the bold one neither of you would have started with."
            ]
        ),
        DateCard(
            title: "Write Three Things You Find Irresistible",
            description: "Swap the notes. No reading aloud. Just keep them.",
            emoji: "📜",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Writing it down lands harder than saying it — and the note keeps working long after the evening ends.",
            tips: [
                "Pen on paper, not screens.",
                "Don't read aloud. Just swap.",
                "Keep the note. Put it somewhere you'll find it."
            ]
        ),
        DateCard(
            title: "The Long Goodnight",
            description: "No phones in bed for one full night. Just each other.",
            emoji: "🌜",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "One full night of no phones in bed is one full night of actually going to bed with each other.",
            tips: [
                "Phones charge in another room.",
                "Talk in the dark. It's a different conversation.",
                "Wake up without checking. Take the slow morning."
            ]
        ),
        DateCard(
            title: "Recreate Your First Kiss",
            description: "Same energy, same nervousness, do it again like it's new.",
            emoji: "💋",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Re-staging the first kiss isn't sentimental — it's a small reminder that the spark was a choice you made.",
            tips: [
                "Same spot if you can.",
                "Don't perform. Be nervous on purpose.",
                "Don't laugh through it. Stay in the moment."
            ]
        ),
        DateCard(
            title: "The Slow Morning",
            description: "Set no alarm. Whoever wakes first makes the coffee. Stay in bed regardless.",
            emoji: "🛌",
            difficulty: .micro,
            estimatedCost: .low,
            category: .intimate,
            whyItWorks: "A morning with no alarm and no agenda is the rarest kind of date — pure, undistracted time.",
            tips: [
                "Set no alarm. Whoever wakes first makes the coffee.",
                "Stay in bed after the coffee. That's the date.",
                "Phones face down or out of the room."
            ]
        ),
        DateCard(
            title: "Two-Minute Heartbeat",
            description: "Lie still, hand on each other's chest, feel the rhythm slow down together.",
            emoji: "💓",
            difficulty: .micro,
            estimatedCost: .free,
            category: .intimate,
            whyItWorks: "Feeling each other's pulse slow down together is one of the most physical possible reminders of safety.",
            tips: [
                "Lie face-to-face, hand on each other's chest.",
                "Two full minutes. Don't talk.",
                "Notice when your breath syncs. It will."
            ]
        ),

        // Try Something New
        DateCard(
            title: "Beginner's Class, Anything",
            description: "Pottery, dance, climbing, whatever has a \"first timers\" session this week.",
            emoji: "🎓",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .creative,
            whyItWorks: "Sitting side by side as the worst people in the room is a quietly bonding kind of vulnerability.",
            tips: [
                "Book it tonight. Hesitation is what kills it.",
                "Pick something neither of you has tried.",
                "Plan a drink after. You'll have things to debrief."
            ]
        ),
        DateCard(
            title: "Be a Beginner at Their Hobby",
            description: "Spend an hour being a total beginner at the thing your partner loves.",
            emoji: "🪡",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Showing up for your partner's hobby as a total beginner is one of the rarest gifts.",
            tips: [
                "Let them lead. Don't shortcut their teaching.",
                "Stay an hour, no less.",
                "Ask one real question. Be curious, not polite."
            ]
        ),
        DateCard(
            title: "The New Cuisine Rule",
            description: "Eat food from a country neither of you has tried. Order the thing you can't pronounce.",
            emoji: "🍱",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .foodie,
            whyItWorks: "Eating food from somewhere neither of you has tried makes the meal feel like a small frontier.",
            tips: [
                "Pick a country, not a restaurant. Then find the spot.",
                "Order the dish you can't pronounce.",
                "Don't Google it before tasting."
            ]
        ),
        DateCard(
            title: "Plant Something Together",
            description: "A herb pot, a tree, a window box. Watch it grow as long as you're together.",
            emoji: "🌱",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "Planting something living is a quiet declaration that you're planning to be there to watch it grow.",
            tips: [
                "Choose something hard to kill. First plant, low stakes.",
                "Same pot, two hands.",
                "Photograph it on day one. Compare in a month."
            ]
        ),
        DateCard(
            title: "The Skill Swap",
            description: "Each teach the other something you can do that they can't, in 30 minutes.",
            emoji: "🔁",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Teaching is one of the only fast ways to see someone you love at their most patient.",
            tips: [
                "Pick something you can teach in 30 minutes — not 'play guitar', 'play one chord'.",
                "Teach the way you wish you'd been taught.",
                "Both go in the same evening. Don't postpone the second."
            ]
        ),
        DateCard(
            title: "Volunteer for an Afternoon",
            description: "Do something good for someone else, together, for a few hours.",
            emoji: "🤝",
            difficulty: .halfDay,
            estimatedCost: .free,
            category: .adventure,
            whyItWorks: "Doing something kind together rearranges what you talk about for days after.",
            tips: [
                "Book a one-off, not a commitment. Lower the bar.",
                "Go in with no agenda about which one of you 'does more'.",
                "Debrief over dinner. The conversation will be different."
            ]
        ),
        DateCard(
            title: "The Language Hour",
            description: "Both learn ten words of a new language and only use those words for an hour.",
            emoji: "🗣️",
            difficulty: .quick,
            estimatedCost: .free,
            category: .creative,
            whyItWorks: "Trying to communicate with only ten new words makes you both laugh — and listen harder.",
            tips: [
                "Ten words each. Same ten or different.",
                "Hour, hard cap.",
                "Forfeit a kiss for every English word that slips out."
            ]
        ),
        DateCard(
            title: "Build a Bucket List Board",
            description: "A physical board of everything you want to do together. Hang it where you'll see it.",
            emoji: "📋",
            difficulty: .quick,
            estimatedCost: .low,
            category: .creative,
            whyItWorks: "A physical list, somewhere visible, turns intentions into things you'll actually do.",
            tips: [
                "A real board, not a phone note.",
                "Hang it where you'll both see it daily.",
                "Move items to a 'done' column. The momentum compounds."
            ]
        ),
        DateCard(
            title: "Try the Thing You're Both Scared Of",
            description: "Heights, deep water, public dancing. Hold hands. Do it anyway.",
            emoji: "😱",
            difficulty: .halfDay,
            estimatedCost: .medium,
            category: .adventure,
            whyItWorks: "Facing a small fear together rearranges what you think you're capable of as a couple.",
            tips: [
                "Pick something neither of you would do alone.",
                "Hold hands going in. Sincerely.",
                "Debrief afterwards. The conversation is half the point."
            ]
        ),
        DateCard(
            title: "The Reverse Bucket List",
            description: "Instead of new things, redo your favourite thing you've ever done together.",
            emoji: "♻️",
            difficulty: .halfDay,
            estimatedCost: .low,
            category: .adventure,
            whyItWorks: "Redoing your favourite shared thing — instead of always chasing new — is its own kind of vow.",
            tips: [
                "Vote separately. Compare.",
                "Don't recreate exactly — let it evolve.",
                "Talk about why it was the favourite in the first place."
            ]
        )
    ]
}
