#!/usr/bin/env python3
"""Generate iLovu SEO + GEO content pages into site/ from a data table.

One template, many pages. Each page emits Article + FAQPage + ItemList JSON-LD
(FAQ + ItemList are what AI answer engines extract and cite — the GEO win), a
direct-answer intro, clean headings/lists, and internal cross-links. Re-run any
time to regenerate. NOT deployed (lives in scripts/, only site/ ships to Netlify).
"""
import html, json, os

SITE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "site")
APPSTORE = "https://apps.apple.com/app/id6781237573"
SVG = ('<svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor" aria-hidden="true">'
       '<path d="M16.365 1.43c0 1.14-.417 2.2-1.11 2.99-.75.86-1.98 1.52-3.16 1.43-.14-1.1.42-2.28 '
       '1.08-3.02.75-.85 2.06-1.48 3.19-1.4zM20.7 17.14c-.58 1.34-.86 1.94-1.61 3.13-1.05 1.66-2.53 '
       '3.73-4.36 3.74-1.63.02-2.05-1.06-4.26-1.05-2.21.01-2.67 1.07-4.3 1.05-1.83-.02-3.23-1.88-4.28-3.54-2.94-4.66-3.25-10.13-1.43-13.04 '
       '1.29-2.07 3.33-3.28 5.25-3.28 1.95 0 3.18 1.07 4.79 1.07 1.57 0 2.52-1.07 4.78-1.07 1.7 0 3.51.93 4.8 2.53-4.22 2.31-3.53 8.34.83 10.46z"/></svg>')

TAG_CLASS = {"Free": "", "Low cost": " orange", "Medium": " rose", "": ""}

def e(s): return html.escape(s, quote=True)

def idea_html(i):
    emoji, title, desc = i[0], i[1], i[2]
    tag = i[3] if len(i) > 3 else None
    tags = ""
    if tag:
        tags = f'<div class="tags"><span class="tag{TAG_CLASS.get(tag, "")}">{e(tag)}</span></div>'
    return (f'<div class="idea"><h3><span class="em">{emoji}</span>{title}</h3>'
            f'<p>{desc}</p>{tags}</div>')

def page_html(p):
    url = f"https://ilovu.io/{p['slug']}"
    ideas = "\n    ".join(idea_html(i) for i in p["ideas"])
    related = "\n      ".join(f'<a href="{href}">{label} &rarr;</a>' for href, label in p["related"])
    faqs = "".join(f"<h3>{e(q)}</h3><p>{a}</p>" for q, a in p["faqs"])

    article_ld = {"@context": "https://schema.org", "@type": "Article",
                  "headline": p["h1_plain"], "description": p["desc"],
                  "author": {"@type": "Organization", "name": "iLovu"},
                  "publisher": {"@type": "Organization", "name": "iLovu", "url": "https://ilovu.io"},
                  "mainEntityOfPage": url}
    faq_ld = {"@context": "https://schema.org", "@type": "FAQPage",
              "mainEntity": [{"@type": "Question", "name": q,
                              "acceptedAnswer": {"@type": "Answer", "text": a_plain}}
                             for q, a_plain in p["faqs_plain"]]}
    item_ld = {"@context": "https://schema.org", "@type": "ItemList",
               "itemListElement": [{"@type": "ListItem", "position": n + 1, "name": i[1]}
                                   for n, i in enumerate(p["ideas"])]}

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{e(p['title'])}</title>
<meta name="description" content="{e(p['desc'])}">
<link rel="canonical" href="{url}">
<link rel="icon" type="image/x-icon" href="favicon.ico">
<link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">
<meta property="og:title" content="{e(p['og'])}">
<meta property="og:description" content="{e(p['desc'])}">
<meta property="og:type" content="article">
<meta property="og:url" content="{url}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,500;0,9..144,600;1,9..144,400&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/site.css">
<script type="application/ld+json">
{json.dumps(article_ld)}
</script>
<script type="application/ld+json">
{json.dumps(faq_ld)}
</script>
<script type="application/ld+json">
{json.dumps(item_ld)}
</script>
</head>
<body>
<nav>
  <a class="logo" href="/">iL<span>o</span>vu</a>
  <a class="nav-cta" href="{APPSTORE}">Get iLovu</a>
</nav>
<div class="wrap">
  <article class="article">
    <p class="eyebrow">{p['eyebrow']}</p>
    <h1>{p['h1']}</h1>
    <p class="lead">{p['lead']}</p>

    {ideas}

    <div class="cta-card">
      <h2>{e(p['cta_h2'])}</h2>
      <p>{p['cta_p']}</p>
      <a class="appstore-btn" href="{APPSTORE}" aria-label="Download iLovu on the App Store">
        {SVG}
        <span><span class="small">Download on the</span><span class="big">App Store</span></span>
      </a>
    </div>

    <section class="faq">
      <h2>Frequently asked</h2>
      {faqs}
    </section>

    <div class="related">
      <strong>More date ideas:</strong><br>
      {related}
    </div>
  </article>
</div>
<footer>
  <p class="footer-tag">One real date a month. No pressure, no guilt.</p>
  <p style="margin-bottom:8px;"><a href="/">Home</a> &nbsp;&middot;&nbsp; <a href="/date-ideas">Date Ideas</a> &nbsp;&middot;&nbsp; <a href="privacy.html">Privacy</a> &nbsp;&middot;&nbsp; <a href="terms.html">Terms</a> &nbsp;&middot;&nbsp; <a href="support.html">Support</a></p>
  <p>&copy; 2026 iLovu &middot; <a href="mailto:contact@ilovu.io">contact@ilovu.io</a></p>
