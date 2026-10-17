## Stickers, as LEGO does them: a thin element of its own, printed, laid
## over a part's face — or over two parts' faces at once, as a sign across
## two tiles is — and not a change to the part under it. It can be peeled
## off and stuck on somewhere else, and every model has a sheet of them.
##
## A sticker is a made part like any print (see [PartPrints]): a film
## [constant THICK] LDU thick (0.1 mm, as LDraw draws its official
## stickers) the size of the faces it covers, less LEGO's 0.1 mm a side —
## a real brick is that much shy of its pitch — and a margin, with its
## picture on its top in a TEXMAP block, named bw-st-<tag>, filed in the
## parts bin under "My stickers". It has no connectors and no collision
## cover: it holds nothing and is in nobody's way. In the model it is a
## brick placed exactly on the face, turned so the picture reads as it was
## drawn.
##
## Everything here is in the app's axes.
class_name Stickers
extends RefCounted

const STICKER_BY := "0 // Sticker by Brickworks:"
const AUTHOR := "Brickworks sticker designer"
## How thick the film is, how much a real brick is shy of its pitch on
## each side, and how far in from the face's edge a sticker stands, LDU.
const THICK := 0.25
const SHY := 0.25
const MARGIN := 0.5
## The colour of the film where the picture is clear: white, as sticker
## sheets are.
const FILM := 15


## A place to stick a sticker: the faces of one or more bricks lying in
## one plane, and the rectangle over them.
class Face extends RefCounted:
	var bricks := PackedInt64Array()
	## The middle of the rectangle, on the faces.
	var centre := Vector3.ZERO
	var normal := Vector3.UP
	## The picture's right and down on the face.
	var right := Vector3.RIGHT
	var down := Vector3.BACK
	## The rectangle's size across and down, LDU.
	var size := Vector2.ZERO

	## The sticker for this face: the rectangle less the brick's shyness
	## and the margin, all round.
	func sticker_size() -> Vector2:
		return Vector2(maxf(2.0, size.x - 2.0 * (SHY + MARGIN)),
			maxf(2.0, size.y - 2.0 * (SHY + MARGIN)))

	## Where a sticker's own frame goes: its X across, its Y out of the
	## face, its Z down the picture.
	func transform() -> Transform3D:
		return Transform3D(Basis(right, normal, down), centre)


# -- finding a face ---------------------------------------------------------------


static var _faces: Dictionary = {}       ## part id -> its triangles, in its own axes


