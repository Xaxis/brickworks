# One loop: the best LEGO® CAD and the best LEGO® social space

Written 2026-11-23 by masterplan, against live brickworks.diy (rel-m318,
main `fe9e7bc59`) and `pre261` at `d52d92f0a`. The owner asked on 23
November: "do a full analysis of how to make our platform not only the best
CAD but best social lego space with amazing intuitive features and elegant
and then execute it all perfectly".

Eleven app rounds ([APP_UX11.md](APP_UX11.md), the scorecard in
[COMPETITIVE.md](COMPETITIVE.md)) and eight site rounds
([SOCIAL.md](SOCIAL.md)) each planned one side. This is the plan for the
whole: the loop a person goes round, where each step stands against the best
there is, and what joins the CAD to the community at each step. Its units
are at the end; the first ten are briefs ready to spawn.

## The answer, short

- **The CAD is ahead.** 78 of 98 cells against six tools (COMPETITIVE.md, 20
  November). Its 9 behinds each have a unit or are the owner's to unpark.
  What is left on the CAD side is how it feels to use, which ux12 is fixing
  in code now.
- **The site has a community's parts and nearly nobody in it.** Read on 23
  November at 03:19Z (`/api/share?op=list`, three pages): 50 models, 49 of
  them the house's. The first model a person outside the house ever shared
  came at 02:51Z today: BrickManBill's Cape Hatteras Lighthouse, 1,320 parts,
  designed with the assistant. Across all 50 models: 0 likes, 0 comments, 0
  remixes, 1 build, 25 views. Microscale, the open challenge, has 0 entries
  with 7 days left, and Haunted house before it closed with 0.
- **What is missing is not another feature on either side. It is the joins.**
  Every rival is one half. Studio, Mecabricks and Kinebrick are CADs with a
  gallery or none. Printables, MakerWorld, Rebrickable, LEGO® Ideas, Flickr,
  Reddit and Eurobricks are communities whose models are pictures or files
  opened somewhere else. Brickworks holds the model as data (parts, steps,
  joints, versions) in the same place people meet. So at every step of the
  loop, the act on one side can land the person on the other, counted and
  checked, which none of them can do.
- **The joins are also the ways in.** Build it needs no account. A real set's
  page is where search sends people. The assistant made the first outside
  share. Each of these ends today without asking the person to do the next
  thing in the community: show their build, build something else from the
  set, change the model with their own Claude.
- **The plan: 20 rows in three waves.** The first ten are briefs in
  `bench/results/lead-2026-11-05/briefs/`. Wave 1 is five units that share no
  file with the four running now (homefeed, ux12, photoreal8, wholekeep),
  and with each other only a block each in the model's page.

## The loop, step by step

```
  discover --> open --> change --> build it for real --> share --> hear back --> come back
     ^                                                                              |
     +------------------------------------------------------------------------------+
```

Each step is graded against the best of either side for that step:
**best** (nobody does it better), **level**, or **behind** (someone does a
thing at this step that a person would reach for and Brickworks does not).
"Live" is brickworks.diy today. "pre261" is merged and rides rel-m319 or
rel-m320. The evidence is in the walk below and in the sources.

| Step | What a person does | Brickworks live | On pre261 | The best elsewhere | Grade |
|---|---|---|---|---|---|
| 1. Discover | finds something worth opening | a gallery of 50 models, 49 the house's; search; Top, New, Following, Builds, Collections; 1,576 real sets in 3D; the first model 2,380 px down a phone's home page | Talk (the forum); the challenge with honours; models that turn in link previews (turntable); homefeed (running) makes the home the feed | Flickr's LEGO® pool: 650,132 photos [fl-pool]; MakerWorld's For You [R8-MW]; Rebrickable ranks every set and MOC by how much of it you own [rb-search] | **behind** on people; level on the machinery |
| 2. Open | opens it to look, turn, step through | 3D on the page; Build it with no account; Open in Brickworks (a copy); Download; parts lists for three shops; an embed | the same | MakerWorld opens a model in Bambu Studio with a tested print profile [mw-faq]; Printables sends a model to PrusaSlicer [pr-slicer]. Both need an install; Brickworks opens the CAD in the same tab | **best**, on a phone and a laptop alike: the walk stepped through a 244-step model signed out in 20 s on both. Slow against the native phone builders, which open at once: on WebKit as an iPhone 13 the app's first visit takes 20.3 s and a return 15.3 s (COMPETITIVE.md, 20 Nov), and webstart13 did not reach its 15 s and 8 s (queue.md, 22 Nov) |
| 3. Change | makes it theirs | the CAD (78 of 98 cells ahead); remixes credited (`remixed_from`); versions that say what changed; Together, live by a link | the same, and mcpreach4's fuller answers for the person's Claude | Onshape: comments pinned to geometry, a version graph that branches and merges, follow mode [on-comments] [on-versions] [on-follow]; Kinebrick 0.3.0's physics [kb-030] | **best** as a CAD; **level** as a join: a remix does not say what it changed, and feedback never reaches the CAD |
| 4. Build it for real | builds it with real bricks | the step player, the booklet as a PDF, BrickLink, Rebrickable and Pick a Brick lists, Use what I own, What can I build, Build with what I own across the gallery | partstep: a part held finds its step, by photo or search | Rebrickable: Build % from your own parts on every model, Missing Parts, Buy Parts, and alternate builds of a set with an Alt badge, "by far the most popular MOCs to build" [rb-build] [rb-alt] | **behind** Rebrickable on alternates, and on the share you own shown on every card with only the missing parts to buy (the gallery sorts by Parts I own, signed in); **level** on the rest |
| 5. Share | shows what they made | publish from the studio: picture, file, steps, parts, versions, Tested, Based on; the share sheet; oEmbed in 3D | Share from a file on the site (bringyours); a model's link turns where it is pasted (turntable) | Printables: makes on the original's page, 9,830 on Benchy, each earning its maker points [pr-benchy] [pr-points]; MakerWorld: anyone can add their print profile to a model [mw-faq] | **level** live, **best** on pre261 for one's own model; **behind** on makes: a build of someone else's model is shared from a web page, never where the build finished |
| 6. Hear back | learns that someone saw, liked, built or answered | 11 kinds of notification, comments with replies, @mentions and comments on a step, a daily email by choice | push on the phone (homescreen); a designer's numbers against last month (insights2) | Onshape's comments pinned to a part, with @mention and Assign to [on-comments]; Eurobricks' juries explain their top three [eb-tc25]; r/LegoMocHelp for critique [rd-moc] | **level**; **behind** on where feedback lands: never in the CAD, beside the part it is about |
| 7. Come back | has a reason to return | a monthly challenge (0 entries in two); achievements with levels; the Following feed | challengehonours: a shortlist, a fan vote, honours; push | Instagram's habitats: one minifigure habitat on an 8×8 base, 2,605 by 330 builders in one run [ig-habitat]; #24daysofbrickmas: a prompt a day and a streak [ig-brickmas]; LEGO® Ideas' supporter clock: 100 in 60 days, then 365, 182, 182 [li-guide]; Printables runs about 30-day contests with hundreds of entries [pr-contest] | **behind** |

