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
probe, the measures, the prompt and the judge's raw reply — is under
`bench/results/<date>/<subject>/<run>/`, gitignored.

Two things to read before trusting a difference: the run-to-run spread
below each table (the same code, the same subject, designed again), and
the rubric version in each heading — scores under two versions do not
compare.

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
