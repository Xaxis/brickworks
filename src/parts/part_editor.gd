## Changing a part that exists: longer, wider, taller, its studs taken off
## or put on — from the part's own geometry, so everything about it that the
## change does not touch stays exactly as LEGO made it.
##
## A LEGO element designer is far more often asked for a change to an
## element than for a new one: the 1 x 2 Technic brick, six long; the brick
## with studs on its side, with more of them; the round brick, without its
## stud. [ElementMaker] redraws the plain families from nothing, and a part
## it does not know it cannot touch. This works on any part, from the
## geometry every build of the app already has — the part's built mesh,
## shipped with a desktop build and fetched by the browser — rather than its
## LDraw source, which neither has.
##
## The mesh is the part's triangles and the connectors the mesh build found
## on it. The edit is made on those, and they are written back out as an
## unofficial LDraw part: the triangles as polygons, the creases the mesh's
## normals keep as edge lines, and each connector as a
## `0 !BRICKWORKS CONNECTOR` meta line — LDraw's way of carrying what a
## program needs and other programs may ignore — which [PartForge] and
## tools/ldraw/connectivity.py both read. So the made part clutches, holds a
## pin and collides exactly where the original did, wherever the edit left
## it alone.
##
## How a part is made longer is the one idea here. A 20 LDU slice of it —
## one stud's worth — is repeated, or taken out, and the slice is chosen
## where cutting it leaves the same face at both ends: through the middle of
## a 2 x 4, where its walls, top and tubes run on unchanged, and never
## through its end walls. A Technic brick's slice holds a hole, a stud and
## the pin under the hole, so a longer one has more holes; a brick with studs
## on its side gets more side studs. Taller is the same with an 8 LDU slice
## and the plate's worth of wall and tube it holds. A part with no such slice
## — a 1 x 1, a round brick — is not stretched: that is said, not faked.
##
## A cut-out is a box, in studs and plates, taken out of the part: its
## triangles cut exactly at the box's faces, and the plastic the box cut
## through closed again — a cap on each cut face where there was plastic, and
## a 4 LDU wall wherever the cut opened into the part's hollow underside, so
## the part is a part a mould could make and not a broken shell. Which cells
## are plastic and which hollow is read off the part's own triangles, two LDU
## at a time, as the collision cover is: square cuts through square walls
## are exact, and a cut through a round tube is closed in steps of 2 LDU.
##
## Everything is in LDraw's axes: X right, Y down, the top of the part at
## Y = 0 for most parts.
class_name PartEditor
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## The meta line a connector is carried in, and the line that says what
## was changed, from what.
const CONNECTOR := "!BRICKWORKS"
const MODIFIED_BY := "0 // Modified by Brickworks:"
const AUTHOR := "Brickworks element maker"
## The most a part may be stretched to, as the maker allows.
const MOST_STUDS := 32
const MOST_PLATES := 36
## The cross-sections at the two ends of a slice are compared on a grid of
## this many LDU, and may differ in this share of their cells (rounding
## where a line is cut).
const SECTION_CELL := 0.5
const SECTION_SLACK := 0.01
## Edges whose two sides' normals differ by more than this are creases.
const CREASE_DOT := 0.995


## What to change. Sizes are what the part is to be, in studs and plates;
## 0 keeps the part's own.
class Edit extends RefCounted:
	var from: String = ""
	var length: int = 0
	var width: int = 0
	var plates: int = 0
	## "keep", "none" (take the studs off its top) or "fill" (a stud on
	## every flat stud square of its top that has none).
	var studs: String = "keep"
	var title: String = ""
	## A box to cut out, or empty: [x0, z0, x1, z1, p0, p1], studs from the
	## part's low corner in the app's x and z (z is towards the front, as in
	## a design's placements) and plates up from its bottom.
	var cut := PackedInt32Array()

	func duplicate() -> Edit:
		var copy := Edit.new()
		copy.from = from
		copy.length = length
		copy.width = width
		copy.plates = plates
		copy.studs = studs
		copy.title = title
		copy.cut = cut.duplicate()
		return copy

	func to_words() -> String:
		var words: String = "from=%s length=%d width=%d plates=%d studs=%s" % [from, length,
			width, plates, studs]
		if cut.size() == 6:
			words += " cut=%d,%d,%d,%d,%d,%d" % [cut[0], cut[1], cut[2], cut[3], cut[4], cut[5]]
		return words


## A part's geometry as the edit works on it: triangles (9 floats each) with
## a colour and a two-sided flag apiece, crease segments (6 floats each), the
## connectors, and what the edit adds — studs and caps drawn with primitives.
class Shape extends RefCounted:
	var tris := PackedFloat64Array()
	var colors := PackedInt32Array()
	var two_sided := PackedByteArray()
	var lines := PackedFloat64Array()
	## [kind, gender, x, y, z, ax, ay, az, length, radius], LDraw's axes.
	var connectors: Array = []
	## [x, y, z] of a stud.dat stood on the top.
	var studs_added: Array = []
	## [x, y, z, radius] of a 4-4disc closing the hole a stud left.
	var caps: Array = []

	func count() -> int:
		return colors.size()

	func copy() -> Shape:
		var out := Shape.new()
		out.tris = tris.duplicate()
		out.colors = colors.duplicate()
		out.two_sided = two_sided.duplicate()
		out.lines = lines.duplicate()
		out.connectors = connectors.duplicate(true)
		out.studs_added = studs_added.duplicate(true)
		out.caps = caps.duplicate(true)
		return out


# -- reading a part's mesh ------------------------------------------------------


## The part's built mesh as a [Shape], in LDraw's axes: the app's +Y up and
## the mesh's a, c, b winding undone.
static func shape_of(mesh: Lbm.PartMesh) -> Shape:
	var shape := Shape.new()
	## Welded position -> per corner [triangle, normal], for the creases.
	var corners: Dictionary = {}
	var normals: Array[Vector3] = []
	for n: int in mesh.surfaces.size():
		var arrays: Array = mesh.surfaces[n].surface_get_arrays(0)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var vertex_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var color: int = mesh.surface_colors[n] if n < mesh.surface_colors.size() else 16
		var sided: int = mesh.surface_two_sided[n] if n < mesh.surface_two_sided.size() else 0
		for t: int in indices.size() / 3:
			# Written a, c, b for the engine: LDraw's order is a, b, c.
			for corner: int in [indices[t * 3], indices[t * 3 + 2], indices[t * 3 + 1]]:
				var p: Vector3 = positions[corner]
				shape.tris.append_array(PackedFloat64Array([p.x, -p.y, -p.z]))
				var normal: Vector3 = vertex_normals[corner] if corner < vertex_normals.size() \
					else Vector3.ZERO
				normals.append(Vector3(normal.x, -normal.y, -normal.z))
			shape.colors.append(color)
			shape.two_sided.append(sided)
	shape.lines = _creases(shape, normals)
	for c: Lbm.Connector in mesh.connectors:
		shape.connectors.append([c.kind, c.gender, c.position.x, -c.position.y,
			-c.position.z, c.axis.x, -c.axis.y, -c.axis.z, c.length, c.radius])
	return shape


