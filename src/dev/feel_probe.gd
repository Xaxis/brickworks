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
var _controls: ControlsDialog
var _main: Node
var _middle: Vector2


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	_main = main
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	_world = main.get("_world")
	_camera = main.get("_camera")
	_builder = main.get("_builder")
	_controls = main.get("_controls")
	var store: ModelStore = main.get("_store")

	# Let the opening animation finish first.
	#
	# The model that greets you assembles itself a brick at a time, and
	# while it is doing that the first click stops it rather than
	# placing anything — deliberately, because a placement against a
	# half-shown model would attach to the wrong brick.
	#
	# A probe that starts while it is still running therefore loses its
	# first drag, its first click and its first right-click to it. That
	# is what was happening: four checks failed together, only when the
	# machine was busy enough to make the animation outlast the wait,
	# and every message blamed clicking. Nothing in the output pointed
	# here.
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()

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

	# Wait for the parts, not for a number of frames.
	#
	# Meshes arrive when they arrive, and a fixed wait is a race the
	# machine wins while it is idle and loses while the rest of the
	# suite is running — which is the way round that makes a test look
	# fine here and fail there. It did: this passed on its own and
	# failed four checks inside the suite, on a busy machine, with
	# nothing in the output to say the parts were the reason.
	var library: PartLibrary = main.get("_library")
	var ready: bool = false
	for _n: int in 2400:
		if (library.mesh_for("3001") != null
				and library.mesh_for("3005") != null):
			ready = true
			break
		await process_frame
	if not ready:
		_failures += 1
		print("  FAIL  the parts never loaded, so nothing below means "
			+ "anything")
		quit(1)
		return

	if not await _input_arrives():
		_failures += 1
		print("  FAIL  events are not reaching the app, so nothing "
			+ "below means anything")
		quit(1)
		return
	await _settle()

	await _mouse()
	await _keyboard()
	await _settings()
	await _framing()

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

	# A box let go where this handler never sees the release.
	#
	# Dragging rightwards and letting go over the parts bin is what
	# hands naturally do, and it used to leave the box drawn with
	# nothing holding it — after which every click was read as the end
	# of a drag still in progress and the app took no input at all.
	var panel: Vector2 = _panel_point()
	if panel == Vector2.ZERO:
		_failures += 1
		print("  FAIL  no panel on screen to let go over, so the "
			+ "check below never ran")
	else:
		_builder.clear_selection()
		# Checked, not assumed. A check whose premise has quietly
		# stopped holding passes for the wrong reason, and this one did
		# — it went on passing with the bug put back, because the
		# release it was meant to have dropped was never over a panel
		# at all.
		_check("the point to let go over really is a panel",
			_main._over_panel_at(panel))
		# Tall enough to enclose the bricks, not a thin band across
		# their middle — a window select takes what is wholly inside
		# it, so a box that clips them catches nothing and says the
		# release was dropped when it was not.
		var corner := Vector2(panel.x, _middle.y + 240.0)
		_check("the corner to let go on is over a panel too",
			_main._over_panel_at(corner))
		await _drag(MOUSE_BUTTON_LEFT, _middle - Vector2(320.0, 240.0),
			corner)
		# What actually goes wrong is that the selection silently does
		# not happen, so that is what to ask about. Asking only whether
		# the box stopped being drawn was not enough: the next press
		# begins a new box and clears the old one either way, so the
		# check passed with the bug put back.
		_check("a box let go over a panel still selects",
			not _main._marquee.is_drawing()
				and _builder.selection.size() > 0)
		_builder.clear_selection()
		before = _world.brick_count()
		await _click(MOUSE_BUTTON_LEFT, _middle)
		_check("...and clicking still works afterwards",
			_world.brick_count() > before)

	before = _world.brick_count()
	await _click(MOUSE_BUTTON_RIGHT, _middle)
	_check("a right click takes a brick off", _world.brick_count() < before)

	before = _world.brick_count()
	var yaw: float = _camera._target_yaw
	await _drag(MOUSE_BUTTON_RIGHT, _middle, _middle + Vector2(80.0, 20.0))
	_check("a right drag turns the view",
		not is_equal_approx(_camera._target_yaw, yaw))
	_check("...and takes nothing off", _world.brick_count() == before)

	# Turning moves the focus too — it swings about the pivot — so
	# asking whether the focus moved does not tell a turn from a slide.
	# This check was written that way and passed while naming the wrong
	# verb. The angle is what separates them.
	yaw = _camera._target_yaw
	var focus: Vector3 = _camera._target_focus
	await _drag(MOUSE_BUTTON_MIDDLE, _middle, _middle + Vector2(90.0, 40.0))
	_check("a middle drag turns the view",
		not is_equal_approx(_camera._target_yaw, yaw)
			and _camera._target_focus.distance_to(focus) > 0.0)

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


