## Prints of one's own: where on a part a picture goes, the part file that
## carries it, and the part built from that file with its picture on it.
##
## LDraw has a way of putting a picture on a part that other programs read:
## `0 !TEXMAP START <projection> <points> <png>` before the faces the picture
## is projected onto and `0 !TEXMAP END` after them (ldraw.org's texture map
## spec, 2020). The projection is PLANAR — three corners of the picture in
## the part's own space, the first its top left, the second its top right,
## the third its bottom left — or CYLINDRICAL, round an axis from a bottom
## centre to a top centre, the picture's middle where a third point says and
## its width an angle round. A model file carries the picture itself as a
## `0 !DATA <name>.png` section of base64 lines (the MPD spec, rev. 2), so a
## print travels inside the model like a made part does.
##
## A print here is an [Area] of a part — a head's face wrapped round its
## cylinder, a torso's front or back, the front of a pair of legs with their
## hips, the top of a tile, the face of a slope — and a picture drawn for it
## on a canvas whose pixels are that area exactly. The file is the plain
## part's own triangles (from its built mesh, as [PartEditor] writes a
## changed part), the faces of each area inside its own TEXMAP block, every
## connector in a `0 !BRICKWORKS CONNECTOR` line, and the picture beside it.
## In LDView, LDCad or anything else that reads TEXMAP the part shows its
## print; in a program that does not, it is the plain part.
##
## The app builds it as any made part — [PartForge] — with the faces under
## each picture handed over in a colour of their own, so they come out as
## surfaces of their own, which are then given texture coordinates by the
## same projection and drawn by the print shader with the picture on them.
## So a printed part has the plain part's studs, sockets and collision to
## the cell, and the picture lands where LDView puts it: the coordinates are
## worked out as LDView's TREModel.cpp works them out, U across the picture
## from the left as seen from outside, V down it from the top.
##
## Everything is in LDraw's axes: +X right, +Y down, the front of a part
## towards -Z.
class_name PartPrints
extends RefCounted

const PRINTED_BY := "0 // Printed by Brickworks:"
## And the line a sculpted part's file says what it was moulded from in.
const MOULDED_BY := "0 // Moulded by Brickworks:"
const AUTHOR := "Brickworks print designer"
## How finely a print is drawn: ten pixels to the LDU, 25 to the
## millimetre, more than a pad print holds. And no side longer than this,
## so a big tile's picture stays a size a browser keeps a few dozen of.
const PIXELS_PER_LDU := 10.0
const MOST_PIXELS := 512
## The colour the forge is handed for the faces under picture n: a code no
## palette uses, so they come out as a surface of their own.
const UNDER_PICTURE := 30000

## Parts made here from another part, and which: a print's or a mould's id
## -> the part it was made from. Filled as each is built, so a figure can
## put a printed head where the plain head goes.
static var bases: Dictionary = {}


## Where on a part a picture goes.
class Area extends RefCounted:
	## What it is called in the file's picture name and in the editor.
	var key: String = ""
	var title: String = ""
	## "PLANAR" or "CYLINDRICAL", as the TEXMAP line says it.
	var method: String = "PLANAR"
	## The three points of the TEXMAP line, in the area's own frame.
	var p1 := Vector3.ZERO
	var p2 := Vector3.ZERO
	var p3 := Vector3.ZERO
	## A cylinder's sweep in degrees: how far round the picture reaches.
	var angle: float = 0.0
	## The canvas: the picture's size in pixels.
	var size := Vector2i(256, 256)
	## The parts it covers, each {"part": id, "shift": Vector3}: a point of
	## the part plus shift is the point in the area's frame. One part but
	## for a pair of legs, whose print runs over the hips and both legs.
	var parts: Array = []
	## A planar area's outward facing, and per part the depths of the
	## faces it takes; a cylinder's radius.
	var normal := Vector3.ZERO
	var depths: Dictionary = {}     ## part index -> Array of plane depths
	## Projected straight on over every face turned its way, at any depth:
	## a dish's dome, a round tile's curved top.
	var any_depth: bool = false
	var radius: float = 0.0
	## Where the part's surface is under the canvas: white where a print
	## shows, clear where there is nothing to print on.
	var mask: Image = null
	## Lines for the editor to draw over the canvas: [[from, to]] in pixels.
	var guides: Array = []

	## The picture's coordinates of a point, 0 to 1 across and down: as
	## LDView works them out (TREModel.cpp, activateTexmap and
	## calcCylTextureCoords).
	func uv(p: Vector3) -> Vector2:
		if method == "CYLINDRICAL":
			var up: Vector3 = p2 - p1
			var height: float = up.length()
			up /= height
			var front: Vector3 = _across(p3 - p1, up).normalized()
			var here: Vector3 = _across(p - p2, up)
			if here.length() < 1e-6:
				return Vector2(0.5, up.dot(p2 - p) / height)
			here = here.normalized()
			var turn: float = atan2(front.cross(here).dot(up), here.dot(front))
			return Vector2(0.5 + turn / deg_to_rad(angle), up.dot(p2 - p) / height)
		var across: Vector3 = p2 - p1
		var down: Vector3 = p3 - p1
		return Vector2((p - p1).dot(across) / across.length_squared(),
			(p - p1).dot(down) / down.length_squared())

	static func _across(v: Vector3, axis: Vector3) -> Vector3:
		return v - axis * v.dot(axis)

	## Whether the picture goes on a triangle of part [param index], its
	## corners already in the area's frame.
	func takes(index: int, a: Vector3, b: Vector3, c: Vector3) -> bool:
		var n: Vector3 = (b - a).cross(c - a)
		if n.length() < 1e-9:
			return false
		n = n.normalized()
		var middle: Vector3 = (a + b + c) / 3.0
		var at: Vector2 = uv(middle)
		if at.x < -0.02 or at.x > 1.02 or at.y < -0.02 or at.y > 1.02:
			return false
		if method == "CYLINDRICAL":
			var up: Vector3 = (p2 - p1).normalized()
			var out: Vector3 = _across(middle - p1, up)
			if out.length() < radius - 2.5:
				return false
			return n.dot(out.normalized()) > 0.3
		if any_depth:
			return n.dot(normal) >= 0.3
		if n.dot(normal) < 0.9:
			return false
		for depth: float in depths.get(index, []):
			if absf(normal.dot(middle) - depth) <= 0.6:
				return true
		return false

	## The TEXMAP line for a part of the area, its points in that part's
	## own frame.
	func start_line(picture: String, shift: Vector3) -> String:
		var words := PackedStringArray(["0 !TEXMAP START", method])
		for p: Vector3 in [p1 - shift, p2 - shift, p3 - shift]:
			words.append_array([PartEditor._n(p.x), PartEditor._n(p.y), PartEditor._n(p.z)])
		if method == "CYLINDRICAL":
			words.append(PartEditor._n(angle))
		words.append(picture)
		return " ".join(words)

	## The canvas pixel of a point of the area.
	func pixel(p: Vector3) -> Vector2:
		var at: Vector2 = uv(p)
		return Vector2(at.x * size.x, at.y * size.y)


