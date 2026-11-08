## The keys work while a field has the focus (APP_UX7 #4, typingkeys).
##
##   godot --path . --resolution 1400x900 --script src/dev/typingkeys_probe.gd
##   tools/probe.sh typingkeys_probe        (and PROBE_SIZE=1280x720)
##   ... -- --shots=DIR    the pictures there, not in user://typingkeys
##
## The walk typed "87087" in the bin's search and pressed F1, and nothing
## happened: while a field had the keys, Main gave up every key, F1, F9,
## Ctrl+S and Alt+X with the letters. Now a field keeps only the keys it
## types with.
##
## Through the way in first, as a person comes: the sign-in screen over the
## app (gate_for_probe), a throwaway account signed in (made with the admin
## key and a password, as mosaic_window_probe does), removed at the end.
## Needs .env (SUPABASE_URL, SUPABASE_SECRET_KEY).
##
## Then under each of the four presets, from each of three fields, the bin's
## search, Find's field (Ctrl+F) and the assistant's brief, each clicked
## as a person clicks it and every key an input event to the window:
## - "87087" typed there and the keys still there: F1 opens the keys sheet,
##   F9 Render, Ctrl+Shift+B Page setup, Alt+X the box, and Ctrl+S saves,
##   in 1 press each;
## - letters, digits, Space (and Shift's capitals, the brackets and the
##   zoom keys, which are keys of the model's too) typed there run nothing:
##   the model byte for byte, its undo list as long, the view, the
##   selection and the tool as they were, nothing opened; the field has
##   every letter;
## - Ctrl+A, C, X, V and Z act on its text (all of it selected, copied, cut,
##   pasted back, the paste undone), never on the model.
## And the walk's own: "87087" in the bin, F1, "cut away" typed into the
## sheet's box: 11 rows (at 1400 x 900, the walk's size; said at any).
extends SceneTree

const CTRL := KEY_MASK_CMD_OR_CTRL
const SHIFT := KEY_MASK_SHIFT
const ALT := KEY_MASK_ALT
const TYPED := "87087"
## Letters, digits and Space, Shift's capitals of the tool keys, and the
## colour and zoom keys: everything here is a key of the model's as well.
const SENTENCE := "the quick brown fox jumps over the lazy dog 0123456789 XOIVPG [] -="
## The bar's keys and what each must leave open, by what it opens.
const KEYS: Array = [[KEY_F1, "the keys sheet"], [KEY_F9, "Render"],
	[CTRL | SHIFT | KEY_B, "Page setup"], [ALT | KEY_X, "a box"], [CTRL | KEY_S, "saved"]]
const CUT_AWAY_ROWS := 11

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _verbs: EditVerbs
var _camera: Camera3D
var _sheet: Control
var _out: String = "user://typingkeys"
var _size: String = ""
var _email: String = ""
var _password: String = ""
var _saves: int = 0
var _snapshots: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	var playback: Variant = _main.get("_playback")
	if playback != null:
		playback.stop()
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	print("in a %s window" % _size)
	if not await _way_in():
		await _finish()
		return
	_world = _main.get("_world")
	for _n: int in 900:
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
		await process_frame
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_camera = _main.get("_camera")
	_sheet = _main.get("_controls")
	if _world == null or _world.brick_count() <= 1 or _shell == null:
		_check("a model in the window to type beside", false)
		await _finish()
		return
	_store.keeps = false
	_store.saved.connect(func(_name: String) -> void: _saves += 1)
	# A model with a name, so Ctrl+S writes it rather than asking for one,
	# and a part taken off on its undo list, for a Ctrl+Z to put back.
	var name_field: LineEdit = (_main.get("_bar") as ModelBar).get("_name")
	name_field.text = "typingkeys"
	name_field.text_changed.emit(name_field.text)
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			_builder.selection[brick.id] = true
			break
	_builder.selection_changed.emit(_builder.selection.size())
	_shell.run("delete")
	await _frames(20)
	_builder.clear_selection()
	_builder.selection_changed.emit(0)
	await _frames(4)
	print("  the model: %d parts, %d on its undo list" % [_world.brick_count(), _builder.history_depth()])
	Keymap.reset()

	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		print("\nunder %s's keys" % Keymap.PRESET_NAMES[preset])
		for field_name: String in ["the bin's search", "Find's field", "the assistant's brief"]:
			await _from_field(preset, field_name)
	Keymap.use("brickworks")
	await _cut_away()
	Keymap.reset()
	await _finish()


