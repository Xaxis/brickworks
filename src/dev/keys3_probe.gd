## Colours on keys, the selections on keys, and menus that fit (APP_UX2
## keys3, gaps 2 and 8).
##
##   godot --path . --resolution 1280x720 --script src/dev/keys3_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh keys3_probe
##
## Every key is pressed as a person presses it, an input event to the
## window, and each check reads what it did to the model:
## - every menu, Make's and the app's too, and every submenu, is 25 rows or
##   fewer, and each of the menus along the top opens no taller than 60% of
##   the window, measured as palette_probe measures Edit; no command is in
##   two of them;
## - Shift-2 paints three selected parts the second favourite in one key,
##   one undo takes it back; Ctrl-Shift-1 paints them the model's most used
##   colour; a browser's Shift-2 (") and a UK keyboard's Shift-2 (@'s key
##   there) are the same key; with a part in hand a colour key is its
##   colour, and the model is not changed;
## - Alt-C, Alt-P, Alt-J and Alt-I select what Edit, Select by's Same
##   colour, Same part, Everything connected and The opposite select;
## - Keys like BrickLink Studio: the colour keys have no key, as Studio's
##   favourites have none, and Shift-V cycles the same colour, part, both
##   and all joined, then back to the part it began from;
## - favourite 1 chosen in the keys sheet (F1, its colour clicked, Sand
##   Green clicked), and the app started again on the same data folder:
##   favourite 1 is Sand Green there, and Shift-1 paints it.
##
## The data folder is the run's own (probe.sh gives one). Pictures in
## shots/keys3/, named by the window's size.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _store: ModelStore
var _sheet: ControlsDialog
var _size: String = ""

