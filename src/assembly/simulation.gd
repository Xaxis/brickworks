## A model's mechanism, read for Tools, Simulate mechanism and for a session's
## simulate_mechanism: what turns from a driver, how fast, which of it goes
## round once in how many turns of what, and the frames of its cycle for the
## balance. Phase P1b of docs/MECHANISMS.md, with P1c's period readout.
##
## A thin layer over [Mechanism], which reads the bodies, joints and gears
## off the parts and solves them. This names what it found the way a person
## and a session know it: a body by the sub-assembly its parts are in
## ("Earth", "Mars arm"), else by its gear and part numbers ("the 24 tooth
## gear #7"). Pure, as Mechanism is: it reads the bricks it is given and
## changes none of them. The panel poses a copy of what it says
## (BrickWorld.set_drawn), and the renderer a copy of its own.
##
## What turns is read against the base: the baseplate, when there is one,
## and everything standing on its studs (in a socket or not: a turntable's
## base resting on a plate is held with it), else the largest rigid part.
## Periods are counted in that frame, the sidereal one: a planet's arm goes
## round once against the base in that many turns of the reference.
##
## Where the motion stops ([method begin_stops], docs/MECHANISMS.md section
## 39): the first turn of the driver where a moving part meets another, by
## their exact shapes, over the whole cycle; how far the driver goes either
## way (its range), as far as what meets and its loop's closing let it; and
## where a motor that turns it stalls, its torque against the weight it
## lifts through the train.
class_name Simulation
extends RefCounted

## Sidereal orbital periods, days: NASA's planetary fact sheets
## (nssdc.gsfc.nasa.gov/planetary/factsheet), and the Moon's sidereal month.
## A body named after one is compared with its real period, when the
## reference is named after one too ("Mars: 1.96 Earth years; real 1.8808").
const PERIODS := {"mercury": 87.969, "venus": 224.701, "earth": 365.256, "moon": 27.3217,
	"mars": 686.980, "jupiter": 4332.589, "saturn": 10759.22, "uranus": 30685.4,
	"neptune": 60189.0, "pluto": 90560.0}

## A sub-assembly named with one of these is the driver unless another is
## picked: what the model marks as what a hand or a motor turns.
const MARKS := ["crank", "driver", "drive", "motor", "handle"]
## A sub-assembly named with one of these words is held still with the
## base: a frame held to the rest by what the parts do not record (friction,
## a part the reader misses), named so by a person or a session.
const BASES := ["base", "frame", "stand", "chassis"]

## The motors a model is driven from, by part: what it is called, its torque
## stalled (N·cm) and its speed with no load (rpm), at 9 V, as Philippe
## Hurbain measured them (philohome.com/motors/motorcomp.htm; stalled torque
## there is "VERY imprecise", read off the most weight each lifted). A
## motor's output is the axle hole in its face, which turns in its case:
## read so here, it turns the axle in it.
const MOTORS := {
	"58120c01": ["Power Functions M motor", 11.0, 405.0],
	"58120": ["Power Functions M motor", 11.0, 405.0],
	"99499c01": ["Power Functions L motor", 18.0, 390.0],
	"99499": ["Power Functions L motor", 18.0, 390.0],
	"58121c01": ["Power Functions XL motor", 40.0, 220.0],
	"58121": ["Power Functions XL motor", 40.0, 220.0],
	"87577": ["Power Functions E-motor", 3.4, 780.0],
	"47154c01": ["9 V geared motor", 6.0, 460.0],
	"71427": ["9 V mini-motor", 6.0, 360.0],
}

## A body turns when its rate is more than this, in turns of the driver's.
const STILL := 1e-6
## A cycle is at most this many turns of the driver.
const MOST_TURNS := 10000.0

var model: Mechanism
var library: PartLibrary
## Body -> its name, said the way the person and a session know it.
var names: Dictionary = {}
## Body -> its parts' brick ids.
var keys_of: Dictionary = {}
## "the baseplate and what stands on it" or "the largest rigid part".
var base_said: String = ""
## The body that drives, -1 for none.
var driver: int = -1
## What Mechanism.solve said for it.
var solved: Dictionary = {}
## Body -> turns against the base for one turn of the driver, about its own
## line read one way for every body ([method axis_of]): the same sign as the
## driver's turns the same way round, on a parallel line.
var rates: Dictionary = {}
## The bodies that turn, fastest first, the ground and the driver left out.
var turning: Array = []
## Brick ids of the parts that move: every part not on the ground.
var moving: Array = []
## The driver taken hold of as a drag takes it (docs/MECHANISMS.md, section
## 27), its gears turned by this reading (its ground the base): set where
## the driver closes a loop that moves what this reading has no equation
## for, a pinion's rack, a crank's rod and slider, or where this reading
## locks and the loop does not. Every pose and rate is then Grab's. Null
## for a gear train, which a drag turns by this reading's rates, and for a
## driver a drag does not turn on its own line: the gear reading's poses
## are drawn.
var grab: Grab = null
## Why Grab's model is not drawn, "" when it is or nothing was asked.
var grab_note: String = ""
## What Grab reads it in ([method hold_with]): null for a read of bricks alone.
var world: BrickWorld = null
var builder: Builder = null
var bodies: Bodies = null
## The baseplate's ids, as the reading was given them.
var scenery_ids: Dictionary = {}
## Body -> how a loop moves it that is not a steady turn, for one turn of the
## driver: {"slide": LDU on along its line, "stroke": LDU back and forth,
## "rock": degrees either way}.
var travels: Dictionary = {}
## Grab's degrees for a turn of the driver here: its line may run the other way.
var _grab_sign: float = 1.0
## Each motor's brick id -> its part, and each body a motor turns -> the
## motor's brick id.
var motors: Dictionary = {}
var motored: Dictionary = {}


## Read the mechanism in [param bricks] (BrickWorld.Brick), the parts in
## [param scenery] (id -> true: the baseplate) holding everything on their
## studs still. Names come from each brick's sub-assembly.
static func read(bricks: Array, from: PartLibrary, scenery: Dictionary = {}) -> Simulation:
	var out := Simulation.new()
	out.library = from
	out.scenery_ids = scenery
	var list: Array = []
	var held: Array = []
	var named_base: bool = false
	var labels: Dictionary = {}   ## brick id -> its sub-assembly's name
	var framed: Dictionary = {}   ## brick id -> true: in a sub-assembly named as the frame
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var mesh: Lbm.PartMesh = from.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var path: String = Assemblies.path_of(brick)
		var label: String = Assemblies.label(path) if not path.is_empty() else ""
		labels[brick.id] = label
		if MOTORS.has(brick.part_id):
			out.motors[brick.id] = brick.part_id
			mesh = Simulation.turning_output(mesh)
		list.append({"key": brick.id, "part": brick.part_id, "at": brick.transform, "mesh": mesh})
		if scenery.has(brick.id):
			held.append(brick.id)
		elif Simulation.names_a_base(label):
			named_base = true
			framed[brick.id] = true
	if framed.is_empty():
		out.model = Mechanism.build(list, held)
	else:
		out.model = Mechanism.build(list, Simulation._frame_held(list, held, framed, from))
	if held.is_empty():
		out.base_said = "the largest rigid part"
	else:
		out.base_said = "the baseplate and what stands on its studs" if not scenery.is_empty() \
			else "what is held on it"
		if named_base:
			out.base_said += ", with the sub-assemblies named as its frame"
	out._name_bodies(labels)
	out._find_motors()
	return out


## [param mesh] with a motor's output, the axle hole in its face, read as a
## round hole: the axle in it turns against the case, as it does in the real
## motor, where read as it is drawn it is keyed to the case and stands still.
static func turning_output(mesh: Lbm.PartMesh) -> Lbm.PartMesh:
	var out := Lbm.PartMesh.new()
	out.bounds = mesh.bounds
	out.boxes = mesh.boxes
	out.sockets = mesh.sockets
	out.cell_ldu = mesh.cell_ldu
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "axle_hole":
			out.connectors.append(connector)
			continue
		var round := Lbm.Connector.new()
		round.kind = "pin_hole"
		round.gender = connector.gender
		round.position = connector.position
		round.axis = connector.axis
		round.length = connector.length
		round.radius = connector.radius
		out.connectors.append(round)
	return out


