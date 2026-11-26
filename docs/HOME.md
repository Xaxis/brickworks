# The home page

What brickworks.diy's front page is for, what it shows and why. The page is
`web/index.html`, `web/landing.js`, `web/home-feed.js` (each post, drawn the
same in the browser and at the deploy) and `web/home-find.js`, on the design
system (docs/DESIGN_SYSTEM.md); its first posts are written in at the deploy
by `tools/web/home_shelf.mjs`.

## The hero: the studio at work (herostudio, 2026-11-26)

The owner, 26 Nov, for somebody signed out: the studio itself, alive, a
first screen a lot better than it was, and the mark in bricks moved to the
header. What BrickLink Studio, Mecabricks, Rebrickable, Figma and Linear
put on their first screens, and what this one does better, is
docs/HERO.md.

- **What it says.** One headline, "Design LEGO® models in your browser";
  one line, "A free CAD with every LDraw part. Drop bricks on studs, follow
  the steps, render it like a photo and share it with other builders."; one
  primary action, **Start building, free** (`/app`); one secondary, **See
  what people build** (`/gallery`); under them "Nothing to install, on a
  computer, a tablet or a phone" and How it compares with Studio. A visitor
  is shown no search (the gallery has its own, a click away); signed in the
  band is the search alone, as before.
- **The loop.** The real studio, recorded from the app itself:
  `src/dev/hero_capture_probe.gd` plays `tools/site/hero_capture.json` in
  the studio at a fixed 30 frames a second, a pointer (a fingertip on the
  phone) drawn where it presses: bricks taken from the parts bin and
  dropped onto studs, a sports car's 35 building steps played one by one,
  the car turned, then rendered as a photograph, then shared, its link
  made. `tools/site/hero_capture.py` cuts it into a loop with no seam (each
  part crossfaded into the next, the end into the start) twice: the
  desktop's (16:10, 1440 x 900) and the phone's (9:16, 720 x 1280, the
  phone studio), each AV1 with an H.264 copy for a browser without AV1,
  each under 1.45 MB, with its poster (WebP, full and half width, the car
  built). Run it again when the studio's look changes:
  `python3 tools/site/hero_capture.py` (the capture is a windowed run on
  the GPU, through tools/probe.sh); `--check` says whether the files and
  the page agree.
- **Where.** From 900 px the words on the left and the loop beside them,
  in a browser window's frame, the band's yellow light behind it; under
  600 px the words, then the phone's cut under them in a phone's frame, no
  taller than half the window; between, the desktop's cut under the
  words. The feed's first post just under the fold (begun within 1.3
  windows of the top).
