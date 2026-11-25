# Releasing Brickworks

A unit an agent reports ready goes live within the hour, through these
scripts. Logs go to `$RELEASE_OUT` (default `$TMPDIR/brickworks-release`).

```sh
tools/release/release_wt.sh merge20 <main sha>        # a staging worktree that can deploy
MERGE_GATES=ship tools/release/merge_unit.sh <worktree> <sha> "Merge …" # each ready unit, as the user
#   on CONFLICTS: resolve, git add, then
tools/release/merge_finish.sh <worktree> "Merge …"
# the unit's affected probes (featuremap affected), then:
tools/release/ship.sh <worktree> <tag> site io …       # preview, its checks, then production
```

Or all of that in one command, queued behind the release before it:

```sh
tools/release/train.sh stage rel-m219 stage219 --after rel-m218 \
  --checks "io gallery" --units "unit1 unit2" --title "…"   # what its change reaches (lean.py)
#   --probes "grab fits" names exactly those; --probes all every headless one; --probes none --why "…" none
#   --every-check carries no proof over (every check its change reaches)
#   no app file changed: the web lane, on the live export, with no probe (--full, --web; --plan says which)
TRAIN_REHEARSE=1 tools/release/train.sh stage reh1 homefix   # the same path, timed, ending where main would move
tools/release/train.sh status                  # what is live since when, what is in flight, ETAs
tools/release/train.sh hold rel-m219 "why"     # train.sh release rel-m219 lifts it
tools/release/train.sh reship rel-m219 io      # a stopped one again, from its worktree
tools/release/train.sh reship rel-m219 --accept progress "why"  # past a check failing on brickworks.diy too
```

### Which lane

| The branch changed | Lane | What runs | About |
|---|---|---|---|
| only `web/`, `api/`, `docs/`, `docs-site/`, `tests/`, `supabase/`, `.claude/`, `*.md`, and tools the export does not run | **web** (chosen by itself; `--web` to insist) | merge with no import; no probe; `ci_gate` beside the deploy; a preview of the live export with this tree's pages and API (`deploy.sh --dir --no-fit`); the checks named, those its change reaches less those proven since (`lean.py`), and site; promote; the live smoke | 15 min is the aim; 28 measured on a preview at a unit's priority (deploy 4, checks 23, smoke 1), 11-23 |
| anything else (`src/`, scenes, `assets/`, `locale/`, `project.godot`, `export_presets.cfg`, `tools/mcp_tools.json`, `tools/export.sh` and the scripts it runs) | **full** (`--full` to insist) | merge and import, the headless probes its change reaches (`lean.py`), export once, the same checks with frames, promotion and smoke | 35 min is the aim for a change to one part of the app, not yet measured; a core class reaches most probes |

### What a release runs (lean.py, fastship 2026-11-23)

rel-m319's 24 units named 146 of the 150 checks and all 293 headless probes,
and its 8 attempts took 13 hours. A release now runs:

1. **What its own change reaches**, against the build brickworks.diy serves
   (its `/app` names `/b/SHA/`), never since an older base: `flows_for.py`
   for the checks; for the headless probes, each whose own source names a
   changed file, a function the change is inside, an underscored word on a
   changed line, or the class when the change is outside its functions (a
   word more than a tenth of the probes say picks out none). `featuremap
   affected` is no choice here: every probe loads `src/main.gd`, so any
   script reaches all of them (569 for one dialog's script).
2. **Less what was proven since.** A check that passed on a preview built
   from commit P, its scripts at commit A, is carried when neither P..H nor
   A..H reaches it (H the release). Proof is written as it is made, in
   `$RELEASE_OUT/proofs/{checks,probes}/NAME.EPOCH`: by `ship.sh` after its
   battery and alone reruns, `unit_preview.sh` after a unit's checks, a
   train's probes, and the nightly run. A record counts only when P is in
   the release's history and it is at most `LEAN_MAX_AGE` hours old (36).
   So a unit that proved its own checks ships with only those that what
   merged beside it also reaches, and a reship runs the checks that failed
   and those its fix reaches.
3. **The smoke**: site always, frames when an app file changed.

The stage works the list out against main with the branch merged (`--plan`
shows it, with what was carried); the train chooses again once it has
merged, against the build live then (`TAG_lean.out`). A name the lead adds
to `TAG.train/checks` after staging, or names with `--checks`, always runs.

**Every check and every headless probe run once a day** on pre261
(`tools/release/nightly.sh`, a systemd user timer at 18:00 local, the
box's quietest hours by sar: load 44-47 on 24 cores), never per release, and
its passes are proof for the next day's releases. `nightly.sh status`
prints the last summary; `nightly.sh plan` what a run would take on.

**The release's jobs before its units'.** heavy's `BOX_HEAVY_PRIORITY`
puts a release first in the queue; `ship.sh` and the train also run its jobs
at `BOX_HEAVY_NICE=0`: brickworks' slice shares its CPU by nice (it hands
none to the cgroups below it), so a release's thread weighs 1024 to a unit's
110. Other projects are untouched: between slices the owner's ranks decide.
Checks run 6 at a time (`PC_AT_ONCE`), probes 6 (`TRAIN_PROBES_AT_ONCE`), and a
timing check waits at most 180 s for its project to calm
(`SHIP_SOLO_WAIT`). `ci_gate.sh` runs beside the deploy and the checks;
main moves only once it passed.

**No check longer than it must be.** A release takes as long as its
longest check, so the three longest are two checks each, side by side:
`design` and `design_dark`, `a11y` and `a11y_dark` (light and dark),
`site_lang` (English and German) and `site_lang_fr_es`. Each visit they make
is judged alone; on one preview the halves found what the whole did, and
the longest went from 32 to 23 minutes at a unit's priority (fastship,
2026-11-23). What still names most checks is a hub file: `api/_talk.js`
reaches 78, `web/site.css` and `web/follow.js` 73, `api/share.js` 65.