## The bodies the motors turn: each whose joint with a motor's case runs
## through the motor's output.
func _find_motors() -> void:
	motored.clear()
	for key: int in motors:
		var piece: Mechanism.Piece = model.parts.get(key)
		var drawn: Lbm.PartMesh = library.mesh_for(str(motors[key])) if library != null else null
		if piece == null or drawn == null:
			continue
		var case: int = model.body_of(key)
		for connector: Lbm.Connector in drawn.connectors:
			if connector.kind != "axle_hole":
				continue
			var point: Vector3 = piece.at * connector.position
			var way: Vector3 = (piece.at.basis * connector.axis).normalized()
			for joint: Mechanism.Joint in model.joints:
				if (joint.a == case or joint.b == case) \
						and Mechanism._same_line(joint.point, joint.way.normalized(), point, way):
					motored[joint.b if joint.a == case else joint.a] = key


## What a frame named so holds still, with [param held] (the baseplate's):
## each body of [param framed] parts as the parts join them, but a body held
## to the frame only by a pin or an axle the frame lists, which turns in it
## with what is on it. The telescope's Stand lists the friction pin its
## tilt chain's idler is read fixed to (docs/MECHANISMS.md, section 27):
## held whole, the frame held the idler, and the chain read locked.
static func _frame_held(list: Array, held: Array, framed: Dictionary, from: PartLibrary) -> Array:
	var loose: Mechanism = Mechanism.build(list, held)
	var out: Array = held.duplicate()
	for body: int in loose.bodies:
		var keys: Array = loose.bodies[body]
		var holds: bool = false
		var all_framed: bool = true
		for key: int in keys:
			if not framed.has(key):
				if not held.has(key):
					all_framed = false
				continue
			var info: PartLibrary.PartInfo = from.parts.get((loose.parts[key] as Mechanism.Piece).part)
			var name: String = info.name if info != null else ""
			if not (name.begins_with("Technic Pin") or name.begins_with("Technic Axle")):
				holds = true
		if holds or all_framed:
			out.append_array(keys)
	return out


# -- names ----------------------------------------------------------------------


func _name_bodies(labels: Dictionary) -> void:
	names.clear()
	keys_of.clear()
	var taken: Dictionary = {}   ## name -> the bodies called it
	for body: int in model.bodies:
		var keys: Array = model.bodies[body]
		keys_of[body] = keys
		if body == model.ground:
			names[body] = "the base"
			continue
		var counted: Dictionary = {}
		for key: int in keys:
			var label: String = str(labels.get(key, ""))
			if not label.is_empty():
				counted[label] = int(counted.get(label, 0)) + 1
		var best: String = ""
		for label: String in counted:
			if best.is_empty() or int(counted[label]) > int(counted[best]):
				best = label
		var name: String = best if not best.is_empty() else _parts_name(body)
		if not taken.has(name):
			taken[name] = []
		(taken[name] as Array).append(body)
		names[body] = name
	# One name, several bodies: the one with most parts keeps it, the rest
	# are told apart by their first part's number.
	for name: String in taken:
		var those: Array = taken[name]
		if those.size() < 2:
			continue
		those.sort_custom(func(a: int, b: int) -> bool:
			return (keys_of[a] as Array).size() > (keys_of[b] as Array).size())
		for n: int in range(1, those.size()):
			names[those[n]] = "%s (#%d)" % [name, _first_key(those[n])]


func _first_key(body: int) -> int:
	var least: int = 0
	for key: int in keys_of.get(body, []):
		if least == 0 or key < least:
			least = key
	return least


## A body named by what is in it: its gear, else its first parts.
func _parts_name(body: int) -> String:
	var gear: Mechanism.Gear = null
	for one: Mechanism.Gear in model.gears:
		if one.body == body and (gear == null or one.teeth > gear.teeth):
			gear = one
	if gear != null:
		var kind: String = "worm" if gear.kind == "worm" else ("%d tooth %s" % [gear.teeth,
			"ring" if gear.kind == "ring" else "gear"])
		return "the %s #%d" % [kind, gear.key]
	var keys: Array = (keys_of.get(body, []) as Array).duplicate()
	keys.sort()
	var said := PackedStringArray()
	for key: int in keys.slice(0, 2):
		said.append("#%d %s" % [key, (model.parts[key] as Mechanism.Piece).part])
	if keys.size() > 2:
		said.append("%d more" % (keys.size() - 2))
	return ", ".join(said)


## A body's name with its parts by number, for a session: "Earth (#12 3707,
## #13 32269, and 4 more)".
func named_with_parts(body: int, most: int = 3) -> String:
	var name: String = str(names.get(body, "?"))
	var keys: Array = (keys_of.get(body, []) as Array).duplicate()
	keys.sort()
	# Named by its parts already.
	if name.begins_with("#") and keys.size() <= 2:
		return name
	var said := PackedStringArray()
	for key: int in keys.slice(0, most):
		said.append("#%d %s" % [key, (model.parts[key] as Mechanism.Piece).part])
	if keys.size() > most:
		said.append("and %d more" % (keys.size() - most))
	return "%s (%s)" % [name, ", ".join(said)]


## The body a session or the person names: a part's number (any part of
## it), a sub-assembly's name, or a body's name as said here. -1 for none.
func body_named(asked: String) -> int:
	var text: String = asked.strip_edges().trim_prefix("#")
	if text.is_valid_int():
		var key: int = int(text)
		if model.parts.has(key):
			return model.body_of(key)
		return -1
	var lower: String = asked.strip_edges().to_lower()
	for body: int in names:
		if str(names[body]).to_lower() == lower:
			return body
	for body: int in names:
		if str(names[body]).to_lower().begins_with(lower):
			return body
	return -1


## Whether a sub-assembly's name says it is the base: a word of [constant
## BASES] in it ("Frame", "Base plate", "Stand"), not part of a longer word.
static func names_a_base(label: String) -> bool:
	for word: String in label.to_lower().replace("-", " ").replace("_", " ").split(" ", false):
		if word in BASES:
			return true
	return false


## The planet a name is of, lower case, or "".
static func planet_in(name: String) -> String:
	var words: PackedStringArray = name.to_lower().replace("'", " ").replace("(", " ").split(" ",
		false)
	for word: String in words:
		if PERIODS.has(word):
			return word
	return ""


# -- driving ------------------------------------------------------------------------


## Whether a body can be driven: it turns on a joint of its own.
func can_drive(body: int) -> bool:
	return body >= 0 and body != model.ground and model.joint_of(body) != null


## The body the model marks as its driver: what a motor's output turns, else
## a sub-assembly named Crank, Motor, Handle, Driver; or -1.
func marked() -> int:
	for body: int in motored:
		if can_drive(body):
			return body
	for body: int in names:
		if not can_drive(body):
			continue
		var lower: String = str(names[body]).to_lower()
		for mark: String in MARKS:
			if lower.contains(mark):
				return body
	return -1


## The body to drive when none is marked or picked: of those with a gear
## that turn on a joint, the one that turns most of the train and leaves
## least undecided; a locked train's first, so that driving it says what
## locks it. -1 when nothing could be driven.
func best() -> int:
	var tried: Dictionary = {}
	var best_body: int = -1
	var best_score: float = -INF
	var best_moved: int = 0
	var locked: int = -1
	for gear: Mechanism.Gear in model.gears:
		var body: int = gear.body
		if tried.has(body) or not can_drive(body):
			continue
		tried[body] = true
		if tried.size() > 24:
			break
		var said: Dictionary = model.solve({body: 1.0})
		if not bool(said["ok"]):
			if locked < 0:
				locked = body
			continue
		var moved: int = 0
		for joint: Mechanism.Joint in model.tree:
			if absf(joint.rate) > STILL:
				moved += 1
		# Most turned, least left free.
		var score: float = float(moved) - 4.0 * float(said["freedoms"])
		if score > best_score:
			best_score = score
			best_body = body
			best_moved = moved
	# A train that locks from one of its gears is said to: a gear turning
	# alone on its axle, meshing nothing, is no driver to hide that behind.
	if locked >= 0 and (best_body < 0 or best_moved <= 1):
		return locked
	return best_body


## Drive [param body] one turn: every rate, what turns, what moves. Returns
## Mechanism.solve's answer.
func drive(body: int) -> Dictionary:
	driver = body
	rates.clear()
	turning.clear()
	moving.clear()
	if not can_drive(body):
		solved = {"ok": false, "locked": false, "said": "that part turns on nothing",
			"culprits": [], "meshes": [], "free": [], "freedoms": 0}
		return solved
	solved = model.solve({body: 1.0})
	var unit: float = model.spin(body, axis_of(body))
	if absf(unit) < 1e-12:
		unit = 1.0
	for one: int in model.bodies:
		if one == model.ground or model.floating.has(one):
			continue
		var rate: float = model.spin(one, axis_of(one)) / unit
		rates[one] = rate
		if one != body and absf(rate) > STILL:
			turning.append(one)
	turning.sort_custom(func(a: int, b: int) -> bool:
		return absf(float(rates[a])) > absf(float(rates[b])))
	for one: int in model.bodies:
		if one != model.ground and not model.floating.has(one) and model.omega(one).length() > STILL:
			moving.append_array(model.bodies[one])
	_take_hold(body)
	return solved


