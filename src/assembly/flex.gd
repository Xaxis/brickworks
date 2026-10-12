## Flexible parts laid along a path: hoses, tubes, a flexible axle and a
## string swept from their segments, and chains and treads put on their
## sprockets link by link. BrickLink Studio has flex tools for this; until
## now a hose here could only be the straight part LDraw draws.
##
## LDraw has no bent hose. What it has, and what every tool that bends one
## writes, is the part's own segments placed along the bend: a ribbed
## hose is an end, a run of 6.25-LDU rings and an end (71944k01, k02); a
## pneumatic tube or a flex-system hose is two end caps and a one-LDU
## piece of tube scaled to length (71533k03, 77); a string is its two stud
## ends and 6-LDU braids (71149). So a bent hose here is those segments,
## and a file written with one is read by LDView, LDCad and Studio as the
## hose it is. A chain is its links (3711), each on the last one's pins.
##
## Everything in this file is pure: it takes where the ends are and hands
## back what goes where. Putting it in the model, picking the ends and
## dragging the bend are FlexTool's (src/ui/flex_tool.gd).
class_name Flex
extends RefCounted

## The distance from one link's pins to the next's: 3711 and 3873 both
## hook onto the pins 16 LDU along their own -z.
const CHAIN_PITCH := 16.0
## The most a scaled piece of tube turns from the last, in degrees: at the
## tightest bend a tube is allowed, the gap this leaves on the outside of
## a joint is a tenth of an LDU.
const PIECE_TURN := 4.0
## And the longest one along a straight run, in LDU.
const PIECE_LONGEST := 80.0
## How finely a path is sampled, in LDU.
const SAMPLE := 0.75

## What can be laid. Each kind's parts and how they go together, in the
## app's own coordinates (+Y up; see tools/ldraw/meshfile.py), measured
## off the straight parts LDraw ships:
##
##   family    "pitched": rings of [member segment] every [member pitch]
##             along the path, an [member end] at each tip.
##             "scaled": [member middle] stretched piece by piece along the
##             path, an end cap at each tip.
##             "links": a closed loop of [member link] over sprockets.
##   real      the name the straight parts have in the library, for their
##             lengths: "Technic Ribbed Hose 6L" is 117.5 LDU tip to tip.
##   bend      the tightest radius it bends to, in LDU, from the real part
##             in the hand: a ribbed hose turns round a stud, a pneumatic
##             tube kinks inside two.
##   takes     the connectors its ends go on.
##   insert    how far into a hole an end goes: "half" to the hole's
##             middle, "through" out of the far side, "face" to the mouth.
const KINDS: Dictionary = {
	"ribbed_hose": {
		"label": "Ribbed hose", "family": "pitched", "real": "Technic Ribbed Hose",
		"segment": "71944k02", "end": "71944k01", "pitch": 6.25, "tip": 2.5,
		"radius": 9.0, "bend": 12.0, "insert": "face",
		"takes": ["pin", "axle", "pin_hole", "axle_hole"],
	},
	"pneumatic_tube": {
		"label": "Pneumatic tube", "family": "scaled", "real": "Technic Pneumatic Tube",
		"middle": "71533k03", "end": "71533k02", "native": 1.0, "along": "y",
		"radius": 5.0, "bend": 18.0, "insert": "half",
		"takes": ["pin_hole", "nozzle"],
	},
	"flex_hose": {
		"label": "Flex-system hose", "family": "scaled", "real": "Technic Flex-System Hose",
		"middle": "77", "end": "u9053", "native": 1.0, "along": "y",
		"radius": 4.0, "bend": 16.0, "insert": "half",
		"takes": ["pin_hole", "clip"],
	},
	"flex_axle": {
		"label": "Flexible axle", "family": "scaled", "real": "Technic Axle Flexible 26",
		"middle": "u9012", "native": 360.0, "along": "x",
		"ends": ["u9011", "u9010"], "rigid": [60.0, 116.0], "overlap": 10.0,
		"radius": 3.5, "bend": 30.0, "insert": "through",
		"takes": ["axle_hole", "pin_hole"],
	},
	"string": {
		"label": "String with end studs", "family": "pitched", "real": "String Braided",
		"segment": "71149k02", "end": "71149k01", "pitch": 6.0, "along": "x",
		"radius": 1.5, "bend": 2.0, "hangs": true,
		"takes": ["stud"],
	},
	"chain": {
		"label": "Technic chain", "family": "links", "link": "3711",
		"real": "Technic Chain Link",
	},
	"tread": {
		"label": "Technic tread", "family": "links", "link": "3873",
		"real": "Technic Chain Tread 2.5 Wide",
	},
}

## What a chain or a tread runs on: part -> how many links go round it. A
## Technic gear takes a chain on every other tooth; the tread sprocket's
## ten teeth take ten.
const SPROCKETS: Dictionary = {
	"3647": 4, "10928": 4, "11955": 4,
	"4019": 8, "94925": 8, "18946": 8,
	"3648a": 12, "3648b": 12, "24505": 12, "2471": 12,
	"3649": 20, "34432": 20,
	"32007": 10,
}


# -- where a flexible part can go ---------------------------------------------


