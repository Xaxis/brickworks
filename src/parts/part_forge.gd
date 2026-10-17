## Building one LDraw part into the app's geometry, inside the app.
##
## The library's twenty-seven thousand parts are built ahead of time by
## tools/build_meshes.py, in Python, with numpy. A part made in the element
## maker cannot wait for that: a desktop build has no Python and a browser
## certainly does not. So this is the same conversion, step for step, in
## GDScript — tools/ldraw/geometry.py's flatten and compute_normals,
## meshfile.build and write, connectivity.extract, and occupancy's
## voxelise, remove_studs, fill_cavities, to_boxes and bottom_sockets — and
## it ends in the same .lbm bytes, which [Lbm] reads like any other part.
##
## "The same" is held to, not hoped for. src/dev/element_files_probe.gd
## builds every fixture both ways and compares the connectors, the boxes,
## the sockets, the cells and the bounds exactly; pipeline.json is what the
## Python made. Matching it means doing the arithmetic in the same order in
## 64-bit floats — Godot's Vector3 is 32-bit, so none is used here — and
## rounding halves to even, as Python's round() does. A Technic hole is
## as the pipeline has it too: its two faces merged into the one hole
## (connectivity._merge_half_holes) and its bore cleared through the cover
## (occupancy.holes and fill_cavities), because the maker makes Technic
## bricks; and so are a drawn hole, a bar's room for a clip and a cover
## past its box limit (occupancy.to_boxes, whose convex hull is found here
## exactly rather than by Qhull). What is still not here is the axle
## family, which the pipeline classifies from each primitive's own
## description.
##
## Primitives come from res://assets/ldraw/, the few the maker draws with,
## shipped with the app (CC BY 4.0, credited in docs/ATTRIBUTION.md), and
## from res://vendor/ldraw/ when a checkout has the whole library — which
## is what lets a part embedded in somebody else's model file build here —
## or, in an exported build, from every primitive it ships ([constant
## SHIPPED]).
class_name PartForge
extends RefCounted

const BUNDLED := "res://assets/ldraw/"
const LIBRARY := "res://vendor/ldraw/"
## LDraw's primitives, every one (p/ and its 8/ and 48/), which every export
## ships (tools/export.sh copies them from vendor/ldraw/p): what LDCad draws a
## flexible part's skin with and what most parts a model file carries are
## drawn from. A build has no vendor/, so without them the web and the
## desktop downloads could build neither, and showed a real set's hoses and
## its carried parts missing (docs/CADTASK.md).
const SHIPPED := "res://assets/ldraw/p/"
const COLOR_INHERIT := 16
const COLOR_EDGE := 24
const CELL := 2.0
const WELD_SCALE := 1000.0         ## geometry._WELD_SCALE
const NORMAL_SCALE := 4096.0       ## meshfile._NORMAL_SCALE
const I16_MAX := 32767
const STUD_RADIUS := 6.5           ## occupancy._STUD_RADIUS
const STUD_HEIGHT := 4.0
const MOST_BOXES := 64             ## occupancy.to_boxes(limit)
const CREASE_DEGREES := 45.0


## What came out: the .lbm bytes and what the catalogue says about them.
class Result extends RefCounted:
	var id: String = ""
	## Empty when the part built; otherwise why not, in words.
	var problem: String = ""
	var lbm: PackedByteArray = PackedByteArray()
	var mesh: Lbm.PartMesh = null
	var name: String = ""
	var category: String = ""
	var triangles: int = 0
	var bounds_min: PackedFloat64Array = PackedFloat64Array([0, 0, 0])
	var bounds_max: PackedFloat64Array = PackedFloat64Array([0, 0, 0])
	var connector_counts: Dictionary = {}
	## [kind, gender, x, y, z, ax, ay, az] in the app's axes, as written.
	var connectors: Array = []
	var boxes: Array = []
	var sockets: Array = []
	var cells: int = 0
	var missing: PackedStringArray = PackedStringArray()

	## The numbers tools/build_custom.py --summary writes, the same way.
	func summary() -> Dictionary:
		var joined: Array = []
		for c: Array in connectors:
			var row: Array = [c[0], c[1], [_r(c[2]), _r(c[3]), _r(c[4])],
				[_r(c[5]), _r(c[6]), _r(c[7])]]
			# A shaft's and a bore's length and radius, and not a hinge's.
			if c.size() > 8 and (c[0] == "shaft" or c[0] == "bore"):
				row.append_array([_r(c[8]), _r(c[9])])
			joined.append(row)
		joined.sort_custom(PartForge._before)
		var box_list: Array = boxes.duplicate(true)
		box_list.sort_custom(PartForge._before)
		var socket_list: Array = []
		for s: Array in sockets:
			socket_list.append([_r(s[0]), _r(s[1])])
		socket_list.sort_custom(PartForge._before)
		return {
			"bounds_min": [_r(bounds_min[0]), _r(bounds_min[1]), _r(bounds_min[2])],
			"bounds_max": [_r(bounds_max[0]), _r(bounds_max[1]), _r(bounds_max[2])],
			"triangles": triangles,
			"connectors": joined,
			"boxes": box_list,
			"sockets": socket_list,
			"cells": cells,
		}

	static func _r(value: float) -> float:
		return snappedf(value, 0.001) + 0.0


## Python's ordering of nested lists, for sorting the same way it does.
static func _before(a: Variant, b: Variant) -> bool:
	return _compare(a, b) < 0


static func _compare(a: Variant, b: Variant) -> int:
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		var x: Array = a
		var y: Array = b
		for n: int in mini(x.size(), y.size()):
			var c: int = _compare(x[n], y[n])
			if c != 0:
				return c
		return signi(x.size() - y.size())
	if typeof(a) == TYPE_STRING:
		return -1 if str(a) < str(b) else (1 if str(a) > str(b) else 0)
	var fa: float = float(a)
	var fb: float = float(b)
	return -1 if fa < fb else (1 if fa > fb else 0)


# -- reading LDraw ------------------------------------------------------------


## One parsed file: its header facts and its commands. A command is an
## Array: [0, keyword, tokens] for a meta line, [1, colour, matrix, file],
## [2, colour, p, q] for an edge, [3, colour, points] for a polygon.
class Source extends RefCounted:
	var name: String = ""
	var description: String = ""
	var category: String = ""
	var bfc_certified: bool = false
	var bfc_ccw: bool = true
	var commands: Array = []


## The files a build may draw on beyond the bundled ones: the other parts
## of a model file, by lowercase name.
var _given: Dictionary = {}
var _parsed: Dictionary = {}
## Whether a reference may resolve into vendor/ldraw. Off, a build has only
## what every build of the app ships, which is how the probe proves a made
## part builds on the web.
var _use_library: bool = true
## The bundled primitives are the same in every build, so they are parsed
## once, here, and nothing else is kept here.
static var _bundled: Dictionary = {}
## Parts are built on worker threads too (CustomParts.take_from).
static var _bundled_lock := Mutex.new()


static func normalise(name: String) -> String:
	return name.replace("\\", "/").strip_edges().to_lower()


func _source_for(name: String) -> Source:
	var key: String = normalise(name)
	if _parsed.has(key):
		return _parsed[key]
	if not _given.has(key):
		_bundled_lock.lock()
		var kept: Source = _bundled.get(key)
		_bundled_lock.unlock()
		if kept != null:
			return kept
	var text: String = ""
	var bundled: bool = false
	if _given.has(key):
		text = _given[key]
	elif FileAccess.file_exists(BUNDLED + key):
		text = FileAccess.get_file_as_string(BUNDLED + key)
		bundled = true
	elif _use_library:
		text = _read_library(key)
	if text.is_empty():
		_parsed[key] = null
		return null
	var source: Source = parse(text, key)
	_parsed[key] = source
	if bundled:
		_bundled_lock.lock()
		_bundled[key] = source
		_bundled_lock.unlock()
	return source


## Where a reference resolves in a checkout's LDraw library, in the order
## tools/ldraw/library.py searches: parts and their subparts, then the
## primitives; and in a build, which has no vendor/, the primitives it ships.
static func _read_library(key: String) -> String:
	var path: String = library_path(key)
	return FileAccess.get_file_as_string(path) if not path.is_empty() else ""


## The file [param key] (normalised) is in a checkout's LDraw library or a
## build's primitives, or "".
static func library_path(key: String) -> String:
	for path: String in [LIBRARY + "parts/" + key, LIBRARY + "p/" + key, SHIPPED + key]:
		if FileAccess.file_exists(path):
			return path
	return ""


## Parse a file's text. Unreadable lines are skipped, as every renderer
## does; the header is read from the type 0 lines before the first drawing
## command, as library._read_header does.
static func parse(text: String, name: String) -> Source:
	var source := Source.new()
	source.name = name
	var lines: PackedStringArray = text.split("\n")
	var first: bool = true
	var in_header: bool = true
	for raw: String in lines:
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		var tokens: PackedStringArray = line.split(" ", false)
		# LDraw separates by any whitespace; a tab survives a space split.
		if line.contains("\t"):
			tokens = line.replace("\t", " ").split(" ", false)
		if in_header:
			if not line.begins_with("0"):
				in_header = false
			else:
				var body: String = line.substr(1).strip_edges()
				if first:
					source.description = body
					first = false
				else:
					var upper: String = body.to_upper()
					if upper.begins_with("!CATEGORY"):
						source.category = body.substr(9).strip_edges()
					elif upper.begins_with("BFC"):
						var said: PackedStringArray = upper.split(" ", false).slice(1)
						if said.has("CERTIFY"):
							source.bfc_certified = true
							source.bfc_ccw = not said.has("CW")
						elif said.has("NOCERTIFY"):
							source.bfc_certified = false
		var command: Array = _command(tokens)
		if not command.is_empty():
			source.commands.append(command)
	if source.category.is_empty() and not source.description.is_empty():
		var head: PackedStringArray = source.description.lstrip("~_=").split(" ", false)
		source.category = head[0] if not head.is_empty() else ""
	return source


static func _command(tokens: PackedStringArray) -> Array:
	if tokens.is_empty() or not tokens[0].is_valid_int():
		return []
	match tokens[0].to_int():
		0:
			if tokens.size() < 2:
				return [0, "", PackedStringArray()]
			return [0, tokens[1].to_upper(), tokens.slice(2)]
		1:
			if tokens.size() < 15 or not tokens[1].is_valid_int():
				return []
			var v := PackedFloat64Array()
			for n: int in range(2, 14):
				v.append(_num(tokens[n]))
			# x y z then the row-major 3x3, stored as a b c d e f g h i x y z.
			var m := PackedFloat64Array([v[3], v[4], v[5], v[6], v[7], v[8],
				v[9], v[10], v[11], v[0], v[1], v[2]])
			return [1, tokens[1].to_int(), m, normalise(" ".join(tokens.slice(14)))]
		2:
			if tokens.size() < 8:
				return []
			return [2, tokens[1].to_int(), _points(tokens, 2, 2)]
		3:
			if tokens.size() < 11:
				return []
			return [3, tokens[1].to_int(), _points(tokens, 2, 3)]
		4:
			if tokens.size() < 14:
				return []
			return [3, tokens[1].to_int(), _points(tokens, 2, 4)]
	return []


static func _points(tokens: PackedStringArray, start: int, count: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for n: int in count * 3:
		out.append(_num(tokens[start + n]))
	return out


## Exact powers of ten, every one representable in a double.
static var _TENS: PackedFloat64Array = _tens()


static func _tens() -> PackedFloat64Array:
	var out := PackedFloat64Array([1.0])
	for _n: int in 22:
		out.append(out[out.size() - 1] * 10.0)
	return out


## A decimal as Python's float() reads it: correctly rounded. Godot's own
## parser need not be, and a last-bit difference in a coordinate can move
## a cell across a boundary. A short decimal is a whole number over a power
## of ten, both exact, and one division of exact values rounds correctly.
static func _num(token: String) -> float:
	var text: String = token.strip_edges()
	var negative: bool = text.begins_with("-")
	if negative or text.begins_with("+"):
		text = text.substr(1)
	if text.is_empty() or text.contains("e") or text.contains("E"):
		return token.to_float()
	var dot: int = text.find(".")
	var digits: String = text if dot < 0 else text.substr(0, dot) + text.substr(dot + 1)
	var places: int = 0 if dot < 0 else text.length() - dot - 1
	if digits.length() > 15 or places > 22 or not digits.is_valid_int():
		return token.to_float()
	var value: float = float(digits.to_int()) / _TENS[places]
	return -value if negative else value


# -- the matrix, as tools/ldraw/parser.py's Matrix ----------------------------


const IDENTITY: Array[float] = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]


