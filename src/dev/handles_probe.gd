## Handles on the selection (docs/APP_UX.md, B3): rings that turn it about
## an axis and arrows that slide it along one, driven as a person drives
## them: presses, drags, keys and numbers sent as input events against the
## real scene, each action counted as the walk counts them (a click, a drag,
## a key, a number typed, each one). Every drag is checked for what it did to
## the model, so a handle that does nothing fails.
##
##   godot --path . --resolution 1400x900 --script src/dev/handles_probe.gd [-- only=SECTION,…]
##
## SECTION is rings (a part turned about each of its own three axes to any
## angle in 3 actions, and a 1 x 16 on an axle through a brick turned 30°
## and tilted 25°, turned about its joint), arrows (slid along each of its
## own axes, a number typed for one), axes (the tag's part, model and view
## axes, each ring and arrow taking its axis), pivot (Alt-click picks the
## point it turns about, Alt-click on nothing goes back), snaps (quarter
## turns near the middle, the turn step on the ring, 5° past it and 1°
## further out), typed (a number straight after a drag takes its place) or
## stopped (a ring and an arrow dragged into a part stop where there is room,
## and light it up). One undo takes back each drag. PROBE_SIZE=1280x720 runs
## it at the smaller window. Pictures go to shots/handles/WxH/.
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
var _store: ModelStore
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
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_handles = _verbs.handles
	print("  window %s" % DisplayServer.window_get_size())
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	for section: String in ["rings", "arrows", "axes", "pivot", "snaps", "typed", "stopped"]:
		if only.is_empty() or section in only.split(","):
			print("  -- %s" % section)
			await _rest()
			await call("_" + section)
	await _rest()
	print("")
	print("handles: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Nothing in hand, nothing selected, the Select tool, the part axes, the
## turn step a quarter, and the model empty.
func _rest() -> void:
	if _handles.is_dragging():
		_handles.cancel()
	if _verbs.typed.is_open():
		await _key(KEY_ESCAPE)
	_verbs.set_mode("select")
	_verbs.turn_step = 90.0
	_handles.frame = "part"
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(6)


# -- rings: any part about any of its axes, to any angle, in three actions --------


func _rings() -> void:
	# A 2 x 4 off the grid, turned 20° and tipped 10°: its own axes are
	# none of the model's.
	var turn := Basis(Vector3.UP, deg_to_rad(20.0)) * Basis(Vector3.RIGHT, deg_to_rad(10.0))
	var brick: int = _put("3001", 4, Transform3D(turn, AIR))
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	await _shot("before_select_tool")
	_verbs.set_mode("rotate")
	await _frames(4)
	_check("the Rotate tool with nothing selected draws no rings", _drawn() == 0)
	for n: int in 3:
		var angle: float = [23.58, -41.2, 67.5][n]
		var was: Transform3D = _world.get_brick(brick).transform
		_count_from()
		if n == 0:
			await _act_click(_spot_on(brick))
			_check("a click on the part picks it out and puts its rings on it (%d drawn, about its %s)"
				% [_drawn(), _handles.pivot_is()], _builder.selection.has(brick) and _drawn() == 3
				and _world.get_brick(brick).transform.is_equal_approx(was))
			await _shot("rings_on_a_part")
		else:
			# The part is still picked out: a click on it again would turn
			# it, so it counts as the click that picks it.
			_acts["click"] = int(_acts["click"]) + 1
		var axis: Vector3 = _axis_of(_world.get_brick(brick).transform.basis, n)
		var middle: Vector3 = _handles.pivot()
		var depth: int = _builder.history_depth()
		await _act_drag_typed("ring", n, "%s" % angle, n == 0)
		var now: Transform3D = _world.get_brick(brick).transform
		var want: Transform3D = _about(middle, Basis(axis, deg_to_rad(angle))) * was
		_check("about its own %s by %+.2f° in %d actions (bar 3) — %s" % [Handles.AXES[n], angle,
			_total(), _acts], _near(now, want) and _total() <= 3)
		_check("...one step to undo (%d)" % (_builder.history_depth() - depth),
			_builder.history_depth() - depth == 1)
	await _shot("rings_after_three_turns")
	var turned: Transform3D = _world.get_brick(brick).transform
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	_check("three undos put it back as it was",
		_near(_world.get_brick(brick).transform, Transform3D(turn, AIR))
		and not _near(turned, Transform3D(turn, AIR)))

	# On a parent turned 30° and tilted 25°: a 1 x 16 on the axle through
	# it, turned about its own axis along the axle, round the joint.
	await _rest()
	var parent_turn := Basis(Vector3.UP, deg_to_rad(30.0)) * Basis(Vector3.RIGHT, deg_to_rad(25.0))
	var parent_at := Transform3D(parent_turn, AIR)
	_put("3701", 4, parent_at)
	var holes: Array = JointSnap.ends_of(_library.mesh_for("3701")).filter(
		func(end: JointSnap.End) -> bool: return end.kind == "pin_hole")
	holes.sort_custom(func(a: JointSnap.End, b: JointSnap.End) -> bool: return a.at.x < b.at.x)
	var hole: JointSnap.End = (holes[holes.size() / 2] as JointSnap.End).placed(parent_at, 0)
	var axle_end: JointSnap.End = JointSnap.ends_of(_library.mesh_for("3706"))[0]
	var axle_at: Transform3D = JointSnap.pose(axle_end, hole, 1, 0.0, 0.0, Basis.IDENTITY)
	_put("3706", 0, axle_at)
	var site: JointSnap.End = null
	for end: JointSnap.End in JointSnap.ends_of(_library.mesh_for("3706")):
		var placed: JointSnap.End = end.placed(axle_at, 0)
		if site == null or placed.at.distance_to(hole.at) > site.at.distance_to(hole.at):
			site = placed
	var child_at: Variant = _on_the_axle(site, parent_turn)
	_check("a 1 x 16 has room on the axle by a hole", child_at != null)
	if child_at == null:
		return
	var child: int = _put("3703", 1, child_at)
	_camera.frame(AABB(AIR - Vector3(120, 120, 120), Vector3(240, 240, 240)), 1.3)
	_camera.look_from((site.axis + Vector3(0.3, 0.5, 0.2)).normalized())
	await _frames(40)
	_verbs.set_mode("rotate")
	_count_from()
	await _act_click(_spot_on(child))
	var joint_axis: int = -1
	for n: int in 3:
		if absf(_axis_of(_world.get_brick(child).transform.basis, n).dot(site.axis)) > 0.999:
			joint_axis = n
	_check("its rings stand on the joint it hangs from (%s), one of them along the axle (%s)" % [
		_handles.pivot_is(), Handles.AXES[joint_axis] if joint_axis >= 0 else "none"],
		_handles.pivot_is() == "joint" and joint_axis >= 0
		and _off_line(_handles.pivot(), site) < 0.05)
	await _shot("rings_on_a_turned_parent")
	if joint_axis < 0:
		return
	var was: Transform3D = _world.get_brick(child).transform
	var hole_on: Vector3 = was * (_hole_of_3703(child_at) as Vector3)
	await _act_drag_typed("ring", joint_axis, "23.58", true)
	var now: Transform3D = _world.get_brick(child).transform
	var degrees: float = rad_to_deg(Quaternion(was.basis.orthonormalized()).angle_to(
		Quaternion(now.basis.orthonormalized())))
	var hole_now: Vector3 = now * (was.affine_inverse() * hole_on)
	_check("turned %.2f° about the axle in %d actions, its hole still on it (%.3f off)" % [
		degrees, _total(), _off_line(hole_now, site)], absf(degrees - 23.58) < 0.01
		and _off_line(hole_now, site) < 0.05 and _total() <= 3)
	await _shot("turned_on_a_turned_parent")


## Where a 1 x 16 goes by a hole onto the axle's end at [param site], with
## room; null where none of its holes, either way on, has any.
func _on_the_axle(site: JointSnap.End, basis: Basis) -> Variant:
	var ends: Array = JointSnap.ends_of(_library.mesh_for("3703"))
	for end: JointSnap.End in ends:
		if end.kind != "pin_hole":
			continue
		for side: int in [1, -1]:
			for slide: float in [0.0, 10.0, -10.0]:
				var at: Transform3D = JointSnap.pose(end, site, side, slide, 0.0, basis)
				if _builder.room_for("3703", at, false):
					_hole_index = ends.find(end)
					return at
	return null


var _hole_index: int = -1


## The middle of the 1 x 16's hole that went on the axle, in its own frame.
func _hole_of_3703(_at: Variant) -> Variant:
	var ends: Array = JointSnap.ends_of(_library.mesh_for("3703"))
	return (ends[_hole_index] as JointSnap.End).at if _hole_index >= 0 else Vector3.ZERO


# -- arrows ------------------------------------------------------------------------


func _arrows() -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(30.0))
	var brick: int = _put("3001", 4, Transform3D(turn, AIR))
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	_verbs.set_mode("move")
	await _act_click(_spot_on(brick))
	_check("the Move tool's click puts arrows on it (%d)" % _drawn(), _drawn() == 3)
	await _shot("arrows_on_a_part")
	for n: int in 3:
		var was: Transform3D = _world.get_brick(brick).transform
		var axis: Vector3 = _axis_of(was.basis, n)
		var depth: int = _builder.history_depth()
		var handle: Dictionary = _handle("arrow", n)
		if handle.is_empty():
			_check("its %s arrow is on the screen" % Handles.AXES[n], false)
			continue
		await _drag_along(handle, 2.2, true)
		var now: Transform3D = _world.get_brick(brick).transform
		var moved: Vector3 = now.origin - was.origin
		var along: float = moved.dot(axis)
		_check("its %s arrow slides it along its own %s by %.1f LDU, on the snap (%.2f off the line)"
			% [Handles.AXES[n], Handles.AXES[n], along, (moved - axis * along).length()],
			absf(along) >= 7.9 and (moved - axis * along).length() < 0.01
			and now.basis.is_equal_approx(was.basis)
			and absf(along / 4.0 - roundf(along / 4.0)) < 0.001)
		_check("...one step to undo", _builder.history_depth() - depth == 1)
	await _shot("arrows_after")
	# A number typed while dragging: 3 studs along x, the part in sight again.
	var was: Transform3D = _world.get_brick(brick).transform
	await _look_at(was.origin, Vector3(0.55, 0.5, 0.67))
	_count_from()
	await _act_drag_typed("arrow", 0, "3", false)
	var moved: Vector3 = _world.get_brick(brick).transform.origin - was.origin
	_check("a drag of its x arrow and 3 typed: 3 studs along its own x (%s) in %d actions"
		% [moved, _total()], moved.is_equal_approx(_axis_of(was.basis, 0) * 60.0) and _total() <= 2)
	# Esc mid-drag: nothing changes.
	was = _world.get_brick(brick).transform
	var depth: int = _builder.history_depth()
	var handle: Dictionary = _handle("arrow", 2)
	var press: Vector2 = handle["at"]
	await _move(press)
	_button(press, true)
	await _frames(2)
	for k: int in range(1, 6):
		await _move(press + (handle["dir"] as Vector2) * 20.0 * k, true)
	var drawn_moved: bool = not _world.drawn_ids().is_empty()
	await _key(KEY_ESCAPE)
	_button(press, false)
	await _frames(4)
	_check("Esc while dragging (the part drawn moved: %s) leaves it as it was, nothing to undo"
		% drawn_moved, drawn_moved and _world.get_brick(brick).transform.is_equal_approx(was)
		and _builder.history_depth() == depth and _world.drawn_ids().is_empty())


