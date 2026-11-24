## A part of one's own from a 3D file: an STL or an OBJ made anywhere — a
## hairstyle sculpted for a minifigure, a goblet for its hand, a piece no
## set has — brought in as an LDraw part with the connectors a person puts
## on it.
##
## The bar is BrickLink Studio's Part Designer, which imports a mesh and
## lets you place connectors on it. Here it is quicker: the shape lands at
## LDraw's scale, upright and centred, beside a 1 x 1 brick; one click puts
## a stud, an anti-stud, a bar, a bar hole or a pin hole where the person
## points; and "This is hair" seats it on a minifigure's head in one step.
## And it works in a browser, which has no Part Designer at all.
##
## Read at the edge, refused in words: a shape that is not closed (a hole in
## its surface: no mould could make it, and the app could not tell its
## inside from its outside), one with no size, one past what a part may
## carry. Past [constant MOST_TRIANGLES] it is simplified — edges collapsed
## cheapest first, by the error each makes against the planes of the
## surface it stands for (Garland and Heckbert's quadrics) — and kept only
## when every corner of the file is still within [method holds_within] of
## the simplified surface and every corner of that within it of the file's:
## the shape is measured, not hoped for.
##
## The part is an LDraw source like every part made here ([CustomParts]):
## its triangles as `3` lines, a stud drawn with stud.dat, a bar with a
## cylinder, and every connector as a `0 !BRICKWORKS CONNECTOR` line, which
## [PartForge] and tools/ldraw/connectivity.py read and other programs pass
## over. Kept in user://custom_parts/ and carried inside every model that
## uses it as `0 FILE`, it opens on a machine that never saw it, and in
## LDCad.
##
## Hair is worn as 3901 is: its origin is the head's, the middle of the top
## of the head with the stud above it, and its socket 3901's own, a stud
## tube 4 LDU up facing down. "This is hair" finds where the head goes: the
## inside of the crown nearest above it is put on the top of the head's
## stud, at whichever point under the crown the head is clearest of the
## hair, so the head's stud is in the hair and the hair turns with the head.
##
## Corners are kept in the app's axes (Y up, a figure facing +Z), as
## [Mould] keeps them, three to a triangle wound as LDraw winds them (the
## right-hand rule gives the outside); LDraw's are written out.
class_name MeshPart
extends RefCounted

## The most triangles the part keeps: a file of about half a megabyte,
## which a browser builds in a few seconds and a model carries ([Mould]'s
## own limit).
const MOST_TRIANGLES := 9000
## The most a file may have to be simplified to that at all. Past it the
## simplifying would take a browser longer than anyone waits.
const MOST_BROUGHT := 120000
## The most a file a part is made from may be, judged from its size before it
## is read (MeshFilePicker): a text STL of [constant MOST_BROUGHT] triangles
## is about 31 MB, a binary one 6 MB, and an OBJ less.
const MOST_BYTES := 32 * 1024 * 1024
## What it reads, by extension, and the same as a person is told it.
const KINDS: PackedStringArray = ["stl", "obj"]
const NAMED := "STL or OBJ"
## How near the simplified surface must stay to the file's, as a share of
## its longest side: a hundredth. On a minifigure's hair, 34 LDU across,
## that is a third of an LDU, 0.14 mm, about a 3D printer's layer; it is
## the furthest any point moved, most of them far less. A 68,416-triangle
## ponytail made 9,000 moved by 0.6% at most (0.4% refused it).
const HOLDS_SHARE := 0.01
## LDraw units.
const LDU_PER_MM := 2.5
const STUD := 20.0
const LATTICE := 2.0
## The sizes a person can say, and what one of each is in LDU.
const UNITS: Dictionary = {"LDU": 1.0, "mm": LDU_PER_MM, "studs": STUD}
## The longest a part may be, mm: past every one of LEGO's own (a 48 x 48
## baseplate is 384 mm), and refused in a sentence before anything is made
## ([method size_problem]). A part's cost to build is bounded whatever its
## size (PartForge.MADE_DENSE_MOST: past it its cover follows its surface);
## this is the size a part is.
const MOST_MM := 400.0
## The sizes a file's own units are read as millimetres without asking:
## from about the smallest of LEGO's elements to the longest a part may be.
## Outside them the file's units are asked ([member unit_unsure]): an STL
## says none, and one 1.5 long may be in metres, or inches, or millimetres.
const LEAST_MM := 4.0
## What a file may be measured in, and how many millimetres one of each is.
const FILE_UNITS: Dictionary = {"mm": 1.0, "cm": 10.0, "m": 1000.0, "inches": 25.4}

## The connectors one click puts, by the words on their buttons: [LDraw
## kind, gender, length, radius]. A bar is 3.18 mm across, a bar hole takes
## one; a stud and an anti-stud are LEGO's own; a hair socket is 3901's.
const CONNECTORS: Dictionary = {
	"stud": ["stud", "male", 0.0, 0.0],
	"anti-stud": ["tube", "female", 0.0, 0.0],
	"bar": ["shaft", "male", 12.0, 4.0],
	"bar hole": ["bore", "female", 8.0, 4.0],
	"pin hole": ["pin_hole", "neutral", 0.0, 0.0],
	"hair socket": ["tube", "female", 0.0, 0.0],
}
## A part thinner than this where a bar is put is the bar: a goblet's stem,
## a sword's grip. Thicker, the bar stands out of it.
const THIN_FOR_BAR := 10.0
## The longest a bar along a stem is taken to be, LDU.
const LONGEST_BAR := 60.0

## Where a minifigure's head is, in its own frame (the app's axes): the top
## of the head at y 0, its stud 4 LDU above, the neck 24 below (3626c).
const STUD_TOP := 4.0
const HEAD_RADIUS := 11.5
const HEAD_STUD_RADIUS := 5.6
## The socket 3901 has, in LDraw's axes: the head's stud goes in here.
const HAIR_SOCKET: Array = ["tube", "female", 0.0, -4.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]
## How a hair piece's socket is drawn: 3901's own tube round the head's
## stud, and plastic from its top up into the crown, this wide (the tube's
## outside), so the stud's tip is in the part and the hair turns with the
## head ([Joints].studs_in reads the plastic just past a stud's tip). A
## shell from a 3D file had air there: the wig's crown rose off the stud
## round its middle, and the hair stood on the head held by nothing.
const SOCKET_RADIUS := 8.0
const SOCKET_SIDES := 16
const HAIR_BASE := "3901"
## An STL's Z up turned to the app's Y up, exactly: (x, y, z) to (x, z, -y).
## Basis(Vector3.RIGHT, -PI / 2) leaves float dust in the zeros, and a flat
## sheet came out 4e-7 thick, so with a size.
const UPRIGHT_FROM_Z := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
## How wide a hair piece is across, LDU: 3901 is 30, 87990 34.
const HAIR_WIDTH := 34.0
const HAIR_WIDEST := 48.0
const HAIR_NARROWEST := 24.0

## The line a part brought in this way says where it came from in, read by
## [method PartPrints.base_in] for what it stands for on a figure.
const IMPORTED_BY := PartPrints.IMPORTED_BY
const AUTHOR := "Brickworks part importer"

## Why it was refused, in a sentence a person can act on; "" when it was not.
var problem: String = ""
## What was done to it on the way in that the person should know: "".
var note: String = ""
var file: String = ""
var name: String = ""
## Its corners in the file's units, turned upright (the app's axes), and its
## triangles, three corners each, wound outward.
var corners := PackedVector3Array()
var triangles := PackedInt32Array()
## How many triangles the file had, and how far, at most, the simplified
## surface is from it, in the file's units (0 when nothing was simplified).
var file_triangles: int = 0
var moved_by: float = 0.0

## The fit: a turn (quarter turns of the file's own upright), LDU per unit
## of the file, and where its corners go after.
var turn := Basis.IDENTITY
var scale: float = LDU_PER_MM
var offset := Vector3.ZERO
## What the scale is made a hair larger or smaller by, so its height is a
## whole number of lattice steps ([method refit]); 1 for hair.
var _snap: float = 1.0
## The unit its size is said in.
var unit: String = "mm"
## What the file is read as measured in (a key of [constant FILE_UNITS]),
## and whether that is a guess to ask about: its size read as millimetres
## is no part's ([method guess_fit]). Answered by [method read_as], or by a
## size given ([method set_longest]).
var file_unit: String = "mm"
var unit_unsure: bool = false
## Worn on a minifigure's head, seated by [method seat_on_head] or a
## socket put by hand.
var hair: bool = false
## Of the head's points looked at, how many are inside the hair: 0 is a
## hair the head is clear of.
var head_inside: float = 0.0
## What was put on it: {kind, at, normal} in the file's units and axes, so
## each moves with the surface it was put on when the part is resized.
var connectors: Array[Dictionary] = []

