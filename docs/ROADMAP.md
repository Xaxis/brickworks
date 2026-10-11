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
    yet (lever 4 above).
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
part, and a saved model carries them inside it. Next: the design loop asking
for a part it lacks (a tool that makes one), families with clips, bars and
Technic holes (the hole merge is the one piece of the pipeline not yet
ported), and draft and wall checks for a part a mould designer could take.

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
