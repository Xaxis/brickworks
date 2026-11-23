# The plan: the best LEGO® CAD, and the LEGO® social site built round it

Written 2026-11-23 by plan24 for the lead, against brickworks.diy as live (rel-m319, main `35d0b963c`),
origin/pre261 (`d871d6ff2`) and the unit branches. Not docs/PLANS.md, which is pricing.

The owner, 23 November: Brickworks has two equal goals. **A**, the core technology: the CAD, kept moving with
advanced features. **B**, the LEGO® social site built round that CAD, its features coherent and far ahead of the
competition. They asked for one analysis of current and planned work against both goals, and the fastest way to
build it: "no hours of coordination that deploy nothing".

This is the living plan. It builds on the research already done and replaces none of it:
[COMPETITIVE.md](COMPETITIVE.md) and [APP_UX11.md](APP_UX11.md) for the CAD, [SOCIAL.md](SOCIAL.md) (round
eight) for the site, [MASTERPLAN.md](MASTERPLAN.md) (on pre261) for the loop that joins them, and
`bench/results/lead-2026-11-05/owner_asks.md` for the owner's 90 asks. **Keep it current:** at each app release,
move the cells and the ranks below. Don't start a new round document.

## The answer, short

- **Both goals are mostly built. Little of it is live.** More than twenty units reached CODE DONE on 23
  November alone. origin/pre261 is 106 commits ahead of main, and mergewave holds more on a local line. None
  of the owner's asks since 21 November is on brickworks.diy (owner_asks.md). Releases went from three or four
  a day (rel-m300 to m316, 15 to 20 November) to one a day or less (rel-m317 on 20 November, rel-m318 on 22
  November, rel-m319 promoted by hand on 23 November at 10:28Z).
- **Three causes, all fixable this week:**
  1. **One integration line.** Every unit merges into pre261, which changes 31 app files that main does not
     have. So every train needs an export and the app's probes. The web lane that train.sh has had since 18
     November (fastlane) is never chosen. Seven units are site-only in their own changes: altbuilds,
     ownedparts, postkit, inbox, lists2a, sitepolish and sitebold. They still wait on an export and 280 probes.
  2. **More units than the box can prove.** There are 11 teammates. At 10:42Z, 46 brickworks jobs waited in
     heavy, and the load was 121 to 135 on 24 cores.
  3. **Day releases held by full trains and timing lines.** A full train runs 280 to 285 probes and about 100
     checks: 7 hours or more. rel-m319 was held on designer_period's timing at load 110 to 138, and reship 4 on
     fpfix.
- **A, the CAD:** ahead of six tools in 78 of 98 cells, level in 11, behind in 9 (20 November). camerakeys and
  pagetools have gone live since, so two of the 9 behinds wait to be judged again. Two quality bars are not met:
  the AI designer against real sets, and renders against photographs.
- **B, the site:** 49 ahead, 36 level, 27 behind over 112 cells (20 November). The one row behind every site is
  people: 50 models, 49 of them the house's, 0 likes. Today's joins (makes, alternates, what you own, weekly
  prompts, entering a challenge from the studio, Talk) close the Rebrickable, Printables and Eurobricks behinds,
  once they are live.
- **The next 20 units** put the community inside the CAD (the studio's start, Ask the builders, suggested edits,
  building live) and the CAD inside every page (set hubs, cards drawn like photographs).
- **The strategy:** two lines and two lanes, and six units at once with no coordination units. The web lane
  ships every hour. The app lane ships twice a day, before and during the owner's hours. The full battery runs
  every night and gates nothing. Done means live.

## 1. Where we stand

**Ahead / level / behind** is Brickworks against that competitor, cell by cell, as COMPETITIVE.md and SOCIAL.md
judge it. **Proof** is a live page on brickworks.diy, or a check by its name in `tools/release/preview_checks.sh`
(a browser flow) or `src/dev/` (a probe).

### Goal A: the CAD

