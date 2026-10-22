## Parts by their exact shapes, as BrickBench judges a build.
##
## BrickBench's verify.py (BrickAgent, MIT) refuses a build when two parts'
## convex colliders overlap by more than 1 LDU, and it lets fall every piece
## its connection graph does not join to the ground. Our check was a 2 LDU
## lattice that forgives a stud and a joint, so it handed over designs whose
## side studs were pushed into the next brick, hinge plates through each
## other, horns on axles and crystals 4 LDU off their studs: 46 pairs over
## ten designs, and 2 of 10 valid (docs/BRICKBENCH.md).
##
## So the check reads the same shapes: each part as BrickNet's compound of
## convex pieces and its connector labels, written by tools/build_exact.py
## into exact/<mesh hash>.bwx beside the part's geometry. Two placed parts
## collide when some piece of one and some piece of the other overlap by more
## than [constant TAU] along every axis that could separate them: the face
## normals of both and the cross products of their edges, which for convex
## shapes is exact (the separating axis theorem), where Bullet's EPA in
## verify.py is an approximation of the same depth. Connections are
## BrickNet's own rules (bricknet.graph._find_pairs), read off the same
## labels: a stud meets a hole within 3 LDU and pointing the same way, a
## hinge its other half, an axle its hole along a shared line.
##
## Everything here is plain arithmetic on packed arrays, so it runs on a
## worker thread and in the browser alike. Shapes are read from disk on any
## thread (shape_for), and in a browser fetched on the main thread.
class_name Exact
extends RefCounted

const MAGIC := 0x31585742     ## "BWX1"
const VERSION := 1
## How far two parts may overlap, in LDU: BrickNet's TAU, which verify.py
## requires to be 1.
const TAU := 1.0
## How far a part this app moves is let overlap another once moved: a hair
## under TAU. Two parts that meet by exactly 1 LDU are a coin's toss in
## verify.py, whose own sum lands either side of its limit: 1.0000000000000024
## for a minifigure head the figure tool had slid 2 LDU up its neck to clear an
## armour breastplate (model-010 of 2026-10-14, refused), under it for two
## parts of one of BrickAgent's builds (passed). The check judges at TAU, as
## verify.py says; what the app places itself it places clear of the toss.
const CLEAR := TAU - 0.01
## How near a stud must be to a hole to meet it, in LDU (BrickNet's _POS_THR),
## and how nearly the two must point the same way.
const POS_THR := 3.0
const AXIS_THR := 0.95
const AXLE_AXIS_THR := 0.9
const AXLE_PERP_THR := 2.05
const AXLE_DEFAULT_RAD := 4.0
const AXLE_MIN_OVERLAP := 4.0
const FIXED_AXIS_THR := 0.9999
const FIXED_FRAME_TRACE := 2.99

## BrickNet's kinds of connector.
const STUD := 0
const HOLE := 1
const HINGE := 2
const FIXED := 3
const BALL := 4
const AXLE := 5
const KIND_NAMES: PackedStringArray = ["stud", "hole", "hinge", "fixed", "ball", "axle"]
## Its subtypes: the stud family's, then the axle family's; a numbered
## subtype (a hinge's or a fixed joint's) is 100 and its number.
const SUB_NAMES: PackedStringArray = ["stud", "open", "hole", "tube", "post",
	"bar", "clip", "axle", "cross", "pin", "socket"]
const S_STUD := 0
const S_OPEN := 1
const S_HOLE := 2
const S_TUBE := 3
const S_POST := 4
const S_BAR := 5
const S_CLIP := 6
const S_AXLE := 7
const S_CROSS := 8
const S_PIN := 9
const S_SOCKET := 10
const NO_POLARITY := 255
## Which stud subtypes take which, and which axle ones: BrickNet's
## _STUD_MATES and _AXLE_MATES, as [low, high] codes.
const STUD_MATES: Array = [[S_OPEN, S_HOLE], [S_STUD, S_HOLE], [S_OPEN, S_POST],
	[S_OPEN, S_TUBE], [S_STUD, S_TUBE]]
const AXLE_MATES: Array = [[S_AXLE, S_CROSS], [S_AXLE, S_SOCKET], [S_BAR, S_CLIP],
	[S_BAR, S_CROSS], [S_PIN, S_SOCKET]]
## The axle-family subtypes BrickNet measures along the other one's line.
const A_SIDE: Array = [S_SOCKET, S_CROSS, S_CLIP]
## The fixed subtypes that hold one orientation only.
const FIXED_ORIENTED: Array = [100, 101, 102, 103]


## One convex piece of a part, in the part's own frame.
class Piece extends RefCounted:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var edges := PackedVector3Array()
	var lo := Vector3.ZERO
	var hi := Vector3.ZERO
	## Its own extent along each of its normals: low, high, low, high...
	var spans := PackedFloat32Array()


## A part's exact shape: its convex pieces and BrickNet's connectors.
class Shape extends RefCounted:
	## A number of its own, for remembering verdicts between two shapes.
	var id: int = 0
	var lo := Vector3.ZERO
	var hi := Vector3.ZERO
	var pieces: Array[Piece] = []
	var kind := PackedByteArray()
	var sub := PackedByteArray()
	var pol := PackedByteArray()
	var length := PackedFloat32Array()
	## Each connector's frame: its axes the directions of BrickNet's frame
	## columns, so it points along minus its y; its origin where it is.
	var frames: Array[Transform3D] = []
	## Its pieces' boxes in a tree, for [method Exact._overlapping] to find
	## the pieces near another part's without asking each of them: each
	## node's box, its two children (a leaf: -1, and how many pieces it
	## holds), and where a leaf's pieces begin in [member tree_pieces].
	## Built as it is read ([method Exact._tree_of]).
	var tree_lo := PackedVector3Array()
	var tree_hi := PackedVector3Array()
	var tree_left := PackedInt32Array()
	var tree_right := PackedInt32Array()
	var tree_first := PackedInt32Array()
	var tree_pieces := PackedInt32Array()

	func has_pieces() -> bool:
		return not pieces.is_empty()

	func connector_count() -> int:
		return kind.size()

	## A connector said as a person reads it: "stud", "hole", "hinge", "clip".
	func named(k: int) -> String:
		var s: int = sub[k]
		if kind[k] == STUD or kind[k] == HOLE or kind[k] == AXLE:
			return SUB_NAMES[s] if s < SUB_NAMES.size() else KIND_NAMES[kind[k]]
		return KIND_NAMES[kind[k]]