**Nothing waits on what cannot answer.** A train staged `--after` the
release before makes its live database mark only once that one serves (and
no hold stops it): rel-m320's mark, made as it began to wait, held
rel-m319's runs on brickworks.diy behind it while it waited for rel-m319. A
check that failed on the preview and cannot run on brickworks.diy (`NEVER_LIVE`
in ship.sh, or a script that refuses it given the check's options: `lean.py
never-live`) is not sent there: the release holds at once for the lead, who
ships past it with `reship TAG --accept NAME "why"`. The Python suite's
failures the lead judged are named at the stage (`--gate-ok "tests/a.py
..."`, kept in `TAG.train/gate_ok` for its reships, or `SHIP_GATE_OK`):
failures only in those files ship, logged; any other holds.

**Nothing made twice.** A reship whose fix touched only `tools/web` (but
the files the build runs: `deploy_reads.sh`), `tools/release` or `tests/`
reuses the preview. A reship whose fix changed no app file ships on the
export the release made on its attempt before (`TAG_export.sha`), with no
import, gates or export. `deploy.sh` keeps a stamp of the part meshes it
found in storage and a cache of each file's brotli, and runs its three
checks side by side.

**After the promotion**, `live_smoke.sh guard` looks at brickworks.diy,
read-only (the home, a model's page, Talk, the app's start). Failing twice
where the build before passes, it rolls the domain back (`vercel rollback`
to the deployment `live_smoke.sh current` named before the promotion),
writes a `TAG-rolled-back` row for `/admin › Site`, sets `$RELEASE_OUT/HOLD`
(main has the release, live does not: revert or fix, then lift it), and the
release is not live: the train behind it stops.

**A rehearsal** (`TRAIN_REHEARSE=1` at the stage) runs a release's whole
path on its preview, the probes and `ci_gate` beside it, and stops where
main would move: its result says how long from its merge. Main, the domain
and `/admin` are untouched, and its worktree and branch go. It is a release
for heavy (first in the queue), so stage one only between releases.

**Vercel's own build** cannot take the build off the box: the web export
needs Godot, its templates and `assets/generated` (the part meshes and the
catalogue, untracked, 3.7 GB here), and the Godot export, the pck split and
the brotli are most of the deploy's time. What a Vercel build could do (put
the site and the functions together, 42 s) is seconds of it, so a release
stays `deploy --prebuilt`, made here and uploaded (73 s); the web lane
makes no export at all.

`tools/release/live_export.sh app FROM TO` is the rule, file by file. The
export a web lane ships on is the one brickworks.diy serves: ship.sh keeps
each full release's `build/web` as it goes live (`$RELEASE_OUT/exports/TAG`,
named by `$RELEASE_OUT/live_web`), and the web lane reuses it until the
next full release. With none kept (the first time, or after a release
shipped by hand), keep one by hand: `live_export.sh keep TAG SHA DIR`, SHA
the commit DIR was exported from. The web lane is checked again once its
merge is made: an app file that differs from the export's tree (main took
one meanwhile) stops it, to be staged again with `--full`. The same live
database lock, stale check, `--accept` and `/admin › Site` record hold in
both lanes. `--plan` says which lane, which checks and which probes a stage
would run, and stages nothing. A tag for a web lane release may be
`rel-mNNN.N`.

