## Does a part's Turn, typed by a finger into Properties, turn it, on a
## tablet held sideways (docs/APP_UX9.md, smalls4 item 6)?
##
##   godot --path . --resolution 1024x768 --script src/dev/typedturn_probe.gd
##   ... -- --shots=DIR    the window once Properties is open, to look at
##
## phonewalk_flow.mjs's turn of 15° on a tablet, 1024 x 768, typed 15 into
## nothing three runs of three on brickworks.diy (2026-11-16): Properties,
## asked for from the part's actions, sat in the drawer over the colours,
## too short for all of it, and Z, Turn, Tilt and Roll were under its fold.
## The tap meant for Turn landed on the bar between Properties and the
## colours, no field took the keys, and the brick stayed where it was.
##
## Here the window is laid out for a finger as a tablet held sideways is
## (Phone, wide; typedturn_phone_probe holds it as a phone), a 2 x 4 put
## down alone, and then as a person does it: the brick tapped, held for its
## actions, their Properties tapped. Then:
##   Turn is inside the window and in sight in its scroller, cut off by
##   nothing it is in (Main._cut_off, what the page is told);
##   a finger's tap on it gives it the keys;
##   "15" typed over it and Enter turn the brick 15° about the up.
extends SceneTree

var _main: Node
var _shell: Shell
var _failures: int = 0
var _shots: String = ""


func _initialize() -> void:
	_run()


## The layout this script holds: a tablet's, held sideways.
func _wide() -> bool:
	return true


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _touch(at: Vector2, down: bool) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at * scale
	touch.pressed = down
	Input.parse_input_event(touch)


func _tap(at: Vector2) -> void:
	_touch(at, true)
	await _frames(3)
	_touch(at, false)
	await _frames(10)


func _keys(text: String) -> void:
	for letter: String in text:
		for down: bool in [true, false]:
			var key := InputEventKey.new()
			key.pressed = down
			key.unicode = letter.unicode_at(0) if down else 0
			key.keycode = OS.find_keycode_from_string(letter.to_upper())
			Input.parse_input_event(key)
			await _frames(2)


func _press(keycode: Key) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.pressed = down
		key.keycode = keycode
		Input.parse_input_event(key)
		await _frames(2)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	Phone._on = 1
	Phone._wide = _wide()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	_shell = _main.get("_shell")
	var window: Rect2 = root.get_visible_rect()
	print("\n  the window: %d x %d units, laid out for a %s" % [roundi(window.size.x),
		roundi(window.size.y), "tablet" if _wide() else "phone"])
	var world: BrickWorld = _main.get("_world")
	var builder: Builder = _main.get("_builder")
	var verbs: EditVerbs = _main.get("_verbs")
	var camera: Camera3D = _main.get("_camera")
	var library: Variant = _main.get("_library")
	_main.call("clear_model")
	await _frames(10)
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick: int = world.add_brick("3001", 4, where)
	builder.register(brick, "3001", where)
	_shell.run("fit")
	await _frames(40)

	# The brick, where the app's own hit test finds it.
	var box: AABB = library.mesh_for("3001").bounds
	var at: Vector2 = Vector2.INF
	for local: Vector3 in [box.get_center(), box.get_center() + Vector3(box.size.x * 0.3, 0, 0),
			box.get_center() - Vector3(box.size.x * 0.3, 0, 0)]:
		var spot: Vector2 = camera.unproject_position(world.get_brick(brick).transform * local)
		if window.has_point(spot) and verbs.brick_at(spot) == brick:
			at = spot
			break
	if not _check("the brick in sight to tap (%s)" % [at], at != Vector2.INF):
		quit(1)
		return
	await _tap(at)
	_check("a tap on it selects it alone", builder.selection.size() == 1 and builder.selection.has(brick))
	# Held, for its actions (Main.HOLD_MS, 480 ms).
	_touch(at, true)
	await create_timer(0.8).timeout
	_touch(at, false)
	await _frames(10)
	var named: Dictionary = _main.call("_page_controls")
	var row: Control = named.get("phone_row_show_properties")
	if not _check("held, its actions offer Properties", row != null and row.is_visible_in_tree()):
		quit(1)
		return
	# The sheet slides up: tapped where it rests, as a finger finds it.
	var was: Rect2 = Rect2()
	var still: int = 0
	for _n: int in 300:
		await process_frame
		var now: Rect2 = row.get_global_rect()
		still = still + 1 if now.is_equal_approx(was) else 0
		was = now
		if still >= 5:
			break
	# Past the list's fold, as Properties is among a part's actions on a
	# tablet's side sheet: brought into sight, as a finger's drag up the
	# list brings it (swapfind_phone_probe; the walk's reach).
	var list: Node = row.get_parent()
	while list != null and not (list is ScrollContainer):
		list = list.get_parent()
	if list != null and not (list as Control).get_global_rect().grow(1.0).encloses(row.get_global_rect()):
		(list as ScrollContainer).ensure_control_visible(row)
		await _frames(6)
	await _tap(row.get_global_rect().get_center())
	var field: SpinBox = null
	for _n: int in 300:
		await process_frame
		named = _main.call("_page_controls")
		field = named.get("prop_turn") as SpinBox
		if field != null and field.is_visible_in_tree():
			break
	await _frames(40)
	if not _check("Properties shows Turn (the phone: %s)" % [_main.get("_phone").call("state")],
			field != null and field.is_visible_in_tree()):
		quit(1)
		return
	var line: LineEdit = field.get_line_edit()
	var rect: Rect2 = line.get_global_rect()
	_check("Turn is inside the window (%s)" % [rect], window.encloses(rect))
	var cut_by: Control = _main.call("_cut_off", line)
	_check("Turn is in sight in its scroller, cut off by nothing it is in (%s)"
		% ["nothing" if cut_by == null else str(cut_by.get_path())], cut_by == null)
	if not _shots.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_shots.path_join("properties.png"))
	var before: float = _yaw(world, brick)
	await _tap(rect.get_center())
	var focus: Control = root.gui_get_focus_owner()
	_check("a finger's tap on Turn gives it the keys (%s)" % [focus], focus == line)
	# Over what it held, as the walk types over it (a tap that brings the
	# keyboard up may drop the field's select-all: phonewalk_flow's deletes).
	line.select_all()
	await _keys("15")
	_check("it reads 15 typed (\"%s\")" % line.text, line.text == "15")
	await _press(KEY_ENTER)
	await _frames(20)
	var turned: float = wrapf(_yaw(world, brick) - before, -180.0, 180.0)
	_check("Enter turned the brick 15° (%.1f°)" % turned, absf(turned - 15.0) < 0.5)

	print("")
	if _failures == 0:
		print("a part's Turn typed by a finger into Properties turns it")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## The brick's turn about the up, in degrees.
func _yaw(world: BrickWorld, brick: int) -> float:
	var x: Vector3 = world.get_brick(brick).transform.basis.x
	return rad_to_deg(atan2(-x.z, x.x))