var _fitted := PackedVector3Array()
var _columns: Dictionary = {}
var _column_cell: float = 1.0


# -- reading a file -----------------------------------------------------------------


## A file read and checked. Never null: [member problem] says why not.
static func read(bytes: PackedByteArray, file_name: String,
		extras: Dictionary = {}) -> MeshPart:
	var out := MeshPart.new()
	# What it was called, read here once into words of ours: no line break or
	# other control character of a file's name reaches the part's lines
	# (mouldreview: a name holding a line break wrote a 0 FILE into it).
	out.file = name_from(file_name.get_file())
	var kind: String = out.file.get_extension().to_lower()
	if out.file.get_basename().is_empty():
		out.file = "file." + kind
	out.name = _title_from(out.file.get_basename())
	if not kind in KINDS:
		out.problem = "%s is not a 3D file this can make a part from: choose an %s file." % [
			out.file, NAMED]
		return out
	if bytes.size() > MOST_BYTES:
		out.problem = MeshFile.too_large(out.file, bytes.size(), MOST_BYTES) + "."
		return out
	var mesh: MeshFile = MeshFile.read(bytes, out.file, extras)
	if not mesh.error.is_empty():
		# A sentence's first letter, but a file's name as it is: "zero.stl
		# has no surfaces", not "Zero.stl".
		out.problem = (mesh.error if mesh.error.begins_with(out.file)
			else mesh.error[0].to_upper() + mesh.error.substr(1)) + "."
		return out
	out.file_triangles = mesh.triangle_count()
	if out.file_triangles > MOST_BROUGHT:
		out.problem = ("%s has %s triangles. A part can be made from at most %s: reduce it in your "
			+ "3D program first (Blender's Decimate modifier does it).") % [out.file,
			_count(out.file_triangles), _count(MOST_BROUGHT)]
		return out
	# STL is drawn Z up, as printers have it; OBJ Y up.
	var upright := Basis.IDENTITY if mesh.up == "+Y" else UPRIGHT_FROM_Z
	var points := PackedVector3Array()
	points.resize(mesh.positions.size())
	for n: int in mesh.positions.size():
		points[n] = upright * mesh.positions[n]
	out._take(points)
	if out.problem.is_empty():
		out.guess_fit()
	return out


## Corners three to a triangle, welded into one surface and checked:
## closed, sized, wound outward, simplified if it must be.
func _take(points: PackedVector3Array) -> void:
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	# A side under a millionth of the longest is none: a flat sheet turned
	# upright keeps a side of float dust.
	var least: float = minf(box.size.x, minf(box.size.y, box.size.z))
	if not is_finite(longest) or longest <= 0.0 or least <= longest * 1e-6:
		problem = "%s has no size: its points are all in one place, on one line or one flat sheet." \
			% file
		return
	# Corners within a millionth of the file's size are one corner: a file
	# from a printer's slicer repeats each in full, to the last bit, and one
	# written out in text rounds it.
	var cell: float = longest * 1e-6
	var index: Dictionary = {}
	corners = PackedVector3Array()
	triangles = PackedInt32Array()
	for t: int in points.size() / 3:
		var three := PackedInt32Array()
		for k: int in 3:
			var p: Vector3 = points[t * 3 + k]
			var key := Vector3i((p / cell).round())
			if not index.has(key):
				index[key] = corners.size()
				corners.append(p)
			three.append(int(index[key]))
		if three[0] == three[1] or three[1] == three[2] or three[0] == three[2]:
			continue
		triangles.append_array(three)
	if triangles.is_empty():
		problem = "%s has no surfaces with any size to them." % file
		return
	var holes: int = _orient()
	if holes > 0:
		problem = ("%s is not a closed shape: %s of its surface border a hole. A part has "
			+ "to be solid to be moulded. Close it in your 3D program (in Blender: select all, "
			+ "then Mesh > Clean Up > Fill Holes) and bring it in again.") % [file,
			Counted.of(holes, "edge")]
		return
	if triangles.size() / 3 > MOST_TRIANGLES:
		var had: int = triangles.size() / 3
		var kept: PackedVector3Array = corners.duplicate()
		var kept_triangles: PackedInt32Array = triangles.duplicate()
		_simplify(MOST_TRIANGLES)
		var allowed: float = holds_within(longest)
		moved_by = _furthest(kept, kept_triangles, corners, triangles, allowed * 2.0)
		if moved_by > allowed:
			problem = ("%s has %s triangles; a part keeps at most %s, and made that simple its "
				+ "surface would move by up to %s of its size. Reduce it in your 3D program first "
				+ "(Blender's Decimate modifier does it).") % [file, _count(had),
				_count(MOST_TRIANGLES), "%.1f%%" % (100.0 * moved_by / longest)
				if moved_by < INF else "more than %.1f%%" % (200.0 * allowed / longest)]
			return
		note = "Simplified from %s triangles to %s; no point of it moved more than %s of its size." \
			% [_count(had), _count(triangles.size() / 3), "%.2f%%" % (100.0 * maxf(moved_by, 0.0) / longest)]


## How far the simplified surface may be from the file's: [constant
## HOLDS_SHARE] of the longest side. For a minifigure's hair 34 LDU across,
## 0.14 LDU, a twentieth of a millimetre.
static func holds_within(longest: float) -> float:
	return longest * HOLDS_SHARE


