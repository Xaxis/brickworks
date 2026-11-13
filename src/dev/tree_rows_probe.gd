## A model tree row stays under the pointer that chose it, and the tree by
## keys (treerows, 2026-11-11). tdcheck measured live and treedrag alike:
## choosing a row filled Properties under the tree, which took the tree's
## height (425 px to 110 at 1280 x 720), the row went up 128 px or out of
## sight, and a double click on it opened its parent or another sub-model;
## Escape went on carrying a row; the menu key and Shift+F10 opened no menu;
## and a sub-model carried into another while it was being edited inside
## left the app editing a path that named nothing.
##
##   godot --headless --path . --script src/dev/tree_rows_probe.gd
##   godot --headless --path . --script src/dev/tree_rows_probe.gd -- --phone
##   godot --headless --path . --script src/dev/tree_rows_probe.gd -- --tablet
##
## On 7140-1, at 1280 x 720, 1400 x 900 and 1920 x 1080 in turn (a phone and
## a tablet with --phone and --tablet): a row at the top, the middle and the
## bottom of the tree in sight, chosen by a click (a tap) from nothing
## chosen, is where it was to the unit, and a double click there edits
## inside that row; a second row then chosen moves no more; the same in the
## tree scrolled half way; the tree as tall after each as before. Then,
## from a first visit's column, a small model's row chosen: Properties
## have the room the tree had spare, every field in sight, and its rows are
## where they were. The desktop then: Escape while carrying a row puts it
## back (no drag, nothing changed, no undo step, nothing else Escape does);
## the menu key and Shift+F10 open the chosen row's menu beside it, not over
## it, Down moves in it and Enter chooses its item; and a sub-model carried
## into another while edited inside is still the one edited, by its new path.
extends SceneTree

var _main: Node
var _shell: Shell
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _outliner: Outliner
var _tree: Tree
var _finger: bool = false
var _failures: int = 0

const OMR := "res://vendor/omr/files/7140-1.mpd"


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_finger = args.has("--phone") or args.has("--tablet")
	if _finger:
		Phone._on = 1
		Phone._wide = args.has("--tablet")
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_store.keeps = false
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	Download.folder = OS.get_user_data_dir().path_join("downloads")
	DirAccess.make_dir_recursive_absolute(Download.folder)
	await _open_text(FileAccess.get_file_as_string(OMR), "7140-1")
	if _finger:
		await _as_finger()
		await _jump_at(root.get_visible_rect().size)
	else:
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1400, 900), Vector2i(1920, 1080)]:
			root.size = size
			await _frames(30)
			await _jump_at(Vector2(size))
		root.size = Vector2i(1400, 900)
		await _frames(30)
		await _first_visit()
		await _open_text(FileAccess.get_file_as_string(OMR), "7140-1")
		await _escape()
		await _menu_keys()
		await _entered_carried()
	print("\ntree_rows: %s, %d failure(s)" % [_kind(), _failures])
	quit(1 if _failures > 0 else 0)


# -- a row chosen stays where it was ----------------------------------------------


