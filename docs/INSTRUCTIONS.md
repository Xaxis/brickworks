# Instructions: our steps against the steps real sets' authors chose

Brickworks makes a booklet for any model. When the model came with steps of
its own (Studio, LDCad, LeoCAD, an LDraw file's `0 STEP` lines), the booklet
follows them (`AuthorSteps`). When it did not, `Instructions.plan` works the
steps out: it grows the order forward from the table, a part going in only
once what holds it is there, so every step can be carried out. It never
takes a finished model apart to find its order. A patent of the LEGO Group
covers instructions made that way, by disassembly, and Google Patents shows
it active until 2030-03-17 [patent]. The planner builds forward and this work
keeps it so.

This page measures how close those worked-out steps come to the steps people
chose for real sets, says what the measure showed, and what changed.

**In short** (2026-10-16, two samples of 100 sets):

- **Order.** Our worked-out order agrees with the author's at Kendall tau
  0.28 on tune and 0.31 on the held-out sample, where it was 0.27 to 0.29
  before this work, barely above sorting by height (0.23, 0.25). A graph transformer trained on LEGO® build orders reached 0.44
  [gt-asp]. Nearly all of the gap is which sub-model the author builds first:
  built in the author's order of sub-models, ours would score 0.86, and no
  rule from the model's shape gets past 0.26. The shape does not say it.
- **The booklet's reading of an author's steps** went up a step of each
  sub-model in turn when one step placed several. Each is built whole now:
  order agreement 0.72 to **0.94** on the sample nothing was tuned on
  (paired change +0.22, 95% interval +0.16 to +0.29, better in 61 files and
  worse in 2), and steps with a floating part 15.0% to 11.4%.
- **Every step buildable.** One step in five of ours left a part floating,
  against one in thirty of the authors', because the planner read what
  rests on what from bounding boxes. It now reads the studs, by the build
  check's own rule. On the held-out sample, against the code before it:
  things put in under one already there 19.6% to 11.3% (paired -8.4, -13.4
  to -4.8), steps with a hidden new thing 19.2% to 13.8% (-5.4, -8.6 to
  -2.7), and steps with a floating thing 18.1% to 14.9% (-3.2, -5.2 to
  -1.4). The authors': 0.8%, 6.7% and 3.4%. Order agreement did not suffer
  (0.27 to 0.31, +0.03, -0.01 to +0.08), and the 100 files plan in 19.2 s
  where they took 16.0 s. The aim was 8% for floating and for put in under.
  A model turned on its stand, the Technic sets and vehicles built before
  their wheels stood in the way (What is left).
- **Pages.** A small model is no longer cut into "Part 1" and "Part 2": 918
  Space Transport's booklet lost a one-step page and a repeated banner. A
  section that touches nothing built before it is drawn on its own: 7636's
  harvester no longer begins in the air above the hay bales.

## The measure

`tools/steps_score.py` and `src/dev/steps_score.gd`; the recipe is in
`.claude/skills/verify/features/view.md`.

**The sets.** LDraw's Official Model Repository holds real sets as LDraw
files. Its rule is that their step lines "should enable any instructions
generated to be as close to the official instructions as possible"
[omr-spec]. We hold 1,572 of its files (vendor/omr, `tools/omr.py fetch`).
Two samples are drawn from them, the same every run:

- sets taken in the order of a hash of their number, so nobody picked them;
- a file of 10 to 2,500 parts with at least two `0 STEP` lines;
- 25 files from each of four sizes (10-99, 100-299, 300-799, 800-2,500
  parts), and within a size the theme taken least so far first;
- a set's files all in one sample.

`tune` (100 files, 48,037 parts, 39 themes) is what the planner was looked at
and changed on. `proof` (100 files, 52,435 parts, 30 themes) is a second
sample of other sets, which nothing was tuned on.

**The builds.** Each file is opened as File, Open opens it and built six ways:

| Build | What it is |
|---|---|
| the author's steps | as LDraw means them: every sub-model built apart in its own steps, then put on whole in the step its parent places it in; copies of one placed in one step built once, in the order the step lists them |
| the author's, as the booklet draws them | `Instructions.plan(..., authored = true)`, what the booklet shows for such a file |
| ours | `Instructions.plan` on the model with every step taken away and its parts shuffled, so nothing of the author's order reaches it through the order of the file; its sub-models kept, as a stepless file has them |
| ours, no sub-models | the same with the sub-models taken away too: a model built by hand |
| file order | the parts in the order the file lists them, cut into steps of the size ours takes |
| bottom up by height | lowest first, then by x and z, cut the same way |

File order is not a naive baseline here. Authors write a file in the order
they build it, so a step-less file still says the author's order, and file
order scores near the author. It is the ceiling for "keep the order the file
was written in", not a plan.

**The measures**, each with a 95% interval from resampling the files 2,000
times (seeded):

- **Order agreement**: Kendall's tau-b between the step each part goes in,
  in a build and in the author's. Parts in one step are tied. This is the
  measure Graph Transformer sequence planning used on LEGO® build orders,
  0.44 against people's [gt-asp]. 1 is the author's order, 0 unrelated, -1
  reversed.
- **Same-step pairs kept together**: of the pairs of parts the author put in
  one step, the share the build also does.
- **Step counts and sizes**: steps against the author's, things a step (a
  thing is a part, or a sub-assembly put on whole), and the share of steps
  over MEPNet's 10 parts or 5 kinds, the rule it made its synthetic manuals
  with [mepnet].
