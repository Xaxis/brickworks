## The studio on a phone, walked as three people would (unit ux15,
## bench/results/ux15-2026-11-23/WALK.md): someone following a gallery
## model's steps from start to end (p15: next, back, the step's parts, the
## model turned and zoomed, a jump to a step, a swipe along the bar, and
## leaving and coming back to the same step), someone building a small model
## from scratch (p16: a part picked, put down, turned, recoloured, undone,
## held for its menu, saved), and someone opening a set from its page with
## Make your own version and changing one thing (p17). And the studio's own
## timeline on a model with steps (p18), as a set's Build it opens it: on the
## desktop at 1280 x 800 it is the layout that must not change.
## Research, not in the suite: each step prints the walk's own "UX12 step"
## line (what covers the model, the status, the sheets, the targets under a
## fingertip) and a picture; "UX15 check" lines judge the instructions bar
## and the gestures. Exits 0 once every step is pictured, 1 when the app
## never came up.
##
##   godot --path . --resolution 390x844 --script src/dev/ux15_phone_probe.gd -- [--phone] [--pictures=DIR] [--only=p15,p16,p17,p18]
##
## --phone lays the app out for a phone at a browser's scale, by fingers, as
## ux12_walk_probe does (run it in a 360x780, 390x844 or 430x932 window).
## Without it, the desktop's layout: the p15 pictures at 1280 x 800 are the
## desktop's timeline, which must not change.
extends "res://src/dev/ux12_walk_probe.gd"

const LINK := "Ux15Walk01"
## A gallery model with its designer's steps: 35 of them, 187 parts.
const GALLERY := "res://models/sports_car.ldr"

var _ux15_only: PackedStringArray = []
var _ux15_failures: int = 0


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1700.0).timeout.connect(func() -> void:
		print("UX15 cut off after 1700 s at step %d" % _steps)
		quit(2))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ux15_phone_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	_out = "user://ux15_walk"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			_out = arg.trim_prefix("--pictures=")
		elif arg == "--phone":
			_on_phone = true
		elif arg.begins_with("--only="):
			_ux15_only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if _on_phone:
		Phone._on = 1
		Phone._wide = false
		Input.emulate_touch_from_mouse = true
	await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	print("UX15 walk in a %d x %d window%s" % [size.x, size.y, ", laid out for a phone"
		if _on_phone else ""])
	BuildSteps._kept.clear()
	if _wants("p15"):
		if not await _up(true):
			quit(1)
			return
		await _follower()
		await _down()
	if _wants("p16") or _wants("p17") or _wants("p18"):
		if not await _up(false):
			quit(1)
			return
		_store.keeps = false
		if _wants("p16"):
			await _scratch_builder()
		if _wants("p17"):
			await _own_version()
		if _wants("p18"):
			await _studio_steps()
	print("UX15 done: %d steps pictured, %d check(s) failed" % [_steps, _ux15_failures])
	quit(0)


func _wants(section: String) -> bool:
	return _ux15_only.is_empty() or _ux15_only.has(section)


## The app up: the studio, or a shared model's viewer (the gallery's link).
func _up(viewer: bool) -> bool:
	_main = load("res://src/main.tscn").instantiate()
	if viewer:
		var fake := FakeShared.new()
		fake.answer = {"code": 200, "body": {"id": LINK, "name": "Sports Car", "author": "Probe Builder",
			"parts": 187, "url": "https://brickworks.diy/m/" + LINK,
			"model": FileAccess.get_file_as_string(GALLERY)}}
		_main.set("_viewing", LINK)
		_main.set("_shared", fake)
	root.add_child(_main)
	for _n: int in 2400:
		await process_frame
		if viewer:
			var view: Variant = _main.get("_share_view")
			if view is ShareView and (view as ShareView).state in ["ready", "failed", "gone"]:
				break
		elif bool(_main.get("_built")):
			break
	if viewer:
		var view: Variant = _main.get("_share_view")
		if not (view is ShareView and (view as ShareView).state == "ready"):
			print("ux15_phone_probe: the shared model never opened")
			return false
	elif not bool(_main.get("_built")):
		print("ux15_phone_probe: the app never came up")
		return false
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback and not viewer:
		(playback as BuildPlayback).stop()
	_phone = _main.get("_phone")
	if _on_phone:
		if _phone != null:
			_phone.set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
		await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_bin = _main.get("_bin")
	_bar = _main.get("_bar")
	await _frames(60)
	return true


