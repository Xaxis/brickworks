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
## 9 V: a 2 x 2 plug (5306 with its wire's end, 2726c01 and 6625c01 without,
## 58124c02's bottom) stands 16 LDU over 2 x 2 contacts and its top takes
## another, as a Power Functions plug does. Each electric stud is metal on a
## quarter of its side, on a diagonal (LDraw's studel), so a 9 V plug makes
## contact turned any way: turned half round it runs its motor the other
## way, and one quarter turn keeps the way while the other turns it. So a
## 9 V place's +x below is that diagonal, and the sign of a plug's +x along
## it is the way. A 9 V motor (47154c01, 71427, 74569p01) has its contacts
## on it, its cable's end being a plug put on them; the old 9 V motor's are
## under it, where a plug goes (74569p01: a point 16 LDU below its bottom, so
## a plug's top against its bottom stands as a plug on contacts does).
## Measured on 6481, 6988, 6991, 8094 and 8868: every 9 V plug standing on
## a battery box's or a motor's contacts is within 0.1 LDU of these.
##
## A cable is read where the model draws one:
##   - a sub-model with two of a cable's ends in it (a motor, a receiver or
##     a pole reverser, and a plug; or two plugs) and the cable's pieces: an
##     LDCad path ("42042 - powerFuncMotorL-1.ldr": the L motor its start cap,
##     the plug its end cap, the cable its skin), an LSynth run (8258's XL
##     motor, its plug and 366 pieces of LS70 in the motor's sub-model), a
##     9 V wire's pieces (993, 6988's), or a wire the flex tool laid;
##   - a sub-model with one plug and the cable's pieces, whose other end is
##     at a motor's, receiver's or reverser's outlet: the flex tool's cable
##     laid from a motor (Flex "pf_cable", "pu_cable");
##   - a part with its own cable drawn: a motor or a receiver "with Coiled
##     Cable" (58120c01), whose plug is part of it; an extension wire as one
##     part (60656, 58118, 75652), a plug at each end.
## Only a cable's own pieces make one: a sub-model holding a motor, a plug
## and anything else but no piece of cable is no cable.
##
## What a motor does with what is read ([method power_of]): its cable
## reaches a box, a receiver's output or a hub's port, and it runs as they
## are switched; its cable is drawn and reaches none (its plug pulled off,
## a quarter turn round), and it stops, saying why; no cable of it is drawn
## at all (a bare motor, or a coiled cable's plug left where the part draws
## it), and it turns by hand as it did before cables were read, saying so.
##
## What it does not do: an IR remote's channel is not read (a receiver's
## two outputs are each worked on the part, as its remote's levers would
## be); 9 V's pass-through plates (4757) and the 9 V control centre (2842c01)
## are not sources. Pure: Simulate (SimulatePanel) and simulate_mechanism
## hold the switches and say what runs.
class_name Wiring
extends RefCounted

## How far over the contacts a PF or 9 V plug's origin stands, LDU: every
## plug the OMR's sets stand on a box, a receiver or a reverser is exactly so.
const PLUG_UP := 16.0
## How near a plug must stand to the place it goes, LDU, and how well its
## axes must line up with the contacts' (a cosine).
const NEAR := 1.5
const LINED := 0.95
## A plug turned at least this far from square (a cosine) faces one way or
## the other; nearer a quarter turn it makes no contact. A 9 V place's +x
## is a diagonal, a square plug's along it 0.71 either way: any above
## [constant DIAGONAL] makes contact.
const SQUARE := 0.7
const DIAGONAL := 0.3
## How near a cable's last piece must come to a motor's outlet to be its
## cable, LDU.
const OUTLET_NEAR := 6.0
## How far off a plug on nothing a place it could go is named, LDU (three
## studs): "on nothing, 40 LDU from the IR receiver's contacts".
const HINT_NEAR := 60.0

## A 9 V place's +x, the diagonal its studs' metal faces (LDraw, the part's
## frame), and a 9 V plug's own top's.
const NINE_X := Vector3(-0.70710678, 0, -0.70710678)
const NINE_UNDER_X := Vector3(-0.70710678, 0, 0.70710678)
const NINE_TOP_X := Vector3(0.70710678, 0, -0.70710678)
const UP := Vector3(0, 1, 0)

