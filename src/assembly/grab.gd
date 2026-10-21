## A section of the model taken in hand and moved about its joint as the real
## thing moves: a wing on its hinge, a boom on its turntable, an arm on its
## shoulder with the hand and what it holds, a gear and the train it drives.
##
## The owner (2026-10-17): a person "should be able to manipulate and move any
## hinging, moving, otherwise interactive part with perfect physics/support/
## structure simulation". What moves is read by [Bodies]: the grabbed part's
## rigid body and everything beyond it, turned on the one joint between it
## and the anchor (what stays: a locked part, what stands on the baseplate's
## studs, else the biggest body). Grabbing a joint's anchored half moves its other half.
##
## How it moves is the joint's:
##   turn   a hinge, a clip, a turntable, a pin or an axle, a round stud:
##          about its line; a click hinge stops on its clicks.
##   slide  a clip on a bar, a hole on an axle or a pin: along its line, as
##          far as the shaft reaches.
##   ball   about its middle, every way.
## Where it stops is the parts' own: the lattice says whether anything but
## what it is joined to is in the way, and the angle is bisected back to the
## last one with room ([method turn_to]), as Poser.settle does. Nothing is
## made up: a hinge with room to go all the way round does.
##
## Gears turn their train: a grabbed gear's body drives [Mechanism], and
## every gear it meshes turns by the tooth counts, as Simulate turns them.
## A closed loop (a four-bar, a crank and its rod) is held at both ends:
## phase P2 of docs/MECHANISMS.md, said rather than moved.
##
## Let go, a joint that holds by friction stays where it was put; one that
## does not (a pin without friction ridges, an axle in a round hole, a
## turntable on its side) swings down under its own weight to where its
## centre of mass is lowest, or to what stops it ([method settle]). The
## pose is one step to undo ([method commit]).
##
## Pure but for the lattice it asks: it changes nothing until [method
## commit], and the caller draws [member placed] (BrickWorld.set_drawn).
class_name Grab
extends RefCounted

## Bisection rounds for where a turn stops: 180° / 2^10 is under 0.2°.
const ROUNDS := 10
const BALL_ROUNDS := 6
## How long the press may spend finding parts that can never meet anything.
const NEVER_MEET_MS := 30
## Where a turn stops, to within this, degrees.
const STOP_TO := 0.15
## A move is tested along its way, not only where it ends (G13,
## docs/MECHANISMS.md §22): in steps that move no point of what moves more
## than this, LDU. Judged by exact shapes, which may overlap by 1 LDU, the end
## of a move is often clear where its way is not: a bogie turned 30° under its
## buffer beam was clear there and went through the beam to get there.
const PATH_LDU := 2.0
## And a turn's step is never more than this, degrees, nor less than the
## least: a boom 30 studs long steps a fifth of a degree.
const PATH_MOST_DEG := 3.0
const PATH_LEAST_DEG := 0.1
## A slide's least step, LDU.
const PATH_LEAST_LDU := 0.25
## A loop's way is tested in no more steps than this a move, and a drag's
## frame in two ([method _walk]).
const LOOP_MOST_STEPS := 6.0
## A part all within this of the joint's line turns inside the holes it is
## in, LDU: an axle or a pin, radius 4, on its own line.
const ON_THE_LINE := 6.5
## A part may sink this far below the floor the model stands on, LDU, as
## Balance lets a pose: half a plate.
const BELOW_FLOOR := 4.0
## A loop's driver is turned on a grid of this, degrees.
const LOOP_GRID := 0.25
## A loop with no more moving parts than this has what they overlap where
## they stand found at the press.
const LOOP_AHEAD_PARTS := 80
## Two parts whose turned boxes are into each other by no more than this
## only touch, LDU: under a cell of the cover, 0.4 mm.
const TOUCHING := 1.0
## A drag along a joint's line this much more than across it slides.
const SLIDE_BIAS := 1.6
## Degrees a pixel when the joint's plane is edge on to the eye.
const EDGE_ON_RATE := 0.5
## Below this the pointer's ray meets the plane a turn is in too slantwise
## to read an angle off it, and the turn drawn nearest the pointer is taken.
const EDGE_ON := 0.12
## Pixels a degree away from where it was weighs, edge on: enough to choose
## between a turn and its mirror, too little to hold it back.
const CONTINUITY := 0.15

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var bodies: Bodies

## What can be grabbed: "moves", "rigid" (nothing to turn on: carried as
## before), "loop" (held at both ends), "locked" (a geared train that
## locks). [member why] says it in words.
var state: String = ""
var why: String = ""
## For a part refused as rigid that has a joint its body holds still (an
## axle in a round hole whose halves something else holds as one), what
## holds it, part by part (Bodies.overruled_words); "" otherwise.
var held_by: String = ""
var part: int = 0
var body: int = 0
var link: Bodies.Link
var moving_bodies: Array = []
## Brick id -> true for every part that moves with it.
var moving: Dictionary = {}
## Brick id -> Transform3D where each stood when grabbed.
var rest: Dictionary = {}
## What the moving side may press against: itself, a hose, what a gear
## train turns with it.
var skip: Dictionary = {}
## What stays that the moving side is joined to, each with the moving parts
## across the joint from it: brick id -> {moving id: true}. Only those may
## press on it. Skipped for every moving part, a bearing let the carriage on
## the axle in it slide into it (MCP walk 3's observatory: both ended at
## the same place, and were read as one body after).
var _across: Dictionary = {}
## turn, slide or ball.
var mode: String = ""
var pivot := Vector3.ZERO
var axis := Vector3.ZERO
## Degrees about [member axis] from where it was grabbed.
var angle: float = 0.0
## LDU along it.
var shift: float = 0.0
## A ball's turn from where it was grabbed.
var twist := Basis.IDENTITY
## Where everything that moves stands now: brick id -> Transform3D.
var placed: Dictionary = {}
## The hoses, tubes and strings whose ends this grab parts, laid again as it
## moves ([method drawn]); null for none.
var flex: FlexFollow = null
## The hoses' bends read ahead (GrabDrag), body -> FlexFollow.fit_all's.
var hose_fits: Dictionary = {}
## What held it the last time a pose was refused for a hose pulled to its
## length ("the pneumatic tube from the valve"); "" when the last refusal
## was the model in the way.
var stretch_words: String = ""
## Gears the grabbed one turns, and what they turn on: brick id -> true.
var coupled: Dictionary = {}
## What hangs on a driven gear's body by a joint of its own (an arm on its
## axle, a tyre on its hub), each with the coupled part that carries it:
## brick id -> carrier's id.
var followers: Dictionary = {}
## A closed loop the grabbed joint is in, solved as it moves; null for none.
var linkage: Linkage = null
## The loop stopped it short of where the pointer asked.
var loop_short: bool = false
## Free joints inside what moved that swung down too, said.
var inner_swung := PackedStringArray()
var mechanism: Mechanism
## The model's gear trains read ahead (GrabDrag), the anchors their ground;
## read here for the piece grabbed when not.
var shared_mechanism: Mechanism = null
## What the press spent, ms: reading what moves, the sweeps, the gears.
var begin_took: Dictionary = {}
## Why no gear turns with it, when none does: for a probe.
var gear_note: String = ""
var _driver: int = -1
var _drive_sign: float = 1.0
## What moves, said: "the boom, 38 parts, on its turntable".
var said: String = ""
## Where it stopped short of where it was asked, degrees or LDU, and how
## often in this drag.
var stopped: bool = false
## Grams of what moves, and its centre of mass where it was grabbed.
var grams: float = 0.0
var _centre := Vector3.ZERO
var _floor_y: float = 0.0
var _range := Vector2.ZERO
## Where the pointer took hold, and the pointer's first way of moving.
var _hold := Vector3.ZERO
var _hold_screen := Vector2.ZERO
var _last_raw: float = 0.0
var _unwrapped: float = 0.0
var _decided: bool = false
## Where the last stop was met, degrees; NAN for none.
var _wall: float = NAN
## A frame's room test may run this long, ms (GrabDrag sets it); past it a
## turn is taken on trust and checked on a pause or at the release.
var budget_ms: float = INF
## A drag's frame may test a small section's way this long, ms (GrabDrag sets
## it where [member budget_ms] has no end); past it the turn is shown on trust
## and the rest of the way checked from the last step tested, the next frame,
## on a pause or at the release (G13b). A small section is still bisected at
## once where its way meets something.
var walk_budget_ms: float = INF
## A pause's check of a loop's way may run this long a frame, ms (GrabDrag
## sets it): what is left goes on the next frame, from the part and the pair
## it reached.
var pause_budget_ms: float = INF
## Let go and settled under its weight (once), and what that said.
var settled: bool = false
var swung: String = ""
## A big section's copies made their own ahead of the frame that keeps it:
## the history's depth before, and what was said.
var own_done: bool = false
var own_depth: int = 0
var own_words: String = ""
## The turn shown is not checked for room yet past [member _checked_angle].
var unchecked: bool = false
var _checked_angle: float = 0.0
## A loop's pose kept where [member _checked_angle] stands (Linkage.kept_state),
## where a pause's or the release's walk starts from ([method verify_step]).
var _checked_kept: Array = []
## Where the pointer let it go (GrabDrag), degrees or LDU; NAN until then.
var let_go_at: float = NAN
## The release's check, its walk from the pose checked last, stopped it
## short of [member let_go_at]: said where it is kept (GrabDrag). Not where
## a swing or a coast after came to rest: that is the swing's to say.
var stopped_short: bool = false
var _verify_from: int = 0
var _verifying_lo: float = 0.0
var _verifying_hi: Variant = null
## Moving parts all within reach of the joint's line: not tested for room.
var _on_the_line: Dictionary = {}
## Those of them left out for a turn of the joint taken alone: its sweeps,
## and what is on its own line. Slid along the line instead ([method
## use_slide]), each is tested: the observatory's carriage, found by its
## turn's sweep to meet nothing, was drawn 6 studs along its axle into the
## bearing at the axle's end.
var _turn_only: Dictionary = {}
## Moving parts round about a line through their own middle along the
## joint's (a cone, a round brick, a wheel lying flat), off the joint's
## line: brick id -> that middle, in the part's own frame. Turned about the
## joint, such a part's shape is its own shape moved round, and it is tested
## so ([method _shape_at]). Its turned cover was not it: 2 LDU cells
## worked out turned, and the corners of the square they come from, reach
## past a round part, and 4096's boom met the plate beside its cones' feet
## by 1.2 LDU from 3.7° to 8.8° either way, though the cones swing away from
## it.
var _round_self: Dictionary = {}
## Parts of a loop round about the line of a joint that a joint of the loop
## carries (a column's bevel in a cab of hinges): brick id -> the body that
## carries the joint. Its own turn sweeps only where it is, so it is tested
## where what carries it puts it, unturned: 8062-1's column bevel, tested by
## its turned cover, met the plate beside it at 4.25°.
var _spin_with: Dictionary = {}
## Parts met, each with the moving parts whose covers overlapped it where
## they stood: brick id -> {moving id: true} ([method _rest_with]).
var _rest_overlap: Dictionary = {}
## A loop's own joints' parts that can meet as the joints turn ([method
## _meeting_pairs]): [part, the part across its joint, the joint's line in
## the second's frame, a line square to it there, the first's turn against
## the second where the grab began, inverted, the joint's point in the
## first's frame, and in the second's]. Each pair turns (and slides) against
## each other on its joint, and the rest of the room test never asks one of
## them about the other.
var _joint_pairs: Array = []
## For each of [member _joint_pairs], its joint's turn, radians, and slide,
## LDU, from where the grab began, as far as each was found clear, whether
## the two were into each other there, and what testing them last took:
## [least turn, most turn, least slide, most slide, PAIR_UNKNOWN,
## PAIR_APART_AT_REST or PAIR_FORGIVEN, ms].
var _pair_clear: Array = []
const PAIR_UNKNOWN := 0.0
const PAIR_APART_AT_REST := 1.0
const PAIR_FORGIVEN := 2.0
## Cannot meet however the joint turns and slides ([method _pieces_apart]).
const PAIR_NEVER := 3.0
## The last part that met something, and what it met: [moving, met].
var blocked_by: Array = []
## The last moving part that met something or went through the floor.
var met: int = 0
## A ball's last turn that had no room, and where it stood then: not asked
## again while the pointer asks further the same way.
var _ball_wall := Quaternion.IDENTITY
var _ball_walled: bool = false
## How long the last test for room took, ms, and how many tests a drag ran.
var test_ms: float = 0.0
var tests: int = 0
## This frame's share of solving the loop and of testing for room, ms, and
## how many tests it ran (GrabDrag keeps the worst).
var frame_solve_ms: float = 0.0
var frame_test_ms: float = 0.0
var frame_tests: int = 0
## This frame's slowest part to test, and how long it took: "#id part ms".
var frame_slowest_us: int = 0
var frame_slowest_said: String = ""
## The slowest part to test in a drag, and on what: for a probe.
var slowest_us: int = 0
var slowest_said: String = ""
## A step along the way of a move ([method _path_step]), degrees or LDU, once
## worked out for this grab and way of moving; 0 until then.
var _step: float = 0.0
## A check on a pause's walk ([method verify_step]): where each part was last
## tested, brick id -> degrees or LDU, and where the walk began; and a loop's
## pose kept when it began (Linkage.kept_state), [] for none.
var _verify_last: Dictionary = {}
var _verify_base: float = 0.0
var _verify_kept: Array = []
## A loop's drag: each pose shown on trust since [member _checked_angle], as
## its frame showed it, [value, Linkage.kept_state()]; and of those, the ones
## a pause's walk has still to pass, in its order ([method verify_step]).
var _shown: Array = []
var _walk_frames: Array = []
## How far each tested part goes at most for a unit of the move, LDU
## ([method _path_rate]): brick id -> LDU. A part near the joint's line is
## tested along the way only as often as it goes [constant PATH_LDU].
var _rates: Dictionary = {}


## Read what [param brick_id] would move, from where the pointer [param at]
## took hold of it. [param selection] (brick id -> true), when it holds the
## part and more, is moved as one about what joins it to the rest.
func begin(brick_id: int, at: Vector3, selection: Dictionary = {}) -> String:
	_hold = at
	pick(brick_id, selection)
	if not bodies.body_of.has(brick_id):
		return state
	return _chosen()


## Which joint taking hold of [param brick_id] (with [param selection], as
## [method begin] has it) moves, and the bodies on either side of it, without
## what moving it asks (the sweeps, the gears, a loop): what a motion needs
## to measure where the joint stands (MotionPlayer). [member state] is
## "moves" with [member body] and [member link] set, or why not.
func pick(brick_id: int, selection: Dictionary = {}) -> String:
	part = brick_id
	if bodies == null or bodies.revision != world.revision:
		bodies = Bodies.read(world, library, builder.lattice, bodies.scenery if bodies != null else {},
			builder.locked)
	if not bodies.body_of.has(brick_id):
		return _refuse("rigid", "that part is not part of the model")
	if selection.size() > 1 and selection.has(brick_id):
		_from_selection(selection)
	else:
		_from_part(brick_id)
	return state


## Take hold of [param child]'s body and all beyond it on [param joined],
## the joint between it and its parent: one link of a chain (GrabChain).
func begin_link(joined: Bodies.Link, child: int, at: Vector3) -> String:
	_hold = at
	link = joined
	body = child
	part = int((bodies.members[child] as PackedInt64Array)[0])
	moving_bodies = bodies.beyond(child)
	# A joint of a closed loop is not one link of a chain: the loop moves
	# only as a whole (Linkage), and a chain's turns are each a joint's alone.
	var ours: Dictionary = {}
	for one: int in moving_bodies:
		ours[one] = true
	if not bodies.loops_out(ours, joined).is_empty() or not bodies.racks_out(ours).is_empty():
		return _refuse("loop", "that joint is in a closed loop")
	state = "moves"
	return _chosen()


## What follows from the joint and the bodies chosen: what moves, what it may
## press on, its weight, how it moves, the gears it drives.
func _chosen() -> String:
	_step = 0.0
	_pushed.clear()
	if state != "moves":
		return state
	var clock: int = Time.get_ticks_usec()
	begin_took.clear()
	moving.clear()
	for key: int in bodies.parts_of(moving_bodies):
		moving[key] = true
	var ours: Dictionary = {}
	for one: int in moving_bodies:
		ours[one] = true
	var held: Array[Bodies.Link] = bodies.loops_out(ours, link)
	# A pinion in a rack that does not move with it holds it too: the rack
	# goes as the teeth say, and what the rack is joined to with it.
	var geared: Array[Racks.Pinion] = bodies.racks_out(ours)
	# Or a pinion the grabbed part turns through gears: a steering wheel and
	# its bevels. Their meshes hold the loop too.
	var couplings: Array = []
	if geared.is_empty() and held.is_empty():
		var offer: Array = _train_to_racks(ours)
		couplings = offer[0]
		geared.assign(offer[1])
	var from_rack: bool = false
	if couplings.is_empty() and not geared.is_empty():
		# The rack drawn turns its pinion, and the pinion the train it is in:
		# a tube drawn along its rod turns the wheel that drives it. Their
		# meshes hold the loop too. Not a pinion taken by hand: 8062-1's
		# column, in a cab of hinges, then shared its turn with the cab.
		var outside: Array[Racks.Pinion] = []
		for mesh: Racks.Pinion in geared:
			if not ours.has(int(bodies.body_of.get(mesh.gear, -1))):
				outside.append(mesh)
		couplings = _train_of_pinions(outside)
		from_rack = not couplings.is_empty()
	linkage = null
	_kingpin = Vector3.ZERO
	var loop: Linkage = null
	var other_words: String = ""
	if not held.is_empty() or not geared.is_empty():
		# Held at both ends: a closed loop, moved as it allows (Linkage).
		other_words = held[0].words().trim_prefix("on ") if not held.is_empty() \
			else "by %s" % geared[0].said(world)
		if link.axis == Vector3.ZERO:
			_kingpin = _kingpin_of(body, link)
			if _kingpin == Vector3.ZERO:
				return _refuse("loop", ("%s is on a ball in a closed loop, and the loop moves it: take hold "
					+ "of a part on one of the loop's turning joints (its crank).") % bodies.named([body]))
		loop = Linkage.read(bodies, link, body, couplings, _kingpin)
		if from_rack and not loop.why.is_empty():
			# Too big with the train: the loop as it was, the train left still.
			couplings = []
			loop = Linkage.read(bodies, link, body, couplings, _kingpin)
		# A gear the loop moves turns the gears it meshes, and they theirs: a
		# telescope's cradle, tilted by its extension wheel's rack, is held by
		# the tilt wheel's chain it meshes. Their meshes hold the loop too, by
		# the bearings of the gears alone: 8062-1's steering pulled in its cab
		# of hinges with them (13 joints of 5), and the cab took a sixth of
		# the rack's travel.
		for _round: int in 6:
			if not loop.why.is_empty():
				break
			var more: Array = _meshes_moved(loop, couplings)
			if more.is_empty():
				break
			var wider: Linkage = Linkage.read(bodies, link, body, couplings + more, _kingpin)
			if not wider.why.is_empty() or wider.gear_meshes.size() <= loop.gear_meshes.size() \
					or wider.links.size() <= loop.links.size() or not _only_bearings(loop, wider):
				break
			couplings.append_array(more)
			loop = wider
	if loop != null and loop.why.is_empty():
		# A linear actuator's screw holds its loop where it is: only its rod
		# drawn along it, or its input turned, moves it.
		var by_input: bool = false
		for mesh: Racks.Pinion in loop.racks:
			if mesh.screw and bodies.parent_link.get(int(bodies.body_of[mesh.gear])) == link:
				by_input = true
		for joined: Bodies.Link in loop.links:
			if joined.kind == "actuator" and joined != link and not by_input:
				return _refuse("locked", ("Held by its linear actuator: %s is in a loop with %s, whose screw "
					+ "holds it where it is (a screw is self-locking). Drag the actuator's rod, or turn its "
					+ "input.") % [_named(), bodies.named([joined.b if
					bodies.parent_link.get(joined.b) == joined else joined.a])])
	if loop != null:
		if not loop.why.is_empty():
			return _refuse("loop", "%s is held at both ends, %s and %s: %s." % [
				_named(), link.words().trim_prefix("on "), other_words, loop.why])
		if not loop.can_move():
			return _refuse("locked", ("Locked: this loop has no freedom. %s is held at both ends, "
				+ "%s and %s, and %s closes neither a degree one way nor the other.") % [
				_capital(_named()), link.words().trim_prefix("on "), other_words,
				loop.said()])
		linkage = loop
		_checked_kept = loop.kept_state()
		moving_bodies = loop.moved
		ours.clear()
		moving.clear()
		for one: int in moving_bodies:
			ours[one] = true
		for key: int in bodies.parts_of(moving_bodies):
			moving[key] = true
		# A gear the loop moves that a worm standing still drives: the worm holds
		# it, as it holds a train turned from the gear's side (_gears).
		var held_by: Mechanism.Coupling = _worm_holding(ours)
		if held_by != null:
			linkage = null
			return _refuse("locked", _worm_words(held_by))
	skip = moving.duplicate()
	_near_kept.clear()
	# A hose bends out of the way, and is not tested where it is carried.
	for one: int in bodies.flexible:
		for key: int in bodies.members.get(one, PackedInt64Array()):
			skip[key] = true
	_join_across(ours)
	# What it already overlaps where it stands is not in its way (covers are
	# 2 LDU cells, and a minifigure's hand sits closer to its leg than that):
	# asked of each part met, when it is met (has_room), not of all 131 parts
	# of a wing at the press.
	# A ball's socket sits flush against what the ball stands out of: within
	# a stud of the ball, a part touching the moving side by a cell is not
	# in its way, as the cells cannot tell a flush face from a collision
	# (30472's wing socket against its fuselage's 2x2 brick met it at once).
	if link.axis == Vector3.ZERO:
		var near_ball := AABB(link.point - Vector3.ONE * BrickLattice.STUD,
			Vector3.ONE * BrickLattice.STUD * 2.0)
		for key: int in moving:
			var boxes: PackedInt32Array = builder.lattice.boxes_of(key)
			if boxes.is_empty():
				continue
			# Its bounds a cell wider all round: flush is not overlapping.
			var wide: PackedInt32Array = BrickLattice._bound_of(boxes)
			wide = PackedInt32Array([wide[0] - 1, wide[1] - 1, wide[2] - 1, wide[3] + 1,
				wide[4] + 1, wide[5] + 1])
			for other: int in builder.lattice.near_bounds(wide, key):
				if skip.has(other):
					continue
				var them: BrickWorld.Brick = world.get_brick(other)
				var mesh: Lbm.PartMesh = library.mesh_for(them.part_id) if them != null else null
				if mesh != null and (them.transform * mesh.bounds).intersects(near_ball):
					skip[other] = true
	# A loop's few parts: what each overlaps where it stands is found now,
	# not by the first frame's test, which worked out a wheel's turned cover
	# (18 ms) to find its own tyre's neighbour forgiven. Any section as
	# small (G13): a move tested along its way stops at the first thing in it
	# and asks nothing past it, so what touched as built was kept only for
	# what the first move met, and a later move back over the start met the
	# rest: 10220-1's door, turned +30 (stopped at 5°) and -60, met a tile
	# coming back at -17°, which it was built against.
	if moving.size() <= LOOP_AHEAD_PARTS:
		for key: int in moving:
			var boxes: PackedInt32Array = builder.lattice.boxes_of(key)
			if boxes.is_empty():
				continue
			for other: int in builder.lattice.blockers_boxes(boxes, key, {}):
				if not moving.has(other):
					_rest_with(other)
	rest.clear()
	grams = 0.0
	var weighted := Vector3.ZERO
	_floor_y = INF
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		_floor_y = minf(_floor_y, (brick.transform * info.bounds).position.y)
		if moving.has(brick.id):
			rest[brick.id] = brick.transform
			var g: float = Stability.grams(info)
			grams += g
			weighted += (brick.transform * info.bounds.get_center()) * g
	_centre = weighted / maxf(grams, 0.000001)
	pivot = link.point
	axis = (link.axis if _kingpin == Vector3.ZERO else _kingpin).normalized()
	mode = "ball" if axis == Vector3.ZERO else "turn"
	if linkage != null and linkage.is_slide():
		# Its loop lets it slide and not turn: a scissor lift's foot.
		mode = "slide"
	elif linkage == null and mode == "turn" and not link.turns:
		# An actuator's rod: drawn out and in, never turned.
		mode = "slide"
	# An axle or a pin on the joint's own line sweeps only the holes it is in,
	# and a part whose whole sweep round the line meets nothing but what it
	# may press on can never meet anything: neither is tested again.
	_on_the_line.clear()
	_round_self.clear()
	begin_took["reading"] = (Time.get_ticks_usec() - clock) / 1000
	clock = Time.get_ticks_usec()
	_turn_only.clear()
	if mode == "turn":
		_never_meet()
	begin_took["sweeps"] = (Time.get_ticks_usec() - clock) / 1000
	clock = Time.get_ticks_usec()
	if mode == "turn" and linkage == null:
		for key: int in moving:
			var brick: BrickWorld.Brick = world.get_brick(key)
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh == null:
				continue
			if _thin_on(key, pivot, axis) or _round_on(key, pivot, axis):
				_on_the_line[key] = true
				_turn_only[key] = true
				continue
			var middle: Vector3 = mesh.bounds.get_center()
			if _round_on(key, brick.transform * middle, axis):
				_round_self[key] = middle
	_spin_with.clear()
	if linkage != null:
		for n: int in linkage.links.size():
			var joined: Bodies.Link = linkage.links[n]
			if joined.axis == Vector3.ZERO:
				continue
			var carried: bool = linkage.moved.has(linkage.parent_of[n])
			for key: int in bodies.members.get(linkage.child_of[n], PackedInt64Array()):
				# An axle or a pin on a joint's own line turns inside the holes
				# it is in, in a loop as out of one: 42111-1's steering column,
				# turned in its loop, met the bearing it turns in at once.
				if not carried and joined.turns and _thin_on(key, joined.point, joined.axis.normalized()):
					_on_the_line[key] = true
					if joined == link:
						_turn_only[key] = true
				elif _round_on(key, joined.point, joined.axis.normalized()):
					if carried:
						_spin_with[key] = int(linkage.parent_of[n])
					else:
						_on_the_line[key] = true
						if joined == link:
							_turn_only[key] = true
	_meeting_pairs()
	var shaft_moves: bool = moving.has(link.shaft_part)
	_range = Vector2(-link.slide.y, link.slide.x) if shaft_moves else Vector2(-link.slide.x, link.slide.y)
	if linkage == null:
		_gears()
	begin_took["gears"] = (Time.get_ticks_usec() - clock) / 1000
	# A hose whose one end moves and other does not bends between them.
	var going: Dictionary = moving.duplicate()
	going.merge(coupled)
	going.merge(followers)
	flex = FlexFollow.read(world, library, bodies, going, hose_fits)
	if flex.items.is_empty():
		flex = null
	else:
		rest.merge(flex.rests())
	begin_took["hoses"] = flex.read_ms if flex != null else 0.0
	if moving.size() <= LOOP_AHEAD_PARTS:
		# What stands near each moving part, asked of the lattice now, where
		# it stands, rather than by the drag's first frame ([method _near]).
		for key: int in moving:
			var brick: BrickWorld.Brick = world.get_brick(key)
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
			if mesh != null and not _on_the_line.has(key):
				_near(brick.transform * mesh.bounds, key)
	placed = rest.duplicate()
	# In a loop, the part taken, not all the loop moves: a session that took
	# a steering knuckle read "the Technic Beam 13, 34 parts".
	said = "%s %s" % [bodies.named([body]) if linkage != null else _named(), link.words()]
	if linkage != null:
		said += ", in %s" % linkage.said()
	return state


