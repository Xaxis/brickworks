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
| **the model** | ~180 shapes, ~23 colours at 1,200 parts | 95 shapes, 10-13 colours; the gap, below |
| **its parts** | named sub-assemblies, bag by bag | assemblies named by the design, kept as `.mpd` sub-models |
| **the booklet** | built a sub-assembly at a time, pictured close | built and framed by those assemblies; `--booklet` writes one |
| **the parts list** | element numbers you can order | CSV with element numbers; the `.mpd` imports into Rebrickable to buy |
| **any subject** | castles, cities, ships, vehicles | castle, fire station and space cruiser all hold; angled structure is the weak joint |

The model is the weakest link by a distance, which is why the levers
below are all about it. When it is within reach of a real set, the next
link to look at is the booklet's pictures — whether a person can follow
350 of them on a table — measured the same way, by building from one.

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
| 7, siblings told what the others got | 803 | 33 | 6 | 162 |
| 8, and thin passes sent back once | **1,895** | 53 | **13** | 361 |
| 9, the same, again | 818 | 58 | 9 | 122 |
| 10, and told the ordinary parts | 1,178 | 64 | 9 | 133 |
| 14, told the 100 most used | 1,120 | **71** | 12 | 216 |
| 15, and the one-off count | 828 | 56 | 7 | 112 |
| 16, the count in the send-back | 1,159 | **95** | 10 | 213 |
| 17, and the accents named | 797 | 57 | 9 | 139 |
| 18, sent back on the model's one-off tail | 1,077 | 78 | 10 | 364 |
| a real set of 1,828 parts | — | **262** | **28** | 90 |
| a real set of 975 parts | — | 180 | 23 | 43 |

Previous project best was 456 parts. Scale is no longer the constraint.
**The whole remaining gap is one number: 95 shapes at best where a real
set of that size has 180** — and 95 is the first castle out of the thin
tail of real sets its size. Colours are 13 against 28 at best. Everything below
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

   *Tried in run 7, unproven:* each pass is now told what earlier passes
   brought to the model and which kind parts are nowhere in it yet, and
   asked to stop only once the assembly reads as detailed as a set its
   size. Shapes went 30 -> 33. But the four tower passes never got to
   detail: up close, each found its tower built inside-out (every 48092
   turned so the shaft bowed inward) and spent the pass turning them
   half a turn. A real fault the whole look had missed, caught by the
   close one — and towers that added no new part leave nothing for the
   next sibling to be told about. One run; the mechanism is in and
   measured nothing yet. Towers under 60 parts also get no size norm,
   because the smallest band starts there.

2. **More than one idea per pass — first evidence it works.** Every pass
   in runs 5 and 6 made one change and stopped, with eight turns in hand.
   Run 8 sends a pass back once when it says it is done and its assembly
   is still thinner than all but one real set in twenty of its size
   (`sent the keep back` in the log). Five of nine were sent back, four
   of them added shapes on the second round, and the passes took the
   model from **23 shapes to 53** — the first doubling, and the roadmap's
   own bar. Its towers also came out different from each other (16 to 19
   shapes each, four different crowns), where runs 5-7 made four copies.
   **Repeated in run 9: the passes took it from 34 shapes to 58**, the
   most yet. Two runs, 2.3x and 1.7x, against 1.1-1.5x for runs 5-7
   without it. This lever holds.

   **And it is not a castle trick.** The fire station brief (a building
   with floors, not a walled compound) came out 669 parts, **62 shapes**
   and 15 colours, its passes taking it from 39 shapes to 62 — against 30
   shapes for the station that ships with the app. For a set of 669 parts
   thin is below 54, so **this is the first design out of the thin tail of
   real sets**. The median is still 123.

