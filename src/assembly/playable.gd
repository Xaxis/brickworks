## What a model has to play with: the things on its joints a person can
## take hold of and move as built (Grab), named as a visitor names them.
##
## Read from the joints the app finds (Bodies) and its gear trains
## (Mechanism), the very reading a drag uses (GrabDrag), so what a card
## says moves is what a drag on the model's link moves. Each body that
## hangs on a joint, by what is in it and how it hangs:
##
##   steering    a steering arm on its kingpin (a part named Steering Arm,
##               Steering Wheel Bearing, Wheel Spindle Steering or Steering
##               Wheel Hub), a steering rack, or whatever carries a wheel
##               and turns on an upright line (a knuckle built of beams and
##               blocks on its pin, a toy's front axle on a turntable);
##   turntable   the top of a turntable;
##   boom        a body of 6 parts or more on a hinge, a click hinge, a pin
##               or an axle that reaches 3 studs or more from its line and
##               lifts (its line is not upright), with no tyre in it, that
##               works something at its end: a crane's arm or hook, a
##               digger's bucket, a forklift's forks or a grab, on it or on
##               what hangs from it (a castle's drawbridge, a garage door,
##               a plane's folding wings and a ship's cockpit all reach and
##               lift, and each was said to be a boom, moves268);
##   doors       a door, ramp, hatch, gate, tailgate, flap or lid on a
##               hinge, a click hinge or a pin, that is the body or hangs on
##               the joint itself (a door in a castle's wing that swings, or
##               in a locomotive's half that turns on its bogie, does not
##               open: the wing and the half were said to be doors);
##   gears       two gears in mesh, one of them turning on its joint;
##   pneumatics  a pneumatic cylinder's rod;
##   actuator    a linear actuator's;
##   rack        a rack a pinion drives, that is not a steering.
##
## What a minifigure's joints move, a hose bending and a wheel on its axle
## are not said: every car and every town has them. They can still be
## dragged; they are not what a card says moves. (docs/MECHANISMS.md §21.)
class_name Playable
extends RefCounted

## The words, in the order they are said. The gallery's card shows them and
## its "Technic or mechanism" filter reads them (supabase/play.sql, which
## lists the same words; api/share.js takes no others).
const KINDS: Array[String] = ["steering", "turntable", "boom", "doors", "gears", "pneumatics",
	"actuator", "rack"]
## The words of a mechanism, for the gallery's filter: all but doors.
const MECHANISMS: Array[String] = ["steering", "turntable", "boom", "gears", "pneumatics",
	"actuator", "rack"]
const BOOM_PARTS := 6
## How far a boom reaches from its joint's line, LDU: three studs.
const BOOM_REACH := 60.0
## A line this near the upright (its cosine) is a kingpin's or a turntable's,
## as Poser.Joint.kind reads one.
const UPRIGHT := 0.9
## A window's shutter and its opening pane hang on a hinge as a door does
## (3856 on 3853, 3854 in it): BrickNet's labels name each one's.
const _DOOR_WORDS: Array[String] = ["Door", "Ramp", "Hatch", "Gate", "Tailgate", "Flap", "Lid",
	"Shutter", "Pane"]