# -- the way in ------------------------------------------------------------------

func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("typingkeys")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify, which is 1 per 10 s for every agent.
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- from a field ----------------------------------------------------------------

func _from_field(preset: String, field_name: String) -> void:
	var field: Control = await _open_field(field_name)
	if field == null:
		_check("%s: up and in sight to type in" % field_name, false)
		return
	var short: String = field_name.get_slice(" ", 1).trim_suffix("'s")
	var shots: bool = preset == "brickworks"

	# Typed: nothing but the field hears it.
	_set_text(field, "")
	if not await _focus(field, field_name):
		await _close_field(field_name)
		return
	var was: Dictionary = _state()
	for character: String in SENTENCE:
		await _type(character)
	await _frames(10)
	var now: Dictionary = _state()
	var differ: Array = _differences(was, now)
	_check("%s: \"%s\" typed runs nothing%s; the field has it all (\"%s\")" % [field_name,
		SENTENCE, "" if differ.is_empty() else ": " + ", ".join(differ), _text(field)],
		differ.is_empty() and _text(field) == SENTENCE)
	if shots:
		await _shot("typed_" + short)

	# "87087" there, and each of the bar's keys from it.
	_set_text(field, "")
	await _focus(field, field_name)
	for character: String in TYPED:
		await _type(character)
	await _frames(6)
	var said: Array = []
	var ok: bool = _text(field) == TYPED
	for pair: Array in KEYS:
		var accel: int = pair[0]
		var opens: String = pair[1]
		await _put_away()
		if not await _focus(field, field_name):
			ok = false
			said.append("%s (no keys in the field)" % Keymap.listed_key(accel))
			continue
		var saves: int = _saves
		await _press(accel)
		var seen: Array = await _opened(opens, saves)
		var right: bool = seen == [opens]
		said.append("%s %s" % [Keymap.listed_key(accel), "ok" if right else str(seen)])
		ok = ok and right and _text(field) == TYPED
		if shots and opens != "saved":
			await _shot("%s_from_%s" % [opens.replace(" ", "_"), short])
	await _put_away()
	_check("%s: \"%s\" in it, the keys there, 1 press each: %s" % [field_name, _text(field),
		"; ".join(said)], ok)

	# The field's own keys act on its text.
	await _edit_keys(field, field_name)
	await _close_field(field_name)


## The field's own: Ctrl+A, C, X, V and Z on its text, never the model's.
func _edit_keys(field: Control, field_name: String) -> void:
	_set_text(field, "")
	await _focus(field, field_name)
	for character: String in TYPED:
		await _type(character)
	DisplayServer.clipboard_set("")
	var was: Dictionary = _state()
	var did: Array = []
	await _press(CTRL | KEY_A)
	did.append("A %s" % ("all selected" if _selected(field) == TYPED else "selected \"%s\"" % _selected(field)))
	await _press(CTRL | KEY_C)
	did.append("C %s" % ("copied" if DisplayServer.clipboard_get() == TYPED
		else "clipboard \"%s\"" % DisplayServer.clipboard_get()))
	await _press(CTRL | KEY_X)
	var cut: bool = _text(field).is_empty() and DisplayServer.clipboard_get() == TYPED
	did.append("X %s" % ("cut" if cut else "left \"%s\"" % _text(field)))
	await _press(CTRL | KEY_V)
	var pasted: bool = _text(field) == TYPED
	did.append("V %s" % ("pasted" if pasted else "gave \"%s\"" % _text(field)))
	await _press(CTRL | KEY_Z)
	var undone: bool = _text(field) != TYPED
	did.append("Z %s" % ("undid the paste" if undone else "left \"%s\"" % _text(field)))
	await _frames(10)
	var differ: Array = _differences(was, _state())
	var text_ok: bool = did[0] == "A all selected" and did[1] == "C copied" and cut and pasted and undone
	_check("%s: Ctrl+%s; the model untouched%s" % [field_name, ", ".join(did),
		"" if differ.is_empty() else ": " + ", ".join(differ)], text_ok and differ.is_empty())