In short: open and change are the best there is; share is the
best on pre261 for one's own work; hear back is level; and three steps are
behind where it matters most: discover (no people's work), build it for
real (alternates and what you own), and come back (no small, frequent
reason). The behinds share one cause, the one docs/SOCIAL.md named on 20
November: the site has one designer. The plan answers it with joins that
turn the traffic the site already gets (set pages, Build it, the studio,
the assistant) into people's work on the site.

## The walk, as people meet it

On live brickworks.diy, signed out, read-only, through `heavy` in Chromium on
SwiftShader: a stranger on a phone (390 × 844, touch) and a builder on a
laptop (1280 × 800), each step a screenshot. Every request that was not a
read was refused in the browser, so no view, build or visit was counted.
The script and the pictures: `bench/results/masterplan-2026-11-23/`
(`walk.mjs`, `walk/`).

The walk ran at 03:35-03:47Z on 23 November.

**A stranger on a phone.**

| Step | What they met | Picture |
|---|---|---|
| The home | "A CAD for LEGO® models, in your browser", Start building and Explore the gallery. No model, builder or search in the first screen; the first models are on the fourth (the page is 8,081 px). The beta's bar (Beta · Report a bug · Join · ×) covers the foot of this and every page | [home](img/masterplan/p01-home.webp) |
| The gallery | a search, Top · New · Builds · Collections · Sets, the challenge in a line, cards with Week's pick, Tested, Like and Save. 49 of the 50 models are the house's | [gallery](img/masterplan/p04-gallery.webp) |
| A model (the first a person shared) | its picture, View in 3D, the maker and Follow, **Build it**, Open in Brickworks, Download, and Like, Save, Share, Comment, Built, all in the first screen; "With the assistant", "Moves: turntable", Version 2. Further down, Builds offers "I built it: add a photo" and Remixes "Open it in Brickworks"; no comments | [model](img/masterplan/p06-model.webp) |
| Build it | the step player, signed out, in 20 s on SwiftShader: Step 1 of 244, One part · Whole step, Back · Next, and Comment once the step's comments loaded. No account, no install | [build it](img/masterplan/p15-build-3.webp) |
| Open in Brickworks | the studio, under "Sign in to start building" (an emailed code or orangecheck), and behind the dialog the example car, not the lighthouse they asked to change. Whether the copy opens after the code was not tried: this walk signs in as nobody | [the door](img/masterplan/p16-remix.webp) |
| The challenge | Microscale: "No rules but the brief", "No entries yet: be the first", 7 days 20 hours left, Enter a model | [challenge](img/masterplan/p10-challenge.webp) |
| The feed | "Your feed", Sign in, and two people to follow: Brickworks and BrickManBill | — |
| Talk | 404, "This brick is missing.": Talk is on pre261 and rides rel-m320 | — |

**A builder on a laptop.** The same pitch first, the header Gallery, Docs,
Plans, Open the app, Sign in. The gallery shows four cards in its first
screen. A model's page holds every act in its first screen, the picture
beside them ([model](img/masterplan/l06-model.webp)). Build it opens in 20 s,
the view the whole width and the step's parts and buttons in a centred
column under it. Open in Brickworks draws the whole studio behind the sign-in dialog,
with the example car on the baseplate ([the door](img/masterplan/l16-remix.webp)).

**What the walk says.**
- **Open is the best there is.** A stranger steps through a 244-step model
  in 20 s with no account and nothing installed, on a phone and a laptop.
  Nobody else does that: MakerWorld and Printables send you to a desktop
  slicer, Mecabricks to its editor, Rebrickable to a PDF.
- **The act that makes a visitor a maker stops at a door.** Open in
  Brickworks asks for an emailed code first, and the model they asked to
  change is not behind it. Everyone signs in to use the studio by the
  owner's rule (2026-10-11); homefeed's Try it card is the one signed-out
  studio planned. firstminute (row 11) keeps the rule and makes the door
  come back to the asked-for copy, unless the owner opens the studio to
  strangers until their first save.
- **The community is the house.** Every card but one, the feed's two
  suggestions, and the challenge's empty state all say so. The ways in
  that turn existing traffic into people's work (makes, altbuilds, prompts,
  claudelink) come before anything that needs a crowd.
