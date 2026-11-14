## A part pointed out to everyone in a Build together session, in the real
## app (pointat, APP_UX8 #17), with no server (Together.check_alone: this
## window in a session of its own, another person in it as a poll gives
## them).
##
##   tools/probe.sh pointat_probe
##   godot --path . --resolution 1280x720 --script src/dev/pointat_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh pointat_probe
##   ... -- --shots=DIR    each step pictured there
##
## Out of a session: Point it out to the others cannot run, its key (Alt-W)
## says to start or join one, a part's right-click menu has no such row, and
## point_at over MCP says so.
##
## In one, this person's own: a part's right-click menu has the row under
## Comment on it…, and pressing it outlines the part in this person's colour
## with "You" over it, read off the window's pixels, and sends it with the
## pointer (Together._pointer_now's look: its part by uid). Alt-W with the
## pointer on another part points that one instead. Esc takes it back: the
## outline gone, nothing sent of it, and the selection still there, so the
## next Esc does what it always did.
##
## Then another person's (Ann's, as a poll says it): outlined in her colour
## with her name over it, read off the pixels, none before; the status bar
## says she points at it; still there at 4 s, gone after 5; one 3 s old when
## heard gone 2 s later; one put away by Esc not shown again while the
## server still says it; her Claude's named "Ann's Claude". And the
## person's own Claude: point_at in one call, through the connector's own
## answer (CommandSocket), outlines it here as "Your Claude" and sends it
## named as Claude's. The panel says how to point (its key as the keymap has
## it).
##
## Each fails when the thing it looks at did nothing: no row, no pixels in
## the colour, a look sent that was not, one shown past its time.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _together: Together
var _bar: ModelBar
var _shots: String = ""
var _step: int = 0
var _size: String = ""

