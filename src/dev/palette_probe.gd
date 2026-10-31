## Find a command by typing (CommandPalette), the menus that hold each
## command once, and the menu on a part (appux371 A9, A7, A8).
##
##   godot --path . --resolution 1280x720 --script src/dev/palette_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh palette_probe
##
## Every key here is an input event against the real window:
##
## - Ctrl+/ opens the box over the model with the keys in it. Every
##   command in the shell's table is found by typing its words, reached
##   with Down and run with Return: the box hands it to Shell.run, as its
##   menu row does (a stand-in records it, so nothing opens a file dialog,
##   a browser or the network), and its row says its key and its menu. One
##   that cannot be used now is in the list greyed, says why, and Return
##   runs nothing.
## - Render opens for real in five key presses: Ctrl+/, R, E, N, Return.
## - A part's number lists the part: "3001" and Return take it into hand.
## - Words, not just the start of a name: "same colour", "colour same",
##   "turn left", "xray", "export picture", "lock". The recent first.
## - Ctrl+Shift+P opens it too; the app's menu has Find a command… with its
##   key; Escape puts it away and the keys go back to the model.
## - No command is in two of the menus; Edit is at most 25 rows and fits in
##   60% of the window; Help is Keys and the tour.
## - The menu on a part holds Duplicate, Replace, the same part and colour,
##   the moves a step earlier and later and the swing on a hinge, each with
##   its key, and each runs from there.
##
## Pictures in shots/palette/, named by the window's size.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _palette: CommandPalette
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
## What the palette handed to be run, while the stand-in is in.
var _ran: Array[String] = []
var _size: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# The assistant on, so its commands are in the palette and the menus too.
	ShellPrefs.put("assistant", "on")
	ShellPrefs.put("assistant_offered", true)
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	_shell = _main.get("_shell")
	_palette = _shell.palette
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	var bar: ModelBar = _main.get("_bar")
	var placed: int = await bar.open_with_progress("res://models/car.ldr")
	bar.opened.emit(placed)
	await _frames(60)
	print("palette probe at %s, the car's %d parts" % [_size, placed])
	await _menus()
	await _render_by_keys()
	await _words()
	await _greyed()
	await _a_part()
	await _every_command()
	await _part_menu()
	if _failures == 0:
		print("palette probe: all checks passed")
	else:
		print("palette probe: %d checks failed" % _failures)
	_world.clear()
	await _frames(6)
	quit(1 if _failures > 0 else 0)