const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT
const ALT := KEY_MASK_ALT
## LDraw's Sand Green: no favourite out of the box.
const SAND_GREEN := 378


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var after_restart: bool = OS.get_cmdline_user_args().has("--after-restart")
	var own_folder: bool = _own_data_folder()
	ShellPrefs.kept_by_a_check = own_folder
	if not after_restart and DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  keys3 probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	_sheet = _main.get("_controls")
	_store.keeps = false
	await _frames(30)
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]

	if after_restart:
		await _after_restart()
	else:
		print("  a %s window" % _size)
		await _menus()
		await _colour_keys()
		await _selection_keys()
		await _studio()
		await _favourite_in_the_sheet()
		await _restart(own_folder)

	print("")
	if _failures == 0:
		print("keys3 probe: all checks passed")
	else:
		print("keys3 probe: %d check(s) FAILED" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the menus -------------------------------------------------------------------

func _menus() -> void:
	print("\n  the menus: 25 rows or fewer, and 60% of the window or less")
	var tall: float = root.get_visible_rect().size.y
	var homes: Dictionary = {}
	var ids: Array = _shell.get("_ids")
	var bar: ModelBar = _main.get("_bar")
	var buttons: Array = (_shell.get("_menus") as Array).duplicate()
	buttons.append(bar.mark)
	for button: MenuButton in buttons:
		var title: String = button.text if not button.text.is_empty() else "the app's menu"
		button.show_popup()
		await _frames(10)
		var popup: PopupMenu = button.get_popup()
		_check("%s: %d rows, %d units tall in a window of %d (at most 25 and %d)" % [title,
			popup.item_count, popup.size.y, roundi(tall), roundi(tall * 0.6)],
			popup.item_count <= 25 and popup.size.y <= tall * 0.6)
		if title in ["View", "Build", "Make", "Tools"]:
			await _shot("menu_" + title.to_lower())
		popup.hide()
		await _frames(3)
		for sub: PopupMenu in _submenus(popup):
			_check("...%s › %s: %d rows" % [title, sub.name, sub.item_count], sub.item_count <= 25)
		for sub: PopupMenu in [popup] + _submenus(popup):
			for index: int in sub.item_count:
				var id: int = sub.get_item_id(index)
				if not sub.is_item_separator(index) and id >= 0 and id < ids.size():
					homes[ids[id]] = int(homes.get(ids[id], 0)) + 1
	var twice: Array = homes.keys().filter(func(named: String) -> bool: return homes[named] > 1)
	_check("no command is in two menus (%d in them%s)" % [homes.size(),
		"" if twice.is_empty() else "; twice: " + ", ".join(twice)], twice.is_empty())
	# Where the moved rows went, as a person finds them.
	_check("Make has the minifigure, the mosaic, brickify and the print (%s)"
		% Keymap.menu_row("minifig"), Keymap.menu_row("minifig") == "Make › Minifigure builder"
		and Keymap.menu_row("print_part").begins_with("Make") and Keymap.menu_row("brickify").begins_with("Make"))
	_check("the views are in View › Viewpoint (%s), with the model's turns (%s)" % [
		Keymap.menu_row("view_front"), Keymap.menu_row("turn_left")],
		Keymap.menu_row("view_front") == "View › Viewpoint › From the front"
		and Keymap.menu_row("turn_left").begins_with("View › Viewpoint"))
	_check("the part in hand's turn is in Tools (%s), and Connect too (%s)" % [
		Keymap.menu_row("rotate_held"), Keymap.menu_row("mode_connect")],
		Keymap.menu_row("rotate_held").begins_with("Tools")
		and Keymap.menu_row("mode_connect").begins_with("Tools"))
	# The Viewpoint submenu's rows run: From the front turns the view.
	var view: PopupMenu = _shell.menu("View").get_popup()
	var point: PopupMenu = view.find_child("viewpoint", false, false) as PopupMenu
	var camera: CadCamera = _main.get("_camera")
	camera.set_view("back")
	await _frames(20)
	var was: Basis = camera.global_transform.basis
	if point != null:
		point.id_pressed.emit(_shell.menu_id("view_top"))
	await _frames(40)
	_check("View › Viewpoint › From above turns the view", point != null
		and not camera.global_transform.basis.is_equal_approx(was))


func _submenus(popup: PopupMenu) -> Array[PopupMenu]:
	var out: Array[PopupMenu] = []
	for child: Node in popup.get_children():
		if child is PopupMenu:
			out.append(child as PopupMenu)
			out.append_array(_submenus(child as PopupMenu))
	return out


# -- the colour keys -------------------------------------------------------------

func _colour_keys() -> void:
	print("\n  the colour keys")
	_check("the keys are the app's own (%s)" % Keymap.preset(), Keymap.preset() == "brickworks")
	_check("favourite 1 is Shift-1 and the model's most used Ctrl-Shift-1 (%s, %s)" % [
		Keymap.listed("favourite_1"), Keymap.listed("most_used_1")],
		Keymap.key_of("favourite_1") == SHIFT | KEY_1
		and Keymap.key_of("most_used_1") == CTRL | SHIFT | KEY_1
		and Keymap.key_of("favourite_10") == SHIFT | KEY_0)
	_main.call("clear_model")
	await _frames(4)
	# Three yellow, the model's red four.
	var three: Array = []
	for n: int in 3:
		three.append(_put("3001", 14, Vector3(-120 + n * 120, 24 * 6, 0)))
	for n: int in 4:
		_put("3003", 4, Vector3(-120 + n * 80, 24 * 6, 160))
	await _frames(4)
	var favourite: int = ColourKeys.favourites()[1]
	_select(three)
	var depth: int = _builder.history_depth()
	await _press(KEY_2, SHIFT, 34)
	_check("Shift-2 paints the three selected favourite 2, %s, in one key (%s)" % [
		_name(favourite), _colours(three)], _all(three, favourite))
	_check("...as one change (%d to %d)" % [depth, _builder.history_depth()],
		_builder.history_depth() == depth + 1)
	await _shot("painted_favourite")
	await _press(KEY_Z, CTRL)
	_check("...and one undo takes it back (%s)" % _colours(three), _all(three, 14))
	_select(three)
	await _press(KEY_1, CTRL | SHIFT, 33)
	_check("Ctrl-Shift-1 paints them the model's most used, Red (%s)" % _colours(three),
		_all(three, 4))
	await _press(KEY_Z, CTRL)
	# A browser names Shift-2 by what it makes, ", and a UK keyboard's "@"
	# key is where a US one's ' is: the digit row's place is the key.
	_select(three)
	await _press(KEY_QUOTEDBL, SHIFT, 34, KEY_2)
	_check("a browser's Shift-2 (\") is favourite 2 too (%s)" % _colours(three), _all(three, favourite))
	await _press(KEY_Z, CTRL)
	_select(three)
	await _press(KEY_AT, SHIFT, 64, KEY_3)
	_check("...and the third key of the row, whatever it makes, favourite 3 (%s)" % _colours(three),
		_all(three, ColourKeys.favourites()[2]))
	await _press(KEY_Z, CTRL)
	_check("...each taken back by one undo (%s)" % _colours(three), _all(three, 14))
	# The part in hand: its colour, and nothing on the model changes.
	_builder.clear_selection()
	(_main.get("_bin") as PartsBin).part_chosen.emit("3001")
	await _frames(6)
	var before: Dictionary = _model_colours()
	await _press(KEY_3, SHIFT, 35)
	_check("with a part in hand Shift-3 is its colour, %s (%d), and the model is as it was" % [
		_name(ColourKeys.favourites()[2]), _builder.held_color],
		_builder.held_color == ColourKeys.favourites()[2] and _model_colours() == before)
	await _press(KEY_ESCAPE)
	_verbs.set_mode("select")
	# A place the model has no colour in says so.
	_select(three)
	await _press(KEY_7, CTRL | SHIFT, 38)
	_check("Ctrl-Shift-7, with two colours in the model, paints nothing and says why: \"%s\""
		% _said(), _all(three, 14) and _said().contains("2 colours"))


# -- the selection keys ----------------------------------------------------------

func _selection_keys() -> void:
	print("\n  the selection keys select what their menu rows do")
	_main.call("clear_model")
	await _frames(4)
	# Two stacks and a brick alone: red brick on yellow, red 1x2 under a
	# yellow 1x2, and a red brick on its own.
	var a: int = _put("3001", 4, Vector3(-120, 24, 20))
	_put("3001", 14, Vector3(-120, 48, 20))
	_put("3003", 4, Vector3(60, 24, 20))
	_put("3003", 14, Vector3(60, 48, 20))
	_put("3001", 4, Vector3(220, 24, 20))
	await _frames(6)
	var sub: PopupMenu = _shell.menu("Edit").get_popup().find_child("select_by", false, false)
	for case: Array in [["select_colour", KEY_C], ["select_part", KEY_P],
			["select_connected", KEY_J], ["select_inverse", KEY_I]]:
		var named: String = case[0]
		_select([a])
		sub.id_pressed.emit(_shell.menu_id(named))
		await _frames(10)
		var by_menu: Array = _sorted(_builder.selection.keys())
		_select([a])
		await _press(case[1], ALT)
		await _frames(6)
		var by_key: Array = _sorted(_builder.selection.keys())
		_check("%s selects what Select by › %s does (%d parts: %s)" % [Keymap.listed(named),
			Keymap.words(named), by_key.size(), by_key], Keymap.key_of(named) == ALT | case[1]
			and by_key == by_menu and by_key != [a])
	# And the menu says it.
	var at: int = sub.get_item_index(_shell.menu_id("select_colour"))
	_check("Select by › Same colour shows Alt+C (%s)" % OS.get_keycode_string(sub.get_item_accelerator(at)),
		sub.get_item_accelerator(at) == ALT | KEY_C)
	_builder.clear_selection()
	await _frames(10)
	await _press(KEY_C, ALT)
	_check("Alt-C with nothing selected says what to do: \"%s\"" % _said(),
		_said().to_lower().contains("select a part first"))


# -- Studio's keys ---------------------------------------------------------------

func _studio() -> void:
	print("\n  Keys like BrickLink Studio")
	Keymap.use("studio")
	_check("the colour keys have none, as Studio's favourites (%s, %s)" % [
		Keymap.listed("favourite_1"), Keymap.listed("most_used_1")],
		Keymap.key_of("favourite_1") == 0 and Keymap.key_of("most_used_1") == 0)
	var a: int = _brick_of("3001", 4, 24)
	_select([a])
	var colours: Dictionary = _model_colours()
	await _press(KEY_1, SHIFT, 33)
	_check("...and Shift-1 paints nothing", _model_colours() == colours)
	_select([a])
	var ways: Array = []
	for _n: int in 5:
		await _press(KEY_V, SHIFT)
		await _frames(6)
		ways.append(_sorted(_builder.selection.keys()))
	var reds: Array = _sorted(_bricks(func(b: BrickWorld.Brick) -> bool: return b.color_code == 4))
	var bricks: Array = _sorted(_bricks(func(b: BrickWorld.Brick) -> bool: return b.part_id == "3001"))
	var alike: Array = _sorted(_bricks(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "3001" and b.color_code == 4))
	_check("Shift-V: the same colour (%s), the same part (%s), both (%s), all joined (%s), then the part it began from (%s)"
		% ways, ways[0] == reds and ways[1] == bricks and ways[2] == alike
		and ways[3].size() == 2 and ways[3].has(a) and ways[4] == [a])
	_check("...said on the bar: \"%s\"" % _said(), _said().contains("the parts it began from"))
	Keymap.use("brickworks")
	_check("back to the app's keys, Shift-1 is favourite 1 again (%s)" % Keymap.listed("favourite_1"),
		Keymap.key_of("favourite_1") == SHIFT | KEY_1)


# -- a favourite chosen in the sheet ---------------------------------------------

func _favourite_in_the_sheet() -> void:
	print("\n  a favourite chosen in the keys sheet")
	_builder.clear_selection()
	await _press(KEY_F1)
	await _frames(10)
	_check("F1 opens the keys sheet", _sheet.visible)
	var named: Dictionary = _sheet.controls_by_name()
	var swatch: Control = named.get("favourite_1")
	_check("favourite 1's colour is on it, %s" % (swatch.tooltip_text if swatch else "not there"),
		swatch != null)
	if swatch == null:
		return
	(_sheet.get("_keys") as ScrollContainer).ensure_control_visible(swatch)
	await _frames(6)
	await _shot("sheet_colours")
	await _click_on(swatch)
	await _frames(10)
	var green: Control = _sheet.controls_by_name().get("colour_%d" % SAND_GREEN)
	var chooser: PopupPanel = _sheet.get("_chooser")
	_check("a click on it opens the colours (%s, %d of them), Sand Green among them" % [
		"open" if chooser != null and chooser.visible else "shut",
		_sheet.controls_by_name().keys().filter(func(k: String) -> bool: return k.begins_with("colour_")).size()],
		green != null)
	if green == null:
		return
	await _shot("favourite_chooser")
	await _click_on(green)
	await _frames(6)
	var row: String = _row_words("favourite_1")
	_check("Sand Green clicked: favourite 1 is Sand Green (%d), and its row says so: \"%s\"" % [
		ColourKeys.favourites()[0], row], ColourKeys.favourites()[0] == SAND_GREEN
		and row.contains("Sand Green"))
	_check("...and the account is sent it with the keys (%s)" % str(Keymap.kept().get("colours")),
		(Keymap.kept().get("colours") as Array)[0] == SAND_GREEN)
	await _shot("favourite_set")
	await _press(KEY_ESCAPE)
	await _frames(4)
	var a: int = _brick_of("3001", 4, 24)
	_select([a])
	await _press(KEY_1, SHIFT, 33)
	_check("Shift-1 paints the selection Sand Green", _world.get_brick(a).color_code == SAND_GREEN)


func _restart(own_folder: bool) -> void:
	print("\n  the app started again")
	if not own_folder:
		_check("a data folder of this run's own to keep the favourite in (run by tools/probe.sh)", false)
		return
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/keys3_probe.gd",
		"--", "--after-restart"], output, true)
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("  ok") or line.begins_with("  FAIL"):
			print("  " + line)
	_check("a run of its own, on the same data folder, passed (exit %d)" % code, code == 0)