- **Fast.** The first paint is the poster, in the HTML with its size given
  (`fetchpriority=high`; `<picture>` picks the width's cut). `web/landing.js`
  asks for the loop only once the page is in (its load), the browser idle
  and the loop in view, and fades it in over its poster once it plays, the
  same picture, so nothing moves (CLS 0). Somebody who asked for less
  motion, or to save data, keeps the poster and the loop is never asked
  for; so does a browser that will not play it. Signed in, the band is not
  shown and nothing of it is asked for.
- **Captions and Pause.** "Drop a brick on the studs", "Follow the steps",
  "Render it like a photo" and "Share it with a link" over the loop as it
  comes to each (`data-cues-desktop` and `data-cues-phone` on
  `#hero-loop`, written by hero_capture.py), in the page's language, and
  not read out: the poster's description tells the whole of it. Muted,
  looping, inline, never with controls; Pause (44 px, named, pressed while
  paused) stops it and its captions until Play (WCAG 2.2.2).

## The header's mark (herostudio, 2026-11-26)

The header's mark, 30 px on every page, turns as the mark in bricks
(hero3d's model, below): 30 frames of one turn of it, side by side in one
picture (`web/img/hero/mark-turn.webp`, 47 KB), drawn by
`tools/site/mark_turn.mjs` with the hero's own drawing
(`tools/viewer/hero.js`, its `pose()`), the first frame the mark as
`web/icon.svg` draws it. At rest the chip is icon.svg. `web/theme.js` asks
for `web/mark.js` once the page has loaded (on a page with the site's
header, for somebody who has not asked for less motion). mark.js fetches
the picture and turns the mark once as a visit begins (sessionStorage),
and again when a pointer comes onto it or it takes the keyboard's focus.
CSS steps through the picture (`web/site.css`, `mark-turn`), so no page
asks for three.js for it. Neither the script nor the picture is in the
first screen's bytes, or in an embed's script budget
(`tests/test_embed_script_budget.py`: theme.js is every page's head
script). Run mark_turn.mjs again after hero_mark.mjs or the hero's drawing
changes.

`tools/web/hero_check.mjs` proves both at 1280 and 390, light and dark: the
width's poster drawn by the load, the loop asked for after it and playing
(the width's cut, AV1 or H.264, muted, looping, inline, under 1.5 MB), its
captions changing, Pause and Play, no layout shift, no three.js; the mark
in bricks in the header turning once as a visit begins, not on the next
page, again on a hover; less motion and saving data keeping the poster with
no loop asked for and a mark that never turns.

## Now: the feed (homefeed, 2026-11-23)

The owner: "turn the landing into our lego 'social media' as it
simultaneously advertises and integrates the CAD. Do better!" What the home
feeds of Instagram, Pinterest, Reddit, the model sites and the LEGO® sites
do, and the decisions taken from them, are docs/SOCIAL.md section 11.

What a stranger sees, at 390 x 844 and at 1280 x 800:

1. **One band**, the hero (above): its headline, its line, Start building,
   free and See what people build, and the studio's loop. Signed in, the
   band is the search alone (models, builders and real sets), with **Share
   a build** (`/app?share`: the studio's share panel for their last model)
   and Share a file beside it, over the tabs (homefix, 2026-11-23). The
   band's foot keeps the page's rhythm: 48 px (`--s-7`) from its last line
   down to its edge and from the edge to the feed's heading, as an inner
   page's head and body are (24, `--s-5`, on a phone).
2. **The feed**, at once under it (the first post just under the fold):
   one stream of posts, a column on a phone, two from 700 px,
   three from 1100 and four from 1560. This week's pick first, then Top and
   New in turn, the month's challenge third with its entries, then a Talk
   thread with its latest reply, the studio to try, more builds, another
   thread, builders to follow, a photo of a real build, and so on. Show
   more adds the next page; there is an end, and the footer.
3. **A build's post**: who made it (their profile, Follow), the day, its
   picture (marked Week's pick or Tested), a **3D** button; its name; a
   pill for how it was made (Designed with the assistant, Built by hand,
   Made with Brickify) and one for what moves or how many steps, each to
   that feature's docs page; like, comments and share, its parts; then the
   studio's verbs, **Open in the studio** (`/app?view=<id>`), **Remix**
   (`/app?copy=<id>`, a copy of their own crediting the builder), **Build
   it** (`&build`, the steps) and **Parts** (its page's parts, to list and
   buy); and the newest thing said of it, with Add a comment.
4. **A Talk post**: who started the thread and on which board, its title
   and first words, its latest reply, the reply count and Reply.
5. **The challenge's post**: its name, brief, days and days left (or its
   round), up to four entries, Enter the challenge and See the entries.
6. **Try the studio, right here**: Try it here puts the studio itself in
   the post (the viewer, `/app?view=<id>`, on the engine without threads,
   since the page keeps its sign-in popups and so is not cross-origin
   isolated; the app may be framed by the site's own pages only, deploy.sh
   `app_closed`). Its Open in Brickworks and the post's Open the whole
   studio take the whole window to a copy of their own.

Signed in, the tabs: **For you** (the stream asked as them: what they
liked, nobody they blocked), **Following** (what the people they follow
made, as /feed has it) and **New** (everything newest first).

In each post, in place: **Like**, a **comment** (its box opens under the
post, the last three said above it, All its comments to the model's page)
and **Follow** ask a visitor to sign in in a dialog over the page, and go
on once they are in, where they were, what was typed kept. **Share** is the
device's own share, else the link copied. **3D**: a pointer resting on a
picture for 0.7 s, or a tap of 3D, turns the model in its picture's place
(`web/viewer3d.js`, asked for then); Escape, or the pointer leaving, puts
the picture back; never unasked for somebody who asked for less motion.

Under the feed, as before: the beta while it is open, the studio and what a
build needs, Build something today.

## Rules it keeps

- **Never empty, honest for a young site.** The first posts are the house's
  seeded gallery, Talk's house threads (once talk.sql is applied), the
  month's challenge; a kind with nothing to show is passed over, never an
  empty post.
- **In the HTML as served.** `tools/deploy.sh` runs `tools/web/home_shelf.mjs`
  after `tools/site.py`: the first six posts are written into the page and
  each language's copy from brickworks.diy's own answers (or
  `web/_home.json`, the last kept with `--save`), their pictures copied
  beside the page (`/img/home/`). A visitor, and a crawler, read posts
  before any script runs.
- **Nothing moves.** `web/landing.js` asks each answer again once the page
  is idle, tells each post there its counts and newest comment in the room
  it holds, and puts the rest in under them; a post's parts hold their
  room from the first frame; the loop fades in over its own poster.
- **Nothing slower.** The first picture loads at once (`fetchpriority=high`),
  the rest lazily; the loop only after the load; three.js only on a 3D
  turn; the studio only on Try it here; the search's script only once the
  field is used.
- AI second: no title or first screen says AI; the assistant is one pill.
- LEGO® an adjective, the disclaimer in the footer (tests/test_trademarks.py).
- de, fr, es: every new word has its entry (`tools/site_lang.py --check`).

`tools/web/landing_check.mjs` (every deploy) proves the first screen: Start
building, free and See what people build whole at both sizes, light and
dark, and no search for a visitor; the studio's loop whole on a laptop and
begun on a phone; the feed's first post within 1.3 windows (over the beta
bar); its pictures drawn, no layout shift, Show more, the search as
somebody signed in has it, the challenge third at the latest, Talk's posts
and the sets. `tools/web/homefeed_check.mjs` drives each post: the served
HTML's links, Like, a comment and Follow asking to sign in, 3D, Try it
here, and signed in, the tabs, a like, a comment and a follow made, and a
visitor signing in from a like.

## Before: our mark in bricks (hero3d, 2026-11-23)

The owner, 23 Nov: "obviously the hero should in some way contain a
brilliant 3D variation of our logo or something to do with LEGO". The mark
(web/icon.svg: a cube with one corner cut away) in 189 real LEGO® parts,
written by `tools/web/hero_mark.mjs` into `models/brickworks_mark.ldr` (one
of the app's examples) and `web/hero/`, drawn by the site's viewer
(`tools/viewer/hero.js` in `web/viewer3d.js`) beside the words: it
assembled a course at a time once a visit, swayed, turned under a drag,
with its poster first and the viewer asked for after the load. It showed
our mark, not our product; since herostudio it is the header's mark, and
the hero is the studio at work.

## Before: the community first (landing, 2026-11-22)

The first screen was one line and a search, the month's challenge beside
it, and a shelf of tabs (Top, New, Real sets in 3D), each one row of ten of
the gallery's cards; under it the latest in Talk, Build together and four
things a builder does, then the studio. It put the community on the first
screen (a phone's first model at 529 px), but as a page with a community
section: the cards were the gallery's, with no way into the studio from
them and nothing to do on them but open them. The critique is
bench/results/landing-2026-11-22/CRITIQUE.md.

## Before: the studio first (landing, 2026-11-03)

The owner then: "cleaner and more modern and elegant exemplifying our
amazing product but also the social features and benefits of using
brickworks.diy in a highly intuitive way". From Figma, Onshape, Mecabricks
and BrickLink Studio: one line and one way in, then the product's own work
as pictures. Its order: the opening ("A CAD for LEGO® models, in your
browser", Start building and Explore the gallery, the app's picture as the
first screen's one picture); Made in Brickworks (five gallery models path
traced in Brickworks, the first turning in 3D when pressed); Everything a
build needs; the community (the challenge, Build together, the gallery's
Top and its collections); Build something today. challengehonours
(2026-11-20) put the challenge and This week's pick under the app's
picture. It cut the page from nine sections to five, but the community
still began two screens down.
