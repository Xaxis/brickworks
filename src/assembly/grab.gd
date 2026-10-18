## A section of the model taken in hand and moved about its joint as the real
## thing moves: a wing on its hinge, a boom on its turntable, an arm on its
## shoulder with the hand and what it holds, a gear and the train it drives.
##
## The owner (2026-10-17): a person "should be able to manipulate and move any
## hinging, moving, otherwise interactive part with perfect physics/support/
## structure simulation". What moves is read by [Bodies]: the grabbed part's
## rigid body and everything beyond it, turned on the one joint between it
## and the anchor (what stays: a locked part, the baseplate, else the
## heaviest body). Grabbing a joint's anchored half moves its other half.
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
## What the moving side may press against: across its joint.
var skip: Dictionary = {}
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
var _verify_from: int = 0
var _verifying_lo: float = 0.0
var _verifying_hi: Variant = null
## Moving parts all within reach of the joint's line: not tested for room.
var _on_the_line: Dictionary = {}
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
## Parts met, and whether they overlapped the moving side where it stood.
var _rest_overlap: Dictionary = {}
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
## The slowest part to test in a drag, and on what: for a probe.
var slowest_us: int = 0
var slowest_said: String = ""


## Read what [param brick_id] would move, from where the pointer [param at]
## took hold of it. [param selection] (brick id -> true), when it holds the
## part and more, is moved as one about what joins it to the rest.
func begin(brick_id: int, at: Vector3, selection: Dictionary = {}) -> String:
	part = brick_id
	_hold = at
	if bodies == null or bodies.revision != world.revision:
		bodies = Bodies.read(world, library, builder.lattice, bodies.scenery if bodies != null else {},
			builder.locked)
	if not bodies.body_of.has(brick_id):
		return _refuse("rigid", "that part is not part of the model")
	if selection.size() > 1 and selection.has(brick_id):
		_from_selection(selection)
	else:
		_from_part(brick_id)
	return _chosen()


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
	linkage = null
	var loop: Linkage = null
	var other_words: String = ""
	if not held.is_empty() or not geared.is_empty():
		# Held at both ends: a closed loop, moved as it allows (Linkage).
		other_words = held[0].words().trim_prefix("on ") if not held.is_empty() \
			else "by %s" % geared[0].said(world)
		if link.axis == Vector3.ZERO:
			return _refuse("loop", ("%s is on a ball in a closed loop, and the loop moves it: take hold "
				+ "of a part on one of the loop's turning joints (its crank).") % _named())
		loop = Linkage.read(bodies, link, body, couplings)
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
	# A hose bends out of the way, and is not tested where it is carried.
	for one: int in bodies.flexible:
		for key: int in bodies.members.get(one, PackedInt64Array()):
			skip[key] = true
	for one: int in moving_bodies:
		for joined: Bodies.Link in bodies.touching.get(one, []):
			if ours.has(joined.other(one)):
				continue
			for pair: Array in joined.pairs:
				for key: int in pair:
					skip[key] = true
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
	# (18 ms) to find its own tyre's neighbour forgiven.
	if linkage != null and moving.size() <= LOOP_AHEAD_PARTS:
		for key: int in moving:
			var boxes: PackedInt32Array = builder.lattice.boxes_of(key)
			if boxes.is_empty():
				continue
			for other: int in builder.lattice.blockers_boxes(boxes, key, {}):
				if not moving.has(other):
					_rest_overlap[other] = true
					skip[other] = true
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
	axis = link.axis.normalized()
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
			var furthest: float = 0.0
			for corner: int in 8:
				var off: Vector3 = brick.transform * mesh.bounds.get_endpoint(corner) - pivot
				furthest = maxf(furthest, (off - axis * off.dot(axis)).length())
			if furthest <= ON_THE_LINE * 1.42 or _round_on(key, pivot, axis):
				_on_the_line[key] = true
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
				if _round_on(key, joined.point, joined.axis.normalized()):
					if carried:
						_spin_with[key] = int(linkage.parent_of[n])
					else:
						_on_the_line[key] = true
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
	placed = rest.duplicate()
	said = "%s %s" % [_named(), link.words()]
	if linkage != null:
		said += ", in %s" % linkage.said()
	return state


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
	for mesh: Racks.Pinion in bodies.racks():
		if turning.has(mesh.gear) and not ours.has(int(bodies.body_of[mesh.rack])):
			pinions.append(mesh)
	if pinions.is_empty():
		return none
	var meshes: Array = []
	for coupling: Mechanism.Coupling in train.couplings:
		if coupling.how != "chain" and turning.has(coupling.one.key) and turning.has(coupling.other.key):
			meshes.append(coupling)
	return [meshes, pinions]


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
## go on from).
func _test(at: Dictionary, from: int, budget: float) -> Vector2i:
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
	var meets: Dictionary = _covers_ahead(at, keys, carried_at) if budget == INF else {}
	while n < keys.size():
		if budget < INF and float(Time.get_ticks_usec() - started) / 1000.0 > budget:
			result = -1
			break
		var key: int = keys[n]
		n += 1
		if _on_the_line.has(key) or bodies.flexible.has(int(bodies.body_of.get(key, -1))):
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
		elif not _near_anything(box) or not _boxes_meet(key, mesh, to, box):
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
	test_ms = float(Time.get_ticks_usec() - started) / 1000.0
	frame_test_ms += test_ms
	frame_tests += 1
	return Vector2i(result, n if result == -1 else 0)


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
		var may: bool = _near_anything(box) and _boxes_meet(key, mesh, to, box)
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
	for other: int in builder.lattice.blockers_boxes(turned.loose_at(), 0, skip):
		if skip.has(other) or not turned.meets(builder.lattice.boxes_of(other)):
			continue
		if _overlapped_at_rest(other):
			skip[other] = true
		elif not _slides_over(key, mesh, to, other) and not _touching(mesh, to, other):
			return PackedInt64Array([other])
	return PackedInt64Array()