# -- Grab's model --------------------------------------------------------------------


## Read in [param in_world] as a drag reads it, with the joints [param
## joints] (GrabDrag's, read ahead; read here when null): the next [method
## drive] turns the driver as Grab turns it.
func hold_with(in_world: BrickWorld, by: Builder, joints: Bodies = null) -> void:
	world = in_world
	builder = by
	bodies = joints
	if bodies == null and world != null and builder != null:
		bodies = Bodies.read(world, library, builder.lattice, scenery_ids, builder.locked.duplicate())
		bodies.racks()
		bodies.revision = world.revision


## Take hold of [param body] as a drag would: through this gear reading, on
## the driver's own line. Its poses are then Grab's, and where its loop moves
## what this reading cannot (a rack, a slider, a rod), every rate is read off
## those poses.
func _take_hold(body: int) -> void:
	grab = null
	grab_note = ""
	travels.clear()
	if world == null or builder == null or bodies == null:
		return
	var joint: Mechanism.Joint = model.joint_of(body)
	if joint == null:
		return
	var part: int = -1
	for key: int in model.bodies.get(body, []):
		if bodies.body_of.has(key) and world.get_brick(key) != null:
			part = key
			break
	if part < 0:
		grab_note = "no part of it is in the joints a drag reads"
		return
	var held := Grab.new()
	held.world = world
	held.builder = builder
	held.library = library
	held.bodies = bodies
	held.shared_mechanism = model
	held.begin(part, world.get_brick(part).transform.origin)
	if held.state != "moves" or held.mode != "turn":
		grab_note = held.why if not held.why.is_empty() else "a drag %s it" % (
			"slides" if held.mode == "slide" else "cannot turn")
		return
	if not Bodies._same_line(held.pivot, held.axis.normalized(), joint.point, joint.way.normalized()):
		grab_note = "a drag turns it on another line"
		return
	if held.linkage == null:
		# A gear train: a drag turns it by this reading's rates, and this
		# reading's poses are drawn, as they always were.
		grab_note = "a gear train, turned by the gear reading as a drag turns it"
		return
	grab = held
	_grab_sign = 1.0 if held.axis.dot(joint.way) > 0.0 else -1.0
	if not bool(solved.get("locked", false)) and not _loop_moves_more(body):
		grab = null
		grab_note = "the gear reading moves all the loop does"
		return
	moving = (_grab_pose(0.01) as Dictionary).keys()
	_read_loop(body)


## Whether the loop moves a part the gear reading leaves where it stands, or
## stands one where the gear reading moves it, a little way into a turn: a
## rack's tube, a slider, a connecting rod the gear reading spins round.
func _loop_moves_more(body: int) -> bool:
	var step: float = 1.0 / 72.0
	var loop_at: Dictionary = _grab_pose(step)
	var gear_at: Dictionary = model.pose(step * TAU)
	var keys: Dictionary = {}
	for key: Variant in loop_at:
		keys[key] = true
	for key: Variant in gear_at:
		keys[key] = true
	for key: Variant in keys:
		var was: Transform3D = model.rest.get(key, world.get_brick(int(key)).transform \
			if world.get_brick(int(key)) != null else Transform3D.IDENTITY)
		var one: Transform3D = loop_at.get(key, was)
		var other: Transform3D = gear_at.get(key, was)
		var turned: Basis = one.basis.orthonormalized() * other.basis.orthonormalized().inverse()
		if one.origin.distance_to(other.origin) > 0.05 or turned.get_rotation_quaternion().get_angle() > 0.002:
			return true
	return false


## Where everything a drag on the driver moves stands with it [param turns]
## turns from where it was built: brick id -> Transform3D.
func _grab_pose(turns: float) -> Dictionary:
	var degrees: float = turns * 360.0 * _grab_sign
	if grab.linkage != null:
		_walk_loop(deg_to_rad(degrees))
	return grab.transforms_at(degrees)


## A loop is solved from the pose last kept, in steps: kept on the way to
## [param value] (radians), a step at most [constant LOOP_LEG], so a scrub
## across the cycle follows the loop round as a drag does.
func _walk_loop(value: float) -> void:
	var loop: Linkage = grab.linkage
	for _n: int in 4096:
		var from: float = loop.kept_value()
		if absf(value - from) <= LOOP_LEG:
			return
		var next: float = from + signf(value - from) * LOOP_LEG
		var got: float = loop.reach(next)
		if absf(got - from) < 1e-6:
			return
		loop.keep()


const LOOP_LEG := 0.5


## Every rate read off Grab's poses over a turn of the driver: a body that
## turns steadily turns as many times as it goes round in one; one that goes
## back and forth (a rod's rock, a slider's stroke) or slides on (a rack) is
## said in [member travels]. A loop moves what the gear reading reads locked,
## or not at all.
func _read_loop(body: int) -> void:
	var frames: int = 72
	var last: Dictionary = {}     ## body -> its turn, unwrapped, radians
	var turned: Dictionary = {}   ## body -> [least, most] turn
	var along: Dictionary = {}    ## body -> [least, most, last] LDU on its line
	var reached: float = 0.0
	var start: Array = grab.linkage.kept_state()
	for n: int in frames + 1:
		var turns: float = float(n) / float(frames)
		var at: Dictionary = _grab_pose(turns)
		var got: float = absf(grab.linkage.reach(deg_to_rad(turns * 360.0 * _grab_sign)))
		if n > 0 and got < absf(deg_to_rad(turns * 360.0)) - 1e-4:
			# The loop stops there: a rack at the end of its rod.
			break
		reached = turns
		for one: int in model.bodies:
			if one == model.ground or model.floating.has(one):
				continue
			var key: int = model.bodies[one][0]
			if not at.has(key):
				continue
			var line: Vector3 = axis_of(one)
			var move: Transform3D = (at[key] as Transform3D) * (model.rest[key] as Transform3D).affine_inverse()
			var q := Quaternion(move.basis.orthonormalized())
			var twist: float = 2.0 * atan2(Vector3(q.x, q.y, q.z).dot(line), q.w)
			var was: float = float(last.get(one, 0.0))
			var now: float = was + wrapf(twist - wrapf(was, -PI, PI), -PI, PI)
			last[one] = now
			var span: Array = turned.get(one, [0.0, 0.0])
			turned[one] = [minf(span[0], now), maxf(span[1], now)]
			var centre: Vector3 = (model.rest[key] as Transform3D).origin
			var slid: float = ((at[key] as Transform3D).origin - centre).dot(model.joint_axis(one).normalized()) \
				if model.joint_of(one) != null else 0.0
			var reach_span: Array = along.get(one, [0.0, 0.0, 0.0])
			along[one] = [minf(reach_span[0], slid), maxf(reach_span[1], slid), slid]
	grab.linkage.restore_kept(start)
	rates.clear()
	turning.clear()
	var unit: float = maxf(reached, 1.0 / float(frames))
	var rate_of_driver: float = float(last.get(body, TAU * unit)) / (TAU * unit)
	if absf(rate_of_driver) < STILL:
		rate_of_driver = 1.0
	for one: int in last:
		var net: float = float(last[one]) / (TAU * unit) / rate_of_driver
		var span: Array = turned[one]
		var swing: float = rad_to_deg(float(span[1]) - float(span[0]))
		var steady: float = 360.0 * unit * absf(net)
		rates[one] = net
		if one != body and steady > 1.0 and swing < steady * 1.02 + 1.0:
			# Round and on, never back: a gear the loop turns.
			turning.append(one)
		elif one != body and swing > 1.0:
			travels[one] = {"rock": swing / 2.0}
			rates[one] = 0.0
		elif one != body:
			rates[one] = 0.0
		var slide: Array = along.get(one, [0.0, 0.0, 0.0])
		var stroke: float = float(slide[1]) - float(slide[0])
		if one != body and stroke > 0.5:
			var said: Dictionary = travels.get(one, {})
			if absf(absf(float(slide[2])) - stroke) < 0.01 * stroke + 0.05:
				said["slide"] = float(slide[2]) / unit
			else:
				said["stroke"] = stroke
			travels[one] = said
	turning.sort_custom(func(a: int, b: int) -> bool:
		return absf(float(rates[a])) > absf(float(rates[b])))
	# Decided now: the loop says how each of them goes.
	var free: Array = (solved.get("free", []) as Array).filter(func(one: int) -> bool:
		return not travels.has(one) and not turning.has(one))
	solved["free"] = free
	if bool(solved.get("locked", false)) or not bool(solved.get("ok", true)):
		solved["ok"] = true
		solved["locked"] = false
		solved["meshes"] = []
		solved["culprits"] = []
	solved["said"] = "moved as a drag moves it: %s" % grab.linkage.said()