## The field up, in sight and empty of what was typed before; null when
## it is not there to be typed in.
func _open_field(field_name: String) -> Control:
	await _put_away()
	root.gui_release_focus()
	match field_name:
		"the bin's search":
			var bin: PartsBin = _main.get("_bin")
			var search: Control = bin.get("_search")
			# At 1280 x 720 the bin gives way to the assistant's column (and
			# to Properties, the walk found): its rail clicked brings it back,
			# as a person brings it back.
			var dock: SideDock = _main.get("_bin_dock")
			if not search.is_visible_in_tree() and not dock.is_open():
				await _click(dock.rail().get_global_rect().get_center())
				for _n: int in 60:
					if search.is_visible_in_tree():
						break
					await process_frame
				await _frames(6)
			return search
		"Find's field":
			await _press(Keymap.key_of("select_find"))
			await _frames(10)
			var list: Control = _main.get("_inventory_made")
			if list == null or not list.visible:
				print("    %s did not open Find" % Keymap.listed("select_find"))
				return null
			return list.get("_find") as Control
		"the assistant's brief":
			_main.call("set_assistant", true)
			(_main.get("_chat_dock") as SideDock).set_open(true, false)
			await _frames(10)
			var chat: Control = _main.get("_chat")
			# The brief's box as it is for somebody with a key to design
			# with (ChatPanel._show_for_key, there for a check).
			chat.call("_show_for_key", true)
			await _frames(10)
			return chat.get("_input") as Control
	return null


func _close_field(field_name: String) -> void:
	root.gui_release_focus()
	match field_name:
		"the bin's search":
			_set_text(_main.get("_bin").get("_search"), "")
		"Find's field":
			var list: Variant = _main.get("_inventory_made")
			if list != null and (list as Control).visible:
				list.call("hide_list")
		"the assistant's brief":
			_set_text(_main.get("_chat").get("_input"), "")
			(_main.get("_chat_dock") as SideDock).set_open(false, false)
	await _frames(10)


## Clicked as a person clicks it, and the keys there.
func _focus(field: Control, field_name: String) -> bool:
	if not field.is_visible_in_tree():
		_check("%s in sight to click" % field_name, false)
		return false
	var rect: Rect2 = field.get_global_rect()
	# Left of the middle: a search's clear button is at its right end.
	await _click(Vector2(rect.position.x + rect.size.x * 0.4, rect.get_center().y))
	await _frames(4)
	if root.gui_get_focus_owner() != field:
		var hit: Control = root.gui_get_hovered_control()
		_check("%s has the keys once clicked (they are with %s; the click went to %s)" % [field_name,
			root.gui_get_focus_owner(), hit.get_path() if hit != null else "nothing"], false)
		return false
	# The caret at its end, as after typing.
	if field is LineEdit:
		(field as LineEdit).caret_column = (field as LineEdit).text.length()
	elif field is TextEdit:
		(field as TextEdit).set_caret_line((field as TextEdit).get_line_count() - 1)
		(field as TextEdit).set_caret_column((field as TextEdit).get_line((field as TextEdit).get_line_count() - 1).length())
	return true


# -- what the keys did -----------------------------------------------------------

## What is open of what the bar's keys open, and whether a save was made
## since [param saves].
func _open_now(saves: int) -> Array:
	var out: Array = []
	if _sheet != null and _sheet.visible:
		out.append("the keys sheet")
	var render: Variant = _main.get("_render_made")
	if render != null and (render as Control).visible:
		out.append("Render")
	var setup: Variant = _shell.get("_page_setup_dialog")
	if setup != null and (setup as Window).visible:
		out.append("Page setup")
	if _shell.see_inside.shape_on() and _shell.see_inside.shape == CutShape.BOX:
		out.append("a box")
	if _saves > saves:
		out.append("saved")
	return out


## What a key opened, waited for (Render's first opening makes it).
func _opened(opens: String, saves: int) -> Array:
	for _n: int in 300:
		if opens in _open_now(saves):
			break
		await process_frame
	await _frames(4)
	return _open_now(saves)


func _put_away() -> void:
	if _sheet != null and _sheet.visible:
		_sheet.visible = false
	var render: Variant = _main.get("_render_made")
	if render != null and (render as Control).visible:
		render.call("close")
	var setup: Variant = _shell.get("_page_setup_dialog")
	if setup != null and (setup as Window).visible:
		(setup as Window).hide()
	if _shell.see_inside.cutting:
		_shell.see_inside.set_cut(false)
	await _frames(6)


