## Measuring between two points on the model, in studs, plates and
## millimetres.
##
## How wide is the gap for a door, how tall is this wall in plates, does
## the roof clear the minifigure's head: a person building by hand asks
## these all the time and counted studs on the screen to answer them.
##
## A mode, switched on with U or the ruler on the edit bar. The first click
## sets a point, the line follows the pointer to the second, and the
## distance is said along the line and across each axis. Points snap to
## half a stud across the ground and to the lattice's two LDU up, so a
## measurement from stud to stud comes out whole. Esc or U again leaves it.
class_name Measure
extends Node3D

const LDU_MM := 0.4

var lattice: BrickLattice
var camera: Camera3D
## Where the words go, over the 3D: a Label the HUD owns.
var label: Label

var active: bool = false
var _from: Variant = null       ## Vector3, or null before the first click
var _to: Variant = null
var _fixed: bool = false
var _line: MeshInstance3D
var _mesh: ImmediateMesh
var _material: StandardMaterial3D


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _mesh
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1.0, 0.82, 0.25)
	_material.no_depth_test = true
	_material.render_priority = 10
	_line.material_override = _material
	add_child(_line)
	_line.visible = false


func toggle() -> bool:
	active = not active
	_from = null
	_to = null
	_fixed = false
	_draw()
	return active


func leave() -> void:
	if active:
		toggle()


var _pressed_at: Vector2 = Vector2.INF


## Whether a pointer event is the ruler's, handling it if so: moving aims
## the line, a left click (not a drag) sets a point. The other buttons are
## left to the camera, so the view can still be turned while measuring.
func takes(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventMouseMotion:
		aim((event as InputEventMouseMotion).position)
		return true
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button.pressed:
			_pressed_at = button.position
		elif _pressed_at.distance_to(button.position) < 6.0:
			click(button.position)
		return true
	return false


## The pointer moved: the line follows it from the first point.
func aim(at: Vector2) -> void:
	if not active or _fixed or _from == null:
		return
	var point: Variant = _point(at)
	if point != null:
		_to = point
		_draw()


## A click: the first point, the second, or a fresh start.
func click(at: Vector2) -> void:
	if not active:
		return
	var point: Variant = _point(at)
	if point == null:
		return
	if _from == null or _fixed:
		_from = point
		_to = point
		_fixed = false
	else:
		_to = point
		_fixed = true
	_draw()


## The measurement as words, for the label and for anything checking it.
func words() -> String:
	if _from == null or _to == null:
		return "Measuring: click a point, then another — Esc stops"
	var span: Vector3 = (_to as Vector3) - (_from as Vector3)
	var parts := PackedStringArray()
	if absf(span.x) > 0.01:
		parts.append("%s studs across" % _num(absf(span.x) / BrickLattice.STUD))
	if absf(span.z) > 0.01:
		parts.append("%s deep" % _num(absf(span.z) / BrickLattice.STUD))
	if absf(span.y) > 0.01:
		parts.append("%s plates up" % _num(absf(span.y) / BrickLattice.PLATE))
	if parts.is_empty():
		return "0 mm — click another point"
	return "%s mm — %s" % [_num(span.length() * LDU_MM), ", ".join(parts)]


static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.1))


## Where the pointer is on the model, snapped: half a stud across the
## ground, a cell up.
func _point(at: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(at)
	var direction: Vector3 = camera.project_ray_normal(at)
	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	var point: Vector3
	if hit.is_valid():
		point = origin + direction.normalized() * hit.distance
	else:
		var ground := Plane(Vector3.UP, 0.0)
		var landing: Variant = ground.intersects_ray(origin, direction)
		if landing == null:
			return null
		point = landing
	return Vector3(snappedf(point.x, BrickLattice.STUD * 0.5),
		snappedf(point.y, BrickLattice.CELL), snappedf(point.z, BrickLattice.STUD * 0.5))


func _draw() -> void:
	_mesh.clear_surfaces()
	_line.visible = active and _from != null
	if label != null:
		label.visible = active
		label.text = words()
	if not active or _from == null or _to == null:
		return
	var a: Vector3 = _from
	var b: Vector3 = _to
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_mesh.surface_add_vertex(a)
	_mesh.surface_add_vertex(b)
	# A tick at each end, so a point is visible before the line is.
	for end: Vector3 in [a, b]:
		_mesh.surface_add_vertex(end + Vector3(-4, 0, 0))
		_mesh.surface_add_vertex(end + Vector3(4, 0, 0))
		_mesh.surface_add_vertex(end + Vector3(0, 0, -4))
		_mesh.surface_add_vertex(end + Vector3(0, 0, 4))
	_mesh.surface_end()