## self @ o: o first, then self. The same products in the same order.
static func _compose(s: PackedFloat64Array, o: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([
		s[0] * o[0] + s[1] * o[3] + s[2] * o[6],
		s[0] * o[1] + s[1] * o[4] + s[2] * o[7],
		s[0] * o[2] + s[1] * o[5] + s[2] * o[8],
		s[3] * o[0] + s[4] * o[3] + s[5] * o[6],
		s[3] * o[1] + s[4] * o[4] + s[5] * o[7],
		s[3] * o[2] + s[4] * o[5] + s[5] * o[8],
		s[6] * o[0] + s[7] * o[3] + s[8] * o[6],
		s[6] * o[1] + s[7] * o[4] + s[8] * o[7],
		s[6] * o[2] + s[7] * o[5] + s[8] * o[8],
		s[0] * o[9] + s[1] * o[10] + s[2] * o[11] + s[9],
		s[3] * o[9] + s[4] * o[10] + s[5] * o[11] + s[10],
		s[6] * o[9] + s[7] * o[10] + s[8] * o[11] + s[11],
	])


static func _determinant(m: PackedFloat64Array) -> float:
	return (m[0] * (m[4] * m[8] - m[5] * m[7])
		- m[1] * (m[3] * m[8] - m[5] * m[6])
		+ m[2] * (m[3] * m[7] - m[4] * m[6]))


static func _point(m: PackedFloat64Array, x: float, y: float, z: float) -> PackedFloat64Array:
	return PackedFloat64Array([
		m[0] * x + m[1] * y + m[2] * z + m[9],
		m[3] * x + m[4] * y + m[5] * z + m[10],
		m[6] * x + m[7] * y + m[8] * z + m[11]])


## Python's round(): halves to even.
static func _rint(value: float) -> int:
	var low: float = floorf(value)
	var rest: float = value - low
	if rest > 0.5:
		return int(low) + 1
	if rest < 0.5:
		return int(low)
	return int(low) + (1 if posmod(int(low), 2) == 1 else 0)


static func _key(x: float, y: float, z: float) -> Vector3i:
	return Vector3i(_rint(x * WELD_SCALE), _rint(y * WELD_SCALE), _rint(z * WELD_SCALE))


# -- flattening, as geometry.flatten -----------------------------------------


## Triangles as flat arrays: 9 floats each, LDraw space; a colour and a
## two-sided flag per triangle.
var _tri := PackedFloat64Array()
var _tri_color := PackedInt32Array()
var _tri_two_sided := PackedByteArray()
## Crease segments: Vector3i -> { Vector3i: true }, smaller key first.
var _edges: Dictionary = {}
var _missing: Dictionary = {}


func _flatten(name: String) -> void:
	_walk(name, PackedFloat64Array(IDENTITY), COLOR_INHERIT, COLOR_EDGE,
		false, true, 0, {})


func _walk(name: String, transform: PackedFloat64Array, color: int, edge_color: int,
		invert: bool, culling: bool, depth: int, stack: Dictionary) -> void:
	if depth > 64 or stack.has(name):
		return
	var source: Source = _source_for(name)
	if source == null:
		_missing[name] = true
		return
	var local_culling: bool = culling and source.bfc_certified
	var winding_ccw: bool = source.bfc_ccw
	var invert_next: bool = false
	var inner: Dictionary = stack.duplicate()
	inner[name] = true
	for command: Array in source.commands:
		match int(command[0]):
			0:
				if command[1] != "BFC":
					continue
				var said: PackedStringArray = PackedStringArray()
				for word: String in command[2]:
					said.append(word.to_upper())
				if said.has("INVERTNEXT"):
					invert_next = true
				if said.has("CW"):
					winding_ccw = false
				elif said.has("CCW"):
					winding_ccw = true
				if said.has("NOCLIP"):
					local_culling = false
				elif said.has("CLIP"):
					local_culling = culling and source.bfc_certified
			1:
				var matrix: PackedFloat64Array = command[2]
				var child: PackedFloat64Array = _compose(transform, matrix)
				var child_invert: bool = (invert != invert_next) != (_determinant(matrix) < 0.0)
				_walk(command[3], child, _resolve_color(command[1], color, edge_color),
					edge_color, child_invert, local_culling, depth + 1, inner)
				invert_next = false
			2:
				var p: PackedFloat64Array = command[2]
				var a: PackedFloat64Array = _point(transform, p[0], p[1], p[2])
				var b: PackedFloat64Array = _point(transform, p[3], p[4], p[5])
				var ka: Vector3i = _key(a[0], a[1], a[2])
				var kb: Vector3i = _key(b[0], b[1], b[2])
				if ka != kb:
					var lo: Vector3i = ka if ka < kb else kb
					var hi: Vector3i = kb if ka < kb else ka
					if not _edges.has(lo):
						_edges[lo] = {}
					(_edges[lo] as Dictionary)[hi] = true
			3:
				var p: PackedFloat64Array = command[2]
				var points := PackedFloat64Array()
				for n: int in p.size() / 3:
					points.append_array(_point(transform, p[n * 3], p[n * 3 + 1], p[n * 3 + 2]))
				_add_polygon(points, _resolve_color(command[1], color, edge_color),
					(not winding_ccw) != invert, not local_culling)


static func _resolve_color(child: int, inherited: int, inherited_edge: int) -> int:
	if child == COLOR_INHERIT:
		return inherited
	if child == COLOR_EDGE:
		return inherited_edge
	return child


func _add_polygon(points: PackedFloat64Array, color: int, reverse: bool,
		two_sided: bool) -> void:
	var count: int = points.size() / 3
	var pts: Array[PackedFloat64Array] = []
	for n: int in count:
		pts.append(points.slice(n * 3, n * 3 + 3))
	if reverse:
		pts.reverse()
	if count == 3:
		_add_triangle(pts[0], pts[1], pts[2], color, two_sided)
		return
	var d02: float = _length(_sub(pts[2], pts[0]))
	var d13: float = _length(_sub(pts[3], pts[1]))
	if d02 <= d13:
		_add_triangle(pts[0], pts[1], pts[2], color, two_sided)
		_add_triangle(pts[0], pts[2], pts[3], color, two_sided)
	else:
		_add_triangle(pts[1], pts[2], pts[3], color, two_sided)
		_add_triangle(pts[1], pts[3], pts[0], color, two_sided)


func _add_triangle(a: PackedFloat64Array, b: PackedFloat64Array, c: PackedFloat64Array,
		color: int, two_sided: bool) -> void:
	if _length(_cross(_sub(b, a), _sub(c, a))) * 0.5 <= 1e-9:
		return
	_tri.append_array(a)
	_tri.append_array(b)
	_tri.append_array(c)
	_tri_color.append(color)
	_tri_two_sided.append(1 if two_sided else 0)


static func _sub(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[0] - b[0], a[1] - b[1], a[2] - b[2]])


static func _cross(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([
		a[1] * b[2] - a[2] * b[1],
		a[2] * b[0] - a[0] * b[2],
		a[0] * b[1] - a[1] * b[0]])


## Vec3.length() is x ** 0.5, which is pow and not sqrt; the two can
## differ in the last bit, so this is pow too.
static func _length(v: PackedFloat64Array) -> float:
	return pow(v[0] * v[0] + v[1] * v[1] + v[2] * v[2], 0.5)


func _corner(t: int, c: int) -> PackedFloat64Array:
	return _tri.slice(t * 9 + c * 3, t * 9 + c * 3 + 3)


# -- shading, as geometry.compute_normals ------------------------------------


## One normal per triangle corner, three floats each.
##
## Written for speed as well as for agreement: a 16 x 16 plate is 34,000
## triangles, and this took 1.3 s of a 2.9 s build when every face normal
## and every corner was a small array of its own. Scalars and flat packed
## arrays now, and the same arithmetic in the same order.
func _normals() -> PackedFloat64Array:
	var count: int = _tri_color.size()
	var cos_crease: float = cos(deg_to_rad(CREASE_DEGREES))
	var face := PackedFloat64Array()
	face.resize(count * 3)
	var areas := PackedFloat64Array()
	areas.resize(count)
	var keys: Array[Vector3i] = []
	keys.resize(count * 3)
	for t: int in count:
		var o: int = t * 9
		var ux: float = _tri[o + 3] - _tri[o]
		var uy: float = _tri[o + 4] - _tri[o + 1]
		var uz: float = _tri[o + 5] - _tri[o + 2]
		var vx: float = _tri[o + 6] - _tri[o]
		var vy: float = _tri[o + 7] - _tri[o + 1]
		var vz: float = _tri[o + 8] - _tri[o + 2]
		var nx: float = uy * vz - uz * vy
		var ny: float = uz * vx - ux * vz
		var nz: float = ux * vy - uy * vx
		var length: float = pow(nx * nx + ny * ny + nz * nz, 0.5)
		if length >= 1e-12:
			var inv: float = 1.0 / length
			face[t * 3] = nx * inv
			face[t * 3 + 1] = ny * inv
			face[t * 3 + 2] = nz * inv
		areas[t] = length * 0.5
		for c: int in 3:
			keys[t * 3 + c] = _key(_tri[o + c * 3], _tri[o + c * 3 + 1], _tri[o + c * 3 + 2])

	# Which triangles own each undirected welded edge: lo -> {hi -> [t]}.
	var by_edge: Dictionary = {}
	for t: int in count:
		for n: int in 3:
			var ka: Vector3i = keys[t * 3 + n]
			var kb: Vector3i = keys[t * 3 + (n + 1) % 3]
			if ka == kb:
				continue
			var lo: Vector3i = ka if ka < kb else kb
			var hi: Vector3i = kb if ka < kb else ka
			var row: Dictionary = by_edge.get(lo, {})
			if row.is_empty():
				by_edge[lo] = row
			var owners: Array = row.get(hi, [])
			if owners.is_empty():
				row[hi] = owners
			owners.append(t)

	var at_position: Dictionary = {}
	for corner: int in count * 3:
		var here: Array = at_position.get(keys[corner], [])
		if here.is_empty():
			at_position[keys[corner]] = here
		here.append(corner)

	var normals := PackedFloat64Array()
	normals.resize(count * 9)
	for position: Vector3i in at_position:
		var corners: Array = at_position[position]
		var size: int = corners.size()
		var members := PackedInt32Array()
		members.resize(size)
		var index_of: Dictionary = {}
		var parent := PackedInt32Array()
		parent.resize(size)
		for n: int in size:
			var t: int = int(corners[n]) / 3
			members[n] = t
			index_of[t] = n
			parent[n] = n
		for corner: int in corners:
			var t: int = corner / 3
			var c: int = corner % 3
			for step: int in [1, 2]:
				var other: Vector3i = keys[t * 3 + (c + step) % 3]
				if other == position:
					continue
				var lo: Vector3i = position if position < other else other
				var hi: Vector3i = other if position < other else position
				var creased: Dictionary = _edges.get(lo, {})
				if creased.has(hi):
					continue
				var row: Dictionary = by_edge.get(lo, {})
				for tj: int in row.get(hi, []):
					if tj == t or not index_of.has(tj):
						continue
					if face[t * 3] * face[tj * 3] + face[t * 3 + 1] * face[tj * 3 + 1] \
							+ face[t * 3 + 2] * face[tj * 3 + 2] < cos_crease:
						continue
					var ra: int = _find(parent, int(index_of[t]))
					var rb: int = _find(parent, int(index_of[tj]))
					if ra != rb:
						parent[rb] = ra
		# One sum per group, kept at its root's index: 0.0 + x is x, so
		# starting every sum at zero is what Python's Vec3(0, 0, 0) did.
		var sums := PackedFloat64Array()
		sums.resize(size * 3)
		for n: int in size:
			var root: int = _find(parent, n)
			var t: int = members[n]
			var area: float = areas[t]
			sums[root * 3] = sums[root * 3] + face[t * 3] * area
			sums[root * 3 + 1] = sums[root * 3 + 1] + face[t * 3 + 1] * area
			sums[root * 3 + 2] = sums[root * 3 + 2] + face[t * 3 + 2] * area
		for n: int in size:
			var corner: int = corners[n]
			var root: int = _find(parent, n)
			var x: float = sums[root * 3]
			var y: float = sums[root * 3 + 1]
			var z: float = sums[root * 3 + 2]
			var length: float = pow(x * x + y * y + z * z, 0.5)
			if length > 1e-12:
				var inv: float = 1.0 / length
				normals[corner * 3] = x * inv
				normals[corner * 3 + 1] = y * inv
				normals[corner * 3 + 2] = z * inv
			else:
				var t: int = corner / 3
				normals[corner * 3] = face[t * 3]
				normals[corner * 3 + 1] = face[t * 3 + 1]
				normals[corner * 3 + 2] = face[t * 3 + 2]
	return normals


static func _find(parent: PackedInt32Array, n: int) -> int:
	var at: int = n
	while parent[at] != at:
		parent[at] = parent[parent[at]]
		at = parent[at]
	return at


# -- connectors, as connectivity.extract -------------------------------------


## Primitive -> [kind, gender], the table connectivity.py registers.
const CONNECTORS: Dictionary = {
	"stud": ["stud", "male"], "stud2": ["stud", "male"], "stud2a": ["stud", "male"],
	"studa": ["stud", "male"], "stud26": ["stud", "male"], "studx": ["stud", "male"],
	"studxa": ["stud", "male"], "studp01": ["stud", "male"], "studel": ["stud", "male"],
	"studh": ["stud", "male"], "stud-logo": ["stud", "male"], "stud-logo2": ["stud", "male"],
	"stud-logo3": ["stud", "male"], "stud-logo4": ["stud", "male"],
	"stud-logo5": ["stud", "male"], "stud2-logo": ["stud", "male"],
	"stud2-logo2": ["stud", "male"], "stud2-logo3": ["stud", "male"],
	"stud2-logo4": ["stud", "male"], "stud2-logo5": ["stud", "male"],
	"stud5": ["stud", "male"], "stud6": ["stud", "male"], "stud6a": ["stud", "male"],
	"stud9": ["stud", "male"], "stud10": ["stud", "male"], "stud13": ["stud", "male"],
	"stud15": ["stud", "male"], "stud17": ["stud", "male"], "stud17a": ["stud", "male"],
	"stud2s": ["stud", "male"], "stud2s2": ["stud", "male"], "stud2s2e": ["stud", "male"],
	"hipstud": ["stud", "male"], "hipstuda": ["stud", "male"], "hipstudh": ["stud", "male"],
	"clikitsstud": ["stud", "male"], "stud14": ["stud", "male"], "stud19": ["stud", "male"],
	"stud20": ["stud", "male"], "stud24": ["stud", "male"], "primotop": ["stud", "male"],
	"stud3": ["tube", "female"], "stud3a": ["tube", "female"], "stud4": ["tube", "female"],
	"stud4a": ["tube", "female"], "stud4h": ["tube", "female"], "stud4o": ["tube", "female"],
	"stud4od": ["tube", "female"], "stud4oda": ["tube", "female"],
	"stud4s": ["tube", "female"], "stud4s2": ["tube", "female"],
	"stud12": ["tube", "female"], "stud16": ["tube", "female"], "stud16a": ["tube", "female"],
	"stud16od": ["tube", "female"], "stud18a": ["tube", "female"],
	"stud21a": ["tube", "female"], "stud22a": ["tube", "female"], "stud23": ["tube", "female"],
	"stud23d": ["tube", "female"], "stud25": ["tube", "female"], "stud7": ["tube", "female"],
	"stud7a": ["tube", "female"], "stud8": ["tube", "female"], "stud8a": ["tube", "female"],
	"stud8s2": ["tube", "female"], "stud11": ["tube", "female"], "stud27": ["tube", "female"],
	"stud27a": ["tube", "female"], "stud28": ["tube", "female"], "stud28a": ["tube", "female"],
	"primobot": ["tube", "female"],
	"ridge": ["ridge", "female"], "ridgea": ["ridge", "female"], "ridgee": ["ridge", "female"],
	"ridges": ["ridge", "female"], "ridgesu": ["ridge", "female"],
	"peghole": ["pin_hole", "neutral"], "peghole2": ["pin_hole", "neutral"],
	"peghole3": ["pin_hole", "neutral"], "peghole4": ["pin_hole", "neutral"],
	"peghole5": ["pin_hole", "neutral"], "peghole6": ["pin_hole", "neutral"],
	"connhole": ["pin_hole", "neutral"], "connhol2": ["pin_hole", "neutral"],
	"connhol3": ["pin_hole", "neutral"], "beamhole": ["pin_hole", "neutral"],
	"beamhol2": ["pin_hole", "neutral"],
	"connect": ["pin", "male"], "connect2": ["pin", "male"], "connect3": ["pin", "male"],
	"connect4": ["pin", "male"], "connect5": ["pin", "male"], "connect6": ["pin", "male"],
	"connect7": ["pin", "male"], "connect8": ["pin", "male"], "connect10": ["pin", "male"],
	"confric": ["pin", "male"], "confric2": ["pin", "male"], "confric3": ["pin", "male"],
	"confric4": ["pin", "male"], "confric5": ["pin", "male"], "confric6": ["pin", "male"],
	"confric10": ["pin", "male"], "confric11": ["pin", "male"], "confric12": ["pin", "male"],
	"clip1": ["clip", "female"], "clip2": ["clip", "female"], "clip3": ["clip", "female"],
	"clip4": ["clip", "female"], "clip5": ["clip", "female"], "clip6": ["clip", "female"],
	"clip7": ["clip", "female"], "clip8": ["clip", "female"], "clip9": ["clip", "female"],
	"clip10": ["clip", "female"], "clip11": ["clip", "female"], "clip12": ["clip", "female"],
	"clip13": ["clip", "female"], "clip14": ["clip", "female"], "clip15": ["clip", "female"],
	"clip16": ["clip", "female"],
	"joint8ball": ["ball", "male"], "joint8socket1": ["socket", "female"],
	"joint8socket2": ["socket", "female"], "joint8socket3": ["socket", "female"],
}

## Not here: the axle and axle-hole families, which connectivity.py
## classifies from each primitive's own description and only Technic parts
## draw with. A second copy of that list would drift, and nothing the maker
## makes has one. A part embedded from elsewhere that uses them builds
## without those connectors. So connectivity._without_axle_edges has
## nothing to drop here: the edge pieces it drops are axle-hole primitives.

## connectivity._UNDRAWN: holes a file draws without a hole primitive, in
## its own frame, [kind, position, axis]. 3648s02 is an eighth of the 24
## tooth gear's centre axle hole.
const UNDRAWN: Dictionary = {
	"3648s02": [["axle_hole", [0.0, 0.0, 0.0], [0.0, 0.0, 1.0]]],
}
## connectivity._BALL_SPHERE and BALL_RADIUS: a whole sphere a Joint-8
## ball's size drawn on its own, a towball, is a ball.
const BALL_SPHERE := "8-8sphe"
const BALL_RADIUS := 8.0
## connectivity._PLAIN_HOLES: parts whose Technic holes are plain cylinders.
const PLAIN_HOLES: Array[String] = ["3709b", "3738", "32001", "6542a", "6573", "4141",
	"73071"]
const PLAIN_HOLE_RADIUS := 6.0


func _connectors(name: String) -> Array:
	var found: Array = []
	_find_connectors(name, PackedFloat64Array(IDENTITY), found, 0, {})
	# A part changed from another's mesh says where its connectors are in
	# meta lines of its own (PartEditor), after whatever its primitives
	# give: connectivity.extract reads them the same way, in the same place.
	var said: Array = _said_connectors(name)
	var rounds_said: Array = []
	for c: Array in said:
		if Lbm.ROUNDS.has(str(c[0])):
			rounds_said.append(c)
		else:
			found.append(c.slice(0, 8))
	var seen: Dictionary = {}
	var unique: Array = []
	for c: Array in found:
		var key: String = "%s|%.2f|%.2f|%.2f|%.3f|%.3f|%.3f" % [c[0], c[2], c[3], c[4],
			c[5], c[6], c[7]]
		if seen.has(key):
			continue
		seen[key] = true
		unique.append(c)
	var round_ones: Array = _rounds(name)
	var merged: Array = _merge_half_holes(unique)
	merged.append_array(_plain_holes(_stem(name), round_ones, merged))
	merged.append_array(round_ones)
	merged.append_array(rounds_said)
	return merged


static func _stem(file: String) -> String:
	var stem: String = file.get_file()
	return stem.substr(0, stem.length() - 4) if stem.ends_with(".dat") else stem


## connectivity._plain_holes: a pin hole at the middle of each whole bore
## of a Technic hole's size, for a part in [constant PLAIN_HOLES], where it
## has no hole on that line already.
static func _plain_holes(stem: String, round_ones: Array, holes: Array) -> Array:
	var out: Array = []
	if not PLAIN_HOLES.has(stem):
		return out
	for bore: Array in round_ones:
		if bore[0] != "bore" or absf(float(bore[9]) - PLAIN_HOLE_RADIUS) > 0.1 \
				or float(bore[10]) < 0.99:
			continue
		var taken: bool = false
		for h: Array in holes:
			if HOLE_KINDS.has(str(h[0])) and _on_round(h, bore, 2.0):
				taken = true
				break
		if taken:
			continue
		var half: float = float(bore[8]) * 0.5
		out.append(["pin_hole", "neutral", float(bore[2]) + float(bore[5]) * half,
			float(bore[3]) + float(bore[6]) * half, float(bore[4]) + float(bore[7]) * half,
			bore[5], bore[6], bore[7]])
	return out


## connectivity._on_round: whether a connector lies on a round's line within
## its length, give or take slack, and its axis runs along it.
static func _on_round(c: Array, round_one: Array, slack: float) -> bool:
	var axis := PackedFloat64Array([c[5], c[6], c[7]])
	var way := PackedFloat64Array([round_one[5], round_one[6], round_one[7]])
	if absf(absf(_dot(axis, way)) - 1.0) > 0.01:
		return false
	var gap := PackedFloat64Array([float(c[2]) - float(round_one[2]),
		float(c[3]) - float(round_one[3]), float(c[4]) - float(round_one[4])])
	var along: float = _dot(gap, way)
	var across: PackedFloat64Array = _sub(gap, _scaled(way, along))
	return _length(across) <= 0.1 and -slack <= along \
		and along <= float(round_one[8]) + slack


## The connectors a part file states in `0 !BRICKWORKS CONNECTOR kind
## gender x y z ax ay az [length radius]` lines, in LDraw's axes, as
## [kind, gender, x, y, z, ax, ay, az] and a round's length and radius.
func _said_connectors(name: String) -> Array:
	var out: Array = []
	var source: Source = _source_for(name)
	if source == null:
		return out
	for command: Array in source.commands:
		if int(command[0]) != 0 or command[1] != PartEditor.CONNECTOR:
			continue
		var words: PackedStringArray = command[2]
		if words.size() < 9 or words[0].to_upper() != "CONNECTOR":
			continue
		var row: Array = [words[1], words[2]]
		for n: int in range(3, 9):
			row.append(_num(words[n]))
		if Lbm.ROUNDS.has(words[1]):
			if words.size() < 11:
				continue
			row.append(_num(words[9]))
			row.append(_num(words[10]))
		out.append(row)
	return out


# -- a hole's two faces, as connectivity._merge_half_holes -------------------


## connectivity.MERGE_WITHIN: how far apart two faces of one hole can be.
const MERGE_WITHIN := 44.0
const HOLE_KINDS: Array[String] = ["pin_hole", "axle_hole"]


## Collapse the two faces of a Technic hole into the one hole it is: two
## pegholes, one recessed into each face and pointing opposite ways, are
## one hole at their midpoint. Faces on the same axis line and within a
## brick of each other along it; the rest pass through, first, in order.
static func _merge_half_holes(connectors: Array) -> Array:
	var lines: Dictionary = {}   ## line key -> connectors on it, in order
	var passthrough: Array = []
	for c: Array in connectors:
		if not HOLE_KINDS.has(str(c[0])):
			passthrough.append(c)
			continue
		var key: String = _axis_line_key(c)
		if not lines.has(key):
			lines[key] = []
		(lines[key] as Array).append(c)
	var merged: Array = []
	for key: String in lines:
		for cluster: Array in _clusters_along(lines[key]):
			var count: float = float(cluster.size())
			var sx: float = 0.0
			var sy: float = 0.0
			var sz: float = 0.0
			for c: Array in cluster:
				sx += float(c[2])
				sy += float(c[3])
				sz += float(c[4])
			var first: Array = cluster[0]
			merged.append([first[0], first[1], sx / count, sy / count, sz / count,
				first[5], first[6], first[7]])
	return passthrough + merged


## The infinite line a connector's axis runs along: the axis to one sign,
## and the foot of the perpendicular from the origin.
static func _axis_line_key(c: Array) -> String:
	var ax: float = c[5]
	var ay: float = c[6]
	var az: float = c[7]
	for component: float in [ax, ay, az]:
		if absf(component) > 1e-6:
			if component < 0.0:
				ax = -ax
				ay = -ay
				az = -az
			break
	var along: float = float(c[2]) * ax + float(c[3]) * ay + float(c[4]) * az
	var fx: float = float(c[2]) - ax * along
	var fy: float = float(c[3]) - ay * along
	var fz: float = float(c[4]) - az * along
	# Rounded as Python's tuple of round()s compares, and -0 is 0 there.
	return "%s|%s|%s|%s|%s|%s|%s" % [c[0], _keyed(ax, 3), _keyed(ay, 3), _keyed(az, 3),
		_keyed(fx, 2), _keyed(fy, 2), _keyed(fz, 2)]


static func _keyed(value: float, places: int) -> String:
	var scale: float = pow(10.0, places)
	return str(_rint(value * scale))


## The faces on one line, split into the holes they describe: sorted along
## the line (stably, as Python's sort is), a new hole wherever the next
## face is more than [constant MERGE_WITHIN] past the last.
static func _clusters_along(group: Array) -> Array:
	if group.size() == 1:
		return [group]
	var first: Array = group[0]
	var axis: Array = [float(first[5]), float(first[6]), float(first[7])]
	var keyed: Array = []
	for n: int in group.size():
		var c: Array = group[n]
		keyed.append([float(c[2]) * axis[0] + float(c[3]) * axis[1]
			+ float(c[4]) * axis[2], n, c])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0])
			and int(a[1]) < int(b[1])))
	var clusters: Array = [[keyed[0][2]]]
	var last: float = keyed[0][0]
	for n: int in range(1, keyed.size()):
		if float(keyed[n][0]) - last <= MERGE_WITHIN:
			(clusters[-1] as Array).append(keyed[n][2])
		else:
			clusters.append([keyed[n][2]])
		last = keyed[n][0]
	return clusters


