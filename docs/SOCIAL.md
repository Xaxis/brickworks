# brickworks.diy as a social site: research and plan

The owner (2026-10-22): "drastically improve the brickworks.diy site, it
needs to feel and act much more like a 'social media' site… the UI/UX of
the gallery need to be drastically improved, including individual gallery
page items… a cohesive design system… a light color theme as an option…
the users account/profile page needs to be drastically improved."

This page is the research behind the work and the plan for it: what the
site has (section 1), what the best sites of its kind do (2), where the
design system stands and what a light theme needs (3), the decisions taken
(4), and the work in units, foundation first (5). Section 6 is the top ten
and the first three units, for a lead to brief from. The website only; the
app's own interface is not in scope.

The pictures it is based on are in `bench/results/social81-2026-10-22/`
(git-ignored, so kept in the social81 worktree, not the repository):
`live-*` are brickworks.diy on 2026-10-22, signed out, Chromium on
SwiftShader at 390 x 844 and 1280 x 900, full page and first screen
(`-fold`); `standin-*` are the same pages made from this checkout's `api/`
with `tools/web/design_stand_in.mjs`'s people and models
(`node tools/web/design_flow.mjs --only=person,feed,account,collection,model,challenge`),
because the live site has no public profile and nobody signed in to show.
That run passed: 68 pages and dialogs, 508 controls, 0 failures.

## 0. The short of it

The site already has most of a community's parts, more than most sites
of its kind at this size: share links, a gallery with search, filters and
build-led ranking, model pages with versions and a remix line, likes,
favourites, collections, comments on a model and on each step, photos of
real builds, follows and a feed, designers' pages with what their models
earned, Tested, "what can I build with my parts", and a monthly challenge.
They were built one unit at a time, each correct and careful, and they
read that way: a page of words about features, not a place full of
people's work. Four things make it feel unsocial:

1. **No people.** No avatar anywhere, not on a card, a comment, a feed row
   or a profile. The live gallery's seven models are all credited to
   "Brickworks" and none links to a profile (`/sitemap.xml` lists no `/u/`
   page). Every social site researched puts a face beside the work.
2. **Words before work.** The gallery's first screen on a phone is a
   title, a four-line lede, a search box and a folded Filters bar; the
   first card of the grid starts 916 px down, below the 844 px screen
   (`live-gallery-390-dark-fold.png`). On a laptop the grid starts at
   962 px, below the 900 px screen, and the only card above it is a
   one-card shelf whose model is repeated in the grid
   (`live-gallery-1280-dark.png`). A model page explains its own buttons
   in a paragraph; the feed opens with a 60-word lede.
3. **Actions as sentences.** Like, Favourite, Add to a collection, Follow,
   I built it are all text buttons, no icon, no count on the button; the
   count sits elsewhere ("0 likes" in a line above). There is no Share.
   Nothing on a card can be acted on from the gallery.
4. **Dead ends.** A model page ends at its licence and remix line: no more
   by its designer, nothing like it. The feed is text rows with no
   pictures (`standin-feed_390_light_in.png`). The challenge page says
   "There is no challenge just now" and nothing else
   (`live-challenge-1280-dark-fold.png`).

And the account page (`standin-account_1280_dark_in.png`, 5,173 px tall)
is a dashboard and a settings form stacked into one page: it is not a
profile, and a person's public profile (`standin-person_1280_light_out.png`)
is a column of sections with two kinds of numbers, no tabs, models cut at
the first page ("More in the gallery" searches their *name*), and their
collections and follows as bare text links.

The light theme exists, but only by the computer's setting: there is no
choice on the site, and the browser's bar stays dark in light mode
(`theme-color` is `#0e1013` on all 14 static pages; the server's pages
have none), and in light a pressed button's yellow edge, the only sign it
is pressed, is 1.33:1 against the page.

The plan: a foundation (tokens, a theme choice, a small component kit and
one card), then the gallery and the model page, the profile and your
account, notifications and a visual feed, then onboarding and the
community's depth: ten units for the first five phases, four of them
large, so about fourteen three-hour units. Every new table is additive.
Nothing needs the owner; one call is the lead's (which account is the
house's, U10).

## 1. What we have

The community's numbers on 2026-10-22, from `/api/share?op=list`: 7
models, all credited "Brickworks" and all designed with the assistant (each
description says so), 0 or 1 views each, 0 likes, 0 builds, 0 remixes. No
public profile. No challenge running. Whatever is built, it is built for a
gallery that is close to empty, so empty states and a cold start matter as
much as the full ones (section 4, D12).