## A body's line, read one way for every body: pointing up, else right,
## else towards the front, so that two on parallel lines read alike.
func axis_of(body: int) -> Vector3:
	var way: Vector3 = model.joint_axis(body).normalized()
	for n: int in [1, 0, 2]:
		if absf(way[n]) > 1e-4:
			return way if way[n] > 0.0 else -way
	return way


## Whether two bodies turn on parallel lines, so one's turns can be counted
## in the other's.
func parallel(a: int, b: int) -> bool:
	return absf(axis_of(a).dot(axis_of(b))) > 0.99


## How many turns of [param reference] one turn of [param body] takes,
## both against the base: its period in the reference's turns, negative
## when it goes round the other way. NAN when they turn on lines that are
## not parallel, or either stands still.
func period_in(body: int, reference: int) -> float:
	if not rates.has(body) or not rates.has(reference) or not parallel(body, reference):
		return NAN
	var mine: float = float(rates[body]) * (1.0 if axis_of(body).dot(axis_of(reference)) > 0.0 else -1.0)
	var theirs: float = float(rates[reference])
	if absf(mine) < STILL or absf(theirs) < STILL:
		return NAN
	return theirs / mine


## The real period of [param body] in [param reference]'s, when both are
## named after planets: Mars in Earth years 1.8808. NAN otherwise.
func real_period(body: int, reference: int) -> float:
	var planet: String = planet_in(str(names.get(body, "")))
	var unit: String = planet_in(str(names.get(reference, "")))
	if planet.is_empty() or unit.is_empty() or planet == unit:
		return NAN
	return float(PERIODS[planet]) / float(PERIODS[unit])


## What a reference's turns are called: "Earth years", "turns of Mars's arm".
func unit_of(reference: int) -> String:
	var name: String = str(names.get(reference, ""))
	var planet: String = planet_in(name)
	if planet == "moon":
		return "months of the Moon"
	if not planet.is_empty():
		return "%s years" % planet.capitalize()
	return "turns of %s" % name


## Driver turns for every body that turns to go round at least once:
## a turn of the slowest, at least one of the driver's.
func cycle() -> float:
	var slowest: float = INF
	for body: int in turning:
		slowest = minf(slowest, absf(float(rates[body])))
	if slowest == INF:
		return 1.0
	return clampf(1.0 / slowest, 1.0, MOST_TURNS)


## Driver turns for one turn of [param reference] (or of the driver, -1).
func turns_for(reference: int) -> float:
	if reference < 0 or not rates.has(reference) or absf(float(rates[reference])) < STILL:
		return 1.0
	return clampf(1.0 / absf(float(rates[reference])), 1.0 / 64.0, MOST_TURNS)


# -- where everything stands ------------------------------------------------------


## Where every part that moves stands with the driver turned [param turns]
## turns: brick id -> Transform3D.
func placed(turns: float) -> Dictionary:
	if grab != null:
		return _grab_pose(turns)
	var all: Dictionary = model.pose(turns * TAU)
	var out: Dictionary = {}
	for key: int in moving:
		out[key] = all[key]
	return out


## The frames of [param turns] of the driver, [param frames] of them, as
## Balance.measure takes poses: {label, turns, transforms}.
func poses(turns: float, frames: int) -> Array:
	var out: Array = []
	var driver_name: String = str(names.get(driver, "the driver"))
	for n: int in maxi(frames, 1):
		var t: float = turns * float(n) / float(maxi(frames, 1))
		out.append({"label": "%s %s" % [driver_name, Simulation.turned(t)], "turns": t,
			"transforms": placed(t)})
	return out


## A driver's turn as said: "at 270°", "2.75 turns in".
static func turned(turns: float) -> String:
	if turns < 1.0 - 1e-6:
		return "at %d°" % roundi(turns * 360.0)
	return "%s turns in" % Simulation.figure(turns)


## A number as a person reads it: four figures, no trailing zeros.
static func figure(value: float) -> String:
	if absf(value) >= 1000.0:
		return "%d" % roundi(value)
	var said: String = "%.4f" % value if absf(value) < 10.0 else "%.2f" % value
	if said.contains("."):
		said = said.rstrip("0").rstrip(".")
	return said


## Which turning body reaches furthest past the edge of [param hull] (x and
## z, LDU, as Balance.Report.support) over [param frames]: {body, studs (past
## the edge, positive past it), edge, label}. Empty when nothing turns.
func furthest_out(hull: PackedVector2Array, frames: Array) -> Dictionary:
	if hull.size() < 3 or turning.is_empty():
		return {}
	var best: Dictionary = {}
	for body: int in turning:
		var keys: Array = keys_of.get(body, [])
		if keys.is_empty():
			continue
		# The corners of each of its parts' boxes where they stand, carried
		# round with the body as one.
		var corners := PackedVector3Array()
		for key: int in keys:
			var piece: Mechanism.Piece = model.parts[key]
			if piece.mesh == null:
				continue
			var box: AABB = piece.mesh.bounds
			for n: int in 8:
				corners.append(piece.at * (box.position + box.size * Vector3(n & 1, (n >> 1) & 1,
					(n >> 2) & 1)))
		if corners.is_empty():
			continue
		var one: int = keys[0]
		var rest: Transform3D = model.rest[one]
		for frame: Dictionary in frames:
			var at: Dictionary = frame.get("transforms", {})
			if not at.has(one):
				continue
			var moved: Transform3D = (at[one] as Transform3D) * rest.affine_inverse()
			for corner: Vector3 in corners:
				var there: Vector3 = moved * corner
				var standing: Dictionary = Balance.margin_in(hull, Vector2(there.x, there.z))
				var past: float = -float(standing["margin"]) / BrickLattice.STUD
				if best.is_empty() or past > float(best["studs"]):
					best = {"body": body, "studs": past, "edge": standing["edge"],
						"label": str(frame.get("label", ""))}
	return best


# -- where it stops ----------------------------------------------------------------------


## A moving part is tested where it has gone at most this far since the last
## test, LDU (Grab's PATH_LDU): no part is thin enough to step through. A
## slow part is tested less often than a fast one, and a round one turning
## about its own axis only once it goes somewhere ([method _as_tested]).
const STEP_LDU := 2.0
## Nor a step more than this, turns of the driver, nor less.
const MOST_STEP := 1.0 / 72.0
const LEAST_STEP := 1e-6
## The first turn where two parts meet is found to within this, turns
## (0.01°).
const MEET_TO := 0.01 / 360.0
## How far back the driver is turned for the far end of its range, turns.
const BACK_TURNS := 1.0
## How much of the cycle is checked at most, turns of the driver.
const MOST_CHECKED := 64.0
## A joint's parts are forgiven the pieces its line goes through within this,
## LDU, as Grab forgives them (PAIR_ACROSS_SLACK).
const ON_THE_LINE := 0.25
## A part named so, whose bounds are as wide as deep about one of its axes, is
## round about that axis (Grab's _round_on): turning about it, it sweeps only
## where it is.
const ROUND_WORDS: Array[String] = ["tyre", "tire", "wheel", "gear", "pulley", "rim", "round",
	"bush", "disk", "cone", "axle", "pin"]
## g·LDU per radian to N·cm: grams to kg, g, LDU (0.4 mm) to metres, and N·m
## to N·cm.
const TORQUE_N_CM := 0.001 * Balance.GRAVITY * Balance.MM_PER_LDU * 0.001 * 100.0
## The parts stood still are found near a moving one in cells this big, LDU.
const GRID := 40.0