## A part where it stands.
class Item extends RefCounted:
	var shape: Shape
	var at := Transform3D.IDENTITY
	var lo := Vector3.ZERO
	var hi := Vector3.ZERO

	## Its connectors in the world, worked out once: [connector, position,
	## the way it points, frame basis] each.
	var _world: Array = []
	var _worked: bool = false

	func _init(of: Shape, where: Transform3D) -> void:
		shape = of
		at = where
		var box: Array = Exact.box_in(of.lo, of.hi, where)
		lo = box[0]
		hi = box[1]

	func world() -> Array:
		if not _worked:
			_worked = true
			for k: int in shape.kind.size():
				var frame: Transform3D = at * shape.frames[k]
				var axis: Vector3 = -frame.basis.y
				if axis.length_squared() > 0.0:
					axis = axis.normalized()
				_world.append([k, frame.origin, axis, frame.basis])
		return _world


static var _next_id: int = 1
## mesh hash -> Shape, or null where there is none. Filled and read on
## any thread: Bodies reads a big model's shapes on a worker as it opens
## (GrabDrag) while the main thread reads others in, and a Dictionary read
## while another thread adds to it can be read mid-way. So it is read and
## filled under a lock, as Joints._lines is (racefix, 2026-10-20).
static var _shapes: Dictionary = {}
static var _shapes_lock := Mutex.new()
## Parts whose shape the main thread asked for while [member noting] and it
## was still on its way, so judged without it: part id -> true, until
## [method missed_taken]. Main thread only: a motion's press notes what its
## working out asks for (main.gd).
static var noting: bool = false
static var _missed: Dictionary = {}
## Verdicts between two shapes at one relative pose: key -> [depth, piece a,
## piece b, axis] or []. Shared by checks on different threads.
static var _verdicts: Dictionary = {}
static var _verdicts_lock := Mutex.new()
const MOST_VERDICTS := 200000


## A shape read from its file, or null.
static func parse(bytes: PackedByteArray) -> Shape:
	if bytes.size() < 40 or bytes.decode_u32(0) != MAGIC or bytes.decode_u16(4) != VERSION:
		return null
	var piece_count: int = bytes.decode_u16(6)
	var connector_count: int = bytes.decode_u16(8)
	var scale: float = bytes.decode_float(12)
	var shape := Shape.new()
	# Under the lock: shapes are read on workers too, and two given one id
	# would share their verdicts.
	_shapes_lock.lock()
	shape.id = _next_id
	_next_id += 1
	_shapes_lock.unlock()
	shape.lo = Vector3(bytes.decode_float(16), bytes.decode_float(20), bytes.decode_float(24))
	shape.hi = Vector3(bytes.decode_float(28), bytes.decode_float(32), bytes.decode_float(36))
	var at: int = 40
	if bytes.size() < at + connector_count * 56:
		return null
	shape.kind.resize(connector_count)
	shape.sub.resize(connector_count)
	shape.pol.resize(connector_count)
	shape.length.resize(connector_count)
	for c: int in connector_count:
		shape.kind[c] = bytes[at]
		shape.sub[c] = bytes[at + 1]
		shape.pol[c] = bytes[at + 2]
		shape.length[c] = bytes.decode_float(at + 4)
		var x := Vector3(bytes.decode_float(at + 8), bytes.decode_float(at + 12), bytes.decode_float(at + 16))
		var y := Vector3(bytes.decode_float(at + 20), bytes.decode_float(at + 24), bytes.decode_float(at + 28))
		var z := Vector3(bytes.decode_float(at + 32), bytes.decode_float(at + 36), bytes.decode_float(at + 40))
		var o := Vector3(bytes.decode_float(at + 44), bytes.decode_float(at + 48), bytes.decode_float(at + 52))
		shape.frames.append(Transform3D(Basis(x, y, z), o))
		at += 56
	for p: int in piece_count:
		if bytes.size() < at + 6:
			return null
		var nv: int = bytes.decode_u16(at)
		var nn: int = bytes.decode_u16(at + 2)
		var ne: int = bytes.decode_u16(at + 4)
		at += 6
		if bytes.size() < at + 6 * (nv + nn + ne):
			return null
		# Read into arrays of its own and handed over whole: appended to the
		# piece's own, each one went through the piece (G14a: a shape of 316
		# pieces took 9 ms to read).
		var verts := PackedVector3Array()
		verts.resize(nv)
		for v: int in nv:
			verts[v] = Vector3(bytes.decode_s16(at), bytes.decode_s16(at + 2),
				bytes.decode_s16(at + 4)) * scale
			at += 6
		var normals := PackedVector3Array()
		var edges := PackedVector3Array()
		for n: int in nn + ne:
			var d := Vector3(bytes.decode_s16(at), bytes.decode_s16(at + 2),
				bytes.decode_s16(at + 4))
			at += 6
			if d.length_squared() < 1.0:
				continue
			if n < nn:
				normals.append(d.normalized())
			else:
				edges.append(d.normalized())
		if verts.is_empty():
			continue
		var piece := Piece.new()
		var lo: Vector3 = verts[0]
		var hi: Vector3 = verts[0]
		for v: Vector3 in verts:
			lo = lo.min(v)
			hi = hi.max(v)
		var spans := PackedFloat32Array()
		spans.resize(normals.size() * 2)
		for k: int in normals.size():
			var n: Vector3 = normals[k]
			var low: float = INF
			var high: float = -INF
			for v: Vector3 in verts:
				var d: float = v.dot(n)
				low = minf(low, d)
				high = maxf(high, d)
			spans[2 * k] = low
			spans[2 * k + 1] = high
		piece.verts = verts
		piece.normals = normals
		piece.edges = edges
		piece.lo = lo
		piece.hi = hi
		piece.spans = spans
		shape.pieces.append(piece)
	_tree_of(shape)
	return shape


## The shape a round part with no exact shape of its own makes (a tyre, a
## wheel: its box two sides alike across [param axis], 0 to 2): the prism of
## [constant ROUND_SIDES] sides inside its box's round. Its box's corners are
## not the part: a tyre steered about its kingpin swung them 4 LDU into the
## steering top beside it at 30°, where the round stays clear (8820-1).
static func round_of(box: AABB, axis: int) -> Shape:
	var key: String = "%s %d" % [box, axis]
	_shapes_lock.lock()
	var known: Shape = _rounds.get(key)
	_shapes_lock.unlock()
	if known != null:
		return known
	var along := Vector3.ZERO
	along[axis] = 1.0
	var one := Vector3.ZERO
	one[(axis + 1) % 3] = 1.0
	var two := Vector3.ZERO
	two[(axis + 2) % 3] = 1.0
	var radius: float = 0.5 * minf(box.size[(axis + 1) % 3], box.size[(axis + 2) % 3])
	var half: float = 0.5 * box.size[axis]
	var middle: Vector3 = box.get_center()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array([along])
	var edges := PackedVector3Array([along])
	for n: int in ROUND_SIDES:
		var t: float = TAU * float(n) / float(ROUND_SIDES)
		var rim: Vector3 = (one * cos(t) + two * sin(t)) * radius
		verts.append(middle + rim - along * half)
		verts.append(middle + rim + along * half)
		if n < ROUND_SIDES / 2:
			var mid: float = t + PI / float(ROUND_SIDES)
			normals.append(one * cos(mid) + two * sin(mid))
			edges.append(-one * sin(mid) + two * cos(mid))
	var piece := Piece.new()
	piece.verts = verts
	piece.normals = normals
	piece.edges = edges
	piece.lo = verts[0]
	piece.hi = verts[0]
	for v: Vector3 in verts:
		piece.lo = piece.lo.min(v)
		piece.hi = piece.hi.max(v)
	piece.spans.resize(normals.size() * 2)
	for k: int in normals.size():
		var low: float = INF
		var high: float = -INF
		for v: Vector3 in verts:
			low = minf(low, v.dot(normals[k]))
			high = maxf(high, v.dot(normals[k]))
		piece.spans[2 * k] = low
		piece.spans[2 * k + 1] = high
	var shape := Shape.new()
	shape.lo = piece.lo
	shape.hi = piece.hi
	shape.pieces.append(piece)
	_tree_of(shape)
	_shapes_lock.lock()
	shape.id = _next_id
	_next_id += 1
	_rounds[key] = shape
	_shapes_lock.unlock()
	return shape


