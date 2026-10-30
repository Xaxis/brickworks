## Build your first model (docs/APP_UX.md A12), done as a person does it:
## every act a click or a key sent to the window, every check what the app
## did to the model, the view or the store.
##
##   tools/probe.sh first_build_probe
##   godot --path . --resolution 1280x720 --script src/dev/first_build_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh first_build_probe
##
## - A first visit is offered it along the top of the model, by itself, with
##   nothing changed: the example car is still there, and nothing is over the
##   model. One click on Skip ends it.
## - The app started again, in a run of its own on the same data folder: it
##   is not offered again.
## - Help, Take the tour brings it back, and keys and clicks take it to its end
##   in 25 acts or fewer: Start (a baseplate of its own, the car taken off), a
##   part from the bin put down, one turned with the keymap's key in hand and
##   put down, one put down in a colour from the palette, one selected and
##   moved with the keymap's key, copied with its key and put down, the view
##   turned with a right drag, saved with its key, and Done. A step moves on
##   only when its act is done: a part put down unturned, the part in hand
##   turned but not put down, and the wheel's zoom each leave it where it is.
## - Any way of doing a step counts: again from Help, on a model of the
##   person's own, which File, New keeps: turned where it stands by its key,
##   painted by a colour clicked with it selected, dragged somewhere else,
##   copied and pasted from the Edit menu, the view from the front by its
##   key, and saved from the File menu.
##
## The data folder is the run's own (probe.sh gives one), where the app keeps
## what it was told; a run with no folder of its own says so and fails.
## Pictures go to shots/first_build/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/first_build/"
const MOST_ACTS := 25

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _bin: PartsBin
var _first: FirstBuild
var _out: String = ""
var _acts: int = 0
## Where the pointer is, in the window's pixels, for each move's relative.
var _pointer: Vector2 = Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var after_restart: bool = OS.get_cmdline_user_args().has("--after-restart")
	var own_folder: bool = _own_data_folder()
	# Kept as the app keeps it, in this run's own folder only.
	ShellPrefs.kept_by_a_check = own_folder
	# A person in front of the window, as a first visit has one.
	FirstBuild.offered_for_probe = true
	if not after_restart and DisplayServer.get_name() == "headless":
		print("  first build probe: needs a window")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var size: Vector2i = DisplayServer.window_get_size()
	_out = "%s%dx%d/" % [SHOTS, size.x, size.y]
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  first build probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_bin = _main.get("_bin")
	_first = _shell.first_build
	var library: PartLibrary = _main.get("_library")
	for _n: int in 600:
		if library.search_ready():
			break
		await process_frame
	if after_restart:
		await _after_restart()
	else:
		print("  a %d x %d window" % [size.x, size.y])
		await _offered()
		await _restart(own_folder)
		await _walk()
		await _other_ways()
	print("")
	if _failures == 0:
		print("first build probe: all checks passed")
	else:
		print("first build probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## Whether user:// is this run's own (probe.sh's XDG_DATA_HOME), never the
## person's.
func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


# -- a first visit -----------------------------------------------------------------

func _offered() -> void:
	print("\n  a first visit")
	var parts: int = _parts()
	var title: String = _store.title
	for _n: int in 1200:
		if _first.step_name() == "offer":
			break
		await process_frame
	await _frames(10)
	_check("Build your first model is offered by itself (%s)" % _first.step_name(),
		_first.step_name() == "offer")
	_check("...with nothing changed: the example car's %d parts, \"%s\"" % [_parts(), _store.title],
		_parts() == parts and parts > 0 and _store.title == title)
	_line_above_the_model()
	await _shot("1_offered")
	await _click(_button("first_build_skip"))
	_check("one click on Skip ends it (%s)" % _first.step_name(), not _first.is_running())
	_check("...and it is kept that it was (%s)" % ShellPrefs.value("first_build"),
		ShellPrefs.value("first_build") == "skipped")
	_check("...the car as it was, %d parts" % _parts(), _parts() == parts)


## Its line along the top of the model, and nothing of it over the model
## a click would land on instead (fit_check.mjs asks the same of the page).
func _line_above_the_model() -> void:
	var line: Rect2 = _first.get_global_rect()
	var model: Rect2 = (_main.get("_over_model") as Control).get_global_rect()
	var covered: Array = (_main.call("model_cover") as Dictionary)["covered"]
	_check("...its line along the top of the model, not over it (%s over %s, %d points covered)"
		% [line, model, covered.size()],
		_first.is_visible_in_tree() and line.end.y <= model.position.y + 1.0 and covered.is_empty())


func _restart(own_folder: bool) -> void:
	print("\n  the app started again")
	if not own_folder:
		_check("a data folder of this run's own to keep it in (run by tools/probe.sh)", false)
		return
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/first_build_probe.gd",
		"--", "--after-restart"], output, true)
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("  ok") or line.begins_with("  FAIL"):
			print("  " + line)
	_check("a run of its own, on the same data folder, passed (exit %d)" % code, code == 0)


