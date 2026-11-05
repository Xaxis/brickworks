## A part drawn from what the catalogue says of it, while its picture is
## still coming: a tile that can be told from its neighbours at once.
##
## On the web a picture is a fetch and then a render in a browser drawing in
## software, and the parts bin's tiles were grey squares eight seconds after
## it opened on the castle, each saying only a number (appux371 A4). The
## catalogue is already here: every part's size, how many studs it has and
## what kind it is. So the tile draws that, in the colour in hand, as a
## ghost of the part, at the angle its picture is drawn from: a box its size
## with its studs on top, a slope falling to the front, a round part round,
## a beam with its holes. The picture fades in over it when it lands.
##
## Drawn once, on a canvas item of the tile's own, which the tile fades as
## the picture comes (ThumbTile); and one stud drawn, as a mesh, and stood on
## every place of the top at once (a MultiMesh). Each stud was a cylinder
## worked out in script and drawn on its own: 110-213 ms for a baseplate,
## over a second for the page of them "32" lists first, and all of it again
## on every frame of each picture's fade (sketchfast, 2026-11-05).
class_name PartSketch
extends RefCounted

## One LDraw unit, studs apart, and a stud's size, in LDU.
const PITCH := 20.0
const STUD_RADIUS := 6.0
const STUD_HEIGHT := 4.0
const PLATE := 8.0
## How much of the square the part fills, and how see-through the ghost is:
## a stand-in, not the picture.
const FILL := 0.74
const GHOST := 0.62
## The isometric view: x to the right and down, z to the left and down.
const ACROSS := 0.866
const DOWN := 0.5
## Points round a stud or a round part.
const ROUND := 20
## A line's width, pixels, and the RenderingServer's fade either side of an
## antialiased one (FEATHER_SIZE), which a line narrower than a pixel scales.
const LINE := 1.0
const FEATHER := 1.25

## How many sketches have been drawn, and the time it took, usec: what a
## probe reads of a frame (bin_sketch_probe).
static var drawn: int = 0
static var spent_usec: int = 0


## Draw [param info] in [param rect] onto the canvas item [param item], in
## [param colour], whole: a tile fades it by the item's opacity. Gives back
## what the drawing stands its studs with, which must be kept as long as the
## item is drawn so; null for a part without studs.
static func draw(item: RID, rect: Rect2, info: PartLibrary.PartInfo, colour: Color) -> MultiMesh:
	if info == null:
		return null
	var began: int = Time.get_ticks_usec()
	var studs: MultiMesh = _draw_sketch(item, rect, info, colour)
	drawn += 1
	spent_usec += Time.get_ticks_usec() - began
	return studs


static func _draw_sketch(item: RID, rect: Rect2, info: PartLibrary.PartInfo,
		colour: Color) -> MultiMesh:
	var studs: Vector2i = info.footprint_studs()
	var width: float = maxf(PITCH * 0.5, info.size.x)
	var depth: float = maxf(PITCH * 0.5, info.size.z)
	var raised: float = STUD_HEIGHT if info.stud_count > 0 else 0.0
	var height: float = clampf(info.size.y - raised, 1.0, maxf(width, depth) * 2.0)
	var round: bool = _is_round(info)
	# Fitted to the square: the box and its studs, in view.
	var extent: Rect2 = _extent(width, depth, height + raised)
	var scale: float = minf(rect.size.x * FILL / maxf(extent.size.x, 1.0),
		rect.size.y * FILL / maxf(extent.size.y, 1.0))
	var origin: Vector2 = rect.get_center() - extent.get_center() * scale
	var view: Callable = func(x: float, y: float, z: float) -> Vector2:
		return origin + _project(x, y, z) * scale
	var top: Color = _shade(colour, 0.22, GHOST)
	var left: Color = _shade(colour, 0.0, GHOST)
	var right: Color = _shade(colour, -0.28, GHOST)
	var edge := Color(0, 0, 0, 0.28)
	if round:
		_cylinder(item, origin, scale, Vector3(width * 0.5, 0.0, depth * 0.5), width * 0.5,
			depth * 0.5, height, top, left, edge)
	elif info.category == "Slope" and height > PLATE * 1.5 \
			and info.name.get_slice(" with ", 0).contains("Inverted"):
		_inverted(item, view, width, depth, height, top, left, right, edge)
	elif info.category == "Slope" and height > PLATE * 1.5:
		_slope(item, view, width, depth, height, studs, info.stud_count, top, left, right, edge)
	else:
		_box(item, view, width, depth, height, top, left, right, edge)
		if info.category == "Technic" and info.stud_count == 0 \
				and int(info.connector_counts.get("pin_hole", 0)) > 0:
			_holes(item, view, width, depth, height, int(info.connector_counts["pin_hole"]),
				_shade(colour, -0.6, GHOST))
	if info.stud_count <= 0:
		return null
	var rows: int = studs.y
	if info.category == "Slope" and not round:
		rows = maxi(1, ceili(float(info.stud_count) / float(maxi(studs.x, 1))))
	return _studs(item, origin, scale, height,
		_stud_places(studs, info.stud_count, rows, width, depth), top, left, edge)