## Whether [method stops_step] is done.
var stops_done: bool = true
## Forward from where it was built, as Play turns it: the first turn of the
## driver where a moving part meets another, {turns, clear (the last turn
## checked clear), key (the moving part), other, depth (LDU)}; empty when
## nothing meets. [member meets_back] the same, turning back.
var meets: Dictionary = {}
var meets_back: Dictionary = {}
## How far the loop the driver closes lets it go, turns, back and on;
## -INF and INF where it lets it go round.
var loop_reach := Vector2(-INF, INF)
## How far it was checked, turns, back and on.
var checked := Vector2.ZERO
## The motor that turns the driver (its brick id, 0 for none), where it
## stalls {turns, needs (N·cm)}, and where it is asked most {turns, needs}.
var motor: int = 0
var stall: Dictionary = {}
var heaviest: Dictionary = {}
## Parts with no exact shape, which nothing is judged against.
var unshaped: int = 0

var _sweep: Dictionary = {}
var _shapes: Dictionary = {}      ## brick id -> Exact.Shape
var _corners: Dictionary = {}     ## brick id -> its bounds' eight corners
var _body: Dictionary = {}        ## brick id -> its body
var _tested: Dictionary = {}      ## brick id -> [where it was last tested, the turn]
var _round: Dictionary = {}       ## brick id -> [its middle, the axis it is round about]
var _grams: Dictionary = {}       ## brick id -> [grams, the middle of its shape]
var _standing: Array = []         ## Exact.Item of each part that does not move
var _standing_keys := PackedInt64Array()
var _grid: Dictionary = {}        ## Vector3i -> PackedInt32Array of _standing
var _forgiven: Dictionary = {}    ## Vector2i(lower, higher) -> Exact.Forgiven, null or true


## Begin finding where the driver's motion stops: [param span] turns on, as
## Play turns it (the cycle), and a turn back, unless it came round on with
## nothing meeting (going back then passes the same places). [method
## stops_step] goes on with it a little at a time.
func begin_stops(span: float) -> void:
	meets = {}
	meets_back = {}
	stall = {}
	heaviest = {}
	loop_reach = Vector2(-INF, INF)
	checked = Vector2.ZERO
	motor = int(motored.get(driver, 0))
	stops_done = moving.is_empty()
	if stops_done:
		return
	if grab != null and grab.linkage != null and not grab.linkage.is_slide():
		loop_reach = _loop_reach()
	_ready_to_meet()
	_sweep = {"way": 1.0, "to": minf(clampf(span, 1.0, MOST_CHECKED), loop_reach.y)}
	_sweep_from(0.0)


## Go on finding where it stops for at most [param budget_ms]; true once done.
func stops_step(budget_ms: float) -> bool:
	if stops_done:
		return true
	var began: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - began) / 1000.0 < budget_ms:
		if not _sweep_one():
			continue
		if float(_sweep["way"]) > 0.0 and not (meets.is_empty() and _comes_round(checked.y)):
			_sweep = {"way": -1.0, "to": maxf(-BACK_TURNS, loop_reach.x)}
			_sweep_from(0.0)
			continue
		if checked.x == 0.0:
			# Round on with nothing meeting, and back to where it began: going
			# back passes the same places.
			checked.x = -checked.y
		stops_done = true
		# A loop's pose kept where it was built again.
		placed(0.0)
		return true
	return false


## Where the driver stops going on, turns: where something meets, a motor
## stalls or its loop goes no further; INF for nowhere.
func stop_on() -> float:
	var at: float = loop_reach.y
	if not meets.is_empty():
		at = minf(at, float(meets["turns"]))
	if not stall.is_empty():
		at = minf(at, float(stall["turns"]))
	return at


## And going back, turns; -INF for nowhere.
func stop_back() -> float:
	var at: float = loop_reach.x
	if not meets_back.is_empty():
		at = maxf(at, float(meets_back["turns"]))
	return at


## The two parts that meet first going on, or none.
func meeting_pair() -> Array:
	if meets.is_empty():
		return []
	return [int(meets["key"]), int(meets["other"])]


## How far the driver's loop closes either way from where it was built, a
## turn at most: Linkage walked there and asked for the last of the way.
func _loop_reach() -> Vector2:
	var loop: Linkage = grab.linkage
	var start: Array = loop.kept_state()
	var out := Vector2(-INF, INF)
	for way: float in [1.0, -1.0]:
		loop.restore_kept(start)
		var asked: float = way * TAU * _grab_sign
		_walk_loop(asked)
		var got: float = loop.reach(asked)
		if absf(got - asked) > 1e-4:
			out[1 if way > 0.0 else 0] = got / (TAU * _grab_sign)
	loop.restore_kept(start)
	return out


## Each part's shape, reach and weight, and what stands still put in a grid
## to be found near what moves.
func _ready_to_meet() -> void:
	_shapes.clear()
	_corners.clear()
	_body.clear()
	_round.clear()
	_grams.clear()
	_standing.clear()
	_standing_keys = PackedInt64Array()
	_grid.clear()
	_forgiven.clear()
	unshaped = 0
	var moves: Dictionary = {}
	for key: Variant in moving:
		moves[int(key)] = true
	for key: int in model.parts:
		var piece: Mechanism.Piece = model.parts[key]
		var shape: Exact.Shape = Exact.shape_for(library, piece.part)
		if shape == null or not shape.has_pieces():
			unshaped += 1
			shape = null
		else:
			_shapes[key] = shape
		if not moves.has(key):
			if shape != null:
				var item := Exact.Item.new(shape, piece.at)
				for cell: Vector3i in Simulation._cells(item):
					var there: PackedInt32Array = _grid.get(cell, PackedInt32Array())
					there.append(_standing.size())
					_grid[cell] = there
				_standing.append(item)
				_standing_keys.append(key)
			continue
		if piece.mesh != null:
			var box: AABB = piece.mesh.bounds
			var corners := PackedVector3Array()
			for n: int in 8:
				corners.append(box.position + box.size * Vector3(n & 1, (n >> 1) & 1, (n >> 2) & 1))
			_corners[key] = corners
			_body[key] = model.body_of(key)
			var round: int = Simulation._round_axis(library.parts.get(piece.part), box)
			if round >= 0:
				_round[key] = [box.get_center(), Vector3(round == 0, round == 1, round == 2)]
			var info: PartLibrary.PartInfo = library.parts.get(piece.part)
			if info != null:
				_grams[key] = [Stability.grams(info), box.get_center()]


## The axis [param info]'s part is round about (0, 1 or 2 of its own), or -1:
## named as round, and as wide as deep about it to 2 LDU (a gear, a wheel,
## an axle, a pin, a bush, a round brick).
static func _round_axis(info: PartLibrary.PartInfo, box: AABB) -> int:
	if info == null:
		return -1
	var name: String = info.name.to_lower()
	var named: bool = false
	for word: String in ROUND_WORDS:
		if name.contains(word):
			named = true
			break
	if not named:
		return -1
	var best: int = -1
	for k: int in 3:
		var across: float = absf(box.size[(k + 1) % 3] - box.size[(k + 2) % 3])
		if across <= 2.0 and (best < 0 or across < absf(box.size[(best + 1) % 3]
				- box.size[(best + 2) % 3])):
			best = k
	return best


## Where [param key] is tested with the part at [param at]: a part round
## about its own axis, turned about it alone since it was built, sweeps only
## where it is, so it is tested as it was built moved to where its middle has
## gone (Grab's _shape_at). An axle turning in its hole, a gear on its pin,
## then never meet them for being drawn in facets; and are not tested again
## till they go somewhere.
func _as_tested(key: int, at: Transform3D) -> Transform3D:
	var round: Array = _round.get(key, [])
	if round.is_empty() or not model.rest.has(key):
		return at
	var stood: Basis = (model.rest[key] as Transform3D).basis
	var axis: Vector3 = round[1]
	if absf((at.basis * axis).normalized().dot((stood * axis).normalized())) < 1.0 - 1e-6:
		return at
	var middle: Vector3 = round[0]
	return Transform3D(stood, at * middle - stood * middle)


static func _cells(item: Exact.Item) -> Array:
	var out: Array = []
	var lo := Vector3i((item.lo / GRID).floor())
	var hi := Vector3i((item.hi / GRID).floor())
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				out.append(Vector3i(x, y, z))
	return out


func _sweep_from(at: float) -> void:
	var pose: Dictionary = placed(at)
	_sweep["at"] = at
	_sweep["step"] = 1.0 / 360.0
	_sweep["pose"] = pose
	_sweep["weight"] = _weight_up(pose)
	_sweep["needs"] = NAN
	_sweep["needs_at"] = 0.0
	# Where it was built every part is let be.
	_tested.clear()
	for key: Variant in pose:
		_tested[key] = [_as_tested(int(key), pose[key]), at]


