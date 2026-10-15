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
