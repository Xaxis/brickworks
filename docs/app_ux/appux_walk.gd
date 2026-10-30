## appux371's walk: a person's first hour, timed, counted and pictured.
## Research only (docs/APP_UX.md), not in the suite. Kept here under a
## .gdignore; copy it to src/dev/ to run it through tools/probe.sh
## (PROBE_SIZE=1280x720 for a laptop's window). SECTION is menus, search,
## wall, turns or dialogs. Pictures go to shots/appux/<width>x<height>/.
##
##   godot --path . --resolution 1400x900 --script src/dev/appux_walk.gd -- [only=SECTION]
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _bin: PartsBin
var _events: int = 0
var _out: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var size: Vector2i = DisplayServer.window_get_size()
	_out = "res://shots/appux/%dx%d/" % [size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var t0: int = Time.get_ticks_msec()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	print("WALK boot_120_frames_ms %d" % (Time.get_ticks_msec() - t0))
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	await _frames(60)
	await _shot("00_first_open")
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
	if only == "" or only == "menus":
		await _menus()
	if only == "" or only == "search":
		await _search_quality()
	if only == "" or only == "wall":
		await _first_wall()
	if only == "" or only == "turns":
		await _turns()
	if only == "" or only == "dialogs":
		await _dialogs()
	print("WALK done")
	quit(0)


func _menus() -> void:
	var menus: Array = _shell.get("_menus")
	for menu: MenuButton in menus:
		menu.show_popup()
		await _frames(20)
		var popup: PopupMenu = menu.get_popup()
		var items: int = popup.item_count
		var greyed: int = 0
		var keyed: int = 0
		for n: int in items:
			if popup.is_item_disabled(n):
				greyed += 1
			if popup.get_item_accelerator(n) != 0:
				keyed += 1
		print("WALK menu %s items=%d greyed=%d with_key=%d height=%d" % [menu.text, items,
			greyed, keyed, popup.size.y])
		await _shot("menu_" + menu.text.to_lower())
		popup.hide()
		await _frames(5)
	# The right-click menu on a part of the example.
	var bricks: Array = _model()
	if not bricks.is_empty():
		var at: Vector2 = _camera.unproject_position((bricks[0] as BrickWorld.Brick).transform.origin)
		_shell.open_context(at)
		await _frames(20)
		var context: PopupMenu = _shell.context
		print("WALK context items=%d" % context.item_count)
		await _shot("menu_context")
		context.hide()
		await _frames(5)


## A builder's words, and the part they mean.
const QUERIES: Array = [
	["2x4", "3001"], ["brick 2x4", "3001"], ["2 x 4 brick", "3001"], ["1x2 plate", "3023"],
	["plate 2x2", "3022"], ["3001", "3001"], ["300121", "3001"], ["slope 45 2x2", "3039"],
	["cheese slope", "54200"], ["tile 1x2", "3069b"], ["grille", "2412b"], ["jumper", "3794b"],
	["headlight", "4070"], ["round 1x1", "4073"], ["hinge", ""], ["clip", ""],
	["technic pin", "2780"], ["axle 4", "3705"], ["liftarm 7", "32524"], ["beam 7", "32524"],
	["window", ""], ["door", ""], ["wheel", ""], ["minifig head", "3626"], ["torso", ""],
	["macaroni", "25269"], ["snot", ""], ["bracket", "99781"], ["log", "30136"], ["arch", ""],
]


func _search_quality() -> void:
	var search: LineEdit = _bin.get("_search")
	for pair: Array in QUERIES:
		var query: String = pair[0]
		await _click(search.get_global_rect().get_center())
		await _key(KEY_A, true)
		var start: int = Time.get_ticks_usec()
		await _type(query)
		var typed: int = Time.get_ticks_usec()
		await create_timer(0.35).timeout
		await _frames(3)
		var results: Array = _bin.get("_results")
		var top: Array = []
		var rank: int = -1
		for n: int in mini(results.size(), 40):
			var id: String = _id_of(results[n])
			if id == str(pair[1]) and rank < 0:
				rank = n + 1
			if n < 5:
				top.append("%s %s" % [id, _name_of(id)])
		print("WALK search %-14s want=%-6s rank=%s total=%d typing_ms=%d top=%s" % [
			"\"%s\"" % query, pair[1], str(rank) if rank > 0 else "-", results.size(),
			(typed - start) / 1000, " | ".join(top)])
		if query in ["2x4", "hinge", "window", "cheese slope"]:
			await _shot("search_" + query.replace(" ", "_"))
	await _click(search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _key(KEY_BACKSPACE)


func _id_of(result: Variant) -> String:
	if result is String:
		return result
	if result is Object and (result as Object).get("id") != null:
		return str((result as Object).get("id"))
	if result is Dictionary:
		return str((result as Dictionary).get("id", ""))
	return str(result)


func _name_of(id: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(id)
	return info.name if info != null else ""


## Four 1 x 4 bricks in a row and four more on them, half a brick along:
## the events a person spends, and the frames.
func _first_wall() -> void:
	_main.call("clear_model")
	await _frames(30)
	_camera.frame(AABB(Vector3(-200, -40, -120), Vector3(400, 120, 240)))
	await _frames(40)
	_events = 0
	var start: int = Time.get_ticks_msec()
	var search: LineEdit = _bin.get("_search")
	await _click(search.get_global_rect().get_center())
	await _type("1x4 brick")
	await create_timer(0.35).timeout
	await _frames(4)
	var grid: GridContainer = _bin.get("_grid")
	var first: Control = grid.get_child(0)
	print("WALK wall first tile %s" % str(first.get_meta("part", "?")))
	await _click(first.get_global_rect().get_center())
	await _frames(6)
	print("WALK wall in hand=%s after %d events" % [_builder.is_carrying(), _events])
	var placed: int = 0
	for row: int in 2:
		for n: int in 4:
			var at := Vector3(-120 + n * 80 + row * 40, row * 24, 0)
			var spot: Vector2 = _camera.unproject_position(at + Vector3(0, 24, 0))
			await _move(spot)
			await _move(spot + Vector2(1, 0))
			await _click(spot + Vector2(1, 0))
			placed += 1
	await _key(KEY_ESCAPE)
	print("WALK wall parts=%d events=%d ms=%d" % [_count(), _events, Time.get_ticks_msec() - start])
	await _shot("wall")
	# A ghost swept across the model: the frame times a hand feels.
	await _key(KEY_Q)
	var worst: int = 0
	var total: int = 0
	for n: int in 40:
		var spot: Vector2 = _camera.unproject_position(Vector3(-160 + n * 8, 48, 0))
		var t: int = Time.get_ticks_usec()
		await _move(spot)
		var spent: int = Time.get_ticks_usec() - t
		worst = maxi(worst, spent)
		total += spent
	print("WALK ghost sweep mean_ms=%.1f worst_ms=%.1f (3 frames each)" % [total / 40000.0,
		worst / 1000.0])
	await _shot("ghost_over_wall")
	await _key(KEY_ESCAPE)


func _turns() -> void:
	if _count() == 0:
		await _first_wall()
	var one: BrickWorld.Brick = _model()[0]
	_builder.clear_selection()
	_builder.selection[one.id] = true
	_builder.selection_changed.emit(1)
	await _frames(10)
	_shell.set_turn_step(15)
	await _frames(5)
	for n: int in 3:
		await _key(KEY_R)
	var b: Basis = _world.get_brick(one.id).transform.basis
	print("WALK turn 3xR at 15 deg: yaw=%.1f" % rad_to_deg(b.get_euler().y))
	_shell.run("show_properties")
	await _frames(30)
	await _shot("turned_15_properties")
	_shell.run("mode_rotate")
	await _frames(30)
	await _shot("rotate_tool")
	_shell.run("mode_select")
	_shell.run("mode_move")
	await _frames(30)
	await _shot("move_tool")
	_shell.run("mode_select")
	await _frames(5)


const DIALOGS: Array = ["instructions", "timeline", "share", "together", "settings", "keys",
	"export_3d", "versions", "collection", "minifig", "part_maker", "flex", "stress",
	"parts_list", "panel_outliner", "stability", "brickify", "mosaic", "connector", "tour",
	"library"]


func _dialogs() -> void:
	_main.call("clear_model")
	await _frames(10)
	var opened: int = 0
	if only_dialogs_turn:
		await _free_turn()
		_main.call("clear_model")
		await _frames(10)
	if _count() == 0:
		var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(
			"res://models/car.ldr"))
		var bar: ModelBar = _main.get("_bar")
		await bar.open_text_with_progress(text, "car")
	await _frames(60)
	print("WALK dialogs on %d parts (%s)" % [_count(), opened])
	_main.call("set_assistant", true)
	await _frames(40)
	await _shot("assistant_on")
	for name: String in DIALOGS:
		if _shell.command(name) == null:
			print("WALK dialog %s: no such command" % name)
			continue
		if not _shell.can(name):
			print("WALK dialog %s: greyed" % name)
			continue
		var t: int = Time.get_ticks_msec()
		_shell.run(name)
		await _frames(90)
		print("WALK dialog %s opened, %d ms incl 90 frames" % [name, Time.get_ticks_msec() - t])
		await _shot("dialog_" + name)
		await _close_all()


var only_dialogs_turn: bool = true


## A brick alone on the floor, turned three times at the 15 degree step.
func _free_turn() -> void:
	_main.call("clear_model")
	await _frames(10)
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick_id: int = _world.add_brick("3001", 4, where)
	_builder.register(brick_id, "3001", where)
	_builder.clear_selection()
	_builder.selection[brick_id] = true
	_builder.selection_changed.emit(1)
	_camera.frame(AABB(Vector3(-120, 0, -120), Vector3(240, 80, 240)))
	await _frames(20)
	_shell.set_turn_step(15)
	for n: int in 3:
		await _key(KEY_R)
	var b: Basis = _world.get_brick(brick_id).transform.basis
	print("WALK free turn 3xR at 15 deg: yaw=%.1f" % rad_to_deg(b.get_euler().y))
	await _shot("free_turn_45")
	_shell.run("mode_rotate")
	await _frames(20)
	await _shot("free_rotate_tool")
	_shell.run("mode_select")
	await _frames(5)


func _close_all() -> void:
	# The library and the collection are panels over the model, not windows.
	for panel_name: String in ["library_dialog", "collection"]:
		var panel: Node = _shell.get(panel_name)
		if panel is CanvasItem and (panel as CanvasItem).visible:
			(panel as CanvasItem).hide()
	for window: Window in _windows(root):
		if window != root and window.visible:
			window.hide()
	await _key(KEY_ESCAPE)
	await _frames(10)


func _windows(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		if child is Window:
			out.append(child)
		out.append_array(_windows(child))
	return out


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	_events += 1
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	_events += 1
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
		_events += 1
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out + name + ".png")
	image.save_png(path)
	print("WALK shot %s" % path)
