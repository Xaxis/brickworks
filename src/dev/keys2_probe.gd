## Keys for Render, its queue, the cut shapes, Page setup, the Pick a Brick
## list and the Library (keys2, APP_UX5 9; docs/app_ux3/keys.md, "Given a
## key in round five").
##
##   godot --path . --resolution 1280x720 --script src/dev/keys2_probe.gd
##   tools/probe.sh keys2_probe        (and PROBE_SIZE=1400x900)
##   ... -- --shots=DIR    the pictures there, not in shots/keys2/
##
## Every key is pressed as a person presses it, an input event to the
## window, and each check reads what it did:
## - under each preset (the app's, Studio's, Mecabricks', LDCad's), and on the
##   web, where a browser keeps some keys: each of the eight has a key, the
##   one the table says, and no other action has it, nor did any before:
##   no preset's keys, nor the app's own, give it to another;
## - commands with a key, counted as APP_UX5's walk counts them (`counts`):
##   98 of 210 before keys2, 106 or more after; and each preset's keyless
##   count is the table's;
## - each key is on its menu row, under each preset;
## - each does what its menu row does, under each preset: Render's panel,
##   the render queue, a box, a sphere and a cylinder cut away, Page setup,
##   the Pick a Brick list's Save dialog (cancelled), the Library;
## - Render from the model in one key press (the walk counted 5 by the
##   palette);
## - typed into the parts' search, none of them runs anything;
## - the keys sheet (F1) lists each with its words and key.
##
## The data folder is the run's own (probe.sh gives one).
extends SceneTree

const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT
const ALT := KEY_MASK_ALT
const TABLE := "res://docs/app_ux3/keys.md"
const SECTION := "Given a key in round five"
## The eight, as the plan names them (Into this model… is not in this
## release; Page setup… has its place).
const NAMES: Array[String] = ["render", "render_queue", "cut_box", "cut_sphere", "cut_cylinder",
	"booklet_page_setup", "export_pickabrick", "library"]
