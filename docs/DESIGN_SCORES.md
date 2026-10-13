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