A shared file every page loads names only the checks of the part of it
that changed (`flows_for.py`'s SPLIT, reviewed: `web/theme.js` by block, an
`/admin` section's markup and its own module by section); a line elsewhere
in it, or in its styles, still names every check of every page that loads
it. A check that changes what is live (`NEVER_LIVE` in ship.sh: console,
console3, discovery) never runs on brickworks.diy as a stale check: failing
on the preview, it holds the release.

`reship TAG [--probes "..."] CHECK...` is for a train that stopped after its
ship began, on a check gone stale or a timing probe under load: commit the
fix in `.claude/worktrees/TAG`, then reship. It ships that worktree with the
checks named, on the preview already made when only checks or release tools
changed since (`SHIP_REUSE`), beside the probes that did not pass (or those
`--probes` names), and keeps the train's own record: a release staged
`--after TAG` waits for it to serve. rel-m227 and rel-m228 were shipped by
hand instead, and the hand ship left rel-m227's train saying stopped, which
the release after it then stopped on (2026-10-31).

`--accept CHECK "REASON"` (at `reship`, or at `stage`) ships past a check
that fails on brickworks.diy too, as the same script: its run there after
the preview (below) failed, and its script has not changed since the build
brickworks.diy serves. One that passes there, or did not run there, is
refused: its failure is the release's own. The train's log, its status and
the release's merge message name the check, the reason, and both failure
lines (`<tag>_accepted`). At `reship` the merge's message is written again,
every tree as it was, so the preview is made afresh (about 17 minutes); at
`stage`, where the lead already knows the check fails on brickworks.diy, it
costs nothing. rel-m249's progress failed on its preview and worse on
brickworks.diy (295 ms against 158), on a booklet delay the release did not
touch, and the lead could ship past it only by reshipping with `site` alone,
which recorded nothing (2026-11-02).

A timing check (frames, play, progress, placing, grab) that fails on the
preview is not run once on brickworks.diy but by turns on both, P L L P
(`live_ab.sh`: `AB_ROUNDS` pairs, 2; each run the check as the battery runs
it, from the release's tree, under heavy, solo), and judged by the numbers
it prints (`timing_judge.py`). A measure is a line the check says ok or FAIL
on with a figure in ms, its bar what the line holds it to. Every line the
preview failed, in its battery or by turns, is judged: it holds the release
only where the preview's mean is past live's by more than the noise, the
wider of the two sides' spreads (max - min of their runs) and at least 2% of
the bar; a FAIL line with no figure, only where the preview failed it in
more runs than live; a measure live never printed, always; and the whole
check, when no measure was timed on both sides (runs that could not start
fail alike, and are no load: a worktree with no `node_modules`), unless the
preview passed every run, said "passed N of N by turns" (rel-m301's placing
held so, all four runs passed). Otherwise the
release ships past it, failing there as much or not at all, as `--accept`
does, with no reason needed: `<tag>_accepted`, the train's log and status
say both sides' numbers, and so does a commit on top of the merge, which
main moves to (`Ships past play: no worse here than on brickworks.diy beyond
the noise, by turns`). The merge's own message cannot change after its
preview, as its commit names the build; the commit on top has the merge's
tree, so that build stands for it (`deploy_reads.sh`) and brickworks.diy
serves the one the checks passed. A reship on the same preview judges its
runs together with the earlier rounds' (their logs kept as
`<tag>_ab_<check>_r<k><run>_<check>.log`, listed in `<tag>_ab_<check>.kept`):
two runs a side cannot see a check's own swing, and rel-m290's play flipped
between sizes on them while brickworks.diy alone swung 1956 ms. A new
preview starts over. The lines, in `<tag>_ab_<check>.judge`:

```
ships past: the preview no worse than brickworks.diy beyond the noise (2 runs on the preview, 2 on brickworks.diy)
it opens playing "Open the gates", # ms (bar 3000): here 3229 2635 (mean 2932), there 2617 3054 (mean 2835.5) (in the battery 3324); noise 594; failed 1 of 2, 1 of 2: no worse
```

One run there was luck: at load ~35 brickworks.diy fails play's phone bar 1
run in 3. rel-m287 held twice on play (3324 and 3685 ms against 3000) while
brickworks.diy passed it (1267, 1953), and passed on its third run; the
lead's A/B by hand, P L L P P L, found the preview no slower (2511 against
2809 ms mean). m142's and rel-m249's were the same (2026-11-11). A check
that is not a timing one runs there first: if one holds the release, the
A/B, an hour of solo runs, is not run.

