## A part taken hold of on its joint and let go ends selected, as a carried part
## does (appwalk): one finger on a phone, the mouse on the desktop's layout.
##
##   godot --path . --resolution 390x844 --script src/dev/grabselect_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh grabselect_probe        the desktop's layout
##
## On the web a part dragged on a phone ended unselected (phonedrag's note,
## 2026-11-23). The car a first visit opens has its headlights on one stud each,
## so a drag on one turns it about the stud (GrabDrag) where a part held by two
## studs is carried (EditVerbs.drag_start). A carried part is selected where it
## is put down (Builder._put_carried); a grab let go selected nothing, so Turn,
## Colour and Delete, the next things a finger reaches for, acted on nothing
## and were greyed out. In the app laid out for the window (a phone's under 600
## units across), a 2 x 4 brick on the floor and a 1 x 1 brick on one of its
## studs:
##   1. the 1 x 1 dragged: taken hold of on its joint, not carried; let go, it
##      has turned, in one step to undo, and it is selected, alone, the 2 x 4
##      selected before it no longer;
##   2. a 2 x 4 alone dragged: carried, as before, and selected where it is put
##      down (with the 1 x 1 on it, a press on the 2 x 4 turns the 1 x 1: the
##      anchored half of a joint moves the half across it, Grab._from_part);
##   3. on a phone, a second finger on the screen while the first turns the
##      1 x 1: put back where it was, and the selection as it was before the
##      press (nothing), as a second finger leaves a carried part (touchfix);
##   4. the two made a sub-assembly and a click on the 2 x 4: it takes them
##      whole, and on the desktop's layout the status line names the
##      sub-assembly and says a double-click edits inside it, as a phone's line
##      does (a set's house, 149 parts, was said as "149 selected — … C
##      paints"); on a phone, a tap: its line says hold, then Edit inside, and
##      nothing names a double tap, which turns a part there.
## Pictures in shots/grabselect/. Exits non-zero when a check fails.
extends "res://src/dev/twist_probe.gd"

const PICTURES := "res://shots/grabselect/"