# -- shafts and bores, as connectivity.rounds --------------------------------
#
# A made round brick has a shaft (its wall) and a bore (its cavity) like the
# library's, and one embedded from a model file may have a bar or a clip, so
# these are found the same way here. Each round comes out as [kind, gender,
# x, y, z, ax, ay, az, length, radius] in LDraw's axes, start then a unit
# direction.

## connectivity._SURFACE: n-dcyli and n-dcyli2.
static var _surface := RegEx.create_from_string("^(\\d+)-(\\d+)cyli2?$")
const AXLE_SIDE: Array[String] = ["axle", "axlehol8"]
## connectivity._WALKED_INTO, kind -> [shafts kept, bores kept].
const WALKED_INTO: Dictionary = {
	"pin": [true, true], "clip": [false, true], "pin_hole": [false, true]}
## connectivity._CONTINUES.
const CONTINUES: Array[String] = ["stud", "tube", "ridge"]
const ROUND_ARC := 0.5         ## connectivity.ROUND_ARC
const ROUND_LENGTH := 1.0      ## connectivity.ROUND_LENGTH
const ROUND_WIDEST := 63.75    ## connectivity.ROUND_WIDEST
## connectivity._HINGES: a click hinge's finger or its half of a fork, by
## primitive, [kind, y, z] of the line it turns on; HINGE_RADIUS and
## HINGE_GAP as there.
const HINGES: Dictionary = {
	"clh1": ["finger", 0.0, -10.0], "clh2": ["finger", -7.0, 0.0],
	"clh3": ["finger", 0.0, -10.0], "clh6": ["finger", 0.0, -10.0],
	"clh6d": ["finger", 0.0, -10.0], "clh6u": ["finger", 0.0, -10.0],
	"clh8": ["finger", 0.0, -7.0], "clh9": ["finger", -7.0, 0.0],
	"clh12": ["finger", -7.0, 0.0], "clh13": ["finger", -7.0, 0.0],
	"clh15": ["finger", 0.0, -10.0],
	"clh4": ["fork", 0.0, 4.0], "clh5": ["fork", 0.0, 10.0], "clh7": ["fork", 0.0, 4.0],
	"clh10": ["fork", 0.0, 4.0], "clh11": ["fork", 0.0, 4.0], "clh14": ["fork", 0.0, 10.0],
}
const HINGE_RADIUS := 6.0
const HINGE_GAP := 3.0


func _rounds(name: String) -> Array:
	var pieces: Array = []
	_round_walk(name, PackedFloat64Array(IDENTITY), false, true, [true, true, false],
		pieces, 0, {})
	return _merge_rounds(pieces)


## A piece: [kind, radius, start, end, arc, continues], points as
## PackedFloat64Array.
func _round_walk(name: String, transform: PackedFloat64Array, invert: bool,
		certified: bool, keep: Array, found: Array, depth: int,
		stack: Dictionary) -> void:
	if depth > 64 or stack.has(name):
		return
	var source: Source = _source_for(name)
	if source == null:
		return
	var inner: Dictionary = stack.duplicate()
	inner[name] = true
	var sure: bool = certified and source.bfc_certified
	var invert_next: bool = false
	for command: Array in source.commands:
		if int(command[0]) == 0:
			if command[1] != "BFC":
				continue
			for word: String in command[2]:
				if word.to_upper() == "INVERTNEXT":
					invert_next = true
			continue
		if int(command[0]) != 1:
			continue
		var child: PackedFloat64Array = _compose(transform, command[2])
		# The INVERTNEXTs and not the mirror: see connectivity._round_walk.
		var child_invert: bool = invert != invert_next
		invert_next = false
		var file: String = command[3]
		var stem: String = file.get_file()
		if stem.ends_with(".dat"):
			stem = stem.substr(0, stem.length() - 4)
		if HINGES.has(stem):
			# A leaf: what it is drawn with is its teeth, not a round.
			_hinge_piece(found, stem, child)
			continue
		var surface: RegExMatch = _surface.search(stem)
		if surface != null:
			if sure and (bool(keep[1]) if child_invert else bool(keep[0])):
				var arc: float = float(surface.get_string(1)) / float(surface.get_string(2))
				_add_piece(found, child, child_invert, arc, 1.0, bool(keep[2]))
			continue
		if AXLE_SIDE.has(stem):
			if bool(keep[0]):
				_add_piece(found, child, false, 1.0, 6.0, bool(keep[2]))
			continue
		var below: Array = keep
		if CONNECTORS.has(stem):
			var kind: String = (CONNECTORS[stem] as Array)[0]
			if WALKED_INTO.has(kind):
				var kept: Array = WALKED_INTO[kind]
				below = [bool(keep[0]) and bool(kept[0]), bool(keep[1]) and bool(kept[1]),
					bool(keep[2])]
			elif CONTINUES.has(kind):
				below = [false, bool(keep[1]), true]
			else:
				continue
		_round_walk(file, child, child_invert, sure, below, found, depth + 1, inner)


static func _add_piece(found: Array, at: PackedFloat64Array, inward: bool, arc: float,
		scale: float, continues: bool) -> void:
	# transform_direction of the three unit vectors, term for term.
	var across := PackedFloat64Array([at[0] * 1.0 + at[1] * 0.0 + at[2] * 0.0,
		at[3] * 1.0 + at[4] * 0.0 + at[5] * 0.0, at[6] * 1.0 + at[7] * 0.0 + at[8] * 0.0])
	var along := PackedFloat64Array([at[0] * 0.0 + at[1] * 1.0 + at[2] * 0.0,
		at[3] * 0.0 + at[4] * 1.0 + at[5] * 0.0, at[6] * 0.0 + at[7] * 1.0 + at[8] * 0.0])
	var deep := PackedFloat64Array([at[0] * 0.0 + at[1] * 0.0 + at[2] * 1.0,
		at[3] * 0.0 + at[4] * 0.0 + at[5] * 1.0, at[6] * 0.0 + at[7] * 0.0 + at[8] * 1.0])
	var r1: float = _length(across)
	var r2: float = _length(deep)
	var length: float = _length(along)
	if length < 1e-6 or r1 < 1e-6 or r2 < 1e-6:
		return
	if absf(r1 - r2) > 0.02 * maxf(r1, r2):
		return
	if absf(_dot(across, deep)) > 0.01 * r1 * r2 \
			or absf(_dot(across, along)) > 0.01 * r1 * length \
			or absf(_dot(deep, along)) > 0.01 * r2 * length:
		return
	var start: PackedFloat64Array = _point(at, 0.0, 0.0, 0.0)
	var end := PackedFloat64Array([start[0] + along[0], start[1] + along[1],
		start[2] + along[2]])
	found.append(["bore" if inward else "shaft", scale * 0.5 * (r1 + r2), start, end,
		arc, continues])


## connectivity._hinge_piece: a click hinge's finger, or its half of a
## fork, as a length of round on the line it turns on.
static func _hinge_piece(found: Array, stem: String, at: PackedFloat64Array) -> void:
	var hinge: Array = HINGES[stem]
	var low: float = -HINGE_GAP if hinge[0] == "finger" else 0.0
	var start: PackedFloat64Array = _point(at, low, hinge[1], hinge[2])
	var end: PackedFloat64Array = _point(at, HINGE_GAP, hinge[1], hinge[2])
	if _length(_sub(end, start)) < 1e-6:
		return
	found.append([hinge[0], HINGE_RADIUS, start, end, 1.0, false])