## A point of the part in LDU, on the screen, before it is scaled: the part
## seen from above its front corner, x running right, z left, y up.
static func _project(x: float, y: float, z: float) -> Vector2:
	return Vector2((x - z) * ACROSS, (x + z) * DOWN - y)


## The box's corners seen, as a rectangle on the screen.
static func _extent(width: float, depth: float, height: float) -> Rect2:
	var area := Rect2(_project(0.0, 0.0, 0.0), Vector2.ZERO)
	for x: float in [0.0, width]:
		for z: float in [0.0, depth]:
			for y: float in [0.0, height]:
				area = area.expand(_project(x, y, z))
	return area


static func _shade(colour: Color, by: float, alpha: float) -> Color:
	var shaded: Color = colour.lightened(by) if by >= 0.0 else colour.darkened(-by)
	shaded.a = alpha
	return shaded


## Round parts: a 1 x 1 round plate, a round brick, a cone, a dish, a cylinder.
static func _is_round(info: PartLibrary.PartInfo) -> bool:
	if info.category in ["Cylinder", "Cone", "Dish"]:
		return true
	# What it is, not what it has: "Slope Brick 45 2 x 2 Inverted with Round
	# Bottom Pin" is not round.
	var name: String = info.name.to_lower().get_slice(" with ", 0)
	return name.contains(" round") and not name.contains("corner round") \
		and not name.contains("round corner") and not name.contains("rounded") \
		and info.footprint_studs().x == info.footprint_studs().y


static func _face(item: RID, points: PackedVector2Array, fill: Color, edge: Color) -> void:
	RenderingServer.canvas_item_add_polygon(item, points, PackedColorArray([fill]))
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	RenderingServer.canvas_item_add_polyline(item, closed, PackedColorArray([edge]), LINE, true)


## The three faces of a box seen from its front corner: its top, its left
## (the z end) and its right (the x end).
static func _box(item: RID, view: Callable, width: float, depth: float, height: float,
		top: Color, left: Color, right: Color, edge: Color) -> void:
	_face(item, PackedVector2Array([view.call(0.0, height, 0.0), view.call(width, height, 0.0),
		view.call(width, height, depth), view.call(0.0, height, depth)]), top, edge)
	_face(item, PackedVector2Array([view.call(0.0, height, depth), view.call(width, height, depth),
		view.call(width, 0.0, depth), view.call(0.0, 0.0, depth)]), left, edge)
	_face(item, PackedVector2Array([view.call(width, height, 0.0), view.call(width, height, depth),
		view.call(width, 0.0, depth), view.call(width, 0.0, 0.0)]), right, edge)


## A slope: flat on top over the rows its studs take at the back, falling
## from there to a plate's height at the front.
static func _slope(item: RID, view: Callable, width: float, depth: float, height: float,
		studs: Vector2i, stud_count: int, top: Color, left: Color, right: Color,
		edge: Color) -> void:
	var rows: int = mini(studs.y, ceili(float(stud_count) / float(maxi(studs.x, 1))))
	var flat: float = minf(depth - PITCH * 0.5, rows * PITCH) if stud_count > 0 else 0.0
	var lip: float = minf(PLATE * 0.5, height)
	_face(item, PackedVector2Array([view.call(0.0, height, 0.0), view.call(width, height, 0.0),
		view.call(width, height, flat), view.call(0.0, height, flat)]), top, edge)
	_face(item, PackedVector2Array([view.call(0.0, height, flat), view.call(width, height, flat),
		view.call(width, lip, depth), view.call(0.0, lip, depth)]), top.darkened(0.08), edge)
	_face(item, PackedVector2Array([view.call(0.0, lip, depth), view.call(width, lip, depth),
		view.call(width, 0.0, depth), view.call(0.0, 0.0, depth)]), left, edge)
	_face(item, PackedVector2Array([view.call(width, height, 0.0), view.call(width, height, flat),
		view.call(width, lip, depth), view.call(width, 0.0, depth), view.call(width, 0.0, 0.0)]),
		right, edge)