## The face of the model a ray meets: the brick it strikes first, the flat
## face struck, and with [param span] every brick beside it whose face lies
## in the same plane and touches — two tiles side by side are one face.
## [param view_up] is the screen's up, which is the picture's up on a face
## turned to the sky. Null when the ray meets no flat face.
static func face_at(world: BrickWorld, library: PartLibrary, origin: Vector3, direction: Vector3,
		span: bool, view_up: Vector3 = Vector3.UP) -> Face:
	var dir: Vector3 = direction.normalized()
	var best: float = INF
	var struck: BrickWorld.Brick = null
	var struck_at := Vector3.ZERO
	var struck_normal := Vector3.ZERO
	# The parts whose box the line meets, the nearest box first: a part whose
	# box begins further off than a face already struck has no face nearer,
	# and its triangles (thousands, milliseconds a part) are not asked. The
	# nearest face wins, and of two as near the one the world has first, as
	# when every part was asked in the world's order.
	var met: Array = []
	for item: Variant in _along(world, library, origin, dir):
		var brick: BrickWorld.Brick = item
		# Not onto another film: a sticker goes on the part, not on a sticker.
		if sticks(library, brick.part_id):
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var box: AABB = (brick.transform * mesh.bounds).grow(0.5)
		var entry: Variant = box.intersects_ray(origin, dir)
		if entry == null:
			continue
		met.append([0.0 if box.has_point(origin) else origin.distance_to(entry), met.size(),
			brick])
	met.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	var struck_order: int = -1
	for one: Array in met:
		if float(one[0]) > best:
			break
		var brick: BrickWorld.Brick = one[2]
		var back: Transform3D = brick.transform.affine_inverse()
		var hit: Dictionary = Rays.nearest(_faces_of(library, brick.part_id), back * origin,
			(back.basis * dir).normalized())
		if hit.is_empty():
			continue
		var at: Vector3 = brick.transform * (hit["position"] as Vector3)
		var d: float = origin.distance_to(at)
		if d < best or (d == best and int(one[1]) < struck_order):
			best = d
			struck = brick
			struck_order = int(one[1])
			struck_at = at
			struck_normal = (brick.transform.basis * (hit["normal"] as Vector3)).normalized()
	if struck == null:
		return null
	if struck_normal.dot(dir) > 0.0:
		struck_normal = -struck_normal
	var plane: float = struck_normal.dot(struck_at)
	var face := Face.new()
	face.normal = struck_normal
	# The picture's down: the world's, on a face that stands; the screen's
	# on one that lies.
	var down: Vector3 = Vector3.DOWN - face.normal * Vector3.DOWN.dot(face.normal)
	if down.length() < 0.3:
		# On a face that lies, the brick's own edge nearest the screen's
		# down: a sticker lies square on a tile, whichever way it is seen.
		var wanted: Vector3 = -view_up - face.normal * (-view_up).dot(face.normal)
		var closest: float = -INF
		for axis: Vector3 in [struck.transform.basis.x, -struck.transform.basis.x,
				struck.transform.basis.z, -struck.transform.basis.z,
				struck.transform.basis.y, -struck.transform.basis.y]:
			var along: Vector3 = axis - face.normal * axis.dot(face.normal)
			if along.length() < 0.5:
				continue
			if along.normalized().dot(wanted) > closest:
				closest = along.normalized().dot(wanted)
				down = along
	face.down = down.normalized()
	face.right = face.normal.cross(face.down).normalized()
	var mine: Array = _flat(library, struck, face.normal, plane, struck_at)
	if mine.is_empty():
		return null
	var rect: Rect2 = _rect(mine, face)
	face.bricks.append(struck.id)
	if span:
		var grew: bool = true
		while grew:
			grew = false
			for item: Variant in world.bricks():
				var brick: BrickWorld.Brick = item
				if face.bricks.has(brick.id) or sticks(library, brick.part_id):
					continue
				var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
				if mesh == null:
					continue
				var box: AABB = brick.transform * mesh.bounds
				if absf(face.normal.dot(box.get_center()) - plane) > box.size.length():
					continue
				var theirs: Array = _flat(library, brick, face.normal, plane, Vector3.INF)
				if theirs.is_empty():
					continue
				var their_rect: Rect2 = _rect(theirs, face)
				if their_rect.grow(1.0).intersects(rect):
					rect = rect.merge(their_rect)
					face.bricks.append(brick.id)
					grew = true
	face.size = rect.size
	var middle: Vector2 = rect.get_center()
	face.centre = face.right * middle.x + face.down * middle.y + face.normal * plane
	return face


static func _faces_of(library: PartLibrary, part_id: String) -> PackedVector3Array:
	if _faces.has(part_id):
		return _faces[part_id]
	var faces := PackedVector3Array()
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	for surface: ArrayMesh in mesh.surfaces:
		faces.append_array(surface.get_faces())
	_faces[part_id] = faces
	return faces