static func _dot(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


static func _scaled(a: PackedFloat64Array, s: float) -> PackedFloat64Array:
	return PackedFloat64Array([a[0] * s, a[1] * s, a[2] * s])


static func _merge_rounds(pieces: Array) -> Array:
	## [kind, radius, way, foot, members]; a member is [low, high, piece, n].
	var lines: Array = []
	var order: int = 0
	for piece: Array in pieces:
		var start: PackedFloat64Array = piece[2]
		var end: PackedFloat64Array = piece[3]
		var span: PackedFloat64Array = _sub(end, start)
		var length: float = _length(span)
		var way: PackedFloat64Array = _scaled(span, 1.0 / length)
		for n: int in 3:
			if absf(way[n]) > 1e-6:
				if way[n] < 0:
					way = _scaled(way, -1.0)
					var swap: PackedFloat64Array = start
					start = end
					end = swap
				break
		var along: float = _dot(start, way)
		var foot: PackedFloat64Array = _sub(start, _scaled(way, along))
		var member: Array = [along, along + length, piece, order]
		order += 1
		var placed: bool = false
		for line: Array in lines:
			if line[0] == piece[0] and absf(float(line[1]) - float(piece[1])) <= 0.1 \
					and _dot(way, line[2]) >= 0.9999 \
					and _length(_sub(foot, line[3])) <= 0.1:
				(line[4] as Array).append(member)
				placed = true
				break
		if not placed:
			lines.append([piece[0], piece[1], way, foot, [member]])

	## [kind, radius, way, foot, low, high, continues only, arc].
	var found: Array = []
	for line: Array in lines:
		var members: Array = line[4]
		# Python's sort is stable; this one is told the original order.
		members.sort_custom(func(a: Array, b: Array) -> bool:
			return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[3]) < int(b[3])))
		var clusters: Array = [[members[0]]]
		var reach: float = members[0][1]
		for n: int in range(1, members.size()):
			var member: Array = members[n]
			if float(member[0]) <= reach + 0.5:
				(clusters[-1] as Array).append(member)
				reach = maxf(reach, float(member[1]))
			else:
				clusters.append([member])
				reach = float(member[1])
		for cluster: Array in clusters:
			var low: float = INF
			var high: float = -INF
			for m: Array in cluster:
				low = minf(low, float(m[0]))
				high = maxf(high, float(m[1]))
			var arc: float = -INF
			for p: Array in cluster:
				var total: float = 0.0
				for q: Array in cluster:
					if minf(float(p[1]), float(q[1])) - maxf(float(p[0]), float(q[0])) > 0.01:
						total += float((q[2] as Array)[4])
				arc = maxf(arc, total)
			if minf(arc, 1.0) < ROUND_ARC or high - low < ROUND_LENGTH:
				continue
			var radius: float = 0.0
			var continues: bool = true
			for m: Array in cluster:
				radius += float((m[2] as Array)[1])
				continues = continues and bool((m[2] as Array)[5])
			found.append([line[0], radius / cluster.size(), line[2], line[3], low, high,
				continues, minf(arc, 1.0)])

	var out: Array = []
	for f: Array in found:
		if bool(f[6]):
			var carried: bool = false
			for other: Array in found:
				if not bool(other[6]) and other[0] == "bore" \
						and absf(_dot(f[2], other[2])) >= 0.9999 \
						and _length(_sub(f[3], other[3])) <= 0.1 \
						and float(other[4]) <= float(f[5]) + 0.5 \
						and float(f[4]) <= float(other[5]) + 0.5:
					carried = true
					break
			if not carried:
				continue
		if float(f[1]) > ROUND_WIDEST:
			continue
		var way: PackedFloat64Array = f[2]
		var at: PackedFloat64Array = _add(f[3], _scaled(way, float(f[4])))
		# How far round it goes rides along after the radius, for
		# occupancy.holes; nothing written carries it.
		out.append([f[0], "male" if f[0] == "shaft" or f[0] == "finger" else "female",
			at[0], at[1], at[2], way[0], way[1], way[2], float(f[5]) - float(f[4]), f[1],
			f[7]])
	return out


static func _add(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[0] + b[0], a[1] + b[1], a[2] + b[2]])


func _find_connectors(name: String, transform: PackedFloat64Array, found: Array,
		depth: int, stack: Dictionary) -> void:
	if depth > 64 or stack.has(name):
		return
	var source: Source = _source_for(name)
	if source == null:
		return
	var inner: Dictionary = stack.duplicate()
	inner[name] = true
	for undrawn: Array in UNDRAWN.get(_stem(name), []):
		var at: Array = undrawn[1]
		var way: Array = undrawn[2]
		var axis := PackedFloat64Array([
			transform[0] * way[0] + transform[1] * way[1] + transform[2] * way[2],
			transform[3] * way[0] + transform[4] * way[1] + transform[5] * way[2],
			transform[6] * way[0] + transform[7] * way[1] + transform[8] * way[2]])
		var inv: float = 1.0 / maxf(_length(axis), 1e-9)
		var point: PackedFloat64Array = _point(transform, at[0], at[1], at[2])
		found.append([undrawn[0], "neutral", point[0], point[1], point[2],
			axis[0] * inv, axis[1] * inv, axis[2] * inv])
	# Whether the reference is inside out, for a sphere: any meta line but
	# an INVERTNEXT clears it, as connectivity._walk has it.
	var inverted: bool = false
	for command: Array in source.commands:
		if int(command[0]) == 0:
			inverted = false
			if command[1] == "BFC":
				for word: String in command[2]:
					if word.to_upper() == "INVERTNEXT":
						inverted = true
			continue
		if int(command[0]) != 1:
			continue
		var inward: bool = inverted
		inverted = false
		var file: String = command[3]
		var stem: String = file.get_file()
		if stem.ends_with(".dat"):
			stem = stem.substr(0, stem.length() - 4)
		var child: PackedFloat64Array = _compose(transform, command[2])
		if stem == BALL_SPHERE:
			var ball: Array = _ball(child, inward)
			if not ball.is_empty():
				found.append(ball)
			continue
		if CONNECTORS.has(stem):
			var entry: Array = CONNECTORS[stem]
			# transform_direction((0, -1, 0)), term for term: a*0 + b*-1 +
			# c*0, so that a zero comes out with the sign Python's has.
			var ax: float = child[0] * 0.0 + child[1] * -1.0 + child[2] * 0.0
			var ay: float = child[3] * 0.0 + child[4] * -1.0 + child[5] * 0.0
			var az: float = child[6] * 0.0 + child[7] * -1.0 + child[8] * 0.0
			var length: float = pow(ax * ax + ay * ay + az * az, 0.5)
			if length > 1e-9:
				var inv: float = 1.0 / length
				ax *= inv
				ay *= inv
				az *= inv
			var at: PackedFloat64Array = _point(child, 0.0, 0.0, 0.0)
			found.append([entry[0], entry[1], at[0], at[1], at[2], ax, ay, az])
			continue
		_find_connectors(file, child, found, depth + 1, inner)


## connectivity._ball: a ball where a whole sphere of a ball's size is drawn
## facing out. One drawn inside out is a cavity, not a ball.
static func _ball(at: PackedFloat64Array, inward: bool) -> Array:
	if inward:
		return []
	var radii: Array[float] = [_length(PackedFloat64Array([at[0], at[3], at[6]])),
		_length(PackedFloat64Array([at[1], at[4], at[7]])),
		_length(PackedFloat64Array([at[2], at[5], at[8]]))]
	if radii.max() - radii.min() > 0.1 or absf(radii[0] - BALL_RADIUS) > 0.5:
		return []
	var ax: float = at[0] * 0.0 + at[1] * -1.0 + at[2] * 0.0
	var ay: float = at[3] * 0.0 + at[4] * -1.0 + at[5] * 0.0
	var az: float = at[6] * 0.0 + at[7] * -1.0 + at[8] * 0.0
	var inv: float = 1.0 / maxf(pow(ax * ax + ay * ay + az * az, 0.5), 1e-9)
	var point: PackedFloat64Array = _point(at, 0.0, 0.0, 0.0)
	return ["ball", "male", point[0], point[1], point[2], ax * inv, ay * inv, az * inv]


# -- the mesh, as meshfile.build and write -----------------------------------


class Surface extends RefCounted:
	var color: int
	var two_sided: bool
	var positions := PackedFloat64Array()
	var normals := PackedFloat64Array()
	var indices := PackedInt32Array()
	## Welded position -> { welded normal -> index }: meshfile.build's
	## six-number key, in two halves, because formatting it as a string
	## was a sixth of the whole build.
	var lookup: Dictionary = {}


func _surfaces(normals: PackedFloat64Array) -> Array:
	var groups: Dictionary = {}
	var order: Array = []
	for t: int in _tri_color.size():
		var key: int = _tri_color[t] * 2 + _tri_two_sided[t]
		var surface: Surface = groups.get(key)
		if surface == null:
			surface = Surface.new()
			surface.color = _tri_color[t]
			surface.two_sided = _tri_two_sided[t] == 1
			groups[key] = surface
			order.append(surface)
		# Written a, c, b — the winding the engine wants — each corner with
		# its own normal.
		for ci: int in [0, 2, 1]:
			var o: int = t * 9 + ci * 3
			var ni: int = (t * 3 + ci) * 3
			var px: float = _tri[o]
			var py: float = -_tri[o + 1]
			var pz: float = -_tri[o + 2]
			var nx: float = normals[ni]
			var ny: float = -normals[ni + 1]
			var nz: float = -normals[ni + 2]
			var at := Vector3i(_rint(px * WELD_SCALE), _rint(py * WELD_SCALE),
				_rint(pz * WELD_SCALE))
			var facing := Vector3i(_rint(nx * NORMAL_SCALE), _rint(ny * NORMAL_SCALE),
				_rint(nz * NORMAL_SCALE))
			var there: Dictionary = surface.lookup.get(at, {})
			if there.is_empty():
				surface.lookup[at] = there
			var index: int = there.get(facing, -1)
			if index < 0:
				index = surface.positions.size() / 3
				there[facing] = index
				surface.positions.append(px)
				surface.positions.append(py)
				surface.positions.append(pz)
				surface.normals.append(nx)
				surface.normals.append(ny)
				surface.normals.append(nz)
			surface.indices.append(index)
	# The recolourable surface first, then by colour, then one-sided first.
	order.sort_custom(func(a: Surface, b: Surface) -> bool:
		var ka: Array = [1 if a.color != COLOR_INHERIT else 0, a.color, 1 if a.two_sided else 0]
		var kb: Array = [1 if b.color != COLOR_INHERIT else 0, b.color, 1 if b.two_sided else 0]
		return PartForge._compare(ka, kb) < 0)
	return order


static func _oct_encode(x: float, y: float, z: float) -> Vector2i:
	var total: float = absf(x) + absf(y) + absf(z)
	if total < 1e-12:
		return Vector2i.ZERO
	x = x / total
	y = y / total
	z = z / total
	if z < 0.0:
		var fx: float = (1.0 - absf(y)) * (1.0 if x >= 0.0 else -1.0)
		var fy: float = (1.0 - absf(x)) * (1.0 if y >= 0.0 else -1.0)
		x = fx
		y = fy
	return Vector2i(clampi(_rint(x * I16_MAX), -I16_MAX, I16_MAX),
		clampi(_rint(y * I16_MAX), -I16_MAX, I16_MAX))


static func _choose_scale(lo: PackedFloat64Array, hi: PackedFloat64Array) -> float:
	var extent: float = 1e-6
	for n: int in 3:
		extent = maxf(extent, maxf(absf(lo[n]), absf(hi[n])))
	for scale: float in [64.0, 16.0, 4.0, 1.0]:
		if extent * scale <= I16_MAX:
			return scale
	return 1.0


## The .lbm bytes, laid out as meshfile.write lays them out.
static func encode(surfaces: Array, lo: PackedFloat64Array, hi: PackedFloat64Array,
		connectors: Array, boxes: Array, sockets: Array) -> PackedByteArray:
	var scale: float = _choose_scale(lo, hi)
	var out := PackedByteArray()
	var flags: int = 0
	for s: Surface in surfaces:
		if s.two_sided:
			flags = 1
	out.resize(44)
	out.encode_u32(0, Lbm.MAGIC)
	out.encode_u16(4, flags)
	out.encode_u16(6, surfaces.size())
	out.encode_float(8, scale)
	for n: int in 3:
		out.encode_float(12 + n * 4, lo[n])
		out.encode_float(24 + n * 4, hi[n])
	out.encode_u16(36, connectors.size())
	out.encode_u16(38, boxes.size())
	out.encode_u16(40, sockets.size())
	out.encode_u16(42, int(round(CELL * 16.0)))
	for s: Surface in surfaces:
		var count: int = s.positions.size() / 3
		var head := PackedByteArray()
		head.resize(12)
		head.encode_s16(0, s.color)
		head.encode_u16(2, 1 if s.two_sided else 0)
		head.encode_u32(4, count)
		head.encode_u32(8, s.indices.size())
		out.append_array(head)
		var body := PackedByteArray()
		body.resize(count * 10)
		for v: int in count:
			body.encode_s16(v * 10, _quantise(s.positions[v * 3], scale))
			body.encode_s16(v * 10 + 2, _quantise(s.positions[v * 3 + 1], scale))
			body.encode_s16(v * 10 + 4, _quantise(s.positions[v * 3 + 2], scale))
			var n: Vector2i = _oct_encode(s.normals[v * 3], s.normals[v * 3 + 1],
				s.normals[v * 3 + 2])
			body.encode_s16(v * 10 + 6, n.x)
			body.encode_s16(v * 10 + 8, n.y)
		out.append_array(body)
		var wide: bool = count > 0xFFFF
		var index_bytes := PackedByteArray()
		index_bytes.resize(s.indices.size() * (4 if wide else 2))
		for i: int in s.indices.size():
			if wide:
				index_bytes.encode_u32(i * 4, s.indices[i])
			else:
				index_bytes.encode_u16(i * 2, s.indices[i])
		out.append_array(index_bytes)
	for c: Array in connectors:
		var row := PackedByteArray()
		row.resize(26)
		var kind: int = Lbm.KINDS.find(str(c[0]))
		var gender: int = Lbm.GENDERS.find(str(c[1]))
		row.encode_u8(0, kind if kind >= 0 else 255)
		# A round's gender byte is its radius, and its axis runs its length:
		# meshfile.write.
		var is_round: bool = Lbm.ROUNDS.has(str(c[0]))
		if is_round:
			gender = clampi(_rint(float(c[9]) * Lbm.ROUND_STEPS), 0, 255)
		row.encode_u8(1, gender if gender >= 0 else 255)
		for n: int in 3:
			row.encode_float(2 + n * 4, float(c[2 + n]))
		for n: int in 3:
			row.encode_float(14 + n * 4,
				float(c[5 + n]) * float(c[8]) if is_round else float(c[5 + n]))
		out.append_array(row)
	for b: Array in boxes:
		var row := PackedByteArray()
		row.resize(12)
		for n: int in 6:
			row.encode_s16(n * 2, int(b[n]))
		out.append_array(row)
	for s: Array in sockets:
		var row := PackedByteArray()
		row.resize(8)
		row.encode_float(0, float(s[0]))
		row.encode_float(4, float(s[1]))
		out.append_array(row)
	return out


static func _quantise(value: float, scale: float) -> int:
	return clampi(_rint(value * scale), -I16_MAX, I16_MAX)


# -- occupancy, as occupancy.voxelise and the rest ------------------------------


## A grid of cells in the app's axes: origin and shape in whole cells, one
## byte per cell, x slowest then y then z, as numpy lays (x, y, z) out.
class Grid extends RefCounted:
	var origin := Vector3i.ZERO
	var shape := Vector3i.ZERO
	var bits := PackedByteArray()

	func at(x: int, y: int, z: int) -> int:
		return bits[(x * shape.y + y) * shape.z + z]

	func put(x: int, y: int, z: int, v: int) -> void:
		bits[(x * shape.y + y) * shape.z + z] = v

	func count() -> int:
		return bits.count(1)

	func copy() -> Grid:
		var out := Grid.new()
		out.origin = origin
		out.shape = shape
		out.bits = bits.duplicate()
		return out


