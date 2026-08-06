/* iLovu couple games — a dependency-free "pass the phone" game engine.
 *
 * One engine, three games, three modes:
 *   sync    — you both answer for yourselves; matching means you're in sync.
 *   guess   — one answers for themselves, the other guesses; scored per person.
 *   confess — you both answer "have / never"; the mismatches are the fun.
 *
 * Everything runs client-side: no backend, no sign-up, no data leaves the page.
 * Partner names are the only thing persisted (localStorage), purely so you
 * don't retype them. Mount a game with:
 *
 *   <div data-couple-game="would-you-rather"></div>
 */
(function () {
  'use strict';

  /* ------------------------------------------------------------------
   * Content banks
   * ------------------------------------------------------------------ */

  /* Mirrors iLovu/WouldYouRatherPrompts.swift so the web game asks the same
     120 dilemmas as the app's daily Would You Rather. */
  var WYR = [
    ['Beach day 🏖️', 'Mountain hike 🏔️'],
    ['Fancy dinner 🍽️', 'Street food crawl 🌮'],
    ['Movie night in 🍿', 'Dancing out 💃'],
    ['Watch the sunrise 🌅', 'Watch the sunset 🌇'],
    ['Cook together 🍳', 'Order in 🥡'],
    ['Road trip 🚗', 'Fly somewhere ✈️'],
    ['Plan every detail 📋', 'Totally spontaneous 🎲'],
    ['Coffee date ☕️', 'Cocktail date 🍸'],
    ['Board games 🎲', 'Video games 🎮'],
    ['Camp under the stars ⛺️', 'Cozy cabin 🛖'],
    ['Museum wander 🖼️', 'Live music 🎶'],
    ['Picnic in the park 🧺', 'Rooftop drinks 🍷'],
    ['Early morning walk 🌄', 'Late night drive 🌙'],
    ['Sweet breakfast 🥞', 'Savory breakfast 🥓'],
    ['City break 🏙️', 'Countryside escape 🌾'],
    ['Slow dance at home 🎵', 'Concert front row 🎤'],
    ['Bake a cake 🎂', 'Make a pizza 🍕'],
    ['Stargazing 🔭', 'Bonfire on the beach 🔥'],
    ['Bookshop afternoon 📚', 'Art gallery afternoon 🎨'],
    ['Spa day 💆', 'Adventure park 🎢'],
    ['Winter cuddles ❄️', 'Summer adventures ☀️'],
    ['Tea person 🍵', 'Coffee person ☕️'],
    ['Sunset picnic 🌅', 'Midnight snack run 🌭'],
    ['Dogs 🐶', 'Cats 🐱'],
    ['Live in the city 🌆', 'Live by the sea 🌊'],
    ['Karaoke night 🎤', 'Trivia night 🧠'],
    ['Breakfast in bed 🛏️', 'Brunch out 🥐'],
    ['Handwritten letter ✍️', 'Surprise voice note 🎙️'],
    ['Wine 🍷', 'Cocktails 🍹'],
    ['Comedy show 😂', 'Theatre play 🎭'],
    ['Cook a new recipe 👩‍🍳', 'Revisit our favorite 🍝'],
    ['Aquarium 🐠', 'Botanical garden 🌷'],
    ['Ski trip ⛷️', 'Tropical getaway 🌴'],
    ['Matching outfits 👕', 'Never in a million years 🙅'],
    ['Sing in the car 🎶', 'Deep chats in the car 💬'],
    ['Farmers market 🥕', 'Vintage flea market 🕰️'],
    ['Sunrise coffee ☕️', 'Sunset wine 🍷'],
    ['Netflix marathon 📺', 'Cinema outing 🎬'],
    ['Long hike 🥾', 'Lazy beach nap 😴'],
    ['Cook breakfast 🍳', 'Cook dinner 🕯️'],

    ['Pancakes 🥞', 'Waffles 🧇'],
    ['Sushi 🍣', 'Tacos 🌮'],
    ['Ice cream 🍦', 'Chocolate 🍫'],
    ['Pasta night 🍝', 'Ramen night 🍜'],
    ['Spicy food 🌶️', 'Sweet treats 🍬'],
    ['Cheese board 🧀', 'Dessert board 🍮'],
    ['Breakfast for dinner 🍳', 'Dinner for breakfast 🍲'],
    ['Bake cookies 🍪', 'Make smoothies 🥤'],
    ['Popcorn 🍿', 'Nachos 🧀'],
    ['Wine tasting 🍇', 'Coffee crawl ☕️'],
    ['Lazy brunch 🥐', 'Big Sunday roast 🍗'],

    ['Mini golf ⛳️', 'Bowling 🎳'],
    ['Escape room 🔐', 'Puzzle night 🧩'],
    ['Roller skating 🛼', 'Ice skating ⛸️'],
    ['Pottery class 🏺', 'Cooking class 🍳'],
    ['Dance class 💃', 'Painting class 🎨'],
    ['Bike ride 🚲', 'Kayak paddle 🛶'],
    ['Surfing 🏄', 'Snorkeling 🤿'],
    ['Rock climbing 🧗', 'Zip-lining 🪢'],
    ['Yoga together 🧘', 'Run together 🏃'],
    ['Fishing 🎣', 'Birdwatching 🐦'],
    ['Go-karting 🏎️', 'Arcade night 🕹️'],
    ['Horse riding 🐴', 'Hot air balloon 🎈'],
    ['Beach volleyball 🏐', 'Frisbee in the park 🥏'],
    ['Photography walk 📷', 'Sketching in the park ✏️'],
    ['Axe throwing 🪓', 'Darts night 🎯'],
    ['Flower arranging 💐', 'Candle making 🕯️'],

    ['Backpacking 🎒', 'Luxury resort 🏨'],
    ['Cruise ship 🚢', 'Train journey 🚂'],
    ['Desert adventure 🏜️', 'Rainforest trek 🌴'],
    ['Northern lights 🌌', 'Tropical beach 🏝️'],
    ['New city every trip 🗺️', 'Same favorite spot 📍'],
    ['Tent 🏕️', 'Campervan 🚐'],
    ['Island hopping 🛥️', 'Mountain village ⛰️'],
    ['Safari 🦁', 'Scuba diving 🐠'],
    ['Window seat ✈️', 'Aisle seat 🚶'],
    ['Pack light 🎒', 'Pack everything 🧳'],

    ['Blanket fort 🏰', 'Backyard camping ⛺️'],
    ['Candles and a bath 🛁', 'Fireplace and cocoa 🔥'],
    ['Big cozy sweater 🧶', 'Fluffy socks 🧦'],
    ['Rainy day inside ☔️', 'Sunny day outside ☀️'],
    ['Redecorate a room 🛋️', 'Plant a garden 🪴'],
    ['Slow morning ☕️', 'Adventurous morning 🥾'],
    ['Home spa night 💆', 'Home cocktail night 🍸'],
    ['Read side by side 📖', 'Watch the rain 🌧️'],
    ['Morning cuddles 🌅', 'Late-night talks 🌙'],
    ['Fairy lights ✨', 'Scented candles 🕯️'],
    ['Nap together 😴', 'Stay up late 🌙'],
    ['Grow herbs 🌿', 'Grow flowers 🌷'],

    ['Prank each other 😜', 'Compliment battle 🥰'],
    ['Sing loudly 🎤', 'Dance badly 🕺'],
    ['Scary stories 👻', 'Funny stories 😂'],
    ['Build furniture together 🔧', 'Never again 🙅'],
    ['Water balloon fight 💦', 'Pillow fight 🛏️'],
    ['Truth 🤔', 'Dare 😈'],
    ["Couple's playlist 🎶", "Couple's scrapbook 📸"],
    ['Win the argument 🏆', 'Get the last bite 🍪'],
    ['Couples costume 🎭', 'Solo costume 🦸'],
    ['Tickle fight 🤣', 'Staring contest 👀'],
    ['Make each other laugh 😄', 'Make each other blush 😊'],
    ['Roast each other lovingly 🔥', 'Hype each other up 📣'],

    ['Autumn leaves 🍂', 'Spring blossoms 🌸'],
    ['Snowball fight ❄️', 'Sandcastles 🏖️'],
    ['Christmas market 🎄', 'Summer festival 🎪'],
    ['Pumpkin patch 🎃', 'Berry picking 🫐'],
    ['First snow ❄️', 'First warm day 🌤️'],
    ['Spooky Halloween 👻', 'Cozy Christmas 🎄'],
    ['Hot cocoa season ☕️', 'Iced coffee season 🧊'],
    ['Rake the leaves 🍁', 'Build a snowman ⛄️'],

    ['Early bird 🌅', 'Night owl 🦉'],
    ['Save dessert for last 🍰', 'Eat it first 😋'],
    ['Playlist DJ 🎧', 'Podcast picker 🎙️'],
    ['Map reader 🗺️', 'Free explorer 🧭'],
    ['Big group hangout 👯', 'Just us two 💑'],
    ['Same meal every time 🍔', 'Try something new 🆕'],
    ['Give gifts 🎁', 'Give experiences 🎟️'],
    ['Textbook romantic 🌹', 'Goofy romantic 🤪'],
    ['Beach sunset 🌇', 'City lights 🌃'],
    ['Text all day 📱', 'Save it for tonight 🌙'],
    ['Slow dance in the kitchen 💃', 'Sing into the spatula 🎤']
  ];

  /* Never Have I Ever — warm and playful on purpose. Nothing here is a
     confession anyone should regret making; the brand is anti-pressure. */
  var NHIE = [
    'fallen asleep during a film I chose',
    'pretended to love a gift',
    'googled something mid-argument to prove I was right',
    'eaten the last slice and said nothing',
    'cried at an advert',
    'reread a text five times before sending it',
    'photographed my food before eating it',
    'missed my stop because I was on my phone',
    'sung in the shower loud enough to be heard',
    'worn the same outfit two days running',
    'said "five minutes away" from bed',
    'laughed at completely the wrong moment',
    'hidden a snack so I would not have to share it',
    'looked up an ex online',
    'said I liked a film just to end the conversation',
    'tripped in public and walked on like nothing happened',
    'forgotten someone’s name mid-introduction',
    'danced alone in the kitchen',
    'bought something and hidden the receipt',
    'pretended to be asleep to avoid getting up',
    'talked to a pet like a person',
    'laughed until it genuinely hurt',
    'sent a message to entirely the wrong person',
    'set off the smoke alarm while cooking',
    'worn something of yours without asking',
    'checked whether our star signs match',
    'rehearsed an argument in the shower',
    'gone back to bed straight after breakfast',
    'eaten dessert before dinner',
    'taken a nap to avoid a chore',
    'kept a gift I will never use',
    'mimed the words to a song I did not know',
    'picked a restaurant purely for the dessert',
    'said I was not hungry and then eaten yours',
    'taken the window seat without asking',
    'changed the thermostat and denied it',
    'bought a plant and killed it within a month',
    'planned an entire trip that never happened',
    'screenshotted something you sent me',
    'cried at the wedding of people I barely knew',
    'pretended to enjoy a hike',
    'read the end of a book first',
    'reused a teabag',
    'laughed at my own joke before finishing it',
    'woken you up on purpose because I was bored',
    'left a voice note longer than three minutes',
    'eaten cereal for dinner',
    'taken a compliment badly',
    'been vague about what something cost',
    'gone somewhere mostly for the photo',
    'pretended to be on the phone to avoid someone',
    'fallen asleep on you and drooled',
    'rewatched a comfort show instead of the film we agreed on',
    'kept a receipt for something I will never return'
  ];

  /* ------------------------------------------------------------------
   * Game definitions
   * ------------------------------------------------------------------ */

  var GAMES = {
    'would-you-rather': {
      label: 'Would You Rather',
      mode: 'sync',
      bank: WYR,
      intro: 'You both answer every dilemma. Matching means you’re in sync — mismatching is where it gets interesting.',
      ask: 'Which would you pick?',
      scoreLabel: 'in sync',
      shareVerb: 'were',
      matchText: 'In sync — you both picked the same 💚',
      missText: 'Opposites attract 😄'
    },
    'know-me': {
      label: 'How Well Do You Know Me?',
      mode: 'guess',
      bank: WYR,
      intro: 'Take turns. One of you answers for yourself in secret, the other guesses what they picked. Points go to the guesser.',
      ask: 'Which would you pick?',
      guessAsk: 'Which did they pick?',
      scoreLabel: 'guessed right',
      shareVerb: 'guessed',
      matchText: 'Correct — you know them 💚',
      missText: 'Wrong! Something new about them 😄'
    },
    'never-have-i-ever': {
      label: 'Never Have I Ever',
      mode: 'confess',
      bank: NHIE,
      intro: 'You both answer honestly, in secret. The ones where you disagree are the ones worth talking about.',
      ask: 'Have you ever?',
      scoreLabel: 'the same answer',
      shareVerb: 'matched on',
      matchText: 'Same answer 💚',
      missText: 'New information 🍿'
    }
  };

  var APP_URL = 'https://apps.apple.com/app/id6781237573';
  var NAMES_KEY = 'ilovu_cg_names';

  /* ------------------------------------------------------------------
   * Helpers
   * ------------------------------------------------------------------ */

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  /* Fisher-Yates over the indices, so a session never repeats a prompt. */
  function shuffledIndices(n) {
    var a = [];
    for (var i = 0; i < n; i++) { a.push(i); }
    for (var j = a.length - 1; j > 0; j--) {
      var k = Math.floor(Math.random() * (j + 1));
      var t = a[j]; a[j] = a[k]; a[k] = t;
    }
    return a;
  }

  function track(name, params) {
    if (typeof window.gtag === 'function') { window.gtag('event', name, params || {}); }
  }

  function loadNames() {
    try {
      var raw = window.localStorage.getItem(NAMES_KEY);
      if (!raw) { return null; }
      var v = JSON.parse(raw);
      return (v && v.length === 2) ? v : null;
    } catch (e) { return null; }
  }

  function saveNames(names) {
    try { window.localStorage.setItem(NAMES_KEY, JSON.stringify(names)); } catch (e) { /* private mode */ }
  }

  /* ------------------------------------------------------------------
   * The engine
   * ------------------------------------------------------------------ */

  function mount(root) {
    var key = root.getAttribute('data-couple-game');
    var def = GAMES[key];
    if (!def) { return; }

    var saved = loadNames();
    var st = {
      names: saved || ['', ''],
      total: 10,
      round: 0,
      queue: [],
      picks: [null, null],
      score: 0,
      guessScore: [0, 0],
      screen: 'intro'
    };

    root.className = 'cg';

    /* --- name resolution: blank inputs fall back to friendly defaults --- */
    function name(i) {
      return (st.names[i] && st.names[i].trim()) || (i === 0 ? 'Player 1' : 'Player 2');
    }

    /* In guess mode the answerer alternates each round. */
    function answerer() { return def.mode === 'guess' ? (st.round % 2) : 0; }
    function guesser() { return 1 - answerer(); }

    /* Guess mode alternates who is guessing, so an odd round count would hand
       one partner an extra turn — offer only even lengths there. */
    function lengths() { return def.mode === 'guess' ? [6, 10, 20] : [5, 10, 20]; }

    function prompt() { return def.bank[st.queue[st.round]]; }

    function options() {
      return def.mode === 'confess'
        ? ['I have 🙋', 'Never 🙅']
        : [prompt()[0], prompt()[1]];
    }

    function promptText() {
      return def.mode === 'confess'
        ? 'Never have I ever&hellip; ' + esc(prompt())
        : esc(prompt()[0]) + '<br><span style="opacity:.7">or</span> ' + esc(prompt()[1]);
    }

    /* --- screens --- */

    function header() {
      var mid = st.screen !== 'intro' && st.screen !== 'done';
      var pct = st.screen === 'intro' ? 0 : Math.round((Math.min(st.round, st.total) / st.total) * 100);
      return '<div class="cg-head">' +
        '<span class="cg-label">' + esc(def.label) + '</span>' +
        (mid ? '<span class="cg-count">Round ' + (st.round + 1) + ' of ' + st.total + '</span>' : '') +
        '</div>' +
        '<div class="cg-bar"><i style="width:' + pct + '%"></i></div>';
    }

    function introScreen() {
      return header() +
        '<p class="cg-sub">' + def.intro + '</p>' +
        '<div class="cg-names">' +
          '<div><label for="' + key + '-n1">One of you</label>' +
            '<input id="' + key + '-n1" type="text" maxlength="16" placeholder="Their name" value="' + esc(st.names[0]) + '"></div>' +
          '<div><label for="' + key + '-n2">The other</label>' +
            '<input id="' + key + '-n2" type="text" maxlength="16" placeholder="Their name" value="' + esc(st.names[1]) + '"></div>' +
        '</div>' +
        '<label class="cg-label" style="display:block;margin-bottom:8px">How many rounds?</label>' +
        '<div class="cg-lens">' +
          lengths().map(function (n) {
            return '<button type="button" class="cg-len" data-len="' + n + '" aria-pressed="' +
              (st.total === n) + '">' + n + '</button>';
          }).join('') +
        '</div>' +
        '<button type="button" class="cg-btn" data-act="start">Start playing →</button>';
    }

    function turnScreen() {
      /* picks[0] is always filled first, so an empty slot 0 means it is still
         the first person's turn — in guess mode that is the answerer. */
      var firstTurn = st.picks[0] === null;
      var who = def.mode === 'guess'
        ? (firstTurn ? answerer() : guesser())
        : (firstTurn ? 0 : 1);
      var isGuessing = def.mode === 'guess' && !firstTurn;
      var opts = options();

      return header() +
        '<span class="cg-turn">' + esc(name(who)) + '’s turn</span>' +
        '<div class="cg-prompt">' + promptText() + '</div>' +
        '<p class="cg-sub">' + (isGuessing
          ? esc(name(answerer())) + ' has answered. ' + def.guessAsk
          : def.ask) + ' Keep it secret.</p>' +
        '<div class="cg-opts two">' +
          opts.map(function (o, i) {
            return '<button type="button" class="cg-opt" data-pick="' + i + '">' + esc(o) + '</button>';
          }).join('') +
        '</div>';
    }

    function handoffScreen() {
      var next = def.mode === 'guess' ? guesser() : 1;
      return header() +
        '<div class="cg-handoff">' +
          '<div class="cg-emoji">🤝</div>' +
          '<div class="cg-prompt">Pass the phone to ' + esc(name(next)) + '</div>' +
          '<p class="cg-sub">No peeking at what was just picked.</p>' +
          '<button type="button" class="cg-btn" data-act="ready">I’m ready →</button>' +
        '</div>';
    }

    function revealScreen() {
      var opts = options();
      var a = st.picks[0], b = st.picks[1];
      var matched = matchedThisRound();

      var cells = opts.map(function (o, i) {
        var by = [];
        if (def.mode === 'guess') {
          if (a === i) { by.push(name(answerer()) + ' picked'); }
          if (b === i) { by.push(name(guesser()) + ' guessed'); }
        } else {
          if (a === i) { by.push(name(0)); }
          if (b === i) { by.push(name(1)); }
        }
        var cls = 'cg-opt ';
        if (a === i && b === i) { cls += 'picked-both'; }
        else if (a === i || b === i) { cls += 'picked-a'; }
        else { cls += 'dim'; }
        return '<div class="' + cls + '">' + esc(o) +
          '<span class="cg-who">' + esc(by.join(' · ')) + '</span></div>';
      }).join('');

      var last = st.round + 1 >= st.total;
      return header() +
        '<div class="cg-prompt">' + promptText() + '</div>' +
        '<div class="cg-opts two">' + cells + '</div>' +
        '<div class="cg-verdict" role="status">' + (matched ? def.matchText : def.missText) + '</div>' +
        '<button type="button" class="cg-btn" data-act="next">' +
          (last ? 'See your score →' : 'Next round →') + '</button>';
    }

    function finalScreen() {
      var pct = Math.round((st.score / st.total) * 100);
      var blurb, big, biglabel;

      if (def.mode === 'guess') {
        big = st.guessScore[0] + ' &ndash; ' + st.guessScore[1];
        biglabel = esc(name(0)) + ' vs ' + esc(name(1));
        var lead = st.guessScore[0] === st.guessScore[1]
          ? 'Dead even — you know each other exactly as well 💛'
          : (st.guessScore[0] > st.guessScore[1] ? name(0) : name(1)) + ' knows the other one better 🏆';
        blurb = lead + ' You got <b>' + st.score + ' of ' + st.total + '</b> guesses right between you.';
      } else {
        big = st.score + '<span style="opacity:.5">/' + st.total + '</span>';
        biglabel = def.mode === 'confess' ? 'answers the same' : 'answers in sync';
        if (pct >= 80) {
          blurb = 'Almost the same person 💚 ' + (def.mode === 'confess'
            ? 'You have lived remarkably parallel lives.'
            : 'Pick anywhere — you’ll both be happy.');
        } else if (pct >= 50) {
          blurb = 'Well matched, with enough difference to keep it interesting 💛';
        } else {
          blurb = 'Opposites, comprehensively 😄 That’s more fun to plan around, not less.';
        }
      }

      return header() +
        '<div class="cg-final">' +
          '<div class="cg-big">' + big + '</div>' +
          '<div class="cg-biglabel">' + biglabel + '</div>' +
          '<div class="cg-blurb">' + blurb + '</div>' +
          '<button type="button" class="cg-btn" data-act="share">Share the result</button>' +
          '<button type="button" class="cg-btn ghost" data-act="again">Play again</button>' +
        '</div>';
    }

    function matchedThisRound() {
      return st.picks[0] === st.picks[1];
    }

    function render() {
      var html;
      if (st.screen === 'intro') { html = introScreen(); }
      else if (st.screen === 'turn') { html = turnScreen(); }
      else if (st.screen === 'handoff') { html = handoffScreen(); }
      else if (st.screen === 'reveal') { html = revealScreen(); }
      else { html = finalScreen(); }
      root.innerHTML = html;
    }

    /* --- transitions --- */

    function start() {
      var i1 = root.querySelector('#' + key + '-n1');
      var i2 = root.querySelector('#' + key + '-n2');
      if (i1 && i2) {
        st.names = [i1.value, i2.value];
        saveNames(st.names);
      }
      st.queue = shuffledIndices(def.bank.length);
      st.round = 0;
      st.score = 0;
      st.guessScore = [0, 0];
      st.picks = [null, null];
      st.screen = 'turn';
      track('game_started', { game_name: key, rounds: st.total });
      render();
    }

    function pick(choice) {
      /* Slot 0 is always the first answer of the round; in guess mode that is
         the answerer's own choice and slot 1 is their partner's guess. */
      st.picks[st.picks[0] === null ? 0 : 1] = choice;

      if (st.picks[0] !== null && st.picks[1] !== null) {
        if (matchedThisRound()) {
          st.score++;
          if (def.mode === 'guess') { st.guessScore[guesser()]++; }
        }
        st.screen = 'reveal';
      } else {
        st.screen = 'handoff';
      }
      render();
    }

    function next() {
      st.round++;
      st.picks = [null, null];
      if (st.round >= st.total) {
        st.screen = 'done';
        track('game_completed', { game_name: key, score: st.score, rounds: st.total });
      } else {
        st.screen = 'turn';
      }
      render();
    }

    function share() {
      var text;
      if (def.mode === 'guess') {
        text = name(0) + ' ' + st.guessScore[0] + ' – ' + st.guessScore[1] + ' ' + name(1) +
          ' on "How Well Do You Know Me?" 💕';
      } else {
        text = 'We ' + def.shareVerb + ' ' + st.score + '/' + st.total + ' ' + def.scoreLabel +
          ' on ' + def.label + ' 💕';
      }
      text += '\nPlay free at https://ilovu.io/couple-games';

      track('game_shared', { game_name: key });

      if (navigator.share) {
        navigator.share({ text: text }).catch(function () { /* dismissed */ });
      } else if (navigator.clipboard) {
        navigator.clipboard.writeText(text).then(function () {
          var b = root.querySelector('[data-act="share"]');
          if (b) { b.textContent = 'Copied ✓'; }
        }).catch(function () { /* denied */ });
      }
    }

    /* --- one delegated listener for the whole game --- */
    root.addEventListener('click', function (e) {
      var el = e.target.closest('button');
      if (!el || !root.contains(el)) { return; }

      if (el.hasAttribute('data-len')) {
        st.total = parseInt(el.getAttribute('data-len'), 10);
        render();
        return;
      }
      if (el.hasAttribute('data-pick')) { pick(parseInt(el.getAttribute('data-pick'), 10)); return; }

      var act = el.getAttribute('data-act');
      if (act === 'start') { start(); }
      else if (act === 'ready') { st.screen = 'turn'; render(); }
      else if (act === 'next') { next(); }
      else if (act === 'share') { share(); }
      else if (act === 'again') { st.screen = 'intro'; render(); }
    });

    render();
  }

  /* ------------------------------------------------------------------
   * Tab switcher for pages hosting more than one game
   * ------------------------------------------------------------------ */

  function initTabs() {
    var tabs = document.querySelectorAll('[data-cg-switch]');
    if (!tabs.length) { return; }
    Array.prototype.forEach.call(tabs, function (tab) {
      tab.addEventListener('click', function () {
        var target = tab.getAttribute('data-cg-switch');
        Array.prototype.forEach.call(tabs, function (t) {
          var on = t === tab;
          t.setAttribute('aria-selected', on ? 'true' : 'false');
          var panel = document.getElementById(t.getAttribute('data-cg-switch'));
          if (panel) { panel.hidden = !on; }
        });
        var heading = document.getElementById(target + '-heading');
        if (heading) { heading.focus(); }
      });
    });
  }

  function init() {
    Array.prototype.forEach.call(document.querySelectorAll('[data-couple-game]'), mount);
    initTabs();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
