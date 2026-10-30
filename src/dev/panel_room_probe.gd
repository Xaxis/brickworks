## The panels that work on the model as it is seen stand beside it, never
## over the parts a person clicks (keys3). Build, Motions… and Tools,
## Colour the hidden parts… were laid over the model's left edge at (12,
## 48), and View, Stress's legend down its right edge under the view cube:
## the model's room and the view's framing never knew they were there.
## (Simulate and the hose tool have their own: simulate_probe and
## flex_room_probe.)
##
##   godot --path . --resolution 1280x720 --script src/dev/panel_room_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh panel_room_probe
##   tools/probe.sh panel_room_probe pose   (or hidden_colours, or stress: one)
##
## A model as wide as it is deep: five bricks in a row across the plate,
## two more in front and a turntable behind. For each panel, opened as a
## person opens it:
## - the panel stands beside the model's room, not in it, and nothing of
##   the window is over the model but the view cube (Main.model_cover);
## - turned round the model in twelve steps at two heights, framed each
##   time, every part in front of the eye and in the window is in the
##   model's room with nothing over it;
## - framed from the front, the part furthest left is the one a click there
##   lands on, with nothing over it;
## - closed: the panel goes, and the parts column and the model's room are
##   back as they were.
## Then, the parts column folded first and so nothing to fold, the view
## zoomed in till the row is as wide as its room: Stress's legend opening
## leaves every part that was in sight in sight.
extends SceneTree

