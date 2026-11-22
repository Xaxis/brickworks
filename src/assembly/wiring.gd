## Motors run by their cables (APP_UX11 wires): which battery box, IR
## receiver, pole reverser or hub each motor's cable reaches, which way its
## plugs face, and so how fast and which way the motor runs once the box is
## switched on. Kinebrick Studio 0.3.0 runs PF, 9 V and Powered Up cables of
## fixed lengths and battery boxes whose switches are worked on the part;
## this reads the model's own cables the same way.
##
## A Power Functions plug (58124c01, c02) sits on a part's contacts 16 LDU
## over them, its cable leaving along its own +x; turned half round on them,
## it runs its motor the other way, as the real plug does, and a quarter
## round it makes no contact. A plug's own top takes another plug, carrying
## the same four wires on. A Powered Up plug (23816c01, c02) goes into a
## hub's port one way only, its origin at the port's. Every part's contacts,
## ports, plugs and cable outlets below were measured off LDraw's own files
## (58124s01, the contacts' top; 58124s03, a cable's stub; 23807, a Powered
## Up port; 23816a, its plug) and checked against the OMR's sets: each of
## 42042's, 42043's, 42065's, 42070's, 8258's and 42124's plugs stands on
## its box, receiver, pole reverser or hub exactly so.
##
## A cable is read where the model has one:
##   - a sub-model with two of a cable's ends in it (a motor, a receiver or a
##     pole reverser, and a plug; or two plugs), as LDCad writes a cable's
##     path ("42042 - powerFuncMotorL-1.ldr": the L motor its start cap, the
##     plug its end cap, the cable drawn between) and as the flex tool lays
##     an extension wire;
##   - a sub-model with one plug and the cable's pieces, whose other end is
##     at a motor's, receiver's or reverser's outlet: the flex tool's cable
##     laid from a motor (Flex "pf_cable", "pu_cable");
##   - a part with its own cable drawn: a motor or a receiver "with Coiled
##     Cable" (58120c01), whose plug is part of it; an extension wire as one
##     part (60656, 58118), a plug at each end.
##
## What it does not do: a 9 V cable's contacts are not measured yet, nor is
## an IR remote's channel read (a receiver's two outputs are each worked on
## the part, as its remote's levers would be). Pure: Simulate (SimulatePanel)
## and simulate_mechanism hold the switches and say what runs.
class_name Wiring
extends RefCounted

## How far over the contacts a PF plug's origin stands, LDU: every plug the
## OMR's sets stand on a box, a receiver or a reverser is exactly so.
const PLUG_UP := 16.0
## How near a plug must stand to the place it goes, LDU, and how well its
## axes must line up with the contacts' (a cosine).
const NEAR := 1.5
const LINED := 0.95
## A plug turned at least this far from square (a cosine) faces one way or
## the other; nearer a quarter turn it makes no contact.
const SQUARE := 0.7
## How near a cable's last piece must come to a motor's outlet to be its
## cable, LDU.
const OUTLET_NEAR := 6.0

