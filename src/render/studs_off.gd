## A part drawn without its studs: View › Edges and studs › Studs off
## (APP_UX6 #19), as LDCad and LDView can draw a model, to read it by its
## shapes, and to draw a big one with less: the studs are 30 to 55% of an
## ordinary part's triangles (a 2 x 4 brick's 384 of 700).
##
## A stud is what the part's connectors say is one (a male stud, Lbm), with
## LDraw's stud primitives' size: a round 6 LDU across its half, standing 4
## LDU from its foot along its axis, a logo's letters on top. Every triangle
## wholly inside that round is left out, of every surface of the part.
##
## A stud stood on a face drawn whole under it leaves the face as it was. One
## stood on a ring (a round plate's top), on a side with its own hole (a
## brick with a stud on its side) or over a bore (a hollow stud) leaves an
## opening the shape of its foot, and that is closed by a disc lying on the
## foot, facing out along the stud's axis, made from the opening's own edges:
## so what is drawn where a stud was is the plastic it stood on, and nothing
## else is drawn that was not there. Where no triangle of a stud was found
## its foot is left as it is, opening and all: no disc is laid where nothing
## was taken.
##
## What is left out is only what is drawn: the part's box, its place, its
## connectors and everything read from them are the part's own. DUPLO's and
## Quatro's studs, two and four times the size, are drawn still: the round is
## the LEGO System stud's.
class_name StudsOff
extends RefCounted

## A stud's round, LDU: its half across with a quantised vertex's slack (the
## mesh's 1/64 LDU) and the rim of a logo, and how tall it stands with the
## logo's letters.
const RADIUS := 6.1
const TALL := 4.8
## How far off its foot's plane a vertex may be and be on it, LDU.
const FOOT := 0.05
## An opening's edge closed by the disc lies on the foot, at least this far
## from the stud's axis: a hollow stud's bore is 4 across its half.
const FOOT_INNER := 3.5
## The grid the studs are found in, LDU: at least twice the farthest any
## point of a stud is from its middle, so a vertex looks in one cell.
const CELL := 16.0
## Kept on the part, so a part's surfaces are made once and go with it.
const META := &"studs_off"

## How long the last part's surfaces took to make, ms, for a probe.
static var last_ms: float = 0.0


## [param part]'s surfaces drawn without its studs, one for each of its own:
## the very same mesh where a surface has no stud, a mesh of its own where it
## had. Made on the first call and kept with the part.
##
## Read off the graphics card (ArrayMesh.surface_get_arrays): the part's
## arrays are not kept once its meshes are made. In a browser that read
## waits for the card to finish what is queued (BrickWorld._triangles_of), so
## a caller asks for every part it needs in one frame, where only the first
## waits.
static func surfaces(part: Lbm.PartMesh) -> Array[ArrayMesh]:
	if part.has_meta(META):
		return part.get_meta(META)
	var began: int = Time.get_ticks_usec()
	var made: Array[ArrayMesh] = _made(part)
	part.set_meta(META, made)
	last_ms = float(Time.get_ticks_usec() - began) / 1000.0
	return made


## The part's male studs: [their feet, their axes].
static func studs_of(part: Lbm.PartMesh) -> Array:
	var feet := PackedVector3Array()
	var axes := PackedVector3Array()
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == "stud" and connector.gender == "male" \
				and connector.axis.length_squared() > 0.5:
			feet.append(connector.position)
			axes.append(connector.axis.normalized())
	return [feet, axes]


