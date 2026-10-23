## Finding where a part is in a big set, in the real app, in a window.
##
##   godot --path . --resolution 1400x900 --script src/dev/find_part_probe.gd
##
## The Boutique Hotel (10297-1, 3,164 parts) opened from the official
## models. The parts list shows each lot's picture beside its row; a row
## clicked with the pointer selects every one of that part in that colour,
## frames them and says how many; Edit, Select by has Same part and Part
## number or name…, which opens the list's find, and "blue 1x2 brick" typed
## into it key by key (none of them taken by the app's own keys) and Enter
## selects the hotel's one blue 1 x 2 brick; "3004" every 1 x 2 brick. The
## MCP's look_at_model finds the same brick by part= and color=.
##
## Then Orthanc (9,429 parts): the longest frame after a click on the row of
## its 1,074 black 1 x 4 tiles against the longest after Select all, each
## three times. --no-time leaves that out. On a checkout without the
## clickable rows (a base to compare with) only Select all is timed.
##
## Pictures: shots/findpart_list.png, findpart_row.png, findpart_find.png
## and findpart_found.png. Look at them.
extends SceneTree

const HOTEL := "res://vendor/omr/files/10297-1.mpd"

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bar: ModelBar
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _list: InventoryPanel
var _pointer := Vector2.ZERO


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_list = _main.get("_inventory")
	var timing_only: bool = not _list.has_signal("chosen")
	if not timing_only:
		await _hotel()
	if not OS.get_cmdline_user_args().has("--no-time"):
		await _time_on_orthanc(timing_only)
	_world.clear()
	await _frames(10)
	_main.queue_free()
	await _frames(10)
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)


func _open(path: String) -> int:
	_main.call("clear_model")
	await _frames(10)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(120)
	return placed


