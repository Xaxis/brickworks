# Handoff

Written 2026-10-09 for a fresh session. Everything below is committed,
pushed and live; nothing is half-finished.

## The goal

Designs as good as a set LEGO would actually release, with no
architectural ceiling on size. The owner's words: a real set may be four
thousand pieces or more, so do not design to a target number. And, from
the same day: keep planning ahead, refine the vision, and update the
website when something is worth showing.

`docs/ROADMAP.md` is the plan and is the **first thing to read**: the
product end to end, the gap as one number, what is solved, and the levers
ranked by evidence.

## Where it stands

- Pushed, live at **brickworks.diy**. Confirm with
  `curl -sI "https://brickworks.diy/app?v=$(date +%s)" | grep -i location`
  against `git log --oneline -3`; a docs-only commit does not earn a
  deploy, and the stamp only says `-dirty` for a change to something that
  ships.
- Full suite: `tools/check.sh` (it queues itself on the machine's `heavy`
  pool). Above a load of about 12 the on-screen checks starve and report
  TIMED OUT, which proves nothing either way: rerun that one alone under
  `heavy` with `xvfb-run` (see `tools/check.sh` for the command).
- Best design by the numbers: castle run 19, **1,329 parts, 113 shapes,
  16 colours**, 37% its main colour — on the landing page, shipped as
  `models/castle.ldr`. A real set that size has 180 shapes and 23 colours.
- Not exercised: the proxy's conversation caching for signed-in accounts
  (`api/claude.js`). Deployed; proving it needs an account.

## What the work found

- **The levers that moved runs**, each measured: detailing per assembly;
  sending a pass back once when the assembly or the whole model is on
  the tail of real sets (thin shapes, few one-off pieces, one colour, big
  pieces); telling passes the parts real sets of the kind use. The run
  table and how each was found is in `docs/ROADMAP.md`.
- **Pieces too big, and invisible in every picture.** A real set is 10%
  pieces as big as a 2 x 4 brick at every size; every castle was 39-56%,
  its walls in 2 x 10s, because `fill` laid the longest brick that fit.
  `fill` now lays courses in short bricks on a running bond (run 21: 17%).
  And the renderer drew no seam between two same-coloured bricks, so the
  difference could not be seen: it draws them now, desktop and web.
- **The 4 x 4 corner-round brick was recommended on a stale number.**
  Every castle built ~200 of it for round towers; real castle sets since
  2010 use at most eight. The prompt and technique now say round is a
  choice.
- **Real sets as geometry**: LDraw's model repository serves one `.mpd`
  per set (the zip is gone). `tools/layout.py` measures how a model
  stands; real castles' towers stand ~3x their walls, ours ~1.5x.
- **The fire station has a plateau**: 62, 67 and 70 shapes over three
  runs, whatever the passes. Asking for assemblies of about a hundred
  parts (run 22) gave five passes instead of four and a richer first
  structure, and the same end. Its windows read as blanks.

## What is next

1. What a building's openings are: a window technique (frame, glass,
   sill, lintel) and a door one, measured on the station brief.
2. What a wall's short bricks are: masonry bricks and a second grey in
   some of them, as real castles do — a `fill` option is the likely
   shape, because a detail pass cannot re-lay a wall (`edit_model` takes
   no patterns).
3. Proportion: towers over walls, measured against more real castles.

## Gotchas that will cost you hours

- **Commits are authored as the user, always.** `git -c user.name=Xaxis
  -c user.email=william.neeley@gmail.com commit -F <msgfile>`. Vercel
  seat-checks the author and a wrong one fails the deploy *silently*. No
  assistant attribution of any kind, ever.
- **The machine is shared and coordinated.** One GPU lease for every
  project (`~/.claude/claude-core/bin/gpu`), a pool of CPU slots for
  heavy jobs (`~/.claude/claude-core/bin/heavy`). The `godot` on the path
  renders in software unless `GODOT_GPU=1`, and then it queues for the
  lease. The suite queues itself; run software renders under `heavy`; take the GPU
  only for seconds (a screenshot), never for a design run. Browsers stay
  on SwiftShader (`tools/web/browser.mjs`).
- **No display.** `tools/check.sh` and `tools/design.py` give themselves
  Xvfb. Anything new that drives the app needs the same, or it hangs.
- **Never kill by `ps | grep`.** `tools/running.py <pattern>` finds a run
  and `--stop` ends it. Stopping `design.py` can orphan its Godot child;
  check with `ps` for your own `--out` path afterwards. Do not touch
  anything under `/mnt/Projects/Reelwright`.
- **Read a design run's output after it ends.** `--out` is rewritten on
  every build. A run prints its progress per assembly and, last, what it
  spent.
- **A Godot script error does not end a probe; it sits there idle.** A
  probe that hangs at ~1% CPU has probably hit one. `tools/check.sh`
  bounds each probe and reads the output for `SCRIPT ERROR`.
- **No GDScript string is greppable in a `.pck`.** To prove code shipped,
  use the stamp: `/` 308s to `/b/<sha>/`. Packed JSON *is* greppable.
- **Rebrickable may be downloaded at most once a day**, enforced in
  `tools/fetch_data.sh`. `themes` was added to its tables this session.
- **Before deploying after any geometry change**, run
  `python3 tools/storage_parts.py --check` and confirm `to upload: 0`.

## Where things are

| | |
|---|---|
| The plan | `docs/ROADMAP.md` |
| How to prove anything works | `.claude/skills/verify/` (start at `SKILL.md`) |
| The whole check suite | `tools/check.sh` (6-20 min, queues on `heavy`) |
| The design loop and its prompt | `src/ai/assistant.gd` |
| Detailing per assembly | `Assistant._detail_next`, `src/dev/detail_probe.gd` |
| Count a model against real sets | `tools/texture.py model.ldr --brief "..."` |
| How a model stands, against real sets | `tools/layout.py model.ldr` |
| Real-set data, joined to LDraw | `tools/rebrickable.py` |
| Catalogue build | `tools/refresh_catalogue.py` |
| Drive a real design | `tools/design.py "a brief" --out m.ldr` |
| Deploy | `tools/deploy.sh --prod` |

## Cleanup state

Verified at handoff: no uncommitted changes, no processes left running by
this session, live build matches the last code commit. Scratch work lived
in the session scratchpad under `/tmp`, which is disposable.
