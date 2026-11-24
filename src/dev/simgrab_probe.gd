## pastereview: does a part taken hold of on its joint, now selected as the
## grab begins (appwalk f32280e26), move anything that did not move before
## while Tools, Simulate mechanism is open? Simulate drives the part selected
## (SimulatePanel._on_selection: a new driver, its turns back to 0 and the
## drawn pose cleared). Two 1 x 1 bricks on single studs of a 2 x 4, Simulate
## open, its driver scrubbed a quarter turn, then the OTHER 1 x 1 dragged on
## its joint. Says the driver, the turns and the first 1 x 1's drawn place
## before and after, and what the drag did to the selection. Run on the branch
## and on its base: what differs is the change's.
##
## In the suite since appfix (726b8bf82): the driver and the drawn pose are
## checked; the turns are noted, as the drag moves a part and Simulate reads
## any edited mechanism again from 0, on the base too.
##
##   PROBE_SIZE=1280x720 tools/probe.sh simgrab_probe
##   godot --path . --resolution 1280x720 --script src/dev/simgrab_probe.gd
extends "res://src/dev/grabselect_probe.gd"

var _left: int = 0


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("simgrab_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "desktop"
	Phone._on = 0
	Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	(_main.get("_store") as ModelStore).keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	print("simgrab_probe: a %s window" % _size)
	# simulate_probe's orrery: a crank (the marked driver), Earth's arm on the
	# central axle and Mars's on a turntable, each a body Simulate can drive.
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path("res://src/dev/fixtures/orrery_two_planets.ldr"))
	var store: ModelStore = _main.get("_store")
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	var playback2: Variant = _main.get("_playback")
	if playback2 is BuildPlayback:
		(playback2 as BuildPlayback).stop()
	_builder.forget_history()
	_builder.clear_selection()
	_verbs.set_mode("select")
	var grab: GrabDrag = _main.get("_grab_drag")
	if grab != null:
		grab.call("read_soon")
	await _frames(6)
	if grab != null and not grab.is_ready():
		grab.call("_ready_now")
	var box := AABB()
	for brick: BrickWorld.Brick in _world.bricks():
		box = AABB(brick.transform.origin, Vector3.ZERO) if box.size == Vector3.ZERO and box.position == Vector3.ZERO \
			else box.expand(brick.transform.origin)
	_camera.set_view("default")
	_camera.frame(box.grow(40))
	await _settle()
	print("  (the orrery: %d parts)" % _world.brick_count())

	print("\n1. Simulate open, its driver a quarter turn on")
	await _main.call("open_simulate")
	var panel: Node = _main.get("_simulate_made")
	for _n: int in 600:
		if not bool(panel.get("_reading")) and not bool(panel.get("_driving")):
			break
		await process_frame
	await _frames(10)
	var sim: Variant = panel.get("sim")
	if sim == null:
		_check("Simulate read a mechanism", false)
		quit(1)
		return
	var body_of := func(id: int) -> int:
		return int(sim.model.body_of(id)) if sim.model.parts.has(id) else -1
	var driver0: int = int(sim.driver)
	var bodies: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var body: int = body_of.call(brick.id)
		if not bodies.has(body):
			bodies[body] = [sim.can_drive(body), []]
		(bodies[body][1] as Array).append(brick.id)
	print("  (driver %d; bodies: %s)" % [driver0, bodies])
	panel.call("scrub_to", 0.25)
	await _frames(20)
	var turns0: float = float(panel.get("turns"))
	var drawn0: Dictionary = _drawn()
	print("  turns %.3f, drawn %d parts" % [turns0, drawn0.size()])
	var selected_before: Array = _builder.selection.keys()
	await _shot2("sim_1_before")

	print("\n2. a part of another body Simulate can drive, dragged on its joint")
	var dragged: int = 0
	var held: Array = [false, false]
	var depth: int = _builder.history_depth()
	var models_before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		models_before[brick.id] = brick.transform
	for body: int in bodies:
		if body == driver0 or not bool(bodies[body][0]):
			continue
		for id: int in bodies[body][1]:
			var on: Vector2 = _point_on(id)
			if on == Vector2.INF:
				continue
			held = await _drag_from(on, on + Vector2(_reach() * 0.5, 0.0), 20, "sim_1b_held")
			if bool(held[0]) or bool(held[1]):
				dragged = id
				break
		if dragged != 0:
			break
	_check("a part of another drivable body was taken hold of (%d: grabbed %s, carried %s)" % [dragged, held[0], held[1]],
		dragged != 0)
	for _n: int in 600:
		if not bool(panel.get("_driving")):
			break
		await process_frame
	await _frames(20)
	await _shot2("sim_2_after")
	var turns1: float = float(panel.get("turns"))
	var driver1: int = int(sim.driver) if panel.get("sim") != null else -2
	var drawn1: Dictionary = _drawn()
	var moved: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if models_before.has(brick.id) and not brick.transform.is_equal_approx(models_before[brick.id]):
			moved.append(brick.id)
	print("  selection %s -> %s; history %d -> %d; parts whose model place changed: %s"
		% [selected_before, _builder.selection.keys(), depth, _builder.history_depth(), moved])
	print("  Simulate: driver %d -> %d (dragged part's body %d), turns %.3f -> %.3f, drawn %d -> %d parts"
		% [driver0, driver1, body_of.call(dragged) if dragged != 0 else -1, turns0, turns1, drawn0.size(), drawn1.size()])
	print("  status: \"%s\"" % str((panel.get("_driver") as Label).text))
	_check("Simulate's driver is the one it had before the drag (%d, now %d)" % [driver0, driver1],
		driver1 == driver0)
	_check("Simulate's pose still drawn (%d parts, now %d)" % [drawn0.size(), drawn1.size()],
		drawn1.size() == drawn0.size() and not drawn0.is_empty())
	# The drag moved a part, so Simulate reads the mechanism again and starts
	# it at 0, as after any edit: on appwalk's base too (pastereview F4).
	print("  NOTE  Simulate's turns after the drag moved a part: %.3f, scrubbed %.3f (read again, as any edit is)"
		% [turns1, turns0])
	print("\nsimgrab_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## The world's drawn poses (BrickWorld.set_drawn), by brick id.
func _drawn() -> Dictionary:
	var got: Variant = _world.get("_drawn")
	return got if got is Dictionary else {}
