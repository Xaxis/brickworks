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
  --checks "io gallery" --probes "grab_probe" --units "unit1 unit2" --title "…"
tools/release/train.sh status                  # what is live since when, what is in flight, ETAs
tools/release/train.sh hold rel-m219 "why"     # train.sh release rel-m219 lifts it
```

The train waits detached until `rel-m218_lead.out` says `SHIP: deploy:
brickworks.diy serves`, never on rel-m218's process: its live checks after
that touch only the live site. It stops if rel-m218 held, failed or never
began, and gives up at its deadline (`TRAIN_WAIT`, 6 hours). Then
`release_wt.sh` from origin/main, `merge_unit.sh` of the branch as
`Merge: <title>` with `MERGE_GATES=ship`, a tree dirty or mid-merge
refused, `check.sh --lists`, each probe (its exit and its FAIL lines both
count), and `ship.sh` with the checks, which promotes the very preview its
checks passed as soon as the battery ends. Once brickworks.diy serves the
release's sha, it retires the release's worktree and each unit's whose HEAD
is on main and which holds no file git does not track (`retire_wt.sh`). Its
spec is a file each in `bench/results/release-out/<tag>.train/` (branch,
after, checks, probes, units, title, deadline), each read only when its step
comes: a unit merged into the branch meanwhile brings its checks by an edit
of `checks`. Its log is `<tag>_train.out`, its result `<tag>.train/result`,
and a train that stops before the ship writes `<tag>.gave_up` as
`ship_after.sh` does, so the release staged behind it stops too. It runs
from a copy of itself: a release fast-forwards the main checkout, this
script with it, and bash reads a script as it goes. `kill -- -PID` (status
names the pid) stops a train and what it runs. The lead wrote a chain like
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
  settled by hand. The files merge as a union (`.gitattributes`), so git
  keeps both sides' lines. `merge_unit.sh` then runs `tools/check.sh
  --lists`, which fails a merge that leaves a probe in no list, or one a
  union brought back (a name twice, or out and run both).
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
- `preview_checks.sh` runs the named browser checks, two at a time. Timing
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
  the same bar 2 runs in 3 beside it (2026-10-22).
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
- `ship.sh` takes `BOX_HEAVY_PRIORITY` for the release only. Probe batches
  must not take it: it holds every other agent's work. After promoting, it
  waits 90 s for the CDN before checking the live site.

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
  deploy and checks are ship.sh's own (`preview_lib.sh`). Four release
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
  throwaway account and deletes it after, run one at a time across the
  machine: `preview_checks.sh` holds `.git/live-db.lock` in the main
  checkout for each one's run, whichever battery it is in, and
  `.git/live-db.log` says who took it, after how long, and when they left.
  Two runs at once on 2026-10-22 got 429s in profile, and another run's
  model took discovery's pick. In a battery a slot takes a live check only
  when the other slot is not running one, and the next check as soon as it
  is free, not when its pair's longer half ends. On the times each check
  took, m146's paired checks take 31 minutes so (37 in its pairs), m145's
  2.6 (4.2), and m144's, more of them live, 44 (38): the live checks one
  after another are the floor. Between batteries a live check waits for
  the one another battery is running; `LIVE_WAIT` (an hour) bounds that,
  then the check fails.

`tools/release/clean_worktrees.sh [--dry-run]` removes finished worktrees
and nothing else: never a locked one (the harness locks an agent's while it
runs), one with a process inside, one with uncommitted tracked edits, or one
whose branch is not on main. "Its commit is on main" alone also describes a
running agent that has not committed yet, and two agents lost their work to
a cleanup that checked only that (2026-10-16).

A mesh sub-build ships on the staging worktree's own copy of the
catalogue (`ln -sfn <copy> <worktree>/assets/generated`). Merge it into the
shared catalogue only after the release is live, with `tools/merge_subbuild.py`
and a backup first. Agents mid-run then never see the catalogue change
under them, and it never runs ahead of the code that reads it.