## The edges the mesh keeps sharp — where the two triangles that share an
## edge have different normals at its ends, which is what the mesh build's
## crease lines and angles made — and the edges only one triangle has.
## Written back as LDraw edge lines, they keep the part shading as it did
## and give other LDraw programs their outlines.
static func _creases(shape: Shape, normals: Array[Vector3]) -> PackedFloat64Array:
	## Low end -> {high end -> [[corner at the low end, at the high], ...]}
	var edges: Dictionary = {}
	for t: int in shape.count():
		for n: int in 3:
			var a: int = t * 3 + n
			var b: int = t * 3 + (n + 1) % 3
			var ka: Vector3i = _weld(shape.tris, a)
			var kb: Vector3i = _weld(shape.tris, b)
			if ka == kb:
				continue
			var lo: Vector3i = ka if ka < kb else kb
			var hi: Vector3i = kb if ka < kb else ka
			var ends: Dictionary = edges.get(lo, {})
			if ends.is_empty():
				edges[lo] = ends
			var row: Array = ends.get(hi, [])
			if row.is_empty():
				ends[hi] = row
			row.append([a, b] if ka < kb else [b, a])
	var rows: Array = []
	for lo: Vector3i in edges:
		var ends: Dictionary = edges[lo]
		for hi: Vector3i in ends:
			rows.append(ends[hi])
	var out := PackedFloat64Array()
	for row: Array in rows:
		var sharp: bool = row.size() == 1
		for n: int in range(1, row.size()):
			var first: Array = row[0]
			var other: Array = row[n]
			if normals[int(first[0])].dot(normals[int(other[0])]) < CREASE_DOT \
					or normals[int(first[1])].dot(normals[int(other[1])]) < CREASE_DOT:
				sharp = true
		if sharp:
			var ends: Array = row[0]
			for corner: int in ends:
				out.append_array(shape.tris.slice(corner * 3, corner * 3 + 3))
	return out


static func _weld(values: PackedFloat64Array, corner: int) -> Vector3i:
	return Vector3i(roundi(values[corner * 3] * 1000.0), roundi(values[corner * 3 + 1] * 1000.0),
		roundi(values[corner * 3 + 2] * 1000.0))


## Where a part's plastic is, from its collision cover, in LDraw's axes:
## [x low, x high, y top, y bottom, z low, z high]. The cover leaves studs
## out, on the top and the sides, as a cut-out's measure has to.
static func extent_of(mesh: Lbm.PartMesh) -> PackedFloat64Array:
	var box := AABB()
	for cells: AABB in mesh.boxes:
		var ldu := AABB(cells.position * mesh.cell_ldu, cells.size * mesh.cell_ldu)
		box = ldu if box.size == Vector3.ZERO else box.merge(ldu)
	if box.size == Vector3.ZERO:
		box = mesh.bounds
	# The app's y and z are LDraw's turned over.
	return PackedFloat64Array([box.position.x, box.end.x, -box.end.y, -box.position.y,
		-box.end.z, -box.position.z])


## A part's size in studs along X and Z and in plates, from its collision
## cover — the plastic, not the studs standing off it.
static func size_of(mesh: Lbm.PartMesh) -> Vector3i:
	var box := AABB()
	for cells: AABB in mesh.boxes:
		var ldu := AABB(cells.position * mesh.cell_ldu, cells.size * mesh.cell_ldu)
		box = ldu if box.size == Vector3.ZERO else box.merge(ldu)
	if box.size == Vector3.ZERO:
		box = mesh.bounds
	return Vector3i(maxi(1, roundi(box.size.x / STUD)), maxi(1, roundi(box.size.y / PLATE)),
		maxi(1, roundi(box.size.z / STUD)))


# -- making a part longer, wider or taller -------------------------------------------


## Repeat (count > 0) or take out (count < 0) [param count] slices of
## [param period] LDU across [param axis] (0, 1, 2 for X, Y, Z). Returns
## {"shape": the new Shape or null, "problem": why not, or ""}.
static func slice(shape: Shape, axis: int, period: float, count: int) -> Dictionary:
	if count == 0:
		return {"shape": shape, "problem": ""}
	var span: float = period * absi(count) if count < 0 else period
	var cut: Array = _find_cut(shape, axis, span)
	if cut.is_empty():
		return {"shape": null, "problem": "no %s LDU slice of it is the same at both ends"
			% _n(span)}
	var a: float = cut[0]
	var c: float = cut[1]
	var out := Shape.new()
	var shift: float = period * count
	for t: int in shape.count():
		var pieces: Array = _split_three(shape.tris.slice(t * 9, t * 9 + 9), axis, a, c)
		for region: int in 3:
			for piece: PackedFloat64Array in pieces[region]:
				_place(out, piece, shape.colors[t], shape.two_sided[t], axis, region, count,
					period, shift)
	for n: int in shape.lines.size() / 6:
		var segments: Array = _split_segment(shape.lines.slice(n * 6, n * 6 + 6), axis, a, c)
		for region: int in 3:
			for segment: PackedFloat64Array in segments[region]:
				_place_line(out, segment, axis, region, count, period, shift)
	for c0: Array in shape.connectors:
		out.connectors.append_array(_move_connector(c0, axis, a, c, count, period, shift))
	for stud: Array in shape.studs_added:
		out.studs_added.append_array(_move_point(stud, axis, a, c, count, period, shift))
	for cap: Array in shape.caps:
		out.caps.append_array(_move_point(cap, axis, a, c, count, period, shift))
	return {"shape": out, "problem": ""}


## Where to cut: [a, c] with c = a + span, both through the part, the two
## cuts' cross-sections the same, nearest the part's middle. Empty if there
## is no such place.
static func _find_cut(shape: Shape, axis: int, span: float) -> Array:
	var lo: float = INF
	var hi: float = -INF
	for v: int in shape.tris.size() / 3:
		lo = minf(lo, shape.tris[v * 3 + axis])
		hi = maxf(hi, shape.tris[v * 3 + axis])
	var middle: float = (lo + hi) * 0.5
	var sections: Dictionary = {}
	# Half an LDU off the whole numbers, where faces and the ends of studs
	# are: a cut through a face lying in its plane says nothing. Tried from
	# the middle out, and the first that fits is the one: the middle is
	# where a part repeats, and a baseplate has six hundred places to try.
	var candidates: Array[float] = []
	var at: float = floorf(lo) + 0.5
	while at + span <= hi - 0.5 + 1e-9:
		candidates.append(at)
		at += 1.0
	candidates.sort_custom(func(p: float, q: float) -> bool:
		var dp: float = absf(p + span * 0.5 - middle)
		var dq: float = absf(q + span * 0.5 - middle)
		return dp < dq - 1e-9 or (absf(dp - dq) <= 1e-9 and p < q))
	for start_at: float in candidates:
		var start: Variant = _section_at(shape, axis, start_at, sections)
		if start == null:
			continue
		var end: Variant = _section_at(shape, axis, start_at + span, sections)
		if end != null and _same_section(start, end):
			return [start_at, start_at + span]
	return []


static func _section_at(shape: Shape, axis: int, at: float, cache: Dictionary) -> Variant:
	var key: int = roundi(at * 2.0)
	if not cache.has(key):
		cache[key] = _section(shape, axis, at)
	return cache[key]


## The cross-section of the part's surface on the plane [param axis] =
## [param at], as the set of SECTION_CELL squares its lines pass through;
## null where a triangle lies in the plane, and empty where nothing is cut.
static func _section(shape: Shape, axis: int, at: float) -> Variant:
	var u: int = (axis + 1) % 3
	var w: int = (axis + 2) % 3
	var cells: Dictionary = {}
	for t: int in shape.count():
		var o: int = t * 9
		var d := PackedFloat64Array([shape.tris[o + axis] - at, shape.tris[o + 3 + axis] - at,
			shape.tris[o + 6 + axis] - at])
		if (d[0] > 1e-6 and d[1] > 1e-6 and d[2] > 1e-6) \
				or (d[0] < -1e-6 and d[1] < -1e-6 and d[2] < -1e-6):
			continue
		if absf(d[0]) <= 1e-6 and absf(d[1]) <= 1e-6 and absf(d[2]) <= 1e-6:
			return null
		var ends: Array = []
		for n: int in 3:
			var m: int = (n + 1) % 3
			if absf(d[n]) <= 1e-6:
				ends.append([shape.tris[o + n * 3 + u], shape.tris[o + n * 3 + w]])
			elif (d[n] < 0.0) != (d[m] < 0.0) and absf(d[m]) > 1e-6:
				var f: float = d[n] / (d[n] - d[m])
				ends.append([lerpf(shape.tris[o + n * 3 + u], shape.tris[o + m * 3 + u], f),
					lerpf(shape.tris[o + n * 3 + w], shape.tris[o + m * 3 + w], f)])
		if ends.size() < 2:
			continue
		var p: Array = ends[0]
		var q: Array = ends[1]
		var length: float = Vector2(float(q[0]) - float(p[0]), float(q[1]) - float(p[1])).length()
		var steps: int = maxi(1, ceili(length / 0.1))
		for s: int in steps + 1:
			var f: float = float(s) / steps
			var pu: float = lerpf(float(p[0]), float(q[0]), f)
			var pw: float = lerpf(float(p[1]), float(q[1]), f)
			cells[Vector2i(floori((pu + 0.013) / SECTION_CELL),
				floori((pw + 0.013) / SECTION_CELL))] = true
	return cells


