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
| a real set of 1,828 parts | — | **242** | **27** | 102 |

Previous project best was 456 parts. Scale is no longer the constraint.
**The whole remaining gap is one number: 30 shapes where a real set of
that size has 242.** Colours are 8 against 27. Everything below is about
closing that and nothing else.

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
  percentiles of real sets, so the advice speaks to 8.5% of them.

## The levers, ranked by evidence

1. **Detail per assembly, not once for the whole model.** The strongest
   evidence we have: run 4 went from 20 shapes to 30, and from 2
   castle-characteristic parts to 12, in a *single* detailing pass — the
   final look, once it carried what the check had measured. That pass
   happens once and globally. A gatehouse, four towers, a curtain wall
   and a courtyard are five to ten assemblies, and the same mechanism
   applied per assembly is the obvious multiplier. **Needs: the loop to
   decompose a model into assemblies and run the look over each.**

2. **Variety inside repetition.** `repeat_section` makes forty identical
   bays. A designer makes a bay with a window, a bay with a buttress, a
   bay with a stair. Copies are exact by construction today. **Needs:
   copies that can be perturbed — a part swapped, a colour band, an
   opening — without dictating each one.**

3. **A surface-treatment vocabulary, measured rather than invented.**
   `kinds` says *which* parts a castle reaches for. Nothing yet says
   where they go, and "a wall wants masonry bricks, an arrow slit, a
   corbel course and a tile walkway" is currently my taste. The data to
   replace that is already downloaded and unread: part **co-occurrence**
   within sets. **Needs: a measurement of which parts appear together,
   conditioned on kind.**

4. **Colour as structure.** 8 against 27. The kinds data gives each kind
   its palette by lift; nothing says a second colour belongs at a string
   course, a lintel, a roof band. Likely falls out of (3).

## The open question

Whether one design pass can hold a 240-shape budget at all. Every
intervention so far has been prompt-and-measurement — more knowledge, in
front of the design, at a moment it can act — and that has taken shapes
from 20 to 30. If the next pass-level intervention gets 40 rather than
100, the answer is no, and lever 1 stops being an optimisation and
becomes the architecture: the loop decomposes, designs each assembly
against its own part budget, and assembles.

**The measurement that decides it:** run the castle brief with the final
look applied per assembly rather than once. If shapes do not roughly
double, the single pass is the ceiling.

## How progress is judged

Rerun a brief and measure the model, never read the diff. `tools/design.py`
drives the real assistant; the figures above come from counting shapes,
colours and the largest lot in the saved `.ldr` against
`catalogue.json`'s `set_norms`. Two measurements have been wrong by being
taken too early: `--out` is rewritten on every build, so read the file
after the run *ends*, and a wall clock on a shared machine measures the
machine.
