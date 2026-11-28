## simplesib: the siblings simplefix5 saw beside Full's exploded view. Simple
## shows every part where it stands (SimpleLayer._set_view_aside), and three
## more things could show or act on a model that is not the one Simple has:
##
##   moving  Full's panels that draw parts moved (BrickWorld.set_drawn):
##           Simulate playing the orrery, and Motions with a pose drawn and a
##           motion playing. Their column is put away for Simple while each
##           panel's own visible stays true. In Simple: nothing drawn moved or
##           tinted, nothing turning on, a part chosen drives nothing, a tap
##           where each part is drawn picks it. Back in Full: Simulate open,
##           playing and drawn as it was; the pose drawn exactly as it was; a
##           motion playing stopped, nothing left drawn.
##   open    every way a model is replaced that the bar is not told of (Main's
##           _open, _open_given and clear_model, a session's clear_model): from
##           inside a sub-assembly, none is entered after and a part put down
##           goes in no sub-assembly; the exploded view of the model before is
##           over, and bringing it "together" on the next one moves no view.
##   lens    in Simple (the phone's scale and the lens shifted up, as at 390)
##           and in Full, at rest and while the lens eases: where
##           unproject_position puts a point of the model and where the app's
##           own ray says it is (CadCamera.screen_of, the inverse of
##           ray_origin/ray_normal), and what Simple aims by (_ghost_foot).
##
##   godot --path . --resolution 390x844 --script src/dev/simplesib_probe.gd
##   godot --headless --path . --script src/dev/simplesib_probe.gd -- --headless-ok [--desktop]
##   PROBE_SIZE=1280x800 tools/probe.sh simplesib_probe -- --desktop
##   tools/probe.sh simplesib_probe -- --headless-ok [--desktop] [--case=moving,open,lens]
## Exits non-zero when a check fails.
extends "res://src/dev/simplefix5_probe.gd"

const ORRERY := "res://src/dev/fixtures/orrery_two_planets.ldr"


func _run() -> void:
	if not await _start("moving,open,lens"):
		return
	for one: String in ["moving", "open", "lens"]:
		if not _cases.has(one):
			continue
		print("\n== %s" % one)
		match one:
			"moving":
				await _case_simulate()
				await _case_pose()
			"open":
				await _case_open()
				await _case_explode_open()
			"lens":
				await _case_lens()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simplesib_probe"


# -- moving ----------------------------------------------------------------------------


func _sim_ready(panel: Node) -> bool:
	return panel != null and panel.get("sim") != null and not bool(panel.get("_reading")) \
		and not bool(panel.get("_driving")) and not Working.is_busy()