| Competitor | What they do best | Where we are (proof) | The gap, and its unit |
|---|---|---|---|
| **BrickLink Studio** 2.26.10 | The community's file (.io). PartDesigner. Step Editor and Page Layout. The Eyesight renderer. Build Together. Prices and wanted lists from BrickLink while you pick. Find compatible bricks. | **Ahead 8, level 4, behind 2.** Level on snapping, sub-models, booklet and render. Ahead on parts made at any size, motion, Technic, sharing, phones and AI. Together runs in a browser, where Build Together is desktop only. Proof: /app; checks `io`, `booklet_edit`, `render`, `together` | **Files:** a Brickworks .io has never been seen opening in Studio (**studioio2**, rank 16). **Prices:** parked, because BrickLink's keys are the owner's, and BrickLink has shown a maintenance page since 19 November. |
| **Mecabricks** | In the browser, no install. A model's page opens straight into its editor. Anyone can add renders to a model. | **Ahead 13, level 1** (render: its render farm and Blender add-on). It has no forks, follows or building together. Proof: /app, /m/ pages; checks `model_page`, `together` | Render only: photoreal13, then **cardlook** (rank 4) |
| **LeoCAD** 26.09 | Minifig Wizard, a timeline pane, a trackball gizmo, "optimized for large models". | **Ahead 12, level 2** (parts, sub-models). Proof: the minifig builder (`e948a46de`), the timeline slider (`2aadc5abb`), Orthanc's 9,429 parts open in a browser; checks `load`, `frames` | None |
| **LDCad** 1.7 b2b | Hoses, bands and springs drawn live. Snap metas. Lua animation. | **Ahead 13, level 1** (full nested MPD). Proof: checks `flex_pose`, `flex_skin`; Motions | None ranked. Scripted animation against keyed Motions is not a builder's gap. |
| **StudWorx** 2026-11-19 | Booklet tools: an element inspector, a page locked or frozen, the outline 1 to 72 wide, HTML pages. | **Ahead 11, level 2, behind 1** on 20 November. pagetools has been live since rel-m319 (`62a161879`). Proof: checks `booklet`, `booklet_edit`, `booklet_safe` | Judge it again at the next scorecard: likely level or ahead now |
| **Kinebrick Studio** 0.3.0 | Gravity, friction and contact. Cams, Geneva drives, pneumatics, chains. Wired electrics. Pybricks. A camera track. It works 701 of 1,226 real sets' functions. | **Ahead 10, level 1, behind 3.** The camera track is closed (camerakeys live, `16744b131`). Behind on Motion and Technic: Simulate works 391 sets' functions (KINEFUNCS.md). Proof: checks `technic`, `assembly` | Physics is kinefuncs2, **parked by the owner**. **pybricks** (rank 18). Wires are on main. |
| **Phone builders** (Brick Creator 3D, Tumbly, Stackable) | Native apps that open at once. A pile scanned by the camera. Every step read aloud. | **Ahead 11, behind 3.** An iPhone's return takes 19.5 s and a first visit 23.8 s (webstart13, 22 November). Wasm peaks at 432 MB. Proof: checks `phone`, `phonewarn` | **webstart14** (rank 10), **pilescan** (rank 12), **smalls13** (rank 19) |
| **The AI designer, against real sets** | (No CAD has a designer. The bar is the owner's: "a kit LEGO might actually manufacture", asked 11 times.) | Ahead of every tool. Against the real sets: won 24% on 44 held-out subjects (16 November). design14 to design29 ended NO-GO. design30 met its gate (8 of 12 bodies laid, 4 of 6 near), but its real-set screen never ran. Proof: `realset.py`, DESIGN_SCORES.md | The realset win rate: design31 (running), then **design32** (rank 9) |
| **Renders, against photographs** | Studio's Eyesight and Mecabricks' farm are level with us. Nobody's renders pass as photographs. | Best, path traced, is live. photoreal1 to 12: the paired judge still picks the photograph 18 to 20 times in 20. Solo, 7 to 31 of 80 renders are called a photograph. photoreal10's measured stage is on pre261. photoreal12 was NO-GO. Proof: `tools/probe.sh photoreal`, `tools/bench/photoreal.py judge`, RENDERING.md 5o | The plastic itself: photoreal13 (running). After it, the gain is shown where people see it: **cardlook** (rank 4) |

### Goal B: the social site

| Competitor | What they do best | Where we are (proof) | The gap, and its unit |
|---|---|---|---|
| **Printables** | Makes on the original's page (9,830 on Benchy). Prusameters. A feed of uploads, makes and collections. Open in PrusaSlicer. 38 contests in 2026, median 218 entries. | **Level** on the model page, feed and profile. **Behind** on showing work, contests, phones and the first visit (SOCIAL.md rows 1, 8, 10, 12). Build it opens a 244-step model signed out in 20 s (the masterplan's walk). Proof: /gallery, /builds, /feed; checks `builds`, `gallery_builds`, `feed`, `challenges` | **makes** (Show your build at the last step) and **prompts** ride rel-m321. Entries: 0 in Microscale. That is people, below |
| **MakerWorld** | For You. Print profiles anyone can add, ranked under the model. Boost tokens. Contests on a countdown. Open in Bambu Studio. | "Best elsewhere" in 6 rows. We are **best** at opening: the CAD opens in the same tab, with no install. Remixes say what they changed, in 3D (remixdiff, pre261). Proof: /m/ pages; checks `model_page`, `embed` | The print profile's idea (a builder's change, ranked under the original): **suggestedit** (rank 5). For You waits for 500 models from 50 designers (SOCIAL.md behind 9) |
| **Rebrickable** | Build % on every set and MOC. Missing Parts and Buy Parts. Alternate builds with an Alt badge. Fan photos. A MOC timeline. | **Behind** on sets, parts and lists (row 9) on 20 November. Live: Own and Want on 1,576 set pages, What can I build, Build with what I own. On pre261 for rel-m321: altbuilds (backfilled on the live database: 52 models counted, 1 of them an alternate) and ownedparts ("You have 87%", only the missing parts to buy). Proof: /library; checks `sets_flow`, `lists`, `collection` | Closes at rel-m321. Then the set page as the hub search lands on: **sethub** (rank 2), **setreviews** (rank 15) |
| **Flickr's LEGO® groups** | Volume: 650,132 photos from 21,668 members. Explore ranks by meaningful interaction. LUGNuts' 120 monthly challenges. | **Behind** on people, notifications and phones (rows 15, 6, 12). Link previews turn in 3D (turntable, live). The embed is 3D (`embed`). Proof: checks `turntable`, `embed`, `seo` | postkit (a Flickr 2560 px kit and others) rides rel-m321. Volume is people |
| **Reddit** r/lego, r/legomoc | Where builders already post. MOC and SEC flairs, one or two WIP posts per MOC, critique on r/LegoMocHelp. No new API apps since 31 October. | The social desk replies by a post's address (redditway, live). postkit makes kits in each sub's own rules, and buildlog keeps WIP at home; both ride rel-m321. Proof: /admin › Social desk; check `socialdesk` | Critique, inside the CAD: **askhelp** (rank 3) |
| **Eurobricks** | Forums by theme. WIP threads. Contests whose public vote (10-6-4-3-2-1) feeds a jury that explains its picks. | Talk, the builders' forum, rides rel-m320 (`talk`, talk_flow 46 of 46 on a local relay). A shortlist, fan vote and honours have been live since rel-m319 (`e162d9442`; `challenges`, `challengehome`). | Live at rel-m320. Then askhelp's help board |
| **LEGO® Ideas** | A path to a product. Supporter milestones on a clock (100 in 60 days, up to 10,000). Three reviews a year, a 1% royalty. Quick Activities. | **Behind** on contests (row 8). We can't make sets. postkit's Ideas kit checks Ideas' rules (200 to 5,000 pieces, at most 15 images), and the weekly prompts are the Activities; both ride rel-m321. | A path to a product: not ours to offer |
| **BrickLink's Studio gallery** | A design opens inside Studio if its designer allows it. The Designer Program. | **Ahead** on the model page: 3D, Build it, steps, versions, parts for three shops, Tested (`model_page`, 1,146 passed and 0 failed on gatefix's tree). Row 8's behind (judged rounds, a fan vote) is answered by challengehonours, live since rel-m319: judge it again. BrickLink has been offline since 19 November. | Nothing to take. The Designer Program means money, which is parked |
| **People and activity** (every site) | Every other site has people's work on its first screen. | **Behind all eight.** On live there are 50 models, 49 of them the house's. The first outside share came on 23 November at 02:51Z (1,320 parts, made with the assistant). There are 0 likes, 0 comments and 0 remixes. Microscale has 0 entries. The loop card over 30 days (loopmetrics, owner included): discovered 23, opened 4, changed 1, shared 0. | No feature copies this. The cure is ways in that turn existing traffic into people's work: set pages, Build it, the studio, the assistant. Ranks 1 to 6 are those ways in. |

