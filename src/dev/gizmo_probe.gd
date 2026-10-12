## Does the cube in the corner say which way you are looking, and take you
## anywhere with a left click?
##
##   godot --path . --resolution 1200x800 --script src/dev/gizmo_probe.gd
##
## The view cube (ViewCube) turns with the view; a click on a face looks
## from that side, on an edge from between two, on a corner from between
## three; a drag on it turns the view. Its arrows turn the view a step a
## click, and its pad and buttons slide, zoom and fit — so a mouse with one
## button, or a trackpad, gets everywhere.
extends SceneTree

var _failures: int = 0


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
	var camera := CadCamera.new()
	get_root().add_child(camera)
	var cube := ViewCube.new()
	cube.camera = camera
	var fitted: Array = [0]
	cube.fit = func() -> void: fitted[0] += 1
	get_root().add_child(cube)
	await process_frame

	camera.set_view("front")
	camera._apply(1.0)
	var middle := Vector2(ViewCube.cube_size(), ViewCube.cube_size()) * 0.5
	var front: Vector2 = cube._to_screen(Vector3(0, 0, 1))
	_check("looking at the front, the front face is in the middle (%s)" % front,
		front.distance_to(middle) < 3.0)
	_check("...and the right face is off to the right",
		cube._to_screen(Vector3(1, 0, 0)).x > middle.x + 10.0)
	camera.set_view("left")
	camera._apply(1.0)
	_check("turning the view turns the cube",
		cube._to_screen(Vector3(0, 0, 1)).distance_to(front) > 15.0)

	# A face, an edge and a corner, each clicked from the usual view — on the
	# side of the cube the usual view shows.
	camera.set_view("default")
	camera._apply(1.0)
	var side: float = 1.0 if cube._seen(Vector3(1, 0, 0)).z > 0.3 else -1.0
	var named: String = "right" if side > 0.0 else "left"
	for case: Array in [["the top face", Vector3(0, 1, 0)], ["the front face", Vector3(0, 0, 1)],
			["the %s face" % named, Vector3(side, 0, 0)],
			["the front-%s edge" % named, Vector3(side, 0, 1)],
			["the top-front-%s corner" % named, Vector3(side, 1, 1)]]:
		camera.set_view("default")
		camera._apply(1.0)
		var aim: Vector3 = case[1]
		var at: Vector2 = cube._to_screen(aim * 0.82 if aim.length() > 1.1 else aim)
		_click(cube, at)
		camera._apply(1.0)
		var looking: Vector3 = (camera.global_position - camera.focus).normalized()
		var wanted: Vector3 = aim.normalized()
		if wanted.y > sin(CadCamera._PITCH_LIMIT):
			wanted = Vector3(0, sin(CadCamera._PITCH_LIMIT), cos(CadCamera._PITCH_LIMIT))
		_check("clicking %s looks from there (%s, wanted %s)" % [case[0], looking.snapped(
			Vector3.ONE * 0.01), wanted.snapped(Vector3.ONE * 0.01)],
			looking.distance_to(wanted) < 0.08 or (aim == Vector3(0, 1, 0) and looking.y > 0.95))

	# A drag on the cube turns the view.
	camera.set_view("default")
	camera._apply(1.0)
	var yaw: float = camera.yaw_turned()
	_drag(cube, middle, middle + Vector2(40, 0))
	_check("a drag on the cube turns the view (%.2f rad)" % (camera.yaw_turned() - yaw),
		absf(camera.yaw_turned() - yaw) > 0.2)

	# The arrows, the pad and the buttons, by what they publish.
	var buttons: Dictionary = cube.controls_by_name()
	yaw = camera.yaw_turned()
	_click(buttons["cube_turn_right"], (buttons["cube_turn_right"] as Control).size * 0.5)
	_check("the right arrow turns the view a step (%.2f rad)" % (camera.yaw_turned() - yaw),
		absf(camera.yaw_turned() - yaw) > 0.1)
	var pitch: float = camera.pitch_now()
	_click(buttons["cube_turn_up"], (buttons["cube_turn_up"] as Control).size * 0.5)
	_check("...and the up arrow tilts it", absf(camera.pitch_now() - pitch) > 0.1)
	var focus: Vector3 = camera.focus_now()
	var pad: Control = buttons["cube_pan"]
	_click(pad, Vector2(pad.size.x * 0.9, pad.size.y * 0.5))
	_check("a click on the pad's right arrow slides the view",
		camera.focus_now().distance_to(focus) > 1.0)
	focus = camera.focus_now()
	_drag(pad, pad.size * 0.5, pad.size * 0.5 + Vector2(30, 10))
	_check("...and a drag on the pad slides it with the pointer",
		camera.focus_now().distance_to(focus) > 1.0)
	var distance: float = camera.distance_now()
	_click(buttons["cube_zoom_in"], (buttons["cube_zoom_in"] as Control).size * 0.5)
	_check("+ zooms in (%.0f to %.0f)" % [distance, camera.distance_now()],
		camera.distance_now() < distance)
	distance = camera.distance_now()
	_click(buttons["cube_zoom_out"], (buttons["cube_zoom_out"] as Control).size * 0.5)
	_check("- zooms out", camera.distance_now() > distance)
	_click(buttons["cube_fit"], (buttons["cube_fit"] as Control).size * 0.5)
	_check("the last fits the model", fitted[0] == 1)

	print("")
	if _failures == 0:
		print("the cube says which way you are looking, and goes anywhere with a click")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _click(control: Control, at: Vector2) -> void:
	for down: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = at
		control._gui_input(press)


func _drag(control: Control, from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	control._gui_input(press)
	for n: int in range(1, 6):
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = from.lerp(to, n / 5.0)
		motion.relative = (to - from) / 5.0
		control._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	control._gui_input(release)