## One step of the sweep: on to the next turn where nothing has gone more
## than [constant STEP_LDU], and what meets there. True when this way is done.
func _sweep_one() -> bool:
	var way: float = _sweep["way"]
	var at: float = _sweep["at"]
	var to: float = _sweep["to"]
	if (to - at) * way <= LEAST_STEP:
		return true
	var step: float = _sweep["step"]
	var next: float = at + way * step
	if (to - next) * way < 0.0:
		next = to
	var pose: Dictionary = placed(next)
	var was: Dictionary = _sweep["pose"]
	var travel: float = 0.0
	var moved: Dictionary = {}
	var shown: Dictionary = {}
	for key: Variant in pose:
		shown[key] = _as_tested(int(key), pose[key])
		var gone: float = _moved(int(key), _as_tested(int(key), was.get(key, pose[key])), shown[key])
		moved[key] = gone
		travel = maxf(travel, gone)
	if travel > STEP_LDU and absf(next - at) > LEAST_STEP * 2.0:
		_sweep["step"] = absf(next - at) * 0.5
		return false
	# A part is tested before another step like this one would take it more
	# than STEP_LDU from where it was last tested, and every part at the end.
	var last: bool = (to - next) * way <= LEAST_STEP
	var due: Dictionary = {}
	for key: Variant in pose:
		var tested: Array = _tested.get(key, [shown[key], at])
		if last or _moved(int(key), tested[0], shown[key]) + float(moved[key]) > STEP_LDU:
			due[key] = true
	var hit: Dictionary = {} if due.is_empty() else _meeting(pose, due)
	if not hit.is_empty():
		var found: Dictionary = _first_meeting(_clear_for(hit, at), next, hit)
		if way > 0.0:
			meets = found
			checked.y = float(found["turns"])
		else:
			meets_back = found
			checked.x = float(found["turns"])
		return true
	for key: Variant in due:
		_tested[key] = [shown[key], next]
	if way > 0.0 and motor != 0:
		_weigh_step(at, next, pose)
	_sweep["at"] = next
	_sweep["pose"] = pose
	if way > 0.0:
		checked.y = next
	else:
		checked.x = next
	# The next step as long as takes the part that goes furthest most of
	# STEP_LDU.
	var grow: float = 2.0 if travel <= 0.0 else clampf(STEP_LDU * 0.9 / travel, 0.5, 2.0)
	_sweep["step"] = clampf(absf(next - at) * grow, LEAST_STEP, MOST_STEP)
	return last


## How far any point of a part has gone from [param from] to [param to],
## LDU: a corner of its bounds' furthest (a turn and a slide move each point
## by an affine sum of where it is, which is greatest at a corner).
func _moved(key: int, from: Transform3D, to: Transform3D) -> float:
	var most: float = 0.0
	for corner: Vector3 in _corners.get(key, PackedVector3Array()):
		most = maxf(most, (from * corner).distance_to(to * corner))
	return most


## The last turn where the parts that met were tested clear: the first
## meeting is looked for from there.
func _clear_for(hit: Dictionary, at: float) -> float:
	var clear: float = at
	for key: Variant in [hit["key"], hit["other"]]:
		if _tested.has(key):
			var turn: float = float((_tested[key] as Array)[1])
			clear = minf(clear, turn) if float(_sweep["way"]) > 0.0 else maxf(clear, turn)
	return clear


## Whether turning on for [param span] turns brings every moving body back
## where it was built (each turns a whole number of times), so turning back
## passes the same places.
func _comes_round(span: float) -> bool:
	if grab != null or absf(span - roundf(span)) > 1e-6:
		return false
	for body: Variant in rates:
		var times: float = float(rates[body]) * span
		if absf(times - roundf(times)) > 1e-6:
			return false
	return true


## Bisected between [param clear] (nothing meets) and [param met] (something
## does) to [constant MEET_TO]: the first turn where they meet.
func _first_meeting(clear: float, met: float, hit: Dictionary) -> Dictionary:
	var low: float = clear
	var high: float = met
	for _n: int in 40:
		if absf(high - low) <= MEET_TO:
			break
		var middle: float = (low + high) * 0.5
		var there: Dictionary = _meeting(placed(middle))
		if there.is_empty():
			low = middle
		else:
			high = middle
			hit = there
	var out: Dictionary = hit.duplicate()
	out["turns"] = high
	out["clear"] = low
	return out


## The first moving part that meets another at [param pose] (brick id ->
## Transform3D), by their exact shapes: {key, other, depth}, or empty. Only
## the parts in [param due] (with what they reach) when it is given.
func _meeting(pose: Dictionary, due: Dictionary = {}) -> Dictionary:
	var items: Array = []
	var keys: Array = []
	var turned: Dictionary = {}   ## index -> Exact.Item as it is turned, where that differs
	for key: Variant in pose:
		var shape: Exact.Shape = _shapes.get(int(key))
		if shape == null:
			continue
		var tested: Transform3D = _as_tested(int(key), pose[key])
		if tested != pose[key]:
			turned[items.size()] = Exact.Item.new(shape, pose[key])
		items.append(Exact.Item.new(shape, tested))
		keys.append(int(key))
	var every: bool = due.is_empty()
	for pair: Vector2i in Exact.candidates(items, Exact.TAU):
		var one: int = keys[pair.x]
		var other: int = keys[pair.y]
		if not every and not due.has(one) and not due.has(other):
			continue
		# One body of the gear reading never moves against itself.
		if grab == null and _body.get(one, -1) == _body.get(other, -2):
			continue
		var hit: Dictionary = _judge(one, items[pair.x], turned.get(pair.x, items[pair.x]), other,
			items[pair.y], turned.get(pair.y, items[pair.y]))
		if not hit.is_empty():
			return hit
	for n: int in items.size():
		if not every and not due.has(keys[n]):
			continue
		var item: Exact.Item = items[n]
		var seen: Dictionary = {}
		for cell: Vector3i in Simulation._cells(item):
			for s: int in _grid.get(cell, PackedInt32Array()):
				if seen.has(s):
					continue
				seen[s] = true
				var other: Exact.Item = _standing[s]
				if minf(item.hi.x, other.hi.x) - maxf(item.lo.x, other.lo.x) <= Exact.TAU \
						or minf(item.hi.y, other.hi.y) - maxf(item.lo.y, other.lo.y) <= Exact.TAU \
						or minf(item.hi.z, other.hi.z) - maxf(item.lo.z, other.lo.z) <= Exact.TAU:
					continue
				var key: int = _standing_keys[s]
				if pose.has(key):
					continue
				var hit: Dictionary = _judge(keys[n], item, turned.get(n, item), key, other, other)
				if not hit.is_empty():
					return hit
	return {}


## Whether two parts, the first moving, meet: as they were built they are
## let be, and what they were built into each other by, a joint's own pieces
## on its line, and toothed parts in mesh are forgiven ([method _forgive]).
## Each comes as it is tested ([method _as_tested]) and as it is turned: two
## that have not turned against each other are let be, the rest judged as
## tested.
func _judge(key: int, item: Exact.Item, item_turned: Exact.Item, other: int, other_item: Exact.Item,
		other_turned: Exact.Item) -> Dictionary:
	var rest_one: Transform3D = model.rest.get(key, item_turned.at)
	var rest_other: Transform3D = model.rest.get(other, other_turned.at)
	var now: Transform3D = item_turned.at.affine_inverse() * other_turned.at
	var was: Transform3D = rest_one.affine_inverse() * rest_other
	if now.origin.distance_to(was.origin) < 0.01 \
			and Quaternion(now.basis.orthonormalized() * was.basis.orthonormalized().inverse()).get_angle() < 1e-4:
		return {}
	var low: int = mini(key, other)
	var pair := Vector2i(low, maxi(key, other))
	if not _forgiven.has(pair):
		_forgiven[pair] = _forgive(pair.x, pair.y)
	var but: Variant = _forgiven[pair]
	if but is bool:
		return {}
	var a: Exact.Item = item if key == low else other_item
	var b: Exact.Item = other_item if key == low else item
	var hit: Dictionary = Exact.clash(a, b) if but == null else Exact.clash_but(a, b, but)
	if hit.is_empty():
		return {}
	return {"key": key, "other": other, "depth": float(hit["depth"])}


