## simplereview: an independent review's attacks on Simple's live switch
## (simplep2, Main.use_controls), each held to the same act with no switch.
##
##   godot --path . --resolution 1280x720 --script src/dev/simplereview_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh simplereview_probe
##   PROBE_SIZE=390x844 tools/probe.sh simplereview_probe --case=phone,keys
##
## --case= focus, keys, dialogs, paced, starting, leak, phone (all when not said);
## --pictures=DIR keeps pictures.
##   focus     A field over both layers (Find and replace) typed into, a part
##             selected, the switch made, and the typing carried on: "01" and
##             Delete. Held to the same keys with no switch: the field keeps
##             them and no part is deleted.
##   keys      In Simple, the studio's keys that open Full's own panels:
##             Shift+C (a colour by name), then "red" and Enter. Where the
##             keys went, what a person could see, and what Full shows after.
##   dialogs   A question the bar asks (Clear the baseplate…, a name for an
##             untitled model's Save) asked in Simple and open across a switch:
##             shown, and answered.
##   paced     10030-1 moved and saved by the person's Save (paced, a bar of
##             its own), switched there and back half way: the file held to
##             the same save with no switch, byte for byte.
##   starting  10030-1's timeline asked for, and the switch made while its
##             steps are still worked out, once and three times: what is open
##             after, and the jobs left.
##   leak      6685-1's timeline on its fifth step, 20 switches there and back,
##             each waited out: on the same step, and the app's nodes, orphans
##             and the signals the switch touches counted before and after.
##   phone     (a phone) the parts sheet open, into Simple: a tap where the
##             sheet was; a part's menu asked for in Simple; back in Full, what
##             is open.
## Exits non-zero when a check fails.
extends "res://src/dev/simple_switch_probe.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("simplereview_probe: needs a window")
		quit(1)
		return
	var cases: String = "camera,focus,keys,dialogs,paced,starting,leak,phone"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			cases = arg.trim_prefix("--case=")
		if arg.begins_with("--pictures="):
			_pictures = arg.trim_prefix("--pictures=")
	_asked = cases.split(",", false)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_forget(PROBE_DIR)
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
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
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	print("simplereview_probe: a %s window, laid out for a %s" % [_size, _layout])
	if "camera" in _asked:
		await _case_camera()
	if "focus" in _asked:
		await _case_focus()
	if "keys" in _asked:
		await _case_keys()
	if "dialogs" in _asked:
		await _case_dialogs()
	if "paced" in _asked:
		await _case_paced()
	if "starting" in _asked:
		await _case_starting()
	if "leak" in _asked:
		await _case_leak()
	if "leakb" in _asked:
		await _case_leak(true)
	if "phone" in _asked and _layout == "phone":
		await _case_phone()
	if _main.call("controls_layer") != &"full":
		_main.call("use_controls", &"full")
	_forget(PROBE_DIR)
	print("\nsimplereview_probe: %d failed, %d notes" % [_failures, _notes])
	quit(1 if _failures > 0 else 0)


# -- keys as a keyboard sends them ----------------------------------------------------


func _keypress(code: Key, text: String = "", shift: bool = false) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.shift_pressed = shift
		if not text.is_empty():
			key.unicode = text.unicode_at(0)
		key.pressed = down
		Input.parse_input_event(key)
		await process_frame
	await process_frame


func _type(text: String) -> void:
	for c: String in text:
		await _keypress(OS.find_keycode_from_string(c.to_upper()), c)


func _focus_said() -> String:
	var owner: Control = root.gui_get_focus_owner()
	if owner == null:
		return "nothing"
	return "%s %s (%s)" % [owner.get_class(), owner.name, "shown" if owner.is_visible_in_tree() else "HIDDEN"]


# -- the cases ------------------------------------------------------------------------


