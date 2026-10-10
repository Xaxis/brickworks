# What it will take to build kits a LEGO designer would ship

The goal, in the owner's words: designs as good as a set LEGO would
actually release, with no architectural ceiling on size — a real set may
be four thousand pieces or more, so no target number.

This file exists because there wasn't one. Every ceiling so far was found
by measuring, lifted, and written down in `.claude/skills/verify/`, which
is the right place for *how to prove a thing works* and the wrong place
for *what to do next*. What follows is ranked by evidence, not by appeal.

## The product, end to end

A set is more than a model, so the goal is a chain, and each link is
judged on its own:

| | what a real set has | where it stands, 2026-10-09 |
|---|---|---|
| **the model** | ~180 shapes, ~23 colours at 1,200 parts; ~260 and ~28 at 2,400 | 113 and 16 at 1,329 parts; 121 and 13 at 2,438; the gap, below |
| **its parts** | named sub-assemblies, bag by bag | assemblies named by the design, kept as `.mpd` sub-models |
| **the booklet** | built a sub-assembly at a time, pictured close | built and framed by those assemblies; `--booklet` writes one |
| **the parts list** | element numbers you can order | CSV with element numbers; the `.mpd` imports into Rebrickable to buy |
| **any subject** | castles, cities, ships, vehicles | castle, fire station and space cruiser all hold; angled structure is the weak joint |

The model is the weakest link by a distance, which is why the levers
below are all about it. When it is within reach of a real set, the next
link to look at is the booklet's pictures — whether a person can follow
350 of them on a table — measured the same way, by building from one.

## Where it stands

The castle brief — "a medieval castle with a gatehouse, four corner
towers and a long curtain wall between them" — run again as each lever
landed, 2026-10-08/09. Every run held together. Counted with
`tools/texture.py model.ldr --brief "..."`, after the run ends:

| run | what was new | parts | shapes | colours | used once or twice | main colour | big pieces |
|---|---|---|---|---|---|---|---|
| 4 | the look carries what the check measured | 1,828 | 30 | 8 | — | — | — |
| 8 | thin passes sent back once | 1,895 | 53 | 13 | — | 49% | 51% |
| 14 | told the 100 parts castle sets use most | 1,120 | 71 | 12 | 21 | 51% | 56% |
| 16 | the one-off count in the send-back | 1,159 | 95 | 10 | 54 | 53% | 39% |
| 18 | sent back on the model's one-off tail | 1,077 | 78 | 10 | 41 | 55% | 46% |
| **19** | **and on its colour tail** | **1,329** | **113** | **16** | **65** | **37%** | 46% |
| 21 | walls in short bricks, bonded | 1,650 | 78 | 10 | 30 | 47% | **17%** |
| **24** | **masonry, a second grey, windows, real-set techniques** | **2,438** | **121** | 13 | **83** | 53% | 15% |
| | *a real set of ~1,300 parts* | — | *180* | *23* | *86* | *28%* | *10%* |
| | *a real set of ~2,400 parts* | — | *262* | *28* | *105* | *30%* | *9%* |

"Big pieces" is the share as big as a 2 x 4 brick; see lever 1.

Run 24 is on the landing page and ships as `models/castle.ldr`: the first
castle whose walls read as a real set's, and the most shapes and one-off
pieces of any. **Against its own size it is still thin — 121 shapes
where a real set of 2,400 parts has 262, 13 colours against 28** — so the
model grew faster than it varied; run 19 sat closer to its size's norm
(113 against 180). Previous project best was 456 parts; scale is not the
constraint, and variety at scale is.

Two cautions every reading of this table needs. **A run varies a lot**:
the first structure alone came out 449 to 1,552 parts across runs of one
brief, so one run is a direction, not a result. **And the count is not
the picture**: runs 16 and 18 beat run 14 on every number and read
plainer — see the first lever below.

## Solved, so do not re-solve

- **Saying a large model.** `repeat_section`: 250 placements described,
  10,000 bricks built. The lattice holds 50,000 in 180 MB.
- **Checking one.** ~2 ms a brick; `Stability.check` 0.08 ms a brick.
- **Which part to reach for.** `in_sets` ranks search by real use; 267
  kinds of set say what a castle is built from, by lift, and (`common`)
  what most of its sets use at all, and (`accents`) what they use one or
  two of — counted in sets, not lots.