| Feature | Where | How good | Where it is weak (evidence) |
|---|---|---|---|
| Gallery: search, kind, size, instructions, Technic, Tested, sort (Newest, Most viewed, liked, remixed, built, Top builds), tag chips, the question in the address | `web/gallery.html`, `web/gallery.js`, `api/share.js ?op=list` | Solid: fast (30 s CDN), shareable searches, text set safely, ranking that rewards builds over views | Words first, cards late (above). One card a row on a phone, 3 at 1280: a 7-model gallery is 3,932 px on a phone. Filters fold into a bar; Sort is a dropdown. No tabs (New / Top / Following). "Show more" only: the pages it loads are not in the address and nothing keeps the place, so Back keeps it only when the browser's back-forward cache happens to hold the page. Shelves show with one card (Small builds = the sports car, repeated in the grid) |
| This week's pick, Small builds, You can build now (signed in, with a collection) | `supabase/discovery.sql`, `gallery.js` | A real differentiator: Rebrickable's Build engine is the only peer with "build with my parts" ([RB-G]) | A quiet week has no pick, so the front is empty; a shelf of one looks broken |
| The model card (`.model`) | `web/cards.js` `modelCard`; and again `api/people.js` `cardHtml`; and `api/share.js` `smallCard` (`.mini`) | One look, picture held at 1200 x 630 so rows line up, zeros hidden | Three renderers that differ: the server's card has no Moves or parts-owned line, and shows Tested only on a designer's page. No designer avatar or link, no like from the card. The 1200 x 630 frame wastes most of itself on tall models: the Wizard's Tower fills about a sixth of its frame's width (`live-gallery-1280-dark.png`) |
| Model page `/m/<id>`: picture, View in 3D, Open in Brickworks (copy), facts, counts, Like, Favourite, Add to a collection, Built by people (photos, I built it), versions, About, tags, comments on the model and on steps, licence, remix line, Report | `api/share.js` `sharePage`, `web/model-page.js`, `web/directory.css` | Deep: versions with what changed, step comments, real-build photos and the remix line are each more than most peers have | One picture, no gallery of pictures. Two "View in 3D" a few cm apart. Five text buttons in two rows, counts in a separate line that shows zeros ("0 likes 0 remixes 0 built") though cards hide them. No Share, no embed offered (an embed exists at `/m/<id>/embed`). The right column ends a third of the way down and the rest of the page is a 72-character column on the left (`live-model-tower-1280-dark.png`). Comments are flat, oldest first, no replies. Nothing to go to next |
| Real builds: "N built" (once per device, no account), photos of real builds | `supabase/builds.sql`, `api/_builds.js`, `api/_photo.js` | Excellent and safe (metadata stripped, 13+, owner can hide) — the equivalent of Printables' and Thingiverse's Makes ([PR-M], [TV]) | Called three things ("built", "Built by people", "I built it: add a photo"); the strip's caption sizes differ from the quote's |
| Likes, Favourites, Collections | `supabase/people.sql`, `api/people.js` | Work; public collections have a page `/c/<id>` | Like and Favourite are two near-identical buttons. A collection is a list of text links on a profile, no cover; its page is a plain grid. Nobody can follow a collection |
| Comments (model and step), hide, remove, report, comments off, a daily email | `supabase/comments.sql`, `api/_comments.js`, `web/model-page.js` | Careful rules, step comments are unique to Brickworks | No replies, no avatar, oldest first, "Sign in to comment" is the whole box when signed out |
| Follows and the feed `/feed`, the count on Account | `supabase/follows.sql`, `api/_follows.js`, `web/follow.js`, `web/feed.*` | Counts, not lists; nobody told they were followed; no messages (COMMUNITY.md): right for a site with children on it | The feed mixes what people you follow did with what happened to your models; text rows, no pictures, no avatars; signed out it is one paragraph and Sign in (`live-feed-390-dark.png`) |
| Profile `/u/<handle>` (Designer or Builder): name, handle, since, bio, earned tiles, counts, Follow, Start with, Challenges won, Built by others, Models, Built, Follows, Collections, Report | `api/people.js` `profilePage`, `supabase/designers.sql` | The designer's tiles say what matters here (builds finished, remixes, Tested) | No avatar, no banner, no links. Two systems of numbers (tiles, then a line). Follow under the numbers. One long column of seven sections, no tabs. Models cut at the first page; "More in the gallery" searches the person's name, so it finds anybody's model that mentions it |
| Your account `/profile` | `web/profile.html`, `web/profile.js`, `web/designs.js` | Complete: your models' numbers, favourites, collections, sets, following, builds, settings, Claude, delete | A dashboard and every setting on one 5,000 px page under a letter avatar; nothing of it looks like your profile; editing your public name is a form under Settings |
| Challenges `/challenge` | `supabase/challenges.sql`, `web/challenge.*` | Rules checked on the stored model; hand-built and assistant-built entries kept apart | Between challenges the page is one sentence: no past challenges, no winners, no "next" |
| Designers' numbers, This week's pick on /admin, reports and takedowns, the age question | many | Careful | Not the owner's ask; stays |
| Light theme | `web/site.css` `@media (prefers-color-scheme: light)` | Every token redefined, contrast measured (`live-*-light.png`) | No choice on the site; follows the computer only; `theme-color` dark on every static page |

What to keep whatever changes: Top builds' weighing (a build 3, a remix
2, Tested 5, views 0), counts-not-lists for follows, the trust rules
(13+, may_act limits, reports), the remix line and licences, step
comments, Tested, and every rule in `docs/COMMUNITY.md`.

## 2. What the best do

Printables and MakerWorld (3D printing), Thingiverse, Sketchfab,
Mecabricks, Rebrickable MOCs, BrickLink Studio's gallery, Instagram,
Pinterest, Dribbble and Behance. Several block automated reading
(Printables, MakerWorld, Thingiverse answered 403), so some of what
follows is from their help pages, their own announcements, captured page
text in search results and third-party guides; each claim names its
source (the list is at the end).

### The model page

- **The work is the biggest thing on the page.** Dribbble's 2020 shot
  page: the shot "nearly full width, up to 1400px… far and away the
  biggest focal element on the page", metadata moved down ([DR]).
  Behance: "large hero images fill the screen", project and creator
  details at the top and bottom ([BE]). Sketchfab's page is its 3D
  viewer, Embed below it ([SK-E]).
- **One action bar, always in reach.** Dribbble: "a new, persistent
  navigation that lets you easily like, share, and add Shots to
  collections" ([DR]). Behance: Share, Save, Follow, Appreciate at the
  top and bottom ([BE]). Printables: Download and Like with likes,
  downloads and views counted beside ([PR-M]).
- **Like and Save are different acts.** Like is applause; Save puts it in
  a collection (Printables' collection ribbon and its Collections tab
  counting public and private collections a model is in, [PR-C];
  Dribbble and Behance Save; Sketchfab collections with Subscribe,
  [SK-P]). None has a second private "favourite" beside Like.
