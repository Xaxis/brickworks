## Do the panels sleep at rest, and wake for whatever gives them work?
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24" \
##     godot --path . --resolution 1280x860 --script src/dev/wake_probe.gd
##
## Forty nodes looked at the model every frame to see whether anything had
## changed, 4 to 6 ms of a slow phone's every frame with nothing moving
## (idleframes, 2026-11-19). Now each sleeps once it has nothing to do and
## everything that can give one work wakes them all (Wake). This turns
## sleeping on as the app does, stands still and checks the panels are
## asleep and what the frames cost, then does what wakes them: the pointer,
## a key, the window resized, a part added to the model, the view moved,
## a search typed into the bin. Each must have them all running in the next
## frame, and asleep again once things are still. A node its owner turned
## off (the grab in a viewer, Wake.off) must stay off through a wake, and a
## node with work of its own under way (a search) must not sleep till it is
## done.
##
## Every act drawn in the frame after it, with every node asleep before it:
## idle_probe with `-- --wake`.
extends SceneTree

const MODEL := "res://models/house.ldr"
## The panels the app shows on a desktop at rest, which must be asleep.
const SLEEPERS := [
	"res://src/camera/cad_camera.gd",
	"res://src/ui/status_bar.gd",
	"res://src/ui/toolbar.gd",
	"res://src/ui/parts_bin.gd",
	"res://src/ui/grab_drag.gd",
	"res://src/ui/outliner.gd",
	"res://src/ui/steps_bar.gd",
	"res://src/ui/view_cube.gd",
	"res://src/ui/cursors.gd",
	"res://src/ui/pins_view.gd",
	"res://src/ui/modal_dialogs.gd",
	"res://src/ui/inspector.gd",
	"res://src/ui/part_thumbnails.gd",
]

var _failures: int = 0
var _finished: bool = false
var _main: Node
var _world: BrickWorld
var _camera: CadCamera
var _builder: Builder
var _pointer: Vector2 = Vector2.ZERO
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	OS.low_processor_usage_mode = true
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 30:
		await process_frame
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_builder = _main.get("_builder")
	if _world == null or _camera == null or _builder == null:
		_check("the app came up", false)
		_finish()
		return
	_check("off in a probe that did not ask (%s)" % Wake.on, not Wake.on)
	var placed: int = int(_main.call("_open", MODEL))
	print("  %s, %d parts" % [MODEL.get_file(), placed])
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
	(_main.get("_playback") as BuildPlayback).stop()
	_camera.frame(_world.model_bounds())
	await _quiet(2.0, 60.0)
	var awake_ms: float = await _process_ms(2.0)

	Wake.begin()
	print("")
	print("  standing still")
	await _seconds(1.5)
	_all_asleep("asleep after 1.5 s standing still")
	var asleep_ms: float = await _process_ms(2.0)
	print("    processing %.3f ms a frame awake, %.3f asleep" % [awake_ms, asleep_ms])
	_check("a frame's processing is less asleep than awake", asleep_ms < awake_ms)
	_check("and nothing woke them standing still (%d asleep)" % _asleep_count(),
		_asleep_count() >= 8)
	print("    still processing: %s" % ", ".join(_still_running()))

	print("")
	print("  what wakes them")
	var centre: Vector2 = root.get_visible_rect().size * 0.5
	await _wakes("the pointer moving", func() -> void: _move(centre + Vector2(40.0, 12.0)))
	await _wakes("a key", func() -> void: _key(KEY_SHIFT))
	await _wakes("the window resized", func() -> void: root.size_changed.emit())
	var box: AABB = _world.model_bounds()
	var at := Transform3D(Basis.IDENTITY, box.end + Vector3(80.0, 0.0, 80.0))
	var added: Array = [0]
	var outliner: Outliner = (_main.get("_shell") as Shell).outliner
	var looked: int = int(outliner.get("_looked_at"))
	await _wakes("a part added to the model", func() -> void:
		added[0] = _world.add_brick("3001", 4, at)
		_builder.register(int(added[0]), "3001", at))
	_check("...and the tree looked at the model again (%d ms later)"
		% (int(outliner.get("_looked_at")) - looked), int(outliner.get("_looked_at")) > looked)
	await _wakes("the view moved", func() -> void:
		_camera.frame(_world.model_bounds().grow(40.0)))
	await _wakes("a part taken out", func() -> void: _builder.remove_brick_id(int(added[0])))

	print("")
	print("  work of its own")
	await _seconds(1.5)
	var bin: PartsBin = _main.get("_bin")
	if bin != null:
		bin.search_for("brick 2 x 4")
		await _frames(2)
		var kept: bool = bin.is_processing()
		await _seconds(1.5)
		_check("the bin awake for its search (%s), asleep once found (%s)" % [kept,
			not bin.is_processing()], kept and not bin.is_processing())
	var grab: GrabDrag = _main.get("_grab_drag")
	if grab != null:
		Wake.off(grab)
		_move(centre + Vector2(-30.0, 8.0))
		await _frames(2)
		_check("a node its owner turned off stays off through a wake",
			not grab.is_processing())
		grab.set_process(true)
		await _seconds(1.5)
		_check("...and sleeps again once turned on", not grab.is_processing())

	Wake.end()
	await _frames(2)
	_check("off again: everything running", _asleep_count() == 0 and _still_asleep().is_empty())
	_finish()


