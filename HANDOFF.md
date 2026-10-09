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

- Clean tree, pushed, live at **brickworks.diy**. Confirm with
  `curl -sI "https://brickworks.diy/app?v=$(date +%s)" | grep -i location`
  against `git log --oneline -3`; a docs-only commit does not earn a
  deploy, and the stamp only says `-dirty` for a change to something that
  ships.
- Full suite green: `tools/check.sh` (it queues itself on the machine's
  `heavy` pool).
- Best design: castle run 19, **1,329 parts, 113 shapes, 16 colours**, 37%
  its main colour, in ten named assemblies — on the landing page, shipped
  as `models/castle.ldr`. A real set that size has 180 shapes and is 28%
  its main colour. 30 shapes was the best before this work.
- Not exercised: the proxy's conversation caching for signed-in accounts
  (`api/claude.js`). Deployed; proving it needs an account.

## What the work found

- **The gap is one-off pieces.** A real set of 1,100 parts has some 177
  shapes and 85 of them are used once or twice. Run 14 had 21. Its shapes
  used many times were close to a real set's. Each pass is now told the
  model's count against the real one — **run 15 was measuring that at
  handoff** (`tools/texture.py` prints the count).
- **The levers that worked, each measured:** detailing per assembly
  (1.2-1.5x on its own); sending a thin pass back once (2.3x, 1.7x, and on
  a fire station 1.6x); telling passes the parts most real sets of the
  kind use (37 of the top 40 against 24; 54 of the top 100).
- **The levers that did not, also measured:** telling siblings what the
  others got (passes went to fixing instead); a filter for kinds that do
  not suit the subject (not in the data).
- **Angled structure is the weak joint.** Two space cruisers failed on
  pods on angled pylons. A design that holds but for a few floating
  bricks now keeps what holds, the check sweeps sideways for where a
  turned section meets, and a failed design is written to
  `user://failed_design.json`.
- **The booklet builds by the design's named assemblies**, carried in the
  file as `.mpd` sub-models, each part framed on its own.
- **Cost**: the conversation is cached; a 40-minute castle is ~$6-8.

## What is next

1. Read run 15's result (`tools/texture.py` on the saved `.ldr` once the
   run has ended): did the one-off count move from 21 toward 86?
2. If it did, repeat once, then try the station and the cruiser briefs.
   If not, the next attempt at accents is a list of what real sets of
   the kind use one or two of (goblets, torches, hinges, brackets, bars),
   filtered so that base plates are not mistaken for accents.
3. Colour is 12 against 23 and nothing has been aimed at it yet.

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
| Real-set data, joined to LDraw | `tools/rebrickable.py` |
| Catalogue build | `tools/refresh_catalogue.py` |
| Drive a real design | `tools/design.py "a brief" --out m.ldr` |
| Deploy | `tools/deploy.sh --prod` |

## Cleanup state

Verified at handoff: no uncommitted changes, no processes left running by
this session, live build matches the last code commit. Scratch work lived
in the session scratchpad under `/tmp`, which is disposable.