- **Makes: proof that people built it.** Printables has a Makes tab
  beside Comments with Add make ([PR-M]); Thingiverse's Makes are a photo
  and the printer's settings, which researchers describe as "a stronger
  form of like" ([TV-R], [TV]); MakerWorld's print profiles with ratings
  ([MW-F]). Brickworks' Built by people is the same thing, with the
  advantage that "built" is also counted from the step player.
- **Remixes and where it came from.** Printables shows "Model origin" and
  "Differences of the remix compared to the original" ([PR-M]);
  Thingiverse treats remix as a many-to-many link ([TV-R]).
- **The page leads on.** Dribbble put "a full-width assortment of a
  Dribbbler's additional related work" under the shot, then "Similar
  Work… surface[d] from all of Dribbble" ([DR]).
- **Parts, instructions and "can I build it".** Every Rebrickable MOC has
  instructions and a parts list, and the Build engine checks it against
  what you own ([RB], [RB-G]). Mecabricks: view in 3D, part inventory,
  edit ([MB-E]). BrickLink Studio's gallery: Private, Display (no file),
  or Full Access (instructions, parts list, download as the designer
  allows) ([BL]).

### The gallery

- **Pictures, a face and a few numbers on each card.** Sketchfab: a
  thumbnail, the title and "a small author avatar that links to the
  creator's profile" ([SK-P]). Mecabricks' cards: thumbnail, counts, the
  title and the creator linked to their profile ([MB]).
- **Tabs and time windows.** Sketchfab's Popular, Staff picks,
  Downloadable, Collections, **Human Created** and **AI Generated**, with
  "This week" and "Most liked" ([SK-P]). Staff picks are chosen by people,
  "We update this page daily", most from the past few days ([SK-S]).
- **Endless, but with an end.** NN/g: infinite scrolling suits browsing
  "homogeneous items with no particular task", but it hides the footer
  and loses the place on return; a Load More button "is a clear
  indication that there is more" and gives the footer back ([NN-IS]).
  Sketchfab uses "load more" ([SK-P]).
- **Grid shape.** Pinterest's masonry places each item in the shortest
  column; it needs every height first ([W3C-M]). Instagram moved its
  profile grid from squares to tall 4:5 / 3:4 tiles in 2025 because most
  of what is posted is vertical ([IG], [IG-M]). For renders of one shape a
  uniform grid is the right one; masonry fits mixed photos (Brickworks'
  build photos).

### The profile

- **Header:** avatar, name, handle, bio, links, counts, Follow; then the
  work. Printables: a level badge and tabs About, 3D Models, Makes,
  Activity, Collections, each with its count ([PR-P]). Dribbble: Work,
  Collections, Liked Shots, About, with Follow ([DR-P]). Sketchfab:
  followers and following, models, collections, likes ([SK-P]).
- **Pinned work.** MakerWorld's new profile Home pins up to 8 designs and
  shows achievements; its users complained that pins could not be
  reordered, that counts were missing, and above all that "recent makes"
  were shown without asking: "Forcing this through without my consent is
  diabolical" ([MW-H]). So: pins people can order, counts on every tab,
  and nothing of a person's activity shown unless they chose it.

### Feed, notifications, onboarding

- **Grouped notifications.** "X and 3 others liked…" is grouped by thing,
  newest first; Discourse's users found grouped likes sorted by the oldest
  sank new activity ([DC]); Android groups from four ([AN]).
- **Empty states teach and lead.** NN/g: say the status, say what goes
  here, give "direct pathways for getting started" ([NN-ES]).
- **Come for the tool, stay for the network.** Andrew Chen's cold-start
  playbook: a product useful to one person alone, which then turns its
  users into a network; the hard side (creators) is the few who do most
  of the work ([AC]). Brickworks is the tool; the site's job is to turn
  people who build into people who share and follow.

### The theme switch

- **Three choices, the system's by default.** GitHub: a theme that
  "either follows your system settings or always uses a light or dark
  mode", in Settings › Appearance, per account ([GH]).
- **Tokens, `color-scheme`, no flash, remember it.** web.dev: semantic
  custom properties, `color-scheme: light dark` so form fields and
  scrollbars follow, follow the system by default with a remembered
  override, update `theme-color`, and avoid a flash of the wrong theme
  ([WD]). A flash is avoided by setting the theme before the first paint,
  from a small script in `<head>` that reads the saved choice.

## 3. The design system

`docs/DESIGN_SYSTEM.md` and `web/site.css` are a good base: one shell
(header and footer from `web/_shell.html`, checked by
`tests/test_site_shell.py`), one type scale for titles, one rhythm, one
field, the buttons, the dialog, the card, and `tools/web/design_flow.mjs`
checking every page at 390 and 1280 px, light and dark, signed in and out
(68 checks, all pass today). What the pages do not hold to, measured in
`web/site.css`, `web/directory.css` and the pages' own `<style>`:

| Measure | Now | Should be |
|---|---|---|
| Font sizes | 33 distinct values (14 px x33, 14.5 x23, 13 x12, 15 x11, 13.5, 12.5, 12, 22, 17, 16, 26, 20, 28, 23, 19, 16.5, 32, 25, 21, 17.5, 15.5…) for 7 type tokens | 8 tokens: display, h1, h2, h3, body 16, small 14.5, tiny 13, micro 12 |
| Corner radii | 16 distinct (`--radius`, 12, 999, 8, 9, 10, 6, 7, 50%, 4, 3, 16, 14, 13, 0) for 2 tokens | 4 tokens and two shapes: `--r-1` 6, `--r-2` 10 (controls), `--r-3` 14 (cards, panels), `--r-pill`, a circle |
| Pills | 6 copies: `.facts li`, `.tags a`, the gallery's `.chips button`, `.tested-mark summary` and `.model .tested`, `.comment-head .tag`, `.feed-row .tag` | one `.pill` (and `.pill.button`, `.pill.good`, `.pill.new`) |
| Model cards | 3 renderers (above) | one |
| Per-page `<style>` | 13 pages; the gallery's 58 lines include a control (the tag chips' button) | layout only, no controls |
| Raw colours | 15 outside `:root`: the 404's brick art, `#c9a227` on terms, guidelines and takedown, `#f2c536` on /admin | tokens; a `--note` for the legal pages' marked box |
| Icons | none on the site | one sprite of a dozen (heart, bookmark, share, comment, built, remix, bell, sun, moon, more, search, close) |
| Avatar | none (a letter on /profile only) | `.avatar` in four sizes, a picture or a generated one |
| Tabs | none (a `.subnav` rail on /profile) | `.tabs`: a row of links or buttons, one `aria-current`, scrolling inside itself on a phone |
| Zero counts | hidden on cards, shown on the model page ("0 likes") | hidden everywhere; a button shows its count only when not zero |

**What a light theme needs.** The colours are already tokens with a light
set, measured at 4.5:1 or better. Missing:

1. **A choice.** System, Light or Dark, as three buttons in a row
   (`.segmented`, the pressed one `aria-pressed`): in the footer of every
   page and on Menu at a phone's width for everybody, in the account menu
   and in Settings › Appearance once signed in. System by default. Not a
   fifth thing in the header: `tests/test_site_shell.py` holds it to four,
   after the owner found it crowded (2026-10-20).
2. **Tokens that answer to it.** The light set moves from
   `@media (prefers-color-scheme: light) { :root {…} }` to
   `:root[data-theme="light"]`, and the system's choice applies only when
   none was made: `@media (prefers-color-scheme: light) {
   :root:not([data-theme]) {…} }`. `color-scheme` follows, so the
   browser's own controls and scrollbars do too.
3. **No flash.** The theme is set before the first paint by a tiny
   external script loaded without `defer` in every page's `<head>`
   (`/theme.js`, under 1 KB, kept by the browser): it reads the saved
   choice and sets `data-theme` and the `theme-color`. It must be a file:
   the server's pages (`/m/`, `/u/`, `/c/`) are served with `script-src
   'self'` and allow no inline script at all (`api/share.js` `pageCsp`),
   and the static pages allow only hashed ones (`tools/deploy.sh`).
4. **Remembered per browser and per account.** In this browser in
   `localStorage` (a preference, not tracking; the privacy page says so).
   For a signed-in person also on their account, so a new browser follows
   them once they sign in: an additive column on `public.profiles` (one
   row an account, deleted with it).
5. **`theme-color` per theme**, and the 404's brick colours, the legal
   pages' `#c9a227` and /admin's yellow as tokens.
6. **Pictures in both.** Model renders sit on a light grey backdrop; in
   the dark theme they are bright tiles. Acceptable now; a backdrop that
   sits in both is an app change at publish, later (U15).
