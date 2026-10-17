# Assistant

Turning a sentence into a model that holds together, then looking at it and
fixing what it got wrong.

<!-- covers: lib:design loop, lib:a big check on a worker, cli:design from a brief, cli:measure how a model is built, cli:score designs on the bench, cli:judge design rounds in pairs, lib:model and effort settings, lib:reference pictures, lib:shapes said as patterns, lib:worked constructions, lib:find a reference picture, lib:real sets' pieces by what they are, lib:recall our own scored designs, cli:run the designer on BrickBench, cli:test designs against real sets, lib:keep a run to a list of parts, lib:the surface pass, ui:ask claude about the selection, ui:sketch first, lib:claude's design is one undo step, cli:design undo probe, lib:the check by real shapes, lib:placing a part by its connectors, lib:figures told of their joints, lib:characters laid on joints -->

## Sub-features

- `design loop`: the real loop in `src/ai/assistant.gd`. It is given the part
  catalogue, the rules, and tools to search, place, read back the world and look at
  a render; it places bricks, is told what collides, floats or will not survive
  being lifted, and revises. Sections let it carry a sub-assembly at an angle.
  A figure, a creature or a character goes another way from a hull: the guide's
  FIGURES, CREATURES AND SMALL MODELS (read_guide "figures", "character",
  "creature", "small"), which the MCP head's step 2 sends it to, builds it as
  sub-assemblies of shaped parts on joints, never a shape pattern, keeps to the
  brief's scope (nothing it does not name, the base it names) and makes a
  minifigure-scale person a minifigure. With it: plan_scale answers a person- or
  animal-sized subject as a figure; a small round body said as a shape is told of
  round bricks, domes and dishes (`SMALL_ROUND`); the creative pass keeps to what
  the brief names when it lists the scene; a design's baseplate is the least in
  eights each way. Checked by `rules_probe` ("a small round body", "choosing a
  scale"), `floor_probe` (the garden's 16 x 8) and `mcp_sync_probe` (the head
  under 3,500).
- `the check by real shapes`: `src/ai/exact_check.gd` over `src/assembly/exact.gd`,
  called from `Assistant._check`, so every check, edit, submission, review and save
  has it: each part BrickNet has is its convex colliders and connector labels
  (`assets/generated/exact/<hash>.bwx`, `tools/build_exact.py`). More than 1 LDU of
  overlap through any two pieces is a collision, named with its fix; a piece of the
  design no connection holds is a fault unless it stands square (`rests`); a piece
  only the floor holds, on a bare floor (floor "none" or "grid", or no baseplate
  laid: `Assistant._on_bare_floor`), is "tips over" unless its centre of mass is
  over where it touches the floor by a hundredth of its height (`tips`: a body over
  its heels, a can lying on one line of its facets); a part
  up to a plate off a stud, hole, hinge or bar is seated on it first (a nudge keeps
  the LDU past the lattice cell). Without the `exact/` folder the check is the
  lattice alone, as it was. Recipe under How to check it, "The check by real shapes".
- `figures told of their joints`: `Style.character_of` (src/ai/style.gd) reads a
  subject as a figure (people's words and he or she), a creature (the living
  things that are not plants) or a thing with a face (eyes, brows, a grin), a
  hyphenated word by its last part, and never a vehicle (its crew is its
  crew); the subject is the brief, what a session from
  outside was started on or asked plan_scale, find_reference and
  how_real_sets_build_this about (`Assistant.heard`), and the design's name. For
  one: check_design's and submit_design's reply, while nothing in it is posed
  (`_posed`: an attach, a joint's part, a turned or hinged section), leads its
  advice with each joint's one call (`_on_joints_said`, twice in full and then a
  line); plan_scale lays out the posed minifigure and the armatures ("jointed
  figure", "jointed animal"); search_parts names the joint parts under a limb's
  search and a character's first (`_joint_parts_for`); read_guide "shapes" is led
  by what a figure is built of (`_for_the_subject`); the review says which named
  limb stands stiff and stacked (`_stiff_limbs_said`); the living things' advice no
  longer tells a creature to lay its body as a shape. Recipe under How to check
  it, "Figures on joints".
- `characters laid on joints`: `src/ai/figure_pattern.gd` (`FigurePattern`), read
  by `Assistant._with_figures` ahead of a design's own bricks. One entry of
  submit_design's or check_design's patterns, `{"pattern": "figure", "kind":
  "person" | "animal" | "head", "at", "height" | "length", "color", "colors",
  "pose"}`, lays a person (arms on ball shoulders posed by words, a head on a
  jumper's stud, seated on a block of its own if said), a four-legged animal (head
  on a ball neck, tail on a bar) or a head on a neck, as named bricks with
  attaches, the larger size from 34 plates or 7 studs. A figure or creature
  submitted with nothing on a joint is sent back once (`_unjointed_refusal`) with
  that entry written out for its box and colour (`_figure_call`); the subject is
  read as for the joints' advice, and a fresh brief (`heard`) or a model cleared or
  opened (`forget_built`) forgets the last design's name. Only when the character
  is the subject: a scene it is in is never sent back (`Style.in_a_scene`: the
  brief's first words, the design's name or its description headed by a place, a
  building or a vehicle, as "Scorpion Pyramid" is a pyramid, or a place named before
  any person or creature), though it is still told of joints. Recipe under How to
  check it, "Characters laid on joints".
- `placing a part by its connectors`: `src/assembly/attach.gd` (`Attach`), read by
  `Assistant._attach_parts`. A brick of submit_design, check_design or edit_model
  may say `"attach": {"to": "torso.hinge[0]", "by": "hinge[0]", "yaw": 240}`
  instead of x, y, z: `to` is a part of the same call by its `name`, a part named
  in an earlier call (`_given_names`, kept with the world), a section of one by its
  name, or a brick standing (`"#41.stud[3]"`); connectors are BrickAgent's
  addresses (a stud's, hole's or axle's subtype, else hinge, ball, fixed; numbered
  within the type in BrickNet's order) off the exact shape, else the catalogue's.
  The pose is BrickAgent's `placement()` (yaw about the joint, flip, slide,
  seat, align, orient; on a ball, align points the part that way), a pin in its
  socket slid to the least clear slide; it is written square in the target's
  frame with a nudge, or as a section of one within the target's section. The
  check holds a part by the joint it was put on where BrickNet's labels join them
  (`_attach_joins`), and a leaning section by any such joint that is not a stud
  (`_leans_on_exact_joint`). attachment_points lists every connector by address
  (`near=` for those by a point); look_at_model shows names; show_technique has
  "figures and joints" (posed minifigure, limb on a clip, ball shoulder, head on a
  neck, tail on a bar, hinged wing) and place_technique lays one by name. Mirror
  skips attached parts. Recipe under How to check it, "Placing by connectors".
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
- `score designs on the bench`: `tools/bench/run.py`, ten fixed held-out
  subjects designed on the subscription, rendered, checked, measured and scored
  1-10 on six dimensions by a judge calibrated by two anchor pictures; tables in
  `docs/DESIGN_SCORES.md`. Under How to check it, "The design bench".
- `judge design rounds in pairs`: `tools/bench/pairwise.py`, through
  `tools/bench/run.py pairs`, `calibrate` and `rank`: every two designs of a
  subject judged A or B per dimension, both orders, fitted as Bradley-Terry ELO
  with intervals, and each lever's change with the run-to-run spread in it.
  Under How to check it, "The pairwise judge".
- `run the designer on BrickBench`: `tools/bench/brickbench.py`, the outside
  ruler: the first ten prompts of BrickBench's Model setting through the real
  loop on the subscription, kept to BrickNet's 14,441 parts, exported as the
  `model.mpd` and `build.py` their `verify.py` rebuilds, checked by their
  `verify.py` and `check_submission.py`, and judged against BrickAgent's Opus 5.5
  builds of the same prompts by our pairwise judge. `docs/BRICKBENCH.md`. Also a
  controlled comparison of arms on held-out prompts (`--start 21`, `--arm`,
  `--runs`, `--app` an export of another commit, `--arms`, `compare`): every
  design of every arm against each other and theirs, ELO per arm with prompts
  resampled, head to head, and what each arm's builds are made of (stacked,
  plain, shaped, tile, joints, size, baseplates). Under How to check it,
  "BrickBench".
- `test designs against real sets`: `tools/bench/realset.py`, the main quality
  bar since 2026-10-16: subjects drawn from LDraw's model repository that no round
  touched (left out by kind, by name, theme and sub-model names), two fixed halves
  (tune, proof) with an animal, a person and a creature each, a brief from the
  set's name, theme, footprint and piece band, the real loop on the subscription
  (`--arm`, `--checkout`), and the pairwise judge blind between the design and the
  set, both orders; win rate per dimension with 95% intervals, the set-file
  measures side by side, and two arms through the set and head to head. A set's
  own pieces are held out of the designer's real-set index by `--held-out=<set
  number>` (src/ai/real_snippets.gd). `docs/DESIGN_SCORES.md`, "Against real
  sets". Under How to check it, "Real sets".
- `keep a run to a list of parts`: `src/parts/parts_only.gd`, `--parts-only=FILE`
  (a part number a line, the first `#` line naming the list). search_parts and
  find_parts_like list only those; a design or edit with another is refused
  naming it ("not among this run's parts", swap it); add_minifig chooses among
  them; make_part, lay_flex and print_part are refused; any call that leaves one
  off the list on the model says so. A number LDraw has moved (3023, 4073) is
  the part it moved to (3023b, 6141), so the generators' fills, shapes and rounds
  are not refused, and the export writes the listed number. Without the flag
  nothing changes.
- `ask claude about the selection`: select parts, right-click one and choose
  **Ask Claude about this…** (top of the part's menu; also Edit, and Ctrl+K).
  The assistant panel opens with a chip, "About 46 selected parts", and the
  next request is about them: "make this wing curved", "recolour this in
  tan", "why is this not stable?". Claude is given the parts by number with
  where each stands, their box, the sub-assembly they share, the joints in
  and round them (`Stability`, under 1,500 parts), and two pictures with the
  selection in magenta, close up and in the whole model
  (`Assistant.selection_said`). It may take off, paint, move or put down
  parts only inside the selection's box grown by two studs across and three
  plates up and down (`SelectionScope`, `src/ai/selection_scope.gd`), or a
  box it asks for with `edit_selection` `room=` and `why=`, which the person
  allows or refuses on a card in the panel (`room_asked`, two minutes, no
  one there is a no). A change reaching outside is refused whole, naming
  the parts. A change inside is checked as any edit is, and then once more
  for what it leaves hanging: the check excuses parts that already stood, so
  taking a plate out from under another passed it; `_left_hanging` compares
  what holds from the ground alone before and after (`_ground_only`), and
  the number of pieces. While a request about a selection stands (the chip
  is up, or `--ask-about`), every edit keeps to the room, edit_model from a
  session included, and submit_design, add_minifig, make_art and
  clear_model are refused; check_design never puts a trial down.
  Every change of one request is one undo step ("Claude's change to the
  selection (3 painted, 1 put down)"); Stop takes it back. New parts go
  into the selection's sub-assembly, the selection becomes what it now is,
  and the panel shows Before and After pictures of the room in its own
  colours. Three ways in: the app's own loop on a key (`about_selection`,
  edit_selection offered only then), the person's Claude Code ("My Claude":
  the brief is `Assistant.selection_brief`, the session reads `selection`),
  and Claude on their plan over the connector or MCP (the `selection` and
  `edit_selection` tools; see [mcp](mcp.md)). From a command line:
  `--model=res://models/orthanc.ldr --ask-about=x0,x1,y0,y1,z0,z1
  --ask-claude-code="..."` selects the parts whose middles are in the box.
  On the shipped Orthanc (9,429 parts) an edit is ~30 s, three checks of
  ten; the next edit reuses what held after the last. `selection_probe`,
  `handbuild_probe` (only=first_timer), `mcp_probe`.
  A real run, on the subscription (2026-10-12): the shipped Orthanc, the 158
  parts of its west horn selected with `--ask-about=4,15,235,300,22,34`,
  "make this horn more jagged and menacing: two or three smaller spikes
  along its outer edge". Opus 5.5 through Claude Code read `selection`, then
  had 22 edits refused by the joints check (17 for an overlap, 5 for a part afloat) while it
  found the studs of a horn laid in a turned section, landed two edits
  (13 put down, 3 taken off: three 1 x 1 tooth plates and the tiles round
  them in place of two 2 x 4s and a 2 x 3) as one undo step, and said so in
  865 s. Nothing outside the room changed: the saved file differs from
  `models/orthanc.ldr` in those 16 lines alone. The spikes are small; the
  part was the hard thing, not the room.
  So the selection now says where a part can go, and a refusal says where
  instead (`OpenPoints`, `src/ai/open_points.gd`, the check's own rules
  asked of one part against the live lattice). `selection` gives each part
  as edit_model reads it, `section='turned 25 2'` and that section's own
  studs and plates for a part laid turned (it gave world corners, which no
  edit could write back), names the sections, and counts the open points by
  the way they face. `where_to_attach` lists every open stud, anti-stud,
  side stud, pin hole, bar and clip of the selection, free or taken, grouped
  by heading, with a picture of the room with the free ones numbered in cyan
  (`ShotRuler.marks`); with `part=` it seats that part on them, each tried
  with the ones before it standing, and gives placements that fit, hold and
  keep to the room, to paste into edit_selection as they are (`toward=out`
  puts outward-facing points first, `near=` those nearest a place). A
  refused edit says, part by part, what each new part runs into or why
  nothing holds it, and the nearest place it fits and holds (a plate up, half
  a stud along; else the nearest free stud of the room it seats on), as a
  placement (`Assistant._what_would_fit`). `check_only=true` tries a change
  without making it. Other copies of the sub-assembly the change was made in
  follow it in the same undo step (`Assemblies.copies_follow`,
  `Assistant.assemblies`). New parts now really go into the selection's
  sub-assembly: `Builder.set_path` called by the class's name reached
  Resource's own one-argument set_path and failed. `selection_fit_probe`.
  Measured on the subscription (2026-10-13, Opus 5.5 through Claude Code,
  the same three requests on the code before and after, both with the short
  guidance head): Orthanc's west horn, "more jagged and menacing: two or
  three smaller spikes", had 12 edits refused before the first landed at
  507 s (542 s in all) before, and 2 after (one a check_only try, one
  reaching outside the room), landing at 277 s (283 s in all): three 1 x 3
  plates set into the blade, each with a tooth plate standing out past the
  edge. The car's bonnet ("sleeker, curved") and a castle wall ("weathering")
  were easy either way: 0 and 0 refused, 53 s and 52 s for the bonnet; 0 and
  1 for the wall (that one landed on the next try, 6 s later), 105 s and
  116 s. The spikes are still small: landing first time did not make Claude
  bolder by itself.
