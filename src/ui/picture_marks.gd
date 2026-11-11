## The picture a bug report sends, on which the person marks the spot
## (FeedbackDialog, Report a bug…; bugreport 2026-11-09): a drag draws a
## box, up to [constant MOST] of them, and Clear the marks takes them off.
##
## The boxes are kept in the picture's own pixels and drawn into it when it
## goes ([method marked]), so the owner's inbox shows each where it was
## drawn, whatever size the picture was shown at here. As the reporters the
## owner measured it against draw theirs (Linear's and GitHub's image
## markup, Jam's): a box with a bright red edge and a thin white halo, which
## reads on a light page and on the app's dark one alike.
class_name PictureMarks
extends Control

const MOST := 6
## A drag shorter than this, in this control's units, is a click, not a box.
const LEAST := 6.0
## The mark, iOS's system red, and the halo round it.
const MARK := Color(1.0, 0.231, 0.188)
const HALO := Color(1, 1, 1, 0.92)
## How thick the mark is drawn into a picture this many pixels wide, at
## least 3: about as thick as it looks here.
const THICK_PER := 400.0

signal changed()

var picture: Image = null
## Each box, in the picture's pixels: where the drag began and ended.
var marks: Array[Rect2i] = []
var _texture: ImageTexture = null
## Where a drag began, in this control's units; INF while none.
var _from: Vector2 = Vector2.INF
var _to: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	accessibility_name = "The picture that goes with the report. Drag on it to mark the spot."
	clip_contents = true


## Show [param image] (null: none), with no marks.
func show_picture(image: Image) -> void:
	picture = image
	_texture = ImageTexture.create_from_image(image) if image != null else null
	marks.clear()
	_from = Vector2.INF
	queue_redraw()
	changed.emit()


func clear() -> void:
	marks.clear()
	_from = Vector2.INF
	queue_redraw()
	changed.emit()


## Where the picture is drawn in this control: as large as fits, centred.
func shown_rect() -> Rect2:
	if picture == null or size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var scale: float = minf(size.x / picture.get_width(), size.y / picture.get_height())
	var drawn := Vector2(picture.get_width(), picture.get_height()) * scale
	return Rect2((size - drawn) * 0.5, drawn)


## A point of this control, in the picture's pixels, kept on the picture.
func to_picture(point: Vector2) -> Vector2i:
	var shown: Rect2 = shown_rect()
	if shown.size.x <= 0.0:
		return Vector2i.ZERO
	var at: Vector2 = (point - shown.position) * (picture.get_width() / shown.size.x)
	return Vector2i(clampi(roundi(at.x), 0, picture.get_width()), clampi(roundi(at.y), 0, picture.get_height()))


## A box of the picture, where it is shown in this control.
func to_shown(box: Rect2i) -> Rect2:
	var shown: Rect2 = shown_rect()
	if picture == null or shown.size.x <= 0.0:
		return Rect2()
	var scale: float = shown.size.x / picture.get_width()
	return Rect2(shown.position + Vector2(box.position) * scale, Vector2(box.size) * scale)


func _gui_input(event: InputEvent) -> void:
	if picture == null:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and shown_rect().has_point(button.position) and marks.size() < MOST:
			_from = button.position
			_to = button.position
			accept_event()
		elif not button.pressed and _from != Vector2.INF:
			_to = button.position
			_take()
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _from != Vector2.INF:
		_to = motion.position
		queue_redraw()
		accept_event()


## The drag made a box, unless it was a click.
func _take() -> void:
	var a: Vector2i = to_picture(_from)
	var b: Vector2i = to_picture(_to)
	var long: Vector2 = (_to - _from).abs()
	_from = Vector2.INF
	if long.x >= LEAST and long.y >= LEAST:
		var box := Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), (b - a).abs())
		if box.size.x >= 2 and box.size.y >= 2:
			marks.append(box)
	queue_redraw()
	changed.emit()


func _draw() -> void:
	if _texture == null:
		return
	var shown: Rect2 = shown_rect()
	draw_texture_rect(_texture, shown, false)
	draw_rect(shown, Color(1, 1, 1, 0.18), false, 1.0)
	for box: Rect2i in marks:
		_draw_mark(to_shown(box))
	if _from != Vector2.INF:
		var a: Vector2 = _from.clamp(shown.position, shown.end)
		var b: Vector2 = _to.clamp(shown.position, shown.end)
		_draw_mark(Rect2(a.min(b), (b - a).abs()))


func _draw_mark(box: Rect2) -> void:
	draw_rect(box.grow(1.5), HALO, false, 1.0)
	draw_rect(box.grow(-0.5), MARK, false, 2.5)
	draw_rect(box.grow(-2.5), HALO, false, 1.0)


## How thick a mark is drawn into the picture.
func thickness() -> int:
	return maxi(3, roundi(picture.get_width() / THICK_PER)) if picture != null else 3


## The picture with each box drawn into it, as it goes: the box's own edge
## red, [method thickness] pixels inside it, with a pixel of white either
## side. Null with no picture.
func marked() -> Image:
	if picture == null:
		return null
	var out: Image = picture.duplicate()
	var bounds := Rect2i(Vector2i.ZERO, out.get_size())
	var thick: int = thickness()
	for box: Rect2i in marks:
		_ring(out, box.grow(1), 1, HALO, bounds)
		_ring(out, box, thick, MARK, bounds)
		_ring(out, box.grow(-thick), 1, HALO, bounds)
	return out


## A frame [param thick] pixels wide inside [param box], in [param colour].
static func _ring(image: Image, box: Rect2i, thick: int, colour: Color, bounds: Rect2i) -> void:
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var t: int = mini(thick, mini(box.size.x, box.size.y))
	for edge: Rect2i in [Rect2i(box.position, Vector2i(box.size.x, t)),
			Rect2i(Vector2i(box.position.x, box.end.y - t), Vector2i(box.size.x, t)),
			Rect2i(box.position, Vector2i(t, box.size.y)),
			Rect2i(Vector2i(box.end.x - t, box.position.y), Vector2i(t, box.size.y))]:
		var kept: Rect2i = edge.intersection(bounds)
		if kept.size.x > 0 and kept.size.y > 0:
			image.fill_rect(kept, colour)


## The boxes in words, as the report's details keep them: "x,y,w,h" in the
## picture's pixels, ";" between.
func words() -> String:
	var out: PackedStringArray = []
	for box: Rect2i in marks:
		out.append("%d,%d,%d,%d" % [box.position.x, box.position.y, box.size.x, box.size.y])
	return ";".join(out)
