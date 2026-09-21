## What happens when somebody does the obvious thing?
##
##   godot --path . --resolution 1400x900 --script src/dev/feel_probe.gd
##
## Every control in this app has been checked by sending the camera the
## events it listens for. That proves the bindings are wired. It does
## not prove the app behaves when somebody does something it is not
## listening for — and the most common such thing, by a distance, was
## holding the left button and dragging, because that is how most 3D
## viewports turn. That placed a brick, once per attempt, with nothing
## to say why. A binding test could never have found it, because there
## was no binding.
##
## So this asks a different question from the rest of the suite: not
## "does each control work" but "does the app do something sensible
## when somebody reaches for what they are used to".
extends SceneTree

var _failures: int = 0
var _world: BrickWorld
var _camera: CadCamera
var _builder: Builder
var _middle: Vector2


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	_world = main.get("_world")
	_camera = main.get("_camera")
	_builder = main.get("_builder")
	var store: ModelStore = main.get("_store")

	# Something to aim at, in the middle of the viewport.
	_world.clear()
	_builder.lattice.clear()
	store.scenery.clear()
	for n: int in 6:
		var at := Transform3D(Basis.IDENTITY, Vector3(n * 40.0, 24.0, 0.0))
		var brick_id: int = _world.add_brick("3001", 4, at)
		_builder.register(brick_id, "3001", at)
	_middle = root.get_visible_rect().size * 0.5
	_builder.held_part = "3005"
	await _settle()

	await _mouse()
	await _keyboard()

	print("")
	if _failures == 0:
		print("the obvious gestures do something sensible")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _mouse() -> void:
	print("  the mouse")

	# The gesture everyone tries first.
	var before: int = _world.brick_count()
	_builder.clear_selection()
	await _drag(MOUSE_BUTTON_LEFT, _middle - Vector2(300.0, 160.0),
		_middle + Vector2(300.0, 160.0))
	_check("a left drag places nothing", _world.brick_count() == before)
	_check("a left drag draws a box that catches bricks",
		_builder.selection.size() > 0)
	_builder.clear_selection()

	before = _world.brick_count()
	await _click(MOUSE_BUTTON_LEFT, _middle)
	_check("a plain click still places", _world.brick_count() > before)

	before = _world.brick_count()
	await _click(MOUSE_BUTTON_RIGHT, _middle)
	_check("a right click takes a brick off", _world.brick_count() < before)

	before = _world.brick_count()
	var yaw: float = _camera._target_yaw
	await _drag(MOUSE_BUTTON_RIGHT, _middle, _middle + Vector2(80.0, 20.0))
	_check("a right drag turns the view",
		not is_equal_approx(_camera._target_yaw, yaw))
	_check("...and takes nothing off", _world.brick_count() == before)

	var focus: Vector3 = _camera._target_focus
	await _drag(MOUSE_BUTTON_MIDDLE, _middle, _middle + Vector2(90.0, 40.0))
	_check("a middle drag slides the view",
		_camera._target_focus.distance_to(focus) > 1.0)

	var distance: float = _camera._target_distance
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	for _n: int in 4:
		await process_frame
	_check("the wheel zooms in", _camera._target_distance < distance)


func _keyboard() -> void:
	print("")
	print("  the keyboard")

	# Back to where the model fills the view.
	#
	# The mouse section has just slid and zoomed, which is the point of
	# it — and leaves the centre of the screen pointing at nothing. A
	# click there places nothing, and the undo test below then reads
	# that as undo being broken. It cost a run to notice, because the
	# failure it printed was about undo.
	await _settle()

	# Undo, which is the one every person tries when something goes
	# wrong — and the thing they try first after discovering a control
	# they did not mean to use.
	var before: int = _world.brick_count()
	await _click(MOUSE_BUTTON_LEFT, _middle)
	var placed: int = _world.brick_count()
	_check("a click placed something to undo", placed > before)
	await _key(KEY_Z, true)
	_check("undo takes the last brick back off",
		_world.brick_count() == before)
	await _key(KEY_Z, true, true)
	_check("redo puts it back", _world.brick_count() == placed)

	_builder.clear_selection()
	await _key(KEY_A, true)
	var all: int = _builder.selection.size()
	_check("select-all selects the model", all > 1)

	await _key(KEY_ESCAPE)
	_check("escape drops the selection", _builder.selection.is_empty())

	await _key(KEY_A, true)
	before = _world.brick_count()
	await _key(KEY_DELETE)
	_check("delete removes the selection", _world.brick_count() < before)
	await _key(KEY_Z, true)

	var distance: float = _camera._target_distance
	_camera._target_distance = distance * 6.0
	await _key(KEY_F)
	_check("f frames the model",
		_camera._target_distance < distance * 6.0)

	var pitch: float = _camera._target_pitch
	await _key(KEY_1)
	_check("1 goes to the front view",
		not is_equal_approx(_camera._target_pitch, pitch)
			or not is_equal_approx(_camera._target_yaw, 0.0))

	var square: bool = _camera.is_square_on()
	await _key(KEY_O)
	_check("o toggles square-on", _camera.is_square_on() != square)
	await _key(KEY_O)


## The model framed and the camera settled there, so that the centre of
## the screen is over it.
func _settle() -> void:
	_camera.frame(_world.model_bounds())
	for _n: int in 40:
		_camera._apply(0.5)
		await process_frame
	_move_to(_middle, Vector2.ZERO, 0)
	for _n: int in 4:
		await process_frame


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s" % what)


## Through Input, not the viewport.
##
## push_input reaches the handlers but leaves the Input singleton
## untouched, and the camera asks that singleton whether a button is
## still down — a guard against a release that never arrives. Driven by
## push_input, that guard fires immediately and every drag ends before
## it begins, which reads as the app ignoring the drag. It was the
## harness, not the app, and it took a print inside the camera to tell
## them apart.
func _press(which: int, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)


func _wheel(which: int) -> void:
	_press(which, _middle, true)
	_press(which, _middle, false)


func _move_to(at: Vector2, by: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = by
	event.button_mask = mask
	Input.parse_input_event(event)


func _key(code: Key, command: bool = false,
		shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.meta_pressed = command
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	for _n: int in 4:
		await process_frame


func _click(which: int, at: Vector2) -> void:
	_move_to(at, Vector2.ZERO, 0)
	await process_frame
	_press(which, at, true)
	await process_frame
	_press(which, at, false)
	for _n: int in 4:
		await process_frame


func _drag(which: int, from: Vector2, to: Vector2) -> void:
	var mask: int = MOUSE_BUTTON_MASK_LEFT
	if which == MOUSE_BUTTON_RIGHT:
		mask = MOUSE_BUTTON_MASK_RIGHT
	elif which == MOUSE_BUTTON_MIDDLE:
		mask = MOUSE_BUTTON_MASK_MIDDLE
	_move_to(from, Vector2.ZERO, 0)
	await process_frame
	_press(which, from, true)
	await process_frame
	for n: int in range(1, 9):
		var at: Vector2 = from.lerp(to, float(n) / 8.0)
		_move_to(at, (to - from) / 8.0, mask)
		await process_frame
	_press(which, to, false)
	for _n: int in 6:
		await process_frame