# -- where a part can be printed --------------------------------------------


## The areas of a part a print can go on, best first: a head's face and the
## back of it, a torso's front and back, a pair of legs' front over their
## hips, a tile's top, a slope's face, or any other part's largest faces.
## [param with] names the parts a pair of legs is printed with: {"hips":
## id, "left": id}, either left out.
static func areas_for(library: PartLibrary, part_id: String, with: Dictionary = {}) \
		-> Array[Area]:
	var out: Array[Area] = []
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if info == null or mesh == null:
		return out
	var shape: PartEditor.Shape = PartEditor.shape_of(mesh)
	var slot: String = Minifig.slot_for(info)
	if slot == "head":
		out = _cylinder_areas(part_id, shape)
		if not out.is_empty():
			return out
	if slot == "torso":
		for facing: Array in [[Vector3(0, 0, -1), "front", "Front"],
				[Vector3(0, 0, 1), "back", "Back"]]:
			var area: Area = _planar(facing[1], facing[2], facing[0],
				[{"part": part_id, "shape": shape, "shift": Vector3.ZERO}])
			if area != null:
				out.append(area)
		if not out.is_empty():
			return out
	if slot == "legs" and Minifig.side_of(info) == "r":
		var parts: Array = []
		var hips: String = str(with.get("hips", ""))
		var left: String = str(with.get("left", ""))
		if not hips.is_empty() and library.mesh_for(hips) != null:
			parts.append({"part": hips, "shape": PartEditor.shape_of(library.mesh_for(hips)),
				"shift": Vector3.ZERO})
		# The legs hang 12 under the hips' joint, as a figure has them.
		var shift := Vector3(0, LEGS_UNDER_HIPS if not parts.is_empty() else 0.0, 0)
		parts.append({"part": part_id, "shape": shape, "shift": shift})
		if not left.is_empty() and library.mesh_for(left) != null:
			parts.append({"part": left, "shape": PartEditor.shape_of(library.mesh_for(left)),
				"shift": shift})
		var legs: Area = _planar("legs", "Front", Vector3(0, 0, -1), parts)
		if legs != null:
			out.append(legs)
			return out
	return _largest_faces(part_id, shape)


## How far a figure's legs sit under its hips: 3816c.dat's "Move down 12
## units to align with hips", which Minifig.LEGS and HIPS say too.
const LEGS_UNDER_HIPS := 12.0


## A head's face and the back of it, each half the way round its cylinder,
## from a little above where the cylinder starts to a little below where it
## ends: the band a face is printed on, its rounded top and chin included.
## None for a head that is not round.
static func _cylinder_areas(part_id: String, shape: PartEditor.Shape) -> Array[Area]:
	var out: Array[Area] = []
	var widest: float = 0.0
	for v: int in shape.tris.size() / 3:
		widest = maxf(widest, Vector2(shape.tris[v * 3], shape.tris[v * 3 + 2]).length())
	# To a hundredth: 3626c's widest corner is 13.0025 off its axis in the
	# mesh's 64ths, and its cylinder is 13.
	widest = snappedf(widest, 0.01)
	if widest < 6.0:
		return out
	var top: float = INF
	var bottom: float = -INF
	var on_it: float = 0.0
	var all: float = 0.0
	for t: int in shape.count():
		var o: int = t * 9
		var a := Vector3(shape.tris[o], shape.tris[o + 1], shape.tris[o + 2])
		var b := Vector3(shape.tris[o + 3], shape.tris[o + 4], shape.tris[o + 5])
		var c := Vector3(shape.tris[o + 6], shape.tris[o + 7], shape.tris[o + 8])
		var area: float = (b - a).cross(c - a).length() * 0.5
		all += area
		var round_here: bool = true
		for p: Vector3 in [a, b, c]:
			if Vector2(p.x, p.z).length() < widest - 0.3:
				round_here = false
		if round_here:
			on_it += area
			for p: Vector3 in [a, b, c]:
				top = minf(top, p.y)
				bottom = maxf(bottom, p.y)
	# A round head is mostly its cylinder (3626c: 30% of its faces, the
	# rest its top, its neck and the insides of both); a sculpted one is
	# not, and gets its largest faces instead.
	if all <= 0.0 or on_it / all < 0.2 or bottom - top < 6.0:
		return out
	top -= 3.0
	bottom += 3.0
	for facing: Array in [[-1.0, "face", "Face"], [1.0, "back", "Back of the head"]]:
		var area := Area.new()
		area.key = facing[1]
		area.title = facing[2]
		area.method = "CYLINDRICAL"
		area.p1 = Vector3(0, bottom, 0)
		area.p2 = Vector3(0, top, 0)
		area.p3 = Vector3(0, bottom, float(facing[0]) * widest)
		area.angle = 180.0
		area.radius = widest
		area.parts = [{"part": part_id, "shift": Vector3.ZERO}]
		var wide: float = PI * widest
		area.size = _canvas(wide, bottom - top)
		area.mask = _mask(area, [shape])
		# The front, and where the cylinder starts and stops curving.
		area.guides = [[Vector2(area.size.x * 0.5, 0), Vector2(area.size.x * 0.5, area.size.y)]]
		for y: float in [top + 3.0, bottom - 3.0]:
			var row: float = (y - top) / (bottom - top) * area.size.y
			area.guides.append([Vector2(0, row), Vector2(area.size.x, row)])
		out.append(area)
	return out