- **Judging a model against real sets fairly.** The size norms are over
  models only (`rebrickable.NOT_A_MODEL`: no mosaics, bulk tubs, Duplo)
  and carry medians and tails for shapes, lots, colours, the largest lot,
  shapes used once or twice, and main-colour share.
- **Detailing, assembly by assembly.** A design names its assemblies; after
  the whole look each comes back close up, measured against a real set its
  own size, told what the passes before it brought and which of the kind's
  parts and accents the model lacks.
- **Sending a pass back** once, when it says it is done and the assembly
  is thin, or the whole model is on the tail of real sets for one-off
  pieces or for one colour. The one mechanism that reliably moved a run:
  1.1-1.5x on shapes without it, 2-4x with it.
- **Cost and the shared machine.** The conversation is cached (a castle is
  $5-10); design runs render in software; the suite and builds queue on
  the machine's `heavy` pool.
- **Seeing what a model is built from.** Bricks are drawn with the seam
  a real brick shows where it meets the next (`plastic_body`), so
  courses, bonds and plate outlines read in the app, the booklet and
  every picture, on the desktop and the web renderer both.
- **Angled sections that miss** are told the sideways offset that meets;
  a design that holds but for a few floating bricks keeps what holds; a
  failure is written to `user://failed_design.json`.

## What is next, ranked by evidence

1. **The big read: pieces the size a real set uses.** Measured
   2026-10-09 over every model set in the inventories: **a real set is a
   median 10% pieces as big as a 2 x 4 brick, at every size from 350
   parts up, and more than about 20% is coarser than all but one in
   twenty.** Modern castle sets: 10%, 4-16%. Every castle built here was
   39-56%, run 19 46%: curtain walls in 2 x 10 bricks, because `fill`
   laid the longest brick that fitted, and slabs are what the pictures
   show. It is the largest gap found against real sets, and it is what
   the eye reads as plain. `fill` now lays a real set's sizes in a
   running bond; the look and the send-back fire on the tail.
   **Run 21: 17%, inside the range of real sets** — and the pictures
   showed nothing, because the renderer drew no seam between two bricks
   of one colour: a wall of forty and a wall of four were the same slab.
   It draws them now (see Solved), and run 21's walls read as masonry
   where run 19's read as planks. What did not follow: 78 shapes and 10
   colours against run 19's 113 and 16, and 349 of one 2 x 3 brick,
   because a wall two studs thick is laid in 2 x 3s. One run; the
   monotony moved rather than went. **Next: what the short bricks are**
   — a real castle lays some of them as masonry bricks (Lion Knights'
   Castle: 281 of the 1 x 2) and some in a second grey, and almost
   never uses the 4 x 4 corner-round brick every castle here built its
   towers from (15 of 54 modern castle sets, at most 8 each).
2. **Proportion and composition.** Five real castles and fourteen modular
   buildings from LDraw's model repository, measured with
   `tools/layout.py`: a real castle's towers stand about three times its
   walls (10176, 6080, 6085: 2.8-3.3) and it is 0.34-0.74 as tall as it
   is wide; every castle here is 1.3-1.9 and 0.21-0.35 — low and
   sprawling. Modular buildings stand 28-43 bricks; both fire stations
   here 17-20. A direction, not yet a norm: nineteen sets. The repository
   serves sets one file at a time now (the zip is gone); the URL is in
   the tool.
3. **Generalise.** The fire station (run 20) with every lever came to
   737 parts and 67 shapes against the first station's 62 — the levers
   that took the castle from 71 to 113 did not carry. The difference is
   passes, not what a pass does: the castle named ten assemblies and
   gained about 8 shapes a pass, the station four of ~250 parts and
   gained about 13 a pass. A big assembly gets the turns of a small one.
   Asked for assemblies of about a hundred parts (run 22), it named five
   instead of four — one of them still 424 parts — started far richer
   (42 shapes at the first look against 16) and ended in the same place:
   797 parts, 70 shapes. Three stations, 62, 67, 70: **the station had a
   plateau, and what it was short of is what a building is made of** —
   its windows were 42 aeroplane windows in white surrounds that read as
   blanks. Given a `window in a wall` technique (a 60593 frame, the bond
   laid short past it, an arch over it), run 23 looked it up in its
   first minute and came to **1,003 parts, 87 shapes, 48 used once or
   twice** — 16 of that frame, six 1x2x2s, two 1x4x3s, three door
   frames, arched lintels — and reads as a building. One run, well
   outside the three before it. Its frames have no glass: the checker
   reads a pane in its frame as an overlap (next). A cruiser run is
   still owed.
