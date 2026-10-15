## A part put on another by their connectors, as BrickAgent's attach puts it.
##
## Our sessions placed every part by its low corner on a 2 LDU lattice. That
## is a brick on a brick, and it cannot say an arm on a clip at 30 degrees: the
## arithmetic of where a hinge's line is, turned, is the arithmetic sessions
## get wrong, so they built nothing on clips, bars, balls or hinges. On
## BrickBench's characters BrickAgent's builds are 4% such joints and ours were
## none (docs/BRICKBENCH.md). Its designer says `attach(part, to=other.hinge[0],
## by=("hinge", 0), yaw=30)` and gets the pose.
##
## So does ours. A connector is addressed as BrickAgent addresses it: its type
## (a stud's subtype, a hole's or an axle's, else the kind: stud, open, hole,
## tube, post, axle, cross, pin, socket, bar, clip, hinge, ball, fixed) and its
## place among that type in BrickNet's order. The connectors are BrickNet's own
## labels from the exact shapes (Exact), which is what BrickBench's check and
## ours look for a connection by; a part with no exact shape has the
## catalogue's connectors instead (studs, tubes, pins and their holes, axles
## and theirs, bars, clips, balls), seated as exactly but judged by the
## lattice. The pose is BrickAgent's (`brickagent.joints.placement`, MIT,
## Kulits and Schmid), the same arithmetic in the app's frame: the source's
## connector frame laid on the target's, turned `yaw` about the joint's axis,
## flipped end for end with `flip`, slid along an axle with `slide`; `align`
## points a direction of the part along one of the model's, and `orient` gives
## its whole orientation, which only a ball takes freely.
##
## The connector frames are kept in the app's frame with BrickNet's own axes
## (tools/build_exact.py), so a frame's y is BrickNet's axis and the
## arithmetic reads unchanged: a part placed at P has its connector k at
## P * frame(k), and the source goes where target * M * source_frame^-1 puts
## it.
class_name Attach
extends RefCounted

## The types a connector is addressed by, in the words a session writes.
const TYPES: PackedStringArray = ["stud", "open", "hole", "tube", "post", "axle", "cross",
	"pin", "socket", "bar", "clip", "hinge", "ball", "fixed"]
## How far an axle joint must overlap (BrickNet's _AXLE_MIN_OVERLAP).
const MIN_OVERLAP := 4.0
## 180 degrees about the connector's x: the flip that opposes two axes.
const RX_PI := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))


## One connector of a part.
class Point extends RefCounted:
	var type: String = ""
	var index: int = 0
	## Its place in the shape's own list (BrickNet's order), -1 for one read
	## from the catalogue.
	var native: int = -1
	var kind: int = 0
	var sub: int = 0
	var pol: int = Exact.NO_POLARITY
	## Half its length along its line, LDU: an axle's, a bar's, a hole's.
	var length: float = 0.0
	## Its frame in the part's own: BrickNet's axes, the axis its y.
	var frame := Transform3D.IDENTITY
	## From BrickNet's labels (the exact shape), not the catalogue's.
	var exact: bool = true

	func address() -> String:
		return "%s[%d]" % [type, index]

	## BrickNet's axis, the frame's y, in the part's frame.
	func axis() -> Vector3:
		return frame.basis.y.normalized()

	## What the joint is said as: "hinge (sub 1, in)".
	func said() -> String:
		var bits := PackedStringArray()
		if kind == Exact.HINGE or kind == Exact.BALL or kind == Exact.FIXED:
			bits.append("sub %d" % (sub - 100 if sub >= 100 else sub))
		if pol != Exact.NO_POLARITY:
			bits.append("in" if pol == 0 else "on")
		if length > 0.0:
			bits.append("half-length %s" % Attach._n(length))
		return type if bits.is_empty() else "%s (%s)" % [type, ", ".join(bits)]