## The camera through the switch, each part of it apart: once the view has
## come to rest after the open, and at once after it (the unit's layer case
## reads it 6 frames after the open's framing began).
func _case_camera() -> void:
	print("\ncamera: the view through the switch, %s" % _layout)
	for arm: String in ["rested", "just opened", "just opened, no switch"]:
		var rested: bool = arm == "rested"
		var switch: bool = arm != "just opened, no switch"
		# Just opened, after another model, as the layer case reads it: the
		# open's framing still easing from the model before.
		if not rested:
			await _open("res://vendor/omr/files/5972-1.mpd")
			await _settle()
		await _open(STEPPED)
		if rested:
			await _settle()
			await _frames(30)
		var was: Dictionary = _view()
		if switch:
			_main.call("use_controls", &"simple")
		await _frames(6)
		var simple: Dictionary = _view()
		if switch:
			_main.call("use_controls", &"full")
		await _frames(6)
		var back: Dictionary = _view()
		for key: String in was:
			if str(was[key]) != str(simple[key]) or str(was[key]) != str(back[key]):
				print("    %s: %s  %s -> %s -> %s" % [arm, key, was[key], simple[key], back[key]])
		var targets: Array = ["yaw", "pitch", "distance", "focus"]
		var moved := PackedStringArray()
		for key: String in targets:
			if str(was[key]) != str(simple[key]) or str(was[key]) != str(back[key]):
				moved.append(key)
		_ok(moved.is_empty(), "%s: the view's aim kept%s" % [arm,
			"" if moved.is_empty() else " (moved: %s)" % ", ".join(moved)])
		if rested:
			_ok(str(was["transform"]) == str(back["transform"]), "rested: the camera where it was, back in Full")
		else:
			_note("%s: the camera %s in those 12 frames" % [arm,
				"moved" if str(was["transform"]) != str(back["transform"]) else "held"])


func _view() -> Dictionary:
	return {"yaw": _camera.get("_target_yaw"), "pitch": _camera.get("_target_pitch"),
		"distance": _camera.get("_target_distance"), "focus": _camera.get("_target_focus"),
		"transform": _camera.global_transform, "shift": _camera.get("_shift"), "seen": _camera.seen_rect()}


## A field over both layers, typed into through the switch.
func _case_focus() -> void:
	print("\nfocus: a field over both layers typed into through the switch, %s" % _layout)
	for arm: String in ["no switch", "into Simple", "back to Full"]:
		var fresh: Array = await _fresh()
		if arm == "back to Full":
			_main.call("use_controls", &"simple")
			await _frames(3)
		_select([_small_id()])
		_main.call("_find_replace")
		await _frames(4)
		var bar: Control = _main.get("_find_replace_made")
		if bar == null or not bar.is_visible_in_tree():
			_ok(false, "%s: Find and replace open" % arm)
			continue
		var fields: Array = bar.find_children("*", "LineEdit", true, false)
		var field: LineEdit = null
		for one: LineEdit in fields:
			if one.is_visible_in_tree() and one.editable:
				field = one
				break
		if field == null:
			_ok(false, "%s: a field in Find and replace" % arm)
			continue
		field.text = ""
		field.grab_focus()
		await _frames(2)
		await _type("30")
		var picked: Array = _builder.selection.keys()
		if arm == "into Simple":
			_main.call("use_controls", &"simple")
			await _frames(3)
		elif arm == "back to Full":
			_main.call("use_controls", &"full")
			await _frames(3)
		var focus: String = _focus_said()
		await _type("01")
		await _keypress(KEY_DELETE)
		await _frames(4)
		# The model's own parts, the baseplate not among them (_records_all).
		var count: int = _records_all().size()
		var small_there: bool = not picked.is_empty() and _world.get_brick(int(picked[0])) != null
		print("    %s: the field says \"%s\", focus %s, parts %d of %d, the selected 2 x 2 %s, undo depth %d"
			% [arm, field.text, focus, count, fresh.size(), "there" if small_there else "GONE",
			_builder.history_depth()])
		_ok(bar.is_visible_in_tree(), "%s: Find and replace still up" % arm)
		_ok(field.text.begins_with("3001"), "%s: the typing went on into the field (\"%s\")"
			% [arm, field.text])
		_ok(count == fresh.size() and small_there, "%s: Delete deleted no part (%d of %d; the 2 x 2 %s)"
			% [arm, count, fresh.size(), "there" if small_there else "GONE"])
		bar.visible = false
		root.gui_release_focus()
		if _main.call("controls_layer") != &"full":
			_main.call("use_controls", &"full")
			await _frames(3)


