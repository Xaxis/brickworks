# Assistant

Turning a sentence into a model that holds together, then looking at it and
fixing what it got wrong.

<!-- covers: lib:design loop, cli:design from a brief, cli:measure how a model is built, lib:model and effort settings, lib:reference pictures, lib:shapes said as patterns, lib:worked constructions, lib:find a reference picture -->

## Sub-features

- `design loop`: the real loop in `src/ai/assistant.gd`. It is given the part
  catalogue, the rules, and tools to search, place, read back the world and look at
  a render; it places bricks, is told what collides, floats or will not survive
  being lifted, and revises. Sections let it carry a sub-assembly at an angle.
- `design from a brief, on a Claude plan`: `tools/claude_run.sh NAME [--brief
  "..."]` — the desktop app off-screen (Xvfb, on the GPU, a free port) running
  `--ask-claude-code`, then `tools/style.py` on the model. Off-screen because a
  run in a visible window was ended by a stray Escape, which then quit the
  desktop app (it no longer does).
- `design from a brief`: `tools/design.py "<sentence>"`, which shells out to
  `godot --path . -- --ask=... --out=...`. **This spends real money.** It renders
  in software unless given `--gpu`: this machine has one GPU lease, and a run
  holding it for twenty minutes while it waits on the API queued every other
  project behind it. A software picture measured 2.6 s against the 20 s cap; a
  run that misses it logs "no picture in time".
- `measure how a model is built`: `tools/style.py <model> --against <group>`,
  how a model is built against real sets: orientation (SNOT, angled), kinds of
  part, shaping spread and mirror symmetry. Run it after a design ends, beside
  `tools/texture.py`; the recipe is under How to check it.
- `a running design, on screen`: `ChatPanel._open_run` and the card it puts in
  the conversation: what it is doing now, the steps before it, a clock, what to
  expect at this effort, and Stop. It ends as Done, Stopped or Did not finish
  with the reason in the card. Before it, a design showed one line of 11-point
  grey text and nothing on the baseplate for minutes. The expectations are
  measured (Opus 5.5, "a small red house": high 684 s and $2.42 for 260 parts,
  first check at 4 minutes; medium 249 s and $0.72 for 127). `chat_probe`.
- `a clear baseplate for a first design`: the example car of a first visit is
  taken off when a design starts on it untouched (`main._sample_untouched`,
  `ChatPanel.designing`), with a line saying so; anything placed, opened or
  cleared first leaves the baseplate alone.
- `errors in plain words`: `Assistant._what_went_wrong` leads, with Anthropic's
  own words after it only where they add something; they used to replace it, so
  a mistyped key read "invalid x-api-key". A refused key (`KEY_REFUSED`) is
  forgotten and the key form comes back. The footer says "Change key", which
  forgets the key and shows the form.
- `the key form`: with no key, the panel is this form straight away — there are
  no accounts, so nothing is asked of a server first and nothing offers to sign
  in (`ChatPanel._show_for_key`). It says what the assistant does and what a
  design costs before asking for anything, at the top of the panel rather than
  under an empty one. Then the two ways in, each under its own heading — "With
  your Anthropic API key", and below a rule "Or with your Claude plan" — kept
  short enough that Connect Claude is on screen at 860px tall. A refusal is said
  right under Use this key, and cleared when the form is shown again. In a
  browser, `tools/web/assistant_flow.mjs` shows it (`2_key_taken.png` with a
  fake key: the refusal under the button, the key still in the box).
  A pasted key is checked with Anthropic's free models call before it is kept
  (`KeyForm.check_key`, replaceable for the probe), so a typo is caught there and
  not after a brief. "Remember it on this device" can be unticked to keep it
  for this visit only (`OwnKey._this_visit`, never written). A subscription's
  `sk-ant-oat` token is refused with the reason. It recommends a key of its own
  in a Console workspace with a spend limit and an expiry. `chat_probe` checks
  both layouts and the refusals on a made-up key kept for the run only
  (`OwnKey._this_visit`); remembering one would touch the key this machine
  holds, and it presses Change key only where no key is stored. Where Claude
  Code is installed the composer stays without a key, because "My Claude" sits
  in it: `chat_probe` builds that panel too and checks Build waits for the tick.