## Whether two cross-sections are the same face: every cell of each is in
## the other or next to one of its cells. A line at 45 degrees through the
## grid's corners touches different cells depending on where it was cut,
## and the face of a 45 degree slope is just such a line; half an LDU
## either way is still the same face, where a tube or a wall that one end
## has and the other has not is many cells from anything.
static func _same_section(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var differ: int = _unmatched(a, b) + _unmatched(b, a)
	var union: int = a.size() + b.size()
	return float(differ) <= maxf(2.0, SECTION_SLACK * union)


static func _unmatched(a: Dictionary, b: Dictionary) -> int:
	var count: int = 0
	for cell: Vector2i in a:
		var near: bool = false
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				if b.has(cell + Vector2i(dx, dy)):
					near = true
		if not near:
			count += 1
	return count


## A triangle cut by the planes at a and c: its pieces below a, between
## them, and past c, each a list of triangles.
static func _split_three(tri: PackedFloat64Array, axis: int, a: float, c: float) -> Array:
	var first: Array = _split_polygon(tri, axis, a)
	var below: Array = _triangulate(first[0])
	var rest: Array = []
	var past: Array = []
	for piece: PackedFloat64Array in _triangulate(first[1]):
		var second: Array = _split_polygon(piece, axis, c)
		rest.append_array(_triangulate(second[0]))
		past.append_array(_triangulate(second[1]))
	return [below, rest, past]


## A convex polygon (3 floats a point) cut by a plane: the part at or
## below it and the part at or above it. A point on the plane is put on it
## exactly, so the two sides of a cut meet.
static func _split_polygon(points: PackedFloat64Array, axis: int, at: float) -> Array:
	var below := PackedFloat64Array()
	var above := PackedFloat64Array()
	var count: int = points.size() / 3
	for n: int in count:
		var p: PackedFloat64Array = points.slice(n * 3, n * 3 + 3)
		var q: PackedFloat64Array = points.slice(((n + 1) % count) * 3, ((n + 1) % count) * 3 + 3)
		var dp: float = p[axis] - at
		var dq: float = q[axis] - at
		if dp <= 1e-9:
			below.append_array(p)
		if dp >= -1e-9:
			above.append_array(p)
		if (dp < -1e-9 and dq > 1e-9) or (dp > 1e-9 and dq < -1e-9):
			var f: float = dp / (dp - dq)
			var cut := PackedFloat64Array([lerpf(p[0], q[0], f), lerpf(p[1], q[1], f),
				lerpf(p[2], q[2], f)])
			cut[axis] = at
			below.append_array(cut)
			above.append_array(cut)
	return [below, above]


## A convex polygon as a fan of triangles; nothing for less than one, and
## nothing of no area.
static func _triangulate(points: PackedFloat64Array) -> Array:
	var out: Array = []
	var count: int = points.size() / 3
	for n: int in range(1, count - 1):
		var tri := PackedFloat64Array()
		tri.append_array(points.slice(0, 3))
		tri.append_array(points.slice(n * 3, n * 3 + 3))
		tri.append_array(points.slice((n + 1) * 3, (n + 1) * 3 + 3))
		var ux: float = tri[3] - tri[0]
		var uy: float = tri[4] - tri[1]
		var uz: float = tri[5] - tri[2]
		var vx: float = tri[6] - tri[0]
		var vy: float = tri[7] - tri[1]
		var vz: float = tri[8] - tri[2]
		var cx: float = uy * vz - uz * vy
		var cy: float = uz * vx - ux * vz
		var cz: float = ux * vy - uy * vx
		if cx * cx + cy * cy + cz * cz > 1e-10:
			out.append(tri)
	return out


static func _split_segment(segment: PackedFloat64Array, axis: int, a: float, c: float) -> Array:
	var regions: Array = [[], [], []]
	var pieces: Array = [segment]
	for n: int in 2:
		var at: float = a if n == 0 else c
		var next: Array = []
		for piece: PackedFloat64Array in pieces:
			var dp: float = piece[axis] - at
			var dq: float = piece[3 + axis] - at
			if (dp < -1e-9 and dq > 1e-9) or (dp > 1e-9 and dq < -1e-9):
				var f: float = dp / (dp - dq)
				var cut := PackedFloat64Array([lerpf(piece[0], piece[3], f),
					lerpf(piece[1], piece[4], f), lerpf(piece[2], piece[5], f)])
				cut[axis] = at
				next.append(piece.slice(0, 3) + cut)
				next.append(cut + piece.slice(3, 6))
			else:
				next.append(piece)
		pieces = next
	for piece: PackedFloat64Array in pieces:
		var middle: float = (piece[axis] + piece[3 + axis]) * 0.5
		regions[0 if middle < a else (1 if middle < c else 2)].append(piece)
	return regions


## Put a piece where its region goes: below the cut, as it was; in the
## slice, as it was and once more for every slice added (or not at all,
## when slices are taken out); past the cut, moved along by them all.
static func _place(out: Shape, tri: PackedFloat64Array, color: int, sided: int, axis: int,
		region: int, count: int, period: float, shift: float) -> void:
	var offsets: Array[float] = _offsets(region, count, period, shift)
	for offset: float in offsets:
		var moved: PackedFloat64Array = tri.duplicate()
		for v: int in 3:
			moved[v * 3 + axis] += offset
		out.tris.append_array(moved)
		out.colors.append(color)
		out.two_sided.append(sided)


static func _place_line(out: Shape, segment: PackedFloat64Array, axis: int, region: int,
		count: int, period: float, shift: float) -> void:
	for offset: float in _offsets(region, count, period, shift):
		var moved: PackedFloat64Array = segment.duplicate()
		moved[axis] += offset
		moved[3 + axis] += offset
		out.lines.append_array(moved)


static func _offsets(region: int, count: int, period: float, shift: float) -> Array[float]:
	var offsets: Array[float] = []
	match region:
		0:
			offsets.append(0.0)
		1:
			if count > 0:
				for k: int in count + 1:
					offsets.append(k * period)
		2:
			offsets.append(shift)
	return offsets


## A connector where its place goes, by where it is along the axis: before
## the cut, kept; in [a, c), kept and repeated (or dropped, with the slices
## taken out); from c on, moved. A round lying along the axis right across
## the slice is made longer or shorter with it; one cut by only one end of
## the slice describes nothing whole any more and is dropped.
static func _move_connector(c: Array, axis: int, a: float, c_at: float, count: int,
		period: float, shift: float) -> Array:
	var position := PackedFloat64Array([float(c[2]), float(c[3]), float(c[4])])
	var direction := PackedFloat64Array([float(c[5]), float(c[6]), float(c[7])])
	var length: float = float(c[8])
	if length > 0.0 and absf(direction[axis]) > 0.99:
		var start: float = position[axis]
		var end: float = start + direction[axis] * length
		var low: float = minf(start, end)
		var high: float = maxf(start, end)
		if low < a - 1e-6 and high > c_at + 1e-6:
			var row: Array = c.duplicate()
			row[8] = length + shift
			if direction[axis] < 0.0:
				row[2 + axis] = float(c[2 + axis]) + shift
			return [row]
		if (low < a - 1e-6 and high > a + 1e-6) or (low < c_at - 1e-6 and high > c_at + 1e-6):
			return []
		position[axis] = low
	var region: int = 0 if position[axis] < a - 1e-6 else (1 if position[axis] < c_at - 1e-6 else 2)
	var out: Array = []
	for offset: float in _offsets(region, count, period, shift):
		var row: Array = c.duplicate()
		row[2 + axis] = float(c[2 + axis]) + offset
		out.append(row)
	return out


static func _move_point(point: Array, axis: int, a: float, c: float, count: int,
		period: float, shift: float) -> Array:
	var region: int = 0 if float(point[axis]) < a - 1e-6 \
		else (1 if float(point[axis]) < c - 1e-6 else 2)
	var out: Array = []
	for offset: float in _offsets(region, count, period, shift):
		var row: Array = point.duplicate()
		row[axis] = float(point[axis]) + offset
		out.append(row)
	return out


## Move everything along an axis: how a part made longer is put back on
## its middle, as the app's stud snapping expects.
static func shifted(shape: Shape, axis: int, by: float) -> Shape:
	var out: Shape = shape.copy()
	for v: int in out.tris.size() / 3:
		out.tris[v * 3 + axis] += by
	for v: int in out.lines.size() / 3:
		out.lines[v * 3 + axis] += by
	for c: Array in out.connectors:
		c[2 + axis] = float(c[2 + axis]) + by
	for point: Array in out.studs_added:
		point[axis] = float(point[axis]) + by
	for point: Array in out.caps:
		point[axis] = float(point[axis]) + by
	return out


# -- studs on the top ---------------------------------------------------------------


## The studs standing up out of the part's top, as connectors.
static func top_studs(shape: Shape) -> Array:
	var out: Array = []
	for c: Array in shape.connectors:
		if c[0] == "stud" and c[1] == "male" and float(c[6]) < -0.99:
			out.append(c)
	return out


## Take the studs off the top: each stud's own triangles and lines go — all
## of them within its 6 LDU of its axis and its 4 of height — and so does
## its connector. Where the top under a stud was open (a hollow stud's hole
## runs down through 3062b's top), a plug as thick as a top closes it: a
## disc on the top would be a lid over nothing, not plastic. The plug is a
## disc on the top and one under it the width of the bore it fills — the
## hollow stud's own bore says how wide — with the bore's own wall between.
static func remove_top_studs(shape: Shape) -> Shape:
	var studs: Array = top_studs(shape)
	if studs.is_empty() and shape.studs_added.is_empty():
		return shape
	var near: Dictionary = {}     ## stud square -> the studs in it
	for stud: Array in studs:
		var cell := Vector2i(floori(float(stud[2]) / STUD), floori(float(stud[4]) / STUD))
		var here: Array = near.get(cell, [])
		if here.is_empty():
			near[cell] = here
		here.append(stud)
	var out := Shape.new()
	for t: int in shape.count():
		var tri: PackedFloat64Array = shape.tris.slice(t * 9, t * 9 + 9)
		if not _in_any_stud(tri, 3, _studs_near(near, tri[0], tri[2])):
			out.tris.append_array(tri)
			out.colors.append(shape.colors[t])
			out.two_sided.append(shape.two_sided[t])
	for n: int in shape.lines.size() / 6:
		var segment: PackedFloat64Array = shape.lines.slice(n * 6, n * 6 + 6)
		if not _in_any_stud(segment, 2, _studs_near(near, segment[0], segment[2])):
			out.lines.append_array(segment)
	out.caps = shape.caps.duplicate(true)
	var over: Dictionary = _by_square(out)
	var plugged: Array = []
	for stud: Array in studs:
		var x: float = stud[2]
		var y: float = stud[3]
		var z: float = stud[4]
		if not _top_covers(out, over, x, y, z):
			out.caps.append([x, y, z, 6.0, _bore_under(shape, stud)])
			plugged.append(stud)
	for c: Array in shape.connectors:
		if studs.has(c):
			continue
		var kept: Array = _below_studs(c, studs, plugged)
		if not kept.is_empty():
			out.connectors.append(kept)
	return out


## A round on a stud's axis that ran up into it — a hollow stud's bore —
## cut off at the stud's base, where the part now ends, or under the plug
## that closes the hole; dropped if nothing of it is left. Anything else as
## it was.
static func _below_studs(c: Array, studs: Array, plugged: Array) -> Array:
	# A stud's own rounds are no wider than it: a round brick's wall is on
	# its stud's axis too, and is the brick's.
	if float(c[8]) <= 0.0 or absf(float(c[6])) < 0.99 or float(c[9]) > 6.1:
		return c
	for stud: Array in studs:
		if absf(float(c[2]) - float(stud[2])) > 0.1 or absf(float(c[4]) - float(stud[4])) > 0.1:
			continue
		var base: float = float(stud[3]) + (PLUG if plugged.has(stud) else 0.0)
		var start: float = c[3]
		var end: float = start + float(c[6]) * float(c[8])
		var top: float = minf(start, end)
		var bottom: float = maxf(start, end)
		if bottom <= base + 1.0:
			return []
		if top >= base:
			return c
		var row: Array = c.duplicate()
		row[3] = base
		row[5] = 0.0
		row[6] = 1.0
		row[7] = 0.0
		row[8] = bottom - base
		return row
	return c


## The radius of the bore running down a stud's axis through the top — a
## hollow stud's hole — or 0 when there is none.
static func _bore_under(shape: Shape, stud: Array) -> float:
	for c: Array in shape.connectors:
		if c[0] != "bore" or float(c[9]) > 6.1 or absf(float(c[6])) < 0.99:
			continue
		if absf(float(c[2]) - float(stud[2])) > 0.1 or absf(float(c[4]) - float(stud[4])) > 0.1:
			continue
		var start: float = c[3]
		var end: float = start + float(c[6]) * float(c[8])
		if maxf(start, end) > float(stud[3]) + 0.5:
			return float(c[9])
	return 0.0


## The studs in the stud squares round (x, z): a point within a stud's 6
## LDU of its axis is in its own square or the next.
static func _studs_near(near: Dictionary, x: float, z: float) -> Array:
	var out: Array = []
	var cell := Vector2i(floori(x / STUD), floori(z / STUD))
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			out.append_array(near.get(cell + Vector2i(dx, dz), []))
	return out


## The triangles over each stud square, by the squares their extent seen
## from above covers.
static func _by_square(shape: Shape) -> Dictionary:
	var out: Dictionary = {}
	for t: int in shape.count():
		var o: int = t * 9
		var x0: int = floori(minf(shape.tris[o], minf(shape.tris[o + 3], shape.tris[o + 6])) / STUD)
		var x1: int = floori(maxf(shape.tris[o], maxf(shape.tris[o + 3], shape.tris[o + 6])) / STUD)
		var z0: int = floori(minf(shape.tris[o + 2], minf(shape.tris[o + 5], shape.tris[o + 8])) / STUD)
		var z1: int = floori(maxf(shape.tris[o + 2], maxf(shape.tris[o + 5], shape.tris[o + 8])) / STUD)
		for x: int in range(x0, x1 + 1):
			for z: int in range(z0, z1 + 1):
				var cell := Vector2i(x, z)
				var here: PackedInt32Array = out.get(cell, PackedInt32Array())
				here.append(t)
				out[cell] = here
	return out


static func _in_any_stud(points: PackedFloat64Array, count: int, studs: Array) -> bool:
	for stud: Array in studs:
		var inside: bool = true
		for v: int in count:
			var dx: float = points[v * 3] - float(stud[2])
			var dz: float = points[v * 3 + 2] - float(stud[4])
			var up: float = float(stud[3]) - points[v * 3 + 1]
			if dx * dx + dz * dz > 6.1 * 6.1 or up < -0.05 or up > 4.7:
				inside = false
				break
		if inside:
			return true
	return false


## Whether a face looking up covers (x, z) at height y.
static func _top_covers(shape: Shape, over: Dictionary, x: float, y: float, z: float) -> bool:
	for t: int in over.get(Vector2i(floori(x / STUD), floori(z / STUD)), PackedInt32Array()):
		var hit: Array = _stab_triangle(shape.tris, t, x, z)
		if not hit.is_empty() and absf(float(hit[0]) - y) < 0.05 and float(hit[1]) < -0.5:
			return true
	return false


## Where a vertical line through (x, z) meets triangle [param t]: [y, the
## y of its normal], or empty if it misses.
static func _stab_triangle(tris: PackedFloat64Array, t: int, x: float, z: float) -> Array:
	var o: int = t * 9
	var ax: float = tris[o]
	var az: float = tris[o + 2]
	var bx: float = tris[o + 3]
	var bz: float = tris[o + 5]
	var cx: float = tris[o + 6]
	var cz: float = tris[o + 8]
	var d: float = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
	if absf(d) < 1e-9:
		return []
	var w0: float = ((bx - x) * (cz - z) - (bz - z) * (cx - x)) / d
	var w1: float = ((cx - x) * (az - z) - (cz - z) * (ax - x)) / d
	var w2: float = 1.0 - w0 - w1
	if w0 < -1e-9 or w1 < -1e-9 or w2 < -1e-9:
		return []
	var y: float = w0 * tris[o + 1] + w1 * tris[o + 4] + w2 * tris[o + 7]
	var ux: float = bx - ax
	var uy: float = tris[o + 4] - tris[o + 1]
	var uz: float = bz - az
	var vx: float = cx - ax
	var vy: float = tris[o + 7] - tris[o + 1]
	var vz: float = cz - az
	var nx: float = uy * vz - uz * vy
	var ny: float = uz * vx - ux * vz
	var nz: float = ux * vy - uy * vx
	var length: float = sqrt(nx * nx + ny * ny + nz * nz)
	return [y, ny / length if length > 0.0 else 0.0]


## Put a stud on every stud square of the top that is flat all the way
## across where a stud would stand, and has none: a tile made a plate, a
## smooth brick studded.
static func fill_top_studs(shape: Shape) -> Shape:
	var out: Shape = shape.copy()
	# Where the top is: the faces looking up, not studs standing off a side.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for t: int in shape.count():
		if _facing_y(shape.tris, t) > -0.99:
			continue
		for v: int in 3:
			var o: int = t * 9 + v * 3
			lo = Vector2(minf(lo.x, shape.tris[o]), minf(lo.y, shape.tris[o + 2]))
			hi = Vector2(maxf(hi.x, shape.tris[o]), maxf(hi.y, shape.tris[o + 2]))
	if lo.x == INF:
		return out
	# The stud grid: the studs it has say where; with none, a stud's width
	# in from the low corner, as on every plain part.
	var phase := Vector2(lo.x + 10.0, lo.y + 10.0)
	var existing: Array = top_studs(shape)
	if not existing.is_empty():
		phase = Vector2(float(existing[0][2]), float(existing[0][4]))
	var over: Dictionary = _by_square(shape)
	var x: float = _first_on(phase.x, lo.x)
	while x <= hi.x - 10.0 + 1e-6:
		var z: float = _first_on(phase.y, lo.y)
		while z <= hi.y - 10.0 + 1e-6:
			if not _has_stud(out, x, z):
				var top: Variant = _flat_top(shape, over, x, z)
				if top != null:
					out.studs_added.append([x, float(top), z])
					out.connectors.append(["stud", "male", x, float(top), z, 0.0, -1.0, 0.0,
						0.0, 0.0])
			z += STUD
		x += STUD
	return out


## The Y of triangle [param t]'s facing, from its winding.
static func _facing_y(tris: PackedFloat64Array, t: int) -> float:
	var o: int = t * 9
	var ux: float = tris[o + 3] - tris[o]
	var uy: float = tris[o + 4] - tris[o + 1]
	var uz: float = tris[o + 5] - tris[o + 2]
	var vx: float = tris[o + 6] - tris[o]
	var vy: float = tris[o + 7] - tris[o + 1]
	var vz: float = tris[o + 8] - tris[o + 2]
	var nx: float = uy * vz - uz * vy
	var ny: float = uz * vx - ux * vz
	var nz: float = ux * vy - uy * vx
	var length: float = sqrt(nx * nx + ny * ny + nz * nz)
	return ny / length if length > 0.0 else 0.0


static func _first_on(phase: float, low: float) -> float:
	var at: float = phase
	while at - 20.0 >= low + 10.0 - 1e-6:
		at -= 20.0
	while at < low + 10.0 - 1e-6:
		at += 20.0
	return at


static func _has_stud(shape: Shape, x: float, z: float) -> bool:
	for c: Array in top_studs(shape):
		if absf(float(c[2]) - x) < 1.0 and absf(float(c[4]) - z) < 1.0:
			return true
	return false


## The height of the top at (x, z) if it is one flat face looking up all
## the way round where a stud would stand, else null.
static func _flat_top(shape: Shape, over: Dictionary, x: float, z: float) -> Variant:
	var height: Variant = null
	for k: int in 9:
		var px: float = x
		var pz: float = z
		if k > 0:
			var angle: float = TAU * float(k - 1) / 8.0 + 0.1
			px += cos(angle) * 6.5
			pz += sin(angle) * 6.5
		var best: float = INF
		var facing: float = 0.0
		for t: int in over.get(Vector2i(floori(px / STUD), floori(pz / STUD)), PackedInt32Array()):
			var hit: Array = _stab_triangle(shape.tris, t, px, pz)
			if not hit.is_empty() and float(hit[0]) < best:
				best = hit[0]
				facing = hit[1]
		if best == INF or facing > -0.99:
			return null
		if height == null:
			height = best
		elif absf(float(height) - best) > 0.01:
			return null
	return height


# -- the whole edit --------------------------------------------------------------------


## Why [param edit] cannot be made of [param mesh], or "" when it can.
static func problem(edit: Edit, mesh: Lbm.PartMesh) -> String:
	if mesh == null:
		return "there is no geometry for %s here yet" % edit.from
	if edit.length < 0 or edit.width < 0 or edit.plates < 0:
		return "sizes are whole studs and plates"
	if edit.length > MOST_STUDS or edit.width > MOST_STUDS:
		return "each side is 1 to %d studs" % MOST_STUDS
	if edit.plates > MOST_PLATES:
		return "a part is 1 to %d plates tall" % MOST_PLATES
	if not ["keep", "none", "fill"].has(edit.studs):
		return "studs are kept, taken off (none) or put on (fill)"
	if not edit.cut.is_empty():
		var c: PackedInt32Array = edit.cut
		if c.size() != 6 or c[0] < 0 or c[1] < 0 or c[4] < 0 or c[0] >= c[2] or c[1] >= c[3] \
				or c[4] >= c[5]:
			return ("a cut-out is from and to in studs across, studs deep and plates up, "
				+ "each to more than its from")
	return ""


## The new part's shape: the original's, made the size the edit says and
## with its studs as it says, put back on its middle. {"shape", "problem"}.
static func apply(edit: Edit, mesh: Lbm.PartMesh) -> Dictionary:
	var said: String = problem(edit, mesh)
	if not said.is_empty():
		return {"shape": null, "problem": said}
	var size: Vector3i = size_of(mesh)
	var shape: Shape = shape_of(mesh)
	# Where the plastic is, studs left out: the cover's extent, carried
	# through the changes in size below, for a cut-out to be measured from.
	var extent: PackedFloat64Array = extent_of(mesh)
	for step: Array in [[0, edit.length, size.x, STUD, "long"],
			[2, edit.width, size.z, STUD, "wide"], [1, edit.plates, size.y, PLATE, "tall"]]:
		var axis: int = step[0]
		var wanted: int = step[1]
		var has: int = step[2]
		if wanted == 0 or wanted == has:
			continue
		var done: Dictionary = slice(shape, axis, float(step[3]), wanted - has)
		if done["shape"] == null:
			return {"shape": null, "problem": "%s cannot be made %d %s %s: %s" % [edit.from,
				wanted, "plates" if axis == 1 else ("stud" if wanted == 1 else "studs"),
				step[4], done["problem"]]}
		shape = done["shape"]
		var grown: float = float(step[3]) * (wanted - has)
		if axis != 1:
			# Back on its middle: half of what was added, the other way.
			shape = shifted(shape, axis, -grown * 0.5)
			extent[axis * 2] -= grown * 0.5
			extent[axis * 2 + 1] += grown * 0.5
		else:
			extent[3] += grown
	if edit.cut.size() == 6:
		var cut: Dictionary = cut_out(shape, edit.cut, extent)
		if cut["shape"] == null:
			return {"shape": null, "problem": "%s cannot have that cut out: %s" % [edit.from,
				cut["problem"]]}
		shape = cut["shape"]
	match edit.studs:
		"none":
			shape = remove_top_studs(shape)
		"fill":
			shape = fill_top_studs(shape)
	if shape.count() == 0:
		return {"shape": null, "problem": "nothing of %s is left" % edit.from}
	return {"shape": shape, "problem": ""}


## The part file's name for an edit: "bw-3700-l6", "bw-3001-p6s0".
static func id_for(edit: Edit) -> String:
	var source: String = ""
	for n: int in edit.from.length():
		var ch: String = edit.from[n].to_lower()
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			source += ch
	var tail: String = ""
	if edit.length > 0:
		tail += "l%d" % edit.length
	if edit.width > 0:
		tail += "w%d" % edit.width
	if edit.plates > 0:
		tail += "p%d" % edit.plates
	if edit.studs == "none":
		tail += "s0"
	elif edit.studs == "fill":
		tail += "sa"
	if edit.cut.size() == 6:
		# The box as a short tag: its six numbers would not fit the name.
		tail += "c%03x" % (hash(Array(edit.cut)) & 0xfff)
	if tail.is_empty():
		tail = "copy"
	return ("bw-%s-%s" % [source.left(10), tail]).left(21)


## The title: the original's, and what was changed.
static func title_for(edit: Edit, name: String, size: Vector3i) -> String:
	if not edit.title.strip_edges().is_empty():
		return edit.title.strip_edges()
	var changes := PackedStringArray()
	if edit.length > 0 and edit.length != size.x:
		changes.append("%d Long" % edit.length)
	if edit.width > 0 and edit.width != size.z:
		changes.append("%d Wide" % edit.width)
	if edit.plates > 0 and edit.plates != size.y:
		changes.append("%d Plates Tall" % edit.plates)
	if edit.studs == "none":
		changes.append("without Top Studs")
	elif edit.studs == "fill":
		changes.append("with Studs Added")
	if edit.cut.size() == 6:
		changes.append("with Cut-Out")
	var base: String = name.strip_edges().trim_prefix("~").trim_prefix("=")
	if changes.is_empty():
		return base + " (Copy)"
	return "%s (%s)" % [base, ", ".join(changes)]


## The part file for an edit of [param part_id] (whose mesh, name and
## category these are), or a problem. {"text", "id", "title", "problem"}.
static func make_dat(edit: Edit, mesh: Lbm.PartMesh, name: String, category: String,
		id: String = "") -> Dictionary:
	var made: Dictionary = apply(edit, mesh)
	if made["shape"] == null:
		return {"text": "", "id": "", "title": "", "problem": made["problem"]}
	var shape: Shape = made["shape"]
	if id.is_empty():
		id = id_for(edit)
	var title: String = title_for(edit, name, size_of(mesh))
	var out := PackedStringArray()
	out.append("0 " + title)
	out.append("0 Name: %s.dat" % id)
	out.append("0 Author: " + AUTHOR)
	out.append("0 !LDRAW_ORG Unofficial_Part")
	out.append("0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt")
	out.append("")
	out.append("0 BFC CERTIFY CCW")
	out.append("")
	out.append("0 !CATEGORY " + (category if not category.is_empty() else "Brick"))
	out.append("0 !KEYWORDS Brickworks, custom element, modified")
	out.append("")
	out.append(MODIFIED_BY + " " + edit.to_words())
	out.append("0 // Made from %s.dat of the LDraw Parts Library (CC BY 4.0) as the" % edit.from)
	out.append("0 // app built it: its triangles, its creases and its connectors, changed as above.")
	out.append("")
	out.append("0 // Connectors, for programs that read them")
	for c: Array in shape.connectors:
		# The studs drawn with stud.dat below are found from it.
		if _is_added_stud(c, shape):
			continue
		var line: String = "0 %s CONNECTOR %s %s %s %s %s %s %s %s" % [CONNECTOR, c[0], c[1],
			_n(c[2]), _n(c[3]), _n(c[4]), _n(c[5]), _n(c[6]), _n(c[7])]
		if float(c[8]) > 0.0:
			line += " %s %s" % [_n(c[8]), _n(c[9])]
		out.append(line)
	out.append("")
	out.append("0 // Faces")
	var open: bool = false
	for t: int in shape.count():
		var sided: bool = shape.two_sided[t] == 1
		if sided and not open:
			out.append("0 BFC NOCLIP")
			open = true
		elif not sided and open:
			out.append("0 BFC CLIP")
			open = false
		var o: int = t * 9
		out.append("3 %d %s %s %s %s %s %s %s %s %s" % [shape.colors[t],
			_n(shape.tris[o]), _n(shape.tris[o + 1]), _n(shape.tris[o + 2]),
			_n(shape.tris[o + 3]), _n(shape.tris[o + 4]), _n(shape.tris[o + 5]),
			_n(shape.tris[o + 6]), _n(shape.tris[o + 7]), _n(shape.tris[o + 8])])
	if open:
		out.append("0 BFC CLIP")
	out.append("0 // Edges")
	for n: int in shape.lines.size() / 6:
		var o: int = n * 6
		out.append("2 24 %s %s %s %s %s %s" % [_n(shape.lines[o]), _n(shape.lines[o + 1]),
			_n(shape.lines[o + 2]), _n(shape.lines[o + 3]), _n(shape.lines[o + 4]),
			_n(shape.lines[o + 5])])
	if not shape.studs_added.is_empty() or not shape.caps.is_empty():
		out.append("0 // Studs put on, and the tops of studs taken off closed")
	for stud: Array in shape.studs_added:
		out.append("1 16 %s %s %s 1 0 0 0 1 0 0 0 1 stud.dat" % [_n(stud[0]), _n(stud[1]),
			_n(stud[2])])
	for cap: Array in shape.caps:
		# A plug: a disc on the part's top, and one closing the bore under
		# it a top's thickness down, facing into the bore.
		var r: String = _n(cap[3])
		out.append("1 16 %s %s %s %s 0 0 0 1 0 0 0 %s 4-4disc.dat" % [_n(cap[0]), _n(cap[1]),
			_n(cap[2]), r, r])
		if cap.size() > 4 and float(cap[4]) > 0.0:
			var bore: String = _n(cap[4])
			out.append("0 BFC INVERTNEXT")
			out.append("1 16 %s %s %s %s 0 0 0 1 0 0 0 %s 4-4disc.dat" % [_n(cap[0]),
				_n(float(cap[1]) + PLUG), _n(cap[2]), bore, bore])
	out.append("0")
	return {"text": "\n".join(out) + "\n", "id": id, "title": title, "problem": ""}


static func _is_added_stud(c: Array, shape: Shape) -> bool:
	if c[0] != "stud":
		return false
	for stud: Array in shape.studs_added:
		if absf(float(stud[0]) - float(c[2])) < 1e-6 and absf(float(stud[1]) - float(c[3])) < 1e-6 \
				and absf(float(stud[2]) - float(c[4])) < 1e-6:
			return true
	return false


## The edit a modified part was made with, read from its header, or null.
static func parse_edit(text: String) -> Edit:
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with(MODIFIED_BY):
			continue
		var edit := Edit.new()
		for word: String in line.substr(MODIFIED_BY.length()).strip_edges().split(" ", false):
			var pair: PackedStringArray = word.split("=")
			if pair.size() != 2:
				continue
			match pair[0]:
				"from": edit.from = pair[1]
				"length": edit.length = pair[1].to_int()
				"width": edit.width = pair[1].to_int()
				"plates": edit.plates = pair[1].to_int()
				"studs": edit.studs = pair[1]
				"cut":
					edit.cut = PackedInt32Array()
					for number: String in pair[1].split(","):
						edit.cut.append(number.to_int())
		return edit
	return null


## How deep a plug closing a stud's hole goes: a top's 4 LDU.
const PLUG := 4.0


# -- a cut-out ---------------------------------------------------------------------

## The cells plastic is read in, LDU on a side, as the collision cover's.
const CELL := 2.0
## How thick the wall put back round a cut through the hollow is, in cells.
const LINING := 2


## Take a box out of the part: [param cut] as [member Edit.cut], measured
## from [param extent] ([method extent_of]). Returns {"shape", "problem"}.
static func cut_out(shape: Shape, cut: PackedInt32Array,
		extent: PackedFloat64Array) -> Dictionary:
	var plastic: Dictionary = _plastic(shape)
	if plastic.is_empty():
		return {"shape": null, "problem": "it has no inside to read"}
	var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var hi := -lo
	for cell: Vector3i in plastic:
		lo = Vector3i(mini(lo.x, cell.x), mini(lo.y, cell.y), mini(lo.z, cell.z))
		hi = Vector3i(maxi(hi.x, cell.x), maxi(hi.y, cell.y), maxi(hi.z, cell.z))
	# The part's extent in LDU, LDraw's axes: the app's z is LDraw's -z, so
	# studs counted from the app's low z run from LDraw's high z. Not the
	# cells' extent: a stud's inside reads as plastic, and a cut "to the top"
	# measured from the tops of the studs stopped short of the body's top.
	var x0: float = extent[0]
	var x1: float = extent[1]
	var y_top: float = extent[2]
	var y_bottom: float = extent[3]
	var z0: float = extent[4]
	var z1: float = extent[5]
	var box_lo := PackedFloat64Array([x0 + cut[0] * STUD, y_bottom - cut[5] * PLATE,
		z1 - cut[3] * STUD])
	var box_hi := PackedFloat64Array([x0 + cut[2] * STUD, y_bottom - cut[4] * PLATE,
		z1 - cut[1] * STUD])
	# Where the box reaches an edge of the part it goes on past it, so studs
	# standing off that face go with what they stood on.
	if cut[0] == 0:
		box_lo[0] = -INF
	if box_hi[0] >= x1 - 0.5:
		box_hi[0] = INF
	if box_lo[1] <= y_top + 0.5:
		box_lo[1] = -INF
	if cut[4] == 0:
		box_hi[1] = INF
	if box_lo[2] <= z0 + 0.5:
		box_lo[2] = -INF
	if cut[1] == 0:
		box_hi[2] = INF
	var inside: Callable = func(cell: Vector3i) -> bool:
		for n: int in 3:
			var middle: float = (cell[n] + 0.5) * CELL
			if middle <= box_lo[n] or middle >= box_hi[n]:
				return false
		return true
	var took: int = 0
	for cell: Vector3i in plastic:
		if inside.call(cell):
			took += 1
	if took == 0:
		return {"shape": null, "problem": "the cut-out misses it"}
	if took == plastic.size():
		return {"shape": null, "problem": "the cut-out takes all of it"}
	var filled: Dictionary = _filled(plastic, lo, hi)
	# The hollow the cut opens: the wall put back round it, LINING cells
	# thick, straight out from the box's faces.
	var lining: Dictionary = {}
	for cell: Vector3i in filled:
		if plastic.has(cell) or inside.call(cell):
			continue
		var near: bool = false
		for step: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN,
				Vector3i.BACK, Vector3i.FORWARD]:
			for k: int in range(1, LINING + 1):
				if inside.call(cell + step * k):
					near = true
		if near:
			lining[cell] = true

	var out := Shape.new()
	for t: int in shape.count():
		for piece: PackedFloat64Array in _outside_box(shape.tris.slice(t * 9, t * 9 + 9),
				box_lo, box_hi):
			out.tris.append_array(piece)
			out.colors.append(shape.colors[t])
			out.two_sided.append(shape.two_sided[t])
	for n: int in shape.lines.size() / 6:
		var segment: PackedFloat64Array = shape.lines.slice(n * 6, n * 6 + 6)
		var middle := PackedFloat64Array([(segment[0] + segment[3]) * 0.5,
			(segment[1] + segment[4]) * 0.5, (segment[2] + segment[5]) * 0.5])
		if not _point_in_box(middle, box_lo, box_hi):
			out.lines.append_array(segment)
	for c: Array in shape.connectors:
		var at := PackedFloat64Array([float(c[2]), float(c[3]), float(c[4])])
		if _point_in_box(at, box_lo, box_hi):
			continue
		if float(c[8]) > 0.0:
			var end := PackedFloat64Array([at[0] + float(c[5]) * float(c[8]),
				at[1] + float(c[6]) * float(c[8]), at[2] + float(c[7]) * float(c[8])])
			var mid := PackedFloat64Array([(at[0] + end[0]) * 0.5, (at[1] + end[1]) * 0.5,
				(at[2] + end[2]) * 0.5])
			if _point_in_box(end, box_lo, box_hi) or _point_in_box(mid, box_lo, box_hi):
				continue
		out.connectors.append(c)
	for stud: Array in shape.studs_added:
		if not _point_in_box(PackedFloat64Array([stud[0], stud[1], stud[2]]), box_lo, box_hi):
			out.studs_added.append(stud)
	for cap: Array in shape.caps:
		if not _point_in_box(PackedFloat64Array([cap[0], cap[1], cap[2]]), box_lo, box_hi):
			out.caps.append(cap)

	# The faces that close it: where kept plastic met plastic the box took,
	# and all round the wall put back, which also cancels the hollow's own
	# face it now covers.
	var faces: Dictionary = {}     ## [axis, sign, plane] -> {Vector2i: true}
	for cell: Vector3i in plastic:
		if inside.call(cell):
			continue
		for step: Vector3i in _STEPS:
			var next: Vector3i = cell + step
			if inside.call(next) and plastic.has(next):
				_note_face(faces, cell, step)
	for cell: Vector3i in lining:
		for step: Vector3i in _STEPS:
			if not lining.has(cell + step):
				_note_face(faces, cell, step)
	_emit_faces(out, faces)
	return {"shape": out, "problem": ""}


