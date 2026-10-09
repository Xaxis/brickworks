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

- Clean tree, pushed. Live at **brickworks.diy**, serving `/b/31707b2/`,
  which is `main` minus this file — a docs-only commit does not earn a
  deploy, and the app in that build is the current one. 23 commits on
  2026-10-08/09, all authored `Xaxis <william.neeley@gmail.com>`.
  Confirm with: `curl -sI "https://brickworks.diy/app?v=$(date +%s)" |
  grep -i location` against `git log --oneline -3`.
- Full suite: **54 ok, 0 fail, 0 unproven** (`tools/check.sh`, ~20 min).
- Four castle runs took the assistant from 496 to **1,828 bricks
  buildable**, against a previous project best of 456.

**The one open number: 30 different shapes where a real set of that size
has 242, and 8 colours against 27.** Scale is solved; texture is not.

## What was decided, and why

- **Design knowledge comes from data, not taste.** Part search ranks by
  how many real sets use a part; 367 "kinds" of set say what a castle or
  a fire station is characteristically built from, by *lift* over sets in
  general. Reason: everything the prompt said about what to reach for was
  mine, and a castle is not arches because I say so.
- **Knowledge a design can get by without is knowledge it never uses.**
  Measured twice. So the kind data arrives with the brief rather than
  waiting behind a tool call.
- **Advice fires on the tails, not on a multiple of the median.** The
  first version flagged 29-34% of real LEGO sets as repetitive; it is
  8.5% now. Advice that fires on good models is noise.
- **No wall clocks in checks.** Three flapped in one day on a shared
  machine. Use a ratio, or compare against something else measured on the
  same machine in the same run.
- **The landing page is the product first.** Proof of exactness sits
  behind a disclosure below the features, not above them.

## What is next

Read `docs/ROADMAP.md`. The top lever, with the evidence already in hand:
**detail per assembly rather than once for the whole model.** A single
detailing pass — the final look, once it carried what the check had
measured — took a castle from 20 shapes to 30 and from 2
castle-characteristic parts to 12. A gatehouse, four towers, a curtain
wall and a courtyard are five to ten assemblies.

The decisive experiment is written down in the roadmap: run the castle
brief with the final look applied per assembly. If shapes do not roughly
double, one design pass is the ceiling and the loop has to decompose the
model instead.

## Gotchas that will cost you hours

- **Commits are authored as the user, always.** `git -c user.name=Xaxis
  -c user.email=william.neeley@gmail.com commit -F <msgfile>`. Vercel
  seat-checks the author and a wrong one fails the deploy *silently*. No
  assistant attribution of any kind, ever.
- **This machine has no display.** `tools/check.sh` and
  `tools/design.py` give themselves Xvfb automatically. Anything new that
  drives the app needs the same, or it hangs on a window whose monitor is
  gone — that cost 25 minutes twice.
- **It is a shared machine.** Another project runs Godot and ffmpeg here;
  load average hit 171. Never kill by `ps | grep` — use
  `tools/running.py <pattern>` to find and `--stop` to end, which spares
  the shells waiting on a run. Do not touch anything under
  `/mnt/Projects/Reelwright`.
- **Do not run a design or a heavy job while the suite runs.** The
  windowed probes starve above about load 12 and report failures that are
  not real.
- **Read a design run's output after it ends.** `--out` is rewritten on
  every build, so the file moves under you; a model read early was
  reported as 1,552 parts when it finished at 1,828.
- **Measure a page where its assets resolve.** A copy kept in a scratchpad
  has no `shot-app.png`, so it fits where the real page does not.
- **No GDScript string is greppable in a `.pck`.** To prove code shipped,
  use the stamp: `/` 308s to `/b/<sha>/`. Packed JSON *is* greppable.
- **Rebrickable may be downloaded at most once a day.** That is a licence
  condition, enforced in `tools/fetch_data.sh`.
- **Before deploying after any geometry change**, run
  `python3 tools/storage_parts.py --check` and confirm `to upload: 0`.
  Meshes are named by content hash and live in Supabase, not the deploy.

## Where things are

| | |
|---|---|
| The plan | `docs/ROADMAP.md` |
| How to prove anything works | `.claude/skills/verify/` (start at `SKILL.md`) |
| The whole check suite | `tools/check.sh` (~20 min, 54 checks) |
| The design loop and its prompt | `src/ai/assistant.gd` |
| Shapes said rather than counted | `src/ai/patterns.gd` |
| Worked constructions | `src/ai/techniques.gd` |
| Collision and occupancy | `src/assembly/lattice.gd` |
| Does it stand up | `src/assembly/stability.gd` |
| Real-set data, joined to LDraw | `tools/rebrickable.py` |
| Catalogue build | `tools/refresh_catalogue.py` |
| Drive a real design | `tools/design.py "a brief" --out m.ldr` |
| Deploy | `tools/deploy.sh --prod` |
| Landing page | `web/index.html`, checked by `tools/web/landing_check.mjs` |

## Cleanup state

Nothing to clean up. Verified at handoff: no uncommitted changes, no
`_tmp_*` files in `src/dev/` or `tools/web/`, no processes left running
by this session, live build matches `HEAD`. Scratch work lived in the
session scratchpad under `/tmp`, which is disposable and outside the
repo.

If a future session leaves something behind, these are the places to
look: `src/dev/_tmp_*.gd` (and their `.uid` siblings), `tools/web/_tmp_*`,
stray `godot-bin --path .` processes under this checkout, and
`git status --porcelain`.