## A7: each command in one menu; Edit short enough to read; Help two rows;
## the app's menu has Find a command with its key.
func _menus() -> void:
	var homes: Dictionary = {}
	var popups: Array[PopupMenu] = [(_main.get("_bar") as ModelBar).mark.get_popup()]
	for button: MenuButton in _shell.get("_menus"):
		popups.append(button.get_popup())
	var ids: Array = _shell.get("_ids")
	for popup: PopupMenu in popups:
		for sub: PopupMenu in [popup] + _submenus(popup):
			for index: int in sub.item_count:
				var id: int = sub.get_item_id(index)
				if sub.is_item_separator(index) or id < 0 or id >= ids.size():
					continue
				var named: String = ids[id]
				homes[named] = int(homes.get(named, 0)) + 1
	var twice: Array = homes.keys().filter(func(named: String) -> bool: return homes[named] > 1)
	_check("no command is in two menus (%d commands in the menus%s)" % [homes.size(),
		"" if twice.is_empty() else "; twice: " + ", ".join(twice)], twice.is_empty() and homes.size() > 150)
	var edit: MenuButton = _shell.menu("Edit")
	edit.show_popup()
	await _frames(10)
	var popup: PopupMenu = edit.get_popup()
	var tall: float = root.get_visible_rect().size.y
	_check("Edit has %d rows (at most 25), %d units tall in a window of %d (at most 60%%)" % [
		popup.item_count, popup.size.y, roundi(tall)],
		popup.item_count <= 25 and popup.size.y <= tall * 0.6)
	await _shot("edit_menu")
	popup.hide()
	await _frames(4)
	var help: PopupMenu = _shell.menu("Help").get_popup()
	var help_rows: Array = []
	for index: int in help.item_count:
		help_rows.append(help.get_item_text(index))
	_check("Help is Keys and the tour (%s)" % ", ".join(help_rows),
		help_rows == ["Keys and controls", "Take the tour"])
	var mark: MenuButton = (_main.get("_bar") as ModelBar).mark
	mark.show_popup()
	await _frames(10)
	var app_menu: PopupMenu = mark.get_popup()
	var at: int = _shell.item_index(app_menu, "palette")
	_check("the app's menu has Find a command… with its key (\"%s\", %s)" % [
		app_menu.get_item_text(at) if at >= 0 else "none", _shell.key_words("palette")],
		at >= 0 and app_menu.get_item_text(at) == "Find a command…"
		and app_menu.get_item_accelerator(at) == KEY_MASK_CMD_OR_CTRL | 0x2215
		and _shell.key_words("palette") == EditVerbs.held_key() + "+/")
	await _shot("app_menu")
	app_menu.id_pressed.emit(app_menu.get_item_id(at))
	app_menu.hide()
	await _frames(6)
	_check("...which opens the box, the keys in it", _palette.visible and _typing())
	await _key(KEY_ESCAPE)
	_check("...and Escape puts it away", not _palette.visible)
	await _keys_from(KEY_P, true, true)
	_check("Ctrl+Shift+P opens it on the desktop", _palette.visible and _typing())
	await _key(KEY_ESCAPE)
	# A beta tester's Beta hub: in the app's menu and the box for a tester
	# alone (Shell.set_early).
	var keys: Array[String] = ["beta_hub"]
	_shell.set_early(keys)
	var tester: bool = _shell.item_index(mark.get_popup(), "beta_hub") >= 0 \
		and "beta_hub" in _palette.matches("beta hub")
	keys.clear()
	_shell.set_early(keys)
	_check("a beta tester has Beta hub in the app's menu and the box, and nobody else (%s)"
		% ", ".join(_palette.matches("beta hub")), tester
		and _shell.item_index(mark.get_popup(), "beta_hub") == -1
		and not "beta_hub" in _palette.matches("beta hub"))
	# The keys list under the model says what I does as the menus and the
	# box do: it said I brickified, which is Ctrl+I; I is X-ray (keysheet).
	var said: Dictionary = {}
	for binding: ControlsHint.Binding in ControlsHint.for_keyboard():
		for key: String in binding.keys:
			said[key.replace("-", "+")] = binding.verb
	_check("the keys list says %s brickifies and I is not that (\"%s\"), as the menus have %s and %s" % [
		_shell.key_words("brickify"), said.get("I", "not listed"), _shell.key_words("brickify"),
		_shell.key_words("xray")], str(said.get(_shell.key_words("brickify"), "")).contains("brickify")
		and not str(said.get("I", "")).contains("brickify") and _shell.key_words("xray") == "I")


func _submenus(popup: PopupMenu) -> Array[PopupMenu]:
	var out: Array[PopupMenu] = []
	for child: Node in popup.get_children():
		if child is PopupMenu:
			out.append(child as PopupMenu)
			out.append_array(_submenus(child as PopupMenu))
	return out


## Render from the model by keys alone, through Shell.run as its menu row.
func _render_by_keys() -> void:
	_builder.clear_selection()
	root.gui_release_focus()
	await _frames(4)
	var presses: int = 0
	await _keys_from(KEY_SLASH, true)
	presses += 1
	var over: Rect2 = _shell.model_area.get_global_rect()
	var box := Rect2(Vector2(_palette.position), Vector2(_palette.size))
	_check("Ctrl+/ opens the box over the model (%s in %s), the keys in its field" % [box, over],
		_palette.visible and _typing() and over.encloses(box))
	for letter: String in "ren":
		await _type(letter)
		presses += 1
	var rows: Array = _palette.get("_names")
	_check("\"ren\": Render… first (%s)" % ", ".join(rows.slice(0, 3)), not rows.is_empty() and rows[0] == "render")
	var list: Tree = _palette.get("_list")
	# Up to ROWS_SHOWN; past those it scrolls (German finds "ren" in every -ieren).
	var shown: int = mini(rows.size(), CommandPalette.ROWS_SHOWN)
	var last: Rect2 = list.get_item_area_rect(list.get_root().get_child(shown - 1))
	_check("...the list as tall as its %d rows%s (the last's foot %d, the list %d)" % [shown,
		"" if shown == rows.size() else " of %d, the rest scrolled to" % rows.size(),
		roundi(last.end.y), roundi(list.size.y)], last.end.y <= list.size.y + 1.0
		and list.size.y - last.end.y < last.size.y / 2.0)
	await _shot("render_typed")
	await _key(KEY_ENTER)
	presses += 1
	await _frames(20)
	var dialog: RenderDialog = _main.get("_render")
	_check("Return opens Render: %d key presses from the model (at most 6)" % presses,
		dialog != null and dialog.visible and presses <= 6 and not _palette.visible)
	await _shot("render_open")
	(dialog as RenderDialog).close()
	await _frames(10)
	await _keys_from(KEY_SLASH, true)
	rows = _palette.get("_names")
	_check("opened again, the recent first (%s)" % ", ".join(rows.slice(0, 3)), rows[0] == "render")
	await _key(KEY_ESCAPE)


