# Assistant

Turning a sentence into a model that holds together, then looking at it and
fixing what it got wrong.

<!-- covers: lib:design loop, cli:design from a brief, lib:model and effort settings, lib:reference pictures, lib:shapes said as patterns, lib:worked constructions, lib:find a reference picture -->

## Sub-features

- `design loop`: the real loop in `src/ai/assistant.gd`. It is given the part
  catalogue, the rules, and tools to search, place, read back the world and look at
  a render; it places bricks, is told what collides, floats or will not survive
  being lifted, and revises. Sections let it carry a sub-assembly at an angle.
- `design from a brief`: `tools/design.py "<sentence>"`, which shells out to
  `godot --path . -- --ask=... --out=...`. **This spends real money.**
- `model and effort settings`: which Claude model and which effort level, and
  whether the request it builds is one that model will accept — `max_tokens`
  ceilings, adaptive thinking, the cached system block. Opus 5.5 is the default;
  Sonnet 5.5 and Haiku 4.5 are the alternatives. Effort rides in
  `output_config`, not at the top level, which the API refuses outright.
- `reference pictures`: a picture of what is wanted, put into the conversation,
  and old ones dropped so the context does not grow without bound. A reference is
  kept when drafts are dropped, and is shown beside the renders in the critique —
  the moment a designer holds the model up against the thing.
- `find a reference picture`: `find_reference`, a tool. Searches Wikimedia Commons
  and brings a photograph of the subject into the conversation, credited. The loop
  calls it first, before any brick: a design asked for a lighthouse and working
  from memory gets the proportions wrong in a way no later critique recovers.
- `measured, not just photographed`: every look — `check_design`, `view_model`,
  `edit_model` and the critique — carries the model's size in studs, its massing
  banded by height, and each named section measured as it is carried. "Is this the
  size I planned" is the question a render answers worst, and a section is the
  thing a designer thinks in: whether the two nacelles match each other is not
  something a photograph settles.
- `wedges laid by the fill`: `fill` on an ellipse lays wedge plates — LDraw files
  them under "Wing" — wherever the shape of a wedge is the shape of the edge, and
  plates everywhere else. A 16 x 12 ellipse went from 29 plates with a stepped
  outline to 13 parts with none. The shapes are read off each part's own top studs
  rather than typed, so handedness falls out of the arithmetic; all 72 shapes (18
  parts, 4 turns) have a mirror twin, which is what makes it possible to lay them
  in families and never leave a saucer lopsided.
- `shapes said as patterns`: `src/ai/patterns.gd`. Writing placements one at a
  time is the arithmetic a language model is worst at, and most of a model is
  repetition. Three verbs do the counting — `repeat`, `mirror`, `fill` — and
  `fill` takes `wall`, `layers`, `rise` and `shrink`, which between them say a
  dome, a cone, a round tower, a straight hull and a flaring bowl in one object.
  Expansion happens here, from data: nothing runs anybody's code.
- `a module said again`: `repeat_section`, on both `submit_design` and
  `edit_model`, over `Assistant._expand_repeats`. Build the repeating unit once
  as a section, then give `{from, times, dx, dy, dz, degrees, axis}` and get a
  copy per step — each one a section of its own, so a later edit can turn one
  without touching the rest. `degrees` turns about the section's own origin, so
  it walks a module round a tower. Capped at `MOST_COPIES` 400 and
  `MOST_BRICKS` 50,000, which is the lattice's own ceiling and not a guess.
- `how real sets build this`: a tool, over `PartLibrary.kinds_for`. The only
  thing the assistant can ask that is neither geometry nor my taste — what real
  sets of a kind are built from, by lift over sets in general. See
  `features/parts.md` for how it is measured.
- `worked constructions`: `show_technique`, a tool, over `src/ai/techniques.gd`.
  Eight constructions with real part numbers and real coordinates — a staggered
  wall, a half-stud offset, a face turned sideways, a porthole, a smooth diagonal,
  a smooth top, a round tower, a taper. Being *told* to stagger a wall is not the
  same as knowing where the stud sits, and the arithmetic is the part that goes
  wrong.

