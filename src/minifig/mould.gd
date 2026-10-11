## A mould of one's own: a part's shape sculpted into another — a new
## hairstyle from a hair piece, a helmet with a crest, a club from a sword —
## with the part's connection exactly where it was.
##
## The shape is the part's own built mesh, welded into one surface of
## shared corners. Brushes push and pull it, smooth it, swell it, pinch
## it, flatten it or drag it about; a lattice of 27 handles bends the
## whole of it at once; with symmetry on, every change is made again on
## the other side of the part's middle. Corners can be made finer where a
## brush needs more of them.
##
## What a mould may not change is what joins it to anything: the socket a
## hair piece sits on the head's stud with, the 3.18 mm bar a hand closes
## on, a stud, a hole. Each corner has a lock, from 0 (free) to 1 (fixed),
## worked out once from where the part's connectors are and, for anything
## worn on the head, where the head is: the inside of a hair piece rests on
## the head and stays exactly as it was, the outside is free, and between
## them the lock fades over two LDU so a stroke near the edge does not
## tear. And nothing free may be pushed into the head: after every stroke
## a corner inside the head's shape is put back on its surface. The part's
## connectors are written into the file unchanged, so the mould sits,
## clutches and is held where the part did, and the checker counts it the
## same.
##
## The file is the sculpted triangles, the base part's connectors as
## `0 !BRICKWORKS CONNECTOR` lines and its creases as edge lines, built by
## [PartForge] like any changed part, and named bw-<part>-m<tag>.
##
## Corners are kept in the app's axes; LDraw's are written out.
class_name Mould
extends RefCounted

const AUTHOR := "Brickworks mould maker"
## The finest a brush makes the surface, in LDU, and the most triangles a
## mould may have: a file of about half a megabyte, which a browser builds
## in a few seconds.
const FINEST := 1.6
const MOST_TRIANGLES := 9000
## How thin a wall can be before it is marked: LEGO's own walls are 1.6
## mm; under 1 mm a moulding is fragile and fills badly.
const THIN := 2.5
## The lock fades to nothing over this many LDU beyond what it protects.
const FADE := 2.0

const TOOLS: Array[String] = ["pull", "push", "inflate", "smooth", "pinch", "flatten", "grab"]

## The part it was made from: its placement on a figure is this part's.
var base: String = ""
var name: String = ""
var category: String = ""
var positions := PackedVector3Array()
## Three corners a triangle, wound as LDraw winds them.
var triangles := PackedInt32Array()
var colors := PackedInt32Array()
var two_sided := PackedByteArray()
var locks := PackedFloat32Array()
var normals := PackedVector3Array()
var neighbours: Array[PackedInt32Array] = []
## The other side's corner, across the part's middle, or -1.
var mirrors := PackedInt32Array()
## Pairs of corners the base part keeps sharp.
var creases := PackedInt32Array()
## The base part's connectors, as [PartEditor.Shape] has them.
var connectors: Array = []
## Worn on a head: it may not be pushed into one.
var on_head: bool = false
## Where a hand closes on it: [point, direction] in the app's axes.
var grip: Array = []
## Per corner, how thick the wall is there, after [method walls].
var thickness := PackedFloat32Array()
## Where each corner was before any sculpting: how near the head it may
## come is measured from there.
var rest := PackedVector3Array()
## How near the head anything free may be pushed, in LDU.
const HEAD_MARGIN := 1.0

var _undo: Array = []
var _redo: Array = []
var _grab: Dictionary = {}
var _lattice_rest := PackedVector3Array()
var _lattice_at := PackedVector3Array()
var _lattice_box := AABB()
## Its triangles as the engine winds them, for picking, and a grid of them
## for how thick it is; remade when it changes (see Rays: the engine's own
## TriangleMesh did not always give the nearest hit).
var _faces := PackedVector3Array()
var _picker_stale: bool = true


# -- making one ------------------------------------------------------------------