static func _made(part: Lbm.PartMesh) -> Array[ArrayMesh]:
	var made: Array[ArrayMesh] = []
	made.assign(part.surfaces)
	var found: Array = studs_of(part)
	var feet: PackedVector3Array = found[0]
	var axes: PackedVector3Array = found[1]
	if feet.is_empty():
		return made
	var cells: Dictionary = _cells(feet, axes)

	# Each surface's arrays, which of its vertices are in which stud, and the
	# triangles kept.
	var arrays_of: Array = []
	var kept_of: Array = []
	var foot_of: Array = []
	var taken := PackedByteArray()
	taken.resize(feet.size())
	var any: bool = false
	for surface: ArrayMesh in part.surfaces:
		var arrays: Array = surface.surface_get_arrays(0) if surface.get_surface_count() > 0 else []
		if arrays.size() < Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null \
				or arrays[Mesh.ARRAY_INDEX] == null:
			arrays_of.append([])
			kept_of.append(PackedInt32Array())
			foot_of.append(PackedInt32Array())
			continue
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var inside := PackedInt32Array()
		var foot := PackedInt32Array()
		inside.resize(points.size())
		foot.resize(points.size())
		inside.fill(-1)
		foot.fill(-1)
		for v: int in points.size():
			var at: Vector3 = points[v]
			var near: Variant = cells.get(Vector3i(floori(at.x / CELL), floori(at.y / CELL),
				floori(at.z / CELL)))
			if near == null:
				continue
			for s: int in near as PackedInt32Array:
				var d: Vector3 = at - feet[s]
				var h: float = d.dot(axes[s])
				if h < -FOOT or h > TALL:
					continue
				var across: float = d.length_squared() - h * h
				if across > RADIUS * RADIUS:
					continue
				inside[v] = s
				if h <= FOOT and across >= FOOT_INNER * FOOT_INNER:
					foot[v] = s
				break
		var kept := PackedInt32Array()
		kept.resize(indices.size())
		var count: int = 0
		for t: int in range(0, indices.size() - 2, 3):
			var a: int = indices[t]
			var s: int = inside[a]
			if s >= 0 and inside[indices[t + 1]] == s and inside[indices[t + 2]] == s:
				taken[s] = 1
				any = true
				continue
			kept[count] = a
			kept[count + 1] = indices[t + 1]
			kept[count + 2] = indices[t + 2]
			count += 3
		kept.resize(count)
		arrays_of.append(arrays)
		kept_of.append(kept)
		foot_of.append(foot)
	if not any:
		return made

	# The edges on a stud's foot used by one kept triangle only, across every
	# surface: the openings its triangles left. By where their ends are, as a
	# corner shared by two faces is two vertices, one for each face's normal.
	var edges: Dictionary = {}  ## "a|b" -> [uses, surface, vertex a, vertex b, stud]
	for n: int in arrays_of.size():
		if (arrays_of[n] as Array).is_empty():
			continue
		var points: PackedVector3Array = arrays_of[n][Mesh.ARRAY_VERTEX]
		var kept: PackedInt32Array = kept_of[n]
		var foot: PackedInt32Array = foot_of[n]
		for t: int in range(0, kept.size(), 3):
			for e: int in 3:
				var a: int = kept[t + e]
				var b: int = kept[t + (e + 1) % 3]
				var s: int = foot[a]
				if s < 0 or foot[b] != s or taken[s] == 0:
					continue
				var key: String = _edge_key(points[a], points[b])
				var seen: Variant = edges.get(key)
				if seen == null:
					edges[key] = [1, n, a, b, s]
				else:
					(seen as Array)[0] = int((seen as Array)[0]) + 1

	# Each opening closed: a triangle from each of its edges to the foot's
	# middle, facing out along the stud, with the stud's axis for its normal.
	var discs: Array = []  ## per surface: [[vertex a, vertex b, stud], ...]
	discs.resize(arrays_of.size())
	for n: int in discs.size():
		discs[n] = []
	for key: String in edges:
		var edge: Array = edges[key]
		if int(edge[0]) == 1:
			(discs[int(edge[1])] as Array).append([edge[2], edge[3], edge[4]])

	for n: int in arrays_of.size():
		var arrays: Array = arrays_of[n]
		if arrays.is_empty():
			continue
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept: PackedInt32Array = kept_of[n]
		if kept.size() == indices.size() and (discs[n] as Array).is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		_lay_discs(arrays, discs[n], feet, axes)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# The part's own box, as its meshes have (Lbm.make_meshes): what is
		# left is inside it, and the batch's bounds are read from it.
		mesh.custom_aabb = part.bounds
		made[n] = mesh
	return made


## The cells of [constant CELL] each stud reaches into: Vector3i -> the studs'
## numbers.
static func _cells(feet: PackedVector3Array, axes: PackedVector3Array) -> Dictionary:
	var cells: Dictionary = {}
	var reach: float = sqrt(RADIUS * RADIUS + pow(TALL * 0.5 + FOOT, 2.0)) + 0.01
	for s: int in feet.size():
		var middle: Vector3 = feet[s] + axes[s] * (TALL * 0.5)
		var low := Vector3i(floori((middle.x - reach) / CELL), floori((middle.y - reach) / CELL),
			floori((middle.z - reach) / CELL))
		var high := Vector3i(floori((middle.x + reach) / CELL), floori((middle.y + reach) / CELL),
			floori((middle.z + reach) / CELL))
		for x: int in range(low.x, high.x + 1):
			for y: int in range(low.y, high.y + 1):
				for z: int in range(low.z, high.z + 1):
					var cell := Vector3i(x, y, z)
					var list: PackedInt32Array = cells.get(cell, PackedInt32Array())
					list.append(s)
					cells[cell] = list
	return cells


