# The app against the best tools, round nine

Written 2026-11-15 and 16 by uxplan9 against `pre261` at `dfce10857`. The web was
measured on rel-m303 (`d3ca8ab57`), live then. [APP_UX.md](APP_UX.md) to
[APP_UX8.md](APP_UX8.md) planned rounds one to eight.

## Where round eight's units stand

All eighteen of APP_UX8's units are built but one. Fourteen are live, three
are in `pre261` for rel-m304 (stopped at 23:53Z, reshipping since 01:34Z with bofix), and
stepops is in its last unit.
Read from `queue.md`, `git log pre261` and each unit's own record:

| # | unit | where | its bar, as it ended |
|---|---|---|---|
| 1 | webstart9 | live, rel-m296 (13 Nov) | usable cold and warm within 10% of m276 in both ABBA runs; the first screen's source 6.49 to 6.18 MB, four rarer features behind Later. **NO-GO line:** the compile, x1.25 cold and x1.12 warm at load 48 to 66, where one block swung 0.97 to 1.28. The 5.93 MB data pack went to webfaults (live, rel-m300) |
| 2 | design20 | NO-GO, recorded (docs only, rel-m296) | the silhouette probe met (five sets 0 at every tenth); the smoke did not: likeness 1 of 10 both ways, overall 0 to 1, a defining feature named wrong in 9 of 10 verdicts both ways. Its Next, the outline asked for before the first build, was design21: **NO-GO** (16 Nov 01:11Z, record `4ba7d52a1`). Built to as a solid, the outline lost its screen, preferred 44% head to head on the 8 subjects reached; the 4 sessions that read it as sizes to build to won 7 of 8. That is **design22, running** |
| 3 | buildorder | `pre261` 966f697bf; rel-m304 stopped 23:53Z on its mend flattening a sub-model's copy on save; **bofix** `75e1c8ccc` fixed it at the root (the four failing probes 0), and rel-m304 is reshipping | floating 1.1% (bar 2%), in under one already there 1.49% (bar 1.5%), tau 0.34, planning 1.20 times. **NO-GO lines:** hidden steps 10.4% (bar 8%; two sets hold 172 of the 404 over the authors'), the build check 5.2% (bar 4%; four sets hold 81 of 91 parts). 8169-1 went 121 to 213 under, untraced. A second unit is the owner's choice (lead, 15 Nov) |
| 4 | stabletruth | live, rel-m296 | met: 8 of 8 structures, 39 of 39 stairs, the let-go 1.92 N; 16,622 bricks of StableText2Brick 100% agreeing |
| 5 | ownlimit | live, rel-m301 (15 Nov) | met: the counts left exact at 12 steps of the wall with 7140 and 12 lots; the 13th "1 over" on its tile; n5 over MCP in 3 calls, 0 parts not owned. **Left:** there is no "built" mark, so every owned set counts as loose parts (round seven's keptbuilt, never built) |
| 6 | phonewalk | live, rel-m297 (14 Nov) | met: 46 acts at both sizes, all by finger; 21 took over twice the desktop's presses and 8 touched a control under 44 points. Its table became phonepanels' and fingertools' briefs ([phonewalk.md](app_ux8/phonewalk.md)) |
| 7 | kinefuncs | live, rel-m299 (15 Nov), after a revert and kinefast's re-land | n4's gear train turned (3 turns to 1). **Not met:** 391 of 1,224 functions work (from 361), against Kinebrick's 517 then and 673 now. The gap is in the joint reading: ball and link loops past racks, differentials, pistons. kinefuncs2 is the owner's choice (lead, 14 Nov) |
| 8 | strengthen | live, rel-m297 | met; today's probe below |
| 9 | swapfind | `pre261` 34239e150 (after swreview and swfix), staged in rel-m304 | met: the car's four Black 3023s Dark Bluish Grey in one action, undo and redo to the byte, a part in two colours flagged, `replace_parts` in 1 call. swreview's live faults (a copy following an edit through a locked twin or one with no room) are **followfix, running** |
| 10 | fingertools | live, rel-m298 (14 Nov) | met: Measure 0 LDU off the mouse (from 156.7), a handle dragged 60 LDU by a finger (from 0), handles 45 to 86 points (from 1 to 29), 0 errors from `touch_sizing` (from 13) |
| 11 | mcpreach | live, rel-m300 (15 Nov) | met: x2's PDF in 3 calls, its text exact; x4 and x5 keep the earlier files and take a free name; x5 says closed in 1 call; n7 names Build together in 0 calls |
| 12 | setsbuild | live, rel-m302 (15 Nov) | met: 20,183 sets ranked, `all_sets.bin` 1.93 MB fetched only by What can I build?, its first page 531 ms on the web; 10 sets checked by hand |
| 13 | loadtest | live, rel-m300 | met: a 16-brick wall lifted, the joint at 2.018 lets go and 14 parts are named and tinted; the car by its roof holds its 52 g; `lift_by` in 1 call |
| 14 | phonepanels | live, rel-m300 | met: 0 of 54 targets under 44 points (from 24); a motion recorded in 5 taps (from 13) |
| 15 | movedparts | `pre261` 3b5fb89f5 (after mvreview and mvfix), staged in rel-m304 with its catalogue patch | met: 13 OMR files, 44 numbers, 138 lines replaced in one undo, byte for byte back. The lead's call: renumbered parts get a strip over the model (Update all, Review…, Keep as is), the list only for parts with no file |
| 16 | spikemotors | live, rel-m303 (15 Nov) | met: SPIKE Prime large 25 N·cm at 175 rpm, medium 18 at 185 (7.2 V); the Powered Up L, XL and others from Hurbain's figures; an arm stalls at 26.300° where virtual work says 26.300° |
| 17 | pointat | live, rel-m299 | met in its own runs: outline and name on both tabs, gone after 5.1 s, Esc 59 ms, Claude in 1 call. **But its timing check fails on live too:** the second tab's p95 was 1,770 ms on live and 2,633 on rel-m303's preview at load 32 to 33, against 500. rel-m303 shipped past it, since it was not new |
| 18 | stepops | **READY** `781c12dc7`, in review (streview, 16 Nov) | its own report: 147 of 147 step edits patched in place (live writes 117 whole), 296 lines changed where 680 moved, undo and redo to the byte |

Also landed in the round, beyond APP_UX8's list: askfirst, intomodel3,
carryrest, copyfaults3, stepnames2, inlines, kinefix, framefetch,
webfaults, smalls1 and smalls2, lists1, challengepage, bugbar, panelfold,
trainflake2, checkfix, console1 and console2 (live); copyorder, signinux
and console3 (`pre261`). followfix and stepops are READY and in review
(flreview, streview); design22 and pointfix are running.

Round seven's units that never started, and still are not built:
keptbuilt (a built set's parts not counted free), stepsearch (find a step
by what it places), partplaces (where each lot is kept), filmsound (a sound
under the build video) and realjoints5 (panes and bars the catalogue does
not join). takeback was done another way: `edit_collection`'s `remove=`
takes the session's own lots off, and the MCP walk's v10 (round five's tasks) tests it. Round
six's watchfile is built (`reload_offer.gd`); modsteps and panelside are
not.

This file measures the app a ninth time, by hand and through a person's own
Claude, this time through the connector as the owner's Claude reaches it. It
says where the field still does better, names the features no tool has that
a builder would value most, judges each, and ranks them with the gaps. Then
it plans round nine in waves the lead can start at once.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second. The desktop
download still says "Coming soon", so the browser is the way in.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix,
[ROADMAP.md](ROADMAP.md) the designer's quality and
[SOCIAL.md](SOCIAL.md) the site. None is repeated or edited here. Left out,
as the owner has parked them: payments, the desktop downloads, BrickBench
submissions, new languages and provider API keys.

## How it was made

- **The walk, a ninth time.** [appux8's script](app_ux8/appux_walk.gd)
  and tasks, run on the GPU at 1280 x 720 and 1400 x 900 from a locked
  snapshot of `pre261` at `dfce10857`, imported first. One section was
  added after the old ones, so their numbers still compare: `round8`,
  which covers:
  - a model with renumbered parts opened, and the strip it shows;
  - Edit › Find and replace by Ctrl+Shift+H on the car, its Black 3023bs
    made Dark Bluish Grey everywhere, timed, and one undo;
  - a tower of 2 x 4s on one corner stud with Stress open: its rows,
    Strengthen on the worst, and Lift by a brick;
  - View › Reset panel layout, and the keys round eight's commands have.

  The first run of `round8` opened the car for the renumbered parts, but
  the car already has 3023b, and Ctrl+Shift+H opened nothing at either
  size. The section was changed to open a model with old numbers first and
  to say what had focus when the key was pressed, and was run again alone
  at both sizes (`only=round8`). Every picture both runs took was looked at.
- **The tasks over MCP, through the connector.** Round eight drove the
  app's own MCP port. This round goes the way the owner's Claude goes:
  - the app runs as a signed-in tab of a throwaway account on the live
    site, opened through the relay (`relay_account.mjs`) and closed at the
    end;
  - Claude Code reaches it as an http MCP server at the relay's `/api/mcp`
    with the account's token, as `realset.py --via relay` does;
  - `claude -p` on the subscription, the Brickworks server alone,
    `--tools ""`, `--restricted`, and no API key. The run held a slot of
    the live database (`live_db.sh`).

  One turn per task, in four sessions:
  - the walk's ten (t1 to t10: a wall, a turn, paint, sub-models, steps,
    a render);
  - the pod's three, then eight for what round eight added (y1 to y8,
    their words in the Over MCP section);
  - APP_UX8's frontier seven (n1 to n7);
  - six that ask for what the field added this week, or for what no tool
    has, from a cleared model (f1 to f6, their words below).

  Rounds three to seven's 37 tasks were measured by APP_UX8 and were not
  run again: each task bills the subscription the team's own sessions
  run on. The first two tries reached no tab, through two faults in this
  round's runner, not the app's: it started the app without
  `--assistant=on`, and its wait read the relay's "No Brickworks tab is
  open" as open. Both were fixed and the walk ran a third time, after the
  probes. Calls are counted from the sessions' own streams.
- **Round eight's bars** were read off each merged unit's probe, run today
  from the same snapshot at the sizes their headers give, one at a time:
  `strengthen`, `loadtest`, `ownlimit`, `mcpreach`, `panelfold`,
  `fingertools`, `phonepanels`, `motion` (spikemotors), `swapfind`,
  `movedparts`, `setsbuild`, `stabletruth` and `kinefuncs`, and then
  `seatfix` and `keys3`, which the walk named.
- **The web, on live brickworks.diy** (rel-m303, `d3ca8ab57`), from a
  worktree at live's own commit, so its flows match live's sign-in:
  - `load_check`, two cold and two warm loads and a part picked from the
    bin, on broadband, and again at a phone's 390 x 844 (3x, touch);
  - `phonewalk_flow`, phonewalk's 46 acts by finger at a phone's and a
    tablet's size, on a throwaway account of its own;
  - 22 of the release's browser checks against live, for the flows a
    builder meets: placing, the bin, sets, sub-models, steps, the booklet
    and its editor, render, share, Build together, pointing, the
    collection, lists, the gallery, a model's page, the first steps,
    phone, tablet, the library, Technic and Brickify. They ran as
    `preview_checks.sh` runs them (throwaway accounts, the live database's
    lock). 21 ran; pointat's gave way to pointfix, below.
- **The field,** from each tool's own pages, release notes, changelogs,
  commits and papers as of 15 November 2026. APP_UX2 to APP_UX8 and
  COMPETITIVE were read again, and only what they did not cover is new
  here.
- **Not run:**
  - Studio itself;
  - the in-app assistant on a key (it spends money);
  - claude.ai's own connector page (the relay is the same server, reached
    the same way).