## Each place in the tree: chosen from nothing chosen, its row's middle
## before and after; then a double click there; then a second row.
func _jump_at(size: Vector2) -> void:
	if not await _show_tree():
		return
	var said: String = "%s %dx%d" % [_kind(), roundi(size.x), roundi(size.y)]
	print("\n  %s: the tree %d px, %d rows in sight; the column %s" % [said, roundi(_tree.size.y),
		_in_sight().size(), _column_said()])
	for scrolled: bool in [false, true]:
		for place: String in ["top", "middle", "bottom"]:
			await _nothing_chosen()
			_set_scroll(0.5 if scrolled else 0.0)
			await _frames(6)
			var target: String = _row_at(place)
			if target.is_empty():
				_check("%s%s %s: a row in sight" % [said, " scrolled" if scrolled else "", place], false)
				continue
			var where: String = "%s%s %s" % [said, " scrolled" if scrolled else "", place]
			var at: Vector2 = _middle_of(target)
			var tall: float = _tree.size.y
			var scroll: float = _tree.get_scroll().y
			await _press_at(at)
			await create_timer(0.8).timeout
			await _frames(6)
			var now: Vector2 = _middle_of(target)
			var chosen: TreeItem = _tree.get_selected()
			var under: String = _meta_at(at)
			_check("%s: %s at y %d, chosen: at y %d (%+d px), under the pointer %s, chosen %s; the tree %d -> %d px, scrolled %d -> %d" % [
				where, target, roundi(at.y), roundi(now.y), roundi(now.y - at.y), under,
				str(chosen.get_metadata(0)) if chosen != null else "(none)", roundi(tall),
				roundi(_tree.size.y), roundi(scroll), roundi(_tree.get_scroll().y)],
				now != Vector2.INF and absf(now.y - at.y) < 1.0 and under == target and chosen != null
				and str(chosen.get_metadata(0)) == target)
			if not _finger:
				# The double click a person makes on the row they see.
				await _nothing_chosen()
				_set_scroll(0.5 if scrolled else 0.0)
				await _frames(6)
				var dat: Vector2 = _middle_of(target)
				_button(dat, true)
				await _frames(1)
				_button(dat, false)
				await create_timer(0.15).timeout
				_button(dat, true, true)
				await _frames(1)
				_button(dat, false)
				await create_timer(0.8).timeout
				await _frames(4)
				_check("%s: a double click on %s edits inside %s" % [where, target,
					_shell.assemblies.entered if not _shell.assemblies.entered.is_empty() else "(the model)"],
					_shell.assemblies.entered == target)
				_shell.assemblies.enter("")
				await _frames(6)
			# A second row, with the first chosen: nothing moves either.
			await _nothing_chosen()
			_set_scroll(0.5 if scrolled else 0.0)
			await _frames(6)
			await _press_at(_middle_of(target))
			await create_timer(0.8).timeout
			await _frames(6)
			var other: String = _row_at("bottom" if place == "top" else "top")
			if other.is_empty() or other == target:
				continue
			var at2: Vector2 = _middle_of(other)
			await _press_at(at2)
			await create_timer(0.8).timeout
			await _frames(6)
			var now2: Vector2 = _middle_of(other)
			_check("%s, then %s at y %d: at y %d (%+d px), under the pointer %s" % [where, other, roundi(at2.y),
				roundi(now2.y), roundi(now2.y - at2.y), _meta_at(at2)],
				absf(now2.y - at2.y) < 1.0 and _meta_at(at2) == other)
	print("    %s after: the column %s" % [said, _column_said()])
	await _nothing_chosen()


## A first visit's column (no height dragged, nothing chosen yet), a model
## of five rows: a row chosen gives Properties the room the tree has spare,
## every field in sight, the rows where they were.
func _first_visit() -> void:
	var side: PanelStack = _main.get("_side")
	if side == null:
		return
	side.set("_split", false)
	var text: String = "\n".join(PackedStringArray(["0 FILE main.ldr", "0 Rows", "0 Name: main.ldr",
		"0 Author: Brickworks", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 16 100 0 0 1 0 0 0 1 0 0 0 1 outer.ldr", "1 16 -100 0 0 1 0 0 0 1 0 0 0 1 sub.ldr",
		"0 NOFILE", "0 FILE outer.ldr", "0 Outer", "0 Name: outer.ldr", "0 Author: Brickworks",
		"1 2 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 inner.ldr", "0 NOFILE",
		"0 FILE inner.ldr", "0 Inner", "0 Name: inner.ldr", "0 Author: Brickworks",
		"1 14 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat", "0 NOFILE",
		"0 FILE sub.ldr", "0 Sub", "0 Name: sub.ldr", "0 Author: Brickworks",
		"1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat", "1 3 0 -24 0 1 0 0 0 1 0 0 0 1 3022.dat", "0 NOFILE", ""]))
	await _open_text(text, "rows")
	if not await _show_tree():
		return
	await _nothing_chosen()
	side.set("_split", false)
	side.queue_sort()
	await _frames(10)
	var tall: float = _outliner.size.y
	var spare: float = float(_outliner.call("spare_height")) if _outliner.has_method("spare_height") else 0.0
	var target: String = _row_at("bottom")
	var at: Vector2 = _middle_of(target)
	await _press_at(at)
	await create_timer(0.8).timeout
	await _frames(10)
	var inspector: Inspector = _shell.inspector
	var whole: float = PanelStack.whole_height(inspector)
	_check("a first visit's column, a small model: %s chosen at y %d, now y %d; the tree %d -> %d px (%d spare), Properties %d px of the %d all their fields take, split set %s" % [
		target, roundi(at.y), roundi(_middle_of(target).y), roundi(tall), roundi(_outliner.size.y),
		roundi(spare), roundi(inspector.size.y), roundi(whole), side.get("_split")],
		absf(_middle_of(target).y - at.y) < 1.0 and inspector.size.y >= whole - 1.0
		and _outliner.size.y >= tall - spare - 1.0 and bool(side.get("_split")))
	# Nothing chosen again: the split stays, the tree as tall.
	var kept: float = _outliner.size.y
	await _nothing_chosen()
	_check("...nothing chosen again: the tree stays %d px (%d)" % [roundi(kept), roundi(_outliner.size.y)],
		absf(_outliner.size.y - kept) < 1.0)


