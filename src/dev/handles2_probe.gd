## Panes, a free turn and angles (docs/APP_UX2.md, 7): the Move tool's panes
## that slide the selection on two axes at once (Mecabricks), the Rotate
## tool's outer ring that turns it about the view's axis and the trackball
## inside the rings (LeoCAD 26.09), and Measure's angle between two
## connectors (LDCad). Driven as a person drives them, presses, drags, keys
## and numbers sent as input events against the real scene, each action
## counted as handles_probe counts them. Every drag is checked for what it did
## to the model, so a handle that does nothing fails.
##
##   godot --path . --resolution 1400x900 --script src/dev/handles2_probe.gd [-- only=SECTION,…]
##
## SECTION is panes (a 2 x 4 turned 30° slid 3 studs along its own x and 2
## back along its own z by its x-z pane: the bar, 2 actions; the model's x-z
## pane; "2x -1z" typed mid-drag; one stopped by a part in the way, which
## lights up), outer (the outer ring turns it 30° about the view's axis: the
## bar, 2 actions), ball (a drag inside the rings turns it about the view's
## up by a quarter turn a radius; a click there is still the tool's turn),
## angle (Measure from a pin hole of one Technic brick to one of another
## turned 23° and tipped 31°: the angle between them to 0.1°, the bar) or
## second (View, Split on: a pane dragged in the second view). One undo takes
## back each drag. PROBE_SIZE=1280x720 runs it at the smaller window.
## Pictures go to shots/handles2/WxH/.
extends SceneTree