## An inverted slope: its top whole, falling away underneath from a lip at
## the front to the row it stands on at the back.
static func _inverted(item: RID, view: Callable, width: float, depth: float, height: float,
		top: Color, left: Color, right: Color, edge: Color) -> void:
	var lip: float = minf(PLATE * 0.5, height)
	var foot: float = minf(PITCH, depth)
	_face(item, PackedVector2Array([view.call(0.0, height, 0.0), view.call(width, height, 0.0),
		view.call(width, height, depth), view.call(0.0, height, depth)]), top, edge)
	_face(item, PackedVector2Array([view.call(0.0, height, depth), view.call(width, height, depth),
		view.call(width, height - lip, depth), view.call(0.0, height - lip, depth)]), left, edge)
	_face(item, PackedVector2Array([view.call(width, height, 0.0), view.call(width, height, depth),
		view.call(width, height - lip, depth), view.call(width, 0.0, foot),
		view.call(width, 0.0, 0.0)]), right, edge)


## An upright round, [param across] and [param deep] its radii, standing
## on [param base]: its side, then its top.
static func _cylinder(item: RID, origin: Vector2, scale: float, base: Vector3, across: float,
		deep: float, height: float, top: Color, side: Color, edge: Color) -> void:
	var outline: Array = _rings(origin, scale, base, across, deep, height)
	var body: PackedVector2Array = outline[1]
	if body.size() >= 3:
		RenderingServer.canvas_item_add_polygon(item, body, PackedColorArray([side]))
	_face(item, outline[0], top, edge)
	RenderingServer.canvas_item_add_polyline(item, outline[2], PackedColorArray([edge]), LINE, true)


## A round's outline seen from [param origin] at [param scale]: [its top's
## ring, its side (what lies between the two rings' outlines: the lower
## ring's near half and the upper ring's, joined), the lower ring's near
## half].
static func _rings(origin: Vector2, scale: float, base: Vector3, across: float, deep: float,
		height: float) -> Array:
	var low := PackedVector2Array()
	var high := PackedVector2Array()
	low.resize(ROUND)
	high.resize(ROUND)
	var up := Vector2(0.0, -height * scale)
	for n: int in ROUND:
		var turn: float = TAU * n / float(ROUND)
		var x: float = base.x + cos(turn) * across
		var z: float = base.z + sin(turn) * deep
		var foot: Vector2 = origin + Vector2((x - z) * ACROSS, (x + z) * DOWN - base.y) * scale
		low[n] = foot
		high[n] = foot + up
	var body := PackedVector2Array()
	var near := _near_half(low)
	body.append_array(near)
	var upper := _near_half(high)
	upper.reverse()
	body.append_array(upper)
	return [high, body, near]


## Every stud, [param height] up on the part at [param places]: one drawn
## as a mesh, as [method _cylinder] draws a round, and stood on each place
## at once. Drawn each on its own, a baseplate's 1,024 took 110-213 ms.
static func _studs(item: RID, origin: Vector2, scale: float, height: float,
		places: Array[Vector2], top: Color, side: Color, edge: Color) -> MultiMesh:
	if places.is_empty():
		return null
	# The stud about its own foot's middle, at the sketch's scale: its side,
	# its top and the top's edge, the side's lower edge, in that order.
	var outline: Array = _rings(Vector2.ZERO, scale, Vector3.ZERO, STUD_RADIUS, STUD_RADIUS,
		STUD_HEIGHT)
	var stud := ArrayMesh.new()
	var body: PackedVector2Array = outline[1]
	if body.size() >= 3:
		_fill(stud, body, side)
	var high: PackedVector2Array = outline[0]
	_fill(stud, high, top)
	var closed: PackedVector2Array = high.duplicate()
	closed.append(high[0])
	_line(stud, closed, edge)
	_line(stud, outline[2], edge)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_2D
	many.mesh = stud
	many.instance_count = places.size()
	# Each a move from the stud's own: [x.x, y.x, -, origin.x, x.y, y.y, -, origin.y].
	var moves := PackedFloat32Array()
	moves.resize(places.size() * 8)
	var n: int = 0
	# Worked out here rather than through _project: a baseplate has 1,024.
	var lift: float = origin.y - height * scale
	for place: Vector2 in places:
		moves[n] = 1.0
		moves[n + 3] = origin.x + (place.x - place.y) * ACROSS * scale
		moves[n + 5] = 1.0
		moves[n + 7] = lift + (place.x + place.y) * DOWN * scale
		n += 8
	many.buffer = moves
	RenderingServer.canvas_item_add_multimesh(item, many.get_rid())
	return many