- `sketch first`: **Sketch first**, ticked beside Build it whenever the next
  request would start a design from nothing (not for a change, not about a
  selection: `ChatPanel._show_sketch_first`). Build it then calls
  `Assistant.sketch`, which asks for three `submit_design` calls with
  `sketch: true` in one reply (`SKETCH_ASK`), on `Brain.sketch_model()` at
  `Brain.sketch_effort()` — Sonnet 5.5 at medium, or what is chosen when
  that is cheaper or lower. Each sketch is read, refused past 150 parts
  once its patterns are laid, checked (`_checked`), and drawn on a world of
  its own that is in no tree and draws nothing (`BrickWorld.add_unseen`,
  `Assistant._stage_of`) by `ModelShot` with no studs written on; nothing
  touches the baseplate, and the stream's live drawing is off for the round.
  `Sketches.measure` reads each one's size and its outline from the front,
  the side and above, counted from its own ground corner; two within 15% on
  every size whose outlines overlap 70% are one idea (`Sketches.alike`), and
  the later one is sent back once for another (`SKETCH_REDOS`). After four
  turns whatever there is is shown. Then `sketches_ready`: the run's card
  closes saying what the three cost, and the panel shows a card for each —
  picture, name, parts and size, its description, and Design this one
  (`sketch_1` to `sketch_3` in `controls_by_name`). Choosing calls
  `choose_sketch`: the sketch is put down as a design is (`_apply`, so
  `built` and the build animation), the other two dropped, and the whole
  model designed from it in a fresh conversation at the chosen model and
  effort, opening on the chosen sketch's picture and its submit_design
  input (`_sketch_opening`, `FROM_SKETCH`). The final bill line adds "the
  sketches before it". A brief typed instead of choosing starts afresh.
  Over MCP: each `submit_design` with `sketch: true` answers with its
  picture and asks for the next; the third answers with all three and how
  to choose; `choose_sketch` (`sketch_tools`, served outside only) puts one
  down and says to design the whole from it. The panel shows a session's
  three too, without buttons, and marks the one it chose. My Claude with
  the box ticked, and `--ask-claude-code=… --sketch-first`, put
  `Assistant.SKETCH_FIRST` after the brief; from the command line each
  sketch is printed, its picture kept beside `--out` as `NAME_sketchN.png`,
  and the session's time and tokens printed when one is chosen and at the
  end (`ClaudeCode.spent`). `sketch_probe` (a recorded brain,
  `tests/fixtures/sketches/lighthouse.json`), and in a browser
  `tools/web/assistant_flow.mjs --recorded`, which answers Anthropic itself
  with the same recording, presses Build it and then sketch 2's card, and
  checks the requests' models.
  A real run on the subscription (2026-10-13, Opus 5.5 through Claude Code,
  `--sketch-first`, off-screen in software), held out: "A lighthouse on a
  rocky coast, as a detailed display model about 30 cm tall." Three ideas,
  each holding: a slender banded tower on a reef (71 parts, 16 x 16 studs,
  84 plates), a short white tower on a stepped headland (98; 16 x 16, 48),
  and a tapering banded tower with a keeper's cottage on a rock shelf (143;
  28 x 24, 80). Six more were refused for passing 150 once their patterns
  were laid (375, 561, 186, 168, 158, 159), which is why the refusal now
  says patterns count and to use the biggest pieces. It chose the third
  ("a lighthouse and a coast, and its tapered outline reads better"), and
  the design from it was 572 parts: the tower and the cottage on a rock
  shelf, a blue baseplate for the sea, a keeper, the lamp on a turntable.
  The composition held; the taper and the red bands did not (black bands).
  The sketches took 132 s of the session's 622, 13 replies, 712k tokens in
  (643k of them cached) and 12.4k out; the design after them 490 s, 42
  replies, 5,145k in (5,053k cached) and 39.4k out — a fifth of the time
  and a quarter of the output, about 72¢ against $2.26 at Opus API prices,
  and the 69k of rules the sketches wrote to the cache are what the design
  then read at a twentieth of the price. The app's own loop sketches on Sonnet at medium,
  cheaper again. The output tokens are from the session's transcript:
  Claude Code's stream gives each reply's usage as it starts, so
  `ClaudeCode.spent` counts input as it goes and output only from the
  session's result. Pictures and the log: `shots/runs/sketch_lighthouse/`
  in the drafts worktree.
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
  cleared first leaves the baseplate alone. The model is then a new one named
  for the brief (`ModelStore.name_for`: "Build the Tower of Orthanc from Lord
  of the Rings, about 40 cm tall" is "Tower of Orthanc"), and the design's own
  `submit_design` name replaces that when it stands (`Assistant.titled`), never
  a name somebody typed or saved. It kept the car's name, and Save saved the
  tower as "Example Car for Demonstration of LDRAW Library". A design started
  on a bare, Untitled baseplate is named the same way. `example_name_probe`.
- `claude's design is one undo step` (`src/ai/claude_step.gd`): each request in
  the panel, a design or a change to it, is one step of the history, "Claude's
  design (12 put down)" or "Claude's change (12 painted)", kept as its run ends
  (Stopped too); a session from outside has one a call
  (`CommandSocket._one_step`). The loop puts its work down without the builder,
  so before 2026-10-14 a request in the panel made no step at all, and the
  person's Undo took back their own last part. What the person does while it
  runs keeps steps of its own: a part one of theirs names is left out of
  Claude's. A run that fails and puts the model back makes none; about a
  selection, its edits gather into one already. `design_undo_probe` runs the
  real loop against a stand-in for the API on this machine and fails on 480b81a
  (12 failures: Undo took the person's brick and left the wall).
- `the floor a design stands on`: `submit_design` takes `floor` ("none",
  "baseplate", "grid") and `floor_colour` (a colour baseplates come in, by
  name); the guidance says a vehicle, a ship, a figure or a creature has no
  plate in its box and a scene, a diorama or a building on its lot comes on
  one. `Assistant.floor_chosen` → `Main._on_floor_chosen`: none is View,
  Floor, No floor; a baseplate is the least of 16, 32 and 48 square that
  holds the model with a stud to spare (in eights past that), in that colour,
  made part of the build — when the app's own design finishes
  (`_plate_after_design`, so the pictures it judges by are of the model), at
  once for a session over MCP. A line in the chat says which, once; the
  person changes it with View, Floor, and one undo takes it back. In
  `floor_probe` (the designer chooses), through `use_tool`, spending nothing.
- `errors in plain words`: `Assistant._what_went_wrong` leads, with Anthropic's
  own words after it only where they add something; they used to replace it, so
  a mistyped key read "invalid x-api-key". A refused key (`KEY_REFUSED`) is
  forgotten and the key form comes back. The footer says "Change key", which
  forgets the key and shows the form.
- `the key form`: with no key, the panel is this form straight away — the
  person's Brickworks account (they are signed in to reach the panel at all,
  see [account](account.md)) pays for nothing, so nothing is asked of a server
  first (`ChatPanel._show_for_key`). It says what the assistant does and what a
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
  your Claude plan" (2026-10-11). Not connected, it says what it is for and
  offers **Connect Claude** (`ClaudeConnector.connect_claude`): this tab
  starts listening, the shared address (`/api/mcp`) goes on the clipboard, and
  claude.ai's documented install link opens — `https://claude.ai/customize/
  connectors?modal=add-custom-connector&connectorName=Brickworks&connectorUrl=…`
  — with a three-step guide (Add then Connect; sign in as <the account's
  address> and Allow; come back) and the address to paste if no tab opened.
  **Connecting again** (2026-10-14): for an account that has had Claude
  connected (`op=connections` says `before`, kept in the account's
  server-only record past a Disconnect; `ClaudeConnector.had_claude`), Connect
  Claude opens Claude's own list instead, `https://claude.ai/customize/
  connectors`, and the steps say to select Brickworks under Your connectors and
  press Connect (or Reconnect), not to add it again, which sets up a second one
  with its tool permissions to choose again; Account says the same
  (`connect_words`). Add custom connector stays for the first time, and as the
  fallback when Brickworks is not in their list. Menu names as claude.com's
  connector docs give them. `chat_probe` checks both: a new account gets Add,
  one with a past connection gets the reconnect steps.
  Links beside it open, one at a time, **Claude Code** (the `claude mcp add
  --transport http brickworks …/api/mcp` command, then `/mcp` and
  Authenticate), **Claude app** (it shows claude.ai's connectors; or Customize,
  Connectors, Add custom connector, and the address) and **Private address**
  (this browser's own `?t=` address, the way before, with its switch, Copy,
  "Make a new address" and a field to paste one added before —
  `ClaudeConnector.adopt`). The state line: waiting for Claude (amber),
  "Connected to Claude [and Claude Code] — it builds in this tab" (green),
  building with a count and a clock ("Claude is building — 12 calls in 3:41",
  said as each call comes, never on a timer: a one-second tick drew the whole
  window every second from Claude's first call on, which in a browser drawing
  in software kept the page drawing for good and every picture waiting behind
  it, 2026-10-16; the run card's clock likewise moves with Claude's calls),
  switched off in this tab (grey), trouble
  (red), taken over by another tab. The account's connections come from
  `/api/oauth?op=connections`: on sign-in (`resume`), when the section is
  shown, every 5 s for ten minutes after Connect Claude, and at once when the
  relay says `brickworks/connected`. Once Claude is connected the switch
  ("Let Claude build in this tab") is on by itself in every tab the person
  signs in to, unless they switched it off there (`off_here`, kept on the
  device), and **Disconnect Claude** ends every connection. `window.
  brickworksClaude` tells the page `{on, connected, status}`. Claude's calls go
  into the conversation as a run card ("Claude is building"), every step kept
  with what came of it ("— refused: …" when a tool said no), and the card says
  Done with Build steps and Parts list once Claude has been quiet 90 s, or
  "Connector off" if it is switched off. One step per call: the tools' own
  progress notes are dropped while Claude's call runs, or each call showed
  twice. While the connector is on and there is no key, the key's form folds
  to "Use your own API key instead" and the section is titled "Designing with
  your Claude plan"; until Claude's first call there is no empty conversation
  above it, so the steps sit under the title (they were at the panel's foot
  under a blank two-thirds of it). The panel's secondary actions — that one,
  Claude Code, Claude app, Private address, "Make a new address", "Disconnect
  Claude", "Change key", "Add a picture of it" — are links (`Look.link`: blue, underlined, as wide as their words), not
  flat buttons in body text, which the owner could not tell were pressable.
  The switch and every tick box are drawn by `Look.apply`, outlined so an
  unticked one shows on a dark panel. `chat_probe` covers all of it on a
  closed port and its own file — Connect Claude's link and guide, connected,
  the Claude Code command, switched off here and kept off next visit, both apps
  named, the account panel's Claude section, the private address — and
  `connector_probe` the protocol (see `web.md`); `tools/web/oauth_flow.mjs`
  the whole of it in a browser on a deployment ([account](account.md)).
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
- `a big check on a worker`: `Assistant._checked`, which every tool path
  (check_design, submit_design, edit_model, add_rooms, review_model, and the
  app's own loop) waits on a frame at a time. From `CHECK_OFF_THREAD_FROM`
  (300) placements the check runs on a `WorkerThreadPool` task while the app
  goes on drawing and answering; below it, in place. On the web the page has
  one thread, and the owner's 4,242-part Falcon Heavy was a 31 s task per
  check in a browser (3.4 s on the desktop). What the worker reads is made
  still first: every part is loaded (`_ensure_parts`; a worker never loads,
  `PartLibrary.mesh_for`), the library holds parts that arrive meanwhile aside, and a part made meanwhile waits for the worker
  (`begin_reading`, `end_reading`), the bricks already standing are copies
  (`_others_standing`), turned covers have their own locked cache
  (`Builder._turned_off_main`), and the tables filled on first use — the style
  norms, the minifigure name patterns — are filled before it starts. One
  worker at a time; a second check meanwhile runs in place. The probes call
  `_check` itself, as before. `responsive_probe` holds the same answer either
  way, frames throughout, and a brick placed and a part loaded during it.
  And a design is put down a slice a frame (`_apply(model, finished, true)`;
  `FramePace`: 12 ms a slice at sixty frames a second, up to half a frame
  where frames are slow — in software a browser frame is over a second, and
  12 ms slices made putting the Falcon down take a minute, past the relay's
  four) with `BrickWorld.hold_drawing` until it is whole, so the
  build animation is the first anyone sees of it; Stop in the middle puts the
  model back and places no more. The probes call `_apply` as before, all at
  once.
  Each picture is also read into the plastic colours sets are made in
  (`ReferenceFinder.colours_in`: CIELAB nearest of the current solid colours,
  the frame's own colours taken as backdrop unless the picture is a cut-out on
  a transparent ground, the middle weighted), and the answer says them once
  as numbers to build in (`Assistant._colours_seen`): "White (15) 76%, Light
  Bluish Grey (71) 10%, ..." for Commons' Falcon Heavy pictures. Found by the
  owner's Falcon Heavy, built in three greys with a white rocket in the
  pictures. `reference_probe` (offline): a white rocket with a black band on a
  sky reads White with Black and no sky; a cut-out drawing running to its
  frame reads White (it read Black before the cut-out rule); the answer names
  both numbers. Photographs of launches, with towers, smoke and ground, read
  muddier, and the answer tells the design to look at the picture to tell a
  shade of the main colour from a colour of its own.
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
  The calls it names follow what the subject is (`Style.traits_of`: round,
  vehicle, living, machine, by whole words in the brief and the model's name;
  `Style.calls_for`): a rocket is told of the round pattern, a car of wedge
  plates and a hinged section, an owl of curves and hinged wings, a machine of
  pinned Technic; restyle_model and the prism only where the subject is a
  building, a tower or unknown. A model whose curve share is past the 90th
  percentile is not told it is square for having nothing on its side. Found
  by the owner's Falcon Heavy, whose description named its launch tower: it
  was told "a prism with piers, for a tower like this one" and restyle_model,
  which put polka dots on a rocket. `style_probe` ("the advice knows what the
  subject is"): the square fixture said to be a rocket by its tower, a car and
  an owl; a steam locomotive is round and a vehicle; no car in "carriage".
- `the touches nobody asks for`: `Assistant._touches`, in every check's advice
  from 300 parts: a model with no printed or stickered part (`_decorated`:
  "Sticker", "Pattern" or an LDraw pattern suffix on the number) or nothing
  that moves (a style `a` part, a pin or ball connector, a hinged section) is
  told so, with a figure, a story detail and a display stand with a
  nameplate. Measured over Rebrickable's inventories of the 2,517 sets of 300
  parts or more since 2015: 95% carry a printed or stickered part, 94% a
  hinge, turntable, Technic pin or ball joint, 1.6% none of these — each
  missing is a one-in-twenty tail, as every advice here keeps. The guidance
  says them under FINISHING TOUCHES and maps shapes to calls under WHAT THE
  SUBJECT NEEDS; the critique names both, and `FROM_OUTSIDE_NEXT` ends on the
  touches. `style_probe` ("the touches nobody asks for"): a plain 320-part
  model is told of both and of a figure; with a printed tile, only of what
  moves; with a hinge too, of nothing.
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
  a band measures 43% sideways in `tools/style.py`. `dress` makes it a band of
  one kind of detail (`Assistant.DRESSES`: tiles, rivets, round, lights; a mix
  by default) — rivets down a hull plate, portholes, a row of lights in a
  transparent `face_color`; `patterns_probe` checks each band's every stud
  carries its kind and holds.
- `a many-sided shaft`: dressed by default (masonry 0.25, sideways 0.15; 0 for a
  plain face): the thirteenth Orthanc stood a prism of plain faces, 61% plain,
  that the finishing pass cannot reach. The `prism` pattern (`Assistant._prism`, in the
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
  bricks. `open` leaves that many faces out, the ones nearest looking -z
  (the lower number of two as near), so the inside shows as a real set's tower does, and
  `add_rooms` furnishes it (rooms inside, below); asked for because nine Orthancs were
  solid shells and variety (shapes, colours) never moved. Found by run 5, octagonal
  piers by hand from ~150 sections (26% angled) at the cost of the rest of the
  run. Each face is laid as a cluster's core face is (`_cluster_face`), its outer
  row run on into the corner groove where there is room. Windows only when
  asked (`"windows": true`): a 3005 in `window_color` (`WINDOW_COLOUR`, 40
  Trans-Brown, a dark slit, unless said) in the outside row at the widest
  run's middle stud, two courses tall, every `WINDOW_EVERY` (16) courses, on
  every other face (`_lay_face`, `_lay_row_around`); on a cluster, the core's
  faces and the piers' faces that look away from the core, not the horns. The
  inside row stays whole, so a window is never seen through, and
  `restyle_model` leaves transparent bricks alone. They were lit yellow every
  eight courses up every face by default, and the homepage's Orthanc (run 18)
  read as an office block, 228 lit 1 x 1s in rows — the owner's worst verdict
  yet. A black face takes dark bluish grey unless told (`SECOND_TONE`, as
  10237's 66% black and 13% grey) as a band: one course of it every
  `BAND_EVERY` (8), a string course where 10237 has its ledges, never
  sprinkled — scattered through the bricks (Orthanc rk1) it read as noise.
  `band_color` sets another; a `mix_color` said means a scatter instead on a
  light face, and on a dark one goes onto its ribs. A
  black `fill` wall with `rise` 3 does the same (`Patterns.BAND_EVERY`). A dark
  face's texture is organised, never scattered (the run after the blades
  sprinkled round tiles, cheese slopes and grey over its black and read as
  noise): its outside row is turned out only in ribs (`_ribs`, `_lay_row`), a
  87087 at the face's middle and every `RIB_EVERY` (4) either side, with a stud
  before and two after (split with one after, a face's run-on into its corner
  groove was left a column of 1 x 1s held by nothing), each carrying a round
  plate (`RIB_PART` 4073) in the wall's colour or its `mix_color`; and every
  `GRILLE_EVERY` (2) outside rows the bricks either side of each rib are grille
  bricks (2877, 3005 for an odd stud), a strip flanking the rib, each starting
  over the face (`_grille_until`; one wholly in the corner groove hangs): 10237
  is 86 grille bricks in 2,359 parts, 3.6%, the Orthanc after the bands was
  0.2%, and a band round every other row only 0.7%. Masonry, relief
  in the wall's own colour, is still scattered. `restyle_model` on a dark wall
  turns out only bricks of one or two studs starting on a column every
  `RIB_EVERY`, the same round plate up each, and gives a `face_color` to whole
  columns; a dark `fill`'s `sideways` bricks stand in columns
  (`Patterns.SIDEWAYS_EVERY`). `patterns_probe`:
  asked for, 16 window studs on the guidance's cluster, each paired two
  courses tall, Trans-Brown, no office block said; none unless asked; a black
  cluster with no mix_color has hundreds of grey, every one in a band course,
  and 2-8% of its parts grille bricks; a black wall's grey is one course at y 21 with no black in
  it; the finishing pass leaves the windows.
  `patterns_probe`: an octagon and a hexagon hold, each face its own angle.
- `the faults of a picture`: three checks in every check's advice, each a
  fault the homepage's Orthanc had and any subject can: `_window_grid` (12 or
  more of one lit window — a warm transparent colour — 70% of them in rows:
  "reads as an office block"; glass is not counted, because Big Ben's facade
  is 380 trans-brown 1 x 1s in rows), `_dark_and_plain` (40% of a model of 200
  parts plain bricks and plates in one dark colour: "reads as a hole", with
  10237's texture parts named) and `_straight_shaft` (taller than twice its
  width and the same width within 12% from a tenth of its height to nine
  tenths, said with taper, flare and a crown; not of a round or a vehicle).
  All three fire on run 18 and on none of the eleven shipped models, the runs
  of 2026-10-11, or eight real sets from LDraw's repository (Big Ben, Tower
  Bridge, Hogwarts Astronomy Tower and Great Hall, two castles, the Bookshop,
  Minecraft's Mountain Cave); the critique, the assembly critique and the
  guidance name them with the fourth, a base that is an afterthought.
  `style_probe` ("the faults of the homepage's Orthanc"): a black 4 x 4 shaft is
  told hole and no profile, light grey not a hole, a rocket not a shaft, a
  stepped tower has a profile, lit windows in rows are an office block and the
  same in dark glass are not, and none is said of any shipped model. Three
  more since the run after the blades, each any subject's: `_speckle`
  (`SPECKLE_FROM` 24 or more pieces of dressing, or in a section's wall a
  second tone, on a dark wall, 40% of them scattered: neither in a column
  holding `SPECKLE_COVER` (60%) of the courses its wall is marked in, a rib, nor
  in a course holding 60% of its columns, a band, and either at least
  `SPECKLE_LINE` (3) long; a second tone in the main body is not counted, so
  mottled rock is not speckle. A wall is one plane (`_speckle_marks`):
  dressing looking the same way from the same depth, in its section's frame
  or the main body's, and a second tone in one row of bricks, so each storey
  that steps in is its own. It was the section or the whole main body, and
  the landing page's Orthanc read back from its file was told 559 of its 593
  pieces were scattered — the rib up each storey's face counted against every
  course of the tower — where per plane 99 of 1,078 are), `_daylight` (slits of
  sky between `DAYLIGHT_SLIT` 0.1 and 1.5 studs wide right through a model
  of 200 parts or more, from any of the eight views at nine heights, measured
  off each part's own box laid flat as `daylight_probe` measures it, counted
  from a view where it shows at `DAYLIGHT_RUNS` (2) heights or more: up to 0.9,
  the run after these rules was told of slivers between its crags and its
  tower, seen at one height, and not of a stud-wide channel through its piers
  at all nine) and
  `_wide_yard` (a model more than twice as tall as it is wide half way up, on a
  base `YARD_WIDER` (1.6) times as wide: the run stood its tower on a 66-stud
  yard, 1.9 tall to wide where the tower alone was 3.3; and the base open
  ground, `YARD_OPEN` (half) of its studs with nothing rising off them, and no
  stand: not when the brief or the model's name asks for one, nor when most of
  the base is an assembly named as one, `STAND_WORDS` — stand, plinth, mount,
  pot... The bench called the stands its owl, astronaut and Falcon Heavy were
  asked for yards, and the crane's chassis (18% open) and the bonsai's pot (0%)
  for being wider than a boom and a trunk half way up). `patterns_probe`
  (`_display_faults`): a black wall sprinkled with grey is called speckle, two
  walls half a stud apart with nothing behind are called sky, the guidance's
  tower on a 66-stud yard is told its base is too wide, and the guidance's
  tower itself, closed or opened at the back, is called none of them.
- `an open tower is not see-through`: a post up the inside of each corner where
  two laid faces meet (`Assistant._corner_posts`, `_corner_post`), a column of
  3062b — or 3941 where the channel's mouth is wider than one covers (radius 9
  loses most of a stud to whole studs) — in whichever face of the corner is
  turned off the grid (a square face's post would be judged on its studs), as
  near the mouth as it is `CLUSTER_CLEAR` from both faces (nearer its own, the
  clutch check read a 2 x 2 as standing across that face's studs), and only if it
  meets every sightline through the channel from either face's look and 15
  degrees past it, found by projecting both faces' bricks every 5 degrees. Where
  none fits square to either face, it is turned half way between them (or 5 or
  10 degrees off half way, where half way is square to the grid) in a section
  of its own, `prism N corner K`, where it stands symmetric to both and nearer
  the mouth: square to one face it had to clear the other, which on a
  ten-sided core put every candidate too far behind the mouth (run 17: no post
  fitted any of its corners). On an open or odd-sided prism, on a cluster's
  core, and on any corner whose outside row cannot run on into its groove — a
  decagon's or a twelve-sided prism's, which were open straight through along
  their corners even closed (54 and 172 sightlines). And on the corners of a
  pier at the back of an open cluster, which is a frame of its outward faces
  open behind, so a groove between two of them looked straight through it:
  the guidance's own cluster showed the sky up its right cleft from the
  front-right corner. And on any other pier's corners by the closed prism's
  rule (where its outside row cannot run on, or it has an odd number of
  sides): run 18's ten-sided piers of radius 6, faces two studs wide, had two
  grooves of each front pier in line, the sky up both front clefts from the
  corner. Pier posts go half way between first (`between_first`): a
  pier's face is narrow, a post square to it stood right behind its inside
  row, and the check read it as resting on that row, off its studs. Found by run 16: a
  face's floored width leaves its inner corner 2.4 LDU short of its neighbour's,
  narrower than a lattice cell so the check never saw it, and the open back put
  the sky behind it — a white slit up the core's front, seen through at six
  heights of nine from the front. Measured with `src/dev/daylight_probe.gd` (each part's box in plan,
  horizontal sightlines at nine heights from eight headings; also runs on a
  saved model). `patterns_probe` ("an open tower is not see-through"): octagons
  of radius 7 and 9 open at the back, no sightline from anywhere (18 and 9 per
  heading without posts); the guidance's open cluster, none from the front,
  back, sides or the 45 and 225 corners (9 each from front and back without
  the core's posts, 9 of 12 LDU from each corner without the back piers'), its
  core three faces open; closed, none; ten- and
  twelve-sided prisms of radius 9, closed and open, none (54, 172 and 176
  before); run 17's own cluster (a ten-sided core, eight-sided piers turned 45),
  none from the front, back, sides or the 45/225 diagonals, three of its ten
  faces open (five before, and 9 sightlines each from 45, 90, 225 and 270, the
  2.5-stud gap from its front-right corner); run 18's (ten-sided core and
  piers), none from the front, back, sides or 45/225 (9 each from 45 and 225
  before its front piers were posted). Still open, and printed rather
  than judged: a cluster has a corridor a clearance wide along the core's
  outside under each pier (a pier's faces keep `CLUSTER_CLEAR` from the core),
  seen through only straight along that core face — 9-18 sightlines from the
  diagonals, open or closed (on the guidance's open cluster, a 12.5 LDU slit
  from 135 and 315 between a back pier and the core's open edge, 15 LDU on run
  18's); a front pier whose outside rows do run on is not posted, and two of
  its grooves can still line up (run 17's eight-sided piers: a 1.4 LDU slit
  from 135 and 315); an open hexagon's channel is wider
  than a post can cover, and so is any one stud thick.
- `faceted piers clustered round a core`: `"piers"` on `prism`
  (`Assistant._cluster`), the guidance's one line for a tower like Orthanc —
  `{"count": 4, "courses": 38}` on an 8-sided core of radius 9 and 30 courses.
  Each pier is a prism of its own (`prism N pier K face J`), `sides` the core's,
  `radius` two thirds of it and never less than keeps two-stud faces at its
  sides (`_least_radius`; asked smaller, it is laid at that and the check's
  advice says so — refused, runs 15 and 16 both asked radius 4 at eight sides,
  were told "or their sides fewer" and took six, which leave the sky beside
  every cleft; a core too small is told the radius that would do), and far
  enough out that where two of their faces meet the bricks clear
  (`_clear_radius`, the same rule a prism's own faces are laid by: a fifth of
  a stud where both faces are turned off the grid, a twentieth where one is —
  piers of 4.5 on a core of 7 had a twenty-eighth and their horns ran into
  themselves; a twelve-sided prism of radius 8 had a tenth), centred
  `out` (radius + pier radius - thickness)
  along `turn` + 360k/count (180/count, so a cleft is front and back). The core
  is whole; each pier is built against it, its faces stopping `CLUSTER_CLEAR`
  (0.15 stud, 3 LDU: more than a 2 LDU cell's diagonal, which is all a turned
  part's cover reaches) short of the core's outside and of the next pier round
  (`_runs`/`_free` clip each face's wall by outlines in plan; a run ending at
  something is laid flush to it on the 0.1-stud grid). The core is capped at
  `y + 3 x courses` with a two-plate summit over the whole outline
  (`_summit`: strips along z, strips along x across them laid from the left in
  the longest plate whose end is not over a joint of the first layer
  (`_summit_across`), only the largest connected piece kept: with both layers
  breaking round the same 6 x 6 block, run 18's summit lost its middle, where
  its figures were to stand, and the run laid a plate over the hole by hand;
  `patterns_probe`: 532 of that summit's 544 studs, the middle covered, 468
  before), which is what makes it one piece — walls at different
  angles only rest on one another — and piers taller than the core rise from
  it into horns: blades by default (`horns as blades`, below), or with
  `"horns": "spire"` as whole prisms with a crown. A cluster face's outer row runs on past its
  right-hand corner into the groove (`_cluster_face`, as far as the outline's
  corner): without it a two-thick pier face three studs wide had a groove
  nearly as wide at each corner and the piers read as bundles of sticks.
  With `open`, a pier at the back keeps every face and gives way only to the
  core's faces that stand (`standing`, each face's wall slab) and to the
  core's inside, so it stands closed in the corner the opening took out and is
  posted as a closed pier: left a frame, open behind and to the opening, the
  sky came up the seam where it met the core's last face and up its own front
  grooves, from the corner a picture is taken from (the guidance's tower
  opened: 6 sightlines from 45 and 225, now none from any corner, and from the
  sides a 1.4 LDU hairline); given way to the standing faces alone, it closed
  the core's inside off from behind too, and the rooms could not be seen.
  Closed, the back piers stand in front of the inside's outer columns, so
  from straight behind the rooms show through the slot between them, the
  middle four of the guidance tower's ten (`_cluster_opened`). Piers not
  told their `out` are set into the core by its wall's thickness, or the
  nearest half stud to that, deeper first, at which no pier face is left a
  hole by the core, part of it standing clear but too little for a brick (`_pier_out`,
  `PIER_HOLE` 0.3): a core of radius 8 (the run after these rules) took two
  faces of each pier down to 0.9 of a stud and laid nothing there, and the
  sky showed a stud wide straight through every pier, full height, from every
  corner; `patterns_probe` (`_display_faults`): that cluster, no slit of a
  tenth of a stud or more from any of the eight views (18 a corner before).
  Any `open` at all opens the core's whole back, every face
  looking within `OPEN_REACH` (67.5 degrees) of straight back (3 of an octagon
  or a decagon, 5 of a twelve-sided core), one more where the count would sit
  off centre: run 15 asked for 2 and got one face and one pier, the rooms
  behind a slot between two piers. Counted as every face looking backwards at
  all, run 17's ten-sided core opened five of ten, its sides with them, and its
  front piers' hollows opened onto the core's inside. A spire ends square: a cap two plates
  thick over its outline at `y + 3 x piers' courses + 2` (`_studs_within`,
  `_summit`, never a stud claimed by two caps), and on it a crown
  (`_horn_crown`): rings of bricks two courses tall (`HORN_RING`), each two
  studs in from the last towards the cap's outermost 2 x 2 (along the horn's
  way out rounded to an eighth of a turn, and across it where that is an
  axis), tiled as the rock tiles its courses (`Patterns._tile`) and their
  ledges faced inwards with 60481a 65-degree slopes, or a cheese slope where
  a ledge is one stud (`Patterns._face_steps`, the rock's own facing pulled
  out of `_rock` unchanged); on the tip a 3688 pyramid, a 59900 cone on its
  stud and a 30374 bar. The four open outwards round the platform, "gaping
  horns, their pinnacles sharp as the points of spears": run 17's horns were
  flat caps with a point stood in the middle of each and read from the front
  as turrets with roofs, and its close pass on "horns and summit" was never
  made, so the pattern carries what that pass would have. One course a ring
  was 31 degrees, a roof; two is 65. Run 15 took its generated horns down
  because their tops were turned 45 degrees and nothing square sat on them. Sideways dressing is laid only where it is clear of the other
  shafts and the faces beside it (`_dressing_clear`), so nothing gives way in
  the check. Found by run 14: four piers round a core rising into horns, built
  square by hand, 0% at an angle. `patterns_probe`: the guidance's cluster
  passes the check as laid, in one piece, faces at 4 angles off the grid, 40%
  angled (fantasy median 27%), open at the back, its blades as below; asked
  for spires, each horn capped square (no
  cap plate turned) with a crown on it, 129 65-degree slopes looking in and
  each tip out past its horn's middle, 35 plates over the cap; flat, caps and
  nothing on them; any other kind refused naming the three; and add_rooms lays and
  furnishes five floors under the summit, open to -z, nothing taken out;
  restyle_model then reaches the faces (below); piers set clear of the core
  are refused; and run 15's own cluster with `"open": 2` has no core face
  looking back and every column across the core's inside is open from behind
  to its middle (7 of 10 before). Its core's corners are posted (`an open tower
  is not see-through`, below the many-sided shaft). A great door stands at the
  foot of the core's front face (the one looking +z), at `y`, unless
  `"door": false` (`_door_for`, `_lay_door_course`): a 6182 arch in the outside
  row `DOOR_BELOW` (4) courses up, the two studs under it open, and the inside
  row behind the opening laid as the door in reddish-brown 30136 log bricks —
  set back a stud, and never a window onto the open back. It goes in the
  stretch of the face the piers leave in view, as near its middle as the face's
  brick grid allows, and the check's advice says so when there is none (fewer
  than two studs in view, or faces narrower than four). A plain prism takes one
  only with `"door": true`. Both rows are one-wide through the door's courses
  and the course over the arch ties them; the windows on that face start a
  storey over it. Found by run 17, whose stair led to a blank wall. Each foot
  of the arch carries two studs' worth of the wall over it: where the face
  leaves a jamb one stud wide, the course under the foot is a 1 x 2 laid
  across both rows, not a 1 x 1 in each (the Wizard's Tower's eight weak
  joints were its two jambs, 1 x 1s carrying 83-85 g on studs that hold 80).
  `patterns_probe`: the guidance's cluster has the arch in `face 0` at y 12
  over six courses of door, none with `"door": false`, and run 17's own
  cluster (piers pulled in to 10, two studs of the core's front in view) has
  it at x -2 and passes the check; on both, the brick under each foot of the
  arch is two studs or more, across both rows where the jamb is one stud.
- `a tower on a plinth`: `"plinth": {"steps", "out", "stair", "rock"}` on `prism`
  (`Assistant._on_plinth`, `_foot`, `_plinth_crags`), the base as a call: every
  Orthanc built here stood on rubble and the owner named it. With `rock` (the
  default), crags (`Patterns._rock`, in the plinth's colour with its ledge
  tone) rise against the tower on the top terrace at each corner and the
  middle of each side but the front, each the largest square of three studs or
  more at the terrace's edge clear of the foot by a fifth of a stud, twice its width
  tall (4 to 10 courses), on studs left for it: within the plinth, so the base
  is no wider (the run after the blades stood on a pale 66-stud yard with five
  rock piles). Square terraces `steps` (1-4)
  of two courses each, stepping out `out` studs, the top one two studs clear
  of the tower's farthest corner (`_foot`: the core's and the lowest storey's
  piers' outlines), laid by the shape pattern as boxes, so every edge is
  straight (laid round, they were a circle stepped a stud at a time and read
  as a staircase from above). Their tops are tiles in the second tone up to
  the tower's faces, with studs (`studs_at`) on every stud the foot reaches
  over at all (by the stud's middle alone, turned faces stood their end bricks
  on tiles); hollow inside under a cap four plates thick (a three-plate cap
  was one brick course, held by nothing in the shape, and pruned: the tower
  stood in a pit). The stair is cut into the front (+z), four wide, two plates
  a step from a four-plate kerb (a two-plate bottom step was plates beside the
  terraces' bricks, a piece of its own), treads tiled in the second tone, up
  to the top terrace at the door's level. `patterns_probe`: the guidance's
  cluster on a plinth passes the check in one piece with its foot at y 12,
  terrace parts and stair treads, and the reply says where its foot is. The
  shape pattern's mirror strip takes its parity with `posmod` — a plinth
  centred on its `at` has studs either side of nought, and `-1 % 2` is `-1`,
  which laid a three-wide strip off the plane and overlapped itself.
- `horns as blades`: `"horns": "blade"` on `prism`'s piers, the default
  (`Assistant._horn_blade`, `_blade_edges`, `_blade_wedges`, `_blade_side`,
  `_by_its_body`), as LEGO's 10237 builds Orthanc's: the owner's verdict on the
  homepage tower was "the ugliest piece of shit I've ever seen", and its horns
  were square spires that read from the corner as turrets with roofs. A pier
  taller than the core stops at the summit, and over it stands a blade in a
  section of its own (`prism N horn K`) turned about the upright into the plane
  through the tower's middle and its pier, so it sweeps out from the crown,
  then `BLADE_TURN` (20 degrees) off it towards the side (a pier on the line
  from front to back stays on its line): turned to face the front instead,
  the four were two straight sticks from the side and cut-off plates from the
  corner; on their piers' diagonals exactly, the two on the corner view's line
  were edge on, a mast behind the summit. Four layers of plates laid on their side (face +x,
  `Patterns._tile`, each turned across the joints of the one under it), tiles
  over the last (`Shapes.TOPS`): two studs deep, centred on its pier's line
  (two layers and tiles were 24 LDU, and the blades seen edge on read as one
  sheet standing out of the middle of the summit). Its foot row is pressed
  onto bricks with side studs (30414, 11211, 87087) standing on the summit,
  where `_blade_side` measures their studs off the parts. Its outline (`_blade_edges`): a centre line sweeping
  out by `flare` (half its width) a little over half way up and part of the
  way back, a width narrowing to nothing, each edge moving a stud at a time and
  at most every other row; past its height the edges close until they meet, so
  it ends in a point (stopped at its height, a blade three studs wide had a flat
  top and read as a slab; with its outer edge bowing on its own and its inner
  held still, the blades read as a hare's ears). At each step a two-stud wedge
  plate (24299/24307, 43722a/43723a, 41769a/41770a, `_blade_wedges`), studs in
  the last column inside and its cut filling the column outside, full at the
  step, so the edge runs on the diagonal; which way a wedge's cut runs is read
  off its body (`Builder._cells_for`), never its studs, which are the same
  either way up (matched by its studs, the first blades' wedges stood out like
  a saw's teeth). A wedge is seated by its body (`_by_its_body`): on its side
  its cover is pulled in a cell at the cut end, and the 2 x 2's body is two LDU
  short of two studs, so placed by either the blades had a slit of sky up their
  inner edge, one a wedge. The 2 x 4 right hand (41769a/b) draws its cut face
  nearly white on its side, a pale flag up a blade: its body is its left
  twin's subpart mirrored, and the renderer is being fixed at the root for
  that, so the blades use it as LEGO would. Its foot is the pier's radius by `BLADE_WIDE` (1.2,
  4 to 10 studs); it rises `BLADE_TALL` (2.6) times that, or the piers'
  courses past the core's if more; one whose studs would look away from the
  front is built the other way round (turned half a turn, its edges taken from
  the other side), so its tiled face is the one seen. The reply says each
  blade's size and its tip's y. `"horns": "spire"` is the crown below, `"flat"`
  a turret's cap; any other kind is refused naming the three. `patterns_probe`
  (`_check_blades`): the guidance's cluster has four blades, every part on its
  side, wedges in both layers, each anchored, 18 studs tall from a 6-wide foot,
  sweeping 3 out past it and back in, to a point two studs across, two studs
  deep (24 LDU before); the probe's
  restyle and open-back counts leave the horn sections out, as built whole on
  their side, and without the seating by body the slit check fails (0 of 4).
  Looked at: `shots/runs/blades_{corner,front,right,close}.png` in its
  worktree, the guidance's tower: crescents from the front and the side, and
  from the corner two crescents and two solid edges round an open summit.
- `display proportions`: a prism with piers (`Assistant._at_display_proportions`,
  `_display_width`, `_display_height`, `DISPLAY_TALL`), once at the top of the
  call (not for its plinth's tower, `_raised`, or a storey). Not given
  `courses`, it is laid in as many as make it 3.3 times as tall as its widest
  (its plinth's width, else its foot's), plinth, summits and horns included —
  LEGO's 10237 is 21 cm across and 73 cm tall — and the reply says how many.
  Given courses more than a fifth off that, they are laid as given and the reply
  says the ratio and the courses that would do. The homepage's Orthanc stood
  2.1 times its 49-stud base and the next 2.6 on a 41-stud plate of rubble: thin
  towers on wide bases. The guidance's tower leaves `courses` out (radius 7,
  storeys of 1, a plinth of 2 by 2) and is closed all round: opened at the back,
  from the corner the sky showed up the clefts beside the back piers and the
  shaft read as four thin columns, where 10237's reads as one mass of rock,
  until the back piers stayed closed. `patterns_probe` (`_display_proportions`):
  that tower, measured by its parts' boxes, stands 3.3 times its 34 studs in one
  piece and the reply gives its 73 courses; a lone cluster of radius 9 the same;
  the old guidance's 36 courses on a core of 10 are laid as given (1.65) and the
  reply says to go taller.
- `a tower in storeys`: `"storeys": {"count", "in"}` on `prism`
  (`Assistant._storeys`), the one call for a silhouette: every Orthanc built
  here rose the same width from foot to horns, and the owner's verdict named it.
  The courses split into `count` storeys (the remainder to the lowest), each
  the prism again with its core `in` whole studs smaller than the one below and
  its piers the same size drawn in with it (`out` recomputed) — piers shrunk
  with the core reached the least radius, and an octagonal core of 7 with piers
  of 4.5 overlaps itself in six pieces, with or without storeys (a fault of the
  cluster at that size, not fixed here). Each storey's sections are named for
  it (`prism N storey S face J`), since a face's section turns from its own foot.
  Every storey but the top is capped with a ledge (`_ledge`): two plates in the
  second tone (`band_color`, else `SECOND_TONE`, else the prism's colour) over
  its outline less the studs wholly inside `r - in - thickness - 1.5` — a ring,
  so the rooms are not floored over, reaching under the next storey's wall and
  the posts behind its corners. `_summit` keeps every piece of a ledge over
  `LEDGE_CRUMBS` (6) plates: a ring crossing a cleft on the diagonal comes in
  pieces, and keeping only the largest left a whole pier of the storey above
  on nothing. Only the top storey's piers rise into horns; its summit is in the
  second tone too, and the faces take no bands (the ledges are the bands). The
  reply says the top's radius (for add_rooms) and its summit's y. A top storey
  with faces under two studs is refused with the radius that would do.
  `patterns_probe`: a 45-course octagon of radius 7 is told it is a straight
  shaft and in three storeys is not, passes the check in one piece, grey only
  on its two ledges (y 45 and 92, two plates each), its outsides 8, 7 and 6;
  five storeys at that radius are refused; the guidance's cluster in storeys
  passes in one piece with horns on its top storey only and one door, at the
  foot of the lowest (every storey laid its own, and the ones above opened onto
  nothing half way up the tower), and add_rooms at the top radius
  furnishes four floors with nothing taken out (a column of the floor above
  stood on a piece of floor `Rooms._hold` took out as held by nothing; it is
  now laid again from whatever is under it). Looked at: `shots/runs/rk_storeys_corner.png` steps in
  on grey ledges as 10237 does.
- `a finishing pass`: `restyle_model` (`Assistant._restyle`, run through
  `edit_model` so it is checked like any edit). Plain one-wide bricks (1x1-1x4,
  studs up) whose long face is open — the live lattice empty 2 and 7 LDU out
  along the whole face at two heights (`_open_side`; both open means the side
  away from the model's middle) — and the outer rows of two-wide ones (2x2-2x4,
  `TWO_WIDE`; both rows when both faces are open, a wall standing on its own)
  are gathered into walls (`_wall_of`: one face's outer row, by section, the way
  it looks and its depth), and each wall is laid again as one structure in its
  own colour (`_dress_wall`), never a part at a time. `style` is one of
  `DRESS_STYLES`: `ribs` (a 87087 carrying a `RIB_PART` round plate in each
  course of one-wide bricks of each rib column — the wall's own columns of side
  studs that stand in `RIB_KEEP` (half) of those courses, or every `RIB_EVERY`
  from its middle, moved a stud or two where that puts each rib inside the
  two-wide bricks of every course it skips: on their joints the first wall in
  ribs came apart in four), `bands` (a course of texture every `BAND_STEP` (4),
  in `face_color` if given), `panels` (ribs, and texture over the rest but its
  first and last course, its ledges in another colour, the course of two-wide
  bricks beside each ledge or, with none, every fourth such course — whole
  courses the panel's strips hang from, which tie a two-thick face to its back
  row: with every one split the first wall laid in panels came apart in
  thirteen — and a plain stud at each end of a wall `PANEL_MARGIN_FROM` (8)
  studs wide), `grid` (ribs and bands) and `courses` (a course of 1 x 1 round
  bricks every `RECESS_EVERY` (4), a shadow line). A rib stands only in courses
  of one-wide bricks, never splitting a two-wide one. Texture
  (`DRESS_TEXTURES`): grille 2877 by default with headlight bricks 4070 for an
  odd stud, or masonry, logs (planking), round bricks or headlight bricks; laid
  across the joints of the bricks it replaces, pairs from the left and a single
  at the right every course alike, faced out by `TEXTURE_FACES`: bonded, the
  single moved end to end and the grille, which catches the light where black
  does not, zigzagged up the face. A brick is split only where every stud is
  held (`_each_stud_held`). A side stud already in the wall that stands in no
  rib is regrouped with what it carries, as its column and course say; a row
  of nothing but side studs and texture is a wall for that too. A dark wall
  told no style gets panels; a light one keeps the old scatter
  (`_scatter_one`): a `sideways` share (0.15) as 87087s dressed by `_dress`,
  and a `masonry` share (0.25) as 98283/15533 facing out (this path still splits
  a free two-wide brick into rows untied, and on the pirate ship below left one
  masonry brick and the brick on it a piece of their own). Found by the sixth
  Orthanc: 978 plain 1x2s, 0% sideways; restyled it went 0% to 10% sideways.
  Run 4 of the Orthanc, the landing page's, took the old dark-wall pass with a
  grey accent and came out 58% plain black: it turned out only the bricks that
  happened to start on a column, each carrying its own tile, broken columns over
  plain black. Run 5 called `restyle_model {"style": "panels", "face_color": 72}`
  by name: 31 walls, 3,284 studs of grille. It reaches bricks in sections
  turned about y, in the section's own coordinates (`_open_side` and
  `_each_stud_held` take the section's frame; only a side within 60 degrees of
  straight out from the section's origin counts, so a face's inner row, open
  onto the hollow shaft, and a course's end, open onto the corner groove, are
  left; in a section found for a file (below) the origin is the middle of what
  stands, so there a side counts that does not look back towards it and is open
  24 LDU out, past a groove). `mcp_probe` lays a bonded black 1x4 wall in
  panels of grille between ribs. `patterns_probe`: on the guidance's cluster
  300+ more grille bricks in panels, 50+ two-wide bricks split, nothing dressed
  facing anywhere but out, the windows left, the whole still passing, not
  speckle, and the grey asked for adds no grey to the faces (the tower's own
  ribs stand). `dress_probe` (below).
- `dressing laid as one structure`: `src/dev/dress_probe.gd`. A black wall
  restyled unasked is panels, over half its face grille, a rib in every course
  of one-wide bricks between its whole courses, a round plate on each rib stud,
  one piece, not called a hole or speckle; ribs, bands, grid and courses each
  hold in one piece and are not speckle; a style it has not got is said so;
  28 grey tiles laid one at a time over a black wall by `edit_model` are
  refused, told the call (`_sprinkled`: `SPRINKLED_FROM` (6) of an edit's own
  marks scattered, 40% of them, or any once the whole would be speckle; not
  for `restyle_model` or `add_rooms`, which lay whole structures,
  `_laying_whole`), and the same tiles in two columns are laid; the guidance's
  tower written to a file and opened again reads its turned faces in sections,
  holds in one piece and is told of no speckle or sky; and the landing page's
  Orthanc, read from its file, is not speckle, and dressed again is no
  plainer, no more scattered, in no more pieces, and stands up (underpinned
  where it would not). With run 4 on the page that was 99 of 1,078 marks
  scattered, 58% to 46% plain black and its weak joint underpinned; run 5,
  dressed by its own run, is left as it is. On the code before this, 18 of its
  checks failed, among them run 4 opened at 232 pieces.
  `src/dev/redress.gd -- IN.ldr OUT.ldr ['{...}']` does the same to any saved
  model (or a design's JSON), says before and after, underpins (below) and
  writes the result.
- `a file's turned faces`: `Assistant._adopted`, from `_model_from_world`. A
  model opened from a file keeps where each brick is, not the section it was
  laid in; read back at the nearest square turn and cell, a prism's faces were
  checked and dressed where they are not. Bricks turned the same way about the
  upright whose origins share one 2 LDU lattice are one section ("turned 45"),
  its origin the lattice point nearest the middle of what stands. A square
  brick stays in the main body, read at the cell it rounds to, at most an LDU
  off: given a section of its own when it sat off the lattice, a pane seated
  half a stud into its frame came back in that section's coordinates and
  `joints_probe`, which copies placements without their sections, stood it
  across the frame. Minifigure parts are left (they nest and stand on no
  grid). Kept in `_adoptions` until the world is cleared. The joint rules hold
  inside such a section: `joints_probe` reads a frame and its pane turned 30
  degrees, and a turntable's top turned 30 on its base, from a file with their
  sections kept, and passes them (and refuses the pane not turned into its
  groove). The landing page's Orthanc opened: no sky through slits it was
  told of before, one piece where the old reading made 232. Bricks tipped the
  same way about a flat axis (x or z) are sections too ("tipped 10 about z"):
  read square, the bench's starfighter, its wings opened ten degrees on hinges,
  was ten pieces and its crane, boom raised, sixteen, each one piece as built
  (now 1 and 1, with their figures apart); 10240's X-wing 31 pieces, now 2.
  Such a section that nothing has added to or moved is not told it leans on
  nothing, and two bricks standing in one are not an overlap, as outside one
  (`_between_standing`). `joints_probe` ("tipped on a hinge and read from a
  file"): four real sets' hinged sub-models (10179, 6285, 75144, 21307), each
  refused before, pass in one piece.
- `a piece standing apart`: `Assistant._standing_apart`, in `_check`. The
  held-out sports car (`car_r1`) finished in two pieces and said every check
  passed: a nameplate (a 41539 plate, a 4515 slope and printed tiles) the run
  meant — "a nameplate plaque in front of the car" — lay on the ground in
  front of it, joined to nothing, and a piece apart was only a remark. Now a
  piece that stands apart from the model — touching nothing of it within half
  a stud and a plate (`_touching`, `NEAR`), its plan outside the plan of the
  rest (`_outside`), fewer than a tenth of the model's parts (`SCENE`) — is a
  fault, `loose`, unless it is named: every part of it in assemblies that
  hold none of the model (a design's `assemblies` box, the smallest that holds
  the part's corner, `_assembly_at`; or a file's sub-model: `Placement.group`),
  or a whole figure. A whole figure of the design's is an item wherever it
  stands, against the model or inside its plan too (`_our_figure`, its parts
  known by the library's names: the bench's starfighter pilot wore a baby's
  head, 24581p01), counted in `figures`; `candidate_probe` says "2 pieces, a
  figure apart". A design's piece against the model (touching it, or
  touching what does) that nothing joins is said with where it is and what
  it is made of (`_unjoined_said`, the first four) and how to join it — a
  plate or brick across the joint, a layer whose joints land across the
  joints below — where it was only counted. It is not a fault: made one,
  15 of `patterns_probe`'s models (round towers, octagonal shafts, turrets,
  domes, cones, rock), 5 of `rooms_probe`'s shells, 6 worked techniques,
  `dress_probe`'s wall and `rules_probe`'s one-layer wall failed — the
  patterns lay pieces that touch (a prism's faces against its core), and
  they are to be joined first. The verdict carries `each_piece`. Pieces of
  a size with the model standing apart (a scene), pieces of the person's
  own and pieces held by nothing (said as floating) are said as before.
  `edit_probe`: a stack of 11 plates against a tower of 100 is said where
  it is; a plate across the joint makes it one piece. `edit_model` takes `assemblies` to
  name one (one of the same name moves to the new box), the in-app loop tags
  its assemblies on the bricks as it ends and a session's on saving
  (`_tag_assemblies`, from `CommandSocket` `save_model`; one assembly only
  where something stands outside it), so the stand is a sub-model of the file
  and the person sees it as an item. `edit_probe` ("a design in two halves"):
  unnamed, refused as loose; named in a box of its own, an item; named in a
  box that holds the model too, still loose; a file's sub-model names it; the
  person's own piece is left alone; a box inside a bigger one named first is
  the smaller's. `candidate_probe` on `car_r1.ldr` fails it (loose 1); the
  same file with the plaque in a sub-model passes ("apart as named:
  Nameplate"). Found again by the held-out rerun (`car_r2`): it named its
  nameplate and was told twice it was loose, because the bonnet's box, named
  first, ran on past the bumper and the first box holding a corner won; and
  the driver it stood on the nameplate made the piece two assemblies. The
  smallest box now wins, here and in tagging, and a piece in several
  assemblies none of the model's is named; the saved file passes
  `candidate_probe` ("apart as named: nameplate, racing driver").
- `standing up, for the landing page`: `src/dev/candidate_probe.gd -- MODEL.ldr
  [ON_THE_PAGE.ldr]`. A candidate opens whole, is buildable in one piece (or
  with items named to stand apart, judged as a design),
  stands up as the status bar reckons it (`Stability`), and the check says none
  of a picture's faults of it (hole, speckle, office block, straight shaft, sky,
  yard) that the model on the page (`models/orthanc.ldr` unless said) does not
  have; exits 1 otherwise. One the page's model has too is said as a pass
  ("ok    not counted: called sky through a slit, as orthanc.ldr on the page
  is"): said as "still ...", the bench's judge read it as a fault named and took
  two points of buildability from four runs the probe had passed. Run 4 on the page fails it: "1 weak joint
  (overloaded)", the foot of its core's face in each cleft between the piers
  hanging over a hole in the plinth, touching a ledge tile at one edge cell, so
  88 g of face rested on a tile corner that holds 80. `redress.gd`'s `underpin`
  gives each brick a weak joint carries, over a void, a column of 1 x 1 bricks
  and plates in every stud it covers down to what is below; run 4 re-dressed
  and run 5 so made pass. `style_probe` holds every shipped model to standing
  up but those known not to (`weak_known`: `orthanc.ldr`, run 4) and fails when
  either list changes, so a weak homepage model is caught and a sound one
  replacing it must clear the list.
- `a resubmit keeps its numbers`: `_apply` matches each placement to a brick
  already standing from the last submit or sketch by part, colour and transform
  (`_same_key`, to a hundredth of an LDU) and keeps it under its number; only
  what changed comes down or goes up. A session that read the numbers, resubmitted
  and then edited by them was editing other bricks (the eleventh Orthanc), and
  every resubmit wrote the whole model into the timeline's History twice.
  `mcp_probe`: a 300-brick wall resubmitted with one brick recoloured keeps the
  other numbers and adds 2 history events; before, 600.
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
- `rooms inside`: `add_rooms` (`src/ai/rooms.gd`, run through `edit_model` by
  `Assistant._rooms`), a tool and not a pattern because it works on what stands:
  the variety advice that names it arrives after the build, when a design is
  told never to submit again, and the two calls made on what stands
  (`restyle_model`, `add_minifig`) are the two the runs took up. Given `where`
  (the building's box) or `prism` (the prism's own at, sides, radius) and
  `floors` bottom up (a kind each: `Rooms.KINDS`, words mapped by `kind_of`, so
  "Saruman's chamber" is a study), it reads the inside off the live lattice —
  inside the prism's inner faces, or walled on two opposite sides in the box —
  stacks floors 26 plates apart (fitted to the shell: to a prism's roof where
  most of its inside is covered, so a cluster's floors stop under its summit
  rather than the fifth landing on it between the horns) unless `y` is said, and
  lays each as two layers: 2/1-wide plates along z, each strip one plate, and
  over them a layer along x — tiles (boards, flags or a checker, by kind) where
  it is walked on, plates where something stands, joints a stud off the
  strips', a 1 x 2 stitched across any joint left untied — held up on two or
  three columns in the corners of the room below (never on its furniture); a
  piece of floor held by nothing is taken out with what is on it, and a column
  of the floor above that stood on it is laid again from whatever is under it
  now (`_hold`). Furniture stands on top, only where plates are. `stair: true` is a straight
  flight of 2 x 2 bricks where it fits, else a ladder (4175 every six plates) up
  a 1 x 2 pillar. Each room gets its kind's furniture, signature first: the
  worked examples (`Techniques`) and a few of castle parts (`Rooms.FURNITURE`),
  turned as transforms to stand back to a wall and face in, coloured by a seed
  in colours the parts were made in. Every part is tried against the live
  lattice and what it has laid, so the shell is never touched; the whole is
  checked before the edit, and anything floating would be taken out (the probe
  holds every room to none). Found by twelve Orthancs that were solid shells,
  46 shapes and 6 colours against a set's 109 and 23. `rooms_probe`: every
  piece holds every way round and every tone is a colour it was made in; an
  octagonal prism open at the back takes a dungeon, a forge with a ladder up, a
  library and a study, passes the check as laid, shell untouched, 5 to 56
  shapes and 2 to 23 colours; two libraries in a box differ; every other kind
  gets its signature piece. With a window it leaves `shots/rooms/` (tower from
  the back, each floor). `Assistant._ensure_parts` loads a part from disk before
  fetching it: on the desktop it fetched over HTTP, failed, and waited 20 s.
- `people in it`: `add_minifig` stands a figure made of real parts on whatever is
  under its feet; declared and passed through here, made in
  `src/minifig/figure_tool.gd`. See [minifig](minifig.md). `_variety` counts a
  model without its figures' bodies, as real sets' inventories are counted, and
  `_tag_assemblies` leaves a figure in its own group.
- `parts it needs`: `make_part` makes a part LEGO has not made — a family at
  any size, or a real part changed — when no real part will do, as a person
  does in Make a part; declared and passed through here, made in
  `src/parts/part_tool.gd`. See [elements](elements.md).
- `walls partly on their side`: `fill`'s `sideways` share (`Patterns._sideways`,
  before the masonry, which would otherwise take every 1x2): one-wide bricks of
  a course (1x1 to 1x4) laid as rows of 87087 marked `dress` with the way out,
  turned and dressed by `Assistant._dress` in `_read_model` with the same side
  stud measurement as `studs_out` (`_side_stud`, cached per facing). In the
  guidance's stone-wall recipe at 0.15, because designs copy the recipes: the
  fourth Orthanc had `studs_out` and used none of it. `patterns_probe`: a stone
  wall with `sideways` 0.3 holds and every turned brick is dressed.
- `a body of revolution`: the `round` pattern (`src/ai/rounds.gd`, class
  `Rounds`, dispatched from `Patterns.expand`). Anything round in section —
  a column, a rocket stage, a lighthouse, a silo, a boiler, a fuselage, a tree
  trunk — said as a diameter (1, 2, 4, 6, 8: the sizes round parts come in)
  and a `stack` up its axis: `{"plates": N}` lengths of body (a `color` band,
  a new `diameter`, `"spokes"` reaching a stud out with a `tile` on each),
  `{"cones": 9|1}` cones under a round plate, `{"technic": true, "struts": n}`
  a course with a 3700 pin hole out of each side and a Technic beam pinned on,
  and a `nose` (cone, ogive, dome, point, flat). Laid in the round parts real
  sets use at each diameter: 3062b, 3941; 87081 or 85941/24593 cylinder halves
  back to back; four 5152 or 48092 (30562 panels) corner rounds tied by a round
  plate every `TIE_EVERY` courses. `axis` x or z lays the same stack on its
  side (each part's transform turned about the axis's foot and named again,
  `_on_its_side`); `beside` stands 2 or 4 more round it, touching, a 2780
  across each joint where the Technic courses meet. A rocket's words
  (engines, legs, grid_fins, boosters) are taken as the general ones
  (`Rounds.SAID`). The corner-round and half turns are constants
  (`QUARTER_TURNS`, `HALF_TURNS`) because a browser lays a pattern before it
  fetches the parts; covers fall back to catalogue bounds for the same reason.
  Found by the owner's Falcon Heavy (4,252 parts of square columns, 67% plain,
  9% curved). `patterns_probe` ("a body of revolution"): every diameter holds
  in one piece of round parts only; four 48092 or 5152 round a ring are a
  ring at eight rim points (the old `wide round tower` example's turns built a
  bow tie, and fail this); the written turns match the parts; a Falcon Heavy
  in one call holds in one piece with 27 cones, 8 struts, 10 pins, spokes
  none into a body beside, no seam or slab advice, and is three pieces
  without its two joint pins; lying along x and z it holds, every part on its
  side, on the ground. The seam advice (`_unbonded_seam`) and the
  structure-not-detail advice (`_mostly_big_plates`) leave round parts
  (style kind `c`) out: a rocket was told to stagger its cylinder halves.
