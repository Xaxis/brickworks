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
## (Lock parts) anchors its body; else the bodies standing on the baseplate's
## studs; else the heaviest body. A car's chassis stays and its wheels turn;
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


func _join(one: int, other: int) -> bool:
	var a: int = _find(one)
	var b: int = _find(other)
	if a == b:
		return false
	if a < b:
		_up[b] = a
	else:
		_up[a] = b
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
	for c: Array in _actuators(entries):
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
		part_of[int(entry[0])] = str(entry[3])

	# Pins and axles.
	var shaft_lines: Dictionary = {}
	var pin_rows: Dictionary = {}   ## pin -> the parts it is in
	for one: Array in Joints.through(entries):
		var a: int = int(one[0])
		var b: int = int(one[1])
		if acting.has(Vector2i(mini(a, b), maxi(a, b))):
			continue
		if str(one[2]) == "grips":
			_join(a, b)
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
				_join(a, b)
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
				detent, slide_and_shaft[0], slide_and_shaft[1], float(zone[4]) if zone.size() > 4 else 0.0])

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
	# The baseplate's own studs are not asked: a 48 x 48 plate has 2,304,
	# and the lattice's answer under a big model's turned parts took 36 s at
	# 1,300 parts. What stands on it is found from the parts' feet instead
	# ([method _on_the_floor]).
	var studs: Array = Joints.studs_in(entries + floor_entries, func(tip: Vector3, key: Variant) -> Variant:
		var there: int = lattice.brick_at(BrickLattice.to_cell(tip))
		return there if there != 0 and there != int(key) else null)
	# Which parts turn against which: a stud reaching into one of them may be
	# in the other, the two sharing cells round their joint.
	var partners: Dictionary = {}   ## id -> Array of ids it turns against
	for c: Array in candidates:
		for ends: Array in [[int(c[0]), int(c[1])], [int(c[1]), int(c[0])]]:
			if not partners.has(ends[0]):
				partners[ends[0]] = []
			(partners[ends[0]] as Array).append(ends[1])
	var askew: Dictionary = {}   ## pair -> its studs into a part askew to them, in no socket or hole
	for stud: Array in studs:
		var a: int = int(stud[0])
		var b: int = int(stud[1])
		if partners.has(b):
			b = _sits_on(stud[2], stud[3], [b] + (partners[b] as Array))
		if scenery.has(a) or scenery.has(b):
			# On the baseplate's studs: a stud in one of its sockets, not a
			# tyre the plate's studs touch.
			var on: int = b if scenery.has(a) else a
			if not scenery.has(on) and _in_a_socket(on, stud[2]):
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
		if _askew(a, b) and not _takes_stud(b, stud[2], stud[3]):
			askew[pair] = int(askew.get(pair, 0)) + 1
		if not per_pair.has(pair):
			per_pair[pair] = []
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
			if not under.is_empty():
				per_pair[pair] = under
				_resting[pair] = true
	# A turntable's top on its base, a hinge brick's halves, a click hinge's
	# two parts: the joint between them is what holds them, whatever studs
	# or cells they also share.
	for pair: Vector2i in per_pair:
		var found: Array = per_pair[pair]
		if turning.has(pair):
			continue
		if found.size() == 1 and (_one_stud(info_of.get(pair.x)) or _one_stud(info_of.get(pair.y))):
			candidates.append([pair.x, pair.y, "stud", found[0][0], found[0][1], true, 0.0,
				Vector2.ZERO, 0])
		else:
			_join(pair.x, pair.y)

	# Glue, magnets, one thing in pieces.
	var stuck: Dictionary = Joints.held_otherwise(entries, library)
	for one: Variant in stuck:
		for other: Variant in stuck[one]:
			if _up.has(int(one)) and _up.has(int(other)):
				_join(int(one), int(other))

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
	var lone: Array = []
	for pin: int in pin_rows:
		if int(sizes.get(_find(pin), 1)) == 1:
			lone.append(pin)
	for pin: int in lone:
		_join(pin, int((pin_rows[pin] as Array)[0]))
	# Two joints between the same two bodies on different lines hold them.
	var changed: bool = true
	while changed:
		changed = false
		var by_pair: Dictionary = {}
		for c: Array in candidates:
			var x: int = _find(int(c[0]))
			var y: int = _find(int(c[1]))
			if x == y:
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
					changed = _join(int(first[0]), int(first[1])) or changed
					break

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
			link.turns = not (str(c[2]) in ["actuator", "cylinder"])
			link.radius = float(c[9]) if c.size() > 9 else 0.0
			made[pair] = link
			links.append(link)
			for end: int in [x, y]:
				if not touching.has(end):
					touching[end] = []
				(touching[end] as Array).append(link)
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
		if best == 0:
			continue
		var into: int = Bodies._piece_find(up, _find(best))
		_join(from, best)
		lodged_in[from] = best
		var root: int = _find(from)
		if not up.has(root):
			up[root] = root
		Bodies._piece_join(up, root, into)
		Bodies._piece_join(up, root, piece)
		lodged += 1


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
	for piece: Array in pieces:
		var chosen: Array = []
		for body: int in piece:
			for key: int in members[body]:
				if locked.has(key):
					chosen.append(body)
					break
		if chosen.is_empty():
			for body: int in piece:
				for key: int in members[body]:
					if _standing.has(key):
						chosen.append(body)
						break
		if chosen.is_empty():
			var best: int = piece[0]
			for body: int in piece:
				if float(grams.get(body, 0.0)) > float(grams.get(best, 0.0)) \
						or (is_equal_approx(float(grams.get(body, 0.0)), float(grams.get(best, 0.0)))
							and body < best):
					best = body
			chosen.append(best)
		for body: int in chosen:
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
		if rod_parts.has(str(entry[3])):
			if not rods.has(str(entry[3])):
				rods[str(entry[3])] = []
			(rods[str(entry[3])] as Array).append(entry)
	for entry: Array in entries:
		var spec: Dictionary = table.get(str(entry[3]), {})
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
		# The bore's middle stays on the shaft.
		var middle: float = (o.x + o.y) * 0.5
		var back: float = maxf(middle - s.x, 0.0)
		var on: float = maxf(s.y - middle, 0.0)
		if back + on > 4.0:
			return [Vector2(back, on), pair[0]]
	return [Vector2.ZERO, 0]


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
## them for a stud of the chassis under the base.
func _sits_on(foot: Vector3, way: Vector3, ids: Array) -> int:
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