## A mould of a part: its geometry welded, its locks worked out. Null when
## there is no geometry for it.
static func of_part(library: PartLibrary, part_id: String, slot: String = "") -> Mould:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if mesh == null or info == null:
		return null
	var mould := Mould.new()
	mould.base = part_id
	mould.name = Minifig._plain(info.name).trim_prefix("~").trim_prefix("=")
	mould.category = info.ldraw_category if info.custom else info.category
	var welded: Dictionary = {}
	for n: int in mesh.surfaces.size():
		var arrays: Array = mesh.surfaces[n].surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t: int in indices.size() / 3:
			# The engine's a, c, b is LDraw's a, b, c.
			var corners: Array[int] = []
			for k: int in [0, 2, 1]:
				var p: Vector3 = points[indices[t * 3 + k]]
				var key := Vector3i((p * 1000.0).round())
				if not welded.has(key):
					welded[key] = mould.positions.size()
					mould.positions.append(p)
				corners.append(welded[key])
			if corners[0] == corners[1] or corners[1] == corners[2] or corners[0] == corners[2]:
				continue
			mould.triangles.append_array(corners)
			mould.colors.append(mesh.surface_colors[n])
			mould.two_sided.append(mesh.surface_two_sided[n])
	var shape: PartEditor.Shape = PartEditor.shape_of(mesh)
	mould.connectors = shape.connectors.duplicate(true)
	for n: int in shape.lines.size() / 6:
		var a := Vector3(shape.lines[n * 6], -shape.lines[n * 6 + 1], -shape.lines[n * 6 + 2])
		var b := Vector3(shape.lines[n * 6 + 3], -shape.lines[n * 6 + 4], -shape.lines[n * 6 + 5])
		var ka := Vector3i((a * 1000.0).round())
		var kb := Vector3i((b * 1000.0).round())
		if welded.has(ka) and welded.has(kb):
			mould.creases.append_array([welded[ka], welded[kb]])
	var on_slot: String = slot if not slot.is_empty() else Minifig.slot_for(info)
	mould.on_head = on_slot in ["headwear", "hat_extra"]
	var held: Array = MinifigData.GRIPS.get(part_id, [])
	if on_slot in ["accessory", "accessory_left"] or not held.is_empty():
		if held.is_empty():
			held = [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]
		mould.grip = [Vector3(held[0], -held[1], -held[2]),
			Vector3(held[3], -held[4], -held[5]).normalized()]
	mould._settle()
	return mould


## A dome to wear on the head, from nothing: a cap round the head's top,
## its inside clear of the classic head by a few tenths of an LDU and its
## socket a hollow stud's, as a hair piece has. It stands for 3901 on a
## figure, so it sits where a hair piece sits.
static func dome() -> Mould:
	# (radius, height) round the outside from the top, the rim, and back up
	# the inside to the socket over the head's stud.
	var profile: Array[Vector2] = [
		Vector2(0.0, 8.0), Vector2(4.5, 7.6), Vector2(8.5, 6.5), Vector2(11.8, 4.5),
		Vector2(14.0, 1.5), Vector2(15.3, -2.0), Vector2(15.6, -6.0), Vector2(15.4, -10.0),
		Vector2(15.0, -14.0), Vector2(13.4, -14.0), Vector2(13.4, -9.0), Vector2(13.4, -4.5),
		Vector2(13.0, -2.6), Vector2(12.0, -1.2), Vector2(10.4, 0.3), Vector2(6.2, 0.3),
		Vector2(6.2, 4.0), Vector2(0.0, 4.0)]
	var mould: Mould = _turned(profile, 40)
	mould.base = "3901"
	mould.name = "Minifig Hair Dome"
	mould.category = "Minifig Headwear"
	mould.on_head = true
	# 3901's socket, where the head's stud goes in.
	mould.connectors = [["tube", "female", 0.0, -4.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]]
	mould._settle()
	return mould


## A club to hold, from nothing: a bar the hand closes on and a ball on
## its end. It stands for 3847 on a figure, so it is held as a sword is,
## its bar exactly where the sword's grip is.
static func club() -> Mould:
	var profile: Array[Vector2] = [Vector2(0.0, 33.0)]
	for n: int in range(1, 12):
		var angle: float = PI * n / 12.0
		profile.append(Vector2(sin(angle) * 9.0, 22.0 + cos(angle) * 11.0))
	profile.append_array([Vector2(4.0, 11.0), Vector2(4.0, 4.0), Vector2(4.0, -4.0),
		Vector2(4.0, -12.0), Vector2(4.0, -20.0), Vector2(3.4, -22.0), Vector2(0.0, -22.8)])
	var mould: Mould = _turned(profile, 24)
	mould.base = "3847"
	mould.name = "Minifig Club"
	mould.category = "Minifig Accessory"
	# The bar a hand closes on, as 3847's: LDraw y 4 to 16 at the grip.
	mould.connectors = [["shaft", "male", 0.0, -11.0, 0.0, 0.0, 1.0, 0.0, 33.0, 4.0]]
	mould.grip = [Vector3(0, -8, 0), Vector3(0, -1, 0)]
	mould._settle()
	return mould