## What [param key], its cover [param packed] at [param to], meets: nothing
## but what the moving side may press on. What it overlapped where it stood
## is forgiven for good; what it slides over across a face square to the
## line it turns on, for this part alone ([method _slides_over]).
func _blocked(key: int, mesh: Lbm.PartMesh, to: Transform3D, packed: PackedInt32Array) -> PackedInt64Array:
	var forgiven: Array = []
	var hit: PackedInt64Array = builder.lattice.blockers_boxes(packed, 0, skip)
	while not hit.is_empty():
		var other: int = int(hit[0])
		if _overlapped_at_rest(other):
			skip[other] = true
		elif _slides_over(key, mesh, to, other) or _touching(mesh, to, other):
			skip[other] = true
			forgiven.append(other)
		else:
			break
		hit = builder.lattice.blockers_boxes(packed, 0, skip)
	for other: int in forgiven:
		skip.erase(other)
	return hit


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
	var now: Vector2 = Grab._reach_along(to, mesh.bounds, axis)
	var was: Vector2 = Grab._reach_along(rest[key], mesh.bounds, axis)
	if absf(now.x - was.x) > 0.5 or absf(now.y - was.y) > 0.5:
		return false
	var theirs: Vector2 = Grab._reach_along(them.transform, their_mesh.bounds, axis)
	var end_on: float = Joints.STUD_REACH + 0.5
	return theirs.y - was.x <= end_on or was.y - theirs.x <= end_on


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
	var a_corners: Array[Vector3] = []
	var b_corners: Array[Vector3] = []
	for corner: int in 8:
		a_corners.append(a_at * a_box.get_endpoint(corner))
		b_corners.append(b_at * b_box.get_endpoint(corner))
	var lines: Array[Vector3] = []
	for k: int in 3:
		lines.append(a_at.basis[k].normalized())
		lines.append(b_at.basis[k].normalized())
	for i: int in 3:
		for j: int in 3:
			var across: Vector3 = a_at.basis[i].normalized().cross(b_at.basis[j].normalized())
			if across.length() > 0.001:
				lines.append(across.normalized())
	var least: float = INF
	for way: Vector3 in lines:
		var a_lo: float = INF
		var a_hi: float = -INF
		var b_lo: float = INF
		var b_hi: float = -INF
		for p: Vector3 in a_corners:
			a_lo = minf(a_lo, p.dot(way))
			a_hi = maxf(a_hi, p.dot(way))
		for p: Vector3 in b_corners:
			b_lo = minf(b_lo, p.dot(way))
			b_hi = maxf(b_hi, p.dot(way))
		least = minf(least, minf(a_hi, b_hi) - maxf(a_lo, b_lo))
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


