# The home page

What brickworks.diy's front page is for, what it shows and why (landing,
2026-11-03). The owner: "cleaner and more modern and elegant exemplifying our
amazing product but also the social features and benefits of using
brickworks.diy in a highly intuitive way". The page is `web/index.html` and
`web/landing.js`, on the design system (docs/DESIGN_SYSTEM.md).

## What the best do

Looked at 2026-11-03, at 1440 and 390 px (shots in the unit's scratch):

- **Figma**: four words of headline and one button, beside a stack of work
  made in Figma; every section after is one bold line and one grey line
  over the product moving (videos with a play button). Almost no
  paragraphs.
- **Onshape**: the headline beside one render of a customer's machine, one
  way in (Sign up free), a wall of customers' logos as proof, six icon
  tiles of why people switch, and a way in for each kind of designer.
- **Mecabricks**: the first screen is a render of a community model under
  "Build & Render your 3D LEGO® models online" and Start now; then straight
  into the community's models, each with its maker's avatar and its views,
  stars and comments, and a second row of renders. Community first, but
  dated, and an ad beside it.
- **BrickLink Studio**: a render of a model and one Download button; then
  each feature a short video beside two lines (building, the instruction
  maker, the renderer), then the community (share your designs, the
  designer program, the forum) and a start for beginners.
- **Printables and Thingiverse** answered a headless browser with a
  Cloudflare check and an error page; from docs/SOCIAL.md: both open on the
  community's models, makers' faces and contests, with one way to join.

What they share: one line and one way in, then the product's own work as
pictures, not paragraphs; proof that people are there (makers' faces, their
numbers, a contest); and a way in again at the foot.

## What was wrong with ours

Nine sections, 6,200 px at 1440. One of them showed the community (two strips
of cards) and none of the social site: no challenge, no collection, no
profile, nothing of Build together but one line among six features. Words
before pictures: "How it works" was three panels of text, the features six
more, the assistant four ticks, the web and the desktop two panels, the plans
two more. Two ways in on the first screen pointed at the app (Open the app,
Download for desktop) and none at the gallery.

## The new order

1. **The opening.** The one line, a shorter lede, **Start building** and
   **Explore the gallery**, a line that it is free on the web and the
   desktop, then the app itself. Kept: the line, the badge to /compare and
   the app's picture, the first screen's one picture (its LCP).
2. **Made in Brickworks.** Five models of the gallery, path traced in
   Brickworks (render_probe's `--model`, Best, the product look), one wide
   and four beside and under it, each a link to its page; the first turns in
   3D in its picture's place when pressed (start3d, its code asked for only
   once its picture is in the window). Pictures, not words: the product's
   work is the proof.
3. **Everything a build needs.** The five benefits, a short line each:
   stability (its picture), instructions and parts lists (the booklet), real
   sets (four of the library's, live), free on the web and the desktop, and
   your own AI if you want it, named once and last.
4. **The community.** This month's challenge, live, beside Build together;
   four things a builder does here, each with its icon (like and save,
   comment on a step, follow, post the one you built); then the gallery's
   Top and its collections, live, each card with its maker's avatar and a
   link to their profile.
5. **Build something today.** The two ways in again, and the plans in a
   line.

Gone: How it works (the steps), the six features, the assistant's section,
the web and desktop's panels and the plans' two cards. Each is a page of its
own already (/docs, /compare, /docs/ai, /download, /plans), and each was
words. Makers get a row of their own once the gallery has three; today it
has one, the house.

## Rules it keeps

- Nothing empty: a live part shows only once its pictures have decoded, and
  holds its place with skeletons or its own words until then.
- Nothing slower: the first screen is the same picture and words. Everything
  under it is lazy and asked a screen and a half ahead; the 3D view costs
  nothing until it is in the window.
- AI second: no title or first screen says AI; the assistant is one tile.
- LEGO® an adjective, the disclaimer in the footer (tests/test_trademarks.py).
- de, fr, es: every new word has its entry (`tools/site_lang.py --check`).