4. **Worked examples for what real sets are made of.** Run 23 is the
   evidence: a part list named the window frames for every station run
   and none used them; one technique did, and the station gained 17
   shapes. A door in its frame, a roof with a ridge, a balcony and its
   railing, a lamp post, a tree, a market stall are each a construction
   real sets repeat. Which ones is in the model repository, whose real
   sets name their sub-models. Counted over the 253 downloaded
   2026-10-09 (models whose sub-model names say it): **roof 46, door 37,
   seat 27, lamp 22, window 21, tree 20**, then furniture — table 14,
   bed 10, chair 8, bench 8, desk 7 — plant 9, sign 7. Doors and glass
   are in (inserts seated as real sets seat them). Nine more are real
   sets' own sub-models — lamp post, tree, bed, bench, armchair, table,
   planter, chimney, fence — opened in the app, read back as placements
   and kept where the checker passes them: 96 of 162 candidates did.
   **The 66 it refused are real LEGO constructions** — 34 overlaps,
   mostly clips on bars, 32 sideways parts read as floating — so they
   are a ready corpus of the checker's false positives. The floating
   ones were mostly one rule: clutch held only the part a stud reaches
   into, not the part it belongs to, so a plate pressed up under an
   overhang floated. Clutch holds both ways now — and support is a walk
   out from the ground, because counting it both ways and only looking
   one part down let a stack in mid-air hold itself up (the suite caught
   that). Measured on the same 162, grounded exactly: the old rule passed
   107, this one 110 — eight hung constructions newly pass, and the five
   it newly refuses are upside-down sub-models hanging from a ceiling
   that is not in them, which the old rule passed only because each of
   their parts held another. **The overlaps are the parts pipeline: it records no bar
   connector anywhere** — not on a handle, a minifig arm's clip or a
   round brick's hollow stud — though the joint matcher has a rule
   waiting for bars in clips. Recognising bars (cylinders 4 LDU in
   radius) and hollow studs in `tools/ldraw/connectivity.py`, then a
   sub-build of the parts that gain them, is the next unit: clips on
   bars are how a real set hangs a lantern, a flag, a tool or a railing.
   Roofs (32 of 55 passed) after that.
