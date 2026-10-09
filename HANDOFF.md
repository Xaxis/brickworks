# Handoff

Written 2026-10-09 for a fresh session. Everything below is committed,
pushed and live; nothing is half-finished.

## The goal

Designs as good as a set LEGO would actually release, with no
architectural ceiling on size. The owner's words: a real set may be four
thousand pieces or more, so do not design to a target number.

`docs/ROADMAP.md` is the plan and is the **first thing to read**. It
states the gap as one number, lists what is already solved so it is not
solved twice, and ranks the levers by the evidence for each.

## Where it stands

- Clean tree, pushed, live at **brickworks.diy**, serving `/b/87537ed/`,
  which is `main` minus this file — a docs-only commit does not earn a
  deploy. Confirm with:
  `curl -sI "https://brickworks.diy/app?v=$(date +%s)" | grep -i location`
  against `git log --oneline -3`.
- Full suite green: `tools/check.sh`, which now queues itself on the
  machine's `heavy` pool (see below).
- Not exercised: the proxy's conversation caching for signed-in accounts
  (`api/claude.js`). It is deployed; proving it needs an account.
- Best castle so far, run 8: **1,895 parts, 53 shapes, 13 colours**,
  against 30 shapes before this session. A real set that size has 262.

## What this session did, and what it found

- **The size norms were measured against mosaics.** The thinnest real
  sets of every size are mosaics, LEGO Art, bulk tubs, education packs
  and Duplo. Over 1,800 parts that put "thin" at 21 shapes, so a castle
  of 1,828 parts and 30 shapes was told nothing. `rebrickable.NOT_A_MODEL`
  and `NAMED_NOT_A_MODEL` leave them out; thin there is 134 now.
- **Detailing per assembly** — the roadmap's decisive experiment. Each
  assembly a design names comes back to it close up, measured against a
  real set its own size. On its own it was worth 1.2-1.5x, not the 2x
  the roadmap asked for: siblings converged (four towers, "the same
  crown") and each pass made one change and stopped.
- **Thin passes sent back once** (run 8) took a castle from 23 shapes to
  53 in its passes — the first doubling. One run. Repeat it first.
- **A design cost $9.67 and $8 of it was re-sending the conversation.**
  The conversation is cached now and old pictures are no longer
  rewritten every turn; the same kind of run costs about $4-6.
- **The GPU is shared.** Design runs render in software now and took
  zero blind looks at load ~80.

## What is next

Read `docs/ROADMAP.md`. In order: rerun the castle brief to see whether
53 holds (`tools/design.py "a medieval castle with a gatehouse, four
corner towers and a long curtain wall between them" --effort high`, then
`tools/texture.py` on the file once the run has ended); then try a
different brief, because every number here is one castle; then raise what
a pass is for, since 53 against 262 is still a fifth.

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