func _after_restart() -> void:
	# Long enough for it to have decided: it waits for the account's answer
	# at most FirstBuild.LOOK_WAIT_MS.
	var until: int = Time.get_ticks_msec() + FirstBuild.LOOK_WAIT_MS + 3000
	while Time.get_ticks_msec() < until and not bool(_first.get("_decided")):
		await process_frame
	await _frames(30)
	_check("it has decided, kept as \"%s\"" % ShellPrefs.value("first_build"),
		bool(_first.get("_decided")) and ShellPrefs.value("first_build") == "skipped")
	_check("...and is not offered again (%s)" % _first.step_name(), not _first.is_running())


# -- Help, Take the tour, to its end ---------------------------------------------------

func _walk() -> void:
	print("\n  from Help, to its end")
	_acts = 0
	await _from_menu("Help", "tour")
	_check("Help, Take the tour offers it again (%s)" % _first.step_name(),
		_first.step_name() == "offer")
	await _click(_button("first_build_go"))
	_check("Start: the car taken off for a baseplate of its own (%d parts), \"%s\""
		% [_parts(), _store.title], _parts() == 0 and _store.title == FirstBuild.MODEL_NAME)
	_check("...the first step, Put a part down, framing the bin's parts", _step_is("put")
		and _lit().encloses((_bin.controls_by_name()["parts list"] as Control).get_global_rect()))
	await _shot("2_put")

	# A part from the bin, put down.
	await _click(_tile("3001"))
	_check("a part chosen in the bin is in hand (%s)" % _builder.held_part,
		_builder.held_part == "3001" and _step_is("put"))
	await _click(_on_baseplate(Vector3(0, 0, 0)))
	_check("put down: %d part, and it moves on" % _parts(), _parts() == 1 and _step_is("turn"))
	_check("...framing the Rotate tool, and naming %s" % Keymap.written("rotate_held"),
		_lit().encloses(_tool("tool_mode_rotate").get_global_rect())
		and _said().contains(Keymap.written("rotate_held")))

	# Turned: not by a part put down as it was, nor by a turn in hand alone.
	await _click(_on_baseplate(Vector3(-100, 0, 60)))
	_check("another put down unturned (%d parts): it stays on Turn it" % _parts(),
		_parts() == 2 and _step_is("turn"))
	await _key_of("rotate_held")
	_check("the part in hand turned with %s, not yet put down: it stays"
		% Keymap.written("rotate_held"), _step_is("turn"))
	await _click(_on_baseplate(Vector3(100, 0, 60)))
	_check("put down turned (%d parts): it moves on to Colour it" % _parts(),
		_parts() == 3 and _step_is("colour"))
	await _shot("3_colour")

	# Coloured.
	var colour: int = _a_colour()
	await _click(_swatch(colour))
	_check("a colour clicked in the palette is in hand (%d)" % _builder.held_color,
		_builder.held_color == colour and _step_is("colour"))
	await _click(_on_baseplate(Vector3(-100, 0, -60)))
	_check("put down in it (%d parts): it moves on to Move it" % _parts(),
		_parts() == 4 and _step_is("move"))

	# Selected and moved.
	await _key(KEY_ESCAPE)
	var first_id: int = _id_at(Vector3(0, 0, 0))
	await _click(_screen_of(first_id))
	_check("Esc lets go of the part, and a click selects the first one",
		_builder.selection.has(first_id) and _builder.selection.size() == 1 and _step_is("move"))
	var was: Vector3 = _world.get_brick(first_id).transform.origin
	await _key_of("nudge_right")
	_check("%s moves it (%s to %s): it moves on to Copy it" % [Keymap.written("nudge_right"),
		was, _world.get_brick(first_id).transform.origin],
		not _world.get_brick(first_id).transform.origin.is_equal_approx(was) and _step_is("copy"))

	# Copied.
	await _key_of("duplicate")
	_check("%s holds a copy of it" % Keymap.written("duplicate"),
		_builder.is_carrying() and _step_is("copy"))
	await _click(_on_baseplate(Vector3(100, 0, -60)))
	_check("put down (%d parts): it moves on to Turn the view, framing the view cube" % _parts(),
		_parts() == 5 and _step_is("view")
		and _lit().encloses((_main.get("_gizmo") as Control).get_global_rect()))
	await _shot("4_view")

	# The view turned: zooming is not turning it.
	await _wheel(_model_middle(), MOUSE_BUTTON_WHEEL_UP)
	_check("the wheel zooms the view: it stays on Turn the view", _step_is("view"))
	var yaw: float = _camera.yaw_turned()
	await _right_drag(_model_middle(), _model_middle() + Vector2(160, 0))
	_check("a right drag turns it (%.0f° to %.0f°): it moves on to Save it" % [rad_to_deg(yaw),
		rad_to_deg(_camera.yaw_turned())], _step_is("save"))

	# Saved.
	_check("...naming %s and the model's name" % Keymap.written("save"),
		_said().contains(Keymap.written("save"))
		and _said().contains(FirstBuild.MODEL_NAME))
	await _key_of("save")
	_check("%s saves it as \"%s\": the end" % [Keymap.written("save"), FirstBuild.MODEL_NAME],
		_saved(FirstBuild.MODEL_NAME) and _step_is("end"))
	await _shot("5_end")
	await _click(_button("first_build_go"))
	_check("Done ends it, kept as done (%s)" % ShellPrefs.value("first_build"),
		not _first.is_running() and ShellPrefs.value("first_build") == "done")
	_check("to its end in %d acts, at most %d" % [_acts, MOST_ACTS], _acts <= MOST_ACTS)


