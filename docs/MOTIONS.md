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
survives a round trip through other tools as text, and comes back:

    0 !BRICKWORKS MOTION "Open the dome" AFTER "" SECONDS 3
    0 !BRICKWORKS MOTION_TRACK "Open the dome" JOINT <ref> TURN
    0 !BRICKWORKS MOTION_KEY "Open the dome" <track> 0.0 0 EASE
    0 !BRICKWORKS MOTION_KEY "Open the dome" <track> 3.0 110 EASE
    0 !BRICKWORKS MOTION_DRIVER "Turn the crank" JOINT <ref> TURNS 3 SECONDS 4

A joint's **ref** must survive editing the rest of the model: the sub-assembly
name where the file gives one, else the moving body's lead part (its part
number, colour and place). When a ref no longer finds its joint (the part was
deleted), the motion says so by name ("Open the dome: its hinge is gone")
rather than doing nothing.

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