const ANN := "a1b2c3d4"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 900:
		await process_frame
		_world = _main.get("_world")
		_shell = _main.get("_shell")
		if _world != null and _world.brick_count() > 10 and _shell != null \
				and not (_main.get("_store") as ModelStore).laying:
			break
	if _world == null or _shell == null or _world.brick_count() <= 10:
		print("  pointat probe: SKIPPED — the window did not come up")
		quit(3)
		return
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_bar = _main.get("_bar")
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_builder.clear_selection()
	await _frames(60)
	var window := DisplayServer.window_get_size()
	print("  a %d x %d window, %d parts" % [window.x, window.y, _world.brick_count()])
	_size = "%dx%d" % [window.x, window.y]

	await _out_of_a_session()
	_together = _main.get("_together")
	await _own()
	await _others()
	await _claude()

	print("")
	if _failures == 0:
		print("pointat probe: all checks passed")
	else:
		print("pointat probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- out of a session -------------------------------------------------------------

func _out_of_a_session() -> void:
	print("\n  out of a session")
	var part: int = _parts_in_sight(1)[0] if not _parts_in_sight(1).is_empty() else 0
	_check("Point it out to the others is a command, and cannot run out of a session",
		_shell.command("together_point") != null and not _shell.can("together_point"))
	await _hover(part)
	await _alt_w()
	var said: String = _bar_words()
	_check("Alt-W over a part says to start or join a session (%s)" % said,
		said.to_lower().contains("build together"))
	await _right_click(part)
	_check("a part's right-click menu has no Point it out row", _row_id("together_point") == -1
		and _row_id("comments") != -1)
	_close_context()
	var answer: String = await _tool("point_at", {"part": part})
	_check("point_at over MCP says there is no session (%s…)" % answer.left(60),
		answer.contains("not in a Build together session"))
	_builder.clear_selection()


# -- this person's own -------------------------------------------------------------

func _own() -> void:
	print("\n  this person's own")
	var three: Array = _parts_in_sight(3)
	_check("three parts in sight", three.size() == 3)
	if three.size() < 3:
		return
	_together.check_alone([{"who": ANN, "name": "Ann", "here": true, "owner": false,
		"at": null, "sel": [], "view": null}])
	await _frames(10)
	var mine: Color = _together.colour_of("00000000")
	var before: Image = await _picture()
	var box: Rect2 = _screen_box([three[0]])
	await _right_click(three[0])
	var row: int = _row_id("together_point")
	var under: int = _shell.item_index(_shell.context, "comments")
	_check("in a session, the part's right-click menu has Point it out to the others under Comment on it…",
		row != -1 and _shell.item_index(_shell.context, "together_point") == under + 1)
	await _shot("context_menu")
	if row == -1:
		return
	_shell.context.id_pressed.emit(row)
	_close_context()
	await _frames(20)
	var looks: Array = _together.looks_shown()
	_check("pressed: the part pointed out here, as \"You\" (%s)" % str(looks),
		looks.size() == 1 and looks[0]["who"] == "me" and looks[0]["name"] == "You" and int(looks[0]["parts"]) == 1)
	var sent: Variant = _together._pointer_now().get("look")
	_check("...and sent with the pointer, its part by uid (%s)" % str(sent),
		sent is Dictionary and (sent["sel"] as Array) == [_together.uid_of(three[0])] and not bool(sent["claude"]))
	var after: Image = await _picture()
	var was: int = _near(before, box, mine, 0.1)
	var now: int = _near(after, box, mine, 0.1)
	_check("...outlined in this person's colour, read off the window: %d pixels round it, %d before" % [now, was],
		now >= 80 and now > was * 3 + 40)
	_check("...and the status bar says to whom: %s" % _bar_words(), _bar_words().contains("Ann"))
	await _shot("own_pointed", after)

	# Alt-W with the pointer on another part points that one instead.
	_builder.clear_selection()
	await _hover(three[1])
	await _alt_w()
	await _frames(20)
	looks = _together.looks_shown()
	sent = _together._pointer_now().get("look")
	_check("Alt-W over another part points that one instead (%s)" % str(looks),
		looks.size() == 1 and sent is Dictionary and (sent["sel"] as Array) == [_together.uid_of(three[1])])
	var second: Rect2 = _screen_box([three[1]])
	var picture: Image = await _picture()
	_check("...outlined there: %d pixels round it, the first part's line gone (%d, %d before)" % [
		_near(picture, second, mine, 0.1), _near(picture, box, mine, 0.1), was],
		_near(picture, second, mine, 0.1) >= 80 and _near(picture, box, mine, 0.1) <= was + 20)
	await _shot("own_alt_w", picture)

	# Esc takes it back, and nothing else: the selection stays.
	_builder.select_brick(three[2], false)
	await _frames(5)
	await _key(KEY_ESCAPE)
	await _frames(10)
	_check("Esc takes it back: nothing shown, nothing sent (%s)" % str(_together.looks_shown()),
		_together.looks_shown().is_empty() and _together._pointer_now().get("look") == null)
	_check("...and nothing else: the selection is still there", _builder.selection.has(three[2]))
	picture = await _picture()
	_check("...its line gone off the window (%d pixels)" % _near(picture, second, mine, 0.1),
		_near(picture, second, mine, 0.1) <= was + 20)
	await _key(KEY_ESCAPE)
	await _frames(5)
	_check("the next Esc does what it did: the selection cleared", _builder.selection.is_empty())

	# The panel says how.
	_check("File, Build together… runs", _shell.run("together"))
	await _frames(20)
	var dialog: TogetherDialog = _main.get("_together_dialog")
	var note: String = str(dialog.page_state().get("note", ""))
	var key: String = Keymap.written("together_point")
	_check("its panel says how to point a part out, with its key (%s)" % key,
		not key.is_empty() and note.contains("Point it out to the others") and note.contains(key))
	await _shot("panel")
	dialog.hide()
	await _frames(5)


# -- another person's ---------------------------------------------------------------

func _others() -> void:
	print("\n  another person's")
	var parts: Array = _parts_in_sight(3)
	if parts.size() < 3:
		return
	var target: int = parts[1]
	var hers: Color = _together.colour_of(ANN)
	var box: Rect2 = _screen_box([target])
	var before: Image = await _picture()
	var n: int = 1000
	_ann_points(n, target, 0)
	var began: int = Time.get_ticks_msec()
	await _frames(20)
	var looks: Array = _together.looks_shown()
	_check("Ann's point shown here, by her name (%s)" % str(looks),
		looks.size() == 1 and looks[0]["who"] == ANN and looks[0]["name"] == "Ann")
	var after: Image = await _picture()
	var was: int = _near(before, box, hers, 0.1)
	var now: int = _near(after, box, hers, 0.1)
	_check("...outlined in her colour, read off the window: %d pixels round it, %d before" % [now, was],
		now >= 80 and now > was * 3 + 40)
	var top: Vector3 = _top_of(target)
	var label: Rect2 = Rect2(_camera.unproject_position(top) - Vector2(40, 40), Vector2(80, 40))
	var named: int = _near(after, label, hers, 0.12)
	_check("...her name over it, in her colour: %d pixels, %d before" % [named, _near(before, label, hers, 0.12)],
		named >= 30 and named > _near(before, label, hers, 0.12) + 20)
	var said: String = _bar_words()
	_check("...and the status bar says she points at it: %s" % said, said.begins_with("Ann points at"))
	await _shot("ann_pointed", after)
	while Time.get_ticks_msec() - began < 4000:
		await process_frame
	_check("still shown 4 s after", _together.looks_shown().size() == 1)
	while Time.get_ticks_msec() - began < 5300:
		await process_frame
	await _frames(3)
	await _picture_gone(box, hers, was)
	_check("gone 5 s after it was pointed out (%s)" % str(_together.looks_shown()), _together.looks_shown().is_empty())
	_ann_points(n, target, 0)
	await _frames(5)
	_check("...and not shown again while the server still says it", _together.looks_shown().is_empty())

	# Heard 3 s old: shown for the 2 s it has left.
	_ann_points(n + 1, target, 3000)
	began = Time.get_ticks_msec()
	await _frames(5)
	_check("one 3 s old when heard is shown", _together.looks_shown().size() == 1)
	while Time.get_ticks_msec() - began < 2300:
		await process_frame
	_check("...and gone 2 s later", _together.looks_shown().is_empty())

	# Esc puts hers away here, for good.
	_ann_points(n + 2, target, 0)
	await _frames(10)
	_check("a new one shown", _together.looks_shown().size() == 1)
	await _key(KEY_ESCAPE)
	await _frames(5)
	_check("Esc puts it away here", _together.looks_shown().is_empty())
	_ann_points(n + 2, target, 100)
	await _frames(5)
	_check("...and it is not shown again while the server still says it", _together.looks_shown().is_empty())

	# Her Claude's.
	_ann_points(n + 3, target, 0, true)
	await _frames(10)
	looks = _together.looks_shown()
	_check("her Claude's point named \"Ann's Claude\" (%s)" % str(looks),
		looks.size() == 1 and looks[0]["name"] == "Ann's Claude")
	await _shot("ann_claude")
	_together.check_alone([{"who": ANN, "name": "Ann", "here": true, "owner": false, "at": null, "sel": [],
		"view": null}])
	await _frames(5)
	_check("taken back by her (no look in what the server says): gone here", _together.looks_shown().is_empty())


func _picture_gone(box: Rect2, colour: Color, was: int) -> void:
	var picture: Image = await _picture()
	_check("...its line off the window: %d pixels" % _near(picture, box, colour, 0.1),
		_near(picture, box, colour, 0.1) <= was + 20)


## Ann, as a poll says her: pointing [param target] out, [param age] ms ago.
func _ann_points(n: int, target: int, age: int, by_claude: bool = false) -> void:
	var at: Vector3 = _world.get_brick(target).transform.origin
	_together.check_alone([{"who": ANN, "name": "Ann", "here": true, "owner": false, "at": null, "sel": [],
		"view": null, "look": {"n": n, "sel": [_together.uid_of(target)], "at": [at.x, at.y, at.z],
		"claude": by_claude, "age": age}}])


# -- the person's Claude ------------------------------------------------------------

func _claude() -> void:
	print("\n  the person's Claude")
	var parts: Array = _parts_in_sight(3)
	if parts.size() < 3:
		return
	var answer: String = await _tool("point_at", {"part": parts[2]})
	var looks: Array = _together.looks_shown()
	_check("point_at in one call: %s" % answer, answer.begins_with("Pointed out part %d" % parts[2])
		and answer.contains("Ann"))
	_check("...shown here as \"Your Claude\" (%s)" % str(looks), looks.size() == 1 and looks[0]["name"] == "Your Claude")
	var sent: Variant = _together._pointer_now().get("look")
	_check("...and sent as Claude's (%s)" % str(sent), sent is Dictionary and bool(sent["claude"])
		and (sent["sel"] as Array) == [_together.uid_of(parts[2])])
	_check("...the status bar says so: %s" % _bar_words(), _bar_words().begins_with("Your Claude points out"))
	await _frames(20)
	await _shot("claude_pointed")
	answer = await _tool("point_at", {"parts": [999999]})
	_check("a number in no part is refused, said (%s)" % answer, answer.begins_with("No part 999999"))
	_together._stop("")
	await _frames(5)
	_check("the session over: nothing shown", _together.looks_shown().is_empty())


# -- helpers ------------------------------------------------------------------------

func _tool(name: String, arguments: Dictionary) -> String:
	var together: Together = _main.get("_together")
	return str(await together.run_tool.call(name, arguments))


func _parts_in_sight(count: int) -> Array:
	var found: Array = _main.call("_parts_to_click", count)
	return found.map(func(one: Dictionary) -> int: return int(one["brick"]))


func _at_of(brick_id: int) -> Vector2:
	for one: Dictionary in _main.call("_parts_to_click", 40):
		if int(one["brick"]) == brick_id:
			return one["at"]
	return _camera.unproject_position(_world.get_brick(brick_id).transform.origin)


func _top_of(brick_id: int) -> Vector3:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var bounds: AABB = (brick.transform * _world.library.mesh_for(brick.part_id).bounds).abs()
	return Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)


