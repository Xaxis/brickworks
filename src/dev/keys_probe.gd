## Keys: every tool has one, Studio's keys as a preset, and a key set in the
## keys sheet that outlives a restart (APP_UX A11).
##
##   tools/probe.sh keys_probe
##   godot --path . --resolution 1280x720 --script src/dev/keys_probe.gd
##   ... -- --shots=DIR    each step pictured there
##
## Every key is pressed as a person presses it, an input event to the
## window, and each check reads what the key did to the model, the view or
## the tool, so a key bound to nothing fails:
## - the app's own keys: each of the twelve tools by its key, and C with
##   nothing selected painting nothing;
## - Keys like BrickLink Studio, chosen in the keys sheet: Studio's own keys
##   (V, H, C, L, Ctrl-L, Ctrl-Shift-L, Ctrl-Shift-V, WASD, the arrows, Shift
##   and an arrow, Ctrl-G, Ctrl-U, Ctrl-T, Ctrl-0, Ctrl-= and -, Ctrl-F) each
##   doing what Studio's does;
## - Mecabricks' W, D and M, and LDCad's M, C, Z, V, H and Insert;
## - a key set in the sheet by clicking the Paint tool's key and pressing
##   Shift-B, which then takes the Paint tool; a key that is another's
##   refused with whose it is, and Tab refused;
## - and the app started again, in a run of its own on the same data folder:
##   Shift-B is still the Paint tool there.
##
## The data folder is the run's own (probe.sh gives one), where the keys are
## written as the app writes them; a run with no folder of its own does not
## write the person's, and says so.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _camera: CadCamera
var _sheet: ControlsDialog
var _shots: String = ""
var _step: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var after_restart: bool = OS.get_cmdline_user_args().has("--after-restart")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	# Written as the app writes them, in this run's own folder only.
	var own_folder: bool = _own_data_folder()
	ShellPrefs.kept_by_a_check = own_folder
	if not after_restart and DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  keys probe: SKIPPED — the window did not come up")
		quit(3)
		return
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_camera = _main.get("_camera")
	_sheet = _main.get("_controls")
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(30)

	if after_restart:
		await _after_restart()
	else:
		var window := DisplayServer.window_get_size()
		print("  a %d x %d window" % [window.x, window.y])
		await _own_keys()
		await _studio()
		await _mecabricks_and_ldcad()
		await _set_a_key()
		await _restart(own_folder)

	print("")
	if _failures == 0:
		print("keys probe: all checks passed")
	else:
		print("keys probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## Whether user:// is this run's own (probe.sh's XDG_DATA_HOME), never the
## person's.
func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


# -- the app's own keys ----------------------------------------------------------

func _own_keys() -> void:
	print("\n  the app's own keys: a key for every tool")
	_check("the preset is the app's own (%s)" % Keymap.preset(), Keymap.preset() == "brickworks")
	_scene()
	for tool: String in EditVerbs.MODES:
		if tool == "place":
			continue
		var key: int = Keymap.key_of("mode_" + tool)
		# From another tool, so the key is seen to change it.
		_verbs.set_mode("zoom" if tool != "zoom" else "select")
		await _press(key)
		_check("%s takes the %s tool (%s)" % [Keymap.listed_key(key), tool, _verbs.mode],
			key != 0 and _verbs.mode == tool)
	await _press(KEY_ESCAPE)
	_verbs.set_mode("select")
	# C paints the selection only: with nothing selected, nothing.
	_builder.clear_selection()
	_builder.held_color = 1
	var colours: Dictionary = _colours()
	await _press(KEY_C)
	var said: String = _said()
	_check("C with nothing selected paints nothing (%s) and says what to do: \"%s\""
		% [str(_colours()), said], _colours() == colours and said.contains("select parts"))
	_select(_ids()[0])
	await _press(KEY_C)
	_check("...and with a part selected, paints it (%s)" % str(_colours()),
		_colours() != colours)
	await _shot("own_keys")


# -- BrickLink Studio's ----------------------------------------------------------

func _studio() -> void:
	print("\n  Keys like BrickLink Studio, chosen in the keys sheet")
	await _press(KEY_F1)
	await _frames(10)
	_check("F1 opens the keys sheet", _sheet.visible)
	# Its choice clicked open, and the arrows down to Studio and Return, as
	# from the keys.
	var choice: OptionButton = _sheet.keys_choice
	await _click(choice.get_global_rect().get_center())
	await _frames(6)
	var popup: PopupMenu = choice.get_popup()
	print("    the choice open: %s, on its row %d" % [popup.visible, popup.get_focused_item()])
	for _n: int in Keymap.PRESETS.find("studio") - popup.get_focused_item():
		await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	await _frames(6)
	_check("Keys like: BrickLink Studio (%s)" % Keymap.preset(), Keymap.preset() == "studio")
	var rows: String = _sheet_words()
	_check("the sheet says Studio's C, H and L: the Clone, Hinge and Hide tools",
		rows.contains("C the Clone tool") and rows.contains("H the Hinge tool")
		and rows.contains("L the Hide tool"))
	await _shot("sheet_studio")
	await _press(KEY_ESCAPE)
	await _frames(4)
	_check("Escape closes it", not _sheet.visible)

	_scene()
	var ids: Array = _ids()
	# The tools.
	for pair: Array in [[KEY_V, "select"], [KEY_H, "hinge"], [KEY_C, "clone"], [KEY_L, "hide"]]:
		_verbs.set_mode("zoom")
		await _press(pair[0])
		_check("%s: the %s tool (%s)" % [OS.get_keycode_string(pair[0]), pair[1], _verbs.mode],
			_verbs.mode == pair[1])
	await _press(KEY_ESCAPE)
	_verbs.set_mode("select")
	# Hiding.
	_select(ids[0])
	await _press(KEY_L, CTRL)
	_check("Ctrl-L hides the selection", _builder.lattice.unseen.has(ids[0]))
	await _press(KEY_L, CTRL | SHIFT)
	_check("Ctrl-Shift-L shows everything", _builder.lattice.unseen.is_empty())
	# Invert.
	_select(ids[0])
	await _press(KEY_V, CTRL | SHIFT)
	_check("Ctrl-Shift-V inverts the selection (%d selected, not the first)"
		% _builder.selection.size(),
		not _builder.selection.has(ids[0]) and _builder.selection.size() == ids.size() - 1)
	# WASD move the selection.
	_select(ids[1])
	for pair: Array in [[KEY_W, "W"], [KEY_A, "A"], [KEY_S, "S"], [KEY_D, "D"]]:
		var was: Vector3 = _at(ids[1])
		await _press(pair[0])
		_check("%s moves the selection (%s to %s)" % [pair[1], _short(was), _short(_at(ids[1]))],
			not _at(ids[1]).is_equal_approx(was))
	# The arrows turn and tip it.
	var basis: Basis = _basis(ids[1])
	await _press(KEY_RIGHT)
	_check("Right turns the selection", not _basis(ids[1]).is_equal_approx(basis))
	await _press(KEY_LEFT)
	_check("...Left turns it back", _basis(ids[1]).is_equal_approx(basis))
	await _press(KEY_UP)
	_check("Up tips it forward", not _basis(ids[1]).is_equal_approx(basis))
	await _press(KEY_DOWN)
	_check("...Down tips it back", _basis(ids[1]).is_equal_approx(basis))
	var yaw: float = _yaw(ids[1])
	await _press(KEY_RIGHT, SHIFT)
	_check("Shift-Right turns it 45° (%.0f° to %.0f°)" % [yaw, _yaw(ids[1])],
		is_equal_approx(absf(wrapf(_yaw(ids[1]) - yaw, -180.0, 180.0)), 45.0))
	await _press(KEY_LEFT, SHIFT)
	# A sub-model, and back.
	_select(ids[0])
	_builder.select_brick(ids[1], true)
	await _press(KEY_G, CTRL)
	var naming: ConfirmationDialog = _verbs.get("_naming")
	_check("Ctrl-G asks a sub-model's name", naming != null and naming.visible)
	if naming != null and naming.visible:
		naming.hide()
		naming.confirmed.emit()
		await _frames(4)
	var grouped: String = Assemblies.path_of(_world.get_brick(ids[0]))
	_check("...and makes one (%s)" % grouped, not grouped.is_empty())
	_select(ids[0])
	await _press(KEY_U, CTRL)
	_check("Ctrl-U releases it (%s)" % Assemblies.path_of(_world.get_brick(ids[0])),
		Assemblies.path_of(_world.get_brick(ids[0])).is_empty())
	# A step from the selection: Studio's Ctrl-T, which a browser keeps.
	_select(ids[2])
	var depth: int = _builder.history_depth()
	await _press(KEY_T, CTRL)
	await _frames(6)
	_check("Ctrl-T adds a step (a change to undo: %d to %d)" % [depth, _builder.history_depth()],
		_builder.history_depth() == depth + 1)
	# The view.
	_builder.clear_selection()
	var framed: float = _distance()
	_camera.set("_target_distance", framed * 4.0)
	await _frames(4)
	await _press(KEY_0, CTRL)
	await _frames(30)
	_check("Ctrl-0 zooms to fit (%.0f, from %.0f)" % [_distance(), framed * 4.0],
		_distance() < framed * 2.0)
	var far: float = _distance()
	await _press(KEY_EQUAL, CTRL)
	_check("Ctrl-= zooms in (%.0f to %.0f)" % [far, _distance()], _distance() < far)
	far = _distance()
	await _press(KEY_MINUS, CTRL)
	_check("Ctrl-- zooms out (%.0f to %.0f)" % [far, _distance()], _distance() > far)
	await _press(KEY_F, CTRL)
	var focused: Control = root.gui_get_focus_owner()
	_check("Ctrl-F puts the keys in the parts' search (%s)" % [focused], focused is LineEdit)
	if focused != null:
		focused.release_focus()
	# What Studio does not have is not where the app's own was.
	_verbs.set_mode("select")
	await _press(KEY_H)
	_check("H is no longer the Pan tool (%s)" % _verbs.mode, _verbs.mode != "pan")
	await _press(KEY_ESCAPE)
	_select(ids[0])
	await _press(KEY_L)
	_check("...nor L the lock (%d locked)" % _builder.locked.size(), _builder.locked.is_empty())
	await _press(KEY_ESCAPE)
	await _shot("studio_keys")


# -- Mecabricks' and LDCad's -----------------------------------------------------

func _mecabricks_and_ldcad() -> void:
	print("\n  Keys like Mecabricks, then LDCad")
	Keymap.use("mecabricks")
	_scene()
	for pair: Array in [[KEY_W, "select"], [KEY_D, "clone"], [KEY_M, "move"],
			[KEY_S, "connect"]]:
		_verbs.set_mode("zoom")
		await _press(pair[0])
		_check("Mecabricks' %s: the %s tool (%s)" % [OS.get_keycode_string(pair[0]), pair[1],
			_verbs.mode], _verbs.mode == pair[1])
	await _press(KEY_ESCAPE)
	_check("...and D held slides no view: it is the Clone tool's",
		not Keymap.held_as_ever(KEY_D))
	_check("...nor S: it is Connect's", not Keymap.held_as_ever(KEY_S))
	Keymap.use("ldcad")
	_scene()
	var ids: Array = _ids()
	_verbs.set_mode("zoom")
	await _press(KEY_M)
	_check("LDCad's M: the Move tool (%s)" % _verbs.mode, _verbs.mode == "move")
	await _press(KEY_ESCAPE)
	_verbs.set_mode("select")
	var square: bool = _camera.is_square_on()
	await _press(KEY_V)
	_check("V switches the projection", _camera.is_square_on() != square)
	await _press(KEY_V)
	_select(ids[0])
	var focus: Vector3 = _camera.get("_target_focus")
	await _press(KEY_C)
	await _frames(20)
	_check("C centres on the selection", not (_camera.get("_target_focus") as Vector3)
		.is_equal_approx(focus))
	_camera.set("_target_distance", _distance() * 4.0)
	var far: float = _distance()
	await _press(KEY_Z)
	await _frames(20)
	_check("Z fits the model (%.0f, from %.0f)" % [_distance(), far], _distance() < far)
	_select(ids[0])
	await _press(KEY_H)
	_check("H hides the selection", _builder.lattice.unseen.has(ids[0]))
	await _press(KEY_H, CTRL | SHIFT)
	_check("Ctrl-Shift-H shows everything", _builder.lattice.unseen.is_empty())
	await _press(KEY_INSERT)
	_check("Insert puts the last part in hand (%s)" % _verbs.mode, _verbs.mode == "place")
	await _press(KEY_ESCAPE)
	Keymap.use("brickworks")


# -- a key set in the sheet ------------------------------------------------------

func _set_a_key() -> void:
	print("\n  a key set in the keys sheet")
	await _press(KEY_F1)
	await _frames(10)
	var chip: Control = _sheet.controls_by_name().get("key_mode_paint")
	_check("the Paint tool's key is on the sheet (%s)" % (chip.tooltip_text if chip else "none"),
		chip != null)
	if chip == null:
		return
	await _click_chip(chip)
	await _shot("press_a_key")
	await _press(KEY_B, SHIFT)
	await _frames(4)
	var said: String = (_sheet.get("_said") as Label).text
	_check("clicked, then Shift-B: the Paint tool's key (%s), and said: \"%s\""
		% [Keymap.listed("mode_paint"), said], Keymap.key_of("mode_paint") == SHIFT | KEY_B
		and said.contains("shift-B"))
	await _shot("key_set")
	var rotate: int = Keymap.key_of("mode_rotate")
	chip = _sheet.controls_by_name().get("key_mode_rotate")
	await _click_chip(chip)
	await _press(KEY_B, SHIFT)
	said = (_sheet.get("_said") as Label).text
	_check("Shift-B for the Rotate tool is refused, saying whose it is: \"%s\"" % said,
		Keymap.key_of("mode_rotate") == rotate and said.contains("already the key for Paint tool"))
	await _shot("key_refused")
	chip = _sheet.controls_by_name().get("key_mode_rotate")
	await _click_chip(chip)
	await _press(KEY_TAB)
	said = (_sheet.get("_said") as Label).text
	_check("...and Tab, kept for itself: \"%s\"" % said,
		Keymap.key_of("mode_rotate") == rotate and said.contains("kept for itself"))
	await _press(KEY_ESCAPE)
	await _frames(4)
	_check("Escape closes the sheet", not _sheet.visible)
	_verbs.set_mode("select")
	await _press(KEY_B, SHIFT)
	_check("Shift-B takes the Paint tool (%s)" % _verbs.mode, _verbs.mode == "paint")
	await _press(KEY_ESCAPE)
	var shell: Shell = _main.get("_shell")
	var tip: String = (shell.toolbar.get("_buttons")["mode_paint"] as Control).tooltip_text
	_check("the toolbar's Paint says it: \"%s\"" % tip.get_slice("\n", 0), tip.contains("Shift+B"))


# -- started again ---------------------------------------------------------------

func _restart(own_folder: bool) -> void:
	print("\n  the app started again")
	if not own_folder:
		_check("a data folder of this run's own to write the keys in (run by tools/probe.sh)",
			false)
		return
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/keys_probe.gd",
		"--", "--after-restart"], output, true)
	var lines: PackedStringArray = "\n".join(output).split("\n")
	for line: String in lines:
		if line.begins_with("  ok") or line.begins_with("  FAIL"):
			print("  " + line)
	_check("a run of its own, on the same data folder, passed (exit %d)" % code, code == 0)