3. **The ordinary parts — measured 2026-10-09, and it works.** The kind
   lists say what makes a castle a castle, by lift. They cannot say what a
   castle is mostly made of: a real 1,895-part castle has some 260 shapes
   and most of them are ordinary. The best castle had **24 of the 40 parts
   castle sets use most**, run 9 had 22 — no 1 x 1 plate, no 2 x 3 plate,
   neither jumper, neither cheese slope, each in more than half of castle
   sets. Each kind now carries `common`, its most used parts by the share
   of its sets using them, and each pass is told the ones the whole model
   has none of yet. (Counting this found the old counts were of lots, not
   sets: the castle's "share" of 1 x 2 plates came to 346%.)

   **Run 10: 37 of the 40**, against 24 and 22, and 64 shapes — the most
   any castle has had. With the list at 100, **run 14 used 54 of the 100**
   (run 10, 48; run 8, 35) and came to 71 shapes, its passes taking it from
   25 — nearly three times. It is aimed at the gap and closes most of it: what
   is left between 64 and 180 is no longer the ordinary parts.

   **Where the rest of the gap is, measured:** a real set of 800-1,500
   parts has a median of 177 shapes, and **85 of them are used only once
   or twice**. Run 14 had 71 shapes and 21 such; its shapes used many
   times (about 39 against a real set's 57) were close. Nearly the whole
   remaining gap is one-off pieces. Each band now carries that count and
   each pass is told the model's own against it. **Run 15: 13 such
   shapes, against run 14's 21 — told the number, nothing moved.** The
   likely reason is symmetry: a detail added to four towers is a part
   used four times, never once. A sentence in a long pass message did
   not act; the one lever that reliably has is the short send-back, so
   the count goes there next. **Run 16, with it there: 54 one-off shapes
   (21, then 13 before) and 95 shapes in all**, its passes taking it from
   22 — more than four times. The first castle outside the thin tail of
   real sets its size. One run; repeat it.

   **And a caution from looking at it:** run 16 (95 shapes) reads plainer
   at a glance than run 14 (71) — square towers alike, a bare courtyard —
   because its one-off pieces are small, and what carries the picture is
   the big read: run 14's great hall and four different crowns. The count
   measures texture, not whether a model reads as the thing. Keep judging
   both: the number, and the picture.

   **Run 17 fell back — 57 shapes, 17 one-off — and why is in the log:**
   its towers came out rich on the first try (20-22 shapes each), so no
   pass was thin, none was sent back, and the one message that moves
   one-off pieces never ran. It rode on thinness. A pass is now sent back
   also when the whole model's one-off count is on the tail of real sets
   (fewer than 31 at 800-1,800 parts) — every model but run 16 was. Each
   pass is also told, by name, the accents real sets of the kind use one
   or two of: a goblet, a torch, a hinge, a bracket. Run 18 measures both.

   **Run 18: 78 shapes and 41 one-off, and the log shows the mechanism.**
   Every pass was sent back, and the whole model's one-off count rose with
   each: 7, 13, 18, 25, 34, 40. With the count in the send-back, runs 16
   and 18 reached 54 and 41 one-off shapes; without it, runs 14, 15 and 17
   had 21, 13 and 17. This one holds.

   **But the pictures say the next lever is not texture.** Run 18 (78
   shapes) and run 16 (95) both read plainer than run 14 (71): an empty
   courtyard, towers alike in silhouette, little colour. Their one-off
   pieces are small things on tower tops. What makes run 14 read as a set
   is the big read — a great hall filling the courtyard, four crowns of
   different shapes, a red roof — and that is fixed by the first
   structure, before any pass. Nothing measures it yet. **Next: find a
   measure of the big read** (how much of its own footprint a model
   fills, how far its siblings' silhouettes differ, how much of it is the
   main colour) the way the shape count was found, by comparing real sets
   with these runs, and aim the whole look at it.

   *Checked and not the gap:* minifigures, stickers and printed parts.
   Rebrickable lists minifigures apart from part inventories, and leaving
   out stickers and prints moves the medians 3% (180 to 173). The 180 is
   real, buildable variety.

4. **A surface-treatment vocabulary, measured rather than invented.**
   `kinds` says *which* parts a castle reaches for. Nothing yet says
   where they go, and "a wall wants masonry bricks, an arrow slit, a
   corbel course and a tile walkway" is currently my taste. The data to
   replace that is already downloaded and unread: part **co-occurrence**
   within sets. **Needs: a measurement of which parts appear together,
   conditioned on kind.**

5. **Colour as structure.** 13 against 28 at best. The kinds data gives each kind
   its palette by lift; nothing says a second colour belongs at a string
   course, a lintel, a roof band. Likely falls out of (3).

## A third kind, and the first failures

The space cruiser brief failed twice (runs 11 and 12), on the one thing
the castle and the station never needed: **angled pylons**. Each spent
its repairs placing an engine pod against the hull's side — one measured
its starboard pylon 0.8 studs inboard, moved it, and was a hairline out
the other way — and each ended with nothing kept, the second with 639 of
641 bricks holding. Three fixes, each proven by a probe:

- **What holds is kept.** When repairs run out and floating is the whole
  complaint, covering at most a quarter of the design, those bricks are
  left out, the rest is checked again, and the run goes on to its look,
  told what went so it can put it back.
- **The sideways offset is measured, not guessed.** The check named the
  height at which a turned section meets and, when none did, said "move
  it in x or z". It sweeps x and z now, a tenth of a stud at a time.
- **A failure is written down** (`user://failed_design.json`) with the
  brief, so it can be read back through the same check.

The brief also exposed the kind lookup: "engine pods" brought fire-engine
ladders and "pod" X-Pod storage tubs, with space pushed out for having
more sets. Kinds are taken in the order the brief names them now. A
filter for a later kind that does not suit the subject ("bridge tower"
still brings castle towers to a spaceship) was looked for and is not in
the data: sets rarely name two kinds together, and kinds' most used parts
overlap as much for space and tower (0.56) as for space and cruiser (0.53).

**Run 13, with the fixes: the cruiser holds** — 619 parts, 49 shapes, 10
colours, its passes taking it from 33 to 49. It still fought the pylons
in its trial checks and in the end laid its pods flush.

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

**Pictures in software, 2026-10-09.** This machine leases its one GPU a
job at a time, and a design run held it for twenty minutes while it
waited on the API. Run 8 rendered every picture in software at load ~80
with none missed; `tools/design.py` is software unless given `--gpu`.

**Cost, fixed 2026-10-09.** Run 6 spent $9.67 on Opus 5.5 at high
effort, and $8 of it was input tokens sent fresh: 2.04M against 575k
read from the cache, because only the rules were cached and old pictures
were rewritten every turn. With the conversation cached and pictures
kept until they add up, run 7 spent **$3.99** on a longer run: 82 tokens
fresh, 3.53M from the cache. Passes are now cheap enough to add more.

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