static var _rounds: Dictionary = {}
## The sides of a round part's prism ([method round_of]): inside the round by
## 2% of its radius, 0.7 LDU for a tyre 70 across.
const ROUND_SIDES := 16


## The catalogue's entry whose exact shape [param part_id] has: its own, or for
## a model file's own copy of a part LEGO made, that part's (PartInfo.copy_of).
static func _shaped_as(library: PartLibrary, part_id: String) -> PartLibrary.PartInfo:
	return library.shaped_as(part_id) if library != null else null


## Where a part's exact shape lives, by its mesh hash.
static func file_for(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = _shaped_as(library, part_id)
	if info == null or info.mesh_hash.is_empty():
		return ""
	return library._resolve_root() + "exact/" + info.mesh_hash + ".bwx"


## A part's exact shape, read from disk the first time, or null where it has
## none (BrickNet does not have the part, or the build has no exact/ folder).
## Read on a worker too, but in a browser, whose shapes are fetched on the
## main thread: null there until then. A worker that answered null for a
## shape not yet read judged the pair by its covers where the main thread
## judged it exactly. 42024-1's small actuator, let go at its stop and
## checked on a worker, was kept 2.25 LDU short of it, where a pin
## joiner's cover met a liftarm their shapes are clear of (Grab 21).
static func shape_for(library: PartLibrary, part_id: String) -> Shape:
	var info: PartLibrary.PartInfo = _shaped_as(library, part_id)
	if info == null or info.mesh_hash.is_empty():
		return null
	_shapes_lock.lock()
	var known: bool = _shapes.has(info.mesh_hash)
	var kept: Shape = _shapes.get(info.mesh_hash)
	_shapes_lock.unlock()
	if known:
		return kept
	var main: bool = OS.get_thread_caller_id() == OS.get_main_thread_id()
	if not main and OS.has_feature("web"):
		return null
	# Already asked for: a look in the browser's pack for a file that is not
	# there costs a couple of milliseconds, each time.
	if main and library.is_exact_on_its_way(info.id):
		if noting:
			_missed[info.id] = true
		return null
	var path: String = file_for(library, info.id)
	var shape: Shape = null
	if FileAccess.file_exists(path):
		shape = parse(FileAccess.get_file_as_bytes(path))
	elif OS.has_feature("web"):
		# Fetched as the geometry is (PartLibrary.request_exact); null until then.
		if library.request_exact(info.id) and main and noting:
			_missed[info.id] = true
		return null
	_shapes_lock.lock()
	# Read by another thread meanwhile: one shape a part, as its id keys
	# verdicts.
	if _shapes.has(info.mesh_hash):
		shape = _shapes[info.mesh_hash]
	else:
		_shapes[info.mesh_hash] = shape
	_shapes_lock.unlock()
	return shape


## Kept from a fetch: the web build's way in (PartLibrary._on_fetched_exact).
static func keep(mesh_hash: String, bytes: PackedByteArray) -> void:
	var shape: Shape = parse(bytes) if not bytes.is_empty() else null
	_shapes_lock.lock()
	_shapes[mesh_hash] = shape
	_shapes_lock.unlock()


## The parts asked for on the main thread since the last call while their
## shapes were on their way ([member _missed]), and forgotten.
static func missed_taken() -> Array:
	var out: Array = _missed.keys()
	_missed.clear()
	return out


## Whether the shape for a part has been looked for (found or not).
static func known(library: PartLibrary, part_id: String) -> bool:
	var info: PartLibrary.PartInfo = _shaped_as(library, part_id)
	if info == null or info.mesh_hash.is_empty():
		return true
	_shapes_lock.lock()
	var known: bool = _shapes.has(info.mesh_hash)
	_shapes_lock.unlock()
	return known


## The shapes for these parts, id -> Shape (absent where there is none), for a
## check on any thread to read. Main thread.
static func shapes_for(library: PartLibrary, part_ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for part_id: Variant in part_ids:
		var shape: Shape = shape_for(library, str(part_id))
		if shape != null:
			out[str(part_id)] = shape
	return out


## A box carried by a transform: [lo, hi] of where it ends up.
static func box_in(lo: Vector3, hi: Vector3, at: Transform3D) -> Array:
	var middle: Vector3 = at * ((lo + hi) * 0.5)
	var half: Vector3 = (hi - lo) * 0.5
	var b: Basis = at.basis
	var reach: Vector3 = b.x.abs() * half.x + b.y.abs() * half.y + b.z.abs() * half.z
	return [middle - reach, middle + reach]


# -- collisions ------------------------------------------------------------


## Every pair of [param items] whose shapes overlap by more than TAU, for the
## pairs [param wanted] allows (wanted.call(i, j) -> bool, i < j; an empty
## Callable asks about every pair). Each is {a, b, depth, piece_a, piece_b,
## axis}, a < b, axis in the world, pointing from a towards b. An item may be
## null (a part with no exact shape), which meets nothing.
static func clashes(items: Array, wanted: Callable = Callable()) -> Array:
	var out: Array = []
	for pair: Vector2i in candidates(items, TAU, wanted):
		var found: Dictionary = clash(items[pair.x], items[pair.y])
		if not found.is_empty():
			found["a"] = pair.x
			found["b"] = pair.y
			out.append(found)
	return out


## Pairs of items whose boxes overlap by more than [param by] along every
## axis (a negative [param by] reaches that far apart), i < j.
static func candidates(items: Array, by: float, wanted: Callable = Callable(),
		only: PackedInt32Array = PackedInt32Array()) -> Array:
	var cell: float = 40.0
	var grow := Vector3.ONE * maxf(0.0, -by) * 0.5
	var grid: Dictionary = {}
	var out: Array = []
	var these: PackedInt32Array = only if not only.is_empty() else _every(items.size())
	for i: int in these:
		var item: Item = items[i]
		if item == null:
			continue
		var lo: Vector3i = Vector3i(((item.lo - grow) / cell).floor())
		var hi: Vector3i = Vector3i(((item.hi + grow) / cell).floor())
		var seen: Dictionary = {}
		for x: int in range(lo.x, hi.x + 1):
			for y: int in range(lo.y, hi.y + 1):
				for z: int in range(lo.z, hi.z + 1):
					var key := Vector3i(x, y, z)
					var there: PackedInt32Array = grid.get(key, PackedInt32Array())
					for j: int in there:
						if seen.has(j):
							continue
						seen[j] = true
						var other: Item = items[j]
						if minf(item.hi.x, other.hi.x) - maxf(item.lo.x, other.lo.x) <= by \
								or minf(item.hi.y, other.hi.y) - maxf(item.lo.y, other.lo.y) <= by \
								or minf(item.hi.z, other.hi.z) - maxf(item.lo.z, other.lo.z) <= by:
							continue
						if wanted.is_valid() and not wanted.call(j, i):
							continue
						out.append(Vector2i(j, i))
					there.append(i)
					grid[key] = there
	return out


## 0 to [param count] - 1.
static func _every(count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(count)
	for i: int in count:
		out[i] = i
	return out


## How two placed parts collide, or {} when they do not: {depth, piece_a,
## piece_b, axis}, the axis in the world from a towards b. Overlapping by
## more than TAU, or with [param placing] (a part the app is moving) by more
## than [constant CLEAR].
static func clash(a: Item, b: Item, placing: bool = false) -> Dictionary:
	if a == null or b == null or not a.shape.has_pieces() or not b.shape.has_pieces():
		return {}
	var rel: Transform3D = a.at.affine_inverse() * b.at
	var key: Array = _key(a.shape.id, b.shape.id, rel)
	key.append(placing)
	_verdicts_lock.lock()
	var known_verdict: Variant = _verdicts.get(key)
	_verdicts_lock.unlock()
	var verdict: Array
	if known_verdict != null:
		verdict = known_verdict
	else:
		verdict = _clash_local(a.shape, b.shape, rel, CLEAR if placing else TAU)
		_verdicts_lock.lock()
		if _verdicts.size() >= MOST_VERDICTS:
			_verdicts.clear()
		_verdicts[key] = verdict
		_verdicts_lock.unlock()
	if verdict.is_empty():
		return {}
	return {"depth": float(verdict[0]), "piece_a": int(verdict[1]),
		"piece_b": int(verdict[2]), "axis": (a.at.basis * (verdict[3] as Vector3)).normalized()}


## What [method clash_but] passes over: pieces of a and of b (1 each piece
## forgiven, or empty for none), and pairs of them (b's piece << 20 | a's ->
## true).
class Forgiven extends RefCounted:
	var a_pieces := PackedByteArray()
	var b_pieces := PackedByteArray()
	var pairs: Dictionary = {}

	func is_empty() -> bool:
		return pairs.is_empty() and not a_pieces.has(1) and not b_pieces.has(1)


## [method clash], passing over the pieces and pairs of pieces [param but]
## forgives: a joint's own two parts, a pin in its hole and what they were
## built into each other by, judged by the rest of their shapes. Not kept
## among the verdicts, which are the whole shapes'.
static func clash_but(a: Item, b: Item, but: Forgiven) -> Dictionary:
	if a == null or b == null or not a.shape.has_pieces() or not b.shape.has_pieces():
		return {}
	var hits: Array = _overlapping(a.shape, b.shape, a.at.affine_inverse() * b.at, TAU, true, but)
	if hits.is_empty():
		return {}
	var verdict: Array = hits[0]
	return {"depth": float(verdict[0]), "piece_a": int(verdict[1]),
		"piece_b": int(verdict[2]), "axis": (a.at.basis * (verdict[3] as Vector3)).normalized()}


## Each piece of [param shape] the line through [param point] along [param
## way] (the part's own frame) goes through, or passes within [param slack]
## of: 1, else 0. A piece is the slabs between its spans along its normals,
## so the line is in it where it is in every slab.
static func through(shape: Shape, point: Vector3, way: Vector3, slack: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(shape.pieces.size())
	for p: int in shape.pieces.size():
		var piece: Piece = shape.pieces[p]
		var lo: float = -INF
		var hi: float = INF
		var missed: bool = piece.normals.is_empty()
		for k: int in piece.normals.size():
			var n: Vector3 = piece.normals[k]
			var at: float = n.dot(point)
			var rate: float = n.dot(way)
			var low: float = piece.spans[2 * k] - slack
			var high: float = piece.spans[2 * k + 1] + slack
			if absf(rate) < 1e-6:
				missed = at < low or at > high
			else:
				var t0: float = (low - at) / rate
				var t1: float = (high - at) / rate
				lo = maxf(lo, minf(t0, t1))
				hi = minf(hi, maxf(t0, t1))
				missed = lo > hi
			if missed:
				break
		out[p] = 0 if missed else 1
	return out


## A relative pose said in whole numbers, so the same pose found twice is
## one key: thousandths of an LDU, ten-thousandths of a turn.
static func _key(ida: int, idb: int, rel: Transform3D) -> Array:
	var b: Basis = rel.basis
	return [ida, idb, roundi(rel.origin.x * 1000.0), roundi(rel.origin.y * 1000.0),
		roundi(rel.origin.z * 1000.0),
		roundi(b.x.x * 10000.0), roundi(b.x.y * 10000.0), roundi(b.x.z * 10000.0),
		roundi(b.y.x * 10000.0), roundi(b.y.y * 10000.0), roundi(b.y.z * 10000.0),
		roundi(b.z.x * 10000.0), roundi(b.z.y * 10000.0), roundi(b.z.z * 10000.0)]


## The first pair of pieces that overlap by more than TAU, with b placed at
## [param rel] in a's frame: [depth, piece of a, piece of b, axis in a's
## frame], or [] when none do.
static func _clash_local(a: Shape, b: Shape, rel: Transform3D, allowed: float = TAU) -> Array:
	var hits: Array = _overlapping(a, b, rel, allowed, true)
	return hits[0] if not hits.is_empty() else []


## Every pair of pieces of two placed parts that overlap by more than TAU:
## [depth, piece of a, piece of b, axis in the world from a towards b] each.
## Where [method clash] stops at the first, this finds them all, to say
## where on the two parts they meet.
static func overlaps(a: Item, b: Item) -> Array:
	if a == null or b == null or not a.shape.has_pieces() or not b.shape.has_pieces():
		return []
	var out: Array = []
	for hit: Array in _overlapping(a.shape, b.shape, a.at.affine_inverse() * b.at, TAU, false):
		out.append([hit[0], hit[1], hit[2], (a.at.basis * (hit[3] as Vector3)).normalized()])
	return out


## Directions over the sphere, a Fibonacci lattice of 128: every direction is
## within 13.7 degrees of one of them, so a convex set reaching no further
## than H along each reaches no further than H * [constant SPHERE_SLACK].
## Made as the class loads, not at first use: a build's check runs on a
## worker while a second check runs here (Assistant._checked), and two
## threads appending to one array at once break it, as two filling
## Mechanism's gear table did (racefix, 2026-10-20).
static var _sphere: PackedVector3Array = _lattice_of_directions(128)
const SPHERE_SLACK := 1.03
## And about a line, 7.5 degrees apart: 1 / cos(7.5 degrees) = 1.0086.
const ROUND_STEPS := 24
const ROUND_SLACK := 1.009
## A whole turn, in radians (TAU here is the overlap a build allows).
const TAU_TURN := 2.0 * PI


static func _lattice_of_directions(count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var turn: float = PI * (3.0 - sqrt(5.0))
	for n: int in count:
		var y: float = 1.0 - 2.0 * (float(n) + 0.5) / float(count)
		var r: float = sqrt(1.0 - y * y)
		out.append(Vector3(cos(turn * n) * r, y, sin(turn * n) * r))
	return out


## How far the overlap of piece [param pa] of [param a] and piece [param pb]
## of [param b] can reach from [param point], or from the line through it
## along [param line] when that is not zero, in LDU. An upper bound, the least
## of: how far either piece reaches (the overlap is inside both), and the two
## pieces' common extent along directions all round.
static func overlap_reach(a: Item, pa: int, b: Item, pb: int, point: Vector3,
		line: Vector3 = Vector3.ZERO) -> float:
	var mine: PackedVector3Array = _from(a, pa, point, line)
	var theirs: PackedVector3Array = _from(b, pb, point, line)
	var reach: float = minf(_furthest(mine), _furthest(theirs))
	var ways := PackedVector3Array()
	var slack: float = SPHERE_SLACK
	if line == Vector3.ZERO:
		ways = _sphere
	else:
		var across: Vector3 = line.cross(Vector3.UP if absf(line.y) < 0.9 else Vector3.RIGHT).normalized()
		var other: Vector3 = line.cross(across)
		for n: int in ROUND_STEPS:
			var angle: float = TAU_TURN * float(n) / float(ROUND_STEPS)
			ways.append(across * cos(angle) + other * sin(angle))
		slack = ROUND_SLACK
	var most: float = 0.0
	for way: Vector3 in ways:
		most = maxf(most, minf(_extent(mine, way), _extent(theirs, way)))
	return minf(reach, most * slack)


## A piece's vertices in the world, from [param point] (and square to [param
## line] when it is not zero).
static func _from(item: Item, piece: int, point: Vector3, line: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for v: Vector3 in (item.shape.pieces[piece] as Piece).verts:
		var d: Vector3 = item.at * v - point
		if line != Vector3.ZERO:
			d -= line * d.dot(line)
		out.append(d)
	return out


static func _furthest(verts: PackedVector3Array) -> float:
	var far: float = 0.0
	for v: Vector3 in verts:
		far = maxf(far, v.length())
	return far


static func _extent(verts: PackedVector3Array, way: Vector3) -> float:
	var most: float = -INF
	for v: Vector3 in verts:
		most = maxf(most, v.dot(way))
	return most


## The pairs of pieces that overlap by more than [param allowed], with b
## placed at [param rel] in a's frame: [depth, piece of a, piece of b, axis in
## a's frame] each, the first only when [param first]. The pairs whose boxes
## overlap are found by the two shapes' trees ([method _tree_of]), and asked
## in the order every pair was asked before, b's pieces then a's: a steering
## arm of 176 pieces beside a Technic brick of 316, asked every pair's boxes,
## took 1.5 ms, and by the trees 0.4 (G14a). [param but]: pieces and pairs
## passed over ([method clash_but]).
static func _overlapping(a: Shape, b: Shape, rel: Transform3D, allowed: float,
		first: bool, but: Forgiven = null) -> Array:
	var hits: Array = []
	var whole: Array = box_in(b.lo, b.hi, rel)
	var b_lo: Vector3 = whole[0]
	var b_hi: Vector3 = whole[1]
	var basis: Basis = rel.basis
	# A node is passed by only where it is apart by float dust or more: what
	# it holds is no further in than it is.
	var loose: float = allowed - NODE_DUST
	# b's pieces whose boxes, carried into a's frame, reach into a's box, and
	# for each the pieces of a whose boxes reach into both its box and b's:
	# b's piece << 20 | a's.
	var pairs := PackedInt64Array()
	var b_nodes := PackedInt32Array([0])
	var a_nodes := PackedInt32Array()
	# Each box carried as box_in carries it, without an Array for each.
	var across_x: Vector3 = basis.x.abs()
	var across_y: Vector3 = basis.y.abs()
	var across_z: Vector3 = basis.z.abs()
	while not b_nodes.is_empty():
		var nb: int = b_nodes[b_nodes.size() - 1]
		b_nodes.resize(b_nodes.size() - 1)
		var lo: Vector3 = b.tree_lo[nb]
		var hi: Vector3 = b.tree_hi[nb]
		var half: Vector3 = (hi - lo) * 0.5
		var middle: Vector3 = rel * ((lo + hi) * 0.5)
		var reach: Vector3 = across_x * half.x + across_y * half.y + across_z * half.z
		if not _into(a.lo, a.hi, middle - reach, middle + reach, loose):
			continue
		if b.tree_left[nb] >= 0:
			b_nodes.append(b.tree_left[nb])
			b_nodes.append(b.tree_right[nb])
			continue
		for n: int in range(b.tree_first[nb], b.tree_first[nb] + b.tree_right[nb]):
			var j: int = b.tree_pieces[n]
			var q: Piece = b.pieces[j]
			half = (q.hi - q.lo) * 0.5
			middle = rel * ((q.lo + q.hi) * 0.5)
			reach = across_x * half.x + across_y * half.y + across_z * half.z
			var q_lo: Vector3 = middle - reach
			var q_hi: Vector3 = middle + reach
			if not _into(a.lo, a.hi, q_lo, q_hi, allowed):
				continue
			a_nodes.append(0)
			while not a_nodes.is_empty():
				var na: int = a_nodes[a_nodes.size() - 1]
				a_nodes.resize(a_nodes.size() - 1)
				if not _into(a.tree_lo[na], a.tree_hi[na], q_lo, q_hi, loose):
					continue
				if a.tree_left[na] >= 0:
					a_nodes.append(a.tree_left[na])
					a_nodes.append(a.tree_right[na])
					continue
				for m: int in range(a.tree_first[na], a.tree_first[na] + a.tree_right[na]):
					var i: int = a.tree_pieces[m]
					var p: Piece = a.pieces[i]
					if _into(p.lo, p.hi, b_lo, b_hi, allowed) and _into(p.lo, p.hi, q_lo, q_hi, allowed):
						pairs.append((j << 20) | i)
	pairs.sort()
	var moved := PackedVector3Array()
	var moved_for: int = -1
	for pair: int in pairs:
		var j: int = pair >> 20
		var i: int = pair & 0xFFFFF
		if but != null and (but.pairs.has(pair) or not but.a_pieces.is_empty() and but.a_pieces[i] == 1
				or not but.b_pieces.is_empty() and but.b_pieces[j] == 1):
			continue
		var q: Piece = b.pieces[j]
		if moved_for != j:
			moved_for = j
			moved.resize(q.verts.size())
			for v: int in q.verts.size():
				moved[v] = rel * q.verts[v]
		var found: Array = _overlap(a.pieces[i], q, moved, basis, rel.origin, allowed)
		if not found.is_empty():
			hits.append([found[0], i, j, found[1]])
			if first:
				return hits
	return hits


## How far a node's box may stand apart and still be descended into, LDU, as
## a margin for float rounding in carrying it ([method _overlapping]).
const NODE_DUST := 0.001
## At most this many pieces in a leaf of a shape's tree.
const LEAF_PIECES := 4


## Whether the box [param lo] to [param hi] and the box [param o_lo] to
## [param o_hi] overlap by more than [param by] along each axis.
static func _into(lo: Vector3, hi: Vector3, o_lo: Vector3, o_hi: Vector3, by: float) -> bool:
	return minf(hi.x, o_hi.x) - maxf(lo.x, o_lo.x) > by \
		and minf(hi.y, o_hi.y) - maxf(lo.y, o_lo.y) > by \
		and minf(hi.z, o_hi.z) - maxf(lo.z, o_lo.z) > by


## [param shape]'s tree of its pieces' boxes, as it is read ([method parse]),
## so a shape read is never changed again and any thread may ask it: halved
## along the way their middles spread most, down to [constant LEAF_PIECES] a
## leaf.
static func _tree_of(shape: Shape) -> void:
	var order: Array = []
	for i: int in shape.pieces.size():
		order.append(i)
	var lo: Array = []
	var hi: Array = []
	var left: Array = []
	var right: Array = []
	var firsts: Array = []
	if not order.is_empty():
		_tree_node(shape, order, 0, order.size(), [lo, hi, left, right, firsts])
	shape.tree_pieces = PackedInt32Array(order)
	shape.tree_lo = PackedVector3Array(lo)
	shape.tree_hi = PackedVector3Array(hi)
	shape.tree_left = PackedInt32Array(left)
	shape.tree_right = PackedInt32Array(right)
	shape.tree_first = PackedInt32Array(firsts)


## The node over [param order]'s pieces [param start] to [param end], made
## into [param into] ([lo, hi, left, right, first]) with its children: its
## index there.
static func _tree_node(shape: Shape, order: Array, start: int, end: int, into: Array) -> int:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var middle_lo := lo
	var middle_hi := hi
	for n: int in range(start, end):
		var p: Piece = shape.pieces[int(order[n])]
		lo = lo.min(p.lo)
		hi = hi.max(p.hi)
		middle_lo = middle_lo.min((p.lo + p.hi) * 0.5)
		middle_hi = middle_hi.max((p.lo + p.hi) * 0.5)
	var at: int = (into[0] as Array).size()
	(into[0] as Array).append(lo)
	(into[1] as Array).append(hi)
	(into[2] as Array).append(-1)
	(into[3] as Array).append(end - start)
	(into[4] as Array).append(start)
	if end - start <= LEAF_PIECES:
		return at
	# Sorted by their middles along that way, a sixteenth of an LDU apart,
	# each kept with its index below: an engine sort, not a script's.
	var axis: int = (middle_hi - middle_lo).max_axis_index()
	var keys := PackedInt64Array()
	keys.resize(end - start)
	for n: int in range(start, end):
		var p: Piece = shape.pieces[int(order[n])]
		keys[n - start] = (int(roundf((p.lo[axis] + p.hi[axis]) * 8.0)) + (1 << 30)) << 20 | int(order[n])
	keys.sort()
	for n: int in keys.size():
		order[start + n] = int(keys[n] & 0xFFFFF)
	var half: int = start + (end - start) / 2
	var left: int = _tree_node(shape, order, start, half, into)
	var right: int = _tree_node(shape, order, half, end, into)
	(into[2] as Array)[at] = left
	(into[3] as Array)[at] = right
	return at


## The depth two convex pieces overlap by, with its axis, when it is more
## than TAU along every axis that could separate them; [] otherwise. [param
## moved] is q's vertices in p's frame, [param basis] and [param origin] q's
## frame in p's.
static func _overlap(p: Piece, q: Piece, moved: PackedVector3Array, basis: Basis,
		origin: Vector3, allowed: float = TAU) -> Array:
	var best: float = INF
	var best_axis := Vector3.ZERO
	# p's face normals: p's own extent is known, q's is projected.
	for k: int in p.normals.size():
		var n: Vector3 = p.normals[k]
		var low: float = INF
		var high: float = -INF
		for v: Vector3 in moved:
			var d: float = v.dot(n)
			if d < low:
				low = d
			if d > high:
				high = d
		var o: float = minf(p.spans[2 * k + 1] - low, high - p.spans[2 * k])
		if o <= allowed:
			return []
		if o < best:
			best = o
			best_axis = n if p.spans[2 * k + 1] - low < high - p.spans[2 * k] else -n
	# q's face normals, turned into p's frame: q's extent is known.
	for k: int in q.normals.size():
		var n: Vector3 = basis * q.normals[k]
		var shift: float = n.dot(origin)
		var q_low: float = q.spans[2 * k] + shift
		var q_high: float = q.spans[2 * k + 1] + shift
		var low: float = INF
		var high: float = -INF
		for v: Vector3 in p.verts:
			var d: float = v.dot(n)
			if d < low:
				low = d
			if d > high:
				high = d
		var o: float = minf(high - q_low, q_high - low)
		if o <= allowed:
			return []
		if o < best:
			best = o
			best_axis = n if high - q_low < q_high - low else -n
	# Edge against edge.
	for e: Vector3 in p.edges:
		for f0: Vector3 in q.edges:
			var c: Vector3 = e.cross(basis * f0)
			var size: float = c.length()
			if size < 1e-6:
				continue
			c /= size
			var low_p: float = INF
			var high_p: float = -INF
			for v: Vector3 in p.verts:
				var d: float = v.dot(c)
				if d < low_p:
					low_p = d
				if d > high_p:
					high_p = d
			var low_q: float = INF
			var high_q: float = -INF
			for v: Vector3 in moved:
				var d: float = v.dot(c)
				if d < low_q:
					low_q = d
				if d > high_q:
					high_q = d
			var o: float = minf(high_p - low_q, high_q - low_p)
			if o <= allowed:
				return []
			if o < best:
				best = o
				best_axis = c if high_p - low_q < high_q - low_p else -c
	if best == INF:
		return []
	return [best, best_axis]


# -- connections -----------------------------------------------------------


## Each connector of each item in the world: [item, connector, position, axis
## (the way it points), frame basis], for every item with a shape.
static func _world_connectors(items: Array, only: PackedInt32Array = PackedInt32Array()) -> Array:
	var out: Array = []
	for i: int in (only if not only.is_empty() else _every(items.size())):
		var item: Item = items[i]
		if item == null:
			continue
		for one: Array in item.world():
			out.append([i, one[0], one[1], one[2], one[3]])
	return out


static func _mates(table: Array, a: int, b: int) -> bool:
	var low: int = mini(a, b)
	var high: int = maxi(a, b)
	for pair: Array in table:
		if pair[0] == low and pair[1] == high:
			return true
	return false


## Whether two connectors of different parts meet by BrickNet's rules.
## [param one] and [param other] are entries of [method _world_connectors].
static func meets(items: Array, one: Array, other: Array) -> bool:
	var a: Shape = (items[one[0]] as Item).shape
	var b: Shape = (items[other[0]] as Item).shape
	var ka: int = a.kind[one[1]]
	var kb: int = b.kind[other[1]]
	var sa: int = a.sub[one[1]]
	var sb: int = b.sub[other[1]]
	var pa: Vector3 = one[2]
	var pb: Vector3 = other[2]
	var xa: Vector3 = one[3]
	var xb: Vector3 = other[3]
	if (ka == STUD and kb == HOLE) or (ka == HOLE and kb == STUD):
		return pa.distance_to(pb) <= POS_THR and _mates(STUD_MATES, sa, sb) \
			and xa.dot(xb) >= AXIS_THR
	if ka != kb or ka < HINGE:
		return false
	if ka == AXLE:
		if not _mates(AXLE_MATES, sa, sb):
			return false
		if absf(xa.dot(xb)) < AXLE_AXIS_THR:
			return false
		var ref: Vector3 = xa if not A_SIDE.has(sa) or A_SIDE.has(sb) else xb
		var delta: Vector3 = pb - pa
		var along: float = delta.dot(ref)
		var perp: float = (delta - ref * along).length_squared()
		if perp > POS_THR * POS_THR:
			return false
		var la: float = maxf(a.length[one[1]], AXLE_DEFAULT_RAD)
		var lb: float = maxf(b.length[other[1]], AXLE_DEFAULT_RAD)
		var overlap: float = la + lb - absf(along)
		if overlap < AXLE_MIN_OVERLAP and sqrt(maxf(0.0, POS_THR * POS_THR - perp)) \
				< AXLE_MIN_OVERLAP - overlap - 1e-4:
			return false
		return true
	var qa: int = a.pol[one[1]]
	var qb: int = b.pol[other[1]]
	if sa != sb or qa == NO_POLARITY or qb == NO_POLARITY or qa == qb:
		return false
	if pa.distance_to(pb) > POS_THR:
		return false
	if ka == HINGE:
		return absf(xa.dot(xb)) >= AXIS_THR
	if ka == FIXED and FIXED_ORIENTED.has(sa) and FIXED_ORIENTED.has(sb):
		if xa.dot(xb) < FIXED_AXIS_THR:
			return false
		var fa: Basis = one[4]
		var fb: Basis = other[4]
		var trace: float = fa.x.dot(fb.x) + fa.y.dot(fb.y) + fa.z.dot(fb.z)
		return trace >= FIXED_FRAME_TRACE
	return true


## BrickNet's connections between [param items]: [item, connector, item,
## connector] each, the first item the lower. Studs, holes, hinges, balls and
## fixed joints within POS_THR; axles along their lines, between parts whose
## boxes come within reach.
static func connections(items: Array, only: PackedInt32Array = PackedInt32Array()) -> Array:
	var conns: Array = _world_connectors(items, only)
	var grid: Dictionary = {}
	var out: Array = []
	var seen: Dictionary = {}
	var axles_of: Dictionary = {}     ## item -> indices into conns of its axle connectors
	for c: int in conns.size():
		var entry: Array = conns[c]
		var item: int = entry[0]
		var kind: int = (items[item] as Item).shape.kind[entry[1]]
		if kind == AXLE:
			var axles: PackedInt32Array = axles_of.get(item, PackedInt32Array())
			axles.append(c)
			axles_of[item] = axles
			continue
		var at: Vector3 = entry[2]
		var cell := Vector3i((at / POS_THR).floor())
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				for dz: int in range(-1, 2):
					var there: Variant = grid.get(cell + Vector3i(dx, dy, dz))
					if there == null:
						continue
					for d: int in (there as PackedInt32Array):
						var other: Array = conns[d]
						if int(other[0]) == item:
							continue
						if meets(items, other, entry):
							_note_edge(out, seen, other, entry)
		var here: PackedInt32Array = grid.get(cell, PackedInt32Array())
		here.append(c)
		grid[cell] = here
	if axles_of.size() > 1:
		var with_axles := PackedInt32Array()
		for item: Variant in axles_of:
			with_axles.append(int(item))
		with_axles.sort()
		for pair: Vector2i in candidates(items, -POS_THR, Callable(), with_axles):
			for c: int in (axles_of[pair.x] as PackedInt32Array):
				for d: int in (axles_of[pair.y] as PackedInt32Array):
					if meets(items, conns[c], conns[d]):
						_note_edge(out, seen, conns[c], conns[d])
	return out


static func _note_edge(out: Array, seen: Dictionary, one: Array, other: Array) -> void:
	var a: Array = one
	var b: Array = other
	if int(a[0]) > int(b[0]):
		a = other
		b = one
	var key := Vector4i(a[0], a[1], b[0], b[1])
	if seen.has(key):
		return
	seen[key] = true
	out.append([int(a[0]), int(a[1]), int(b[0]), int(b[1])])


## Which piece each item is in, joined by [param edges] ([a, _, b, _] each):
## the lowest item of its piece, for each item.
static func pieces(count: int, edges: Array) -> PackedInt32Array:
	var root := PackedInt32Array()
	root.resize(count)
	for i: int in count:
		root[i] = i
	for edge: Array in edges:
		var a: int = _find(root, int(edge[0]))
		var b: int = _find(root, int(edge[2]))
		if a != b:
			root[maxi(a, b)] = mini(a, b)
	for i: int in count:
		root[i] = _find(root, i)
	return root


static func _find(root: PackedInt32Array, i: int) -> int:
	while root[i] != i:
		root[i] = root[root[i]]
		i = root[i]
	return i


# -- seating ---------------------------------------------------------------


## For item [param i]: how far its connectors are from meeting another part's
## exactly, as the move that would seat the nearest one, {move, mine, other,
## item, residual}; {} when one already meets exactly (within [param exact])
## or none comes within [param reach]. Only connectors that would meet once
## moved: a stud and a hole pointing the same way, a hinge and its other
## half, a clip and a bar along one line (whose move is across the line).
static func seat_move(items: Array, i: int, reach: float, exact: float = 0.05,
		among: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var item: Item = items[i]
	if item == null or item.shape.kind.is_empty():
		return {}
	var near: PackedInt32Array = _near(items, i, among, reach + POS_THR, true)
	if near.is_empty():
		return {}
	var mine: Array = _world_connectors(items, PackedInt32Array([i]))
	# Theirs by where they are, a cell of [param reach] each, so a connector
	# of this part is set only against those within reach of it.
	var grid: Dictionary = {}
	for entry: Array in _world_connectors(items, near):
		var cell := Vector3i(((entry[2] as Vector3) / reach).floor())
		var list: Array = grid.get(cell, [])
		list.append(entry)
		grid[cell] = list
	var best: Dictionary = {}
	for one: Array in mine:
		var cell := Vector3i(((one[2] as Vector3) / reach).floor())
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				for dz: int in range(-1, 2):
					for other: Array in grid.get(cell + Vector3i(dx, dy, dz), []):
						var move: Variant = _move_to_meet(items, one, other, reach)
						if move == null:
							continue
						var residual: float = (move as Vector3).length()
						if residual <= exact:
							return {}
						if best.is_empty() or residual < float(best["residual"]):
							best = {"move": move, "mine": int(one[1]), "other": int(other[1]),
								"item": int(other[0]), "residual": residual}
	return best


## The items of [param among] (every item when it is empty) whose boxes come
## within [param reach] of item [param i]'s, not [param i] itself; only those
## with connectors when [param connectors].
static func _near(items: Array, i: int, among: PackedInt32Array, reach: float,
		connectors: bool = false) -> PackedInt32Array:
	var item: Item = items[i]
	var out := PackedInt32Array()
	for j: int in (among if not among.is_empty() else _every(items.size())):
		var other: Item = items[j]
		if j == i or other == null or (connectors and other.shape.kind.is_empty()):
			continue
		if other.lo.x - reach > item.hi.x or item.lo.x - reach > other.hi.x \
				or other.lo.y - reach > item.hi.y or item.lo.y - reach > other.hi.y \
				or other.lo.z - reach > item.hi.z or item.lo.z - reach > other.hi.z:
			continue
		out.append(j)
	return out


## The move that would put connector [param one] where it meets [param
## other], or null when the two never meet that way or are further than
## [param reach] apart.
static func _move_to_meet(items: Array, one: Array, other: Array, reach: float) -> Variant:
	var a: Shape = (items[one[0]] as Item).shape
	var b: Shape = (items[other[0]] as Item).shape
	var ka: int = a.kind[one[1]]
	var kb: int = b.kind[other[1]]
	var sa: int = a.sub[one[1]]
	var sb: int = b.sub[other[1]]
	var xa: Vector3 = one[3]
	var xb: Vector3 = other[3]
	var delta: Vector3 = (other[2] as Vector3) - (one[2] as Vector3)
	if delta.length() > reach:
		return null
	if (ka == STUD and kb == HOLE) or (ka == HOLE and kb == STUD):
		if not _mates(STUD_MATES, sa, sb) or xa.dot(xb) < AXIS_THR:
			return null
		return delta
	if ka != kb or ka < HINGE:
		return null
	if ka == AXLE:
		if not _mates(AXLE_MATES, sa, sb) or absf(xa.dot(xb)) < AXLE_AXIS_THR:
			return null
		# Along the line it may slide; only across it is it off.
		var ref: Vector3 = xb
		return delta - ref * delta.dot(ref)
	var qa: int = a.pol[one[1]]
	var qb: int = b.pol[other[1]]
	if sa != sb or qa == NO_POLARITY or qb == NO_POLARITY or qa == qb:
		return null
	if ka == HINGE and absf(xa.dot(xb)) < AXIS_THR:
		return null
	return delta


## For item [param i], joined by a bar, a clip or an axle to one of [param
## among] (by one of [param subs] of its own, when given), the slide along
## that line, in steps of [param step] LDU up to the joint's own play, that
## clears it of every other item while it stays joined: the move, or null. A
## sword whose guard was through the hand that holds it slides along its grip
## until it is clear, as it would in a hand.
static func slide_clear(items: Array, i: int, among: PackedInt32Array, step: float = 1.0,
		subs: Array = []) -> Variant:
	var item: Item = items[i]
	if item == null:
		return null
	var line := Vector3.ZERO
	var play: float = 0.0
	var these := PackedInt32Array([i])
	these.append_array(among)
	for edge: Array in connections(items, these):
		if int(edge[0]) != i and int(edge[2]) != i:
			continue
		var mine: int = int(edge[1]) if int(edge[0]) == i else int(edge[3])
		var other: int = int(edge[2]) if int(edge[0]) == i else int(edge[0])
		var other_k: int = int(edge[3]) if int(edge[0]) == i else int(edge[1])
		if item.shape.kind[mine] != AXLE or (not subs.is_empty() and not subs.has(item.shape.sub[mine])):
			continue
		var them: Item = items[other]
		line = -(them.at.basis * them.shape.frames[other_k].basis.y).normalized()
		play = maxf(item.shape.length[mine], AXLE_DEFAULT_RAD) \
			+ maxf(them.shape.length[other_k], AXLE_DEFAULT_RAD) - AXLE_MIN_OVERLAP
		break
	if line == Vector3.ZERO or play <= 0.0:
		return null
	# What it could run into, sliding as far as it may.
	var around: PackedInt32Array = _near(items, i, PackedInt32Array(), play + TAU)
	var steps: int = int(floor(play / step))
	for n: int in range(1, steps + 1):
		for sign: float in [1.0, -1.0]:
			var move: Vector3 = line * (step * n * sign)
			var there := Item.new(item.shape, item.at.translated(move))
			var clear: bool = true
			for j: int in around:
				if items[j] != null and not clash(there, items[j], true).is_empty():
					clear = false
					break
			if not clear:
				continue
			var was: Item = items[i]
			items[i] = there
			var joined: bool = connected(items, i, among)
			items[i] = was
			if joined:
				return move
	return null


## Whether item [param i] has any connection by BrickNet's rules to another
## of [param items].
static func connected(items: Array, i: int,
		among: PackedInt32Array = PackedInt32Array()) -> bool:
	var item: Item = items[i]
	if item == null or item.shape.kind.is_empty():
		return false
	var these := PackedInt32Array([i])
	these.append_array(_near(items, i, among, POS_THR, true))
	if these.size() < 2:
		return false
	these.sort()
	for edge: Array in connections(items, these):
		if int(edge[0]) == i or int(edge[2]) == i:
			return true
	return false