## Matched by its words and its menu's, in any order, not only by how its
## name starts.
func _words() -> void:
	_stand_in()
	for case: Array in [["same colour", "select_colour", 1], ["colour same", "select_colour", 3],
			["turn left", "turn_left", 1], ["xray", "xray", 1], ["export picture", "export_picture", 1],
			["lock", "lock", 1], ["lock", "unlock", 3], ["swing", "swing", 1],
			["bricklink", "export_bricklink", 3], ["import ldraw", "import_ldraw", 1]]:
		await _keys_from(KEY_SLASH, true)
		await _type(case[0])
		var rows: Array = _palette.get("_names")
		var at: int = rows.find(case[1])
		_check("\"%s\" finds %s, row %d (in the first %d: %s)" % [case[0], case[1], at + 1, case[2],
			", ".join(rows.slice(0, 3))], at >= 0 and at < int(case[2]))
		await _key(KEY_ESCAPE)
	# The assistant off in Settings: its commands are not found, as they are
	# not in the menus.
	_shell.set_assistant(false)
	var found: Array[String] = _palette.matches("claude")
	_check("with the assistant off, \"claude\" finds none of its commands (%s)" % ", ".join(found),
		found.filter(func(named: String) -> bool: return named in Shell.ASSISTANT_COMMANDS).is_empty())
	_shell.set_assistant(true)
	found = _palette.matches("claude")
	_check("...and on again, Ask Claude is back (%s)" % ", ".join(found.slice(0, 3)), "ask_claude" in found)


## A part's number lists the part, and Return takes it into hand.
func _a_part() -> void:
	_palette.run_command = _shell.run
	_builder.clear_selection()
	var from: int = Time.get_ticks_usec()
	_palette.matches("brick 2 x 4")
	_palette.parts_for("brick 2 x 4")
	var took: float = (Time.get_ticks_usec() - from) / 1000.0
	await _keys_from(KEY_SLASH, true)
	await _type("3001")
	var rows: Array = _palette.get("_names")
	_check("\"3001\" lists the part first (%s); finding \"brick 2 x 4\" took %.1f ms" % [
		", ".join(rows.slice(0, 3)), took], not rows.is_empty() and rows[0] == "part:3001" and took < 50.0)
	var list: Tree = _palette.get("_list")
	var scrolled: Array = list.get_children(true).filter(func(child: Node) -> bool:
		return child is VScrollBar and (child as VScrollBar).visible)
	_check("...its %d rows in sight with no scroll bar" % rows.size(), scrolled.is_empty())
	await _shot("a_part")
	await _key(KEY_ENTER)
	_check("...and Return takes it into hand (%s, the %s tool)" % [_builder.held_part,
		(_main.get("_verbs") as EditVerbs).mode], _builder.held_part == "3001"
		and (_main.get("_verbs") as EditVerbs).mode == "place" and not _palette.visible)
	(_main.get("_verbs") as EditVerbs).put_away()
	(_main.get("_verbs") as EditVerbs).set_mode("select")
	await _frames(4)


## A command that cannot be used now: greyed, says why, and runs nothing.
func _greyed() -> void:
	_stand_in()
	_builder.clear_selection()
	await _frames(2)
	await _keys_from(KEY_SLASH, true)
	await _type("mirror")
	var rows: Array = _palette.get("_names")
	var item: TreeItem = (_palette.get("_list") as Tree).get_root().get_child(0)
	var why: String = _shell.why_not("mirror")
	_check("with nothing selected Mirror is listed, greyed, saying why (\"%s\", \"%s\")" % [
		item.get_text(0), item.get_text(1)], rows[0] == "mirror" and item.get_custom_color(0).a < 0.6
		and item.get_text(1) == why and why == "Select a part first")
	await _shot("greyed")
	await _key(KEY_ENTER)
	var foot: Label = _palette.get("_foot")
	_check("...Return runs nothing and says why there (\"%s\"), the words still being typed"
		% foot.text, _ran.is_empty() and _palette.visible and foot.text.contains(why)
		and _typing() and (_palette.get("_field") as LineEdit).is_editing())
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check("Escape puts it away, the keys back with the model", not _palette.visible
		and root.gui_get_focus_owner() == null)