5. **The texture still missing, 113 to 180.** The ordinary parts are
   mostly used (54 of the castle's top 100). What is left is where parts
   go together: which parts real sets put beside which — the
   co-occurrence data, downloaded and unread.
6. **Angled structure.** Two of three cruiser runs failed on pods on
   pylons; the third laid them flush. The tools now say where a section
   meets, but no run has yet built a raked pylon that held.
7. **The booklet's pictures.** A castle's booklet enters its parts 18-30
   times because walls stand on a shared base; whether a person can
   follow 250 pages is the next thing to measure, by building from one.

## How the levers were found

Each line is a run of the castle brief unless it says otherwise.

- **Per-assembly detailing** (runs 5-6): 1.2-1.5x on shapes, not the 2x
  the roadmap set as its bar. Siblings converged — four towers given "the
  same crown, so they match" — and each pass made one change and stopped.
- **Siblings told what the others got** (run 7): unproven; its tower
  passes found every tower built inside-out and spent themselves turning
  the corner bricks round. A real fault the close look caught.
- **Thin passes sent back once** (runs 8, 9; fire station): 23 to 53, 34
  to 58, and on a fire station 39 to 62 — the first design out of the thin
  tail of real sets. It is not a castle trick.
- **The ordinary parts** (runs 10, 14): the best castle had used 24 of the
  40 parts castle sets use most; told them, 37 of 40, then 54 of 100.
- **Where the rest of the gap was**: a real set of 1,100 parts has some 85
  shapes used once or twice; run 14 had 21. Told the count in the long
  message (run 15): 13, nothing moved. In the short send-back (run 16): 54.
  Run 17's passes were never thin, so the send-back never ran: 17. Sent
  back on the whole model's one-off tail too (run 18): the count rose with
  every pass, 7, 13, 18, 25, 34, 40.
- **Colour** (run 19): every castle had been 49-55% one colour against a
  real castle set's 31%, and 72-86% in two colours against 49%. Sent back
  on that tail: 37%, 60%, 16 colours, and the best picture yet.
- **The count is not the picture**: runs 16 and 18 measured better than
  run 14 and read plainer, their one-off pieces small things on tower
  tops. Hence lever 1.
- *Refuted or not in the data:* minifigures, stickers and prints are not
  the gap (3%); a filter for kinds that do not suit the subject (kinds
  overlap as much for space and tower as for space and cruiser); a booklet
  planner that goes to the part a stalled one waits on (19 entries to 18);
  asking for assemblies of about a hundred parts (station run 22: five
  passes for four, 70 shapes for 67).
- **What a building is made of** (station run 23): a window technique
  took the station from a plateau of 62-70 shapes to 87, and one-off
  pieces from ~30 to 48. The kind's parts had named the frames all
  along; a list of part numbers did not get them used, a worked example
  did.
- **Piece size** (run 21): `fill` in a real set's sizes on a running bond
  took big pieces from 46% to 17%, and the seams it needed to be seen
  were then drawn. Shapes and colours fell in the same run (78, 10).
- **The cruiser** (runs 11-13): failed twice on angled pylons, ending with
  nothing kept — the second with 639 of 641 bricks holding. With the fixes
  in Solved it held: 619 parts, 49 shapes. "Engine pods" had brought
  fire-engine ladders; kinds are taken in the order the brief names them.
- **Cost**: run 6 spent $9.67, $8 of it the conversation sent fresh; cached,
  run 7 spent $3.99 on a longer run.

## The other half: a set is also how it is built

A set LEGO would ship is the model, a parts list and a booklet you can
follow on a table. The first two hold at any size. The booklet does not
yet, measured on run 8's castle, 2026-10-09: `Instructions.plan` orders
its 1,895 parts into **281 steps in 3.3 s, none of them out of order**
— and that is the problem. The order is course by course across the
whole model, so consecutive steps jump a median of **12.5 studs and up
to 61** across a castle 72 studs wide, and every step is photographed
framed on all of it: eight new bricks somewhere in a picture of 1,895.

A real set is built the other way: bag 1 is the gatehouse, built to the
top, then a tower, and the pictures follow the part being built. The
design now names exactly those parts. **Needs: the assemblies to travel
with the model** (LDraw's own way is a submodel per sub-assembly, an
`.mpd`, which Studio, LeoCAD and LPub all read), **the planner to finish
one before starting the next, and each section of the booklet framed on
its own assembly.** Judged by the same numbers: the jump between steps
and how much of each picture the new bricks fill.

*Both halves done, 2026-10-09.* The planner builds a model wider than 24
studs a region at a time — tiles of its plan, borrowing only the bricks a
region is directly waiting on — and the booklet frames each region on its
own: the castle's steps now jump a median of **6.2 studs (90th 12, max
35)**, in 350 steps across 12 parts. Borrowing deeper than one brick was
tried and measured as one part swallowing 1,175 of 1,483 steps. And the
assemblies the design names now travel with the model, as an `.mpd` of
sub-models, and the booklet builds by them: the cruiser's builds its
landing legs, hull, port pod, bridge tower and starboard pod, each
entered once and named, in 117 steps where tiles took 171.

## Beyond variety: beauty (2026-10-10)

The owner had Claude build the Tower of Orthanc from claude.ai, through the
connector. It held together and was "okay", and **"still ultimately sucked":
too symmetric, functional square bricks studs-up, no creative use of parts.**
Every lever above measures variety; none measures style. What real sets and
good builders do that this does not, to be measured on the official models
(their transforms say it) before anything is told to the designer: parts on
their sides and upside down (SNOT), parts at angles, curves where a box
would do, texture, organic shapes for rock and growth, and asymmetry where
the subject is not symmetric. `tools/style.py` is that measure; the norms go
into the check and `review_model` the way `_variety`'s did, and the guidance
learns the techniques with worked examples from real sets (`show_technique`,
`tools/omr.py harvest`). Judged by building Orthanc again against 10237;
the first one that is master level replaces the castle on the landing page.

The same brief each time, built by Claude Code (Opus 5.5) on the owner's
plan over MCP (`--ask-claude-code`), so the way the owner builds from
claude.ai; measured by `tools/style.py --against fantasy` (16 real fantasy
sets: sideways 19%, angled 27%, plain 28%, mirrored 31%, 109 shapes, 23
colours at the median):