## The studio's keys that open its own panels, pressed in Simple.
func _case_keys() -> void:
	print("\nkeys: Full's own panels asked for by keys in Simple, %s" % _layout)
	await _fresh()
	var dock: SideDock = _main.get("_bin_dock")
	var was_open: bool = dock.is_open()
	var colour: int = _builder.held_color
	_main.call("use_controls", &"simple")
	await _frames(3)
	await _keypress(KEY_C, "C", true)
	await _frames(4)
	var focus: String = _focus_said()
	print("    Shift+C in Simple: focus %s; the parts column %s" % [focus, "open" if dock.is_open() else "shut"])
	var owner: Control = root.gui_get_focus_owner()
	_ok(owner == null or owner.is_visible_in_tree(), "Shift+C in Simple: the keys go nowhere a person cannot see (%s)" % focus)
	await _type("red")
	await _keypress(KEY_ENTER)
	await _frames(4)
	print("    then \"red\" and Enter: the colour in hand %d (was %d), focus %s" % [_builder.held_color, colour,
		_focus_said()])
	await _picture("simple-after-shift-c")
	root.gui_release_focus()
	_main.call("use_controls", &"full")
	await _frames(4)
	print("    back in Full: the parts column %s (was %s)" % ["open" if dock.is_open() else "shut",
		"open" if was_open else "shut"])
	_note("keys: back in Full the parts column is %s, %s before Simple" % ["open" if dock.is_open() else "shut",
		"open" if was_open else "shut"])
	await _picture("full-after-shift-c")
	if dock.is_open() != was_open:
		dock.set_open(was_open)
	# The first acts' Add parts, which the notices strip carries into Simple.
	_main.call("use_controls", &"simple")
	await _frames(3)
	_main.call("_first_add")
	await _frames(4)
	var after_add: Control = root.gui_get_focus_owner()
	print("    the first acts' Add parts in Simple: focus %s" % _focus_said())
	_ok(after_add == null or after_add.is_visible_in_tree(),
		"Add parts (the first acts, in Simple's strip): the keys go nowhere a person cannot see (%s)" % _focus_said())
	root.gui_release_focus()
	_main.call("use_controls", &"full")
	await _frames(3)
	if dock.is_open() != was_open:
		dock.set_open(was_open)


## A question the bar asks, in Simple and across the switch.
func _case_dialogs() -> void:
	print("\ndialogs: the bar's questions and the switch, %s" % _layout)
	var fresh: Array = await _fresh()
	var bar: ModelBar = _main.get("_bar")
	var clear: AcceptDialog = bar.get("_confirm")
	# Asked in Full, then the switch.
	bar.call("_ask_to_clear")
	await _frames(4)
	_ok(clear.visible, "Clear the baseplate… asked in Full")
	_main.call("use_controls", &"simple")
	await _frames(4)
	_ok(clear.visible, "into Simple: the question still up")
	await _picture("simple-clear-asked")
	clear.get_cancel_button().pressed.emit()
	await _frames(4)
	_ok(not clear.visible, "cancelled in Simple")
	_exact("the model as it was", fresh, _records_all())
	# Asked in Simple.
	bar.call("_ask_to_clear")
	await _frames(4)
	_ok(clear.visible, "Clear the baseplate… asked in Simple: up")
	await _picture("simple-clear-in-simple")
	_main.call("use_controls", &"full")
	await _frames(4)
	_ok(clear.visible, "back to Full: the question still up")
	clear.get_cancel_button().pressed.emit()
	await _frames(4)
	_exact("cancelled: the model as it was", fresh, _records_all())
	# An untitled model's Save asks its name: in Simple.
	_main.call("use_controls", &"simple")
	await _frames(3)
	var asking: AcceptDialog = bar.get("_ask_name")
	var field: LineEdit = bar.get("_ask_name_field")
	var saving: Array = [null]
	var run := func() -> void: saving[0] = await bar._on_save()
	run.call()
	await _frames(6)
	_ok(asking.visible, "Save in Simple, the model untitled: its name asked (%s)" % ("up" if asking.visible else "not up"))
	await _picture("simple-save-asks-name")
	if asking.visible:
		field.text = "Simplereview"
		asking.get_ok_button().pressed.emit()
		for _n: int in 300:
			if saving[0] != null:
				break
			await process_frame
		_ok(bool(saving[0]), "named and saved in Simple: %s" % saving[0])
	_main.call("use_controls", &"full")
	await _frames(3)


