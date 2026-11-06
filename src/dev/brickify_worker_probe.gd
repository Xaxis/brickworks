## Bring in a 3D model compiles Brickify on a worker as a model is shown
## (BrickifyDialog, Later.script_in_background). Named by the panel, it
## compiled 4.3 MB, 91 scripts, as the panel opened: 2.0 s in one frame in
## a browser (leaves, 2026-11-05). On a worker, the window's own frames go
## on while those scripts compile, and they read some of them every frame:
## Main's frame timer asks whether ModelShot is loaded and reads its GPU
## wait, and the booklet's busy flag is BookletMaker's. So:
##
##   the panel opens with Brickify not loaded, and shows the bunny;
##   while Brickify compiles, every Later class it names that reads as
##   loaded (Later.loaded, as those frames ask) is whole: its script can
##   make one, and ModelShot's GPU wait and BookletMaker's busy flag read;
##   the window's frames go on meanwhile, none held over 300 ms (each
##   frame's time is printed);
##   a dialog the main thread compiles meanwhile (About's credits, half a
##   second in) is made whole. It waits for the worker's compile to end:
##   Godot's script cache is held for the whole of a compile, so any first
##   use compiled while Brickify comes waits out the rest of it (printed);
##   then the bunny is laid from the panel three times, as Brickify pressed
##   does: each lands, buildable in one piece, with no script error, and
##   what the worker reads its steps and stock with stays compiled between.
##
##   godot --headless --path . --script src/dev/brickify_worker_probe.gd
##
## It names no class Later loads, nor one that names Brickify: naming one
## would compile Brickify here first, and its worker would have nothing to do
## (brickify_ui_probe names BookletMaker, so it never sees the worker's compile).
extends SceneTree

var _failures: int = 0
var _main: Node
var _dialog: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://src/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_shell") != null and _main.get("_bin") != null and bool(_main.get("_built")):
			break
	if _main.get("_shell") == null:
		print("  brickify_worker probe: SKIPPED — the shell never came up")
		quit(3)
		return
	var playback: Object = _main.get("_playback")
	if playback != null:
		playback.call("stop")
	await _frames(60)
	_main.call("clear_model")
	await _frames(10)

	_dialog = _main.get("_brickify")
	_check("the panel is made without Brickify: %s" % str(Later.took.keys()),
		_dialog != null and not Later.loaded(&"Brickify") and not Later.loaded(&"Assistant"))
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/brickify/bunny.obj")
	var mesh: Object = load("res://src/parts/mesh_file.gd").call("read", bytes, "bunny.obj")
	_check("the bunny is read: %s triangles" % (mesh.call("triangle_count") if mesh != null else 0),
		mesh != null and int(mesh.call("triangle_count")) > 100)
	if mesh == null:
		_finish()
		return
	_dialog.call("show_for", mesh)
	_check("the panel shows it while Brickify comes", _dialog.visible
		and bool(_dialog.get("_making")) and not Later.loaded(&"Brickify"))

	# While it compiles: the frames, what reads as loaded, and a dialog
	# compiled on the main thread.
	var watched: Array[StringName] = []
	for name: StringName in Later.PATHS:
		if not Later.loaded(name):
			watched.append(name)
	var frames := PackedFloat64Array()
	var broken := PackedStringArray()
	var seen_loaded: Dictionary = {}
	var credits_ms: float = -1.0
	var credits_at: int = -1
	var began: int = Time.get_ticks_usec()
	var last: int = began
	while bool(_dialog.get("_making")) and Time.get_ticks_usec() - began < 120000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		for name: StringName in watched:
			if seen_loaded.has(name) or not Later.loaded(name):
				continue
			seen_loaded[name] = frames.size()
			var script: GDScript = Later.script(name)
			if script == null or not script.can_instantiate():
				broken.append(String(name))
		if Later.loaded(&"ModelShot"):
			var shots: GDScript = Later.script(&"ModelShot")
			if typeof(shots.get("gpu_wait_us")) != TYPE_INT:
				broken.append("ModelShot.gpu_wait_us")
		if Later.loaded(&"BookletMaker"):
			var maker: GDScript = Later.script(&"BookletMaker")
			if typeof(maker.get("busy")) != TYPE_BOOL:
				broken.append("BookletMaker.busy")
		if now - began > 500000 and credits_ms < 0.0:
			credits_at = frames.size()
			var asked: int = Time.get_ticks_usec()
			var credits: GDScript = Later.script(&"Credits")
			credits_ms = (Time.get_ticks_usec() - asked) / 1000.0
			_check("About's credits compiled on the main thread meanwhile",
				credits != null and credits.can_instantiate())
	var compile_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	# The frames before the credits were asked for: the worker's alone.
	var longest: float = 0.0
	var alone: int = credits_at if credits_at >= 0 else frames.size()
	for at: int in alone:
		longest = maxf(longest, frames[at])
	print("  Brickify compiled on a worker in %.0f ms over %d frames" % [compile_ms, frames.size()])
	var slow := PackedStringArray()
	for at: int in frames.size():
		if frames[at] > 30.0:
			slow.append("%d: %.0f" % [at, frames[at]])
	print("    frames over 30 ms (frame: ms): %s" % ", ".join(slow))
	print("    the credits' compile, asked at frame %d (half a second in), waited %.0f ms"
		% [credits_at, credits_ms])
	print("    read as loaded during it (at frame): %s" % str(seen_loaded))
	_check("Brickify came in, with the assistant it lays with",
		_dialog.get("_maker") != null and Later.loaded(&"Brickify") and Later.loaded(&"Assistant"))
	_check("every class read as loaded meanwhile was whole: broken %s" % str(broken), broken.is_empty())
	_check("the frames went on while it compiled: %d before the credits were asked for, the longest %.0f ms"
		% [alone, longest], alone >= 10 and longest < 300.0)

	# Laid three times from the panel, as Brickify pressed lays it.
	var world: Object = _main.get("_world")
	for turn: int in 3:
		_main.call("clear_model")
		await _frames(5)
		_dialog.call("set_studs", 24)
		await _frames(2)
		var start: int = Time.get_ticks_msec()
		await _dialog.call("brickify")
		await _frames(20)
		var said: String = str(_dialog.get("last_summary"))
		_check("lay %d: %d parts in %d ms: %s" % [turn + 1, int(world.call("brick_count")),
			Time.get_ticks_msec() - start, said.left(120)],
			said.contains("buildable in one piece") and int(world.call("brick_count")) > 100)
	_check("what the worker reads its steps and stock with stayed compiled",
		Later.loaded(&"BrickifySteps") and Later.loaded(&"BrickifyStock"))
	print("  first loads, ms: %s" % str(Later.took))
	_finish()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	print("brickify_worker probe: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
