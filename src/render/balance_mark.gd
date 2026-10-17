## Where the model stands and where its weight is, drawn on the floor:
## Tools, Check stability's Balance readout (src/assembly/balance.gd).
##
## The support polygon — the hull of where the model touches the floor —
## is laid on the floor, filled faintly and edged, green when the centre of
## mass is well inside it, amber when it is within half a stud of an edge
## and red when it is past one. The centre of mass is dropped onto it: a
## line from the point itself straight down to a ring on the floor, so
## whether the ring is inside the edge is the whole answer, seen, and a
## line from it to the nearest edge is the margin. Where a pose is worse
## than the model as it stands, that pose's centre is a second ring, with a
## line to it from the first, and the margin is measured from it.
##
## Drawn over the model rather than hidden under it: the polygon and the
## ring are underneath the thing they are about. Gone, with the tint on the
## joints, as soon as the model changes.
class_name BalanceMark
extends MeshInstance3D

const GOOD := Color(0.36, 0.86, 0.46)
const CLOSE := Color(1.0, 0.76, 0.22)
const TIPS := Color(0.97, 0.32, 0.26)
const WEIGHT := Color(1.0, 1.0, 1.0)
## Line widths and the ring's size, LDU.
const EDGE := 3.2
const RING := 7.0
const LIFT := 0.6

var world: BrickWorld
## The report drawn, and the world's revision when it was.
var report: Balance.Report = null
var _revision: int = -1
var _lines: ImmediateMesh


func _ready() -> void:
	_lines = ImmediateMesh.new()
	mesh = _lines
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.no_depth_test = true
	paint.render_priority = 8
	material_override = paint
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Draw [param weighed] and tint [param tints] (brick id -> Color) until the
## model next changes.
func show_report(weighed: Balance.Report, tints: Dictionary = {}) -> void:
	report = weighed
	_revision = world.revision if world != null else -1
	if world != null:
		world.set_tinted(tints)
	_draw()


## Draw one triangle nobody can see, in front of [param eye], for two
## frames, so the renderer builds this mark's material (unshaded, blended,
## over everything) before a drag first needs it. A browser drawing in
## software built it in the first drag's first frame, 203 ms of it on a
## loaded box (MECHANISMS §13). Nothing is left drawn after.
func warm(eye: Camera3D) -> void:
	if report != null or eye == null:
		return
	var ahead: Vector3 = eye.global_position - eye.global_transform.basis.z * (eye.near + 1.0)
	var across: Vector3 = eye.global_transform.basis.x * 0.01
	var up: Vector3 = eye.global_transform.basis.y * 0.01
	_lines.clear_surfaces()
	_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_triangle(ahead, ahead + across, ahead + up, Color(1.0, 1.0, 1.0, 0.0))
	_lines.surface_end()
	visible = true
	for _n: int in 2:
		await RenderingServer.frame_post_draw
	if report == null:
		_lines.clear_surfaces()
		visible = false


func clear() -> void:
	report = null
	visible = false
	if _lines != null:
		_lines.clear_surfaces()
	if world != null and not world.tinted_ids().is_empty():
		world.set_tinted({})


func _process(_delta: float) -> void:
	if report != null and world != null and world.revision != _revision:
		clear()


func colour() -> Color:
	if report == null or report.margin < 0.0:
		return TIPS
	return CLOSE if report.margin < Balance.SPARE else GOOD


func _draw() -> void:
	_lines.clear_surfaces()
	if report == null or report.empty or report.support.size() < 3:
		visible = false
		return
	var y: float = report.floor_y + LIFT
	var shade: Color = colour()
	var hull: PackedVector2Array = report.support
	_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# The polygon, faintly.
	var middle := Vector2.ZERO
	for corner: Vector2 in hull:
		middle += corner
	middle /= float(hull.size())
	var fill := Color(shade, 0.3)
	for n: int in hull.size():
		_triangle(_at(middle, y), _at(hull[n], y), _at(hull[(n + 1) % hull.size()], y), fill)
	# Its edge.
	for n: int in hull.size():
		_band(_at(hull[n], y), _at(hull[(n + 1) % hull.size()], y), EDGE, Color(shade, 0.95))
	# The weight, dropped onto it.
	var centre: Vector3 = report.rest_centre
	var foot := Vector3(centre.x, y, centre.z)
	_upright(centre, foot, Color(WEIGHT, 0.9))
	_ring(foot, RING, Color(WEIGHT, 0.95))
	_disc(foot, RING * 0.45, Color(shade, 1.0))
	_disc(centre, RING * 0.35, Color(WEIGHT, 0.95))
	# And the worst pose's, where that is not this.
	var worst := Vector3(report.centre.x, y, report.centre.z)
	if not report.worst_pose.is_empty():
		_band(foot, worst, EDGE * 0.6, Color(shade, 0.8))
		_ring(worst, RING, Color(shade, 1.0))
	# The margin itself: from the worst centre to the nearest edge.
	if report.edge_ends.size() == 2:
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(worst.x, worst.z),
			report.edge_ends[0], report.edge_ends[1])
		_band(worst, _at(on, y), EDGE * 0.5, Color(shade, 1.0))
	_lines.surface_end()
	visible = true


static func _at(point: Vector2, y: float) -> Vector3:
	return Vector3(point.x, y, point.y)


func _triangle(a: Vector3, b: Vector3, c: Vector3, paint: Color) -> void:
	for corner: Vector3 in [a, b, c]:
		_lines.surface_set_color(paint)
		_lines.surface_add_vertex(corner)


## A flat strip on the floor from [param a] to [param b].
func _band(a: Vector3, b: Vector3, wide: float, paint: Color) -> void:
	var along: Vector3 = b - a
	if along.length() < 0.001:
		return
	var side: Vector3 = along.cross(Vector3.UP).normalized() * wide * 0.5
	_triangle(a - side, a + side, b + side, paint)
	_triangle(a - side, b + side, b - side, paint)


## A line standing up, as two crossed strips so it reads from any side.
func _upright(top: Vector3, bottom: Vector3, paint: Color) -> void:
	if top.distance_to(bottom) < 0.001:
		return
	for side: Vector3 in [Vector3(EDGE * 0.4, 0, 0), Vector3(0, 0, EDGE * 0.4)]:
		_triangle(bottom - side, bottom + side, top + side, paint)
		_triangle(bottom - side, top + side, top - side, paint)


func _ring(at: Vector3, radius: float, paint: Color) -> void:
	var steps: int = 24
	for n: int in steps:
		var a: float = TAU * n / steps
		var b: float = TAU * (n + 1) / steps
		var inner: float = radius - EDGE * 0.6
		var p0 := at + Vector3(cos(a), 0, sin(a)) * radius
		var p1 := at + Vector3(cos(b), 0, sin(b)) * radius
		var q0 := at + Vector3(cos(a), 0, sin(a)) * inner
		var q1 := at + Vector3(cos(b), 0, sin(b)) * inner
		_triangle(p0, p1, q1, paint)
		_triangle(p0, q1, q0, paint)


func _disc(at: Vector3, radius: float, paint: Color) -> void:
	var steps: int = 16
	for n: int in steps:
		var a: float = TAU * n / steps
		var b: float = TAU * (n + 1) / steps
		_triangle(at, at + Vector3(cos(a), 0, sin(a)) * radius,
			at + Vector3(cos(b), 0, sin(b)) * radius, paint)