## {kind: [brick ids]} for what moves in [param bodies]: for each kind the
## parts a person would take hold of, the biggest body's first. A steering's
## is its steering wheel where it has one, else its arms.
static func read(bodies: Bodies, world: BrickWorld, library: PartLibrary,
		mechanism: Mechanism = null) -> Dictionary:
	var found: Dictionary = {}   ## kind -> [[parts, brick id], ...]
	if bodies == null or world == null or library == null:
		return {}
	var name_of := func(key: int) -> String:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		return info.name if info != null else ""
	var moving: Dictionary = {}   ## body -> its link
	for key: Variant in bodies.parent_link:
		var body: int = int(key)
		if bodies.flexible.has(body):
			continue
		moving[body] = bodies.parent_link[body]
	for body: int in moving:
		var link: Bodies.Link = moving[body]
		var ids: PackedInt64Array = bodies.members.get(body, PackedInt64Array())
		if ids.is_empty():
			continue
		var figure: bool = false
		var tyre: bool = false
		var door: int = 0
		var arm: int = 0
		var biggest: int = _biggest(ids, world, library)
		for id: int in ids:
			var part_name: String = name_of.call(id)
			if part_name.contains("Minifig"):
				figure = true
			if part_name.contains("Tyre") or part_name.contains("Tire"):
				tyre = true
			if door == 0 and door_named(part_name) and (id == biggest or _at_joint(link, id)):
				door = id
			if arm == 0 and steering_arm(part_name):
				arm = id
		var kind: String = ""
		var driver: int = int(ids[0])
		var upright: bool = link.axis != Vector3.ZERO and absf(link.axis.normalized().y) >= UPRIGHT
		match link.kind:
			"cylinder":
				kind = "pneumatics"
			"actuator":
				kind = "actuator"
			"turntable":
				kind = "turntable" if not figure else ""
		if kind in ["", "turntable"] and not figure and not tyre and upright and link.turns \
				and _carries_wheel(bodies, body, name_of):
			# The kart that comes with the app steers by blocks on frictionless
			# pins and a beam between them, and its card said "boom".
			kind = "steering"
			driver = arm if arm != 0 else _biggest(ids, world, library)
		elif kind.is_empty() and arm != 0 and link.turns:
			kind = "steering"
			driver = arm
		elif kind.is_empty() and figure:
			continue
		elif kind.is_empty() and door != 0 and link.kind in ["hinge", "click", "pin"]:
			kind = "doors"
			driver = door
		elif kind.is_empty() and link.turns and not tyre and not upright and ids.size() >= BOOM_PARTS \
				and link.kind in ["hinge", "click", "pin", "axle"] \
				and _reach(bodies, body, link, world, library) >= BOOM_REACH \
				and _works(bodies, body, name_of):
			kind = "boom"
		if kind.is_empty():
			continue
		_add(found, kind, ids.size(), driver)
	# A steering wheel on its column: where a person turns the steering,
	# when the model has one. Not one that spins alone on its stud, which
	# turns nothing with it: the kart's, on a round brick, was named the
	# steering's, and turned it moved itself and no wheel.
	for body: int in moving:
		var ids: PackedInt64Array = bodies.members.get(body, PackedInt64Array())
		if (moving[body] as Bodies.Link).kind == "stud" and ids.size() == 1 \
				and bodies.beyond(body).size() == 1:
			continue
		for id: int in ids:
			var part_name: String = name_of.call(id)
			if part_name.contains("Steering Wheel") and not steering_arm(part_name):
				_add(found, "steering_wheel", ids.size(), id)
	# Racks a pinion drives: a steering's when it has arms, else a rack.
	for mesh: Racks.Pinion in bodies.racks():
		var rack_body: int = int(bodies.body_of.get(mesh.rack, -1))
		var gear_body: int = int(bodies.body_of.get(mesh.gear, -1))
		if not moving.has(rack_body) and not moving.has(gear_body):
			continue
		if not found.has("steering") and not name_of.call(mesh.rack).contains("Steering"):
			_add(found, "rack", 1, mesh.gear)
		elif not found.has("steering"):
			_add(found, "steering", 1, mesh.gear)
	# Gears in mesh, one of them turning on its joint.
	if mechanism != null:
		for coupling: Mechanism.Coupling in mechanism.couplings:
			for gear: Mechanism.Gear in [coupling.one, coupling.other]:
				var body: int = int(bodies.body_of.get(gear.key, -1))
				if moving.has(body) and (moving[body] as Bodies.Link).turns:
					_add(found, "gears", 1, gear.key)
	var out: Dictionary = {}
	for kind: String in KINDS:
		if not found.has(kind):
			continue
		var list: Array = found[kind]
		list.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
		var ids: Array = []
		for one: Array in list:
			if not ids.has(int(one[1])):
				ids.append(int(one[1]))
		if kind == "steering" and found.has("steering_wheel"):
			var wheels: Array = found["steering_wheel"]
			wheels.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
			ids.push_front(int(wheels[0][1]))
		out[kind] = ids
	return out