const EXACT_PLACE := 0.05
const EXACT_TURN := 0.002
## Up in the air, clear of the floor and whatever stands on it.
const AIR := Vector3(0, 400, 0)

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _verbs: EditVerbs
var _handles: Handles
var _acts: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_handles = _verbs.handles
	print("  window %s" % DisplayServer.window_get_size())
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	for section: String in ["panes", "outer", "ball", "angle", "second"]:
		if only.is_empty() or section in only.split(","):
			print("  -- %s" % section)
			await _rest()
			await call("_" + section)
	await _rest()
	print("")
	print("handles2: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Nothing in hand, nothing selected, the Select tool, the part axes, the
## turn step a quarter, the ruler away, one view, and the model empty.
func _rest() -> void:
	if _handles.is_dragging():
		_handles.cancel()
	if _verbs.typed.is_open():
		await _key(KEY_ESCAPE)
	var measure: Measure = _main.get("_measure")
	if measure != null and measure.active:
		measure.leave()
	var split: SplitView = _main.get("_split")
	if split != null and split.is_showing():
		split.set_on(false)
	_verbs.set_mode("select")
	_verbs.turn_step = 90.0
	_handles.frame = "part"
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(6)


# -- panes: two axes at once ---------------------------------------------------------


func _panes() -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(30.0))
	var start := Transform3D(turn, AIR)
	var brick: int = _put("3001", 4, start)
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	await _shot("before_select_tool")
	_verbs.set_mode("move")
	await _frames(4)
	_count_from()
	await _act_click(_spot_on(brick))
	# Each pane but one seen nearly edge on, which is too thin to take.
	var panes: Array = _extras("pane")
	var named: Array = panes.map(func(pane: Dictionary) -> String:
		return "".join((pane["pair"] as Array).map(func(n: int) -> String: return Handles.AXES[n])))
	_check("the Move tool's click puts its arrows and panes on it (%d arrows, panes %s)"
		% [_handles.screen_handles().size(), named], _builder.selection.has(brick)
		and _handles.screen_handles().size() == 3 and panes.size() >= 2 and "xz" in named)
	await _shot("panes_on_a_part")
	# The bar: its own x-z pane (square to its y), 3 studs along x and 2 back
	# along z, in one drag.
	var x: Vector3 = _axis_of(turn, 0)
	var z: Vector3 = _axis_of(turn, 2)
	var depth: int = _builder.history_depth()
	await _drag_pane(1, x * 60.0 - z * 40.0, true, "pane_dragged")
	var now: Transform3D = _world.get_brick(brick).transform
	var moved: Vector3 = now.origin - start.origin
	_check("its x-z pane slides it 3 studs along its own x and 2 back along its own z (%.2f, %.2f, %.2f off the plane) in %d actions (bar 2) — %s"
		% [moved.dot(x) / 20.0, moved.dot(z) / 20.0, moved.dot(_axis_of(turn, 1)), _total(), _acts],
		moved.distance_to(x * 60.0 - z * 40.0) < EXACT_PLACE and now.basis.is_equal_approx(turn)
		and _total() <= 2)
	_check("...one step to undo (%d), said as \"%s\"" % [_builder.history_depth() - depth,
		_said()], _builder.history_depth() - depth == 1 and "x +3 studs, z -2 studs" in _said())
	await _key(KEY_Z, true)
	_check("...and one undo puts it back", _near(_world.get_brick(brick).transform, start))
	# The model's x-z pane: along the model's x and z, whatever the part's turn.
	_handles.frame = "model"
	await _frames(4)
	await _drag_pane(1, Vector3(40, 0, 20), false, "")
	moved = _world.get_brick(brick).transform.origin - start.origin
	_check("the model's x-z pane slides it 2 studs along the model's x and 1 along its z (%s)"
		% moved, moved.distance_to(Vector3(40, 0, 20)) < EXACT_PLACE)
	await _key(KEY_Z, true)
	_handles.frame = "part"
	await _frames(4)
	# A number typed while dragging a pane: its two axes named.
	_count_from()
	await _drag_pane_typed(1, "2x -1z")
	moved = _world.get_brick(brick).transform.origin - start.origin
	_check("a drag of its x-z pane and \"2x -1z\" typed: 2 studs along its own x, 1 back along its own z (%s) in %d actions"
		% [moved, _total()], moved.distance_to(x * 40.0 - z * 20.0) < EXACT_PLACE
		and _total() <= 2)
	await _key(KEY_Z, true)

	# Stopped: slid on the slant into a 2 x 4 in the way.
	await _rest()
	var mover: int = _put("3001", 4, Transform3D(Basis.IDENTITY, AIR))
	var wall: int = _put("3001", 1, Transform3D(Basis.IDENTITY, AIR + Vector3(140, 0, 70)))
	await _look_at(AIR + Vector3(70, 0, 35), Vector3(0.3, 0.75, 0.6))
	_verbs.set_mode("move")
	await _click(_spot_on(mover))
	depth = _builder.history_depth()
	await _drag_pane(1, Vector3(160, 0, 80), false, "pane_stopped")
	moved = _world.get_brick(mover).transform.origin - AIR
	_check("a pane dragged 8 studs by 4 into a 2 x 4 stops at %s, short of it, and lights it (%s)"
		% [moved, _verbs.flashed], moved.length() > 1.0 and moved.x < 159.0
		and _verbs.flashed.has(wall) and _builder.history_depth() - depth == 1)


## Press on pane [param n] (named by the axis it is square to), drag it so
## the point taken goes [param by] LDU, and let go: one action.
func _drag_pane(n: int, by: Vector3, act: bool, shot: String) -> void:
	var pane: Dictionary = _extra("pane", n)
	if pane.is_empty():
		_check("its pane square to %s is on the screen" % Handles.AXES[n], false)
		return
	if act:
		_acts["drag"] = int(_acts.get("drag", 0)) + 1
	var press: Vector2 = pane["centre"]
	await _move(press)
	var pair: Array = pane["pair"]
	_check("the pointer over its %s-%s pane takes it (%s)" % [Handles.AXES[pair[0]],
		Handles.AXES[pair[1]], _handles.handle_at(press).get("kind")],
		_handles.handle_at(press).get("kind") == "pane"
		and int(_handles.handle_at(press).get("axis", -1)) == n)
	var from3: Vector3 = _on_plane(press, _handles.pivot(), pane["way"])
	var to: Vector2 = _screen(from3 + by)
	_button(press, true)
	await _frames(2)
	for s: int in range(1, 11):
		await _move(press.lerp(to, s / 10.0), true)
	await _frames(6)
	if not shot.is_empty():
		await _shot(shot)
	_button(to, false)
	await _frames(6)


