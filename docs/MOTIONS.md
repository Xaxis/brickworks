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
  order they were made.
- A joint carried by another is moved alone while its slider is dragged
  (from where the model stands); its key, and the frames, carry it.
- Recording keeps one joint a drag; a chain drag and a ball are not recorded.

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
discovery_flow (48) through the same relay, as before.

Left for later:
- supabase/motions.sql is written and dry-run, not applied: until it is,
  a card says Playable's words, and a model published before it says its
  motions only once published again.
- A press works a motion's frames out at once (`MotionPlayer.play`): 713
  ms of a phone slowed four times for two gates over 2 s, one long frame.
  Worked out a few frames at a time it would not stall.
- The gallery's search does not find a model by its motions' names.
- A link plays one motion at a time: no Play all, no sequence (AFTER).