# -- the part's, the model's and the view's axes ---------------------------------------


func _axes() -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(20.0)) * Basis(Vector3.RIGHT, deg_to_rad(15.0))
	var brick: int = _put("3001", 4, Transform3D(turn, AIR))
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	_verbs.set_mode("rotate")
	await _click(_spot_on(brick))
	var was: Transform3D = _world.get_brick(brick).transform
	var tag: Rect2 = _handles.call("_tag_box")
	_check("the tag beside the rings says whose axes (%s)" % _handles.frame,
		_handles.frame == "part" and tag.has_area())
	var seen: Array = []
	for _n: int in 3:
		await _click(_handles.call("_tag_box").get_center())
		seen.append(_handles.frame)
	_check("a click on it goes to the model's, the view's and back to the part's (%s), the part as it was"
		% ", ".join(seen), seen == ["model", "view", "part"]
		and _world.get_brick(brick).transform.is_equal_approx(was)
		and _builder.selection.has(brick))
	for frame: String in ["model", "view"]:
		_handles.frame = frame
		await _frames(4)
		if frame == "view":
			await _shot("rings_on_the_view")
		for n: int in 3:
			was = _world.get_brick(brick).transform
			var basis: Basis = Basis.IDENTITY if frame == "model" \
				else _camera.global_transform.basis.orthonormalized()
			var axis: Vector3 = _axis_of(basis, n)
			var middle: Vector3 = _handles.pivot()
			await _act_drag_typed("ring", n, "30", false)
			var want: Transform3D = _about(middle, Basis(axis, deg_to_rad(30.0))) * was
			_check("the %s's %s ring turns it 30° about the %s's %s" % [frame, Handles.AXES[n],
				frame, Handles.AXES[n]], _near(_world.get_brick(brick).transform, want))
	_verbs.set_mode("move")
	await _frames(4)
	for frame: String in ["model", "view"]:
		_handles.frame = frame
		await _frames(4)
		var basis: Basis = Basis.IDENTITY if frame == "model" \
			else _camera.global_transform.basis.orthonormalized()
		if frame == "view":
			_check("the view's arrows: across and up, none at the eye (%d drawn)" % _drawn(),
				_drawn() == 2 and _handle("arrow", 2).is_empty())
			await _shot("arrows_on_the_view")
		for n: int in (3 if frame == "model" else 2):
			was = _world.get_brick(brick).transform
			await _act_drag_typed("arrow", n, "2", false)
			var moved: Vector3 = _world.get_brick(brick).transform.origin - was.origin
			_check("the %s's %s arrow slides it 2 studs along the %s's %s (%s)" % [frame,
				Handles.AXES[n], frame, Handles.AXES[n], moved],
				moved.distance_to(_axis_of(basis, n) * 40.0) < 0.01)