## Each joint between the moving bodies [param ours] (body -> true) and what
## stays, pair by pair, into [member _across]: the part that stays may be
## pressed on by its partner across the joint, an axle by the bearing it
## turns in, and by nothing else that moves.
func _join_across(ours: Dictionary) -> void:
	_across.clear()
	_verdicts.clear()
	_along.clear()
	for one: int in moving_bodies:
		for joined: Bodies.Link in bodies.touching.get(one, []):
			if ours.has(joined.other(one)):
				continue
			for pair: Array in joined.pairs:
				var a: int = int(pair[0])
				var b: int = int(pair[1])
				var stays: int = b if moving.has(a) else a
				var goes: int = a if moving.has(a) else b
				if moving.has(stays) or not moving.has(goes):
					continue
				if not _across.has(stays):
					_across[stays] = {}
				(_across[stays] as Dictionary)[goes] = true


## The line a part grabbed on a ball in a loop turns on, or ZERO: where it
## hangs on another ball as well, on a body held on a line of its own (a
## hinge, an axle) or on what stays, it turns on the line through the two
## balls' middles, which keeps both where they are, as a steering arm turns
## on its upper and lower ball joints (15460 on 10295-1's wishbones, 6571 on
## 4404-1's frame and swing arm). A third ball, a track rod's on a rod hung
## only on balls, is not a kingpin's: the loop moves it.
var _kingpin := Vector3.ZERO


func _kingpin_of(child: int, ball: Bodies.Link) -> Vector3:
	if not _held_on_a_line(ball.other(child)):
		return Vector3.ZERO
	var best := Vector3.ZERO
	for joined: Bodies.Link in bodies.touching.get(child, []):
		if joined == ball or joined.kind != "ball" or joined.axis != Vector3.ZERO \
				or not _held_on_a_line(joined.other(child)):
			continue
		var line: Vector3 = joined.point - ball.point
		if line.length() > BrickLattice.STUD * 0.5 and line.length() > best.length():
			best = line
	return best.normalized() if best != Vector3.ZERO else Vector3.ZERO


## Whether [param body] stays, or hangs on a joint with a line (not only on
## balls, as a track rod does).
func _held_on_a_line(body: int) -> bool:
	var up: Bodies.Link = bodies.parent_link.get(body)
	return up == null or up.axis != Vector3.ZERO


## What moves, in words: named by its rigid bodies, not a hose it carries,
## which bends and is not what was taken hold of (an arm on a hinge with a
## tube of 53 pieces hanging from it was "Pneumatic Tube 9L, 56 parts"); its
## parts counted whole.
func _named() -> String:
	var rigid: Array = moving_bodies.filter(func(one: int) -> bool: return not bodies.flexible.has(one))
	if rigid.is_empty() or rigid.size() == moving_bodies.size():
		return bodies.named(moving_bodies)
	var count: int = bodies.parts_of(moving_bodies).size()
	return "%s, %d part%s" % [bodies.named(rigid).get_slice(",", 0), count, "" if count == 1 else "s"]


static func _capital(words: String) -> String:
	return words.substr(0, 1).to_upper() + words.substr(1) if not words.is_empty() else words


func _refuse(kind: String, words: String) -> String:
	state = kind
	why = words
	return state


## The part's body and all beyond it, on the joint towards the anchor; or,
## for a joint's anchored half, the half across it.
func _from_part(brick_id: int) -> void:
	body = int(bodies.body_of[brick_id])
	# An actuator's rod is drawn out and in along its actuator, whichever way
	# the tree hangs the two.
	for joined: Bodies.Link in bodies.touching.get(body, []):
		if joined.turns or joined.shaft_part != brick_id:
			continue
		for end: int in [joined.a, joined.b]:
			if bodies.parent_link.get(end) == joined:
				body = end
				link = joined
				moving_bodies = bodies.beyond(end)
				state = "moves"
				return
	if bodies.anchors.has(body) or not bodies.parent_link.has(body):
		# The anchored half of a joint moves the half across it.
		for joined: Bodies.Link in bodies.touching.get(body, []):
			var across: int = joined.other(body)
			if bodies.parent_link.get(across) != joined:
				continue
			for pair: Array in joined.pairs:
				if int(pair[0]) == brick_id or int(pair[1]) == brick_id:
					body = across
					link = joined
					moving_bodies = bodies.beyond(across)
					state = "moves"
					return
		held_by = bodies.overruled_words(brick_id)
		var held: String = held_by if not held_by.is_empty() else bodies.held_words(brick_id)
		_refuse("rigid", "that part is held rigidly to what it stands on"
			+ ("" if held.is_empty() else ": " + held))
		return
	link = bodies.parent_link[body]
	moving_bodies = bodies.beyond(body)
	state = "moves"


## A selection moved as one: whole bodies only, about the one joint (or the
## joints on one line) between it and the rest.
func _from_selection(selection: Dictionary) -> void:
	var ours: Dictionary = {}
	for key: Variant in selection:
		if bodies.body_of.has(int(key)):
			ours[int(bodies.body_of[int(key)])] = true
	for one: int in ours:
		for key: int in bodies.members[one]:
			if not selection.has(key):
				_refuse("rigid", ("the selection is held to the rest by studs: it would have to be "
					+ "pulled off them. Drag it with nothing selected to turn it on its joint, or "
					+ "move it off as a whole with the Move tool."))
				return
	var crossing: Array[Bodies.Link] = []
	for one: int in ours:
		for joined: Bodies.Link in bodies.touching.get(one, []):
			if not ours.has(joined.other(one)) and not crossing.has(joined):
				crossing.append(joined)
	if crossing.is_empty():
		_refuse("rigid", "the selection is joined to nothing that turns")
		return
	link = crossing[0]
	body = link.a if ours.has(link.a) else link.b
	moving_bodies = ours.keys()
	state = "moves"


## A gear in what moves drives its train, as Simulate drives it.
func _gears() -> void:
	coupled.clear()
	mechanism = null
	_driver = -1
	var any: bool = false
	for key: int in moving:
		if not Mechanism.spec_of(world.get_brick(key).part_id).is_empty():
			any = true
			break
	if not any or mode != "turn":
		return
	if shared_mechanism != null:
		mechanism = shared_mechanism
	else:
		var list: Array = []
		var held: Array = []
		var piece: Dictionary = _piece_of(body)
		for key: int in piece:
			var brick: BrickWorld.Brick = world.get_brick(key)
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh == null:
				continue
			list.append({"key": key, "part": brick.part_id, "at": brick.transform, "mesh": mesh})
			if bodies.anchors.has(int(bodies.body_of[key])):
				held.append(key)
		mechanism = Mechanism.build(list, held)
		mechanism.join_universals(bodies.universals(), bodies)
	# The driver is what the gear that moves turns on, on the grabbed joint's
	# line: the part pressed may be a sail pinned to it, which Mechanism
	# reads as a body of its own.
	var driven: int = -1
	var joint: Mechanism.Joint = null
	for key: int in [part] + moving.keys():
		var body_here: int = mechanism.body_of(key)
		var turning_on: Mechanism.Joint = mechanism.joint_of(body_here)
		if turning_on != null and Bodies._same_line(turning_on.point, turning_on.way, pivot, axis) \
				and (key == part or not Mechanism.spec_of(world.get_brick(key).part_id).is_empty()):
			driven = body_here
			joint = turning_on
			break
	if joint == null:
		gear_note = "no gear of it turns on this joint's line in the gear reading"
		mechanism = null
		return
	var solved: Dictionary = mechanism.solve({driven: 1.0})
	if not bool(solved["ok"]):
		# Gears that fight lock it, and are named. A lock no one mesh makes is
		# Mechanism's reading of a loop of pins elsewhere in a big model, not
		# of these gears: moved on its joint, its gears left where they are.
		gear_note = "the gear reading says: %s" % str(solved["said"])
		if bool(solved["locked"]) and not (solved["culprits"] as Array).is_empty():
			var stays: String = bodies.what_stays(body)
			_refuse("locked", "%s will not turn: its gears lock (%s).%s" % [_named(),
				", ".join(PackedStringArray(solved["culprits"])),
				"" if stays.is_empty() else " It is held between what stays: %s." % stays])
		mechanism = null
		return
	# A worm turns its gear; its gear cannot turn it (self-locking). Grabbed
	# on the gear's side, the train is held there.
	var held_back: Array[Mechanism.Coupling] = mechanism.worms_back_driven(driven)
	if not held_back.is_empty():
		_refuse("locked", _worm_words(held_back[0]))
		gear_note = "a worm it would turn backwards holds it"
		mechanism = null
		return
	_driver = driven
	_drive_sign = 1.0 if joint.way.dot(axis) > 0.0 else -1.0
	# What turns: every body the solve gives a spin, its parts; not the whole
	# model posed to find them (1,300 parts at the press).
	for one: int in mechanism.bodies:
		if one == mechanism.ground or mechanism.floating.has(one) \
				or mechanism.omega(one).length() <= 1e-6:
			continue
		for key: int in mechanism.bodies[one]:
			if moving.has(key) or not mechanism.rest.has(key):
				continue
			coupled[key] = true
			skip[key] = true
			rest[key] = mechanism.rest[key]
	_follow_driven()


## Why a worm holds what was grabbed, in words: its gear cannot turn it.
func _worm_words(worm: Mechanism.Coupling) -> String:
	var worm_body: int = int(bodies.body_of.get(worm.one.key, -1))
	# Its thread's lead angle: a tooth a turn round its pitch circle.
	var lead: float = float(Mechanism.table().get("worm_lead", PI * 2.5))
	var climbs: float = rad_to_deg(atan(lead / (TAU * maxf(worm.one.radius, 1.0))))
	return ("Held by a worm: %s turns the %d tooth gear that turns %s, and a gear cannot turn its worm "
		+ "back (a worm is self-locking: its thread climbs at %.0f°, too shallow for the gear's teeth to "
		+ "push it round). Turn the worm's axle instead.") % [bodies.named([worm_body]) if worm_body >= 0
		else "the worm", worm.other.teeth, _named(), climbs]


## A worm standing still whose gear the loop moves against it, from the gear
## reading read ahead: the loop's driver stepped a little, the gear's body
## has moved against the worm's. Null for none. [param ours]: the bodies the
## loop moves (Bodies body -> true).
func _worm_holding(ours: Dictionary) -> Mechanism.Coupling:
	if shared_mechanism == null or linkage == null:
		return null
	var step: Dictionary = {}
	for coupling: Mechanism.Coupling in shared_mechanism.couplings:
		if coupling.how != "worm":
			continue
		var wheel: int = int(bodies.body_of.get(coupling.other.key, -1))
		var worm: int = int(bodies.body_of.get(coupling.one.key, -1))
		# The worm moved too is the loop's driver or carried with it: a worm
		# may turn its gear.
		if wheel < 0 or not ours.has(wheel) or ours.has(worm):
			continue
		if step.is_empty():
			var small: float = Linkage.FREEDOM_SLIDE if linkage.is_slide() else Linkage.FREEDOM_TURN
			if absf(linkage.reach(linkage.kept_value() + small) - linkage.kept_value()) < small * 0.5:
				linkage.reach(linkage.kept_value() - small)
			step = linkage.places()
			linkage.q = linkage.kept.duplicate()
		var against: Transform3D = (step.get(worm, Transform3D.IDENTITY) as Transform3D).affine_inverse() \
			* (step.get(wheel, Transform3D.IDENTITY) as Transform3D)
		var turned: float = rad_to_deg(Quaternion(against.basis.orthonormalized()).get_angle())
		var moved: float = (against * coupling.other.centre).distance_to(coupling.other.centre)
		gear_note = "the gear moved %.4f° and %.4f LDU against its worm for the driver's step" % [turned, moved]
		# Turned against it: a gear shifted along its own axle by a slide the
		# loop takes up (8062-1's, 0.13 LDU for a degree of the column) does
		# not turn the worm.
		if turned > 0.01:
			return coupling
	return null


## The gear train the grabbed joint drives, when it reaches a pinion in a
## rack that does not move with it (a steering wheel turning its pinion
## through bevels): [the train's meshes, those pinions], else [[], []]. The
## train is the gear reading's (GrabDrag reads it ahead), solved from the
## grabbed joint as [method _gears] solves it.
func _train_to_racks(ours: Dictionary) -> Array:
	var none: Array = [[], []]
	if shared_mechanism == null or link.axis == Vector3.ZERO or bodies.racks().is_empty():
		return none
	var gear_parts: Array = []
	for key: int in moving:
		if not Mechanism.spec_of(world.get_brick(key).part_id).is_empty():
			gear_parts.append(key)
	if gear_parts.is_empty():
		return none
	var train: Mechanism = shared_mechanism
	var driven: int = -1
	for key: int in [part] + gear_parts:
		var here: int = train.body_of(key)
		var turning_on: Mechanism.Joint = train.joint_of(here)
		if turning_on != null and Bodies._same_line(turning_on.point, turning_on.way, link.point,
				link.axis.normalized()):
			driven = here
			break
	if driven < 0:
		return none
	var solved: Dictionary = train.solve({driven: 1.0})
	if not bool(solved["ok"]):
		return none
	var turning: Dictionary = {}
	for gear: Mechanism.Gear in train.gears:
		if gear.body == driven or (gear.body != train.ground and not train.floating.has(gear.body)
				and train.omega(gear.body).length() > 1e-6):
			turning[gear.key] = true
	var pinions: Array = []
	# A rack the train carries round past a pinion standing still rolls along
	# it as much: a telescope's tilt wheel turns its cradle, whose tube's rack
	# rolls along the extension wheel's pinion on the tilt line.
	var carrying: Dictionary = ours.duplicate()
	for key: Variant in turning:
		carrying[int(bodies.body_of.get(int(key), -1))] = true
	for mesh: Racks.Pinion in bodies.racks():
		var rack_body: int = int(bodies.body_of[mesh.rack])
		if turning.has(mesh.gear) and not ours.has(rack_body):
			pinions.append(mesh)
		elif not turning.has(mesh.gear) and not carrying.has(int(bodies.body_of[mesh.gear])) \
				and _carried_by(rack_body, carrying):
			pinions.append(mesh)
	if pinions.is_empty():
		return none
	var meshes: Array = []
	for coupling: Mechanism.Coupling in train.couplings:
		if coupling.how != "chain" and turning.has(coupling.one.key) and turning.has(coupling.other.key):
			meshes.append(coupling)
	return [meshes, pinions]


## Whether [param body] or a body it hangs from is among [param carrying]
## (Bodies body -> true).
func _carried_by(body: int, carrying: Dictionary) -> bool:
	var at: int = body
	for _n: int in 64:
		if carrying.has(at):
			return true
		if not bodies.parent_of.has(at):
			return false
		at = int(bodies.parent_of[at])
	return false


## Whether every joint [param wider] has that [param loop] has not turns a
## gear, or a universal joint's cross or end: the bearings of a gear chain
## and the shafts it drives on, not what carries them. 42125-1's steering
## column turns its wheel through two universal joints and a cardan shaft;
## left out, the loop's gear turned and the one it meshes on the column stood.
func _only_bearings(loop: Linkage, wider: Linkage) -> bool:
	var geared: Dictionary = {}
	for gear: Mechanism.Gear in shared_mechanism.gears:
		geared[int(bodies.body_of.get(gear.key, -1))] = true
	for cross: Array in bodies.universals():
		geared[int(cross[0])] = true
		for joined: Bodies.Link in [cross[1], cross[2]]:
			geared[joined.other(int(cross[0]))] = true
	for n: int in wider.links.size():
		if not loop.links.has(wider.links[n]) and not geared.has(int(wider.child_of[n])):
			return false
	return true


## The gear reading's meshes, not among [param offered], of a gear [param
## loop] turns on its own axle against one it leaves standing: what it turns
## as it moves. A gear the loop swings about another line (a hub's on a
## steered wheel) is left out: its mesh would part, and a steering pulled in
## a drivetrain's meshes with it (8062-1: 40 joints, the rack 4.45 LDU of
## 5.34 for 30°).
func _meshes_moved(loop: Linkage, offered: Array) -> Array:
	var out: Array = []
	if shared_mechanism == null:
		return out
	var moved: Dictionary = {}
	for one: int in loop.moved:
		moved[one] = true
	var line_of: Dictionary = {}   ## a loop joint's child body -> its link
	for n: int in loop.links.size():
		line_of[int(loop.child_of[n])] = loop.links[n]
	for coupling: Mechanism.Coupling in shared_mechanism.couplings:
		if coupling.how == "chain" or offered.has(coupling):
			continue
		var one: int = int(bodies.body_of.get(coupling.one.key, -1))
		var other: int = int(bodies.body_of.get(coupling.other.key, -1))
		if one < 0 or other < 0 or one == other or moved.has(one) == moved.has(other):
			continue
		# The gear it would turn must turn on a joint of its own: one held with
		# what stays locks the loop (8020-1's truck, steered back, did not move).
		var still: int = other if moved.has(one) else one
		var bearing: Bodies.Link = bodies.parent_link.get(still)
		if bodies.anchors.has(still) or bearing == null or not bearing.turns:
			continue
		# A worm standing still holds its gear: no mesh to turn it back by
		# (_worm_holding says so). A tractor's sower, on a 24, turned 720°.
		if coupling.how == "worm" and moved.has(other):
			continue
		var gear: Mechanism.Gear = coupling.one if moved.has(one) else coupling.other
		# The loop joint that carries it: its own, or the nearest one in.
		var at: int = one if moved.has(one) else other
		var carried: Bodies.Link = null
		for _n: int in 64:
			if line_of.has(at):
				carried = line_of[at]
				break
			if not bodies.parent_of.has(at):
				break
			at = int(bodies.parent_of[at])
		if carried != null and carried.axis != Vector3.ZERO and carried.turns \
				and Bodies._same_line(carried.point, carried.axis.normalized(), gear.centre, gear.axis.normalized()):
			out.append(coupling)
	return out