# -- any way of doing a step ---------------------------------------------------------

func _other_ways() -> void:
	print("\n  again, each step another way, on a model of the person's own")
	_shell.run("tour")
	await _frames(5)
	await _click(_button("first_build_go"))
	_check("Start, over \"%s\" saved as it is: File, New, and its first step (%s, %d parts)"
		% [FirstBuild.MODEL_NAME, _first.step_name(), _parts()],
		_step_is("put") and _parts() == 0 and _saved(FirstBuild.MODEL_NAME))
	_check("...a new model of its own name (\"%s\")" % _store.title,
		_store.title.begins_with(FirstBuild.MODEL_NAME) and _store.title != FirstBuild.MODEL_NAME)
	await _click(_tile("3001"))
	await _click(_on_baseplate(Vector3(0, 0, 0)))
	_check("a part put down: Turn it", _parts() == 1 and _step_is("turn"))

	# Turned where it stands, selected.
	await _key(KEY_ESCAPE)
	var id: int = _id_at(Vector3(0, 0, 0))
	await _click(_screen_of(id))
	var basis: Basis = _world.get_brick(id).transform.basis
	await _key_of("rotate_held")
	_check("selected and turned where it stands by %s: Colour it" % Keymap.written("rotate_held"),
		not _world.get_brick(id).transform.basis.is_equal_approx(basis) and _step_is("colour"))

	# Painted by a colour clicked with it selected.
	var colour: int = _a_colour()
	await _click(_swatch(colour))
	_check("a colour clicked with it selected paints it (%d): Move it"
		% _world.get_brick(id).color_code,
		_world.get_brick(id).color_code == colour and _step_is("move"))

	# Dragged somewhere else.
	var from: Vector2 = _screen_of(id)
	await _left_drag(from, _on_baseplate(Vector3(-120, 0, -80)))
	_check("dragged somewhere else (%d parts): Copy it" % _parts(),
		_parts() == 1 and _step_is("copy"))

	# Copied and pasted from the Edit menu.
	var moved: int = _id_at(Vector3(-120, 0, -80))
	if not _builder.selection.has(moved):
		await _click(_screen_of(moved))
	await _from_menu("Edit", "copy")
	await _from_menu("Edit", "paste")
	await _click(_on_baseplate(Vector3(100, 0, 80)))
	_check("Edit, Copy and Paste, put down (%d parts): Turn the view" % _parts(),
		_parts() == 2 and _step_is("view"))

	# The view from the front, by its key.
	await _key_of("view_front")
	for _n: int in 30:
		await process_frame
	_check("%s, the view from the front: Save it" % Keymap.written("view_front"), _step_is("save"))

	# Saved from the File menu.
	var name: String = _store.title
	await _from_menu("File", "save")
	for _n: int in 60:
		if _step_is("end"):
			break
		await process_frame
	_check("File, Save saves \"%s\": the end" % name, _saved(name) and _step_is("end"))
	_check("...and the first one is kept as it was (%s)" % FirstBuild.MODEL_NAME,
		_saved(FirstBuild.MODEL_NAME))
	await _click(_button("first_build_go"))
	_check("Done ends it", not _first.is_running())


# -- reading the window ------------------------------------------------------------

## What its line says now.
func _said() -> String:
	return (_first.get("_words") as Label).text


func _step_is(step: String) -> bool:
	return _first.step_name() == step


func _parts() -> int:
	return _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(brick.id)).size()


func _saved(name: String) -> bool:
	for entry: ModelStore.Entry in _store.list_saved():
		if entry.name == name:
			return true
	return false


## The frame round what the step points at, in the window's units.
func _lit() -> Rect2:
	return (_first.get("_frame") as Control).get("lit")