## 2. What to build, ranked

### First: ship what is built (no new unit)

The owner sees nothing that is not live. Each of these is code done today.

| Release | Lane | What the owner will see | Owner asks it answers |
|---|---|---|---|
| **rel-m320** (restaged 10:30Z on `85dd6961f`, 19 checks, no probes) | app (homefeed touches src/boot/shell.html and src/main.gd) | The home is the builders' feed. The mark is built in real bricks in the 3D hero. Talk is in the header. | #1 hero, #5 the home as the feed, #15 forum and gallery on the first screen |
| **rel-m321** (pre261 once mergewave pushes; inbox, firstminute and bootlook as they merge) | app, as a lean list: no --full | Show your build at the last step. Other builds from this set. You have 87%, and only the missing parts to buy. Weekly prompts and their stack. Enter from the studio. Change it with your Claude. A remix shows what it changed. Comments pinned to a part. Share progress. Kits for Reddit, Instagram, Ideas and Flickr. The stranger's door opens on the model they chose. Inbox settings. Lists by name. ux12 and ux13. The loading wall. photoreal10's stage. hero3d's frame rate (`cd8aa2f7e`). | #5, #6 UI/UX, #7 rendering (in part), #11 site and docs moving with features |
| **save path** (held) | app | Nothing visible. Comments, TEXMAPs and steps kept on every save. | The baseline: no silent data loss |