- `a body said as its solids`: the `shape` pattern (`src/ai/shapes.gd`, class
  `Shapes`, dispatched from `Patterns.expand`). A body that is not a box — a
  car's, a hull, a fuselage, a creature's — said as `solids` (`loft` through
  `sections` {at, width, height, bottom, round 0 box..1 ellipse, keel, offset};
  `extrude` of a side `profile`/`under` with top edges `round`ed; `revolve` of
  a profile about x, y or z; `box` with plan corners `round`ed or `chamfer`ed
  and top `edge`s rounded; `ellipsoid`; `dome`), each with its own `color`,
  less `cuts`, coloured by height with `bands`. Sampled at every stud and
  plate (`Plan`), a plate with nothing above, below or beside it dropped, then:
  the surface fitted (`surface`, `_fit`) — from the top of every fall down, the
  slope whose own profile is nearest the studs' heights (`SLOPES`: curved 4, 3
  and 2 long or 18/33/45 degrees, cheese for one stud; `INVERTED` under an
  overhang), standing on the shape's plates (never on a thin bridge's place),
  its high end flush with the stud above or up to two plates under, the plates
  it stands in carved out; each slope's own surface becomes the next one's top,
  so a ramp is a run of slopes; which end of each part is high read off its
  mesh (`Shapes.part`). Then the core plate by plate: bricks (`CORE_BRICKS`, up
  to 2 x 8) where a course is whole in one colour; where a plan edge runs off
  the square, edge parts (`Plan._wedged`): corner rounds first (30565, 30357,
  79491; bricks 2577, 5152, 3063b), then plates and bricks without a corner
  (2450, 26601, 30505), wing plates and wedge bricks — each placed where it
  brings the layer's outline nearest the shape, measured on a 4 x 4 grid in
  every stud of its box (`_gain`, `Shapes.edge_parts` read off each part's
  collision boxes, which are in lattice cells, not LDU), its cut side on a
  stud the edge cuts inside the plan or out of it, never across a stud whose
  edge runs square (`Shapes.square`: a ramp's falls cross studs half way),
  never cutting a column of studs through the middle (`_may_cut`); a brick
  course's rim studs a plate's edge part would follow better are left to the
  plates; an edge part where two pieces meet is laid again in plain parts so
  they can be stitched (`_unedge`); then plates (`CORE_PLATES`) laid stud by stud from the most hemmed-in, tiles
  on top unless `"top": "studs"` (`TOPS`), and every other course the outside
  row of a straight side (clear for two courses, its stud above part of the
  side) as bricks with side studs, 30414/11211/87087 in runs, marked `panel`
  so `Assistant._panel` turns each to face out and lays a tile two studs tall
  (87079/3068b/3069b) flat on its studs over the course above (`"panels":
  false` for plain sides). A shape that is its own mirror
  (`mirror_of`) is laid as one half, its reflection, and a strip across the
  plane two and four (or three and one) studs wide by turns so every layer is
  tied across it; surface picks pair into two-wide parts and are laid with
  their mirror or not at all; wedges find their twin by their plan at half a
  stud, not their studs (a 2 x 3 wing's other hand turned round has the same
  studs). Only parts joined to the foot by studs are kept (`prune`), and a
  piece standing apart is joined by laying two side-by-side parts again as
  one that reaches across (`stitch`, mirrored). The check's lopsided advice
  now samples only where a part is (`_lopsided`): a pair of wings, each the
  other's reflection, was called lopsided for the empty half of each box.
  Inverted 1 x 2 slopes (3665) run into the plate over them and are not used.
  A car on its own wheels (`"wheels": [x, ...]`, `Shapes._wheels`, 2026-10-13):
  every bench car that tried a shaped body gave it up — raised over nothing it
  floated (126-183 parts), and with wheels added as bricks its slopes ran into
  the tyres' boxes (a round arch cut leaves the box's corners), so it was built
  by hand, studs up. Each axle is the d5b car's proven unit — 18976c01 each
  side, a row of 32064a Technic bricks, an axle of the body's width less two
  (`AXLES`: 6, 8, 10 or 12 across) — with keep box cuts round each wheel's whole
  box and round the bricks, so the body over them stands on the bricks' studs
  from five plates up; a body too wide or raised off the bricks is refused
  saying so. `shapes_probe` ("a car on the shape's own wheels"): the guide's
  example lays 269 parts, one piece, buildable, four wheels; 11 across and a
  raised underside are refused with why.
  A shaped body comes back whole, or says why not (2026-10-14, the shapes
  round): the sessions' own car requests (the steps round's "the generator
  left the nose floating"), a curved car, a two-colour boiler, a hull with a
  black bow, a fighter's nose on its stands and a dog on legs all came back
  in pieces or floating. What changed in `Shapes`: the axles stand on a
  chassis of plates from nose to tail (`_chassis`), and the wheels sit on
  whole studs, said when moved; a foot off the ground (on wheels, or raised
  onto the design's own bricks, `Patterns` passes `_under`) is laid in plates
  and carries no slope where nothing is under it (`Plan.foot_on`); `stitch`
  keeps a way of joining only if it leaves fewer pieces, or as many and a
  bigger body (it used to re-lay the same pair 96 times; a sculpt's grid,
  `brickify_probe`, still stitches the old way), and its last ways lay the pieces' plates and
  bricks, the rest's beside them, then top tiles, then wedges, again as
  bonded plates (`_replate`), hidden plates taking the commonest colour so
  two colours face to face join; a slope's joins are read off its mesh
  (`Shapes.part`'s `grips` under, `tops` over: an inverted curved 4 x 1
  holds what stands on two of its studs, not four); a narrow strip on the
  mirror takes the other plate's strip width, not 1 x 1s; a side's shell
  stops above what hangs under it with no core behind (a leg); a part or
  three no way can hold is left off and said. What it cannot hold it says in
  the check's advice (`Shapes.said`): pieces apart with where and how to
  join them, a shape standing on nothing with what to build under it
  (`Patterns._over_nothing`). `shapes_probe` ("bodies as sessions said
  them"): each of those bodies one piece, nothing floating, the shape laid
  in one, standing (`Stability`), with shaped parts held at its ends; an
  owl raised at y 55, two engine pods said as one shape and a wheel at 15.5
  each said with the fix.
  Cabins, couplings and the studs a joint leaves (2026-10-14, the cabins
  round, after the shapes round's judge named "a boxy cabin with a flat roof
  and an upright windscreen", a tender coupled to nothing, studs on tops).
  A loft, extrude or revolve with `"screen"` (true: its steepest climb, carried
  along the whole climb, `_climb`; or `{"from", "to", "color", "part"}`) is laid
  by `Plan.screen`: of `Shapes.SCREENS` (92583, 4176, 3823, 57783, each read off
  its mesh by `screen_part`: across, along its rake, plates, its top studs and
  the studs its tubes grip), the one nearest the solid's rake, the roof's full
  height and its width, centred on the mirror, its top row where the roof is;
  its plates carved and taken, no slope fitted there (`screened`), the plates
  it grips studded (a plate or two laid under them where the shape is lower),
  and a roof of a plate and a tile over its top row on its top studs. Said in
  the reply only if it survives the joining (`_said` on the part); a side
  turned out that loses it is laid upright again; an odd width or a climb no
  screen fits is said with the numbers that fit. A shape that says no screen
  and whose raised solid climbs three plates within three studs is told how
  (`_screen_hints`). The guide's car example is a cabin said by its own
  profile with `"screen": true` (its cabin glazed, below). A vehicle's part on its
  own wheels, end to end with the model within `COUPLE_GAP` studs, its feet
  level and its side in line, coupled by nothing (`_uncoupled`, before the
  named-item rule: a named tender is still uncoupled) is said with where it
  is and `COUPLE_HOW`; the check reports `"uncoupled"`. A train's buffer beam
  with a sealed magnet (64422) is a magnet to `Joints.is_magnet`. A part
  whose cover hangs below its foot (a towball, a socket, buffers) stands on a
  shape's studs at its tubes' plate (`Patterns.foot_plate`), so the shape
  keeps studs under it. The surface pass tiles fewer than four open studs
  when a tile lies beside them at their height (`_set_in_tiles`): "a joint's
  studs in a tiled top". Techniques: "raked screen and falling roof",
  "towball hitch" (14417 and 14704, two studs apart on one grid), "magnet
  coupling" (two 64422 on 2 x 2 plates, seven studs between their middles).
  `cabins_probe`: the four screens read; the guide's car, the bench car's own
  loft said with a screen, a truck's cab and an aircraft's round fuselage
  each lay a windscreen in glass, said in the reply, one piece, a mirror,
  the car's roof falling in curved slopes; the bench car's flat loft with no
  screen is told to say one; an engine and a tender a stud apart are two
  pieces with the tender named uncoupled and the fix, a sign beside a car is
  not, and coupled by the towball pair or the magnet beams the two are one
  piece; the guide's car's six joints' studs set in tiles are all tiled by
  the surface pass. On the tree before (24d36aa) 21 of them fail: no screen
  is read or laid, nothing is said, the tender is not named, the towball pair
  stands on tiles and the magnet beams are two pieces, neither technique
  exists, and four of the car's six groups of studs are left as detail.
  A cabin's glass, its roof and its side studs (2026-10-14, the glass round,
  after both cabins-round cars laid their windscreen and built the car again
  by hand: "too blocky", its cabin solid red with side studs open along it;
  and a seat cut into the cabin that the screen read its roof off). On a shape
  with `"wheels"`, `Plan._glaze` lays the cabin behind the windscreen's top row
  in the screen's glass: every plate of the screen's own solid where no other
  solid is (the body keeps its colour), from the screen's foot to two plates
  under the roof, back as far as two plates of roof are over it and no further
  than the screen is wide; where the roof falls the glass falls with it, three
  plates under it for the curved slope there. Said
  in the screen's line ("Behind it the cabin is glazed ..."). A fuselage's
  cockpit (no wheels) is not glazed. In glass a layer is laid only in parts
  LEGO made in it (`Plan._made_in`, through `_tile` and `_across`), a 1 x 2 or
  1 x 4 brick as its glass brick (`Shapes.GLASS_SWAP`: 3065, 3066); no wedge,
  side panel or side-stud brick is laid in glass, and a side shell leaves the
  glass in its box, and what stands on it in its lane, to the core (`"glass"`
  on the shell; no shell part reaches in). The screen reads the
  roof across the solid's whole width (`"span"`) and off the solid as said,
  before any cut (`"roof_of"`), so a seat cut leaves it where it was. A shell's
  side-stud brick none of whose studs carries anything is a plain brick of
  its length; one holding something elsewhere takes a 1 x 1 tile on each open
  stud (`Plan._close_side_studs`). The "say a screen" hint (`_screen_hints`)
  fires only on a shape with wheels or of a solid said in glass. A model whose
  body a shape laid is told `Style.SHAPED_KEEP` (keep it, work on what shows)
  instead of "the shape pattern, for a body ..." (`_shaped_body`, or the last
  submit's patterns), and the "rounded across as well as along it" note is
  not said once the shape turned its flanks out (`Shapes.turned`). The guide's
  car example has no glass band; its cabin is glazed. `cabin_glass_probe`: the
  cabins round's two cars (one with its seat cut) and the second fire truck,
  as their sessions said them, each glazed down both sides in parts made in
  trans-black, said, one piece; a fuselage's cockpit not; none of those
  bodies, nor the shapes round's loft car, has an open side stud; the cut car's
  92583 stands where the uncut car's does, leaning back; a ship's raised
  stern is not told to say a screen, a canopy in glass and a car on wheels
  are; the first car and the truck are told to keep the body, not to say one,
  and the first car is not told it steps in plates. On the tree before
  (1a8079a) 19 of its checks fail.
  Found by the held-out car, told every check to use wedge plates and curved
  slopes and using none. `shapes_probe`: each surface part's fall is read off
  its mesh; a car, a hull, a bird and a fuselage (`BODIES`) each lay without
  trouble, pass the check in one piece, carry sloped, curved and tiled
  surfaces and are mirrors of themselves; a ramp falling a plate a stud takes
  18 degree slopes (curved 4 x 2s said curved); a box's top is tiled, not with
  `"top": "studs"`; a band colours by height; a loft without sections is
  refused saying what it wants; a box's straight sides carry eight side-stud
  bricks each with its tile, in one piece, and none with `"panels": false`.
  Measured against real vehicles
  (`tools/style.py`): curved 5-14% (median 14%), plain 58-67% (median 33%),
  sideways up to 5% (median 23%) — the solid core is plates and bricks, and
  round bodies have few straight sides; looked at on the GPU:
  `shots/runs/shapes/shape_*_corner.png`. `shapes_probe` ("a round or cut
  plan is laid in round parts and wedges"): a revolve about y of radius 5
  takes 8 corner rounds and 4 cut-corner bricks, a box with `"chamfer": 3`
  12 plates and bricks without a corner, an egg (ellipsoid 5 x 16 x 5 with a
  white front) 26 corner rounds and 24 wedges, 13% curved or sideways; each
  in one piece; a ramp's straight edges take none. Before (held-out round,
  2026-10-12, docs/ROADMAP.md) all three were staircases: 0, 0 and 2 wedges,
  the egg 4% — the wedge's cut side had to lie outside every stud of the
  plan, and on a round plan the studs the edge cuts are the plan's own (the
  egg is laid with `"sideways": false` there, to show its plan edges).
  A layer whose section is a disc 1, 2, 4, 6 or 8 studs across (`Plan.round_runs`:
  one colour, its box holding nothing else, nearer a disc of its own area
  than its box on a 4 x 4 grid in every stud, its own mirror where the shape
  is) is laid by the round pattern's own `Rounds._body` for each run of
  plates: round plates and bricks, cylinder halves, four corner rounds tied
  by a round plate. Its plates are taken, so nothing else is laid there, no
  slope stands on them (`_fit`) and no wedge cuts in; where all the shape has
  left over a run of 4, 6 or 8 is no taller than a dish, a dish (3960,
  44375b, 3961) crowns it. Off for a sculpt's grid (`"rounds"`; Brickify is
  unchanged). `shapes_probe` ("a round section is laid in round parts"): a
  cylinder of radius 4, a dome and a column stepping 6, 4, 2 are every part
  round (48092 and 74611; a 44375b crown; 5152 and 3941), each one piece; a
  square post takes none. The cylinder, the dome, the column and an
  ellipsoid 4 x 12 x 4 laid side by side were 370 parts, 9% curved, 49%
  plain before, and 60 parts, 100% curved after. `Shapes.last` says the
  runs (`round_runs`) and where each piece but the largest is (`apart`).
  The top of a smooth round run is its round tiles (`_round_tiles`: 98138,
  14769 and 7212 whole; the corner round tiles of 4 and 8 are rings a stud
  wide, so a round of 8 is three nested rings, 27507, 79393 and 27925, with a
  14769 in the middle, and a round of 4 the 27925 ring and a 14769:
  `TILE_RINGS`, read off their meshes — a 6 x 6 round tile's cover is its
  square box and overlaps the ring) and a dish crown carries a round tile on
  its middle studs. A round of 6 or 8 with a round a stud narrower standing
  on it is eased (`Plan._ease`): the step was a stud-wide ledge of bare
  studs, a wedding cake from the side; now the rim of the round below
  carries 2 x 2 curved slopes (15068) falling out on each side and a round
  plate with a quarter-round tile (6141, 25269) on each corner's one stud,
  two plates tall; inside them a core four studs narrower (round plates),
  and the round above goes on from a round plate that bridges in over the
  slopes (`_round_run`'s `under`). A round above only one or two plates
  tall is the slopes, all of it, and a round on it within those two plates
  goes on from over them ("6 at 2,2 is the slopes"): a squat dome's rings
  were a stack of round plates under a dish, studs bare on every ring.
  Only where the round above is one colour with the one below and nothing
  else of the shape is in the rim (`_rim_free`). A disc one plate thick is
  a round only on or under another round about the same middle
  (`Plan._stacked`): an oval head (the held-out owl's, 13 by 11 studs)
  passes through a disc of 8 at its crown, and a round plate there with a
  dish on it read as a hat. `shapes_probe` ("a round section is laid in
  round parts"): the dome eases both its steps (15068 x12, 25269 x8); a
  squat dome 4 x 7 x 4 eases its short ring (15068 x8, no 11213 or 3961);
  the owl's head lays no round plate or dish, one piece.
  A side that curves up and down is laid on its side (`Plan.shells`,
  `lay_shell`): for each way out, where the shape reaches past a face two
  studs in from its outermost, steeply (out no more than two studs in four
  plates), curving up the side (a cylinder and a flat side are not), at
  least five plates tall and with a core two studs deep behind it, the box
  of those lanes past the face is taken out of the core and laid by the same
  plan turned on its side — local x along the side, local plates out
  (0.4 stud), local studs down (2.5 plates a row) — then each part turned by
  the basis that takes up to out (`Rounds._cover`/`_placed`). It is held by
  side-stud bricks in the core's outer wall in every lane of every second
  row (the side stud is 1.75 plates up the brick; one lane in two cut the
  wall into columns of 1 x 1s): each run of lanes in one colour as 1 x 4s,
  1 x 2s and 1 x 1s with studs on a side (30414, 11211, 87087:
  `ANCHOR_RUNS`), split the same from either end so a mirrored side stays
  one (`_split`: 6 is 2 2 2, 9 is 4 1 4) — an egg was 84 1 x 1s, now 49
  bricks; the shell's own plan keeps only parts joined to a
  side stud the core kept (`Plan.held` in `prune`), is not stitched, and
  samples a row only where every plate it reaches into is its own. Where
  turning sides out leaves the core in more pieces than upright, it is laid
  upright (the probe car, cut by axle tunnels). Each shell is tried before
  the core is laid (`lay_shell` with `trial`, on every side stud it was
  given), and one whose kept parts cover less than `SHELL_KEEPS` (40%; a side and its mirror on the two together — a hull kept one flank at 65% and gave back the other at 55%, lopsided) of
  the plates it took out of the core is given back (`drop_shell`: its
  plates, the plates it kept clear and its side studs), and that side laid
  upright; so is one held by no side stud, which before kept its plates
  taken and laid none. The held-out car's body (8 wide, 3.5 plates over its
  arches) lost two studs a side to shells that kept 5 of their 74 parts —
  rows a stud apart from the top left its foot to no row — and eroded to a
  strip four studs wide. `Shapes.last["shells_kept"]` says each shell's
  parts kept and the share of its plates covered. `shapes_probe` ("a
  minifigure-scale car's body keeps its flanks"): 74 parts, from z 0 to 7
  across its middle (was 45, z 2 to 5). Off for a sculpt's grid
  (`"sideways"`). Also: a course with nothing under it and nothing studded
  over it is laid in plates, not bricks (`bridges`, off for a grid): a
  car's body over its arches came apart from its nose; and where anything
  of the same design stands on a shape's top — another shape, a round, the
  design's own bricks — those studs are kept (`Shapes.feet`,
  `Patterns.feet_of`, `_carried` from `Patterns.expand`, laid again when
  something other than a shape stands there): a cabin on a body stood on
  tiles, and the owner's orrery collar floated. A tile something is put
  down on later (edit_model, edit_selection, a design checked or submitted)
  is laid again as the plate of its size (`Assistant._studs_where_stood_on`,
  over `BrickLattice.standing_on`, "is anything standing on these studs"),
  in the same change. Its size, not plates under the part and tiles round
  it: a top's tiles tie the plates under them, and split, a rooms floor's
  tile left a 1 x 1 plate held by nothing (`rooms_probe` failed). Only
  parts this change adds or moves count, so an edit never re-lays the
  person's own tiles; and not where the plate's studs would run into another
  part over the tile by their real shapes (`_studs_would_meet`): a rooms floor
  is tiled under a dresser's door rail plates and an armchair's arms. `standing_probe`: a ring shape, a round column,
  plates one thick, each on a box's tiled top and on a revolve's rings of
  tiles, gripped by the studs under them (a stud of the lower part reaching
  into the upper, read off the connectors), the top round them still
  smooth; a brick added later gripped, the tiles under it plates and the
  rest still tiles; an edit about a selection one undo, which puts the
  tiles back; a recolour elsewhere leaves a tile under the person's own
  plate a tile. The
  check's "resting on a smooth face" advice now fires
  only for a part that grips nothing (`_note_loose`): every row of a shell
  rests on the edge of the one under it. `shapes_probe` ("a side that
  curves up and down is laid on its side"): the egg, the hull and the bird
  each a tenth or more turned out, tiles and slopes among them, on side
  studs, buildable, one piece; a cylinder's side is not turned. Upright
  against sideways (`"sideways": false`): egg 1.8% to 32% sideways, plain 73
  to 60%; bird 0 to 25%, 68 to 55%; hull 0.3 to 19%, 72 to 54%; the owl
  body 2.7 to 37%, 80 to 58% — and the curved share falls (12 to 8%, 10 to
  3%), because the corner rounds at the rim become the shell's plates.
  A shell's own plan is a flank (`Plan.flank`): where it falls a plate a
  stud, a curved 2 x 1 fits within half a plate and a cheese slope by a
  stud each, so the cheese is scored 0.3 worse there and the curved one is
  laid — except where its colour changes (`_one_colour`): on the probe
  fuselage's canopy edge a curved 2 x 1 laid there was held by nothing. The
  egg's flank went from 2 curved slopes of 143 parts turned out to 26 of 135
  (11477, 50950, 15068, 24309), the whole egg 3% to 9% curved and 450 parts
  to 407. `shapes_probe` checks the egg's and the bird's shells carry curved
  slopes (one in twenty turned parts or more; a hull's side falls straight
  and keeps its tiles) and that each of the three has fewer side-stud bricks
  than three quarters of the lanes they hold (egg 49 for 86, bird and hull
  22 for 62, where each had a 1 x 1 a lane: 84, 58, 58).
  A curved slope is hollow under its high end: a stud there reaches into
  nothing, as the check reads it, and only its low rows grip
  (`Shapes.part(...)["grips"]`, read off the part's cover a little past a
  stud's tip: 11477 [1], 24309 [1, 2], 61678 [2, 3], straight slopes every
  row). Upright that is hidden, since a slope rests on its plates; on a
  shell nothing rests, and the held-out owl (`owl_d3`) was refused four
  times for 11477s whose side stud stood under the hollow end — "held by
  nothing", or resting on the cheese slope a row below. In a flank a slope
  is laid only where a row it grips by is held (against the core, a side
  stud there; `_fit`), and its foot is those rows (`_gripped`), so `prune`
  keeps what the check will. `shapes_probe` ("a stud grips a curved slope
  under its low rows", "an owl's body on its post"): that owl's post and
  body, 4 floating and 5 pieces before, 785 bricks buildable in one piece
  after, 23 curved slopes turned out (29 before, 4 of them held by nothing).
  And a piece the stitch could not join because its plates stand beside a
  brick of the rest (`_unbrick`: the brick laid again as three plates, and
  its mirror, so a plate reaches across; off for a grid): the held-out car's
  body (`car_d3`), 5 plates over its arches, lost its nose past the front
  arch in 8 parts, 14 floating with what stood on them, and the run threw the
  body away. `shapes_probe` ("a car's body over its arches keeps its nose"):
  its axles, wheels and body as the run said them, 135 bricks, buildable,
  one piece.
  A face on a shell: a shape's `"face": {"facing": "+z", "x", "y", "z",
  "across": 4|6|8, "color", "rim", "eyes", "beak"}` (`Shapes._read_faces`,
  `Plan._face_on_shell`). On the shell that faces that way, the face's
  square is masked out of the shell's own plan; on the side-stud bricks the
  core already has behind it (`anchors`, every second row) a square plate or
  two (3031/3958/41539, `backing`: the square's mean surface height less two
  plates, so the disc is flush with the curve) and the round plate disc
  (60474/11213/74611), then two 2 x 2 round eyes (18674 in the iris's colour,
  98138p07 on the centre stud) and a beak (3794b jumper, 54200 falling down
  the face), all studs out, and the disc's other studs tiled — 3068b where four
  free studs lie wholly on it, 3070b where one does, a round 98138 at its rim —
  read off the part's own studs (`Patterns._studs_of`: the 6 x 6's ring is not
  every stud whose middle is on the disc). The first held-out owl with a face
  was judged "a round plate with its studs showing". A face that takes its
  whole side is laid alone there. It is moved up to two studs to fit the side and
  clear the core (`room`: every plate of a row the shell's or nobody's); a
  face that cannot be laid is a pattern trouble naming why (no curved side
  that way, too small, no side studs, the core in the way), never dropped.
  `owl_d4`'s face was white tiles on the shell and 1 x 1 eyes, because a
  2 x 2 round plate wants four studs out. `face_probe`: the held-out owl's
  post and body with a 6-across face, a cat's head with a 4, a big owl's with
  an 8 and a bear's facing -x with a 6 — each one piece, buildable, disc and
  both eyes 2 x 2 and studs out, every face part and tile held — and a box's
  flat side and a face said wrong
  refused with the reason. With an OUTDIR it saves `face_<name>.ldr`; render
  with `src/dev/bench_views.gd` to look (`--closef=0.2,0.8,0.6,1.0,0.5,1.0`
  frames the owl's head).
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
  Expansion happens here, from data: nothing runs anybody's code. Layers of
  plates over plates are laid the way, of four (turned or not, from the near
  corner or the far), that leaves the two layers in fewest pieces
  (`Patterns._layers_apart`), never a plate exactly over one under it: laid
  the same way every layer, the held-out owl's base (20 x 16, two plates)
  was columns of two, eleven pieces side by side. `patterns_probe`: a display
  base two plates thick is one piece; a round one is still in pieces where
  its rim's wing plates lie wedge on wedge.
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
  that way; `mcp_probe` checks a later check leaves the model standing. An
  assembly's close review ends on the next one not yet reviewed
  (`_not_yet_reviewed`), not "and stop", which the in-app loop's passes end on
  because the loop hands the next itself; and `save_model`, a run's last act,
  saves and hands back the next assembly's close review while any is left
  (`next_review`, from `CommandSocket`). Found by run 16: told "and stop" it
  made one edit to the first of its three assemblies and saved; no run from
  outside had reviewed more than two. `mcp_probe`: the east wall's review
  names the west wall, saving hands back the west wall's, and once both have
  had theirs saving only saves. It did not move run 17: handed the first of
  its five assemblies' reviews at its save, it finished anyway and said so.
- `how real sets build this`: a tool, over `PartLibrary.kinds_for`. The only
  thing the assistant can ask that is neither geometry nor my taste — what real
  sets of a kind are built from, by lift over sets in general. See
  `features/parts.md` for how it is measured. A brief names a kind in whole
  words, plurals and simple stems (`SubjectWords`), and a word made of a
  kind and one of `SubjectWords.COMPOUND_ENDS` (a spaceship is space); every
  other vocabulary that reads a brief (`Style.GROUP_WORDS`, `Style.TRAITS`,
  `Style.TOWER_WORDS`, `Rooms.SAID`, `Techniques.named`) goes through the
  same. The owner's orrery was reviewed as an aeroplane: "planet" began with
  the plane kind. `subject_words_probe`: an orrery and a planetarium are no
  kind of aeroplane in how_real_sets_build_this, the opening message and
  review_model, and are a mechanism (`Style.TRAITS["mechanism"]`, told a gear
  train from one crank, planets on arms, a heavy base, a counterweight);
  every vocabulary against some seventy near misses (planet, carriage,
  worship, giant, storey, shopkeeper, inspired…) matches none it does not
  hold as a word; castles, a spaceship, fire engines, two buses, an X-wing
  and a farmhouse still find theirs.
- `worked constructions`: `show_technique`, a tool, over `src/ai/techniques.gd`.
  83 constructions with real part numbers and real coordinates, each in a group
  (`Techniques.GROUPS`: basics, walls and stone, towers and columns, round
  bodies, faces and features, machines and joints, angles, roofs and spires,
  windows and doors, rock and ground, plants, furniture and interiors, lights,
  creative touches). Creative touches (2026-10-12) is the creative pass's: a
  lid or hatch raised on hinges (two 3937 bases, the tops and a 4 x 4 lid in
  a section turned -60 degrees about the pin), a small creature on a jumper
  (33320 frog; the why names the mouse, songbird, cat, rat and spider), and
  the display stand with a nameplate. Faces and features (2026-10-12), because the
  held-out owl's face was a panel of white 1 x 1 tiles with 1 x 1 dots for
  eyes: an eye with a highlight (18674 under a printed 98138p07), a round
  face (a 4 x 4 round plate with two eyes and a beak on it), a beak or snout
  (a cheese slope on a jumper), ears or tufts (slopes falling outward), talons
  (three 49668 tooth plates) and a vehicle's headlamps and grille, each on a
  bracket or a side stud where it faces out; the guidance's "WHAT THE SUBJECT
  NEEDS" sends a face to them and `Style.calls_for` names them for a living
  thing and a vehicle. `techniques_probe` ("a face is built as features"):
  each one piece, buildable, the eye a round plate and a printed pupil, and
  the guidance naming them. The round bodies, machines and display groups came with the round
  pattern: what it lays, named for the technique and not the subject (a round
  body, one lying down, a dome and cone cap, a ring of cones under a round
  plate, spokes with tiles, struts pinned to a Technic course, two rounds
  pinned side by side, a display stand with a nameplate), and six as LEGO
  built them in 21309 Saturn V (a curved skin panel, a studs-out core, a grille
  band, a cone bell on round plates, a round tip, a fin root on a Technic pin).
  `wide round tower` had two of its four 48092 turned the wrong way — a bow
  tie that stacked and checked — and is a ring now, tied by a 74611 round
  plate; `techniques_probe` checks each quarter curves out of the ring.
  Sixteen read off real sets stood half a stud off any floor as a whole, which
  the half-stud check (2026-10-11) refused on `techniques_probe`'s floor; each
  is moved half a stud back, its parts kept where they are to each other. The
  taper's 1x1 stands on an 87580's middle stud, and the bedside lamp's tap on
  its jumper's. An entry may carry `sections` and its bricks a `section`,
  as a design does: `corner on a turntable` is 10182 Cafe Corner's corner
  entrance steps, taken off their 2x2 turntable and put back on at the set's 45
  degrees by a section turned about the turntable's middle, and `leaning on a
  hinge` is 6085 Black Monarch's Castle's gatehouse flag on 3937/3938, its
  section's origin on the pin and the hinge top's studs at y=1.25 in it — the
  answer the "leaning on nothing" fault names. `show_technique` says the
  section before the bricks that name it. The
  tool's description and its answer to an empty or unknown name
  list them by group (`Techniques.listing()`). Eleven are hand-made (a staggered
  wall, a half-stud offset, a face turned sideways, a porthole, a smooth diagonal,
  a smooth top, a round tower, a wide round tower, a taper, a window and a door
  in a wall); 49 are real sets as LEGO built them, from LDraw's model repository,
  each naming its set and modeller (CC BY 2.0 or 4.0; `docs/ATTRIBUTION.md`):
  named sub-models (`tools/omr.py harvest WORD... --most 40`; a set number as
  the word takes every small sub-model of that set) and, since 2026-10-10, the
  craft nobody split out (`tools/omr.py clusters [--seeds REGEX]`: the parts
  round each bracket, inverted slope, cone, plant or textured part, inside a box
  a few studs about it and holding it, scored by `tools/style.py`'s kinds) —
  rough and weathered stone from 21325 and 9471, corbels and oversails from
  6080, 10176 and 7327, a turret spire from 75969, rock from 9476 and 6066, a
  bookcase, a fireplace, an anvil, a potion shelf, lanterns. Read into this
  app's numbers by opening each in the app and reading it back
  (`harvest_probe.gd -- DIR`), looked at on a contact sheet
  (`technique_sheet_probe.gd`, windowed, `-- --verdicts=DIR --into=DIR` for
  candidates), and kept only where the checker passes them. `techniques_probe`
  asserts each builds, says when and why, is in a group, credits its set and
  modeller if it is from one, that names are unique and found as words
  ("street lamp" is not the tree), and that the tool lists them by group.
  Measured as a library with `tools/style.py shots/techniques/library.ldr`:
  156 parts, 48 shapes, sideways 3.9%, plain 46% with the twenty; 658 parts,
  129 shapes, 34 colours, sideways 18%, plain 31%, organic 2% with 59. Angled
  was 0% until the checker learned round joints: the ones it refuses are real
  constructions, so a corpus for its false positives. Of 880 distinct real
  sub-models (`named2` and `fantasy_subs`, harvested 2026-10-10) the checker
  at 24c3422 passed 564, refused 232 for overlaps and 84 for floating or below
  ground. With shafts and bores (`geometry.md`, `round joints`) and the panes
  NESTS lacked, on a catalogue rebuilt for the parts they use: **617 pass, 182
  are refused for overlaps, none newly refused**. By the family of what
  overlapped (a model in more than one counts in each; passing after, of those
  refused for it): parts in hollow studs 20 of 75, clips on bars 6 of 36, bars
  and axles through holes 6 of 57, hinges 3 of 10, the one square turntable 1
  of 1, panes 5 of 25. What still refuses them, measured: a handle or a gate
  whose cover fills the opening a clip's fingers pass through (60478, 48336,
  42448 — inside the joint's length, 5.8 to 7.6 LDU off the bar); 75937, whose
  cover is its bounding box (over 64 boxes), with every axle and plate on it;
  a bar loose in a tube (4 in 6, not a joint); a pane its modeller mirrored;
  and parts beside the joint that overlap for reasons of their own. The
  turntable is how 10182 Cafe Corner stands its corner entrance, corner
  windows and tower at 45 degrees (13 turned assemblies in six sets); the
  harvest only takes square sub-models, so `joints_probe` is where a turntable
  turned 10, 30 and 45 degrees is checked.
- `real sets' pieces by what they are`: `find_techniques(query, max_studs?,
  kinds?)`, `place_technique(id, x, y, z, turn?, recolor?)` and
  `find_parts_like(query)` in `assistant.gd`, over `src/ai/real_snippets.gd`.
  The worked constructions are seventy-odd chosen by hand; this is every named
  sub-model of 2 to 60 building parts in LDraw's model repository (Eye L, Beak,
  Bonnet, Grille, Wing, Tower Roof...) and three clusters of craft a model
  (`omr.found_clusters`), built by `tools/snippets.py build` from `vendor/omr/files`
  (`tools/omr.py fetch --themes all --min-parts 30`: every theme but `UNSCULPTED`)
  into `assets/knowledge/snippets.json.gz`, which the desktop exports carry and
  the web build fetches from beside itself on first use (`web.md`). Each piece: set, modeller and licence (CC BY;
  non-commercial and share-alike files left out), part count, size in studs,
  parts and colours, kinds by `tools/style.py` (sideways, curved, hinged...), the
  LDraw lines to place it as built, and `text`: a line written by Claude from its
  thumbnail and part list (`src/dev/snippet_thumbs.gd` renders the thumbnails
  into `vendor/omr/thumbs/`, `tools/snippets.py batches` makes numbered sheets,
  `tools/describe_snippets.sh` runs Claude Code on the subscription — no
  `ANTHROPIC_API_KEY`, Read only, one `heavy` slot — and `tools/snippets.py
  texts` keeps the answers in `assets/knowledge/snippet_texts.jsonl.gz`). Search is
  BM25 over fields (name x3, what it sits in, text x1.5, synonyms and kinds, the
  set x0.7), stemmed alike in Python and GDScript ("EyeL", "eyes" are eye; a
  Y-wing is not a wing; "wheel arch" also asks for "wheelarch"); pieces from sets
  about the query's subject come first, then sets about its kind (`SUBJECTS`: an
  owl, then birds and animals), at most two a set; the subject word itself counts
  0.3 in the score (`SUBJECT_WEIGHT`), so within the subject's sets the feature
  decides ("bird beak": a parrot's beak before whole birds). 12,954 of 12,967
  pieces are described (360 sheets, Sonnet on the subscription, ~21 s a sheet).
  Recall on ten queries written beforehand (`docs/ROADMAP.md`): 8 of 10 with
  something an expert would use on names alone, 9 with descriptions; the miss
  left is the corpus (no owl or dragon set). `find_techniques` answers with
  the best three (`FOUND`), each credited, in two lines (`_piece_line`: id,
  size, whether it lays, its description cut at 110 characters, its first
  four parts), and one picture of them side by side, 200 pixels a piece
  (`_snippet_picture`, headless: text only) — five with whole parts lists
  and a 1,600-pixel sheet was a long read a run made once.
  Features, one at a time, driven by the app (`src/ai/feature_pass.gd`,
  2026-10-13): `submit_design` takes `features` (required in the schema: what
  the subject is known by, each `{"name", "x", "y", "z", "facing"}` — where
  it goes on the model and the way it faces out, +z the front; a bare string
  still reads), `Model.features` and `Model.feature_spots`. In the app's loop
  the whole look is for the silhouette, then each feature comes back before
  the assemblies (`_queue_features`, `TURNS_PER_FEATURE` 4). For each, the
  app does the retrieval itself (`FeaturePass.propose`): `candidates_for`
  searches the index for the subject word and the feature (`_subject_words`,
  "owl eyes"), then the feature alone, and keeps up to six pieces that lay
  whole (`lays`, square, at most 40 parts, no wider than 0.6 of the model);
  `spot_for` takes the design's spot or reads one off the name (`WHERE`:
  eyes high on the front, wheels low on the side, ear tufts on top, tails at
  the back) on the model's surface at that height, not its box; `fit` tries
  the piece as built with its front turned to the spot, then tipped whole so
  its studs face out, seated by its lowest hollows on the free studs nearest
  the spot that point its way — on the outside (`_outside`: nothing on the
  stud, nothing between it and the model's edge the way the feature faces;
  the d6 shop's awning and sign were laid on its floors), within `REACH` 4
  studs and, facing sideways, `DEPTH` 1.5 studs of the face (seven studs every
  way put a starfighter's exhausts on its fuselage) — kept when no part runs
  into the model and one is held by it (`OpenPoints.test`); `lay` puts it down through
  `edit_model`, checked like any edit; a plural feature off the middle gets
  its pair, mirrored. `_feature_brief` hands it over: the piece, its credit,
  where it was seated and how, its bricks, whether the spot was a guess, the
  next-best, the worked technique, a picture framed on it from the way it
  faces (`_proposal_picture`, none headless), and `SETTLE_HOW`.
  `settle_feature {feature, verdict}`: `accept` (with `move`, `turn`,
  `recolor` first: the same piece laid again in one edit with taking the
  old off, so a refusal leaves it), `next` (taken off, the next candidate
  laid), `reject` (a reason of three words or more; taken off), `built` (a
  reason, or an edit put down to the feature; the app's piece is taken off). In the loop a settle ends the
  feature's turn (`_feature_closed`) and the next comes; turns run out with
  the piece standing and it is "kept". From outside: the build's answer says
  so (step 2), the whole review hands the first feature with its piece laid,
  each settle hands the next, after the last says the assemblies or the
  creative pass are next; `save_model` refuses while any feature is not
  settled (`Assistant.save_gate`, checked in `CommandSocket._run_own` before
  anything is written) and hands the first open one back with its piece —
  every bench session had saved with features unworked, and the old save
  wrote the file and then handed the next feature, which the session read as
  done. review_model, save_model and settle_feature answer with the picture
  as blocks (`Assistant._joined`). What each came to is said as each ends
  and all together as the run ends ("eyes: real piece 7784-1/eye-rh "eye rh"
  laid by the app, accepted"; "beak: the app's piece rejected: ..."). A
  `--ask-claude-code` run prints the app's progress lines ("app: working the
  eyes (feature 1 of 4)", "app: the eyes: ..."), so a bench log says what
  each came to. `features_probe` drives both with replies written in it: in
  the loop the eyes laid from a real piece that lays (from "owl eyes": the
  Batmobile's eye), accepted, the beak laid at the spot given and rejected
  with a reason and taken off, the run's record; from outside save_model
  refused with both open and the eyes laid as a mirrored pair, "next" laying
  the next-best, accept with a move laying it a stud back and handing the
  beak, a reason-less rejection refused, the last settle naming the next
  step, save going ahead, the whole review's record. Windowed (`xvfb-run -a
  godot --path . --resolution 1200x800 --script src/dev/features_probe.gd`)
  it writes the proposal's picture to `shots/features/eyes_proposal.png`.
  Needs the index; SKIP without.
  The surface pass, before the creative pass (`src/ai/surface_pass.gd`,
  `SurfacePass`, 2026-10-13): the app reads the model's open up-facing studs
  exactly (nothing on the stud — `BrickLattice.standing_on`, the question a
  shape asks before tiling its top, or for a stud in a turned section the
  tip test of OpenPoints — nothing within a brick over it, and seen: clear to
  the top, or open to the outside on two sides, as a lower wing under the
  upper one is; on a plain brick, plate, slope, wedge, wing or baseplate, its
  whole square part; in the main body and in each section's own frame, so a
  wing laid at an angle is tiled in it), and the tiles already lying open
  (`tile_tops`, by the studs under them), and finds four things — `studs`, a
  field of four or more
  joined at one height, tiled in the colour under it, largest real sizes
  first (`TILES`, only sizes made in that colour) with one to three textured
  tiles (`ACCENTS`: grille 2412b, ingot 96910, jumper 15573) on a field of
  16 or more; `staircase`, two risers or more of one to three plates along one
  way with treads of one to three studs, studded or tiled (a tiled tread's
  tiles come off first, `_cut` laying again what of each lay beyond the
  slope, and go back on a reject), each riser covered by a slope or
  curved slope laid on the tread below (read off its mesh by `Shapes.part`
  for fall and height; curved first unless the brief is a building), or,
  where the tread is one stud under a brick's rise, the brick above laid
  again as a 45 degree slope (3037-3040b) with the rest of it in bricks and
  its stud row tiled if open, else a plate and a cheese slope; and steps a
  plate high two at a time (`_cover_pairs`, 2026-10-13 steps): up each run
  of them from the bottom, a curved slope two plates tall (88930, 15068,
  11477; 7302 where one tread is two studs) on the lower tread's studs, the
  upper tread's plate cut under it and the rest laid again in plates, the
  pair's tiles off — a lone step at the top is left; `edge`, for
  anything not a building (`_straight_first`), a flat top of eight studs or
  more, studded or tiled, not the ground and not a yard, whose edges drop
  away: curved slopes two plates tall (15068, 11477) along each edge that
  drops, falling outward, two studs deep, and the rest of the top raised
  flush with a plate and tiles, its own tiles off first (`_crown`) — nothing
  under the top is touched, so what ties the body together still does;
  `flank`, for anything not a building (`_flanks`, 2026-10-13 steps), a
  course of plain one-wide bricks (or two-wide's outer rows), a face stacked
  two courses or more, four studs long or more, one colour, clear in front
  for a tile and flush behind over the course above in the same colour
  (`_skin_room`): the course laid again in bricks with studs on the side
  (30414, 11211, 87087, `_turned_out`) and on them, laid on their side
  (`_onto_side`, the arithmetic of `Assistant._panel`), tiles two studs tall
  straight on the studs, a plate proud, with a rounded-end tile 5520 at each
  end (`_rounded_end` reads which end is round off its cover), courses tried
  top down. Not a course that is not the body's (`_off_the_body`, said in
  "Left as studs"): the bottom course on a wheeled base or one no higher
  than its wheels (`_wheel_top`, wheels within a plate of the model's
  bottom), one under a wider course whose face reaches past either end over
  open space, or one in a colour the body over it is not — the steps
  round's car had its black course between the wheels skinned, and the
  judge saw "black slabs ... like blocks". And a side built of plates
  (`_plate_flanks`, 2026-10-14 sides), which a brick flank cannot read: at
  a face of the main body, a course of three plain plates stacked (or one
  plain brick, under plates: one brick course is no brick flank), one
  colour, four studs along or more, nothing in front, and over it, within a
  stud behind the skin's span, the body in the course's colour
  (`_skin_backed`: flush, or a step a stud back, which the skin covers;
  never a stripe painted out). Its outer row is cut (`_cut`, the rest of
  each plate laid again in plates), laid as bricks with studs on the side,
  and skinned as a flank is (`_skin_pieces`); faces are read top down, no
  skin over another or over a brick flank's. Runs that cut the same parts
  are one finding (`_sharing`): a body of plates its full width has both
  sides in the same plates, and two findings may not take one part — the
  later run gives up a corner stud, and a run sharing a part at another
  height is left. `_off_the_body` holds for it too. And open studs on a
  part's side (`_side_fields`): pointing sideways, nothing on them, nothing
  within a stud and a half out, on a part whose studs are finished, four or
  more joined on a grid a stud apart, one colour — tiled on their side
  (`_onto_side`), largest tiles first; "the right wing is a flat plate with
  its studs showing" (the steps round's owl). The record says both apart
  (`Finding.of`): "2 flanks skinned (1 of plates)", "8 side studs tiled".
  `surface_probe`: a body of
  seven plates stacked, a stud narrower over its fourth on one side, gets
  both sides skinned in one finding (two 30414s a side, 5520 at each end, a
  2 x 4 between, the three plates cut to 2 x 8s) in as many pieces; one
  course of 1 x 8 bricks under plates gets both sides; two side-stud bricks'
  eight open side studs all tiled. And `wall`, for a building only, a
  plain one-wide (or two-wide's outer row) wall open to the air, six studs by
  three courses or more, nine tenths one colour, laid again by `_restyle`
  in its box with masonry only (`"turned_out": false`: no stud turned out).
  No part may be taken off by two findings (`_taken_off`): the edges
  round's starfighter cut one plate from both sides and the edit of all was
  refused. Every finding is laid at once up to `MOST_FINDINGS` (40); any
  more are counted and said for the next review. Left alone, and said: a
  Brick Art mosaic, a field a figure,
  animal or plant stands among (a yard), fewer than four studs, anywhere the
  design kept or rejected; the ground (a plate or two up, spanning most of
  the model) is offered as G1, laid only on "tile". The findings are laid
  in one edit_model (one check: a check of the starfighter is most of a
  minute, and one at a time a review took six, past the relay's three) after
  their studs are checked open again, one at a time only if that is refused
  and for at most `LAYING_MS`; the bricks are given back to each finding by
  part and place (`_share_out`). Where a finding takes parts off, the model's
  pieces are counted first and edit_model refuses an edit that would leave
  more (`Assistant._keep_pieces`): the surface round's shop stood on 137 loose plates,
  and a step brick or wall brick laid again may be what tied two others. The design
  gets one corner picture with each marked S1, S2 ...; `settle_surface`
  accepts (`plain`, `recolor` to adjust), rejects or keeps with a reason
  (pieces off, what they replaced put back, the zone never proposed again).
  In the loop it is a turn of its own (`_surface_wanted`, `_surface_turn`,
  `SurfacePass.TURNS` 4) after the assemblies, ending when every finding is
  settled; from outside `review_model {"surface": true}`
  (`surface_review`), the build's answer and the head name it, and saving
  says it was never run (once alone, then before the creative pass), or
  which findings wait — never refusing. The creative brief says a touch
  stood on a tile floats. `surface_probe` drives it on fixtures.
  The creative pass, last (`CREATIVE_PASS`, `_creative_brief`, 2026-10-12):
  once the features and assemblies have had their turns, a fresh design
  (`_creative_wanted`, set by `_start` for a new conversation, never a
  revision or a selection) is handed one more turn of its own,
  `TURNS_FOR_TOUCHES` 6: propose three touches for this subject, one each of
  a story (a figure doing the subject's own thing, with its tool, catch or
  load), a play or display feature shown working (a lid ajar, a jib on a
  turntable, a printed nameplate — a blank one reads as blank) and a nod
  (its maker, number or year printed, the detail it is famous for, a part
  used for its look); add the best one or two, small, joined, where they are
  seen, never at the likeness's or the build's cost; say which. The brief
  quotes the subject, says what the model has already (`_touches_had`:
  figures, creatures, printed parts, parts that hinge or turn) and names
  find_techniques words and the creative touches techniques. It ends as
  "the creative pass: 2 parts added, new to the model: 3794b …, 33320 Animal
  Frog" (`_creative_said`, `_creative_record`) or "nothing added". From
  outside: the build's answer makes it step 4, `review_model {"creative":
  true}` hands it, the whole review and the last assembly's end on it, and
  saving hands it once nothing else is left (`_creative_next`, only after a
  submit_design from outside); the save after the pass says what it added
  (or once, that it added nothing) first, before any feature or assembly it
  hands back (`_creative_passed`: three of four bench sessions worked the
  pass before their features), then saving only saves. A bench run's log shows "the creative
  pass" for the call and "app: the creative pass: …" for what it added.
  `creative_probe` drives it with canned replies: owed to a design and not a
  revision, handed after the look with its kinds, subject and inventory, a
  frog on a jumper added and the model one piece, the record said, a pass
  that only calls tools ended after its six turns, and from outside the
  answer, saving and review_model creative=, and a pass worked before a
  feature said at the save that hands the feature. With the pass switched
  off, 12 of its checks fail. Measured (`2026-10-12-creative`, four subjects
  one run each, docs/DESIGN_SCORES.md): every session called the pass, and
  creativity went from 3.0 to 5.2 against the re-scored baseline, each
  judge's reason naming what the pass added; none added a play feature. `place_technique` reads the piece
  with the app's own LDraw reader, turns it by quarter turns, moves its low
  corner to x, y, z by whole studs, swaps colours by `recolor`, and lays it
  through `edit_model`, so the joints checker refuses it like any edit; pieces
  built at an angle or mirrored (`square` false) are shown, not placed.
  `src/dev/snippet_verdicts.gd` lays every square piece alone the same way and
  checks it (`vendor/omr/snippet_verdicts.jsonl`, folded in as `lays`/`why`):
  4,487 of 10,699 lay whole; search counts those 1.25 times and the answer says
  of each whether it lays. `tools/snippets.py build --from INDEX` redoes only
  subjects, descriptions, verdicts and terms, in seconds.
  `find_parts_like` searches `assets/knowledge/part_looks.json`: the 600 part
  families real sets use most (`tools/part_looks.py`, sizes and hands taken out
  of the name), each with a line by Claude of what it reads as in a model
  (feather, claw, exhaust). `snippets_probe` checks credit, search, that the app
  and `tools/snippets.py search --ids` agree, and lays an eye, a car nose, a
  wing, a beak and a turret roof on a plate, whole and joined.
- `recall our own scored designs`: `src/ai/design_memory.gd` over
  `assets/knowledge/designs.json.gz`, which `tools/design_memory.py build`
  writes from the design bench's records (every
  `<batch>/<subject>/<run>/record.json` under the main checkout's
  `bench/results/`, where `tools/bench/run.py` now writes from any worktree, or
  `--results DIR`; dry runs and a re-score's `oldcheck/` left out) and merges
  into what the index already holds: bench results are gitignored, and the
  creative, d5 and d5b rounds' critiques survive only in the index. The
  baseline's build is taken from the re-score's table in
  `docs/DESIGN_SCORES.md` (`RESCORED`); the d5 batches' build, judged on the
  old check, is not told (`OLD_CHECK`). Each design:
  subject, title, brief, the judge's six scores and reasons, its visual mean
  (buildability left out: the check mis-scored it before 26ddb89), how it was
  built (`tools/style.py`'s shares and its five most-used shaped parts), what
  its log says it did (features worked, worked techniques read, real-set pieces
  laid, figures stood) and a 192-pixel JPEG of its corner view. Search is
  BM25 like the real-set index (title x3, brief x1.5, kinds of subject,
  features, the judge's words x0.3), with a subject word also asking for its
  kinds (`snippets.SUBJECTS`: an eagle asks for birds); a design is near only
  if the query shares a word of its title or a kind with it, so a revision is
  handed nothing. `how_real_sets_build_this` answers with it after the
  kinds data (`DesignMemory.recall`: the nearest subject's best design, its
  scores, how it was built, the judge's three lowest reasons to design out, its
  best, two more subjects in a line each, and its picture), and the app's own
  loop has it in its first message (`opening_for`), in words only, because the
  pictures there are the reference (`reference_probe`). `--held-out=ID[,ID]`
  hides a subject's designs; `tools/bench/run.py` passes the subject under
  test, so a bench score is never the memory of the same subject.
  `design_memory_probe` measures recall on sixteen phrasings no title uses,
  checks a revision gets nothing, that holding out hides the subject, and that
  the tool, the first message and the guidance head carry it; run with
  `-- --held-out=speed_champions` it checks the flag as the bench passes it.
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
  (46), 57895 glass at (0, 4, 5) (19). And on 2026-10-10 the panes still
  refused: 3854 in 6556 and 60594, 60607 and 86210 in 60594, 38320 in 60592,
  57895 in 57894, with the seats sets use both ways round. The overlap is
  forgiven only there, to an LDU, in the frame's LDraw coordinates;
  `techniques_probe` asserts a pane a plate high and a door half a stud along
  are still refused, and `joints_probe` a 3854 not turned into its groove.
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
env -u ANTHROPIC_API_KEY xvfb-run -a godot --path . -- --mcp=8790 \
  --ask-claude-code="a lighthouse" --sketch-first --out=/tmp/x.ldr   # three sketches first, on your plan
```

Effort is one of `low medium high xhigh max`. The app needs the person's own key,
pasted into the panel, or their own Claude plan — **My Claude** on the desktop, or
a Claude session driving the app over MCP ([mcp](mcp.md)). The CLI uses the key in
the environment or `.env`, and without one a run ends at once with
`Assistant.NO_KEY`. A Brickworks account pays for nothing, and **the user's key never reaches our
server**: every request goes from the app straight to Anthropic.

## How to check it

The big design that froze the web app, made and timed (see web.md for the
same in a browser):

```sh
godot --headless --path . --script src/dev/responsive_probe.gd   # a big check on a worker, frames throughout
~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 --script src/dev/freeze_probe.gd
#   the Falcon made through the connector's answer_rpc, every frame timed, then
#   8,484 parts turned round; add -- calls.json to replay a run's own calls
```

Static: nothing static covers the loop. `pyright` covers `tools/design.py`.

Runtime, all free — these are the ones to run after changing the loop:

```sh
godot --headless --path . --script src/dev/rules_probe.gd       # the rules, and what it is told
godot --headless --path . --script src/dev/world_view_probe.gd  # it reads back what it wrote, and how big it is
godot --headless --path . --script src/dev/edit_probe.gd        # change a model without re-describing it
godot --headless --path . --script src/dev/selection_probe.gd   # a change asked about a selection keeps to it
godot --headless --path . --script src/dev/design_undo_probe.gd # each request in the panel is one undo step, Claude's; the person's own stay theirs
godot --headless --path . --script src/dev/sketch_probe.gd      # Sketch first: three sketches, one sent back, the second chosen and designed from; over MCP too
xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/sketch_probe.gd -- --pictures=DIR   # ...and each one's picture
godot --headless --path . --script src/dev/selection_fit_probe.gd   # ...and lands the first time: Orthanc's horn, its open studs, refusals that say where, copies that follow
xvfb-run -a godot --path . --resolution 1200x800 --script src/dev/selection_fit_probe.gd   # ...and the numbered picture: shots/selection_fit/points.png
godot --headless --path . --script src/dev/scale_probe.gd       # a model too big to list in one go
godot --headless --path . --script src/dev/scanner_probe.gd     # half-written arguments yield whole bricks
godot --headless --path . --script src/dev/reader_probe.gd      # the reassembled answer matches what was sent
godot --headless --path . --script src/dev/busy_probe.gd        # a second design during the first
godot --headless --path . --script src/dev/dropped_probe.gd     # a dropped connection, retried
godot --headless --path . --script src/dev/restore_probe.gd     # a failed design leaves the model alone
godot --headless --path . --script src/dev/brain_probe.gd       # the request carries only what the model accepts
godot --headless --path . --script src/dev/reference_probe.gd   # a picture gets in
godot --headless --path . --script src/dev/reference_lookup_probe.gd  # and one can be found
godot --headless --path . --script src/dev/patterns_probe.gd    # a shape said rather than counted out; a clustered tower stands and takes rooms
godot --headless --path . --script src/dev/dress_probe.gd       # dark walls dressed as one structure, a file read as it stands
godot --headless --path . --script src/dev/candidate_probe.gd -- MODEL.ldr  # may it go on the landing page: whole, one piece, stands up, no new fault
godot --headless --path . --script src/dev/redress.gd -- IN.ldr OUT.ldr ['{"style": "panels"}']  # dress a saved model again, underpin it, write it
godot --headless --path . --script src/dev/rooms_probe.gd       # floors and furnished rooms in what stands
godot --headless --path . --script src/dev/daylight_probe.gd -- MODEL.ldr X0 X1 Z0 Z1 Y0 Y1 [HEADING]  # sightlines through a saved model
xvfb-run -a godot --path . --resolution 1200x800 --script src/dev/rooms_probe.gd  # ...and pictures: shots/rooms/
godot --headless --path . --script src/dev/repeat_probe.gd      # ten thousand bricks from two hundred and fifty
godot --headless --path . --script src/dev/detail_probe.gd      # each assembly detailed on its own, through the real loop
godot --headless --path . --script src/dev/techniques_probe.gd  # the worked constructions are real parts
godot --headless --path . --script src/dev/snippets_probe.gd    # real sets' pieces found by what they are, credited, laid whole and joined
python3 tools/minitest.py tests/test_snippets.py                # the search on a hand-made index: subject first, plurals, filters
godot --headless --path . --script src/dev/design_memory_probe.gd  # our scored designs found by subject, the judge's faults handed over
godot --headless --path . --script src/dev/design_memory_probe.gd -- --held-out=speed_champions  # ...and never the subject under test
python3 tools/design_memory.py list                             # what the memory holds: each design's scores and kinds
godot --path . --resolution 1400x900 --script src/dev/technique_sheet_probe.gd  # and each looks like its name: shots/techniques/
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

### The design bench: is a round better, and by more than the noise

`tools/bench/run.py` is the measuring stick for design rounds; its tables are
`docs/DESIGN_SCORES.md`. Ten fixed held-out subjects (`tools/bench/suite.py`),
each designed by the real loop on the subscription, rendered, checked, measured
and scored 1-10 on six dimensions by a calibrated judge (`tools/bench/judge.py`).

```sh
python3 tools/bench/run.py list                     # the suite, its briefs and references
python3 tools/bench/run.py run --dry-run --subjects bonsai   # canned design + canned judge, no network
~/.claude/claude-core/bin/heavy python3 tools/bench/run.py run --date 2026-10-12  # the batch: every subject once, one at a time
python3 tools/bench/run.py run --date 2026-10-12 --run 2 --subjects barn_owl,bonsai,mobile_crane
python3 tools/bench/run.py summary --date 2026-10-12 --append docs/DESIGN_SCORES.md
python3 tools/minitest.py tests/test_bench.py       # the reply, the probe and the summary read right
```

Per subject: the design (`--ask-claude-code` off-screen under `heavy`, its own
port, `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` taken out, `--timeout`
2700 s); corner/front/close by `src/dev/bench_views.gd` under `gpu`;
`candidate_probe`; `tools/style.py --json`; the references (Commons photographs
fetched, real sets from the model repository rendered); then the judge —
`claude -p` with `--tools Read --restricted --strict-mcp-config --json-schema`,
on the subscription, shown the two anchors (LEGO's 10242 MINI Cooper = 9, a
naive brick-stack car `tools/bench/naive_car.ldr` = 2, rendered once into
`bench/results/anchors/`), the references, the views and the probe's words.
Run a batch as one `heavy` job, as above: the design and probe steps inside it
then take the slot it holds. Run bare, each queues for a slot of its own, and on
a busy machine (load 60 on 24 cores, 2026-10-12) a one-minute probe waited 18
minutes. The per-run `--timeout` is inside the slot, so a queue is never counted
as the design's time.
Everything goes to `bench/results/<date>/<subject>/<run>/` (gitignored), and each
stage is skipped when its file is there, so the same command resumes a stopped
batch — pass the same `--date`, or a batch run past midnight starts a new folder.
The design's saves and its `claude-code-mcp-<port>.json` are moved out of the
app's user folder into the run's `saves/` — a save is the run's if the log names
it or it was written during one of the session's `saving` steps (the session
names only its last save; the first baseline owl left its first behind), never
a file older than the session; Godot's own log goes to the run's folder
(`--log-file`), not `user://logs`. `--no-judge` designs, pictures, checks and
measures only; the same command without it later judges what is there.
`rejudge` judges recorded runs a second time (`judge_again.json`), the judge's
own noise without the design's. A fresh worktree needs `godot --headless --path
. --import --quit` once before `bench_views.gd` can name the app's classes.

Proves it when: the dry run writes `record.json` with the canned scores (mean
4.5) and three real views, `views_*.png` show the model, the probe and style
JSON are filled; a real judge's `judge.json` lists in `looked_at` every picture
named in `judge_prompt.txt`; and `summary` prints a row per subject, the suite
mean, the run-to-run spread and the three weakest dimensions. The baseline
(13 runs, 2026-10-12) took 2 h 26 min once its `heavy` slot came; a judge call is
about 20 s and reads 7-9 pictures.

### The pairwise judge: which of two designs is better, and is a round's gain real

The 1-10 judge moves 0.7-1.0 between two designs of the same code, so most
rounds land inside its noise. `tools/bench/pairwise.py` asks instead which of two
designs of one subject is better, per dimension and overall, A or B with a
reason, both orders (BrickBench's method), and fits Bradley-Terry ELO with 95%
intervals from 1,000 resampled pairs. `tools/bench/calibrate.py` makes pairs
whose answer is known, to measure the judge first.

```sh
python3 tools/bench/run.py pairs --dry-run --subjects sailing_ship   # canned reply, into bench/results/dry-pairwise/
python3 tools/bench/run.py rank --dry-run --subjects sailing_ship    # both orders split: every ELO 1000
env -u ANTHROPIC_API_KEY python3 tools/bench/run.py pairs --jobs 4   # every two designs of each subject, from every batch
env -u ANTHROPIC_API_KEY python3 tools/bench/run.py pairs --subjects starfighter --repeat 2   # the judge alone, asked again
XDG_DATA_HOME=$PWD/.scratch-data ~/.claude/claude-core/bin/gpu python3 tools/bench/run.py calibrate --draw-only
#   (or: ... calibrate --draw-only --software --jobs 3, the same renderer on lavapipe under heavy)
env -u ANTHROPIC_API_KEY python3 tools/bench/run.py calibrate --absolute --jobs 4
python3 tools/bench/run.py rank --out /tmp/ranking.md                # ELO, run-to-run spread, each lever
python3 tools/minitest.py tests/test_pairwise.py   # the fit on synthetic pairs, the reply, the faults
```

A subject's pool is every batch's runs that have their three views
(`bench/results/<batch>/<subject>/<run>/views_*.png`), never `pairwise*`, `dry-*`
or `anchors`. Each design's pictures are copied to
`bench/results/pairwise/<subject>/designs/<code>_<view>.png`, the code a hash of
its batch and run, so the judge cannot read a round from a file name. Each
ordered verdict is `judged/<codeA>-<codeB>.json` (`-2` for a repeat), skipped when
there, so a stopped run resumes. `ROUNDS`, `LEVERS` and `TWINS` in `run.py` say
which round each batch is, what each lever is read against, and which designs
were made on the same code (the run-to-run spread). `calibrate` writes its models
(a real set and a naive stack of it; a design and the same design with its
tiles off, in one colour, or without its figures) to
`bench/results/pairwise/calibration/models/`, draws each with `bench_views.gd`
(a fresh worktree needs `godot --headless --path . --import` first), and judges
each pair both orders `--repeats` times; `--absolute` scores each model 1-10 too.
Draw first and apart: `--draw-only` inside one `gpu` lease waits for the GPU
once and no call to the judge holds it. When the GPU's queue is long,
`--software` draws on lavapipe under `heavy` with Godot's Forward+ renderer
(`GODOT_GPU=1` pinned to the lavapipe ICD; the wrapper's plain software path is
the compatibility renderer, which shades differently): measured against the GPU
on the 75895 Porsche, 70 of 1,048,576 pixels differ by more than 16 of 255.

Proves it when: the dry run's `rank` prints 1000 for both ship designs (a judge
that always says A cancels over both orders); `tests/test_pairwise.py` passes
(strengths given back within 25 ELO, the 95% interval round the truth on 85% or
more, one tile in four taken off in file order); `calibrate` prints its
agreement (2026-10-14: 256 of 256 verdicts on 24 known pairs, both orders the
same on 99%); and every `judged/*.json` lists in `looked_at` all six design
pictures (456 of 456 on 2026-10-14). A call is about 22 s; four at once judge a
subject of 12 designs (132 calls) in about 13 minutes.

### Real sets: our design against the set, blind

`tools/bench/realset.py` draws its subjects from vendor/omr: main models of 80 to
1,500 parts from 2000 on, one model to a box, none of a kind any round touched
(`TOUCHED`, `TOUCHED_THEMES`, and a quarter of the sub-models' names; the suite's
reference sets by number too). `sample` is fixed (a hash of the set number):
tune, which the tool was built on, and proof, run only at the end.

```sh
python3 tools/minitest.py tests/test_realset.py              # exclusion, halves, brief, reading
python3 tools/bench/realset.py sample --which tune --show     # never --show the proof half while tuning
env -u ANTHROPIC_API_KEY python3 tools/bench/realset.py calibrate --which tune --jobs 2
gpu env -u ANTHROPIC_API_KEY XDG_DATA_HOME=$PWD/.scratch-data MESA_VK_WSI_DEBUG=sw python3 tools/bench/realset.py run --which tune --arm dry --subjects 40148-1 --dry-run --jobs 1 --audit-later
gpu env -u ANTHROPIC_API_KEY XDG_DATA_HOME=$PWD/.scratch-data MESA_VK_WSI_DEBUG=sw python3 tools/bench/realset.py run --which proof --arm mine --checkout ../mine --jobs 2 --audit-later
heavy env -u ANTHROPIC_API_KEY XDG_DATA_HOME=$PWD/.scratch-data python3 tools/bench/realset.py audit --which proof --arm mine
env -u ANTHROPIC_API_KEY python3 tools/bench/realset.py compare --which proof --arms m32,mine --jobs 2
godot --headless --path . --script src/dev/design_memory_probe.gd -- --held-out=40148-1   # the set's pieces held out
```

Each of `--jobs` workers runs its share of the subjects, one after another
(worker-<set>.log). Run under one `gpu`, every worker's designs (run.py's design
stage takes the lease itself when it is run bare) and pictures share that lease,
and no worker waits for a CPU slot; `--audit-later` leaves the build check's
reading (floating parts, the only CPU work) to `audit`, one `heavy` job after the
run. `--software` draws on lavapipe and makes each worker one `heavy` job, as every
run was before 2026-10-16's technique round: the set drawn
and checked once into `bench/results/realset-sets/<set>/`, the design by run.py's
design stage into `realset-<date>-<arm>/<set>/` (brief.json, design.ldr, views,
audit.jsonl, record.json, judged/), both drawn by `bench_views.gd` and copied to
`bench/results/blind/<code>/` under hashed names, which is also the judge's
working folder, so neither a path nor the prompt says which is the set. Each
stage is skipped when its output is there: the same command resumes.
`calibrate` judges each tune set against `calibrate.naive_stack` of itself.

Proves it when: `calibrate` names the set on every dimension of every verdict;
the dry run writes a record with two verdicts and a report; a real design's log
says `real sets: holding out <set>` once it searched the index; every
`judged/*.json` lists all six pictures in `looked_at`; and the report's two
orders agree on most dimensions with the model shown first winning near half
(2026-10-16: 120 of 120 calibration verdicts named the set; m32's proof half,
24 of 24 verdicts with all six pictures, orders agreeing on 82%, the first
shown winning 42%; a design 5-24 minutes, a half about 80 minutes on two
workers after the `heavy` queue; on the GPU with audits later, 2026-10-16's
technique round started each half at once at load 45-75, its workers in one lease,
and a half of ten took 45-55 minutes on two or three workers).

### The check by real shapes

```sh
godot --headless --path . --script src/dev/exact_probe.gd        # one case a pair kind BrickBench refused, and builds that are right
godot --headless --path . --script src/dev/exact_cost_probe.gd   # station (535) and Orthanc (9,427): as standing, an edit, a whole design
godot --headless --path . --script src/dev/exact_dump.gd -- --out=F.jsonl A.mpd B.mpd   # pairs and pieces, to set beside verify.py
```

Needs `assets/generated/exact/` (`tools/build_exact.py`, in features/pipeline.md);
without it `exact_probe` says SKIPPED. The shapes must be built by `read_obj` as
it is since 2026-10-15 (each collider group the vertices its faces use, shared
or not): built before, 679 of 3033's 785 pieces lost corners and a flame 1.27 LDU
into a tipped lid read as clear. Proves it when: `exact_probe` ends "29
passed, 0 failed" (on the code before it, fb64132, 4 of its first 21 passed and 17
failed: every pair kind came back "buildable"; the 22nd is model-010's head in a
breastplate; the 23rd to 25th are the attach round's three that our check let
through and verify.py refused — a body over its shoes' heels that tips, a can lying
on its side that rolls, the flame against the lid — each confirmed by BrickBench's
own simulation or colliders on the case itself); `exact_dump` on the BrickBench builds lists
verify.py's own pairs and pieces (2026-10-14: identical on all twenty);
`exact_cost_probe` says an edit to Orthanc spends under 3 s in the exact check
(182 ms on 2026-10-14, at a load of 37; a whole new design of it 9.7 s, on a worker); and the connection audit over the sample
(every 25th OMR file) keeps floating where it was and overlapping pairs no higher
(2026-10-14: 7,511 overlapping pairs to 3,386 on the morning's code, 6,678 floating
either way; on main 7970de9, 8,188 to 3,845, 1,698 floating either way; to compare,
run it once with `assets/generated` pointed at a copy without `exact/`).
`clutch`, `joints`, `section`, `axle`, `techniques`, `patterns`, `rooms` and
`creative` assert what the shapes say where the lattice forgave: a part 2-8 LDU off
seated, a tilting hinge folded into its base refused as the hinge, a pin's collar at
the hole's mouth, five worked constructions withdrawn (`Techniques.WITHDRAWN`);
and where real sets hold: a wheel drawn spun 16 degrees on its axle passes (turned
on its axle, `ExactCheck.turned_on_axle`), the log pile's logs rest in their
grooves. A part resting on nothing that joins it passes only square to gravity
with its weight a LDU inside its support (`ExactCheck.rests`): held-out model-011's
steering wheel on a brick's edge and model-017's leaning flower, both of which fell
in verify.py, are refused. In a browser (`tools/web/freeze_check.mjs`, the shapes
fetched, not packed) check_design's own longest frame stays under 500 ms on the
Falcon: 7,530 ms before the shapes were asked for once a part, 313 ms after.

### Placing by connectors

```sh
godot --headless --path . --script src/dev/by_connector_probe.gd                 # each joint kind against BrickAgent's own poses
godot --headless --path . --script src/dev/by_connector_probe.gd -- --out=DIR    # ...and each case as DIR/<case>.ldr
godot --headless --path . --script src/dev/techniques_probe.gd                   # the six "figures and joints" build
```

Needs `assets/generated/exact/`; without it the probe says SKIPPED. Proves it when
`by_connector_probe` ends "43 passed, 0 failed": a brick on a stud, a round plate on
a side stud, a bar in a clip, a ball, a hinge, an axle and a twelve-part posed
minifigure (legs, hips, torso, arms, hands, head on its neck, hat, an axe in a hand)
each land within 0.001 LDU of where brickagent's `placement()` (b3df55e) puts them,
joined by BrickNet's labels, clear by its colliders and passed by the check; the
hinge folded the way it does not open is refused as the hinge, as BrickAgent's check
refuses it; through submit_design and edit_model a part attaches to a part named in
an earlier call and to a brick by number, a later edit passes with the posed arms
standing, and read back every attached part is written where it stands; what cannot
be done is refused saying why, with the pairs that do mate (a bar asked into a round brick's hollow stud is told of the clip at the same spot). On the code before it (7740d22) all 43 fail:
every part lands at 0, 0, 0. The `--out` files, exported by `brickbench.py`'s
`export_one` and checked by BrickBench's own `verify.py`, are valid where the
connector probe says so (scratch `verify_probe.py` in the 2026-10-15 run;
docs/BRICKBENCH.md). The poses BrickAgent printed come from its own `attach` in the
BrickBench venv, `python -I`, BRICKNET_DATA set; to make more, call
`brickagent.Assembly.attach` the same way and print `parts(model)`.

### Figures on joints

```sh
godot --headless --path . --script src/dev/figure_joints_probe.gd    # what a figure, a creature and a tower are told, where
godot --headless --path . --script src/dev/techniques_probe.gd       # "jointed figure" and "jointed animal" build
```

Proves it when `figure_joints_probe` ends "0 failed": the subject is read by its
words (a statue, a balloon-dog, a toilet's human head, a chair with eyes, he and
she; not a whale-tail spoiler, a dollhouse, a clock face, a crane's arm, a toy
car, nor the bench's Porsche "at minifigure scale" and fire engine "with a
firefighter", which were told in every check before vehicles were left out); check_design on a statue stacked square leads its advice with each joint's
call and an attach written out, twice in full and then a line, and says nothing
of joints once an arm is on a clip, nor for a lighthouse; with no brief, the
subject plan_scale was asked about is read; a dragon's advice names "jointed
animal" and not the shape pattern for its body, a bonsai's is still a living
thing's; plan_scale offers a statue of a man the posed minifigure and the
armature, a dragon at a scale its joints, a lighthouse nothing; search_parts
names 63868, 60478, 14418 and 44301a under "robot arm" and a balloon dog's first
search, not its second nor a lighthouse's; read_guide "shapes" is led for the
statue and unchanged for the lighthouse, and its description names "figures";
submit_design sends the stacked statue back once, with the figure pattern written
out for it, and builds it when it comes again as it was; the review of the stacked
statue names its left and right arms stiff, of the posed one nothing. On merge29 (5c4708e) it does not load (no `Style.character_of`),
and no reply in that arm's 28 bench sessions told of joints. The techniques probe
builds both armatures by the check, and BrickBench's verify.py passes them
exported, with the figure's right arm raised too (2026-10-15).

### Characters laid on joints (the figure pattern)

```sh
godot --headless --path . --script src/dev/armature_probe.gd                 # each kind laid, each joint turned, held, and the refusal
godot --headless --path . --script src/dev/armature_probe.gd -- --out=DIR    # ...and each kind as DIR/<kind>.ldr, for verify.py
```

Needs `assets/generated/exact/`; without it the probe says SKIPPED. Proves it when it
ends "0 failed": `{"pattern": "figure"}` lays a person (30 and 42 plates, and seated),
an animal (6 and 8 studs) and a head on a neck, every part said by its connectors on
them, named to build on, joined to what it went on by BrickNet's labels, clear of
every other by 1 LDU and passed by the check on a bare floor; each arm pose word
(down, bent, forward, raised, out) at both sizes is joined and passed, its hand where
the word says against the shoulder and its upper arm turned on its ball; the head
turns on its jumper by the degrees said, an animal's head nods and looks aside on its
ball neck and its tail swings 60 degrees on its bar, the part it is on unmoved;
submitted, a later edit leaves every posed part where it stood, and an arm raised and
a head turned again by an edit (parts off, put on again by the names standing) stand
where that pose puts them; a statue stacked square is sent back once with a person's
entry that builds as it is, built when it comes again, and not sent back a second
time; a balloon dog is sent back with an animal's; a fire engine with a firefighter,
a Porsche at minifigure scale and a lighthouse never are; and with no brief (the
connector), a lighthouse checked after a statue was built and the model cleared is
told nothing of joints. Before a fresh brief or a cleared model forgot the last
design's name (armature, 2026-10-16), the balloon dog was handed a person's entry and
the three vehicles and the tower were sent back: the statue's name, kept as the brief,
made each of them a figure. Four scenes of the real-set test, as their sessions named
and described them (Scorpion Pyramid with its statues, Micro World - The End with its
dragon, Jungle River with its crocodile, Dino Explorer twice with its baby T-rex), are
never sent back, and the bench's characters (model-043, 044, 049, 078, 080, as their
sessions named them) still are, once; the potato toy (042), a thing with a face, never
was. Before `Style.in_a_scene` (m35) each of the four was sent back.

### BrickBench: the designer on an outside ruler

`tools/bench/brickbench.py` puts the designer on BrickBench's Model setting
(https://github.com/kulits/BrickAgent, MIT), locally; `docs/BRICKBENCH.md` is
the write-up. Their code and their builds are untrusted: keep them in a scratch
folder, never in the repo, and run their Python with `-I`, paths as arguments.

```sh
S=<a scratch folder>
git clone https://github.com/kulits/BrickAgent $S/upstream           # b3df55e on 2026-10-14
uv venv -p 3.12 $S/venv && VIRTUAL_ENV=$S/venv uv pip install pybullet $S/upstream
#   the colliders (1 GB): curl bricknet/__main__.py's COLLIDER_URL into $S/download/,
#   then tarfile.extractall(..., filter="data") into $S/bricknet_data/cvx
python3 tools/bench/brickbench.py prompts --upstream $S/upstream    # model-001..010, briefs
python3 tools/bench/brickbench.py parts --upstream $S/upstream      # bricknet_parts.txt, 14,441
XDG_DATA_HOME=$S/xdg ~/.claude/claude-core/bin/heavy env -u ANTHROPIC_API_KEY \
    python3 tools/bench/brickbench.py design --jobs 2               # two at a time, 45 min each at most
python3 tools/bench/brickbench.py export --python $S/venv/bin/python
BRICKNET_DATA=$S/bricknet_data ~/.claude/claude-core/bin/heavy python3 tools/bench/brickbench.py verify --upstream $S/upstream --python $S/venv/bin/python
python3 tools/bench/brickbench.py zip --upstream $S/upstream        # submission.zip; NEVER submitted
python3 tools/bench/brickbench.py fetch                             # their Opus 5.5 builds; never committed
XDG_DATA_HOME=$S/xdg python3 tools/bench/brickbench.py views        # four views each, on the GPU
XDG_DATA_HOME=$S/xdg ~/.claude/claude-core/bin/heavy python3 tools/bench/brickbench.py views --software --jobs 2   # or on lavapipe
env -u ANTHROPIC_API_KEY python3 tools/bench/brickbench.py pairs --repeat 2 --jobs 3
python3 tools/bench/brickbench.py report                            # the tables BRICKBENCH.md quotes
godot --headless --path . --script src/dev/parts_only_probe.gd      # the allowlist, and nothing without it
godot --headless --path . --script src/dev/parts_only_probe.gd -- --parts-only=bench/results/brickbench-<date>/bricknet_parts.txt
python3 tools/minitest.py tests/test_brickbench.py                  # the export round-trips, the reads, the ELO
```

A controlled comparison of two arms on held-out prompts (each arm the app of
one checkout; an earlier commit's arm runs from `git archive` of it extracted
into a scratch folder, with `assets/generated`, `vendor` and `node_modules`
linked and `godot --headless --import` run there once):

```sh
D=2026-10-14-held
python3 tools/bench/brickbench.py prompts --upstream $S/upstream --start 21 --date $D   # model-021..030
python3 tools/bench/brickbench.py parts --upstream $S/upstream --date $D
python3 tools/bench/brickbench.py fetch --date $D
XDG_DATA_HOME=$S/xdg-full ~/.claude/claude-core/bin/heavy env -u ANTHROPIC_API_KEY \
    python3 tools/bench/brickbench.py design --date $D --arm full --runs 2 --jobs 2 --app $S/base-app
#   then the other arm the same way, --arm lean (--app this checkout, or its own export)
python3 tools/bench/brickbench.py export --date $D --arm full --runs 2 --python $S/venv/bin/python
BRICKNET_DATA=$S/bricknet_data ~/.claude/claude-core/bin/heavy python3 tools/bench/brickbench.py verify --date $D --arm full --runs 2 --upstream $S/upstream --python $S/venv/bin/python
XDG_DATA_HOME=$S/xdg ~/.claude/claude-core/bin/heavy python3 tools/bench/brickbench.py views --date $D --arms full,lean --runs 2 --software --jobs 2
env -u ANTHROPIC_API_KEY python3 tools/bench/brickbench.py pairs --date $D --arms full,lean --runs 2 --jobs 3
python3 tools/bench/brickbench.py compare --date $D --arms full,lean --runs 2   # compare.md
```

Its designs are under `arms/<arm>/<task>/run<n>/` (the design, `export.json`,
`submission/`), its views under `views/<arm>-run<n>/`. Proves it when every
design's log has the `parts only` line and its `design.json` the app's commit
(an export's says `"app"` and commit `?`: name the commit in the write-up), and
`compare.md` counts every verdict (each pair of designs, both orders).

Everything lands in the main checkout's `bench/results/brickbench-<date>/`
(git-ignored): `ours/<task>/` (run.py's design stage: `design.ldr`, the log,
`export.json`), `submission/<task>/` (`build.py`, `model.mpd`,
`verification.json`), `theirs/<task>/` (the gallery's files and their
`verification.json`), `views/`, `pairwise/<task>/judged/`, `submission.zip`,
`check_submission.txt`, `report.md`. Each design's log says
`parts only: 14441 parts (...)` once the flag took, and its last lines carry the
tokens by kind and Claude Code's own API price for them
(`tokens fresh=... api_usd=...`).

Proves it when: `verify.py` passes the ten gallery builds it published as valid
(it did, 2026-10-14), so a fault it names in ours is ours; every
`verification.json` has `mpd_geometry_reproduced: true` (the model.mpd is the
build's own); `check_submission.py` prints no `error:` line (it lists the 90
prompts not attempted as missing, which is expected); the probe prints its
`ok` lines with the flag and without; and `tests/test_brickbench.py` passes.
Their VQA and ELO need Gemma 4 31B in about 62 GB of GPU memory: not run here.

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