func _column_said() -> String:
	var parts := PackedStringArray()
	var stack: Variant = _main.get("_side")
	if stack == null:
		stack = _main.get("_stack")
	for section: Control in (stack as PanelStack).sections():
		parts.append("%s %d%s" % [section.get_class() if section.get_script() == null
			else (section.get_script() as Script).get_global_name(), roundi(section.size.y),
			"" if section.is_visible_in_tree() else " (hidden)"])
	return ", ".join(parts)


# -- Escape mid-carry ---------------------------------------------------------------


func _escape() -> void:
	print("\n  Escape while carrying a row")
	if not await _show_tree():
		return
	var paths: PackedStringArray = _shell.assemblies.paths()
	var figure: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Minifig"))
	var vehicle: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Support Vehicle"))
	await _nothing_chosen()
	var before: String = _store.to_text("tree rows")
	var depth: int = _builder.history_depth()
	var at: Vector2 = _middle_of(figure)
	_move(at, 0, Vector2.ZERO)
	await _frames(3)
	_button(at, true)
	await _frames(4)
	var now: Vector2 = at
	for step: int in 6:
		var next: Vector2 = at + Vector2(4.0 * (step + 1), 0.0)
		_move(next, MOUSE_BUTTON_MASK_LEFT, next - now)
		now = next
		await _frames(2)
	var carried: String = _drag_name(root.gui_get_drag_data()) if root.gui_is_dragging() else "(no drag)"
	var entered: String = _shell.assemblies.entered
	var chosen: int = _builder.selection.size()
	await _key(KEY_ESCAPE)
	await _frames(4)
	var dragging: bool = root.gui_is_dragging()
	# On to the vehicle's row and let go there.
	var goal: Vector2 = _middle_of(vehicle)
	if goal != Vector2.INF:
		for step: int in 10:
			var next: Vector2 = now.lerp(goal, float(step + 1) / 10.0)
			_move(next, MOUSE_BUTTON_MASK_LEFT, next - now)
			now = next
			await _frames(2)
	_button(now, false)
	await _frames(10)
	_check("Escape carrying %s, let go on %s: carried %s, dragging after Escape %s, the model as it was %s, undo %d -> %d, editing %s -> %s, %d -> %d parts selected" % [
		figure, vehicle, carried, dragging, _store.to_text("tree rows") == before, depth,
		_builder.history_depth(), entered if not entered.is_empty() else "(the model)",
		_shell.assemblies.entered if not _shell.assemblies.entered.is_empty() else "(the model)", chosen,
		_builder.selection.size()],
		carried == figure and not dragging and _store.to_text("tree rows") == before
		and _builder.history_depth() == depth and _shell.assemblies.entered == entered
		and _builder.selection.size() == chosen)
	if _builder.history_depth() > depth:
		await _shell.verbs.press("undo")
		await _frames(6)


# -- the menu key ---------------------------------------------------------------