## The walk's count before keys2 (APP_UX5, `counts`), and the plan's bar.
const WALK_BEFORE := 98
const WALK_BAR := 106
const SHORT: Dictionary = {"Brickworks": "brickworks", "Studio": "studio",
	"Mecabricks": "mecabricks", "LDCad": "ldcad"}

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _sheet: ControlsDialog
var _shots: String = ""
var _size: String = ""
var _a: int = 0


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
		_shots = ProjectSettings.globalize_path("res://shots/keys2")
	DirAccess.make_dir_recursive_absolute(_shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
		print("  keys2 probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
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
	_check("docs/app_ux3/keys.md has \"%s\": the eight, each with its key under each preset (%s)"
		% [SECTION, ", ".join(table["keyed"].keys())],
		(table["keyed"] as Dictionary).size() == NAMES.size()
		and NAMES.all(func(n: String) -> bool: return (table["keyed"] as Dictionary).has(n)))
	_keys(table)
	_counts(table)
	await _menus(table)
	await _model()
	await _keys_do_what_rows_do()
	await _not_while_typing()
	await _sheet_lists_them()
	Keymap.use("brickworks")
	Keymap.reset()

	print("")
	if _failures == 0:
		print("keys2 probe: all checks passed")
	else:
		print("keys2 probe: %d check(s) FAILED" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the table -------------------------------------------------------------------

## keys2's rows {command: {preset: listed, "menu": row}} and the counts'
## After column {preset: keyless}.
func _read_table() -> Dictionary:
	var keyed: Dictionary = {}
	var counts: Dictionary = {}
	var file := FileAccess.open(ProjectSettings.globalize_path(TABLE), FileAccess.READ)
	if file == null:
		return {"keyed": keyed, "counts": counts}
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
		if columns[0] == "Preset" and SHORT.has(cells[0]) and columns.has("After"):
			counts[SHORT[cells[0]]] = int(cells[columns.find("After")])
		if section.begins_with(SECTION) and columns.has("Brickworks"):
			var name: String = str(cells[0]).trim_prefix("`").trim_suffix("`")
			keyed[name] = {"brickworks": cells[columns.find("Brickworks")],
				"studio": cells[columns.find("Studio's keys")],
				"mecabricks": cells[columns.find("Mecabricks'")],
				"ldcad": cells[columns.find("LDCad's")], "menu": cells[columns.find("Menu")]}
	return {"keyed": keyed, "counts": counts}


## Each preset's layers of keys, highest first, as Keymap builds them.
func _layers(preset: String) -> Array:
	var out: Array = [ColourKeys.preset_keys(preset).merged(Keymap.PRESET_KEYS[preset], true)]
	if preset != "brickworks":
		out.append(ColourKeys.preset_keys("brickworks").merged(Keymap.PRESET_KEYS["brickworks"], true))
	out.append(Keymap._native)
	return out


func _keys(table: Dictionary) -> void:
	print("\n  each preset's keys for the eight, against docs/app_ux3/keys.md")
	var keyed: Dictionary = table["keyed"]
	for web: bool in [false, true]:
		Keymap.web = web
		for preset: String in Keymap.PRESETS:
			Keymap.use(preset)
			var got: Array = []
			var off: Array = []
			var taken: Array = []
			for name: String in NAMES:
				var key: int = Keymap.key_of(name)
				got.append("%s %s" % [name, Keymap.listed(name) if key != 0 else "none"])
				var want: String = str((keyed.get(name, {}) as Dictionary).get(preset, "?"))
				if key == 0 or Keymap.listed(name) != want:
					off.append("%s %s (the table: %s)" % [name, Keymap.listed(name), want])
					continue
				if Keymap.action_of(key) != name:
					taken.append("%s's %s is %s's now" % [name, Keymap.listed(name), Keymap.action_of(key)])
				# None taken from a command that had it: no layer of this
				# preset's keys gives it to another action.
				for layer: Dictionary in _layers(preset):
					for action: String in layer:
						if action != name and int(layer[action]) == key and Keymap.has(action):
							taken.append("%s's %s is %s's too" % [name, Keymap.listed(name), action])
			_check("%s%s: each of the eight has the table's key: %s" % [preset, " on the web" if web else "",
				", ".join(got) if off.is_empty() else "not " + ", ".join(off)], off.is_empty())
			_check("...none taken from another action, now or out of the box%s" % (""
				if taken.is_empty() else ": " + ", ".join(taken)), taken.is_empty())
	Keymap.web = OS.has_feature("web")
	Keymap.use("brickworks")


# -- the counts ------------------------------------------------------------------

func _counts(table: Dictionary) -> void:
	print("\n  commands with a key")
	var commands: Dictionary = _shell.get("_commands")
	# As APP_UX5's walk counts them (appux_walk.gd `_counts`): the app's own
	# keys, each command's key as its menu row writes it.
	Keymap.use("brickworks")
	var with_key: int = 0
	for name: String in commands:
		if _shell.key_words(name) != "":
			with_key += 1
	_check("the walk's count: %d of %d commands have a key (%d before keys2; the bar %d or more)"
		% [with_key, commands.size(), WALK_BEFORE, WALK_BAR], with_key >= WALK_BAR)
	var counts: Dictionary = table["counts"]
	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		var none: int = 0
		for name: String in commands:
			if Keymap.key_of(name) == 0:
				none += 1
		_check("%s: %d of %d with no key, as the table's After says (%s)" % [preset, none,
			commands.size(), str(counts.get(preset, "none"))], counts.has(preset)
			and none == int(counts[preset]))
	Keymap.use("brickworks")


# -- the menus -------------------------------------------------------------------

func _menus(table: Dictionary) -> void:
	print("\n  each key is on its menu row")
	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		var wrong: Array = []
		for name: String in NAMES:
			var found: Array = _row_of(name)
			if found.is_empty():
				wrong.append("%s in no menu" % name)
				continue
			var popup: PopupMenu = found[0]
			popup.about_to_popup.emit()
			var shown: int = popup.get_item_accelerator(found[1])
			if Keymap.key_of(name) == 0 or shown != Shell.menu_accel(Keymap.key_of(name)):
				wrong.append("%s shows %s" % [name, OS.get_keycode_string(shown) if shown != 0 else "none"])
		_check("%s: each row shows its key%s" % [preset, "" if wrong.is_empty() else ": " + ", ".join(wrong)],
			wrong.is_empty())
	Keymap.use("brickworks")
	var rows: Array = []
	for name: String in NAMES:
		var said: String = str(((table["keyed"] as Dictionary).get(name, {}) as Dictionary).get("menu", ""))
		if Keymap.menu_row(name) != said:
			rows.append("%s is %s (the table: %s)" % [name, Keymap.menu_row(name), said])
	_check("each is where the table says in the menus%s" % ("" if rows.is_empty() else ": " + ", ".join(rows)),
		rows.is_empty())
	# As a person sees them: the menus opened, and the submenus beside them.
	for shown: Array in [["File", ""], ["File", "export"], ["View", "cut_away"], ["Build", "booklet"]]:
		var button: MenuButton = _shell.menu(str(shown[0]))
		button.show_popup()
		await _frames(10)
		var sub: PopupMenu = null
		if not str(shown[1]).is_empty():
			var top: PopupMenu = button.get_popup()
			for i: int in top.item_count:
				var node: PopupMenu = top.get_item_submenu_node(i)
				if node != null and String(node.name) == str(shown[1]):
					sub = node
			if sub != null:
				sub.popup(Rect2i(top.position + Vector2i(top.size.x - 8, 40), Vector2i.ZERO))
				await _frames(10)
		await _shot("menu_%s%s" % [str(shown[0]).to_lower(), "_" + str(shown[1]) if sub != null else ""])
		if sub != null:
			sub.hide()
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
	_put("3001", 14, Vector3(-120, 48, 20))
	_put("3003", 4, Vector3(60, 24, 20))
	_put("3001", 4, Vector3(220, 24, 20))
	await _frames(6)


## What is open now, of what the eight open: one word for each, "" for none.
func _open_now() -> Array:
	var out: Array = []
	# The panels made, or null: reading them never makes one (Later).
	var render: Variant = _main.get("_render_made")
	if render != null and (render as Control).visible:
		out.append("Render")
	if _main.call("_render_queue_up") != null:
		out.append("the render queue")
	var see: SeeInside = _shell.see_inside
	if see.shape_on():
		out.append(["", "a box", "a sphere", "a cylinder"][see.shape] if see.shape <= 3 else "a shape")
	var setup: Variant = _shell.get("_page_setup_dialog")
	if setup != null and (setup as Window).visible:
		out.append("Page setup")
	if SaveTo.showing != null and SaveTo.showing.visible:
		out.append("Save " + SaveTo.showing.current_file.get_slice("_", SaveTo.showing.current_file.get_slice_count("_") - 1))
	var library: Variant = _shell.get("_library_dialog")
	if library != null and (library as Control).visible:
		out.append("the Library")
	return out


## What each command, from its row or its key, should leave open.
const OPENS: Dictionary = {"render": "Render", "render_queue": "the render queue",
	"cut_box": "a box", "cut_sphere": "a sphere", "cut_cylinder": "a cylinder",
	"booklet_page_setup": "Page setup", "export_pickabrick": "Save pickabrick.csv",
	"library": "the Library"}


## Everything the eight open, put away.
func _put_away() -> void:
	var render: Variant = _main.get("_render_made")
	if render != null and (render as Control).visible:
		render.call("close")
	var queue: Variant = _main.call("_render_queue_up")
	if queue != null:
		queue.call("close")
	if _shell.see_inside.cutting:
		_shell.see_inside.set_cut(false)
	var setup: Variant = _shell.get("_page_setup_dialog")
	if setup != null and (setup as Window).visible:
		(setup as Window).hide()
	if SaveTo.showing != null:
		SaveTo.showing.get_cancel_button().pressed.emit()
		for _n: int in 60:
			if SaveTo.showing == null:
				break
			await process_frame
	var library: Variant = _shell.get("_library_dialog")
	if library != null and (library as Control).visible:
		library.call("close")
	await _frames(6)
	root.gui_release_focus()


## What a command did: what it left open, waited for (a Save dialog comes a
## few frames after).
func _what_opened(name: String) -> Array:
	for _n: int in 120:
		if str(OPENS[name]) in _open_now():
			break
		await process_frame
	await _frames(4)
	return _open_now()


func _keys_do_what_rows_do() -> void:
	print("\n  each key does what its menu row does, under each preset")
	for name: String in NAMES:
		await _put_away()
		Keymap.use("brickworks")
		_select([_a])
		await _frames(4)
		var found: Array = _row_of(name)
		if found.is_empty():
			_check("%s: a menu row to compare its key with" % name, false)
			continue
		(found[0] as PopupMenu).id_pressed.emit(_shell.menu_id(name))
		var by_row: Array = await _what_opened(name)
		var ok: bool = by_row == [OPENS[name]]
		await _put_away()
		var by_key: Array = []
		for preset: String in Keymap.PRESETS:
			Keymap.use(preset)
			_select([_a])
			await _frames(4)
			root.gui_release_focus()
			if Keymap.key_of(name) == 0:
				by_key.append("%s none" % preset)
				ok = false
				continue
			await _press(Keymap.key_of(name))
			var seen: Array = await _what_opened(name)
			var same: bool = seen == by_row and seen == [OPENS[name]]
			by_key.append("%s %s%s" % [preset, Keymap.listed(name), "" if same else " (%s)" % str(seen)])
			if not same:
				ok = false
			if preset == "brickworks":
				await _shot("key_" + name)
			await _put_away()
		_check("%s, as %s does (%s): %s" % [Keymap.words(name), Keymap.menu_row(name), ", ".join(by_row),
			"; ".join(by_key)], ok)
	Keymap.use("brickworks")
	_builder.clear_selection()
	# Render from the model by keys: the walk counted five by the palette.
	_events = 0
	await _press(Keymap.key_of("render"))
	var opened: Array = await _what_opened("render")
	_check("Render from the model in %d key press (the walk's 5 by the palette)" % _events,
		opened == ["Render"] and _events == 1)
	await _put_away()


# -- typed into a field ----------------------------------------------------------

func _not_while_typing() -> void:
	print("\n  typed into the parts' search, the keys run nothing")
	_select([_a])
	var bin: PartsBin = _main.get("_bin")
	bin.focus_search()
	await _frames(6)
	var field: Control = root.gui_get_focus_owner()
	_check("the parts' search has the keys (%s)" % field, field is LineEdit)
	var pressed: Array = []
	for name: String in NAMES:
		pressed.append(Keymap.listed(name))
		await _press(Keymap.key_of(name))
	await _frames(20)
	var ran: Array = _open_now()
	_check("%s ran nothing%s, and the search kept the keys" % [", ".join(pressed),
		"" if ran.is_empty() else ": " + ", ".join(ran)],
		ran.is_empty() and root.gui_get_focus_owner() == field)
	await _put_away()
	_builder.clear_selection()


# -- the keys sheet --------------------------------------------------------------

func _sheet_lists_them() -> void:
	print("\n  the keys sheet")
	await _press(KEY_F1)
	await _frames(10)
	_check("F1 opens the keys sheet", _sheet.visible)
	var chips: Dictionary = _sheet.controls_by_name()
	var missing: Array = []
	for name: String in NAMES:
		var chip: Control = chips.get("key_" + name)
		if chip == null or Keymap.listed(name).is_empty() \
				or not chip.accessibility_name.contains(Keymap.listed(name)) \
				or not chip.accessibility_name.begins_with(Keymap.words(name)):
			missing.append("%s (%s)" % [name, chip.accessibility_name if chip != null else "no row"])
	_check("each is on it with its words and key%s" % ("" if missing.is_empty() else ": not " + ", ".join(missing)),
		missing.is_empty())
	# Its row's words keep a name's capitals: LEGO®, never "lEGO®".
	var rows: Array = []
	for binding: ControlsHint.Binding in _sheet.bindings():
		if binding.actions.has("export_pickabrick") or binding.actions.has("export_bricklink"):
			rows.append(binding.verb)
	_check("the lists' rows keep their names' capitals: %s" % ", ".join(rows), rows.size() == 2
		and rows.any(func(verb: String) -> bool: return verb.begins_with("LEGO®"))
		and rows.any(func(verb: String) -> bool: return verb.begins_with("BrickLink")))
	var find: LineEdit = _sheet.get("_find")
	for typed: String in ["F9", "cut away", "list"]:
		find.text = typed
		find.text_changed.emit(typed)
		await _frames(10)
		await _shot("sheet_" + typed.replace(" ", "_").to_lower())
	find.text = ""
	find.text_changed.emit("")
	await _frames(6)
	await _press(KEY_ESCAPE)
	await _frames(4)


# -- helpers ---------------------------------------------------------------------

var _events: int = 0


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


## A key and its modifiers, down and up, as the window delivers them.
func _press(accel: int) -> void:
	_events += 1
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


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