## The kinds alone, in the order they are said.
static func kinds(read_out: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for kind: String in KINDS:
		if read_out.has(kind):
			out.append(kind)
	return out


## Whether any of [param said] is a mechanism (the gallery's filter).
static func is_mechanism(said: PackedStringArray) -> bool:
	for kind: String in said:
		if MECHANISMS.has(kind):
			return true
	return false


## "Moves: steering, boom", or "" for nothing.
static func words(said: PackedStringArray) -> String:
	return "Moves: " + ", ".join(said) if not said.is_empty() else ""


## A steering arm by its name: what turns on a kingpin and steers a wheel.
static func steering_arm(name: String) -> bool:
	return name.contains("Steering Arm") or name.contains("Steering Wheel Bearing") \
		or name.contains("Wheel Spindle Steering") or name.contains("Steering Wheel Hub")


## A door, a ramp, a hatch, a gate, a tailgate, a flap, a lid, a shutter or
## a window's pane, by its name: the word whole, and not a frame for one.
static func door_named(part_name: String) -> bool:
	if part_name.contains("Frame") or part_name.begins_with("~"):
		return false
	for word: String in _DOOR_WORDS:
		var at: int = part_name.find(word)
		while at >= 0:
			var before_ok: bool = at == 0 or not part_name[at - 1].is_valid_identifier()
			var end: int = at + word.length()
			var after_ok: bool = end >= part_name.length() or not part_name[end].is_valid_identifier()
			if before_ok and after_ok:
				return true
			at = part_name.find(word, at + 1)
	return false


## What a boom works with at its end, by its name: a crane's arm, hook or
## basket, a digger's bucket or what holds one, a forklift's forks, a grab.
## Not a minifigure's tool, a crane stand (a support many models stand on),
## a tipper's bucket (a dumper's bed tips; it lifts nothing), or a hook that
## tows (a towball, a train's coupling) or a holder for one.
static func working_end(part_name: String) -> bool:
	if part_name.contains("Minifig") or part_name.begins_with("~") or part_name.contains("Crane Stand"):
		return false
	for word: String in _WORKING:
		if part_name.contains(word):
			return true
	return part_name.contains("Hook") and not (part_name.contains("Towball")
		or part_name.contains("Train") or part_name.contains("Tow-Hook") or part_name.contains("Holder"))


const _WORKING: Array[String] = ["Crane", "Excavator", "Digger Bucket", "Forklift", "Grab"]


## Whether [param body], or anything that hangs from it (a hook on its
## string, a digger's stick and bucket), has a working end (working_end).
static func _works(bodies: Bodies, body: int, name_of: Callable) -> bool:
	for id: int in bodies.parts_of(bodies.beyond(body)):
		if working_end(str(name_of.call(id))):
			return true
	return false


## Whether [param id] is one of the parts [param link] joins.
static func _at_joint(link: Bodies.Link, id: int) -> bool:
	for pair: Variant in link.pairs:
		if (pair as Array).has(id):
			return true
	return false


## A wheel or a tyre by its name, not what holds one (a wheel holder, a
## spindle, a hub, a bearing).
static func wheel_named(name: String) -> bool:
	if name.contains("Tyre") or name.contains("Tire"):
		return true
	return name.begins_with("Wheel ") and not (name.contains("Holder") or name.contains("Spindle")
		or name.contains("Hub") or name.contains("Bearing"))


## Whether a wheel turns on its own level line on [param body]: what a
## kingpin or a toy's turntable steers.
static func _carries_wheel(bodies: Bodies, body: int, name_of: Callable) -> bool:
	for child: Variant in bodies.children.get(body, []):
		var joined: Bodies.Link = bodies.parent_link.get(child)
		if joined == null or not joined.turns or joined.axis == Vector3.ZERO \
				or absf(joined.axis.normalized().y) >= UPRIGHT:
			continue
		for id: int in bodies.members.get(child, PackedInt64Array()):
			if wheel_named(str(name_of.call(id))):
				return true
	return false


## The biggest part of [param ids], by its box: what a hand takes hold of,
## not a pin in it.
static func _biggest(ids: PackedInt64Array, world: BrickWorld, library: PartLibrary) -> int:
	var best: int = int(ids[0])
	var most: float = -1.0
	for id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var size: Vector3 = info.bounds.size
		if size.x * size.y * size.z > most:
			most = size.x * size.y * size.z
			best = id
	return best


static func _add(found: Dictionary, kind: String, parts: int, driver: int) -> void:
	if not found.has(kind):
		found[kind] = []
	(found[kind] as Array).append([parts, driver])


## How far [param body]'s parts reach from its joint's line, LDU: the
## furthest middle of a part's box. A shaft and what is on it reach little.
static func _reach(bodies: Bodies, body: int, link: Bodies.Link, world: BrickWorld,
		library: PartLibrary) -> float:
	var most: float = 0.0
	var way: Vector3 = link.axis.normalized() if link.axis != Vector3.ZERO else Vector3.ZERO
	for key: int in bodies.members.get(body, PackedInt64Array()):
		var brick: BrickWorld.Brick = world.get_brick(key)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var off: Vector3 = brick.transform * info.bounds.get_center() - link.point
		if way != Vector3.ZERO:
			off -= way * off.dot(way)
		most = maxf(most, off.length())
	return most
