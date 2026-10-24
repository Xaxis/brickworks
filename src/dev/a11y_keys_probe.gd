## Building without the mouse: from launch, F6 (Tab, with a screen reader
## running), Tab and the arrows reach the toolbar, the bin's parts, a colour
## and the view cube's buttons, and a part is taken from the bin and put
## down on the model with keys alone.
##
##   godot --path . --resolution 1400x900 --script src/dev/a11y_keys_probe.gd
##
## Every press is a key event sent to the real scene, as a keyboard sends
## it; nothing is clicked and nothing is called on the app to move the
## focus. The app's own key handler stands aside while the keys are on a
## control, so the arrows walking the toolbar must leave the view still.
## And a click on a tile after all that must leave the keys with the model,
## as it always has (the CAD task test, 2026-10-16).
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _camera: CadCamera
var _store: ModelStore


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
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_store.keeps = false
	_main.call("clear_model")
	await _frames(20)

	_check("from launch nothing has the keys", _focused() == null)

	# F6 goes into the interface (Tab does with a screen reader running; here
	# Tab is the app's own, the panels folded), and Tab along it to the
	# toolbar.
	await _key(KEY_F6)
	var first: Control = _focused()
	_check("F6 from the model goes into the interface (%s)" % _said(first), first != null)
	if first is LineEdit:
		# A field gives the keys back to the model on Tab, as the owner asked
		# (FocusGuard), and the next F6 goes on from it.
		await _key(KEY_TAB)
		_check("Tab from a field gives the keys back to the model", _focused() == null)
		await _key(KEY_F6)
		var after: Control = _focused()
		_check("...and F6 goes on past it (%s)" % _said(after),
			after != null and after != first)
	var tool: Control = await _tab_until(func(c: Control) -> bool:
		return _shell.toolbar.is_ancestor_of(c), 80)
	_check("Tab reaches the toolbar (%s)" % _said(tool), tool != null)
	if tool == null:
		_finish()
		return
	_check("...whose button says its words and its key (%s)" % tool.accessibility_name,
		tool.accessibility_name.contains(", Ctrl+") or tool.accessibility_name.contains(", "))
	var facing: Transform3D = _camera.global_transform
	await _key(KEY_RIGHT)
	await _frames(20)
	var next_tool: Control = _focused()
	_check("Right walks the toolbar (%s to %s)" % [_said(tool), _said(next_tool)],
		next_tool != null and next_tool != tool and _shell.toolbar.is_ancestor_of(next_tool))
	_check("...and the view stays still while it does",
		_camera.global_transform.is_equal_approx(facing))
	# A tool chosen from the keyboard: Select, by Return on it.
	var select: Control = await _tab_until(func(c: Control) -> bool:
		return c.accessibility_name == "Select, V", 40)
	_check("Tab reaches Select, V", select != null)

	# On to the parts: past the bin's buttons, its search and its tabs.
	var tile: Button = await _tab_until(func(c: Control) -> bool:
		return c is Button and c.has_meta("part") and _bin.is_ancestor_of(c), 200)
	_check("Tab reaches a part in the bin (%s)" % _said(tile), tile != null)
	if tile == null:
		_finish()
		return
	await _key(KEY_DOWN)
	var below: Control = _focused()
	_check("Down walks the grid to the part below (%s)" % _said(below),
		below != null and below != tile and below.has_meta("part")
		and below.global_position.y > tile.global_position.y)
	await _key(KEY_RIGHT)
	var part_tile: Button = _focused() as Button
	_check("Right to the part beside it (%s)" % _said(part_tile),
		part_tile != null and part_tile.has_meta("part") and part_tile != below)
	if part_tile == null or not part_tile.has_meta("part"):
		_finish()
		return
	var part: String = str(part_tile.get_meta("part"))

	# Return takes it into hand, and the keys go to the model.
	var count: int = _count()
	await _key(KEY_ENTER)
	await _wait_for(func() -> bool: return _builder.has_preview(), 240)
	_check("Return takes %s into hand (%s)" % [part, _builder.held_part],
		_builder.held_part == part)
	_check("...and gives the keys to the model", _focused() == null)
	_check("...its ghost on the model, at the middle of the view", _builder.has_preview())
	var aimed: Variant = _builder.ghost_place()
	# The view's keys move what it is aimed at: D slides the view right.
	await _key(KEY_D)
	await _frames(30)
	var moved: Variant = _builder.ghost_place()
	_check("D slides the view, and the ghost with its middle (%s to %s)" % [aimed, moved],
		aimed != null and moved != null and aimed != moved)
	await _key(KEY_ENTER)
	await _frames(6)
	_check("Return puts it down: %d parts, then %d" % [count, _count()], _count() == count + 1)
	var placed: BrickWorld.Brick = _last_brick()
	_check("...the part it was, where its ghost was",
		placed != null and placed.part_id == part)

	# A colour, from the keyboard: F6 back in, Tab on to the palette.
	await _key(KEY_F6)
	var swatch: Button = await _tab_until(func(c: Control) -> bool:
		return c is PartsBin.Swatch, 400)
	_check("Tab reaches a colour (%s)" % _said(swatch), swatch != null)
	if swatch != null:
		await _key(KEY_RIGHT)
		var other: PartsBin.Swatch = _focused() as PartsBin.Swatch
		_check("Right to the colour beside it (%s)" % _said(other), other != null)
		if other != null:
			await _key(KEY_ENTER)
			_check("Return chooses %s (%d in hand)" % [other.color.name, _builder.held_color],
				_bin.selected_color() == other.color.code)

	# The view cube's buttons: a turn from the keyboard.
	var turn: Control = await _tab_until(func(c: Control) -> bool:
		return c.accessibility_name == "Turn the view left", 400)
	_check("Tab reaches the view cube's Turn the view left", turn != null)
	if turn != null:
		var before: Basis = _camera.global_transform.basis
		await _key(KEY_ENTER)
		await _frames(40)
		_check("Return on it turns the view",
			not _camera.global_transform.basis.is_equal_approx(before))
		var fit: Control = await _tab_until(func(c: Control) -> bool:
			return c.accessibility_name == "Fit, F", 10)
		_check("...and Tab goes on to Fit, F", fit != null)

	# A click still leaves the keys with the model.
	await _key(KEY_ESCAPE)
	await _frames(4)
	var some_tile: Button = _first_tile()
	if some_tile != null:
		await _click(some_tile.get_global_rect().get_center())
		_check("a click on a part takes it and leaves the keys with the model (%s)"
			% _said(_focused()), _focused() == null)
	_finish()


## Tab, until the focus is on a control [param wanted] says yes to, or
## [param most] presses have found none.
func _tab_until(wanted: Callable, most: int) -> Control:
	for _n: int in most:
		var on: Control = _focused()
		if on != null and bool(wanted.call(on)):
			return on
		await _key(KEY_TAB)
	var last: Control = _focused()
	return last if last != null and bool(wanted.call(last)) else null


func _focused() -> Control:
	return root.gui_get_focus_owner()


func _said(control: Control) -> String:
	if control == null:
		return "nothing"
	var name: String = control.accessibility_name
	if name.is_empty() and control is Button:
		name = (control as Button).text
	return "%s \"%s\"" % [control.get_class(), name]


func _first_tile() -> Button:
	for child: Node in _bin._grid.get_children():
		if child is Button and child.has_meta("part"):
			return child
	return null


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _last_brick() -> BrickWorld.Brick:
	var last: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if last == null or brick.id > last.id:
			last = brick
	return last


func _wait_for(done: Callable, most: int) -> void:
	for _n: int in most:
		if bool(done.call()):
			return
		await process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(4)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("a11y keys probe: all checks passed")
	else:
		print("a11y keys probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