| run | what was new | parts | sideways | angled | plain | mirrored | shapes | colours |
|---|---|---|---|---|---|---|---|---|
| 1 | review_model; old guidance | 1,648 | 0% | 0% | 57% | 88% | 34 | 8 |
| 2 | the guidance teaches craft, in words | 1,674 | 0% | 0% | 77% | 71% | 40 | 10 |
| 3 | style measured in every check; `rock` | 2,769 | 0% | 0% | 51% | 70% | 36 | 4 |
| 4 | `studs_out` offered | 2,909 | 0% | 0% | 76% | 65% | 34 | 7 |
| 5 | stone-wall recipe with `sideways` | 2,355 | 0% | **26%** | 70% | 62% | 37 | 5 |
| 6 | turned parts place 19x faster | 2,559 | 0% | 0% | 83% | 65% | 43 | 6 |
| 7 | `restyle_model`, named in the advice | 2,390 | **14%** | 0% | 63% | 60% | 33 | 6 |
| 8 | `prism` | 1,463 | 0% | **31%** | 94% | 87% | 36 | 10 |
| 9 | prism faces take masonry and sideways | 2,869 | **13%** | 0% | 64% | 58% | 41 | 4 |

**Words moved nothing; measurement moved symmetry and plainness a little;
a technique offered as its own pattern went unused.** What designs take up
is what is already in their habits — run 3 used `rock` because the base
was the thing it was building, and every run builds walls with `fill` by
the guidance's recipes. So the next lever puts the technique inside the
recipe: `fill`'s `sideways` share, in the stone-wall recipe. Run 4 is the
first whose silhouette reads as Orthanc (four piers with clefts, horns
flaring at the top, boulders and a moat); none is close to 10237 in craft.
Also found by these runs: a check from outside replaced the standing
model, a finished session spun a core and held the GPU lease for an hour,
and the renderer draws black as navy and dark grey as near white.

Runs 5-7. Run 5 built octagonal piers from ~150 turned sections — 26%
angled, the fantasy median — and finished blind: turned parts took three
minutes to place on the app's one thread and every look timed out (fixed:
19x faster, same cells). Run 6 went back to plain walls, 978 1x2 bricks.
**Run 7 used the finishing pass when it was one call that edits what
stands** ("applying the detail pass"): 14% sideways, the first designed
run inside the real range. So the rule holds a third time: a technique is
taken up when it is one call shaped like what the design is already doing
— a wall recipe, a base, an edit. Next on that rule: a many-sided shaft as
one pattern (`prism`), since run 5's silhouette was the best and cost it
everything else. Shapes (33-47 against 109) and colours (4-8 against 23)
have not moved in any run; the real set has rooms inside, and these are
solid shells.

Runs 8-9. Run 8 used `prism` and could not finish its faces (the finishing
pass skips sections and two-wide bricks: fixed, prism faces take masonry
and sideways themselves). Run 9 used the finishing pass unprompted for the
second run running — 13% sideways — and no prism. **The two craft numbers
have each reached the real range, in different runs; no run has both, and
variety has not moved in nine.** The style advice now names both calls
when its numbers want them. Run 8 also ended silently at 46 minutes: the
desktop app quits on Escape and on closing its window, and the run's
window was on the owner's screen — runs go off-screen now
(`tools/claude_run.sh`).

## Long term: custom elements

A LEGO designer can ask for a new element, or a change to one. Brickworks
should let its designer do the same: a part editor that makes real LDraw
geometry, keeps to the system's dimensions and moulding rules (1.6 mm walls,
4.8 mm studs, the clutch), gives the part its connection points, and puts it
in the catalogue, the checks and the design loop. How LEGO's own element
design works is to be found out, not assumed, before this is planned.

## How progress is judged

Rerun a brief and measure the model, never read the diff.
`tools/claude_run.sh NAME` builds the Orthanc brief (or `--brief`) with the
Claude Code on this machine over MCP — the way the owner builds from
claude.ai — off-screen on its own port, and prints `tools/style.py` against
real fantasy sets (or `--against`). `tools/design.py`
drives the real assistant and prints what it spent; `tools/texture.py`
counts the saved `.ldr` against `catalogue.json`'s `set_norms` and the
brief's kinds. A run's progress lines say what each assembly pass came
to. Two measurements have been wrong by being taken too early: `--out` is
rewritten on every build, so read the file after the run *ends*, and a
wall clock on a shared machine measures the machine.
