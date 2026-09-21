## Do the view controls do anything?
##
##   godot --headless --path . --script src/dev/camera_probe.gd
##
## They did not. The camera listened for a mouse wheel and a middle
## button, and macOS sends two-finger scrolling as a pan gesture and
## pinching as a magnify gesture — so on a laptop trackpad, which is
## what most people are on, nothing turned, nothing slid and nothing
## zoomed. There was no test because there was no test of input at all:
## every probe drove the camera by calling its methods.
##
## So this feeds it the events, the way the window would.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var camera := CadCamera.new()
	get_root().add_child(camera)
	await process_frame

	print("  what a trackpad sends")
	_moves("two fingers slide the view", camera, "focus", func() -> void:
		var swipe := InputEventPanGesture.new()
		swipe.delta = Vector2(6.0, 0.0)
		camera._unhandled_input(swipe))

	_moves("pinching zooms", camera, "distance", func() -> void:
		var pinch := InputEventMagnifyGesture.new()
		pinch.factor = 1.4
		camera._unhandled_input(pinch))

	_moves("alt and two fingers turn it", camera, "yaw", func() -> void:
		var swipe := InputEventPanGesture.new()
		swipe.delta = Vector2(6.0, 0.0)
		swipe.alt_pressed = true
		camera._unhandled_input(swipe))

	print("")
	print("  what a mouse sends")
	_moves("the wheel zooms", camera, "distance", func() -> void:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		camera._unhandled_input(wheel))

	_moves("shift and scroll slides it", camera, "focus", func() -> void:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.shift_pressed = true
		camera._unhandled_input(wheel))

	_moves("middle-drag turns it", camera, "yaw", func() -> void:
		_press(camera, MOUSE_BUTTON_MIDDLE, true)
		_move(camera, Vector2(30.0, 0.0))
		_press(camera, MOUSE_BUTTON_MIDDLE, false))

	_moves("shift-middle-drag slides it", camera, "focus", func() -> void:
		_press(camera, MOUSE_BUTTON_MIDDLE, true, true)
		_move(camera, Vector2(30.0, 0.0))
		_press(camera, MOUSE_BUTTON_MIDDLE, false, true))

	_moves("alt and left-drag turns it", camera, "yaw", func() -> void:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.alt_pressed = true
		camera._unhandled_input(down)
		_move(camera, Vector2(30.0, 0.0))
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.alt_pressed = true
		camera._unhandled_input(up))

	print("")
	print("  a right button that means two things")
	_moves("right-drag turns it", camera, "yaw", func() -> void:
		_press(camera, MOUSE_BUTTON_RIGHT, true)
		_move(camera, Vector2(40.0, 0.0))
		_press(camera, MOUSE_BUTTON_RIGHT, false))
	# And having turned, the release must not also take a brick off.
	_press(camera, MOUSE_BUTTON_RIGHT, true)
	_move(camera, Vector2(40.0, 0.0))
	if camera.swallowing_click():
		print("  ok    ...and the click it raises is thrown away")
	else:
		_failures += 1
		print("  FAIL  a right-drag turn would also remove a brick")
	_press(camera, MOUSE_BUTTON_RIGHT, false)

	# A right click that does not move is still a right click.
	await process_frame
	var before: float = camera._target_yaw
	_press(camera, MOUSE_BUTTON_RIGHT, true)
	_move(camera, Vector2(1.0, 0.0))
	_press(camera, MOUSE_BUTTON_RIGHT, false)
	if is_equal_approx(camera._target_yaw, before):
		print("  ok    a right click that does not move turns nothing")
	else:
		_failures += 1
		print("  FAIL  a right click without a drag turned the model")

	print("")
	_keeps_pace(camera)
	_towards_the_pointer(camera)

	print("")
	if _failures == 0:
		print("the view can be turned, slid and zoomed")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _press(camera: CadCamera, which: int, down: bool,
		shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.shift_pressed = shift
	camera._unhandled_input(event)


func _move(camera: CadCamera, by: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = by
	camera._unhandled_input(event)


## Did the thing that was supposed to move, move?
func _moves(what: String, camera: CadCamera, which: String,
		doing: Callable) -> void:
	var before: Variant = _read(camera, which)
	doing.call()
	var after: Variant = _read(camera, which)
	var changed: bool = (not (before as Vector3).is_equal_approx(after)
		if before is Vector3 else not is_equal_approx(before, after))
	if changed:
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s — %s did not change (%s)" % [what, which, before])


func _read(camera: CadCamera, which: String) -> Variant:
	match which:
		"focus": return camera._target_focus
		"distance": return camera._target_distance
		"yaw": return camera._target_yaw
	return 0.0


## Does zooming keep what is under the pointer under the pointer?
##
## Zooming towards the middle of the screen is what makes a viewport
## feel wrong without anyone being able to say why: you point at the
## corner you want a closer look at, zoom, and it slides off the edge,
## so every zoom costs a pan to put it right.
func _towards_the_pointer(camera: CadCamera) -> void:
	camera.focus = Vector3.ZERO
	camera._target_focus = Vector3.ZERO
	camera.distance = 400.0
	camera._target_distance = 400.0
	camera._yaw = 0.0
	camera._target_yaw = 0.0
	camera._pitch = 0.0
	camera._target_pitch = 0.0
	camera._apply(1.0)

	# A point well off to one side of the middle.
	var at := camera.get_viewport().get_visible_rect().size * Vector2(0.8, 0.5)
	var before: Vector3 = _aim(camera, at)

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = at
	camera._unhandled_input(wheel)
	camera._apply(1.0)

	if camera.distance >= 400.0:
		_failures += 1
		print("  FAIL  the wheel did not move the camera in")
		return
	var after: Vector3 = _aim(camera, at)
	var drift: float = (after - before).length()
	# Within a tenth of a stud of where it was.
	if drift < 2.0:
		print("  ok    zooming keeps what is under the pointer under it")
	else:
		_failures += 1
		print("  FAIL  what was under the pointer moved %.1f LDU away"
			% drift)


## The world point the pointer is aiming at, on the plane the focus is
## in — the same plane the zoom works against.
func _aim(camera: CadCamera, at: Vector2) -> Vector3:
	var forward: Vector3 = (camera.focus - camera.global_position).normalized()
	var origin: Vector3 = camera.project_ray_origin(at)
	var towards: Vector3 = camera.project_ray_normal(at)
	return origin + towards * (
		(camera.focus - origin).dot(forward) / towards.dot(forward))


## Does the model keep pace with the pointer?
##
## Drag a stud a hundred pixels and it should be a hundred pixels
## further along. A pan that outruns the cursor is half of why a
## viewport feels wrong, and this one ran at about one and three
## quarter times the pointer, because the constant was picked by eye
## rather than worked out from the field of view.
func _keeps_pace(camera: CadCamera) -> void:
	camera.focus = Vector3.ZERO
	camera._target_focus = Vector3.ZERO
	camera.distance = 400.0
	camera._target_distance = 400.0
	camera._yaw = 0.0
	camera._target_yaw = 0.0
	camera._pitch = 0.0
	camera._target_pitch = 0.0
	camera._apply(1.0)

	# A point sitting in the focus plane, which is where a model is.
	var point := Vector3(0.0, 0.0, 0.0)
	var was: Vector2 = camera.unproject_position(point)

	var by := Vector2(120.0, -70.0)
	camera._pan_by(by)
	camera._apply(1.0)
	var now: Vector2 = camera.unproject_position(point)

	var moved: Vector2 = now - was
	var off: float = (moved - by).length()
	if off < 2.0:
		print("  ok    sliding moves the model with the pointer, "
			+ "%.0f px for %.0f" % [moved.length(), by.length()])
	else:
		_failures += 1
		print("  FAIL  a %.0f px drag moved the model %.0f px"
			% [by.length(), moved.length()])