## [param polygon] filled in [param colour], a surface of [param mesh],
## triangulated as the RenderingServer fills one (Geometry2D).
static func _fill(mesh: ArrayMesh, polygon: PackedVector2Array, colour: Color) -> void:
	var corners: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if corners.is_empty():
		return
	var ink := PackedColorArray()
	ink.resize(polygon.size())
	ink.fill(colour)
	_surface(mesh, polygon, ink, corners)


## [param line] a surface of [param mesh], [constant LINE] wide in [param
## colour], made as the RenderingServer makes an antialiased polyline
## (canvas_item_add_polyline, Godot 4.7.2), point for point: a strip down
## its middle half as wide as asked, then a strip each side fading out over
## [constant FEATHER] times that, mitred at each bend, an open line's ends
## fading out as far beyond them. Made a pixel wide with the whole fade each
## side, the studs were ringed twice as dark and a baseplate's top went black.
static func _line(mesh: ArrayMesh, line: PackedVector2Array, colour: Color) -> void:
	var count: int = line.size()
	if count < 2:
		return
	# Its width less the fades' share (canvas_item_get_compensated_antialiasing_width).
	var width: float = LINE * 0.5
	var border: float = FEATHER * (width if width < 1.0 else 1.0)
	var loop: bool = line[0].is_equal_approx(line[count - 1])
	var first := Vector2.ZERO
	for n: int in range(1, count):
		first = (line[n] - line[n - 1]).normalized()
		if not first.is_zero_approx():
			break
	var last := Vector2.ZERO
	for n: int in range(count - 1, 0, -1):
		last = (line[n] - line[n - 1]).normalized()
		if not last.is_zero_approx():
			break
	var clear := Color(colour, 0.0)
	var ends: int = 0 if loop else 2
	var middle := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var middle_ink := PackedColorArray()
	var left_ink := PackedColorArray()
	var right_ink := PackedColorArray()
	# Packed arrays are values: each is sized where it is named.
	middle.resize(count * 2 + ends * 2)
	middle_ink.resize(middle.size())
	left.resize(count * 2 + (0 if loop else 5))
	left_ink.resize(left.size())
	right.resize(left.size())
	right_ink.resize(left.size())
	var before := Vector2.ZERO
	for n: int in count:
		var is_first: bool = n == 0
		var is_last: bool = n == count - 1
		var along: Vector2 = before
		if not is_last:
			along = (line[n + 1] - line[n]).normalized()
			if along.is_zero_approx():
				along = before
		if is_first and loop:
			before = last
		elif is_last and loop:
			before = first
		var base: Vector2
		if is_first and not loop:
			base = first.orthogonal()
		elif is_last and not loop:
			base = last.orthogonal()
		else:
			base = _mitre(along, before)
		var half: Vector2 = base * (width * 0.5)
		var fade: Vector2 = base * border
		var at: Vector2 = line[n]
		var j: int = n * 2 + ends
		middle[j] = at + half
		middle[j + 1] = at - half
		left[j] = at + half
		left[j + 1] = at + half + fade
		right[j] = at - half
		right[j + 1] = at - half - fade
		middle_ink[j] = colour
		middle_ink[j + 1] = colour
		left_ink[j] = colour
		left_ink[j + 1] = clear
		right_ink[j] = colour
		right_ink[j + 1] = clear
		if is_first and not loop:
			var back: Vector2 = -along * border
			middle[0] = at + half + back
			middle[1] = at - half + back
			left[0] = at + half + back
			left[1] = at + half + back + fade
			right[0] = at - half + back
			right[1] = at - half + back - fade
			middle_ink[0] = clear
			middle_ink[1] = clear
			left_ink[0] = clear
			left_ink[1] = clear
			right_ink[0] = clear
			right_ink[1] = clear
		if is_last and not loop:
			var on: Vector2 = before * border
			var k: int = count * 2 + 2
			middle[k] = at + half + on
			middle[k + 1] = at - half + on
			middle_ink[k] = clear
			middle_ink[k + 1] = clear
			# Back to the line's corner first, so the end's quad is cut from it.
			left[k] = at + half
			left[k + 1] = at + half + on + fade
			left[k + 2] = at + half + on
			right[k] = at - half
			right[k + 1] = at - half + on - fade
			right[k + 2] = at - half + on
			left_ink[k] = colour
			left_ink[k + 1] = clear
			left_ink[k + 2] = clear
			right_ink[k] = colour
			right_ink[k + 1] = clear
			right_ink[k + 2] = clear
		before = along
	var points: PackedVector2Array = middle + left + right
	_surface(mesh, points, middle_ink + left_ink + right_ink,
		_strips([middle.size(), left.size(), right.size()]))