- **Sub-assembly agreement**: of the author's sub-assemblies (every copy of a
  sub-model, at any depth, of two parts or more and under nine tenths of the
  model), the share the build makes on the side and puts on whole, matched
  when it has at least 80% of the same parts.
- **Never hidden**: new things that show less than a tenth of themselves from
  the front and from the back, the two ways the booklet looks
  (`BookletMaker._choose_views`), with everything placed by the end of the
  step in front of them. "All the new parts added in each step ... must be
  visible" is the strongest design principle Agrawala et al. found [agrawala].
  Drawn on the CPU from each part's collision cover, a pixel 4 LDU.
- **Never put in under**: things put in under a part placed in an earlier
  step, resting on them, so they cannot be pressed on from above. Not a pin
  or an axle, which goes in along its line; and on the model only, since a
  sub-assembly in the hand is any way up.
- **Every step buildable**: things held to nothing that stands at the end of
  their step. On the model, what stands is what is on the ground and the
  model's first parts (a car's chassis goes down first and rests on the
  table, though its tyres are lower); on a sub-assembly, its first parts,
  the piece in the hand. APEX-MR prunes every order whose intermediate state
  is unstable [apexmr]. `--check` asks the app's own build check too, on the
  model as it stands after five steps of each build, for files of up to 300
  parts.

**Held** is the probe's own graph, so the planner is not marked by its own
rules: what rests on what by the parts' covers (`Stability.contacts`), and
every joint the build check reads (pins and axles, axles through holes,
clips, bars, hinges, turntables, balls, what is held otherwise). A thing the
graph does not hold even in the finished build is not counted either way.

**The measures check themselves.** Every run first builds models whose
answers are known and refuses to score if one is wrong: three bricks built
from the top float twice and are put in under twice; built from the bottom,
nothing is wrong; a 1 x 1 plate put into a well of bricks four high is hidden,
and put in first it is not; in the hand, a part that joins nothing floats.
The arithmetic is pinned by `tests/test_steps_score.py`: tau-b against its
definition pair by pair on random rankings with ties, and scipy's own
example (-0.4714), samples that are the same every time and share no set.

```sh
python3 tools/steps_score.py run --which tune --out build/steps_score/tune    # ~10 min under heavy
python3 tools/steps_score.py report --out build/steps_score/tune
python3 tools/steps_score.py compare build/steps_score/before build/steps_score/after
```

## Where it stood

Tune, 100 files, 48,037 parts, 2026-10-15, before any change:

| Measure | the author's steps | the author's, as the booklet drew them | ours | ours, no sub-models | file order | bottom up by height |
|---|---:|---:|---:|---:|---:|---:|
| Kendall tau-b against the author | 1.00 | 0.75 (0.69–0.81) | **0.27 (0.21–0.32)** | 0.21 (0.15–0.26) | 0.96 (0.94–0.97) | 0.23 (0.18–0.28) |
| author's same-step pairs kept together | 100% | 92.6% | 5.6% (3.1–11.7) | 3.7% | 9.1% | 4.1% |
| steps for each of the author's | 1.00 | 1.00 | 1.29 (1.10–1.51) | 1.21 | 0.83 | 0.83 |
| steps of one thing | 18.4% | 19.7% | 39.4% | 39.5% | 0.3% | 0.3% |
| steps over 10 parts or 5 kinds | 10.5% (8.1–13.4) | 10.2% | 11.0% (8.2–13.9) | 15.3% | 22.3% | 28.6% |
| author's sub-assemblies built on the side | 97.4% | 64.8% (58.7–70.6) | 40.0% (34.3–46.1) | 0% | 0% | 0% |
| steps with a hidden new thing | 6.2% (4.9–7.8) | 7.9% | **21.2% (17.5–24.5)** | 26.5% | 28.9% | 23.8% |
| things put in under one already there | 1.3% (0.6–2.2) | 11.5% | **19.4% (14.2–25.3)** | 23.6% | 22.8% | 26.5% |
| steps with a floating thing | 2.9% (2.0–3.9) | 14.1% (10.1–18.3) | **19.1% (16.1–22.3)** | 22.6% | 20.5% | 29.2% |
| parts the build check calls floating at sampled steps | 6.0% (1.6–12.1) | – | 12.8% (7.2–20.0) | 18.7% | – | – |

The last row is a third opinion: the build check the app gives a design
(`Assistant._check` with only the ground holding, the one the connection
audit uses), run on the model as it stands after five steps spread through
each build, on the 50 files of up to 300 parts. It knows side studs and
pushed-in joints the probe's graph does not.

Three things stand out.

**Our order is barely better than sorting by height.** 0.27 against 0.23,
where a graph transformer trained on LEGO® build orders reached 0.44
[gt-asp]. The reason is the order of sub-models. Of pairs of parts in two
different sub-models, ours orders 56.1% as the author does, which is close to
a coin. Inside one sub-model it is 70.1%, and bottom up is 72.5% there. Built
as blocks in the author's order, bottom up inside each, the tune files would
score **0.86**. But no rule from the model's shape picks that order: lowest
block first scores 0.25, biggest first 0.17, and every mix of the two tried
0.21 to 0.26. 69% of the pairs between sibling sub-models are between
sub-models one step places together, where nothing but the file's listing
says which comes first (the bigger is listed first in 62% of them). That is
the designer's choice, not geometry, and a planner that only sees the shape
cannot recover it.

**The booklet misread its own authors.** Given the author's steps, the
booklet drew them at 0.75. Sub-models a step places together were built a
step of each in turn: the five buildings of 10230 Mini Modulars went up a
course of each, then the next course. Each is now built whole, in the order the step places it
(`AuthorSteps.key_of`, `first_under`).

**One step in five of ours cannot be done as drawn.** Authors leave a thing
floating at the end of its step in 2.9% of steps and put one in under a part
already placed for 1.3% of things. Ours do 19.1% and 19.4%, no better than
bottom up. Asked what the planner itself believed about each, its own graph
says:

| Put in under one already there (9,276) | | Floating at its step (6,996) | |
|---|---:|---|---:|
| it rests on this one, and the planner's boxes missed it | 6,759 | it rests on parts whose boxes touch and whose shapes do not | 3,790 |
| it hangs pressed under what it touches | 2,314 | it hangs from what it touches | 2,205 |
| a sub-assembly | 198 | placed before what it needs, the loop broken | 706 |
| | | the planner had it needing nothing | 241 |