7. **An edge colour that shows in light.** Every text token passes in both
   themes (measured: the faintest, `--ink-faint`, is 5.04:1 in dark and
   5.30:1 in light at worst), but the yellow accent is 1.33:1 on the light
   surfaces, and it is the only mark of a pressed toggle
   (`.cta.ghost[aria-pressed="true"]`: Following, a liked Like), the New
   pill, the older-version box and the designer's leading tiles. WCAG
   1.4.11 asks 3:1 for a control's state. A `--accent-edge` token: the
   yellow in dark, `#a67c00` in light (3.28:1 on `--bg-soft`, 3.82:1 on
   `--panel`). Buttons that are yellow keep the yellow; their words are
   11.96:1 on it. (`standin-model_1280_light_in_pressed-top.png`: "In
   your favourites" is pressed, and only just looks it.)

## 4. Decisions

Each decided here, with its reason (`brickworks-decide-dont-wait`).

- **D1. The trust rules stay.** No list of anybody's followers, nobody
  told they were followed, no messages, likes told as counts, 13+ for
  anything public. A "social" feel comes from faces, pictures, quick
  actions and things happening, not from these. The site has children on
  it (COMMUNITY.md, the age question), and MakerWorld's users revolted
  when activity was shown without consent ([MW-H]).
- **D2. Like and Save.** Like stays (applause, counted). Favourite and Add
  to a collection become one **Save**, a bookmark that opens your lists
  with Favourites first. Every peer has like + save ([DR], [BE], [PR-C]);
  none has two private-ish buttons. Existing favourites stay where they
  are (Favourites is that first list).
- **D3. A 4:3 card picture**, cut from the middle of today's 1200 x 630
  picture by `object-fit: cover`, so a model shows 1.43 times larger at
  the same card width. Measured on the seven live pictures, each model
  fills the picture's height (rows 32-598 of 630) and 12% to 75% of its
  width: the middle 70% a 4:3 cut keeps holds six of them whole, and the
  castle (13%-87%) loses 28 px of baseplate at each side. The share
  picture stays 1200 x 630 for link previews; a 4:3 render made at
  publish (U15) ends the cut.
- **D4. A uniform grid, not masonry**, for models: one shape of picture,
  rows that line up, no script to place them ([W3C-M]). Masonry for build
  photos, which are any shape.
- **D5. Endless with an end.** The gallery loads the next page as you
  near the bottom, three times, then a Show more button; the page number
  is in the address and Back returns to the same card ([NN-IS]).
- **D6. Top builds stays the default order**, as "Top", with time windows
  (this week, this month, all time), beside New and, signed in,
  Following. Views never rank.
- **D7. Hand-built and With the assistant are said and filterable**, as
  Sketchfab's Human Created and AI Generated ([SK-P]): a mark on the card
  and a filter. The community distrusts AI-designed work (a Reddit reply
  to the owner's post, 2026-10-13: "that Assistant looks worryingly AI…
  a LOT of us… building freely… not AI designed") and the guidelines
  already ask for the label (`ai-designed`, `brickify` tags). Read from
  the tags until the app says it at publish (U16).
- **D8. Theme: System, Light, Dark**; System by default; the browser
  remembers, the account remembers (section 3).
- **D9. Your profile is your public page with Edit**, as on Instagram,
  Printables and Dribbble. `/profile` shows your `/u/<handle>` page with
  owner-only tabs (Saved, Sets, Insights) and an Edit profile button.
  Settings move to `/settings`. Signed in without a profile, `/profile`
  makes one in two fields.
- **D10. Notifications apart from the feed.** What happened to your work
  (comments, replies, builds and photos, remixes, likes as a number,
  challenge results) is Notifications; the feed is what the people you
  follow made. Today's `feed_rows` already has both kinds; they are split
  by kind. The header keeps its four things: signed in, Account becomes
  your avatar, carrying today's count, and opens a menu (Your profile,
  Notifications with its count, Your feed, Saved, Settings, the theme,
  Sign out), as GitHub's and YouTube's do.
- **D11. Avatars: a generated one for everybody, a picture for who wants
  one.** Generated from the handle (a coloured tile and the initial, no
  figure likeness: the Minifigure is a mark, `docs/TRADEMARKS.md`). An
  uploaded picture goes through the build-photo pipeline (metadata
  stripped, at most 8 MB, reportable, removable by the owner on /admin),
  13+ as every public thing. A banner is one of their own models'
  pictures, chosen, never an upload.
- **D12. The cold start is designed, not waited out.** Every empty state
  says what goes there and gives the way in ([NN-ES]); a shelf shows only
  with three cards; the house account gets a real profile so its models
  are credited to a person-shaped page; the signed-out feed shows the
  latest public activity rather than one sentence.
- **D13. No new tracking.** Similar models come from kind and tags, not
  from who looked at what. Views stay counted as now (HMAC, never a
  robot, never ranked). The third-party counter stays off `/m/`, `/u/`,
  `/c/`. Account deletion removes everything new (every new table
  references `auth.users` `on delete cascade`, and any new stored file is
  deleted by name first, as `api/account.js` does for photos).

## 5. The plan

Sizes: **S** under half a unit, **M** one unit (about three hours), **L**
two units. Every unit: looked at 390 and 1280 px in light and dark;
`design_flow.mjs` passes; a new browser flow is wired into
`tools/release/preview_checks.sh`; `.claude/skills/verify/` updated;
Supabase changes additive, in a new `supabase/*.sql` applied by the lead.

### Phase 1: foundation

**U1. Tokens and the theme choice** (M). *What:* the token set completed
(type to 8 sizes, radius to 4, `--note`, the 404's colours,
`theme-color`), a `.segmented` control (three buttons in a row), the
light set keyed on `data-theme`, `/theme.js` in every page's head
(static pages through `web/_shell.html` and `tools/site_shell.py`, the
server's through `siteChrome`), the theme control in the footer, on Menu
and in Settings (section 3), the choice in `localStorage` and on the
account (`profiles.theme`, `GET/POST /api/account?op=theme`), the privacy
page's line. *Why:* the owner's ask; section 3. *Now:* system only.
*Acceptance:* at 390 and 1280, on all 16 static pages (the 14 with the
site's header, /admin and the Claude sign-in page) and `/m/`, `/u/`,
`/c/`: choosing Light, Dark or System changes the page at once, with no
reload; a reload and a new tab keep it; a probe reading `body`'s
background at first paint finds the chosen theme, never the other (no
flash); signed in on a fresh browser profile, the account's choice applies
on the first page after sign-in; the browser bar's colour follows; every
text token measures 4.5:1 or more on each surface it sits on, and a
pressed toggle's edge 3:1 or more, in both themes (a script, not by
eye); deleting the account removes the choice.
*Supabase:* `alter table public.profiles add column if not exists theme
text check (theme in ('system','light','dark'))`.

**U2. The component kit and one card** (M). *What:* `.pill`, `.tabs`,
`.avatar` (generated fallback), `.icon-btn` with a count, an icon sprite,
a toast ("Link copied"), a "more" menu (an icon button says its name
and count to a screen reader, "Like, 12 likes", and a toggle is
`aria-pressed`); one card renderer (a pure string
function the API and the browser both use, `web/card.js`, with a test that
the server's card and the browser's are the same markup); the six pill
copies, the gallery's chip control and the per-page controls deleted;
`DESIGN_SYSTEM.md` updated. *Why:* section 3's table. *Now:* copies.
*Acceptance:* `grep` finds one card renderer and one pill; `design_flow`
extended to fail on a font size, radius or colour off the scale in any
stylesheet or page style, and on a count of 0 shown; every page's
pictures at 390 and 1280, light and dark, show no change a person would
call a regression (before and after shots side by side).

### Phase 2: the gallery and the model page

**U3. The gallery** (L). *What:* a compact head (title and search on one
line, no lede); tabs **Top · New · Following** (signed in), with This
week / This month / All time under Top; kinds as a row of pills that
scrolls inside itself; the other filters (size, instructions, Technic,
Tested, **Hand-built / With the assistant**) in one Filters button that
opens a sheet; the card: 4:3 picture with Tested and Moves marks over its
corner, the name, the designer's avatar and name (linked), and a row of
heart (like from the card, signed in; sign-in asked when not), built and
comments with their counts; 2 columns on a phone, 3 at 900 px, 4 at 1200;
endless to three pages then Show more, page in the address, Back to the
same card; shelves only with 3 cards; empty and "nothing matches" states
with the way in. *Why:* sections 1 and 2; D3-D7. *Now:* above.
*Acceptance:* at 390 x 844 the first card's picture starts within 330 px
of the top and four cards' names are on the first two screens; at 1280 x
900 at least four cards are wholly on the first screen; a like from a
card changes its count at once and the model page shows it liked; Back
from a model returns to the same card within 100 px; a search address
sent to somebody shows the same cards; light and dark. *Supabase:* the list gains each card's designer
handle and avatar and its comment count: a new `directory_models` version
(functions replaced as builds.sql and discovery.sql did; no table change).

**U4. The model page** (L). *What:* the picture large, beside a sticky
column on a laptop, first on a phone, with a strip of more pictures (the
owner's own, added from the page through the photo pipeline, then the
photos of real builds); the column: name, the designer's row (avatar,
name, Follow), facts as pills, **Build it** (View in 3D: steps, booklet,
parts list) and Open in Brickworks (copy), and one action bar of icon
buttons with counts: Like, Save (D2), Share (the phone's share sheet; on
a laptop Copy link and the embed), Comments, I built it; the paragraph
explaining the buttons gone; Report and Takedown in the "more" menu; below,
in-page tabs that stay on screen: About · Comments (n) · Builds (n) ·
Remixes (n) · Versions (n); at the end **More by <designer>** and
**Like this** (same kind and tags) as card rows. *Why:* [DR], [BE], [PR-M];
section 1. *Now:* above. *Acceptance:* at 390 the picture, the name, the
designer and the action bar are on the first screen; at 1280 the column
stays beside the picture as the page scrolls; Share puts the address on
the clipboard and says so; Save opens the lists with Favourites ticked
when it is a favourite; a model with no comments, builds or remixes shows
no zero and no empty section but one line each with its way in; the last
screen always has another model to open. *Supabase:* `model_pictures`
(id, model, account, file, place, hidden_at, removed_at; `on delete
cascade` both ways; the photo's file deleted by name with the account),
or a `kind` column on `build_photos`: the unit chooses, additive either way.

### Phase 3: profile and your account

**U5. The public profile** (L). *What:* a header with a banner (one of
their models' pictures, chosen), the avatar, name, @handle, bio, up to
three links (shown as their domain, `rel="ugc nofollow"`), since when, one
row of numbers (models, builds finished of their models, followers,
following), Follow and Share; **Pinned** (up to 6, in the order they
set); tabs **Models (n) · Builds (n) · Collections (n) · Likes (n, only
when they chose to show it) · About**, each paged to the end (no more
"More in the gallery" by name); collections as cards with a picture
mosaic; the designer's earned tiles folded into the numbers row (builds
finished and remixes first, as Top builds weighs them). *Why:* [PR-P],
[DR-P], [MW-H]; section 1. *Acceptance:* at 390 the avatar, name, numbers
and Follow are on the first screen and the tabs are a row that scrolls
inside itself; every model of a person with 60 models can be reached from
their profile; Likes appears only after its owner turns it on; a profile
under 13 or taken out is not shown (as now). *Supabase:* `people` gains
`avatar` (a photo id), `banner_model`, `links` (jsonb, at most 3),
`shows_likes` (default false); `profile_pins` (account, model, place);
new versions of `profile_page` and `directory_card`.

**U6. Your account, as your profile** (L). *What:* `/profile` is your
`/u/<handle>` page plus owner-only tabs **Saved** (favourites and your
collections, managed in place), **Sets** (what you own and what it
builds), **Insights** (today's designer numbers); **Edit profile** in a
dialog (avatar, banner, name, handle, bio, links, pins, what to show);
`/settings` with **Appearance** (theme), **Email**, **Privacy** (follows
shown, likes shown), **Claude**, **Sign out**, **Delete account** (the
same `.settings` rows as now); signed in without a profile, a two-field
start (name, handle). *Why:* D9; the owner called the old page "complete
garbage" and this one is still a stacked form. *Acceptance:* every
setting of today's page is reachable in Settings and works (account_flow,
people_flow, follows_flow, collection_flow pass); a name changed in Edit
shows on the profile without a reload; the account page is under 2,000 px
tall at 1280 with its first tab open; Delete still deletes everything,
proven by account_flow against a deployment.

### Phase 4: notifications, comments and the feed

**U7. Notifications** (M). *What:* Account in the header becomes your
avatar with today's count, opening the account menu (D10); its
Notifications opens `/notifications`: comments and replies on your
models, photos of builds of them, remixes of them, challenge results,
and likes as a number per model per day ("Wizard's Tower: 4 new
likes"), grouped by model, newest group first ([DC], [AN]); read as you
open them; Mark all read; the daily email choices unchanged. *Why:* D10.
*Acceptance:* a comment on your model shows in the avatar's count within
a page load and in the list with its picture; ten likes on one model
are one row; nothing says who followed you or names who liked. *Supabase:* `feed_rows` split by kind into
`notification_rows` and `follow_rows` (new functions), likes counted per
day from `model_likes`; `feed_marks` gains `notifications_seen_at`.

**U8. Comments that talk** (M). *What:* one level of replies, the newest
thread first and replies oldest first under it, the avatar and "Designer"
on the model's owner, the step a comment is on as a pill that opens the
viewer at that step, the box shown to everybody (signing in from it),
replies in Notifications. *Why:* conversation is the social act; flat
oldest-first lists bury the new. *Acceptance:* a reply shows under its
comment at 390 and 1280; hiding a comment hides its replies; the rules
(13+, limits, comments off, under-13 owners) unchanged and proven by
`comments_flow`. *Supabase:* `model_comments.parent` (nullable, additive)
and the comment functions' new versions.

**U9. A feed you look at** (M). *What:* `/feed` as cards: a new model (its
picture, name, designer), a new version (what changed), a build photo
(the photo), a challenge entry; signed out and when you follow nobody,
**Latest on Brickworks** (newest listed models and build photos) and
designers to follow (by Top builds of their models, D1-safe: profiles
shown in public only); the 60-word lede gone. *Why:* section 1; [NN-ES];
[AC]. *Acceptance:* at 390 every row with a picture shows it; the
signed-out page shows at least the newest models; following somebody from
the suggestions fills the feed on the next load.

### Phase 5: onboarding and the house

**U10. First steps and the house profile** (M). *What:* after a first
sign-in (and the age question), **Make your profile** (avatar, name,
handle), **What do you build?** (kinds as pills), then three designers and
six models to start with, all skippable; the house account's profile
(`/u/brickworks`: picture, bio saying these are made with the assistant,
pinned models) on the account that published the seven house models,
which then credits them to it; Hand-built / With the assistant marks
shown (D7). *Why:* D12; [AC]. *Acceptance:* a new account reaches a
filled feed in four taps or fewer; every live model links to a profile;
the label is on every assistant-made card. Needs nothing from the owner
but, if that account is theirs, a profile shown in the house's name: the
lead's call, made once.

### Phase 6: depth (after the first five, in this order)

| # | Unit | What | Size | Supabase |
|---|---|---|---|---|
| U11 | Collections first-class | A cover mosaic, Follow a collection (in the feed when it grows), "In N collections" on a model ([PR-C], [SK-P]) | M | `collection_follows` |
| U12 | Challenges that live between months | Past challenges and their winners, the next one's theme and date, entries as cards; a year of themes set once on /admin | M | `challenges` gains `announced_at` |
| U13 | Achievements | Earned marks on a profile: first model listed, first build finished, Tested, ten builds of your models, a challenge won ([PR-P], [MW-H]); names free of any LEGO® mark | M | none (computed) |
| U14 | Embed and share | A share sheet with the embed code; an embed that is the picture, name and Build it (exists) with the theme | S | none |
| U15 | Pictures that suit both themes | Renders at publish on a backdrop that sits in light and dark, and a 4:3 one (app code at publish, no interface change) | M | none |
| U16 | Hand-built said by the app | The app says at publish whether the assistant laid parts, so D7 is not left to tags (app code, no interface change) | S | `shared_models.made_with` |

What we will not build: messages between people, lists of followers,
"X followed you", view counts as a ranking, streaks, or anything that
shows a person's activity they did not choose to show (D1, D13).

### Sketches

Layouts, not looks: for the units to start from, in the site's own
components. Brackets are buttons, parentheses an avatar.

The card (U3), the same on every page:

    +---------------------------------+
    | [Tested] [Moves]                |   marks over the picture's corner
    |                                 |
    |        the picture, 4:3         |
    |                                 |
    +---------------------------------+
    | Wizard's Tower                  |   name, one line
    | (av) Robin Castell              |   avatar and name, a link to /u/
    | [heart 12]  built 4  comments 3 |   like from the card; zeros hidden
    +---------------------------------+

The gallery at 390 (U3): the header, then at once

    Gallery                      [search]
    [Top] [New] [Following]          This week v
    (All) (Castles) (Space) (Vehicles) (Town) ->      pills, scroll inside
    [Filters 2]                       Hand-built, Tested...
    +-----------+ +-----------+
    |   card    | |   card    |       two columns from 390 px
    +-----------+ +-----------+

The model page at 1280 (U4):

    Gallery > Castles and fantasy
    +--------------------------------+  Wizard's Tower
    |                                |  (av) Robin Castell        [Follow]
    |          the picture           |  (9,541 parts) (1,324 steps) (Tested)
    |                                |  [Build it]  [Open in Brickworks]
    +--------------------------------+  [heart 12] [Save] [Share] [3] [I built it] [...]
    [pic] [pic] [build photo] [build photo] ->     the column stays beside the
                                                   picture as the page scrolls
    About | Comments 3 | Builds 4 | Remixes 3 | Versions 2     tabs that stay on screen
    ...
    More by Robin Castell   [card] [card] [card] [card]
    Like this               [card] [card] [card] [card]

At 390 the same, one column: the picture, the name, the designer and
the action bar on the first screen, the tabs below.

The profile at 390 (U5):

    [ banner: one of their models' pictures ]
    (avatar)  Robin Castell
              @robin · building here since March 2026
    I design castles and small mechanisms, built to be built.
    robincastell.example · flickr.com/robin
    4 models · 77 builds of them · 3 followers · following 2
    [Follow] [Share]
    Pinned   [card] [card] ->
    Models 4 | Builds 1 | Collections 2 | About        tabs, scroll inside
    +-----------+ +-----------+
    |   card    | |   card    |
    +-----------+ +-----------+

### Rules every unit keeps

- "LEGO®" only as an adjective, the disclaimer in the footer, no LEGO
  Group pictures or logo, no mark in a feature's name
  (`docs/TRADEMARKS.md`, `tests/test_trademarks.py`).
- No new tracking (D13); the privacy page updated in the same commit as
  anything it should say (U1's theme, U4's and U5's pictures).
- Account deletion keeps working: every new table cascades from
  `auth.users`, every new stored file is deleted by name before the
  account, and `account_flow` proves it on a deployment.
- The trust rules: 13+ for every new public thing (an avatar, pins, a
  link, a reply), `may_act` limits on every new write, Report on every
  new thing people make, /admin can take each out.
- Text people typed goes on the page as text; links people typed are
  `rel="ugc nofollow"` and only `https:`.

## 6. For the lead

**The top ten, in order:** (1) the theme choice on a complete token set,
U1; (2) the component kit and one card, U2; (3) the gallery grid, tabs and
card actions, U3; (4) the model page's media, action bar and what comes
next, U4; (5) the public profile with avatar, tabs and pins, U5; (6) your
account as your profile, with Settings apart, U6; (7) notifications apart
from the feed, U7; (8) comments with replies, U8; (9) a visual feed with
Latest for everybody, U9; (10) first steps and the house profile, U10.

**The first three units:**

- **U1, Tokens and theme.** Bar: System, Light and Dark chosen in the
  footer, Menu and Settings on all 19 kinds of page at 390 and 1280; no
  flash (first-paint background is the chosen theme on every page); kept
  across reload, tab and, signed in, a new browser; every text token at
  4.5:1 or more and a pressed edge 3:1 or more in both themes, by
  script (the yellow edge is 1.33:1 in light today); `theme-color` follows;
  `design_flow` passes; account deletion removes the choice.
- **U2, Component kit and one card.** Bar: one card renderer (server and
  browser markup equal by test), one pill, avatar, tabs, icon buttons;
  `design_flow` fails on an off-scale size, radius or colour and on a
  shown zero, and passes; before-and-after shots of every page show no
  regression.
- **U3, The gallery.** Bar: at 390 x 844 the first card's picture within
  330 px of the top, 2 columns; at 1280 x 900 four whole cards on the
  first screen; Top · New · Following tabs with time windows; kinds as
  pills; Hand-built / With the assistant filter; like from a card; Back
  returns to the same card; endless to three pages then Show more; light
  and dark.

## Sources

Read 2026-10-22. Where a site refused automated reading, the claim is
from its captured page text in search results or a guide, as noted.

- [AC] Andrew Chen, *The Cold Start Problem*, as summarised:
  https://www.antoinebuteau.com/lessons-from-andrew-chen/
- [AN] Android, "Create a group of notifications":
  https://developer.android.com/training/notify-user/group
- [BE] Creative Bloq on Behance's 2019 project page:
  https://www.creativebloq.com/news/behance-reveals-all-new-look-for-2019 ;
  https://www.abduzeedo.com/new-year-new-behance-profile-and-project-page
- [BL] BrickLink Studio help, sharing to the Studio Gallery:
  https://studiohelp.bricklink.com/hc/en-us/articles/360042355033
- [DC] Discourse Meta, grouped like notifications:
  https://meta.discourse.org/t/grouped-liked-notifications-should-sort-by-the-most-recent-like/116489
- [DR] Dribbble, "New & improved Shot pages" (2020):
  https://dribbble.com/stories/2020/10/14/new-improved-shot-pages
- [DR-P] A Dribbble profile (tabs Work, Collections, Liked Shots, About;
  Follow), captured text: https://dribbble.com/sethshaw/shots
- [GH] GitHub Docs, "Managing your theme settings":
  https://docs.github.com/en/get-started/accessibility/managing-your-theme-settings
- [IG] Buffer on Instagram's taller grid (2025):
  https://buffer.com/resources/instagram-grid/
- [IG-M] Social Samosa, Mosseri on why:
  https://www.socialsamosa.com/news-2/instagram-updates-profile-grid-vertical-thumbnail-display-8636556
- [MB] Mecabricks' front page (model cards, creators linked):
  https://www.mecabricks.com/
- [MB-E] Eurobricks, Mecabricks thread (view in 3D, inventory, edit):
  https://www.eurobricks.com/forum/forums/topic/69050-software-mecabricks-online-design-tool/page/4
- [MW-F] MakerWorld FAQ (print profiles by class and rating), captured
  text: https://makerworld.com/en/faq
- [MW-H] Bambu Lab forum, "The new 'Home' for profiles":
  https://forum.bambulab.com/t/the-new-home-for-profiles/137466
- [NN-ES] NN/g, "Designing Empty States in Complex Applications: 3
  Guidelines": https://www.nngroup.com/articles/empty-state-interface-design/
- [NN-IS] NN/g, "Infinite Scrolling: When to Use It, When to Avoid It":
  https://www.nngroup.com/articles/infinite-scrolling-tips/
- [PR-C] A Printables model's Collections tab (public and private counts),
  captured text: https://www.printables.com/model/133615-simple-love-heart/collections
- [PR-M] A Printables model page (Like, Download, counts, Makes &
  Comments, Remixes, Model origin), captured text:
  https://www.printables.com/model/1214729-talking-benchy
- [PR-P] A Printables profile (Lvl, About, 3D Models, Makes, Activity,
  Collections with counts), captured text: https://www.printables.com/@lowboydrvr
- [RB] BrickNerd, "Mastering Rebrickable":
  https://bricknerd.com/home/mastering-rebrickable-a-guide-to-sharing-mocs-and-instructions-1-10-25 ;
  AlternativeTo: https://alternativeto.net/software/rebrickable/about
- [RB-G] Rebrickable's glossary, "Build": "A calculation tool to see if
  you can build a specific set/MOC based on your available parts"
  (rebrickable.com/help/glossary; not fetched, the project reads
  Rebrickable at most once a day)
- [SK-E] Sketchfab help, embedding: https://help.sketchfab.com/en/articles/16152735
- [SK-P] Sketchfab, Popular 3D models (Human Created, AI Generated, This
  week, Most liked, author avatar, load more):
  https://sketchfab.com/3d-models/popular
- [SK-S] Sketchfab help, Staff Picks: https://help.sketchfab.com/en/articles/16151953
- [TV] JMU Libraries, "How to use Thingiverse":
  https://sites.lib.jmu.edu/adrihooker/how-to-use-thingiverse
- [TV-R] "Towards Laws of the 3D-printable Design Web" (WebSci 2014):
  https://www.cs.ucr.edu/~epapalex/papers/websci14-3dprinting.pdf
- [W3C-M] CSS WG masonry explainer:
  https://github.com/w3c/csswg-drafts/blob/master/css-grid-2/MASONRY-EXPLAINER.md
- [WD] web.dev, "prefers-color-scheme: Hello darkness, my old friend":
  https://web.dev/articles/prefers-color-scheme