## A brick's triangles lying flat in the plane, turned the plane's way, in
## the world: those of the face containing [param near], or all of them
## when it is [constant Vector3.INF]. From the part's triangles kept once
## (_faces_of): read from its meshes at every move, each read was the
## drawing's copy of them fetched back, with a sticker in hand.
static func _flat(library: PartLibrary, brick: BrickWorld.Brick, normal: Vector3, plane: float,
		near: Vector3) -> Array:
	var out: Array = []
	var corners: PackedVector3Array = _faces_of(library, brick.part_id)
	for t: int in corners.size() / 3:
		var a: Vector3 = brick.transform * corners[t * 3]
		var b: Vector3 = brick.transform * corners[t * 3 + 1]
		var c: Vector3 = brick.transform * corners[t * 3 + 2]
		var n: Vector3 = (b - a).cross(c - a)
		if n.length() < 1e-6:
			continue
		if absf(n.normalized().dot(normal)) < 0.99:
			continue
		if absf(normal.dot(a) - plane) > 0.3 or absf(normal.dot(b) - plane) > 0.3 \
				or absf(normal.dot(c) - plane) > 0.3:
			continue
		out.append([a, b, c])
	return out


static func _rect(triangles: Array, face: Face) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for triangle: Array in triangles:
		for p: Vector3 in triangle:
			var at := Vector2(p.dot(face.right), p.dot(face.down))
			lo = lo.min(at)
			hi = hi.max(at)
	return Rect2(lo, hi - lo)


## The world's parts by their drawn boxes (BrickGrid), as face_at grows
## them, kept part by part as the model changes.
static var _drawn: BrickGrid = null


## The parts whose drawn box the line from [param origin] going [param dir]
## may meet, in the order the world gives them: every one face_at would
## have found by asking each part, without asking each. A sticker in hand
## asked every part of the model at every move, 14 ms a move on a
## 4,139-part set. A part whose shape has not arrived is asked every time,
## as it was.
static func _along(world: BrickWorld, library: PartLibrary, origin: Vector3,
		dir: Vector3) -> Array:
	if _drawn == null or _drawn._library != library:
		_drawn = BrickGrid.new(library, func(brick: BrickWorld.Brick, mesh: Lbm.PartMesh) -> Array:
			if mesh == null:
				return [null, null, true]
			return [(brick.transform * mesh.bounds).grow(0.5), null, false])
	_drawn.follow(world)
	return _drawn.along(origin, dir)


# -- the sticker itself --------------------------------------------------------------


static func is_sticker(library: PartLibrary, part_id: String) -> bool:
	var text: String = library.custom_source(part_id) if part_id.begins_with("bw-st-") else ""
	return not text.is_empty() and text.contains(STICKER_BY)


## Whether a part holds by its glue: a film laid on a face, one of ours or
## one LDraw files as a Sticker (PartLibrary.decor_of). What it is stuck to
## is [method lies_on]'s.
static func sticks(library: PartLibrary, part_id: String) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	return info != null and (info.decor() & PartLibrary.PartInfo.STICKER) != 0


## Points a little behind a film at [param at], across it, [param film] its
## own box: where what it is stuck to is. Its printed face is its top, as
## LDraw draws a sticker and [method text_for] writes one.
static func behind(at: Transform3D, film: AABB) -> Array[Vector3]:
	var middle: Vector3 = film.get_center()
	var points: Array[Vector3] = []
	for i: int in 5:
		for j: int in 5:
			points.append(at * Vector3(middle.x + (i / 4.0 - 0.5) * film.size.x * 0.9,
				film.position.y - 0.5, middle.z + (j / 4.0 - 0.5) * film.size.z * 0.9))
	return points


## What a film at [param at] lies on, of [param parts] ([key, transform, box in
## its own axes]): each whose box holds a point behind it ([method behind]), as
## [key, how many of the points], most first. [param skip] is the film's own key.
## The booklet's question (what it goes on after) and the build check's (what
## holds it) both, so the two cannot disagree about where a sticker is.
static func lies_on(at: Transform3D, film: AABB, parts: Array, skip: Variant = null) -> Array:
	var points: Array[Vector3] = behind(at, film)
	var near: AABB = (at * film).grow(2.0)
	var found: Array = []
	for part: Array in parts:
		if skip != null and part[0] == skip:
			continue
		var box: AABB = ((part[1] as Transform3D) * (part[2] as AABB)).grow(0.3)
		if not box.intersects(near):
			continue
		var hits: int = 0
		for point: Vector3 in points:
			if box.has_point(point):
				hits += 1
		if hits > 0:
			found.append([part[0], hits])
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0])))
	return found


