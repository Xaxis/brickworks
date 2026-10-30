## The keys sheet and the menus' rows, as a person meets them (APP_UX A1, A2).
##
##   tools/probe.sh keysheet_probe
##   godot --path . --resolution 1280x720 --script src/dev/keysheet_probe.gd
##   ... -- --shots=DIR    each step pictured there
##
## F1 opens the keys sheet: 20 or more rows of keys in sight at once, and
## no setting on it. Typed into, it keeps only the rows that say what was
## typed ("hinge"), and the letters typed run nothing in the window. The
## keys the menus show that the controls list does not name are on it, in
## the menus' own words. "," and Tools, Settings open Settings: the
## settings, and not one key. Escape closes each.
##
## Then every menu in the bar, read off the window's pixels: each row's
## words against what is behind them, in each state a row has (normal,
## under the pointer, focused from the keyboard, greyed, greyed and
## focused), at 4.5:1 or better. A greyed row with the focus read as a
## blank bar: its words were the grey of the highlight.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _shots: String = ""
var _step: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	var world: BrickWorld = null
	for _n: int in 600:
		await process_frame
		world = _main.get("_world")
		_shell = _main.get("_shell")
		if world != null and world.brick_count() > 1 and _shell != null:
			break
	if world == null or _shell == null:
		print("  keysheet probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_builder") as Builder).clear_selection()
	await _frames(30)
	var window := DisplayServer.window_get_size()
	print("  a %d x %d window" % [window.x, window.y])

	await _keys_sheet()
	await _settings()
	await _menus()

	print("")
	if _failures == 0:
		print("keysheet probe: all checks passed")
	else:
		print("keysheet probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the keys sheet ---------------------------------------------------------------

func _keys_sheet() -> void:
	print("\n  F1, the keys sheet")
	var sheet: ControlsDialog = _main.get("_controls")
	var verbs: EditVerbs = _main.get("_verbs")
	await _key(KEY_F1)
	await _frames(20)
	_check("F1 opens the keys sheet", sheet.visible)
	var rows: Array[Control] = _rows(sheet)
	var seen: Array[Control] = _in_sight(sheet, rows)
	_check("%d rows of keys in sight at once, of %d (20 or more)" % [seen.size(), rows.size()],
		seen.size() >= 20)
	var settings: Array[String] = _settings_showing(sheet)
	_check("no setting on it (%s)" % (", ".join(settings) if not settings.is_empty() else "none"),
		settings.is_empty())
	var said: PackedStringArray = PackedStringArray()
	for row: Control in rows:
		said.append(_words(row))
	for menu_key: String in ["Ctrl-O", "Ctrl-shift-S", "F2", "Y"]:
		var named: bool = false
		for words: String in said:
			named = named or words.begins_with(menu_key + " ") or words.contains(" " + menu_key + " ")
		_check("the menus' %s is on it" % menu_key, named)
	await _shot("keys_sheet")

	# Typed into, as a person types: the letters go to the sheet's own box.
	var before: int = rows.size()
	var mode: String = verbs.mode
	var selected: int = (_main.get("_builder") as Builder).selection.size()
	await _type("hinge")
	await _frames(6)
	var kept: Array[Control] = _rows(sheet).filter(
		func(row: Control) -> bool: return row.is_visible_in_tree())
	var off: Array[String] = []
	for row: Control in kept:
		if not _words(row).to_lower().contains("hinge"):
			off.append(_words(row))
	_check("\"hinge\" typed keeps %d of %d rows, each about a hinge%s" % [kept.size(), before,
		"" if off.is_empty() else ": not " + "; ".join(off.slice(0, 3))],
		kept.size() >= 1 and kept.size() < before and off.is_empty())
	_check("...and the letters ran nothing (tool %s, %d selected)" % [verbs.mode, selected],
		verbs.mode == mode and sheet.visible)
	await _shot("keys_hinge")
	for _n: int in 5:
		await _key(KEY_BACKSPACE)
	await _type("undo")
	kept = _rows(sheet).filter(func(row: Control) -> bool: return row.is_visible_in_tree())
	_check("\"undo\" typed keeps %s" % "; ".join(kept.map(func(r: Control) -> String: return _words(r))),
		kept.any(func(r: Control) -> bool: return _words(r).contains("Ctrl-Z")))
	await _key(KEY_ESCAPE)
	await _frames(6)
	_check("Escape closes it", not sheet.visible)

	_shell.run("keys")
	await _frames(10)
	_check("Help, Keys and controls opens the sheet too, the box cleared (%d rows)"
		% _rows(sheet).filter(func(r: Control) -> bool: return r.is_visible_in_tree()).size(),
		sheet.visible and _rows(sheet).filter(
			func(r: Control) -> bool: return r.is_visible_in_tree()).size() == before)
	await _key(KEY_ESCAPE)
	await _frames(6)


func _settings() -> void:
	print("\n  \",\", Settings")
	var sheet: ControlsDialog = _main.get("_controls")
	await _key(KEY_COMMA)
	await _frames(20)
	_check(", opens Settings", sheet.visible)
	var settings: Array[String] = _settings_showing(sheet)
	_check("its settings show (%s)" % ", ".join(settings), settings.size() >= 3)
	var keys: int = _rows(sheet).filter(func(r: Control) -> bool: return r.is_visible_in_tree()).size()
	_check("and not one key (%d rows)" % keys, keys == 0)
	await _shot("settings")
	await _key(KEY_ESCAPE)
	await _frames(6)
	_check("Escape closes it", not sheet.visible)
	_shell.run("settings")
	await _frames(10)
	_check("Tools, Settings opens Settings, not the keys",
		sheet.visible and _settings_showing(sheet).size() >= 3
		and _rows(sheet).filter(func(r: Control) -> bool: return r.is_visible_in_tree()).is_empty())
	await _key(KEY_ESCAPE)
	await _frames(6)


## Every row of keys on the sheet, shown or not: an HBox holding the keys'
## box, the pointer and the words.
func _rows(sheet: Control) -> Array[Control]:
	var out: Array[Control] = []
	for row: Node in sheet.find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() == 3 and row.get_child(2) is Label \
				and row.get_child(1) is CenterContainer:
			out.append(row as Control)
	return out


## Those wholly inside the list's own scroller, which is inside the window.
func _in_sight(sheet: Control, rows: Array[Control]) -> Array[Control]:
	var out: Array[Control] = []
	var room := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for row: Control in rows:
		if not row.is_visible_in_tree():
			continue
		var scroll: Control = row.get_parent()
		while scroll != null and not scroll is ScrollContainer:
			scroll = scroll.get_parent()
		var rect: Rect2 = row.get_global_rect()
		var window: Rect2 = scroll.get_global_rect().intersection(room) if scroll != null else room
		if window.grow(0.5).encloses(rect):
			out.append(row)
	return out


## The keys of a row and its words: "Ctrl-Z undo".
func _words(row: Control) -> String:
	var keys: PackedStringArray = PackedStringArray()
	for key: Control in row.get_child(0).get_children():
		keys.append(key.tooltip_text)
	return "%s %s" % [" ".join(keys), (row.get_child(2) as Label).text]


## The settings a person can see on it now, by name.
func _settings_showing(sheet: ControlsDialog) -> Array[String]:
	var out: Array[String] = []
	var named: Dictionary = {"Navigate like": sheet.preset_choice,
		"Interface size": sheet.interface_choice, "Reduce motion": sheet.reduce_motion,
		"Assistant (AI)": sheet.assistant_on, "New models start on": sheet.new_floor}
	for name: String in named:
		var control: Control = named[name]
		if control != null and control.is_visible_in_tree():
			out.append(name)
	return out


# -- the menus --------------------------------------------------------------------

## Each state's lowest contrast, and how many rows were read in it.
var _worst: Dictionary = {}
var _counted: Dictionary = {}


func _menus() -> void:
	print("\n  the menus, every row in every state, read off the window")
	for title: String in ["File", "Edit", "View", "Build", "Tools", "Help"]:
		var button: MenuButton = _shell.menu(title)
		if button == null:
			continue
		button.show_popup()
		await _frames(10)
		var popup: PopupMenu = button.get_popup()
		var first_enabled: int = -1
		for index: int in popup.item_count:
			if popup.is_item_separator(index):
				continue
			# Lit, then not, in the same place: a menu taller than the window
			# scrolls to the row it is given.
			popup.set_focused_item(index)
			var lit: Image = await _picture()
			popup.set_focused_item(-1)
			var plain: Image = await _picture()
			var rect: Rect2i = _changed(plain, lit, popup)
			if rect.size.x < 20:
				print("    %s, row %d (%s): no highlight seen" % [title, index, popup.get_item_text(index)])
				_check("%s, %s is drawn lit when focused" % [title, popup.get_item_text(index)], false)
				continue
			var greyed: bool = popup.is_item_disabled(index)
			_read(title, popup.get_item_text(index), "greyed" if greyed else "normal", plain, rect)
			_read(title, popup.get_item_text(index), "greyed, focused" if greyed else "focused", lit, rect)
			if not greyed and first_enabled < 0 and popup.get_item_submenu_node(index) == null:
				first_enabled = index
				await _shot("menu_%s_focused" % title.to_lower(), lit)
			if greyed and title == "Edit" and index == 0:
				await _shot("menu_edit_greyed_focused", lit)
		# Under the pointer: a real move of the mouse over the first row that
		# can be used (and opens no submenu), which the highlight follows.
		if first_enabled >= 0:
			popup.set_focused_item(first_enabled)
			var lit: Image = await _picture()
			popup.set_focused_item(-1)
			var lit_rect: Rect2i = _changed(await _picture(), lit, popup)
			for step: int in 2:
				var move := InputEventMouseMotion.new()
				move.position = Vector2(lit_rect.get_center()) + Vector2(step * 4, 0)
				move.global_position = move.position
				move.relative = Vector2(4, 0)
				# A menu takes no notice of a move without speed: a pointer
				# resting where a menu opens does not light a row.
				move.velocity = Vector2(240, 0)
				Input.parse_input_event(move)
				await _frames(2)
			await _frames(4)
			var hovered: Image = await _picture()
			if popup.get_focused_item() == first_enabled:
				_read(title, popup.get_item_text(first_enabled), "under the pointer", hovered, lit_rect)
			else:
				_check("%s: the pointer over %s lights it" % [title,
					popup.get_item_text(first_enabled)], false)
		popup.hide()
		await _frames(6)
	for state: String in ["normal", "under the pointer", "focused", "greyed", "greyed, focused"]:
		var worst: float = _worst.get(state, 0.0)
		_check("%s: %d rows, the lowest %.2f:1 (4.5:1 or better)" % [state,
			int(_counted.get(state, 0)), worst], int(_counted.get(state, 0)) > 0 and worst >= 4.5)


## The highlight: where [param lit] differs from [param plain], inside the
## menu, in the picture's pixels.
func _changed(plain: Image, lit: Image, popup: PopupMenu) -> Rect2i:
	var box: Rect2i = _box_of(popup, plain)
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-1, -1)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var a: Color = plain.get_pixel(x, y)
			var b: Color = lit.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.03:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x < 0:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