func _screen_box(ids: Array) -> Rect2:
	var box := Rect2()
	var first: bool = true
	for id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var bounds: AABB = (brick.transform * _world.library.mesh_for(brick.part_id).bounds).abs()
		for n: int in 8:
			var at: Vector2 = _camera.unproject_position(bounds.get_endpoint(n))
			box = Rect2(at, Vector2.ZERO) if first else box.expand(at)
			first = false
	return box.grow(8.0)


func _near(picture: Image, area: Rect2, colour: Color, slack: float) -> int:
	var scale: Vector2 = Vector2(picture.get_size()) / root.get_visible_rect().size
	var from := Vector2i((area.position * scale).floor()).clamp(Vector2i.ZERO, picture.get_size() - Vector2i.ONE)
	var to := Vector2i((area.end * scale).ceil()).clamp(Vector2i.ZERO, picture.get_size())
	var count: int = 0
	for y: int in range(from.y, to.y):
		for x: int in range(from.x, to.x):
			var c: Color = picture.get_pixel(x, y)
			if absf(c.r - colour.r) < slack and absf(c.g - colour.g) < slack and absf(c.b - colour.b) < slack:
				count += 1
	return count


func _bar_words() -> String:
	return _bar.status_text()


func _row_id(name: String) -> int:
	if _shell.context == null or not _shell.context.visible:
		return -1
	var at: int = _shell.item_index(_shell.context, name)
	return _shell.context.get_item_id(at) if at != -1 else -1


func _close_context() -> void:
	if _shell.context != null:
		_shell.context.hide()


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _hover(brick_id: int) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(_at_of(brick_id))
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(5)


func _right_click(brick_id: int) -> void:
	await _hover(brick_id)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		event.position = _as_event(_at_of(brick_id))
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(8)


func _alt_w() -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_W
		event.physical_keycode = KEY_W
		event.alt_pressed = true
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(5)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _picture() -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _shot(name: String, picture: Image = null) -> void:
	if _shots.is_empty():
		return
	if picture == null:
		picture = await _picture()
	_step += 1
	var path: String = _shots.path_join("%s_%02d_%s.png" % [_size, _step, name])
	picture.save_png(path)
	print("    picture: %s" % path)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
