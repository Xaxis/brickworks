# MCP walk 3: an observatory with motions (2026-10-20)

A real Claude Code session on the owner's subscription drove Brickworks
over MCP and nothing else, as the owner does (`claude -p` with only the
Brickworks server, `--strict-mcp-config`, no API key; one session
continued with `--resume`), building the owner's kind of model: an
observatory on a baseplate with a dome panel on hinges, a telescope slid
out on a rack turned by a wheel at the back, and two back wall panels that
swing open. Transcripts, pictures, the render and the scripts are in
`bench/results/mcpwalk3-2026-10-20/` (`s1`-`s5` the walk, `r1`-`r5` the
reruns on the fixed app). The session's model is
`tests/fixtures/mcpwalk3/observatory.ldr`, and `src/dev/mcp_walk3_probe.gd`
replays what it met.

## The model

Looked at in its pictures and its file: it is what was asked. Four 87375
quarter domes on a ring of 58846 corners, the +x quarter hung by its
bottom bar in two clips with its crown clip left off, so it swings out on
a real hinge (110°). A white telescope on a carriage riding a Technic axle,
two 3743 racks under the carriage, an 8 tooth gear meshing them on a 12L
axle that runs out through the back wall to a red wheel: a real rack and
pinion, which Grab drives (1.7 turns, 5.4 studs out). Two 60616b doors in
60596 frames on their hinges in the back wall. Tan walls with windows.

## The steps

1. **"Build me a small observatory..."** 104 calls, 20 min. Built it, and
   defined three motions unprompted. Met: a rack stood on its side against
   a gear in 14 checks that said nothing either way, after which it
   concluded "the app recognises a rack meshing a gear only when the rack
   lies flat" and slid the telescope level; move_part on a rack resting on
   a tile answered "It did not move: it is already there"; the shell dome
   pattern at 20 and 24 across overlapped its own crown dish (not fixed).
2. **"Give it motions..."** 17 turns. A one-motion "Extend the telescope"
   (dome track, then wheel track) stopped on the shut dome: tracks are
   tested as if the others stood still, and the session took it to mean
   the wheel turned too early. It made the show a chain of after=, with
   "Show it all" a copy of the doors' tracks at its head (no motion can
   name others to play).
