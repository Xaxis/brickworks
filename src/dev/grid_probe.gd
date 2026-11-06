## Pattern's In a grid: a block of copies in one dialog (docs/APP_UX4.md,
## grid; LeoCAD's Array).
##
##   godot --path . --resolution 1400x900 --script src/dev/grid_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh grid_probe     the same at 1280 x 720
##
## Pattern made a row, a ring or a path, so a grid of copies was two runs of
## it: a row, then the row selected and copied in a row. LeoCAD's Array makes
## one in one go. Everything here is done through the window, as a person does
## it, from one 2 x 2 brick on the floor:
##
## * a click selects it, Ctrl+Shift+D opens Pattern, a click chooses In a
##   grid, and 4 columns, 3 rows and 2 levels, every 3 studs, 3 studs and 9
##   plates (3 bricks) up, are typed with Tab between them; the dialog says
##   it before anything is put down, and Enter puts it down;
## * 24 bricks, each at its place to the LDU (60 LDU a column and a row, 72 a
##   level, square to the grid), none in another's room; one step to undo,
##   one Ctrl+Z takes all 23 copies back and redo puts them back;
## * a 1 x 4 brick standing where column 3, row 2, level 1 would go: the
##   dialog says that copy has no room and what is in the way, draws it red,
##   and nothing is put down.
## The dialog is inside the window, every field in sight, in English, German,
## French and Spanish.
##
## And the same over MCP, as the owner's own Claude does it, called the way the
## connector and the desktop's MCP port call it (CommandSocket.answer_rpc,
## tools/call): pattern_parts lays the same 4 x 3 x 2 in 1 call, 24 bricks
## each at its place to the LDU, one undo step (the session's undo takes the
## 23 back), the person's selection as it was; the 1 x 4 brick in the way
## refused with its column, row and level and its number, nothing changed;
## and with no spacing given the copies touch, a 2 x 2 brick's own 2 studs
## and 3 plates, answered with a picture. Pictures go to shots/grid/.
extends SceneTree

