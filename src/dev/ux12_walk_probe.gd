## Five people's first use of the app, pictured step by step (unit ux12,
## bench/results/ux12-2026-11-23/WALK.md): a first-time visitor who wants a
## car, a LEGO® fan rebuilding a set from its number (6080-1), a Technic
## builder wiring a motor, a parent printing instructions, and someone
## remixing a model. Research, not in the suite: it checks nothing and exits
## 0 once every step is pictured, 1 when the app never came up.
##
##   godot --path . --resolution 1280x800 --script src/dev/ux12_walk_probe.gd -- [--phone] [--pictures=DIR] [--only=p1,p2]
##
## --phone lays the app out for a phone at a browser's scale, by fingers, as
## phonepanels_probe holds it (run it in a 390x844 window). Each step prints
## one line: what share of the model's room is covered and by what
## (Main.model_cover), the status bar's words, the windows and sheets open,
## and on a phone every control in sight under a fingertip (Phone.TARGET).
## Pictures in --pictures=DIR (else user://ux12_walk), named by step.
extends SceneTree

const SET := "omr-6080-1"

var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _shell: Shell
var _store: ModelStore
var _bin: PartsBin
var _bar: ModelBar
var _phone: Node
var _on_phone: bool = false
var _out: String = "user://ux12_walk"
var _only: PackedStringArray = []
var _steps: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()
	# Never left running: a step that hangs is cut off and the run says so.
	create_timer(1500.0).timeout.connect(func() -> void:
		print("UX12 cut off after 1500 s at step %d" % _steps)
		quit(2))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ux12_walk_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			_out = arg.trim_prefix("--pictures=")
		elif arg == "--phone":
			_on_phone = true
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if _on_phone:
		Phone._on = 1
		Phone._wide = false
		Input.emulate_touch_from_mouse = true
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	if not bool(_main.get("_built")):
		print("ux12_walk_probe: the app never came up")
		quit(1)
		return
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
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
	_store.keeps = false
	var size: Vector2i = DisplayServer.window_get_size()
	print("UX12 walk in a %d x %d window%s" % [size.x, size.y, ", laid out for a phone"
		if _on_phone else ""])
	await _frames(60)
	if _runs("p1"):
		await _visitor()
	if _runs("p2"):
		await _fan()
	if _runs("p3"):
		await _technic()
	if _runs("p4"):
		await _parent()
	if _runs("p5"):
		await _remixer()
	await _checks()
	print("UX12 done: %d steps pictured, %d check(s) failed" % [_steps, _failures])
	quit(0)


## The fixes judged in the app as it runs, one "UX12 check" line each: run
## on the code before them, these are the frictions; after, the fixes.
func _checks() -> void:
	print("\nUX12 checks")
	if _on_phone and _phone != null:
		var buttons: Dictionary = _phone.get("_tool_buttons")
		var bare: Array = []
		for tool: Array in PhoneShell.TOOLS:
			var button: Button = buttons.get(str(tool[0]))
			if button != null and button.text.is_empty():
				bare.append(str(tool[1]))
		_check("the phone row says its words (bare: %s)" % ", ".join(bare), bare.is_empty())
	var maker: Shell.Command = _shell.command("part_maker")
	_check("Make's row names the part maker as the bin does (%s)" % maker.words,
		maker.words == "Make a part…")
	var flex: Shell.Command = _shell.command("flex")
	_check("the flex tool is named for a cable (%s)" % flex.words, flex.words.begins_with("Cable"))
	_check("Instructions under File, Export", (Shell.SUBMENUS["export"] as Array).has("instructions"))
	var clear: ConfirmationDialog = _bar.get("_confirm")
	_check("Clear it is red (%s)" % clear.get_ok_button().theme_type_variation,
		clear.get_ok_button().theme_type_variation == &"DangerButton")
	var dialog: Node = _shell.get("library_dialog")
	dialog.call("open", "sets")
	await _frames(20)
	var search: LineEdit = dialog.get("_search")
	var shown: String = search.placeholder_text
	var font: Font = search.get_theme_font("font")
	var room: float = search.size.x - search.get_theme_stylebox("normal").get_minimum_size().x \
		- (search.right_icon.get_width() if search.right_icon != null else 0)
	var needs: float = font.get_string_size(search.tr(shown), HORIZONTAL_ALIGNMENT_LEFT, -1,
		search.get_theme_font_size("font_size")).x
	_check("Library's search says it takes a set's number, whole (%s: %.0f of %.0f)" % [shown,
		needs, room], shown.begins_with("Set number") and needs <= room)
	await _close_all()
	_bar.call("_on_open")
	await _frames(10)
	var saves: PopupMenu = _bar.get("_saves")
	var first: String = saves.get_item_text(0) if saves.item_count > 0 else ""
	_check("Open's first row: %s" % first, first.begins_with("From a file ("))
	saves.hide()
	await _frames(5)