## The meshes of the gear trains [param pinions] are in (Racks.Pinion), as
## the gear reading has them, each solved from its pinion: [] where none
## turns or the train locks. A train turned from its rack's side, as
## [method _train_to_racks] offers one turned from the train's.
func _train_of_pinions(pinions: Array[Racks.Pinion]) -> Array:
	var meshes: Array = []
	if shared_mechanism == null:
		return meshes
	var train: Mechanism = shared_mechanism
	for mesh: Racks.Pinion in pinions:
		if mesh.screw or not train.parts.has(mesh.gear):
			continue
		var driven: int = train.body_of(mesh.gear)
		if driven == train.ground or train.joint_of(driven) == null:
			continue
		if not bool(train.solve({driven: 1.0})["ok"]):
			continue
		var turning: Dictionary = {}
		for gear: Mechanism.Gear in train.gears:
			if gear.body == driven or (gear.body != train.ground and not train.floating.has(gear.body)
					and train.omega(gear.body).length() > 1e-6):
				turning[gear.key] = true
		for coupling: Mechanism.Coupling in train.couplings:
			if coupling.how != "chain" and turning.has(coupling.one.key) and turning.has(coupling.other.key) \
					and not meshes.has(coupling):
				meshes.append(coupling)
	return meshes


## What hangs on a driven body by a joint the gear reading does not read (a
## clip, a hinge, a tyre on its hub, an arm pinned to the gear) goes round
## with it: every part of the driven body's rigid body in [Bodies] and of
## everything beyond it there, each carried by a driven part of its own body
## or the nearest one in from it. Tested for room as the section is.
var follower_bodies: Array = []


func _follow_driven() -> void:
	followers.clear()
	follower_bodies.clear()
	var carrier_of: Dictionary = {}   ## Bodies body -> a driven part in it
	for key: int in coupled:
		var one: int = int(bodies.body_of.get(key, -1))
		if one >= 0 and not carrier_of.has(one):
			carrier_of[one] = key
	var ours: Dictionary = {}
	for one: int in moving_bodies:
		ours[one] = true
	for one: int in carrier_of:
		var carrier: int = carrier_of[one]
		var stack: Array = [one]
		while not stack.is_empty():
			var at: int = stack.pop_back()
			if at != one:
				follower_bodies.append(at)
			for key: int in bodies.members.get(at, PackedInt64Array()):
				if coupled.has(key) or moving.has(key) or followers.has(key):
					continue
				followers[key] = carrier
				skip[key] = true
				rest[key] = world.get_brick(key).transform
			for kid: int in bodies.children.get(at, []):
				if carrier_of.has(kid) or ours.has(kid):
					continue
				# What it is joined by may press on what carries it.
				for pair: Array in (bodies.parent_link[kid] as Bodies.Link).pairs:
					for key: int in pair:
						skip[key] = true
				stack.append(kid)


## Every part in the piece of the model [param from] is in.
func _piece_of(from: int) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {from: true}
	var frontier: Array = [from]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		for key: int in bodies.members[at]:
			out[key] = true
		for joined: Bodies.Link in bodies.touching.get(at, []):
			var next: int = joined.other(at)
			if not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return out


