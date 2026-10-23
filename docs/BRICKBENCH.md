# BrickBench: the designer on an outside ruler

Run on **2026-10-14**. Until today every claim about our designer rested on
our own judge ([DESIGN_SCORES.md](DESIGN_SCORES.md)). BrickBench (Kulits et
al., October 2026; MIT code at [kulits/BrickAgent][bb-repo], gallery at
[gallery.brickben.ch][bb-gallery]) ranks 13 AI LEGO® designers on 300 prompts,
and it is the only outside ruler there is ([RESEARCH.md](RESEARCH.md), unit 1).
This puts our designer on ten prompts of its Model setting, locally, the way a
system is submitted.

**Nothing was submitted.** The submission zip is ready, checked by their
`check_submission.py`, at
`bench/results/brickbench-2026-10-14/submission.zip` in the main checkout
(git-ignored, 0.03 MB). Sending it through their form is the owner's call.

**What was not run.** Their VQA and their ELO are judged by Gemma 4 31B, which
needs about 62 GB of GPU memory; this machine has 12.9 GB. So the comparison of
quality below is **our** pairwise judge, not theirs, and it is labelled so
everywhere it appears.

## The headline

| system | valid (verify.py) | VQA | Design ELO | cost a build | time a build |
|---|---|---|---|---|---|
| Claude Opus 5.5 in BrickAgent, their Table 1 (Model setting, 100 prompts) | 1.00 | 0.952 | 1252 | $5.90 | |
| the same system's builds of these ten, from their gallery, verify.py run here | **1.00** (10 of 10) | | | | |
| **Brickworks, these ten** | **0.20** (2 of 10) | not run | not run | $2.65 at API prices, $0 billed | 10 min |
| **Brickworks, these ten, the check as strict as verify.py** (`6bbe717`, evening) | **0.90** (9 of 10) | not run | not run | $0 billed | 7 min |
| **Brickworks, ten held out** (model-011 to 020, the same) | **0.80** (8 of 10) | not run | not run | $0 billed | 12 min |

- **Valid: 9 of 10 since the evening's check, 8 of 10 held out** ("the check
  made as strict as BrickBench's", below). The morning's run, before it:
- **Valid: 2 of 10.** Their verify.py passed model-001 and model-004 and
  failed the other eight: seven on collisions BrickNet's colliders see and our
  check forgives, one on pieces that fall. Their Opus 5.5 builds of the same
  ten all passed the same verify.py here.
- **Our pairwise judge preferred their build on every prompt**: 0 of 40
  verdicts overall for ours (95% 0-9%), every order, every repeat. Ours came
  closest on colour and creativity, 7 of 40 each.
- **Cheaper**: $2.65 a build at API prices (nothing billed, on the
  subscription) against their $5.90, in 10 minutes on average.

## How it was run

**The ten prompts.** The first ten of `benchmark/model/tasks.json`, in file
order (model-001 to model-010), at BrickAgent `b3df55e`. Not chosen: they are
whatever came first. They happen to be ten character vignettes (knights, a
throne, a duck, a penguin, a dog in armour, a cloaked figure on a bench, a
knight on a blob), which is a narrow slice of the 100.

| task | prompt |
|---|---|
| model-001 | A black-armored knight’s helmeted torso sits upright with a tiny wooden bridge behind his back. His two arms, two legs, and sword lie separately on the ground around him. His visor remains closed. |
| model-002 | A squat knight in bright-blue armor wears a helmet with two large ivory horns. He grips a broad shovel like a sword, with one foot planted on a small mound of dirt containing a red gem. |
| model-003 | A round blue knight wears a silver mask with narrow yellow eye openings. Purple bat wings spread behind him, and he holds a golden sword with a jagged blade. His feet are planted wide apart. |
| model-004 | A short, black-haired lord in a red hat and red tunic sits on an enormous throne. His boots hang far above the floor. A long red carpet leads up three steps to the seat. |
| model-005 | A dark metal throne stands on a low stone dais. Its tall back is a fan of overlapping sword blades, and more swords form the armrests and legs. Three shallow steps lead up to the empty seat. |
| model-006 | A white duck with severe black eyebrows stands in a knightly fighting pose. It grips a green leek three times its height like a lance and holds a broad round leaf as a shield. The cut white end of the leek points forward in the direction the duck faces. |
| model-007 | A round blue penguin in a red fur-trimmed royal robe holds a wooden hammer larger than his entire body. He wears a red cap with a white pom-pom. One yellow foot is planted on a tiny overturned throne. |
| model-008 | A brown dog’s muzzle pokes from the raised visor of an oversized suit of gray armor. His blue collar shows above the breastplate, while his long tail sticks out behind. He holds a shield backward, and one floppy ear hangs outside the helmet. |
| model-009 | A tiny figure in a black cloak sits on a curved black bench, its white mask topped by two long horns. A nail-shaped sword longer than its body leans against the bench. An ornate streetlamp arches overhead, and pale mushrooms grow beside one bench leg. |
| model-010 | A tiny silver-armored knight rides a large smiling green blob. The rider raises a short sword and carries a yellow shield, while his boots dangle above the ground. The blob bulges outward beneath him, with two round eyes and a broad red smile. |

**The design.** Each prompt went through the real loop on the subscription,
the way `tools/bench/run.py` runs its subjects: the app off-screen under
`heavy` with `--ask-claude-code`, Claude Code (Opus 5.5) driving it over MCP,
`ANTHROPIC_API_KEY` taken out of its environment, 45 minutes at most, two at a
time. One design a prompt, as their protocol has it. The brief was the prompt
and the setting's own limit in its own words, "Use at most 400 pieces.", as a
person would type it. BrickAgent's agent was given more: their whole
`prompt.md`, with the API, the checks it must pass and how it would be judged.

**The parts.** The Model setting allows BrickNet's 14,441 parts only: under
half of our catalogue, with no stickers and no unofficial parts. The least
invasive way to enforce that was a list the app reads only when a run passes
`--parts-only=FILE` (`src/parts/parts_only.gd`): search_parts and
find_parts_like list only those parts; a design or an edit with any other is
refused, naming the part and asking for a swap; add_minifig chooses among
them; make_part, lay_flex and print_part are refused; and any call that leaves
one on the model says so. Without the flag the app is as it was
(`parts_only_probe` checks both). It worked: 10 checks or edits were refused
for a part off the list across the ten, every one was swapped, and every
export had no part off it.

**The export.** `tools/bench/brickbench.py export` flattens each design and
writes the `build.py` their `verify.py` rebuilds: every part where the design
put it, through `Assembly.add` with a `Pose`, each rotation made exactly
orthonormal (brickagent refuses one off by more than 1e-8, and LDraw's own
minifigure hand matrix, written to three places, is off by 1e-3; the largest
change to any entry was 0.001). The `model.mpd` is the one that build
writes, so verify.py finds them the same (`mpd_geometry_reproduced` on all
ten). `tests/test_brickbench.py` holds a known LDraw placement, a sub-model
turned and moved with colour 16 inside it, to the position, rotation and
colour that come out of `build.py`.

**The check.** Their `verify.py`, unchanged: part limits, BrickNet's convex
colliders at 1 LDU, and every connected piece under gravity in PyBullet for
two seconds. It was first run on their own ten builds from the gallery, and
passed all ten, as they published. So the faults it names in ours are ours.

## verify.py on each build

| task | ours | parts | pieces | colliding pairs | unstable pieces | theirs | parts | pieces |
|---|---|---|---|---|---|---|---|---|
| model-001 | valid | 105 | 1 | 0 | 0 | valid | 125 | 1 |
| model-002 | **no** | 133 | 2 | 7 | (1) | valid | 136 | 1 |
| model-003 | **no** | 132 | 2 | 1 | (1) | valid | 38 | 1 |
| model-004 | valid | 243 | 1 | 0 | 0 | valid | 210 | 1 |
| model-005 | **no** | 208 | 3 | 9 | (2) | valid | 201 | 2 |
| model-006 | **no** | 216 | 7 | 9 | (4) | valid | 98 | 1 |
| model-007 | **no** | 96 | 7 | 0 | 4 | valid | 184 | 1 |
| model-008 | **no** | 270 | 1 | 14 | (0) | valid | 169 | 2 |
| model-009 | **no** | 62 | 3 | 1 | (2) | valid | 79 | 1 |
| model-010 | **no** | 86 | 6 | 5 | (4) | valid | 62 | 4 |

verify.py stops at the collisions: it simulates stability only once there are
none. The figures in brackets are from running its `check` again with
stability on regardless, to see whether a build would also have fallen.

## Our pairwise judge against BrickAgent's Opus 5.5

**This is our judge, not BrickBench's.** It is `tools/bench/pairwise.py`
([DESIGN_SCORES.md](DESIGN_SCORES.md), "Judged in pairs"): Claude Opus 5.5
through Claude Code on the subscription, with the Read tool only, asked A or B
on six dimensions and overall, with a sentence of reason each. BrickBench's own
judge is Gemma 4 31B, shown four views of each build and asked about prompt
alignment and design; its numbers for these builds are unknown until the
authors score ours.

Both sides of every pair were drawn by our renderer (`bench_views.gd`, on
lavapipe) from the same four cameras: the two three-quarter views and the
front and back. Each was given the prompt as the brief, no references, and its
own verify.py verdict in words as its build check. The pictures were copied
under six-letter names, so nothing in a file name says whose build it is.
Every pair was asked in both orders, and every order twice: 40 verdicts, each of
which opened all eight pictures, about 19 seconds each.

| dimension | Brickworks ELO (95%) | Opus 5.5 ELO (95%) | verdicts for Brickworks | prompts won in every verdict / split / lost in every verdict |
|---|---|---|---|---|
| likeness | 701 (559-788) | 1299 (1212-1441) | 1 of 40 (2%), 95% 0-13% | 0 / 1 / 9 |
| surface | 788 (559-894) | 1212 (1106-1441) | 3 of 40 (8%), 95% 3-20% | 0 / 1 / 9 |
| colour | 868 (559-965) | 1132 (1035-1441) | 7 of 40 (18%), 95% 9-32% | 1 / 2 / 7 |
| technique | 559 | 1441 | 0 of 40, 95% 0-9% | 0 / 0 / 10 |
| creativity | 868 (754-927) | 1132 (1073-1246) | 7 of 40 (18%), 95% 9-32% | 0 / 4 / 6 |
| buildability | 559 | 1441 | 0 of 40, 95% 0-9% | 0 / 0 / 10 |
| **overall** | **559** | **1441** | **0 of 40, 95% 0-9%** | **0 / 0 / 10** |

Bradley-Terry over all forty, as their `elo.py` fits it, with half a virtual
tie between the two; the intervals resample the ten prompts. Where every
verdict went one way (technique, buildability, overall) no resample can move
it, and the gap of 882 is set by the half tie, not by the data: read those rows
by the share, nothing for ours in 40. The judge was consistent with itself:
on overall, the two orders and the two repeats of each prompt all named the
same build.

What it said, overall, one prompt at a time (one of its four reasons each):

| task | its reason |
|---|---|
| model-001 | "B is a recognisable, colourful and well-made display of the knight in pieces by the bridge, while A is crude and hard to read." (ours was A) |
| model-002 | "B is a valid build that reads clearly as the horned knight with a shovel and his foot on the gem mound, which outweighs A's more accurate blue and smoother helmet when A fails its build check." (ours was A) |
| model-003 | "B is a recognisable and well-built round bat-winged knight that passes the build check, while A is a crude brick-wall build that fails it." (ours was A) |
| model-004 | "B reads as a grand throne room with a richer colour scheme, better details and a lord who matches the brief, so a designer would rather ship it than A's plain brown box." (ours was A; both valid) |
| model-005 | "B is a valid build with a striking sword-fan throne, a red carpet and tiled steps, so it is clearly the one to ship over A's invalid, boxy throne." (ours was A) |
| model-006 | "A is a valid, characterful knight duck that matches the brief, while B's garden scene does not make up for a blocky duck with a leek running through its body and a build that fails the check." (ours was B) |
| model-007 | "B is a recognisable, sturdy, well-detailed royal penguin holding his mallet, while A is a crude, disconnected stack that barely reads as the subject." (ours was A) |
| model-008 | "B is valid and reads clearly as a dog in oversized armor with every detail from the brief, while A is blocky, fails its collision check and gets the tail and the backward shield wrong." (ours was A) |
| model-009 | "B is a valid, recognisable vignette that matches the brief, with an ornate lamp, a leaning sword and the mushrooms, whereas A is crude, has loose pieces and misses the sword leaning against the bench." (ours was A) |
| model-010 | "B is a clean, valid build with a smooth bulging smiling blob and a knight raising his sword, which beats A's boxy, invalid slab." (ours was A) |

## Cost and time a build

On the subscription nothing is billed. The dollars below are Claude Code's own
price for the tokens each session used (`total_cost_usd`, which the app now
prints at the end of a command-line design), so they compare with their $5.90.

| task | minutes | replies | tokens in (cached) | out | at API prices | refused for a part off the list |
|---|---|---|---|---|---|---|
| model-001 | 4 | 11 | 0.8M (0.7M) | 19k | $1.19 | 0 |
| model-002 | 11 | 50 | 6.4M (6.2M) | 56k | $3.39 | 2 |
| model-003 | 14 | 47 | 6.1M (6.0M) | 68k | $3.63 | 0 |
| model-004 | 8 | 26 | 2.5M (2.4M) | 29k | $1.67 | 0 |
| model-005 | 19 | 77 | 11.3M (11.2M) | 87k | $5.44 | 2 |
| model-006 | 13 | 58 | 7.6M (7.4M) | 54k | $3.74 | 1 |
| model-007 | 8 | 25 | 2.4M (2.3M) | 36k | $1.79 | 2 |
| model-008 | 13 | 40 | 5.5M (5.4M) | 68k | $3.52 | 2 |
| model-009 | 4 | 12 | 0.9M (0.8M) | 20k | $0.86 | 0 |
| model-010 | 5 | 23 | 1.9M (1.9M) | 22k | $1.33 | 1 |

Mean **$2.65** and **10 minutes** a build, against their $5.90: under half
their cost. Their time a build is not published.

## What lost, and why

**Validity: placements our check forgives and BrickNet does not.** Our own
check accepted every part of the eight as it went in. Our check is a
2 LDU lattice that forgives joints and lets a part rest where it fits; their
`check` wants every part where a connector puts it, its convex colliders
overlapping by at most 1 LDU, and every piece held by a connection or standing
on the ground. The 46 colliding pairs (from their `clashes`, read by part):

| what collided | pairs | builds |
|---|---|---|
| a brick 1 x 2 with two studs on one side (11211) against its neighbours: its side studs pushed into the next brick | 12 | model-006, model-008 |
| hinge plates 1 x 2 (3937 and 3938) against each other and the plate beside them | 11 | model-005, model-008 |
| horns (2142) threaded on a Technic axle, and on a round plate | 6 | model-002 |
| minifigure parts: a fez on a head, a sword in a hand, a baby head in a torso, a visor on a cap | 4 | model-006, model-010 |
| round bricks 2 x 2 (3941) sitting into the plate under them | 4 | model-006 |
| tiles set on side studs 2 LDU off them (30414 with 3070b, 5520) | 3 | model-006, model-010 |
| crystals and gems set into a round plate or a slope, 4 LDU off its stud | 3 | model-002, model-005 |
| a bat on a plate, leaves on a round plate, a dome on a round plate | 3 | model-003, model-006, model-009 |

verify.py stops at collisions, so these hide a second fault: run again with
stability on regardless, six of the seven also have pieces that fall:
decorations and figure parts resting on a part without a connection (a gem, a
bat, crystals, the duck's leek of round bricks and its wings, tiles, a lamp's
arch, a figure's head and visor). model-007 fails on that alone: four round
1 x 1 tiles lying on a round 8 x 8 plate without a connection.

None of this is a quirk of the export: the parts are where our model file put
them (`tests/test_brickbench.py`), and the same verify.py passes all ten of
BrickAgent's builds. The two builds that passed were built of ordinary
stacked parts (a throne and steps; a knight's pieces on a baseplate).

**Design, by our judge: blocky statues on big plates, against shaped parts and
real figures.** The judge's words for ours are "crude", "blocky", "a plain
brown box", "a brick-wall build", "a loose, blocky totem". Ours built the
characters as brick statues (a knight's torso of black bricks, a duck of
white bricks, a penguin of stacked round plates), and stood model-001's scene,
a few studs high, on a 48 x 48 baseplate. BrickAgent's built them at
minifigure scale from real minifigure parts with prints, or from large shaped parts (dome halves, curved
slopes, a wing pair), on a compact base sized to the scene. Ours won verdicts
only on model-002's colour and surface (all four on colour: "truer bright-blue
colour and smoother curves") and on creative touches in four prompts, and the
judge still shipped theirs every time, our two valid builds included. Where
ours failed its check, the judge named that first, as BrickBench would: there
an invalid build scores 0.

Two things about the comparison cut against ours. BrickAgent's agent was told
how it would be judged and that it must pass `check`; ours was given the
prompt and the piece limit, and checked its work with our check, which is not
theirs. Both are one run a prompt.

## What would most improve the score

In order, each measurable by running this again.

1. **Check like BrickBench inside the loop.** Validity is worth more than
   everything else here: an invalid build scores 0, and 8 of our 10 were
   invalid while all 10 of theirs passed. BrickAgent's agent gets to 1.00 by
   running the same `check` until it passes. Ours never saw that check. Its
   three rules are what ours lacks: a part seats only where its connectors
   meet another's exactly (the crystals and tiles above are 2-4 LDU off their
   studs); a side stud, a hinge or an axle through a part may not put solid
   into solid, which our lattice forgives as a joint; and every piece is held
   by a connection or stands on the ground. BrickNet's connector labels are
   MIT and cover the same 14,441 parts ([RESEARCH.md](RESEARCH.md)); the
   quickest trial is the
   `--parts-only` pattern again, a bench flag that runs their `check` on the
   model after each change and refuses what it refuses.
2. **Build characters as the LEGO Group's sets do at this size.** Every one
   of these prompts is a character, and the judge's word for ours was
   "blocky". Theirs used minifigure parts with prints, dome halves and curved slopes at
   minifigure scale; ours stacked bricks into statues. The design memory and
   the worked constructions have no character subjects yet: a held-out
   character subject in `tools/bench/suite.py` would measure this.
3. **Size the base to the scene.** Ours stood model-001's scene, a few
   studs high, on a 48 x 48 baseplate, and model-004's on a 32 x 32, which
   every view then shows as a wide empty field.

Then send the zip, which is the only way to learn our VQA and our ELO on
their judge.

## 2026-10-14, evening: the check made as strict as BrickBench's

Lever 1 above, done. Our check now judges a part by BrickNet's own shapes,
so a design it hands over is one `verify.py` passes.

**What the check reads.** `tools/build_exact.py` converts BrickNet's convex
colliders and connector labels (MIT, Kulits and Schmid; the colliders are
decompositions of LDraw parts) into one small file a shape,
`assets/generated/exact/<mesh hash>.bwx`, beside the part's geometry: 15,417
shapes for the 14,583 BrickNet parts and their aliases, 884 MB, the median
14 KB. Each holds the part's convex pieces (vertices, face normals and edge
directions, worked out once by Qhull) and its connectors in BrickNet's own
order. `src/assembly/exact.gd` reads them; nothing of BrickNet's is run.

**What it judges** (`src/ai/exact_check.gd`, called from `Assistant._check`,
so check_design, submit_design, edit_model, review_model and saving all have
it):

