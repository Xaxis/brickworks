## Scratch probe: what a finger actually produces.
extends SceneTree

var _main: Node
var _seen: Array[String] = []


func _initialize() -> void:
	_run()


class Spy extends Node:
	var log: Array[String]
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			log.append("touch %s at %s" % [
				"down" if event.pressed else "up", event.position])
		elif event is InputEventMouseButton:
			log.append("mouse %s at %s (device %d)" % [
				"down" if event.pressed else "up", event.position, event.device])
		elif event is InputEventScreenDrag:
			log.append("drag at %s" % event.position)
		elif event is InputEventMouseMotion:
			log.append("motion at %s" % event.position)


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame

	var world: BrickWorld = _main.get("_world")
	var builder: Builder = _main.get("_builder")
	var camera: Node = _main.get("_camera")
	print("bricks before: ", world.brick_count())
	print("touchscreen available: ", DisplayServer.is_touchscreen_available())
	print("viewport visible rect: ", _main.get_viewport().get_visible_rect().size)
	print("window size: ", DisplayServer.window_get_size())
	print("content scale factor: ", _main.get_window().content_scale_factor)
	print("bin dock rect: ", (_main.get("_bin_dock") as Control).get_global_rect())
	print("mouse position before: ", _main.get_viewport().get_mouse_position())

	# A spy added last, so it sees unhandled input first and can record the
	# order the engine hands events over in.
	var spy := Spy.new()
	spy.log = []
	root.add_child(spy)
	await process_frame

	var middle: Vector2 = _main.get_viewport().get_visible_rect().size * 0.5
	print("--- one finger down at %s, dragged, lifted ---" % middle)
	_touch(0, middle, true)
	await process_frame
	print("  after finger down: bricks=%d mouse=%s swallow=%s" % [
		world.brick_count(), _main.get_viewport().get_mouse_position(),
		camera.swallowing_click()])
	for n: int in 6:
		_drag(0, middle + Vector2(12 * (n + 1), 0), Vector2(12, 0))
		await process_frame
	_touch(0, middle + Vector2(72, 0), false)
	await process_frame
	await process_frame
	print("  after lift: bricks=%d was_tap=%s swallow=%s" % [
		world.brick_count(), camera.last_touch_was_a_tap(),
		camera.swallowing_click()])
	for line: String in spy.log:
		print("  | ", line)

	spy.log = []
	print("--- a clean tap at %s ---" % (middle + Vector2(40, 40)))
	var before: int = world.brick_count()
	_touch(1, middle + Vector2(40, 40), true)
	await process_frame
	_touch(1, middle + Vector2(40, 40), false)
	await process_frame
	await process_frame
	print("  tap placed %d brick(s)" % (world.brick_count() - before))
	for line: String in spy.log:
		print("  | ", line)

	quit(0)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, at: Vector2, by: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	e.relative = by
	Input.parse_input_event(e)
