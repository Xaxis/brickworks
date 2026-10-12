## The view cube in the corner, and the arrows round it: navigating with
## nothing but a left button.
##
## Asked for by the owner: "there should be a way to use the mouse to move
## and navigate the view and pan and not placing bricks." A trackpad has no
## middle button and a right drag on one is awkward, so the view has to be
## reachable by clicking and dragging things that say what they do, as
## Mecabricks and every CAD program's view cube do.
##
## The cube turns with the view. A click on a face looks at the model from
## that side, on an edge from between the two faces, on a corner from
## between three. A drag on it turns the view. Round it, four arrows turn
## the view a step a click (held, they keep turning; dragged, they follow
## the pointer). Under it: a pad that slides the view (drag it, or click an
## arrow on it), zoom out and in, and fit.
##
## The cube is drawn in 2D, square on: a projected cube is six
## parallelograms, and a second viewport with its own meshes and lights
## would be a great deal of machinery for that.
class_name ViewCube
extends Control

const CUBE := 84.0
const TOUCH_CUBE := 116.0
const ROW := 28.0
const TOUCH_ROW := 40.0

## The six faces: the direction each looks from (towards the eye) and its
## name. +z is the front: CadCamera's "front" stands at +z.
const FACES: Array[Dictionary] = [
	{"normal": Vector3(0, 0, 1), "name": "FRONT", "u": Vector3(1, 0, 0), "v": Vector3(0, 1, 0)},
	{"normal": Vector3(0, 0, -1), "name": "BACK", "u": Vector3(-1, 0, 0), "v": Vector3(0, 1, 0)},
	{"normal": Vector3(1, 0, 0), "name": "RIGHT", "u": Vector3(0, 0, -1), "v": Vector3(0, 1, 0)},
	{"normal": Vector3(-1, 0, 0), "name": "LEFT", "u": Vector3(0, 0, 1), "v": Vector3(0, 1, 0)},
	{"normal": Vector3(0, 1, 0), "name": "TOP", "u": Vector3(1, 0, 0), "v": Vector3(0, 0, -1)},
	{"normal": Vector3(0, -1, 0), "name": "BOTTOM", "u": Vector3(1, 0, 0), "v": Vector3(0, 0, 1)},
]

## How much of a face, from its edge in, is the edge or the corner rather
## than the face itself.
const RIM := 0.62

var camera: CadCamera
## Fit: the selection, or the whole model.
var fit: Callable = Callable()

var _font: Font
var _hover: Vector3 = Vector3.ZERO
var _pressed_at: Vector2 = Vector2.INF
var _dragged: bool = false
var _arrows: Dictionary = {}     ## name -> NavButton


static func cube_size() -> float:
	return TOUCH_CUBE if DisplayServer.is_touchscreen_available() else CUBE


static func row_size() -> float:
	return TOUCH_ROW if DisplayServer.is_touchscreen_available() else ROW


## The room it takes: the cube, and the row under it.
static func size_for() -> Vector2:
	return Vector2(cube_size(), cube_size() + row_size() + 4.0)


func _ready() -> void:
	custom_minimum_size = size_for()
	size = size_for()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Pressed, not read: the pointing hand, as its arrows have. It is not a
	# button, so Cursors._point_at passes it by.
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click a face, an edge or a corner to look from there; drag to turn the view"
	_font = ThemeDB.fallback_font
	var cube: float = cube_size()
	var arrow: float = 16.0 if cube < 100.0 else 22.0
	# Round the cube: turn the view a step left, right, up, down.
	for entry: Array in [["cube_turn_left", Vector2(-1, 0), Vector2(0, (cube - arrow) * 0.5)],
			["cube_turn_right", Vector2(1, 0), Vector2(cube - arrow, (cube - arrow) * 0.5)],
			["cube_turn_up", Vector2(0, 1), Vector2((cube - arrow) * 0.5, 0)],
			["cube_turn_down", Vector2(0, -1), Vector2((cube - arrow) * 0.5, cube - arrow)]]:
		var made := NavButton.new()
		made.camera = camera
		made.kind = "turn"
		made.way = entry[1]
		made.position = entry[2]
		made.size = Vector2(arrow, arrow)
		made.tooltip_text = "Turn the view %s — click for a step, hold to keep turning, or drag" % {
			"cube_turn_left": "left", "cube_turn_right": "right", "cube_turn_up": "up",
			"cube_turn_down": "down"}[entry[0]]
		add_child(made)
		_arrows[entry[0]] = made
	# Under it: slide, zoom out, zoom in, fit.
	var row: float = row_size()
	var gap: float = (cube - row * 4.0) / 3.0
	var kinds: Array = [["cube_pan", "pan", "Slide the view — drag this, or click one of its arrows"],
		["cube_zoom_out", "zoom_out", "Zoom out — click, hold, or drag up and down"],
		["cube_zoom_in", "zoom_in", "Zoom in — click, hold, or drag up and down"],
		["cube_fit", "fit", "Fit the selection, or the whole model   F"]]
	for n: int in kinds.size():
		var made := NavButton.new()
		made.camera = camera
		made.kind = kinds[n][1]
		made.fit = func() -> void:
			if fit.is_valid():
				fit.call()
		made.position = Vector2(n * (row + gap), cube + 4.0)
		made.size = Vector2(row, row)
		made.tooltip_text = kinds[n][2]
		add_child(made)
		_arrows[kinds[n][0]] = made
	set_process(true)