## Whether [param other] overlapped any part of the moving side where they
## stood when it was grabbed: the same answer, asked when first met, as
## asking every moving part at the press, so a turn tested later finds what
## one tested earlier found.
func _overlapped_at_rest(other: int) -> bool:
	if _rest_overlap.has(other):
		return _rest_overlap[other]
	var touching: bool = false
	var boxes: PackedInt32Array = builder.lattice.boxes_of(other)
	if not boxes.is_empty():
		for key: int in builder.lattice.blockers_boxes(boxes, other, {}):
			if moving.has(key) or followers.has(key):
				touching = true
				break
	_rest_overlap[other] = touching
	return touching


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
		if not _near_anything(sweep):
			_on_the_line[key] = true


## Whether the part [param mesh] at [param to] (its world box [param box])
## may meet any part near it but what it may press on: their boxes, each
## turned as it stands, into each other by more than [constant TOUCHING].
## Boxes hold the shapes, so boxes apart are shapes apart, and the turned
## cover need not be worked out.
func _boxes_meet(key: int, mesh: Lbm.PartMesh, to: Transform3D, box: AABB) -> bool:
	var cell: float = BrickLattice.CELL
	var bound := PackedInt32Array([floori(box.position.x / cell), floori(box.position.y / cell),
		floori(box.position.z / cell), ceili(box.end.x / cell), ceili(box.end.y / cell),
		ceili(box.end.z / cell)])
	for other: int in builder.lattice.near_bounds(bound):
		if skip.has(other):
			continue
		var them: BrickWorld.Brick = world.get_brick(other)
		var their_mesh: Lbm.PartMesh = library.mesh_for(them.part_id) if them != null else null
		if their_mesh == null:
			return true
		if Grab.box_depth(to, mesh.bounds, them.transform, their_mesh.bounds) <= TOUCHING \
				or _slides_over(key, mesh, to, other):
			continue
		# Into its box: then against its cover, box by box, which hugs it.
		var cover: PackedInt32Array = builder.lattice.boxes_of(other)
		var cell_size: float = BrickLattice.CELL
		# A piece whose box the part's own box, square to the grid, is not
		# into by more than TOUCHING along some axis is not into the part's
		# turned box either: the three axes are three of box_depth's fifteen
		# lines, and along them the part's turned box reaches as far as its
		# box does. Asked first: a neighbour of hundreds of boxes cost 42081-1's
		# drag 9 ms a frame by the fifteen lines alone.
		var lo: Vector3 = box.position / cell_size + Vector3.ONE * ((TOUCHING - 0.01) / cell_size)
		var hi: Vector3 = box.end / cell_size - Vector3.ONE * ((TOUCHING - 0.01) / cell_size)
		for at: int in range(0, cover.size(), 6):
			if float(cover[at + 3]) <= lo.x or float(cover[at]) >= hi.x or float(cover[at + 4]) <= lo.y \
					or float(cover[at + 1]) >= hi.y or float(cover[at + 5]) <= lo.z or float(cover[at + 2]) >= hi.z:
				continue
			var piece := AABB(Vector3(cover[at], cover[at + 1], cover[at + 2]) * cell_size,
				Vector3(cover[at + 3] - cover[at], cover[at + 4] - cover[at + 1],
					cover[at + 5] - cover[at + 2]) * cell_size)
			if Grab.box_depth(to, mesh.bounds, Transform3D.IDENTITY, piece) > TOUCHING:
				_near_part = other
				return true
	return false


