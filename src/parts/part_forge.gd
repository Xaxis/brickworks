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
## rounding halves to even, as Python's round() does. Two places differ on
## purpose and say so: a Technic hole's two faces are not merged and its
## bore is not cleared (connectivity._merge_half_holes and the hole half of
## occupancy.fill_cavities), because nothing the maker makes has one.
##
## Primitives come from res://assets/ldraw/, the few the maker draws with,
## shipped with the app (CC BY 4.0, credited in docs/ATTRIBUTION.md), and
## from res://vendor/ldraw/ when a checkout has the whole library — which
## is what lets a part embedded in somebody else's model file build here.
class_name PartForge
extends RefCounted

const BUNDLED := "res://assets/ldraw/"
const LIBRARY := "res://vendor/ldraw/"
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
			joined.append([c[0], c[1], [_r(c[2]), _r(c[3]), _r(c[4])],
				[_r(c[5]), _r(c[6]), _r(c[7])]])
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


static func normalise(name: String) -> String:
	return name.replace("\\", "/").strip_edges().to_lower()


func _source_for(name: String) -> Source:
	var key: String = normalise(name)
	if _parsed.has(key):
		return _parsed[key]
	if _bundled.has(key) and not _given.has(key):
		return _bundled[key]
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
		_bundled[key] = source
	return source


## Where a reference resolves in a checkout's LDraw library, in the order
## tools/ldraw/library.py searches: parts and their subparts, then the
## primitives.
static func _read_library(key: String) -> String:
	for path: String in [LIBRARY + "parts/" + key, LIBRARY + "p/" + key]:
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_string(path)
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
## without those connectors.


func _connectors(name: String) -> Array:
	var found: Array = []
	_find_connectors(name, PackedFloat64Array(IDENTITY), found, 0, {})
	var seen: Dictionary = {}
	var unique: Array = []
	for c: Array in found:
		var key: String = "%s|%.2f|%.2f|%.2f|%.3f|%.3f|%.3f" % [c[0], c[2], c[3], c[4],
			c[5], c[6], c[7]]
		if seen.has(key):
			continue
		seen[key] = true
		unique.append(c)
	return unique


func _find_connectors(name: String, transform: PackedFloat64Array, found: Array,
		depth: int, stack: Dictionary) -> void:
	if depth > 64 or stack.has(name):
		return
	var source: Source = _source_for(name)
	if source == null:
		return
	var inner: Dictionary = stack.duplicate()
	inner[name] = true
	for command: Array in source.commands:
		if int(command[0]) != 1:
			continue
		var file: String = command[3]
		var stem: String = file.get_file()
		if stem.ends_with(".dat"):
			stem = stem.substr(0, stem.length() - 4)
		var child: PackedFloat64Array = _compose(transform, command[2])
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
		row.encode_u8(1, gender if gender >= 0 else 255)
		for n: int in 6:
			row.encode_float(2 + n * 4, float(c[2 + n]))
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
	grid.bits.resize(grid.shape.x * grid.shape.y * grid.shape.z)
	var xs := PackedFloat64Array()
	for i: int in grid.shape.x:
		xs.append((float(i + origin.x) + 0.5) * CELL)
	var zs := PackedFloat64Array()
	for k: int in grid.shape.z:
		zs.append((float(k + origin.z) + 0.5) * CELL)

	var crossings: Dictionary = {}   ## column index -> Array of [y, direction]
	for t: int in count:
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
		var i1: int = mini(grid.shape.x - 1, int(ceil(x1 / CELL)) - origin.x)
		var k0: int = maxi(0, int(floor(z0 / CELL)) - origin.z)
		var k1: int = mini(grid.shape.z - 1, int(ceil(z1 / CELL)) - origin.z)
		if i0 > i1 or k0 > k1:
			continue
		var direction: int = 1 if area2 > 0.0 else -1
		for i: int in range(i0, i1 + 1):
			var gx: float = xs[i]
			for k: int in range(k0, k1 + 1):
				var gz: float = zs[k]
				var w0: float = ((bx - gx) * (cz - gz) - (bz - gz) * (cx - gx)) / area2
				var w1: float = ((cx - gx) * (az - gz) - (cz - gz) * (ax - gx)) / area2
				var w2: float = 1.0 - w0 - w1
				if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
					continue
				var y: float = w0 * ay + w1 * by + w2 * cy
				var column: int = i * grid.shape.z + k
				if not crossings.has(column):
					crossings[column] = []
				(crossings[column] as Array).append([y, direction])

	var y_base := PackedFloat64Array()
	for j: int in grid.shape.y:
		y_base.append((float(j + origin.y) + 0.5) * CELL)
	for column: int in crossings:
		var hits: Array = crossings[column]
		hits.sort_custom(PartForge._before)
		var i: int = column / grid.shape.z
		var k: int = column % grid.shape.z
		var winding: int = 0
		var previous: float = 0.0
		var started: bool = false
		for hit: Array in hits:
			var height: float = hit[0]
			if winding > 0 and started:
				var first: int = y_base.bsearch(previous, true)
				var last: int = y_base.bsearch(height, false)
				for j: int in range(first, last):
					grid.put(i, j, k, 1)
			winding += int(hit[1])
			previous = height
			started = true
	return grid


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