</footer>
</body>
</html>
"""

# Standard cross-links (each page filters out itself in build).
CORE_LINKS = [
    ("/date-ideas", "All date ideas"),
    ("/date-night-ideas", "Date night"),
    ("/romantic-date-ideas", "Romantic"),
    ("/cheap-date-ideas", "Cheap & free"),
    ("/outdoor-date-ideas", "Outdoor"),
    ("/date-ideas-at-home", "At home"),
    ("/first-date-ideas", "First date"),
    ("/fun-date-ideas", "Fun"),
]

DEFAULT_CTA_H2 = "Stop scrolling. Actually go."
DEFAULT_CTA_P = ('iLovu turns "we should do something sometime" into your next real date &mdash; swipe date '
                 'ideas together, match on what you both love, and go. 190+ ideas and local spots for two.')

PAGES = [
  dict(slug="date-night-ideas", em_word="Never Boring",
    title="Date Night Ideas — 10 for Couples That Never Get Boring | iLovu",
    desc="Date night ideas for couples that beat dinner-and-a-movie on repeat. Fresh, doable ways to make your regular night out feel like something again.",
    og="Date Night Ideas That Never Get Boring",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Date night',
    h1='Date Night Ideas That <em>Never Get Boring</em>',
    lead="The best date nights swap the routine for something a little new &mdash; novelty is what makes an evening actually stick. Here are ten to rescue your regular night out.",
    ideas=[("🌹","Recreate your first date","Same meal, same music, same nervous butterflies. Nostalgia is a shortcut to feeling new again.","Free"),
      ("🍽️","The new restaurant rule","Somewhere neither of you has been, no reviews first. No expectations, just your reactions.","Medium"),
      ("🕯️","Candlelit dinner at home","Cook together, dim the lights, phones in another room. You both look softer by candlelight.","Low cost"),
      ("🍸","Cocktail lab","Invent two cocktails and name them after each other. Three ingredients max.","Low cost"),
      ("🌮","Street food tour","Starter, main, dessert, each somewhere new. Small stops mean more talking.","Medium"),
      ("🎶","Live music, any genre","Book whatever's on locally. Sharing a song live beats another screen.","Medium"),
      ("💃","Slow dance in the kitchen","One song, no reason. The kind of moment that becomes the memory.","Free"),
      ("🎲","Board game caf&eacute;","Learn a game neither of you has played. Beginners together is a great leveller.","Low cost"),
      ("🍿","Themed movie night","Pick a country or decade and match the film, food and drinks to it.","Low cost"),
      ("😂","Comedy or open mic","Laughing together in a room full of strangers is its own kind of closeness.","Medium")],
    faqs=[("What's a good date night idea for couples?","The best ones add a little novelty &mdash; try a new restaurant with no reviews, a cocktail lab at home, a themed movie night, or live music. Novel shared experiences boost closeness more than repeating the same evening."),
      ("What can couples do for date night at home?","Cook a candlelit dinner together, invent cocktails, do a themed movie night, or slow dance in the kitchen to one song. See more <a href='/date-ideas-at-home'>at-home date ideas</a>.")]),

  dict(slug="romantic-date-ideas", em_word="Romantic",
    title="Romantic Date Ideas — 10 to Feel Closer Tonight | iLovu",
    desc="Romantic date ideas for couples &mdash; slow, intimate, low-key ways to feel closer, from candlelit floor picnics to stargazing and the 36 questions.",
    og="Romantic Date Ideas to Feel Closer Tonight",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Romantic',
    h1='Romantic Date Ideas to Feel <em>Closer</em> Tonight',
    lead="Romance isn't about grand gestures &mdash; it's about undivided attention. These slow, intimate date ideas are built to help you actually feel close, not just look the part.",
    ideas=[("💃","Slow dance, no occasion","One song, kitchen floor, no reason. A small ceremony a relationship runs on.","Free"),
      ("🪔","Candlelit floor picnic","Dinner on a blanket, lights off, candles only. It strips away the small formalities.","Low cost"),
      ("🌇","Sunset walk","Walk until the sun sets, talk about anything but work. Walking lowers the bar for real talk.","Free"),
      ("⭐","Stargazing","Somewhere dark, a blanket, three constellations. The same sky puts the noise in perspective.","Free"),
      ("📚","Read to each other in bed","One chapter, out loud, lights low. Being read to is care most people last felt as children.","Free"),
      ("💌","Handwritten letter swap","Write, seal, swap, read in silence. Handwriting forces you to mean what you write.","Free"),
      ("🍷","Old photos, new wine","Open a bottle and scroll back to the very beginning of you two.","Low cost"),
      ("🛁","Bath and talk","Run a bath, no agenda, just float and talk. One of the more honest places to open up.","Free"),
      ("🤍","Trace and tell","Draw a slow line down their arm and tell them one thing you love, three times each.","Free"),
      ("💬","The 36 questions","The <a href='/36-questions'>questions designed to make two people fall in love</a>. Take turns, go in order.","Free")],
    faqs=[("What is the most romantic date idea?","The most romantic dates are intimate and undistracted &mdash; a candlelit floor picnic, slow dancing to one song, or reading to each other in bed. Attention, not expense, is what makes it romantic."),
      ("How can I be more romantic with my partner?","Small, consistent gestures beat big ones. Write a handwritten letter, do the 36 questions, or plan a phone-free evening. Doing the little things regularly is what keeps a relationship warm.")]),

  dict(slug="fun-date-ideas", em_word="Fun",
    title="Fun Date Ideas — 10 That Actually Make You Laugh | iLovu",
    desc="Fun date ideas for couples that get you laughing &mdash; mini golf, karaoke, escape rooms, trampolines and more playful this-or-that nights out.",
    og="Fun Date Ideas That Make You Laugh",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Fun',
    h1='Fun Date Ideas That Actually Make You <em>Laugh</em>',
    lead="Nothing bonds two people like laughing together. These fun date ideas are built around play &mdash; a little competition, a little chaos, zero pressure to look cool.",
    ideas=[("⛳","Mini golf showdown","Nine holes, a made-up trophy, loser buys ice cream. A silly bet makes it memorable.","Low cost"),
      ("🤸","Trampoline park","An hour of bouncing like nobody's watching. Impossible to hold a bad mood mid-air.","Medium"),
      ("🎤","Karaoke night out","Book a private booth and sing badly where nobody can judge.","Medium"),
      ("🔓","Escape room","Break out before the clock beats you. A low-stakes look at how you solve things together.","Medium"),
      ("🍫","Blind taste test","Blindfold each other and guess mystery foods. The laughing comes easy.","Low cost"),
      ("🎙️","Lip-sync battle","One song each, full commitment, phone on a tripod, no mercy.","Free"),
      ("🎲","Board game caf&eacute;","Let a stranger recommend a game you've never played and fumble the rules together.","Low cost"),
      ("🛼","Roller or ice rink","Hold on to each other for dear life. Nothing melts self-consciousness faster.","Low cost"),
      ("🎳","Bowling or arcade","Something to do with your hands and a scoreboard to tease over.","Low cost"),
      ("📷","Photo scavenger hunt","Ten things to photograph around town, first to all ten wins.","Free")],
    faqs=[("What are fun date ideas for couples?","Playful, active ones: mini golf, karaoke, an escape room, a trampoline park, or a photo scavenger hunt. Anything with a bit of friendly competition and room to be silly."),
      ("What's a fun cheap date?","A photo scavenger hunt, a lip-sync battle at home, or a blind taste test cost almost nothing and guarantee laughs. More <a href='/cheap-date-ideas'>cheap date ideas</a>.")]),

  dict(slug="cute-date-ideas", em_word="Cute",
    title="Cute Date Ideas — 10 Sweet, Low-Key Ideas for Couples | iLovu",
    desc="Cute date ideas for couples &mdash; sweet, cosy, low-key ways to spend time together, from building a blanket fort to a two-person bake-off.",
    og="Cute Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Cute',
    h1='Cute Date Ideas That Are Sweet, Not <em>Fussy</em>',
    lead="Cute doesn't mean complicated. These are the sweet, low-key date ideas that make an ordinary evening feel a little softer &mdash; and cost almost nothing.",
    ideas=[("🏰","Blanket fort cinema","Build a fort with every cushion you own and watch a film under it.","Free"),
      ("🧁","Two-person bake-off","Same recipe, separate bowls, no helping. Judge with kissed feedback only.","Low cost"),
      ("🍕","Build-your-own pizza night","Each design the weirdest pizza for the other to eat.","Low cost"),
      ("⛺","Living-room camping","Sleeping bags, fairy-light stars, snacks, ghost stories.","Free"),
      ("🫙","The memory jar","Add a happy-moment note each week and open it next year.","Low cost"),
      ("🎨","Paint each other","Cheap canvases, twenty-minute portraits, frame the worst one.","Low cost"),
      ("🎵","Build a playlist for us","Each add ten songs that remind you of the other.","Free"),
      ("🍦","Dessert crawl","Skip dinner, order only pudding at three places, rank them on the walk home.","Medium"),
      ("🥞","Breakfast in bed swap","Each secretly makes the other breakfast in bed tomorrow.","Low cost"),
      ("🐠","Aquarium or botanical garden","Wander somewhere gentle and green with easy things to point at.","Low cost")],
    faqs=[("What are cute date ideas?","Sweet, low-key ones: a blanket fort movie, a two-person bake-off, a memory jar, or painting each other badly. Cute is about warmth and effort, not expense."),
      ("What's a cute date to do at home?","Build a blanket fort and watch a film, do a bake-off, or start a memory jar. See more <a href='/date-ideas-at-home'>at-home date ideas</a>.")]),

  dict(slug="unique-date-ideas", em_word="Unusual",
    title="Unique Date Ideas — 10 Unusual Ideas You Haven't Tried | iLovu",
    desc="Unique date ideas for couples who are bored of the usual &mdash; a yes day, a silent dinner, geocaching, a coin-flip road trip and more unexpected outings.",
    og="Unique Date Ideas You Haven't Tried",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Unique',
    h1="Unique Date Ideas You <em>Haven&rsquo;t Tried</em>",
    lead="Done dinner and a movie to death? These unusual date ideas are built to surprise you both &mdash; and the novelty is exactly what makes them memorable.",
    ideas=[("🥂","Strangers at a bar","Arrive separately, pretend you've never met, chat each other up from scratch.","Medium"),
      ("✅","The yes day","For one afternoon, say yes to every reasonable thing the other suggests.","Medium"),
      ("🤐","Silent dinner","Cook and eat a whole meal communicating without a single word.","Low cost"),
      ("🪙","Coin-flip road trip","Flip a coin at every junction and drive where chance takes you.","Medium"),
      ("🎯","Map-pin dart","Drop a pin within an hour's drive without looking, then go there.","Medium"),
      ("🧭","Geocaching hunt","Use a free app to hunt hidden caches near you like a treasure map.","Free"),
      ("🤝","Kindness spree","Do three small kind things for strangers together in one outing.","Low cost"),
      ("🍄","Forage and cook","Pick what's in season, then cook with it that night.","Free"),
      ("👃","The scent memory test","Blindfold each other, sniff things, share the memory each smell unlocks.","Low cost"),
      ("🌲","The awe walk","Walk somewhere vast and hunt for things that make you stop.","Free")],
    faqs=[("What are some unique date ideas?","Try the unexpected: a 'yes day', a silent dinner, geocaching, a coin-flip road trip, or meeting as strangers at a bar. Novelty is what makes a date stick in memory."),
      ("Why do new experiences make couples closer?","Relationship research (Aron and others) finds that novel, mildly exciting shared activities boost closeness and satisfaction &mdash; more than repeating a comfortable routine.")]),

  dict(slug="adventurous-date-ideas", em_word="Adventurous",
    title="Adventurous Date Ideas — 10 for Couples Who Love a Thrill | iLovu",
    desc="Adventurous date ideas for couples &mdash; wild swims, sunrise missions, escape rooms, road trips and outdoor thrills that bring you closer through a rush.",
    og="Adventurous Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Adventure',
    h1='Adventurous Date Ideas for Couples Who Love a <em>Thrill</em>',
    lead="A shared rush of adrenaline is a shortcut to feeling connected &mdash; your brain ties the excitement to the person beside you. These adventurous dates lean into it.",
    ideas=[("🏊","Wild swim","Lake, river or sea &mdash; get in and scream about the cold together.","Free"),
      ("🌄","Sunrise mission","A high spot, a 5am alarm, coffee in a flask. The early start is what earns the view.","Free"),
      ("🔓","Escape room","Beat the clock together. A live test of how you problem-solve as a team.","Medium"),
      ("🛶","Sunset paddle","Canoe or paddleboard on the water as the sun goes down.","Medium"),
      ("🚴","Cycle to nowhere","Two bikes, no destination, turn back when one of you gets hungry.","Free"),
      ("🚆","The unplanned train","Take the next train out and get off where it looks interesting.","Medium"),
      ("🧗","Try a climbing class","Being beginners side by side resets the dynamic &mdash; nobody's the expert.","Medium"),
      ("☄️","Meteor shower night","Look up the next shower, drive somewhere dark, and count shooting stars.","Free"),
      ("🎯","Map-pin dart","Let a random pin choose your day and arrive without googling it first.","Medium"),
      ("🥾","Hike a trail","Find a real trail and walk it end to end. The best talks happen mid-stride.","Free")],
    faqs=[("What are adventurous date ideas?","Wild swimming, a sunrise hike, an escape room, a paddle at sunset, or a spontaneous road trip. Shared excitement bonds couples fast."),
      ("Why does adventure make couples closer?","A shared adrenaline rush gets partly attributed to the person you're with &mdash; a well-studied effect. Doing something new and slightly thrilling together deepens attraction and closeness.")]),

  dict(slug="foodie-date-ideas", em_word="Foodie",
    title="Foodie Date Ideas — 10 Delicious Ideas for Couples | iLovu",
    desc="Foodie date ideas for couples who love to eat &mdash; make pasta from scratch, a blind taste test, a dessert crawl, a spice dare and more delicious nights.",
    og="Foodie Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Foodie',
    h1='Foodie Date Ideas for Couples Who Love to <em>Eat</em>',
    lead="Cooking and eating together is one of the oldest ways to bond &mdash; equal parts teamwork, sensory pleasure and laughter. Here are ten dates for the food-obsessed.",
    ideas=[("🍝","Make pasta from scratch","Flour, eggs, a rolling pin, low expectations, high laughter.","Low cost"),
      ("🍫","Blind taste test","Buy five versions of one thing, blindfold, rank, argue.","Low cost"),
      ("👵","Cook a family recipe","One of you teaches the other a dish from home. Phone a parent for the real version.","Low cost"),
      ("🍜","Order in a language you don't speak","Point and hope. The dish you'd never have chosen is the best part.","Medium"),
      ("🍰","Dessert crawl","Skip dinner, order only pudding at three spots, rank them.","Medium"),
      ("🌶️","The spice dare","Cook one dish, add increasing heat, see who taps out first.","Low cost"),
      ("🍸","Cocktail lab","Invent two cocktails and name them after each other.","Low cost"),
      ("🥘","Cook without a recipe","Open the fridge, pick five things, invent a dish, no looking up.","Low cost"),
      ("🌭","Street food hunt","Share one thing from every stall at a market that catches your eye.","Medium"),
      ("💷","The tenner dinner challenge","A tenner each, separate shops, combine it all into one meal.","Low cost")],
    faqs=[("What are good foodie date ideas?","Make pasta from scratch, do a blind taste test, cook a family recipe together, or go on a dessert crawl. The doing matters as much as the eating."),
      ("What's a fun food date at home?","A spice dare, a cocktail lab, or cooking without a recipe. Constraints and a bit of competition make it a proper date, not just dinner.")]),

  dict(slug="creative-date-ideas", em_word="Creative",
    title="Creative Date Ideas — 10 Hands-On Ideas for Couples | iLovu",
    desc="Creative date ideas for couples &mdash; paint each other, write a song, make pottery, draw your future house and more hands-on nights that make something together.",
    og="Creative Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Creative',
    h1='Creative Date Ideas That Make Something <em>Together</em>',
    lead="Making something side by side &mdash; badly, happily &mdash; is a quiet act of teamwork. These creative dates leave you with more than a memory: something you made.",
    ideas=[("🎨","Paint each other","Cheap canvases, twenty-minute portraits, keep the worst one forever.","Low cost"),
      ("🖌️","Ten-minute portraits","One paintbrush, three colours, a timer. Frame the disaster.","Low cost"),
      ("🎤","Write a song about today","Three verses, terrible, performed with total seriousness.","Free"),
      ("🏺","Pottery on the table","Air-dry clay and make each other a 'gift'. Keep it terrible.","Low cost"),
      ("📓","Make a zine about us","Fold one sheet into a tiny booklet of drawings and inside jokes.","Low cost"),
      ("🏡","Draw your future house","Each sketch the home you'd build, then merge the two.","Free"),
      ("🍹","Invent a cocktail","Name it after your relationship and write the recipe down.","Low cost"),
      ("🧩","The jigsaw race","Two small jigsaws, start together, loser does the washing up.","Low cost"),
      ("📸","Two-person photoshoot","One shoots, one poses, then swap. Find your best and worst shot.","Free"),
      ("🕺","Learn a dance routine","Learn a 30-second routine off the internet, badly, until you nail it.","Free")],
    faqs=[("What are creative date ideas for couples?","Hands-on ones: paint each other, write a silly song, make pottery, draw your future house, or invent a cocktail. Making something together beats just consuming something."),
      ("What creative date can we do at home?","Air-dry-clay pottery, ten-minute portraits, or a two-person photoshoot need almost nothing. See more <a href='/date-ideas-at-home'>at-home date ideas</a>.")]),

  dict(slug="rainy-day-date-ideas", em_word="Rainy Day",
    title="Rainy Day Date Ideas — 10 Cosy Ideas for a Wet Day | iLovu",
    desc="Rainy day date ideas for couples &mdash; cosy, low-energy ways to enjoy a wet day in, from a duvet day to a puzzle-and-podcast and window-watching the storm.",
    og="Rainy Day Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Rainy day',
    h1='Rainy Day Date Ideas for a <em>Cosy</em> Day In',
    lead="Rain is permission to do nothing, together. These low-energy date ideas turn a grey, wet day into one of the cosiest you'll have all month.",
    ideas=[("🛏️","The duvet day","Cancel everything, stay in bed, order food, watch a whole series.","Low cost"),
      ("🎧","Puzzle and podcast","A big jigsaw and a podcast you both like. Quiet, easy, together.","Low cost"),
      ("☕","The ultimate hot drink","Hot chocolate with everything &mdash; cream, marshmallows, a sneaky shot.","Low cost"),
      ("🌧️","Window-watch the storm","Two chairs at the window, a blanket, watch the rain do its thing.","Free"),
      ("📺","Face mask and trash TV","Skincare neither of you understands and the worst reality show you can find.","Low cost"),
      ("🏰","Blanket fort cinema","Cushions off every chair, and the film one of you keeps meaning to show.","Free"),
      ("📖","Read the same book","Both read a short book this week and talk about it like a two-person book club.","Low cost"),
      ("🚗","The rainy drive","Drive somewhere with a view and watch the storm from the warm car with music on.","Low cost"),
      ("🧺","Indoor picnic under the table","Crackers, cheese, juice in wine glasses. Childhood, recreated.","Low cost"),
      ("🃏","Learn a card trick each","Ten minutes of tutorials, then perform for each other.","Free")],
    faqs=[("What can couples do on a rainy day?","Lean into cosy and low-effort: a duvet day, a puzzle with a podcast, a blanket-fort movie, or watching the storm from a warm car. Rain is the perfect excuse to slow down together."),
      ("What's a cheap rainy day date?","Build the ultimate hot drink and window-watch the storm, or do a face-mask-and-trash-TV night. Almost free, very cosy.")]),

  dict(slug="winter-date-ideas", em_word="Winter",
    title="Winter Date Ideas — 10 Cosy Ideas for Cold Nights | iLovu",
    desc="Winter date ideas for couples &mdash; cosy nights in and crisp days out, from ice skating and Christmas markets to hot cocoa, camping indoors and stargazing.",
    og="Winter Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Winter',
    h1='Winter Date Ideas for Long, <em>Cosy</em> Nights',
    lead="Winter is made for couples &mdash; the cold gives you every excuse to slow down, huddle up, and make an evening feel like an event. Here are ten for the season.",
    ideas=[("⛸️","Ice skating hand in hand","Wobble around a rink holding on to each other. Falling together is the fun part.","Low cost"),
      ("☕","Build the ultimate hot cocoa","Cream, marshmallows, a chocolate bar broken into it, a sneaky shot.","Low cost"),
      ("🎄","Christmas market wander","Mulled wine, fairy lights, one thing from every stall.","Medium"),
      ("⛺","Living-room camping","Sleeping bags, fairy-light stars, snacks, ghost stories.","Free"),
      ("⭐","Winter stargazing","Crisp skies show the most stars. Bundle up, bring a flask.","Free"),
      ("🎂","Bake something that scares you","Pick the ambitious recipe you'd never try, and win together.","Low cost"),
      ("🛏️","The duvet day","Cancel everything, stay in, watch a whole series.","Low cost"),
      ("🕯️","Candlelit dinner at home","Cook together, dim the lights, phones away.","Low cost"),
      ("🌨️","Snowy walk and hot drink","A short cold walk that ends somewhere warm with cocoa.","Low cost"),
      ("🍿","Themed movie night","A whole evening built around one country or decade of film.","Low cost")],
    faqs=[("What are good winter date ideas?","Cosy nights in and crisp days out: ice skating, a Christmas market, hot cocoa and a movie, or winter stargazing. The cold is the perfect excuse to huddle up."),
      ("What's a cheap winter date?","Living-room camping, the ultimate hot cocoa, or a snowy walk that ends somewhere warm. See more <a href='/cheap-date-ideas'>cheap date ideas</a>.")]),

  dict(slug="summer-date-ideas", em_word="Summer",
    title="Summer Date Ideas — 10 Sunny Ideas for Couples | iLovu",
    desc="Summer date ideas for couples &mdash; wild swims, sunset picnics, golden-hour walks, paddleboarding and long light evenings that make the most of the season.",
    og="Summer Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Summer',
    h1='Summer Date Ideas for Long, <em>Light</em> Evenings',
    lead="Long days and warm nights are a gift for couples &mdash; more hours, more places, fewer reasons to stay in. These summer date ideas make the most of the season.",
    ideas=[("🏊","Wild swim","Find water and get in. A screaming, laughing, unforgettable free date.","Free"),
      ("🌅","Sunset picnic","Blanket, snacks, and a spot facing west as the light goes gold.","Low cost"),
      ("🌇","Golden-hour walk","Time a walk to end at the best view exactly as the sun sets.","Free"),
      ("🛶","Sunset paddle","Canoe or paddleboard as the day cools down.","Medium"),
      ("🍷","Rooftop drinks","Somewhere high with a view and a warm evening breeze.","Medium"),
      ("🎶","Outdoor live music","A festival, a park gig, a bandstand &mdash; music under an open sky.","Medium"),
      ("🍓","Pick-your-own farm","Fill a basket together, then cook or bake what you picked.","Low cost"),
      ("🔥","Beach bonfire","A fire, the sea, and nowhere you need to be.","Low cost"),
      ("🚴","Cycle to nowhere","Two bikes, a warm day, snacks, no plan.","Free"),
      ("🍦","Ice cream crawl","Two or three spots, one scoop each, rank them on the walk.","Low cost")],
    faqs=[("What are good summer date ideas?","Make the most of the light: wild swimming, a sunset picnic, a golden-hour walk, paddleboarding, or a beach bonfire. Long evenings are perfect for slow, outdoor dates."),
      ("What's a free summer date?","A wild swim, a golden-hour walk, or a cycle to nowhere cost nothing and use the best of the season. More <a href='/outdoor-date-ideas'>outdoor date ideas</a>.")]),

  dict(slug="autumn-date-ideas", em_word="Autumn",
    title="Autumn Date Ideas — 10 Cosy Fall Ideas for Couples | iLovu",
    desc="Autumn date ideas for couples &mdash; leaf-strewn walks, pumpkin patches, foraging, bonfires and cosy candlelit nights that make the most of fall.",
    og="Autumn Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Autumn',
    h1='Autumn Date Ideas for Crisp, <em>Golden</em> Days',
    lead="Autumn hits the sweet spot &mdash; crisp enough for a walk, cosy enough for candles. These fall date ideas make the most of the best-looking season of the year.",
    ideas=[("🍂","The awe walk in the leaves","Walk somewhere the trees are turning and hunt for things that stop you.","Free"),
      ("🍄","Forage and cook","Pick blackberries or whatever's in season, then cook with it.","Free"),
      ("🎃","Pumpkin patch","Pick pumpkins, carve them badly, keep the ugliest.","Low cost"),
      ("🔥","Bonfire and marshmallows","A fire, blankets, and toasting things on sticks.","Low cost"),
      ("🕯️","Cosy candlelit dinner","Cook together as the nights draw in, lights low.","Low cost"),
      ("🎂","Bake something warm","Something with cinnamon and apples that fills the house with smell.","Low cost"),
      ("👻","Scary stories night","Living-room camp-out and one real ghost story each.","Free"),
      ("🚗","A country drive and a hot drink","Chase the colour, stop for cocoa, no destination.","Low cost"),
      ("🥐","Farmers market breakfast","Wander a market early and build breakfast from what you find.","Low cost"),
      ("📚","Read the same book","Cosy season is book-club season. Read one together and argue the ending.","Low cost")],
    faqs=[("What are good autumn or fall date ideas?","Lean into the season: a walk through turning leaves, a pumpkin patch, foraging, a bonfire, or a cosy candlelit dinner as the nights draw in."),
      ("What's a cosy fall date at home?","Bake something with cinnamon, do a scary-stories camp-out in the living room, or read the same book together.")]),

  dict(slug="weekend-date-ideas", em_word="Weekend",
    title="Weekend Date Ideas — 10 Bigger Adventures for Couples | iLovu",
    desc="Weekend date ideas for couples with a little more time &mdash; road trips, sunrise missions, day trips, classes and adventures worth the free hours.",
    og="Weekend Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Weekend',
    h1='Weekend Date Ideas Worth the <em>Free Hours</em>',
    lead="A weekend gives you the one thing weeknights don't: time. These are the slightly bigger date ideas worth waking up for &mdash; day trips, adventures, and slow mornings.",
    ideas=[("🪙","Coin-flip road trip","Flip a coin at every junction and drive where chance takes you.","Medium"),
      ("🌅","Sunrise somewhere new","Set an early alarm and watch the sun rise from a spot you've never been.","Free"),
      ("🥐","Breakfast in a new town","Drive somewhere you've never had breakfast and find the busiest caf&eacute;.","Medium"),
      ("🎯","Try a class together","Pottery, dance, climbing &mdash; book something neither of you has done.","Medium"),
      ("🗺️","Tourist in your own city","Do the obvious tourist thing you've never bothered to do.","Low cost"),
      ("📍","Map-pin dart","Drop a pin within an hour's drive and go explore whatever's there.","Medium"),
      ("🥾","Hike a trail","Pick a proper trail or regional park and make a day of it.","Free"),
      ("🌮","Street food tour","Graze your way across a market or a few streets, one bite at a time.","Medium"),
      ("🍓","Pick-your-own farm","Fill a basket, then cook the haul together that night.","Low cost"),
      ("🚆","The unplanned train","Take the next train out and get off where it looks interesting.","Medium")],
    faqs=[("What are good weekend date ideas?","Use the extra time for something bigger: a coin-flip road trip, a day trip for breakfast, a class you've never tried, or a proper hike. Weekends reward the ideas weeknights can't fit."),
      ("What's a spontaneous weekend date?","A map-pin dart or the next-train-out both hand the day over to chance &mdash; the surprise is the point. More <a href='/adventurous-date-ideas'>adventurous date ideas</a>.")]),

  dict(slug="anniversary-date-ideas", em_word="Anniversary",
    title="Anniversary Date Ideas — 10 Meaningful Ways to Celebrate | iLovu",
    desc="Anniversary date ideas for couples &mdash; meaningful, personal ways to celebrate, from recreating your first date to a time-capsule letter and a year-in-review night.",
    og="Anniversary Date Ideas for Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Anniversary',
    h1='Anniversary Date Ideas That Actually <em>Mean</em> Something',
    lead="An anniversary isn't about outdoing last year &mdash; it's about remembering why. These date ideas look back and forward at once, and cost far less than a fancy dinner you'll forget.",
    ideas=[("🌹","Recreate your first date","Same meal, same music, same nervous butterflies.","Low cost"),
      ("📌","The anniversary map","Pin every place that mattered and revisit one.","Medium"),
      ("💝","Recreate your first-date meal","Find or cook exactly what you ate the first time out.","Low cost"),
      ("✉️","Time-capsule letter","Each write a letter to open on your next anniversary.","Free"),
      ("🖼️","Look through old photos","Go back to the very beginning and watch yourselves change.","Free"),
      ("💍","Renew your tiny vows","Write and read three small promises to each other. No ceremony needed.","Free"),
      ("🍽️","The milestone feast","Cook the most ambitious meal you've ever attempted, together.","Low cost"),
      ("🎞️","The year-in-review night","Trade favourite memories from the year until one of you tears up.","Free"),
      ("🗺️","Dream planning session","Plan the trip you'd take if money were no object.","Free"),
      ("🍷","Old photos, new wine","Open a bottle and scroll back through every photo of you two.","Low cost")],
    faqs=[("What's a meaningful anniversary date idea?","The personal ones land hardest: recreate your first date, write time-capsule letters, or revisit the places that mattered. Meaning beats money on an anniversary."),
      ("What can couples do for a cheap anniversary?","Recreate your first-date meal at home, look through old photos, or renew a few tiny vows. Almost free, and more memorable than a pricey dinner.")]),

  dict(slug="date-ideas-for-married-couples", em_word="Married",
    title="Date Ideas for Married Couples — 10 to Reconnect | iLovu",
    desc="Date ideas for married couples and long-term partners &mdash; simple, meaningful ways to reconnect and keep things fresh after years together.",
    og="Date Ideas for Married Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Married',
    h1='Date Ideas for Married Couples to <em>Reconnect</em>',
    lead="After years together, couples drift less from fighting and more from forgetting to ask the big things again. These date ideas are built to reopen the conversation &mdash; and keep it fun.",
    ideas=[("🌌","The big questions night","Talk about dreams, fears, and where you see the two of you in five years.","Free"),
      ("🤫","Phone-free dinner","Both phones in a drawer in another room. Just talk. See how long it lasts.","Free"),
      ("💛","The appreciation exchange","Take turns naming three things you appreciate. No interrupting.","Free"),
      ("🎸","Learn each other's hobby","Spend an evening teaching each other something you love.","Free"),
      ("🌙","The reverse day","Breakfast for dinner, pyjamas all evening, the whole night backwards.","Low cost"),
      ("📝","Make a wish list for us","Each write five things you want to do together this year, then read them aloud.","Free"),
      ("🎢","Try the thing you're both scared of","Book the class or the activity you keep putting off.","Medium"),
      ("🙏","The gratitude round","Name one thing you're grateful for about the other, until you run out.","Free"),
      ("💬","The 36 questions","Even years in, the <a href='/36-questions'>36 questions</a> surface things you never asked.","Free"),
      ("💃","Slow dance, no occasion","One song, no reason. The small ceremony a long marriage runs on.","Free")],
    faqs=[("What are good date ideas for married couples?","Ones that reopen real conversation and add a little novelty: a big-questions night, a phone-free dinner, the 36 questions, or trying something neither of you has done. Long-term couples drift from routine, not from lack of love."),
      ("How do married couples keep things fresh?","Protect regular one-on-one time, keep asking new questions, and do occasional novel activities together. Small, consistent effort beats one grand gesture a year.")]),

  dict(slug="double-date-ideas", em_word="Double Date",
    title="Double Date Ideas — 10 Fun Ideas for Two Couples | iLovu",
    desc="Double date ideas for two couples &mdash; games, teams and shared activities that work great in a foursome, from board game caf&eacute;s to cocktail contests.",
    og="Double Date Ideas for Two Couples",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Double date',
    h1='Double Date Ideas That Work Great as a <em>Foursome</em>',
    lead="The best double dates give everyone something to do together &mdash; ideally with teams. These ideas keep the energy up and the awkward pauses out.",
    ideas=[("🎲","Board game caf&eacute;","Pick a team game and let the friendly rivalry do the work.","Low cost"),
      ("🍫","Blind taste test, teams","Couples vs couples, blindfolds on, loser buys the round.","Low cost"),
      ("🔓","Escape room","Four heads, one clock. You'll learn a lot about all four of you.","Medium"),
      ("⛳","Mini golf","Nine holes, made-up rules, a wildly unfair scoring system.","Low cost"),
      ("🎳","Bowling or arcade","Classic foursome fuel &mdash; a scoreboard and something to tease over.","Low cost"),
      ("🧠","Trivia night","Team up at a pub quiz and find out who's been holding out.","Low cost"),
      ("🎤","Karaoke booth","A private room, duets, zero dignity, maximum fun.","Medium"),
      ("🍕","Pizza-making night","Everyone builds a weird pizza for someone else at the table.","Low cost"),
      ("🔥","Backyard bonfire","A fire, drinks, and the kind of long talk that goes till midnight.","Low cost"),
      ("🍹","Cocktail-making contest","Two couples, two drinks, one taste-off. Name them, judge them.","Low cost")],
    faqs=[("What are good double date ideas?","Anything with teams or a shared task: a board game caf&eacute;, an escape room, mini golf, a trivia night, or a cocktail-making contest. Games keep a foursome flowing."),
      ("What's a cheap double date?","A pizza-making night, a backyard bonfire, or a home cocktail contest costs little and gets everyone involved.")]),

  dict(slug="long-distance-date-ideas", em_word="Long-Distance",
    title="Long-Distance Date Ideas — 10 Virtual Dates for Couples | iLovu",
    desc="Long-distance date ideas for couples apart &mdash; virtual dates that actually feel connected, from watching a film in sync to cooking together over video.",
    og="Long-Distance Date Ideas & Virtual Dates",
    eyebrow='<a href="/date-ideas">Date ideas</a> &middot; Long-distance',
    h1='Long-Distance Date Ideas That Actually Feel <em>Connected</em>',
    lead="Distance is hard, but a real shared activity beats another 'how was your day' call. These long-distance date ideas give you something to do together, not just talk over.",
    ideas=[("🎬","Watch a film in sync","Press play at the same second (or use a watch-party app) and text through it.","Free"),
      ("🍳","Cook the same recipe over video","Same ingredients, same dish, one video call. Eat 'together' after.","Low cost"),
      ("🎲","Play would you rather","Trade <a href='/would-you-rather-couples'>this-or-that questions</a> and see how in sync you are.","Free"),
      ("💬","Do the 36 questions","Work through the <a href='/36-questions'>36 questions</a> over a call &mdash; distance makes them land harder.","Free"),
      ("📖","Read the same book","Read to the same chapter and discuss it like a two-person book club.","Low cost"),
      ("🎮","Online game night","Pick a co-op game you can play across the miles.","Low cost"),
      ("🖼️","Virtual museum tour","Many museums have free online walkthroughs &mdash; wander one together on a call.","Free"),
      ("🗺️","Plan your next trip together","Plan the visit or the dream trip. Counting down is its own kind of date.","Free"),
      ("🎁","Send a surprise","Order a dessert or coffee to their door mid-call. Effort travels.","Medium"),
      ("⭐","Star-gaze on a call","Step outside at the same time and find the same moon.","Free")],
    faqs=[("What are good long-distance date ideas?","Do something together, not just talk: watch a film in sync, cook the same recipe over video, play would you rather, or work through the 36 questions on a call."),
      ("How do you keep a long-distance relationship fun?","Shared activities and small surprises beat status-update calls. Schedule real 'dates', send the occasional surprise delivery, and keep discovering each other with questions and games.")]),

  dict(slug="questions-to-ask-your-partner", em_word="Closer",
    title="100 Questions to Ask Your Partner to Feel Closer | iLovu",
    desc="Questions to ask your partner &mdash; warm, honest prompts to spark real conversation and feel closer, from playful to deep. Perfect for date night.",
    og="Questions to Ask Your Partner",
    eyebrow='<a href="/date-ideas">For couples</a> &middot; Questions',
    h1='Questions to Ask Your Partner to Feel <em>Closer</em>',
    lead="Couples drift when they stop asking. These questions reopen the good conversations &mdash; some playful, some deep &mdash; and they work anywhere: a car, a dinner, a slow Sunday.",
    ideas=[("💬","What's a small thing I do that you love?","Naming the little things makes them happen more often.",None),
      ("💬","What did you think of me when we first met?","First impressions are a story you rarely get to hear.",None),
      ("💬","What's a dream you haven't told me about yet?","There's almost always one. Asking gives it permission.",None),
      ("💬","When do you feel most loved by me?","The most useful thing you'll learn all week.",None),
      ("💬","What's your favourite memory of us?","Trading memories is how you audit how much you've lived through.",None),
      ("💬","What's something you'd like more of from me?","Braver than it sounds, and worth it every time.",None),
      ("💬","What scares you about the future?","Sharing a fear is the fastest way to feel less alone in it.",None),
      ("💬","What does a perfect ordinary day look like to you?","Not the holiday &mdash; the Tuesday. That's the real answer.",None),
      ("💬","Who in your life shaped you the most?","You learn who someone is by who made them.",None),
      ("💬","What's something you've never told anyone?","Only if you're both ready &mdash; but it changes the room.",None)],
    faqs=[("What are good questions to ask your partner?","Mix playful and deep: 'what's a small thing I do that you love?', 'when do you feel most loved by me?', and 'what's a dream you haven't told me about?'. For a structured version, try the <a href='/36-questions'>36 questions that lead to love</a>."),
      ("What questions bring couples closer?","Questions that invite honest self-disclosure &mdash; about feelings, fears, dreams and memories. Taking turns and really listening is what builds closeness, not the questions alone.")]),
]

def build():
    written = []
    for p in PAGES:
        # Fill derived fields.
        p.setdefault("cta_h2", DEFAULT_CTA_H2)
        p.setdefault("cta_p", DEFAULT_CTA_P)
        p["h1_plain"] = p["h1"].replace("<em>", "").replace("</em>", "")
        # Plain-text FAQ answers for JSON-LD (strip any inline HTML links).
        import re
        def strip(s): return re.sub("<[^>]+>", "", s).replace("&mdash;", "-").replace("&amp;", "&")
        p["faqs_plain"] = [(strip(q), strip(a)) for q, a in p["faqs"]]
        # Cross-links: 4 core links that aren't this page.
        self_href = f"/{p['slug']}"
        p["related"] = [(h, l) for h, l in CORE_LINKS if h != self_href][:5]
        out = os.path.join(SITE, f"{p['slug']}.html")
        with open(out, "w") as f:
            f.write(page_html(p))
        written.append(p["slug"])
    print(f"Generated {len(written)} pages:")
    for s in written:
        print(f"  /{s}")

if __name__ == "__main__":
    build()
