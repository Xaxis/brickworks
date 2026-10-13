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