func _after_restart() -> void:
	_check("Shift-B is still the Paint tool's (%s)" % Keymap.listed("mode_paint"),
		Keymap.key_of("mode_paint") == SHIFT | KEY_B)
	_verbs.set_mode("select")
	await _press(KEY_B, SHIFT)
	_check("...and takes it (%s)" % _verbs.mode, _verbs.mode == "paint")


# -- helpers ---------------------------------------------------------------------

const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT


## Three bricks up off the baseplate, with room all round to turn and tip.
func _scene() -> void:
	_main.call("clear_model")
	for n: int in 3:
		var where := Transform3D(Basis.IDENTITY, Vector3(-120 + n * 120, 24 * 6, 0))
		var brick_id: int = _world.add_brick("3001", 4, where)
		_builder.register(brick_id, "3001", where)
	_builder.clear_selection()


func _ids() -> Array:
	var store: ModelStore = _main.get("_store")
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not store.scenery.has(b.id)).map(func(b: BrickWorld.Brick) -> int: return b.id)


func _select(brick_id: int) -> void:
	_builder.clear_selection()
	_builder.select_brick(brick_id, false)


func _colours() -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in _ids():
		out[brick_id] = _world.get_brick(brick_id).color_code
	return out


func _at(brick_id: int) -> Vector3:
	return _world.get_brick(brick_id).transform.origin