## A part's connectors, addressed: its exact shape's (BrickNet's) when it has
## one, else the catalogue's. Main thread, as Exact.shape_for is.
static func points_of(library: PartLibrary, part_id: String) -> Array:
	var shape: Exact.Shape = Exact.shape_for(library, part_id)
	if shape != null and not shape.kind.is_empty():
		return points_from_shape(shape)
	var mesh: Lbm.PartMesh = library.mesh_for(part_id) if library != null else null
	return points_from_mesh(mesh) if mesh != null else []


## BrickNet's connectors, in its order, each typed and numbered within its type.
static func points_from_shape(shape: Exact.Shape) -> Array:
	var out: Array = []
	var counts: Dictionary = {}
	for k: int in shape.kind.size():
		var point := Point.new()
		point.type = shape.named(k)
		point.index = int(counts.get(point.type, 0))
		counts[point.type] = point.index + 1
		point.native = k
		point.kind = shape.kind[k]
		point.sub = shape.sub[k]
		point.pol = shape.pol[k]
		point.length = shape.length[k]
		point.frame = shape.frames[k]
		out.append(point)
	return out


## The catalogue's connectors as BrickNet's would be, for a part with no exact
## shape: a stud and the tube under it, a pin and its hole, an axle and its
## cross hole, a bar and what grips one, a ball and its socket. Each frame has
## BrickNet's axis as its y (a stud's into the part, as BrickNet's is) and its
## middle where a line's middle is.
static func points_from_mesh(mesh: Lbm.PartMesh) -> Array:
	var out: Array = []
	var counts: Dictionary = {}
	for connector: Lbm.Connector in mesh.connectors:
		var kind: int = -1
		var sub: int = 0
		var pol: int = Exact.NO_POLARITY
		var line: bool = false
		match connector.kind:
			"stud":
				kind = Exact.STUD if connector.gender == "male" else Exact.HOLE
				sub = Exact.S_STUD if connector.gender == "male" else Exact.S_HOLE
			"tube":
				kind = Exact.HOLE
				sub = Exact.S_TUBE
			"pin":
				kind = Exact.AXLE
				sub = Exact.S_PIN
				line = true
			"pin_hole":
				kind = Exact.AXLE
				sub = Exact.S_SOCKET
				line = true
			"axle":
				kind = Exact.AXLE
				sub = Exact.S_AXLE
				line = true
			"axle_hole":
				kind = Exact.AXLE
				sub = Exact.S_CROSS
				line = true
			"bar", "shaft":
				if connector.kind == "shaft" and absf(connector.radius - 4.0) > 0.5:
					continue
				kind = Exact.AXLE
				sub = Exact.S_BAR
				line = true
			"clip", "bore":
				if connector.kind == "bore" and absf(connector.radius - 4.0) > 0.5:
					continue
				kind = Exact.AXLE
				sub = Exact.S_CLIP
				line = true
			"ball", "socket":
				kind = Exact.BALL
				sub = 100
				pol = 0 if connector.kind == "ball" else 1
		if kind < 0:
			continue
		var out_way: Vector3 = connector.axis.normalized()
		if out_way == Vector3.ZERO:
			continue
		var point := Point.new()
		point.kind = kind
		point.sub = sub
		point.pol = pol
		point.exact = false
		point.type = Exact.SUB_NAMES[sub] if sub < Exact.SUB_NAMES.size() else \
			Exact.KIND_NAMES[kind]
		point.index = int(counts.get(point.type, 0))
		counts[point.type] = point.index + 1
		var middle: Vector3 = connector.position
		if line and connector.length > 0.0:
			point.length = connector.length * 0.5
			middle = connector.position + out_way * point.length
		# The frame's y is BrickNet's axis, which a stud and the hole it goes in
		# share: into the part under a stud, out of the part over a hole, so
		# against the way the catalogue's stud points out and along a tube's.
		var y: Vector3 = out_way if kind == Exact.HOLE else -out_way
		var across: Vector3 = Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
		var x: Vector3 = y.cross(across).normalized()
		var z: Vector3 = x.cross(y).normalized()
		point.frame = Transform3D(Basis(x, y, z), middle)
		out.append(point)
	return out