## Press on pane [param n], drag it a little, type [param text] and Enter
## while the button is held, then let go: two actions (the drag, the number).
func _drag_pane_typed(n: int, text: String) -> void:
	var pane: Dictionary = _extra("pane", n)
	if pane.is_empty():
		_check("its pane square to %s is on the screen" % Handles.AXES[n], false)
		return
	_acts["drag"] = int(_acts.get("drag", 0)) + 1
	_acts["number"] = int(_acts.get("number", 0)) + 1
	var press: Vector2 = pane["centre"]
	await _move(press)
	_button(press, true)
	await _frames(2)
	for s: int in range(1, 5):
		await _move(press + Vector2(8.0, 3.0) * s, true)
	_check("...it drags (%s)" % _handles.drag.get("value"), _handles.is_dragging()
		and _handles.drag.get("kind") == "pane")
	await _type(text)
	_check("...the number opens the field over the drag (%s)" % _meaning(),
		_verbs.typed.is_open() and _handles.is_typing())
	await _shot("pane_typed")
	await _key(KEY_ENTER)
	_button(press, false)
	await _frames(6)
	_check("...Enter puts it there and the field closes", not _verbs.typed.is_open()
		and not _handles.is_dragging())


# -- the outer ring: about the view's axis -------------------------------------------


func _outer() -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(20.0)) * Basis(Vector3.RIGHT, deg_to_rad(10.0))
	var start := Transform3D(turn, AIR)
	var brick: int = _put("3001", 4, start)
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	_verbs.set_mode("rotate")
	_verbs.turn_step = 15.0
	await _frames(4)
	_count_from()
	await _act_click(_spot_on(brick))
	var outer: Dictionary = _extra("ring", Handles.VIEW_AXIS)
	_check("the Rotate tool's click puts three rings and the outer ring on it (%d, %s)"
		% [_handles.screen_handles().size(), "outer" if not outer.is_empty() else "no outer"],
		_handles.screen_handles().size() == 3 and not outer.is_empty())
	await _shot("outer_ring_on_a_part")
	if outer.is_empty():
		return
	var middle: Vector2 = outer["middle"]
	var press: Vector2 = outer["at"]
	var round: float = press.distance_to(middle)
	var from: float = (press - middle).angle()
	var toward: Vector3 = _camera.eye_basis(CadCamera.MAIN).z
	var pivot: Vector3 = _handles.pivot()
	var depth: int = _builder.history_depth()
	# The bar: dragged 32° round it, against the clock as seen, on the ring:
	# the turn step's stops, so 30°.
	_acts["drag"] = int(_acts.get("drag", 0)) + 1
	await _move(press)
	_check("the pointer over the outer ring takes it (%s %s)" % [_handles.handle_at(press).get(
		"kind"), _handles.handle_at(press).get("axis")], _handles.handle_at(press).get("kind")
		== "ring" and int(_handles.handle_at(press).get("axis", -1)) == Handles.VIEW_AXIS)
	_button(press, true)
	await _frames(2)
	for k: int in range(1, 17):
		await _move(middle + Vector2.from_angle(from - deg_to_rad(2.0 * k)) * round, true)
	await _frames(6)
	await _shot("outer_ring_dragged")
	_button(_pointer, false)
	await _frames(6)
	var now: Transform3D = _world.get_brick(brick).transform
	var want: Transform3D = _about(pivot, Basis(toward, deg_to_rad(30.0))) * start
	var turned: Quaternion = (now.basis.orthonormalized() * start.basis.inverse()) \
		.get_rotation_quaternion()
	_check("the outer ring turns it %.2f° about %s, the view's axis (%s), in %d actions (bar 2) — %s"
		% [rad_to_deg(turned.get_angle()), turned.get_axis().snappedf(0.001),
		toward.snappedf(0.001), _total(), _acts], _near(now, want) and _total() <= 2)
	_check("...one step to undo (%d), said as \"%s\"" % [_builder.history_depth() - depth,
		_said()], _builder.history_depth() - depth == 1 and "about the view's axis" in _said())
	# A number typed straight after: it takes the drag's place, about the
	# same axis.
	await _type("12.5")
	await _key(KEY_ENTER)
	now = _world.get_brick(brick).transform
	_check("\"12.5\" straight after: 12.5° about the view's axis instead, one step in all (%d)"
		% (_builder.history_depth() - depth), _near(now, _about(pivot,
		Basis(toward, deg_to_rad(12.5))) * start) and _builder.history_depth() - depth == 1)
	await _key(KEY_Z, true)
	_check("...and one undo puts it back", _near(_world.get_brick(brick).transform, start))