func _hotel() -> void:
	print("\n  the parts list of the Boutique Hotel")
	var placed: int = await _open(HOTEL)
	_check("the hotel is open (%d parts)" % placed, placed > 3000)
	var scenery: Dictionary = (_main.get("_store") as ModelStore).scenery
	var library: PartLibrary = _main.get("_library")

	var from: int = Time.get_ticks_usec()
	_main.call("_toggle_parts")
	print("     the list made in %.0f ms" % ((Time.get_ticks_usec() - from) / 1000.0))
	await _frames(10)
	var made: Array = _list._made
	var stock: Inventory = _list._stock
	_check("one row per lot (%d)" % made.size(), _list.visible and made.size() == stock.lot_count()
		and _list._rows.get_child_count() == made.size())
	# The pictures of the rows in sight, drawn as they come into sight.
	var in_sight: Array = []
	var drawn: int = 0
	for _n: int in 600:
		in_sight = _list._sight.tiles().filter(func(tile: ThumbTile) -> bool:
			return tile.in_sight)
		drawn = in_sight.filter(func(tile: ThumbTile) -> bool:
			return tile.state == ThumbTile.State.READY and tile.texture != null).size()
		if not in_sight.is_empty() and drawn == in_sight.size():
			break
		await process_frame
	_check("every row in sight has its picture (%d of %d)" % [drawn, in_sight.size()],
		in_sight.size() >= 10 and drawn == in_sight.size())
	await _shot("findpart_list")

	# A row clicked with the pointer: 57 light nougat plates 1 x 2.
	var lot: Inventory.Lot = null
	var row: Button = null
	for pair: Array in made:
		var one: Inventory.Lot = pair[0]
		if one.part_id == "3023b" and one.color_name == "Light Nougat":
			lot = one
			row = pair[1]
	_check("the list has the light nougat plates 1 x 2", lot != null)
	if lot == null:
		return
	(_list._scroll as ScrollContainer).ensure_control_visible(row)
	await _frames(4)
	var aimed_from: Vector3 = _camera._target_focus
	await _click(row.get_global_rect().get_center())
	var picked: Array = _builder.selection.keys()
	var all_of_it: bool = picked.all(func(id: int) -> bool:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		return brick != null and brick.part_id == "3023b" and brick.color_code == lot.color_code)
	_check("clicking its row selects every one: %d of %d" % [picked.size(), lot.count],
		picked.size() == lot.count and all_of_it)
	_check("...and puts the list away", not _list.visible)
	var said: String = _bar._status.text
	print("     the bar: %s" % said)
	_check("...and says how many and what", said.begins_with("selected %d: Plate 1 x 2 in Light Nougat"
		% lot.count))
	await _frames(90)
	var box: AABB = _main.call("_selection_bounds")
	_check("the view is framed on them", _camera._target_focus.distance_to(box.get_center()) < 1.0
		and aimed_from.distance_to(box.get_center()) > 1.0)
	var seen: Rect2 = _camera.seen_rect()
	var out_of_view: int = 0
	for id: int in picked:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var at: Vector3 = brick.transform.origin
		if _camera.is_position_behind(at) or not seen.has_point(_camera.unproject_position(at)):
			out_of_view += 1
	_check("...every one of them in the view (%d outside)" % out_of_view, out_of_view == 0)
	await _shot("findpart_row")

	print("\n  Edit, Select by")
	var items: PackedStringArray = _select_by_items()
	print("     %s" % ", ".join(items))
	_check("Select by has Same part and Part number or name…",
		items.has("Same part") and items.has("Part number or name…"))
	_shell.run("select_find")
	await _frames(20)
	var find: LineEdit = _list._find
	_check("Part number or name… opens the list with its find to type into",
		_list.visible and find.has_focus())
	var before: int = _world.brick_count()
	await _type("blue 1x2 brick")
	_check("the words went to the find, none to the app's keys: '%s'" % find.text,
		find.text == "blue 1x2 brick" and _world.brick_count() == before and _list.visible
		and not _shell.see_inside.seeing_through)
	print("     the list: %s" % _list._heading.text)
	# Every word: the 1 x 2 brick and the Technic brick 1 x 2 with a hole.
	var shown: Array = []
	for pair: Array in _list._made:
		if (pair[1] as Node).get_parent() == _list._rows:
			shown.append("%s/%d" % [(pair[0] as Inventory.Lot).part_id,
				(pair[0] as Inventory.Lot).color_code])
	_check("the rows that answer it are the blue bricks 1 x 2: %s" % ", ".join(shown),
		shown == ["3004/1", "3700/1"])
	await _shot("findpart_find")
	await _key(KEY_ENTER)
	picked = _builder.selection.keys()
	var blue: BrickWorld.Brick = null
	var blues: int = 0
	for id: int in picked:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		blues += 1 if brick.color_code == 1 and brick.part_id in ["3004", "3700"] else 0
		if brick.part_id == "3004":
			blue = brick
	_check("Enter selects the four, the hotel's one blue 1 x 2 brick among them (%d)" % picked.size(),
		picked.size() == 4 and blues == 4 and blue != null)
	print("     the bar: %s" % _bar._status.text)
	await _frames(90)
	await _shot("findpart_found")

	_shell.run("select_find")
	await _frames(10)
	await _type("3004")
	await _key(KEY_ENTER)
	var bricks_1x2: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not scenery.has(brick.id) and brick.part_id.begins_with("3004") \
				and not brick.part_id.substr(4, 1).is_valid_int():
			bricks_1x2 += 1
	_check("\"3004\" selects every brick 1 x 2: %d of %d" % [_builder.selection.size(), bricks_1x2],
		bricks_1x2 > 50 and _builder.selection.size() == bricks_1x2)

	_shell.run("select_find")
	await _frames(10)
	await _type("no such part zzq")
	_check("words nothing answers say so: %s" % _list._heading.text,
		_list._heading.text.begins_with("Nothing in this model answers")
		and _list._rows.get_child_count() == 0)
	await _key(KEY_ESCAPE)
	_check("...and Escape puts the list away", not _list.visible)

	print("\n  the MCP")
	var assistant: Assistant = _main.get("_assistant")
	var listed: String = assistant._describe_world({"part": "3004", "color": 1})
	var where: String = ""
	for line: String in listed.split("\n"):
		if line.begins_with("  #"):
			where = line
	print("     %s" % where)
	_check("look_at_model part=3004 color=1 lists where the one blue 1 x 2 brick is",
		listed.contains("1 of them are the parts you asked about") and blue != null
		and where.begins_with("  #%d " % blue.id) and listed.contains("Where they are:"))
	listed = assistant._describe_world({"part": "blue 1x2 brick"})
	_check("...and part=\"blue 1x2 brick\" the four the find selected",
		listed.contains("4 of them are the parts you asked about"))
	_builder.clear_selection()
	await _frames(10)