## Each triangle turned to agree with its neighbours across every edge, and
## all of them outward; how many edges border a hole (used once, or an odd
## number of times), which a closed surface has none of.
func _orient() -> int:
	var count: int = triangles.size() / 3
	var edges: Dictionary = {}       ## Vector2i(low, high) -> triangles on it
	for t: int in count:
		for k: int in 3:
			var a: int = triangles[t * 3 + k]
			var b: int = triangles[t * 3 + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not edges.has(key):
				edges[key] = PackedInt32Array()
			edges[key].append(t)
	var holes: int = 0
	for key: Vector2i in edges:
		if (edges[key] as PackedInt32Array).size() % 2 == 1:
			holes += 1
	if holes > 0:
		return holes
	# Each piece of surface flood-filled from one triangle, its neighbours
	# across two-triangle edges turned to run each edge the other way.
	var done := PackedByteArray()
	done.resize(count)
	var pieces: Array[PackedInt32Array] = []
	for first: int in count:
		if done[first] == 1:
			continue
		var piece := PackedInt32Array([first])
		done[first] = 1
		var at: int = 0
		while at < piece.size():
			var t: int = piece[at]
			at += 1
			for k: int in 3:
				var a: int = triangles[t * 3 + k]
				var b: int = triangles[t * 3 + (k + 1) % 3]
				var on: PackedInt32Array = edges[Vector2i(mini(a, b), maxi(a, b))]
				if on.size() != 2:
					continue
				var other: int = on[0] if on[1] == t else on[1]
				if done[other] == 1:
					continue
				done[other] = 1
				# Agreeing, the other runs b to a.
				if _runs(other, a, b):
					_flip(other)
				piece.append(other)
		pieces.append(piece)
	# Each piece outward: the volume it encloses, by its winding, positive.
	for piece: PackedInt32Array in pieces:
		var volume: float = 0.0
		for t: int in piece:
			var a: Vector3 = corners[triangles[t * 3]]
			volume += a.dot(corners[triangles[t * 3 + 1]].cross(corners[triangles[t * 3 + 2]]))
		if volume < 0.0:
			for t: int in piece:
				_flip(t)
	return 0


func _runs(t: int, a: int, b: int) -> bool:
	for k: int in 3:
		if triangles[t * 3 + k] == a and triangles[t * 3 + (k + 1) % 3] == b:
			return true
	return false


func _flip(t: int) -> void:
	var keep: int = triangles[t * 3 + 1]
	triangles[t * 3 + 1] = triangles[t * 3 + 2]
	triangles[t * 3 + 2] = keep


# -- simplifying ---------------------------------------------------------------------


## Down to [param target] triangles: the edge whose collapse moves the
## surface least, first, while any is left whose collapse keeps the surface
## closed and every triangle facing the way it faced.
func _simplify(target: int) -> void:
	var n: int = corners.size()
	var count: int = triangles.size() / 3
	var quadrics := PackedFloat64Array()
	quadrics.resize(n * 10)
	var faces_of: Array[PackedInt32Array] = []
	faces_of.resize(n)
	for t: int in count:
		var a: Vector3 = corners[triangles[t * 3]]
		var normal: Vector3 = (corners[triangles[t * 3 + 1]] - a).cross(
			corners[triangles[t * 3 + 2]] - a)
		var area: float = normal.length()
		if area > 0.0:
			normal /= area
		var d: float = -normal.dot(a)
		var plane: Array[float] = [normal.x * normal.x, normal.x * normal.y, normal.x * normal.z,
			normal.x * d, normal.y * normal.y, normal.y * normal.z, normal.y * d,
			normal.z * normal.z, normal.z * d, d * d]
		for k: int in 3:
			var v: int = triangles[t * 3 + k]
			faces_of[v].append(t)
			for m: int in 10:
				quadrics[v * 10 + m] += plane[m] * area
	var alive := PackedByteArray()
	alive.resize(count)
	alive.fill(1)
	var gone := PackedByteArray()
	gone.resize(n)
	var stamps := PackedInt32Array()
	stamps.resize(n)
	var heap := _Heap.new()
	var seen: Dictionary = {}
	for t: int in count:
		for k: int in 3:
			var a: int = triangles[t * 3 + k]
			var b: int = triangles[t * 3 + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not seen.has(key):
				seen[key] = true
				_queue(heap, quadrics, key.x, key.y, stamps)
	var live: int = count
	while live > target and heap.size() > 0:
		var entry: Array = heap.pop()
		var u: int = entry[1]
		var v: int = entry[2]
		if gone[u] == 1 or gone[v] == 1 or stamps[u] != int(entry[3]) \
				or stamps[v] != int(entry[4]):
			continue
		var to: Vector3 = entry[5]
		var shared := PackedInt32Array()
		var around_u: Dictionary = {}
		for t: int in faces_of[u]:
			if alive[t] == 0:
				continue
			var has_v: bool = false
			for k: int in 3:
				var w: int = triangles[t * 3 + k]
				if w == v:
					has_v = true
				elif w != u:
					around_u[w] = true
			if has_v:
				shared.append(t)
		# Only an edge between exactly two triangles, whose ends share no
		# neighbour but those two triangles' third corners: anything else
		# would pinch the surface into a part that is not one.
		if shared.size() != 2:
			continue
		var common: int = 0
		for t: int in faces_of[v]:
			if alive[t] == 0:
				continue
			for k: int in 3:
				var w: int = triangles[t * 3 + k]
				if w != u and w != v and around_u.has(w):
					around_u.erase(w)
					common += 1
		if common != 2:
			continue
		if _turns_over(faces_of[u], u, v, to, alive) or _turns_over(faces_of[v], v, u, to, alive):
			continue
		corners[u] = to
		for m: int in 10:
			quadrics[u * 10 + m] += quadrics[v * 10 + m]
		for t: int in shared:
			alive[t] = 0
			live -= 1
		var kept := PackedInt32Array()
		for t: int in faces_of[u]:
			if alive[t] == 1:
				kept.append(t)
		for t: int in faces_of[v]:
			if alive[t] == 0:
				continue
			for k: int in 3:
				if triangles[t * 3 + k] == v:
					triangles[t * 3 + k] = u
			kept.append(t)
		faces_of[u] = kept
		faces_of[v] = PackedInt32Array()
		gone[v] = 1
		stamps[u] += 1
		var near: Dictionary = {}
		for t: int in kept:
			for k: int in 3:
				var w: int = triangles[t * 3 + k]
				if w != u:
					near[w] = true
		for w: int in near:
			_queue(heap, quadrics, mini(u, w), maxi(u, w), stamps)
	# What is left, its corners numbered afresh.
	var renumber := PackedInt32Array()
	renumber.resize(n)
	renumber.fill(-1)
	var points := PackedVector3Array()
	var out := PackedInt32Array()
	for t: int in count:
		if alive[t] == 0:
			continue
		for k: int in 3:
			var v: int = triangles[t * 3 + k]
			if renumber[v] < 0:
				renumber[v] = points.size()
				points.append(corners[v])
			out.append(renumber[v])
	corners = points
	triangles = out


## Whether moving [param u] (joined to [param v]) to [param to] turns any
## of its triangles not on the edge over, or flattens it to nothing.
func _turns_over(faces: PackedInt32Array, u: int, v: int, to: Vector3,
		alive: PackedByteArray) -> bool:
	for t: int in faces:
		if alive[t] == 0:
			continue
		var a: int = triangles[t * 3]
		var b: int = triangles[t * 3 + 1]
		var c: int = triangles[t * 3 + 2]
		if a == v or b == v or c == v:
			continue
		var pa: Vector3 = corners[a]
		var pb: Vector3 = corners[b]
		var pc: Vector3 = corners[c]
		var before: Vector3 = (pb - pa).cross(pc - pa)
		if a == u:
			pa = to
		elif b == u:
			pb = to
		else:
			pc = to
		var after: Vector3 = (pb - pa).cross(pc - pa)
		if after.length_squared() <= before.length_squared() * 1e-6:
			return true
		if before.normalized().dot(after.normalized()) < 0.3:
			return true
	return false


## An edge's collapse queued at what it costs: the best of its two ends,
## its middle, and the point its quadric says is best, if that is near.
func _queue(heap: _Heap, quadrics: PackedFloat64Array, u: int, v: int,
		stamps: PackedInt32Array) -> void:
	var q := PackedFloat64Array()
	q.resize(10)
	for m: int in 10:
		q[m] = quadrics[u * 10 + m] + quadrics[v * 10 + m]
	var a: Vector3 = corners[u]
	var b: Vector3 = corners[v]
	var options: Array[Vector3] = [a, b, (a + b) * 0.5]
	var best: Variant = _solve(q)
	if best != null and (best as Vector3).distance_to((a + b) * 0.5) <= a.distance_to(b):
		options.append(best)
	var cost: float = INF
	var to: Vector3 = a
	for p: Vector3 in options:
		var e: float = _error(q, p)
		if e < cost:
			cost = e
			to = p
	heap.push(cost, [cost, u, v, stamps[u], stamps[v], to])


static func _error(q: PackedFloat64Array, p: Vector3) -> float:
	var x: float = p.x
	var y: float = p.y
	var z: float = p.z
	return q[0] * x * x + 2.0 * q[1] * x * y + 2.0 * q[2] * x * z + 2.0 * q[3] * x \
		+ q[4] * y * y + 2.0 * q[5] * y * z + 2.0 * q[6] * y + q[7] * z * z \
		+ 2.0 * q[8] * z + q[9]


## The point a quadric is least at, or null where it has no one least.
static func _solve(q: PackedFloat64Array) -> Variant:
	var m := Basis(Vector3(q[0], q[1], q[2]), Vector3(q[1], q[4], q[5]),
		Vector3(q[2], q[5], q[7]))
	var det: float = m.determinant()
	var scale_of: float = absf(q[0]) + absf(q[4]) + absf(q[7])
	if scale_of <= 0.0 or absf(det) < 1e-9 * scale_of * scale_of * scale_of:
		return null
	return m.inverse() * Vector3(-q[3], -q[6], -q[8])


## A binary heap of [cost, ...] by cost, cheapest first.
class _Heap extends RefCounted:
	var keys := PackedFloat64Array()
	var items: Array = []

	func size() -> int:
		return keys.size()

	func push(key: float, item: Array) -> void:
		keys.append(key)
		items.append(item)
		var at: int = keys.size() - 1
		while at > 0:
			var up: int = (at - 1) / 2
			if keys[up] <= keys[at]:
				break
			_swap(at, up)
			at = up

	func pop() -> Array:
		var top: Array = items[0]
		var last: int = keys.size() - 1
		_swap(0, last)
		keys.resize(last)
		items.resize(last)
		var at: int = 0
		while true:
			var low: int = at
			var left: int = at * 2 + 1
			if left < last and keys[left] < keys[low]:
				low = left
			if left + 1 < last and keys[left + 1] < keys[low]:
				low = left + 1
			if low == at:
				break
			_swap(at, low)
			at = low
		return top

	func _swap(a: int, b: int) -> void:
		var key: float = keys[a]
		keys[a] = keys[b]
		keys[b] = key
		var item: Array = items[a]
		items[a] = items[b]
		items[b] = item


## The furthest any corner of either surface is from the other, measured
## up to [param reach] (INF past it), in the surfaces' units.
static func _furthest(a_points: PackedVector3Array, a_triangles: PackedInt32Array,
		b_points: PackedVector3Array, b_triangles: PackedInt32Array, reach: float) -> float:
	return maxf(_furthest_from(a_points, b_points, b_triangles, reach),
		_furthest_from(b_points, a_points, a_triangles, reach))


static func _furthest_from(points: PackedVector3Array, surface: PackedVector3Array,
		tris: PackedInt32Array, reach: float) -> float:
	var cell: float = maxf(reach, 1e-6)
	var grid: Dictionary = {}
	for t: int in tris.size() / 3:
		var a: Vector3 = surface[tris[t * 3]]
		var b: Vector3 = surface[tris[t * 3 + 1]]
		var c: Vector3 = surface[tris[t * 3 + 2]]
		var lo: Vector3i = Vector3i((a.min(b).min(c) / cell).floor())
		var hi: Vector3i = Vector3i((a.max(b).max(c) / cell).floor())
		for x: int in range(lo.x, hi.x + 1):
			for y: int in range(lo.y, hi.y + 1):
				for z: int in range(lo.z, hi.z + 1):
					var key := Vector3i(x, y, z)
					if not grid.has(key):
						grid[key] = PackedInt32Array()
					grid[key].append(t)
	# Each point's nearest triangle is looked for only until one is nearer
	# than the furthest found so far: it cannot change the answer then.
	var furthest: float = 0.0
	var steps: Array[Vector3i] = []
	for dx: int in [0, -1, 1]:
		for dy: int in [0, -1, 1]:
			for dz: int in [0, -1, 1]:
				steps.append(Vector3i(dx, dy, dz))
	for p: Vector3 in points:
		var home := Vector3i((p / cell).floor())
		var nearest: float = INF
		for step: Vector3i in steps:
			var near: Variant = grid.get(home + step)
			if near == null:
				continue
			for t: int in near:
				var on: Vector3 = CustomParts._closest_on_triangle(p, surface[tris[t * 3]],
					surface[tris[t * 3 + 1]], surface[tris[t * 3 + 2]])
				nearest = minf(nearest, p.distance_to(on))
				if nearest <= furthest:
					break
			if nearest <= furthest:
				break
		if nearest > reach:
			return INF
		furthest = maxf(furthest, nearest)
	return furthest


# -- the fit -------------------------------------------------------------------------


## The size, upright and place a part from this file most likely wants: the
## file's own units read as millimetres, what a printer's file is in;
## centred, its top at the part's origin, as a brick's is. Where that makes
## it no part's size (under [constant LEAST_MM] or over [constant MOST_MM])
## the guess is asked about ([member unit_unsure]), never taken: up to
## moulds2 a file under 2 long was read as metres without a word, and a
## 1.5 mm part came out 1.5 m.
func guess_fit() -> void:
	var size: Vector3 = _source_box().size
	var longest: float = maxf(size.x, maxf(size.y, size.z))
	scale = LDU_PER_MM
	file_unit = "mm"
	unit_unsure = longest < LEAST_MM or longest > MOST_MM
	unit = "mm"
	hair = false
	refit()


## The file read as measured in [param in_unit] (a key of [constant
## FILE_UNITS]): what a person answers when asked ([member unit_unsure]).
func read_as(in_unit: String) -> void:
	if not FILE_UNITS.has(in_unit):
		return
	file_unit = in_unit
	unit_unsure = false
	if hair:
		return
	scale = LDU_PER_MM * float(FILE_UNITS[in_unit])
	unit = "mm"
	refit()


## What is asked when its file's units are a guess ([member unit_unsure]):
## its longest side as the file has it, read as millimetres, and the question.
func unit_question() -> String:
	var size: Vector3 = _source_box().size
	return ("%s does not say what it is measured in, and read as millimetres it is %s mm long, "
		+ "no part's size. What is it measured in?") % [file,
		_short(maxf(size.x, maxf(size.y, size.z)))]


## Why it cannot be made as it is, in words, or "": its file's units still
## a guess, or longer than [constant MOST_MM]. Said before any of the part
## is made ([method make]).
func size_problem() -> String:
	if unit_unsure:
		return "say what its file is measured in first"
	var mm: float = longest("mm")
	if mm > MOST_MM + 0.05:
		return "it is %s mm long, and a part may be at most %d mm (%d studs): make it smaller" % [
			_short(mm), int(MOST_MM), int(MOST_MM * LDU_PER_MM / STUD)]
	return ""


## The part's corners where they go: turned, sized and placed.
func fitted() -> PackedVector3Array:
	if _fitted.size() != corners.size():
		_fitted.resize(corners.size())
		for n: int in corners.size():
			_fitted[n] = turn * (corners[n] * _k()) + offset
		_columns.clear()
	return _fitted


## LDU per unit of the file, as fitted.
func _k() -> float:
	return scale * _snap


func _changed() -> void:
	_fitted = PackedVector3Array()
	_columns.clear()


## The box round the part as it is fitted, LDU in the app's axes.
func box() -> AABB:
	var points: PackedVector3Array = fitted()
	var out := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		out = out.expand(p)
	return out


func _source_box() -> AABB:
	var out := AABB(turn * corners[0], Vector3.ZERO)
	for p: Vector3 in corners:
		out = out.expand(turn * p)
	return out


## The longest side in [param in_unit].
func longest(in_unit: String = "") -> float:
	var size: Vector3 = box().size
	return maxf(size.x, maxf(size.y, size.z)) / float(UNITS.get(
		in_unit if not in_unit.is_empty() else unit, 1.0))


## Make the longest side [param value] in [param in_unit] and fit again.
func set_longest(value: float, in_unit: String) -> void:
	var size: Vector3 = _source_box().size
	var source: float = maxf(size.x, maxf(size.y, size.z))
	if value <= 0.0 or source <= 0.0:
		return
	scale = value * float(UNITS.get(in_unit, 1.0)) / source
	unit = in_unit
	# A size given answers what the file is measured in.
	unit_unsure = false
	refit()


## A quarter turn about [param axis] (the app's X, Y or Z), and fit again.
func quarter_turn(axis: Vector3) -> void:
	turn = (Basis(axis, PI / 2.0) * turn).orthonormalized()
	# Whole quarter turns: no rounding left to tilt it.
	for c: int in 3:
		turn[c] = turn[c].round()
	refit()


## Placed again for its size and turn: worn on the head, seated there;
## otherwise centred with its top at the origin, and its height a whole
## number of lattice steps, so its top and bottom both lie on the lattice a
## model is built on.
func refit() -> void:
	if hair:
		_snap = 1.0
		seat_on_head()
		return
	var source: AABB = _source_box()
	var tall: float = source.size.y * scale
	_snap = maxf(1.0, roundf(tall / LATTICE)) * LATTICE / tall if tall > LATTICE else 1.0
	var middle: Vector3 = source.get_center() * _k()
	offset = Vector3(-middle.x, -(source.end.y * _k()), -middle.z)
	_changed()


# -- hair -----------------------------------------------------------------------------


## Worn as hair: stood up, faced forward, sized like a hair piece if the
## file's size is not one already, and seated on the head (see the class's
## note). Says how much of the head is left inside it in [member
## head_inside].
func make_hair() -> void:
	hair = true
	# Sized as a hair piece, whatever its file is measured in.
	unit_unsure = false
	_snap = 1.0
	_stand_as_hair()
	unit = "mm"


## Hair the right way up and facing forward, as a file seldom has it: a
## 3D printer's hair is often upside down or on its back. Of the six ways
## up, each fitted to the head ([method _fit_head]), the one that holds the
## head best: round its sides and back ([method _round_the_head]), hanging
## down beside it ([method _hangs]), and not through it. The file's own way
## wins a near tie. Then turned about the upright so its open side, the
## face, is at the front (the figure faces +Z), or where more of it hangs
## to one side than the others, that side at the back. Turn and Tip put it
## right where this guesses wrong.
func _stand_as_hair() -> void:
	var start: Basis = turn
	var start_scale: float = scale
	var best: Array = []
	for way: Basis in [Basis.IDENTITY, Basis(Vector3.RIGHT, PI), Basis(Vector3.RIGHT, PI / 2.0),
			Basis(Vector3.RIGHT, -PI / 2.0), Basis(Vector3.BACK, PI / 2.0),
			Basis(Vector3.BACK, -PI / 2.0)]:
		turn = _square(way * start)
		scale = start_scale
		_fit_head()
		# The head through it counts most: a hair the head stands out of is
		# not worn, and one grown round the head covers it all (a mohawk's
		# crest stood on its side, 137 LDU tall).
		var score: float = float(_round_the_head()[0]) + _hangs() - 4.0 * head_inside
		if best.is_empty() or score > float(best[0]) + 0.05:
			best = [score, turn, scale, offset, head_inside]
	turn = best[1]
	scale = best[2]
	offset = best[3]
	head_inside = best[4]
	_changed()
	# Its hanging part to the back (a ponytail), or if it hangs evenly
	# round, its open side to the front (a wig's face).
	var front: float = 0.0
	var back: Vector3 = _hanging_way()
	if back != Vector3.ZERO:
		front = atan2(-back.x, -back.z)
	else:
		var round_it: Array = _round_the_head()
		if float(round_it[2]) >= 4.0:
			front = float(round_it[1])
	var quarters: int = posmod(roundi(-front / (PI / 2.0)), 4)
	if quarters != 0:
		turn = _square(Basis(Vector3.UP, PI / 2.0 * quarters) * turn)
		_fit_head()


## Sized across the face like a hair piece and seated on the head; while
## the head still comes through it, a size or two larger: a wig whose sides
## hang wide is shallow for its width, and at a hair piece's width the head
## stood out of its front and back.
func _fit_head() -> void:
	_size_as_hair()
	seat_on_head()
	if head_inside <= 0.02:
		return
	var start: float = scale
	var best: Array = [head_inside, scale]
	for step: float in [1.12, 1.25, 1.4]:
		scale = start * step
		seat_on_head()
		if head_inside < float(best[0]) - 0.005:
			best = [head_inside, scale]
		if head_inside <= 0.02:
			return
	scale = float(best[1])
	seat_on_head()


## Its widest across or front to back like a hair piece's, 34 LDU, unless
## it is one already. Narrower than the head ([method _fit_head] grows it):
## a ponytail lying on its back was 18 across and 41 front to back, all
## tail; sized across, a mohawk's crest on its side was 137 LDU tall.
func _size_as_hair() -> void:
	var size: Vector3 = _source_box().size
	var widest: float = maxf(size.x, size.z)
	if widest * scale < HAIR_NARROWEST or widest * scale > HAIR_WIDEST:
		scale = HAIR_WIDTH / widest
	_changed()


## How much of the head's sides and back it covers as seated, and which way
## it leaves most open: [share, angle about the upright, 0 the front (+Z),
## PI / 2 the side at +X, how much more the most covered quarter round
## holds than that one]. Looked at past the head, 24 ways round at three
## heights down its side, by whether the hair is there, close or a little
## further out (a loose fit's wall).
func _round_the_head() -> Array:
	var covered: PackedFloat32Array = PackedFloat32Array()
	covered.resize(24)
	var total: float = 0.0
	for n: int in 24:
		var angle: float = TAU * n / 24.0
		var out := Vector3(sin(angle), 0.0, cos(angle))
		for y: float in [-2.0, -5.0, -8.0]:
			if is_inside(out * (HEAD_RADIUS + 1.5) + Vector3.UP * y) \
					or is_inside(out * (HEAD_RADIUS + 4.5) + Vector3.UP * y):
				covered[n] += 1.0
				total += 1.0
	# The open side: the quarter round with least in it.
	var open: int = 0
	var least: float = INF
	var most: float = 0.0
	for n: int in 24:
		var there: float = 0.0
		for k: int in range(-3, 4):
			there += covered[posmod(n + k, 24)]
		most = maxf(most, there)
		if there < least:
			least = there
			open = n
	return [total / 72.0, TAU * open / 24.0, most - least]


## The share of its surface below the top of the head as seated: hair hangs
## round a head, so a tail hangs down rather than up or out.
func _hangs() -> float:
	var points: PackedVector3Array = fitted()
	var low: float = 0.0
	var total: float = 0.0
	for t: int in triangles.size() / 3:
		var a: Vector3 = points[triangles[t * 3]]
		var b: Vector3 = points[triangles[t * 3 + 1]]
		var c: Vector3 = points[triangles[t * 3 + 2]]
		var area: float = (b - a).cross(c - a).length()
		total += area
		if a.y + b.y + c.y < -6.0:
			low += area
	return low / total if total > 0.0 else 0.0


## Which way round its hanging part is from the head, flat; zero if it
## hangs evenly: a ponytail's tail, at the back.
func _hanging_way() -> Vector3:
	var points: PackedVector3Array = fitted()
	var sum := Vector3.ZERO
	var total: float = 0.0
	for t: int in triangles.size() / 3:
		var a: Vector3 = points[triangles[t * 3]]
		var b: Vector3 = points[triangles[t * 3 + 1]]
		var c: Vector3 = points[triangles[t * 3 + 2]]
		var middle: Vector3 = (a + b + c) / 3.0
		if middle.y < -2.0:
			var area: float = (b - a).cross(c - a).length()
			sum += Vector3(middle.x, 0.0, middle.z) * area
			total += area
	if total <= 0.0:
		return Vector3.ZERO
	var way: Vector3 = sum / total
	return way.normalized() if way.length() > HEAD_RADIUS * 0.25 else Vector3.ZERO


static func _square(basis: Basis) -> Basis:
	var out: Basis = basis.orthonormalized()
	for c: int in 3:
		out[c] = out[c].round()
	return out


## Seated on the head: of the points under its crown, the one deepest
## under it, then the one the head is clearest of the hair at, with the
## inside of the crown above it on the top of the head's stud. Deepest
## first: clearest first, a hair too small for the head sat on the bottom
## of its own side, over the head, rather than round it.
func seat_on_head() -> void:
	hair = true
	offset = Vector3.ZERO
	_changed()
	var fitted_box: AABB = box()
	var middle: Vector3 = fitted_box.get_center()
	var reach_x: float = fitted_box.size.x * 0.2
	var reach_z: float = fitted_box.size.z * 0.2
	var best: Array = []
	for i: int in range(-3, 4):
		for j: int in range(-3, 4):
			var x: float = middle.x + reach_x * i / 3.0
			var z: float = middle.z + reach_z * j / 3.0
			var inside_top: float = _lowest_from_below(x, z)
			if is_nan(inside_top):
				continue
			var at := Vector3(-x, STUD_TOP - inside_top, -z)
			var into: float = _head_inside_at(at)
			# Deepest under the crown, to a tenth of its height; then clearest
			# of the head; then nearest the middle.
			var score: Array = [-snappedf((inside_top - fitted_box.position.y)
					/ maxf(fitted_box.size.y, 0.001), 0.1), snappedf(into, 0.01), absf(i) + absf(j)]
			if best.is_empty() or _less(score, best[0]):
				best = [score, at, into]
	if best.is_empty():
		head_inside = 1.0
		offset = Vector3(-middle.x, STUD_TOP - fitted_box.position.y, -middle.z)
	else:
		offset = best[1]
		head_inside = float(best[2])
	_changed()


## A socket put by hand, at a point under the crown: that point goes on the
## top of the head's stud.
func seat_at(at: Vector3) -> void:
	hair = true
	offset += Vector3(-at.x, STUD_TOP - at.y, -at.z)
	_changed()
	head_inside = _head_inside_at(Vector3.ZERO)


static func _less(a: Array, b: Array) -> bool:
	for n: int in a.size():
		if float(a[n]) != float(b[n]):
			return float(a[n]) < float(b[n])
	return false


## The head's shape as points: its stud, its top and its sides, in its
## own frame. Those inside the hair are where the two would pass through
## each other.
static func head_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for y: float in [-20.0, -14.0, -8.0, -3.0, -0.6]:
		out.append(Vector3(0.0, y, 0.0))
		for radius: float in [HEAD_RADIUS * 0.5, HEAD_RADIUS]:
			for n: int in 12:
				var angle: float = TAU * n / 12.0
				out.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
	for y: float in [1.0, 3.2]:
		out.append(Vector3(0.0, y, 0.0))
		for n: int in 8:
			var angle: float = TAU * n / 8.0
			out.append(Vector3(cos(angle) * HEAD_STUD_RADIUS, y, sin(angle) * HEAD_STUD_RADIUS))
	return out


## The share of the head's points inside the hair moved by [param by].
## One line up through the hair for each place round the head, the points
## at its heights read off it: a line each, the six ways up a hair is tried
## in took 4.3 s for a wig.
func _head_inside_at(by: Vector3) -> float:
	var heights: Dictionary = {}
	for p: Vector3 in head_points():
		var place := Vector2(p.x, p.z)
		if not heights.has(place):
			heights[place] = []
		heights[place].append(p.y)
	var inside: int = 0
	var count: int = 0
	for place: Vector2 in heights:
		var hits: Array = _column(place.x - by.x, place.y - by.z)
		for y: float in heights[place]:
			count += 1
			var above: int = 0
			for hit: Array in hits:
				if float(hit[0]) > y - by.y:
					above += 1
			inside += above % 2
	return float(inside) / float(count)


## Where the surface is first met going up from under the part at x, z:
## the inside of the crown for a hair piece. NAN if nothing is above.
func _lowest_from_below(x: float, z: float) -> float:
	var hits: Array = _column(x, z)
	for hit: Array in hits:
		if float(hit[1]) < 0.0:
			return float(hit[0])
	return NAN


## Whether a point is inside the part as it is fitted: an odd number of its
## surface above it.
func is_inside(p: Vector3) -> bool:
	var above: int = 0
	for hit: Array in _column(p.x, p.z):
		if float(hit[0]) > p.y:
			above += 1
	return above % 2 == 1


## Every place a vertical line at x, z meets the fitted surface, lowest
## first: [y, which way the surface faces up (+1) or down (-1)].
func _column(x: float, z: float) -> Array:
	var points: PackedVector3Array = fitted()
	if _columns.is_empty():
		var whole: AABB = box()
		_column_cell = maxf(maxf(whole.size.x, whole.size.z) / 48.0, 0.25)
		for t: int in triangles.size() / 3:
			var a: Vector3 = points[triangles[t * 3]]
			var b: Vector3 = points[triangles[t * 3 + 1]]
			var c: Vector3 = points[triangles[t * 3 + 2]]
			var lo := Vector2i(int(floor(minf(a.x, minf(b.x, c.x)) / _column_cell)),
				int(floor(minf(a.z, minf(b.z, c.z)) / _column_cell)))
			var hi := Vector2i(int(floor(maxf(a.x, maxf(b.x, c.x)) / _column_cell)),
				int(floor(maxf(a.z, maxf(b.z, c.z)) / _column_cell)))
			for i: int in range(lo.x, hi.x + 1):
				for j: int in range(lo.y, hi.y + 1):
					var key := Vector2i(i, j)
					if not _columns.has(key):
						_columns[key] = PackedInt32Array()
					_columns[key].append(t)
	# Nudged off any edge or corner a line could run exactly along.
	x += 0.000137
	z += 0.000291
	var out: Array = []
	var near: Variant = _columns.get(Vector2i(int(floor(x / _column_cell)),
		int(floor(z / _column_cell))))
	if near == null:
		return out
	for t: int in near:
		var a: Vector3 = points[triangles[t * 3]]
		var b: Vector3 = points[triangles[t * 3 + 1]]
		var c: Vector3 = points[triangles[t * 3 + 2]]
		var d: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-12:
			continue
		var u: float = ((x - a.x) * (c.z - a.z) - (c.x - a.x) * (z - a.z)) / d
		var v: float = ((b.x - a.x) * (z - a.z) - (x - a.x) * (b.z - a.z)) / d
		if u < 0.0 or v < 0.0 or u + v > 1.0:
			continue
		var y: float = a.y + u * (b.y - a.y) + v * (c.y - a.y)
		var up: float = (b - a).cross(c - a).y
		out.append([y, 1.0 if up > 0.0 else -1.0])
	out.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	return out


# -- connectors ------------------------------------------------------------------------


## Where a ray from [param from] toward [param toward] first meets the part
## as fitted: {"at", "normal"} (outward), or empty.
func pick(from: Vector3, toward: Vector3) -> Dictionary:
	var points: PackedVector3Array = fitted()
	var faces := PackedVector3Array()
	faces.resize(triangles.size())
	for n: int in triangles.size():
		faces[n] = points[triangles[n]]
	var hit: Dictionary = Rays.nearest(faces, from, toward)
	if hit.is_empty():
		return {}
	var t: int = hit["face"]
	var a: Vector3 = faces[t * 3]
	var normal: Vector3 = (faces[t * 3 + 1] - a).cross(faces[t * 3 + 2] - a).normalized()
	return {"at": hit["position"], "normal": normal}


## Put a connector of [param kind] (a key of [constant CONNECTORS]) where a
## pick found the surface. A hair socket seats the part on the head there
## instead. Returns why not, or "".
func put(kind: String, hit: Dictionary) -> String:
	if not CONNECTORS.has(kind) or hit.is_empty():
		return "Point at the part to put a %s on it." % kind
	var at: Vector3 = hit["at"]
	var normal: Vector3 = hit["normal"]
	if kind == "hair socket":
		if normal.y > -0.2:
			return "A hair socket goes under the crown: point at the inside of the hair, from below."
		seat_at(at)
		return ""
	# Kept in the file's frame, so it moves with the surface when resized.
	var inverse: Basis = turn.inverse()
	connectors.append({"kind": kind, "at": inverse * (at - offset) / _k(),
		"normal": (inverse * normal).normalized()})
	return ""


## Take off the connector nearest [param at] within [param reach] LDU.
func take_off(at: Vector3, reach: float = 6.0) -> bool:
	var best: int = -1
	var nearest: float = reach
	for n: int in connectors.size():
		var there: Vector3 = _placed_at(connectors[n])
		if there.distance_to(at) < nearest:
			nearest = there.distance_to(at)
			best = n
	if best < 0:
		return false
	connectors.remove_at(best)
	return true


func _placed_at(c: Dictionary) -> Vector3:
	return turn * ((c["at"] as Vector3) * _k()) + offset


## The way out of the surface at a connector, square to the part's sides
## when it is within 10 degrees of square.
func _placed_normal(c: Dictionary) -> Vector3:
	var normal: Vector3 = (turn * (c["normal"] as Vector3)).normalized()
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.LEFT, Vector3.DOWN,
			Vector3.FORWARD]:
		if normal.dot(axis) > cos(deg_to_rad(10.0)):
			return axis
	return normal


## Every connector as the part file states it: [kind, gender, x, y, z, ax,
## ay, az, length, radius] in LDraw's axes, and what is drawn for it:
## {"connectors", "studs" (positions and ways out, LDraw), "bars" (start,
## way, length)}.
func placed() -> Dictionary:
	var out_connectors: Array = []
	var studs: Array = []
	var bars: Array = []
	if hair:
		out_connectors.append(HAIR_SOCKET.duplicate())
	for c: Dictionary in connectors:
		var kind: String = c["kind"]
		var spec: Array = CONNECTORS[kind]
		var at: Vector3 = _placed_at(c)
		var way: Vector3 = _placed_normal(c)
		# On a square face, on the lattice across it: a brick on a stud put
		# on the part's top lines up with the model's grid.
		if absf(absf(way.x) + absf(way.y) + absf(way.z) - 1.0) < 1e-4:
			for axis: int in 3:
				if absf(way[axis]) < 0.5:
					at[axis] = snappedf(at[axis], LATTICE)
		match kind:
			"stud":
				studs.append([_ldraw(at), _ldraw_way(way)])
				out_connectors.append(["stud", "male"] + _numbers(at, way) + [0.0, 0.0])
			"anti-stud", "pin hole":
				out_connectors.append([spec[0], spec[1]] + _numbers(at, way) + [0.0, 0.0])
			"bar hole":
				var deep: float = minf(_thickness(at, way), float(spec[2]) * 2.0)
				deep = maxf(deep, 4.0)
				out_connectors.append([spec[0], spec[1]] + _numbers(at - way * deep, way)
					+ [deep, spec[3]])
			"bar":
				var thick: float = _thickness(at, way)
				if thick <= THIN_FOR_BAR:
					# The stem is the bar: along it, through its middle.
					var middle: Vector3 = at - way * thick * 0.5
					var along: Array = _along_stem(middle, way)
					out_connectors.append([spec[0], spec[1]] + _numbers(along[0], along[1])
						+ [along[2], spec[3]])
				else:
					# Drawn, as a cylinder: the cylinder says where it is.
					bars.append([_ldraw(at), _ldraw_way(way), float(spec[2])])
	return {"connectors": out_connectors, "studs": studs, "bars": bars}


func _numbers(at: Vector3, way: Vector3) -> Array:
	var p: Vector3 = _ldraw(at)
	var w: Vector3 = _ldraw_way(way)
	return [p.x, p.y, p.z, w.x, w.y, w.z]


static func _ldraw(p: Vector3) -> Vector3:
	return Vector3(snappedf(p.x, 0.01), snappedf(-p.y, 0.01), snappedf(-p.z, 0.01))


static func _ldraw_way(w: Vector3) -> Vector3:
	return Vector3(snappedf(w.x, 0.0001), snappedf(-w.y, 0.0001), snappedf(-w.z, 0.0001))


## How far through the part it is from [param at], going in against
## [param way]: where the surface is next met.
func _thickness(at: Vector3, way: Vector3) -> float:
	var inside: Dictionary = pick(at - way * 0.05, -way)
	if inside.is_empty():
		return 0.0
	return (inside["at"] as Vector3).distance_to(at)


## A stem's line through [param middle], square to [param across]: of the
## part's own sides' directions, the one it runs furthest along. [start,
## way, length].
func _along_stem(middle: Vector3, across: Vector3) -> Array:
	var best: Array = [middle, Vector3.UP, 0.0]
	for axis: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3.BACK]:
		var way: Vector3 = (axis - across * axis.dot(across))
		if way.length() < 0.5:
			continue
		way = way.normalized()
		var forward: Dictionary = pick(middle, way)
		var back: Dictionary = pick(middle, -way)
		if forward.is_empty() or back.is_empty():
			continue
		var ahead: float = minf((forward["at"] as Vector3).distance_to(middle), LONGEST_BAR / 2.0)
		var behind: float = minf((back["at"] as Vector3).distance_to(middle), LONGEST_BAR / 2.0)
		if ahead + behind > float(best[2]):
			best = [middle - way * behind, way, ahead + behind]
	if float(best[2]) <= 0.0:
		best = [middle - Vector3.UP * 6.0, Vector3.UP, 12.0]
	return best