func _case_simulate() -> void:
	await _to_full()
	if not _check("[simulate] the orrery opened", await _open(ProjectSettings.globalize_path(ORRERY))):
		return
	_builder.forget_history()
	_shell().run("simulate")
	var panel: Node = null
	for _n: int in 1200:
		await process_frame
		panel = _main.get("_simulate_made")
		if _sim_ready(panel):
			break
	if not _check("[simulate] Simulate read the orrery", _sim_ready(panel)):
		return
	panel.call("play")
	await _frames(20)
	var turns_full: float = float(panel.get("turns"))
	var drawn_full: int = _world.drawn_ids().size()
	var tinted_full: int = _world.tinted_ids().size()
	_check("[simulate] Full: Simulate plays (%.3f turns), turned parts drawn (%d) and tinted (%d)" % [turns_full,
		drawn_full, tinted_full], bool(panel.get("playing")) and turns_full > 0.0 and drawn_full > 0)
	await _to_simple()
	await _frames(4)
	var turns_in: float = float(panel.get("turns"))
	await _frames(30)
	var left: Array = _view_left()
	_check("[simulate] in Simple nothing drawn moved (%s) and nothing tinted (%d)" % [", ".join(left),
		_world.tinted_ids().size()], left.is_empty() and _world.tinted_ids().is_empty())
	_check("[simulate] ...nothing turns on in Simple (%.3f -> %.3f turns)" % [turns_in, float(panel.get("turns"))],
		is_equal_approx(turns_in, float(panel.get("turns"))))
	# A part chosen in Simple is Simple's choice: no driver for Simulate.
	var sim: Simulation = panel.get("sim")
	var driver: int = sim.driver
	var other: int = 0
	for body: int in sim.turning:
		var ids: Array = sim.keys_of.get(body, [])
		if body != driver and not ids.is_empty():
			other = int(ids[0])
			break
	if other != 0:
		_builder.select_brick(other, false)
		await _frames(20)
		sim = panel.get("sim")
		_check("[simulate] ...a part chosen in Simple drives nothing (driver %d, was %d) and draws nothing (%d)" % [
			sim.driver if sim != null else -1, driver, _world.drawn_ids().size()],
			sim != null and sim.driver == driver and _world.drawn_ids().is_empty())
		_builder.clear_selection()
	await _to_full()
	await _frames(4)
	var turns_back: float = float(panel.get("turns"))
	await _frames(20)
	_check("[simulate] back in Full: open, playing and on from where it was (%.3f, then %.3f), drawn (%d) and tinted (%d) again" % [
		turns_back, float(panel.get("turns")), _world.drawn_ids().size(), _world.tinted_ids().size()],
		bool(panel.get("visible")) and bool(panel.get("playing")) and absf(turns_back - turns_in) < 0.05
		and float(panel.get("turns")) > turns_back and _world.drawn_ids().size() > 0
		and _world.tinted_ids().size() == tinted_full)
	panel.call("close")
	await _frames(3)


## The pose a motion's editor draws: [param ids] lifted [param up] LDU and
## turned a quarter.
func _pose_of(ids: Array, up: float) -> Dictionary:
	var frame: Dictionary = {}
	for id: Variant in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		frame[int(id)] = Transform3D(brick.transform.basis.rotated(Vector3.UP, PI * 0.5),
			brick.transform.origin + Vector3(0.0, up, 0.0))
	return frame


func _drawn_now() -> String:
	var out: Array = []
	for id: Variant in _world.drawn_ids():
		out.append("%d:%s" % [int(id), str((_world.drawn_ids()[id] as Transform3D).origin.snapped(Vector3.ONE * 0.01))])
	out.sort()
	return str(out)


func _case_pose() -> void:
	await _open_saved(LOOSE_MODEL, "ssib_pose.ldr")
	_shell().run("pose")
	var panel: Node = null
	for _n: int in 600:
		await process_frame
		panel = _main.get("_pose_made")
		if panel != null and bool(panel.get("visible")):
			break
	if not _check("[pose] Motions open", panel != null and bool(panel.get("visible"))):
		return
	await _frames(10)
	var ids: Array = _plain_ids().slice(0, 2)
	panel.call("_draw_frame", _pose_of(ids, 48.0))
	await _frames(4)
	var held: String = _drawn_now()
	_check("[pose held] Full: two parts drawn posed (%s)" % held, _world.drawn_ids().size() == 2)
	await _to_simple()
	await _frames(10)
	_simple_picks_right("pose held")
	await _to_full()
	await _frames(6)
	_check("[pose held] back in Full the pose drawn exactly as it was (%s, was %s)" % [_drawn_now(), held],
		_drawn_now() == held)
	# A motion playing: 600 frames lifting the two, 20 s at its pace.
	var frames: Array = []
	for k: int in 600:
		frames.append(_pose_of(ids, 2.0 + float(k) * 0.1))
	panel.call("_undraw")
	panel.call("_begin_playing", frames, null)
	await _frames(10)
	_check("[pose playing] Full: a motion plays (%s), its parts drawn moved (%d)" % [str(panel.get("_playing")),
		_world.drawn_ids().size()], bool(panel.get("_playing")) and _world.drawn_ids().size() == 2)
	await _to_simple()
	await _frames(20)
	var left: Array = _view_left()
	_check("[pose playing] in Simple it stopped (%s) and nothing is drawn moved (%s)" % [str(panel.get("_playing")),
		", ".join(left)], not bool(panel.get("_playing")) and left.is_empty())
	await _to_full()
	await _frames(10)
	_check("[pose playing] back in Full: stopped, nothing drawn moved (%d), the panel open" % _world.drawn_ids().size(),
		not bool(panel.get("_playing")) and _world.drawn_ids().is_empty() and bool(panel.get("visible")))
	panel.call("close")
	await _frames(3)