## A sticker's size in LDU, from its file.
static func size_of(library: PartLibrary, part_id: String) -> Vector2:
	for raw: String in library.custom_source(part_id).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with(STICKER_BY):
			var size := Vector2.ZERO
			for word: String in line.substr(STICKER_BY.length()).split(" ", false):
				if word.begins_with("w="):
					size.x = word.substr(2).to_float()
				elif word.begins_with("h="):
					size.y = word.substr(2).to_float()
			return size
	return Vector2.ZERO


## The canvas for a sticker of a size: ten pixels to the LDU, as a print's.
static func canvas_for(size: Vector2) -> Vector2i:
	return PartPrints._canvas(size.x, size.y)


## A sticker's part file: a film [param size] LDU across and down, its top
## printed with [param picture_name].
static func text_for(id: String, title: String, size: Vector2, picture_name: String) -> String:
	var w: float = size.x * 0.5
	var h: float = size.y * 0.5
	var t: float = THICK
	var words: String = title.strip_edges().replace("\n", " ")
	var out := PackedStringArray()
	out.append("0 Sticker %s x %s mm, %s" % [_mm(size.x), _mm(size.y),
		words if not words.is_empty() else id])
	out.append("0 Name: %s.dat" % id)
	out.append("0 Author: " + AUTHOR)
	out.append("0 !LDRAW_ORG Unofficial_Part")
	out.append("0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt")
	out.append("")
	out.append("0 BFC CERTIFY CCW")
	out.append("")
	out.append("0 !CATEGORY Sticker")
	out.append("0 !KEYWORDS Brickworks, custom sticker")
	out.append("")
	out.append("%s w=%s h=%s" % [STICKER_BY, PartEditor._n(size.x), PartEditor._n(size.y)])
	out.append("0 // A film %s LDU thick; its printed face is its top." % PartEditor._n(t))
	out.append("")
	# LDraw's axes: the top is at -t, the back at +z.
	var top: Array[Vector3] = [Vector3(-w, -t, h), Vector3(w, -t, h), Vector3(w, -t, -h),
		Vector3(-w, -t, -h)]
	var bottom: Array[Vector3] = [Vector3(-w, 0, h), Vector3(w, 0, h), Vector3(w, 0, -h),
		Vector3(-w, 0, -h)]
	out.append("0 !TEXMAP START PLANAR %s %s %s %s %s %s %s %s %s %s" % [
		PartEditor._n(-w), PartEditor._n(-t), PartEditor._n(h),
		PartEditor._n(w), PartEditor._n(-t), PartEditor._n(h),
		PartEditor._n(-w), PartEditor._n(-t), PartEditor._n(-h), picture_name])
	out.append(_quad(top, Vector3(0, -1, 0)))
	out.append("0 !TEXMAP END")
	out.append(_quad(bottom, Vector3(0, 1, 0)))
	for n: int in 4:
		var m: int = (n + 1) % 4
		var side: Array[Vector3] = [top[n], top[m], bottom[m], bottom[n]]
		var outward: Vector3 = ((top[n] + top[m]) * 0.5) * Vector3(1, 0, 1)
		out.append(_quad(side, outward))
	out.append("0")
	return "\n".join(out) + "\n"


## A quad line wound so its front faces [param outward].
static func _quad(corners: Array[Vector3], outward: Vector3) -> String:
	var a: Vector3 = corners[0]
	var points: Array[Vector3] = corners.duplicate()
	if (corners[1] - a).cross(corners[2] - a).dot(outward) < 0.0:
		points.reverse()
	var words := PackedStringArray(["4", "16"])
	for p: Vector3 in points:
		words.append_array([PartEditor._n(p.x), PartEditor._n(p.y), PartEditor._n(p.z)])
	return " ".join(words)


