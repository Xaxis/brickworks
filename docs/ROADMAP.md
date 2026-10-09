# What it will take to build kits a LEGO designer would ship

The goal, in the owner's words: designs as good as a set LEGO would
actually release, with no architectural ceiling on size — a real set may
be four thousand pieces or more, so no target number.

This file exists because there wasn't one. Every ceiling so far was found
by measuring, lifted, and written down in `.claude/skills/verify/`, which
is the right place for *how to prove a thing works* and the wrong place
for *what to do next*. What follows is ranked by evidence, not by appeal.

## Where it stands

Four runs of the same castle brief, 2026-10-08/09, each buildable:

| | parts | shapes | colours | most of one piece |
|---|---|---|---|---|
| 1 | 496 | 28 | 4 | 70 |
| 2 | 713 | 23 | 6 | 208 |
| 3 | 1,106 | 22 | 4 | 223 |
| 4 | **1,828** | **30** | **8** | 320 |
| 5, detailed per assembly | 975 | **41** | **11** | 176 |
| 6, detailed per assembly | 795 | 33 | 8 | 144 |
| a real set of 1,828 parts | — | **262** | **28** | 90 |
| a real set of 975 parts | — | 180 | 23 | 43 |

Previous project best was 456 parts. Scale is no longer the constraint.
**The whole remaining gap is one number: 41 shapes at best where a real
set of that size has 180.** Colours are 11 against 23. Everything below
is about closing that and nothing else. Count a run with
`tools/texture.py model.ldr --brief "..."`, after it ends.

How big the first structure comes out is mostly the run, not the code:
496, 713, 1,106, 1,552, 641 and 449 parts across six runs of one brief.

## Solved, so do not re-solve

- **Saying a large model.** `repeat_section`: 250 placements described,
  10,000 bricks built. The lattice holds 50,000 in 180 MB.
- **Checking one.** The design check is ~2 ms a brick; `Stability.check`
  went from 37 ms a brick to 0.08. A 10,000-brick model checks in
  seconds, not minutes.
- **Which part to reach for.** `in_sets` over 30,000 set inventories
  ranks search by what real sets use; 367 kinds of set say what a castle
  or a fire station is characteristically built from, by lift.
- **Judging texture fairly.** The variety norms carry the 5th and 95th
  percentiles of real *models*, so the advice speaks to 9.1% of them.
  Until 2026-10-09 they were measured with mosaics, LEGO Art and bulk
  tubs in, which put the thin end over 1,800 parts at 21 shapes: run 4
  was told nothing. `rebrickable.NOT_A_MODEL` takes them out.
- **Detailing per assembly.** `submit_design` names assemblies and each
  gets a close, measured look of its own after the whole one. Worth
  having, and measured below; not the multiplier.

## The levers, ranked by evidence

1. **Variety inside repetition — now the top lever, on evidence.** The
   per-assembly experiment (below) found the reason it did not double:
   the design makes siblings match. Run 6 took each tower from 6 shapes
   to 11, and the whole model went from 27 to 33, because all four towers
   got the same new parts — "same crown, so they match" four times. Run 5
   did the same to its towers and mirrored its side walls; its ten passes
   held about six ideas. A real castle's towers are not four copies: one
   is the keep, one has the gate winch, one a lookout. **Needs: siblings
   that are told to differ — a pass that knows the other towers already
   have a crown, and copies that can be perturbed without dictating each
   one.** `repeat_section` has the same problem by construction.

2. **More than one idea per pass.** Every pass in runs 5 and 6 made one
   change and stopped — a tower in twelve seconds, a wall in sixty — with
   eight turns available. The pass is told what is missing, measured
   against a real set the size of the assembly (a 70-part tower against
   38 shapes), and answers with one edit. Whether that is the prompt's
   "say what you changed and stop" or the model judging one idea enough
   is not yet measured.

3. **A surface-treatment vocabulary, measured rather than invented.**
   `kinds` says *which* parts a castle reaches for. Nothing yet says
   where they go, and "a wall wants masonry bricks, an arrow slit, a
   corbel course and a tile walkway" is currently my taste. The data to
   replace that is already downloaded and unread: part **co-occurrence**
   within sets. **Needs: a measurement of which parts appear together,
   conditioned on kind.**

4. **Colour as structure.** 11 against 23 at best. The kinds data gives each kind
   its palette by lift; nothing says a second colour belongs at a string
   course, a lintel, a roof band. Likely falls out of (3).

## The open question, measured 2026-10-09

Whether detailing per assembly is the multiplier. **It is not.** Runs 5
and 6 of the castle brief, with the whole look followed by a close,
measured look at each assembly:

| | first holds | after whole look | after the passes |
|---|---|---|---|
| run 5, 10 assemblies | 641 / 19 shapes | 797 / 27 | **975 / 41**, 11 colours |
| run 6, 8 assemblies | 449 / 18 | 572 / 27 | 795 / 33, 8 colours |

The passes are worth 1.2-1.5x on shapes, and run 5 used 8 of the 21
parts the tower and castle kinds are characteristic for, against 4 in
run 4. Real, cheap (about nine minutes of passes), and kept. Not 2x, so
by the test this roadmap set, more knowledge in front of the design at a
moment it can act has stopped being the lever: 20 -> 30 -> 41 at best,
against 180.

What the passes showed instead is *why*, and it is two things rather
than one ceiling: siblings converge (lever 1) and each pass does one idea
(lever 2). Neither is a capacity limit. Both are the next experiments,
in that order, before decomposing the loop itself.

**Cost.** Run 6 spent $9.67 on Opus 5.5 at high effort, and $8 of it was
input tokens sent fresh: 2.04M against 575k read from the cache. Only the
system prompt and tools are cached, so every turn pays full price for
the whole conversation again. More passes multiply exactly that.

## How progress is judged

Rerun a brief and measure the model, never read the diff. `tools/design.py`
drives the real assistant and prints what it spent; `tools/texture.py`
counts the saved `.ldr` against `catalogue.json`'s `set_norms` and the
brief's kinds. A run's progress lines say what each assembly pass came
to. Two measurements have been wrong by being taken too early: `--out` is
rewritten on every build, so read the file after the run *ends*, and a
wall clock on a shared machine measures the machine.
