## A small cross where the view is turning.
##
## Turning around the point under the cursor is what makes an orbit feel
## like a hand on the model rather than a camera on a boom, and it is
## invisible: the same drag turns around a different place depending on
## where you started it, and nothing says where. So while a turn is
## happening there is a mark on the point, and when it stops the mark
## goes.
##
## Three short axis lines rather than a dot, because a dot in a model
## made of coloured bricks is lost among them, and because the lines
## also say which way the world's axes run.
class_name PivotMark
extends MeshInstance3D

## In LDU, at a distance of 400. Scaled with the camera so it stays the
## same size on screen — a fixed marker is a speck across a baseplate
## and swallows the model when you are close to a stud.
const REACH := 26.0
## X, Y and Z as the app draws them: here, the move handles (Handles) and
## the cut-away's knobs (SeeInside). With them the handle the pointer is on,
## and the dark edge each is drawn on. Kept here, on the first screen, so
## the knobs are drawn without compiling the handles.
const AXIS_COLOURS: Array[Color] = [Color(0.91, 0.30, 0.34), Color(0.42, 0.76, 0.32),
	Color(0.33, 0.58, 0.93)]
const LIT := Color(1.0, 0.85, 0.3)
const EDGE := Color(0.05, 0.07, 0.12, 0.85)

var camera: CadCamera

var _lines: ImmediateMesh


func _ready() -> void:
	_lines = ImmediateMesh.new()
	mesh = _lines
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	# Drawn over the brick it sits on: a mark hidden inside the thing it
	# is marking says nothing.
	paint.no_depth_test = true
	paint.render_priority = 9
	material_override = paint
	visible = false
	set_process(true)


var _drawn_at: Vector3 = Vector3.INF
var _drawn_reach: float = 0.0


func _process(_delta: float) -> void:
	if camera == null:
		return
	if not camera.pivot_shown:
		visible = false
		return

	var at: Vector3 = camera.pivot()
	var reach: float = REACH * maxf(camera.distance / 400.0, 0.25)
	# Built again only when it moved: new lines are a frame drawn (IdleDraw).
	if visible and at == _drawn_at and reach == _drawn_reach:
		return
	_drawn_at = at
	_drawn_reach = reach
	_lines.clear_surfaces()
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for axis: Array in [
		[Vector3.RIGHT, AXIS_COLOURS[0]],
		[Vector3.UP, AXIS_COLOURS[1]],
		[Vector3.BACK, AXIS_COLOURS[2]],
	]:
		var way: Vector3 = axis[0]
		_lines.surface_set_color(axis[1])
		_lines.surface_add_vertex(at - way * reach)
		_lines.surface_set_color(axis[1])
		_lines.surface_add_vertex(at + way * reach)
	_lines.surface_end()
	visible = true