# -- the point it turns about -----------------------------------------------------------


func _pivot() -> void:
	var brick: int = _put("3001", 4, Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), AIR))
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	_verbs.set_mode("rotate")
	await _click(_spot_on(brick))
	var was_pivot: Vector3 = _handles.pivot()
	_check("on a part off the grid with nothing under it, the rings stand at its middle (%s)"
		% _handles.pivot_is(), _handles.pivot_is() == "middle")
	# Alt-click near its end.
	var mesh: Lbm.PartMesh = _library.mesh_for("3001")
	var was: Transform3D = _world.get_brick(brick).transform
	var end_at: Vector2 = _screen(was * (mesh.bounds.get_center()
		+ Vector3(mesh.bounds.size.x * 0.4, 0, 0)))
	var spot: Vector2 = end_at
	for r: int in range(0, 40, 2):
		if _verbs.brick_at(end_at + Vector2(r, 0)) == brick:
			spot = end_at + Vector2(r, 0)
			break
		if _verbs.brick_at(end_at - Vector2(r, 0)) == brick:
			spot = end_at - Vector2(r, 0)
			break
	await _click(spot, true)
	var picked: Vector3 = _handles.pivot()
	_check("Alt-click on its end picks the point it turns about (%s, %.1f LDU from its middle)"
		% [_handles.pivot_is(), picked.distance_to(was_pivot)], _handles.pivot_is() == "picked"
		and picked.distance_to(was_pivot) > 20.0 and _builder.selection.has(brick)
		and not _builder.is_carrying() and _verbs.mode == "rotate")
	await _shot("pivot_picked")
	await _act_drag_typed("ring", 1, "45", false)
	var now: Transform3D = _world.get_brick(brick).transform
	var stays: Vector3 = now * (was.affine_inverse() * picked)
	_check("a ring turns it 45° about that point (it stays %.3f LDU from where it was)"
		% stays.distance_to(picked), stays.distance_to(picked) < 0.05
		and not _near(now, was))
	# Alt-click on nothing: back to its middle.
	var view: Rect2 = (_main.call("model_cover") as Dictionary)["view"]
	await _click(view.position + Vector2(view.size.x * 0.5, 24.0), true)
	_check("Alt-click on nothing: about its middle again (%s)" % _handles.pivot_is(),
		_handles.pivot_is() == "middle")


