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
compare.

**Design memory, and what a batch holds out.** Every scored design is kept,
with its critique, in `assets/knowledge/designs.json.gz`: subject, brief,
the six scores, the judge's reasons, how it was built (`tools/style.py`'s
shares, its most-used shaped parts, and from its log the features worked and
real-set pieces laid) and a small picture. After a batch, run
`python3 tools/design_memory.py build` (it reads the main checkout's
`bench/results/`) and commit the index: it merges into what the index holds,
and it is now the only copy of the creative, d5 and d5b rounds' critiques and
pictures, read before their worktrees went. It holds 47 designs: the
baseline's 13, the creative round's 4, d5's 2, d5b's 3, d6's 4, d6b's 2, the
surface round's 4, the edges rounds' 5, the steps round's 4 and the sides
round's 6 (its locomotive and ship the first of their subjects). What is missing is
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