## occupancy.TIE: how far a column's ray is moved off its cell's middle to
## tell which side of a face the middle is on, LDU.
const TIE := 1.3e-4


## occupancy.voxelise. A ray up each column, and then, in the columns whose
## middles are on an edge in plan, the ray moved a hair each way along x
## and each way along z: what both moves along one of them agree on is
## kept. On a face square to z the moves along x agree, on one square to x
## the moves along z do, and on an upright face slanted in plan neither
## does, so a cell there is inside neither part meeting on it.
func _voxelise() -> Grid:
	var grid := Grid.new()
	var count: int = _tri_color.size()
	if count == 0:
		return grid
	# Into the application's axes, +Y up.
	var app := PackedFloat64Array()
	app.resize(_tri.size())
	var lo := PackedFloat64Array([INF, INF, INF])
	var hi := PackedFloat64Array([-INF, -INF, -INF])
	for v: int in _tri.size() / 3:
		var p: Array[float] = [_tri[v * 3], -_tri[v * 3 + 1], -_tri[v * 3 + 2]]
		for n: int in 3:
			app[v * 3 + n] = p[n]
			lo[n] = minf(lo[n], p[n])
			hi[n] = maxf(hi[n], p[n])
	var origin := Vector3i(int(floor(lo[0] / CELL + 1e-9)), int(floor(lo[1] / CELL + 1e-9)),
		int(floor(lo[2] / CELL + 1e-9)))
	var extent := Vector3i(int(ceil(hi[0] / CELL - 1e-9)), int(ceil(hi[1] / CELL - 1e-9)),
		int(ceil(hi[2] / CELL - 1e-9))) - origin
	grid.origin = origin
	grid.shape = Vector3i(maxi(1, extent.x), maxi(1, extent.y), maxi(1, extent.z))
	var stabbed: Array = _stab(app, grid.origin, grid.shape, 0.0, 0.0, PackedByteArray())
	grid.bits = stabbed[0]
	var touchy: PackedByteArray = stabbed[1]
	if not touchy.has(1):
		return grid
	var moved: Array[PackedByteArray] = []
	for step: Array in [[TIE, 0.0], [-TIE, 0.0], [0.0, TIE], [0.0, -TIE]]:
		moved.append(_stab(app, grid.origin, grid.shape, step[0], step[1], touchy)[0])
	var s: Vector3i = grid.shape
	for i: int in s.x:
		for k: int in s.z:
			if touchy[i * s.z + k] == 0:
				continue
			for j: int in s.y:
				var n: int = (i * s.y + j) * s.z + k
				var agreed: bool = (moved[0][n] == 1 and moved[1][n] == 1) \
					or (moved[2][n] == 1 and moved[3][n] == 1)
				grid.bits[n] = 1 if agreed else 0
	return grid


## occupancy._stab: [the cells inside by a ray up each column, dx and dz LDU
## off its middle; the columns (x * sz + z) whose rays are within TIE of an
## edge of a triangle in plan]. Given columns, only those are stabbed.
static func _stab(app: PackedFloat64Array, origin: Vector3i, shape: Vector3i, dx: float,
		dz: float, columns: PackedByteArray) -> Array:
	var every: bool = columns.is_empty()
	var xs := PackedFloat64Array()
	for i: int in shape.x:
		xs.append((float(i + origin.x) + 0.5) * CELL + dx)
	var zs := PackedFloat64Array()
	for k: int in shape.z:
		zs.append((float(k + origin.z) + 0.5) * CELL + dz)
	var touchy := PackedByteArray()
	touchy.resize(shape.x * shape.z)

	var crossings: Dictionary = {}   ## column index -> Array of [y, direction]
	for t: int in app.size() / 9:
		var o: int = t * 9
		var ax: float = app[o]
		var ay: float = app[o + 1]
		var az: float = app[o + 2]
		var bx: float = app[o + 3]
		var by: float = app[o + 4]
		var bz: float = app[o + 5]
		var cx: float = app[o + 6]
		var cy: float = app[o + 7]
		var cz: float = app[o + 8]
		var area2: float = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
		if absf(area2) < 1e-12:
			continue
		var x0: float = minf(ax, minf(bx, cx))
		var x1: float = maxf(ax, maxf(bx, cx))
		var z0: float = minf(az, minf(bz, cz))
		var z1: float = maxf(az, maxf(bz, cz))
		var i0: int = maxi(0, int(floor(x0 / CELL)) - origin.x)
		var i1: int = mini(shape.x - 1, int(ceil(x1 / CELL)) - origin.x)
		var k0: int = maxi(0, int(floor(z0 / CELL)) - origin.z)
		var k1: int = mini(shape.z - 1, int(ceil(z1 / CELL)) - origin.z)
		if i0 > i1 or k0 > k1:
			continue
		# How far each barycentric coordinate moves when the ray moves TIE,
		# twice over: the opposite edge's length over the area. np.hypot
		# there; its last bit could only matter to a ray an ulp from TIE.
		var spread: float = maxf(absf(area2), 1e-300)
		var e0: float = 2.0 * TIE * sqrt((bx - cx) * (bx - cx) + (bz - cz) * (bz - cz)) / spread
		var e1: float = 2.0 * TIE * sqrt((cx - ax) * (cx - ax) + (cz - az) * (cz - az)) / spread
		var e2: float = 2.0 * TIE * sqrt((ax - bx) * (ax - bx) + (az - bz) * (az - bz)) / spread
		var direction: int = 1 if area2 > 0.0 else -1
		for i: int in range(i0, i1 + 1):
			var gx: float = xs[i]
			for k: int in range(k0, k1 + 1):
				if not every and columns[i * shape.z + k] == 0:
					continue
				var gz: float = zs[k]
				var w0: float = ((bx - gx) * (cz - gz) - (bz - gz) * (cx - gx)) / area2
				var w1: float = ((cx - gx) * (az - gz) - (cz - gz) * (ax - gx)) / area2
				var w2: float = 1.0 - w0 - w1
				if every and w0 >= -e0 and w1 >= -e1 and w2 >= -e2 \
						and (absf(w0) <= e0 or absf(w1) <= e1 or absf(w2) <= e2):
					touchy[i * shape.z + k] = 1
				if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
					continue
				var y: float = w0 * ay + w1 * by + w2 * cy
				var column: int = i * shape.z + k
				if not crossings.has(column):
					crossings[column] = []
				(crossings[column] as Array).append([y, direction])

	# Up the column a face at a cell's middle counts on both sides: a part
	# resting on another there is held by the cell under it.
	var bits := PackedByteArray()
	bits.resize(shape.x * shape.y * shape.z)
	var y_base := PackedFloat64Array()
	for j: int in shape.y:
		y_base.append((float(j + origin.y) + 0.5) * CELL)
	for column: int in crossings:
		var hits: Array = crossings[column]
		hits.sort_custom(PartForge._before)
		var i: int = column / shape.z
		var k: int = column % shape.z
		var winding: int = 0
		var previous: float = 0.0
		var started: bool = false
		for hit: Array in hits:
			var height: float = hit[0]
			if winding > 0 and started:
				var first: int = y_base.bsearch(previous, true)
				var last: int = y_base.bsearch(height, false)
				for j: int in range(first, last):
					bits[(i * shape.y + j) * shape.z + k] = 1
			winding += int(hit[1])
			previous = height
			started = true
	return [bits, touchy]


func _remove_studs(grid: Grid, connectors: Array) -> Grid:
	var studs: Array = connectors.filter(func(c: Array) -> bool:
		return c[0] == "stud" and c[1] == "male")
	if studs.is_empty() or grid.count() == 0:
		return grid
	var out: Grid = grid.copy()
	for stud: Array in studs:
		var base: Array[float] = [stud[2], -float(stud[3]), -float(stud[4])]
		var axis: Array[float] = [stud[5], -float(stud[6]), -float(stud[7])]
		var length: float = sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2])
		if length < 1e-9:
			continue
		axis = [axis[0] / length, axis[1] / length, axis[2] / length]
		# Only the cells a stud could reach: its four LDU along and six and
		# a half across are inside eight of its base either way.
		var from := Vector3i.ZERO
		var to := Vector3i.ZERO
		for n: int in 3:
			from[n] = maxi(0, int(floor((base[n] - 8.0) / CELL)) - grid.origin[n] - 1)
			to[n] = mini(grid.shape[n], int(ceil((base[n] + 8.0) / CELL)) - grid.origin[n] + 1)
		for x: int in range(from.x, to.x):
			var dx: float = (float(x + grid.origin.x) + 0.5) * CELL - base[0]
			for y: int in range(from.y, to.y):
				var dy: float = (float(y + grid.origin.y) + 0.5) * CELL - base[1]
				for z: int in range(from.z, to.z):
					var dz: float = (float(z + grid.origin.z) + 0.5) * CELL - base[2]
					var along: float = dx * axis[0] + dy * axis[1] + dz * axis[2]
					var px: float = dx - along * axis[0]
					var py: float = dy - along * axis[1]
					var pz: float = dz - along * axis[2]
					var radial: float = sqrt(px * px + py * py + pz * pz)
					if along > 0.0 and along < STUD_HEIGHT and radial < STUD_RADIUS:
						out.put(x, y, z, 0)
	return _trim(out)


static func _trim(grid: Grid) -> Grid:
	var lo := Vector3i(grid.shape)
	var hi := Vector3i(-1, -1, -1)
	for x: int in grid.shape.x:
		for y: int in grid.shape.y:
			for z: int in grid.shape.z:
				if grid.at(x, y, z) == 1:
					lo = Vector3i(mini(lo.x, x), mini(lo.y, y), mini(lo.z, z))
					hi = Vector3i(maxi(hi.x, x), maxi(hi.y, y), maxi(hi.z, z))
	var out := Grid.new()
	if hi.x < 0:
		return out
	out.origin = grid.origin + lo
	out.shape = hi - lo + Vector3i.ONE
	out.bits.resize(out.shape.x * out.shape.y * out.shape.z)
	for x: int in out.shape.x:
		for y: int in out.shape.y:
			for z: int in out.shape.z:
				out.put(x, y, z, grid.at(x + lo.x, y + lo.y, z + lo.z))
	return out


## occupancy.fill_cavities. Each horizontal layer's enclosed voids closed
## ([method _fill_holes]), with the part's holes ([method _holes]) plugged
## while it fills, so a hole through a wall into a cavity does not open the
## cavity, and cleared after: a pin goes into a Technic hole, so the hole
## cannot be cover. Then the fill is taken back from a column with no
## plastic in it at any height, away from a stud's line (a ring plate's
## middle), and from the room round a bar a clip goes on.
func _fill_cavities(grid: Grid, connectors: Array = []) -> Grid:
	if grid.count() == 0:
		return grid
	var s: Vector3i = grid.shape
	var before: PackedByteArray = grid.bits
	var found: Array = _holes(connectors)
	var bores := PackedByteArray()
	var plugged: PackedByteArray = before.duplicate()
	if not found.is_empty():
		bores = _bore(grid, found, false)
		for n: int in plugged.size():
			if bores[n] == 1:
				plugged[n] = 1
	var out: Grid = grid.copy()
	var layer := PackedByteArray()
	layer.resize(s.x * s.z)
	for y: int in s.y:
		for x: int in s.x:
			for z: int in s.z:
				layer[x * s.z + z] = plugged[(x * s.y + y) * s.z + z]
		var filled: PackedByteArray = _fill_holes(layer, s.x, s.z)
		for x: int in s.x:
			for z: int in s.z:
				out.bits[(x * s.y + y) * s.z + z] = filled[x * s.z + z]

	# A hole right through, top to bottom, is a closed ring in every layer
	# too, but nothing is spoken for in it. Not on a stud's line, though: a
	# stud below is held by the plastic just past its tip.
	var near: PackedByteArray = _stud_lines(grid, connectors)
	for x: int in s.x:
		for z: int in s.z:
			if near[x * s.z + z] == 1:
				continue
			var through: bool = true
			for y: int in s.y:
				if before[(x * s.y + y) * s.z + z] == 1:
					through = false
					break
			if through:
				for y: int in s.y:
					out.bits[(x * s.y + y) * s.z + z] = 0

	if not bores.is_empty():
		for n: int in bores.size():
			if bores[n] == 1:
				out.bits[n] = 0

	for room: Array in _clip_rooms(grid, _bars(connectors), before):
		var lo: Vector3i = room[0]
		var hi: Vector3i = room[1]
		var cells: PackedByteArray = room[2]
		var w: Vector3i = hi - lo
		for x: int in range(lo.x, hi.x):
			for y: int in range(lo.y, hi.y):
				for z: int in range(lo.z, hi.z):
					var n: int = (x * s.y + y) * s.z + z
					if cells[((x - lo.x) * w.y + y - lo.y) * w.z + z - lo.z] == 1 \
							and before[n] == 0:
						out.bits[n] = 0
	return out


## occupancy.HOLE_RADIUS and DRAWN_HOLE_FIT.
const HOLE_RADIUS := 6.0
const DRAWN_HOLE_FIT := 0.5


## occupancy.holes: every hole a pin or an axle goes into, as [point, unit
## axis, span] in the app's axes, span [from, to] along the axis or empty
## for the whole line. A pin or axle hole primitive's, and a drawn bore of
## a pin's radius, all the way round, across the stud axis and not filled
## by the part's own shaft, along its own length.
static func _holes(connectors: Array) -> Array:
	var out: Array = []
	var shafts: Array = connectors.filter(func(c: Array) -> bool: return c[0] == "shaft")
	for c: Array in connectors:
		var span: Array = []
		if HOLE_KINDS.has(str(c[0])):
			pass
		elif c[0] == "bore" and absf(float(c[9]) - HOLE_RADIUS) <= DRAWN_HOLE_FIT \
				and _arc(c) >= 1.0 - 1e-6 and absf(float(c[6])) < 0.99 \
				and not shafts.any(func(shaft: Array) -> bool: return _fills(shaft, c)):
			span = [0.0, float(c[8])]
		else:
			continue
		# The connectors are in LDraw's axes and the grid in the app's.
		var axis := PackedFloat64Array([float(c[5]), -float(c[6]), -float(c[7])])
		var length: float = sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2])
		if length < 1e-9:
			continue
		out.append([PackedFloat64Array([float(c[2]), -float(c[3]), -float(c[4])]),
			PackedFloat64Array([axis[0] / length, axis[1] / length, axis[2] / length]), span])
	return out


## A round's arc; a round a file states for itself has none.
static func _arc(c: Array) -> float:
	return float(c[10]) if c.size() > 10 else 0.0


## occupancy._fills: whether a part's own shaft stands inside one of its
## bores, as a hinge's pin does in its eye.
static func _fills(shaft: Array, bore: Array) -> bool:
	if float(shaft[9]) < float(bore[9]) - 1.0 or float(shaft[9]) > float(bore[9]) + DRAWN_HOLE_FIT:
		return false
	var way := PackedFloat64Array([shaft[5], shaft[6], shaft[7]])
	var axis := PackedFloat64Array([bore[5], bore[6], bore[7]])
	if absf(_dot(way, axis)) < 0.999:
		return false
	var gap := PackedFloat64Array([float(shaft[2]) - float(bore[2]),
		float(shaft[3]) - float(bore[3]), float(shaft[4]) - float(bore[4])])
	if _length(_sub(gap, _scaled(axis, _dot(gap, axis)))) > 1.0:
		return false
	var a: float = _dot(gap, axis)
	var b: float = a + float(shaft[8]) * _dot(way, axis)
	return minf(maxf(a, b), float(bore[8])) - maxf(minf(a, b), 0.0) > 1.0