func _button(name: String) -> Vector2:
	var found: Dictionary = _first.controls_by_name()
	if not found.has(name):
		_check("%s is shown" % name, false)
		return Vector2.ZERO
	return (found[name] as Control).get_global_rect().get_center()


func _tool(name: String) -> Control:
	return _shell.toolbar.controls_by_name()[name]


## The bin's tile for [param part], in sight.
func _tile(part: String) -> Vector2:
	var scroll: Control = _bin.controls_by_name()["parts list"]
	var tiles: Array[Node] = _bin.find_children("*", "Button", true, false)
	for tile: Node in tiles:
		var button := tile as Button
		if str(button.get_meta("part", "")) == part and button.is_visible_in_tree() \
				and scroll.get_global_rect().encloses(button.get_global_rect()):
			return button.get_global_rect().get_center()
	_check("the bin shows %s" % part, false)
	return Vector2.ZERO


func _swatch(code: int) -> Vector2:
	var swatches: Dictionary = _bin.get("_swatches")
	var swatch: Control = swatches.get(code)
	var palette: Control = _bin.controls_by_name()["palette"]
	if swatch == null or not swatch.is_visible_in_tree() \
			or not palette.get_global_rect().encloses(swatch.get_global_rect()):
		_check("the palette shows colour %d" % code, false)
		return Vector2.ZERO
	return swatch.get_global_rect().get_center()


## A colour in sight in the palette that is neither in hand nor in the model.
func _a_colour() -> int:
	var used: Array[int] = [_builder.held_color]
	for brick: BrickWorld.Brick in _world.bricks():
		used.append(brick.color_code)
	var swatches: Dictionary = _bin.get("_swatches")
	var palette: Rect2 = (_bin.controls_by_name()["palette"] as Control).get_global_rect()
	for code: int in swatches:
		var swatch: Control = swatches[code]
		if not used.has(code) and swatch.is_visible_in_tree() \
				and palette.encloses(swatch.get_global_rect()):
			return code
	_check("the palette shows a colour the model has not", false)
	return -1


func _on_baseplate(at: Vector3) -> Vector2:
	return _camera.unproject_position(at)


func _screen_of(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	return _camera.unproject_position(brick.transform.origin) if brick != null else Vector2.ZERO


## The part put down nearest [param at].
func _id_at(at: Vector3) -> int:
	var best: int = 0
	var near: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var far: float = brick.transform.origin.distance_to(at + Vector3(0, 24, 0))
		if far < near:
			near = far
			best = brick.id
	return best


func _model_middle() -> Vector2:
	return (_main.call("_model_rect") as Rect2).get_center()


# -- acts ----------------------------------------------------------------------------

func _as_event(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


func _move(at: Vector2, mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.relative = motion.position - _pointer
	_pointer = motion.position
	motion.button_mask = mask
	Input.parse_input_event(motion)
	await _frames(3)


func _press(button: MouseButton, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	_acts += 1
	await _move(at)
	_press(MOUSE_BUTTON_LEFT, at, true)
	await _frames(2)
	_press(MOUSE_BUTTON_LEFT, at, false)
	await _frames(8)


func _wheel(at: Vector2, which: MouseButton) -> void:
	_acts += 1
	await _move(at)
	_press(which, at, true)
	_press(which, at, false)
	await _frames(20)


func _right_drag(from: Vector2, to: Vector2) -> void:
	await _drag(MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MASK_RIGHT, from, to)


func _left_drag(from: Vector2, to: Vector2) -> void:
	await _drag(MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MASK_LEFT, from, to)


func _drag(button: MouseButton, mask: int, from: Vector2, to: Vector2) -> void:
	_acts += 1
	await _move(from)
	_press(button, from, true)
	await _frames(2)
	for n: int in range(1, 9):
		await _move(from.lerp(to, n / 8.0), mask)
	_press(button, to, false)
	await _frames(30)


func _key(code: Key) -> void:
	await _keys(Keymap.press_of(code))


## The key the person's keymap gives [param action], pressed.
func _key_of(action: String) -> void:
	var accel: int = Keymap.key_of(action)
	_check("%s has a key" % action, accel != 0)
	await _keys(Keymap.press_of(accel))


func _keys(down: InputEventKey) -> void:
	_acts += 1
	Input.parse_input_event(down)
	await process_frame
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(10)


## A command from a menu on the bar, opened with a click and its row chosen:
## two acts.
func _from_menu(title: String, command: String) -> void:
	var menu: MenuButton = _shell.menu(title)
	await _click(menu.get_global_rect().get_center())
	var popup: PopupMenu = menu.get_popup()
	var at: int = _shell.menu_id(command)
	_check("%s opens, with %s in it" % [title, command],
		popup.visible and popup.get_item_index(at) >= 0)
	_acts += 1
	popup.id_pressed.emit(at)
	popup.hide()
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out + name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s%s.png" % [_out.trim_prefix("res://"), name])