const _STEPS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


static func _point_in_box(p: PackedFloat64Array, lo: PackedFloat64Array,
		hi: PackedFloat64Array) -> bool:
	for n: int in 3:
		if p[n] <= lo[n] + 0.01 or p[n] >= hi[n] - 0.01:
			return false
	return true


## The pieces of a triangle outside a box: cut at each of the box's faces
## in turn, keeping what is beyond it and carrying on with the rest; what is
## left at the end is inside, and goes. A piece lying in a face's plane is
## outside.
static func _outside_box(tri: PackedFloat64Array, lo: PackedFloat64Array,
		hi: PackedFloat64Array) -> Array:
	var kept: Array = []
	var rest: Array = [tri]
	for n: int in 3:
		for side: int in 2:
			var at: float = lo[n] if side == 0 else hi[n]
			if is_inf(at):
				continue
			var next: Array = []
			for piece: PackedFloat64Array in rest:
				var flat: bool = true
				for v: int in piece.size() / 3:
					if absf(piece[v * 3 + n] - at) > 1e-6:
						flat = false
				if flat:
					kept.append(piece)
					continue
				var halves: Array = _split_polygon(piece, n, at)
				# Below the low face, or above the high one, is outside.
				var beyond: PackedFloat64Array = halves[0] if side == 0 else halves[1]
				var within: PackedFloat64Array = halves[1] if side == 0 else halves[0]
				if beyond.size() >= 9:
					kept.append(beyond)
				if within.size() >= 9:
					next.append(within)
			rest = next
	var out: Array = []
	for piece: PackedFloat64Array in kept:
		out.append_array(_triangulate(piece))
	return out


