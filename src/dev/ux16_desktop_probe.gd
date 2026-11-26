## The studio on a desktop, a first hour of building, walked as three people
## would with a mouse and keys (unit ux16,
## bench/results/ux16-2026-11-26/WALK.md): a first-time builder making a small
## house from nothing (p19: the tour's Start, parts found by their words, put
## down, turned, coloured, copied, undone, saved and opened again), a builder
## changing a real set opened as their own version (p20: one part found in a
## 741-part castle, swapped, a sub-model moved, the steps followed back), and
## a builder meeting the newer features untold (p21: an edit at a step of the
## timeline, a part held and put back, Connect on a Technic axle, a minifigure
## with hair of their own). Each act is a click or a key where a person has
## one, and "UX16 reach" lines say how many clicks each common act takes from
## the menus, its key and whether the toolbar has it.
## Research, not in the suite: each step prints the walk's own "UX12 step"
## line (what covers the model, the status, the windows) and a picture;
## "UX16 check" lines judge what each act did. Exits 0 once every step is
## pictured, 1 when the app never came up.
##
##   godot --path . --resolution 1280x800 --script src/dev/ux16_desktop_probe.gd -- [--pictures=DIR] [--only=p19,p20,p21]
##   PROBE_SIZE=1920x1080 tools/probe.sh ux16_desktop_probe -- --pictures=DIR
extends "res://src/dev/ux15_phone_probe.gd"

## The words of the common acts a first hour needs, each by its command.
const COMMON := ["undo", "redo", "copy", "paste", "duplicate", "delete", "save", "open", "new",
	"paint", "replace", "find_replace", "select_find", "select_part", "select_connected",
	"make_submodel", "enter_assembly", "timeline", "step_prev", "step_next", "mode_rotate",
	"mode_hinge", "mode_connect", "minifig", "hide", "show_all", "fit_model", "parts_list"]

## King's Castle's black knight's helmet with a chin-guard, and the helmet
## with a neck protector the set's other knights wear.
const SWAP_FROM := "3896"
const SWAP_TO := "3844"

var _ux16_only: PackedStringArray = []
var _ux16_failures: int = 0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(2400.0).timeout.connect(func() -> void:
		print("UX16 cut off after 2400 s at step %d" % _steps)
		quit(2))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ux16_desktop_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	_out = "user://ux16_walk"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			_out = arg.trim_prefix("--pictures=")
		elif arg.begins_with("--only="):
			_ux16_only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	print("UX16 walk in a %d x %d window, mouse and keys" % [size.x, size.y])
	BuildSteps._kept.clear()
	# A first visit, as a person's first start of the app has it (the probe's
	# --script would otherwise offer nothing): the example car, the tour.
	FirstBuild.offered_for_probe = _wants16("p19")
	if not await _up(false):
		quit(1)
		return
	_reach()
	if _wants16("p19"):
		await _house()
	if _wants16("p20"):
		await _set_changed()
	if _wants16("p21"):
		await _newer()
	print("UX16 done: %d steps pictured, %d check(s) failed" % [_steps, _ux16_failures])
	quit(0)


func _wants16(section: String) -> bool:
	return _ux16_only.is_empty() or _ux16_only.has(section)