## The model and everything a key of the model's changes: the model's
## bytes as a save writes them, its undo list, the view, the selection, the
## tool, and what is open.
func _state() -> Dictionary:
	_snapshots += 1
	var path: String = "user://typingkeys_%d.ldr" % _snapshots
	_store.save_file(path, "typingkeys")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return {"the model's bytes": bytes, "parts": _world.brick_count(),
		"the undo list": _builder.history_depth(), "the view": _camera.global_transform,
		"the selection": _builder.selection.keys(), "the tool": _verbs.mode,
		"open": _open_now(_saves), "saves": _saves}


func _differences(was: Dictionary, now: Dictionary) -> Array:
	var out: Array = []
	for key: String in was:
		if was[key] is Transform3D:
			if not (was[key] as Transform3D).is_equal_approx(now[key]):
				out.append("%s moved" % key)
		elif was[key] != now[key]:
			out.append("%s %s" % [key, "changed" if was[key] is PackedByteArray
				else "%s, was %s" % [str(now[key]), str(was[key])]])
	return out


# -- the walk's keys sheet -------------------------------------------------------

## The walk's way: "87087" in the bin's search, F1, and "cut away" typed
## into the sheet's box: the rows it keeps.
func _cut_away() -> void:
	print("\nthe walk's: \"87087\" in the bin, F1, \"cut away\" typed into the sheet")
	var field: Control = await _open_field("the bin's search")
	_set_text(field, "")
	if not await _focus(field, "the bin's search"):
		return
	for character: String in TYPED:
		await _type(character)
	await _press(KEY_F1)
	await _opened("the keys sheet", _saves)
	var find: LineEdit = _sheet.get("_find")
	await _frames(4)
	var keys_with: Control = root.gui_get_focus_owner()
	for character: String in "cut away":
		await _type(character)
	await _frames(10)
	var kept := PackedStringArray()
	for row: Node in _sheet.find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() == 3 and row.get_child(2) is Label \
				and row.get_child(1) is CenterContainer and (row as Control).is_visible_in_tree():
			kept.append((row.get_child(2) as Label).text)
	print("    kept: %s" % "; ".join(kept))
	var at_walk: bool = _size == "1400x900"
	_check("F1 from the search opens the sheet, its box has the keys (%s), and \"%s\" typed keeps %d rows%s"
		% [keys_with, find.text, kept.size(), "" if at_walk else " (the walk's 11 are at 1400x900)"],
		_sheet.visible and keys_with == find and find.text == "cut away"
		and (kept.size() == CUT_AWAY_ROWS or not at_walk))
	await _shot("cut_away")
	await _put_away()
	await _close_field("the bin's search")


# -- helpers ---------------------------------------------------------------------

func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _text(field: Control) -> String:
	return str(field.get("text"))


func _selected(field: Control) -> String:
	return str(field.call("get_selected_text"))


func _set_text(field: Variant, text: String) -> void:
	if field == null:
		return
	(field as Control).set("text", text)
	if field is LineEdit:
		(field as LineEdit).text_changed.emit(text)
	elif field is TextEdit:
		(field as TextEdit).text_changed.emit()


## A character typed as the window delivers it: its key, Shift for a
## capital, and the character.
func _type(character: String) -> void:
	var code: int = character.to_upper().unicode_at(0)
	var shifted: bool = character != character.to_lower()
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code as Key
		event.physical_keycode = code as Key
		event.unicode = character.unicode_at(0) if down else 0
		event.shift_pressed = shifted
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


## A key and its modifiers, down and up, as the window delivers them.
func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


## A point on the app's canvas in the window's pixels.
func _px(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


## On Xvfb the system's pointer too, before each event (mosaic_window_probe).
func _warp(at: Vector2) -> void:
	if OS.get_environment("XAUTHORITY").contains("xvfb-run"):
		Input.warp_mouse(at)


func _click(at: Vector2) -> void:
	at = _px(at)
	_warp(at)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await process_frame
	for down: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = at
		press.global_position = at
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(press)
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(named: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%s_%s.png" % [named, _size])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % ProjectSettings.globalize_path(path))


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	if _failures == 0:
		print("typingkeys probe: all checks passed")
	else:
		print("typingkeys probe: %d check(s) FAILED" % _failures)
	if _world != null:
		_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)