## [param act] wakes every sleeper in the next frame, and they sleep again
## once nothing more happens.
func _wakes(what: String, act: Callable) -> void:
	await _seconds(1.5)
	var before: int = Wake.wakes
	var asleep: int = _asleep_count()
	act.call()
	await process_frame
	var slept: Array[String] = _still_asleep()
	_check("%s wakes the %d asleep in the next frame%s" % [what, asleep,
		"" if slept.is_empty() else " (still asleep: %s)" % ", ".join(slept)],
		Wake.wakes > before and slept.is_empty() and asleep > 0)
	await _seconds(1.5)
	_all_asleep("...and they sleep again")


func _all_asleep(what: String) -> void:
	var awake: Array[String] = []
	for node: Node in _sleepers():
		if node.is_processing():
			awake.append(_name(node))
	_check("%s%s" % [what, "" if awake.is_empty() else " (awake: %s)" % ", ".join(awake)],
		awake.is_empty() and not _sleepers().is_empty())


func _sleepers() -> Array[Node]:
	var out: Array[Node] = []
	_walk(root, func(node: Node) -> void:
		var script: Script = node.get_script()
		if script != null and SLEEPERS.has(script.resource_path) and node.is_inside_tree():
			out.append(node))
	return out


func _still_asleep() -> Array[String]:
	var out: Array[String] = []
	for node: Node in _sleepers():
		if Wake.is_asleep(node) or not node.is_processing():
			out.append(_name(node))
	return out


## Every node with a script still running its _process, by script.
func _still_running() -> Array[String]:
	var out: Array[String] = []
	_walk(root, func(node: Node) -> void:
		var script: Script = node.get_script()
		if script != null and node.is_processing() and node.has_method("_process") \
				and script.resource_path.begins_with("res://src/") \
				and not script.resource_path.begins_with("res://src/dev/"):
			out.append(script.resource_path.get_file().get_basename()))
	return out


## Counted in an array: a lambda captures a local int by value.
func _asleep_count() -> int:
	var n: Array[int] = [0]
	_walk(root, func(node: Node) -> void:
		if Wake.is_asleep(node):
			n[0] += 1)
	return n[0]


func _walk(node: Node, visit: Callable) -> void:
	visit.call(node)
	for child: Node in node.get_children():
		_walk(child, visit)


func _name(node: Node) -> String:
	return (node.get_script() as Script).resource_path.get_file().get_basename()


## The engine's own measure of the scripts' and engine's processing a frame,
## averaged over [param seconds].
func _process_ms(seconds: float) -> float:
	var total: float = 0.0
	var frames: int = 0
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		frames += 1
	return total / maxf(frames, 1.0)


func _quiet(seconds: float, longest: float) -> bool:
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


func _seconds(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _frames(how_many: int) -> void:
	for _n: int in how_many:
		await process_frame


func _move(at: Vector2) -> void:
	if _virtual:
		Input.warp_mouse(_as_event(at))
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	_pointer = event.position
	Input.parse_input_event(event)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)


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
		else "asleep standing still, and woken by everything that gives them work")
	_finished = true
	Wake.end()
	quit(1 if _failures else 0)


func _finalize() -> void:
	if not _finished:
		print("    FAIL the app quit before the probe finished")