# -- open ------------------------------------------------------------------------------


func _write(text: String, file: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ModelStore.SAVE_DIR))
	var path: String = ModelStore.SAVE_DIR + file
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	return ProjectSettings.globalize_path(path)


func _wait_laid() -> void:
	for _n: int in 900:
		await process_frame
		if _store.awaited.is_empty() and not _store.laying:
			break
	await _frames(10)


func _case_open() -> void:
	var other: String = _write(STEPS_MODEL, "ssib_other.ldr")
	var main: Variant = _main
	for way: String in ["Main._open", "Main._open_given", "Main.clear_model", "a session's clear_model"]:
		await _open_saved(FROM_FULL, "ssib_open.mpd")
		var shell: Shell = _shell()
		var wing_part: int = _id_where(func(b: BrickWorld.Brick) -> bool: return not Assemblies.path_of(b).is_empty())
		_builder.clear_selection()
		_builder.select_brick(wing_part, false)
		var wing: String = shell.assemblies.selected_assembly()
		_builder.clear_selection()
		shell.assemblies.enter(wing)
		await _frames(3)
		if not _check("[%s] inside %s first" % [way, wing], not wing.is_empty() and shell.assemblies.entered == wing):
			continue
		match way:
			"Main._open":
				main._open(other)
				await _wait_laid()
			"Main._open_given":
				await main._open_given(other)
				await _wait_laid()
			"Main.clear_model":
				main.clear_model()
			"a session's clear_model":
				main.clear_model(true, "a session's clear model")
		await _frames(4)
		_check("[%s] after it, inside no sub-assembly (entered \"%s\", a part put down goes into \"%s\")" % [way,
			shell.assemblies.entered, _builder.place_group],
			shell.assemblies.entered.is_empty() and _builder.place_group.is_empty())


## Full's exploded view, then another model opened by a way the bar is not
## told of: the view of the model before is over, and "together" on the
## next one moves no view and enters nothing.
func _case_explode_open() -> void:
	var other: String = _write(STEPS_MODEL, "ssib_other2.ldr")
	var main: Variant = _main
	await _open_saved(EXPLODE_MODEL, "ssib_explode_open.ldr")
	var sections: Node = _shell().sections
	sections.call("explode_now", true)
	await _frames(20)
	if not _check("[explode open] Full drawn apart (%d)" % _drawn_apart(), bool(sections.call("is_exploded"))
			and _drawn_apart() > 0):
		return
	main._open(other)
	await _wait_laid()
	_camera.frame(_main.call("_built_bounds") as AABB)
	await _settle()
	await _frames(10)
	var pose: String = _camera_pose()
	_check("[explode open] the next model is not \"exploded\" (%s), nothing drawn moved (%d)" % [
		str(sections.call("is_exploded")), _drawn_apart()],
		not bool(sections.call("is_exploded")) and _drawn_apart() == 0)
	_shell().run("explode")
	await _frames(60)
	_check("[explode open] Exploded view on it moves no view (%s, was %s) and enters nothing (\"%s\")" % [
		_camera_pose(), pose, _shell().assemblies.entered], _camera_pose() == pose
		and _shell().assemblies.entered.is_empty())
	sections.call("explode_now", false)
	await _frames(2)


# -- lens ------------------------------------------------------------------------------


## Where the app's own rays say [param point] is on the screen: the camera's
## projection run forwards, as CadCamera._through_lens runs it backwards.
func _screen_by_rays(point: Vector3) -> Vector2:
	var local: Vector3 = _camera.get_camera_transform().affine_inverse() * point
	var clip: Vector4 = _camera.get_camera_projection() * Vector4(local.x, local.y, local.z, 1.0)
	var room: Vector2 = root.get_visible_rect().size
	return Vector2((clip.x / clip.w + 1.0) * 0.5 * room.x, (1.0 - clip.y / clip.w) * 0.5 * room.y)