## Where a polyline's edge is from a point at a bend, coming along [param
## before] and going on along [param along] (compute_polyline_edge_offset_clamped).
static func _mitre(along: Vector2, before: Vector2) -> Vector2:
	var bisector: Vector2 = (before * along.length() - along * before.length()).normalized()
	var length: float = 1.0
	var sine: float = sin(atan2(bisector.cross(before), bisector.dot(before)))
	if not is_zero_approx(sine) and not along.is_equal_approx(before):
		length = clampf(1.0 / sine, -3.0, 3.0)
	else:
		bisector = along.orthogonal()
	if bisector.is_zero_approx():
		bisector = along.orthogonal()
	return bisector * length


## The triangles of triangle strips [param sizes] long laid end to end, each
## as a strip runs: made once for each line's length, on the main thread,
## where the tiles draw.
static var _stripped: Dictionary = {}

static func _strips(sizes: Array) -> PackedInt32Array:
	var made: Variant = _stripped.get(sizes)
	if made != null:
		return made
	var corners := PackedInt32Array()
	var from: int = 0
	for size: int in sizes:
		for n: int in size - 2:
			corners.append_array([from + n, from + n + 1, from + n + 2])
		from += size
	_stripped[sizes] = corners
	return corners


static func _surface(mesh: ArrayMesh, points: PackedVector2Array, ink: PackedColorArray,
		corners: PackedInt32Array) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = ink
	arrays[Mesh.ARRAY_INDEX] = corners
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## The half of a ring nearer the eye, from its leftmost point to its
## rightmost along its lower side.
static func _near_half(ring: PackedVector2Array) -> PackedVector2Array:
	var leftmost: int = 0
	var rightmost: int = 0
	for n: int in ring.size():
		if ring[n].x < ring[leftmost].x:
			leftmost = n
		if ring[n].x > ring[rightmost].x:
			rightmost = n
	var out := PackedVector2Array()
	var n: int = leftmost
	# The way round that passes under the middle.
	var forward: bool = ring[(leftmost + 1) % ring.size()].y >= ring[leftmost].y
	while true:
		out.append(ring[n])
		if n == rightmost:
			break
		n = (n + (1 if forward else ring.size() - 1)) % ring.size()
	return out


## Where the studs stand on top: one in the middle of a jumper, the rows of
## a slope's back, every place of a plate's or a brick's top.
static func _stud_places(studs: Vector2i, count: int, rows: int, width: float,
		depth: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var across: int = maxi(1, studs.x)
	var deep: int = maxi(1, mini(studs.y, rows))
	if count == 1 and across * deep > 1:
		out.append(Vector2(width * 0.5, depth * 0.5))
		return out
	var left_x: float = (width - across * PITCH) * 0.5 + PITCH * 0.5
	var back_z: float = (depth - studs.y * PITCH) * 0.5 + PITCH * 0.5
	for z: int in deep:
		for x: int in across:
			if out.size() >= count:
				return out
			out.append(Vector2(left_x + x * PITCH, back_z + z * PITCH))
	return out


## A beam's holes, along its long side, dark where they go through.
static func _holes(item: RID, view: Callable, width: float, depth: float, height: float,
		count: int, ink: Color) -> void:
	var along_x: bool = width >= depth
	var length: float = width if along_x else depth
	var holes: int = mini(count, maxi(1, roundi(length / PITCH)))
	for n: int in holes:
		var at: float = (length - holes * PITCH) * 0.5 + PITCH * (n + 0.5)
		var ring := PackedVector2Array()
		for k: int in 14:
			var turn: float = TAU * k / 14.0
			var u: float = at + cos(turn) * PITCH * 0.3
			var y: float = height * 0.5 + sin(turn) * minf(PITCH * 0.3, height * 0.4)
			ring.append(view.call(u, y, depth) if along_x else view.call(width, y, u))
		RenderingServer.canvas_item_add_polygon(item, ring, PackedColorArray([ink]))
