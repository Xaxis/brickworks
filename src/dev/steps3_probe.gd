## Any step in one action, by hand and over MCP (APP_UX3 steps3).
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw \
##     xvfb-run -a -s '-screen 0 1400x900x24' godot --path . --resolution 1280x720 \
##     --script src/dev/steps3_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh steps3_probe
##
## A model of twenty steps opened from its file, as its author stepped it:
## a 2 x 2 brick a step along a baseplate, two in step 3. The second of
## step 3's is moved to step 17, each way a person or a session does it,
## and read back off the plan the booklet is made from (Instructions.plan
## with the author's steps), never off the edit's own words:
## - dragged from its yellow mark on the timeline's row of steps onto step
##   17: one drag, real mouse events against the window;
## - Alt+T, then 17 and Return typed into Move to step…: two actions;
## - Move to step… on the menu on the part, a number typed;
## - edit_steps {"op": "to"} over MCP, called as the connector calls it:
##   one call, and a step that is not there refused with nothing changed.
## Each is one undo step, the model still has twenty steps, and an undo
## puts the part back in step 3.
##
## Then the four step commands of Build steps (earlier, later, merge,
## delete): each has a key, and its key does to the step showing exactly
## what its menu row does. And the presets' own: under LDCad's keys Page Up
## and Page Down step the timeline, Ctrl with them to its end and start, and
## Page Up off the timeline still raises the selection; under Studio's,
## Ctrl+D and Ctrl+A move the selection a step on the timeline, and Ctrl+A
## off it still selects all. The keys sheet names them.
##
## Pictures in shots/steps3/, named by the window's size.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _steps: StepsBar
var _socket: CommandSocket
var _size: String = ""
var _rpc_id: int = 0
## The part moved: the second 2 x 2 brick of step 3.
var _moved: int = 0


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
	Keymap.reset()
	Keymap.use("brickworks")
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_store = _main.get("_store")
	_store.keeps = false
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_steps = _main.get("_steps")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	var bar: ModelBar = _main.get("_bar")
	var placed: int = await bar.open_with_progress(_write_model())
	bar.opened.emit(placed)
	await _frames(60)
	print("steps3 probe at %s, %d parts in %d steps" % [_size, placed, _plan().size()])
	_check("the model opens with its author's twenty steps", _plan().size() == 20
		and AuthorSteps.any(_world, _store.scenery))
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.step == 2 and brick.id > _moved:
			_moved = brick.id
	_check("step 3 holds two parts, part %d the second (in step %d)" % [_moved, _step_of(_moved)],
		_step_of(_moved) == 3)
	_camera.frame(AABB(Vector3(-40, 0, -40), Vector3(320, 60, 160)))
	await _timeline_up()
	await _by_drag()
	await _by_typing()
	await _by_part_menu()
	await _by_mcp()
	await _four_keys()
	await _presets()
	if _failures == 0:
		print("steps3 probe: all checks passed")
	else:
		print("steps3 probe: %d checks failed" % _failures)
	Keymap.use("brickworks")
	_world.clear()
	await _frames(6)
	quit(1 if _failures > 0 else 0)


## Twenty steps of the author's: a 2 x 2 brick a step, side by side on the
## floor so none stands on another, and two in step 3.
func _write_model() -> String:
	var lines := PackedStringArray(["0 Twenty steps", "0 Name: steps3.ldr", "0 Author: steps3 probe"])
	var at: int = 0
	for step: int in range(1, 21):
		for _n: int in (2 if step == 3 else 1):
			lines.append("1 %d %d -24 %d 1 0 0 0 1 0 0 0 1 3003.dat" % [[4, 1, 14, 2][at % 4],
				(at % 7) * 40, (at / 7) * 40])
			at += 1
		if step < 20:
			lines.append("0 STEP")
	var path: String = OS.get_user_data_dir().path_join("steps3.ldr")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return path


## The booklet's plan as it is now: the author's steps.
func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _main.get("_library"), _store.scenery, {}, true)


## The number of the booklet's step [param brick_id] is in, or 0.
func _step_of(brick_id: int) -> int:
	for step: Instructions.Step in _plan():
		if step.brick_ids.has(brick_id):
			return step.number
	return 0