## How to reach it

```sh
godot --path .                                   # the Design panel
tools/design.py "a small lighthouse"             # COSTS MONEY
tools/design.py "a red sports car" --out models/car.ldr --effort max
godot --headless --path . -- --ask="a small lighthouse" --out=/tmp/x.ldr --effort=low
```

Effort is one of `low medium high xhigh max`. The app needs either the person's own
key or a signed-in account; the CLI uses the key in the environment. **The user's
key never reaches our server** — `/api/claude` is for accounts that pay in our
tokens, and a bring-your-own-key client talks to Anthropic directly.

## How to check it

Static: nothing static covers the loop. `pyright` covers `tools/design.py`.

Runtime, all free — these are the ones to run after changing the loop:

```sh
godot --headless --path . --script src/dev/rules_probe.gd       # the rules, and what it is told
godot --headless --path . --script src/dev/world_view_probe.gd  # it reads back what it wrote, and how big it is
godot --headless --path . --script src/dev/edit_probe.gd        # change a model without re-describing it
godot --headless --path . --script src/dev/scale_probe.gd       # a model too big to list in one go
godot --headless --path . --script src/dev/scanner_probe.gd     # half-written arguments yield whole bricks
godot --headless --path . --script src/dev/reader_probe.gd      # the reassembled answer matches what was sent
godot --headless --path . --script src/dev/busy_probe.gd        # a second design during the first
godot --headless --path . --script src/dev/dropped_probe.gd     # a dropped connection, retried
godot --headless --path . --script src/dev/restore_probe.gd     # a failed design leaves the model alone
godot --headless --path . --script src/dev/brain_probe.gd       # the request carries only what the model accepts
godot --headless --path . --script src/dev/reference_probe.gd   # a picture gets in
godot --headless --path . --script src/dev/reference_lookup_probe.gd  # and one can be found
godot --headless --path . --script src/dev/patterns_probe.gd    # a shape said rather than counted out
godot --headless --path . --script src/dev/repeat_probe.gd      # ten thousand bricks from two hundred and fifty
godot --headless --path . --script src/dev/techniques_probe.gd  # the worked constructions are real parts
godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd  # and it is a picture of the model
```

Proves it when: each exits 0 with no `FAIL`. `rules` is the one that catches a
message that reads as three problems when there is one, or advice counted as an
error.

Paid, and only when the thing they exercise has changed — each spends tokens.
**Two of these need only a key; three need an account.** `sideways` and `bakeoff`
read `Brain.api_key()` and run with a key in the environment or in `.env`.
`assistant`, `revise` and `tier` test the account gate rather than the design
loop: they want a signed-in account against a real `BRICKWORKS_API`, and the
first two refuse to start when a direct key is set, because a key bypasses the
gate they exist to check. On a machine with a key in `.env` the app always takes
the direct path, so the account path is not exercised there at all.

```sh
godot --headless --path . --script src/dev/assistant_probe.gd   # a real design, through the real gate
godot --headless --path . --script src/dev/revise_probe.gd      # add to a model it did not build
godot --path . --resolution 1200x800 --script src/dev/sideways_probe.gd  # build sideways when the job needs it
godot --headless --path . --script src/dev/stream_probe.gd       # appears while it is being written
godot --headless --path . --script src/dev/bakeoff_probe.gd      # do the settings change anything
godot --headless --path . --script src/dev/tier_probe.gd         # who may use it, on whose money
godot --headless --path . --script src/dev/account_probe.gd      # a whole sign-in, against a real server
```

A real brief is the end-to-end proof: `tools/design.py "a small lighthouse"
--effort low`, then open the `.ldr` and count the parts. Report that you spent.

## Gotchas

- **Four tests here once asserted against the thing under test** and passed with
  the bug reinstated: `_tries >= TRIES_WHEN_DROPPED - 1`, a colour lookup that
  never returns null, a wedge assertion the old wrong answer also satisfied, and
  wording that matched either way. Before trusting a new assertion here, break the
  code and watch it fail.
