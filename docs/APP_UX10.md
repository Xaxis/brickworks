# The app against the best tools, round ten

Written 2026-11-19 by uxplan10 against `pre261` at `3e6e46f05`. The web was
measured on live brickworks.diy, rel-m311.4 (`15b59b46b`) until 04:15Z and rel-m313 (`b7d74c04a`) after it. [APP_UX.md](APP_UX.md) to
[APP_UX9.md](APP_UX9.md) planned rounds one to nine.

## Where round nine's units stand

Thirteen of APP_UX9's fifteen rows are done and live, three of them since
rel-m313 went live (19 November 04:14Z, `b7d74c04a`), and the design track's three
units each ended NO-GO. kinefuncs2 and buildorder2 wait on the owner, as
planned. Read from `queue.md`, `git log pre261` and each unit's own record:

| # | unit | where | its bar, as it ended |
|---|---|---|---|
| 1 | balljoints | live, rel-m307 (17 Nov 20:36Z) | met: every ball in its socket the stability reads in real sets, 1,109 of 1,109 (the bar said 78; the probe found 1,111 joints in 360 sets), seated by hand both ways round; 11 catalogue pairs; a turn about the ball's centre; Pose gives each ball three turns; the MCP walk's f1 from 38 calls to 12 to 14 |
| 2 | kinefuncs2 | **the owner's choice**, not started | Simulate works 391 of 1,224 functions ([KINEFUNCS.md](KINEFUNCS.md), unchanged since 13 Nov). Kinebrick works **701** today, from 673 on 15 Nov: the gap is 310 functions, from 282 |
| 3 | webstart10 | live, rel-m307 | a return after a release keeps the engine it has (`/e/<hash>/`): 19.7 to 14.9 s (x0.76), a phone's 17.7 to 13.2. **Not met:** the first visit's targets, 0 of 2 pairs, as on live. Then **webstart11** (pre261, rides rel-m314): the catalogue as columns, Wasm at start 519 to 432 MB, the catalogue's read at a quarter speed 10.0 to 3.7 s, a loaded desktop first visit 33.9 to 27.2 s in 5 same-moment pairs |
| 4 | jointmarks | live, rel-m309 (18 Nov 07:35Z) | met: on in hand and under the pointer, View › Connection points; a beam's 7 holes within 0.54 px; 11 kinds; nothing written. **Its cost line failed at load** (x1.107; marks worked out in 70% of frames): **jmfix** (live, rel-m310) works them out only when the hand leaves the parts they cover, 72 to 162 frames of 1,200, the car x0.95 to 1.01 |
| 5 | buildorder2 | **the owner's choice**, not started | hidden steps 10.4% (bar 8%) and the build check 5.2% (bar 4%) stand as buildorder left them |
| 6 | keptbuilt | live, rel-m308 (18 Nov 01:28Z), after kbreview and kbfix | met: a set marked Built leaves the bin's counts, What can I build? and `mine=true`; one count per set number however its marks sit (two copies, one built, 3 missing: 7 whichever way, was 7 or 10); the site's pool left out missing parts as the app does, a live fault fixed (17 against 20) |
| 7 | smalls4 | live, item 1 in rel-m305, the rest in rel-m307 | met, items 1 to 8: Ctrl+Shift+H opens Find and replace (Ctrl+Shift+F under LDCad's keys), the bin stays beside Stress, Edit fits 1280 x 720, a model that tips is offered a foot, makerfold, a tablet's typed turn, Simulate's driver in 2 taps, and `save_model` then `open_model` |
| 8 | pointfast (as pointfix) | live, rel-m308, with **pollreads** | met in its own runs: the point queued behind the pointer's send (114 to 244 ms), a poll that missed points while joining (356 ms) and points held behind the bin's picture read-back (817 ms on live) fixed; pointat 3 of 3 at loads 52 to 80; a poll reads who is in once (1.35 to 1.01 reads). **Not met under load:** rel-m313's train failed pointat beside other checks and passed it alone, and "the second tab draws each" read p95 1,714 ms. **smalls7** is on it now |
| 9 | grabseat | live, rel-m309 | met: picked up by X, 41 of 177 joints went on by the one picked up by, now 177 of 177; by a Select drag 16 to 177; to 0.01 LDU; the bin's parts seat as before |
| 10 | mcpreach2 | live, rel-m309 | met but one count: no answer counts a session's own earlier turns as other chats; `where_to_attach` with nothing selected is the whole model, a picture in 1 call; a turntable says the camera circles the model; `submit_design pool`. **y6 took 13 and 16 calls** in two runs against 15 (from 26): the 16-call run met an unpinned motor's "nothing to lift", fixed in smalls6 |
| 11 | hubprogram | live, rel-m313 (19 Nov 04:14Z), after hpreview and hpfix | met: a SPIKE Prime large motor's arm runs repeat 3 / to 90° at 50% / wait 1 s / to 0°, 9 moves in 4.03 s as worked out, and stalls at 26.300° where spikemotors says; one PROGRAM line kept byte for byte through undo, two saves, a reopen, a copy and a sub-model; 1 call over MCP; 8.3 ms a frame or less |
| 12 | rareswap | live, rel-m313, after rsreview and rsfix | met: 79 rare lots on 10 models, 61 swapped for a part in 20 or more sets, by ΔE 2000 or the same mould, 18 where no swap exists; rare lots 79 to 24 in one undo, byte for byte back; after rsfix, 0 of 735 picks over ΔE 10 or across a finish, a held part kept; `replace_parts rare` in 1 call |
| 13 | stepsearch | live, rel-m310 (18 Nov 15:01Z, inside 5374239c5) | met: the car's steps found by part, name or colour within 72 ms (Orthanc 61 ms, bar 100); `edit_steps find` in 1 call |
| 14 | partplaces | live, rel-m310, after ppreview and ppfix | met: a place set by part and colour, kept through a reload and on the account; the parts list sorted by place; the booklet's callout "from drawer 3"; 1 call over MCP. ppreview's High (Enter sent twice) and nine more fixed before it shipped |
| 15 | design22, then design23 and design24 | **NO-GO**, records merged | design22: the outline's sizes won head to head 56% but lost likeness 44%, against the set -6. design23: a box as a bound with depth from the plan lost 22% head to head. design24: a feature's form, asked before the first build, won the screen 63% head to head, but on the paired 44 it was +2 subjects against the set (-5 to +10), surface -14, and 36 of 44 passed the build check (the base 37). Below, in full |

From APP_UX9's Next, **posehold** is built too (live in rel-m313): a posed joint holding more than its cited friction is marked
("holds 71% of what hangs on it"), a Technic ball at 2.85 N·cm and a friction
pin at 1.04, 11 real sets hold at the box's pose, and `pose_model` says it
in 1 call.

Also landed in the round, beyond APP_UX9's list:
- live: pollreads, kbfix, jmfix, socialdesk and sdpolish, connectfix and
  redditway, Claude in /admin, Notifications and Announcements
  (rel-m311.4);
- live in rel-m313: smalls5 and s5fix, mergekeep (a booklet's page settings stay
  on their own step through every step edit), phonetruth
  ([PHONE.md](PHONE.md)), m312fix;
- in `pre261` for rel-m314: webstart11, smalls6 and s6fix, stepmoves and
  smfix, insights (/admin › Analytics), and nothreads (an iPhone's engine
  without threads, behind the owner's switch and off until **weighpace**,
  the lead's task 128);
- running: keepbytes (three files a save or undo changes on live) and
  smalls7 (Motions on a 664-pixel iPhone, and pointat's and app_host's
  timing under load).

Round seven's and eight's units still not built: filmsound, realjoints5,
modsteps, panelside, camerakeys, swoosh, agesteps and pilecount.

This file measures the app a tenth time, by hand, on phones and through a
person's own Claude over the connector. It says where the field still does
better, names the features no tool has that a builder would value most,
judges each, and ranks them with the gaps. Then it plans round ten in waves
the lead can start at once, the next design unit first.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second. The owner asked,
in their own words, for the studio to be good on phones; [PHONE.md](PHONE.md)
is the measure. Left out, as the owner has parked them: payments, the
desktop downloads ("Coming soon"), BrickBench submissions, new languages,
provider API keys, and kinefuncs2 and buildorder2.

## How it was made

- **The tasks over MCP, through the connector, as the owner's Claude goes**
  (APP_UX9's runner, `run.sh`, from a locked snapshot of `pre261` at
  `3e6e46f05`, imported first):
  - the app runs as a signed-in tab of a throwaway account, opened through
    the relay (`relay_account.mjs`) and closed at the end;
  - Claude Code reaches it as an http MCP server at the relay's `/api/mcp`
    with the account's token, as `realset.py --via relay` does;
  - `claude -p` on the subscription, the Brickworks server alone,
    `--tools ""`, `--restricted`, and no API key, holding a slot of the live
    database's lock (`live_db.sh`).

  One turn per task, in six sessions:
  - the walk's ten (t1 to t10);
  - the pod's three and round eight's eight (s1 to s3, y1 to y8);
  - **round nine's seven** (r1 to r7), new: a motor's program, a click
    hinge held at 90°, a beam's connection points, a step found by what it
    places, a set marked built, where parts are kept, and rare colours;
  - APP_UX9's frontier six (f1 to f6);
  - **this round's frontier six** (g1 to g6), new: a build compared with
    its set, a joint locked, a finishing pass, a swing, a boat from one
    set's parts and its booklet's hardest step;
  - APP_UX8's seven (n1 to n7), last, as they are the longest.

  Rounds three to seven's tasks were not run again: each task bills the
  subscription the team's own sessions run on. Calls are counted from the
  sessions' own streams.
- **The web, on live brickworks.diy** (rel-m311.4, `15b59b46b`, until 04:15Z; rel-m313, `b7d74c04a`, after it):
  - `load_check`: two cold and two warm loads and a part picked from the
    bin, on broadband, with live's own flows (a worktree at live's commit);
  - **a phone's first visit and return on Playwright's WebKit as an
    iPhone 13** (390 x 664 once Safari's bars are drawn) and Chromium as a
    phone (390 x 844), by `phonetruth_flow --steps=load`;
  - **the walk by finger**, `phonewalk_flow`'s 23 acts, at 390 x 844 and
    1024 x 768 on Chromium, and **on WebKit as an iPhone 13**, each on a
    throwaway account of its own;
  - 22 of the release's browser checks for the flows a builder meets, on
    throwaway accounts under the live database's lock, from live's own
    flows: placing, the bin, a set's bin, sub-models, steps, the booklet
    and its editor, render, share, the collection, Build together,
    pointing, the gallery, a model's page, the first steps, phone, tablet,
    the library, sets, Technic, Brickify and lists.
- **The walk, a tenth time:** appux8's script as uxplan9 left it, at
  1280 x 720 and 1400 x 900, from the same snapshot, on the GPU. No section
  was added: round nine's features each have a probe, run after it.
- **Round nine's bars** read off each merged unit's probe on the snapshot,
  one at a time: `balljoints`, `jointmarks`, `grabseat`, `stepsearch`,
  `hubprogram`, `rareswap`, `posehold`, `mcpreach2` and `keys3`. keptbuilt's
  and partplaces' probes make accounts in production and were run on live
  by their own units.
- **The field,** from each tool's own pages, release notes, commits and
  papers as of 18 and 19 November 2026.
- **Not run:** Studio itself; the in-app assistant on a key (it spends
  money); claude.ai's own connector page (the relay is the same server,
  reached the same way).
- **The box was shared** with rel-m313's by-hand ship and its 13 checks,
  keepbytes, smalls7, nothreads' last runs and other projects' tests. The
  load was 23 to 68. Its solo timing checks held every heavy job of the
  project from 04:06Z to about 04:14Z, so the MCP walk went first. Seconds
  are stretched by the load; counts are not.

## What the walk measured, ten times

The first seven rounds' figures are in APP_UX4 to APP_UX8. Both sizes ran
from the snapshot on the GPU, at loads of 23 to 63, and every Godot quit
cleanly.

| act | appux9 (1280 / 1400) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|
| desktop start, the first 120 frames | 7.7 / 6.9 s | 8.5 s (load 23 to 39) | 9.7 s (load 39 to 63) | walk |
| bin tiles in sight on the first open | 24 / 42 | 24, every one named | 42, every one named | walk `counts` |
| keys sheet (F1), rows in sight | 32 / 46 of 161 | 32 of 162 | 46 of 162 | walk `counts` |
| commands with a key | 120 of 232 | 120 of 233 | the same | walk `counts` |
| the tallest menu, rows (height) | Edit 25 (486); File 23 (460) | **File 24 (482)**; Edit 23 (442); View 22 (456) | the same | walk `menus` |
| a wall of eight 1 x 4s from the search | 20, 3.3 / 3.9 s | 20 events, 3.1 s (3.8 s the second time) | 20, 4.9 s (3.5 s) | walk `wall`, `round6` |
| the ghost following the pointer, 3 frames a move | 44.8, worst 67.2 / 55.7, worst 84.9 | 38.1 ms, worst 74.2 (48.5, worst 111.5) | 64.6, worst 89.6 (68.0, worst 110.5) | walk `wall`, `round6` |
| R on a brick in a wall; a brick alone, 3 x R | 15.0°; 45° | the same | the same | walk `turns`, `dialogs` |
| panels and dialogs | 22 of 24, 0.75 to 1.57 s | 22 of 24, 1.03 to 2.31 s; Compare and Pattern greyed, as before | 22 of 24, 1.69 to 3.00 s | walk `dialogs` |
| search, 30 words | 27: the same three not first | the same | the same | walk `search` |
| the car's instructions, 240 frames | 3.3 / 2.7 s | 3.8 s | 3.4 s | walk `round3` |
| Cut away by a box | 0.9 / 0.8 s | 1.0 s | 1.6 s | walk `round4` |
| a 2 x 4 clicked with Stress open | the bin gives way | **the bin gives way still**, back by its rail | **the bin stays in sight** (smalls4) | walk `round7` |
| a 4740 dish on a 6141 round plate by hand | 14.14 LDU across / seated | 14.14 across: the click missed the plate, as before (the walk's own) | seated: 0.00 across, 8.00 above | walk `round7` |
| Check stability on the car | 21 / 16 ms | 17 ms, "a 34° tilt tips it" | 48 ms | walk `round7` |
| **Edit › Find and replace, Ctrl+Shift+H** | the key opened nothing | **opens in 1 press**; two Black 3023s Dark Bluish Grey in 16 ms, one undo to the byte (smalls4) | the same, 12 ms | walk `round8` |
| the tower on one corner stud, Stress open | "0 past working load"; Strengthen not offered | the same words, and **Strengthen offered**: "adds a Brick 2 x 2 under its right side … Then it stands" (smalls4) | the same | walk `round8` |
| **Stress › Lift, the tower's top brick clicked** | 295 / 191 ms: "everything comes with it, 22 g" | **not lifted after 26.7 s**: "Click the part to lift the model by." | **not lifted after 35.8 s**, the same words | walk `round8` |
| View › Reset panel layout | the bin back | the same | the same | walk `round8` |

The search's three that are not first are the walk's own answers, as
before: "jumper" sixth, "macaroni" fourteenth, "bracket" fourth. 113 of
233 commands have no key. View has a row more (Connection points) and
File one more; Edit is two shorter.

**Found on the way:**
- **Lift no longer lifts in the walk** (`round8`), at both sizes. In
  round nine it took 191 to 295 ms after the same click. Now the click
  waits 27 to 36 s and Stress still asks for a part. Since then
  Strengthen is offered over the same tower, and the walk presses it
  first, so the click may land on a model that has changed under it.
  It is reproduced first, by hand and by `loadtest`'s probe, before
  anything is fixed (smalls8, item 1).
- **At 1280 x 720 a click with Stress open still puts the bin away,**
  where 1400 x 900 keeps it (smalls4 fixed the larger size). The bin
  gives way to Properties when a part is selected at that height, as
  APP_UX9 said, so it is the walk's own unless a person meets it too
  (smalls8, item 2: by hand first).
- **File is the tallest menu again,** at 24 rows and 482 units; at
  1280 x 720 it fits (`keys3` below).
- **The dialogs open later,** 1.0 to 3.0 s against 0.75 to 1.57. The load
  was up to 63 against 28 to 36, and each still opens in its 90 frames,
  so this is the box until a same-moment pair says otherwise.

## The web

`load_check` on live brickworks.diy (rel-m311.4, `15b59b46b`), on
broadband, at loads of 40 to 50, against APP_UX9's runs on rel-m303 at 27
to 33:

| | appux8 (rel-m281, load 26 to 38) | appux9 (rel-m303, load 27 to 33) | now: rel-m311.4, load 40 to 50 | from |
|---|---|---|---|---|
| first visit, cold, to working | 17.9 s | 16.3 s | **24.0 s** (26.6 and 21.5) | `load_check` |
| warm | 11.8 s | 9.3 s | **14.6 s** (12.4 and 16.9) | `load_check` |
| the network, cold | | 8.3 s | 10.6 s | `load_check` |
| main thread, cold | 9.0 s | 8.8 s | 10.6 s | `load_check` |
| the engine's banner, cold | 5.3 s | 5.8 s | 7.1 s (7.8 and 6.3) | `load_check` |
| the scripts' compile, cold and warm | 4.1 s and 4.0 s | 4.1 s and 3.5 s | **6.3 s and 5.2 s** (6.9 and 5.7; 4.0 and 6.4) | `load_check`'s phases |
| a part from the bin to its ghost, the longest | 461 cold, 311 warm | 566 and 2,183 cold, 275 and 331 warm | **5,312** and 2,189 cold, 1,222 and 670 warm; 0 part files fetched for it | `load_check --pick` |
| bytes before working | 16.84 MB | 16.84 MB | 17.01 MB | `load_check` |

**The seconds are mostly the box's.** The load was half again APP_UX9's.
The banner grew by 22%, the main thread by 20% and the network by 28%;
the scripts' compile grew most, by 54%, as the phase that needs a core
the longest (webstart11 found the same). The bytes grew by 0.17 MB. Two
lines are worth a person's notice:
- **the first pick after a cold start took 5.3 s** once and 2.2 s the
  other time, with no part file fetched for it, and JointMarks' first
  load 39 to 58 ms of it. APP_UX9 saw 2.2 s once. It is a fault that
  shows only at load, on the first pick, and nothing names what the 5 s
  waits on (smalls8, item 2: measure it first);
- the data pack is asked at 5.9 to 7.5 s and comes at 13.3 to 16.5 s, so
  the start waits 0.2 to 0.4 s for it, as before.

**A phone's first visit, on live** (`phonetruth_flow --steps=load`, at a
load of 66 to 68):

| | PHONE.md (17 Nov, rel-m309) | now: Chromium as a phone, 390 x 844 | now: **WebKit as an iPhone 13** |
|---|---|---|---|
| first visit, cold, to working | Chromium 10.5 s; WebKit 12.4 (iPhone 15) to 21.3 s (iPhone 13) | 19.0 s | **19.3 s** |
| … the engine's files had come | | 1.8 s | 4.4 s |
| … the engine started | | 14.5 s | 14.0 s |
| … started once its files had come | | 12.6 s | 9.6 s |
| … over the wire | | 9 MB | 19 MB |
| a return, to working | | 14.0 s | **16.6 s** |
| peak memory, first visit (the process / Wasm) | 519 MB Wasm | 798 MB / 519 MB | **1,810 MB / 519 MB** |

On live the Wasm memory is still **519 MB** at the start: webstart11's
432 rides rel-m314. On WebKit the whole process peaks at **1.8 GB**,
where an iPhone 13 reliably gives a page about 300 MB of Wasm. After its
files have come, the engine's own start is 9.6 to 12.6 s on both engines:
that is the compile and the first window, at this load, and it is the
whole of the gap to a native app (webstart12).

**phonewalk on live** (rel-m313), by finger, each on a throwaway account
of its own:
- **Chromium, 390 x 844 and 1024 x 768:** 46 of 46 acts tried, **44 done**,
  2 in more than twice the desktop's presses, **0 controls under 44
  points** (APP_UX9: 45 done, 1 over twice, 0 small).
- **WebKit as an iPhone 13, 390 x 664:** 23 of 23 tried, **21 done**, 1
  over twice, 0 small. The first run of the walk on WebKit.
- **The two not done are the same two on both engines, both in Motions**
  (`src/ui/pose_panel.gd`): the suggested motion's Keep took no tap (5 and
  6 taps against 3 presses), and a finger's drag of a joint's slider moved
  no joint (3 taps against 1 drag). APP_UX9's walk did both. smalls7 is in
  Motions' panel now for its height on a 664-pixel iPhone; these two go to
  it or, if it has merged, to jointlock (wave 2).