## A connector a flexible part's end can go on, in the world.
class Anchor extends RefCounted:
	var brick: int = 0
	## pin_hole, axle_hole, clip (a bore a bar's size), pin, axle, nozzle
	## or stud.
	var kind: String = ""
	## A hole's or a clip's middle; a pin's or an axle's collar; a stud's
	## foot.
	var at: Vector3
	## Unit. A hole's either way along it; out of the part otherwise.
	var axis: Vector3
	## A hole's half depth; how far a pin or an axle stands out.
	var reach: float = 0.0

	func is_hole() -> bool:
		return kind == "pin_hole" or kind == "axle_hole" or kind == "clip"

	func is_male() -> bool:
		return kind == "pin" or kind == "axle" or kind == "nozzle"

	## Where it is to look at and aim at: a hole's middle, the middle of a
	## pin's free length, a stud's top.
	func middle() -> Vector3:
		if is_male():
			return at + axis * reach * 0.5
		if kind == "stud":
			return at + axis * 2.0
		return at


## The end of a flexible part, resolved: where its tip is, which way it
## leaves, and how far it runs straight before it may bend.
class Port extends RefCounted:
	var tip: Vector3
	## Unit: the way the part leaves the tip, out of the connector.
	var out: Vector3
	var lead: float = 0.0
	var anchor: Anchor = null
	## Which face of a hole, +1 along its axis or -1.
	var side: int = 1

	func start() -> Vector3:
		return tip + out * lead


## Every connector each kind's ends can go on, for one part placed at
## [param where] as brick [param brick_id].
static func anchors_of(part: Lbm.PartMesh, where: Transform3D, brick_id: int,
		pneumatic: bool = false) -> Array:
	var out: Array = []
	if part == null:
		return out
	for end: JointSnap.End in JointSnap.ends_of(part):
		var anchor := Anchor.new()
		anchor.brick = brick_id
		var placed: JointSnap.End = end.placed(where, brick_id)
		anchor.axis = placed.axis
		match end.kind:
			"pin_hole", "axle_hole":
				anchor.kind = end.kind
				anchor.at = placed.at
				anchor.reach = placed.reach
			"pin", "axle":
				anchor.kind = end.kind
				anchor.at = placed.at
				anchor.reach = placed.reach
			"bore":
				anchor.kind = "clip"
				anchor.at = placed.at + placed.axis * placed.reach * 0.5
				anchor.reach = placed.reach * 0.5
			_:
				continue
		out.append(anchor)
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == "stud" and connector.gender == "male":
			var stud := Anchor.new()
			stud.brick = brick_id
			stud.kind = "stud"
			stud.at = where * connector.position
			stud.axis = (where.basis * connector.axis).normalized()
			out.append(stud)
		elif pneumatic and connector.kind == "shaft" and connector.radius >= 2.0 \
				and connector.radius <= 3.6 and connector.length >= 3.0:
			# A pneumatic part's outlet: a nozzle a tube is pushed over.
			var nozzle := Anchor.new()
			nozzle.brick = brick_id
			nozzle.kind = "nozzle"
			nozzle.at = where * connector.position
			var tip: Vector3 = where * (connector.position + connector.axis * connector.length)
			nozzle.axis = (tip - nozzle.at).normalized()
			nozzle.reach = connector.length
			out.append(nozzle)
	return out


## Every anchor in the world a kind's ends can go on, but none on the
## bricks in [param skip].
static func anchors_in(world: BrickWorld, library: PartLibrary, kind: String,
		skip: Dictionary = {}) -> Array:
	var spec: Dictionary = KINDS.get(kind, {})
	var takes: Array = spec.get("takes", [])
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id) or brick.hidden:
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var pneumatic: bool = info != null and info.name.contains("Pneumatic")
		for anchor: Anchor in anchors_of(library.mesh_for(brick.part_id), brick.transform,
				brick.id, pneumatic):
			if takes.has(anchor.kind):
				out.append(anchor)
	return out


## The anchor the pointer's line is aimed at: nearest the line within
## [param reach], no further along it than [param before], the nearer of
## two as near. Null when there is none.
static func aimed(anchors: Array, from: Vector3, way: Vector3, before: float,
		reach: float = 12.0) -> Anchor:
	var best: Anchor = null
	var best_off: float = reach
	var best_along: float = INF
	for anchor: Anchor in anchors:
		var point: Vector3 = anchor.middle()
		var along: float = (point - from).dot(way)
		if along <= 0.0 or along > before:
			continue
		var off: float = ((point - from) - way * along).length()
		if off < best_off - 0.5 or (off <= best_off + 0.5 and along < best_along):
			best = anchor
			best_off = minf(off, best_off)
			best_along = along
	return best


## Where a kind's end goes on an anchor, leaving by [param side] for a hole
## (+1 along its axis, -1 against it).
static func port_for(kind: String, anchor: Anchor, side: int, end_index: int = 0) -> Port:
	var spec: Dictionary = KINDS[kind]
	var port := Port.new()
	port.anchor = anchor
	port.side = 1 if side >= 0 else -1
	if anchor.is_hole():
		port.out = anchor.axis * float(port.side)
		match str(spec.get("insert", "half")):
			"through":
				port.tip = anchor.at - port.out * anchor.reach
				port.lead = anchor.reach * 2.0 + 2.0
			"face":
				port.tip = anchor.at + port.out * anchor.reach
				port.lead = 2.0
			_:
				port.tip = anchor.at
				port.lead = anchor.reach + 2.0
	elif anchor.is_male():
		# Over a pin, an axle or a nozzle, to its collar.
		port.out = anchor.axis
		port.tip = anchor.at
		port.lead = anchor.reach
	else:
		port.out = anchor.axis
		port.tip = anchor.at
		port.lead = 0.0
	var rigid: Array = spec.get("rigid", [])
	if rigid.size() > end_index:
		port.lead = maxf(port.lead, float(rigid[end_index]))
	return port


## A free end: a point and the way the part leaves it.
static func free_port(tip: Vector3, out: Vector3, lead: float = 0.0) -> Port:
	var port := Port.new()
	port.tip = tip
	port.out = out.normalized()
	port.lead = lead
	return port