# -- finer towards the rim -------------------------------------------------------


func _snaps() -> void:
	var brick: int = _put("3001", 4, Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), AIR))
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	_verbs.set_mode("rotate")
	_verbs.turn_step = 15.0
	await _click(_spot_on(brick))
	# The view's z ring faces the eye: round on the screen, so the pointer's
	# distance from the middle is the same all the way round.
	_handles.frame = "view"
	await _frames(4)
	var handle: Dictionary = _handle("ring", 2)
	var middle: Vector2 = handle["middle"]
	var radius: float = _handles.call("_radius")
	var from: float = ((handle["at"] as Vector2) - middle).angle()
	# [how far out, as the radius, degrees swept, what it snaps to, the step]
	for zone: Array in [[0.4, 60.0, 90.0, 90.0], [1.0, 40.0, 45.0, 15.0], [1.65, 37.0, 35.0, 5.0],
			[2.4, 37.0, 37.0, 1.0]]:
		var was: Transform3D = _world.get_brick(brick).transform
		var depth: int = _builder.history_depth()
		var press: Vector2 = handle["at"]
		await _move(press)
		_button(press, true)
		await _frames(2)
		var out: float = zone[0]
		for k: int in range(1, 5):
			await _move(middle + Vector2.from_angle(from) * radius * lerpf(1.0, out, k / 4.0), true)
		var sweep: float = zone[1]
		for k: int in range(1, roundi(sweep / 2.0) + 1):
			await _move(middle + Vector2.from_angle(from + deg_to_rad(minf(k * 2.0, sweep)))
				* radius * out, true)
		await _frames(6)
		if is_equal_approx(out, 2.4):
			await _shot("ring_dragged_finest")
		_button(press, false)
		await _frames(6)
		var now: Transform3D = _world.get_brick(brick).transform
		var turned: float = rad_to_deg(Quaternion(was.basis.orthonormalized()).angle_to(
			Quaternion(now.basis.orthonormalized())))
		_check("swept %.0f° with the pointer at %.2f of the ring's radius: turned %.2f° (%s° stops)"
			% [sweep, out, turned, zone[3]], absf(turned - float(zone[2])) < 0.05
			and _builder.history_depth() - depth == 1)
		await _key(KEY_Z, true)
		handle = _handle("ring", 2)
		middle = handle["middle"]
		from = ((handle["at"] as Vector2) - middle).angle()


