## The canvas a print is drawn on: one area of a part, its pixels the
## picture's pixels, shown big enough to draw on.
##
## Outside the part's surface (the mask) is shaded, so a torso's canvas
## shows its trapezoid and a pair of legs' the gap between them; the
## middle line is drawn, which is the middle of a face or a torso and
## where a mirrored mark is reflected.
##
## Left button draws with the tool in hand; the right or middle button,
## or Space held, moves the canvas; the wheel zooms where it points. With
## "move" in hand the left button drags the active layer's picture, its
## edges and middle snapping to the face's edges and middle, and the wheel
## with Ctrl held scales it.
class_name PrintCanvas
extends Control

signal changed()
signal colour_picked(colour: Color)
## The active layer's picture was moved or scaled here.
signal picture_moved()

const TOOLS: Array[String] = ["brush", "eraser", "line", "box", "oval", "fill", "text", "pick",
	"move"]
## How near, in screen pixels, a picture's edge comes to the face's before
## it snaps there.
const SNAP_PIXELS := 8.0

var paint: PrintPaint
var area: PartPrints.Area
var tool: String = "brush"
var colour: Color = Color.BLACK
## Brush and line width, in canvas pixels.
var radius: float = 6.0
var filled: bool = true
var words: String = "LEGO"
var word_size: int = 32

var _zoom: float = 1.0
var _pan := Vector2.ZERO
var _picture: ImageTexture
var _shade: ImageTexture
var _drawing: bool = false
var _moving: bool = false
var _space: bool = false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _hover := Vector2(-1, -1)
var _grab_from := Vector2.ZERO
var _grab_centre := Vector2.ZERO
## What a dragged picture snapped to last, for the outline to say.
var snapped: Array[String] = []


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(fit)


## Draw on this area with this document.
func show_area(on: PartPrints.Area, document: PrintPaint) -> void:
	area = on
	paint = document
	_picture = ImageTexture.create_from_image(paint.composite())
	_shade = ImageTexture.create_from_image(_shade_of(area.mask, paint.width, paint.height))
	fit()


## The whole canvas in view, as large as fits.
func fit() -> void:
	if paint == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = maxf(0.25, minf((size.x - 16.0) / paint.width, (size.y - 16.0) / paint.height))
	_pan = (size - Vector2(paint.width, paint.height) * _zoom) * 0.5
	queue_redraw()


## Show what the document holds now: after an undo, a layer hidden.
func refresh() -> void:
	if paint == null:
		return
	if _picture == null or _picture.get_size() != Vector2(paint.width, paint.height):
		_picture = ImageTexture.create_from_image(paint.composite())
	else:
		_picture.update(paint.composite())
	queue_redraw()
	changed.emit()


## Canvas pixels of a point on the control.
func to_canvas(at: Vector2) -> Vector2:
	return (at - _pan) / _zoom


func to_screen(at: Vector2) -> Vector2:
	return at * _zoom + _pan


## Outside the part's surface, shaded: clear where the mask is.
static func _shade_of(mask: Image, w: int, h: int) -> Image:
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.06, 0.08, 0.62))
	if mask != null and mask.get_size() == Vector2i(w, h):
		var clear := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		out.blit_rect_mask(clear, mask, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.14, 0.16))
	if paint == null:
		return
	var box := Rect2(_pan, Vector2(paint.width, paint.height) * _zoom)
	# A checker under the canvas, so clear reads as clear.
	draw_rect(box, Color(0.82, 0.82, 0.84))
	var cell: float = maxf(8.0, 12.0 * _zoom)
	var y: float = 0.0
	var row: int = 0
	while y < box.size.y:
		var x: float = cell if row % 2 == 1 else 0.0
		while x < box.size.x:
			draw_rect(Rect2(box.position + Vector2(x, y),
				Vector2(minf(cell, box.size.x - x), minf(cell, box.size.y - y))),
				Color(0.72, 0.72, 0.75))
			x += cell * 2.0
		y += cell
		row += 1
	draw_texture_rect(_picture, box, false)
	draw_texture_rect(_shade, box, false)
	for guide: Array in area.guides if area != null else []:
		draw_dashed_line(to_screen(guide[0]), to_screen(guide[1]), Color(0.3, 0.75, 1.0, 0.55),
			1.0, 6.0)
	draw_rect(box, Color(1, 1, 1, 0.25), false, 1.0)
	# The active layer's picture, outlined, with its middle.
	var picture: PrintPicture = paint.layer().picture
	if picture != null:
		var outline := PackedVector2Array()
		for corner: Vector2 in picture.corners():
			outline.append(to_screen(corner))
		outline.append(outline[0])
		draw_polyline(outline, Color(1.0, 0.75, 0.2, 0.9), 1.5)
		var middle: Vector2 = to_screen(picture.centre)
		draw_line(middle - Vector2(6, 0), middle + Vector2(6, 0), Color(1.0, 0.75, 0.2), 1.0)
		draw_line(middle - Vector2(0, 6), middle + Vector2(0, 6), Color(1.0, 0.75, 0.2), 1.0)
	# What the tool will do.
	if _drawing and tool in ["line", "box", "oval"]:
		var a: Vector2 = to_screen(_from)
		var b: Vector2 = to_screen(_to)
		var ink := Color(colour, 0.8)
		var width: float = maxf(1.0, radius * 2.0 * _zoom)
		match tool:
			"line":
				draw_line(a, b, ink, width)
			"box":
				var rect := Rect2(a, b - a).abs()
				if filled:
					draw_rect(rect, ink)
				else:
					draw_rect(rect, ink, false, width)
			"oval":
				var centre: Vector2 = (a + b) * 0.5
				var half: Vector2 = ((b - a) * 0.5).abs()
				var points := PackedVector2Array()
				for n: int in 65:
					var angle: float = TAU * n / 64.0
					points.append(centre + Vector2(cos(angle) * half.x, sin(angle) * half.y))
				if filled:
					draw_colored_polygon(points, ink)
				else:
					draw_polyline(points, ink, width)
	if _hover.x >= 0.0 and tool in ["brush", "eraser"]:
		draw_arc(to_screen(_hover), maxf(2.0, radius * _zoom), 0.0, TAU, 40,
			Color(1, 1, 1, 0.8), 1.0)
		if paint.mirror:
			draw_arc(to_screen(Vector2(paint.width - _hover.x, _hover.y)),
				maxf(2.0, radius * _zoom), 0.0, TAU, 40, Color(1, 1, 1, 0.4), 1.0)
	if _hover.x >= 0.0 and tool == "text":
		draw_string(get_theme_default_font(), to_screen(_hover), words,
			HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(6, int(word_size * _zoom)), Color(colour, 0.6))