## A flat area facing [param normal] over some parts: on each, the largest
## face turned that way and whatever faces it further out (a leg's foot
## below its shin), all projected straight on. Null when no part has a face
## turned that way.
static func _planar(key: String, title: String, normal: Vector3, parts: Array,
		any_depth: bool = false) -> Area:
	var area := Area.new()
	area.key = key
	area.title = title
	area.method = "PLANAR"
	area.normal = normal.normalized()
	area.any_depth = any_depth
	var shapes: Array = []
	for index: int in parts.size():
		var entry: Dictionary = parts[index]
		var shape: PartEditor.Shape = entry["shape"]
		var shift: Vector3 = entry["shift"]
		var depths: Array = [] if any_depth else _depths(shape, area.normal, shift)
		if depths.is_empty() and not any_depth:
			continue
		area.depths[area.parts.size()] = depths
		area.parts.append({"part": entry["part"], "shift": shift})
		shapes.append(shape)
	if area.parts.is_empty():
		return null
	# The picture's up is the part's up, seen from outside; for a face
	# looking up or down, the back of the part is the top of the picture.
	var world_up := Vector3(0, -1, 0)
	var up: Vector3 = world_up - area.normal * world_up.dot(area.normal)
	if up.length() < 0.3:
		up = Vector3(0, 0, 1) - area.normal * area.normal.z
	up = up.normalized()
	var down: Vector3 = -up
	var right: Vector3 = down.cross(-area.normal)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var outer: float = -INF
	for index: int in area.parts.size():
		var shape: PartEditor.Shape = shapes[index]
		var shift: Vector3 = area.parts[index]["shift"]
		for t: int in shape.count():
			var corners: Array[Vector3] = _corners(shape, t, shift)
			if not _faces(area, index, corners):
				continue
			for p: Vector3 in corners:
				lo = lo.min(Vector2(p.dot(right), p.dot(down)))
				hi = hi.max(Vector2(p.dot(right), p.dot(down)))
				outer = maxf(outer, p.dot(area.normal))
	if lo.x >= hi.x or lo.y >= hi.y:
		return null
	# Half an LDU spare round the edge, so the picture's border is clear
	# and a program that stretches the edge pixels stretches nothing.
	lo -= Vector2(0.5, 0.5)
	hi += Vector2(0.5, 0.5)
	area.p1 = right * lo.x + down * lo.y + area.normal * outer
	area.p2 = area.p1 + right * (hi.x - lo.x)
	area.p3 = area.p1 + down * (hi.y - lo.y)
	area.size = _canvas(hi.x - lo.x, hi.y - lo.y)
	area.mask = _mask(area, shapes)
	area.guides = [[Vector2(area.size.x * 0.5, 0), Vector2(area.size.x * 0.5, area.size.y)]]
	return area


## The depths of the faces of a part a flat area takes: its largest face
## turned that way, and any as large as a third of it standing further out.
static func _depths(shape: PartEditor.Shape, normal: Vector3, shift: Vector3) -> Array:
	var by_depth: Dictionary = {}
	for t: int in shape.count():
		var corners: Array[Vector3] = _corners(shape, t, shift)
		var n: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0])
		var area: float = n.length() * 0.5
		if area < 1e-6 or n.normalized().dot(normal) < 0.9:
			continue
		var depth: float = snappedf(normal.dot((corners[0] + corners[1] + corners[2]) / 3.0), 0.5)
		by_depth[depth] = float(by_depth.get(depth, 0.0)) + area
	if by_depth.is_empty():
		return []
	var main: float = by_depth.keys()[0]
	for depth: float in by_depth:
		if float(by_depth[depth]) > float(by_depth[main]):
			main = depth
	if float(by_depth[main]) < 20.0:
		return []
	var out: Array = [main]
	for depth: float in by_depth:
		if depth > main + 0.25 and float(by_depth[depth]) >= float(by_depth[main]) / 3.0:
			out.append(depth)
	return out


static func _faces(area: Area, index: int, corners: Array[Vector3]) -> bool:
	var n: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0])
	if area.any_depth:
		return n.length() >= 1e-9 and n.normalized().dot(area.normal) >= 0.3
	if n.length() < 1e-9 or n.normalized().dot(area.normal) < 0.9:
		return false
	var depth: float = area.normal.dot((corners[0] + corners[1] + corners[2]) / 3.0)
	for wanted: float in area.depths.get(index, []):
		if absf(depth - wanted) <= 0.6:
			return true
	return false


