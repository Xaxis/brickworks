## Press every key the on-screen hint advertises, and check it did
## something.
##
##   godot --headless --path . --script src/dev/controls_probe.gd
##
## The hint along the bottom is a promise. A key listed there that does
## nothing is worse than no hint at all, because the person concludes the
## app is broken rather than that they misread it — which is exactly the
## complaint this exists to stop coming back.
##
## So the bindings are not read from the handler; they are read from
## [ControlsHint], the same table the strip is drawn from, and each one
## is pressed for real against a running scene. A key added to the hint
## and forgotten in the handler fails here.
extends SceneTree

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	# The library and the starting model load over several frames.
	for _n: int in 90:
		await process_frame

	var world: BrickWorld = _main.get("_world")
	var builder: Builder = _main.get("_builder")
	var camera: Node3D = _main.get("_camera")
	if world == null or builder == null:
		print("scene did not come up")
		quit(1)
		return

	# Something to rotate and orbit around. A probe on an empty scene
	# would pass every check by doing nothing to nothing.
	if world.brick_count() == 0:
		var at := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
		var id: int = world.add_brick("3001", 4, at)
		builder.register(id, "3001", at)
		await process_frame

	_check("R turns the held part",
		func() -> Variant: return builder.held_rotation, KEY_R)
	_check("] changes the colour",
		func() -> Variant: return builder.held_color, KEY_BRACKETRIGHT)
	_check("[ changes it back",
		func() -> Variant: return builder.held_color, KEY_BRACKETLEFT)
	_check("E turns the whole model",
		func() -> Variant: return _model_signature(world), KEY_E)
	_check("Q turns it the other way",
		func() -> Variant: return _model_signature(world), KEY_Q)
	# Pushed off the model first. F on an already-framed scene correctly
	# does nothing, so checking that the transform changed would fail a
	# working key — the question is whether F brings the camera back,
	# not whether it moves it.
	var framed: Transform3D = camera.global_transform
	camera.global_position += Vector3(4000, 2000, 4000)
	await process_frame
	_press(KEY_F)
	for _n: int in 40:
		await process_frame
	_assert("F brings the camera back to the model, off by %.0f" %
		camera.global_position.distance_to(framed.origin),
		camera.global_position.distance_to(framed.origin) < 50.0)

	var bin_dock: SideDock = _main.get("_bin_dock")
	var chat_dock: SideDock = _main.get("_chat_dock")
	var was_open: bool = bin_dock.is_open()
	_press(KEY_TAB)
	await process_frame
	_assert("Tab folds both panels away",
		bin_dock.is_open() != was_open and chat_dock.is_open() != was_open)
	_press(KEY_TAB)
	await process_frame
	_assert("Tab brings them back", bin_dock.is_open() == was_open)

	# The search box has to end up with the caret in it, or "/" is a key
	# that appears to do nothing at all.
	_press(KEY_SLASH)
	await process_frame
	var focused: Control = root.gui_get_focus_owner()
	_assert("/ puts the caret in the search box, got %s" % [focused],
		focused is LineEdit)
	if focused != null:
		focused.release_focus()

	var steps: StepsBar = _main.get("_steps")
	_press(KEY_B)
	for _n: int in 20:
		await process_frame
	_assert("B opens the build steps", steps.is_playing_back())

	# Only worth checking when there is more than one step to move
	# between, which the starting model has.
	var world_before: int = _drawn(world)
	_press(KEY_RIGHT)
	await process_frame
	_assert("right arrow adds the next step's bricks, %d -> %d"
		% [world_before, _drawn(world)], _drawn(world) > world_before)
	_press(KEY_LEFT)
	await process_frame
	_assert("left arrow takes them back off", _drawn(world) == world_before)

	_press(KEY_ESCAPE)
	await process_frame
	_assert("escape leaves the steps rather than quitting",
		not steps.is_playing_back())
	_assert("...and puts the whole model back", _drawn(world) == world.brick_count())

	# Undo is the one that has to be checked by doing, not by pressing:
	# it needs something to undo first.
	var before: int = world.brick_count()
	var placed := Transform3D(Basis.IDENTITY, Vector3(200, 24, 200))
	var new_id: int = world.add_brick("3001", 4, placed)
	builder.register(new_id, "3001", placed)
	builder._history.append({"undo": "remove", "brick": new_id})
	await process_frame
	_press(KEY_Z, true)
	await process_frame
	_assert("Cmd-Z takes a brick back off, %d -> %d" % [before + 1, world.brick_count()],
		world.brick_count() == before)

	print("")
	print("%d failed" % _failures if _failures else "every advertised key does something")
	quit(1 if _failures else 0)


## How many bricks are actually on screen, which is not the same as how
## many exist while a booklet is up.
func _drawn(world: BrickWorld) -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if not brick.hidden:
			n += 1
	return n


## A number that changes whenever any brick moves, so a rotation can be
## detected without knowing where it should have ended up.
func _model_signature(world: BrickWorld) -> float:
	var total: float = 0.0
	for brick: BrickWorld.Brick in world.bricks():
		var at: Vector3 = brick.transform.origin
		total += at.x * 7.0 + at.y * 13.0 + at.z * 29.0
	return total


func _check(what: String, reading: Callable, key: int) -> void:
	var before: Variant = reading.call()
	_press(key)
	_assert(what, reading.call() != before)


func _assert(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## Delivered the way the window delivers one, so it travels the same path
## a real press does — including past the "is someone typing?" guard that
## a direct call to the handler would skip.
func _press(keycode: int, command: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.meta_pressed = command
	root.push_input(event)