- **The box was shared** with the rel-m304 train, design21's paired
  sessions, stepops' and followfix's probes and console3's checks. The
  load was 20 to 36 through the walk. Seconds are stretched by it; counts
  are not.

## What the walk measured, nine times

The first six rounds' figures are in APP_UX4 to APP_UX7.

| act | appux7 (1280 / 1400) | appux8 (1280 / 1400) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|---|
| desktop start, the first 120 frames | 8.2 / 8.3 s | 7.3 / 9.1 s | 7.7 s (load 28) | 6.9 s (load 36) | walk |
| bin tiles in sight on the first open | 24 / 42 | 24 / 42 | 24, every one named | 42, every one named | walk `counts` |
| keys sheet (F1), rows in sight | 32 / 46 of 157 | 32 / 46 of 158 | 32 of 161 | 46 of 161 | walk `counts` |
| commands with a key | 116 of 222 | 116 of 224 | 120 of 232 | the same | walk `counts` |
| the tallest menu, rows (height) | File 24 (482) | File 24 (482); Edit 24 (464) | **Edit 25 (486)**; File 23 (460) | the same | walk `menus` |
| the part menu | 26 | 26 | 26 | 26 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20, 3.4 / 4.7 s | 20, 3.7 / 3.9 s | 20 events, 3.3 s (3.8 s the second time) | 20, 3.9 s (3.7 s) | walk `wall`, `round6` |
| the ghost following the pointer, 3 frames a move | 47.8, worst 65.9 / 62.1, worst 82.8 | 55.0, worst 80.5 / 54.8, worst 78.7 | 44.8 ms, worst 67.2 (46.6, 69.0) | 55.7, worst 84.9 (52.8, 84.1) | walk `wall`, `round6` |
| R on a brick in a wall, 15° step | down after 2 events, 15.0° | the same | the same | the same | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | 45° | walk `dialogs` |
| panels and dialogs | 22 of 24, 0.9 to 2.5 s | 22 of 24, 0.9 to 2.3 s | 22 of 24, 0.75 to 1.54 s; Compare and Pattern greyed, as before | 22 of 24, 0.83 to 1.57 s | walk `dialogs` |
| search, 30 words | 27 | 27 | 27: the same three not first | the same | walk `search` |
| the car's instructions, 240 frames | | 7.8 / 5.4 s | **3.3 s** | **2.7 s** | walk `round3` |
| three selected parts painted Red; a plate split and merged | 1 key each | the same | the same | the same | walk `round2` |
| a part to the last step | 4 presses | 4 | 4 | 4 | walk `round3` |
| Like this on a 2 x 4 brick, Stress open | seventh | Plate 2 x 4 seventh | the same | the same | walk `round3`, `round7` |
| the status bar, the car open | the same | "61 bricks · stands up · 52 g", "4.5 × 10.8 studs, 15 plates high · 3.60 × 8.64 × 4.96 cm" | the same | the same | walk `round6` |
| Cut away by a box | 1.1 s | 1.3 / 1.6 s | 0.9 s, Alt+X, Alt+Z, Alt+Y | 0.8 s | walk `round4` |
| Cut away's strip, with Stress open | 5 of 5 | 5 of 5 | 5 of 5 | 5 of 5 | walk `round5` |
| everything open with the timeline | 0 past; room 639 / 769 | the same | 0 past the edge; room 639 | 0; room 769 | walk `round6` |
| a view saved, turned away 35°, brought back | back 0.000° | the same | the same | the same | walk `round5` |
| File, Import, Into this model… | not offered | not offered (intomodel3 waited) | **offered, not greyed** (intomodel3) | the same | walk `round4` |
| the bin's "plate 1 x 1" and "1x1 plate"; 87087's tooltip | 3024 first at 1400 | 3024 first; "1 x 1, a stud on one side, 1 brick" | the bin had given way to Properties (the walk's own, as before) | 3024 first, both; the same tooltip | walk `round6` |
| the keys sheet's "cut away" | 11 rows | 11 rows | 11 rows | 11 rows | walk `round6` |
| **round seven's own** | | | | | |
| every bin shelf with Stress open | out of sight at 1280 | all eight in sight | all eight in sight, the bin 322 wide | the same | walk `round7` |
| **a 2 x 4 clicked with Stress open** | | the bin gives way (binstay, in Next) | **the bin gives way still**; back by its rail | the same | walk `round7` |
| the New shelf | none | 32 tiles, 282 parts | 32 tiles; 91 parts, the search still holding "2x4" (the walk's own) | 32 tiles, 282 parts | walk `round7` |
| F1, F9 and Ctrl+Shift+B with the bin's search focused | F1 did nothing | each in 1 press | each in 1 press | the same | walk `round7` |
| a 4740 dish on a 6141 round plate by hand | refused, 14 LDU off | seated: 0.00 LDU across, 8.00 above | 14.14 LDU across, 4.00 above: the click missed the plate (below; `seatfix` 33 of 33) | seated: 0.00 across, 8.00 above | walk `round7`, `seatfix` |
| View › Edges and studs | none | each off and on; no key | the same | the same | walk `round7` |
| Check stability on the car | | 21 / 31 ms; "a 34° tilt tips it" | 21 ms, the same words | 16 ms | walk `round7` |
| Make a part's "Far corner cut flat" | | offered, below the fold (makerfold, in Next) | offered; in sight by the walk's test, which asks only whether it is shown (as before) | the same | walk `round7` |
| My collection with the assistant hidden | | 0 words of Claude | 0 | 0 | walk `round7` |
| **round eight's own** | | | | | |
| Edit › Find and replace, Ctrl+Shift+H | | | **the key opens nothing**; the menu's row opens it, and two Black 3023bs went Dark Bluish Grey in 15 ms, one undo to the byte (below) | the same, 11 ms | walk `round8` |
| a tower of 2 x 4s on one corner stud, Stress open | | | "0 past working load · 0 near it", "the whole model tips over: its weight is 0.7 studs past the right edge"; the status bar "2 weak joints (tips)"; Strengthen not offered | the same | walk `round8` |
| Stress › Lift, a brick of the tower clicked | | | 295 ms: "Lifted by Brick 2 x 4: everything comes with it, 22 g" | 191 ms, the same | walk `round8` |
| View › Reset panel layout | | | the bin back, Properties closed; no key | the same | walk `round8` |

The search's three that are not first are the walk's own answers, as
before: "jumper" lists 3794b sixth, "macaroni" lists 25269 fourteenth, and
"bracket" has 99781 fourth. 112 of 232 commands have no key. Find and
replace is Ctrl+Shift+H, Point at Alt+W and Name the step Shift+F2.

**`round8` again, alone, at both sizes:**
- **Ctrl+Shift+H opens nothing,** with nothing focused, the command
  enabled, and again with the pointer over the model. Edit › Find and
  replace… from the menu opens the bar in sight, and the car's two
  top-level Black 3023bs went Dark Bluish Grey in 11 to 15 ms, one undo
  back to the byte ([picture](img/appux9/find_replace_1400x900.webp)). The cause is in the code: `main.gd` hands a key to
  the editing verbs before the shell's commands (line 11076), and
  `edit_verbs.gd`'s H (line 133) takes any Shift+H as Show only the
  selection, Ctrl or not. swapfind's own probe opens the bar from the
  menu, so it never pressed the key it names. swapfind is staged in
  rel-m304 (smalls4, item 1).
- **The renumbered-parts strip** did not show for a model of four 3023s
  and two 4073s opened as the walk opens it. That is the walk's own: the
  strip is offered after a person's own open (`ModelBar.offer_moved`),
  which the walk does not call. movedparts' probe opens as a person
  does and meets its bar (below).
- **The tower and Lift** read as in the first run: "0 past working
  load · 0 near it" in Stress beside "the whole model tips over" and
  the status bar's "2 weak joints (tips)". Lift took 185 to 201 ms.

**Found on the way:**
- **Ctrl+Shift+H** (above), in a feature that ships in rel-m304.
- **swapfind's probe fails 3 lines on `pre261`** and 4 in rel-m304's
  train: the car, opened and saved with no edit, is not its own file
  byte for byte. The lead bisected it to buildorder's mend, which
  flattens a sub-model's copy on save, and stopped rel-m304. bofix
  fixed it, and rel-m304 is reshipping (round eight, below).
- **With Stress open, a click on a part still puts the bin away,** at
  both sizes (binstay, from round eight's Next).
- **The Edit menu is 25 rows and 486 units tall,** and `keys3` fails it
  today: "Edit: 25 rows, 486 units tall in a window of 783 (at most 25
  and 470)". Find and replace's row is the new one. At 1280 x 720 the
  menu scrolls, and Mirror is the last row in sight
  ([picture](img/appux9/edit_menu_1280x720.webp)). Its Shift+H and
  Ctrl+Shift+H sit four rows apart.
- **A model that tips whole is "2 weak joints (tips)" in the status bar,
  and "0 past working load · 0 near it" in Stress,** over the same
  tower. Stress lists eight joints, the weakest at a margin of 3.5, and
  says plainly that the whole model tips 0.7 studs past its edge
  ([picture](img/appux9/tower_tips_1400x900.webp)). A person looks in
  Stress for two weak joints it does not list.
- **The walk's own:**
  - The 4740 dish at 1280 x 720 landed at (10, 12, -10), 14.14 LDU
    across from the plate's stud, where 1400 x 900 seated it at 0.00
    across and 8.00 above. `seatfix`'s own probe, run after, seats it
    by hand at every quarter turn (33 checks, every distance 0.00).
    (10, -10) is a baseplate stud's place beside the 1 x 1 plate, so the
    walk's click, at the last model's zoom, missed the plate.
  - At 1280 x 720 the bin gives way to Properties when a part is
    selected, so `round6`'s bin lines read the last search there, as
    in rounds seven and eight.
  - The New shelf's 91 at 1280 x 720 is the search still holding "2x4".
  - The walk opens models without the app's own open, so no strip, and
    the car keeps the last zoom.
  - Its "in sight" for Make a part's far corner asks only whether the box
    is shown, as round eight said; makerfold stays in smalls4.
  - Every Godot quit cleanly (exit 0).

## The web

`load_check` on live brickworks.diy (rel-m303), on broadband:

| | appux7 (live rel-m276, load 18 to 31) | appux8 (live rel-m281, load 26 to 38) | now: live rel-m303, load 27 to 33 | from |
|---|---|---|---|---|
| first visit, cold, to working | 10.2 s | 17.9 s | **16.3 s** (15.3 and 17.4) | `load_check` |
| warm | 6.0 s | 11.8 s | **9.3 s** (9.7 and 9.0) | `load_check` |
| the network, cold | | | 8.3 s (8.1 and 8.5) | `load_check` |
| main thread, cold | 5.7 s | 9.0 s | 8.8 s | `load_check` |
| the engine's banner, cold | 4.3 s | 5.3 s | 5.8 s | `load_check` |
| the scripts' compile, cold and warm | 2.2 s and 2.2 s | 4.1 s and 4.0 s | 4.1 s and 3.5 s | `load_check` |
| a part from the bin to its ghost, the longest | 214 cold, 1,426 warm | 461 cold, 311 warm | 566 and **2,183** cold, 275 and 331 warm; 0 part files fetched for it | `load_check --pick` |
| bytes before working | 16.71 MB | 16.84 MB | 16.84 MB | `load_check` |
| a phone, 390 x 844: first frame, cold and warm | 10.8 and 6.7 s | 16.6 and 12.6 s | **15.1 and 9.7 s** (14.1 and 16.0; 9.2 and 10.2); the compile 3.6 and 4.0 s | `load_check`, a phone's viewport |

**Better than round eight, still well behind round seven.** The warm
start is 2.5 s faster and the phone's 3 s faster (webstart9's 0.31 MB
behind Later, webfaults' data pack). The cold start is still 6 s
behind round seven's. Half of the cold load is the network: 8.3 s for
16.84 MB, with the data pack asked at 4.5 s and come at 9.6 s on the
phone. The compile is the other lever. One pick took 2.2 s on the
second cold run, at a load of 33, with no part file fetched for it;
the other three were 275 to 566 ms. On a phone, "working" never comes,
because a phone keeps the bin behind a button, so the first frame is
the measure, as before (webstart10).

**phonewalk on live,** 46 acts by finger at 390 x 844 and 1024 x 768, on
a throwaway account of its own: every act tried, 45 done. **One** took
more than twice the desktop's presses, against **21** when phonewalk
first ran: Simulate's driver changed by a tap, 3 taps against 1
(`simulate_panel.gd`). **No** control a finger took was under 44 points,
against **8**. The one not done is a 15° turn on a tablet: Properties'
Turn field read "" after 15 was typed, and the brick turned 0°. It ran
once, at a load of 35, and the phone's own run of the same act turned
15°. The table is in `web/phonewalk/phonewalk.md`.

**21 of the release's browser checks on live,** on throwaway accounts
under the live database's lock, at loads of 12 to 40:
- **20 passed with no line failed:** placing, the bin, a set's bin,
  sub-models, steps, the booklet and its editor, render, share, the
  collection, lists, the gallery, a model's page, the first steps, phone,
  tablet, the library, sets, Technic and Brickify. share took 17 minutes
  and the collection 14; the rest 1 to 9. The storage mirror served their
  part files; only the set's bin asked the bucket, 16 times (1.3 MB).
- **Build together:** every line of the two browsers passed (45). The
  link joins, both have the car byte for byte, 49 edits from both sides
  leave the two browsers byte-identical, a change reaches the other
  browser in 486 ms (p95 614), an under-13 is kept out of the chat,
  Follow, Comments, the owner's Claude's edit, a reload and an offline
  spell all hold. The desktop half did not join, and its 17 lines failed
  with it: the run's own fault, not live's, since the worktree it ran from
  had never been imported (no `.godot`), as a release worktree without
  `fresh_import.sh` fails the same way. The flow then reached its 45-minute limit at its last
  step. The slow lines are this box's frames, not the network: on the rich
  car the pointer took 2,990 ms (p95 8,742) with frames to 10,150 ms at a
  load of 40, while the trip itself was 327 ms (p95 423).
- **pointat on live** was not run here. It queued behind rel-m304's
  reship, and pointfix, started at 01:34Z, measures it on live itself.

## Over MCP: the tasks as the owner's Claude does them, through the connector

This is the first walk through the connector, as the owner's Claude goes:
the app was a signed-in tab of a throwaway account, and every call went
through the relay's `/api/mcp`. 34 tasks took **250 calls in 32.1
minutes** of the sessions' own time. No task failed or errored.

**The search** answers word for word as in APP_UX8's run, in 17 to 109 ms
a word. 19 of the 25 words with a part to find put it first. The six that
do not are the same six, for the same reasons: jumper sixth, macaroni
fourteenth, bracket fourth, and 3023b, 6141 and 3626c ahead of the number
asked.

**The walk's ten and the pod's three, again:** 37 calls in 4.5 minutes,
against 44 in 4.2 through the app's own port. The rows that moved:

| task | APP_UX8: calls, time | now | what the session did |
|---|---|---|---|
| t3: paint three bricks blue | 1, 6 s | 2, 9 s | a `look_at_model` first, because the relay said "two other chats are working in this tab" (below), and it told the person so |
| t7: a beam 7 standing, a pin in its second hole | 13, 86 s | 8, 72 s | a stand of a 2 x 3 plate and a 1 x 2 Technic brick, after three `check_design`s; its first `edit_model` sent the parts as a string |
| t9: move the top row three steps later | 6, 21 s | **3, 14 s** | `edit_steps to` in one call, where APP_UX8's session stepped `next` three times |
| s3: a 2 x 2 slope split into 1-wide slopes | 2, 7 s | 2, 20 s | the same calls; it named the slope's area as an assembly, unasked |

**Round eight's own** (in the second session, on the side pods):

| task | calls, time | what the session did |
|---|---|---|
| y1: the weakest joint, fixed with the fewest parts | 3, 20 s | "No joint in the model is under any real strain." It joined the two loose halves of the split slope with one 1 x 2 plate, and `weakest_joints` confirmed the plate held both (strengthen) |
| y2: lifted by the left pod's headlight brick, does anything come away? | **1, 9 s** | `weakest_joints lift_by`: the whole pod comes up, the headlight's one stud carrying 5.3 g, a tenth of its hold; the other 8 parts stay on the table, rightly (loadtest) |
| y3: every light grey wing plate dark bluish grey, every sub-model, in one go | **2, 11 s** | `replace_parts` with a preview, then one call: both wings, one undo (swapfind) |
| y4: which sets could I build from my collection? | 1, 7 s | the throwaway account's collection is empty, and it said how to fill it (setsbuild; a real collection is setsbuild's own probe, above) |
| y5: point the right-hand pod out to my friend | 1, 6 s | `point_at` the pod's five parts: "this tab isn't in a Build together session", and how to start one (pointat) |
| y6: a SPIKE Prime large motor lifting a beam 9 with a 2 x 2 brick; where does it stall? | **29, 178 s** | "The motor never stalls": 0.2 of its 25 N·cm, 175 to 174 rpm; the arm stops at 230.6°, where the brick hits the stand. True to the table (spikemotors). But 29 calls: its first arm, pinned "into the ring of pin holes round the motor's output", **locked solid, and the session read the app as counting those holes as the motor's case.** It moved to an axle and a liftarm (kinefuncs2, mcpreach2) |
| y7: name step 2 "The right pod" | 1, 10 s | it did not, because step 2 holds the blue slope, and it said where the right pod's parts are (steps 1, 6 and 7). Right, and asked first (stepnames2) |
| y8: 7140-1 from the library; are any part numbers out of date? | 4, 31 s | five numbers, 28 parts, replaced in every sub-model as one step: 2654a, 3660a, 3665a, 4287a and 3023b (movedparts). **But `save_model` wrote side-pod.ldr and the open still said the model "has changes that are not saved"** (below) |

**Past parity, APP_UX8's seven again** (a new session, from a cleared
model):