## The biggest faces of any other part, turned out from it — a tile's top,
## a slope's face, a panel's front — at most four, the largest first.
static func _largest_faces(part_id: String, shape: PartEditor.Shape) -> Array[Area]:
	var directions: Dictionary = {}
	for t: int in shape.count():
		var corners: Array[Vector3] = _corners(shape, t, Vector3.ZERO)
		var n: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0])
		var area: float = n.length() * 0.5
		if area < 1e-6:
			continue
		n = n.normalized()
		# Nothing printed underneath.
		if n.y > 0.5:
			continue
		var key := Vector3(snappedf(n.x, 0.05) + 0.0, snappedf(n.y, 0.05) + 0.0,
			snappedf(n.z, 0.05) + 0.0)
		directions[key] = float(directions.get(key, 0.0)) + area
	var keys: Array = directions.keys()
	keys.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return float(directions[a]) > float(directions[b]))
	var out: Array[Area] = []
	var used: Dictionary = {}
	# A top that is not flat — a dish's dome, a round tile's rounded top —
	# printed from above over all of it.
	var upward: float = 0.0
	var all: float = 0.0
	for key: Vector3 in directions:
		all += float(directions[key])
		if key.y <= -0.3:
			upward += float(directions[key])
	# Curved, not faceted: no one way up has half of it, and it faces
	# many ways. A slope's face is one way, and is a face of its own.
	var largest_up: float = 0.0
	var ways: int = 0
	for key: Vector3 in directions:
		if key.y <= -0.3:
			largest_up = maxf(largest_up, float(directions[key]))
			ways += 1
	# 3960's dish: no way up has 7% of it; 3037's slope face has 53%.
	if upward > all * 0.15 and largest_up < upward * 0.45 and ways >= 6:
		var dome: Area = _planar("dome", "Top, curved", Vector3(0, -1, 0),
			[{"part": part_id, "shape": shape, "shift": Vector3.ZERO}], true)
		if dome != null:
			used["dome"] = true
			out.append(dome)
	for key: Vector3 in keys:
		if out.size() >= 4 or float(directions[key]) < float(directions[keys[0]]) * 0.15:
			break
		var named: Array = _named(key)
		if used.has(named[0]):
			continue
		var area: Area = _planar(named[0], named[1], key,
			[{"part": part_id, "shape": shape, "shift": Vector3.ZERO}])
		if area != null:
			used[named[0]] = true
			out.append(area)
	return out


## What a face turned some way is called on a part seen from its front.
static func _named(n: Vector3) -> Array:
	if n.y < -0.9:
		return ["top", "Top"]
	if n.y < -0.25 and absf(n.z) >= absf(n.x):
		return ["slope", "Slope"] if n.z < 0.0 else ["slope_back", "Back slope"]
	if n.y < -0.25:
		return ["slope_side", "Side slope"]
	if absf(n.z) >= absf(n.x):
		return ["front", "Front"] if n.z < 0.0 else ["back", "Back"]
	return ["right", "Right side"] if n.x > 0.0 else ["left", "Left side"]


static func _corners(shape: PartEditor.Shape, t: int, shift: Vector3) -> Array[Vector3]:
	var o: int = t * 9
	return [Vector3(shape.tris[o], shape.tris[o + 1], shape.tris[o + 2]) + shift,
		Vector3(shape.tris[o + 3], shape.tris[o + 4], shape.tris[o + 5]) + shift,
		Vector3(shape.tris[o + 6], shape.tris[o + 7], shape.tris[o + 8]) + shift]


## A canvas for an area so many LDU across and down.
static func _canvas(across: float, down: float) -> Vector2i:
	var scale: float = minf(PIXELS_PER_LDU, MOST_PIXELS / maxf(across, down))
	return Vector2i(maxi(8, roundi(across * scale)), maxi(8, roundi(down * scale)))


## Where the area's faces are on its canvas.
static func _mask(area: Area, shapes: Array) -> Image:
	var mask := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	for index: int in area.parts.size():
		var shape: PartEditor.Shape = shapes[index]
		var shift: Vector3 = area.parts[index]["shift"]
		for t: int in shape.count():
			var corners: Array[Vector3] = _corners(shape, t, shift)
			if area.takes(index, corners[0], corners[1], corners[2]):
				fill_triangle(mask, area.pixel(corners[0]), area.pixel(corners[1]),
					area.pixel(corners[2]), Color.WHITE)
	return mask


## A triangle filled in one colour, a row at a time: every pixel whose
## middle is inside it.
static func fill_triangle(image: Image, a: Vector2, b: Vector2, c: Vector2,
		color: Color) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var top: int = maxi(0, ceili(minf(a.y, minf(b.y, c.y)) - 0.5))
	var bottom: int = mini(h - 1, floori(maxf(a.y, maxf(b.y, c.y)) - 0.5))
	var edges: Array = [[a, b], [b, c], [c, a]]
	for y: int in range(top, bottom + 1):
		var row: float = float(y) + 0.5
		var left: float = INF
		var right: float = -INF
		for edge: Array in edges:
			var p: Vector2 = edge[0]
			var q: Vector2 = edge[1]
			if (p.y <= row and q.y > row) or (q.y <= row and p.y > row):
				var x: float = p.x + (row - p.y) / (q.y - p.y) * (q.x - p.x)
				left = minf(left, x)
				right = maxf(right, x)
		if left > right:
			continue
		var x0: int = maxi(0, ceili(left - 0.5))
		var x1: int = mini(w - 1, floori(right - 0.5))
		if x1 >= x0:
			image.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), color)


# -- starting from a print LEGO made ------------------------------------------