static func _same(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.01 and a.basis.x.distance_to(b.basis.x) < 1e-5 \
		and a.basis.y.distance_to(b.basis.y) < 1e-5 and a.basis.z.distance_to(b.basis.z) < 1e-5


# -- where it stands ------------------------------------------------------------


## Where every part that moves stands with the joint at [param degrees]
## (turn), [param along] (slide) or [param turned] (ball).
func transforms_at(degrees: float, along: float = 0.0, turned: Basis = Basis.IDENTITY) -> Dictionary:
	if linkage != null:
		# The loop closed with its driver there, from the pose last kept.
		var solving: int = Time.get_ticks_usec()
		linkage.reach(along if linkage.is_slide() else deg_to_rad(degrees))
		var out_loop: Dictionary = linkage.transforms(rest)
		frame_solve_ms += float(Time.get_ticks_usec() - solving) / 1000.0
		return out_loop
	var move := Transform3D.IDENTITY
	if mode == "ball":
		move = Transform3D(Basis.IDENTITY, pivot) * Transform3D(turned, Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -pivot)
	else:
		move = Transform3D(Basis.IDENTITY, pivot) \
			* Transform3D(Basis(axis, deg_to_rad(degrees)), axis * along) \
			* Transform3D(Basis.IDENTITY, -pivot)
	var out: Dictionary = {}
	for key: int in moving:
		# Not squared up: a file's own six-decimal turns would read as moved.
		out[key] = move * (rest[key] as Transform3D)
	if not _pushed.is_empty():
		_turn_pushed(out)
	if mechanism != null and not coupled.is_empty():
		var driven: Dictionary = mechanism.pose_of(deg_to_rad(degrees) * _drive_sign, coupled)
		for key: int in coupled:
			out[key] = driven[key]
		# A universal joint at an angle turns its far shaft by Cardano's
		# relation, not the gear reading's mean.
		_cardan(out, deg_to_rad(degrees) * _drive_sign)
		# What hangs on a driven body goes round with it.
		for key: int in followers:
			var carrier: int = followers[key]
			out[key] = ((out[carrier] as Transform3D) * (rest[carrier] as Transform3D).affine_inverse()) \
				* (rest[key] as Transform3D)
		_pose_crosses(out)
	return out


## A universal joint's cross where its two ends put it: each of its lines
## turns with the end it is pinned in, and it stays where they cross. Hung
## on one end it went round with that one alone, which is right only while
## the other turns alike. [param out]: brick id -> Transform3D, as
## [method transforms_at] has it.
func _pose_crosses(out: Dictionary) -> void:
	for joint: Dictionary in mechanism.universals:
		var keys: Array = joint["cross"]
		if keys.is_empty() or not (out.has(int(keys[0]))):
			continue
		var moved := func(key: int) -> Transform3D:
			if not out.has(key) or not rest.has(key):
				return Transform3D.IDENTITY
			return (out[key] as Transform3D) * (rest[key] as Transform3D).affine_inverse()
		var one: Transform3D = moved.call(int(joint["end_one"]))
		var other: Transform3D = moved.call(int(joint["end_other"]))
		var p: Vector3 = joint["pin_one"]
		var q: Vector3 = joint["pin_other"]
		var p_now: Vector3 = (one.basis * p).normalized()
		var q_now: Vector3 = (other.basis * q).normalized()
		var stood := Basis(p, (q - p * p.dot(q)).normalized(), p.cross(q).normalized())
		var q_square: Vector3 = (q_now - p_now * p_now.dot(q_now))
		if q_square.length() < 0.01:
			continue
		q_square = q_square.normalized()
		var stands := Basis(p_now, q_square, p_now.cross(q_square).normalized())
		var turn: Basis = stands * stood.inverse()
		var at: Vector3 = one * (joint["at"] as Vector3)
		var move := Transform3D(turn, at - turn * (joint["at"] as Vector3))
		for key: int in keys:
			if out.has(key) and rest.has(key):
				out[key] = move * (rest[key] as Transform3D)


## A universal joint whose shafts stand further apart than this, radians
## (half a degree), turns its far shaft by Cardano's relation, not the mean.
const CARDAN_LEAST := 0.0087


## A universal joint at an angle turns its far shaft unevenly: the far end's
## pin stays square to the near end's pin and to the far shaft, so with the
## near shaft turned θ1 the far one is turned where that pin then lies,
## tan θ2 = tan θ1 cos β from where the near pin lies in the shafts' plane
## (Cardano's relation), running ahead and behind the near one within each
## half turn. The gear reading turns it one for one (the mean, exact only in
## line); the difference is turned onto the far shaft and onto every gear it
## turns, each by its ratio to it, about its own axle. Where the far side is
## not shafts and gears on axles that stand (one on a carrier, or a loop
## back to the near side), the mean is kept. [param out]: brick id ->
## Transform3D, as [method transforms_at] has it; [param driver_turn]: the
## gear reading's driver angle, radians.
func _cardan(out: Dictionary, driver_turn: float) -> void:
	var angled: Array = []   ## [joint, its far side]
	for joint: Dictionary in mechanism.universals:
		var a: Vector3 = (joint["way_one"] as Vector3).normalized()
		var b: Vector3 = (joint["way_other"] as Vector3).normalized()
		if a.angle_to(b) >= CARDAN_LEAST:
			angled.append([joint, _far_side(joint)])
	for one: Array in angled:
		for other: Array in angled:
			# Two at an angle one after the other (a cardan shaft's two ends):
			# the second's near shaft is the first's uneven far one. Not
			# worked out: both keep the mean.
			if one != other and (other[1] as Dictionary).has(int((one[0] as Dictionary)["one"])):
				return
	for one: Array in angled:
		var joint: Dictionary = one[0]
		var far: Dictionary = one[1]
		if far.is_empty():
			continue
		var a: Vector3 = (joint["way_one"] as Vector3).normalized()
		var b: Vector3 = (joint["way_other"] as Vector3).normalized()
		var near_turn: float = mechanism.omega(int(joint["one"])).dot(a) * driver_turn
		var mean: float = mechanism.omega(int(joint["other"])).dot(b) * driver_turn
		var exact: float = Grab.cardan_turn(near_turn, a, b, joint["pin_one"], joint["pin_other"])
		var behind: float = exact - mean
		if absf(behind) < 1e-7:
			continue
		for body: int in far:
			var line: Mechanism.Joint = mechanism.joint_of(body)
			var turn := Transform3D(Basis.IDENTITY, line.point) \
				* Transform3D(Basis(line.way.normalized(), behind * float(far[body])), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -line.point)
			for key: int in mechanism.bodies.get(body, []):
				if out.has(key):
					out[key] = turn * (out[key] as Transform3D)


## The far shaft of [param joint] and every body the gear reading turns from
## it, each with its turn about its own axle for a radian of the far shaft
## about its line: body -> ratio. {} when one of them turns on a carrier, or
## the near side is reached again from the far one (the far shaft is driven
## some other way too).
func _far_side(joint: Dictionary) -> Dictionary:
	var near: int = int(joint["one"])
	var far_shaft: int = int(joint["other"])
	var b: Vector3 = (joint["way_other"] as Vector3).normalized()
	var linked: Dictionary = {}   ## body -> bodies its gears mesh with
	for coupling: Mechanism.Coupling in mechanism.couplings:
		for pair: Array in [[coupling.one.body, coupling.other.body], [coupling.other.body, coupling.one.body]]:
			if not linked.has(pair[0]):
				linked[pair[0]] = []
			(linked[pair[0]] as Array).append(pair[1])
	for other: Dictionary in mechanism.universals:
		if other == joint:
			continue
		for pair: Array in [[int(other["one"]), int(other["other"])], [int(other["other"]), int(other["one"])]]:
			if not linked.has(pair[0]):
				linked[pair[0]] = []
			(linked[pair[0]] as Array).append(pair[1])
	var seen: Dictionary = {far_shaft: true}
	var frontier: Array = [far_shaft]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		for next: int in linked.get(at, []):
			if next == near:
				return {}
			if not seen.has(next):
				seen[next] = true
				frontier.append(next)
	var per: float = mechanism.omega(far_shaft).dot(b)
	if absf(per) < 1e-9:
		return {}
	var out: Dictionary = {}
	for body: int in seen:
		if mechanism.path(body).size() != 1:
			return {}
		var line: Mechanism.Joint = mechanism.joint_of(body)
		out[body] = mechanism.omega(body).dot(line.way.normalized()) / per
	return out


## The far shaft's turn about [param b] for the near shaft's [param near]
## radians about [param a] from where they stood, the near end's pin along
## [param pin_one] then and the far end's along [param pin_other]: the far
## pin is square to the near pin and to the far shaft. Unwrapped about the
## near turn, from which it differs by less than a quarter turn.
static func cardan_turn(near: float, a: Vector3, b: Vector3, pin_one: Vector3, pin_other: Vector3) -> float:
	var p0: Vector3 = pin_one.normalized()
	var q0: Vector3 = pin_other.normalized()
	var p: Vector3 = p0.rotated(a, near)
	var q: Vector3 = b.cross(p)
	if q.length() < 1e-9:
		return near
	q = q.normalized()
	# The far pin as it stood is one of the two square to both: keep its side.
	if b.cross(p0).dot(q0) < 0.0:
		q = -q
	var raw: float = atan2(b.dot(q0.cross(q)), q0.dot(q))
	return near + wrapf(raw - near, -PI, PI)


## Whether every part that moves has room at [param at]: nothing in the
## way but what it is joined to, and nothing through the floor.
func has_room(at: Dictionary) -> bool:
	return _test(at, 0, INF).x == 1


## Test [param at] from the [param from]th moving part on, for at most
## [param budget] ms: Vector2i(1 room, 0 none, -1 out of time; the part to
## go on from). [param ahead]: the turned covers it wants worked out whole,
## side by side, when the whole test is asked at once; a step along the way
## is a turn asked once, and asks each cover where something is instead.
## [param due], when not empty, the only moving parts tested (brick id ->
## true): a step along the way tests those that have gone far enough.
## [param pairs]: a loop's own joints' parts against each other too ([member
## _joint_pairs]), which a loop's drag leaves to its pause.
func _test(at: Dictionary, from: int, budget: float, ahead: bool = true, due: Dictionary = {},
		pairs: bool = true) -> Vector2i:
	var started: int = Time.get_ticks_usec()
	tests += 1
	if flex != null and from == 0:
		# A hose pulled further than it reaches holds what it joins.
		var holding: FlexFollow.Item = flex.stretched(at)
		if holding != null:
			met = holding.slots[0]
			blocked_by = [holding.slots[0], holding.holders[0]]
			stretch_words = holding.name
			test_ms = float(Time.get_ticks_usec() - started) / 1000.0
			frame_test_ms += test_ms
			frame_tests += 1
			return Vector2i(0, 0)
	var keys: Array = moving.keys()
	if not followers.is_empty():
		keys.append_array(followers.keys())
	var result: int = 1
	var n: int = from
	# Which parts' turned covers this test wants, worked out side by side
	# first, when the whole test is asked at once.
	var carried_at: Dictionary = linkage.places() if linkage != null and not _spin_with.is_empty() else {}
	var meets: Dictionary = _covers_ahead(at, keys, carried_at) if budget == INF and ahead else {}
	while n < keys.size():
		# The first part a call asks is tested whatever is left of the
		# budget, so a pause whose solve took its budget still goes on.
		if budget < INF and n > from and float(Time.get_ticks_usec() - started) / 1000.0 > budget:
			result = -1
			break
		var key: int = keys[n]
		n += 1
		if _on_the_line.has(key) or bodies.flexible.has(int(bodies.body_of.get(key, -1))) \
				or not due.is_empty() and not due.has(key):
			continue
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var to: Transform3D = _tested_at(key, at, carried_at)
		var box: AABB = to * mesh.bounds
		if box.position.y < _floor_y - BELOW_FLOOR and mesh.lowest_at(to) < _floor_y - BELOW_FLOOR:
			result = 0
			met = key
			blocked_by = []
			stretch_words = ""
			break
		# Its box first: nothing but what it may press on anywhere near it,
		# and its turned cover is not worked out at all. A sail turning in
		# the air cost a windmill's drag 38 ms a frame that way. Then its
		# turned box against each part near it: apart from all of them, or
		# only touching, it meets nothing (a steering's wheel beside its
		# mudguard cost 19 ms a test by its turned cover).
		if meets.has(key):
			if not bool(meets[key]):
				continue
		elif not _near_anything(box, key) or not _boxes_meet(key, mesh, to, box):
			continue
		var part_began: int = Time.get_ticks_usec()
		# A part at a turn whose cover is not kept is asked where something
		# is (BrickLattice.TurnedCover), not worked out whole: each body of a
		# loop is at a new turn every frame, and 42081-1's panel of 611 boxes
		# took 2.8 s a cover.
		var turned: BrickLattice.TurnedCover = builder.turned_cover(mesh, to)
		var hit: PackedInt64Array
		var cover_us: int = 0
		if turned != null:
			hit = _blocked_turned(key, mesh, to, turned)
			if check_covers:
				var whole: PackedInt64Array = _blocked(key, mesh, to, builder.boxes_for(mesh, to))
				covers_checked += 1
				if whole.is_empty() != hit.is_empty():
					covers_differ += 1
					print("    COVER DIFFERS: #%d %s whole %s, asked %s" % [key, brick.part_id, whole, hit])
		else:
			var packed: PackedInt32Array = builder.boxes_for(mesh, to)
			cover_us = Time.get_ticks_usec() - part_began
			hit = _blocked(key, mesh, to, packed)
		var part_us: int = Time.get_ticks_usec() - part_began
		if part_us > frame_slowest_us:
			frame_slowest_us = part_us
			frame_slowest_said = "#%d %s %.1f ms" % [key, brick.part_id, part_us / 1000.0]
		if part_us > slowest_us:
			slowest_us = part_us
			slowest_said = "#%d %s: cover %.1f ms, blockers %.1f ms; its box is into #%d %s's" % [key,
				brick.part_id, cover_us / 1000.0, (part_us - cover_us) / 1000.0, _near_part,
				world.get_brick(_near_part).part_id if world.get_brick(_near_part) != null else "?"]
		if not hit.is_empty():
			blocked_by = [key, int(hit[0])]
			met = key
			stretch_words = ""
			result = 0
			break
	# Then the loop's own joints, each pair of parts that make one (counted on
	# from the moving parts, so a test cut short goes on from where it was).
	# A pair's test is not begun where what it took last would pass the
	# budget, unless it is the first this call asks: a steering arm against
	# the plate its kingpin is in took 8808-1's pause 20 ms past its budget on
	# a phone at a quarter speed.
	while result == 1 and pairs and n < keys.size() + _joint_pairs.size():
		var spent: float = float(Time.get_ticks_usec() - started) / 1000.0
		var k: int = n - keys.size()
		if budget < INF and (spent > budget or n > from and spent + float(_pair_clear[k][5]) > budget):
			result = -1
			break
		n += 1
		var asked: int = Time.get_ticks_usec()
		if not _pair_clear_at(k, at):
			result = 0
		var took: float = float(Time.get_ticks_usec() - asked) / 1000.0
		if took > 0.05:
			var kept: PackedFloat64Array = _pair_clear[k]
			kept[5] = took
			_pair_clear[k] = kept
	test_ms = float(Time.get_ticks_usec() - started) / 1000.0
	frame_test_ms += test_ms
	frame_tests += 1
	return Vector2i(result, n if result == -1 else 0)


## A loop's joints turn their own two parts against each other, and nothing
## else tests one against the other: 21019-1's turntable turned a loop of 11
## joints 10°, and left a plate with a handle 2.42 LDU into the plate with
## a clip on its handle; the next grab began with them into each other,
## forgave them, and went 60° through the clip. Each pair of parts that makes
## one of the loop's joints is tested against each other, by their exact
## shapes, but not one that cannot meet as the joint turns: a pin, an axle
## or a round part on the joint's line, which turns in place, or two parts a
## plane square to the line keeps apart (a beam on a beam), further than the
## joint slides. Only a hinge's, a click hinge's or a turntable's ([constant
## PAIR_KINDS]): two parts built side by side to turn against each other, as
## 21019-1's clip on its handle, which the loop slid along the handle's bar
## 4.3 LDU into the handle's plate. An axle or a pin may slide in its hole as
## far as its reading lets it, and a loop whose other joints are read loosely
## closes by those slides: tested, 8448-1's racer and 5533-1 steered 1° and
## 2° before a towball and a steering arm met the rack and the brick they are
## in, 1 to 2 LDU along the axle (they steered 11° and 10°). Not a ball's
## either. Asked every frame, the six pairs of 8808-1's steering (its arms in
## two plates each) took its drag's room test from 0.5 ms a frame to 5 to 10,
## so a loop's drag asks them on the pause, with its way ([method turn_to]).
func _meeting_pairs() -> void:
	_joint_pairs.clear()
	_pair_clear.clear()
	if linkage == null:
		return
	var joints: Array[Bodies.Link] = []
	joints.append_array(linkage.links)
	joints.append_array(linkage.closing)
	for joined: Bodies.Link in joints:
		if not joined.kind in PAIR_KINDS:
			continue
		var line: Vector3 = joined.axis.normalized()
		var apart: float = PAIR_APART - joined.slide.x - joined.slide.y
		for pair: Array in joined.pairs:
			var one: int = int(pair[0])
			var other: int = int(pair[1])
			if not moving.has(one) and not moving.has(other):
				continue
			var a: BrickWorld.Brick = world.get_brick(one)
			var b: BrickWorld.Brick = world.get_brick(other)
			var mesh_a: Lbm.PartMesh = library.mesh_for(a.part_id) if a != null else null
			var mesh_b: Lbm.PartMesh = library.mesh_for(b.part_id) if b != null else null
			if mesh_a == null or mesh_b == null:
				continue
			var turns_in_place: bool = false
			for key: int in [one, other]:
				if _thin_on(key, joined.point, line) or _round_on(key, joined.point, line):
					turns_in_place = true
			if turns_in_place:
				continue
			var reach_a: Vector2 = Grab._reach_along(a.transform, mesh_a.bounds, line)
			var reach_b: Vector2 = Grab._reach_along(b.transform, mesh_b.bounds, line)
			if reach_a.y <= reach_b.x + apart or reach_b.y <= reach_a.x + apart:
				continue
			var local: Vector3 = (b.transform.basis.inverse() * line).normalized()
			var square: Vector3 = (Vector3.UP if absf(local.y) < 0.9 else Vector3.RIGHT).cross(local).normalized()
			_joint_pairs.append([one, other, local, square,
				(b.transform.basis.inverse() * a.transform.basis).inverse(),
				a.transform.affine_inverse() * joined.point, b.transform.affine_inverse() * joined.point,
				(a.transform.basis.inverse() * line).normalized(), joined.slide.x + joined.slide.y])
			_pair_clear.append(PackedFloat64Array([0.0, 0.0, 0.0, 0.0, PAIR_UNKNOWN, 0.0]))


## The joints whose own two parts are tested against each other in a loop
## ([method _meeting_pairs]).
const PAIR_KINDS: Array[String] = ["hinge", "click", "turntable"]
## Two parts' boxes this far into each other along a joint's line, LDU, are
## kept apart by a plane square to it ([method _meeting_pairs]): faces
## built flush.
const PAIR_APART := 0.5
## A joint turned this far past the turns found clear, radians, or slid this
## far, LDU, is asked again ([method _pair_clear_at]).
const PAIR_SAME := 0.0001
const PAIR_SLIDE_SAME := 0.01


## Whether the [param n]th of [member _joint_pairs] is clear of each other at
## [param at]: asked by their exact shapes only where the joint has turned or
## slid past what was already found clear, which then grows to take it in.
## Where the two meet, [member blocked_by] says them.
func _pair_clear_at(n: int, at: Dictionary) -> bool:
	var pair: Array = _joint_pairs[n]
	var one: int = pair[0]
	var other: int = pair[1]
	var at_one: Transform3D = at.get(one, rest.get(one, world.get_brick(one).transform))
	var at_other: Transform3D = at.get(other, rest.get(other, world.get_brick(other).transform))
	var turned: Basis = at_other.basis.inverse() * at_one.basis * (pair[4] as Basis)
	var line: Vector3 = pair[2]
	var square: Vector3 = pair[3]
	var to: Vector3 = turned * square
	var turn: float = atan2(line.dot(square.cross(to)), square.dot(to))
	var slide: float = (at_other.affine_inverse() * (at_one * (pair[5] as Vector3)) - (pair[6] as Vector3)).dot(line)
	var clear: PackedFloat64Array = _pair_clear[n]
	if clear[4] == PAIR_FORGIVEN or clear[4] == PAIR_NEVER \
			or turn >= clear[0] - PAIR_SAME and turn <= clear[1] + PAIR_SAME \
			and slide >= clear[2] - PAIR_SLIDE_SAME and slide <= clear[3] + PAIR_SLIDE_SAME:
		return true
	var a: BrickWorld.Brick = world.get_brick(one)
	var b: BrickWorld.Brick = world.get_brick(other)
	var shape_a: Exact.Shape = Exact.shape_for(library, a.part_id)
	var shape_b: Exact.Shape = Exact.shape_for(library, b.part_id)
	if clear[4] == PAIR_UNKNOWN and shape_a != null and shape_b != null and shape_a.has_pieces() \
			and shape_b.has_pieces():
		# Each part's pieces only where the other reaches along the line, and
		# as far again as the joint slides: none further can meet it.
		var way: Vector3 = (b.transform.basis * line).normalized()
		var middle: float = (b.transform * (pair[6] as Vector3)).dot(way)
		var reach_a: Vector2 = Grab._reach_along(a.transform, library.mesh_for(a.part_id).bounds, way) \
			- Vector2(middle, middle)
		var reach_b: Vector2 = Grab._reach_along(b.transform, library.mesh_for(b.part_id).bounds, way) \
			- Vector2(middle, middle)
		var spare: float = float(pair[8]) + PAIR_ALONG_SLACK
		# Kept by the two shapes and where the joint is in each: the same pair
		# in the next grab is not read again.
		var key: String = "%d|%d|%s|%s|%s|%s|%.2f" % [shape_a.id, shape_b.id,
			(pair[5] as Vector3).snapped(Vector3.ONE * 0.01), (pair[7] as Vector3).snapped(Vector3.ONE * 0.0001),
			(pair[6] as Vector3).snapped(Vector3.ONE * 0.01), line.snapped(Vector3.ONE * 0.0001), float(pair[8])]
		var apart: Variant = _apart_known.get(key)
		if apart == null:
			apart = Grab._pieces_apart(Grab._about_line(shape_a, pair[5], pair[7], reach_b.x - spare, reach_b.y + spare),
				Grab._about_line(shape_b, pair[6], line, reach_a.x - spare, reach_a.y + spare), float(pair[8]))
			if _apart_known.size() > 2000:
				_apart_known.clear()
			_apart_known[key] = apart
		if bool(apart):
			clear[4] = PAIR_NEVER
			_pair_clear[n] = clear
			return true
	if clear[4] == PAIR_UNKNOWN:
		# Into each other where the grab began, or one with no exact shape
		# (covers cannot judge a joint's own pieces): forgiven, as the rest of
		# the room test forgives such a pair. Asked here, not at the press:
		# for six pairs, reading their shapes and asking took 8808-1's
		# steering's press from 6 ms to 19.
		clear[4] = PAIR_FORGIVEN if shape_a == null or shape_b == null or not shape_a.has_pieces() \
			or not shape_b.has_pieces() or not Exact.clash(Exact.Item.new(shape_a, a.transform),
			Exact.Item.new(shape_b, b.transform)).is_empty() else PAIR_APART_AT_REST
		_pair_clear[n] = clear
		if clear[4] == PAIR_FORGIVEN:
			return true
	if Exact.clash(Exact.Item.new(shape_a, at_one), Exact.Item.new(shape_b, at_other)).is_empty():
		_pair_clear[n] = PackedFloat64Array([minf(clear[0], turn), maxf(clear[1], turn),
			minf(clear[2], slide), maxf(clear[3], slide), clear[4], clear[5]])
		return true
	blocked_by = [one, other] if moving.has(one) else [other, one]
	met = int(blocked_by[0])
	stretch_words = ""
	return false


## Each piece of [param shape] about the line through [param point] along
## [param way] (the part's own frame) that reaches between [param from] and
## [param to] along it: [least and most along the line, least and most from
## it]. A turn about the line keeps each point's place along
## it and its distance from it, so two parts whose pieces share no place
## there cannot meet as their joint turns: 8808-1's steering arms, whose
## kingpins go through two plates each; where the plates are along the line
## only the kingpin is, narrower than their holes. Kept by shape and line.
static func _about_line(shape: Exact.Shape, point: Vector3, way: Vector3, from: float = -INF,
		to: float = INF) -> Array:
	var key: String = "%d|%s|%s|%.1f|%.1f" % [shape.id, point.snapped(Vector3.ONE * 0.01),
		way.snapped(Vector3.ONE * 0.0001), from, to]
	var known: Variant = _footprints.get(key)
	if known != null:
		return known
	var u: Vector3 = (Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT).cross(way).normalized()
	var v: Vector3 = way.cross(u)
	var out: Array = []
	var flat := PackedVector2Array()
	var spread := Vector3(absf(way.x), absf(way.y), absf(way.z))
	for piece: Exact.Piece in shape.pieces:
		# Its box first: a piece wholly outside [from, to] along the line is
		# left out ([param from] and [param to] from [param point]).
		var middle: float = ((piece.lo + piece.hi) * 0.5 - point).dot(way)
		var half: float = ((piece.hi - piece.lo) * 0.5).dot(spread)
		if middle + half < from or middle - half > to:
			continue
		var lo: float = INF
		var hi: float = -INF
		var far: float = 0.0
		flat.resize(0)
		for vert: Vector3 in piece.verts:
			var d: Vector3 = vert - point
			var along: float = d.dot(way)
			lo = minf(lo, along)
			hi = maxf(hi, along)
			var across := Vector2(d.dot(u), d.dot(v))
			flat.append(across)
			far = maxf(far, across.length())
		# How near the line the piece comes: none where the line goes through
		# it, else the nearest edge of its outline seen along the line.
		var near: float = 0.0
		var hull: PackedVector2Array = Geometry2D.convex_hull(flat)
		if hull.size() >= 4 and not Geometry2D.is_point_in_polygon(Vector2.ZERO, hull):
			near = INF
			for k: int in hull.size() - 1:
				near = minf(near, Geometry2D.get_closest_point_to_segment(Vector2.ZERO, hull[k], hull[k + 1]).length())
		out.append(PackedFloat32Array([lo, hi, near, far]))
	if _footprints.size() > 2000:
		_footprints.clear()
	_footprints[key] = out
	return out


static var _footprints: Dictionary = {}
static var _apart_known: Dictionary = {}
## Two pieces this far into each other along a joint's line, or across it,
## LDU, as [method _about_line] reads them, can still not be said to meet:
## a face flush on a face, a kingpin's facets in its hole's (a quarter of
## Exact's own TAU).
const PAIR_ALONG_SLACK := 0.25
const PAIR_ACROSS_SLACK := 0.25


## Whether no piece of one part ([param a], as [method _about_line] reads
## it) shares a place along the line and a distance from it with a piece of
## the other ([param b]), the other slid as far as [param slide] either way.
static func _pieces_apart(a: Array, b: Array, slide: float) -> bool:
	# The other's pieces by where they lie along the line, a cell every 4 LDU,
	# and how near the line any of them comes: a piece of this one no further
	# out than that meets none (a kingpin in its holes).
	var cells: Dictionary = {}   ## cell -> Array of indices into b
	var nearest: float = INF
	for k: int in b.size():
		var one: PackedFloat32Array = b[k]
		nearest = minf(nearest, one[2])
		for cell: int in range(floori((one[0] - slide) / 4.0), floori((one[1] + slide) / 4.0) + 1):
			var list: Variant = cells.get(cell)
			if list == null:
				cells[cell] = [k]
			else:
				(list as Array).append(k)
	for mine: PackedFloat32Array in a:
		if mine[3] - nearest <= PAIR_ACROSS_SLACK:
			continue
		for cell: int in range(floori(mine[0] / 4.0), floori(mine[1] / 4.0) + 1):
			for k: int in cells.get(cell, []):
				var theirs: PackedFloat32Array = b[k]
				if minf(mine[1], theirs[1] + slide) - maxf(mine[0], theirs[0] - slide) > PAIR_ALONG_SLACK \
						and minf(mine[3], theirs[3]) - maxf(mine[2], theirs[2]) > PAIR_ACROSS_SLACK:
					return false
	return true


## Where [param key] is tested for room with the parts at [param at]: a part
## round on a joint the loop carries, where what carries it stands
## ([param carried_at], Linkage.places as the test's pose has it), unturned;
## else as [method _shape_at] has it.
func _tested_at(key: int, at: Dictionary, carried_at: Dictionary) -> Transform3D:
	if _spin_with.has(key) and not carried_at.is_empty() and rest.has(key):
		return (carried_at.get(_spin_with[key], Transform3D.IDENTITY) as Transform3D) * (rest[key] as Transform3D)
	return _shape_at(key, at[key])


## Where [param key]'s shape stands with the part at [param to]: for a part
## round about its own middle's line along the joint's ([member _round_self]),
## its shape as it stood moved so its middle is where the turn puts it; else
## [param to].
func _shape_at(key: int, to: Transform3D) -> Transform3D:
	if not _round_self.has(key) or not rest.has(key):
		return to
	var middle: Vector3 = _round_self[key]
	var stood: Basis = (rest[key] as Transform3D).basis
	return Transform3D(stood, to * middle - stood * middle)


## Whether each moving part at [param at] may meet anything ([method
## _near_anything], [method _boxes_meet]): key -> bool, for [method _test]
## to read rather than ask again. The turned covers of those that may, not
## worked out yet, are worked out side by side on the engine's workers and
## kept as [method Builder.boxes_for] keeps its own: a four-bar's frame asked
## for its two wheels' and two arms' covers, 11 to 16 ms each, one after the
## other. Nothing ahead on a build without threads, or for one cover.
func _covers_ahead(at: Dictionary, keys: Array, carried_at: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	# Not in a browser: its workers start when first asked, and the first
	# drag's frame waited 1.3 s for them.
	if OS.has_feature("web"):
		return out
	var wanted: Array = []   ## [mesh, basis]
	var asked: Dictionary = {}
	for key: int in keys:
		if _on_the_line.has(key) or not at.has(key):
			continue
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			continue
		var to: Transform3D = _tested_at(key, at, carried_at)
		var box: AABB = to * mesh.bounds
		var may: bool = _near_anything(box, key) and _boxes_meet(key, mesh, to, box)
		out[key] = may
		if not may or not builder.turned_wanted(mesh, to.basis):
			continue
		var exact: String = "%d|%s" % [mesh.get_instance_id(), to.basis]
		if not asked.has(exact):
			asked[exact] = true
			wanted.append([mesh, to.basis])
	if wanted.size() < 2:
		return out
	var made: Array = []
	made.resize(wanted.size())
	var writing := Mutex.new()
	var tasks: Array[int] = []
	for n: int in wanted.size():
		var mesh: Lbm.PartMesh = wanted[n][0]
		var basis: Basis = wanted[n][1]
		var job := func() -> void:
			var shape: PackedInt32Array = BrickLattice.boxes_for_turned(mesh.boxes, Vector3i.ZERO, basis)
			writing.lock()
			made[n] = shape
			writing.unlock()
		# The first of the app's run here, before others run it at once
		# (WorkerTasks.first_here).
		if not WorkerTasks.first_here("a turned cover", job):
			tasks.append(WorkerTasks.add(job, true, "a grabbed part's turned cover"))
	for task: int in tasks:
		WorkerTasks.collect(task)
	for n: int in wanted.size():
		builder.keep_turned(wanted[n][0], wanted[n][1], made[n])
	return out


## Parts that touched where the model was built, kept from one grab to the
## next: "brick id:part" -> {brick id: part} of what each touched before a
## grab moved either. A grab forgives for good what its moving side touched
## where it began; turned out and back in three moves, the third began away
## from what the part was built against and met it short of where it was
## built (10220-1's door at 18 degrees, 8855-1's steering). Moves in turn
## are one drag: what touched as built is not in the way of coming back.
static var _built_touching: Dictionary = {}
## Parts a grab has moved since [member _built_touching] began, and the world
## and part count it was kept for.
static var _moved_since_built: Dictionary = {}
## Where each of those stood before a grab first moved it: brick id ->
## Transform3D. A joint's turn from where it was built is read against it
## ([method from_built]).
static var _built_at: Dictionary = {}
static var _built_for: int = 0
static var _built_count: int = -1


## Every room test asks a turned part's cover whole too, and counts where
## the two answer differently: for a probe.
static var check_covers: bool = false
static var covers_checked: int = 0
static var covers_differ: int = 0


## What [param key] at [param to], its cover [param turned] asked where each
## part near it is, meets, as [method _blocked] says of the whole cover: the
## first part met that it did not overlap where it stood, slide over or only
## touch, or nothing.
func _blocked_turned(key: int, mesh: Lbm.PartMesh, to: Transform3D,
		turned: BrickLattice.TurnedCover) -> PackedInt64Array:
	var short: bool = BrickLattice.is_off_lattice(to.origin)
	var near: PackedInt32Array = turned.loose_at()
	for other: int in builder.lattice.blockers_boxes(Grab._reach_cell(near, true) if short else near, 0, skip):
		# Its box first (as [method _boxes_meet] asks it): the cover is asked
		# where something is box by box, and 42081-1's fairing against the
		# 2,573 boxes of a frame its box was not into took 42 ms a frame.
		# What it may go through whatever the pose (its partner across the
		# joint, what it touched as built) is not asked of the cover at all:
		# asked first, box by box and then by the cover, 8808-1's steering
		# arms took a frame 0.4 ms each on the plates their kingpins stand
		# in, ten times what they took before Grab 17 tested those plates.
		if skip.has(other) or _verdict_of(key, other) == FORGIVEN or _scrubs(key, other) \
				or _bends_aside(other) or not _into_cover(mesh, to, to * mesh.bounds, other):
			continue
		# Theirs a cell further back is ours a cell further on.
		var theirs: PackedInt32Array = builder.lattice.boxes_of(other)
		if not turned.meets(Grab._reach_cell(theirs, false) if short and _both_exact(key, other) else theirs):
			continue
		if not _pair_forgiven(key, other, mesh, to) and not _slides_over(key, mesh, to, other) \
				and not _touching(mesh, to, other) and not _clear_exactly(key, to, other):
			return PackedInt64Array([other])
	return PackedInt64Array()


## What [param key], its cover [param packed] at [param to], meets: nothing
## but what the moving side may press on. What it overlapped where it stood
## is forgiven for good; what it slides over across a face square to the
## line it turns on, for this part alone ([method _slides_over]).
##
## A cover is counted from the cell its part's origin is in, so off the
## lattice it stands up to a cell short of the part towards +x, +y and +z.
## 4096-1's boom, turned 96.7° on its hinge, was 1.24 LDU into the hinge's
## base by their shapes and its cover clear of the base's: the drag stopped
## at 95.7° and the room test found room a degree on. So a part off the
## lattice asks its cover a cell further on for any pair whose exact shapes
## then judge it ([method _clear_exactly]); a pair with no exact shape is
## judged by the cover as it was.
func _blocked(key: int, mesh: Lbm.PartMesh, to: Transform3D, packed: PackedInt32Array) -> PackedInt64Array:
	var forgiven: Array = []
	var short: bool = BrickLattice.is_off_lattice(to.origin)
	var asked: PackedInt32Array = Grab._reach_cell(packed, true) if short else packed
	var by_cover: Variant = null
	var hit: PackedInt64Array = builder.lattice.blockers_boxes(asked, 0, skip)
	while not hit.is_empty():
		var other: int = int(hit[0])
		var missed: bool = false
		if short and not _both_exact(key, other):
			if by_cover == null:
				by_cover = builder.lattice.blockers_boxes(packed, 0, skip)
			missed = not (by_cover as PackedInt64Array).has(other)
		if missed or _pair_forgiven(key, other, mesh, to) or _scrubs(key, other) or _bends_aside(other) \
				or _slides_over(key, mesh, to, other) or _touching(mesh, to, other) \
				or _clear_exactly(key, to, other):
			skip[other] = true
			forgiven.append(other)
		else:
			break
		hit = builder.lattice.blockers_boxes(asked, 0, skip)
	for other: int in forgiven:
		skip.erase(other)
	return hit


## [param packed], boxes of cells as the lattice keeps them, each reaching a
## cell further towards +x, +y and +z ([param on]), or further back towards
## -x, -y and -z: where a cover counted from its origin's cell may fall short
## of its part ([method _blocked]).
static func _reach_cell(packed: PackedInt32Array, on: bool) -> PackedInt32Array:
	var out: PackedInt32Array = packed.duplicate()
	var first: int = 3 if on else 0
	var by: int = 1 if on else -1
	for n: int in range(0, out.size(), 6):
		out[n + first] += by
		out[n + first + 1] += by
		out[n + first + 2] += by
	return out


## Whether [param key] at [param to] and [param other] where it stands are
## clear of each other by their exact shapes (Exact: BrickNet's convex
## pieces), overlapping by no more than the 1 LDU a build check allows: what
## their covers met, 2 LDU cells that each reach past the part, the parts do
## not. 10220-1's floor (a plate with rounded pins beside a tile 2 x 4),
## 10295-1's door (two slopes 75 built side by side) and 10185-1's hinge
## plates on a plate with studs on one edge would not turn at all by their
## covers, and their shapes are clear of each other at every degree. A part
## with no exact shape is judged by its cover.
func _clear_exactly(key: int, to: Transform3D, other: int) -> bool:
	var a: BrickWorld.Brick = world.get_brick(key)
	var b: BrickWorld.Brick = world.get_brick(other)
	if a == null or b == null:
		return false
	var shape_a: Exact.Shape = Exact.shape_for(library, a.part_id)
	var shape_b: Exact.Shape = Exact.shape_for(library, b.part_id)
	if shape_a == null or shape_b == null or not shape_a.has_pieces() or not shape_b.has_pieces():
		return false
	return Exact.clash(Exact.Item.new(shape_a, to), Exact.Item.new(shape_b, b.transform)).is_empty()


## Whether [param other] bends out of the way: a hose's piece, a string's,
## or a flexible part a file draws whole (a cable, a rubber band:
## Bodies.bends). 8074-1's crane turned on its turntable and stopped where
## its frame met the cable's skin hanging from it, and 10252-1's arm where it
## met a rubber band.
func _bends_aside(other: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(other)
	return brick != null and Bodies.bends(library, brick.part_id)


## Whether [param key] is a tyre and [param other] the baseplate it stands
## on: rubber on the floor scrubs round as its wheel is steered, and the
## floor is not in its way (that it goes no lower is the floor's own test).
## 8063-1's and 42075-1's steering stopped where a front tyre met the
## baseplate at the first degree.
func _scrubs(key: int, other: int) -> bool:
	if not bodies.scenery.has(other):
		return false
	var brick: BrickWorld.Brick = world.get_brick(key)
	return brick != null and Bodies._is_tyre(library.parts.get(brick.part_id))


## Whether [param key] at [param to] only slides over [param other] across a
## face square to the line the section turns on: its reach along that line
## is what it was where it stood, and there it met [param other] end to end
## along the line, by no more than a stud's height (a steering arm turning on
## the brick it sits on, a turntable's top on its base). A turn about the
## line keeps every point's place along it, so the two meet no more than
## they did; the 2 LDU cells of a turned part's cover cannot tell. The
## cover counted them as one, and the arm would not turn at all.
func _slides_over(key: int, mesh: Lbm.PartMesh, to: Transform3D, other: int) -> bool:
	if mode == "ball" or axis == Vector3.ZERO or not rest.has(key):
		return false
	var them: BrickWorld.Brick = world.get_brick(other)
	var their_mesh: Lbm.PartMesh = library.mesh_for(them.part_id) if them != null else null
	if their_mesh == null:
		return false
	if _along_for != axis:
		_along_for = axis
		_along.clear()
	var now: Vector2 = Grab._reach_along(to, mesh.bounds, axis)
	# Where it stood and where the other stands, kept for the grab: neither
	# moves while it lasts.
	if not _along.has(key):
		_along[key] = Grab._reach_along(rest[key], mesh.bounds, axis)
	var was: Vector2 = _along[key]
	if absf(now.x - was.x) > 0.5 or absf(now.y - was.y) > 0.5:
		return false
	if not _along.has(other):
		_along[other] = Grab._reach_along(them.transform, their_mesh.bounds, axis)
	var theirs: Vector2 = _along[other]
	var end_on: float = Joints.STUD_REACH + 0.5
	return theirs.y - was.x <= end_on or was.y - theirs.x <= end_on


## [method _slides_over]'s reaches along the grab's line, of the moving
## parts where they stood and of what they may meet: brick id -> Vector2.
var _along: Dictionary = {}
var _along_for := Vector3.ZERO


## Whether the part [param mesh] at [param to] and [param other] only touch:
## their boxes, each turned as it stands, are apart or into each other by no
## more than [constant TOUCHING] along some line (the separating axis test:
## each box's three edges and the nine lines square to a pair of them). A
## steering arm turned 3° beside the brick it was built flush against met it
## by one of its turned cover's 2 LDU cells, and at 10° not at all.
func _touching(mesh: Lbm.PartMesh, to: Transform3D, other: int) -> bool:
	var them: BrickWorld.Brick = world.get_brick(other)
	var their_mesh: Lbm.PartMesh = library.mesh_for(them.part_id) if them != null else null
	if their_mesh == null:
		return false
	return Grab.box_depth(to, mesh.bounds, them.transform, their_mesh.bounds) <= TOUCHING


## How far two boxes, each at its own transform, are into each other: the
## least overlap of their shadows on the fifteen lines of the separating
## axis test, LDU; below zero they are apart.
static func box_depth(a_at: Transform3D, a_box: AABB, b_at: Transform3D, b_box: AABB) -> float:
	# Each box as its middle and its three half edges, carried: its shadow on
	# a line reaches the half edges' reaches either side of its middle's.
	# Held in locals, not arrays: asked for every pair near a moving part
	# every frame, the arrays were most of what it cost.
	var a_mid: Vector3 = a_at * a_box.get_center()
	var b_mid: Vector3 = b_at * b_box.get_center()
	var a0: Vector3 = a_at.basis[0] * (a_box.size.x * 0.5)
	var a1: Vector3 = a_at.basis[1] * (a_box.size.y * 0.5)
	var a2: Vector3 = a_at.basis[2] * (a_box.size.z * 0.5)
	var b0: Vector3 = b_at.basis[0] * (b_box.size.x * 0.5)
	var b1: Vector3 = b_at.basis[1] * (b_box.size.y * 0.5)
	var b2: Vector3 = b_at.basis[2] * (b_box.size.z * 0.5)
	var a_lines: PackedVector3Array = [a_at.basis[0].normalized(), a_at.basis[1].normalized(),
		a_at.basis[2].normalized()]
	var b_lines: PackedVector3Array = [b_at.basis[0].normalized(), b_at.basis[1].normalized(),
		b_at.basis[2].normalized()]
	var lines: PackedVector3Array = [a_lines[0], b_lines[0], a_lines[1], b_lines[1], a_lines[2], b_lines[2]]
	for i: int in 3:
		for j: int in 3:
			var across: Vector3 = a_lines[i].cross(b_lines[j])
			if across.length() > 0.001:
				lines.append(across.normalized())
	var least: float = INF
	for way: Vector3 in lines:
		var a_at_way: float = a_mid.dot(way)
		var a_reach: float = absf(a0.dot(way)) + absf(a1.dot(way)) + absf(a2.dot(way))
		var b_at_way: float = b_mid.dot(way)
		var b_reach: float = absf(b0.dot(way)) + absf(b1.dot(way)) + absf(b2.dot(way))
		least = minf(least, minf(a_at_way + a_reach, b_at_way + b_reach) - maxf(a_at_way - a_reach, b_at_way - b_reach))
	return least


## How far [param box] at [param at] reaches along [param way]: (lo, hi).
static func _reach_along(at: Transform3D, box: AABB, way: Vector3) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for corner: int in 8:
		var along: float = (at * box.get_endpoint(corner)).dot(way)
		lo = minf(lo, along)
		hi = maxf(hi, along)
	return Vector2(lo, hi)


## Whether [param key] is round about the line through [param point] along
## [param way] and centred on it: a wheel, a tyre, a gear, a pulley, a round
## plate on its axle, a cone. Turning on that line it sweeps only where it
## is, so it is never tested (a tyre resting on the floor, turned with its
## axle, met the floor by its turned cover's cells); turning about a line
## beside it, along that one, it is its own shape moved ([member _round_self]).
## Whether [param key] lies all within [constant ON_THE_LINE] of the line
## through [param point] along [param way] (its box's corners within that
## of it, a square's diagonal over): an axle or a pin on the line.
func _thin_on(key: int, point: Vector3, way: Vector3) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(key)
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	if mesh == null:
		return false
	for corner: int in 8:
		var off: Vector3 = brick.transform * mesh.bounds.get_endpoint(corner) - point
		if (off - way * off.dot(way)).length() > ON_THE_LINE * 1.42:
			return false
	return true


func _round_on(key: int, point: Vector3, way: Vector3) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(key)
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
	if info == null:
		return false
	var name: String = info.name.to_lower()
	var round_name: bool = false
	for word: String in ["tyre", "tire", "wheel", "gear", "pulley", "rim", "round", "bush", "disk", "cone"]:
		if name.contains(word):
			round_name = true
			break
	if not round_name:
		return false
	var centre: Vector3 = brick.transform * info.bounds.get_center()
	var off: Vector3 = centre - point
	if (off - way * off.dot(way)).length() > 2.0:
		return false
	var local: Vector3 = (brick.transform.basis.inverse() * way).normalized()
	var size: Vector3 = info.bounds.size
	for k: int in 3:
		if absf(local[k]) > 0.999:
			var a: float = size[(k + 1) % 3]
			var b: float = size[(k + 2) % 3]
			return absf(a - b) <= 2.0
	return false


## Whether [param key], a moving part, may go through [param other] for the
## rest of the grab: their covers overlap where both stand when it was
## grabbed, or they touched as built and are kept so ([method
## _forgiven_at_rest]). The pair, not [param other] for every moving part
## (G13): a move stopped where two parts just meet begins the next with their
## covers into each other, and forgiven for all of the moving side, 10220-1's
## door went on from the tile its plate 1 x 1 round had stopped at through
## that tile, with its plate 2 x 8, at -17°. Where one of the two has no
## exact shape it is judged by its cover, which reaches past it, and what
## overlapped any moving part where it stood is forgiven for all of them, as
## before: 42042-1's winch drum, a file's own part, met an axle by their
## covers 66° round. But only so far ([method _no_deeper]): forgiven whole,
## a section stopped against a part with no exact shape went through it on
## its next move. Asked when first met, as asking every moving part at the
## press would answer, so a turn tested later finds what one tested earlier
## found. [param mesh] at [param to]: where [param key] is tested.
func _pair_forgiven(key: int, other: int, mesh: Lbm.PartMesh, to: Transform3D) -> bool:
	var verdict: int = _verdict_of(key, other)
	return verdict == FORGIVEN or verdict == NO_DEEPER and _no_deeper(key, other, mesh, to)


## [method _verdict] for the pair, kept for the grab ([member _verdicts]).
func _verdict_of(key: int, other: int) -> int:
	var pair := Vector2i(key, other)
	var verdict: int = int(_verdicts.get(pair, -1))
	if verdict < 0:
		verdict = _verdict(key, other)
		_verdicts[pair] = verdict
	return verdict


## [method _pair_forgiven]'s answer for the grab, but where it is the pair's
## depth now: [constant FORGIVEN], [constant NO_DEEPER] or 0, never.
func _verdict(key: int, other: int) -> int:
	var across: Dictionary = _across.get(other, {})
	if across.has(key):
		return FORGIVEN
	var with: Dictionary = _rest_with(other)
	if with.has(key) or _touched_as_built(key, other):
		return FORGIVEN if _both_exact(key, other) else NO_DEEPER
	# Not for the parts joined to it: an axle is in its bearing as built, and
	# says nothing of how far a cover reaches past its part. Their shapes are
	# asked last: read from disk the first time, 16 of them took 42081-1's
	# arm's drag frame 49 ms.
	for one: int in with:
		if not across.has(one):
			return 0 if _both_exact(key, other) else NO_DEEPER
	return 0


## [method _verdict]s: forgiven whatever the pose, or as far as no deeper
## ([method _no_deeper]).
const FORGIVEN := 1
const NO_DEEPER := 2
## Each pair's [method _verdict] for the grab, Vector2i(moving, other) -> it:
## asked of every part near each moving part every frame, it read the parts'
## names and shapes afresh each time, a fifth of 8808-1's steering's room
## test once its front wheels were tested against the plates their kingpins
## stand in (Grab 17). What it reads stays as it is while the grab lasts.
var _verdicts: Dictionary = {}


## Whether [param key]'s box, [param mesh] at [param to], is no further into
## [param other]'s than where the grab began or where the two were built,
## and [constant TOUCHING] more: the measure of a pair judged by covers,
## which cannot tell parts built flush from parts into each other. A move
## away is forgiven, and back to where it began; a move on into it is not.
## The covers of a door stopped where they met began its next move into
## each other, and forgiven whole, the door went on through.
func _no_deeper(key: int, other: int, mesh: Lbm.PartMesh, to: Transform3D) -> bool:
	var them: BrickWorld.Brick = world.get_brick(other)
	var their_mesh: Lbm.PartMesh = library.mesh_for(them.part_id) if them != null else null
	if mesh == null or their_mesh == null:
		return true
	var pair := Vector2i(key, other)
	if not _depth_allowed.has(pair):
		var from: Transform3D = rest.get(key, world.get_brick(key).transform)
		var allowed: float = _depth_between(key, mesh, from, other, them.transform, their_mesh)
		_built_for_world()
		if _built_at.has(key) or _built_at.has(other):
			allowed = maxf(allowed, _depth_between(key, mesh, _built_at.get(key, from), other,
				_built_at.get(other, them.transform), their_mesh))
		_depth_allowed[pair] = allowed + TOUCHING
	return _depth_between(key, mesh, to, other, them.transform, their_mesh) <= float(_depth_allowed[pair])


## How far [param key] ([param mesh] at [param at]) is into [param other]
## ([param their_mesh] at [param their_at]), LDU: by their boxes, but where
## one is a round part with no exact shape of its own and the other has one
## (or is round too), by the round it makes against that shape
## (Exact.round_of), nought where those are clear. A tyre steered about its
## kingpin swings its box's corners where the tyre is not: 8820-1's, built
## against its steering top, stopped at 6° of 30 on that, its round 0.09 LDU
## clear of the top's shape all the way.
func _depth_between(key: int, mesh: Lbm.PartMesh, at: Transform3D, other: int, their_at: Transform3D,
		their_mesh: Lbm.PartMesh) -> float:
	var mine: Array = _shape_or_round(key, mesh)
	var theirs: Array = _shape_or_round(other, their_mesh)
	if mine.is_empty() or theirs.is_empty() or not (bool(mine[1]) or bool(theirs[1])):
		return Grab.box_depth(at, mesh.bounds, their_at, their_mesh.bounds)
	var into: Dictionary = Exact.clash(Exact.Item.new(mine[0], at), Exact.Item.new(theirs[0], their_at))
	return float(into.get("depth", 0.0))


## [param key]'s exact shape and false, or where it has none and is a tyre
## (as its name says, its box two sides alike), the round its box makes and
## true; or [] for neither. Not a wheel's rim: 8845-1's, judged by its round,
## let its steering on past -24° to -52°, where its axle pin is read in its
## track rod's hole and the steering arm one body with the rod.
func _shape_or_round(key: int, mesh: Lbm.PartMesh) -> Array:
	var brick: BrickWorld.Brick = world.get_brick(key)
	if brick == null or mesh == null:
		return []
	var shape: Exact.Shape = Exact.shape_for(library, brick.part_id)
	if shape != null and shape.has_pieces():
		return [shape, false]
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	var name: String = info.name.to_lower() if info != null else ""
	if not (name.contains("tyre") or name.contains("tire")):
		return []
	var size: Vector3 = mesh.bounds.size
	for k: int in 3:
		var a: float = size[(k + 1) % 3]
		var b: float = size[(k + 2) % 3]
		if absf(a - b) <= 2.0 and size[k] < minf(a, b):
			return [Exact.round_of(mesh.bounds, k), true]
	return []


## [method _no_deeper]'s measure for each pair asked: Vector2i(moving, other)
## -> LDU.
var _depth_allowed: Dictionary = {}


## Whether [param one] and [param other] both have exact shapes.
func _both_exact(one: int, other: int) -> bool:
	for key: int in [one, other]:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var shape: Exact.Shape = Exact.shape_for(library, brick.part_id) if brick != null else null
		if shape == null or not shape.has_pieces():
			return false
	return true


## The moving parts whose covers overlap [param other]'s where they stand, kept
## for the grab; each pair is kept as touching as built where [method
## _forgiven_at_rest] says.
func _rest_with(other: int) -> Dictionary:
	if _rest_overlap.has(other):
		return _rest_overlap[other]
	var with: Dictionary = {}
	var boxes: PackedInt32Array = builder.lattice.boxes_of(other)
	# Its partner across the joint is forgiven it whatever their shapes say
	# ([member _across]), and is not asked: each pair asked reads both shapes
	# and their clash.
	var across: Dictionary = _across.get(other, {})
	if not boxes.is_empty():
		for key: int in builder.lattice.blockers_boxes(boxes, other, {}):
			if moving.has(key) or followers.has(key):
				with[key] = true
				if not across.has(key) and _forgiven_at_rest(key, other):
					_keep_built_touching(key, other)
	_rest_overlap[other] = with
	return with


## Whether [param key] and [param other], whose covers overlap where both
## stand, are kept as touching as built, to go through each other in later
## grabs: unless both have exact shapes and those are clear of each other
## there (G13). A cover reaches past its part, so parts built flush overlap
## by their covers, and their exact shapes judge them as they turn; parts a
## file has built into each other overlap by their shapes too, and a part
## with no exact shape is judged by its cover.
func _forgiven_at_rest(key: int, other: int) -> bool:
	var a: BrickWorld.Brick = world.get_brick(key)
	var b: BrickWorld.Brick = world.get_brick(other)
	if a == null or b == null:
		return true
	var shape_a: Exact.Shape = Exact.shape_for(library, a.part_id)
	var shape_b: Exact.Shape = Exact.shape_for(library, b.part_id)
	if shape_a == null or shape_b == null or not shape_a.has_pieces() or not shape_b.has_pieces():
		return true
	return not Exact.clash(Exact.Item.new(shape_a, a.transform), Exact.Item.new(shape_b, b.transform)).is_empty()


## Keep that [param one] and [param other] touch where they stand, where
## neither has been moved by a grab since the model was built.
func _keep_built_touching(one: int, other: int) -> void:
	_built_for_world()
	if _moved_since_built.has(one) or _moved_since_built.has(other):
		return
	for pair: Array in [[one, other], [other, one]]:
		var a: BrickWorld.Brick = world.get_brick(int(pair[0]))
		var b: BrickWorld.Brick = world.get_brick(int(pair[1]))
		if a == null or b == null:
			continue
		var key: String = "%d:%s" % [a.id, a.part_id]
		if not _built_touching.has(key):
			_built_touching[key] = {}
		(_built_touching[key] as Dictionary)[b.id] = b.part_id


## Whether the moving part [param key] touched [param other] where the model
## was built ([member _built_touching]).
func _touched_as_built(key: int, other: int) -> bool:
	_built_for_world()
	var them: BrickWorld.Brick = world.get_brick(other)
	var brick: BrickWorld.Brick = world.get_brick(key)
	if them == null or brick == null:
		return false
	var touched: Dictionary = _built_touching.get("%d:%s" % [other, them.part_id], {})
	return touched.has(key) and brick.part_id == str(touched[key])


## Starts the record again for another world, or where parts were added or
## taken away since it was kept.
func _built_for_world() -> void:
	if _built_for == world.get_instance_id() and _built_count == world.brick_count():
		return
	_built_for = world.get_instance_id()
	_built_count = world.brick_count()
	_built_touching.clear()
	_moved_since_built.clear()
	_built_at.clear()


## Every moving part whose sweep all the way round the joint's line, a
## cylinder about it as far out as the part reaches, has nothing in it but
## what the moving side may press on: put with [member _on_the_line].
func _never_meet() -> void:
	var started: int = Time.get_ticks_msec()
	for key: int in moving:
		# An aid, not a rule: a big section's sweeps are many and wide, and
		# the press comes first. What is not looked at is tested as usual.
		if Time.get_ticks_msec() - started > NEVER_MEET_MS:
			return
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var reach: float = 0.0
		var lo: float = INF
		var hi: float = -INF
		for corner: int in 8:
			var off: Vector3 = brick.transform * mesh.bounds.get_endpoint(corner) - pivot
			var along: float = off.dot(axis)
			reach = maxf(reach, (off - axis * along).length())
			lo = minf(lo, along)
			hi = maxf(hi, along)
		var sweep := AABB(pivot + axis * lo, Vector3.ZERO)
		for end: float in [lo, hi]:
			var middle: Vector3 = pivot + axis * end
			for n: int in 3:
				var way := Vector3.ZERO
				way[n] = 1.0
				var across: Vector3 = way - axis * way.dot(axis)
				var spread: float = across.length() * reach
				sweep = sweep.expand(middle + way * spread).expand(middle - way * spread)
		if not _near_anything(sweep, key, false):
			_on_the_line[key] = true
			_turn_only[key] = true


## Whether the part [param mesh] at [param to] (its world box [param box])
## may meet any part near it but what it may press on: their boxes, each
## turned as it stands, into each other by more than [constant TOUCHING].
## Boxes hold the shapes, so boxes apart are shapes apart, and the turned
## cover need not be worked out.
func _boxes_meet(key: int, mesh: Lbm.PartMesh, to: Transform3D, box: AABB) -> bool:
	for other: int in _near(box, key):
		if _pair_forgiven(key, other, mesh, to):
			continue
		var them: BrickWorld.Brick = world.get_brick(other)
		var their_mesh: Lbm.PartMesh = library.mesh_for(them.part_id) if them != null else null
		if their_mesh == null:
			return true
		if Grab.box_depth(to, mesh.bounds, them.transform, their_mesh.bounds) <= TOUCHING \
				or _slides_over(key, mesh, to, other):
			continue
		if _into_cover(mesh, to, box, other):
			_near_part = other
			return true
	return false


## Whether the part [param mesh] at [param to], its world box [param box], is
## into a box of [param other]'s cover, which hugs it, by more than
## [constant TOUCHING].
func _into_cover(mesh: Lbm.PartMesh, to: Transform3D, box: AABB, other: int) -> bool:
	var pieces: PackedVector3Array = _pieces(other)
	# A piece whose box the part's own box, square to the grid, is not
	# into by more than TOUCHING along some axis is not into the part's
	# turned box either: the three axes are three of box_depth's fifteen
	# lines, and along them the part's turned box reaches as far as its
	# box does. Asked first: a neighbour of hundreds of boxes cost 42081-1's
	# drag 9 ms a frame by the fifteen lines alone.
	var lo: Vector3 = box.position + Vector3.ONE * (TOUCHING - 0.01)
	var hi: Vector3 = box.end - Vector3.ONE * (TOUCHING - 0.01)
	# Then box_depth's fifteen lines, the part's own reach along each worked
	# out once for all the pieces: carried afresh for each piece, they were
	# half the room test of 8808-1's steering, its front wheels against the
	# plates their kingpins stand in (Grab 17 tests those; it skipped them).
	var lines := PackedVector3Array()
	var reach := PackedFloat64Array()
	for at: int in range(0, pieces.size(), 4):
		var low: Vector3 = pieces[at]
		var high: Vector3 = pieces[at + 1]
		if high.x <= lo.x or low.x >= hi.x or high.y <= lo.y or low.y >= hi.y or high.z <= lo.z or low.z >= hi.z:
			continue
		if lines.is_empty():
			lines = Grab._square_lines(to.basis)
			reach = Grab._reach_on(to, mesh.bounds, lines)
		if Grab._into_square(lines, reach, pieces[at + 2], pieces[at + 3], TOUCHING):
			return true
	return false


## [param other]'s cover, which stays where it is while the grab lasts, as
## its pieces' low and high corners, middles and half sizes in LDU, four to
## a piece: read from the lattice's cells once, not for each moving part
## near it each frame.
func _pieces(other: int) -> PackedVector3Array:
	if _pieces_for != world.revision:
		_pieces_for = world.revision
		_pieces_of.clear()
	if _pieces_of.has(other):
		return _pieces_of[other]
	var cover: PackedInt32Array = builder.lattice.boxes_of(other)
	var cell_size: float = BrickLattice.CELL
	var out := PackedVector3Array()
	for at: int in range(0, cover.size(), 6):
		var piece := AABB(Vector3(cover[at], cover[at + 1], cover[at + 2]) * cell_size,
			Vector3(cover[at + 3] - cover[at], cover[at + 4] - cover[at + 1],
				cover[at + 5] - cover[at + 2]) * cell_size)
		out.append(piece.position)
		out.append(piece.end)
		out.append(piece.get_center())
		out.append(piece.size * 0.5)
	_pieces_of[other] = out
	return out


var _pieces_of: Dictionary = {}
var _pieces_for: int = -1


## [method box_depth]'s lines for a box turned by [param turned] against one
## square to the grid: its own three, the grid's three, and those square to
## one of each.
static func _square_lines(turned: Basis) -> PackedVector3Array:
	var out := PackedVector3Array()
	var grid: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for k: int in 3:
		out.append(turned[k].normalized())
	for i: int in 3:
		for j: int in 3:
			var across: Vector3 = turned[i].normalized().cross(grid[j])
			if across.length() > 0.001:
				out.append(across.normalized())
	# The grid's last: a piece [method _into_cover] asks has passed them.
	for k: int in 3:
		out.append(grid[k])
	return out


## How far [param box] at [param at] reaches along each of [param lines]:
## its low and high end on each, in turn.
static func _reach_on(at: Transform3D, box: AABB, lines: PackedVector3Array) -> PackedFloat64Array:
	var middle: Vector3 = at * box.get_center()
	var edges: Array[Vector3] = [at.basis[0] * (box.size.x * 0.5), at.basis[1] * (box.size.y * 0.5),
		at.basis[2] * (box.size.z * 0.5)]
	var out := PackedFloat64Array()
	for way: Vector3 in lines:
		var mid: float = middle.dot(way)
		var half: float = absf(edges[0].dot(way)) + absf(edges[1].dot(way)) + absf(edges[2].dot(way))
		out.append(mid - half)
		out.append(mid + half)
	return out


## Whether a turned box is into a piece square to the grid, its [param
## middle] and [param half] its size, by more than [param depth]: [method
## box_depth] over [param depth], from the box's [param lines] and its
## [param reach] on them as [method _reach_on] gives them, its half of the
## measure worked out once. Done at the first line along which they are no
## deeper.
static func _into_square(lines: PackedVector3Array, reach: PackedFloat64Array, middle: Vector3,
		half: Vector3, depth: float) -> bool:
	for n: int in lines.size():
		var way: Vector3 = lines[n]
		var mid: float = middle.dot(way)
		var spread: float = absf(half.x * way.x) + absf(half.y * way.y) + absf(half.z * way.z)
		if minf(reach[n * 2 + 1], mid + spread) - maxf(reach[n * 2], mid - spread) <= depth:
			return false
	return true


var _near_part: int = 0


## Whether anything but what the moving side may press on has its bounds
## within [param box] ([method _near]): for the moving part [param key], but
## what it is joined to ([member _across]). [param kept]: its neighbours
## asked for its cells are kept for it.
func _near_anything(box: AABB, key: int = 0, kept: bool = true) -> bool:
	for other: int in _near(box, key if kept else 0):
		if not (_across.get(other, {}) as Dictionary).has(key):
			return true
	return false


## What but what the moving side may press on has its bounds within [param
## box]'s cells, as the lattice says (near_bounds). For a moving part [param
## key], asked of the lattice for its cells and [constant NEAR_MARGIN] more
## all round, and sifted from that while its cells stay within them, as long
## as the model and what the moving side may press on stay as they are: asked
## of the lattice twice a part a frame, it was half of 8808-1's steering's
## room test (G14a).
func _near(box: AABB, key: int = 0) -> PackedInt64Array:
	if _near_for != Vector2i(world.revision, skip.size()):
		_near_for = Vector2i(world.revision, skip.size())
		_near_kept.clear()
	var cell: float = BrickLattice.CELL
	var lo := Vector3i(floori(box.position.x / cell), floori(box.position.y / cell), floori(box.position.z / cell))
	var hi := Vector3i(ceili(box.end.x / cell), ceili(box.end.y / cell), ceili(box.end.z / cell))
	var kept: Array = _near_kept.get(key, []) if key != 0 else []
	if kept.is_empty() or lo.x < int(kept[0][0]) or lo.y < int(kept[0][1]) or lo.z < int(kept[0][2]) \
			or hi.x > int(kept[0][3]) or hi.y > int(kept[0][4]) or hi.z > int(kept[0][5]):
		var margin: int = NEAR_MARGIN if key != 0 else 0
		var grown := PackedInt32Array([lo.x - margin, lo.y - margin, lo.z - margin, hi.x + margin,
			hi.y + margin, hi.z + margin])
		var ids := PackedInt64Array()
		var bounds := PackedInt32Array()
		for other: int in builder.lattice.near_bounds(grown):
			if not skip.has(other):
				ids.append(other)
				bounds.append_array(builder.lattice._bounds[other])
		kept = [grown, ids, bounds]
		if key != 0:
			_near_kept[key] = kept
	var found: PackedInt64Array = kept[1]
	var their: PackedInt32Array = kept[2]
	var out := PackedInt64Array()
	for n: int in found.size():
		var at: int = n * 6
		if their[at] < hi.x and lo.x < their[at + 3] and their[at + 1] < hi.y and lo.y < their[at + 4] \
				and their[at + 2] < hi.z and lo.z < their[at + 5]:
			out.append(found[n])
	return out


## How many cells all round a moving part's neighbours are asked for at once
## ([method _near]): a part goes a cell or two a frame.
const NEAR_MARGIN := 4
## [method _near]'s asks for each moving part: brick id -> [the cells asked,
## what is in them, their bounds]; and the model's revision and how many parts
## the moving side may press on when they were asked.
var _near_kept: Dictionary = {}
var _near_for := Vector2i(-1, -1)


## Turn to [param degrees] from where it was grabbed, as far as it has room
## for from where it is: a click hinge on its clicks. Returns the angle.
func turn_to(degrees: float) -> float:
	if state != "moves" or mode != "turn":
		return angle
	frame_solve_ms = 0.0
	frame_test_ms = 0.0
	frame_tests = 0
	frame_slowest_us = 0
	frame_slowest_said = ""
	var wanted: float = degrees
	if link.detent > 0.0:
		wanted = roundf(wanted / link.detent) * link.detent
	if is_equal_approx(wanted, angle):
		return angle
	_end_verify_walk()
	# Past the wall it met last, the same way: still there, and not asked
	# again, so a pointer pressed on past a stop costs nothing a frame.
	if not is_nan(_wall) and (wanted - _wall) * (_wall - angle) >= 0.0 \
			and absf(_wall - angle) < absf(wanted - angle) + 0.001:
		stopped = true
		return angle
	_wall = NAN
	loop_short = false
	if linkage != null and budget_ms < INF:
		# A drag's, on a quarter-degree grid: a part's turned cover is kept
		# per turn (Builder.boxes_for), so a drag back over the same ground
		# finds them. A session's turn is the degrees it asks (G14a): put on
		# the grid, a turn back by as far as a stop found off it had gone
		# overshot, and 6987-1's loop came back 0.29 LDU from where it began.
		wanted = snappedf(wanted, LOOP_GRID)
	if linkage != null and not linkage.is_slide():
		# As far as the loop closes towards it.
		var reached: float = rad_to_deg(linkage.reach(deg_to_rad(wanted)))
		if absf(reached - wanted) > 0.01:
			loop_short = true
			wanted = reached
	# Along the way first, a step at a time from the last turn checked
	# (G13): the first step with no room is where it stops.
	var began: int = Time.get_ticks_usec()
	var walked: Array = _walk(_checked_angle if unchecked else angle, wanted, began)
	var room: int = int(walked[0])
	var at: Dictionary = {}
	# The way not tested this frame (a loop's drag): checked on a pause.
	var way_left: bool = room == 2
	if way_left:
		room = 1
	if room == 1:
		at = transforms_at(wanted)
		# A loop's drag: its joints' own parts are asked on the pause, with
		# its way ([method verify_step]). Asked every frame, 8808-1's steering
		# drag spent 5 to 10 ms a frame on them, against 0.5 ms for the rest.
		room = _test(at, 0, _budget_left(began), true, {}, not way_left).x
		if room == 0 and budget_ms == INF and _push_aside(wanted):
			room = 1
			at = transforms_at(wanted)
		if room == 0:
			walked = [0, walked[1], wanted]
	elif room == -1:
		at = transforms_at(wanted)
	if room != 0:
		# Room, or not all asked this frame: a big section is shown where the
		# pointer says and checked when it pauses or is let go
		# ([method verify_step]), from the last step that had room, rather
		# than hold the frame.
		_shown_on_trust(room == 1 and not way_left, wanted, float(walked[1]))
		angle = wanted
		placed = at
		_keep_loop()
		_keep_shown()
		stopped = loop_short
		return angle
	if budget_ms < INF:
		# Met something, on a section too big to bisect in a frame: it stands
		# at the last step that had room, and the stop is found a round a
		# frame (verify_step), on a pause or at the release.
		if not way_left:
			_stand_at(float(walked[1]))
		_met_on_trust(float(walked[2]), angle)
		return angle
	var low: float = float(walked[1])
	var high: float = float(walked[2])
	# As many halvings as bring the step under STOP_TO: a step along the way
	# is a few degrees, and each round tests every part that may hit something.
	var rounds: int = clampi(ceili(log(maxf(absf(high - low), STOP_TO) / STOP_TO) / log(2.0)),
		1, ROUNDS)
	for _round: int in rounds:
		var middle: float = (low + high) * 0.5
		if _test(transforms_at(middle), 0, budget_ms).x != 0:
			low = middle
		else:
			high = middle
	if link.detent > 0.0:
		# The last click short of what is in the way.
		var clicks: float = (low - angle) / link.detent
		low = angle + (floorf(clicks) if clicks >= 0.0 else ceilf(clicks)) * link.detent
	_wall = high
	angle = low
	placed = transforms_at(angle)
	_keep_loop()
	stopped = true
	return angle


## A big section drawn at [param value] (degrees or LDU), [param checked]
## when its whole test found room there. A stop met earlier and not found
## yet is behind it now: found later, it put a section let go somewhere else
## back at that stop (42081-1's arm let go 20 LDU out was kept at its stop
## 60 LDU in), and a test cut short for an earlier pose went on from the
## part it had reached, for this one.
func _shown_on_trust(checked: bool, value: float, clear_to: float) -> void:
	if checked:
		_checked_angle = value
		unchecked = false
		_shown.clear()
	else:
		# Checked along the way as far as [param clear_to]: the rest of the
		# way is checked from there.
		_checked_angle = clear_to
		unchecked = true
		_verify_last.clear()
		_verify_base = clear_to
	_verifying_hi = null
	_verify_from = 0


## Stand at [param value] (degrees or LDU), checked all the way there.
func _stand_at(value: float) -> void:
	_set_value(value)
	placed = _pose_at(value)
	_checked_angle = value
	unchecked = false
	_shown.clear()
	_keep_loop()


## A big section met something at [param value], standing at [param at]: it
## stays, and where it stops is found on a pause or at the release
## ([method verify_step]), bisected from the last value checked whole.
func _met_on_trust(value: float, at: float) -> void:
	_wall = value
	if not unchecked:
		_checked_angle = at
	unchecked = true
	_verifying_lo = _checked_angle
	_verifying_hi = value
	_verify_from = 0
	stopped = true


## One frame's worth of checking a turn shown on trust: the whole section
## tested along the way from the last turn checked to where it stands, a
## step at a time (G13: tested only where it stood, a train's bogie shown 30°
## round had gone through its buffer beam to get there), a [member
## budget_ms] at a time; if something is in the way, bisected back towards
## the last step with room, a round a frame. True once it stands where it
## has room.
func verify_step() -> bool:
	if not unchecked or mode == "ball":
		unchecked = false
		return true
	var now: float = angle if mode == "turn" else shift
	var began: int = Time.get_ticks_usec()
	if _verifying_hi == null and linkage != null and _verify_kept.is_empty():
		# The pose shown, solved from where the move began, kept to come back
		# to once the way to it is checked ([method _walk]). The way is walked
		# from the pose checked last, as the drag showed it: solved off the
		# pose shown, its steps were not the poses the drag had shown (42080-1's
		# crane 127 LDU off at the end of the walk, 42024-1's actuator 0.02 LDU
		# at its stop), and where they met something, a pose the drag never
		# showed was kept: the actuator, let go at that stop, once 1.75 LDU in.
		_verify_kept = linkage.kept_state()
		if not _checked_kept.is_empty():
			linkage.restore_kept(_checked_kept)
		_walk_frames = _frames_on_the_way(_checked_angle, now)
	while _verifying_hi == null:
		var next: float = _next_step(_checked_angle, now)
		# Through each pose the drag showed on the way, as it showed it, each
		# step on solved from the last of them: a loop with freedom to spare
		# has no one pose for a value of its driver, and the walk's own, solved
		# from where it was checked last, were not the drag's. 42024-1's rod,
		# shown at 2, 4 and 6 LDU, had a beam 1.1 LDU into a cross block at 5.5
		# solved back from the pose shown at 6, and room to 5.75 walked out.
		var frame: bool = not _walk_frames.is_empty() \
			and (float(_walk_frames[0][0]) - next) * signf(now - _checked_angle) <= 0.0001
		if frame:
			next = float(_walk_frames[0][0])
			linkage.restore_kept(_walk_frames[0][1])
		# As a move's own walk tests them: each part as often as it goes
		# PATH_LDU, every part where it stands. Every part at every step
		# kept 42081-1's arm, 653 parts, 10 s after it was let go.
		var due: Dictionary = {}
		if next != now:
			var after: float = _next_step(next, now)
			for key: int in _rates:
				if float(_rates[key]) * absf(after - float(_verify_last.get(key, _verify_base))) > PATH_LDU:
					due[key] = true
			if due.is_empty():
				_checked_angle = next
				if frame:
					_walk_frames.pop_front()
					_checked_kept = linkage.kept_state()
				continue
		# Where it was let go, the pose shown is what is kept, and what is tested.
		var r: Vector2i = _test(placed if next == now and linkage != null and not placed.is_empty()
			else _pose_at(next), _verify_from, _pause_left(began), next == now, due)
		if r.x == -1:
			_verify_from = r.y
			return false
		_verify_from = 0
		if r.x == 1:
			_checked_angle = next
			if frame:
				_walk_frames.pop_front()
			for key: int in due:
				_verify_last[key] = next
			_keep_loop()
			if linkage != null and next != now:
				_checked_kept = linkage.kept_state()
			if next == now:
				_end_verify_walk()
				unchecked = false
				_shown.clear()
				if linkage != null:
					_checked_kept = linkage.kept_state()
				return true
			continue
		_end_verify_walk()
		_verifying_hi = next
		_verifying_lo = _checked_angle
		# Bisected from the last step with room, as the walk got there.
		if linkage != null and not _checked_kept.is_empty():
			linkage.restore_kept(_checked_kept)
	var hi: float = float(_verifying_hi)
	# A slide is found to a tenth of an LDU, a turn to STOP_TO degrees.
	if absf(hi - _verifying_lo) < (STOP_TO if mode == "turn" else 0.1):
		_set_value(_verifying_lo)
		placed = _pose_at(_verifying_lo)
		_keep_loop()
		_wall = hi
		_verifying_hi = null
		unchecked = false
		_shown.clear()
		stopped = true
		_checked_angle = _verifying_lo
		if linkage != null:
			_checked_kept = linkage.kept_state()
		if not settled and not is_nan(let_go_at) and absf(_verifying_lo - let_go_at) > 0.01:
			stopped_short = true
		return true
	var middle: float = (_verifying_lo + hi) * 0.5
	var r2: Vector2i = _test(_pose_at(middle), _verify_from, _pause_left(began))
	if r2.x == -1:
		_verify_from = r2.y
		return false
	_verify_from = 0
	if r2.x == 1:
		_verifying_lo = middle
	else:
		_verifying_hi = middle
	_set_value(_verifying_lo)
	placed = _pose_at(_verifying_lo)
	_keep_loop()
	stopped = true
	return false


## Free joints inside what moves, turned aside by what pressed them (G13b):
## child body -> degrees about its own joint, from where it stood.
var _pushed: Dictionary = {}
## How far a free joint inside what moves is turned aside at most, degrees.
const PUSH_MOST := 90.0


## Turn each free joint inside what moves that something pressed aside, as
## [member _pushed] has it, where [param out] (brick id -> Transform3D, as
## [method transforms_at] has it) puts what carries it.
func _turn_pushed(out: Dictionary) -> void:
	for child: int in _pushed:
		var joined: Bodies.Link = bodies.parent_link.get(child)
		var carrier: int = int(bodies.parent_of.get(child, -1))
		if joined == null or not bodies.members.has(carrier):
			continue
		var carrier_key: int = int((bodies.members[carrier] as PackedInt64Array)[0])
		if not out.has(carrier_key):
			continue
		var carried: Transform3D = (out[carrier_key] as Transform3D) * (rest[carrier_key] as Transform3D).affine_inverse()
		var turn_point: Vector3 = carried * joined.point
		var way: Vector3 = (carried.basis * joined.axis).normalized()
		var turn: Transform3D = Transform3D(Basis.IDENTITY, turn_point) \
			* Transform3D(Basis(way, deg_to_rad(float(_pushed[child]))), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -turn_point)
		for key: int in bodies.parts_of(bodies.beyond(child)):
			if out.has(key):
				out[key] = turn * (out[key] as Transform3D)


## The free joint inside what moves that carries [param key]: the body hung on
## a joint that does not hold by friction, below the grabbed one, as [method
## _settle_inside] swings them. -1 for none.
func _free_inside(key: int) -> int:
	var ours: Dictionary = {}
	for one: int in moving_bodies:
		ours[one] = true
	var at: int = int(bodies.body_of.get(key, -1))
	while ours.has(at) and at != body:
		var joined: Bodies.Link = bodies.parent_link.get(at)
		var parent: int = int(bodies.parent_of.get(at, -1))
		if joined != null and joined != link and not joined.holds and joined.axis != Vector3.ZERO \
				and ours.has(parent):
			return at
		at = parent
	return -1


## A free joint inside what moves swings aside when the model presses on what
## it carries, rather than stop the section (G13b): where a turn at [param
## value] has no room and the part that met something hangs on such a joint,
## that joint is turned aside a little more each way until it has room, up to
## [constant PUSH_MOST]. 8074-1's crane, turned back over its start, met the
## brick 1 x 16 its first turn had swung down on a free pin. True when it then
## has room there.
func _push_aside(value: float) -> bool:
	if linkage != null or mode == "ball" or blocked_by.size() != 2:
		return false
	var child: int = _free_inside(int(blocked_by[0]))
	if child < 0:
		return false
	var was: float = float(_pushed.get(child, 0.0))
	var tried: float = 1.0
	while tried <= PUSH_MOST:
		for way: float in [1.0, -1.0]:
			_pushed[child] = was + way * tried
			if _test(_pose_at(value), 0, INF, false).x == 1:
				return true
		tried *= 2.0
	if is_zero_approx(was):
		_pushed.erase(child)
	else:
		_pushed[child] = was
	return false


## A loop's pose kept as it was when a pause's walk began, the walk over or
## cut short by a move ([method verify_step]).
func _end_verify_walk() -> void:
	if linkage != null and not _verify_kept.is_empty():
		linkage.restore_kept(_verify_kept)
	_verify_kept = []
	_walk_frames = []


## A loop's pose shown on trust by a drag's frame, kept for the walk that
## checks the way to it ([method verify_step]).
func _keep_shown() -> void:
	if linkage != null and unchecked:
		_shown.append([angle if mode == "turn" else shift, linkage.kept_state()])


## The poses the drag showed ([member _shown]) between [param from] and
## [param to], not at either: one a value, the last shown there, in order
## along the way.
func _frames_on_the_way(from: float, to: float) -> Array:
	var way: float = signf(to - from)
	var at: Dictionary = {}
	for frame: Array in _shown:
		var along: float = (float(frame[0]) - from) * way
		if along > 0.0001 and along < absf(to - from) - 0.0001:
			at[snappedf(float(frame[0]), 0.0001)] = frame
	var values: Array = at.keys()
	values.sort()
	if way < 0.0:
		values.reverse()
	var out: Array = []
	for value: Variant in values:
		out.append(at[value])
	return out


## Where everything stands with the joint at [param value]: degrees for a
## turn, LDU for a slide.
func _pose_at(value: float) -> Dictionary:
	return transforms_at(value) if mode == "turn" else transforms_at(angle, value)


func _set_value(value: float) -> void:
	if mode == "turn":
		angle = value
	else:
		shift = value


# -- along the way (G13) ------------------------------------------------------------


## What is left of a pause's check since [param began] (usec), ms: of
## [member budget_ms] and [member pause_budget_ms].
func _pause_left(began: int) -> float:
	var budget: float = minf(minf(budget_ms, walk_budget_ms), pause_budget_ms)
	if budget == INF:
		return INF
	return budget - float(Time.get_ticks_usec() - began) / 1000.0


## What is left of [member budget_ms] since [param began] (usec), ms.
func _budget_left(began: int) -> float:
	var budget: float = minf(budget_ms, walk_budget_ms)
	if budget == INF:
		return INF
	return budget - float(Time.get_ticks_usec() - began) / 1000.0


## Test the way from [param from] (degrees or LDU), which has room, towards
## [param to], a step at a time ([method _path_step]), short of [param to]
## itself: [1, the last step, to] when every step has room; [0, the last step
## with room, the first with none]; or [-1, the last step with room, the next]
## when [member budget_ms] since [param began] runs out first.
func _walk(from: float, to: float, began: int) -> Array:
	if linkage != null and budget_ms < INF:
		# A loop's drag: its way is left to a pause or the release ([method
		# verify_step]), and only where the pointer says is tested a frame, as
		# before G13. Solved a step at a time in the frame, 42024-1's actuator,
		# a loop of 36 joints, took 62 ms a frame on average and 181 at 95%.
		return [2, from, to]
	# A loop is solved at each step from the step before, kept for it, and
	# left as it was when the walk ends: where the move ends is solved from
	# where it began, as if there were no steps (G13b). Where it ended
	# depended on how many steps the way took, and fourteen sets' steering,
	# turned out and back, came back 0.03 to 0.19 LDU off.
	var began_kept: Array = linkage.kept_state() if linkage != null else []
	var walked: Array = _walk_steps(from, to, began)
	if linkage != null:
		linkage.restore_kept(began_kept)
	return walked


func _walk_steps(from: float, to: float, began: int) -> Array:
	var clear: float = from
	# Where each part was last tested: one that would go further than
	# PATH_LDU by the step after this one is tested at this one. A turned
	# section's parts by its joint (a hinge's own pieces, a turntable's top)
	# are what stand near something, and go least.
	var last: Dictionary = {}
	# A loop is solved at every step, a few ms each for dozens of joints: its
	# way is tested in at most LOOP_MOST_STEPS, and a drag's frame, which
	# moves it a little, in two. Stepped 0.4 LDU at a time, 42024-1's
	# actuator, its rod in a loop of 36 joints, solved 50 times in a frame.
	var least: float = 0.0
	if linkage != null:
		least = absf(to - from) / (LOOP_MOST_STEPS if budget_ms == INF else 2.0)
	while true:
		var next: float = _next_step(clear, to, least)
		if next == to:
			break
		var left: float = _budget_left(began)
		if left <= 0.0:
			return [-1, clear, next]
		var after: float = _next_step(next, to, least)
		var due: Dictionary = {}
		for key: int in _rates:
			if float(_rates[key]) * absf(after - float(last.get(key, from))) > PATH_LDU:
				due[key] = true
		if not due.is_empty():
			var r: Vector2i = _test(_pose_at(next), 0, left, false, due)
			if r.x == 0 and budget_ms == INF and _push_aside(next):
				r.x = 1
			if r.x != 1:
				return [r.x, clear, next]
			for key: int in due:
				last[key] = next
			# Each step solved from the last, not from where the move began:
			# from there, 42024-1's 36-joint loop took 172 ms a frame.
			_keep_loop()
		clear = next
	return [1, clear, to]


## The next step from [param from] towards [param to]: [param to] itself
## when it is within a step. A loop's turn steps on its quarter-degree grid,
## where its parts' turned covers are kept.
func _next_step(from: float, to: float, least: float = 0.0) -> float:
	var step: float = maxf(_path_step(from), least)
	if absf(to - from) <= step * 1.0001:
		return to
	var next: float = from + signf(to - from) * step
	if linkage != null and mode == "turn":
		next = snappedf(next, LOOP_GRID)
	return next


## A step along the way, degrees for a turn and LDU for a slide: one that
## moves no point of what moves more than [constant PATH_LDU], worked out once
## a grab from [param now], where it stands.
func _path_step(now: float) -> float:
	if _step > 0.0:
		return _step
	var rate: float = _path_rate(now)
	if mode == "turn":
		_step = clampf(PATH_LDU / rate, PATH_LEAST_DEG, PATH_MOST_DEG) if rate > 0.0 else PATH_MOST_DEG
		if linkage != null:
			_step = maxf(LOOP_GRID, floorf(_step / LOOP_GRID) * LOOP_GRID)
	else:
		_step = clampf(PATH_LDU / rate, PATH_LEAST_LDU, PATH_LDU) if rate > 0.0 else PATH_LDU
	return _step


## How far a point of what moves goes at most for a degree of the turn (an
## LDU of the slide) from [param now], LDU: the corners of each tested part's
## box, which go at least as far as any point of the part, between where it
## stands and a unit on. Gears it drives, what hangs on them and a loop's
## other bodies are placed as the move places them. 0 when it does not move.
func _path_rate(now: float) -> float:
	var a: Dictionary
	var b: Dictionary
	var span: float = 1.0
	if linkage != null:
		# A loop goes as far as it closes: a unit one way, else the other.
		var solving: int = Time.get_ticks_usec()
		var slide: bool = linkage.is_slide()
		span = 0.0
		for way: float in [1.0, -1.0]:
			var target: float = now + way
			var got: float = linkage.reach(target if slide else deg_to_rad(target))
			got = got if slide else rad_to_deg(got)
			if absf(got - now) > 0.01:
				b = linkage.transforms(rest)
				span = absf(got - now)
				break
		if span > 0.0:
			linkage.reach(now if slide else deg_to_rad(now))
			a = linkage.transforms(rest)
		frame_solve_ms += float(Time.get_ticks_usec() - solving) / 1000.0
		if span == 0.0:
			return 0.0
	else:
		a = _pose_at(now)
		b = _pose_at(now + 1.0)
	var most: float = 0.0
	_rates.clear()
	for key: Variant in b:
		if not a.has(key) or _on_the_line.has(key) or bodies.flexible.has(int(bodies.body_of.get(key, -1))):
			continue
		var brick: BrickWorld.Brick = world.get_brick(int(key))
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			continue
		var one: Transform3D = a[key]
		var other: Transform3D = b[key]
		var its: float = 0.0
		for corner: int in 8:
			var point: Vector3 = mesh.bounds.get_endpoint(corner)
			its = maxf(its, (other * point).distance_to(one * point))
		_rates[int(key)] = its / span
		most = maxf(most, its)
	return most / span


## Slide [param along] LDU from where it was grabbed, along the shaft as far
## as it reaches and there is room.
func slide_to(along: float) -> float:
	if state != "moves" or mode != "slide":
		return shift
	frame_solve_ms = 0.0
	frame_test_ms = 0.0
	frame_tests = 0
	frame_slowest_us = 0
	frame_slowest_said = ""
	var wanted: float = clampf(along, _range.x, _range.y)
	if budget_ms < INF and not is_nan(_wall) and (wanted - _wall) * (_wall - shift) >= 0.0 \
			and absf(_wall - shift) < absf(wanted - shift) + 0.001:
		# Past the stop it met last, the same way, as turn_to has it: 42081-1's
		# arm drawn on past its stop was tested again each frame. A loop got as
		# far as that stop, so it gets there again before anything further.
		stopped = true
		return shift
	_wall = NAN
	_end_verify_walk()
	if linkage != null:
		# A slide in a loop goes as far as the loop takes it.
		var solving: int = Time.get_ticks_usec()
		wanted = linkage.reach(along)
		frame_solve_ms += float(Time.get_ticks_usec() - solving) / 1000.0
		if absf(wanted - shift) < 0.001 and not is_equal_approx(wanted, along):
			# Where it already stands: the loop closes no further that way.
			stopped = true
			return shift
	stopped = not is_equal_approx(wanted, along)
	# Along the way first, as turn_to has it (G13).
	var began: int = Time.get_ticks_usec()
	var walked: Array = _walk(_checked_angle if unchecked else shift, wanted, began)
	var room: int = int(walked[0])
	var at: Dictionary = {}
	var way_left: bool = room == 2
	if way_left:
		room = 1
	if room == 1:
		at = transforms_at(angle, wanted)
		room = _test(at, 0, _budget_left(began), true, {}, not way_left).x
		if room == 0:
			walked = [0, walked[1], wanted]
	elif room == -1:
		at = transforms_at(angle, wanted)
	if room != 0:
		# A big section, as turn_to has it: tested within a frame's share,
		# shown where the pointer says when there is not time to finish, and
		# checked on a pause or at the release (verify_step). 42081-1's boom,
		# 262 parts on its actuator, was bisected by whole tests at its stop:
		# 164 of them, 31 s in one frame.
		_shown_on_trust(room == 1 and not way_left, wanted, float(walked[1]))
		shift = wanted
		placed = at
		_keep_loop()
		_keep_shown()
		return shift
	if budget_ms < INF:
		if not way_left:
			_stand_at(float(walked[1]))
		_met_on_trust(float(walked[2]), shift)
		return shift
	var low: float = float(walked[1])
	var high: float = float(walked[2])
	for _round: int in ROUNDS:
		var middle: float = (low + high) * 0.5
		if has_room(transforms_at(angle, middle)):
			low = middle
		else:
			high = middle
	shift = low
	placed = transforms_at(angle, shift)
	_keep_loop()
	stopped = true
	return shift


## Turn a ball to [param turned] from where it was grabbed, as far towards
## it as it has room for.
func ball_to(turned: Basis) -> Basis:
	if state != "moves" or mode != "ball":
		return twist
	var from := Quaternion(twist.orthonormalized())
	var to := Quaternion(turned.orthonormalized())
	# Asked further than the turn that met something, about much the same
	# way: still met, and not tested again.
	if _ball_walled:
		var wall_step: Quaternion = _ball_wall * from.inverse()
		var step: Quaternion = to * from.inverse()
		if step.get_angle() >= wall_step.get_angle() - 0.001 and wall_step.get_angle() > 0.0001 \
				and step.get_axis().dot(wall_step.get_axis()) > 0.9:
			stopped = true
			return twist
	_ball_walled = false
	# Along the way first, as turn_to has it (G13): in steps that move no
	# point of what moves more than PATH_LDU.
	var whole: float = from.angle_to(to)
	var steps: int = 1
	if whole > 0.0:
		if _step <= 0.0:
			# Radians a step, once a grab.
			_step = clampf(PATH_LDU / maxf(_ball_reach(), 0.001), deg_to_rad(PATH_LEAST_DEG),
				deg_to_rad(PATH_MOST_DEG))
		steps = maxi(1, ceili(whole / _step))
	var low: float = 0.0
	var high: float = 1.0
	var met_on_way: bool = false
	for n: int in range(1, steps):
		var part_way: float = float(n) / float(steps)
		if _test(transforms_at(0.0, 0.0, Basis(from.slerp(to, part_way))), 0, INF, false).x != 1:
			high = part_way
			met_on_way = true
			break
		low = part_way
	if not met_on_way and has_room(transforms_at(0.0, 0.0, Basis(to))):
		twist = Basis(to)
		placed = transforms_at(0.0, 0.0, twist)
		stopped = false
		return twist
	# Fewer rounds than a turn: a ball's way changes every frame, so no wall
	# is kept, and 1/64 of a frame's step is under a degree.
	for _round: int in BALL_ROUNDS:
		var middle: float = (low + high) * 0.5
		if has_room(transforms_at(0.0, 0.0, Basis(from.slerp(to, middle)))):
			low = middle
		else:
			high = middle
	twist = Basis(from.slerp(to, low))
	placed = transforms_at(0.0, 0.0, twist)
	stopped = true
	_ball_wall = from.slerp(to, high)
	_ball_walled = true
	return twist


## How far from the ball's middle any corner of a tested moving part's box
## reaches, LDU: a radian of the ball moves no point further.
func _ball_reach() -> float:
	var most: float = 0.0
	for key: int in moving:
		if not rest.has(key) or bodies.flexible.has(int(bodies.body_of.get(key, -1))):
			continue
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			continue
		for corner: int in 8:
			most = maxf(most, ((rest[key] as Transform3D) * mesh.bounds.get_endpoint(corner)).distance_to(pivot))
	return most


## The loop's pose as it now stands is where its next move starts.
func _keep_loop() -> void:
	if linkage != null:
		linkage.keep()
		if not unchecked and is_equal_approx(angle if mode == "turn" else shift, _checked_angle):
			_checked_kept = linkage.kept_state()


## Slide it along its joint's line rather than turn it: a drag along the
## line, or move_part's along=.
func use_slide() -> void:
	mode = "slide"
	_step = 0.0
	for key: int in _turn_only:
		_on_the_line.erase(key)
	_turn_only.clear()
	_round_self.clear()
	if linkage != null:
		linkage.drive_slide()


## The range a slide has, LDU from where it was grabbed.
func slide_range() -> Vector2:
	return _range


func can_slide() -> bool:
	if linkage != null:
		return linkage.slide_col[0] >= 0
	return mode != "ball" and _range.y - _range.x > 4.0


# -- following the pointer ----------------------------------------------------------


## The pointer at [param screen], its ray from [param origin] along [param
## direction], [param eye] the camera: move the joint as the pointer says.
## The first move decides between turning and sliding, for a joint that
## does both, by whether it goes along the line as the eye sees it.
func follow(origin: Vector3, direction: Vector3, screen: Vector2, eye: Camera3D) -> void:
	if state != "moves":
		return
	if not _decided:
		if _hold_screen == Vector2.ZERO:
			_hold_screen = screen
			return
		var moved: Vector2 = screen - _hold_screen
		if moved.length() < 3.0:
			return
		_decided = true
		if can_slide() and eye != null:
			var a: Vector2 = eye.unproject_position(pivot)
			var b: Vector2 = eye.unproject_position(pivot + axis * 20.0)
			var line: Vector2 = (b - a)
			# The way the point held goes when it turns, as the eye sees it:
			# the pointer slides only when it goes along the line clearly more
			# than that way. Across the line was not enough: seen from above
			# its axle, a wheel's rim turns along the axle's line on the screen,
			# and an engine's crank slid instead of turning.
			var held: Vector3 = _hold - pivot
			var round_way: Vector3 = axis.cross(held - axis * held.dot(axis))
			var turning := Vector2.ZERO
			if round_way.length() > 0.5 and not eye.is_position_behind(_hold):
				turning = eye.unproject_position(_hold + round_way.normalized() * 3.0) \
					- eye.unproject_position(_hold)
			if line.length() > 12.0:
				var along: float = absf(moved.normalized().dot(line.normalized()))
				var round: float = absf(moved.normalized().dot(turning.normalized())) \
					if turning.length() > 0.5 else absf(moved.normalized().cross(line.normalized()))
				if along > round * SLIDE_BIAS:
					use_slide()
	match mode:
		"turn":
			if linkage != null and not linkage.driver_fixed() and eye != null:
				turn_to(_pointer_loop(screen, eye))
			else:
				turn_to(_pointer_angle(origin, direction, screen, eye))
			_note_turn(Time.get_ticks_usec())
		"slide":
			slide_to(_pointer_along(origin, direction))
		"ball":
			ball_to(_pointer_twist(origin, direction))


## Where the turn stood at each of the pointer's last moves: [usec, degrees].
var _turns_seen: Array = []
## A fling's speed is read from the pointer's moves in at most this long
## before it let go, ms.
const FLING_WINDOW_MS := 100.0
## The pointer's last move this long or more before the button came up, ms,
## and twice its last gap: it stood still, and let go from rest.
const FLING_STILL_MS := 60.0
## A gap between two moves longer than this, ms, in which the turn went
## slower than [constant FLING_LEAST], is where the pointer paused: what
## came before it is not this fling. Not every long gap: a browser drawing
## in software moves the pointer a few times a second, and its speed is read
## over those moves.
const FLING_PAUSE_MS := 40.0
## Slower than this, rad/s (11° a second), the pointer was held still: a
## hand's drift as it lets go is not a fling.
const FLING_LEAST := 0.2
## A fling faster than this is taken as this, rad/s (ten turns a second): a
## frame held up makes one move of the pointer look like a flick.
const FLING_MOST := TAU * 10.0


## The turn now, as the pointer last left it, at [param usec].
func _note_turn(usec: int) -> void:
	_turns_seen.append([usec, angle])
	if _turns_seen.size() > 24:
		_turns_seen.pop_front()


## How fast the pointer was turning the joint as the button came up at
## [param now_usec], rad/s about [member axis]: the slope of the turn
## against the clock over the pointer's last moves (least squares), the turn
## as the parts went (a stop the model met is not a fling). 0 when the
## pointer stood still before it let go.
func fling_rate(now_usec: int) -> float:
	if mode != "turn" or _turns_seen.size() < 2:
		return 0.0
	var last: Array = _turns_seen[_turns_seen.size() - 1]
	var gap: float = float(int(last[0]) - int(_turns_seen[_turns_seen.size() - 2][0])) / 1000.0
	if gap <= 0.0 or float(now_usec - int(last[0])) / 1000.0 > maxf(FLING_STILL_MS, gap * 2.0):
		return 0.0
	var ts := PackedFloat64Array([0.0])
	var degs := PackedFloat64Array([float(last[1])])
	# The last tenth of a second, or the last three moves where they come
	# further apart, back to where the pointer paused.
	var window: float = maxf(FLING_WINDOW_MS, gap * 3.0)
	for n: int in range(_turns_seen.size() - 2, -1, -1):
		var one: Array = _turns_seen[n]
		var next: Array = _turns_seen[n + 1]
		var this_gap: float = float(int(next[0]) - int(one[0])) / 1000.0
		var back: float = float(int(last[0]) - int(one[0])) / 1000.0
		var went: float = deg_to_rad(absf(float(next[1]) - float(one[1])))
		if back > window or (this_gap > FLING_PAUSE_MS and went / (this_gap / 1000.0) < FLING_LEAST):
			break
		ts.append(-back / 1000.0)
		degs.append(float(one[1]))
	if ts.size() < 2:
		return 0.0
	var mean_t: float = 0.0
	var mean_d: float = 0.0
	for n: int in ts.size():
		mean_t += ts[n] / ts.size()
		mean_d += degs[n] / ts.size()
	var top: float = 0.0
	var bottom: float = 0.0
	for n: int in ts.size():
		top += (ts[n] - mean_t) * (degs[n] - mean_d)
		bottom += (ts[n] - mean_t) * (ts[n] - mean_t)
	if bottom <= 0.0:
		return 0.0
	var rate: float = deg_to_rad(top / bottom)
	if absf(rate) < FLING_LEAST:
		return 0.0
	return clampf(rate, -FLING_MOST, FLING_MOST)


## Where the pointer says the joint is turned, degrees, unwrapped so a turn
## past half way carries on round.
func _pointer_angle(origin: Vector3, direction: Vector3, screen: Vector2,
		eye: Camera3D = null) -> float:
	var held: Vector3 = _hold - pivot
	held -= axis * held.dot(axis)
	var facing: float = absf(direction.normalized().dot(axis))
	if held.length() < 1.0:
		# Held on the line itself: up and down the screen turn it.
		return -(screen.y - _hold_screen.y) * EDGE_ON_RATE
	if facing < EDGE_ON and eye != null:
		# Nearly edge on, the plane the held point turns in is a line on the
		# screen: the turn whose held point is drawn nearest the pointer,
		# within a half turn of where it is (4096's boom, seen from the side).
		var best: float = _unwrapped
		var nearest: float = INF
		for k: int in range(-36, 37):
			var trial: float = _unwrapped + float(k) * 2.5
			var at: Vector3 = Transform3D(Basis.IDENTITY, pivot) \
				* Transform3D(Basis(axis, deg_to_rad(trial)), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -pivot) * _hold
			if eye.is_position_behind(at):
				continue
			# Edge on, a turn and its mirror about the plane's long axis are
			# drawn at one place: of the two, the one nearer where it was
			# (4096's boom jumped 45° to its mirror for a frame).
			var gap: float = eye.unproject_position(at).distance_to(screen) \
				+ absf(trial - _unwrapped) * CONTINUITY
			if gap < nearest:
				nearest = gap
				best = trial
		for k: int in range(-10, 11):
			var trial: float = best + float(k) * 0.25
			var at: Vector3 = Transform3D(Basis.IDENTITY, pivot) \
				* Transform3D(Basis(axis, deg_to_rad(trial)), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -pivot) * _hold
			var gap: float = eye.unproject_position(at).distance_to(screen) \
				+ absf(trial - _unwrapped) * CONTINUITY
			if gap < nearest:
				nearest = gap
				best = trial
		_unwrapped = best
		_last_raw = wrapf(best, -180.0, 180.0)
		return best
	# The plane the held point turns in: through it, square to the line.
	var denom: float = direction.dot(axis)
	var t: float = (_hold - origin).dot(axis) / denom
	var on: Vector3 = origin + direction * t - pivot
	on -= axis * on.dot(axis)
	if on.length() < 0.5:
		return _unwrapped
	var raw: float = rad_to_deg(atan2(axis.dot(held.cross(on)), held.dot(on)))
	var step: float = wrapf(raw - _last_raw, -180.0, 180.0)
	_last_raw = raw
	_unwrapped += step
	return _unwrapped


## Where the pointer says a loop's driver is turned, when its joint is
## carried by the loop itself (a coupler grabbed, its pivot on the crank):
## the turn that brings the point held nearest the pointer on the screen,
## stepped along the way the loop moves it (three steps of Newton's method
## on the screen distance, each from two solves of the loop).
func _pointer_loop(screen: Vector2, eye: Camera3D) -> float:
	var t: float = angle
	var probe: float = 0.5
	for _step: int in 3:
		var here: Variant = _held_on_screen(t, eye)
		var there: Variant = _held_on_screen(t + probe, eye)
		if here == null or there == null:
			break
		var way: Vector2 = ((there as Vector2) - (here as Vector2)) / probe
		if way.length_squared() < 1e-6:
			break
		var dt: float = (screen - (here as Vector2)).dot(way) / way.length_squared()
		t += clampf(dt, -15.0, 15.0)
		if absf(dt) < 0.05:
			break
	return t


## Where the point held is drawn with the loop's driver at [param degrees];
## null where the loop does not close there.
func _held_on_screen(degrees: float, eye: Camera3D) -> Variant:
	var got: float = rad_to_deg(linkage.reach(deg_to_rad(degrees)))
	if absf(got - degrees) > 0.01:
		return null
	var at: Dictionary = linkage.places()
	var move: Transform3D = at.get(body, Transform3D.IDENTITY)
	var point: Vector3 = move * _hold
	if eye.is_position_behind(point):
		return null
	return eye.unproject_position(point)


## Where the pointer says a slide has gone: the point of the joint's line
## nearest the pointer's ray, against where it was held.
func _pointer_along(origin: Vector3, direction: Vector3) -> float:
	# The line the held point slides on, not the joint's own: the pointer
	# stays on the point it took hold of, whatever the eye's perspective.
	var d: Vector3 = direction.normalized()
	var w: Vector3 = _hold - origin
	var b: float = axis.dot(d)
	var denom: float = 1.0 - b * b
	if denom < 1e-4:
		return shift
	return (b * w.dot(d) - w.dot(axis)) / denom


## A ball turned so the point held goes towards the pointer: the turn that
## carries where it was held onto the pointer's ray at the same distance
## from the middle.
func _pointer_twist(origin: Vector3, direction: Vector3) -> Basis:
	var held: Vector3 = _hold - pivot
	var radius: float = maxf(held.length(), 4.0)
	var d: Vector3 = direction.normalized()
	var w: Vector3 = origin - pivot
	var b: float = w.dot(d)
	var c: float = w.dot(w) - radius * radius
	var disc: float = b * b - c
	var on: Vector3
	if disc >= 0.0:
		on = w + d * (-b - sqrt(disc))
	else:
		on = w + d * (-b)
	if on.length() < 0.5 or held.length() < 0.5:
		return twist
	var turn := Quaternion(held.normalized(), on.normalized())
	return Basis(turn)


# -- letting go ------------------------------------------------------------------------


## Where a joint that does not hold by friction comes to rest under its own
## weight: turned towards where the centre of mass of what it carries is
## lowest, as far as it has room for. Quasi-static: no swing past it and
## back. Returns words, or "" when it stays where it was put.
func settle() -> String:
	if linkage != null:
		return _settle_loop()
	var words: String = _settle_joint()
	_settle_inside()
	if not inner_swung.is_empty():
		var more: String = "%s inside it swung down too (%s)" % [
			"a free joint" if inner_swung.size() == 1 else "%d free joints" % inner_swung.size(),
			", ".join(inner_swung)]
		words = more if words.is_empty() else "%s; %s" % [words, more]
	return words


## The grabbed joint's own swing under its weight, when it does not hold.
func _settle_joint() -> String:
	if state != "moves" or mode != "turn" or link.holds or grams <= 0.0:
		return ""
	var turned: Transform3D = Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(axis, deg_to_rad(angle)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var centre: Vector3 = turned * _centre
	var out: Vector3 = centre - pivot
	out -= axis * out.dot(axis)
	var down: Vector3 = Vector3.DOWN - axis * Vector3.DOWN.dot(axis)
	if out.length() < 0.5 or down.length() < 0.05:
		return ""
	var to_bottom: float = rad_to_deg(atan2(axis.dot(out.cross(down)), out.dot(down)))
	if absf(to_bottom) < 0.5:
		return ""
	var from: float = angle
	turn_to(angle + to_bottom)
	var swung: float = angle - from
	if absf(swung) < 0.5:
		return ""
	if stopped:
		return "swung %d° under its own weight until it met the model" % roundi(absf(swung))
	return "swung %d° down under its own weight: %s turns freely" % [roundi(absf(swung)),
		link.words().trim_prefix("on ")]


## Every joint inside what moved that does not hold by friction swings down
## under the weight of what it carries too, innermost first and then again
## (a pendulum on a pendulum), each turned as far as it has room against the
## model that stands. Quasi-static, as [method settle]: no swing past it and
## back. What swung is said in [member inner_swung].
func _settle_inside() -> void:
	inner_swung.clear()
	if state != "moves" or mode == "ball":
		return
	var inner: Array = []   ## [child body, link]
	var ours: Dictionary = {}
	for one: int in moving_bodies:
		ours[one] = true
	for one: int in follower_bodies:
		ours[one] = true
	for one: int in ours:
		var joined: Bodies.Link = bodies.parent_link.get(one)
		if joined == null or joined == link or joined.holds or joined.axis == Vector3.ZERO:
			continue
		if not ours.has(int(bodies.parent_of[one])) and not follower_bodies.has(one):
			continue
		inner.append([one, joined])
	if inner.is_empty():
		return
	var swung: Dictionary = {}   ## child body -> degrees
	for _pass: int in 3:
		var any: bool = false
		for entry: Array in inner:
			var turned: float = _swing_inner(int(entry[0]), entry[1])
			if absf(turned) >= 0.5:
				swung[int(entry[0])] = float(swung.get(int(entry[0]), 0.0)) + turned
				any = true
		if not any:
			break
	for one: int in swung:
		if absf(float(swung[one])) >= 0.5:
			inner_swung.append("%s %d°" % [bodies.named(bodies.beyond(one)).get_slice(",", 0),
				roundi(absf(float(swung[one])))])


## Turn the joint [param joined] above [param child] so the centre of mass of
## everything beyond it comes under its line, as far as it has room. Returns
## the degrees it turned.
func _swing_inner(child: int, joined: Bodies.Link) -> float:
	var parts: PackedInt64Array = bodies.parts_of(bodies.beyond(child))
	# Its line and point where what carries it now stands.
	var carrier: int = int(bodies.parent_of[child])
	var carrier_key: int = int((bodies.members[carrier] as PackedInt64Array)[0])
	var carried: Transform3D = (placed[carrier_key] as Transform3D) \
		* (rest[carrier_key] as Transform3D).affine_inverse()
	var turn_point: Vector3 = carried * joined.point
	var way: Vector3 = (carried.basis * joined.axis).normalized()
	var weight: float = 0.0
	var sum := Vector3.ZERO
	for key: int in parts:
		var info: PartLibrary.PartInfo = library.parts.get(world.get_brick(key).part_id)
		if info == null or not placed.has(key):
			continue
		var g: float = Stability.grams(info)
		weight += g
		sum += ((placed[key] as Transform3D) * info.bounds.get_center()) * g
	if weight <= 0.0:
		return 0.0
	var out: Vector3 = sum / weight - turn_point
	out -= way * out.dot(way)
	var down: Vector3 = Vector3.DOWN - way * Vector3.DOWN.dot(way)
	if out.length() < 0.5 or down.length() < 0.05:
		return 0.0
	var to_bottom: float = rad_to_deg(atan2(way.dot(out.cross(down)), out.dot(down)))
	if absf(to_bottom) < 0.5:
		return 0.0
	var at_turn := func(degrees: float) -> Dictionary:
		var move: Transform3D = Transform3D(Basis.IDENTITY, turn_point) \
			* Transform3D(Basis(way, deg_to_rad(degrees)), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -turn_point)
		var out_at: Dictionary = {}
		for key: int in parts:
			if placed.has(key):
				out_at[key] = move * (placed[key] as Transform3D)
		return out_at
	var low: float = 0.0
	var high: float = to_bottom
	if not _room_for(at_turn.call(high)):
		for _round: int in ROUNDS:
			var middle: float = (low + high) * 0.5
			if _room_for(at_turn.call(middle)):
				low = middle
			else:
				high = middle
		high = low
	if absf(high) < 0.5:
		return 0.0
	var moved_to: Dictionary = at_turn.call(high)
	for key: Variant in moved_to:
		placed[key] = moved_to[key]
	return high


## Whether the parts [param at] names have room there against the model
## that stands: nothing in the way but what moves with the grab or is
## joined to it, and not through the floor.
func _room_for(at: Dictionary) -> bool:
	for key: Variant in at:
		var brick: BrickWorld.Brick = world.get_brick(int(key))
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			continue
		var to: Transform3D = at[key]
		var box: AABB = to * mesh.bounds
		if box.position.y < _floor_y - BELOW_FLOOR and mesh.lowest_at(to) < _floor_y - BELOW_FLOOR:
			return false
		if not _near_anything(box, int(key)) or not _boxes_meet(int(key), mesh, to, box):
			continue
		var packed: PackedInt32Array = builder.boxes_for(mesh, to)
		if not _blocked(int(key), mesh, to, packed).is_empty():
			return false
	return true


## A loop that no friction holds turns down under its weight: its driver
## stepped downhill while the centre of mass of what it moves comes lower and
## it has room, the step halved where it does not.
func _settle_loop() -> String:
	if state != "moves" or mode != "turn" or linkage.holds() or grams <= 0.0:
		return ""
	var from: float = angle
	transforms_at(angle)
	var best: float = linkage.centre_y()
	var step: float = 8.0
	var rounds: int = 0
	while step >= 0.25 and rounds < 200:
		rounds += 1
		var better: bool = false
		for way: float in [1.0, -1.0]:
			var trial: float = angle + way * step
			var got: float = rad_to_deg(linkage.reach(deg_to_rad(trial)))
			if absf(got - trial) > 0.01:
				continue
			var lower: float = linkage.centre_y()
			if lower < best - 0.01 and has_room(linkage.transforms(rest)):
				best = lower
				angle = trial
				placed = linkage.transforms(rest)
				_keep_loop()
				better = true
				break
		if not better:
			step *= 0.5
	if absf(angle - from) < 0.5:
		return ""
	return "the loop turned %d° under its own weight: no joint in it holds by friction" % roundi(
		absf(angle - from))


## The swing under its weight once let go ([Swing]): the grabbed joint when
## it does not hold, and every free joint inside what moved, a chain of them
## swinging together. Null when it settles as before ([method settle]): a
## loop, a ball, a gear train, a click hinge, a section of more than
## [constant SWING_MOST_PARTS] parts (its room tests cost more than a frame).
var swing: Swing = null
## More parts than this moving settle as before.
const SWING_MOST_PARTS := 40
## The grabbed joint's turn where it was let go, degrees; the child body of
## each joint that swings -> its index in [member swing].
var _let_go_at: float = 0.0
var _swing_index: Dictionary = {}
## The bodies that move (body -> true), for the swing's tree.
var _ours: Dictionary = {}
## A swing that began as the model landed from a fall (GrabDrag): the
## history's depth the drag began at, and what was said of the fall.
var landing: bool = false
var landing_depth: int = 0
var landing_said: String = ""


## Set up [member swing] from where it was let go, turning at [param fling]
## rad/s about [member axis] as the pointer had it (fling_rate): it carries
## on at that rate and coasts. False when nothing it carries swings (every
## joint holds, or it is not a case a swing takes). A gear train the grab
## drives turns with it, each gear at its ratio, when no bearing of the
## train holds by friction.
func swing_begin(fling: float = 0.0) -> bool:
	swing = null
	_swing_index.clear()
	train_held = false
	if state != "moves" or mode != "turn" or linkage != null or grams <= 0.0 or unchecked:
		return false
	if moving.size() + followers.size() > SWING_MOST_PARTS:
		return false
	if bodies.parent_link.get(body) != link:
		return false
	var train: Array = []
	if not coupled.is_empty():
		# The train turns with the grabbed joint: it swings only when that joint
		# and every bearing of the train turns freely.
		if mechanism == null or not Grab._swings(link):
			return false
		if _train_holds():
			train_held = true
			return false
		train = _train_parts()
	elif not followers.is_empty():
		return false
	_ours.clear()
	for one: int in moving_bodies:
		_ours[one] = true
	var free: Dictionary = {}   ## child body -> its link
	if Grab._swings(link):
		free[body] = link
	for one: int in moving_bodies:
		if one == body:
			continue
		var joined: Bodies.Link = bodies.parent_link.get(one)
		if joined != null and Grab._swings(joined) and _ours.has(int(bodies.parent_of.get(one, -1))):
			free[one] = joined
	if free.is_empty():
		return false
	_let_go_at = angle
	_make_swing(free, train)
	if fling != 0.0 and _swing_index.has(body) and int(_swing_index[body]) == 0:
		swing.fling(fling)
	return true


## A bearing of the train the grab drives holds by friction (a gear pinned on
## with a friction pin): it stays where it is let go, as the grabbed joint
## would. Set by [method swing_begin].
var train_held: bool = false


## Whether a gear the grab drives turns on a joint that holds by friction:
## [Bodies]' joints of its body on the gear reading's line for it.
func _train_holds() -> bool:
	var seen: Dictionary = {}
	for key: int in coupled:
		var one: int = int(bodies.body_of.get(key, -1))
		var turning: Mechanism.Joint = mechanism.joint_of(mechanism.body_of(key))
		if one < 0 or seen.has(one) or turning == null:
			continue
		seen[one] = true
		for joined: Bodies.Link in bodies.touching.get(one, []):
			if joined.axis != Vector3.ZERO and joined.turns and joined.holds \
					and Bodies._same_line(joined.point, joined.axis, turning.point, turning.way):
				return true
	return false


## The gears the grab drives and what rides on each, as the swing's geared
## segments: [keys, a point on its line, its spin (radians a radian of the
## grabbed joint, about its own line)] where it was let go. The spin is the
## gear reading's rate (Mechanism.omega); the line, its joint's where it
## turns on an axle in what stands, else the line it then turns about (a
## gear on a carrier the train turns), read off where the train puts its
## middle a hundredth of a radian either side.
func _train_parts() -> Array:
	var by_body: Dictionary = {}   ## gear reading's body -> keys
	for key: int in coupled:
		var one: int = mechanism.body_of(key)
		if not by_body.has(one):
			by_body[one] = []
		(by_body[one] as Array).append(key)
	for key: int in followers:
		var one: int = mechanism.body_of(int(followers[key]))
		if not by_body.has(one):
			by_body[one] = []
		(by_body[one] as Array).append(key)
	var out: Array = []
	var h: float = 0.01
	var at: float = deg_to_rad(angle) * _drive_sign
	for one: int in by_body:
		var keys: Array = by_body[one]
		var spin: Vector3 = mechanism.omega(one) * _drive_sign
		if spin.length() < 1e-6:
			continue
		var path: Array = mechanism.path(one)
		var point: Vector3
		if path.size() == 1:
			point = (path[0] as Mechanism.Joint).point
		else:
			var key: int = int(keys[0])
			var middle: Vector3 = library.mesh_for(world.get_brick(key).part_id).bounds.get_center()
			var before: Vector3 = (mechanism.pose_of(at - h * _drive_sign, {key: true})[key] as Transform3D) * middle
			var after: Vector3 = (mechanism.pose_of(at + h * _drive_sign, {key: true})[key] as Transform3D) * middle
			var now: Vector3 = (placed[key] as Transform3D) * middle
			# A turn ω about a line through p moves c at ω × (c - p).
			point = now + spin.cross((after - before) / (2.0 * h)) / spin.length_squared()
		out.append([keys, point, spin])
	return out


## Whether a joint swings when let go: it turns on a line, freely (no
## friction holds it, no clicks).
static func _swings(joined: Bodies.Link) -> bool:
	return joined != null and not joined.holds and joined.axis != Vector3.ZERO and joined.turns \
		and joined.detent <= 0.0


## A model that has just landed from a fall (GrabDrag): every joint in it
## that does not hold swings in its new lie, starting with the speed the
## fall gave it: the model was turning at [param spin] (rad/s about its
## line) about [param about], and stops dead as it lands; what hangs on a
## free joint carries on (its momentum about the joint kept: Swing.carry).
## False when nothing in it swings. [member bodies] must be read for the
## model as it lies.
func land_begin(spin: Vector3, about: Vector3) -> bool:
	state = "moves"
	mode = "turn"
	linkage = null
	landing = true
	var free: Dictionary = {}
	for one: Variant in bodies.parent_link:
		var joined: Bodies.Link = bodies.parent_link[one]
		if Grab._swings(joined) and not bodies.anchors.has(int(one)):
			free[int(one)] = joined
	if free.is_empty():
		return false
	_ours.clear()
	moving_bodies = []
	for one: int in free:
		for x: int in bodies.beyond(one):
			if not _ours.has(x):
				_ours[x] = true
				moving_bodies.append(x)
	# The outermost free joint in: what is said moved, and its line.
	body = -1
	for one: int in free:
		if not _ours.has(int(bodies.parent_of.get(one, -1))):
			if body < 0 or bodies.parts_of(bodies.beyond(one)).size() > bodies.parts_of(bodies.beyond(body)).size():
				body = one
	if body < 0:
		return false
	link = free[body]
	pivot = link.point
	axis = link.axis.normalized()
	moving.clear()
	for key: int in bodies.parts_of(moving_bodies):
		moving[key] = true
	skip = moving.duplicate()
	_near_kept.clear()
	_join_across(_ours)
	rest.clear()
	grams = 0.0
	_floor_y = INF
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if info == null or mesh == null:
			continue
		# Its lowest point, not its turned box's: a model lying tilted reaches
		# lower by its boxes' corners than by its shapes.
		_floor_y = minf(_floor_y, mesh.lowest_at(brick.transform))
		if moving.has(brick.id):
			rest[brick.id] = brick.transform
			grams += Stability.grams(info)
	placed = rest.duplicate()
	said = _named()
	angle = 0.0
	_let_go_at = 0.0
	_make_swing(free)
	swing.carry(spin, about)
	return true


## [member swing] from [param free] (child body -> its link), each joint's
## line where [member placed] has it, and the gear train the grabbed joint
## drives, [param train] ([method _train_parts]), turning with it.
func _make_swing(free: Dictionary, train: Array = []) -> void:
	var order: Array = free.keys()
	order.sort_custom(func(x: int, y: int) -> bool: return _depth(x) < _depth(y))
	var made := Swing.new()
	for child: int in order:
		var joined: Bodies.Link = free[child]
		var point: Vector3 = joined.point
		var way: Vector3 = joined.axis.normalized()
		var parent: int = -1
		if bodies.parent_of.has(child):
			# Its line where what carries it now stands.
			var carrier: int = int(bodies.parent_of[child])
			var carrier_key: int = int((bodies.members[carrier] as PackedInt64Array)[0])
			if placed.has(carrier_key):
				var carried: Transform3D = (placed[carrier_key] as Transform3D) \
					* (rest[carrier_key] as Transform3D).affine_inverse()
				point = carried * joined.point
				way = (carried.basis * joined.axis).normalized()
			parent = _swing_joint_of(carrier)
		_swing_index[child] = made.add_joint(point, way, parent,
			bodies.named(bodies.beyond(child)).get_slice(",", 0))
		made.joints[int(_swing_index[child])].bearing = Swing.bearing_of(joined)
	var by_joint: Dictionary = {}   ## joint index -> brick ids
	for one: int in moving_bodies:
		var j: int = _swing_joint_of(one)
		if j < 0:
			continue
		if not by_joint.has(j):
			by_joint[j] = []
		(by_joint[j] as Array).append_array(Array(bodies.members[one] as PackedInt64Array))
	for j: int in by_joint:
		var start: Dictionary = {}
		for key: int in by_joint[j]:
			start[key] = placed[key]
		made.add_segment(j, start, Swing.lump(world, library, by_joint[j], placed))
	if _swing_index.has(body):
		for gear: Array in train:
			var start: Dictionary = {}
			for key: int in gear[0]:
				start[key] = placed[key]
			made.add_geared(int(_swing_index[body]), start, Swing.lump(world, library, gear[0], placed),
				gear[1], gear[2])
	made.ready_up(world, library)
	made.room = func(at: Dictionary) -> int:
		var whole: Dictionary = placed.duplicate()
		for key: Variant in at:
			whole[key] = at[key]
		met = 0
		return 0 if _test(whole, 0, INF).x != 0 else maxi(met, 1)
	swing = made


## How many bodies lie between [param one] and the edge of what moves.
func _depth(one: int) -> int:
	var n: int = 0
	var at: int = one
	while _ours.has(at) and bodies.parent_of.has(at) and n < 1000:
		at = int(bodies.parent_of[at])
		n += 1
	return n


## The swing's joint [param one] hangs from: the innermost free joint
## between it and the edge of what moves; -1 for none (it does not swing).
func _swing_joint_of(one: int) -> int:
	var at: int = one
	for _n: int in 1000:
		if _swing_index.has(at):
			return int(_swing_index[at])
		if not _ours.has(at) or not bodies.parent_of.has(at):
			return -1
		at = int(bodies.parent_of[at])
	return -1


## Whether the grabbed joint itself swings (it does not hold).
func swing_has_grabbed() -> bool:
	return swing != null and _swing_index.has(body)


## Where the swing has it now: [member placed], and the grabbed joint's
## [member angle].
func swing_pose() -> void:
	if swing == null:
		return
	var at: Dictionary = swing.pose()
	for key: Variant in at:
		placed[key] = at[key]
	if mechanism != null and not coupled.is_empty():
		_pose_crosses(placed)
	if _swing_index.has(body):
		angle = _let_go_at + rad_to_deg(swing.q[int(_swing_index[body])])


## What the swing did, in words: "swung down under its own weight and back
## and forth 9 times in 3.2 s, and came to rest at 2°, hanging within its
## friction of straight down"; "" for no swing.
func swing_words() -> String:
	if swing == null:
		return ""
	var said: String = swing.words()
	if said.is_empty():
		return ""
	if not _swing_index.has(body):
		var names := PackedStringArray()
		for one: Swing.Joint in swing.joints:
			names.append(one.name)
		return "%s inside it %s" % [", ".join(names), said]
	var hangs: String = ""
	if swing.stops > 0 and swing.joints[int(_swing_index[body])].pressed != 0:
		hangs = ", resting against what it met"
	elif _balanced():
		# Its weight on its line: nothing turns it but the pointer, and its
		# bearing's friction alone stops it.
		hangs = ", stopped by its bearing's friction"
	else:
		hangs = ", hanging within its friction of straight down"
	var out: String = "%s, and came to rest at %d°%s" % [said, roundi(angle), hangs]
	if absf(swing.flung) > 0.0:
		out = "%s, and came to rest at %d° (%s round from where it was taken hold of)%s" % [said, roundi(angle),
			Grab._turns_words(angle), "" if hangs == ", stopped by its bearing's friction" else hangs]
	if not coupled.is_empty():
		out += "; the gears it drives turned with it, each by its teeth"
	if swing.joints.size() > 1:
		out += " (a chain of %d free joints, swinging together)" % swing.joints.size()
	return out


## Whether the swing's grabbed joint carries its weight on its line, or so
## near it that its friction holds it at any turn: a wheel on its axle, a
## gear train, a turntable standing upright. The most gravity can turn it
## by, each segment's weight times how far its centre stands off its line
## (times the line's lean from upright, times a gear's ratio), is no more
## than its friction.
func _balanced() -> bool:
	if swing == null or not _swing_index.has(body):
		return false
	var j: int = int(_swing_index[body])
	var joint: Swing.Joint = swing.joints[j]
	var most: float = 0.0
	var frames: Array[Transform3D] = swing.frames_at(swing.q)
	for segment: Swing.Segment in swing.segments:
		if not segment.geared and not swing.joints[segment.joint].chain.has(j):
			continue
		var frame: Transform3D = swing._frame_of(segment, frames, swing.q)
		var line: Vector3 = segment.turn_axis if segment.geared else joint.axis
		var on: Vector3 = segment.turn_point if segment.geared else joint.point
		var off: Vector3 = frame * segment.centre - on
		off -= line * off.dot(line)
		most += segment.grams * Swing.GRAVITY * off.length() * line.cross(Vector3.UP).length() \
			* (segment.ratio if segment.geared else 1.0)
	return most <= joint.friction


## How far round [param degrees] is, in words: "35°", "4.1 turns".
static func _turns_words(degrees: float) -> String:
	if absf(degrees) < 360.0:
		return "%d°" % roundi(absf(degrees))
	return "%s turns" % Balance.tidy(absf(degrees) / 360.0)


## Put every part that moved where it now stands, as one step to undo,
## called [param words]. Returns how many moved.
func commit(words: String, cells: Dictionary = {}) -> int:
	var steps: Array = []
	# The hoses laid where they are kept; one laid as more or fewer pieces
	# than it has is laid afresh in its place, in the same step.
	var swapping: Dictionary = {}
	var hose_keys: Dictionary = {}
	if flex != null:
		flex.lay_into(placed, true)
		swapping = flex.swapped()
		hose_keys = flex.keys()
	for key: int in placed:
		var brick: BrickWorld.Brick = world.get_brick(key)
		if brick == null or swapping.has(key):
			continue
		var to: Transform3D = placed[key]
		if Grab._same(to, rest[key]):
			continue
		steps.append({"undo": "move", "brick": key, "transform": rest[key]})
		_built_for_world()
		_moved_since_built[key] = true
		if not _built_at.has(key):
			_built_at[key] = rest[key]
		world.move_brick(key, to)
		builder.lattice.release(key)
		# Worked out ahead, a share a frame, for a big section (GrabDrag):
		# its cover, bound and rows (BrickLattice.cover_for). Not a hose's:
		# its cells were worked out where a drag drew it.
		var cover: Variant = cells.get(key) if not hose_keys.has(key) else null
		if cover != null:
			builder.lattice.occupy_moved(key, cover, Vector3i.ZERO)
		else:
			builder.lattice.occupy_boxes(key, builder.boxes_for(library.mesh_for(brick.part_id), to))
	var moved: int = steps.size() + swapping.size()
	if flex != null and not swapping.is_empty():
		steps.append_array(flex.swap(builder, placed, rest))
	builder.record(steps, words)
	return moved


## [member placed] with the hoses this grab bends laid where it puts their
## ends ([FlexFollow]): what is drawn. Within a frame's budget unless
## [param full], as each is kept.
func drawn(full: bool = false) -> Dictionary:
	if flex != null:
		flex.lay_into(placed, full)
	return placed


## The parts that will move when it is kept: brick id -> where.
func changed() -> Dictionary:
	var out: Dictionary = {}
	for key: int in placed:
		if world.get_brick(key) != null and not Grab._same(placed[key], rest[key]):
			out[key] = placed[key]
	return out


## The joint now, in words: "45°", "3 LDU along", "turned 30°".
func position_words() -> String:
	match mode:
		"slide":
			return "%s studs along" % Balance.studs(shift / BrickLattice.STUD)
		"ball":
			var turned: float = rad_to_deg(Quaternion(twist.orthonormalized()).get_angle())
			return "turned %d°" % roundi(turned)
	return "%d°" % roundi(angle)


## The joint's turn from where the model was built, degrees about its line
## as [member angle] counts them, or its slide, LDU: the moving side's part
## against the part across the joint, as both stand now, so a loop that
## carries both, or the whole model turned, leaves it as it is. [member
## angle] is this grab's alone: a session turned a kart's steering 20° and
## then 15° more, and was told "now 15°". NAN for a ball.
func from_built() -> float:
	if state != "moves" or link == null or mode == "ball" or not bodies.members.has(body) \
			or not bodies.members.has(link.other(body)):
		return NAN
	var ours: int = int((bodies.members[body] as PackedInt64Array)[0])
	var theirs: int = int((bodies.members[link.other(body)] as PackedInt64Array)[0])
	var mine: BrickWorld.Brick = world.get_brick(ours)
	var across: BrickWorld.Brick = world.get_brick(theirs)
	if mine == null or across == null:
		return NAN
	_built_for_world()
	var now: Transform3D = across.transform.affine_inverse() * mine.transform
	var then: Transform3D = (_built_at.get(theirs, across.transform) as Transform3D).affine_inverse() \
		* (_built_at.get(ours, mine.transform) as Transform3D)
	# The joint's line as the part across it holds it, from where it was grabbed.
	var line: Vector3 = ((rest.get(theirs, across.transform) as Transform3D).basis.orthonormalized().inverse()
		* axis).normalized()
	if mode == "slide":
		return (now.origin - then.origin).dot(line)
	var turned: Basis = now.basis.orthonormalized() * then.basis.orthonormalized().inverse()
	var square: Vector3 = (Vector3.UP if absf(line.y) < 0.9 else Vector3.RIGHT).cross(line).normalized()
	var to: Vector3 = turned * square
	return rad_to_deg(atan2(line.dot(square.cross(to)), square.dot(to)))


## The step's words: "turned the boom, 38 parts, on its turntable to 45°".
func step_words() -> String:
	var verb: String = {"slide": "slid", "ball": "turned"}.get(mode, "turned")
	return "%s %s %s %s" % [verb, _named(), link.words(),
		"to " + position_words() if mode == "turn" else position_words()]