## Close each horizontal layer's enclosed voids: scipy's binary_fill_holes,
## which fills whatever empty cells cannot reach the layer's edge through
## empty cells, four ways.
func _fill_cavities(grid: Grid) -> Grid:
	if grid.count() == 0:
		return grid
	var out: Grid = grid.copy()
	for y: int in grid.shape.y:
		var layer := PackedByteArray()
		layer.resize(grid.shape.x * grid.shape.z)
		for x: int in grid.shape.x:
			for z: int in grid.shape.z:
				layer[x * grid.shape.z + z] = grid.at(x, y, z)
		var filled: PackedByteArray = _fill_holes(layer, grid.shape.x, grid.shape.z)
		for x: int in grid.shape.x:
			for z: int in grid.shape.z:
				out.put(x, y, z, filled[x * grid.shape.z + z])
	return out


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


static func _to_boxes(grid: Grid) -> Array:
	var boxes: Array = []
	if grid.count() == 0:
		return boxes
	var remaining: PackedByteArray = grid.bits.duplicate()
	var s: Vector3i = grid.shape
	var cursor: int = 0
	while true:
		cursor = remaining.find(1, cursor)
		if cursor < 0:
			break
		if boxes.size() >= MOST_BOXES:
			return [_bounding_box(grid)]
		var x0: int = cursor / (s.y * s.z)
		var y0: int = (cursor / s.z) % s.y
		var z0: int = cursor % s.z
		var x1: int = x0 + 1
		var y1: int = y0 + 1
		var z1: int = z0 + 1
		var grown: bool = true
		while grown:
			grown = false
			if x1 < s.x and _solid(grid, x1, x1 + 1, y0, y1, z0, z1):
				x1 += 1
				grown = true
			if z1 < s.z and _solid(grid, x0, x1, y0, y1, z1, z1 + 1):
				z1 += 1
				grown = true
			if y1 < s.y and _solid(grid, x0, x1, y1, y1 + 1, z0, z1):
				y1 += 1
				grown = true
		for x: int in range(x0, x1):
			for y: int in range(y0, y1):
				for z: int in range(z0, z1):
					remaining[(x * s.y + y) * s.z + z] = 0
		boxes.append([grid.origin.x + x0, grid.origin.y + y0, grid.origin.z + z0,
			x1 - x0, y1 - y0, z1 - z0])
	return boxes


static func _solid(grid: Grid, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> bool:
	for x: int in range(x0, x1):
		for y: int in range(y0, y1):
			for z: int in range(z0, z1):
				if grid.at(x, y, z) == 0:
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
## checkout has it.
static func build(text: String, id: String, others: Dictionary = {},
		library: bool = true) -> Result:
	var forge := PartForge.new()
	forge._use_library = library
	return forge._build(text, id, others)


func _build(text: String, id: String, others: Dictionary) -> Result:
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
		result.connectors.append([c[0], c[1], c[2], -float(c[3]), -float(c[4]),
			c[5], -float(c[6]), -float(c[7])])

	var solid: Grid = _fill_cavities(_remove_studs(_voxelise(), found))
	result.cells = solid.count()
	result.boxes = _to_boxes(solid)
	result.sockets = _bottom_sockets(solid)

	result.lbm = encode(surfaces, result.bounds_min, result.bounds_max,
		result.connectors, result.boxes, result.sockets)
	result.mesh = Lbm.parse(result.lbm, id)
	if result.mesh == null:
		result.problem = "the geometry did not encode"
	return result