After rel-m321 is live, main and pre261 hold the same app files again. From then on, the two lines in section 4
keep site-only work off the app lane.

### The next 20 units

Cohesion first: a unit that ties the CAD to the community ranks above an isolated feature. **Lane:** W is the
web lane (site only, about 15 minutes to live). A is the app lane (twice a day). W+A splits into a site half and
an app half, and the site half ships first when it degrades cleanly on its own. **Hours** are the unit's own
work and its lean proofs, not time in the queue. **Review:** one, only for the save path, accounts, people's data
or SQL. Three rows are **standing**: one unit of each always runs, and the next takes the slot when one lands.

| # | Unit | Goal | Lane | What it ships | Its visible bar | Hours | Waits on |
|---|---|---|---|---|---|---|---|
| 1 | **studiostart** | A+B | A | The studio's first screen for a signed-in person, in place of the example car. It shows Continue (your last models), this week's prompt (its template in one tap), what came back on your models (comments, pinned parts, remixes, builds), and a gallery search that opens a copy. A pin opens the model and lights its part. | /app at 1280×800 and 390×844, both themes: at least 3 real items, within the studio's open time + 1 s. Never the example car for an account that has a model. A pin lights its part in ≤ 1 s. A new pin appears while the studio is open, within 60 s (partpins' gap). Before and after pictures in the report. | 5 | rel-m321 (partpins, prompts, firstminute) |
| 2 | **sethub** | B+A | W | Each of the 1,576 set pages as the place search sends people: it turns inline (set3d), with Build it, Other builds from this set, and You own n. Make your own version opens the set in the studio as a credited copy, and when that copy is published it is listed on the set's page. | LCP no worse at 390 and 1280. Make your own version puts the set on the baseplate within the studio's open time + 2 s. A published version shows on the set's page within 60 s. No whole .mpd is read per view (Supabase egress). | 4 | set3d, rel-m321 |
| 3 | **askhelp** | A+B | W+A | Ask the builders, from the studio: posts the open step (its 3D, the parts picked) to a help board in Talk. Answers pinned to parts light those parts in the studio and appear in studiostart. Signed out, the thread reads with the 3D at that step. It is r/LegoMocHelp, but the answer lands on the part, in the CAD. | Studio to a live thread in ≤ 3 taps at 1280 and 390. A pinned reply reaches the open studio within 60 s and lights its part. The thread's 3D opens at the asked step. 13+, report and block all hold. | 6 | rel-m320 (Talk), studiostart |
| 4 | **cardlook** | A+B | A | Every model's gallery picture drawn at publish with Render's measured stage: photoreal10's tables and light, plus photoreal13's plastic if it passes. The house's 49 are drawn again once. The home feed and the gallery then read as photographs of real models. | A blind judge prefers the new card to the old in ≥ 15 of 20 pairs, both orders, at the 480 px 4:3 card. Publish ≤ 2 s slower at p95. Both themes' cutouts kept. | 5 | photoreal13's verdict |
| 5 | **suggestedit** | A+B | W+A | A remixer sends their change back. The designer sees it in the studio as Compare (added, removed, moved, recoloured, in 3D) and takes all of it or part. The change taken credits the remixer in Versions and on the model's page. A pull request for LEGO® models: no CAD or community has one. | Each class of edit, taken whole or in part, gives the remixer's model (by a test). Nothing is taken without the designer's tap. The request reaches the designer's bell and studiostart within 60 s. | 10 (review) | remixdiff (pre261), studiostart |
| 6 | **buildlive** | A+B | W+A | Building now. A designer opens their Together session to watchers from the studio. It is listed first in the home feed and on their profile. Watchers see parts land in the light viewer and chat. Ask to build gives a seat. It ends as a version in the model's log (buildlog). Folds in the masterplan's watchlive. | A part reaches 10 watchers within 1 s at p95. Listed within 10 s. A watcher's edit is refused at the relay. Egress per watcher-minute measured against the Supabase budget before it ships. | 10 (review) | rel-m321 (buildlog), rel-m320 (feed) |
| 7 | **ux15** (standing) | A | A | The next walk-and-fix pass of the studio once ux14 lands: a first build, a remix, a booklet and a phone, walked as people do, with at least 8 frictions fixed in code. This is the owner's "continue to master the UI/UX". | First screens before and after at 1280×800 and 390×844, both themes, in the report, which the lead looks at itself. A probe for each fix. Nothing outside the app's own style. | 6 | ux14 |
| 8 | **sitebold2** (standing) | B | W | The next pass by eye once sitebold lands. Every page against Printables, MakerWorld and Rebrickable at 390, 768 and 1280, both themes. It ships alone on the web lane. | The lead's own before and after first screens. At least 12 fixes. LCP no worse. | 4 | sitebold |
| 9 | **design32** (standing) | A | A | The design track's next lever, chosen from design31's screen sessions. One candidate is the owner's 10-13 retrieval ask, as a lever and not as infrastructure: real sets' own sub-assemblies for the subject, found and handed to the session. | The realset win rate above design31's beyond the noise, with both arms complete. A NO-GO is said plainly. | 8 | design31 |
| 10 | **webstart14** | A | A | A phone opens the studio fast. It cuts the 124-script cycle webstart13 named, and keeps Wasm under 300 MB. | In same-moment pairs: an iPhone's return ≤ 8 s (19.5 now), a first visit ≤ 15 s (23.8), Wasm ≤ 300 MB (432). A web export starts. | 8 | nothing (webstart13's report) |
| 11 | **twobuilders** | A+B | A | Build with a friend, from the model's page. The model's steps split into two strands with even part counts, and two phones build from one link, each seeing the other's progress. It ends as one make with both names. | A 200-step model split within 10% of even parts. Progress in sync within 1 s. One make, two credits. | 8 | rel-m321 (makes) |
| 12 | **pilescan** | A+B | A | Measured first: a photo of a pile counted into what you own. If it works, the gallery's You have 87% and What can I build follow at once. | On 20 pile photos, the right part in the top 3 for ≥ 80% and the count within 10%, or NO-GO. If met, scan to shelf in ≤ 10 s. | 6 | rel-m321 (ownedparts) |
| 13 | **signin-google** | B | W | Continue with Google in the sign-in dialog. MakerWorld and Printables have it; ours is the stranger's door. | As SOCIAL.md rank 6: at 390 and 1280. A new account meets the age question and First steps. The same address lands in the same account. | 4 (review) | a free Google OAuth client the lead makes (parked, and said so, if none) |
| 14 | **commentcare** | B | W | The designer pins one comment and one build photo. Held words, as Instagram's Hidden Words. | As SOCIAL.md rank 10. `comments`, `mentions` and `block` pass. | 6 (review) | rel-m321 (makes, partpins) |
| 15 | **setreviews** | B | W | Reviews on a set's page on Brickset's five axes, with helpful votes. A note pinned to a step of the set's booklet. | As MASTERPLAN row 18. A step note opens its step. Review JSON-LD in `seo`. | 6 (review) | sethub |
| 16 | **studioio2** | A | A | The siofix line finished: a Brickworks .io opens in Studio itself (the Files behind against Studio). Folds in siofix4. | APP_UX11's bar: 20 Studio files written back entry for entry, a round trip of each identical, and 5 opened in Studio itself. | 6 (review: save path) | siofix3 and siorev4's fixes |
| 17 | **moulds** | A | A | Custom 3D moulds: a part from an OBJ, STL or glTF (a hair piece, an element of your own), with connection points placed by hand, saved in the file and published. The owner's 10-11 ask (#14). | A mesh part placed, snapped by its points, saved and reopened byte for byte, and shown in the gallery's viewer. A mesh that can't be one is refused in words. | 8 | nothing |
| 18 | **pybricks** | A | A | Pybricks programs drive Simulate (the Technic behind against Kinebrick). | APP_UX11's bar: hubprogram's arm driven the same by its Pybricks version, kept byte for byte. | 8 | nothing |
| 19 | **smalls13** | A | A | LDraw 2026-10's 129 parts in the bin. Steps read aloud in Build it (Tumbly's lead). The walk's faults. | APP_UX11's bar. | 5 | nothing |
| 20 | **weekmail** | B | W | Your week, by email, by choice (inbox's settings): what the people you follow made, the week's prompt and its stack, and your models against last week. This is the come-back step, the cheapest lever on a row that is behind. | `digest` passes. At most one email a week, unsubscribe in one tap. Every number equal to insights2's. | 3 | rel-m321 (inbox, prompts) |

**What the owner will see, in order:** the home as the feed (rel-m320). Then the joins on every model and set page
(rel-m321). Then the studio opening onto their own community (1). The set pages as the place to start (2).
Feedback landing on the part (3). Cards that look like photographs (4). Remixes coming home (5). And a live show
on the feed (6). Throughout, the UI/UX and the site get better by eye every day (7, 8).

**Roughly how long:** the 17 ranked units with no standing slot come to about 115 unit-hours. At three ranked
slots plus the three standing ones, that is about three days of slot time, if releases keep pace (section 4).

## 3. Stop or fold

| Unit | Now | Verdict | Why |
|---|---|---|---|
| **fastship** | running | **Keep, first.** Add one bar: a site-only change from main takes the web lane. | The export is down from 511 s to 205 s, and the deploy takes 636 s in its slot (`deploy/steps.txt`), but the web lane is still never chosen (section 4) |
| **mergewave** | running | **Keep until pre261 is pushed and rel-m321 staged. Then stop the pattern.** | From then on, units merge themselves at READY (merge_unit.sh); a red train reverts the unit |
| **gatefix** | running | **Fold into mergewave now.** No gate-fixing units after this. | Gates are each unit's own before READY (common_rules) |
| **fmfin** | running | **Fold.** Merge firstminute as it stands (FAILS_OK) and let the train judge. | The owner, 08:51Z: "not pedantic". A finisher per unit doubles the slots. |
| **sitebold** | running | **Keep** (standing site slot). It touches web/model-page.js only after mergewave's merges are on its base. | partpins, remixdiff, claudelink, makes and ownedparts all edited web/model-page.js; partpins hit 7-file conflicts this way |
| **set3d** | running | **Keep.** sethub is its follow-up on the same files. | The owner's 10-30 ask (#12) |
| **ux14** | running | **Keep** (standing UX slot) | The owner asked 4 times |
| **design31** | running | **Keep** (standing design slot) | The owner's most repeated ask, 11 times |
| **keepfix** | running | **Keep, the save path's last unit.** stepkeep2, sk2fix, wholekeep, wkfix and keepfix merge on keepfix's red-to-green with the reviewers' own tools. No further review round. | No silent data loss is a baseline. track-and-ship: one review per save-path line |
| **photoreal13** | running | **Keep as the track's last lever round.** No photoreal14. Its result goes to cardlook. | Twelve rounds: the paired judge has said 18 to 20 of 20 since photoreal1. photoreal11's app "after" looked worse by eye, and photoreal12 was NO-GO. |
| **snot5** | running | **Keep to its bound.** No snot6 unless snot5's own numbers move. If it misses, say "not fully done" and park it for the owner. | The owner asked twice (10-22). Brickify is a side door, not a join. |
| landing, landfix | stopped | **Retire the branches** (done_unit.sh) | homefeed replaced them |
| webstart13 proofs3 | planned | **Fold into webstart14** | Same bars, same files |
| siofix4 | stopped | **Fold into studioio2** | One save-path line, one unit |
| watchlive (masterplan 16) | planned | **Fold into buildlive** with Together's Ask to build | One live session, not two |
| RAG / vector DB (owner 10-13) | not started | **Fold into the design track** as a lever (design32's candidate), judged by the screen | "If it is relevant, do it": the screen says whether it is |
| X, Facebook, Instagram desk | not started | **Not ranked**: the owner said "later" | |
| kinefuncs2, buildorder2, payments, desktop downloads, BrickBench, new languages, provider keys, BrickLink prices | parked | **Not ranked**: the owner's to unpark | Nothing above waits on any of them |
| New plan rounds (APP_UX12, SOCIAL round nine, a second masterplan) | habit | **Stop.** Move this file's cells at each app release. | Four plan documents planned two halves of one loop |
| Judge, clerk and check-fix units (m319checks, m319_judge, mergeclerk) | habit | **Stop.** A red traced to a unit reverts it (red-train-revert-the-unit). | Coordination that deploys nothing |

## 4. How to build it fast

### The box, measured at 10:42Z on 23 November

- It has 24 cores. The load was 121, 134 and 135 (1, 5 and 15 minutes). heavy has 24 slots, 8 a project, with
  brickworks at high priority (CPU weight 400). Brickworks held 9 and had 46 waiting, every one "beside
  brickworks's release job, which goes first". Cutwright, Reelwright, ratchet.diy, ochk, oc-*, soniq and
  blocklore share the box.
- At this load a browser flow takes 10 to 60 minutes: set3d_flow had held its slot for 58 minutes, signin_flow
  for 22. A full train takes 7 hours or more.
- A release holds 3 or 4 slots (`PC_AT_ONCE=3` plus a probe or ci_gate), which leaves units 4 or 5. A lean unit's
  proofs are 3 to 5 flows, up to 8 probes and ci_gate: 1.5 to 3 slot-hours. **So the box proves about six units
  in a three-hour cycle.** Eleven units queue faster than it drains: 46 jobs is about five hours.

### Six units at once, none of them coordination

- **Web lane:** one ranked unit and the standing site unit. **App lane:** two ranked units and the standing UX
  unit. **Design:** the standing design unit. Add fastship until it lands.
- **Spawn only when `heavy --status` shows 15 or fewer brickworks jobs waiting.** Otherwise merge and ship
  first. A long queue is never a reason to go round it (common_rules).
- **A unit runs only what it drives:** 3 to 5 flows, the featuremap-affected probes (at most 8) and ci_gate. Then
  it reports CODE DONE with its sha and stops (units-under-a-full-train).

### Two lines and two lanes

- **Why the web lane never fires:** train.sh chooses it only when the branch changes no app file
  (`live_export.sh app FROM TO`). Every branch off pre261 carries pre261's 31 app files against main. So
  altbuilds, ownedparts, postkit, inbox, lists2a, sitepolish and sitebold, which change no app file of their
  own, each wait for an export and the app's probes.
- **From rel-m321's going live:** a site-only unit branches from **origin/main** and ships alone on the web lane
  (`train.sh --web`). That means no export and no probes: its own flows, flows_for its diff and a smoke of 6
  (`site`, `gallery`, `model_page`, `feed`, `talk`, `site_lang`). Then promote, with a read-only smoke after it.
  It takes about 15 minutes. An app unit branches from **pre261** and ships in the app lane. When an app release
  goes live, main merges into pre261, as now.
- **Choose the lane at spawn, not at staging:** run `live_export.sh app` on the unit's planned files. A W+A unit
  is two branches: the site half ships first when it degrades cleanly without the app half. Otherwise the whole
  unit rides the app lane.

### Cadence

- **Web lane:** each site unit ships the hour it is READY, at most two to a train. One web train in flight.
- **App lane:** a batch of up to 4 units, twice a day, **live by about 08:00Z and 14:00Z.** 94 of the owner's
  125 November prompts (75%) came between 08:00 and 16:00Z. Checks are the featuremap-affected headless probes,
  flows_for the diff, and an app smoke of about 10 (`app_host`, `model_view`, `placing`, `steps`, `dialogs`,
  `phone`, `tabs`, `load`, `library`, `booklet`). Stage to live in ≤ 2 hours. rel-m320's restage (19 checks, no
  probes) is the model to follow.
- **Nightly full battery:** `--full` on main as live, started after the day's last app release (about 18:00Z).
  **It gates nothing.** A red traced to a unit reverts that unit in the morning batch. Timing checks are judged
  only here, as same-moment pairs (timing-hold-attribution). A day release never waits on a timing line at load
  110 or more.
- **One release in flight per lane.** Never stage a train `--after` one in the other lane: rel-m320's
  live-db.release mark blocked rel-m319's stale run (10:31Z), and the lead promoted by hand.

### What the lead stops doing

1. Spawning past six units, or while more than 15 jobs wait.
2. Coordination units and idle-drain replies (mergeclerk, mergewave after rel-m321, gatefix, fmfin, judges).
3. `--full` on the day path. Holding a day release on a timing line or a stale check under load.
4. Staging a train behind another train, and promoting by hand to get round a lock. Hand fastship the lock bug
   instead (its two tooling bugs, queue.md 10:31Z).
5. New plan rounds. Move this file at each app release.
6. Counting CODE DONE as progress. A task completes when its release is live and the lead has looked at it.
   Each status leads with what went live (brickworks-report-by-feature).
7. Lever rounds on a track whose measure has not moved in three rounds, until a measure can see a step:
   photoreal now, as designmeasure was for design.

### What the lead keeps doing

- It looks at every home and UI unit's first screen itself before calling it done: 1280×800 and 390×844, both
  themes.
- It gives one review, only to the save path, accounts, people's data and SQL. SQL is additive and applied by the
  lead from production's current function body.
- The site and docs move with each feature, in the same branch.
- One standing unit each for UX, the site and design, so the owner sees the app and the site change every day.

### Done means live

The owner judges brickworks.diy and the studio by eye. A unit is done when its release is live and the lead has
looked at the first screen. That is the moment this plan's cells and ranks move.