func _check(what: String, ok: bool) -> void:
	print("UX12 check %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _runs(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


# -- 1. a first-time visitor who wants a car --------------------------------------


func _visitor() -> void:
	print("\nUX12 p1: a first-time visitor who wants a car")
	await _step("p1_01_first_open", "the app as it first opens")
	await _menu("Help", "p1_02_help_menu", "where to start: the Help menu")
	await _run_command("tour", "p1_03_tour", "Help, Take the tour", 90)
	await _close_all()
	await _run_command("panel_assistant", "p1_04_assistant", "the assistant, asked for a car", 60)
	await _close_all()
	await _run_command("panel_assistant", "", "", 10)
	await _run_command("new", "p1_05_new", "File, New: an empty baseplate", 60)
	await _search_bin("car", "p1_06_bin_car", "the parts bin's search: car")
	await _search_bin("wheel", "p1_07_bin_wheel", "the parts bin's search: wheel")
	await _library("car", "sets", "p1_08_library_car", "File, Library: car")
	await _close_all()


# -- 2. a LEGO fan rebuilding a set from its number -------------------------------


func _fan() -> void:
	print("\nUX12 p2: a LEGO fan rebuilding %s from its number" % SET)
	await _search_bin("6080", "p2_01_bin_6080", "the set's number in the parts bin's search")
	await _library("6080", "sets", "p2_02_library_6080", "File, Library: 6080")
	await _close_all()
	# As a new window opens it (?library=): not awaited, so a question over
	# work not saved is answered Don't save here rather than waited on.
	_main.set("_from_library", SET)
	_main.call("_maybe_open_library")
	for _n: int in 120:
		await process_frame
		var asking: Variant = _bar.get("_confirm_open")
		if asking is Window and (asking as Window).visible:
			print("UX12 p2: asked to save what was there first; answered Don't save")
			(asking as Window).hide()
			_bar.emit_signal("_replace_answered", "discard")
			break
	await _until_still(240)
	await _step("p2_03_set_open", "the set opened, as Library's Open opens it")
	await _run_command("instructions", "p2_04_instructions", "File, Instructions", 120)
	await _close_all()
	await _run_command("step_next", "p2_05_step_next", "the next step", 30)
	await _run_command("parts_list", "p2_06_parts_list", "View, Parts list", 60)
	await _close_all()
	await _run_command("collection_need", "p2_07_need", "What do I need?", 60)
	await _close_all()


# -- 3. a Technic builder wiring a motor --------------------------------------------


func _technic() -> void:
	print("\nUX12 p3: a Technic builder wiring a motor")
	_main.call("clear_model")
	await _frames(30)
	await _search_bin("motor", "p3_01_bin_motor", "the parts bin's search: motor")
	await _take_first_tile("p3_02_motor_in_hand", "the first motor tile pressed")
	await _put_down(Vector3(-40, 0, 0), "p3_03_motor_down", "the motor put on the baseplate")
	await _search_bin("battery box", "p3_04_bin_battery", "the parts bin's search: battery box")
	await _take_first_tile("", "")
	await _put_down(Vector3(80, 0, 0), "p3_05_battery_down", "the battery box put down")
	await _search_bin("cable", "p3_06_bin_cable", "the parts bin's search: cable")
	await _search_bin("wire", "p3_07_bin_wire", "the parts bin's search: wire")
	await _run_command("flex", "p3_08_flex", "Make, Cable, hose or chain", 60)
	await _close_all()
	await _run_command("simulate", "p3_09_simulate", "Tools, Simulate mechanism", 90)
	await _close_all()


# -- 4. a parent printing instructions ----------------------------------------------


func _parent() -> void:
	print("\nUX12 p4: a parent printing instructions")
	await _open_model("res://models/car.ldr", "Car")
	await _step("p4_01_car", "the car open")
	await _menu("File", "p4_02_file_menu", "where printing would be: File")
	await _run_command("instructions", "p4_03_instructions", "File, Instructions", 150)
	await _step("p4_04_instructions_later", "the instructions a moment later")
	await _run_command("booklet_page_setup", "p4_05_page_setup", "Page setup", 60)
	await _close_all()
	await _close_all()


# -- 5. remixing a model from the gallery ----------------------------------------------


func _remixer() -> void:
	print("\nUX12 p5: remixing a model from the gallery")
	await _library("", "community", "p5_01_library_community", "File, Library, Community")
	await _close_all()
	await _open_model("res://models/house.ldr", "House")
	_store.remixed_from = "abcdefgh"
	await _step("p5_02_copy_open", "a copy of someone's model open")
	await _run_command("panel_properties", "p5_03_properties", "Properties: whose it was", 40)
	await _run_command("save", "p5_04_saved", "File, Save", 60)
	await _close_all()
	await _run_command("share", "p5_05_share", "File, Share", 60)
	await _close_all()


# -- acts ------------------------------------------------------------------------------


func _run_command(name: String, shot: String, what: String, frames: int) -> void:
	if _shell.command(name) == null:
		print("UX12 %s: no command %s" % [shot, name])
		return
	if not _shell.can(name):
		print("UX12 %s: %s greyed" % [shot, name])
		if not shot.is_empty():
			await _step(shot, what + " (greyed)")
		return
	_shell.run(name)
	await _frames(frames)
	if not shot.is_empty():
		await _step(shot, what)


func _menu(title: String, shot: String, what: String) -> void:
	if _on_phone:
		var more: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_more")
		if more is Control:
			await _tap((more as Control).get_global_rect().get_center())
			await _frames(30)
			await _step(shot, what + " (More)")
		await _close_all()
		return
	for menu: MenuButton in _shell.get("_menus"):
		if menu.text == title:
			menu.show_popup()
			await _frames(20)
			await _step(shot, what)
			menu.get_popup().hide()
			await _frames(5)


func _search_bin(words: String, shot: String, what: String) -> void:
	var dock: SideDock = _main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
		await _frames(20)
	if _on_phone:
		var parts: Variant = (_phone.call("controls_by_name") as Dictionary).get("phone_parts")
		if parts is Control and _phone_sheet() != "Parts":
			await _tap((parts as Control).get_global_rect().get_center())
			await _frames(30)
	var search: LineEdit = _bin.get("_search")
	search.grab_focus()
	search.text = words
	search.text_changed.emit(words)
	await create_timer(0.6).timeout
	await _frames(20)
	if not shot.is_empty():
		var grid: GridContainer = _bin.get("_grid")
		var first: Array = []
		for n: int in mini(6, grid.get_child_count()):
			var tile: Node = grid.get_child(n)
			first.append(str(tile.get_meta("part", tile.get_meta("key", "?"))))
		print("UX12 %s first tiles: %s" % [shot, ", ".join(first)])
		await _step(shot, what)


func _take_first_tile(shot: String, what: String) -> void:
	var grid: GridContainer = _bin.get("_grid")
	for tile: Node in grid.get_children():
		var control := tile as Control
		if control != null and control.is_visible_in_tree() and tile.has_meta("part"):
			if _on_phone:
				await _tap(control.get_global_rect().get_center())
			else:
				await _click(control.get_global_rect().get_center())
			await _frames(10)
			break
	print("UX12 in hand: %s" % _builder.is_carrying())
	if not shot.is_empty():
		await _step(shot, what)


func _put_down(at: Vector3, shot: String, what: String) -> void:
	if _on_phone and _phone_sheet() != "":
		var done: Variant = (_phone.call("controls_by_name") as Dictionary).get(
			"phone_sheet_" + _phone_sheet().to_lower().replace(" ", "_") + "_done")
		if done is Control:
			await _tap((done as Control).get_global_rect().get_center())
			await _frames(20)
	var spot: Vector2 = _camera.unproject_position(at + Vector3(0, 8, 0))
	if _on_phone:
		await _tap(spot)
	else:
		await _move(spot)
		await _move(spot + Vector2(1, 0))
		await _click(spot + Vector2(1, 0))
		await _key(KEY_ESCAPE)
	await _frames(20)
	print("UX12 parts now: %d" % _world.bricks().size())
	if not shot.is_empty():
		await _step(shot, what)


func _library(words: String, source: String, shot: String, what: String) -> void:
	var dialog: Node = _shell.get("library_dialog")
	dialog.call("open", source)
	await _frames(30)
	var search: Variant = dialog.get("_search")
	if search is LineEdit and not words.is_empty():
		var field := search as LineEdit
		field.text = words
		field.text_changed.emit(words)
	for _n: int in 40:
		await create_timer(0.25).timeout
	await _step(shot, what)


func _open_model(path: String, name: String) -> void:
	await _close_all()
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
	var result: Dictionary = await _bar.open_text_with_progress(text, name)
	# As every open of the app's says it, so the view frames it (Main).
	_bar.opened.emit(int(result.get("placed", 0)))
	await _until_still(120)


# -- what each step sees -------------------------------------------------------------


func _step(shot: String, what: String) -> void:
	_steps += 1
	await _frames(6)
	var cover: Dictionary = _main.call("model_cover", 24, 16)
	var covered: Array = cover["covered"]
	var by: Dictionary = {}
	for point: Dictionary in covered:
		by[str(point["by"])] = int(by.get(str(point["by"]), 0)) + 1
	var by_words: Array = []
	for name: String in by:
		by_words.append("%s %d" % [name, by[name]])
	var status: StatusBar = _shell.get("status")
	var said: String = status.message.text if status != null and status.message != null else ""
	var windows: Array = []
	for window: Window in _windows(root):
		if window.visible:
			windows.append(window.title if not window.title.is_empty() else str(window.name))
	print("UX12 step %s | %s | covered %d%% (%s) | status: %s | windows: %s%s" % [shot, what,
		roundi(100.0 * covered.size() / maxf(1.0, float(cover["samples"]))), ", ".join(by_words),
		said.replace("\n", " "), ", ".join(windows), (" | sheet: " + _phone_sheet())
		if _on_phone else ""])
	if _on_phone:
		var small: Array = _small_targets()
		print("UX12 small %s: %d under %d points%s" % [shot, small.size(), int(Phone.TARGET),
			(": " + ", ".join(small.slice(0, 40))) if not small.is_empty() else ""])
	await _shot(shot)


## Every control a finger presses, in sight, under a fingertip across or down.
func _small_targets() -> Array:
	var out: Array = []
	var pt: float = Phone.per_point(root)
	_small_in(root, pt, out)
	return out


func _small_in(node: Node, pt: float, out: Array) -> void:
	for child: Node in node.get_children(true):
		if child is Window and not (child as Window).visible:
			continue
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		var control := child as Control
		if control != null and (control is BaseButton or control is LineEdit or control is Range
				and not control is ScrollBar and not control is ProgressBar) \
				and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and control.is_visible_in_tree() and _in_sight(control):
			var size: Vector2 = control.get_global_rect().size / pt
			if minf(size.x, size.y) < Phone.TARGET - 0.5:
				out.append("%s %.0fx%.0f" % [_name(control), size.x, size.y])
		_small_in(child, pt, out)


func _name(control: Control) -> String:
	var words: String = ""
	if control is Button:
		words = (control as Button).text
	elif control is LineEdit:
		words = (control as LineEdit).placeholder_text
	if words.is_empty():
		words = control.tooltip_text.get_slice("\n", 0).left(30)
	if words.is_empty():
		words = str(control.name)
	return "[%s]" % words.left(30)


func _in_sight(control: Control) -> bool:
	var clip: Rect2 = root.get_visible_rect()
	var up: Node = control.get_parent()
	while up != null and up is Control:
		if up is ScrollContainer or (up as Control).clip_contents:
			clip = clip.intersection((up as Control).get_global_rect())
		up = up.get_parent()
	return clip.grow(1.0).encloses(control.get_global_rect())


func _phone_sheet() -> String:
	if _phone == null or not _phone.has_method("state"):
		return ""
	return str((_phone.call("state") as Dictionary).get("sheet", ""))


func _close_all() -> void:
	for panel_name: String in ["library_dialog", "collection"]:
		var panel: Variant = _shell.get(panel_name)
		if panel is CanvasItem and (panel as CanvasItem).visible:
			(panel as CanvasItem).hide()
	for window: Window in _windows(root):
		if window != root and window.visible:
			window.hide()
	if _on_phone and _phone != null:
		for _n: int in 3:
			var sheet: String = _phone_sheet()
			if sheet.is_empty():
				break
			var done: Variant = (_phone.call("controls_by_name") as Dictionary).get(
				"phone_sheet_" + sheet.to_lower().replace(" ", "_") + "_done")
			if done is BaseButton:
				(done as BaseButton).pressed.emit()
			await _frames(15)
	await _key(KEY_ESCAPE)
	await _frames(10)
	var finder: Variant = _main.get("_find_replace_made")
	if finder is Control and (finder as Control).visible:
		(finder as Control).hide()
	var first: Variant = _shell.get("first_build")
	if first is Node and (first as Node).has_method("stop"):
		(first as Node).call("stop")
	await _frames(10)


func _windows(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		if child is Window:
			out.append(child)
		out.append_array(_windows(child))
	return out


func _until_still(most: int) -> void:
	var last: int = -1
	var same: int = 0
	for _n: int in most:
		await _frames(5)
		var now: int = _world.bricks().size()
		if now == last and (_store.awaited.is_empty()):
			same += 1
			if same >= 6:
				break
		else:
			same = 0
		last = now
	await _frames(30)


# -- input ------------------------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _tap(at: Vector2) -> void:
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await _frames(3)
	await _frames(6)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	if name.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("UX12 picture %s" % path)
