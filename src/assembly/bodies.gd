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

	func other(body: int) -> int:
		return b if body == a else a

	## "on its hinge", "on its turntable", "on a pin without friction".
	func words() -> String:
		match kind:
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
## The world revision this was read at.
var revision: int = -1
## How long the reading took, ms.
var took_ms: int = 0

var _up: Dictionary = {}
var _standing: Dictionary = {}   ## brick id -> true: on the baseplate's studs


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

	# Pins and axles.
	var shaft_lines: Dictionary = {}
	var pin_rows: Dictionary = {}   ## pin -> the parts it is in
	for one: Array in Joints.through(entries):
		var a: int = int(one[0])
		var b: int = int(one[1])
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
			if done.has(pair) or shaft_lines.has(pair):
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
			if names.contains("tyre") or names.contains("tire "):
				_join(a, b)
				continue
			# A clip, or a minifigure's hand, slides along the bar it holds;
			# a hinge's pin and a head on its neck do not.
			var slide_and_shaft: Array = [Vector2.ZERO, 0]
			if names.contains("clip") or names.contains("minifig hand"):
				slide_and_shaft = _slide_on(a, b, zone)
			candidates.append([a, b, kind, zone[0], (zone[1] as Vector3).normalized(), holds,
				detent, slide_and_shaft[0], slide_and_shaft[1]])

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

	# Studs: two or more between two parts hold them; one alone turns when
	# either is a single stud across.
	var per_pair: Dictionary = {}   ## Vector2i -> Array of [point, way]
	var studs: Array = Joints.studs_in(entries + floor_entries, func(tip: Vector3, key: Variant) -> Variant:
		var there: int = lattice.brick_at(BrickLattice.to_cell(tip))
		return there if there != 0 and there != int(key) else null)
	for stud: Array in studs:
		var a: int = int(stud[0])
		var b: int = int(stud[1])
		if scenery.has(a) or scenery.has(b):
			_standing[b if scenery.has(a) else a] = true
			continue
		if not _up.has(a) or not _up.has(b):
			continue
		var pair := Vector2i(mini(a, b), maxi(a, b))
		if not per_pair.has(pair):
			per_pair[pair] = []
		(per_pair[pair] as Array).append([stud[2], stud[3]])
	var turning: Dictionary = {}
	for c: Array in candidates:
		turning[Vector2i(mini(int(c[0]), int(c[1])), maxi(int(c[0]), int(c[1])))] = true
	# A stud between two parts that already turn on a round (a turntable's
	# top on its base's middle, read as a stud too) is that round's.
	for pair: Vector2i in per_pair:
		var found: Array = per_pair[pair]
		if found.size() == 1 and turning.has(pair):
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

	# A pin keyed to nothing is part of the first thing it is in, and what
	# else it is in turns against that on its line (Mechanism's rule): a
	# beam pinned to a frame turns on the frame, the pin with the frame.
	var sizes: Dictionary = {}
	for entry: Array in entries:
		var root: int = _find(int(entry[0]))
		sizes[root] = int(sizes.get(root, 0)) + 1
	for pin: int in pin_rows:
		if int(sizes.get(_find(pin), 1)) == 1:
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
				closing.append(link)
				continue
			reached[next] = true
			parent_link[next] = link
			parent_of[next] = at
			if not children.has(at):
				children[at] = []
			(children[at] as Array).append(next)
			queue.append(next)


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
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var way: Vector3 = (under.transform.basis * connector.axis).normalized()
		if way.y < 0.9:
			continue
		var foot: Vector3 = under.transform * connector.position
		var tip: Vector3 = foot + way * Joints.STUD_REACH
		if box.has_point(tip) and tip.y - box.position.y < BrickLattice.PLATE + 1.0:
			out.append([foot, way])
	return out


func _ball_middle(a: int, b: int) -> Vector3:
	for key: int in [a, b]:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "ball":
				return brick.transform * connector.position
	return world.get_brick(a).transform.origin


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