## The way the camera faced when this was last drawn.
var _drawn_facing: Basis = Basis()


func _process(_delta: float) -> void:
	# Redrawn whenever the camera turned, because it follows the camera,
	# which eases. Not every frame: a redraw is a frame drawn (IdleDraw).
	if camera == null:
		return
	var facing: Basis = camera.global_transform.basis
	if facing != _drawn_facing:
		_drawn_facing = facing
		queue_redraw()


## What the page is told is here, for a browser check to press: the cube,
## each face that faces the viewer, and the buttons round it.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _arrows:
		out[name] = _arrows[name]
	return out


## Where on the page each visible face's middle is, for the same check.
func face_points() -> Dictionary:
	var out: Dictionary = {}
	for face: Dictionary in FACES:
		var seen: Vector3 = _seen(face["normal"])
		if seen.z > 0.3:
			out["cube_" + str(face["name"]).to_lower()] = global_position + _to_screen(face["normal"])
	return out


# -- the cube ------------------------------------------------------------------


## A world direction in the view's space: x right, y up, z towards the eye.
func _seen(world: Vector3) -> Vector3:
	if camera == null:
		return world
	return camera.global_transform.basis.orthonormalized().transposed() * world


func _half() -> float:
	return cube_size() * 0.25


## A point of the unit cube (each axis -1 to 1) on this control.
func _to_screen(point: Vector3) -> Vector2:
	var seen: Vector3 = _seen(point)
	return Vector2(cube_size() * 0.5, cube_size() * 0.5) + Vector2(seen.x, -seen.y) * _half()


func _draw() -> void:
	if camera == null:
		return
	var middle := Vector2(cube_size() * 0.5, cube_size() * 0.5)
	draw_circle(middle, cube_size() * 0.5 - 1.0, Color(0.11, 0.12, 0.14, 0.55))
	var faces: Array = FACES.duplicate()
	faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _seen(a["normal"]).z < _seen(b["normal"]).z)
	for face: Dictionary in faces:
		var facing: float = _seen(face["normal"]).z
		if facing <= 0.02:
			continue
		var n: Vector3 = face["normal"]
		var u: Vector3 = face["u"]
		var v: Vector3 = face["v"]
		var corners := PackedVector2Array([_to_screen(n - u - v), _to_screen(n + u - v),
			_to_screen(n + u + v), _to_screen(n - u + v)])
		var lit: bool = _hover == n
		var shade := Color(0.80, 0.83, 0.88).darkened(0.55 - 0.45 * facing)
		if lit:
			shade = Color(0.36, 0.6, 1.0)
		draw_colored_polygon(corners, shade)
		var outline := corners.duplicate()
		outline.append(corners[0])
		draw_polyline(outline, Color(0.08, 0.09, 0.11, 0.9), 1.2, true)
		if facing > 0.35:
			var words: String = face["name"]
			var points: int = 9 if cube_size() < 100.0 else 12
			var wide: float = _font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
			draw_string(_font, _to_screen(n) + Vector2(-wide * 0.5, points * 0.35), words,
				HORIZONTAL_ALIGNMENT_LEFT, -1, points,
				Color(1, 1, 1, facing) if lit else Color(0.08, 0.09, 0.11, facing))
	# An edge or a corner under the pointer: a dot where it is.
	if _hover != Vector3.ZERO and _hover.abs().x + _hover.abs().y + _hover.abs().z > 1.5:
		draw_circle(_to_screen(_hover), 4.5, Color(0.36, 0.6, 1.0))


## The face, edge or corner under a point, as the direction to look from:
## a face's normal, or the sum of two or three of them. Zero for none.
func _region(at: Vector2) -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_facing: float = 0.0
	for face: Dictionary in FACES:
		var facing: float = _seen(face["normal"]).z
		if facing <= 0.02:
			continue
		var n: Vector3 = face["normal"]
		var u: Vector3 = face["u"]
		var v: Vector3 = face["v"]
		# The face is a parallelogram: its middle plus a*U + b*V on the
		# screen. Solve for a and b.
		var origin: Vector2 = _to_screen(n)
		var across: Vector2 = _to_screen(n + u) - origin
		var up: Vector2 = _to_screen(n + v) - origin
		var det: float = across.x * up.y - across.y * up.x
		if absf(det) < 0.0001:
			continue
		var d: Vector2 = at - origin
		var a: float = (d.x * up.y - d.y * up.x) / det
		var b: float = (across.x * d.y - across.y * d.x) / det
		if absf(a) > 1.0 or absf(b) > 1.0 or facing < best_facing:
			continue
		best_facing = facing
		best = n
		if absf(a) > RIM:
			best += u * signf(a)
		if absf(b) > RIM:
			best += v * signf(b)
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _pressed_at != Vector2.INF and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if _dragged or motion.position.distance_to(_pressed_at) > 4.0:
				_dragged = true
				if camera != null:
					camera.turn_by_drag(motion.relative)
				accept_event()
				return
		var was: Vector3 = _hover
		_hover = _region(motion.position)
		if was != _hover:
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if button.pressed:
		_pressed_at = button.position
		_dragged = false
		return
	var was_drag: bool = _dragged
	_pressed_at = Vector2.INF
	_dragged = false
	if was_drag or camera == null:
		return
	var from: Vector3 = _region(button.position)
	if from != Vector3.ZERO:
		camera.look_from(from)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != Vector3.ZERO:
		_hover = Vector3.ZERO
		queue_redraw()