- **GDScript lambdas capture by value.** A callback that reads a counter captured
  the number, not the variable.
- **A whole-model plan view is blind to a stepped edge.** `_stepped_outline`
  flattened every brick into one outline, so a ship whose saucer is a staircase
  and whose hull is wider than the saucer had the hull's straight edge for an
  outline and no staircase in it anywhere. Measured on a real 144-part Voyager:
  not one wedge in 27 kinds of part, and not one word said. It runs course by
  course now, and only over parts that fill their box — the lattice approximates
  a round brick as a staircase, and calling that stepped would be a complaint
  about the measuring. Silent on all eight shipped models, and it finds the
  saucer.
- **"A straight diagonal of any slope" was not what the old rule tested.** It
  compared step *sizes* and allowed any two adjacent ones, which rejects a
  two-stud step alternating with a flat — the commonest wedge slope there is. It
  asks whether the edge stays within a stud of a straight line now, and requires
  the slope to be strictly steeper than one in two: at exactly one in two the
  shipped tower and tree fire, and they taper on purpose.
- **A decoder handed the wrong format prints an engine error before it returns
  its failure.** `reference_finder` used to try jpg, then png, then webp and keep
  whichever worked, which is correct and put two engine errors in the middle of
  a real design run for an ordinary picture. Engine errors are what this project
  treats as a broken build, so the format is read off the first bytes now and
  only the right decoder is called.
- **A fault nobody can act on is not a fault.** `models/car.ldr` ships with the
  app and opens on a first visit. It has wheels: thirteen tyres at y=-3, which is
  where wheels go, and a tyre fits *around* a hub, which a cover made of boxes
  cannot express. So the car read as fourteen problems, and asking to recolour one
  brick on it came back "Not applied — the model would not hold together", listing
  thirteen wheels the edit never touched. Below-ground now applies only to a brick
  being placed or moved, and an overlap is a fault only when at least one of the
  two bricks is this design's. What was already there still goes into the lattice,
  so a new or moved brick is checked against it exactly as before — `edit_probe`
  asserts both halves.
- **`sideways_probe` answers a question the other probes cannot.** `snot_probe`
  proves the machinery works; this asks whether the design ever *reaches* for it,
  with a brief that cannot be answered studs-up. First run, 2026-10-03: 16 of 39
  parts turned onto +z, a plate on SNOT bricks with tiles over the studs. So
  sideways building is not dead code — and that sharpens when a capability must
  live inside a tool rather than in the prompt. The design reached for sideways
  building because the brief made it unavoidable; it never reached for wedges
  because a staircase of plates still satisfies "build a saucer". A technique the
  brief demands gets used; one that merely improves the result has to be in a tool
  the design cannot avoid.
- **The ceiling on model size was never the lattice — and it was never the
  reply either.** The lattice holds 50,000 bricks in 180 MB. A reply holds about
  a thousand placements. Everything between was unreachable, and `patterns`
  only reaches shapes it has verbs for: a dome, a hull, a row. A castle wall of
  forty bays is none of those. `repeat_section` closes it, and the measured
  claim is the probe's: **250 placements described, 10,000 bricks built**, 780
  studs along and fifty courses high, checked in one piece and really on the
  baseplate.

  What it cost to find out: checking those 10,000 bricks took **108 seconds**,
  and two thirds of that was work nobody needed. Walking all 9,600 cells of
  every brick to find its two corners was 20s — a box *is* its corners, so
  `BrickLattice.corners_in` reads them in six reads per box. `_longest_staircase`
  was 36s: quadratic in the width of the model, because a flat edge never breaks
  the run and every extension rechecks everything before it. A run of equal
  steps lies exactly on its chord, so there is nothing to measure; the scan now
  skips it and carries a 2-second budget besides, the same way the hint sweep
  does. **22 seconds** now, with every staircase answer unchanged — `rules_probe`
  is what says so.

  Measure before you cut. The first guess was the cell expansion itself, which
  turned out to be 10.9s of the 108.

  **That 108→22 is a direct measurement, made once, and `rules_probe` is what
  guards the answers it gave.** What `repeat_probe` guards is weaker and worth
  stating plainly: the check staying about linear in the number of bricks. It
  does not pin the staircase scan — with the quadratic restored the ratio reads
  5.0 against 4.2, because the same quadratic sits in both measurements and
  nearly divides out. Isolating width at a fixed brick count was tried and
  confounds width with height: hold the bricks and narrow the wall and it gets
  taller.

  **And do not put a wall clock in a suite check.** The first version asserted
  "under a minute". It measured 22s alone and 68s in a suite run beside another
  session's video encode, on a box at load average 164 — a failure with nothing
  changed. The suite says so itself for the on-screen probes: "Check the load:
  these starve above about 12". A ratio divides the machine out; the threshold is
  10, between linear's 4 and quadratic's 16, because the ratio itself read 4.2,
  4.9 and 7.3 on three runs of identical code.