var _near_part: int = 0


## Whether anything but what the moving side may press on has its bounds
## within [param box].
func _near_anything(box: AABB) -> bool:
	var cell: float = BrickLattice.CELL
	var bound := PackedInt32Array([floori(box.position.x / cell), floori(box.position.y / cell),
		floori(box.position.z / cell), ceili(box.end.x / cell), ceili(box.end.y / cell),
		ceili(box.end.z / cell)])
	for other: int in builder.lattice.near_bounds(bound):
		if not skip.has(other):
			return true
	return false


## Turn to [param degrees] from where it was grabbed, as far as it has room
## for from where it is: a click hinge on its clicks. Returns the angle.
func turn_to(degrees: float) -> float:
	if state != "moves" or mode != "turn":
		return angle
	frame_solve_ms = 0.0
	frame_test_ms = 0.0
	frame_tests = 0
	var wanted: float = degrees
	if link.detent > 0.0:
		wanted = roundf(wanted / link.detent) * link.detent
	if is_equal_approx(wanted, angle):
		return angle
	# Past the wall it met last, the same way: still there, and not asked
	# again, so a pointer pressed on past a stop costs nothing a frame.
	if not is_nan(_wall) and (wanted - _wall) * (_wall - angle) >= 0.0 \
			and absf(_wall - angle) < absf(wanted - angle) + 0.001:
		stopped = true
		return angle
	_wall = NAN
	loop_short = false
	if linkage != null:
		# On a quarter-degree grid: a part's turned cover is kept per turn
		# (Builder.boxes_for), so a drag back over the same ground finds them.
		wanted = snappedf(wanted, LOOP_GRID)
	if linkage != null and not linkage.is_slide():
		# As far as the loop closes towards it.
		var reached: float = rad_to_deg(linkage.reach(deg_to_rad(wanted)))
		if absf(reached - wanted) > 0.01:
			loop_short = true
			wanted = reached
	var at: Dictionary = transforms_at(wanted)
	var room: int = _test(at, 0, budget_ms).x
	if room != 0:
		# Room, or not all asked this frame: a big section is shown where the
		# pointer says and checked when it pauses or is let go
		# ([method verify_step]), rather than hold the frame.
		_shown_on_trust(room == 1, wanted)
		angle = wanted
		placed = at
		_keep_loop()
		stopped = loop_short
		return angle
	if budget_ms < INF:
		# Met something, on a section too big to bisect in a frame: it stays
		# where it last had room and the stop is found a round a frame
		# (verify_step), on a pause or at the release.
		_met_on_trust(wanted, angle)
		return angle
	var low: float = angle
	var high: float = wanted
	# As many halvings as bring the step under STOP_TO: a frame's step is a
	# few degrees, and each round tests every part that may hit something.
	var rounds: int = clampi(ceili(log(maxf(absf(wanted - angle), STOP_TO) / STOP_TO) / log(2.0)),
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
func _shown_on_trust(checked: bool, value: float) -> void:
	if checked:
		_checked_angle = value
		unchecked = false
	else:
		unchecked = true
	_verifying_hi = null
	_verify_from = 0


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
## tested where it stands, a [member budget_ms] at a time; if something is in
## the way, bisected back towards the last turn checked, a round a frame.
## True once it stands where it has room.
func verify_step() -> bool:
	if not unchecked or mode == "ball":
		unchecked = false
		return true
	var now: float = angle if mode == "turn" else shift
	if _verifying_hi == null:
		var r: Vector2i = _test(_pose_at(now), _verify_from, budget_ms)
		if r.x == -1:
			_verify_from = r.y
			return false
		_verify_from = 0
		if r.x == 1:
			unchecked = false
			_checked_angle = now
			return true
		_verifying_hi = now
		_verifying_lo = _checked_angle
	var hi: float = float(_verifying_hi)
	# A slide is found to a tenth of an LDU, a turn to STOP_TO degrees.
	if absf(hi - _verifying_lo) < (STOP_TO if mode == "turn" else 0.1):
		_set_value(_verifying_lo)
		placed = _pose_at(_verifying_lo)
		_keep_loop()
		_wall = hi
		_verifying_hi = null
		unchecked = false
		stopped = true
		_checked_angle = _verifying_lo
		return true
	var middle: float = (_verifying_lo + hi) * 0.5
	var r2: Vector2i = _test(_pose_at(middle), _verify_from, budget_ms)
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


## Where everything stands with the joint at [param value]: degrees for a
## turn, LDU for a slide.
func _pose_at(value: float) -> Dictionary:
	return transforms_at(value) if mode == "turn" else transforms_at(angle, value)


func _set_value(value: float) -> void:
	if mode == "turn":
		angle = value
	else:
		shift = value


## Slide [param along] LDU from where it was grabbed, along the shaft as far
## as it reaches and there is room.
func slide_to(along: float) -> float:
	if state != "moves" or mode != "slide":
		return shift
	frame_solve_ms = 0.0
	frame_test_ms = 0.0
	frame_tests = 0
	var wanted: float = clampf(along, _range.x, _range.y)
	if budget_ms < INF and not is_nan(_wall) and (wanted - _wall) * (_wall - shift) >= 0.0 \
			and absf(_wall - shift) < absf(wanted - shift) + 0.001:
		# Past the stop it met last, the same way, as turn_to has it: 42081-1's
		# arm drawn on past its stop was tested again each frame. A loop got as
		# far as that stop, so it gets there again before anything further.
		stopped = true
		return shift
	_wall = NAN
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
	var at: Dictionary = transforms_at(angle, wanted)
	if budget_ms < INF:
		# A big section, as turn_to has it: tested within a frame's share,
		# shown where the pointer says when there is not time to finish, and
		# checked on a pause or at the release (verify_step). 42081-1's boom,
		# 262 parts on its actuator, was bisected by whole tests at its stop:
		# 164 of them, 31 s in one frame.
		var room: int = _test(at, 0, budget_ms).x
		if room != 0:
			_shown_on_trust(room == 1, wanted)
			shift = wanted
			placed = at
			_keep_loop()
			return shift
		_met_on_trust(wanted, shift)
		return shift
	if has_room(at):
		shift = wanted
		placed = at
		_keep_loop()
		return shift
	var low: float = shift
	var high: float = wanted
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
	if has_room(transforms_at(0.0, 0.0, Basis(to))):
		twist = Basis(to)
		placed = transforms_at(0.0, 0.0, twist)
		stopped = false
		return twist
	var low: float = 0.0
	var high: float = 1.0
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


## The loop's pose as it now stands is where its next move starts.
func _keep_loop() -> void:
	if linkage != null:
		linkage.keep()


## Slide it along its joint's line rather than turn it: a drag along the
## line, or move_part's along=.
func use_slide() -> void:
	mode = "slide"
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
		if not _near_anything(box) or not _boxes_meet(int(key), mesh, to, box):
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
	for one: int in moving_bodies:
		for joined: Bodies.Link in bodies.touching.get(one, []):
			if _ours.has(joined.other(one)):
				continue
			for pair: Array in joined.pairs:
				for key: int in pair:
					skip[key] = true
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
		world.move_brick(key, to)
		builder.lattice.release(key)
		# Worked out ahead, a share a frame, for a big section (GrabDrag).
		# Not a hose's: its cells were worked out where a drag drew it.
		var boxes: Variant = cells.get(key) if not hose_keys.has(key) else null
		builder.lattice.occupy_boxes(key, boxes if boxes != null
			else builder.boxes_for(library.mesh_for(brick.part_id), to))
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


## The step's words: "turned the boom, 38 parts, on its turntable to 45°".
func step_words() -> String:
	var verb: String = {"slide": "slid", "ball": "turned"}.get(mode, "turned")
	return "%s %s %s %s" % [verb, _named(), link.words(),
		"to " + position_words() if mode == "turn" else position_words()]