func _box_of(popup: PopupMenu, picture: Image) -> Rect2i:
	var scale: Vector2 = root.get_final_transform().get_scale()
	var at := Vector2i(Vector2(popup.position) * scale)
	var size := Vector2i(Vector2(popup.size) * scale)
	return Rect2i(at, size).intersection(Rect2i(Vector2i.ZERO, picture.get_size()))


## The words of the row in [param rect] against its ground: the ground is
## the colour most of the row is, and each run of words (the name, the key)
## is as strong as its strongest pixel; the row is its weakest run. The
## highlight's own edge, the tick and the submenu's arrow are left out.
func _read(menu: String, row: String, state: String, picture: Image, rect: Rect2i) -> void:
	var inner := rect.grow(-3)
	var counts: Dictionary = {}
	for y: int in range(inner.position.y, inner.end.y):
		for x: int in range(inner.position.x, inner.end.x):
			var key: int = picture.get_pixel(x, y).to_rgba32()
			counts[key] = int(counts.get(key, 0)) + 1
	var ground_key: int = 0
	var most: int = -1
	for key: int in counts:
		if int(counts[key]) > most:
			most = counts[key]
			ground_key = key
	var ground := Color.hex(ground_key)
	# The strongest pixel of each column, then the columns gathered into runs
	# by the gaps between them.
	var runs: Array = []   # [from x, to x, strongest]
	var gap: int = 99
	for x: int in range(inner.position.x, inner.end.x):
		var strongest: float = 1.0
		for y: int in range(inner.position.y, inner.end.y):
			strongest = maxf(strongest, _ratio(picture.get_pixel(x, y), ground))
		if strongest > 1.3:
			if gap > 9 or runs.is_empty():
				runs.append([x, x, strongest])
			else:
				var run: Array = runs[-1]
				run[1] = x
				run[2] = maxf(float(run[2]), strongest)
			gap = 0
		else:
			gap += 1
	var weakest: float = 99.0
	for run: Array in runs:
		var wide: int = int(run[1]) - int(run[0]) + 1
		# A tick or an arrow at either end, not words.
		var at_end: bool = int(run[0]) < inner.position.x + 20 or int(run[1]) > inner.end.x - 20
		if wide < 16 and at_end:
			continue
		weakest = minf(weakest, float(run[2]))
	if weakest > 98.0:
		return
	_counted[state] = int(_counted.get(state, 0)) + 1
	if not _worst.has(state) or weakest < float(_worst[state]):
		_worst[state] = weakest
		print("    %s: %s, %s, %.2f:1 (ground #%s)" % [state, menu, row, weakest, ground.to_html(false)])


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


static func _ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# -- helpers ----------------------------------------------------------------------

func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.physical_keycode = event.keycode
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _picture() -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _shot(name: String, picture: Image = null) -> void:
	if _shots.is_empty():
		return
	if picture == null:
		picture = await _picture()
	_step += 1
	var path: String = _shots.path_join("%02d_%s.png" % [_step, name])
	picture.save_png(path)
	print("    picture: %s" % path)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