- **The check measured what was wrong with a model and threw it away on exactly
  the designs that needed it.** A design that fails gets `report["feedback"]`,
  which carries faults *and* advice. A design that holds together went straight
  to the one deliberate look — stability plus five named visual faults — and that
  look never mentioned texture. Measured on a castle: **713 bricks, buildable,
  23 different shapes where a real set of its size has 117, and 208 of one corner
  brick where 81 is the 95th percentile.** The check knew all three; at the one
  moment the design was deciding whether it was finished, it was shown none of
  them, and it finished. `_check` returns `advice` now and the final look carries
  it, with monotony added to the critique's named failures. `variety_probe` pins
  both.

- **Three wall-clock checks flapped in one day on a box shared with another
  project's video encode.** Load average 104 to 171, and the suite's own words
  for its windowed probes are "nothing was proven. Check the load: these starve
  above about 12." `repeat_probe`'s was new and became a ratio. `shot_probe`'s
  was "a picture takes more than 2.0 s", and it **already measured what a frame
  costs on this machine in the same run** — so it counts frames now: a picture is
  8 frames of a 101 ms frame when quiet, `MOST_FRAMES` is 20, and above
  `A_FRAME_IS_HOPELESS` it reports nothing-proven rather than failing. Verified
  both ways: tightening the constant to 3 makes it fail. The original cost it was
  written for — six seconds a picture at every model size — was a 989 ms frame,
  which shows up in frames too.

- **One call's complaint was the next call's problem.** A real run reported "155
  problems (floating 125, overlap 17, **pattern 13**)" about an `edit_model` —
  and an edit takes no patterns at all. `_check` reads `_pattern_trouble`
  whatever produced it, and only `_read_model` ever cleared it, so the thirteen
  complaints belonged to the `check_design` before it and were re-reported as the
  edit's own for the rest of the run. `_edit` clears both troubles now.

  **This was found by the logging, not by reading the code.** The progress line
  started saying how much shorthand a call carried, and an edit was claiming
  patterns it could not have sent. Worth knowing where each piece of shorthand
  actually expands: patterns in `_read_model`, so `check_design` and
  `submit_design`; `repeat_section` in both `_read_model` and `_edit`. The first
  version put the counts on one path and the complaints on another, and neither
  was the path that mattered.

- **A number somebody typed is not a measurement.** `brain.gd` recorded Opus and
  Sonnet at 64,000 output tokens and Haiku at 32,000. The real figures are
  128,000 and 64,000, so the app capped its own replies at half the room it had
  on every model — and `max_tokens` is the ceiling on how many bricks can be
  dictated in one reply, which is the ceiling this project cares most about. The
  old check only asked whether the request carried the table's number, which it
  faithfully did. `brain_probe` now asks the API: a `max_tokens` above the limit
  is refused *before* any tokens are generated and the refusal names the limit,
  so the check is free. It skips rather than fails without a key or a network.