var _base: int = 0
var _small: int = 0


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("grabselect_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale, as twist_probe holds it.
	if _layout == "phone":
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	(_main.get("_store") as ModelStore).keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	print("grabselect_probe: a %s window, laid out for a %s" % [_size, _layout])
	await _model()
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-60, 0, -40), Vector3(120, 72, 80)))
	await _settle()
	_home = _camera.aim()
	var grab: GrabDrag = _main.get("_grab_drag")
	if grab != null and not grab.is_ready():
		grab.call("_ready_now")

	print("\n1. the 1 x 1 on one stud, dragged")
	await _model()
	await _go_home()
	_builder.select_brick(_base, false)
	var on: Vector2 = _point_on(_small)
	_check("the 1 x 1 is under the point (%s)" % on, on != Vector2.INF)
	var before: Array = _parts()
	var depth: int = _builder.history_depth()
	var was: Transform3D = _world.get_brick(_small).transform
	await _shot2("1_before")
	var held: Array = await _drag_from(on, on + Vector2(_reach() * 0.6, 0.0), 20, "1b_held")
	await _shot2("2_after")
	_check("...taken hold of on its joint (%s), not carried (%s)" % [held[0], held[1]],
		bool(held[0]) and not bool(held[1]))
	var now: Transform3D = _world.get_brick(_small).transform if _world.get_brick(_small) != null \
		else Transform3D()
	_check("...turned about its stud (%s), in one step to undo (%d, was %d)"
		% ["turned" if not now.basis.is_equal_approx(was.basis) else "not turned",
			_builder.history_depth(), depth],
		not now.basis.is_equal_approx(was.basis) and _builder.history_depth() == depth + 1)
	_check("...and selected alone (%s; the 1 x 1 is %d, the 2 x 4 %d)"
		% [_builder.selection.keys(), _small, _base], _builder.selection.keys() == [_small])
	print("  measure grab %s" % _moved(before))

	print("\n2. a 2 x 4 alone on the floor, dragged")
	await _model(false)
	await _go_home()
	before = _parts()
	var base_at: Vector2 = _point_on(_base)
	_check("the 2 x 4 is under the point (%s)" % base_at, base_at != Vector2.INF)
	held = await _drag_from(base_at, base_at + Vector2(0.0, _reach() * 0.4))
	_check("...carried (%s), not taken hold of on a joint (%s)" % [held[1], held[0]],
		bool(held[1]) and not bool(held[0]))
	var put: Array = _builder.selection.keys()
	_check("...put down and selected (%s), %s" % [put, _moved(before)],
		put.size() >= 1 and _moved_count(before) >= 1)

	if _layout == "phone":
		print("\n3. a second finger while the first turns the 1 x 1")
		await _model()
		await _go_home()
		before = _parts()
		on = _point_on(_small)
		_touch(0, on, true)
		await process_frame
		var at: Vector2 = on
		var grabbed: bool = false
		for n: int in 10:
			var next: Vector2 = at + Vector2(6.0, 0.0)
			_drag(0, next, next - at)
			at = next
			await process_frame
			grabbed = grabbed or bool(_main.get("_grabbing"))
		var beside: Vector2 = on + Vector2(0.0, _reach() * 0.8)
		_touch(1, beside, true)
		await _frames(3)
		_touch(1, beside, false)
		_touch(0, at, false)
		await _settle()
		_check("...it was taken hold of (%s), and is put back, the selection as it was: %s"
			% [grabbed, _moved(before)], grabbed and _parts() == before)

	print("\n4. a %s on a part of a sub-assembly" % ("tap" if _layout == "phone" else "click"))
	await _model()
	await _go_home()
	_builder.selection[_base] = true
	_builder.selection[_small] = true
	var made: String = _verbs.assemblies.make("Wall")
	_builder.clear_selection()
	await _frames(4)
	var at: Vector2 = _point_on(_base)
	if _layout == "phone":
		_touch(0, at, true)
		await process_frame
		_touch(0, at, false)
	else:
		_button(at, true)
		await process_frame
		_button(at, false)
	# A tap waits out a double tap's time before it selects.
	for _n: int in 90:
		await process_frame
		if not _builder.selection.is_empty():
			break
	await _frames(8)
	var shell: Variant = _main.get("_shell")
	var said: String = str(shell.status.message.text)
	if _layout == "desktop":
		_check("a click on its 2 x 4 takes the sub-assembly %s whole (%d selected) and says which and how to change one: \"%s\""
			% [made, _builder.selection.size(), said],
			_builder.selection.size() == 2 and said.begins_with("Wall selected, 2 parts")
				and said.contains("double-click edits inside"))
	else:
		# A phone's double tap turns: its line says hold, then Edit inside, and
		# nothing said over it names a double tap or click.
		var line: String = str((_main.get("_phone") as Node).call("hint"))
		_check("a tap on its 2 x 4 takes the sub-assembly %s whole (%d selected); the phone's line says hold, then Edit inside: \"%s\" (the status line \"%s\")"
			% [made, _builder.selection.size(), line, said],
			_builder.selection.size() == 2 and line.begins_with("Wall selected, 2 parts")
				and line.contains("hold, then Edit inside") and not line.contains("double")
				and not said.contains("double"))
	await _shot2("4_subassembly")

	print("\ngrabselect_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## A 2 x 4 brick on the floor and (unless [param small] is false) a 1 x 1
## brick on its end stud, nothing selected, no history, the Select tool, the
## example car taken off first.
func _model(small: bool = true) -> void:
	if _builder.is_carrying():
		_builder.cancel_carry()
	_main.call("clear_model")
	await _frames(4)
	_base = _world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	_builder.register(_base, "3001", _world.get_brick(_base).transform)
	_small = 0
	if small:
		_small = _world.add_brick("3005", 1, Transform3D(Basis.IDENTITY, Vector3(30, 48, 10)))
		_builder.register(_small, "3005", _world.get_brick(_small).transform)
	_builder.forget_history()
	_builder.clear_selection()
	_verbs.set_mode("select")
	var grab: GrabDrag = _main.get("_grab_drag")
	if grab != null:
		grab.call("read_soon")
	await _frames(6)
	if grab != null and not grab.is_ready():
		grab.call("_ready_now")


## A point on the screen where [param brick_id] is the part under it, near
## the middle of its top: the first of a few round its projected centre.
func _point_on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null:
		return Vector2.INF
	var centre: Vector2 = _camera.screen_of(brick.transform.origin + Vector3(0, -6, 0))
	for offset: Vector2 in [Vector2.ZERO, Vector2(0, 4), Vector2(0, -4), Vector2(4, 0), Vector2(-4, 0),
			Vector2(0, 8), Vector2(0, -8)]:
		if _verbs.brick_at(centre + offset) == brick_id:
			return centre + offset
	return Vector2.INF


## One finger (a phone) or the left button (the desktop's) pressed at [param
## from], moved to [param to] a frame at a time, and let go: whether it was
## [taken hold of on a joint, carried] while it moved.
func _drag_from(from: Vector2, to: Vector2, steps: int = 20, mid: String = "") -> Array:
	var grabbed: bool = false
	var carried: bool = false
	if _layout == "phone":
		_touch(0, from, true)
	else:
		_button(from, true)
	await process_frame
	var at: Vector2 = from
	for n: int in steps:
		var next: Vector2 = from.lerp(to, _eased(n + 1, steps))
		if _layout == "phone":
			_drag(0, next, next - at)
		else:
			_motion(next, next - at)
		at = next
		await process_frame
		grabbed = grabbed or bool(_main.get("_grabbing"))
		carried = carried or bool(_main.get("_dragging_part"))
		if n == steps - 2 and not mid.is_empty():
			await _shot2(mid)
	if _layout == "phone":
		_touch(0, to, false)
	else:
		_button(to, false)
	await _settle()
	# A swing let go settles over frames before it is kept.
	var grab: GrabDrag = _main.get("_grab_drag")
	for _n: int in 240:
		if grab == null or not (grab.is_swinging() or grab.is_settling() or grab.is_falling()):
			break
		await process_frame
	await _frames(4)
	return [grabbed, carried]


func _button(at: Vector2, down: bool) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = down
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	press.position = _as_event(at)
	press.global_position = press.position
	Input.parse_input_event(press)


func _motion(at: Vector2, by: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(by)
	Input.parse_input_event(move)


func _shot2(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PICTURES))
	root.get_texture().get_image().save_png("%s%s_%s_%s.png" % [PICTURES, _size, _layout, name])