static func _mm(ldu: float) -> String:
	return String.num(ldu * Lbm.LDU_MM, 1)


## Make a sticker of a picture and a size, add it to the library and keep
## it: {"id", "problem"}. The same picture at the same size is the same
## sticker.
static func make(library: PartLibrary, picture: Image, size: Vector2, title: String,
		keep: bool = true) -> Dictionary:
	var finished: Image = picture.duplicate()
	if finished.get_format() != Image.FORMAT_RGBA8:
		finished.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = finished.save_png_to_buffer()
	var tag: String = PartPrints.tag_of(["sticker", size, title, bytes])
	var id: String = "bw-st-" + tag
	var name: String = id + ".png"
	var text: String = text_for(id, title, size, name)
	return CustomParts.add(library, text, id, keep, {name: bytes})


# -- in a model ----------------------------------------------------------------------


## Stick a sticker on a face, through the builder so one undo takes it
## off: one made here, or one of LDraw's, in [param colour] (the film's
## colour where nothing is printed; white, as a sticker sheet is, unless
## said). Returns the brick, or 0.
static func stick(builder: Builder, sticker_id: String, face: Face, colour: int = FILM) -> int:
	var film: Lbm.PartMesh = builder.library.mesh_for(sticker_id)
	var at: Transform3D = laid_on(face, film.bounds) if film != null else face.transform()
	return builder.put_part(sticker_id, colour, at)


## Where a film whose own box is [param film] goes to lie on [param face]:
## its middle on the face's middle, its back on the face, its picture's
## down the face's down, turned [param quarter_turns] about the face. One
## made here is drawn round its own middle with its back at 0, as LDraw
## draws its stickers (169585a: a box 0.25 thick under y 0, centred), so
## either lands where Face.transform says; this only makes sure of it.
static func laid_on(face: Face, film: AABB, quarter_turns: int = 0) -> Transform3D:
	var at: Transform3D = face.transform()
	if posmod(quarter_turns, 4) != 0:
		at.basis = Basis(face.normal, posmod(quarter_turns, 4) * PI * 0.5) * at.basis
	var middle: Vector3 = film.get_center()
	at.origin -= at.basis * Vector3(middle.x, film.position.y, middle.z)
	return at


## The model's stickers: sticker id -> the bricks that are it.
static func in_model(world: BrickWorld, library: PartLibrary) -> Dictionary:
	# Gathered in Arrays: a packed array read out of a Dictionary is a copy,
	# and appending to it appended to nothing.
	var found: Dictionary = {}
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if is_sticker(library, brick.part_id):
			if not found.has(brick.part_id):
				found[brick.part_id] = []
			(found[brick.part_id] as Array).append(brick.id)
	var out: Dictionary = {}
	for id: String in found:
		out[id] = PackedInt64Array(found[id])
	return out


## The bricks a placed sticker is stuck to: those under its film, found
## by looking a little behind it at points across it ([method lies_on]),
## the one it covers most first, which is the one the build check holds it
## by. What the booklet needs to show it in the step after they are put in.
static func stuck_to(world: BrickWorld, library: PartLibrary, sticker_brick: int) -> PackedInt64Array:
	var out := PackedInt64Array()
	var sticker: BrickWorld.Brick = world.get_brick(sticker_brick)
	var film: Lbm.PartMesh = library.mesh_for(sticker.part_id) if sticker != null else null
	if film == null:
		return out
	var parts: Array = []
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if sticks(library, brick.part_id):
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			parts.append([brick.id, brick.transform, mesh.bounds])
	for found: Array in lies_on(sticker.transform, film.bounds, parts, sticker_brick):
		out.append(int(found[0]))
	return out