const BRICK := "3003"     ## Brick 2 x 2
const IN_WAY := "3010"    ## Brick 1 x 4
const RED := 4
const BLUE := 1
## The 2 x 2 brick's place: on the floor, on the stud grid.
const AT := Vector3(0, 24, 0)
## Columns, rows and levels; and how far apart, in LDU: 3 studs, 3 studs, 3
## bricks (9 plates).
const COLUMNS := 4
const ROWS := 3
const LEVELS := 2
const APART := Vector3(60, 72, 60)

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _verbs: EditVerbs
var _shell: Shell
var _socket: CommandSocket
var _next: int = 0
var _tag: String = ""
var _said: String = ""
## What the status bar said when the grid was put down.
var _put_down: String = ""
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_had_autosave = FileAccess.file_exists(ModelStore.autosave())
	if _had_autosave:
		_autosave = FileAccess.get_file_as_bytes(ModelStore.autosave())
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_shell = _main.get("_shell")
	(_main.get("_bar") as ModelBar).said.connect(func(text: String) -> void: _said = text)
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	print("  Pattern's grid in a %s window" % _tag)

	if await _a_grid():
		await _one_undo()
		await _in_the_way()
	await _over_mcp()
	_put_back_autosave()
	print("")
	print("grid probe: a block of copies in one dialog and in one call, one undo, a copy with no room said where"
		if _failures == 0 else "grid probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## One 2 x 2 brick, selected by a click, Pattern opened, In a grid chosen
## and its six numbers typed, put down with Enter. Whether a grid was made.
func _a_grid() -> bool:
	print("")
	print("  a 2 x 2 brick in %d columns, %d rows and %d levels, every 3 studs, 3 studs and 3 bricks up"
		% [COLUMNS, ROWS, LEVELS])
	await _fresh()
	var first: int = _put(BRICK, RED, AT)
	await _look()
	await _shot("before")
	var acts: int = 0
	await _click(_screen(AT + Vector3(0, -4, 0)))
	acts += 1
	_check("a click selects the brick (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 1 and _builder.selection.has(first))
	await _key(KEY_D, true, true)
	acts += 1
	var dialog: PatternDialog = _shell.pattern_dialog
	_check("Ctrl+Shift+D opens Pattern", dialog.is_open())
	var controls: Dictionary = dialog.controls_by_name()
	var grid_button: Button = controls.get("pattern_grid")
	_check("Pattern has In a grid beside In a row (%s)" % _kinds(controls),
		grid_button != null and grid_button.is_visible_in_tree()
		and grid_button.text == "In a grid")
	if grid_button == null:
		print("    a person cannot make a grid in one dialog: only %s, so a 4 x 3 x 2 block is a row,"
			% _kinds(controls))
		print("    then that row copied in a row, then that layer copied up: three runs of Pattern")
		await _key(KEY_ESCAPE)
		return false
	# The dialog is a window of its own: its controls' places are its.
	await _click(Vector2(dialog.position) + grid_button.get_global_rect().get_center())
	acts += 1
	_check("In a grid is chosen (%s)" % dialog.kind, dialog.kind == "grid")
	var fields: Array = ["pattern_columns", "pattern_columns_every", "pattern_rows",
		"pattern_rows_every", "pattern_levels", "pattern_levels_every"]
	var in_sight: bool = true
	for named: String in fields:
		var field: LineEdit = controls.get(named)
		in_sight = in_sight and field != null and field.is_visible_in_tree()
	_check("...its columns, rows and levels, each with how far apart, in sight", in_sight)
	var window := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var box := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	_check("...the dialog inside the window (%s in %s)" % [box, window.size],
		window.encloses(box))
	var columns_field: LineEdit = controls.get("pattern_columns")
	_check("...the columns' field has the keys, its number selected to type over",
		columns_field != null and columns_field.has_focus())
	# Each number typed over the field's, Tab to the next.
	var typed: Array = [str(COLUMNS), "3", str(ROWS), "3", str(LEVELS), "9"]
	for n: int in typed.size():
		if n > 0:
			await _key(KEY_TAB)
			acts += 1
		var field: LineEdit = controls.get(fields[n])
		if field != null and not field.has_focus():
			print("    Tab did not reach %s" % fields[n])
		await _type(str(typed[n]))
		acts += 1
	await _frames(4)
	var state: Dictionary = dialog.page_state()
	print("    said: %s" % state["said"])
	_check("%d in all, %d copies, shown first: %s" % [state["in_all"], state["copies"],
		state["said"]], int(state["in_all"]) == COLUMNS * ROWS * LEVELS
		and int(state["copies"]) == COLUMNS * ROWS * LEVELS - 1
		and str(state["said"]).contains("4 columns 3 studs apart")
		and str(state["said"]).contains("3 rows 3 studs apart")
		and str(state["said"]).contains("2 levels 3 bricks apart")
		and str(state["said"]).contains("each has room") and bool(state["can_put"]))
	await _shot("dialog")
	var depth: int = _builder.history_depth()
	await _key(KEY_ENTER)
	acts += 1
	await _frames(6)
	_check("Enter puts it down and closes Pattern", not dialog.is_open())
	var bricks: Array = _of(BRICK)
	var placed: bool = _at_places(bricks)
	_check("%d bricks, each at its place to the LDU, square to the grid" % bricks.size(),
		bricks.size() == COLUMNS * ROWS * LEVELS and placed)
	_check("...none in another's room", _none_overlap(bricks))
	_check("...in one dialog: %d actions (a click, Ctrl+Shift+D, In a grid, six numbers, five Tabs, Enter)"
		% acts, acts == 15)
	_check("...one step to undo (%d steps more)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_check("...the copies selected (%d)" % _builder.selection.size(),
		_builder.selection.size() == COLUMNS * ROWS * LEVELS - 1)
	var status: String = _status()
	_put_down = status
	_check("the status bar says it and its undo: \"%s\"" % status,
		status.contains("23 copies") and status.contains("takes them all back"))
	_builder.clear_selection()
	await _frames(4)
	await _shot("after")
	return bricks.size() == COLUMNS * ROWS * LEVELS


## One Ctrl+Z takes the 23 copies back; redo puts them back where they were.
func _one_undo() -> void:
	print("")
	print("  one undo")
	await _key(KEY_Z, true)
	await _frames(4)
	_check("one Ctrl+Z takes all 23 copies back (%d bricks)" % _of(BRICK).size(),
		_of(BRICK).size() == 1 and _at(_of(BRICK)[0] as BrickWorld.Brick, Vector3i.ZERO))
	await _key(KEY_Z, true, true)
	await _frames(4)
	_check("...and redo puts them back, each at its place (%d bricks)" % _of(BRICK).size(),
		_of(BRICK).size() == COLUMNS * ROWS * LEVELS and _at_places(_of(BRICK)))


## A 1 x 4 brick where column 3, row 2, level 1 would go: refused, with
## where, and nothing put down.
func _in_the_way() -> void:
	print("")
	print("  a grid that would collide")
	await _fresh()
	var first: int = _put(BRICK, RED, AT)
	var where: Vector3 = AT + Vector3(2 * APART.x, 0, 1 * APART.z)
	_put(IN_WAY, BLUE, where)
	await _look()
	await _click(_screen(AT + Vector3(0, -4, 0)))
	_check("a click selects the 2 x 2 brick", _builder.selection.size() == 1
		and _builder.selection.has(first))
	await _key(KEY_D, true, true)
	var dialog: PatternDialog = _shell.pattern_dialog
	var controls: Dictionary = dialog.controls_by_name()
	_check("Pattern opens on In a grid, the kind last used (%s)" % dialog.kind,
		dialog.is_open() and dialog.kind == "grid")
	var typed: Array = [str(COLUMNS), "3", str(ROWS), "3", str(LEVELS), "9"]
	for n: int in typed.size():
		if n > 0:
			await _key(KEY_TAB)
		await _type(str(typed[n]))
	await _frames(4)
	var state: Dictionary = dialog.page_state()
	var name: String = _name(IN_WAY)
	print("    said: %s" % state["said"])
	_check("the copy in its way is said by its place and what is there: %s" % state["said"],
		str(state["said"]).contains("the copy in column 3, row 2, level 1 has no room")
		and str(state["said"]).contains("%s is in the way" % name))
	_check("...and it cannot be put down", not bool(state["can_put"])
		and (controls.get("pattern_ok") as Button).disabled)
	await _shot("in_the_way")
	var before: int = _world.bricks().size()
	await _key(KEY_ENTER)
	await _frames(4)
	_check("...Enter puts none of it down (%d parts, %d before)" % [_world.bricks().size(), before],
		_world.bricks().size() == before)
	await _words(dialog, [str(state["said"]), _put_down])
	await _key(KEY_ESCAPE)
	await _frames(4)
	_check("Escape closes Pattern, the copies' ghosts gone", not dialog.is_open())


## Every word the dialog shows, and [param lines] (what it and the status bar
## said), in German, French and Spanish: each translated, none left in English
## but a part's name and a key; and the dialog inside the window in each.
func _words(dialog: PatternDialog, lines: Array) -> void:
	print("")
	print("  in German, French and Spanish")
	var english: Array[String] = []
	for node: Node in dialog.find_children("*", "", true, false):
		var text: String = str(node.get("text")) if (node is Label or node is Button) else ""
		if not text.is_empty() and text.to_lower() != text.to_upper() and not english.has(text) \
				and (node as CanvasItem).is_visible_in_tree():
			english.append(text)
	for line: Variant in lines:
		if not str(line).is_empty():
			english.append(str(line))
	var allowed: Array[String] = [_name(IN_WAY), "Ctrl-Z", "x", "z"]
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		await _frames(6)
		var lacking := PackedStringArray()
		for text: String in english:
			var said: String = Language.says(text)
			var left: Array = Language.left_in_english(text).filter(func(kept: String) -> bool:
				return not allowed.has(kept.strip_edges()))
			if said.is_empty() or not left.is_empty():
				lacking.append("%s%s" % [text, (" (%s)" % ", ".join(left)) if not left.is_empty() else ""])
		_check("%s: every one of the %d translated%s" % [code, english.size(),
			"" if lacking.is_empty() else "; not: " + " | ".join(lacking)], lacking.is_empty())
		print("    %s" % Language.says(str(lines[0])))
		# Opened again as a person in this language opens it, laid out in its
		# words: the counts kept, the spacings the brick's own again.
		dialog.hide()
		await _frames(2)
		dialog.open(_builder.selection.keys())
		await _frames(6)
		var window := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var box := Rect2(Vector2(dialog.position), Vector2(dialog.size))
		_check("%s: ...the dialog inside the window (%s)" % [code, box], window.encloses(box))
		await _shot("in_the_way_" + code)
	Language.apply("en")
	await _frames(4)


## The same grid over MCP, in 1 call; its undo; the collision; the copies
## touching when no spacing is given.
func _over_mcp() -> void:
	print("")
	print("  over MCP, as the owner's Claude calls it")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await _frames(2)
	var listed: Dictionary = await _rpc("tools/list", {})
	var tool: Dictionary = {}
	for one: Dictionary in listed.get("tools", []):
		if str(one["name"]) == "pattern_parts":
			tool = one
	_check("tools/list offers pattern_parts, not read-only (%s)" % str(tool.get("annotations", {})),
		not tool.is_empty() and not bool((tool.get("annotations", {}) as Dictionary)
			.get("readOnlyHint", true)))
	if tool.is_empty():
		print("    a session cannot lay a grid in one call: it lays 23 copies a part at a time")
		return
	await _fresh()
	var first: int = _put(BRICK, RED, AT)
	await _look()
	var depth: int = _builder.history_depth()
	var calls: int = 0
	var said: String = _text(await _rpc("tools/call", {"name": "pattern_parts", "arguments": {
		"bricks": [first], "columns": COLUMNS, "rows": ROWS, "levels": LEVELS,
		"column_studs": 3, "row_studs": 3, "level_plates": 9, "picture": false}}))
	calls += 1
	print("    said: %s" % said)
	var bricks: Array = _of(BRICK)
	_check("in %d call: %d bricks, each at its place to the LDU, square to the grid"
		% [calls, bricks.size()], calls == 1 and bricks.size() == COLUMNS * ROWS * LEVELS
		and _at_places(bricks))
	_check("...none in another's room", _none_overlap(bricks))
	_check("...said: 24 in all, 4 columns, 3 rows and 2 levels as asked, one undo step",
		said.contains("24 in all") and said.contains("4 columns 3 studs apart")
		and said.contains("3 rows 3 studs apart")
		and said.contains("2 levels 9 plates (3 bricks) apart") and said.contains("One undo step"))
	_check("...one step to undo (%d more)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_check("...the person's selection as it was (%d selected)" % _builder.selection.size(),
		_builder.selection.is_empty())
	await _frames(4)
	await _shot("mcp_after")
	var undone: String = _text(await _rpc("tools/call", {"name": "undo", "arguments": {}}))
	_check("the session's undo, once, takes all 23 copies back (%d bricks): %s"
		% [_of(BRICK).size(), undone.left(90)], _of(BRICK).size() == 1
		and _at(_of(BRICK)[0] as BrickWorld.Brick, Vector3i.ZERO))

	# The 1 x 4 brick where column 3, row 2, level 1 would go.
	var where: Vector3 = AT + Vector3(2 * APART.x, 0, 1 * APART.z)
	var in_way: int = _put(IN_WAY, BLUE, where)
	await _frames(2)
	var before: int = _world.bricks().size()
	depth = _builder.history_depth()
	said = _text(await _rpc("tools/call", {"name": "pattern_parts", "arguments": {
		"bricks": [first], "columns": COLUMNS, "rows": ROWS, "levels": LEVELS,
		"column_studs": 3, "row_studs": 3, "level_plates": 9}}))
	print("    said: %s" % said)
	_check("a grid that would collide is refused with where: %s" % said,
		said.contains("the copy in column 3, row 2, level 1 has no room")
		and said.contains("%s is in the way (#%d)" % [_name(IN_WAY), in_way])
		and said.contains("Nothing changed"))
	_check("...nothing put down (%d parts, %d before), no step to undo (%d more)"
		% [_world.bricks().size(), before, _builder.history_depth() - depth],
		_world.bricks().size() == before and _builder.history_depth() == depth)

	# No spacing given: the brick's own size, so the copies touch.
	await _fresh()
	first = _put(BRICK, RED, AT)
	await _frames(2)
	var answer: Dictionary = await _rpc("tools/call", {"name": "pattern_parts", "arguments": {
		"bricks": [first], "columns": 2, "levels": 2}})
	said = _text(answer)
	var pictured: bool = (answer.get("content", []) as Array).any(func(block: Dictionary) -> bool:
		return str(block.get("type", "")) == "image")
	var origins: Array = _of(BRICK).map(func(b: BrickWorld.Brick) -> Vector3:
		return b.transform.origin - AT)
	var touching: bool = origins.size() == 4
	for want: Vector3 in [Vector3(0, 0, 0), Vector3(40, 0, 0), Vector3(0, 24, 0),
			Vector3(40, 24, 0)]:
		touching = touching and origins.any(func(at: Vector3) -> bool:
			return at.distance_to(want) < 0.01)
	_check("with no spacing given, a 2 x 2 brick's own 2 studs and 3 plates: touching (%s)"
		% str(origins), touching and said.contains("2 columns 2 studs apart")
		and said.contains("2 levels 3 plates (1 brick) apart"))
	_check("...answered with the copies pictured (%s)" % ("a picture" if pictured else "words alone"),
		pictured or DisplayServer.get_name() == "headless")
	_socket.queue_free()


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


# -- the model -----------------------------------------------------------------


## Whether [param bricks] are the grid: one at each place, each square.
func _at_places(bricks: Array) -> bool:
	var seen: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		var place: Vector3 = (brick.transform.origin - AT) / APART
		var cell := Vector3i(roundi(place.x), roundi(place.y), roundi(place.z))
		if not _at(brick, cell) or seen.has(cell) or cell.x < 0 or cell.x >= COLUMNS \
				or cell.z < 0 or cell.z >= ROWS or cell.y < 0 or cell.y >= LEVELS:
			print("    %s at %s is at no place of the grid" % [brick.part_id, brick.transform.origin])
			return false
		seen[cell] = true
	return seen.size() == COLUMNS * ROWS * LEVELS


## Whether [param brick] is at column x, level y, row z exactly, unturned.
func _at(brick: BrickWorld.Brick, cell: Vector3i) -> bool:
	var want: Vector3 = AT + Vector3(cell) * APART
	return brick.transform.origin.distance_to(want) < 0.01 \
		and brick.transform.basis.is_equal_approx(Basis.IDENTITY)


## Whether every part has room where it stands, by the rule a part put
## down meets: each taken out of the lattice and asked again.
func _none_overlap(bricks: Array) -> bool:
	for brick: BrickWorld.Brick in bricks:
		_builder.lattice.release(brick.id)
		var fits: bool = _builder.room_for(brick.part_id, brick.transform, false)
		_builder.register(brick.id, brick.part_id, brick.transform)
		if not fits:
			print("    %s at %s has no room" % [brick.part_id, brick.transform.origin])
			return false
	return true


func _of(part: String) -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool: return b.part_id == part)


func _name(part: String) -> String:
	var name: String = (_library.parts[part] as PartLibrary.PartInfo).name
	while name.contains("  "):
		name = name.replace("  ", " ")
	return name


func _kinds(controls: Dictionary) -> String:
	var out := PackedStringArray()
	for named: String in controls:
		if controls[named] is Button and named != "pattern_ok":
			out.append((controls[named] as Button).text)
	return ", ".join(out)


## What the status bar said last (ModelBar.said).
func _status() -> String:
	return _said


func _put(part: String, colour: int, at: Vector3) -> int:
	var where := Transform3D(Basis.IDENTITY, at)
	var id: int = _world.add_brick(part, colour, where)
	_builder.register(id, part, where)
	return id


## An empty model, the Select tool, nothing in hand, no history.
func _fresh() -> void:
	await _key(KEY_ESCAPE)
	_main.call("clear_model")
	await _frames(6)
	_builder.forget_history()
	_builder.clear_selection()
	if _verbs.mode != "select":
		_verbs.set_mode("select")
	await _frames(4)


func _look() -> void:
	_camera.frame(AABB(Vector3(-40, 0, -40), Vector3(280, 170, 220)), 1.0)
	_camera.look_from(Vector3(0.45, 0.55, 0.7).normalized())
	await create_timer(1.5).timeout
	await _frames(10)


# -- a person's hands ----------------------------------------------------------


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2 if down else 4)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://shots/grid/%s_%s.png" % [name, _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


## Whether user:// is this run's own (probe.sh's XDG_DATA_HOME), never the
## person's.
func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _put_back_autosave() -> void:
	if _had_autosave:
		var file: FileAccess = FileAccess.open(ModelStore.autosave(), FileAccess.WRITE)
		if file != null:
			file.store_buffer(_autosave)
			file.close()
	elif FileAccess.file_exists(ModelStore.autosave()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.autosave()))