## A surface turned round the Y axis from a profile of (radius, height)
## points, ends on the axis closed.
static func _turned(profile: Array[Vector2], around: int) -> Mould:
	var mould := Mould.new()
	var rings: Array = []
	for point: Vector2 in profile:
		var ring := PackedInt32Array()
		if point.x < 1e-6:
			ring.append(mould.positions.size())
			mould.positions.append(Vector3(0.0, point.y, 0.0))
		else:
			for n: int in around:
				var angle: float = TAU * n / around
				ring.append(mould.positions.size())
				mould.positions.append(Vector3(cos(angle) * point.x, point.y, sin(angle) * point.x))
		rings.append(ring)
	for r: int in rings.size() - 1:
		var a: PackedInt32Array = rings[r]
		var b: PackedInt32Array = rings[r + 1]
		for n: int in around:
			var m: int = (n + 1) % around
			if a.size() == 1:
				mould._add_triangle(a[0], b[m], b[n])
			elif b.size() == 1:
				mould._add_triangle(a[n], a[m], b[0])
			else:
				mould._add_triangle(a[n], a[m], b[m])
				mould._add_triangle(a[n], b[m], b[n])
	# Wound outward: the top of the surface faces up.
	var top: Vector3 = mould._face_normal(0)
	if top.y < 0.0:
		for t: int in mould.triangles.size() / 3:
			var keep: int = mould.triangles[t * 3 + 1]
			mould.triangles[t * 3 + 1] = mould.triangles[t * 3 + 2]
			mould.triangles[t * 3 + 2] = keep
	return mould


func _add_triangle(a: int, b: int, c: int) -> void:
	triangles.append_array([a, b, c])
	colors.append(Lbm.COLOR_INHERIT)
	two_sided.append(0)


## Everything worked out from the corners: neighbours, mirrors, normals,
## locks.
func _settle() -> void:
	_find_neighbours()
	_find_mirrors()
	recompute_normals()
	locks = PackedFloat32Array()
	locks.resize(positions.size())
	for v: int in positions.size():
		locks[v] = lock_at(positions[v], normals[v])
	if rest.size() != positions.size():
		var kept: int = rest.size()
		rest.resize(positions.size())
		for v: int in range(kept, positions.size()):
			rest[v] = positions[v]
	_picker_stale = true


func _find_neighbours() -> void:
	var sets: Array = []
	sets.resize(positions.size())
	for v: int in positions.size():
		sets[v] = {}
	for t: int in triangles.size() / 3:
		for k: int in 3:
			var a: int = triangles[t * 3 + k]
			var b: int = triangles[t * 3 + (k + 1) % 3]
			(sets[a] as Dictionary)[b] = true
			(sets[b] as Dictionary)[a] = true
	neighbours.clear()
	for v: int in positions.size():
		neighbours.append(PackedInt32Array((sets[v] as Dictionary).keys()))


func _find_mirrors() -> void:
	var at: Dictionary = {}
	for v: int in positions.size():
		at[Vector3i((positions[v] * 4.0).round())] = v
	mirrors = PackedInt32Array()
	mirrors.resize(positions.size())
	for v: int in positions.size():
		var p: Vector3 = positions[v]
		mirrors[v] = int(at.get(Vector3i((Vector3(-p.x, p.y, p.z) * 4.0).round()), -1))