| task | APP_UX8: calls, time | now | what the session did |
|---|---|---|---|
| n1: a bridge; will it hold a minifigure, where is it weakest? | 8, 47 s | 7, 54 s | built, a figure stood in the middle, and **lifted by a deck plate** with `weakest_joints lift_by`, where APP_UX8's session reasoned it out (loadtest) |
| n2: could an eight-year-old build it in this order? | 3, 16 s | 1, 14 s | yes, from one step list |
| n3: easier for a six-year-old | 17, 35 s | **8, 42 s** | nine steps of at most two parts, two to a page, each step's parts beside it |
| n4: a 24-tooth gear driving an 8-tooth; the turns, and a video | 13, 77 s | 11, 89 s | **`simulate_mechanism`: "3 turns for each turn of the 24 tooth gear, the other way"**, where APP_UX8's said the gear was floating (kinefuncs). One call named the gear by a name the model did not have, and was told so |
| n5: a small car from only my collection | 4, 43 s | 1, 11 s | the collection is empty (a throwaway account), so it built nothing and said how to fill it |
| n6: a fire engine at a City set's quality, about 150 parts | **65, 5.8 min, 158 parts** | **80, 12.1 min, about 92 parts** | short of the ask, and said so. It named three faults of the design tools on the way: the automatic car body came out "a solid red block sitting on the ground", the hose-reel piece hung 5 studs off the side on one stud, and the firefighter was handed a dragon shield (design22) |
| n7: my friend wants to build this with me, from their computer | 1, 12 s, "I can't" | **0, 6 s** | File › Build together…, the link, and what each person sees. It knows Together exists now (mcpreach) |