- **Collisions by the real shapes.** Two parts collide when some piece of
  one and some piece of the other overlap by more than 1 LDU along every axis
  that could part them (the face normals of both and the cross products of
  their edges: the separating axis test, exact for convex pieces, where
  verify.py asks Bullet's EPA for the same depth). Where both parts have a
  shape this decides, not the lattice; the lattice still finds every pair
  worth asking about and decides for parts without one. Each collision is
  named with its fix: a side stud pushed into a brick, a stud in a part's
  solid, a hinge folded into its base (the tilting hinge opens one way), an
  axle through a part with no hole on its line, a part sunk into the one
  under it, or a part a few LDU off a connector of the other with the move
  that seats it. Gears in mesh are forgiven, as before: a convex piece a
  tooth cannot interleave.
- **Held, or standing.** A piece of the design that no BrickNet connection
  joins to the ground or to what stood before is a fault unless it would
  stand where it is, as verify.py's two seconds of gravity find it: clear of
  everything, square to gravity (within 8 degrees), and its centre of mass a
  LDU inside where it touches the parts under it, read off their convex
  pieces: corners of each within 2.5 LDU of the other and over or under it,
  as a drop that short passes verify.py's 3 LDU. A dish lying on a round
  brick stands, and a log in the groove of two; a tile half off a round
  plate's edge, a tile flat against a wall, a gem on a slope, a steering
  wheel with its centre on a brick's edge and a flower leaning 35 degrees do
  not.
- **Seated exactly.** Before anything is judged, a part of the design whose
  stud, hole, hinge or bar misses another's by up to a plate (8 LDU), and that
  meets none exactly, is moved onto it, as BrickAgent's `attach` places a part
  by its connector; a piece of the design built on its own and set down off
  its base moves whole; a pin put by its middle into a hole slides until its
  collar is at the mouth. The rest past the 2 LDU lattice cell is kept as a
  nudge on the placement, so a round part's odd LDU is reachable.
  `add_minifig` seats a fez on its head's stud (it is drawn 16 LDU above where
  other headgear goes) and slides a sword along its grip until the guard is
  out of the hand. What the app moves itself it leaves overlapping by less
  than 0.99 LDU, not 1: two parts that meet by exactly 1 LDU are a rounding
  error either side of verify.py's limit (1.0000000000000024 for a head in a
  breastplate, refused; under it for two parts of BrickAgent's model-004,
  passed). The check itself judges at 1, as verify.py says.
- **Turned on its axle.** A part and the cross axle through its cross hole
  that collide only because the two crosses are not lined up (a wheel drawn
  spun on its axle, as Technic sets draw them) are clear when a turn about
  the axle of up to 45 degrees clears them: in plastic the axle turns with
  it. A hinge, a clip on a bar, or an axle through a ring it cannot pass is
  not forgiven.
- **Before it is handed over.** review_model judges every part the design
  placed, not only the last edit's, and says what is left; saving waits, twice
  at most, until nothing collides or falls. attachment_points lists a part's
  connectors exactly where they say more than its studs.

**One case a pair kind, from our own failing designs** (`src/dev/exact_probe.gd`):
the two parts of each pair as the design placed them, out of our designs' own
model files, read back as a session's model is and checked as review_model
checks. On the code before this (`fb64132`) every case came back "buildable"
and the probe failed 17 of 21; now all 22 pass (the 22nd, below, from the
bench run after):

| pair kind (verify.py's count) | case | now |
|---|---|---|
| side studs pushed into the neighbour (12) | 11211 by 3003, model-008 | named: "a side stud ... pushed into" |
| hinge plates overlapping (11) | 3937 and 3938, model-008 | named as the hinge folded into its base |
| horns threaded on axles (6) | 2142 on 4032a and 3704, model-002 | named: at one point, one inside the other |
| minifig accessories and heads (4) | a fez on 3626cpbd; 3847 in 3820 | named, the fez "16 LDU up, on the other's open" stud |
| round bricks sunk into a plate (4) | 3941 in 3035, model-006 | named: a stud in its solid |
| tiles off side studs (3) | 3070b on 30414, model-010 | seated: it was 8 LDU off, a plate |
| crystals and gems 4 LDU off (3) | 30385 on 18674, model-005; 30153 on 3039 | seated; the gem on the slope named |
| a dome, leaves, a bat on plates (3) | 20952 on 6141, model-009 | named |
| decorations resting without a connection | 98138 on 74611, model-007 | not held: past the round plate's edge |

and four built right say nothing (bricks stacked, a fez on its head's stud, a
round tile on the round plate's stud, tiles on side studs), nor does a figure
add_minifig makes with a fez and a sword, nor one in a breastplate (2587,
model-010's head: its head stands clear of it and joined to the torso), nor
the app's own tilting hinge at 0, 30, 60 and 90 degrees.

**It sees what verify.py sees.** On the twenty builds of the first run, ours
and BrickAgent's, `src/dev/exact_dump.gd` finds verify.py's colliding pairs
exactly (0, 7, 1, 0, 9, 9, 0, 14, 1, 5 in ours; none in theirs), the same part
pairs, and BrickNet's connected pieces exactly (1, 2, 2, 1, 3, 7, 7, 1, 3, 6 in
ours; 1, 1, 1, 1, 2, 1, 1, 2, 1, 4 in theirs), in 0.02 to 0.27 s a build.

**The bench again.** The same ten prompts through the same loop as the first
run, and the next ten of BrickBench's model split held out (model-011 to 020),
designed on the subscription two at a time from a snapshot of `6bbe717`, each
exported and judged by BrickAgent's own `verify.py`
(`bench/results/brickbench-2026-10-14-exact`, `-heldout`):

| | valid | colliding pairs | pieces that fell | parts, mean | design time, mean |
|---|---|---|---|---|---|
| ours, first run (this morning) | 2 of 10 | 46, in 7 builds | 1 build | 155 | 587 s |
| ours, the same ten now | **9 of 10** | 1, in 1 build | none | 133 | 432 s |
| ours, ten held out | **8 of 10** | none | 2 builds, one part each | 167 | 712 s |
| BrickAgent's Opus 5.5 | 10 of 10 | none | none | 130 | |

Each of the three that failed is one part:

- model-010: a minifigure's head exactly 1 LDU into its breastplate (2587),
  which verify.py's sum puts at 1.0000000000000024. The check, judging at 1
  LDU as verify.py says, still passes that file; the app no longer makes it:
  add_minifig stands the head 3 LDU up its neck, clear, and what the app
  moves it leaves under 0.99.
- model-011: a steering wheel (16091) resting on a brick with its centre on
  the brick's edge, joined to nothing. It tipped off. Its corners 2 LDU past
  the edge had been counted as what it stood on.
- model-017: a flower (98262) leaning 35 degrees on a round plate, joined to
  nothing. It slid off. A part leaning on what it rests on now falls.

Checked as review_model checks, over the twenty designs' own model files
(the merged code), the check refuses model-011 and model-017, each for that
one part, and passes the other eighteen: it agrees with verify.py on 19 of 20,
and the twentieth is the 1 LDU coin's toss.

The designs are smaller than the first run's on the same prompts (133 parts
against 155) and quicker (432 s against 587): a stricter check is met by
building less, not by more turns.

**Honest on real sets.** The connection audit (`src/dev/connection_audit.gd`)
over every 25th file of the LDraw model repository, 64 files (29,693 parts as
the morning's code reads them, 29,931 as main's does), checked as an edit
checks what it leaves hanging, before and after:

| code | parts | floating | overlapping pairs | files worse | time |
|---|---|---|---|---|---|
| the morning's (`fb64132`), lattice only | 29,693 | 6,678 | 7,511 | | 1,864 s |
| with the exact check (`6bbe717`) | 29,693 | 6,678 | **3,386** | 1 (+2 pairs) | 1,925 s |
| main as merged (`7970de9`, connections part 4), shapes left out | 29,931 | 1,698 | 8,188 | | 1,836 s |
| the same with the exact check (this branch) | 29,931 | 1,698 | **3,845** | 1 (+3 pairs) | 1,842 s |

What the audit counts as overlapping is every pair the check would refuse in
a set that is built in plastic, so every one is a false positive. The lattice's
covers made 7,511 and then 8,188 of them; the real shapes clear 53 to 55% of
those, and judge the rest exactly. Of 64 files one is worse, 8825-1 (a Technic
set: three pairs of gears and bushings their convex pieces put inside each
other). Floating is unchanged: the held rule is for a design's own parts.
BrickNet's own colliders, asked directly of the same 64 sets (24,861 parts
they cover), put 1,135 parts in 797 overlapping pairs: a set modelled in LDraw
is not clean by them either, which is why a fault is only ever a pair the
design is in.

**What it costs.** On a model as it stands the exact check adds little; as a
whole new design it is most of the check, and a check of over 300 parts runs on
a worker, so the app draws on (`src/dev/exact_cost_probe.gd`, on this machine at
a load of 37 on 24 cores, the merged code):

| model | checked | whole check | of it exact | seating | collisions | pieces |
|---|---|---|---|---|---|---|
| station.ldr, 535 parts | as it stands | 883 ms | 9 ms | | | |
| | an edit, one brick added | 715 ms | 17 ms | 1 ms | 1 ms | |
| | as a whole new design | 1,917 ms | 1,423 ms | 966 ms | 181 ms | 260 ms |
| orthanc.ldr, 9,427 parts | as it stands | 14,198 ms | 153 ms | | | |
| | an edit, one brick added | 12,545 ms | 182 ms | 13 ms | 9 ms | |
| | as a whole new design | 32,062 ms | 9,669 ms | 8,016 ms | 345 ms | 1,179 ms |

An edit to a 9,000 part model asks about its own parts and their neighbours,
not every stud in it. Read back as a design of its own, Orthanc has 162
collisions and 34 pieces held by nothing by its real shapes: its prism
sections are not in the file, so its turned walls are judged as anything else
is.

**In the browser.** The web build reads a shape from the pack if it is there
and otherwise fetches `<hash>.bwx` from beside the geometry, six at a time, as
it fetches a part; `tools/web_pack.py` leaves them out of the pack unless
`--with-exact` (19 MB more for everyone), and `tools/storage_parts.py` uploads
them with the meshes. Until they are in storage the web build checks by the
lattice alone, as before.

