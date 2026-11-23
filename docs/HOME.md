# The home page

What brickworks.diy's front page is for, what it shows and why. The page is
`web/index.html`, `web/landing.js`, `web/home-feed.js` (each post, drawn the
same in the browser and at the deploy) and `web/home-find.js`, on the design
system (docs/DESIGN_SYSTEM.md); its first posts are written in at the deploy
by `tools/web/home_shelf.mjs`.

## Now: the feed (homefeed, 2026-11-23)

The owner: "turn the landing into our lego 'social media' as it
simultaneously advertises and integrates the CAD. Do better!" What the home
feeds of Instagram, Pinterest, Reddit, the model sites and the LEGO® sites
do, and the decisions taken from them, are docs/SOCIAL.md section 11.

What a stranger sees, at 390 x 844 and at 1280 x 800:

1. **One band, one line.** "Build, share and find LEGO® models", one
   sentence ("A free CAD in your browser. Every build here was made in it:
   open one, change it, build it."), the search over models, builders and
   real sets, and **Start building**. Signed in, the band gives way to
   **Share a build** (`/app?share`: the studio's share panel for their
   last model) and the tabs.
2. **The feed**, at once under it (the first post within 600 px on a
   phone): one stream of posts, a column on a phone, two from 700 px,
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
search and Start building whole at both sizes, light and dark, the first
post within 600 px on a phone with its pictures drawn, no layout shift,
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
