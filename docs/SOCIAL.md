# brickworks.diy as a social site: research and plan

The CAD and the community as one loop, graded step by step, with the units that join them: [MASTERPLAN.md](MASTERPLAN.md) (2026-11-23).

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

## The scorecard (kept current: each research round updates it)

**Round 8, 2026-11-20 (unit siteplan8).** The owner asked on 11-20: "Are you
still effectively building to reach our goals of having the absolute best app
(and site) of this type?" This section is the site's half of the answer. The
studio has its own (docs/APP_UX11.md). The next round replaces this section's
numbers and keeps its shape.

**The count: 49 ahead, 36 level, 27 behind**, over 112 judged cells (14 rows
against 8 columns, plus the row of people and activity, which is behind every
column; 8 cells not judged: where a site could not be read or timed). The
three worst:

1. **People and activity.** All 49 models in the gallery are the house's own
   (`/api/share?op=list`, 3 pages, every one `by: brickworks`). The gallery has
   never had a like (`model_likes`: 0 rows). This month's challenge, Microscale,
   has 0 entries with 10 days to go. 9 real accounts were made in the last 30
   days, and none of them has shared a model. Every other site in the table has
   people's work on its first screen: Flickr's LEGO® pool alone holds 650,054
   photos.
2. **Challenges and contests.** Ours is the most complete contest page of the
   LEGO® sites, but it has no prizes, no judges and no entries. Printables ran
   38 contests so far in 2026, with a median of 218 entries. LEGO® Ideas and
   BrickLink run judged rounds, then a fan vote, with prizes and a path to a
   product.
3. **Showing work.** A model can be shared only from inside the studio. Work
   made elsewhere has to be opened in the studio first, and the challenge's
   Enter tells a newcomer just that ([picture](img/social8/challenge-enter-390.webp)).
   Rebrickable, Printables and MakerWorld take files on the web page, with
   many pictures and drafts.

What we lead on: the model page (steps, versions, parts with three shops'
exports, Tested, remixes and builds, embedded in 3D), comments (replies,
@mentions, step comments), the feed, a model shared outside (link previews,
oEmbed and structured data on every model), a silent block, and speed: of the
sites that let a browser time them beside ours, every one drew its first screen
later. None of the LEGO® sites matches them.

### The table

**A** ahead, **L** level, **B** behind, **–** not judged (the site could not be
read, or the measurement did not run). Each cell is Brickworks against that site on that row. The evidence for
every cell is in the list under the table.

| Row | brickworks.diy today | RB | BL | MB | BS | FL | LI | PR/TV | Best elsewhere |
|---|---|---|---|---|---|---|---|---|---|
| 1. Showing work | published from the studio: picture, file, steps, parts, versions, Tested, based-on, extra pictures | L | L | A | A | A | A | **B** | **B** MakerWorld |
| 2. Finding work | Top (time windows), New, Following, Builds, Collections; search; filters by time, size and how it was made; shelves; More like | L | L | L | L | A | L | L | **B** MakerWorld, Sketchfab |
| 3. The model page | 3D, Build it, Download, one action bar, 6 tabs, parts exports, More by, Like this | A | A | A | L | A | A | L | L Sketchfab |
| 4. The profile | banner, avatar, links, numbers, pins, tabs, achievements with levels, More like | L | A | A | A | L | A | L | L Printables |
| 5. The feed | cards from people you follow; Latest when signed out; people to follow | A | A | A | A | L | A | L | L Printables |
| 6. Notifications | the avatar's count, grouped by model, 11 kinds, a daily email by choice | L | A | A | A | **B** | L | L | **B** GitHub |
| 7. Comments | replies, @mentions, comments on steps, hide, off, report | A | A | A | A | A | A | L | **B** MakerWorld |
| 8. Challenges and contests | monthly; rules checked; two groups; blind vote; notices; past winners | L | **B** | A | L | A | **B** | **B** | **B** MakerWorld |
| 9. Sets, parts and lists | Own/Want on 1,576 set pages; lists; You can build now; BrickLink, Rebrickable and Pick a Brick exports | **B** | L | A | **B** | A | A | A | L Ravelry |
| 10. First visit and sign-up | the studio's pitch and a call to test the beta first; the first model 2.8 phone screens down; email code or orangecheck; age; First steps | – | L | L | A | L | L | **B** | **B** MakerWorld |
| 11. Shared outside | og and twitter cards, oEmbed (3D), JSON-LD on models and sets, sitemaps | – | A | A | A | L | – | A | **B** Sketchfab |
| 12. Phones | no page scrolls sideways (112 visits at 390, 768, 1280 and as an iPhone); the studio itself on a phone; no app, no push | L | A | A | L | **B** | – | **B** | **B** MakerWorld |
| 13. Safety and moderation | 13+, report everywhere, hide, comments off, silent block, owner's console | A | L | A | A | L | L | A | **B** Instagram |
| 14. Speed | largest picture 0.6-1.0 s at 1280, 1.6-3.0 s on a slow phone; answers in 0.14 s warm | – | – | – | A | A | A | – | A Sketchfab |
| 15. People and activity | 49 models, all the house's; 0 likes; 0 entries | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** |

RB Rebrickable (MOCs) · BL BrickLink's and Studio's gallery · MB Mecabricks ·
BS Brickset · FL Flickr's LEGO® groups · LI LEGO® Ideas · PR/TV Printables and
Thingiverse · Best elsewhere: the site named.

### The evidence, row by row

Facts about other sites are from round 8's reading on 2026-11-20 ([R8-…] in
Sources). Where a site blocked reading, the claim rests on a search excerpt,
marked *(excerpt)*. Rebrickable was not fetched at all: the project reads it at
most once a day, so its cells rest on guides and excerpts. BrickLink was offline
the whole day ("temporarily unavailable … while we investigate unusual
activity"), so its cells rest on Studio's help pages and an archived page.

1. **Showing work.** Ours: Share in the studio publishes the render, a cut-out,
   a 4:3 card picture, the .mpd, its steps and parts list, versions with what
   changed, Tested, made-with and based-on. The designer can then Add a picture
   on the model's page. Rebrickable takes up to 12 images, instructions from
   any tool (PDFs, paid ones too) and a parts list in five steps on its site
   [R8-RB]. Level: more media there, more done for you here. Studio's gallery
   offers Private, Display or Full Access [R8-BL], level. Mecabricks publishes
   from its workshop with a Renderings tab [R8-MB]; Brickset, Flickr and Ideas
   take no model file. Behind Printables and MakerWorld: files of any kind
   uploaded on the web page, many pictures, drafts, and MakerWorld's print
   profiles [R8-PR], [R8-MW]. Our studio is the only way in, and there are no
   drafts.
2. **Finding work.** Ours has tabs, time windows, filters (including Hand-built
   and With the assistant), This week's pick, You can build now and More like.
   Level with Rebrickable's theme and Build searches [R8-RB], Mecabricks'
   Library and Selection [R8-MB], Ideas' Staff Picks and Trending [R8-LI], and
   Printables' search operators [R8-PR]. Ahead of a Flickr pool, which is a
   stream by date. Behind MakerWorld's For You (78 of its home cards are
   recommendations) and Sketchfab's daily Staff Picks [R8-MW], [R8-SK].
3. **The model page.** No LEGO® site has steps in the browser, versions, Tested
   and three shops' part exports on one page. Mecabricks comes closest: 3D,
   inventory as CSV or BrickLink XML, embed and Suggested [R8-MB]. Brickset is
   level on its own ground: a set page with 16 tabs, ratings and reviews
   [R8-BS]. Printables is level with makes, ratings, collections and remix
   parents [R8-PR]. Sketchfab is level: the 3D viewer is its page [R8-SK].
4. **The profile.** Level with Rebrickable's custom profile and Workbench blog
   [R8-RB], Flickr's photostream, and Printables' tabs, chosen badges, levels
   and analytics tab [R8-PR]. Ahead of Studio's gallery, Mecabricks (no
   Follow), Brickset and Ideas.
5. **The feed.** Only Flickr and Printables have one [R8-FL], [R8-PR].
   Printables folds likes of one item within 3 hours into one entry and shows a
   collection only once it holds 4 models: level, since ours folds by model.
6. **Notifications.** Ahead of the sites with none: Studio's gallery,
   Mecabricks, Brickset. Level with Rebrickable's per-designer opt-in, Ideas'
   bell and Printables' list. Behind Flickr: its own app pushes, and each kind
   can be set for the site and for email [R8-FL]. Behind GitHub's inbox: Done
   and Saved, per-thread watching, push on a phone [R8-GH]. We have no push,
   and the choice by kind is for email only, not for what shows here.
7. **Comments.** Replies, @mentions and comments on a step are ours alone among
   the LEGO® sites. Brickset has Report and "hide this member's comments", no
   threads [R8-BS]; Ideas has @-tags [R8-LI]. Printables is level, with
   replies, comment likes and star ratings [R8-PR]. Behind MakerWorld: a
   designer pins a comment or a picture, and makers rate after printing
   [R8-MW].
8. **Challenges and contests.** Rebrickable runs a quarterly competition,
   entered by a tag on the MOC [RB-C]: level. Mecabricks and Flickr's pool run
   none. Brickset ran its first in five years this month, with three prizes:
   level. Behind Studio's Activities and Designer Program, judged, with prizes
   and a fan vote [R8-BL]; behind Ideas: judges shortlist 5, then one fan vote,
   prizes, past winners kept [R8-LI]. Behind Printables: 38 contests so far in
   2026, a median of 218 entries, the largest 1,108 (its API, read today), a
   monthly Designer Challenge themed by its Designer of the Month [R8-PR].
   Behind MakerWorld: contests with countdowns and prizes on its home page
   [R8-MW]. Our Microscale has 0 entries.
9. **Sets, parts and lists.** Behind Rebrickable: it keeps loose parts as well
   as sets, and its Build search ranks every MOC by what you own [R8-RB].
   Behind Brickset: owned and wanted with flags (Trade, MISB), notes, a CSV
   export and a sync with Rebrickable [R8-BS]. Level with Studio's wanted list
   and Easy Buy [R8-BL], which our BrickLink export feeds. Ahead of Mecabricks'
   export alone, and of the sites with no sets. Level with Ravelry, which
   matches a stash to a queue [R8-RV], as our You can build now matches owned
   sets to models.
10. **First visit and sign-up.** A stranger's first screen, in the home page's
    own order: the studio's pitch ("A CAD for LEGO® models, in your browser"),
    then "Help shape Brickworks", a call to test the beta, and only then "Made
    in Brickworks", the house's models. Measured, the first model sits 2,380 px
    down on a 390 x 844 phone (2.8 screens) and 2,318 px down at 1280 x 900
    (2.6 screens) ([picture](img/social8/home-390.webp)). On Printables,
    MakerWorld and a Flickr pool, people's work is the first screen. Signing up
    took 3 taps and 18 s from the header's Sign in to signed in on a phone (the
    code read from a test inbox, so the wait for mail is extra), then the age
    question and First steps' three screens: 11 taps to the feed. Sign-up is an
    emailed code or orangecheck, with no password. Mecabricks shows 6 models
    and 6 renders on its home page, but asks for a password and shows a
    stranger an ad: level. Brickset opens on its news, asks for a password and
    shows ads: ahead [R8-MB], [R8-BS]. Studio's gallery and Ideas use a LEGO®
    Account (Ideas from 16) [R8-BL], [R8-LI]. Behind Printables and MakerWorld,
    which offer Google and Apple as well as email [R8-PR], [R8-MW].
