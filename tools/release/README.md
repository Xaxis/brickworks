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
  result (`<prev>.done`, or the `exit=` line ending `<prev>_ship.log`),
  ships only if it shipped, and writes its own. `-` for none before. A
  waiter written by hand found the release before by its command line, its
  own grep hid it, and m43's ship went at once (2026-10-17).
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
- `ship.sh` hands over to the worktree's own `tools/release/ship.sh`, so a
  release runs its own scripts and knows its own checks. m87 was started
  from main's copy and held on "no such check" for the three it added
  (2026-10-19). `RELEASE_HERE` pins a copy on purpose.
- A timing check (the SOLO ones) waits for the one-minute load to fall under
  `CALM_LOAD` (12), from one `CALM_WAIT` budget (900 s) for the battery, then
  runs anyway; `<tag>_calm.log` says the load each began at. m87's play and
  m98's grab held at load 20-42 and passed alone at 3-10 (2026-10-19).
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