## 10030-1 saved by the person's Save, the switch made half way.
func _case_paced() -> void:
	print("\npaced: the person's Save of 10030-1, the switch half way, %s" % _layout)
	var texts: Array = []
	for switch: bool in [false, true]:
		# The same file name either side: the model's name is the file's.
		var copy: String = PROBE_DIR + ("paced-%s/" % ("switched" if switch else "plain")) + SET.get_file()
		DirAccess.make_dir_recursive_absolute(copy.get_base_dir())
		_write(ProjectSettings.globalize_path(copy), _text_of(SET))
		await _open(copy)
		var bar: ModelBar = _main.get("_bar")
		var moving: BrickWorld.Brick = _placed_once()
		if moving == null or not await _moved(moving):
			_ok(false, "paced: a part moved")
			return
		var saving: Array = [null]
		var run := func() -> void: saving[0] = await bar._on_save()
		run.call()
		var frames: int = 0
		var switched: int = 0
		var paced: bool = bar.get("_saving") != null
		# The save's bar is up and waits a frame to be shown: the switch made
		# in that frame and every frame after while the save is under way.
		if switch and saving[0] == null:
			_main.call("use_controls", &"simple")
			switched += 1
		while saving[0] == null and frames < 20000:
			await process_frame
			frames += 1
			if bar.get("_saving") != null:
				paced = true
			if switch and saving[0] == null and switched < 6:
				_main.call("use_controls", &"simple" if switched % 2 == 0 else &"full")
				switched += 1
		if _main.call("controls_layer") != &"full":
			_main.call("use_controls", &"full")
		await _frames(3)
		var at: String = str(_store.get("_saved_as"))
		var known: String = str(_store.get("_known_path"))
		print("    %s: saved %s in %d frames, paced %s, switched %d times; at %s / %s" % [
			"switched" if switch else "plain", saving[0], frames, paced, switched, at, known])
		_ok(bool(saving[0]), "%s: saved" % ("switched" if switch else "plain"))
		var path: String = at if not at.is_empty() and FileAccess.file_exists(at) else known
		texts.append(_text_of(path) if FileAccess.file_exists(path) else "")
		# Out of the way of the next arm's save under the same name.
		if not switch and path.begins_with(ModelStore.SAVE_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if switch:
			_ok(switched >= 1, "the switch made while the save was under way (%d times)" % switched)
	_ok(texts.size() == 2 and not str(texts[0]).is_empty() and texts[0] == texts[1],
		"saved with switches under way: byte for byte the save with none (%d bytes against %d)"
		% [str(texts[1]).length() if texts.size() == 2 else -1, str(texts[0]).length() if texts.size() > 0 else -1])


## The timeline asked for, and the switch while its steps are worked out.
func _case_starting() -> void:
	print("\nstarting: the switch while the timeline's steps are worked out, %s" % _layout)
	await _open(SET)
	for times: int in [1, 3]:
		if _steps.is_playing_back():
			_steps.stop()
			await _frames(3)
		_main.call("_toggle_steps")
		await _frames(2)
		var starting: bool = _steps.is_starting()
		for n: int in times:
			_main.call("use_controls", &"simple")
			await _frames(1)
			_main.call("use_controls", &"full")
			await _frames(1)
		for _n: int in 3000:
			if not _steps.is_starting() and Working._jobs.is_empty():
				break
			await process_frame
		await _frames(30)
		print("    %d round trips while starting (%s): timeline %s, starting %s, jobs %d" % [times, starting,
			"open" if _steps.is_playing_back() else "shut", _steps.is_starting(), Working._jobs.size()])
		_ok(Working._jobs.is_empty(), "%d round trips while starting: no job left (%d)" % [times, Working._jobs.size()])
		_note("starting: %d round trips while its steps were worked out: the timeline asked for is %s after"
			% [times, "open" if _steps.is_playing_back() else "SHUT"])
	if _steps.is_playing_back():
		_steps.stop()
		await _frames(3)


## 20 switches there and back with the timeline on a step.
## by_key: the timeline put away and opened again by its own key (B) in place of
## the switch, which does the same to it: what the studio did before Simple.
func _case_leak(by_key: bool = false) -> void:
	var how: String = "B pressed twice" if by_key else "switches there and back"
	print("\nleak%s: 20 then 40 %s, the timeline on a step, %s" % ["b" if by_key else "", how, _layout])
	await _open(STEPPED)
	await _main.call("_toggle_steps")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	for _n: int in 4:
		_steps.step_forward()
		await _frames(2)
	var at: Instructions.Step = _steps.current_step()
	var number: int = at.number if at != null else -1
	# One first, to make Simple's layer.
	await _there_and_back(by_key)
	var before: Dictionary = _counts()
	var opened: Array = _records_all()
	for _n: int in 20:
		await _there_and_back(by_key)
	await _frames(30)
	var after: Dictionary = _counts()
	var back: Instructions.Step = _steps.current_step()
	_ok(_steps.is_playing_back() and back != null and back.number == number,
		"after 20: the timeline on step %d (%d)" % [number, back.number if back != null else -1])
	_exact("after 20: the model as it was", opened, _records_all())
	for _n: int in 20:
		await _there_and_back(by_key)
	await _frames(30)
	var later: Dictionary = _counts()
	print("    counts before %s" % [before])
	print("    counts after 20 %s" % [after])
	print("    counts after 40 %s" % [later])
	for pair: Array in [["after 20", before, after], ["20 more", after, later]]:
		var was: Dictionary = pair[1]
		var now: Dictionary = pair[2]
		var grew := PackedStringArray()
		# Left behind is more after than before: fewer objects is the engine's
		# own freeing, and notices_at is where the strip stands, kept exactly.
		for key: String in was:
			if int(now[key]) > int(was[key]) or (key == "notices_at" and int(now[key]) != int(was[key])):
				grew.append("%s %d -> %d" % [key, was[key], now[key]])
		_ok(grew.is_empty(), "%s (%s): nothing left behind%s" % [pair[0], how,
			"" if grew.is_empty() else " (%s)" % ", ".join(grew)])
	_steps.stop()
	await _frames(3)


func _there_and_back(by_key: bool) -> void:
	if by_key:
		await _main.call("_toggle_steps")
		await _frames(2)
		await _main.call("_toggle_steps")
	else:
		_main.call("use_controls", &"simple")
		await _frames(2)
		_main.call("use_controls", &"full")
	await _wait_timeline()


func _wait_timeline() -> void:
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(2)


func _counts() -> Dictionary:
	var notices: Control = _main.get("_notices")
	var notes: Node = notices.get_child(0)
	var linked: int = 0
	for note: Node in notes.get_children():
		linked += (note as Control).visibility_changed.get_connections().size()
	var reveal: int = _world.reveal_ended.get_connections().size()
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects_k": int(Performance.get_monitor(Performance.OBJECT_COUNT) / 1000),
		"notes_linked": linked, "reveal_ended": reveal,
		"loaded": _store.loaded.get_connections().size(), "begun": _store.begun.get_connections().size(),
		"notices_at": notices.get_index(), "hud": (_main.get_node("HUD") as Node).get_child_count(),
		"jobs": Working._jobs.size()}