func _down() -> void:
	_main.queue_free()
	await _frames(10)


# -- p15: following a gallery model's steps ---------------------------------------


func _bar_() -> StepsBar:
	return _main.get("_steps")


## The timeline's step, by its number on the booklet's page, 0 at the start.
func _at() -> int:
	var step: Instructions.Step = _bar_().current_step()
	return step.number if step != null else 0


func _control(name: String) -> Control:
	var named: Dictionary = _bar_().controls_by_name()
	var found: Variant = named.get(name)
	return found as Control if found is Control and (found as Control).is_visible_in_tree() else null


func _follower() -> void:
	print("\nUX15 p15: following a gallery model's steps on a phone")
	var steps: StepsBar = _bar_()
	var since: int = Time.get_ticks_msec()
	while (steps.is_starting() or not steps.is_playing_back()) and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _until_still(60)
	await _step("p15_01_opened", "the gallery model's link opened: its steps at the foot")
	await _bar_report("p15_01")
	# To the first step: the step's number and step 1, or the bar's Start.
	var number: Control = _control("steps_at")
	if number != null:
		await _press_at(_centre(number))
		await _frames(30)
		await _jump_in_sheet(1)
	else:
		var start: Control = _control("steps_start")
		if start != null:
			await _press_at(_centre(start))
	await _frames(20)
	await _step("p15_02_first", "to the first step")
	_check15("at the first step (%d)" % _at(), _at() == 1)
	# Next, as a thumb finds it.
	var next: Control = _control("steps_next")
	var was: int = _at()
	if next != null:
		await _press_at(_centre(next))
		await _frames(20)
	await _step("p15_02b_next", "Next tapped")
	_check15("Next tapped goes a step on (%d to %d)" % [was, _at()], _at() > was)
	if next != null:
		await _press_at(_centre(next))
		await _frames(20)
		await _press_at(_centre(next))
		await _frames(20)
	await _step("p15_03_next_twice", "Next twice more")
	var back: Control = _control("steps_back")
	was = _at()
	if back != null:
		await _press_at(_centre(back))
		await _frames(20)
	await _step("p15_04_back", "Back tapped")
	_check15("Back tapped goes a step back (%d to %d)" % [was, _at()], _at() < was)
	# The parts for this step: the bar's own Parts, else the viewer's.
	var parts: Control = _control("steps_parts")
	if parts != null:
		# Shown from the first step, as a booklet's parts box is; Parts takes
		# them away for the model's room and brings them back.
		var shown: int = _parts_shown()
		await _press_at(_centre(parts))
		await _frames(30)
		await _step("p15_05_parts_away", "Parts tapped: the pictures put away")
		var away: int = _parts_shown()
		await _press_at(_centre(parts))
		await _frames(30)
		await _step("p15_05_parts", "Parts tapped again: the step's parts as pictures")
		_check15("the step's parts shown as pictures, and Parts puts them away and back (%d, %d, %d)"
			% [shown, away, _parts_shown()], shown > 0 and away == 0 and _parts_shown() > 0)
	else:
		await _step("p15_05_parts", "the step's parts: the bar's words alone (no Parts)")
		_check15("the step's parts shown as pictures (no Parts on the bar)", false)
	# Turned by a finger, then pinched.
	var turned_from: Basis = _camera.global_transform.basis
	var middle: Vector2 = _model_middle()
	await _drag(middle - Vector2(60, 0), middle + Vector2(80, 0), 12)
	await _frames(20)
	await _step("p15_06_turned", "the model turned by a finger dragged across it")
	_check15("a finger across the model turns it",
		not _camera.global_transform.basis.is_equal_approx(turned_from))
	var far: float = float(_camera.get("_target_distance"))
	await _pinch(middle, 40.0, 130.0)
	await _frames(30)
	var near: float = float(_camera.get("_target_distance"))
	await _step("p15_07_zoomed", "two fingers spread on the model")
	_check15("two fingers spread zoom in (%.0f to %.0f)" % [far, near], near < far - 1.0)
	# A jump to a step: what the bar offers for it.
	was = _at()
	var at: Control = _control("steps_at")
	if at != null:
		await _press_at(_centre(at))
		await _frames(30)
		await _step("p15_08_jump_sheet", "the step's number tapped: go to a step")
		var to: int = await _jump_in_sheet(25)
		await _frames(30)
		await _step("p15_08_jumped", "step %d chosen" % to)
		_check15("a step chosen from the number is shown (%d, %d asked)" % [_at(), to], _at() == to)
	else:
		var slider: Control = _control("steps_slider")
		if slider != null:
			var rect: Rect2 = slider.get_global_rect()
			await _drag(rect.position + Vector2(rect.size.x * 0.3, rect.size.y * 0.5),
				rect.position + Vector2(rect.size.x * 0.7, rect.size.y * 0.5), 8)
			await _frames(20)
		await _step("p15_08_jumped", "the slider dragged to jump ahead")
		_check15("a step jumped to by its number (no number to tap; slider %d to %d)" % [was, _at()],
			false)
	# A swipe along the bar, as a phone's pages turn.
	was = _at()
	var bar_rect: Rect2 = steps.get_global_rect()
	var row_y: float = bar_rect.end.y - bar_rect.size.y * 0.25
	await _drag(Vector2(bar_rect.position.x + bar_rect.size.x * 0.8, row_y),
		Vector2(bar_rect.position.x + bar_rect.size.x * 0.2, row_y), 10)
	await _frames(20)
	await _step("p15_09_swiped", "a thumb swiped left along the bar")
	_check15("a swipe left along the bar is Next (%d to %d)" % [was, _at()], _at() == was + 1)
	# Away and back again: Done (or More's), then the viewer's Steps.
	var left_at: int = _at()
	await _leave_steps()
	await _step("p15_10_left", "the steps put away")
	var view: ShareView = _main.get("_share_view")
	var again: Variant = view.controls_by_name().get("view_steps") if view != null else null
	if again is Control:
		await _press_at(_centre(again as Control))
	else:
		_main.call("_toggle_steps")
	since = Time.get_ticks_msec()
	while (steps.is_starting() or not steps.is_playing_back()) and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _frames(30)
	await _step("p15_11_back_again", "the steps opened again")
	_check15("back at the step left (%d, left at %d)" % [_at(), left_at], _at() == left_at)
	await _bar_report("p15_11")
	# More: everything else, one tap away.
	var more: Control = _control("steps_more")
	if more != null:
		await _press_at(_centre(more))
		await _frames(30)
		await _step("p15_12_more", "the bar's More")
		await _close_all()
	# Build it, the viewer's own step player, for comparison.
	var build: Variant = view.controls_by_name().get("view_build") if view != null else null
	if build is Control:
		await _press_at(_centre(build as Control))
		await _frames(60)
		await _step("p15_13_build_it", "the viewer's Build it, the step player")