11. **Shared outside.** Every /m/ page has og and twitter tags with its own
    1200 x 630 picture, an oEmbed discovery link whose answer is the 3D embed,
    and JSON-LD (`CreativeWork` with like and view counts). Set pages have the
    tags and the JSON-LD, not oEmbed. 49 models and 1,576 set pages are in the
    sitemaps (read today). Studio's archived page had no og tags [R8-BL].
    Mecabricks has og:image only [R8-MB]. Brickset has og and twitter but no
    JSON-LD [R8-BS]. Printables has og, twitter and `Product` JSON-LD but no
    oEmbed [R8-PR]. Flickr is level: og, twitter, oEmbed and JSON-LD [R8-FL].
    Behind Sketchfab, whose og:video and twitter `player` card play the model
    inside X, Discord and Slack [R8-SK]. Ours are still pictures. Gaps of our
    own: /u/ has no JSON-LD, and /gallery and /challenge show the site's
    generic picture (each challenge's own `?id=` link has its own).
12. **Phones.** 112 visits to 14 pages, at 390 x 844 and 768 x 1024 in
    Chromium, at 1280 x 900, and as an iPhone 13 in WebKit, light and dark:
    none scrolls sideways and none threw a script error. One page moves as it
    loads: the challenge page (layout shift 0.19 at 390, 0.12 at 768, where
    Google counts over 0.1 as needing work); every other page is at 0.05 or
    under. The studio itself runs on a phone (docs/PHONE.md: first visit 10.5 s
    on Chromium, 12-21 s on WebKit). Studio is desktop-only and Mecabricks has
    no viewport tag [R8-BL], [R8-MB]: ahead. Brickset is responsive, with apps
    by others: level. Behind Flickr's apps, the Prusa app's Printables browser,
    and Bambu Handy [R8-FL], [R8-PR], [R8-MW]. Our site has a manifest but no
    service worker, so it cannot be installed with an offline page and cannot
    push.
13. **Safety and moderation.** Ahead of Printables (Report only; no block, its
    admin said in 2025) [R8-PR], Mecabricks (no report or block), Brickset and
    Rebrickable. Level with Flickr's silent block [R8-FL], Studio's review and
    reporting [R8-BL], and Ideas' moderators (16+) [R8-LI]. Behind Instagram's
    Restrict, Hidden Words and blocking a person's next accounts too [R8-IG].
14. **Speed.** Timed in one browser at the same moments as the others
    (`survey.mjs --pass=speed`, median of 2 rounds; a phone on slow 4G at a
    quarter of the CPU, then 1280 as it is). The largest picture drawn, phone /
    1280: Brickworks' home 1.6 / 0.8 s, gallery 3.0 / 1.0 s, a model 2.9 / 0.6
    s; LEGO® Ideas 4.6 / 2.3 s; Sketchfab 16.7 / 1.3 s; Brickset 15.1 / 7.5 s;
    Flickr's LEGO® pool 17.3 / 4.9 s. Printables, MakerWorld and Thingiverse
    showed the timing browser a Cloudflare check (403) and Mecabricks drew
    nothing in time, so they are not judged; Rebrickable is read once a day and
    was not, and Studio's gallery was not timed. Chrome's field verdicts for
    the others: Printables, MakerWorld, Sketchfab and Brickset fail Core Web
    Vitals and Thingiverse passes [R8-SP]. Ours, from the few loads people
    timed (under what people do): LCP p75 1.09 s in Edge, p50 4.24 s in Chrome.
15. **People and activity.** Section "What people do on it" below.

### Where the plan stands (2026-11-20)

From `git log` on main (rel-m316, 7f25aa4bf, live since 07:38Z today) and the
live pages. **Live** means on brickworks.diy now; **partly** means live with a
named piece missing; **not built** means nothing of it is on main.

| Section | Unit | State | Evidence |
|---|---|---|---|
| 5 | U1 Tokens and the theme choice | live | `web/theme.js` on every page; System, Light, Dark in the footer and Settings › Appearance |
| 5 | U2 The component kit and one card | live | `web/card.js` and `api/_card.js`, one renderer |
| 5 | U3 The gallery | live | Top · New · Following · Builds · Collections, pills, filters, Show more |
| 5 | U4 The model page | live | action bar, tabs About · Comments · Builds · Remixes · Collections · Parts, More by, Add a picture |
| 5 | U5 The public profile | live | `/u/brickworks`: banner, pins, tabs, `supabase/avatars.sql` |
| 5 | U6 Your account as your profile | live | `/profile` and `/settings` apart |
| 5 | U7 Notifications | live | `/notifications`, `supabase/notifications.sql` |
| 5 | U8 Comments that talk | live | `supabase/replies.sql` |
| 5 | U9 A feed you look at | live | `/feed` as cards, Latest when signed out |
| 5 | U10 First steps and the house profile | live | `web/first-steps.js`, `supabase/house.sql` |
| 5 | U11 Collections first-class | partly | live (`supabase/collection_follows.sql`); its rename to Lists is lists2's item 2, not built |
| 5 | U12 Challenges between months | live | Coming next and Past challenges; the page redone 11-13 (challengepage) |
| 5 | U13 Achievements | live | levels since phase 7 #2 (`supabase/achievements.sql`) |
| 5 | U14 Embed and share | live | the share sheet on every page with Share (3e8f53cf2) |
| 5 | U15 Pictures for both themes | live | `/m/X.cutout.png` and the 4:3 WebP at publish |
| 5 | U16 Hand-built said by the app | live, changed | `made_with` kept; since 11-02 (the owner) said on the model's page only, not on cards |
| 7 | 1 Share everywhere | live | sheet with networks; `/oembed` answers `rich` with the 3D embed (read today) |
| 7 | 2 Achievements with levels | live | six tracks, the next level on your own page |
| 7 | 3 Challenges people hear of | live | `supabase/challenge_notices.sql`; `/challenge?id=N` has its own preview |
| 7 | 4 The embed in 3D | live | `/m/X/embed` answers 200, 4 KB (read today) |
| 7 | 5 Based on | live | `supabase/model_bases.sql` |
| 7 | 6 @mentions | live | `supabase/comment_mentions.sql`; @ searches shown profiles since socialtails |
| 7 | 7 The week by email | not built | ranked low in phase 7; still low: nothing happens yet |
| 7 | 8 Builds as a gallery tab | live | `/builds` |
| 7 | 9 People to follow on a profile | live | More like, `supabase/designers_alike.sql` |
| 8 | lists1 (Own, Want, lists, Save, the profile's Sets) | live | rel-m299, `supabase/lists.sql` |
| 8 | lists2 items 1-9 (docs/LISTS.md section 5) | not built | no commit since lists1 names any of them |
| 9 | Blocking a person | live | rel-m316 today, `supabase/block.sql`, Settings › Blocked people |
| – | Owner's console at /admin | live | console1-3, Analytics since rel-m314 |
| – | Sign in with orangecheck | live | rel-m305 (signinux), beside the emailed code |

Of 30 units: 27 live, 1 partly, 2 not built (the week by email; lists2). The
plan of sections 5 and 7 is done. What is left is not more of the same: the
site has the parts of a community and no community (below).

### The site measured by hand (2026-11-20)

**What was set up.** Live brickworks.diy, signed out, in Chromium on
SwiftShader at 390 x 844 (a phone: touch, twice the pixels), 768 x 1024 and
1280 x 900, and in WebKit as an iPhone 13, each in light and dark, 14 pages,
through `heavy` (`survey.mjs`); the first visit timed beside eight other sites'
at the same moment, a phone on slow 4G at a quarter of the CPU and 1280 as it
is (`survey.mjs --pass=speed`); and signed in, a newcomer's whole way through
between two throwaway accounts of this round's own, deleted at the end
(`journey.mjs`: sign up in the header's dialog on a phone, First steps, like,
follow, comment, save, own a set, a list, the challenge's Enter, the feed, a
notification, block, delete the account). Resend test addresses, so their
models never reach a public list; nobody else's model or profile touched; the
site's visit counter stopped for these browsers. The scripts and everything
they write are in `bench/results/siteplan8-2026-11-20/` (git-ignored).

**What the browsers saw.** The runs started at 15:00Z, once the release train's
timing checks let them, with the box under other work: the same for every site
timed beside ours, but each number is a lab number, not a person's.

- **The survey** (112 visits, 14 pages, every one answered 200): no page
  scrolls sideways, no page threw a script error, and only the challenge page
  shifts as it loads (0.19 at 390). The gallery's first card is 322 px down on
  a phone; the home page's first model is 2,380 px down, 2.8 screens
  ([picture](img/social8/home-390.webp)). The challenge has nothing to show:
  "No entries yet: be the first", on day 20 of 30
  ([picture](img/social8/challenge-390.webp)). Builds, collections and lists
  are a heading and a "nothing yet" to a stranger.
- **The first visit beside the others** (largest picture drawn, median of 2
  rounds, a slow phone / 1280): Brickworks' home 1.6 / 0.8 s, gallery 3.0 / 1.0
  s, a model 2.9 / 0.6 s; LEGO® Ideas 4.6 / 2.3 s; Sketchfab 16.7 / 1.3 s;
  Brickset 15.1 / 7.5 s; Flickr's LEGO® pool 17.3 / 4.9 s. Printables,
  MakerWorld and Thingiverse showed the timing browser a Cloudflare check, and
  Mecabricks drew nothing: none of the four is judged.
- **The journey** between two throwaway accounts (31 steps, the newcomer on a
  390 phone, the designer at 1280): sign-up in 3 taps and 18 s, then 11 taps to
  the feed through the age question and First steps. On a model page, Like and
  Follow are in the first screen (692 and 532 px down) and the comment box
  1,820 px down. A comment with an @mention reached the designer as New, with 3
  on the header's bell, within the minute, and the followed designer's model
  led the newcomer's feed. The challenge's Enter told the newcomer to build in
  the app first ([picture](img/social8/challenge-enter-390.webp)). Two steps
  failed by the script's fault, not the site's: it pressed Own on a set's 3D
  model page instead of its set page, and Block and Delete my account ask with
  the browser's own confirm box, which a test browser declines unless told, so
  neither happened. The site's own checks cover both (`block_flow`,
  `account_flow`). Both accounts and their model were deleted at the end, and
  their pages answer 404.

**The server's answer** (curl, three tries each, 14:25Z): every page answers
in 0.14-0.16 s once warm. The first try at a model's page took 1.49 s and at a
profile 1.86 s: a cold function. The field numbers (under what people do on
it, below) say the same: Chrome on a desktop waited 3.56 s for the first byte
(p50, 2 loads). Mecabricks' selection answered in 0.89-1.07 s and Brickset's
year page in 0.37-0.64 s. Printables, MakerWorld and Thingiverse refused a
reader that is not a browser (403).

**The first screen, from the pages themselves.** The home page's sections run:
the studio's pitch ("A CAD for LEGO® models, in your browser"), "Help shape
Brickworks" (a call to test the beta), "Made in Brickworks" (the house's
models, loaded late), "Everything a build needs", "Share it, and build with
others", "Build something today". A stranger meets the tool and the beta
before any model, and every model they then meet is the house's.

### What people do on it (2026-11-20)

**How it was read.** /admin › Analytics' own read, `GET /api/admin?op=analytics`,
through `api/admin.js` run locally (`tools/web/relay_server.mjs` on port
10840) against the live database. The relay's `MASTER_EMAIL` was the checks'
shared test account, as docs/ADMIN_CLAUDE.md's local run has it, so the owner
was never signed in. The relay had no `VIEW_SECRET` (it is kept only in
Vercel), so the read could not join visits to accounts: its sign-ups and
retention read 0 and are not used here. Account numbers are from the auth
admin list instead, as counts only (`people_counts.mjs` in the results). Read
only; nothing was written.