## Each part's contacts: [kind, where (LDraw, in the part's frame), the
## contacts' +x, their +y], kind "pf" for Power Functions' 2 x 2 contacts,
## "pu" for a Powered Up port. LDraw's axes, -y up: read through [method
## _frame].
const CONTACTS := {
	"58119": [["pf", Vector3(-40, -70, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"58123": [["pf", Vector3(-20, 0, 20), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pf", Vector3(20, 0, 20), Vector3(0, 0, 1), Vector3(0, 1, 0)]],
	"61929": [["pf", Vector3(0, 0, 40), Vector3(0, 0, 1), Vector3(0, 1, 0)]],
	"64228": [["pf", Vector3(40, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"22127": [["pu", Vector3(50, -40, -20), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pu", Vector3(50, -40, -60), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pu", Vector3(-50, -40, -20), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		["pu", Vector3(-50, -40, -60), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"22167": [["pu", Vector3(50, -40, -60), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pu", Vector3(-50, -40, -60), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"28738": [["pu", Vector3(20, 10, -80), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		["pu", Vector3(-20, 10, -80), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"19066c01": [["pu", Vector3(-20, 11, 80), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		["pu", Vector3(20, 11, 80), Vector3(-1, 0, 0), Vector3(0, 1, 0)]],
	"26910": [["pu", Vector3(40, 11, 20), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pu", Vector3(-40, 11, 20), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"45601": [["pu", Vector3(69, -68, -40), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pu", Vector3(69, -68, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pu", Vector3(69, -68, 40), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pu", Vector3(-69, -68, -40), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		["pu", Vector3(-69, -68, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		["pu", Vector3(-69, -68, 40), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"67351c01": [["pu", Vector3(-40, -68, 49), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		["pu", Vector3(40, -68, 49), Vector3(-1, 0, 0), Vector3(0, 1, 0)]],
}
## Parts drawn the same with another's contacts.
const SAME := {
	"58123c01": "58123", "58123p01": "58123", "58123p01c01": "58123", "61929c01": "61929",
	"64228c01": "64228", "19071": "19066c01", "45601c01": "45601", "45601p01": "45601",
	"45601p02": "45601",
}

## The plugs: part -> [kind, whether its top takes another plug].
const PLUGS := {
	"58124c01": ["pf", true], "58124c02": ["pf", true], "58124c03": ["pf", false],
	"23816c01": ["pu", false], "23816c02": ["pu", false], "23816a": ["pu", false],
}

## Parts drawn with their own cable and plug: part -> each plug's [kind,
## where, its +x, its +y] (LDraw, the part's frame), the plug's origin as a
## plug part's own. A motor's or a receiver's one is joined to the part by
## its cable; an extension wire's two to each other.
const OWN_PLUGS := {
	"58120c01": [["pf", Vector3(48, -30.5, 290.7), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"58121c01": [["pf", Vector3(48, -30.5, 290.7), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"99499c01": [["pf", Vector3(48, -7, 304.7), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"58123c01": [["pf", Vector3(48, 3, 215.1), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"58123p01c01": [["pf", Vector3(48, 3, 215.1), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"61929c01": [["pf", Vector3(48, 7, 235.1), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"60656": [["pf", Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pf", Vector3(48, 0, 205.1), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"58118": [["pf", Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		["pf", Vector3(100, 0, 200.4), Vector3(0, 0, -1), Vector3(0, 1, 0)]],
	"22169c01": [["pu", Vector3(48, 0, 298), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"22172c01": [["pu", Vector3(48, 0, 298), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"21980c01": [["pu", Vector3(48, -1.0913, 254.631), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"26913c01": [["pu", Vector3(48, 7, 214), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"54675c01": [["pu", Vector3(48, 14, 300), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"69730c01": [["pu", Vector3(48, 14, 300), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"54696p01c01": [["pu", Vector3(48, 0, 300), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"54696p02c01": [["pu", Vector3(48, 0, 300), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
	"68488c01": [["pu", Vector3(48, 0, 220), Vector3(1, 0, 0), Vector3(0, 1, 0)]],
}

## Where a part's cable leaves it, and the way out (LDraw, its frame): a
## motor's, a receiver's or a pole reverser's, and a plug's, which the flex
## tool lays a cable from and reads one laid back by.
const OUTLETS := {
	"58120": [Vector3(0, -23, 118), Vector3(0, -0.7071, 0.7071)],
	"58121": [Vector3(0, -42, 108), Vector3(0, -0.7071, 0.7071)],
	"99499": [Vector3(0, 0, 127), Vector3(0, 0, 1)],
	"87577": [Vector3(0, 4.7, 57.9), Vector3(0, -0.7071, 0.7071)],
	"58123": [Vector3(0, 10, 40), Vector3(0, 0, 1)],
	"61929": [Vector3(0, 14, 60), Vector3(0, 0, 1)],
	"22169": [Vector3(0, 0, 140), Vector3(0, 0, 1)],
	"22172": [Vector3(0, 0, 140), Vector3(0, 0, 1)],
	"21980": [Vector3(0, -1.0913, 96.6306), Vector3(0, 0, 1)],
	"26913": [Vector3(0, 7, 56), Vector3(0, 0, 1)],
	"54675": [Vector3(0, 14, 142), Vector3(0, 0, 1)],
	"69730": [Vector3(0, 14, 142), Vector3(0, 0, 1)],
	"58124c01": [Vector3(30, 7, 0), Vector3(1, 0, 0)],
	"58124c02": [Vector3(30, 7, 0), Vector3(1, 0, 0)],
	"58124c03": [Vector3(30, 7, 0), Vector3(1, 0, 0)],
	"23816c01": [Vector3(0, 0, -14), Vector3(0, 0, -1)],
	"23816c02": [Vector3(0, 0, -14), Vector3(0, 0, -1)],
}
const OUTLET_SAME := {
	"58120c01": "58120", "58121c01": "58121", "99499c01": "99499", "58123c01": "58123",
	"58123p01": "58123", "58123p01c01": "58123", "61929c01": "61929", "22169c01": "22169",
	"22172c01": "22172", "21980c01": "21980", "26913c01": "26913", "54675c01": "54675",
	"69730c01": "69730",
}

## What gives a motor power: part -> {kind, label, and for a box its
## switch's settings, each the way it runs a motor (1 on, -1 back, 0 off)}.
## A receiver's outputs and a pole reverser's lever go forward, off or back
## (its remote's levers; the lever on it); a hub's ports at any speed, its
## button on or off.
const SOURCES := {
	"58119": {"kind": "box", "label": "Power Functions battery box",
		"switch": [["off", 0], ["forward", 1], ["back", -1]]},
	"64228": {"kind": "box", "label": "Power Functions AAA battery box",
		"switch": [["off", 0], ["on", 1]]},
	"58123": {"kind": "receiver", "label": "Power Functions IR receiver", "outputs": ["red", "blue"]},
	"61929": {"kind": "reverser", "label": "Power Functions pole reverser"},
	"22127": {"kind": "hub", "label": "Control+ hub"},
	"22167": {"kind": "hub", "label": "Powered Up hub"},
	"28738": {"kind": "hub", "label": "Powered Up hub"},
	"19066c01": {"kind": "hub", "label": "Powered Up hub"},
	"26910": {"kind": "hub", "label": "Boost Move hub"},
	"45601": {"kind": "hub", "label": "SPIKE Prime hub"},
	"67351c01": {"kind": "hub", "label": "SPIKE Essential hub"},
}
## The settings a lever goes through: a receiver's output, a pole reverser.
const LEVER := [["off", 0], ["forward", 1], ["back", -1]]
## A hub port's speeds, a share of the motor's own.
const PORT_SPEEDS := [0.0, 0.25, 0.5, 0.75, 1.0, -0.25, -0.5, -0.75, -1.0]


## A point electricity passes: a part's contacts, a plug's bottom, or the
## end of a part's cable at the part.
class Point extends RefCounted:
	var key: String = ""
	var brick: int = -1
	## "contacts", "plug" or "terminal".
	var role: String = ""
	var kind: String = ""
	## Which of the part's contacts or plugs, from 0.
	var index: int = 0
	## World, the app's axes: where it is, its +x, its up.
	var at: Vector3
	var x: Vector3
	var up: Vector3


## The model's cables and joins, read: points, the joins between them
## ([a, b, the way it turns things, why]), and what went unjoined.
var points: Dictionary = {}
var joins: Array = []
## Brick id -> its part, for every motor, source and plug read.
var parts: Dictionary = {}
## Each motor's brick id -> its key in Simulation.MOTORS.
var motors: Dictionary = {}
## Each source's brick id -> its key in [constant SOURCES].
var sources: Dictionary = {}
## Each cable read: {ends: [point keys], how: "LDCad's path" / "laid" / "its own",
## path: the sub-model it is}.
var cables: Array = []
## Plugs that sit on nothing, or on contacts a quarter turn round:
## point key -> why.
var loose: Dictionary = {}

## The switches as worked: a box's brick id -> its setting's index in its
## switch; "brick:output" -> a lever's index in [constant LEVER]; a hub's
## brick id -> on; "brick:port" -> its speed; a box's brick id with
## "dial:" before it -> its speed, 0 to 1 (a rechargeable box's dial).
var settings: Dictionary = {}


## The cables and plugs among [param bricks] (BrickWorld.Brick), with
## [param motor_of] the key in Simulation.MOTORS a part is ("" for none).
static func read(bricks: Array, motor_of: Callable) -> Wiring:
	var out := Wiring.new()
	var by_path: Dictionary = {}   ## a sub-model's path with a plug in it -> its bricks
	var ends: Array = []           ## bricks a cable can end at, beside plugs
	# Each part number asked once: Orthanc's thousands of parts are a few
	# hundred numbers, and none of them a motor, a box or a plug.
	var known: Dictionary = {}     ## part id -> [its base part, its motor] or [] for neither
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var seen: Variant = known.get(brick.part_id)
		if seen == null:
			var base: String = Wiring.base_part(brick.part_id)
			var motor: String = str(motor_of.call(brick.part_id))
			seen = [base, motor] if not motor.is_empty() or not Wiring.source_of(base).is_empty() \
				or PLUGS.has(base) or OWN_PLUGS.has(base) else []
			known[brick.part_id] = seen
		if (seen as Array).is_empty():
			continue
		var part: String = (seen as Array)[0]
		if PLUGS.has(part):
			by_path[Assemblies.path_of(brick)] = []
		var made: String = (seen as Array)[1]
		if not made.is_empty():
			out.motors[brick.id] = made
			out.parts[brick.id] = brick.part_id
			out._terminal(brick, part)
			ends.append(brick)
		var source: String = Wiring.source_of(part)
		if not source.is_empty():
			out.sources[brick.id] = source
			out.parts[brick.id] = brick.part_id
			var contacts: Array = CONTACTS.get(SAME.get(part, part), [])
			for n: int in contacts.size():
				out._point(brick, "contacts", n, contacts[n], false)
			if str(SOURCES[source]["kind"]) != "hub" and str(SOURCES[source]["kind"]) != "box":
				out._terminal(brick, part)
				ends.append(brick)
		if PLUGS.has(part):
			out.parts[brick.id] = brick.part_id
			var plug: Array = PLUGS[part]
			var it: Point = out._point(brick, "plug", 0, [plug[0], Vector3.ZERO, Vector3(1, 0, 0),
				Vector3(0, 1, 0)], true)
			if bool(plug[1]):
				var top: Point = out._point(brick, "contacts", 0, [plug[0], Vector3.ZERO,
					Vector3(1, 0, 0), Vector3(0, 1, 0)], false)
				out.joins.append([it.key, top.key, 1, "the plug's own top"])
		if OWN_PLUGS.has(part):
			out.parts[brick.id] = brick.part_id
			var own: Array = OWN_PLUGS[part]
			var keys: Array = []
			for n: int in own.size():
				var it: Point = out._point(brick, "plug", n, own[n], true)
				keys.append(it.key)
				if str((own[n] as Array)[0]) == "pf":
					var top: Point = out._point(brick, "contacts", 100 + n, own[n], false)
					out.joins.append([it.key, top.key, 1, "the plug's own top"])
			if keys.size() == 2:
				out.cables.append({"ends": keys, "how": "its own", "path": ""})
				out.joins.append([keys[0], keys[1], 1, "the extension wire"])
			elif out.points.has("t:%d" % brick.id):
				out.cables.append({"ends": ["t:%d" % brick.id, keys[0]], "how": "its own", "path": ""})
				out.joins.append(["t:%d" % brick.id, keys[0], 1, "its own cable"])
	by_path.erase("")
	if not by_path.is_empty():
		# The sub-models a plug is in, whole: a cable's path, or one laid.
		for item: Variant in bricks:
			var path: String = Assemblies.path_of(item as BrickWorld.Brick)
			if by_path.has(path):
				(by_path[path] as Array).append(item)
	out._cables_in(by_path, ends)
	out._seat_plugs()
	return out


## Whether a part is a piece of a cable the flex tool lays (Flex's cable
## kinds draw theirs in Flex-System cable segments, scaled).
static func is_cable_piece(part_id: String) -> bool:
	return Wiring.base_part(part_id) == "343"


## A part's number without a file's "<set> - " before it and ".dat" after.
static func base_part(part_id: String) -> String:
	var name: String = part_id.to_lower().trim_suffix(".dat")
	if name.contains(" - "):
		name = name.substr(name.rfind(" - ") + 3)
	return name


## Whether a part's cable is Powered Up's (its plug goes into a hub's
## port), not Power Functions'.
static func is_powered_up(part: String) -> bool:
	var it: String = str(OUTLET_SAME.get(part, part))
	if PLUGS.has(it):
		return str((PLUGS[it] as Array)[0]) == "pu"
	return it in ["22169", "22172", "21980", "26913", "54675", "69730"]


## The key in [constant SOURCES] a part is, "" for none.
static func source_of(part: String) -> String:
	var it: String = str(SAME.get(part, part))
	return it if SOURCES.has(it) else ""


## A row's [kind, where, +x, +y] in LDraw's axes, as a frame in the app's,
## in [param brick]'s place: [where, its +x, its up].
static func _frame(brick: BrickWorld.Brick, row: Array) -> Array:
	var flip: Vector3 = LdrModel.FLIP
	var at: Vector3 = brick.transform * ((row[1] as Vector3) * flip)
	var x: Vector3 = (brick.transform.basis * ((row[2] as Vector3) * flip)).normalized()
	var up: Vector3 = (brick.transform.basis * (-(row[3] as Vector3) * flip)).normalized()
	return [at, x, up]


func _point(brick: BrickWorld.Brick, role: String, index: int, row: Array, is_plug: bool) -> Point:
	var it := Point.new()
	it.brick = brick.id
	it.role = role
	it.index = index
	it.kind = str(row[0])
	var frame: Array = Wiring._frame(brick, row)
	it.at = frame[0]
	it.x = frame[1]
	it.up = frame[2]
	it.key = "%s:%d:%d" % ["p" if is_plug else "c", brick.id, index]
	points[it.key] = it
	return it


## The end of [param brick]'s cable at the part: where its cable leaves it.
func _terminal(brick: BrickWorld.Brick, part: String) -> void:
	var it := Point.new()
	it.brick = brick.id
	it.role = "terminal"
	it.key = "t:%d" % brick.id
	var outlet: Array = OUTLETS.get(OUTLET_SAME.get(part, part), [])
	it.at = brick.transform * ((outlet[0] as Vector3) * LdrModel.FLIP) if not outlet.is_empty() \
		else brick.transform.origin
	it.x = (brick.transform.basis * ((outlet[1] as Vector3) * LdrModel.FLIP)).normalized() \
		if not outlet.is_empty() else Vector3.ZERO
	points[it.key] = it


## The cables the model's sub-models are: two of a cable's ends in one (an
## LDCad path, an extension wire laid), or one plug and the pieces of a
## cable whose far end is at a part's outlet (a cable laid from a motor).
func _cables_in(by_path: Dictionary, ends: Array) -> void:
	var cabled: Dictionary = {}
	for cable: Dictionary in cables:
		for key: String in cable["ends"]:
			cabled[key] = true
	for path: String in by_path:
		if path.is_empty():
			continue
		var inside: Array = by_path[path]
		var tips: Array = []
		var plugs: Array = []
		var others: Array = []
		var sourced: bool = false
		for brick: BrickWorld.Brick in inside:
			var part: String = Wiring.base_part(brick.part_id)
			if PLUGS.has(part):
				plugs.append("p:%d:0" % brick.id)
				tips.append("p:%d:0" % brick.id)
			elif points.has("t:%d" % brick.id) and not OWN_PLUGS.has(part):
				tips.append("t:%d" % brick.id)
			elif sources.has(brick.id) or motors.has(brick.id) or OWN_PLUGS.has(part):
				sourced = true
			else:
				others.append(brick)
		if sourced or plugs.is_empty():
			continue
		if tips.size() == 2 and (others.size() <= 8 or others.all(func(b: BrickWorld.Brick) -> bool:
				return Wiring.is_cable_piece(b.part_id))):
			cables.append({"ends": tips, "how": "a path", "path": path})
			joins.append([tips[0], tips[1], 1, "the cable"])
			cabled[tips[0]] = true
			cabled[tips[1]] = true
		elif tips.size() == 1 and not others.is_empty():
			# A cable laid from a motor: its far end at the part's outlet.
			var best: String = ""
			var nearest: float = OUTLET_NEAR
			for brick: BrickWorld.Brick in ends:
				var key: String = "t:%d" % brick.id
				if cabled.has(key) or OWN_PLUGS.has(Wiring.base_part(brick.part_id)):
					continue
				var outlet: Vector3 = (points[key] as Point).at
				for piece: BrickWorld.Brick in others:
					var off: float = piece.transform.origin.distance_to(outlet)
					if off < nearest:
						nearest = off
						best = key
			if not best.is_empty():
				cables.append({"ends": [best, tips[0]], "how": "laid", "path": path})
				joins.append([best, tips[0], 1, "the cable"])
				cabled[best] = true


## Each plug seated on the contacts or the port it stands on: joined, the
## way it faces the sign; or said loose.
func _seat_plugs() -> void:
	var places: Array = []
	for key: String in points:
		var it: Point = points[key]
		if it.role == "contacts":
			places.append(it)
	for key: String in points:
		var plug: Point = points[key]
		if plug.role != "plug":
			continue
		var found: bool = false
		for place: Point in places:
			if place.brick == plug.brick or place.kind != plug.kind:
				continue
			var lift: float = PLUG_UP if plug.kind == "pf" else 0.0
			if plug.at.distance_to(place.at + place.up * lift) > NEAR or plug.up.dot(place.up) < LINED:
				continue
			var facing: float = plug.x.dot(place.x)
			found = true
			if absf(facing) < SQUARE or (plug.kind == "pu" and facing < 0.0):
				loose[key] = "a quarter turn round on %s, so it makes no contact" % _said(place.brick)
				break
			joins.append([key, place.key, 1 if facing > 0.0 else -1,
				"on %s%s" % [_said(place.brick), "" if facing > 0.0 else ", turned half round"]])
			break
		if not found:
			loose[key] = "on nothing"


## A part said: "the Power Functions battery box (#12)".
func _said(brick: int) -> String:
	var part: String = Wiring.base_part(str(parts.get(brick, "")))
	if sources.has(brick):
		return "the %s (#%d)" % [str(SOURCES[sources[brick]]["label"]), brick]
	if PLUGS.has(part) or (OWN_PLUGS.has(part) and not motors.has(brick)):
		return "a plug (#%d)" % brick
	if motors.has(brick):
		return "the %s (#%d)" % [str((Simulation.MOTORS[motors[brick]] as Array)[0]), brick]
	return "#%d" % brick


# -- what runs ---------------------------------------------------------------------


## The way and share of its speed [param motor] (a brick id) runs at with
## the switches as set: {"run": -1 to 1, "words": how it is wired, "why":
## why it does not run, "" when it does; "wired": whether its cable reaches
## anything that gives power}.
func power_of(motor: int) -> Dictionary:
	var reached: Dictionary = _reach("t:%d" % motor, {})
	if reached.is_empty():
		return {"run": 0.0, "wired": false, "words": "", "why": _unwired(motor)}
	var value: Dictionary = _value(reached, {})
	var words: String = str(value.get("words", ""))
	return {"run": float(value["run"]), "wired": true, "words": words,
		"why": str(value.get("why", "")) if absf(float(value["run"])) < 1e-6 else ""}


## Why [param motor]'s cable reaches nothing that gives power.
func _unwired(motor: int) -> String:
	var start: String = "t:%d" % motor
	var seen: Dictionary = {start: 1}
	var queue: Array = [start]
	while not queue.is_empty():
		var at: String = queue.pop_front()
		for join: Array in joins:
			for side: int in 2:
				if str(join[side]) == at and not seen.has(str(join[1 - side])):
					seen[str(join[1 - side])] = 1
					queue.append(str(join[1 - side]))
	for key: String in seen:
		if loose.has(key):
			return "its plug (#%d) is %s" % [(points[key] as Point).brick, loose[key]]
	if seen.size() == 1:
		return "no cable of it is in the model"
	return "its cable reaches no battery box, receiver or hub"


## The sources' contacts [param start] is joined to, each with the way the
## joins between turn things: contacts key -> [sign, the joins said].
func _reach(start: String, _unused: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {start: [1, PackedStringArray()]}
	var queue: Array = [start]
	while not queue.is_empty():
		var at: String = queue.pop_front()
		var here: Array = seen[at]
		var point: Point = points.get(at)
		if point != null and point.role == "contacts" and sources.has(point.brick):
			out[at] = here
		for join: Array in joins:
			for side: int in 2:
				var other: String = str(join[1 - side])
				if str(join[side]) != at or seen.has(other):
					continue
				var said: PackedStringArray = (here[1] as PackedStringArray).duplicate()
				said.append(str(join[3]))
				seen[other] = [int(here[0]) * int(join[2]), said]
				queue.append(other)
	return out


## What the first source of [param reached] gives, through the joins'
## signs: {"run", "words", "why"}. [param asked] holds the sources being
## asked already, so a loop of cables asks none twice.
func _value(reached: Dictionary, asked: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for key: String in reached:
		var point: Point = points[key]
		if asked.has(key):
			continue
		var sign: int = int((reached[key] as Array)[0])
		var gives: Dictionary = _gives(point, asked.merged({key: true}))
		var run: float = float(gives["run"]) * float(sign)
		var words: String = "%s%s" % [_source_words(point), ", turned half round" if sign < 0 else ""]
		var through: String = str(gives.get("through", ""))
		if not through.is_empty():
			words += "; " + through
		var it: Dictionary = {"run": run, "words": words, "why": str(gives.get("why", ""))}
		if best.is_empty() or (absf(run) > 1e-6 and absf(float(best["run"])) < 1e-6):
			best = it
	return best if not best.is_empty() else {"run": 0.0, "words": "", "why": "nothing gives it power"}


## What a source's contacts [param point] give, -1 to 1: {"run", "why",
## "through"}.
func _gives(point: Point, asked: Dictionary) -> Dictionary:
	var brick: int = point.brick
	var spec: Dictionary = SOURCES[sources[brick]]
	match str(spec["kind"]):
		"box":
			var setting: Array = (spec["switch"] as Array)[switch_index(brick)]
			var dial: float = float(settings.get("dial:%d" % brick, 1.0))
			if int(setting[1]) == 0:
				return {"run": 0.0, "why": "%s is off" % _said(brick)}
			return {"run": float(setting[1]) * dial}
		"receiver", "reverser":
			var lever: int = int((LEVER[lever_index(brick, point.index)] as Array)[1])
			var input: Dictionary = _value(_reach("t:%d" % brick, {}), asked)
			var fed: float = float(input["run"])
			var through: String = "%s's own plug is %s" % [_said(brick), str(input.get("words", ""))] \
				if not str(input.get("words", "")).is_empty() else ""
			if absf(fed) < 1e-6:
				var why: String = str(input.get("why", ""))
				if why.is_empty() or why == "nothing gives it power":
					why = "%s's own cable reaches nothing that gives power" % _said(brick)
				return {"run": 0.0, "why": why, "through": through}
			if lever == 0:
				return {"run": 0.0, "why": "%s %s is off" % [_said(brick), _output_said(brick, point.index)],
					"through": through}
			# A receiver runs its outputs from the box's power whichever way
			# the box's switch is; a pole reverser passes the box's way on.
			var run: float = float(lever) * (1.0 if str(spec["kind"]) == "receiver" else fed)
			return {"run": run * float(settings.get("dial:%d:%d" % [brick, point.index], 1.0)),
				"through": through}
		"hub":
			if not bool(settings.get(brick, false)):
				return {"run": 0.0, "why": "%s is off" % _said(brick)}
			var speed: float = float(settings.get("%d:%d" % [brick, point.index], 0.0))
			if absf(speed) < 1e-6:
				return {"run": 0.0, "why": "%s's port %d is at 0%%" % [_said(brick), point.index + 1]}
			return {"run": speed}
	return {"run": 0.0, "why": "nothing gives it power"}


## "on the Power Functions battery box (#12)", "on the IR receiver's red output (#40)".
func _source_words(point: Point) -> String:
	var brick: int = point.brick
	var kind: String = str(SOURCES[sources[brick]]["kind"])
	if kind == "receiver":
		return "on %s %s" % [_said(brick), _output_said(brick, point.index)]
	if kind == "hub":
		return "in %s's port %d" % [_said(brick), point.index + 1]
	return "on %s" % _said(brick)


func _output_said(brick: int, index: int) -> String:
	var spec: Dictionary = SOURCES[sources[brick]]
	if str(spec["kind"]) == "receiver":
		return "%s output" % str((spec["outputs"] as Array)[clampi(index, 0, 1)])
	return "lever"


# -- the switches ---------------------------------------------------------------------


## A box's switch's setting, as an index into its [code]switch[/code].
func switch_index(brick: int) -> int:
	var spec: Dictionary = SOURCES.get(sources.get(brick, ""), {})
	var count: int = (spec.get("switch", [[0]]) as Array).size()
	return clampi(int(settings.get(brick, 0)), 0, count - 1)


func lever_index(brick: int, output: int) -> int:
	return clampi(int(settings.get("%d:%d" % [brick, output], 0)), 0, LEVER.size() - 1)


## Work [param brick]'s switch once, as a finger moves it: a box's to its
## next setting, a reverser's lever and a receiver's [param output] lever
## to theirs, a hub's button on or off. What it is now, said.
func work(brick: int, output: int = 0) -> String:
	if not sources.has(brick):
		return ""
	var spec: Dictionary = SOURCES[sources[brick]]
	match str(spec["kind"]):
		"box":
			var settings_of: Array = spec["switch"]
			settings[brick] = (switch_index(brick) + 1) % settings_of.size()
			return "%s switched %s" % [_said(brick), str((settings_of[switch_index(brick)] as Array)[0])]
		"receiver", "reverser":
			var key: String = "%d:%d" % [brick, output]
			settings[key] = (lever_index(brick, output) + 1) % LEVER.size()
			return "%s %s: %s" % [_said(brick), _output_said(brick, output),
				str((LEVER[lever_index(brick, output)] as Array)[0])]
		"hub":
			settings[brick] = not bool(settings.get(brick, false))
			return "%s %s" % [_said(brick), "on" if bool(settings[brick]) else "off"]
	return ""


## Set a box's switch to the setting named ("on", "off", "forward", "back"),
## a lever, or a hub's port's speed (-1 to 1, the hub on with it): false
## when the part has no such setting.
func set_to(brick: int, setting: String, output: int = 0) -> bool:
	if not sources.has(brick):
		return false
	var spec: Dictionary = SOURCES[sources[brick]]
	match str(spec["kind"]):
		"box":
			var list: Array = spec["switch"]
			var wanted: String = "forward" if setting == "on" and list.size() == 3 else setting
			for n: int in list.size():
				if str((list[n] as Array)[0]) == wanted:
					settings[brick] = n
					return true
		"receiver", "reverser":
			var wanted: String = "forward" if setting == "on" else setting
			for n: int in LEVER.size():
				if str((LEVER[n] as Array)[0]) == wanted:
					settings["%d:%d" % [brick, output]] = n
					return true
		"hub":
			if setting == "off":
				settings[brick] = false
				return true
			if setting == "on":
				settings[brick] = true
				return true
			if setting.is_valid_float():
				settings[brick] = true
				settings["%d:%d" % [brick, output]] = clampf(float(setting), -1.0, 1.0)
				return true
	return false


## Set a speed dial, 0 to 1 of the motor's speed: a receiver's output's
## (its speed remote's dial, [param output] 0 red, 1 blue), or a box's own
## ([param output] -1).
func set_dial(brick: int, share: float, output: int = -1) -> void:
	var key: String = "dial:%d" % brick if output < 0 else "dial:%d:%d" % [brick, output]
	settings[key] = clampf(share, 0.0, 1.0)


func dial_of(brick: int, output: int = -1) -> float:
	var key: String = "dial:%d" % brick if output < 0 else "dial:%d:%d" % [brick, output]
	return float(settings.get(key, 1.0))


## Every source's switch, said: "the Power Functions battery box (#12): off".
func switch_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for brick: int in sources:
		var spec: Dictionary = SOURCES[sources[brick]]
		match str(spec["kind"]):
			"box":
				var said: String = "%s: %s" % [_said(brick),
					str(((spec["switch"] as Array)[switch_index(brick)] as Array)[0])]
				var dial: float = float(settings.get("dial:%d" % brick, 1.0))
				if dial < 1.0:
					said += ", its dial at %d%%" % roundi(dial * 100.0)
				out.append(said)
			"receiver":
				var outputs := PackedStringArray()
				for n: int in 2:
					var said: String = "%s output %s" % [str((spec["outputs"] as Array)[n]),
						str((LEVER[lever_index(brick, n)] as Array)[0])]
					if dial_of(brick, n) < 1.0:
						said += " at %d%%" % roundi(dial_of(brick, n) * 100.0)
					outputs.append(said)
				out.append("%s: %s" % [_said(brick), ", ".join(outputs)])
			"reverser":
				out.append("%s: lever %s" % [_said(brick), str((LEVER[lever_index(brick, 0)] as Array)[0])])
			"hub":
				out.append("%s: %s" % [_said(brick), "on" if bool(settings.get(brick, false)) else "off"])
	return out


## Each motor, how it is wired and whether it runs: one line each.
func motor_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for motor: int in motors:
		out.append(motor_line(motor))
	return out


## One motor's line: what its cable reaches and whether it runs.
func motor_line(motor: int) -> String:
	var power: Dictionary = power_of(motor)
	var name: String = _said(motor)
	var head: String = name.left(1).to_upper() + name.substr(1)
	if not bool(power["wired"]):
		return "%s: not wired, %s." % [head, str(power["why"])]
	var run: float = float(power["run"])
	if absf(run) < 1e-6:
		return "%s: wired %s; stopped, as %s." % [head, str(power["words"]), str(power["why"])]
	return "%s: wired %s; runs %s at %d%%." % [head, str(power["words"]),
		"forward" if run > 0.0 else "back", roundi(absf(run) * 100.0)]


## Whether the model has anything that gives a motor power: with none, a
## motor turns by hand in Simulate, as it did before cables were read.
func has_power() -> bool:
	return not sources.is_empty()
