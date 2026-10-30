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
## Nothing is kept and nothing processes: a few polygons drawn with the tile.
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


## Draw [param info] in [param rect] of [param item], in [param colour],
## [param strength] of the way in (it fades out as the picture fades in).
static func draw(item: CanvasItem, rect: Rect2, info: PartLibrary.PartInfo, colour: Color,
		strength: float) -> void:
	if info == null or strength <= 0.0:
		return
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
	var alpha: float = GHOST * strength
	var top: Color = _shade(colour, 0.22, alpha)
	var left: Color = _shade(colour, 0.0, alpha)
	var right: Color = _shade(colour, -0.28, alpha)
	var edge := Color(0, 0, 0, 0.28 * strength)
	if round:
		_cylinder(item, view, Vector3(width * 0.5, 0.0, depth * 0.5), width * 0.5, depth * 0.5,
			height, top, left, edge)
	elif info.category == "Slope" and height > PLATE * 1.5:
		_slope(item, view, width, depth, height, studs, info.stud_count, top, left, right, edge)
	else:
		_box(item, view, width, depth, height, top, left, right, edge)
		if info.category == "Technic" and info.stud_count == 0 \
				and int(info.connector_counts.get("pin_hole", 0)) > 0:
			_holes(item, view, width, depth, height, int(info.connector_counts["pin_hole"]),
				_shade(colour, -0.6, alpha))
	if info.stud_count > 0:
		var rows: int = studs.y
		if info.category == "Slope" and not round:
			rows = maxi(1, ceili(float(info.stud_count) / float(maxi(studs.x, 1))))
		for at: Vector2 in _stud_places(studs, info.stud_count, rows, width, depth):
			_cylinder(item, view, Vector3(at.x, height, at.y), STUD_RADIUS, STUD_RADIUS,
				STUD_HEIGHT, top, left, edge)


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
	var name: String = info.name.to_lower()
	return name.contains(" round") and not name.contains("corner round") \
		and not name.contains("round corner") and not name.contains("rounded") \
		and info.footprint_studs().x == info.footprint_studs().y


static func _face(item: CanvasItem, points: PackedVector2Array, fill: Color, edge: Color) -> void:
	item.draw_colored_polygon(points, fill)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	item.draw_polyline(closed, edge, 1.0, true)


## The three faces of a box seen from its front corner: its top, its left
## (the z end) and its right (the x end).
static func _box(item: CanvasItem, view: Callable, width: float, depth: float, height: float,
		top: Color, left: Color, right: Color, edge: Color) -> void:
	_face(item, PackedVector2Array([view.call(0.0, height, 0.0), view.call(width, height, 0.0),
		view.call(width, height, depth), view.call(0.0, height, depth)]), top, edge)
	_face(item, PackedVector2Array([view.call(0.0, height, depth), view.call(width, height, depth),
		view.call(width, 0.0, depth), view.call(0.0, 0.0, depth)]), left, edge)
	_face(item, PackedVector2Array([view.call(width, height, 0.0), view.call(width, height, depth),
		view.call(width, 0.0, depth), view.call(width, 0.0, 0.0)]), right, edge)


## A slope: flat on top over the rows its studs take at the back, falling
## from there to a plate's height at the front.
static func _slope(item: CanvasItem, view: Callable, width: float, depth: float, height: float,
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


## An upright round, [param across] and [param deep] its radii, standing
## on [param base]: its side, then its top.
static func _cylinder(item: CanvasItem, view: Callable, base: Vector3, across: float, deep: float,
		height: float, top: Color, side: Color, edge: Color) -> void:
	var low := PackedVector2Array()
	var high := PackedVector2Array()
	for n: int in 20:
		var turn: float = TAU * n / 20.0
		var x: float = base.x + cos(turn) * across
		var z: float = base.z + sin(turn) * deep
		low.append(view.call(x, base.y, z))
		high.append(view.call(x, base.y + height, z))
	# The side is what lies between the two rings' outlines: the lower
	# ring's near half and the upper ring's, joined.
	var body := PackedVector2Array()
	var near := _near_half(low)
	body.append_array(near)
	var upper := _near_half(high)
	upper.reverse()
	body.append_array(upper)
	if body.size() >= 3:
		item.draw_colored_polygon(body, side)
	_face(item, high, top, edge)
	item.draw_polyline(near, edge, 1.0, true)


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
static func _holes(item: CanvasItem, view: Callable, width: float, depth: float, height: float,
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
		item.draw_colored_polygon(ring, ink)
