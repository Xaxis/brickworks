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
| **any subject** | castles, cities, ships, vehicles | castle, fire station and space cruiser all hold; round things are round since 2026-10-11 (a Falcon Heavy reads as one); a car's body is still stacked square |

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
   meets, but no run has yet built a raked pylon that held. Since
   2026-10-10 a lean must turn on a joint, and `hinge: true` on a section
   is that joint in one line: the hinge brick put in, the pin found, the
   section written as if square on a 1 x 2 plate. Not yet tried by a run.
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
| 10 | open prisms, rooms inside; both calls named | 2,838 | 0% | 0% | 80% | 57% | 34 | 6 |
| 11 | run 10 again, the MCP port fixed | 4,437 | **16%** | 9% | 62% | 56% | 35 | 5 |
| 12 | minifigures, 59 worked examples, dressing gives way, true lighting | 4,167 | **18%** | 0.3% | **38%** | 42% | **46** | 6 |
| 13 | `add_rooms`, named in the recipes and the variety advice | 3,120 | 1.1% | **13%** | 61% | 36% | **80** | **22** |
| 14 | prism dressed by default, round joints, rebuilt catalogue | 4,748 | 13% | 0% | 54% | **28%** | 70 | 16 |
| 15 | clustered piers on `prism`, in the recipe and the advice | 3,281 | 2.5% | **30%** | 69% | **27%** | 56 | 14 |
| 16 | horns capped square, any opening the whole back, the finish reaches a cluster, no animation off-screen | 3,539 | **14%** | **50%** | 58% | 31% | 53 | 17 |
| 17 | posts behind open corners, piers keep their sides, dressing in the wall's colour, each assembly handed back, lit windows | 8,547 | **16%** | **31%** | 58% | **23%** | 65 | 15 |
| 18 | any core's corners posted and its back three faces, a great door, horns that rise to points | 8,438 | 13% | 60% | 58% | 38% | 61 | 13 |

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

Run 10 does not count. Both its submits had "the palantír" in a note,
and the app's MCP port read a request's body in characters against a
Content-Length in bytes, so one accented letter left it a byte short for
ever: the app never saw the call and the session waited out the ten-minute
tool timeout. It built through `check_design` and `edit_model` instead, and
none of the lever reached the model (fixed: counted in bytes, with a probe
that sends an accent).