## Every command in the shell's table, found by its words and run from the
## box by Down and Return: handed to Shell.run, as its menu row hands it.
func _every_command() -> void:
	_stand_in()
	(_main.get("_verbs") as EditVerbs).select_by("all")
	await _frames(4)
	var names: Array = (_shell.get("_commands") as Dictionary).keys()
	var ran: int = 0
	var greyed: int = 0
	var unlisted: Array[String] = []
	var wrong: Array[String] = []
	var deepest: int = 0
	for named: String in names:
		if named == "palette":
			continue
		if _shell._shown([named]).is_empty():
			unlisted.append(named)
			continue
		await _keys_from(KEY_SLASH, true)
		if not _palette.visible:
			wrong.append("%s: the box did not open" % named)
			continue
		await _type(_shell.command(named).words)
		var rows: Array = _palette.get("_names")
		var at: int = rows.find(named)
		deepest = maxi(deepest, at)
		if at < 0 or at >= CommandPalette.ROWS_SHOWN:
			wrong.append("%s: row %d for \"%s\"" % [named, at + 1, _shell.command(named).words])
			await _key(KEY_ESCAPE)
			continue
		var item: TreeItem = (_palette.get("_list") as Tree).get_root().get_child(at)
		var why: String = _shell.why_not(named)
		if item.get_text(2) != _shell.key_words(named) \
				or item.get_text(1) != (why if not why.is_empty() else _palette.where(named)):
			wrong.append("%s: its row says \"%s\", \"%s\"" % [named, item.get_text(1), item.get_text(2)])
		for _n: int in at:
			await _key(KEY_DOWN, 0)
		_ran.clear()
		await _key(KEY_ENTER)
		if _shell.can(named):
			ran += 1
			if _ran != [named] or _palette.visible:
				wrong.append("%s: ran %s" % [named, str(_ran)])
		else:
			greyed += 1
			if not _ran.is_empty() or not _palette.visible:
				wrong.append("%s: greyed, but ran %s" % [named, str(_ran)])
			await _key(KEY_ESCAPE)
	_check("every command found by its words, its key and menu on its row, and Return hands it to "
		+ "Shell.run: %d run, %d greyed with why and not run, the deepest on row %d; %s%s" % [ran,
		greyed, deepest + 1, "not listed here: " + ", ".join(unlisted) if not unlisted.is_empty() else "",
		"" if wrong.is_empty() else "; wrong: " + "; ".join(wrong.slice(0, 12))],
		wrong.is_empty() and ran > 120 and unlisted.all(func(named: String) -> bool:
			# In a browser alone, or a beta tester's alone.
			return named in Shell.WEB_ONLY or Shell.EARLY_COMMANDS.has(named)))
	_builder.clear_selection()