## A real printed part's print, as a picture on an area of its plain mould:
## the faces of the print — every one not in the part's own colour — drawn
## onto the canvas in their inks. 3626cp01's grin on the face of 3626c.
static func picture_of(library: PartLibrary, printed: String, area: Area, part_index: int = 0) \
		-> Image:
	var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	var mesh: Lbm.PartMesh = library.mesh_for(printed)
	if mesh == null:
		return picture
	var shape: PartEditor.Shape = PartEditor.shape_of(mesh)
	var shift: Vector3 = area.parts[part_index]["shift"] if part_index < area.parts.size() \
		else Vector3.ZERO
	for t: int in shape.count():
		var code: int = shape.colors[t]
		if code == Lbm.COLOR_INHERIT:
			continue
		var corners: Array[Vector3] = _corners(shape, t, shift)
		if not _print_on(area, part_index, corners):
			continue
		var ink: Color = library.color(code).rgb
		ink.a = 1.0
		fill_triangle(picture, area.pixel(corners[0]), area.pixel(corners[1]),
			area.pixel(corners[2]), ink)
	return picture


## Whether a face of a printed part is print on the area: on a cylinder,
## on its surface and inside the picture; on a flat area, facing its way
## within a cell of one of its faces. A print's faces lie on the part's or
## a hair over it.
static func _print_on(area: Area, index: int, corners: Array[Vector3]) -> bool:
	if area.method == "CYLINDRICAL":
		return area.takes(index, corners[0], corners[1], corners[2])
	var n: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0])
	if n.length() < 1e-9 or n.normalized().dot(area.normal) < 0.9:
		return false
	var middle: Vector3 = (corners[0] + corners[1] + corners[2]) / 3.0
	var at: Vector2 = area.uv(middle)
	if at.x < 0.0 or at.x > 1.0 or at.y < 0.0 or at.y > 1.0:
		return false
	for wanted: float in area.depths.get(index, []):
		if absf(area.normal.dot(middle) - wanted) <= 1.0:
			return true
	return false