## A phone's sheets and the switch.
func _case_phone() -> void:
	print("\nphone: the phone's sheets and the switch")
	var fresh: Array = await _fresh()
	var phone: Control = _main.get("_phone")
	phone.call("_chose", "parts")
	await _frames(10)
	var state_before: Dictionary = phone.call("state")
	print("    the parts sheet asked for: %s" % [state_before])
	_main.call("use_controls", &"simple")
	await _frames(4)
	# A tap in the middle of the window's lower half, where the sheet was.
	var where: Vector2 = Vector2(root.get_visible_rect().size.x * 0.5, root.get_visible_rect().size.y * 0.8)
	var over: bool = bool(_main.call("_over_panel_at", where))
	print("    in Simple, %s is %s" % [where, "the interface's" if over else "the model's"])
	_ok(not over, "in Simple, where the sheet was is the model's")
	_main.call("use_controls", &"full")
	await _frames(6)
	var state_back: Dictionary = phone.call("state")
	print("    back in Full: %s" % [state_back])
	_ok(str(state_back.get("sheet", "")) == str(state_before.get("sheet", "")), "back in Full: the same sheet open (%s, was %s)"
		% [state_back.get("sheet", ""), state_before.get("sheet", "")])
	phone.call("_chose", "parts")
	await _frames(6)
	# A part's menu asked for in Simple (the right button, as a mouse on a
	# phone's layout or a pen gives it).
	_main.call("use_controls", &"simple")
	await _frames(3)
	_camera.frame(_main.call("_built_bounds"))
	await _settle()
	var on: Vector2 = _point_on(_small_id())
	if on.x < INF:
		_main.call("_right_click", on)
		await _frames(6)
		var in_simple: Dictionary = phone.call("state")
		print("    a part's menu asked for in Simple: %s" % [in_simple])
		_ok(str(in_simple.get("sheet", "")).is_empty(), "a part's menu in Simple opens nothing a person cannot see (%s)"
			% in_simple.get("sheet", ""))
		_main.call("use_controls", &"full")
		await _frames(6)
		var after: Dictionary = phone.call("state")
		print("    back in Full: %s" % [after])
		_ok(str(after.get("sheet", "")).is_empty(), "back in Full, no menu the person never saw asked for (%s)"
			% after.get("sheet", ""))
		await _picture("full-after-context-in-simple")
	_exact("the model as it was", fresh, _records_all())
	if _main.call("controls_layer") != &"full":
		_main.call("use_controls", &"full")
		await _frames(3)