## One of the buttons round the cube: turn, slide, zoom or fit. A click is a
## step; held, it keeps going; dragged, it follows the pointer.
class NavButton extends Control:
	var camera: CadCamera
	var kind: String = "turn"      ## turn, pan, zoom_in, zoom_out, fit
	var way: Vector2 = Vector2.ZERO
	var fit: Callable = Callable()

	const HOLD_MS := 280
	var _down_at: int = -1
	var _pressed_at: Vector2 = Vector2.ZERO
	var _dragged: bool = false
	var _hover: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _process(delta: float) -> void:
		# Held without moving: keep going, at the keys' rate.
		if _down_at < 0 or _dragged or camera == null:
			return
		if Time.get_ticks_msec() - _down_at < HOLD_MS:
			return
		match kind:
			"turn":
				camera.key_hold(delta, 0, way, Vector2.ZERO)
			"zoom_in":
				camera.key_hold(delta, 1, Vector2.ZERO, Vector2.ZERO)
			"zoom_out":
				camera.key_hold(delta, -1, Vector2.ZERO, Vector2.ZERO)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var motion: InputEventMouseMotion = event
			if _down_at < 0 or (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				return
			if not _dragged and motion.position.distance_to(_pressed_at) <= 4.0:
				return
			_dragged = true
			accept_event()
			if camera == null:
				return
			match kind:
				"turn":
					camera.turn_by_drag(motion.relative)
				"pan":
					camera.slide_by_drag(motion.relative)
				"zoom_in", "zoom_out":
					camera.zoom_by_drag(motion.relative.y)
			return
		if not (event is InputEventMouseButton):
			return
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if button.pressed:
			_down_at = Time.get_ticks_msec()
			_pressed_at = button.position
			_dragged = false
			queue_redraw()
			return
		var quick: bool = Time.get_ticks_msec() - _down_at < HOLD_MS
		var was_drag: bool = _dragged
		_down_at = -1
		_dragged = false
		queue_redraw()
		if was_drag or not quick or camera == null:
			return
		match kind:
			"turn":
				camera.key_turn(way)
			"zoom_in":
				camera.key_zoom(1)
			"zoom_out":
				camera.key_zoom(-1)
			"pan":
				# The arrow of the pad that was clicked: the way from its
				# middle to the click, to the nearest of four.
				var from_middle: Vector2 = button.position - size * 0.5
				var step := Vector2(signf(from_middle.x), 0.0) \
					if absf(from_middle.x) >= absf(from_middle.y) \
					else Vector2(0.0, -signf(from_middle.y))
				camera.key_slide(step)
			"fit":
				if fit.is_valid():
					fit.call()

	func _draw() -> void:
		var middle: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		var down: bool = _down_at >= 0
		var ink := Color(0.89, 0.9, 0.93) if not _hover else Color(0.56, 0.74, 1.0)
		if kind != "turn":
			var face := Color(0.16, 0.17, 0.2, 0.92) if not down else Color(0.24, 0.34, 0.52, 0.95)
			draw_circle(middle, r - 0.5, face)
			draw_arc(middle, r - 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.14), 1.0, true)
		match kind:
			"turn":
				# A triangle pointing the way it turns the view.
				var tip: Vector2 = middle + Vector2(way.x, -way.y) * r * 0.8
				var side := Vector2(-way.y, -way.x) * r * 0.6
				var back: Vector2 = middle - Vector2(way.x, -way.y) * r * 0.35
				var shade := ink if not down else Color(0.36, 0.6, 1.0)
				draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), shade)
			"pan":
				for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					var tip: Vector2 = middle + dir * r * 0.72
					var side := Vector2(dir.y, dir.x) * r * 0.22
					var back: Vector2 = middle + dir * r * 0.4
					draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), ink)
				draw_circle(middle, r * 0.14, ink)
			"zoom_in", "zoom_out":
				draw_line(middle - Vector2(r * 0.45, 0), middle + Vector2(r * 0.45, 0), ink, 2.0, true)
				if kind == "zoom_in":
					draw_line(middle - Vector2(0, r * 0.45), middle + Vector2(0, r * 0.45), ink, 2.0, true)
			"fit":
				var e: float = r * 0.42
				for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var at: Vector2 = middle + corner * e
					draw_line(at, at - Vector2(corner.x * e * 0.55, 0), ink, 1.8, true)
					draw_line(at, at - Vector2(0, corner.y * e * 0.55), ink, 1.8, true)
