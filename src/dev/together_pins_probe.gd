## Building together as a person sees it, in the real app (APP_UX B8): a
## comment pinned to a part, another person's pointer and selection in
## their colour, and Follow on their name.
##
##   tools/probe.sh together_pins_probe
##   godot --path . --resolution 1280x720 --script src/dev/together_pins_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh together_pins_probe
##   ... -- --shots=DIR    each step pictured there
##
## The comment, with no session: a part selected, File, Comments… (the
## command, as the menu and the part's right-click run it), words typed and
## Pin pressed. Its mark is drawn on the part, in its colour, read off the
## window's pixels; pressed, its card opens, and one click on Resolve takes
## it off the model and keeps it in the file, resolved; Ctrl+Z brings it
## back. Saved into the person's models and opened again, it is on the same
## part, and drawn there.
##
## The others, with no server (Together.check_alone: this window in a
## session of its own, another person in it as a poll gives them): their two
## selected parts outlined in their colour and their pointer's dot, both read
## off the pixels, none of it before. Then File, Build together…, Follow on
## their name, clicked: the view turns to theirs and goes where theirs goes,
## framed in their colour with their name and Stop; the person turning the
## view themselves (the wheel over the model) stops it, and their next turn
## moves this view no more; Follow again, then Stop, stops it too.
##
## Each fails when the thing it looks at did nothing: no mark, no card, no
## pixels in the colour, a view that stayed where it was.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _camera: CadCamera
var _together: Together
var _shots: String = ""
var _step: int = 0


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
		print("  together pins probe: SKIPPED — the window did not come up")
		quit(3)
		return
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_camera = _main.get("_camera")
	_together = _main.get("_together")
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_builder.clear_selection()
	await _frames(60)
	var window := DisplayServer.window_get_size()
	print("  a %d x %d window, %d parts" % [window.x, window.y, _world.brick_count()])
	_size = "%dx%d" % [window.x, window.y]

	await _pins()
	await _colours()
	await _follow()

	print("")
	if _failures == 0:
		print("together pins probe: all checks passed")
	else:
		print("together pins probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


var _size: String = ""


# -- a comment pinned to a part ------------------------------------------------------

func _pins() -> void:
	print("\n  a comment pinned to a part")
	var view: PinsView = _main.get("_pins_view")
	var part: int = _part_in_sight()
	_check("a part in sight to comment on (#%d)" % part, part != 0)
	if part == 0:
		return
	_builder.select_brick(part, false)
	await _frames(5)
	_check("File, Comments… runs", _shell.run("comments"))
	await _frames(20)
	var dialog: PinsDialog = _main.get("_pins_dialog")
	_check("...and opens the Comments panel", dialog != null and dialog.visible)
	if dialog == null:
		return
	var named: Dictionary = dialog.controls_by_name()
	(named["pins_field"] as LineEdit).grab_focus()
	await _frames(3)
	await _type("Roof starts here")
	await _click(_centre(named["pins_pin"]))
	await _frames(10)
	var pin: PinnedComments.Pin = _store.pins.list[0] if not _store.pins.list.is_empty() else null
	_check("Pin pressed: a comment on the part, by its words (%s)" % (pin.text if pin != null else "none"),
		pin != null and pin.text == "Roof starts here" and pin.brick == part)
	_check("...in the model's file", _store.to_text(_store.title).contains(PinnedComments.META)
		and _store.to_text(_store.title).contains("Roof starts here"))
	await _shot("comments_panel")
	await _click(_centre(dialog.get_ok_button()))
	await _frames(10)
	_builder.clear_selection()
	await _frames(20)
	var mark: Button = view.mark_of(pin.id) if pin != null else null
	_check("its mark is drawn on the model (%d)" % view.marks_shown(), mark != null and mark.is_visible_in_tree())
	if mark == null:
		return
	var picture: Image = await _picture()
	var at: Vector2 = _centre(mark)
	var tinted: int = _near(picture, Rect2(at - Vector2(9, 9), Vector2(18, 18)), PinsView.DEFAULT_TINT, 0.12)
	_check("...in its colour, read off the window: %d pixels" % tinted, tinted >= 60)
	var over: Vector2 = _camera.unproject_position(PinnedComments.point_of(pin, _world, _store.lift()))
	_check("...over its part (%.0f px from the part's top)" % at.distance_to(over), at.distance_to(over) < 4.0)
	await _shot("pin_on_part", picture)

	await _click(at)
	await _frames(12)
	var resolve: Button = view.card_resolve()
	_check("pressed, the mark opens its card", resolve != null)
	await _shot("pin_card")
	if resolve == null:
		return
	await _click(_centre(resolve))
	await _frames(12)
	_check("one click on Resolve: resolved, off the model (%d marks)" % view.marks_shown(),
		pin.resolved and view.marks_shown() == 0)
	_check("...and kept in the file, resolved", _store.to_text(_store.title).contains("\"resolved\":true"))
	await _key(KEY_Z, true)
	await _frames(12)
	pin = _store.pins.list[0] if not _store.pins.list.is_empty() else null
	_check("Ctrl+Z brings it back on the model", pin != null and not pin.resolved and view.marks_shown() == 1)

	var place: Vector3 = _world.get_brick(part).transform.origin
	var kind: String = _world.get_brick(part).part_id
	var count: int = _world.brick_count()
	var path: String = ModelStore.SAVE_DIR + "Pins probe %s.ldr" % _size
	_check("saved into the person's models", _main.save_model(path))
	var bar: ModelBar = _main.get("_bar")
	# As File, Open… opens one: the bar's own open, then its signal.
	var placed: int = await bar.open_with_progress(path)
	if placed >= 0:
		bar.opened.emit(placed)
	for _n: int in 300:
		await process_frame
		if not _store.laying and _store.awaited.is_empty():
			break
	await _frames(30)
	pin = _store.pins.list[0] if not _store.pins.list.is_empty() else null
	var found: int = PinnedComments.find(pin, _world, _store.lift()) if pin != null else 0
	var brick: BrickWorld.Brick = _world.get_brick(found)
	var now: int = _world.brick_count()
	_check("opened again (%d parts and the floor, %d before): the comment is on the same part" % [now, count],
		now == count and pin != null
		and pin.text == "Roof starts here" and brick != null and brick.part_id == kind
		and brick.transform.origin.distance_to(place) < 0.5)
	_check("...and drawn there", view.marks_shown() == 1)
	await _shot("pin_opened_again")


# -- the others, in their colours ------------------------------------------------------

const ANN := "a1b2c3d4"


func _colours() -> void:
	print("\n  another person's pointer and selection")
	var two: Array = _parts_in_sight(2)
	_check("two parts in sight for them to select", two.size() == 2)
	if two.size() < 2:
		return
	var box: Rect2 = _screen_box(two)
	var before: Image = await _picture()
	_together.check_alone([])
	var colour_of_ann: Color = Color.WHITE
	var uids: Array = two.map(func(id: int) -> String: return _together.uid_of(id))
	var top: Vector3 = _world.get_brick(two[0]).transform.origin
	_ann_view = _camera.aim()
	_together.check_alone([{"who": ANN, "name": "Ann", "here": true, "owner": false,
		"at": [top.x, top.y, top.z], "sel": uids, "view": _ann_view}])
	colour_of_ann = _together.colour_of(ANN)
	await _frames(40)
	var after: Image = await _picture()
	var was: int = _near(before, box, colour_of_ann, 0.1)
	var now: int = _near(after, box, colour_of_ann, 0.1)
	_check("Ann's two selected parts outlined here (%s)" % str(_together.selections_shown()),
		int(_together.selections_shown().get(ANN, 0)) == 2)
	_check("...in her colour, read off the window: %d pixels round them, %d before" % [now, was],
		now >= 80 and now > was * 3 + 40)
	var dot: Rect2 = Rect2(_camera.unproject_position(top) - Vector2(14, 14), Vector2(28, 28))
	var pointed: int = _near(after, dot, colour_of_ann, 0.12)
	var shown: int = _together.pointers_shown()
	await _shot("colours", after)
	_together.check_alone([{"who": ANN, "name": "Ann", "here": true, "owner": false,
		"at": null, "sel": uids, "view": _ann_view}])
	await _frames(12)
	var nowhere: int = _near(await _picture(), dot, colour_of_ann, 0.12)
	_check("her pointer's dot drawn where she points, in her colour: %d pixels, %d with her pointing nowhere"
		% [pointed, nowhere], shown == 1 and _together.pointers_shown() == 0 and pointed >= nowhere + 40)
	# A cursor's size whatever the view: near, it hides nothing it points at.
	_together.check_alone([{"who": ANN, "name": "Ann", "here": true, "owner": false,
		"at": [top.x, top.y, top.z], "sel": uids, "view": _ann_view}])
	var near_view: Dictionary = _ann_view.duplicate(true)
	near_view["distance"] = float(near_view["distance"]) * 0.4
	near_view["size"] = float(near_view["size"]) * 0.4
	_camera.aim_at(near_view)
	await _frames(20)
	var close: Image = await _picture()
	var near_dot: Rect2 = Rect2(_camera.unproject_position(top) - Vector2(14, 14), Vector2(28, 28))
	var near_pointed: int = _near(close, near_dot, colour_of_ann, 0.12)
	_check("...the same size with the view two and a half times nearer: %d pixels" % near_pointed,
		near_pointed >= 40 and near_pointed <= pointed * 2 and near_pointed * 2 >= pointed)
	await _shot("pointer_near", close)
	_camera.aim_at(_ann_view)
	await _frames(12)


var _ann_view: Dictionary = {}


func _follow() -> void:
	print("\n  Follow on her name")
	_check("File, Build together… runs", _shell.run("together"))
	await _frames(20)
	var dialog: TogetherDialog = _main.get("_together_dialog")
	var follow: Button = dialog.controls_by_name().get("together_follow_1") if dialog != null else null
	_check("...and its panel has Follow beside Ann", follow != null and follow.is_visible_in_tree())
	await _shot("panel_follow")
	if follow == null:
		return
	var turned: Dictionary = _ann_view.duplicate(true)
	turned["yaw"] = float(turned["yaw"]) + 1.2
	turned["distance"] = float(turned["distance"]) * 0.7
	_ann_says(turned)
	var mine: Dictionary = _camera.aim()
	await _click(_centre(follow))
	await _frames(10)
	_check("Follow clicked: following her, the view turned to hers", _together.following == ANN
		and Together._same_view(_camera.aim(), turned) and not Together._same_view(mine, turned))
	await _click(_centre(dialog.get_ok_button()))
	await _frames(30)
	var banner: Button = _together.stop_button()
	_check("...the view framed in her colour, her name and Stop over it", banner != null
		and banner.is_visible_in_tree())
	var picture: Image = await _picture()
	var model: Rect2 = (_main.get("_over_model") as Control).get_global_rect()
	var framed: int = _near(picture, Rect2(model.position + Vector2(0, model.size.y / 2.0 - 40), Vector2(4, 80)),
		_together.colour_of(ANN), 0.1)
	_check("...the frame read off the window's left edge: %d pixels" % framed, framed >= 100)
	await _shot("following", picture)
	turned["yaw"] = float(turned["yaw"]) - 2.0
	turned["focus"] = [float(turned["focus"][0]) + 60.0, float(turned["focus"][1]), float(turned["focus"][2])]
	_ann_says(turned)
	await _frames(10)
	if not _check("she turns: this view goes with her", Together._same_view(_camera.aim(), turned)):
		print("    hers %s, this %s, following %s" % [turned, _camera.aim(), _together.following])
	# The person turns the view themselves: the wheel over the model.
	await _wheel(model.get_center())
	await _frames(10)
	_check("the wheel over the model stops it", _together.following.is_empty())
	var kept: Dictionary = _camera.aim()
	turned["yaw"] = float(turned["yaw"]) + 0.8
	_ann_says(turned)
	await _frames(20)
	_check("...and her next turn moves this view no more", Together._same_view(_camera.aim(), kept)
		and not Together._same_view(_camera.aim(), turned))
	_check("...and the frame is gone", _together.stop_button() == null)
	_together.follow(ANN)
	await _frames(10)
	var stop: Button = _together.stop_button()
	_check("Follow again, then Stop pressed, stops it", stop != null)
	if stop != null:
		await _click(_centre(stop))
		await _frames(10)
		_check("...stopped", _together.following.is_empty() and _together.stop_button() == null)
	_together._stop("")


func _ann_says(view: Dictionary) -> void:
	var people: Array = _together.people.duplicate(true)
	for person: Dictionary in people:
		if str(person.get("who", "")) == ANN:
			# A copy, as each poll's words are new: the probe goes on turning its own.
			person["view"] = view.duplicate(true)
	_together.check_alone(people.filter(func(p: Dictionary) -> bool: return not bool(p.get("me", false))))


# -- helpers ------------------------------------------------------------------------

## A part near the middle of the view whose top is in sight (Main's own
## choice for the page's clicks), or 0.
func _part_in_sight() -> int:
	var found: Array = _parts_in_sight(1)
	return int(found[0]) if not found.is_empty() else 0


func _parts_in_sight(count: int) -> Array:
	var found: Array = _main.call("_parts_to_click", count)
	return found.map(func(one: Dictionary) -> int: return int(one["brick"]))


## Round the parts [param ids] on the screen, a little out.
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


## How many pixels of [param picture] in [param area] (the view's units) are
## within [param slack] of [param colour].
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


## The middle of [param control], in the view's units, inside a dialog too.
func _centre(control: Control) -> Vector2:
	var at: Vector2 = control.get_global_rect().get_center()
	var window: Window = control.get_window()
	if window != root and window != null:
		at += Vector2(window.position)
	return at


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(4)


func _wheel(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP
		event.pressed = down
		event.factor = 1.0
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.physical_keycode = event.keycode
			event.unicode = c.unicode_at(0)
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