## Printed parts of the same mould LEGO made, to start from: 3626cp01 and
## the rest for 3626c, the most used first. At most [param most].
static func prints_of(library: PartLibrary, mould: String, most: int = 60) \
		-> Array[PartLibrary.PartInfo]:
	var out: Array[PartLibrary.PartInfo] = []
	for id: String in library.parts:
		if id == mould or not id.begins_with(mould) or Minifig._family(id) != mould:
			continue
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect() or not info.reachable or info.custom:
			continue
		out.append(info)
	out.sort_custom(func(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
		if a.in_sets != b.in_sets:
			return a.in_sets > b.in_sets
		return a.id.naturalnocasecmp_to(b.id) < 0)
	return out.slice(0, most)


# -- the part file ------------------------------------------------------------


## The part to print on for a part chosen to start from: its plain mould
## (3626c for 3626cp01), the part itself where there is none.
static func mould_of(library: PartLibrary, part_id: String) -> String:
	var base: String = str(bases.get(part_id, part_id))
	var plain: String = Minifig._family(base)
	return plain if library.parts.has(plain) else base


## A print's id: the part it is on and a tag from what is on it, so the
## same print twice is the same part and any change is another.
static func id_for(base: String, tag: String) -> String:
	var source: String = ""
	for n: int in base.length():
		var ch: String = base[n].to_lower()
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			source += ch
	return "bw-%s-p%s" % [source.left(10), tag]


## Six hex digits from everything that makes a print what it is.
static func tag_of(things: Array) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	for thing: Variant in things:
		if thing is PackedByteArray:
			hashing.update(thing)
		else:
			hashing.update(str(thing).to_utf8_buffer())
	return hashing.finish().hex_encode().left(6)


## The picture's file name for an area of a print.
static func picture_name(print_id: String, area: Area) -> String:
	return "%s-%s.png" % [print_id, area.key]


## The part file of a print: the plain part's triangles, each area's
## inside a TEXMAP block naming its picture, its connectors and creases.
## [param areas] is [[Area, picture file name]]; [param index] which of an
## area's parts this file is (a pair of legs is three files).
static func part_text(library: PartLibrary, base: String, id: String, title: String,
		areas: Array, index: int = 0) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(base)
	var mesh: Lbm.PartMesh = library.mesh_for(base)
	if info == null or mesh == null:
		return ""
	var shape: PartEditor.Shape = PartEditor.shape_of(mesh)
	var name: String = Minifig._plain(info.name).trim_prefix("~").trim_prefix("=")
	var words: String = title.strip_edges().replace("\n", " ")
	var out := PackedStringArray()
	out.append("0 %s, Custom Print %s" % [name, words if not words.is_empty() else id])
	out.append("0 Name: %s.dat" % id)
	out.append("0 Author: " + AUTHOR)
	out.append("0 !LDRAW_ORG Unofficial_Part")
	out.append("0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt")
	out.append("")
	out.append("0 BFC CERTIFY CCW")
	out.append("")
	var category: String = info.ldraw_category if info.custom else info.category
	out.append("0 !CATEGORY " + (category if not category.is_empty() else "Minifig"))
	out.append("0 !KEYWORDS Brickworks, custom print")
	out.append("")
	var keys := PackedStringArray()
	for pair: Array in areas:
		keys.append((pair[0] as Area).key)
	out.append("%s from=%s areas=%s" % [PRINTED_BY, base, ",".join(keys)])
	out.append("0 // Made from %s.dat of the LDraw Parts Library (CC BY 4.0) as the app" % base)
	out.append("0 // built it, its faces under each picture inside that picture's TEXMAP block.")
	out.append("")
	out.append("0 // Connectors, for programs that read them")
	for c: Array in shape.connectors:
		var line: String = "0 %s CONNECTOR %s %s %s %s %s %s %s %s" % [PartEditor.CONNECTOR,
			c[0], c[1], PartEditor._n(c[2]), PartEditor._n(c[3]), PartEditor._n(c[4]),
			PartEditor._n(c[5]), PartEditor._n(c[6]), PartEditor._n(c[7])]
		if float(c[8]) > 0.0:
			line += " %s %s" % [PartEditor._n(c[8]), PartEditor._n(c[9])]
		out.append(line)
	# Each face goes under the first picture that takes it.
	var taken := PackedInt32Array()
	taken.resize(shape.count())
	taken.fill(-1)
	for n: int in areas.size():
		var area: Area = areas[n][0]
		var part_index: int = _part_index(area, base, index)
		if part_index < 0:
			continue
		var shift: Vector3 = area.parts[part_index]["shift"]
		for t: int in shape.count():
			if taken[t] >= 0:
				continue
			var corners: Array[Vector3] = _corners(shape, t, shift)
			if area.takes(part_index, corners[0], corners[1], corners[2]):
				taken[t] = n
	for n: int in areas.size():
		var area: Area = areas[n][0]
		var part_index: int = _part_index(area, base, index)
		if part_index < 0 or not taken.has(n):
			continue
		out.append("")
		out.append("0 // %s" % area.title)
		out.append(area.start_line(str(areas[n][1]), area.parts[part_index]["shift"]))
		_write_faces(out, shape, taken, n)
		out.append("0 !TEXMAP END")
	out.append("")
	out.append("0 // Faces")
	_write_faces(out, shape, taken, -1)
	out.append("0 // Edges")
	for n: int in shape.lines.size() / 6:
		var o: int = n * 6
		out.append("2 24 %s %s %s %s %s %s" % [PartEditor._n(shape.lines[o]),
			PartEditor._n(shape.lines[o + 1]), PartEditor._n(shape.lines[o + 2]),
			PartEditor._n(shape.lines[o + 3]), PartEditor._n(shape.lines[o + 4]),
			PartEditor._n(shape.lines[o + 5])])
	out.append("0")
	return "\n".join(out) + "\n"


## Which of an area's parts a file is for: the one that is [param base],
## or the given index.
static func _part_index(area: Area, base: String, index: int) -> int:
	for n: int in area.parts.size():
		if str(area.parts[n]["part"]) == base:
			return n
	return index if index < area.parts.size() else -1


static func _write_faces(out: PackedStringArray, shape: PartEditor.Shape, taken: PackedInt32Array,
		which: int) -> void:
	var open: bool = false
	for t: int in shape.count():
		if taken[t] != which:
			continue
		var sided: bool = shape.two_sided[t] == 1
		if sided and not open:
			out.append("0 BFC NOCLIP")
			open = true
		elif not sided and open:
			out.append("0 BFC CLIP")
			open = false
		var o: int = t * 9
		var words := PackedStringArray(["3", str(shape.colors[t])])
		for k: int in 9:
			words.append(PartEditor._n(shape.tris[o + k]))
		out.append(" ".join(words))
	if open:
		out.append("0 BFC CLIP")


## Whether a part file is a print made here.
static func is_print(text: String) -> bool:
	return text.contains(PRINTED_BY) and text.contains("!TEXMAP START")


## Whether a part file carries pictures it needs to be built with: a print
## or a sticker.
static func has_pictures(text: String) -> bool:
	return text.contains("0 !TEXMAP START")


## The name someone gave a print, a mould or a sticker, read out of its
## title ("Tile 2 x 2, Custom Print Monument Valley", "Sticker 31.4 x 15.4
## mm, Brick Street"); empty for any other part.
static func given_name(title: String) -> String:
	for mark: String in ["Custom Print ", "Custom Mould "]:
		if title.contains(mark):
			return title.get_slice(mark, 1).strip_edges()
	if title.begins_with("Sticker ") and title.contains(", "):
		return title.get_slice(", ", 1).strip_edges()
	return ""


## The parts bin's category for a made part: "My prints", "My stickers",
## or "Custom" for any other.
static func bin_for(text: String) -> String:
	if text.contains(Stickers.STICKER_BY):
		return MY_STICKERS
	if is_print(text):
		return MY_PRINTS
	return "Custom"


const MY_PRINTS := "My prints"
const MY_STICKERS := "My stickers"


## The part a print or a mould was made from, from its header, or "".
static func base_in(text: String) -> String:
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		for lead: String in [PRINTED_BY, MOULDED_BY]:
			if line.begins_with(lead):
				for word: String in line.substr(lead.length()).split(" ", false):
					if word.begins_with("from="):
						return word.substr(5)
	return ""


## What a print or mould made here is called, said as the builder says
## it: "print: Captain", "mould: Quiff".
static func made_title(name: String) -> String:
	for kind: String in ["Print", "Mould"]:
		var lead: String = ", Custom %s " % kind
		if name.contains(lead):
			return "%s: %s" % [kind.to_lower(), name.get_slice(lead, 1)]
	return name


## The part a figure should treat this one as: a print's or mould's plain
## part, or the part itself.
static func base_of(part_id: String) -> String:
	return str(bases.get(part_id, part_id))


## The pictures a print's file names, in order.
static func pictures_named(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 !TEXMAP START") or line.begins_with("0 !TEXMAP NEXT"):
			var words: PackedStringArray = line.split(" ", false)
			var name: String = words[words.size() - 1]
			if not out.has(name):
				out.append(name)
	return out


# -- building a printed part ----------------------------------------------------


## Build a print's part file with its pictures on it: [PartForge]'s build,
## with each TEXMAP block's faces in a surface of their own given texture
## coordinates and the block's picture. [param pictures] is file name ->
## PNG bytes. The result's problem says what is missing, if anything.
static func build(text: String, id: String, pictures: Dictionary) -> PartForge.Result:
	var blocks: Array = []        ## per block: {method, points, angle, picture}
	var lines := PackedStringArray()
	var block: int = -1
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 !TEXMAP START"):
			var words: PackedStringArray = line.split(" ", false)
			if words.size() < 14:
				lines.append(raw)
				continue
			var numbers := PackedFloat64Array()
			for n: int in range(4, 13):
				numbers.append(words[n].to_float())
			var cylinder: bool = words[3].to_upper() == "CYLINDRICAL"
			blocks.append({"method": words[3].to_upper(), "points": numbers,
				"angle": words[13].to_float() if cylinder else 0.0,
				"picture": words[words.size() - 1]})
			block = blocks.size() - 1
			lines.append(raw)
			continue
		if line.begins_with("0 !TEXMAP END"):
			block = -1
		var words: PackedStringArray = line.split(" ", false)
		if block >= 0 and words.size() > 2 and (words[0] == "3" or words[0] == "4") \
				and words[1] == "16":
			words[1] = str(UNDER_PICTURE + block)
			lines.append(" ".join(words))
		else:
			lines.append(raw)
	var built: PartForge.Result = PartForge.build("\n".join(lines), id)
	if not built.problem.is_empty() or built.mesh == null:
		return built
	var mesh: Lbm.PartMesh = built.mesh
	for n: int in mesh.surfaces.size():
		var code: int = mesh.surface_colors[n]
		if code < UNDER_PICTURE or code >= UNDER_PICTURE + blocks.size():
			continue
		var at: Dictionary = blocks[code - UNDER_PICTURE]
		var name: String = at["picture"]
		var bytes: PackedByteArray = pictures.get(name, PackedByteArray())
		var picture := Image.new()
		if bytes.is_empty() or picture.load_png_from_buffer(bytes) != OK:
			built.problem = "its picture %s is missing" % name
			return built
		mesh.surfaces[n] = _with_uv(mesh.surfaces[n], _area_of(at))
		mesh.surface_colors[n] = Lbm.COLOR_INHERIT
		mesh.prints[n] = texture_of(picture)
		(mesh.prints[n] as Texture2D).resource_name = name
		mesh.print_files[name] = bytes
	return built


## An area standing for a TEXMAP line read back, enough to work out its
## coordinates.
static func _area_of(block: Dictionary) -> Area:
	var area := Area.new()
	var p: PackedFloat64Array = block["points"]
	area.method = block["method"]
	area.p1 = Vector3(p[0], p[1], p[2])
	area.p2 = Vector3(p[3], p[4], p[5])
	area.p3 = Vector3(p[6], p[7], p[8])
	area.angle = block["angle"]
	return area


## A surface with texture coordinates from a projection: its points are in
## the app's axes, the projection in LDraw's.
static func _with_uv(surface: ArrayMesh, area: Area) -> ArrayMesh:
	var arrays: Array = surface.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	uvs.resize(positions.size())
	for v: int in positions.size():
		var p: Vector3 = positions[v]
		uvs[v] = area.uv(Vector3(p.x, -p.y, -p.z))
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.custom_aabb = surface.custom_aabb
	return out


## A picture as the renderer wants it: mipmapped, so a print far off is
## its average and not a shimmer.
static func texture_of(picture: Image) -> ImageTexture:
	var copy: Image = picture.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	copy.generate_mipmaps()
	return ImageTexture.create_from_image(copy)


## The picture an area's canvas comes to in the file: what was drawn, kept
## to where the part is (a pixel's grace round the edge, so the print
## meets the part's edge), with its outermost pixels clear.
static func finished(drawn: Image, area: Area) -> Image:
	var out: Image = drawn.duplicate()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var w: int = out.get_width()
	var h: int = out.get_height()
	if area.mask != null and area.mask.get_size() == out.get_size():
		# The mask grown by a pixel each way, then only what it covers
		# copied: both done by the engine, not a pixel at a time.
		var grown: Image = area.mask.duplicate()
		var whole := Rect2i(0, 0, w, h)
		for step: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
				Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1),
				Vector2i(1, 1)]:
			grown.blend_rect(area.mask, whole, step)
		var kept := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		kept.blit_rect_mask(out, grown, whole, Vector2i.ZERO)
		out = kept
	var clear := Color(0, 0, 0, 0)
	out.fill_rect(Rect2i(0, 0, w, 1), clear)
	out.fill_rect(Rect2i(0, h - 1, w, 1), clear)
	out.fill_rect(Rect2i(0, 0, 1, h), clear)
	out.fill_rect(Rect2i(w - 1, 0, 1, h), clear)
	return out