## occupancy._bore: the cells within a hole's radius of its axis, as a mask
## of the grid, within the slab the hole can touch (all of the grid for a
## hole at an angle to it); along a drawn hole's own length unless
## whole_line.
static func _bore(grid: Grid, found: Array, whole_line: bool) -> PackedByteArray:
	var s: Vector3i = grid.shape
	var bore := PackedByteArray()
	bore.resize(s.x * s.y * s.z)
	for hole: Array in found:
		var point: PackedFloat64Array = hole[0]
		var axis: PackedFloat64Array = hole[1]
		var span: Array = hole[2]
		var bounded: bool = not span.is_empty() and not whole_line
		var square: bool = maxf(absf(axis[0]), maxf(absf(axis[1]), absf(axis[2]))) > 0.99
		var lo := Vector3i.ZERO
		var hi := Vector3i(s)
		var empty: bool = false
		for n: int in 3:
			if not square or absf(axis[n]) > 0.99:
				continue
			var middle: float = point[n] / CELL - grid.origin[n]
			var reach: float = HOLE_RADIUS / CELL + 1.0
			lo[n] = maxi(0, int(floor(middle - reach)))
			hi[n] = mini(s[n], int(ceil(middle + reach)) + 1)
			if lo[n] >= hi[n]:
				empty = true
		if empty:
			continue
		for x: int in range(lo.x, hi.x):
			var dx: float = (float(x + grid.origin.x) + 0.5) * CELL - point[0]
			for y: int in range(lo.y, hi.y):
				var dy: float = (float(y + grid.origin.y) + 0.5) * CELL - point[1]
				for z: int in range(lo.z, hi.z):
					var dz: float = (float(z + grid.origin.z) + 0.5) * CELL - point[2]
					var along: float = dx * axis[0] + dy * axis[1] + dz * axis[2]
					var px: float = dx - along * axis[0]
					var py: float = dy - along * axis[1]
					var pz: float = dz - along * axis[2]
					if px * px + py * py + pz * pz > HOLE_RADIUS * HOLE_RADIUS:
						continue
					if bounded and (along < float(span[0]) or along > float(span[1])):
						continue
					bore[(x * s.y + y) * s.z + z] = 1
	return bore


## occupancy.STUD_CLEAR: how far from a stud's or a tube's upright line a
## through hole is kept filled, LDU.
const STUD_CLEAR := 8.0


## occupancy._stud_lines: the columns (x * sz + z) within STUD_CLEAR of an
## upright stud, tube or ridge of the part's.
static func _stud_lines(grid: Grid, connectors: Array) -> PackedByteArray:
	var s: Vector3i = grid.shape
	var near := PackedByteArray()
	near.resize(s.x * s.z)
	for c: Array in connectors:
		if not (c[0] == "stud" or c[0] == "tube" or c[0] == "ridge") \
				or absf(float(c[6])) < 0.99:
			continue
		for x: int in s.x:
			var gx: float = (float(x + grid.origin.x) + 0.5) * CELL - float(c[2])
			for z: int in s.z:
				# The grid's z is LDraw's turned.
				var gz: float = (float(z + grid.origin.z) + 0.5) * CELL + float(c[4])
				if gx * gx + gz * gz <= STUD_CLEAR * STUD_CLEAR:
					near[x * s.z + z] = 1
	return near


## occupancy.BAR_RADIUS, BAR_FIT and CLIP_REACH: a bar a clip goes on, and
## how far from its axis the clip reaches, LDU.
const BAR_RADIUS := 4.0
const BAR_FIT := 0.5
const CLIP_REACH := 8.0


## occupancy.bars: every bar a clip could be put on, across the stud axis,
## as [point, unit axis, length] in the app's axes.
static func _bars(connectors: Array) -> Array:
	var out: Array = []
	for c: Array in connectors:
		if c[0] != "shaft" or absf(float(c[9]) - BAR_RADIUS) > BAR_FIT \
				or absf(float(c[6])) >= 0.99 or float(c[8]) <= 0.0:
			continue
		var axis := PackedFloat64Array([float(c[5]), -float(c[6]), -float(c[7])])
		var length: float = sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2])
		if length < 1e-9:
			continue
		out.append([PackedFloat64Array([float(c[2]), -float(c[3]), -float(c[4])]),
			PackedFloat64Array([axis[0] / length, axis[1] / length, axis[2] / length]),
			float(c[8])])
	return out


## occupancy._clip_rooms: each bar with room round it for a clip, as [low
## corner, high corner] of the window of the grid it is in and the cells
## within CLIP_REACH of its axis, along it, there (x slowest). Room is no
## plastic between the bar's own cells and CLIP_REACH: a minifigure hip's
## pin inside its legs has none.
static func _clip_rooms(grid: Grid, gripped: Array, plastic: PackedByteArray) -> Array:
	var out: Array = []
	var s: Vector3i = grid.shape
	for bar: Array in gripped:
		var point: PackedFloat64Array = bar[0]
		var axis: PackedFloat64Array = bar[1]
		var length: float = bar[2]
		var lo := Vector3i.ZERO
		var hi := Vector3i.ZERO
		var empty: bool = false
		for n: int in 3:
			var far: float = point[n] + axis[n] * length
			var low: float = (minf(point[n], far) - CLIP_REACH) / CELL - grid.origin[n]
			var high: float = (maxf(point[n], far) + CLIP_REACH) / CELL - grid.origin[n]
			lo[n] = maxi(0, int(floor(low)))
			hi[n] = mini(s[n], int(ceil(high)) + 1)
			if lo[n] >= hi[n]:
				empty = true
		if empty:
			continue
		var w: Vector3i = hi - lo
		var room := PackedByteArray()
		room.resize(w.x * w.y * w.z)
		var held: bool = false
		for x: int in range(lo.x, hi.x):
			var dx: float = (float(x + grid.origin.x) + 0.5) * CELL - point[0]
			for y: int in range(lo.y, hi.y):
				var dy: float = (float(y + grid.origin.y) + 0.5) * CELL - point[1]
				for z: int in range(lo.z, hi.z):
					var dz: float = (float(z + grid.origin.z) + 0.5) * CELL - point[2]
					var along: float = dx * axis[0] + dy * axis[1] + dz * axis[2]
					var px: float = dx - along * axis[0]
					var py: float = dy - along * axis[1]
					var pz: float = dz - along * axis[2]
					var off: float = px * px + py * py + pz * pz
					if off > CLIP_REACH * CLIP_REACH or along < 0.0 or along > length:
						continue
					room[((x - lo.x) * w.y + y - lo.y) * w.z + z - lo.z] = 1
					# The bar's own cells are those whose middles are in it, and
					# the nearest middles outside it a cell's half diagonal on.
					if off > (BAR_RADIUS + CELL * 0.5) * (BAR_RADIUS + CELL * 0.5) \
							and plastic[(x * s.y + y) * s.z + z] == 1:
						held = true
		if not held:
			out.append([lo, hi, room])
	return out


## scipy's binary_fill_holes on one layer: the empty cells that cannot reach
## the layer's edge through empty cells, four ways, filled.
static func _fill_holes(mask: PackedByteArray, sx: int, sz: int) -> PackedByteArray:
	var outside := PackedByteArray()
	outside.resize(sx * sz)
	var queue := PackedInt32Array()
	for x: int in sx:
		for z: int in sz:
			if (x == 0 or z == 0 or x == sx - 1 or z == sz - 1) and mask[x * sz + z] == 0:
				outside[x * sz + z] = 1
				queue.append(x * sz + z)
	var head: int = 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		var x: int = at / sz
		var z: int = at % sz
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + step.x
			var nz: int = z + step.y
			if nx < 0 or nz < 0 or nx >= sx or nz >= sz:
				continue
			var n: int = nx * sz + nz
			if outside[n] == 0 and mask[n] == 0:
				outside[n] = 1
				queue.append(n)
	var out := PackedByteArray()
	out.resize(sx * sz)
	for n: int in sx * sz:
		out[n] = 0 if outside[n] == 1 else 1
	return out


## occupancy.to_boxes' numbers: how many times its cells a bounding box
## may be before it is too much air to stand for the part (MOSTLY_AIR); the
## grains, in cells, a cover past its limit is tried at, and the most boxes
## it may take at one; how near a bar's or a hole's line, and how far along
## a hole the connectors give no depth, a coarse cover stays exact, LDU; the
## share of the hull a flat face must be to cut it; the boxes a hole and a
## bar with room round it bring; and the most a carved bounding box takes.
const MOSTLY_AIR := 3.0
const COARSE_GRAINS: Array[int] = [1, 2, 3, 4, 6, 8]
const COARSE_LIMIT := 768
const JOINT_ROOM := 24.0
const HOLE_LINE := 40.0
const FLAT_FACE := 0.02
const HOLE_BOXES := 16
const BAR_BOXES := 24
const CARVED_LIMIT := 2048


## occupancy.to_boxes: the occupied cells as a few boxes, exact while they
## fit MOST_BOXES, and HOLE_BOXES more for each hole and BAR_BOXES for each
## bar with room for a clip. Past that a curve whose bounding box is mostly
## air keeps its own cells; the rest are covered at coarser grains, exact
## near a bar's or a hole's line and never past a big flat face of the hull;
## and past those, by the bounding box with the holes and the bars' room
## carved out of it.
static func _to_boxes(grid: Grid, connectors: Array = []) -> Array:
	if grid.count() == 0:
		return []
	var s: Vector3i = grid.shape
	var size: int = s.x * s.y * s.z
	var found: Array = _holes(connectors)
	var gripped: Array = _bars(connectors)
	var rooms: Array = _clip_rooms(grid, gripped, grid.bits)
	var allowed: int = mini(MOST_BOXES + HOLE_BOXES * found.size()
		+ BAR_BOXES * rooms.size(), CARVED_LIMIT)
	var boxes: Variant = _greedy(grid.bits, s, grid.origin, allowed)
	if boxes != null:
		return boxes

	var box: Array = _bounding_box(grid)
	var bounds := PackedByteArray()
	bounds.resize(size)
	for x: int in range(box[0] - grid.origin.x, box[0] - grid.origin.x + box[3]):
		for y: int in range(box[1] - grid.origin.y, box[1] - grid.origin.y + box[4]):
			for z: int in range(box[2] - grid.origin.z, box[2] - grid.origin.z + box[5]):
				bounds[(x * s.y + y) * s.z + z] = 1
	if box[3] * box[4] * box[5] > MOSTLY_AIR * grid.count():
		var exact: Variant = _greedy(grid.bits, s, grid.origin, CARVED_LIMIT)
		if exact != null:
			return exact
	var whole: Array = [box]
	var carved := PackedByteArray()
	if not found.is_empty() or not rooms.is_empty():
		carved = _bore(grid, found, true)
		for room: Array in rooms:
			var lo: Vector3i = room[0]
			var hi: Vector3i = room[1]
			var cells: PackedByteArray = room[2]
			var w: Vector3i = hi - lo
			for x: int in range(lo.x, hi.x):
				for y: int in range(lo.y, hi.y):
					for z: int in range(lo.z, hi.z):
						if cells[((x - lo.x) * w.y + y - lo.y) * w.z + z - lo.z] == 1:
							carved[(x * s.y + y) * s.z + z] = 1

	var lines: Array = []
	for bar: Array in gripped:
		lines.append([bar[0], bar[1], 0.0, bar[2]])
	for hole: Array in found:
		var span: Array = hole[2]
		lines.append([hole[0], hole[1], -HOLE_LINE if span.is_empty() else span[0],
			HOLE_LINE if span.is_empty() else span[1]])
	var near: PackedByteArray = _near_lines(grid, lines, JOINT_ROOM)
	# Found only past a grain of one: there the blocks are the cells, which
	# are inside any hull of them.
	var hull := PackedByteArray()
	for grain: int in COARSE_GRAINS:
		if grain > 1 and hull.is_empty():
			hull = _in_hull(grid)
		var blocks: PackedByteArray = _blocky(grid.bits, s, grain)
		var blocky := PackedByteArray()
		blocky.resize(size)
		for n: int in size:
			var cell: bool = grid.bits[n] == 1
			var keep: bool = cell if near[n] == 1 else (blocks[n] == 1 and bounds[n] == 1
				and (grain == 1 or hull[n] == 1))
			if keep and not cell and not carved.is_empty() and carved[n] == 1:
				keep = false
			blocky[n] = 1 if keep else 0
		boxes = _greedy(blocky, s, grid.origin, COARSE_LIMIT)
		if boxes != null:
			return boxes

	if carved.is_empty():
		return whole
	for n: int in size:
		if carved[n] == 1 and grid.bits[n] == 0:
			bounds[n] = 0
	var cut: Variant = _greedy(bounds, s, grid.origin, CARVED_LIMIT)
	return cut if cut != null and not (cut as Array).is_empty() else whole


## occupancy._greedy: boxes over a grid's cells, each grown from the first
## cell left uncovered along x, then z, then y while the slab stays solid;
## null past limit of them.
static func _greedy(bits: PackedByteArray, s: Vector3i, origin: Vector3i, limit: int) -> Variant:
	var boxes: Array = []
	var remaining: PackedByteArray = bits.duplicate()
	var cursor: int = 0
	while true:
		cursor = remaining.find(1, cursor)
		if cursor < 0:
			break
		if boxes.size() >= limit:
			return null
		var x0: int = cursor / (s.y * s.z)
		var y0: int = (cursor / s.z) % s.y
		var z0: int = cursor % s.z
		var x1: int = x0 + 1
		var y1: int = y0 + 1
		var z1: int = z0 + 1
		var grown: bool = true
		while grown:
			grown = false
			if x1 < s.x and _solid(bits, s, x1, x1 + 1, y0, y1, z0, z1):
				x1 += 1
				grown = true
			if z1 < s.z and _solid(bits, s, x0, x1, y0, y1, z1, z1 + 1):
				z1 += 1
				grown = true
			if y1 < s.y and _solid(bits, s, x0, x1, y1, y1 + 1, z0, z1):
				y1 += 1
				grown = true
		for x: int in range(x0, x1):
			for y: int in range(y0, y1):
				var row: int = (x * s.y + y) * s.z
				for z: int in range(z0, z1):
					remaining[row + z] = 0
		boxes.append([origin.x + x0, origin.y + y0, origin.z + z0,
			x1 - x0, y1 - y0, z1 - z0])
	return boxes


static func _solid(bits: PackedByteArray, s: Vector3i, x0: int, x1: int, y0: int, y1: int,
		z0: int, z1: int) -> bool:
	for x: int in range(x0, x1):
		for y: int in range(y0, y1):
			var row: int = (x * s.y + y) * s.z
			for z: int in range(z0, z1):
				if bits[row + z] == 0:
					return false
	return true


static func _bounding_box(grid: Grid) -> Array:
	var lo := Vector3i(grid.shape)
	var hi := Vector3i(-1, -1, -1)
	for x: int in grid.shape.x:
		for y: int in grid.shape.y:
			for z: int in grid.shape.z:
				if grid.at(x, y, z) == 1:
					lo = Vector3i(mini(lo.x, x), mini(lo.y, y), mini(lo.z, z))
					hi = Vector3i(maxi(hi.x, x), maxi(hi.y, y), maxi(hi.z, z))
	return [grid.origin.x + lo.x, grid.origin.y + lo.y, grid.origin.z + lo.z,
		hi.x - lo.x + 1, hi.y - lo.y + 1, hi.z - lo.z + 1]