func _menu_keys() -> void:
	print("\n  the menu key and Shift+F10")
	if not await _show_tree():
		return
	var paths: PackedStringArray = _shell.assemblies.paths()
	var vehicle: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Support Vehicle"))
	for how: Array in [["the menu key", KEY_MENU, false], ["Shift+F10", KEY_F10, true]]:
		await _nothing_chosen()
		var at: Vector2 = _middle_of(vehicle)
		await _press_at(at)
		await create_timer(0.6).timeout
		await _frames(4)
		_tree.grab_focus()
		await _frames(2)
		await _key(how[1], how[2])
		await _frames(10)
		var menu: PopupMenu = _outliner.row_menu
		var up: bool = menu != null and menu.visible
		var row_rect: Rect2 = _rect_of(vehicle)
		var menu_rect: Rect2 = Rect2(Vector2(menu.position), Vector2(menu.size)) if up else Rect2()
		var over: bool = up and menu_rect.intersects(row_rect.grow(-2.0))
		var near: bool = up and absf(menu_rect.position.y - row_rect.end.y) < row_rect.size.y * 2.0 + 4.0 \
			or up and absf(menu_rect.end.y - row_rect.position.y) < row_rect.size.y * 2.0 + 4.0
		_check("%s on %s: its menu %s for %s, at %s by the row at %s, over it %s" % [how[0], vehicle,
			"up" if up else "none" if menu == null else "not up", _outliner.get("_menu_path"),
			str(menu_rect.position.round()), str(row_rect.position.round()), over],
			up and str(_outliner.get("_menu_path")) == vehicle and not over and near)
		if not up:
			continue
		var was: int = menu.get_focused_item()
		await _key(KEY_DOWN)
		await _frames(4)
		var focused: int = menu.get_focused_item()
		_check("%s: Down in the menu moves to an item (%d -> %d)" % [how[0], was, focused],
			focused >= 0 and focused != was)
		if how[1] == KEY_MENU:
			await _key(KEY_ESCAPE)
			await _frames(6)
			_check("%s: Escape puts the menu away (%s)" % [how[0], "up" if menu.visible else "away"],
				not menu.visible)
			continue
		# Enter on the item Down chose: the item's own, as a click on it.
		var chose: Array = []
		var heard := func(id: int) -> void: chose.append(id)
		menu.id_pressed.connect(heard)
		var item: int = menu.get_item_id(focused) if focused >= 0 else -1
		await _key(KEY_ENTER)
		await create_timer(1.0).timeout
		await _frames(10)
		menu.id_pressed.disconnect(heard)
		_check("%s: Enter chose %s (item %d), the menu away %s" % [how[0], str(chose), item, not menu.visible],
			chose == [item] and not menu.visible)
		_close_popups()
		await _frames(6)


# -- the path edited, carried ----------------------------------------------------


func _entered_carried() -> void:
	print("\n  a sub-model carried while edited inside")
	var paths: PackedStringArray = _shell.assemblies.paths()
	var figure: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Minifig"))
	var vehicle: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Support Vehicle"))
	for inside: bool in [false, true]:
		_shell.assemblies.enter("")
		await _frames(4)
		var edited: String = figure
		if inside:
			for p: String in paths:
				if Assemblies.parent_of(p) == figure:
					edited = p
					break
		_shell.assemblies.enter(edited)
		await _frames(6)
		var moved: String = _shell.assemblies.move_into(figure, vehicle)
		_shell.verbs.edited.call()
		await _frames(10)
		var want: String = moved + edited.substr(figure.length())
		_check("editing %s, %s put in %s: editing %s, new parts go in %s (want %s)" % [edited, figure, vehicle,
			_shell.assemblies.entered, _builder.place_group, want],
			_shell.assemblies.entered == want and _builder.place_group == want
			and _shell.assemblies.paths().has(want))
		await _shell.verbs.press("undo")
		await _frames(8)
		_shell.assemblies.enter("")
		await _frames(4)


# -- the tree ------------------------------------------------------------------------


func _as_finger() -> void:
	if DisplayServer.get_name() != "headless":
		return
	# A tablet held upright: on its side (1180 x 820) its drawer is the
	# colours' 250 units, what the model stands on 180 and the tree's head
	# and hint, with one row of the tree in sight, nothing chosen (treerows).
	root.size = Vector2i(390, 844) if not Phone.wide() else Vector2i(820, 1180)
	await _frames(10)
	var across := float(root.size.x)
	var down := float(root.size.y)
	if Phone.wide():
		root.content_scale_factor = Phone.tablet_factor(across, down) * ShellPrefs.interface_size()
	else:
		var phone: Variant = _main.get("_phone")
		if phone is Node:
			(phone as Node).set_process(false)
		root.content_scale_factor = (_main.get_script() as GDScript).sized_factor(across, down,
			true, ShellPrefs.interface_size(), true)
	await _frames(30)


func _show_tree() -> bool:
	var dock: Variant = _main.get("_props_dock")
	if dock == null:
		dock = _main.get("_bin_dock")
	if dock is SideDock and not (dock as SideDock).is_open():
		(dock as SideDock).set_open(true, false)
		await _frames(20)
	if not _shell.outliner.is_open():
		_shell.outliner.set_open(true)
	await _frames(20)
	_outliner = _shell.outliner
	_tree = _outliner.get("_tree")
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and not (_tree.is_visible_in_tree() and _tree.get_root() != null):
		await process_frame
	# Every row open, so the tree is long enough to scroll.
	if _tree.get_root() != null:
		var stack: Array = [_tree.get_root()]
		while not stack.is_empty():
			var row: TreeItem = stack.pop_back()
			row.collapsed = false
			for child: TreeItem in row.get_children():
				stack.append(child)
		await _frames(6)
	var shown: bool = _tree.is_visible_in_tree() and _tree.get_root() != null
	if not shown:
		_check("%s: the model tree shown" % _kind(), false)
	return shown