## The longest frame after a click on a row of a thousand parts, and after
## Select all, on Orthanc: three of each, in turn.
func _time_on_orthanc(timing_only: bool) -> void:
	print("\n  frames on Orthanc")
	var placed: int = await _open("res://models/orthanc.ldr")
	_check("Orthanc is open (%d parts)" % placed, placed > 9000)
	var verbs: EditVerbs = _main.get("_verbs")
	var all_frames: Array = []
	var row_frames: Array = []
	for round: int in 3:
		all_frames.append(await _longest(func() -> void: _shell.run("select_all")))
		verbs.select_by("none")
		await _frames(30)
		if timing_only:
			continue
		_main.call("_toggle_parts")
		await _frames(30)
		var row: Button = null
		var count: int = 0
		for pair: Array in _list._made:
			var lot: Inventory.Lot = pair[0]
			if lot.part_id == "4070" and lot.color_code == 0:
				row = pair[1]
				count = lot.count
		if row == null:
			_check("Orthanc's list has its black 1 x 1 bricks with a stud on one side", false)
			return
		(_list._scroll as ScrollContainer).ensure_control_visible(row)
		await _frames(10)
		var at: Vector2 = row.get_global_rect().get_center()
		await _move(at)
		row_frames.append(await _longest(func() -> void:
			_button(at, true)
			await process_frame
			_button(at, false)))
		_check("round %d: the row selected its %d" % [round + 1, count],
			_builder.selection.size() == count and count >= 1000)
		verbs.select_by("none")
		await _frames(30)
	print("     Select all, longest frame: %s ms" % _list_ms(all_frames))
	if timing_only:
		return
	print("     a row of a thousand, longest frame: %s ms" % _list_ms(row_frames))
	var worst_row: float = row_frames.max()
	var worst_all: float = all_frames.max()
	_check("a row of a thousand is no slower than Select all (%.0f ms, %.0f ms)"
		% [worst_row, worst_all], worst_row <= worst_all)


## The longest gap between frames while [param act] runs and over the
## sixty frames after it, in ms.
func _longest(act: Callable) -> float:
	await _frames(20)
	var last: int = Time.get_ticks_usec()
	await act.call()
	var longest: float = 0.0
	for _n: int in 60:
		await process_frame
		var now: int = Time.get_ticks_usec()
		longest = maxf(longest, (now - last) / 1000.0)
		last = now
	return longest


static func _list_ms(values: Array) -> String:
	return ", ".join(values.map(func(ms: float) -> String: return "%.0f" % ms))


## The rows of Edit's Select by, as the menu shows them.
func _select_by_items() -> PackedStringArray:
	var out := PackedStringArray()
	var menu: PopupMenu = _named_popup(root, "select_by")
	if menu != null:
		for n: int in menu.item_count:
			out.append(menu.get_item_text(n))
	return out


## A submenu is its menu's internal child, which find_children passes over.
func _named_popup(node: Node, wanted: String) -> PopupMenu:
	for child: Node in node.get_children(true):
		if child is PopupMenu and child.name == wanted:
			return child
		var found: PopupMenu = _named_popup(child, wanted)
		if found != null:
			return found
	return null


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	_pointer = event.position
	Input.parse_input_event(event)
	await _frames(2)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _type(text: String) -> void:
	for character: String in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.keycode = OS.find_keycode_from_string(character.to_upper()) \
			if character != " " else KEY_SPACE
		event.physical_keycode = event.keycode
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	await _frames(6)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)