const PANELS: Array[String] = ["pose", "hidden_colours", "stress"]
const NAMES: Dictionary = {"pose": "Motions", "hidden_colours": "Colour the hidden parts",
	"stress": "Stress's legend"}

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _verbs: EditVerbs
var _size: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	await process_frame
	ShellPrefs.kept_by_a_check = true
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var wanted: Array = Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool:
		return a in PANELS)
	if wanted.is_empty():
		wanted = PANELS.duplicate()
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
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	print("  a %s window" % _size)
	_main.call("clear_model")
	# In the scene's own axes (up is +Y): a row of 2 x 4 bricks across the
	# plate, two in front of it, a turntable behind.
	for x: int in [-160, -80, 0, 80, 160]:
		_put("3001", Vector3(x, 24, 0))
	_put("3001", Vector3(-120, 24, 80))
	_put("3001", Vector3(120, 24, 80))
	_put("3680", Vector3(0, 8, -80))
	await _frames(3)

	for which: String in wanted:
		print("")
		print("  %s" % NAMES[which])
		await _panel_room(which)
	if "stress" in wanted:
		print("")
		await _narrower()

	print("")
	if _failures == 0:
		print("panel room: %s beside the model and over none of it" % ", ".join(
			wanted.map(func(w: String) -> String: return NAMES[w])))
	else:
		print("panel room: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _panel_room(which: String) -> void:
	var bin: SideDock = _main.get("_bin_dock")
	var bin_was: bool = bin.is_open()
	_camera.set_view("default")
	_shell.run("fit_model")
	await _frames(60)
	var room_was: Rect2 = _room()
	var panel: Control = await _open(which)
	if not _check("%s opens" % NAMES[which], panel != null and panel.is_visible_in_tree()):
		return
	await _frames(30)
	await _shot("open_" + which)
	var room: Rect2 = _room()
	_check("the panel stands beside the model's room, not in it (panel %s, room %s)" % [
		_rect_words(panel.get_global_rect()), _rect_words(room)],
		not panel.get_global_rect().intersects(room))
	var cover: Dictionary = _main.call("model_cover")
	_check("nothing of the window is over the model but the view cube (%d of %d points covered%s)"
		% [(cover["covered"] as Array).size(), int(cover["samples"]), _first_cover(cover)],
		(cover["covered"] as Array).is_empty())

	await _all_round()
	await _reach()

	_close(which)
	await _frames(30)
	# Across: the foot of the room moves with the line saying what the app
	# is busy with (Colour the hidden parts goes on looking once closed).
	var room_now: Rect2 = _room()
	_check("closed: the panel goes, the parts column is as it was (%s) and the model's room "
		% ("open" if bin.is_open() else "folded") + "across too (%s, was %s)"
		% [_rect_words(room_now), _rect_words(room_was)],
		not panel.is_visible_in_tree() and bin.is_open() == bin_was
		and is_equal_approx(room_now.position.x, room_was.position.x)
		and is_equal_approx(room_now.size.x, room_was.size.x))


## Opened as a person opens it, and shown: Build, Motions…; Tools, Colour
## the hidden parts… (it measures what is hidden first); View, Stress (it
## weighs every joint first).
func _open(which: String) -> Control:
	var panel: Control = _panel(which)
	match which:
		"pose": _shell.run("pose")
		"hidden_colours": _main.call("open_hidden_colours", "sections")
		"stress": _shell.run("stress")
	for _n: int in 1200:
		if panel.is_visible_in_tree():
			break
		await process_frame
	return panel


func _close(which: String) -> void:
	match which:
		"pose": (_panel(which) as PosePanel).close()
		"hidden_colours": (_panel(which) as HiddenColoursPanel).close()
		"stress": _shell.run("stress")


func _panel(which: String) -> Control:
	return _shell.stress.panel if which == "stress" else _main.get("_" + which)


## Turned round the model, framed each time: every part in sight is in the
## model's room with nothing over it.
func _all_round() -> void:
	var looked: int = 0
	var bad: Array = []
	for pitch: float in [20.0, 55.0]:
		for step: int in 12:
			_camera.set("_target_yaw", deg_to_rad(step * 30.0))
			_camera.set("_target_pitch", deg_to_rad(pitch))
			_shell.run("fit_model")
			await _frames(40)
			for brick: BrickWorld.Brick in _model():
				var middle: Vector3 = _middle(brick)
				if _camera.is_position_behind(middle):
					continue
				var at: Vector2 = _camera.unproject_position(middle)
				if not root.get_visible_rect().has_point(at):
					continue
				looked += 1
				var by: String = _covered_by(at)
				if by.is_empty():
					continue
				if bad.size() < 4:
					bad.append("%d° up, %d° round, %s: %s" % [roundi(pitch), step * 30,
						brick.part_id, by])
				else:
					bad.append("")
	_check("turned round it at two heights, %d parts in sight, none behind a panel%s"
		% [looked, "" if bad.is_empty() else " (%d: %s)" % [bad.size(),
		", ".join(bad.filter(func(s: String) -> bool: return not s.is_empty()))]],
		looked >= 12 * _model().size() and bad.is_empty())


## Framed from the front: of the parts whose middles the eye reaches (none
## in front of them), the one furthest left has nothing over it, so a
## click there lands on it.
func _reach() -> void:
	_camera.set_view("front")
	_shell.run("fit_model")
	await _frames(60)
	var left: BrickWorld.Brick = null
	var left_at := Vector2(INF, 0)
	for brick: BrickWorld.Brick in _model():
		var at: Vector2 = _camera.unproject_position(_middle(brick))
		if at.x < left_at.x and _verbs.brick_at(at) == brick.id:
			left = brick
			left_at = at
	var by: String = _covered_by(left_at) if left != null else "no part reached"
	_check("from the front, a click on the part furthest left, %s at %s, lands on it (%s)" % [
		left.part_id if left != null else "-", _point_words(left_at),
		"nothing over it" if by.is_empty() else by], by.is_empty())


## The parts column folded before Stress's legend opens, so its column
## takes room from the model's, and the view zoomed in till the row is as
## wide as its room: every part in sight before is in sight after.
func _narrower() -> void:
	var bin: SideDock = _main.get("_bin_dock")
	bin.set_open(false, false)
	_camera.set_view("front")
	await _frames(10)
	_shell.run("fit_model")
	await _frames(60)
	var before: Rect2 = _room()
	for _step: int in 12:
		var view: Dictionary = _camera.aim()
		view["distance"] = float(view["distance"]) * 0.9
		_camera.aim_at(view)
		await _frames(30)
		if _in_sight(before).size() < _model().size():
			view["distance"] = float(view["distance"]) / 0.9
			_camera.aim_at(view)
			await _frames(30)
			break
	var seen: Array = _in_sight(before)
	var panel: Control = await _open("stress")
	await _frames(60)
	var after: Rect2 = _room()
	var lost: Array = []
	for brick_id: int in seen:
		var at: Vector2 = _camera.unproject_position(_middle(_world.get_brick(brick_id)))
		if not after.has_point(at) or not _covered_by(at).is_empty():
			lost.append(_world.get_brick(brick_id).part_id)
	await _shot("narrower")
	_check("the parts column folded and the view zoomed in: Stress's legend takes its room beside "
		+ "the model's (%d units across, was %d), and the %d parts in sight are in sight still"
		% [roundi(after.size.x), roundi(before.size.x), seen.size()]
		+ ("" if lost.is_empty() else " (gone: %s)" % ", ".join(lost)),
		panel.is_visible_in_tree() and after.size.x < before.size.x
		and seen.size() == _model().size() and lost.is_empty())
	_close("stress")
	await _frames(10)
	bin.set_open(true, false)
	await _frames(10)


## The middle of a part's box, where a click on it is aimed.
func _middle(brick: BrickWorld.Brick) -> Vector3:
	var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
	return brick.transform * (info.bounds.get_center() if info != null else Vector3.ZERO)


## The parts whose middles are in [param room], by id.
func _in_sight(room: Rect2) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		var middle: Vector3 = _middle(brick)
		if not _camera.is_position_behind(middle) \
				and room.has_point(_camera.unproject_position(middle)):
			out.append(brick.id)
	return out


## The model's room: the part of the window it is seen in.
func _room() -> Rect2:
	return _main.call("_model_rect")


## What is over a point instead of the model: "" for nothing, "outside
## the model's room" for a point beside it.
func _covered_by(at: Vector2) -> String:
	if not _room().has_point(at):
		return "outside the model's room"
	var canvases: Array[Node] = []
	_main.call("_canvas_roots", root, canvases)
	canvases.sort_custom(func(a: Node, b: Node) -> bool:
		return int(_main.call("_layer_of", a)) > int(_main.call("_layer_of", b)))
	return str(_main.call("_covering", at, canvases))


func _first_cover(cover: Dictionary) -> String:
	var covered: Array = cover["covered"]
	return "" if covered.is_empty() else ", the first by %s" % str((covered[0] as Dictionary)["by"])


func _rect_words(rect: Rect2) -> String:
	return "%d to %d across" % [roundi(rect.position.x), roundi(rect.end.x)]


func _point_words(at: Vector2) -> String:
	return "(%d, %d)" % [roundi(at.x), roundi(at.y)]


func _put(part: String, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, 7, where)
	_builder.register(brick_id, part, where)


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://shots/panel_room/%s_%s.png" % [name, _size])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)
