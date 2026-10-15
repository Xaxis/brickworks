# Releasing Brickworks

A unit an agent reports ready goes live within the hour, through these
scripts. Logs go to `$RELEASE_OUT` (default `$TMPDIR/brickworks-release`).

```sh
tools/release/release_wt.sh merge20 <main sha>        # a staging worktree that can deploy
tools/release/merge_unit.sh <worktree> <sha> "Merge …" # each ready unit, as the user
#   on CONFLICTS: resolve, git add, then
tools/release/merge_finish.sh <worktree> "Merge …"
# the unit's affected probes (featuremap affected), then:
tools/release/ship.sh <worktree> <tag> site io …       # preview, its checks, then production
```

What each one guards against, all learned the hard way on 2026-10-13:

- `merge_unit.sh` merges with `--no-commit` as the user. It takes either
  side of the generated files (`tools/mcp_tools.json`, the feature map) and
  writes them again, and it unions doc conflicts (`resolve_docs.py`). After
  the merge it re-imports, so new `class_name`s resolve, then runs the
  parse gate, then rewrites the tool list when `src/net` or `src/ai`
  changed.
- `parse_gate.sh` parses every GDScript file the merge changed. Two units
  each added a `"dome"` key to one dictionary, git merged both without a
  conflict, and Godot could not parse `assistant.gd`. The tool-list probe
  hung on it rather than failing.
- `preview_checks.sh` runs the named browser checks, two at a time. Timing
  checks (idle, arrival, progress, cursor) run alone: beside a heavy flow,
  idle drew 4 frames for 7 moves, against 16 alone. An unknown name fails,
  where it used to run bare node and "pass". The script runs from a copy
  of itself, so editing it mid-battery cannot break the run.
- The merge scripts hold a lock (`.git/worktrees/<name>/merging`) until their
  last gate is done, and `ship.sh` refuses a worktree that has one. m26 was
  shipped as soon as its merge commit appeared, while the tool-list check
  was still running (2026-10-14).
- `ship.sh` takes `BOX_HEAVY_PRIORITY` for the release only. Probe batches
  must not take it: it holds every other agent's work. After promoting, it
  waits 90 s for the CDN before checking the live site.

A mesh sub-build ships on the staging worktree's own copy of the
catalogue (`ln -sfn <copy> <worktree>/assets/generated`). Merge it into the
shared catalogue only after the release is live, with `tools/merge_subbuild.py`
and a backup first. Agents mid-run then never see the catalogue change
under them, and it never runs ahead of the code that reads it.