## The part's plastic, cell by cell in LDraw's axes: a cell is plastic when
## the faces a vertical line through its middle crosses from above, counted
## in (a face looking up) and out, have it inside — the voxeliser's rule.
static func _plastic(shape: Shape) -> Dictionary:
	var columns: Dictionary = {}       ## Vector2i -> [[y, +1 or -1], ...]
	for t: int in shape.count():
		var o: int = t * 9
		var ax: float = shape.tris[o]
		var az: float = shape.tris[o + 2]
		var bx: float = shape.tris[o + 3]
		var bz: float = shape.tris[o + 5]
		var cx: float = shape.tris[o + 6]
		var cz: float = shape.tris[o + 8]
		var d: float = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
		if absf(d) < 1e-9:
			continue
		# The normal's y is -d: a face looking up (LDraw's -y) has d > 0.
		var way: int = 1 if d > 0.0 else -1
		var i0: int = floori(minf(ax, minf(bx, cx)) / CELL)
		var i1: int = floori(maxf(ax, maxf(bx, cx)) / CELL)
		var k0: int = floori(minf(az, minf(bz, cz)) / CELL)
		var k1: int = floori(maxf(az, maxf(bz, cz)) / CELL)
		for i: int in range(i0, i1 + 1):
			var x: float = (i + 0.5) * CELL
			for k: int in range(k0, k1 + 1):
				var z: float = (k + 0.5) * CELL
				var w0: float = ((bx - x) * (cz - z) - (bz - z) * (cx - x)) / d
				var w1: float = ((cx - x) * (az - z) - (cz - z) * (ax - x)) / d
				var w2: float = 1.0 - w0 - w1
				if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
					continue
				var y: float = w0 * shape.tris[o + 1] + w1 * shape.tris[o + 4] \
					+ w2 * shape.tris[o + 7]
				var key := Vector2i(i, k)
				if not columns.has(key):
					columns[key] = []
				(columns[key] as Array).append([y, way])
	var cells: Dictionary = {}
	for key: Vector2i in columns:
		var hits: Array = columns[key]
		hits.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var count: int = 0
		for n: int in hits.size():
			count += int(hits[n][1])
			if count > 0 and n + 1 < hits.size():
				var top: float = hits[n][0]
				var bottom: float = hits[n + 1][0]
				for j: int in range(ceili(top / CELL - 0.5), ceili(bottom / CELL - 0.5)):
					cells[Vector3i(key.x, j, key.y)] = true
	return cells


