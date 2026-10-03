## Does the corner tell you which way you are looking?
##
##   godot --path . --resolution 1200x800 --script src/dev/gizmo_probe.gd
##
## After a few turns of a model that is roughly symmetrical there is
## nothing on screen to say which side you are looking at. The gizmo is
## also the only obvious way to reach the straight-on views, which were
## on the number keys — and nobody presses 3 to see the left of
## something unless they have been told to.
##
## Two things it has to get right. The dots have to follow the camera,
## or it is decoration. And clicking one has to take you there.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Counted in frames, and a window nothing is looking at gets one a
	# second on this machine. Without this the probe is minutes of
	# waiting for a compositor.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var camera := CadCamera.new()
	get_root().add_child(camera)
	var gizmo := AxisGizmo.new()
	gizmo.camera = camera
	get_root().add_child(gizmo)
	await process_frame

	camera.set_view("front")
	camera._apply(1.0)
	var front: Dictionary = _where(gizmo)

	# Looking at the front, the z axis points at you: it should sit in
	# the middle rather than off to a side, and be the nearest of the
	# six.
	var middle: Vector2 = gizmo.size * 0.5
	if front["front"]["at"].distance_to(middle) < 6.0:
		print("  ok    looking at the front, z points at you")
	else:
		_failures += 1
		print("  FAIL  z is %.0f px off centre from the front"
			% front["front"]["at"].distance_to(middle))
	if float(front["front"]["depth"]) > float(front["back"]["depth"]):
		print("  ok    ...and the far side is behind it")
	else:
		_failures += 1
		print("  FAIL  the far side is not behind the near one")

	# And the right axis is off to the right.
	if front["right"]["at"].x > middle.x + 10.0:
		print("  ok    ...and x is off to the right")
	else:
		_failures += 1
		print("  FAIL  x is at %.0f, middle is %.0f"
			% [front["right"]["at"].x, middle.x])

	# Turn the model; the dots have to move.
	camera.set_view("left")
	camera._apply(1.0)
	var left: Dictionary = _where(gizmo)
	if front["front"]["at"].distance_to(left["front"]["at"]) > 20.0:
		print("  ok    turning the view moves the axes")
	else:
		_failures += 1
		print("  FAIL  the axes did not move when the view did")

	# Clicking a dot goes to that view.
	camera.set_view("default")
	camera._apply(1.0)
	var spots: Dictionary = _where(gizmo)
	for view: String in ["top", "front", "left", "right"]:
		camera.set_view("default")
		camera._apply(1.0)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = spots[view]["at"]
		gizmo._gui_input(press)

		var wanted := CadCamera.new()
		get_root().add_child(wanted)
		wanted.set_view(view)
		var same: bool = (
			is_equal_approx(camera._target_pitch, wanted._target_pitch)
			and is_equal_approx(
				wrapf(camera._target_yaw, -PI, PI),
				wrapf(wanted._target_yaw, -PI, PI)))
		wanted.queue_free()
		if same:
			print("  ok    clicking it goes to the %s" % view)
		else:
			_failures += 1
			print("  FAIL  clicking the %s dot did not go there" % view)

	print("")
	if _failures == 0:
		print("the corner says which way you are looking")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _where(gizmo: AxisGizmo) -> Dictionary:
	var out: Dictionary = {}
	for spoke: Dictionary in gizmo._spokes():
		out[str(spoke["view"])] = spoke
	return out