## Wait until events actually arrive, by sending one and watching.
##
## A scene in the tree is not a window taking input. On the first run
## after an edit Godot reimports, and everything sent before the window
## is ready goes nowhere at all — so every check fails, including the
## ones that are pure arithmetic and cannot fail for any other reason.
## A run like that says nothing about the app, and it looked exactly
## like a real failure: ten of them, in a row, about clicking.
##
## Counting frames cannot settle it, because the thing being waited for
## is how long the machine takes. Asking is the only honest way: turn
## the view a little and see whether it turned.
func _input_arrives() -> bool:
	# Ask for the window first.
	#
	# Inside the suite this starts moments after another windowed probe
	# has closed, and a window that has not been given the foreground
	# can sit there taking nothing. That is the whole of this flake: it
	# has never once failed on its own and fails every so often in the
	# suite, and when it does, checks that are pure arithmetic fail
	# alongside the rest.
	DisplayServer.window_move_to_foreground()
	get_root().grab_focus()
	for _n: int in 30:
		await process_frame

	for _attempt: int in 240:
		var yaw: float = _camera._target_yaw
		await _drag(MOUSE_BUTTON_RIGHT, _middle,
			_middle + Vector2(40.0, 0.0))
		if not is_equal_approx(_camera._target_yaw, yaw):
			return true
		for _n: int in 30:
			await process_frame
	return false


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


## The two things a person can change about the controls.
##
## A setting that is written down, remembered, and changes nothing is
## worse than no setting: it reads as the app ignoring you. So each one
## is checked by doing the gesture it governs and watching the camera,
## not by reading the value back.
func _settings() -> void:
	print("")
	print("  the two settings")
	await _settle()

	ViewPrefs.invert_zoom = false
	var near: float = _camera._target_distance
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await _frames(4)
	_check("scrolling up zooms in", _camera._target_distance < near)

	ViewPrefs.invert_zoom = true
	_camera._target_distance = near
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await _frames(4)
	_check("inverted, the same scroll zooms out",
		_camera._target_distance > near)
	ViewPrefs.invert_zoom = false

	# And the middle button, which turns or slides depending.
	ViewPrefs.middle_slides = false
	await _settle()
	var yaw: float = _camera._target_yaw
	var focus: Vector3 = _camera._target_focus
	await _drag(MOUSE_BUTTON_MIDDLE, _middle, _middle + Vector2(90.0, 30.0))
	_check("middle turns by default",
		not is_equal_approx(_camera._target_yaw, yaw))

	ViewPrefs.middle_slides = true
	await _settle()
	yaw = _camera._target_yaw
	focus = _camera._target_focus
	await _drag(MOUSE_BUTTON_MIDDLE, _middle, _middle + Vector2(90.0, 30.0))
	_check("set the other way, middle slides instead",
		is_equal_approx(_camera._target_yaw, yaw)
			and _camera._target_focus.distance_to(focus) > 1.0)
	_check("and the hint says so",
		_names_middle("slide"))
	ViewPrefs.middle_slides = false
	_check("and says the other thing when it is set back",
		_names_middle("turn"))
	# The strip picks its entries out of the full list by key, so a key
	# that is renamed there leaves a gap here rather than an error.
	_check("the strip carries every control it means to",
		ControlsHint.for_strip().size()
			== ControlsHint.ON_THE_STRIP.size() + 1)

	# Re-centring, which is how you stop the model drifting off screen
	# after a few turns.
	await _settle()
	focus = _camera._target_focus
	var off: Vector2 = _middle + Vector2(120.0, 60.0)
	_move_to(off, Vector2.ZERO, 0)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_MIDDLE
	event.pressed = true
	event.double_click = true
	event.position = _as_event(off)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(4)
	_check("double-clicking the middle button re-centres",
		_camera._target_focus.distance_to(focus) > 1.0)

	# And the panel the two settings live in, because a setting nobody
	# can reach is a setting nobody has.
	await _key(KEY_COMMA)
	_check("comma opens the controls panel",
		_controls != null and _controls.visible)
	_controls.visible = false


