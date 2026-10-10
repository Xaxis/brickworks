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
| **the model** | ~180 shapes, ~23 colours at 1,200 parts | 113 shapes, 16 colours; the gap, below |
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
| | *a real set of ~1,300 parts* | — | *180* | *23* | *86* | *28%* | *10%* |

"Big pieces" is the share as big as a 2 x 4 brick; see lever 1.

Run 19 is on the landing page and ships as `models/castle.ldr`. **The gap
is now 113 shapes against 180, 16 colours against 23**, with the thin and
grey tails of real sets both cleared. Previous project best was 456
parts; scale is not the constraint.

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
   797 parts, 70 shapes. Three stations, 62, 67, 70: **the station has a
   plateau, and what it is short of is what a building is made of** —
   its windows are 42 aeroplane windows in white surrounds that read as
   blanks. Real windows are a frame, glass, a sill and a lintel, and no
   technique says so. A cruiser run is still owed.
4. **The texture still missing, 113 to 180.** The ordinary parts are
   mostly used (54 of the castle's top 100). What is left is where parts
   go together: which parts real sets put beside which — the
   co-occurrence data, downloaded and unread.
5. **Angled structure.** Two of three cruiser runs failed on pods on
   pylons; the third laid them flush. The tools now say where a section
   meets, but no run has yet built a raked pylon that held.
6. **The booklet's pictures.** A castle's booklet enters its parts 18-30
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

## How progress is judged

Rerun a brief and measure the model, never read the diff. `tools/design.py`
drives the real assistant and prints what it spent; `tools/texture.py`
counts the saved `.ldr` against `catalogue.json`'s `set_norms` and the
brief's kinds. A run's progress lines say what each assembly pass came
to. Two measurements have been wrong by being taken too early: `--out` is
rewritten on every build, so read the file after the run *ends*, and a
wall clock on a shared machine measures the machine.