## What two parts are forgiven when one moves against the other: true for two
## toothed parts in mesh, gears or a pinion and its rack, whose teeth pass
## through each other's drawn shapes as they go round (Grab forgives a pair
## built into each other whole); else the pieces each joint between their
## bodies runs through (a pin in its hole, a beam on it), and the pairs of
## pieces built into each other; null for nothing.
func _forgive(a: int, b: int) -> Variant:
	var piece_a: Mechanism.Piece = model.parts[a]
	var piece_b: Mechanism.Piece = model.parts[b]
	var shape_a: Exact.Shape = _shapes[a]
	var shape_b: Exact.Shape = _shapes[b]
	var at_rest: Array = Exact.overlaps(Exact.Item.new(shape_a, piece_a.at), Exact.Item.new(shape_b, piece_b.at))
	if Simulation._toothed(piece_a.part) and Simulation._toothed(piece_b.part):
		if not at_rest.is_empty():
			return true
		for coupling: Mechanism.Coupling in model.couplings:
			if (coupling.one.key == a and coupling.other.key == b) \
					or (coupling.one.key == b and coupling.other.key == a):
				return true
	var but := Exact.Forgiven.new()
	for hit: Array in at_rest:
		but.pairs[(int(hit[2]) << 20) | int(hit[1])] = true
	var body_a: int = model.body_of(a)
	var body_b: int = model.body_of(b)
	for joint: Mechanism.Joint in model.joints:
		if not ((joint.a == body_a and joint.b == body_b) or (joint.a == body_b and joint.b == body_a)):
			continue
		var on_a: PackedByteArray = Exact.through(shape_a, piece_a.at.affine_inverse() * joint.point,
			(piece_a.at.basis.inverse() * joint.way).normalized(), ON_THE_LINE)
		var on_b: PackedByteArray = Exact.through(shape_b, piece_b.at.affine_inverse() * joint.point,
			(piece_b.at.basis.inverse() * joint.way).normalized(), ON_THE_LINE)
		but.a_pieces = Simulation._either(but.a_pieces, on_a)
		but.b_pieces = Simulation._either(but.b_pieces, on_b)
	return null if but.is_empty() else but


static func _toothed(part: String) -> bool:
	return not Mechanism.spec_of(part).is_empty() or not Mechanism.entry_of("racks", part).is_empty()


static func _either(one: PackedByteArray, other: PackedByteArray) -> PackedByteArray:
	if one.is_empty():
		return other
	var out: PackedByteArray = one.duplicate()
	for n: int in mini(out.size(), other.size()):
		out[n] = 1 if out[n] == 1 or other[n] == 1 else 0
	return out


## How high the weight of what moves stands at [param pose]: the sum of each
## moving part's grams times the height of its middle, g·LDU.
func _weight_up(pose: Dictionary) -> float:
	var sum: float = 0.0
	for key: Variant in pose:
		var it: Array = _grams.get(int(key), [])
		if not it.is_empty():
			sum += float(it[0]) * ((pose[key] as Transform3D) * (it[1] as Vector3)).y
	return sum


## The torque the weight asks of the motor over a step, N·cm: how much higher
## it stands for each radian of the driver, by virtual work. Where it first
## asks more than the motor gives, the motor stalls: found between the
## middles of the two steps either side.
func _weigh_step(at: float, next: float, pose: Dictionary) -> void:
	var weight: float = _weight_up(pose)
	var needs: float = (weight - float(_sweep["weight"])) / ((next - at) * TAU) * TORQUE_N_CM
	var middle: float = (at + next) * 0.5
	_sweep["weight"] = weight
	if heaviest.is_empty() or needs > float(heaviest["needs"]):
		heaviest = {"turns": middle, "needs": needs}
	var gives: float = float((MOTORS[motors[motor]] as Array)[1])
	if stall.is_empty() and needs > gives:
		var was: float = float(_sweep["needs"])
		var turns: float = middle
		if not is_nan(was) and needs > was:
			turns = lerpf(float(_sweep["needs_at"]), middle, (gives - was) / (needs - was))
		stall = {"turns": maxf(turns, 0.0), "needs": needs}
	_sweep["needs"] = needs
	_sweep["needs_at"] = middle


## Where it stops, in words: what meets, the range, and the motor.
func stop_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if moving.is_empty():
		return lines
	var driver_name: String = str(names.get(driver, "the driver"))
	if not meets.is_empty():
		lines.append(("MEETS: at %s of %s's turn, %s meets %s, %s LDU into it. Move one of them, "
			+ "or keep the turn short of it.") % [Simulation.angle(float(meets["turns"])), driver_name,
			_part_said(int(meets["key"])), _part_said(int(meets["other"])),
			Simulation.figure(snappedf(float(meets["depth"]), 0.1))])
	lines.append(range_line())
	if motor != 0:
		lines.append(motor_line())
	if unshaped > 0:
		lines.append("%d part%s with no exact shape %s not checked for meeting." % [unshaped,
			"" if unshaped == 1 else "s", "is" if unshaped == 1 else "are"])
	return lines


## The driver's range: from how far back to how far on it goes, and what
## stops it at each end.
func range_line() -> String:
	var driver_name: String = str(names.get(driver, "the driver"))
	var back: float = stop_back()
	var on: float = stop_on()
	var on_free: bool = on == INF
	var back_free: bool = back == -INF
	if on_free and back_free:
		return "Range: %s turns all the way round either way; nothing meets over %s of the cycle." % [
			driver_name, Simulation.angle(checked.y)]
	var line: String = "Range of %s: " % driver_name
	if back_free:
		line += "to %s on; back, nothing meets over %s" % [Simulation.angle(on), Simulation.angle(-checked.x)]
	elif on_free:
		line += "to %s back; on, nothing meets over %s" % [Simulation.angle(back), Simulation.angle(checked.y)]
	else:
		line += "%s to %s, %s in all" % [Simulation.angle(back), Simulation.angle(on), Simulation.angle(on - back)]
	var whys := PackedStringArray()
	if not back_free:
		whys.append("back, " + _why_stopped(back, meets_back, loop_reach.x, {}))
	if not on_free:
		whys.append("on, " + _why_stopped(on, meets, loop_reach.y, stall))
	var said: String = "; ".join(whys)
	return "%s. %s." % [line, said.left(1).to_upper() + said.substr(1)]


## Why it stops going on, said: "Arm (#12 3004) meets Stand (#20 32524)".
func stopped_said() -> String:
	return _why_stopped(stop_on(), meets, loop_reach.y, stall)


func _why_stopped(at: float, met: Dictionary, reach: float, stalled: Dictionary) -> String:
	if not stalled.is_empty() and at == float(stalled["turns"]):
		return "its motor stalls"
	if not met.is_empty() and at == float(met["turns"]):
		return "%s meets %s" % [_part_said(int(met["key"])), _part_said(int(met["other"]))]
	if at == reach:
		return "the loop it closes goes no further"
	return "it stops"


## What the motor is asked: where it stalls, or at its heaviest and how fast
## it then goes, by the weight of what moves alone (no friction).
func motor_line() -> String:
	var it: Array = MOTORS[motors[motor]]
	var said: String = "%s (#%d %s)" % [it[0], motor, motors[motor]]
	var gives: float = float(it[1])
	if not stall.is_empty():
		return ("STALLS: the %s at %s of its turn: the weight it lifts asks more than the %s N·cm "
			+ "it gives at 9 V, %s at most (by the parts' weight, without friction). Gear it "
			+ "down, or lighten what it lifts.") % [said, Simulation.angle(float(stall["turns"])),
			Simulation.figure(gives), Simulation.figure(snappedf(float(heaviest.get("needs",
				stall["needs"])), 0.1))]
	if heaviest.is_empty() or float(heaviest["needs"]) <= 0.0:
		return "The %s turns it with nothing to lift: %s rpm, its speed with no load." % [said,
			Simulation.figure(float(it[2]))]
	var needs: float = float(heaviest["needs"])
	return ("The %s turns it: at its heaviest, at %s, it is asked %s of its %s N·cm and slows "
		+ "from %s to %s rpm (by the parts' weight, without friction).") % [said,
		Simulation.angle(float(heaviest["turns"])), Simulation.figure(snappedf(needs, 0.1)),
		Simulation.figure(gives), Simulation.figure(float(it[2])),
		Simulation.figure(roundf(float(it[2]) * (1.0 - needs / gives)))]


## A part said with its body's name: "Arm (#12 3004)".
func _part_said(key: int) -> String:
	return "%s (#%d %s)" % [names.get(model.body_of(key), "?"), key, _part(key)]


## A turn of the driver in degrees, to a tenth: "140.5°", "-80.4°"; a turn
## or more, "2.75 turns".
static func angle(turns: float) -> String:
	if absf(turns) >= 1.0 - 1e-6:
		var said: String = Simulation.figure(snappedf(turns, 0.01))
		return "%s turn%s" % [said, "" if said in ["1", "-1"] else "s"]
	return "%s°" % Simulation.figure(snappedf(turns * 360.0, 0.1))