## occupancy._near_lines: the cells whose middles are within reach of any
## of lines, each [point, unit axis, from, to] in LDU along it, app axes.
## Only the box each line and its reach are in is looked at.
static func _near_lines(grid: Grid, lines: Array, reach: float) -> PackedByteArray:
	var s: Vector3i = grid.shape
	var out := PackedByteArray()
	out.resize(s.x * s.y * s.z)
	for line: Array in lines:
		var point: PackedFloat64Array = line[0]
		var axis: PackedFloat64Array = line[1]
		var low: float = line[2]
		var high: float = line[3]
		var lo := Vector3i.ZERO
		var hi := Vector3i.ZERO
		for n: int in 3:
			var a: float = point[n] + axis[n] * low
			var b: float = point[n] + axis[n] * high
			lo[n] = maxi(0, int(floor((minf(a, b) - reach) / CELL)) - grid.origin[n] - 1)
			hi[n] = mini(s[n], int(ceil((maxf(a, b) + reach) / CELL)) - grid.origin[n] + 1)
		for x: int in range(lo.x, hi.x):
			var dx: float = (float(x + grid.origin.x) + 0.5) * CELL - point[0]
			for y: int in range(lo.y, hi.y):
				var dy: float = (float(y + grid.origin.y) + 0.5) * CELL - point[1]
				for z: int in range(lo.z, hi.z):
					var dz: float = (float(z + grid.origin.z) + 0.5) * CELL - point[2]
					var along: float = clampf(dx * axis[0] + dy * axis[1] + dz * axis[2],
						low, high)
					var px: float = dx - along * axis[0]
					var py: float = dy - along * axis[1]
					var pz: float = dz - along * axis[2]
					if px * px + py * py + pz * pz <= reach * reach:
						out[(x * s.y + y) * s.z + z] = 1
	return out


## occupancy._blocky: every block of grain cells a side, from the grid's
## corner, that has a cell occupied, occupied whole.
static func _blocky(bits: PackedByteArray, s: Vector3i, grain: int) -> PackedByteArray:
	if grain == 1:
		return bits
	var out := PackedByteArray()
	out.resize(bits.size())
	for bx: int in range(0, s.x, grain):
		for by: int in range(0, s.y, grain):
			for bz: int in range(0, s.z, grain):
				var ex: int = mini(bx + grain, s.x)
				var ey: int = mini(by + grain, s.y)
				var ez: int = mini(bz + grain, s.z)
				var occupied: bool = false
				for x: int in range(bx, ex):
					for y: int in range(by, ey):
						var row: int = (x * s.y + y) * s.z
						for z: int in range(bz, ez):
							if bits[row + z] == 1:
								occupied = true
								break
						if occupied:
							break
					if occupied:
						break
				if not occupied:
					continue
				for x: int in range(bx, ex):
					for y: int in range(by, ey):
						var row: int = (x * s.y + y) * s.z
						for z: int in range(bz, ez):
							out[row + z] = 1
	return out


## occupancy._in_hull: the cells whose middles are inside the big flat faces
## of the occupied cells' convex hull, and every occupied cell; all of them
## where the cells are too few or too flat for a hull. scipy's ConvexHull
## there; here the hull is found exactly, in whole cells ([method _hull]),
## which gives the same planes, and so cuts the same cells.
static func _in_hull(grid: Grid) -> PackedByteArray:
	var s: Vector3i = grid.shape
	var whole := PackedByteArray()
	whole.resize(s.x * s.y * s.z)
	whole.fill(1)
	if grid.count() < 4:
		return whole
	var faces: Array = _hull(_hull_points(grid))
	if faces.is_empty():
		return whole
	# The hull's triangles, gathered by the plane they nearly lie in: their
	# unit normals to a tenth, as the pipeline keys them.
	var areas: Dictionary = {}       ## key -> summed area
	var planes: Dictionary = {}      ## key -> { plane in lowest terms -> it }
	for face: Array in faces:
		var nx: int = face[0]
		var ny: int = face[1]
		var nz: int = face[2]
		var size: float = sqrt(float(nx * nx + ny * ny + nz * nz))
		var key: Vector3i = Vector3i(_rint(nx / size * 10.0), _rint(ny / size * 10.0),
			_rint(nz / size * 10.0))
		areas[key] = float(areas.get(key, 0.0)) + 0.5 * size
		var common: int = _gcd(_gcd(absi(nx), absi(ny)), absi(nz))
		var plane: Array = [nx / common, ny / common, nz / common, int(face[3]) / common]
		if not planes.has(key):
			planes[key] = {}
		(planes[key] as Dictionary)["%d %d %d %d" % plane] = plane
	var total: float = 0.0
	for key: Vector3i in areas:
		total += float(areas[key])
	var cuts: Array = []
	for key: Vector3i in areas:
		if float(areas[key]) < FLAT_FACE * total:
			continue
		cuts.append_array((planes[key] as Dictionary).values())
	# Each row along z is inside every cut between two heights.
	var inside: PackedByteArray = grid.bits.duplicate()
	for x: int in s.x:
		for y: int in s.y:
			var low: int = 0
			var high: int = s.z - 1
			for plane: Array in cuts:
				var nz: int = plane[2]
				var rest: int = int(plane[3]) - int(plane[0]) * x - int(plane[1]) * y
				if nz > 0:
					high = mini(high, _floor_div(rest, nz))
				elif nz < 0:
					low = maxi(low, -_floor_div(rest, -nz))
				elif rest < 0:
					high = -1
				if low > high:
					break
			for z: int in range(low, high + 1):
				inside[(x * s.y + y) * s.z + z] = 1
	return inside


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var r: int = a % b
		a = b
		b = r
	return a


static func _floor_div(a: int, b: int) -> int:
	var q: int = a / b
	return q - 1 if a % b != 0 and a < 0 else q


## The points the hull can have corners at, as x, y, z triples in whole
## cells: a corner of the hull is a corner of every slice through it, so of
## the outline of its x slice and of its z slice, each found from the ends
## of the slice's rows.
static func _hull_points(grid: Grid) -> PackedInt64Array:
	var s: Vector3i = grid.shape
	var corner := PackedByteArray()
	corner.resize(s.x * s.y * s.z)
	for x: int in s.x:
		var ends := PackedInt64Array()
		for y: int in s.y:
			var row: int = (x * s.y + y) * s.z
			var first: int = -1
			var last: int = -1
			for z: int in s.z:
				if grid.bits[row + z] == 1:
					if first < 0:
						first = z
					last = z
			if first < 0:
				continue
			ends.append_array(PackedInt64Array([y, first]))
			if last != first:
				ends.append_array(PackedInt64Array([y, last]))
		var outline: PackedInt64Array = _corners(ends)
		for n: int in outline.size() / 2:
			corner[(x * s.y + outline[n * 2]) * s.z + outline[n * 2 + 1]] = 1
	var out := PackedInt64Array()
	for z: int in s.z:
		var ends := PackedInt64Array()
		for x: int in s.x:
			var first: int = -1
			var last: int = -1
			for y: int in s.y:
				if grid.bits[(x * s.y + y) * s.z + z] == 1:
					if first < 0:
						first = y
					last = y
			if first < 0:
				continue
			ends.append_array(PackedInt64Array([x, first]))
			if last != first:
				ends.append_array(PackedInt64Array([x, last]))
		var outline: PackedInt64Array = _corners(ends)
		for n: int in outline.size() / 2:
			var x: int = outline[n * 2]
			var y: int = outline[n * 2 + 1]
			if corner[(x * s.y + y) * s.z + z] == 1:
				out.append_array(PackedInt64Array([x, y, z]))
	return out


## The corners of the outline round (u, v) points sorted by u then v:
## Andrew's monotone chain, with points along an edge left out.
static func _corners(points: PackedInt64Array) -> PackedInt64Array:
	var count: int = points.size() / 2
	if count <= 2:
		return points
	var lower: PackedInt64Array = _chain(points, range(count))
	var upper: PackedInt64Array = _chain(points, range(count - 1, -1, -1))
	# Each ends where the other starts.
	lower.resize(lower.size() - 2)
	upper.resize(upper.size() - 2)
	lower.append_array(upper)
	return lower


## Half of the monotone chain: the points in order, each kept while the
## chain turns left at it.
static func _chain(points: PackedInt64Array, order: Array) -> PackedInt64Array:
	var chain := PackedInt64Array()
	for n: int in order:
		var u: int = points[n * 2]
		var v: int = points[n * 2 + 1]
		while chain.size() >= 4:
			var size: int = chain.size()
			var au: int = chain[size - 4]
			var av: int = chain[size - 3]
			if (chain[size - 2] - au) * (v - av) - (chain[size - 1] - av) * (u - au) > 0:
				break
			chain.resize(size - 2)
		chain.append(u)
		chain.append(v)
	return chain


## A convex hull being built: its points, and its faces, each three point
## indices counter-clockwise seen from outside, the face across each edge
## (corner k to k + 1), the plane [nx, ny, nz, d] with n.p = d on it and
## n.p > d outside, and the points still outside it.
class Hull extends RefCounted:
	var points := PackedInt64Array()
	var corners := PackedInt32Array()
	var across := PackedInt32Array()
	var planes := PackedInt64Array()
	var alive := PackedByteArray()
	var outside: Array = []

	func add(a: int, b: int, c: int) -> int:
		var p: PackedInt64Array = points
		var ux: int = p[b * 3] - p[a * 3]
		var uy: int = p[b * 3 + 1] - p[a * 3 + 1]
		var uz: int = p[b * 3 + 2] - p[a * 3 + 2]
		var vx: int = p[c * 3] - p[a * 3]
		var vy: int = p[c * 3 + 1] - p[a * 3 + 1]
		var vz: int = p[c * 3 + 2] - p[a * 3 + 2]
		var nx: int = uy * vz - uz * vy
		var ny: int = uz * vx - ux * vz
		var nz: int = ux * vy - uy * vx
		corners.append_array(PackedInt32Array([a, b, c]))
		across.append_array(PackedInt32Array([-1, -1, -1]))
		planes.append_array(PackedInt64Array([nx, ny, nz,
			nx * p[a * 3] + ny * p[a * 3 + 1] + nz * p[a * 3 + 2]]))
		alive.append(1)
		outside.append([])
		return alive.size() - 1

	## How far outside a face a point is, times the face's normal's length.
	func height(face: int, point: int) -> int:
		return planes[face * 4] * points[point * 3] + planes[face * 4 + 1] * points[point * 3 + 1] \
			+ planes[face * 4 + 2] * points[point * 3 + 2] - planes[face * 4 + 3]


## The convex hull of whole-cell points (x, y, z triples), as each face's
## plane [nx, ny, nz, d] with n.p <= d for every point: Quickhull, in
## integers, so a face is on the hull or not with no tolerance. Empty where
## the points are flat, which is where Qhull gives up too.
static func _hull(points: PackedInt64Array) -> Array:
	var count: int = points.size() / 3
	if count < 4:
		return []
	var hull := Hull.new()
	hull.points = points
	var p: PackedInt64Array = points
	# The first tetrahedron: two points apart along an axis, the point
	# furthest off the line through them, the point furthest off the plane.
	var i0: int = -1
	var i1: int = -1
	for axis: int in 3:
		var low: int = 0
		var high: int = 0
		for i: int in count:
			if p[i * 3 + axis] < p[low * 3 + axis]:
				low = i
			if p[i * 3 + axis] > p[high * 3 + axis]:
				high = i
		if p[low * 3 + axis] != p[high * 3 + axis]:
			i0 = low
			i1 = high
			break
	if i0 < 0:
		return []
	var ux: int = p[i1 * 3] - p[i0 * 3]
	var uy: int = p[i1 * 3 + 1] - p[i0 * 3 + 1]
	var uz: int = p[i1 * 3 + 2] - p[i0 * 3 + 2]
	var i2: int = -1
	var best: int = 0
	for i: int in count:
		var vx: int = p[i * 3] - p[i0 * 3]
		var vy: int = p[i * 3 + 1] - p[i0 * 3 + 1]
		var vz: int = p[i * 3 + 2] - p[i0 * 3 + 2]
		var cx: int = uy * vz - uz * vy
		var cy: int = uz * vx - ux * vz
		var cz: int = ux * vy - uy * vx
		if cx * cx + cy * cy + cz * cz > best:
			best = cx * cx + cy * cy + cz * cz
			i2 = i
	if i2 < 0:
		return []
	var first: int = hull.add(i0, i1, i2)
	var i3: int = -1
	best = 0
	for i: int in count:
		if absi(hull.height(first, i)) > best:
			best = absi(hull.height(first, i))
			i3 = i
	if i3 < 0:
		return []
	if hull.height(first, i3) > 0:
		var swap: int = i1
		i1 = i2
		i2 = swap
	hull = Hull.new()
	hull.points = points
	var faces: Array[int] = [hull.add(i0, i1, i2), hull.add(i0, i3, i1),
		hull.add(i1, i3, i2), hull.add(i0, i2, i3)]
	var edges: Dictionary = {}
	for f: int in faces:
		for k: int in 3:
			edges[Vector2i(hull.corners[f * 3 + k], hull.corners[f * 3 + (k + 1) % 3])] = f
	for f: int in faces:
		for k: int in 3:
			hull.across[f * 3 + k] = edges[Vector2i(hull.corners[f * 3 + (k + 1) % 3],
				hull.corners[f * 3 + k])]
	for i: int in count:
		if i == i0 or i == i1 or i == i2 or i == i3:
			continue
		for f: int in faces:
			if hull.height(f, i) > 0:
				(hull.outside[f] as Array).append(i)
				break

	var pending: Array[int] = []
	pending.append_array(faces)
	while not pending.is_empty():
		var f: int = pending.pop_back()
		var waiting: Array = hull.outside[f]
		if hull.alive[f] == 0 or waiting.is_empty():
			continue
		var apex: int = waiting[0]
		var top: int = hull.height(f, apex)
		for i: int in waiting:
			if hull.height(f, i) > top:
				top = hull.height(f, i)
				apex = i
		# The faces the apex is outside of, found across their edges.
		var seen: Dictionary = {f: true}
		var visible: Array[int] = [f]
		var at: int = 0
		while at < visible.size():
			var g: int = visible[at]
			at += 1
			for k: int in 3:
				var next: int = hull.across[g * 3 + k]
				if not seen.has(next) and hull.height(next, apex) > 0:
					seen[next] = true
					visible.append(next)
		# A face from each edge round them to the apex.
		var made: Array[int] = []
		var starting: Dictionary = {}
		var ending: Dictionary = {}
		for g: int in visible:
			for k: int in 3:
				var next: int = hull.across[g * 3 + k]
				if seen.has(next):
					continue
				var a: int = hull.corners[g * 3 + k]
				var b: int = hull.corners[g * 3 + (k + 1) % 3]
				var face: int = hull.add(a, b, apex)
				hull.across[face * 3] = next
				for j: int in 3:
					if hull.corners[next * 3 + j] == b and hull.corners[next * 3 + (j + 1) % 3] == a:
						hull.across[next * 3 + j] = face
				starting[a] = face
				ending[b] = face
				made.append(face)
		for face: int in made:
			hull.across[face * 3 + 1] = starting[hull.corners[face * 3 + 1]]
			hull.across[face * 3 + 2] = ending[hull.corners[face * 3]]
		for g: int in visible:
			hull.alive[g] = 0
			for i: int in hull.outside[g]:
				if i == apex:
					continue
				for face: int in made:
					if hull.height(face, i) > 0:
						(hull.outside[face] as Array).append(i)
						break
			hull.outside[g] = []
		for face: int in made:
			if not (hull.outside[face] as Array).is_empty():
				pending.append(face)

	var out: Array = []
	for f: int in hull.alive.size():
		if hull.alive[f] == 1:
			out.append([hull.planes[f * 4], hull.planes[f * 4 + 1], hull.planes[f * 4 + 2],
				hull.planes[f * 4 + 3]])
	return out