The train waits detached until `rel-m218_lead.out` says `SHIP: deploy:
brickworks.diy serves`, never on rel-m218's process: its live checks after
that touch only the live site. It stops if rel-m218 held, failed or never
began, and gives up at its deadline (`TRAIN_WAIT`, 6 hours). Then
`release_wt.sh` from origin/main, `merge_unit.sh` of the branch's tip
then (in the spec's `tip`; a commit to the branch after it waits for the
next release) as `Merge: <title>` with `MERGE_GATES=ship`, a tree dirty or
mid-merge refused, `check.sh --lists`, then the probes and `ship.sh` side
by side. The probes run four at a time (`TRAIN_PROBES_AT_ONCE`; one failing
beside others runs again alone before it counts, and its exit and its FAIL
lines both count) at the release's priority, in a process group of their
own. `ship.sh` makes its gates, preview and checks meanwhile, and moves main
only once `<tag>.probes` is gone, every probe passed: it says `running
PID: NAMES` until then, or `failed: NAMES`, and a failure stops the ship
before main moves (the checks under way end as they would; none more
begins). One after the other, rel-m226's 35 probes took 50 minutes and its
ship an hour more, while the GPU the probes wait for sat idle through the
ship (2026-10-30). The ship promotes the very preview its checks passed.
A check that fails on the preview, and alone after it, runs on
brickworks.diy as it is, after the preview's battery and as a unit's check
would (`ship.sh`, `SHIP_STALE`: no release's priority at the lock or for a
slot), and `status` says which already fail there: people, stale since
achievements, held rel-m226 two hours on. Every check named used to run
there from the moment the train was staged, beside the preview's battery:
rel-m249's 74 there ran 10 hours of checks at load 43 on 24 cores, four of
its preview's checks held for the load, and its preview's checks waited
3.0 hours for the lock behind them (2026-11-02). Once brickworks.diy serves the
release's sha, it retires the release's worktree and each unit's whose HEAD
is on main and which holds no file git does not track (`retire_wt.sh`). Its
spec is a file each in `bench/results/release-out/<tag>.train/` (branch,
after, checks, probes, units, title, deadline), each read only when its step
comes: a unit merged into the branch meanwhile brings its checks by an edit
of `checks`. Staging adds to the checks named every one `flows_for.py` (the
branch's, on its own tree) finds for what the branch changed since it left
main, or since the merge of it the release before ships, and says which it
added: rel-m237's hand-picked list missed model_view (2026-11-02).

Named no `--probes`, it runs every probe `tools/suite/headless.txt` lists
in the branch's own tree, as `check.sh` reads it; windowed.txt's are the
suite's, and out.txt's skip themselves. Staging says how many (`probes: all
209 headless (103 windowed left to the suite)`), `<tag>.train/probes` holds
them and `probes.why` why, and the log and `status` say it again.
`--probes "a b"` names exactly those; `--probes none --why "…"` runs none
and says why, and `--probes ""` is refused. Staged with `--probes ""`
every time, no release ran a probe from v0.15.0 to rel-m256, and eight went
red on main unseen until desktop016's whole-suite run held desktop 0.16.0
(2026-11-04). All 209 took 19m30s four at a time on this box at load 4 to
8 (22m12s with each failure again alone), on rel-m256's merge, and failed
the six headless ones of the eight. That is well under the preview's
battery, about two hours from the ship's start (rel-m256's, 14:56Z to
17:09Z), so the whole list costs the release no time. Picked by what
`featuremap affected` reaches it would have caught three of the six: its
GDScript graph follows `res://` paths alone, and a probe that uses a class
by its `class_name` is never reached (a change to
`src/assembly/instructions.gd` reached none of the 32 probes that use
`Instructions`). Since claude-core e6df180 it follows class names and
autoloads, and the verify config names `src/dev/*_probe.gd` as tests, so
that change lists all eight. Trains still run the whole list: it costs
nothing beside the battery.

Its log is `<tag>_train.out`, its result `<tag>.train/result`,
and a train that stops before the ship writes `<tag>.gave_up` as
`ship_after.sh` does, so the release staged behind it stops too. It runs
from a copy of itself: a release fast-forwards the main checkout, this
script with it, and bash reads a script as it goes. `kill -- -PID` (status
names the pid) stops a train and what it runs. Restaging a tag that
stopped clears its worktree and branch when they hold nothing but its merge,
and refuses when they hold a fix of their own. The lead wrote a chain like
this by hand for each release from rel-m214 to m218, a promote job beside
it, and another to retire worktrees afterwards; a held merge left one
release's tree half-merged (rel-m214), and a retire after a held preview
took rel-m196's worktree (2026-10-28).

`status` is for the owner as much as the lead. First what brickworks.diy
serves, which release that is and since when (the end of its deploy), and
how long a ship takes from begun to served (the median of the last five:
when `<tag>_lead.out` was made to when `<tag>_prod.log` was last written).
Then each release in flight, a train or a ship begun by hand: its step,
its checks passed of all, and when it should serve. A ship under way serves
about a median ship after it began; one not yet shipping, no sooner than
the release before it serves and a ship after that. The ETAs need a file
system that keeps when a file was made (`stat %W`); without one they are
left out.

And before a unit says ready, from its own worktree:

```sh
RELEASE_OUT=<its scratch>/out tools/release/unit_preview.sh <worktree> [check…]
```

What each one guards against, all learned the hard way on 2026-10-13:

- `merge_unit.sh` merges with `--no-commit` as the user. It takes either
  side of the generated files (`tools/mcp_tools.json`, the feature map) and
  writes them again, and it unions doc conflicts (`resolve_docs.py`). A
  unit begun before a version was cut has its changelog entries put under
  `[Unreleased]` (`changelog_merge.py`), where git would merge them into the
  released section. After
  the merge it re-imports, so new `class_name`s resolve, then runs the
  parse gate, then rewrites the tool list when `src/net` or `src/ai`
  changed.
- A new probe goes on a line of its own in `tools/suite/headless.txt`,
  `windowed.txt` or `out.txt` (with why after its `#`), never in
  `tools/check.sh`. The suite's lists were arrays there, every unit appended
  to the same last line, and four merges on 2026-10-22 were that conflict
  settled by hand. The files merge a probe at a time
  (`tools/merge_lists.py`, `merge=lists` in `.gitattributes`): both sides'
  new lines are kept, a line one side edits is kept once, the side merged in
  winning if both did, and one taken out stays out. A plain union kept an
  edited line twice (steps_kept, 62d9de65 and fe6808ae). The driver is in the
  main checkout's `.git/config`, and `merge_unit.sh` passes it on its merge;
  a merge with neither stops on a conflict. `merge_unit.sh` then runs
  `tools/check.sh --lists`, which fails a merge that leaves a probe in no
  list, or one listed twice, or out and run both.
  `tools/check.sh --dry-run` prints every command the suite would run.
- `parse_gate.sh` parses every GDScript file the merge changed. Two units
  each added a `"dome"` key to one dictionary, git merged both without a
  conflict, and Godot could not parse `assistant.gd`. The tool-list probe
  hung on it rather than failing.
- Probes may run at once in one checkout (`tools/probe.sh`, so
  `run_probes.sh` too): none writes `.godot`. A class list older than the
  scripts is what fails them, every script naming a class it lacks: a
  `.godot` copied from another worktree, or kept across a merge, checkout
  or bisect. surface108's three probes failed with 9,377 errors,
  `"BestOfTwo" not declared`, put down to running at once; one probe alone
  on that list fails the same (2026-10-22). `probe.sh` imports first when
  the list is behind (`tools/fresh_import.sh`, one import a checkout under
  `.godot/import.lock`) and refuses (exit 2) when an import cannot fix it;
  the parse gate imports whenever it is behind, not only when it is missing.
- `preview_checks.sh` runs the named browser checks, `PC_AT_ONCE` at a
  time (3). Timing
  checks (idle, arrival, progress, cursor) run alone: beside a heavy flow,
  idle drew 4 frames for 7 moves, against 16 alone. An unknown name fails,
  where it used to run bare node and "pass". The script runs from a copy
  of itself, so editing it mid-battery cannot break the run. `frames`
  (`cad_frames.mjs --gate`, alone too) holds what a frame costs the app on
  75969-1: each press of the timeline's Next and an orbit's frames under
  200 ms of the app's own work, select all under 400. No check held that:
  the grab's drag
  handles took a step from 75 ms to 6.7 s, and m61 shipped with it
  (docs/CADTASK.md, section 6).
- The merge scripts hold a lock (`.git/worktrees/<name>/merging`) until their
  last gate is done, and `ship.sh` refuses a worktree that has one. m26 was
  shipped as soon as its merge commit appeared, while the tool-list check
  was still running (2026-10-14).
- `ship.sh` fails closed: every check named must report `exit=0`, and a
  battery that wrote no results holds the release. It used to look only for
  a failed line, so when the checks could not even start (a relative
  worktree path) m31 went on to deploy production unchecked (2026-10-15).
- `RELEASE_OUT=<folder> ship_after.sh <prev-tag> <worktree> <tag> <check…>`
  queues a release behind the one before it: it waits for that release's
  result (`<prev>.done`), ships only if it shipped, and writes its own. `-` for none before. A
  waiter written by hand found the release before by its command line, its
  own grep hid it, and m43's ship went at once (2026-10-17).
- A result is only the latest attempt's: a waiter that gives up writes
  `<tag>.gave_up`, never `<tag>.done`, and a tag queued or begun clears
  both (its log before is kept as `<tag>_ship.prev.log`). m177's first
  waiter gave up when m175 held and wrote `m177.done` = 1; m177 shipped
  later, and m178's waiter read that 1 while m177's checks ran, and held
  (2026-10-26).
- `ship.sh` writes `<tag>.done` itself as it ends, begun by hand or queued,
  and no waiter reads a log for a result. m181's promote, begun by hand,
  cleared `m181.done`; m182's waiter fell back to the held battery's
  `exit=1` ending `m181_ship.log`, and held while the promote ran
  (2026-10-26).
