## Does the app stay alive while a big design is made in it?
##
##   godot --path . --resolution 1400x900 --script src/dev/freeze_probe.gd
##   godot --path . --resolution 1400x900 --script src/dev/freeze_probe.gd -- calls.json
##
## The owner asked the web app for a Falcon Heavy and it "damn near froze
## my computer". This makes the calls Claude makes over the connector, on
## that design (src/dev/fixtures/falcon_heavy.json, 4,242 parts), through
## the connector's own answer_rpc in the real scene — check it, submit it,
## read it back, look at it, edit one brick, review it — and times every
## frame while each runs and while the build animation plays after it.
## Then it turns the camera round the model, doubled to 8,484 parts, and
## times that. A calls file pulled from a Claude Code session log
## ([{name, input}]) replays a real run instead.
##
## Measured before the fixes, on this machine's GPU: submit_design one frame
## of 19.5 s, then frames of 4 to 35 s for the two minutes the animation was
## let run. Run on the Compatibility renderer too (--rendering-method
## gl_compatibility), which is the web build's.
extends SceneTree

## The longest frame allowed while a design is made, in ms. A browser on a
## laptop runs the same scripts two or three times slower than this.
const BUDGET_MS := 200.0
## Frames a second the doubled Falcon must turn at.
const ORBIT_FPS := 30.0

var _failures: int = 0
var _last_us: int = 0
var _gaps: Array = []   ## [end in usec, ms]
var _recording: bool = false
var _software: bool = false


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if _recording and _last_us > 0:
		_gaps.append([now, (now - _last_us) / 1000.0])
	_last_us = now
	return false


## The longest frame that began at or after [param from], and how many
## went over the budget.
func _worst_since(from: int) -> Array:
	var worst: float = 0.0
	var over: int = 0
	for gap: Array in _gaps:
		if int(gap[0]) - int(float(gap[1]) * 1000.0) < from:
			continue
		worst = maxf(worst, float(gap[1]))
		if float(gap[1]) > BUDGET_MS:
			over += 1
	return [worst, over]


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	playback.stop()
	var world: BrickWorld = main.get("_world")
	var rpc: CommandSocket = main.get("_connector").rpc

	var calls: Array = _falcon_calls()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		calls = JSON.parse_string(FileAccess.get_file_as_string(args[0]))

	var first_listed: int = 0
	var worst_all: float = 0.0
	# Drawn in software (no GPU to hand: llvmpipe, lavapipe), a frame is
	# mostly the CPU drawing triangles, so frames are said and not judged.
	var adapter: String = RenderingServer.get_video_adapter_name().to_lower()
	_software = adapter.contains("llvmpipe") or adapter.contains("lavapipe") \
		or adapter.contains("swiftshader")
	_recording = true
	for call: Dictionary in calls:
		var name: String = call["name"]
		if name == "save_model":
			continue
		var input: Variant = JSON.parse_string(JSON.stringify(call["input"]).replace(
			"\"first listed\"", str(first_listed)))
		var began: int = Time.get_ticks_usec()
		var answer: Variant = await rpc.answer_rpc({"jsonrpc": "2.0", "id": 1,
			"method": "tools/call", "params": {"name": name, "arguments": input}})
		var took: float = (Time.get_ticks_usec() - began) / 1000.0
		var waited: int = Time.get_ticks_usec()
		while playback.is_playing() and Time.get_ticks_usec() - waited < 60_000_000:
			await process_frame
		var played: float = (Time.get_ticks_usec() - waited) / 1000.0
		for _n: int in 3:
			await process_frame
		var worst: Array = _worst_since(began)
		worst_all = maxf(worst_all, float(worst[0]))
		var text: String = JSON.stringify(answer)
		if name == "look_at_model":
			var found: RegExMatch = RegEx.create_from_string("#(\\d+)\\s").search(text)
			if found != null:
				first_listed = found.get_string(1).to_int()
		var said: String = text.substr(text.find("\"text\":") + 8, 60).replace("\\n", " ")
		_check("%-14s %6.0f ms, then %5.0f ms of animation; the longest frame %4.0f ms, %d over %d: %s"
			% [name, took, played, worst[0], worst[1], BUDGET_MS, said],
			(_software or float(worst[0]) <= BUDGET_MS)
				and not text.contains("Not applied") and not text.contains("No brick has"))
	_recording = false
	print("  the model: %d bricks" % world.brick_count())

	await _orbit(main, world)
	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "a %d-part design is made without a frame over %.0f ms" % [
			world.brick_count(), BUDGET_MS])
	quit(1 if _failures else 0)


