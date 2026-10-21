# Design scores: the bench

What the owner asks for above all is a highly elegant, expert LEGO design.
Design rounds used to rerun one or two subjects once and read
`tools/style.py`; a run varies a lot and "elegant" was judged by eye, so
nobody could say which change made designs better. This file is the
measuring stick: every batch of `tools/bench/run.py` appends its table
here, with the commit it ran on.

**The suite** (`tools/bench/suite.py`), fixed, ten held-out subjects: a
barn owl, a Porsche 911 Turbo at Speed Champions scale, a Falcon Heavy at
display scale, a small modular corner shop, a castle gatehouse, a
Star-Wars-like starfighter, a bust of an Apollo astronaut, a bonsai, a
mobile crane with Technic functions and a mountain-lake vignette. Each has
a one-line brief, a scale, and references: photographs on Wikimedia
Commons (URL, author and licence kept; fetched at run time, never
committed) or a real set from LDraw's model repository rendered by the
same renderer.

**A run** of a subject: the real design loop on the subscription
(`--ask-claude-code`, no API key, under `heavy`, one at a time, 45 minutes
at most), the design rendered corner, front and close on the GPU, the
build check (`candidate_probe`: opens whole, one piece, stands, faults),
`tools/style.py` against the subject's real sets, and the judge.

**The judge** is Claude through Claude Code on the subscription, with only
the Read tool, shown the same two anchor pictures in every call — LEGO's
own 10242 MINI Cooper, which is what 9 looks like, and the same car as a
naive stack of plain bricks, which is what 2 looks like — then the
references, the three views and the build check's words, and a fixed
rubric (`tools/bench/judge.py`, versioned). It scores 1-10, with a line of
reason each:

- **likeness**: silhouette and proportion read as the subject
- **surface**: smooth where the subject is smooth, studs only where meant, SNOT and curves used well
- **colour**: the subject's colours, tonal variation and detail, no flat expanses
- **technique**: what a real LEGO designer would use for it, used well
- **creative**: a creative touch, an easter egg, a story or display feature
- **build**: from the build check (10 one piece, stands, no fault; 1 nothing built)

A subject's score is the mean of its runs; the suite's, the mean of its
subjects. A design that left no model scores 1 everywhere: the person got
nothing. Everything a run made — the `.ldr`, the log, the views, the
probe, the measures, the prompt and the judge's raw reply — is under the
main checkout's `bench/results/<date>/<subject>/<run>/`, gitignored, from a
worktree too: `run.py` finds it by git's common directory, because a
worktree's untracked files go when it is removed, and the raw results of the
re-score, creative, d5 and d5b rounds went that way on 2026-10-13.

Two things to read before trusting a difference: the run-to-run spread
below each table (the same code, the same subject, designed again), and
the rubric version in each heading — scores under two versions do not
compare. Since 2026-10-14 every round is also judged in pairs, with
intervals that carry the run-to-run spread: "Judged in pairs", next.

**Design memory, and what a batch holds out.** Every scored design is kept,
with its critique, in `assets/knowledge/designs.json.gz`: subject, brief,
the six scores, the judge's reasons, how it was built (`tools/style.py`'s
shares, its most-used shaped parts, and from its log the features worked and
real-set pieces laid) and a small picture. After a batch, run
`python3 tools/design_memory.py build` (it reads the main checkout's
`bench/results/`) and commit the index: it merges into what the index holds,
and it is now the only copy of the creative, d5 and d5b rounds' critiques and
pictures, read before their worktrees went. It holds 65 designs: the
baseline's 13, the creative round's 4, d5's 2, d5b's 3, d6's 4, d6b's 2, the
surface round's 4, the edges rounds' 5, the steps round's 4, the sides
round's 6 (its locomotive and ship the first of their subjects), the shapes
round's 6 (two of them trial cars) and the cabins round's 12 (two of each
subject, its fire truck and aircraft the first of theirs). What is missing is
the re-score's own replies: the baseline keeps its first judgement's scores
and words, with the re-scored build taken from the table below, and the
design5 batches' build, judged on the old check and never re-scored, is not
told as a fault. A designer asking `how_real_sets_build_this` with its
subject, which a session does before building, and the app's own loop in its
first message, is handed the best design of the nearest subject (a race car
finds the Porsche, a parrot the owl, a corner store the shop), how it was
built, the judge's three lowest reasons to design out, and its picture
(`src/ai/design_memory.gd`).

The ten subjects here are the test set, so memory must never hand a design
the answer for the subject being scored. `run.py` starts every design with
`--held-out=<subject id>`, and the memory leaves that subject's designs out
for the whole run (when the session first asks, the app says "design memory:
holding out ..." in the design's log; `design_memory_probe -- --held-out=ID`
checks it). What a batch measures from this round on is what the designer
learnt from the other nine subjects, as a person's new subject would, never
its own past attempts. Rebuild the index between batches, and say in a
batch's heading whether memory was on: every batch on a commit before it came
in ran without it.

What the first batch with memory should measure, against the last without:
whether each session asked (`how real sets build this` in its log) and was
held out; whether the faults the judge named for the other subjects stop
recurring (studs-up bodies, stud fields, staircases where a curve should be:
technique and surface, the two weakest); and that likeness does not fall,
which would say a session copied the nearest design's picture rather than
designing past it. A subject moves only beyond the 0.5 run-to-run spread.

## Against real sets (2026-10-16)

From 2026-10-16 the bar is real LEGO® sets, judged blind, on subjects no round
was tuned on. Every round before was steered by the subjects it was scored on,
and our own judge once preferred an outside designer 40 of 40 after calling our
rounds gains. BrickBench stays one outside check against other designers. We do
not tune for it.

`tools/bench/realset.py` is the test.

- **Subjects.** The main model of a set in LDraw's model repository, 80 to
  1,500 parts, from 2000 on, one model to its box. A set is out when its name,
  its theme or a quarter of its sub-models' names name a kind any round touched:
  every suite subject, all sixty BrickBench prompts we ran, and the runs and
  probes in ROADMAP.md (cars, trucks, trains, ships, aircraft, spaceships,
  rockets, castles and towers, shops, houses, plants, birds, dogs, cats, bears,
  robots, wizards, statues and more; `TOUCHED` in the tool says where each came
  from). The suite's reference sets are out by number too. That leaves 142 of
  1,235 sets. The instructions sample (tools/steps_score.py) is not left out:
  it scores build order, not design.
- **Halves.** Fixed by a hash of the set number. Each half has an animal, a
  person and a creature, then seven more across four sizes, the least used
  theme first. Ten a half. Tune was looked at while the tool was built; proof
  was run once, at the end. Since 2026-10-19, 44 a half, the ten first
  ("Enough subjects", below).
- **The brief** is the set's name, its theme, the footprint it fits in and a
  quarter either side of its piece count: "Andrea’s Stage, in the style of
  LEGO® Friends sets: fitting in about 18 x 18 studs, 70 to 110 pieces." The
  designer never sees the set. Its own pieces are held out of the real-set
  index for the run, and the log says so: "real sets: holding out 3932-1 (7
  pieces)".
- **The judge** sees the design and the set drawn by the same renderer, three
  views each, under hashed names, in both orders. It is not told either is a
  set. It picks one per dimension, with a reason. A subject counts the share
  of its verdicts we won; a win rate has a 95% Wilson interval over subjects.

**Calibration first.** On the tune half the judge named each set over a naive
stack of itself (`calibrate.naive_stack`) in 120 of 120 verdicts, 95%
97-100%, every dimension, both orders. Every verdict opened all six pictures.

