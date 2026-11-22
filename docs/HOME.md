# The home page

What brickworks.diy's front page is for, what it shows and why. The page is
`web/index.html`, `web/landing.js` and `web/home-find.js`, on the design
system (docs/DESIGN_SYSTEM.md); its first screen's models are written in at
the deploy by `tools/web/home_shelf.mjs`.

## Now: the community first (landing, 2026-11-22)

The owner: "We want the 'forum/gallery' features to be better highlighted
and available immediately upon landing. Critically analyze and brilliantly
implement." The critique, with pictures of ours and the others' first
screens, is bench/results/landing-2026-11-22/CRITIQUE.md.

What was wrong: the first screen sold the studio (a 72 px headline over
three lines, a lede, two buttons, the top of the app's screenshot) and
showed nothing of the community: no model, no builder, no search, no
challenge. The first model sat 2,380 px down a phone (docs/SOCIAL.md R8,
row 10). The header gave Plans the weight of the Gallery and had no Sets or
Challenges. MakerWorld, Printables, Thingiverse, Rebrickable and Mecabricks
all open on the community's models, with a search first and tabs over them.

The first screen now, at 390 x 844 and at 1280 x 800:

1. **One line and a search.** "Build, share and find LEGO® models", one
   sentence of what Brickworks is, a search over models, builders and real
   sets (suggestions as it is typed, `web/home-find.js`), and **Start
   building**. "/" puts the cursor in the search, as in the gallery.
2. **This month's challenge** beside it (under the shelf on a phone), with
   its days left or its round.
3. **The shelf**: tabs Top, New and Real sets in 3D (Trending first once a
   week's Top has four models with pictures), each one row of ten cards
   that scrolls sideways, the gallery's own cards. This week's pick is the
   first card of the first tab, marked Week's pick. See all opens the tab's
   whole list.

Then:

4. **What builders are talking about** (`#talk-latest`), the forum's
   latest threads (unit talk, `/api/people?op=talk_latest&html=1`, its rows
   drawn by Talk), asked only once the header links to Talk and hidden
   until it answers with three, never an empty box.
5. **Build together**, and four things a builder does here.
6. **The beta**, while it is open.
7. **The studio**: the app's picture (no longer the first screen's), will
   it stand, the booklet, four real sets live, free, your own AI.
8. **Build something today**, the way in again.

The header on every page (`web/_shell.html`): Gallery and Challenges, then
Docs (Talk joins after Challenges when it lands: the four links the owner
capped the bar at); Open the app and Sign in far right. Plans and Desktop
app are in the phone menu, the account menu and the footer. Sets stays the
gallery's tab and the shelf's, as the owner had it ("one is just a tab in
another", 2026-11-02).

## Rules it keeps

- **Honest for a young site.** One row of cards, never a grid that counts
  how few; a tab shows only with four models with pictures; the sets tab
  shows depth that is real today; the talk shows only with talk.
- **In the HTML as served.** `tools/deploy.sh` runs `tools/web/home_shelf.mjs`
  after `tools/site.py`: the shown tab's cards and the challenge are
  written into the page and each language's copy (the other tabs, a
  third of the page if written too, come when first opened) from brickworks.diy's own answers
  (or `web/_home.json`, the last kept with `--save`), the cards' pictures
  copied beside the page (`/img/home/`, the CDN, a day's cache, never the
  bucket). A visitor sees models before any script runs.
- **Nothing moves.** `web/landing.js` asks each tab again once the page is
  idle (the others when first opened) and swaps a card only for one whose
  picture has decoded, in a row of the same height (each card's words a
  fixed height). What comes under the first screen comes only while its
  place is out of sight.
- **Nothing slower.** The first card's picture loads at once
  (`fetchpriority=high`), the rest lazily, as the row is laid out (four at
  once were drawn into the first frame and put a laptop's first paint back
  726 ms, bench/results/landing-2026-11-22 timing3); the app's screenshot, the
  old largest paint, is lazy below the fold; the search's script loads
  only once the field is used; the old five renders (195 KB) are gone.
- AI second: no title or first screen says AI; the assistant is one tile.
- LEGO® an adjective, the disclaimer in the footer (tests/test_trademarks.py).
- de, fr, es: every new word has its entry (`tools/site_lang.py --check`).

`tools/web/landing_check.mjs` (every deploy) proves it: the search and
Start building whole in the first screen at both sizes, light and dark, the
shelf's cards with their pictures, at least one whole in view, no layout
shift as the live answer comes, the tabs, the search, the challenge, the
talk and the sets.

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
