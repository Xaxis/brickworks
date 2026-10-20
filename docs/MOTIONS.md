# Motions: a model's own named movements

The owner (2026-10-20): "for simulations there should be a way to define
simulations... for my observatory one might be 'open dome panel' and another
'extend telescope' and another 'open back wall panels'." For every model, not
one.

A **motion** is a named, saved movement of a model's real joints: *Open the
dome*, *Extend the telescope*, *Open the back wall*, *Steer left*, *Lift the
boom*. A model carries its motions in its file, and they work the same in the
window, on a shared link, in the gallery, in renders and over MCP.

This replaces four ideas of what moves with one (docs/ANIMATION.md, "Four
notions of what moves"): Pose's sub-assemblies, Grab's bodies, Simulate's gear
trains and the link card's moves. **Grab's bodies are the one model**: their
joints, stops, loops, gear and rack couplings, sliders and friction are what a
motion moves, and playing a motion runs through Grab's solver.

## What a motion is

- A **name**, said the way a builder says it ("Open the dome").
- One or more **tracks**. A track is one joint as Grab reads it (a hinge, a
  turntable, a slider, a ball, a gear's axle) with **keys**: a time, a place
  (degrees turned, or studs slid, from where the model was built, 0 = as
  built), and how it gets there (eased, linear or held).
- Optionally a **driver** instead of keys: "turn the crank 3 times in 4 s".
  Whatever the driver moves through gears, racks and linkages moves with it,
  as Grab couples it (a wheel on a pinion slides its rack).
- Optionally **after**: the motion it follows, so a sequence ("Show the
  observatory": dome, then telescope, then wall) is motions in order.

Playing a motion is a test too. It moves through Grab's solver, so a joint
stops where it meets something, and the motion says so and where: "the dome
panel stops at 86°, where it meets the telescope's tube". A motion that runs
clear says that as well.

## Where it lives in the file

In the main model, as LDraw meta lines like the floor's (`0 !BRICKWORKS
FLOOR ...`). LDraw and Studio ignore lines they do not know, so a motion
survives a round trip through other tools as text, and comes back. As unit 1
wrote them (`src/assembly/motions.gd`):

    0 !BRICKWORKS MOTION "Open the dome" AFTER "" SECONDS 3
    0 !BRICKWORKS MOTION_TRACK "Open the dome" 1 TURN AT 0 JOINT ASSEMBLY "Dome Panel"
    0 !BRICKWORKS MOTION_KEY "Open the dome" 1 0 0 EASE
    0 !BRICKWORKS MOTION_KEY "Open the dome" 1 3 110 EASE
    0 !BRICKWORKS MOTION_TRACK "Extend the telescope" 1 SLIDE AT 0 JOINT PART 3705 0 40 -96 12
    0 !BRICKWORKS MOTION_DRIVER "Turn the crank" TURNS 3 SECONDS 4 AT 0 JOINT PART 4185 71 0 -40 60

- A track's lines carry its number in its motion, `TURN` (degrees) or
  `SLIDE` (studs), `AT`, and its joint's ref last. A key is `time place how`,
  how being `EASE` (the monotone cubic Pose's keys use), `LINEAR` or `HOLD`
  (where the key before left it, until this key's moment).
- `AT` is where the joint stood from where the model was built when the file
  was written. A model saved with its doors open (the autosave writes it a
  moment after play_motion) says `AT 90`, so "Open the doors" played again
  opens them no further and played backwards closes them. A joint is measured
  as Grab.from_built measures it, against the part across the joint, from
  where the parts stood when the file was read.
- A ref is `ASSEMBLY "name"` where taking the sub-assembly whole moves the
  same parts on the same joint, else `PART number colour x y z`: the part
  the motion takes hold of, its place in the whole model in LDraw's
  coordinates (LDU), written where it stands each time. A ref that finds
  nothing is said by name, "Open the doors: its joint is gone: no Container
  Cupboard 2 x 3 x 2 Door (4533, colour 15) where it was", and its lines stay
  in the file, so an undo that brings the part back brings the motion back.
- The lines go in the head of the main model, after the floor's line, and
  are written the same every time: numbers to at most two or three places,
  no trailing zeros. A line of the wrong shape is left out (`Motions.unread`).

## How a person makes one (the window)

The Pose & animate panel becomes the motions panel. It is the owner's ask, so
its controls may change, in the app's existing look:

1. **Suggested.** The panel lists what moves (Playable's words: doors,
   steering, boom, turntable) and offers each as a motion to keep: "Open the
   doors", one press.
2. **Record.** Name a motion, press Record, and drag the real parts with
   Grab: every drag is kept as keys at the times it happened, with Grab's
   stops and couplings. Stop. This is animating by moving the mechanism by
   hand, which keyframe tools cannot offer.
3. **By its joints.** A motion's tracks are listed, one row per joint, with a
   slider for where it goes (Pose's sliders are Grab's joints: the steering,
   the boom and the doors become sliders, and joints that cannot move are not
   offered). Keys on a simple per-track timeline, each eased, linear or held.
4. **Play, reverse, loop, play all.** Reverse closes what Play opened.

## Everywhere else

- **A shared link** shows the model's motions as buttons over the 3D view
  (Play on a link today moves what Playable finds; it plays the motions
  instead when the model has them).
- **The gallery card** says "Moves: open the dome, extend the telescope".
- **Render.** File > Render gains Animation beside Turntable: choose a motion
  or a sequence; quality, size, lighting and lens as for a still; camera "as I
  see it" or "framed on what moves" (framed on what the parts sweep, not their
  box). Files named `<model> <motion>.webp` and `.mp4`, numbered when taken.
- **MCP**, for Claude:
  - `list_motions`: each motion, its tracks, what it was last found to do.
  - `define_motion(name, tracks | driver, after)`: joints named as `move_part`
    names them ("#80", a sub-assembly), places from as built. Answers by
    playing it once and saying where each joint ended or stopped.
  - `play_motion(name, reverse)`: moves the model and reports, with a picture.
  - `render_motion(name)`: a WebP and MP4 as a job.
  - `animate_model` and `simulate_mechanism` become a motion defined and
    played once, so there is one path.
- **Simulate** runs a motion with a driver (the gear train turned from its
  crank), on Grab's model, so racks, linkages, sliders and friction all work
  in it (the mechverify unit, 2026-10-20).

## Order of work

1. **Engine, file and MCP** (motions1): the motion data on Grab's joints, the
   meta lines and refs, playing through Grab's solver with stops reported, the
   MCP tools, suggestions from what moves. A probe on real sets (a door, a
   steering rack, a crane boom, a gear-and-rack driver) that defines, saves,
   reloads, plays and reverses each.
2. **The window** (motions2): the panel as above, Record a drag, sliders on
   Grab's joints, play all.
3. **Links and gallery** (motions3): motion buttons, card words.
4. **Render** (motions4): File > Render > Animation of a motion.

## What unit 1 built (motions1, 2026-10-20)

No window interface: the engine, the file and the MCP tools.

- **The data** (`Motions`, `src/assembly/motions.gd`): motions, their
  tracks and keys, a driver, AFTER; the joints, each once, shared by the
  tracks of every motion on it; the lines above, read at the edge. Kept on
  the model (`BrickWorld.motions`) and changed only by a history step
  (`Builder`'s "motions": define and remove are each one undo step). Read
  as a file opens, written into every text the model is written as
  (`ModelStore._text_into`): a save, the autosave, an export, an .io, the
  text a shared link publishes. An edit elsewhere leaves them alone.
- **Playing** (`MotionPlayer`, `src/assembly/motion_player.gd`): each
  track's joint taken hold of as move_part takes it (`GrabDrag.held_of`),
  turned or slid to its keys a frame at a time, 12 a second. A joint stops
  where it meets the model, a loop goes as its loop allows, gears and racks
  follow, and the stop is said: "#143 stops at 0° of the 30° asked, where the
  Slope Brick Curved 2 x 2 x 0.667 (#566) meets the Bracket 5 x 2 x 1.333
  with Understud in Centre (#42)". A loop is turned 3° at a time at most:
  asked 11° in one step, 8808-1's steering loop drifted along its column's
  free slide, 1.28 LDU after turning 90° each way and back (0.001 at 3°).
  Two tracks on joints that carry each other are composed, the outer
  carrying the inner. Played to keep (play_motion), the model is left where
  the motion ends as one undo step; to look (define_motion's check, a
  render), nothing changes. What each motion was last found to do is kept
  for list_motions while the app runs.
- **A driver** turns its joint so many times from where it stands; played
  backwards it turns back as far as it last went forward, so 8841-1's
  steering wheel, stopped at 37° where a Technic Axle Pin (#17) meets a Tile
  1 x 2 with Groove (#11), comes back to where it began (else as many turns as it was given).
- **Suggested** (`MotionPlayer.suggest`, from Playable's words): "Open the
  door(s)", each door the way it has room, to 90° or its stop (a rail with
  less than 15° is no door); "Steer left and right", a steering wheel 90°
  and an arm 30° each way, or as far as both ways allow; "Lift the boom",
  the way its weight rises, to 45° or its stop; "Turn the turntable", once
  round or as far as each way goes; "Turn the gears" and "Drive the rack",
  a driver, once round in 4 s. Tried for room, nothing changed.
- **MCP** (`AppTools`): `list_motions`, `define_motion` (tracks, a driver,
  after, suggested=true keeps a suggestion, remove=true), `play_motion`
  (reverse, sequence, a picture of its frames), `render_motion` (a job: a
  WebP and an MP4 framed on what moves, through Render animation's own path,
  `PosePanel.render_poses`). `animate_model` keeps its interface and is now
  a motion defined and played once: its joints, Pose's and a part's, taken
  as a drag takes them.

Proof: `src/dev/motions_probe.gd` (`tools/probe.sh motions_probe`), on
1484-1's doors, 8808-1's steering, 4096-1's crane, 8841-1's chassis driven
from its steering wheel and 31070-1's windscreen, each defined over MCP,
saved as .mpd and opened again, played, reversed and rendered once; and an
.ldr of its own, an .io, the autosave and a shared link's text; files and
pictures in `bench/results/motions1-2026-10-20/`.

Left for later units, or for Grab:
- Tracks are tested each as if the others stood still: two doors that would
  meet each other are not tested against each other, and a joint carried by
  another is tested as if its carrier stood (the frames carry it).
- A ball joint is not a track (it would need a way to turn about).
- A motion begun where the last one stopped against a part with no exact
  shape passes through it: Grab forgives what a section overlaps where it
  starts (`Grab._pair_forgiven`), so a second drag does the same.
- Grab's loops drift along a free slide on a big single step: one grab of
  8808-1's steering wheel turned 90° and back, a step each, stands 0.14 LDU
  out, and 90°, -90° and back 0.97 (motions step 3° at a time; move_part
  turns in one step).
- 10220-1's camper doors are not read as doors by Playable, only its
  cupboard's inside, so its suggestion opens a door no picture shows
  (1484-1's gates and mailbox are the probe's doors).
- The window (unit 2), links and the gallery (unit 3), File > Render >
  Animation (unit 4).

## What unit 2 built (motions2, 2026-10-20)

The window: **Build, Motions…** (it was Pose and animate…). The name is
the panel's subject now: a builder looking for "open the dome" reads
Motions; "Pose" named the sliders of sub-assemblies, which are gone from it
(pose_model keeps them over MCP). The panel is `PosePanel`
(`src/ui/pose_panel.gd`), in the frame, fonts, buttons and sliders of its
neighbours (Simulate, Hidden colours), over the model's left edge.

- **The list.** The model's motions, a row each: its name (a radio: the one
  Render animation draws), Play, Play backwards, Edit. Play plays it through
  Grab (`MotionPlayer.play`, kept: one step), its frames drawn over the model
  12 a second (`BrickWorld.set_drawn`), and says what it found in unit 1's
  words: "Played "Open the doors": #122 went from 0° to -90°, clear all the
  way". Play backwards closes what Play opened. Play all plays every motion
  in order (`Motions.in_order`: each after the one it follows, the rest as
  listed), each from where the last left the model, one step. Loop plays it
  again until Stop.
- **Suggested from what moves.** `MotionPlayer.suggest`'s motions the model
  has not kept, each with Keep (one step), its joints and reach in its
  tooltip.
- **New motion and Record.** New motion opens the editor on a motion not yet
  kept, its name ready to type over. Record puts the Select tool in hand and
  listens: each Grab drag in the view (`GrabDrag.grab`) is sampled 30 times a
  second while held, measured from where its joint stood (the joint as a
  motion names it, `MotionPlayer.joint_named`, after the drag is kept, and
  its place `at_now` less the grab's turn), and thinned to the fewest keys
  within 2° or a tenth of a stud of it (Douglas-Peucker), with a key where
  the drag was kept (a swing or a settle after it). The clock starts at the
  first drag's press; pauses between drags stay. Grab's stops and couplings
  are the drag's own, and played again they are Grab's again (8808-1's
  steering wheel recorded turns both arms through the rack). Stop undoes the
  drags (when the history since Record holds only them), so the model is
  back where it stood, and keeps the motion as one step; a ball, or a chain
  dragged after holding still, is said and not recorded.
- **By its joints.** The editor: Name (renamed is one step, and a motion that
  followed it follows the new name), Remove (one step), Record, Play, Play
  backwards, At (the time: the model drawn as the motion has it then, played
  to look), then a slider for each joint: the motion's own, then what moves
  (`MotionPlayer.movable`: Playable's doors, steering, boom first, then the
  rest biggest first, five until Show all; a joint with no room to move 10°
  or half a stud either way, held as a motion holds it, is not offered). A
  slider moves its joint through Grab as it is dragged (`MotionPlayer.hold`,
  `step_to`) and, let go, puts a key at that time where the joint got to; the
  first key of a joint at a time past 0 puts one at 0 where it stood. Under
  each slider, its keys on a strip (`PosePanel.KeyStrip`): a key pressed is
  chosen (Eased, Linear or Held, or Remove key), dragged it moves in time; a
  press between keys sets the time there. A driver motion is said, not
  edited.
- **Render animation** draws the chosen motion (or the one in the editor)
  through `render_poses`, as render_motion does, 12 or 24 a second, 480 ×
  300 or 720p. Turn the model round once is not in the panel: File, Render
  has Turntable, and animate_model keeps turntable=.
- **One history.** Every change is a "motions" step. The panel reads the
  history each frame it is open (its depth and its newest step, an int and a
  reference), so an undo, a redo or a motion a session defines over MCP shows
  in it at once. Closed it does not process; open and idle it draws nothing.
  animate_model keeps its keys as the motion "Animation" (one step), so a
  session's animation is in the panel to play.

Proof: `src/dev/motions_panel_probe.gd` (`tools/probe.sh motions_panel_probe`,
and `PROBE_SIZE=1280x720` for the small window), clicks and drags as a
person: 1484-1's doors kept, played open and backwards shut (0 parts off); a
gate recorded from a 50° drag (4 to 6 keys over 0.7 to 0.9 s), the model put
back, one step, and played to where the drag left it (0 parts off); a key
made linear and one put by a slider, undone; Play all in order and its
undo; saved and opened again with the 37 lines byte for byte; a motion
defined over MCP in the open panel, and gone again on undo. 8808-1's
steering kept and played both ways through its rack; the wheel recorded
turns both arms when played; every joint offered moves, and the last one,
scrolled to, takes a key; Render animation drew the motion. 49 checks at
1400 × 900 and at 1280 × 720 (the editor, its joints found, open in 270
to 410 ms on 1484-1); pictures in `bench/results/motions2-2026-10-20/`.
With the panel open on 75969-1 (922 parts) in a browser, `cad_frames.mjs
--gate --motions` passed: an orbit's own work 39.8 ms at its 95th
percentile (of 200), select all 70 ms (of 400), Next at worst 28.5 ms (of
200). pose_probe, animation_probe,
mcp_walk_probe, flex_ui_probe and anim_walk_probe drive the panel in place
of Pose's sliders and keys; flex_pose_flow makes a crane's motion in a
browser.

Left for later units:
- AFTER is set over MCP only; the panel plays it, and lists motions in the
  order they were made. (Unit 5 retired AFTER for sequences.)
- A joint carried by another is moved alone while its slider is dragged
  (from where the model stands); its key, and the frames, carry it.
- Recording keeps one joint a drag; a chain drag and a ball are not recorded.

## What unit 4 built (motions4, 2026-10-20)

**File, Render… has Animation** beside Turntable, in the dialog's own look:
Render animation in the row of Render picture and Render turntable, and
under Turntable's frames an Animation heading with the motion to draw (the
model's motions as listed, then All, in order, `Motions.in_order`, when
there are two or more; "No motions yet: Build, Motions… makes them" and the
button off when there are none), the camera (As I see it, Framed on what
moves) and a line of what it comes to. Quality, size, background, light,
lens and depth of field are the picture's; the frames go at the turntable's
24 a second. Nothing else in the dialog moved.

- **One path** (`MotionRender`, `src/render/motion_render.gd`): the frames
  (`frames_of`: each motion played through Grab, a sequence each from where
  the last ended, kept while the next is played and taken back after with
  `Builder.take_back_to`, which puts the person's redo back as it was), and
  drawing them (`draw`, `StudioRender.animate`). The dialog's Animation, the
  Motions panel's Render animation (`PosePanel.render_poses`) and
  render_motion all go through it, and name their files the same way.
- **As I see it** is the camera the picture has (the dialog's Camera: the
  view you are looking at, unless another is chosen). **Framed on what
  moves** looks from the same side and fits the frame to the corners of
  every moving part in every frame (`MotionRender.swept`,
  `StudioRender._fit_points`, `RenderSettings.on_what_moves`), not to a
  box: a box's corners stand far off a boom rising on a diagonal, and that
  is what left unit 1's crane small. The sweep, the floor and the contact
  shadow are still laid under the whole model and what it sweeps, and the
  clip planes take in all of it. render_motion frames on what moves from
  three-quarters, as it said it did; the panel's Render animation draws as
  I see it.
- **Files** `<model> <motion>.webp` and `.mp4` and a folder of its frames
  (`RenderOutput.begin_animation`), "main Open the doors.webp", then "main
  Open the doors 2.webp" when that is taken; All, in order is "<model> all
  in order". In a browser the WebP downloads (the browser numbers its own).
  Stills and turntables keep their names (`model_render.png`,
  `model_turntable.webp`), written over as before.
- Progress on the dialog's bar, frame by frame; Cancel and Escape stop it
  and keep nothing; the finished frames loop in the dialog as a
  turntable's do.

Proof: `src/dev/motions_render_probe.gd` (`tools/probe.sh
motions_render_probe`, and `PROBE_SIZE=1280x720 … OUT_DIR pictures`), the
dialog pressed as a person presses it, 34 checks:
- 1484-1's "Open the doors" at 720p, Quick: 49 frames of 49 as I see it
  and framed on what moves, each a WebP of 49 frames, an MP4 and 49 PNGs,
  the second named "main Open the doors 2.webp" (1484-1.mpd's model is
  called main). What changes from the first frame to the last spans 13% ×
  12% of the frame as I see it and 41% × 47% framed on what moves. All, in
  order (with "Close the first gate" after it): 86 frames, the gate
  closing in the last of them (44,969 pixels differ from the doors open),
  the model as built and the redo kept. Cancel part way: "Cancelled.", no
  WebP.
- 4096-1's "Lift the boom" (45°) framed on what moves: the boom's sweep
  over 52% × 90% of the frame, against 47% × 63% framed as unit 1 framed
  it (the whole model's box with the sweep's, from three-quarters).
- One path: the dialog and the panel's Render animation (as I see it),
  and the dialog and render_motion (framed on what moves, three-quarters),
  for the same settings: the same camera and every moving part in the same
  place on the last frame, exactly; the pixels differ in 5,484 and 7,927
  places by at most 8 and 7 of 255, as the dialog drawing the same frames
  twice does (1,284 by 11; 7,927 by 5). StudioRender does not draw a frame
  twice bit for bit.
- The dialog at 1400 × 900 and 1280 × 720 with every Animation control in
  it; pictures in `bench/results/motions4-2026-10-20/`.

In a browser (`tools/web/render_flow.mjs`, `render` in
`tools/release/preview_checks.sh`, run on a local export): a small crane
opened from a file with a motion in its head, rendered from Animation
framed on what moves, downloaded "Crane motion Turn the turret.webp", 25
frames, decoded at 1280 × 720, in 23 s, the page's longest wait 1,084 ms;
the flow's 13 checks passed. render_probe (41), motions_probe (70),
motions_panel_probe (51), pose_probe (25) and animation_probe (24) pass.

Left for later:
- The draft in the dialog is the still; framed on what moves is seen only
  once rendered (the frames loop in the dialog then).
- The list of motions is read when the dialog opens and as a render
  starts: a motion a session defines while the dialog is open shows at
  the next.
- render_motion has no camera choice: it frames on what moves, from
  three-quarters.
## What unit 3 built (motions3, 2026-10-20)

Links, the gallery and a session, for a model that carries motions.

- **The link's buttons** (`ShareView`, `src/ui/share_view.gd`; main.gd's
  `_play_motion`). Once the viewer has read the model's joints (as Play
  does), a model with motions has a button for each in the play pill,
  under "Play its motions", in Reset's face, wrapping as the pill's words
  do, a fingertip tall on a phone: "Press one to play it, and again to put
  it back. Or drag a part that moves." (a touch screen: "Tap one…").
  Pressed, it plays through Grab as the Motions panel plays it
  (`MotionPlayer.play`, kept: one history step), its frames drawn over the
  model 12 a second (`BrickWorld.set_drawn`), the first at once, and the
  button stays lit (the pill's yellow) while the model stands where it
  ends: "“Open the gates” played. Press it again to put it back." Pressed
  again it plays backwards: "“Open the gates” put back." A joint that
  stops is said in a visitor's words, each part by its name
  ("stopped short: the Fence Gate 1 x 4 x 2 stops at 62°…", `_visitor_words`).
  Reset undoes every play's step, a drag's and a motion's alike, and puts
  every button out; Build it does the same first. Nothing is kept: the
  store is read-only, as for a drag. A drag still moves a part. A model
  without motions keeps Play as it was. What the last press played is told
  to the page (`brickworksShare.motion`: its joints from and to, frames,
  the press's own ms); `brickworksShare.view.play` has `motions` and
  `motions_out`; the buttons are `view_motion_1`… in `brickworksControls`.
- **The card and the page** (`api/_directory.js` `motionsIn`, `motionsOf`,
  `movesWords`; `api/share.js` `keepMoves`, the page's facts;
  `web/cards.js` `motionWords`). The server reads the names from the very
  text published, as the app reads them (a motion that moves something,
  each name once whatever its case, at most 12 of 60 characters), so any
  app that writes the lines gets the card. Kept with the model's row
  (`supabase/motions.sql`: `shared_models.motions`, `motion_names_ok`,
  `directory_card` with `motions`), in the same request as the words
  Playable found. The card says "Moves: open the dome, extend the
  telescope" (each begun in lower case when it begins with a plain word,
  three and "and N more"), the page all of them in its facts; a model
  without motions says Playable's words, on its page too now. Until
  motions.sql is applied the request with the names fails, the words are
  kept alone, the publish answers `motions: null`, and the card says the
  words: nothing else changes.
- **A session** (`GalleryTool`, `AppTools`). A gallery list's line says
  `motions: "Open the gates", "Open the mailbox"`; `gallery open=` reads
  them from the file: `Its motions (2): "Open the gates" (2 s, 2 joints),
  "Open the mailbox" (1 s, 1 joint).`, and how to play one (`open_model
  link=`, then `play_motion name=`). `open_model` says the same of
  whatever it opened, so a session that opens a model knows its motions'
  names without asking `list_motions`.

A first press can come before the parts' exact shapes have arrived (the
web build fetches each as a check first asks for it). Judged by the parts'
covers, "Open the gates" stopped one gate at 6° of 90°, where it met the
mailbox's box, on the local relay; with the shapes it opens clear. So once
the motions are offered every part's shape is asked for (eight a frame),
and a press waits, saying "Getting “Open the gates” ready…", until they are
here, or ten seconds, and until the grab has come to rest: a press during
a settle had done nothing at all.

Proof: `tools/probe.sh share_play_probe` (66 checks, its section 8 on
1484-1 with `tests/fixtures/motions/1484-1.motions` written into it): the
two buttons; Open the gates pressed by the mouse, its frames drawn (2 parts
moving, 1.9 s), both gates at 90.0°, the mailbox still, the button lit;
Open the mailbox at 90.0°; the gates pressed again back where they were
built (0 off); Reset, every part as built; nothing published or written; a
press 50 to 93 ms of one frame on this machine (load 30 to 42).
`tools/web/play_flow.mjs --publish` through the local relay
(`relay_server.mjs --static=build/web`, the live database, a throwaway
account deleted after): at 1280 by the mouse and at 390 by a finger with
the CPU slowed four times, each button inside the page and clear of the
view cube (34 px tall on the phone), each motion played (the gates 0° to
-90°, the mailbox 0° to 90°, `brickworksShare.motion`), lit, the gates taken back to 0°, Reset,
the link's text unchanged; the press's own work 180 ms (laptop) and 713 ms
(phone, slowed) for the gates' 25 frames, 44 and 171 ms for the mailbox's
13; the first press waited 12.4 s and 10.1 s for the shapes at a load of
40. The house's page says "Moves: doors" until motions.sql is applied (its
publish answered `motions: null`), at both sizes, light and dark; the
gallery's page from the checkout says "Moves: open the dome, extend the
telescope, open the back wall panels and 1 more" of a card with four.
`gallery_tool_probe -- --played` (37 checks): a list's line and `open=`
name them, `open_model link=` names them, and `play_motion` plays "Open
the gates" by that name (both gates 90°). The SQL: `tools/apply_sql.mjs
supabase/motions.sql --dry --try=tools/motions_try.sql` and
`tools/sql_compare.mjs supabase/motions.sql motions` (17 of 17 the same),
`tests/test_motions.py`. share_view_probe (173), share_flow (49) and
discovery_flow (48) through the same relay, as before. The viewer's frame
gate, play_flow's racer drag on the phone slowed four times, is the box's
at a load of 26 to 47 on 24 cores: the build before this (rel-m115's) 64.3
and 20.9 ms at worst, this one 15.1 and 44.2, in turn (held to 33 ms; 7.5
on the laptop). What runs a frame here is three checks of empty lists
until a motion plays.

Left for later:
- supabase/motions.sql is written and dry-run, not applied: until it is,
  a card says Playable's words, and a model published before it says its
  motions only once published again.
- A press works a motion's frames out at once (`MotionPlayer.play`): 713
  ms of a phone slowed four times for two gates over 2 s, one long frame.
  Worked out a few frames at a time it would not stall. (Unit 5: a slice a frame.)
- The gallery's search does not find a model by its motions' names.
- A link plays one motion at a time: no Play all, no sequence (AFTER).
  (Unit 5: a sequence is a button.)

## What unit 5 built (motions5, 2026-10-20)

The owner asked for "open dome panel", "extend telescope" and "open back
wall panels" on their observatory, and a real session (docs/MCP_WALK3.md)
for "one that shows it all in order". It could not: it copied the back
wall's tracks into a motion called "Show it all" and set "Open the dome
panel" AFTER it.

- **A sequence** is a motion made of motions, by name, in order, saved as
  one line:

      0 !BRICKWORKS MOTION "Show it all" SEQUENCE "Open the dome panel" "Extend the telescope" "Open the back wall panels"

  read at the edge like the rest (`Motions._read_motion`; a sequence with
  no names is left out). Played, each motion begins where the one before
  left the model; backwards, they go in reverse order, each backwards
  (`Motions.played_by`, `flat`; `MotionPlayer.play_in_order`, one step).
  A sequence may name another; one that would play itself inside itself
  is refused. A name the model has no motion of is kept in the line and
  said ("the model has no motion "Extend the telescope": passed over"),
  so an undo that brings the motion back brings it back into the play; a
  rename in the panel renames it in every sequence. Rendered whole
  (`MotionRender.frames_of` plays a sequence through, `whole_frames`), as
  "<model> Show it all.webp". An older app reads the line as one of the
  wrong shape and leaves it out. The card (`api/_directory.js`
  `motionsIn`) lists the motions that move something, so a sequence is
  not on it: its motions are.
- **AFTER is retired in favour of sequences.** A chain names its order
  only through its members, so a motion could follow one other and be in
  one chain; the chain had no name to play, render or press on a link; and
  it changed what its members did (played with sequence=true, the walk's
  "Open the dome panel" opened the doors first). A sequence is a name for
  an order: each of its motions still plays alone, and may be in many.
  Files with AFTER lines read and write them as before, byte for byte;
  Play all, Render's All, in order and play_motion sequence=true still
  follow them, but a sequence is never in a chain, and nothing makes AFTER
  any more: the panel has no control for it, and define_motion's schema
  has sequence= in place of after= (a call with after= still keeps it).
- **The panel** (`PosePanel`): a sequence is a row like any motion (its
  tooltip says what it plays). New sequence, beside New motion, keeps one
  of every motion in Play all's order, named "Show it all", one step, and
  opens its editor: Name, Remove, Play, Play backwards, then "It plays, in
  order", a row for each motion with Up, Down and Take out, and Add with
  the model's motions to choose from. Each change is one step. Play all and
  a sequence's Play draw every frame with every part (`whole_frames`):
  drawn on the model as it ends, a motion's frames had shown a later one's
  parts where they end. The last render's frame of another model is no
  longer shown when the panel opens on this one.
- **MCP**: `define_motion {"name": "Show it all", "sequence": [...]}` keeps
  it and plays it once to check, each from where the one before left the
  model, then puts the model back; list_motions shows `"Show it all", 8 s,
  a sequence: "Open the dome panel", then "Extend the telescope", then
  "Open the back wall panels"`; play_motion and render_motion take it like
  any motion. A track stopped on a part another track of its motion moves
  is now pointed at a sequence, not after=.
- **A link**: a sequence is a button like any motion; pressed, its motions
  play in order, lit; again, backwards in reverse order.
- **play_motion's picture from where what moves is seen.** Without view=,
  the picture is from the view (StudioRender.VIEWS) that sees most of what
  the motion moves, and the answer says which: "from the back corner
  (view="back"), which sees 32% of what it moves (the front corner 2%)".
  `MotionRender.seen_from` takes each moving part's travel as each view
  sees it (across the picture, not towards it), at the first, middle and
  last frames, and marches the lattice from five points of the part toward
  the camera (`_clear`, the march `BrickLattice._march` makes), passing
  through what moves and through what the part stands in where it begins
  (a door's frame, whose opening the lattice fills); `best_view` keeps the
  front corner unless another sees 10 points more. Boxes would not do: a
  door frame's box hides its door from every side. It costs 8 to 28 ms on
  the observatory, and draws nothing.
- **A link's press is worked out a slice a frame** (`MotionPlayer.pace`,
  `pace_on`; `play` is `begin`, `advance`, `finish`): main gives it 40 ms of
  each frame (`MOTION_SLICE_MS`), a slice ending after the frame that passes
  it, and draws its frames once all are worked out. A drag taken up
  meanwhile drops it, and what it had kept is taken back.
  `brickworksShare.motion` has `ms` (all its work), `longest_ms` and
  `slices`.