**The baseline: m32 on the proof half** (main at `2789cd0`, with only the
set's own pieces held out; one design a subject, 2026-10-16). Ten subjects:
Valentine's Bee, Jack Skellington & Sally and Steve & Creeper (BrickHeadz),
Emma's Fashion Design Studio, Container Stacker, Container Yard, Imperial
Hotel, Dino Explorer, Naida's Spa Secret and Rise of the Sphinx.

| dimension | our design preferred to the set | 95% |
|---|---|---|
| likeness | 30% | 11-60% |
| surface | 20% | 6-51% |
| colour | 15% | 4-46% |
| technique | 5% | 1-34% |
| creativity | 25% | 8-56% |
| overall | 20% | 6-51% |

- **Overall, the set won seven subjects outright**, both orders. Ours won one
  outright, the Container Stacker, whose set reads as a telehandler with a
  hook. The judge split two: the bee, and Steve & Creeper.
- **Technique is the gap.** One verdict in twenty went our way. The set's
  reasons are clips on bars, hinged sub-assemblies and faces built sideways;
  ours are stacked bricks and plates. Jack and Sally were pixel mosaics.
- **A theme's style counts against us.** Container Yard lost as a stud-heavy
  diorama where the brief said Technic, Naida's Spa as a generic scene where
  it said Elves.
- The two orders named the same model on 82% of dimensions. The model shown
  first won 42% of verdicts.
- **Blind by name, not by look.** In 7 of 24 verdicts the reason calls one
  side a real set of its line ("looks like a real BrickHeadz"). Printed
  tiles, mini-dolls and a line's build formula give a set away. The judge was
  never told, and it still chose ours where ours read better as the brief.

What they are made of, the median over the ten (tools/style.py, figures left
out; floating by the build check's reading, src/dev/connection_audit.gd):

| measure | ours | the sets | ours minus the set's, median |
|---|---|---|---|
| parts | 230 | 201 | +13 |
| shapes per 100 parts | 15 | 28 | -8 |
| shaped (curve, slope, angled) | 21% | 24% | -12 points |
| 1 x 1 parts | 24% | 13% | +10 points |
| colours | 11.5 | 13.5 | -3 |
| tiles | 15% | 11% | +5 points |
| studs not up (SNOT) | 4% | 25% | -19 points |
| hinges, clips, bars, turntables | 0% | 3% | -3 points |
| floating | 0% | 0% | 0 |

The same size, half the variety of shapes, a sixth of the SNOT and almost no
joints. Hidden colours were not read: that audit needs pictures of every part.

**The tune half** ran two subjects end to end while the tool was built. The
set won Andrea's Stage on every verdict. Our Year of the Sheep won overall
both ways round, for its New Year dressing, and lost surface and technique to
the set's posed sculpt.

**A design took** 5 to 24 minutes, 9 at the median. Two workers did the proof
half in 80 minutes, after 23 and 30 minutes in the `heavy` queue at load 40-50.

**Another arm** runs on the same subjects and is judged two ways: each arm
against the sets, and the two head to head, both orders.

```sh
env -u ANTHROPIC_API_KEY XDG_DATA_HOME=$PWD/.scratch-data python3 tools/bench/realset.py run --which proof --arm mine --checkout ../mine --jobs 2
env -u ANTHROPIC_API_KEY python3 tools/bench/realset.py compare --which proof --arms m32,mine --jobs 2
```

The arm's checkout must hold a set out too (src/ai/real_snippets.gd, from this
round on), or it can lay the answer. The report names any design whose log
lacks the hold-out line. Results are in `bench/results/realset-2026-10-16-m32/`
(report-proof.md, report-tune.md) and `realset-sets/calibration-tune.md`.

### Enough subjects: the halves grown to 44 (2026-10-19)

Ten subjects a half could not tell a lever from noise. The day's two
technique rounds moved technique against the sets from none to 10% and 20%
on the proof half, and every paired interval reached zero. This sizes the
halves from the verdicts already on disk.

**The noise, measured** on 18 arms of ten subjects (nine a half; 191 designs
in all, each judged both orders), the 72 pairs of arms that share their
subjects, and 15 head-to-head comparisons (`bench/results/realset-2026-10-1*`).
- A subject's paired gap, one arm's share of its two verdicts against the set
  less the other arm's, has an SD of 0.36 on overall over the 72 pairs. On
  technique it is 0.25, but most arms win technique on no subject, so most
  gaps are 0; over the 36 pairs with an arm that moved it (armature, t2plan3,
  t3lay) it is 0.31.
- A 95% interval is about 1.96 SD / √n either way. For 10 points, n =
  (1.96 × SD / 0.10)²: 49 on overall, 36 on technique where a lever moves it.
- Drawn as realset.py draws it, subjects resampled, from the pooled gaps: 18
  points either way on overall and 10 on technique at 10 subjects, 12 and 8
  at 30, 10 and 7 at 44.
- The judge's own noise is 43% of a gap's variance on overall and 67% on
  technique: a verdict's variance between the two orders of one design,
  (v1 − v2)² / 2, is 0.055 on overall and 0.042 on technique, halved for a
  share of two verdicts and doubled for two arms. The rest is which design
  was drawn and how a lever suits a subject.

**Subjects, not designs a subject.** k designs of each subject cut the
judge's and the design's part of the noise k times, but not how a lever suits
one subject more than another. At the same number of designs they do no
better than k times the subjects, and worse where levers suit subjects
differently, as the technique levers did (a river's palms, a clothes rack).
More subjects also widen what a result is about. Asking the judge each order
twice would not help: t2base's 20 pairs asked again in the same order named
the same model on 115 of 120 dimensions (96%; colour and technique on all
20). Its noise is which model it is shown first when the two are close, not
chance, so a third or fourth ask of the same pictures says the same.

**The halves.** The same rule run further: an animal, a person and a creature
first, then across four sizes, the least used theme first, in hash order. It
stops at 44 a half, where the 82 sets that are no character run out. Past
that are only BrickHeadz (53 of the 54 left), one line's formula. 44 gives
about 10.5 points either way on overall and 9 on technique, paired; one arm
against the sets about 11 on overall. Head to head (SD 0.41) would need 65
for 10 points, and gets 12.
- **Each half's first ten are its ten before** (tests/test_realset.py pins
  them), so every result before reads on: `compare` pairs the subjects both
  arms have, and `--first 10` runs or reports the old ten alone.
- Sizes, smallest first: tune 14, 12, 14 and 4; proof 14, 11, 15 and 4.
  Architecture is 13 of tune and 15 of proof, Technic 8 and 9: 28 and 17 of
  the 82 sets in the pool. A report's subject table gives each theme's
  share.
- **Tune has been looked at:** its first ten built the tool and steered four
  technique rounds. Its 34 new subjects may be tuned on too. **Proof's 34 new
  subjects never are:** never `sample --show`n, their designs and transcripts
  never read to steer a lever. A lever runs on proof once, when it is settled.

**Main on the 44 of proof** (`64fdf18`, main's `f6db180` with this test's
change; one design a subject on the subscription, drawn on the GPU, two at a
time). The 34 new subjects are this run's designs. The first ten are
t2base's (main at `7299b56`), copied in: src/ai, the design code, is the same.

| dimension | main preferred to the set, all 44 (95%) | the first ten, as before | the 34 new |
|---|---|---|---|
| likeness | 22% (12-36) | 25% (8-56) | 21% (10-37) |
| surface | 26% (15-41) | 25% (8-56) | 26% (15-43) |
| colour | 26% (15-41) | 20% (6-51) | 28% (16-45) |
| technique | 12% (6-25) | 0% (0-28) | 16% (7-32) |
| creativity | 35% (23-50) | 25% (8-56) | 38% (24-55) |
| overall | 20% (11-35) | 20% (6-51) | 21% (10-37) |

- **The set is preferred four times in five overall,** 18 verdicts of 88
  ours, as the first ten said, now within 12 points either way where ten
  gave 22.
- **Technique is not zero:** 11 verdicts of 88, where the first ten gave
  main none. By theme over the 44: Architecture (15 subjects) gave main 3
  subjects' worth of overall and 2.5 of technique; the two Promotional sets
  went to main on both, both orders; Technic (9 subjects) gave main no
  verdict on either. A lever judged against these designs should get a
  paired interval of about 10 points either way on overall and 9 on
  technique.
- The two orders named the same model on 88% of dimensions; the model shown
  first won 45%. All 88 verdicts opened all six pictures. Six design logs have
  no hold-out line: those sessions never searched the real-set index.

What they are made of (medians over the 44, tools/style.py; floating by the
build check, every design and set audited):

| measure | main | the sets | main less the set's, median |
|---|---|---|---|
| parts | 288 | 344 | -5 |
| shapes per 100 parts | 14 | 17 | -2 |
| shaped (curve, slope, angled) | 27% | 25% | -4 points |
| 1 x 1 parts | 27% | 17% | +8 points |
| colours | 10 | 13 | -2 |
| tiles | 16% | 11% | +7 points |
| studs not up (SNOT) | 4% | 27% | -19 points |
| hinges, clips, bars, turntables | 0% | 4% | -3 points |
| floating | 0% | 0% | 0 |

The gaps the first ten showed hold on the 44: a sixth of the sets' SNOT, no
joints, more 1 x 1s and tiles. Shapes per 100 parts is nearer (14 against 17,
where the first ten's sets had 28): the grown half's sets are bigger (344
parts at the median against 201) and repeat their shapes more.

**What a round costs now.** The 34 new designs' sessions took 11 minutes at
the median and 14 on average, up to 36; the subjects are bigger than the
first ten. Two at a time, with the GPU shared, the 34 took five hours: nine minutes
a subject. A half of 44 is about 6.5 hours on main's code, and nearer 9 for a
lever whose sessions run as long as t3lay's (13 minutes a design against
t2base's 9.5). So: tune on tune's first ten (about 1.5 hours an arm), take a
settled lever to tune's 44 if it is close, and run proof's 44 once. Main's
proof designs stand while src/ai is unchanged, so a proof round is the lever's
44 designs and a `compare` (88 verdicts head to head, about 15 minutes).

**One lever round is 54 designs and about 11 hours** at two workers: tune's
first ten against t2base's (84 to 104 minutes for technique2's and
technique3's arms), proof's 44 (about 9 hours at t3lay's pace, 6.5 at
main's), and the two compares. Taking the lever to tune's 44 as well adds 34
designs and about 7 hours, and main's own tune 44 once, 34 designs and about
5 hours. Those hours are two workers' with each design holding one of the
GPU's two slots for its whole session, so a third waited, and every other
agent's probe with it.

**A design now holds the GPU only while it draws** (2026-10-20). Its app runs
headless, and each picture the session is shown is drawn by a drawer on the
lease (`src/ai/leased_shots.gd`) that starts in 5-10 s and stays up to 20 s
after its last picture, 2 s when another job waits. The pictures are the
window's: on Dubai (21052-1) five views byte for byte, and a change's picture
4 to 9 pixels of a million off, where two windows differ by 1 to 9 on it from
run to run: each drawer's change picture is byte for byte one a window drew in
another run (`tools/bench/leased_shots_check.py`). Four tune designs (3932-1,
7410-1, 40148-1, 9470-1) at two workers took 24.6 minutes; their 25 drawers
held the lease 15.6 of their 42 minutes of sessions (37%, against all of it in
a window), and every picture with something in it was drawn (61; the 9 with
nothing to stage are the letters at once, as in a window). At four workers
the same four ran beside another agent's realset run on a checkout from
before this, whose windowed designs held the lease 86 minutes of the run's 54,
both slots most of the time: the four designs' 31 drawers held it 5.6 minutes,
other agents' probes waited up to 9 minutes (behind those designs and this
test's own picture check, a window that held a slot 8 minutes), 29 of 104 pictures
waited out the 2 minutes a picture may wait and were the letters, and the
sessions ran 19 to 24 minutes against 6 to 15, the fourth (9470-1) out to its
45-minute timeout against 14.5. So a third and fourth worker
pay where the GPU is shared with short jobs, and not beside a run that holds a
slot a session (an arm on a `--checkout` from before 2026-10-20 still does):
run such an arm alone. A clean four-worker round is still to be timed. Not
drawn headless: render_model, which 5 of main's 44 proof designs called, all
but one after their last save.

```sh
env -u ANTHROPIC_API_KEY XDG_DATA_HOME=$PWD/.scratch-data BENCH_PORTS=8960-8969 MESA_VK_WSI_DEBUG=sw python3 tools/bench/realset.py run --which tune --first 10 --arm mine --checkout ../mine --jobs 2 --audit-later
env -u ANTHROPIC_API_KEY XDG_DATA_HOME=$PWD/.scratch-data BENCH_PORTS=8960-8969 MESA_VK_WSI_DEBUG=sw python3 tools/bench/realset.py run --which proof --arm mine --checkout ../mine --jobs 2 --audit-later
heavy env -u ANTHROPIC_API_KEY XDG_DATA_HOME=$PWD/.scratch-data python3 tools/bench/realset.py audit --which proof --arm mine
env -u ANTHROPIC_API_KEY python3 tools/bench/realset.py compare --which proof --arms main,mine --dates 2026-10-19,D --jobs 2
```

Give the run a timeout of eight hours or more: this one's five-hour timeout
stopped its last design, run again alone. Results:
`bench/results/realset-2026-10-19-main/` (report-proof.md, and
report-proof-first10.md for the first ten alone; arm.json says which designs
are t2base's).

### The first arm judged by it: figures on an armature (2026-10-16, `2ad2323`)

The armature unit lays a person, an animal or a head on working joints and
sends an unjointed character back once. Its arm ran the same proof half, one
design a subject, on m33's code with the armature merged.

| dimension | m32 preferred to the set | armature preferred to the set | m32 minus armature, paired (95%) | armature preferred to m32, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% | 30% | 0 (-20, +20) | 65% (35-86) |
| surface | 20% | 40% | -20 (-45, 0) | 80% (49-94) |
| colour | 15% | 30% | -15 (-30, -5) | 70% (40-89) |
| technique | 5% | 15% | -10 (-35, +10) | 75% (44-92) |
| creativity | 25% | 45% | -20 (-45, +5) | 65% (35-86) |
| overall | 20% | 25% | -5 (-35, +25) | 75% (44-92) |

- **Shipped on this.** Every dimension leans to the armature, both ways of
  judging it; colour's gap to the sets closed by a margin that leaves out
  zero; no dimension leans to m32. Ten subjects are few: no overall interval
  leaves out a tie. BrickBench, the outside check, called it a tie overall
  (12 of 24) and gave it surface 21 of 24 (docs/BRICKBENCH.md).
- **Characters.** Against its set the bee won every verdict but creativity.
  Steve & Creeper won surface, colour and creativity both ways and split
  likeness and overall. Jack and Sally won one creativity verdict and lost
  the rest, as m32's did.
- **The gap that stays** is the same as m32's: shapes per 100 parts 16
  against the sets' 28, SNOT 4% against 25%, joints 0% against 3%.
- One design's log (Container Yard) has no hold-out line: that session never
  searched the real-set index.

Results: `bench/results/realset-2026-10-16-armature/` and
`realset-2026-10-16-m32-vs-armature/`.

### Technique: a square design sent back once (2026-10-16, tried and taken out)

Technique is the dimension we lose most to the sets. This round looked for
the cheapest lever on it, on the tune half only, then ran the proof half
once. It did not move technique, and it is not in the code.

**Where the sessions stacked.** Every set of the tune half has joint parts:
locking hinge plates under Shelob's legs and the pyramid's walls, ball joints
in the wolf, clip plates and handle plates for Andrea's spotlights. The
judge's reasons for the sets say the same: "clip-mounted angled spotlights",
"fans the Skytree's legs out at an angle", "a worm-screw drive for the boom".
Ours say "stacked bricks and plates", nine of ten at the start code. Three things,
read in the logs and transcripts:

- A session settles how it builds at its first submission: the whole massing,
  part by part, in coordinates. The real-set briefs name no moving part, so
  nothing at that moment asks for a joint, and it is built square.
- The real-set index reaches the design only through the feature pass, and
  is almost never kept. Of 725 features settled in 289 design logs on disk
  (the proof half left out), 11 kept a real set's piece; 558 were built by
  hand and 156 were refused as the wrong thing ("a grey Technic display beam
  is not a microphone stand").
- SNOT alone does not win the verdict. m32's sheep was 18% SNOT, more than
  its set, and lost technique to "angled leg sub-assemblies on clips and
  hinges".

The verbs are there: a section's `hinge` is one field, and 62 of 267 recent
sessions used it, on BrickBench prompts that named a moving part.

**The lever** (`2dd7663`), the armature's send-back made general: a design
started on a brief, not a character, 20 parts or more, with nothing on a
joint and nothing off the square, sent back once with four ways named for how
they are built (a hinged section, a clip-and-bar detail, a pivot on a pin, a
sideways face) and its own features to look at first. Sent again as it was,
it was built. The armature probe proved it (90 checks).

**The tune half,** both arms on the GPU, one design a subject: the start code
(`b217576`, all ten subjects designed again) against the lever.

| dimension | start preferred to the set | lever preferred to the set | start minus lever, paired (95%) | lever preferred to start, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% (11-60) | 15% (4-46) | +15 (-10, +40) | 50% (24-76) |
| surface | 40% (17-69) | 25% (8-56) | +15 (-15, +45) | 65% (35-86) |
| colour | 35% (14-65) | 30% (11-60) | +5 (0, +15) | 40% (17-69) |
| technique | 5% (1-34) | 5% (1-34) | 0 (0, 0) | 70% (40-89) |
| creativity | 25% (8-56) | 30% (11-60) | -5 (-15, 0) | 65% (35-86) |
| overall | 30% (11-60) | 15% (4-46) | +15 (0, +35) | 55% (27-80) |

**The proof half,** run once on the lever, against the armature arm:

| dimension | armature preferred to the set | lever preferred to the set | armature minus lever, paired (95%) | lever preferred to armature, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% (11-60) | 20% (6-51) | +10 (0, +25) | 35% (14-65) |
| surface | 40% (17-69) | 20% (6-51) | +20 (+5, +35) | 25% (8-56) |
| colour | 30% (11-60) | 20% (6-51) | +10 (0, +25) | 30% (11-60) |
| technique | 15% (4-46) | 5% (1-34) | +10 (0, +25) | 25% (8-56) |
| creativity | 45% (20-73) | 35% (14-65) | +10 (-15, +30) | 35% (14-65) |
| overall | 25% (8-56) | 15% (4-46) | +10 (0, +30) | 30% (11-60) |

- **Technique against the sets did not move:** one verdict in twenty on the
  tune half, both arms. Head to head the judge leaned to the lever's
  technique (70%, 40-89%), an interval that holds a tie.
- **On the proof half every dimension leaned the other way,** and surface fell
  beyond noise. The armature arm drew its designs in software and this one on
  the GPU, so the proof comparison carries that change too; the tune half,
  the same harness on both sides, also leaned against the lever on likeness
  and overall. Not shipped: `b217576`'s assistant is back.
- **What they are made of did not move** (medians, ours against the sets):

| | shapes per 100 parts | SNOT | joints | 1 x 1 |
|---|---|---|---|---|
| tune, start | 22.4 | 8% | 1% | 30% |
| tune, lever | 22.6 | 10% | 1% | 30% |
| tune, the sets | 29.2 | 35% | 7% | 19% |
| proof, armature | 16 | 4% | 0% | 23% |
| proof, lever | 16.1 | 3% | 0% | 20% |
| proof, the sets | 28.4 | 25% | 3% | 13% |

**What stood in the way.**
- *The way out was taken.* Ten designs were sent back, three of seven on the
  tune half and seven of ten on the proof. Four rebuilt with real joints:
  Andrea's spotlights hung on clips (joints 0% to 9%), a hinge brick in Emma's
  studio, click hinges in the Container Stacker, a clip and bar in Naida's
  spa. Six sent it again unchanged or nearly, Tokyo and the Scorpion Pyramid
  among them, though their sets angle the Skytree's legs and hinge the walls.
- *A joint is a detail; technique is judged whole.* Taken, the lever put one
  jointed detail on a stacked model, and the judge said so: "only spotlights
  hung from brackets on a plain stacked wall".
- *"Posed" is read too loosely.* Any joint part counts, a plant's bar or a
  section turned on a stud, so four of the seven non-character tune designs
  were never asked.
- A next lever has to change how the body is built, not add to it: the
  sets' angles are in their main structure (the pyramid's walls, the tower's
  legs, the boom).

**The bench, kept.** A design is a windowed app, so run.py's design stage
now takes the GPU's lease, as every windowed run does; it used to draw in
software under `heavy`. A realset run under one `gpu` holds one lease for
every worker, its workers hold no CPU slot, and `--audit-later` leaves the
build check's reading to `realset.py audit`, one `heavy` job after the run.
At load 45-75 each half had its lease within a minute, while the `heavy`
queue was holding this project's jobs for over an hour. Six designs at once in
one lease: one design's app used under a second of the GPU in ten minutes.
The GPU did not bring the session's pictures sooner: "no picture in time"
came 1 to 2 times a design either way.

Results: `bench/results/realset-2026-10-16-technique-base/`,
`realset-2026-10-16-technique/` (both halves),
`realset-2026-10-16-technique-base-vs-technique/` and
`realset-2026-10-16-armature-vs-technique/`. The base's Year of the Sheep and
Robin each lost a part fetch for forty seconds while the shared
`assets/generated` link was briefly broken; both are characters, which the
lever never touched.

### Technique: the body built on its side (2026-10-16, tried and taken out)

The last lever put a joint on a stacked body and did not move technique.
This one went for the body: its plain faces built on their side, by the call
that lays it. It did not move technique either, and it is not in the code.

**How the bodies are laid.** Read in the ten tune transcripts of the start
code (`technique-base`):

- Six sessions laid the first body by hand, brick by brick: 37 to 101
  parts in one submission, or Robin's in edits. Patterns laid it in four: Tokyo's towers (repeat, round), the End
  island (fill), Shelob's lair (shape, rock) and the pyramid (shape, once).
  A pattern made more expert reaches few bodies.
- The two that reached for a body built rather than stacked were turned
  away. Shelob's legs on ball joints were refused seven times, most for a
  ball and its socket overlapping by 1 to 2.4 LDU. The pyramid's shape was
  sent back as a figure, built on the second try at 16 plates where its
  profile rose to 41, and then laid again by hand: 149 slope bricks.
- The character send-back misreads scenes. A person or a creature named in
  the description is read as the subject: the pyramid's statues, the End's
  dragon, Jungle River and Dino Explorer, in the last round's runs and the
  armature's. Dino Explorer was told "nothing in it is on a
  joint" in 11 replies. The armature unit has the cause
  (`Style.character_of`) and a fix.
- SNOT is the widest gap measured: the tune sets build 35% of their parts
  on their side, ours 8%. The surface pass's flank skin reached little of
  it: only when asked, six a review, never a building, never a run under
  four studs. Tokyo kept five skins in 418 parts.

**The lever** (`369b006`): submit_design lays every plain face of the body
on its side as it builds it. Each course of plain bricks with a face open to
the air is laid again as bricks with studs on the side, with tiles on them a
plate proud. Two-stud runs count, and so do buildings. Each is a kept
finding of the surface pass, so settle_surface can put one back. Replayed
on 15 first bodies from the transcripts, a median 9% of their parts then
stood on their side (0-23%).

**The tune half,** one design a subject, both arms drawn on the GPU (RADV,
every views_render.log):

| dimension | start preferred to the set | lever preferred to the set | start minus lever, paired (95%) | start preferred to lever, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% (11-60) | 10% (2-40) | +20 (0, +50) | 80% (49-94) |
| surface | 40% (17-69) | 30% (11-60) | +10 (-15, +35) | 55% (27-80) |
| colour | 35% (14-65) | 35% (14-65) | 0 (-15, +15) | 65% (35-86) |
| technique | 5% (1-34) | 5% (1-34) | 0 (0, 0) | 65% (35-86) |
| creativity | 25% (8-56) | 15% (4-46) | +10 (0, +25) | 60% (31-83) |
| overall | 30% (11-60) | 20% (6-51) | +10 (-10, +35) | 80% (49-94) |

**The proof half,** run once on the lever, against the armature arm (drawn
on the GPU too: every views_render.log names the RADV device, so nothing was
drawn again):

| dimension | armature preferred to the set | lever preferred to the set | armature minus lever, paired (95%) | lever preferred to armature, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% (11-60) | 25% (8-56) | +5 (-10, +20) | 45% (20-73) |
| surface | 40% (17-69) | 35% (14-65) | +5 (-10, +20) | 60% (31-83) |
| colour | 30% (11-60) | 25% (8-56) | +5 (-10, +20) | 30% (11-60) |
| technique | 15% (4-46) | 5% (1-34) | +10 (0, +25) | 30% (11-60) |
| creativity | 45% (20-73) | 20% (6-51) | +25 (+5, +45) | 25% (8-56) |
| overall | 25% (8-56) | 20% (6-51) | +5 (-10, +30) | 30% (11-60) |

- **Technique against the sets did not move:** one verdict in twenty on
  both halves, as the start's tune half and m32's proof half; the armature
  arm had three. No dimension rose. Creativity fell beyond noise on the
  proof half, and likeness all but did on the tune half: neither is a thing
  a tile on a side stud can do, which says how far two sessions of nearly
  the same code can differ.

**What they are made of** (medians, ours against the sets):

| | shapes per 100 parts | SNOT | joints | 1 x 1 | tiles |
|---|---|---|---|---|---|
| tune, start | 22.4 | 8% | 1% | 30% | 17% |
| tune, lever | 25.5 | 11% | 1% | 30% | 22% |
| tune, the sets | 29.2 | 35% | 7% | 19% | 7% |
| proof, armature | 16 | 4% | 0% | 23% | 18% |
| proof, lever | 18.2 | 5% | 0% | 18% | 18% |
| proof, the sets | 28.4 | 25% | 3% | 13% | 11% |

**What happened.**
- *The faces were laid, and kept.* Six of ten tune designs had faces laid at
  their first submission (Tokyo 15, the End 43, Robin 6, the wolf 5, the
  sheep 3, Shelob 2). SNOT rose on four of them: Tokyo 1% to 6%, the End
  14% to 20%, the sheep 4% to 26% (19 of its 24 sideways parts its own
  round plates and tiles, 4 the lever's), Shelob 18% to 33%. On the proof
  half eight of ten had faces laid and SNOT went from 4% to 5%: a session
  that submits again replaces the model, and Container Yard's first body,
  158 parts on their side, went with it.
- *The judge saw them and did not count them.* Tokyo: "largely stacked
  bricks and round plates, with some sideways-mounted detail on the grey
  towers". The End: "a layered island ... better use of technique than A's
  dragon arms made of plain bricks, even though A has some sideways-mounted
  detail on its base". The sheep: "round plates mounted sideways for wool
  texture are a good idea, but the rest is stacked bricks". What the sets
  win technique on is what they angle: legs and claws on joints, lamps on
  clips, arches, a boom on gears. A face built on its side is still a box.
- *Head to head the start won, carried by sessions the lever never touched.*
  Andrea's Stage, the pyramid and Jungle River had no face laid, and the
  start won likeness and overall on all three, both orders: "its bare
  studded floor looks unfinished", "a lumpy, studded pyramid lost in
  clutter". Two sessions of the same code differ that much; ten subjects
  cannot tell it from the lever.

**Taken out:** submit_design lays the body as it did before. What is kept
is above: where the bodies come from, what a skin reaches, and that a face
on its side does not win the verdict. A next lever has to angle the body,
not face it, and the sessions that tried (Shelob's legs, the pyramid's
shape) were refused by the build check or the send-back before the judge
saw them. The build check read all twenty: the only parts floating are
two minifigure skirts in Emma's studio, none of the lever's.

Results: `bench/results/realset-2026-10-16-faces/` (both halves),
`realset-2026-10-16-technique-base-vs-faces/` and
`realset-2026-10-16-armature-vs-faces/`.

### Characters: faces and a lean in the figure pattern (2026-10-16, `ccab190`)

The figure pattern's heads now have printed eyes, an animal's look out of its
sides, its joint plates are covered and its torso leans (docs/BRICKBENCH.md,
"faces, a lean, and joints in their colours"). Its arm (`figfaces`) ran the
proof half's three characters once each, on the GPU, against the armature
arm's designs, also drawn on the GPU.

| dimension | armature preferred to the set | figfaces preferred to the set | armature minus figfaces, paired (95%) | figfaces preferred to armature, head to head (95%) |
|---|---|---|---|---|
| likeness | 50% (13-87) | 33% (6-79) | +17 (-50, +100) | 67% (21-94) |
| surface | 67% (21-94) | 50% (13-87) | +17 (-50, +100) | 50% (13-87) |
| colour | 67% (21-94) | 33% (6-79) | +33 (0, +100) | 67% (21-94) |
| technique | 33% (6-79) | 17% (2-69) | +17 (-50, +100) | 67% (21-94) |
| creativity | 50% (13-87) | 50% (13-87) | 0 (0, 0) | 50% (13-87) |
| overall | 50% (13-87) | 33% (6-79) | +17 (-50, +100) | 67% (21-94) |

- **The test cannot see the change.** None of the six sessions, either arm,
  laid the figure pattern or was sent back for a statue (read in their
  transcripts): a BrickHeadz brief is built by hand as a big square head with
  its own eyes. What differs is the sessions. Steve & Creeper won
  five dimensions of six both ways against its set; the bee lost all of them,
  where armature's won all but creativity.
- Three subjects are few: every interval holds a tie, colour's only just.
- So the real-set character half says nothing about faces yet. A pattern a
  BrickHeadz session would lay (a head as wide as the body) is what would
  reach it.

Results: `bench/results/realset-2026-10-16-figfaces/` and
`realset-2026-10-16-armature-vs-figfaces/`.
### Technique: joints held by their real shapes (2026-10-16)

The judge's reasons for the sets name legs on joints, lamps on clips, arches
and a boom on gears, and the one session that built a body on joints had it
refused seven times by our own build check. A designer punished for angling
a body will keep stacking. So the check was measured where it must pass:
the jointed parts of real sets, which are built.

**Measured.** `src/dev/joint_collisions.gd` opens each of the model
repository's 1,576 files as File, Open does, stands each part where the check
reads it, and puts every pair whose BrickNet pieces overlap by more than 1 LDU
down to the joint BrickNet's labels join the two by. Gears in mesh and a wheel
turned on its axle the check already excused; they are left out. Each pair
joined by a joint is a false refusal, and the one a design on joints meets.
Before, 3,361 of them in 462 files; now 440:

| joint (BrickNet's label) | pairs refused before | refused now |
|---|---:|---:|
| ball and socket (towballs among them) | 133 | 8 |
| hinge (click hinges, levers, a minifigure's arms and hands) | 757 | 111 |
| clip on a bar (and a bar under a 1-wide plate) | 810 | 297 |
| Technic pin in its hole | 649 | 6 |
| axle in its hole | 864 | 4 |
| turntable | 3 | 3 |
| two kinds at once | 145 | 11 |
| all | 3,361 | 440 |

Each of the 462 files was measured twice, on the code before the fix and on
the code after, and the two runs found the same pairs in every one; what the
fix lets be is read off the second, which records how far each overlap
reaches from its joint.

**The cause.** A convex piece cannot be hollow. BrickNet's colliders fill a
socket's mouth, a clip's jaws, the collar ring of a pin hole and a hinge's
knuckles with convex pieces, and the ball, bar, pin or knuckle seated in them
overlaps those pieces by 1 to 2.5 LDU: 31088's whale's Joint-8 ball in its
socket by 1.0, 10283's towball in its steering arm by 2.5, 10315's mechanical
arm's clip on a handle by 2.3, 10246's lever on its base by 2.0, 10276's
pin in its beam by 1.8. The check, as strict as BrickBench's verify.py,
refused every one.

**The fix** (`ExactCheck.at_joint`, asked where the check refuses a pair by
its shapes, `Assistant._exact_collisions`): two parts BrickNet's labels join
by a ball, a clip on a bar, a hinge (a turntable's too), a pin or an axle,
whose every overlapping pair of pieces
meets inside the joint's own round, are the joint and not a collision. The
round is the joint's own size with 1.5 LDU over, as a cover's slack is: 9.5
LDU from a ball's middle (a Joint-8 ball and a towball are 16 across); 5.5
from a bar's line (8 across; not its stop or a sword's guard, which rest
against the clip and must not be in it: 7.5 let model-010's sword through
its hand, which verify.py refused); 9.5 from a pin's or an axle's (the mouth
of a Technic hole, 16 across, where a pin's collar and an axle's stop sit);
9.5 from a hinge's (its knuckles, a lever's pivot). How far an overlap can
reach is bounded from the two pieces (`Exact.overlap_reach`: the least of
how far either reaches and of their common extent along 128 directions round
a ball, 24 round a line), so an overlap is held to be the joint only where
it must lie inside the round. Anything else stays a collision: a socket's
rim into the next plate's neck, a hinge folded into its base, a ball pushed
through its socket. In a run kept to BrickBench's parts (`PartsOnly`, the
bench) none of it is excused, because verify.py excuses none. Only the
refusal leaves the joint out: asked first of every pair the shapes decide
(`ExactCheck.between`), it let a pin's collar stay inside its hole, which the
check slides out to the mouth (`axle_probe`), and a hinge's top 2 LDU off its
pivot through, which the lattice refuses (`joints_probe`); both fail on that
and pass on this.

**What is left, named.** 440 jointed pairs, none of them proven to be the
joint: each has an overlap the bound cannot put inside the joint's round.
149 of them reach no more than 2 LDU past it (most of them bars: a half pin's
end or a bar's thick stop against the clip or the plate it is under), 190
reach 2 to 10 LDU past, 101 further. By kind:

- **Clip, 297:** half pins and bars under 1-wide plates, which BrickNet
  labels a clip (4274 with 3666, 88072), a bar's thick stop at its clip or
  hollow stud (63965 with 4274, 3062b, 60897), and clip tiles on a part's
  edge (2555 with 30375 and 30031): the holder's body against the clip, not
  the bar in it.
- **Hinge, 111:** a pane against its hinged frame (2348a and 2348b in 2349a,
  29 pairs), shutters and doors on their frames (3853 with 3856 and 3855a,
  4132 with 4133), 2495 with 2496, old finger hinges (4275b with 4276b) and a
  minifigure's arm against its torso (973 with 3818): overlaps away from the
  hinge's line.
- **Ball, 8:** a towball's axle stem in the mouth of a socket (2736 in 2739a
  and 14418), 6628 in 2739a and 15459, one 14417 in a 14704: past the ball.
- **Pin 6, axle 4:** overlaps 2 LDU and more past the hole's mouth (4730 with
  2515a, 22969 with 32496; 2853a with 32184 and 3703). **Two kinds at once,
  11:** 3937 with 3938 and 6134 with 3937, hinge and clip.
- **Turntable, 3:** 3680's ring with 3679, past a hinge's round.

**Shelob's legs.** `src/dev/replay_calls.gd` makes a session's calls again
on this checkout: on the base code it repeats the base round's fourteen leg
calls (realset-2026-10-16-technique-base, 9470-1) to the collision, eleven
refused as the session was. The seven ball-joint refusals are Joint-8 plates,
14419 on 14419 bent 43 to 67 degrees from straight and 14419 on a 14417's side
ball, and each pair overlaps out to 10.5 to 15.5 LDU from the ball's middle,
outside the ball (8): a 14419's socket is two jaws, and by BrickNet's shapes
it bends 70 degrees up or down with nothing touching but meets the next
plate's neck at 38 to 50 degrees sideways (a sweep of one joint: clear to 40,
1.2 LDU in at 45). Real sets never bend one that far: of the 43 repository
files with Joint-8 plates, the most a 14419 joint bends is 21 degrees
(21311's; 10276's 8, 21318's 15). So these refusals stand: not proven false,
and Shelob's legs as that session bent them are still refused. What changed is what the session is
told. It was "move one clear of the other by 2 LDU 1.1 LDU -x", and it
guessed "bent too sharply"; now (`ExactCheck._ball_turned`) it is "brick 18
is bent 49 degrees in its ball joint with brick 17, and past about 41
degrees that way its socket's rim meets the ball's neck. Keep the joint,
and bend it 41 degrees or less that way, or another way". The legs it did
build, bent about 40 degrees, passed before and pass now.

**BrickBench stays as strict.** verify.py passes the armature round's twelve
submissions as it did (12 of 12, run again into this round's folder). Our
check over every BrickBench build there is (the 2026-10-14 round's ten and
BrickAgent's ten, the armature round's twelve and BrickAgent's six) finds the
46 colliding pairs verify.py found, and in a run kept to BrickNet's parts
lets none of them be. Without the gate it would let 4 be: model-002's axle
through four horns, the axle in their holes by BrickNet's shapes, which
verify.py refuses. That is what the gate is for.

**What else was checked.** The connection audit over its sample (every 25th
file, 64 files, 29,931 parts): 94.06% held before and after (1,778 floating
either way), overlapping pairs 3,209 to 3,115. `exact_probe` 29 of 29,
`by_connector_probe` 43 of 43 (the hinge folded the way it does not open
still refused as the hinge), `figure_joints` 43 and `armature` 82, and
`joints`, `axle`, `section`, `clutch`, `techniques`, `attach`, `turned` and
`technic` with no failure; `exact_cost_probe` an edit to Orthanc spending 100
ms in the exact check (budget 3 s). `src/dev/joint_check_probe.gd` holds
it, 19 checks: each real set's pair above passes, at the joint it is; a leg
of three Joint-8 plates on a body, bent about 40 degrees each, passes; a
Joint-8 plate bent 50 degrees sideways is refused as bent, a ball pushed 5
LDU through its socket and a hinge folded into its base are refused, and a
real set's clip on its bar is refused in a run kept to BrickBench's parts.

**The tune half, run once** (arm `jointcheck`, ten designs on the GPU,
19:40 to 20:52, on this worktree while it was still being changed: the
rounds, the bent-joint message and where the joint is excused changed under
the first nine designs, and Shelob's alone ran on the code committed here):
technique preferred to the set 0 of 20
verdicts (0-28%), against the start code's 1 of 20; overall 20% (6-51%)
against 30%; likeness 20% against 30%. Nothing moved beyond the noise of
ten subjects, and nothing says sessions now keep jointed bodies: none met a
joint refused at its joint, none was told a ball joint was bent too far,
and this time Shelob's session built her legs of clips on bars rather than
ball joints. Parts at an angle stay rare (a median 0% against the sets'
7%). The check no longer turns a jointed body away for its joints; whether
sessions build one is the designer's, not the check's.

Results: `bench/results/jointcheck-2026-10-16/` (the measure before and
after, `before-*.jsonl` and `after-*.jsonl`; the replays; the BrickBench
runs; the audit's sample) and `realset-2026-10-16-jointcheck/`.

### Technique: the body's build shown before the first brick (2026-10-16, tried and taken out)

The last three levers came after the body was settled: a send-back, a face
laid sideways, a check that lets joints be. This one went where the body is
settled, the session's opening, and showed it how real sets of the brief's
line build a body. Sessions read it and built as before.

**The first plan.** Read in the twenty tune transcripts of the start code and
the jointcheck arm, up to the first submission (only calls and words are
kept, not a session's thinking):

- Every session opened with how_real_sets_build_this, 20 of 20. It said
  nothing of how a body is built. Fifteen first calls found no kind of set
  ("concert stage", "telehandler", "architecture skyline", "brickheadz",
  "pyramid", "wolf creature"). Ten sessions got nothing from it at all. Ten
  got parts by how much more often sets of a kind use them (doors, windows,
  plant stems), and colours.
- Eleven asked the real-set index before the first brick, most for the body.
  Five got the wrong thing: Spider-Man's BrickHeadz for "giant spider legs"
  (the word "spider"), Tokyo's rooftop garden for "pyramid scorpion", The
  Cave's spider for "minecraft ender dragon micro", a giraffe's head for
  "wolf legend beast head". Four got a detail of the right kind: a five-part
  boom pivot, a sheep set's plate work held from outside it. All nine were
  set aside.
- The one whole body that fitted, a BrickHeadz frame for Robin, was laid
  and built on, both times.
- So "stacked" is chosen at the first submission, from memory. 14 of 20
  first bodies were placed by hand (37 to 117 parts; a pattern for a rock or
  an island in some), four were a pattern (the pyramid's shape, the wolf's
  figure), two a real set's frame. Only Technic sections, Shelob's legs on
  clips or balls, the figure and the frame were off the square there.

**Why real pieces were "the wrong thing".** Every rejection in the realset
logs, 77 over all arms, traced to the piece the app laid: 60 the wrong kind
of thing, 7 the wrong size, 6 the wrong place, 1 the wrong colour, 3 other.
68 of the 76 pieces laid were of another line than the brief's: a Tower
Bridge pinnacle for a Technic engine grille, a Batmobile's eye for a Friends
vanity mirror, Cafe Corner's hotel sign for an Architecture nameplate. The 17
kept were no better, 2 of the line. The ranking did it. A subject word from
the session's own description (tower, hotel, dragon) put another line's sets
first for 30, a word's other sense (light grey, a mirrored copy) for 32, and
the line was never asked. Size did not tell rejected from kept (the long side
a median 0.12 and 0.13 of the plan's), and 74 of 76 were laid as built.

**The lever** (`543c726`): the brief's line, in the retrieval the plan is
made with.

- how_real_sets_build_this answers first with how the line builds a body:
  the line the brief names (every word of a theme the real-set index holds,
  the one named first), its six biggest sub-assemblies of 12 parts or more,
  those built other than stacked square first, each with how it is built (on
  hinges or clips, at an angle, studs sideways, on brackets, of slopes, of
  curves), a picture of them, and the nearest two to each mass the session
  names in a new `assemblies` input. A brief of no line gets sets about its
  subject. Step 1 of the head asks for the masses.
- A feature's piece comes from the brief's line first, where the feature's
  own words find one.
- `real_bodies_probe` held it, 26 checks; it went out with the lever.

**The tune half,** one design a subject, on the GPU (one lease, five at a
time, 29 minutes), against the sets and head to head with the start code
(`technique-base`) and the jointcheck arm:

| dimension | start preferred to the set | jointcheck | bodies | start minus bodies, paired (95%) | jointcheck minus bodies | bodies preferred to start, head to head | bodies preferred to jointcheck |
|---|---|---|---|---|---|---|---|
| likeness | 30% (11-60) | 20% (6-51) | 30% (11-60) | 0 (-15, +15) | -10 (-40, +20) | 40% (17-69) | 75% (44-92) |
| surface | 40% (17-69) | 35% (14-65) | 35% (14-65) | +5 (-20, +30) | 0 (-30, +25) | 45% (20-73) | 65% (35-86) |
| colour | 35% (14-65) | 25% (8-56) | 30% (11-60) | +5 (0, +15) | -5 (-15, 0) | 35% (14-65) | 50% (24-76) |
| technique | 5% (1-34) | 0% (0-28) | 10% (2-40) | -5 (-15, 0) | -10 (-25, 0) | 60% (31-83) | 75% (44-92) |
| creativity | 25% (8-56) | 25% (8-56) | 25% (8-56) | 0 (-15, +15) | 0 (-15, +15) | 55% (27-80) | 35% (14-65) |
| overall | 30% (11-60) | 20% (6-51) | 25% (8-56) | +5 (0, +15) | -5 (-20, +10) | 35% (14-65) | 80% (49-94) |

- Technique against the sets: 2 verdicts of 20 (The End's island tapered
  with slopes, the Jungle River's arch and angled palm), against 1 and 0.
  Head to head the judge leaned to the lever over jointcheck on all but
  colour (even) and creativity, and to the start over the lever on all but
  technique and creativity. The two bases differ more than the lever does.

**What the sessions did with it.** All ten named their masses at the first
call, four to six each. None laid a piece it was shown, before the first
submission or after. The first bodies were built as before: the pyramid a
stepped fill, shown the line's temple of 75-degree slopes for its "stepped
pyramid wall"; Tokyo stacked towers, shown Architecture's towers of side-stud
tiles and slopes. Where the line had nothing of the mass, its words found the
wrong thing again: "giant spider" a skull and a Giant Truck's chassis,
"exit portal" a Unimog's rear hub. Two real pieces were laid whole all run,
both palm trees each session searched for itself. The judge's reasons for the
sets were the same as ever: "the Tokyo Tower's legs as angled sub-assemblies",
"legs from several angled joint segments", "a worm-gear lift for the boom".
Ours: "almost entirely bricks stacked straight up".

The line did change what the feature pass laid, not whether it was kept: 8
of the 21 pieces it laid were of the brief's line (before, 10 of 93 laid on
all arms), and 1 was kept, 9 rejected, 21 features built by hand (the start:
1, 8, 19). The Telehandler's headlamps, mirrors, mudguards and rear lights
were Technic pieces now, and were rejected for where they sat ("sat on top
of the beacon", "lies flat on the deck between the wheels"), not for what
they were. Where the line had no such piece, the old faults came back: the
Batmobile's eye for the eyes of a sheep, a wolf and Shelob.

**The proof half,** run once on `543c726`, against the armature arm (both
drawn on the GPU: every views_render.log names the RADV device):

| dimension | armature preferred to the set | bodies preferred to the set | armature minus bodies, paired (95%) | bodies preferred to armature, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% (11-60) | 30% (11-60) | 0 (-20, +20) | 35% (14-65) |
| surface | 40% (17-69) | 35% (14-65) | +5 (0, +15) | 35% (14-65) |
| colour | 30% (11-60) | 15% (4-46) | +15 (-10, +40) | 40% (17-69) |
| technique | 15% (4-46) | 5% (1-34) | +10 (0, +30) | 40% (17-69) |
| creativity | 45% (20-73) | 45% (20-73) | 0 (-20, +20) | 55% (27-80) |
| overall | 25% (8-56) | 25% (8-56) | 0 (-20, +25) | 30% (11-60) |

- **Technique against the sets did not rise:** one verdict in twenty (Emma's
  studio: dress forms of cones, the sign a raised sub-assembly), as m32's,
  the send-back's and the faces' proof halves; the armature arm had three.
  No dimension rose. None fell beyond noise, though technique's and
  surface's intervals only just hold a tie.
- **One session of ten laid what it was shown:** Jack Skellington & Sally,
  on the BrickHeadz frames of Venom and Spider-Man. It lost technique both
  ways ("grille tiles awkwardly placed as mouths"). Steve & Creeper was shown
  the same frames and built its own. The sets' reasons were the same as
  ever: "a rack-driven telescoping boom", "SNOT-mounted round eyes", "hinged
  and clipped sub-assemblies at angles for the head".
- Features: 12 of the 19 pieces laid were of the brief's line; 2 kept
  (Naida's waterfall and flowers, of other lines, as the armature and faces
  arms kept), 7 rejected, 20 built by hand (armature: 3, 8, 24).

**What they are made of** (medians, ours against the sets):

| | shapes per 100 parts | SNOT | joints | 1 x 1 |
|---|---|---|---|---|
| tune, start | 22.4 | 8% | 1% | 30% |
| tune, jointcheck | 23.7 | 6% | 0% | 36% |
| tune, bodies | 24.6 | 11% | 1% | 26% |
| tune, the sets | 29.2 | 35% | 7% | 19% |
| proof, armature | 16 | 4% | 0% | 23% |
| proof, bodies | 17.5 | 7% | 1% | 24% |
| proof, the sets | 28.4 | 25% | 3% | 13% |

Small moves the same way on both halves, SNOT 3 points up on each against
its start and shapes 1.5 to 2 a hundred, each within what two sessions of
one code differ by. The build check read all twenty: a median 0% floating
on both halves.

**Taken out:** how_real_sets_build_this, the feature pass, the head and the
tool list are `71da669`'s again. What is kept is above.

**What it says.** Shown where the plan is made, in the call every session
makes, with a picture and an id to lay, the line's built bodies were read
and not used: 1 session of 20 laid one. The masses the sessions named in that
call were already their own ("stepped pyramid wall", "giant spider",
"woolly body"), and the first submission built them as named, from memory.
So a choice offered, however early, is advice, and advice does not reach the
body. The lever that can is the app building the technique itself, as the
figure pattern lays a character on joints: a leg of jointed segments, a wall
of slopes on hinges, a face built sideways whole, laid by the call that lays
the mass. The line is worth having for that, and for the feature pass: where
the line has the kind of thing, its pieces were the right kind (the
Telehandler's Technic lamps and mudguards), and what sent them back was the
seat.

Results: `bench/results/realset-2026-10-16-bodies/` (both halves; the tune
arm ran on `7b2943b`, whose head said step 1 at greater length, the rest as
`543c726`), `realset-2026-10-16-jointcheck-vs-bodies/`,
`realset-2026-10-16-technique-base-vs-bodies/`,
`realset-2026-10-16-armature-vs-bodies/`, and in
`realset-2026-10-16-bodies/diagnosis/` the sessions' digests (start,
jointcheck and this arm) and every realset rejection traced to its piece
(`labels.tsv`, `realset_pieces.tsv`).

### Technique: bodies the app builds (2026-10-17, laid, not counted, the push taken out)

Four levers came at the body from outside it, and each left it stacked: a
session chooses the body at its first submission and lays it from memory.
The figure pattern is the one lever that won, and it is one entry. So this
round made three more bodies one entry each, with the technique the sets win
on built in. Sessions laid them. The judge did not count them.

**Which bodies.** Every verdict that gave a set technique, over the six arms
judged on both halves (197 verdicts, 20 subjects), read for what it names in
the set. Named in half or more of a subject's verdicts:

- legs or limbs of angled joint segments: 7 subjects (Shelob's legs, the
  scorpion's legs and claws, the wolf's and the sheep's legs, the sphinx's
  legs and jaw, the dragon's wings and neck, the Tokyo Tower's legs);
- a face built sideways, with side-built panels and clip hands: the 4
  block-figure subjects (the bee, Robin, Steve & Creeper, Jack & Sally);
- a boom on pins or gears: 3 (the Telehandler, the Container Yard, the
  Container Stacker).

The rest name details (spotlights on clips, a laptop's hinged lid), arches,
vehicles of their own, a layered overhang.

**The patterns** (`7225ecc`, then `c24de17`):

- `{"pattern": "legs"}`: a chassis of two crossed layers of plates on two to
  four pairs of legs of Joint-8 ball plates (14417 at the hip, 14419 for each
  segment, 14418 for the foot), fanned, a neck and a jointed tail if said,
  turned any way. Each segment is turned whole with its studs to the sky, so
  a knee bends the way a socket bends furthest: aimed by `align`, every knee
  bent 45 degrees or more was refused, its socket's rim meeting the next
  plate's neck. The feet land 1 LDU over the floor: the chassis's height and
  the first and last segments are worked out for it, exact to 0.1 LDU against
  the parts as laid. `legs_probe`, 112 checks.
- `{"pattern": "figure", "kind": "block"}`: a head as wide as the body,
  a ring of bricks with studs on their side (22885), the face a plate on them
  tiled round two printed eyes, the sides tiled panels in the hair's colour,
  arms on side studs with a clip for a hand. `block_figure_probe`, 57.
- `{"pattern": "boom"}`: two Technic beams on friction pins in a pair of
  Technic bricks, raised to its angle, tied by pins, a hook block on the tip,
  the foot grown under a long boom so it stands. `boom_probe`, 135.

Told where the body is chosen: the patterns' description in submit_design,
and a short block at the head of how_real_sets_build_this's answer, which
every session asks first.

**The tune half, first version** (`7225ecc`, arm `builtbodies`, one GPU
lease, 2 to 16 minutes a design), against the start code:

| dimension | start preferred to the set | builtbodies preferred to the set | start minus builtbodies, paired (95%) | start preferred to builtbodies, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% (11-60) | 20% (6-51) | +10 (0, +25) | 75% (44-92) |
| surface | 40% (17-69) | 20% (6-51) | +20 (+5, +40) | 60% (31-83) |
| colour | 35% (14-65) | 30% (11-60) | +5 (0, +15) | 65% (35-86) |
| technique | 5% (1-34) | 0% (0-28) | +5 (0, +15) | 50% (24-76) |
| creativity | 25% (8-56) | 20% (6-51) | +5 (-10, +20) | 65% (35-86) |
| overall | 30% (11-60) | 20% (6-51) | +10 (0, +30) | 75% (44-92) |

- **Laid where the body is chosen.** Five of ten first submissions laid a
  body pattern, where real sub-assemblies shown first reached one session in
  twenty: Robin the block figure, the wolf, Shelob and the scorpion legs, the
  Telehandler the boom. Four kept it to the end. The other five (a stage, a
  river boat, a skyline, an island, a sheep) laid none.
- **The judge did not count them.** Technique went to the set in all twenty
  verdicts. Shelob: "simple clip joints on its legs"; "flat splayed legs that
  look more like a crab". The scorpion: "a simple hinged-plate assembly"; "a
  scorpion laid flat on the ground". The Telehandler: "a static Technic beam
  laid on as the boom", against the set's worm gear. Robin: "only hangs a few
  clips on the sides of a solid stack"; "no legs".
- **The wolf's session threw its legs away**: laid low between knees raised
  over it, it was "the app's low crawler", rebuilt on stacked legs.

**The second version** (`c24de17`), from those: two pairs stand upright, legs
under the body; three and four pairs arch on four segments; the block
figure's legs are two bricks tall and its reply says it is bare until dressed.
Run again on the four tune subjects that had laid a pattern (arm
`builtbodies2`): 0 of 8 technique verdicts, 0 of 8 overall. Shelob kept her
arched legs: "repetitive flat hinged plate chains laid out the same way". The
wolf laid upright legs and rebuilt on stacked ones again; the scorpion and
Robin laid none.

**The proof half,** run once on `c24de17`, against the armature arm:

| dimension | armature preferred to the set | builtbodies preferred to the set | armature minus builtbodies, paired (95%) | armature preferred to builtbodies, head to head (95%) |
|---|---|---|---|---|
| likeness | 30% (11-60) | 30% (11-60) | 0 (-20, +25) | 70% (40-89) |
| surface | 40% (17-69) | 55% (27-80) | -15 (-40, +10) | 60% (31-83) |
| colour | 30% (11-60) | 5% (1-34) | +25 (+5, +50) | 65% (35-86) |
| technique | 15% (4-46) | 0% (0-28) | +15 (0, +40) | 65% (35-86) |
| creativity | 45% (20-73) | 15% (4-46) | +30 (0, +60) | 85% (54-96) |
| overall | 25% (8-56) | 15% (4-46) | +10 (-10, +35) | 75% (44-92) |

- **Technique did not rise; it fell to none,** 0 of 20 against armature's 3.
  Colour fell beyond noise and creativity all but did. Surface leaned our
  way. Not shipped.
- **Uptake.** Five of ten laid a body pattern at their first submission and
  four kept it: the three block-figure briefs (the bee, Steve & Creeper, Jack &
  Sally, every one) and the Container Yard's boom. Dino Explorer laid upright
  legs and dropped them; the sphinx and the Container Stacker laid none.
- **The block figures were built sideways and read stacked.** SNOT on the
  three went from 0-27% (armature) to 41-48%, the sets' own 36-45%, and the
  judge said "mostly plain stacked bricks with a tiled face", "faces mostly
  bricks stacked studs-up", against the sets' "SNOT-mounted round eye tiles"
  and "curved hair attached sideways". Rendered beside the set, Steve &
  Creeper is the set's build, a flush face for the set's raised eyes; it won
  surface both ways. The bee lost all but one surface verdict, where
  armature's hand-built bee won everything but creativity; it came in five
  colours to the set's 14.
- **The boom read as one beam.** The Container Yard: "a single Technic beam
  for the boom", against "a gear rack on the telescopic boom, a
  linear-actuator-style piston, a pivoting spreader". A Technic brief's
  technique is its mechanism, which a pinned boom is not.

**What they are made of** (medians, ours against the sets):

| | shapes per 100 parts | SNOT | joints | 1 x 1 |
|---|---|---|---|---|
| tune, start | 22.4 | 8% | 1% | 30% |
| tune, builtbodies | 25.1 | 11% | 1% | 33% |
| tune, the sets | 29.2 | 35% | 7% | 19% |
| proof, armature | 16 | 4% | 0% | 23% |
| proof, builtbodies | 17.5 | 3% | 1% | 28% |
| proof, the sets | 28.4 | 25% | 3% | 13% |

Where a pattern was laid its parts moved toward the set's (the scorpion's
angled parts 1% to 5%, the block figures' SNOT to the sets'); the medians did
not. The build check read all the designs of both halves: a median 0%
floating. The bee's and the Container Yard's logs have no hold-out line: those
sessions never searched the real-set index.

**BrickBench, once, as an outside check.** The armature round's six
character prompts, one design each on `c24de17`, against that round's
`figfaces` designs and BrickAgent's, our judge both orders twice: 72 verdicts.
All six valid by verify.py. Head to head, figfaces 11 of 24 overall (46%,
28-65%), 10 of 24 technique (42%, 24-61%): a tie. Against BrickAgent, 1 of 24
overall (figfaces 2). No session laid legs, a block figure or a boom; three
laid the figure pattern as before. So it says only that nothing else moved.

**Taken out, kept aside.** None of it is on main. Without the push (the
block at the head of how_real_sets_build_this's answer, the patterns'
longer description in submit_design) sessions laid them as rarely as they
used real sub-assemblies, and laid, they lost. The three patterns, each
laying a body that passes the check as it stands, are kept with their probes
on the branch `exp/builtbodies-2026-10-17` at fbf0d52
(src/ai/legs_pattern.gd, block_figure.gd, boom_pattern.gd), for a unit that
dresses what they lay: what the judge counts, below.

**What it says.** An entry that lays the body is taken where advice is not:
ten first submissions of twenty laid one and eight kept it, against one
session in twenty that laid a real sub-assembly it was shown. But the judge's
technique is not in the joints or the sideways studs; it is in what they
make. A set's spider arches high on long
segments of varied parts, its abdomen raised on a joint; ours repeated one
thin chain. A set's block figure carries round printed eyes standing proud and
curved hair; ours had the set's build with a flush face. A Technic set's boom
has a rack and an actuator. The technique the judge sees is the silhouette a
joint gives and the parts that dress it, which a pattern of plain plates on
balls does not reach, and a session that has its body handed over dresses
less: colour and creativity fell.

Results: `bench/results/realset-2026-10-17-builtbodies/` (both halves),
`realset-2026-10-17-builtbodies2/` (the second version on four tune
subjects), `realset-2026-10-17-technique-base-vs-builtbodies/` and
`realset-2026-10-17-armature-vs-builtbodies/`; BrickBench's in
`brickbench-2026-10-16-armature` (arm `builtbodies`; the round's own
`compare.md` kept) and `technique4-2026-10-17/compare-figfaces-builtbodies.md`.

### Technique: the model planned before its first brick (2026-10-19, tried, not shipped)

Five levers came at technique after the body was settled or offered advice
before it, and none moved the judge: a session settles how it builds at its
first submission, from memory and square, and real sub-assemblies shown before
then were read and not used. This one had the session make the choice itself,
sub-assembly by sub-assembly, before the massing, from counts of how the real
ones of each kind are built, and held its first build to that plan. Sessions
planned, and built to the plan. Technique against the sets did not move beyond
noise. It is on the branch `technique2`, not on main.

**The lever** (`plan_build`, src/ai/build_plan.gd).
- A session names three or more sub-assemblies, as a set's bags would be, and
  what each is. The answer counts how the eight real sub-assemblies nearest each
  are built (`RealSnippets.built_like`: the brief's line first where its pieces
  have as many of the words as any line's, then any line; one a set, 8 parts or
  more, the set under test held out), with three examples. The session then
  says how each is built: stacked, sideways, hinged, angled, brackets, sloped or
  curved. Stacked where 60% of the real ones are not needs a why.
- Step 1 of the instructions' head names it, and how_real_sets_build_this's
  answer leads with it. A session on a brief that submits 20 parts or more with
  no plan is sent back once.
- A first build whose planned sub-assembly, found by name among its assemblies,
  is not built so is sent back, naming it, the way and how that way is built
  here, up to three times, or until the plan is changed with a why. The check
  counts the parts in its box: on their side, turned, sloped or curved, 15% and
  two at least; on a joint or a bracket, two.
- `build_plan_probe`, 22 checks.

**Three versions on the tune half,** each read in its transcripts before the
next (bench/results/technique2-2026-10-19/digests/).
- *v1* (`f2e8e31`): the plan only in how_real_sets_build_this's answer, the
  no-plan send-back, a build not as planned sent back once. The sheep's session
  read it, built 58 bricks from memory and planned only when sent back: its two
  submission boxes, "sheep" with every way at once, then the same model. A plan
  made after the massing is the stacked model again. Stopped after one design.
- *v2* (`76a7e30`): plan_build in the head's step 1, three sub-assemblies at
  least. Both sessions run planned before any brick, within 25 seconds, and
  lost technique both ways as main's did: "A is mostly stacked slopes and simple
  brick columns" against "the scorpion's angled legs and pincers on clips and
  hinges". The scorpion, planned hinged, angled, sideways and curved, was sent
  back with 0 of its 28 parts on a joint, came again unchanged and was built.
  Sent back once is advice again. Stopped after two.
- *v3* (`65c7259`): sent back up to three times, and a way is a share of the
  sub-assembly, not one part. Run on all ten.

**What v3's sessions did** (all ten tune transcripts):
- Every one planned before its first brick, 10 to 63 seconds in, 3 to 7
  sub-assemblies, 47 in all. 4 were planned stacked alone; 7 more named stacked
  first among their ways.
- Nine of ten first builds were sent back for a sub-assembly not built as
  planned, 20 times in all. Eight sessions gave whys, 25 in all: "a
  raised arch 1x6 gives the bridge its hump, as Adventurers bridges did"; the
  others built the way in.
- Jungle River planned its palms "angled, curved" and built them leaning on
  sections, and won technique both ways ("a leaning, segmented palm trunk, an
  arched ruin"), where main's lost it. The End won it, as main's did. The other
  eight lost it as ever: Tokyo "mostly stacks plain round bricks and walls"
  against "the tower legs from angled sub-assemblies"; the Telehandler "stacked
  system bricks with a few Technic bricks and pins added for looks" against "a
  worm gear and screw to raise the boom"; Shelob, at 12% joints as main's, "legs
  straight plates fixed at single angles" against "multi-jointed legs".

**The tune half,** both arms in the same harness, drawn on the GPU, one design a
subject: main (`7299b56`, arm `t2base`) against v3 (`t2plan3`).

| dimension | main preferred to the set | v3 preferred to the set | main minus v3, paired (95%) | v3 preferred to main, head to head (95%) |
|---|---|---|---|---|
| likeness | 25% (8-56) | 15% (4-46) | +10 (-10, +35) | 50% (24-76) |
| surface | 30% (11-60) | 30% (11-60) | 0 (-20, +20) | 45% (20-73) |
| colour | 30% (11-60) | 35% (14-65) | -5 (-15, 0) | 65% (35-86) |
| technique | 10% (2-40) | 20% (6-51) | -10 (-30, 0) | 75% (44-92) |
| creativity | 30% (11-60) | 30% (11-60) | 0 (-30, +30) | 60% (31-83) |
| overall | 15% (4-46) | 20% (6-51) | -5 (-30, +15) | 55% (27-80) |

- Technique leaned to v3 both ways of judging it, 4 verdicts of 20 against 2
  and 75% head to head, and neither interval leaves out a tie. Likeness leaned
  to main. The two subjects v3 won technique on are the river and The End;
  main's two were The End's.

**The proof half,** run once on v3, against main in the same harness.

| dimension | main preferred to the set | v3 preferred to the set | main minus v3, paired (95%) | v3 preferred to main, head to head (95%) |
|---|---|---|---|---|
| likeness | 25% (8-56) | 20% (6-51) | +5 (-20, +35) | 45% (20-73) |
| surface | 25% (8-56) | 40% (17-69) | -15 (-45, +15) | 60% (31-83) |
| colour | 20% (6-51) | 20% (6-51) | 0 (-15, +15) | 65% (35-86) |
| technique | 0% (0-28) | 10% (2-40) | -10 (-25, 0) | 50% (24-76) |
| creativity | 25% (8-56) | 35% (14-65) | -10 (-35, +15) | 55% (27-80) |
| overall | 20% (6-51) | 20% (6-51) | 0 (-25, +20) | 50% (24-76) |

- **Technique against the sets did not move beyond noise:** 2 verdicts of 20
  against main's none, the paired interval reaching zero, and head to head the
  judge split technique evenly. The two were the bee ("builds the face sideways
  with SNOT and mounts the antennae and wings on hinge and clip plates at
  angles") and Jack & Sally ("Sally's hair as tidy SNOT side panels"), each
  one order of two. Nothing fell beyond noise; surface and colour leaned to
  v3. Not shipped.
- Every proof session planned before its first submission too, 10 to 195
  seconds in, five or six sub-assemblies each.

**What they are made of** (medians, ours against the sets):

| | shapes per 100 parts | SNOT | joints | 1 x 1 | tiles |
|---|---|---|---|---|---|
| tune, main | 26.9 | 7% | 1% | 29% | 15% |
| tune, v3 | 23.4 | 12% | 1% | 29% | 22% |
| tune, the sets | 29.2 | 35% | 7% | 19% | 7% |
| proof, main | 15.4 | 2% | 0% | 29% | 16% |
| proof, v3 | 17.6 | 12% | 0% | 25% | 20% |
| proof, the sets | 28.4 | 25% | 3% | 13% | 11% |

SNOT moved on both halves, 5 and 10 points toward the sets, more than any
technique lever before it moved a median; joints did not. The build check read
main's designs on both halves and v3's on the tune half: a median 0%
floating. v3's proof designs were not audited.

**What it says.**
- *Planning reaches the body; the plan's ways are the session's own.* A plan
  asked for in step 1 is made before any brick, every time, where a body shown
  there was used once in twenty. Held to, it is built: SNOT rose from 7% to 12%
  on the tune half and from 2% to 12% on the proof. But the ways a session chooses are the ones it can lay from
  memory, faces on side studs and a few curves on a stacked body, "stacked"
  first in most; the real sets' ways that the judge names (legs on several joints, a
  tower's legs as angled arches, a worm drive) were planned in a few
  sub-assemblies and built as one hinge where the set has a jointed limb.
- *The judge still reads the whole.* Where a plan put the angle into the
  silhouette (the river's palms), technique was won; where it put a technique
  into a box the judge did not look at, nothing changed.
- *Next.* The plan is the right place, and its evidence is the weak part: by
  words alone the nearest real sub-assemblies are often of another kind (a
  gear train's "stage 2" for a stage roof, a dressing table's cone legs for a
  sheep's). What
  would test the idea harder is evidence that is the real set's own build of
  that kind of thing at that size, shown as a picture and its joint parts, and
  a plan answered with the way that makes the silhouette (the angle, the
  joints), not the finish. Laid, not described: the app's patterns for jointed
  legs and booms (`exp/builtbodies-2026-10-17`) as what a "hinged" or "angled"
  sub-assembly is built from when planned.

Results: `bench/results/realset-2026-10-19-t2base/` (main, both halves),
`realset-2026-10-19-t2plan3/` (v3, both halves),
`realset-2026-10-19-t2base-vs-t2plan3/` (head to head), v1's and v2's partial
arms `realset-2026-10-19-t2plan/` and `-t2plan2/`, and the sessions' digests in
`technique2-2026-10-19/digests/`.

### Technique: the planned way laid, not described (2026-10-19, tried, not shipped)

The plan reached the body and its ways were the session's own: faces on side
studs on a stacked body, where the sets' legs are joints. This round changed
what the plan is answered with and what a planned joint is built from. It is
on the branch `technique3`.

**The lever** (`aad64d3`, src/ai/build_plan.gd, real_snippets.gd).
- *Evidence of the kind and size.* For each planned sub-assembly, with its
  studs, a real one whose own sub-model is named for that kind
  (`RealSnippets.kind_like`: "leg" is a sub-model called leg; a cluster is the
  kind it is in; a name's part, colour, size and step words are no kind),
  its longest side within half to twice the plan's, the brief's line first,
  the set under test held out. Pictured (one sheet, the plan's order), with its
  joint parts and sideways parts by name, and how the eight nearest of the kind
  are built: shaped on joints or at an angle, only finished, or stacked.
- *Answered with the shape, not the finish.* Where 40% or more of the kind are
  on joints or at an angle, the picture is one of those, and a plan that leads
  with another way is not kept without a why.
- *Laid, not described.* A sub-assembly planned hinged or angled whose name or
  what says leg, limb, boom or jib is given the app's entry that lays it (the
  legs and boom patterns of `exp/builtbodies-2026-10-17`, brought over with
  their probes), named as planned, a spider's or a scorpion's four pairs; a
  submission whose patterns laid it counts as built as planned, and a send-back
  for it carries the entry.
- `build_plan_probe` 30 checks, `legs_probe` 112, `boom_probe` 135.

**A first version** (`ac6816f`) matched a kind by any word of a sub-model's
name, and the tune half's first session, the sheep, was shown a train's tank
("brick work in tank" for "brick-built sheep"). It was stopped after two
plans and the kind made the sub-model's own (`aad64d3`), the version run.

**The tune half,** in the same harness as technique2's (realset.py of
`7299b56` with its port range, drawn on the GPU, one design a subject):
v3's designs (`t2plan3`) as the start arm, this lever as `t3lay`.

| dimension | v3 preferred to the set | t3lay preferred to the set | v3 minus t3lay, paired (95%) | v3 preferred to t3lay, head to head (95%) |
|---|---|---|---|---|
| likeness | 15% (4-46) | 10% (2-40) | +5 (0, +15) | 70% (40-89) |
| surface | 30% (11-60) | 15% (4-46) | +15 (-10, +40) | 70% (40-89) |
| colour | 35% (14-65) | 30% (11-60) | +5 (0, +15) | 75% (44-92) |
| technique | 20% (6-51) | 15% (4-46) | +5 (0, +15) | 65% (35-86) |
| creativity | 30% (11-60) | 25% (8-56) | +5 (-15, +30) | 65% (35-86) |
| overall | 20% (6-51) | 10% (2-40) | +10 (0, +25) | 70% (40-89) |

- **It lost the tune half,** every dimension both ways of judging it, no
  interval leaving out a tie. Technique against the sets was won where v3 won
  it, the river (2 of 2, "an arch bridge over stepped trans water, a palm built
  from layered parts") and The End (1 of 2, v3's 2), and nowhere else.
- **The evidence reached every session.** Every one was shown a picture of
  its plan's real ones, 1 to 3 sheets. The shape rule sent one plan back (the
  sheep, twice: its "head and legs" were of a kind 5 of 8 real ones shape on
  joints), and the sheep then led with hinged. Ten sessions were sent back 21
  times for a sub-assembly not built as planned (v3's 20).
- **Laid, and taken back off.** The legs or boom entry was given to four plans
  (the sheep, the wolf, the Telehandler, Shelob); four sessions submitted a
  pattern (the wolf, the Telehandler, Shelob, and the scorpion from
  submit_design's own list). Two kept it to the end. The wolf laid upright legs,
  looked, and rebuilt: "The legs pattern gave a spidery sprawl — not a wolf",
  ending on stacked posts ("a boxy table-like body on straight posts"). The
  Telehandler built on a 22-stud boom raised 5 degrees, then made its own
  "boom and fork carriage as one hinged section". The sheep checked its legs
  alone, laid a plate up with nothing under them, read "floating (47)" and
  built by hand.
- **Kept, not counted.** Shelob kept 40 ball-joint parts (16% of its parts
  on joints, v3's 12%, the set's 40%) and lost technique both ways: "simple hinged
  plate chains", "clip-hinge legs are repetitive". The scorpion kept 29: "its
  scorpion is a basic flat build", beside a stacked pyramid. As in the
  builtbodies round: a pattern's plain plates on balls are joints the judge
  does not read as technique.

**The proof half,** run once on the same code, the tune half's loss
notwithstanding (the time box held no second tune round and a proof), against
main's designs (`t2base`, `7299b56`) in the same harness.

| dimension | main preferred to the set | t3lay preferred to the set | main minus t3lay, paired (95%) | t3lay preferred to main, head to head (95%) |
|---|---|---|---|---|
| likeness | 25% (8-56) | 40% (17-69) | -15 (-45, +10) | 40% (17-69) |
| surface | 25% (8-56) | 30% (11-60) | -5 (-35, +20) | 35% (14-65) |
| colour | 20% (6-51) | 25% (8-56) | -5 (-20, +10) | 70% (40-89) |
| technique | 0% (0-28) | 20% (6-51) | -20 (-40, 0) | 65% (35-86) |
| creativity | 25% (8-56) | 35% (14-65) | -10 (-35, +10) | 70% (40-89) |
| overall | 20% (6-51) | 30% (11-60) | -10 (-30, 0) | 60% (31-83) |

And against v3's proof designs, judged the same way: technique 10% to 20%,
paired -10 (-35, +10), head to head 50% (24-76); overall 20% to 30%, head to
head 60% (31-83); surface 40% to 30%.

- **Technique against the sets did not move beyond noise:** 4 verdicts of 20
  against main's none, the paired interval reaching zero, as v3's did (2 of 20).
  Head to head with main the judge leaned to it on technique, 65%, and on
  likeness and surface leaned to main. Against the sets nothing fell. Not
  shipped.
- **Where it won technique:** Emma's studio both ways, where the shape rule
  sent the clothes rack back ("71% of the real ones of its kind are shaped on
  joints or at an angle") and the session hung "clothes on a bar-and-clip rail
  between column posts"; the bee one way, its antennae sent back to lead with
  hinged, winning on "wings at an angle on clips and hinges"; the Container Stacker one way, on
  the boom pattern it kept, "a Technic liftarm boom braced by an angled strut".
  Main won technique on none of the three; v3 on the bee.
- **The why let the stack through.** The Container Yard's plan was sent back
  once and came again stacked throughout, each with a why: "beams pinned on the
  side come in the detail pass". They did not; the set's "rack-driven telescopic
  boom" won. No proof plan named legs on joints: the sphinx planned its paws
  curved, the dinosaur hinged and curved, and neither was given the legs entry.

**What they are made of** (medians, ours against the sets; floating 0% median
on both halves, every t3lay design audited):

| | shapes per 100 parts | SNOT | joints | 1 x 1 | tiles |
|---|---|---|---|---|---|
| tune, v3 | 23.4 | 12% | 1% | 29% | 22% |
| tune, t3lay | 19 | 14% | 2% | 35% | 21% |
| tune, the sets | 29.2 | 35% | 7% | 19% | 7% |
| proof, main | 15.4 | 2% | 0% | 29% | 16% |
| proof, v3 | 17.6 | 12% | 0% | 25% | 20% |
| proof, t3lay | 17.2 | 12% | 1% | 30% | 21% |
| proof, the sets | 28.4 | 25% | 3% | 13% | 11% |

Joints rose a point on both halves and SNOT held v3's gain; shapes per 100 fell
on the tune half, and 1 x 1 rose on both.

**What it says.**
- *A picture of the right kind moves a plan; it does not move the build much.*
  Every session saw its plan's real ones drawn, and where the kind is shaped on
  joints the plan was answered so (the clothes rack, the antennae, the sheep).
  Where the way was one small joint in a sub-assembly (a rail of clips, an
  antenna on a hinge) it was built and the judge counted it. Where it was a
  body (legs, a boom) the session laid the app's pattern and either took it back
  off on sight, or kept it and the judge read plain plates on balls.
- *The patterns are the weak part, as builtbodies found.* Two rounds now: a
  pattern's joints are the right joints and the wrong silhouette. A wolf's legs
  on a 2-segment upright chain read "spidery"; a spider's 4-segment chains read
  "repetitive". The sets' legs are shaped parts (claws, tooth plates, curved
  slopes) on two or three joints at different angles.
- *Finish ways held to shares buy nothing the judge sees.* The plan check sent
  the wolf back three times for its body's slope and side-stud shares, the
  Telehandler for its chassis's side studs and its bonnet's slopes; neither
  verdict named them. Holding a plan to its shape ways (hinged, angled) and
  leaving the finish to the session would keep what the plan is for.
- *Next.* Lay the real one pictured, not a generic pattern: place_technique of
  the nearest real sub-assembly of the kind, at its size, where the plan is
  answered on joints, so the joints come dressed as a set's are; check a plan
  only on its shape ways; and a why for stacked where the kind is shaped needs
  the part that says it ("a flat base"), not a promise of a later pass.

Results: `bench/results/realset-2026-10-19-t3lay/` (both halves),
`realset-2026-10-19-t2plan3-vs-t3lay/` (head to head with v3, both halves),
`realset-2026-10-19-t2base-vs-t3lay/` (with main, proof), and the sessions'
digests, the stopped first version and an example picture in
`technique3-2026-10-19/`.

### The planned way laid, on the 44 of proof (2026-10-20, not ready)

Ten proof subjects leaned every way toward the planned way laid (technique
none to 4 of 20, overall 20% to 30%) and could not resolve it. The 34 subjects
the halves grew by had never been seen by any lever, so this is its proof,
run once.

**The arm** (`t3lay44`): the lever unchanged (`aad64d3`'s src/ai, its three
probes passing on the merge: build_plan 30, legs 112, boom 135), merged with
realset2 (`ea06f75`) so main's code and the test's are what main's 44 ran on.
The 34 new subjects are this run's designs; the first ten are t3lay's, copied
in as realset2 copied t2base's into main's. One design a subject on the
subscription, drawn on the GPU, two at a time, started bare.

**Ready means** technique against the sets moves beyond noise on the 44 (the
paired interval against main's leaves zero), and likeness, surface and
overall do not fall beyond noise.

**It did not move technique.** All 44, against main's 44 (`realset-2026-10-19-main`):

| dimension | main preferred to the set | t3lay44 preferred to the set | t3lay44 minus main, paired (95%) | t3lay44 preferred to main, head to head (95%) |
|---|---|---|---|---|
| likeness | 22% (12-36) | 25% (15-39) | +3 (-7, +15) | 47% (33-61) |
| surface | 26% (15-41) | 26% (15-41) | +0 (-9, +9) | 48% (34-62) |
| colour | 26% (15-41) | 23% (13-37) | -3 (-14, +7) | 48% (34-62) |
| technique | 12% (6-25) | 15% (7-28) | +2 (-3, +9) | 58% (43-71) |
| creativity | 35% (23-50) | 35% (23-50) | +0 (-14, +12) | 55% (40-68) |
| overall | 20% (11-35) | 22% (12-36) | +1 (-7, +10) | 55% (40-68) |

The first ten were the whole of the lean. Split:

| dimension | the first ten, t3lay minus main | the 34 new, t3lay44 minus main | the 34 new against the set: main, t3lay44 |
|---|---|---|---|
| likeness | +15 (-10, +45) | +0 (-12, +12) | 21%, 21% |
| surface | +5 (-20, +35) | -1 (-9, +6) | 26%, 25% |
| colour | +5 (-10, +20) | -6 (-18, +6) | 28%, 22% |
| technique | +20 (0, +40) | -3 (-7, 0) | 16%, 13% |
| creativity | +10 (-10, +35) | -3 (-18, +12) | 38%, 35% |
| overall | +10 (0, +30) | -1 (-12, +9) | 21%, 19% |

- **Technique's interval holds zero** on the 44, (-3, +9): not ready. Nothing
  fell beyond noise either: likeness, surface and overall are within 3 points
  of main's. Head to head the judge leaned to the lever on technique (58%) and
  overall (55%), every interval holding a tie; on the 34 new alone 56% and 53%.
- **On the 34 new it won technique against the set on no subject main did
  not.** Both arms' technique verdicts there came from the same five subjects:
  the two Promotional sets, two Architecture, one Minecraft, won alike by
  both. Main also took half of a City set and of another Architecture set that
  the lever did not. The subject decides technique against the set, not the
  arm.
- **The first ten's three wins were three subjects** where a planned part is a
  kind the sets shape on joints (a clothes rack, a bee's wings, a container
  stacker's boom), each sent back to its joints or laid by the pattern. The new 34 are mostly
  buildings (14 Architecture) and vehicles (8 Technic): little of either is
  legs or a boom.

**The lever reached every session; its laying part almost none.** Over the 34
new sessions (their transcripts, counted, not read for lessons): every one was
shown its plan's real ones, 43 sheets; the shape rule sent 24 sub-assemblies
back, in 16 sessions, to lead with hinged or angled. The boom entry went to one
plan, a Technic one, the legs entry to none, and no session submitted a
pattern.

**What they are made of** (medians over the 44, tools/style.py; SNOT and joints
also as means; floating by the build check, every design and set audited, a
median 0%):

| | parts | shapes per 100 | shaped | 1 x 1 | colours | tiles | SNOT (mean) | joints (mean) |
|---|---|---|---|---|---|---|---|---|
| main | 288 | 14 | 27% | 27% | 10 | 16% | 4% (7%) | 0% (0.6%) |
| t3lay44 | 311 | 12.9 | 23% | 29% | 11 | 20% | 12% (12%) | 0% (0.8%) |
| the sets | 344 | 16.6 | 25% | 17% | 13 | 11% | 27% (34%) | 4% (6.4%) |

SNOT held v3's gain (three times main's median), tiles rose 4 points, shaped
parts fell 4 and joints stayed where main's are (a joint part in 20 designs
of 44, main's 21). The judge did not count the SNOT as technique.

**What it says.**
- *Ten subjects gave a lean the next 34 did not repeat.* The proof's first ten
  had three subjects of the one kind this lever is for; 34 more had almost none.
  At 44 the lever is worth at most about 9 points of technique against the
  sets, and probably none.
- *The lever acts only where a sub-assembly is of a kind shaped on joints,*
  and that is a few subjects in ten. The plan sheets and the shape rule reached
  all 34, and the designs' joints came out as main's did.
- *It costs time.* Sessions on the 34 took 13 minutes at the median (main's
  11), up to 25 (main's 36).

Two at a time on the subscription, each design taking the GPU for itself, the
34 designs took 4 h 55 min (01:38 to 06:33), nine minutes a subject; the build
check and the 68 new head-to-head verdicts (the first ten's are t2base-vs-t3lay's,
copied) another 11 minutes.

Results: `bench/results/realset-2026-10-20-t3lay44/` (report-proof.md;
arm.json says which designs are t3lay's), `realset-2026-10-20-main-vs-t3lay44/`
(head to head), and the split, the reach count and their scripts in
`t3proof-2026-10-20/`.

### Why the sets win, from the verdicts (2026-10-20)

Three technique levers in a row (technique2, technique3, and technique3 on
the 44, t3lay44) did not move the judge; the last tripled SNOT and won no extra verdicts. They were
chosen from what the designs are made of. This reads what the judge says the
sets win on, before anyone builds another.

**What was read.** Every design-against-its-set verdict on disk: 260 designs
(a copy counted once: main's first ten are t2base's, t3lay44's are t3lay's),
520 verdicts, 3,120 dimension verdicts, 2,408 of them the set's. Main's 44 on
proof are 528, 403 the set's. Each reason was coded against a fixed codebook
of 20 classes, not told which side was the set: every class the reason names
as deciding, and the one that carries it (its primary). The coding was done by
eight subagents, before AGENT_RULES said never to spawn them; I coded 50 drawn
at random myself. Of the classes they named, 94% were mine; of mine they found
90%; the primary matched on 39 of 50, the misses mostly between "reads as this
subject" and "a signature feature", which are counted together below.

**1. What decides the overall verdict: whether it reads as the subject.**
The classes grouped, and the primary of each verdict the set won:

| family of the set's win | overall, main's 44 | overall, every round | overall, tune half | likeness, main's 44 | likeness, every round |
|---|---|---|---|---|---|
| reads as the subject: this subject not a generic one, its signature features, its silhouette and proportion | 41 of 70 (59%) | 251 of 415 (60%) | 119 of 160 (74%) | 57 of 69 (83%) | 330 of 402 (82%) |
| the line's own way: Technic built studless, BrickHeadz's formula, Friends' mini-dolls and print | 21 (30%) | 146 (35%) | 39 (24%) | 12 (17%) | 70 (17%) |
| play and story | 4 (6%) | 6 (1%) | 0 | 0 | 0 |
| surface, colour and detail, technique | 2 (3%) | 6 (1%) | 0 | 0 | 0 |
| it hangs together | 2 (3%) | 6 (1%) | 2 (1%) | 0 | 2 (0%) |

- **Overall follows likeness.** It names the same model as likeness in 93% of
  the 520 verdicts (97% of main's 88), technique in 87%, colour 85%, surface
  76%, creativity 73%. Where likeness and technique disagree (89 verdicts),
  overall goes with likeness 62 times; where likeness and surface disagree
  (117), 104 times.
- **Surface, colour and technique never carry overall:** 6 of the set's 415
  overall wins between them. They are named in its reasons as support ("with
  better shaping"), and decide only their own column. A technique lever can win
  the technique column and leave overall where it was, which is what the last
  three did.
- **What we win on is the same thing.** Of our 18 overall wins on main's 44,
  11 are ours reading truer (Big Ben's slender shaft and belfry, Sungnyemun's
  hipped roofs, the Flatiron's window grid) and 7 are the set's own faults (the
  Bricktober sets' floating plane and car, the Level Crossing's excavator
  swamping the crossing).
- The tune half, which may be tuned on, says the same and more so: 74% of the
  set's overall wins and 96% of its likeness wins are this family.

**2. What the reasons name**, per dimension: the set's 403 wins on main's 44,
how often the same class appears in our 125 wins, and over every round how
often the set won when the class was named (it won 77% of all).

| what the reason names | likeness | surface | colour | technique | creativity | overall | of the set's 403 | of our 125 | every round: set won when named |
|---|---|---|---|---|---|---|---|---|---|
| reads as this subject, not a generic one | 54 |  |  |  |  | 45 | 99 (25%) | 22 (18%) | 79% of 793 |
| a signature feature of the subject | 60 |  |  |  | 3 | 21 | 84 (21%) | 22 (18%) | 78% of 628 |
| silhouette and proportion | 37 |  |  |  |  | 9 | 46 (11%) | 12 (10%) | 85% of 372 |
| the line's own way | 17 |  | 5 | 18 | 1 | 33 | 74 (18%) | 3 (2%) | 90% of 574 |
| the right figures (mini-dolls, characters) | 9 |  |  |  | 12 | 9 | 30 (7%) | 11 (9%) | 81% of 279 |
| exposed studs, bare baseplate |  | 54 |  |  |  | 10 | 64 (16%) | 25 (20%) | 72% of 528 |
| a staircase where a curve should be | 1 | 51 |  |  |  | 9 | 61 (15%) | 10 (8%) | 88% of 336 |
| curves, slopes and panels shaping the form |  | 56 |  | 16 |  | 7 | 79 (20%) | 21 (17%) | 76% of 633 |
| a flat expanse of one colour |  |  | 59 |  |  | 3 | 62 (15%) | 18 (14%) | 78% of 516 |
| the subject's colours and accents |  |  | 65 |  |  | 18 | 83 (21%) | 34 (27%) | 75% of 704 |
| printed parts, nameplates |  | 1 | 23 | 1 | 15 | 6 | 46 (11%) | 23 (18%) | 81% of 502 |
| fine detail, texture |  | 4 | 15 | 2 |  | 12 | 33 (8%) | 16 (13%) | 81% of 194 |
| "mostly stacked bricks" |  | 11 |  | 71 |  | 5 | 87 (22%) | 7 (6%) | 94% of 526 |
| SNOT |  |  |  | 19 |  |  | 19 (5%) | 5 (4%) | 85% of 237 |
| angled sub-assemblies, hinges, clips |  |  |  | 57 | 1 | 3 | 61 (15%) | 4 (3%) | 94% of 409 |
| Technic construction and mechanisms |  |  |  | 26 | 5 | 12 | 43 (11%) | 0 | 98% of 177 |
| play features that work |  |  |  | 1 | 21 | 12 | 34 (8%) | 7 (6%) | 94% of 250 |
| story props and accessories |  |  |  |  | 50 | 13 | 63 (16%) | 32 (26%) | 69% of 587 |
| a setting around it | 4 |  |  |  | 10 | 3 | 17 (4%) | 14 (11%) | 44% of 184 |
| it hangs together: nothing floats, collides or muddles | 7 | 3 |  | 8 | 3 | 6 | 27 (7%) | 41 (33%) | 32% of 290 |

- **Named almost only against us:** Technic construction (98%), angled
  sub-assemblies and "mostly stacked bricks" (94% each), working play features
  (94%), the line's own way (90%), a staircase where a curve should be (88%).
- **Named about as often for us:** exposed studs, the subject's colours, story
  props, a signature feature. The judge weighs them both ways: we lose them as
  often as we win them, so they are not where the gap is.
- **Named for us:** coherence and a setting. Our designs hang together; the
  sets that lose to them are the messy ones.

**By theme**, main's 44: what our designs won overall, and the primary of the
set's overall wins.

| theme | subjects | the set's wins, all dimensions | ours overall | the set's overall wins, by primary |
|---|---|---|---|---|
| Architecture | 15 | 130 of 180 | 6 of 30 | reads as the subject 23 of 24, story 1 |
| Technic | 9 | 102 of 108 | 0 of 18 | the line's own way 13, reads as the subject 5 |
| City | 5 | 45 of 60 | 3 of 10 | reads as the subject 5, it hangs together 2 |
| Friends | 3 | 32 of 36 | 1 of 6 | the line's own way 2, story 2, reads as the subject 1 |
| BrickHeadz | 3 | 23 of 36 | 2 of 6 | the line's own way 2, curves shaping the form 2 |
| Promotional, Minecraft | 3 | 4 of 36 | 6 of 6 | none |
| LOTR | 2 | 22 of 24 | 0 of 4 | reads as the subject 3, story 1 |
| Elves, Adventurers | 2 | 23 of 24 | 0 of 4 | the line's own way 4 |
| Creator, Pharaoh's Quest | 2 | 22 of 24 | 0 of 4 | reads as the subject 4 |

**Three reasons a class**, quoted from main's 44 (the set's side named; every
one a verdict the set won but the last two).

- *Reads as this subject.* Great Wall of China, overall (set B): "B looks like
  a LEGO Architecture Great Wall, with a tan wall winding up a mountain, while A
  looks like a grey castle wall." Imperial Hotel, overall (B): "B reads clearly
  as Wright's Imperial Hotel in true Architecture-line style, while A is a tidy
  but generic green-roofed building." Dune Hopper, overall (B): "B looks like a
  Creator dune buggy, with curved bodywork and a Technic rear end, while A
  reads as a generic blocky off-road truck."
- *A signature feature.* Trevi Fountain, overall (A): "A captures the Trevi's
  signature curved basin, rock base and triumphal-arch centre with better
  shaping, which matters more for this subject than B's nicer surface
  details." Sydney, likeness (B): "an Opera House with clustered pointed white
  sails, and a through-arch bridge with hangers. A's solid grey arch, flat
  white blocks for the Opera House and squat towers read only loosely as
  Sydney." Single-Drum Roller, likeness (A): "A's large exposed grey drum, held
  in a yellow yoke ... reads at once as a single-drum roller, while B hides its
  drum under a boxy body ... and looks more like a forklift or tractor."
- *Silhouette and proportion.* Burj Khalifa, overall (B): "For an Architecture
  set the tower's silhouette matters most, and B's tapering, spiralling form is
  unmistakably the Burj Khalifa." Guggenheim, overall (B): "it has the right
  inverted-spiral silhouette ... while A's dome looks more like a generic white
  building." Corvette ZR1, likeness (A): "A has the ZR1's low wedge nose,
  bulging fenders, big wheels ... while B is a long, flat, slab-sided bar with
  tiny wheels that looks more like a limo than a Corvette."
- *The line's own way.* Record Breaker, overall (A): "A looks like a finished,
  shippable Technic Record Breaker, while B looks like a blocky System-style
  mock-up of one." Steve & Creeper, overall (B): "B delivers the BrickHeadz
  format the brief asks for ... A is a tidier Minecraft model but does not read
  as a BrickHeadz pair." Naida's Spa Secret, overall (B): "B looks like a real
  LEGO Elves spa set with colour, play features and story details, while A is a
  plain garden gazebo."
- *The right figures.* Mia's Bedroom, likeness (A): "a mini-doll Mia ... B's
  classic minifig and its generic furniture make it look less like a Friends
  set." Heartlake Stables, overall (B): "an on-brand Friends stable with
  mini-dolls ... while A is a generic white house and paddock with off-theme
  minifigures." Uruk-hai Army, likeness (A): "Uruk-hai in the right helmets
  facing a mounted Rohan rider, while B is a generic grey castle wall with ...
  classic yellow-faced defenders."
- *Exposed studs.* Emma's Fashion Design Studio, surface (B): "A shows a large
  field of bare baseplate studs and blocky stacked-brick furniture." Trafalgar
  Square, surface (A): "B shows exposed studs on its roofs and plaza and builds
  its portico from stacked boxy bricks." WHACK!, surface (A): "A's body is
  studless Technic panels and beams ... while most of B's top is an open field
  of studded green plate."
- *A staircase where a curve should be.* Dubai, surface (A): "B's sail is a
  stepped stack of white bricks, a staircase where a curve should be."
  Heartlake Stables, surface (A): "B's magenta roof and white gables are stepped
  staircases of bricks with studs showing." Volvo ZEUX, surface (B): "B's bucket
  is one smooth, curved shell ... while A's bucket is a stepped staircase of
  plates and bricks."
- *Curves shaping the form.* Dune Hopper, surface (B): "B's sides are made of
  sweeping curved red and white slopes, while A is mostly flat brick walls."
  Jack Skellington & Sally, surface (B): "curved slopes for Sally's hair and the
  round sides of Jack's skull ... A is all square bricks with stepped edges and
  no curves at all." Single-Drum Roller, surface (A): "a smooth round drum
  shell, curved fenders and a curved cab roof."
- *A flat expanse of one colour.* Imperial Hotel, colour (B): "A is dominated
  by flat expanses of sand-green roof." Dom's Dodge Charger, colour (B): "A is
  almost all flat black with only red tail lights and a tan window strip."
  Single-Drum Roller, colour (A): "B has large plain yellow areas with only a
  black-and-yellow hazard stripe for accent."
- *The subject's colours.* Great Wall, colour (B): "B uses tan with darker tan
  banding against the dark green hill, which is closer to the real wall's
  colour, while A is mostly flat light grey." Air Mail, colour (B): "a clear
  yellow, red and grey courier livery, with a red cheat line." Naida's Spa
  Secret, colour (B): "the Elves palette of dark purple, magenta, lavender,
  medium azure, reddish brown and trans-pink."
- *Printed parts.* Mia's Bedroom, colour (B): "printed parts (the 'Mia' drum
  head and the sheet music), while A spreads into flat expanses of mint wall
  and tan floor with almost no printed detail."
  Jack & Sally, colour (B): "printed detail (pinstripes, the bat bow tie,
  Sally's stitches, swirl patches)." Heartlake Stables, colour (B): "printed
  name plates, rosettes, butterflies and horseshoe tiles."
- *Fine detail.* Las Vegas, colour (A): "fine banding and window greebling."
  Emma's Fashion Design Studio, colour (A): "lots of small detail (printed
  sketches, ruler, brush, camera, laptop, flowers)." Volvo ZEUX, colour (A): "a
  lot of fine mechanical detail."
- *"Mostly stacked bricks".* Imperial Hotel, technique (A): "B relies mostly on
  stacked slopes and round-brick columns." Trafalgar Square, technique (B): "A
  is mostly stacked bricks with simple round-part stacks." Dino Explorer,
  technique (A): "B's dino is a simple stack of bricks with stuck-on slopes and
  almost no advanced technique."
- *SNOT.* Jack & Sally, technique (B): "B builds the faces sideways (SNOT),
  places curved hair pieces at angles and uses clip hands." Burj Khalifa,
  technique (B): "sideways-mounted (SNOT) cladding, offset setbacks at several
  heights and angled wedge wings at the base to get the three-lobed plan." Air
  Mail, technique (B): "side stripes built sideways (SNOT)."
- *Angled sub-assemblies.* Sydney, technique (B): "B builds the bridge arch
  from angled, hinged segments with bar hangers ... and angled sail
  sub-assemblies." Great Wall, technique (A): "A builds the wall as angled
  sub-assemblies that follow the ridge and bend around the tower." Gandalf
  Arrives, technique (B): "B hinges the cart sides out at an angle and uses
  bar-and-clip shafts to hitch the horse."
- *Technic construction.* Roadwork Crew, technique (B): "pinned studless beams,
  a boom on angled liftarms, gears and tracks, while A is plain stacked bricks
  with Technic bricks used only as decoration." Container Yard, technique (B):
  "a gear-rack boom, a lift arm and a spreader linkage ... the yellow Technic
  bricks on its gantry are a cosmetic touch, not a mechanism." Corvette ZR1,
  technique (B): "a beam frame, panels, a visible engine with pistons ... while
  A is a plain System brick build with no Technic at all."
- *Play features.* First Responder, creativity (A): "A's working winch with a
  hook, its steering knob and its rear equipment rack." Uruk-hai Army,
  creativity (A): "A's ballista that can fire, its collapsing wall rubble."
  Street Sweeper, creativity (A): "A's poseable vacuum hose with a disc nozzle,
  its pressure gauge on the tank and its bristle roller."
- *Story props.* Trafalgar Square, creativity (B): "B's egg on the Fourth Plinth
  is a witty easter egg." Gandalf Arrives, creativity (B): "the printed party
  invitation, the fireworks standing in a barrel, the carrot and Frodo holding a
  book." Naida's Spa Secret, creativity (A): "a hairbrush, perfume bottles, a
  bucket, a book, a map tile, a dolphin."
- *A setting.* Big Ben, creativity (B): "a wing of the Palace of Westminster
  with pinnacles, a patch of green lawn." Sungnyemun, creativity (B): "sloping
  city-wall wings and grass beds that give the gate a setting." Great Wall,
  creativity (B): "B's dramatic ridge line."
- *It hangs together.* Air Mail, overall (A): "A is a coherent, attractive
  City-style Air Mail plane ... while B is blocky and muddled." Ours won these
  two: Bricktober Hotel, overall (set B): "B has structural errors (a floating
  plane, a car intersecting the base)"; Level Crossing, overall (set A): "A is
  a vehicle parked on a sparse, poorly assembled crossing."

**3. What the judge rewards against what we measure.**
- *No measure of tools/style.py tracks likeness.* Within a subject, across the
  192 designs of the 20 subjects designed four times or more (each measure and
  each share less the subject's mean, intervals by resampling subjects), no
  measure's correlation with likeness reaches 0.1. SNOT goes with technique at
  +0.14 (+0.02, +0.24) and with overall at +0.01 (-0.06, +0.07); joint parts
  with technique at +0.20 (+0.01, +0.38) and overall at -0.09 (-0.20, +0.03).
  The one measure that goes with overall is the plain share, -0.17 (-0.32,
  -0.04). More SNOT than another design of the same subject buys a little
  technique and nothing else.
- *Half the SNOT gap is the Technic idiom.* style.py reads a Technic set as 79%
  SNOT at the median (its beams and pins lie on their side) and 1% plain; our
  Technic designs read 15% and 44%. Architecture's sets read 22% against our
  3%, BrickHeadz 44% against 1%. Main's median gap of -19 points was met with
  SNOT in System building, where the sets' gap is Technic's way of building.
- *What it leaves out:* minifigures, mini-dolls, animals and stickers, which
  the Friends, LOTR and Adventurers reasons turn on; whether a part is printed;
  and the model's shape at the whole model's scale, which is what likeness is.
- *What the levers aimed at:*

| lever | what it changed | the class it aimed at |
|---|---|---|
| armature, jointcheck, builtbodies (2026-10-16, 17) | figures and bodies on working joints | angled sub-assemblies |
| technique, bodies, the body's build shown (2026-10-16) | a square design sent back, bodies on their side | "mostly stacked", SNOT |
| technique2 (t2plan) | sub-assemblies planned from how real ones are built | "mostly stacked", SNOT, angled |
| technique3 (t3lay, t3lay44) | the planned joint laid by the app | angled sub-assemblies |
| faces, figfaces | faces and a lean in the figure pattern | a signature feature, for characters |
| the passes every session runs: surface, restyle, creative, feature | studs tiled, plain faces dressed, a creative touch, named features laid from real sets | exposed studs, fine detail, story, signature features (as details) |

  The technique family carries 0 of the set's 70 overall wins on main's 44.
  The two families that carry 62 of them, the subject's shape and the line's
  way, no lever aimed at, faces for characters apart; and the feature pass, the
  one meant for signature features, is spent on details (below).

**4. The pictures** of seven of the largest gaps (all twelve verdicts the
set's but the Burj's eight): each side's corner view, and its front where the
corner hid something, looked at as a set designer would.

- *Sydney.* Ours has the three landmarks and a printed "Sydney" tile, but each
  is the wrong shape. The Opera House is a low drift of white curved slopes on
  a tan podium: no shell rises above the podium and none points. The set makes
  each shell from white wedges leaning together at an angle, taller than the
  podium, three stepping down in a row. Our bridge is one grey 1 x 12 x 3 arch
  brick, a wall; the set's is black hinged segments with bar hangers and open
  sky under the arch, which is what a through-arch is. Our Sydney Tower is a
  thin grey rod; the set's is the tallest thing on the base, a black cone and
  shaft under a gold turret, and the composition leads with it.
- *Single-Drum Roller.* Ours is a yellow box under a canopy on four posts, its
  drum a grey cylinder tucked under the front with a few studs of it showing.
  The set's drum is its biggest element, a third of its length, out in front in
  a yoke on a spoked hub. A roller is its drum.
- *Rise of the Sphinx.* Ours lays its 505 parts over a 32 x 48 tan baseplate:
  courtyard walls, columns, palms, and in the middle a tan lump a few bricks
  high for the sphinx. The set is the sphinx: a black jackal head with tall ears,
  angled jaws, paws forward, a gate between them, and a car and three figures
  round it. The brief's 26 x 52 is the set's bounding box with its car; ours
  took it as a plot to fill.
- *Dom's Dodge Charger.* Ours is a black System-brick slab with a box hanging
  below the sills between the wheels, a strip of grille tiles and a two-pot
  blower. The set is a studless shell of Technic panels: the full-width chrome
  grille, round fender ends, the blower and engine open to see. Shape and idiom
  fail together.
- *Heartlake Stables.* Ours is a tidy Friends-coloured scene, of a cottage: a
  white house under a magenta staircase roof, a paddock and classic minifigures
  on a green baseplate. A stable is a tan barn under a dark red roof with an
  arch and stalls with half doors; a Friends set is mini-dolls, printed name
  plates and modular plates, not a baseplate.
- *Jack Skellington & Sally.* Ours is pixel art in bricks: square heads, eyes of
  black bricks, Sally's hair a red box. BrickHeadz is one armature for every
  character: the face built sideways, 2 x 2 round eye tiles, a printed mouth,
  curved slopes for the back of the head and the hair, arms on clips. The set's
  Jack has the curved back of a skull; ours is a cube.
- *Burj Khalifa*, the closest. Ours rises in three equal square tiers. The real
  tower's lobes stop at different heights round a spiral, so its taper is
  continuous, and the set gets that with staggered setbacks and smooth panel
  cladding. Ours is clad in grille texture, which the judge called busy.

**What our designs lack is the defining shape, made first and made true at the
whole model's scale:** the sails, the drum, the sphinx, the taper, the wedge,
the barn. They get the subject right by name and decorate a generic mass.

The logs say how. 42 of the 44 sessions ran the feature pass, and the features
were the session's own choice: 130 over 42 sessions, 62 of them details by name (a
nameplate in 10 sessions; headlights, tail lights, beacons, exhausts,
windscreens, signs, lettering). The Guggenheim's were its lettering, skylight
and nameplate, where it lost on a rotunda that should widen upward; the Burj's
its spire and nameplate; the roller's its headlights, rear grille, exhaust,
steering wheel and drum hub, never the drum; the Corvette's six were lights,
intakes, arches and a wing, where it lost on a stretched slab. Where we won,
the features were the defining shapes: Big Ben's clock faces, belfry arcade and
lantern; Sungnyemun's gate tunnel and upturned eaves; the Flatiron's rounded
prow and cornice; the Level Crossing's barrier arms. 101 times a feature was
settled as "built by the design", the session judging its own. Half the
sessions (23 of 44) never asked for a picture of the real thing
(`find_reference`), and the sketch step, three cheap massings before the design, was tried by one (the
Great Wall's, refused at 235 parts of the 150 a sketch may have, and not tried
again).

**Not recognition.** The three views of each design and of each set, one model
at a time under a hashed name, were shown to a blind reader (eight subagents, before the rule) and
asked only what it is. It named 30 of our 44 as the subject and 42 as the right
kind of thing, every Architecture design among them; it named 42 of the sets,
14 of them by set number. Our Architecture designs lose 24 of 30 overall
verdicts while each is named at a glance: the gap is that side by side the
set's defining shape is truer, not that ours cannot be told. A "what is this?"
check would pass most of our losers. Six designs did build the brief's words
rather than its set (WHACK! as a whack-a-mole, Container Yard as a gantry yard,
Roadwork Crew as a truck carrying a roller, First Responder as a fire van, Dino
Explorer as an explorer photographing a dinosaur, Rise of the Sphinx as a
temple courtyard), and the blind reader read them the same way: a product's
name is a smaller class of its own.

**5. The next lever: the defining shape first.** The one class that would win
the most verdicts is the subject's shape: primary in 41 of the set's 70 overall
wins and 57 of its 69 likeness wins on main's 44, over 23 subjects in seven
themes, and 60% and 82% over every round. The line's way is second (21 overall
wins, 12 subjects, 7 of them Technic).

- *What a session does.* Before any brick it names the subject's defining
  shapes: the one to three forms by which a person tells this subject from
  others of its kind at a glance, each at the whole model's scale, with its
  geometry (tapers in staggered setbacks, widens upward, pointed shells, an
  exposed drum a third of the length, a low wide wedge), its share of the model
  and where it sits. A nameplate, lights, a sign or a print is not one. Where
  the subject is a product's name, it says first what the product is. Its first
  build is those shapes alone, as a massing; details come after.
- *How it is made to.* At the planning stage, in the answer of
  `how_real_sets_build_this`, which 42 of the 44 sessions called first (the
  other two asked for a picture first): it asks for the defining shapes before
  anything else. They are held in `submit_design`'s features, which must lead
  with them; a list that leads with a detail is sent back with the one line
  why, in the tool's result, as technique3's shape rule sent plans back (24
  sub-assemblies in 16 sessions: send-backs reach sessions). The massing is
  laid with the calls that already lay a form in a set builder's parts
  (shapes.gd's lofts and revolves, rounds, shells), through the sketch step
  that exists and is not used: words alone moved nothing six times (shapes.gd's
  header). Then in `look_at_model`'s result, after the massing: its front, side
  and top beside the reference picture, which the app fetches itself where the
  session has not, and for each defining shape the judge's own question: is it
  there, at its size, from every view? Only then the detail passes.
- *How to measure it on the 44.* The arm on proof's 44, paired against main's
  44 designs, which stand (`realset.py compare`; 44 designs, 6.5 to 9 hours at
  two workers as the halves' section counts, and the compare). Ready if likeness's paired interval leaves
  zero and overall does not fall; a quarter of the 57 likeness losses and 41
  overall losses turned would be about +16 points on likeness and +12 on
  overall, at the edge of what 44 resolves (10.5 either way on overall).
  Then the codebook again on the arm's verdicts: the share of the set's
  likeness and overall wins whose primary is the subject's shape should fall
  from 83% and 59%, and the line's way should not move (the lever does not
  touch Technic; if it moved, something else did). From the logs: sessions
  whose first features are defining shapes, the massing taken (now none of
  44), the reference seen (now 21 of 44).
- *Proof has been read.* This read the 34 new proof subjects' reasons and
  pictures, which the halves' rule keeps unread until a lever runs. The lever
  is chosen at the level of a class over 260 designs and the tune half says it
  more strongly, and nothing in it may name a proof subject or use one as its
  example. For a check nobody has seen, tune's 34 new subjects have never been
  designed or judged: if proof's result is close, run main and the lever there
  (68 designs, about 12 hours).
- *Then the line's way, for Technic.* Technic is 9 of proof's 44 (and 8 of
  tune's), lost 102 of its 108 verdicts, and 13 of its 18 overall verdicts on
  "System bricks, not Technic". Its means is a call that lays a studless frame
  of beams, pins and panels with one working function, as shapes.gd lays a
  solid: a bigger build than the first lever, and the measure for it is
  Technic's subjects alone. BrickHeadz's armature as a pattern, and mini-dolls
  for Friends, are the small ones.

Everything is in `bench/results/verdicts-2026-10-20/`: the flattened verdicts
(rows.jsonl, designs.jsonl, from extract.py), the codebook (CODEBOOK.md) and
its codes (labels.jsonl; the 50 checked by hand in mine50.txt against
sample50.txt), the blind reader's answers and key (blind_answers/,
blind_key.json), the features the sessions worked (features.txt), and the
scripts that make each table (families.py, doc_tables.py, measures.py,
persubject.py, quotes.py).



### The defining shape first, on the 44 of proof (2026-10-20, not ready)

The verdicts said the set wins overall on whether a model reads as its subject,
by its shape at the whole model's scale, and that our sessions named the
subject right and decorated a generic mass. This lever had a session name that
shape before any brick, build it first and see it measured beside the real
thing. Likeness against the sets went from 22% to 25%, a paired +3 (-7, +14)
that holds zero; overall did not move; head to head the judge preferred main's
designs. It is on the branch `shapefirst`, not on main.

**The lever** (`src/ai/defining_shapes.gd`, `defining_shapes_probe`).
- *Asked at planning.* how_real_sets_build_this, the first call of nearly every
  session, leads with the ask: the one to three whole-model shapes a person tells
  the subject by at a glance, each with its geometry, its share of the model's
  outline and its box. The examples are general (a lighthouse's taper, a
  tortoise's dome, a crane's jib), never a subject of either half. A nameplate,
  lights, a sign, a print, a grille or a door is named as a detail, never one.
- *Held at submission.* The shapes lead submit_design's features, each with
  `shape`, `share` and its box. A session on a brief whose features start with a
  detail is sent back, twice at most. A first build with more than half its
  parts outside its shapes' boxes is the whole model, not the shapes, and is sent
  back once. The shapes are left out of the feature pass, which works the
  details.
- *Measured and shown.* Each build's answer measures each shape in its box: its
  parts and size, its share of the outline against the share said, its width at
  foot, middle and top, whether it is a box from every view, the base it stands
  on left out. It says what is not as said ("it does not taper", "nothing of it
  is round", "smaller than you said"), with the model from the front, the side
  and above beside the first reference picture, which the app looks up once
  where the session has not. look_at_model does the same once the model has
  changed, and the whole review leads with any shape not yet as said.

**Tuning, on tune's first ten** against t2base's designs (main's code), one
design a subject, each version read in its transcripts. Verdicts won of 2 a
subject, likeness to overall:
- *v1* (`cea3cfb7`, the ask and the send-back): both sessions led with their
  shapes, the sheep's a "chunky rounded block of bumpy fleece", and built the
  whole model at once. The measure only said what they had built. Stopped after
  two.
- *v2* (`de61219d`, the massing sent back, the share weighed): on nine subjects
  3 4 7 2 3 4 verdicts, t2base's 5 6 6 2 4 3 on the same nine. Tokyo's session
  named its towers "tapering from four splayed legs", built straight columns,
  looked at them beside its photographs and called the massing right; the judge
  called them "straight-sided stacked columns".
- *v3* (`fa19fbd3` to `aaaf1613`, the geometry read off the outline): on seven
  subjects 4 5 4 2 5 1, t2base's 3 5 4 2 4 1. Tokyo's base had been read as each
  tower's foot (fixed: a part reaching past a box on both sides is no part of
  it), and its Skytree, said to be all of the model for being the tallest thing
  in it, was told it was smaller than said and dwarfed the skyline ("a plain
  white column that dwarfs everything"; fixed: share is of the outline, and a
  shape said to be most of the model is held to its geometry alone).

**The proof half,** run once on `5b4adaa3`: the lever merged with main's
gpulease, so the app runs headless and each picture is drawn on the lease; src/ai
otherwise main's 44's. Against main's 44 standing designs
(`realset-2026-10-19-main`), in the same harness, started bare.

| dimension | main preferred to the set | the lever preferred to the set | the lever minus main, paired (95%) | the lever preferred to main, head to head (95%) |
|---|---|---|---|---|
| likeness | 22% (12-36) | 25% (15-39) | +3 (-7, +14) | 42% (29-57) |
| surface | 26% (15-41) | 33% (21-48) | +7 (-5, +18) | 38% (25-52) |
| colour | 26% (15-41) | 19% (10-33) | -7 (-18, +5) | 40% (27-54) |
| technique | 12% (6-25) | 8% (3-20) | -5 (-10, 0) | 47% (33-61) |
| creativity | 35% (23-50) | 25% (15-39) | -10 (-22, +1) | 35% (23-50) |
| overall | 20% (11-35) | 19% (10-33) | -1 (-10, +9) | 39% (26-53) |

- **Likeness's interval holds zero:** not ready. Overall against the sets is
  where main's is. Head to head the judge preferred main's designs on every
  dimension, creativity at the edge of noise (65%, 50-77) and overall 61%
  (47-74). Technique against the sets fell 5 points, its interval reaching
  zero.
- **Where likeness moved, both ways.** Gained: Mia's Bedroom (+2), the Trevi
  Fountain (+1, overall +2), Steve & Creeper (+1, overall +2), Las Vegas, the
  Bricktober Town Hall, Rise of the Sphinx, the Container Stacker and the Uruk-hai
  Army (+1 each). Lost: Big Ben and the Flatiron (-2 each, overall -2 each), two
  of main's wins on reading truer, and Chicago and Emma's studio (-1 each). Net
  3 verdicts of 88.
- **The shapes were named and built, and still lost on the same shape.** The
  Sydney sails, the roller's drum ("a treaded tyre for the drum"), the Burj's
  taper ("a squat, wide wedding-cake of rectangular steps"), the Guggenheim's
  rotunda ("capped by a square slab"), the Charger's and the Corvette's bodies
  ("a boxy, slab-sided yellow brick car"). Naming the shape and measuring it did
  not give the session the means to build it.
- **Reach** (each proof transcript counted, not read for lessons,
  `shapefirst-2026-10-20/reach.py`): all 44 sessions led their first features
  with defining shapes; 3 were sent back for starting with a detail and 2 first
  builds for being the whole model; 21 looked the real thing up themselves
  (main: 21 of 44 saw a reference) and 34 were shown it beside their model; 18
  were told a shape was not as said.
- *What it cost.* Sessions took 14.8 minutes at the median (main's 10.7), the
  BMW out to its 45-minute timeout with its model saved. 9 pictures over 5
  designs were the letters for want of a drawer in time. The build check read
  every design and set: a median 0% floating, as main's. The run was SIGTERMed at
  12:57 with 16 recorded, with every other process on the box older than a few
  minutes; it was started again at four workers and the other 28 took 3 hours.

**Re-coded with the verdicts' codebook** (`verdicts-2026-10-20/CODEBOOK.md`): the
lever's 528 dimension verdicts coded by hand, not told which side was the set.
Main's are the verdicts round's codes; to take the coder out, main's 176 likeness
and overall verdicts were coded again by the same hand (the same family as the
verdicts round's primary in 158, the same class in 134).

| primary of the set's wins | main, verdicts' codes | main, this hand | the lever, this hand |
|---|---|---|---|
| overall: reads as the subject | 41 of 70 (59%) | 42 of 70 (60%) | 39 of 71 (55%) |
| overall: the line's way | 21 (30%) | 26 (37%) | 25 (35%) |
| likeness: reads as the subject | 57 of 69 (83%) | 61 of 69 (88%) | 57 of 66 (86%) |
| likeness: the line's way | 12 (17%) | 8 (12%) | 9 (14%) |

- **The shape's share of the set's wins did not fall beyond what a coder moves
  it:** 60% to 55% on overall, 88% to 86% on likeness, one hand. The sets win as
  often, and on the same thing.
- **Technic did not move:** 0 of 18 overall verdicts for either arm, the line's
  way the primary of 13 of main's 18 losses and 16 of the lever's.

**What it says.**
- *The ask reaches, the build does not follow.* Every session named its
  subject's shape in the judge's own words (the Skytree's taper, the Trevi's
  basin, the roller's drum) and led its build with it, and the measure told 18 of
  them a shape was not as said. The designs' shapes came out no truer. What a
  session can lay from memory, stacked bricks round a box, is the limit. Words
  alone moved nothing six times (shapes.gd's header); words with the shape
  measured and pictured beside the real thing did not either.
- *It costs the passes after it.* Four more minutes a session, spent on massing
  and rebuilding; creativity fell 10 points against the sets and 65% to 35%
  head to head, colour 7.
- *Next.* Lay the shape, not describe it: for a defining shape said to taper,
  widen, be round or point, a call that lays it in the box the session gave, as
  shapes.gd's lofts and revolves lay a hull, in a set builder's parts (setbacks of
  slopes and tiles for a taper, curved bricks and panels for a drum, wedges
  leaning together for a shell), checked by this measure. And the line's way for
  Technic, the next family by size and untouched by this lever.

Results: `bench/results/realset-2026-10-20-shapefirst44/` (report-proof.md),
`realset-2026-10-20-main-vs-shapefirst44/` (head to head), the tune arms
`realset-2026-10-20-shapefirst/`, `-shapefirst2/` and `-shapefirst3/`, and in
`shapefirst-2026-10-20/` the codes (proof-labels.jsonl, main44-labels.jsonl) and
the scripts that make each table (extract.py, code.py, families.py,
same_coder.py, wins.py, reach.py).


**What the verdicts' reasons add** (the lead, reading the 42 verdicts main
won overall). When main wins on likeness the judge names the features that
make the subject its own: Big Ben's slender belfry under a two-stage spire,
the Flatiron's prow under its cornice, the Burj Khalifa's tiers and setbacks,
the Louvre's mansard pavilions; and calls the losing design "a stubby, wide
tower", "plain grey cylinders", "long flat slabs". Naming the whole-model
shapes gave the right volumes and blunted those features. So two levers
follow, in this order: the subject's signature features named at planning
and each checked by name in the pictures beside the reference (branch
signature, 2026-10-20); then laying a defining shape from real parts rather
than describing it, as above.

### Likeness: the signature features, named and looked at, on the 44 of proof (2026-10-20, not ready)

The shape-first verdicts said a subject is known by its signature features,
Big Ben's slender belfry under a two-stage spire, the Flatiron's prow, the
Burj Khalifa's tiers. So the planner was made to name three to five of them,
each with what it must look like, and before saving the session looked at
its model beside a reference picture and rebuilt the feature least like the
real thing (branch signature, 0432339b; `Assistant._signature_gate`). On
tune's first ten it looked promising and could not be told from noise
(likeness against the sets 35% against main's 25%, head to head 40%).

Run once on the 44 of proof (4 at a time, headless with pictures on the GPU
lease; 3 pictures of 3 designs gave up for the letters), against main's 44:

| dimension | main | signature44 | main minus signature44 (95%) |
|---|---|---|---|
| likeness | 22% | 24% | -2 (-10, +5) |
| surface | 26% | 28% | -2 (-12, +8) |
| colour | 26% | 23% | +3 (-6, +11) |
| technique | 12% | 11% | +1 (-2, +5) |
| creativity | 35% | 32% | +3 (-7, +14) |
| overall | 20% | 22% | -1 (-8, +5) |

Head to head the judge was at a coin's toss: main preferred 52% on likeness
(38-66%), 55% overall (40-68%).

**Not ready.** Naming the features and looking again did reach every session
that looked (each rebuilt one), and moved nothing the judge could see. Two
likeness levers in a row (the defining shape, the signature features) told
the session what matters and checked it in words; neither changed what was
built enough. The next lever changes what is built: Technic subjects lost all
18 overall verdicts, 13 as "System bricks, not Technic", so a Technic subject
is built studless, beams and pins, from how real Technic sets build it. The
lever is kept on its branch. Results: bench/results/realset-2026-10-20-signature44/
and realset-2026-10-20-main-vs-signature44/.

### Technic built studless, on tune's Technic subjects (2026-10-21)

Technic lost every overall verdict on main's 44, 13 of 18 on the line's own
way ("Why the sets win" above). The sessions knew the brief said Technic and
built System bricks: every Telehandler designed here before this was 84 to 99%
studded parts, where a real Technic set is 4%. This lever has a Technic brief
built the way Technic sets are built. Branch `technic`.

**The lever** (`src/ai/technic_way.gd`, `technic_way_probe`).
- *How the designer knows:* the brief names Technic ("in the style of LEGO®
  Technic sets", "a Technic excavator"). Not the subject alone: a City
  front-end loader is studs and a Technic one is beams, and tune has both.
- *Asked at planning.* how_real_sets_build_this leads, on a Technic brief, with
  how a Technic set is built, measured over the 92 Technic sets of the OMR from
  2008 on (the realset subjects left out): 94% of a set's parts studless Technic
  at the median (pins 36%, beams and liftarms 20%, connectors and cross blocks
  20%, axles 12%, gears 3%, panels 2%), 4% studded and 9% at most in nine sets
  of ten; then the order a set is built in (the frame of beams and pins, wheels
  on axles, panels and bent liftarms for the body, what moves on the real one
  moving), with part numbers.
- *Held at submission.* A Technic brief's build more than half studded is sent
  back once with its numbers, as a character with nothing on a joint is.
- *A means.* show_technique "studless beam frame": rails, axles, wheels, pins
  and posts, written connector to connector and checked; find_techniques on a
  Technic brief answers from Technic sets' pieces (RealSnippets.search's theme).

**Tune's eight Technic subjects,** the lever (`3fbb245c`) and main
(`80271aa9`, the release head) each designed in the same harness, three at a
time, the same night.

| dimension | main preferred to the set | the lever preferred to the set | main minus the lever, paired (95%) | the lever preferred to main, head to head (95%) |
|---|---|---|---|---|
| likeness | 38% (14-69) | 19% (4-53) | +19 (-12, +50) | 6% (1-40) |
| surface | 50% (22-78) | 12% (2-47) | +38 (+19, +62) | 12% (2-47) |
| colour | 25% (7-59) | 6% (1-40) | +19 (+6, +38) | 38% (14-69) |
| technique | 0% (0-32) | 6% (1-40) | -6 (-19, 0) | 88% (53-98) |
| creativity | 12% (2-47) | 0% (0-32) | +12 (0, +31) | 44% (17-74) |
| overall | 0% (0-32) | 6% (1-40) | -6 (-19, 0) | 31% (10-64) |

- **The idiom moved.** Studded parts, the median over the eight: main 91%
  (57 to 98), the lever 3% (0 to 6), where a Technic set is 4%. No first build
  was sent back: told at planning, every session built a beam frame from its
  first submission. Head to head the judge called the lever's technique better
  88% of the time; against the sets it won its first Technic technique and
  overall verdicts (the Mine Loader, 1 of 2 each, likeness 2 of 2).
- **The reasons changed class.** Main lost as before: "a System model that
  misses the style", "stacked bricks with Technic bricks used only as
  decoration", BASH! built as the word in Technic bricks. The lever lost on
  being an unfinished Technic model: "an unclear yellow beam frame", "open
  studless beams with exposed pin holes, and nothing closes off its surfaces",
  "a raw beam framework", "loose, floating sub-assemblies and no clear working
  mechanism". Main's smooth sloped bodies won surface 8 of 16 against the sets;
  the lever's open frames 2.
- **Not ready on this alone.** Overall head to head the judge preferred main's
  designs 69% (36-90), likeness 94%, surface 88%: two of our designs side by
  side, it took the finished System body over the bare Technic frame, though
  against the set main won nothing overall.
- *What it cost.* The lever's sessions ran to their 45-minute timeout in 5 of 8
  (main 2 of 8), median 45 minutes against main's 22, models saved: laying beams
  by their holes is slow, and the Ducati stopped at 126 of the set's 638 parts.
  Pictures given up for the letters: 0 over 8 designs on each arm. The build
  check read the lever's first five and main's first seven: nothing floating.
- *Next.* The body. The lever got the frame; what the judge faults now is that
  nothing covers it. A Technic set's body is panels and bent liftarms pinned to
  the frame (2% panels by count, most of what is seen), and the sessions ran out
  of time before any: a call that lays a panel or a fairing on a frame's holes
  by name (as the frame itself is copied), and the review naming the open
  faces. And time: the frame done in fewer turns, so the passes after it run.

Results: `bench/results/realset-2026-10-20-technic/` and `-technicmain/`
(report-tune.md each), `realset-2026-10-20-technicmain-vs-technic/` (head to
head). The lever's 8464-1 and main's 42006-1 were designed twice: the first
sessions were orphaned when an outer `timeout` killed their run, and are set
aside as `*.killed`; the lever's 42107-1 waited on a port and was designed
alone.

### The body on the frame, on three of tune's Technic subjects (2026-10-21, not ready)

The studless lever's frames lost as bare frames: "open studless beams with
exposed pin holes, and nothing closes off its surfaces", "a raw beam
framework". Its sessions used no fairing at all, and five of eight ran to
their 45-minute limit. This lever gives the frame a body, measured off real
sets, and the frame fewer turns. Branch `technic2`.

**How real sets cover a frame** (`tools/technic_cover.py`). Over the 92
Technic sets of the OMR from 2008 on, the realset subjects left out: each
part's box seen from the sides, the ends and the top (by the model's own
length), the nearest part in each half-stud cell.

| of what a viewer sees, median (quartiles) | sides | ends | top |
|---|---|---|---|
| panels and fairings | 18% (9-34) | 15% (5-29) | 25% (12-39) |
| bent liftarms | 10% (5-16) | 8% (5-14) | 8% (4-12) |
| bare frame: beams, pins, axles, connectors | 38% (23-57) | 43% (36-55) | 44% (30-57) |
| wheels and tracks | 19% (2-28) | 11% (3-22) | 3% (1-13) |

- The body's parts by how many sets use them: bent liftarms 32140 (89 of 92)
  and 32526 (77), the thin fairing pair 11946/11947 (51-52), 32009 (50), the
  medium fairing pair 64683/64391 (46), the 5 x 11 panel 64782 (43). Fairings
  come in mirrored pairs.
- In the 59 sets with coloured panels, 67% of the straight beams are black or
  grey at the median (49-77), 17% in the body's colour: the colour is on the
  panels.
- The first reading had each box mirrored in z: `tools/style.py`'s `Parts`
  turns the catalogue's boxes to LDraw by y alone, and the catalogue is LDraw
  turned half a turn about x (`src/parts/ldr_model.gd` FLIP). A bent liftarm
  read 27% of a side where the app reads 12%. `technic_cover.py` puts z back,
  and on two designs it reads within a point or two of the app's own
  `TechnicWay.faces`. The run below was told the first reading (16% and 15%
  for the sides); every other measure `style.py` makes of an asymmetric part
  has the same mirror.

**Where the studless lever's time went** (its nine session transcripts).
85% of a session was the model's, not the app's: 37 of 44 minutes. 87 to
198 tool calls; attachment_points 22 to 54 of them, with 5 to 17 minutes of
thinking around them, because most parts were placed by coordinates worked
out by hand and checked there (attach laid 2 to 15%); edit_model up to 44
calls of a few parts each, 6 to 9 s each in the app. The first whole-model
review came at 15 to 42 minutes (the Ducati never had one), and the surface
and creative passes ran in 3 of 9. The Ducati lost its last ten minutes to a
move_part that hung for 600 s until the MCP server dropped (reopened from its
saved file, the same call answers at once: the sections' hinge is not in the
file).

**The lever** (`src/ai/technic_way.gd`, `techniques.gd`, `technic_way_probe`).
- *Told at planning*: the body step with those numbers and part numbers, the
  fairings in pairs, the frame dark and the colour on the panels, never beams
  stacked side by side as a wall.
- *A means*: show_technique "panelled beam frame", the studless frame with a
  3 x 7 panel on two pins on each post and the medium fairing pair low along
  the sides, laid by attach, checked (27 parts, none studded).
- *Said at every build and the whole-model review*: what covers the frame,
  face by face, against those sets (`TechnicWay.cover_said`), the faces below
  the sets' lowest quartile named open with the parts that cover them, and a
  frame under half black or grey named.
- *Time*: the frame and its body in the first submit_design, every pin, beam
  and panel by attach to a named part, attachment_points once a part, then
  review_model.

**Three of tune's eight,** the Mine Loader (42049-1), the Ducati (42107-1)
and the Tractor (9393-1), designed with the lever (`c4f60f05`) in the same
harness as the two arms recorded for 2026-10-20, three at a time.

| | main (`technicmain`) | studless (`technic`) | the body (`technic2`) |
|---|---|---|---|
| overall against the set, verdicts won of 6 | 0 | 1 | 1 |
| likeness / surface / technique | 3 / 3 / 0 | 3 / 1 / 1 | 1 / 1 / 0 |
| studded parts, each subject | 97%, 76%, 98% | 0%, 0%, 6% | 5%, 1%, 6% |
| sides in panels and fairings (sets 18%) | 0%, 13%, 0% | 17%, 0%, 12% | 42%, 42%, 33% |
| fairings on the sides | 0%, 13%, 0% | none | 14%, 12%, 0% |
| bent liftarms on the sides (sets 10%) | none | 12%, 1%, 4% | 0%, 0%, 3% |
| minutes; timed out | 24, 45, 15; 1 of 3 | 45, 45, 45; 3 of 3 | 37, 39, 32; 0 of 3 |
| parts (sets 478, 638, 354) | 428, 345, 415 | 299, 126, 252 | 160, 173, 272 |

- **The body is there, and the time.** Every face the first build showed bare
  was named open ("the sides, the ends and the top"), and by the first review
  the Tractor's and the Mine Loader's sides were a third panels (the Ducati's
  9%, its top still open). The first review came at 11 to 15 minutes,
  all three reached the surface and creative passes and saved, none ran to
  the limit; attach laid 12 to 28% of the parts, attachment_points 17 to 34
  calls. Head to head the judge took its surface over the studless lever's
  every time (6 of 6), overall 50%.
- **The reasons moved again.** From "no bodywork at all" and "nothing closes
  off its surfaces" to the body's shape: "flat panels with gaps between
  them", "panels sticking out at odd angles", "a tall open frame with yellow
  beams floating above the chassis", "a long, flat box frame". The Mine
  Loader copied the technique's panels standing on posts above the rails and
  was read as panels floating over the axles; the Tractor's bonnet is still
  beams stacked side by side, under one flat panel. Overall they are panelled
  past the sets (33 to 42% of the sides, the sets' upper quartile 34%) with
  flat panels, and with no bent liftarms where a set has 10%.
- **Not ready on this.** Against the set it won what the studless lever won (1
  of 6 overall) and lost likeness (1 of 6 against 3). Head to head main's
  smooth System bodies still won likeness 100%, surface 83%, overall 67%; the
  body's technique 67%. Three subjects is no measure: the bar is the 9 of
  proof.
- **The technique was the flaw.** Drawn, "panelled beam frame" has its panels
  on the posts two studs clear of the rails, and its fairings low at the
  sides beside the wheels (`technique-panelled-beam-frame_corner.png` in the
  arm's folder): the gap the judge read as "floating panels over the axles",
  and all three sessions copied it. Its 11-stud rails leave five studs
  between the wheels, so no 7-stud panel lies on them at rail level.
- *Next.* The body's shape, not its amount: a technique drawn and looked at
  before it ships, with panels flush on the frame and no daylight under them
  (longer rails, or panels above mudguards), fairing pairs shaping the nose,
  the bonnet and the fenders at their angle, bent liftarms drawing the
  outline; and the review reading a panel standing clear of the frame. The z
  mirror in `style.py`'s boxes is its own fix.

Results: `bench/results/realset-2026-10-20-technic2/` (report-tune.md),
`realset-2026-10-20-technic-vs-technic2/` and
`-technicmain-vs-technic2/` (report-tune-3.md each, head to head on the
three). A dry run first wrote a canned design into the arm's folder; it is
set aside as `realset-2026-10-20-technic2.dryrun`.


### The body held flush, on the same three subjects (2026-10-21, not ready)

The body lever's technique stood its panels on posts two studs above the
rails, and every session copied it: "floating panels over the axles", "flat
panels with gaps between them", "a long, flat box frame". This lever measures
how a set holds its body and draws the technique from that. Branch `technic3`.

**How a set holds its body** (`src/dev/technic_hold.gd`, joint by joint as the
build check reads them, over the 92 Technic sets `technic_cover.py` reads).

| | panels (1,075) | fairings (1,020) |
|---|---|---|
| held by a pin through their holes | 92% | 93% |
| ...a 6558 long pin / a 2780 / an axle pin (43093, 11214, 18651) | 40% / 34% / 13% | 28% / 35% / 11% |
| ...to a straight beam / a connector / another panel / a bent liftarm | 45% / 16% / 21% / 14% | 41% / 20% / 16% / 14% |
| the pin in the part's edge / through its face | 74% / 26% | 93% / 7% |
| holes a stud apart along the pin or less (face to face) | 68% | 71% |
| facing the side / up / an end | 39% / 50% / 11% | 49% / 43% / 8% |
| facing the side: foot on the part below / nothing below / 2 studs of daylight or more | 60% / 19% / 5% | 57% / 23% / 4% |

- Of the panels and fairings facing the side, 77% (705 of 919) are face to
  face with a straight beam or a connector: the side's panels are flush on
  the frame, never stood off it on posts.
- Bent liftarms (3,994): 62% lie in the side's plane, drawing the side's
  outline; pinned to straight beams 31%, connectors 26%, each other 25%.
- Tyres (314): 63% have something over them, reaching above the tyre and
  coming down to within two studs of its top: a bent liftarm 39%, a panel
  13%, a fairing 11%. The wheel arch is a bent liftarm before it is a panel.
- Drawn, a real side reads the same way: the Rally Car (42077-1,
  `reference-42077-1_right.png` in the arm's folder) has a door panel low
  between the wheels down to the sill beam, curved pieces over both wheels,
  and fairings at the nose and the tail.

**The lever** (`src/ai/techniques.gd`, `technic_way.gd`, `technic_way_probe`).
- *The technique redrawn.* "panelled beam frame" is now beam 15 rails with
  the wheels at their ends; on each side a 3 x 7 panel as the door, flush on
  the rail's outer face between the wheels on two 2780 pins through its face
  holes, its foot the rail's; a beam 15 as the waist behind its top row,
  running over both wheels; and a 4 x 4 bent liftarm at each end of the
  waist, in the door's plane, over the wheel and down past it to the nose
  and the tail. 36 parts, none studded, laid by attach, checked. Drawn from
  the corner and the side (`technique-panelled-beam-frame_corner.png`,
  `_right.png`): a door low between the wheels, arches over them, no daylight
  under anything. What it does not show is a closed nose, tail or top: a
  5 x 11 panel between the waists is a lattice cell too wide (its edge holes
  sit 0.45 of a stud in, so pinned to one waist it overlaps the other by
  1 LDU), and a panel across the nose on the arches' holes lay on one line
  of pins, free to turn. Its text names what closes them instead.
- *Told at planning*: the body step with those numbers, "never a panel on
  posts standing clear of the frame", with the judge's words.
- *An open face named with what covers it*: the review's "Open:" now says,
  face by face, what covers it on a set, by part number: the sides a flat
  panel flush between the wheels and bent liftarms arching over them, the
  ends fairing pairs meeting in the middle and a panel across, the top flat
  panels by their edge holes into the side beams.
- *Checked*: the probe holds the technique to it, its two doors' feet no
  higher than the rails' top and all four tyres arched. The old technique
  fails both: no panel flush in the side's plane, two of its four tyres
  arched.

**The same three of tune's eight,** the Mine Loader (42049-1), the Ducati
(42107-1) and the Tractor (9393-1), designed with the lever (`359c0b1b`) in the
same harness as the arms recorded for 2026-10-20, three at a time.

| | main (`technicmain`) | studless (`technic`) | the body (`technic2`) | held flush (`technic3`) |
|---|---|---|---|---|
| overall against the set, verdicts won of 6 | 0 | 1 | 1 | 1 |
| likeness / surface / technique | 3 / 3 / 0 | 3 / 1 / 1 | 1 / 1 / 0 | 1 / 3 / 0 |
| studded parts, each subject | 97%, 76%, 98% | 0%, 0%, 6% | 5%, 1%, 6% | 5%, 3%, 9% |
| sides in panels and fairings (sets 18%) | 0%, 13%, 0% | 17%, 0%, 12% | 42%, 42%, 33% | 19%, 50%, 14% |
| bent liftarms on the sides (sets 10%) | none | 12%, 1%, 4% | 0%, 0%, 3% | 7%, 0%, 6% |
| minutes; timed out | 24, 45, 15; 1 of 3 | 45, 45, 45; 3 of 3 | 37, 39, 32; 0 of 3 | 40, 45, 42; 1 of 3 |
| parts (sets 478, 638, 354) | 428, 345, 415 | 299, 126, 252 | 160, 173, 272 | 223, 228, 249 |

Head to head, both orders, the lever's design preferred:

| dimension | to main's | to the body's (`technic2`) |
|---|---|---|
| likeness | 33% (6-79) | 50% (13-87) |
| surface | 33% (6-79) | 67% (21-94) |
| colour | 0% (0-56) | 50% (13-87) |
| technique | 83% (31-98) | 83% (31-98) |
| creativity | 50% (13-87) | 67% (21-94) |
| overall | 67% (21-94) | 83% (31-98) |

- **The floating went from the sides.** No verdict reads panels over the
  axles or a tall open frame; what floats now is the Tractor's roof ("a stack
  of floating roof panels and loose pins"), and what is boxy the Ducati's
  flat panels. The Mine Loader is low and long, its panels flush, a
  curved black mudguard over the rear wheels, and against the set it won
  surface both ways round, likeness and overall once: "B covers the body with smooth
  yellow panels and a flat engine deck behind a curved black fender". The
  Tractor's sessions built mudguards on their own (5 x 11 panels over the
  rear tyres, double-bent liftarms arching over the front). The sides came
  back to the sets' amount on two (19% and 14% against the sets' 18%), and
  bent liftarms to the sides' outline (7% and 6%, the body's 0% and 3%).
- **Head to head it moved most.** Against main's System bodies the judge
  took the lever's overall 67% (the body's 33%) and its likeness 33% (the
  body's 0%); against the body's own designs, overall 83%, technique 83%.
- **What the sets still win on.** Shape where the body is the subject: the
  Ducati is "a boxy stack of flat red panels with a blunt nose", "flat
  rectangular panels stacked in steps", where the set's fairing is "curved
  Technic panels that flow around the nose and flanks" (its sides 50% flat
  panels). The Tractor's roof is "a stack of floating roof panels and loose
  pins". And technique, 0 of 6: every set wins it on working functions, "a
  turntable-centred articulated chassis", "a working chain drive with
  sprockets, a gearbox, front and rear suspension", "angled fairing
  sub-assemblies", against "a simpler frame of stacked beams with a gear".
- *What it cost.* The sessions ran longer, 40, 45 and 42 minutes, the Ducati
  to the limit (the body's 37, 39 and 32), with 28 to 44 attachment_points
  calls (the body's 17 to 34) and more parts laid (223 to 249). Each looked
  at the technique once. The build check read all three: none floating.
- **Not ready on this alone.** Three subjects is no measure, and against the
  sets it won what the last two levers won, 1 of 6 overall. The bar is the 9
  of proof: technique's paired interval against the sets clearing zero and
  overall not falling. On these three, technique against the sets did not
  move (0 of 6).
- *Next.* Shape and working parts, not cover: panels at an angle (a fairing
  pair raked to a nose, the sets' "angled panel sub-assemblies") rather than
  flat in steps, and one working function the real machine has, driven from
  a knob or a gear, before the body.

Results: `bench/results/realset-2026-10-20-technic3/` (report-tune-3.md, the
technique drawn as `technique-panelled-beam-frame_corner.png` and `_right.png`,
the Rally Car's side as `reference-42077-1_right.png`, `technic_hold.txt`), and
`realset-2026-10-20-technicmain-vs-technic3/` and `-technic2-vs-technic3/`
(report-tune-3.md each). The main checkout's renderer failed to load at 04:47
(main.gd, a parse error on "player": its class cache older than its code), so
the three designs were drawn by this branch's `bench_views.gd`, which main's
equals, and judged by a second `run` that kept the designs; `audit` failed the
same way, so the build check above is this branch's `connection_audit.gd`, and
the records still want `audit` once the main checkout is imported again.

**On tune's eight, not ready.** The main checkout imported again, its five
other Technic subjects designed with the lever (`752f83b7`) and all eight
audited and judged against technicmain's (2026-10-20):

| dimension | technicmain preferred to the set | technic3 preferred to the set | technicmain minus technic3, paired (95%) | technic3 preferred to technicmain, head to head (95%) |
|---|---|---|---|---|
| likeness | 38% (14-69) | 6% (1-40) | +31 (+6, +62) | 25% (7-59) |
| surface | 50% (22-78) | 38% (14-69) | +12 (0, +31) | 25% (7-59) |
| colour | 25% (7-59) | 12% (2-47) | +12 (-12, +38) | 31% (10-64) |
| technique | 0% (0-32) | 0% (0-32) | 0 (0, 0) | 88% (53-98) |
| creativity | 12% (2-47) | 25% (7-59) | -12 (-38, +12) | 50% (22-78) |
| overall | 0% (0-32) | 6% (1-40) | -6 (-19, 0) | 56% (26-83) |

Three units have moved the idiom and the judge's view of it: between our
two designs it takes the Technic one on technique nearly every time. Against
the set nothing has moved on technique, and likeness has fallen, the one
interval here that clears zero. A real Technic set wins on what it does and
on looking like its machine; a studless frame with a flush body is neither.
So the proof half was not run. What is left is the line's own next step:
the subject's silhouette laid first, then one working function the real
machine has, driven from a knob or a gear. Results:
`realset-2026-10-20-technicmain-vs-technic3/report-tune-8.md` beside
`report-tune-3.md`.
### The outline and a working function, on the same three subjects (2026-10-21, not ready)

Against the sets the held-flush lever won no technique verdict in three
units, and its likeness fell: "no working mechanism", "a long, flat box
frame", "a tall boxy cage of beams on small car-like wheels". This lever
gives the session the machine's outline as real Technic sets of its kind
have it, and has it build one function the real machine has and prove it
moves before saving. Branch `technic4`.

**How a kind of machine stands, and what works in it** (`tools/technic_shape.py`,
over the 92 Technic sets `technic_cover.py` reads). A set's kind by a word of
its name; its length, height, biggest tyre and wheelbase (the first axle to
the last, tracked machines left out), each a share of its length; what works
in it by the parts that do it.

| kind (sets) | tyre across, of the length | wheelbase | height | most of them have |
|---|---|---|---|---|
| car (26) | 0.17 (0.14-0.21) | 0.61 (0.53-0.67) | 0.36 (0.27-0.55) | steering 21, piston engine 15, suspension 15 |
| truck (14) | 0.15 (0.11-0.18) | 0.59 (0.46-0.67) | 0.51 (0.37-0.64) | steering 12, differential 8, gearbox 8 |
| crane (10) | 0.16 (0.10-0.19) | 0.42 (0.39-0.58) | 0.62 (0.47-0.69) | worm 7, turntable 6, steering 5 |
| loader (8, 4 on wheels) | 0.21 (0.13-0.30) | 0.47 (0.37-0.59) | 0.54 (0.49-0.60) | worm 5, turntable 4, steering 3 |
| tractor (5) | 0.16 (0.15-0.24) | 0.35 (0.30-0.77) | 0.51 (0.37-0.60) | steering 4, worm 4, linear actuator 3 |
| motorcycle (2) | 0.24 (0.19-0.28) | 0.63 (0.60-0.66) | 0.57 (0.57-0.58) | piston engine, suspension, chain, 1 each |
| all 92 | 0.15 (0.11-0.20) | 0.57 (0.42-0.64) | 0.49 (0.35-0.60) | steering 63, gearbox 38, piston engine 37 |

- *Held out, the height is not the kind's.* Tune's eight Technic sets read
  the same way against their kind: the wheelbase in its range for all seven
  on wheels, the tyres for five (BASH!'s balloon tyres are 0.32), the height
  for four of eight (the Mine Loader is 0.27 where a loader is 0.49 to 0.60).
  So the height and where the masses stand are told off find_reference's
  picture, and only the tyres and the wheelbase are measured against the
  kind. Seven of the eight sets have one of their kind's three most usual
  functions; BASH! has none.
- *Read twice.* A tyre turned on its axle has a world box up to 1.4 times
  its size, so it is read across by its own box; a motorcycle's tyre named
  "... Racing Tread" and a chain of Link Treads at the axles are not tracks,
  only treads that reach the ground are. The app reads 8260-1 and 42036-1 to
  within 0.6 of a stud of the script (`technic_way_probe`). The tractor's
  wheelbase range is wide because two of its five sets carry their trailer.

**The lever** (`src/ai/technic_way.gd`, `assistant.gd`, `command_socket.gd`,
`technic_way_probe`).
- *Told at planning*, how_real_sets_build_this on a Technic brief, for the
  kind the brief names or, failing that, the one the session asks about (the
  Ducati's sessions asked for "a Technic motorcycle"): the tyres and wheelbase
  in studs for the brief's length, the tyres its sets run on, the height and
  masses off the picture, then the kind's functions by count with their parts
  (a worm 4716 on a 3648b, a linear actuator 61927-f1, a turntable 99009 and
  99010, an engine's cylinders, pistons and crankshaft), built where the
  corner picture shows them and proven with move_part and simulate_mechanism.
- *Said at every build and the whole review*: the outline against the kind,
  tyres or wheelbase out of range named; what works in it by its parts against
  the kind's, its signature (the three most usual) named where it has none.
  The whole review adds what moves as the app reads its joints (Playable).
- *Held at saving*, once: a Technic design with nothing Playable reads as
  moving, or none of its kind's signature by its parts.
- *Two runs.* The first (`technic4`, `d1da8bfd`) told the sessions to take
  the panelled frame's holds but not to copy it whole; head to head the judge
  took technic3's designs over all three, so the second (`technic4b`,
  `2d9ba735`) copies it again, its rails, axles and tyres sized by the outline,
  and adds what works by its parts.

**The same three of tune's eight,** in the same harness as the arms recorded
for 2026-10-20, three at a time.

| | main | held flush (`technic3`) | `technic4` | `technic4b` |
|---|---|---|---|---|
| overall against the set, verdicts won of 6 | 0 | 1 | 0 | 0 |
| likeness / surface / technique | 3 / 3 / 0 | 1 / 3 / 0 | 0 / 2 / 0 | 0 / 1 / 0 |
| studded parts, each subject | 97%, 76%, 98% | 5%, 3%, 9% | 3%, 0%, 6% | 6%, 0%, 5% |
| tyre across, of the length (the sets' 0.16, 0.27, 0.22) | 0.22, 0.27, 0.34 | 0.17, 0.30, 0.25 | 0.15, 0.31, 0.27 | 0.16, 0.28, 0.23 |
| wheelbase (the sets' 0.40, 0.63, 0.37) | 0.43, 0.68, 0.56 | 0.45, 0.70, 0.32 | 0.47, 0.69, 0.55 | 0.38, 0.65, 0.50 |
| what works, by its parts | steering; chain, suspension; steering | worm; chain; steering, worm | worm; chain; steering | worm; chain, piston engine; steering, worm |
| minutes; saved | 24, 45, 15 | 40, 45, 42 | 30, 45, 40; 3 of 3 | 45, 45, 45; 1 of 3 |
| parts (sets 478, 638, 354) | 428, 345, 415 | 223, 228, 249 | 216, 192, 270 | 246, 217, 230 |

Head to head, both orders, the lever's design preferred:

| dimension | `technic4` to main's | `technic4` to technic3's | `technic4b` to main's | `technic4b` to technic3's |
|---|---|---|---|---|
| likeness | 0% (0-56) | 17% (2-69) | 0% (0-56) | 0% (0-56) |
| surface | 0% (0-56) | 0% (0-56) | 0% (0-56) | 0% (0-56) |
| technique | 67% (21-94) | 0% (0-56) | 67% (21-94) | 17% (2-69) |
| overall | 50% (13-87) | 0% (0-56) | 33% (6-79) | 0% (0-56) |

- **Every design built a function, and it moved.** By the sessions' own
  checks: the Mine Loader's worm lifts its boom ("5 turns of the knob raise
  it about 75°") and, in the second run, it steers; the Tractor's knob lifts
  its hitch ("four turns of the knob raise the linkage by about a stud"); the
  second Ducati's rear wheel turns a piston engine through two chains ("1.5
  crank turns per wheel turn"). Saving read them on the joints in the four
  designs that saved ("moves: boom, gears", "steering, boom, gears"); the
  gate never had to hold one. The second Tractor and Ducati ran out of time before saving.
- **The judge credits none of it.** Against the sets, technique 0 of 12 over
  both runs: "a gear that shows but does little", "one exposed worm gear on a
  simple boom frame", "gears and panels bolted onto a box with no real
  purpose", "springs and levers, but they sit inside a sprawling, unenclosed
  beam scaffold". What wins it on the set is how the working parts are
  packaged and shaped: "a piston engine block packaged inside the frame",
  "angled fairing sub-assemblies" and "angled panel sub-assemblies" (in seven
  of the twelve technique reasons), "a compact, tractor-shaped frame". Head to
  head with main's System bodies our technique still wins 67%.
- **The outline came near the set's, and likeness did not move.** The second
  run's tyres are within 0.01 of the set's on all three and its wheelbase
  within 0.02 on two (the Tractor's 0.50 against 0.37, inside the
  trailer-wide range). The likeness reasons are about masses and faces, not
  proportions: "tall open roll cage", "open lattice cab", "an open beam-cage
  cab" (in four of the second run's six),
  "panels sticking out at odd angles", "a long flat box of a bonnet".
- **It cost the body.** The sessions spent their time on the function: 14
  move_part calls in two of the second run's sessions, the Ducati laying its
  engine before its frame (60 parts at 17 minutes), all three of the second
  run to the 45-minute limit. Head to head technic3's designs won overall 6
  of 6 against each run, surface 6 of 6.
- **Not ready.** On these three it falls behind the lever it builds on, head
  to head and against the sets (overall 0 of 6 against technic3's 1). The
  proof 9 would not clear its bar on this evidence. The build check read all
  six: none floating.
- *Next.* What the judge reads as technique is a mechanism's packaging, not
  its working: a function enclosed in the body with its signature parts
  showing where a set shows them (an engine block between the frame rails,
  shock absorbers at the wheels), and panels at an angle. And the cab: a
  closed cab of panels and a windscreen, not a cage of beams, named by the
  review as the open faces are. The tractor's wheelbase measured on the
  tractor alone.

Results: `bench/results/realset-2026-10-20-technic4/` and `-technic4b/`
(report-tune-3.md each), `realset-2026-10-20-technicmain-vs-technic4/`,
`-technic3-vs-technic4/`, `-technicmain-vs-technic4b/` and
`-technic3-vs-technic4b/` (report-tune-3.md each). The kinds' table is
`python3 tools/technic_shape.py` (and `--gd` for the one technic_way.gd keeps).

## Against an outside ruler: BrickBench (2026-10-14)

Everything below is our own judge. [BRICKBENCH.md](BRICKBENCH.md) puts the
designer on BrickBench's Model setting: its first ten prompts through the real
loop on the subscription, kept to BrickNet's parts, checked by BrickBench's own
`verify.py` and judged in pairs against BrickAgent's Claude Opus 5.5 builds of
the same prompts. **2 of 10 valid**, against 10 of 10 for theirs; our pairwise
judge (ours, not BrickBench's) preferred their build in all 40 verdicts
overall; $2.65 a build at API prices against their $5.90. The submission zip
is built and checked, and not sent.

### The check made as strict as BrickBench's (2026-10-14, evening)

The build check now judges each part by BrickNet's own convex colliders and
connector labels: more than 1 LDU of overlap is a collision named with its
fix, a piece that nothing holds and that would not stand is a fault, and a
part a few LDU off a connector is seated on it first
([BRICKBENCH.md](BRICKBENCH.md), "the check made as strict as BrickBench's").
The same ten prompts through the same loop, and ten held out, each checked by
BrickBench's own `verify.py`:

| | valid by verify.py | parts, mean | design time, mean |
|---|---|---|---|
| the ten, first run (this morning) | 2 of 10 | 155 | 587 s |
| the same ten, the strict check (`6bbe717`) | **9 of 10** | 133 | 432 s |
| ten held out (model-011 to 020) | **8 of 10** | 167 | 712 s |
| BrickAgent's Opus 5.5, the ten | 10 of 10 | 130 | |

The three that failed were a part each (a head exactly 1 LDU into a
breastplate, which verify.py's rounding refuses; a steering wheel on a
brick's edge; a leaning flower). The check refuses the last two since, and
the app no longer seats a head that way. Nothing was judged on looks here: these are verify.py's verdicts,
and no VQA or Elo was run.

## A figure is not a hull: the stacking fix, held out (2026-10-14, `63ab5ca`)

[BRICKBENCH.md](BRICKBENCH.md) has the whole of it, under "why ours were
statues". Our BrickBench characters were stacked-brick statues on big plates.
Four things made them so:
- the instructions' head said every mass is a shape pattern;
- the bench's part list refused the generators' own part numbers, so
  sessions stacked bricks by hand;
- nothing said how big a figure is;
- the creative pass asked for a story, which meant an unasked figure.

The fix sends a figure, a creature or anything small to a guide section of
its own. It answers plan_scale for a person, keeps the creative pass to what
the brief names, and sizes a baseplate to the scene in eights. A moved part
number now reads as the part it moved to.

**On ten held-out BrickBench prompts** (model-021 to model-030, small trains
with faces and figures), there were two designs a prompt in each arm and 200
pairwise verdicts:

| | full (`fe032a8`) | lean (`63ab5ca`) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| overall ELO (95%) | 675 (597-731) | 735 (679-797) | 1590 (1588-1606) |
| lean vs full, overall | | 47 of 80 (59%, 95% 48-69%) | |
| likeness, surface | | 61%, 62% of 80 (each just clear of even) | |
| against BrickAgent, overall | 0 of 40 | 0 of 40 | |
| unasked figures, of 12 designs | 7 | 1 | |
| stacked bricks and plates (median) | 60% | 59% | 38% |
| valid (their verify.py) | 5 of 20 | 6 of 20 | 10 of 10 |

The scope fix worked: the unasked figures and the big baseplates went. The
judge leaned to the fix, on overall inside the noise and on likeness and
surface just outside it. It cost creativity, which the judge had read off
the unasked figures. The construction itself did not move on these
vehicle-like prompts. Neither arm won a verdict against BrickAgent.

**No regression on big subjects.** The car and the fire truck went through
`run.py` on the fix (`c0d7257`), two designs each, as round
`2026-10-14-figures`. Each was judged in pairs against every design of its
subject from every round, `2026-10-14-cabins` among them: 302 verdicts, 272
for the car's 17 designs and 30 for the fire truck's 6. `run.py rank` reads
the round as the lever "figures" against "cabins".

| subject | design | 1-10 mean | overall ELO (95%) | its cabins counterpart |
|---|---|---|---|---|
| speed_champions | figures/1 | 4.17 | 1017 (934-1100) | cabins/1 4.33, 1125 (1040-1214) |
| speed_champions | figures/2 | 4.17 | 976 (885-1063) | cabins/2 4.17, 825 (718-926) |
| fire_truck | figures/1 | 6.67 | 1011 (851-1154) | cabins/1 5.67, 631 (543-852) |
| fire_truck | figures/2 | 6.67 | 1276 (1080-1437) | cabins/2 7.00, 1203 (996-1383) |

| lever | subjects | dimension | ELO change | judge's 95% | with run-to-run 95% | 1-10 change |
|---|---|---|---|---|---|---|
| figures, against cabins | 2 | overall | +124 | (+0, +218) | (-246, +475) | +0.13 |
| | | likeness | +118 | (-9, +231) | (-205, +404) | +0.25 |
| | | technique | +27 | (-98, +130) | (-322, +340) | +0.00 |
| | | surface | +55 | (-55, +156) | (-348, +476) | +0.00 |
| | | colour | +369 | (+280, +421) | (+47, +616) | +0.50 |

Head to head with the cabins round, overall: the car won 4 of 8 verdicts
(95% 22-78%) and the fire truck 6 of 8 (41-93%), 10 of 16 together (39-82%).
No dimension went down. Once the run-to-run spread is counted, every change
but colour is inside the noise.

The new guidance routes a hull to the shape patterns as before. Both fire
trucks' creative passes still added a firefighter, because the brief names
only the truck.

**On ten held-out characters** (model-031 to model-040: robots, aliens,
wizards, a demon, a bear), with one design an arm a prompt and 120 verdicts:

| | full (`fe032a8`) | lean (`c0d7257`) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| overall ELO (95%) | 739 (577-812) | 856 (680-988) | 1405 (1293-1613) |
| lean vs full, overall | | 26 of 40 (65%, 95% 50-78%) | |
| lean vs full, likeness and technique | | 62% (47-76%), 60% (45-74%) | |
| against BrickAgent, overall | 0 of 40 | 2 of 40 | |
| stacked / shaped / tiles (median) | 66% / 28% / 12% | 53% / 36% / 21% | 38% / 62% / 16% |
| across, studs; parts | 20; 202 | 14.5; 158 | 17; 203 |
| valid (their verify.py) | 2 of 10 | 4 of 10 | 10 of 10 |

On characters the fix did what it was for. Nine of ten sessions read the
figures section, and the builds moved from stacked bricks toward shaped
parts, smaller and on no baseplate. The judge preferred them. Lean took the
first verdicts any of ours has taken from BrickAgent: 2 of 40.

What is left is the size of the gap. Their builds are 62% shaped, with real
joints; ours have none to speak of. The intervals here carry no run-to-run
spread within an arm, and that spread was the larger part on the held-out
ten.
### The check made as strict as BrickBench's (2026-10-14, evening)

The build check now judges each part by BrickNet's own convex colliders and
connector labels: more than 1 LDU of overlap is a collision named with its
fix, a piece that nothing holds and that would not stand is a fault, and a
part a few LDU off a connector is seated on it first
([BRICKBENCH.md](BRICKBENCH.md), "the check made as strict as BrickBench's").
The same ten prompts through the same loop, and ten held out, each checked by
BrickBench's own `verify.py`:

| | valid by verify.py | parts, mean | design time, mean |
|---|---|---|---|
| the ten, first run (this morning) | 2 of 10 | 155 | 587 s |
| the same ten, the strict check (`6bbe717`) | **9 of 10** | 133 | 432 s |
| ten held out (model-011 to 020) | **8 of 10** | 167 | 712 s |
| BrickAgent's Opus 5.5, the ten | 10 of 10 | 130 | |

The three that failed were a part each (a head exactly 1 LDU into a
breastplate, which verify.py's rounding refuses; a steering wheel on a
brick's edge; a leaning flower). The check refuses the last two since, and
the app no longer seats a head that way. Nothing was judged on looks here: these are verify.py's verdicts,
and no VQA or Elo was run.

## Parts put on by their connectors (2026-10-15, `f64620b`)

[BRICKBENCH.md](BRICKBENCH.md) has the whole of it, under "parts put on each
other by their connectors". A placement can now say `"attach": {"to":
"torso.hinge[0]", "by": "hinge[0]", "yaw": 240}`: the app puts the part where
BrickAgent's own placement arithmetic puts it, on BrickNet's connector
labels, seated so the exact check passes it. A probe puts a brick on a stud,
a plate on a side stud, a bar in a clip, a ball, a hinge, an axle and a
twelve-part posed minifigure each within 0.001 LDU of BrickAgent's pose, and
BrickBench's verify.py passes all seven.

**On ten held-out BrickBench prompts** (model-041 to model-050: a puzzle
cube, a potato toy, a balloon dog, a toilet with a head, a paperclip with
eyes, a hugging armchair, a dumpster on fire, a lava lamp, a seated statue,
a pinball machine), two designs a prompt in each arm and 200 pairwise
verdicts:

| | lean and exact (`7740d22`) | attach (`f64620b`) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| overall ELO (95%) | 811 (622-903) | 860 (670-948) | 1329 (1197-1600) |
| attach vs lean, overall | | 46 of 80 (58%, 95% 47-68%) | |
| attach vs lean, likeness | | 48 of 80 (60%, 95% 49-70%) | |
| against BrickAgent, overall | 2 of 40 | 2 of 40 | |
| valid (their verify.py) | 16 of 20 | 17 of 20 | 10 of 10 |
| shaped, median | 35% | 39% | 44% |
| parts off the square, pooled | 9.8% | 12.6% | 26.2% |
| joints, pooled | 0.6% | 0.8% | 1.2% |
| sessions that attached anything | | 7 of 20 (211 of 2,867 parts sent) | |

The sessions took attach up for what a corner cannot say: flames turned on
round bricks' hollow studs, eyelashes aimed out of side studs, eyebrows
turned 15 degrees on jumpers. Where they did, the judge preferred it (the
dumpster 8 of 8 verdicts, the armchair 7 of 8). No session posed a figure on
its joints or asked for the new figure techniques: the statue and the
balloon dog were stacks in both arms. Overall the gain is inside the noise.

**No regression on big subjects.** The car and the fire truck went through
`run.py` on `9e147ef`, two designs each, as round `2026-10-15-attach`, judged
in pairs against every design of their subject (380 verdicts for the car's 20
designs, 56 for the fire truck's 8). Every session put a few parts by their
connectors.

| subject | design | 1-10 mean | overall ELO (95%) | its figures counterpart |
|---|---|---|---|---|
| speed_champions | 2026-10-15-attach/1 | 4.17 | 872 (793-950) | figures/1 4.17, 997 (921-1073) |
| speed_champions | 2026-10-15-attach/2 | 4.33 | 1162 (1079-1251) | figures/2 4.17, 979 (900-1057) |
| fire_truck | 2026-10-15-attach/1 | 6.00 | 965 (815-1096) | figures/1 6.67, 965 (847-1082) |
| fire_truck | 2026-10-15-attach/2 | 6.33 | 1251 (1140-1344) | figures/2 6.67, 1198 (1048-1333) |

Head to head with the figures round, overall: the car won 5 of 8 verdicts
(95% 31-86%) and the fire truck 5 of 8 (31-86%); with the cabins round, 4 of
8 and 5 of 8. Against the baseline round, `run.py rank` reads the car -45
ELO (judge's 95% -121 to +44; with the run-to-run spread -503 to +466). The
car's two designs are 290 ELO apart: no regression, and no gain shown.

## Figures told of their joints (2026-10-15, `6506514`)

[BRICKBENCH.md](BRICKBENCH.md) has the whole of it, under "figures on joints,
told where they decide". Every character session of the attach round chose how
to build at its first submit or check and was told of towers there. Now a
figure, a creature or a thing with a face is told each joint's one call in that
reply, in plan_scale, search_parts, the shapes guide and the review, with two
armatures to lay whole. The exact check's three verify.py gaps are closed: a
piece only the floor holds must settle on a bare floor, and the shapes are read
with the vertices their collider groups share.

**On ten held-out BrickBench prompts and the four characters again**, two designs
a prompt in each arm, 280 pairwise verdicts:

| | merge29 (`5c4708e`) | joints (`6506514`) | BrickAgent's Opus 5.5 |
|---|---|---|---|
| overall ELO (95%) | 809 (725-867) | 883 (811-949) | 1308 (1248-1406) |
| joints vs merge29, overall | | 67 of 112 (60%, 95% 51-68%) | |
| ...where it is told: characters, people scenes | | 22 of 32 (69%), 33 of 48 (69%) | |
| ...where it is not: four buildings | | 12 of 32 (38%, 23-55%) | |
| against BrickAgent, overall | 2 of 56 | 5 of 56 | |
| valid (their verify.py) | 26 of 28 | 27 of 28 | 14 of 14 |
| characters with a limb posed on a joint | 0 of 8 | 2 of 8 | |

**The car and the fire truck: a regression read, from a misfire.** Through
`run.py` on the merged tree before the last fix, round `2026-10-15-joints`:

| subject | design | 1-10 mean | overall ELO (95%) |
|---|---|---|---|
| speed_champions | 2026-10-15-joints/1 | 4.50 | 1245 (1163-1327) |
| speed_champions | 2026-10-15-joints/2 | 4.33 | 830 (740-918) |
| fire_truck | 2026-10-15-joints/1 | 5.67 | 1085 (957-1204) |
| fire_truck | 2026-10-15-joints/2 | 5.50 | 649 (564-777) |

`run.py rank` reads joints against attach at -126 overall (judge's 95% -199 to
-45; with the run-to-run spread -473 to +246). All four sessions were told they
were figures with nothing on a joint, in every check: "at minifigure scale" and
"with a firefighter" read as people. A vehicle now hears none of it; the two
subjects were not run again on the fixed code.

## Judged in pairs: what each round really did (2026-10-14)

The 1-10 judge's scores move by 0.7-1.0 between two designs of the same
code, so most rounds below were called inside the noise. BrickBench judges
its designs in pairs, and its judge agreed with 102 people on 34 of 36
pairs ([RESEARCH.md](RESEARCH.md), unit 4). `tools/bench/pairwise.py` brings
that method here, and every round so far has been judged again with it.
`run.py pairs`, `calibrate` and `rank` reproduce everything below; the
recipe is "The pairwise judge" in `.claude/skills/verify/features/assistant.md`.

**How it judges.**
- Two designs of one subject, each as its three views from the same cameras,
  with the subject's references and each design's build check.
- The pictures are copied under six-letter names, so no file name says which
  round made a design.
- The judge is Claude Opus 5.5 through Claude Code on the subscription, with
  the Read tool only. It must answer A or B on each of the six dimensions and
  overall, with a sentence of reason. Every one of its verdicts opened all six
  design pictures.
- Every pair is asked both ways round. Where the two orders disagree, the pair
  is a tie.
- Strengths are fitted per subject by Bradley-Terry, as BrickBench's `elo.py`
  does: Hunter's MM, with half a virtual tie between every two designs. They
  are given as ELO, 1000 being the subject's average design. A design 100
  above another is preferred 64% of the time, and 200 above, 76%.
- Intervals are 95%, from 1,000 resamplings of the pairs with both orders
  kept together.

**What it read.** Every design under `bench/results` that has its three views:
7 owls, 8 shops, 12 cars, 7 starfighters, 2 locomotives and 2 ships. Every
two designs of a subject, both ways: 138 pairs, 276 verdicts, about 22 s
each. The bust, the bonsai, the gatehouse, the Falcon Heavy, the crane and
the cabin have one design each, so nothing to compare.

### Is it right? Pairs whose answer is known

Each known pair is a model and a version of it that is worse in a way nobody
would argue with (`tools/bench/calibrate.py`). Both were drawn now by the same
renderer, and each pair was judged both ways, twice.
- **A real set against a naive stack of itself** (5 pairs): 75895 Porsche,
  10194 Emerald Night, 6286 schooner, 10281 bonsai and 75102 X-wing. The
  stack is the set's own shape in plain bricks, studs up, in its three
  commonest colours. The set should win every visual dimension and overall.
- **A design against itself with a fault put in** (19 pairs), on five recent
  designs: the steps round's shop and starfighter, the sides round's
  locomotive and owl, and the shapes round's car. The faults: every tile
  taken off (surface and overall); one tile in four taken off (the same at a
  quarter of the size); every part in its commonest colour (colour and
  overall); its figures and animals taken out (creativity).

The 1-10 judge scored the same pictures once each, with the same anchors as
every bench design; its overall is its mean.

| known pairs | known dimensions | the pairwise judge, both orders, twice | the 1-10 judge |
|---|---|---|---|
| a real set against its naive stack, 5 | 30 | 120 of 120 verdicts right | 30 higher |
| every tile off, one colour, no figures, 14 | 24 | 96 of 96 | 18 higher, 6 the same |
| one tile in four off, 5 | 10 | 40 of 40 | 4 higher, 4 the same, 2 lower |
| all 24 | 64 | 256 of 256 (95%: 99-100%) | 52 higher, 10 the same, 2 lower |

- **Agreement.** Every one of the 256 verdicts named the model without the
  fault, so every one of the 64 known dimensions was right in both orders and
  both times.
- **Its spread.** The two orders named the same design on 331 of 336
  dimension verdicts (99%). Asked again in the same order, 331 of 336 (99%).
  It picked the model shown first 337 times of 672 (50%).
- **Where the 1-10 judge falls short.** It tied creativity with and without
  the shop's and the starfighter's figures, and the locomotive's surface with
  and without its 50 tiles. With one tile in four off, it saw the fault on
  the starfighter and the car only. It scored the shop and the owl higher
  without those tiles (means 5.5 against 4.7, and 4.8 against 4.5).

**What it does not show.** Even the smaller fault is plain to see, and the
pairwise judge resolves every one. Its limit was not reached here; the
rounds' own designs, below, are where it splits. And on a pair that
differs in one thing, it names the better model on nearly every other
dimension as well: on the dimensions a fault was not meant to change, 399
of 416 verdicts (96%) went to the model without it. A forced choice between
two equals goes to the better model overall. So read overall first. A
dimension says where the judge sees the difference, not a measure
independent of the others.

### How much is the judge, how much the design

- **The judge alone.** Every starfighter and owl pair asked again gave the
  same answer on 90% and 95% of dimension verdicts. Fitted again, a design's
  overall ELO moved by 48 and 43 on average.
- **The two orders, over the rounds.** On the 138 pairs, both orders named
  the same design on 81% of dimension verdicts. The judge picked the model
  shown first 43% of the time. Asking both ways cancels that lean.
- **Run to run.** Four pairs of designs were made on the same code: the
  baseline's two owls, two shops and two cars, and the shapes round's two
  trial cars. Overall they are 160, 253, 251 and 384 ELO apart. Pooled, one
  design sits 194 ELO from its code's mean (likeness 134, surface 204). Four
  pairs are few: that 194 could be anything from 0.6 to 2.9 times itself.

The judge's own noise is about a quarter of a design's. Two designs of one
brief on the same code differ by as much as most rounds do. The judge can
tell designs apart; one design a round cannot tell a lever from luck.

### Every design, best first

Overall ELO. Each design's interval is about ±100 to ±200
(`run.py rank` prints them, and each dimension).

| subject | best first: round, overall ELO | agrees with the 1-10 order (Spearman) |
|---|---|---|
| starfighter | surface 1384, sides 1170, edges 1058, steps 1004, shapes 1004, d6 769, baseline 612 | 0.81 |
| corner_shop | sides 1408, steps 1264, surface 1097, baseline 1047, d6b 948, edges 847, baseline 793, d6 595 | 0.50 |
| barn_owl | d6 1324, edges 1324, sides 1124, steps 1004, surface 882, baseline 751, baseline 591 | 0.40 |
| speed_champions | shapes trial 1350, d6b 1224, shapes 1224, baseline 1188, edges 997, surface 967, shapes trial 967, baseline 936, edges-b 936, d6 737, steps 737, sides 737 | 0.70 |
| steam_locomotive | sides 1191, shapes 809 (one pair) | |
| sailing_ship | shapes 1191, sides 809 (one pair) | |

### Each lever

Each round against the round it was read against above, as the mean over the
subjects run in both, overall and on the dimension it aimed at. "Judge" is
the judge's own 95% interval: could it tell these designs apart? "Runs" adds
a design's luck, 194 ELO: is the lever real? Bold where that excludes 0.

| round | against | subjects | overall | judge | runs | its dimension | judge | runs | 1-10 mean |
|---|---|---|---|---|---|---|---|---|---|
| d6, the feature pass | baseline | 4 | +40 | -65, +114 | -225, +302 | technique +19 | -80, +96 | -212, +197 | +0.31 |
| d6b | d6 | 2 | **+420** | +255, +542 | +15, +805 | technique +569 | +420, +669 | +216, +818 | +0.58 |
| surface | baseline | 4 | +266 | +154, +330 | -10, +501 | surface +153 | +49, +223 | -146, +408 | +0.56 |
| edges | surface | 4 | -34 | -124, +69 | -297, +243 | surface -11 | -102, +95 | -280, +273 | -0.10 |
| steps | edges | 4 | -47 | -139, +52 | -318, +222 | surface +95 | -9, +181 | -176, +392 | +0.44 |
| sides | steps | 4 | +108 | +1, +189 | -196, +385 | surface -26 | -109, +69 | -321, +268 | -0.25 |
| shapes | sides | 4 | +69 | -72, +211 | -238, +360 | likeness +66 | -64, +194 | -152, +285 | +0.11 |

Each round against the baseline, overall:

| round | subjects | overall | judge | runs | 1-10 mean |
|---|---|---|---|---|---|
| d6 | 4 | +40 | -65, +114 | -225, +302 | +0.31 |
| d6b | 2 | +95 | -30, +208 | -243, +449 | +0.46 |
| surface | 4 | +266 | +154, +330 | -10, +501 | +0.56 |
| edges | 4 | +233 | +134, +289 | -42, +447 | +0.46 |
| steps | 4 | +186 | +71, +260 | -89, +427 | +0.90 |
| sides | 4 | **+294** | +192, +350 | +11, +536 | +0.65 |
| shapes | 2 | +255 | +125, +349 | -113, +594 | +0.73 |

**Reading it, honestly.**
- **Designs are better than the baseline's.** Every round from the surface
  round on is 186 to 294 ELO ahead of it, and the judge's own interval
  excludes 0 for each. With a design's luck in, only the sides round clears 0
  (+294, so its design is preferred to a baseline design about 85% of the
  time).
- **The surface round is where the step up came.** Against the baseline it is
  +266 overall, and the judge credits its likeness (+235), colour (+213) and
  creativity (+318) as much as its surface (+153). With luck in, its interval
  reaches -10. It also measures the staging branch it ran on, which the
  baseline did not have (d5b's process, the guidance head, design memory),
  not the surface pass alone.
- **Edges, steps and shapes are nulls, even to the judge alone.** Overall
  -34, -47 and +69, every interval across 0. Steps' +95 on surface is not
  resolved either (-9 to +181). The 1-10 judge had steps at +0.44; the
  pairwise judge does not see it.
- **Sides is a gain to the judge, not beyond luck.** +108 (+1 to +189), but
  -196 to +385 with a design's luck in. Most of it is creativity (+251) and
  likeness (+160), which the pass does not touch.
- **d6b is the largest step of any round, on two subjects.** +420 overall,
  +569 on technique, clearing 0 just (+15 to +805). Its car and its shop are
  all the evidence.
- **The two judges disagree where both are inside the noise.** The 1-10
  judge has sides at -0.25 and steps at +0.44; the pairwise judge has them
  at +108 and -47. Neither is resolved.

**What a round needs from now on.** The judge is not the limit any more; one
design a subject is. With one design a subject on four subjects, a lever has
to move about 270 ELO to show (1.96 x 194 x the square root of 2/4). To show
+200 (preferred 76%), design each subject twice in the round and twice in the
round it is read against. To show +100 (64%), about seven times. So the next
round runs with `--run 2` on four subjects, then `run.py pairs` and
`run.py rank`, and quotes its lever's interval with runs in it.

## 2026-10-12: commit 0ddfaab, b887e96, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| astronaut_bust | 1 | 5.0 | 3.0 | 4.0 | 3.0 | 5.0 | 8.0 | **4.7** | 1,153 | 1 |
| barn_owl | 2 | 4.0 | 4.0 | 4.0 | 4.0 | 4.0 | 9.0 | **4.8** | 633 | 1, 1 |
| bonsai | 1 | 4.0 | 3.0 | 4.0 | 3.0 | 2.0 | 8.0 | **4.0** | 213 | 1 |
| castle_gatehouse | 1 | 5.0 | 3.0 | 5.0 | 3.0 | 5.0 | 8.0 | **4.8** | 1,317 | 1 |
| corner_shop | 2 | 5.0 | 4.0 | 5.0 | 4.0 | 3.5 | 8.0 | **4.9** | 967 | 1, 1 |
| falcon_heavy | 1 | 6.0 | 6.0 | 5.0 | 4.0 | 5.0 | 8.0 | **5.7** | 350 | 1 |
| mobile_crane | 1 | 4.0 | 3.0 | 4.0 | 3.0 | 4.0 | 4.0 | **3.7** | 244 | 16 |
| mountain_cabin | 1 | 4.0 | 3.0 | 4.0 | 3.0 | 4.0 | 8.0 | **4.3** | 213 | 1 |
| speed_champions | 2 | 3.0 | 4.0 | 3.0 | 3.0 | 3.0 | 10.0 | **4.3** | 161 | 2, 2 |
| starfighter | 1 | 5.0 | 4.0 | 5.0 | 4.0 | 4.0 | 4.0 | **4.3** | 204 | 10 |
| **suite mean** | 13 | **4.5** | **3.7** | **4.3** | **3.4** | **4.0** | **7.5** | **4.6** |  |  |

Run to run, the same subject designed again on the same code (each cell is run 1 / run 2 ...):

| subject | likeness | surface | colour | technique | creative | build | mean |
|---|---|---|---|---|---|---|---|
| barn_owl | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 | 5 / 3 | 10 / 8 | 5.2 / 4.5 |
| corner_shop | 5 / 5 | 4 / 4 | 5 / 5 | 4 / 4 | 4 / 3 | 8 / 8 | 5.0 / 4.8 |
| speed_champions | 3 / 3 | 4 / 4 | 3 / 3 | 3 / 3 | 3 / 3 | 10 / 10 | 4.3 / 4.3 |

Mean spread between runs, per dimension: likeness 0.0, surface 0.0, colour 0.0, technique 0.0, creative 1.0, build 0.7; of a subject's mean score, 0.28 (standard deviation 0.20). A change to a subject's mean smaller than the spread is not yet a result.

The judge alone, the same pictures judged twice (10 runs), mean difference per dimension: likeness 0.2, surface 0.1, colour 0.3, technique 0.3, creative 0.2, build 0.0; of the mean score, 0.08.

Weakest across the suite: **technique** (3.4), **surface** (3.7), **creativity** (4.0).

**What the baseline says.** Thirteen designs of next3 (`0ddfaab`; `b887e96` is
the same app code with the bench's own files added), each 3-22 minutes of
Claude Code on the subscription, 150-1,300 parts, 19-65 shapes, 42-91% plain
bricks and plates by `tools/style.py`. Against the anchors, the suite sits at
4.6, nearer the naive brick stack (2) than LEGO's MINI (9), from the crane
(3.7) to the Falcon Heavy (5.7). Every run left a model; none timed out.

The three weakest dimensions are what the next design rounds should attack:

1. **Technique (3.4).** In the judge's words on every subject: "almost all
   stacked bricks and plates", no SNOT side-building, no angled sub-assemblies,
   no hinges or clips. The crane's functions are suggested, not built (no
   turntable, no gearing, a "telescoping" boom of two stacked sections); the
   starfighter's wings are angled but held by nothing (10 pieces).
2. **Surface (3.7).** Open fields of studs on roofs, decks, wing tops and
   bases, and staircases where a curve should be (the bonsai's trunk, the
   gatehouse's tower roofs, the astronaut's helmet, the cabin's roof). The one
   6 is the Falcon Heavy, the subject the round pattern lays in round parts.
3. **Creativity (4.0).** Figures and set dressing are there (a mouse for the
   owl, guards on the gatehouse, an astromech); a play or display feature is
   not: no portcullis that raises, no wings that open, no separable boosters,
   and the bonsai (2) has nothing beyond the tree.

**How big a change must be.** The judge alone, the same pictures judged
twice, moves a subject's mean by 0.08; designed again on the same code, by
0.28 (three subjects, two runs each; dimensions moved by 0 or 1, creativity
and buildability most). So a round moves a subject when its mean moves by
more than about 0.3, and the suite when its mean moves by more than about
0.2 (twice the standard deviation of a difference between two suite means:
0.20 x 1.4 / 3.2). The five visual scores so far fall between 2 and 6:
read a one-point move in one dimension on several subjects as real, and a
one-point move on one subject as noise.

**One fault in the stick itself.** Buildability (7.5) is the strongest
dimension, but its scores below 10 are mostly not about building. The
rubric takes 2 points for a fault the build check names, and the check's
picture faults were written for Orthanc: "a yard for a base" in 5 of the 13
runs (three of them the stand the brief asked for), and "sky through a
slit" in 4 more, which the probe itself lets pass because `orthanc.ldr` has
it too. Only the crane (16 pieces) and the starfighter (10) are truly loose.
It does not change the weakest three; but before a round chases
buildability, the check should know a display stand, and the rubric should
count only the faults the probe fails on.

## 2026-10-13: the baseline re-scored after the build check was fixed (26ddb89)

The same 13 designs, their pictures and style kept; only the build check and
the judge run again. The check had misread parts tipped on a flat axis (hinged
wings, a raised boom) and fired two picture faults written for Orthanc, so
build was under-scored. This corrects the measure, not the designs: build
went from 7.5 to 10 and the suite mean from 4.6 to 5.1, and the other five
dimensions moved within the noise. Compare later rounds with this table.


| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| astronaut_bust | 1 | 5.0 | 4.0 | 4.0 | 4.0 | 5.0 | 10.0 | **5.3** | 1,153 | 1 |
| barn_owl | 2 | 4.0 | 3.5 | 4.0 | 4.0 | 4.0 | 10.0 | **4.9** | 633 | 1, 1 |
| bonsai | 1 | 4.0 | 3.0 | 4.0 | 2.0 | 2.0 | 10.0 | **4.2** | 213 | 1 |
| castle_gatehouse | 1 | 5.0 | 3.0 | 5.0 | 4.0 | 5.0 | 10.0 | **5.3** | 1,317 | 1 |
| corner_shop | 2 | 4.5 | 3.5 | 4.5 | 3.5 | 3.0 | 10.0 | **4.8** | 967 | 1, 1 |
| falcon_heavy | 1 | 6.0 | 6.0 | 5.0 | 5.0 | 5.0 | 10.0 | **6.2** | 350 | 1 |
| mobile_crane | 1 | 4.0 | 3.0 | 4.0 | 3.0 | 4.0 | 10.0 | **4.7** | 244 | 3 |
| mountain_cabin | 1 | 4.0 | 3.0 | 5.0 | 3.0 | 4.0 | 10.0 | **4.8** | 213 | 1 |
| speed_champions | 2 | 3.5 | 4.5 | 3.5 | 3.5 | 3.0 | 10.0 | **4.7** | 161 | 2, 2 |
| starfighter | 1 | 6.0 | 4.0 | 5.0 | 4.0 | 5.0 | 10.0 | **5.7** | 204 | 2 |
| **suite mean** | 13 | **4.6** | **3.8** | **4.4** | **3.6** | **4.0** | **10.0** | **5.1** |  |  |

Run to run, the same subject designed again on the same code (each cell is run 1 / run 2 ...):

| subject | likeness | surface | colour | technique | creative | build | mean |
|---|---|---|---|---|---|---|---|
| barn_owl | 4 / 4 | 3 / 4 | 4 / 4 | 4 / 4 | 5 / 3 | 10 / 10 | 5.0 / 4.8 |
| corner_shop | 4 / 5 | 3 / 4 | 4 / 5 | 3 / 4 | 3 / 3 | 10 / 10 | 4.5 / 5.2 |
| speed_champions | 3 / 4 | 4 / 5 | 3 / 4 | 3 / 4 | 3 / 3 | 10 / 10 | 4.3 / 5.0 |

Mean spread between runs, per dimension: likeness 0.7, surface 1.0, colour 0.7, technique 0.7, creative 0.7, build 0.0; of a subject's mean score, 0.50 (standard deviation 0.28). A change to a subject's mean smaller than the spread is not yet a result.

Weakest across the suite: **technique** (3.6), **surface** (3.8), **creativity** (4.0).

## 2026-10-12-creative: a creative pass at the end of every design (482576f)

Every design now ends with a turn of its own for touches: it proposes three
for its subject (a story, a play or display feature, a nod only someone who
knows it would catch) and adds the best one or two, small and joined. From
outside, the build's answer, `review_model {"creative": true}` and saving
hand it over. Four subjects, one run each, on the fixed build check (26ddb89),
against the re-scored baseline above.

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| bonsai | 1 | 6.0 | 4.0 | 6.0 | 4.0 | 5.0 | 10.0 | **5.8** | 213 | 1 |
| corner_shop | 1 | 6.0 | 4.0 | 6.0 | 4.0 | 6.0 | 10.0 | **6.0** | 1,212 | 1 |
| mountain_cabin | 1 | 5.0 | 3.0 | 5.0 | 4.0 | 6.0 | 10.0 | **5.5** | 308 | 1 |
| speed_champions | 1 | 3.0 | 3.0 | 4.0 | 3.0 | 4.0 | 6.0 | **3.8** | 165 | 2 |
| **suite mean** | 4 | **5.0** | **3.5** | **5.2** | **3.8** | **5.2** | **9.0** | **5.3** |  |  |

Before and after, the same four subjects (baseline re-scored / this round):

| subject | likeness | surface | colour | technique | creative | build | mean |
|---|---|---|---|---|---|---|---|
| bonsai | 4 / 6 | 3 / 4 | 4 / 6 | 2 / 4 | **2 / 5** | 10 / 10 | 4.2 / 5.8 |
| corner_shop | 4.5 / 6 | 3.5 / 4 | 4.5 / 6 | 3.5 / 4 | **3 / 6** | 10 / 10 | 4.8 / 6.0 |
| mountain_cabin | 4 / 5 | 3 / 3 | 5 / 5 | 3 / 4 | **4 / 6** | 10 / 10 | 4.8 / 5.5 |
| speed_champions | 3.5 / 3 | 4.5 / 3 | 3.5 / 4 | 3.5 / 3 | **3 / 4** | 10 / 6 | 4.7 / 3.8 |
| the four | 4.0 / 5.0 | 3.5 / 3.5 | 4.2 / 5.2 | 3.0 / 3.8 | **3.0 / 5.2** | 10 / 9 | 4.6 / 5.3 |

Creativity rose on all four, by 3, 3, 2 and 1, against a run-to-run spread
of 0.7. Every session called the pass, and the judge's creative reason names
what it added each time: pink birds in the bonsai's canopy and a frog in its
soil; a bicycle, a grocer and customers at the shop; a fish and a duck by the
cabin's jetty; the Porsche's driver standing by it with a trophy. None of the
four added a play feature or a clever use of a part, and the judge says so in
each; that is the next thing to push.

What this does not show. The baseline ran before next3's feature pass and the
guidance head (6440b60), so the other dimensions moved with those as well;
creativity is the one this round can claim. An intermediate run on 29592be
(the feature pass, no creative pass) scored speed_champions 3 for creativity,
as the baseline did. The Porsche's lower likeness, surface and build are its
hand-built chassis and body (build: axle 3707 carries 119 g on one stud); the
pass added only the driver, named apart. One run a subject is one sample.

## 2026-10-12-d5: commit 29592be, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 1 | 4.0 | 3.0 | 4.0 | 4.0 | 5.0 | 8.0 | **4.7** | 620 | 1 |
| speed_champions | 1 | 3.0 | 4.0 | 3.0 | 3.0 | 3.0 | 6.0 | **3.7** | 175 | 2 |
| **suite mean** | 2 | **3.5** | **3.5** | **3.5** | **3.5** | **4.0** | **7.0** | **4.2** |  |  |

Weakest across the suite: **likeness** (3.5), **surface** (3.5), **colour** (3.5).

## 2026-10-12-d5b: commit 6440b60, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 1 | 4.0 | 4.0 | 4.0 | 4.0 | 4.0 | 8.0 | **4.7** | 1,132 | 1 |
| corner_shop | 1 | 5.0 | 4.0 | 5.0 | 4.0 | 5.0 | 8.0 | **5.2** | 973 | 1 |
| speed_champions | 1 | 3.0 | 3.0 | 3.0 | 2.0 | 3.0 | 10.0 | **4.0** | 153 | 2 |
| **suite mean** | 3 | **4.0** | **3.7** | **4.0** | **3.3** | **4.0** | **8.7** | **4.6** |  |  |

Weakest across the suite: **technique** (3.3), **surface** (3.7), **likeness** (4.0).

**What the design5 batches say.** `2026-10-12-d5` is the feature process and
faces on shells (29592be); `2026-10-12-d5b` adds the guidance head a Claude
Code session can actually read, the feature chain and tiled face discs
(6440b60). Both ran on the build check before 26ddb89, so their build
column is not comparable with the re-scored baseline (build 10 everywhere)
and is left out here. Against that re-scored baseline, the five visual
dimensions (likeness / surface / colour / technique / creative):

| subject | baseline, 2 runs | d5 | d5b |
|---|---|---|---|
| barn_owl | 4.0 / 3.5 / 4.0 / 4.0 / 4.0 | 4 / 3 / 4 / 4 / 5 | 4 / 4 / 4 / 4 / 4 |
| speed_champions | 3.5 / 4.5 / 3.5 / 3.5 / 3.0 | 3 / 4 / 3 / 3 / 3 | 3 / 3 / 3 / 2 / 3 |
| corner_shop | 4.5 / 3.5 / 4.5 / 3.5 / 3.0 | — | 5 / 4 / 5 / 4 / 5 |

One run each, so no single cell is a result (the baseline's run-to-run
spread is 0.28 of a subject's mean, a whole point on creativity). Read
together: the owl did not move, the shop rose half a point on four
dimensions and two on creativity, and the car fell — its two runs hand-built
studs-up again, technique 2 in the second. Not progress on the bench yet; what
moved is that sessions now follow the process (they read the guide, review,
and work features), where before none worked a single feature.

## 2026-10-13-d6: commit 0b72f7f, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 1 | 5.0 | 4.0 | 4.0 | 5.0 | 5.0 | 10.0 | **5.5** | 1,019 | 1 |
| corner_shop | 1 | 4.0 | 4.0 | 4.0 | 3.0 | 4.0 | 10.0 | **4.8** | 786 | 1 |
| speed_champions | 1 | 3.0 | 3.0 | 3.0 | 3.0 | 3.0 | 10.0 | **4.2** | 157 | 2 |
| starfighter | 1 | 5.0 | 3.0 | 5.0 | 4.0 | 4.0 | 10.0 | **5.2** | 479 | 2 |
| **suite mean** | 4 | **4.2** | **3.5** | **4.0** | **3.8** | **4.0** | **10.0** | **4.9** |  |  |

Weakest across the suite: **surface** (3.5), **technique** (3.8), **colour** (4.0).

**What d6 says: the app-driven feature pass (0b72f7f).** The app now works
each feature with the design instead of telling it which feature is next. It
looks up how real sets built the feature, lays the best piece that lays whole
where the feature goes, and hands it over with a picture. The session settles
it with `settle_feature`: accept it (moved, turned or recoloured first), ask
for the next, reject it with a reason, or say it built the feature itself.
Saving refuses until every feature is settled. The four subjects against the
re-scored baseline and the earlier rounds (likeness / surface / colour /
technique / creative):

| subject | baseline (re-scored) | d5 | d5b | creative | d6 |
|---|---|---|---|---|---|
| barn_owl | 4 / 3.5 / 4 / 4 / 4 | 4 / 3 / 4 / 4 / 5 | 4 / 4 / 4 / 4 / 4 | — | 5 / 4 / 4 / **5** / 5 |
| speed_champions | 3.5 / 4.5 / 3.5 / 3.5 / 3 | 3 / 4 / 3 / 3 / 3 | 3 / 3 / 3 / 2 / 3 | 3 / 3 / 4 / 3 / 4 | 3 / 3 / 3 / 3 / 3 |
| corner_shop | 4.5 / 3.5 / 4.5 / 3.5 / 3 | — | 5 / 4 / 5 / 4 / 5 | 6 / 4 / 6 / 4 / 6 | 4 / 4 / 4 / 3 / 4 |
| starfighter | 6 / 4 / 5 / 4 / 5 | — | — | — | 5 / 3 / 5 / 4 / 4 |
| the four | 4.5 / 3.9 / 4.3 / 3.75 / 3.75 | | | | 4.2 / 3.5 / 4.0 / 3.75 / 4.0 |

**Technique and surface did not move.** Over the four subjects, technique went
from 3.75 to 3.75 and surface from 3.9 to 3.5, against a run-to-run spread of
0.7 and 1.0. The owl is the only cell outside the noise: technique 5, the
first owl at 5 in five runs. The judge credits the face disc laid sideways
and the wing panels hung at an angle, and it is one run. The shop came out
below its d5b and creative runs on every visual dimension. The car hand-built
a boxy body again. Renders: `bench/results/2026-10-13-d6/*/1/views_*.png` in
the main checkout.

**What did change is behaviour.** Every session settled every feature: 20 of
20, against 2 of 6 in d5b. None was refused at the save, because the walk
handed each feature over before the save was reached. But not one of the 20
pieces the app laid was accepted: 10 were rejected with a reason and 10 were
marked "built". The reasons say why:
- **Most were about placement.** The awning and the sign were laid "inside
  the flat"; the starfighter's canopy "on the cockpit floor where nobody can
  see it"; its exhausts "on top of the fuselage, not on the engines"; the
  car's headlamps "on the door tops by the windscreen". Every session gave
  every feature a position (x, y, z, facing), so the spots were right. What
  went wrong was the seat: the fit took the free stud nearest the spot,
  anywhere within seven studs of it. That turned out to be an interior
  floor, the cockpit floor or the top of the fuselage.
- **The rest were the wrong piece.** A robot lion's paw for an owl's talons,
  "a generic racer tail in blue and white", two tan plates for a cornice.
  The corpus has no owl or 911 of this scale.
- **"Built" is an easy way out.** It needs only a sentence. The shop said it
  had built its corner door, and the judge saw no corner door.

What the judge still says is missing, in its words. Technique: "mostly plain
stacked bricks" and "no SNOT detailing, no angled corner sub-assembly" (shop);
"plain bricks and plates stacked studs-up … no brackets or hinged
sub-assemblies shaping the wings, nose or roofline" (car). Surface: "the whole
roof is a large expanse of exposed studs" (shop); "every surface is a flat slab
meeting the next at a right angle" (car); "the body is a straight-sided box"
(owl).

## 2026-10-13-d6b: commit 8dc02d3, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| corner_shop | 1 | 5.0 | 5.0 | 5.0 | 4.0 | 4.0 | 10.0 | **5.5** | 934 | 1 |
| speed_champions | 1 | 3.0 | 4.0 | 4.0 | 4.0 | 3.0 | 10.0 | **4.7** | 154 | 2 |
| **suite mean** | 2 | **4.0** | **4.5** | **4.5** | **4.0** | **3.5** | **10.0** | **5.1** |  |  |

Weakest across the suite: **creativity** (3.5), **likeness** (4.0), **technique** (4.0).

**What d6b says: the follow-ups (8dc02d3).** The batch ran the car and the shop
again with three changes. A shape can now lay its own wheels. "Built" takes
the app's piece off. And a piece is seated only on the model's outside. Before
and after (likeness / surface / colour / technique / creative):

| subject | baseline (re-scored) | d6 | d6b |
|---|---|---|---|
| speed_champions | 3.5 / 4.5 / 3.5 / 3.5 / 3 (4.7) | 3 / 3 / 3 / 3 / 3 (4.2) | 3 / 4 / 4 / 4 / 3 (4.7) |
| corner_shop | 4.5 / 3.5 / 4.5 / 3.5 / 3 (4.8) | 4 / 4 / 4 / 3 / 4 (4.8) | 5 / 5 / 5 / 4 / 4 (5.5) |

The shop's surface 5 is its best so far, and technique 4 matches its best
(d5b, creative). Each is one run, and a one-point move on one subject is
inside the noise. The car is back to its baseline and no higher.

What the car did is the finding. It said its body as a shape with `"wheels":
[4, 15]`, and the shape stood: built, 177 and 208 parts, where every earlier
shaped car floated or overlapped its tyres. Then it rebuilt the body by hand
anyway: "the second try came out blockier", "the generated body was coming out
lopsided". It kept the wheel units. The judge credits it with mudguards, a
curved windscreen and a curved fastback slope, but still calls it "a generic
boxy red car". So the shape is now buildable on wheels, but its look at this
size (stepped flanks, studs round the cowl, the cabin) does not yet beat a
hand build.

The shop rejected two of the app's pieces, the sign and the awning, as "laid
inside the upstairs flat" again. Seats on the outside were not enough: a ray
out through a window, or up through a flat with no roof over it, reads as the
outside. 83f152e also keeps a seat within four studs of the spot and a stud and
a half of its face, but no batch has measured that yet. Not one of the app's
pieces has been accepted in either batch.

## 2026-10-13-surface: commit 62376c9, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 1 | 4.0 | 4.0 | 4.0 | 4.0 | 4.0 | 10.0 | **5.0** | 992 | 1 |
| corner_shop | 1 | 5.0 | 6.0 | 5.0 | 4.0 | 4.0 | 4.0 | **4.7** | 1,159 | 12 |
| speed_champions | 1 | 3.0 | 4.0 | 3.0 | 3.0 | 4.0 | 10.0 | **4.5** | 169 | 2 |
| starfighter | 1 | 6.0 | 6.0 | 5.0 | 6.0 | 6.0 | 10.0 | **6.5** | 495 | 1 |
| **suite mean** | 4 | **4.5** | **5.0** | **4.2** | **4.2** | **4.5** | **8.5** | **5.2** |  |  |

Weakest across the suite: **colour** (4.2), **technique** (4.2), **likeness** (4.5).

**What the surface round says: an app-driven surface pass (62376c9).** Once a
design stands and its features and assemblies have had their turns, the app
reads the model's open studs exactly (nothing on them, nothing within a brick
over them, seen from above or from two sides; in each section's own frame
too) and lays real pieces on it as a proposal: tiles in the part's colour,
largest first, with a grille, ingot or jumper on a big field; slopes over a
stud staircase; masonry and turned-out studs in a long plain wall. The
session sees one picture with each finding marked and settles each with
`settle_surface` (accept, reject with a reason, keep the studs). Yards,
mosaics and the ground are left; the ground is offered, laid only on "tile".
Held out and on the subscription as every batch; this branch is staging
(2beda06) and does not have d6's app-driven feature pass. The five visual
scores (likeness / surface / colour / technique / creative) against the
re-scored baseline, d6 and d6b:

| subject | baseline (re-scored) | d6 | d6b | surface |
|---|---|---|---|---|
| corner_shop | 4.5 / 3.5 / 4.5 / 3.5 / 3 | 4 / 4 / 4 / 3 / 4 | 5 / 5 / 5 / 4 / 4 | 5 / **6** / 5 / 4 / 4 |
| starfighter | 6 / 4 / 5 / 4 / 5 | 5 / 3 / 5 / 4 / 4 | — | 6 / **6** / 5 / 6 / 6 |
| barn_owl | 4 / 3.5 / 4 / 4 / 4 | 5 / 4 / 4 / 5 / 5 | — | 4 / 4 / 4 / 4 / 4 |
| speed_champions | 3.5 / 4.5 / 3.5 / 3.5 / 3 | 3 / 3 / 3 / 3 / 3 | 3 / 4 / 4 / 4 / 3 | 3 / 4 / 3 / 3 / 4 |
| the four | 4.5 / 3.9 / 4.25 / 3.75 / 3.75 | 4.25 / 3.5 / 4.0 / 3.75 / 4.0 | | 4.5 / **5.0** / 4.25 / 4.25 / 4.5 |

**Surface moved on the two subjects with open studs, and not on the two
without.** The shop went to 6 (3.5, 4 and 5 before) and the starfighter to 6
(4 and 3), each more than the surface run-to-run spread of 1.0. In the judge's
words: "the roof, cornice and pavement are fully tiled" on the shop, where d6's
was "a large expanse of exposed studs"; "wings and hull are mostly tiled" on
the starfighter, where d6's wings were "open fields of studded white plates".
The owl (4) and the car (4) did not move, as predicted before the batch: the
pass found 4 fields on the owl and nothing on the car, because their faults
are not open studs. Over the four, surface is 5.0 against 3.9 and 3.5, the
first round to move it beyond the noise; one run a subject, so two subjects carry it.

**Behaviour.** All four sessions ran the pass after their assemblies and
before the creative pass, and accepted every finding ("all"): 12 on the shop
(699 studs and a wall), 4 on the owl (347 studs), 12 on the starfighter (432
studs, its wings in sections among them), none on the car. None rejected or
kept anything. The shop's session put street furniture on its pavement first,
then asked for the ground (G1) to be tiled; the pass refused where something
already stood and tiled around it on a second review. Its creative figures
first landed on the tiled roof (add_minifig stands a figure on the highest
surface) and the session moved them.

**The shop's build of 4 is not the pass.** It is 12 pieces: the session laid
its base as 137 loose 4 x 6 plates on the app's floor, and the pavement's
plates are joined to nothing of the building. The tiles join some of them to
each other: the same model without its 76 ground tiles is 24 pieces. The
starfighter's technique and creativity (6 and 6) also rose; one run, and not
the pass's doing.

**The next lever, from the critiques.** What is left is not open studs but
steps and right angles on what is already smooth: the car's "stepped rear
deck ... square corners ... no curved slopes", the owl's "head is a
hard-edged cube" and breast "stepped and patchy", the starfighter's "nose
climbs in visible stepped layers" and "hull sides are flat slab walls", the
shop's "broad flat expanses of tan brick". The pass handles stud staircases
only. Next: tiled staircases (a tread's tiles off, a slope or curved slope on
the studs under them) and rounded edges where a body turns (curved slopes and
wedge plates along a top edge or an outline that steps; the check already
names the latter), proposed and settled the same way.

## 2026-10-13-edges: commit e06ac7f, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 1 | 5.0 | 4.0 | 4.0 | 4.0 | 4.0 | 10.0 | **5.2** | 808 | 1 |
| corner_shop | 1 | 5.0 | 5.0 | 5.0 | 4.0 | 4.0 | 4.0 | **4.5** | 1,167 | 64 |
| speed_champions | 1 | 3.0 | 4.0 | 4.0 | 3.0 | 3.0 | 10.0 | **4.5** | 168 | 2 |
| starfighter | 1 | 6.0 | 5.0 | 5.0 | 5.0 | 5.0 | 10.0 | **6.0** | 352 | 1 |
| **suite mean** | 4 | **4.8** | **4.5** | **4.5** | **4.0** | **4.0** | **8.5** | **5.0** |  |  |

Weakest across the suite: **technique** (4.0), **creativity** (4.0), **surface** (4.5).

## 2026-10-13-edges-b: commit fcc308e, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| speed_champions | 1 | 3.0 | 4.0 | 4.0 | 3.0 | 4.0 | 10.0 | **4.7** | 194 | 2 |
| **suite mean** | 1 | **3.0** | **4.0** | **4.0** | **3.0** | **4.0** | **10.0** | **4.7** |  |  |

Weakest across the suite: **likeness** (3.0), **technique** (3.0), **surface** (4.0).

**What the edges rounds say: tiled steps and hard top edges (e06ac7f,
fcc308e).** The surface pass also covers staircases whose treads are tiles:
the tread tiles come off and the slopes go on. On anything that is not a
building, it also crowns a flat top whose edges drop away: curved slopes
(15068, 11477) run along each such edge, falling outward, and the rest of
the top is raised flush with a plate and tiles. Only the top's tiles are
taken off, and any finding that takes parts off may not leave the model in
more pieces. Against the surface round and earlier (likeness / surface /
colour / technique / creative):

| subject | baseline (re-scored) | d6 | d6b | surface | edges |
|---|---|---|---|---|---|
| corner_shop | 4.5 / 3.5 / 4.5 / 3.5 / 3 | 4 / 4 / 4 / 3 / 4 | 5 / 5 / 5 / 4 / 4 | 5 / 6 / 5 / 4 / 4 | 5 / 5 / 5 / 4 / 4 |
| starfighter | 6 / 4 / 5 / 4 / 5 | 5 / 3 / 5 / 4 / 4 | — | 6 / 6 / 5 / 6 / 6 | 6 / 5 / 5 / 5 / 5 |
| barn_owl | 4 / 3.5 / 4 / 4 / 4 | 5 / 4 / 4 / 5 / 5 | — | 4 / 4 / 4 / 4 / 4 | 5 / 4 / 4 / 4 / 4 |
| speed_champions | 3.5 / 4.5 / 3.5 / 3.5 / 3 | 3 / 3 / 3 / 3 / 3 | 3 / 4 / 4 / 4 / 3 | 3 / 4 / 3 / 3 / 4 | 3 / 4 / 4 / 3 / 3, and b: 3 / 4 / 4 / 3 / 4 |

**A null, honestly, and it holds the surface round's gain.** Surface was 5, 5,
4 and 4, against 6, 6, 4 and 4 in the surface round. Every cell is within the
1.0 run-to-run spread, so this lever neither helped nor hurt on the bench.
Over the four, surface is 4.5, against the surface round's 5.0, d6's 3.5 and
the baseline's 3.9. Only part of the lever reached the designs:
- The starfighter crowned two tops. The judge still says "the nose steps down
  in layers", and studs remain "along the dark-red wing stripes": only twelve
  findings are laid at a time, and the session did not ask for the rest.
- The car found nothing to round. It read the design's description, where
  "roof" counted as a building word. The same model, read as a car, had three
  tops rounded. Fixed in fcc308e, which reads the name only. Run again on
  that commit (edges-b), it crowned two tops and rejected a third, the first
  rejection in either round. Surface stayed at 4: "stepped edges where the
  911's rounded wings and fastback should flow", "flanks ... walls of stacked
  plain bricks", "exposed studs on the bonnet".
- The owl had nothing the pass would finish. Its open studs lie among a
  figure or an animal (yards), or are not open: something stands within a
  brick of them.
- The shop is a building, so it has no edges. Its build is 4 again: 64
  pieces. The session laid its base as loose plates on the floor (35 pieces
  without the pass), and the pass tiled the floor baseplate's own studs when
  the session asked for its ground. When the floor went back to scenery,
  those 29 tiles were left lying loose. fcc308e no longer finishes a
  baseplate's studs.

**Next, from the critiques: the plate-high steps need their own finding.**
On every body that is not a building, the stepped fault the judge names is a
plate high:
- the starfighter's nose "steps down in layers";
- the car's "stepped edges where the rounded wings and fastback should
  flow";
- the owl's breast "bands of tiles meet in hard steps", and its head and
  wings are "a stepped, jagged layering of plates".
The staircase cover skips a one-plate rise, because no slope is a plate
tall. The real answer takes two plate steps at a time: a curved slope two
plates tall (11477, 15068) laid over each pair of one-stud treads, cut and
re-laid the way the crown is. After that come the flanks ("walls of stacked
plain bricks"), which want sideways building, not a top.

## 2026-10-13-steps: commit dac9143, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 1 | 4.0 | 4.0 | 4.0 | 4.0 | 5.0 | 10.0 | **5.2** | 1,041 | 1 |
| corner_shop | 1 | 6.0 | 6.0 | 6.0 | 5.0 | 5.0 | 10.0 | **6.3** | 1,111 | 1 |
| speed_champions | 1 | 3.0 | 3.0 | 4.0 | 3.0 | 3.0 | 10.0 | **4.3** | 150 | 2 |
| starfighter | 1 | 6.0 | 6.0 | 5.0 | 6.0 | 4.0 | 10.0 | **6.2** | 464 | 2 |
| **suite mean** | 4 | **4.8** | **4.8** | **4.8** | **4.5** | **4.2** | **10.0** | **5.5** |  |  |

Weakest across the suite: **creativity** (4.2), **technique** (4.5), **likeness** (4.8).

**What the steps round says: plate steps, flank skins, every finding laid,
masonry only on a building (dac9143).** The surface pass gained four things.
Steps a plate high are taken two at a time: one curved slope two plates tall
over each pair, with the upper tread's plate cut under it. A body's flank of
plain bricks gets a skin on its side: a course laid again with its studs
turned out, plates and tiles on them, and a curved slope at each end. Every
finding is laid at once (up to 40, not 12). A building's long walls get
masonry and no studs turned out. Held out and on the subscription, one run a
subject, design memory on. Against the earlier rounds (likeness / surface /
colour / technique / creative):

| subject | baseline (re-scored) | d6 | surface | edges | steps |
|---|---|---|---|---|---|
| corner_shop | 4.5 / 3.5 / 4.5 / 3.5 / 3 | 4 / 4 / 4 / 3 / 4 | 5 / 6 / 5 / 4 / 4 | 5 / 5 / 5 / 4 / 4 | 6 / 6 / 6 / 5 / 5 |
| starfighter | 6 / 4 / 5 / 4 / 5 | 5 / 3 / 5 / 4 / 4 | 6 / 6 / 5 / 6 / 6 | 6 / 5 / 5 / 5 / 5 | 6 / 6 / 5 / 6 / 4 |
| barn_owl | 4 / 3.5 / 4 / 4 / 4 | 5 / 4 / 4 / 5 / 5 | 4 / 4 / 4 / 4 / 4 | 5 / 4 / 4 / 4 / 4 | 4 / 4 / 4 / 4 / 5 |
| speed_champions | 3.5 / 4.5 / 3.5 / 3.5 / 3 | 3 / 3 / 3 / 3 / 3 | 3 / 4 / 3 / 3 / 4 | 3 / 4 / 4 / 3 / 3 | 3 / 3 / 4 / 3 / 3 |
| the four | 4.5 / 3.9 / 4.25 / 3.75 / 3.75 | 4.25 / 3.5 / 4.0 / 3.75 / 4.0 | 4.5 / 5.0 / 4.25 / 4.25 / 4.5 | 4.75 / 4.5 / 4.5 / 4.0 / 4.0 | 4.75 / 4.75 / 4.75 / 4.5 / 4.25 |

**On surface, a null.** Surface is 6, 6, 4 and 3. The surface round had 6, 6,
4 and 4, and the edges round 5, 5, 4 and 4. Every cell is within the 1.0
run-to-run spread. Over the four it is 4.75, between the surface round's 5.0
and the edges round's 4.5. The suite mean is 5.5, the highest of any round
(the surface round 5.2, edges 5.0, d6 4.9). That rests mostly on the shop,
whose 6.3 is its best (likeness, surface and colour 6, built whole). It is
one run a subject, so treat it as a mean inside its noise.

**What reached the designs, from each design's log:**
- **Plate steps reached none.** No design had a pair laid: not one staircase
  among the four runs' findings. The lever works on a stepped model: run on
  the edges round's starfighter (`design.ldr`), the same pass lays two
  plate-step staircases in 7302s and one crown, all in one edit, and the
  model stays one piece. But the steps the judge names now are on the sides,
  not the tops: the starfighter's "fuselage sides are a terrace of stacked
  plates", the owl's "head and body are rough, stepped blocks". A pass that
  reads up-facing studs and tiles cannot see them.
- **Flank skins reached two, and hurt one.** The car got two skins, and the
  owl two on the grey of its perch. The car's were laid on the black course
  between its wheels, under the red body, and the judge saw them: "the black
  slabs between the wheels hang below the body like blocks". The flanks the judge
  faults are built of plates ("flanks and tail are plain brick walls", the
  starfighter's terrace of plates). A skin hung on a course of bricks cannot
  read those either. The car's surface fell to 3 (4 in the surface and
  edges rounds), inside the noise, but the critique names the skin.
- **Laying every finding reached two.** The shop laid 28 findings in one edit
  (710 studs tiled, 5 walls) and the starfighter 14 (522 studs, 3 tops
  rounded). The starfighter's "rows of exposed studs along the dark-red wing
  stripes" from the edges round is gone. What it still names, "the nose tip
  and wing tops still show exposed studs", are groups under four studs that
  the pass leaves as detail.
- **Masonry only reached the shop.** Its 5 walls got masonry and no turned-out
  studs. "Odd studs and stud-up knobs poke out of the tan facade" is gone.
  Now it says "masonry-profile texture in places" and "little relief". Its
  build of 10, against 4 in the surface and edges rounds, is the session's
  doing: its base was not loose plates this time.

**Next.** First, the sides of bodies built of plates: a terrace of offset
plates on a flank or a nose, and a flank of plate layers. These are what the
judge names on the starfighter, the car and the owl, and the pass reads only
tops and brick courses. Second, a skin must never go on a course under the
body (a chassis or skirt), or in a colour the body above is not. On the car
it read as a slab. Laying tiles straight on the turned-out studs, a plate
proud and not two, would also make a skin read less like a block.

Both are done since, and not benched: a skin is no longer laid on the bottom
course on a wheeled base, on a course under a wider one, or in a colour the
body over it is not; and it is tiles straight on the studs with a rounded
end at each end, a plate proud. Replayed through the pass, the round's car
with its skins taken back off gets none: both black courses are left as
"its wheels' sill", and only the crown on its deck is laid.

## 2026-10-14-sides: commit 226967d, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 1 | 5.0 | 4.0 | 4.0 | 4.0 | 6.0 | 4.0 | **4.5** | 986 | 5 |
| corner_shop | 1 | 6.0 | 6.0 | 6.0 | 5.0 | 6.0 | 10.0 | **6.5** | 1,041 | 1 |
| sailing_ship | 1 | 5.0 | 3.0 | 4.0 | 3.0 | 4.0 | 4.0 | **3.8** | 840 | 64 |
| speed_champions | 1 | 3.0 | 3.0 | 3.0 | 3.0 | 3.0 | 10.0 | **4.2** | 248 | 2 |
| starfighter | 1 | 6.0 | 5.0 | 5.0 | 5.0 | 4.0 | 10.0 | **5.8** | 558 | 1 |
| steam_locomotive | 1 | 6.0 | 6.0 | 6.0 | 5.0 | 5.0 | 5.0 | **5.5** | 272 | 4 |
| **suite mean** | 6 | **5.2** | **4.5** | **4.7** | **4.2** | **4.7** | **7.2** | **5.1** |  |  |

Weakest across the suite: **technique** (4.2), **surface** (4.5), **colour** (4.7).

**What the sides round says: the surface pass reads a body's sides
(226967d).** After the steps round, surface had not moved for two rounds
(6/6/4/3), and the judge's fault on bodies had moved from their tops to
their sides: the starfighter's "fuselage sides are a terrace of stacked
plates", the car's "flanks and tail are plain brick walls", the owl's
"head and body are rough, stepped blocks" and "the right wing is a flat
plate with its studs showing".

The diagnosis first, from the steps round's four models, voxelised a stud
by a plate, each exposed side face read by the part that owns it:

| model | exposed side faces | plate edges | bricks | turned (SNOT) | slopes | layer pairs whose outline steps |
|---|---|---|---|---|---|---|
| starfighter | 1,152 | 44% | 18% | 0% | 16% | 20% |
| car | 1,158 | 17% | 24% | 15% | 14% | 14-23% |
| owl | 3,396 | 19% | 21% | 51% | 4% | 11-17% |
| shop | 10,822 | 8% | 67% | 2% | 3% | 2-12% |

- The starfighter's fuselage was built by hand of plates the body's width.
  Behind the cockpit it is a flush wall: four grey plates, a dark red
  stripe plate and a brick. Ahead of it the nose narrows a stud at a time,
  and its layers stand at different widths, one two studs in between the
  ones over and under it. Plate edges and outline steps, and no SNOT.
- The car's session tried the shape pattern, said "the generator left the
  nose floating", and built the body by hand in 71 bricks: flat walls of
  bricks and plates, square in plan. Its only turned parts were the steps
  round's skins on its black course. Bare bricks and plates, no shaping.
- The owl is half SNOT already: the shape pattern's shells, the face, the
  wings on their side. What reads as stepped is the shells' own stepped
  plan. And its wing is a plate on its side whose studs point out, open:
  the pass read only studs that point up.
- The shop is a building. Its sides are walls, masonry since the steps
  round. Not a sides problem.

The lever chosen was (a), the pass reading the sides, not (b), the
designer building them right. Six rounds of words moved nothing and two
app-driven passes did. Every design runs the pass, where (b) depends on a
session taking the shape pattern, which the car's session tried and gave
up. (a) can move surface, not likeness: nothing it lays changes a
silhouette. Two findings:

- **A side of plates** (`_plate_flanks`): a course of three plain plates
  stacked at a face, or one brick under plates, one colour, four studs or
  more, with the body over it in that colour, flush or a stud back. Its
  outer row is cut, the rest of each plate laid again, and laid as bricks
  with studs on the side under the brick flank's skin. The skin covers the
  plate edges and a step a stud back. Runs that cut the same plates are one
  finding, since a fuselage of plates its full width has both sides in
  them, and opposite sides are trimmed to match.
- **Studs on a side** (`_side_fields`): open studs pointing sideways, four
  or more on a grid, tiled on their side in their own colour.

Replayed on earlier rounds' models before the batch, every one kept its
pieces. The steps starfighter got both fuselage sides skinned for five
studs behind the cockpit, under its wings where they barely show, and its
tail end. The steps owl got both wing panels and two strips tiled (the
judge's "flat plate with its studs showing"). The edges-b car got its
tail skinned; its sides were left, "under a wider course" over the
arches. The surface round's starfighter got three white flanks of
plates beside two of bricks.

Held out and on the subscription as every batch, one run a subject,
design memory on, and two subjects never run before. The five visual
scores (likeness / surface / colour / technique / creative):

| subject | surface | edges | steps | sides |
|---|---|---|---|---|
| corner_shop | 5 / 6 / 5 / 4 / 4 | 5 / 5 / 5 / 4 / 4 | 6 / 6 / 6 / 5 / 5 | 6 / 6 / 6 / 5 / 6 |
| starfighter | 6 / 6 / 5 / 6 / 6 | 6 / 5 / 5 / 5 / 5 | 6 / 6 / 5 / 6 / 4 | 6 / 5 / 5 / 5 / 4 |
| barn_owl | 4 / 4 / 4 / 4 / 4 | 5 / 4 / 4 / 4 / 4 | 4 / 4 / 4 / 4 / 5 | 5 / 4 / 4 / 4 / 6 |
| speed_champions | 3 / 4 / 3 / 3 / 4 | 3 / 4 / 4 / 3 / 3 | 3 / 3 / 4 / 3 / 3 | 3 / 3 / 3 / 3 / 3 |
| the four | 4.5 / 5.0 / 4.25 / 4.25 / 4.5 | 4.75 / 4.5 / 4.5 / 4.0 / 4.0 | 4.75 / 4.75 / 4.75 / 4.5 / 4.25 | 5.0 / 4.5 / 4.5 / 4.25 / 4.75 |
| steam_locomotive (new) | | | | 6 / 6 / 6 / 5 / 5 |
| sailing_ship (new) | | | | 5 / 3 / 4 / 3 / 4 |

**On surface, a null for the third round running.** Surface is 6, 5, 4
and 3 on the four, against 6, 6, 4 and 3 in the steps round. Every cell is
within the 1.0 run-to-run spread. Over the four it is 4.5, against 4.75,
4.5 and 5.0 in the three rounds before. The four's mean of means is 5.25,
against the steps round's 5.5. The two held-out subjects have no earlier
run: they are a baseline, surface 6 on the locomotive and 3 on the ship.

**What reached the designs, from each log and model:**
- **Flank skins reached four of six.** The locomotive got the most: dark
  green skins on both cab sides, the cab's back and the tender's sides and
  end, of brick courses. Its session kept four findings and accepted
  eight. The judge saw them: "the tender sides are rounded at the ends",
  surface 6. The owl's two flank findings went on its display stand, a
  stack of black plates, not the owl. The car and the starfighter got one
  each. The pass's line did not say which flanks were of plates; it does
  now ("2 flanks skinned (1 of plates)", "8 side studs tiled").
- **What the judge faults on sides now is outlines that step, not flush
  faces.** The car: "the sides read as a staircase of blocks". The
  starfighter: "the nose is a staircase of stacked curved slopes and
  bricks", and "the grey wing-root block is a plain brick wall". The owl:
  "staircase edges where the rounded skull and folded wings should be".
  The ship: "the hull steps in plate by plate at the bow and stern instead
  of curving". A skin lies on a straight face. A bow, a nose or a skull
  that narrows a stud at a time needs wedge plates along the outline, and
  the pass does not lay those.
- **Beyond the 0.7 spread, against the steps round:** the owl's likeness
  and creativity up a point, the shop's creativity up a point, the
  starfighter's technique and the car's colour down a point. One run each,
  and none of them is the pass's: nothing it lays changes a silhouette or
  a colour. This starfighter's session built its fuselage of bricks, "no
  visible SNOT shaping".
- **Build fell on three, none of it the pass's doing.** The owl is 5
  pieces: four stacks of 1 x 1 plates and cheese slopes on its head, left
  against it when the session took its ear wedges off just before the
  pass. Every edit of the pass is held to the piece count it found, and
  three were refused for splitting the model. The locomotive is 4 pieces:
  the creative pass stuck two cab plates on its cab-side skins, and the
  check counts a sticker on an upright face as a piece of its own (it
  joins what sits on a part's top, and a sticker has no connector). The
  ship is 64 pieces: its rigging is a string of 227 braided segments, and
  the check counts 63 bits of it as pieces of their own. The last two are
  the build check's faults, not the design's.

  **Re-scored with one rule for pieces (f515bcd, 2026-10-14).** The probe
  and the judge ran again on both runs; the first records are in each
  run's `oldcheck/`. The ship is 1 piece, a candidate: build 4 to 10, mean
  3.83 to 5.33 (surface, technique and creativity each up 1, inside the
  spread). The locomotive is 2: build 5 to 6, mean 5.50 either way. Its 2
  are real: the tender butts against the drawbar plate with no hitch or
  magnet, which the old check had excused because the driver in the cab
  made the locomotive "a figure apart".

**Next.** First, wedge plates along an outline that steps a stud at a
time, read course by course as the check's own staircase advice is: a bow,
a nose, a skull. That is what the judge names on four of six. Then the
build check: a sticker on an upright face, and a string's segments,
should each be one with what they are on.

## 2026-10-14-shapes: commit ecb3ae4, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| sailing_ship | 1 | 6.0 | 4.0 | 5.0 | 4.0 | 5.0 | 10.0 | **5.7** | 1,211 | 1 |
| speed_champions | 1 | 4.0 | 4.0 | 4.0 | 3.0 | 4.0 | 10.0 | **4.8** | 188 | 2 |
| starfighter | 1 | 6.0 | 6.0 | 6.0 | 5.0 | 5.0 | 6.0 | **5.7** | 408 | 3 |
| steam_locomotive | 1 | 6.0 | 5.0 | 6.0 | 5.0 | 5.0 | 6.0 | **5.5** | 457 | 2 |
| **suite mean** | 4 | **5.5** | **4.8** | **5.2** | **4.2** | **4.8** | **8.0** | **5.4** |  |  |

Weakest across the suite: **technique** (4.2), **surface** (4.8), **creativity** (4.8).

**What the shapes round says: a shaped body comes back whole (6fd49e0, run
on ecb3ae4).** The car was the weakest subject every round, likeness 3, and
its sessions kept giving up the shape pattern: the steps round's said "the
generator left the nose floating" and built the body by hand in 71 bricks.
The lever was to make the session's first, shaped attempt hold, so it is
kept.

The diagnosis first: every shape request the sessions sent (204 of them,
from their transcripts) run again through the pattern as sent and alone,
and six bodies a session would say. On b219bdb and on a077567 the steps
car's cockpit cut came back in 9 pieces and its fastback in 6, a curved
car's nose in 9 and its tail in 6, the sides car's back axle at 15.5 off
its studs, a two-colour boiler in 2, a hull with a black bow in 2, a
fighter's nose past its stands in 3 to 9 and a dog on legs a stud thick
floating whole; an owl said at y 55 floated with nothing said. The causes:

- `stitch` laid one pair again joined and broke the next, then the other
  way, 96 times; nothing checked a move joined anything.
- Nothing ran under a car's nose and tail: the body stood on the axles'
  Technic bricks alone, and a slope at its foot stood on nothing.
- The plan's joins were wrong. A curved slope was counted held by its
  hollow high end, and an inverted curved 4 x 1 by four studs where it has
  two (read off each mesh now, `grips` and `tops`); that inverted slope was
  a ship's bow's only tie to its hull.
- Two colours face to face never shared a part (a smokebox on its boiler).
- On the mirror, a strip two studs wide on the plates whose strip is four
  was 1 x 1s, so a fighter's nose came apart row by row.
- A side's shell took a leg hanging under it into itself, held none of it,
  and the body stood on nothing.

The fix is in the generator, for any body: a chassis of plates under the
axles from nose to tail; a foot off the ground laid in plates where nothing
is under it; a stitch that keeps a way only if it leaves fewer pieces (or
as many and a bigger body), whose last ways lay the pieces' plates, tiles
and wedges again as bonded plates, hidden plates in the commonest colour;
joins read off the parts' meshes; the narrow strip laid in the other
plate's width; a shell that stops above what hangs with no core behind it.
What it still cannot hold it says in the reply, with the fix: pieces apart
and why, a shape standing on nothing, a wheel moved onto whole studs, a
stud-sized tip left off. `shapes_probe` holds the twelve as fixtures, each
failing on a077567.

**Two car sessions on the subscription first** (`2026-10-14-shapes-trial`,
6fd49e0). Both kept the shaped body. The first sent one shape, its nose
four plates up as the curved car's was, and built on it to the end: 184
parts, one piece with the driver apart, likeness 4. The second sent four
shapes, refining the wings and arches in the pattern rather than by hand,
212 parts; it ended in 2 pieces only because the creative pass stuck a
licence plate on an upright face, which the check counts apart. Likeness
3. Neither reply needed a word from the generator: every shape came back
whole.

**Held out, on the subscription, one run a subject** (likeness / surface /
colour / technique / creative / build):

| subject | sides | shapes |
|---|---|---|
| speed_champions | 3 / 3 / 3 / 3 / 3 / 10 | 4 / 4 / 4 / 3 / 4 / 10 |
| starfighter | 6 / 5 / 5 / 5 / 4 / 10 | 6 / 6 / 6 / 5 / 5 / 6 |
| steam_locomotive | 6 / 6 / 6 / 5 / 5 / 5 | 6 / 5 / 6 / 5 / 5 / 6 |
| sailing_ship | 5 / 3 / 4 / 3 / 4 / 4 | 6 / 4 / 5 / 4 / 5 / 10 |

**On likeness, honestly.** The car is 4, and 4 and 3 in the two trial
sessions: 3.7 over three runs, where every round before was 3 (3.5 in the
re-scored baseline). Each run alone is inside the 1.0 spread; the three
together are the first car runs above 3.5, and the first whose sessions
kept a shaped body. The ship is 6 against 5, the starfighter and the
locomotive 6 against 6: inside the spread. What the judge now faults on the
car is not a floating nose or brick walls but the shape the session said:
"a boxy cabin with a flat roof and an upright windscreen", headlamps "stood
up like towers", studs on the wings and sills.

**What reached the designs, from each log:** all four bench sessions and
both trials laid a shaped body and kept it; the car's, the ship's hull and
the fighter's nose came back whole on the first call. The locomotive's
tender was said a part-plate off its chassis; the reply said "A shape's
underside is at y=9, and nothing of the design has its top there under it,
so it floats. Build what it stands on ... or bring the shape's underside
down", and the session fixed it on the next call. Build fell on two for
reasons not the shape's: the starfighter's two figures stand apart unnamed,
the locomotive's tender is not coupled.

**Next.** The car's cabin: a fastback roof and a raked windscreen are what
the judge names, and the session says them as a loft with a flat top. And
the studs a joint leaves on a top, where a tile there had joined nothing,
for the surface pass to tile.

## 2026-10-14-cabins: commit 2c94d72, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| fire_truck | 2 | 6.0 | 6.0 | 5.5 | 5.0 | 5.5 | 10.0 | **6.3** | 322 | 2, 2 |
| passenger_aircraft | 2 | 5.0 | 4.5 | 4.0 | 4.0 | 4.0 | 5.5 | **4.5** | 419 | 3, 5 |
| sailing_ship | 2 | 4.5 | 3.5 | 4.0 | 3.5 | 4.0 | 10.0 | **4.9** | 969 | 1, 1 |
| speed_champions | 2 | 3.0 | 3.0 | 3.0 | 3.0 | 3.5 | 10.0 | **4.2** | 194 | 2, 1 |
| starfighter | 2 | 6.0 | 5.0 | 5.0 | 5.5 | 4.5 | 10.0 | **6.0** | 443 | 2, 2 |
| steam_locomotive | 2 | 6.0 | 5.0 | 5.5 | 5.0 | 4.5 | 9.0 | **5.8** | 388 | 1, 1 |
| **suite mean** | 12 | **5.1** | **4.5** | **4.5** | **4.3** | **4.3** | **9.1** | **5.3** |  |  |

Run to run, the same subject designed again on the same code (each cell is run 1 / run 2 ...):

| subject | likeness | surface | colour | technique | creative | build | mean |
|---|---|---|---|---|---|---|---|
| fire_truck | 5 / 7 | 5 / 7 | 5 / 6 | 4 / 6 | 5 / 6 | 10 / 10 | 5.7 / 7.0 |
| passenger_aircraft | 5 / 5 | 5 / 4 | 3 / 5 | 4 / 4 | 4 / 4 | 6 / 5 | 4.5 / 4.5 |
| sailing_ship | 5 / 4 | 4 / 3 | 4 / 4 | 4 / 3 | 4 / 4 | 10 / 10 | 5.2 / 4.7 |
| speed_champions | 3 / 3 | 3 / 3 | 3 / 3 | 3 / 3 | 4 / 3 | 10 / 10 | 4.3 / 4.2 |
| starfighter | 6 / 6 | 5 / 5 | 5 / 5 | 6 / 5 | 5 / 4 | 10 / 10 | 6.2 / 5.8 |
| steam_locomotive | 6 / 6 | 5 / 5 | 6 / 5 | 5 / 5 | 5 / 4 | 8 / 10 | 5.8 / 5.8 |

Mean spread between runs, per dimension: likeness 0.5, surface 0.7, colour 0.7, technique 0.7, creative 0.7, build 0.5; of a subject's mean score, 0.39 (standard deviation 0.30). A change to a subject's mean smaller than the spread is not yet a result.

Weakest across the suite: **technique** (4.3), **creativity** (4.3), **surface** (4.5).

**What the cabins round says: a cabin said by its profile is laid, a tender
is coupled, and the car still gives up its body (0df6625, run on 2c94d72,
merged with merge21).** The shapes round's judge had moved on to three faults.
The car's cabin was "a boxy cabin with a flat roof and an upright windscreen":
every car session said its cabin as a loft with a flat top, as the guide's own
example did, and fitted a windscreen afterwards by hand, if at all. The
locomotive's tender was coupled to nothing, two pieces, and the check said only
that a piece stood against the model. And studs a shape's joint leaves in its
top (a top tile that joined nothing, laid again as a plate) were left by the
surface pass as "detail", fewer than four together.

The change, for any vehicle and named by how it is built:
- **"screen" on a loft, an extrude or a revolve.** Where its front climbs to
  the roof, a windscreen (92583, 4176, 3823 or 57783, each read off its mesh)
  is laid at that rake, standing on the plates at its foot, the roof two
  plates over its top row on its studs, and the roof falls behind it in
  curved slopes. The reply says what it laid, or why none fits. The guide's
  car example is now a cabin said by its own profile with a screen, and a
  raised solid that climbs steeply with no screen is told how to say one.
- **Couplings.** A part on wheels of its own, end to end with the model and
  coupled by nothing, is named in the check with the fix: a towball pair
  (14417 and 14704, two studs apart on one grid), or train buffer beams with
  sealed magnets (64422, as the Emerald Night couples its tender), which the
  check now counts as magnets. A coupler hanging below its plate keeps the
  shape's studs under it. Both are worked techniques.
- **The surface pass** tiles a few open studs set beside tiles at their height.

`cabins_probe` holds each as a fixture: four cabins (the guide's car, the
shapes round's own loft with a screen, a truck's cab, an aircraft's round
fuselage) each laid with a windscreen in glass, in one piece; the tender named
with the fix, and coupled either way one piece; the guide car's six joints'
studs all tiled. On the tree before, 21 of its checks fail.

**Held out, on the subscription, two designs a subject** (likeness / surface
/ colour / technique / creative / build):

| subject | shapes | cabins, run 1 | cabins, run 2 |
|---|---|---|---|
| speed_champions | 4 / 4 / 4 / 3 / 4 / 10 (trials 4 and 3) | 3 / 3 / 3 / 3 / 4 / 10 | 3 / 3 / 3 / 3 / 3 / 10 |
| steam_locomotive | 6 / 5 / 6 / 5 / 5 / 6 | 6 / 5 / 6 / 5 / 5 / 8 | 6 / 5 / 5 / 5 / 4 / 10 |
| starfighter | 6 / 6 / 6 / 5 / 5 / 6 | 6 / 5 / 5 / 6 / 5 / 10 | 6 / 5 / 5 / 5 / 4 / 10 |
| sailing_ship | 6 / 4 / 5 / 4 / 5 / 10 | 5 / 4 / 4 / 4 / 4 / 10 | 4 / 3 / 4 / 3 / 4 / 10 |
| fire_truck (new) | | 5 / 5 / 5 / 4 / 5 / 10 | 7 / 7 / 6 / 6 / 6 / 10 |
| passenger_aircraft (new) | | 5 / 5 / 3 / 4 / 4 / 6 | 5 / 4 / 5 / 4 / 4 / 5 |

**Judged in pairs** (`run.py pairs` then `rank`, every design of the six
subjects both ways round), overall ELO; each design's 95% interval, about
±100 to ±250, is in `run.py rank`:

| subject | shapes round | cabins round |
|---|---|---|
| speed_champions | 1255; trials 1370, 970 | 1191, 806 |
| steam_locomotive | 663 (sides 897) | 1337, 1103 |
| starfighter | 915 (sides 1048) | 1286, 1286 |
| sailing_ship | 1167 (sides 920) | 1080, 833 |

The lever, cabins against shapes, mean over the four subjects run in both:

| dimension | ELO change | judge's 95% | with run-to-run 95% | 1-10 change |
|---|---|---|---|---|
| overall | +130 | +7, +187 | -153, +386 | -0.07 |
| build | +202 | +89, +303 | -39, +438 | +2.08 |
| surface | +83 | -60, +176 | -221, +362 | -0.62 |
| technique | +69 | -31, +136 | -172, +286 | -0.08 |
| likeness | +25 | -43, +107 | -221, +257 | -0.54 |

The round's six pairs of designs on one code are six more measures of luck:
the car's two are 385 ELO apart, the fire truck's and the aircraft's 382 (as
far apart as two designs on one pair can be), the locomotive's 234. Pooled with the four before, one design sits 220 ELO from
its code's mean (194 on four pairs).

**On likeness, honestly.** The car is 3 in both runs, against 4 in the shapes
round and 4 and 3 in its trials; in pairs its two designs fall either side of
the shapes round's. What the judge names on it is still the cabin: "The cabin
is a tall, square-sided block" (run 1), "a short box roof sits over the
driver on open pillars, and there is no 911 fastback slope" (run 2). Both
sessions said their cabin with a screen, as the guide's example does, and got
the windscreen; both then gave the shaped body up and built the car by hand,
keeping a 92583 at the rake under a box roof:
- Run 1: "The generated body came out too blocky to read as a 911". Its
  body's sides were turned out on side studs, and the shell kept 54% of its
  plates, leaving side studs open along the cabin; the cabin's sides were solid
  red, with no glass.
- Run 2 cut a box out of the cabin for its driver. The screen reads the roof
  off the middle studs, which the cut had lowered, and stood on the cut's
  floor, at y 4: "the generator mangled the cabin with the cut".
The locomotive and the starfighter rose in pairs (+674 and +371 on their
best, both runs above the shapes round's), the ship fell inside the spread.
Overall the round is +130 to the judge, which excludes 0, and -153 to +386
with a design's luck in, which does not: a gain the judge sees, not a lever
shown. On the 1-10 scale, -0.07.

**What reached the designs, from each log:**
- **Screens: said in 7 of 12 sessions** (both cars, both fire trucks, both
  aircraft, the second starfighter's cockpit), and laid every time. The
  starfighter kept its 57783 canopy; the second fire truck rebuilt its cab
  round a 4176; both aircraft took the airliner nose parts instead. The cabin
  hint was given to both ships, three times each, for a raised stern: a false
  alarm, ignored.
- **Couplings: both locomotives coupled.** Each was told once that its tender
  rolled on its own wheels with nothing coupling it, with the fix. Run 1 read
  "magnet coupling" and pinned a Technic drawbar; run 2 used the "towball
  hitch". Both are one piece, where the sides and shapes rounds' were two
  pieces each. Build 8 (an axle brick overloaded) and 10; in pairs, build is
  the dimension that moved most, +202.
- **The new subjects:** the second fire truck is the highest 1-10 mean any
  bench design has had, 7.0, "at a glance ... a City ladder truck"; the
  first, 5.7, "one flat-topped box ... no stepped-down crew cab". The
  aircraft are 4.5 twice, faulted on short square wings and loose engines, and
  in 3 and 5 pieces with overloaded joints.
- **A joint's studs:** the judge still names open studs, on fields the
  sessions kept or laid by hand (running boards, a sterncastle deck, wings);
  from the pictures alone none can be told for a joint's few.

**Next.** The car's cabin is still its fault, now for what comes after the
windscreen: its sides glazed rather than solid, and not turned out on side
studs a shell then leaves open; a seat for the driver, the screen reading the
roof across the cabin's width so a cut does not lower it; and the cabin hint
only where a shape stands on wheels or its solid is glass.

## 2026-10-14-glass: commit 810cd27, rubric v1, judge claude-opus-5-5

| subject | runs | likeness | surface | colour | technique | creative | build | mean | parts | pieces |
|---|---|---|---|---|---|---|---|---|---|---|
| barn_owl | 2 | 4.5 | 3.5 | 4.0 | 3.5 | 5.0 | 10.0 | **5.1** | 809 | 1, 1 |
| fire_truck | 2 | 5.5 | 5.5 | 5.5 | 5.0 | 4.5 | 10.0 | **6.0** | 343 | 2, 2 |
| mobile_crane | 2 | 4.0 | 2.5 | 3.0 | 3.5 | 4.0 | 10.0 | **4.5** | 552 | 1, 1 |
| passenger_aircraft | 2 | 5.0 | 4.5 | 4.0 | 4.0 | 3.5 | 4.0 | **4.2** | 612 | 2, 2 |
| speed_champions | 2 | 3.5 | 3.5 | 3.0 | 3.0 | 3.5 | 10.0 | **4.4** | 226 | 2, 2 |
| steam_locomotive | 2 | 6.0 | 5.5 | 6.0 | 5.0 | 4.5 | 10.0 | **6.2** | 317 | 1, 1 |
| **suite mean** | 12 | **4.8** | **4.2** | **4.2** | **4.0** | **4.2** | **9.0** | **5.1** |  |  |

Run to run, the same subject designed again on the same code (each cell is run 1 / run 2 ...):

| subject | likeness | surface | colour | technique | creative | build | mean |
|---|---|---|---|---|---|---|---|
| barn_owl | 5 / 4 | 4 / 3 | 4 / 4 | 4 / 3 | 5 / 5 | 10 / 10 | 5.3 / 4.8 |
| fire_truck | 6 / 5 | 6 / 5 | 6 / 5 | 5 / 5 | 5 / 4 | 10 / 10 | 6.3 / 5.7 |
| mobile_crane | 4 / 4 | 3 / 2 | 3 / 3 | 4 / 3 | 4 / 4 | 10 / 10 | 4.7 / 4.3 |
| passenger_aircraft | 5 / 5 | 5 / 4 | 4 / 4 | 4 / 4 | 4 / 3 | 4 / 4 | 4.3 / 4.0 |
| speed_champions | 3 / 4 | 3 / 4 | 3 / 3 | 3 / 3 | 4 / 3 | 10 / 10 | 4.3 / 4.5 |
| steam_locomotive | 6 / 6 | 5 / 6 | 6 / 6 | 5 / 5 | 4 / 5 | 10 / 10 | 6.0 / 6.3 |

Mean spread between runs, per dimension: likeness 0.5, surface 1.0, colour 0.2, technique 0.3, creative 0.7, build 0.0; of a subject's mean score, 0.39 (standard deviation 0.21). A change to a subject's mean smaller than the spread is not yet a result.

Weakest across the suite: **technique** (4.0), **surface** (4.2), **creativity** (4.2).

**What the glass round says: a session now keeps the body the shape laid,
and the car's likeness has not moved (981b310, run on 810cd27).** The
cabins round's two cars, both fire trucks and one aircraft laid a shaped
body and then built the model again by hand. Read from their transcripts,
what each saw first:
- **The picture.** The first car's cabin was a solid red block behind its
  windscreen, with side studs standing open along it where its shell kept
  54% of its plates; the session said "too blocky to read as a 911". Both
  fire trucks saw a cab with no windows: "a solid lump with no crew cab
  interior", "the silhouette works but looks blocky".
- **A fault.** The second car liked its first body ("silhouette reads as a
  911 fastback"), cut a seat into the cabin, and the windscreen read the
  roof off the cut's floor: it stood at y 4 leaning forward. "The generator
  mangled the cabin with the cut."
- **The check's words.** Every shaped car was told it was "built more
  squarely than real vehicles sets ... how a model that holds together comes
  to look like a pile of bricks", its rounded extrude "steps in plates
  however fine", and, as "one call", the shape pattern it had just used.
  The plain share counts the shape's hidden core.
- The first aircraft swapped its fuselage for the real City airliner nose and
  belly: an expert's choice, not a fault. The second ship found its hull's
  top too round to build a deck on; that is not this round's.

The change, for any shape (`cabin_glass_probe`, 19 of whose checks fail on
1a8079a):
- **A cabin on wheels is glazed.** Behind the windscreen's top row, every
  plate of the screen's own solid from its foot to two plates under the roof
  is laid in its glass, as far back as the roof is over it and no further
  than the screen is wide, falling with a fastback. In glass a layer takes
  only parts LEGO made in it (a 1 x 2 or 1 x 4 brick as its glass brick,
  3065 and 3066), as Speed Champions' 76897 glazes its own cabin. A
  fuselage's cockpit, with no wheels, is not.
- **No side stud left open.** A side shell leaves glass to the core, and the
  roof standing on it; a side-stud brick none of whose studs holds anything
  is a plain brick of its length, and an open stud on one that holds
  something takes a tile.
- **The roof across the cabin.** The screen reads its roof across the
  solid's whole width, off the solid as said, so a seat cut leaves it where
  it was.
- **The hint** to say a screen fires only on a shape with wheels or of a
  solid said in glass, not on a ship's raised stern.
- **The words.** A shaped body is told to keep it ("its core is plain bricks
  inside, which these shares count, so work on what shows"), not to say one;
  and is told its rounded body steps in plates only where the shape did not
  turn its flanks out.

**What reached the designs, from each session:**
- **The body kept.** Of the five sessions on the car, the fire truck and the
  aircraft that laid a shaped body, none built it again by hand (the
  cabins round: five of six). Both cars refined theirs in place, 4 and 2
  submits all of the shape, then features, a seat, the surface pass; both
  fire trucks built their lockers, ladder and lamps on it. The first aircraft
  kept its shaped fuselage and built its wings by hand from wing plates; the
  second never laid one. Held out: both owls kept theirs; the first crane
  built its chassis by hand because "the wheel generator is choking on
  closely paired axles", the second kept its body.
- **Glass laid** in both cars, both fire trucks and both cranes, said in the
  reply each time. The hint fired once, on the second crane, on wheels.
- **The judge's words.** The car's cabin is no longer the fault it names. Run
  1: "a long, low, flat-sided red wedge ... stray blocks sticking up from
  the roof"; run 2: "the curved fastback roof sloping down ... gives a faint
  911 hint", faulted on slab sides, no flared arches and no whale tail. The
  fire trucks read "a sloped glass cab with a blue light bar".

**Judged in pairs** (`run.py pairs` then `rank`), overall ELO, each with its
95% interval in `run.py rank`:

| subject | cabins round | glass round |
|---|---|---|
| speed_champions | 1139, 813 | 1257, 957 |
| fire_truck | 1203, 631 | 1074, 806 |
| passenger_aircraft | 1187, 1011 | 1097, 705 |
| steam_locomotive | 1369, 1068 | 1068, 1068 |
| barn_owl (held out; best before d6 1353) | | 1240, 912 |
| mobile_crane (held out; the baseline 716) | | 1284, 1000 |

The lever, glass against cabins, mean over the four subjects run in both:

| dimension | ELO change | judge's 95% | with run-to-run 95% | 1-10 change |
|---|---|---|---|---|
| overall | -49 | -116, +29 | -280, +198 | -0.04 |
| likeness | +11 | -74, +120 | -231, +265 | +0.00 |
| technique | +75 | -1, +156 | -160, +301 | +0.00 |
| surface | +50 | -62, +155 | -272, +367 | +0.12 |
| build | -89 | -168, -20 | -309, +127 | -0.12 |

On the car alone, the two designs are 118 and 144 above the cabins round's,
and on likeness 226 and 229 (1324 and 1035 against 1098 and 806): the
dimension this was for, one subject, two designs, each inside a design's luck
(one design sits 226 ELO from its code's mean, pooled over the thirteen pairs of
twins now). Against the baseline on the three subjects run in both (the car,
the owl and the crane), +302 (+157, +337; with luck, -34, +569).

**On it, honestly.** The cause is fixed, in what the sessions do: the body is
kept and refined, every time on the vehicles. It is a null to the judge:
-49 overall, +11 on likeness, both intervals across 0. The locomotive (no
shaped body either round) fell 151 and the aircraft 198, which is the
luck of four designs; the car rose. The car is still likeness 3 and 4: what
the judge names now is the body the session said, long and flat, its flank
stepped where the shape kept no shell (the first car's body turned none out,
0% sideways), and the roof over the windscreen's top row a plate or two
above where the fastback's curved slopes begin.

The parts catalogue changed under the round (main 7970de9, connections part
4, 68 entries): the last designs read the new one.

**Next.** The car's body itself: its flanks skinned where the shell gives
back (a car three and a half plates of body falls under `SHELL_KEEPS`); the
roof over the screen's top row flush with the fastback; a multi-axle chassis
the wheel generator can lay (the crane's); and a fuselage's own open side
studs (12 on the probe's revolve, on main as well).