func _after_restart() -> void:
	_check("favourite 1 is still Sand Green (%d)" % ColourKeys.favourites()[0],
		ColourKeys.favourites()[0] == SAND_GREEN)
	_main.call("clear_model")
	await _frames(4)
	var one: int = _put("3001", 4, Vector3(0, 24 * 6, 0))
	_select([one])
	await _press(KEY_1, SHIFT, 33)
	_check("...and Shift-1 paints a selected part Sand Green (%d)" % _world.get_brick(one).color_code,
		_world.get_brick(one).color_code == SAND_GREEN)


# -- helpers ---------------------------------------------------------------------

func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _put(part: String, colour: int, at: Vector3) -> int:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _bricks(test: Callable) -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id) and test.call(b)).map(
		func(b: BrickWorld.Brick) -> int: return b.id)


func _brick_of(part: String, colour: int, y: float) -> int:
	for brick_id: int in _bricks(func(b: BrickWorld.Brick) -> bool:
			return b.part_id == part and b.color_code == colour and is_equal_approx(b.transform.origin.y, y)):
		return brick_id
	return 0


func _sorted(ids: Array) -> Array:
	var out: Array = ids.duplicate()
	out.sort()
	return out


func _all(ids: Array, colour: int) -> bool:
	return ids.all(func(id: int) -> bool: return _world.get_brick(id).color_code == colour)