## Which face of a hole the part should leave by, for its other end at
## [param toward]: the face looking at it, or, when the other end is off
## to the side, [param fallback].
static func side_toward(anchor: Anchor, toward: Vector3, fallback: int = 1) -> int:
	if not anchor.is_hole():
		return 1
	var gap: Vector3 = toward - anchor.at
	var along: float = gap.dot(anchor.axis)
	if absf(along) < maxf(gap.length() * 0.15, 1.0):
		return fallback
	return 1 if along > 0.0 else -1


# -- the lengths a kind comes in ----------------------------------------------


static var _lengths: Dictionary = {}


## The straight parts a kind is sold as, shortest first: [{id, name,
## length}], their length the long side of the part.
static func lengths_of(library: PartLibrary, kind: String) -> Array:
	if _lengths.has(kind):
		return _lengths[kind]
	var spec: Dictionary = KINDS.get(kind, {})
	var real: String = str(spec.get("real", ""))
	var out: Array = []
	if not real.is_empty() and str(spec.get("family", "")) != "links":
		for id: String in library.parts:
			var info: PartLibrary.PartInfo = library.parts[id]
			if not info.name.begins_with(real) or info.is_redirect() \
					or info.name.begins_with("~") or info.name.contains("Bulges") \
					or info.name.contains("Segment"):
				continue
			if kind == "pneumatic_tube" and not id.ends_with("-f1"):
				continue
			if kind == "string" and not info.name.contains("End Studs"):
				continue
			var longest: float = maxf(info.size.x, maxf(info.size.y, info.size.z))
			out.append({"id": id, "name": info.name, "length": longest})
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["length"]) < float(b["length"]))
	_lengths[kind] = out
	return out


## How long a kind's body is along its path, tip to tip, for a part as long
## as [param real] (the straight part's own length): a string's is between
## its stud ends.
static func body_length(kind: String, real: float) -> float:
	if kind == "string":
		return real - 28.0
	if kind == "flex_axle":
		return real + 1.0
	return real


# -- paths ----------------------------------------------------------------------


## A path: points along it, close enough together to be read as a curve.
class Path extends RefCounted:
	var points: PackedVector3Array = PackedVector3Array()
	## How far along it each point is.
	var along: PackedFloat64Array = PackedFloat64Array()
	var closed: bool = false

	func total() -> float:
		return along[along.size() - 1] if not along.is_empty() else 0.0

	func measure() -> void:
		along.resize(points.size())
		var run: float = 0.0
		for n: int in points.size():
			if n > 0:
				run += points[n].distance_to(points[n - 1])
			along[n] = run

	## The point [param s] along it; a closed path goes round again.
	func at(s: float) -> Vector3:
		var n: int = _index(s)
		if n < 0:
			return points[0]
		if n >= points.size() - 1:
			return points[points.size() - 1]
		var span: float = along[n + 1] - along[n]
		var t: float = 0.0 if span <= 0.0 else (_wrap(s) - along[n]) / span
		return points[n].lerp(points[n + 1], clampf(t, 0.0, 1.0))

	## Which way it runs [param s] along.
	func heading(s: float) -> Vector3:
		var n: int = clampi(_index(s), 0, points.size() - 2)
		return (points[n + 1] - points[n]).normalized()

	func _wrap(s: float) -> float:
		if closed and total() > 0.0:
			return fposmod(s, total())
		return clampf(s, 0.0, total())

	func _index(s: float) -> int:
		var want: float = _wrap(s)
		var low: int = 0
		var high: int = along.size() - 1
		if high <= 0:
			return -1
		while high - low > 1:
			var mid: int = (low + high) >> 1
			if along[mid] <= want:
				low = mid
			else:
				high = mid
		return low

	## The tightest radius it bends to, from each three points about
	## [param spacing] apart. INF on a straight path.
	func tightest(spacing: float = 2.0) -> float:
		var least: float = INF
		var length: float = total()
		if length < spacing * 2.0:
			return least
		var s: float = spacing
		var stop: float = length - spacing if not closed else length
		while s <= stop:
			var a: Vector3 = at(s - spacing)
			var b: Vector3 = at(s)
			var c: Vector3 = at(s + spacing)
			least = minf(least, Flex.circumradius(a, b, c))
			s += spacing * 0.5
		return least


