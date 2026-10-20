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
| Two tracks that meet | stop words only | "(what it meets is moved by #193, another joint of this motion: a motion's joints are each tested as if the others stood still, so make that a motion of its own and this one after= it ...)" |
| A held loop, backwards | "it slides; a motion turns this joint", "It did not move: it is already there" | "it does not turn here ... what it turns is held: #150 would turn on its hinge in #151, but the studs of #150 grip the Plate 2 x 2 (#153) and the studs of #151 grip the Plate 2 x 2 (#153). A part moved to where its studs or holes meet another's is read as joined there ..." |
| A held door | "is part of what stays: the body of the Baseplate is the biggest of the model" | "..., and the studs of the Door (#13) grip the Brick 1 x 6 (#37)" |
| Step 3 as a whole | 41 turns, 249 s, wrong reasons | r3: 17 turns, 90 s: "After a part moves, the app treats its studs as clicking onto whatever they now touch, so it gets stuck where it ended up" |
| A sequence's picture | every frame at the end (telescope out through a shut dome) | each moment as it was (r5's sheet: 2 s shut, 4 s dome open, 8 s telescope out); a sequence's joint frame not drawn twice |
| A render | front corner only | view= (hero, front, side, back, low, top), and a line when what a motion moves is low behind the model |
| Saved under the session's name, opened | "has changes that are not saved" | r5 opened it at once (a file `save_file` wrote under another name counts as saved) |
| move_part's joint | "axle at x=16 y=6.7 z=14.5 studs", "a loop of 1 joints (1 axle), closed by 0 and a 8 tooth pinion" | "axle at x=16 z=14.5 studs, 16.8 plates up", "a loop of 1 joint (1 axle), closed by an 8 tooth pinion in rack 3743" |
| check_design with a rack | nothing | "brick 3 (8 tooth) is in the teeth of rack brick 1: a turn of it slides the rack 3.20 studs"; two plates high: "is beside rack brick 1 and not in its teeth: it meshes 16 LDU from where it stands, 2 plates down" |
| Step 1 as a whole | 104 calls, 1174 s; 14 checks on the rack, then "only when the rack lies flat" | r1: 60 calls, 894 s; one check ("brick 2 (8 tooth) is in the teeth of rack brick 1 ..."), then "Rack base + 2.75 plates = pinion centre ... exactly my plan"; telescope out 6.1 studs |
| A turned door | "Moved 1 part: turned -100°", and r1 spent 18 calls on four views to find which way its doors had gone | "Moved 1 part: turned -90° (asked -90°); its middle went 2.2 studs toward +x, out from the model" (its middle, not its origin, which is on the hinge) |

`tools/probe.sh mcp_walk3_probe`: 20 of 20 pass; against the walk's
base (40c4ff2e, the three frame checks left out as they cannot load
there, and before the door's way was added) 13 of its 16 fail. Live on the fixed app,
r1's back doors rendered from the hero view say "moves parts on the far
side of the model from this view, hardly seen: render_motion view="back"
faces them", and from the back they show (`live_after_*`). app_tools_probe, motions_probe, mcp_probe, read_only_probe
and mcp_walk_probe pass on it (103, 70, 73, 34 and 33 checks), and so do
what featuremap affected lists: mcp_sync_probe, responsive_probe,
section_probe, rules_probe, reference_probe and grab_probe's survey of
4096-1.

## Left, with the evidence

- **A slide passes through a bearing (Grab), and what it leaves fuses
  (Bodies).** `Grab._chosen` (src/assembly/grab.gd, the loop over
  `bodies.touching` after `skip = moving.duplicate()`) puts both halves of
  every joint between a moving body and what stays into `skip`, so when
  the loop moves the axle, the bearings it turns in (#147, #151) are
  skipped for every moving part. The carriage's own Technic brick #150 then
  slid into bearing #151: move_part #149 along=6 put both at (20.5, 4.8,
  15) studs, "slid 6 studs (asked 6 studs)"; the wheel's 612° left them
  0.44 studs into each other, "clear all the way". The bearing should be
  forgiven only for the axle in it, not for everything that moves. After
  the move the joints are read again where the parts stand, so a part
  left with its studs in another's holes is joined there: the carriage's
  plate on the bearing's studs, and a door at exactly 90° by its stud in the
  wall brick above (at 85° it is free). A joint the model was built with
  should survive a move. Both need Grab's sweeps to prove; the answers now
  say what holds the part and how to get it back. The repro prints each
  join (`bench/results/mcpwalk3-2026-10-20/repro/`).
- **A carriage on two axles is read as hinged on one.** r1's carriage hung
  on two parallel axles; pose_model listed "telescope and slide, on its
  hinge", and list_motions suggested "Lift the boom", which the second
  axle forbids (the session left it out).
- r1 built its back doors standing open in their frames, so its "Open the
  back doors" closes them; the way a turn goes is now said, which shows it.
- **A motion made of motions (motions unit).** The owner's "one that
  shows it all in order" can only be a chain's head that is itself a
  motion: the session copied the doors' tracks into "Show it all", and
  "Open the dome panel" played with sequence=true now opens the doors too.
  A motion that names others to play in order would need a file line
  (motions unit 5: a SEQUENCE line, docs/MOTIONS.md).
- **Tracks tested apart (motions unit).** Said now, and pointed at after=;
  a dome and a telescope in one motion still cannot be tested together.
- **Simulate and racks (mechverify).** As in step 4: the driver chosen by
  the word "drive" in a sub-assembly's name, the wheel's axle called free,
  the rack not moved.
- **play_motion's picture is always from the front corner** (PosePanel's
  draw_stills, motions2's file): the back panels never show in it (motions
  unit 5: from the view that sees most of what moves).
- **The shell dome pattern** at 20 and 24 across lays its 50990b crown on
  plates whose studs it overlaps by 1.1 LDU, not held (`check_design`,
  step 1 calls 8 and 9).
- **Part names in the catalogue are double-encoded** ("Curve 90Â°"; 11
  names with Â°, 180 with Ã¤): the pipeline reads LDraw files as Latin-1.
  Needs the catalogue regenerated, which is not this unit's.