func _timeline_up() -> void:
	if not _steps.is_playing_back():
		_shell.run("timeline")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(10)
	var row: Dictionary = _steps.row_state()
	_check("the timeline opens in the author's steps with its row of %d steps shown" % int(row["cells"]),
		_steps.mode() == StepsBar.AUTHORS and bool(row["shown"]) and int(row["cells"]) == 20)


# -- the drag ----------------------------------------------------------------


func _by_drag() -> void:
	_select(_moved)
	await _frames(6)
	var row: Dictionary = _steps.row_state()
	_check("selected, its step marked on the row (%s)" % str(row["marked"]), row["marked"] == [2])
	await _shot("marked")
	var depth: int = _builder.history_depth()
	# One drag: down on the mark, along the row, up on step 17.
	var from: Vector2 = _cell(2)
	var to: Vector2 = _cell(16)
	await _mouse_move(from)
	await _mouse_button(from, true)
	for n: int in range(1, 13):
		await _mouse_move(from.lerp(to, n / 12.0), true)
	await _shot("dragging")
	await _mouse_button(to, false)
	await _frames(12)
	_check("one drag puts it in step 17 (plan: step %d, %d steps)" % [_step_of(_moved), _plan().size()],
		_step_of(_moved) == 17 and _plan().size() == 20)
	_check("...in one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_check("...the timeline showing step 17, its mark there (%s)" % str(_steps.row_state()["marked"]),
		_steps.current_step() != null and _steps.current_step().number == 17
		and _steps.row_state()["marked"] == [16])
	await _shot("dropped")
	await _press(Keymap.CTRL | KEY_Z)
	_check("Ctrl+Z puts it back in step 3 (%d)" % _step_of(_moved), _step_of(_moved) == 3
		and _builder.history_depth() == depth)


# -- the command, and the number typed --------------------------------------