The Falcon Heavy's calls in Chromium on SwiftShader (`tools/web/freeze_check.mjs
--dir=build/web`, the shapes not packed, every mesh and shape served beside the
app as storage would serve them). The first export held the page for 7,530 ms
in check_design: the check asked for a shape once a placement, 4,242 times,
each a look in the pack for a file that is not there (8 of the 8.2 seconds,
timed in the page). Asked once a part, check_design's longest frame of its
own is 313 ms, and 256 ms in a second run. The worker's check of the Falcon
took 22 s in the page, 12 s of it the exact check, and the page drew on. Over
the 500 ms budget left are the build's frames and the autosave's: 577 ms on
submit_design and 681 ms on edit_model; the code before this, the same calls
in the same hour, 672 ms on submit_design and 879 ms on review_model. (In the
second run the check was still out when submit_design came, so the calls
after it were answered busy and the first build was the last call's, 1,400 ms.)

**What it changed elsewhere, and what is left.**

- Five worked constructions collide as they were read off their sets and are
  out of the library until they are read again (`Techniques.WITHDRAWN`, each
  with why): face turned sideways, wall lantern, round body lying down, two
  rounds pinned side by side, lid or hatch raised on hinges. The anvil stands
  on a 2 x 2 jumper (9476 stands its dish on one stud, turned 45 degrees),
  and add_rooms lights a stair with candles.
- A rim's wedge plates and wings give way, as a tile on a side stud does,
  where the real shape runs into a stud of the layer under it.
- The prism pattern's turned walls meet inside each other by their real
  shapes, and its square summit stands on them joined by nothing BrickNet
  sees; both are judged by the lattice until the pattern lays its corners
  another way.
- Probes that asserted the lattice's leniency now say what the shapes say:
  a hinge top folded 10 degrees into its base, a pin centred in a 1-stud hole
  with its collar inside it, a turntable stood 15 LDU off the plate's studs,
  side studs against a wall once its tiles give way.
- Shapes' wheels faced the wrong way: the hub's cross hole out and its clip
  ring in, where the axle ended in a ring a bar's width and joined neither
  wheel. Turned, as 75893 stands them, the axle ends in both cross holes and
  the clip, which takes a hubcap, faces out.
- A 4 x 4 dish (3960) stands on a 2 x 2 round plate's four studs, a 2 x 2 dish
  (4740) on a jumper: a round plate's ring of studs runs 2 and 3 LDU into
  their undersides. The round pattern's dome and ogive noses and Shapes'
  dish crowns lay them so.
- dress_probe's wall had side studs where its ribs stand against it, 4 LDU
  into each rib's brick; shapes_probe's held-out car had its wheels as the
  pattern did.
- **Left:** face_probe's cat head. Shapes' side-stud shells and a face's disc
  stand their lowest edge on the studs of the round plate under them, 4 LDU
  into each, 7 pairs; the check is right, and the pattern has to lay them
  clear (a tile there, or the shell a plate up). rooms_probe's eight floors:
  furniture add_rooms sets on a floor off its studs (a dresser's handle plate
  and tile 0.4 stud over, a seat on a plate, a lamp's plate 0.2 stud over)
  meets the floor's studs, 32 pairs, and three pieces rest joined to nothing;
  two floors pass. add_rooms has to stand those on tiles or on the grid. Both
  probes pass with the shapes left out.
- **Left:** the two meshes the catalogue gained with connections part 4 have
  no exact shape yet, nor do 32 of its 68 moved parts, so those are judged by
  the lattice alone; `tools/build_exact.py --only` builds those BrickNet has.
  `detail_probe`, `print_probe` and
  `tests/test_elements.py::test_pipeline_json_is_what_the_pipeline_makes_now`
  fail on main too; nothing here touches them.
- The desktop release carries `assets/generated/` whole, so it grows by the
  884 MB of shapes unless the export filters them.

## 2026-10-14, later: why ours were statues, and the fix

The same model drives both systems, so the difference was in what ours was
told and given. This section reads every tool call and reply of our ten
sessions, compares what both sides' builds are made of, makes a general fix,
and measures it on twenty held-out prompts that nothing was tuned on: ten
small vehicles and ten characters.

### What the builds are made of

`brickbench.py compare` counts it (`vocabulary`). It uses the first ten
prompts, the median of each side's ten builds. Stacked means a brick or plate
of any outline, studs up. Shaped means a curve, a slope, or a part at an angle.

| | ours | BrickAgent's Opus 5.5 |
|---|---|---|
| parts | 133 | 131 |
| stacked bricks and plates | 57% | 41% |
| plain rectangular bricks and plates | 49% | 17% |
| shaped | 28% | 45% |
| tiles | 16% | 26% |
| clips, bars, hinges, balls | 0% | 2% |
| figure parts | 2.5 | 5 |
| across, studs | 22 | 19 |
| on a baseplate | 3 of 10 (48 x 48, 32 x 32, 16 x 24) | 1 of 10 (16 x 24) |

The two sides used the same number of parts at the same size. The difference
is which parts.

### What our sessions reached for, and why

1. **The head told every session to say each mass as a shape pattern.** The
   instructions' step 2 read "each said as a shape pattern — a body, a head".
   The guide's examples included "a bird's or a beast's body ellipsoids".
   - Six of ten sessions read the shapes section, and eight used a
     pattern: a shape, a fill or a round.
   - A pattern fills a volume with bricks and skins it. That is right for
     a hull, and gives a statue for a figure. Our own barn owl was judged
     nine times on the bench. Four of the technique reasons call its body
     stacked bricks ("plain stacked bricks", "layered stacking", "bricks
     stacked straight up"). Four more ask for angled head, wing or limb
     sub-assemblies.
   - BrickAgent's agent built each character as sub-assemblies: a helmet, a
     torso, an arm on a Technic brick, a wing on a hinge, a fist of round
     parts, a foot of a round brick and a dome. That is what its `build.py`
     files are.
2. **The bench's part list refused the generators' own numbers.**
   - The shape, fill and round patterns lay 3023 and 4073. LDraw has moved
     those numbers to 3023b and 6141, and BrickNet lists only the new ones.
   - So every shape was refused: 41 times in the penguin's first submission,
     and even a check with no bricks of its own.
   - Three sessions gave up on the body generator and stacked bricks by
     hand: "I'm switching to building the duck by hand" (24 bricks 2 x 4).
     The blob became stacks of 2 x 4 bricks. Two fell back on the round
     pattern's stacked round plates.
   - This was a fault of the bench mode, and the worst single cause.
3. **Nothing said how big a figure is.**
   - No session called plan_scale. Had one called it for a person, the
     answer was "build a part of it, a locomotive rather than the train".
   - The standing knights were 37 to 62 plates tall, mostly 2 x 4 and
     2 x 6 bricks.
   - No session considered a minifigure knight. add_minifig said it was for
     "who lives in it, guards it, works in it", added once the model is
     built.
4. **The creative pass asked for a story.** It asked "who flies, drives,
   works, keeps or hunts from it", and told the session "What it has now:
   no figure, no creature".
   - Five of the six sessions that ran it added something unasked: a
     farmer with his leek, a throne guard on a throne the prompt called
     empty, a bat, a beetle, a bone.
   - The assembly reviews listed castle parts for every "knight" (flags,
     barrels, fences). They also listed leaves and petals. The fence,
     flowers and coins followed.
5. **Baseplates were rounded up to a square.** The prompts are vignettes on a
   mound, a bench or a dais, so four sessions chose a baseplate "for a
   scene". The plate was the least of 16, 32 or 48 square that held the
   model. That gave model-001 and model-004 a 48 x 48 plate, a wide empty
   field in every view.
6. **Not changed: design memory anchors to big builds.** A duck or a penguin
   is handed the barn owl (986 parts), and a knight the castle gatehouse
   (1,317 parts), as "the best design of the nearest subject".

### The fix

All of it is general. Nothing names a prompt.

- **A figure is not a hull**, in the guide's own words: a new section, FIGURES,
  CREATURES AND SMALL MODELS (`read_guide "figures"`). The head's step 2 now
  sends a figure, a creature, a character or anything small there, and a
  hull, a car body, a fuselage or a building to the shape patterns. It says:
  - A figure is sub-assemblies of shaped parts on joints. Its head is a round
    brick, a dome or a dish. Its body is round bricks and curved slopes on
    side studs. A limb is a section on a clip, click or tilting hinge, or a
    ball in a socket, and anything held is a bar in a clip.
  - The brief is the scope: build what it names, and only that.
  - A person at minifigure scale is a minifigure.
  - A pattern still fits a figure's one big mass when that mass is a hull.

  The shapes section opens by saying the same. A small round body said as a
  shape (under 12 studs) is told so in the check's reply, with the moulded
  parts a set would use (`SMALL_ROUND`).
- **plan_scale answers a person or an animal**: built as a figure, a
  minifigure among minifigure-scale things, or brick-built 6 to 16 studs
  tall from shaped parts.
- **The scope is the brief.** Where a brief says what is in the scene, the
  creative pass keeps its touches on what it names. A figure, a creature or a
  prop it did not name is clutter, in the pass's own words and the guide's,
  and the head's step 7 says the same. The kind lists say "never something
  the brief did not ask for". add_minifig says a minifigure can be the
  subject itself.
- **A design's baseplate is the least in eights each way**, so a scene 19
  studs by 12 now stands on 24 x 16 (3334), not 32 x 32 (`src/main.gd`).
- **A moved part number is the part it moved to** under `--parts-only`
  (`PartsOnly.allows(part, library)`). The export writes the number BrickNet
  lists. Both arms below have this fix, so the comparison measures the
  guidance alone.

The fix overlaps one other agent's work in one place. The "body" agent works
on the car body and its cabin. The cabin and screen lines of the shapes
section are untouched; only the shape paragraph's animal example and the face
line changed.

### The controlled comparison, on ten held-out prompts

**The prompts.** model-021 to model-030, the ten after the first twenty in
file order. Nothing was tuned on them, and no guide example names anything
in them. They turned out to be small trains and carts with faces and
figures: a spider-legged locomotive, a creature in a minecart, a trolley at
a junction, a stick figure by a train, an engine with a pig in its cab.

**The two arms.**
- **full**: the guidance as it was (`fe032a8`), with the moved-number fix.
- **lean**: the fix (`63ab5ca`).

Each arm ran from a `git archive` of its commit, two designs a prompt, 40
designs in all. Every design was checked by their `verify.py`, drawn by our
renderer from the same four cameras, and judged by our pairwise judge
against every other design of its prompt and BrickAgent's. That is 200
verdicts, both orders of every pair.

| dimension | full ELO (95%) | lean ELO (95%) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| likeness | 843 (679-921) | 907 (783-990) | 1250 (1126-1474) |
| surface | 881 (740-979) | 942 (870-996) | 1178 (1084-1334) |
| colour | 897 (760-977) | 882 (759-950) | 1221 (1112-1460) |
| technique | 775 (610-876) | 825 (697-897) | 1400 (1282-1603) |
| creativity | 932 (789-1040) | 845 (756-892) | 1223 (1140-1403) |
| buildability | 901 (757-998) | 949 (840-1009) | 1150 (1040-1359) |
| **overall** | **675 (597-731)** | **735 (679-797)** | **1590 (1588-1606)** |

Bradley-Terry over the arms, as their `elo.py` fits systems. Two designs of
one arm are not a game. The 95% intervals resample the ten prompts with all
their verdicts, so the run-to-run spread is inside them. This is our judge,
not BrickBench's.

| head to head | verdicts for lean | 95% | prompts lean won every time / split / lost |
|---|---|---|---|
| lean vs full, overall | 47 of 80 (59%) | 48-69% | 2 / 8 / 0 |
| lean vs full, likeness | 49 of 80 (61%) | 50-71% | 1 / 9 / 0 |
| lean vs full, surface | 50 of 80 (62%) | 52-72% | 3 / 7 / 0 |
| lean vs full, technique | 46 of 80 (58%) | 47-68% | 2 / 8 / 0 |
| lean vs BrickAgent, overall | 0 of 40 | 0-9% | 0 / 0 / 10 |
| full vs BrickAgent, overall | 0 of 40 | 0-9% | 0 / 0 / 10 |

What each arm's 20 builds are made of (medians):

| arm | valid (verify.py) | baseplates | parts | figure parts | stacked | plain | shaped | tiles | across |
|---|---|---|---|---|---|---|---|---|---|
| full | 5 of 20 | 6 (48 x 48, 3 of 32 x 32, 2 of 16 x 16) | 142 | 10 | 60% | 55% | 21% | 13% | 24 |
| lean | 6 of 20 | 4 (16 x 32, 2 of 16 x 24, 8 x 16) | 151 | 0 | 59% | 51% | 22% | 18% | 26 |
| BrickAgent | 10 of 10 | 1 | 136 | 1.5 | 38% | 36% | 31% | 27% | 22 |

**What the fix did.**
- **The scope held.** Six of these prompts ask for no person. The full arm
  put an unasked minifigure into 7 of its 12 designs of those prompts, a
  driver beside the spider train among them. The lean arm put one into 1 of
  12. The baseplates shrank to the scene: no lean design stood on more than
  16 x 32.
- **The judge leaned to the fix, but not past the noise on overall.** Lean
  was preferred in 59% of the 80 verdicts between the arms, and no prompt
  went to full every time. Its interval, 48-69%, touches even. Likeness and
  surface were just clear of it.
- **Creativity went the other way** (932 to 845). The unasked figures were
  what the judge had counted as story. Where a brief lists its scene, a
  touch now has to be on what it names.
- **The construction did not change.** On these prompts, which are vehicles
  more than figures, both arms are 59-60% stacked, against BrickAgent's 38%.
  Only 2 of the 20 lean sessions read the figures section. The head sent
  the trains to the shape patterns, as it should send a hull.
- **Validity did not change**, 5 and 6 of 20, against their 10 of 10. That
  is the collision and stability work of the "exact" agent, not this one.
- **Neither arm won a single verdict against BrickAgent.** This fix does not
  close the gap on these prompts.

### No regression on big subjects

The car and the fire truck went through `tools/bench/run.py` on the fix,
two designs each, as round `2026-10-14-figures`. They were judged in pairs
against every design of their subject from every round. Against the
`2026-10-14-cabins` round they won 4 of 8 verdicts for the car (95% 22-78%)
and 6 of 8 for the fire truck (41-93%).

Read as a lever against cabins, the change is +124 ELO overall. That is
(+0, +218) on the judge's interval and (-246, +475) once the run-to-run
spread is counted. No dimension went down.

On the 1-10 judge the car scored 4.17 and 4.17, against 4.33 and 4.17 for
cabins. The fire truck scored 6.67 and 6.67, against 5.67 and 7.00. The
tables are in [DESIGN_SCORES.md](DESIGN_SCORES.md).

### And on ten held-out characters

model-021 to model-030 were mostly vehicles. The next ten, model-031 to
model-040, are characters:
- a cube robot holding a boot;
- a masked spirit;
- an alien in a Roman helmet;
- a basketball robot;
- a wizard at a crystal ball;
- a man with eyes on stalks;
- a one-eyed alien on tentacles;
- a demon with a telephone;
- a turtle wizard on a broom;
- a bear with a brain in a dome.

They were run the same way, one design an arm a prompt, the two arms side by
side. The full arm ran from `fe032a8` again. The lean arm ran from `c0d7257`,
which is `63ab5ca` with two guide examples swapped for words in no prompt: a
wizard at his desk and a broom matched two of these ten.

Every pair was judged twice in both orders, 120 verdicts. Both arms ran
after the shared catalogue's connections part 4 went live, so they read the
same catalogue. With one design an arm a prompt, the intervals carry no
run-to-run spread within an arm; on the held-out ten that spread was the
larger part.

| dimension | full ELO (95%) | lean ELO (95%) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| likeness | 748 (618-812) | 848 (688-978) | 1404 (1290-1601) |
| surface | 897 (791-959) | 883 (618-1040) | 1221 (1118-1601) |
| colour | 849 (753-903) | 979 (820-1099) | 1172 (1052-1400) |
| technique | 670 (577-747) | 739 (661-810) | 1591 (1588-1613) |
| creativity | 905 (763-1019) | 918 (786-1022) | 1176 (1084-1313) |
| buildability | 824 (409-950) | 961 (820-1139) | 1215 (1132-1439) |
| **overall** | **739 (577-812)** | **856 (680-988)** | **1405 (1293-1613)** |

| head to head | verdicts for lean | 95% | prompts lean won every time / split / lost |
|---|---|---|---|
| lean vs full, overall | 26 of 40 (65%) | 50-78% | 5 / 4 / 1 |
| lean vs full, likeness | 25 of 40 (62%) | 47-76% | 3 / 6 / 1 |
| lean vs full, technique | 24 of 40 (60%) | 45-74% | 3 / 5 / 2 |
| lean vs full, surface | 16 of 40 (40%) | 26-55% | 2 / 5 / 3 |
| lean vs BrickAgent, overall | 2 of 40 (5%) | 1-17% | 0 / 1 / 9 |
| full vs BrickAgent, overall | 0 of 40 | 0-9% | 0 / 0 / 10 |

| arm | valid (verify.py) | baseplates | parts | stacked | plain | shaped | tiles | joints | across |
|---|---|---|---|---|---|---|---|---|---|
| full | 2 of 10 | 2 | 202 | 66% | 51% | 28% | 12% | 0% | 20 |
| lean | 4 of 10 | 0 | 158 | 53% | 45% | 36% | 21% | 0% | 14.5 |
| BrickAgent | 10 of 10 | 0 | 203 | 38% | 33% | 62% | 16% | 4% | 17 |

**What the fix did on characters.**
- **The routing took.** Nine of the ten lean sessions read the figures
  section. Seven of the ten built with no shape, fill or round pattern,
  and three turned limbs, eyes or arms on hinged sections. Nine of the
  ten full sessions read the shapes section and laid a pattern. The turtle
  wizard's session sent 23 shapes and 4 rounds across its calls.
- **The builds moved toward theirs.**
  - Stacked parts fell from 66% to 53%, against their 38%.
  - Shaped parts rose from 28% to 36%, against their 62%.
  - Tiles nearly doubled.
  - The figures got smaller, 20 studs across to 14.5, and lost a fifth of
    their parts.
  - No lean figure stood on a baseplate.
- **The judge preferred the fix**: 26 of 40 verdicts overall (95% 50-78%),
  with five prompts won every time and one lost every time. Likeness and
  technique went the same way. Surface went the other, 16 of 40.
- **Their verify.py passed twice as many**, 4 of 10 against 2, on the same
  check. At ten builds an arm that is a hint, not a finding.
- **The gap is still wide.** Lean won 2 of its 40 verdicts against
  BrickAgent, the first any of ours has, and lost the other 38. Their
  builds are still 62% shaped parts with real joints (4%), against our
  36% and 0%.

### What is left

- **Validity first.** 4 to 6 builds in 10 still fail their `verify.py` on
  collisions, against all of theirs. The "exact" agent is making our checks
  as strict as BrickBench's.
- **The vocabulary of joints.** Ours still have no clips, bars, ball
  joints or hinge plates to speak of, where theirs are 4%. A session places
  parts by corner coordinates on a lattice. BrickAgent's attaches them
  connector to connector, which makes a clip on a bar as easy as a brick
  on a brick. Worked techniques for a figure's limb on a clip, a ball
  shoulder and a head on a neck joint (`show_technique`) are the next
  general step.
- **Small vehicles.** A train or a cart is still routed to the shape
  patterns as a hull, and stays 60% stacked. The figures section's advice
  for anything under a dozen studs reached 2 of 20 such sessions.
- **Design memory** still hands a duck the 986-part owl and a knight the
  1,317-part gatehouse, as the best design of the nearest subject.
- **Creativity** fell on the held-out ten where unasked figures had been
  its source.

## Repeat it
## 2026-10-14, evening: the check made as strict as BrickBench's

Lever 1 above, done. Our check now judges a part by BrickNet's own shapes,
so a design it hands over is one `verify.py` passes.

**What the check reads.** `tools/build_exact.py` converts BrickNet's convex
colliders and connector labels (MIT, Kulits and Schmid; the colliders are
decompositions of LDraw parts) into one small file a shape,
`assets/generated/exact/<mesh hash>.bwx`, beside the part's geometry: 15,417
shapes for the 14,583 BrickNet parts and their aliases, 884 MB, the median
14 KB. Each holds the part's convex pieces (vertices, face normals and edge
directions, worked out once by Qhull) and its connectors in BrickNet's own
order. `src/assembly/exact.gd` reads them; nothing of BrickNet's is run.

**What it judges** (`src/ai/exact_check.gd`, called from `Assistant._check`,
so check_design, submit_design, edit_model, review_model and saving all have
it):

- **Collisions by the real shapes.** Two parts collide when some piece of
  one and some piece of the other overlap by more than 1 LDU along every axis
  that could part them (the face normals of both and the cross products of
  their edges: the separating axis test, exact for convex pieces, where
  verify.py asks Bullet's EPA for the same depth). Where both parts have a
  shape this decides, not the lattice; the lattice still finds every pair
  worth asking about and decides for parts without one. Each collision is
  named with its fix: a side stud pushed into a brick, a stud in a part's
  solid, a hinge folded into its base (the tilting hinge opens one way), an
  axle through a part with no hole on its line, a part sunk into the one
  under it, or a part a few LDU off a connector of the other with the move
  that seats it. Gears in mesh are forgiven, as before: a convex piece a
  tooth cannot interleave.
- **Held, or standing.** A piece of the design that no BrickNet connection
  joins to the ground or to what stood before is a fault unless it would
  stand where it is, as verify.py's two seconds of gravity find it: clear of
  everything, square to gravity (within 8 degrees), and its centre of mass a
  LDU inside where it touches the parts under it, read off their convex
  pieces: corners of each within 2.5 LDU of the other and over or under it,
  as a drop that short passes verify.py's 3 LDU. A dish lying on a round
  brick stands, and a log in the groove of two; a tile half off a round
  plate's edge, a tile flat against a wall, a gem on a slope, a steering
  wheel with its centre on a brick's edge and a flower leaning 35 degrees do
  not.
- **Seated exactly.** Before anything is judged, a part of the design whose
  stud, hole, hinge or bar misses another's by up to a plate (8 LDU), and that
  meets none exactly, is moved onto it, as BrickAgent's `attach` places a part
  by its connector; a piece of the design built on its own and set down off
  its base moves whole; a pin put by its middle into a hole slides until its
  collar is at the mouth. The rest past the 2 LDU lattice cell is kept as a
  nudge on the placement, so a round part's odd LDU is reachable.
  `add_minifig` seats a fez on its head's stud (it is drawn 16 LDU above where
  other headgear goes) and slides a sword along its grip until the guard is
  out of the hand. What the app moves itself it leaves overlapping by less
  than 0.99 LDU, not 1: two parts that meet by exactly 1 LDU are a rounding
  error either side of verify.py's limit (1.0000000000000024 for a head in a
  breastplate, refused; under it for two parts of BrickAgent's model-004,
  passed). The check itself judges at 1, as verify.py says.
- **Turned on its axle.** A part and the cross axle through its cross hole
  that collide only because the two crosses are not lined up (a wheel drawn
  spun on its axle, as Technic sets draw them) are clear when a turn about
  the axle of up to 45 degrees clears them: in plastic the axle turns with
  it. A hinge, a clip on a bar, or an axle through a ring it cannot pass is
  not forgiven.
- **Before it is handed over.** review_model judges every part the design
  placed, not only the last edit's, and says what is left; saving waits, twice
  at most, until nothing collides or falls. attachment_points lists a part's
  connectors exactly where they say more than its studs.

**One case a pair kind, from our own failing designs** (`src/dev/exact_probe.gd`):
the two parts of each pair as the design placed them, out of our designs' own
model files, read back as a session's model is and checked as review_model
checks. On the code before this (`fb64132`) every case came back "buildable"
and the probe failed 17 of 21; now all 22 pass (the 22nd, below, from the
bench run after):

| pair kind (verify.py's count) | case | now |
|---|---|---|
| side studs pushed into the neighbour (12) | 11211 by 3003, model-008 | named: "a side stud ... pushed into" |
| hinge plates overlapping (11) | 3937 and 3938, model-008 | named as the hinge folded into its base |
| horns threaded on axles (6) | 2142 on 4032a and 3704, model-002 | named: at one point, one inside the other |
| minifig accessories and heads (4) | a fez on 3626cpbd; 3847 in 3820 | named, the fez "16 LDU up, on the other's open" stud |
| round bricks sunk into a plate (4) | 3941 in 3035, model-006 | named: a stud in its solid |
| tiles off side studs (3) | 3070b on 30414, model-010 | seated: it was 8 LDU off, a plate |
| crystals and gems 4 LDU off (3) | 30385 on 18674, model-005; 30153 on 3039 | seated; the gem on the slope named |
| a dome, leaves, a bat on plates (3) | 20952 on 6141, model-009 | named |
| decorations resting without a connection | 98138 on 74611, model-007 | not held: past the round plate's edge |

and four built right say nothing (bricks stacked, a fez on its head's stud, a
round tile on the round plate's stud, tiles on side studs), nor does a figure
add_minifig makes with a fez and a sword, nor one in a breastplate (2587,
model-010's head: its head stands clear of it and joined to the torso), nor
the app's own tilting hinge at 0, 30, 60 and 90 degrees.

**It sees what verify.py sees.** On the twenty builds of the first run, ours
and BrickAgent's, `src/dev/exact_dump.gd` finds verify.py's colliding pairs
exactly (0, 7, 1, 0, 9, 9, 0, 14, 1, 5 in ours; none in theirs), the same part
pairs, and BrickNet's connected pieces exactly (1, 2, 2, 1, 3, 7, 7, 1, 3, 6 in
ours; 1, 1, 1, 1, 2, 1, 1, 2, 1, 4 in theirs), in 0.02 to 0.27 s a build.

**The bench again.** The same ten prompts through the same loop as the first
run, and the next ten of BrickBench's model split held out (model-011 to 020),
designed on the subscription two at a time from a snapshot of `6bbe717`, each
exported and judged by BrickAgent's own `verify.py`
(`bench/results/brickbench-2026-10-14-exact`, `-heldout`):

| | valid | colliding pairs | pieces that fell | parts, mean | design time, mean |
|---|---|---|---|---|---|
| ours, first run (this morning) | 2 of 10 | 46, in 7 builds | 1 build | 155 | 587 s |
| ours, the same ten now | **9 of 10** | 1, in 1 build | none | 133 | 432 s |
| ours, ten held out | **8 of 10** | none | 2 builds, one part each | 167 | 712 s |
| BrickAgent's Opus 5.5 | 10 of 10 | none | none | 130 | |

Each of the three that failed is one part:

- model-010: a minifigure's head exactly 1 LDU into its breastplate (2587),
  which verify.py's sum puts at 1.0000000000000024. The check, judging at 1
  LDU as verify.py says, still passes that file; the app no longer makes it:
  add_minifig stands the head 3 LDU up its neck, clear, and what the app
  moves it leaves under 0.99.
- model-011: a steering wheel (16091) resting on a brick with its centre on
  the brick's edge, joined to nothing. It tipped off. Its corners 2 LDU past
  the edge had been counted as what it stood on.
- model-017: a flower (98262) leaning 35 degrees on a round plate, joined to
  nothing. It slid off. A part leaning on what it rests on now falls.

Checked as review_model checks, over the twenty designs' own model files
(the merged code), the check refuses model-011 and model-017, each for that
one part, and passes the other eighteen: it agrees with verify.py on 19 of 20,
and the twentieth is the 1 LDU coin's toss.

The designs are smaller than the first run's on the same prompts (133 parts
against 155) and quicker (432 s against 587): a stricter check is met by
building less, not by more turns.

**Honest on real sets.** The connection audit (`src/dev/connection_audit.gd`)
over every 25th file of the LDraw model repository, 64 files (29,693 parts as
the morning's code reads them, 29,931 as main's does), checked as an edit
checks what it leaves hanging, before and after:

| code | parts | floating | overlapping pairs | files worse | time |
|---|---|---|---|---|---|
| the morning's (`fb64132`), lattice only | 29,693 | 6,678 | 7,511 | | 1,864 s |
| with the exact check (`6bbe717`) | 29,693 | 6,678 | **3,386** | 1 (+2 pairs) | 1,925 s |
| main as merged (`7970de9`, connections part 4), shapes left out | 29,931 | 1,698 | 8,188 | | 1,836 s |
| the same with the exact check (this branch) | 29,931 | 1,698 | **3,845** | 1 (+3 pairs) | 1,842 s |

What the audit counts as overlapping is every pair the check would refuse in
a set that is built in plastic, so every one is a false positive. The lattice's
covers made 7,511 and then 8,188 of them; the real shapes clear 53 to 55% of
those, and judge the rest exactly. Of 64 files one is worse, 8825-1 (a Technic
set: three pairs of gears and bushings their convex pieces put inside each
other). Floating is unchanged: the held rule is for a design's own parts.
BrickNet's own colliders, asked directly of the same 64 sets (24,861 parts
they cover), put 1,135 parts in 797 overlapping pairs: a set modelled in LDraw
is not clean by them either, which is why a fault is only ever a pair the
design is in.

**What it costs.** On a model as it stands the exact check adds little; as a
whole new design it is most of the check, and a check of over 300 parts runs on
a worker, so the app draws on (`src/dev/exact_cost_probe.gd`, on this machine at
a load of 37 on 24 cores, the merged code):

| model | checked | whole check | of it exact | seating | collisions | pieces |
|---|---|---|---|---|---|---|
| station.ldr, 535 parts | as it stands | 883 ms | 9 ms | | | |
| | an edit, one brick added | 715 ms | 17 ms | 1 ms | 1 ms | |
| | as a whole new design | 1,917 ms | 1,423 ms | 966 ms | 181 ms | 260 ms |
| orthanc.ldr, 9,427 parts | as it stands | 14,198 ms | 153 ms | | | |
| | an edit, one brick added | 12,545 ms | 182 ms | 13 ms | 9 ms | |
| | as a whole new design | 32,062 ms | 9,669 ms | 8,016 ms | 345 ms | 1,179 ms |

An edit to a 9,000 part model asks about its own parts and their neighbours,
not every stud in it. Read back as a design of its own, Orthanc has 162
collisions and 34 pieces held by nothing by its real shapes: its prism
sections are not in the file, so its turned walls are judged as anything else
is.

**In the browser.** The web build reads a shape from the pack if it is there
and otherwise fetches `<hash>.bwx` from beside the geometry, six at a time, as
it fetches a part; `tools/web_pack.py` leaves them out of the pack unless
`--with-exact` (19 MB more for everyone), and `tools/storage_parts.py` uploads
them with the meshes. Until they are in storage the web build checks by the
lattice alone, as before.

The Falcon Heavy's calls in Chromium on SwiftShader (`tools/web/freeze_check.mjs
--dir=build/web`, the shapes not packed, every mesh and shape served beside the
app as storage would serve them). The first export held the page for 7,530 ms
in check_design: the check asked for a shape once a placement, 4,242 times,
each a look in the pack for a file that is not there (8 of the 8.2 seconds,
timed in the page). Asked once a part, check_design's longest frame of its
own is 313 ms, and 256 ms in a second run. The worker's check of the Falcon
took 22 s in the page, 12 s of it the exact check, and the page drew on. Over
the 500 ms budget left are the build's frames and the autosave's: 577 ms on
submit_design and 681 ms on edit_model; the code before this, the same calls
in the same hour, 672 ms on submit_design and 879 ms on review_model. (In the
second run the check was still out when submit_design came, so the calls
after it were answered busy and the first build was the last call's, 1,400 ms.)

**What it changed elsewhere, and what is left.**

- Five worked constructions collide as they were read off their sets and are
  out of the library until they are read again (`Techniques.WITHDRAWN`, each
  with why): face turned sideways, wall lantern, round body lying down, two
  rounds pinned side by side, lid or hatch raised on hinges. The anvil stands
  on a 2 x 2 jumper (9476 stands its dish on one stud, turned 45 degrees),
  and add_rooms lights a stair with candles.
- A rim's wedge plates and wings give way, as a tile on a side stud does,
  where the real shape runs into a stud of the layer under it.
- The prism pattern's turned walls meet inside each other by their real
  shapes, and its square summit stands on them joined by nothing BrickNet
  sees; both are judged by the lattice until the pattern lays its corners
  another way.
- Probes that asserted the lattice's leniency now say what the shapes say:
  a hinge top folded 10 degrees into its base, a pin centred in a 1-stud hole
  with its collar inside it, a turntable stood 15 LDU off the plate's studs,
  side studs against a wall once its tiles give way.
- Shapes' wheels faced the wrong way: the hub's cross hole out and its clip
  ring in, where the axle ended in a ring a bar's width and joined neither
  wheel. Turned, as 75893 stands them, the axle ends in both cross holes and
  the clip, which takes a hubcap, faces out.
- A 4 x 4 dish (3960) stands on a 2 x 2 round plate's four studs, a 2 x 2 dish
  (4740) on a jumper: a round plate's ring of studs runs 2 and 3 LDU into
  their undersides. The round pattern's dome and ogive noses and Shapes'
  dish crowns lay them so.
- dress_probe's wall had side studs where its ribs stand against it, 4 LDU
  into each rib's brick; shapes_probe's held-out car had its wheels as the
  pattern did.
- **Left:** face_probe's cat head. Shapes' side-stud shells and a face's disc
  stand their lowest edge on the studs of the round plate under them, 4 LDU
  into each, 7 pairs; the check is right, and the pattern has to lay them
  clear (a tile there, or the shell a plate up). rooms_probe's eight floors:
  furniture add_rooms sets on a floor off its studs (a dresser's handle plate
  and tile 0.4 stud over, a seat on a plate, a lamp's plate 0.2 stud over)
  meets the floor's studs, 32 pairs, and three pieces rest joined to nothing;
  two floors pass. add_rooms has to stand those on tiles or on the grid. Both
  probes pass with the shapes left out.
- **Left:** the two meshes the catalogue gained with connections part 4 have
  no exact shape yet, nor do 32 of its 68 moved parts, so those are judged by
  the lattice alone; `tools/build_exact.py --only` builds those BrickNet has.
  `detail_probe`, `print_probe` and
  `tests/test_elements.py::test_pipeline_json_is_what_the_pipeline_makes_now`
  fail on main too; nothing here touches them.
- The desktop release carries `assets/generated/` whole, so it grows by the
  884 MB of shapes unless the export filters them.

**Then the generators lay what the check passes**, with the check as strict as
above:

- Shapes' shells: a round run's top plate under a shell is laid as a ring of
  corner round tiles with a round plate inside it, which the core stands on
  (the cat head's 8 x 8 round plate became four 27507s round an 11213); a
  shell gives back the column over another shell's side-stud brick, and a
  side-stud brick is not laid with its studs up into a shell; a core plate
  right under a shell is a tile. face_probe's four heads pass, faces and all.
- add_rooms: a floor's stud under a part of a piece that does not take it by
  its real shape is a tile, so a dresser, a log pile and a bed on a laid floor
  rest on tiles where they took no stud; the throne's seat stands its base on
  its plate's studs, its back a quarter stud behind (it was the base that was
  a quarter stud off); the four-poster bed has a footing of two plates under
  its frame, as on the ground only the ground held it. A tile something stands
  on is laid again as a plate only where the plate's studs meet nothing over
  it (`_studs_where_stood_on`). rooms_probe's eight floors pass.
- The prism pattern: under a face turned off the grid, the plinth is tiled
  and a ledge's or the summit's plates are the tiles of their size
  (`_smooth_under_turned`), so its sections are judged as any other: the
  exemption for "prism ..." in `_note_turned_studs` is gone. The tower
  dress_probe saves and opens again had 128 turned studs; it has none.
- `models/orthanc.ldr`: the 35 bricks of its plinth's top course under its
  core's 45 degree faces are each two plates of their size with tiles over the
  studs the faces stood on, and the 14 summit plates under its horns' turned
  side-stud bricks are tiles: 9,427 parts to 9,541, 45 turned studs to none,
  one piece, and it stands up (8,002 g) with no weak joint.
- detail_probe expects the surface pass between the assemblies and the
  creative pass, which came in after it was written.
- The app's own part builder (`PartForge`) is the pipeline's occupancy again:
  it had stood still since 10-11 while `tools/ldraw/occupancy.py` gained
  drawn holes and their spans, the ray tie-break, through holes, clip rooms
  round bars and the coarse, hull-bound covers, and `pipeline.json` is
  written again from the pipeline. A print takes its plain part's cover, which
  its stated connectors cannot rebuild (a bore's arc is in neither them nor an
  .lbm), so 3816c and 3817c printed are their legs to the cell.
## 2026-10-15: parts put on each other by their connectors

The lean and exact work left one gap the "what is left" lists named first:
our sessions placed every part by its low corner on a 2 LDU lattice, and
BrickAgent's place them connector to connector. A clip on a bar, an arm on a
shoulder at 30 degrees, a head on its neck are each the joint arithmetic a
session gets wrong when it has to say a corner, so ours built none of them:
0% clips, bars, balls and hinges on the held-out characters, against
BrickAgent's 4%. This gives our designer BrickAgent's attach (`f64620b`;
`9e147ef` after the bench says, in a refusal, which connectors do mate).

### What a session says

Any brick of submit_design, check_design or edit_model may say, instead of
x, y, z, face and rot:

```json
{"part": "3818", "color": 15, "name": "right arm",
 "attach": {"to": "torso.hinge[0]", "by": "hinge[0]", "yaw": 240}}