## Where a stud from below can go: the lowest plate's footprint with its
## voids filled, divided into stud squares, each kept if half covered.
static func _bottom_sockets(grid: Grid) -> Array:
	if grid.count() == 0:
		return []
	var s: Vector3i = grid.shape
	var bottom: int = -1
	for y: int in s.y:
		for x: int in s.x:
			for z: int in s.z:
				if grid.at(x, y, z) == 1:
					bottom = y
					break
			if bottom >= 0:
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return []
	var top: int = mini(s.y, bottom + maxi(1, _rint(8.0 / CELL)))
	var mask := PackedByteArray()
	mask.resize(s.x * s.z)
	for x: int in s.x:
		for z: int in s.z:
			for y: int in range(bottom, top):
				if grid.at(x, y, z) == 1:
					mask[x * s.z + z] = 1
					break
	var footprint: PackedByteArray = _fill_holes(mask, s.x, s.z)
	var step: int = maxi(1, _rint(20.0 / CELL))
	var base_x: int = -1
	var base_z: int = 1 << 30
	for x: int in s.x:
		for z: int in s.z:
			if footprint[x * s.z + z] == 1:
				if base_x < 0:
					base_x = x
				base_z = mini(base_z, z)
	if base_x < 0:
		return []
	var counts: Dictionary = {}
	var order: Array = []
	for x: int in s.x:
		for z: int in s.z:
			if footprint[x * s.z + z] == 1:
				var key := Vector2i((x - base_x) / step, (z - base_z) / step)
				if not counts.has(key):
					counts[key] = 0
					order.append(key)
				counts[key] = int(counts[key]) + 1
	var needed: float = 0.5 * step * step
	var sockets: Array = []
	for key: Vector2i in order:
		if float(counts[key]) < needed:
			continue
		sockets.append([
			(float(grid.origin.x + base_x + key.x * step) + step * 0.5) * CELL,
			(float(grid.origin.z + base_z + key.y * step) + step * 0.5) * CELL])
	sockets.sort_custom(PartForge._before)
	return sockets


# -- the whole of it -----------------------------------------------------------


## Build a part from its text. [param others] holds files it may reference
## that are neither bundled nor in the library: the rest of a model file.
## [param library] lets references resolve into vendor/ldraw where a
## checkout has it. [param cover]: a part whose collision cover and
## underside this one is, for a print, which is that part to the triangle.
## Without [param meshed] the geometry is encoded but not made a mesh
## ([member Result.mesh] null), which may be done off the main thread; the
## caller makes it ([method with_mesh]).
static func build(text: String, id: String, others: Dictionary = {},
		library: bool = true, cover: Lbm.PartMesh = null, meshed: bool = true) -> Result:
	var forge := PartForge.new()
	forge._use_library = library
	return forge._build(text, id, others, cover, meshed)


## [param built], built without its mesh ([method build]), with it made.
static func with_mesh(built: Result) -> Result:
	if not built.problem.is_empty() or built.mesh != null:
		return built
	built.mesh = Lbm.parse(built.lbm, built.id)
	if built.mesh == null:
		built.problem = "the geometry did not encode"
	return built


## Build what a flexible part is drawn with as LDCad generated it (a hose's,
## a band's, a rope's skin: CustomParts.begin_skins), its geometry as the file
## has it and nothing else. No connectors: a skin is joined to nothing, its
## ends are parts. And no voxelised cover: 42082's rope runs a metre and a
## half across the crane, a box of 33 million cells of air. Its cover is the
## cells its surface passes through, a block of two cells a side each
## ([method _skin_boxes]), which is what picking it and what stands near it
## need. A reference to a file this build has not got is a problem, as in
## [method build]: half a hose is not drawn. Safe on another thread
## without [param meshed], as build is (CustomParts.begin_skins).
static func build_skin(text: String, id: String, others: Dictionary = {},
		library: bool = true, meshed: bool = true) -> Result:
	var forge := PartForge.new()
	forge._use_library = library
	var result := Result.new()
	result.id = id
	var key: String = normalise(id + ".dat")
	for name: String in others:
		forge._given[normalise(name)] = others[name]
	forge._given[key] = text
	var source: Source = forge._source_for(key)
	if source == null:
		result.problem = "nothing to read"
		return result
	result.name = source.description
	result.category = source.category
	forge._flatten(key)
	for name: String in forge._missing:
		result.missing.append(name)
	if not result.missing.is_empty():
		result.problem = "it uses files this build does not have: " \
			+ ", ".join(result.missing)
		return result
	if forge._tri_color.is_empty():
		result.problem = "it has no faces"
		return result
	var surfaces: Array = forge._surfaces(forge._skin_normals())
	var lo := PackedFloat64Array([INF, INF, INF])
	var hi := PackedFloat64Array([-INF, -INF, -INF])
	for v: int in forge._tri.size() / 3:
		for n: int in 3:
			lo[n] = minf(lo[n], forge._tri[v * 3 + n])
			hi[n] = maxf(hi[n], forge._tri[v * 3 + n])
	result.bounds_min = PackedFloat64Array([lo[0], -hi[1], -hi[2]])
	result.bounds_max = PackedFloat64Array([hi[0], -lo[1], -lo[2]])
	result.triangles = forge._tri_color.size()
	result.boxes = forge._skin_boxes()
	for box: Array in result.boxes:
		result.cells += int(box[3]) * int(box[4]) * int(box[5])
	result.lbm = encode(surfaces, result.bounds_min, result.bounds_max, [], result.boxes, [])
	# Its mesh made where it is wanted, as build's: on the main thread.
	return with_mesh(result) if meshed else result


## The files [param text] draws on, through everything they draw on, that
## this build cannot read: what [method build_skin] would call a problem, found
## without building anything (a skin is built on another thread, and one that
## cannot be is left out of that and said when the file opens).
static func unreached(text: String, others: Dictionary = {}, library: bool = true) -> PackedStringArray:
	var given: Dictionary = {}
	for name: String in others:
		given[normalise(name)] = others[name]
	var missing := PackedStringArray()
	var seen: Dictionary = {}
	var todo: Array = [text]
	while not todo.is_empty():
		for raw: String in str(todo.pop_back()).split("\n"):
			var line: String = raw.strip_edges()
			if not line.begins_with("1 ") and not line.begins_with("1\t"):
				continue
			var words: PackedStringArray = line.replace("\t", " ").split(" ", false)
			if words.size() < 15:
				continue
			var key: String = normalise(" ".join(words.slice(14)))
			if seen.has(key):
				continue
			seen[key] = true
			if given.has(key):
				todo.append(given[key])
			elif FileAccess.file_exists(BUNDLED + key):
				continue
			elif library and not library_path(key).is_empty():
				# The library's own files draw on the library only.
				continue
			else:
				missing.append(key)
	return missing


## A skin's normals, smooth where its faces meet within the crease angle of
## what meets there: each corner the faces at its place summed by area, or
## its own face's where that turns too far from the sum. One pass, not
## [method _normals]' grouping of the faces round each corner by the edges
## they share, which took 0.6 s of 42082's rope (28,000 faces) when its
## segments are cylinders, smooth all round.
func _skin_normals() -> PackedFloat64Array:
	var count: int = _tri_color.size()
	var cos_crease: float = cos(deg_to_rad(CREASE_DEGREES))
	var face := PackedFloat64Array()
	face.resize(count * 3)
	var slot_of := PackedInt32Array()
	slot_of.resize(count * 3)
	var slots: Dictionary = {}
	var sums := PackedFloat64Array()
	for t: int in count:
		var o: int = t * 9
		var ux: float = _tri[o + 3] - _tri[o]
		var uy: float = _tri[o + 4] - _tri[o + 1]
		var uz: float = _tri[o + 5] - _tri[o + 2]
		var vx: float = _tri[o + 6] - _tri[o]
		var vy: float = _tri[o + 7] - _tri[o + 1]
		var vz: float = _tri[o + 8] - _tri[o + 2]
		var nx: float = uy * vz - uz * vy
		var ny: float = uz * vx - ux * vz
		var nz: float = ux * vy - uy * vx
		var length: float = sqrt(nx * nx + ny * ny + nz * nz)
		if length >= 1e-12:
			face[t * 3] = nx / length
			face[t * 3 + 1] = ny / length
			face[t * 3 + 2] = nz / length
		for c: int in 3:
			var at := Vector3i(roundi(_tri[o + c * 3] * WELD_SCALE),
				roundi(_tri[o + c * 3 + 1] * WELD_SCALE), roundi(_tri[o + c * 3 + 2] * WELD_SCALE))
			var slot: int = slots.get(at, -1)
			if slot < 0:
				slot = sums.size() / 3
				slots[at] = slot
				sums.append(0.0)
				sums.append(0.0)
				sums.append(0.0)
			slot_of[t * 3 + c] = slot
			# The cross product's length is twice the area: weighted by it.
			sums[slot * 3] += nx * 0.5
			sums[slot * 3 + 1] += ny * 0.5
			sums[slot * 3 + 2] += nz * 0.5
	var normals := PackedFloat64Array()
	normals.resize(count * 9)
	for corner: int in count * 3:
		var t: int = corner / 3
		var slot: int = slot_of[corner]
		var x: float = sums[slot * 3]
		var y: float = sums[slot * 3 + 1]
		var z: float = sums[slot * 3 + 2]
		var length: float = sqrt(x * x + y * y + z * z)
		if length > 1e-12 and (face[t * 3] * x + face[t * 3 + 1] * y
				+ face[t * 3 + 2] * z) / length >= cos_crease:
			normals[corner * 3] = x / length
			normals[corner * 3 + 1] = y / length
			normals[corner * 3 + 2] = z / length
		else:
			normals[corner * 3] = face[t * 3]
			normals[corner * 3 + 1] = face[t * 3 + 1]
			normals[corner * 3 + 2] = face[t * 3 + 2]
	return normals


## A skin's cover: every block of SKIN_BLOCK cells a side its surface passes
## through, in the app's axes, run together along x. A face under a block
## and a half across is taken at its middle, which is where a segment's
## faces are along a hose; a wider one is sampled across at under a block
## apart.
const SKIN_BLOCK := 2
const BLOCK_OFFSET := 1 << 20


func _skin_boxes() -> Array:
	var size: float = CELL * SKIN_BLOCK
	var blocks: Dictionary = {}
	var reach: float = 2.25 * size * size
	for t: int in _tri_color.size():
		var o: int = t * 9
		var a := Vector3(_tri[o], -_tri[o + 1], -_tri[o + 2])
		var b := Vector3(_tri[o + 3], -_tri[o + 4], -_tri[o + 5])
		var c := Vector3(_tri[o + 6], -_tri[o + 7], -_tri[o + 8])
		var longest: float = maxf(a.distance_squared_to(b),
			maxf(a.distance_squared_to(c), b.distance_squared_to(c)))
		if longest <= reach:
			var mid: Vector3 = (a + b + c) / (3.0 * size)
			blocks[Vector3i(floori(mid.x), floori(mid.y), floori(mid.z))] = true
			continue
		# Along each of its two sides from a at under a block apart: a long
		# thin face (a straight run of rope merged into one segment, 400 LDU
		# by 3) is sampled along its length, not over a square of it.
		var along_b: int = maxi(1, ceili(a.distance_to(b) / size))
		var along_c: int = maxi(1, ceili(a.distance_to(c) / size))
		for i: int in along_b + 1:
			var u: float = float(i) / along_b
			for j: int in along_c + 1:
				var v: float = float(j) / along_c
				if u + v > 1.0 + 1e-9:
					break
				var p: Vector3 = a + (b - a) * u + (c - a) * v
				blocks[Vector3i(floori(p.x / size), floori(p.y / size),
					floori(p.z / size))] = true
	# Sorted by y, z, then x, as one number each: a block's place is within
	# a million either way of the part's origin.
	var order := PackedInt64Array()
	for k: Vector3i in blocks:
		order.append(((k.y + BLOCK_OFFSET) << 42) | ((k.z + BLOCK_OFFSET) << 21)
			| (k.x + BLOCK_OFFSET))
	order.sort()
	var boxes: Array = []
	var run: Array = []
	for packed: int in order:
		var k := Vector3i((packed & 0x1FFFFF) - BLOCK_OFFSET,
			(packed >> 42) - BLOCK_OFFSET, ((packed >> 21) & 0x1FFFFF) - BLOCK_OFFSET)
		if not run.is_empty() and int(run[1]) == k.y * SKIN_BLOCK \
				and int(run[2]) == k.z * SKIN_BLOCK \
				and int(run[0]) + int(run[3]) == k.x * SKIN_BLOCK:
			run[3] = int(run[3]) + SKIN_BLOCK
			continue
		if not run.is_empty():
			boxes.append(run)
		run = [k.x * SKIN_BLOCK, k.y * SKIN_BLOCK, k.z * SKIN_BLOCK,
			SKIN_BLOCK, SKIN_BLOCK, SKIN_BLOCK]
	if not run.is_empty():
		boxes.append(run)
	return boxes


func _build(text: String, id: String, others: Dictionary,
		cover: Lbm.PartMesh = null, meshed: bool = true) -> Result:
	var result := Result.new()
	result.id = id
	var key: String = normalise(id + ".dat")
	for name: String in others:
		_given[normalise(name)] = others[name]
	_given[key] = text
	var source: Source = _source_for(key)
	if source == null:
		result.problem = "nothing to read"
		return result
	result.name = source.description
	result.category = source.category
	_flatten(key)
	for name: String in _missing:
		result.missing.append(name)
	if not result.missing.is_empty():
		result.problem = "it uses parts this build does not have: " \
			+ ", ".join(result.missing)
		return result
	if _tri_color.is_empty():
		result.problem = "it has no faces"
		return result

	var normals: PackedFloat64Array = _normals()
	var surfaces: Array = _surfaces(normals)
	var lo := PackedFloat64Array([INF, INF, INF])
	var hi := PackedFloat64Array([-INF, -INF, -INF])
	for v: int in _tri.size() / 3:
		for n: int in 3:
			lo[n] = minf(lo[n], _tri[v * 3 + n])
			hi[n] = maxf(hi[n], _tri[v * 3 + n])
	# The same axis change as the mesh, so min and max swap on Y and Z.
	result.bounds_min = PackedFloat64Array([lo[0], -hi[1], -hi[2]])
	result.bounds_max = PackedFloat64Array([hi[0], -lo[1], -lo[2]])
	result.triangles = _tri_color.size()

	var found: Array = _connectors(key)
	for c: Array in found:
		result.connector_counts[c[0]] = int(result.connector_counts.get(c[0], 0)) + 1
		var row: Array = [c[0], c[1], c[2], -float(c[3]), -float(c[4]),
			c[5], -float(c[6]), -float(c[7])]
		if c.size() > 8:
			row.append_array([c[8], c[9]])     # a round's length and radius
		result.connectors.append(row)

	if cover != null:
		# The plain part's own, which the pipeline made from its primitives.
		# Rebuilt from the connectors a print states, a bore's arc is not in
		# them (nor in an .lbm), so a print of 3816c kept the bore its hip's
		# pin goes in filled, three boxes and 109 cells off the legs it is.
		for box: AABB in cover.boxes:
			result.boxes.append([roundi(box.position.x), roundi(box.position.y),
				roundi(box.position.z), roundi(box.size.x), roundi(box.size.y),
				roundi(box.size.z)])
			result.cells += roundi(box.size.x * box.size.y * box.size.z)
		for socket: Vector2 in cover.sockets:
			result.sockets.append([socket.x, socket.y])
	else:
		var solid: Grid = _fill_cavities(_remove_studs(_voxelise(), found), found)
		result.cells = solid.count()
		result.boxes = _to_boxes(solid, found)
		result.sockets = _bottom_sockets(solid)

	result.lbm = encode(surfaces, result.bounds_min, result.bounds_max,
		result.connectors, result.boxes, result.sockets)
	return with_mesh(result) if meshed else result