- Every release runs `site` and `frames` whether they are named or not:
  `frames` holds a big model's step, orbit and select all to the app's own
  work per frame, after a feature that ran twice a second left a step at
  6 s while every named check passed.
- To hold releases, write a reason to `$RELEASE_OUT/HOLD` (all) or
  `$RELEASE_OUT/<tag>.hold` (one): a queued release waits, and one already
  shipping stops before main moves. Remove the file to let them go. Killing
  a queued waiter does not stop a ship it already started.
- `ship.sh` runs each check that failed in its battery once more, alone,
  before it holds, every one whatever else failed, and one that wrote no
  line for the first time. Timing checks (frames, play, progress, placing,
  grab) get no second go: alone they would pass what the load showed.
  rel-m249's progress, a timing check, kept keys, library, model_page and
  together from theirs, and the lead reshipped them by hand (2026-11-02).
  Its last line names what still fails: `SHIP: held, failed on the
  preview: X Y (failing on brickworks.diy too: X)`, or for a timing check
  judged worse by turns with brickworks.diy, `SHIP: held, failed on the
  preview: play (by turns with brickworks.diy: <tag>_ab_NAME.judge)`.
- `SHIP_REUSE=1 ship.sh <worktree> <tag> <check…>` reuses the preview that
  tag made, only if it was made from the same commit (`<tag>_preview.sha`),
  and runs the named checks on it again; each must still pass. A timing
  check failed at load 75-95 and held m33 twice on 2026-10-16; the only way
  on was a fresh deploy and every check again. Rerun the one that failed,
  alone, when the load allows, then promote with it.
- `timing_ab.sh <base-wt> <new-wt> <rounds> <out> -- <flow…>` tells a
  timing failure's cause: the change, or the load. It serves both builds'
  `build/web` and runs the flow on each in turn, so the load weighs on both
  alike. m142's phone drag failed its preview twice; the live m141 failed
  the same bar 2 runs in 3 beside it (2026-10-22). A train does the same
  for a deployment itself: `live_ab.sh <worktree> <tag> <check> <preview>`
  runs the check on the preview and on brickworks.diy by turns (`AB_LIVE`
  names another), and `timing_judge.py --battery LOG --run P|L EXIT LOG...`
  judges any runs' logs.
- `live_smoke.sh` looks at the live site the moment a release is live, and
  puts it back when the release broke it. `current [DOMAIN]` names the
  deployment the domain points at (asked before the promotion: where to go
  back to); `check ORIGIN` only reads (GETs, then a signed-out browser that
  sends nothing else: home, a model page, Talk, `/app` started), about a
  minute on a calm box; `guard DOMAIN PREVIOUS_URL TAG` checks twice, checks
  the build before on its own URL, and only when that one passes rolls the
  domain back (`vercel rollback` for brickworks.diy, `vercel alias set` for
  any other alias), confirms the domain serves it, checks it there and writes
  `TAG-rolled-back` for `/admin#site`. Exit 0 passed, 3 rolled back, 1
  failed, 2 no verdict; the line to copy begins `live_smoke: rolled back`.
  The next release's `vercel promote` ends the rolled-back state.
- `ship.sh` runs the merge gates itself, once for every unit merged, under
  the release's priority: the parse gate on every GDScript file changed since
  main, and the tool list against the app. Run per merge without priority,
  each gate waited 30 to 70 minutes for a slot at load 50 (2026-10-16).
  `MERGE_GATES=ship` has `merge_unit.sh` leave them to it; without it the
  merge still runs them, as before.
- `ci_gate.sh` is the first of those gates: what GitHub's `check.yml` ran
  on every push. One version in `VERSION`, `project.godot` and
  `CHANGELOG.md` (`tools/release.py version`); the Python suite as
  `tools/check.sh` runs it (pytest, else `tools/minitest.py`); and
  `shellcheck -S warning tools/*.sh tools/release/*.sh` (these scripts
  too, which CI never linted), where shellcheck is installed (where
  it is not, the gate says so and goes on: koalaman's v0.10.0 static
  binary goes in `~/.local/bin`). CI was red from 2026-10-13 to 10-26 and
  nobody read it: a quoting warning in `describe_snippets.sh`, then a test
  that needed `colors.json`, which CI never had. A check that only reports
  is not read, so this one holds the release before main moves, and the
  workflow runs by hand only, since a private repository pays for each
  minute. It takes 80 to 120 s in its slot at load 40, nearly all of it
  the suite.
