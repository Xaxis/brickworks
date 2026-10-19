extends SceneTree
## Presses across a slow frame. A browser drawing in software, or a slow
## phone, draws a frame a second and more; a press and its release then come
## a frame apart. How long something was held is what the frames saw, not
## the clock: a finger's tap is not a hold (a hold takes a brick off), and a
## click on the view cube's zoom is a click. (A drag across one is
## grab_probe -- --only=chain.) Each check fails timed by the clock. And
## the press's own frame slow before the app sees it (PressFrameWork): a
## hold is timed from the first frame that saw the press, so that work is
## not held either. Each of those fails timed from the press.
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . \
##     --resolution 1400x900 --script src/dev/slow_frames_probe.gd

## As slow as m78's preview drew grab_flow's frames.
const SLOW_MS := 600
const PressFrameWork := preload("res://src/dev/press_frame_work.gd")

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _camera: Node


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


## The frame is slow in its drawing, after the app's own work for it; what
## comes next is read at the start of the next frame.
func _slow_frame() -> void:
	await RenderingServer.frame_post_draw
	OS.delay_msec(SLOW_MS)


func _touch(at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = down
	event.position = _as_event(at)
	Input.parse_input_event(event)


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	await _cube_click()
	await _tap()
	print("")
	print("slow frames: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## The view cube's Zoom in, pressed, one slow frame, released: a step in.
func _cube_click() -> void:
	var cube: ViewCube = _main.get("_gizmo")
	var zoom: Control = cube._arrows["cube_zoom_in"]
	var before: float = float(_camera.get("_target_distance"))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = zoom.size * 0.5
	zoom._gui_input(press)
	await _slow_frame()
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	zoom._gui_input(release)
	await _frames(3)
	var after: float = float(_camera.get("_target_distance"))
	_check("the view cube's Zoom in, clicked across a %d ms frame, zooms a step: %.1f to %.1f"
		% [SLOW_MS, before, after], after < before - 0.01)
	# Pressed, its own frame slow before the cube sees it, released: the
	# same step, not a hold's zoom (which a hold timed from the press made).
	var step: float = after / before
	var work: Node = PressFrameWork.new()
	work.ms = SLOW_MS
	work.pressed = func() -> bool: return int(zoom.get("_down_at")) >= 0
	root.add_child(work)
	before = float(_camera.get("_target_distance"))
	zoom._gui_input(press)
	await process_frame
	await process_frame
	zoom._gui_input(release)
	await _frames(3)
	after = float(_camera.get("_target_distance"))
	_check("...and clicked with %d ms of work in the press's own frame before the cube sees it, the same step: %.1f to %.1f (x%.3f, a step x%.3f)"
		% [int(work.took), before, after, after / before, step], int(work.took) >= SLOW_MS
		and absf(after / before - step) < 0.005)
	work.queue_free()
	# Pressed, the frame that handled it slow in its drawing, released two
	# frames on: the same step.
	await _frames(3)
	before = float(_camera.get("_target_distance"))
	zoom._gui_input(press)
	await RenderingServer.frame_post_draw
	OS.delay_msec(SLOW_MS)
	await process_frame
	await process_frame
	zoom._gui_input(release)
	await _frames(3)
	after = float(_camera.get("_target_distance"))
	_check("...and clicked with the press's own frame %d ms in its drawing, the same step: %.1f to %.1f (x%.3f)"
		% [SLOW_MS, before, after, after / before], absf(after / before - step) < 0.005)


## A finger on a brick: a tap across a slow frame leaves it; held as long
## with the frames running, it takes it off (the hold this must not be).
func _tap() -> void:
	var path: String = OS.get_user_data_dir().path_join("sessions/probe/slow_frames.ldr")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("0 FILE slow_frames.ldr\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	file.close()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", path)
	var store: ModelStore = _main.get("_store")
	for _n: int in 400:
		await process_frame
		if store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	var library: PartLibrary = _main.get("_library")
	var brick: BrickWorld.Brick = null
	for one: BrickWorld.Brick in _world.bricks():
		if not store.scenery.has(one.id):
			brick = one
	if brick == null:
		_check("the brick to tap on opened", false)
		return
	var box: AABB = brick.transform * (library.parts.get(brick.part_id) as PartLibrary.PartInfo).bounds
	_camera.frame(box, 2.0)
	await _frames(10)
	var at: Vector2 = _camera.unproject_position(box.get_center())
	var verbs: Node = _main.get("_verbs")
	_check("a finger's place over the brick: %s" % at, int(verbs.brick_at(at)) == brick.id)
	var builder: Builder = _main.get("_builder")
	var depth: int = builder.history_depth()
	_touch(at, true)
	await _frames(2)
	await _slow_frame()
	_touch(at, false)
	await _frames(6)
	_check("tapped across a %d ms frame, the brick stays (%s)" % [SLOW_MS,
		"there" if _world.get_brick(brick.id) != null else builder.history_words(1)],
		_world.get_brick(brick.id) != null)
	while builder.history_depth() > depth:
		builder.undo()
	await _frames(30)
	# Tapped, the touch's own frame slow before the app sees it.
	var work: Node = PressFrameWork.new()
	work.ms = SLOW_MS
	work.pressed = func() -> bool: return int(_main.get("_touch_index")) != -1
	root.add_child(work)
	_touch(at, true)
	await _frames(2)
	_touch(at, false)
	await _frames(6)
	_check("tapped with %d ms of work in its own frame before the app sees it, the brick stays (%s)" % [int(work.took),
		"there" if _world.get_brick(brick.id) != null else builder.history_words(1)],
		int(work.took) >= SLOW_MS and _world.get_brick(brick.id) != null)
	work.queue_free()
	while builder.history_depth() > depth:
		builder.undo()
	await _frames(30)
	# Tapped, the frame that handled the touch slow in its drawing, lifted
	# two frames on.
	_touch(at, true)
	await process_frame
	await RenderingServer.frame_post_draw
	OS.delay_msec(SLOW_MS)
	await process_frame
	_touch(at, false)
	await _frames(6)
	_check("tapped with its own frame %d ms in its drawing, the brick stays (%s)" % [SLOW_MS,
		"there" if _world.get_brick(brick.id) != null else builder.history_words(1)],
		_world.get_brick(brick.id) != null)
	while builder.history_depth() > depth:
		builder.undo()
	await _frames(30)
	_touch(at, true)
	await create_timer(float(SLOW_MS) / 1000.0).timeout
	_touch(at, false)
	await _frames(6)
	_check("held as long with the frames running, it is taken off (%s)" % [builder.history_words(1)
		if builder.history_depth() > depth else "nothing done"], _world.get_brick(brick.id) == null)