## The Falcon twice over, turned about for two seconds.
func _orbit(main: Node, world: BrickWorld) -> void:
	var library: PartLibrary = main.get("_library")
	var twice: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		twice.append(brick)
	for brick: BrickWorld.Brick in twice:
		var at: Transform3D = brick.transform
		at.origin.x += 1200.0
		world.add_brick(brick.part_id, brick.color_code, at)
	var camera: CadCamera = main.get("_camera")
	camera.frame(world.model_bounds())
	for _n: int in 30:
		await process_frame
	var frames: int = 0
	# Where a frame goes: drawing it, the CPU's side and the GPU's (the
	# viewport's measured render times). The rest is the app's own work
	# and handing the frame to the display, which under Xvfb is a copy the
	# CPU makes (MESA_VK_WSI_DEBUG=sw).
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var draw_cpu_ms: float = 0.0
	var draw_gpu_ms: float = 0.0
	var queued: float = _waited_for_cpu_ms()
	var began: int = Time.get_ticks_usec()
	var worst: float = 0.0
	var last: int = began
	while Time.get_ticks_usec() - began < 2_000_000:
		camera.key_turn(Vector2(1.0, 0.0))
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		draw_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		draw_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	var fps: float = frames / ((Time.get_ticks_usec() - began) / 1e6)
	queued = _waited_for_cpu_ms() - queued
	RenderingServer.viewport_set_measure_render_time(viewport, false)
	print("  a frame while turning: %.1f ms, of which drawing is %.1f ms of the CPU's and %.1f of the GPU's"
		% [2000.0 / maxf(frames, 1), draw_cpu_ms / maxf(frames, 1), draw_gpu_ms / maxf(frames, 1)])
	var batches: int = 0
	for key: String in world._batches:
		if world._batches[key].multimesh.instance_count > 0:
			batches += 1
	var adapter: String = RenderingServer.get_video_adapter_name()
	var software: bool = _software
	_check("turning round %d parts in %d batches: %.0f frames a second, the slowest %.0f ms (%s on %s)%s%s"
		% [world.brick_count(), batches, fps, worst,
			RenderingServer.get_current_rendering_method(), adapter,
			", in software, so not judged" if software else "",
			_queued_said(queued, 2000.0)],
		software or fps >= ORBIT_FPS)
	if library == null:
		return


## The calls Claude makes with the owner's design.
static func _falcon_calls() -> Array:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/dev/fixtures/falcon_heavy.json"))
	var bricks: Array = []
	for row: Array in fixture["bricks"]:
		var one: Dictionary = {"part": row[0], "color": row[1], "x": row[2],
			"y": row[3], "z": row[4], "rot": row[6]}
		if row[5] != "up":
			one["face"] = row[5]
		bricks.append(one)
	var design: Dictionary = {"name": fixture["name"], "bricks": bricks}
	return [
		{"name": "clear_model", "input": {}},
		{"name": "check_design", "input": design},
		{"name": "submit_design", "input": design},
		{"name": "look_at_model", "input": {}},
		{"name": "view_model", "input": {"from": "corner"}},
		{"name": "edit_model", "input": {"recolor": [
			{"bricks": ["first listed"], "color": 4}]}},
		{"name": "review_model", "input": {}},
		# And submitted onto a bare baseplate, with nothing checked first,
		# so all 4,242 go up in the build animation.
		{"name": "clear_model", "input": {}},
		{"name": "submit_design", "input": design},
	]


## How long this process's main thread has waited for a CPU it was ready
## to run on, in ms (/proc/self/schedstat, Linux; -1 elsewhere). On a
## machine other projects share, it says how much of a slow stretch was
## the machine rather than the app: the frames are judged as they are.
static func _waited_for_cpu_ms() -> float:
	var stat: FileAccess = FileAccess.open("/proc/self/schedstat", FileAccess.READ)
	if stat == null:
		return -1.0
	var fields: PackedStringArray = stat.get_line().split(" ", false)
	return fields[1].to_float() / 1e6 if fields.size() > 1 else -1.0


static func _queued_said(queued: float, of_ms: float) -> String:
	if queued < 0.0:
		return ""
	var load: FileAccess = FileAccess.open("/proc/loadavg", FileAccess.READ)
	return "; the main thread waited %.0f of those %.0f ms for a CPU, at a load of %s" % [
		queued, of_ms, load.get_line().get_slice(" ", 0) if load != null else "?"]


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