**22 of the release's browser checks on live,** on throwaway accounts
under the live database's lock, at loads of 23 to 66, from live's own
flows (rel-m313 from 04:15Z):
- **18 passed with no line failed:** placing, the bin, a set's bin,
  sub-models, steps, the booklet and its editor, share, the collection,
  lists, the gallery (47 lines), a model's page, phone, tablet, the
  library, sets, Technic and Brickify. The storage mirror served every
  part file; the bucket was asked 0 times.
- **first_steps gave way:** the live database stayed held by rel-m314's
  preview checks for its 60 minutes.
- **render, Build together and pointat did not run:** the batch reached its
  150-minute bound first, at a load of 31 to 66. pointat's timing under
  load is smalls7's, running.

## Over MCP: the tasks as the owner's Claude does them, through the connector

47 tasks in six sessions took **300 calls in 43.2 minutes** of the
sessions' own time, every call through the relay's `/api/mcp`, from 04:11Z
to 04:59Z. No task errored.

**The walk's ten and the pod's three:** 42 calls in 6.2 minutes, against
37 in 4.5 in APP_UX9. The rows that moved:

| task | APP_UX9: calls, time | now | what the session did |
|---|---|---|---|
| t3: paint three bricks blue | 2, 9 s | **1, 11 s** | no `look_at_model` first: the relay no longer counts its own earlier turns as other chats (mcpreach2) |
| t7: a beam 7 standing, a pin in its second hole | 8, 72 s | 11, 147 s | the beam falls on its round end, rightly; five `check_design`s to find a stand of plates and a 1 x 2 Technic brick |
| t9: move the top row three steps later | 3, 14 s | **7, 30 s, not all of it** | the last brick could go only two steps later: `next` at the last step and `new` on that step's one part each answered "the steps are as they were", with no reason (mcpreach3) |
| s1: the side pod | 7, 54 s | 7, 55 s | the same |