## "hinge[1]", "hinge 1", "hinge", "stud[-1]" read: {type, index} (index null
## when not said), or {error}.
static func parse_address(text: String) -> Dictionary:
	var said: String = text.strip_edges().to_lower().replace("(", "[").replace(")", "]")
	var re := RegEx.create_from_string("^([a-z]+)\\s*(?:\\[\\s*(-?\\d+)\\s*\\]|(-?\\d+))?$")
	var found: RegExMatch = re.search(said)
	if found == null:
		return {"error": "'%s' is not a connector: say its type and number, as hinge[0]" % text}
	var type: String = found.get_string(1)
	if type == "holes":
		type = "hole"
	elif type.ends_with("s") and TYPES.has(type.trim_suffix("s")):
		type = type.trim_suffix("s")
	if not TYPES.has(type):
		return {"error": "'%s' is no connector type; the types are %s" % [type, ", ".join(TYPES)]}
	var number: String = found.get_string(2) if not found.get_string(2).is_empty() \
		else found.get_string(3)
	return {"type": type, "index": null if number.is_empty() else int(number)}


## The connector of [param points] at [param type] and [param index] (from the
## end when negative), or null.
static func pick(points: Array, type: String, index: int) -> Point:
	var of_type: Array = points.filter(func(p: Point) -> bool: return p.type == type)
	if of_type.is_empty():
		return null
	var n: int = index if index >= 0 else of_type.size() + index
	return of_type[n] if n >= 0 and n < of_type.size() else null


## How many of a type a part has.
static func count_of(points: Array, type: String) -> int:
	return points.filter(func(p: Point) -> bool: return p.type == type).size()


## Whether BrickNet pairs two connectors (brickagent's compatible): a stud and
## what takes one, an axle-family pair, or two halves of a hinge, a ball or a
## fixed joint of one subtype and opposite polarities.
static func compatible(a: Point, b: Point) -> bool:
	if (a.kind == Exact.STUD and b.kind == Exact.HOLE) or (a.kind == Exact.HOLE and b.kind == Exact.STUD):
		return Exact._mates(Exact.STUD_MATES, a.sub, b.sub)
	if a.kind == Exact.AXLE and b.kind == Exact.AXLE:
		return Exact._mates(Exact.AXLE_MATES, a.sub, b.sub)
	if a.kind != b.kind or not [Exact.HINGE, Exact.BALL, Exact.FIXED].has(a.kind):
		return false
	return a.sub == b.sub and a.pol != Exact.NO_POLARITY and b.pol != Exact.NO_POLARITY \
		and a.pol != b.pol


## What a connector of [param type] takes, in words.
static func takes(type: String) -> String:
	var mates := PackedStringArray()
	var code: int = Exact.SUB_NAMES.find(type)
	if code >= 0:
		for table: Array in [Exact.STUD_MATES, Exact.AXLE_MATES]:
			for pair: Array in table:
				if int(pair[0]) == code and not mates.has(Exact.SUB_NAMES[int(pair[1])]):
					mates.append(Exact.SUB_NAMES[int(pair[1])])
				elif int(pair[1]) == code and not mates.has(Exact.SUB_NAMES[int(pair[0])]):
					mates.append(Exact.SUB_NAMES[int(pair[0])])
	if mates.is_empty():
		return "the other half of a %s of its subtype and the other polarity" % type
	mates.sort()
	return ", ".join(mates)