## The radius of the circle through three points; INF when they are in a
## line.
static func circumradius(a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab: Vector3 = b - a
	var bc: Vector3 = c - b
	var twice_area: float = ab.cross(bc).length()
	if twice_area < 1e-9:
		return INF
	return ab.length() * bc.length() * (c - a).length() / (2.0 * twice_area)


## A smooth curve from [param from] leaving along [param leave] to
## [param to] arriving along [param arrive], through [param controls] in
## between: Hermite pieces, the tangent at either end [param k] long and
## between them Catmull-Rom's. Returned as points.
static func curve(from: Vector3, leave: Vector3, to: Vector3, arrive: Vector3,
		controls: PackedVector3Array, k: float) -> PackedVector3Array:
	var knots := PackedVector3Array([from])
	knots.append_array(controls)
	knots.append(to)
	var tangents := PackedVector3Array()
	for n: int in knots.size():
		if n == 0:
			tangents.append(leave * k)
		elif n == knots.size() - 1:
			tangents.append(arrive * k)
		else:
			tangents.append((knots[n + 1] - knots[n - 1]) * 0.5)
	var out := PackedVector3Array([from])
	for n: int in knots.size() - 1:
		var p0: Vector3 = knots[n]
		var p1: Vector3 = knots[n + 1]
		var m0: Vector3 = tangents[n]
		var m1: Vector3 = tangents[n + 1]
		var guess: float = p0.distance_to(p1) + (m0.length() + m1.length()) * 0.5
		var steps: int = clampi(ceili(guess / SAMPLE), 16, 1600)
		for step: int in range(1, steps + 1):
			var t: float = float(step) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(p0 * (2.0 * t3 - 3.0 * t2 + 1.0) + m0 * (t3 - 2.0 * t2 + t)
				+ p1 * (-2.0 * t3 + 3.0 * t2) + m1 * (t3 - t2))
	return out


static func _length_of(points: PackedVector3Array) -> float:
	var run: float = 0.0
	for n: int in range(1, points.size()):
		run += points[n].distance_to(points[n - 1])
	return run


## The whole path of a swept part: straight out of the first connector,
## the bend, straight into the second. The bend's tangents are made as
## long as it takes for the path to be [param wanted] long, tip to tip.
## Returns {path, k, short}: short when even the shortest smooth path
## between the two is longer than the part.
static func swept_path(a: Port, b: Port, controls: PackedVector3Array, wanted: float,
		hangs: bool = false, up: Vector3 = Vector3.UP) -> Dictionary:
	var from: Vector3 = a.start()
	var to: Vector3 = b.start()
	var free: float = wanted - a.lead - b.lead
	var gap: float = from.distance_to(to)
	var shaped: PackedVector3Array = controls
	var bend: PackedVector3Array
	var k: float = 0.0
	var short: bool = false
	if hangs and controls.is_empty():
		# A string hangs: its middle drops until it is as long as it is.
		var low: float = 0.0
		var high: float = maxf(free, 1.0)
		var tangent: float = gap * 0.4
		var middle: Vector3 = (from + to) * 0.5
		var shortest: float = _length_of(curve(from, a.out, to, -b.out,
			PackedVector3Array([middle]), tangent))
		short = shortest > free + 0.5
		for _round: int in 40:
			var sag: float = (low + high) * 0.5
			var trial: float = _length_of(curve(from, a.out, to, -b.out,
				PackedVector3Array([middle - up * sag]), tangent))
			if trial < free:
				low = sag
			else:
				high = sag
		var dropped: float = 0.0 if short else (low + high) * 0.5
		shaped = PackedVector3Array([middle - up * dropped])
		k = tangent
		bend = curve(from, a.out, to, -b.out, shaped, k)
	else:
		# The bend gets longer as its tangents do: find the length that
		# makes it the part's. Never shorter than a fifth of the gap, which
		# kinks it at both ends.
		var low: float = maxf(gap * 0.2, 1.0)
		var shortest: float = _length_of(curve(from, a.out, to, -b.out, shaped, low))
		if shortest >= free:
			short = shortest > free + 0.5
			k = low
		else:
			var high: float = maxf(gap, 8.0)
			var guard: int = 0
			while _length_of(curve(from, a.out, to, -b.out, shaped, high)) < free and guard < 30:
				low = high
				high *= 2.0
				guard += 1
			for _round: int in 48:
				var mid: float = (low + high) * 0.5
				if _length_of(curve(from, a.out, to, -b.out, shaped, mid)) < free:
					low = mid
				else:
					high = mid
			k = (low + high) * 0.5
		bend = curve(from, a.out, to, -b.out, shaped, k)
	var path := Path.new()
	path.points.append(a.tip)
	if a.lead > 0.001:
		var out: PackedVector3Array = _line(a.tip, from)
		for n: int in range(1, out.size()):
			path.points.append(out[n])
	for n: int in range(1, bend.size()):
		path.points.append(bend[n])
	if b.lead > 0.001:
		var back: PackedVector3Array = _line(to, b.tip)
		for n: int in range(1, back.size()):
			path.points.append(back[n])
	path.measure()
	return {"path": path, "k": k, "short": short, "controls": shaped}


static func _line(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var steps: int = maxi(ceili(from.distance_to(to) / 4.0), 1)
	for n: int in steps + 1:
		out.append(from.lerp(to, float(n) / float(steps)))
	return out


# -- frames along a path ----------------------------------------------------------


## A frame at every point of a path that turns no more than the path does
## (the double-reflection rotation-minimising frame), as each point's
## [tangent, normal]. A tube's pieces laid on it do not twist.
static func frames(path: Path, normal: Vector3 = Vector3.ZERO) -> Array:
	var out: Array = []
	var count: int = path.points.size()
	if count < 2:
		return out
	var tangent: Vector3 = (path.points[1] - path.points[0]).normalized()
	var reference: Vector3 = normal
	if reference.length_squared() < 0.5 or absf(reference.normalized().dot(tangent)) > 0.95:
		reference = Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT
	var r: Vector3 = (reference - tangent * reference.dot(tangent)).normalized()
	out.append([tangent, r])
	for n: int in range(1, count):
		var next_tangent: Vector3 = tangent
		if n < count - 1:
			next_tangent = (path.points[n + 1] - path.points[n]).normalized()
		elif n >= 1:
			next_tangent = (path.points[n] - path.points[n - 1]).normalized()
		var v1: Vector3 = path.points[n] - path.points[n - 1]
		var c1: float = v1.dot(v1)
		if c1 < 1e-12:
			out.append([next_tangent, r])
			continue
		var r_l: Vector3 = r - v1 * (2.0 / c1 * v1.dot(r))
		var t_l: Vector3 = tangent - v1 * (2.0 / c1 * v1.dot(tangent))
		var v2: Vector3 = next_tangent - t_l
		var c2: float = v2.dot(v2)
		r = r_l if c2 < 1e-12 else r_l - v2 * (2.0 / c2 * v2.dot(r_l))
		r = (r - next_tangent * r.dot(next_tangent)).normalized()
		tangent = next_tangent
		out.append([tangent, r])
	return out


## The frame of a part whose own [param axis] ("x" or "y", negative for
## its minus side) lies along [param forward], turned so its next axis is
## as near [param normal] as it can be. Unit: scale it after.
static func basis_along(forward: Vector3, normal: Vector3, axis: String) -> Basis:
	var f: Vector3 = forward.normalized()
	var n: Vector3 = (normal - f * normal.dot(f))
	if n.length_squared() < 1e-8:
		n = Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT
		n = n - f * n.dot(f)
	n = n.normalized()
	match axis:
		"x":
			# x along, y the normal, z = x × y.
			return Basis(f, n, f.cross(n))
		"-x":
			return Basis(-f, n, (-f).cross(n))
		"-y":
			# y against: the part's -y runs along. x the normal, z = x × y.
			return Basis(n, -f, n.cross(-f))
		_:
			return Basis(n, f, n.cross(f))


# -- laying a swept part -------------------------------------------------------------


## What laying a flexible part came to.
class Laid extends RefCounted:
	## {part, at: Transform3D}, in the order they run.
	var pieces: Array = []
	## How long it came out along its centreline, and how long the real
	## part is.
	var length: float = 0.0
	var wanted: float = 0.0
	## The tightest it bends, LDU.
	var tightest: float = INF
	var links: int = 0
	var path: Path
	## What a person should know: too short for the path, bent tighter
	## than it goes, a chain left slack.
	var warnings: PackedStringArray = PackedStringArray()
	## And what is worth knowing that is not wrong: how much spare a chain
	## has.
	var notes: PackedStringArray = PackedStringArray()
	var slack: float = 0.0
	## The bend points the path went through, for the handles.
	var controls: PackedVector3Array = PackedVector3Array()


## A swept kind laid from [param a] to [param b], [param real] LDU long
## as a straight part, through [param controls].
static func lay_swept(kind: String, a: Port, b: Port, real: float,
		controls: PackedVector3Array = PackedVector3Array()) -> Laid:
	var spec: Dictionary = KINDS[kind]
	var laid := Laid.new()
	laid.wanted = body_length(kind, real)
	var hangs: bool = bool(spec.get("hangs", false))
	var ends: Array = [a, b]
	if kind == "string":
		ends = [_string_port(a, b.tip), _string_port(b, a.tip)]
	var shaped: Dictionary = swept_path(ends[0], ends[1], controls, laid.wanted, hangs)
	var path: Path = shaped["path"]
	laid.path = path
	laid.controls = shaped["controls"] if hangs else controls
	laid.tightest = path.tightest(maxf(float(spec.get("radius", 4.0)) * 0.5, 1.5))
	if bool(shaped["short"]):
		laid.warnings.append("the path is longer than this %s: %.0f LDU are needed and it is %.0f"
			% [str(spec["label"]).to_lower(), path.total(), laid.wanted])
	if laid.tightest < float(spec["bend"]) - 0.25:
		laid.warnings.append("it bends tighter than a %s can, round %.0f LDU where the least is %.0f"
			% [str(spec["label"]).to_lower(), laid.tightest, float(spec["bend"])])
	match str(spec["family"]):
		"pitched":
			_pitched(kind, spec, path, ends, laid)
		"scaled":
			_scaled(spec, path, laid, Vector2((ends[0] as Port).lead, (ends[1] as Port).lead))
	return laid


## A string's end on a stud: the stud end sits on it, and the braid leaves
## sideways from its top, towards the other end.
static func _string_port(port: Port, toward: Vector3) -> Port:
	var up: Vector3 = port.out
	var level: Vector3 = toward - port.tip
	level = level - up * level.dot(up)
	if level.length_squared() < 1e-6:
		level = Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK
	level = level.normalized()
	var seat: Vector3 = port.tip + up * 8.0
	var leaving := Port.new()
	leaving.anchor = port.anchor
	leaving.tip = seat - up * 1.5 + level * 6.0
	leaving.out = level
	leaving.lead = 0.0
	leaving.side = port.side
	leaving.set_meta("seat", seat)
	leaving.set_meta("up", up)
	return leaving


static func _pitched(kind: String, spec: Dictionary, path: Path, ends: Array, laid: Laid) -> void:
	var total: float = path.total()
	var pitch: float = float(spec["pitch"])
	var turned: Array = frames(path)
	if kind == "string":
		# The braid between the two stud ends, which sit on their studs.
		var count: int = maxi(roundi(total / pitch), 1)
		var spacing: float = total / float(count)
		for end: int in 2:
			var port: Port = ends[end]
			var seat: Vector3 = port.get_meta("seat")
			var up: Vector3 = port.get_meta("up")
			var level: Vector3 = (port.tip - seat + up * 1.5).normalized()
			var basis := Basis(level, up, level.cross(up))
			laid.pieces.append({"part": spec["end"], "at": Transform3D(basis, seat)})
		for n: int in count:
			var s: float = spacing * (float(n) + 0.5)
			var frame: Array = turned[_frame_index(path, s)]
			laid.pieces.insert(laid.pieces.size() - 1, {"part": spec["segment"],
				"at": Transform3D(basis_along(path.heading(s), frame[1], "x"), path.at(s))})
		laid.length = spacing * float(count)
		return
	var tip: float = float(spec.get("tip", 0.0))
	var count: int = maxi(roundi((total - tip * 2.0) / pitch) + 1, 2)
	var spacing: float = (total - tip * 2.0) / float(count - 1)
	for n: int in count:
		var s: float = tip + spacing * float(n)
		var frame: Array = turned[_frame_index(path, s)]
		var heading: Vector3 = path.heading(s)
		var part: String = spec["segment"]
		var basis: Basis
		if n == 0 or n == count - 1:
			part = spec["end"]
			# An end's own +y runs into the hose.
			basis = basis_along(heading if n == 0 else -heading, frame[1], "y")
		else:
			basis = basis_along(heading, frame[1], "y")
		laid.pieces.append({"part": part, "at": Transform3D(basis, path.at(s))})
	laid.length = total


static func _frame_index(path: Path, s: float) -> int:
	return clampi(path._index(s), 0, path.points.size() - 1)


## A scaled kind's pieces: the path cut where it has turned
## [constant PIECE_TURN], each piece the middle part stretched from one cut
## to the next, end caps at the tips.
static func _scaled(spec: Dictionary, whole: Path, laid: Laid, leads: Vector2) -> void:
	var path: Path = whole
	if spec.has("ends"):
		# A flexible axle's ends are rigid: the tube runs only between them.
		path = _between(whole, leads.x, whole.total() - leads.y)
	var turned: Array = frames(path)
	# Cut where the way it runs has turned PIECE_TURN since the last cut, so
	# one piece turns that much from the next at most; and where a straight
	# lead into a connector ends, so the lead is a piece of its own and
	# goes into the hole straight.
	var cuts := PackedInt32Array([0])
	var started: int = 0
	var limit: float = cos(deg_to_rad(PIECE_TURN))
	var last: int = path.points.size() - 1
	var forced: Dictionary = {}
	if not spec.has("ends"):
		for s: float in [leads.x, path.total() - leads.y]:
			if s > 0.01 and s < path.total() - 0.01:
				forced[clampi(path._index(s + 0.001), 1, last - 1)] = true
	for n: int in range(1, last):
		var began: Vector3 = (path.points[started + 1] - path.points[started]).normalized()
		var now: Vector3 = (path.points[n + 1] - path.points[n]).normalized()
		if forced.has(n) or now.dot(began) < limit \
				or path.along[n] - path.along[started] > PIECE_LONGEST:
			cuts.append(n)
			started = n
	cuts.append(last)
	var along: String = str(spec.get("along", "y"))
	var native: float = float(spec.get("native", 1.0))
	var overlap: float = float(spec.get("overlap", 0.0))
	var length: float = 0.0
	for n: int in range(1, cuts.size()):
		var a: Vector3 = path.points[cuts[n - 1]]
		var b: Vector3 = path.points[cuts[n]]
		var span: float = a.distance_to(b)
		if span < 0.01:
			continue
		length += span
		var heading: Vector3 = (b - a) / span
		var normal: Vector3 = turned[cuts[n - 1]][1]
		# The tube runs on into an end by as much as the real part's does.
		if overlap > 0.0 and n == 1:
			a -= heading * overlap
			span += overlap
		if overlap > 0.0 and n == cuts.size() - 1:
			b += heading * overlap
			span += overlap
		var at: Transform3D
		if along == "x":
			var basis: Basis = basis_along(heading, normal, "x")
			basis.x *= span / native
			at = Transform3D(basis, (a + b) * 0.5)
		else:
			# A piece of tube runs from its origin along its own -y.
			var basis: Basis = basis_along(heading, normal, "-y")
			basis.y *= span / native
			at = Transform3D(basis, a)
		laid.pieces.append({"part": spec["middle"], "at": at})
	laid.length = length
	if spec.has("ends"):
		# A flexible axle's rigid ends: their own +x out along the axle, the
		# tip of each at the path's.
		laid.length = whole.total()
		var names: Array = spec["ends"]
		var rigid: Array = spec["rigid"]
		var tail: int = whole.points.size() - 1
		var first_out: Vector3 = -(whole.points[1] - whole.points[0]).normalized()
		var last_out: Vector3 = (whole.points[tail] - whole.points[tail - 1]).normalized()
		laid.pieces.push_front({"part": names[0], "at": Transform3D(
			basis_along(first_out, turned[0][1], "x"),
			whole.points[0] - first_out * float(rigid[0]))})
		laid.pieces.append({"part": names[1], "at": Transform3D(
			basis_along(last_out, turned[turned.size() - 1][1], "x"),
			whole.points[tail] - last_out * float(rigid[1]))})
	elif spec.has("end"):
		# An end cap's -y runs into the tube.
		var count: int = path.points.size()
		var into_start: Vector3 = (path.points[1] - path.points[0]).normalized()
		var into_end: Vector3 = (path.points[count - 2] - path.points[count - 1]).normalized()
		laid.pieces.push_front({"part": spec["end"], "at": Transform3D(
			basis_along(into_start, turned[0][1], "-y"), path.points[0])})
		laid.pieces.append({"part": spec["end"], "at": Transform3D(
			basis_along(into_end, turned[count - 1][1], "-y"), path.points[count - 1])})


## The part of a path from [param from] to [param to] along it.
static func _between(path: Path, from: float, to: float) -> Path:
	var out := Path.new()
	out.points.append(path.at(from))
	for n: int in path.points.size():
		if path.along[n] > from + 0.01 and path.along[n] < to - 0.01:
			out.points.append(path.points[n])
	out.points.append(path.at(to))
	out.measure()
	return out


# -- chains and treads on sprockets ------------------------------------------------


## A sprocket in the world: where its middle is, the way its axle runs,
## and the circle a chain's pins go round it on.
class Sprocket extends RefCounted:
	var brick: int = 0
	var centre: Vector3
	var axis: Vector3
	var links: int = 0
	var radius: float = 0.0


## The sprocket a brick is, or null: one of [constant SPROCKETS], its axle
## the way its axle hole runs (the thin way where it has no hole), its
## middle its box's.
static func sprocket_of(brick: BrickWorld.Brick, library: PartLibrary) -> Sprocket:
	if brick == null or not SPROCKETS.has(brick.part_id):
		return null
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if part == null:
		return null
	var local_axis := Vector3.ZERO
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == "axle_hole" or connector.kind == "pin_hole":
			local_axis = connector.axis
			break
	if local_axis.length_squared() < 0.5:
		var size: Vector3 = part.bounds.size
		local_axis = Vector3.RIGHT if size.x <= size.y and size.x <= size.z \
			else (Vector3.UP if size.y <= size.z else Vector3.BACK)
	var sprocket := Sprocket.new()
	sprocket.brick = brick.id
	sprocket.centre = brick.transform * part.bounds.get_center()
	sprocket.axis = (brick.transform.basis * local_axis).normalized()
	sprocket.links = int(SPROCKETS[brick.part_id])
	sprocket.radius = CHAIN_PITCH * 0.5 / sin(PI / float(sprocket.links))
	return sprocket


## The loop a chain makes round sprockets: their pin circles and the
## straight runs between them, the way round that keeps every sprocket
## inside. All on one plane, their axles one way; null otherwise. The
## sprockets go round in the order they lie about their middle.
## [param sag] drops the longest run, the one nearest the ground, by that
## much at its middle: a chain a little longer than the loop hangs there.
static func belt(sprockets: Array, sag: float = 0.0) -> Dictionary:
	if sprockets.size() < 2:
		return {}
	var first: Sprocket = sprockets[0]
	var axis: Vector3 = first.axis
	for other: Sprocket in sprockets:
		if absf(other.axis.dot(axis)) < 0.995:
			return {}
		if absf((other.centre - first.centre).dot(axis)) > 2.0:
			return {}
	# The plane's two ways, u then v, turning about the axle.
	var u: Vector3 = (Vector3.UP - axis * axis.dot(Vector3.UP))
	if u.length_squared() < 0.01:
		u = Vector3.RIGHT - axis * axis.x
	u = u.normalized()
	var v: Vector3 = axis.cross(u)
	var middle := Vector3.ZERO
	for one: Sprocket in sprockets:
		middle += one.centre
	middle /= float(sprockets.size())
	var order: Array = sprockets.duplicate()
	order.sort_custom(func(a: Sprocket, b: Sprocket) -> bool:
		var pa: Vector3 = a.centre - middle
		var pb: Vector3 = b.centre - middle
		return atan2(pa.dot(v), pa.dot(u)) < atan2(pb.dot(v), pb.dot(u)))
	var flat := func(point: Vector3) -> Vector2:
		var gap: Vector3 = point - first.centre
		return Vector2(gap.dot(u), gap.dot(v))
	var lift := func(point: Vector2) -> Vector3:
		return first.centre + u * point.x + v * point.y
	var count: int = order.size()
	# Going anticlockwise about the axle, the sprockets on the left, so each
	# straight run's outward normal is on its right.
	var normals: Array[Vector2] = []
	for n: int in count:
		var a: Sprocket = order[n]
		var b: Sprocket = order[(n + 1) % count]
		var gap: Vector2 = flat.call(b.centre) - flat.call(a.centre)
		var reach: float = gap.length()
		if reach < absf(a.radius - b.radius) + 0.01:
			return {}
		var theta: float = gap.angle() - acos(clampf((a.radius - b.radius) / reach, -1.0, 1.0))
		normals.append(Vector2(cos(theta), sin(theta)))
	# The longest run, the lowest of two as long: where slack hangs.
	var sagging: int = 0
	var best: float = -INF
	for n: int in count:
		var a: Sprocket = order[n]
		var b: Sprocket = order[(n + 1) % count]
		var from: Vector3 = lift.call(flat.call(a.centre) + normals[n] * a.radius)
		var to: Vector3 = lift.call(flat.call(b.centre) + normals[n] * b.radius)
		var score: float = from.distance_to(to) - ((from + to) * 0.5).y * 0.01
		if score > best:
			best = score
			sagging = n
	var path := Path.new()
	path.closed = true
	for n: int in count:
		var here: Sprocket = order[n]
		var next: Sprocket = order[(n + 1) % count]
		var came: Vector2 = normals[(n - 1 + count) % count]
		var leaves: Vector2 = normals[n]
		# Round this sprocket anticlockwise from where the last run met it.
		var start: float = came.angle()
		var sweep: float = fposmod(leaves.angle() - start, TAU)
		var steps: int = maxi(ceili(sweep * here.radius / 0.5), 1)
		var centre: Vector2 = flat.call(here.centre)
		for step: int in steps:
			var angle: float = start + sweep * float(step) / float(steps)
			path.points.append(lift.call(centre + Vector2(cos(angle), sin(angle)) * here.radius))
		# Then the straight run to the next, dropped in its middle if it is
		# the one that hangs.
		var from2: Vector2 = centre + leaves * here.radius
		var to2: Vector2 = flat.call(next.centre) + leaves * next.radius
		var run_steps: int = maxi(ceili(from2.distance_to(to2) / 1.0), 1)
		for step: int in run_steps:
			var t: float = float(step) / float(run_steps)
			var point: Vector2 = from2.lerp(to2, t)
			if n == sagging and sag > 0.0:
				point += leaves * sag * sin(PI * t)
			path.points.append(lift.call(point))
	path.points.append(path.points[0])
	path.measure()
	return {"path": path, "axis": axis, "order": order}


## Where the pins go: [param count] of them round a closed path, each
## exactly [param pitch] from the last, from [param start] along it.
## Returns the pins and how far round the last step reached, which is the
## whole way round when the loop closes.
static func walk(path: Path, pitch: float, count: int, start: float = 0.0) -> Dictionary:
	var pins := PackedVector3Array()
	var arcs := PackedFloat64Array([0.0])
	var s: float = start
	var here: Vector3 = path.at(s)
	pins.append(here)
	var total: float = path.total()
	for _link: int in count:
		s = _next_pin(path, s, here, pitch, total)
		here = path.at(s)
		pins.append(here)
		arcs.append(s - start)
	return {"pins": pins, "reached": s - start, "arcs": arcs}


## The first point after [param s] along the path exactly [param pitch]
## from [param here], found on the segment where the distance crosses it.
static func _next_pin(path: Path, s: float, here: Vector3, pitch: float, total: float) -> float:
	var step: float = 0.5
	var low: float = s
	var high: float = s + step
	var guard: int = 0
	while path.at(high).distance_to(here) < pitch and guard < 100000:
		low = high
		high += step
		guard += 1
		if high - s > total + pitch * 2.0:
			break
	for _round: int in 40:
		var mid: float = (low + high) * 0.5
		if path.at(mid).distance_to(here) < pitch:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## A chain or a tread round [param sprockets]: as many links as go round
## with a little to spare, and the spare hung in the longest run so the
## last link's pins are exactly in the first's hook.
static func lay_chain(kind: String, sprockets: Array) -> Laid:
	var spec: Dictionary = KINDS[kind]
	var laid := Laid.new()
	var taut: Dictionary = belt(sprockets)
	if taut.is_empty():
		laid.warnings.append("those sprockets are not on one plane with their axles one way")
		return laid
	var path: Path = taut["path"]
	var loop: float = path.total()
	# Links taut round it, rounded up: the chain is never shorter than the
	# loop, and what it has over hangs.
	var reach: Dictionary = walk(path, CHAIN_PITCH, ceili(loop / CHAIN_PITCH) + 2)
	var count: int = 0
	var arcs: PackedFloat64Array = reach["arcs"]
	for n: int in range(1, arcs.size()):
		if arcs[n] >= loop - 0.001:
			count = n
			break
	count = maxi(count, 3)
	var pins: PackedVector3Array
	# Hang the spare: the drop at which the count-th pin is the first.
	var low: float = 0.0
	var high: float = 0.0
	var span: float = 0.0
	for one: Sprocket in sprockets:
		span = maxf(span, one.radius)
	high = maxf(loop * 0.25, span)
	var closing: Dictionary = {}
	var hung: Path = path
	for _round: int in 60:
		var sag: float = (low + high) * 0.5
		var trial: Dictionary = belt(sprockets, sag)
		var trial_path: Path = trial["path"]
		var walked: Dictionary = walk(trial_path, CHAIN_PITCH, count)
		if float(walked["reached"]) > trial_path.total():
			low = sag
		else:
			high = sag
		hung = trial_path
		closing = walked
	var sag_made: float = (low + high) * 0.5
	var final: Dictionary = belt(sprockets, sag_made)
	hung = final["path"]
	closing = walk(hung, CHAIN_PITCH, count)
	laid.path = hung
	pins = closing["pins"]
	var axis: Vector3 = final["axis"]
	# Which way round the pins go about the axle, so each link's +y (a
	# tread's face) is out.
	var turning: float = 0.0
	var middle := Vector3.ZERO
	for one: Sprocket in sprockets:
		middle += one.centre
	middle /= float(sprockets.size())
	for n: int in count:
		turning += (pins[n] - middle).cross(pins[n + 1] - middle).dot(axis)
	var across: Vector3 = -axis if turning > 0.0 else axis
	for n: int in count:
		var here: Vector3 = pins[n]
		var next: Vector3 = pins[n + 1] if n + 1 < count else pins[0]
		var z: Vector3 = -(next - here).normalized()
		var x: Vector3 = (across - z * across.dot(z)).normalized()
		var y: Vector3 = z.cross(x)
		laid.pieces.append({"part": spec["link"], "at": Transform3D(Basis(x, y, z), here)})
	laid.links = count
	laid.length = float(count) * CHAIN_PITCH
	laid.wanted = loop
	laid.tightest = hung.tightest(1.0)
	var gap: float = pins[count].distance_to(pins[0])
	if gap > 0.05:
		laid.warnings.append("the loop does not close: %.2f LDU between the last link and the first" % gap)
	laid.slack = laid.length - loop
	if sag_made > CHAIN_PITCH:
		laid.notes.append("%d links, %.0f LDU spare, hanging %.0f LDU in the longest run: move a sprocket to take it up"
			% [count, laid.slack, sag_made])
	else:
		laid.notes.append("%d links, %.0f LDU spare" % [count, laid.slack])
	return laid


# -- the parts of an item, read back --------------------------------------------


## Which kind a set of parts is, when every one of them is a segment of
## one: "" otherwise.
static func kind_of(part_ids: Array) -> String:
	if part_ids.is_empty():
		return ""
	for kind: String in KINDS:
		var spec: Dictionary = KINDS[kind]
		var own: Array = []
		for key: String in ["segment", "end", "middle", "link"]:
			if spec.has(key):
				own.append(spec[key])
		own.append_array(spec.get("ends", []))
		var all: bool = true
		for part: Variant in part_ids:
			if not own.has(str(part)):
				all = false
				break
		if all:
			return kind
	return ""


## Whether a part is any kind's segment.
static func is_segment(part_id: String) -> bool:
	return not kind_of([part_id]).is_empty()