```

- `to` is the part it goes on and that part's connector: a part of the same
  call by its `name`, one named in an earlier call (the name is kept with the
  world), a section of one by its name, or a brick standing by its number,
  `"#41.stud[3]"`.
- A connector is addressed as BrickAgent addresses it: its type (a stud's,
  a hole's or an axle's subtype: stud, open, hole, tube, post, axle, cross,
  pin, socket, bar, clip; else hinge, ball, fixed) and its place among that
  type in BrickNet's order. They are BrickNet's own labels, read off the exact
  shapes the check already has; a part BrickNet does not have uses the
  catalogue's studs, tubes, pins, axles, bars, clips and balls.
- `by` is the new part's own connector, left out when only one fits.
- `yaw` turns it about the joint's axis: a hinge's or a clip's angle, an
  arm's swing. `flip` turns an axle, bar or hinge joint end for end, `slide`
  moves it along an axle, `align` points one of the part's directions along
  one of the model's, and `orient` gives its whole orientation, which a ball
  takes any of and a hinge, clip or axle only about its own line.
- On a ball, `align` points the part that way whatever the ball's axis
  (`["-x", [0, -0.5, 0.87]]`: out along +z and 30 degrees down). BrickAgent's
  align turns about the joint's axis alone, which on a ball standing up
  cannot lift an arm.

### What the app does with it

- **The pose is BrickAgent's.** `src/assembly/attach.gd` is
  `brickagent.joints.placement` (MIT) in the app's frame: the target's
  connector frame, turned by yaw (and flipped), times the inverse of the
  source's. A pin in its socket said with no slide is slid, a whole LDU at a
  time, to the least slide that clears it of the part it goes in by their
  exact shapes, where BrickAgent reads a collar table: a minifigure's head
  comes to rest on the torso's top, as BrickAgent seats it.
- **It is written as a placement the rest of the app reads.** Square to the
  part it goes on, it is a placement in that part's frame with what lies past
  the lattice cell as a nudge (a leg on its hips, a plate on a side stud).
  Turned off the square, it is a section of one, named for the part, within
  the section of the part it goes on, so a hand goes where its arm goes. The
  nudge is now kept with a section's bricks across edits, as the corner was.
- **The check holds it by its joint.** A part attached by a clip, a hinge or
  a ball at an angle is a joint the lattice's cells cannot see; it is held by
  the part it went on wherever BrickNet's labels still join the two, and a
  leaning section is held by any such joint that is not a stud. The exact
  check judges everything else as before: collisions by the real shapes,
  pieces by BrickNet's connections.
- **What it cannot do it says**, and builds nothing somewhere else instead:
  a connector the part does not have, two that do not mate, a name nothing
  has, an orientation that would tilt a hinge's axis, a part with neither a
  corner nor an attach. Since `9e147ef` a refusal also says which pairs of
  the two parts' connectors do mate, the nearest first: a bench session
  asked for a flame's bar in a round brick's hollow stud ("open"), and the
  same spot is the brick's clip.
- **attachment_points says every connector by its address** with where it
  is and the way it points (`near=` lists those by a point); look_at_model
  says each part's name; mirror leaves attached parts to each side's own.

### Worked techniques

show_technique gains a group, "figures and joints", each built and checked
by `techniques_probe` as every technique is, and each laid in one call by
place_technique with the technique's name:

| technique | joint | parts |
|---|---|---|
| posed minifigure | hips, legs, arms, hands, neck, hat, a tool in a hand | 12 |
| limb on a clip | a bar in a clip, flipped and turned | 4 |
| ball shoulder | a ball, aimed with align | 4 |
| head on a neck | a ball, the head on the socket plate | 6 |
| tail on a bar | a clip on a bar | 4 |
| hinged wing | click hinge plates, the wing on them | 4 |

The guide's FIGURES section points at them in one line, and the head's step 2
says "on joints (attach; read_guide "figures")".

### The proof: seated where BrickAgent seats them, and valid by verify.py

`src/dev/by_connector_probe.gd` builds one case a joint kind as a design
says it, and asks three things of each: that every part lands where
BrickAgent's own `attach` puts it (the poses below were printed by
brickagent b3df55e, MIT, for the same calls), that BrickNet's labels join
each part to the one it went on and its colliders find no two parts more
than 1 LDU into each other, and that our whole check passes the design.

| case | joint | off BrickAgent's pose | joined, clear | our check | verify.py |
|---|---|---|---|---|---|
| a brick on a stud, turned a quarter | stud and hole | 0.0000 LDU | yes | passes | valid |
| a round plate on a side stud | open stud and tube | 0.0000 LDU | yes | passes | valid |
| a bar in a clip, slid 4 LDU and turned 30 degrees | bar and clip | 0.0004 LDU | yes | passes | valid |
| a ball in its socket, swung 150 degrees | ball | 0.0004 LDU | yes | passes | valid |
| a hinge opened 30 degrees | click hinge | 0.0003 LDU | yes | passes | valid |
| the same hinge folded the way it does not open | click hinge | 0.0003 LDU | overlaps | refused, named as the hinge | (BrickAgent's check refuses it too) |
| an axle through a beam, slid 32 LDU | axle and pin hole | 0.0000 LDU | yes | passes | valid |
| a minifigure on a plate: legs on the hips, the torso on its fixed joint, arms swung 240 and 230 degrees, hands, the head turned 20 degrees on its neck, a hat, an axe in a hand | hinges, fixed, pin and socket, open stud, bar and clip | 0.001 LDU | yes | passes | valid |

verify.py is BrickBench's own, run on each case exported by
`brickbench.py`'s `export_one`: all seven valid, one piece each, no
collisions, nothing unstable. Through the tools as a session uses them,
submit_design stands a figure, edit_model hangs hands on arms named in that
design and a hat on its head by number, a later edit passes with the posed
arms standing, and read back every part is written where it stands. Six
refusals say why, and the last says what does mate. On the code before this
(7740d22, the lean and exact merge) all 43 of the probe's checks fail: every
part said by its connectors lands at 0, 0, 0.

### The controlled comparison, on ten more held-out prompts

**The prompts.** model-041 to model-050, the ten after the first forty in
file order, used by no run before: a puzzle cube with its top layer turned,
a potato toy, a balloon dog, a toilet with a head, a paperclip with eyes, an
armchair that hugs a pillow, a dumpster on fire, a lava lamp, a seated
statue of a thinking man, a pinball machine. Characters and things.

**The two arms.**
- **lean**: the merged lean and exact tree (`7740d22`), as it was.
- **attach**: the same with attach (`f64620b`).

Each ran from a `git archive` of its commit with the same private catalogue
(exact's shapes linked in), two designs a prompt, two at a time, on the
subscription, kept to BrickNet's 14,441 parts: 40 designs. Every design was
checked by their `verify.py`, drawn by our renderer from the same four
cameras, and judged by our pairwise judge against every other design of its
prompt and BrickAgent's: 200 verdicts, both orders of every pair
(`bench/results/brickbench-2026-10-15-attach`; the commands are those under
"Repeat it" with `prompts --start 41`, `--arm lean` and `--arm attach`, each
`--app` an archive of its commit, and `compare --arms lean,attach`).

| dimension | lean ELO (95%) | attach ELO (95%) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| likeness | 802 (590-903) | 868 (679-966) | 1330 (1197-1609) |
| surface | 886 (674-962) | 917 (701-1000) | 1197 (1070-1591) |
| colour | 913 (739-988) | 890 (727-962) | 1197 (1084-1589) |
| technique | 862 (679-945) | 874 (679-951) | 1264 (1133-1592) |
| creativity | 886 (783-950) | 850 (760-908) | 1265 (1188-1402) |
| buildability | 966 (883-1031) | 1040 (966-1113) | 994 (896-1091) |
| **overall** | **811 (622-903)** | **860 (670-948)** | **1329 (1197-1600)** |

Bradley-Terry over the arms, as their `elo.py` fits systems; the intervals
resample the ten prompts with all their verdicts. Our judge, not BrickBench's.

| head to head | verdicts for attach | 95% | prompts attach won every time / split / lost |
|---|---|---|---|
| attach vs lean, overall | 46 of 80 (58%) | 47-68% | 2 / 7 / 1 |
| attach vs lean, likeness | 48 of 80 (60%) | 49-70% | 3 / 6 / 1 |
| attach vs lean, technique | 42 of 80 (52%) | 42-63% | 1 / 8 / 1 |
| attach vs lean, surface | 43 of 80 (54%) | 43-64% | 1 / 9 / 0 |
| attach vs BrickAgent, overall | 2 of 40 (5%) | 1-17% | 0 / 1 / 9 |
| lean vs BrickAgent, overall | 2 of 40 (5%) | 1-17% | 0 / 1 / 9 |

| arm | valid (verify.py) | parts | stacked | plain | shaped | tiles | joints (median / pooled) | parts off the square |
|---|---|---|---|---|---|---|---|---|
| lean | 16 of 20 | 194.5 | 58% | 55% | 35% | 12% | 0% / 0.6% | 9.8%, in 9 builds |
| attach | **17 of 20** | 124 | 62% | 54% | 39% | 12% | 0% / 0.8% | 12.6%, in 7 builds |
| BrickAgent | 10 of 10 | 174.5 | 42% | 32% | 44% | 26% | 1% / 1.2% | 26.2%, in 6 builds |

Medians over each arm's builds (`brickbench.py compare`); pooled is every
build's parts together; off the square is any part not on one of the 24
square orientations. On these prompts BrickAgent's own joint share is 1%,
not the 4% of its characters (model-031 to 040): only the toilet's head, the
armchair, the dumpster and the paperclip call for a joint at all.

**What the sessions did with it**, from their Claude Code transcripts:
- **7 of 20 sessions attached parts, 211 of the 2,867 bricks they sent**,
  none in the other arm. All of it was what the corner could not say: a flame
  on a round brick's hollow stud turned to its own angle (the dumpster, 80
  and 93 parts), tooth plates aimed out of an armchair's side studs as
  eyelashes (20), jumper plates turned 15 degrees on a paperclip's studs as
  raised eyebrows (12), eyes on side studs.
- **No session asked for the new techniques by name**, and none posed a
  figure on its joints: the statue was a shape and a stack in both arms, the
  balloon dog a stack of round parts. These prompts sent most sessions to the
  shape patterns (8 of 20 read "shapes"); one read "figures", and its one
  line did not move it.
- **Six answers refused an attach**, all in the dumpster's two sessions, each
  fixed on the next call: a bar asked into a round brick's hollow stud, which
  takes a stud's kind (the same spot is its clip, which a bar goes in; the
  refusal says so now, `9e147ef`), a stud on a part that has an open one.
- **Where it was used, the judge preferred it**: 8 of 8 verdicts for the
  dumpster, 7 of 8 for the armchair. Where it was not, the two arms traded
  prompts as two runs of one arm do (the balloon dog 0 of 8, the pinball
  machine 8 of 8, neither with an attached part).

**What it did.**
- **Validity held and edged up**: 17 of 20 against 16, against their 10 of
  10. Of the three that failed, two have a piece our check called standing
  that verify.py's simulation moved more than 3 LDU (a dish resting on a
  round plate; a trash can lying on its side, which rolled); the third is a
  flame against a tipped lid that verify.py counts as a collision and our
  exact check (exact_dump) does not. All three are the exact check's to
  close; none was an attached part off its seat.
- **The judge leaned to it, not past the noise on overall**: 58% of the 80
  verdicts between the arms, 47-68%; likeness just clear, 60% (49-70%);
  buildability up 74 ELO. Neither arm won more than 2 of 40 against
  BrickAgent.
- **The vocabulary barely moved**: shaped 39% against 35%, parts off the
  square 12.6% against 9.8%, against BrickAgent's 44% and 26%. Joints are a
  little of each arm's builds and of theirs on these prompts.

### No regression on big subjects

The car and the fire truck went through `tools/bench/run.py` on the attach
code (`9e147ef`), two designs each, as round `2026-10-15-attach`, and were
judged in pairs against every design of their subject from every round.
All four sessions put a few parts by their connectors (1 to 8).

| subject | 1-10 mean, run 1 / run 2 | the figures round's | pairwise ELO, run 1 / run 2 | the figures round's | against the figures round's designs, overall |
|---|---|---|---|---|---|
| car (speed_champions) | 4.17 / 4.33 | 4.17 / 4.17 | 872 / 1162 | 997 / 979 | 5 of 8 (31-86%) |
| fire truck | 6.00 / 6.33 | 6.67 / 6.67 | 965 / 1251 | 965 / 1198 | 5 of 8 (31-86%) |

Against the cabins round they won 4 of 8 (car) and 5 of 8 (fire truck).
The run-to-run spread is wider than any of it: the car's two designs are
290 ELO apart. No regression; no gain shown either. The tables are in
[DESIGN_SCORES.md](DESIGN_SCORES.md).

### What is left

- **Figures on joints.** The tool is there and exact; the sessions use it for
  details, not for a figure's limbs. The guide sends a character to "figures"
  and three in twenty read it. What would move it is guidance in the answers
  a session reads anyway: check_design's reply on a character naming the
  joint techniques, or plan_scale's figure answer laying a posed minifigure
  in one call (place_technique "posed minifigure").
- **The exact check's last gaps**, from verify.py's three failures above: a
  piece joined to nothing that it calls standing and the simulation moves,
  and one collision at an angle it does not find.
- **variety_probe** waits more than 20 minutes on a 535-part check with every
  part at the origin, on `7740d22` as here: the exact check asks every pair.
  face, rooms, detail and print fail on `7740d22` too (exact's "left").

## 2026-10-15, later: figures on joints, told where they decide

Attach gave sessions the joints; the attach round's transcripts say why none
used them for a figure. Every character session (the potato toy, the balloon
dog, the toilet with a head, the seated statue: two each) decided how to build
at its **first submit_design or check_design**, and six of the eight had just
read `read_guide "shapes"`, the section read_guide's own description sent them
to ("the patterns that lay ... a body and a head with its face"). Eight of the
round's ten guide reads were "shapes"; one was "figures". What those first
replies said of a figure:

- **check_design could not tell a figure from a tower.** It carries no name,
  and a session from outside had not given the app its brief, so the statue,
  the potato and the toilet were told "a prism pattern, for a tower, a pier or a
  turret". Only the balloon dog's name ("dog") made it a living thing, whose
  advice said "the shape pattern, for a creature's body and head", the opposite
  of the figures guide.
- The one figure line was the tail of the small-ellipsoid hint ("its limbs on
  joints (read_guide "figures")"), and no session went.
- **plan_scale was never called** (0 of 40) and its figure answer named no joint.
- **No session searched for a limb or a joint part.**
- The first review came after the body stood, said "a hinge or a leg built rigid"
  among five faults of any model, and pointed at a section nobody read; the
  balloon dog's tail was settled "built", of round bricks, under a feature review
  that offered "tail on a bar".
- The only channel that taught attach was attachment_points' template: 7 of 20
  sessions attached something, for eyes, brows, lashes and flames, all after the
  body stood.

### The change (`6506514`; vehicles left out of it after the bench)

All of it in what a session reads anyway; nothing in the MCP head (3,493
characters with the connector's note, as before).

- **The subject, by its words** (`Style.character_of`): a figure (people's words,
  a statue, a mascot, he or she), a creature (the living things that are not
  plants), or a thing given a face (eyes, brows, a grin). A hyphenated word is its
  last part (a balloon-dog is a dog; a whale-tail spoiler is a tail). The app now
  hears the brief Claude Code is started on, and the subject plan_scale,
  find_reference and how_real_sets_build_this are asked about, so a check before
  the first submit knows it.
- **check_design's and submit_design's reply**, while nothing in the design is
  posed (an attach, a joint's part, a turned or hinged section), leads its advice
  with each joint's one call and one line of how: the posed minifigure, two new
  armatures ("jointed figure", a brick-built person 13 plates to the shoulders
  with ball shoulders and elbows and a head turned on a jumper; "jointed animal",
  four legs, a head on a ball neck, a tail on a bar), limb on a clip, ball
  shoulder, head on a neck, tail on a bar, hinged wing, and an attach written out.
  Twice in full, then a line.
- The living things' advice names the joints instead of the shape pattern.
- **plan_scale** offers a person at minifigure scale the posed minifigure, and a
  brick-built figure the armatures; a creature at a scale is told it is built on
  joints all the same.
- **search_parts** names the joint parts (60478 in 63868, 14417 or 22890 in
  14418, 44302a and 44301a, 3937 under 3938) under a search for a limb, and under
  a character's first search.
- **read_guide "shapes"** is led, for a character, by what a figure is built of;
  read_guide's description names "figures".
- **The review** names each limb a design named (a part, a section, an assembly)
  that stands stiff and stacked, square on the body with nothing on a joint, and
  says so of a character with nothing on a joint at all.

`src/dev/figure_joints_probe.gd` asks each of these of a statue, a balloon dog,
a lighthouse and their near misses: 39 checks.

### Exact's three gaps

Each confirmed on the case itself with BrickBench's own simulation or
colliders (`brickagent.physics._simulate`, `bricknet.collision`), and each a
case in `exact_probe` (29 passed, 0 failed).

- **042r2, "a dish on a round plate that PyBullet moves", is the body under it.**
  Without the dish the potato still moves 3.9 LDU, and let move it falls over
  (402 LDU): its centre of mass is 16 LDU behind the heels of its two shoes, and
  the dish moved because the body under it did. A dish on a round plate on a
  round brick stands (0.06 LDU). Our check held anything touching y=0 as held by
  the ground, as on a baseplate; BrickBench's ground is a bare plane.
- **047r1, the lying trash can,** touched the floor along one line of its facets
  and rolled 3.25 LDU.
- So **a piece only the floor holds must now settle on a bare floor**
  (`ExactCheck.tips`): it tips about the edge its centre of mass is past (or
  rolls, its centre over a line) until another of its points comes down, and
  fails if its furthest point moves more than 2.5 LDU; only points within that
  of the floor can catch it, so it is cheap. A bare floor is a design's floor
  "none" or "grid", or the app's; on a baseplate the studs hold. A ball plate
  lying on its ball, 4 LDU under its plate, tilts onto its far edge and stands,
  as verify.py passes it.
- **047r2, the flame against the tipped lid: our shapes were wrong.** BrickNet
  measures the flame 1.268 LDU into the 6 x 10 plate (an exact separating-axis
  test on its own pieces, 1.2685), our check 0. `tools/build_exact.py` read each
  collider group as the vertex lines written under it, and BrickNet's files share
  vertices between groups: 679 of 3033's 785 pieces and 49 of the flame's 74 lost
  corners, the deciding one a slab 4.6 LDU thick read as a quad 0.7 deep. A group
  is now the vertices its faces use, as BrickBench reads it; rebuilt, the
  catalogue's shapes are 984 MB (884 before) and the pair is 1.2686 LDU.
- The rebuilt shapes refuse what verify.py refuses and the old ones let through:
  the **log pile** construction (verify.py: 1 piece unstable; withdrawn), a pylon
  at 80 degrees whose hull stud is 1.275 LDU into it by BrickNet's colliders
  (section_probe now asks up to 70), and the shipped Orthanc checked as a new
  design finds 116 collisions where it found 90.

**The shared catalogue's exact/ folder must be built again** with the fixed
`build_exact.py` (`features/pipeline.md`); until it is, the app checks with the
corners missing. A built copy is in the round's scratch (`figjoints-a261/gen2/exact`).

### The controlled comparison, on ten held-out prompts and the four characters again

**The prompts.** model-051 to model-060, used by no run before: a hill home, a
skyscraper laboratory, a farmhouse and windmill, a doughnut shop with a rooftop
mascot, a mailroom conspiracy board, a giant in a cubicle, a spy on a cable, a
low office, a dirt-block house, a man looming over a model school. Six of the
ten are people in scenes. With them, the attach round's four characters again:
the potato toy, the balloon dog, the toilet with a head, the seated statue.

**The two arms.** merge29 (`5c4708e`, with the shapes as exact built them) and
joints (`6506514`, with the shapes rebuilt by the fixed `read_obj`). Each from a
`git archive` of its commit, two designs a prompt, two at a time, on the
subscription, kept to BrickNet's 14,441 parts: 56 designs. Every design checked
by verify.py, drawn from the same four cameras and judged against every other
design of its prompt and BrickAgent's: 280 verdicts, both orders
(`bench/results/brickbench-2026-10-15-joints`, `compare.md`).

| dimension | merge29 ELO (95%) | joints ELO (95%) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| likeness | 809 (722-877) | 883 (798-950) | 1308 (1241-1441) |
| surface | 920 (811-1005) | 912 (829-969) | 1168 (1077-1324) |
| colour | 844 (706-922) | 913 (817-955) | 1243 (1137-1449) |
| technique | 897 (827-955) | 921 (852-981) | 1182 (1110-1277) |
| creativity | 900 (816-957) | 919 (861-956) | 1182 (1105-1307) |
| buildability | 954 (886-1016) | 992 (939-1047) | 1054 (971-1132) |
| **overall** | **809 (725-867)** | **883 (811-949)** | **1308 (1248-1406)** |

| head to head, overall | verdicts for joints | 95% | prompts joints won every time / split / lost |
|---|---|---|---|
| joints vs merge29, all 14 | 67 of 112 (60%) | 51-68% | 2 / 12 / 0 |
| ...the characters (042, 043, 044, 049) | 22 of 32 (69%) | 51-82% | 1 / 3 / 0 |
| ...the people scenes (054-058, 060) | 33 of 48 (69%) | 55-80% | 1 / 5 / 0 |
| ...the rest (051-053, 059), never told | 12 of 32 (38%) | 23-55% | 0 / 4 / 0 |
| joints vs merge29, likeness | 67 of 112 (60%) | 51-68% | 3 / 11 / 0 |
| joints vs BrickAgent | 5 of 56 (9%) | 4-19% | 0 / 4 / 10 |
| merge29 vs BrickAgent | 2 of 56 (4%) | 1-12% | 0 / 2 / 12 |

The gain is where the guidance speaks and not elsewhere: the four buildings are
never told of joints, and there the arms trade verdicts as two runs of one arm
do. Against BrickAgent both arms still lose almost every verdict.

| arm | valid (verify.py) | shaped, characters | off the square, characters (pooled) | joints, characters (pooled) | sessions told of joints |
|---|---|---|---|---|---|
| merge29 | 26 of 28 | 30% | 0.1% | 0.1% | 0 of 28 |
| joints | **27 of 28** | 34% | 3.4% | 0.8% | 20 of 28 |
| BrickAgent | 14 of 14 | 36% | 0.2% | 0.1% | |

Shares by `brickbench.py`'s measure; on these prompts BrickAgent's characters
are 36% shaped, not the 62% of model-031 to 040, and its people scenes carry
their joints in minifigures, which the shares leave out as figure parts.

**Uptake, from the sessions' transcripts** (`uptake.py` in the round's scratch):

| | attach round | merge29 | joints |
|---|---|---|---|
| characters with a limb or torso posed on a joint (of 8) | 0 | 0 | **2** (both statues: an arm on a click hinge, a torso leaning on one) |
| characters told of joints (of 8) | 0 | 0 | 8 |
| people scenes posed on joints (of 12) | | 8 | 9 |
| people scenes told of joints (of 12) | | 0 | 12 |
| any session posed on a joint or a hinged section (of 28) | 8 of 20 | 12 | 16 |

The people scenes posed their minifigures on joints in both arms: merge29's
sessions found "posed minifigure" themselves (show_technique, 7 sessions). The
brick-built characters are where the change was aimed, and there it is told
every time and acted on twice in eight: the balloon dog's sessions read the
shapes guide's new lead and the joints in every submit's reply, and built round
bricks by hand. The judge still preferred the joints arm's characters 69% of the
time, likeness 63% (45-77%).

**Validity.** joints 27 of 28, merge29 26 of 28. Two of the three failures are
the same coin toss (a minifigure head exactly 1.0000 LDU into a 42446 bracket,
the spy in both arms), which verify.py's sum lands over and our check, judging at
1 LDU, passes. merge29's other failure, model-058's five collisions, our exact
dump finds all five of with the rebuilt shapes and none with exact's.

### No regression on big subjects: not shown, and one thing found

The car and the fire truck went through `run.py` on the merged tree before the
last fix, as round `2026-10-15-joints`, judged against every design of their
subject. `run.py rank` reads the lever joints against attach at **-126 ELO**
overall (judge's 95% -199 to -45; with the run-to-run spread -473 to +246); the
car's two designs rank 4th and 18th of 22 (1245 and 830, 415 apart), the fire
truck's 5th and 10th of 10 (1085 and 649, 436 apart; the second has a stud joint
overloaded, 99 g on one stud). The transcripts show why it could be the change:
**both cars and both fire trucks were told, in every check, that they were
figures with nothing on a joint** — "at minifigure scale" made the Porsche a
figure and "with a firefighter" the fire engine. Fixed after the bench (a
vehicle with its crew is a vehicle; "minifigure" is a scale, not a person:
`figure_joints_probe` asks both briefs), so a vehicle now hears none of it. The
two subjects were not run again on the fixed code.

### What is left

- **Brick-built characters still mostly stack.** Told every time, two of eight
  posed a limb. The likeliest reason: the joints come as a list after the
  session has already chosen its build, and a hand-built body of round bricks
  passes every check; the armature is a skeleton to dress, which costs a session
  more than the body it has. A first-submit refusal for a character with no
  joint, or a body pattern that lays on an armature, would test that.
- **The coin toss at exactly 1 LDU** (a head against a thin bracket, both arms):
  judging a design's own pairs at a hair under 1 LDU would close it, at the cost
  of refusing pairs verify.py sometimes passes.
- **The car and the fire truck on the fixed code**, to see the -126 go.
- **The shared catalogue's exact/ shapes** are exact's, with the corners missing;
  they need `tools/build_exact.py` again (a built copy is in the round's scratch,
  `figjoints-a261/gen2/exact`).

## 2026-10-16: characters laid on joints in one entry

The last round's open question was why told characters still stacked: two of
eight posed a limb. This round tests the two answers it proposed, together:
**a body pattern that lays on an armature** (`{"pattern": "figure"}`: a person,
a four-legged animal or a head on a neck, every limb, the head and the tail on a
working joint, posed by words, its parts named to build on), and **a
first-submit refusal**: a figure or creature submitted with nothing on a joint
is sent back once, with that entry written out for its box and colour, and built
as it is when it comes again. `src/dev/armature_probe.gd` proves both (82
checks): each kind joined by BrickNet's labels and passed by the check, each
joint turned by its pose and held through edits, the refusal once and never for
a vehicle with its crew or a tower.

The probe found one fault, and it was live: an outside design's name stayed as
the brief, so after a statue was built every later design in that app was read
as a figure (a fire engine, a Porsche and a lighthouse were told so, and would
have been sent back). A fresh brief or a cleared model now forgets it.

**The comparison.** m32 (main at `2789cd0`) against armature (`baf29eb`; its
first two designs ran on the same code uncommitted, `23da079-dirty`), one
design a prompt each, on the four characters of the last two rounds (model-042,
043, 044, 049) and two held out, used by no run before: model-078, a fat
rabbit, and model-080, an armoured boy. Same recipe as before (two at a time on
the subscription, BrickNet's parts only, four views each, our judge both orders
twice): 72 verdicts (`bench/results/brickbench-2026-10-16-armature`,
`compare.md`). BrickBench is one outside check here, not the target; the real-set
blind test (`tools/bench/realset.py`) is to judge the same designs next.

| head to head, overall | verdicts for armature | 95% | prompts won every time / split / lost |
|---|---|---|---|
| armature vs m32, all 6 | 12 of 24 (50%) | 31-69% | 3 / 0 / 3 |
| ...surface | 21 of 24 (88%) | 69-96% | 5 / 1 / 0 |
| ...the held-out two (078, 080) | 4 of 8 | | 1 / 0 / 1 |
| armature vs BrickAgent | 0 of 24 | 0-14% | 0 / 0 / 6 |
| m32 vs BrickAgent | 1 of 24 | 1-20% | 0 / 1 / 5 |

| arm | valid (verify.py) | parts (median) | stacked | shaped | joints | sent back once | laid the figure pattern | the pattern, an attach or a joint's part |
|---|---|---|---|---|---|---|---|---|
| m32 | 6 of 6 | 292 | 43% | 26% | 0% | | | 4 of 6 |
| armature | 6 of 6 | 188 | 55% | 44% | 1% | 5 of 6 | 3 of 6 | 5 of 6 |
| BrickAgent | 6 of 6 | 216 | 50% | 36% | 0% | | | |

**A tie.** Each prompt went one way every time, so this is six designs against
six, not a measured gain: armature won the balloon dog, the toilet with a head
and the armoured boy; m32 won the potato, the seated statue and the rabbit. The
judge preferred armature's surfaces almost every time and its buildability ELO
is higher (1039 against 942), on two thirds the parts. Likeness, the overall
verdict, is level. Both still lose nearly every verdict to BrickAgent.

**Uptake.** The refusal reached five of six (the potato had attached parts, so it
was posed). Three of the five laid the pattern (the toilet's head, the statue,
the boy); the balloon dog and the rabbit built their own way when they came
again, the rabbit's arms on ball joints by attach. m32's sessions found joints
without being sent back in half the characters (a ball neck, a tail on a bar,
ball shoulders), so the gap the refusal closes is smaller on this code than on
merge29's.

**What the views show** (`bench/results/armature-2026-10-16/views*`). The
pattern's people and animals read as built figures, not statues, and every joint
turns. Seen front and corner, the large person's legs stood together as one
pillar and a seated person's lap was one studded slab that read as a table: both
fixed before the bench (legs apart; a thigh each). Still wrong and not small:
heads have no face (a session must dress one);
an animal's eyes sit on top of its head, not its front; "to chin" and "on knee"
are said as bent and forward, which do not reach the chin or the knee; and the
grey joint plates show on a coloured back.

**What is left.** The statue lost with the pattern laid four times: the pattern
gives the pose, and a hunched, chin-on-fist statue needs the torso leaning and
the arms reaching, which its words cannot say yet. Faces and torso lean are
the next things a session should not have to build by hand. Two designs a prompt,
and more held-out characters, would say whether the surface gain carries to the
overall verdict.

## 2026-10-16, later: faces, a lean, and joints in their colours

The armature round's views listed what still read wrong in what the figure
pattern lays: heads had no face, an animal's eyes sat on top of its head, the
grey joint plates showed, no torso could lean, and "to chin" and "on knee" did
not reach. This round fixes four of the five, built the way real character sets
build them. Looked at first: BrickHeadz (40349 Puppy, 41608 Han Solo, 40271
Bunny, 41634 Emmet) put two printed round eyes a stud apart on side studs;
Creator animals (30285 Tiger, 30026 Panda, 4903 Lion) put a printed eye tile or
a round plate on each side of the head and a nose on the muzzle.

- **A face on every head.** A person's head, and a head on a neck, is a round
  brick with a course over it: a brick with two studs on its front (11211)
  carrying two printed eye tiles (98138p07, white, the eye and its highlight
  printed), the back of the head in the hair's colour, the hair over both. The
  eyes face the way the head is turned. An animal's head carries a brick with
  studs on two opposite sides (47905), an eye out of each side, and a black
  round tile for a nose on its muzzle. `"face": false` leaves it to the
  session. A person has no mouth: the round brick under the eyes turns on the
  jumper and has no stud for one, and a BrickHeadz face is its eyes.
- **Joints in the body's colours.** The ball parts are sold in greys only
  (14417, 14419 and 22890 dark bluish grey, 14418 light), so they are covered:
  a tile in the sleeve's colour on each shoulder plate, one in the body's colour
  on an animal's neck plate. Its tail's bar plate (60478) is sold in 25 colours
  and takes the body's.
- **A lean.** `"lean": "forward"` (25°), `"back"` (15°), `"left"` or
  `"right"` (10°), or degrees. The torso's first course becomes hinge bricks
  (3937) with their tops (3938), and the torso is built up on the tops by its
  connectors, so the chest, the arms and the head lean as one. A hinge top
  turns one way off its base before meeting it, so the base is turned to the
  lean and the torso set on the top turned back square, at the corner the top's
  stud was measured to be at each turn. Leaning to a side, an arm hanging on the
  side that rises keeps its pose to the torso. All 180 leans tried (six words,
  five heights, standing and seated, three pairs of arm poses) pass the check.
- **Not done: reaches.** Solved to put a hand under the chin or on the knee,
  the arm runs into itself. Searched against the real clash check, 980 poses at
  30 plates put a hand under the chin and none keeps the upper arm's socket out
  of its shoulder plate by 1 LDU (the nearest 1.35 in); of 1,584 for a seated
  hand on the knee the nearest is 1.05 LDU in, 5.6 LDU from the knee, and 1.11
  leaned 25°. A reach needs a shoulder other than 14417's ball on the chest's
  side. The words still say bent and forward.

`src/dev/armature_probe.gd` proves it (106 checks, 0 failed): each kind's eyes
within a degree of the way its head faces, an animal's square to the way it
looks and its nose 20 LDU ahead, the covers in their colours, the chest tipped
by each lean's degrees and passed at 30 and 42 plates with every arm pose, and
the head re-posed by an edit with its eyes on it. `figure_joints_probe` is
unchanged and passes (43). The views of every kind, front and corner, on the
GPU, before beside after: `bench/results/faces-2026-10-16/sheet_before_after.png`
and `sheet_leans.png`. Each head now reads as a face from across the room; the
animal's eyes look out of its sides as the Creator tiger's do; the seated
figure hunches. The eyes stand a plate and a half proud, more cartoon than a
BrickHeadz face, and the grey edges of the shoulder plates and the animal's jaw
still show under their covers.

**BrickBench, once, as an outside check.** The same six character prompts as
the armature round, one design each, the arm `figfaces` (`ccab190`: faces,
covers and the forward lean; back and sideways came after) against that
round's `armature` designs and BrickAgent's, our judge both orders twice: 72
verdicts (`bench/results/brickbench-2026-10-16-armature`,
`faces-2026-10-16/compare-armature-figfaces.md`; the round's own `compare.md`
kept).

| head to head | verdicts for figfaces | 95% | prompts won every time / split / lost |
|---|---|---|---|
| figfaces vs armature, overall | 13 of 24 (54%) | 35-72% | 2 / 3 / 1 |
| ...likeness | 16 of 24 (67%) | 47-82% | 3 / 2 / 1 |
| ...surface | 12 of 24 (50%) | 31-69% | 3 / 0 / 3 |
| ...technique | 12 of 24 (50%) | 31-69% | 2 / 2 / 2 |
| figfaces vs BrickAgent, overall | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |
| armature vs BrickAgent, overall | 0 of 24 (0%) | 0-14% | 0 / 0 / 6 |

All six valid by verify.py. By ELO the arms overlap on every dimension;
buildability leans to armature (1061, 969-1238, against 888, 449-1048) and
likeness to figfaces (895, 674-1045, against 759, 588-844). A tie, as the last
round's was.

**Uptake.** Five of six were sent back once and five laid the pattern (the
balloon dog, the toilet's head, the statue, the rabbit, the boy; the armature
round, three). Two kept it to the end: the boy, its body, eyes and all, and the
rabbit, ball arms of its own. The statue laid itself seated and leaning
forward and was built, then aimed its arms by hand to reach the chin and the
knee, was refused four times for an arm running into the body, and rebuilt
itself stacked: the reach gap, met by a session.

**What is left.** The arms' reach, which needs another shoulder. A head as
wide as its body, which is how a BrickHeadz brief is built: the real-set test's
three characters never laid the pattern in either arm (docs/DESIGN_SCORES.md),
so faces cannot reach them until it can say one.

## 2026-10-22: m147 against BrickAgent, and where the gap is

The release about to go live, rel-m147 (`9379fbb1`), on the six character
prompts of the 10-16 rounds (model-042, 043, 044, 049, 078, 080), one design
each, beside that round's figfaces designs (`ccab190`) and BrickAgent's Opus
5.5 builds. The prompts, the parts list and BrickAgent's builds were copied
from the 10-16 folder, so the field is the same. All three drawn again by one
renderer on the GPU and judged by our judge, every pair both orders twice: 72
verdicts (`bench/results/brickbench-2026-10-22-m147`, `compare.md`).

**Valid: 6 of 6** by verify.py, geometry reproduced, `parts only` in every
log. The toilet is two components (251 parts and one resting loose), which
verify.py passes and the judge counts against it. A design took 12.7 minutes
at the median (8.1 to 14.2); figfaces' took 8.5. The bench runs one design a
brief; the panel's best of two is not measured here.

| head to head, overall | verdicts for the first | 95% | prompts won every time / split / lost |
|---|---|---|---|
| m147 vs BrickAgent | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |
| figfaces vs BrickAgent, judged again | 3 of 24 (12%) | 4-31% | 0 / 1 / 5 |
| m147 vs figfaces | 17 of 24 (71%) | 51-85% | 3 / 2 / 1 |
| ...likeness | 17 of 24 (71%) | 51-85% | 3 / 2 / 1 |

| dimension | m147 ELO (95%) | figfaces ELO (95%) | BrickAgent ELO (95%) |
|---|---|---|---|
| likeness | 933 (811-1079) | 823 (515-1000) | 1244 (1140-1572) |
| surface | 961 (734-1090) | 971 (789-1103) | 1068 (905-1404) |
| colour | 956 (674-1113) | 892 (749-971) | 1152 (980-1536) |
| technique | 1000 (808-1154) | 931 (735-1060) | 1069 (914-1266) |
| creativity | 934 (789-1034) | 901 (759-1023) | 1165 (1070-1346) |
| buildability | 1062 (911-1294) | 876 (455-1038) | 1062 (942-1343) |
| **overall** | **933 (811-1079)** | **823 (515-1000)** | **1244 (1139-1572)** |

**Against the 10-16 round.** That round gave figfaces 2 of 24 against
BrickAgent; judged again here it has 3, so the judge reads the field as it
did. The units since are a real gain on characters: m147 beats figfaces head
to head on five of six prompts, about 110 ELO. Against BrickAgent nothing
moved: 2 of 24 again, about 310 ELO behind. The rabbit split (two verdicts for
its round body); the other five were lost every time. m147 lost the toilet to
figfaces 4-0, for the loose part and a head out of proportion.

### What the judge held against ours

Read as a builder would: each build's four views beside BrickAgent's
(`sheets/`), the reasons of all 24 verdicts (`reasons-m147-opus.txt`), what
each build is made of (`scripts/parts_of.py`), and the sessions' transcripts.

Two things are not the gap. **Recognition:** a cold reader (Claude Code with
Read only, the four views, no brief; `scripts/blindread.py`) named five of
m147's six as their subject (Mr. Potato Head, a balloon dog on a plinth,
Skibidi Toilet, a chubby bunny, a man in a shark suit) and the statue "an
elephant clambering over a stone wall"; BrickAgent's, all six. The judge knows
what ours are and likes theirs better. **The vocabulary in aggregate:** shaped
36% in both, stacked 50% in both, joints 2% and 0%, buildability 1062 each.
What differs is which shaped part goes where.

The 22 lost verdicts, by how many give each as a reason (likeness and overall
read together):

1. **The body's outline: a box, slab, drum or barrel where the subject is
   round, pinched or posed. 21 of 22.** The potato "a tall blocky barrel" (4),
   the balloon dog "a flat slab table on cylinder legs" (4), the toilet "a
   square box bowl" (4), the statue "a tilted slab on two pillars" (4), the boy
   "a squat grey block" (3), the rabbit "a drum" (2). BrickAgent's outlines are
   large curved parts set on the silhouette. 90 of its potato's 237 parts are
   corner rounds (3063b, 27925, 27507, 79393, 30565, 2577, 5152, 6003), an oval
   face laid sideways. Every balloon segment is an inverted ovoid dome (24947)
   on a domed cylinder (3262), so each tapers at both ends and pinches at the
   next. The bowl is round and corner-round bricks (2577, 3063b, 87081).
   Ours: the potato is 98 plates 1 x 1 and 7% tiles, the balloon's body a
   plate deck on round bricks, the bowl 2 x 3 bricks. The one prompt we split, the rabbit, is the
   one body of ours built of large corner rounds (24 of 2577), and the two
   verdicts it won said so.
2. **Defining features that read as something else. 14 of 22.** The ear for a
   mouth reads as a tongue (4: two pink curved slopes under a round plate;
   BrickAgent's is a pink macaroni brick and corner tile); the cold reader,
   told the brief, took the mustache (a plate 1 x 4 and two curved slopes)
   for a bow tie. The boy's hair is a flat brim and
   his grin a grille (4; BrickAgent's hair is 17 quadruple slopes 22388, its
   grin buck teeth). The rabbit's belly is a band
   round a drum, not a panel (2). The toilet's face is less expressive (4).
3. **Limbs posed where the brief does not put them. 10 of 22.** The statue's
   torso is tipped forward on hinges as one slab (the figure pattern's
   `"lean": "forward"`), with no elbow and no fist at a chin (4). The boy's
   arms stick out sideways and throw no punch (3). The rabbit's arms jut out
   on ball joints (2); its session said "The arms can't hang any lower without
   hitting the body, so they stay at their outward angle". The potato has no
   arms (1). BrickAgent's rabbit, boy and statue have limbs of bricks, laid on
   the body where the pose puts them, with no joint.
4. **Colour. 3 of 22:** the boy is all grey, where BrickAgent dressed him in blue.

**Why the first two: the session asked for the parts and was told they do not
exist.** Four of six sessions had a search for a shaping part come back empty
or wrong, three of them for the very parts BrickAgent's winning builds are
made of. search_parts, kept to BrickNet's list as BrickBench requires,
answered as follows (the same words through the app's own `Assistant._search`;
`scripts/search_check.gd`):

| the session asked | the app answered | plainer words find |
|---|---|---|
| "dome bottom 2 x 2 round inverted" (balloon dog) | No parts match | 24947, the ovoid BrickAgent used |
| "tile 2x2 macaroni curved", "tile 2x2 round corner quarter" (potato) | No parts match | 27925 |
| "tile round corner 4 x 4 macaroni" (rabbit) | 27925ph0, a printed 2 x 2 | 27507 |
| "slope curved 1 x 3 or 1 x 4 double ear" (rabbit) | 61484d01, a stickered 5 x 6 | 93273 |
| "brick 1x4 with 4 studs on one side" (boy) | 88930py0, an AMG grille print | 30414 |
| "spiky hair" (boy) | 53982, minifig hair | 22388, as "slope 1 x 1 quadruple" |

The potato's session took it that none existed and built the ear and the
mustache of curved slopes and plates. The rabbit's said "No macaroni tile available, so the stud
rings around the shoulders stay". The balloon dog's built round bricks. Two
faults make it. Every word must be in a part's name or keywords, so one
builder's word the catalogue does not use ("macaroni" on 27507, "quarter",
"bottom", "curved", "round") hides the right part. And keywords match as
substrings, so "4" is found in "LegoID 6410654" and "one" in "Project One",
and prints and stickers come first. BrickAgent's `find` ranks every part by how
many of the asked words it matches, so an extra word lowers a part and never
hides it. The prompts whose reasons trace to those parts (the potato, the
balloon dog, the boy's hair) carry 12 of the 22 lost verdicts.

The toilet and the statue found their parts and still laid them square (the
bowl's corner rounds are "odd round pieces stuck on the sides") or as a slab.
That is the outline's other half, and posture is the next gap after it.

### The next lever: search_parts that finds what a builder describes

- **What changes.** `Assistant._search` and `PartLibrary.search` rank by how
  many of the asked words a part matches: all first, then most, and a size
  asked must match. Keywords match as whole words. A builder's shape words are
  translated (macaroni and quarter to corner round, bottom and underside to
  inverted, ovoid, spiky to quadruple slope, studs on one side to studs on
  side). Plain parts come before prints and stickers unless a print is asked
  for. "No parts match" only when no word matches. find_parts_like names real
  parts for a mustache, spiky hair and an ear.
- **Proof in the unit** (a probe, minutes): each query in the table returns
  the part in its right-hand column within its first six. Every query of this
  round's six transcripts that found its part still gets the same first answer.
- **The bar on this bench** (the lead's run: six designs two at a time, about
  50 minutes, then 72 verdicts): the six prompts, one design each, against m147
  and BrickAgent, `pairs --repeat 2`. Head to head with m147, at least 60%
  overall and no prompt lost every time. Against BrickAgent, at least 6 of 24
  overall (from 2), with the potato and the balloon dog no longer lost every
  time and their sessions using the shaping parts (corner-round tiles, 24947).
  Six of six valid by verify.py.
- **After it:** limbs laid where the brief puts them (the rabbit's arms
  hanging, the boy's fist forward, the statue's elbow on its knee), which the
  armature's joints cannot reach against a body. Then the outline laid from the
  parts once found.

## 2026-10-22, later: the new search on the same six, and nobody asked it

search156 (`9590a07d`) is m147 with the new `search_parts` (`PartSearch`):
words ranked by how many match, builders' words translated, plain parts before
prints. Nothing else a design reaches changed. It designed the same six prompts,
one design each, in the m147 round's folder. Its builds were drawn on the GPU by
the same renderer and judged against m147's and BrickAgent's, every pair both
orders twice: 72 verdicts. The 24 between m147 and BrickAgent are the m147
round's, read back (`compare-search156.md`; that round's `compare.md` is as it
was).

**Valid: 6 of 6** by verify.py, geometry reproduced, `parts only` in every log,
`9590a07d` in every `design.json`. The boy is two components (a loose part),
which verify.py passes and the judge held against it. A design took
8.2 minutes at the median (5.4 to 10.1; m147's 12.7) and is smaller: 128 parts
at the median against m147's 202.

| head to head, overall | verdicts for the first | 95% | prompts won every time / split / lost |
|---|---|---|---|
| search156 vs m147 | 9 of 24 (38%) | 21-57% | 1 / 3 / 2 |
| search156 vs BrickAgent | 4 of 24 (17%) | 7-36% | 0 / 2 / 4 |
| m147 vs BrickAgent (the m147 round's verdicts) | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |

| dimension | search156 ELO (95%) | m147 ELO (95%) | BrickAgent ELO (95%) |
|---|---|---|---|
| likeness | 884 (654-1036) | 918 (815-1027) | 1199 (1116-1370) |
| surface | 990 (735-1125) | 931 (637-1049) | 1079 (916-1545) |
| colour | 881 (691-951) | 967 (735-1101) | 1153 (980-1533) |
| technique | 932 (772-1027) | 1010 (819-1151) | 1059 (895-1343) |
| creativity | 851 (675-935) | 964 (869-1024) | 1185 (1080-1370) |
| buildability | 1019 (875-1221) | 962 (808-1100) | 1019 (869-1192) |
| **overall** | **868 (643-1012)** | **914 (799-1043)** | **1218 (1150-1370)** |

| prompt | vs m147 | vs BrickAgent | what the judge said of search156's |
|---|---|---|---|
| potato (042) | 1-3 | 0-4 | "a tall, narrow dark-brown block"; its ear "a stack of pink studded plates", "more like a tongue" |
| balloon dog (043) | 0-4 | 0-4 | "boxy slab body and straight cylinder pillars", a flat wedge for a muzzle |
| toilet (044) | 4-0 | 2-2 | a round bowl, the long neck, and one piece where m147's and BrickAgent's each have a loose part |
| statue (049) | 2-2 | 2-2 | a hunched seated statue to some verdicts, "an upright, studded stack" or "doesn't read as the subject" to the others |
| rabbit (078) | 0-4 | 0-4 | "a slim striped barrel" that does not read enormously fat |
| boy (080) | 2-2 | 0-4 | better colour than m147's grey, and the loose part |

**The bar is missed.** Against m147, 38% where it asked 60%, and two prompts
lost every time. Against BrickAgent, 4 of 24 where it asked 6. The potato and
the balloon dog were lost 4 of 4 again, and neither build has a corner-round
tile or a 24947. Six of six valid is the one part met. With one design a
prompt, 9 of 24 is not told apart from an even match (21-57%). The two prompts
split with BrickAgent, the toilet and the statue, owe nothing to a search: the
bowl's round plates and round bricks (74611, 3941) were never searched for, the
toilet won its two for being one piece, and the statue won its two only when
BrickAgent's was shown first.

### What the sessions asked the search

The search answered everything it was asked. **It was not asked for an
outline.** Six sessions made 21 searches, and none came back empty (m147's made
35, and 6 came back empty). No session asked for a corner-round tile, an
inverted dome, an ovoid or spiky hair, the parts the m147 round traced 12 of
its 22 lost verdicts to. The boy made no search and built his hair of tooth
plates. Every session laid its body in its first `submit_design`, before its
first search; the potato never laid it again. The searches came after, for
features: a nose, a mustache, an ear, side studs, a turntable, eye and mouth
prints.

The round's 18 distinct queries, through both apps' own `Assistant._search`
(`scripts/search_check_bench160.gd`, headless, with the round's list): 13 get
m147's first answer. Two, "brick 2 x 2 round dome top" and "brick round 2x2
dome top", get a different first part: 5906 now, 20952 then. Three were empty on m147 and are answered now:

| query | search156 answers | the design |
|---|---|---|
| "plate 2 x 3 rounded end" (potato) | 3176, 41948, 35480, 80031, 77850 | its ear of 35480 and 77850, which the judge read as a tongue |
| "tile mouth teeth grin print" (toilet) | 3626cpnc, 14769p02, 98138p1x | none of them |
| "buck teeth print" (rabbit) | 2431pk0, a teeth print | plain white 2431 instead |

The parts a search found were used where the session asked: the potato's nose
(30367c), side-stud bricks (30414), turntables, eye tiles (98138p07), and the
rabbit's round body of twelve 2577 and four 49612 from "brick 4 x 4 round
corner". m147 gives that last answer too.

Against m147 the verdicts follow each session's choices, not the search. The
toilet won on a round bowl and being one piece; m147 lost the same prompt to
figfaces for its loose part. The rabbit lost for being slim, and the balloon
dog for a slab head and a flat muzzle. None of the queries that came back
empty for m147's sessions was asked this time.

### The next lever: the outline parts before the body is laid

The search finds what a builder asks for. The designer does not ask for an
outline's parts: every session read a guide first (`shapes` twice, `figures`
four times), then laid its body. So the parts have to be in what it reads
first, or in what lays the body for it.

- **What changes.** The `shapes` and `figures` guides name the parts that make
  an outline by the silhouette they make: a round or egg body faced with
  corner-round bricks and tiles (2577, 3063b, 27925, 27507), a balloon's
  pinched segment as 24947 on 3262, spiky hair as 22388. Or the body patterns
  (`round`, the figure's torso) lay them when asked for a round body.
- **Proof in the unit** (minutes): the potato and the balloon dog briefs in a
  short design each, whose builds have corner-round tiles and a 24947.
- **The bar on this bench:** this round's, unchanged.

## 2026-10-22, night: the outline parts laid, as drums

outline161 (`71f25bdb`) is search156's search with a new guide section, THE
OUTLINE OF A ROUNDED BODY (`read_guide "outline"`, and in what `figures`
returns). It names a part for each edge of a rounded body: corner rounds,
rounded tops, inverted curved slopes, 24947 on 3262 for a pinched segment,
22388 for spikes. It asks for the body whole in one submit, and a body laid
from those parts is no longer sent back for joints. It also carries what main
merged since search156 (offered placements that are never refused, studs on a
turned part). It designed the same six prompts, one design each, in the m147
round's folder. Its builds were drawn on the GPU by the same renderer and
judged against m147's and BrickAgent's, every pair both orders twice: 72
verdicts. The 24 between m147 and BrickAgent are the m147 round's, read back
(`compare-outline161.md`; that round's `compare.md` is as it was).

**Valid: 6 of 6** by verify.py, geometry reproduced, `parts only` in every log,
`71f25bdb` in every `design.json`. Two builds come apart, which verify.py passes
and the judge held against them. The potato is two pieces: the dish on top of
its hat is loose. The rabbit is 13 pieces: twelve 1 x 1 slopes (54200) round
its head and shoulders that BrickNet's connection graph joins to nothing. The
app's check told that session "it holds together" (`scripts/loose.py` names
them).

| a design, the median of six | minutes | API dollars | replies | parts |
|---|---|---|---|---|
| outline161 | 9.5 (7.5-12.0) | 2.59 (16.90 for six) | 31 | 122 |
| search156 | 8.0 (5.2-9.9) | 2.30 (14.02) | 32 | 128 |
| m147 | 12.7 (8.1-14.2) | 3.14 (19.18) | 50 | 202 |

Minutes are each `design.json`'s `design_seconds`, dollars the log's `api_usd`
(`scripts/cost.py`). On that measure search156's median is 8.0, not the 8.2 of
its section, which counted the whole run. outline161 costs 13% more a design
than search156 (21% more over the six) and 18% less than m147. The unit's +43%
on its held-out briefs is not seen here.

| head to head, overall | verdicts for the first | 95% | prompts won every time / split / lost |
|---|---|---|---|
| outline161 vs m147 | 11 of 24 (46%) | 28-65% | 1 / 3 / 2 |
| outline161 vs BrickAgent | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |
| search156 vs m147 (the search round) | 9 of 24 (38%) | 21-57% | 1 / 3 / 2 |
| m147 vs BrickAgent (the m147 round's verdicts) | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |

| dimension | outline161 ELO (95%) | m147 ELO (95%) | BrickAgent ELO (95%) |
|---|---|---|---|
| likeness | 815 (643-914) | 915 (706-1053) | 1269 (1183-1540) |
| surface | 990 (834-1048) | 931 (557-1090) | 1079 (920-1572) |
| colour | 957 (776-1020) | 905 (614-1039) | 1138 (971-1551) |
| technique | 931 (782-1029) | 990 (759-1152) | 1079 (917-1341) |
| creativity | 946 (706-1086) | 903 (706-981) | 1151 (1019-1536) |
| buildability | 962 (782-1127) | 1000 (875-1112) | 1038 (909-1199) |
| **overall** | **855 (691-940)** | **879 (657-1027)** | **1266 (1181-1545)** |

Against m147, outline161 wins surface (15 of 24) and loses likeness (8 of 24).

| prompt | vs m147 | vs BrickAgent | outline parts in it | what the judge said of outline161's |
|---|---|---|---|---|
| potato (042) | 0-4 | 0-4 | 55 corner rounds (2577, 48092, 79491, 30565) | a cylinder or a can in 8 of 8, "a straight-sided brown cylinder that looks more like a can than a potato", against m147's "tapered egg"; two pieces |
| balloon dog (043) | 3-1 | 0-4 | 10 of 24947 on 10 of 3262 | "pinched balloon segments" beat m147's "slab-and-cylinder build"; against BrickAgent, "flat plate hip frames", "two separate H-shapes", a tail straight up |
| toilet (044) | 3-1 | 0-4 | 40 corner-round bricks, 26 of them in the head | one piece and a rounder head beat m147's loose part; BrickAgent's "rounded bowl" beat a "boxy bowl" under "an oversized barrel head" |
| statue (049) | 1-3 | 2-2 | none | its finish won 2 of 4 against BrickAgent; "sits upright", no chin on a fist, in all 5 it lost |
| rabbit (078) | 0-4 | 0-4 | 28 corner rounds (5152, 48092, 30565) | "a narrow stacked cylinder", "a stack of drums", a pig's snout, 13 pieces (8 of 8) |
| boy (080) | 4-0 | 0-4 | 16 of 22388 for hair | spiky hair, colour, the fin and the punch beat m147; BrickAgent's hair, buck-toothed grin and shark-mouth chest beat "a flat crop" and "a slot mouth" |

**The bar is missed.** Against m147, 46% where it asked 60%, and two prompts
lost every time (the potato and the rabbit). Against BrickAgent, 2 of 24 where
it asked 6. The potato and the balloon dog were lost 4 of 4 again, though both
now have the parts the bar asked for: 55 corner rounds in the potato, ten
24947 in the balloon dog. Six of six valid is the one part met. 11 of 24 is not
told apart from an even match (28-65%).

### What the sessions did with the outline

Every session had the section before its first submit: four read `outline`
first, and the statue and the boy got it inside `figures`. Every rounded body
used its parts (`scripts/outline_parts.py`; m147's and search156's builds had
corner rounds only in the rabbit and four in m147's toilet, and no 24947). The
potato and the toilet searched for corner rounds, the balloon dog for 24947
and 3262 by number and by name. So the lever reached the sessions. The parts
it reached them with did not make the shape.

**Round in plan, straight in elevation.** The potato's first two submits were
the round pattern with bands that swell and narrow (diameters 8, 6, 6, 8, 4).
Its third followed the section's step 4, which names a potato: "build that
face as layers stacked toward the viewer". It laid the body behind that face by
hand, as rings of 2577 and 48092 of one size, 10 studs across, bottom to top.
view_model told it "plates 0-5 10 across x 11 deep ... plates 30-35 10 across x
9 deep", and the session said "the potato reads well". The rabbit also began
with the round pattern (8, 6, 8, 6, 4, 6, 4), then replaced it with 73 parts by
hand: a body 8 studs deep from plate 0 to 17 and a head 6 across, where the
brief says enormously fat. The toilet put 26 of its corner rounds in the
head, which the judge read as a barrel over a boxy bowl. Step 3 of the section
says exactly this: "corner rounds on straight sides make a drum, and are read
as one". Nothing in the check measured it, and m147's potato of 1 x 1 plates
had the egg's taper that the corner rounds lost.

**The balloon dog is the lever working.** Its segments are the ones BrickAgent
built, and the judge named them in all three of its wins over m147. It lost to
BrickAgent on what lies between them: plate frames for hips, no body balloon,
a tail straight up.

### Where the gap is now

The 22 verdicts lost to BrickAgent, by what their reasons hold against it:

1. **An outline round from above and straight from the side: a can, a stack of
   drums, a barrel head. 12 of 22** (the potato, the rabbit and the toilet, 4
   each). It was 21 of 22 for m147, said then of boxes, slabs and drums.
2. **Loose parts. 6 of 22** (the rabbit 4, the potato 2), all within the 12.
   The rabbit's twelve slopes are where the app's check and BrickNet's graph
   disagree: the session was told the build held.
3. **The posture, and the body between the parts. 6 of 22** (the balloon dog 4,
   the statue 2).
4. **The face. 4 of 22**, the boy's hair and mouth.

### The next lever: an outline that narrows, and is measured

- **What changes.** The check measures a body that is said to be round, fat,
  an egg or a pear course by course. When its footprint stays the same from
  bottom to top, the check says so on submit and in review_model, as it does
  for a stepped edge: "a drum, 10 across from plate 0 to 35; an egg is narrower
  at both ends". And a body faced by hand keeps the round pattern's bands:
  each ring at its band's diameter, not one size throughout.
- **Apart from the lever:** find why the app's check held the rabbit's twelve
  54200 and BrickNet's graph does not. It is a validity risk on any build.
- **Proof in the unit** (minutes): the potato and the rabbit briefs in a short
  design each. Each body's widest course is at least 2 studs wider than its top
  and bottom courses, and each build is one piece by verify.py.
- **The bar on this bench:** this round's, unchanged.

## 2026-10-23: what holds together, by our check and by BrickNet's graph

verify.py records how many pieces a build is (`connected_components`, from
BrickNet's connection graph), though it judges validity without it. On the
outline161 arm the rabbit was 13 pieces by that graph, and the app's check had
told its session it held together. connect166 found which of the two was right
from the parts' own geometry, and ran both judgements over every build in
`brickbench-2026-10-22-m147/` (four arms and BrickAgent's six).

**The rabbit's twelve 54200s: BrickNet is right.** Each is a 1 x 1 cheese slope
whose only connector is one anti-stud in the middle of its underside (54200.dat
has its origin at its bottom face). Four stand on an 11213, a 6 x 6 round plate
whose studs are a 4 x 4 block in the middle and two at the middle of each side
(`stug-4x4`, `stug-2x1`, `stug-1x2` in 11213.dat): the slopes are at (±30, ±50)
from its middle, on its stud grid where the plate has no stud. Eight stand on a
74611, an 8 x 8 round plate whose outer rows have studs only nearer the middle
(rows ±30 and ±50 to x ±50, rows ±70 at x ±10 only): the slopes are at (±70,
±30) and (±30, ±70), again on its grid with no stud. No stud is within 20 LDU of
any of their anti-studs. In plastic each just rests on the plate's flat top:
the model stands, and the slopes fall off when it is picked up. BrickBench's two
seconds of gravity leave them standing, so verify.py passed the build.

**Why our check held them.** Our exact check's own connections
(`Exact.connections`, BrickNet's rules) found the same 13 pieces. Three things
then hid it. A piece nothing joins that stands square (`ExactCheck.rests`) was
let pass, on the promise in its comment that the lattice's loose advice says it
comes away in the hand; that advice speaks only of a part resting on a part with
no stud anywhere (`_note_loose`), and a round plate has studs. And the check's
count of pieces (`_pieces_of`) joins any part to what it sits on, so it said one
piece.

**The fix** (`ExactCheck.comes_away`, `on_missing_stud`; `_exact_unheld`,
`_pieces_of`). A piece that stands but that no stud holds comes away in the
hand. It is a fault ("not held") when its anti-stud stands on another part's
stud grid, a whole number of studs from one of its studs, where that part has no
stud: the rabbit's case, a part meant to be on studs that missed them. It is
advice when it was set down so on purpose: a brick on a tile, a plate on its
edge, a log in a groove. Either way the check counts it as a piece of its own,
and it counts pieces by the exact shapes' connections as well as the lattice's,
as verify.py does. A tube between four studs holds, as every 2 x 2 brick's tube
does (`_tube_grips`).

**Agreement, all 30 builds** (pieces by verify.py's graph, `scripts/loose.py`;
by our check on d05a59be; by our check now, `src/dev/pieces_agree.gd`):

| build | verify.py | ours, before | ours, now | what it is |
|---|---|---|---|---|
| outline161 model-078, the rabbit | 13 | 1 | 13 | twelve 54200s on round plates' rims: now 12 faults |
| search156 model-080 | 2 | 1 | 2 | four 1 x 1 tooth plates under a 1 x 4 tile, their anti-studs 12 LDU above the studs of the plate under them: advice |
| m147 model-044 | 2 | 1 | 2 | a 2 x 6 plate standing on its edge: advice |
| BrickAgent's model-044 | 2 | 1 | 2 | a 1 x 8 plate and a tile on it, resting unjoined: advice |
| figfaces model-043 | 1 | 3 | 1 | a dome's stud in the middle tube of a 2 x 2 round brick laid on its side, twice: the 2 LDU lattice missed it |
| outline161 model-044 | 1 | 3 | 1 | a side stud (87087) in a 2 x 2 round plate's middle tube, twice: the same |
| BrickAgent's model-043 | 1 | 2 | 1 | an open stud in a headlight brick's side hole (65578 in 4070): the same |
| figfaces model-042 | 2 | 1 | 1 | **disagree**: the potato's 4 x 4 dish on a 2 x 2 round plate |
| outline161 model-042 | 2 | 1 | 1 | **disagree**: the potato's 4 x 4 dish on a 2 x 2 plate |
| the other 21 | | | | agree, before and now |

28 of 30 agree, from 21 of 30. On all 30 our exact shapes' own connections
found exactly verify.py's pieces; what differed was what the check did with
them.

**The two that disagree: the potato's hat, where BrickNet is wrong.** The hat's
top is a 3960, a 4 x 4 inverted dish, on a 2 x 2 plate (outline161) or a 2 x 2
round plate (figfaces). Under its middle the dish has a tube (`stud4a`, inner
radius 6, outer 8 LDU, at its bottom face: dish-local y 12 to 16), the same
tube a 2 x 2 brick has. The plate's four studs stand round it, each 14.14 LDU
from its middle, so 0.14 LDU off the tube's outside in LDraw's nominal
geometry and pressing on it in plastic: the dish is clutched as any 2 x 2 brick
on a 2 x 2 plate is. BrickNet labels 3960's underside with that one tube and nothing else,
and a tube mates only with a stud at its own middle (`("stud", "tube")` within
3 LDU), where it takes a single stud; a 2 x 2 plate is labelled with four holes
as well as its tube, which is why it joins and the dish does not. So its graph
has the dish as a piece of its own. The designer is not changed for it: a dish
on one stud (a 1 x 1 round plate under its tube, which BrickNet reads) turns
where four studs hold it still, so it would be a worse build, and verify.py's
validity does not read the graph.

**What else it found in the app's own builders.** The round pattern laid its
6 x 6 and 8 x 8 dishes (44375b, 3961) straight on the round: each is hollow out
to its rim, and its 2 x 2 of anti-studs is a plate and two plates above the
round's studs, so it rested, held by nothing (`patterns_probe` counted its round
bodies and the Falcon Heavy two pieces). They now stand on 2 x 2 round plates
under their middles (`Rounds.DISH_RISE`), as the crowns in `shells.gd` already
did. Brickify's forty-stud bunny laid upright had a 1 x 1 brick that rests
where nothing joins it; its mend now takes out what comes away (the check's
`come_away`) as it takes out what floats, and it is one piece again. add_rooms'
furniture has pieces that rest unjoined (a turntable top, 3679, laid straight
on a plate with what stands on it); they are set down, so they are advice, as a
brick on a tile is (`clutch_probe`).

Proved by `exact_probe`: a 54200 on an 11213's rim is said not held and counted
two pieces (both fail on d05a59be: 33 passed, 2 failed; 35 passed now), the
same slope on one of its studs and the potato's dish say nothing and count one.
`src/dev/pieces_agree.gd` prints both counts for any LDraw files. The check's
cost is unchanged (`exact_cost_probe`, three runs each on d05a59be and now, on
the 9,541-part Orthanc): an edit 4.4-5.0 s and 4.2-5.6 s, of it the exact check
82-102 ms and 74-85 ms; a whole new design 31.9-39.0 s and 27.5-35.2 s.

## 2026-10-23, later: the side measured, but not said last

taper165 (`6185b456`) is outline161 with one lever: `git log 71f25bdb..6185b456
-- src/ai` is its two commits. The check measures a body the brief or the design
calls round, fat, an egg or a pear, or a creature's, course by course. When one
width runs up three quarters of a mass or more, its first advice says so: "Seen
from the side it is straight-sided", with the mass's widths by sixths of its
height against a round's. The outline guide gives a round's widths by sixths and
asks a body laid by hand to keep the bands. It does not carry connect166's check
of what holds together. It designed the same six prompts, one design each, in
the m147 round's folder. Its builds were drawn on the GPU by the same renderer
and judged against m147's, outline161's and BrickAgent's, every pair both orders
twice: 72 new verdicts, with the other three pairs' 72 read back
(`compare-taper165.md`; that round's `compare.md` is as it was).

**Valid: 6 of 6** by verify.py, geometry reproduced, `parts only` in every log,
`6185b456` in every `design.json`. Two builds come apart, which verify.py passes
and the judge held against them. The toilet is 9 pieces: its hair is corner-round
plates (79491) on corner-round bricks (85080) where those have no stud, two with
a curved slope on, and two 85080 resting on a plate. The rabbit is 3: two 1 x 1
bricks with a side stud (87087), each with a tile on its side, stand on 6 x 6
round plates (11213) where those have no stud, outline161's rabbit's fault again. Both
sessions ended saying the app's check says it holds together. rel-m151's check
(`89c069e3`, with connect166's fix) fails both, "not held", and counts 9 and 3
pieces as verify.py does (`src/dev/pieces_agree.gd`, `pieces-taper165.txt`).

| a design, the median of six | minutes | API dollars | replies | parts |
|---|---|---|---|---|
| taper165 | 9.3 (7.0-11.4) | 2.60 (15.19 for six) | 36 | 177 |
| outline161 | 9.5 (7.5-12.0) | 2.59 (16.90) | 31 | 122 |
| m147 | 12.7 (8.1-14.2) | 3.14 (19.18) | 50 | 202 |

taper165 costs what outline161 does a design, and 10% less over the six. The
unit's 19% less on its held-out briefs is not seen here. Its builds are larger:
177 parts at the median against 122.

| head to head, overall | verdicts for the first | 95% | prompts won every time / split / lost |
|---|---|---|---|
| taper165 vs m147 | 14 of 24 (58%) | 39-76% | 2 / 4 / 0 |
| taper165 vs outline161 | 10 of 24 (42%) | 24-61% | 2 / 1 / 3 |
| taper165 vs BrickAgent | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |
| outline161 vs m147 (the outline round's verdicts) | 11 of 24 (46%) | 28-65% | 1 / 3 / 2 |
| m147 vs BrickAgent (the m147 round's verdicts) | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |

| dimension | taper165 ELO (95%) | m147 ELO (95%) | outline161 ELO (95%) | BrickAgent ELO (95%) |
|---|---|---|---|---|
| likeness | 909 (717-1068) | 909 (728-1029) | 883 (713-988) | 1299 (1191-1611) |
| surface | 1037 (907-1173) | 894 (630-1008) | 986 (857-1089) | 1083 (894-1517) |
| colour | 866 (742-947) | 925 (719-1100) | 1013 (863-1124) | 1196 (1061-1438) |
| technique | 948 (779-1067) | 992 (774-1161) | 963 (882-1000) | 1097 (916-1389) |
| creativity | 875 (708-976) | 925 (741-1041) | 1005 (826-1156) | 1195 (1054-1498) |
| buildability | 1029 (889-1172) | 1008 (917-1117) | 919 (695-1098) | 1044 (897-1202) |
| **overall** | **900 (712-1042)** | **892 (661-1030)** | **909 (784-1000)** | **1299 (1186-1616)** |

Against m147, taper165 wins surface (19 of 24) and likeness (15 of 24). Overall
our three arms are within 20 ELO of each other, and about 400 behind BrickAgent.

| prompt | vs m147 | vs outline161 | vs BrickAgent | told it was straight-sided | what the judge said of taper165's |
|---|---|---|---|---|---|
| potato (042) | 1-3 | 0-4 | 0-4 | once, at its fourth submit | "a tall, narrow, square-sided brown column", "a brown box with a face"; m147's "potato-egg silhouette" beat "a body shaped like a can" |
| balloon dog (043) | 2-2 | 0-4 | 0-4 | never: its segments are 4 studs across, under the 6 the check measures from | "straight-sided stacked cylinders", "a blocky pipe robot"; no 24947, where outline161's had ten |
| toilet (044) | 4-0 | 4-0 | 0-4 | never: not called round | "a round bowl, a raised round lid" and "an expressive grinning face" beat both of ours; against BrickAgent "disjointed", a "fragmented head build", a bowl "a plain studded drum" |
| statue (049) | 1-3 | 0-4 | 0-4 | never: not called round | "a solid brown lump": the figure and its rough block in one brown, run together |
| rabbit (078) | 2-2 | 4-0 | 2-2 | six times, the last at its review | "a domed head over a wide, rounded white belly" beat outline161's "tin can with ears"; against BrickAgent it won the two where BrickAgent's was shown first, and lost two for its three pieces and "a snowman with ears" |
| boy (080) | 4-0 | 2-2 | 0-4 | never: not called round | the grin, the shark mouth and the fin beat m147's; against BrickAgent "a grey robot-like figure", its 16 spikes (22388) "a short flat crew cut" |

**The bar is missed.** Against m147, 58% where it asked 60%, one verdict short,
with no prompt lost every time. Against BrickAgent, 2 of 24 where it asked 6. The
potato and the balloon dog were lost 4 of 4 again. Six of six valid is met. 14
of 24 is not told apart from an even match (39-76%).

### What the lever reached

The measure spoke to two sessions of six, the potato's and the rabbit's. Every
final build was measured again by taper165's own check (`scripts/taper_final.gd`,
headless in its checkout; `taper-final.txt`). It reproduces the unit's own
numbers for outline161's builds:

| final build | taper165's | outline161's | m147's |
|---|---|---|---|
| potato | straight: 8 across for 22 of 27 courses (81%) | straight: 10 across for 30 of 32 (94%) | quiet |
| rabbit | straight: body 8 deep for 12 of 16 (75%), head 6 deep for 17 of 19 (89%) | straight: 6 deep for 30 of 30 (100%) | quiet |
| the other four | quiet | quiet | quiet |

**Both sessions it told saved a body it still calls straight.** The advice comes
with a submit, an edit that is refused, and review_model's read of the whole
model. An edit that applies answers with the massing alone, and the surface and
creative passes do not carry it (`scripts/taper_said.py`, `taper-said-taper165.txt`).

The potato was told at its fourth submit: 'potato body', plates 4 to 32, 8
across for 24 of 29 courses, by sixths 6, 8, 8, 8, 8, 8 against a round's 4, 7,
8, 8, 7, 4. It searched for 5152 and 2577 by number and laid the body again.
Its next submit, of 66 parts, and its review at 86 said nothing of it. The 22
parts after that, the face, the ear and the hat on a hinge, went in by edits.
The body it saved is 8 across in all but its lowest courses: courses with a
corner round (3063b) at each corner alternate with courses of plain bricks 6
and 8 long, square-cornered. The check calls it straight again (81%, by
sixths 6, 8, 8, 8, 8, 8). Which of those edits brought it back over the line is
not settled here. The judge read "a tall, narrow, square-sided brown column" in
4 of 4 against BrickAgent, and m147's egg beat it 3-1.

The rabbit was told six times, from its first submit to its review at 68 parts.
It went from 10 across for 80% of its body to a body 8 deep and a head 6 deep.
The 34 parts after the review, its face and what the surface pass laid, went in
by edits and passes. Its body is two rings of 4 x 4 corner rounds (2577) under a
domed top (49612), white in front, with a round brick hanging under for the
belly: by sixths 5, 8, 8, 10, 8, 8. The check calls it straight (75%); the judge
reads it round, "a domed head over a wide, rounded white belly", and it beat
outline161's can 4-0. On the rabbit the measure and the judge disagree, and the
judge is the one that scores.

**The balloon dog lost the outline parts outline161 found**, and not by the
lever: it was never measured. Both sessions read `outline` first, which names
24947 on 3262 for a balloon's segment. outline161's then searched for 24947 and
3262 before any check and laid ten of each. taper165's made three `check_design`
calls first. The second was answered with the advice for a small round body
(outline161's too), which names round bricks, domes, corner rounds and the round
pattern's bands, and no 24947. It read `round` next and laid every segment as
round bricks four studs across (31 of 87081, 11 of 3941), pinched to 2 x 2. That
is one session's choice, which one design a prompt cannot tell from the arm's.

### What the judge holds against it now

The 22 verdicts lost to BrickAgent, by what their reasons hold against it:

1. **A straight side: a column, a pillar, stacked cylinders, a drum. 10 of 22**
   (the potato 4, the balloon dog 4, the toilet's bowl 2). It was 12 of 22 for
   outline161 (the potato, the rabbit and the toilet's head) and 21 of 22 for
   m147, said then of boxes, slabs and drums. So: fewer cans and drums, and
   other ones. The rabbit has left the list. The potato is on it still, now a
   column. The balloon dog has joined it.
2. **Loose parts. 6 of 22** (the toilet 4, the rabbit 2): outline161's count, in
   other builds. rel-m151's check would have told both sessions.
3. **A figure that does not read. 4 of 22**, the statue: one brown lump.
4. **The face and the colour. 4 of 22**, the boy: grey, a square head, a mouth
   plate that "looks like a robot's grille".

### The next lever: say it last, and on rel-m151

- **What changes.** The straight-sided advice is said where the design decides
  it is done: on an edit that changes a mass it measured, and in the final look,
  not only on a submit. The small-round advice names 24947 on 3262 for a segment
  that pinches, beside the round pattern's bands, as the outline guide does. The
  arm is built on rel-m151, whose check tells a session of the parts that come
  away (it fails both of this round's loose builds).
- **Proof in the unit** (minutes): the potato and the balloon dog briefs in a
  short design each. The potato's saved build is quiet by
  `scripts/taper_final.gd`; the balloon dog's has 24947 on 3262; both are one
  piece by verify.py.
- **The bar on this bench:** this round's, unchanged.

## 2026-10-23, before dawn: the sculpt, kept in two builds of six

sculpt170 (`55eee104`) is rel-m151 (`89c069e3`, with connect166's check of what
holds together) and one lever: a `sculpt` pattern. A design says a rounded body
as one to four solids (an ellipsoid, an egg, a capsule, a superellipsoid) and
Brickify lays them as one connected piece. The outline guide asks for it for any
rounded mass bigger than a ball 8 studs across, and moulded parts below that. It
does not carry taper165's lever. It designed the same six prompts, one design
each, in the m147 round's folder. Its builds were drawn on the GPU by the same
renderer and judged against m147's, outline161's and BrickAgent's, every pair
both orders twice: 72 new verdicts, with the other three pairs' 72 read back
(`compare-sculpt170.md`; that round's `compare.md` is as it was).

**Valid: 6 of 6** by verify.py, geometry reproduced, `parts only` in every log,
`55eee104` in every `design.json`. Every build is one piece, by verify.py's graph
and by our check (`src/dev/pieces_agree.gd` on main, `c07144d2`;
`pieces-sculpt170.txt`): the first of our arms on these six with no build that
comes apart.

| build | parts | pieces, verify.py | pieces, ours | the sculpt in it |
|---|---|---|---|---|
| potato (042) | 203 | 1 | 1 | its body, an egg 10 across and 28 plates tall: 184 parts laid by Brickify |
| balloon dog (043) | 111 | 1 | 1 | none: ten capsules at its first submit, then laid again by hand |
| toilet (044) | 203 | 1 | 1 | none: its head an egg 7 across, then laid again by hand |
| statue (049) | 128 | 1 | 1 | none: the whole seated man in 13 solids, then laid again by hand |
| rabbit (078) | 320 | 1 | 1 | its body, belly and head, three solids: 278 parts laid by Brickify |
| boy (080) | 186 | 1 | 1 | none: never laid |

| a design, the median of six | minutes | API dollars | replies | parts |
|---|---|---|---|---|
| sculpt170 | 7.2 (5.2-12.8) | 2.33 (15.06 for six) | 35 | 195 |
| outline161 | 9.5 (7.5-12.0) | 2.59 (16.90) | 31 | 122 |
| m147 | 12.7 (8.1-14.2) | 3.14 (19.18) | 50 | 202 |

sculpt170 costs 10% less a design than outline161 (11% over the six) and 26% less
than m147 (21% over the six), and is the quickest arm yet. The unit's 40% less on
its held-out briefs is not seen here. Its builds are as large as m147's. They are
69% stacked and 26% shaped, where m147's, outline161's and BrickAgent's are
50-54% stacked and 36-47% shaped: what Brickify lays is mostly plates and
bricks.

| head to head, overall | verdicts for the first | 95% | prompts won every time / split / lost |
|---|---|---|---|
| sculpt170 vs m147 | 13 of 24 (54%) | 35-72% | 3 / 1 / 2 |
| sculpt170 vs outline161 | 17 of 24 (71%) | 51-85% | 4 / 1 / 1 |
| sculpt170 vs BrickAgent | 4 of 24 (17%) | 7-36% | 1 / 0 / 5 |
| taper165 vs m147 (the taper round's verdicts) | 14 of 24 (58%) | 39-76% | 2 / 4 / 0 |
| m147 vs BrickAgent (the m147 round's verdicts) | 2 of 24 (8%) | 2-26% | 0 / 1 / 5 |

| dimension | sculpt170 ELO (95%) | m147 ELO (95%) | outline161 ELO (95%) | BrickAgent ELO (95%) |
|---|---|---|---|---|
| likeness | 966 (772-1212) | 932 (683-1084) | 836 (639-932) | 1266 (1176-1464) |
| surface | 916 (719-1046) | 954 (646-1161) | 999 (839-1107) | 1132 (978-1516) |
| colour | 936 (737-1118) | 928 (728-1092) | 967 (812-1093) | 1170 (1043-1369) |
| technique | 907 (709-1063) | 1006 (757-1219) | 946 (805-1028) | 1141 (1022-1362) |
| creativity | 1046 (888-1276) | 875 (709-984) | 962 (733-1135) | 1117 (978-1335) |
| buildability | 1051 (904-1183) | 971 (829-1089) | 949 (766-1142) | 1029 (878-1197) |
| **overall** | **974 (783-1212)** | **907 (655-1082)** | **855 (690-956)** | **1265 (1168-1457)** |

Overall sculpt170 is the best of our arms by 67 ELO, well inside the intervals,
and about 290 behind BrickAgent, from about 360 for m147 here. Against m147 it has
likeness 13 of 24, technique 10 and surface 11.

| prompt | vs m147 | vs outline161 | vs BrickAgent | what the judge said of sculpt170's |
|---|---|---|---|---|
| potato (042) | 1-3 | 4-0 | 0-4 | "actually looks like a potato" beside outline161's can; m147's "smooth oval" beat it 3-1; against BrickAgent "a blocky octagonal brown lump with no arms", "stepped, angular", in 4 of 4 |
| balloon dog (043) | 4-0 | 4-0 | 0-4 | "pinched rounded segments" beat m147's "blocky dog" and outline161's "plate yokes"; BrickAgent's beat "a gangly H", its legs and neck stretched tall, the tail straight up, a thin slab for a plinth |
| toilet (044) | 4-0 | 4-0 | 4-0 | the long neck the brief asks for, one piece, a raised lid and a plunger; BrickAgent's has "a short stubby neck" and a loose part |
| statue (049) | 0-4 | 0-4 | 0-4 | "an upright block of bricks", "a slab-like brown block with a cylinder for a head", not a seated man |
| rabbit (078) | 0-4 | 1-3 | 0-4 | arms that "stick straight out like a T-shaped frame", a face of black slopes with no teeth; "messier blocky build" than m147's |
| boy (080) | 4-0 | 4-0 | 0-4 | the grin, the shark-jaw chest and the colour beat both of ours; BrickAgent's hair spikes, its torso turns, its fin is large, where ours has "a flat cap topped with cones" |

**The bar is missed.** Against m147, 54% where it asked 60%, two verdicts short,
with the statue and the rabbit lost every time. Against BrickAgent, 4 of 24
where it asked 6, as many as search156 had and the most any arm has. The potato
and the balloon dog were lost 4 of 4 again. Six of six valid is met. 13 of 24 is
not told apart from an even match (35-72%). Against outline161, 17 of 24 (51-85%)
is the one clear win.

### What the sessions did with the sculpt

Five sessions of six laid a sculpt in a `check_design` or `submit_design`; the
boy's never did (`scripts/sculpt_calls.py` on the transcripts in Claude Code's
project folder for the sculpt170-bench worktree; `sculpt-calls-sculpt170.txt`).
**Two kept it.** Three looked at what Brickify laid and laid that mass again by
hand:

- **The balloon dog** sculpted ten capsules 3 studs across, under the guide's
  6-stud floor for a sculpt, 239 parts. Then it said "I'll rebuild the dog by
  hand from round parts so each segment really pinches", and laid ten 24947 on ten
  3262 with round bricks between, "in place of the blocky sculpt": outline161's
  parts, at 111 parts. The judge named the segments in all eight wins over m147
  and outline161.
- **The toilet** sculpted its head as an egg 7 across (109 parts), then took it
  off "to replace the blocky sculpted head", and laid a square head by hand. Its
  wins are the neck, the plunger and being one piece where BrickAgent's is two.
- **The statue** sculpted the whole seated man, block and all, in 13 solids
  (291 parts), then laid it again as a fill and bricks, 96 parts, because "the
  generated figure couldn't put the right elbow across onto the opposite knee".

The two that kept it both lost to m147 for a blockier body. The potato's egg is
round from the side, and no verdict calls it a can, a column or a drum: it beat
outline161's can 4-0. But at 10 studs across its skin is 1 x 1 plates,
cut-corner plates (26601) and cheese slopes (54200), and the judge reads it as
faceted ("octagonal", "stepped"), where m147's, of 1 x 1 plates, reads as "a
smooth oval". The rabbit lost to m147's "smooth round body" 4-0; against
BrickAgent its reasons are not its body but its arms, on a frame out to the
sides, and its face. Of the three prompts won every time over m147, the balloon
dog's segments are outline161's lever, the toilet's win is a neck and one
piece, and the boy laid no sculpt.

### What the judge holds against it now

The 20 verdicts lost to BrickAgent, by what their reasons hold against it:

1. **A pose or proportions the brief does not give. 16 of 20.** The statue
   reads as no seated man (4), the rabbit's arms jut out in a T (4), the boy's
   torso does not turn and his hair is a flat block (4), the balloon dog is
   stretched tall with its tail straight up (4). Taper165's round put 4 of 22
   here, the statue's lump.
2. **The face. 8 of 20**, all within the 16: the rabbit's black-slope eyes and
   no teeth, the boy's square head and flat hair.
3. **A sculpted skin read as stepped and faceted. 4 of 20**, the potato, each
   with "no arms".
4. **A straight side: none** (10 of 22 for taper165). **Loose parts: none** (6
   of 22).

So the outline is no longer what loses. The sculpt rounded the potato from the
side, the balloon dog went back to outline161's segments, and connect166's check
kept every build in one piece. What is left is how a figure stands.

### The next lever: the pose the brief gives

- **What changes.** The posture words of a brief (arms hanging, a fist forward,
  seated and hunched with an elbow on a knee, a torso turned against the hips, a
  tail angled back) are read into the figure as where each limb goes, and the
  check says when the build has them elsewhere: "the arms stand out level; the
  brief has them hanging at its sides". It is bench155's "after it", now first.
- **Apart from the lever:** a small sculpt (the potato's, 10 across) is skinned
  in curved slopes and tiles over its steps, so it reads as smooth as m147's.
- **Proof in the unit** (minutes): the statue, the rabbit and the boy briefs in a
  short design each. The statue reads as a seated man with an elbow on a knee,
  the rabbit's arms hang, the boy's torso is turned; each build is one piece by
  verify.py.
- **The bar on this bench:** this round's, unchanged.

## Repeat it

The recipe, with the setup of BrickAgent, its colliders and a venv, is
"BrickBench" in `.claude/skills/verify/features/assistant.md`. In short:

```sh
python3 tools/bench/brickbench.py prompts --upstream $S/upstream
python3 tools/bench/brickbench.py parts --upstream $S/upstream
XDG_DATA_HOME=$S/xdg heavy env -u ANTHROPIC_API_KEY python3 tools/bench/brickbench.py design --jobs 2
python3 tools/bench/brickbench.py export --python $S/venv/bin/python
BRICKNET_DATA=$S/bricknet_data heavy python3 tools/bench/brickbench.py verify --upstream $S/upstream --python $S/venv/bin/python
python3 tools/bench/brickbench.py zip --upstream $S/upstream
python3 tools/bench/brickbench.py fetch
XDG_DATA_HOME=$S/xdg heavy python3 tools/bench/brickbench.py views --software --jobs 2
env -u ANTHROPIC_API_KEY python3 tools/bench/brickbench.py pairs --repeat 2 --jobs 3
python3 tools/bench/brickbench.py report
```

The designs ran on the app code of `21ff198` (the runs recorded it as
`480b81a-dirty`: the same code before it was committed). Everything a run makes
is in the main checkout's `bench/results/brickbench-2026-10-14/`, git-ignored.
BrickAgent's builds are theirs: they were downloaded for this comparison only,
and are never committed or republished.

The figures-on-joints round (2026-10-15) is the same with `prompts --start 51`,
the four characters' rows copied from the attach round's `prompts.json`, `--arm
merge29` and `--arm joints` (each `--app` an archive of its commit), and
`compare --arms merge29,joints`.

The armature round (2026-10-16) wrote its `prompts.json` by hand: the four
characters' rows copied from the joints round's, and model-078 and model-080 by
`first_tasks(tasks_json, 1, start)`; then `--arm m32` (`--app` a detached
worktree at main) and `--arm armature` (`--app` the branch's worktree), `--runs 1`,
views on the GPU, `pairs --repeat 2`, `compare --arms m32,armature --runs 1`.

The faces round (2026-10-16) ran in the armature round's folder: `design --date
2026-10-16-armature --arm figfaces --runs 1 --app` the branch's worktree (in one
`gpu` lease with the real-set run), `export` and `verify` for that arm, then
`views`, `pairs --repeat 2` and `compare` with `--arms armature,figfaces`; the
round's `compare.md` was copied aside first and put back. The transcripts were
read with `bench/results/armature-2026-10-16/scripts/uptake.py`.

The m147 round (2026-10-22) copied `prompts.json`, `bricknet_parts.txt` and
`theirs/` from the armature round's folder, and its figfaces designs in as
`arms/figfaces`. Then `design --date 2026-10-22-m147 --arm m147 --runs 1
--jobs 2 --app` a locked `release_wt.sh` worktree of `9379fbb1` (with
`godot --headless --import` run there once), `export` and `verify --which
ours` for that arm, `views --arms figfaces` and `--arms m147` on the GPU,
`pairs --arms m147,figfaces --runs 1 --repeat 2 --jobs 3`, and `compare`. The
cold reads are `scripts/blindread.py` (on the subscription, Read only). The
searches are `scripts/search_check.gd`, run headless in the app's checkout
with `--parts-only=` the round's list.

The search round (2026-10-22, later) ran in the m147 round's folder from
search156's locked worktree (`9590a07d`, imported): `design --date
2026-10-22-m147 --arm search156 --runs 1 --jobs 2 --app` that worktree, `export`
and `verify --which ours` for that arm (`BRICKNET_DATA` the main checkout's
`bench/data/bricknet_data`), `views --arms search156` on the GPU, `pairs --arms
search156,m147 --runs 1 --repeat 2 --jobs 3` (which judges BrickAgent's too, and
reads the m147 round's verdicts back), and `compare --arms search156,m147 --runs
1`, its `compare.md` kept as `compare-search156.md` and the m147 round's put
back. The searches each session made are `scripts/searches.py`, a session's
words `scripts/said.py`, and the same queries through both apps
`scripts/search_check_bench160.gd`.

The outline round (2026-10-22, night) is the search round's commands with
`--arm outline161` and `--app` a locked `release_wt.sh outline161-bench
71f25bdb` worktree (imported), then `compare --arms outline161,m147 --runs 1
--out .../compare-outline161.md`, the m147 round's `compare.md` copied aside
first and put back. Three things it ran into. `BRICKNET_DATA` must be an
absolute path: verify.py runs in each submission's folder, so a relative one
writes a NOT valid `verification.json` for want of colliders, and a run with
`--arm` then skips that design until the file is deleted. Views drawn from a
checkout whose `.godot` class cache is stale fail with "no world": the main
checkout's lacked BestOfTwo and ModelLibrary. They were drawn from an imported
worktree of `41e09513`, whose tool and renderer are main's; results land in the
main checkout's folder whichever worktree runs the tool. Export, verify,
views and pairs were run two prompts at a time as the designs finished, then
`pairs` once over all six, which asked nothing new. The scripts are `cost.py`,
`outline_parts.py`, `loose.py` (in the venv, `-I`, a submission folder) and
`calls.py` (a session's calls in order), with the sheets in
`sheets-outline161/`.

The taper round (2026-10-23, later) is the outline round's commands with `--arm
taper165` and `--app` a locked `release_wt.sh taper165-bench 6185b456` worktree
(imported; retired after), views drawn from an imported worktree of rel-m151
(`89c069e3`), `pairs --arms taper165,m147,outline161`, and `compare --arms
taper165,m147,outline161 --runs 1 --out .../compare-taper165.md`. `compare`
writes `compare.md` as well as `--out`, so the m147 round's was copied aside
first and put back. The advice each session got is `scripts/taper_said.py` on
its transcripts (Claude Code's project folder for the taper165-bench worktree),
and each final build measured by taper165's own check `scripts/taper_final.gd`,
run headless in its checkout with the round's folder and the arms. Its outputs
are `taper-said-taper165.txt`, `taper-final.txt` and `pieces-taper165.txt` (rel-m151's
`src/dev/pieces_agree.gd` on the two loose builds), with the sheets in
`sheets-taper165/`.

The sculpt round (2026-10-23, before dawn) is the taper round's commands with
`--arm sculpt170` and `--app` a locked `release_wt.sh sculpt170-bench 55eee104`
worktree (imported; retired after), views drawn from an imported worktree of main
(`c07144d2`), `pairs --arms sculpt170,m147,outline161`, and `compare --arms
sculpt170,m147,outline161 --runs 1 --out .../compare-sculpt170.md`, the m147
round's `compare.md` copied aside first and put back. The verdicts a prompt are
`scripts/by_prompt.py BATCH sculpt170-run1 m147-run1 outline161-run1 opus55`,
each session's submits and the sculpts in them `scripts/sculpt_calls.py`, a
session's words and calls `scripts/said_calls.py`, and the pieces main's
`src/dev/pieces_agree.gd` on the six `design.ldr` (`pieces-sculpt170.txt`), with
the sheets in `sheets-sculpt170/`.

The comparison of arms is the same tool with `--start`, `--arm`, `--runs`,
`--app`, `--arms` and `compare`. The recipe is under "BrickBench" in the
same verify file. Its results are in `bench/results/brickbench-2026-10-14-held/`
and `brickbench-2026-10-14-chars/`, with `compare.md` in each.

The arms ran from `git archive` exports of `fe032a8` (full, with the
moved-number fix copied in: `parts_only.gd`, `figure_tool.gd` and the two
calls in `assistant.gd`),
`63ab5ca` and `c0d7257` (lean). Each design's `design.json` records the
export as its `"app"`. The car and the fire truck are in
`bench/results/2026-10-14-figures/`.

[bb-repo]: https://github.com/kulits/BrickAgent
[bb-gallery]: https://gallery.brickben.ch/
