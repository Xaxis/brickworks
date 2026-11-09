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
##
## By finger (fingertools, APP_UX8 #10), a tap is a click: a fingertip lands
## a few points from where it is aimed, so a tap goes on the stud or the
## connector nearest it within half a fingertip, read as a mouse's click on
## its middle reads it; the ruler snapped to wherever the finger landed was
## half a stud off, or on the brick's top beside the stud. A drag still turns
## the view, and a finger held down neither takes the part off (Main's touch
## hold) nor brings up its actions.
class_name Measure
extends Node3D

const LDU_MM := 0.4
## How near a connector's middle the pointer has to be for a point to go on
## it, px at the window's own scale.
const NEAR := 14.0
## How near a stud's or a connector's middle a fingertip has to land for a
## tap to go on it, points: half what a finger is given to press.
const FINGER_REACH := Phone.TARGET * 0.5
## How far a tap may wander and still be a tap, points (as a phone's own
## tap lets it).
const FINGER_SLOP := 10.0
## A stud stands this far off the part it is on, LDU.
const STUD_TALL := 4.0
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
## A finger's touch is taken too, after the camera has seen it (it is
## Main's child), so two fingers still turn and zoom the view; its tap is
## the click the engine raises from it.
func takes(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventScreenTouch:
		return true
	if event is InputEventMouseMotion:
		# A finger has no pointer between its taps: its drag turns the view,
		# and the line stays where its last tap put it.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			aim((event as InputEventMouseMotion).position)
		return true
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		var finger: bool = button.device == InputEvent.DEVICE_ID_EMULATION
		if button.pressed:
			_pressed_at = button.position
		elif _pressed_at.distance_to(button.position) < (_points(FINGER_SLOP) if finger else 6.0):
			click(button.position, finger)
		return true
	return false


## [param points] in the window's units: a finger's sizes are in points.
func _points(points: float) -> float:
	return Phone.px(get_viewport(), points) if is_inside_tree() else points


## The pointer moved: the line follows it from the first point.
func aim(at: Vector2) -> void:
	if not active or _fixed or _from == null:
		return
	var point: Dictionary = _point(at)
	if not point.is_empty():
		_to = point["at"]
		_to_end = point["end"]
		_draw()


## A click: the first point, the second, or a fresh start. A finger's
## [param finger] tap goes on the stud or connector nearest it.
func click(at: Vector2, finger: bool = false) -> void:
	if not active:
		return
	var point: Dictionary = _finger_point(at) if finger else _point(at)
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
	# Laid out for a finger, its words: no Esc to press, and taps.
	var finger: bool = Phone.on()
	if _from == null or _to == null:
		return "Measuring: tap a point, then another" if finger \
			else "Measuring: click a point, then another — Esc stops"
	var said: String = said_between(_from, _to)
	if said.is_empty():
		return "0 mm — tap another point" if finger else "0 mm — click another point"
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


## Where a fingertip at [param at] is on the model: the stud or the connector
## nearest it on the screen within [constant FINGER_REACH], of any part under
## the fingertip and in sight there, read as a mouse's click on its middle
## reads it ([method _point]); with none, where the mouse's click at [param
## at] would be.
func _finger_point(at: Vector2) -> Dictionary:
	var reach: float = _points(FINGER_REACH)
	var view: int = camera.view_at(at)
	var best: Vector2 = at
	var best_off: float = reach
	for brick_id: int in _under_fingertip(at, reach):
		for spot: Vector2 in _spots_of(brick_id, view):
			var off: float = spot.distance_to(at)
			if off < best_off and _in_sight(spot, brick_id):
				best_off = off
				best = spot
	return _point(best)


## The parts under a fingertip [param reach] round [param at]: under its
## middle, and under eight points round each of two rings inside it.
func _under_fingertip(at: Vector2, reach: float) -> Array[int]:
	var found: Array[int] = []
	for ring: float in [0.0, 0.5, 1.0]:
		for n: int in (1 if ring == 0.0 else 8):
			var spot: Vector2 = at + Vector2.from_angle(TAU * n / 8.0) * reach * ring
			var hit: BrickLattice.Hit = lattice.raycast(camera.ray_origin(spot),
				camera.ray_normal(spot))
			if hit.is_valid() and not found.has(hit.brick_id):
				found.append(hit.brick_id)
	return found


## Where [param brick_id]'s studs' tops and its connectors' middles are on
## the screen in [param view], those in front of the eye.
func _spots_of(brick_id: int, view: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if world == null or library == null:
		return out
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return out
	var points := PackedVector3Array()
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if mesh != null:
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male" \
					and connector.axis.length_squared() > 0.5:
				points.append(brick.transform * (connector.position
					+ connector.axis.normalized() * STUD_TALL))
	for end: JointSnap.End in JointSnap.ends_for(library, brick.part_id):
		points.append(end.placed(brick.transform, brick_id).middle())
	for point: Vector3 in points:
		if not camera.behind(point, view):
			out.append(camera.screen_of(point, view))
	return out


## Whether [param brick_id] is what a click at [param spot] meets: a stud or
## a hole round the back of the part, or behind another, is not in sight.
func _in_sight(spot: Vector2, brick_id: int) -> bool:
	return lattice.raycast(camera.ray_origin(spot), camera.ray_normal(spot)).brick_id == brick_id


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
