## Does the app stop drawing when nothing changes, and still draw what does?
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24" \
##     godot --path . --resolution 1280x860 --script src/dev/idle_probe.gd
##   # on the graphics card, for its time a frame:
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a \
##     --server-args="-screen 0 1400x900x24" godot --path . --resolution 1280x860 \
##     --script src/dev/idle_probe.gd
##
## At the browser checks' window size: at 1400 x 900 the parts bin's first
## shimmering row out of sight fell off the window, and at 1280 x 860 it sat
## inside it and had every frame drawn (ThumbTile.in_sight).
##
## The app drew every frame with nothing moving: about 5.5 ms of a desktop
## graphics card a frame, sixty a second, and more of a laptop's, while
## somebody only looked at a model (2026-10-11). Now it draws only when
## something was written to the RenderingServer (IdleDraw). This counts the
## frames drawn with the model standing still, and fails past one in a
## second; then it does what a person does, and fails where a change was not
## drawn: a turn and the camera easing to a stop, a drag, a brick put down,
## the build animation's every step, the ghost under the pointer, a button
## lit by the pointer, a part's picture in the bin.
##
## When idle frames are drawn it says which node's processing draws them,
## by pausing each in turn.
##
## `-- --every-frame` runs the app as it was, drawing every frame, for the
## number to compare with.
extends SceneTree