## An edge by where its ends are, to the mesh's own 1/64 LDU, the same
## whichever way round.
static func _edge_key(a: Vector3, b: Vector3) -> String:
	var p := Vector3i(roundi(a.x * 64.0), roundi(a.y * 64.0), roundi(a.z * 64.0))
	var q := Vector3i(roundi(b.x * 64.0), roundi(b.y * 64.0), roundi(b.z * 64.0))
	if q < p:
		var swap: Vector3i = p
		p = q
		q = swap
	return "%d,%d,%d|%d,%d,%d" % [p.x, p.y, p.z, q.x, q.y, q.z]


## [param edges] ([vertex a, vertex b, stud]) laid into [param arrays] as
## triangles to their studs' feet: three new vertices each, with the stud's
## axis for their normal, wound as the part's faces are (a front face's
## corners turn against its normal: cross(b - a, c - a) points into the
## plastic). Every other array a vertex has is copied from the edge's own
## ends, but the picture's: off it, as a print's clear border is.
static func _lay_discs(arrays: Array, edges: Array, feet: PackedVector3Array,
		axes: PackedVector3Array) -> void:
	if edges.is_empty():
		return
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
		if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var had: int = points.size()
	var with_normals: bool = normals.size() == had
	var from := PackedInt32Array()
	for edge: Array in edges:
		var a: int = edge[0]
		var b: int = edge[1]
		var s: int = edge[2]
		var middle: Vector3 = feet[s]
		var axis: Vector3 = axes[s]
		if (points[b] - points[a]).cross(middle - points[a]).dot(axis) > 0.0:
			var swap: int = a
			a = b
			b = swap
		for corner: Vector3 in [points[a], points[b], middle]:
			indices.append(points.size())
			points.append(corner)
			if with_normals:
				normals.append(axis)
		from.append_array([a, b, a])
	arrays[Mesh.ARRAY_VERTEX] = points
	if with_normals:
		arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	for k: int in Mesh.ARRAY_MAX:
		if k == Mesh.ARRAY_VERTEX or k == Mesh.ARRAY_NORMAL or k == Mesh.ARRAY_INDEX \
				or arrays[k] == null:
			continue
		arrays[k] = _grown(arrays[k], k, had, from)


## A vertex array of [param had] vertices with one more for each of
## [param from], copied from that vertex; a picture's coordinates off it.
static func _grown(values: Variant, kind: int, had: int, from: PackedInt32Array) -> Variant:
	if kind == Mesh.ARRAY_TEX_UV or kind == Mesh.ARRAY_TEX_UV2:
		var uv: PackedVector2Array = values
		for _n: int in from.size():
			uv.append(Vector2(-1.0, -1.0))
		return uv
	if values is PackedColorArray:
		var colours: PackedColorArray = values
		for v: int in from:
			colours.append(colours[v])
		return colours
	if values is PackedFloat32Array:
		var floats: PackedFloat32Array = values
		var stride: int = floats.size() / maxi(1, had)
		for v: int in from:
			for k: int in stride:
				floats.append(floats[v * stride + k])
		return floats
	if values is PackedInt32Array:
		var ints: PackedInt32Array = values
		var stride: int = ints.size() / maxi(1, had)
		for v: int in from:
			for k: int in stride:
				ints.append(ints[v * stride + k])
		return ints
	if values is PackedVector3Array:
		var vectors: PackedVector3Array = values
		for v: int in from:
			vectors.append(vectors[v])
		return vectors
	if values is PackedVector2Array:
		var pairs: PackedVector2Array = values
		for v: int in from:
			pairs.append(pairs[v])
		return pairs
	if values is PackedByteArray:
		var bytes: PackedByteArray = values
		var stride: int = bytes.size() / maxi(1, had)
		for v: int in from:
			for k: int in stride:
				bytes.append(bytes[v * stride + k])
		return bytes
	return values