func _basis(brick_id: int) -> Basis:
	return _world.get_brick(brick_id).transform.basis.orthonormalized()


func _yaw(brick_id: int) -> float:
	return rad_to_deg(_basis(brick_id).get_euler().y)


func _short(at: Vector3) -> String:
	return "(%d, %d, %d)" % [roundi(at.x), roundi(at.y), roundi(at.z)]


func _distance() -> float:
	return float(_camera.get("_target_distance"))


func _said() -> String:
	return (_main.get("_bar").get("_status") as Label).text


## Every row of the sheet as "keys words", one a line.
func _sheet_words() -> String:
	var out: PackedStringArray = []
	for row: Node in _sheet.find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() == 3 and row.get_child(2) is Label \
				and row.get_child(1) is CenterContainer and (row as Control).is_visible_in_tree():
			var keys: PackedStringArray = []
			for key: Control in row.get_child(0).get_children():
				keys.append(key.tooltip_text)
			out.append("%s %s" % [" ".join(keys), (row.get_child(2) as Label).text])
	return "\n".join(out)


## A key and its modifiers, down and up, as the window delivers them.
func _press(accel: int, mods: int = 0) -> void:
	accel |= mods
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


## A key's chip on the sheet, scrolled into sight as a person would, then
## clicked.
func _click_chip(chip: Control) -> void:
	(_sheet.get("_keys") as ScrollContainer).ensure_control_visible(chip)
	await _frames(4)
	await _click(chip.get_global_rect().get_center())


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	if _shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	_step += 1
	var path: String = _shots.path_join("%02d_%s.png" % [_step, name])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