- `design on your Claude plan`: `ConnectorForm` in the panel, under "Or with
  your Claude plan", is a switch for a `ClaudeConnector` on this tab. Off, it
  says what it is for; on, it shows a coloured state line — waiting (amber),
  connected with the time Claude reached it (green), building with a count and
  a clock, trouble (red), or taken over by another tab — and the address and
  steps until Claude has used the address once, then folds them away. It says
  to keep the tab in view. The address is kept on this device and the switch
  comes back on by itself; "Make a new address" forgets it. An address added
  to Claude before — another browser, cleared storage — can be pasted ("Added
  Brickworks to Claude before? Use that address", `ClaudeConnector.adopt`),
  so nothing changes in Claude. Claude's calls go
  into the conversation as a run card ("Claude is building"), every step kept
  with what came of it ("— refused: …" when a tool said no), and the card says
  Done with Build steps and Parts list once Claude has been quiet 90 s, or
  "Connector off" if it is switched off. One step per call: the tools' own
  progress notes are dropped while Claude's call runs, or each call showed
  twice. While the connector is on and there is no key, the key's form folds
  to "Use your own API key instead" and the section is titled "Designing with
  your Claude plan". `chat_probe` covers all of it on a
  closed port and its own file; `connector_probe` the protocol (see `web.md`).
- `a finished design's next steps`: the Done card offers Build steps and Parts
  list (`ChatPanel.steps_wanted`, `parts_list_wanted`).
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
- `built like real sets`: `src/ai/style.gd` (class `Style`), in every check's
  advice (`Assistant._style`) and so in `review_model` and the loop's look.
  Measures a design from its placements' transforms as `tools/style.py` measures
  official models: share sideways or upside down, at an angle, curved, plain,
  and the best mirror plane's share (planes voted by like pairs, as the tool
  does — the middle alone read the castle 0% mirrored). Part kinds come from
  `style_norms.json` (`part_kinds`, written by `tools/style.py norms`, packed
  for the web by `tools/web_pack.py`), not a second copy of the rules. Said only
  past the 10th/90th percentile of real sets of the brief's kind
  (`Style.group_for`: castles and Orthanc against fantasy). Found by the
  Orthanc baselines: 0% sideways, 0% angled, 57% plain, 88% mirrored against
  fantasy's 19%, 27%, 28%, 31% — and words in the guidance moved none of it.
  `style_probe`: hand-made cases, the square Orthanc fixture
  (`src/dev/fixtures/orthanc_square.ldr`) told all three, the shipped castle
  not called over-symmetric (54% here, 55% in the tool).
