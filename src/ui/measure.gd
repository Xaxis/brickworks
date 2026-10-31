## Measuring between two points on the model, in studs, plates and
## millimetres, and between two connectors the angle between them too.
##
## How wide is the gap for a door, how tall is this wall in plates, does
## the roof clear the minifigure's head: a person building by hand asks
## these all the time and counted studs on the screen to answer them.
## Where a spring or a link goes between two pin holes, the angle between
## them as well (LDCad; docs/APP_UX2.md, 7).
##
## A mode, switched on with U or the ruler on the edit bar. The first click
## sets a point, the line follows the pointer to the second, and the
## distance is said along the line and across each axis. Points snap to
## half a stud across the ground and to the lattice's two LDU up, so a
## measurement from stud to stud comes out whole. A point near a pin, a
## hole, an axle, a bar or a hinge of the part under it goes on its middle
## instead, and with both points on one the angle between their axes is
## said to a tenth of a degree, each axis drawn through its point. It works
## in either view (View, Split), through the camera of the view clicked in.
## Esc or U again leaves it.
class_name Measure
extends Node3D

const LDU_MM := 0.4
## How near a connector's middle the pointer has to be for a point to go on
## it, px at the window's own scale.
const NEAR := 14.0
## How far each connector's axis is drawn either side of its point, LDU.
const AXIS_DRAWN := 14.0
## A connector in words.
const KINDS: Dictionary = {"pin": "pin", "axle": "axle", "pin_hole": "pin hole",
	"axle_hole": "axle hole", "shaft": "bar", "bore": "clip", "tyre": "tyre", "rim": "rim",
	"hinge": "hinge"}

var lattice: BrickLattice
var camera: CadCamera
## The parts, for the connectors of the one under the pointer.
var world: BrickWorld
var library: PartLibrary
## Where the words go, over the 3D: a Label the HUD owns.
var label: Label

var active: bool = false
var _from: Variant = null       ## Vector3, or null before the first click
var _to: Variant = null
## The connector each point is on (a placed JointSnap.End), or null.
var _from_end: JointSnap.End = null
var _to_end: JointSnap.End = null
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
	_from_end = null
	_to_end = null
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
	var point: Dictionary = _point(at)
	if not point.is_empty():
		_to = point["at"]
		_to_end = point["end"]
		_draw()


## A click: the first point, the second, or a fresh start.
func click(at: Vector2) -> void:
	if not active:
		return
	var point: Dictionary = _point(at)
	if point.is_empty():
		return
	if _from == null or _fixed:
		_from = point["at"]
		_from_end = point["end"]
		_to = _from
		_to_end = _from_end
		_fixed = false
	else:
		_to = point["at"]
		_to_end = point["end"]
		_fixed = true
	_draw()


## The measurement as words, for the label and for anything checking it.
func words() -> String:
	if _from == null or _to == null:
		return "Measuring: click a point, then another — Esc stops"
	var said: String = said_between(_from, _to)
	if said.is_empty():
		return "0 mm — click another point"
	var between: Variant = angle()
	if between != null:
		said += angle_words(between, KINDS.get(_from_end.kind, _from_end.kind),
			KINDS.get(_to_end.kind, _to_end.kind))
	return said


## From [param from] to [param to] in words, as the ruler says it: "12.8 mm
## — 1 stud across, 2 plates up"; "" for no distance. A session's measure
## says it the same (HandTools).
static func said_between(from: Vector3, to: Vector3) -> String:
	var span: Vector3 = to - from
	var parts := PackedStringArray()
	if absf(span.x) > 0.01:
		parts.append("%s studs across" % _num(absf(span.x) / BrickLattice.STUD))
	if absf(span.z) > 0.01:
		parts.append("%s deep" % _num(absf(span.z) / BrickLattice.STUD))
	if absf(span.y) > 0.01:
		parts.append("%s plates up" % _num(absf(span.y) / BrickLattice.PLATE))
	if parts.is_empty():
		return ""
	return "%s mm — %s" % [_num(span.length() * LDU_MM), ", ".join(parts)]


## " · 37.0° between the pin hole and the stud".
static func angle_words(degrees: float, one: String, other: String) -> String:
	return " · %.1f° between the %s" % [degrees, "two %ss" % one if one == other
		else "%s and the %s" % [one, other]]


## The angle between the axes of the connectors the two points are on, in
## degrees; null unless both are on one.
func angle() -> Variant:
	if _from_end == null or _to_end == null or _from == null or _to == null:
		return null
	return angle_between(_from_end.axis, _from_end.is_male(), _to_end.axis, _to_end.is_male())


## The angle between two connectors' axes, degrees. A hole, a bar or a hinge
## goes both ways, so with one of those it is the angle between the lines, 0
## to 90°; between two pins or axles, each pointing out of its part, 0 to 180°.
static func angle_between(one: Vector3, one_male: bool, other: Vector3, other_male: bool) -> float:
	var cosine: float = one.normalized().dot(other.normalized())
	if not (one_male and other_male):
		cosine = absf(cosine)
	return rad_to_deg(acos(clampf(cosine, -1.0, 1.0)))


## The points measured between, and the connectors they are on: {from, to,
## from_end, to_end}, for anything checking it.
func ends() -> Dictionary:
	return {"from": _from, "to": _to, "from_end": _from_end, "to_end": _to_end}


static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.1))


## Where the pointer is on the model: {at, end}. On a connector of the part
## under it, if one is near, its middle and the connector; else snapped,
## half a stud across the ground and a cell up, and no connector. Empty for
## nowhere.
func _point(at: Vector2) -> Dictionary:
	var origin: Vector3 = camera.ray_origin(at)
	var direction: Vector3 = camera.ray_normal(at)
	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	var point: Vector3
	if hit.is_valid():
		var end: JointSnap.End = _end_near(hit.brick_id, at)
		if end != null:
			return {"at": end.middle(), "end": end}
		point = origin + direction.normalized() * hit.distance
	else:
		var ground := Plane(Vector3.UP, 0.0)
		var landing: Variant = ground.intersects_ray(origin, direction)
		if landing == null:
			return {}
		point = landing
	return {"at": Vector3(snappedf(point.x, BrickLattice.STUD * 0.5),
		snappedf(point.y, BrickLattice.CELL), snappedf(point.z, BrickLattice.STUD * 0.5)),
		"end": null}


## The connector of [param brick_id] whose middle is nearest [param at] on
## the screen, within [constant NEAR]; null for none.
func _end_near(brick_id: int, at: Vector2) -> JointSnap.End:
	if world == null or library == null:
		return null
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return null
	var view: int = camera.view_at(at)
	var window: Window = get_window() if is_inside_tree() else null
	var best_off: float = NEAR * (window.content_scale_factor if window != null
		and window.content_scale_factor > 0.0 else 1.0)
	var best: JointSnap.End = null
	for end: JointSnap.End in JointSnap.ends_for(library, brick.part_id):
		var placed: JointSnap.End = end.placed(brick.transform, brick_id)
		var middle: Vector3 = placed.middle()
		if camera.behind(middle, view):
			continue
		var off: float = camera.screen_of(middle, view).distance_to(at)
		if off < best_off:
			best_off = off
			best = placed
	return best


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
	# Through a point on a connector, its axis: what the angle is between.
	for each: Array in [[a, _from_end], [b, _to_end]]:
		var on: JointSnap.End = each[1]
		if on != null:
			_mesh.surface_add_vertex((each[0] as Vector3) - on.axis * AXIS_DRAWN)
			_mesh.surface_add_vertex((each[0] as Vector3) + on.axis * AXIS_DRAWN)
	_mesh.surface_end()
