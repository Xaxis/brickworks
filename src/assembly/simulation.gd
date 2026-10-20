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
## 27): Grab's model of what moves, its gear train turned by this reading
## (its ground the base), with what this reading has no equation for: a
## pinion's rack, a loop of pins (a crank, its rod and its slider), what
## hangs on a gear by a joint of its own. Every pose is Grab's while it is
## set; null when Grab does not take the driver as a turn on its own line,
## and the gear reading's poses are drawn.
var grab: Grab = null
## Why Grab's model is not drawn, "" when it is or nothing was asked.
var grab_note: String = ""
## What Grab reads it in ([method hold_with]): null for a read of bricks alone.
var world: BrickWorld = null
var builder: Builder = null
var bodies: Bodies = null
## Body -> how a loop moves it that is not a steady turn, for one turn of the
## driver: {"slide": LDU on along its line, "stroke": LDU back and forth,
## "rock": degrees either way}.
var travels: Dictionary = {}
## Grab's degrees for a turn of the driver here: its line may run the other way.
var _grab_sign: float = 1.0


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
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var mesh: Lbm.PartMesh = from.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var path: String = Assemblies.path_of(brick)
		var label: String = Assemblies.label(path) if not path.is_empty() else ""
		labels[brick.id] = label
		list.append({"key": brick.id, "part": brick.part_id, "at": brick.transform, "mesh": mesh})
		if scenery.has(brick.id):
			held.append(brick.id)
		elif Simulation.names_a_base(label):
			named_base = true
			held.append(brick.id)
	out.model = Mechanism.build(list, held)
	if held.is_empty():
		out.base_said = "the largest rigid part"
	else:
		out.base_said = "the baseplate and what stands on its studs" if not scenery.is_empty() \
			else "what is held on it"
		if named_base:
			out.base_said += ", with the sub-assemblies named as its frame"
	out._name_bodies(labels)
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


## The body the model marks as its driver (a sub-assembly named Crank,
## Motor, Handle, Driver), or -1.
func marked() -> int:
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


## The baseplate's ids, as the reading was given them.
var scenery_ids: Dictionary = {}


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
		if one.origin.distance_to(other.origin) > 0.05 \
				or (one.basis.orthonormalized() * other.basis.orthonormalized().inverse()).get_rotation_quaternion().get_angle() > 0.002:
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
	solved["said"] = "turned as a drag turns it, %s" % grab.linkage.said()



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
## that lock it red, free bodies amber, floating gears violet. Brick id ->
## Color.
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
	return out


const SLOW := Color(0.25, 0.55, 1.0)
const FAST := Color(1.0, 0.5, 0.1)
const DRIVER := Color(1.0, 1.0, 1.0)
const FREE := Color(1.0, 0.78, 0.2)
const FLOATING := Color(0.7, 0.35, 1.0)
const LOCKED := Color(1.0, 0.12, 0.12)