# -- the trackball: free --------------------------------------------------------------


func _ball() -> void:
	var start := Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), AIR)
	var brick: int = _put("3001", 4, start)
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	_verbs.set_mode("rotate")
	_verbs.turn_step = 15.0
	await _click(_spot_on(brick))
	var middle: Vector2 = _screen(_handles.pivot())
	var radius: float = _handles.call("_radius")
	var press: Vector2 = _clear_inside(middle, radius)
	await _move(press)
	_check("the pointer inside the rings, on none, takes the trackball (%s)"
		% _handles.handle_at(press).get("kind"), _handles.handle_at(press).get("kind") == "ball")
	await _shot("trackball_lit")
	var up: Vector3 = _camera.eye_basis(CadCamera.MAIN).y
	var pivot: Vector3 = _handles.pivot()
	var depth: int = _builder.history_depth()
	# Half the rings' radius to the right: an eighth of a turn about the
	# view's up.
	var to: Vector2 = press + Vector2(radius * 0.5, 0.0)
	_button(press, true)
	await _frames(2)
	for s: int in range(1, 9):
		await _move(press.lerp(to, s / 8.0), true)
	await _frames(6)
	await _shot("trackball_dragged")
	_button(to, false)
	await _frames(6)
	var now: Transform3D = _world.get_brick(brick).transform
	var turned: Quaternion = (now.basis.orthonormalized() * start.basis.inverse()) \
		.get_rotation_quaternion()
	_check("dragged half the radius right, it rolls %.2f° about %s, the view's up (%s), about its pivot"
		% [rad_to_deg(turned.get_angle()), turned.get_axis().snappedf(0.001), up.snappedf(0.001)],
		_near(now, _about(pivot, Basis(up, PI * 0.25)) * start))
	_check("...one step to undo (%d), said as \"%s\"" % [_builder.history_depth() - depth,
		_said()], _builder.history_depth() - depth == 1 and "freely" in _said())
	await _key(KEY_Z, true)
	_check("...and one undo puts it back", _near(_world.get_brick(brick).transform, start))
	# A press and let go inside the rings, on the part: the tool's own click,
	# a turn by the turn step.
	var on: Vector2 = _spot_on(brick)
	var inside: bool = on.distance_to(_screen(_handles.pivot())) < radius
	var was: Transform3D = _world.get_brick(brick).transform
	await _click(on)
	var step: float = rad_to_deg(Quaternion(was.basis.orthonormalized()).angle_to(
		Quaternion(_world.get_brick(brick).transform.basis.orthonormalized())))
	_check("a click on the part inside the rings (%s) is still the tool's: turned %.1f° (the turn step, 15°)"
		% [inside, step], inside and absf(step - 15.0) < 0.05)