# -- making one ----------------------------------------------------------------


## Make a print and add it to the library: [param drawn] is area key ->
## the canvas's picture, for the areas of [param base] (from
## [method areas_for]). Returns {"ids": the parts made (a pair of legs
## makes three), "problem"}. Each part's picture files are kept beside it.
static func make(library: PartLibrary, base: String, areas: Array[Area], drawn: Dictionary,
		title: String, keep: bool = true) -> Dictionary:
	var pictures: Dictionary = {}       ## area key -> PNG bytes
	var tag_parts: Array = [base, title]
	for area: Area in areas:
		if not drawn.has(area.key):
			continue
		var picture: Image = finished(drawn[area.key], area)
		if picture.is_invisible():
			continue
		var bytes: PackedByteArray = picture.save_png_to_buffer()
		pictures[area.key] = bytes
		tag_parts.append_array([area.key, bytes])
	if pictures.is_empty():
		return {"ids": [], "problem": "nothing is drawn on it yet"}
	var tag: String = tag_of(tag_parts)
	var first_id: String = id_for(base, tag)
	# Every part the drawn areas cover, each with the areas on it.
	var part_ids: Array = []
	for area: Area in areas:
		if not pictures.has(area.key):
			continue
		for entry: Dictionary in area.parts:
			if not part_ids.has(entry["part"]):
				part_ids.append(entry["part"])
	var made: Array = []
	for part: String in part_ids:
		var id: String = id_for(part, tag)
		var on_it: Array = []
		var files: Dictionary = {}
		for area: Area in areas:
			if not pictures.has(area.key):
				continue
			for entry: Dictionary in area.parts:
				if str(entry["part"]) == part:
					var name: String = picture_name(first_id, area)
					on_it.append([area, name])
					files[name] = pictures[area.key]
		var text: String = part_text(library, part, id, title, on_it)
		if text.is_empty():
			return {"ids": made, "problem": "there is no geometry for %s to print on" % part}
		var result: Dictionary = CustomParts.add(library, text, id, keep, files)
		if not str(result["problem"]).is_empty():
			return {"ids": made, "problem": result["problem"]}
		made.append(id)
	return {"ids": made, "problem": ""}