func _check16(what: String, ok: bool) -> void:
	print("UX16 check %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_ux16_failures += 1


## How each common act is reached: the menu path (its clicks), its key, and
## whether the toolbar has it.
func _reach() -> void:
	var toolbar: Dictionary = _shell.toolbar._buttons as Dictionary
	for name: String in COMMON:
		var path: Array = _path_to(name)
		var command: Shell.Command = _shell.command(name)
		var key: String = Keymap.listed(name) if command != null else ""
		print("UX16 reach %s | %s | %d clicks from the menus | key %s | toolbar %s" % [name,
			" › ".join(path) if not path.is_empty() else "in no menu", path.size(),
			key if not key.is_empty() else "none", "yes" if toolbar.has(name) else "no"])


## The menu path to [param name]: the menu's title, each submenu's words, the
## row's words.
func _path_to(name: String) -> Array:
	for menu: Array in Shell.MENUS:
		var found: Array = _path_in(menu[1] as Array, name)
		if not found.is_empty():
			return [str(menu[0])] + found
	return []


func _path_in(rows: Array, name: String) -> Array:
	for row: String in rows:
		if row == name:
			var command: Shell.Command = _shell.command(name)
			return [command.words if command != null else name]
		if row.begins_with(">"):
			var sub: String = row.substr(1)
			var inner: Array = _path_in(Shell.SUBMENUS.get(sub, []) as Array, name)
			if not inner.is_empty():
				return [sub] + inner
	return []


# -- keys and the pointer ---------------------------------------------------------


func _chord(code: Key, ctrl: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _press_named(named: Dictionary, name: String) -> bool:
	var control: Variant = named.get(name)
	if not (control is Control and (control as Control).is_visible_in_tree()):
		print("UX16: no %s in sight (%s)" % [name, ", ".join(named.keys())])
		return false
	await _click(_centre(control as Control))
	await _frames(10)
	return true


func _status() -> String:
	var status: StatusBar = _shell.get("status")
	return status.message.text.replace("\n", " ") if status != null and status.message != null else ""


func _hint() -> String:
	var verbs: EditVerbs = _main.get("_verbs")
	return verbs.hint().replace("\n", " ") if verbs != null else ""


## The status bar's line on the left as drawn: "" when it is whole, else how
## much of it the bar shows.
func _line_cut() -> String:
	var status: StatusBar = _shell.get("status")
	var label: Label = status.get("_hint") as Label if status != null else null
	if label == null or not label.is_visible_in_tree():
		return "no line shown"
	var font: Font = label.get_theme_font("font")
	var wide: float = font.get_string_size(label.atr(label.text), HORIZONTAL_ALIGNMENT_LEFT,
		-1, label.get_theme_font_size("font_size")).x
	if wide <= label.size.x + 1.0:
		return ""
	return "%d of its %d px shown: \"%s\"" % [roundi(label.size.x), roundi(wide), label.text]


## The pointer over [param at] on the floor, then a click: what is in hand
## goes down there, and stays in hand.
func _put_at(at: Vector3) -> void:
	var spot: Vector2 = _camera.unproject_position(at + Vector3(0, 8, 0))
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _frames(4)
	await _click(spot + Vector2(1, 0))
	await _frames(12)


func _count_of(part: String) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.get_basename() == part:
			count += 1
	return count


## A drag with the left button held, as a mouse sends it: each move says the
## button is down.
func _drag16(from: Vector2, to: Vector2, steps: int, release: bool = true) -> void:
	await _move(from)
	_button(from, true)
	await _frames(3)
	for n: int in steps:
		var event := InputEventMouseMotion.new()
		var at: Vector2 = from.lerp(to, float(n + 1) / steps)
		event.position = _as_event(at)
		event.global_position = event.position
		event.relative = _as_event(at - from.lerp(to, float(n) / steps))
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		await _frames(2)
	if release:
		_button(to, false)
		await _frames(6)


func _parts_count() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			count += 1
	return count


## The bin's search typed into as a person types: the field clicked, the
## words, the tiles shown.
func _find_in_bin(words: String, shot: String) -> void:
	var dock: SideDock = _main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
		await _frames(20)
	var search: LineEdit = _bin.get("_search")
	await _click(search.get_global_rect().get_center())
	search.text = words
	search.text_changed.emit(words)
	await create_timer(0.6).timeout
	await _frames(20)
	var grid: GridContainer = _bin.get("_grid")
	var first: Array = []
	for n: int in mini(6, grid.get_child_count()):
		var tile: Node = grid.get_child(n)
		var part: String = str(tile.get_meta("part", tile.get_meta("key", "?")))
		var info: PartLibrary.PartInfo = (_main.get("_library") as PartLibrary).parts.get(part)
		first.append("%s %s" % [part, info.name if info != null else ""])
	print("UX16 %s: \"%s\" first tiles: %s" % [shot, words, " | ".join(first)])
	await _step(shot, "the bin searched: " + words)


# -- p19: a first-time builder's small house -------------------------------------


func _house() -> void:
	print("\nUX16 p19: a first-time builder makes a small house from nothing")
	await _frames(30)
	# The tour is offered once the account has been looked for, up to
	# FirstBuild.LOOK_WAIT_MS after the studio is up: a person looking.
	var tour: Variant = _shell.get("first_build")
	var tour_named: Dictionary = {}
	var looked_from: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - looked_from < 15000:
		tour_named = (tour as Node).call("controls_by_name") if tour is Node else {}
		if tour_named.has("first_build_go"):
			break
		await _frames(10)
	await _frames(20)
	await _step("p19_01_first_open", "the studio as a first visit opens it")
	_check16("a first visit offers the tour (%s)" % ", ".join(tour_named.keys()),
		tour_named.has("first_build_go"))
	if tour_named.has("first_build_go"):
		await _press_named(tour_named, "first_build_go")
		await _until_still(60)
	await _step("p19_02_tour_start", "the tour's Start: a baseplate of its own")
	var empty: int = _parts_count()
	_check16("Start leaves an empty baseplate (%d parts)" % empty, empty == 0)
	# Parts found by their words.
	await _find_in_bin("brick 2 x 4", "p19_03_bin_brick")
	await _take_first_tile("p19_04_in_hand", "the first tile clicked: in hand")
	await _put_at(Vector3(0, 0, 0))
	await _step("p19_05_put_down", "a click on the baseplate")
	await _put_at(Vector3(80, 0, 0))
	await _put_at(Vector3(-80, 0, 0))
	await _step("p19_06_three", "two more clicks, a row of three")
	_check16("three clicks put three bricks down (%d)" % _parts_count(), _parts_count() == empty + 3)
	await _key(KEY_ESCAPE)
	await _frames(10)
	# Turned: the middle one clicked and R.
	var middle: BrickWorld.Brick = _brick_near(_camera.unproject_position(Vector3(0, 12, 0)))
	if middle != null:
		await _click(_camera.unproject_position(middle.transform.origin + Vector3(0, 12, 0)))
		await _frames(10)
	await _step("p19_07_selected", "the middle brick clicked")
	_check16("a click on a brick selects it (%d selected)" % _builder.selection.size(),
		_builder.selection.size() == 1)
	var was: Basis = middle.transform.basis if middle != null else Basis()
	await _key(KEY_R)
	await _frames(10)
	var now: BrickWorld.Brick = _world.get_brick(middle.id) if middle != null else null
	await _step("p19_08_turned", "R pressed")
	_check16("R turns the selected brick (%s)" % _status(), now != null
		and not now.transform.basis.is_equal_approx(was))
	# Coloured: a swatch of the bin's colours clicked.
	var swatches: Dictionary = _bin.get("_swatches")
	var colour_was: int = now.color_code if now != null else -1
	var wanted: int = 1 if colour_was != 1 else 4
	var swatch: Variant = swatches.get(wanted)
	var seen: bool = swatch is Control and (swatch as Control).is_visible_in_tree() \
		and root.get_visible_rect().encloses((swatch as Control).get_global_rect())
	_check16("the colours are in sight beside the bin (%s)" % ("blue" if wanted == 1 else "red"), seen)
	if seen:
		await _click((swatch as Control).get_global_rect().get_center())
		await _frames(12)
	now = _world.get_brick(middle.id) if middle != null else null
	await _step("p19_09_coloured", "a colour clicked with the brick selected")
	_check16("a colour clicked paints the selected brick (%d to %d)" % [colour_was,
		now.color_code if now != null else -1], now != null and now.color_code == wanted)
	# Copied: Ctrl+D, then Ctrl+C and Ctrl+V for one to put somewhere.
	var before_copy: int = _parts_count()
	await _chord(KEY_D, true)
	await _frames(20)
	await _step("p19_10_duplicated", "Ctrl+D")
	_check16("Ctrl+D puts a copy down (%d to %d)" % [before_copy, _parts_count()],
		_parts_count() == before_copy + 1)
	await _chord(KEY_Z, true)
	await _frames(20)
	await _step("p19_11_undone", "Ctrl+Z")
	_check16("Ctrl+Z takes the copy back (%d)" % _parts_count(), _parts_count() == before_copy)
	await _chord(KEY_Y, true)
	await _frames(20)
	var redo_y: int = _parts_count()
	if redo_y == before_copy:
		await _chord(KEY_Z, true, true)
		await _frames(20)
	await _step("p19_12_redone", "Ctrl+Y (then Ctrl+Shift+Z)")
	_check16("redo puts it back (Ctrl+Y %d, then %d)" % [redo_y, _parts_count()],
		_parts_count() == before_copy + 1)
	# The house: a door, a window, a roof, found by their words and put on.
	var top: float = 24.0
	await _find_in_bin("door", "p19_13_bin_door")
	await _take_first_tile("", "")
	await _put_at(Vector3(0, top, 0))
	await _step("p19_14_door", "a door put on the row")
	await _key(KEY_ESCAPE)
	await _find_in_bin("window", "p19_15_bin_window")
	await _take_first_tile("", "")
	await _put_at(Vector3(80, top, 0))
	await _step("p19_16_window", "a window put on the row")
	await _key(KEY_ESCAPE)
	await _find_in_bin("roof", "p19_17_bin_roof")
	await _find_in_bin("slope 2 x 4", "p19_18_bin_slope")
	await _take_first_tile("", "")
	await _put_at(Vector3(-80, top, 0))
	await _step("p19_19_roof", "a slope put on the row")
	await _key(KEY_ESCAPE)
	await _frames(10)
	var built: int = _parts_count()
	# Saved, by Ctrl+S.
	await _chord(KEY_S, true)
	await _frames(30)
	await _step("p19_20_save", "Ctrl+S")
	var asking: Variant = _bar.get("_ask_name")
	if asking is Window and (asking as Window).visible:
		var field: LineEdit = _bar.get("_ask_name_field")
		field.text = "My house"
		field.text_submitted.emit("My house")
		await _frames(30)
	await _until_still(20)
	await _step("p19_21_saved", "named My house if asked, saved")
	var saved: Array = []
	for entry: ModelStore.Entry in _store.list_saved():
		saved.append(entry.describe())
	_check16("saved: %s (%s)" % [", ".join(saved), _status()], not saved.is_empty())
	# Opened again: New, then Open's list.
	_shell.run("new")
	await _frames(30)
	await _answer_dont_save()
	await _until_still(30)
	await _step("p19_22_new", "File › New")
	await _chord(KEY_O, true)
	await _frames(20)
	await _step("p19_23_open_list", "Ctrl+O: the Open list")
	var saves: PopupMenu = _bar.get("_saves")
	var row: int = -1
	for n: int in saves.item_count:
		if saves.get_item_id(n) >= 0 and saves.get_item_id(n) < 1000 \
				and not saves.is_item_separator(n) and not saves.is_item_disabled(n):
			row = n
			break
	print("UX16 open list: %s" % ", ".join(range(saves.item_count).map(
		func(n: int) -> String: return saves.get_item_text(n))))
	if row >= 0:
		saves.id_pressed.emit(saves.get_item_id(row))
		saves.hide()
		await _answer_dont_save()
		await _until_still(60)
	await _step("p19_24_reopened", "the save clicked in Open's list")
	_check16("opened again whole (%d of %d parts, %s)" % [_parts_count(), built, _store.title],
		_parts_count() == built)
	await _close_all()


# -- p20: a real set, changed ----------------------------------------------------


func _set_changed() -> void:
	print("\nUX16 p20: a builder changes a real set opened as their own version")
	await _close_all()
	var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/6080-1.mpd")
	_store.keeps = false
	_main.call("clear_model")
	await _frames(10)
	await _bar.open_text_with_progress(text, "King's Castle")
	_bar.opened.emit(_world.brick_count())
	await _until_still(240)
	await _step("p20_01_opened", "King's Castle opened as their own version")
	# One part found: the castle's door. Ctrl+F first, as every other program
	# finds with it.
	await _chord(KEY_F, true)
	await _frames(20)
	var focus: Control = root.gui_get_focus_owner()
	await _step("p20_02_ctrl_f", "Ctrl+F, to find the door")
	print("UX16 Ctrl+F: focus %s, status \"%s\"" % [_name(focus) if focus != null else "none", _status()])
	_check16("Ctrl+F offers a way to find something (focus %s)" % (_name(focus) if focus != null else "none"),
		focus is LineEdit)
	# "helmet" typed and Enter, as the field asks.
	if focus is LineEdit:
		(focus as LineEdit).text = "helmet chin"
		(focus as LineEdit).text_changed.emit("helmet chin")
		await _frames(20)
		await _step("p20_03_find_parts", "\"helmet chin\" typed in the finder")
		(focus as LineEdit).text_submitted.emit("helmet chin")
		await _frames(30)
	var found: int = _builder.selection.size()
	var covered: Dictionary = _main.call("model_cover", 24, 16)
	await _step("p20_03b_found", "Enter: the helmet found")
	_check16("Enter selects what was found and shows it (%d selected, %d%% of the model covered, %s)" % [
		found, roundi(100.0 * (covered["covered"] as Array).size() / maxf(1.0, float(covered["samples"]))),
		_status()], found >= 1 and (covered["covered"] as Array).size() * 4 < int(covered["samples"]))
	await _close_all()
	# The knight's helmet with a chin-guard, swapped for one with a neck
	# protector: clicked, gone inside its figure, another in hand, Replace.
	var door: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with(SWAP_FROM):
			door = brick
			break
	var had: Array = [_count_of(SWAP_FROM), _count_of(SWAP_TO)]
	_check16("the castle has the helmet (%s)" % SWAP_FROM, door != null)
	if door != null:
		_camera.frame(AABB(door.transform.origin - Vector3(60, 60, 60), Vector3(120, 120, 120)), 1.6)
		await _frames(30)
		await _click(_camera.unproject_position(door.transform.origin))
		await _frames(15)
	await _step("p20_04_door_clicked", "the door clicked")
	var took: int = _builder.selection.size()
	print("UX16 door click took %d (%s) hint \"%s\"" % [took, _status(), _hint()])
	# A click takes the whole sub-assembly, as Studio's does; the words must
	# say how to get inside it (ux16 kept this, and said why in WALK.md).
	_check16("a click on the door takes the door, or says how to (%d, %s)" % [took, _status()],
		took == 1 or _status().contains("double-click edits inside"))
	# Down to the door alone, as the line says.
	if took > 1:
		await _key(KEY_ENTER)
		await _frames(20)
		if door != null:
			await _click(_camera.unproject_position(door.transform.origin))
			await _frames(15)
		await _step("p20_05_inside", "Enter, then the door clicked again")
		_check16("inside, a click takes the door alone (%d)" % _builder.selection.size(),
			_builder.selection.size() == 1)
	# Right-click: its menu, for Replace.
	if door != null:
		var at: Vector2 = _camera.unproject_position(door.transform.origin)
		await _move(at)
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.position = _as_event(at)
		right.global_position = right.position
		right.pressed = true
		Input.parse_input_event(right)
		await _frames(3)
		right = right.duplicate()
		right.pressed = false
		Input.parse_input_event(right)
		await _frames(20)
	await _step("p20_06_right_click", "the door right-clicked: its menu")
	var menu_rows: Array = []
	for window: Window in _windows(root):
		if window is PopupMenu and window.visible:
			for n: int in (window as PopupMenu).item_count:
				menu_rows.append((window as PopupMenu).get_item_text(n))
	print("UX16 the part's menu: %s" % " | ".join(menu_rows))
	_check16("its menu offers to replace it (%s)" % ", ".join(menu_rows.filter(
		func(row: String) -> bool: return row.to_lower().contains("replace"))),
		menu_rows.any(func(row: String) -> bool: return row.to_lower().contains("replace")))
	await _key(KEY_ESCAPE)
	await _frames(10)
	var selected_door: Array = _builder.selection.keys()
	await _find_in_bin("helmet castle", "p20_07_bin_doors")
	var grid: GridContainer = _bin.get("_grid")
	var other: Control = null
	for tile: Node in grid.get_children():
		if tile is Control and (tile as Control).is_visible_in_tree() and tile.has_meta("part") \
				and str(tile.get_meta("part")) == SWAP_TO:
			other = tile
			break
	if other != null:
		await _click(other.get_global_rect().get_center())
		await _frames(15)
	await _step("p20_08_other_door", "another door clicked in the bin")
	print("UX16 after the bin's click: selection %d, in hand %s, hint \"%s\"" % [
		_builder.selection.size(), _builder.held_part, _hint()])
	_check16("the door stays selected with another in hand (%d, %s)" % [_builder.selection.size(),
		_builder.held_part], _builder.selection.size() == selected_door.size()
		and not selected_door.is_empty())
	var can_replace: bool = _shell.can("replace")
	_check16("Replace with the part in hand is there to run (%s)" % _shell.why_not("replace")
		if not can_replace else "Replace with the part in hand is there to run", can_replace)
	if can_replace:
		_shell.run("replace")
		await _frames(30)
	await _step("p20_09_replaced", "Edit › Replace with the part in hand")
	var has: Array = [_count_of(SWAP_FROM), _count_of(SWAP_TO)]
	var swapped: int = had[0] - has[0]
	_check16("the helmet is swapped (%s: %d to %d, %s: %d to %d; %s)" % [SWAP_FROM, had[0], has[0],
		SWAP_TO, had[1], has[1], _status()], swapped >= 1 and has[1] == had[1] + swapped)
	# A sub-model's copies are one definition, as in Studio and LeoCAD: the
	# line says how many more changed with it.
	if swapped > 1:
		_check16("the words say the other copies changed too (%s)" % _status(),
			_status().contains("%d parts more in its other copies" % (swapped - 1)))
	await _key(KEY_ESCAPE)
	await _close_all()
	# A sub-model moved: the drawbridge's rope or the flag, whole.
	_shell.run("leave_assembly")
	await _frames(10)
	_shell.run("fit_model")
	await _frames(30)
	var flag: BrickWorld.Brick = null
	var subs: Dictionary = {}
	var assemblies: Variant = _main.get("_assemblies")
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3957"):
			flag = brick
	if flag != null:
		await _click(_camera.unproject_position(flag.transform.origin))
		await _frames(15)
	var group: Array = _builder.selection.keys()
	print("UX16 flag click: %d selected, \"%s\"" % [group.size(), _status()])
	await _step("p20_10_sub_clicked", "the flag's pole clicked")
	var starts: Dictionary = {}
	for id: int in group:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		if brick != null:
			starts[id] = brick.transform.origin
	if flag != null:
		var from: Vector2 = _camera.unproject_position(flag.transform.origin)
		await _drag16(from, from + Vector2(120, 40), 12)
		await _frames(20)
	var moved: int = 0
	for id: int in starts:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		if brick != null and brick.transform.origin.distance_to(starts[id]) > 1.0:
			moved += 1
	await _step("p20_11_sub_moved", "dragged along the wall")
	print("UX16 sub-model drag: %d of %d moved, \"%s\"" % [moved, starts.size(), _status()])
	var history_was: int = _builder.history_depth()
	if moved == 0 and flag != null:
		# A wall on its hinge pin, in a loop with the rest: a drag moves it
		# as the real one moves, which here is not at all. The line says
		# the way to move it anywhere, and the person takes it.
		_check16("a drag refused says how to move it anyway (%s)" % _status(),
			_status().contains("X takes it into hand"))
		await _key(KEY_X)
		await _frames(15)
		var to: Vector2 = _camera.unproject_position(flag.transform.origin) + Vector2(120, 40)
		await _move(to)
		await _frames(15)
		await _click(to)
		await _frames(30)
		for id: int in starts:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick != null and brick.transform.origin.distance_to(starts[id]) > 1.0:
				moved += 1
		await _step("p20_11b_sub_lifted", "X, as the line says, and a click further along")
	_check16("the sub-model moves whole (%d of %d moved, %s)" % [moved, starts.size(), _status()],
		moved == starts.size() and moved > 1)
	if _builder.history_depth() > history_was or moved > 0:
		await _chord(KEY_Z, true)
		await _frames(20)
	# The steps followed back.
	await _key(KEY_B)
	var steps: StepsBar = _bar_()
	var since: int = Time.get_ticks_msec()
	while (steps.is_starting() or not steps.is_playing_back()) and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _frames(30)
	# Step 1 first, as a booklet opens: said, not checked (WALK.md).
	var opened: Vector2i = steps.timeline_at()
	await _step("p20_12_timeline", "B: the timeline")
	print("UX16 the timeline opened at step %d, %d of %d parts shown" % [_at(), opened.x, opened.y])
	# To the end, as the person goes to follow the steps back. Left steps
	# a sub-model's own steps inside the last step too: counted in parts.
	await _key(KEY_END)
	await _frames(20)
	var at_end: int = steps.timeline_at().x
	_check16("End shows the whole model (%d of %d)" % [at_end, opened.y], at_end == opened.y)
	for _n: int in 3:
		await _key(KEY_LEFT)
		await _frames(15)
	await _step("p20_13_back3", "Left three times")
	_check16("Left steps back (%d to %d parts, step %d)" % [at_end, steps.timeline_at().x, _at()],
		steps.timeline_at().x < at_end)
	await _leave_steps()
	await _close_all()


# -- p21: the newer features, unannounced ----------------------------------------


func _newer() -> void:
	print("\nUX16 p21: a builder meets the newer features without being told")
	await _close_all()
	# An edit at a step of the timeline.
	await _open_model("res://models/kart.ldr", "Kart")
	await _key(KEY_B)
	var steps: StepsBar = _bar_()
	var since: int = Time.get_ticks_msec()
	while (steps.is_starting() or not steps.is_playing_back()) and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _frames(30)
	for _n: int in 4:
		await _key(KEY_RIGHT)
		await _frames(10)
	var all_parts: int = _parts_count()
	var shown: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and not brick.hidden:
			shown.append(brick)
	await _step("p21_01_at_step", "the timeline at step %d" % _at())
	var target: BrickWorld.Brick = null
	if not shown.is_empty():
		target = shown[shown.size() - 1]
		await _click(_camera.unproject_position(target.transform.origin))
		await _frames(15)
	await _step("p21_02_step_selected", "a part of this step clicked")
	print("UX16 at a step: %d selected, status \"%s\", hint \"%s\"" % [_builder.selection.size(),
		_status(), _hint()])
	var picked: int = _builder.selection.size()
	if picked > 0:
		var colour: int = 4
		var swatch: Variant = (_bin.get("_swatches") as Dictionary).get(colour)
		if swatch is Control and (swatch as Control).is_visible_in_tree():
			await _click((swatch as Control).get_global_rect().get_center())
			await _frames(15)
	await _step("p21_03_step_painted", "a colour clicked at the step")
	_check16("an edit at a step changes what the step shows (%d selected, %s)" % [picked, _status()],
		picked > 0 and _parts_count() == all_parts)
	await _leave_steps()
	await _close_all()
	# A part held and put back: clicked, X as the line says, then Esc.
	var brick: BrickWorld.Brick = _brick_near(_model_middle())
	if brick != null:
		await _click(_camera.unproject_position(brick.transform.origin))
		await _frames(10)
		if not _builder.selection.is_empty():
			brick = _world.get_brick(int(_builder.selection.keys()[0]))
	var home: Transform3D = brick.transform if brick != null else Transform3D()
	await _step("p21_04_clicked", "a part of the kart clicked")
	print("UX16 clicked to hold: %d selected, status \"%s\"" % [_builder.selection.size(), _status()])
	if brick != null:
		await _key(KEY_X)
		await _frames(10)
		var away: Vector2 = _camera.unproject_position(home.origin) + Vector2(60, -30)
		await _move(away)
		await _frames(10)
		await _step("p21_05_held", "X: the part in hand")
		print("UX16 holding: in hand %s, status \"%s\", hint \"%s\"" % [_builder.is_carrying(),
			_status(), _hint()])
		_check16("X takes it into hand (%s)" % _builder.is_carrying(), _builder.is_carrying())
		_check16("while held, the words say how to put it back (%s | %s)" % [_status(), _hint()],
			(_status() + _hint()).to_lower().contains("esc"))
		await _key(KEY_ESCAPE)
		await _frames(20)
		var back: BrickWorld.Brick = _world.get_brick(brick.id)
		await _step("p21_06_put_back", "Esc while held")
		_check16("Esc puts it back where it was (%s)" % _status(), back != null
			and back.transform.origin.distance_to(home.origin) < 0.5 and not _builder.is_carrying())
	await _close_all()
	# Connect on a Technic axle.
	_main.call("clear_model")
	await _frames(20)
	await _find_in_bin("technic beam 5", "p21_07_bin_beam")
	await _take_first_tile("", "")
	await _put_at(Vector3(0, 0, 0))
	await _key(KEY_ESCAPE)
	await _frames(10)
	var beam: BrickWorld.Brick = _newest_brick()
	if beam != null:
		_camera.frame(AABB(beam.transform.origin - Vector3(80, 40, 80), Vector3(160, 80, 160)), 1.4)
		await _frames(30)
	await _find_in_bin("technic axle 4", "p21_08_bin_axle")
	await _take_first_tile("", "")
	if beam != null:
		await _move(_camera.unproject_position(beam.transform.origin + Vector3(0, 12, 0)))
		await _frames(10)
	await _step("p21_09_axle_over_beam", "an axle in hand over the beam")
	print("UX16 axle in hand: status \"%s\", hint \"%s\"" % [_status(), _hint()])
	_check16("the words name Connect with an axle in hand (%s)" % _hint(),
		_hint().contains("Connect") or _status().contains("Connect"))
	# Said is not shown: at 1280 the line was cut after the part's names.
	var cut: String = _line_cut()
	_check16("the joint's line is drawn whole (%s)" % ("whole" if cut.is_empty() else cut),
		cut.is_empty())
	await _key(KEY_N)
	await _frames(20)
	await _step("p21_10_connect", "N: Connect")
	var verbs: EditVerbs = _main.get("_verbs")
	print("UX16 Connect: mode %s, stage %s, %d points, hint \"%s\"" % [verbs.mode,
		verbs.connect_tool.stage, verbs.connect_tool.screen_points().size(), _hint()])
	_check16("N lights the axle's points (%d)" % verbs.connect_tool.screen_points().size(),
		verbs.connect_tool.screen_points().size() > 0)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _close_all()
	# A minifigure with hair of their own.
	_shell.run("minifig")
	await _frames(40)
	var dialog: Node = _main.get("_figures")
	await _step("p21_11_minifig", "Make › Minifigure…")
	var named: Dictionary = dialog.call("controls_by_name") if dialog != null else {}
	print("UX16 figure builder: %s" % ", ".join(named.keys()))
	if await _press_named(named, "minifig_headwear"):
		await _frames(20)
	await _step("p21_12_headgear", "Headgear chosen")
	named = dialog.call("controls_by_name") if dialog != null else {}
	var make: Variant = named.get("minifig_make")
	_check16("Headgear offers Make a mould… in sight (%s)" % ((make as Button).text if make is Button else "none"),
		make is Button and (make as Button).is_visible_in_tree())
	if await _press_named(named, "minifig_make"):
		await _frames(60)
	await _step("p21_13_mould", "Make a mould…")
	named = dialog.call("controls_by_name") if dialog != null else {}
	var view: Variant = named.get("mould_view")
	if view is Control:
		var middle: Vector2 = _centre(view as Control)
		await _drag(middle + Vector2(0, -20), middle + Vector2(0, -70), 10)
		await _frames(20)
	await _step("p21_14_stroke", "a drag on the hair")
	var name_field: Variant = named.get("mould_name")
	if name_field is LineEdit:
		(name_field as LineEdit).text = "Spiky"
		(name_field as LineEdit).text_changed.emit("Spiky")
	if await _press_named(named, "mould_save"):
		await _frames(60)
	await _step("p21_15_saved_mould", "Save mould")
	named = dialog.call("controls_by_name") if dialog != null else {}
	var figure: Variant = dialog.get("figure") if dialog != null else null
	var hair: String = (figure as Minifig).part("headwear") if figure is Minifig else ""
	_check16("the figure wears the mould (%s)" % hair, hair.begins_with("mould") or hair.contains("custom")
		or not hair.is_empty() and not hair.begins_with("3901"))
	if await _press_named(named, "minifig_place"):
		await _frames(30)
	if _builder.is_carrying():
		await _put_at(Vector3(0, 0, 60))
	await _step("p21_16_placed", "Place in model, a click")
	await _key(KEY_ESCAPE)
	await _close_all()