## A point inside the rings, on none of them and away from the middle, where
## the trackball is taken.
func _clear_inside(middle: Vector2, radius: float) -> Vector2:
	var view: Rect2 = ((_main.call("model_cover") as Dictionary)["view"] as Rect2).grow(-8.0)
	var best := middle
	var best_room: float = -1.0
	for r: float in [0.35, 0.5, 0.65]:
		for k: int in 16:
			var at: Vector2 = middle + Vector2.from_angle(TAU * k / 16.0) * radius * r
			if not view.has_point(at):
				continue
			var room: float = INF
			for handle: Dictionary in _handles.screen_handles():
				var points: PackedVector2Array = handle["points"]
				for m: int in points.size() - 1:
					room = minf(room, Geometry2D.get_closest_point_to_segment(at, points[m],
						points[m + 1]).distance_to(at))
			if room > best_room:
				best_room = room
				best = at
	return best


# -- Measure: the angle between two pin holes ------------------------------------------


func _angle() -> void:
	var measure: Measure = _main.get("_measure")
	var one_at := Transform3D(Basis.IDENTITY, AIR)
	var other_turn := Basis(Vector3.UP, deg_to_rad(23.0)) * Basis(Vector3.RIGHT, deg_to_rad(31.0))
	var other_at := Transform3D(other_turn, AIR + Vector3(0, 10, 90))
	var one: int = _put("3701", 4, one_at)
	var other: int = _put("3701", 1, other_at)
	await _look_at(AIR + Vector3(0, 0, 45), Vector3(0.75, 0.45, 0.35))
	await _key(KEY_U)
	_check("U takes the ruler out", measure.active)
	var holes: Array = JointSnap.ends_of(_library.mesh_for("3701")).filter(
		func(end: JointSnap.End) -> bool: return end.kind == "pin_hole")
	holes.sort_custom(func(a: JointSnap.End, b: JointSnap.End) -> bool: return a.at.x < b.at.x)
	var hole: JointSnap.End = holes[holes.size() / 2]
	var first: JointSnap.End = hole.placed(one_at, one)
	var second: JointSnap.End = hole.placed(other_at, other)
	var want: float = rad_to_deg(acos(clampf(absf(first.axis.dot(second.axis)), 0.0, 1.0)))
	await _click(_near_on(first.middle(), one))
	await _click(_near_on(second.middle(), other))
	var ends: Dictionary = measure.ends()
	var from_end: JointSnap.End = ends["from_end"]
	var to_end: JointSnap.End = ends["to_end"]
	_check("a click by each brick's middle hole puts the points on those holes (%s, %s)"
		% [from_end.kind if from_end != null else "none", to_end.kind if to_end != null else "none"],
		from_end != null and to_end != null and from_end.kind == "pin_hole"
		and to_end.kind == "pin_hole" and from_end.brick == one and to_end.brick == other
		and from_end.at.distance_to(first.at) < 0.01 and to_end.at.distance_to(second.at) < 0.01)
	var said: String = measure.label.text
	var shown: String = "%.1f°" % want
	_check("Measure says the angle between the two pin holes, %s, to 0.1° (bar): \"%s\""
		% [shown, said], measure.label.visible and shown in said and "pin hole" in said
		and measure.angle() != null and absf(float(measure.angle()) - want) < 0.05)
	_check("...and the distance between their middles (%.2f mm)"
		% (first.at.distance_to(second.at) * Measure.LDU_MM), ("%s mm" % Measure._num(
		first.at.distance_to(second.at) * Measure.LDU_MM)) in said)
	await _shot("measure_angle")
	# A point on a face, away from any connector, says no angle.
	var bounds: AABB = _library.mesh_for("3701").bounds
	var top: Vector3 = one_at * Vector3(bounds.get_center().x - bounds.size.x * 0.4, bounds.end.y,
		bounds.get_center().z)
	await _click(_near_on(top, one))
	var plain: Variant = measure.ends()["from_end"]
	await _click(_near_on(second.middle(), other))
	_check("from a point on the brick's top to a hole: a distance and no angle (\"%s\")"
		% measure.label.text, plain == null and measure.angle() == null
		and not "°" in measure.label.text and "mm" in measure.label.text)
	await _key(KEY_ESCAPE)
	_check("Esc puts the ruler away", not measure.active)