So the cause is that the planner reads what rests on what from bounding
boxes. A slope's box, an L-shaped plate's, a bracket's are not the part.
Reading the parts' collision covers instead, as the stability check does
(`Stability.contacts`), was tried. It needs a lattice of covers the planner's
callers do not hold, cost 14 times the planning time (20 s to 286 s over the
100 files; the 1,454-part Rebel Snowspeeder, 0.7 s to 22-32 s), and on its
own made 77% of steps one part, because a stud reaches up into the part above and each read
as resting on the other. With a part resting only on one whose cover starts
lower, it moved "put in under" from 19.4% to 17.7% and floating things from
16.4% to 17.3%. Not worth fourteen times the wait; it is the next thing to
fix, with a cheaper reading of covers.

## What changed

1. **The author's steps, as written** (`src/assembly/author_steps.gd`,
   `Instructions._authored_plan`). The sort key of a step names, at each
   level, the step the copy goes on in *and where that step places it* (its
   first part in the file), so sub-models one step places are each built
   whole, one after another, in the order the step lists them; and the
   copies a step puts on are taken in that order, not alphabetically.
2. **A pin goes into one part, and the next goes on it**
   (`Instructions._find_joints`). A pin joining two parts waited for both,
   so it went in last, between two beams already there, where no picture
   could show it: 1,296 of our hidden things on tune were Technic parts,
   against 431 in the authors' steps. Now it goes into the lowest of the
   parts it joins, and the others need it, as a Technic booklet has it.
   `instructions_probe` checks the kart: no pin before the hole it goes
   into, and the pins that join two parts in before the second part.
3. **A small model is not cut into tiles** (`Instructions.TILED_FROM`, 400
   parts). Tiles of the plan were made for a 1,895-part castle. A 92-part
   spaceship (918 Space Transport) wider than a tile's 24 studs was cut in
   two, "Part 1" a stand and a plate, one step on a page of its own under a
   banner, and "Part 2" twice, when the build went back to it.

Tried and not kept, on tune: filling a step by plate layer, with more of the
same part on the same layer, and from twice as far (one-part steps 39.4% to
37.6%, nothing else moved); a part hanging under another put in with it (no
change); covers (above).

Then what rests on what, 2026-10-16:

4. **By the studs, not the boxes** (`Instructions._supports_of`,
   `Joints.studs_in`, `Instructions.Covers`). A stud reaching up into a
   part means that part sits on the stud's owner; reaching down, the part
   is turned over on top of it. The stud's direction says which of two
   parts rests on the other, where covers read as touching said each rested
   on each. The rule is the build check's, moved into `Joints.studs_in`:
   the check asks its lattice what is past a stud's tip, and the booklet,
   which holds no lattice, asks the few parts whose boxes hold the tip
   whether their covers do, each in its own frame. `instructions_probe`
   holds the two to the same 816 stud pairs on the station. A part no stud
   seats (a figure's, a Technic beam, a tile on a side stud) rests on what
   its box sits on, as before.
5. **A plate pressed up under parts goes in with them** (`_pressed_up`).
   A 1 x 3 under a sign, a 2 x 2 under a lantern: read by its studs alone,
   what it carries needs it, so it went in first, on nothing. It goes in in
   the step of the last part it is under.
6. **A part on a side stud waits for what holds it** (`Node2.held_by`),
   not only for what its box sits on. Vernie's tiles went on before the
   bricks whose side studs hold them.
7. **A sub-model put on at an angle is built on the side** (`_turned`), of
   any size up to half the model: square, in the hand, with steps of a
   page's size, then put on turned. On the five biggest tune files, 19 in
   20 of the things put in under were turned parts of a sub-model too big
   to be a callout, and their authors put in none.
8. **A loop gives up a guess before a callout** (`_contract`, `_ease`).
   Needs guessed from touching boxes go first, then those read off a box,
   and only then the smallest sub-assembly on the loop. A hose drawn
   through a figure's hand had cost a 664-part trailer, a locomotive and
   the figures riding them their callouts.
9. **A flexible thing goes in as one** (`_find_bundles`). 6891's hose,
   drawn a segment at a time, was 52 things floating, in 28 of its 83 steps.
10. **A section that touches nothing built before it is drawn on its own**
    (`BookletMaker._find_apart`), framed on itself as a booklet draws a
    second vehicle, until the build moves on. What it touches is read off
    the parts' boxes.

Tried and not kept: reading clips, hinges and balls as well (`Joints.rounds`,
`balls`). They changed nothing measured but the planning time, 2.5 s to
4.1 s on fifteen files.

## After

### The author's steps and Technic pins (2026-10-15)

**Proof**, the sample nothing was tuned on: 100 files, 52,435 parts. Before
is the code at 7a55e86, after is this change; the interval is after's, and
`compare` gives the paired change file by file: steps with a floating thing
-3.0 (-4.8 to -1.3), steps with a hidden new thing -1.9 (-3.7 to -0.3).

| Measure | the author's | the booklet's reading of them, before → after | ours, before → after | ours, no sub-models, before → after | bottom up |
|---|---:|---:|---:|---:|---:|
| Kendall tau-b against the author | 1.00 | 0.72 → **0.94 (0.90–0.97)** | 0.29 → **0.27 (0.21–0.34)** | 0.26 → **0.26 (0.20–0.32)** | 0.25 |
| author's same-step pairs kept together | 100.0% | 96.0% → **95.6% (88.5–98.9)** | 10.4% → **10.9% (8.1–16.0)** | 8.3% → **8.9% (6.6–13.2)** | 9.1% |
| steps for each of the author's | 1.00 | 1.00 → **1.00 (1.00–1.03)** | 1.17 → **1.14 (1.03–1.28)** | 1.04 → **0.96 (0.87–1.14)** | 0.77 |
| author's sub-assemblies built on the side | 97.9% | 64.9% → **64.7% (56.2–73.4)** | 38.5% → **39.5% (28.6–51.1)** | 0.0% → **0.0% (0.0–0.0)** | 0.0% |
| steps with a hidden new thing | 6.8% | 9.7% → **9.4% (7.3–11.8)** | 21.5% → **19.6% (14.9–24.5)** | 24.9% → **24.0% (19.5–28.5)** | 21.4% |
| things put in under one already there | 0.8% | 13.5% → **13.2% (8.7–18.2)** | 20.4% → **19.9% (12.2–28.4)** | 22.8% → **22.3% (14.6–30.9)** | 26.4% |
| steps with a floating thing | 3.5% | 15.0% → **11.4% (7.5–16.1)** | 20.9% → **17.9% (13.9–22.1)** | 24.1% → **21.5% (17.4–25.9)** | 25.6% |
| parts the build check calls floating at sampled steps | 3.1% | – | 22.4% → **20.5% (12.1–29.8)** | 25.0% → **25.5% (16.1–35.7)** | – |
| steps in all | 11,890 | 11,989 → 12,230 | 14,370 → 13,090 | 13,618 → 12,098 | 7,350 |

**Tune**, 100 files, 48,037 parts:

| Measure | the author's | the booklet's reading of them, before → after | ours, before → after | ours, no sub-models, before → after | bottom up |
|---|---:|---:|---:|---:|---:|
| Kendall tau-b against the author | 1.00 | 0.75 → **0.92 (0.88–0.95)** | 0.27 → **0.29 (0.23–0.34)** | 0.21 → **0.22 (0.17–0.27)** | 0.23 |
| author's same-step pairs kept together | 100.0% | 92.6% → **92.5% (80.9–98.2)** | 5.6% → **6.1% (3.2–13.1)** | 3.7% → **3.8% (2.2–7.6)** | 4.1% |
| steps for each of the author's | 1.00 | 1.00 → **1.02 (1.00–1.04)** | 1.29 → **1.25 (1.05–1.48)** | 1.21 → **1.13 (0.93–1.34)** | 0.83 |
| author's sub-assemblies built on the side | 97.4% | 64.8% → **64.7% (58.6–70.5)** | 40.0% → **40.1% (34.7–46.1)** | 0.0% → **0.0% (0.0–0.0)** | 0.0% |
| steps with a hidden new thing | 6.2% | 7.9% → **8.3% (6.8–10.2)** | 21.2% → **19.9% (16.2–23.5)** | 26.5% → **25.4% (21.9–28.6)** | 23.8% |
| things put in under one already there | 1.3% | 11.5% → **11.7% (8.8–15.4)** | 19.4% → **19.4% (14.2–25.4)** | 23.6% → **23.2% (18.0–29.3)** | 26.5% |
| steps with a floating thing | 2.9% | 14.1% → **11.8% (8.8–15.2)** | 19.1% → **16.9% (14.2–20.0)** | 22.6% → **20.8% (16.9–24.9)** | 29.2% |
| parts the build check calls floating at sampled steps | 6.0% | – | 12.8% → **11.9% (6.3–18.7)** | 18.7% → **17.2% (10.2–25.0)** | – |
| steps in all | 9,633 | 9,794 → 9,992 | 14,306 → 13,579 | 12,730 → 11,804 | 6,710 |

### What rests on what, by the studs (2026-10-16)

**Proof**, 100 files, 52,435 parts. Before is main at 2789cd0, whose plans
are file for file those of main when this work began; after is this change
on it. Both ran on this machine the same morning; the interval is after's.
The paired change, file by file
(`compare`): things put in under -8.4 (-13.4 to -4.8), steps with a hidden
new thing -5.4 (-8.6 to -2.7), steps with a floating thing -3.2 (-5.2 to
-1.4), tau +0.03 (-0.01 to +0.08), better in 54 files and worse in 46.

| Measure | the author's | the booklet's reading of them, before → after | ours, before → after | ours, no sub-models, before → after | bottom up |
|---|---:|---:|---:|---:|---:|
| Kendall tau-b against the author | 1.00 | 0.94 → **0.93 (0.89–0.96)** | 0.27 → **0.31 (0.24–0.37)** | 0.26 → **0.28 (0.22–0.34)** | 0.25 |
| author's same-step pairs kept together | 100.0% | 95.6% → **94.8% (86.6–98.6)** | 10.9% → **12.0% (8.8–18.0)** | 8.9% → **18.6% (8.7–37.0)** | 9.1% |
| steps for each of the author's | 1.00 | 1.00 → **1.00 (1.00–1.03)** | 1.14 → **1.10 (1.02–1.26)** | 0.96 → **0.93 (0.85–1.07)** | 0.77 |
| author's sub-assemblies built on the side | 97.9% | 64.7% → **62.0% (51.7–72.3)** | 39.5% → **54.1% (42.3–66.2)** | 0.0% → **0.0% (0.0–0.0)** | 0.0% |
| steps with a hidden new thing | 6.7% | 9.3% → **8.7% (6.9–10.5)** | 19.2% → **13.8% (11.1–16.4)** | 23.5% → **22.0% (18.9–25.0)** | 21.0% |
| things put in under one already there | 0.8% | 13.1% → **8.1% (5.4–11.2)** | 19.6% → **11.3% (6.0–17.6)** | 22.0% → **20.3% (13.2–28.1)** | 26.1% |
| steps with a floating thing | 3.4% | 11.4% → **9.6% (6.7–12.8)** | 18.1% → **14.9% (11.2–18.9)** | 21.9% → **20.8% (16.5–25.2)** | 25.9% |
| parts the build check calls floating at sampled steps | 3.1% | – | 20.5% → **21.3% (12.2–31.7)** | 25.6% → **26.0% (15.9–38.3)** | – |
| steps in all | 11,890 | 12,230 → 12,274 | 13,090 → 14,561 | 12,098 → 11,740 | 7,350 |

More of the authors' sub-assemblies are built on the side (39.5% to 54.1%),
from sub-models put on at an angle, and there are more steps (13,090 to
14,561). The booklet's reading of the authors' own steps gains too, since it
reads support and finds sub-assemblies the same way: things put in under
13.1% to 8.1% (-5.0, -8.1 to -2.4).

**Tune**, 100 files, 48,037 parts, against the code of the section above:
things put in under -11.6 (-17.2 to -7.1), steps with a hidden new thing
-6.2 (-8.8 to -3.4), steps with a floating thing -4.2 (-6.4 to -1.8), tau
-0.01 (-0.05 to +0.03). Same-step pairs kept together jump on one file:
9391's crane string, drawn in 681 pieces its author puts on in one step, now
goes in as one flexible thing.

| Measure | the author's | the booklet's reading of them, before → after | ours, before → after | ours, no sub-models, before → after | bottom up |
|---|---:|---:|---:|---:|---:|
| Kendall tau-b against the author | 1.00 | 0.92 → **0.91 (0.87–0.95)** | 0.29 → **0.28 (0.21–0.34)** | 0.22 → **0.22 (0.16–0.28)** | 0.23 |
| author's same-step pairs kept together | 100.0% | 92.5% → **93.1% (82.0–98.6)** | 6.1% → **31.2% (6.1–62.3)** | 3.8% → **64.7% (26.3–82.7)** | 4.1% |
| steps for each of the author's | 1.00 | 1.02 → **1.02 (1.00–1.04)** | 1.25 → **1.29 (1.08–1.54)** | 1.13 → **1.15 (0.88–1.29)** | 0.83 |
| author's sub-assemblies built on the side | 97.4% | 64.7% → **62.2% (55.8–69.2)** | 40.1% → **57.1% (50.7–64.0)** | 0.0% → **0.0% (0.0–0.0)** | 0.0% |
| steps with a hidden new thing | 6.0% | 8.3% → **8.0% (6.6–9.8)** | 19.9% → **13.7% (11.9–15.6)** | 25.4% → **21.4% (18.6–23.9)** | 23.0% |
| things put in under one already there | 1.2% | 11.7% → **7.7% (5.7–10.1)** | 19.4% → **7.9% (5.8–10.2)** | 23.2% → **17.4% (13.8–21.7)** | 26.1% |
| steps with a floating thing | 2.9% | 11.8% → **10.0% (7.3–12.9)** | 16.9% → **12.8% (9.7–15.7)** | 20.8% → **20.0% (16.1–23.8)** | 29.4% |
| parts the build check calls floating at sampled steps | 6.0% | – | 11.9% → **11.3% (5.6–19.9)** | 17.2% → **13.8% (7.7–21.7)** | – |
| steps in all | 9,633 | 9,992 → 9,983 | 13,579 → 13,450 | 11,804 → 9,656 | 6,710 |

Planning took 19.2 s over the 100 proof files, against 16.0 s on main
(1.2 times), the slowest file 2.0 s (76161, 2,396 parts); on tune 20.6 s
against 18.2 s. The 1,454-part Rebel Snowspeeder plans in 0.58 s, against 0.59 s.

## The pages

Booklets of three proof models with their steps taken out, made on the
desktop (`--model=… --booklet=…`, the GPU drawing, on Xvfb) and in the web
build on the preview (`tools/web/booklet_flow.mjs --model=…`), and read page
by page as a builder would.

918 Space Transport (92 parts), before: "Part 1" is a stand and a plate, one
step on a page of its own under a banner. "Part 2" starts on the next page,
and its banner came back on page 14 when the build went back to that tile.

![918 before, page 2](instructions/918-before-page2.webp)
![918 before, page 3](instructions/918-before-page3.webp)

After: one build, four steps to the first page, 25 steps where there were 29.

![918 after, page 2](instructions/918-after-page2.webp)

Callouts read as before: a figure built in its own box with an arrow to its
seat (918 step 5), and a long sub-assembly on framed pages of its own (6059
Knight's Stronghold's cart).

Then, reading the studs (2026-10-16), two more proof models, made the same
way on the desktop with main at 2789cd0 and with this change.

7636 Combine Harvester (372 parts), before: the harvester's first axle plate
is drawn in the air above the hay bales and the farmer of the sections before
it. Three of the 2 x 2 round plates its base stands on are steps of their
own, on the ground, and the base goes down at one end, then the other, then
across the middle.

![7636 before, page 4](instructions/7636-before-page4.webp)
![7636 before, page 7](instructions/7636-before-page7.webp)

After: the harvester begins on a stage of its own. One round plate is still
a step of its own; the next goes in in the step of the plate pressed onto
it, and the base grows from one end. 101 steps where there were 109.

![7636 after, page 4](instructions/7636-after-page4.webp)
![7636 after, page 5](instructions/7636-after-page5.webp)

Each of its first 40 pages can be built as drawn. What still reads badly:
the axle plate of step 3 hangs in the air beside the base until step 18
joins them. By the measure 75 of its 100 steps float a thing (61% before),
because the harvester stands on its wheels, which go on last, and the
measure holds only the model's first parts, the hay bales, to the table.

6718 Raindance Ridge (80 parts), before: the warrior is built in place, a
torso and two legs in step 12 and the hips that join them a step later, in
between.

![6718 before, page 8](instructions/6718-before-page8.webp)

After: he is a callout, built whole and put on, and so are the rider and the
horse. 17 steps where there were 28. By the measure, on its shuffled copy,
steps with a floating thing 25.0% to 0.0% and things put in under 24.7% to
8.3%.

![6718 after, page 7](instructions/6718-after-page7.webp)

## What is left

- **Order.** Ours reads what the file's shape says and not what its author
  chose among equal options. The order the file lists its sub-models in is
  that choice (LPub builds a step-less file's sub-models in it), and a
  person's own model lists them in the order they made them. Following it
  would be reading, not planning, and on these files it reads the answer, so
  it was not done here; it is the obvious next step for files that carry it.
- **Every step buildable.** On the held-out sample one step in seven still
  floats something by the probe's graph (14.9%), against one in thirty for
  authors, and 11.3% of things go in under one already there, against 0.8%.
  Both miss the 8% this work aimed at. Three things stand in the way:
  - **A model turned on its stand.** 76161's Batwing stands on its edge.
    Built in the world's frame, 1,692 of its 2,396 things go in under one
    already there, 29% of all such things in the sample; without it the
    sample is at 8.4%. Its author builds it flat and stands it up. A turned
    sub-model is built on the side up to half the model, and here the whole
    model is turned.
  - **Technic.** The 7 Technic files float a thing in 31.5% of steps (38.3%
    before), the other 93 in 13.2% (15.8%). Their parts are held by pins and
    axles, and this work read the studs.
  - **A vehicle that is not built first.** The measure holds only the model's
    first parts to the table. A body built before its wheels, which go on
    last as a set's do, floats until they do: 7636's harvester is 75 of its
    100 steps.

  The app's build check calls 21% of the parts our sampled steps add
  floating, as before (20.5% to 21.3%, within its noise), against 3% of the
  authors'.
- **Sub-assemblies.** Ours builds on the side sub-models of at most 60
  parts and under 30% of the model (`ASSEMBLY_MOST`), and a sub-model put on
  at an angle up to half the model: 54% of the authors' (from 40%).
  The rest are built in place as sections. Authors build a floor of a modular
  building apart and stack it; the booklet can show a long callout on pages
  of its own, so lifting the limit for a sub-model that holds together and
  goes on whole is open.
- **The author's steps as the booklet draws them** still build a big
  sub-model where it stands, before what it stands on (9.6% of steps float
  something on the held-out sample, from 11.4%, against 3.4% for the author's
  own build), because only small sub-models become callouts.

## Sources

[agrawala]: https://graphics.stanford.edu/papers/assembly_instructions/assembly.pdf
[mepnet]: https://arxiv.org/html/2207.12572
[apexmr]: https://arxiv.org/html/2503.15836
[gt-asp]: https://arxiv.org/abs/2210.05236
[patent]: https://patents.google.com/patent/US7979251B2/en
[omr-spec]: https://www.ldraw.org/article/593.html