- `a face built sideways`: `Assistant._studs_out`, the `studs_out` pattern (in
  the assistant, not `patterns.gd`, because it needs the parts' connectors).
  Courses of 87087 turned so the side stud faces `facing` (the turn found from
  the part's own connectors on a trial brick), tied by plates staggered across
  the joints, and on every side stud a 3070b, 98138, 4073, 54200 or 3024 laid
  on its side at the corner `_corner_on` gives — the same measurement
  `attachment_points` makes. On -x/-z no cheese slope: thicker than a plate
  hangs the other way there. Found by three Orthancs at 0% sideways against
  fantasy sets' 19%, the check saying so every time. `patterns_probe` builds it
  facing each way and checks it holds and has one sideways part per side stud;
  a band measures 43% sideways in `tools/style.py`.
- `a many-sided shaft`: the `prism` pattern (`Assistant._prism`, in the
  assistant because it adds sections). `sides` 5-16 faces, each a bonded wall in
  a section of its own (`prism N face K`) turned `360 * K / sides` about the
  middle (`at`), its outer face at `radius`; faces as wide as lets the inside
  corners meet (`2 * (radius - thickness) * tan(pi / sides)`, floored), which
  leaves a groove up each outer corner — see-through at `thickness` 1, so 2 is
  the default. `mix_color`, `masonry` and `sideways` as on `fill`: a two-thick
  face alternates a course of two-wide bricks with two rows of one-wide ones
  (bonded by their own count — counted by the course every outer row started
  short and none could be masonry), and the outer row is stoned or turned out
  and dressed in the face's frame (`_lay_row`). Run 8 used `prism` (31% angled)
  and could not finish its faces: `restyle_model` skips sections and two-wide
  bricks. `open` leaves that many faces out, centred on the one turned half
  way round (looking -z), so the inside shows as a real set's tower does; the
  guidance and `CRITIQUE` ask for rooms inside, because nine Orthancs were
  solid shells and variety (shapes, colours) never moved. Found by run 5, octagonal
  piers by hand from ~150 sections (26% angled) at the cost of the rest of the
  run. `patterns_probe`: an octagon and a hexagon hold, each face its own angle.
- `a finishing pass`: `restyle_model` (`Assistant._restyle`, run through
  `edit_model` so it is checked like any edit). Plain one-wide bricks (1x1-1x4,
  studs up, not in a section) whose long face is open — the live lattice empty
  2 and 7 LDU out along the whole face at two heights (`_open_side`; both open
  means the side away from the model's middle) — are laid again in place: a
  `sideways` share (0.15) as 87087s dressed by `_dress`, only where every stud
  is held from below or above (`_each_stud_held`: a bonded course's end brick
  overhangs, and split it floated), and a `masonry` share (0.25) as 98283/15533
  facing out. Found by the sixth Orthanc: 978 plain 1x2s, 0% sideways, though
  every pattern for it was offered; restyled it went 0% to 10% sideways and 83%
  to 59% plain. Style advice names it. `mcp_probe` restyles a bonded 1x4 wall
  and checks bricks are turned, dressed and stoned, and the edit applied.
- `dressing gives way`: every tile, round tile or plate `_dress` lays on a side
  stud is marked `Placement.dressing`, and in `_check` it is the thing left out
  where it would overlap a brick, whichever came first (`_give_way`, in the world
  lattice and in a section's own). The check then runs again without it
  (`_without_dressing`), so every brick number it reports is one in the model as
  built, and says how many tiles were left out. Found by the eleventh Orthanc:
  its prism core's sideways tiles hit the piers, and the run dropped the dressing
  from the whole core to get past them. `patterns_probe`: a wall of 1x1s where a
  studs_out face's 18 tiles go is buildable built before or after it, and says
  so; with give-way off it is 18 overlaps.
- `walls partly on their side`: `fill`'s `sideways` share (`Patterns._sideways`,
  before the masonry, which would otherwise take every 1x2): one-wide bricks of
  a course (1x1 to 1x4) laid as rows of 87087 marked `dress` with the way out,
  turned and dressed by `Assistant._dress` in `_read_model` with the same side
  stud measurement as `studs_out` (`_side_stud`, cached per facing). In the
  guidance's stone-wall recipe at 0.15, because designs copy the recipes: the
  fourth Orthanc had `studs_out` and used none of it. `patterns_probe`: a stone
  wall with `sideways` 0.3 holds and every turned brick is dressed.
- `rock said as a pattern`: `Patterns._rock`. Courses of bonded bricks that
  step in unevenly (per-course weights by seed) and drift towards a peak off
  the middle, each cut to the one below so nothing floats; where a course steps
  in, a 1x2 slope (3040b) where there are two studs of ledge, else a cheese
  slope, a 1x1 round plate, a 1x1 tile or the bare stud, facing out (rot 0 +z,
  1 +x, 2 -z, 3 -x); two greys (72, 71). Found by the Orthanc baselines, which
  stood on flat plazas and stepped "wedding cakes". `patterns_probe` checks it
  holds together at three sizes, is faced, in two greys, leans (its upper half's
  centre more than a stud off the middle), and that seeds differ.
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
- `detailed one assembly at a time`: `submit_design` takes `assemblies`, the
  parts of the model a person would name, each a box in studs. Once the model
  holds together and has had its whole look, `Assistant._detail_next` hands each
  one back on its own: framed close from two corners, measured against a real set
  the size of *that assembly*, with the parts of the brief's kinds it does not use
  yet. Each pass has `TURNS_PER_ASSEMBLY` turns and edits are framed on it; at
  most `MOST_ASSEMBLIES`. A model that names one assembly gets the whole look only.
  The progress lines say what each pass came to, which is how a run is measured.
  Each pass is told what earlier passes brought (siblings converged: four towers
  given "the same crown, so they match"), and a pass that says it is done while
  its assembly is thinner than all but one real set in twenty of its size is
  sent back once ("sent the keep back" in the log). It is also sent back when
  the whole model is on the tail of real sets for one-off pieces, for one
  colour, or for big pieces — the share as big as a 2 x 4 brick
  (`Assistant._coarse`, the same rule as `rebrickable.piece_size`; a real set is
  a median 10%, every castle built before this was 39-56%). The look's measured
  advice (`_variety`) names the same tail. `detail_probe` asserts all three
  messages and what counts as a big piece.
- `reviewed from outside`: a session that is not this loop — Claude over the
  connector, or on the MCP port — gets the same review as tools. A successful
  `submit_design` answers with what the check measured against real sets and
  the way on (`Assistant._built_from_outside`); `review_model` (a socket tool,
  `CommandSocket._own_tools`) is the loop's whole look (`CRITIQUE` plus the
  advice) with no assembly, and an assembly's close pass
  (`_assembly_measured` plus `ASSEMBLY_CRITIQUE`) with one, each told what the
  last one brought. Found on the first Orthanc from claude.ai, which was told
  only "Built". An assembly's box is read from its own sides or a nested
  `where`. `mcp_probe` asserts it on a 300-brick wall. Once an outside design
  stands (`_outside_standing`), `check_design` no longer puts its trial on the
  baseplate — a session testing one part's seat wiped a 2,900-part Orthanc
  that way; `mcp_probe` checks a later check leaves the model standing.
- `how real sets build this`: a tool, over `PartLibrary.kinds_for`. The only
  thing the assistant can ask that is neither geometry nor my taste — what real
  sets of a kind are built from, by lift over sets in general. See
  `features/parts.md` for how it is measured.
- `worked constructions`: `show_technique`, a tool, over `src/ai/techniques.gd`.
  Twenty constructions with real part numbers and real coordinates — a staggered
  wall, a half-stud offset, a face turned sideways, a porthole, a smooth diagonal,
  a smooth top, a round tower, a wide round tower, a taper, a window in a wall
  (a 60593 frame three courses tall with its 60602 glass, the bond laid short
  past it, a 1x4 arch over it) and a door in a wall (60596 and a 60623 door);
  and nine taken from real sets' own sub-models in LDraw's model repository —
  lamp post, tree, bed, bench, armchair, table, planter, chimney, fence — each
  naming its set and modeller (CC BY 2.0; `docs/ATTRIBUTION.md`). They were
  chosen by what real sets' sub-models are named most (roof, door, seat, lamp,
  window, tree, then furniture), read into this app's numbers by opening each
  in the app and reading it back, and kept only where the checker passes them.
  The ones it refuses are real constructions, so a test corpus for its false
  positives: `tools/omr.py harvest ... --out DIR` then `harvest_probe.gd -- DIR`
  (110 of 162 pass, 2026-10-09; the overlaps are clips on bars and hollow
  studs, for which the parts pipeline records no connector).
- `held from the ground`: `_check_support`. A part is held if a chain of
  resting-on, clutch (both ways: a stud holds the part it reaches into and
  the part it belongs to) and pin/axle/ball joints reaches the ground or a
  brick already standing. It used to look one part down and count only the
  part a stud reaches into, so a plate pressed up under an overhang floated
  — the commonest reason it refused a real set's sub-model. Counting clutch
  both ways while still looking one part down let a stack in mid-air hold
  itself up, which `section_probe` caught. On 162 real sub-models grounded
  exactly: 107 passed before, 110 now — 8 hung constructions newly pass,
  5 upside-down ones hanging from an absent ceiling are newly refused.
  `holds_probe` asserts a hung plate holds and a loose plate floats (and
  fails with the clutch half taken out); a part on a floating part is told
  it "stands on parts that are not held up themselves".
- `inserts in their frames`: `Assistant.NESTS`, `_seated`. A pane's groove is
  narrower than a collision cell, so glass in its frame read as an overlap and
  every glazed window was refused. Measured over the model repository's sets
  (2026-10-09): panes in 60592/60593 at the frame's own origin and turn (185 and
  110 of them), doors at (±32, 0, 5) in a 60596, the far hand turned half round
  (46), 57895 glass at (0, 4, 5) (19). The overlap is forgiven only there, to an
  LDU, in the frame's LDraw coordinates; `techniques_probe` asserts a pane a
  plate high and a door half a stud along are still refused.
  Known: nothing can be laid on a 60596. Its two outer top studs are notched for
  the hinge and drawn with `3-4cylc` rather than a stud primitive, so
  `occupancy.remove_studs` never sees a stud there and keeps them as solid. The
  fix belongs in `tools/ldraw/connectivity.py` plus a sub-build of the parts it
  changes; the door technique ends the wall level with the frame meanwhile. Being *told* to stagger a wall is not the
  same as knowing where the stud sits, and the arithmetic is the part that goes
  wrong.

