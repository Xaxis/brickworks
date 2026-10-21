## A model read as rigid bodies and the joints between them: what moves
## together when a person grabs a part, and about what.
##
## The owner (2026-10-17): grabbing a part grabs "sections of the build": its
## whole rigid body and everything beyond it, a wing with everything built on
## it, a boom with its hook, an arm with its hand and what the hand holds.
##
## The graph is the one the build check, Balance and Sections read, from
## [Joints]' rules, so they cannot drift apart over what holds what:
##   studs: a stud in another part (Joints.studs_in, the lattice saying what
##     it reaches into). Two or more between two parts hold them as one. One
##     alone turns when either part is a single stud across (a 1x1 round
##     plate, a minifigure's head on its neck): builders use it as a
##     turntable. One under a wider part holds, as clutch holds a plate on
##     one stud of a wall.
##   pins and axles (Joints.through): an axle in an axle hole holds; an axle
##     or a pin in a round hole turns on its line, and slides along it as far
##     as the shaft reaches.
##   rounds (Joints.rounds): a clip on a bar, a hinge's pin in its eye, a
##     click hinge's fingers, a turntable's top on its base: turns on the
##     shared line; a clip slides along its bar.
##   balls (Joints.balls): a ball in its socket turns about its middle,
##     every way.
##   glue and one thing in pieces (Joints.held_otherwise): hold.
## Resting on a part with no stud in it holds nothing (Stability.contacts
## counts it as a load path, which it is, but a flap folded down onto the
## body lifts off it). Two joints between the same two bodies on different
## lines hold them as one, as two pins through two beams do (Mechanism's
## rule), repeated until nothing changes.
##
## Each piece of the model that holds together by joints has an anchor: the
## part of it that stays when the rest is moved. A part the person locked
## (Lock parts) anchors its body; else the bodies on the baseplate's studs
## (a stud in one of their sockets); else the biggest body, the one with the
## most parts, unless a body standing on the floor (reaching down to where
## its piece is lowest, not by a tyre) is heavier. A car's chassis stays and
## its wheels turn;
## a crane's base stays and its boom swings. The tree of joints is grown
## out from the anchors, so each other body has the one joint between it and
## the anchor nearest it ([member parent_link]) and everything beyond.
class_name Bodies
extends RefCounted

## A click hinge's step, degrees. Retailers' descriptions of the same
## locking hinges disagree: 9 positions over 180° for 30365, 7 or 9 for
## 30540 (ToyPro's listings, 2026-10-17); nothing the LEGO Group publishes
## says. 9 over 180° is 22.5°, the finer of the two: the hinge stops on
## every click either count has.
const CLICK_STEP := 22.5
## Two joints are on one line when their ways agree to this and each point
## is this close to the other's line, LDU (Mechanism.LINE_SLACK).
const SAME_LINE := 1.5
## Two parts' boxes counted cell by cell for touching only below this many.
const MOST_BOXES := 400
## A part a single stud across: its footprint no wider than this, LDU.
const ONE_STUD := 22.0
## A body stands on the floor when it reaches within this of where its piece
## is lowest, LDU.
const STANDS := 2.0


## One joint between two bodies.
class Link extends RefCounted:
	var a: int = 0
	var b: int = 0
	## hinge (a clip, a hinge's pin), click (a click hinge), turntable, pin
	## (a pin in a round hole), axle (an axle in a round hole), stud (one
	## round stud), ball.
	var kind: String = ""
	var point: Vector3
	## Its line's way; ZERO for a ball, which turns about its middle.
	var axis: Vector3 = Vector3.ZERO
	## Friction holds a pose; false swings down under its own weight when
	## let go (a pin without friction ridges, an axle in a round hole).
	var holds: bool = true
	## Degrees between clicks; 0 turns smoothly.
	var detent: float = 0.0
	## How far the part on the far side may slide along the line, LDU,
	## either way from where it stands: [back, on]; zero for none.
	var slide := Vector2.ZERO
	## A clip's slide as far as its bore's middle stays on its bar, before
	## its rounds are read ([method Bodies._rounds_room]): as far as the
	## two parts' exact shapes may be asked ([method Bodies.exact_room]).
	## Zero for any other slide: an axle's in its hole, which a loop holds
	## to what is on its line ([method Bodies.line_room]), and an engine's
	## piston's, which it does not (its crank holds it).
	var reach := Vector2.ZERO
	## The parts it joins, as [one in a, one in b] pairs.
	var pairs: Array = []
	## Which part of the pair is the shaft (its id) when it slides.
	var shaft_part: int = 0
	## False for a joint that only slides: a linear actuator's rod in its body,
	## a pneumatic cylinder's.
	var turns: bool = true
	## The round it turns in, its radius, LDU: a turntable's disc in its base
	## bears on it ([Swing]'s friction); 0 where the joints do not say.
	var radius: float = 0.0

	func other(body: int) -> int:
		return b if body == a else a

	## "on its hinge", "on its turntable", "on a pin without friction".
	func words() -> String:
		match kind:
			"actuator":
				return "in its linear actuator"
			"cylinder":
				return "in its pneumatic cylinder"
			"housing":
				return "in its rack housing"
			"groove":
				return "on the studs in its groove"
			"rests":
				return "sliding where it rests"
			"click":
				return "on its click hinge"
			"turntable":
				return "on its turntable"
			"pin":
				return "on its pin" if holds else "on a pin without friction"
			"axle":
				return "on its axle"
			"stud":
				return "on its stud"
			"ball":
				return "on its ball joint"
		return "on its hinge"


var world: BrickWorld
var library: PartLibrary
var lattice: BrickLattice
## The baseplate: not a body; what stands on its studs is an anchor.
var scenery: Dictionary = {}
## Parts the person locked: their bodies are anchors.
var locked: Dictionary = {}

## Brick id -> body (the smallest brick id in it).
var body_of: Dictionary = {}
## Body -> PackedInt64Array of brick ids.
var members: Dictionary = {}
## Body -> grams.
var grams: Dictionary = {}
var links: Array[Link] = []
## Body -> Array of its Links.
var touching: Dictionary = {}
## Body -> true for each anchor.
var anchors: Dictionary = {}
## Anchor body -> why it stays, [kind, a part]: "locked" (the part the person
## locked), "studs" (the part on the baseplate's studs), "biggest" (the body
## with the most parts), "floor" (a body standing on the floor, heavier than
## the biggest).
var anchor_why: Dictionary = {}
## Body -> the Link between it and its parent (towards the anchor).
var parent_link: Dictionary = {}
## Body -> its parent body.
var parent_of: Dictionary = {}
## Body -> Array of child bodies.
var children: Dictionary = {}
## Links the tree did not grow along: each closes a loop.
var closing: Array[Link] = []
## Bodies of flexible pieces, a hose's or a chain's (Flex.strung): they
## close no loop, and bend out of what moves (Grab).
var flexible: Dictionary = {}
## The world revision this was read at.
var revision: int = -1
## How long the reading took, ms.
var took_ms: int = 0

## Pairs of parts whose studs only press on the other's face, holding
## nothing: a bush resting on a plate's studs ([method _no_sockets]).
var pressed_on: Dictionary = {}
## Why parts are one body: part -> Array of [the part it was joined to, why],
## each join that made two bodies one, so [method held_words] can say what
## holds a part ("grips", "tyre", "studs:<the part whose studs>", "stuck",
## "pin", "lodged", "lines:<a part>:<the other>").
var joined_by: Dictionary = {}
## Each joint read between two parts that ended in one body: what would
## turn but is held, as [a, b, kind].
var overruled: Array = []
## Every part each axle or pin goes through or grips (Joints.through),
## whatever body it is in: shaft part -> Array of part keys. What is on an
## axle's line besides the axle ([method line_room]).
var on_shaft: Dictionary = {}
var _line_rooms: Dictionary = {}   ## Link -> Vector2

var _up: Dictionary = {}
var _standing: Dictionary = {}   ## brick id -> true: on the baseplate's studs
## Pairs joined by studs the lattice did not see, from their resting.
var _resting: Dictionary = {}


## Read [param from]'s model. Pure but for asking the lattice what a stud
## reaches into.
static func read(from: BrickWorld, parts: PartLibrary, cells: BrickLattice,
		floor_ids: Dictionary = {}, held: Dictionary = {}) -> Bodies:
	var out := Bodies.new()
	out.world = from
	out.library = parts
	out.lattice = cells
	out.scenery = floor_ids
	out.locked = held
	out._read()
	return out