func _nothing_chosen() -> void:
	_close_popups()
	_shell.assemblies.enter("")
	_builder.clear_selection()
	_tree.deselect_all()
	await create_timer(0.6).timeout
	await _frames(6)


## The tree scrolled to [param share] of as far as it goes.
func _set_scroll(share: float) -> void:
	var bar: VScrollBar = null
	for child: Node in _tree.get_children(true):
		if child is VScrollBar:
			bar = child
	if bar == null:
		return
	bar.value = (bar.max_value - bar.page) * share if bar.visible else 0.0


## The row at the top, the middle or the bottom of those wholly in sight.
func _row_at(place: String) -> String:
	var shown: Dictionary = _in_sight()
	var keys: Array = shown.keys().filter(func(m: String) -> bool:
		return not m.is_empty() and not m.begins_with(Outliner.SUGGESTION) and m != Outliner.SUGGESTED)
	keys.sort_custom(func(a: String, b: String) -> bool:
		return (shown[a] as Rect2).position.y < (shown[b] as Rect2).position.y)
	if keys.is_empty():
		return ""
	return keys[0] if place == "top" else keys[keys.size() / 2] if place == "middle" else keys[keys.size() - 1]


func _in_sight() -> Dictionary:
	var out: Dictionary = {}
	var area: Rect2 = _tree.get_global_rect()
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var row: TreeItem = stack.pop_back()
		if row == null:
			continue
		var rect: Rect2 = _tree.get_item_area_rect(row)
		if rect.size != Vector2.ZERO:
			rect.position += area.position
			if area.encloses(rect):
				out[str(row.get_metadata(0))] = rect
		if not row.collapsed:
			for child: TreeItem in row.get_children():
				stack.append(child)
	return out


func _rect_of(path: String) -> Rect2:
	var row: TreeItem = _outliner.call("_find", _tree.get_root(), path)
	if row == null:
		return Rect2()
	var rect: Rect2 = _tree.get_item_area_rect(row)
	rect.position += _tree.get_global_rect().position
	return rect


## Where the row's middle is in the window, INF when it is not in sight.
func _middle_of(path: String) -> Vector2:
	var rect: Rect2 = _rect_of(path)
	if not rect.has_area() or not _tree.get_global_rect().has_point(rect.get_center()):
		return Vector2.INF
	return rect.get_center()


func _meta_at(at: Vector2) -> String:
	if at == Vector2.INF or not _tree.get_global_rect().has_point(at):
		return "(off the tree)"
	var under: TreeItem = _tree.get_item_at_position(_tree.get_global_transform_with_canvas().affine_inverse() * at)
	return str(under.get_metadata(0)) if under != null else "(none)"


## A click, or a finger's tap.
func _press_at(at: Vector2) -> void:
	if at == Vector2.INF:
		return
	if _finger:
		_touch(at, true)
		await _frames(3)
		_touch(at, false)
		await _frames(3)
		return
	_move(at, 0, Vector2.ZERO)
	await _frames(2)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(2)


func _drag_name(data: Variant) -> String:
	if not data is Dictionary:
		return str(data)
	return str((data as Dictionary).get("assembly", data))


func _first(paths: PackedStringArray, test: Callable) -> String:
	for path: String in paths:
		if test.call(path):
			return path
	return ""


func _close_popups() -> void:
	for child: Node in _outliner.get_children() if _outliner != null else []:
		if child is Popup and (child as Popup).visible:
			(child as Popup).hide()


func _open_text(text: String, name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var opened: Dictionary = await _bar.open_text_with_progress(text, name)
	_bar.opened.emit(int(opened.get("placed", 0)))
	for _n: int in 3000:
		if not _store.laying:
			break
		await process_frame
	await _frames(20)


func _kind() -> String:
	return "tablet" if Phone.wide() else "phone" if Phone.on() else "desktop"


func _key(code: Key, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		key.shift_pressed = shift
		Input.parse_input_event(key)
		await _frames(2)


func _button(at: Vector2, down: bool, double: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.double_click = double
	event.position = _as_event(at)
	event.global_position = event.position
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _move(at: Vector2, mask: int, relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.button_mask = mask
	motion.relative = _as_event_by(relative)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)


func _touch(at: Vector2, down: bool, index: int = 0) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _as_event(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _as_event_by(by: Vector2) -> Vector2:
	return root.get_final_transform().basis_xform(by)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