## What the bar is at this step: its height, the rows its buttons fill, the
## buttons in sight and whether any is cut off at the window's edge.
func _bar_report(label: String) -> void:
	var steps: StepsBar = _bar_()
	var window: Rect2 = root.get_visible_rect()
	var pt: float = Phone.per_point(root) if _on_phone else 1.0
	var buttons: Array = []
	var rows: Dictionary = {}
	var cut: Array = []
	var small: Array = []
	_buttons_in(steps, buttons)
	for button: Button in buttons:
		var rect: Rect2 = button.get_global_rect()
		rows[roundi(rect.position.y / 4.0)] = true
		if rect.end.x > window.end.x + 0.5 or rect.position.x < -0.5:
			cut.append(button.text)
		if _on_phone and minf(rect.size.x, rect.size.y) / pt < Phone.TARGET - 0.5:
			small.append("%s %.0fx%.0f" % [button.text, rect.size.x / pt, rect.size.y / pt])
	var tall: float = steps.get_global_rect().size.y
	print("UX15 bar %s: %.0f of %.0f tall (%d%%), %d buttons in sight on %d row(s); cut off: %s; under a fingertip: %s" % [
		label, tall, window.size.y, roundi(100.0 * tall / window.size.y), buttons.size(), rows.size(),
		", ".join(cut) if not cut.is_empty() else "none", ", ".join(small) if not small.is_empty() else "none"])
	if _on_phone:
		_check15("%s: the bar's buttons on one row (%d rows)" % [label, rows.size()], rows.size() <= 1)
		_check15("%s: at most 6 buttons on the bar (%d)" % [label, buttons.size()], buttons.size() <= 6)
		_check15("%s: nothing on the bar cut off (%s)" % [label, ", ".join(cut)], cut.is_empty())
		_check15("%s: every button a fingertip (%s)" % [label, ", ".join(small)], small.is_empty())
		_check15("%s: the bar a fifth of the screen or less (%d%%)" % [label,
			roundi(100.0 * tall / window.size.y)], tall <= window.size.y * 0.2)