## The connector of the source's [param points] that goes on [param target],
## said by [param type] and [param index] (null for "the only one that fits"):
## {point} or {error}.
static func source_for(points: Array, target: Point, type: String, index: Variant) -> Dictionary:
	if not type.is_empty():
		if count_of(points, type) == 0:
			return {"error": "has no %s; it has %s" % [type, listing(points)]}
		var chosen: Point = pick(points, type, int(index) if index != null else 0)
		if chosen == null:
			return {"error": "has %d %s (%s[0] to %s[%d])" % [count_of(points, type), type,
				type, type, count_of(points, type) - 1]}
		if index == null and count_of(points, type) > 1:
			var fits: Array = points.filter(func(p: Point) -> bool:
				return p.type == type and compatible(target, p))
			if fits.size() > 1:
				return {"error": "has %d %s; say which, as %s[0] to %s[%d]" % [fits.size(), type,
					type, type, count_of(points, type) - 1]}
			if fits.size() == 1:
				chosen = fits[0]
		if not compatible(target, chosen):
			return {"error": "has %s%s, which does not fit %s: %s takes %s" % [chosen.address(),
				chosen.said().trim_prefix(chosen.type), _a(target.said()), _a(target.type),
				takes(target.type)]}
		return {"point": chosen}
	var fits: Array = points.filter(func(p: Point) -> bool: return compatible(target, p))
	if fits.size() == 1:
		return {"point": fits[0]}
	if fits.is_empty():
		return {"error": "has nothing that fits %s (%s takes %s); it has %s" % [
			_a(target.said()), _a(target.type), takes(target.type), listing(points)]}
	var names := PackedStringArray()
	for p: Point in fits.slice(0, 6):
		names.append(p.address())
	return {"error": "has %d connectors that fit %s; say which with by: %s%s" % [fits.size(),
		_a(target.type), ", ".join(names), "..." if fits.size() > 6 else ""]}


## The pairs of connectors that do mate, said as attach takes them: each of
## [param theirs] (the target's, named [param ref]) with each of [param mine]
## (the new part's) that fits it, the nearest [param near] (the target's
## connector asked for, or null) first, a few at most. A session that asked
## for a bar in a round brick's hollow stud ("open") is told the same spot is
## its clip, which a bar goes in. "" when none mate.
static func mates_said(theirs: Array, mine: Array, ref: String, near: Point = null) -> String:
	var found: Array = []      ## [distance, words]
	for t: Point in theirs:
		for s: Point in mine:
			if not compatible(t, s):
				continue
			var off: float = 0.0 if near == null else t.frame.origin.distance_to(near.frame.origin)
			found.append([off, "\"to\": \"%s.%s\", \"by\": \"%s\"" % [ref, t.address(), s.address()]])
			break
	if found.is_empty():
		return ""
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var said := PackedStringArray()
	for row: Array in found.slice(0, 3):
		said.append(str(row[1]) + (" (the same spot)" if near != null and float(row[0]) < 1.0
			else ""))
	return "; what does mate: " + "; ".join(said)


## A word with its article: "a stud", "an open".
static func _a(word: String) -> String:
	return ("an " if "aeiou".contains(word.left(1)) else "a ") + word


## A part's connectors in a line: "8 stud, 8 hole, 3 tube".
static func listing(points: Array) -> String:
	var counts: Dictionary = {}
	var order := PackedStringArray()
	for p: Point in points:
		if not counts.has(p.type):
			order.append(p.type)
		counts[p.type] = int(counts.get(p.type, 0)) + 1
	var out := PackedStringArray()
	for type: String in order:
		out.append("%d %s" % [counts[type], type])
	return "no connectors" if out.is_empty() else ", ".join(out)


## A direction said in words or as [x, y, z], in the app's frame (y up), or
## null.
static func direction(said: Variant) -> Variant:
	if said is Array and (said as Array).size() == 3:
		var v := Vector3(float(said[0]), float(said[1]), float(said[2]))
		return v.normalized() if v.length() > 1e-9 else null
	var words: Dictionary = {"x": Vector3.RIGHT, "+x": Vector3.RIGHT, "-x": Vector3.LEFT,
		"y": Vector3.UP, "+y": Vector3.UP, "up": Vector3.UP, "-y": Vector3.DOWN,
		"down": Vector3.DOWN, "z": Vector3.BACK, "+z": Vector3.BACK, "-z": Vector3.FORWARD}
	return words.get(str(said).strip_edges().to_lower())