func _colours(ids: Array) -> String:
	return ", ".join(ids.map(func(id: int) -> String: return str(_world.get_brick(id).color_code)))


func _model_colours() -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in _bricks(func(_b: BrickWorld.Brick) -> bool: return true):
		out[brick_id] = _world.get_brick(brick_id).color_code
	return out


func _name(code: int) -> String:
	return (_main.get("_library") as PartLibrary).color(code).name


func _said() -> String:
	return str(_shell.status.fields()["message"])


## The words of the sheet's row whose key's chip is [param action]'s.
func _row_words(action: String) -> String:
	var chip: Control = _sheet.controls_by_name().get("key_" + action)
	if chip == null:
		return ""
	var row: Node = chip.get_parent().get_parent()
	return (row.get_child(2) as Label).text if row.get_child_count() == 3 else ""


## A key and its modifiers, down and up, as the window delivers them: the
## key as the layout names it, the character it makes, and where it is on
## the keyboard ([param place], the key itself when 0).
func _press(code: int, mods: int = 0, character: int = 0, place: int = 0) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(code | mods)
		event.physical_keycode = (place if place != 0 else code) as Key
		event.unicode = character
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


## A click on [param control]'s middle, wherever it is drawn: in the
## window, or in a popup over it. The window embeds its popups, so a
## control's screen place is in the window's own units, as a popup is
## placed; the event is in the window's pixels.
func _click_on(control: Control) -> void:
	var scale: Vector2 = control.get_global_transform_with_canvas().get_scale()
	var at: Vector2 = (control.get_screen_position() + control.size * scale / 2.0) \
		* (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(named: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://shots/keys3/%s_%s.png" % [named, _size])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