## A8: the menu on a part, opened by a right click on it, holds what is
## done to a part, each with its key, and each runs from there.
func _part_menu() -> void:
	_palette.run_command = _shell.run
	_main.call("clear_model")
	await _frames(4)
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3001", 4, Vector3(-60, 48, 20))
	_put("3001", 1, Vector3(60, 24, 20))
	# A hinge brick's base and top on a brick, as handbuild_probe swings it.
	_put("3004", 15, Vector3(0, 24, 10))
	_put("3937", 7, Vector3(0, 48, 10))
	_put("3938", 7, Vector3(0, 48, 10))
	_camera.frame(AABB(Vector3(-90, 0, -20), Vector3(180, 80, 80)))
	await _frames(30)
	var red: int = _brick_of("3001", 4)
	var hinged: int = _brick_of("3938", 7)
	var menu: PopupMenu = await _right_click(red)
	var words: PackedStringArray = []
	for index: int in menu.item_count:
		words.append("-" if menu.is_item_separator(index) else menu.get_item_text(index))
	print("    the menu on a part: %s" % " | ".join(words))
	var keyed: Array[String] = []
	for named: String in ["duplicate", "replace", "select_part", "select_colour", "step_prev",
			"step_next", "swing"]:
		var at: int = _shell.item_index(menu, named)
		var key: String = _shell.key_words(named)
		var shows: bool = key.is_empty() or menu.get_item_accelerator(at) != 0 \
			or menu.get_item_text(at).ends_with(key)
		if at < 0 or not shows:
			keyed.append(named)
	_check("a right click on a part holds Duplicate, Replace, Select the same part and colour, the "
		+ "step moves and Swing on its hinge, each with its key%s" % (
		"" if keyed.is_empty() else ": not " + ", ".join(keyed)), keyed.is_empty())
	_check("...Swing on its hinge greyed on a part on studs", menu.is_item_disabled(
		_shell.item_index(menu, "swing")))
	await _shot("part_menu")
	menu.hide()
	await _frames(4)
	# Each from the menu.
	await _from_menu(red, "select_part")
	_check("Select the same part takes every 3001 (%d)" % _builder.selection.size(),
		_builder.selection.size() == 3)
	await _from_menu(red, "select_colour")
	_check("Select the same colour takes the two red (%d)" % _builder.selection.size(),
		_builder.selection.size() == 2)
	await _from_menu(red, "duplicate")
	_check("Duplicate puts a copy in hand", _builder.is_carrying())
	(_main.get("_verbs") as EditVerbs).put_away()
	await _frames(4)
	# The blue brick, with nothing on it, for what changes the part clicked.
	var blue: int = _brick_of("3001", 1)
	_builder.held_part = "3003"
	var depth: int = _builder.history_depth()
	await _from_menu(blue, "replace")
	_check("Replace with the part in hand makes it a 3003 (%s)" % _part_of(_brick_of("3003", 1)),
		_brick_of("3003", 1) != 0 and _brick_of("3001", 1) == 0)
	while _builder.history_depth() > depth:
		_builder.undo()
	await _frames(4)
	blue = _brick_of("3001", 1)
	# The first step edit gives the model its worked-out steps (AuthorSteps).
	await _from_menu(blue, "step_next")
	var was: int = _world.get_brick(blue).step
	await _from_menu(blue, "step_next")
	var later: int = _world.get_brick(blue).step
	_check("Move to next step takes it a step later (%d to %d)" % [was, later], later == was + 1)
	await _from_menu(blue, "step_prev")
	_check("Move to previous step takes it back (%d)" % _world.get_brick(blue).step,
		_world.get_brick(blue).step == was)
	var turned: Transform3D = _world.get_brick(hinged).transform
	menu = await _right_click(hinged)
	_check("on the hinge's top, Swing on its hinge is not greyed",
		not menu.is_item_disabled(_shell.item_index(menu, "swing")))
	menu.hide()
	await _from_menu(hinged, "swing")
	var angle: float = rad_to_deg(turned.basis.get_rotation_quaternion().angle_to(
		_world.get_brick(hinged).transform.basis.get_rotation_quaternion()))
	_check("...and swings it %.1f degrees on its pin" % angle, absf(angle - EditVerbs.SWING) < 0.5)


func _from_menu(brick_id: int, named: String) -> void:
	_builder.clear_selection()
	await _frames(2)
	var menu: PopupMenu = await _right_click(brick_id)
	if _builder.selection.keys() != [brick_id]:
		print("    (the right click for %s took %s, not %d)" % [named, str(_builder.selection.keys()), brick_id])
	menu.id_pressed.emit(menu.get_item_id(_shell.item_index(menu, named)))
	menu.hide()
	await _frames(6)


func _right_click(brick_id: int) -> PopupMenu:
	var at: Vector2 = _camera.unproject_position(_world.get_brick(brick_id).transform.origin
		+ Vector3(0, -12, 0))
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(2)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)
	return _shell.context


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	_builder.register(_world.add_brick(part, colour, where), part, where)


func _brick_of(part: String, colour: int) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.color_code == colour and not _store.scenery.has(brick.id):
			return brick.id
	return 0


func _part_of(brick_id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	return brick.part_id if brick != null else "gone"


## What the box chooses is recorded, not run.
func _stand_in() -> void:
	_ran.clear()
	_palette.run_command = func(named: String) -> bool:
		_ran.append(named)
		return true


func _typing() -> bool:
	var field: LineEdit = _palette.get("_field")
	return field.has_focus()


func _type(text: String) -> void:
	for letter: String in text:
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.unicode = letter.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
	await _frames(2)


func _key(code: Key, settle: int = 3) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(settle)


## A key with Ctrl, and Shift, as a person holds them.
func _keys_from(code: Key, ctrl: bool, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _shot(named: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://shots/palette/%s_%s.png" % [named, _size])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)
