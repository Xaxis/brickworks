## Which way is which, in the corner.
##
## Every CAD viewport has one, and for the same reason: after a few
## turns of a model that is roughly symmetrical you have no idea which
## side you are looking at, and there is nothing on screen to tell you.
##
## It is also the only obvious way to reach the straight-on views. They
## were on the number keys and the number keys are not obvious — nobody
## presses 3 to see the left side of something unless they have been
## told to.
##
## Drawn in 2D rather than as a little 3D scene. The axes are three
## directions and a direction projects to a line; a second viewport with
## its own meshes and lights would be a great deal of machinery to draw
## six dots and three lines, and it would not be as crisp.
class_name AxisGizmo
extends Control

## The six directions, as the view each one looks from and the colour to
## draw it in. Red, green and blue for x, y and z is universal enough
## that using anything else would be the surprising choice.
const AXES: Array[Dictionary] = [
	{"axis": Vector3.RIGHT, "view": "right", "label": "X",
		"tint": Color(0.91, 0.30, 0.34)},
	{"axis": Vector3.LEFT, "view": "left", "label": "",
		"tint": Color(0.91, 0.30, 0.34)},
	{"axis": Vector3.UP, "view": "top", "label": "Y",
		"tint": Color(0.42, 0.76, 0.32)},
	{"axis": Vector3.DOWN, "view": "bottom", "label": "",
		"tint": Color(0.42, 0.76, 0.32)},
	{"axis": Vector3.BACK, "view": "front", "label": "Z",
		"tint": Color(0.33, 0.58, 0.93)},
	{"axis": Vector3.FORWARD, "view": "back", "label": "",
		"tint": Color(0.33, 0.58, 0.93)},
]

const SIZE := 84.0
const DOT := 9.0

var camera: CadCamera

var _font: Font
var _hovered: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click an axis for a straight-on view"
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_delta: float) -> void:
	# Redrawn every frame because it follows the camera, and the camera
	# eases towards where it is going rather than jumping.
	if camera != null:
		queue_redraw()


## Where each direction lands on this little square, and how near the
## viewer it is.
##
## In view space the camera looks along -z, x is right and y is up. So a
## world direction turned into view space gives the screen offset
## straight off its x and y, and its z says which ones are in front.
func _spokes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if camera == null:
		return out
	var basis: Basis = camera.global_transform.basis.orthonormalized()
	var middle: Vector2 = size * 0.5
	var reach: float = SIZE * 0.5 - DOT - 2.0
	for entry: Dictionary in AXES:
		var seen: Vector3 = basis.transposed() * (entry["axis"] as Vector3)
		out.append({
			"at": middle + Vector2(seen.x, -seen.y) * reach,
			"depth": seen.z,
			"view": entry["view"],
			"label": entry["label"],
			"tint": entry["tint"],
		})
	# Furthest first, so the near ones are drawn over them.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["depth"]) < float(b["depth"]))
	return out


func _draw() -> void:
	var spokes: Array[Dictionary] = _spokes()
	if spokes.is_empty():
		return
	var middle: Vector2 = size * 0.5

	for spoke: Dictionary in spokes:
		var tint: Color = spoke["tint"]
		# Behind the middle, and dimmed to say so.
		var near: bool = float(spoke["depth"]) >= 0.0
		var shade: Color = tint if near else tint.darkened(0.45)
		shade.a = 1.0 if near else 0.75

		if not str(spoke["label"]).is_empty():
			draw_line(middle, spoke["at"], shade, 2.0, true)

		var here: Vector2 = spoke["at"]
		var lit: bool = _hovered == str(spoke["view"])
		if near or lit:
			draw_circle(here, DOT + (1.5 if lit else 0.0), shade)
		else:
			draw_arc(here, DOT, 0.0, TAU, 24, shade, 2.0, true)

		var label: String = spoke["label"]
		if label.is_empty():
			continue
		var wide: float = _font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, here + Vector2(-wide * 0.5, 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.08, 0.09, 0.11) if near else Color(1, 1, 1, 0.8))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was: String = _hovered
		_hovered = _at((event as InputEventMouseMotion).position)
		if was != _hovered:
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event
	if not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var view: String = _at(button.position)
	if view.is_empty() or camera == null:
		return
	camera.set_view(view)
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _hovered.is_empty():
		_hovered = ""
		queue_redraw()


## Which direction, if any, is under a point. Nearest first, so clicking
## where two overlap picks the one that is drawn on top.
func _at(point: Vector2) -> String:
	var spokes: Array[Dictionary] = _spokes()
	spokes.reverse()
	for spoke: Dictionary in spokes:
		if point.distance_to(spoke["at"]) <= DOT + 3.0:
			return str(spoke["view"])
	return ""