## Whether the controls strip names this verb for the middle button.
func _names_middle(verb: String) -> bool:
	for binding: ControlsHint.Binding in ControlsHint.for_keyboard():
		if binding.keys.has("middle-drag"):
			return binding.verb == verb
	return false


func _frames(how_many: int) -> void:
	for _n: int in how_many:
		await process_frame


## Framing, which has to be about the model and not the ground.
##
## The baseplate is a brick like any other and is 32 studs across, so a
## box round everything is a box round the baseplate. Every framing call
## took that box, and a six-stud car opened as a speck in a green field.
## Nothing failed; it just looked like the model had got lost.
func _framing() -> void:
	print("")
	print("  framing")
	await _settle()
	var tight: float = _camera._target_distance

	var plate := Transform3D(Basis.IDENTITY, Vector3(0.0, -8.0, 0.0))
	var plate_id: int = _world.add_brick("3811", 2, plate)
	if plate_id == 0:
		_failures += 1
		print("  FAIL  no baseplate to stand on, so the check below "
			+ "never ran")
		return
	_main._store.scenery[plate_id] = true
	await _frames(6)

	# Pushed well back first, so that framing has to actually do
	# something for this to pass.
	_camera._target_distance = tight * 8.0
	await _key(KEY_F)
	await _frames(8)
	_check("framing comes back to the model",
		_camera._target_distance < tight * 8.0)
	_check("...and ignores the baseplate under it",
		_camera._target_distance < tight * 2.0)

	print("")
	print("  ground for a model bigger than one plate")
	# The baseplate is laid when a model is opened and when the board is
	# cleared, and was never laid again after something was built on it
	# — so a ship designed larger than thirty-two studs hung off the
	# edge into nothing.
	var plates_before: int = _plates()
	for n: int in 30:
		var far := Transform3D(Basis.IDENTITY,
			Vector3(float(n) * 80.0 - 600.0, 24.0, 0.0))
		var wide_id: int = _world.add_brick("3001", 4, far)
		if wide_id != 0:
			_builder.register(wide_id, "3001", far)
	await _frames(4)
	_main._ground_for_the_model()
	await _frames(4)
	_check("more ground is laid, %d plates against %d"
		% [_plates(), plates_before], _plates() > plates_before)
	var built: AABB = _world.model_bounds()
	_check("...and the model is standing on it",
		_main._ground.encloses(AABB(
			Vector3(built.position.x, 0.0, built.position.z),
			Vector3(built.size.x, 0.0, built.size.z))))


## A point on screen that a panel is under, found by walking in from
## the right edge rather than assuming a width.
## How many baseplates are down.
func _plates() -> int:
	return _main._store.scenery.size()


func _panel_point() -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var y: float = rect.y * 0.5
	var x: int = int(rect.x) - 6
	while float(x) > rect.x * 0.55:
		var at := Vector2(float(x), y)
		if _main._over_panel_at(at):
			return at
		x -= 6
	return Vector2.ZERO


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)
	# And the state that most often explains one of these.
	#
	# This has failed twice inside the suite and never on its own,
	# with a different set of checks each time, and both runs were on a
	# busy machine. Guessing at it from the list of what failed got
	# nowhere twice. A key shortcut does nothing at all while a text box
	# has the focus, which is the first thing worth knowing and the one
	# thing the output never said.
	var focused: Control = root.gui_get_focus_owner()
	print("        focus=%s playing=%s drawing=%s sel=%d bricks=%d" % [
		"none" if focused == null else focused.get_class(),
		_main._playback != null and _main._playback.is_playing(),
		_main._marquee.is_drawing(), _builder.selection.size(),
		_world.brick_count()])


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
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


## Viewport coordinates turned into the window coordinates an event
## actually carries.
##
## The two are not the same here: this app scales its interface, so the
## viewport was 1600 wide inside a 1400 wide window. A point worked out
## from the viewport rectangle and handed to an event lands somewhere
## else once the engine has scaled it — which meant the check that
## asked the app whether a point was over a panel, and then let go of
## the button at that point, was asking about one place and clicking
## another. It passed with the bug put back, every time, for a reason
## that had nothing to do with panels.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _wheel(which: int) -> void:
	_press(which, _middle, true)
	_press(which, _middle, false)



func _move_to(at: Vector2, by: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = _as_event(by)
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
