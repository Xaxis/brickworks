## A key for each command a builder uses often (docs/app_ux3/keys.md).
##
##   godot --path . --resolution 1280x720 --script src/dev/keys4_probe.gd
##   tools/probe.sh keys4_probe
##   ... -- --shots=DIR    the pictures there, not in shots/keys4/
##
## Every key is pressed as a person presses it, an input event to the
## window, and each check reads what it did:
## - under each preset (the app's, Studio's, Mecabricks', LDCad's): every
##   command docs/app_ux3/keys.md gives a key has the key it says, no two
##   actions share a key, and the commands with none are exactly the ones
##   its table names, as many as its counts say. A command added with no
##   key fails here until the table says why it has none;
## - each of those keys is on its menu row, under each preset;
## - each does what its menu row does, under each preset: Select nothing,
##   the same part and colour, Find a part (the list, its box ready),
##   Replace with the part in hand, the stud grid, Check stability (the
##   same words), Simulate, Motions, the reference picture and Instructions
##   (the booklet's Save dialog, cancelled);
## - typed into the parts' search, none of them runs anything;
## - the keys sheet (F1) lists each with its words, and Replace set there
##   to Alt-W is done by Alt-W.
##
## The data folder is the run's own (probe.sh gives one).
extends SceneTree

const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT
const ALT := KEY_MASK_ALT
const TABLE := "res://docs/app_ux3/keys.md"
## The preset each column of the table's counts and keys is.
const SHORT: Dictionary = {"Brickworks": "brickworks", "Studio": "studio",
	"Mecabricks": "mecabricks", "LDCad": "ldcad"}

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _store: ModelStore
var _sheet: ControlsDialog
var _shots: String = ""
var _size: String = ""
## The model's parts: a red 2x4 (a), a yellow 2x4 on it (b), a red 2x2 (c)
## and a red 2x4 alone (d).
var _a: int = 0
var _b: int = 0
var _c: int = 0
var _d: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.substr(8)
	if _shots.is_empty():
		_shots = ProjectSettings.globalize_path("res://shots/keys4")
	DirAccess.make_dir_recursive_absolute(_shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	BookletMaker.open_when_written = false
	# Godot's own Save dialog, which this answers, never the desktop's.
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  keys4 probe: SKIPPED — the window did not come up")
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
	Keymap.reset()
	Keymap.use("brickworks")
	await _frames(30)
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	print("  a %s window" % _size)

	var table: Dictionary = _read_table()
	if table.is_empty():
		_check("docs/app_ux3/keys.md read: its counts, its keys and its keyless rows", false)
	else:
		_counts(table)
		await _menus(table)
		await _model()
		await _keys_do_what_rows_do(table)
		await _not_while_typing()
		await _sheet_lists_them(table)
	Keymap.use("brickworks")
	Keymap.reset()

	print("")
	if _failures == 0:
		print("keys4 probe: all checks passed")
	else:
		print("keys4 probe: %d check(s) FAILED" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the table -------------------------------------------------------------------

## The table's counts {preset: keyless after}, its keys {command: {preset:
## listed}}, and its keyless rows {command: [presets]}.
func _read_table() -> Dictionary:
	var file := FileAccess.open(ProjectSettings.globalize_path(TABLE), FileAccess.READ)
	if file == null:
		return {}
	var counts: Dictionary = {}
	var keyed: Dictionary = {}
	var keyless: Dictionary = {}
	var section: String = ""
	var columns: Array = []
	for raw: String in file.get_as_text().split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("## "):
			section = line.substr(3)
			columns = []
			continue
		if not line.begins_with("|") or line.begins_with("|---"):
			continue
		var cells: Array = Array(line.trim_prefix("|").trim_suffix("|").split("|")).map(
			func(cell: String) -> String: return cell.strip_edges())
		if columns.is_empty():
			columns = cells
			continue
		if columns[0] == "Preset" and SHORT.has(cells[0]):
			counts[SHORT[cells[0]]] = int(cells[columns.find("After")])
		var name: String = str(cells[0]).trim_prefix("`").trim_suffix("`")
		if section == "Given a key":
			keyed[name] = {"brickworks": cells[columns.find("Brickworks")],
				"studio": cells[columns.find("Studio's keys")],
				"mecabricks": cells[columns.find("Mecabricks'")],
				"ldcad": cells[columns.find("LDCad's")]}
		elif section.begins_with("Left without a key"):
			var under: String = cells[columns.find("Keyless under")]
			var presets: Array = []
			if under == "all":
				presets = Keymap.PRESETS.duplicate()
			else:
				for named: String in under.split(", "):
					presets.append(SHORT.get(named, named))
			keyless[name] = presets
	if counts.size() != 4 or keyed.is_empty() or keyless.is_empty():
		return {}
	return {"counts": counts, "keyed": keyed, "keyless": keyless}


func _counts(table: Dictionary) -> void:
	print("\n  each preset's keys, against docs/app_ux3/keys.md")
	var commands: Dictionary = _shell.get("_commands")
	var keyed: Dictionary = table["keyed"]
	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		var none: Array = []
		for name: String in commands:
			if Keymap.key_of(name) == 0:
				none.append(name)
		var named: Array = (table["keyless"] as Dictionary).keys().filter(func(n: String) -> bool:
			return preset in (table["keyless"][n] as Array))
		var unnamed: Array = none.filter(func(n: String) -> bool: return not n in named)
		var wrongly: Array = named.filter(func(n: String) -> bool: return not n in none)
		_check("%s: %d of %d commands with no key, as its counts say (%d)%s%s" % [preset, none.size(),
			commands.size(), int(table["counts"][preset]),
			"; with none, not in the table (say why there): " + ", ".join(unnamed) if not unnamed.is_empty() else "",
			"; in the table, but keyed: " + ", ".join(wrongly) if not wrongly.is_empty() else ""],
			none.size() == int(table["counts"][preset]) and unnamed.is_empty() and wrongly.is_empty())
		var off: Array = []
		for name: String in keyed:
			if Keymap.listed(name) != str(keyed[name][preset]) or Keymap.key_of(name) == 0:
				off.append("%s %s (the table: %s)" % [name, Keymap.listed(name), keyed[name][preset]])
		_check("...the %d given a key each have the table's: %s" % [keyed.size(),
			", ".join(keyed.keys().map(func(n: String) -> String: return "%s %s" % [n, Keymap.listed(n)]))
			if off.is_empty() else "not " + ", ".join(off)], off.is_empty())
		var holders: Dictionary = {}
		for action: String in Keymap.actions():
			var key: int = Keymap.key_of(action)
			if key != 0:
				holders[key] = (holders.get(key, []) as Array) + [action]
		var shared: Array = []
		for key: int in holders:
			if (holders[key] as Array).size() > 1:
				shared.append("%s %s" % [Keymap.listed_key(key), holders[key]])
		_check("...and no two of its %d keys' actions share a key%s" % [holders.size(),
			"" if shared.is_empty() else ": " + ", ".join(shared)], shared.is_empty())
	Keymap.use("brickworks")


# -- the menus -------------------------------------------------------------------

func _menus(table: Dictionary) -> void:
	print("\n  each key is on its menu row")
	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		var wrong: Array = []
		for name: String in table["keyed"]:
			var found: Array = _row_of(name)
			if found.is_empty():
				wrong.append("%s in no menu" % name)
				continue
			var popup: PopupMenu = found[0]
			popup.about_to_popup.emit()
			var shown: int = popup.get_item_accelerator(found[1])
			if shown == 0 or shown != Shell.menu_accel(Keymap.key_of(name)):
				wrong.append("%s shows %s" % [name, OS.get_keycode_string(shown)])
		_check("%s: each row shows its key%s" % [preset, "" if wrong.is_empty() else ": " + ", ".join(wrong)],
			wrong.is_empty())
	Keymap.use("brickworks")
	# As a person sees them: the menus opened.
	for title: String in ["Edit", "View", "Build", "Make", "Tools"]:
		var button: MenuButton = _shell.menu(title)
		button.show_popup()
		await _frames(10)
		await _shot("menu_" + title.to_lower())
		button.get_popup().hide()
		await _frames(3)


## The popup a command's row is in, and the row's index there; [] for none.
func _row_of(name: String) -> Array:
	var id: int = _shell.menu_id(name)
	if id < 0:
		return []
	for button: MenuButton in _shell.get("_menus"):
		for popup: PopupMenu in [button.get_popup()] + _submenus(button.get_popup()):
			var at: int = popup.get_item_index(id)
			if at >= 0:
				return [popup, at]
	return []


func _submenus(popup: PopupMenu) -> Array[PopupMenu]:
	var out: Array[PopupMenu] = []
	for child: Node in popup.get_children():
		if child is PopupMenu:
			out.append(child as PopupMenu)
			out.append_array(_submenus(child as PopupMenu))
	return out


# -- what each key does ----------------------------------------------------------

func _model() -> void:
	_main.call("clear_model")
	await _frames(4)
	_a = _put("3001", 4, Vector3(-120, 24, 20))
	_b = _put("3001", 14, Vector3(-120, 48, 20))
	_c = _put("3003", 4, Vector3(60, 24, 20))
	_d = _put("3001", 4, Vector3(220, 24, 20))
	await _frames(6)
	# A picture for the reference to show: with none, its key and row ask
	# for a file, as a person's first time does.
	var picture := Image.create(64, 48, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.8, 0.7, 0.5))
	(_main.get("_reference") as ReferenceImage).take(picture, "probe")
	await _frames(6)


## Each command's way to be tried: what is set first, what is read after, and
## what puts it back.
func _cases() -> Dictionary:
	return {
		"select_none": [func() -> void: _select([_a, _c]),
			func() -> Variant: return _sorted(_builder.selection.keys()),
			func() -> void: pass,
			func(seen: Variant) -> bool: return (seen as Array).is_empty()],
		"select_alike": [func() -> void: _select([_a]),
			func() -> Variant: return _sorted(_builder.selection.keys()),
			func() -> void: _builder.clear_selection(),
			func(seen: Variant) -> bool: return seen == _sorted([_a, _d])],
		"select_find": [func() -> void: _builder.clear_selection(),
			func() -> Variant:
				var list: Variant = _main.get("_inventory_made")
				return list != null and (list as Control).visible \
					and root.gui_get_focus_owner() is LineEdit,
			func() -> void:
				var list: Variant = _main.get("_inventory_made")
				if list != null and (list as Control).visible:
					list.call("hide_list"),
			func(seen: Variant) -> bool: return seen == true],
		"replace": [func() -> void:
				(_main.get("_bin") as PartsBin).part_chosen.emit("3003")
				_select([_b]),
			func() -> Variant:
				await _frames(20)
				return _parts(),
			func() -> void:
				await _verbs.press("undo")
				await _frames(6)
				_verbs.set_mode("select")
				_builder.clear_selection(),
			func(seen: Variant) -> bool:
				return (seen as Array).count("3003") == 2 and (seen as Array).count("3001") == 2],
		"grid": [func() -> void: pass,
			func() -> Variant: return _shell.grid.visible,
			func() -> void: pass,
			func(_seen: Variant) -> bool: return true],
		"stability": [func() -> void:
				_builder.clear_selection()
				_shell.balance_shown = null
				_shell.bar.say(""),
			func() -> Variant:
				for _n: int in 600:
					if _shell.balance_shown != null:
						break
					await process_frame
				await _frames(4)
				return _said(),
			func() -> void: _builder.clear_selection(),
			func(seen: Variant) -> bool: return not str(seen).is_empty() and _shell.balance_shown != null],
		"simulate": [func() -> void: pass,
			func() -> Variant:
				await _frames(10)
				return _panel_up("_simulate_made"),
			func() -> void: _close("_simulate_made"),
			func(seen: Variant) -> bool: return seen == true],
		"pose": [func() -> void: pass,
			func() -> Variant:
				await _frames(10)
				return _panel_up("_pose_made"),
			func() -> void: _close("_pose_made"),
			func(seen: Variant) -> bool: return seen == true],
		"reference": [func() -> void: pass,
			func() -> Variant:
				await _frames(6)
				return ((_main.get("_reference") as ReferenceImage).get("_dialog") as Window).visible,
			func() -> void:
				((_main.get("_reference") as ReferenceImage).get("_dialog") as Window).hide(),
			func(seen: Variant) -> bool: return seen == true],
		"instructions": [func() -> void: pass,
			func() -> Variant:
				for _n: int in 300:
					if SaveTo.showing != null and SaveTo.showing.visible:
						return true
					await process_frame
				return false,
			func() -> void:
				if SaveTo.showing != null:
					SaveTo.showing.get_cancel_button().pressed.emit()
				for _n: int in 60:
					if SaveTo.showing == null:
						break
					await process_frame,
			func(seen: Variant) -> bool: return seen == true],
	}


func _keys_do_what_rows_do(table: Dictionary) -> void:
	print("\n  each key does what its menu row does, under each preset")
	var cases: Dictionary = _cases()
	for name: String in table["keyed"]:
		if not cases.has(name):
			_check("%s: a way to try it here" % name, false)
			continue
		var case: Array = cases[name]
		var found: Array = _row_of(name)
		Keymap.use("brickworks")
		await case[0].call()
		await _frames(4)
		var before: Variant = null
		if name == "grid":
			before = await case[1].call()
		var popup: PopupMenu = found[0]
		popup.id_pressed.emit(_shell.menu_id(name))
		await _frames(6)
		var by_row: Variant = await case[1].call()
		var row_ok: bool = case[3].call(by_row) and (name != "grid" or by_row != before)
		if name in ["pose", "simulate", "reference", "instructions"]:
			await _shot("row_" + name)
		await case[2].call()
		await _frames(6)
		var by_key: Array = []
		for preset: String in Keymap.PRESETS:
			Keymap.use(preset)
			await case[0].call()
			await _frames(4)
			before = null
			if name == "grid":
				before = await case[1].call()
			root.gui_release_focus()
			await _press(Keymap.key_of(name))
			var seen: Variant = await case[1].call()
			var ok: bool = case[3].call(seen) and (name != "grid" or seen != before) \
				and (name == "grid" or seen == by_row)
			by_key.append("%s %s%s" % [preset, Keymap.listed(name), "" if ok else " (%s)" % str(seen)])
			if not ok:
				row_ok = false
			if preset == "brickworks" and name in ["select_find", "replace", "stability"]:
				await _shot("key_" + name)
			await case[2].call()
			await _frames(6)
		_check("%s, as %s does (%s): %s" % [Keymap.words(name), Keymap.menu_row(name),
			str(by_row), "; ".join(by_key)], row_ok)
	Keymap.use("brickworks")


# -- typed into a field ----------------------------------------------------------

func _not_while_typing() -> void:
	print("\n  typed into the parts' search, the keys run nothing")
	_select([_a, _c])
	var bin: PartsBin = _main.get("_bin")
	bin.focus_search()
	await _frames(6)
	var field: Control = root.gui_get_focus_owner()
	_check("the parts' search has the keys (%s)" % field, field is LineEdit)
	var grid_was: bool = _shell.grid.visible
	for name: String in ["select_none", "select_find", "reference", "pose", "simulate", "instructions",
			"grid"]:
		await _press(Keymap.key_of(name))
	await _frames(20)
	var ran: Array = []
	if _builder.selection.size() != 2:
		ran.append("Select nothing")
	var list: Variant = _main.get("_inventory_made")
	if list != null and (list as Control).visible:
		ran.append("Find")
	if ((_main.get("_reference") as ReferenceImage).get("_dialog") as Window).visible:
		ran.append("the reference picture")
	if _panel_up("_pose_made"):
		ran.append("Motions")
	if _panel_up("_simulate_made"):
		ran.append("Simulate")
	if SaveTo.showing != null:
		ran.append("Instructions")
	if _shell.grid.visible != grid_was:
		ran.append("the grid")
	_check("Ctrl-shift-A, Ctrl-F, alt-N, alt-O, alt-U, alt-B and alt-G ran nothing%s, and the search kept the keys"
		% ("" if ran.is_empty() else ": " + ", ".join(ran)),
		ran.is_empty() and root.gui_get_focus_owner() == field)
	root.gui_release_focus()
	_builder.clear_selection()


# -- the keys sheet --------------------------------------------------------------

func _sheet_lists_them(table: Dictionary) -> void:
	print("\n  the keys sheet")
	await _press(KEY_F1)
	await _frames(10)
	_check("F1 opens the keys sheet", _sheet.visible)
	var chips: Dictionary = _sheet.controls_by_name()
	var missing: Array = []
	for name: String in table["keyed"]:
		var chip: Control = chips.get("key_" + name)
		if chip == null or not chip.accessibility_name.contains(Keymap.listed(name)) \
				or not chip.accessibility_name.begins_with(Keymap.words(name)):
			missing.append("%s (%s)" % [name, chip.accessibility_name if chip != null else "no row"])
	_check("each is on it with its words and key%s" % ("" if missing.is_empty() else ": not " + ", ".join(missing)),
		missing.is_empty())
	var find: LineEdit = _sheet.get("_find")
	for typed: String in ["alt-", "select"]:
		find.text = typed
		find.text_changed.emit(typed)
		await _frames(10)
		await _shot("sheet_" + typed.trim_suffix("-"))
	find.text = ""
	find.text_changed.emit("")
	await _frames(6)
	# Set there to another: Replace to Alt-W.
	var chip: Control = _sheet.controls_by_name().get("key_replace")
	if chip == null:
		_check("Replace's key is on the sheet to click", false)
		return
	(_sheet.get("_keys") as ScrollContainer).ensure_control_visible(chip)
	await _frames(4)
	await _click(chip.get_global_rect().get_center())
	await _press(ALT | KEY_W)
	await _frames(4)
	var said: String = (_sheet.get("_said") as Label).text
	_check("Replace's key clicked, then Alt-W: it is Replace's (%s), and said: \"%s\"" % [
		Keymap.listed("replace"), said], Keymap.key_of("replace") == ALT | KEY_W and said.contains("alt-W"))
	await _shot("sheet_set")
	await _press(KEY_ESCAPE)
	await _frames(4)
	var case: Array = _cases()["replace"]
	await case[0].call()
	await _frames(4)
	root.gui_release_focus()
	await _press(ALT | KEY_W)
	var seen: Variant = await case[1].call()
	_check("Alt-W replaces the selection with the part in hand (%s)" % str(seen), case[3].call(seen))
	await case[2].call()
	Keymap.reset()
	_check("back to these keys, Replace is alt-R again (%s)" % Keymap.listed("replace"),
		Keymap.key_of("replace") == ALT | KEY_R)


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


func _sorted(ids: Array) -> Array:
	var out: Array = ids.duplicate()
	out.sort()
	return out


## The model's parts by number, sorted.
func _parts() -> Array:
	var out: Array = _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id)).map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	out.sort()
	return out


func _panel_up(field: String) -> bool:
	var panel: Variant = _main.get(field)
	return panel != null and (panel as CanvasItem).visible


func _close(field: String) -> void:
	var panel: Variant = _main.get(field)
	if panel != null and (panel as CanvasItem).visible:
		panel.call("close")
	await _frames(4)
	root.gui_release_focus()


func _said() -> String:
	return str(_shell.status.fields()["message"])


## A key and its modifiers, down and up, as the window delivers them.
func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _click(at: Vector2) -> void:
	var window := Vector2(DisplayServer.window_get_size())
	var place: Vector2 = at * (window / root.get_visible_rect().size)
	var move := InputEventMouseMotion.new()
	move.position = place
	move.global_position = place
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = place
		event.global_position = place
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(named: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path: String = _shots.path_join("%s_%s.png" % [named, _size])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