## The plastic with each layer's enclosed hollows filled, as the collision
## cover fills them: the hollow under a brick is hollow; the space a cut
## opens into it is what needs a wall.
static func _filled(plastic: Dictionary, lo: Vector3i, hi: Vector3i) -> Dictionary:
	var out: Dictionary = {}
	var sx: int = hi.x - lo.x + 3
	var sz: int = hi.z - lo.z + 3
	for j: int in range(lo.y, hi.y + 1):
		var mask := PackedByteArray()
		mask.resize(sx * sz)
		for i: int in range(lo.x, hi.x + 1):
			for k: int in range(lo.z, hi.z + 1):
				if plastic.has(Vector3i(i, j, k)):
					mask[(i - lo.x + 1) * sz + (k - lo.z + 1)] = 1
		var full: PackedByteArray = PartForge._fill_holes(mask, sx, sz)
		for a: int in sx:
			for b: int in sz:
				if full[a * sz + b] == 1:
					out[Vector3i(a + lo.x - 1, j, b + lo.z - 1)] = true
	return out


static func _note_face(faces: Dictionary, cell: Vector3i, step: Vector3i) -> void:
	var axis: int = 0 if step.x != 0 else (1 if step.y != 0 else 2)
	var sign: int = step[axis]
	var plane: int = cell[axis] + (1 if sign > 0 else 0)
	var u: int = (axis + 1) % 3
	var w: int = (axis + 2) % 3
	var key := Vector3i(axis, sign, plane)
	if not faces.has(key):
		faces[key] = {}
	(faces[key] as Dictionary)[Vector2i(cell[u], cell[w])] = true