Run 11, the same lever with the port fixed, is the first with sideways in
the real range and angles in the same model (16% and 9%), and the first to
detail unprompted from the review: 22 lit windows, braziers at the door,
forge fires on the rock. Its prism core's sideways tiles hit the piers and it
dropped the dressing from the whole core to get past them (fixed: dressing
gives way and the check says so), and after a resubmit it edited by brick
numbers it had read before, which a resubmit renumbered (fixed: a resubmit
keeps every unchanged brick's number). Judged by eye it is still a box with
horns on a pale wedding-cake rock: the rock is light grey banded in white,
and the shaft's faces are flat. Variety has not moved in eleven runs; what
moves it in real sets is the interior, the details and the figures.

Run 12 had the minifigure builder and the 59 worked examples, and used both
unprompted: Saruman and Gandalf face each other on the summit, Uruk-hai at the
door, the shaft ribbed and tied with plate rings, glowing slit windows up its
grooves, horns leaning out on hinged sections, rock outcrops round a paved
court. Plain fell to 38% (the lowest of twelve, against a median of 28%),
curve 22% and texture 20% are in or past the real range, sideways 18%, and
shapes reached 46, the most yet. Angled fell to 0.3%: no prism this run. It is
still a square shaft where Orthanc is a faceted spire, and six colours where a
set has twenty-three; and it saved itself, by name, with the app's own models.

The worked examples, 2026-10-10. The runs say a technique is taken up
when it is shaped like what the design is doing, and run 23 said a
worked example moves a design where words do not; the library had
twenty, mostly furniture and basics. It has 59 now, 39 more as LEGO built
them in real castle, fantasy and modular sets — rough and weathered stone
faces, corbels and an oversail, a turret spire, rock, ivy, a cobbled
path, a bookcase, a fireplace, an anvil, lanterns — found by
`tools/omr.py clusters` inside big models as well as by sub-model name,
and listed by what they are for. Laid out as one model the library is
18% sideways (fantasy median 9%) and 31% plain, where the twenty were 4%
and 46%. **Angled is still 0%, and the library is not why**: every way
real sets turn a wall — a 2x2 turntable (Cafe Corner's whole corner;
13 turned assemblies in six sets), hinge bricks, hinge plates, clips on
bars — is refused by the checker as two parts in one place, so no honest angled
example passes. That checker work (turntables and bars in
`tools/ldraw/connectivity.py` and `Assistant.NESTS`) comes before an
angled example can. Not yet measured on an Orthanc run.

Run 14, with everything at once: the best form of the fourteen by eye —
four piers clustered round a core and rising into horns, stone faces with
lit windows, a door and stair on a paved court with Uruk-hai at it, rock
outcrops, and seven furnished storeys behind a slot in the back, Saruman
with the palantír among them. Sideways 13% and texture 15% came back, and
symmetry fell to 28%, the most natural yet. But it built no prism and no
turntable, so nothing is at an angle (0%), the piers are square where
Orthanc's are faceted, and the slot shows far less of the inside than run
13's open back did; shapes 70 and colours 16 sit between runs 12 and 13.
The levers left: faceted piers as one call (a prism per pier), and an
opening as wide as the real set's.

Round joints, 2026-10-10. A clip on a bar, a bar in a hollow stud, a
hinge's pin in its eye and a turntable's top on its base are one joint,
something round in something round that fits it, and the parts pipeline
now records it: each part's shafts and bores, read off the cylinders it
is drawn with and which way their winding faces. The checker forgives an
overlap between a shaft and a coaxial bore of its size only inside the
bore, so the same parts meeting anywhere else still collide
(`Joints.rounds`, `src/dev/joints_probe.gd`). Over the same 880 real
sub-models: 564 pass → 617, refused for overlaps 232 → 182, none newly
refused; hollow studs 20 of 75 now pass, clips 6 of 36, bars and axles
through holes 6 of 57, hinges 3 of 10, panes 5 of 25. The library has its
first angled example, Cafe Corner's corner entrance steps on their
turntable at 45 degrees (`corner on a turntable`). Still refused: handles
and gates whose cover fills the opening a clip passes through, 75937 (its
cover is its bounding box), and a long tail of covers. The catalogue was rebuilt with the rounds the same day (29,587 parts; the
16,360 meshes that changed uploaded for the web), so the checker forgives
them everywhere. Not yet measured on an Orthanc run.

Rooms inside, as one call, 2026-10-10. Twelve runs built solid shells or
bare open backs though the guidance asked for rooms in words, and variety
(shapes, colours) moved least of all. `add_rooms` lays a floor at each
storey of a building that stands and furnishes each room by its kind —
library, study, bedchamber, hall, throne room, forge, armoury, dungeon,
kitchen, lookout, palantír room — from the worked examples, against the
walls and facing in, with a stair or a ladder where asked. An edit of what
stands, like the finishing pass and the figures (the two calls runs took up
unprompted), named in the recipes and in the variety advice. On an
octagonal prism open at the back, a dungeon, a forge, a library and a study
take the model from 5 shapes and 2 colours to 56 and 23. On run 12's own
shaft it finds the inside and furnishes four floors, and says none of it
shows: that shaft was closed all round.

Run 13 used it unprompted, three times: straight after standing an
open-backed prism ("Now the floors inside, from the cellars up to the
summit"), again after widening the shaft, and once more to put back a study
floor the first version had dropped (fixed: floors hold as laid). Then it
peopled the rooms — Gríma in the study, an orc smith in the forge, a
skeleton in the dungeon — eight storeys from a dungeon to the palantír's
carpet under the horns. **Shapes 80 and colours 22, both records: colours
at the fantasy median (23) for the first time, from six.** Angled 13% from
the prism. What fell is the finish: the faces were prism sections, which the
finishing pass cannot reach ("restyle only touched 5 bricks"), and the
prism was laid without its own masonry and sideways, so sideways 1% and
plain 61%; it ran out of its 90 minutes placing figures. Since: the prism dresses its faces by default (masonry 0.25, sideways
0.15), and the catalogue is rebuilt with the rounds.

Clustered piers, as one call, 2026-10-10. Run 14 had the form and built it
square by hand; run 5 built its piers octagonal by hand and spent the run on
it. A prism now takes `"piers"`: `{"count": 4, "courses": 38}` on an
eight-sided core stands four eight-sided piers round it, each a prism of its
own built against the core, with deep clefts between them, caps the core with
a summit two plates thick — what ties walls at different angles into one
piece, since they only rest on one another — and carries the piers past it as
horns. With `open`, the piers at the back drop every face that looks back or
across the opening, so the rooms show across the core's whole width. The
guidance's prism line is that call, and the style advice names it for a tower
with nothing at an angle. As laid it passes the check with nothing given way,
in one piece, 42% at an angle, and add_rooms lays and furnishes five floors
under its summit, open to the back (`patterns_probe`). The pictures caught
two things the check did not: six-sided piers on an octagon meet it corner
first, and the core's faces had to stop short, leaving slits down every cleft
that the rooms showed through (the piers now take the core's sides and are
built against it whole); and a two-thick face of a small pier has a groove at
each corner nearly as wide as itself, so the first piers read as bundles of
sticks (a face's outer row now runs on into its corner groove). Still open: a
prism face's inner corner stops short of its neighbour's, so a thin channel
up one corner of each face is see-through straight on, on a plain prism too.

Run 15 called the cluster in its first build — an eight-sided core of radius
7, open 2, and four six-sided piers of radius 4.5 set 7 out, 48 courses to
the core's 40 — and add_rooms straight after it, six storeys from a dungeon
to the palantír room. **30% at an angle, past the fantasy median, the first
time in a model that also has its form** (run 5's 26% finished blind), and
symmetry 27%, the most natural yet. By eye the shaft is Orthanc's: four
faceted piers, deep clefts, lit windows, a door and stair on a stepped plinth
among rock outcrops, Gandalf on the summit. Then it took the horns down:
"Pier tops are built at 45°, so grid parts can't clip on. I'm rebuilding the
four horns myself on the flat summit instead" — square spires of slopes with
bars for points. It chose its own numbers rather than the recipe's, and
"open": 2 on an octagon opens one back face and one back pier, so the rooms
are behind a slot again. The finish fell: sideways 2.5% and plain 69%,
because what it built square round the cluster is plain and the finishing
pass cannot reach a section; shapes 56 and colours 14 are below runs 13 and
14. The levers left: horns that end in something a square part sits on, an
opening that stays wide whatever "open" says when there are piers, and the
dressing on what a design builds square around a cluster.

On their studs, 2026-10-10. The owner saw the spires and points of a tower
of Orthanc not sitting on their studs, on a model built over MCP. Two causes,
both the engine's. A placement's corner was its cover's, and a part drawn
inside its footprint — a 4 x 4 wing's cut edge at -38 of -40, a turntable's
top 36 across a 2 x 2, a flag's narrow clip, plant leaves — stood 2 to 4 LDU
off the studs below at whole-stud coordinates: 24 wing tips on that tower,
the castle's six flags, the house's four plants, while the wing patterns had
meant the footprint all along. The corner is now the footprint's, read off
the part's own studs (`Assistant._footprint_start`); 15 worked examples were
rewritten to stay put, most to cleaner numbers (1.1 → 1, -0.9 → -1), three
more moved whole onto the grid, and
`src/dev/reseat.gd` moves a part only where undoing exactly that error puts
it on its studs. And a section leaning out was held by touching: run 12's horn
tips sat at a slant on the studs below, gripping none. A section turned about
x or z now has to turn on a joint along its axis or it is "leaning on
nothing"; a hinge's halves, turned, graze by less than a cell and are
forgiven that, and `leaning on a hinge` (6085's gatehouse flag on 3937/3938)
is the worked answer with the pin already found. And a part a fraction of a
stud off the studs below is a fault now, not advice: as advice it was passed
over (two round plates on the owner's second tower stood a tenth off with the
note beside them); over the 61 worked examples it fired only on two horns,
which have no stud grid and are no longer judged by one. Still open: a plate
half a stud off on a plain plate, with no jumper under it, is passed. A check
by sockets found it, and also 72 plain parts in 65 real sets that do grip — a
1 x 2 crossing a jumper's one stud among them — so it needs a socket model
that tells a 1 x N's post from a 2 x N's tube before it can refuse anything.
Closed 2026-10-11: a part half a stud off is asked where the studs under it
went (`_underside`), and refused when they stand against its walls; on a
jumper it passes. Posts count, since they fit a hollow stud and a jumper's is
hollow. Over the 328 fetched sets it refuses 31 of 2,828 half-stud seats,
none on a jumper, and in every one the set file has the part's own plastic
inside a stud — a sub-assembly or a part typed half a stud out
(`src/dev/half_studs_in_sets.gd` checks each against the part's mesh).

Run 15's three levers, 2026-10-11. **Horns that end square**: each horn of a
cluster is capped two plates thick over its own outline at y + 3 x the piers'
courses + 2, square to the grid, and carries a point on the cap — a 4 x 4
course where there is room, stepped in by four corner slopes, two 2 x 2
bricks, a 2 x 2 pyramid (3688), a cone and a black bar — with the cap's ledge
sloped up to it as the rock faces its ledges. The point's first course is two
2 x 4 bricks on the cap's studs and the whole passes the check, so a square
part sits on every horn; a design that wants its own takes the point off and
builds on the cap. What 10237 builds its horns from was not found: the reviews
praise the four spires and name no parts. **An opening that stays wide**: with
piers, any `open` opens the core's whole back (three faces of an octagon); on
run 15's own cluster with `"open": 2`, every column across the core's inside
is now open from behind to its middle, where 7 of 10 were. **The finish on a
cluster**: `restyle_model` works on bricks in sections turned about y, in the
section's own coordinates and only on a face's outside, and lays an open
two-wide brick as two rows with the outer one finished. Run 15's own calls,
replayed in order: its restyle went from 4 bricks to 172, and the model from
2.5% to 9.1% sideways and 69% to 60% plain.

Replaying them found where run 15's hour went. Every submit and every edit
starts the window's assembly animation, which plans build steps for the whole
model and shows it a step at a time, each step walking every brick; off-screen
and nobody watching, on that 3,000-part tower, a frame took 13 s while it
played. A look took 130-220 s, `add_rooms` 159 s, a restyle 249 s. An app
driven from the command line skips it now: 0.3 s, 12 s and 12 s, and seven
of run 15's calls replayed went from 19 minutes to 31 seconds on the same busy
machine.

Run 16, on everything above: the cluster in its first build (an octagonal core
of radius 7 and 36 courses, four six-sided piers of radius 5 set 8 out, 43
courses, `"open": 3`, `"sideways": 0.2`), `add_rooms` straight after (a
dungeon, a forge, a library, Saruman's chamber and the palantír room), seven
figures, a front portal with braziers and an Uruk-hai at it, and the
finishing pass over the whole tower (208 bricks: 149 turned out, 59 stone,
dressed in grey). It never touched the horns, and it finished in **585 s
against run 15's 3,798**. **Sideways 14% and angled 50% in one model**: both
in the real range at once for the first time in sixteen runs (run 14 had the
one, 15 the other), angled the most yet, texture 15%, plain 58% (13: 61%, 14:
54%, 15: 69%), symmetry 31% at the fantasy median. By eye it is Orthanc's
shape with four capped black spires, its back open across the core onto five
furnished floors with figures in them. It is not yet the homepage: shapes 53
and colours 17 are below runs 13-15's 80, 70 and 56 shapes, because it
reviewed one of its three assemblies and stopped at ten minutes; the grey
dressing on black faces reads as polka dots where 10237 is black on black; the
ground is a flat grey plate with four small crags where run 15 had a ring of
outcrops; there are no windows; and daylight shows through the tower. That
last one is measured: on the guidance's own cluster, closed, no horizontal
sightline at mid height passes through; open at the back, 7 pass straight from
the front through the thin channel at each prism face's inner corner (still
open since "Clustered piers"), which used to lead into a dark inside. Run 16's
six-sided piers add their own: 7 sightlines each side from the front corners
even with the back closed, 0 with eight-sided piers (the default both runs
overrode). Pictures: `shots/runs/orthanc_16_*.png` in its worktree. The levers
left, by what they cost the picture: inner corners of a prism face that meet
(or a post behind each), so an open tower is not see-through; the detail
passes a run skips now that each call takes seconds; dressing in the face's
own colour on a dark tower; and the ground.

Run 16's levers, 2026-10-11. **An open tower that is not see-through.**
`src/dev/daylight_probe.gd` measures it: each part's box laid flat in plan,
horizontal sightlines at nine heights from eight headings, on a pattern or a
saved model. On run 16's model it finds the slit up the core's front at six
heights of nine (2.4 LDU wide) and, from each 45-degree corner, two gaps at
every height 15-37 LDU wide: the six-sided piers. A face is as wide as whole
studs allow and two walls at angles nearer than a lattice cell collide, so the
channel cannot be closed by bringing the faces together; it is closed from
behind, with a post up the inside of each corner — a column of 1 x 1 round
bricks, or 2 x 2 where the corner's mouth is wider (radius 9), in whichever face
of the corner is turned off the grid, as near the mouth as clears both faces,
and kept only if it meets every sightline through the channel. Open octagons of
radius 7 and 9 are now clear from every heading, the guidance's open cluster
from front and back. Still open, and measured: a corridor a clearance wide
(`CLUSTER_CLEAR`, 3 LDU) along the core's outside under each pier, seen through
only straight along that core face — 9 sightlines on each diagonal of the
guidance's cluster, open or closed; closing it wants a pier's faces that meet
the core built in that core face's own section, so they can meet it flush.
Hexagons and decagons keep their channels, wider than a post can cover from
behind. **Piers that keep their sides**: runs 15 and 16 both asked for piers of
radius 4 at eight sides, were refused with "make their radius larger or their
sides fewer", and took six; a pier radius too small for its sides is now laid
at the least that keeps them (4.5 for eight) and the check says so.
**Dressing in the wall's own colour**: run 16's 149 grey round tiles were asked
for (`face_color` 72), copied from the guidance's studs_out example of grey on
black; the finishing pass dresses in the wall brick's own colour now, a
`face_color` going through a fifth of it as an accent. **Each assembly in
turn**: run 16's close review of its first assembly ended "say in a line what
you changed, and stop", and it did — one edit, then save. In sixteen runs'
transcripts no outside run reviewed more than two assemblies. The close review
now ends on the next one, and `save_model`, a run's last act, hands back the
next assembly's review while any is left. **Windows**: a prism lays narrow lit
windows two courses tall up its outward faces every eight courses unless told
not to; with the dressing black on black, the tower would otherwise read as one
black mass. **The ground** is unchanged: it is each run's own choice (run 15 a
ring of outcrops, run 16 four crags at the corners), and no default was found
that would not put rock round towers that should not stand on it.

Run 17, on those: a ten-sided core of radius 9 and 48 courses with four
eight-sided piers of radius 6 set 10 out (58 courses), `"open": 3`,
`"windows": true`, `"sideways": 0.25`; `add_rooms` straight after (six floors,
a dungeon to the palantír room); then it rebuilt the base unprompted as a black
drum on a ring of eight crags with a stair up to the door, restyled the faces
twice (asking `face_color` 72 again, which now went to a fifth of them), lit
two braziers and stood five figures and a skeleton, Saruman in white in the
top room. 8,603 parts in **864 s**. **Sideways 16% and angled 31% both in the
real range, and symmetry 23%, the most natural of seventeen**; plain 58% and
curve 10% still on the plain side, shapes 65 (16: 53) and colours 15 below the
median. By eye, from the front it is the best yet: a faceted black shaft with
71 narrow lit windows up every face, no slit up the core, four square-capped
horns with spires, and furnished floors behind. It is not the homepage. **The
detail passes were skipped again, knowingly**: it reviewed the whole once,
never an assembly, and when its save handed back the first of five assemblies'
close reviews it finished anyway — "I stopped before the close-up detailing
pass on each section". Words in an answer, even at the moment of saving, did not
move it; the next default has to be one that does the pass for it or that it
cannot step round. **Daylight still shows from the corners**: on a ten-sided
core no post fits (its corner channels are wider than one covers), "any open"
opened five of its ten faces as "the back", and the eight-sided piers' wide
corner grooves lead into hollows that open onto the core's inside — 2 to 2.5
studs of sky at every height from the front-right corner, 90 sightlines in all
by `daylight_probe` (run 16: 86, its front slit gone). The design chose ten
sides itself; the guidance and every example say eight. Also: no door is
visible at the top of its stair, and the faces still carry the design's own 12%
of grey bricks. Pictures: `shots/runs/orthanc_17_*.png` in its worktree. The
levers left, by what they cost the picture: the corners of a ten-sided core (a
post that fits, or the corner closed another way) and what counts as the back
on one; the corridor under each pier; a detail pass that happens without being
asked; a portal the stair leads to; and the ground's own craft.

Run 17's levers, 2026-10-11. **The corners of any core.** Run 17's ten-sided
core opened five of its ten faces as "the back", every face that looked
backwards at all, and that opened its front piers' hollows onto the core's
inside. The back is now the faces within 67.5 degrees of straight back
(`OPEN_REACH`): an octagon's three, as before, and a decagon's three. No post
had fitted a decagon's corner either: square to one face, a post had to clear
the other, which put all 535 clear places too far behind the channel's mouth
to meet the slanting sightlines. Where none fits square to a face, the post
now turns half way between the two, in a section of its own. Ten- and
twelve-sided prisms turned out to be open straight through along their corners
even when closed (54 and 172 sightlines; their outside rows cannot run on into
the groove), so those corners are posted too. Looking at the guidance's own
octagonal cluster from the front-right corner, the view a picture is taken
from, found one more: a pier at the back is a frame of its outward faces, open
behind, and a groove between two of them showed the sky up the right cleft.
Those piers' corners are posted, half way between their faces (square to a
narrow pier face, a post stood behind its inside row and the check read it as
resting there off its studs). **A portal**: a clustered tower lays a great
door at the foot of its core's front unless told not to. It is a 6182 arch
over two open studs, the door set back a stud in reddish-brown log bricks so
it is never a window onto the open back, in the stretch the piers leave in
view (on run 17's cluster, two studs), and the check says so when nothing
fits. **The detail that happens without being asked**: `save_model` and the
review it hands back belong to the command socket, and nothing the app does
after a save is in the file saved, so the default that moves designs is the
pattern. Every run since 15 called the cluster in its first build, and the
windows it gained after run 16 were all over run 17. The close pass that
mattered most to the picture was "horns and summit": run 17's horns were flat
caps with a point stood in the middle, four turrets with roofs from the front.
Each horn now rises from its cap in rings two courses tall, two studs in each
time, towards its outermost 2 x 2, its ledges faced inwards with 65-degree
slopes as `rock` faces its own, the spike on that tip: four claws opening
outwards round the platform. (One course a ring was 31 degrees and looked like
a roof.) **The corridor under each pier** is still open, seen only straight
along a core face: 9 to 15 LDU from the 135 and 315 diagonals.
`patterns_probe` judges the rest and prints that.

Run 18, on those: it began with a ten-sided core of radius 7 and piers set 7
out, and was told no door fitted ("the piers leave less than two studs of it
in view"). **It resubmitted twice, widening the core to radius 9 and setting
the piers out to 11 with `"door": true`, until the door was laid**: a default,
and the check's one line saying it had not been laid, reshaped a run's tower
for the first time, and its clefts are wider than run 17's. Then `add_rooms`
(seven floors, a hall to the palantír room, with ladders), one finishing pass,
one whole review, five figures from eighteen tries, lamp posts either side of
the door and a brazier at each corner of the plinth, saved: 8,506 parts in
**1,048 s**. It took the generated horns as they were ("the tops of the horns
are the tool's standard layouts"), and again **skipped every close pass,
knowingly**: "None of the four parts of the model has had its close detailing
pass yet", handed the first of them at its save. Sideways 13%, curve 13% and
texture 16% in the real range; plain 58% (17: 58%); angled 60%, past the
fantasy 90th percentile, nearly all of it its own ten-sided core and piers
(hidden posts are 8% of the parts); symmetry 38% (17: 23%); 61 shapes and 13
colours, both below runs 13-17. By eye, from the front it has the best
silhouette of eighteen: slender, the horns rising to spikes at their outer
edges so the crown gapes, the door at the top of the steps with Saruman, Gríma
and two Uruk-hai before it, braziers burning, Gandalf on the summit. Two
things the run could not see cost it: **its summit had a 6 x 6 hole in the
middle**, where it tried to stand Saruman and Gandalf ("nothing to stand on"),
which it covered with a grey plate by hand; and **its ten-sided piers of
radius 6 have faces two studs wide** whose grooves line up through each front
pier, sky up both front clefts from the corner view (56 sightlines in all by
`daylight_probe`, 90 in run 17). Thirteen of its eighteen figure calls were
refused, nine because the furnished rooms left nowhere to stand. Pictures:
`shots/runs/orthanc_18_*.png` in its worktree, with `orthanc_18.ldr` and the
log.

After run 18, 2026-10-11. **A summit that keeps its middle**: the summit keeps
only its largest connected piece, and its two plate layers had broken round
the same 6 x 6 block, six-long strips both ways. The second layer is now laid
in the longest plate whose end is not over a joint of the first; that summit
covers 532 of its 544 studs with the middle whole, where it had 468. **Front
piers posted** where their outside rows cannot run on, as a closed prism is.
Run 18's own calls replayed on both (`orthanc_18_replayed.ldr`): Saruman
stands on the summit at the run's first try and its hand-laid patch is refused
as an overlap, and 22 sightlines are left (56), none from the front, the back
or the 45 and 225 corners. **Not homepage-worthy, run or replay.** The form is
right and the craft is not: plain 56-58% where real sets are 28%, 61 shapes
against 109, 13 colours against 23 and 78% of it black, the faces a speckled
brick wall with yellow dots, a flat stepped plinth for Isengard's rock, and no
run has done a close pass in three. The best picture so far is
`shots/runs/orthanc_18_replayed_front.png`. The levers left: the faces
themselves carrying what a close pass would add (the arched lattice windows
30044/30046 the tower review names, and a second and third tone), since words
at the save have now failed three times; rooms that leave a figure room to
stand; post columns of taller bricks, so hidden posts stop being 8% of the
parts; the corridor under each pier; and the ground.

## Building by hand, against Studio and Mecabricks (2026-10-11)

The owner's bar: "an excellent stand-alone LEGO builder with high feature
detail and immaculate UI/UX", at least as good as BrickLink Studio and
Mecabricks for everything a person does by hand. Audited on the live site
(build fd05ea3) by building a house, a car and a SNOT detail with the mouse
and keys, at 1600 x 900, 1280 x 720 at 1x, 1440 x 900 at 2x and a phone.
Studio's tools are from its help centre and a long tutorial (select by
colour, type, type and colour, connected, invert; L hides, Show all; C
clones; H hinges; arrow keys turn 90°, shift 45°); Mecabricks' from its
guide (clone D, groups, snap S, numpad views).

What it already does that they do not: a weight and "stands up" for every
model as it is built, the colours each part was really made in marked on
the palette, the parts bin drawn in the colour you hold, nothing to
install, and an assistant that builds.

What a person building by hand misses, most first:

1. **Copy, paste and duplicate.** None. Every window, wheel arch and wall
   bay is built again brick by brick. Studio clones with C, Mecabricks
   with D, and both paste.
2. **Moving and turning a selection as one.** X lifts one brick; arrows
   nudge a selection a stud; nothing turns a selection once it is placed.
   Both rivals pick a selection up, turn it and put it down.
3. **The ghost in its own colour.** The part about to be placed is drawn
   55% green (or red): a green brick's ghost and a refused one look alike
   in a hurry, and the colour you are about to place is not what you see.
4. **Selecting by colour, by part, by both, by what is connected, and
   inverting.** Only part-and-colour exists, on shift-double-click, which
   nothing on screen mentions.
5. **Hide, isolate and show all.** None. Working inside a model means
   taking its roof off.
6. **The verbs on screen.** Rotate, tip, paint, pick, lift, delete exist as
   keys only; the strip along the bottom names six things. A toolbar with a
   tooltip and shortcut for each is how both rivals are learned.
7. **Replace part**: the selection becomes the part held, in place and in
   its own colours.
8. **An undo history you can see** and go back through.
9. **The parts bin**: recently used parts, favourites, an exact number
   first (searching 3023 lists spider 30239 above the 3023 prints), and
   thumbnails of white parts that read as flat silhouettes.
10. **Placing under a part and onto side studs.** A bottom face drops the
    part to whatever is below; a side face does not meet the side studs'
    own grid.
11. **Mirror** a selection.
12. **Hinges and turntables turned about their joint** (Studio's H).
    `Joints` already finds the joints for the assistant.
13. **Technic pins and axles into holes, clips onto bars**: placing by
    connection rather than by box. The pipeline records no bar connector
    yet (lever 4 above). Done 2026-10-11 (`JointSnap`): a part in hand goes
    onto the pin hole, axle hole, pin, axle, bar or clip it is aimed at, R
    turns it about the joint and T takes the next way on, with check_design's
    rule for room. Bars and clips are read off the shafts and bores.
14. **Save a picture**: a large render to a PNG, the background clear.
    Only the command line's `--shot` does it today.
15. **Parts lists for shops**: a BrickLink wanted list (XML, which needs
    BrickLink's colour numbers; none are on disk) and a Rebrickable CSV in
    the columns its import reads (`Part,Color,Quantity`).
16. **Opening Studio's .io** (a zip around an LDraw file) **and LDD's
    .lxf** (a zip around LXFML, which needs LDD's design numbers mapped).
17. **Measuring** in studs, plates and millimetres.
18. **Cut-away and x-ray.**
19. **Sub-models made by hand** from a selection; the `.mpd` already
    carries them.
20. **Locking** parts against edits.

Found on the way, and fixed or owed below:

- Escape does not close the Controls sheet on the web, and the keys go
  through it: 5 turned the view underneath.
- At 1280 x 720 at 1x the whole interface is drawn at 0.8 of its size, so
  11-unit text is under 9 pixels: part numbers, the colour notes, the key
  strip (task 51).
- On a phone held upright the model is framed too close and cut off.
- A part's tooltip keeps LDraw's padding ("Brick  1 x  2") and counts side
  studs into its footprint ("2 x 2 studs" for a 1 x 2).
- A model whose parts sit a fraction of a stud off their studs opens as it
  is (task 55); `src/dev/reseat.gd` can seat it.

**Built, 2026-10-11** (each a key and a button, each in
`src/dev/handbuild_probe.gd`, which drives them with keys and clicks):

- 1, 2: `Ctrl-C`, `Ctrl-V`, `Ctrl-D`, `Ctrl-X`; `X` picks a selection up to
  move it, `Esc` puts it back; `R` turns what is held, or the selection where
  it stands. A held group's frame is a stud centre or corner at its bottom, so
  it stays on the studs however it is moved or turned. Copy also puts LDraw on
  the system clipboard, and LDraw from another program pastes in.
- 3: the ghost is the part in its own colour, shaded; refused, red and
  striped.
- 4, 5: Select by colour, part, both, connected (by studs, not by touching),
  the opposite; `H` hides, `Shift-H` shows only the selection, `Alt-H` shows
  all. Hidden parts are not hit by the pointer but still take up room.
- 6: the edit bar, twenty tools down the left of the model, each with what
  it does and its key, faint when it needs a selection; two columns on a short
  window.
- 7, 8: Replace swaps the selection for the part in hand; History lists every
  step in words and goes back to before any of them. Undo now follows a part
  through a removal and back (it comes back under a new number, and a paint
  before it was being lost).
- 9: Recent and Favourites in the parts bin (right-click keeps a part); a
  number finds its own family first; light parts' thumbnails have faces.
- 10: aimed at an underside, a part hangs under it; a part tipped onto its
  side goes onto side studs.
- 11: `Shift-M` mirrors a selection left to right as seen, swapping handed
  parts by name.
- 12: `J` swings a selection 15° about the hinge, clip or turntable it hangs
  from, found by `Joints` as the assistant finds them.
- 17: `U` takes out a ruler: two clicks give the distance in millimetres and
  in studs and plates along each axis.
- 19: `Ctrl-G` names a selection as a sub-model, which saves as one in the
  `.mpd` and which the booklet builds on its own; Select → Same sub-model.
- 14, 15: Export offers a 2400 x 1600 picture of the model alone on a clear
  background, a BrickLink wanted list (55 colours, sourced) and a Rebrickable
  list.
- 16: Open reads BrickLink Studio's `.io` (a zip with Studio's published
  password around an LDraw file), in a browser too; and, since 2026-10-12,
  LDD's `.lxf`: LEGO's part and colour numbers and LDD's origins mapped by
  the community's ldraw.xml (`assets/ldraw/ldd.json`, `src/parts/ldd_lxf.gd`),
  a part it cannot place named rather than dropped. Proven on a file LDD 4.3
  saved, every part where LDD put it (`lxf_probe`).
- 18, 2026-10-12: `K` cuts the model along X, Y or Z, the plane dragged
  through it by a slider in a strip over the model (View → Cut away, or the
  toolbar); the faces it cuts through are drawn as faces, hatched, and what
  is cut away can stay as a ghost. `I` is x-ray: everything but the
  selection, or the sub-assembly being edited, see-through. A click goes
  where the eye does, past the cut and through the ghosts; the timeline
  keeps both, the booklet sees neither. On Orthanc a drag of the cut costs
  11 ms a plate, x-ray 60 to 90 ms once, and a frame cut through the middle
  less than a whole one (`src/ui/see_inside.gd`, `see_inside_probe`).
- Task 55: a model with parts off their studs offers, once, to seat them.
- Task 51: no window that keeps its panels is drawn below 0.92 (1280 x 720
  was 0.8); the smallest text is eleven units; the top bar's buttons have
  faces; the key strip sits on dark pills; a phone held upright frames the
  model across it. The Timeline's caption and buttons are the booklet's work.

**The shell, 2026-10-11.** The owner: "you didn't build the UI/UX and features
of an actual LEGO CAD platform, including the top controls." Laid out as
Studio, Mecabricks and LDCad lay one out (`src/ui/shell.gd`):

- Menus along the top — File, Edit, View, Build, Tools, Help — every command
  with its key beside it, greyed where it would do nothing, ticked where it is
  a setting that is on. The dozen buttons the bar had are items in them.
- A toolbar under them: the file, undo and history, the tools, the clipboard,
  snap and turn step, the grid, square-on, fit and three views, measure,
  properties, timeline, instructions, parts list. On a narrow screen it folds
  what the menus also hold; on a phone the tools stay.
- Tools a click acts through, the one in use lit: Build, Select, Move, Rotate,
  Hinge, Clone, Paint, Hide, Delete. `V` is Select; `Esc` is back to Build.
- Snap (stud, ½ stud, ½ plate, free) for placing, carrying and the arrows; a
  turn step (90°, 45°, 15°, 5°) for `R` and the Rotate tool.
- Properties of the selection: the part by LDraw's and BrickLink's numbers, the
  colour by every name it has, X, Y, Z and the turn typed over to move it, what
  it is joined to, its sub-model and its step.
- A status bar: what just happened or what the tool does, the parts and whether
  they stand, the selection, the snap, the size of a stud on screen.
- Locking (20): `L`, `Shift-L`. A stud grid, full screen, Save as, Open
  recent, a tour, About. The layout — panels, properties, key strip, grid,
  snap, turn step — comes back next time.
- Escape closes the Controls sheet on the web with a tooltip up (`Main._input`).
- Text fields give the keys back on Enter, Tab, Escape or a click elsewhere
  (`src/ui/focus_guard.gd`): naming the model no longer left every shortcut dead.
- The controls, as Studio's (the owner: "super awkward to switch between
  selecting a placed piece and placing a new piece"): Select is where the app
  rests and a drag moves a part; a part chosen (or Q) stays in hand until Esc
  or a right click; the right and middle buttons only look; navigation presets
  for Studio (default), Blender and Mecabricks. `tools/web/controls_flow.mjs`
  counts a person's first tasks on the old build and the new.

Left, in order: Technic pins and axles and clips on bars placed by connection
(13); edge lines and studs-off views, which are the
renderer's (BrickWorld); panels that can be
moved to another edge, not only folded. And: a part's tooltip still counts side
studs into its footprint; on the web a moved brick is not redrawn until
something else is (BrickWorld's, being fixed there).

## Any subject: round, mechanical, on show (2026-10-11)

The owner asked for a Falcon Heavy and got, in their words, "the ugliest most
retarded version... no advanced lego pieces, cant make perfectly smooth curves,
cant use techniqs, picks completely wrong colors". Read from their tab: 4,252
parts in square columns of plain bricks (720 of 87087 dressed with round tiles),
29 shapes and 5 colours — three greys and white, where the rocket is white with
black interstages — 67% plain, 9% curved, 0% at an angle, no fairing, no
octaweb, no Technic, a slab for a launch tower. Its review told it "a prism with
piers, for a tower like this one" (its description named the launch tower).
Every lever above was built for towers and castles; nothing could say round.

**What real rocket sets are made of.** 21309 Saturn V (1,969 parts by inventory,
1,831 in LDraw's model): white 37%, light grey 15%, black 12%. 196 of the 3 x 2
curved brick (24309) and 92 of the 2 x 2 (15068), hung as panels on a core of
brackets and jumper plates turned out on four sides, with corner fillers at 45
degrees on clips — 74% of the model sideways, 39% at an angle, 37% curved by
`tools/style.py`, 138 shapes, 14 colours; 112 grille tiles for the corrugations,
20 quarter-cylinder panels for the third stage, F-1 engines as 3 x 3 cones under
round plates, fins on Technic pins. 10341 Artemis SLS (3,601): 154 curved 2 x 2
in dark orange for the core stage, 287 grille bricks, and 114 friction pins and
108 pin connectors holding the boosters on. City rockets (60228, 60351): white
cylinder halves 2 x 4 x 5 and 2 x 4 x 2 back to back, 4 x 4 round plates, cones,
1 x 1 cones for engines, Technic pins, girders for the tower.
`how_real_sets_build_this` for "rocket" (38 sets) leads with the 2 x 2 cone
(x108), girders, the 4 x 4 cone and the cylinder half.

**What changed**, each general and named for the technique, not the subject:

- The `round` pattern: anything round in section, diameter 1, 2, 4, 6 or 8 (the
  sizes round parts come in), as a stack up one axis of the parts real sets use
  at that size — round bricks, cylinder halves, corner rounds tied by round
  plates — with colour bands, cones under a round plate, a Technic course with
  beams pinned on, spokes carrying tiles, and a nose; upright or lying along x or
  z; `beside` stands two or four more round it, pinned at every Technic course
  they share. A rocket's words (engines, legs, grid fins, boosters) are read as
  the general ones.
- Reference pictures' colours arrive as LEGO colour numbers: Commons' Falcon
  Heavy pictures read White 76%, the greys of its shading, Black 7%.
- Advice that knows the subject (round, vehicle, living thing, machine): a rocket
  by its tower is told of the round pattern, never piers or restyle_model; a
  model shaped by its curves is not told it is square; the seam and slab advice
  leave round parts out.
- The guidance maps shapes to techniques and asks for an expert's touches (a
  figure, a printed tile, a story detail, something that opens, a stand with a
  nameplate); a check says so when a model of 300 parts has no printed part or
  nothing that moves — 95% and 94% of the 2,517 real sets that size since 2015
  have them.
- `studs_out` bands of one kind of detail (rivets, portholes, lights, tiles).
- 16 worked examples: round bodies, pinned joints, a display stand, six from the
  Saturn V. The `wide round tower` example had two of its four corner rounds the
  wrong way round — a bow tie that stacked and checked — since it was written.

Every run is the brief "A ___ as a detailed LEGO display model" on the owner's
plan over MCP (Opus 5.5), the "before" on main as it was (4199409), the "after"
on these changes; measured by `tools/style.py` against real space sets for the
rocket and vehicle sets for the rest. Pictures: `shots/runs/{falcon_owner,
falcon_1,falcon_2,loco_*,pirate_*,car_*}_*.png` in this worktree.

| run | parts | shapes | colours | sideways | angled | curved | plain | mirrored | min |
|---|---|---|---|---|---|---|---|---|---|
| Falcon Heavy, the owner's | 4,252 | 29 | 5 | 18% | 0% | 9% | 67% | — | — |
| Falcon Heavy, before (`falcon_1`) | 3,319 | 23 | 4 | 22% | 0% | 11% | 56% | 34% | 8 |
| **Falcon Heavy, after (`falcon_2`)** | **311** | 31 | 6 | 2.7% | 0% | **54%** | **26%** | 88% | 4 |
| *21309 Saturn V* | *1,831* | *138* | *14* | *74%* | *39%* | *37%* | *20%* | *74%* | |
| steam locomotive, before | 932 | 42 | 9 | 21% | 0% | 17% | 52% | 54% | 19 |
| steam locomotive, after | 825 | 59 | 9 | 22% | 0% | 19% | 51% | 64% | 21 |
| pirate ship, before | 1,087 | 45 | 14 | 16% | 0.9% | 17% | 54% | 60% | 17 |
| pirate ship, after | 1,695 | 55 | 6 | 20% | 2.4% | 16% | 56% | 43% | 20 |
| sports car, before | 194 | 41 | 10 | 5.3% | 0% | 6.7% | 50% | 99% | 10 |
| sports car, after | 240 | 45 | 8 | 7.2% | 0% | 10% | 40% | 80% | 16 |
| *real space sets, median* | | *138* | *12* | *44%* | *25%* | *17%* | *27%* | *82%* | |
| *real vehicle sets, median* | | *119* | *15* | *23%* | *16%* | *14%* | *33%* | *87%* | |

**The Falcon Heavy reads as a Falcon Heavy.** Its first call was the round
pattern with `beside`: three white cores of cylinder halves, nine cones under a
black round plate each, a black interstage with grid fins, the second stage, a
6-wide fairing; the boosters pinned on at the foot and the top of the first stage
(it asked for both, which found a bug: only the upper course was pinned; fixed).
Then twelve folded landing legs as Technic beams pinned to the skirts, from the
worked example; a black stand with a 6 x 8 plaque, a printed flag tile and two
lightning masts. Curved 54% and plain 26% against the owner's 9% and 67%; 311
parts against 4,252, so nothing for a computer to choke on. What it is not yet:
a set. It stopped after one assembly's review at 311 parts where the Saturn V
has 1,831; 31 shapes against 138; the round body is smooth but plain — no panel
lines, no grille bands, no Saturn V-style curved skin; the upper booster attach
point is a white square Technic course in a round body; and the 6-wide fairing,
four corner rounds tied by round plates every two courses, shows the plates'
notches as rows of slots. Sideways 2.7% is low against the space median, by
design: round bricks are curved, not turned.

**The held-out subjects** (not looked at while building any of this):

- *Steam locomotive.* It looked up "round body lying down" and laid the boiler
  as a round along x in crimson with gold bands, a round chimney and dome, a
  black smokebox with a round door, a display track on a base with a plaque, and
  a crew. The boiler is now a true cylinder where the before's was a box with a
  curved top; 59 shapes against 42. Plain is unchanged (51%): the tender, cab and
  frames are still brick walls.
- *Pirate ship.* Twenty-four round calls: masts with conical tops, black cannons
  lying along the deck. The hull narrows to a bow and has a waterline, a stern
  castle with railings, figures, a flag and a small stand with a map-tile
  nameplate, where the before's hull was a rectangular box. But its sails are
  stacks of white bricks where the before used sail parts, it fell to 6 colours,
  and the hull is still stepped, not smooth.
- *Sports car.* No better by eye. Its advice named wedge plates, curved slopes
  and a hinged section every time and it used none of them (0% at an angle); the
  body is plates stacked square. What it did take up was the touches: a stand
  with a plaque, a driver on a podium with a trophy, quad exhausts, a licence
  plate. The roadmap's rule holds a sixth time: words move nothing, one call
  shaped like the work does. A rocket has that call now; a car does not.

**Orthanc, held out against 10237.** The owner called the homepage's Orthanc
(run 18) "the ugliest piece of shit I've ever seen". Its faults are any
subject's: lit yellow windows in rows (an office block), black on black with
nothing on it (a void), one straight shaft with a top stuck on (no
silhouette), and rubble ringed round its foot (a base as an afterthought).
LEGO's 10237 is 66% black and 13% dark bluish grey, the grey on its ledges and
setbacks, and breaks its black with 86 grille bricks, 63 headlight bricks and
58 bricks with a handle; it steps in at each storey and its horns are blades.
(Commons has no picture of 10237, so `find_reference` cannot fetch one; it was
judged against LEGO's own product photo.) Each fault is now a check by name in
every check's advice, in the critique and the guidance; the prism's windows
are off unless asked and dark slits when they are; a black wall's second tone
is a course of grey every eight, never sprinkled (`orthanc_rk1` took a
scattered grey and read as speckle); and a prism takes `"storeys"`, stepping
in on grey ledges in one call.

| run | parts | shapes | colours | black | grey 72 | sideways | angled | curved | plain |
|---|---|---|---|---|---|---|---|---|---|
| run 18, the homepage's | 8,717 | 61 | 13 | 78% | 11% | 12% | 61% | 16% | 56% |
| `orthanc_rk1` (faults named, grey scattered) | 4,412 | 57 | 15 | 77% | 17% | 19% | 38% | 14% | 50% |
| `orthanc_rk2` (grey in bands, storeys) | 7,222 | 61 | 18 | 83% | 11% | 17% | 33% | 11% | 55% |
| *real fantasy sets, median* | | *109* | *23* | | | *19%* | *27%* | *20%* | *28%* |

`orthanc_rk2` used every new call: `"storeys": {"count": 3, "in": 1}`,
`band_color` 72, `windows` in Trans-Brown, rooms from the top storey's radius
(Saruman by the palantír, Gandalf on the summit, a dungeon), a nameplate and
braziers. By eye it is better than run 18 on each named fault — no window
grid, no speckle, a tower that narrows storey by storey on grey ledges — and it
is still not a display set: it chose a core of radius 7 with 4.5 piers, so it
is tall and thin; its horns are the generated thin spikes, not 10237's blades;
its base is two rock piles on a grey plate; and in software rendering its
faces read as one black mass (12 grille bricks against 10237's 86). Not for
the homepage. Pictures: `shots/runs/orthanc_rk{1,2}_{corner,front,back}.png`
in this worktree; the homepage's are `web/orthanc-{corner,back}.webp`.

**Horns as blades.** 10237's horns, in LEGO's own photographs, are blades of
plates on their side: wedge plates cut their edges, tiles face them, Technic
beams edge one, a cone tips each; seen along its plane one is a narrow edge,
across it a curved fin. Every generated horn before was a square spire
stepping in to a cone and a bar. A pier's horns are now `"horns": "blade"` by
default (`"spire"` and `"flat"` on asking): over each pier's summit a blade in
a section of its own, four layers of plates on their side and tiles, two studs
deep, its foot pressed onto bricks with side studs, in the plane through the
tower's middle and its pier, sweeping out by half its width and back in to a
point, each edge a stud at a time with a wedge plate at every step. It is
a technique, not a subject: any crown of spikes, a throne's back, a gate's
fangs. Three faults found by looking: wedges matched by their studs stood the
wrong way out of the edge like a saw's teeth (their cut is now read off their
body); a wedge on its side placed by its collision cover stood two LDU off its
neighbour, a slit of sky up every blade (seated by its body now); and a blade
that stopped at its height was flat-topped and read as a slab (its edges now
close to a point). Then by eye at the integrator: at 24 LDU the two blades
seen edge on from the corner read as one sheet standing out of the middle of
the summit (two studs deep now); turned to face the front they were sticks
from the side and cut-off plates from the corner (radial again); and the 2 x 4
right-hand wedge (41769a) draws its cut face nearly white on its side, a pale
flag up a blade, a rendering fault of mirrored subparts being fixed at the
root (the blades still use the part). Every storey also laid its own door;
only the lowest does.

**Display proportions.** 10237 is 21 cm across and 73 cm tall (its box says
so), 1 : 3.4 with its base. The homepage's Orthanc stood 2.1 times its 49-stud
base and `orthanc_rk2` 2.6 on a 41-stud plate of rubble, thin towers on wide
bases; the guidance's own example stood 1.65. A prism with piers given no
courses is now laid at 3.3 times its widest, plinth and horns included, and the
reply says how many; courses given more than a fifth off are laid as given and
the reply says what would do. The guidance's example leaves them out: radius 7
on a plinth comes to 73 courses, 7,052 parts, one piece. It is closed all round
now: opened at the back, the sky showed up the clefts beside the back piers from
the corner and the shaft read as four thin straws, where 10237's is one mass of
rock. Pictures:
`shots/runs/blades_{corner,front,right,close}.png` in this worktree.

The brief run on the owner's plan over MCP with blades and display proportions
(`orthanc_new`, 416 s; `orthanc_run1` was the same with a ban on one wedge,
since lifted): 11,866 parts, 79 shapes, 23 colours (run 18: 61 and 13),
sideways 19%, angled 34%, curve 15%, plain 52%, symmetry 34%. It took the
call as the guidance has it, rebuilt it wider for its rooms, opened the back on
ten furnished floors, and stood Saruman, Gandalf, Gríma and an Uruk-hai about
it with a nameplate. By eye it is clearly better than run 18 — crescent horns
round an open summit, three storeys on grey ledges, no lit windows, a stair to
a door — and still not a LEGO display set: its faces are speckled with grey
dressing where 10237's are ribbed and gridded; from the corner the sky shows up
the right cleft into the open back; the back horn, edge on from the corner,
stands like a mast behind the summit; and its base is a flat 66-stud courtyard
with five rock piles, which also makes it 1.9 times as tall as wide where its
tower alone is 3.3. Not for the homepage. Pictures:
`shots/runs/orthanc_new_{corner,front,back,right,close}.png` in this worktree.

Each of those four is now a rule of any model, laid by the patterns and named
by the check. **Speckle**: a dark face's texture goes in columns — a rib of
round plates up the middle of each face, grille bricks either side of it every
other outside row (2.7% of a black tower, 10237 3.6%), its second tone on the
ribs — and `restyle_model`
and a dark fill's sideways bricks keep to columns; the check calls dressing or
a second tone scattered over a dark wall speckle. **Sky through a slit**: a
pier at the back of an opened core stays closed where the core's corner was
taken out (the open guidance tower had 6 sightlines from each corner, now
none), and the check calls a slit of sky that runs up the model from any of
the eight views. **The mast**: blades turn 20 degrees off their piers' diagonals, so none
is edge on from the corner. **The yard**: a plinth carries crags in its dark
tones at its corners and sides, within its own width, and the check says when
a tall model's base is 1.6 times as wide as its body. Pictures of the guidance
tower: `shots/runs/blades_*.png` in this worktree.

The brief run once more on those rules (`orthanc_r3`, 530 s): 9,151 parts, 84
shapes, 20 colours, sideways 10%, angled 41%, curve 12%, plain 66%, symmetry
36%; 36 studs across and 304 plates tall, 3.4 times as tall as wide with its
base (10237 is about 3.5). It took the guidance's call at radius 8 on a plinth
of two terraces with its crags, opened the back on ten furnished floors, and
added braziers, a nameplate and four figures. By eye it is clearly better than
run 18 — blades round the summit, a black shaft on grey string courses that
reads as one mass from the front and the side, rooms through the back, a
compact base — and still flawed: from the corner a stud-wide slit of sky runs
the full height beside the front-left pier; its faces are plainer than run 2's
(66% plain, the scatter gone and only ribs and a little grille in its place);
and the crags are small grey spikes at the plinth's corners, not a mass of
dark rock. Better than the homepage, not a display set. Pictures:
`shots/runs/orthanc_r3v_{corner,front,back,right,close}.png` in this worktree.

The slit was a gap in a rule, now closed: a core of radius 8 took two faces of
each pier down to 0.9 of a stud, too little for a brick, and nothing was laid
there, so the sky passed straight through every pier. Piers not told their
`out` now stand at the nearest half stud to the core's wall at which no face is
left such a hole (`_pier_out`, here a stud deeper): the run's own call had a
slit from each corner at all nine heights and has none up the shaft
(`shots/runs/orthanc_r3_pattern_fixed_*`).
The check had told the run only of slivers between its crags and its tower, at
one height, which it chased with posts; it now counts slits up to a stud and a
half wide that run up the model, at two of its nine heights or more.

Run once more on that (`orthanc_r4`, 136 s): 9,415 parts, 71 shapes, 23
colours, plain 68%, three figures (Saruman, Gandalf, an Uruk-hai at the door),
seven furnished floors behind; the guidance's radius 7, opened one face. No
sky shows from the corner, front, back or close views: off the parts' own
boxes nothing up the shaft is wider than 0.07 of a stud, and at the plinth only
the gaps between its crags and the tower, at one height. Its form is r3's,
the corner view without the slit; its finishing is thinner (no nameplate or
braziers, seven floors to ten, 71 shapes to 84). Offered for the homepage.
Pictures: `shots/runs/orthanc_r4v_{corner,front,back,right,close}.png`.

**Dark walls dressed as one structure (2026-10-12).** On the landing page, run
4 was told by the app's own check that it was 58% plain black, a hole, and that
559 of its 593 pieces of dressing were scattered one by one; the status bar
said "1 weak joint (overloaded)". Three causes, each any subject's:

- *The check read the file wrong.* An `.ldr` keeps where each brick is and not
  the section it was laid in, so read back, a prism's turned faces sat at the
  nearest square turn (232 pieces, sky through slits no picture shows) and the
  whole tower was one wall: the rib up each storey's face was counted against
  every course of the tower. A file's turned bricks are now read into sections
  of their own, and speckle is measured a wall at a time — one plane of one
  face, a rib or band three marks long. Read so, run 4 has 99 of 1,078 marks
  scattered, one piece, no sky, and is not called speckle.
- *The finishing pass dressed part by part.* On a dark wall `restyle_model`
  turned out only the bricks that happened to start on a column, each with its
  own tile: broken columns over plain black. It now lays each wall as one
  structure in its own colour, `"style"` ribs, bands, panels, grid or recessed
  courses, and a dark wall gets panels unasked: grille between ribs of round
  plates, framed by whole courses at its ledges, which also tie a two-thick
  face to its back row. Side studs in no rib are regrouped. An `edit_model`
  that lays dressing a part at a time over a dark wall is refused, told the
  call. Run 5 took it up by name in its first minute.
- *The weak joint* is the prism's: the foot of the core's face in each cleft
  between the piers hangs over a hole in the plinth, touching a ledge tile at
  one edge cell, and 88 g of face rested on a tile corner that holds 80.
  `src/dev/redress.gd` underpins such a brick with a column of 1 x 1 bricks and
  plates down to what is below; `src/dev/candidate_probe.gd` refuses a homepage
  model that does not stand up, is not one piece, or has a picture fault the
  page's model has not.

| model | parts | plain black | marks scattered | weak joints | pieces |
|---|---|---|---|---|---|
| run 4, the page's, as read before | 9,415 | 58% | 559 of 593 | 1 | 232 |
| run 4, read as it stands | 9,415 | 58% | 99 of 1,078 | 1 | 1 |
| run 4 dressed again (`orthanc_redress`) | 10,038 | 46% | 90 of 1,020 | 0 | 1 |
| run 5, fresh, made sound (`orthanc_r5_sound`) | 9,428 | 48% | 10 of 725 | 0 | 1 |
| *10237 Tower of Orthanc (Rebrickable)* | *2,337* | *23%* | | | |

By eye run 5 is the best of the three: every face a panel of grille between
the string courses, which reads as 10237's worked black where run 4 read as
brick; run 4 dressed again is between, its old masonry and grille strips mixed
into the panels. Both still read as a dark mass from across the room, and the
check still calls both a hole: what is left plain black is the inside of a
two-thick hollow shaft, open at the back, the blades and the summit, which a
dressing of outer faces cannot reach — 10237 is 23% plain black. Held out, the
pirate ship: unasked, its black lower hull took faint grille panels and its
reddish brown walls (not dark) kept the old scatter, which also sprinkled its
sails and split one brick off; told `"texture": "log"`, the hull reads as
planked. The default suits a fortress, not a ship; the subject should choose.
Pictures: `shots/runs/{orthanc_redress,orthanc_r5,orthanc_r5_sound}_{corner,front,back,right,close}.png`,
`shots/runs/pirate_{before,redress,redress_log}_corner.png` in this worktree.

**What is left, by what it would move:**

1. **A shaped body for vehicles, in one call** — the car's and the hull's
   equivalent of `round`: a plan outline and a side profile laid as plates, wedge
   plates where the plan slants, curved slopes where the profile rounds, and
   sections for a windscreen. The car ignored every word of the same advice.
2. **Detail passes on a model this compact.** The Falcon Heavy stopped at 311
   parts; 31 shapes against a set's 138 is the variety gap, and the curved skin
   panel, grille band and studs-out core examples are there to be used.
3. **The Saturn V's skin as one call**: curved-brick panels on a studs-out core,
   for rounds wider than 8 studs and for a surface with panel lines.
4. **Sails, canopies and other non-brick parts** — the pirate ship gave up sail
   parts for bricks.
5. A round's Technic course in the body's own round section, not a square one;
   and a 6-wide round tied without rows of notches.
6. **Orthanc's crown and base as calls**: claws round the upper storeys, and a
   base of ribbed, flaring buttresses (10237's 36 curved 10 x 1 slopes on their
   side) — horns as blades and a plinth with steps to the door are calls now,
   but nothing yet lays the claws or the ribs.
7. **The prism's foot in its clefts**: lay the plinth under each cleft between
   piers so the core's face stands on it, rather than underpinning it after;
   and **a dark tower's hidden half**: a two-thick shaft is as many plain
   bricks inside as out, so a black tower dressed on every face is still 46%
   plain black where 10237 is 23% — thinner walls on a frame, or SNOT panels
   on a core, as real sets build a tall dark body. And the light-wall scatter
   `restyle_model` keeps, which sprinkled a ship's sails.
8. Two prism faults found on the way, neither from storeys: a twelve-sided
   prism of radius 8 overlaps itself (14 problems, 36 pieces), and
   an octagonal core of radius 7 with piers of 4.5 (the least radius) overlaps
   and comes apart in six pieces. A run that asks for either is told so by the
   check, but the pattern should not lay them.

**The held-out set again, with `shape` and the rest in (2026-10-12).** The
brief "A ___ as a detailed LEGO display model" on the owner's plan over MCP
(`env -u ANTHROPIC_API_KEY`, the app in software under `heavy`), pictures on
the GPU; measured by `tools/style.py` against space sets for the rocket,
vehicle sets for the car, ship and locomotive, and `other` for the owl. Beside
the last round's "after" runs (table above):

| run | parts | shapes | colours | sideways | angled | curved | plain | mirrored | s |
|---|---|---|---|---|---|---|---|---|---|
| Falcon Heavy (`falcon_h1`) | 281 | 29 | 5 | 2.2% | 0% | 55% | 15% | 92% | 341 |
| *last round (`falcon_2`)* | *311* | *31* | *6* | *2.7%* | *0%* | *54%* | *26%* | *88%* | |
| sports car (`car_h1`) | 223 | 50 | 7 | 1.8% | 4.6% | 10% | 58% | 83% | 1,166 |
| *last round* | *240* | *45* | *8* | *7.2%* | *0%* | *10%* | *40%* | *80%* | |
| pirate ship (`pirate_h1`) | 1,850 | 67 | 10 | 1.8% | 12% | 14% | 72% | 92% | 951 |
| *last round* | *1,695* | *55* | *6* | *20%* | *2.4%* | *16%* | *56%* | *43%* | |
| steam locomotive (`loco_h1`) | 667 | 59 | 11 | 7.7% | 0% | 7.8% | 62% | 92% | 984 |
| *last round* | *825* | *59* | *9* | *22%* | *0%* | *19%* | *51%* | *64%* | |
| barn owl (`owl_h1`, new) | 738 | 46 | 14 | 4.3% | 0% | 6.8% | 74% | 94% | 331 |
| *real vehicle sets, median* | | *119* | *15* | *23%* | *16%* | *14%* | *33%* | *87%* | |
| *real `other` sets, median* | | *126* | *16* | *61%* | *15%* | *12%* | *31%* | *65%* | |

By eye: the **Falcon Heavy** reads as one — three smooth white cores of round
parts, black interstage and grid fins, ogive fairing, Technic legs, a stand
with Starman and a red roadster — and is bare: 29 shapes, no panel lines. The
**car** is a yellow supercar with mudguard arches, a wing, a driver with a
cup and a plinth, built by hand after its `shape` body "came out blocky and
in pieces" (234 floating, three pieces once the wheel arches were cut); its
roof is a flat slab. The **ship** is a three-master with cannons, a stern
gallery, crew and a bowsprit on a `shape` loft hull whose bow is a
staircase of brick columns, and its six sails are walls of white bricks
again. The **locomotive** is a crimson Pacific on track with a round boiler
— its `shape` revolve boiler came out "too boxy" and it switched to the round
pattern — and a tender, cab and smokebox of plain studded bricks. The
**owl**, two `shape` calls of ellipsoids, is a lump of stepped plain bricks
with a flat white face. Every run met the touches (figures, plaques, a stand)
and none is detailed: shapes are under the tenth percentile in four.

**The weakness they share is the `shape` call's surface.** Four of the five
said a body as solids, and wherever it curves it comes back as a staircase of
studs-up bricks: two runs threw it away, two kept it. Laid on its own, the
call puts no wedge plate on a 45-degree edge and nothing on its side on a
curved flank: a cylinder of radius 5 and a box chamfered 3 studs are both
staircases with no wedges at all (`lay_disc`); an egg like the owl's body is
4% sideways and 75% plain with two wedges in 409 parts; the probe's hull 2%
sideways, the run's hull 4 side-stud bricks in 1,301 parts. Side panels need a
straight side two courses tall, which a round body barely has, and the brick
courses' wedges come at 34 degrees and shallower.

Tried and not kept, each measured on that egg and the probe's bodies: side
panels on every exposed flank with a curved slope rolling back from each
step (egg 4 to 6% sideways: half a round body's outline is in plate layers,
and corner columns came apart, the probe car in five pieces); ellipsoids laid
as rounded boxes (no clearer); diagonal brick edges handed to the plates for
wing plates (none fitted). Dressing a staircase's outline does not make it
round. **Next**, in order: (1) find why `Plan._wedged` fits no wing plate on
a round or chamfered plan, with `lay_disc` as the failing probe; (2) a body
round in section laid in round parts (a revolve's diameters, 1 to 8); (3) a
round body's sides laid outward on their side, a shell of plates and curved
slopes on a core with studs out on four sides, as the Saturn V and BB-8 are
built; (4) sails and flags as cloth parts hung from yards, which the check
does not yet count as held. Pictures, logs and saves:
`shots/runs/{falcon,car,pirate,loco,owl}_h1_{corner,front,close}.png`,
`.log`, `saves/`, and `lay_{egg,hull,boiler,owl,disc}_*.png` in this
worktree.

**Why `shape` laid no wedge on a round plan, and the fix (2026-10-12).**
Measured with the `lay_disc` cases, laid through `Shapes.lay` as the call
lays them: a revolve about y of radius 5, a box with `"chamfer": 3` and an
egg (ellipsoid 5 x 16 x 5 with a white front). Every wedge position that
passed `Patterns._wedge_fits` failed `_diagonal`, and the reason was the
first rule: a wedge's cut side had to lie outside every stud of the plan.
On a stepped round plan the studs the edge cuts across are the plan's own
(a stud is in when its middle is), so the only places left were flat sides,
where `_diagonal` rightly said fin. The twin, `near_edges` and the wedge
table were never reached. Two more faults were found on the way: the plates
the twin was matched by (`Shapes.wedge_plan`) read the collision boxes,
which are in 2 LDU lattice cells, as LDU, so every plan was the middle half
of the part and twins were found by chance; and nothing at 45 degrees was in
the table, which a chamfer and the diagonal of a circle both need.

Now an edge part goes where it brings the layer's outline nearest the
shape's own edge, measured on a 4 x 4 grid in every stud of its box against
what the shape covers there (`Plan._gain`); its cut side may take a stud the
edge cuts; round parts first (corner rounds 30565, 30357, 79491; bricks
2577, 5152, 3063b), then plates and bricks without a corner (2450, 26601,
30505), wing plates and wedge bricks; never across a stud whose edge runs
square (a ramp's falls), never cutting a column of studs through the middle,
and a part at a joint between pieces is laid again plain so they can be
stitched (a 20-stud brickified bunny otherwise stood on its feet with its
body beside them). Whole round plates and bricks, 30503 and the double
wedges have one square collision box, so they are left out: the check would
read them as squares.

| case | parts | round parts | wedges, cut corners | curved | sideways | plain | pieces |
|---|---|---|---|---|---|---|---|
| cylinder r 5, before | 45 | 0 | 0 | 0% | 0% | 76% | 1 |
| cylinder r 5, after | 57 | 8 | 4 | 14% | 0% | 60% | 1 |
| chamfered box, before | 63 | 0 | 0 | 0% | 0% | 70% | 1 |
| chamfered box, after | 67 | 0 | 12 | 0% | 0% | 54% | 1 |
| egg, before | 409 | 0 | 2 | 0.5% | 3.9% | 75% | 1 |
| egg, after | 411 | 26 | 24 | 12% | 1.5% | 68% | 1 |

(2450, 26601 and 30505 are not "curved" in `style.py`'s kinds, so the box's
twelve are in no share.) Every `shapes_probe` body still one piece (the car
255 parts); `patterns`, `style`, `stability`, `rooms`, `techniques`,
`world_view`, `brickify` and `brickify_ui` probes pass; a forty-stud
bunny lays in 6 s against 1.7 (the edge search is most of it now).

Held-out again, on the subscription (`env -u ANTHROPIC_API_KEY`, under
`heavy`), measured by `tools/style.py`:

| run | parts | shapes | colours | sideways | angled | curved | plain | mirrored | s |
|---|---|---|---|---|---|---|---|---|---|
| barn owl (`owl_w1`) | 825 | 43 | 10 | 2.7% | 0% | 6.3% | 70% | 94% | 431 |
| *last round (`owl_h1`)* | *738* | *46* | *14* | *4.3%* | *0%* | *6.8%* | *74%* | *94%* | |
| sports car (`car_w1`) | 220 | 34 | 8 | 1.8% | 0% | 14% | 56% | 69% | 1,111 |
| *last round (`car_h1`)* | *223* | *50* | *7* | *1.8%* | *4.6%* | *10%* | *58%* | *83%* | |

By eye: the **owl** said its body as a `shape` again and kept it: 36
corner rounds (30357), 28 plates without a corner (26601) and 6 cut-corner
bricks in its 825 parts, and its head and flanks read rounder than
`owl_h1`'s from the corner, but it is still a stepped body, its curved share
no higher (26601 and 30505 are not "curved" in `style.py`'s kinds) and its
sideways share lower. The **car** threw the `shape` body away again ("hand-
building gives much better control than the body-shape generator here") and
was built by hand, so it says nothing about this change: an orange
Gallardo-like coupe with a wing, grilles, roundels on the doors, a driver and
a plaque. One run each, and a run's choices move these numbers more than
this did. **Next**: a body round in section laid in round parts (a revolve's
diameters 1 to 8 handed to the `round` pattern), and a round body's flanks
turned out on their side — the plan view is fixed, the side view is not.
Pictures: `shots/runs/{owl_w1,car_w1,lay_disc_w,lay_egg_w}_{corner,front,close}.png`
in this worktree.

**A round section in round parts (2026-10-12).** The first of the two next
steps above. Where a layer of a `shape` is a disc of 1, 2, 4, 6 or 8 studs
(one colour, nothing else in its box, nearer a disc of its own area than
its box), it is handed to the round pattern's own body (`Rounds._body`):
round plates and bricks, cylinder halves, four corner rounds tied by a
round plate; a dome's crown, where no more than a dish is left over a run,
is the dish. Whole round parts were kept out of the edge fitter because the
check reads them as squares; laid where the square holds nothing else,
that is true of them. Measured on four bodies laid side by side (a
cylinder of radius 4, a dome 4 x 12, a column stepping 6, 4, 2, an
ellipsoid 4 x 12 x 4):

| | parts | curved | plain | pieces |
|---|---|---|---|---|
| before | 370 | 9.2% | 49% | 1 each |
| after | 60 | 100% | 0% | 1 each |

By eye (`shots/runs/{before,after}_rounds_corner.png` in this worktree):
the cylinder and the column are round where they were octagons of plates;
the dome and the ellipsoid are stacks of rounds with a dish on top, round
in plan and stepped in elevation, where they were lumpy in plan and sloped
on top. A body round only in part (the egg with its white front, an owl's
oval sections) is unchanged except at its ends. Not yet a held-out run.

**A curved side on its side, round tops tiled, and why the car threw its
body away (2026-10-12).** The second next step, and the third: a side of a
`shape` that curves up and down — an owl's breast, an egg's flank, a hull's
side — is no longer laid in courses that step out a stud at a time. The box
of it past a face two studs in is laid by the same plan turned on its side
(plates out from the face, rows of 2.5 plates down it) and held by 87087s in
the core's outer wall, every lane of every second row; its outside is
tiles, slopes and curved slopes facing out. Upright against sideways, on
the probe bodies:

| body | sideways | curved | plain | parts | pieces |
|---|---|---|---|---|---|
| egg, upright | 1.8% | 10% | 73% | 438 | 1 |
| egg, sideways | 32% | 2.6% | 60% | 453 | 1 |
| bird, upright | 0% | 12% | 68% | 255 | 1 |
| bird, sideways | 25% | 7.8% | 55% | 359 | 1 |
| hull, upright | 0.3% | 7.4% | 72% | 1,405 | 1 |
| hull, sideways | 19% | 2.7% | 54% | 1,823 | 1 |
| owl body, upright | 2.7% | 6.1% | 80% | 589 | 1 |
| owl body, sideways | 37% | 1.8% | 58% | 729 | 1 |

By eye (`shots/runs/cmp_{egg,owl}{,_up}_{corner,front}.png`): the flanks
follow the curve in tiles where they were brown blocks with studs on every
step; the breast is flat white tiles on its side, smoother but blocky, and
the curved share falls because the corner rounds at the rim become the
shell's plates. Where the core is cut thin (the probe car's axle tunnels)
turning its sides out left it in pieces, so it is laid upright.

The round sections of the unit before now finish as a set finishes them,
on the owner's note: a smooth top in round tiles (98138, 14769, four 27925,
7212; a round of 8 in the 4 x 4 corner round tiles, which are a ring, so
its middle keeps studs — no round tile of 8 exists) and a round tile on a
dish crown's studs. Not done: easing a dome's steps with curved-top
corner rounds (5651, 65617, 7426), which have no studs where the next ring
stands.

Why the held-out car threw its body away, read from its session: its three
`shape` attempts came back "floating (302)", then "3 pieces" with its
cabin's curved slopes "resting on a smooth face, held by nothing" — a cabin
said as a second shape stood on the body's tiles — then "11 pieces, 120
floating": the body's nose came away over the wheel arches, a course of
bricks with tiles over it and the cut under it. The run concluded
"hand-building gives much better control". Fixed where the body was at
fault: a shape under another keeps its studs where the other stands
(`Shapes.feet`), and a course with nothing under it and nothing studded
over it is laid in plates, which cross the joints (the session's last body
went from 7 pieces of its own to 2; the rest of its floating parts are its
own hand-placed axle bricks). The guidance says the shape now lays round
sections and turns curved sides out, that shapes stack, and to fix what a
piece stands on rather than rebuild by hand.

Held-out again, on the subscription (`env -u ANTHROPIC_API_KEY`, under
`heavy`), measured by `tools/style.py`:

| run | parts | shapes | colours | sideways | angled | curved | plain | mirrored |
|---|---|---|---|---|---|---|---|---|
| barn owl (`owl_r1`) | 1,313 | 49 | 11 | 19% | 0% | 5.3% | 64% | 88% |
| *last round (`owl_w1`)* | *825* | *43* | *10* | *2.7%* | *0%* | *6.3%* | *70%* | *94%* |
| sports car (`car_r1`) | 544 | 46 | 6 | 16% | 0% | 4.6% | 53% | 90% |
| *last round (`car_w1`)* | *220* | *34* | *8* | *1.8%* | *0%* | *14%* | *56%* | *69%* |

Both kept their `shape` bodies this time: the car said its body as a fill
and a shape and submitted it as laid, where `car_w1` threw it away after
three tries. By eye (`shots/runs/{owl,car}_r1_{corner,front,close}.png`):
the **owl** from the front is a rounded body with a smooth white breast and
flanks that follow the curve, where `owl_w1` was stepped brown blocks; its
head and shoulders are still small plates stepping. The **car** is a red
coupe whose flanks are smooth sideways tiles, tiled bonnet and a curved
cabin, wheels in arches, a wing and a plaque. Curved share fell in both
(the shell's plates replace the rim's corner rounds, and the car's run used
fewer curved slopes); plain fell and sideways rose by an order. One run
each. Left: easing a dome's steps (curved-top corner rounds), the middle of
a round of 8's top, fewer side-stud bricks (an 87087 a lane; 1 x 2 and 1 x 4
in runs would do), shells where arches thin the core, and a curved share
for the shell's own outline (it lays few curved slopes on its side).

**Finished the way a set finishes a shape: a stand named, steps eased, tops
tiled, flanks curved, side studs in runs (2026-10-12).** Five things the
held-out round left, each measured on the probe bodies, then the car and the
owl held out again.

*A piece apart is named or it fails.* `car_r1` was two pieces and said every
check passed. Its session says why: "Adding a printed grille tile, spoiler
tiles, and a nameplate plaque in front of the car" — a 41539 plate, a 4515
slope and printed tiles laid on the ground two studs in front of the bumper,
meant, and joined to nothing; to the check a piece apart was a remark, and a
part that has come off reads the same. Now a piece that stands apart from the
model (touching nothing of it within half a stud, its plan outside the rest,
under a tenth of the model's parts) fails as `loose` unless it is named: an
assembly whose box holds it and none of the model — `edit_model` takes
`assemblies` now — or a file's sub-model, or a figure. Pieces against the
model unjoined (a seam, one layer, a prism's faces) and a scene's second
thing of a size with the model are said as before. The run's assemblies are
tagged on the bricks as a session saves, so the stand is a sub-model the
person sees. `candidate_probe` on `car_r1.ldr`: before "544 bricks,
buildable, 2 pieces"; after "1 problem (loose 1)", and with the plaque in a
sub-model "apart as named: Nameplate", a candidate.

| body | before | after |
|---|---|---|
| dome (radius 4) | 12 parts; a stud-wide ledge of 20 bare studs between its 8 and its 6 | 28 parts, 100% round or curved: eight 15068 round the rim, a round plate and quarter tile on each corner, a core of 4, the 6 bridging in |
| cylinder of 8, top | four 27507 and 20 bare studs inside them | 23 parts: 27507, 79393 and 27925 rings and a 14769, no stud showing |
| egg, sideways | 450 parts; 2 curved slopes of 143 turned out; 84 1 x 1 side-stud bricks | 407 parts; 26 curved slopes of 135 turned out; 49 side-stud bricks (30414, 11211, 87087) holding the same 86 lanes |

*Dome steps eased.* The curved-top corner rounds have no studs, so a round
standing on them has nothing to grip; a set instead lays curved slopes on the
rim of the round below and stands the next round inset, on a round plate that
bridges in over them. `Plan._ease` does that where a round of 6 or 8 has a
round a stud narrower standing on it (three plates or more, one colour, the
rim otherwise empty). *Round tops.* The 4 x 4 and 3 x 3 corner round tiles
are rings a stud wide (27507 inside radius 3, 79393 inside radius 2) and the
2 x 2 one (27925) a ring round a 2 x 2 round tile: nested, a round of 8's top
is smooth (a 6 x 6 round tile's cover is its square box, and the check reads
it as overlapping the ring). *Curved flanks.* On a shell (`Plan.flank`) a
cheese slope is scored 0.3 worse where a curved 2 x 1 fits a fall of a plate
a stud, except where the colour changes (a fuselage's canopy edge got a
curved slope held by nothing). *Side studs in runs.* A shell's side studs are
1 x 4s and 1 x 2s with studs on a side wherever lanes run in one colour, split
the same from either end so a mirrored side stays one.

Held-out again on these changes, on the subscription (`env -u
ANTHROPIC_API_KEY`, under `heavy`), measured by `tools/style.py` (`other` for
the owl, `vehicle` for the car):

| run | parts | shapes | colours | sideways | curved | plain | mirrored | side-stud bricks | curved slopes turned out | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn owl (`owl_r2`) | 1,036 | 56 | 11 | 20% | 10% | 69% | 87% | 82 (24 1 x 1) | 41 | 7, none apart |
| *last round (`owl_r1`)* | *1,313* | *49* | *11* | *19%* | *5.3%* | *64%* | *88%* | *176 (all 1 x 1)* | *0* | |
| sports car (`car_r2`) | 174 | 36 | 7 | 9.2% | 14% | 47% | 92% | 10 (all 1 x 1; built by hand) | 0 | 2: car, and the nameplate with its driver, named |
| *last round (`car_r1`)* | *544* | *46* | *6* | *16%* | *4.6%* | *53%* | *90%* | *100 (88 1 x 1)* | *0* | *2: the nameplate, loose* |

By eye (`shots/runs/owl_r2_{corner,front}.png`): the **owl**'s wings are
dark tan shells whose flanks round off in curved slopes where `owl_r1`'s
stepped in cheese wedges and tiles, the breast is a smooth white front, and
the body sits on a post on a stand with a plaque on its base; the run named
its body, head and stand as assemblies and they went into the file as
sub-models. Its head is still a stack of thin round plates with studs on
every ring: rings a plate or two tall are not eased (the round above must
be three plates for the core to stand in). It is 7 pieces that touch and are
not joined (said, not refused; not a landing-page candidate).
The **car** this time chose minifigure scale, 8 studs wide, and said its
body as a loft 3.5 plates tall over its arches; the shells turned its flanks
out and kept only 5 of their parts (a thin side has too little a side stud
can hold), the body came back 45 parts in five pieces where upright it is 74
in fifteen, and the run, judging the picture "eroded into a narrow strip",
built the car by hand, Speed Champions fashion: a red coupe with white
stripes, mudguard arches, a trans-black screen, a wing and lights
(`shots/runs/car_r2_{corner,front}.png`). The same loft laid by the code
before this round erodes the same way (51 parts), so it is not new. It then
added a nameplate in front with a driver holding a trophy on it, named both,
and was refused twice — the bug above, fixed after the run; its saved file
passes as a model and two named items, and is a landing-page candidate.

Left: shells on a thin body drop the flank they take out of the core (the
car's loft); easing thin rings (a dome of single round plates, the owl's
head); the owl's 7 unjoined pieces; a dome step wider than a stud; curved
slopes on a hull's straight-falling side; and an 11477 on its side is held
only where a stud reaches its solid end, which the shell's plan cannot
tell (the fuselage's canopy edge).

**A head without a hat, a model that lifts as one, a thin body kept
whole, a hull's bilge turned (2026-10-12).** Four of what the last round
left, each measured on probe bodies, then the owl and the car held out
again.

*An oval is not a round.* The owl's head was the run's own: its shape laid
the crown of a 13 x 11 oval as a round plate of 8 one plate thick with an
8 x 8 dish on it, and the run, judging "the flat disc on top of the head,
which reads like a hat", took it off and stacked round plates there by
hand, studs bare on every ring. A disc one plate thick where an oval body
passes through one is not a round section; it is now a round only on or
under another round about the same middle (`Plan._stacked`), and the oval
is laid by the plan: curved slopes falling off the crown and tiles. A true
dome's short rings are eased too: a round of 6 or 8 with a round a stud
narrower one or two plates tall on it lays its curved-slope rim and core
in that round's place (it was left a ring of bare studs unless the round
above was three plates).

| body | before | after |
|---|---|---|
| owl's head alone (two ellipsoids, as the run said it) | 369 parts; a round plate of 8 and a 3961 dish at the crown; 1 floating | 329 parts, buildable, one piece; no round plate, no dish; crown in curved slopes and tiles |
| squat dome 4 x 7 x 4 | three round plates of 8 under a 3961 dish: a tin with a lid | the 8's rim eased in eight 15068 and four corner tiles, a round of 4 and a 3960 dish |
| dome 4 x 12 x 4 | one step eased, a 44375b dish on the 6 | both steps eased (15068 x12) |

Pictures: `shots/d3/head_{before,after}_{corner,front}.png` and
`shots/d3/domes_{before,after}_corner.png` in this worktree.

*Why the owl was seven pieces.* Not its body: laid again as submitted, its
shape was one piece. Its base was a `fill` 20 x 16, two layers of plates,
and the fill tiled every layer of plates the same way, so the base was
columns of two plates each held only to the one over it; the post and the
body joined some, and the rest stood side by side, eleven pieces as
submitted and seven after the run's edits bridged a few. Plates over plates
are now laid the way of four (turned or not, from the near corner or the
far) that leaves the two layers in fewest pieces, never a plate exactly over
one under it (`Patterns._layers_apart`). The owl's submission: 12 pieces
before, 1 after. A round fill is still in pieces where its rim's wing
plates lie wedge on wedge (14 across, two plates: 7 pieces).

The check still says pieces against the model as a remark, now each with
where it is and how to join it, where it only counted them. Made a fault,
it failed 15 of `patterns_probe`'s models (round towers, octagonal shafts,
turrets, domes, cones, rock), 5 of `rooms_probe`'s shells, 6 worked
techniques, `dress_probe`'s wall and `rules_probe`'s one-layer wall: the
patterns themselves lay pieces that touch (a prism's faces against its
core, a column of side-stud bricks up a shaft). Those are to be joined
before it can refuse a design.

*A thin body kept whole.* The car's body, 8 wide and 3.5 plates over its
arches, lost two studs a side to shells that kept 5 of their 74 parts:
rows are laid a stud apart from the top, and on a body that short the
lower row reached below the shape and was dropped, its plates already
taken out of the core; the side studs found three plates behind the top
row only under the cabin. A shell is now tried before the core is laid and
given back (its plates, its clearance and its side studs) when its kept
parts cover less than 40% of what it took (the car's 13%; the egg, bird, hull and owl 55 to 94%, a side and its mirror judged together), and that side is laid upright;
so is one held by no side stud, which before kept its plates and laid
none. The run's loft alone: before 45 parts, across its middle z 2 to 5
(a strip four studs wide), 5 sideways; after 74 parts, z 0 to 7, laid
upright. The egg, the bird and the hull keep their shells
(`shapes_probe`). Not done: a shell made for a thin body (plates and tiles
on side studs, rows fitted to its height), so the flank is smooth rather
than upright plates. Pictures: `shots/d3/car_{before,after}_corner.png`.

Held-out again on these three, on the subscription (`env -u
ANTHROPIC_API_KEY`, under `heavy`), measured by `tools/style.py` (`other`
for the owl, `vehicles` for the car) and `candidate_probe`:

| run | parts | shapes | colours | sideways | curved | plain | mirrored | pieces |
|---|---|---|---|---|---|---|---|---|
| barn owl (`owl_d3`) | 613 | 53 | 11 | 32% | 9.3% | 47% | 79% | 1 |
| *last round (`owl_r2`)* | *1,036* | *56* | *11* | *20%* | *10%* | *69%* | *87%* | *7* |
| sports car (`car_d3`) | 120 | 35 | 7 | 3.4% | 13% | 46% | 100% | 1, and the driver, named |
| *last round (`car_r2`)* | *174* | *36* | *7* | *9.2%* | *14%* | *47%* | *92%* | *2, named* |

By eye (`shots/runs/{owl,car}_d3_{corner,front,close}.png`): the **owl**
kept its shapes — an ellipsoid body with a loft for a tail, an ellipsoid
head, a rounded box for a stone post — on a grassy base two plates thick
that is one piece, and the whole owl is one piece and a landing-page
candidate where `owl_r2` was seven. Its face and breast it laid as
`studs_out` panels of white tiles, flat, and its head reads boxy, a round
with studs on its crown; four of its submissions were refused first, each
for curved slopes on a shell held by nothing or standing on a cheese slope
(the 2 x 1 curved slope on its side, the last round's open problem). Plain
fell from 69% to 47% and sideways rose to 32%; it is smaller. The **car**
said its body as a shape once, a 5-plate extrusion over arches cut nearly
to its top; the shells kept 43% of their plates each (so were kept), its
nose came away in 14 parts held by nothing, and the run judged it "ragged"
and built a red mid-engine coupe by hand, Speed Champions fashion, with a
trans canopy, a wing on a hinge and a black diffuser — one piece, a
candidate. One run each.

Left: a shell for a thin body that lays its flank smooth (plates and tiles
on side studs, rows fitted to its height), and its nose kept joined; a
hull's bilge turned out in curved slopes (not started); the 2 x 1 curved
slope on its side held by nothing; touching-but-unjoined as a fault, once
the prisms, round towers, domes, rock and rooms the patterns lay are joined
themselves; a round fill's rim wedges stacked wedge on wedge; an oval
head's crown and a face in tiles that read round.

## Real sets' own pieces, found by what they are (2026-10-12)

Asked for "an intelligent builder that knows how to use these advanced
building structures like an expert human", the assistant had seventy-odd
worked constructions chosen by hand. An expert asked for an owl's eye does
not reach for the nearest of seventy: they remember how a set built one.
LDraw's model repository has the sets part by part, and its modellers
split them into named sub-models — Eye L, Beak, Bonnet, Grille, Wing,
Tower Roof.

**The corpus.** `tools/omr.py fetch --themes all --min-parts 30` takes
every theme but the unsculpted ones (Duplo, Fabuland, Znap, mosaics, bins
of loose bricks, robotics), one request a second, nothing twice: **1,266
sets in 1,576 model files** (252 sets before), 526,000 parts by their
inventories, 768,000 placed in the files. 59 files are free for
non-commercial use only and are left out of everything built from them.

**The index**, `tools/snippets.py build` -> `assets/knowledge/snippets.json.gz`
(2.3 MB, shipped in every export): **9,555 named sub-models of 2-60
building parts and 3,412 clusters of craft** (three a model, round
brackets, hinges and slopes, `omr.found_clusters`), from 1,185 sets by 76
modellers, every one credited, CC BY 2.0 and 4.0 only. Each with its size
in studs, its parts and colours, its kinds by `tools/style.py`, and the
LDraw to lay it as built; 10,699 are square to the grid and can be laid
by `place_technique`, the rest are shown to copy. Search is lexical, BM25
over the name, what it sits in, a description, synonyms and kinds, and
the set; the subject's own sets first, then sets about its kind. No
vector database: whether embeddings would earn a place is what the recall
below is for. The app reads the index in 2.6 s the first time a design
asks (desktop).

**The tools.** `find_techniques(query, max_studs?, kinds?)` answers with
the best five, credited, with a picture of them side by side;
`place_technique(id, x, y, z, turn?, recolor?)` lays one through
`edit_model`, so the joints checker refuses it like any edit;
`find_parts_like(query)` finds parts by what they read as. All three
reach the in-app loop, My Claude and MCP. The rules' step 5: before
inventing a feature, look at how real sets built it.

**What placing showed.** On a plate, an eye (4349 Wild Pod), a car nose
(Fire Rescue's), a wing (31049) and a turret roof (10214) lay whole and
joined. Many real pieces do not stand alone, so every square one was laid
alone and checked (`src/dev/snippet_verdicts.gd`, 12 ms each): **4,487 of
10,699 lay whole as they stand**; 2,770 have a part that floats (held by
something outside the sub-model when it is cut out), 2,387 float and
overlap, 650 only overlap — some real, some the checker's known false
positives (a curved slope seated on the stud of a part below, clips on
bars), which refuse 31031's parrot beak. The verdict is in the index:
search counts a piece that lays 1.25 times, and `find_techniques` says
of each whether it lays or why not.


## Long term: custom elements

A LEGO designer can ask for a new element, or a change to one. Brickworks
should let its designer do the same: a part editor that makes real LDraw
geometry, keeps to the system's dimensions and moulding rules (1.6 mm walls,
4.8 mm studs, the clutch), gives the part its connection points, and puts it
in the catalogue, the checks and the design loop.

**First version, 2026-10-10** (`docs/custom-elements.md` has what is known
of LEGO's own process, with sources). Make a part… in the parts bin makes
bricks, plates, tiles, slopes, inverted slopes and round parts of any size,
or resizes a plain library part, as unofficial LDraw parts drawn from the
library's primitives. The app builds them with a port of the mesh build
that matches it byte for byte, so they clutch, collide and check like any
part, and a saved model carries them inside it.

**Second version, 2026-10-11.** The families a modern set is built from:
bricks with studs on any side, brackets up and down, curved slopes, and
Technic bricks with holes — each standard size with its library part's
bounds, studs, holes and tubes (87087, 30414, 99781, 99780, 44728, 3700,
3701), the hole merge and bore clearing now ported so 3700 and 3701 match
the pipeline byte for byte. A part that exists can be changed rather than
redrawn: any part, from its own built mesh (so in a browser too), made
longer, wider or taller by repeating a slice of it where its cut faces
match, its studs taken off or put on, a piece cut out with its cut faces
capped and its hollow walled; 3700 made six long is 3894 to the connector
and the collision cell, a corner cut out of 3003 has 2357's studs, and a
part with no slice to repeat is refused in words. And the design loop makes the parts it lacks: `make_part`, in the
assistant's tools and every MCP session's, makes a family part or changes a
real one through the same rules a person's part goes through, and the
design builds with it.

**Third version, 2026-10-11: prints and stickers of one's own.** The
parts bin's "Print…" and the figure builder's "Draw a print…" paint — or
bring in a photograph or an SVG logo, placed, cropped, turned and mapped to
LEGO's inks — a face, a torso front and back, a pair of legs with their
hips, or any face of any part (a tile, a slope, a dish's curved top) on a
canvas that is the part's printable area, the part wearing it as it is
drawn; saved as a real LDraw part with !TEXMAP and its picture carried in
the model as !DATA, which LDView draws as the app does. "Stickers…" lays a
sticker of its own over the faces it is clicked on, across two parts if they
lie in one plane, and prints the model's sticker sheet as a PDF whose cut
lines measure to within 0.01 mm of the sticker. And moulds: "Make a mould…"
sculpts a hair piece, a helmet or something to hold — push, pull, smooth,
inflate, pinch, a lattice, symmetry — from the part or from a dome or a club,
its socket and its grip bar locked to the float, nothing pushed into the
head, its walls checked. Next: families with clips and bars (the checker's
round joints need the catalogue's rounds), wedge plates, cut-outs that are
not boxes (a cut through a round part is closed in 2 LDU steps), axle holes
in the app's build, and draft and wall checks for a part a mould designer
could take.

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
