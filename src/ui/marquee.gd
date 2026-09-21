## The rectangle you drag to select things.
##
## Every CAD viewport has one, and they nearly all agree on a detail
## worth keeping: which way you drag decides what it takes. Dragging
## left to right takes only what falls entirely inside the box;
## dragging right to left takes anything the box touches. It reads as
## one gesture and it is two, and people who use these tools reach for
## the difference without thinking about it.
##
## So the box says which it is while you are drawing it — a solid edge
## for "wholly inside", a dashed one for "anything it touches" — rather
## than leaving you to find out on release.
class_name Marquee
extends Control

## How far the pointer must travel before a click becomes a drag.
const SLOP := 5.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _drawing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func begin(at: Vector2) -> void:
	_from = at
	_to = at
	_drawing = false
	visible = false


## Returns true once the pointer has moved far enough to mean a box
## rather than a click.
func drag_to(at: Vector2) -> bool:
	_to = at
	if not _drawing and _from.distance_to(at) > SLOP:
		_drawing = true
		visible = true
	if _drawing:
		queue_redraw()
	return _drawing


func is_drawing() -> bool:
	return _drawing


## Anything the box touches, rather than only what is wholly inside.
func takes_touching() -> bool:
	return _to.x < _from.x


func box() -> Rect2:
	return Rect2(Vector2(minf(_from.x, _to.x), minf(_from.y, _to.y)),
		(_to - _from).abs())


func finish() -> void:
	_drawing = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not _drawing:
		return
	var rect: Rect2 = box()
	var tint := Color(0.45, 0.72, 1.0)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.12), true)
	if takes_touching():
		# Dashed, for the one that takes anything it touches.
		_dashed(rect, tint)
	else:
		draw_rect(rect, tint, false, 1.5)


func _dashed(rect: Rect2, tint: Color) -> void:
	const DASH := 7.0
	for side: Array in [
		[rect.position, Vector2(rect.end.x, rect.position.y)],
		[Vector2(rect.end.x, rect.position.y), rect.end],
		[rect.end, Vector2(rect.position.x, rect.end.y)],
		[Vector2(rect.position.x, rect.end.y), rect.position],
	]:
		var from: Vector2 = side[0]
		var to: Vector2 = side[1]
		var span: float = from.distance_to(to)
		if span <= 0.0:
			continue
		var step: Vector2 = (to - from) / span
		var at: float = 0.0
		while at < span:
			var stop: float = minf(at + DASH, span)
			draw_line(from + step * at, from + step * stop, tint, 1.5)
			at = stop + DASH