## Each part's contacts: [kind, where (LDraw, in the part's frame), the
## contacts' +x, their +y], kind "pf" for Power Functions' 2 x 2 contacts,
## "pu" for a Powered Up port, "9v" for 9 V's 2 x 2. LDraw's axes, -y up:
## read through [method _frame].
const CONTACTS := {
	"58119": [["pf", Vector3(-40, -70, 0), Vector3(0, 0, -1), UP]],
	"58123": [["pf", Vector3(-20, 0, 20), Vector3(0, 0, 1), UP],
		["pf", Vector3(20, 0, 20), Vector3(0, 0, 1), UP]],
	"61929": [["pf", Vector3(0, 0, 40), Vector3(0, 0, 1), UP]],
	"64228": [["pf", Vector3(40, 0, 0), Vector3(1, 0, 0), UP]],
	"22127": [["pu", Vector3(50, -40, -20), Vector3(0, 0, 1), UP],
		["pu", Vector3(50, -40, -60), Vector3(0, 0, 1), UP],
		["pu", Vector3(-50, -40, -20), Vector3(0, 0, -1), UP],
		["pu", Vector3(-50, -40, -60), Vector3(0, 0, -1), UP]],
	"22167": [["pu", Vector3(50, -40, -60), Vector3(0, 0, 1), UP],
		["pu", Vector3(-50, -40, -60), Vector3(0, 0, -1), UP]],
	"28738": [["pu", Vector3(20, 10, -80), Vector3(1, 0, 0), UP],
		["pu", Vector3(-20, 10, -80), Vector3(1, 0, 0), UP]],
	"19066c01": [["pu", Vector3(-20, 11, 80), Vector3(-1, 0, 0), UP],
		["pu", Vector3(20, 11, 80), Vector3(-1, 0, 0), UP]],
	"26910": [["pu", Vector3(40, 11, 20), Vector3(0, 0, 1), UP],
		["pu", Vector3(-40, 11, 20), Vector3(0, 0, -1), UP]],
	"45601": [["pu", Vector3(69, -68, -40), Vector3(0, 0, 1), UP],
		["pu", Vector3(69, -68, 0), Vector3(0, 0, 1), UP],
		["pu", Vector3(69, -68, 40), Vector3(0, 0, 1), UP],
		["pu", Vector3(-69, -68, -40), Vector3(0, 0, -1), UP],
		["pu", Vector3(-69, -68, 0), Vector3(0, 0, -1), UP],
		["pu", Vector3(-69, -68, 40), Vector3(0, 0, -1), UP]],
	"67351c01": [["pu", Vector3(-40, -68, 49), Vector3(-1, 0, 0), UP],
		["pu", Vector3(40, -68, 49), Vector3(-1, 0, 0), UP]],
	# 9 V: the battery boxes' and the motors' own.
	"4760c01": [["9v", Vector3(0, 0, -60), NINE_X, UP], ["9v", Vector3(0, 0, -40), NINE_X, UP],
		["9v", Vector3(0, 0, -20), NINE_X, UP], ["9v", Vector3(0, 0, 0), NINE_X, UP],
		["9v", Vector3(0, 0, 20), NINE_X, UP]],
	"74650c01": [["9v", Vector3(0, -48, 100), NINE_X, UP]],
	"47154c01": [["9v", Vector3(0, 0, 20), NINE_X, UP]],
	"71427": [["9v", Vector3(0, 16, -20), NINE_X, UP]],
	"74569p01": [["9v", Vector3(0, 72, -30), NINE_UNDER_X, UP],
		["9v", Vector3(0, 72, -10), NINE_UNDER_X, UP], ["9v", Vector3(0, 72, 10), NINE_UNDER_X, UP],
		["9v", Vector3(0, 72, 30), NINE_UNDER_X, UP]],
}
## Parts drawn the same with another's contacts.
const SAME := {
	"58123c01": "58123", "58123p01": "58123", "58123p01c01": "58123", "61929c01": "61929",
	"64228c01": "64228", "19071": "19066c01", "45601c01": "45601", "45601p01": "45601",
	"45601p02": "45601", "2838c01": "74569p01", "2847c01": "74650c01", "74650c02": "74650c01",
	"74650c03": "74650c01", "2849": "74650c01", "2849c01": "74650c01", "2849-f1": "74650c01",
	"2849-f2": "74650c01", "4760p01c01": "4760c01", "4760p02c01": "4760c01",
	"4760p03c01": "4760c01", "4760c01d01": "4760c01", "4760c01d02": "4760c01",
	"4760c01d03": "4760c01", "4760c01d04": "4760c01", "71427c01": "71427",
}

## The plugs: part -> [the kind its bottom goes on, the kind its top takes
## ("" for none), how far over the place it goes its origin stands].
const PLUGS := {
	"58124c01": ["pf", "pf", PLUG_UP], "58124c02": ["9v", "pf", PLUG_UP],
	"58124c03": ["pf", "", PLUG_UP],
	"23816c01": ["pu", "", 0.0], "23816c02": ["pu", "", 0.0], "23816a": ["pu", "", 0.0],
	"5306": ["9v", "9v", PLUG_UP], "2726c01": ["9v", "9v", PLUG_UP], "6625c01": ["9v", "9v", PLUG_UP],
}

## Parts drawn with their own cable and plug: part -> each plug's [kind,
## where, its +x, its +y] (LDraw, the part's frame), the plug's origin as a
## plug part's own. A motor's or a receiver's one is joined to the part by
## its cable; an extension wire's two to each other.
const OWN_PLUGS := {
	"58120c01": [["pf", Vector3(48, -30.5, 290.7), Vector3(0, 0, -1), UP]],
	"58121c01": [["pf", Vector3(48, -30.5, 290.7), Vector3(0, 0, -1), UP]],
	"99499c01": [["pf", Vector3(48, -7, 304.7), Vector3(0, 0, -1), UP]],
	"58123c01": [["pf", Vector3(48, 3, 215.1), Vector3(0, 0, -1), UP]],
	"58123p01c01": [["pf", Vector3(48, 3, 215.1), Vector3(0, 0, -1), UP]],
	"61929c01": [["pf", Vector3(48, 7, 235.1), Vector3(0, 0, -1), UP]],
	"60656": [["pf", Vector3(0, 0, 0), Vector3(0, 0, 1), UP],
		["pf", Vector3(48, 0, 205.1), Vector3(0, 0, -1), UP]],
	"58118": [["pf", Vector3(0, 0, 0), Vector3(0, 0, 1), UP],
		["pf", Vector3(100, 0, 200.4), Vector3(0, 0, -1), UP]],
	"75652": [["9v", Vector3(0, 0, 0), Vector3(-1, 0, 0), UP],
		["9v", Vector3(0, 30, -14), Vector3(-1, 0, 0), UP]],
	"22169c01": [["pu", Vector3(48, 0, 298), Vector3(1, 0, 0), UP]],
	"22172c01": [["pu", Vector3(48, 0, 298), Vector3(1, 0, 0), UP]],
	"21980c01": [["pu", Vector3(48, -1.0913, 254.631), Vector3(1, 0, 0), UP]],
	"26913c01": [["pu", Vector3(48, 7, 214), Vector3(1, 0, 0), UP]],
	"54675c01": [["pu", Vector3(48, 14, 300), Vector3(1, 0, 0), UP]],
	"69730c01": [["pu", Vector3(48, 14, 300), Vector3(1, 0, 0), UP]],
	"54696p01c01": [["pu", Vector3(48, 0, 300), Vector3(1, 0, 0), UP]],
	"54696p02c01": [["pu", Vector3(48, 0, 300), Vector3(1, 0, 0), UP]],
	"68488c01": [["pu", Vector3(48, 0, 220), Vector3(1, 0, 0), UP]],
}

