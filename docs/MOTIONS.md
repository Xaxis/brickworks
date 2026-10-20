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