## A point on the screen near where [param point] is drawn where the brick
## [param brick] is under the pointer, so the ray meets it there.
func _near_on(point: Vector3, brick: int) -> Vector2:
	var at: Vector2 = _screen(point)
	for r: int in range(0, 12):
		for d: Vector2 in [Vector2(0, r), Vector2(r, 0), Vector2(-r, 0), Vector2(0, -r),
				Vector2(r, r), Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r)]:
			if _verbs.brick_at(at + d) == brick:
				return at + d
	return at


# -- in the second view ---------------------------------------------------------------


func _second() -> void:
	var split: SplitView = _main.get("_split")
	if split == null or not split.fits():
		print("  (the window has no room for two views: nothing to check)")
		return
	var start := Transform3D(Basis.IDENTITY, AIR)
	var brick: int = _put("3001", 4, start)
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	split.set_on(true)
	split.show_side("top")
	await _frames(30)
	split.call("fit")
	await _frames(20)
	_verbs.set_mode("move")
	await _click(split.on_screen(AIR))
	var pane: Dictionary = {}
	for each: Dictionary in _handles.screen_extras(CadCamera.SECOND):
		if each["kind"] == "pane" and int(each["axis"]) == 1:
			pane = each
	_check("from the top, the second view draws the x-z pane face on", _builder.selection.has(brick)
		and not pane.is_empty())
	if pane.is_empty():
		return
	var press: Vector2 = _centre(pane["points"])
	var to: Vector2 = split.on_screen(_on_plane_second(split, press) + Vector3(60, 0, 40))
	var depth: int = _builder.history_depth()
	var main_was: Transform3D = _camera.global_transform
	await _move(press)
	_button(press, true)
	await _frames(2)
	for s: int in range(1, 11):
		await _move(press.lerp(to, s / 10.0), true)
	await _frames(6)
	await _shot("second_pane_dragged")
	_button(to, false)
	await _frames(6)
	var moved: Vector3 = _world.get_brick(brick).transform.origin - start.origin
	_check("a pane dragged in the second view slides it 3 studs along x and 2 along z (%s), one step (%d), the main view unmoved"
		% [moved, _builder.history_depth() - depth], moved.distance_to(Vector3(60, 0, 40))
		< EXACT_PLACE and _builder.history_depth() - depth == 1
		and _camera.global_transform.is_equal_approx(main_was))
	split.set_on(false)
	await _frames(6)


func _on_plane_second(split: SplitView, at: Vector2) -> Vector3:
	var ray: Array = split.ray_through(at)
	var plane := Plane(Vector3.UP, _handles.pivot())
	var hit: Variant = plane.intersects_ray(ray[0], ray[1])
	return hit if hit != null else _handles.pivot()


# -- helpers ----------------------------------------------------------------------


## A part put down as a file puts it, wherever it is: its id.
func _put(part: String, colour: int, at: Transform3D) -> int:
	var brick: int = _world.add_brick(part, colour, at)
	_builder.register(brick, part, at)
	return brick


func _look_at(at: Vector3, from: Vector3) -> void:
	_camera.frame(AABB(at - Vector3(90, 90, 90), Vector3(180, 180, 180)), 1.2)
	_camera.look_from(from.normalized())
	await _frames(40)


static func _axis_of(basis: Basis, n: int) -> Vector3:
	return ([basis.x, basis.y, basis.z][n] as Vector3).normalized()


static func _about(point: Vector3, turn: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, point) * Transform3D(turn, Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -point)