## Over the middle of each part's top: [the most unproject_position and the
## rays disagree, window pixels; the furthest a ray through
## unproject_position passes from the point, LDU; the same for screen_of].
func _lens_gap() -> Array:
	var room: Vector2 = root.get_visible_rect().size
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var per: float = window.y / room.y if window.y > 0.0 else 1.0
	var px: float = 0.0
	var ldu: float = 0.0
	var ldu_own: float = 0.0
	for id: Variant in _plain_ids():
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = _world.drawn_at(brick) * part.bounds
		var point := Vector3(box.get_center().x, box.end.y - 2.0, box.get_center().z)
		var by_godot: Vector2 = _camera.unproject_position(point)
		px = maxf(px, by_godot.distance_to(_screen_by_rays(point)) * per)
		for both: Array in [[by_godot, false], [_camera.screen_of(point), true]]:
			var at: Vector2 = both[0]
			var origin: Vector3 = _camera.ray_origin(at)
			var normal: Vector3 = _camera.ray_normal(at)
			var miss: float = (point - origin).cross(normal).length()
			if bool(both[1]):
				ldu_own = maxf(ldu_own, miss)
			else:
				ldu = maxf(ldu, miss)
	return [px, ldu, ldu_own]


func _lens_line(tag: String) -> String:
	var gap: Array = _lens_gap()
	return "[%s] unproject_position and the rays %.2f px apart at most (a ray through it passes %.2f LDU from the point; through screen_of %.3f LDU); lens shift %s, frustum %s, near %.2f, keep_aspect %d, window %s, room %s" % [
		tag, gap[0], gap[1], gap[2], str(_camera.get("_shift")), str(_camera.frustum_offset), _camera.near,
		_camera.keep_aspect, str(DisplayServer.window_get_size()), str(root.get_visible_rect().size)]


func _case_lens() -> void:
	await _open_saved(LOOSE_MODEL, "ssib_lens.ldr")
	await _frames(30)
	var full: Array = _lens_gap()
	_note2(_lens_line("Full at rest"))
	_main.call("use_controls", &"simple")
	await _frames(2)
	var easing: Array = _lens_gap()
	_note2(_lens_line("Simple, the lens easing"))
	await _settle()
	await _frames(30)
	var rest: Array = _lens_gap()
	_note2(_lens_line("Simple at rest"))
	_check("[lens] what Simple marks over a part by screen_of is where the app's ray meets it: within 0.05 LDU (Full %.3f, easing %.3f, Simple %.3f)" % [
		full[2], easing[2], rest[2]], maxf(full[2], maxf(easing[2], rest[2])) < 0.05)
	_check("[lens] ...and unproject_position too, within half a pixel (Full %.2f px, easing %.2f, Simple %.2f; %.2f LDU at most)" % [
		full[0], easing[0], rest[0], maxf(full[1], maxf(easing[1], rest[1]))],
		maxf(full[0], maxf(easing[0], rest[0])) < 0.5)
	# The ghost Simple aims by: a tray part over the plate, its foot on the
	# screen (_ghost_foot) and the ray back through it.
	var at: Vector2 = _base_point(0.5, 0.5)
	if int(_simple.call("chosen_colour")) != 4:
		_simple.call("_on_swatch", 4)
	_simple.call("_take", "3003")
	_simple.call("_aim", at)
	await _frames(4)
	var box: AABB = _simple.call("_ghost_box")
	if box.size != Vector3.ZERO:
		var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		var on: Vector2 = _simple.call("_ghost_foot")
		var miss: float = (foot - _camera.ray_origin(on)).cross(_camera.ray_normal(on)).length()
		_check("[lens] Simple's ghost foot on the screen is where its ray meets the foot (%.3f LDU)" % miss, miss < 0.05)
	else:
		_note2("[lens] no ghost shown to measure (aimed at %s)" % str(at))
	_simple.call("_unchoose")
	await _frames(2)
	await _to_full()