## Where the source part goes so that its connector [param b] joins the
## target's [param a]: {"at": its transform} in the frame [param target] (the
## target part's transform) is in, or {"error"}. [param options]: yaw (degrees,
## right-handed about the target's axis; zero follows its connector's roll),
## flip (true opposes the axes: an axle or a hinge only; left out, the way
## align or orient implies, else the axes agree), slide (LDU along an axle
## joint), seat ("center", "+end", "-end": an axle joint's labelled middles or
## ends together), align ([u, v]: the source's own u along the frame's v,
## which chooses the flip, then yaw), orient (a Basis: the source's whole
## orientation in that frame; a ball takes any, the rest only a turn about
## their axis, a fixed joint none).
static func pose(target: Transform3D, a: Point, b: Point, options: Dictionary = {}) -> Dictionary:
	if not compatible(a, b):
		return {"error": "%s does not take %s: %s takes %s" % [_a(a.said()), _a(b.said()),
			_a(a.type), takes(a.type)]}
	var angle: float = float(options.get("yaw", 0.0))
	var offset: float = float(options.get("slide", 0.0))
	var flip: Variant = options.get("flip")
	var side: int = 0 if flip == null else (-1 if bool(flip) else 1)
	var orient: Variant = options.get("orient")
	var align: Variant = options.get("align")
	if orient != null and (align != null or not is_zero_approx(angle)):
		return {"error": "give orient, or align and yaw, not both"}
	var ft: Transform3D = target * a.frame
	var fs: Transform3D = b.frame
	var a_axis: Vector3 = ft.basis.y.normalized()
	var b_axis: Vector3 = fs.basis.y.normalized()
	var u := Vector3.ZERO
	var v := Vector3.ZERO
	if align != null:
		u = (align[0] as Vector3).normalized()
		v = (align[1] as Vector3).normalized()
	if side == 0 and (a.kind == Exact.AXLE or a.kind == Exact.HINGE):
		if orient != null:
			side = 1 if a_axis.dot((orient as Basis) * b_axis) >= 0.0 else -1
		elif align != null:
			var source_along: float = u.dot(b_axis)
			var target_along: float = v.dot(a_axis)
			if absf(source_along) > 1e-8 and absf(target_along) > 1e-8:
				side = 1 if source_along * target_along > 0.0 else -1
	var slide: float = offset
	var seat: String = str(options.get("seat", ""))
	if seat == "+end" or seat == "-end":
		if a.kind != Exact.AXLE:
			return {"error": "seat %s is for an axle joint: a pin, an axle, a bar in its hole or clip" % seat}
		slide += (1.0 if seat == "+end" else -1.0) * (a.length - b.length)
	if side == 0:
		side = 1
	if a.kind != Exact.AXLE and (not is_zero_approx(offset) or (side == -1 and a.kind != Exact.HINGE)):
		return {"error": "slide is for an axle joint (a pin, an axle, a bar in a clip); flip for "
			+ "one of those or a hinge"}
	var limit: float = a.length + b.length - minf(MIN_OVERLAP, minf(2.0 * a.length, 2.0 * b.length))
	if a.kind == Exact.AXLE and absf(slide) > limit + 1e-6:
		var shift: float = slide - offset
		return {"error": "slide %s would pull it off; here it can be %s to %s" % [_n(offset),
			_n(-limit - shift), _n(limit - shift)]}
	var r: Basis = RX_PI if side == -1 else Basis.IDENTITY
	# A ball turns any way, so aligned it points the part's own direction
	# along the one asked by the least turn there is, then turns it by yaw
	# about that direction: "this arm out and 20 degrees down". BrickAgent's
	# align turns about the joint's axis alone, which on a ball whose axis
	# stands up cannot lift an arm at all.
	if align != null and a.kind == Exact.BALL:
		var turn: Basis = _arc(u, v)
		turn = Basis(v, deg_to_rad(angle)) * turn
		align = null
		angle = 0.0
		orient = turn
	if align != null:
		var uu: Vector3 = r * (fs.basis.inverse() * u)
		var vv: Vector3 = ft.basis.inverse() * v
		var radii := Vector2(Vector2(uu.x, uu.z).length(), Vector2(vv.x, vv.z).length())
		if absf(uu.y - vv.y) > 1e-4 or absf(radii.x - radii.y) > 1e-4:
			return {"error": "those two directions cannot be lined up by turning about the joint's axis"}
		if maxf(radii.x, radii.y) >= 1e-6:
			angle += rad_to_deg(atan2(uu.cross(vv).y, uu.x * vv.x + uu.z * vv.z))
	var rotation: Basis
	if orient != null:
		rotation = ft.basis.inverse() * (orient as Basis) * fs.basis * r.transposed()
	else:
		rotation = Basis(Vector3.UP, deg_to_rad(angle))
	if a.kind == Exact.FIXED:
		if not rotation.is_equal_approx(Basis.IDENTITY) and not _near(rotation, Basis.IDENTITY):
			return {"error": "a fixed joint (a torso on its hips, a tyre on its rim) holds one "
				+ "orientation only: leave out orient and yaw"}
		rotation = Basis.IDENTITY
	elif a.kind != Exact.BALL and (rotation * Vector3.UP).distance_to(Vector3.UP) > 1e-3:
		return {"error": "that orientation tilts the joint's axis; only a ball joint tilts, the "
			+ "rest turn about their axis (yaw)"}
	var m := Transform3D((rotation * r).orthonormalized(), Vector3(0.0, slide, 0.0))
	var at: Transform3D = ft * m * fs.affine_inverse()
	return {"at": Transform3D(at.basis.orthonormalized(), at.origin)}