func _buttons_in(node: Node, out: Array) -> void:
	for child: Node in node.get_children():
		if child is Window:
			continue
		var button := child as Button
		if button != null and button.is_visible_in_tree():
			out.append(button)
		_buttons_in(child, out)


## The pictures of the step's parts the bar shows.
func _parts_shown() -> int:
	var steps: StepsBar = _bar_()
	if steps.has_method("parts_state"):
		return int((steps.call("parts_state") as Dictionary).get("pictures", 0))
	return 0


## A step chosen in the go-to sheet: [param wanted], or the nearest the
## sheet offers. Returns the step asked for.
func _jump_in_sheet(wanted: int) -> int:
	var steps: StepsBar = _bar_()
	if steps.has_method("go_to_step_control"):
		var chip: Variant = steps.call("go_to_step_control", wanted)
		if chip is Control:
			await _press_at(_centre(chip as Control))
			await _frames(20)
			return wanted
	return -1


func _leave_steps() -> void:
	var done: Control = _control("steps_done")
	if done == null:
		var more: Control = _control("steps_more")
		if more != null:
			await _press_at(_centre(more))
			await _frames(30)
			done = _control("steps_done")
	if done != null:
		await _press_at(_centre(done))
	else:
		_main.call("_toggle_steps")
	await _frames(30)


# -- p16: a small model from scratch -----------------------------------------------


func _scratch_builder() -> void:
	print("\nUX15 p16: building a small model from scratch on a phone")
	await _close_all()
	_main.call("clear_model")
	await _frames(30)
	await _step("p16_01_empty", "an empty baseplate")
	await _phone_parts("brick 2 x 4", "p16_02_parts", "Parts, searched: brick 2 x 4")
	await _take_first_tile("p16_03_in_hand", "the first tile tapped")
	await _put_down(Vector3(0, 0, 0), "p16_04_put_down", "tapped on the baseplate")
	var placed: int = _world.bricks().size()
	_check15("a part put down by tapping (%d parts)" % placed, placed >= 1)
	# What is in hand let go (Select, as the row's hint says), then the part
	# tapped to select it, as a phone selects.
	var verbs: EditVerbs = _main.get("_verbs")
	if _builder.is_carrying() or verbs.shows_ghost():
		await _tool("select")
		await _frames(10)
	var brick: BrickWorld.Brick = _newest_brick()
	if brick != null:
		await _tap(_camera.unproject_position(brick.transform.origin))
		await _frames(20)
	await _step("p16_05_selected", "the part tapped")
	_check15("the part tapped is selected (%d selected)" % _builder.selection.size(),
		brick != null and _builder.selection.has(brick.id))
	var turned_was: Basis = brick.transform.basis if brick != null else Basis()
	await _tool("turn")
	await _step("p16_06_turned", "Turn tapped")
	brick = _newest_brick()
	_check15("Turn turns the part", brick != null and not brick.transform.basis.is_equal_approx(turned_was))
	await _tool("colour")
	await _step("p16_07_colours", "Colour tapped")
	var colour_was: int = brick.color_code if brick != null else -1
	# Another colour than its own: blue, or red on a blue part.
	var wanted: int = 4 if colour_was == 1 else 1
	var swatch: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_swatch_%d" % wanted) \
		if _phone != null else null
	if swatch is Control:
		await _press_at(_centre(swatch as Control))
		await _frames(20)
	brick = _newest_brick()
	await _step("p16_08_painted", "another colour chosen")
	_check15("the colour chosen paints the part (%d to %d)" % [colour_was, brick.color_code if brick != null else -1],
		brick != null and brick.color_code == wanted)
	var undo: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_undo") \
		if _phone != null else null
	if undo is Control:
		await _press_at(_centre(undo as Control))
		await _frames(20)
	brick = _newest_brick()
	await _step("p16_09_undone", "Undo tapped")
	_check15("Undo takes the colour back (%d)" % (brick.color_code if brick != null else -1),
		brick != null and brick.color_code == colour_was)
	# A finger held on the part: its menu.
	if brick != null:
		await _hold(_camera.unproject_position(brick.transform.origin), 1.0)
		await _frames(20)
	await _step("p16_10_held", "a finger held on the part")
	_check15("a finger held on a part opens its menu (%s)" % _phone_sheet(), not _phone_sheet().is_empty())
	await _close_all()
	await _tool("more")
	await _step("p16_11_more", "More, for Save")
	var save: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_quick_save") \
		if _phone != null else null
	if save is Control:
		await _press_at(_centre(save as Control))
		await _frames(40)
	await _step("p16_12_save", "Save tapped")
	await _close_all()