## The pictures of a print, by area key, read back off its built part:
## to change a print made before.
static func pictures_of(library: PartLibrary, print_id: String) -> Dictionary:
	var out: Dictionary = {}
	var mesh: Lbm.PartMesh = library.mesh_for(print_id)
	if mesh == null:
		return out
	for name: String in mesh.print_files:
		var picture := Image.new()
		if picture.load_png_from_buffer(mesh.print_files[name]) == OK:
			var key: String = name.get_basename().get_slice("-", name.get_basename()
				.get_slice_count("-") - 1)
			out[key] = picture
	return out


# -- drawing it ----------------------------------------------------------------


const PRINT_SHADERS := {
	false: preload("res://src/render/plastic_print.gdshader"),
	true: preload("res://src/render/plastic_print_two_sided.gdshader"),
}


## The material that draws a printed surface: [param plain]'s settings, the
## print shader, and the picture.
static func material_for(plain: ShaderMaterial, picture: Texture2D, two_sided: bool) \
		-> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PRINT_SHADERS[two_sided]
	for name: String in ["linearise", "part_box_min", "part_box_max", "tint_override",
			"finish_override"]:
		var value: Variant = plain.get_shader_parameter(name)
		if value != null:
			material.set_shader_parameter(name, value)
	material.render_priority = plain.render_priority
	material.set_shader_parameter("print_texture", picture)
	return material


# -- seeing it while it is drawn ------------------------------------------------


## The parts an area covers, cut up for a live preview: per part, its faces
## under each area as a mesh with the area's texture coordinates, and the
## rest as plain meshes, in the app's axes and placed by the area's shift.
## [{"mesh", "area" (key, or "" for plain plastic), "part", "colour": the
## code moulded in or 16, "two_sided"}].
static func preview_meshes(library: PartLibrary, areas: Array[Area]) -> Array:
	var parts: Array = []        ## [part id, LDraw shift]
	for area: Area in areas:
		for entry: Dictionary in area.parts:
			var known: bool = false
			for seen: Array in parts:
				known = known or str(seen[0]) == str(entry["part"])
			if not known:
				parts.append([str(entry["part"]), entry["shift"]])
	var out: Array = []
	for seen: Array in parts:
		var part: String = seen[0]
		var shift: Vector3 = seen[1]
		var mesh: Lbm.PartMesh = library.mesh_for(part)
		if mesh == null:
			continue
		for n: int in mesh.surfaces.size():
			var arrays: Array = mesh.surfaces[n].surface_get_arrays(0)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			## Area index (or -1) -> the corners of its triangles. An Array:
			## a packed array read back out of a container is a copy, and
			## appending to it appends to nothing.
			var pieces: Dictionary = {}
			for t: int in indices.size() / 3:
				var corner: Array[int] = [indices[t * 3], indices[t * 3 + 1], indices[t * 3 + 2]]
				# The engine's a, c, b is LDraw's a, b, c.
				var lp: Array[Vector3] = []
				for k: int in [0, 2, 1]:
					var p: Vector3 = positions[corner[k]]
					lp.append(Vector3(p.x, -p.y, -p.z) + shift)
				var which: int = -1
				if mesh.surface_colors[n] == Lbm.COLOR_INHERIT:
					for a: int in areas.size():
						var index: int = _part_index(areas[a], part, -1)
						if index >= 0 and areas[a].takes(index, lp[0], lp[1], lp[2]):
							which = a
							break
				if not pieces.has(which):
					pieces[which] = []
				(pieces[which] as Array).append_array(corner)
			for which: int in pieces:
				var corners: Array = pieces[which]
				var at := PackedVector3Array()
				var facing := PackedVector3Array()
				var uvs := PackedVector2Array()
				at.resize(corners.size())
				facing.resize(corners.size())
				uvs.resize(corners.size())
				for k: int in corners.size():
					var p: Vector3 = positions[int(corners[k])]
					at[k] = p + Vector3(shift.x, -shift.y, -shift.z)
					facing[k] = normals[int(corners[k])]
					if which >= 0:
						uvs[k] = areas[which].uv(Vector3(p.x, -p.y, -p.z) + shift)
				var built: Array = []
				built.resize(Mesh.ARRAY_MAX)
				built[Mesh.ARRAY_VERTEX] = at
				built[Mesh.ARRAY_NORMAL] = facing
				built[Mesh.ARRAY_TEX_UV] = uvs
				var surface := ArrayMesh.new()
				surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
				out.append({"mesh": surface, "area": areas[which].key if which >= 0 else "",
					"part": part, "colour": mesh.surface_colors[n],
					"two_sided": mesh.surface_two_sided[n] == 1})
	return out