var _failures: int = 0
var _finished: bool = false
var _main: Node
var _world: BrickWorld
var _camera: CadCamera
var _builder: Builder
var _playback: BuildPlayback
var _pointer: Vector2 = Vector2.ZERO
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")
## The graphics card's time for the last frame drawn, summed.
var _gpu_ms: float = 0.0
var _gpu_frames: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var every_frame: bool = OS.get_cmdline_user_args().has("--every-frame")
	# The app as it is used. Main draws only what changed, and leaves a
	# probe as it found it unless the probe asked first: most probes count
	# on a frame drawn for every frame they wait.
	OS.low_processor_usage_mode = not every_frame
	print("  %s, %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()])
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 30:
		await process_frame
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_builder = _main.get("_builder")
	_playback = _main.get("_playback")
	if _world == null or _camera == null or _builder == null or _playback == null:
		_check("the app came up", false)
		_finish()
		return
	if every_frame:
		OS.low_processor_usage_mode = false
	_check("the app draws only what changed%s" % (" (asked not to)" if every_frame else ""),
		OS.low_processor_usage_mode != every_frame)
	var rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	RenderingServer.frame_post_draw.connect(func() -> void:
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
		if gpu > 0.0:
			_gpu_ms += gpu
			_gpu_frames += 1)

	# The sample model, its parts and the bin's pictures, all arrived.
	var library: PartLibrary = _main.get("_library")
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 120000:
		await process_frame
		var waiting: bool = false
		for brick: BrickWorld.Brick in _world.bricks():
			if library.mesh_for(brick.part_id) == null:
				waiting = true
				break
		if not waiting:
			break
	_playback.stop()
	_camera.frame(_world.model_bounds())
	var quiet: bool = await _quiet(2.0, 60.0)
	print("  %s, %.0f s in" % ["settled" if quiet else "never settled in a minute",
		(Time.get_ticks_msec() - began) / 1000.0])

	print("")
	print("  standing still")
	var idle: Dictionary = await _measure(5.0)
	print("    %d frames drawn in %.1f s, %d run (%.0f drawn a second)" % [
		idle["drawn"], idle["seconds"], idle["run"], idle["drawn"] / idle["seconds"]])
	print("    graphics card %.2f ms a frame drawn, %.1f ms a second" % [
		idle["gpu_frame"], idle["gpu_frame"] * idle["drawn"] / idle["seconds"]])
	print("    CPU %.0f%% of a core, %.2f ms a frame run" % [
		idle["cpu"] * 100.0, idle["cpu"] * idle["seconds"] * 1000.0 / maxf(idle["run"], 1.0)])
	_check("no frame drawn standing still, but at most one a second (%d in %.1f s)"
		% [idle["drawn"], idle["seconds"]],
		idle["drawn"] <= ceili(idle["seconds"]) and idle["run"] > 20)
	if idle["drawn"] > ceili(idle["seconds"]) and not every_frame:
		await _who_draws()
	await _looks_only_on_change()

	print("")
	print("  something changes")
	await _turns()
	await _drags()
	await _edits()
	await _animates()
	await _hovers()
	await _lights_a_button()
	await _draws_a_part()
	_finish()


## The part under the pointer, which the status line and the pointer each
## ask for every frame: looked up again only when the pointer, the view or
## the model moved, and never out of view. Each asked for it every frame,
## and a look that hits nothing marches the whole lattice: with the
## 4,242-part Falcon built that was 18 to 25 ms twice a frame on the
## desktop, and a big design built in a hidden tab was never seen to settle
## once shown (arrival_check, 2026-10-12).
func _looks_only_on_change() -> void:
	var verbs: EditVerbs = _main.get("_verbs")
	var still: Dictionary = await _measure(2.0)
	_check("the part under the pointer looked up %d times in %d frames standing still"
		% [still["looked"], still["run"]], still["looked"] <= 1 and still["run"] > 10)
	var was: int = verbs.looked
	await _move_to(root.get_visible_rect().size * 0.5 + Vector2(30.0, 10.0))
	await _frames(3)
	_check("...and again when the pointer moved (%d)" % (verbs.looked - was), verbs.looked > was)
	# Out of view, as Main._watch_view says for a hidden tab: a design goes
	# on being built there, and nobody is pointing at anything.
	verbs.out_of_view = true
	was = verbs.looked
	var box: AABB = _world.model_bounds()
	var at := Transform3D(Basis.IDENTITY, box.end + Vector3(80.0, 0.0, 80.0))
	var id: int = _world.add_brick("3001", 4, at)
	_builder.register(id, "3001", at)
	await _frames(10)
	_check("...and out of view, with the model changing, never (%d)" % (verbs.looked - was),
		verbs.looked == was)
	verbs.out_of_view = false
	_builder.remove_brick_id(id)
	await _frames(3)


# -- the changes ---------------------------------------------------------------


## A turn from the keys eases to a stop over frames: every frame it moved
## in is drawn, and then none.
func _turns() -> void:
	await _quiet(1.0, 5.0)
	var moved: int = 0
	var missed: int = 0
	var last: Transform3D = _camera.global_transform
	var drawn: int = Engine.get_frames_drawn()
	_camera.key_turn(Vector2(1.0, 0.0))
	for _n: int in 600:
		await process_frame
		var now: Transform3D = _camera.global_transform
		var drew: bool = Engine.get_frames_drawn() > drawn
		drawn = Engine.get_frames_drawn()
		if not now.is_equal_approx(last):
			moved += 1
			if not drew:
				missed += 1
		last = now
		if moved > 0 and _camera.get("_yaw") == _camera.get("_target_yaw"):
			break
	_check("a turn from the keys: %d frames of it, each drawn (%d not)" % [moved, missed],
		moved >= 3 and missed == 0)
	_check("...and the camera came to rest where it was going",
		is_equal_approx(float(_camera.get("_yaw")), float(_camera.get("_target_yaw"))))
	_check("...and then nothing more is drawn", await _quiet(1.0))


## A right drag across the model turns it, drawn as it goes.
func _drags() -> void:
	await _quiet(1.0, 5.0)
	var middle: Vector2 = root.get_visible_rect().size * 0.5
	var drawn: int = Engine.get_frames_drawn()
	var was: Transform3D = _camera.global_transform
	await _move_to(middle)
	_press(MOUSE_BUTTON_RIGHT, middle, true)
	await _frames(2)
	var missed: int = 0
	for step: int in 12:
		var before: int = Engine.get_frames_drawn()
		await _move_to(middle + Vector2(8.0 * (step + 1), 0.0), MOUSE_BUTTON_MASK_RIGHT)
		if Engine.get_frames_drawn() == before:
			missed += 1
	_press(MOUSE_BUTTON_RIGHT, middle + Vector2(96.0, 0.0), false)
	await _frames(2)
	_check("a right drag turned the view, drawn at every step (%d not)" % missed,
		not _camera.global_transform.is_equal_approx(was) and missed == 0
		and Engine.get_frames_drawn() > drawn)
	_check("...and then nothing more is drawn", await _quiet(2.0))


## A brick put down is drawn, then nothing.
func _edits() -> void:
	await _quiet(1.0, 5.0)
	var drawn: int = Engine.get_frames_drawn()
	var box: AABB = _world.model_bounds()
	var at := Transform3D(Basis.IDENTITY, box.end + Vector3(40.0, 0.0, 40.0))
	var id: int = _world.add_brick("3001", 4, at)
	_builder.register(id, "3001", at)
	await _frames(4)
	_check("a brick put down is drawn", Engine.get_frames_drawn() > drawn)
	_check("...and then nothing more", await _quiet(2.0))


## The build animation: every step drawn as it is shown, and the whole
## model at the end.
func _animates() -> void:
	await _quiet(1.0, 5.0)
	var fresh := PackedInt64Array()
	var box: AABB = _world.model_bounds()
	for n: int in 48:
		var at := Transform3D(Basis.IDENTITY, Vector3(box.position.x - 200.0 + (n % 6) * 80.0,
			24.0 * (1 + n / 6), box.position.z - 200.0))
		var id: int = _world.add_brick("3001", 1 + n % 5, at)
		_builder.register(id, "3001", at)
		fresh.append(id)
	await _frames(2)
	await _quiet(1.0, 5.0)
	var steps: int = 0
	var missed: int = 0
	var at_step: int = -1
	var drawn: int = Engine.get_frames_drawn()
	if not _playback.play_new(fresh):
		_check("the build animation began", false)
		return
	for _n: int in 3000:
		# Each resumes at the start of a frame, with the last one's work done
		# and drawn or not: so the step it showed, and whether it drew.
		await process_frame
		var shown: int = int(_playback.get("_at"))
		var drew: bool = Engine.get_frames_drawn() > drawn
		drawn = Engine.get_frames_drawn()
		if shown != at_step:
			steps += 1
			at_step = shown
			if not drew:
				missed += 1
		if not _playback.is_playing():
			break
	await _frames(2)
	_check("the build animation: %d steps shown, each drawn (%d not)" % [steps, missed],
		steps >= 3 and missed == 0 and not _playback.is_playing()
		and not _world.is_revealing())
	_check("...and then nothing more", await _quiet(2.0))


## The ghost of the held part follows the pointer: each move that moved it
## is drawn, and a pointer standing still draws nothing.
func _hovers() -> void:
	_builder.held_part = "3005"
	# In hand, as Q or the bin puts it: Select is where the app rests, and
	# shows no ghost.
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.set_mode("place")
	await _frames(2)
	await _quiet(1.0, 5.0)
	var middle: Vector2 = root.get_visible_rect().size * 0.5
	var moved: int = 0
	var missed: int = 0
	var last: Transform3D = _builder.get("_ghost_transform")
	for step: int in 10:
		var before: int = Engine.get_frames_drawn()
		await _move_to(middle + Vector2(24.0 * step, 12.0 * step))
		var now: Transform3D = _builder.get("_ghost_transform")
		if not now.is_equal_approx(last):
			moved += 1
			if Engine.get_frames_drawn() == before:
				missed += 1
		last = now
	_check("the ghost under the pointer: %d moves of it, each drawn (%d not)" % [moved, missed],
		moved >= 3 and missed == 0 and _builder.has_preview())
	_check("...and a still pointer draws nothing", await _quiet(2.0))
	verbs.set_mode("select")
	_builder.hide_preview()
	_builder.held_part = ""
	await _frames(2)


## A button under the pointer lights up, and that is drawn.
func _lights_a_button() -> void:
	# On the CAD shell's toolbar since 2026-10-11; the model bar before.
	var button: BaseButton = null
	for holder: String in ["_shell", "_bar"]:
		var bar: Object = _main.get(holder)
		if button != null or bar == null or not bar.has_method("controls_by_name"):
			continue
		for name: String in ["save", "open", "new", "export"]:
			var one: Control = (bar.call("controls_by_name") as Dictionary).get(name)
			if one is BaseButton and one.is_visible_in_tree():
				button = one
				break
	if button == null:
		_check("a toolbar button to point at", false)
		return
	await _move_to(Vector2(4.0, root.get_visible_rect().size.y - 4.0))
	await _quiet(1.0, 5.0)
	var drawn: int = Engine.get_frames_drawn()
	await _move_to(button.get_global_rect().get_center())
	await _frames(2)
	_check("a button lit by the pointer is drawn (%s)" % button.name,
		button.is_hovered() and Engine.get_frames_drawn() > drawn)
	await _move_to(Vector2(4.0, root.get_visible_rect().size.y - 4.0))
	_check("...and then nothing more", await _quiet(2.0))


## A part's picture for the bin is drawn off screen and arrives.
func _draws_a_part() -> void:
	var thumbnails: Object = _main.get("_thumbnails")
	if thumbnails == null:
		_check("the bin has pictures to draw", false)
		return
	await _quiet(1.0, 5.0)
	var part: String = "3039"
	var colour: int = 2
	var started: int = Time.get_ticks_msec()
	var texture: Variant = thumbnails.call("request", part, colour)
	for _n: int in 3000:
		if texture != null:
			break
		await process_frame
		texture = thumbnails.call("peek", part, colour)
	_check("a part's picture, asked for standing still, arrives (%d ms)"
		% (Time.get_ticks_msec() - started), texture != null)
	_check("...and then nothing more is drawn", await _quiet(3.0))


# -- counting ------------------------------------------------------------------


## Whether a whole [param seconds] go by with nothing drawn, waiting up to
## [param longest] for it.
func _quiet(seconds: float, longest: float = 10.0) -> bool:
	var until: int = Time.get_ticks_msec() + int(maxf(longest, seconds) * 1000.0)
	var since: int = Time.get_ticks_msec()
	var drawn: int = Engine.get_frames_drawn()
	while Time.get_ticks_msec() < until:
		await process_frame
		if Engine.get_frames_drawn() != drawn:
			drawn = Engine.get_frames_drawn()
			since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - since >= int(seconds * 1000.0):
			return true
	return false


## Frames drawn and run, CPU and the graphics card's time, over [param seconds].
func _measure(seconds: float) -> Dictionary:
	_gpu_ms = 0.0
	_gpu_frames = 0
	var drawn: int = Engine.get_frames_drawn()
	var run: int = Engine.get_process_frames()
	var cpu: int = _cpu_ticks()
	var verbs: EditVerbs = _main.get("_verbs")
	var looked: int = verbs.looked
	var began: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - began < int(seconds * 1000000.0):
		await process_frame
	var took: float = (Time.get_ticks_usec() - began) / 1000000.0
	return {
		"looked": verbs.looked - looked,
		"seconds": took,
		"drawn": Engine.get_frames_drawn() - drawn,
		"run": Engine.get_process_frames() - run,
		"cpu": (_cpu_ticks() - cpu) / 100.0 / took if cpu >= 0 else -1.0,
		"gpu_frame": _gpu_ms / _gpu_frames if _gpu_frames > 0 else 0.0,
	}


## This process's CPU time in clock ticks (a hundredth of a second), every
## thread of it.
static func _cpu_ticks() -> int:
	var file: FileAccess = FileAccess.open("/proc/self/stat", FileAccess.READ)
	if file == null:
		return -1
	var line: String = file.get_line()
	var fields: PackedStringArray = line.substr(line.rfind(")") + 2).split(" ")
	return fields[11].to_int() + fields[12].to_int() if fields.size() > 12 else -1


## Which node's processing draws frames nobody asked for: all paused, and
## each let go again alone, with the frames drawn counted.
func _who_draws() -> void:
	var nodes: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != root and node.is_processing():
			nodes.append(node)
		stack.append_array(node.get_children(true))
	for node: Node in nodes:
		node.set_process(false)
	await _frames(3)
	var drawn: int = Engine.get_frames_drawn()
	await _frames(20)
	var without: int = Engine.get_frames_drawn() - drawn
	var found: Array[String] = []
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		node.set_process(true)
		await _frames(3)
		drawn = Engine.get_frames_drawn()
		await _frames(20)
		if Engine.get_frames_drawn() - drawn > 2:
			found.append("%s (%s)" % [node.get_path(), node.get_script().resource_path.get_file()
				if node.get_script() != null else node.get_class()])
		node.set_process(false)
	for node: Node in nodes:
		if is_instance_valid(node):
			node.set_process(true)
	if without > 2:
		found.append("%d of 20 frames with every node's processing paused (a coroutine, a tween, a shader reading TIME)" % without)
	print("    drawn by: %s" % (", ".join(found) if not found.is_empty() else "nothing found"))


# -- the pointer ---------------------------------------------------------------


func _frames(how_many: int) -> void:
	for _n: int in how_many:
		await process_frame


## Through Input, as cursor_probe does: the camera asks Input whether a
## button is still down.
func _press(which: int, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if down and which == MOUSE_BUTTON_RIGHT else 0
	event.position = _as_event(at)
	event.global_position = event.position
	_pointer = event.position
	Input.parse_input_event(event)


func _move_to(at: Vector2, mask: int = 0) -> void:
	if _virtual:
		Input.warp_mouse(_as_event(at))
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	_pointer = event.position
	event.button_mask = mask
	Input.parse_input_event(event)
	await _frames(2)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _check(what: String, held: bool) -> void:
	print("    %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "nothing is drawn standing still, and every change is")
	_finished = true
	quit(1 if _failures else 0)


func _finalize() -> void:
	if not _finished:
		print("    FAIL the app quit before the probe finished")