func _newest_brick() -> BrickWorld.Brick:
	var newest: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if newest == null or brick.id > newest.id:
			newest = brick
	return newest


func _tool(what: String) -> void:
	if _phone == null:
		return
	var button: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_" + what)
	if button is Control:
		await _press_at(_centre(button as Control))
		await _frames(30)


## The phone's Parts, searched: the row's Parts tapped, the words typed.
func _phone_parts(words: String, shot: String, what: String) -> void:
	if _phone_sheet() != "Parts":
		await _tool("parts")
	var search: LineEdit = _bin.get("_search")
	search.grab_focus()
	search.text = words
	search.text_changed.emit(words)
	await create_timer(0.6).timeout
	await _frames(20)
	await _step(shot, what)


# -- p18: the studio's own timeline -------------------------------------------------


## A model with steps open in the studio, its timeline from More (on a phone)
## or Build, Timeline: the instructions bar as a set's Build it opens it.
func _studio_steps() -> void:
	print("\nUX15 p18: the studio's timeline on %s" % ("a phone" if _on_phone else "the desktop"))
	await _open_model("res://models/kart.ldr", "Kart")
	var steps: StepsBar = _bar_()
	if _on_phone and _phone != null:
		await _tool("more")
		var row: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_quick_timeline")
		if row is Control:
			await _press_at(_centre(row as Control))
		else:
			_shell.run("timeline")
	else:
		_shell.run("timeline")
	var since: int = Time.get_ticks_msec()
	while (steps.is_starting() or not steps.is_playing_back()) and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _frames(30)
	await _step("p18_01_timeline", "the studio's timeline, at its first step")
	await _bar_report("p18_01")
	var next: Control = _control("steps_next")
	if next != null:
		await _press_at(_centre(next))
		await _frames(20)
	await _step("p18_02_next", "Next")
	var more: Control = _control("steps_more")
	if more != null:
		await _press_at(_centre(more))
		await _frames(30)
		await _step("p18_03_more", "the bar's More: the rest, in a sheet")
		await _close_all()
	await _leave_steps()


# -- p17: Make your own version of a set --------------------------------------------


func _own_version() -> void:
	print("\nUX15 p17: a set's Make your own version, one thing changed")
	await _close_all()
	_main.set("_from_library", SET)
	_main.call("_maybe_open_library")
	for _n: int in 120:
		await process_frame
		var asking: Variant = _bar.get("_confirm_open")
		if asking is Window and (asking as Window).visible:
			print("UX15 p17: asked to save what was there first; answered Don't save")
			(asking as Window).hide()
			_bar.emit_signal("_replace_answered", "discard")
			break
	# The set comes from the library: fetched, then laid out.
	var since: int = Time.get_ticks_msec()
	while _world.brick_count() < 20 and Time.get_ticks_msec() - since < 120000:
		await process_frame
	print("UX15 p17: the set's %d parts in %.1f s" % [_world.brick_count(),
		(Time.get_ticks_msec() - since) / 1000.0])
	await _until_still(240)
	await _step("p17_01_opened", "the set opened as a copy of its own")
	# One part, near the middle of the screen, tapped and recoloured.
	var brick: BrickWorld.Brick = _brick_near(_model_middle())
	if brick != null:
		await _tap(_camera.unproject_position(brick.transform.origin))
		await _frames(20)
	await _step("p17_02_selected", "a part tapped")
	await _tool("colour")
	await _step("p17_03_colours", "Colour tapped")
	var was: int = brick.color_code if brick != null else -1
	var wanted: int = 4 if was == 1 else 1
	var swatch: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_swatch_%d" % wanted) \
		if _phone != null else null
	if swatch is Control:
		await _press_at(_centre(swatch as Control))
		await _frames(20)
	await _step("p17_04_painted", "another colour chosen")
	var now: BrickWorld.Brick = _world.get_brick(brick.id) if brick != null else null
	_check15("the tapped part painted (%d to %d)" % [was, now.color_code if now != null else -1],
		now != null and now.color_code == wanted)
	await _tool("more")
	await _step("p17_05_more", "More, to save or share it")
	await _close_all()