# -- a number straight after the drag ----------------------------------------------------


func _typed() -> void:
	var start := Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), AIR)
	var brick: int = _put("3001", 4, start)
	await _look_at(AIR, Vector3(0.55, 0.5, 0.67))
	_verbs.set_mode("rotate")
	await _click(_spot_on(brick))
	var axis: Vector3 = _axis_of(start.basis, 1)
	var middle: Vector3 = _handles.pivot()
	var depth: int = _builder.history_depth()
	_count_from()
	await _drag_along(_handle("ring", 1), 4.5, true)
	var dragged: Transform3D = _world.get_brick(brick).transform
	var quarter: float = rad_to_deg(Quaternion(start.basis).angle_to(
		Quaternion(dragged.basis.orthonormalized())))
	_check("a drag of its y ring a quarter round turns it %.1f°" % quarter,
		absf(quarter - 90.0) < 0.05)
	await _type("30")
	_acts["number"] = int(_acts["number"]) + 1
	_check("a number straight after opens the field (%s)" % _meaning(), _verbs.typed.is_open()
		and _handles.is_typing())
	await _key(KEY_ENTER)
	var now: Transform3D = _world.get_brick(brick).transform
	_check("...and Enter turns it 30° instead, about its y, in %d actions — %s" % [_total(), _acts],
		_near(now, _about(middle, Basis(axis, deg_to_rad(30.0))) * start) and _total() <= 2)
	_check("...one step to undo in all (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() - depth == 1)
	# Esc in the field leaves the drag as it was let go.
	await _drag_along(_handle("ring", 1), 4.5, false)
	var let_go: Transform3D = _world.get_brick(brick).transform
	await _type("12")
	await _key(KEY_ESCAPE)
	_check("a number then Esc: the drag as it was let go",
		_near(_world.get_brick(brick).transform, let_go) and not _near(let_go, now)
		and _builder.history_depth() - depth == 2)
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	_check("two undos: back where it began", _near(_world.get_brick(brick).transform, start))


# -- a part in the way ------------------------------------------------------------------


func _stopped() -> void:
	# A 1 x 4 between two 1 x 1s: turned, an end meets one of them.
	var bar: int = _put("3010", 4, Transform3D(Basis.IDENTITY, AIR))
	var near: int = _put("3005", 1, Transform3D(Basis.IDENTITY, AIR + Vector3(30, 0, 40)))
	var far: int = _put("3005", 1, Transform3D(Basis.IDENTITY, AIR + Vector3(30, 0, -40)))
	await _look_at(AIR, Vector3(0.2, 0.9, 0.35))
	_verbs.set_mode("rotate")
	_verbs.turn_step = 15.0
	await _click(_spot_on(bar))
	var was: Transform3D = _world.get_brick(bar).transform
	var depth: int = _builder.history_depth()
	await _drag_along(_handle("ring", 1), 4.5, false)
	var now: Transform3D = _world.get_brick(bar).transform
	var turned: float = rad_to_deg(Quaternion(was.basis).angle_to(
		Quaternion(now.basis.orthonormalized())))
	_check("a ring dragged a quarter round stops at %.0f°, where an end meets a 1 x 1, and lights it (%s)"
		% [turned, _verbs.flashed], turned > 1.0 and turned < 89.0
		and (_verbs.flashed.has(near) or _verbs.flashed.has(far))
		and _builder.history_depth() - depth == 1)
	await _shot("ring_stopped")
	await _key(KEY_Z, true)
	_check("...one undo puts it back", _near(_world.get_brick(bar).transform, was))
	# An arrow: slid along x into a 2 x 4 six studs off.
	await _rest()
	var mover: int = _put("3001", 4, Transform3D(Basis.IDENTITY, AIR))
	var wall: int = _put("3001", 1, Transform3D(Basis.IDENTITY, AIR + Vector3(200, 0, 0)))
	await _look_at(AIR + Vector3(100, 0, 0), Vector3(0.3, 0.6, 0.75))
	_verbs.set_mode("move")
	await _click(_spot_on(mover))
	var handle: Dictionary = _handle("arrow", 0)
	var press: Vector2 = handle["at"]
	depth = _builder.history_depth()
	await _move(press)
	_button(press, true)
	await _frames(2)
	var target: Vector2 = _screen(AIR + Vector3(320, 0, 0))
	for k: int in range(1, 13):
		await _move(press.lerp(target + (press - _screen(AIR)), k / 12.0), true)
	await _frames(6)
	await _shot("arrow_stopped")
	_button(press, false)
	await _frames(6)
	var slid: float = _world.get_brick(mover).transform.origin.x - AIR.x
	_check("an arrow dragged 16 studs stops at %.0f LDU, against the 2 x 4 in the way, and lights it (%s)"
		% [slid, _verbs.flashed], is_equal_approx(slid, 120.0) and _verbs.flashed.has(wall)
		and _builder.history_depth() - depth == 1)


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


static func _off_line(point: Vector3, site: JointSnap.End) -> float:
	var v: Vector3 = point - site.at
	return (v - site.axis * v.dot(site.axis)).length()


## How many handles are drawn now.
func _drawn() -> int:
	return _handles.screen_handles().size() if _handles.shown() else 0


## A ring or an arrow on the screen, and the best place to take it: {at
## (a point on it, on the near half, furthest from the others), dir (the
## way along it there, on the screen, a unit), k (its point's index)}.
func _handle(kind: String, n: int) -> Dictionary:
	var all: Array = _handles.screen_handles()
	var mine: Dictionary = {}
	for handle: Dictionary in all:
		if handle["kind"] == kind and int(handle["axis"]) == n:
			mine = handle
	if mine.is_empty():
		return {}
	var points: PackedVector2Array = mine["points"]
	var middle: Vector2 = mine["middle"]
	# Over the model, not a panel beside it.
	var view: Rect2 = ((_main.call("model_cover") as Dictionary)["view"] as Rect2).grow(-8.0)
	var best: Dictionary = {}
	var best_room: float = -1.0
	var count: int = points.size() - 1 if kind == "ring" else 4
	for k: int in count:
		var at: Vector2 = points[k] if kind == "ring" \
			else points[0].lerp(points[1], [0.7, 0.55, 0.85, 0.4][k])
		if kind == "ring" and not bool((mine["front"] as Array)[k]):
			continue
		if not view.has_point(at):
			continue
		var room: float = INF
		for other: Dictionary in all:
			if other == mine:
				continue
			var theirs: PackedVector2Array = other["points"]
			for m: int in theirs.size() - 1:
				room = minf(room, Geometry2D.get_closest_point_to_segment(at, theirs[m],
					theirs[m + 1]).distance_to(at))
		room = minf(room, at.distance_to(middle))
		if room > best_room:
			best_room = room
			var dir: Vector2 = (points[k + 1] - points[k]).normalized() if kind == "ring" \
				else (points[1] - points[0]).normalized()
			best = {"at": at, "dir": dir, "k": k, "points": points, "middle": middle}
	return best


## Press on [param handle], move [param ring_turns] of a ring's way round
## it (a ring) or [param ring_turns] arrow lengths along it (an arrow), and
## let go: one action.
func _drag_along(handle: Dictionary, amount: float, act: bool) -> void:
	if act:
		_acts["drag"] = int(_acts.get("drag", 0)) + 1
	var press: Vector2 = handle["at"]
	await _move(press)
	_button(press, true)
	await _frames(2)
	var points: PackedVector2Array = handle["points"]
	if points.size() > 2:
		# Round the ring, from the point taken.
		var k: int = handle["k"]
		var steps: int = roundi(amount * 4)
		for s: int in range(1, steps + 1):
			await _move(points[(k + s) % (points.size() - 1)], true)
	else:
		var length: float = points[0].distance_to(points[1])
		var steps: int = 8
		for s: int in range(1, steps + 1):
			await _move(press + (handle["dir"] as Vector2) * length * amount * s / steps, true)
	await _frames(4)
	_button(press, false)
	await _frames(6)


## Press on a ring or an arrow, drag it a little, type [param text] and
## Enter while the button is held, then let go: two actions (the drag, the
## number).
func _act_drag_typed(kind: String, n: int, text: String, pictured: bool) -> void:
	var handle: Dictionary = _handle(kind, n)
	if handle.is_empty():
		_check("the %s %s is on the screen" % [Handles.AXES[n], kind], false)
		return
	_acts["drag"] = int(_acts.get("drag", 0)) + 1
	_acts["number"] = int(_acts.get("number", 0)) + 1
	var press: Vector2 = handle["at"]
	await _move(press)
	_check("the pointer is over its %s %s" % [Handles.AXES[n], kind],
		_handles.handle_at(press).get("kind") == kind
		and int(_handles.handle_at(press).get("axis", -1)) == n)
	_button(press, true)
	await _frames(2)
	var points: PackedVector2Array = handle["points"]
	for s: int in range(1, 5):
		var at: Vector2 = points[(int(handle["k"]) + s) % (points.size() - 1)] if kind == "ring" \
			else press + (handle["dir"] as Vector2) * 12.0 * s
		await _move(at, true)
	_check("...it drags (%s)" % _handles.drag.get("value"), _handles.is_dragging())
	await _type(text)
	_check("...the number opens the field over the drag (%s)" % _meaning(),
		_verbs.typed.is_open() and _handles.is_typing())
	if pictured:
		await _shot("%s_typed_%s" % [kind, Handles.AXES[n]])
	await _key(KEY_ENTER)
	_button(press, false)
	await _frames(6)
	_check("...Enter puts it there and the field closes", not _verbs.typed.is_open()
		and not _handles.is_dragging())


func _meaning() -> String:
	var label: Label = _verbs.typed.find_child("Meaning", true, false)
	return label.text if label != null else ""


## A point on the screen where this part is the one under the pointer and
## no handle is.
func _spot_on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var middle: Vector2 = _screen(brick.transform * mesh.bounds.get_center())
	for r: int in range(0, 80, 3):
		for d: Vector2 in [Vector2(0, r), Vector2(r, 0), Vector2(-r, 0), Vector2(0, -r),
				Vector2(r, r), Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r)]:
			if _verbs.brick_at(middle + d) == brick_id and _handles.handle_at(middle + d).is_empty():
				return middle + d
	return middle


func _count_from() -> void:
	_acts = {"point": 0, "click": 0, "key": 0, "drag": 0, "number": 0}


func _total() -> int:
	var total: int = 0
	for kind: String in _acts:
		total += int(_acts[kind])
	return total


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2, held: bool = false) -> void:
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
	var path: String = ProjectSettings.globalize_path("res://shots/handles/%dx%d/%s.png" % [
		size.x, size.y, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)