static func _near(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_to(b.origin) > EXACT_PLACE:
		return false
	for n: int in 3:
		if (a.basis[n] - b.basis[n]).length() > EXACT_TURN:
			return false
	return true


static func _centre(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point: Vector2 in points:
		sum += point
	return sum / maxf(points.size(), 1.0)


## The outer ring or the panes drawn now in the main view.
func _extras(kind: String) -> Array:
	return _handles.screen_extras().filter(func(handle: Dictionary) -> bool:
		return handle["kind"] == kind)


## The outer ring or a pane, and where to take it: a pane by its middle, the
## ring on a point over the model's view, furthest from the other rings.
func _extra(kind: String, n: int) -> Dictionary:
	var mine: Dictionary = {}
	for handle: Dictionary in _extras(kind):
		if int(handle["axis"]) == n:
			mine = handle.duplicate()
	if mine.is_empty():
		return {}
	var points: PackedVector2Array = mine["points"]
	if kind == "pane":
		mine["centre"] = _centre(points)
		return mine
	var view: Rect2 = ((_main.call("model_cover") as Dictionary)["view"] as Rect2).grow(-8.0)
	var best_room: float = -1.0
	for k: int in points.size() - 1:
		if not view.has_point(points[k]):
			continue
		var room: float = INF
		for other: Dictionary in _handles.screen_handles():
			var theirs: PackedVector2Array = other["points"]
			for m: int in theirs.size() - 1:
				room = minf(room, Geometry2D.get_closest_point_to_segment(points[k], theirs[m],
					theirs[m + 1]).distance_to(points[k]))
		var tag: Rect2 = _handles.call("_tag_box")
		if tag.grow(6.0).has_point(points[k]):
			continue
		if room > best_room:
			best_room = room
			mine["at"] = points[k]
	return mine if mine.has("at") else {}


## Where the ray through [param at] meets the plane through [param point]
## square to [param normal].
func _on_plane(at: Vector2, point: Vector3, normal: Vector3) -> Vector3:
	var hit: Variant = Plane(normal, point).intersects_ray(_camera.ray_origin(at),
		_camera.ray_normal(at))
	return hit if hit != null else point


## A point on the screen where this part is the one under the pointer and
## no ring, arrow or pane is.
func _spot_on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var middle: Vector2 = _screen(brick.transform * mesh.bounds.get_center())
	for r: int in range(0, 80, 3):
		for d: Vector2 in [Vector2(0, r), Vector2(r, 0), Vector2(-r, 0), Vector2(0, -r),
				Vector2(r, r), Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r)]:
			var over: Dictionary = _handles.handle_at(middle + d)
			if _verbs.brick_at(middle + d) == brick_id and (over.is_empty()
					or over.get("kind") == "ball"):
				return middle + d
	return middle


## What the last step to undo did, in the history's words.
func _said() -> String:
	var words: PackedStringArray = _builder.history_words(1)
	return words[0] if not words.is_empty() else ""


func _count_from() -> void:
	_acts = {"point": 0, "click": 0, "key": 0, "drag": 0, "number": 0}


func _total() -> int:
	var total: int = 0
	for kind: String in _acts:
		total += int(_acts[kind])
	return total


func _meaning() -> String:
	var label: Label = _verbs.typed.find_child("Meaning", true, false)
	return label.text if label != null else ""


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


var _pointer := Vector2.ZERO


func _move(at: Vector2, held: bool = false) -> void:
	_pointer = at
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool, alt: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.alt_pressed = alt
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2, alt: bool = false) -> void:
	await _move(at)
	_button(at, true, alt)
	await _frames(2)
	_button(at, false, alt)
	await _frames(4)


func _act_click(at: Vector2) -> void:
	_acts["click"] = int(_acts["click"]) + 1
	await _click(at)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		var code: Key = {"-": KEY_MINUS, ".": KEY_PERIOD, "/": KEY_SLASH, " ": KEY_SPACE,
			"+": KEY_PLUS, "*": KEY_ASTERISK}.get(c, OS.find_keycode_from_string(c.to_upper()))
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("res://shots/handles2/%dx%d/%s.png" % [
		size.x, size.y, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)