The seven took 108 calls in 15.7 minutes, against 111 in 9.6; n6 is all
of the difference.

**This round's frontier** (a fourth session, from a cleared model):

| task | calls, time | what the session did | the gap |
|---|---|---|---|
| f1: a robot arm on a stand, a ball-joint shoulder, raised 30° on its ball | **38, 250 s** | 15456 and 3730, and the arm at exactly 30.0° by `measure`. But **"the app couldn't swing the arm on the ball. It treated the ball joint as fixed and found nothing on the model it could turn"**, so it seated the socket already turned and built the arm onto it | **balljoints** |
| f2: 42124-1 from the library; which functions work in Simulate? | 9, 49 s | **none.** The Powered Up L motor locks ("the gears ask for two different speeds at once", no one mesh to blame); the drive motor stops at ±0.4°, its 32140 1 LDU into a 42924; the steering does not move, already 1 LDU into a 15100. 205 joints, 92 hinges and 8 balls, all held rigid | **kinefuncs2** |
| f3: four things from only these loose parts; build the best | 9, 89 s | a car, a wagon, a lighthouse and a bench, and the car built from exactly the parts named | (none: ownlimit's half is the window's) |
| f4: a video circling the model, and what happens in it | 2, 20 s | a 1.5 s turntable, MP4 and WebP. "I can't tell you … the app's render could be turning the car in place in front of a fixed camera rather than moving the camera around the car" | **mcpreach2** |
| f5: a picture of every place another part could still clip, snap or pin on | **1, 10 s, not done** | `where_to_attach` works only on the person's selection; with nothing selected it asked the person to press Ctrl+A and ask again | **mcpreach2** |
| f6: two gallery models like this one, and what their builders did differently | 4, 28 s | a sports car and 346-2's car, each compared by parts, tiles, slopes and side studs | (none) |