**The numbers.**

- **Counted visits: 6 since the counter went live** with rel-m314 (11-19,
  11:24Z): 1 on 11-19 and 5 on 11-20. Sources: 4 direct, 2 from Bing. Few
  visits are counted: anyone sending Do Not Track or GPC is left out, anyone in
  the EU, UK or Switzerland only after saying yes, and a robot never.
  Overlook counts the audience, but its API has no read of analytics
  (docs/ANALYTICS.md).
- **The visit funnel:** 6 visits, 2 opened the studio, 1 put down a part, 0
  saved, 0 published.
- **Where visits stopped** (each visit's last act): a set's page (2), the
  studio's view button (1), the Select tool (1), the home page (1),
  /profile (1).
- **Speed as people had it** (1 visit in 4 is timed, so few): 4 loads in Edge
  on a desktop, LCP p50 0.87 s and p75 1.09 s, TTFB p50 0.11 s; 2 loads in
  Chrome on a desktop, LCP p50 4.24 s with TTFB p50 3.56 s, the time going
  before the first byte. The studio's catalogue took 47 s (p50, 2 loads) in
  Edge.
- **Accounts** (the auth list, counts only): 160 in all; 141 are the checks'
  (Resend test addresses); **19 are real**. 9 of those were made in the last
  30 days and 5 in the last 7, all by the emailed code. 3 of them have a
  public profile, the house's among them.
- **Made and shared:** of 410 rows in `shared_models`, 49 are by real
  accounts, and all 49 are the house's. **No person outside the house has
  ever shared a model.** `model_likes`, `build_photos` and `collections`
  have 0 rows; `model_builds` has 1.

**Where people drop off.** At the first save and the first share. People
come (9 new accounts this month, 5 this week) and look at sets and the studio.
The one visit that put down a part saved nothing. None of the 18 real accounts
other than the house's has shared a model, liked one or posted a build photo,
and this month's challenge has no entry. Nothing in the site's own funnel is
broken: there is no second person to meet. That is why the next plan opens
with ways in for work people have already made (bringyours), and with every
share outside working as an advertisement (turntable), before anything that
needs a crowd.

### The behinds, ranked

Ranked by what each would change for a builder, given the finding above: the
site has the parts of a community and one designer. A behind that brings people
and their work in outranks one that serves a crowd we do not have yet.

1. **People and activity** (row 15, behind all 8). Not a feature to copy: the
   cure is ways in. Work people already made, shared from the site in a minute
   (bringyours), and every share outside working as an advertisement
   (turntable).
2. **Showing work** (row 1: Printables, MakerWorld). A model can be shared only
   from inside the studio. bringyours.
3. **Challenges and contests** (row 8: Studio, Ideas, Printables, MakerWorld).
   No judges, no honours, nothing on the home page while one runs.
   challengehonours.
4. **Phones** (row 12: Flickr, Printables, MakerWorld). No install, no
   offline page, no push. homescreen.
5. **Notifications** (row 6: Flickr, GitHub). No push, and kinds can be
   chosen for email only. homescreen, then inbox.
6. **First visit and sign-up** (row 10: Printables, MakerWorld). No Google
   or Apple: signin-google (Apple needs a paid developer account, so it is
   parked with payments). The home page shows the tool and a call to test the
   beta before any model (the first is 2.8 phone screens down): challengehonours brings the open challenge and This
   week's pick into its first two screens.
7. **Sets, parts and lists** (row 9: Rebrickable, Brickset). No quantities,
   no "what am I missing", no flags or notes. ownedparts, then lists2a.
8. **Shared outside** (row 11: Sketchfab). Our previews are still pictures.
   turntable.
9. **Finding work** (row 2: MakerWorld's For You, Sketchfab's daily picks).
   Not planned: recommendations over 49 models from one designer would
   recommend the same designer. Revisit at 500 models from 50 designers.
10. **Comments** (row 7: MakerWorld's pins and ratings). commentcare.
11. **Safety** (row 13: Instagram's Hidden Words and Restrict). commentcare.

### What no such site has, that builders would value most

Each is a lead no LEGO® site has, built on what only Brickworks has: the
model as data (parts, steps, joints), not as pictures.

- **A model that turns in the link preview.** Paste a model into Discord, X
  or Slack and it turns, its steps a click away. Among all the sites
  read, only Sketchfab does this, and Sketchfab is not a LEGO® site (unit
  turntable).
- **Share a model you made anywhere, with its parts, steps and pictures worked
  out for you.** Rebrickable asks for each by hand, in five steps. Studio's
  gallery takes only Studio's files (unit bringyours).
- **What you are missing, and one click to buy only that.** Rebrickable tells
  you what share of a MOC you own. Nobody turns the gap into a BrickLink wanted
  list or a Pick a Brick list of just the missing parts (unit ownedparts).
- **A designer's numbers against last month.** Printables has this; no LEGO®
  site does (unit insights2).

### The units, in waves

Sizes as section 5: **S** under half a unit, **M** one (about three hours),
**L** two. **Review**: the unit touches accounts, user data or the database,
so it gets one independent review before it merges, and its SQL is additive
only (new tables, columns, functions; nothing dropped or rewritten). Every
unit follows section 3 and docs/DESIGN_SYSTEM.md: the shared components only,
standard controls (dates as dropdowns, choices as selects or radios, toggles as
checkboxes), and the web's standard layouts (account at the far right, the
primary action beside it, search at the left). Each is looked at 390, 768 and
1280 px in light and dark, wired into `tools/release/preview_checks.sh`, and
recorded in `.claude/skills/verify/`.

**No two units in a wave share a file** beyond the registries
(`tools/release/preview_checks.sh`, `.claude/skills/verify/`,
`api/_insights_names.js`, `tools/site_shell.py`, the docs index). The files
column is each unit's own.

| Rank | Unit | Wave | Size | Risk | Review | Waits on | Its files | Bar (measured) |
|---|---|---|---|---|---|---|---|---|
| 1 | **bringyours**: share a model you already made, from the site | 1 | L | M | yes (publishes people's files) | nothing | new `web/share-model.html`, new `web/share-model.js`, new `web/studio-io.js` (reads a Studio .io in the browser), `web/gallery.html` (Share yours). It posts to `/api/share` as it stands and draws its picture with `web/viewer3d.js` unchanged. | An LDraw .mpd or a Studio .io of 300 parts goes from the file chosen to a live /m/ page in 60 s or less at 1280 and 120 s or less at 390 (this box, SwiftShader), in 4 taps or fewer after choosing. Its parts list is the server's own count of the file, as for a studio share; its steps are the file's. An LDD .lxf is opened in the studio instead, with one tap. A file that is not a model is refused in words. 13+ and `may_publish` as today. |
| 2 | **turntable**: the model turns in link previews | 1 | L | H | yes (a new stored file per model, deleted with the account and on unpublish) | nothing | `api/share.js` (head tags, the clip's upload and route), `web/embed.js` (`?autoplay=1`), new `web/turntable-clip.js`, `web/model-page.js` (the designer's own visit records the clip once, from the 3D view, so studio, desktop and site shares all get one) | A model has `/m/X.mp4` (WebM where the browser cannot record MP4) within one visit of its designer: 4 s or less, a seamless loop, at most 1.5 MB. `/m/X` then carries `og:video` (type, width, height, secure_url) and a `twitter:card` `player` whose `twitter:player` is its embed. Fetched as Discordbot, Slackbot and Twitterbot, the page answers with those tags and the clip with 200. The embed plays muted with `?autoplay=1`. A model with no clip keeps today's picture card. `account_flow` proves that deleting the account deletes the clips; `share_probe` passes. |
| 3 | **challengehonours**: judges, a fan vote, honours, and the challenge on the home page | 1 | M | L | yes (`supabase/challenge_rounds.sql`) | nothing | `web/challenge.js`, `web/challenge.html`, `api/_challenges.js`, `web/admin-challenges.js`, `api/_console_challenges.js`, `web/index.html`, new `supabase/challenge_rounds.sql` | A challenge can run as a shortlist of up to 5, chosen on /admin by the owner or a guest judge named on the page, then a one-vote fan round, each with its countdown. Winners are This week's pick the week after and carry an honour on their profile. While a challenge is open, the home page shows it, with its days left, and This week's pick within its first two screens at 390 and 1280. The challenge page moves no more than 0.1 as it loads (layout shift, now 0.19 at 390). `/challenge` has the open challenge's own preview picture. `challenges_flow` passes; the blind vote and the rules are unchanged. |
| 9 | **seo2**: people and lists in search results | 1 | S | L | no | nothing | `api/people.js` (the profile's head), `api/collection.js` | Every /u/ page carries `ProfilePage` JSON-LD whose `mainEntity` is a `Person` (name, url, image, followers and models as `interactionStatistic`). Every public /c/ page carries `CollectionPage` with `hasPart`. Both parse as schema.org. No visible change (`design_flow`'s pictures the same). |
| 4 | **homescreen**: install the site, and push | 2 | L | M | yes (`supabase/push.sql`: subscriptions, deleted with the account) | nothing (the unit makes its own VAPID keys) | new `web/sw.js`, new `web/push.js`, new `api/_push.js`, new `supabase/push.sql` (a webhook on new notification rows), `web/site.webmanifest`, `web/settings.html`, `web/settings.js` | Chromium finds the site installable (manifest, service worker, offline page). Install is offered from the second visit, never the first. With push on (Settings › Notifications, per device), a comment on your model reaches Chromium as a push within 60 s, and an iPhone once the site is on its home screen, as Apple allows. Nothing is cached for `/app` or `/e/`. A deploy's pages are served on the next load (no stale shell). Deleting the account deletes its subscriptions. |
| 8 | **lists2a**: one Save, Lists by name, link-only lists, import preview | 2 | M | L | yes (`supabase/lists_link.sql`) | turntable (`web/model-page.js`) | `web/model-page.js`, `web/keep.js`, `web/lists.html`, `web/lists.js`, `web/collections.html`, `web/collections.js`, `api/_lists.js`, `api/_mylists.js`, `docs/LISTS.md` | docs/LISTS.md section 5, items 1, 2, 3 and 6, each as written there: the model page's Save is keep.js's panel; Collections are Lists everywhere, and `/collections` redirects; a link-only list opens by its link and nowhere else, until the link is revoked; an import shows matched, not found and already there before anything is written. `lists_flow` and `collection_flow` pass. |
| 5 | **ownedparts**: what you own, what you are missing, and only those to buy | 3 | M | M | yes (`supabase/owned_quantity.sql`) | lists2a (`web/keep.js`, `web/model-page.js`) | `web/card.js`, `api/_card.js`, `api/_owned.js`, `web/set-page.js`, `api/_sets.js`, `web/keep.js`, `web/model-page.js` (the Parts tab) | Signed in with owned sets (quantities 1-99 kept), every gallery card shows "You have 87%" when you have half or more. A model's Parts tab lists only what you are missing, with a BrickLink wanted list and a Pick a Brick list of just those: the model's list less your parts, by a test. Set pages say "In N lists". A gallery page of 24 cards answers no more than 50 ms slower. |
| 7 | **inbox**: say what you hear of, and where; mute a model; done | 3 | M | L | yes (`supabase/notification_prefs.sql`) | homescreen (`web/settings.*`) | `web/notifications.js`, `web/notifications.html`, `api/_notifications.js`, `web/settings.html`, `web/settings.js`, new `supabase/notification_prefs.sql` | Each of the 11 kinds can come here, by email or by push, or not at all. Mute this model stops its count. Mark all done. The account menu shows the newest five with their pictures. `digest_flow` and `notifications_flow` pass. |
| 11 | **insights2**: a designer's numbers against last month | 3 | M | L | yes (reads people's own numbers) | nothing | `web/designs.js`, `api/_designers.js`, new `supabase/designer_period.sql` (functions only) | Insights shows each model's views, builds, likes, saves and comments over 30 days beside the 30 before, with the change, and a chart by week. Nothing new is counted (D13). It answers within 1 s for 50 models. |
| 6 | **signin-google**: Continue with Google | 4 | M | M | yes (accounts) | a Google OAuth client, free, in a Google Cloud project the lead can make; parked, and said so, if there is none | `web/account.js` (the sign-in dialog), `web/settings.html`, `web/settings.js`, `api/_auth.js`, `web/privacy.html` | Continue with Google sits in the sign-in dialog at 390 and 1280. A new account made through it meets the age question and First steps, as an emailed one does. An email account signing in with the same Google address lands in the same account, never a second one. Settings lists the ways in, each removable while one is left. Deleting the account removes the identity. |
| 10 | **commentcare**: pin a comment and a build photo; held words | 4 | L | L | yes (`supabase/model_pins.sql`, `supabase/held_words.sql`) | ownedparts (`web/model-page.js`), insights2 (`web/designs.js`) | `web/model-page.js` (the designer's comment and photo controls), `api/_comments.js`, `api/_builds.js`, `web/designs.js` (the held words, beside Insights), new `supabase/model_pins.sql`, new `supabase/held_words.sql` | The model's designer pins one comment and one build photo; each shows first, marked Pinned, at 390 and 1280; hiding or deleting it unpins it. A designer keeps up to 50 held words or phrases: a comment with one, on any of their models, waits for them, its writer sees it as posted (as Instagram's Hidden Words does) and nobody else sees it until Approve. A base list is on by default and can be turned off. `comments_flow`, `mentions_flow` and `block_flow` pass. |


Wave 1 runs four units at once: bringyours, turntable, challengehonours and
seo2. Wave 2 is homescreen and lists2a. Wave 3 is ownedparts, inbox and
insights2. Wave 4 is signin-google and commentcare. The ranks are by value;
the waves follow what each waits on and which files it owns. signin-google
ranks sixth but waits on a client and on Settings, which homescreen and inbox
hold first.

**Leave out** (section 6 of the brief): payments, Pro and prizes paid in money;
the desktop downloads (paused, "Coming soon"); BrickBench submissions; new
languages (the new words go into de, fr and es as every unit's do); provider
API keys; posting from a real social account. A challenge's honours are
non-cash for that reason. Sign in with Apple needs Apple's paid developer
program, so it waits with payments.

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
*Built (2026-10-22, `supabase/notifications.sql`):* the marks as two new
tables instead, `notification_marks` (seen, all read) and
`notification_reads` (a model's group opened), so no live table is
altered; the avatar's count is notifications and the feed together, as
the app's Account says it.

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
*Built (2026-10-22, `supabase/replies.sql`):* a reply to a reply joins its
thread; a reply reaches the comment's author and whoever replied before
it in the thread (Notifications, kind `reply`); one rule,
`comment_parent_shown`, keeps a reply only where its comment is shown
(page, card counts, designer numbers, the day's email, notifications). The
step pill opens `/app?view=<id>&step=<n>`, which the app now takes into
its step player.

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
*Built (2026-10-22):* the lead's call: the account that shared the seven
(the studio's, at a brickworks.diy address) gets `/u/brickworks`, said as
the studio's own account (drawn as every person's page is, its name the
studio's and its words saying its models were made with the assistant, Claude in the app;
the castle as banner, three pinned), by `supabase/house.sql`, which the
lead applies: idempotent, additive, no model changed, so the cards credit
it through `directory_card`'s `by`. First steps (`web/first-steps.js`)
open after the age question is answered 13 or over; the kinds chosen only
order step 3 and are kept nowhere (D13). The Assistant mark is read from
tags, which the house's seven did not have (their descriptions say
"Designed by Claude"): the script's second step, apart and the lead's
call, appends ai-designed to those seven, so the mark is on every one and
With the assistant finds them.
*Changed (2026-11-02, the owner: the site leans less on AI):* no card says
how a model was made; its own page does, among its facts (With the
assistant, or Brickify, `api/share.js` madeFact), and the gallery's Made
filter still finds them.

### Phase 6: depth (after the first five, in this order)

| # | Unit | What | Size | Supabase |
|---|---|---|---|---|
| U11 | Collections first-class | A cover mosaic, Follow a collection (in the feed when it grows), "In N collections" on a model ([PR-C], [SK-P]) | M | `collection_follows` |
| U12 | Challenges that live between months | Past challenges and their winners, the next one's theme and date, entries as cards; a year of themes set once on /admin | M | `challenges` gains `announced_at` |
| U13 | Achievements | Earned marks on a profile: first model listed, first build finished, Tested, ten builds of your models, a challenge won ([PR-P], [MW-H]); names free of any LEGO® mark | M | none (computed) |
| U14 | Embed and share | A share sheet with the embed code; an embed that is the picture, name and Build it (exists) with the theme | S | none |
| U15 | Pictures that suit both themes | Renders at publish on a backdrop that sits in light and dark, and a 4:3 one (app code at publish, no interface change) | M | none |
| U16 | Hand-built said by the app | The app says at publish whether the assistant laid parts, so D7 is not left to tags (app code, no interface change) | S | `shared_models.made_with` |

*U15 and U16 built (2026-10-24, social230):* at publish the app sends,
beside the 1200 x 630 PNG link previews keep (on its own light ground, as
another site's page may be any colour), the same render with nothing behind
the model (`/m/X.cutout.png`, the model's page) and the cards' picture drawn
again four to three (480 x 360 WebP, nothing behind it). The site draws the
ground: `--picture-ground`, a lit dark grey in the dark theme (a black model
still shows on it) and in the light one the ground the app drew before, so an
old picture and a new one look alike there. Old models keep their pictures
(the page's cut-out falls back to the PNG) until published again; nobody's is
re-rendered. And the app says who laid the parts (`made_with`: hand for a
model begun empty in it, assistant once Claude laid any, by the panel or a
session's tools, brickify once Brickify did; nothing for a file that does not
say), kept in the model's text and sent; `supabase/made_with.sql` keeps it
for the server alone, and the card and the filter read it before the tags,
which a model the app said nothing of still goes by. A profile's banner
(/u/ and /profile) is the cut-out on the same ground since tidy240; it was
the PNG, a light box across the top of a page in the dark theme.
*U11 built (2026-10-24, `supabase/collection_follows.sql`, applied by the
lead):* a collection's page is headed as a playlist's or a board's, its
cover (up to four of its models' pictures) beside its name, whose, its
words, its models and followers, Follow, Share and More. Follow by
follows.sql's rules (13 or over, not taken out, not your own; counted with
following people); its owner is told nothing, its followers are a count.
What is put in it is in the follower's feed as a post with the model's
card ("Robin added “…” to their collection “…”"), counted on the avatar;
not in the day's email. A model's page says "In N collections", a pill
and a tab to a part of their cards; the public ones only, while the model
is in the gallery, a test account's only on a test model's page.

*U14 built (2026-10-24):* Share on a model's page opens a sheet, the
site's dialog, with its link and the embed code, each with Copy, what was
copied said in the sheet; on a phone the phone's own sheet offered too.
The embed loads `web/theme.js`, so it is in the theme its viewer chose
where their browser lets a frame inside somebody else's page read the
site's storage (most keep it apart: then their device's light or dark).
The embed's button still says View in 3D, and opens the model's page.
*U12 built (2026-10-24, `supabase/challenge_year.sql`):* under the
challenge shown, **Coming next** (the next one's theme and days, a
`.card`) and **Past challenges** (each that ran, the last first: its name a
link to its own page, `/challenge?id=N`, its days and entries, its winners
as the gallery's cards), as contest hubs list running, upcoming and finished
ones. `challenges.announced_at` says when visitors are told of one: null,
at once, for one set alone; a year of themes set once on /admin (a month a
row from a first month, title and brief, all or none, `POST /api/admin
?op=plan`) tells each a month before it opens, so the next is known while
one runs and the rest of the year stays the owner's. One the owner ends
before it opens never ran, and is in no list. Three of challenges.sql's
functions replaced with the same answers for every challenge there is
(`tools/challenge_year_try.sql`), guarded by `tools/apply_sql.mjs`.

*The page redone (challengepage, 2026-11-13; the owner: "the /challenge
page is ugly and just really bad ui/ux"):* laid out as the best contest
pages are (Printables' and MakerWorld's contests, Rebrickable's
competitions and Kaggle's), with no change to the API. The head
says where it stands at a glance: a status (Open, Opens soon, Ended), the
brief, the rules as checks, one primary Enter a model beside Share, and a
panel with a live countdown to its end (or start), the day it is of how
many, and its numbers (entries, designers, and votes once counted). Enter
a model works on the page: signed out it asks to sign in, then your models
in the gallery to choose from, by hand or with the assistant, the rules
checked on the server as before. The entries are the gallery's cards in a
grid, the two groups as tabs with their counts, ordered newest or oldest
first (most votes once ended, never while votes are blind), each card's
vote at its foot: Vote, asked once in a dialog because it cannot be moved;
then Your vote on the card and named over the cards, Your entry on your
own. Ended, the two winners come first, celebrated, over the entries. How
it works is three numbered steps, the rest folded. Past challenges are a
grid of cards, each a mosaic of its winners. No state is a dead end: no
challenge offers Start building and the ones that ran, a number with none
offers this month's, and a failed load Try again. Not built: how many
people voted (the API counts votes only once it ends, per entry; the
number of voters would need a new count in `challenge_page`, and the blind
vote would show it moving).

*U13 built (2026-10-24, no Supabase change):* **achievements** on a
profile and on your own, a row of pills after the numbers (beside them
on a laptop, under them on a phone), as GitHub's and Printables' profiles
carry their badges in the person's head: each
challenge won (a link to the model that won it), Ten builds (of their
models, to the last step), Tested, First model listed, First build
finished (a photo of their real build: builds are counted per device and
name nobody, D13), the rarest first. `api/people.js` `achievementsOf`
works them out from what the page already reads, so nothing is kept and
nothing new is tracked; a profile not shown in public (under 13, taken
out) shows none, to anybody, its owner included. No name uses a LEGO®
mark.

*A model page a builder can use (2026-10-26, site278, site273's unit 7):*
every shared model's page has its **Parts**, a tab and a section, as
Rebrickable's MOC pages are built around theirs ([RB]): how many parts in
how many lots, then a row a colour (or, with Kind, a part category) over
its lots, each lot its picture, name, part and element number, colour and
count, the first twelve rows until Show all. The list is the app's own
(`api/_parts.js`, a port of `Inventory.of` as `count_of_text` reads a file:
sub-models expanded, a sticker counted, a hose once, a ~ piece and an
unknown primitive not), worked out from the stored .mpd when the page or
the list is asked for, so every model shared before has one with no
republish; `src/dev/parts_page_probe.gd` holds it to the app's list lot by
lot and the exports word for word. What it needs of the catalogue (every
part's name, kind, moves and shop numbers; every colour's; the element
numbers; the flexible parts' lengths) is `_parts_table.json` beside the
share function, 3.2 MB (0.8 MB gzipped), written at deploy by
`tools/web/part_facts.mjs --parts`; a page's own bytes carry only the
section's head, and the list is its own request (`/m/X/parts.json`) made as
the section nears the screen, into rows of one height kept for it, so
nothing moves. **Export**: a BrickLink wanted list (`/m/X/parts.xml`,
BrickLink's XML: ITEMTYPE, ITEMID, COLOR, MINQTY in INVENTORY), a
Rebrickable parts list (`/m/X/parts.csv`: Part, Color, Quantity) and a
LEGO® Pick a Brick list (`/m/X/parts-pab.csv`: elementId, quantity, with
LEGO's own line ends; past 400 elements a file each, `parts-pab-2.csv`
and on, as its upload takes them; sitepickabrick, 2026-11-08), in each
shop's own part and colour numbers as the app exports them
(`ShopLists`), a made part or a colour the shop has no number for left
off and counted, never guessed: what Pick a Brick leaves off, a lot with
no element number known, is said under the buttons in lots and parts,
and an element past the 999 it takes, the rest to add by hand. **Download** beside Build it: the
version's .mpd as it is stored (`/m/X.mpd`, `/m/X/v/N.mpd`), signed out,
named for the model. **Like** and **I built it** ("Built") say their
names beside their icons and counts from 600 px up (`.icon-btn.labelled`);
a phone's row of six has room for icons and counts alone. A lot has no
picture yet: it shows its colour. Rebrickable's photos were left out on
purpose (2026-10-26): they would have every visitor's browser ask a third
party for every part on every page, where Brickworks asks Rebrickable at
most once a day, so the page's security policy allows images from itself
alone; our own renders of each part in its colour come later. No
booklet PDF is kept for any model (the bucket holds the .mpd and its
pictures), so the page offers none; the viewer makes the booklet.

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

## 7. Phase 7 (2026-10-30)

The owner (2026-10-30): "improve social features of site", to the bar
of better than any competitor on every feature, with nothing half done.

**What is built.** Every unit of section 5 is built and live, U12-U14
included (their notes above; the code: `supabase/challenge_year.sql`,
`api/people.js` `achievementsOf`, `api/share.js` `shareSheet` and
`embedCard`). On 2026-10-29 the live `/challenge` shows Haunted house
open, with no entry, and Microscale told for November. The community is
still the house's: the gallery's first page is 24 models, every one
`/u/brickworks`'s, with 0 likes, builds and remixes. So the cold start
(D12, [AC]) still decides the order: first what brings people in from
elsewhere, then what gives a designer a reason to come back.

**Where U12-U14 fall short of the best today** (research 2026-10-29,
sources at the end; Printables' public API and Sketchfab's oEmbed read
directly):

- **U14, Share.** Only a model's page has the sheet. A profile's and a
  collection's Share copy the link and nothing more; `/challenge` has no
  Share, and its link preview is the site's generic picture. No network
  is offered: Sketchfab puts Facebook, X and Pinterest under its viewer
  [SK-SH], Mecabricks Facebook and X beside its embed [MB-S], Behance a
  Share and Embed menu [BE-S]. There is no oEmbed, so a link pasted into
  WordPress, Ghost, Notion or a Discourse forum stays a bare link, where
  Sketchfab's (`/oembed`, a `rich` iframe, a discovery link in the page)
  becomes its viewer [SK-O]. The embed is a picture and a name; Sketchfab's
  and Mecabricks' are the 3D viewer [SK-EO], [MB-S].
- **U13, Achievements.** Five marks, each had or not, that nobody is told
  of. Printables has 22 badges, six of them tracks of four to nine levels,
  each level a number to reach ("Publish 5 models"), a profile level that
  is the count of badges, and an email when one is earned [PR-B], [PR-BL].
  MakerWorld's are one-offs [MW-A]; Dribbble, Behance, Sketchfab and
  Thingiverse have none. Nobody shows how far a person is from the next
  level: an open lane.
- **U12, Challenges.** Complete as a page: open, next, past, entries in two
  groups, votes, winners, entry from the model's page as Rebrickable's
  competition tag is [RB-C]. Nobody is told: a challenge opens and only
  someone who opens `/challenge` knows; nobody is reminded before it
  closes; a voter never hears who won. No peer documents reminders. The
  open challenge has no entry with two days left (live, 2026-10-29);
  Printables runs about three a month, median 16 days and 223 entries
  [PR-B].

**Ranked**, value first, then size (S, M, L as section 5):

| # | What | Value, and the evidence | Size | Supabase |
|---|---|---|---|---|
| 1 | **Share everywhere** (U14 finished): the one share sheet on a model's, a set's, a profile's, a collection's and the challenge's page: its link, the phone's own sheet, Reddit, Bluesky, Pinterest, X, Facebook and email, the embed code where there is one; oEmbed at `/api/oembed` with its discovery link on `/m/`; the challenge's own link preview | High: every share is a way in from elsewhere, which a gallery of one designer needs most [AC]; [SK-SH], [MB-S], [BE-S], [SK-O] | M | none |
| 2 | **Achievements with levels and the next step** (U13 finished): tracks with levels (models in the gallery, builds finished of them, photos of real builds, remixes of them, Tested), one-offs (a challenge entered, a challenge won); the next level and how far, on your own page; a page of them all, with how many hold each; told in Notifications when earned | High on the side that makes the work, designers [AC]: [PR-B], [PR-BL]; the next step shown is ours alone | M | `achievement_marks`: which levels each account has been told of |
| 3 | **Challenges people hear of** (U12 finished): in Notifications when one opens and two days before it closes, for everybody who may enter; the winners for whoever voted; Share and its own link preview (in 1) | Medium-high: an empty challenge is a dead end (D12); the lane is open | S | none, or a mark for what was told |
| 4 | **The embed in 3D**: `/m/X/embed` as the model turning, as viewer369's inline preview draws it | High: Sketchfab's whole embed [SK-EO], Mecabricks' too [MB-S]; after viewer369 lands | S then | none |
| 5 | **Based on**: a model credits a set of the LDraw library (an alternate build or a change of it) or work elsewhere (its link, author and licence), beside today's remix line | Medium: Printables takes several parents, outside links with their author and licence [PR-B]; Rebrickable asks which set a MOC is built from [RB]; half of Thingiverse's remixed things have several parents [GR]. Only Brickworks has each set's own page to link to | M | additive column or table on `shared_models` |
| 6 | **@mentions in comments** told in Notifications, 13+ shown profiles only, three a comment | Medium, later: Behance [BE-M], Dribbble [DR-N], Sketchfab [SK-N]; there is no conversation yet to mention anybody in | M | new versions of the comment functions |
| 7 | **The week by email**, opt-in: your models' week, what people you follow made, the challenge | Low now: nothing happens yet; none of the peers sends a personal one [DR-N] | M | a mail kind |
| 8 | **Builds as a gallery tab** (everybody's real builds) | Low now: 0 builds; site357 owns the gallery | S | none |
| 9 | **People to follow on a profile** (more like this designer) | Low now: one designer; the feed has them (U9), as Sketchfab's and Behance's feeds do [SK-F], [BE-F] | S | none |

**Not built, with the reason:** reactions beyond Like (none of the peers
has them on work; MakerWorld's Boost is scarce and paid for by the site
[MW-B]; a site with children on it keeps one plain Like); streaks
(section 5's list; GitHub removed its own in 2016 so the profile "focuses
on the work you're doing rather than the duration of your activity"
[GH-S]; MakerWorld's Guardian expires, Printables' Maniac counts visits).

**The order built:** 1, 2, 3 (U14, U13, U12 as asked), then 5 and 6.
4 waits for viewer369. Each is done end to end, its browser flow on a
preview, before the next begins.

**2 as built** (supabase/achievements.sql): six tracks, Designer (models
listed: 1 3 10 25 50 100), Built (builds finished of them: 1 10 50 100 500
1000), Builder (photos of real builds: 1 5 10 25 50), Remixed (1 5 25 100),
Tested (1 5 10 25) and Challenger (challenges entered: 1 3 6 12); a
challenge won stays a pill of its own. The level shows as its number
("Designer · 10 models", the level on hover) on the person's page; your
own profile's Achievements tab has every track, how far the next level is
and what gets you there, with a link where a page helps. A level reached
is written down the next time the account opens any page (its avatar's
count) and told in Notifications, a group of its own. Not built: how many
hold each level. With one designer in the gallery every share would read
100% or 0%, which says nothing; it is worth adding once there are a few
hundred designers.

**3 as built** (supabase/challenge_notices.sql): Notifications tell every
account that may enter (13 or over, not taken out of the gallery) when a
challenge opens, or when it is told if that is later, and again at the
start of its last two days unless they entered; and whoever voted without
entering when its winners are named, saying whether a model they voted for
won (an entrant already hears it under their model). Each challenge's
notices are a group of their own, its link the challenge's page, read once
opened; nothing is kept but when each was read, the rest read from the
challenges as they are. An account hears only of what came after it was
made, so a new account is not handed a backlog. Not built: an email when a
challenge opens. The day's email already tells what is new; a second email
a month would be the first one the site sends unasked. Each challenge's
own link, `/challenge?id=N`, has its own preview: its title, its brief and
days, and a winner's picture once it has one.

**4 as built**: the embed's picture is the model in 3D, as its page's is:
View in 3D on it, a click or the first drag across turns the model in the
frame, in somebody else's page, with viewer369's own view (the same code,
budget and touch rules: a phone's finger up or down scrolls their page
until the model is taken hold of). Nothing of it loads until asked; the
embed is still a picture and a bar, about 8 KB of script. Full screen is
the screen's where the page allowed it (the share sheet's code and oEmbed's
both do), and every link opens a tab of its own, since the app cannot run
in a frame. Sketchfab's embed is its viewer [SK-EO]; this is Brickworks'
model, its steps a click away in Build it.

**5 as built** (supabase/model_bases.sql): a model's designer says what it
is based on, up to three: an alternate build of a LEGO® set (built from its
parts, Rebrickable's word), changed from a set or from work elsewhere, or
inspired by one. A set is given by its number, checked against the
catalogue and linked to its page here; work elsewhere by its https address,
its title, and its author and licence when known, said as written and
linked as theirs (nofollow ugc). The lines sit under the remix line on the
model's page, in its structured data (`isBasedOn`) and its JSON
(`based_on`); each set's page lists the
gallery's models based on it, Based on this set, which no peer can do
without a page per set. Under 13, not offered: a name and a link shown in
public. Not built: picking the set from a search in the dialog (its
number is typed, and refused in words when the library has not got it),
and a work elsewhere's picture.

**6 as built** (supabase/comment_mentions.sql): `@` in a comment or a reply
offers the people on the page, the designer first, then the commenters
and those they named, as Behance and Sketchfab do; arrows and Enter, or a
click, put one in, and any public profile's handle works typed out. Each
named becomes a link to their page and is told in Notifications with what
was said, at most three a comment however often it is edited, so an edit
cannot spam. Never twice: the designer already hears of every comment, and
someone in the conversation of each reply. Only profiles shown in public,
13 or over, can be named, and only by someone 13 or over; hiding or
deleting the comment takes the notice with it. Since socialtails (pre261
7d3b2ede), @ offers anyone who may be named, by a search of shown profiles as
one types. Not built: an email for a mention.

**8 as built**: Builds, a tab of the gallery beside Top, New and
Collections, at `/builds` (its own page, as Collections and the LDraw
library are, so it has no bar of filters a photo means nothing to).
Everybody's photos of real builds, newest first, 24 to a page with the
gallery's paging, each as the gallery's card (the photo cut to 4:3, shown
whole at its model's page): its model's name, a link to the photo on that
page, who built it, a link to their profile, when, and what they said. A
photo is left out once its model's owner hides it, while a report of it
waits for the site's owner, and when its builder or the model's owner was
taken out or is not shown in public (under 13); only a model in the
gallery has its builds there. Empty, the tab says what a build is and how
to add one: I built it on a model's page. No SQL. Since socialtails (pre261
7d3b2ede), each card loads a picture its own size (480 px wide or less). Not
built: masonry (D4): the cards
are the gallery's, so Show more puts a page after the last without moving
what was there.

**9 as built** (supabase/designers_alike.sql): More like <name>, on a
person's page under their work, up to six designers whose models in the
gallery share the most with theirs. Each theme (a model's kind; "Something
else" is none) and each tag in common counts one, ai-designed and brickify
aside; the parts both use, colours aside, count up to three, as the share
of the parts either uses. One theme or tag in common, or a third of the
parts, is close; between equals, more of the person's followers following
them comes first. Never the person, never whoever is looking, never anybody
they follow already; only profiles that may be followed (13 or over, shown
in public, not taken out). Each has Follow in place; the section is hidden
when nobody is close. Who follows whom only orders the list and is never
said (D1); a signed-in answer is never kept by the CDN. Until the SQL is
applied, the themes and tags alone (the parts and the followers in common
need the database's own function: about 4 ms on today's gallery, 0.6 s at
2,000 designers, measured in the dry run). Not built: a "why" beyond the
line of what they share, and suggestions on your own page or in the feed
from this (the feed's designers to follow are U9's, by Top builds).

## 8. Sets and lists (2026-11-13)

The owner asked for lists people make and manage in the gallery and a way
to show off the sets they own. That work has its own research and plan:
docs/LISTS.md (Own and Want on every set, Save on every gallery model,
lists of your own holding both, Your lists at /lists, the profile's Sets
tab; unit lists1, and what is left for lists2 in its order).

## 9. Blocking a person (2026-11-19)

Nobody could be blocked on brickworks.diy: a model's owner could hide a
comment, but nothing stopped a person. Brick Creator 3D's gallery lets
you "report creations or block authors" (docs/APP_UX10.md, item 6). Unit
blockauthor read how five sites treat a block, then built one
(`supabase/block.sql`, `api/_blocks.js`, `web/block.js`).

### What the sites do

Most help pages refused automated reading (X and Reddit 403, Instagram's
loaded empty), so where a line says *excerpt* the words are a search
result's quote of that page, not a full read.

| | Instagram [IG-B] | X [X-B] | Reddit [RD-B] | Printables [PR-B] | Thingiverse |
|---|---|---|---|---|---|
| What the blocked person sees of you | nothing: they "can no longer search for your profile, view your content" | your public posts, but they "cannot engage (like, reply, repost)" (excerpt) | your posts as "[deleted]" / "[unavailable]"; not your profile (excerpt) | not documented; reads as a filter on your own view | no block found |
| Follows | end both ways, not back on unblock (a guide only [IG-G]) | "will cause you to unfollow that account (and them to unfollow you)"; they "cannot follow you" (excerpt) | not documented | not documented | |
| Old comments | stay; "you can delete their comments" (archived help, excerpt [IG-C]) | not documented (only "hide reply") | collapsed for the blocker [RD-E] | not documented | |
| Notifications | a blocked mention "won't appear in your Activity" (archived, excerpt [IG-M]) | "you will not receive notifications from accounts you block" (excerpt) | not documented | | |
| Is anybody told | no: "People aren't notified when you block them" | no notice, but they "will see they have been blocked" on your profile, and a follow says so [X-F] | no notice; a failed reply said "Something went wrong" (a user's report) | not documented | |

They disagree most on two things: whether the blocked person learns of it
(X says so on the profile; Instagram and Reddit stay silent), and whether
old comments stay (Instagram leaves them for you to delete; Reddit folds
them for you only). Printables has, from its forum, a "hide this creator
from me" list under your account's settings, not a two-way block; we found
nothing for Thingiverse.

### What Brickworks does, and why

The person who blocks (A) is the one to protect, and the person blocked (B)
is the one who might retaliate if told. So each choice below is the one
that leaves A safest without telling B anything B could act on.

- **Never told.** No notification, mail, count or page says B was blocked.
  B's own pages are as before. A refusal B meets says only that it cannot
  be done ("You can't follow this profile.", "You can't comment on this
  model.") with no word of a block, as Instagram and Reddit do. X's
  "you have been blocked" is what we chose not to copy: it is the moment a
  harasser starts a second account. A, who did it, is told plainly why and
  where to undo it.
- **B's comments on A's models are hidden from everybody**, not just from A,
  with their replies. Instagram leaves them for A to delete one by one, and
  Reddit folds them only for A. Both leave the abuse on A's page for
  everyone else, which is the harm a block is for. B still sees their own
  comments as before, so the page doesn't tell B anything. Comments on
  other people's models stay, but are hidden from A wherever A reads.
- **Both ways for writing, one way for reading.** Neither may follow the
  other or the other's collections, comment on the other's models, reply
  to the other's comment or in a thread the other started, post a photo of
  a build on the other's model, like the other's model, remix it, put it in
  a collection, or @name the other. A trigger on each table says it
  whatever writes it. Likes are refused too because a day's likes reach A
  as one row with a count, which no list can leave B's like out of.
  Remixes and collections are refused because each sits on A's model's
  page, and a collection's name is B's to choose: the same harm hiding B's
  comments is for. A remix B made before keeps its link, and its republish
  is B's own; a collection filled many at once leaves the model out and
  keeps the rest. B's @ list still offers A, as anybody's does:
  A missing from it would tell B. Reading stays open both ways on public pages: a
  public model page is public signed out, so hiding it from a signed-in B
  would protect nobody and would tell B.
- **Follows end both ways, and unblocking doesn't bring them back**, as X
  documents and Instagram's guides say. A follow brought back on its own
  would tell B of the unblock and put B back in A's feed unasked.
- **What leaves A's model pages, for everybody:** B's remixes and B's
  public collections made before the block, and B's models among those
  beside it, out of the page's counts too; the page is everybody's, so it
  goes by A's blocks, as A's comments do. Back when A unblocks.
- **What leaves A's view:** B's models from A's gallery (search included),
  shelves, feed, Latest on Brickworks (the feed page's rail and First
  steps, answered for A alone) and "More like"; the same where A's own
  Claude reads the gallery and a model's comments and photos, and in the
  app's Library, which ask with A's session once A is signed in; B's rows from
  A's notifications and the daily mail, and rows about B's models (a remix
  of A's model with no maker named, a reply on B's model); the count on
  A's avatar, counted again without them (never the count less them: a
  count stops at 99); B from A's @ list.
- **Unblocking** brings back what was hidden (models, comments) and lets
  either follow or comment again. Settings › Blocked people lists whom you
  blocked, newest first, each with Unblock, as Printables' and Instagram's
  settings do.
- **The owner sees how many, never who.** /admin › People › the account
  says "Blocked by N people" beside its reports (docs/ADMIN.md), so a run
  of blocks can be weighed with reports. Who blocked whom is no client's
  to read: the table has row security on and every client role revoked;
  an account's export leaves out who blocked it, even the count.
- **Limits.** At most 1,000 blocks an account, as Reddit's, and 60 an hour
  (300 a day), so blocking can't be used to probe who is who.

## 10. Talk, the builders' forum (2026-11-22)

Until now people could talk only under one model or one step of it. The
owner, 2026-11-22: "We want the 'forum/gallery' features to be better
highlighted and available immediately upon landing." Unit talk read how
forums and the LEGO® building sites do it, then built Talk at /talk
(`supabase/talk.sql`, `api/_talk.js`, `web/talk.js`, `/admin` › Talk).

### What the others do

| | Discourse [TK-TL] [TK-FL] [TK-NL] | Eurobricks [TK-EB] | Rebrickable [TK-RB] | Printables, MakerWorld | Mecabricks, BrickLink Studio |
|---|---|---|---|---|---|
| Where people talk | categories, topics, replies | boards by theme, a [MOC] topic per build | a forum beside the MOC pages | a separate forum site each (Prusa's forum, Bambu Lab's forum) [PR-B] [MW-H] | a forum [TK-MB]; Studio's gallery has comments only [BL] |
| A build in a post | a pasted link becomes a card (onebox) | a picture hosted elsewhere, a link | a link to the MOC page | a link | a link |
| New people | trust level 0: few links, no images, limits that lift with reading and time [TK-TL] | moderators approve | | | |
| Bad posts | flags; enough of them hide the post until a moderator looks, the writer can still see it and edit [TK-FL] | report to a moderator | report | report | report |
| Hearing of replies | Watching (every post), Tracking, Normal (mentions and replies to you), Muted [TK-NL] | follow a topic | follow | | |
| Search engines | DiscussionForumPosting markup on every topic [TK-DF] | | | | |
| Feeds | RSS per category and per topic | RSS per forum [TK-EB] | | | |

Two things stand out. Every LEGO® building site keeps its forum apart
from its builds: a link from one to the other at best, so a build's
conversation and the forum's never meet. And a new forum is empty: the
advice that holds across Discourse's own launch guides [TK-DL] and the
research on seeding [TK-MS] is to launch with real first topics (a
welcome, an "introduce yourself", open questions that ask for pictures),
written by the people who run it and answered by them early, never with
made-up members.

### Decisions

- **Boards, not categories.** Show and tell, Help, Ideas, Challenges and
  News, as a row of tiles over one list, each its icon on its own colour,
  its name and its count (sitebold, 2026-11-23; tabs before), "Latest"
  being every board. A thread's row leads with the picture of the model it
  is about, else its board's icon, and ends in the faces of who started it
  and who replied last, the replies and when. News is the house's alone to start; anybody may reply.
- **Threads and replies are the comments' own.** The same post markup
  (`.comment`), mentions (@handle, three a post, told only to people of
  the same pool who may be named, never somebody blocked), Report,
  Block, hidden and removed states, the same limits through `may_act`,
  and the same Notifications page and push: two new kinds, `talk_reply`
  ("{who} replied in your thread / a thread you follow") and
  `talk_mention`. Plain text only, 4,000 characters; a title 3 to 120.
- **A pasted link is a card.** A model's page, a step of it
  (`/app?view=ID&step=N`), a set of the library, a challenge on
  brickworks.diy show as cards with their picture, as Discourse's
  onebox does. A Rebrickable or BrickLink part number shows as a chip,
  not linked. A link to any other site stays words, never a link, so
  Talk is no place to post spam links.
- **One photo a post**, through the build photos' own path (location and
  time taken out, a card's copy made), kept as `talk-<id>.jpg`; served
  only while its post is shown, its files deleted with the post (Remove)
  or the account.
- **Follow a thread** (Discourse's Watching): the starter and everybody
  who posts follow it; anybody can follow or stop. Mentions and replies to
  you reach you either way (Discourse's Normal).
- **Reports hide.** Three different signed-in people of its pool hide a
  post until the site's owner looks (Discourse's flags); its writer still
  sees it, said so. A visitor's report counts for the owner's queue, not
  for hiding.
- **Blocks hold across Talk.** Never a post of somebody you blocked; the
  posts of somebody a thread's starter blocked are seen by nobody but
  their writer there; a blocked person's reply is refused in words that
  do not say why ("You cannot post here."), as comments do.
- **Moderation in /admin › Talk**: Reported (Hide or Show, Remove, Let
  the reports go, Ban for a day, a week, a month or for good), Threads
  (Pin, Lock, Hide, Move to a board, Remove) and Banned (Unban). Every
  act is in the audit log.
- **Never empty on its first day.**
  - Beside the threads, what builders say under the gallery's models,
    newest first; while nobody has said anything, the newest models with
    a prompt to be the first.
  - The house writes the first threads itself, through the API, dated
    when they are written, as Brickworks, never as made-up people: a
    welcome in News, how to ask for help in Help, "What are you building
    this week?" in Show and tell, "What should Brickworks do next?" in
    Ideas, and a recent change (Own, Want and your lists) in News.
  - Each month's challenge opens its own thread in Challenges, by the
    house, linking to the challenge.
  - A shared model's builder is offered a Show and tell thread about it
    on its page, and its page links to the thread once there is one.
- **Found on the web.** Every thread is a server-drawn page with its own
  address (`/talk/t/<n>/<title>`), DiscussionForumPosting JSON-LD with
  the replies as Comment [TK-DF], hreflang copies in German, French and
  Spanish, and an RSS feed for every board and for all of Talk.
- **On the first screen.** "Talk" in the header beside Gallery, in Menu
  and in the footer's Community; on the homepage the newest threads are
  posts in its feed, each with its latest reply (section 11, homefeed
  2026-11-23; landing's band before it).
- **The two pools.** Throwaway test accounts talk in a pool of their own
  (`?tests=1`), as the gallery's; a preview never writes the real pool's
  house threads.

What it does not do yet: likes on posts, accepted answers in Help, a
board you follow (Discourse's Watching First Post), and post drafts kept
across devices. Each is a follow-up for the owner to choose.

## 11. Work in progress, shared by version (2026-11-23)

A model was shared when it was finished, so the weeks it took to build
were seen by nobody, and a builder's followers heard of it once. Builders
on the LEGO® sites post a WIP topic and add to it as they go (Eurobricks'
[WIP] threads, Flickr albums); Brickworks now keeps that for them, from
the studio, in one press (unit buildlog; `supabase/wip.sql`, `api/_wip.js`,
`src/ui/share_panel.gd`, docs-site/sharing.md#progress).

- **Share progress** beside Publish in the studio's Share panel publishes
  the version as Publish does, marked WIP, listed and credited, with its
  note (What changed?). Publish then reads Publish as finished; Mark it
  finished on the page's Log calls the newest one finished.
- **Talk.** The first WIP opens the model's one Show and tell thread, by
  its designer, with the model's card; each later WIP version is one post
  in it (its note, the versions' own line of what changed, and the
  version's card with its picture, `/m/X/v/N.webp`), never a new thread;
  the finish is the last post. `wip_talk` holds the version row, so a
  version asked twice posts once, and Talk's own rules (limits, bans, the
  age question, blocks) hold for every post. A post Talk refuses never
  stops the publish; the panel says why.
- **The feed.** Followers of the designer see *shared work in progress*,
  *shared progress on … version N* and *finished …*; followers of the
  thread are told of each post as of any reply.
- **Ranking.** A WIP model is in Newest, marked, and never in Top, the
  ranked sorts, This week's pick, a challenge, a feature or a shelf
  (`gallery_shows`, `gallery_models`); finished, it ranks as any model.
- **The Log.** A model's Versions tab is its Log: every version, newest
  first, each with its picture, date, note and what changed, WIP and
  Finished marked, each opening `/m/X/v/N`.

What it does not do yet: a WIP's own picture strip of photos between
versions, and saying in the studio which followers have seen a version.
## 11. The home is the feed (2026-11-23)

The owner, 2026-11-23: "turn the landing into our lego 'social media' as it
simultaneously advertises and integrates the CAD." Unit homefeed read how
the home feeds of the social sites and the model sites work: what a card
holds, how a card sells the tool behind it, and how a stranger becomes a
member. Then it made brickworks.diy's home one feed (`web/home-feed.js`,
`web/landing.js`, `tools/web/home_shelf.mjs`; docs/HOME.md).

### What the others do

| | A card holds | The tool behind it | A stranger |
|---|---|---|---|
| Instagram [HF-IG] | the picture, heart, comment, share, save | | a few rows, then a sign-in pop-up that cannot be closed |
| Pinterest [HF-PI] | the picture; Save and a board picker on hover | | trending Pins, then a sign-up pop-up; its own test found the pop-up that cannot be closed lost members over time |
| Reddit [HF-RD] | title, media, votes, comments; a reason ("Because…") and Join on a recommended one | | For you and Following since 2026-10-28, reopening on the last used; six trending posts for a visitor |
| Printables [HF-PR] | picture, likes, downloads; a community feed of uploads, makes and likes, repeats collapsed | Open in PrusaSlicer, off until turned on in settings | featured models, contests |
| MakerWorld [HF-MW] | picture, boosts, prints | Open in Bambu Studio, with the designer's printer settings; printing from the card | recommendations tuned for good new models with real photos |
| Thingiverse [HF-TV] | picture, likes | Open in Customizer on some | downloads with no account |
| Rebrickable [HF-RB] | picture, parts, the MOC's kind (original, alternate, mod) | Build: what you own against what it needs, the rest to a BrickLink cart | "Create an account to find MOCs you can build from the parts you already own" |
| Mecabricks [HF-MB] | picture, four numbers with no labels, no Follow | an Editor tab on the model's page: the whole editor | "Build & Render your 3D LEGO® models online", Start Now, then twelve cards |
| BrickLink Studio [HF-BL] | picture, likes, comments | Import in the desktop app, greyed out for display-only builds | asked to sign in once a download has started |
| Flickr's LEGO® group [HF-FL] | the photo alone: no title, no author | | Join; a monthly takeover of Explore chosen from members |

Three things decide the design. Every model site hands its builds to a
program somewhere else, and each makes that hard: a setting to turn on, a
desktop app, a greyed-out Import. A CAD that runs in the page can open an
editable copy from the card itself, and can put the studio in the feed.
The hard walls (Instagram's, Pinterest's pop-up, Reddit's tests) lose
people, by Pinterest's own numbers; a visitor should read freely and be
asked to sign in only when they act. And no source found a 3D turn on a
card, or a sign-in that brings the person back to what they pressed: both
are Brickworks' to have first.

### Decisions

- **The feed is the first screen, for everybody.** One stream of posts:
  builds, Talk's threads with their latest reply, the month's challenge
  with its entries, the studio to try, builders to follow, photos of real
  builds. Signed out, one band over it says what Brickworks is in a line,
  with the search and Start building, and nothing else stands between a
  visitor and the first post (within 600 px on a phone).
- **Signed in: For you, Following and New** (Reddit's and Instagram's
  tabs). For you is the stream asked as them (their likes, nobody they
  blocked); Following is what the people they follow made (`/feed`'s own
  rows); New is everything newest first. Share a build at the top opens
  the studio's publish for their last model (`/app?share`).
- **Every build card is a way into the studio.** Open in the studio (the
  viewer), Remix (a copy of their own, its page saying whose it was),
  Build it (the steps, one at a time) and Parts (to list and buy), on
  every card, no setting to turn on. A pill says how it was made (with
  the assistant, by hand, Brickify, what moves, how many steps), each a
  link to that feature's docs page: the card sells the feature that made
  it (Mecabricks' Editor tab and Rebrickable's Build, on the card).
- **A 3D turn in the picture's place**, on a pointer that rests on it or a
  tap of 3D, three.js asked for only then; never unasked for somebody
  who asked for less motion.
- **The studio in the feed.** A Try it here post puts the real studio in
  the post on a tap (the viewer at `/app?view=<id>`: turn it, play what
  moves, build it step by step), nothing of it asked for before; Open the
  whole studio takes the model across as a copy of their own. A visitor
  edits nothing before signing in (everyone who builds has an account,
  13 and over): what carries across is the model, not a pose played in
  the post.
- **No walls; asked on the spot.** A visitor reads every post, follows
  every link, opens every model in the studio. Like, a comment and Follow
  ask to sign in in a dialog over the page (`askToSignIn`), and once in,
  the like or the comment goes on, the page where it was, what was typed
  kept.
- **Never empty on day one.** The first posts are written into the page
  at the deploy from the live answers (the house's seeded gallery, Talk's
  house threads, the month's challenge), or from the last answers kept
  (`web/_home.json`), so the first screen never waits on the server; the
  rest come once the page is idle, counts said in place, nothing in view
  moving.
- **An end to it.** Show more, not endless scrolling (NN/g, section 2):
  the footer and the studio's own sections stay reachable.
- **Found on the web.** The first posts are in the page as served, each a
  link to its model's page, for a crawler as for a person.

Not done here, each for the owner to choose: a reason on a recommended
card ("Because you liked…"), owned-parts matching on a card ("you have 80%
of its parts"), collapsing a builder's many uploads into one post
(Printables), and For you ranked by what a person likes rather than by
the gallery's own order.

## Sources

Read 2026-10-22. Where a site refused automated reading, the claim is
from its captured page text in search results or a guide, as noted.
Phase 7's (section 7) were read 2026-10-29; they are after these.

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

Phase 7's, read 2026-10-29:

- [BE-F] Behance help, the For You feed:
  https://help.behance.net/hc/en-us/articles/204484454-Guide-For-You-Feed
- [BE-M] Behance help, comment mentions (notified on Behance and by
  email): https://help.behance.net/hc/en-us/articles/204484484-Guide-Comment-Mentions
- [BE-S] Behance help, Share and Embed (Copy Link, Copy Embed):
  https://help.behance.net/hc/en-us/articles/19288565618971-Guide-Sharing-and-Embedding-Behance-Content
- [DR-N] Dribbble's notification settings (Mentions among 16 kinds; no
  digest of people followed): https://dribbble.com/notifications
- [GH-S] GitHub, "More contributions on your profile" (streaks removed,
  2016): https://github.blog/news-insights/product-news/more-contributions-on-your-profile/
- [GR] Roumen et al., Grafter (2018), on Thingiverse's remixes with
  several parents: https://hpi.de/oldsite/fileadmin/user_upload/fachgebiete/baudisch/projects/grafter/Roumen-2018-grafter-paper.pdf
- [MB-S] A Mecabricks model's Share tab (link, an Embed Viewer iframe to
  its 3D player, Facebook, X), observed: https://www.mecabricks.com/en/models/07vN6RZWvAm
- [MW-A] Bambu Lab forum, MakerWorld's profile achievements:
  https://forum.bambulab.com/t/updated-new-achievements-on-makerworld-profile/163541
- [MW-B] Bambu Lab, the MakerWorld Boost:
  https://blog.bambulab.com/rethinking-rewards-makerworld-boost-system
- [PR-B] Printables' public API, read directly
  (`https://api.printables.com/graphql/`: `badges { name badgeLevels {
  name description } }`, 22 badges, Designer's nine levels from "Publish
  your first model"; `competitions { openFrom openTo printsCount }`)
- [PR-BL] Prusa, the reward system and badges (an email when one is
  earned, three chosen to show):
  https://blog.prusa3d.com/introducing-a-new-reward-system-and-badges-for-prusaprinters_60073/
- [RB-C] Rebrickable, a quarterly competition entered by a tag on the MOC:
  https://rebrickable.com/blog/621/quarterly-competition-announcement/
- [SK-EO] Sketchfab help, the embedded 3D viewer's options:
  https://help.sketchfab.com/en/articles/16152734-customizing-your-embedded-3d-model
- [SK-F] Sketchfab, profiles to follow in the news feed:
  https://sketchfab.com/blogs/community/stay-up-to-date-with-our-news-feed
- [SK-N] Sketchfab, notifications (mentioned in a comment):
  https://sketchfab.com/blogs/community/welcome-notifications-updated-newsfeed
- [SK-O] Sketchfab's oEmbed, read directly: https://sketchfab.com/developers/oembed
- [SK-SH] Sketchfab help, sharing (Facebook, X, Pinterest):
  https://help.sketchfab.com/en/articles/16152737-sharing-models-online
Section 9's, read 2026-11-19 (most by search excerpt, as it says):

- [IG-B] Instagram, restrict, mute, block and report:
  https://about.instagram.com/blog/tips-and-tricks/restrict-mute-block-report-guide/
- [IG-C] Instagram help (archived), what happens when you block someone:
  https://help.instagram.com/426700567389543
- [IG-M] Instagram help (archived), mentions from a blocked account:
  https://help.instagram.com/454180787965921
- [IG-G] A guide to Instagram's block (follows end, not restored):
  https://macpaw.com/how-to/block-unblock-someone-instagram
- [X-B] X help, blocking and unblocking accounts:
  https://help.x.com/en/using-x/blocking-and-unblocking-accounts
- [X-F] X help, common following issues ("blocked you from following"):
  https://help.x.com/en/using-x/common-following-issues
- [RD-B] Reddit help, how does blocking work:
  https://support.reddithelp.com/hc/en-us/articles/4413520308372-How-does-blocking-work
- [RD-E] Engadget, Reddit's block update (a blocked user's posts collapsed):
  https://www.engadget.com/reddit-updates-block-feature-000112208.html
- [PR-B] Prusa forum, Printables' blocked creators under your account:
  https://forum.prusa3d.com/forum/english-forum-general-discussion-announcements-and-releases/printables-com-feature-request-improved-filtering-block-or-hide-selected-user-and-their-models

### Round 8 (2026-11-20)

Read on 2026-11-20. *(excerpt)* marks a claim resting on a search result's
text where the page itself refused a reader.

- [R8-RB] Rebrickable (never fetched; once a day at most): Bricknerd's guide
  to sharing MOCs, https://bricknerd.com/home/mastering-rebrickable-a-guide-to-sharing-mocs-and-instructions-1-10-25 ;
  custom profiles and per-designer notices, https://rebrickable.com/blog/572/new-feature-lego-workbench-custom-profiles *(excerpt)* ;
  the Build search, https://www.eurobricks.com/forum/forums/topic/147089 *(excerpt)*
- [R8-BL] BrickLink Studio's gallery: help, https://studiohelp.bricklink.com/hc/en-us/articles/5705436653847
  and https://studiohelp.bricklink.com/hc/en-us/articles/360042355033 ; the
  archived gallery page, https://web.archive.org/web/20260112074538/https://www.bricklink.com/v3/studio/design.page ;
  LEGO® Account sign-in, https://brickset.com/article/124148 *(excerpt)* ;
  the live gallery showed only its outage page all day,
  https://www.bricklink.com/v3/studio/gallery.page
- [R8-MB] Mecabricks: https://www.mecabricks.com/ , a model page
  https://www.mecabricks.com/en/models/0Qa3x3lY2Mo , the selection
  https://www.mecabricks.com/en/library/selection , a profile
  https://www.mecabricks.com/en/user/instantea , sign-up
  https://www.mecabricks.com/en/signup
- [R8-BS] Brickset: https://brickset.com/ , https://brickset.com/faq , a set
  page https://brickset.com/sets/10497-1/Galaxy-Explorer , its contest
  https://brickset.com/article/136015 , sign-up https://brickset.com/signup ,
  apps https://brickset.com/tools/apps
- [R8-FL] Flickr: the LEGO® group https://www.flickr.com/groups/lego/ and its
  pool https://www.flickr.com/groups/lego/pool/ ; a photo page
  https://www.flickr.com/photos/127404146@N02/55659869943/ ; block and the
  home feed, https://www.flickrhelp.com/hc/en-us/articles/4404057922324 *(excerpt)* ;
  notifications, https://www.flickrhelp.com/hc/en-us/articles/4404377011476 *(excerpt)*
- [R8-LI] LEGO® Ideas (refused every reader; all excerpts): policies
  https://ideas.lego.com/agree_policies *(excerpt)* ; Staff Picks
  https://www.lego.com/en-us/service/help-topics/article/what-are-lego-ideas-staff-picks-and-how-are-they-chosen *(excerpt)* ;
  the code of conduct https://www.lego.com/en-us/legal/code-of-conduct *(excerpt)*
- [R8-PR] Printables: its public API, https://api.printables.com/graphql/
  (`competitions`, read twice today: 38 contests opened in 2026, median 218
  entries, largest 1,108; `print`), https://www.printables.com/model ;
  analytics, https://blog.prusa3d.com/revealing-the-new-detailed-analytics-on-printables_71849 *(excerpt)* ;
  no block, https://forum.prusa3d.com/forum/english-forum-general-discussion-announcements-and-releases/printables-com-feature-request-improved-filtering-block-or-hide-selected-user-and-their-models
- [R8-TV] Thingiverse: https://www.thingiverse.com/ ; its sale to
  MyMiniFactory (February 2026) and its AI labels, from 3D Printing Industry's
  and All3DP's news pages *(excerpt)*
- [R8-MW] MakerWorld: https://makerworld.com/en ; uploading,
  https://wiki.bambulab.com/en/makerworld/tutorials/how-to-upload-models ;
  AI policy, https://wiki.bambulab.com/en/makerworld/ai-policy *(excerpt)* ;
  profiles, https://forum.bambulab.com/t/137466 ; https://makerworld.com/en/faq
- [R8-SK] Sketchfab: https://sketchfab.com/3d-models/popular ; oEmbed,
  https://sketchfab.com/developers/oembed ; sharing,
  https://help.sketchfab.com/en/articles/16152737-sharing-models-online ;
  email notices, https://help.sketchfab.com/en/articles/16152184-editing-your-email-notifications
- [R8-GH] GitHub, configuring notifications:
  https://docs.github.com/en/subscriptions-and-notifications/get-started/configuring-notifications
- [R8-IG] Instagram's Restrict, mute, block and report guide:
  https://about.instagram.com/blog/tips-and-tricks/restrict-mute-block-report-guide
- [R8-RV] Ravelry, faves, queue, library and stash:
  https://blog.ravelry.com/thursday-tip-faves-queue-library-shopping-cart/ *(excerpt)*
- [R8-SP] Field speed of the other sites (Chrome's users, by origin):
  https://treo.sh/sitespeed/ (per domain)
- [TK-TL] Discourse, trust level permissions reference (what a new
  account may not do yet): https://meta.discourse.org/t/trust-level-permissions-reference/224824 ;
  https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/
- [TK-FL] Discourse, flags and hidden posts:
  https://meta.discourse.org/t/what-happens-when-you-flag-a-post/275 ;
  https://meta.discourse.org/t/what-are-flags-and-how-do-they-work/32783
- [TK-NL] Discourse, notification levels (Watching, Tracking, Normal, Muted):
  https://meta.discourse.org/t/configuring-default-notification-settings-for-users/285619
- [TK-DL] Discourse, launching a community (seed topics, go first, invite
  early repliers): https://blog.discourse.org/2018/08/launching-a-successful-discourse-community/ ;
  https://blog.discourse.org/2014/08/building-a-discourse-community/
- [TK-MS] MIT Sloan Management Review, "The Secret to Successful Knowledge
  Seeding": https://sloanreview.mit.edu/article/the-secret-to-successful-knowledge-seeding
- [TK-DF] Google Search Central, discussion forum (DiscussionForumPosting)
  structured data: https://developers.google.com/search/docs/appearance/structured-data/discussion-forum
- [TK-EB] Eurobricks, its forums, [MOC] topics and per-forum RSS:
  https://www.eurobricks.com/forum/forums/topic/179720-moc-sites/ ;
  https://www.eurobricks.com/forum/forums/forum/7-community.xml/
- [TK-RB] Brickset, interview with Rebrickable's founder (MOCs, the forum):
  https://brickset.com/article/111720/interview-with-nathan-thom-founder-of-rebrickable
- [TK-MB] Mecabricks' forum, as cited by builders' blogs: https://blog.firestartoys.com/?p=1139 *(excerpt)*

### Round 11, the home feed (2026-11-23)

Read on 2026-11-23. MakerWorld, Printables and Thingiverse answered 403,
Rebrickable 402 and BrickLink its maintenance page, so claims about them
rest on their help pages, blogs and press; *(excerpt)* marks a search
result's text alone.

- [HF-IG] Instagram: Following and Favorites, https://about.instagram.com/blog/announcements/favorites-and-following ;
  suggested posts, https://help.instagram.com/381638392275939 ; the sign-in
  wall, https://thenextweb.com/news/instagram-now-forces-people-to-sign-in-to-view-public-profiles
- [HF-PI] Pinterest: the home feed, https://help.pinterest.com/en/article/explore-the-home-feed ;
  saving, https://help.pinterest.com/en/article/save-pins-on-pinterest ; the
  sign-up modal test, https://medium.com/@Pinterest_Engineering/lessons-in-growth-and-increasing-signups-d6e7d8fef479 *(excerpt)*
- [HF-RD] Reddit: For You and Following, https://techcrunch.com/2026/10/28/reddit-is-the-latest-platform-to-embrace-the-for-you-feed/ ;
  the logged-out landing, https://techcrunch.com/2023/08/01/reddit-updates-its-site-design-for-logged-out-users/ ;
  login-wall tests, https://www.ghacks.net/2026/05/13/reddit-tests-forcing-logged-out-mobile-users-into-app-with-non-dismissible-pop-up/
- [HF-PR] Printables: Open in PrusaSlicer, https://help.prusa3d.com/article/opening-models-in-prusaslicer-from-supported-websites_399198 ;
  the community feed, https://blog.prusa3d.com/new-on-printables-com-community-feed-improved-search-new-rewards-and-more_69067/
- [HF-MW] MakerWorld: one-step printing, https://blog.bambulab.com/makerworld-one-step-printing ;
  Open in Bambu Studio, https://forum.bambulab.com/t/noob-question-about-print-profiles-from-mw/90714 ;
  boosts, https://blog.bambulab.com/rethinking-rewards-makerworld-boost-system
- [HF-TV] Thingiverse: Customizer, https://www.thingiverse.com/apps/customizer/ *(excerpt)* ;
  the 2020 redesign, https://all3dp.com/4/thingiverse-gets-a-new-design-and-introduces-ads/
- [HF-RB] Rebrickable: https://en.wikipedia.org/wiki/Rebrickable ; sharing a MOC,
  https://bricknerd.com/home/mastering-rebrickable-a-guide-to-sharing-mocs-and-instructions-1-10-25
- [HF-MB] Mecabricks: https://www.mecabricks.com/ , https://www.mecabricks.com/en/library/selection ,
  a model page https://mecabricks.com/en/models/VzvMRWy7aJp
- [HF-BL] BrickLink Studio: access levels, https://studiohelp.bricklink.com/hc/en-us/articles/5705436653847 ;
  the Welcome Screen's gallery, https://studiohelp.bricklink.com/hc/en-us/articles/6153755149591
- [HF-FL] Flickr: the LEGO® group's pool, https://www.flickr.com/groups/lego/pool/ ; Explore,
  https://blog.flickr.net/?p=91697