func _by_typing() -> void:
	_select(_moved)
	await _frames(4)
	var depth: int = _builder.history_depth()
	_check("Move to step… has Alt+T (%s)" % Keymap.written("step_to"),
		Keymap.key_of("step_to") == Keymap.ALT | KEY_T)
	await _press(Keymap.ALT | KEY_T)
	var asked: ConfirmationDialog = _steps.get("_ask")
	var number: SpinBox = _steps.get("_ask_number")
	_check("Alt+T opens Move to step… on the step it is in, chosen to be typed over (%s)" % (
		number.get_line_edit().text if number != null else "none"), asked != null and asked.visible
		and int(number.value) == 3 and number.get_line_edit().has_focus()
		and number.get_line_edit().get_selected_text() == "3")
	await _type("17")
	await _shot("move_to_step")
	await _press(KEY_ENTER)
	await _frames(8)
	_check("17 and Return put it in step 17 (plan: step %d), the dialog gone" % _step_of(_moved),
		_step_of(_moved) == 17 and not asked.visible and _plan().size() == 20)
	_check("...two actions, one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	await _undo()
	_check("undone, back in step 3 (%d)" % _step_of(_moved), _step_of(_moved) == 3)


func _by_part_menu() -> void:
	_builder.clear_selection()
	_steps.stop()
	await _frames(6)
	var menu: PopupMenu = await _right_click(_moved)
	var at: int = _shell.item_index(menu, "step_to")
	_check("the menu on a part has Move to step… with its key (%s)" % (
		"%s, %s" % [menu.get_item_text(at), Shell.key_text(menu.get_item_accelerator(at))]
		if at >= 0 else "none"), at >= 0 and _shows_key(menu, at, "step_to"))
	menu.id_pressed.emit(menu.get_item_id(at))
	menu.hide()
	await _frames(8)
	var asked: ConfirmationDialog = _steps.get("_ask")
	_check("...it asks for the step with the timeline down", asked.visible)
	await _type("12")
	await _press(KEY_ENTER)
	await _frames(8)
	_check("...and 12 typed puts it in step 12 (plan: step %d)" % _step_of(_moved),
		_step_of(_moved) == 12)
	await _undo()
	await _timeline_up()


# -- over MCP ---------------------------------------------------------------------


func _by_mcp() -> void:
	var depth: int = _builder.history_depth()
	var said: String = await _say("edit_steps", {"op": "to", "bricks": [_moved], "step": 17})
	print("    edit_steps to 17: %s" % said)
	_check("edit_steps {\"op\": \"to\", \"step\": 17} in 1 call puts it in step 17 (plan: step %d)"
		% _step_of(_moved), _step_of(_moved) == 17 and _plan().size() == 20)
	_check("...one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	said = await _say("edit_steps", {})
	_check("...and its list says so: %s" % said.get_slice("\n", 17).strip_edges(),
		said.get_slice("\n", 17).strip_edges().begins_with("17:")
		and said.get_slice("\n", 17).contains("#%d" % _moved))
	await _undo()
	depth = _builder.history_depth()
	said = await _say("edit_steps", {"op": "to", "bricks": [_moved], "step": 99})
	_check("a step that is not there is refused: %s" % said, said.begins_with("There is no step 99"))
	said = await _say("edit_steps", {"op": "to", "bricks": [_moved]})
	_check("no step= is refused: %s" % said, said.begins_with("Give step="))
	_check("...and nothing changed (step %d, %d undo steps more)" % [_step_of(_moved),
		_builder.history_depth() - depth], _step_of(_moved) == 3 and _builder.history_depth() == depth)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


# -- the four step commands' keys ---------------------------------------------


func _four_keys() -> void:
	var steps_menu: PopupMenu = _steps_submenu()
	var heard: Array = []
	(_main.get("_bar") as ModelBar).said.connect(func(text: String) -> void: heard.append(
		"%s (on %d)" % [text, _steps.current_step().number if _steps.current_step() != null else 0]))
	for named: String in ["step_earlier", "step_later", "step_merge", "step_delete"]:
		var key: int = Keymap.key_of(named)
		await _go_to_step(10)
		var before: Dictionary = _steps_now()
		var on_key: int = _steps.current_step().number if _steps.current_step() != null else 0
		await _press(key)
		var by_key: Dictionary = _steps_now()
		await _undo()
		await _go_to_step(10)
		var on_menu: int = _steps.current_step().number if _steps.current_step() != null else 0
		var menu_from: Dictionary = _steps_now()
		var at: int = _shell.item_index(steps_menu, named)
		steps_menu.id_pressed.emit(steps_menu.get_item_id(at))
		await _frames(8)
		var by_menu: Dictionary = _steps_now()
		if by_key != by_menu:
			print("    %s: on step %d for the key, %d for the menu; by key %s; undone %s; by menu %s; said %s" % [
				named, on_key, on_menu, _diff(before, by_key), _diff(before, menu_from),
				_diff(before, by_menu), " | ".join(heard)])
		heard.clear()
		await _undo()
		_check("%s has %s, and it does on step 10 what its menu row (%s) does (%d parts changed by the key, %d by the menu)" % [named,
			Keymap.written(named), steps_menu.get_item_text(at) if at >= 0 else "none",
			_changed(before, by_key), _changed(before, by_menu)],
			key != 0 and at >= 0 and by_key == by_menu and by_key != before
			and _shows_key(steps_menu, at, named))


## Whether a menu's row shows its command's key, drawn or after its words.
func _shows_key(menu: PopupMenu, at: int, named: String) -> bool:
	var key: int = Keymap.key_of(named)
	return key != 0 and (menu.get_item_accelerator(at) == key
		or menu.get_item_text(at).ends_with(Shell.key_text(key)))


func _steps_submenu() -> PopupMenu:
	var build: PopupMenu = _shell.menu("Build").get_popup()
	for child: Node in build.get_children(true):
		if child is PopupMenu and child.name == "steps":
			return child
	return null


static func _diff(before: Dictionary, after: Dictionary) -> String:
	var out := PackedStringArray()
	for brick_id: Variant in before:
		if after.get(brick_id) != before[brick_id]:
			out.append("#%d %d>%d" % [brick_id, before[brick_id], after.get(brick_id, -9)])
	return " ".join(out)


static func _changed(before: Dictionary, after: Dictionary) -> int:
	var count: int = 0
	for brick_id: Variant in before:
		if after.get(brick_id) != before[brick_id]:
			count += 1
	return count


## Every part's step, by id.
func _steps_now() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.step
	return out


func _go_to_step(number: int) -> void:
	await _mouse_move(_cell(number - 1))
	await _mouse_button(_cell(number - 1), true)
	await _mouse_button(_cell(number - 1), false)
	await _frames(4)


# -- the presets' own -----------------------------------------------------------


func _presets() -> void:
	Keymap.use("ldcad")
	await _frames(2)
	_builder.clear_selection()
	await _go_to_step(5)
	await _press(KEY_PAGEUP)
	var after: int = _steps.current_step().number if _steps.current_step() != null else 0
	await _press(KEY_PAGEDOWN)
	var back: int = _steps.current_step().number if _steps.current_step() != null else 0
	_check("LDCad's keys: on the timeline Page Up is the step after (5 to %d), Page Down the step "
		% after + "before (%d)" % back, after == 6 and back == 5)
	await _press(Keymap.CTRL | KEY_PAGEUP)
	var shown: Vector2i = _steps.timeline_at()
	await _press(Keymap.CTRL | KEY_PAGEDOWN)
	_check("...Ctrl+Page Up its end (%d of %d), Ctrl+Page Down its start (%d)" % [shown.x, shown.y,
		_steps.timeline_at().x], shown.x == shown.y and _steps.timeline_at().x == 0)
	var sheet: Array = ControlsHint.for_keyboard().filter(func(binding: ControlsHint.Binding) -> bool:
		return binding.section == "The timeline" and "Page Up" in binding.keys)
	_check("...the keys sheet says so (%s)" % (sheet[0].verb if not sheet.is_empty() else "nothing"),
		sheet.size() == 1)
	_steps.stop()
	await _frames(6)
	_select(_moved)
	var low: float = _world.get_brick(_moved).transform.origin.y
	await _press(KEY_PAGEUP)
	_check("...off the timeline Page Up raises the selection still (%.0f to %.0f)" % [low,
		_world.get_brick(_moved).transform.origin.y], _world.get_brick(_moved).transform.origin.y > low)
	await _undo()

	Keymap.use("studio")
	await _timeline_up()
	_select(_moved)
	await _frames(4)
	await _press(Keymap.CTRL | KEY_D)
	var later: int = _step_of(_moved)
	await _press(Keymap.CTRL | KEY_A)
	_check("Studio's keys: on the timeline Ctrl+D moves the selection a step later (3 to %d) and "
		% later + "Ctrl+A back (%d)" % _step_of(_moved), later == 4 and _step_of(_moved) == 3)
	_steps.stop()
	await _frames(6)
	_builder.clear_selection()
	await _press(Keymap.CTRL | KEY_A)
	_check("...off the timeline Ctrl+A selects all still (%d of %d)" % [_builder.selection.size(),
		_world.brick_count() - _store.scenery.size()],
		_builder.selection.size() == _world.brick_count() - _store.scenery.size())
	_builder.clear_selection()
	Keymap.use("brickworks")
	await _timeline_up()
	await _shot("timeline")


# -- input -----------------------------------------------------------------------


func _select(brick_id: int) -> void:
	_builder.clear_selection()
	_builder.select_brick(brick_id, false)


## The middle of the row's cell for [param index], in the window's points.
func _cell(index: int) -> Vector2:
	var rect: Rect2 = _steps.row_state()["rect"]
	var cells: int = _steps.row_state()["cells"]
	return Vector2(rect.position.x + (index + 0.5) * rect.size.x / cells, rect.get_center().y)


## Ctrl+Z, as a person takes a change back: the timeline follows it.
func _undo() -> void:
	await _press(Keymap.CTRL | KEY_Z)
	await _frames(4)


func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


## Digits typed as a person types them, each a character.
func _type(text: String) -> void:
	for character: String in text:
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(character)
			event.physical_keycode = event.keycode
			event.unicode = character.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


## Where the pointer was last moved to, in the window's pixels: a drag is
## started by how far it has moved (relative), as a real mouse says.
var _pointer := Vector2.ZERO


func _mouse_move(at: Vector2, held: bool = false) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = move.position - _pointer
	_pointer = move.position
	# The pointer itself too: a drop is read where the pointer is.
	Input.warp_mouse(move.position)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(move)
	await _frames(2)


func _mouse_button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(2)


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
	await _frames(6)
	return _shell.context


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(named: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path("res://shots/steps3")
	DirAccess.make_dir_recursive_absolute(folder)
	var image: Image = root.get_texture().get_image()
	image.save_png(folder.path_join("%s_%s.png" % [named, _size]))
