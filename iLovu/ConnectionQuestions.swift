// ConnectionQuestions.swift
// The bank of warm, specific connection questions cycled one per
// day on the Us tab. Designed to feel like a thoughtful friend
// nudging — not a therapy worksheet. Every question is short,
// concrete, and easy to answer in 2-3 sentences.
//
// Rotation rule: pick by day-of-year, mod question count. With ~130
// questions that means a ~130-day cycle — each question reappears
// roughly three times a year, far enough apart that they feel fresh.

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
        "What's something you'd love us to do before the year ends?",

        // MARK: - Content Pack (100 additions)

        // Light & Warm
        "What's one small thing I did recently that made you happy and I probably don't even know about?",
        "If we could wake up anywhere in the world tomorrow, where would it be?",
        "What's a memory of us that always makes you smile when it pops into your head?",
        "What song instantly reminds you of me?",
        "What's something tiny I do that you find weirdly adorable?",
        "If we had a completely free Saturday with no plans and no budget limit, what would you want to do?",
        "What's the best meal we've ever shared?",
        "What's a place we've been that you'd happily go back to a hundred times?",
        "What did you think of me the very first time we met — honestly?",
        "What's something you've never told me about our first date?",

        // Getting Deeper
        "When did you most recently feel really loved by me?",
        "What's something you wish I asked you about more often?",
        "What's a fear you have that you don't talk about much?",
        "What does a \"good day\" look like for you lately?",
        "When do you feel most like yourself around me?",
        "What's something you're proud of that you don't think I fully realise?",
        "What's a way I could support you better right now?",
        "What's been on your mind lately that you haven't said out loud?",
        "When was the last time you felt genuinely peaceful?",
        "What's something you needed as a kid that you still need now?",

        // Us, Specifically
        "What's something about our relationship you're grateful we figured out?",
        "What's a moment you knew you wanted to keep choosing me?",
        "What do you think is our greatest strength as a couple?",
        "What's something we used to do that you miss?",
        "What's a habit we've built together that you love?",
        "When have you felt proudest to be with me?",
        "What's something you want us to be braver about?",
        "What does \"home\" feel like to you — and is it a place or a person?",
        "What's a small ritual of ours that means more to you than I might think?",
        "What's something you'd never want us to lose?",

        // Dreams & Future
        "What's something you want us to do together before we get old?",
        "Where do you picture us in five years — and how do you feel about it?",
        "What's a dream of yours I could help make happen?",
        "If money were no object, what would you want our life to look like?",
        "What's something you want to learn or try that you've been putting off?",
        "What kind of older couple do you hope we become?",
        "What's a tradition you'd love us to start?",
        "What's somewhere you've always wanted to take me?",
        "What's a goal you have that you've never said out loud to me?",
        "What would make the next year of us feel like a good one?",

        // Tender & Vulnerable
        "When do you feel most secure with me?",
        "Is there anything you've been wanting reassurance about?",
        "What's a way I've grown since we got together?",
        "What's something hard you went through that shaped who you are?",
        "When was the last time you cried, and what was it about?",
        "What's a part of yourself you're still learning to accept?",
        "What do you need more of from me, gently?",
        "What's something you forgive me for that I might still feel guilty about?",
        "What makes you feel safe?",
        "What's a moment you felt closest to me, even if I didn't notice?",

        // Playful & Fun
        "If you had to describe our relationship as a film genre, what would it be?",
        "What's the most ridiculous argument we've ever had?",
        "If we swapped bodies for a day, what's the first thing you'd do?",
        "What's a nickname for me you've thought of but never used?",
        "What's my most annoying habit — and which one do you secretly find endearing?",
        "If we started a business together, what would it be and who'd be the boss?",
        "What's the weirdest thing about me that you love?",
        "If you could relive one day with me, which would it be?",
        "What's a \"couple thing\" other people do that we'd never be caught doing?",
        "What's the pettiest thing you've ever been right about in this relationship?",

        // Past & Story
        "What's your favourite story to tell people about us?",
        "When did you first realise you were falling for me?",
        "What's something from your past you wish I'd been there for?",
        "What did you imagine love would be like before you met me — and how was it different?",
        "What's a moment early on when you almost gave up, and what made you stay?",
        "What's the best advice about love anyone's ever given you?",
        "What's a version of you from the past you wish I'd known?",
        "What's something your family taught you about love — good or bad?",
        "What's the first thing you ever told a friend about me?",
        "If our story had a title, what would it be?",

        // Everyday Closeness
        "What's the best part of your normal day with me in it?",
        "What's something I could do tomorrow that would make your week better?",
        "How do you most like to be comforted when you're stressed?",
        "What's your favourite way we say \"I love you\" without saying it?",
        "What's something you appreciate about our daily life that's easy to overlook?",
        "When do you feel most connected to me during an ordinary week?",
        "What's a small kindness I do that you'd miss if it stopped?",
        "What does your ideal lazy day with me look like?",
        "What's something you'd love to do together more often?",
        "What makes you feel like we're a team?",

        // Growth & Honesty
        "What's something we should probably talk about more than we do?",
        "Where do you think we could understand each other better?",
        "What's a way you've changed because of me — for better or worse?",
        "What's something you're working on in yourself right now?",
        "How can we argue better, do you think?",
        "What's a fear you have about us that you'd feel relieved to say out loud?",
        "What do you think I misunderstand about you?",
        "What's a compromise we've made that you're actually grateful for?",
        "What would \"growing together\" look like to you this year?",
        "What's something you want me to know but find hard to say?",

        // Tender Closers
        "What's the kindest thing I've ever done for you?",
        "When you picture growing old, what part of it with me are you most looking forward to?",
        "What's something you hope never changes about us?",
        "If I could feel exactly how much you love me for one minute, what would it feel like?",
        "What's a quiet moment with me you'll never forget?",
        "What do you love about who you are when you're with me?",
        "What's something you want to thank me for that you've never said?",
        "If today were a snapshot of us, what would you title it?",
        "What's the thing you most want me to remember on a hard day?",
        "After all of it — what makes you still choose us?"
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