## The faces as rectangles, merged where they meet in a plane, and drawn as
## two triangles each, looking the way they were noted.
static func _emit_faces(out: Shape, faces: Dictionary) -> void:
	for key: Vector3i in faces:
		var axis: int = key.x
		var normal := PackedFloat64Array([0.0, 0.0, 0.0])
		normal[axis] = float(key.y)
		var at: float = key.z * CELL
		var u: int = (axis + 1) % 3
		var w: int = (axis + 2) % 3
		var left: Dictionary = (faces[key] as Dictionary).duplicate()
		var order: Array = left.keys()
		order.sort()
		for start: Vector2i in order:
			if not left.has(start):
				continue
			var width: int = 1
			while left.has(start + Vector2i(width, 0)):
				width += 1
			var height: int = 1
			var grows: bool = true
			while grows:
				for d: int in width:
					if not left.has(start + Vector2i(d, height)):
						grows = false
						break
				if grows:
					height += 1
			for a: int in width:
				for b: int in height:
					left.erase(start + Vector2i(a, b))
			var corners: Array = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(width, 0), Vector2i(width, height),
					Vector2i(0, height)]:
				var p := PackedFloat64Array([0.0, 0.0, 0.0])
				p[axis] = at
				p[u] = (start.x + corner.x) * CELL
				p[w] = (start.y + corner.y) * CELL
				corners.append(p)
			_quad(out, corners, normal)