- **Five paid probes read the key from the environment only, and the app reads
  `.env` too.** So a key set up the way the app expects made `stream`, `sideways`,
  `bakeoff`, `tier` and `brain` all print "no ANTHROPIC_API_KEY" and skip —
  reporting no key with the key in the file beside them, which is part of why
  those surfaces had never been driven. `Brain.api_key()` is the one
  implementation now; `main.gd` delegates to it.
- **`TLS handshake error: -27648` / `mbedtls -0x6c00` happens, and is not ours.**
  That code is `MBEDTLS_ERR_SSL_INTERNAL_ERROR` — a failure inside Godot's
  bundled TLS. Measured: about twice per run, in a 46-brick post box as readily
  as in a 90-minute Voyager, always on a fresh connection's handshake. The app
  retries (`_ask_again`, 4 tries, 2 s × attempt) and every run has recovered and
  finished its design, so the symptom is a slow run rather than a lost one.
  **A speculative fix was tried and reverted**: polling the socket hard instead of
  once per frame, on the theory that a main thread busy for seconds was starving
  the handshake. Two runs before, two runs after, two errors in every one — it
  changed nothing. The damage that mattered was a timed-out run losing its file,
  and that is fixed in `model-io.md` instead.
- **Four ways to get wedge-laying wrong, all of them measured.** Studs are not the
  body: a wedge's tapered half fills cells it has no stud on, so reserving only the
  studded ones let two wedges put their tapers in the same place — 14 overlaps on
  one flat ellipse, every one wedge against wedge. The fits test needs the shape as
  it *was*, not as it is left, or the second wedge mistakes the first one's studs
  for the outside of the shape. Candidate positions sweep the whole box, not the
  wanted cells, because a right hand's corner cell is never one of its own studs —
  take a wanted cell for the corner and only left hands can ever be placed. And the
  unit is the whole **family** under reflection in x *and* z, not a pair: pairing
  about one axis drew "a mirror of itself about its width, except brick 6 and brick
  7" from the checker, a correct pair about the other axis.
- **The symmetry advisory forgives three lonely bricks**, so it cannot be the test
  for this: an ellipse laid with only the across-mirror came back 18 parts with no
  complaint at all. `patterns_probe` asserts the invariant instead — reflect every
  stud the wedges cover about both middles and the set maps onto itself — over
  three ellipse sizes, because the 20 x 16 case passes even when the code is broken.
- **The checker never asked whether a model reads as the thing.** It asks whether
  it stands up, and colour is most of the difference. Measured, and the two
  populations do not overlap: the eight models that ship with the app, made by a
  person, are **31 to 59 per cent** their commonest colour across three to eight
  colours; three starships the assistant built are **90, 93 and 95 per cent** —
  387 of 407 parts in one grey. `MOSTLY_ONE_COLOUR` is three quarters, which sits
  in the empty gap with room either side, and `WORTH_COLOURING` is 40 parts
  because a fourteen-brick sign is one colour for a reason. Advice, never a fault,
  and it says so: a sculpture or a prototype is meant to be monochrome.
- **And whether it is all structure and no detail**, the other half of the same
  thing. Measured, and the populations do not overlap here either: the person's
  eight models are **9 to 44 per cent** parts of eight studs or more; three
  starships the assistant built are **70, 73 and 75** — 284 of 407 parts on one of
  them. A set is mostly small parts with the big plates buried inside, which is
  what greebling is. `MOSTLY_BIG` is 0.60, in the gap. `tower.ldr` is the closest
  a person's model comes to either line — 44 per cent big, 59 per cent one colour
  — and stays silent on both.
- **`advice` is not `issues`.** Hints live in their own array, because
  `errors += issues[kind].size()` counted the hint as a problem and the model spent
  turns fixing it.
- **Every brief is a different model.** A run that produced 193 bricks and a run
  that produced 0 are the same code. Judge a change by several runs, and read the
  transcript — it has caught more bugs here than the probes have.
- A render only exists where there is something to draw with, so `shot_probe`
  needs a display. The headless suite would never exercise the path the app takes.
