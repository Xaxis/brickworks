## Temporary review probe. Delete after use.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("window  = %v" % DisplayServer.window_get_size())
	print("visible = %v" % get_root().get_visible_rect().size)
	print("final   = %s" % get_root().get_final_transform())
	print("canvas  = %s" % get_root().get_canvas_transform())
	print("scale2d = %s" % [get_root().get_screen_transform()])

	var camera := CadCamera.new()
	get_root().add_child(camera)
	await process_frame

	# --- 1. does a real dragged pixel move the model a pixel? ---
	camera.focus = Vector3.ZERO
	camera._target_focus = Vector3.ZERO
	camera.distance = 400.0
	camera._target_distance = 400.0
	camera._yaw = 0.0
	camera._target_yaw = 0.0
	camera._pitch = 0.0
	camera._target_pitch = 0.0
	camera._apply(1.0)

	var point := Vector3.ZERO
	var was: Vector2 = camera.unproject_position(point)

	# The window would send: middle down with shift, motion, up.
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.shift_pressed = true
	down.position = get_root().get_visible_rect().size * 0.5
	Input.parse_input_event(down)
	await process_frame

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120.0, 0.0)
	motion.position = down.position + Vector2(120.0, 0.0)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	Input.parse_input_event(motion)
	await process_frame
	await process_frame
	camera._apply(1.0)
	var now: Vector2 = camera.unproject_position(point)
	print("drag 120 device px -> model moved %.1f px (unproject), focus %v"
		% [(now - was).x, camera._target_focus])

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.shift_pressed = true
	up.position = motion.position
	Input.parse_input_event(up)
	await process_frame

	# --- 2. modifier let go before the button ---
	camera._panning = false
	camera._orbiting = false
	var d2 := InputEventMouseButton.new()
	d2.button_index = MOUSE_BUTTON_MIDDLE
	d2.pressed = true
	d2.shift_pressed = true
	camera._unhandled_input(d2)
	print("shift-middle down: panning=%s orbiting=%s"
		% [camera._panning, camera._orbiting])
	var u2 := InputEventMouseButton.new()
	u2.button_index = MOUSE_BUTTON_MIDDLE
	u2.pressed = false
	u2.shift_pressed = false     # shift let go first
	camera._unhandled_input(u2)
	print("middle up, shift already let go: panning=%s orbiting=%s"
		% [camera._panning, camera._orbiting])
	var drift_before: Vector3 = camera._target_focus
	var m2 := InputEventMouseMotion.new()
	m2.relative = Vector2(50.0, 0.0)
	camera._unhandled_input(m2)
	print("  a later mouse move with no button down shifted the view by %.1f LDU"
		% (camera._target_focus - drift_before).length())

	camera._panning = false
	camera._orbiting = false
	var d3 := InputEventMouseButton.new()
	d3.button_index = MOUSE_BUTTON_LEFT
	d3.pressed = true
	d3.alt_pressed = true
	camera._unhandled_input(d3)
	print("alt-left down: orbiting=%s" % camera._orbiting)
	var u3 := InputEventMouseButton.new()
	u3.button_index = MOUSE_BUTTON_LEFT
	u3.pressed = false
	u3.alt_pressed = false       # alt let go first
	camera._unhandled_input(u3)
	print("left up, alt already let go: orbiting=%s" % camera._orbiting)
	var yaw_before: float = camera._target_yaw
	var m3 := InputEventMouseMotion.new()
	m3.relative = Vector2(50.0, 0.0)
	camera._unhandled_input(m3)
	print("  a later mouse move with no button down turned it by %.3f rad"
		% absf(camera._target_yaw - yaw_before))

	# --- 3. two fingers down at once, one lifted ---
	camera._touches.clear()
	var t1 := InputEventScreenTouch.new()
	t1.index = 0
	t1.pressed = true
	t1.position = Vector2(200, 300)
	camera._unhandled_input(t1)
	var t2 := InputEventScreenTouch.new()
	t2.index = 1
	t2.pressed = true
	t2.position = Vector2(400, 300)
	camera._unhandled_input(t2)
	var lift := InputEventScreenTouch.new()
	lift.index = 1
	lift.pressed = false
	lift.position = Vector2(400, 300)
	camera._unhandled_input(lift)
	print("two fingers, one lifted: touches=%d was_tap=%s swallow=%s"
		% [camera._touches.size(), camera.last_touch_was_a_tap(),
			camera.swallowing_click()])
	var lift2 := InputEventScreenTouch.new()
	lift2.index = 0
	lift2.pressed = false
	lift2.position = Vector2(200, 300)
	camera._unhandled_input(lift2)
	print("second finger lifted: was_tap=%s swallow=%s"
		% [camera.last_touch_was_a_tap(), camera.swallowing_click()])

	quit(0)