3. **"Play each one, then backwards, render the show."** 41 turns, 249 s.
   Played backwards, the wheel "slides; a motion turns this joint" and
   move_part said "it is already there"; a door opened to 90° became "part
   of what stays". The session fixed both by trial (doors to 85°, the
   carriage moved a stud, 1.875 turns) and explained them wrongly ("the
   gear only keeps hold of the rack if the travel ends on a whole stud").
   The play pictures showed the telescope slid out through a shut dome.
   The render wrote into the real home folder (the walk's own setup: its
   downloads folder now points into scratch) and hid the back panels.
4. **"Turn the wheel: does the telescope slide out?"** Yes, through Grab,
   once the dome is open; the answer said only that the gear turned, so the
   session read the travel off a picture. Simulate (`simulate_mechanism`)
   today takes the carriage's axle as the driver, because its sub-assembly
   is called "telescope and drive", calls the wheel's axle free, and does
   not move the rack at all.
5. **"Save it, open it again, play the show."** The motions came back with
   the file. open_model, straight after save_model, said the model had
   changes that were not saved, and the session discarded them.

## What was fixed, before and after

| What | Before | After (rerun or probe) |
|---|---|---|
| A motion after another, checked | "stops at 101° ... meets the Windscreen Quarter Dome"; the session told the person to ignore the check | "Played once to check after "Show it all", then "Open the dome panel" ... clear all the way" |
| A wheel driving a rack | "#188 went from 0° to 612°" | "... and the Technic Gear Rack 1 x 4 (#160) slid 5.4 studs toward +x, and 26 parts with it"; r4 said "0.9 studs before its end tile hits the closed dome" and "the full 5.4 studs" with no picture |
| Two tracks that meet | stop words only | "(the part it meets is one #193 moves: a motion's joints are each tested as if the others stood still, so make that a motion of its own and this one after= it ...)" |
| A held loop, backwards | "it slides; a motion turns this joint", "It did not move: it is already there" | "it does not turn here ... what it turns is held: #150 would turn on its hinge in #151, but the studs of #150 grip the Plate 2 x 2 (#153) and the studs of #151 grip the Plate 2 x 2 (#153). A part moved to where its studs or holes meet another's is read as joined there ..." |
| A held door | "is part of what stays: the body of the Baseplate is the biggest of the model" | "..., and the studs of the Door (#13) grip the Brick 1 x 6 (#37)" |
| Step 3 as a whole | 41 turns, 249 s, wrong reasons | r3: 17 turns, 90 s: "After a part moves, the app treats its studs as clicking onto whatever they now touch, so it gets stuck where it ended up" |
| A sequence's picture | every frame at the end (telescope out through a shut dome) | each moment as it was (r5's sheet: 2 s shut, 4 s dome open, 8 s telescope out); a sequence's joint frame not drawn twice |
| A render | front corner only | view= (hero, front, side, back, low, top), and a line when what a motion moves is low behind the model |
| Saved under the session's name, opened | "has changes that are not saved" | r5 opened it at once (a file `save_file` wrote under another name counts as saved) |
| move_part's joint | "axle at x=16 y=6.7 z=14.5 studs", "a loop of 1 joints (1 axle), closed by 0 and a 8 tooth pinion" | "axle at x=16 z=14.5 studs, 16.75 plates up", "a loop of 1 joint (1 axle), closed by an 8 tooth pinion in rack 3743" |
| check_design with a rack | nothing | "brick 3 (8 tooth) is in the teeth of rack brick 1: a turn of it slides the rack 3.20 studs"; two plates high: "is beside rack brick 1 and not in its teeth: it meshes 16 LDU from where it stands, 2 plates down" |

`tools/probe.sh mcp_walk3_probe`: 20 of 20 pass; against the walk's
base (40c4ff2e, the frame check left out as it cannot load there) 13 of
its 17 fail. app_tools_probe, motions_probe, mcp_probe, read_only_probe
and mcp_walk_probe pass on it.

## Left, with the evidence

- **A moved joint fuses where it lands (engine, Bodies/Grab).** After a
  move the joints are read again from where the parts stand, so a part
  left with its studs in another's holes is joined there for good: the
  door at exactly 90° by its stud into the wall brick above (at 85° it is
  free), the carriage at 5.4 studs by the fixed bearing's studs in its
  plate. Grab let the plate slide sideways onto those studs ("clear all
  the way"). The answers now say so; the fix is for Grab: a joint the model
  was built with should survive a move, or a slide should not carry holes
  sideways onto studs (`repro` in the results folder prints each join).
- **A motion made of motions (motions unit).** The owner's "one that
  shows it all in order" can only be a chain's head that is itself a
  motion: the session copied the doors' tracks into "Show it all", and
  "Open the dome panel" played with sequence=true now opens the doors too.
  A motion that names others to play in order would need a file line.
- **Tracks tested apart (motions unit).** Said now, and pointed at after=;
  a dome and a telescope in one motion still cannot be tested together.
- **Simulate and racks (mechverify).** As in step 4: the driver chosen by
  the word "drive" in a sub-assembly's name, the wheel's axle called free,
  the rack not moved.
- **play_motion's picture is always from the front corner** (PosePanel's
  draw_stills, motions2's file): the back panels never show in it.
- **The shell dome pattern** at 20 and 24 across lays its 50990b crown on
  plates whose studs it overlaps by 1.1 LDU, not held (`check_design`,
  step 1 calls 8 and 9).
- **Part names in the catalogue are double-encoded** ("Curve 90Â°"; 11
  names with Â°, 180 with Ã¤): the pipeline reads LDraw files as Latin-1.
  Needs the catalogue regenerated, which is not this unit's.