## Where a part's cable leaves it, and the way out (LDraw, its frame): a
## motor's, a receiver's or a pole reverser's, which the flex tool lays a
## cable from and reads one laid back by. A plug's own is the flex tool's
## (Flex.KINDS "stub").
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
}
const OUTLET_SAME := {
	"58120c01": "58120", "58121c01": "58121", "99499c01": "99499", "58123c01": "58123",
	"58123p01": "58123", "58123p01c01": "58123", "61929c01": "61929", "22169c01": "22169",
	"22172c01": "22172", "21980c01": "21980", "26913c01": "26913", "54675c01": "54675",
	"69730c01": "69730",
}

## The pieces a cable is drawn in, by part: LDraw's electric cable segments
## (the flex tool lays Power Functions' in u9190, Powered Up's in u9392 and
## 9 V's in 993), LSynth's Power Functions cable (LS70: 8258's, 8275's,
## 9397's), and the end LDCad puts under each 9 V cap (2727ac01). An LDCad
## path's skin, one part of its own (CustomParts), is a cable's too where it
## is between a cable's ends.
const CABLE_PIECES := {
	"u9190": true, "u9028": true, "u9392": true, "993": true, "932": true, "ls70": true,
	"2727ac01": true,
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
	"4760c01": {"kind": "box", "label": "9 V battery box",
		"switch": [["off", 0], ["forward", 1], ["back", -1]]},
	"74650c01": {"kind": "box", "label": "9 V battery box",
		"switch": [["off", 0], ["forward", 1], ["back", -1]]},
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
	## A plug's: how far over the place it goes its origin stands.
	var lift: float = 0.0
	## A plug's own top: it carries what the plug carries on, and is no
	## source's own output, though the plug be a receiver's.
	var top: bool = false


## The model's cables and joins, read: points, the joins between them
## ([a, b, the way it turns things, why, what: "cable", "seat", "own",
## "top" or "contacts"]), and what went unjoined.
var points: Dictionary = {}
var joins: Array = []
## Brick id -> its part, for every motor, source and plug read.
var parts: Dictionary = {}
## Each motor's brick id -> its key in Simulation.MOTORS.
var motors: Dictionary = {}
## Each source's brick id -> its key in [constant SOURCES].
var sources: Dictionary = {}
## Each cable read: {ends: [point keys], how: "a path" / "laid" / "its own",
## path: the sub-model it is}.
var cables: Array = []
## Plugs that sit on nothing, or on contacts a quarter turn round:
## point key -> why.
var loose: Dictionary = {}
## The loose plugs that are on nothing at all (a plug key -> true), not
## turned on something: whatever language [member loose] is said in.
var nothing: Dictionary = {}
## Each point key -> its joins, for walking them.
var _by_point: Dictionary = {}

## The switches as worked: a box's brick id -> its setting's index in its
## switch; "brick:output" -> a lever's index in [constant LEVER]; a hub's
## brick id -> on; "brick:port" -> its speed; a box's brick id with
## "dial:" before it -> its speed, 0 to 1 (a rechargeable box's dial).
var settings: Dictionary = {}
## Words said in the language the app is in (Simulate's own row), not the
## English a session reads.
var local: bool = false


## The cables and plugs among [param bricks] (BrickWorld.Brick), with
## [param motors] each motor's brick id -> its key in Simulation.MOTORS, as
## Simulation.motors_in reads them (a motor drawn in its pieces is keyed by
## its hub's piece): Simulate's, read with the rest of its model.
static func read(bricks: Array, motors: Dictionary, in_language: bool = false) -> Wiring:
	return Wiring._read(bricks, motors, null, in_language)


## The motors among [param bricks] and their cables, as [method read] reads
## them, for a caller with the library and no Simulation at hand: the
## motors found in the same pass, as Simulation.motors_in finds them.
static func read_with(bricks: Array, library: PartLibrary) -> Wiring:
	return Wiring._read(bricks, {}, library, false)


## [method read], the motors given in [param motors] or, with
## [param library], found as each part is read. One pass over the parts, a
## look at each part's number: on Orthanc's 10,101 a second pass to find
## the motors first held the read at 57 ms (wfix2).
static func _read(bricks: Array, motors: Dictionary, library: PartLibrary, in_language: bool) -> Wiring:
	var out := Wiring.new()
	# Said in the person's language from the first word read, as the joins
	# and loose plugs are said once, here.
	out.local = in_language
	var finds: bool = library != null
	var slots: Dictionary = {}     ## sub-model path -> {"tips": [point keys], "pieces": [bricks]}
	var ends: Array = []           ## bricks a laid cable's far end can be at
	# Each part number asked once: Orthanc's thousands of parts are a few
	# hundred numbers, and none of them a motor, a box, a plug or a cable.
	var known: Dictionary = {}     ## part id -> [method _class_of]
	var drawn: Dictionary = {}     ## a hub piece's sub-model -> [the drawn motor's sub-model, its key] or ["", ""]
	var keyed: Dictionary = {}     ## a drawn motor's sub-model whose hub piece is read
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var seen: Variant = known.get(brick.part_id)
		if seen == null:
			seen = Wiring._class_of(brick.part_id, library, finds)
			known[brick.part_id] = seen
		var motor: String = ""
		if seen is bool:
			# Nothing wiring reads, unless Simulate's motors say it is one.
			if finds or not motors.has(brick.id):
				continue
			motor = str(motors[brick.id])
			seen = [""]
		elif not finds:
			motor = str(motors.get(brick.id, ""))
		elif (seen as Array).size() > 2:
			motor = str((seen as Array)[2])
		if finds and (seen as Array).size() > 3 and bool((seen as Array)[3]):
			# A motor drawn in its pieces: the first hub piece in the
			# sub-model named for it is the motor (Simulation.motors_in).
			var holder: String = Assemblies.path_of(brick)
			var found: Variant = drawn.get(holder)
			if found == null:
				var it: Array = Simulation.drawn_motor_at(holder)
				found = [str(it[0]), str(it[1])] if not it.is_empty() else ["", ""]
				drawn[holder] = found
			var at: String = str((found as Array)[0])
			if not at.is_empty() and not keyed.has(at):
				keyed[at] = true
				motor = str((found as Array)[1])
		var part: String = (seen as Array)[0]
		if part.is_empty():
			if motor.is_empty():
				continue
			part = Wiring.base_part(brick.part_id)
		var path: String = Assemblies.path_of(brick)
		if (seen as Array).size() > 1 and bool((seen as Array)[1]):
			(Wiring._slot(slots, path)["pieces"] as Array).append(brick)
			continue
		if not motor.is_empty():
			out.motors[brick.id] = motor
			out.parts[brick.id] = brick.part_id
			out._terminal(brick, part)
			# A 9 V motor's own contacts: a plug on them is its cable's end.
			var own: Array = CONTACTS.get(SAME.get(part, part), [])
			for n: int in own.size():
				var contacts: Point = out._point(brick, "contacts", n, own[n], false)
				out._join("t:%d" % brick.id, contacts.key, 1, out._t("its contacts"), "contacts")
			if not OWN_PLUGS.has(part) and own.is_empty():
				# A motor drawn in its pieces is its sub-model: a cable's end
				# in the one that holds it, as LDCad's path holds it (42131).
				var at: String = Assemblies.parent_of(path) if Simulation.HUBS.has(part) else path
				Wiring._tip(slots, at, "t:%d" % brick.id, brick.id)
				ends.append(brick)
		var source: String = Wiring.source_of(part)
		if not source.is_empty():
			out.sources[brick.id] = source
			out.parts[brick.id] = brick.part_id
			var contacts: Array = CONTACTS.get(SAME.get(part, part), [])
			for n: int in contacts.size():
				out._point(brick, "contacts", n, contacts[n], false)
			var kind: String = str(SOURCES[source]["kind"])
			if kind == "receiver" or kind == "reverser":
				out._terminal(brick, part)
				if not OWN_PLUGS.has(part):
					Wiring._tip(slots, path, "t:%d" % brick.id, brick.id)
					ends.append(brick)
		if PLUGS.has(part):
			out.parts[brick.id] = brick.part_id
			var plug: Array = PLUGS[part]
			var it: Point = out._point(brick, "plug", 0, [plug[0], Vector3.ZERO, Vector3(1, 0, 0), UP], true)
			it.lift = float(plug[2])
			if not str(plug[1]).is_empty():
				var top: Point = out._point(brick, "contacts", 0, [plug[1], Vector3.ZERO,
					Wiring._top_x(str(plug[1]), Vector3(1, 0, 0), UP), UP], false)
				top.top = true
				out._join(it.key, top.key, 1, out._t("the plug's own top"), "top")
			Wiring._tip(slots, path, it.key, brick.id)
		if OWN_PLUGS.has(part):
			out.parts[brick.id] = brick.part_id
			var own: Array = OWN_PLUGS[part]
			var keys: Array = []
			for n: int in own.size():
				var row: Array = own[n]
				var it: Point = out._point(brick, "plug", n, row, true)
				it.lift = PLUG_UP if str(row[0]) != "pu" else 0.0
				keys.append(it.key)
				if str(row[0]) != "pu":
					var top: Point = out._point(brick, "contacts", 100 + n, [row[0], row[1],
						Wiring._top_x(str(row[0]), row[2], row[3]), row[3]], false)
					top.top = true
					out._join(it.key, top.key, 1, out._t("the plug's own top"), "top")
			if keys.size() == 2:
				out.cables.append({"ends": keys, "how": "its own", "path": ""})
				out._join(keys[0], keys[1], 1, out._t("the extension wire"), "cable")
			elif out.points.has("t:%d" % brick.id):
				out.cables.append({"ends": ["t:%d" % brick.id, keys[0]], "how": "its own", "path": ""})
				out._join("t:%d" % brick.id, keys[0], 1, out._t("its own cable"), "own")
	# A sub-model of a cable's two ends and nothing else is a cable too: an
	# LDCad path whose skin is drawing, not a part (an open that built none).
	var bare: Dictionary = {}
	for path: String in slots:
		if (slots[path]["tips"] as Array).size() == 2 and (slots[path]["pieces"] as Array).is_empty():
			bare[path] = true
	if not bare.is_empty():
		for item: Variant in bricks:
			var brick: BrickWorld.Brick = item
			var path: String = Assemblies.path_of(brick)
			if bare.has(path) and not (slots[path]["ids"] as Dictionary).has(brick.id):
				bare.erase(path)
	out._cables_in(slots, ends, bare)
	out._seat_plugs()
	return out


## Where an end of a cable of Flex kind [param kind] may go among
## [param world]'s parts shown, but those in [param skip] (a cable laid
## again: its own pieces and plug): each motor's, receiver's and pole
## reverser's outlet ("outlet") when the kind runs from one, and each
## battery box's, receiver output's, pole reverser's and plug top's contacts
## or hub's port ("contacts"), of the kind's own system; each a
## Flex.Anchor, with why it is taken now in its [code]taken[/code] ("" when
## free): the outlet's cable is there already, a plug of another part is on
## the contacts. Taken places are kept, so a caller says first whether the
## ends make a cable at all, then whether they are free (lay_flex).
static func places(world: BrickWorld, library: PartLibrary, kind: String, skip: Dictionary = {}) -> Array:
	var spec: Dictionary = Flex.KINDS[kind]
	var system: String = str(spec["electric"])
	var bricks: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not brick.hidden and not skip.has(brick.id):
			bricks.append(brick)
	var wired: Wiring = Wiring.read_with(bricks, library)
	var taken: Dictionary = {}   ## point key -> why
	for join: Array in wired.joins:
		if str(join[4]) != "seat":
			continue
		var plug: int = (wired.points[str(join[0])] as Point).brick
		var place: Point = wired.points[str(join[1])]
		taken[place.key] = ("port %d of #%d has a plug (#%d) in it" % [place.index + 1, place.brick, plug]
			if place.kind == "pu" else "a plug (#%d) is on #%d's contacts already: give to= that plug, "
			% [plug, place.brick] + "whose top takes another")
	for cable: Dictionary in wired.cables:
		var plug: int = -1
		for end: String in cable["ends"]:
			if end.begins_with("p:"):
				plug = (wired.points[end] as Point).brick
		for end: String in cable["ends"]:
			if end.begins_with("t:"):
				taken[end] = "#%s's own cable is laid already (%s): give item= it to lay it again%s" % [
					end.trim_prefix("t:"), Assemblies.label(str(cable["path"]))
					if not str(cable["path"]).is_empty() else "drawn with the part", "" if plug < 0
					else ", or to= its plug (#%d) to stack another cable's plug on it" % plug]
	var out: Array = []
	for key: String in wired.points:
		var point: Point = wired.points[key]
		var anchor := Flex.Anchor.new()
		anchor.brick = point.brick
		anchor.taken = str(taken.get(key, ""))
		if point.role == "terminal" and point.x != Vector3.ZERO:
			if Wiring.system_of(Wiring.base_part(str(wired.parts.get(point.brick, "")))) != system \
					or not (spec["takes"] as Array).has("outlet"):
				continue
			anchor.kind = "outlet"
			anchor.at = point.at
			anchor.axis = point.x
			out.append(anchor)
		elif point.role == "contacts" and point.kind == system:
			anchor.kind = "contacts"
			anchor.at = point.at
			anchor.axis = point.up
			anchor.x = point.x
			out.append(anchor)
	return out


## Why no end of a cable of Flex kind [param kind] goes on a
## [param part_id] at all, where it has a cable of another system: the kind
## its cable is. "" for any other part.
static func system_refusal(part_id: String, kind: String) -> String:
	var part: String = Wiring.base_part(part_id)
	var its: String = Wiring.system_of(part)
	var rows: Array = CONTACTS.get(SAME.get(part, part), [])
	if its.is_empty() and not rows.is_empty():
		its = str((rows[0] as Array)[0])
	if its.is_empty() or its == str(Flex.KINDS[kind]["electric"]):
		return ""
	for other: String in Flex.KINDS:
		if str((Flex.KINDS[other] as Dictionary).get("electric", "")) == its:
			return "its cable is a %s: lay_flex kind=%s" % [str(Flex.KINDS[other]["label"]), other]
	return ""


## [base part, whether it is a piece of cable] for a part wiring reads, or
## false for one it does not. With [param finds], a part that is a motor
## (Simulation.motor_of) or may be the hub of one drawn in its pieces
## (Simulation.HUBS) is [its base part or "", a piece of cable, its key in
## Simulation.MOTORS or "", whether it may be such a hub].
static func _class_of(part_id: String, library: PartLibrary = null, finds: bool = false) -> Variant:
	var base: String = Wiring.base_part(part_id)
	var out: Array = []
	if not Wiring.source_of(base).is_empty() or PLUGS.has(base) or OWN_PLUGS.has(base) \
			or CONTACTS.has(SAME.get(base, base)):
		out = [base, false]
	elif Wiring.is_cable_piece(part_id):
		out = [base, true]
	var motor: String = Simulation.motor_of(library, part_id) if finds else ""
	var hub: bool = finds and part_id in Simulation.HUBS
	if motor.is_empty() and not hub:
		return out if not out.is_empty() else false
	return [base if not out.is_empty() else "", not out.is_empty() and bool(out[1]), motor, hub]


static func _slot(slots: Dictionary, path: String) -> Dictionary:
	if not slots.has(path):
		slots[path] = {"tips": [], "pieces": [], "ids": {}}
	return slots[path]


## A cable's end [param key] (of brick [param id]) in the sub-model at
## [param path].
static func _tip(slots: Dictionary, path: String, key: String, id: int) -> void:
	var slot: Dictionary = Wiring._slot(slots, path)
	(slot["tips"] as Array).append(key)
	(slot["ids"] as Dictionary)[id] = true


## Whether a part is a piece of a cable ([constant CABLE_PIECES]), or an
## LDCad path's skin (one part of its own: it is a cable's where it lies
## between a cable's two ends).
static func is_cable_piece(part_id: String) -> bool:
	return CABLE_PIECES.has(Wiring.base_part(part_id)) or CustomParts.is_skin(part_id)


## A part's number without a file's "<set> - " before it and ".dat" after.
static func base_part(part_id: String) -> String:
	var name: String = part_id.to_lower().trim_suffix(".dat")
	if name.contains(" - "):
		name = name.substr(name.rfind(" - ") + 3)
	return name


## Whether a part's cable is Powered Up's (its plug goes into a hub's
## port), not Power Functions'.
static func is_powered_up(part: String) -> bool:
	return Wiring.system_of(part) == "pu"


## The system a part's cable is of: "pf", "pu" or "9v" ("" for a part with
## no cable).
static func system_of(part: String) -> String:
	var it: String = str(OUTLET_SAME.get(part, part))
	if PLUGS.has(it):
		# A plug's cable is its top's system: 58124c02's is Power Functions'.
		var plug: Array = PLUGS[it]
		return str(plug[1]) if not str(plug[1]).is_empty() else str(plug[0])
	if it in ["22169", "22172", "21980", "26913", "54675", "69730"]:
		return "pu"
	if OUTLETS.has(it):
		return "pf"
	return ""


## The key in [constant SOURCES] a part is, "" for none.
static func source_of(part: String) -> String:
	var it: String = str(SAME.get(part, part))
	return it if SOURCES.has(it) else ""


## A plug's own top's +x, LDraw, from the plug's own +x and +y: a Power
## Functions top faces as the plug does; a 9 V one along its studs'
## diagonal, turned as the plug is.
static func _top_x(kind: String, x: Vector3, up: Vector3) -> Vector3:
	if kind != "9v":
		return x
	var z: Vector3 = x.cross(up)
	return (x * NINE_TOP_X.x + z * NINE_TOP_X.z).normalized()


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


func _join(a: String, b: String, sign: int, why: String, what: String) -> void:
	var join: Array = [a, b, sign, why, what]
	joins.append(join)
	for key: String in [a, b]:
		if not _by_point.has(key):
			_by_point[key] = []
		(_by_point[key] as Array).append(join)


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


## The cables the model's sub-models are: two of a cable's ends and its
## pieces in one (an LDCad path, an LSynth run, a wire laid), or one plug
## and the pieces of a cable whose far end is at a part's outlet (a cable
## laid from a motor). A sub-model with no piece of cable in it is none,
## whatever else is in it.
func _cables_in(slots: Dictionary, ends: Array, bare: Dictionary) -> void:
	var cabled: Dictionary = {}
	for cable: Dictionary in cables:
		for key: String in cable["ends"]:
			cabled[key] = true
	for path: String in slots:
		var slot: Dictionary = slots[path]
		var tips: Array = slot["tips"]
		var pieces: Array = slot["pieces"]
		if (pieces.is_empty() and not bare.has(path)) or tips.is_empty():
			continue
		var plugs: int = tips.filter(func(key: String) -> bool: return key.begins_with("p:")).size()
		if tips.size() == 2 and plugs >= 1:
			cables.append({"ends": tips, "how": "a path", "path": path})
			_join(tips[0], tips[1], 1, _t("the cable"), "cable")
			cabled[tips[0]] = true
			cabled[tips[1]] = true
		elif tips.size() == 1 and plugs == 1:
			# A cable laid from a motor: its far end at the part's outlet.
			var best: String = ""
			var nearest: float = OUTLET_NEAR
			for brick: BrickWorld.Brick in ends:
				var key: String = "t:%d" % brick.id
				var outlet: Point = points[key]
				if cabled.has(key) or outlet.x == Vector3.ZERO:
					continue
				for piece: BrickWorld.Brick in pieces:
					for tip: Vector3 in [piece.transform.origin, piece.transform.origin - piece.transform.basis.y]:
						var off: float = tip.distance_to(outlet.at)
						if off < nearest:
							nearest = off
							best = key
			if not best.is_empty():
				cables.append({"ends": [best, tips[0]], "how": "laid", "path": path})
				_join(best, tips[0], 1, _t("the cable"), "cable")
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
		var hint: Point = null
		var hint_off: float = HINT_NEAR
		for place: Point in places:
			if place.brick == plug.brick or place.kind != plug.kind:
				continue
			var off: float = plug.at.distance_to(place.at + place.up * plug.lift)
			if off > NEAR or plug.up.dot(place.up) < LINED:
				if off < hint_off and not place.top:
					hint_off = off
					hint = place
				continue
			var facing: float = plug.x.dot(place.x)
			found = true
			if plug.kind == "pu" and facing < -SQUARE:
				loose[key] = _t("turned half round in %s's port %d, which a Powered Up plug goes into one way only") \
					% [_said(place.brick), place.index + 1]
				break
			if absf(facing) < (DIAGONAL if plug.kind == "9v" else SQUARE):
				loose[key] = _t("a quarter turn round on %s, so it makes no contact") % _said(place.brick)
				break
			_join(key, place.key, 1 if facing > 0.0 else -1,
				_t("on %s") % _said(place.brick) + ("" if facing > 0.0 else _t(", turned half round")), "seat")
			break
		if not found:
			loose[key] = _t("on nothing") if hint == null else _t("on nothing, %d LDU from %s") % [
				roundi(hint_off), _place_said(hint)]
			nothing[key] = true


## A part said: "the Power Functions battery box (#12)".
func _said(brick: int) -> String:
	var part: String = Wiring.base_part(str(parts.get(brick, "")))
	if sources.has(brick):
		return _t("the %s (#%d)") % [_t(str(SOURCES[sources[brick]]["label"])), brick]
	if PLUGS.has(part) or (OWN_PLUGS.has(part) and not motors.has(brick)):
		return _t("a plug (#%d)") % brick
	if motors.has(brick):
		return _t("the %s (#%d)") % [str((Simulation.MOTORS[motors[brick]] as Array)[0]), brick]
	return "#%d" % brick


## A place said: "the Power Functions IR receiver (#40)'s blue output".
func _place_said(place: Point) -> String:
	if sources.has(place.brick) and str(SOURCES[sources[place.brick]]["kind"]) == "receiver":
		return "%s %s" % [_said(place.brick), _output_said(place.brick, place.index)]
	if sources.has(place.brick) and str(SOURCES[sources[place.brick]]["kind"]) == "hub":
		return _t("%s's port %d") % [_said(place.brick), place.index + 1]
	return _t("%s's contacts") % _said(place.brick)


## [param words] in the app's language when [member local].
func _t(words: String, context: String = "") -> String:
	return String(TranslationServer.translate(words, context)) if local else words


## A switch's or an output's one word (on, off, forward, back, lever, red,
## blue) in the person's language: kept apart from the same words elsewhere
## (the camera's "back" view) by the context "power".
func _w(word: String) -> String:
	return _t(word, "power")


# -- what runs ---------------------------------------------------------------------


## The way and share of its speed [param motor] (a brick id) runs at with
## the switches as set: {"run": -1 to 1, "words": how it is wired, "why":
## why it does not run, "" when it does; "wired": whether its cable reaches
## anything that gives power; "by_hand": no cable of it is drawn, so it is
## turned by hand as before cables were read}.
func power_of(motor: int) -> Dictionary:
	var reached: Dictionary = _reach("t:%d" % motor)
	if reached.is_empty():
		var state: Array = _unwired(motor)
		return {"run": 0.0, "wired": false, "words": "", "why": str(state[0]), "by_hand": not bool(state[1])}
	var value: Dictionary = _value(reached, {})
	var words: String = str(value.get("words", ""))
	return {"run": float(value["run"]), "wired": true, "words": words, "by_hand": false,
		"why": str(value.get("why", "")) if absf(float(value["run"])) < 1e-6 else ""}


## Whether [param motor] turns by hand: nothing in the model gives power,
## or no cable of it is drawn.
func by_hand(motor: int) -> bool:
	return not has_power() or bool(power_of(motor)["by_hand"])


## Why [param motor]'s cable reaches nothing that gives power, and whether
## a cable of it is drawn at all: [why, drawn].
func _unwired(motor: int) -> Array:
	var start: String = "t:%d" % motor
	var seen: Dictionary = {start: 1}
	var queue: Array = [start]
	var drawn: bool = false
	while not queue.is_empty():
		var at: String = queue.pop_front()
		for join: Array in _by_point.get(at, []):
			var what: String = str(join[4])
			drawn = drawn or what == "cable" or what == "seat"
			for side: int in 2:
				if str(join[side]) == at and not seen.has(str(join[1 - side])):
					seen[str(join[1 - side])] = 1
					queue.append(str(join[1 - side]))
	var own_plug: String = ""
	for key: String in seen:
		if loose.has(key):
			if not nothing.has(key):
				drawn = true
			if drawn:
				return [_t("its plug (#%d) is %s") % [(points[key] as Point).brick, loose[key]], true]
			own_plug = key
	if not drawn:
		if not own_plug.is_empty():
			return [_t("its own cable's plug is in nothing, so it turns by hand; put the plug on a box "
				+ "or lay a cable from it to run it by the box"), false]
		return [_t("no cable of it is drawn in the model, so it turns by hand; lay one from it to a box "
			+ "(Make › Hose, tube or chain…, a cable) to run it by the box"), false]
	return [_t("its cable reaches no battery box, receiver or hub"), true]


## The sources' contacts [param start] is joined to, each with the way the
## joins between turn things: contacts key -> [sign, the joins said].
func _reach(start: String) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {start: [1, PackedStringArray()]}
	var queue: Array = [start]
	while not queue.is_empty():
		var at: String = queue.pop_front()
		var here: Array = seen[at]
		var point: Point = points.get(at)
		if point != null and point.role == "contacts" and not point.top and sources.has(point.brick):
			out[at] = here
		for join: Array in _by_point.get(at, []):
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
		var words: String = "%s%s" % [_source_words(point), _t(", turned half round") if sign < 0 else ""]
		var through: String = str(gives.get("through", ""))
		if not through.is_empty():
			words += "; " + through
		var it: Dictionary = {"run": run, "words": words, "why": str(gives.get("why", ""))}
		if best.is_empty() or (absf(run) > 1e-6 and absf(float(best["run"])) < 1e-6):
			best = it
	return best if not best.is_empty() else {"run": 0.0, "words": "", "why": _t("nothing gives it power")}


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
				return {"run": 0.0, "why": _t("%s is off: click it to switch it on") % _said(brick)}
			return {"run": float(setting[1]) * dial}
		"receiver", "reverser":
			var lever: int = int((LEVER[lever_index(brick, point.index)] as Array)[1])
			var input: Dictionary = _value(_reach("t:%d" % brick), asked)
			var fed: float = float(input["run"])
			var through: String = _t("%s's own plug is %s") % [_said(brick), str(input.get("words", ""))] \
				if not str(input.get("words", "")).is_empty() else ""
			if absf(fed) < 1e-6:
				var why: String = str(input.get("why", ""))
				if why.is_empty() or why == _t("nothing gives it power"):
					why = _t("%s's own cable reaches nothing that gives power") % _said(brick)
				return {"run": 0.0, "why": why, "through": through}
			if lever == 0:
				return {"run": 0.0, "why": _t("%s %s is off: click it to work its lever") % [_said(brick),
					_output_said(brick, point.index)], "through": through}
			# A receiver runs its outputs from the box's power whichever way
			# the box's switch is; a pole reverser passes the box's way on.
			var run: float = float(lever) * (1.0 if str(spec["kind"]) == "receiver" else fed)
			return {"run": run * float(settings.get("dial:%d:%d" % [brick, point.index], 1.0)),
				"through": through}
		"hub":
			if not bool(settings.get(brick, false)):
				return {"run": 0.0, "why": _t("%s is off: click it to switch it on") % _said(brick)}
			var speed: float = port_speed(brick, point.index)
			if absf(speed) < 1e-6:
				return {"run": 0.0, "why": _t("%s's port %d is at 0%%") % [_said(brick), point.index + 1]}
			return {"run": speed}
	return {"run": 0.0, "why": _t("nothing gives it power")}


## "on the Power Functions battery box (#12)", "on the IR receiver's red output (#40)".
func _source_words(point: Point) -> String:
	var brick: int = point.brick
	var kind: String = str(SOURCES[sources[brick]]["kind"])
	if kind == "receiver":
		return _t("on %s %s") % [_said(brick), _output_said(brick, point.index)]
	if kind == "hub":
		return _t("in %s's port %d") % [_said(brick), point.index + 1]
	return _t("on %s") % _said(brick)


func _output_said(brick: int, index: int) -> String:
	var spec: Dictionary = SOURCES[sources[brick]]
	if str(spec["kind"]) == "receiver" and index >= 0 and index < 2:
		return _t("%s output") % _w(str((spec["outputs"] as Array)[index]))
	return _w("lever")


# -- the switches ---------------------------------------------------------------------


## A box's switch's setting, as an index into its [code]switch[/code].
func switch_index(brick: int) -> int:
	var spec: Dictionary = SOURCES.get(sources.get(brick, ""), {})
	var count: int = (spec.get("switch", [[0]]) as Array).size()
	return clampi(int(settings.get(brick, 0)), 0, count - 1)


func lever_index(brick: int, output: int) -> int:
	return clampi(int(settings.get("%d:%d" % [brick, output], 0)), 0, LEVER.size() - 1)


## A hub's port's speed, -1 to 1: full speed until set, so a hub switched
## on runs what is in its ports at once.
func port_speed(brick: int, port: int) -> float:
	return float(settings.get("%d:%d" % [brick, port], 1.0))


## The output of [param brick] (a receiver: 0 red, 1 blue) whose contacts
## are nearest the line from [param origin] along [param way]: the lever a
## click there works. 0 for any other part.
func output_at(brick: int, origin: Vector3, way: Vector3) -> int:
	if not sources.has(brick) or str(SOURCES[sources[brick]]["kind"]) != "receiver":
		return 0
	var best: int = 0
	var nearest: float = INF
	var along: Vector3 = way.normalized()
	for key: String in points:
		var it: Point = points[key]
		if it.brick != brick or it.role != "contacts" or it.top:
			continue
		var off: Vector3 = it.at - origin
		var gap: float = (off - along * off.dot(along)).length()
		if gap < nearest:
			nearest = gap
			best = it.index
	return best


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
			return _t("%s switched %s") % [_said(brick), _w(str((settings_of[switch_index(brick)] as Array)[0]))]
		"receiver", "reverser":
			var key: String = "%d:%d" % [brick, output]
			settings[key] = (lever_index(brick, output) + 1) % LEVER.size()
			return "%s %s: %s" % [_said(brick), _output_said(brick, output),
				_w(str((LEVER[lever_index(brick, output)] as Array)[0]))]
		"hub":
			settings[brick] = not bool(settings.get(brick, false))
			return "%s %s" % [_said(brick), _w("on") if bool(settings[brick]) else _w("off")]
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


## Every source switched on or off ([param setting] "on" or "off"): each
## box, each receiver's two levers and pole reverser's, each hub, its ports
## at full speed when on.
func set_all(setting: String) -> void:
	for brick: int in sources:
		match str(SOURCES[sources[brick]]["kind"]):
			"box", "reverser":
				set_to(brick, setting)
			"receiver":
				set_to(brick, setting, 0)
				set_to(brick, setting, 1)
			"hub":
				set_to(brick, setting)
				if setting == "on":
					var part: String = Wiring.base_part(str(parts.get(brick, "")))
					for port: int in (CONTACTS.get(SAME.get(part, part), []) as Array).size():
						if absf(port_speed(brick, port)) < 1e-6:
							set_to(brick, "1.0", port)


## What [param motor]'s cable reaches switched on where it is off, as a
## person presses Play on a motor wants it run: each box off switched
## forward (on), each receiver's or pole reverser's lever off moved forward
## and what feeds it switched on the same way, each hub off switched on and
## a port at 0% put at full speed. A box switched back stays back. Each
## change said; none for a motor whose cable reaches nothing.
func switch_on_for(motor: int) -> PackedStringArray:
	var said := PackedStringArray()
	_switch_on(_reach("t:%d" % motor), {}, said)
	return said


func _switch_on(reached: Dictionary, asked: Dictionary, said: PackedStringArray) -> void:
	for key: String in reached:
		if asked.has(key):
			continue
		asked[key] = true
		var point: Point = points[key]
		var brick: int = point.brick
		match str(SOURCES[sources[brick]]["kind"]):
			"box":
				if switch_index(brick) == 0:
					set_to(brick, "on")
					said.append(_t("%s switched %s") % [_said(brick), _w(str(((SOURCES[sources[brick]]["switch"]
						as Array)[switch_index(brick)] as Array)[0]))])
			"receiver", "reverser":
				_switch_on(_reach("t:%d" % brick), asked, said)
				if lever_index(brick, point.index) == 0:
					set_to(brick, "forward", point.index)
					said.append("%s %s: %s" % [_said(brick), _output_said(brick, point.index), _w("forward")])
			"hub":
				if not bool(settings.get(brick, false)):
					settings[brick] = true
					said.append("%s %s" % [_said(brick), _w("on")])
				if absf(port_speed(brick, point.index)) < 1e-6:
					set_to(brick, "1.0", point.index)
					said.append(_t("%s's port %d at 100%%") % [_said(brick), point.index + 1])


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
					_w(str(((spec["switch"] as Array)[switch_index(brick)] as Array)[0]))]
				var dial: float = float(settings.get("dial:%d" % brick, 1.0))
				if dial < 1.0:
					said += _t(", its dial at %d%%") % roundi(dial * 100.0)
				out.append(said)
			"receiver":
				var outputs := PackedStringArray()
				for n: int in 2:
					var said: String = "%s %s" % [_output_said(brick, n),
						_w(str((LEVER[lever_index(brick, n)] as Array)[0]))]
					if dial_of(brick, n) < 1.0:
						said += _t(" at %d%%") % roundi(dial_of(brick, n) * 100.0)
					outputs.append(said)
				out.append("%s: %s" % [_said(brick), ", ".join(outputs)])
			"reverser":
				out.append("%s: %s %s" % [_said(brick), _w("lever"),
					_w(str((LEVER[lever_index(brick, 0)] as Array)[0]))])
			"hub":
				out.append("%s: %s" % [_said(brick), _w("on") if bool(settings.get(brick, false)) else _w("off")])
	return out


## Each motor, how it is wired and whether it runs: one line each.
func motor_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for motor: int in motors:
		out.append(motor_line(motor))
	return out


## One motor's line: what its cable reaches and whether it runs.
func motor_line(motor: int) -> String:
	var name: String = _said(motor)
	var head: String = name.left(1).to_upper() + name.substr(1)
	if not has_power():
		return _t("%s: turns by hand, as nothing here gives a motor power.") % head
	var power: Dictionary = power_of(motor)
	if bool(power["by_hand"]):
		return _t("%s: %s.") % [head, str(power["why"])]
	if not bool(power["wired"]):
		return _t("%s: stopped, %s.") % [head, str(power["why"])]
	var run: float = float(power["run"])
	if absf(run) < 1e-6:
		return _t("%s: wired %s; stopped, as %s.") % [head, str(power["words"]), str(power["why"])]
	return _t("%s: wired %s; runs %s at %d%%.") % [head, str(power["words"]),
		_w("forward") if run > 0.0 else _w("back"), roundi(absf(run) * 100.0)]


## Whether the model has anything that gives a motor power: with none, a
## motor turns by hand in Simulate, as it did before cables were read.
func has_power() -> bool:
	return not sources.is_empty()