- `release_links.sh` holds a release before any of them, in about 30 s:
  every release page and file `web/releases.json` links to must answer a
  visitor, each file at its size (`tests/test_release_links.py`). A
  manifest naming a repository or a file that is not there yet cannot
  ship, and neither can one whose links a private source repository has
  broken (the releases' move to Xaxis/brickworks-releases, 2026-10-27).
- `ship.sh` hands over to the worktree's own `tools/release/ship.sh`, so a
  release runs its own scripts and knows its own checks. m87 was started
  from main's copy and held on "no such check" for the three it added
  (2026-10-19). `RELEASE_HERE` pins a copy on purpose.
- A timing check (the SOLO ones) runs as `heavy --solo`: it waits until none
  of the project's other jobs holds a slot, bar long ones held over
  `BOX_HEAVY_SOLO_WAIT` (600 s, a bench run), and none queued after the
  first of them starts until the last ends; after 600 s it runs anyway.
  `<tag>_calm.log` says the load each began at, after how long, and beside
  what. m87's play and m98's grab held at load 20-42 and passed alone at
  3-10 (2026-10-19). Waiting for the load to fall instead held m214 ten
  minutes while four agents' deploys and flows kept it at 13-42 (2026-10-30).
- `ship.sh` sends live the very preview its checks passed (`tools/deploy.sh
  --promote=URL`): the preview is a production build no domain points at
  yet, so that takes seconds, and it ends once brickworks.diy names the
  build (`SHIP: deploy: brickworks.diy serves <sha>`). `deploy.sh --promote`
  takes only a build of its checkout's own commit, by the preview's
  `version.json`, and ship.sh never a unit's preview (`--unit`, without
  production's secrets). Should the promotion not go, it deploys production
  afresh with `deploy.sh --prod`, as releases did before.
- `ship.sh` takes `BOX_HEAVY_PRIORITY` for the release only, and so do the
  train's own probes, which run beside it: heavy holds a project's ordinary
  jobs back while its priority job runs, so ordinary probes would wait out
  the ship. A unit's probe batches must not take it: it holds every other
  agent's work. After promoting, it waits 90 s for the CDN before checking
  the live site.

- `unit_preview.sh <worktree> [check…]` is how a unit proves its site
  change before it says ready. It deploys the worktree unpromoted
  (`tools/deploy.sh` without `--prod`, which Vercel makes as
  `--prod --skip-domain`: no domain points at it), then runs the checks
  `flows_for.py` names for what the unit changed since the commit it was
  made from (the later of its merge base with main and with a `rel-*`
  branch), or the checks named, and `site` always. One `pass` or `FAIL`
  line a check, and it exits 0 only when every one reported and passed.
  Its files are `$RELEASE_OUT/<branch>_unit_*`; `UNIT_REUSE=1` runs the
  checks again on the preview it last made from the same commit. It runs
  no merge gate, takes no release priority and never touches main. Its
  deploy and checks are ship.sh's own (`preview_lib.sh`). Each deploy
  writes into a log of its run's own: a preview into
  `<tag>_preview.<run>.log`, which `<tag>_preview.log` links to while it
  runs and becomes once it ends, the URL read from that log alone; a ship's
  promotion and production deploy into `<tag>_prod.<run>.log`, added to
  `<tag>_prod.log` as each ends. A run stopped by its group or its pid ends
  its deploy first, heavy's queued job too (`run_owned`).
  GNU `timeout` makes a process group of its own, so `kill -- -PGID` missed
  the deploy under it: hubprogram's went on after its run was killed and
  wrote a second `deploy done` into the next run's log, which took both URLs
  and ran its checks on neither (2026-11-18). Four release
  previews held on 2026-10-22, about an hour each, and every time on a
  check: digest, moderation, share_flow, builds, share_probe and challenges
  read markup a unit had changed, and a smooth scroll was read mid-way.
  Its deploy is `tools/deploy.sh --unit`: as a production deployment
  (m112's queue) it would hold every production secret while it runs code
  nobody has reviewed, so `OC_SIGNING_SECRET` (orangecheck asked,
  2026-10-23) and `ANTHROPIC_API_KEY` (read by nothing) are set to nothing
  for it alone (`vercel deploy --env NAME=`). A release's preview and
  production keep both. The rest stay: every API needs
  `SUPABASE_SECRET_KEY`, share_probe runs the sweep with `CRON_SECRET`,
  and the preview's own email sign-in sends with `RESEND_API_KEY`.
- `flows_for.py` also names a changed flow's own checks, and the checks of
  every flow that imports a changed module in `tools/web` (`session.mjs`
  is nearly all of them).
- The checks that write the live database, every flow that makes a
  throwaway account and deletes it after, run `LIVE_DB_SLOTS` (3) at a
  time across the machine: `preview_checks.sh` holds one of the files
  `.git/live-db.slot.N` in the main checkout, under a shared hold of
  `.git/live-db.lock`, for each one's run, whichever battery it is in, and
  `.git/live-db.log` says who took it, after how long, which slot, and
  when they left, in the order they took it (written before a run gives up
  its place in line). Two runs at once on 2026-10-22 got 429s in profile, and
  another run's model took discovery's pick; one at a time, rel-m254's 53
  held the lock for 3.1 hours and four units gave up behind it. Twelve of
  the longest held it 12 minutes three at a time on rel-m254's preview,
  and 44 one at a time, every one passing both ways and no sign-in
  answering 429 (2026-11-04). Each flow
  makes accounts of its own and judges its own models by id; sign-ins are
  by password, from a bucket of 30 at once and one every 2 s, which a
  battery draws on about 180 times (`session.mjs`). The checks that read
  what every account changes hold `.git/live-db.lock` alone (`ALONE_DB` in
  `preview_checks.sh`, each with its reason): discovery (the week's pick),
  first_steps (the top designers), challenges (the one test challenge),
  and beta where the beta is open (one test pool). In a battery a slot
  takes a live check first while fewer of the battery's than
  `LIVE_DB_SLOTS` run one, one held alone only when none runs, and the next
  check as soon as it is free. Between batteries a live check waits for a
  slot; `LIVE_WAIT` (an hour) bounds that, then the check fails. A
  release's checks go first: waiting, its battery leaves a ticket in
  `.git/live-db.release/`, and no other battery takes a slot while one is
  there. Within each line, a release's and the rest, only the first living
  ticket takes a slot, so one waiting to hold it alone is not passed by
  those that came after. flock serves no one in order, and a unit's A/B,
  taking the lock run after run, held rel-m232's arrival 24 minutes
  (2026-10-31). A train leaves a mark there, a file named for its pid
  holding its start time, from its start until its battery on the
  preview, with the checks run again alone, is done (`ship.sh` takes it
  away, `SHIP_LIVE_MARK`), so
  no unit begins a live check meanwhile: a run already in the lock cannot
  be taken back, and one begun while rel-m233 merged held its oauth 33
  minutes. Then units take it in their turn again, and the release's own
  checks on brickworks.diy wait theirs among them. Left for as long as the
  train ran, the file shut units out of the live database for all but an
  hour of the sixteen from rel-m247's staging to rel-m250's battery: 13
  unit checks gave up after an hour each, and the 15 that ran waited 7.5
  hours between them (2026-11-02).
- The checks that take no lock run side by side, in one battery and across
  two, signed in to the flows' shared test account (`tools/web/session.mjs`).
  None may change what that account keeps and then read it back: rel-m249's
  keys ran on its preview and on brickworks.diy a minute apart, each put
  the account's keys back while the other's were on it, and both failed
  with nothing wrong in the app. A flow that must, signs in to a throwaway
  account of its own and deletes it after, as `keys_flow.mjs` does since
  keysync (which makes it take the lock). Swept on 2026-11-02: of the rest,
  only `dialogs_flow.mjs` writes there, and only things of its own (a link
  it publishes and takes back, a session it starts and ends, its own page
  signed out), which no other run can undo.
- A unit's own run on the live site, an A/B or a diagnostic outside a
  battery, takes the lock only through `tools/release/live_db.sh [--alone]
  WHO CMD...`, which takes a slot by the same rule (all of it with
  `--alone`, for a run of an `ALONE_DB` check; `live_db_lib.sh`, which
  `preview_checks.sh` sources) and writes `.git/live-db.log` as WHO. hover's
  scratch script took it with a bare flock, gave way to no release, and
  held rel-m233's checks twice more, 33 and 38 minutes.

`tools/release/clean_worktrees.sh [--dry-run]` removes finished worktrees
and nothing else: never a locked one (the harness locks an agent's while it
runs), one with a process inside, one with uncommitted tracked edits, or one
whose branch is not on main. "Its commit is on main" alone also describes a
running agent that has not committed yet, and two agents lost their work to
a cleanup that checked only that (2026-10-16).

`tools/release/archive_out.sh [--dry]` moves release-out's old output: the
releases older than the newest 8 (`RELEASE_KEEP`) and any other entry
untouched for 3 days (`RELEASE_IDLE_DAYS`) go to
`~/brickworks-archive/release-out` (`RELEASE_ARCHIVE`), on the root disk, and
`release-out/archive` links there. In the archive, screenshots (png, webp, ppm)
go after 14 days (`RELEASE_SHOT_DAYS`); logs, JSON and the rest stay, since
those are what the docs cite. The archive had reached 113 GB, 110 GB of it
preview PNGs, with / at 4% free (2026-11-24). A running train's output, a hold and the
archive stay. train.sh runs it once a release is live: release-out had grown to
61 GB in 25,000 entries with /mnt/Projects at 93% (2026-11-11).

A mesh sub-build ships on the staging worktree's own copy of the
catalogue (`ln -sfn <copy> <worktree>/assets/generated`). Merge it into the
shared catalogue only after the release is live, with `tools/merge_subbuild.py`
and a backup first. Agents mid-run then never see the catalogue change
under them, and it never runs ahead of the code that reads it.