# -- the part file ------------------------------------------------------------------------


## Its id: what it is called and a tag from its shape and connectors, so the
## same part made twice is one part and any change is another.
func id_for(title: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	hashing.update(text("", title).to_utf8_buffer())
	var source: String = ""
	for ch: String in title.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			source += ch
	if source.is_empty():
		source = "shape"
	# Joined, not formatted: "%s-s" reads as a key named in words
	# (tests/test_keys_named.py).
	return "bw-" + source.left(10) + "-s" + hashing.finish().hex_encode().left(6)


## The part file: its triangles, its connectors, what it was made from.
## Nothing a person typed or a file was called is written raw: the title is
## [method name_from]'s words after a lead of ours, so it can never be the
## line's first word (a title "FILE x" wrote "0 FILE x, Custom Shape", a
## section of its own to every reader), and the file's name one [method
## _token].
func text(id: String, title: String) -> String:
	var words: String = name_from(title)
	if words.is_empty():
		words = name_from(name)
	if words.is_empty():
		words = "My shape"
	var made: Dictionary = placed()
	var size: Vector3 = box().size
	var points: PackedVector3Array = fitted()
	var faces := _faces(points)
	var out := PackedStringArray()
	out.append(("0 Minifig Hair, Custom Shape %s" if hair else "0 Custom Shape %s") % words)
	out.append("0 Name: %s.dat" % id)
	out.append("0 Author: " + AUTHOR)
	out.append("0 !LDRAW_ORG Unofficial_Part")
	out.append("")
	out.append("0 BFC CERTIFY CCW")
	out.append("")
	if hair:
		out.append("0 !CATEGORY Minifig Headwear")
	out.append("0 !KEYWORDS Brickworks, own shape, %s" % _token(file.get_extension().to_lower()))
	out.append("")
	out.append("%s%s file=%s triangles=%d size=%sx%sx%s" % [IMPORTED_BY,
		(" from=%s" % HAIR_BASE) if hair else "", _token(file), faces.size(),
		PartEditor._n(snappedf(size.x, 0.01)), PartEditor._n(snappedf(size.y, 0.01)),
		PartEditor._n(snappedf(size.z, 0.01))])
	out.append("0 // Made in Brickworks from %s, a 3D file of its maker's own." % _token(file))
	out.append("")
	out.append("0 // Connectors, for programs that read them")
	for c: Array in made["connectors"]:
		# A stud is drawn with stud.dat below, which says where it is, and
		# a hair's socket with 3901's tube.
		if c[0] == "stud" or (hair and c == HAIR_SOCKET):
			continue
		var line: String = "0 %s CONNECTOR %s %s %s %s %s %s %s %s" % [PartEditor.CONNECTOR,
			c[0], c[1], PartEditor._n(c[2]), PartEditor._n(c[3]), PartEditor._n(c[4]),
			PartEditor._n(c[5]), PartEditor._n(c[6]), PartEditor._n(c[7])]
		if float(c[8]) > 0.0:
			line += " %s %s" % [PartEditor._n(c[8]), PartEditor._n(c[9])]
		out.append(line)
	out.append("")
	out.append("0 // Faces")
	out.append_array(faces)
	if hair:
		out.append("0 // The socket a minifigure's hair has: 3901's tube round the head's stud,")
		out.append("0 // and plastic from it up into the crown")
		out.append("1 16 0 -4 0 1 0 0 0 -1 0 0 0 -1 stud4.dat")
		out.append_array(_socket_faces())
	var creases: PackedVector3Array = _creases(points)
	if not creases.is_empty():
		out.append("0 // Edges")
		for n: int in creases.size() / 2:
			var a: Vector3 = _ldraw(creases[n * 2])
			var b: Vector3 = _ldraw(creases[n * 2 + 1])
			out.append("2 24 %s %s %s %s %s %s" % [PartEditor._n(a.x), PartEditor._n(a.y),
				PartEditor._n(a.z), PartEditor._n(b.x), PartEditor._n(b.y), PartEditor._n(b.z)])
	if not (made["studs"] as Array).is_empty() or not (made["bars"] as Array).is_empty():
		out.append("0 // Studs and bars put on")
	for stud: Array in made["studs"]:
		out.append("1 16 %s %s stud.dat" % [_xyz(stud[0]), _turned_to(stud[1])])
	for bar: Array in made["bars"]:
		# A cylinder 4 across from the surface out, and a disc to close it.
		var way: Vector3 = bar[1]
		var long: float = float(bar[2])
		var start: Vector3 = bar[0]
		out.append("1 16 %s %s 4-4cyli.dat" % [_xyz(start), _turned_to(-way, 4.0, long)])
		out.append("1 16 %s %s 4-4disc.dat" % [_xyz(start + way * long),
			_turned_to(way, 4.0, 1.0)])
	out.append("0")
	return "\n".join(out) + "\n"


## The plastic over a hair's socket, as "3" lines: a round of
## [constant SOCKET_RADIUS] from the tube's top, where the stud's top is, up
## into the crown, closed top and bottom (its bottom the socket's ceiling).
func _socket_faces() -> PackedStringArray:
	var top: float = socket_top()
	var ring := PackedVector3Array()
	for n: int in SOCKET_SIDES:
		var angle: float = TAU * n / SOCKET_SIDES
		ring.append(Vector3(cos(angle), 0.0, sin(angle)) * SOCKET_RADIUS)
	var low := Vector3(0, STUD_TOP, 0)
	var high := Vector3(0, top, 0)
	var out := PackedStringArray()
	# Wound as LDraw winds them, in the app's axes: outward by the right hand.
	for n: int in SOCKET_SIDES:
		var a: Vector3 = ring[n]
		var b: Vector3 = ring[(n + 1) % SOCKET_SIDES]
		for three: Array in [[low + a, high + b, low + b], [low + a, high + a, high + b],
				[high, high + b, high + a], [low, low + a, low + b]]:
			out.append("3 16 %s %s %s" % [_xyz(_ldraw(three[0])), _xyz(_ldraw(three[1])),
				_xyz(_ldraw(three[2]))])
	return out


## How high the plastic over a hair's socket goes, app axes: a little past
## the crown's inside over it, so it joins the crown, and under the crown's
## outside where it can be, so it never shows; at least to where a stud's
## tip is looked for.
func socket_top() -> float:
	var inside: float = Joints.STUD_REACH + 1.0
	var outside: float = INF
	for n: int in SOCKET_SIDES + 1:
		var at := Vector3.ZERO
		if n > 0:
			var angle: float = TAU * n / SOCKET_SIDES
			at = Vector3(cos(angle), 0.0, sin(angle)) * (SOCKET_RADIUS - 0.5)
		var under: Dictionary = pick(Vector3(at.x, 0.25, at.z), Vector3.UP)
		if under.is_empty():
			continue
		var crown: float = (under["at"] as Vector3).y
		inside = maxf(inside, crown + 1.0)
		var over: Dictionary = pick(under["at"] + Vector3.UP * 0.01, Vector3.UP)
		if not over.is_empty():
			outside = minf(outside, (over["at"] as Vector3).y)
	if inside > outside - 0.5:
		inside = maxf(Joints.STUD_REACH + 1.0, outside - 0.5)
	return snappedf(inside, 0.01)


## Each triangle as its "3" line, in the hundredths of an LDU the file
## keeps. A sliver whose corners fall on one line at that grain is left
## out: it has no surface, and LDraw's readers count a flat triangle as a
## fault (own_parts_check found 3 in the mohawk's 2,500, 1 in the wig's).
func _faces(points: PackedVector3Array) -> PackedStringArray:
	var out := PackedStringArray()
	for t: int in triangles.size() / 3:
		var a: Vector3 = _ldraw(points[triangles[t * 3]])
		var b: Vector3 = _ldraw(points[triangles[t * 3 + 1]])
		var c: Vector3 = _ldraw(points[triangles[t * 3 + 2]])
		if (Vector3(b - a)).cross(c - a).length() < 0.00005:
			continue
		out.append("3 16 %s %s %s" % [_xyz(a), _xyz(b), _xyz(c)])
	return out


static func _xyz(p: Vector3) -> String:
	return "%s %s %s" % [PartEditor._n(p.x), PartEditor._n(p.y), PartEditor._n(p.z)]


## The nine numbers of an LDraw line turning a primitive's -Y (a stud's up,
## a cylinder's length runs +Y) to [param up], its X and Z [param across]
## wide and its Y [param along] long.
static func _turned_to(up: Vector3, across: float = 1.0, along: float = 1.0) -> String:
	var y: Vector3 = -up.normalized()
	var x: Vector3 = (Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	var cols: Array[Vector3] = [x * across, y * along, z * across]
	var out := PackedStringArray()
	for row: int in 3:
		for col: int in 3:
			out.append(PartEditor._n(snappedf(cols[col][row], 0.000001)))
	return " ".join(out)


## The creases: edges where two faces meet at more than 40 degrees, drawn
## as LDraw's edge lines, as every part's are.
func _creases(points: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(triangles.size() / 3)
	for t: int in triangles.size() / 3:
		var a: Vector3 = points[triangles[t * 3]]
		normals[t] = (points[triangles[t * 3 + 1]] - a).cross(points[triangles[t * 3 + 2]] - a) \
			.normalized()
	var first: Dictionary = {}
	var out := PackedVector3Array()
	var sharp: float = cos(deg_to_rad(40.0))
	for t: int in triangles.size() / 3:
		for k: int in 3:
			var a: int = triangles[t * 3 + k]
			var b: int = triangles[t * 3 + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not first.has(key):
				first[key] = t
				continue
			if normals[t].dot(normals[int(first[key])]) < sharp:
				out.append(points[a])
				out.append(points[b])
	return out


## Made, added to the library and kept: {"id", "problem"}. Refused before
## any of it is made where its size is no part's ([method size_problem]).
func make(library: PartLibrary, title: String, keep: bool = true) -> Dictionary:
	if not size_problem().is_empty():
		return {"id": "", "problem": size_problem()}
	var words: String = name_from(title)
	if words.is_empty():
		words = name_from(name)
	if words.length() > MOST_NAME:
		return {"id": "", "problem": _long_name(words)}
	var id: String = id_for(words)
	var made: Dictionary = CustomParts.add(library, text(id, words), id, keep)
	return made


## [method make] with its file written and built on a worker, so the window
## draws meanwhile: 9,000 triangles' text, cover and meshes are most of a
## second. Here and now where there are no threads. A coroutine.
func make_built(library: PartLibrary, title: String, keep: bool = true) -> Dictionary:
	if not size_problem().is_empty():
		return {"id": "", "problem": size_problem()}
	var words: String = name_from(title)
	if words.is_empty():
		words = name_from(name)
	if words.length() > MOST_NAME:
		return {"id": "", "problem": _long_name(words)}
	var forge: GDScript = Later.script(&"PartForge")
	WorkerTasks.first_here("the forge", Callable(forge, &"warm"))
	var made: Array = await WorkerTasks.awaited(func() -> Variant:
		var id: String = id_for(words)
		var source: String = text(id, words)
		return [id, source, forge.build(source, id, {}, true, null, false)],
		"build a part from a 3D file", library)
	return CustomParts.add(library, made[1], made[0], keep, {}, forge.with_mesh(made[2]))


## The most letters a part's name may have.
const MOST_NAME := 80


## [param title] as a part's name: every kind of space one space, no
## character that shows nothing (a zero-width space, a joiner) and no
## control character, its ends trimmed.
static func name_from(title: String) -> String:
	var out: String = ""
	for n: int in title.length():
		var code: int = title.unicode_at(n)
		if code < 32 or (code >= 127 and code < 160) \
				or SubmodelFile._in_runs(code, SubmodelFile.UNSEEN):
			continue
		out += " " if code in SubmodelFile.SPACES else title[n]
	return " ".join(out.split(" ", false))


## [param words] as one word of a line that programs read as key=value
## ("file=wig_67.stl"): [method name_from]'s, with no space and no "=".
static func _token(words: String) -> String:
	var out: String = name_from(words).replace(" ", "_").replace("=", "_")
	return out if not out.is_empty() else "file"


static func _long_name(words: String) -> String:
	return "its name has %d letters, and a part's may have at most %d" % [words.length(), MOST_NAME]


# -- words ---------------------------------------------------------------------------------


## The file's name as a part's: "w-fit-trainer-hair" is "W Fit Trainer Hair".
static func _title_from(stem: String) -> String:
	var words := PackedStringArray()
	for word: String in stem.replace("_", " ").replace("-", " ").replace(".", " ").split(" ", false):
		words.append(word[0].to_upper() + word.substr(1))
	var out: String = " ".join(words).strip_edges()
	return out.left(40) if not out.is_empty() else "My shape"


static func _count(n: int) -> String:
	var digits: String = str(n)
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out


## Its size as a person reads it: "34 x 24 x 30 LDU (13.6 x 9.6 x 12 mm)", wide
## by tall by deep.
func size_words() -> String:
	var size: Vector3 = box().size
	return "%s x %s x %s LDU (%s x %s x %s mm, %s x %s x %s studs)" % [
		_short(size.x), _short(size.y), _short(size.z),
		_short(size.x / LDU_PER_MM), _short(size.y / LDU_PER_MM), _short(size.z / LDU_PER_MM),
		_short(size.x / STUD), _short(size.y / STUD), _short(size.z / STUD)]


static func _short(v: float) -> String:
	var text: String = String.num(snappedf(v, 0.1), 1)
	return text.trim_suffix(".0")