func recompute_normals() -> void:
	normals = PackedVector3Array()
	normals.resize(positions.size())
	for t: int in triangles.size() / 3:
		var a: int = triangles[t * 3]
		var b: int = triangles[t * 3 + 1]
		var c: int = triangles[t * 3 + 2]
		var n: Vector3 = (positions[b] - positions[a]).cross(positions[c] - positions[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for v: int in normals.size():
		normals[v] = normals[v].normalized()


func _face_normal(t: int) -> Vector3:
	var a: Vector3 = positions[triangles[t * 3]]
	return (positions[triangles[t * 3 + 1]] - a).cross(positions[triangles[t * 3 + 2]] - a).normalized()


# -- what may not move -----------------------------------------------------------


## How fixed a point is, 0 to 1: inside what a connection needs it is 1,
## and the lock fades to 0 over [constant FADE] LDU beyond. [param normal]
## says which way the surface there faces: on a hair piece the inside,
## turned to the head and resting on it, is locked, and the outside a
## millimetre away is not.
func lock_at(p: Vector3, normal: Vector3 = Vector3.ZERO) -> float:
	var nearest: float = INF
	for c: Array in connectors:
		# The connectors are in LDraw's axes.
		var at := Vector3(float(c[2]), -float(c[3]), -float(c[4]))
		var axis := Vector3(float(c[5]), -float(c[6]), -float(c[7])).normalized()
		var kind: String = c[0]
		match kind:
			"stud":
				# A stud stands 4 LDU out of the part along its axis.
				nearest = minf(nearest, _cylinder(p, at - axis, at + axis * 4.5, 7.0))
			"tube":
				# A socket: its axis points out of the part, and a stud comes
				# in against it, 4 LDU deep.
				nearest = minf(nearest, _cylinder(p, at - axis * 0.5, at + axis * 4.5, 7.0))
			"shaft", "bore":
				var radius: float = float(c[9])
				if radius <= 6.0:
					nearest = minf(nearest, _cylinder(p, at, at + axis * float(c[8]), radius + 1.5))
			"pin", "pin_hole", "axle", "axle_hole", "clip", "bar", "ball", "socket":
				nearest = minf(nearest, _cylinder(p, at - axis * 6.0, at + axis * 6.0, 5.5))
	if not grip.is_empty():
		var point: Vector3 = grip[0]
		var along: Vector3 = grip[1]
		nearest = minf(nearest, _cylinder(p, point - along * 9.0, point + along * 9.0, 5.5))
	if on_head and normal.dot(head_outward(p)) < 0.35:
		nearest = minf(nearest, -head_depth(p) - HEAD_MARGIN)
	if nearest <= 0.0:
		return 1.0
	return clampf(1.0 - nearest / FADE, 0.0, 1.0)


## How far outside a cylinder of [param radius] round the segment [param a]
## to [param b] a point is: negative inside.
static func _cylinder(p: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	var along: Vector3 = b - a
	var length: float = along.length()
	if length < 1e-6:
		return p.distance_to(a) - radius
	var dir: Vector3 = along / length
	var t: float = (p - a).dot(dir)
	var across: float = (p - (a + dir * clampf(t, 0.0, length))).length()
	var outside_end: float = maxf(-t, t - length)
	if outside_end <= 0.0:
		return across - radius
	return maxf(across - radius, outside_end)


## How deep a point is inside the classic head (3626c), whose top is where
## anything worn on the head has its origin: positive inside, negative
## outside, roughly in LDU. Its cylinder is 13 LDU round from 24 under the
## origin to 4 under it, rounding in to 9.92 at the top (3626c: 12.62 at 2
## under, 11.54 at 1), with the 6 LDU stud standing 4 on top. A hair piece
## rests on all three: on the cylinder, on the top round the stud, and over
## the stud — 3901's inside is at 12.8 to 13.0.
static func head_depth(p: Vector3) -> float:
	var across: float = Vector2(p.x, p.z).length()
	var depth: float = -INF
	if p.y <= -4.0:
		depth = maxf(depth, minf(13.0 - across, p.y + 24.0))
	if p.y >= -4.0:
		var t: float = clampf((p.y + 4.0) / 4.0, 0.0, 1.0)
		depth = maxf(depth, minf(lerpf(13.0, 9.92, t * t) - across, -p.y))
	if p.y >= 0.0:
		depth = maxf(depth, minf(6.0 - across, 4.0 - p.y))
	return depth


## Which way is out of the head at a point near it: up over its top and
## its stud, straight out from its sides.
static func head_outward(p: Vector3) -> Vector3:
	var across := Vector3(p.x, 0.0, p.z)
	var r: float = across.length()
	var side: Vector3 = across / r if r > 1e-4 else Vector3(0, 0, 1)
	if p.y >= 0.0:
		# Over the head's top: the stud's side, or up.
		return side if r > 5.0 and r < 7.0 and p.y < 3.5 else Vector3.UP
	if p.y > -4.0:
		var t: float = (p.y + 4.0) / 4.0
		var cap: float = lerpf(13.0, 9.92, t * t)
		return Vector3.UP if r < cap - 0.5 else (side + Vector3.UP * t).normalized()
	return side


# -- sculpting -----------------------------------------------------------------


## Where a ray meets the surface: {"at", "normal"} or empty.
func pick(from: Vector3, toward: Vector3) -> Dictionary:
	_refresh_faces()
	var hit: Dictionary = Rays.nearest(_faces, from, toward)
	if hit.is_empty():
		return {}
	# Turned out of the part: LDraw's winding is the outside's.
	var t: int = hit["face"]
	var outward: Vector3 = _face_normal(t)
	return {"at": hit["position"], "normal": outward}


func _refresh_faces() -> void:
	if not _picker_stale and _faces.size() == triangles.size():
		return
	_faces.resize(triangles.size())
	for n: int in triangles.size():
		_faces[n] = positions[triangles[n]]
	_picker_stale = false


## Begin a stroke: one undo step from here to its end.
func begin() -> void:
	_undo.append(positions.duplicate())
	if _undo.size() > 40:
		_undo.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(positions.duplicate())
	positions = _undo.pop_back()
	_changed()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(positions.duplicate())
	positions = _redo.pop_back()
	_changed()
	return true


## One dab of a brush at a point of the surface: [param radius] in LDU,
## [param strength] 0 to 1. With [param symmetry], the same again on the
## other side of the middle. Returns how many corners moved.
func dab(tool: String, at: Vector3, normal: Vector3, radius: float, strength: float,
		symmetry: bool) -> int:
	var moved: int = _dab(tool, at, normal, radius, strength)
	if symmetry and absf(at.x) > radius * 0.1:
		moved += _dab(tool, Vector3(-at.x, at.y, at.z), Vector3(-normal.x, normal.y, normal.z),
			radius, strength)
	_keep_off_head()
	_changed()
	return moved


func _dab(tool: String, at: Vector3, normal: Vector3, radius: float, strength: float) -> int:
	var near := PackedInt32Array()
	var weight := PackedFloat32Array()
	var facing := Vector3.ZERO
	for v: int in positions.size():
		var d: float = positions[v].distance_to(at)
		if d >= radius:
			continue
		var w: float = 1.0 - d / radius
		w = w * w * (3.0 - 2.0 * w)
		near.append(v)
		weight.append(w)
		facing += normals[v] * w
	if near.is_empty():
		return 0
	facing = facing.normalized() if facing.length() > 1e-6 else normal
	var step: float = radius * 0.1 * strength
	var before: PackedVector3Array = positions.duplicate() if tool == "smooth" else PackedVector3Array()
	var moved: int = 0
	for n: int in near.size():
		var v: int = near[n]
		var free: float = weight[n] * (1.0 - locks[v])
		if free <= 0.0:
			continue
		var p: Vector3 = positions[v]
		match tool:
			"pull":
				p += facing * step * free
			"push":
				p -= facing * step * free
			"inflate":
				p += normals[v] * step * free
			"smooth":
				var mean := Vector3.ZERO
				for other: int in neighbours[v]:
					mean += before[other]
				if neighbours[v].size() > 0:
					mean /= neighbours[v].size()
					p = p.lerp(mean, clampf(free * strength, 0.0, 1.0))
			"pinch":
				var toward: Vector3 = at - p
				toward -= facing * toward.dot(facing)
				p += toward * 0.25 * free * strength
			"flatten":
				p -= facing * ((p - at).dot(facing)) * 0.5 * free * strength
		positions[v] = p
		moved += 1
	return moved


## Take hold of the surface round a point, to drag it.
func grab(at: Vector3, radius: float, symmetry: bool) -> void:
	begin()
	_grab = {"from": positions.duplicate(), "near": {}, "mirror": symmetry, "at": at}
	for v: int in positions.size():
		var d: float = positions[v].distance_to(at)
		var w: float = 0.0
		if d < radius:
			w = 1.0 - d / radius
			w = w * w * (3.0 - 2.0 * w)
		if symmetry:
			var m: float = positions[v].distance_to(Vector3(-at.x, at.y, at.z))
			if m < radius:
				var wm: float = 1.0 - m / radius
				wm = wm * wm * (3.0 - 2.0 * wm)
				if wm > w:
					w = -wm
		if w != 0.0:
			(_grab["near"] as Dictionary)[v] = w


## Drag what was taken hold of by [param by], in the app's axes.
func drag(by: Vector3) -> void:
	if _grab.is_empty():
		return
	var from: PackedVector3Array = _grab["from"]
	var near: Dictionary = _grab["near"]
	for v: int in near:
		var w: float = near[v]
		var move: Vector3 = by if w > 0.0 else Vector3(-by.x, by.y, by.z)
		positions[v] = from[v] + move * absf(w) * (1.0 - locks[v])
	_keep_off_head()
	_changed()


func let_go() -> void:
	_grab = {}


## Anything free pushed towards the head put back: no nearer it than
## [constant HEAD_MARGIN] LDU, or than it was to begin with — the head
## still fits, and the inside a hair piece rests on is not pushed through.
func _keep_off_head() -> void:
	if not on_head:
		return
	for v: int in positions.size():
		if locks[v] >= 1.0:
			continue
		var p: Vector3 = positions[v]
		var limit: float = maxf(-HEAD_MARGIN, head_depth(rest[v]))
		var depth: float = head_depth(p)
		if depth > limit + 1e-4:
			positions[v] = p + head_outward(p) * (depth - limit)


func _changed() -> void:
	recompute_normals()
	_picker_stale = true
	thickness = PackedFloat32Array()


# -- the lattice -------------------------------------------------------------------


## Start bending the whole part with a lattice of 3 x 3 x 3 handles round
## it. Returns the handles' places.
func lattice_begin() -> PackedVector3Array:
	begin()
	var box := AABB(positions[0], Vector3.ZERO)
	for p: Vector3 in positions:
		box = box.expand(p)
	_lattice_box = box.grow(2.0)
	_lattice_rest = positions.duplicate()
	_lattice_at = PackedVector3Array()
	for i: int in 3:
		for j: int in 3:
			for k: int in 3:
				_lattice_at.append(_lattice_box.position + _lattice_box.size * Vector3(i, j, k) * 0.5)
	return _lattice_at.duplicate()


func lattice_handles() -> PackedVector3Array:
	return _lattice_at.duplicate()


## Move handle [param index] to [param to]; with symmetry its mirror moves
## the mirrored way. The part follows, as far as its locks let it.
func lattice_move(index: int, to: Vector3, symmetry: bool) -> void:
	if _lattice_at.is_empty():
		return
	_lattice_at[index] = to
	if symmetry:
		var i: int = index / 9
		var other: int = (2 - i) * 9 + index % 9
		if other != index:
			_lattice_at[other] = Vector3(-to.x, to.y, to.z)
		else:
			_lattice_at[index].x = 0.0
	var rest: PackedVector3Array = PackedVector3Array()
	for i: int in 3:
		for j: int in 3:
			for k: int in 3:
				rest.append(_lattice_box.position + _lattice_box.size * Vector3(i, j, k) * 0.5)
	for v: int in positions.size():
		var s: Vector3 = (_lattice_rest[v] - _lattice_box.position) / _lattice_box.size
		var shift := Vector3.ZERO
		var bs: Array[float] = _bernstein(s.x)
		var bt: Array[float] = _bernstein(s.y)
		var bu: Array[float] = _bernstein(s.z)
		for i: int in 3:
			for j: int in 3:
				for k: int in 3:
					var n: int = i * 9 + j * 3 + k
					shift += (_lattice_at[n] - rest[n]) * (bs[i] * bt[j] * bu[k])
		positions[v] = _lattice_rest[v] + shift * (1.0 - locks[v])
	_keep_off_head()
	_changed()


static func _bernstein(t: float) -> Array[float]:
	return [(1.0 - t) * (1.0 - t), 2.0 * t * (1.0 - t), t * t]


func lattice_end() -> void:
	_lattice_at = PackedVector3Array()
	_lattice_rest = PackedVector3Array()


# -- finer -------------------------------------------------------------------------


## Split every edge longer than [param longest] LDU that is not locked at
## both ends, through its middle — the shape does not change, it only gets
## corners a brush can move — until none is, or the mould has as many
## triangles as it may. Returns how many triangles it has.
func refine(longest: float = FINEST * 2.0) -> int:
	begin()
	for _pass: int in 6:
		if triangles.size() / 3 >= MOST_TRIANGLES:
			break
		var middles: Dictionary = {}       ## Vector2i(a, b) low first -> new corner
		var budget: int = (MOST_TRIANGLES - triangles.size() / 3) / 3
		for t: int in triangles.size() / 3:
			if middles.size() >= budget:
				break
			for k: int in 3:
				var a: int = triangles[t * 3 + k]
				var b: int = triangles[t * 3 + (k + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if middles.has(key) or locks[a] >= 1.0 and locks[b] >= 1.0:
					continue
				if positions[a].distance_to(positions[b]) > longest:
					middles[key] = -1
		if middles.is_empty():
			break
		for key: Vector2i in middles:
			middles[key] = positions.size()
			positions.append((positions[key.x] + positions[key.y]) * 0.5)
		var old: PackedInt32Array = triangles
		var old_colors: PackedInt32Array = colors
		var old_sided: PackedByteArray = two_sided
		triangles = PackedInt32Array()
		colors = PackedInt32Array()
		two_sided = PackedByteArray()
		for t: int in old.size() / 3:
			var c: Array[int] = [old[t * 3], old[t * 3 + 1], old[t * 3 + 2]]
			var m: Array[int] = []
			for k: int in 3:
				var a: int = c[k]
				var b: int = c[(k + 1) % 3]
				m.append(int(middles.get(Vector2i(mini(a, b), maxi(a, b)), -1)))
			_split(c, m, old_colors[t], old_sided[t])
		# A crease split is two creases.
		var old_creases: PackedInt32Array = creases
		creases = PackedInt32Array()
		for n: int in old_creases.size() / 2:
			var a: int = old_creases[n * 2]
			var b: int = old_creases[n * 2 + 1]
			var mid: int = int(middles.get(Vector2i(mini(a, b), maxi(a, b)), -1))
			if mid >= 0:
				creases.append_array([a, mid, mid, b])
			else:
				creases.append_array([a, b])
		# The new corners' normals, locks and neighbours, before the next
		# pass reads them.
		_settle()
	_settle()
	return triangles.size() / 3


## One triangle with some of its edges split, as triangles: corners c,
## the middles of edges c0-c1, c1-c2, c2-c0 (or -1), in the same winding.
func _split(c: Array[int], m: Array[int], color: int, sided: int) -> void:
	var count: int = 0
	for value: int in m:
		if value >= 0:
			count += 1
	var add := func(a: int, b: int, d: int) -> void:
		triangles.append_array([a, b, d])
		colors.append(color)
		two_sided.append(sided)
	if count == 0:
		add.call(c[0], c[1], c[2])
	elif count == 3:
		add.call(c[0], m[0], m[2])
		add.call(m[0], c[1], m[1])
		add.call(m[2], m[1], c[2])
		add.call(m[0], m[1], m[2])
	else:
		# Turn it so the first split edge is c0-c1.
		var first: int = m.find(m.filter(func(value: int) -> bool: return value >= 0)[0])
		var cc: Array[int] = [c[first], c[(first + 1) % 3], c[(first + 2) % 3]]
		var mm: Array[int] = [m[first], m[(first + 1) % 3], m[(first + 2) % 3]]
		if count == 1:
			add.call(cc[0], mm[0], cc[2])
			add.call(mm[0], cc[1], cc[2])
		elif mm[1] >= 0:
			add.call(cc[0], mm[0], cc[2])
			add.call(mm[0], cc[1], mm[1])
			add.call(mm[0], mm[1], cc[2])
		else:
			add.call(cc[0], mm[0], mm[2])
			add.call(mm[0], cc[1], cc[2])
			add.call(mm[0], cc[2], mm[2])


# -- how thick it is ---------------------------------------------------------------


## Per corner, how far through the part it is, straight in: the wall's
## thickness there. Returns {"thinnest" (LDU), "thin" (share of corners
## under [constant THIN])}.
func walls() -> Dictionary:
	_refresh_faces()
	var grid := Rays.Grid.new(_faces, 4.0)
	thickness = PackedFloat32Array()
	thickness.resize(positions.size())
	var thin: int = 0
	var thinnest: float = INF
	var measured: int = 0
	for v: int in positions.size():
		var inward: Vector3 = -normals[v]
		var hit: Dictionary = grid.nearest(positions[v] + inward * 0.05, inward, 16.0)
		var depth: float = 99.0
		if not hit.is_empty():
			depth = (hit["position"] as Vector3).distance_to(positions[v])
		thickness[v] = depth
		if depth < 0.3:
			# The neighbouring face at a sharp inside corner, not a wall.
			continue
		measured += 1
		thinnest = minf(thinnest, depth)
		if depth < THIN:
			thin += 1
	return {"thinnest": thinnest if measured > 0 else 0.0,
		"thin": float(thin) / maxf(1.0, float(measured))}


# -- the file ----------------------------------------------------------------------


## A mould's id: the part it was made from and a tag from its shape.
func id_for() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	hashing.update(base.to_utf8_buffer())
	hashing.update(positions.to_byte_array())
	hashing.update(triangles.to_byte_array())
	var source: String = ""
	for n: int in base.length():
		var ch: String = base[n].to_lower()
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			source += ch
	return "bw-%s-m%s" % [source.left(10), hashing.finish().hex_encode().left(6)]


## The part file: the sculpted triangles, the base part's connectors as
## they were, its creases.
func text(id: String, title: String) -> String:
	var words: String = title.strip_edges().replace("\n", " ")
	var out := PackedStringArray()
	out.append("0 %s, Custom Mould %s" % [name, words if not words.is_empty() else id])
	out.append("0 Name: %s.dat" % id)
	out.append("0 Author: " + AUTHOR)
	out.append("0 !LDRAW_ORG Unofficial_Part")
	out.append("0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt")
	out.append("")
	out.append("0 BFC CERTIFY CCW")
	out.append("")
	out.append("0 !CATEGORY " + (category if not category.is_empty() else "Minifig Accessory"))
	out.append("0 !KEYWORDS Brickworks, custom mould")
	out.append("")
	out.append("%s from=%s triangles=%d" % [PartPrints.MOULDED_BY, base, triangles.size() / 3])
	out.append("0 // Sculpted in Brickworks from %s.dat of the LDraw Parts Library (CC BY 4.0)," % base)
	out.append("0 // its connectors kept exactly where the part has them.")
	out.append("")
	out.append("0 // Connectors, for programs that read them")
	for c: Array in connectors:
		var line: String = "0 %s CONNECTOR %s %s %s %s %s %s %s %s" % [PartEditor.CONNECTOR,
			c[0], c[1], PartEditor._n(c[2]), PartEditor._n(c[3]), PartEditor._n(c[4]),
			PartEditor._n(c[5]), PartEditor._n(c[6]), PartEditor._n(c[7])]
		if float(c[8]) > 0.0:
			line += " %s %s" % [PartEditor._n(c[8]), PartEditor._n(c[9])]
		out.append(line)
	out.append("")
	out.append("0 // Faces")
	var open: bool = false
	for t: int in triangles.size() / 3:
		var sided: bool = two_sided[t] == 1
		if sided and not open:
			out.append("0 BFC NOCLIP")
			open = true
		elif not sided and open:
			out.append("0 BFC CLIP")
			open = false
		var words_out := PackedStringArray(["3", str(colors[t])])
		for k: int in 3:
			var p: Vector3 = _ldraw(triangles[t * 3 + k])
			words_out.append_array([PartEditor._n(p.x), PartEditor._n(p.y), PartEditor._n(p.z)])
		out.append(" ".join(words_out))
	if open:
		out.append("0 BFC CLIP")
	out.append("0 // Edges")
	for n: int in creases.size() / 2:
		var a: Vector3 = _ldraw(creases[n * 2])
		var b: Vector3 = _ldraw(creases[n * 2 + 1])
		out.append("2 24 %s %s %s %s %s %s" % [PartEditor._n(a.x), PartEditor._n(a.y),
			PartEditor._n(a.z), PartEditor._n(b.x), PartEditor._n(b.y), PartEditor._n(b.z)])
	out.append("0")
	return "\n".join(out) + "\n"


## A corner in LDraw's axes, on the 64ths of an LDU a part's mesh is kept
## to: a corner the mould did not move comes out exactly as it went in.
func _ldraw(v: int) -> Vector3:
	var p: Vector3 = positions[v]
	return Vector3(snappedf(p.x, 1.0 / 64.0), snappedf(-p.y, 1.0 / 64.0),
		snappedf(-p.z, 1.0 / 64.0))


## Make the part, add it to the library and keep it: {"id", "problem"}.
func make(library: PartLibrary, title: String, keep: bool = true) -> Dictionary:
	var id: String = id_for()
	return CustomParts.add(library, text(id, title), id, keep)


# -- drawing it ----------------------------------------------------------------------


## The mould as one mesh to draw: its corners shaded by what is locked
## (blue) and, after [method walls], what is thin (red).
func mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var points := PackedVector3Array()
	var facing := PackedVector3Array()
	var shades := PackedColorArray()
	var order := PackedInt32Array()
	points = positions
	facing = normals
	shades.resize(positions.size())
	for v: int in positions.size():
		var shade := Color.WHITE
		if locks[v] > 0.0:
			shade = Color.WHITE.lerp(Color(0.55, 0.7, 1.0), locks[v])
		if thickness.size() == positions.size() and thickness[v] >= 0.3 and thickness[v] < THIN:
			shade = Color(1.0, 0.3, 0.25)
		shades[v] = shade
	order.resize(triangles.size())
	for t: int in triangles.size() / 3:
		order[t * 3] = triangles[t * 3]
		order[t * 3 + 1] = triangles[t * 3 + 2]
		order[t * 3 + 2] = triangles[t * 3 + 1]
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = facing
	arrays[Mesh.ARRAY_COLOR] = shades
	arrays[Mesh.ARRAY_INDEX] = order
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func triangle_count() -> int:
	return triangles.size() / 3