**Round eight's own:** y1 to y5 and y7 as in APP_UX9, in 1 or 2 calls each.
y8 (7140-1's numbers out of date) is 4 calls, the save then the open, now
with no "not saved" (smalls4). **y6, the SPIKE motor lifting a beam, took
32 calls in 289 s,** against mcpreach2's 13 and 16: the motor stood on
four 1 x 1 bricks, each on one stud, so Simulate rightly saw the motor
free to turn, and the session moved it to bricks with side studs in its
back face. The answer was right ("it doesn't stall"); the mount took 20
of the calls (mcpreach3).

**Round nine's own** (new this round):

| task | calls, time | what the session did | the gap |
|---|---|---|---|
| r1: a SPIKE motor's program, three times to 90° and back, played | **30, 262 s** | the program ran: "the arm swings up and back three times", each swing 0.17 s at half speed. The program itself was 1 call (hubprogram); the motor's mount took most of the rest, as in y6 | **mcpreach3** |
| r2: a click hinge arm held at 90°: will it droop? | 14, 95 s | built; the hinge was not a joint until the session named its arm as an assembly ("Nothing here turns … Name the part that turns as an assembly"); then "Click hinges here: 1, not weighed: no one has published what one holds", so "that part of the answer is my own estimate" | **mcpreach3**; the hinge's hold is unmeasured (open question 2) |
| r3: the beam with every place a pin could go marked | **1, 22 s** | a close picture with every hole marked (jointmarks) | none |
| r4: which steps put in a Technic part; the first | **2, 17 s** | steps 1 to 5, each named (stepsearch) | none |
| r5: set 31058-1 added, marked built | **2, 15 s, not done** | "I can't add a set, only loose parts"; Built refused as "not a set in the person's collection" | **mcpreach3** |
| r6: loose parts added with their places; where each is kept | **3, 18 s** | both lots added and placed; "only one of them … is something you have and have a place for" (partplaces) | none |
| r7: 7140-1's rare colours swapped where it still looks right | 6, 38 s | 7 of 126 lots rare; 1 swapped, as rareswap judged the rest would change the look | none |

**APP_UX9's frontier six again:** f1 (an arm on a ball, raised 30°) in
**15 calls** (APP_UX9: 38; balljoints' bar 15); f2 (42124-1's functions)
"neither of the set's two motor functions works" (kinefuncs2, the owner's);
f3 in 9; f4's turntable in 2, saying "the camera" goes round (mcpreach2);
**f5 in 1 call** (APP_UX9: not done); f6 in 5.

**This round's frontier** (the gaps the field showed):

| task | calls, time | what the session did | the gap |
|---|---|---|---|
| g1: 7140-1 opened, two parts changed, compared with the set step by step | **2, 24 s, not done** | it would not open the set over the unsaved car, and **`save_model` refused to save the car**: "Not saved yet: 2 of its 2 features are not settled (wheels, cabin)". The session stopped and asked the person which of three ways to go | **mcpreach3** (a save never refused); **setcheck** behind it |
| g2: a hinge at 45°, locked, then turned | 8, 49 s | "None of my tools can lock a joint, so when I tried turning it, it moved" | **jointlock** |
| g3: a house with a stepped roof, then a set designer's finishing pass | 14, 165 s | done through `review_model` and `settle_surface`: the AI reaches the surface pass, the window does not | **finishpass** |
| g4: a child swooshes the house by its roof: what comes away first | 3, 23 s | Lift by a ridge brick, still: "everything comes up with it, 82 g … that brick's four studs carry the whole". No speed or swing | **swoosh** |
| g5: a boat from only 31058-1's parts | 10, 145 s | 19 pieces, each checked against the set's inventory (`submit_design pool`) | none |
| g6: its booklet; which page holds the hardest step | 6, 31 s | a 6-page PDF; "my judgement … the app doesn't score how hard a step is" | buildorder2's own (the owner's) |

**APP_UX8's seven:** n1 to n5 and n7 in 0 to 13 calls each, as before.
**n6, a fire engine at a City set's quality, took 36 calls in 5.8 minutes,**
against 80 in 12.1: built, saved and standing, but "over the part budget
and plainer than a real LEGO City set" (the design track).

**Where a session still needed more than the window, or guessed:**
1. **`save_model` refuses while a design's features are unsettled** (g1).
   A person's own copy, asked for before an open, is never refused: the
   answer names what is unsettled and saves (`app_tools.gd`'s save; the
   feature gate stays on `submit_design`'s finish).
2. **`edit_collection` cannot add a set** (r5): sets come in only by the
   window's My collection. It adds a set by number, and Built on it, in
   one call, as the window does.
3. **A click hinge is not a joint until it is named** (r2): `pose_model`
   finds a hinge's moving half as a drag does, with no assembly asked.
4. **A motor's mount** (y6, r1: 32 and 30 calls): `attachment_points` on
   a SPIKE or Powered Up motor names the faces real sets mount it by (its
   pin holes and frame), and a motor on single studs is said to swivel
   before Simulate runs, not after.
5. **`edit_steps` says why nothing changed** (t9), and `next` from the
   last step makes a new step, as a person's Alt+] does.
6. **Each answer carries the tab's 420-character line on other chats**
   (every call of t9's seven). It is said once as a chat begins and again
   only when another chat calls, as its own words promise.

Every call of every task is in `mcp/run/` (one stream a task).

## Round nine, item by item

Each unit's bar, read off its own probe today on the snapshot (`pre261` at
`3e6e46f05`), or off rel-m313's train (18 November, 13:10Z) where the
probe is headless and today's queue did not reach it. "Met" means every
line of the bar that ran passed.

| unit | its bar | today |
|---|---|---|
| balljoints | real ball joints seated by hand at the set's place; a turn about the ball; f1 in 15 calls | **met**: 34 checks, 1,109 of 1,109 both ways round; the MCP walk's f1 in 15 calls through the connector |
| jointmarks (and jmfix) | a beam's holes within 1 px; nothing written; frame cost within 10% | **met**: 78 checks, the seven holes within 0.54 px; the MCP walk's r3 in 1 call |
| grabseat | every joint by the one picked up by, to 0.01 LDU | **met**: "grabseat: passed" |
| stepsearch | a step found by part, name or colour within 100 ms | **met**: 46 checks; the car 62 ms, 7140-1 36 ms, Orthanc 88 ms of its own; r4 in 2 calls |
| hubprogram | the program drives the motors; 1 call | not run today (queued behind a solo timing check at the bound); its unit met it, and r1's program was 1 call |
| rareswap | rare lots swapped only where the look holds; 1 call | **met** on rel-m313's train (133 checks); r7 in 6 calls, 1 of 7 swapped, the rest refused as changing the look |
| posehold | a posed joint over its friction marked; 1 call | **met** on rel-m313's train (52 checks); but r2: **a click hinge is "not weighed: no one has published what one holds"** |
| mcpreach2 | t3, y6, f4, f5 in their counts | **t3 1, f4 2, f5 1 met; y6 32 against 15, not met** (the motor's mount, above) |
| keptbuilt, partplaces | Built leaves the counts; places by part and colour | r6 met in 3 calls; r5 could not add the set at all (above) |
| smalls4 | the walk's faults | Ctrl+Shift+H, the bin beside Stress at 1400, Strengthen on the tower, y8's save: **met**. The bin at 1280 x 720 still gives way (the walk's own, as before) |
| webstart10, webstart11 | first visit; Wasm 432 MB | live keeps 519 MB until rel-m314; the start's seconds above |
| pointfix, pollreads | the second tab within 500 ms | not run on live today (the checks reached their 150-minute bound first); smalls7 is on it |

**Nine of round nine's units met their bars today** where they ran.
mcpreach2's y6 did not, and the first_steps, render, Build together and
pointat checks did not run on live in the time.

## What the field does that Brickworks does not, yet

The latest versions, as of 18 and 19 November 2026, read from each tool's
own pages (saved in `bench/results/uxplan10-2026-11-19/sources/`). Only
what APP_UX9 did not cover is new here.
- **Studio 2.26.10_1** (27 October), unchanged. The release data in the
  download page (its server's clock at 18 November 22:49, UTC-5) still
  ends there, and the Early Access log ends at 2.26.10_1 (29 October). The
  help centre has 125 articles, none edited after 25 September; none
  mentions an iPad or a phone. BrickLink is back online after its outage
  (BrickFanatics, its archived copy of 15 November).
- **Mecabricks:** no release; `workshop.js` still last changed
  31 October 2022. Its forum since 15 November is two questions.
- **LeoCAD 26.09,** and a continuous build of 19 November 03:22Z that
  snaps studs while dragging, from connection data it now bundles: "Snap
  stud connections during dragging", "Preserve the mouse-down grab point",
  and "Rotate dragged bricks to seat more stud connections".
- **LDCad 1.7 Beta 2b,** its pages the same to the byte as on 15 November.
- **StudWorx 2026-11-18,** published 18:11Z. Its notices since 11-15:
  - 11-16, instructions: undo and redo in the instructions; "Step Flow …
    row by row or column by column"; Show Final Model; a cover title,
    author and BOM title from your own text; "Model Size … from 10 to 200
    percent"; "new part outlines follow only what can be seen";
  - 11-17: "parts grouped with a jointed submodel turn along with its
    joint", Ctrl turning a whole sub-model round a hinge; "Highlight Width
    … from 1 to 72"; Show Part IDs in the bill of materials; a lock on each
    page, and a snowflake that "freezes" a page against all-page changes;
  - 11-18: "a Lock column freezes a joint, saved in the file; a locked
    joint … can't be moved, turned, edited or deleted"; joint mode with
    "every joint shown as a ring to click"; keyframes picked by Ctrl+click
    and deleted together; Esc leaves one mode per press, innermost first.
- **BrickAgent, BrickNet and BrickBench:** unchanged (PyPI the same to the
  byte; brickben.ch's page, script and gallery the same). The leaders:
  GPT-6 Astra (valid 1.00, ELO 1297), GPT-6.1 Sol (1.00, 1293), Claude Opus
  5.5 (0.99, 1249), BrickWright (0.99, 1136), Claude Opus 5 (1.00, 1101).
  Nothing was submitted.
- **Kinebrick:** **701 of its 1,226 functions work (57%)**, from 673 on
  15 November; 239 partly, 107 not, 179 skipped. "Only 25 of the 186 sets
  have every function working." Kinebrick Studio is still v0.2.0-beta.1.
- **New since 15 November:**
  - **bicheck** (18 November): "Finds where an LDraw model differs from the
    set's LEGO building instructions … and in which step each wrong part
    goes", line by line ("step 58 … WRONG COLOUR: wants 3710 Dark Tan (28),
    model has 3710 Tan (19) at main.ldr > east-wing.ldr, step 49, line
    358").
  - **Brick Workshop's Brick Studio** (a browser builder): "Smooth
    surfaces … dresses the whole build as one undoable edit" (outside
    corners round, cheese and curved slopes on steps, tiles on open plate
    edges); a Claude draft from up to four photos; .skp, .dae and .glb
    models into bricks; a PDF manual.
  - **Brick Creator 3D 1.1.1** (19 November, iPhone and iPad): "Tap to
    place, drag to move … Double-tap a brick to rotate it … two-finger tap
    to undo"; a public gallery with hearts and comments, where you can
    "Report creations or block authors".
  - **LEGOGOD** (17 November): a sentence in, a checked build out, on the
    web and in a native Android app.
  - **BrickFlow's code** (16 November, `pip install brick-flow`; its
    models are a 3.81 GiB download), **DailyBrick's paper** (arXiv
    2611.22132: a "Meta-Reviewer agent replays and inspects the generated
    package"), **mesh2brick** 2.0 and 2.1 (tiles by default, slopes on round
    shapes), and **Mister Blocks** (easy builds 45 to 72, a French site).
  - Hacker News has no LEGO CAD story since 15 November. Eurobricks
    (Cloudflare) and Reddit (404) could not be read.

Each item was checked against `shell.gd`'s commands, `tools/mcp_tools.json`
and the files named. Ranked by how much a person building would feel it.

**The window**
1. **Where my build differs from the set's booklet, step by step**
   (bicheck). Anyone rebuilding an official set, or checking a MOC's
   instructions against its file, meets it.
   - Brickworks: "Compare two sets or models…" gives "the parts … in only
     one, and what to buy" (`shell.gd` 1189 to 1190, `parts_compare.gd`
     `PartsCompare.between`), and "Compare with…" this model's own saves.
     Neither says which step a part belongs in, nor where in the model the
     wrong one sits. The set's own file, with its steps, is in the library
     for 1,576 sets (`vendor/omr/files`).
2. **A joint locked** (StudWorx 11-18).
   - Brickworks: "Lock the selection" (`shell.gd` 1312) locks parts; Pose
     and Motions (`pose_panel.gd`) have no lock, so a posed figure's knee
     set just right moves with the next drag of the shin.
3. **A finishing pass in one press** (Brick Studio's Smooth surfaces).
   - Brickworks: `surface_pass.gd` tiles open stud fields, slopes plate
     staircases, rounds a body's top edges and skins its flanks, but only
     the AI reaches it (`review_model {"surface": true}`, `settle_surface`).
     A person who built by hand has no command for it.
4. Smaller:
   - a dragged part turned to seat more studs (LeoCAD's build of
     19 November). Brickworks keeps the person's turn (`joint_snap.gd`),
     which is the CAD's choice; low;
   - StudWorx's highlight width, a page locked or frozen against all-page
     changes, and keys picked and deleted together (`booklet.gd` 33 to 39
     has the outline on or off; `page_setup_dialog.gd` sets every page;
     `pose_panel.gd` 2050 deletes one key) (**smalls8**).

**Phones and tablets**
5. **A two-finger tap undoes** (Brick Creator 3D, as iOS's own apps and
   Procreate do).
   - Brickworks: Undo is a button in the phone's top bar
     (`phone_shell.gd` 177, 222); two fingers only turn and pinch
     (`cad_camera.gd` 344 to 445), and no tap gesture exists in `src/`.

**The site**
6. **Block a person** (Brick Creator 3D's gallery).
   - Brickworks: a comment can be reported (`api/_comments.js` 415) and a
     model's owner can hide it. Nothing blocks a person: not
     `api/people.js`, `_follows.js`, `_trust.js` or the pages.

**Mechanisms and AI tools**
7. **Real sets' functions working:** Kinebrick 701, Simulate 391. The gap
   grew to 310 (kinefuncs2, the owner's choice).
8. **A model rebuilt from a photo of it** (BrickFlow, runnable now on a
   GPU). Brickworks' photo search names one part (`brickognize.gd`), and
   the person's Claude reads a picture for a reference. Not ranked: it is
   a research model, not a feature a builder reaches for yet.

Checked and **not gaps:**
- LeoCAD's stud snapping while dragging, and its grab point kept
  (`joint_snap.gd`, `builder.gd`; grabseat);
- StudWorx's Show Part IDs (the booklet's parts list prints the element
  number), Show Final Model and a cover's title and author
  (`booklet.gd` 22, `page_setup_dialog.gd`), joint rings (Motions gives
  each joint a slider and records by dragging the parts), and parts
  turning with their joint (carryrest);
- mesh2brick's tiles and slopes and Brick Studio's models into bricks
  (Brickify lays slopes, curved slopes, wedges and tiles from .obj, .stl,
  .ply, .3mf, .vox, .fbx, .gltf and .glb; it does not read .skp or .dae);
- Brick Studio's stand-and-tip check, PDF manual and photo draft
  (`check_design`, the booklet, `find_reference`);
- LEGOGOD (`submit_design`), Kinebrick Studio's hub programs
  (hubprogram), DailyBrick's reviewer (`review_model`, the own look),
  a gallery with hearts and comments (live).

## Past parity: what no tool has

Five candidates were judged on what Brickworks has today, what the field
has (from its own pages) and what a person building would feel. Two are
worth a unit now; one waits on a measure; two are already built.

**1. A model swung like a toy: what comes away first.** A spaceship
swooshed by a child loses its wings first, and a builder learns which only
by losing them.
- **Brickworks today:** Lift (loadtest) hangs a model from a part, still;
  posehold weighs a posed joint against its cited friction; stabletruth
  measured the stud's hold (1.92 N).
- **The field:** none. BrickSim and StableLego weigh still models only.
- **What is missing:** speed and a turn added to Lift's sum: the model
  held by a part and swung through a child's arc, every joint's load at
  the swing's worst, and the first to let go named.
- **Judged:** worth a unit now (**swoosh**). Every number it needs is
  measured. The MCP walk's g4 asked for it, and Lift gave a still answer (above).

**2. A model rebuilt from what I own.** A builder with a collection and a
model from the gallery wants to build it tonight, not after an order.
- **Brickworks today:** ownlimit counts what is left of the person's
  parts at each step; rareswap swaps a rare colour for a common one where
  the look holds (ΔE 2000 or the same mould); setsbuild ranks every set by
  the share owned.
- **The field:** Rebrickable matches sets against a collection. No tool
  changes a model's parts to the ones you own.
- **What is missing:** for each lot not owned, the nearest owned part of
  the same shape in the nearest colour, or the same colour in an equal
  part, chosen by rareswap's own matcher with the collection as its pool,
  applied in one undo, and what is still missing said.
- **Judged:** worth a unit now (**ownswap**). It writes the model file, so
  one review.

**3. A photo of my build checked against the booklet's step.** A child at
step 23 holds the phone over the model and is told the 2 x 4 is one stud
too far left.
- **Brickworks today:** the booklet on a phone, step by step; the person's
  Claude can read a photo and `view_model` a step's picture.
- **The field:** bicheck compares a model's file with the booklet;
  BrickFlow rebuilds a model from a photo, as research.
- **Judged:** high value, but whether a photo can be read to a stud is
  unmeasured. Next: a task in the next MCP walk, a photo and a step, before
  any unit.

**4. A pose that holds its own weight:** built (posehold, live in rel-m313).

**5. Instructions that say where each part is kept:** built (partplaces,
live).

## The design track: why it lost five times, and the next lever

The realset win rate on the connector path is the owner's first measure.
Its latest base is **24% overall (14 to 38%)** against the real set on the
44 held-out subjects (`d24p44base`, `pre261` at `33f1006dd`, run 17 November;
likeness 30%, technique 9%). The lever arm beside it read 26%.

Ten likeness levers in a row have lost, design15 to design24, and the last
five in this run:

| unit | its lever | the screen (16 tune subjects) | the proof (44 held out) | its Next |
|---|---|---|---|---|
| design20 | `review_model` lays the model's silhouette over the real thing's outline, read off a photo | a smoke of 5: likeness 1 to 1 of 10, a defining feature named wrong in 9 of 10 both ways | not run | build to the outline before the first build |
| design21 | the outline as the first mass, laid as a solid | reached 8 of 16, the solid sent in 0 of 8; head to head 44% | not run | the outline as sizes, with no solid |
| design22 | `plan_scale` answers in studs and plates, with breaks and setbacks | reached 9; head to head 56%, likeness 44%; against the set -6 | not run | the brief's box as a bound |
| design23 | the box as a bound, with depth, levels and storeys | reached 10; head to head 22%; against the set -11 | not run | stop moving the outline; build the features the thing is known by |
| design24 | each feature's form (open, angled, curved, twisted, tapering) asked before the first build and handed back close up | forms given 16 of 16; head to head 63%, likeness 67%, technique 60%; against the set +10 | overall 24 to 26%, +2 subjects (-5 to +10); head to head 61%; surface 42 to 28%, **-14**; technique +10, creativity +12; build check 36 of 44 (base 37) | keep the form, build it with the parts real sets use for it |

(From `docs/DESIGN_SCORES.md` on `pre261`, lines 6084 to 7315, and
`bench/results/design24-2026-11-16/`.)

**What the five have in common.** design20 to design23 moved the outline
and the massing; design24 moved the feature's form ahead of the first
build. Each changed where the bricks go. None changed which parts go
there:
- the median design is **4% SNOT in both of design24's arms, against the
  sets' 27%**, and 23% shaped parts against the base's 22%;
- where design24 lost surface, the judge's reason names the design's
  **steps in 49 of 63** and its stacked bricks in 37 (the base: 31 and 25
  of 51). The forms asked for curves, tapers and leans, and the sessions
  built them of plates stepped in, where the sets use curved slopes,
  wedges, SNOT panels and hinges;
- 38 of 44 subjects scored the same in both arms, and 29 lost every
  verdict in both: all 9 Technic sets, and 20 where the set's own parts and
  figures won.

**The next design unit, design25: the form built with the parts real sets
build it with.** Its lever, its measure, and why it and not the five
before:
- **Why this lever.** The form is the first lever in the run with full
  reach (16 of 16 sessions) that wins head to head twice (63%, 61%) and
  lifts technique and creativity against the set. What lost it the proof
  was its surface, and the surface's reason is the parts. So keep the form
  and change only what it is built of. design24's own Next says so.
- **Why not another outline or massing lever:** four of the five moved the
  outline, and the last of them lost 22% head to head. The record says to
  stop.
- **Why not a new tool:** a tool the session must choose goes unused
  (design282's angled runs: offered 6 of 6 times, used 0; design325's
  reshape: 1 of 6). The parts arrive laid, inside the close look every
  session already answers (`settle_feature`), and the session settles
  them as it settles a feature's piece today.
- **The lever, in three parts:**
  1. **A form's parts, read from real sets.** A new `tools/form_parts.py`
     reads the snippets index (9,555 named sub-models and 3,509 clusters of
     1,185 sets, `real_snippets.gd`) by form, not by name. For each form
     design24 asks (a curve in plan or in profile, a taper, a lean, an angle
     off the grid, an open frame, a slender rod) and each size, it lists the
     parts and the technique real sets of the theme used: curved slopes and
     arches, wedge plates and tiles, SNOT brackets with tiles, hinge plates,
     bars and clips. The held-out sets' files are never read
     (`realset.py`'s holdout, and its leak audit).
  2. **The close look builds the form with them.** design24's ask is put
     back (`5fe92412d`). Where `feature_pass.gd` hands a feature back close
     up, the app lays that form's parts where the session's plates step, as
     one settle: accept, the next best, or reject with a reason, with the
     picture.
  3. **Steps are said.** The close picture's check (`surface_pass.gd`)
     names where plates step on a face the form calls curved or tapering,
     and which parts the sets use there.
- **The measure** (the owner's path: the relay, no Claude Code in the tab,
  no instructions; two sessions at a time from a locked snapshot; a
  same-snapshot base arm):
  - **The screen**, 16 tune subjects: preferred overall head to head in
    both orders, likeness and technique no worse, **surface preferred**;
    the forms' parts in the final design of 8 or more of the 16 sessions;
    the median design's SNOT share 10% or more (from 4%); steps named in a
    third or fewer of its surface losses (from 49 of 63).
  - **The proof**, the paired 44 held out, against a same-night base:
    overall against the set above the base by its 95% interval's lower
    edge; **surface no worse than the base**; likeness and technique no
    worse; no more build-check failures than the base; the leak audit
    clean.
  - The mined table with its own probe (ten forms, each with parts and the
    sets they came from, no held-out set among them) is a valid first
    commit, and the record says what the screen shows if it loses.
- **After it:** the Technic subjects, 9 of the 44 and every verdict lost in
  both of design24's arms, are lost on parts, not form. Four studless
  Technic levers in October lifted technique and lost likeness (38 to 19%;
  the Technic line paused, DESIGN_SCORES lines 2242 to 2705). So the next
  is **design26**: the set's Technic parts (panels, beams as the seen frame,
  gears where they show) laid onto the System body's surface, never a
  studless body in its place, measured on the 9 Technic subjects first.

## The gaps and the features, by value to a person building

design25 is first, ahead of every rank: it is the measure the rest serve,
and nothing below takes its files or its bench's hours. Then:

1. **A phone's start is the engine's compile and its memory** (PHONE.md
   faults 1 and 2). At a quarter of this box's speed on Fast 4G, a first
   visit is 72 s, of which **the scripts' compile is 24.5 s**, and it fills
   the Wasm memory to **432 MB**, where an iPhone reliably has "only
   ~300 MB" (WebKit 269937). Today, on live: on WebKit as an iPhone 13 a first visit took **19.3 s** and the content process peaked at **1.8 GB**, with live's Wasm at 519 MB. With the
   desktop downloads paused, the browser is the only way in, and the owner
   asked for phones by name (**webstart12**).
2. **Where the person's Claude stalled or guessed** in today's MCP walk
   (above): a save refused while a design's features are unsettled (g1), a set that cannot be added (r5), a click hinge that is not a joint until named (r2), a motor's mount in 30 and 32 calls (r1, y6), and `edit_steps` that says nothing changed with no reason (t9) (**mcpreach3**).
3. **A build checked against its set's own booklet, step by step**
   (bicheck, 18 November). Compare gives a parts list with no step and no
   place (**setcheck**).
4. **A model rebuilt from what I own** (past parity, 2): no tool swaps a
   model's missing lots for owned ones (**ownswap**).
5. **A joint cannot be locked** (StudWorx 11-18): a figure's pose is undone
   by the next drag (**jointlock**).
6. **What comes away when a model is swung** (past parity, 1)
   (**swoosh**).
7. **A finger's gestures** (Brick Creator 3D: a two-finger tap undoes), and
   what today's walk by finger on WebKit found: 44 of 46 acts on Chromium and 21 of 23 on WebKit, the two not done both in Motions
   (**phonefingers**).
8. **A finishing pass a person can run** (Brick Studio's Smooth surfaces).
   The surface pass exists and only the AI reaches it (**finishpass**).
9. **A person cannot be blocked** in the gallery (Brick Creator 3D)
   (**blockauthor**).
10. **Frames on a slow phone** (PHONE.md fault 4): turning the car at a
    quarter speed costs 39 ms of the app's own work a frame at p95, and
    at a sixth 196 ms (**idleframes**).
11. **The walk's small faults** and StudWorx's smaller polish:
    Lift that no longer lifts in the walk, a 5.3 s first pick at load, the bin at 1280 x 720, a highlight width and a page locked (**smalls8**).
12. **The camera cannot be keyed** in Motions (StudWorx keys any object)
    (**camerakeys**).
13. **Real sets' functions:** Simulate 391, Kinebrick 701 (kinefuncs2, the
    owner's choice: not planned here).
14. **One booklet step in ten hides a new part** (buildorder2, the owner's
    choice: not planned here).

## The units

Fourteen rows: the design track's two, and twelve to build, in three waves.
Each unit runs in its own worktree off the next stage. The shared
registries are round nine's. A unit adds its own lines in a block of its
own and changes no one else's:
- `src/ui/shell.gd`'s `_define` and `MENUS`;
- `src/ui/keymap.gd`'s `PRESET_KEYS`;
- `src/net/app_tools.gd`'s `COMMANDS`, `WINDOW_ONLY`, `GUIDE`, its tool
  list and its dispatch, and each tool's own answer function;
- `tools/mcp_tools.json`, written by `mcp_sync_probe --write`;
- `docs-site/generated/menus.json`;
- `src/ui/language.gd`'s tables and `locale/*.po`, with every new word in
  German, French and Spanish;
- `tools/suite/*.txt`, one line a new probe.

Every feature added gets its entry in `.claude/skills/verify/` in the same
commit, and every unit runs `tools/release/unit_preview.sh` on its final
sha, on the 10 to 15 checks its change drives, before it says ready, and
attacks its own work first (`briefs/self_attack.md`).

**Units that write the model file or the collection** each get one
independent review before they merge, and attack their own save path
before they say ready:
- **jointlock, ownswap, finishpass and camerakeys** write the model file;
- smalls8's item 4 writes the model file (a page's lock);
- **mcpreach3** writes the collection (item 2, a set added by number); ownswap only reads it.

setcheck and swoosh read the model and write nothing, and each proves it
with `keep_text` and `store`. design25 and design26 change what a session
builds, not how a file is written.

**The files the running units own,** read from their briefs today. Nothing
in wave 1 touches them before that unit merges, beyond the registries:
- keepbytes: `src/parts/model_store.gd`, `source_file.gd` and their
  probes (the save and undo paths);
- smalls7: Motions' panel (`src/ui/pose_panel.gd`), the phone's layout
  (`src/ui/phone_shell.gd`), and pointat's and app_host's checks;
- weighpace (the lead's task 128, next): the weigh's pool tasks
  (`src/assembly/stability.gd`, `tested.gd`) and Together without threads.

| # | unit | rank | size | risk | wave, and what it waits on | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|---|
| 1 | **design25** | first measure | L | high | 1, at once | `src/ai/feature_pass.gd`, `surface_pass.gd` (its step check), `assistant.gd`, `connector_guide.gd`; new `src/ai/form_parts.gd`, `tools/form_parts.py`, `assets/knowledge/form_parts.json.gz`, `src/dev/form_parts_probe.gd`; `docs-site/` design pages | above: the screen (head to head both orders, surface preferred, reach 8 of 16, SNOT 10%, steps in a third of surface losses), then the paired 44 against a same-night base (overall's lower edge above 0, surface no worse, build check no worse, leak audit clean) |
| 2 | **webstart12** | 1 | M to L | high | 1 | the first screen's script closure: `src/main.gd`'s and `src/ui/shell.gd`'s loads of the assistant, Together, the booklet and the forge, made on first use as the Later scripts are; the export's Later list (`tools/export.sh`, `src/boot/`); `tools/web/start_phases.mjs` read and extended; `assistant.gd` read only | see below |
| 3 | **mcpreach3** | 2 | S to M | low | 1 (any `assistant.gd` line after design25) | the answers of `save_model`, `edit_collection`, `pose_model`, `attachment_points`, `check_design` and `edit_steps` in `app_tools.gd` (their own functions); `api/mcp.js`'s line on other chats; the window's own set add called, `collection_store.gd` read only; new `src/dev/mcpreach3_probe.gd` | see below; a review before merge (it writes the collection) |
| 4 | **setcheck** | 3 | M | medium | 1 | new `src/parts/set_check.gd`; Compare's "with the set" mode in `src/ui/compare_view.gd`; `compare_with_set` in `app_tools.gd`; `parts_compare.gd` and the library's OMR files read only; new `src/dev/setcheck_probe.gd` | 10 library sets, each opened and changed by a script (3 parts taken away, 2 recoloured, 2 swapped for a near mould, 1 moved a stud, 1 put in another sub-model): every change found, each named with the set's own step and the model's sub-model and line, 0 named that were not changed; each unchanged set says it matches; a click on a row selects the part; the MCP walk's g1 in 3 calls or fewer; nothing written; `compare`, `library`, `keep_text` pass |
| 5 | **ownswap** | 4 | M | medium | 1 | new `src/collection/own_swap.gd`; the parts list's row in `src/ui/inventory_panel.gd`; `replace_parts`' `mine` in `app_tools.gd`; `rare_swap.gd`'s matcher, `own_counts.gd` and `collection_store.gd` read only; new `src/dev/ownswap_probe.gd` | 10 gallery models against a collection of 3 sets and 40 loose lots: every lot not owned listed, each with an owned swap (the same mould in the nearest owned colour by ΔE 2000 under 10 and never across a finish, or an equal part in the same colour) or "none you own"; applied in one undo, byte for byte back; the owned share before and after, as `mine=true` counts it; a held part kept; 1 call over MCP; `rareswap`, `ownlimit`, `store`, `keep_text` pass; a review before merge |
| 6 | **jointlock** | 5 | M | medium | 2 (after smalls7: `pose_panel.gd`) | a lock per joint in `src/assembly/pose.gd` and `joints.gd`; Pose's lock column in `pose_panel.gd`; the drag's refusal in `builder.gd`; a `0 !BRICKWORKS LOCK` line; `pose_model`'s `lock`; new `src/dev/jointlock_probe.gd` | a joint locked in Pose holds through a drag of either part, R, a handle, Simulate's driver, `move_part` and `pose_model`, each refused with the joint's name and how to unlock it; unlocked, each moves again; the lock saved, reopened and kept by `keep_text` byte for byte, and named, not dropped, by older builds; the MCP walk's g2 in 3 calls or fewer; and, as `pose_panel.gd`'s owner in wave 2, **Motions by finger**: Keep on the suggested motion in 1 tap and a joint's slider moved by a drag, on Chromium and WebKit (phonewalk's two not done today), unless smalls7 has fixed them; `pose`, `motion`, `simulate`, `keep_text` pass; a review before merge |
| 7 | **swoosh** | 6 | M | medium | 2 (after weighpace: `stability.gd`) | new `src/assembly/swing_test.gd` (Lift's sum with speed and a turn); Stress's Swing row in `src/ui/stress_panel.gd`; `weakest_joints`' `swing`; `lift_test.gd` and `pose_hold.gd` read only; new probe | the car held by its roof and the walk's tower by its top brick, swung through a child's arc (1 m in 0.5 s, a quarter turn): each joint's load at the arc's worst within 1% of a hand's sum on 3 cases, and the first to let go named with its parts and weight; on 10 gallery models the first part to come away named, and after Strengthen it comes away later or not at all; the MCP walk's g4 in 2 calls or fewer; `loadtest`, `strengthen`, `stabletruth` pass |
| 8 | **phonefingers** | 7 | S to M | low | 2 (after smalls7: `phone_shell.gd`) | the gestures in `src/camera/cad_camera.gd` and `src/ui/phone_shell.gd` (no panel's own file); new `src/dev/phonefingers_probe.gd` | see below |
| 9 | **finishpass** | 8 | M | medium | 3 (after design25: `surface_pass.gd`) | Edit › Finish the surfaces… in the registry; a new `src/ui/finish_bar.gd` (what the pass will lay, shown first, each kind left out by a tick); `surface_pass.gd` called from the window, not changed | on 10 hand-built models (the walk's wall, a stepped roof, a car's bonnet, the MCP walk's g3 house among them) the pass's tiles, slopes and rounds shown first and laid in one undo, byte for byte back; each kind can be left out; nothing floats or overlaps after (`check_design`); a part that holds a stud others sit on is never tiled; `surface`, `keep_text`, `store` pass; a review before merge |
| 10 | **blockauthor** | 9 | M | medium | 2 | a block in `api/people.js`, `_follows.js` and `_comments.js`; new `supabase/block.sql` (additive, RLS on); Block in the profile's and a comment's menu and its list in Settings (`web/`); `/admin`'s people read only | a person blocked from their profile or a comment: their models leave your gallery, feed and search; their comments on yours are hidden; they can no longer follow you or comment on yours; neither is told; unblocked from Settings, all of it back; a second account cannot read another's blocks (RLS); `gallery`, `feed`, `comments`, `follows`, `profile`, `account_page` pass |
| 11 | **idleframes** | 10 | M | medium | 2 (after webstart12: `main.gd`) | the frame's work when nothing moves and while turning: `main.gd`'s `_process`, the view's redraw, the bin's and the status bar's per-frame reads | at a quarter speed in a phone's window, the app's own work with nothing moving 2 ms or less a frame at p95, and turning the car 20 ms or less (39.1 today) and Orthanc 30 ms or less (57.9), in 3 same-moment pairs; the desktop's frames no worse; `frames`, `phone`, `placing`, `jointmarks` pass |
| 12 | **smalls8** | 11 | S | low | 3; item 1 at once if Lift fails by hand (no wave-1 unit owns `stress_panel.gd`), before swoosh starts | per item, below: `stress_panel.gd`, `lift_test.gd` (item 1), the pick's path (item 2), `booklet.gd` and `page_setup_dialog.gd` (item 4) | below; a review for item 4 |
| 13 | **camerakeys** | 12 | M | medium | 3 (after jointlock: `pose_panel.gd`) | a camera track in Motions (`pose_panel.gd`, `src/assembly/motions.gd`); `render_motion`'s camera; keys picked by Ctrl+click and deleted together | the camera keyed at 3 times in Motions plays and renders through them, the model still; a turntable is two keys; saved, reopened and kept by `keep_text` byte for byte; three keys picked by Ctrl+click and deleted in one undo (StudWorx 11-18); 1 call over MCP; `motion`, `render`, `keep_text` pass; a review before merge |
| 14 | **design26** | design track | L | high | 3 (after design25 ends, GO or NO-GO) | the Technic brief's path in `assistant.gd` and `feature_pass.gd` (after design25 frees them) | on the 9 Technic subjects of the 44, where both of design24's arms lost all 18 verdicts: the set's Technic parts (panels, beams as the seen frame) laid onto the System body, never a studless body in its place; a verdict against the set won on 2 or more of the 9, likeness no worse than the base; then the paired 44 as design25's bar |

**Which can run at once.** At most five units run at a time. keepbytes
and smalls7 are running, and weighpace is the lead's next. Wave 1 is
five: **design25** first, then **webstart12**, **mcpreach3**, **setcheck**
and **ownswap**, each as a slot frees. No two share a file beyond the
registries: design25 owns `assistant.gd`, which webstart12 and mcpreach3
only read; setcheck and ownswap own new files.
- **Wave 2:** jointlock and phonefingers once smalls7 merges; swoosh once
  weighpace merges; blockauthor at any free slot; idleframes once
  webstart12 merges.
- **Wave 3:** finishpass and design26 once design25 ends; camerakeys once
  jointlock merges; smalls8, its item 1 first if a person's Lift fails
  too (open question 1).
- kinefuncs2 and buildorder2 run when the owner says, each alone on its
  files.

None of these needs the owner to start, beyond those two.

**webstart12, in full.** webstart11 timed the start phase by phase and
found the scripts' compile the largest on every engine: 24.5 s of a 72 s
first visit at a quarter speed on Fast 4G, 9.4 s of WebKit's 25 s, and the
whole of the Wasm memory's 432 MB. Its own Next was the first screen's
script closure. The bar:
- **Measure first,** as same-moment pairs (`start_phases.mjs`, live's
  build against the change, in browsers of their own), on Chromium at a
  quarter speed with Fast 4G and on WebKit as an iPhone 13: which classes
  the first window compiles and does not use before a press, and what
  each costs in seconds and MB. A first commit that measures only is a
  valid stop.
- **The lever:** those classes (the assistant, Together, the booklet, the
  forge and what only they name) loaded on first use, as the Later scripts
  are, with no feature slower to open than 1 s after its first press.
- **The target:** at a quarter speed, the scripts' phase 12 s or less
  (24.5) and the first visit 55 s or less (72.4); on WebKit as an iPhone,
  working 15 s or less (18.4 to 25); **the Wasm memory at its height
  300 MB or less** (432), the ceiling an iPhone reliably gives; desktop
  cold to working no slower. In 3 pairs of 3.
- **Checks:** `load_check`, `phone`, `phonewarn`, `first_steps`,
  `placing`, `dialogs`, `together` and the assistant's first open on the
  preview.

**mcpreach3, in full.** Where the person's Claude stalled or guessed in
this round's MCP walk, each in the answer that would have spared it:
1. **A save is never refused** (`save_model`, g1): unsettled features are
   named in the answer, and the file is written. g1 opens the set in 2
   calls or fewer with the car kept.
2. **`edit_collection` adds a set by number,** and marks it Built, in one
   call (r5: 1 call, "0 loose parts" said). It writes the collection, so
   one review.
3. **A click hinge is a joint without an assembly** (`pose_model`, r2):
   the hinge's moving half found as a drag finds it; r2 in 6 calls or
   fewer.
4. **A motor's mount said before Simulate** (`attachment_points` and
   `check_design` on a SPIKE or Powered Up motor): the faces real sets
   mount it by, and a motor on single studs named as free to swivel at
   the check, not after a run. y6 and r1 in 15 calls or fewer each.
5. **`edit_steps` says why nothing changed,** and `next` from the last
   step makes a step after it (t9: 3 calls, the whole row three steps
   later).
6. **The tab's line on other chats once a chat,** and again only when
   another chat calls (`api/mcp.js`): t9's later answers without it.

Bar: a probe drives each over the app's port (`mcpreach3`), and the MCP
walk's g1, r2, r5, t9, y6 and r1 rerun through the connector meet the counts above.
`mcpreach`, `mcpreach2`, `mcp_sync` and `tabpair` pass.

**phonefingers, in full.** The bar:
- **The two gestures every iPhone app has:** a two-finger tap undoes and a
  three-finger tap redoes, as iOS's own apps and Procreate do, and as
  Brick Creator 3D does since 19 November; each says what it took back.
- **No false fires:** over phonewalk's own 100 two-finger turns and pinches
  on the car, 0 undos.
- **A double tap on a part turns it 90°**, as R does.
- **Checks:** phonewalk at 390 x 844, 1024 x 768 and on WebKit as an
  iPhone 13, every act its gestures touch done; `phonepanels`, `fingertools`, `phone`,
  `tablet` pass.

**smalls8, in full.** Faults this round's runs found, each with its file,
item 1 first on its own commit so it can ride the next release:
1. **Lift no longer lifts in the walk** (`round8`, both sizes): 27 to 36 s
   and "Click the part to lift the model by." against 191 to 295 ms in
   round nine. Reproduce first, by hand and with `loadtest`, with and
   without Strengthen pressed before it (`src/ui/stress_panel.gd`,
   `src/assembly/lift_test.gd`). Bar: the walk's Lift within 300 ms,
   "everything comes with it, 22 g".
2. **The first pick after a cold start at load, 2.2 to 5.3 s,** with no
   part file fetched for it (`load_check --pick`). Measure first: what the
   first pick waits on, phase by phase. Bar: 600 ms or less, cold, in 3
   runs at load.
3. **At 1280 x 720 the bin gives way with Stress open**, by hand first;
   if a person meets it, the bin stays beside Stress at every size, as at
   1400 x 900.
4. **StudWorx's smaller polish:** the booklet's highlight width (1 to 8
   px, `booklet.gd`), and **a page locked against all-page changes**
   (`page_setup_dialog.gd`), which writes a line in the model file, so it
   gets the review. Keys deleted together are camerakeys'; Motions by
   finger is jointlock's (both own `pose_panel.gd` in their waves).

Bar: each item's line read as above at the sizes named, and the checks
each names pass.

## The top ten

1. **design25:** the form built with the parts real sets build it with.
   Measured: the screen on the 16 tune subjects, then the paired 44 against
   a same-night base, overall against the set above the base by its 95%
   lower edge, surface no worse, the build check no worse, the leak audit
   clean.
2. **webstart12:** a phone's start. Measured first, as same-moment pairs;
   then the scripts' compile at a quarter speed 12 s or less (24.5), WebKit
   as an iPhone working in 15 s or less, and the Wasm memory at its height
   300 MB or less (432).
3. **mcpreach3:** where the person's Claude stalled or guessed this round.
   Measured: g1, r2, r5, t9, y6 and r1 through the connector, each in the calls its bar
   names.
4. **setcheck:** a build checked against its set's own steps. Measured: 10
   library sets changed 9 ways each, every change named with its step and
   line, 0 named that were not; g1 in 3 calls.
5. **ownswap:** a model rebuilt from what I own. Measured: 10 gallery models
   against a collection, every lot not owned given an owned swap or "none
   you own", one undo, byte for byte back.
6. **jointlock:** a joint locked. Measured: a locked joint holds through 6
   ways of moving it, each refused by name; the lock kept byte for byte.
7. **swoosh:** what comes away when a model is swung. Measured: each joint's
   load at the arc's worst within 1% of a hand's sum, the first to let go
   named on 10 gallery models.
8. **phonefingers:** a two-finger tap undoes. Measured: undo and redo by
   tap, 0 false fires in 100 turns and pinches, and a double tap turns a
   part 90°.
9. **finishpass:** the surface pass for a person. Measured: 10 hand-built
   models finished in one undo, each kind left out on a tick, nothing
   floating after.
10. **blockauthor:** a person blocked. Measured: their models, comments and
    follows gone from yours, back on unblocking, and no account reading
    another's blocks.

Wave 1 starts with five of these: design25, webstart12, mcpreach3,
setcheck and ownswap. keepbytes and smalls7 are running beside them.

**Next, once those land:**
- idleframes, smalls8 and camerakeys: ranked 10 to 12 above, in waves 2
  and 3;
- **design26,** the set's Technic parts on a System body, once design25
  ends;
- **the photo step check** (past parity, 3): a photo of a build held
  against its booklet's step, measured first as a task of the next MCP
  walk;
- from round seven and earlier, still not built: filmsound, realjoints5,
  modsteps and panelside;
- not ranked:
  - **agesteps:** a booklet for an age, after buildorder2;
  - **pilecount:** a pile counted from one photo in the window;
  - LeoCAD's turn to seat more studs, which overrides the person's own turn;
  - BrickFlow's photo to model, a research model today;
  - SOCIAL rows 7 to 9, once the beta's first weeks show who comes;
  - BrickBench's validity measured locally again, with nothing submitted.
- **Parked, the owner's:**
  - payments and live prices;
  - desktop downloads ("Coming soon" until the owner says);
  - BrickBench submissions, and any MCP registry listing;
  - new languages;
  - provider API keys: all AI is the person's own;
  - kinefuncs2 and buildorder2, until the owner chooses;
  - BrickLink's keys and terms, and store prices; Studio's install; a real
    SPIKE hub; 3Dconnexion; the Mac's thumbnails; tests on other AIs.

  None is ranked above, and nothing above waits on any of them.
- **Out on purpose:**
  - a weather lab, a falling-bricks physics simulation and a collision
    switch, for the reasons APP_UX8 gave;
  - Studio's POV-Ray region render and LGEO library: Best is path traced in
    the app;
  - a second look for the app, until the owner asks;
  - the LEGO® logo on studs ([TRADEMARKS.md](TRADEMARKS.md), 3);
  - anything for a person who is not signed in.

## Open questions, named

Measured only in part by the bound (3 hours, 19 November 03:46 to 06:46Z).
Each is a first step of the unit named, not a reason to wait:
1. **Is Lift broken, or is the walk's click wrong?** (smalls8, item 1.)
   The walk's Lift waited 27 to 36 s and lifted nothing at both sizes;
   `loadtest`'s probe was not run today. If a person's click fails too,
   it is a regression on `pre261` and goes first, on its own commit,
   before swoosh starts on `stress_panel.gd`.
2. **What does a click hinge hold?** posehold says "no one has published
   what one holds", so r2's answer was the session's guess. No unit can
   measure it here without the real part; it stays named in the answer,
   as today.
3. **What does the first pick wait on at load?** (smalls8, item 2.) 5.3 s
   once and 2.2 s once, with no file fetched.
4. **Not run on live today:** render, Build together, pointat and
   first_steps (the batch's bound and the live database's lock). The next
   release's train runs them.
5. **Not run on the snapshot today:** hubprogram's, mcpreach2's and
   keys3's probes, queued behind a release's solo timing check at the
   bound. Their units' own runs met them, and r1's program and f4 and f5
   met them through the connector.
6. **Do the snippets cover the 16 tune subjects' forms?** design25's
   first commit measures form reach before any screen: 8 of 16 or more,
   or design25 stops there with that number.
7. **Can a photo of a build be read to a stud?** (past parity, 3.) A task
   of the next MCP walk, before any unit.

## Sources

Every page below was read on 18 or 19 November 2026, and a copy of each is
in `bench/results/uxplan10-2026-11-19/sources/`, by tool.
- **BrickLink Studio:** the download page's release data
  (https://www.bricklink.com/v3/studio/download.page), the Early Access
  notes, and the help centre's article list
  (https://studiohelp.bricklink.com/hc/en-us); BrickLink's outage,
  https://www.brickfanatics.com/lego-bricklink-outage-summarised-what-happens-next
  and its Wayback copy of 15 November.
- **Mecabricks:** https://www.mecabricks.com/ (the workshop, its
  `workshop.js` headers and the forum's categories).
- **LeoCAD:** https://github.com/leozide/leocad/releases (26.09 and the
  continuous build of 19 November) and its commits since 15 November.
- **LDCad:** http://www.melkert.net/LDCad (home, download, features and
  next version).
- **StudWorx:** https://github.com/nathaneltitane/studworx/releases/tag/2026-11-18,
  its `FEATURES.md`, `NOTICE.md` and `RELEASES.md`.
- **BrickAgent, BrickNet and BrickBench:** https://brickben.ch/leaderboard,
  https://gallery.brickben.ch/, PyPI's `brickagent` and `bricknet`, and the
  repositories' commits (https://github.com/kulits/BrickAgent,
  https://github.com/kulits/BrickNet, https://github.com/AvaLovelace1/brickwright).
- **Kinebrick:** https://github.com/erik-larsen/kinebrick (its README's
  table, 701 of 1,226) and Kinebrick Studio,
  https://github.com/fhareide/kinebrick-studio-releases.
- **bicheck:** https://github.com/fhareide/bicheck (README and commits).
- **Brick Workshop's Brick Studio:** https://brick-studio.larsvanbraam.nl/
  and https://github.com/larsvanbraam/brick-workshop
  (`apps/brick-studio/README.md`).
- **Brick Creator 3D 1.1.1:** https://apps.apple.com/us/app/brick-creator-3d/id6818529262
  (and the App Store searches saved under `apps/`).
- **LEGOGOD:** https://github.com/jensen666/legogod.
- **BrickFlow:** https://kulits.github.io/BrickFlow/,
  https://github.com/kulits/BrickFlow and https://huggingface.co/kulits/BrickFlow.
- **DailyBrick:** https://arxiv.org/abs/2611.22132 and
  https://github.com/Agent-and-Embodied-Lab/DailyBrick.
- **mesh2brick:** https://github.com/leckermatz79/mesh2brick (commits).
- **Mister Blocks:** https://misterblocks.com/.
- **arXiv's searches** for "lego", "ldraw" and brick assembly, newest
  first (`sources/arxiv/`).
- **LDraw's forum** (https://forums.ldraw.org/syndication.php), Hacker
  News (by Algolia's search), Eurobricks and Reddit (the last two could not
  be read).
- **An iPhone's memory:** WebKit bug 269937, as cited in
  [PHONE.md](PHONE.md).

The app's own figures are in `bench/results/uxplan10-2026-11-19/`:
`mcp/run/` (each task's stream, `calls.txt`, `search.txt`), `walk/`,
`probes/`, and `web/` (`load_check`, `phonetruth`, `phonewalk`,
`phonewalk_iphone13` and `checks/`). Round nine's units' records are in
`queue.md`, [DESIGN_SCORES.md](DESIGN_SCORES.md), [PHONE.md](PHONE.md),
[CAPACITY.md](CAPACITY.md) and [KINEFUNCS.md](KINEFUNCS.md).