func _gui_input(event: InputEvent) -> void:
	if paint == null:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed and button.ctrl_pressed and paint.layer().picture != null:
				var grow: float = 1.05 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.05
				paint.change_picture({"scale": paint.layer().picture.scale * grow})
				refresh()
				picture_moved.emit()
			elif button.pressed:
				var before: Vector2 = to_canvas(button.position)
				var by: float = 1.15 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				_zoom = clampf(_zoom * by, 0.25, 24.0)
				_pan = button.position - before * _zoom
				queue_redraw()
			accept_event()
			return
		if button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] \
				or (button.button_index == MOUSE_BUTTON_LEFT and _space):
			_moving = button.pressed
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			if button.pressed:
				_press(to_canvas(button.position))
			else:
				_release(to_canvas(button.position))
			accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _moving:
			_pan += motion.relative
			queue_redraw()
			accept_event()
			return
		_hover = to_canvas(motion.position)
		if _drawing:
			_drag(_hover)
		queue_redraw()
	elif event is InputEventKey:
		var key: InputEventKey = event
		if key.keycode == KEY_SPACE:
			_space = key.pressed
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2(-1, -1)
		queue_redraw()


# -- the tools ------------------------------------------------------------------


## Press, drag and release, in canvas pixels: what a mouse does, and what a
## check does without one.
func _press(at: Vector2) -> void:
	_from = at
	_to = at
	match tool:
		"brush", "eraser":
			_drawing = true
			paint.begin()
			paint.brush_to(at, radius, colour if tool == "brush" else PrintPaint.CLEAR)
			refresh()
		"fill":
			paint.fill(Vector2i(at.floor()), colour)
			refresh()
		"text":
			paint.text(at, words, word_size, colour)
			refresh()
		"pick":
			var found: Color = paint.colour_at(Vector2i(at.floor()))
			if found.a > 0.0:
				colour_picked.emit(found)
		"move":
			if paint.layer().picture == null:
				return
			_drawing = true
			_grab_from = at
			_grab_centre = paint.layer().picture.centre
			paint.change_picture({})
		_:
			_drawing = true


func _drag(at: Vector2) -> void:
	_to = at
	if tool == "move" and paint.layer().picture != null:
		paint.change_picture({"centre": _snap(_grab_centre + at - _grab_from)}, true)
		refresh()
		picture_moved.emit()
		return
	if tool in ["brush", "eraser"]:
		paint.brush_to(at, radius, colour if tool == "brush" else PrintPaint.CLEAR)
		refresh()


func _release(at: Vector2) -> void:
	if not _drawing:
		return
	_drawing = false
	_to = at
	match tool:
		"brush", "eraser":
			paint.end()
		"move":
			snapped.clear()
		"line":
			paint.line(_from, _to, radius, colour)
		"box":
			paint.rectangle(_from, _to, radius, colour, filled)
		"oval":
			paint.ellipse(_from, _to, radius, colour, filled)
	refresh()


## A stroke through some canvas points, as a hand would make it: for a
## check to draw with the tools a person uses.
func stroke(points: Array) -> void:
	if points.is_empty():
		return
	_press(points[0])
	for n: int in range(1, points.size()):
		_drag(points[n])
	_release(points[points.size() - 1])


## Where a dragged picture's middle goes: its edges or its middle snapped to
## the face's edges or middle when they come within [constant SNAP_PIXELS]
## on screen. The face is the area's mask's extent; the canvas's own edges
## and middle too.
func _snap(centre: Vector2) -> Vector2:
	snapped.clear()
	var picture: PrintPicture = paint.layer().picture
	var reach := Rect2(picture.corners()[0], Vector2.ZERO)
	for corner: Vector2 in picture.corners():
		reach = reach.expand(corner)
	var half: Vector2 = reach.size * 0.5
	var face := Rect2(0, 0, paint.width, paint.height)
	if area != null and area.mask != null:
		var used: Rect2i = area.mask.get_used_rect()
		if used.size.x > 0:
			face = Rect2(used)
	var tolerance: float = SNAP_PIXELS / _zoom
	var out: Vector2 = centre
	for axis: int in 2:
		var targets: Array[float] = [face.position[axis], face.get_center()[axis], face.end[axis],
			0.0, [paint.width, paint.height][axis] * 0.5]
		var best: float = tolerance
		for offset: float in [-half[axis], 0.0, half[axis]]:
			for target: float in targets:
				var gap: float = target - (centre[axis] + offset)
				if absf(gap) < best:
					best = absf(gap)
					out[axis] = centre[axis] + gap
		if best < tolerance:
			snapped.append("x" if axis == 0 else "y")
	return out
