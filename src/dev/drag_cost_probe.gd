## What a loop's drag frame spends in its room test: 8808-1's steering wheel
## turned by the pointer as play_flow turns it on a phone, frame by frame.
##
##   godot --headless --path . --script src/dev/drag_cost_probe.gd
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _grab: GrabDrag
var _store: ModelStore


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_grab = _main.get("_grab_drag")
	_store = _main.get("_store")
	var rounds: int = 3
	var degrees: float = -120.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
		if arg.begins_with("--degrees="):
			degrees = float(arg.trim_prefix("--degrees="))
	_main.call("_open", ProjectSettings.globalize_path("res://vendor/omr/files/8808-1.mpd"))
	for _n: int in 400:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	_builder.forget_history()
	_grab._ready_now()
	var bodies: Bodies = _grab.read_bodies()
	var wheel: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info != null and info.name.contains("Steering Wheel") and bodies.body_of.has(brick.id):
			wheel = brick.id
			break
	var body: int = int(bodies.body_of[wheel])
	var link: Bodies.Link = bodies.parent_link[body]
	var worst_frames := PackedFloat64Array()
	var worst_tests := PackedFloat64Array()
	var tests_ms := PackedFloat64Array()
	for round: int in rounds:
		var spot: Variant = _grab.handle_on(body, link, PackedInt64Array([wheel]))
		if spot == null:
			print("no handle on the wheel #%d" % wheel)
			quit(1)
			return
		var at: Vector2 = spot["screen"]
		var pivot: Vector2 = spot.get("pivot", at + Vector2(0, 30))
		var off: Vector2 = at - pivot
		if off.length() < 12.0:
			off = Vector2(0, -30)
		if not _grab.press(int(spot["id"]), at):
			print("the press was not a grab")
			quit(1)
			return
		var grab: Grab = _grab.grab
		print("round %d: %s; moving %d, followers %d, %d joints; budget %.0f ms" % [round, grab.said,
			grab.moving.size(), grab.followers.size(), grab.linkage.links.size() if grab.linkage != null else 0,
			grab.budget_ms])
		var frame_worst: float = 0.0
		var test_worst: float = 0.0
		for n: int in range(1, 13):
			var a: float = deg_to_rad(degrees) * n / 12.0
			var to: Vector2 = pivot + off.rotated(a)
			var began: int = Time.get_ticks_usec()
			_grab.motion(to)
			var took: float = float(Time.get_ticks_usec() - began) / 1000.0
			frame_worst = maxf(frame_worst, took)
			test_worst = maxf(test_worst, grab.frame_test_ms)
			tests_ms.append(grab.frame_test_ms)
			print("  move %2d: %8.3f° %s %s  %.2f ms (solve %.2f, %d tests %.2f%s)" % [n, grab.angle,
				"stopped" if grab.stopped else "       ", grab.blocked_by, took, grab.frame_solve_ms, grab.frame_tests,
				grab.frame_test_ms, ", slowest " + grab.frame_slowest_said if not grab.frame_slowest_said.is_empty() else ""])
			# 90 ms between moves, as play_flow waits.
			var waited: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - waited < 90:
				await process_frame
		worst_frames.append(frame_worst)
		worst_tests.append(test_worst)
		print("  worst frame %.2f ms, worst room test %.2f ms; drag's worst %.2f (%s)" % [frame_worst, test_worst,
			_grab.worst_ms, _grab.worst_follow_said])
		var verified: int = 0
		while grab.unchecked and verified < 200:
			grab.verify_step()
			verified += 1
		print("  checked: %.3f° %s %s after %d steps" % [grab.angle, "stopped" if grab.stopped else "", grab.blocked_by,
			verified])
		_grab.release()
		for _n: int in 600:
			await process_frame
			if not _grab.is_grabbing() and not _grab.is_settling():
				break
		_builder.undo()
		await _frames(5)
	print("worst frames %s; worst room tests %s" % [worst_frames, worst_tests])
	var sorted_tests: Array = Array(tests_ms).filter(func(v: float) -> bool: return v > 0.0)
	sorted_tests.sort()
	var total: float = 0.0
	for v: float in sorted_tests:
		total += v
	print("room tests: %d, mean %.3f ms, median %.3f ms, worst %.3f ms" % [sorted_tests.size(),
		total / maxf(1.0, sorted_tests.size()), sorted_tests[sorted_tests.size() / 2], sorted_tests.back()])
	quit(0)