# -- what it found, said ------------------------------------------------------------


## Each turning body's line: its turns per driver turn and, with a
## reference, its period in the reference's turns against the real one.
## [param targets] are periods asked for by name (name -> period in the
## reference's turns). Up to [param most] lines.
func rate_lines(reference: int = -1, targets: Dictionary = {}, most: int = 12) -> PackedStringArray:
	var lines := PackedStringArray()
	var driver_name: String = str(names.get(driver, "the driver"))
	for body: int in listed(targets).slice(0, most):
		var rate: float = float(rates[body])
		var way: String = ""
		if parallel(body, driver):
			way = ", the same way" if rate * axis_of(body).dot(axis_of(driver)) > 0.0 \
				else ", the other way"
		var said: String = figure(absf(rate))
		var line: String = "%s: %s turn%s for each turn of %s%s" % [names[body], said,
			"" if said == "1" else "s", driver_name, way]
		if reference >= 0 and body != reference:
			var period: float = period_in(body, reference)
			if not is_nan(period):
				line = "%s: %s %s%s" % [names[body], figure(absf(period)), unit_of(reference),
					" (going round the other way)" if period < 0.0 else ""]
				var real: float = real_period(body, reference)
				var asked: Variant = _target_for(body, targets)
				if asked != null:
					real = float(asked)
				if not is_nan(real) and real > 0.0:
					line += "; %s %s, %+.1f%%" % ["real" if asked == null else "asked for",
						figure(real), (absf(period) / real - 1.0) * 100.0]
				line += " (%s a turn of %s)" % [figure(absf(rate)), driver_name]
		elif reference >= 0 and body == reference:
			line += " (the reference)"
		lines.append(line)
	if turning.size() > most:
		lines.append("and %d more that turn" % (turning.size() - most))
	for body: int in travels:
		lines.append(_travel_line(body, driver_name))
	return lines


## How a loop moves [param body] for each turn of the driver, said: "Tube:
## slides 1.1 studs along its line for each turn of the wheel", "the rod
## rocks 14° either way".
func _travel_line(body: int, driver_name: String) -> String:
	var said: Dictionary = travels[body]
	var how := PackedStringArray()
	if said.has("slide"):
		how.append("slides %s studs along its line for each turn of %s" % [
			Balance.studs(absf(float(said["slide"])) / BrickLattice.STUD), driver_name])
	if said.has("stroke"):
		how.append("goes %s studs back and forth for each turn of %s" % [
			Balance.studs(float(said["stroke"]) / BrickLattice.STUD), driver_name])
	if said.has("rock"):
		how.append("rocks %d° either way as %s turns" % [roundi(float(said["rock"])), driver_name])
	return "%s: %s" % [names.get(body, "?"), ", and ".join(how)]


## Whether driving it moves anything: a body that turns, or one a loop
## slides or rocks.
func moves_anything() -> bool:
	return not turning.is_empty() or not travels.is_empty()


## The turning bodies in the order they are said: those named after a
## planet or asked for by [param targets] first, then those a sub-assembly
## names, then the rest, each fastest first. An orrery's gear axles turn
## faster than its outer planets, and its readout of sixteen stopped at
## Mars with "and 25 more that turn".
func listed(targets: Dictionary = {}) -> Array:
	var out: Array = []
	for rank: int in 3:
		for body: int in turning:
			var name: String = str(names.get(body, ""))
			var said: int = 2
			if not planet_in(name).is_empty() or _target_for(body, targets) != null:
				said = 0
			elif not name.begins_with("the ") and not name.begins_with("#"):
				said = 1
			if said == rank:
				out.append(body)
	return out


func _target_for(body: int, targets: Dictionary) -> Variant:
	var name: String = str(names.get(body, "")).to_lower()
	for asked: Variant in targets:
		var word: String = str(asked).to_lower()
		if name == word or name.begins_with(word) or planet_in(name) == word:
			return float(targets[asked])
	return null


## What is wrong with it, in words a session acts on: locked (the meshes
## that fight, by part), free bodies, gears that float, holes not read.
func trouble_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if bool(solved.get("locked", false)):
		var fights := PackedStringArray()
		for pair: Array in solved.get("meshes", []):
			fights.append("#%d %s with #%d %s" % [int(pair[0]), _part(int(pair[0])), int(pair[1]),
				_part(int(pair[1]))])
		lines.append(("LOCKED: it cannot turn — the meshes ask for two different speeds at once. "
			+ "The ones that fight: %s. Take one of those gears off, or move it a stud so it "
			+ "no longer meshes.") % (", ".join(fights) if not fights.is_empty()
				else "none alone; several together"))
	var free: Array = solved.get("free", [])
	if not free.is_empty():
		var said := PackedStringArray()
		for body: int in free.slice(0, 6):
			said.append(named_with_parts(body, 2))
		lines.append(("Free (nothing decides how fast it turns, so it goes round with what "
			+ "carries it): %s%s. Mesh it with a gear that turns, or key it to an axle that "
			+ "does.") % ["; ".join(said), "; and %d more" % (free.size() - 6) if free.size() > 6
				else ""])
	var lost: Array = model.floating_gears()
	if not lost.is_empty():
		var said := PackedStringArray()
		for body: int in lost.slice(0, 6):
			said.append(named_with_parts(body, 2))
		lines.append(("Floating (on no axle, pin or turntable that reaches the base, so it "
			+ "cannot turn): %s. Put its hole on an axle's line, within the axle's length.")
			% "; ".join(said))
	var others: int = model.floating.size() - lost.size()
	if others > 0:
		lines.append("%d other part group%s touch nothing the app reads as holding them (no gear in them)."
			% [others, "" if others == 1 else "s"])
	for one: Array in model.unseated.slice(0, 3):
		lines.append("#%d %s" % [int(one[0]), str(one[1])])
	var off: Array[Mechanism.Coupling] = model.off_spacing()
	if not off.is_empty():
		var said := PackedStringArray()
		for coupling: Mechanism.Coupling in off.slice(0, 6):
			said.append("#%d %s with #%d %s, %s" % [coupling.one.key, _part(coupling.one.key),
				coupling.other.key, _part(coupling.other.key), coupling.off_said()])
		lines.append(("Off their spacing (they mesh, and turn at their teeth's ratio, but real "
			+ "ones that far out run loose or bind): %s%s.") % ["; ".join(said),
				"; and %d more" % (off.size() - 6) if off.size() > 6 else ""])
	return lines


func _part(key: int) -> String:
	var piece: Mechanism.Piece = model.parts.get(key)
	return piece.part if piece != null else "?"


## Each moving part's tint, by how fast its body turns against the driver:
## blue slow, orange fast, on a scale of how many times over; the meshes
## that lock it and the two parts that meet first red, free bodies amber,
## floating gears violet. Brick id -> Color.
func tints() -> Dictionary:
	var out: Dictionary = {}
	var fastest: float = 0.0
	var slowest: float = INF
	for body: int in turning:
		fastest = maxf(fastest, absf(float(rates[body])))
		slowest = minf(slowest, absf(float(rates[body])))
	for body: int in turning:
		var share: float = 1.0
		if fastest > slowest * 1.0001:
			share = (log(absf(float(rates[body]))) - log(slowest)) / (log(fastest) - log(slowest))
		var colour: Color = SLOW.lerp(FAST, clampf(share, 0.0, 1.0))
		for key: int in keys_of.get(body, []):
			out[key] = colour
	if driver >= 0:
		for key: int in keys_of.get(driver, []):
			out[key] = DRIVER
	for body: int in solved.get("free", []):
		for key: int in keys_of.get(body, []):
			out[key] = FREE
	for body: int in model.floating_gears():
		for key: int in keys_of.get(body, []):
			out[key] = FLOATING
	for pair: Array in solved.get("meshes", []):
		out[int(pair[0])] = LOCKED
		out[int(pair[1])] = LOCKED
	for key: int in meeting_pair():
		out[key] = LOCKED
	return out


const SLOW := Color(0.25, 0.55, 1.0)
const FAST := Color(1.0, 0.5, 0.1)
const DRIVER := Color(1.0, 1.0, 1.0)
const FREE := Color(1.0, 0.78, 0.2)
const FLOATING := Color(0.7, 0.35, 1.0)
const LOCKED := Color(1.0, 0.12, 0.12)
