# The home page

What brickworks.diy's front page is for, what it shows and why. The page is
`web/index.html`, `web/landing.js`, `web/home-feed.js` (each post, drawn the
same in the browser and at the deploy) and `web/home-find.js`, on the design
system (docs/DESIGN_SYSTEM.md); its first posts are written in at the deploy
by `tools/web/home_shelf.mjs`.

## The hero: our mark in bricks (hero3d, 2026-11-23)

The owner, 23 Nov: "obviously the hero should in some way contain a
brilliant 3D variation of our logo or something to do with LEGO". The best
product pages lead with the product, alive; here that is a model built in
our CAD, turning in the page, that opens in the studio.

- **The model.** The mark (web/icon.svg: a cube with one corner cut away)
  in 189 real LEGO® parts, written by `tools/web/hero_mark.mjs` into
  `models/brickworks_mark.ldr` (one of the app's examples, Tested:
  `src/dev/tested_models_probe.gd`) and `web/hero/`: a 12-stud cube, 30
  plates tall, its cut 6 studs and 15 plates; outer faces Yellow, Blue and
  Red, the cut's walls Dark Blue and Dark Red and its floor Pearl Gold
  tiles; bricks and plates bonded a course across the one under it, each
  course a step. The front corner, where two seen faces meet, is the red
  face's all the way up, so the colours meet on one straight edge as the
  logo's do (bonded red and blue in turn it read as a zip; the lead, 23
  Nov); the other corners take the colour of the one face seen. Run it again after a change (`--check` says whether the
  files are what it writes; it also writes the piece count into
  `web/index.html` and into the line's words in `web/_lang/*.json`).
- **Where.** Large, and short enough that a laptop's first screen (1280 x
  800, over the beta bar) shows at least 60% of each first-row picture of
  the feed, real builds plainly seen beside it, and a phone's shows its
  first picture begun (the lead, 23 Nov; tools/web/landing_check.mjs). From
  900 px the words on the left and the model beside both lines of the
  title: a 400 px stage (the bricks about 340 px tall) rising 47 px under
  the header, the bricks starting 9 px below its edge, and over the band's
  bottom padding, with Built in Brickworks · 189 pieces · **Open it in the
  studio** one line on its baseline, under the bricks' lowest corner. Under
  900 px a compact band over the words: the model at 45% of the width, its
  line beside it, a word a row. The line names it a build, never the logo
  (docs/TRADEMARKS.md, Decision 1).
- **Open it in the studio** opens the gallery's copy as any shared model's
  Open does (`/app?view=<id>`), once the project's account lists it (the
  last entry of `tools/web/gallery_seeds/seeds.json`; publishing it is a
  production write, so the lead's): `tools/web/home_shelf.mjs` finds it at
  the deploy and writes the link in. Until then it opens the app's own
  copy (`/app?model=res://models/brickworks_mark.ldr`), behind the sign-in
  for a stranger.
- **Drawn by the site's viewer** (`tools/viewer/hero.js`, built into
  `web/viewer3d.js`): each part's own shape from the app's .lbm, less its
  inside and underneath, the studs drawn only where nothing sits on them
  (about 8,000 triangles). The plastic is lit as in a studio: a soft key
  light with its real shadow on the ground and in the cut, a fill, a rim
  and the room in the gloss, worked out where they are seen (a prefiltered
  map's look-ups were half of each frame in software); the seam between
  bricks drawn dark, as the gap between real bricks reads. The ground's
  shadow fades out by 235 LDU round the mark, so it ends softly inside the
  picture. Transparent, on the page's own background, light or dark.
  While bricks fly it draws 0.7 of the pixels across, the studs of a brick
  in the air with 8 sides (the part's own has 16) and none under a brick
  leaving: in software the studs in the air were a quarter of a frame.
- **Alive.** Once a visit (sessionStorage) it assembles in about 2.5 s,
  from the poster's own picture: the finished mark's bricks leave up and
  out of the picture, the top course first, then come down from over its
  top a course at a time, each falling as a dropped thing does, landing
  with the smallest bounce. Nothing appears in mid-air (each starts over
  the picture's top, which fades what crosses it) and a brick in the air
  casts no shadow (the key's shadows begin at the mark's reach). Then it
  sways slowly
  about the mark's own view, resting after 45 s with nobody near it. A drag
  or a touch across turns it and it settles back; focused, the arrow keys
  turn it (Home puts it back); a brick lifts under a mouse. Asked for less
  motion: built and still, turned by hand only.
- **Fast.** The first paint is its poster, in the HTML (`web/img/hero/`,
  WebP with a clear ground, so one picture serves light and dark; the
  stage's one shape, 460 / 414, at 222, 444 and 888 px across; `tools/web/hero_poster.mjs` draws them with the same
  code). `web/landing.js` asks for the viewer only after the page's load,
  at idle, with the hero on the screen, on a device with WebGL 2, four
  cores and not saving data; a device that draws the finished mark slower
  than 40 ms a frame keeps the poster (the assembly's middle frame takes
  about four fifths of that, so it is seen at 30 frames a second or more),
  as does any trouble. The 3D fades in
  over the poster, the same drawing, so nothing moves (CLS 0).

`tools/web/hero_check.mjs` proves it at both sizes, light and dark: the
poster at first paint (its picture taken with the viewer held back, so it
is the page before any 3D), the viewer asked after the load, the assembly's
frames timed to a WebGL fence, the sway, a drag, the keys, a brick lifting,
the stage named and Open it in the studio a link into the app, no layout
shift, a second visit not assembling again, less motion, and no WebGL
keeping the poster with no error.

## Now: the feed (homefeed, 2026-11-23)

The owner: "turn the landing into our lego 'social media' as it
simultaneously advertises and integrates the CAD. Do better!" What the home
feeds of Instagram, Pinterest, Reddit, the model sites and the LEGO® sites
do, and the decisions taken from them, are docs/SOCIAL.md section 11.

What a stranger sees, at 390 x 844 and at 1280 x 800:

1. **One band, one line**, beside the hero (above). "Build, share and find LEGO® models", one
   sentence ("A free CAD in your browser. Every build here was made in it:
   open one, change it, build it."), the search over models, builders and
   real sets, and **Start building**. Signed in, the band gives way to
   **Share a build** (`/app?share`: the studio's share panel for their
   last model) and the tabs.
2. **The feed**, at once under it (the first post begun in the first
   screen, under the hero): one stream of posts, a column on a phone, two from 700 px,
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
  room from the first frame.
- **Nothing slower.** The first picture loads at once (`fetchpriority=high`),
  the rest lazily; three.js only on a 3D turn; the studio only on Try it
  here; the search's script only once the field is used.
- AI second: no title or first screen says AI; the assistant is one pill.
- LEGO® an adjective, the disclaimer in the footer (tests/test_trademarks.py).
- de, fr, es: every new word has its entry (`tools/site_lang.py --check`).

`tools/web/landing_check.mjs` (every deploy) proves the first screen: the
search and Start building whole at both sizes, light and dark, a phone's
first post's picture begun in it and 60% of each of a laptop's first-row
pictures in it (over the beta bar), its pictures drawn, no layout shift,
Show more, the search, the challenge third at the latest, Talk's posts and
the sets. `tools/web/homefeed_check.mjs` drives each post: the served
HTML's links, Like, a comment and Follow asking to sign in, 3D, Try it
here, and signed in, the tabs, a like, a comment and a follow made, and a
visitor signing in from a like.

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