## How to reach it

```sh
godot --path .                                   # the Design panel
tools/design.py "a small lighthouse"             # COSTS MONEY
tools/design.py "a red sports car" --out models/car.ldr --effort max
godot --headless --path . -- --ask="a small lighthouse" --out=/tmp/x.ldr --effort=low
```

Effort is one of `low medium high xhigh max`. The app needs the person's own key,
pasted into the panel, or their own Claude plan — **My Claude** on the desktop, or
a Claude session driving the app over MCP ([mcp](mcp.md)). The CLI uses the key in
the environment or `.env`, and without one a run ends at once with
`Assistant.NO_KEY`. There are no accounts, and **the user's key never reaches our
server**: every request goes from the app straight to Anthropic.

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
godot --headless --path . --script src/dev/detail_probe.gd      # each assembly detailed on its own, through the real loop
godot --headless --path . --script src/dev/techniques_probe.gd  # the worked constructions are real parts
godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd  # and it is a picture of the model
```

Proves it when: each exits 0 with no `FAIL`. `rules` is the one that catches a
message that reads as three problems when there is one, or advice counted as an
error.

Paid, and only when the thing they exercise has changed — each spends tokens on
the key in the environment or in `.env` (`Brain.api_key()`), and refuses to start
without one.

```sh
godot --headless --path . --script src/dev/revise_probe.gd      # add to a model it did not build
godot --path . --resolution 1200x800 --script src/dev/sideways_probe.gd  # build sideways when the job needs it
godot --headless --path . --script src/dev/stream_probe.gd       # appears while it is being written
godot --headless --path . --script src/dev/bakeoff_probe.gd      # do the settings change anything
```

A real brief is the end-to-end proof: `tools/design.py "a small lighthouse"
--effort low`, then `tools/texture.py <the .ldr> --brief "<the brief>"` once the
run has *ended* — parts, shapes, colours, lots, the commonest piece, one-off
shapes, main colour and the share of big pieces against a real set of its size,
and how many of the brief's kind parts it uses. `tools/layout.py <the .ldr>` says
how it stands: footprint, height, towers over walls, against real sets measured
from LDraw's model repository (numbers in its docstring). `tools/style.py <the
.ldr> --against castle` says how it is built: the share of parts not studs-up
(SNOT) or off the 90-degree grid, the share of each kind of part (curves, slopes,
SNOT and angle parts, texture, tiles, plain bricks), how much of the model sits
beside a shaped part, and how much of it a mirror plane matches, each against the
10th/median/90th of real sets of the group (`castle`, `fantasy`, `buildings`,
`vehicles`, `space`, `architecture`, `since_2010`). The norms are
`assets/generated/style_norms.json`, gitignored: `tools/style.py norms` makes them
from `vendor/omr/files` in about a minute; without them it prints the measures
alone. `tests/test_style.py` pins each measure on hand-made models. A driven run
prints what it spent before its verdict; report it.

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
- **The ceiling on model size was never the lattice, and never the reply.** The
  lattice holds 50,000 bricks in 180 MB; a reply holds about a thousand
  placements; `patterns` only reaches shapes it has verbs for, and a castle wall
  of forty bays is none of them. `repeat_section` closes it: **250 placements
  described, 10,000 bricks built**, 780 studs along, checked in one piece and
  really on the baseplate.

  Checking those 10,000 took 108s, two thirds of it waste. Walking all 9,600
  cells of a brick to find its two corners was 20s — a box *is* its corners
  (`BrickLattice.corners_in`). `_longest_staircase` was 36s, quadratic in the
  model's *width*: a flat edge never breaks the run, and a run of equal steps
  lies exactly on its chord so there is nothing to measure. **22s now**, every
  staircase answer unchanged, which `rules_probe` is what says.

  The first guess was the cell expansion. It was 10.9s of the 108. Measure the
  phases before cutting.
- **The check measured what was wrong and threw it away on the designs that
  needed it.** A failing design gets `report["feedback"]`, which carries faults
  *and* advice. A buildable one went straight to the final look — stability plus
  five named visual faults — which never mentioned texture. The castle was 713
  bricks, 23 shapes against 117, and 208 of one brick where 81 is the 95th
  percentile; the check knew all three and showed none of them at the moment the
  design was deciding it was finished. `_check` returns `advice` now, the look
  carries it, and monotony is in the critique's named failures.
- **Do not put a wall clock in a suite check.** Three flapped in one day on a
  box shared with another project's video encode at load average 104-171; the
  suite says it itself — "nothing was proven. Check the load: these starve above
  about 12". `repeat_probe`'s became a ratio of four-times-the-bricks to
  four-times-the-work, threshold 10, because the ratio itself read 4.2, 4.9 and
  7.3 on identical code. `shot_probe`'s already measured what a frame costs on
  that machine in the same run, so it counts frames: 8 of a 101 ms frame when
  quiet, `MOST_FRAMES` 20, and above `A_FRAME_IS_HOPELESS` it reports
  nothing-proven rather than failing.

  Know what a ratio pins. With the quadratic staircase scan restored,
  four-times-the-bricks reads 5.0 against 4.2 — the same quadratic sits in both
  measurements and nearly divides out. Isolating width at a fixed brick count was
  tried and confounds width with height.
- **One call's complaint was the next call's problem.** A run reported "155
  problems (floating 125, overlap 17, **pattern 13**)" about an `edit_model`, and
  an edit takes no patterns at all: `_check` reads `_pattern_trouble` whatever
  filled it, and only `_read_model` cleared it, so a `check_design`'s thirteen
  complaints were re-reported as every later edit's own. `_edit` clears both now.
  Found by the logging, not by reading: the progress line started saying how much
  shorthand a call carried, and an edit was claiming patterns. Patterns expand in
  `_read_model`, so `check_design` and `submit_design` are where a complaint has
  something to say; `repeat_section` in both that and `_edit`.
- **`fill` is right for a straight wall and was not being used for one.** A
  castle dictated its curtain walls as 223 1x2 bricks, every joint in a column.
  `fill` then laid the same 40x24 wall in 168 1x8s and 24 1x6s, and the castles
  built that way were 39-56% pieces as big as a 2 x 4 brick against a real set's
  10%: slabs. Its courses are now a real set's sizes (`Patterns.COURSES`, 1x4
  down, 2x3 and 2x2 where a wall is two thick) on a running bond
  (`Patterns.BONDED`: the longest brick of each width starts only where its
  joints fall on a grid that moves half a brick each course, and the side that
  owns a ring's corner alternates). The same wall: **408 parts, 336 of them 1x4,
  and 0 of 376 joints over a joint in the course below**; it and a wall two
  studs thick pass the checker. `mix_color` (a share, `mix`, default 0.15 —
  real castle walls are 9-19% their second grey) and `masonry` (a share of 1x2s
  and 1x4s laid as 98283/15533) say what the short bricks are, chosen by
  position so a check and a build agree; stonework faces away from the fill's
  middle, which LDraw's -Z becoming the app's +Z at rot 0 decides, and a
  render of a ring confirmed it on the outside faces. `edge_color` existed and
  was never in the tool schema, so no design could know to use it; it is now.
  Its worked examples
  listed a dome, a cone, a tower, a hull and a bowl and **no wall** — the shape
  it is best at. The table names a wall and a room now, and
  `patterns_probe._a_wall_is_long_bricks` pins the numbers so the prompt cannot
  drift from the code.

  The same table said "a round tower → ellipse", which is where 354 1x1 bricks
  came from: an ellipse with a wall has no room for a long brick once it curves.
  It says "a round tube" now, with a `wide round tower` technique — four 48092
  corner-round bricks a course. It also said that was "the part real castle sets
  reach for second-most", from the kinds before they were counted by set over
  models only; counted properly 48092 is in none of castle's lists, and 15 of 54
  castle sets since 2010 use it, none more than eight. Every castle built here
  had 200-240 of it. The prompt and technique now say round is a choice.
  Its rotation was measured, not guessed: all four assignments stack and check
  buildable, and only one leaves the middle hollow, which turning the finished
  ring a quarter about its own centre settles (93% of cells map onto themselves,
  against 0-19%).
- **Detailing happens once, at the final look, and that one pass is worth 10
  shapes.** Run 4 of the castle brief: 1,552 parts with 20 shapes, 4 colours and
  2 castle-characteristic pieces when it first reported buildable; **1,828 parts
  with 30 shapes, 8 colours and 12** after the look. It added five rounded-top
  castle windows, four wave flags and an arch, and brought Tan, Dark Tan and
  Reddish Brown into a model that had been grey and green.

  The run progression and what to do about it live in `docs/ROADMAP.md`. What
  belongs here: read a design run's output **after it ends**, not when it first
  says "buildable" — `--out` is rewritten on every build, so the file moves under
  you, and that is how the 1,552 figure got reported as final.
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
- **A colour no part can be is refused, not drawn magenta.** `_colour_trouble`
  says why: a number LDraw does not have, or one of its internal codes — 16 and
  24 are in the palette, because LDConfig declares them under "Internal Common
  Material", so "is it in `library.colors`" is the wrong test; ask
  `BrickColor.is_plastic()`. A submitted or added brick in one is a `no such
  colour` fault with the commonest current colours as the advice; an edit that
  recolours into one is "Not applied" whole. Only bricks the design places are
  judged, not ones already standing. A brick that names no colour is 71, Light
  Bluish Grey (`DEFAULT_COLOUR`); it was 7, which LEGO stopped using in 2007.
  `availability_probe` asserts all four.
- **The palette in the rules is the data's.** `_palette_lines()` lists the
  current colours in 100+ sets, plain, see-through and metallic, commonest
  first, with names — 62 of them, about 1,300 characters. The hand-kept list it
  replaced had 37 and none LEGO added after it was typed. `vocab_probe` still
  checks every number in that block is a real colour.
- **`_never_made` is advice, and measured to stay one.** On the 276 real sets in
  LDraw's model repository it fires on 1.3% of the lots it can judge, every one
  false; see [parts](parts.md). A rubber or canvas colour is asked as its plain
  colour (`PartLibrary.plain_code`), or every tyre drawn in Rubber Black was told
  it was never made.
- **Only the rules were cached, so every turn paid for the whole design again.**
  A castle run spent $9.67, and $8 was input sent fresh: 2.04M tokens against
  575k from the cache. The request now carries top-level `cache_control`,
  which caches the conversation up to its last
  block. That only pays if nothing before it changes, and `_forget_old_pictures`
  rewrote the previous turn's pictures every turn — it now waits until drafts
  pass `MOST_PICTURE_BYTES` and drops them in one sweep. On Opus 5.5 an edited
  history also drops the thinking after the edit, so rewriting is worth avoiding
  for more than money. Proven directly: an appended second turn read 4,815
  tokens from the cache and wrote 17. A driven run's `spent` line shows the
  split; `cached` should dwarf `fresh`.
- **`advice` is not `issues`.** Hints live in their own array, because
  `errors += issues[kind].size()` counted the hint as a problem and the model spent
  turns fixing it.
- **Every brief is a different model.** A run that produced 193 bricks and a run
  that produced 0 are the same code. Judge a change by several runs, and read the
  transcript — it has caught more bugs here than the probes have.
- A render only exists where there is something to draw with, so `shot_probe`
  needs a display. The headless suite would never exercise the path the app takes.