## The part whose middle is drawn nearest [param at], scenery left out.
func _brick_near(at: Vector2) -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	var best_d: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or _camera.is_position_behind(brick.transform.origin):
			continue
		var d: float = _camera.unproject_position(brick.transform.origin).distance_to(at)
		if d < best_d:
			best_d = d
			best = brick
	return best


# -- fingers ------------------------------------------------------------------------


func _centre(control: Control) -> Vector2:
	# A control in a sheet (an embedded Window) is placed in the sheet: the
	# sheet's own place added, for a tap on the window it is drawn in.
	var at: Vector2 = control.get_global_rect().get_center()
	var window: Window = control.get_window()
	while window != null and window != root:
		at += Vector2(window.position)
		window = window.get_parent().get_window() if window.get_parent() != null else null
	return at


## The middle of the model's room on the screen.
func _model_middle() -> Vector2:
	var cover: Dictionary = _main.call("model_cover", 4, 4)
	var rect: Variant = cover.get("view")
	if rect is Rect2:
		return (rect as Rect2).get_center()
	return root.get_visible_rect().get_center()


func _touch(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _drag_to(index: int, from: Vector2, to: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _as_event(to)
	drag.relative = _as_event(to) - _as_event(from)
	Input.parse_input_event(drag)


func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	if not _on_phone:
		await _move(from)
		_button(from, true)
		await _frames(2)
		for n: int in steps:
			await _move(from.lerp(to, float(n + 1) / steps))
		_button(to, false)
		await _frames(4)
		return
	_touch(0, from, true)
	await _frames(3)
	var last: Vector2 = from
	for n: int in steps:
		var at: Vector2 = from.lerp(to, float(n + 1) / steps)
		_drag_to(0, last, at)
		last = at
		await _frames(2)
	_touch(0, to, false)
	await _frames(6)


## Two fingers [param from] apart about [param at], spread to [param to].
func _pinch(at: Vector2, from: float, to: float) -> void:
	if not _on_phone:
		for _n: int in 4:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			wheel.position = _as_event(at)
			Input.parse_input_event(wheel)
			await _frames(3)
		return
	var a := at - Vector2(from * 0.5, 0)
	var b := at + Vector2(from * 0.5, 0)
	_touch(0, a, true)
	await _frames(2)
	_touch(1, b, true)
	await _frames(3)
	for n: int in 10:
		var spread: float = lerpf(from, to, float(n + 1) / 10.0) * 0.5
		var a2 := at - Vector2(spread, 0)
		var b2 := at + Vector2(spread, 0)
		_drag_to(0, a, a2)
		_drag_to(1, b, b2)
		a = a2
		b = b2
		await _frames(2)
	_touch(1, b, false)
	await _frames(2)
	_touch(0, a, false)
	await _frames(6)


func _hold(at: Vector2, seconds: float) -> void:
	_touch(0, at, true)
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(seconds * 1000.0):
		await process_frame
	_touch(0, at, false)
	await _frames(6)


func _check15(what: String, ok: bool) -> void:
	print("UX15 check %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_ux15_failures += 1


## A finger's tap on a phone, the mouse's click on a desktop.
func _press_at(at: Vector2) -> void:
	if _on_phone:
		await _tap(at)
	else:
		await _click(at)