static func _quad(out: Shape, corners: Array, normal: PackedFloat64Array) -> void:
	var a: PackedFloat64Array = corners[0]
	var b: PackedFloat64Array = corners[1]
	var c: PackedFloat64Array = corners[2]
	var ux: float = b[0] - a[0]
	var uy: float = b[1] - a[1]
	var uz: float = b[2] - a[2]
	var vx: float = c[0] - a[0]
	var vy: float = c[1] - a[1]
	var vz: float = c[2] - a[2]
	var facing: float = (uy * vz - uz * vy) * normal[0] + (uz * vx - ux * vz) * normal[1] \
		+ (ux * vy - uy * vx) * normal[2]
	var ring: Array = corners.duplicate()
	if facing < 0.0:
		ring.reverse()
	for tri: Array in [[ring[0], ring[1], ring[2]], [ring[0], ring[2], ring[3]]]:
		for p: PackedFloat64Array in tri:
			out.tris.append_array(p)
		out.colors.append(16)
		out.two_sided.append(0)


## A number as the part file writes it: exact for the mesh's 64ths of an
## LDU, no trailing zeros, no "-0".
static func _n(value: Variant) -> String:
	var v: float = float(value)
	var rounded: float = snappedf(v, 0.000001)
	if absf(rounded - roundf(rounded)) < 0.0000005:
		return str(int(roundf(rounded)))
	var text: String = String.num(rounded, 6)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return "0" if text == "-0" else text