## The least turn that carries direction [param from] onto [param to].
static func _arc(from: Vector3, to: Vector3) -> Basis:
	var a: Vector3 = from.normalized()
	var b: Vector3 = to.normalized()
	var axis: Vector3 = a.cross(b)
	var d: float = clampf(a.dot(b), -1.0, 1.0)
	if axis.length() < 1e-6:
		if d > 0.0:
			return Basis.IDENTITY
		# Opposite: half a turn about any line across it.
		var across: Vector3 = Vector3.UP if absf(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		return Basis(a.cross(across).normalized(), PI)
	return Basis(axis.normalized(), acos(d))


## Whether two bases are the same within a ten-thousandth.
static func _near(one: Basis, other: Basis) -> bool:
	for k: int in 3:
		if one[k].distance_to(other[k]) > 1e-4:
			return false
	return true


## Whether a joint is a pin in its round hole, which BrickAgent seats by the
## pin's collar rather than at its middle.
static func pinned(a: Point, b: Point) -> bool:
	return a.kind == Exact.AXLE and b.kind == Exact.AXLE \
		and [a.sub, b.sub].has(Exact.S_PIN) and [a.sub, b.sub].has(Exact.S_SOCKET)


## For a pin in its hole said with no slide: the least slide along the joint,
## in whole LDU up to its play, that leaves the source clear of the target by
## their exact shapes (a minifigure's head down its neck to the torso's top, a
## Technic pin's collar at the hole's mouth), as BrickAgent seats one by its
## collar. 0 when nothing clears it or either has no shape.
static func seat_slide(target_shape: Exact.Shape, target_at: Transform3D,
		source_shape: Exact.Shape, a: Point, b: Point, options: Dictionary) -> float:
	if target_shape == null or source_shape == null or not target_shape.has_pieces() \
			or not source_shape.has_pieces():
		return 0.0
	var them := Exact.Item.new(target_shape, target_at)
	var limit: float = a.length + b.length - minf(MIN_OVERLAP, minf(2.0 * a.length, 2.0 * b.length))
	for step: int in range(0, int(floor(limit)) + 1):
		for sign: float in ([1.0] if step == 0 else [1.0, -1.0]):
			var tried: Dictionary = options.duplicate()
			tried["slide"] = sign * step
			var found: Dictionary = pose(target_at, a, b, tried)
			if not found.has("at"):
				continue
			if Exact.clash(them, Exact.Item.new(source_shape, found["at"]), true).is_empty():
				return sign * step
	return 0.0


static func _n(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")