## The parts standing on the baseplate's studs: a part that takes studs
## from below (it has sockets), its foot on the plate's top and over it. A
## tyre resting on the plate has no socket and is not; a wheel turns on its
## axle under the chassis that stands.
func _on_the_floor(entries: Array, floor_entries: Array) -> void:
	var plates: Array = []   ## [top, AABB]
	for entry: Array in floor_entries:
		var box: AABB = (entry[1] as Transform3D) * (entry[2] as Lbm.PartMesh).bounds
		plates.append([box.end.y - BrickLattice.PLATE * 0.5, box])
	if plates.is_empty():
		return
	for entry: Array in entries:
		var mesh: Lbm.PartMesh = entry[2]
		if mesh.sockets.is_empty():
			continue
		var at: Transform3D = entry[1]
		var box: AABB = at * mesh.bounds
		for n: int in plates.size():
			var plate: Array = plates[n]
			var over: AABB = plate[1]
			# The studs stand half a plate proud of the plate: a part on them
			# has its foot at their foot, and a socket of it on one of them.
			if absf(box.position.y - float(plate[0])) > 2.5 \
					or box.position.x >= over.end.x or box.end.x <= over.position.x \
					or box.position.z >= over.end.z or box.end.z <= over.position.z:
				continue
			var local: Transform3D = (floor_entries[n][1] as Transform3D).affine_inverse()
			var on_a_stud: bool = false
			for socket: Vector2 in mesh.sockets:
				var p: Vector3 = local * (at * Vector3(socket.x, mesh.bounds.position.y, socket.y))
				# A baseplate's studs are half a stud off its middle, 20 apart:
				# the floor's plates are a whole number of eights across.
				var dx: float = fposmod(p.x - 10.0, 20.0)
				var dz: float = fposmod(p.z - 10.0, 20.0)
				if (dx <= 1.5 or dx >= 18.5) and (dz <= 1.5 or dz >= 18.5):
					on_a_stud = true
					break
			if on_a_stud:
				_standing[int(entry[0])] = true
				break


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