## Whether [param key]'s part has shafts on more than one line: a block
## with pins on two sides, not one pin.
func _pins_on_lines(key: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(key)
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	if mesh == null:
		return false
	var shafts: Array = Joints._lines_of(mesh)[0]
	for line: Array in shafts:
		if not Bodies._same_line(line[1], line[2], shafts[0][1], shafts[0][2]):
			return true
	return false


## Whether a part is a tyre, by its name.
static func _is_tyre(info: PartLibrary.PartInfo) -> bool:
	if info == null:
		return false
	var name: String = info.name.to_lower() + " "
	return name.contains("tyre") or name.contains("tire ")


func _find(key: int) -> int:
	var at: int = key
	while int(_up.get(at, at)) != at:
		at = int(_up.get(at, at))
	if at != key:
		_up[key] = at
	return at


## Join two parts' bodies, and keep [param why] they are one ([member joined_by]).
func _join(one: int, other: int, why: String = "") -> bool:
	var a: int = _find(one)
	var b: int = _find(other)
	if a == b:
		return false
	if a < b:
		_up[b] = a
	else:
		_up[a] = b
	for ends: Array in [[one, other], [other, one]]:
		if not joined_by.has(ends[0]):
			joined_by[ends[0]] = []
		(joined_by[ends[0]] as Array).append([ends[1], why])
	return true


func _read() -> void:
	var started: int = Time.get_ticks_msec()
	revision = world.revision
	var entries: Array = []
	var floor_entries: Array = []
	var info_of: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var entry: Array = [brick.id, brick.transform, mesh, brick.part_id, Assemblies.path_of(brick)]
		if scenery.has(brick.id):
			floor_entries.append(entry)
			continue
		entries.append(entry)
		_up[brick.id] = brick.id
		info_of[brick.id] = library.parts.get(brick.part_id)
	var candidates: Array = []   ## [part a, part b, kind, point, axis, holds, detent, slide, shaft]

	# Linear actuators and pneumatic cylinders: the rod slides in its body
	# along their axis as far as the library draws it out and in, and does not
	# turn there. Nothing else joins the two.
	var acting: Dictionary = {}   ## Vector2i pair -> true
	for c: Array in _actuators(entries) + _rack_housings(entries):
		candidates.append(c)
		acting[Vector2i(mini(int(c[0]), int(c[1])), maxi(int(c[0]), int(c[1])))] = true
	# A screw's input turns in its body and is held there: it does not slide.
	var inputs: Dictionary = {}   ## input part -> its actuator's body part
	var actuator_table: Dictionary = Mechanism.table().get("actuators", {})
	for body_part: String in actuator_table:
		if (actuator_table[body_part] as Dictionary).has("input"):
			inputs[str(actuator_table[body_part]["input"])] = body_part
	var part_of: Dictionary = {}
	for entry: Array in entries:
		part_of[int(entry[0])] = Mechanism.reads_as(str(entry[3]))

	# Pins and axles.
	var shaft_lines: Dictionary = {}
	var pin_rows: Dictionary = {}   ## pin -> the parts it is in
	for one: Array in Joints.through(entries):
		var a: int = int(one[0])
		var b: int = int(one[1])
		if not on_shaft.has(a):
			on_shaft[a] = []
		(on_shaft[a] as Array).append(b)
		if acting.has(Vector2i(mini(a, b), maxi(a, b))):
			continue
		if str(one[2]) == "grips":
			_join(a, b, "grips:%d" % a)
			continue
		var shaft_info: PartLibrary.PartInfo = info_of.get(a)
		var shaft_name: String = shaft_info.name if shaft_info != null else ""
		var is_pin: bool = shaft_name.to_lower().contains("pin")
		var holds: bool = is_pin and _has_friction(shaft_name)
		# How far the hole may run along the shaft before it comes off it.
		# A pin is held by its collar; an axle slides in a round hole.
		var along: float = float(one[7])
		var slide := Vector2.ZERO if is_pin \
			else Vector2(maxf(along - float(one[5]), 0.0), maxf(float(one[6]) - along, 0.0))
		if slide != Vector2.ZERO:
			var room: Vector2 = _rounds_room(a, b, one[3], one[4])
			slide = Vector2(minf(slide.x, room.x), minf(slide.y, room.y))
		if str(inputs.get(part_of.get(a, ""), "-")) == str(part_of.get(b, "")) \
				or str(inputs.get(part_of.get(b, ""), "-")) == str(part_of.get(a, "")):
			# An actuator's input: held in its body, its screw holding it.
			slide = Vector2.ZERO
			holds = true
		candidates.append([a, b, "pin" if is_pin else "axle", one[3], one[4], holds, 0.0,
			slide, a])
		if is_pin:
			if not pin_rows.has(a):
				pin_rows[a] = []
			(pin_rows[a] as Array).append(b)
		shaft_lines[Vector2i(mini(a, b), maxi(a, b))] = true

	# Rounds: clips, hinges, turntables.
	var rounds: Dictionary = Joints.rounds(entries)
	var done: Dictionary = {}
	for one: Variant in rounds:
		for other: Variant in rounds[one]:
			var a: int = int(one)
			var b: int = int(other)
			var pair := Vector2i(mini(a, b), maxi(a, b))
			if done.has(pair) or shaft_lines.has(pair) or acting.has(pair):
				continue
			done[pair] = true
			var zones: Array = rounds[one][other]
			if zones.is_empty():
				continue
			var zone: Array = zones[0]
			# A round steering rack (2790a) is loose in its holder (a rod 20
			# across in a bore 22 to 26 across), and its pinion pushes it
			# along: as the arms at its ends swing, the rod goes a little
			# aside. Held to the holder's line, 8022-1's steering closed to a
			# hundredth at 5 degrees and not at 20.
			if _rides_loose(a, b, part_of, zone):
				continue
			var kind: String = "hinge"
			var detent: float = 0.0
			var holds: bool = true
			var names: String = ""
			for key: int in [a, b]:
				var info: PartLibrary.PartInfo = info_of.get(key)
				if info != null:
					names += info.name.to_lower() + " "
			if _clicks(library.mesh_for(world.get_brick(a).part_id)) \
					or _clicks(library.mesh_for(world.get_brick(b).part_id)):
				kind = "click"
				detent = CLICK_STEP
			elif names.contains("turntable"):
				kind = "turntable"
				holds = false
			# A tyre is held on its wheel: it does not turn on the rim.
			if _is_tyre(info_of.get(a)) or _is_tyre(info_of.get(b)):
				_join(a, b, "tyre")
				continue
			# A clip, or a minifigure's hand, slides along the bar it holds;
			# a hinge's pin and a head on its neck do not.
			var slide_and_shaft: Array = [Vector2.ZERO, 0]
			if names.contains("clip") or names.contains("minifig hand"):
				slide_and_shaft = _slide_on(a, b, zone)
			elif names.contains("piston"):
				# An engine's piston slides up and down its cylinder, and nothing
				# holds it there: its crank does (2851 in 2850a).
				slide_and_shaft = _slide_within(a, b, zone)
				holds = false
			candidates.append([a, b, kind, zone[0], (zone[1] as Vector3).normalized(), holds,
				detent, slide_and_shaft[0], slide_and_shaft[1], float(zone[4]) if zone.size() > 4 else 0.0,
				slide_and_shaft[2] if slide_and_shaft.size() > 2 else Vector2.ZERO])

	_cross_in_forks(entries, info_of, rounds, candidates)

	# Balls.
	var balls: Dictionary = Joints.balls(entries)
	var seen_balls: Dictionary = {}
	for one: Variant in balls:
		for other: Variant in balls[one]:
			var a: int = int(one)
			var b: int = int(other)
			var pair := Vector2i(mini(a, b), maxi(a, b))
			if seen_balls.has(pair):
				continue
			seen_balls[pair] = true
			candidates.append([a, b, "ball", _ball_middle(a, b), Vector3.ZERO, true, 0.0,
				Vector2.ZERO, 0])
	# A ball held between another part's two bores is in a socket the
	# connectors do not name: an engine's connecting rod's ball end snapped
	# into its piston (2852 in 2851). It turns every way, freely: the crank
	# holds the piston, not the joint. The piston has no socket connector,
	# and the rod hung loose from its crank.
	var boxes: Array[AABB] = []
	for entry: Array in entries:
		var mesh: Lbm.PartMesh = entry[2]
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "ball":
				continue
			if boxes.is_empty():
				for other: Array in entries:
					boxes.append(((other[1] as Transform3D) * (other[2] as Lbm.PartMesh).bounds).grow(1.0))
			var middle: Vector3 = (entry[1] as Transform3D) * connector.position
			for n: int in entries.size():
				var other: Array = entries[n]
				if int(other[0]) == int(entry[0]) or not boxes[n].has_point(middle):
					continue
				var pair := Vector2i(mini(int(entry[0]), int(other[0])), maxi(int(entry[0]), int(other[0])))
				if seen_balls.has(pair):
					continue
				var line: Vector3 = Bodies._bores_across(other[1], other[2], middle)
				if line == Vector3.ZERO:
					continue
				seen_balls[pair] = true
				candidates.append([int(entry[0]), int(other[0]), "ball", middle, Vector3.ZERO, false,
					0.0, Vector2.ZERO, 0])

	# Studs: two or more between two parts hold them; one alone turns when
	# either is a single stud across.
	var per_pair: Dictionary = {}   ## Vector2i -> Array of [point, way]
	# The baseplate's studs too: a part with one in a socket stands on the
	# floor (below). A tip is in the first part but its own whose cover has
	# its cell, as Stability.stud_joints reads it: where two covers overlap
	# the cell is in both, and the stud's own part named first had it in
	# nothing.
	var studs: Array = Joints.studs_in(entries + floor_entries, func(tip: Vector3, key: Variant) -> Variant:
		for there: int in lattice.bricks_at(BrickLattice.to_cell(tip), int(key)):
			if _up.has(there) or scenery.has(there):
				return there
		return null)
	# Which parts turn against which: a stud reaching into one of them may be
	# in the other, the two sharing cells round their joint.
	var partners: Dictionary = {}   ## id -> Array of ids it turns against
	for c: Array in candidates:
		for ends: Array in [[int(c[0]), int(c[1])], [int(c[1]), int(c[0])]]:
			if not partners.has(ends[0]):
				partners[ends[0]] = []
			(partners[ends[0]] as Array).append(ends[1])
	var stud_of: Dictionary = {}   ## pair -> the part whose studs they are
	var askew: Dictionary = {}   ## pair -> its studs into a part askew to them, in no socket or hole
	var pressed: Dictionary = {}   ## pair -> its studs against a part with no socket, in no hole of it
	pressed_on.clear()
	for stud: Array in studs:
		var a: int = int(stud[0])
		var b: int = int(stud[1])
		if partners.has(b):
			b = _sits_on(stud[2], stud[3], [b] + (partners[b] as Array))
		if scenery.has(a) or scenery.has(b):
			# On the baseplate's studs: a stud in one of its sockets, not a
			# tyre the plate's studs touch. A tyre is rubber with no socket,
			# whatever gaps its tread has: 58090's file leaves four that read
			# as sockets, and a session's kart, its steering turned 30
			# degrees, had a front tyre's gap come over a stud. Its front
			# axle became what stays, and the turn back swung the chassis.
			var on: int = b if scenery.has(a) else a
			if not scenery.has(on) and not _is_tyre(info_of.get(on)) and _in_a_socket(on, stud[2]):
				_standing[on] = true
			continue
		if not _up.has(a) or not _up.has(b):
			continue
		# A tyre is rubber with no socket: a stud pressed against its tread
		# holds nothing. Held on its wheel (above), 8054-1's steering wheel,
		# a rim with its tyre, read as held by the two dash studs its tyre
		# touches, and its column was locked to the chassis.
		if _is_tyre(info_of.get(a)) or _is_tyre(info_of.get(b)):
			continue
		var pair := Vector2i(mini(a, b), maxi(a, b))
		# The lattice covers a part turned off the grid with every cell its
		# boxes' turned corners span: a stud reaches into it only within its
		# own box. 8448-1's steering column, an axle 8 tilted two ways, had
		# a wing brick's stud 13 LDU below it in its cover, read as holding
		# it there, and the column was one with the chassis.
		if _askew(a, b) and not _reaches_into(b, stud[2], stud[3]):
			continue
		if _askew(a, b) and not _takes_stud(b, stud[2], stud[3]):
			askew[pair] = int(askew.get(pair, 0)) + 1
		# A part with nothing underneath to take a stud (a bush, a gear, a
		# beam: no socket) takes one only in a hole; a stud against its face
		# holds nothing. A session's kart had a bush on its steering column
		# sitting on the deck's studs, read as held by them, and the column
		# was locked to the chassis.
		if _no_sockets(b) and not _takes_stud(b, stud[2], stud[3]):
			pressed[pair] = int(pressed.get(pair, 0)) + 1
		if not per_pair.has(pair):
			per_pair[pair] = []
			stud_of[pair] = a
		(per_pair[pair] as Array).append([stud[2], stud[3]])
	# Two parts turned askew to each other hold by studs only where they go
	# into sockets or holes: one stud alone is a round joint, as any lone
	# stud is, but more than one cannot all be in a part turned off their
	# grid, and are read so only off the boxes the lattice covers a turned
	# part with. A session turned a steering column 30 degrees, the four
	# studs of the Technic plate under its 24 tooth gear no longer met the
	# gear's holes, and the next reading locked the column, both kingpins
	# and their gears to the chassis: the column would not turn back. A
	# section built at an angle is square to itself and held as it was, and
	# a half pin's stud in a turned part (42081-1's arm) is one stud.
	for pair: Vector2i in askew:
		if int(askew[pair]) >= 2 and int(askew[pair]) == (per_pair[pair] as Array).size():
			per_pair.erase(pair)
	for pair: Vector2i in pressed:
		if per_pair.has(pair) and int(pressed[pair]) == (per_pair[pair] as Array).size():
			per_pair.erase(pair)
			pressed_on[pair] = true
	var turning: Dictionary = {}
	for c: Array in candidates:
		turning[Vector2i(mini(int(c[0]), int(c[1])), maxi(int(c[0]), int(c[1])))] = true
	# What rests on a joint's half with that half's studs under its foot is
	# carried by it, where the lattice's cover of the part above is hollow at
	# the studs' tips: 4096's hinge brick 3937 on its turntable's top read as
	# resting on nothing, and the turntable carried none of the crane. Only
	# on a joint's half: a boom laid down on two cones' studs rests there,
	# and reading every such rest as studs (Stability.contacts) clicked it
	# down and locked the turntable under it, at 4 s for 1,300 parts.
	for low: Variant in partners:
		var a: int = int(low)
		if not _up.has(a):
			continue
		var lid: PackedInt32Array = BrickLattice.moved_by(lattice.boxes_of(a), Vector3i(0, 1, 0))
		if lid.is_empty():
			continue
		for other: int in lattice.near_bounds(lid, a):
			var pair := Vector2i(mini(a, other), maxi(a, other))
			if per_pair.has(pair) or turning.has(pair) or not _up.has(other):
				continue
			# Touching, cell by cell, but not for two turned parts of hundreds
			# of boxes each: counted box by box that took 30 s at 1,300 parts.
			var theirs: PackedInt32Array = lattice.boxes_of(other)
			if lid.size() + theirs.size() < MOST_BOXES * 6 \
					and BrickLattice.shared_cells(lid, theirs) <= 0:
				continue
			var under: Array = _studs_under(a, other)
			# Pressed on a face with nothing to take them, as above.
			if not under.is_empty() and _no_sockets(other):
				under = under.filter(func(stud: Array) -> bool:
					return _takes_stud(other, stud[0], stud[1]))
				if under.is_empty():
					pressed_on[pair] = true
			if not under.is_empty():
				per_pair[pair] = under
				stud_of[pair] = a
				_resting[pair] = true
	# A turntable's top on its base, a hinge brick's halves, a click hinge's
	# two parts: the joint between them is what holds them, whatever studs
	# or cells they also share.
	var in_grooves: Dictionary = _grooves_by_shape(entries, turning)
	for pair: Vector2i in in_grooves:
		candidates.append(in_grooves[pair])
	for pair: Vector2i in per_pair:
		var found: Array = per_pair[pair]
		if turning.has(pair) or in_grooves.has(pair):
			continue
		var groove: Array = _in_a_groove(pair, int(stud_of.get(pair, pair.x)), found)
		if not groove.is_empty():
			candidates.append(groove)
			continue
		if found.size() == 1 and (_one_stud(info_of.get(pair.x)) or _one_stud(info_of.get(pair.y))):
			candidates.append([pair.x, pair.y, "stud", found[0][0], found[0][1], true, 0.0,
				Vector2.ZERO, 0])
		else:
			_join(pair.x, pair.y, "studs:%d" % int(stud_of.get(pair, pair.x)))

	# Glue, magnets, one thing in pieces.
	var stuck: Dictionary = Joints.held_otherwise(entries, library)
	for one: Variant in stuck:
		for other: Variant in stuck[one]:
			if _up.has(int(one)) and _up.has(int(other)):
				_join(int(one), int(other), "stuck")

	# A piece nothing holds where it is, lodged in another, is held by what
	# it is lodged in: an axle in a pin's stop bush, a log in a gripper's
	# claws ([method _lodge]).
	_lodge(entries, candidates)
	# A pin keyed to nothing is part of the first thing it is in, and what
	# else it is in turns against that on its line (Mechanism's rule): a
	# beam pinned to a frame turns on the frame, the pin with the frame.
	var sizes: Dictionary = {}
	for entry: Array in entries:
		var root: int = _find(int(entry[0]))
		sizes[root] = int(sizes.get(root, 0)) + 1
	# Which pins are keyed to nothing is read before any is joined: asked as
	# each was joined, a pin in a piece whose root the joining had just
	# changed was not found among the sizes and was taken for one alone.
	# 42080-1's rod eye held by an axle pin keyed into its boom was joined to
	# that pin's piece, and its pneumatic cylinder could not slide.
	# A part with pins on more than one line (a cross block with four pins,
	# 48989) is not a pin: held on two lines it is held, and on one it turns.
	# Joined to the first thing it was in, 42050-1's two such blocks made
	# its steering rack one with the beams its pinion turns in.
	var lone: Array = []
	for pin: int in pin_rows:
		if int(sizes.get(_find(pin), 1)) == 1 and not _pins_on_lines(pin):
			lone.append(pin)
	for pin: int in lone:
		_join(pin, int((pin_rows[pin] as Array)[0]), "pin")
	# Two joints between the same two bodies on different lines hold them.
	var changed: bool = true
	while changed:
		changed = false
		var by_pair: Dictionary = {}
		for c: Array in candidates:
			var x: int = _find(int(c[0]))
			var y: int = _find(int(c[1]))
			# A rack's housing or the studs in its groove guide it along its
			# line: what else joins the two rides in the housing's slot (an
			# axle through 18940's), and does not hold the rack with them.
			if x == y or str(c[2]) in GUIDES:
				continue
			var pair := Vector2i(mini(x, y), maxi(x, y))
			if not by_pair.has(pair):
				by_pair[pair] = []
			(by_pair[pair] as Array).append(c)
		for pair: Vector2i in by_pair:
			var found: Array = by_pair[pair]
			var first: Array = found[0]
			for c: Array in found:
				if not _one_line(first, c):
					changed = _join(int(first[0]), int(first[1]),
						"lines:%d:%d" % [int(c[0]), int(c[1])]) or changed
					break

	_rest_racks(entries, candidates)

	overruled.clear()
	for c: Array in candidates:
		if _find(int(c[0])) == _find(int(c[1])) and str(c[2]) != "stud":
			overruled.append([int(c[0]), int(c[1]), str(c[2])])

	members.clear()
	body_of.clear()
	var lists: Dictionary = {}   ## body -> Array of keys (a packed array is copied by value)
	for entry: Array in entries:
		var key: int = int(entry[0])
		var body: int = _find(key)
		body_of[key] = body
		if not lists.has(body):
			lists[body] = []
		(lists[body] as Array).append(key)
		var info: PartLibrary.PartInfo = info_of.get(key)
		grams[body] = float(grams.get(body, 0.0)) + (Stability.grams(info) if info != null else 0.0)
	for body: int in lists:
		members[body] = PackedInt64Array(lists[body])

	# One link per pair of bodies, with every pair of parts it joins.
	var made: Dictionary = {}
	for c: Array in candidates:
		var x: int = _find(int(c[0]))
		var y: int = _find(int(c[1]))
		if x == y:
			continue
		var pair := Vector2i(mini(x, y), maxi(x, y))
		var link: Link = made.get(pair)
		if link == null:
			link = Link.new()
			link.a = x
			link.b = y
			link.kind = c[2]
			link.point = c[3]
			link.axis = c[4]
			link.holds = c[5]
			link.detent = c[6]
			link.slide = c[7]
			link.shaft_part = c[8]
			link.turns = not (str(c[2]) in ["actuator", "cylinder"] or str(c[2]) in GUIDES)
			link.radius = float(c[9]) if c.size() > 9 else 0.0
			link.reach = c[10] if c.size() > 10 else Vector2.ZERO
			made[pair] = link
			links.append(link)
			for end: int in [x, y]:
				if not touching.has(end):
					touching[end] = []
				(touching[end] as Array).append(link)
		elif str(c[2]) in GUIDES or link.kind in GUIDES:
			# A rack guided along its line by its housing or its groove moves
			# as they let it, whatever else joins the two.
			if str(c[2]) in GUIDES and not (link.kind in GUIDES):
				link.kind = c[2]
				link.point = c[3]
				link.axis = c[4]
				link.slide = c[7]
				link.shaft_part = c[8]
				link.turns = false
		else:
			# Two along one line: the tighter fit says how far it slides, and
			# friction anywhere holds it.
			link.holds = link.holds or bool(c[5])
			link.slide = Vector2(minf(link.slide.x, (c[7] as Vector2).x),
				minf(link.slide.y, (c[7] as Vector2).y))
			if link.detent == 0.0:
				link.detent = c[6]
		link.pairs.append([int(c[0]), int(c[1])])
	_anchor_and_grow()
	took_ms = Time.get_ticks_msec() - started


## Each piece of the model that nothing holds where it is (no part of it
## on the baseplate's studs, none locked) and that is lodged in another
## piece (a part of it shares cells with a part of the other) is held by
## what it is lodged in: its part joined to the part whose box its own is
## most into. A piece of one part is an axle in a pin's stop bush or in an axle
## joiner, whose axle holes the connectors do not name on the part's own
## line (32054, 26287), or a gear a model file carries as a part of its own
## ("42080 - 18575") on its axle; a bigger one, a log held up in a
## gripper's claws. Read as pieces of their own, they stayed where they
## stood while what held them moved: 42080-1's arm left an axle 3, an axle
## 5, a joiner, its saw's drive gear and the log in its gripper in the air.
## Not the biggest piece, nor one of more than [constant LODGE_MOST] parts:
## the model is not held by what it holds. [param candidates] as [method
## _read] gathers joints. How many were joined is [member lodged].
func _lodge(entries: Array, candidates: Array) -> void:
	lodged = 0
	var up: Dictionary = {}   ## body root -> its piece, a union-find of its own
	for entry: Array in entries:
		var root: int = _find(int(entry[0]))
		up[root] = root
	for c: Array in candidates:
		if up.has(_find(int(c[0]))) and up.has(_find(int(c[1]))):
			Bodies._piece_join(up, _find(int(c[0])), _find(int(c[1])))
	var parts_of_piece: Dictionary = {}   ## piece -> Array of part keys
	var held: Dictionary = {}
	for entry: Array in entries:
		var key: int = int(entry[0])
		var piece: int = Bodies._piece_find(up, _find(key))
		if not parts_of_piece.has(piece):
			parts_of_piece[piece] = []
		(parts_of_piece[piece] as Array).append(key)
		if _standing.has(key) or locked.has(key):
			held[piece] = true
	var biggest: int = -1
	for piece: int in parts_of_piece:
		if biggest < 0 or (parts_of_piece[piece] as Array).size() > (parts_of_piece[biggest] as Array).size():
			biggest = piece
	# Each piece's biggest body, what stays as the anchor is chosen: a door
	# hangs on that, never on a part that moves.
	var staying: Dictionary = {}   ## piece -> the root of its biggest body
	for piece: int in parts_of_piece:
		var count: Dictionary = {}
		for key: int in parts_of_piece[piece]:
			var root: int = _find(key)
			count[root] = int(count.get(root, 0)) + 1
			if not staying.has(piece) or int(count[root]) > int(count[staying[piece]]):
				staying[piece] = root
	var bending: Dictionary = {}   ## part -> true: a hose, a string, a chain
	var world_box: Dictionary = {}   ## part -> its box where it stands
	for entry: Array in entries:
		world_box[int(entry[0])] = (entry[1] as Transform3D) * (entry[2] as Lbm.PartMesh).bounds
		if Bodies.bends(library, str(entry[3])):
			bending[int(entry[0])] = true
			held[Bodies._piece_find(up, _find(int(entry[0])))] = true
	for piece: int in parts_of_piece:
		var keys: Array = parts_of_piece[piece]
		# A piece with a hose, a string or a chain in it hangs on it: 42042-1's
		# hook block on its winch's string, joined to the drum the string's end
		# was lodged in, went round with the drum.
		if piece == biggest or held.has(piece) or keys.size() > LODGE_MOST:
			continue
		var best: int = 0
		var most: float = -1.0
		var from: int = 0
		var also: Array = []   ## more parts the lone one stands in round holes of
		for key: int in keys:
			var boxes: PackedInt32Array = lattice.boxes_of(key)
			if boxes.is_empty():
				continue
			for other: int in lattice.blockers_boxes(boxes, key, {}):
				if not _up.has(other) or bending.has(other) \
						or Bodies._piece_find(up, _find(other)) == Bodies._piece_find(up, _find(key)):
					continue
				# How far into each other their boxes are, the room they share:
				# counting their shared cells cost 42081-1's reading 5 s.
				var shared: float = (world_box[key] as AABB).intersection(world_box[other]).get_volume()
				if shared > most or (is_equal_approx(shared, most) and other < best):
					most = shared
					best = other
					from = key
		if best == 0 and keys.size() == 1:
			# A part held by nothing that shares no cell with anything, where
			# it or what it is in has no exact shape to read joints from (a
			# file's own part, an obsolete one), is in something whose cover is
			# hollow where it is: a belt wheel on the axle through its hole, the
			# half pin in that wheel, a magnet in its coupling. It is held by
			# what goes through its middle, else by what its box is most into
			# (G13): left behind, 8074-1's belt wheel stopped its crane's turn at
			# once, its axle tested along the way through it. Two parts with
			# exact shapes are not (lodged so, 42042-1's winch was read into a
			# loop of 63 joints), but where the one stands in a round hole of
			# the other that names no joint ([method _in_a_bore]).
			var lone: int = int(keys[0])
			var lone_cells: PackedInt32Array = lattice.boxes_of(lone)
			var middle: Vector3 = (world_box[lone] as AABB).get_center()
			var through: bool = false
			var sharing: Array = []
			if not lone_cells.is_empty():
				for other: int in lattice.near_bounds(lone_cells, lone):
					if not _up.has(other) or bending.has(other) or not world_box.has(other):
						continue
					var shared: float = (world_box[lone] as AABB).intersection(world_box[other]).get_volume()
					if shared <= 0.0:
						continue
					sharing.append(other)
					var its_middle: bool = (world_box[other] as AABB).grow(0.5).has_point(middle)
					if (its_middle and not through) or (its_middle == through and shared > most):
						through = its_middle
						most = shared
						best = other
						from = lone
			if best != 0 and not _unknown_shape(lone) and not _unknown_shape(best) \
					and not (_door(lone) and _stays(best, up, staying)
						and not _labelled_hinge(lone, best).is_empty()) \
					and not _in_a_bore(lone, best):
				best = 0
			# Standing in round holes of more parts than one, it holds them
			# together: 8808-1's side panel, a Technic plate whose end holes
			# are on two headlight bricks' side studs, each brick on one stud.
			# Lodged in the one alone, that brick and the panel turned on its
			# stud, and a finger on the panel beside the steering wheel took
			# it for a part that moves, not the wheel.
			if best != 0 and not _unknown_shape(lone):
				for other: int in sharing:
					if other != best and not _unknown_shape(other) and _in_a_bore(lone, other):
						also.append(other)
		if best == 0:
			continue
		var into: int = Bodies._piece_find(up, _find(best))
		# A rack a pinion of another piece stands in is held by the pinion's
		# teeth, and slides as they push it, on what it rests on: 6753-1's
		# tow truck has its rack under a Technic brick lying on a tile, and
		# lodged in the tile the rack was held with the frame.
		var driven: Array = _driven_rack(keys, piece, up)
		if not driven.is_empty():
			var rack: int = int(driven[0])
			var rack_at: Transform3D = world.get_brick(rack).transform
			var spec: Dictionary = Racks.spec_of(world.get_brick(rack).part_id)
			var reach: float = absf(float(spec.get("to", 20.0)) - float(spec.get("from", -20.0))) * 0.5
			candidates.append([best, rack, "rests", rack_at.origin, (rack_at.basis * Vector3.RIGHT).normalized(),
				true, 0.0, Vector2(reach, reach), rack])
			Bodies._piece_join(up, piece, into)
			continue
		# And a pinion standing in another piece's rack turns on its own axis
		# where it is lodged: 41999-1's steering pinion, on an axle through
		# the big ball joint's socket that no hole names, was lodged in the
		# socket and held its rack and the whole front axle still.
		var driving: Array = _driving_pinion(keys, piece, up)
		if not driving.is_empty():
			var mesh: Racks.Pinion = driving[0]
			candidates.append([best, mesh.gear, "axle", mesh.centre, mesh.axis, true, 0.0,
				Vector2.ZERO, mesh.gear])
			Bodies._piece_join(up, piece, into)
			continue
		# A door held by nothing, lodged in a part that BrickNet's labels name
		# a hinge with, hangs on that hinge ([method _labelled_hinge]): 3180-1's
		# cupboard door (4533), whose pins the file draws as rounds of one size
		# end to end with the cupboard's (4532), which no round reads as in a
		# bore, was held by nothing and did not swing. Only a door, a hatch
		# or a lid (Playable.door_named), and only on what it is lodged in:
		# read for any part, 6765-1's carriage tongue was hinged to its
		# turntable's base and the turntable's turn moved the carriage; read
		# for every pair, 9397-1's universal joint gained its second hinge
		# and its steering's loop 44 joints, too many to solve; read for a
		# door on any part, 10264-1's roller door, once its spool had
		# turned, hung on the spool. And only on the piece's biggest body,
		# what stays: hung on a clip of 21319-1's camera boom, its door
		# swung with the boom into the frame.
		if keys.size() == 1 and _door(from) and _stays(best, up, staying):
			var hinge: Array = _labelled_hinge(from, best)
			if not hinge.is_empty():
				candidates.append([best, from, "hinge", hinge[0], hinge[1], true, 0.0, Vector2.ZERO, 0])
				Bodies._piece_join(up, piece, into)
				continue
		var holders: Array = [into]
		for other: int in also:
			holders.append(Bodies._piece_find(up, _find(other)))
		_join(from, best, "lodged")
		for other: int in also:
			_join(from, other, "lodged")
		lodged_in[from] = best
		var root: int = _find(from)
		if not up.has(root):
			up[root] = root
		for holder: int in holders:
			Bodies._piece_join(up, root, holder)
		Bodies._piece_join(up, root, piece)
		lodged += 1


## Whether a shaft or a stud of [param lone]'s part runs in a round hole of
## [param key]'s part that no pin or axle hole names (a bore, Lbm): on its
## line and into it, a stud as far as Joints.STUD_REACH. 8074-1's half pins
## stand so by their studs in their belt wheels' rims, cranks for the winch
## strings; neither the wheel's connectors nor BrickNet's shape name those
## holes. Read as 4185a since the file's copies of it are read as the
## part (CustomParts.read_as_copy), the half pins were held by nothing and
## stayed where they were as the crane turned, so its turntable stopped at
## once.
func _in_a_bore(lone: int, key: int) -> bool:
	var inner: BrickWorld.Brick = world.get_brick(lone)
	var outer: BrickWorld.Brick = world.get_brick(key)
	var shafts: Lbm.PartMesh = library.mesh_for(inner.part_id) if inner != null else null
	var holes: Lbm.PartMesh = library.mesh_for(outer.part_id) if outer != null else null
	if shafts == null or holes == null:
		return false
	for hole: Lbm.Connector in holes.connectors:
		if hole.kind != "bore" or hole.length <= 0.0:
			continue
		var at: Vector3 = outer.transform * hole.position
		var way: Vector3 = (outer.transform.basis * hole.axis).normalized()
		for shaft: Lbm.Connector in shafts.connectors:
			var reach: float = shaft.length if shaft.kind == "shaft" else (
				Joints.STUD_REACH if shaft.kind == "stud" else 0.0)
			if reach <= 0.0:
				continue
			var from: Vector3 = inner.transform * shaft.position
			var along: Vector3 = (inner.transform.basis * shaft.axis).normalized()
			if absf(along.dot(way)) < 0.99:
				continue
			var gap: Vector3 = from - at
			if (gap - way * gap.dot(way)).length() > 2.0:
				continue
			# Where the shaft runs on the hole's line, against where the hole does.
			var one: float = gap.dot(way)
			var other: float = one + reach * along.dot(way)
			if minf(maxf(one, other), hole.length) - maxf(minf(one, other), 0.0) > 1.0:
				return true
	return false


## A rack a pinion of another body stands in slides along its line on what
## it rests on, where its own joints do not guide it: hung on balls alone (a
## track rod's at each end), it rolls about its line and swings off it, and
## a steering's turn went into that and not its arms (42125-1, its file's
## own copies of the track rods read as the parts: the rack 10 LDU for 30°,
## the arms 1°). [method _lodge] lays the same joint for a rack nothing
## holds; this one is held, by balls. Added to [param candidates].
func _rest_racks(entries: Array, candidates: Array) -> void:
	var near: Array = []
	var box_of: Dictionary = {}
	for entry: Array in entries:
		var id: String = str(entry[3])
		if Racks.is_rack(id) or int(Mechanism.spec_of(id).get("teeth", 0)) > 0:
			near.append([int(entry[0]), id, entry[1]])
	if near.is_empty():
		return
	var done: Dictionary = {}
	for mesh: Racks.Pinion in Racks.find(near):
		var body: int = _find(mesh.rack)
		if mesh.screw or done.has(mesh.rack) or body == _find(mesh.gear):
			continue
		done[mesh.rack] = true
		var joined: Dictionary = {body: true, _find(mesh.gear): true}
		var balls: int = 0
		var other_joints: int = 0
		for c: Array in candidates:
			var x: int = _find(int(c[0]))
			var y: int = _find(int(c[1]))
			if x == y or (x != body and y != body):
				continue
			if str(c[2]) == "ball":
				balls += 1
				joined[x if y == body else y] = true
			else:
				other_joints += 1
		if balls == 0 or other_joints > 0:
			continue
		if box_of.is_empty():
			for entry: Array in entries:
				box_of[int(entry[0])] = (entry[1] as Transform3D) * (entry[2] as Lbm.PartMesh).bounds
		# On the part its box is most into of those that share its cells, not
		# what its balls join it to, nor its pinion's body.
		var boxes: PackedInt32Array = lattice.boxes_of(mesh.rack)
		var best: int = 0
		var most: float = -1.0
		for other: int in (lattice.blockers_boxes(boxes, mesh.rack, {}) if not boxes.is_empty() else []):
			if not _up.has(other) or joined.has(_find(other)) or not box_of.has(other) \
					or Bodies.bends(library, world.get_brick(other).part_id):
				continue
			var shared: float = (box_of[mesh.rack] as AABB).intersection(box_of[other]).get_volume()
			if shared > most or (is_equal_approx(shared, most) and other < best):
				most = shared
				best = other
		if best == 0:
			continue
		var rack_at: Transform3D = world.get_brick(mesh.rack).transform
		var spec: Dictionary = Racks.spec_of(world.get_brick(mesh.rack).part_id)
		var reach: float = absf(float(spec.get("to", 20.0)) - float(spec.get("from", -20.0))) * 0.5
		candidates.append([best, mesh.rack, "rests", rack_at.origin, (rack_at.basis * Vector3.RIGHT).normalized(),
			true, 0.0, Vector2(reach, reach), mesh.rack])


## A universal joint's centre in an end's fork is pinned there on the fork's
## line, where a file has turned the centre off it: 42125-1 draws both its
## steering column's centres a quarter turn round from their ends' forks,
## each pinned in one end only. The other end turned free of it, the cardan
## shaft between was held by nothing and lodged where its box was most into
## something, a beam beside it, or, once the column had turned, the column:
## turned back, the shaft swung round with it into the frame. Added to
## [param candidates] for each end [param rounds] (Joints.rounds) does not
## join to its centre. The 4L joint's too (3326b in 3712s): 8448-1's file
## turns its column, a 4L joint at each end, 28 degrees round its own line,
## so each centre fits the column's forks and not the other end's; turned
## 30 degrees, the steering's pinion end took the column's centre, and the
## column, hung on nothing else, swung with it into the chassis, or held
## it, "Locked".
func _cross_in_forks(entries: Array, info_of: Dictionary, rounds: Dictionary, candidates: Array) -> void:
	var centres: Array = []
	var ends: Array = []
	for entry: Array in entries:
		var info: PartLibrary.PartInfo = info_of.get(int(entry[0]))
		var name: String = info.name if info != null else ""
		if not name.contains("Universal Joint") or name.contains("Complete"):
			continue
		if name.contains("Centre"):
			centres.append(entry)
		elif name.contains("End"):
			ends.append(entry)
	for centre: Array in centres:
		var middle: Vector3 = (centre[1] as Transform3D).origin
		for end: Array in ends:
			if (rounds.get(int(centre[0]), {}) as Dictionary).has(int(end[0])):
				continue
			# The fork: two small bores on one line, either side of the middle.
			var at: Transform3D = end[1]
			var bores: Array = []
			for connector: Lbm.Connector in (end[2] as Lbm.PartMesh).connectors:
				if connector.kind == "bore" and connector.radius < 2.5:
					bores.append([at * (connector.position + connector.axis * connector.length * 0.5),
						(at.basis * connector.axis).normalized()])
			if bores.size() != 2 or absf((bores[0][1] as Vector3).dot(bores[1][1])) < 0.999:
				continue
			var fork: Vector3 = ((bores[0][0] as Vector3) + (bores[1][0] as Vector3)) * 0.5
			if fork.distance_to(middle) > SAME_LINE:
				continue
			candidates.append([int(end[0]), int(centre[0]), "hinge", fork, bores[0][1], true, 0.0,
				Vector2.ZERO, 0])


## Whether [param key]'s part has no exact shape to read its joints from.
## Off the main thread a shape not read yet is not known to be missing: no.
func _unknown_shape(key: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(key)
	if brick == null or (not Exact.known(library, brick.part_id)
			and OS.get_thread_caller_id() != OS.get_main_thread_id()):
		return false
	var shape: Exact.Shape = Exact.shape_for(library, brick.part_id)
	return shape == null or shape.connector_count() == 0


## A gear rack among [param keys] (one piece, [param piece] in [param up])
## that a pinion of another piece stands in (Racks.find): [rack, pinion]
## ids, or empty.
func _driven_rack(keys: Array, piece: int, up: Dictionary) -> Array:
	var racks: Array = []
	for key: int in keys:
		var brick: BrickWorld.Brick = world.get_brick(key)
		if brick != null and Racks.is_rack(brick.part_id):
			racks.append([key, brick.part_id, brick.transform])
	if racks.is_empty():
		return []
	var near: Array = racks.duplicate()
	for brick: BrickWorld.Brick in world.bricks():
		if not _up.has(brick.id) or Bodies._piece_find(up, _find(brick.id)) == piece:
			continue
		var spec: Dictionary = Mechanism.spec_of(brick.part_id)
		if not spec.is_empty() and int(spec.get("teeth", 0)) > 0:
			near.append([brick.id, brick.part_id, brick.transform])
	for mesh: Racks.Pinion in Racks.find(near):
		return [mesh.rack, mesh.gear]
	return []


## A pinion among [param keys] (one piece, [param piece] in [param up])
## standing in a rack of another piece (Racks.find): [the mesh], or empty.
func _driving_pinion(keys: Array, piece: int, up: Dictionary) -> Array:
	var gears: Array = []
	for key: int in keys:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var spec: Dictionary = Mechanism.spec_of(brick.part_id) if brick != null else {}
		if not spec.is_empty() and int(spec.get("teeth", 0)) > 0:
			gears.append([key, brick.part_id, brick.transform])
	if gears.is_empty():
		return []
	var near: Array = gears.duplicate()
	for brick: BrickWorld.Brick in world.bricks():
		if _up.has(brick.id) and Bodies._piece_find(up, _find(brick.id)) != piece \
				and Racks.is_rack(brick.part_id):
			near.append([brick.id, brick.part_id, brick.transform])
	for mesh: Racks.Pinion in Racks.find(near):
		if not mesh.screw and keys.has(mesh.gear):
			return [mesh]
	return []


## Whether [param part_id] bends: a hose's, a tube's, a string's or a
## chain's piece (Flex.strung), or a flexible part a file draws whole (its
## skin, CustomParts.SKIN_CATEGORY: 42042-1's winch rope).
static func bends(parts: PartLibrary, part_id: String) -> bool:
	if not Flex.strung(parts, part_id).is_empty():
		return true
	var info: PartLibrary.PartInfo = parts.parts.get(part_id) if parts != null else null
	return info != null and info.category == CustomParts.SKIN_CATEGORY


## A piece at most this many parts may be held by what it is lodged in.
const LODGE_MOST := 300


static func _piece_find(up: Dictionary, at: int) -> int:
	var x: int = at
	while int(up.get(x, x)) != x:
		x = int(up.get(x, x))
	up[at] = x
	return x


static func _piece_join(up: Dictionary, one: int, other: int) -> void:
	var a: int = Bodies._piece_find(up, one)
	var b: int = Bodies._piece_find(up, other)
	if a != b:
		up[maxi(a, b)] = mini(a, b)


## Parts no joint named that were held by what they are lodged in ([method
## _lodge]).
var lodged: int = 0
## Each piece's part that was lodged -> the part it was joined to.
var lodged_in: Dictionary = {}


## Each piece's anchor, and the tree grown from them.
func _anchor_and_grow() -> void:
	anchors.clear()
	parent_link.clear()
	parent_of.clear()
	children.clear()
	closing.clear()
	var seen: Dictionary = {}
	var pieces: Array = []
	for body: int in members:
		if seen.has(body):
			continue
		var piece: Array = []
		var frontier: Array = [body]
		seen[body] = true
		while not frontier.is_empty():
			var at: int = frontier.pop_back()
			piece.append(at)
			for link: Link in touching.get(at, []):
				var next: int = link.other(at)
				if not seen.has(next):
					seen[next] = true
					frontier.append(next)
		pieces.append(piece)
	anchor_why.clear()
	for piece: Array in pieces:
		for body: int in piece:
			for key: int in members[body]:
				if locked.has(key):
					anchor_why[body] = ["locked", key]
					break
		if not _any_of(piece, anchor_why):
			for body: int in piece:
				for key: int in members[body]:
					if _standing.has(key):
						anchor_why[body] = ["studs", key]
						break
		if not _any_of(piece, anchor_why):
			# The biggest body: the most parts, as the gear reading takes its
			# ground (Mechanism._largest); between two of a size, the heavier.
			# Not the heaviest outright: a part is weighed by its box
			# (Stability.grams), and a shell's box is mostly air. 42081-1's
			# bucket (15265), weighed at 535 g, outweighed the loader's frame,
			# and drawing the arm's rod swung the loader round the arm.
			var best: int = piece[0]
			for body: int in piece:
				if Bodies._bigger(_size_of(body), float(grams.get(body, 0.0)), body,
						_size_of(best), float(grams.get(best, 0.0)), best):
					best = body
			# Unless what stands on the floor outweighs it: a body reaching
			# down to where its piece is lowest (not by a tyre, which rolls)
			# holds the model there by its weight. A crane of a few bricks
			# stands on its tower, though its arm has more parts.
			var lowest: Dictionary = {}   ## body -> its lowest point, LDU up, no tyre's
			var floor_y: float = INF
			for body: int in piece:
				for key: int in members[body]:
					var brick: BrickWorld.Brick = world.get_brick(key)
					var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
					if info == null:
						continue
					var bottom: float = (brick.transform * info.bounds).position.y
					floor_y = minf(floor_y, bottom)
					if not _is_tyre(info):
						lowest[body] = minf(float(lowest.get(body, INF)), bottom)
			var why: String = "biggest"
			for body: int in piece:
				if float(lowest.get(body, INF)) <= floor_y + STANDS \
						and float(grams.get(body, 0.0)) > float(grams.get(best, 0.0)):
					best = body
					why = "floor"
			anchor_why[best] = [why, 0]
	for body: int in anchor_why:
		anchors[body] = true
	# Breadth first from every anchor at once: each body hangs from the one
	# nearest an anchor.
	var reached: Dictionary = {}
	var queue: Array = []
	for body: int in anchors:
		reached[body] = true
		queue.append(body)
	var used: Dictionary = {}
	# A flexible tube, a hose, a chain is drawn as rigid pieces but bends:
	# held at both ends it closes no loop, and carries nothing on from where
	# it hangs. A pneumatic cylinder's tubes, each joined to its ports and to
	# a valve, locked its loop, and what the tubes reached at their far end
	# hung from them and stayed when the arm it is on was raised.
	flexible.clear()
	for body: int in members:
		var strung: bool = true
		for key: int in members[body]:
			var brick: BrickWorld.Brick = world.get_brick(key)
			if brick == null or Flex.strung(library, brick.part_id).is_empty():
				strung = false
				break
		if strung:
			flexible[body] = true
	var head: int = 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		for link: Link in touching.get(at, []):
			if used.has(link):
				continue
			used[link] = true
			var next: int = link.other(at)
			if reached.has(next):
				if not flexible.has(at) and not flexible.has(next):
					closing.append(link)
				continue
			if flexible.has(at):
				# Reached from its far end, or its own piece's anchor, later.
				used.erase(link)
				continue
			reached[next] = true
			parent_link[next] = link
			parent_of[next] = at
			if not children.has(at):
				children[at] = []
			(children[at] as Array).append(next)
			queue.append(next)
	# A linear actuator or a cylinder in a loop is a joint of the tree, not the
	# one that closes it: its rod is dragged along it, and a loop is driven from
	# a joint of the tree (Linkage). The body it would close on is hung from it
	# instead, and the joint that body hung from closes the loop.
	for link: Link in closing.duplicate():
		if link.turns:
			continue
		var child: int = link.a if beyond(link.b).has(link.a) else link.b
		var parent: int = link.other(child)
		var old: Link = parent_link.get(child)
		if old == null or beyond(child).has(parent):
			continue
		(children[parent_of[child]] as Array).erase(child)
		closing.erase(link)
		closing.append(old)
		parent_link[child] = link
		parent_of[child] = parent
		if not children.has(parent):
			children[parent] = []
		(children[parent] as Array).append(child)


func _size_of(body: int) -> int:
	return (members.get(body, PackedInt64Array()) as PackedInt64Array).size()


## Whether a body of [param parts] parts and [param weight] grams is bigger
## than another: more parts, else heavier, else the first read.
static func _bigger(parts: int, weight: float, body: int, other_parts: int, other_weight: float,
		other: int) -> bool:
	if parts != other_parts:
		return parts > other_parts
	if not is_equal_approx(weight, other_weight):
		return weight > other_weight
	return body < other


## Whether any of [param piece]'s bodies is a key of [param among].
static func _any_of(piece: Array, among: Dictionary) -> bool:
	for body: int in piece:
		if among.has(body):
			return true
	return false


## What holds [param part] still, in words a person or a session can act on,
## each part named with its number, or "" when nothing is known. The joint
## nearest it that its body holds still (an axle in a round hole, a pin, a
## hinge, whose two halves ended in one body), and each join that holds those
## halves as one, from one to the other: "the Technic Axle 4 (#15) would turn
## on its axle in the Technic Plate 2 x 8 with Holes (#11), but the Brick 2 x
## 2 Round (#25) grips the Technic Axle 4 (#15) and the studs of the Technic
## Plate 2 x 8 with Holes (#11) grip the Brick 2 x 2 Round (#25)". With no
## such joint, why its body is what stays ([method stays_words]).
func held_words(part: int) -> String:
	var body: int = int(body_of.get(part, -1))
	if body < 0:
		return ""
	var overruled_said: String = overruled_words(part)
	if not overruled_said.is_empty():
		return overruled_said
	var stays: String = stays_words(body)
	if stays.is_empty():
		return ""
	stays = "%s is part of what stays: %s" % [_part_named(part), stays]
	var at: int = int((anchor_why[body] as Array)[1])
	if at == 0:
		# The biggest body, held by no part in particular: what joins this
		# part to it. A door opened to 90° was "part of what stays", with
		# its top stud read into the wall brick over it.
		var own := PackedStringArray()
		for edge: Array in (joined_by.get(part, []) as Array).slice(0, 2):
			own.append(_join_words(part, int(edge[0]), str(edge[1])))
		return stays if own.is_empty() else "%s, and %s" % [stays, Bodies._and(own)]
	var path: Array = _path(part, at) if at != part else []
	if path.is_empty() or path.size() > 3:
		return stays
	var steps := PackedStringArray()
	for step: Array in path:
		steps.append(_join_words(int(step[0]), int(step[1]), str(step[2])))
	return "%s, and %s" % [stays, Bodies._and(steps)]


## The joint nearest [param part] that its body holds still, and what holds
## its halves as one ([method held_words]); "" for a part with none.
func overruled_words(part: int) -> String:
	var body: int = int(body_of.get(part, -1))
	if body < 0:
		return ""
	var hops: Dictionary = _hops(part)
	var far: int = 1 << 30
	var near_first: Array = []   ## [hops, joint]
	for one: Array in overruled:
		if int(body_of.get(int(one[0]), -1)) == body:
			near_first.append([mini(int(hops.get(int(one[0]), far)), int(hops.get(int(one[1]), far))), one])
	near_first.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	# Not a joint between two parts joined to each other directly: a wheel's
	# hub read as on a hinge in the axle it grips is no joint at all.
	var best: Array = []
	for near: Array in near_first:
		# Near it, or it is not what holds this part: a door left held at 90°
		# in a big body was said to be held by a carriage's bearing across
		# the model.
		if int(near[0]) > 3:
			break
		if _path(int(near[1][0]), int(near[1][1])).size() >= 2:
			best = near[1]
			break
	if best.is_empty():
		return ""
	var near_end: int = int(best[0])
	var far_end: int = int(best[1])
	if int(hops.get(far_end, far)) < int(hops.get(near_end, far)):
		near_end = int(best[1])
		far_end = int(best[0])
	var steps := PackedStringArray()
	for step: Array in _path(near_end, far_end):
		steps.append(_join_words(int(step[0]), int(step[1]), str(step[2])))
	var said := Link.new()
	said.kind = str(best[2])
	return "%s would turn %s in %s, but %s" % [_part_named(near_end), said.words(),
		_part_named(far_end), Bodies._and(steps)]


## What stays in [param body]'s piece of the model, each anchor and why, in
## words ([method stays_words]): a train that locks is held between them.
func what_stays(body: int) -> String:
	var seen: Dictionary = {body: true}
	var queue: Array = [body]
	var said := PackedStringArray()
	var head: int = 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		if anchors.has(at):
			said.append(stays_words(at))
		for link: Link in touching.get(at, []):
			var next: int = link.other(at)
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return Bodies._and(said)


## Why [param body] is what stays when something else is moved, or "" for a
## body that is not an anchor.
func stays_words(body: int) -> String:
	var why: Array = anchor_why.get(body, [])
	if why.is_empty():
		return ""
	var at: int = int(why[1])
	match str(why[0]):
		"locked":
			return "%s is locked" % _part_named(at)
		"studs":
			return "%s stands on the baseplate's studs" % _part_named(at)
		"floor":
			return "the body of %s stands on the floor" % named([body]).get_slice(",", 0)
	return "the body of %s is the biggest of the model (%d parts)" % [named([body]).get_slice(",", 0),
		_size_of(body)]


## [param one] and [param other] made one body for [param why] (as [member
## joined_by] keeps it), in words.
func _join_words(one: int, other: int, why: String) -> String:
	var kind: String = why.get_slice(":", 0)
	match kind:
		"grips":
			var shaft: int = int(why.get_slice(":", 1))
			return "%s grips %s" % [_part_named(other if shaft == one else one), _part_named(shaft)]
		"studs":
			var owner: int = int(why.get_slice(":", 1))
			return "the studs of %s grip %s" % [_part_named(owner), _part_named(other if owner == one else one)]
		"tyre":
			var tyre: int = one if Bodies._is_tyre(_info(one)) else other
			return "%s is held on %s" % [_part_named(tyre), _part_named(other if tyre == one else one)]
		"pin":
			return "%s and %s turn as one (a pin is part of the first thing it is in)" % [
				_part_named(one), _part_named(other)]
		"lodged":
			var lodged_part: int = one if int(lodged_in.get(one, -1)) == other \
				or (lodged_in.has(one) and not lodged_in.has(other)) else other
			return "%s is lodged in %s" % [_part_named(lodged_part),
				_part_named(other if lodged_part == one else one)]
		"lines":
			return "%s and %s are joined on two lines at once" % [_part_named(one), _part_named(other)]
	return "%s is stuck to %s" % [_part_named(one), _part_named(other)]


## How many joins from [param from] each part of its body is.
func _hops(from: int) -> Dictionary:
	var out: Dictionary = {from: 0}
	var queue: Array = [from]
	var head: int = 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		for edge: Array in joined_by.get(at, []):
			if not out.has(int(edge[0])):
				out[int(edge[0])] = int(out[at]) + 1
				queue.append(int(edge[0]))
	return out


## The joins from [param from] to [param to], each [one, other, why], or [].
func _path(from: int, to: int) -> Array:
	var back: Dictionary = {from: []}
	var queue: Array = [from]
	var head: int = 0
	while head < queue.size() and not back.has(to):
		var at: int = queue[head]
		head += 1
		for edge: Array in joined_by.get(at, []):
			if not back.has(int(edge[0])):
				back[int(edge[0])] = [at, str(edge[1])]
				queue.append(int(edge[0]))
	if not back.has(to):
		return []
	var out: Array = []
	var at: int = to
	while at != from:
		var step: Array = back[at]
		out.push_front([int(step[0]), at, str(step[1])])
		at = int(step[0])
	return out


func _info(key: int) -> PartLibrary.PartInfo:
	var brick: BrickWorld.Brick = world.get_brick(key)
	return library.parts.get(brick.part_id) if brick != null else null


## "the Technic Bush (#80)".
func _part_named(key: int) -> String:
	var info: PartLibrary.PartInfo = _info(key)
	return "the %s (#%d)" % [Bodies._short(info.name) if info != null else "part", key]


## "a", "a and b", "a, b and c".
static func _and(said: PackedStringArray) -> String:
	if said.size() <= 1:
		return "".join(said)
	return ", ".join(said.slice(0, said.size() - 1)) + " and " + said[said.size() - 1]


## Every body beyond [param body], it included: what comes along when it
## turns on its joint towards the anchor.
func beyond(body: int) -> Array:
	var out: Array = [body]
	var head: int = 0
	while head < out.size():
		for child: int in children.get(out[head], []):
			out.append(child)
		head += 1
	return out


## Every part in [param bodies_list].
func parts_of(bodies_list: Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	for body: int in bodies_list:
		out.append_array(members.get(body, PackedInt64Array()))
	return out


## The joints in series from [param body] back to its anchor, nearest
## first: an arm's wrist, elbow, shoulder.
func chain(body: int) -> Array[Link]:
	var out: Array[Link] = []
	var at: int = body
	while parent_link.has(at):
		var link: Link = parent_link[at]
		out.append(link)
		at = parent_of[at]
	return out


## The links leaving [param inside] (body -> true) other than [param but]:
## a loop that holds the moving side at its other end, when any of them is
## not on the same line as [param but].
func loops_out(inside: Dictionary, but: Link) -> Array[Link]:
	var out: Array[Link] = []
	for body: int in inside:
		for link: Link in touching.get(body, []):
			if link == but or inside.has(link.other(body)):
				continue
			if link.axis != Vector3.ZERO and but.axis != Vector3.ZERO \
					and _same_line(link.point, link.axis, but.point, but.axis):
				continue
			if not out.has(link):
				out.append(link)
	return out


## Every pinion standing in a rack (Racks.find), read once, where each
## joins two bodies: a steering column's pinion in the rack on its track rod.
## And every linear actuator's screw whose input is a part of its own, read
## as a pinion in the rod (Racks.screws): its input turned, the rod goes out.
func racks() -> Array[Racks.Pinion]:
	if _racks_read:
		return _racks
	_racks_read = true
	var entries: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if body_of.has(brick.id):
			entries.append([brick.id, brick.part_id, brick.transform])
	for mesh: Racks.Pinion in Racks.find(entries) + Racks.screws(entries, links):
		if int(body_of[mesh.rack]) != int(body_of[mesh.gear]):
			_racks.append(mesh)
	return _racks


## Each rod standing in its actuator's body (the gear table's actuators,
## where the library's contracted and extended files draw it): [body, rod,
## kind, point, axis, holds, detent, slide, shaft] as _read gathers joints,
## the axis the way the rod goes out and the slide as far as it may go out
## and back in from where it stands. A screw holds where it is left; a
## cylinder's air holds it while its valve is shut.
func _actuators(entries: Array) -> Array:
	var table: Dictionary = Mechanism.table().get("actuators", {})
	var out: Array = []
	if table.is_empty():
		return out
	var rods: Dictionary = {}   ## rod part -> Array of entries
	var rod_parts: Dictionary = {}
	for body_part: String in table:
		rod_parts[str(table[body_part]["rod"])] = true
	for entry: Array in entries:
		var rod_part: String = Mechanism.reads_as(str(entry[3]))
		if rod_parts.has(rod_part):
			if not rods.has(rod_part):
				rods[rod_part] = []
			(rods[rod_part] as Array).append(entry)
	for entry: Array in entries:
		var spec: Dictionary = Mechanism.entry_of("actuators", str(entry[3]))
		if spec.is_empty():
			continue
		var at: Transform3D = entry[1]
		var inverse: Transform3D = at.affine_inverse()
		var local_axis: Vector3 = Mechanism._axis_of(spec.get("axis", "z"))
		var from: float = float(spec["from"])
		var to: float = float(spec["to"])
		var stroke: float = absf(to - from)
		var sense: float = signf(to - from)
		for rod: Array in rods.get(str(spec["rod"]), []):
			var rod_at: Transform3D = rod[1]
			var local: Vector3 = inverse * rod_at.origin
			var along: float = local.dot(local_axis)
			if (local - local_axis * along).length() > Mechanism.LINE_SLACK \
					or along < minf(from, to) - Mechanism.REACH_SLACK \
					or along > maxf(from, to) + Mechanism.REACH_SLACK:
				continue
			if absf((inverse.basis * (rod_at.basis * local_axis)).normalized().dot(local_axis)) < 0.99:
				continue
			var out_by: float = clampf((along - from) * sense, 0.0, stroke)
			out.append([int(entry[0]), int(rod[0]), "actuator" if str(spec.get("kind", "")) == "screw"
				else "cylinder", at * (local_axis * along), (at.basis * (local_axis * sense)).normalized(),
				true, 0.0, Vector2(stroke - out_by, out_by), int(rod[0])])
	return out


## A rack that slides in a housing of its own (18942 in 18940, the gear
## table's racks: housing, housing_at): the rack's origin on the housing's x
## line where the table puts it, give or take a cell across, anywhere along
## the housing. It slides along that line, the rack's middle staying within
## the housing's length, and does not turn there: candidates as
## [method _actuators] gives them, kind "housing".
func _rack_housings(entries: Array) -> Array:
	var out: Array = []
	var by_housing: Dictionary = {}   ## housing part -> [rack entry, spec]
	for entry: Array in entries:
		var spec: Dictionary = Racks.spec_of(str(entry[3]))
		if spec.has("housing"):
			var housing: String = str(spec["housing"])
			if not by_housing.has(housing):
				by_housing[housing] = []
			(by_housing[housing] as Array).append([entry, spec])
	if by_housing.is_empty():
		return out
	for entry: Array in entries:
		var housing: String = Mechanism.reads_as(str(entry[3]))
		if not by_housing.has(housing):
			continue
		var at: Transform3D = entry[1]
		var inverse: Transform3D = at.affine_inverse()
		var info: PartLibrary.PartInfo = library.parts.get(str(entry[3]))
		for pair: Array in by_housing[housing]:
			var rack: Array = pair[0]
			var spec: Dictionary = pair[1]
			var rack_at: Transform3D = rack[1]
			var local: Vector3 = inverse * rack_at.origin
			var want: Array = spec.get("housing_at", [0.0, 0.0, 0.0])
			if absf(local.y - float(want[1])) > Mechanism.LINE_SLACK \
					or absf(local.z - float(want[2])) > Mechanism.LINE_SLACK:
				continue
			if absf((inverse.basis * rack_at.basis * Vector3.RIGHT).normalized().x) < Racks.SQUARE:
				continue
			# Along the housing: the rack's middle within its length.
			var lo: float = info.bounds.position.x if info != null else local.x - 20.0
			var hi: float = info.bounds.end.x if info != null else local.x + 20.0
			if local.x < lo - Mechanism.REACH_SLACK or local.x > hi + Mechanism.REACH_SLACK:
				continue
			# As an actuator's stroke: how far on along the housing's x, then
			# how far back.
			var way: Vector3 = (at.basis * Vector3.RIGHT).normalized()
			out.append([int(entry[0]), int(rack[0]), "housing", rack_at.origin, way, true, 0.0,
				Vector2(maxf(hi - local.x, 0.0), maxf(local.x - lo, 0.0)), int(rack[0])])
	return out


## Studs standing up into a gear rack from underneath ride in its groove: a
## steering rack (87761, 64781; the gear table's racks: groove) is a channel
## open below, and the half pins
## under it guide it as it slides (42083-1, 42111-1). Read as studs, the
## half pins held the rack to the frame and its pinion turned against
## nothing. [param pair]'s studs, all of [param owner]'s, each [foot, way]:
## a candidate as [method _read] gathers them, kind "groove", the rack
## sliding along its line as far as the studs stay under it; empty when the
## other is not a rack or a stud does not stand up into it.
func _in_a_groove(pair: Vector2i, owner: int, found: Array) -> Array:
	var rack: int = pair.y if owner == pair.x else pair.x
	var brick: BrickWorld.Brick = world.get_brick(rack)
	if brick == null or not bool(Racks.spec_of(brick.part_id).get("groove", false)):
		return []
	var up: Vector3 = (brick.transform.basis * Vector3.UP).normalized()
	var line: Vector3 = (brick.transform.basis * Vector3.RIGHT).normalized()
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	if info == null:
		return []
	var inverse: Transform3D = brick.transform.affine_inverse()
	var on: float = INF
	var back: float = INF
	for stud: Array in found:
		if (stud[1] as Vector3).normalized().dot(up) < Racks.SQUARE:
			return []
		# The stud's middle stays under the rack, a stud's half from its ends.
		var along: float = (inverse * (stud[0] as Vector3)).x
		on = minf(on, along - info.bounds.position.x - 6.0)
		back = minf(back, info.bounds.end.x - 6.0 - along)
	return [owner, rack, "groove", found[0][0], line, true, 0.0,
		Vector2(maxf(on, 0.0), maxf(back, 0.0)), rack]


## The studs standing up in each grooved rack's groove, found from the rack's
## shape rather than the cells their tips are in: a rack its pinion has slid
## off the studs' grid has their tips in its groove, which its cover leaves
## empty, and none was read in it. 8448-1's rack, slid 2 LDU, was then held
## by nothing on its plate and lodged in the steering arm it touched, which
## carried it the next turn. Pair -> a candidate as [method _in_a_groove]
## makes one, for each part with a stud there.
func _grooves_by_shape(entries: Array, turning: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for entry: Array in entries:
		var rack: int = int(entry[0])
		if not bool(Racks.spec_of(str(entry[3])).get("groove", false)):
			continue
		var at: Transform3D = entry[1]
		var mesh: Lbm.PartMesh = entry[2]
		var inverse: Transform3D = at.affine_inverse()
		var up: Vector3 = (at.basis * Vector3.UP).normalized()
		var box: AABB = (at * mesh.bounds).grow(Joints.STUD_REACH + 2.0)
		var cell: float = BrickLattice.CELL
		var bound := PackedInt32Array([floori(box.position.x / cell), floori(box.position.y / cell),
			floori(box.position.z / cell), ceili(box.end.x / cell), ceili(box.end.y / cell),
			ceili(box.end.z / cell)])
		var found: Dictionary = {}   ## owner -> [[foot, way]]
		for other: int in lattice.near_bounds(bound, rack):
			var brick: BrickWorld.Brick = world.get_brick(other)
			var theirs: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
			if theirs == null or scenery.has(other) or not _up.has(other):
				continue
			for connector: Lbm.Connector in theirs.connectors:
				if connector.kind != "stud" or connector.gender != "male":
					continue
				var way: Vector3 = (brick.transform.basis * connector.axis).normalized()
				if way.dot(up) < Racks.SQUARE:
					continue
				var foot: Vector3 = brick.transform * connector.position
				var local: Vector3 = inverse * (foot + way * Joints.STUD_REACH)
				# Its tip in the groove: under the rack's middle, into its foot.
				if absf(local.z) > 2.0 or local.x < mesh.bounds.position.x + 6.0 \
						or local.x > mesh.bounds.end.x - 6.0 or local.y < mesh.bounds.position.y \
						or local.y > mesh.bounds.position.y + Joints.STUD_REACH + 1.0:
					continue
				if not found.has(other):
					found[other] = []
				(found[other] as Array).append([foot, way])
		for owner: int in found:
			var pair := Vector2i(mini(owner, rack), maxi(owner, rack))
			if turning.has(pair):
				continue
			var groove: Array = _in_a_groove(pair, owner, found[owner])
			if not groove.is_empty():
				out[pair] = groove
	return out


## A round steering rack (the gear table's racks: round), which slides
## through the holder it turns in.
static func _round_rack(part_id: String) -> bool:
	return bool(Racks.spec_of(part_id).get("round", false))


## Whether [param zone] between [param a] and [param b] is a round rack in
## its holder: a round on the rack's own line, not the pin holes at its ends.
func _rides_loose(a: int, b: int, part_of: Dictionary, zone: Array) -> bool:
	for key: int in [a, b]:
		if _round_rack(str(part_of.get(key, ""))):
			var line: Vector3 = (world.get_brick(key).transform.basis * Vector3.RIGHT).normalized()
			return absf(line.dot((zone[1] as Vector3).normalized())) > Racks.SQUARE
	return false


## Joints that guide a rack along its line: its housing (18942 in 18940),
## studs standing in its groove (a steering rack on half pins), and what a
## rack its pinion holds rests on ([method _lodge]).
const GUIDES: Array[String] = ["housing", "groove", "rests"]

var _racks: Array[Racks.Pinion] = []
var _racks_read: bool = false


## Every universal joint's cross, as the joints read it: a body of a part or
## two joined to two others by a turning joint each, the two lines square to
## each other and crossing at one point, as a universal joint's centre is
## pinned into its two ends (3326a in two 3712s, 62519 in two 62520s). Each
## [the cross's body, the link to one end, the link to the other, where the
## lines cross]. Whether the ends' shafts turn about lines through that
## point is the gear reading's to say (Mechanism.join_universals).
func universals() -> Array:
	if _universals_read:
		return _universals
	_universals_read = true
	for body: int in members:
		if (members[body] as PackedInt64Array).size() > 2:
			continue
		var turning: Array[Link] = []
		for link: Link in touching.get(body, []):
			if link.axis != Vector3.ZERO and link.turns:
				turning.append(link)
		# Pinned into its ends' forks: a shaft of two parts (a joint's end on
		# its axle) turning as an axle in a hole on a line through where it
		# is pinned is not a cross.
		if turning.size() == 2 and not (turning[0].kind in ["hinge", "pin"] and turning[1].kind in ["hinge", "pin"]):
			continue
		if turning.size() != 2 or turning[0].other(body) == turning[1].other(body):
			continue
		var u: Vector3 = turning[0].axis.normalized()
		var v: Vector3 = turning[1].axis.normalized()
		if absf(u.dot(v)) > 0.05:
			continue
		var t: float = Mechanism._crossing(turning[0].point, u, turning[1].point, v)
		var on_one: Vector3 = turning[0].point + u * t
		var s: float = Mechanism._crossing(turning[1].point, v, turning[0].point, u)
		var on_other: Vector3 = turning[1].point + v * s
		if on_one.distance_to(on_other) > SAME_LINE:
			continue
		_universals.append([body, turning[0], turning[1], (on_one + on_other) * 0.5])
	return _universals


var _universals: Array = []
var _universals_read: bool = false


## The bodies the joints between them hold as one, though each joint alone
## turns or slides: a frame on four pins, each pin a body of its own turning
## in both; a beam on a pin and a hinge on two lines through a connector
## between. Body -> the body of its group nearest an anchor (itself, alone
## or nearest), every anchor in one group. Two groups are one when no
## motion of the one against the other is let by every way between them:
## each joint straight between them, and each way through a third body,
## which lets what its two joints let together. Read once, for a loop
## (Linkage): its joints are those between groups, and a steering does not
## take in every pin of the chassis it stands in (42125-1's 106 joints).
func held_together() -> Dictionary:
	if _held_read:
		return _held
	_held_read = true
	var up: Dictionary = {}
	for body: int in members:
		up[body] = body
	var find := func(at: int) -> int:
		var x: int = at
		while int(up[x]) != x:
			up[x] = up[int(up[x])]
			x = int(up[x])
		return x
	var first_anchor: int = -1
	for body: int in anchors:
		if first_anchor < 0:
			first_anchor = body
		else:
			up[find.call(body)] = find.call(first_anchor)
	for _pass: int in HELD_PASSES:
		var direct: Dictionary = {}   ## Vector2i of groups -> Array of links
		var near: Dictionary = {}   ## group -> {group: true}
		for link: Link in links:
			var x: int = find.call(link.a)
			var y: int = find.call(link.b)
			if x == y:
				continue
			var pair := Vector2i(mini(x, y), maxi(x, y))
			if not direct.has(pair):
				direct[pair] = []
				for ends: Array in [[x, y], [y, x]]:
					if not near.has(ends[0]):
						near[ends[0]] = {}
					(near[ends[0]] as Dictionary)[ends[1]] = true
			(direct[pair] as Array).append(link)
		# Each pair of groups and the bodies between them: a pin, a connector.
		var through: Dictionary = {}   ## Vector2i -> Array of groups between
		for middle: Variant in near:
			var round: Array = (near[middle] as Dictionary).keys()
			if round.size() < 2 or round.size() > HELD_THROUGH:
				continue
			for i: int in round.size():
				for j: int in range(i + 1, round.size()):
					var pair := Vector2i(mini(int(round[i]), int(round[j])), maxi(int(round[i]), int(round[j])))
					if not through.has(pair):
						through[pair] = []
					(through[pair] as Array).append(int(middle))
		var joined: bool = false
		var asked: Dictionary = {}
		for pair: Variant in direct.keys() + through.keys():
			if asked.has(pair):
				continue
			asked[pair] = true
			var straight: Array = direct.get(pair, [])
			var between: Array = through.get(pair, [])
			if straight.size() + between.size() < 2:
				continue
			var x: int = (pair as Vector2i).x
			var y: int = (pair as Vector2i).y
			if find.call(x) != x or find.call(y) != y:
				continue
			var ways: Array = []   ## each way's lets, as [links] or [[links], [links]]
			for link: Link in straight:
				ways.append([link])
			for middle: int in between:
				if find.call(middle) != middle:
					continue
				ways.append([direct.get(Vector2i(mini(x, middle), maxi(x, middle)), []),
					direct.get(Vector2i(mini(y, middle), maxi(y, middle)), [])])
			if ways.size() >= 2 and Bodies._held_by(ways):
				up[y] = x
				joined = true
		if not joined:
			break
	# Each group's body nearest an anchor stands for it.
	var depth: Dictionary = {}
	var lead: Dictionary = {}   ## group -> its body nearest an anchor
	for body: int in members:
		var d: int = 0
		var at: int = body
		while parent_of.has(at):
			at = int(parent_of[at])
			d += 1
		depth[body] = d
		var group: int = find.call(body)
		var best: int = int(lead.get(group, -1))
		if best < 0 or d < int(depth[best]) or d == int(depth[best]) and body < best:
			lead[group] = body
	_held.clear()
	for body: int in members:
		_held[body] = int(lead[find.call(body)])
	return _held


var _held: Dictionary = {}
var _held_read: bool = false
## Passes over the groups: each joins those held by what the last joined.
const HELD_PASSES := 12
## A body between two groups is a way between them when it touches no more
## than this many groups: a pin, a connector, not a frame.
const HELD_THROUGH := 6
## A way of moving one group against another counts when it is this far
## from what the other ways let, in turns of a radian and studs: two pins'
## lines 0.6 LDU or more apart hold.
const HELD_SLACK := 0.03


## Whether [param ways] between two groups let no motion of the one against
## the other: each way a joint, [link], or a body between, [[links to the
## one], [links to the other]], which lets what either side lets. Motions as
## twists (a turn and the speed of a point), about the middle of the joints,
## in radians and studs.
static func _held_by(ways: Array) -> bool:
	var middle := Vector3.ZERO
	var count: int = 0
	for way: Array in ways:
		for one: Variant in way:
			for link: Link in (one if one is Array else [one]):
				middle += link.point
				count += 1
	middle /= maxf(float(count), 1.0)
	# What every way lets, as what each way holds: the motions square to it.
	var held: Array = []
	for way: Array in ways:
		var lets: Array = []
		if way.size() == 1 and way[0] is Link:
			lets = Bodies._lets(way[0], middle)
		else:
			for side: Array in way:
				var both: Array = Bodies._lets(side[0], middle)
				for n: int in range(1, side.size()):
					both = Bodies._meet(both, Bodies._lets(side[n], middle))
				lets.append_array(both)
		held.append_array(Bodies._square_to(Bodies._basis_of(lets)))
	return Bodies._basis_of(held).size() >= 6


## The motions [param link] lets the one half against the other, about
## [param middle]: a turn about its line, and a slide along it where it
## slides; a ball's turns about its middle.
static func _lets(link: Link, middle: Vector3) -> Array:
	var at: Vector3 = (link.point - middle) / BrickLattice.STUD
	var out: Array = []
	if link.axis == Vector3.ZERO:
		for way: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			out.append(Bodies._twist(way, at.cross(way)))
		return out
	var u: Vector3 = link.axis.normalized()
	if link.turns:
		out.append(Bodies._twist(u, at.cross(u)))
	if not link.turns or link.slide.x + link.slide.y > 0.0:
		out.append(Bodies._twist(Vector3.ZERO, u))
	return out


static func _twist(turn: Vector3, speed: Vector3) -> PackedFloat64Array:
	return PackedFloat64Array([turn.x, turn.y, turn.z, speed.x, speed.y, speed.z])


## An orthonormal basis of what [param vectors] span, each one counted
## where it stands [constant HELD_SLACK] or more from the rest.
static func _basis_of(vectors: Array) -> Array:
	var out: Array = []
	for v: PackedFloat64Array in vectors:
		var w: PackedFloat64Array = v.duplicate()
		for e: PackedFloat64Array in out:
			var dot: float = 0.0
			for i: int in 6:
				dot += w[i] * e[i]
			for i: int in 6:
				w[i] -= dot * e[i]
		var size: float = 0.0
		for i: int in 6:
			size += w[i] * w[i]
		size = sqrt(size)
		if size < HELD_SLACK:
			continue
		for i: int in 6:
			w[i] /= size
		out.append(w)
		if out.size() == 6:
			break
	return out


## What is square to every one of [param basis] (orthonormal).
static func _square_to(basis: Array) -> Array:
	var out: Array = basis.duplicate()
	var start: int = out.size()
	for i: int in 6:
		var e := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
		e[i] = 1.0
		for f: PackedFloat64Array in out:
			var dot: float = f[i]
			for k: int in 6:
				e[k] -= dot * f[k]
		var size: float = 0.0
		for k: int in 6:
			size += e[k] * e[k]
		size = sqrt(size)
		if size < 1e-6:
			continue
		for k: int in 6:
			e[k] /= size
		out.append(e)
		if out.size() == 6:
			break
	return out.slice(start)


## What both [param one] and [param other] let.
static func _meet(one: Array, other: Array) -> Array:
	var held: Array = Bodies._square_to(Bodies._basis_of(one))
	held.append_array(Bodies._square_to(Bodies._basis_of(other)))
	return Bodies._square_to(Bodies._basis_of(held))


## The racks and pinions with one half in [param inside] (body -> true) and
## the other out of it: a turn of one drives the other.
func racks_out(inside: Dictionary) -> Array[Racks.Pinion]:
	var out: Array[Racks.Pinion] = []
	for mesh: Racks.Pinion in racks():
		if inside.has(int(body_of[mesh.rack])) != inside.has(int(body_of[mesh.gear])):
			out.append(mesh)
	return out


## How [param body] is said: "the boom, 38 parts" — its sub-assembly's name
## when most of it is in one, else its heaviest part's name.
func named(bodies_list: Array) -> String:
	var counted: Dictionary = {}
	var heaviest: int = 0
	var most: float = -1.0
	var count: int = 0
	for body: int in bodies_list:
		for key: int in members.get(body, PackedInt64Array()):
			count += 1
			var brick: BrickWorld.Brick = world.get_brick(key)
			if brick == null:
				continue
			var path: String = Assemblies.path_of(brick)
			if not path.is_empty():
				var label: String = Assemblies.label(path)
				counted[label] = int(counted.get(label, 0)) + 1
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			var g: float = Stability.grams(info) if info != null else 0.0
			if g > most:
				most = g
				heaviest = key
	var best: String = ""
	for label: String in counted:
		if int(counted[label]) * 2 > count and (best.is_empty() or int(counted[label]) > int(counted[best])):
			best = label
	if best.is_empty():
		var brick: BrickWorld.Brick = world.get_brick(heaviest)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		best = "the %s" % _short(info.name if info != null else "part")
	return "%s, %d part%s" % [best, count, "" if count == 1 else "s"]


static func _short(name: String) -> String:
	var out: String = name.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out


static func _one_stud(info: PartLibrary.PartInfo) -> bool:
	return info != null and info.size.x <= ONE_STUD and info.size.z <= ONE_STUD


## A pin's name says whether it has friction ridges: "Technic Pin with
## Friction Ridges" (2780), "Technic Pin without Friction Ridges" (3673),
## "Technic Axle Pin with Friction Ridges" (43093). A pin with neither has
## none (4274, a half pin). Builders use the ridged ones where a part should
## stay where it is put and the smooth ones where it should turn freely
## (Eurobricks, "Technic pins: to friction or not to friction",
## forums/topic/109407).
static func _has_friction(name: String) -> bool:
	var lower: String = name.to_lower()
	return lower.contains("friction") and not lower.contains("without friction")


static func _clicks(mesh: Lbm.PartMesh) -> bool:
	if mesh == null:
		return false
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "finger" or connector.kind == "fork":
			return true
	return false


## How far the bore of [param a] or [param b] may slide along the other's
## shaft on [param zone]'s line: [Vector2(back, on), the shaft's part]. Zero
## when neither is a shaft longer than the bore on it.
func _slide_on(a: int, b: int, zone: Array) -> Array:
	var point: Vector3 = zone[0]
	var way: Vector3 = (zone[1] as Vector3).normalized()
	var spans: Dictionary = {}   ## key -> {"shaft": Vector2, "bore": Vector2} along the line
	for key: int in [a, b]:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var mine: Dictionary = {}
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "shaft" and connector.kind != "bore":
				continue
			var start: Vector3 = brick.transform * connector.position
			var end: Vector3 = brick.transform * (connector.position + connector.axis * connector.length)
			if not _same_line(start, (end - start).normalized(), point, way):
				continue
			var s: float = (start - point).dot(way)
			var e: float = (end - point).dot(way)
			var span := Vector2(minf(s, e), maxf(s, e))
			var was: Variant = mine.get(connector.kind)
			mine[connector.kind] = span if was == null \
				else Vector2(minf((was as Vector2).x, span.x), maxf((was as Vector2).y, span.y))
		spans[key] = mine
	for pair: Array in [[a, b], [b, a]]:
		var shaft: Variant = (spans[pair[0]] as Dictionary).get("shaft")
		var bore: Variant = (spans[pair[1]] as Dictionary).get("bore")
		if shaft == null or bore == null:
			continue
		var s: Vector2 = shaft
		var o: Vector2 = bore
		# The bore's middle stays on the shaft, and the bore goes no further
		# than the two parts' rounds let it ([method _rounds_room]).
		var middle: float = (o.x + o.y) * 0.5
		var room: Vector2 = _rounds_room(pair[0], pair[1], point, way)
		var reach := Vector2(maxf(middle - s.x, 0.0), maxf(s.y - middle, 0.0))
		var back: float = minf(reach.x, room.x)
		var on: float = minf(reach.y, room.y)
		if back + on > 4.0:
			return [Vector2(back, on), pair[0], reach]
	return [Vector2.ZERO, 0]


## How far [param hole] may slide along [param shaft] on the line through
## [param point] along [param way] before their rounds meet, LDU:
## Vector2(back, on), the hole's part going against [param way] and with
## it; INF where nothing drawn stops it. Read by how far a slide had let them:
## a towball's flange into the rack it is in (8448-1), a steering arm's pin
## collar into the brick (5533-1), a clip into a bar's ball end
## (4002020-1) and into the plate a handle is on (21019-1), each a loop's
## slide, 1 to 6 LDU, where the real part cannot go.
##
## Each part is a round along the line: its rounds (shafts) and bores, at
## each place along it, say how far from the line it is solid, from the
## widest bore out to the widest round; past the last round of the shaft's
## part, where the part goes on (a towball's ball), solid all through. Two
## parts meet where both are solid at one radius ([constant ROUND_SLACK]
## spared); a pair already so where they stand is forgiven.
func _rounds_room(shaft: int, hole: int, point: Vector3, way: Vector3) -> Vector2:
	var none := Vector2(INF, INF)
	var at: float = point.dot(way)
	var rounds: Array = []   ## per part: Array of [lo, hi, inner, outer]
	for key: int in [shaft, hole]:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			return none
		var spans: Array = []   ## [lo, hi, radius, is a bore]
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "shaft" and connector.kind != "bore":
				continue
			var start: Vector3 = brick.transform * connector.position
			var end: Vector3 = brick.transform * (connector.position + connector.axis * connector.length)
			if connector.length <= 0.0 or not _same_line(start, (end - start).normalized(), point, way):
				continue
			var s: float = start.dot(way) - at
			var e: float = end.dot(way) - at
			spans.append([minf(s, e), maxf(s, e), connector.radius, connector.kind == "bore"])
		if key == shaft:
			var widths: Array = spans.filter(func(one: Array) -> bool: return not one[3])
			if widths.is_empty():
				return none
			var lowest: float = INF
			var highest: float = -INF
			for one: Array in widths:
				lowest = minf(lowest, float(one[0]))
				highest = maxf(highest, float(one[1]))
			var reach: Vector2 = Grab._reach_along(brick.transform, mesh.bounds, way) - Vector2(at, at)
			if reach.x < lowest - END_SLACK:
				spans.append([reach.x, lowest, INF, false])
			if reach.y > highest + END_SLACK:
				spans.append([highest, reach.y, INF, false])
		elif not spans.any(func(one: Array) -> bool: return one[3]):
			return none
		rounds.append(_solid_along(spans))
	var back: float = INF
	var on: float = INF
	for one: Array in rounds[0]:
		for other: Array in rounds[1]:
			# Solid at one radius: the shaft's part from its inner to its outer,
			# the hole's from its.
			if float(one[3]) <= float(other[2]) + ROUND_SLACK or float(other[3]) <= float(one[2]) + ROUND_SLACK:
				continue
			if float(other[1]) <= float(one[0]) + ALONG_SLACK:
				on = minf(on, maxf(float(one[0]) - float(other[1]), 0.0))
			elif float(other[0]) >= float(one[1]) - ALONG_SLACK:
				back = minf(back, maxf(float(other[0]) - float(one[1]), 0.0))
	return Vector2(back, on)


## How far a clip's [param link] slides along its bar before the two
## parts' exact shapes meet, LDU: Vector2(back, on) as [member Link.slide]
## has it, within [member Link.reach]; Vector2(-1, -1) where either shape is
## not at hand (a browser fetches them) or the two meet as they stand. The
## rounds' reading takes a bar's end as solid where its part goes on, and
## 4002020-1's bar goes on in a neck before its ball: a clip slides 2 LDU
## by its rounds and as far as the neck by its shapes.
func exact_room(link: Link) -> Vector2:
	var unknown := Vector2(-1.0, -1.0)
	var shaft: int = link.shaft_part
	var hole: int = -1
	for pair: Array in link.pairs:
		if int(pair[0]) == shaft:
			hole = int(pair[1])
		elif int(pair[1]) == shaft:
			hole = int(pair[0])
	var at_shaft: BrickWorld.Brick = world.get_brick(shaft)
	var at_hole: BrickWorld.Brick = world.get_brick(hole) if hole >= 0 else null
	if at_shaft == null or at_hole == null:
		return unknown
	var one: Exact.Shape = Exact.shape_for(library, at_shaft.part_id)
	var other: Exact.Shape = Exact.shape_for(library, at_hole.part_id)
	if one == null or other == null or not one.has_pieces() or not other.has_pieces():
		return unknown
	var fixed := Exact.Item.new(one, at_shaft.transform)
	if not Exact.clash(fixed, Exact.Item.new(other, at_hole.transform)).is_empty():
		return unknown
	var way: Vector3 = link.axis.normalized()
	var out := Vector2.ZERO
	for side: int in 2:
		var far: float = link.reach.x if side == 0 else link.reach.y
		var sign: float = -1.0 if side == 0 else 1.0
		var clear: float = 0.0
		var met: float = far
		if far > 0.0 and Exact.clash(fixed, Exact.Item.new(other, Transform3D(at_hole.transform.basis,
				at_hole.transform.origin + way * sign * far))).is_empty():
			clear = far
		else:
			for _round: int in 8:
				var middle: float = (clear + met) * 0.5
				if Exact.clash(fixed, Exact.Item.new(other, Transform3D(at_hole.transform.basis,
						at_hole.transform.origin + way * sign * middle))).is_empty():
					clear = middle
				else:
					met = middle
		out[side] = clear
	return out


## How far an axle's [param link] slides before what is on its line meets,
## LDU: Vector2(back, on) as [member Link.slide] has it, and no further
## than that. [member Link.slide] reads the axle against each part it goes
## through; this reads, besides, each other part on the axle's side of the
## joint that it goes through or grips (a gear, a bush, a joint's end, a
## wheel) against each part on the other side it goes through. 8448-1's
## pinion axle reads 9.5 and 29.5 LDU against its two bricks, and its
## pinion stands against one face of the nearer brick and its column's
## universal joint against the other: 2 LDU either way, into the brick's
## counterbores. 5533-1's steering closed its loop by sliding an arm 1.75
## LDU on into its brick. By the two parts' exact shapes where both are at
## hand, to where they first touch (Exact.clash forgives [constant
## Exact.TAU] into each other, taken off here); else by their rounds
## ([method _rounds_room]).
func line_room(link: Link) -> Vector2:
	if _line_rooms.has(link):
		return _line_rooms[link]
	var room: Vector2 = link.slide
	var shaft: int = link.shaft_part
	var shaft_body: int = int(body_of.get(shaft, -1))
	var hole_body: int = link.b if shaft_body == link.a else link.a
	var way: Vector3 = link.axis.normalized()
	var mine: Array = []
	var theirs: Array = []
	for key: int in on_shaft.get(shaft, []):
		var body: int = int(body_of.get(key, -1))
		if body == shaft_body:
			mine.append(key)
		elif body == hole_body:
			theirs.append(key)
	for one: int in mine:
		for other: int in theirs:
			var met: Vector2 = _room_between(one, other, link.point, way, room)
			room = Vector2(minf(room.x, met.x), minf(room.y, met.y))
	_line_rooms[link] = room
	return room


## How far [param other] may go along [param way] (on) and against it
## (back) from [param one] before the two meet, LDU, no further than
## [param within] asks: [method line_room]'s reading of one pair.
func _room_between(one: int, other: int, point: Vector3, way: Vector3, within: Vector2) -> Vector2:
	var a: BrickWorld.Brick = world.get_brick(one)
	var b: BrickWorld.Brick = world.get_brick(other)
	var mesh_a: Lbm.PartMesh = library.mesh_for(a.part_id) if a != null else null
	var mesh_b: Lbm.PartMesh = library.mesh_for(b.part_id) if b != null else null
	if mesh_a == null or mesh_b == null:
		return within
	# Along the line, how far apart their boxes stand each way: a pair that
	# cannot meet within the slide is not asked.
	var reach_a: Vector2 = Grab._reach_along(a.transform, mesh_a.bounds, way)
	var reach_b: Vector2 = Grab._reach_along(b.transform, mesh_b.bounds, way)
	var gaps := Vector2(reach_b.x - reach_a.y, reach_a.x - reach_b.y)   ## back, on
	# Going back, the other part comes towards this one only from the far
	# side of it along the line; going on, from the near side.
	var towards: Array = [reach_b.x + reach_b.y > reach_a.x + reach_a.y, reach_b.x + reach_b.y < reach_a.x + reach_a.y]
	var out: Vector2 = within
	var shape_a: Exact.Shape = Exact.shape_for(library, a.part_id)
	var shape_b: Exact.Shape = Exact.shape_for(library, b.part_id)
	if shape_a != null and shape_b != null and shape_a.has_pieces() and shape_b.has_pieces():
		var fixed := Exact.Item.new(shape_a, a.transform)
		if Exact.clash(fixed, Exact.Item.new(shape_b, b.transform)).is_empty():
			for side: int in 2:
				var far: float = within[side]
				# Boxes apart by more than the slide (and the touch it forgives).
				if far <= 0.0 or not bool(towards[side]) or gaps[side] > far + Exact.TAU:
					continue
				var sign: float = -1.0 if side == 0 else 1.0
				var clear: float = 0.0
				var met: float = far + Exact.TAU
				for _round: int in 10:
					var middle: float = (clear + met) * 0.5
					if Exact.clash(fixed, Exact.Item.new(shape_b, Transform3D(b.transform.basis,
							b.transform.origin + way * sign * middle))).is_empty():
						clear = middle
					else:
						met = middle
				if met <= far + Exact.TAU - 0.001:
					out[side] = maxf(clear - Exact.TAU, 0.0)
			return out
	var rounds: Vector2 = _rounds_room(one, other, point, way)
	return Vector2(minf(out.x, rounds.x), minf(out.y, rounds.y))


## A part's rounds and bores along a line ([lo, hi, radius, is a bore]) as
## the stretches between where any begins or ends, each [lo, hi, inner,
## outer]: solid from its widest bore (0 for none) to its widest round (INF
## for none, round a bore). A stretch with neither is left out.
static func _solid_along(spans: Array) -> Array:
	var cuts: Array = []
	for one: Array in spans:
		cuts.append(float(one[0]))
		cuts.append(float(one[1]))
	cuts.sort()
	var out: Array = []
	for n: int in cuts.size() - 1:
		var lo: float = cuts[n]
		var hi: float = cuts[n + 1]
		if hi - lo < 0.01:
			continue
		var mid: float = (lo + hi) * 0.5
		var inner: float = 0.0
		var outer: float = -1.0
		var bored: bool = false
		for one: Array in spans:
			if mid < float(one[0]) or mid > float(one[1]):
				continue
			if bool(one[3]):
				inner = maxf(inner, float(one[2]))
				bored = true
			else:
				outer = maxf(outer, float(one[2]))
		if outer < 0.0:
			if not bored:
				continue
			outer = INF
		out.append([lo, hi, inner, outer])
	return out


## Past the last round of a shaft's part, a part going on further than this
## along the line, LDU, is solid there: an axle's chamfered end is not.
const END_SLACK := 2.5
## Two rounds this far into each other across the line, LDU, still pass: a
## pin's end ridge (6.5 across) in its hole (6).
const ROUND_SLACK := 0.75
## Two rounds this far into each other along the line, LDU, as they stand,
## are side by side: a flange in its counterbore.
const ALONG_SLACK := 0.05


## How far a short shaft may slide inside a longer bore of the same round on
## [param zone]'s line, staying all inside it: a piston in its cylinder.
## [Vector2(back, on) the bore may move against the shaft, the shaft's
## part], as [method _slide_on] gives them.
func _slide_within(a: int, b: int, zone: Array) -> Array:
	var point: Vector3 = zone[0]
	var way: Vector3 = (zone[1] as Vector3).normalized()
	var rounds: Dictionary = {}   ## key -> Array of [kind, span, radius]
	for key: int in [a, b]:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var mine: Array = []
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "shaft" and connector.kind != "bore":
				continue
			var start: Vector3 = brick.transform * connector.position
			var end: Vector3 = brick.transform * (connector.position + connector.axis * connector.length)
			if not _same_line(start, (end - start).normalized(), point, way):
				continue
			var s: float = (start - point).dot(way)
			var e: float = (end - point).dot(way)
			mine.append([connector.kind, Vector2(minf(s, e), maxf(s, e)), connector.radius])
		rounds[key] = mine
	for pair: Array in [[a, b], [b, a]]:
		for shaft: Array in rounds[pair[0]]:
			if shaft[0] != "shaft":
				continue
			for bore: Array in rounds[pair[1]]:
				if bore[0] != "bore" or absf(float(shaft[2]) - float(bore[2])) > Joints.ROUND_FIT:
					continue
				# Every shaft of that round on the line, as one.
				var s: Vector2 = shaft[1]
				for more: Array in rounds[pair[0]]:
					if more[0] == "shaft" and absf(float(more[2]) - float(shaft[2])) <= Joints.ROUND_FIT:
						s = Vector2(minf(s.x, (more[1] as Vector2).x), maxf(s.y, (more[1] as Vector2).y))
				var o: Vector2 = bore[1]
				if o.y - o.x <= s.y - s.x:
					continue
				var back: float = maxf(o.y - s.y, 0.0)
				var on: float = maxf(s.x - o.x, 0.0)
				if back + on > 4.0:
					return [Vector2(back, on), pair[0]]
	return [Vector2.ZERO, 0]


## The line of two bores of [param mesh] at [param at] that [param middle]
## lies on and between, each no wider than a pin's: a piston's slots for its
## connecting rod. ZERO when none.
static func _bores_across(at: Transform3D, mesh: Lbm.PartMesh, middle: Vector3) -> Vector3:
	var spans: Array = []   ## [way, lo, hi]
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "bore" or connector.radius > 4.0:
			continue
		var start: Vector3 = at * connector.position
		var way: Vector3 = (at.basis * connector.axis).normalized()
		var gap: Vector3 = middle - start
		if (gap - way * gap.dot(way)).length() > Joints.ROUND_OFF_AXIS:
			continue
		var s: float = (start - middle).dot(way)
		var e: float = s + connector.length
		spans.append([way, minf(s, e), maxf(s, e)])
	for one: Array in spans:
		if float(one[1]) <= 0.0 and float(one[2]) >= 0.0:
			return one[0]
		for other: Array in spans:
			if absf((one[0] as Vector3).dot(other[0])) > 0.99 \
					and float(one[2]) <= 0.5 and float(other[1]) >= -0.5 \
					and ((one[0] as Vector3).dot(other[0]) > 0.0):
				return one[0]
	return Vector3.ZERO


## Which of [param ids] a stud at [param foot] pointing [param way] is in:
## the one whose face it meets is nearest the stud's foot. A turntable's top
## and base share cells round their middle, and the lattice answers one of
## them for a stud of the chassis under the base. But where that one has no
## socket at all, and so would hold nothing, the one the lattice answered
## ([param ids][0]) when one of BrickNet's holes of it takes the stud ([method
## _in_a_hole_exactly], G13): a train's buffer beam (4022) hangs 32 LDU below
## the holes in its cap that take the plate's studs, and its coupling, hinged
## to it, reaches lower than the studs by less, so by faces the studs the
## lattice found in the beam were put in the coupling, and held nothing.
func _sits_on(foot: Vector3, way: Vector3, ids: Array) -> int:
	var best: int = _nearest_face(foot, way, ids)
	var found: BrickWorld.Brick = world.get_brick(int(ids[0]))
	if best != int(ids[0]) and _no_sockets(best) and found != null and _in_a_hole_exactly(found, foot, way):
		return int(ids[0])
	return best


## Of [param ids], the one whose face a stud at [param foot] pointing
## [param way] meets nearest its foot, and of two alike the one that reaches
## least far past it ([method _sits_on]).
func _nearest_face(foot: Vector3, way: Vector3, ids: Array) -> int:
	var best: int = int(ids[0])
	var nearest: float = INF
	for key: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			continue
		var box: AABB = brick.transform * mesh.bounds
		# The face it meets nearest its foot, and of two alike the one that
		# reaches least far past it: a turntable's base, not its top.
		var face: float = box.position.y if way.y > 0.0 else box.end.y
		var score: float = absf(face - foot.y) * 1000.0 \
			+ (box.end.y - foot.y if way.y > 0.0 else foot.y - box.position.y)
		if absf(way.y) < 0.9:
			score = box.get_center().distance_to(foot)
		if score < nearest - 0.01:
			nearest = score
			best = key
	return best


## Whether a stud at [param foot] is in one of [param key]'s sockets: a part
## that takes studs from below, not a tyre the baseplate's studs touch.
func _in_a_socket(key: int, foot: Vector3) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(key)
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	if mesh == null:
		return false
	for socket: Vector2 in mesh.sockets:
		var at: Vector3 = brick.transform * Vector3(socket.x, mesh.bounds.position.y, socket.y)
		if at.distance_to(foot) <= Mechanism.STUD_SLACK + 4.0:
			return true
	return false


## Whether a stud at [param foot] pointing [param way] reaches into
## [param key]'s own box, a cell's slack round it, as the part is turned.
func _reaches_into(key: int, foot: Vector3, way: Vector3) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(key)
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	if mesh == null:
		return true
	return mesh.bounds.grow(BrickLattice.CELL).has_point(
		brick.transform.affine_inverse() * (foot + way * Joints.STUD_REACH))


## Whether [param key] has nothing underneath to take a stud: no socket.
func _no_sockets(key: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(key)
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	return mesh != null and mesh.sockets.is_empty()


## Whether two parts stand turned to each other off the square, so their
## studs and sockets are on grids that do not meet.
func _askew(one: int, other: int) -> bool:
	var a: BrickWorld.Brick = world.get_brick(one)
	var b: BrickWorld.Brick = world.get_brick(other)
	return a != null and b != null and not BrickLattice.is_square_to_grid(
		a.transform.basis.inverse() * b.transform.basis)


## Whether a stud at [param foot] pointing [param way] goes into something of
## [param key] that takes it: one of its sockets, or a pin hole or an axle
## hole it points along.
func _takes_stud(key: int, foot: Vector3, way: Vector3) -> bool:
	if _in_a_socket(key, foot):
		return true
	var brick: BrickWorld.Brick = world.get_brick(key)
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	if mesh == null:
		return false
	var tip: Vector3 = foot + way * Joints.STUD_REACH
	for end: JointSnap.End in JointSnap.ends_of(mesh):
		if not end.is_hole():
			continue
		var hole: JointSnap.End = end.placed(brick.transform, key)
		if absf(hole.axis.dot(way)) < 0.99:
			continue
		var gap: Vector3 = tip - hole.at
		var along: float = gap.dot(hole.axis)
		if absf(along) <= hole.reach + 1.0 and (gap - hole.axis * along).length() <= 2.0:
			return true
	return _in_a_hole_exactly(brick, foot, way)


## Whether a stud at [param foot] pointing [param way] is in one of BrickNet's
## holes of [param brick] (Exact's connectors: a hole or a tube taking a stud
## within POS_THR of the stud's line, pointing its way). The catalogue's
## sockets are read off a part's bottom face, and a socket higher up is not
## one: a train's buffer beam (4022) sits on the four end studs of the plate
## under it by the holes in its cap, 32 LDU above its bottom. Read as studs
## pressed on a face, the beam was a body of its own, hung on its coupling,
## and stayed where it stood when its bogie turned: six trains' bogies met
## their own beam at the first degree (G13, MECHANISMS §22).
func _in_a_hole_exactly(brick: BrickWorld.Brick, foot: Vector3, way: Vector3) -> bool:
	var shape: Exact.Shape = Exact.shape_for(library, brick.part_id)
	if shape == null:
		return false
	for k: int in shape.connector_count():
		if shape.kind[k] != Exact.HOLE or not (shape.sub[k] in [Exact.S_HOLE, Exact.S_TUBE]):
			continue
		var frame: Transform3D = brick.transform * shape.frames[k]
		if (-frame.basis.y).normalized().dot(way) < Exact.AXIS_THR:
			continue
		var gap: Vector3 = frame.origin - foot
		var along: float = clampf(gap.dot(way), 0.0, Joints.STUD_REACH)
		if (gap - way * along).length() <= Exact.POS_THR:
			return true
	return false


## The studs of [param low] pointing up into [param high]'s foot: each
## [where, way], their tips inside its box and no more than a plate above
## its bottom.
func _studs_under(low: int, high: int) -> Array:
	var under: BrickWorld.Brick = world.get_brick(low)
	var over: BrickWorld.Brick = world.get_brick(high)
	var mesh: Lbm.PartMesh = library.mesh_for(under.part_id)
	var top: Lbm.PartMesh = library.mesh_for(over.part_id)
	if mesh == null or top == null:
		return []
	var box: AABB = (over.transform * top.bounds).grow(1.0)
	var out: Array = []
	# Its foot on the studs' foot: an arm hanging down past a minifigure's
	# hips holds their studs inside its box, and is not on them.
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var way: Vector3 = (under.transform.basis * connector.axis).normalized()
		if way.y < 0.9:
			continue
		var foot: Vector3 = under.transform * connector.position
		var tip: Vector3 = foot + way * Joints.STUD_REACH
		if box.has_point(tip) and absf(box.position.y + 1.0 - foot.y) <= 1.5:
			out.append([foot, way])
	return out


## The hinge BrickNet's labels name between parts [param a] and [param b]:
## [where, its line], or empty. Two hinge connectors of one subtype and
## opposite halves, within Exact.POS_THR and on one line (Exact.meets). Off
## the main thread, only the shapes already read.
func _labelled_hinge(a: int, b: int) -> Array:
	var main: bool = OS.get_thread_caller_id() == OS.get_main_thread_id()
	var items: Array = []
	for key: int in [a, b]:
		var brick: BrickWorld.Brick = world.get_brick(key)
		if brick == null or (not main and not Exact.known(library, brick.part_id)):
			return []
		var shape: Exact.Shape = Exact.shape_for(library, brick.part_id)
		if shape == null or not shape.kind.has(Exact.HINGE):
			return []
		items.append(Exact.Item.new(shape, brick.transform))
	for one: Array in (items[0] as Exact.Item).world():
		if (items[0] as Exact.Item).shape.kind[int(one[0])] != Exact.HINGE:
			continue
		for other: Array in (items[1] as Exact.Item).world():
			if (items[1] as Exact.Item).shape.kind[int(other[0])] != Exact.HINGE:
				continue
			if Exact.meets(items, [0, one[0], one[1], one[2], one[3]], [1, other[0], other[1], other[2], other[3]]):
				return [one[1], one[2]]
	return []


## Whether [param key] is in its piece's biggest body ([param staying]:
## piece in [param up] -> that body's root), which stays as the anchor is
## chosen.
func _stays(key: int, up: Dictionary, staying: Dictionary) -> bool:
	var root: int = _find(key)
	return int(staying.get(Bodies._piece_find(up, root), -1)) == root


## Whether [param key] is a door, a hatch, a lid or the like by its name.
func _door(key: int) -> bool:
	var info: PartLibrary.PartInfo = _info(key)
	return info != null and Playable.door_named(info.name)


## The middle of the ball that is in the other's socket: a plate with two
## balls turned about the wrong one ran its wing into the fuselage at once.
func _ball_middle(a: int, b: int) -> Vector3:
	var balls: Array = []
	var sockets: Array = []
	for key: int in [a, b]:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "ball":
				balls.append(brick.transform * connector.position)
			elif connector.kind == "socket":
				sockets.append(brick.transform * connector.position)
			elif connector.kind == "bore" and absf(connector.radius - Joints.BALL_RADIUS) <= Joints.ROUND_FIT * 0.5 \
					and connector.length > 0.0 and connector.length <= Joints.BALL_RADIUS * 2.0:
				# A socket drawn as plain rounds, as Joints.balls reads one: 8448-1's
				# suspension arms (32195a) on a steering arm's three balls (32186).
				# Not counted, both arms were put on its first ball, and the
				# parallelogram they make with the chassis read as held.
				sockets.append(brick.transform * (connector.position + connector.axis * connector.length * 0.5))
	var best: Vector3 = balls[0] if not balls.is_empty() else world.get_brick(a).transform.origin
	var nearest: float = INF
	for ball: Vector3 in balls:
		for socket: Vector3 in sockets:
			if ball.distance_to(socket) < nearest:
				nearest = ball.distance_to(socket)
				best = ball
	return best


static func _one_line(c: Array, d: Array) -> bool:
	var u: Vector3 = c[4]
	var v: Vector3 = d[4]
	if u == Vector3.ZERO or v == Vector3.ZERO:
		# A ball and anything else between the same two bodies holds them,
		# unless it is the same ball.
		return u == v and (c[3] as Vector3).distance_to(d[3]) < SAME_LINE
	return _same_line(c[3], u, d[3], v)


static func _same_line(p: Vector3, u: Vector3, q: Vector3, v: Vector3) -> bool:
	if absf(u.normalized().dot(v.normalized())) < 0.995:
		return false
	var gap: Vector3 = q - p
	var off: Vector3 = gap - u.normalized() * gap.dot(u.normalized())
	return off.length() < SAME_LINE


## What a probe and a session read: bodies, joints, anchors.
func summary() -> String:
	var kinds: Dictionary = {}
	for link: Link in links:
		kinds[link.kind] = int(kinds.get(link.kind, 0)) + 1
	return "%d bodies, %d joints %s, %d anchor%s, %d loop%s (%d ms)" % [members.size(),
		links.size(), str(kinds), anchors.size(), "" if anchors.size() == 1 else "s",
		closing.size(), "" if closing.size() == 1 else "s", took_ms]