- **A stranger meets a tool before anybody's work.** homefeed, running,
  makes the home the feed.
- **A friction for the running units**, said to the lead: the beta's bar
  covers the foot of every page at 390 (the gallery's cards, the model's
  share row, the challenge's countdown) until it is closed.

## The best of each side, from their own pages

Read on 22 and 23 November 2026. Each line is a thing the site or tool does
best at a step of the loop, with what Brickworks takes from it.

**The CADs**

- **BrickLink Studio.** It searches by what connects (`=compatible("<ID>")`,
  "Find compatible bricks") [st-find]. It gives a stability zone under each
  connected group [st-stab], prices and available colours while you pick
  [st-price], and Divide into Steps [st-steps]. A Studio Gallery design opens
  inside Studio, if its designer allowed the download [st-gal]. BrickLink
  itself has served a maintenance page since 19 November. *Brickworks has
  Fits in the parts bin, Stress and Swing, the booklet and the gallery; it
  takes nothing new here. Prices stay parked (BrickLink's keys are the
  owner's).*
- **Mecabricks.** It runs in the browser, "no plug-in, no installation"
  [mb-home]. A model's page links straight to its Editor, and anyone can drop
  their own renders on it [mb-model]. It has no forks, no follows and no
  co-building: real-time shared building is unlikely "anytime soon (if
  ever)" [mb-forum]. *Brickworks is ahead on each.*
- **LDCad 1.7 Beta 2b** has hoses, bands and springs drawn live, snap metas
  and Lua animation [ld-adv] [ld-script]. **LeoCAD 26.09** has the Minifig
  Wizard, a timeline pane and a trackball gizmo [lc-2609]. *Level or behind
  Brickworks in every row.*
- **Kinebrick Studio 0.3.0** (20 November; 0.4.0 on 22 November lists no
  changes) [kb-030] [kb-040] adds gravity, friction and contact, cams, Geneva
  drives, pneumatics, wired electrics, Pybricks, and a camera track. Gears
  mesh as they snap, and snapping can follow Studio's or LDCad's habits.
  It has no community; Kinebrick Play shares a model as a link [kb-play].
  *Its physics is kinefuncs2, parked by the owner; the wiring is wires'.*
- **Onshape and Fusion**, for the feel. Onshape has live co-editing and follow
  mode: double-click a collaborator to see what they see [on-follow]. It
  pins comments to geometry, with @mention and Assign to [on-comments], keeps
  a version graph of branches and merges [on-versions], gives view-only
  links that need no sign-in [on-share], and puts a toolbar at the cursor on
  S [on-keys]. Fusion pins comments on points and objects with a snapshot of
  the view [fu-comment], and its timeline marker shows the design at any
  point [fu-timeline]. *Brickworks has Together (live, each with their own
  undo, point at a part), the command palette and the steps bar. What it
  lacks is the comment pinned to the part, landing in the CAD: partpins.*

**The communities**

- **LEGO® Ideas.** Supporter milestones on a clock (100 in 60 days, then
  1,000 in 365, 5,000 in 182, 10,000 in 182). Review three times a year. A
  1% royalty. Entries of 200 to 5,000 pieces, at most 15 images, no text on
  the main image, Studio renders accepted. One moderated update every 30
  days, and an update cannot change what the idea is [li-guide]. Challenges
  and quick Activities beside the ideas [li-how]. *Brickworks cannot make
  sets. It can make a model ready for Ideas, checked against those rules
  (postkit), and it can take the quick Activity (prompts).*
- **Rebrickable.** The Build Engine and Build Search score your Build % for
  every set and MOC, with one to three what-if sets [rb-engine] [rb-search].
  "Build this MOC" shows what you have and what is missing, with Buy Parts
  [rb-build]. Alternate builds from one set get an Alt badge (partial: up to
  5 sets) and are listed on the set's own page [rb-alt]. Fan Photos of other
  people's real builds, and a dated MOC Timeline [rb-fan]. Levels unlock
  acts [rb-levels]. *Brickworks has Build with what I own across the
  gallery; it lacks the alternates (altbuilds) and the missing-only list
  (ownedparts).*
- **Flickr's LEGO® groups.** The LEGO Pool holds 650,132 photos from 21,668
  members since 2004 [fl-pool]. Explore ranks about 500 photos a day on the
  quality of interaction, "a meaningful comment may weigh more than multiple
  quick faves" [fl-explore]. LUGNuts ran 120 numbered monthly challenges
  [fl-lugnuts]. *Volume Brickworks cannot copy; makes and prompts are how
  photos and small builds arrive.*
- **Reddit r/lego and r/legomoc.** r/lego allows at most one post in ten
  that can earn its poster money [rd-rules]. r/legomoc has MOC and SEC flairs
  (someone else's creation, designer credited) and allows "one or two" WIP
  posts per MOC; critique goes to r/LegoMocHelp [rd-moc]. Reddit takes no new
  API apps since 31 October (docs/SOCIAL_DESK.md). *What a builder takes to
  Reddit should already be in Reddit's form, credited, with the link back
  (postkit); WIP belongs in Brickworks' own log (buildlog).*
- **Instagram.** At most 5 hashtags a post since December 2025 [ig-tags].
  Community challenges run there by hashtag: habitats on 8×8 bases stacked
  on a "stack day" [ig-habitat], #24daysofbrickmas with a prompt a day and a
  streak [ig-brickmas]. *Prompts, with the stack made as a real model.*
- **Eurobricks.** Forums by theme, WIP threads, contests whose public vote
  (10-6-4-3-2-1 over six picks, voters with 50 posts, no self-votes) feeds a
  jury [eb-tc20], and juries that explain their top three [eb-tc25]. *Talk is
  the forum; challengehonours has the shortlist and the vote.*
- **Brickset.** Own and Want on every set, inventories that say how many of
  each part you own, and Rebrickable sync [bs-faq]. Reviews rated on five
  axes with helpful votes: 40,886 reviews, 406,811 active members [bs-rev].
  *Brickworks has Own and Want on 1,576 set pages and no reviews
  (setreviews, wave 3).*
- **MakerWorld.** Open in Bambu Studio. A print profile is a file with the
  settings, and anyone can add one; profiles rank designer, official, then
  others by rating, and can be rated only after printing. Remixed by. Boost
  tokens, up to 3 a week, earned by use, 12 points to the designer each.
  Contests on countdowns [mw-faq] [mw-model] [mw-boost] [mw-contest]. *The
  print profile is the idea worth taking: something a person who built it
  adds to the original (a make, a remix, a part swap), ranked under it.*
- **Printables.** Makes and comments, remixes, collections and a "Model
  origin" block on every model [pr-benchy]. Prusameters for downloads, likes
  and makes, capped and never for your own model; 350 buy a spool
  [pr-points]. A feed of uploads, makes and collections from people you
  follow [pr-feed]. Open in PrusaSlicer [pr-slicer]. Contests with entry
  counts and a jury [pr-contest]. *Makes where the build ends (makes), and
  the remix both ways with what it changed (remixdiff).*

## What only Brickworks can do

Each comes from one fact: the model is data in the same place people meet.

1. **Build % and alternates counted, not typed.** Rebrickable's designers
   type their inventories in. Brickworks reads every model's needs at
   publish (`model_needs`) and has 1,576 sets' inventories. Whether a model
   is an alternate build of a set, and how much of it a person owns, can be
   worked out for every model at once (altbuilds, ownedparts).
2. **What a remix changed, part by part.** Printables writes "remixed from"
   in words. The app's Compare already counts what was added, taken away,
   moved and recoloured between two versions (`open_model versions=true`).
   A remix's page can say it and show it in 3D (remixdiff).
3. **Feedback on the part, seen in the CAD.** Onshape pins a comment to
   geometry, but Onshape has no community. A comment pinned to a brick on
   the model's page can light that brick in the designer's studio
   (partpins).
4. **A challenge's rules checked while you build.** Every contest checks
   entries after the fact. Brickworks already checks a challenge's rules on
   the stored model (`most_parts`, `set`, `tested`). It can check them live
   in the studio and enter from Publish (challengestudio).
5. **A stack day made as a model.** Instagram's habitats are stacked as a
   collage of photos. Brickworks can stack every entry's file into one model
   that anyone can turn and build (prompts).
6. **Your own Claude, handed the model.** No other community has a designer
   that can open a model from its link and change it: `open_model link=`
   does it today, and the first outside share came from it. A model's page
   can hand the person's Claude the model in one tap (claudelink).
7. **Build it to a make, with no account until the photo.** Printables'
   makes are posted from a web page after printing. Brickworks' step player
   knows the moment the last step is done, on the person's phone, beside its
   camera (makes).
8. **A model's whole life in one place.** Versions with what changed, a
   build log, the booklet, Play, Together, the real set it came from: none
   of the communities has the file's history; none of the CADs has the
   people (buildlog).

## The joins, step by step

| Step | The join today | The join missing | Unit |
|---|---|---|---|
| Discover → open | a card opens the model's page; Build it and Open in Brickworks on it | every card carries the CAD's verbs and a model turns on the card | homefeed (running) |
| Discover → build for real | a set's page: Own, Want, 3D, Build it | "Other builds from this set": the alternates people made, each with how much of the set it uses | altbuilds |
| Open → change | Open in Brickworks makes a copy, credited when published | "Change it with your Claude": the person's own Claude opens the copy and changes it as asked | claudelink |
| Open → change, for a stranger | Open in Brickworks asks for an emailed code, and the example car is behind the door (the walk) | the door comes back to the asked-for copy, open and ready; or, if the owner allows, the copy opens first and the account is asked at the first save | firstminute |
| Change → share | Publish; Based on; versions | a remix says what it changed, in words and in 3D, and the original shows its remixes as a tree | remixdiff |
| Change → share, while building | nothing: a model is shared when finished | work in progress shared by version, followed, and kept as the model's log | buildlog |
| Build for real → share | "I built it" photos, from the model's page only | the step player's last step asks for the photo, where the build is | makes |
| Share → hear back | comments, on the model or a step | comments pinned to a part, lighting it in the designer's studio | partpins |
| Share → outside → discover | the share sheet; link previews that turn (pre261) | a kit in each community's own form and rules, each carrying the link back | postkit |
| Come back → change | a monthly challenge, checked after publishing | a weekly quick build with a template that opens in the studio, and the stack at its end | prompts |
| Come back → share | Enter on the challenge's page | the rules ticked live in the studio, and Enter from Publish | challengestudio |
| All of them | the visit funnel in /admin (6 counted visits since 19 Nov) | the loop measured step by step on real people, so each unit's bar can be read after it ships | loopmetrics |

## Intuitive and elegant: what every unit keeps

The owner asked for "amazing intuitive features and elegant", not more
buttons. Each unit below keeps these rules, and its review checks them.

1. **The act where the person already is.** Show your build where the build
   finished. Enter where the model is made. Answer feedback beside the part.
   A unit that adds a page a person must go to has not found the join.
2. **The CAD's verbs, in one order, everywhere a model is shown:** Build it ·
   Open in Brickworks · Parts · and, where it fits, Change it with your
   Claude. Never a new name for an existing act.
3. **Never a dead end.** An empty state names the next act and opens it. A
   challenge with no entries opens its template; a set with no alternates
   asks for the first.
4. **Signed out works until it must not.** Looking, turning and Build it
   need no account. Sign-in is asked at the first act that needs
   it, in place, and comes back to the same step with nothing lost (the
   photo still chosen, the comment still typed).
5. **Subtract before adding.** Reuse what exists: the build photos' path, the
   comments' table, Compare, the challenge's rules, the share sheet, the
   collection's sums. A new button must take one away or carry an act
   that had none.
6. **One design system.** The site's shared components and
   docs/DESIGN_SYSTEM.md, looked at 390, 768 and 1280 in light and dark. In
   the app, a new panel in the app's own style; nothing restyled.
7. **Counted and checked, never asserted.** A number on a page (87% of the
   set, 42 parts added) comes from the same code the app uses, proven equal
   by a test on real files.
8. **Proven twice.** First by the unit's own bars. Then, after the deploy, by
   loopmetrics on real people: the share of people who reach the unit's
   step, this week against last.

## The units, ranked, in waves

Ranked by what each does for the loop, given that the site has one designer.
A join that turns the traffic the site already has into people's work
outranks one that serves a crowd it does not have yet. Waves follow what
each waits on and which files it owns. **Size** is hours of a unit's own
work, not counting a full train's queue. **Review** means one independent
review before merging (it touches accounts, people's data, the database or a
save path), with SQL additive only and applied by the lead. Briefs 1 to 10
are in `bench/results/lead-2026-11-05/briefs/brief_<name>.md`.

**Not planned here, because they are running or in flight:** homefeed (the
home as the feed), ux12 (the app's friction), photoreal8 (renders like real
plastic), wholekeep (a whole save keeps what it carried); stepkeep2, the
siofix/studioio line, texkeep, webstart13's proofs, design30, exactfix,
smalls11, and the wires fixes, as `queue.md` has them. **Parked by the
owner:** payments and prizes in money, desktop downloads, BrickBench
submissions, new languages, provider API keys, kinefuncs2 and buildorder2,
BrickLink's keys and prices, posting from a real social account.

| Rank | Unit | Wave | Size | Review | Why (the step it joins) | What | Bar, measured | Waits on |
|---|---|---|---|---|---|---|---|---|
| 1 | **makes** | 1 | 6 h | yes | Build it → share. Build it needs no account and set pages bring the traffic; today the last step ends with a count and nothing to do | "Built it? Show it" at the step player's and the viewer's last step: a photo from the camera or a file and a line, posted through the build photos' own path; sign-in in place if needed, back at the last step with the photo kept; the designer hears | last step to posted photo in ≤ 3 taps after the picture, at 390 touch and 1280 and on desktop; on the model's page and the designer's bell within 60 s; signed out, back at the last step with the photo still chosen 10 of 10; metadata stripped, the 480 px card copy, 13+ and `may_act` as today | nothing (rebase on ux12 if it merges first: it may touch `build_mode.gd`) |
| 2 | **altbuilds** | 1 | 6 h | yes | Discover → build for real. Rebrickable's alternates are "by far the most popular MOCs to build"; set pages are where search sends people | every listed model checked against every set's inventory with the app's own rules: "An alternate build of 31009 Small Cottage: every part from the set", or the share of 2 to 5 sets; the set's page lists the models built from it | the share equals the app's Collection check on 20 pairs exactly; no false alternate on 50 hand-checked pairs; every alternate the library holds is found; publish ≤ 300 ms slower at p95; the whole gallery backfilled in ≤ 5 min; the set page's LCP no worse at 390 and 1280 | nothing |
| 3 | **prompts** | 1 | 8 h | yes | Come back → change. Small, frequent builds bring the most people in (2,605 habitats by 330 builders) | a weekly quick build, a challenge of a new kind: a brief, a template that opens in the studio on one tap, entered from Publish, no vote; at its end every entry stacked into one model anyone can open and build; a streak on the profile | Start to the template on the baseplate within the studio's own open time + 2 s; entered in one tap more than a plain publish; the stack holds every entry's parts (the sum, by a test) and opens in the viewer; never empty (the house's two entries a week, dated, as Brickworks); challenges_flow passes | nothing (challengestudio waits on it) |
| 4 | **claudelink** | 1 | 3 h | no | Open → change. The first outside share came from the assistant; no other community has one | "Change it with your Claude" on every model's page: copies a ready message for the person's own Claude (`open_model link=`), or opens the connect page with it kept; the remix published from it is credited | on 3 gallery models a Claude Code session given only the copied message opens a copy, changes it as asked and publishes it with `remixed_from` set, through the connector, instructions none, in ≤ 12 calls each; the control at 390 and 1280, both themes, de/fr/es | nothing |
| 5 | **loopmetrics** | 1 | 3 h | yes (reads people's numbers) | every step: the plan's bars need people, and the funnel stops at publish | /admin › Analytics › The loop: each step's people this week and last, by the week they arrived, from what is counted today (nothing new counted) | each number equals a hand count on a fixture of known rows (a test); answers in ≤ 1 s; the checks' accounts and pool left out; no new table of a person's data | nothing |
| 6 | **partpins** | 2 | 8 h | yes | Hear back → change. Onshape pins comments to geometry; nobody brings a community's comment into a CAD | a comment pinned to a part on the model's 3D view; the designer's studio lights the part and lists the pins; Resolve shows on the site; a pin follows its part to later versions or says which version it was on | 100 of 100 taps pin the part under the finger on 5 models at 390 and 1280; on 20 version pairs no pin lands on a wrong part; the studio lists the same pins as the site; comments_flow, mentions_flow and block_flow pass | makes (`share_view.gd`) |
| 7 | **remixdiff** | 2 | 6 h | yes | Change → share. Printables says "remixed from" in words | the remix's page says what it changed from the version it was copied from (added, taken away, recoloured, moved), "What changed" lights it in 3D, and the original's Remixes tab draws the tree both ways | the counts equal the app's Compare on 12 remix pairs exactly; publish ≤ 200 ms slower at p95 on 1,000 parts; the 3D view lights exactly the added parts (a mask test); a chain of three drawn; share_probe passes | claudelink (`web/model-page.js` block) |
| 8 | **challengestudio** | 2 | 6 h | no | Come back → share. Entering today means building in the app, then finding the page | while a challenge or a week's prompt is open, the studio ticks its rules live on the model and Publish enters it; the fan vote shows two entries side by side in 3D, blind | the studio's ticks agree with the site's check on 30 models × 3 rules, 90 of 90; Enter one tap more than a plain publish; the pill never over the model at 390; the vote pair's LCP no worse; the vote stays blind (no maker in the pair's page) | prompts (`api/_challenges.js`, `web/challenge.js`) |
| 9 | **postkit** | 2 | 6 h | no | Share → outside → discover. People are on Reddit, Instagram, Flickr and LEGO® Ideas, each with its own rules | "Post it elsewhere": a kit for each, in its form, its rules checked, the link back in each: r/legomoc (flair, images, credit), Instagram (1080 × 1350, a 9:16 turn, ≤ 5 hashtags), LEGO® Ideas (200-5,000 pieces, ≤ 15 images, no text on the main one), Rebrickable (CSV and booklet), Flickr | each kit passes its destination's rules by a test citing the rule's page; made in ≤ 60 s on desktop at Best for a 500-part model; Brickworks posts nothing itself; de/fr/es | turntable (merged) |
| 10 | **buildlog** | 2 | 6 h | yes | Change → share while building. r/legomoc allows one or two WIP posts; Rebrickable keeps a dated timeline | a model's versions as its Log; Share progress from Publish sends a work-in-progress version to followers and grows one Talk thread per model, a post a version with what changed; Finished ends it | a WIP in a follower's feed and its Talk thread within 60 s; the next WIP adds one post, not a thread, with what changed equal to Compare; Top never lists a WIP (a test on the ranking); talk_flow and the feed's flows pass | talk (merged), remixdiff (`web/model-page.js`) |
| 11 | **firstminute** | 2 | 5 h | no | Discover → open → change. The funnel: 2 of 6 visits opened the studio, 1 put a part down, 0 saved; the walk: Open in Brickworks asks a stranger for an emailed code, and the model they asked for is not behind the door | the door comes back to the asked-for copy, open and ready, with three first acts offered (recolour, add a part, Build it); if the owner opens the studio to strangers until their first save, the copy opens at once and the account is asked at that save, nothing lost | a stranger in the walk at 390 and 1280 from Open in Brickworks to a saved change in 3 minutes or less, the asked-for model on the baseplate after sign-in 10 of 10; loopmetrics' "put a part down → saved" share up beyond the week's noise | ux12 (the app's start and sign-in), loopmetrics (its second bar) |
| 12 | **webstart14** | 2 | 8 h | no | Open, on a phone. webstart13's runs under load: an iPhone's return 19.5 s and first visit 23.8 s, against 8 s and 15 s | the 124-script cycle cut that webstart13 named, so the first screen compiles less; Wasm under 300 MB | webstart13's bars: an iPhone's return ≤ 8 s, its first visit ≤ 15 s, Wasm ≤ 300 MB, same-moment pairs | webstart13's proofs; its brief is the lead's, written from webstart13's report |
| 13 | **ownedparts** | 2 | 5 h | yes | Build for real. Rebrickable's Build % on every card | as docs/SOCIAL.md rank 5: "You have 87%" on cards, the Parts tab's missing-only BrickLink and Pick a Brick lists | as SOCIAL.md rank 5 | lists2a |
| 14 | **lists2a** | 2 | 4 h | yes | Discover. One Save, Lists by name | as docs/SOCIAL.md rank 8 and docs/LISTS.md section 5 | as SOCIAL.md | nothing |
| 15 | **inbox** | 2 | 4 h | yes | Hear back. Each kind by email, push or not at all | as docs/SOCIAL.md rank 7 | as SOCIAL.md | homescreen (merged) |
| 16 | **watchlive** | 3 | 10 h | yes | Change → discover. Onshape's follow mode, as a show: people watch a model being built | Building now: a designer opens a session to watchers, listed on the home feed; watchers see parts land in the light viewer, read-only, and comment; it ends as a replay | a part reaches 10 watchers in ≤ 1 s at p95; a watcher's edit refused at the relay; listed within 10 s; 13+, block and report hold; bytes per watcher-minute measured against the Supabase egress budget | partpins, buildlog |
| 17 | **suggestedit** | 3 | 10 h | yes | Change → change. Onshape merges a branch back | a remixer sends their change back; the designer sees it as Compare in the studio and takes all or part; the taken change credits the remixer in Versions | a suggestion of each edit class taken whole or in part gives the same model as the remixer's (by a test); credit in Versions; nothing taken without the designer's tap | remixdiff |
| 18 | **setreviews** | 3 | 6 h | yes | Build for real → hear back. Brickset's 40,886 reviews on five axes | a real set's page takes a review on five axes, with helpful votes, and a note can be pinned to a step of its booklet | the five axes and helpful votes as Brickset's; a step note opens the step; seo carries Review JSON-LD; reports and blocks hold | partpins |
| 19 | **commentcare** | 3 | 6 h | yes | Hear back. Pin a comment and a build photo; held words | as docs/SOCIAL.md rank 10 | as SOCIAL.md | makes, partpins |
| 20 | **APP_UX11 wave 3** | 3 | 6-8 h each | as planned | the CAD's remaining behinds | pilescan (measured first), smalls13, pybricks, twobuilders, as docs/APP_UX11.md ranks 8 to 12 | as APP_UX11.md | as APP_UX11.md |

**The waves.** Wave 1 is makes, altbuilds, prompts, claudelink and
loopmetrics: five units with no file in common but one block each in
`web/model-page.js` for altbuilds and claudelink (makes is the app's step
player and the build photos' path; altbuilds the sets' and needs' API, the
set page and a line under the model's credit; prompts the challenges' API,
page and console; claudelink a choice in Open in Brickworks and the MCP's
open path; loopmetrics the console). They go ahead of APP_UX11's wave 3 and
docs/SOCIAL.md's lists2a and inbox, which the lead's slots had next: the
owner's ask of 23 November is the social loop, and these are its joins.

Wave 2 starts as wave 1's units merge: partpins after makes, remixdiff after
claudelink, challengestudio after prompts, buildlog after remixdiff,
firstminute after ux12; postkit, webstart14 (after webstart13's proofs),
lists2a, inbox and ownedparts (after lists2a) wait on nothing else here.
Wave 3 needs wave 2.

**Shared files.** Several units add a block to `web/model-page.js`. As with
the registries (`tools/release/preview_checks.sh`, `.claude/skills/verify/`,
`api/_insights_names.js`, `tools/site_shell.py`, the docs index), each unit
adds its own block and changes no other's, and the lead merges them in rank
order.

**If every row lands,** the loop reads: discover level (people still
arriving), open best on a laptop and level on a phone, change best, build it
for real best (alternates and missing-only, which Rebrickable has no 3D
for), share best (makes where the build ends), hear back best (on the
part, in the CAD), come back level (weekly prompts and challenges entered
from the studio, without a crowd yet). The remaining behind is people,
which only time and the ways in above can fix. loopmetrics says whether
they do.

## Sources

Each read on 22 or 23 November 2026. Where a site refused a reader, its
Wayback Machine copy was read and the original address is given.

The CADs:
- [st-find] https://studiohelp.bricklink.com/hc/en-us/articles/6502499385111-Finding-parts
- [st-stab] https://studiohelp.bricklink.com/hc/en-us/articles/6501498505111-Stability-check
- [st-price] https://studiohelp.bricklink.com/hc/en-us/articles/5705572363159-Parts-prices-and-availability
- [st-steps] https://studiohelp.bricklink.com/hc/en-us/articles/7123910550039-Automatic-instructions-Divide-into-steps
- [st-gal] https://studiohelp.bricklink.com/hc/en-us/articles/6153755149591-Importing-designs-from-the-Studio-Gallery
- [mb-home] https://www.mecabricks.com/
- [mb-model] https://mecabricks.com/en/models/1w2rOpE0j8W
- [mb-forum] https://www.mecabricks.com/en/forum/topic/70739
- [ld-adv] http://www.melkert.net/LDCad/docs/advEdit
- [ld-script] http://www.melkert.net/LDCad/docs/scriptAPI2
- [lc-2609] https://github.com/leozide/leocad/releases/tag/v26.09
- [kb-030] https://github.com/fhareide/kinebrick-studio-releases/releases/tag/v0.3.0
- [kb-040] https://github.com/fhareide/kinebrick-studio-releases/releases/tag/v0.4.0
- [kb-play] https://github.com/erik-larsen/kinebrick
- [on-follow] https://cad.onshape.com/help/Content/Collaboration/follow_mode.htm
- [on-comments] https://cad.onshape.com/help/Content/Collaboration/comments_on_workspaces.htm
- [on-versions] https://cad.onshape.com/help/Content/Document/versions_and_history.htm
- [on-share] https://cad.onshape.com/help/Content/Collaboration/share_documents.htm
- [on-keys] https://cad.onshape.com/help/Content/Home/keyboard_shortcuts_and_hotkeys.htm
- [fu-comment] https://help.autodesk.com/cloudhelp/ENU/Fusion-Designs/files/ASM-COMMENT-DESIGN.htm
- [fu-timeline] https://help.autodesk.com/view/fusion360/ENU/?contextId=DESIGN_HISTORY

The communities:
- [li-guide] https://ideas.lego.com/guidelines ("last updated September 30th, 2024"; Wayback copy)
- [li-how] https://ideas.lego.com/how-it-works (Wayback copy)
- [rb-engine] https://rebrickable.com/help/build-engine/
- [rb-search] https://rebrickable.com/help/build-search/
- [rb-build] https://rebrickable.com/help/building-lego-set-mocs/
- [rb-alt] https://rebrickable.com/help/alternate-builds/
- [rb-fan] https://rebrickable.com/help/fan-photos/
- [rb-levels] https://rebrickable.com/help/users-levels/
- [fl-pool] https://www.flickr.com/groups/lego/
- [fl-explore] https://www.flickrhelp.com/hc/en-us/articles/4404070823700-Flickr-Explore
- [fl-lugnuts] https://www.flickr.com/groups/lugnuts/discuss/
- [rd-rules] https://www.reddit.com/r/lego/wiki/rules_policies_and_expected_behaviour (Wayback copy)
- [rd-moc] https://www.reddit.com/r/legomoc/ (Wayback copy)
- [ig-tags] https://www.socialmediatoday.com/news/instagram-implements-new-limits-on-hashtag-use/808309/
- [ig-habitat] https://bricknerd.com/home/stacking-habitats-an-instagram-afol-community-challenge-3-16-22
- [ig-brickmas] https://www.brothers-brick.com/2025/12/01/24-days-of-brickmas-a-holiday-challenge-for-builders-of-all-ages-starts-today
- [eb-tc20] https://www.eurobricks.com/forum/forums/topic/187042-tc20-technic-studless-recreation-contest-voting-topic/
- [eb-tc25] https://www.eurobricks.com/forum/forums/topic/196022-tc25-technic-shrinking-contest-results-topic/
- [bs-faq] https://brickset.com/faq
- [bs-rev] https://brickset.com/reviews
- [mw-faq] https://makerworld.com/en/faq (Wayback copy)
- [mw-model] https://makerworld.com/en/models/41621 (Wayback copy)
- [mw-boost] https://blog.bambulab.com/boosting-what-matters-rewarding-engineering-and-design-effort/
- [mw-contest] https://makerworld.com/en/contests (Wayback copy)
- [pr-benchy] https://www.printables.com/model/3161-3d-benchy (Wayback copy)
- [pr-points] https://help.prusa3d.com/article/how-do-prusameters-on-printables-work_365065
- [pr-feed] https://blog.prusa3d.com/new-on-printables-com-community-feed-improved-search-new-rewards-and-more_69067/
- [pr-slicer] https://help.prusa3d.com/article/opening-models-in-prusaslicer-from-supported-websites_399198
- [pr-contest] https://www.printables.com/contest (Wayback copy)
- [R8-MW] and the other R8 sources: docs/SOCIAL.md, Round 8.

Brickworks' own: `/api/share?op=list` and `/api/people?op=challenge` on
brickworks.diy, read at 03:19Z on 23 November; `bench/results/lead-2026-11-05/queue.md`
for what is in flight; docs/COMPETITIVE.md, docs/APP_UX11.md, docs/SOCIAL.md
and bench/results/landing-2026-11-22/CRITIQUE.md for the rows they measured.