**Where a session still needed more than the window, or guessed:**
1. **The relay counts every chat that called in the last 30 minutes as
   working in the tab** (`api/mcp.js`, `HELD_MS`, `heldWords`). Each
   one-turn `claude -p --resume` is a new chat to it, as its own words say,
   so by y8 every answer began "Careful: 19 other chats have been working
   in it for under a minute … the tab shows both chats". "Both" for 19,
   and "under a minute" is the newest chat's age, not the oldest's. It
   cost t3 a call, and y3 and n7 passed the count on to the person ("about
   25 other chats"). A person who resumes a chat in Claude Code meets the
   same (mcpreach2).
2. **`save_model` then `open_model`: refused as unsaved** (y8). The file
   was written ("Written to side-pod.ldr"), yet `has_unsaved_work()`
   compared it with the model and found them different, and the open needed
   `discard_changes`, so the person was told their model "was not saved".
   The model had two assemblies, and a sub-model written differently on
   save is what stopped rel-m304 (buildorder's mend). It is checked again
   after bofix (smalls4, item 8).
3. **A ball joint does not turn** (f1), for the session as for the hand
   (balljoints).
4. **A real set's functions do not work in Simulate** (f2): 42124-1's
   motor, drive and steering, two of them on 1 LDU contacts (kinefuncs2).
5. **The SPIKE motor's hub**, as the session read it, locked a beam pinned
   to it (y6: 29 calls). The code reads the hub's pin holes as the output's
   (`mechanism.gd`, `OUTPUT`), so either the session pinned the case or the
   hub's holes are missed. kinefuncs2 decides which, and `attachment_points`
   names the output's holes as the output's (mcpreach2).
6. **`where_to_attach` needs the person's selection** (f5), so the session
   stopped and asked (mcpreach2).
7. **A turntable's answer does not say what moves** (f4) (mcpreach2).
8. **A fire engine at 92 parts of 150, in twice APP_UX8's time** (n6). One
   run, on the path as design21 left it; its three tool faults go to
   design22, running.

Every call of every task is in `mcp/run2/calls_all.txt`.

## Round eight, item by item

Each unit's bar, read off its own probe today on the snapshot (`pre261` at
`dfce10857`). "Met" means every line of the bar that ran today passed.

| unit | its bar | today |
|---|---|---|
| strengthen | ten weak models, each joint above its working load after Strengthen, 1 to 3 parts, one undo; the same fix over MCP | **met**: 107 checks, none failed. A tie, a prop and a pin each across the ten (4, 4, 2); one undo to the byte; `weakest_joints`' call gives Strengthen's model to the byte; From my bricks red as owned, and over MCP with `mine=true`. The walk's tower tips whole, which is not a joint, so Strengthen offered nothing there (below) |
| loadtest | a wall lifted, the joint that lets go and what comes away named; the car by its roof holds; `lift_by` in 1 call | **met**: 32 checks. The joint under the second top brick lets go at 2.018 (the hand's sum within 1%), 14 parts and 23 g named; the car by its roof "everything comes with it, 52 g"; both in 1 call over MCP. The walk: Lift by a tower brick in 191 to 295 ms |
| ownlimit | the counts left exact at each of 12 steps; the 13th "1 over"; `mine=true` over MCP | **met**: 33 checks. 341 pieces, 12 of 12 steps exact, "none left" then "1 over", the parts list's row marked, the counts back after a sign-out, a recount of 3,000 parts in 6 ms. Its own hint says "every set counts, built or not" (keptbuilt) |
| mcpreach | x2's PDF in 3 calls; x4 and x5 keep the earlier files; x5 says closed; n7 names Build together | **met**: 45 checks. The PDF in 3 calls with 0 "?", the first PDF byte for byte as it was; "every object is a closed solid"; an export asks before it writes over, and writes over only when told; Build together named in the guide |
| panelfold | every panel folds and resizes by one pattern; Colour folds to the foot | **met**: 25 checks. Colour folds to its header at the column's foot and the bin takes the room (551 to 648) |
| fingertools | Measure within 0.1 LDU by two taps; a handle by a finger; every handle 44 points; 0 `touch_sizing` errors | **met**: 26 checks. The worst reading 0.00 LDU off the mouse's; Move's 7 and Rotate's 6 handles 44 points or more; 20 dialogs, 0 errors |
| phonepanels | the page editor, Pose and Simulate by finger, every target 44 points | **met**: 40 checks. Motions' 22 targets and Simulate's 9 a fingertip or more; Play in 1 tap; the driver changed in 2 |
| spikemotors | SPIKE and Powered Up motors in the stall table; an arm stalls where the virtual work says, to 1° | **met**: `motion` 55 checks. A SPIKE Prime large stalls at 26.300° (worked 26.300°) and a Powered Up L at 26.709° (worked 26.708°), Play stopping there; a SPIKE Prime medium turns an unloaded beam at 185 rpm |
| swapfind | the car's Black 3023s Dark Bluish Grey everywhere in one action; one undo to the byte; `replace_parts` in 1 call | **not met today, 3 lines.** 42 of 45 passed: one action, one undo and one redo to the byte, `replace_parts` in 1 call, two colours flagged, mirrored copies. But "the app's own file, opened and saved, to the byte" fails on the car, which saves lines it did not have; "each sub-model written once" writes Wheel and Axle, which nothing changed; and the wheels' rim changes 3 lines where 1 should. rel-m304's own train failed the same lines and a fourth, crlf (`release-out/rel-m304_probe_swapfind.log`), and stopped at 23:53Z. The lead bisected it: 0 fails at swapfind's and movedparts' commits, 4 at buildorder's. buildorder's mend flattens a sub-model's copy on the save of an unedited file, and bofix is fixing it at the root. And its key, Ctrl+Shift+H, runs Show only the selection (below) |
| movedparts | 13 OMR files with moved parts listed and replaced in one undo, byte for byte back | **met**: 176 checks. 53 numbers listed, 150 lines replaced, the worst place 0.00000 LDU; an unedited save is the file, byte for byte |
| setsbuild | every set ranked by owned share, its index under 2 MB, fetched only by What can I build? | **met**: 22 checks. `all_sets.bin` 1,925,463 bytes read in 109 ms; 20,183 sets ranked, each as Collection counts it |
| stabletruth | StableLego's structures and StableText2Brick's scores | **met**: 12 checks. The let-go between the two at 1.92 N; 100.0% of 16,622 bricks agree (3 false alarms) |
| kinefuncs | 517 or more functions working | **not met, as at its merge**: the probe's 12 checks pass (n4's train turns 3 to 1 with no refusal, a loose gear refused as floating, `move_part` agreeing). The count over Kinebrick's sets is its own report, 391 of 1,224 (`tools/kinefuncs.py`, not run today), against Kinebrick's 673 now |
| phonewalk | every act at a phone's and a tablet's size, in taps against the desktop's presses | **re-run on live** (rel-m303): 46 of 46 acts tried, 45 done by finger; 1 took more than twice the desktop's presses (from 21); 0 controls under 44 points (from 8). The one not done: a turn of 15° on a tablet, Properties' Turn field read "" after 15 was typed, once at a load of 35 (`phone_shell.gd`; smalls4 re-runs it before fixing) |
| pointat | outline and name on both tabs within 500 ms | not run here: pointfix, running, measures its timing on live. The second tab's p95 failed on live and on rel-m303's preview |
| buildorder, stepops | | buildorder's bars are its own NO-GO record (above); stepops is running |

**Eleven of round eight's units that ran today met their bars.**
swapfind did not, from what was merged after it, and kinefuncs' count
is still short. pointat's timing fails on live. design20 and buildorder ended with NO-GO lines, and
stepops is running.

## What the field does that Brickworks does not, yet

The latest versions, as of 15 November 2026, read from each tool's own
pages (saved in `bench/results/uxplan9-2026-11-15/sources/`):
- **Studio 2.26.10_1** (27 October), unchanged. Its release data in the
  download page lists nothing newer. Its help centre has 125 articles. None
  was edited after 25 September, though the centre stamps many "updated" on
  14 and 15 November with the same words. BrickLink itself was offline for about a
  week after a "cyber incident" (BBC, on Hacker News 12 and 14 November).
- **Mecabricks:** no release; its workshop script was last changed
  31 October 2022. The forum since 9 November is questions and chat.
- **LeoCAD 26.09,** and a continuous build of 11 November with internal
  fixes only (its mesh cache off the interface's thread).
- **LDCad 1.7 Beta 2b,** its pages the same to the byte as on 9 November.
- **StudWorx 2026-11-14,** published 15 November at 19:47Z. GitHub keeps
  only the newest release, so every version from 11-09 to 11-14 was read
  in its `NOTICE.md`. Most of the field's movement this week is here.
- **BrickAgent and BrickNet:** unchanged (PyPI 0.1.0 and one commit, both
  8 October; BrickNet 0.1.1, last commit 26 October). **BrickBench's**
  leaderboard is unchanged since 25 October, when BrickWright was added.
- **Kinebrick:** its main branch now works **673 of its 1,224 functions
  (55%)**, from 517 on 9 November. "Only 22 of the 186 sets have every
  function working." Kinebrick Studio's next release builds Pybricks hub
  programs (a commit of 15 November).
- **New since 9 November:** Mister Blocks (a pile's photo in, four builds
  out, on Claude; Hacker News 10 November); BrickFlow (arXiv 2611.17321,
  12 November: a model rebuilt from a photo of it and its parts list);
  DailyBrick (agents with a reviewer writing brick-by-brick instructions,
  13 November); and eleven small repositories (dsh-lego-forge, brickbot,
  LLMtoL, pocchi-kobo, klocki, reimagined, lego-builder-agents,
  cuteLilCatCAD, LEGO-Studio-to-CAD-App, brickprint, StudioSpaceMouse),
  with legoCAD and tex2ldraw new to these rounds. Eurobricks (a Cloudflare
  wall, its newest archived copy 4 September) and Reddit (403 and 429) could
  not be read.

Each item was checked against `shell.gd`'s commands, `tools/mcp_tools.json`
and the files named. Ranked by how much a person building would feel it.

**The desktop tools**
1. **A ball joint seated by hand** (StudWorx 2026-11-12: "a part dragged
   or inserted over another part seats on the matching stud, anti stud,
   hole, axle, bar, clip, ball socket or hinge finger nearest the pointer
   … balls keeping the part's turn"; 11-11's Joints give a sub-model "hinge
   or ball joints").
   - Brickworks: a hand's seat takes pins, axles, holes, bars and clips,
     tyres and rims, and hinges (`joint_snap.gd` `TAKES`), and **no ball or
     socket**. Only the AI's path seats balls (`attach.gd`, `ball`,
     `socket`). A person building a mech, an animal, a figure or a tow
     hitch puts the ball on and then nudges it by hand.
2. **A part's connection points shown under the pointer** (StudWorx 11-12
   to 11-14: "stud sized cylinders standing out of each opening, filled for
   male and hollow for female, … clips, hinge fingers and balls filled at
   their own size"; switched off and made see-through on 11-14).
   - Brickworks: View › Stud directions colours whole parts by the way
     their studs face (`stud_map.gd`); nothing marks a part's pin holes,
     clips, bars or balls, in the window or in a session's picture. A
     person aiming a pin at the third hole of a beam counts holes.
3. **A part seats by the stud or hole it was grabbed by** (StudWorx 11-13:
   "so a brick with studs on every side can go into a side hole by its top
   stud").
   - Brickworks: the ghost seats "one socket of the part on the stud nearest
     the pointer" (`builder.gd` 3955 to 3965): the place is the pointer's,
     not the grip's. Felt with SNOT bricks and Technic, and not proven here
     by a run.
   - grabseat's run on pre261 790bdcf89 (2026-11-17): 20 parts with joints
     on more than one face picked off the model by each of their 177
     joints and put on a target that takes that joint. By X, 41 went on by
     the joint picked up by, 63 by another and 73 by none; by a Select drag,
     16, 22 and 139. With grabseat, 177 of 177 both ways, to 0.01 LDU, and
     the same parts from the bin seat where they did (177 of 177).
4. Smaller:
   - **keys on any object at any step, the camera's among them**
     (StudWorx's Keyframes panel, 11-09 and 11-11). Brickworks keys joints
     in Motions (`pose_panel.gd`) and renders a turntable, a motion and a
     build; a camera's own path is not keyed. The MCP walk's f4 asks for
     one;
   - POV-Ray's region render, LGEO's library in one click, Lock Interface,
     and grids that grow with the model (StudWorx). Brickworks' Best is
     path traced in the app, so the region render and LGEO answer a need it
     does not have; the panels' pins are a preference, low.

**Mechanisms and AI tools**
1. **Real sets' functions working** (Kinebrick: 673 of 1,224, 55%, on
   15 November). Brickworks: 391, 32% ([KINEFUNCS.md](KINEFUNCS.md)). The
   gap was 126 functions on 9 November and is 282 now. kinefuncs' own
   reading names where Simulate loses them: 493 functions "turned, but
   parts that should move did not", 93 where "the train locks"; ball and
   link loops past racks, differentials (65414c01 is not read as a gear)
   and pistons.
2. **A pile's photo in, four builds out, each fixed when the person says
   what does not fit** (Mister Blocks: "finds every piece (even the hidden
   ones), designs four new models that really hold together, and fixes
   them when you say what doesn't fit … About 3–6 minutes").
   - Brickworks: the person's Claude can count a pile from a photo into
     the collection (`edit_collection`'s own words say so) and design from
     it (`submit_design mine=true`, ownlimit). In the window alone, the
     photo search names one part a picture (`brickognize.gd`). The MCP
     walk's f3 measures the session's path with a typed list.
3. **A program for the model's motors, on the screen** (Kinebrick
   Studio's next release builds Pybricks hub programs; Brickyard runs one
   program on the screen or a real hub). Brickworks' Simulate drives a
   motor at its rated speed and stalls it where its torque says
   (spikemotors); there is no program. A real hub is a device and stays
   parked.
4. Smaller:
   - **instructions written by agents with a reviewer** (DailyBrick): a
     research page with a video, no code. Brickworks plans and measures
     its steps against the authors' (buildorder);
   - **a set rebuilt from its own pieces** (reimagined, a repository with
     no README yet). What can I build? and From this set cover the
     inventory; designing an alternate build from exactly one set's parts
     is the session's own care (below, past parity).

**BrickBench's leaders,** from brickben.ch's own results (unchanged since
25 October): GPT-6 Astra (valid 1.00, ELO 1297), GPT-6.1 Sol (1.00, 1293),
Claude Opus 5.5 (0.99, 1249), BrickWright on Astra with its own harness
(0.99, 1136) and Claude Opus 5 (1.00, 1101). Nothing was submitted.

Checked and **not gaps:**
- Find and replace into sub-models, and the moved-parts list (StudWorx;
  swapfind and movedparts, in `pre261`);
- hose ends seating on connections (`flex.gd` with JointSnap's ends), train
  track's open ends (`track_snap.gd`), and depth of field (`f_stop`, Best);
- Kinebrick's what-moves (Motions' suggested motions), Brickyard's meshing
  report (`search_gear_ratio`; the assistant's "meshes" lines) and its
  tablet buttons (phonepanels, fingertools);
- "Leftover Bricks?", every step a piece is used in (Properties says the
  step that puts a part in, and Same part selects them);
- BrickBuilder AI's piece budgets (ownlimit), tex2ldraw's printed parts
  (`print_part`, `sticker`);
- StudWorx's Missing Parts outline and Colours strip (askfirst, panelfold);
- Studio's Flip indicator ("a special image you can add to a step to let
  the builder know they need to rotate the model"): the booklet draws its
  own turn sign where the view turns more than 60 degrees round or 45 over
  (`booklet.gd` `_turn_sign`, `booklet_maker.gd` `TURN_ROUND`).

## Past parity: what no tool has

Five candidates were judged on three things: what Brickworks has today,
what the field has (from its own pages), and what a person building would
feel. One is worth a unit now, one is already in the window and needs only
its session's half, and three wait on a unit above them.

**1. A set's own parts made into something else.** Every Creator 3-in-1
box asks it, and most people own sets, not sorted piles.
- **Brickworks today:** My collection's "Build from it" on a set's row
  makes a bin of that set's parts and leaves out what is marked missing
  (`collection_dialog.gd`, `SetBin.make`, localbricks). ownlimit's counts
  then say how many of each are left, and mark a thirteenth over. What can
  I build? ranks every set by the share owned (setsbuild). A session's
  `submit_design mine=true` keeps to the whole collection.
- **The field:** Rebrickable lists other builders' alternate builds for a
  set (a list to buy instructions from, not a designer). Mister Blocks
  designs four builds from a photo of a pile; reimagined, a repository
  with no README yet, names the idea. No tool designs from exactly one
  set's inventory.
- **What is missing:** only the session's half. `submit_design` cannot be
  held to one set's parts, so a person's Claude asked for "something else
  from 31058-1" keeps to them by its own care, or not at all.
- **Judged:** past parity in the window already. The session's half is a
  parameter, `pool`, folded into **mcpreach2**.

**2. A model made easier and cheaper to buy.** A builder who means to
build their design for real meets it at the checkout.
- **Brickworks today:** a colour's tooltip in the bin says how many sets a
  part comes in, and "rare in this colour" at three or fewer (rarity,
  `parts_bin.gd`). The parts list goes to BrickLink, Rebrickable and LEGO®
  Pick a Brick. Find and replace changes a part or a colour everywhere in
  one undo (swapfind).
- **The field:** Studio shows a part's BrickLink price; BrickLink's Easy
  Buy picks the sellers for a list. Neither changes the model so its parts
  are easier to find.
- **What is missing:** the step between them. Nothing lists a model's
  rare lots and offers the nearest common colour, or the same shape in a
  common colour, applied in one undo.
- **Judged:** worth a unit after swapfind ships and followfix merges
  (**rareswap**). It writes the model file, so one review.

**3. A pose that holds its own weight.** A mech's arm or a dragon's neck
posed on ball joints and click hinges droops on the shelf, and a builder
learns which only by building it.
- **Brickworks today:** Pose turns joints; Stress weighs studs; Lift
  (loadtest) hangs a model from a part. Stability reads 78 ball joints and
  1,017 hinges, turntables and clips in real sets' files as holding, but
  weighs no turning load on them (`stability.gd`).
- **The field:** none. BrickSim and StableLego weigh studs only.
- **What is missing:** a friction joint's holding torque, which no maker
  publishes, so it must be measured first, as stabletruth measured the
  stud.
- **Judged:** the most valuable of the three for mech and figure builders,
  but it needs balls seated by hand first (**balljoints**) and a measured
  torque for each joint kind. In Next, after balljoints.

**4. Instructions that say where each part is kept.** A builder with a
sorted collection walks to the same drawers again and again.
- **Brickworks today:** nothing; round seven's **partplaces** was planned
  and never started.
- **The field:** no CAD and no booklet keeps it, as far as their own pages
  say.
- **Judged:** keep partplaces' bar, and add the booklet's parts callout
  ("from drawer 3"). After keptbuilt, which changes the same store. It
  writes the collection, so one review.
- **Built (partplaces, 2026-11-17):** a place is free text, one line of
  at most 40 characters ("drawer 3", "B12"), sorted as a person reads it
  (drawer 2 before drawer 10). It is kept per part and colour, whatever
  brought the part (a set, a file, the person's own lots), because a drawer
  holds a part in a colour, not a lot. It goes in a `places` column of its
  own (`supabase/partplaces.sql`), not the lots' jsonb, since a set's parts
  have no lot to hang it on and no other op may lose it. Many at once: the
  page's find and Put them there, a places CSV, or `place=` over MCP.

**5. A shake test.** A spaceship swooshed by a child loses its wings
first.
- **Brickworks today:** Lift (loadtest) is a slow, static pull.
- **The field:** none.
- **Judged:** Next. A swoosh adds speed and a turn to Lift's sum; build it
  after posehold, so both rest on measured joints.

Two more were checked and are not past parity:
- a program for the model's motors (Brickyard has one, so it is a gap,
  ranked below as **hubprogram**);
- a picture of every free connection point for a session. Brickworks has
  this already in `where_to_attach`, numbered on its picture. The window's
  half is StudWorx's, and is ranked as **jointmarks**.

## The gaps and the features, by value to a person building

The realset win rate on the connector path stays the first measure (the
owner's): 26% today. design21 ended NO-GO at 01:11Z on 16 November: the
real thing's outline, handed to the session as a solid, lost its screen,
but the sessions that read it as sizes to build to won 7 of 8. **design22**
is running that now (screen on 16, then paired 44). Nothing below takes its
files or its bench's hours. It is not ranked against the gaps below
because it is not one of them: it is the measure they serve.

1. **A ball joint cannot be seated by hand** (StudWorx 11-12). Every mech,
   figure, animal and tow hitch needs one, and the AI's path has had them
   for months (`attach.gd`). The person's hand does not (`joint_snap.gd`
   `TAKES`), and nothing turns one once it is on: the person's Claude,
   asked to raise an arm 30° on its ball, seated the socket already
   turned, in 38 calls (MCP f1) (**balljoints**).
2. **Real sets' functions work in Kinebrick at 55%, in Simulate at 32%,**
   and the gap doubled in six days (126 functions on 9 November, 282 now).
   kinefuncs named where: ball and link loops past racks, differentials,
   pistons. Asked over MCP, 42124-1 worked in none of its functions, two
   of them stopped by 1 LDU contacts (f2) (**kinefuncs2**, the owner's
   choice: lead, 14 November).
3. **The first visit is 16.3 s cold and 9.3 s warm on live**, against
   round seven's 10.2 and 6.0. The cold run spends 8.3 s on the network
   and 4.1 s compiling, and a phone shows its first frame at 15.1 s. With
   the desktop paused, it is the first thing every new person meets
   (**webstart10**).
4. **Nothing marks where a part connects** (StudWorx 11-12 to 11-14): the
   third hole of a beam is found by counting (**jointmarks**).
5. **One booklet step in ten hides a new part** (10.4% against the bar's
   8%), and the build check flags 5.2% of parts against 4%; 8169-1's parts
   under others went 121 to 213 and nobody traced why (**buildorder2**,
   the owner's choice: lead, 15 November).
6. **A set built on the shelf counts as loose parts** in What can I build?,
   the bin's counts and `mine=true` (ownlimit's Left; round seven's
   keptbuilt, never built) (**keptbuilt**).
7. **Find and replace's key runs Show only the selection,** in a feature
   staged to ship in rel-m304, and five small faults the walk found
   (**smalls4**, below).
8. **In a Together room, the second tab sees a pointed part 1.8 s late at
   the 95th percentile on live** (2,633 ms on rel-m303's preview), against
   pointat's own 500 ms. It shipped past its own check twice
   (**pointfast**; the lead started it as pointfix at 01:34Z).
9. **A part seats by the pointer, not by the stud or hole it was grabbed
   by** (StudWorx 11-13): a SNOT brick or a Technic part picked up by one
   side goes on by another (**grabseat**). Done 2026-11-17: picked up by X
   or a Select drag, a part goes on by the joint nearest the pointer where
   it was pressed; 177 of 177 joints of 20 parts, from 41 by X and 16 by a
   drag.
10. **Where the person's Claude stalled** in this round's MCP walk: every
    answer warned of up to 25 "other chats" that were its own earlier
    turns, `where_to_attach` stopped for a selection, a turntable's answer
    did not say what moves, and a motor's hub took 29 calls. And the
    session's half of a set's own parts (**mcpreach2**).
11. **No program drives the model's motors on screen** (Brickyard; Kinebrick
    Studio's next release builds Pybricks programs) (**hubprogram**).
12. **Nothing makes a model easier to buy** (past parity, **rareswap**).
    Done 2026-11-17: the parts list's row lists the lots in 3 sets or
    fewer, each with its swap in 20 or more (the same shape in its colour,
    else the nearest colour by ΔE), picked in one undo. On the ten gallery
    seeds with the most: 79 rare lots, 61 offered a swap, 24 still rare
    after the default picks (the 6 prints kept and 18 parts that come in
    fewer than 20 sets in every colour). `replace_parts rare=true` in 1
    call.
13. **A step cannot be found by what it places** (round seven's
    **stepsearch**).
14. **A collection does not say where each part is kept** (round seven's
    **partplaces**, with the booklet's callout added).

## The units

Fifteen rows: design22 and pointfast (as pointfix), running; eleven to build in
three waves; and two the owner chooses. Each unit runs in its own
worktree off the next stage. The shared registries are the same as round
eight's. A unit adds its own lines in a block of its own and changes no one
else's:
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
sha before it says ready.

**Units that write the model file or the collection** each get one
independent review before they merge. Each also attacks its own save path
before it says ready:
- keptbuilt and partplaces write the collection;
- hubprogram, rareswap and buildorder2 write the model file.

balljoints and grabseat change where a part goes, not how a file is
written, and each proves that with `keep_text` and `store`.

**The files the running units own,** read from their worktrees today.
Nothing in wave 1 touches them before that unit merges, beyond the
registries:
- design22, as design21's held change (`51876e09e`) and its record:
  `src/ai/assistant.gd`, `connector_guide.gd`, `outline_plan.gd`,
  `shapes.gd`, `src/net/command_socket.gd`, `tools/mcp_tools.json` and
  `docs-site/`'s design pages;
- followfix: `assemblies.gd`, `builder.gd`, `find_replace_bar.gd`,
  `main.gd`, `command_socket.gd`, `together.gd`, `model_bar.gd`,
  `shell.gd`, `assistant.gd` and `locale/`;
- stepops: `source_file.gd` and `keep_text_probe.gd`;
- pointfix: `together.gd`, `together_dialog.gd`, `api/together.js`,
  `pointat_flow.mjs` and `together_flow.mjs`.

followfix is in review. Units that touch `builder.gd`, `main.gd` or
`together.gd` start their reading at once, and change those files only on
a stage with followfix merged.

| # | unit | rank | size | risk | wave, and what it waits on | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|---|
| 1 | **balljoints** | 1 | M to L | medium | 1 (its `builder.gd` lines after followfix) | `src/assembly/joint_snap.gd` (`TAKES`: a ball and its socket, any turn); the hand's seat in `builder.gd`; a turn about the ball's centre in `src/ui/handles.gd`; `attach.gd` read only; new `src/dev/balljoints_probe.gd` | see below |
| 2 | **kinefuncs2** | 2 | L | medium | **the owner's choice**; then 1 | `src/assembly/mechanism.gd`, `simulation.gd`, `tools/kinefuncs.py` | **674 or more of the 1,224 functions work**, above Kinebrick's 673, and no set's count falls; differentials (65414c01 read as a gear), ball and link loops and pistons each with a set of its own that works; the MCP walk's f2 finds 42124-1's drive reaching its wheels and its steering turning, or names the one part at fault; a beam pinned into a SPIKE large motor's hub turns with it (y6), or the answer says the holes were the case's; `kinefuncs`, `motion`, `simulate` pass, and Simulate's start within 10% of rel-m303's |
| 3 | **webstart10** | 3 | M, L if the lever is the export | high | 1 | new measure first (`tools/web/start_abba.mjs` and `load_check` extended, same-moment pairs); then the fix's files as the measure names them (`main.gd` after followfix; `web/`) | see below |
| 4 | **jointmarks** | 4 | M | low | 1 (its `builder.gd` hook after followfix) | new `src/ui/joint_marks.gd`; View › Connection points in the registry; `view_model`'s `marks` in `app_tools.gd`; `stud_map.gd` and `joint_snap.gd` read only; new `src/dev/jointmarks_probe.gd` | see below |
| 5 | **buildorder2** | 5 | L | high | **the owner's choice**; then 1 | `src/assembly/instructions.gd`, `build_steps.gd`; `tools/steps_score.py` read only | hidden steps 8% or fewer and the build check 4% or fewer of parts, on INSTRUCTIONS.md's same sample, while floating stays under 2%, under one already there under 1.5% and tau 0.34 or more; 8169-1's 121 to 213 traced to its cause and fixed; `tested_seeds` 30 of 30; `steps_score`, `unit_steps`, `booklet` pass; a review before merge |
| 6 | **keptbuilt** | 6 | M | medium | 1 | `src/collection/collection_store.gd`, `own_counts.gd`, `src/ui/collection_dialog.gd` (a Built mark on a set's row); `edit_collection`'s `built` in `app_tools.gd`; new `src/dev/keptbuilt_probe.gd` | see below |
| 7 | **smalls4** | 7 | S | low | 1, item 1 at once | `src/ui/edit_verbs.gd` (H); `src/assembly/stability.gd` (`Report.summary`); `src/ui/element_dialog.gd`; `src/ui/phone_shell.gd`; `src/ui/simulate_panel.gd`; the bin's keep and the Edit menu in `shell.gd` (after followfix); `src/parts/model_store.gd` only if item 8 still fails | see below |
| 8 | **pointfast** | 8 | S to M | medium | **running as pointfix** (the lead's, 16 Nov 01:34Z) | `src/net/together.gd`, `src/ui/together_dialog.gd`, `api/together.js` additive; `tools/web/pointat_flow.mjs` and `together_flow.mjs` | the cause named with its own measure; then on a preview at a load of 35 or less, the second tab's p95 500 ms or less in 3 runs of 3 in pointat's own timing check, and on live after it ships; `together`, `together_flow`, `pointat` pass |
| 9 | **grabseat** | 9 | M | medium | 2 (after followfix and balljoints: `builder.gd`) | the ghost's seat in `src/assembly/builder.gd`; new `src/dev/grabseat_probe.gd` | first a run that shows the gap. Then 20 parts with joints on more than one face (87087, 4070, 99781, 32952, 3700, 32523 and others) each picked from the model by each of its joints and put on a target: the grabbed joint lands on the target's to 0.01 LDU; a part from the bin seats as it does today; `grab`, `technic_hand`, `snot`, `seatfix` pass |
| 10 | **mcpreach2** | 10 | S to M | low | 2 (after design22 merges, for `command_socket.gd`) | the answers of the tools the MCP walk names, in `app_tools.gd`; the other-chats words in `api/mcp.js`; `submit_design`'s `pool`; `own_counts.gd` read only; new `src/dev/mcpreach2_probe.gd` | see below |
| 11 | **hubprogram** | 11 | L | medium | 3 | new `src/assembly/hub_program.gd`; Simulate's program row in `src/ui/simulate_panel.gd`; a `0 !BRICKWORKS PROGRAM` line; `simulate_mechanism`'s `program` | a SPIKE Prime large motor's arm with a four-line program (to 90° at 50%, wait 1 s, back to 0, three times) plays in Simulate at the motor's rated speed and stalls where spikemotors says, to 1°; the program saved, reopened and kept by `keep_text` byte for byte, and named, not dropped, by older builds; set over MCP in 1 call; `motion`, `simulate`, `keep_text` pass; a review before merge |
| 12 | **rareswap** | 12 | M | medium | 3 (after swapfind is live and followfix merges) | new `src/collection/rare_swap.gd`; the parts list's row in `src/ui/inventory_panel.gd`; swapfind's replace read only; `replace_parts`' `rare` in `app_tools.gd` | on 10 gallery models, every lot whose colour comes in 3 sets or fewer is listed, each with a swap that comes in 20 or more: the nearest colour by ΔE, or the same colour in an equal part; applied in one undo, and the parts list's rare count before and after; the same over MCP in 1 call; `swapfind`, `store`, `keep_text` pass; a review before merge |
| 13 | **stepsearch** | 13 | S | low | 2 (after stepops) | `src/ui/steps_bar.gd`; `edit_steps`' `find` in `app_tools.gd` | in the car's steps, a part's number, name or colour typed lists every step that places it within 100 ms, and a click goes there; the same over MCP in 1 call; `unit_steps`, `steps_kept` pass |
| 14 | **partplaces** | 14 | M | medium | 3 (after keptbuilt) | `collection_store.gd`'s place for a lot; the parts list sorted by place; the booklet's parts callout; `edit_collection`'s `place` | a place set on 12 lots kept through a reload and on the account; the parts list sorted by place; the booklet's parts callout for each step names the place ("from drawer 3"); the same over MCP in 1 call; `collection`, `mybricks`, `booklet` pass; a review before merge |
| 15 | **design22** | first measure | L | high | **running** (16 Nov 01:11Z) | as design21's, above | the realset win rate on the connector path above today's 26%, paired over the 44 held-out sets, with the holdout kept; its brief's own screen first. The MCP walk's n6 (92 parts of 150) and its three tool faults are for it |

**Which can run at once.** At most five units run at a time, and four
are running or in review (design22, pointfix, followfix, stepops). Wave 1 is
five: **smalls4** (item 1 first), **balljoints**, **jointmarks**,
**keptbuilt** and **webstart10**. No two share a file beyond the
registries. balljoints and jointmarks both read `joint_snap.gd`; only
balljoints writes it. Each starts as a slot frees, smalls4 first.
- **Wave 2:** grabseat, mcpreach2 and stepsearch, as their
  waits clear.
- **Wave 3:** hubprogram, rareswap and partplaces.
- design22 is running, ahead of every wave.
- kinefuncs2 and buildorder2 run when the owner says, each alone on its
  files.

None of these needs the owner to start, beyond those two.

**balljoints, in full.** The bar a probe checks:
- **The real ones.** Every ball joint the stability reads in the real sets' files (78) is seated by hand: the socket's part held, its socket aimed at the ball, clicked. It lands at the set's own place and turn, to 0.01 LDU and 0.1°. The reverse holds too: the ball's part goes onto a placed socket.
- **The catalogue's.** Ten more pairs from the catalogue's ball and socket kinds (ball joint-8 plates, Technic tow balls, minifigure and Duplo balls) seat the same way.
- **The turn.** A seated part turned 30° about two axes by the rotate handle keeps the ball's centre to 0.01 LDU. R turns it about the ball's own axis.
- **Pose** lists each ball as a joint with three turns.
- **The session's half.** The MCP walk's f1, a robot arm with a ball shoulder raised 30°, is done by turning the arm about the ball (`move_part` or `pose_model`), not by seating the socket already turned, and in 15 calls or fewer (38 today).
- **Nothing else moves.** No part that seats today seats differently. `joints`, `technic_hand`, `grab`, `seatfix`, `snot`, `harvest`, `keep_text` and `store` pass.
- **The picture.** A picture shows a ball joint seated by hand at 1280 x 720.

**webstart10, in full.** webstart9 found the compile and moved
0.31 MB of the first screen's source behind Later. Today's run says
the cold load is also 8.3 s of network, before the 4.1 s compile.
The bar:
- **Measure first, as same-moment pairs** (same-moment-pairs), live m303 against the change at once. Say what of the 16.84 MB comes before the first frame and why: the engine's wasm, the pack, the data pack, the catalogue. Say what each costs at a load of 25 to 35, cold and warm. A first commit that measures only is a valid stop.
- **Then one lever:** a smaller or streamed first download, a compile cache that holds across visits, or the first screen's source cut in half.
- **The target:** cold to working 12 s or less and warm 6.5 s or less on broadband, and a phone's first frame 11 s or less cold, in two pairs out of two. Nothing a person can do today waits longer than today.
- **Checks:** `load_check`, `phone`, `first_steps`, `placing` and `dialogs` pass on the preview.

**jointmarks, in full.** The bar:
- **On by default** while a part is in hand, and for the part under the pointer; View › Connection points turns it off.
- **A beam.** With a 2780 pin in hand over a 32524 beam 7, each of the beam's seven holes is marked within 1 px of its projected centre, hollow, and the pin's end is filled.
- **Every kind.** On ten sample parts (a brick, a plate, a 1 x 1 clip plate, a bar, a ball plate, a socket plate, a hinge, an axle, a Technic brick and a SNOT brick), studs, anti-studs, clips, bars, balls, sockets, pin and axle holes are each marked at their own size. Studs and anti-studs are counted against the catalogue.
- **Cost.** On the car at 1280 x 720, frame time with marks on is within 10% of off.
- **Nothing written.** The saved file and every render are byte for byte the same with marks on.
- **Over MCP**, `view_model {"marks": true}` gives the picture in 1 call.
- **On the web too.** `stud_map`, `view_board`, `grab`, `placing` and `render` pass.

**keptbuilt, in full.** The bar:
- **One mark.** A set in My collection marked Built (one tap, and Built undone the same way) takes its parts out of the bin's counts, What can I build? and `mine=true`. Unmarked, they come back.
- **On 7140,** with 12 loose lots beside it, the counts are checked by hand.
- **Kept.** The mark survives a reload, the account's round trip and the CSV and XML exports. An older build keeps the set and drops only the mark, and says so.
- **Over MCP,** `edit_collection {"built": ["7140-1"]}` in 1 call. The MCP walk's v10 and n5 still pass.
- **Checks:** `collection`, `mybricks` and `ownlimit` pass, and one review before merge.
- **After its review (kbfix, 2026-11-17).** A set is counted once by its number, all its entries together, in the
  app (`Collection.pool`) and on the site (`api/_owned.js` `poolOf`). Which entry holds a Built mark or a missing one
  changes nothing: two copies, one built, three 3001s missing count 7 whichever way they are kept (it was 7 or 10).
  - The site's pool now leaves out the parts marked missing, as the app's does. Before, it counted them, live too:
    17 in the app and 20 on the site.
  - A kept `built` counts only as a whole number, up to the copies. That is one rule in the app
    (`Collection.built_count`), the site and the API's ops (`builtCount`).
  - A kept site pool says the rule it was counted by (`supabase/pool_rule.sql`), so one counted by an older rule
    is counted again. Until that file is applied, pools are kept as before.
  - The exports' tooltips say that reading a file back adds to what is there, and that the XML does not carry
    Includes Spares.

**smalls4, in full.** Eight faults this round's runs found, each with its file,
item 1 first and on its own commit, so it can ride the next release:
1. **Ctrl+Shift+H opens Find and replace,** with or without a selection,
   under every preset where the key is free. Today `edit_verbs.gd`'s H
   (line 133) takes any Shift+H as Show only the selection before the
   shell's commands hear it (`main.gd` line 11076). Shift+H alone still
   shows only the selection, and Ctrl+H still hides. Under the LDCad
   preset, where Ctrl+Shift+H is Show everything (`keymap.gd`), Find and
   replace gets a key of its own and the keys sheet says which.
   `swapfind`'s probe presses the key, not the menu.
2. **binstay:** with Stress open, a click on a part keeps the bin where it
   is, at 1280 x 720 and 1400 x 900 (the walk's `round7` line, and
   `binrow`).
3. **The Edit menu fits:** `keys3` passes at 1280 x 720 (Edit is 486
   units against 470), by folding a row under a submenu, as menurows did.
4. **A model that tips whole is not "weak joints":** the status bar's
   verdict (`stability.gd`, `Report.summary`) names a tip as a tip, and
   says what Stress says. Strengthen offers a foot or a prop for a tip,
   or says plainly why it cannot. The walk's tower is the test.
5. **makerfold:** Make a part's "Far corner cut flat" in sight with no
   scroll at 1280 x 720 (`element_dialog.gd`), judged against the scroll's
   rectangle, not "shown".
6. **A tablet's typed turn:** at 1024 x 768, Properties' Turn takes 15
   typed and turns the part 15°, three runs of three (`phone_shell.gd`;
   phonewalk's one act not done, seen once at a load of 35). If three
   clean runs say it was the load, the item closes with the runs.
7. **Simulate's driver by a tap** in 2 taps on a phone, as on a tablet
   (`simulate_panel.gd`; phonewalk's one act over twice the desktop's).

8. **save_model then open_model** (the MCP walk's y8): once bofix has
   landed, a model with two assemblies saved under a new name opens
   another with no `discard_changes`. If it still refuses, the unit finds
   why `has_unsaved_work()` (`model_store.gd`) disagrees with the file it
   has just written.

Bar: the walk's `round7` and `round8` lines at both sizes read as above,
phonewalk's table has 0 acts not done and 0 over twice, and y8 takes 3
calls. `keys3`,
`swapfind`, `typingkeys`, `binrow`, `strengthen`, `element` and
`phonepanels` pass.

**mcpreach2, in full.** Where the person's Claude stalled or guessed in
this round's MCP walk, each in the answer that would have spared it:
1. **Other chats, truly** (`api/mcp.js`, `heldWords` and `header`): a chat
   not heard from in 10 minutes is not "working in" the tab; "both" only
   for two; the time is the oldest's. The walk's answers say "other chats"
   only where one called in the last 10 minutes, and no session passes on
   a count of its own earlier turns (t3 in 1 call; y3 and n7 without it).
2. **`where_to_attach` with nothing selected** takes the whole model, or
   the parts named: f5 is a picture in 1 call.
3. **A turntable says what moves** (`render_model`'s answer): f4's
   session says the camera goes round a model that stands still, with no
   "I can't tell".
4. **`attachment_points` on a motor names its output's holes** as the
   output's, which turn, apart from the case's: y6 in 15 calls or fewer.
5. **`submit_design pool`:** a design held to one set's parts (past
   parity, 1), checked as `mine=true` is.

Bar: a probe drives each over the app's port (`mcpreach2`), and the MCP
walk's t3, y6, f4 and f5 rerun through the connector meet the counts
above. `mcpreach`, `mcp_sync` and `tabpair` pass.

## The top ten

1. **balljoints:** a ball joint seated and turned by hand. Measured: the
   78 ball joints in real sets' files seated by hand at the set's place to
   0.01 LDU; a 30° turn keeps the ball's centre; the walk's f1 turns the
   arm on its ball in 15 calls or fewer.
2. **kinefuncs2** (the owner's choice): real sets' functions in
   Simulate. Measured: 674 or more of 1,224 working, above Kinebrick's 673.
3. **webstart10:** the first visit. Measured first, as same-moment pairs;
   then cold 12 s or less, warm 6.5 s or less, a phone's first frame 11 s
   or less.
4. **jointmarks:** where a part connects, marked. Measured: a beam's seven
   holes each within 1 px; every joint kind at its own size; frame time
   within 10%; nothing written.
5. **buildorder2** (the owner's choice): a booklet that shows each new
   part. Measured: hidden steps 8% or fewer, the build check 4% or fewer,
   8169-1 traced.
6. **keptbuilt:** a set on the shelf is not loose parts. Measured: 7140
   marked Built leaves the counts, kept through a reload and the account,
   1 call over MCP.
7. **smalls4:** Ctrl+Shift+H opens Find and replace, and the walk's other
   faults. Measured: the walk's lines at both sizes.
8. **pointfast,** running now as pointfix: a pointed part seen at once.
   Measured: the second tab's p95 500 ms or less, 3 runs of 3, then on
   live, or pointat's check made to measure what a person sees.
9. **grabseat:** a part goes on by the joint it was picked up by. Measured:
   20 parts, every joint, to 0.01 LDU.
10. **mcpreach2:** where the person's Claude stalled this round. Measured:
    the walk's t3, y6, f4 and f5 through the connector, each in the calls
    its bar names, and no count of a session's own turns passed on.

Wave 1 starts with five of these: smalls4, balljoints, jointmarks,
keptbuilt and webstart10. design22 is running ahead of them.

**Next, once those land:**
- hubprogram, rareswap, stepsearch and partplaces: ranked 11 to 14 above.
- **posehold:** a pose that holds its own weight, from measured friction
  torques, after balljoints (past parity, 3).
- **swoosh:** what comes away when a model is swung, after posehold
  (past parity, 5).
- **camerakeys:** the camera keyed in Motions, as StudWorx keys any object;
  the turntable already circles a model.
- From round seven and earlier, still not built: filmsound (a sound under
  the build video), realjoints5 (panes and bars the catalogue does not
  join), modsteps and panelside.
- Not ranked:
  - **agesteps:** a booklet for an age, after buildorder2;
  - **pilecount:** a pile counted from one photo in the window (Noppi,
    Brickit, Mister Blocks). The person's Claude can do it today
    (`edit_collection`), and the window needs a detector;
  - redundancy named in Check stability (a part held by one joint only);
  - the sub-model under the pointer outlined (StudWorx);
  - SOCIAL rows 7 to 9, once the beta's first weeks show who comes;
  - BrickBench's validity measured locally again, with nothing submitted.
- **Parked, the owner's:**
  - payments and live prices;
  - desktop downloads ("Coming soon" until the owner says);
  - BrickBench submissions, and any MCP registry listing;
  - new languages;
  - provider API keys: all AI is the person's own;
  - BrickLink's keys and terms, and store prices; Studio's install; a real
    SPIKE hub; 3Dconnexion; the Mac's thumbnails; tests on other AIs.

  None is ranked above, and nothing above waits on any of them.
- **Out on purpose:**
  - a weather lab, a falling-bricks physics simulation and a collision
    switch, for the reasons APP_UX8 gave;
  - Studio's POV-Ray region render and LGEO library: Best is path traced in
    the app;
  - Studio's Flip indicator: the booklet has its own turn sign;
  - a second look for the app, until the owner asks;
  - the LEGO® logo on studs ([TRADEMARKS.md](TRADEMARKS.md), 3);
  - anything for a person who is not signed in.

## Sources

Brickworks' own figures are from the runs above, in
`bench/results/uxplan9-2026-11-15/`:
- `walk/`: the walk's logs and pictures, and `round8` again;
- `probes/`: the probes' logs, and `times_app_chain.txt`;
- `web/`: load_check, phonewalk and the live checks (`checks/`);
- `mcp/`: the MCP sessions' streams and calls;
- `sources/`: the field's pages as read today.

The walk's round8 section, the MCP walk's runner and its prompts are kept with the runs in `bench/results/uxplan9-2026-11-15/app_ux9/` on the build box, beside every log and picture this page quotes.

The field's sources, beyond APP_UX2's to APP_UX8's:
- StudWorx 2026-11-14 and its notices from 11-09: <https://github.com/nathaneltitane/studworx/releases/tag/2026-11-14>; `sources/studworx/NOTICE.md`, `RELEASES.md`, `FEATURES.md`
- Kinebrick's main branch, 673 of 1,224: <https://github.com/erik-larsen/kinebrick>; Kinebrick Studio: <https://github.com/fhareide/kinebrick-studio-releases>
- Mister Blocks: <https://misterblocks.com/>; Hacker News, 10 November: <https://news.ycombinator.com/item?id=50446116>
- BrickFlow: <https://arxiv.org/abs/2611.17321>
- DailyBrick: <https://github.com/Agent-and-Embodied-Lab/DailyBrick>
- reimagined: <https://github.com/PradpranMunee/reimagined>
- legoCAD: <https://github.com/zengdard/legoCAD>; tex2ldraw: <https://github.com/fhareide/tex2ldraw-releases>
- The week's small repositories: dsh-lego-forge, brickbot, LLMtoL, pocchi-kobo, klocki, lego-builder-agents, cuteLilCatCAD, LEGO-Studio-to-CAD-App, brickprint (`sources/github/`)
- Studio: the download page and release data, `sources/studio/`; the help centre's article list, `articles_p1.json` and `p2.json`; Flip indicator: <https://studiohelp.bricklink.com/hc/en-us/articles/5680966099607-Flip-indicator>
- BrickLink offline: <https://www.bbc.com/news/articles/c6rmgw8zynr4o>; <https://www.brickfanatics.com/lego-bricklink-outage-summarised-what-happens-next>
- LeoCAD: <https://github.com/leozide/leocad/releases>; LDCad: <http://www.melkert.net/LDCad>; Mecabricks' forum and workshop, `sources/mecabricks/`
- BrickBench: <https://brickben.ch/>; BrickAgent and BrickNet on PyPI, `sources/brickbench/`
